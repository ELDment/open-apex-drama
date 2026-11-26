import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'update_mirror_probe.dart';
import 'update_mirrors.dart';

/// 应用内下载更新包。
///
/// 启动后 [UpdateMirrorProbe] 会在后台测速三个镜像；下载时所有候选地址
/// （镜像 + 官方直链）同时发起，谁先下完用谁，其余立即取消。安装包只有
/// 二十兆左右，瓶颈在中转站带宽而非用户带宽，并发比逐个重试快得多。
/// 全部失败返回 null，由调用方降级为打开网页下载。
///
/// 镜像格式见 [UpdateMirrors]。
class UpdateDownloader {
  const UpdateDownloader._();

  /// 下载候选 URL：按 [order]（测速顺序）排列，官方直链始终最后。
  static List<String> candidateUrls(String assetUrl, {List<String>? order}) {
    return UpdateMirrors.candidates(assetUrl, order: order);
  }

  /// 流式下载到临时目录，成功返回文件完整路径。
  ///
  /// [onProgress] 参数 0.0~1.0（服务端未返回长度时上报 -1 表示不确定），
  /// 取所有并发流里最快的那个。单个候选连接超时 15s、整体无进度判定
  /// 超时 30s；全部候选失败才返回 null。
  static Future<String?> download(
    String assetUrl, {
    String? fileName,
    void Function(double progress)? onProgress,
    HttpClient? client,

    /// 测试注入用；默认系统临时目录。
    Directory? directory,

    /// 测试注入用；默认中转站 + 官方直链（见 [candidateUrls]）。
    List<String>? urls,
  }) async {
    final String name = fileName ?? assetUrl.split('/').last.split('?').first;
    final Directory dir = directory ?? await getTemporaryDirectory();
    final String savePath =
        '${dir.path}${Platform.pathSeparator}apexduanju-update-$name';

    // 已完整下载过（文件名含版本，不会串版本）就直接复用：安装授权失败
    // 后用户再次点击更新时无需重新下载。下载中写入 .part，完成才改名，
    // 因此存在即代表文件完整。
    final File cached = File(savePath);
    if (await cached.exists() && await cached.length() > 0) {
      onProgress?.call(1);
      return savePath;
    }

    final List<String>? order =
        urls == null ? await UpdateMirrorProbe.preferredOrder() : null;
    final List<String> candidates =
        urls ?? candidateUrls(assetUrl, order: order);
    return _raceDownload(candidates, savePath, onProgress, client);
  }

  /// 所有候选并发下载，首个完成者胜出并落为正式文件，其余流作废。
  static Future<String?> _raceDownload(
    List<String> urls,
    String savePath,
    void Function(double progress)? onProgress,
    HttpClient? externalClient,
  ) async {
    final HttpClient client = externalClient ?? HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      final Completer<String?> winner = Completer<String?>();
      final _RaceState state = _RaceState(urls.length);
      for (int i = 0; i < urls.length; i++) {
        unawaited(
          _tryDownload(
            urls[i],
            savePath,
            '$savePath.$i.part',
            client,
            onProgress: (double value) {
              final double? report = state.report(value);
              if (report != null) {
                onProgress?.call(report);
              }
            },
            isCancelled: () => winner.isCompleted,
          ).then((String? path) {
            if (path != null) {
              if (!winner.isCompleted) {
                winner.complete(path);
              }
            } else if (state.allSettled() && !winner.isCompleted) {
              winner.complete(null);
            }
          }),
        );
      }
      return await winner.future;
    } finally {
      // force 关闭会掐断落选流还在传输的连接。
      if (externalClient == null) {
        client.close(force: true);
      }
    }
  }

  static Future<String?> _tryDownload(
    String url,
    String savePath,
    String partPath,
    HttpClient client, {
    required void Function(double progress) onProgress,
    required bool Function() isCancelled,
  }) async {
    try {
      final HttpClientRequest request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.userAgentHeader, 'ApexDrama-App');
      request.followRedirects = true;
      final HttpClientResponse response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>().catchError((Object _) => response);
        return null;
      }
      final int? total = response.contentLength > 0
          ? response.contentLength
          : null;
      final IOSink sink = File(partPath).openWrite();
      int received = 0;
      Timer? stall;
      try {
        final Completer<void> done = Completer<void>();
        stall = Timer.periodic(const Duration(seconds: 30), (Timer timer) {
          // 30 秒收不到任何字节视为该候选失败，终止换下一个。
          if (!done.isCompleted) {
            timer.cancel();
            done.completeError(const SocketException('download stalled'));
          }
        });
        late StreamSubscription<List<int>> sub;
        sub = response.listen(
          (List<int> chunk) {
            if (isCancelled()) {
              sub.cancel();
              if (!done.isCompleted) {
                done.complete();
              }
              return;
            }
            received += chunk.length;
            sink.add(chunk);
            onProgress(
              total == null ? -1 : (received / total).clamp(0.0, 1.0),
            );
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
        await done.future;
        await sub.cancel();
        await sink.flush();
        await sink.close();
        // 已有别的候选先下完：丢弃自己的半截文件，不覆盖胜出的正式文件。
        if (isCancelled()) {
          await _deletePart(partPath);
          return null;
        }
        // 完整收完才改名为正式文件，避免下次误复用半截包。
        final File target = File(savePath);
        if (await target.exists()) {
          await target.delete();
        }
        await File(partPath).rename(savePath);
        return savePath;
      } catch (_) {
        await sink.close().catchError((Object _) => sink);
        await _deletePart(partPath);
        return null;
      } finally {
        stall?.cancel();
      }
    } catch (_) {
      return null;
    }
  }

  static Future<void> _deletePart(String partPath) async {
    final File partial = File(partPath);
    if (await partial.exists()) {
      await partial.delete().catchError((Object _) => partial);
    }
  }
}

/// 并发下载的共享状态：进度只上报最快的流，并统计是否全部失败。
class _RaceState {
  _RaceState(this._total);

  final int _total;
  double _best = 0;
  int _settled = 0;

  /// 进度比当前最快的高才上报；-1（长度未知）只在尚无已知进度时上报。
  double? report(double value) {
    if (value < 0 ? _best > 0 : value <= _best) {
      return null;
    }
    _best = value < 0 ? 0 : value;
    return value;
  }

  bool allSettled() => ++_settled >= _total;
}
