import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:openhongguo/openhongguo.dart';

import '../data/remote/openhongguo_service.dart';
import '../data/repository/sdk_repositories.dart';
import '../models/catalog.dart';
import '../models/playback.dart';
import '../player/video_output.dart';
import 'perf_probe.dart';
import 'perf_probe_util.dart';

/// 固定测量脚本。阶段之间串行，阶段内部尽量复现应用真实链路。
Future<void> runPerfBench(
  PerfLog out,
  void Function(VideoController?) mount,
) async {
  final OpenhongguoService service = OpenhongguoService.instance;
  final SdkCatalogRepository catalog = SdkCatalogRepository();

  // ---- P1 客户端创建 + 首个目录请求（含可能的一次匿名游客注册） ----
  out.add('phase=p1_client');
  final OpenhongguoClient client = await timed(
    out,
    'client_create_ms',
    service.client,
  );
  String seriesId = '';
  try {
    final DramaPage page = await timed(
      out,
      'discover_first_ms',
      () => catalog.discoverFeed('推荐'),
    );
    if (page.items.isNotEmpty) {
      seriesId = page.items.first.id;
    }
  } catch (error) {
    out.add('discover_first_error=${oneLine(error)}');
    return;
  }
  if (seriesId.isEmpty) {
    out.add('skip=no_series');
    return;
  }
  await timed(out, 'discover_warm_ms', () => catalog.discoverFeed('推荐'));

  // ---- P2 并发双调用：后完成者的耗时暴露是否被串行化 ----
  out.add('phase=p2_pair');
  final Stopwatch pairClock = Stopwatch()..start();
  int seasonsAt = -1;
  int recommendAt = -1;
  await Future.wait<void>(<Future<void>>[
    client
        .seasons(seriesId)
        .then<void>((_) => seasonsAt = pairClock.elapsedMilliseconds)
        .catchError(
          (Object error) => out.add('seasons_error=${oneLine(error)}'),
        ),
    client
        .seriesRecommend(seriesId)
        .then<void>((_) => recommendAt = pairClock.elapsedMilliseconds)
        .catchError(
          (Object error) => out.add('recommend_error=${oneLine(error)}'),
        ),
  ]);
  out.add('pair_wall_ms=${pairClock.elapsedMilliseconds}');
  out.add('pair_seasons_done_ms=$seasonsAt');
  out.add('pair_recommend_done_ms=$recommendAt');
  // 串行判据：后完成者 ≈ 两者之和；并发判据：后完成者 ≈ 较慢的那个。
  out.add('pair_serialized=${looksSerialized(seasonsAt, recommendAt)}');

  // ---- P3 详情页聚合（应用真实链路：4 个请求） ----
  out.add('phase=p3_detail');
  try {
    await timed(out, 'detail_aggregate_ms', () => catalog.seriesDetail(seriesId));
  } catch (error) {
    out.add('detail_error=${oneLine(error)}');
  }

  // ---- P4 分集 + 取址（播放前的两段网络等待） ----
  out.add('phase=p4_resolve');
  final SdkPlaybackRepository playback = SdkPlaybackRepository();
  List<EpisodeInfo> episodes = const <EpisodeInfo>[];
  try {
    episodes = await timed(out, 'episodes_ms', () => playback.episodes(seriesId));
  } catch (error) {
    out.add('episodes_error=${oneLine(error)}');
  }
  if (episodes.isEmpty) {
    out.add('skip=no_episodes');
    return;
  }
  final PlaybackBundle bundle = await timed(
    out,
    'resolve_ms',
    () => playback.resolve(episodes.first.id),
  );
  final String url = streamUrl(bundle);
  if (url.isEmpty) {
    out.add('skip=no_stream_url');
    return;
  }

  // ---- P5 首帧：当前线上配置（软渲染） vs 默认配置（GPU） ----
  out.add('phase=p5_first_frame');
  final Map<String, int> soft = await timed(
    out,
    'first_frame_software_total_ms',
    () => measureFirstFrame(bundle, url, hardware: false, mount: mount),
  );
  recordFirstFrame(out, 'sw', soft);
  final Map<String, int> gpu = await timed(
    out,
    'first_frame_hardware_total_ms',
    () => measureFirstFrame(bundle, url, hardware: true, mount: mount),
  );
  recordFirstFrame(out, 'hw', gpu);

  // ---- P6 封面并发下载（纯 dart:io，与 SDK 无关） ----
  out.add('phase=p6_covers');
  final List<String> covers = await coverUrls(client, catalog, seriesId);
  if (covers.isEmpty) {
    out.add('skip=no_covers');
    return;
  }
  final List<String> sample = covers.take(20).toList();
  final Stopwatch coverClock = Stopwatch()..start();
  final HttpClient http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10);
  int ok = 0;
  int failed = 0;
  try {
    await Future.wait<void>(<Future<void>>[
      for (final String cover in sample)
        fetchBytes(http, cover).then<void>(
          (bool hit) => hit ? ok++ : failed++,
          onError: (Object _) => failed++,
        ),
    ]);
  } finally {
    http.close(force: true);
  }
  out.add('covers_count=${sample.length}');
  out.add('covers_wall_ms=${coverClock.elapsedMilliseconds}');
  out.add('covers_ok=$ok covers_failed=$failed');
}

/// 用同一路流开一次播放器，返回控制创建 / 挂载 / open / 首帧 / 播放期
/// CPU 各阶段耗时。
Future<Map<String, int>> measureFirstFrame(
  PlaybackBundle bundle,
  String url, {
  required bool hardware,
  required void Function(VideoController?) mount,
}) async {
  final Player player = Player();
  final List<String> errors = <String>[];
  final StreamSubscription<String> errorSub = player.stream.error.listen(
    errors.add,
  );
  final Stopwatch clock = Stopwatch()..start();
  final VideoController controller = hardware
      ? VideoController(player)
      : VideoController(
          player,
          configuration: videoOutputConfiguration(VideoOutputMode.texture),
        );
  final int controllerMs = clock.elapsedMilliseconds;
  try {
    // 挂上 Video 再开流：不挂纹理时 media_kit 等不到出画阶段。
    mount(controller);
    await WidgetsBinding.instance.endOfFrame;
    final int mountMs = clock.elapsedMilliseconds;
    if (bundle.hasKey) {
      await (player.platform as dynamic).setProperty(
        'demuxer-lavf-o',
        'decryption_key=${bundle.contentKeyHex}',
      );
    }
    await (player.platform as dynamic).setProperty('user-agent', kCdnUserAgent);
    int openMs = -1;
    bool openTimedOut = false;
    try {
      await player.open(Media(url)).timeout(const Duration(seconds: 30));
      openMs = clock.elapsedMilliseconds;
    } on TimeoutException {
      openTimedOut = true;
    }
    int frameMs = -1;
    if (!openTimedOut) {
      try {
        await player.stream.width
            .firstWhere((int? width) => (width ?? 0) > 0)
            .timeout(const Duration(seconds: 25));
        frameMs = clock.elapsedMilliseconds;
      } on TimeoutException {
        frameMs = -1;
      }
    }
    // 出画后再播 6 秒，量平均 CPU 占用：软渲染与 GPU 渲染的差别主要在这里，
    // 而不在首帧（首帧主要等取流/解码起播）。
    final int cpuBefore = await processCpuMs();
    final Duration posBefore = player.state.position;
    await Future<void>.delayed(const Duration(seconds: 6));
    final int cpuAfter = await processCpuMs();
    final Duration posAfter = player.state.position;
    final int cpuPct = cpuBefore < 0 || cpuAfter < 0
        ? -1
        : ((cpuAfter - cpuBefore) * 100 ~/ 6000);
    return <String, int>{
      'controller': controllerMs,
      'mount': mountMs,
      'open': openMs,
      'open_timeout': openTimedOut ? 1 : 0,
      'first_frame': frameMs,
      'errors': errors.length,
      'cpu_pct': cpuPct,
      'played_ms': (posAfter - posBefore).inMilliseconds,
    };
  } finally {
    mount(null);
    await errorSub.cancel();
    try {
      await player.dispose();
    } catch (_) {
      // 释放失败不影响已记录的数据。
    }
    if (errors.isNotEmpty) {
      debugPrint('[perf] mpv errors: ${errors.take(3).join(' / ')}');
    }
  }
}

void recordFirstFrame(PerfLog out, String tag, Map<String, int> result) {
  out.add('${tag}_controller_ms=${result['controller']}');
  out.add('${tag}_mount_ms=${result['mount']}');
  out.add('${tag}_open_ms=${result['open']}');
  out.add('${tag}_open_timeout=${result['open_timeout']}');
  out.add('${tag}_first_frame_ms=${result['first_frame']}');
  out.add('${tag}_mpv_errors=${result['errors']}');
  out.add('${tag}_play_cpu_pct=${result['cpu_pct']}');
  out.add('${tag}_played_ms=${result['played_ms']}');
}
