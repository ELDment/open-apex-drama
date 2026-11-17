import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/watch_store.dart';
import '../services/watch_sync_service.dart';
import '../services/webdav_client.dart';
import '../services/webdav_sync_settings.dart';
import 'watch_providers.dart';

/// 同步界面状态：配置 + 当前是否在同步 + 最近一次结果文案。
@immutable
class WebDavSyncState {
  const WebDavSyncState({
    required this.settings,
    this.phase = SyncPhase.idle,
    this.message = '',
    this.messageIsError = false,
    this.lastPulledRecords = 0,
  });

  final WebDavSyncSettings settings;
  final SyncPhase phase;

  /// 最近一次同步结果 / 错误信息（空串 = 尚未同步）。
  final String message;
  final bool messageIsError;
  final int lastPulledRecords;

  bool get isConfigured => settings.isConfigured;

  bool get syncing => phase == SyncPhase.syncing;

  WebDavSyncState copyWith({
    WebDavSyncSettings? settings,
    SyncPhase? phase,
    String? message,
    bool? messageIsError,
    int? lastPulledRecords,
  }) {
    return WebDavSyncState(
      settings: settings ?? this.settings,
      phase: phase ?? this.phase,
      message: message ?? this.message,
      messageIsError: messageIsError ?? this.messageIsError,
      lastPulledRecords: lastPulledRecords ?? this.lastPulledRecords,
    );
  }
}

enum SyncPhase { idle, syncing }

/// WebDAV 云同步控制器：持有配置、监听本地变更并调度自动同步。
///
/// - 手动：仅 [syncNow]；
/// - 每天：启动 / 回到前台 / 每 10 分钟检查，距上次成功同步满 24h 触发；
/// - 改动：本地收藏 / 历史变更后 debounce 15s 触发，两次自动同步至少间隔
///   [WebDavSyncSettings.onChangeMinGap]（播放中每 5 秒就有进度写入，
///   不做限流会把 WebDAV 请求额度打满）。
class WebDavSyncController extends AsyncNotifier<WebDavSyncState> {
  WatchStore? _store;
  WebDavSyncSettings? _settings;
  StreamSubscription<void>? _storeSubscription;
  AppLifecycleListener? _lifecycle;
  Timer? _changeDebounce;
  Timer? _minGapTimer;
  bool _running = false;
  bool _pending = false;
  bool _disposed = false;

  /// 最近一次同步失败时间（内存态）：失败后 15 分钟内不再自动重试，
  /// 避免账号填错时反复打 WebDAV 请求。
  DateTime _lastFailureAt = DateTime.fromMillisecondsSinceEpoch(0);

  static const Duration _changeDebounceDuration = Duration(seconds: 15);
  static const Duration _autoRetryCooldown = Duration(minutes: 15);

  @override
  Future<WebDavSyncState> build() async {
    final WatchStore store = await ref.watch(watchStoreProvider.future);
    final WebDavSyncSettings settings = await WebDavSyncSettings.load();
    _store = store;
    _settings = settings;
    _storeSubscription = store.changes.listen(_onStoreChanged);
    _lifecycle = AppLifecycleListener(onResume: _onAppResumed);
    ref.onDispose(() {
      _disposed = true;
      _storeSubscription?.cancel();
      _lifecycle?.dispose();
      _changeDebounce?.cancel();
      _minGapTimer?.cancel();
    });
    return WebDavSyncState(settings: settings);
  }

  /// 启动时由 AppShell 在 provider 就绪后调用一次；按同步方式决定
  /// 是否立刻补一次同步（每天模式到期 / 改动模式的启动补同步）。
  void checkAutoSync() {
    _maybeAutoSync();
  }

  /// 保存服务器 / 账号配置（不改触发方式）。[autoSync] 为 false 时
  /// 不立刻触发自动同步（调用方紧接着会手动同步）。
  Future<void> updateConfig(
    WebDavConfig config, {
    bool autoSync = true,
  }) async {
    final WebDavSyncSettings base = _settings ?? await WebDavSyncSettings.load();
    _settings = base.copyWith(config: config);
    await _settings!.save();
    _lastFailureAt = DateTime.fromMillisecondsSinceEpoch(0);
    _emit(settings: _settings, message: '', messageIsError: false);
    if (autoSync && _settings!.mode != SyncMode.manual) {
      _maybeAutoSync();
    }
  }

  /// 切换同步方式。
  Future<void> updateMode(SyncMode mode) async {
    final WebDavSyncSettings base = _settings ?? await WebDavSyncSettings.load();
    _settings = base.copyWith(mode: mode);
    await _settings!.save();
    _lastFailureAt = DateTime.fromMillisecondsSinceEpoch(0);
    _emit(settings: _settings);
    if (mode != SyncMode.manual) {
      _maybeAutoSync();
    }
  }

  /// 切换同步策略（合并 / 以本地为准覆盖云端）。
  Future<void> updateStrategy(SyncStrategy strategy) async {
    final WebDavSyncSettings base = _settings ?? await WebDavSyncSettings.load();
    _settings = base.copyWith(strategy: strategy);
    await _settings!.save();
    _emit(settings: _settings);
  }

  /// 立即同步一次。返回可直接展示的结果文案。
  Future<String> syncNow({bool manual = true}) async {
    if (_running) {
      return '正在同步，请稍候…';
    }
    final WebDavSyncSettings? settings = _settings;
    final WatchStore? store = _store;
    if (settings == null || store == null) {
      return '同步尚未就绪，请稍后再试';
    }
    if (!settings.config.isConfigured) {
      const String message = '请先在设置中填写服务器地址、账号和应用密码';
      _emit(message: message, messageIsError: true);
      return message;
    }

    _running = true;
    _emit(phase: SyncPhase.syncing, message: '正在同步…', messageIsError: false);
    try {
      final WatchSyncService service = WatchSyncService(
        config: settings.config,
        strategy: settings.strategy,
      );
      final WatchSyncResult result = await service.sync(store);
      _settings = (_settings ?? settings).copyWith(
        lastSyncAt: DateTime.now(),
        lastSyncOk: true,
      );
      await _settings!.save();
      // 云端数据可能改写了本机列表，刷新两个 provider。
      ref.invalidate(historyProvider);
      ref.invalidate(favoritesProvider);
      final String message = _resultMessage(result);
      _emit(
        settings: _settings,
        phase: SyncPhase.idle,
        message: message,
        messageIsError: false,
        lastPulledRecords: result.pulledRecords,
      );
      return message;
    } on WebDavException catch (error) {
      return _fail(settings, error.message);
    } on WatchSyncFormatException catch (error) {
      return _fail(settings, error.message);
    } catch (error) {
      return _fail(settings, '同步失败：$error');
    } finally {
      _running = false;
      if (_pending && !_disposed) {
        _pending = false;
        _scheduleChangeSync();
      }
    }
  }

  /// 测试连接（不读写同步文件）；失败抛 [WebDavException]。
  Future<void> testConnection(WebDavConfig config) async {
    await WatchSyncService(config: config).testConnection();
  }

  String _fail(WebDavSyncSettings settings, String message) {
    _lastFailureAt = DateTime.now();
    _settings = (_settings ?? settings).copyWith(lastSyncOk: false);
    unawaited(_settings!.save());
    _emit(
      settings: _settings,
      phase: SyncPhase.idle,
      message: message,
      messageIsError: true,
    );
    return message;
  }

  String _resultMessage(WatchSyncResult result) {
    final String base =
        '同步完成 · 收藏 ${result.favoriteCount} 部 · 观看记录 ${result.historyCount} 条';
    if (result.pulledRecords > 0) {
      return '$base · 拉取 ${result.pulledRecords} 条';
    }
    return base;
  }

  // ---------------------------------------------------------------------------
  // 自动同步调度
  // ---------------------------------------------------------------------------

  void _onStoreChanged(void _) {
    final WebDavSyncSettings? settings = _settings;
    if (settings == null ||
        settings.mode != SyncMode.onChange ||
        !settings.config.isConfigured) {
      return;
    }
    _scheduleChangeSync();
  }

  void _scheduleChangeSync() {
    _changeDebounce?.cancel();
    _changeDebounce = Timer(_changeDebounceDuration, () {
      if (!_disposed) {
        _triggerChangeSync();
      }
    });
  }

  void _triggerChangeSync() {
    final WebDavSyncSettings? settings = _settings;
    if (settings == null ||
        settings.mode == SyncMode.manual ||
        !settings.config.isConfigured) {
      return;
    }
    if (_running) {
      _pending = true;
      return;
    }
    // 最近一次尝试失败后进入冷却期，避免反复打请求。
    if (DateTime.now().difference(_lastFailureAt) < _autoRetryCooldown) {
      return;
    }
    final DateTime? last = settings.lastSyncAt;
    if (last != null) {
      final Duration elapsed = DateTime.now().difference(last);
      if (elapsed < WebDavSyncSettings.onChangeMinGap) {
        _minGapTimer?.cancel();
        _minGapTimer = Timer(
          WebDavSyncSettings.onChangeMinGap - elapsed + const Duration(seconds: 1),
          () {
            if (!_disposed) {
              _triggerChangeSync();
            }
          },
        );
        return;
      }
    }
    unawaited(syncNow(manual: false));
  }

  void _onAppResumed() {
    _maybeAutoSync();
  }

  /// 按当前模式判断是否该自动同步（不满足条件立即返回）。
  void _maybeAutoSync() {
    final WebDavSyncSettings? settings = _settings;
    if (settings == null ||
        settings.mode == SyncMode.manual ||
        !settings.config.isConfigured) {
      return;
    }
    if (_running) {
      _pending = true;
      return;
    }
    final DateTime? last = settings.lastSyncAt;
    final Duration? gap = switch (settings.mode) {
      SyncMode.manual => null,
      SyncMode.daily => WebDavSyncSettings.dailyInterval,
      SyncMode.onChange => WebDavSyncSettings.onChangeResumeGap,
    };
    if (gap == null) {
      return;
    }
    if (last != null && DateTime.now().difference(last) < gap) {
      return;
    }
    _triggerChangeSync();
  }

  void _emit({
    WebDavSyncSettings? settings,
    SyncPhase? phase,
    String? message,
    bool? messageIsError,
    int? lastPulledRecords,
  }) {
    if (_disposed) {
      return;
    }
    final WebDavSyncState? current = state.value;
    // provider 首次 build 尚未落地时不写 state，避免非法状态写入；
    // 此时 UI 还没渲染，也不存在需要展示的中间态。
    if (current == null) {
      return;
    }
    state = AsyncData(
      current.copyWith(
        settings: settings,
        phase: phase,
        message: message,
        messageIsError: messageIsError,
        lastPulledRecords: lastPulledRecords,
      ),
    );
  }
}

final AsyncNotifierProvider<WebDavSyncController, WebDavSyncState>
webDavSyncProvider =
    AsyncNotifierProvider<WebDavSyncController, WebDavSyncState>(
      WebDavSyncController.new,
    );
