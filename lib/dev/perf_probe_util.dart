import 'dart:io';

import 'package:openhongguo/openhongguo.dart';

import '../data/repository/sdk_repositories.dart';
import '../models/catalog.dart';
import '../models/drama.dart';
import '../models/playback.dart';
import 'perf_probe.dart';

/// 计时包装：无论成功失败都把耗时写进日志。
Future<T> timed<T>(
  PerfLog out,
  String name,
  Future<T> Function() run,
) async {
  final Stopwatch clock = Stopwatch()..start();
  try {
    return await run();
  } finally {
    clock.stop();
    out.add('$name=${clock.elapsedMilliseconds}');
  }
}

/// 后完成者明显慢于先完成者时判为串行（并发时两者应接近）。
bool looksSerialized(int a, int b) {
  if (a < 0 || b < 0) {
    return false;
  }
  final int min = a < b ? a : b;
  final int max = a < b ? b : a;
  return min > 0 && max > min * 3 ~/ 2;
}

/// 优先取短剧频道的封面集合；拿不到时退回刚解析那部剧的单张封面。
Future<List<String>> coverUrls(
  OpenhongguoClient client,
  SdkCatalogRepository catalog,
  String seriesId,
) async {
  final List<String> urls = <String>[];
  try {
    final DramaPage page = await catalog.discoverFeed('短剧');
    for (final Drama drama in page.items) {
      if (drama.coverUrl.isNotEmpty) {
        urls.add(drama.coverUrl);
      }
    }
  } catch (_) {
    // 频道未接入时走下面的单张回退。
  }
  if (urls.isEmpty) {
    try {
      final Series series = await client.getSeries(seriesId);
      if (series.coverUrl.isNotEmpty) {
        urls.add(series.coverUrl);
      }
    } catch (_) {
      // 无封面可用，跳过封面阶段。
    }
  }
  return urls;
}

Future<bool> fetchBytes(HttpClient http, String url) async {
  final HttpClientRequest request = await http.getUrl(Uri.parse(url));
  final HttpClientResponse response = await request.close();
  await response.drain<void>();
  return response.statusCode == 200;
}

String streamUrl(PlaybackBundle bundle) {
  for (final StreamInfo stream in bundle.streams) {
    if (stream.url.isNotEmpty) {
      return stream.url;
    }
  }
  return '';
}

/// 本进程累计 CPU 时间（毫秒），两次采样之差 ÷ 墙钟即平均占用核数百分比。
Future<int> processCpuMs() async {
  try {
    final ProcessResult result = await Process.run('powershell', <String>[
      '-NoProfile',
      '-Command',
      // $pid 由 Dart 侧插值成真实进程号后拼进命令，PowerShell 收到的已是数字。
      '(Get-Process -Id $pid).TotalProcessorTime.TotalMilliseconds',
    ]);
    // TotalProcessorTime.TotalMilliseconds 是小数，直接 int.parse 会失败。
    return double.tryParse((result.stdout as String).trim())?.round() ?? -1;
  } catch (_) {
    return -1;
  }
}
