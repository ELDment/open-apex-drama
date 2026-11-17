import 'package:shared_preferences/shared_preferences.dart';

import 'webdav_client.dart';

/// 同步触发方式。
enum SyncMode {
  manual('手动同步', '只在你点按云图标或「立即同步」时同步'),
  daily('每天自动同步', '打开应用时检查，距上次同步满 24 小时自动同步一次'),
  onChange('改动后自动同步', '收藏、取消收藏、观看进度或删除记录后自动同步');

  const SyncMode(this.label, this.description);

  final String label;
  final String description;

  static SyncMode fromStorage(String? value) {
    return switch (value) {
      'daily' => SyncMode.daily,
      'onChange' => SyncMode.onChange,
      _ => SyncMode.manual,
    };
  }

  String get storageValue => name;
}

/// 同步策略：决定本地与云端数据如何处理冲突。
enum SyncStrategy {
  merge('合并同步', '逐条比对，同一部剧保留较新的记录，删除标记双向传播（推荐）'),
  localOverwrite('以本地为准覆盖云端', '用本机收藏与观看记录替换云端文件，云端独有的记录会丢失');

  const SyncStrategy(this.label, this.description);

  final String label;
  final String description;

  static SyncStrategy fromStorage(String? value) {
    return value == 'localOverwrite'
        ? SyncStrategy.localOverwrite
        : SyncStrategy.merge;
  }

  String get storageValue => name;
}

/// WebDAV 同步设置（本机持久化）。
///
/// 账号密码只保存在本机 SharedPreferences，不上传到任何第三方；WebDAV
/// 服务器只接收 `watch-sync.json` 这一个数据文件。
class WebDavSyncSettings {
  const WebDavSyncSettings({
    required this.config,
    this.mode = SyncMode.manual,
    this.strategy = SyncStrategy.merge,
    this.lastSyncAt,
    this.lastSyncOk,
  });

  static const String serverKey = 'webdav.server.v1';
  static const String usernameKey = 'webdav.username.v1';
  static const String passwordKey = 'webdav.password.v1';
  static const String remoteDirKey = 'webdav.remoteDir.v1';
  static const String modeKey = 'webdav.mode.v1';
  static const String strategyKey = 'webdav.strategy.v1';
  static const String lastSyncAtKey = 'webdav.lastSyncAt.v1';
  static const String lastSyncOkKey = 'webdav.lastSyncOk.v1';

  final WebDavConfig config;
  final SyncMode mode;
  final SyncStrategy strategy;

  /// 最近一次成功同步时间；失败不算。
  final DateTime? lastSyncAt;

  /// 最近一次同步是否成功（null = 还没同步过）。
  final bool? lastSyncOk;

  bool get isConfigured => config.isConfigured;

  /// 每天自动同步的间隔。
  static const Duration dailyInterval = Duration(hours: 24);

  /// 改动即同步模式下两次自动同步的最小间隔，避免播放进度写入
  /// （播放中每 5 秒一次）把 WebDAV 请求额度打满。
  static const Duration onChangeMinGap = Duration(minutes: 2);

  /// 打开应用 / 回到前台时，改动模式下的补同步阈值。
  static const Duration onChangeResumeGap = Duration(minutes: 10);

  bool get isDailyDue {
    final DateTime? last = lastSyncAt;
    return last == null ||
        DateTime.now().difference(last) >= dailyInterval;
  }

  WebDavSyncSettings copyWith({
    WebDavConfig? config,
    SyncMode? mode,
    SyncStrategy? strategy,
    DateTime? lastSyncAt,
    bool? lastSyncOk,
    bool clearLastSyncAt = false,
  }) {
    return WebDavSyncSettings(
      config: config ?? this.config,
      mode: mode ?? this.mode,
      strategy: strategy ?? this.strategy,
      lastSyncAt: clearLastSyncAt ? null : (lastSyncAt ?? this.lastSyncAt),
      lastSyncOk: lastSyncOk ?? this.lastSyncOk,
    );
  }

  static Future<WebDavSyncSettings> load() async {
    const WebDavSyncSettings fallback = WebDavSyncSettings(
      config: WebDavConfig(
        serverUrl: WebDavConfig.defaultServerUrl,
        username: '',
        password: '',
      ),
    );
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final int lastSyncMillis = prefs.getInt(lastSyncAtKey) ?? 0;
      final String storedDir =
          prefs.getString(remoteDirKey) ?? WebDavConfig.defaultRemoteDir;
      return WebDavSyncSettings(
        config: WebDavConfig(
          serverUrl:
              prefs.getString(serverKey) ?? WebDavConfig.defaultServerUrl,
          username: normalizeWebDavCredential(
            prefs.getString(usernameKey) ?? '',
          ).trim(),
          password: normalizeWebDavCredential(
            prefs.getString(passwordKey) ?? '',
          ),
          // 旧版本默认目录自动迁移到新名字；用户自定义过的目录不动。
          remoteDir: storedDir == WebDavConfig.legacyDefaultRemoteDir
              ? WebDavConfig.defaultRemoteDir
              : storedDir,
        ),
        mode: SyncMode.fromStorage(prefs.getString(modeKey)),
        strategy: SyncStrategy.fromStorage(prefs.getString(strategyKey)),
        lastSyncAt: lastSyncMillis > 0
            ? DateTime.fromMillisecondsSinceEpoch(lastSyncMillis)
            : null,
        lastSyncOk: prefs.getBool(lastSyncOkKey),
      );
    } catch (_) {
      // 插件未注册（纯 Dart 测试）：返回内存默认值，接口行为一致。
      return fallback;
    }
  }

  Future<void> save() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(serverKey, config.serverUrl);
      await prefs.setString(usernameKey, config.username);
      await prefs.setString(passwordKey, config.password);
      await prefs.setString(remoteDirKey, config.remoteDir);
      await prefs.setString(modeKey, mode.storageValue);
      await prefs.setString(strategyKey, strategy.storageValue);
      final DateTime? last = lastSyncAt;
      if (last == null) {
        await prefs.remove(lastSyncAtKey);
      } else {
        await prefs.setInt(lastSyncAtKey, last.millisecondsSinceEpoch);
      }
      final bool? ok = lastSyncOk;
      if (ok == null) {
        await prefs.remove(lastSyncOkKey);
      } else {
        await prefs.setBool(lastSyncOkKey, ok);
      }
    } catch (_) {
      // 落盘失败不阻断本次使用（内存态已更新）。
    }
  }
}
