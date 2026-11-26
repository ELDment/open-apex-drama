import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'perf_probe_bench.dart';

/// 性能基线探针：`--dart-define=PERF_PROBE=true` 时才编进启动流程。
///
/// 它替代正常界面，跑一段固定脚本后把结果逐行写到 `%TEMP%\apex-perf.log`
/// 并退出，因此不会和首页/分类页自己的请求抢队列。量的东西：
///
/// 1. **SDK 桥接是否把并发调用串行化**——同时发起两个调用，看后完成的那个
///    是≈两者之和（串行）还是≈较慢的那个（并发）；
/// 2. **详情页聚合、取址、首帧**的真实耗时；
/// 3. **软渲染 vs GPU 渲染**的首帧与播放期 CPU 占用；
/// 4. **封面并发下载**耗时（纯 dart:io，用来判断是否网络层问题）。
///
/// 取址额度有限，整段脚本只解析一集。
const bool kPerfProbeEnabled = bool.fromEnvironment('PERF_PROBE');

/// 探针宿主：直接在 [runApp] 里替换正常界面。
class PerfProbeHost extends StatefulWidget {
  const PerfProbeHost({super.key});

  @override
  State<PerfProbeHost> createState() => _PerfProbeHostState();
}

class _PerfProbeHostState extends State<PerfProbeHost> {
  /// 当前挂到界面上的渲染输出。首帧测量必须真的挂一个 [Video]：
  /// media_kit 要等纹理被布局才会推进到出画，只在 Dart 侧 new 一个控制器时
  /// `Player.open` 会一直等不到 file-loaded。
  VideoController? _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_run()));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 480,
            height: 270,
            child: _controller == null
                ? const Text('perf probe running')
                : Video(controller: _controller!),
          ),
        ),
      ),
    );
  }

  void _mount(VideoController? controller) {
    if (!mounted) {
      return;
    }
    setState(() => _controller = controller);
  }

  Future<void> _run() async {
    final PerfLog log = PerfLog();
    final Stopwatch total = Stopwatch()..start();
    log.add('generated_at=${DateTime.now().toIso8601String()}');
    log.add(
      'platform=${Platform.operatingSystem} ${Platform.version.split(' ').first}',
    );
    try {
      await runPerfBench(log, _mount);
    } catch (error, stack) {
      log.add('fatal=${oneLine(error)}');
      debugPrint('[perf] fatal $error\n$stack');
    }
    total.stop();
    log.add('total_ms=${total.elapsedMilliseconds}');
    exit(0);
  }
}

/// 逐行落盘的性能日志：每完成一项立刻写文件并打日志，某个阶段卡住时
/// 也能从最后一行看出卡在哪里。
class PerfLog {
  PerfLog() {
    try {
      File(_logPath).writeAsStringSync('# ApexDrama perf probe\n');
    } catch (error) {
      debugPrint('[perf] open log failed: $error');
    }
  }

  static String get _logPath =>
      '${Directory.systemTemp.path}${Platform.pathSeparator}apex-perf.log';

  final List<String> lines = <String>[];

  void add(String line) {
    lines.add(line);
    debugPrint('[perf] $line');
    try {
      File(_logPath).writeAsStringSync('$line\n', mode: FileMode.append);
    } catch (error) {
      debugPrint('[perf] append failed: $error');
    }
  }
}

/// 异常压成单行，便于写进日志。
String oneLine(Object error) => error.toString().replaceAll('\n', ' | ');
