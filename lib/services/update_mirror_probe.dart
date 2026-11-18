import 'dart:async';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../app_state/project_info.dart';
import 'update_mirrors.dart';

/// 启动后台测速三个下载镜像，按「拿到 512KB 探针数据的总耗时」排序。
///
/// - 总耗时同时包含首字节延迟和传输速度，符合「延迟最低、下载最快」；
/// - 结果缓存 6 小时，避免每次启动都消耗流量；
/// - 全部镜像失败时不写缓存，下次启动重试；
/// - 下载开始时若测速仍在进行，[_preferredOrder] 最多等 4 秒。
class UpdateMirrorProbe {
  const UpdateMirrorProbe._();

  static const String _cOrder = 'update.mirrorOrder';
  static const String _cProbedAt = 'update.mirrorProbedAt';
  static const Duration _cacheWindow = Duration(hours: 6);
  static const int _probeBytes = 512 * 1024;
  static const Duration _probeTimeout = Duration(seconds: 8);
  static const Duration _downloadWait = Duration(seconds: 4);

  static Future<void>? _running;

  /// 应用启动时调用；同一时刻只跑一轮测速。
  static Future<void> warmUp({
    required String currentVersion,
    bool force = false,
  }) {
    final Future<void>? running = _running;
    if (running != null) {
      return running;
    }
    final Future<void> future = _run(
      currentVersion: currentVersion,
      force: force,
    );
    _running = future.whenComplete(() {
      _running = null;
    });
    return _running!;
  }

  static Future<void> _run({
    required String currentVersion,
    required bool force,
  }) async {
    final String version = currentVersion.trim();
    if (version.isEmpty) {
      return;
    }
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (!force && _isFresh(prefs)) {
        return;
      }
      final String assetUrl = _assetUrl(version);
      // 串行测速：并发会互相抢带宽，测出来的“最快”会随启动顺序波动，
      // 不能代表单独下载时的真实速度。
      final List<MirrorProbeResult> results = <MirrorProbeResult>[];
      for (final String id in UpdateMirrors.probeOrder) {
        final String? url = UpdateMirrors.url(id, assetUrl);
        results.add(
          url == null
              ? MirrorProbeResult.failed(id)
              : await _probe(id, url),
        );
      }
      // 全部失败（例如启动时没网）：保留旧缓存/默认顺序，下次再试。
      if (results.every((MirrorProbeResult result) => !result.ok)) {
        return;
      }
      await prefs.setStringList(_cOrder, rank(results));
      await prefs.setInt(_cProbedAt, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // 测速只影响下载排序，失败时继续用默认顺序。
    }
  }

  /// 读取测速顺序；没有缓存且测速仍在进行时，最多等 [_downloadWait]。
  static Future<List<String>> preferredOrder() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String>? stored = prefs.getStringList(_cOrder);
      if (stored != null && stored.isNotEmpty) {
        return _completeOrder(stored);
      }
      final Future<void>? running = _running;
      if (running != null) {
        await running.timeout(_downloadWait, onTimeout: () {});
        final List<String>? refreshed = prefs.getStringList(_cOrder);
        if (refreshed != null && refreshed.isNotEmpty) {
          return _completeOrder(refreshed);
        }
      }
    } catch (_) {
      // 读取失败按默认顺序。
    }
    return UpdateMirrors.defaultOrder;
  }

  /// 成功项按总耗时升序；失败项按默认顺序排在最后。
  static List<String> rank(List<MirrorProbeResult> results) {
    final List<MirrorProbeResult> sorted = List<MirrorProbeResult>.of(results)
      ..sort((MirrorProbeResult a, MirrorProbeResult b) {
        if (a.ok != b.ok) {
          return a.ok ? -1 : 1;
        }
        if (!a.ok) {
          return _defaultIndex(a.id).compareTo(_defaultIndex(b.id));
        }
        final int byTotal = a.total.compareTo(b.total);
        if (byTotal != 0) {
          return byTotal;
        }
        return (a.ttfb ?? Duration.zero).compareTo(b.ttfb ?? Duration.zero);
      });
    return sorted.map((MirrorProbeResult result) => result.id).toList();
  }

  static int _defaultIndex(String id) {
    final int index = UpdateMirrors.defaultOrder.indexOf(id);
    return index < 0 ? UpdateMirrors.defaultOrder.length : index;
  }

  static List<String> _completeOrder(List<String> stored) {
    final List<String> order = <String>[];
    for (final String id in <String>[
      ...stored,
      ...UpdateMirrors.defaultOrder,
    ]) {
      if (!order.contains(id)) {
        order.add(id);
      }
    }
    return order;
  }

  static bool _isFresh(SharedPreferences prefs) {
    final int probedAt = prefs.getInt(_cProbedAt) ?? 0;
    if (probedAt <= 0) {
      return false;
    }
    final int elapsed = DateTime.now().millisecondsSinceEpoch - probedAt;
    return elapsed >= 0 && elapsed < _cacheWindow.inMilliseconds;
  }

  static String _assetUrl(String version) {
    final String file = Platform.isWindows
        ? 'ApexDrama-$version-windows-x64-setup.exe'
        : 'ApexDrama-v$version-arm64-v8a.apk';
    return 'https://github.com/$projectRepoOwner/$projectRepoName/'
        'releases/download/v$version/$file';
  }

  static Future<MirrorProbeResult> _probe(String id, String url) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5);
    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      final HttpClientRequest request = await client
          .getUrl(Uri.parse(url))
          .timeout(_probeTimeout);
      request.headers.set(HttpHeaders.userAgentHeader, 'ApexDrama-App');
      request.headers.set(
        HttpHeaders.rangeHeader,
        'bytes=0-${_probeBytes - 1}',
      );
      final HttpClientResponse response = await request.close().timeout(
        _probeTimeout,
      );
      if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.partialContent) {
        await response.drain<void>().catchError((Object _) => response);
        return MirrorProbeResult.failed(id);
      }
      final String? mime = response.headers.contentType?.mimeType;
      if (mime == 'text/html') {
        await response.drain<void>().catchError((Object _) => response);
        return MirrorProbeResult.failed(id);
      }
      final Duration ttfb = stopwatch.elapsed;
      final Completer<void> done = Completer<void>();
      int received = 0;
      late StreamSubscription<List<int>> subscription;
      subscription = response.listen(
        (List<int> chunk) {
          received += chunk.length;
          if (received >= _probeBytes && !done.isCompleted) {
            unawaited(subscription.cancel());
            done.complete();
          }
        },
        onDone: () {
          if (!done.isCompleted) {
            done.complete();
          }
        },
        onError: (Object error) {
          if (!done.isCompleted) {
            done.completeError(error);
          }
        },
        cancelOnError: true,
      );
      await done.future.timeout(_probeTimeout);
      return MirrorProbeResult(
        id: id,
        ok: received > 0,
        ttfb: ttfb,
        total: stopwatch.elapsed,
      );
    } catch (_) {
      return MirrorProbeResult.failed(id);
    } finally {
      client.close(force: true);
    }
  }
}

/// 单个镜像的测速结果。
class MirrorProbeResult {
  const MirrorProbeResult({
    required this.id,
    required this.ok,
    this.ttfb,
    this.total = Duration.zero,
  });

  final String id;
  final bool ok;

  /// 响应头到达时间；总耗时相同时用它做次要排序。
  final Duration? ttfb;

  /// 拿到 512KB 探针数据的总耗时。
  final Duration total;

  static MirrorProbeResult failed(String id) {
    return MirrorProbeResult(id: id, ok: false);
  }
}
