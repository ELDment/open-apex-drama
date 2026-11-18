import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'update_mirror_probe.dart';
import 'update_mirrors.dart';

/// 应用内下载更新包。
///
/// 启动后 [UpdateMirrorProbe] 会在后台测速三个镜像；下载时按测速结果
/// 从快到慢逐个尝试，全部失败回退官方直链；仍失败则返回 null，由调用方
/// 降级为打开网页下载。
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
  /// [onProgress] 参数 0.0~1.0（服务端未返回长度时上报 -1 表示不确定）。
  /// 单个候选连接超时 15s、整体无进度判定超时 30s；任一候选失败自动换
  /// 下一个（含中转站返回 4xx/5xx 的情况）。
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
    for (final String url in urls ?? candidateUrls(assetUrl, order: order)) {
      final String? result = await _tryDownload(
        url,
        savePath,
        onProgress,
        client,
      );
      if (result != null) {
        return result;
      }
    }
    return null;
  }

  static Future<String?> _tryDownload(
    String url,
    String savePath,
    void Function(double progress)? onProgress,
    HttpClient? externalClient,
  ) async {
    final HttpClient client = externalClient ?? HttpClient();
    final String partPath = '$savePath.part';
    try {
      client.connectionTimeout = const Duration(seconds: 15);
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
            received += chunk.length;
            sink.add(chunk);
            onProgress?.call(
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
        // 完整收完才改名为正式文件，避免下次误复用半截包。
        final File target = File(savePath);
        if (await target.exists()) {
          await target.delete();
        }
        await File(partPath).rename(savePath);
        return savePath;
      } catch (_) {
        await sink.close().catchError((Object _) => sink);
        final File partial = File(partPath);
        if (await partial.exists()) {
          await partial.delete().catchError((Object _) => partial);
        }
        return null;
      } finally {
        stall?.cancel();
      }
    } catch (_) {
      return null;
    } finally {
      if (externalClient == null) {
        client.close(force: true);
      }
    }
  }
}
