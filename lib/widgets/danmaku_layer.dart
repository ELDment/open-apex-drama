import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app_state/danmaku_prefs.dart';
import '../models/danmaku_cue.dart';

part 'danmaku_layer_painter.dart';

/// 弹幕层：按播放位置把弹幕从右往左推过去，或固定在顶部/底部显示。
///
/// 位置来自 [position]（播放器的位置流），两次位置更新之间用 Ticker 线性
/// 补间——media_kit 的 position 大约几百毫秒才推一次，直接按它画会一跳一跳。
/// [playing] 为 false 时停止推进，保证暂停后弹幕与视频进度一起停住。
/// 只负责画，开关与数据加载由调用方控制。
class DanmakuLayer extends StatefulWidget {
  const DanmakuLayer({
    super.key,
    required this.cues,
    required this.position,
    required this.playing,
    this.travel = const Duration(seconds: 8),
    this.fontSize = 15,
    this.area = DanmakuArea.scroll,
    this.rate = 1.0,
  });

  /// 整集弹幕，按出现时间粗略排序（顺序不影响绘制，只影响轨道分配的观感）。
  final List<DanmakuCue> cues;

  /// 播放器当前进度。
  final ValueListenable<Duration> position;

  /// 是否正在播放；暂停时弹幕停住，恢复后继续对齐进度。
  final ValueListenable<bool> playing;

  /// 一条弹幕从右边缘走到左边缘外所需时间；顶部/底部弹幕的停留时长也用它。
  final Duration travel;

  final double fontSize;

  /// 出现位置：滚动 / 顶部 / 底部。
  final DanmakuArea area;

  /// 当前播放倍速：补间按倍速推进，避免高倍速下弹幕落后进度条。
  final double rate;

  @override
  State<DanmakuLayer> createState() => _DanmakuLayerState();
}

/// 计算弹幕层应占的矩形：按视频宽高做 contain 适配并居中。
///
/// 竖屏手机上下有黑边，弹幕只画在画面内，避免落到状态栏、标题栏或
/// 控制栏上；视频尺寸未知时退回整个可用区域。
Rect danmakuVideoRect({
  required Size area,
  required int videoWidth,
  required int videoHeight,
}) {
  if (videoWidth <= 0 || videoHeight <= 0) {
    return Offset.zero & area;
  }
  final double scale = math.min(
    area.width / videoWidth,
    area.height / videoHeight,
  );
  return Rect.fromCenter(
    center: Offset(area.width / 2, area.height / 2),
    width: videoWidth * scale,
    height: videoHeight * scale,
  );
}

/// 计算某一帧的弹幕时钟。
///
/// 暂停时停在最近一次真实播放位置 [base]，不再按流逝时间外推——这是
/// 「暂停后弹幕还在滚」的根因修复点。
@visibleForTesting
Duration danmakuClockAt({
  required Duration base,
  required Duration baseAtTick,
  required Duration tickNow,
  required bool playing,
  double rate = 1.0,
}) {
  if (!playing) {
    return base;
  }
  final int elapsedUs = (tickNow - baseAtTick).inMicroseconds;
  final int posUs = (elapsedUs * rate).round();
  final Duration pos = base + Duration(microseconds: posUs);
  return pos.isNegative ? Duration.zero : pos;
}

class _DanmakuLayerState extends State<DanmakuLayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);

  /// 补间后的播放位置，驱动重绘。
  final ValueNotifier<Duration> _clock = ValueNotifier<Duration>(Duration.zero);

  /// 最近一次来自播放器的真实位置，以及当时的 ticker 时间。
  Duration _base = Duration.zero;
  Duration _baseAtTick = Duration.zero;
  Duration _tickNow = Duration.zero;

  List<_CueLayout> _layouts = const <_CueLayout>[];
  List<DanmakuCue>? _preparedCues;
  Size? _preparedSize;
  DanmakuArea? _preparedArea;
  double? _preparedFontSize;
  Duration? _preparedTravel;

  /// 同一条轨道上两条弹幕的最小间隔，避免文字重叠。
  static const int _laneGapMs = 900;

  @override
  void initState() {
    super.initState();
    widget.position.addListener(_onPosition);
    widget.playing.addListener(_onPlayingChanged);
    _base = widget.position.value;
    _ticker.start();
  }

  @override
  void didUpdateWidget(covariant DanmakuLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position != widget.position) {
      oldWidget.position.removeListener(_onPosition);
      widget.position.addListener(_onPosition);
      _base = widget.position.value;
    }
    if (oldWidget.playing != widget.playing) {
      oldWidget.playing.removeListener(_onPlayingChanged);
      widget.playing.addListener(_onPlayingChanged);
      _onPlayingChanged();
    }
    if (oldWidget.rate != widget.rate) {
      // 倍速切换时按真实位置重新起算，避免沿用旧速率的时间差。
      _base = widget.position.value;
      _baseAtTick = _tickNow;
    }
  }

  @override
  void dispose() {
    widget.position.removeListener(_onPosition);
    widget.playing.removeListener(_onPlayingChanged);
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  void _onPosition() {
    // 以播放器位置为准重新对齐，跳转进度时立即生效。
    _base = widget.position.value;
    _baseAtTick = _tickNow;
  }

  /// 播放/暂停切换时把补间基准对齐到真实位置，避免恢复播放时跳一下。
  void _onPlayingChanged() {
    _base = widget.position.value;
    _baseAtTick = _tickNow;
    if (!widget.playing.value) {
      _clock.value = _base;
    }
  }

  void _onTick(Duration elapsed) {
    _tickNow = elapsed;
    // 暂停时不推进：position 流不再推送，若继续按流逝时间外推，
    // 弹幕就会脱离视频进度条一直滚。冻结在最近一次真实位置上。
    if (!widget.playing.value) {
      _baseAtTick = elapsed;
      _clock.value = _base;
      return;
    }
    final Duration pos = danmakuClockAt(
      base: _base,
      baseAtTick: _baseAtTick,
      tickNow: elapsed,
      playing: widget.playing.value,
      rate: widget.rate,
    );
    _clock.value = pos;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cues.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = Size(constraints.maxWidth, constraints.maxHeight);
        _ensurePrepared(size);
        return IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(
              size: size,
              painter: _DanmakuPainter(
                layouts: _layouts,
                clock: _clock,
                travel: widget.travel,
                fontSize: widget.fontSize,
                area: widget.area,
              ),
            ),
          ),
        );
      },
    );
  }

  /// 预排文本尺寸与轨道；尺寸、数据或渲染参数变化时才重算。
  void _ensurePrepared(Size size) {
    if (_preparedSize == size &&
        identical(_preparedCues, widget.cues) &&
        _preparedArea == widget.area &&
        _preparedFontSize == widget.fontSize &&
        _preparedTravel == widget.travel) {
      return;
    }
    _preparedSize = size;
    _preparedCues = widget.cues;
    _preparedArea = widget.area;
    _preparedFontSize = widget.fontSize;
    _preparedTravel = widget.travel;

    final bool fixed = widget.area != DanmakuArea.scroll;
    final int travelMs = widget.travel.inMilliseconds;
    final int laneGapMs = fixed ? 200 : _laneGapMs;
    final double lineHeight = widget.fontSize + 9;
    final int lanes = math.max(1, (size.height / lineHeight).floor());
    final List<int> laneFreeAt = List<int>.filled(lanes, -1000000);
    final List<_CueLayout> out = <_CueLayout>[];

    for (final DanmakuCue cue in widget.cues) {
      final TextPainter painter = TextPainter(
        text: TextSpan(
          text: cue.text,
          style: TextStyle(
            fontSize: widget.fontSize,
            height: 1.15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            shadows: const <Shadow>[
              Shadow(color: Color(0xCC000000), blurRadius: 3),
            ],
          ),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      if (painter.width <= 0) {
        painter.dispose();
        continue;
      }
      // 优先选已空闲的轨道，否则选最早空出来的那条，尽量均匀分布。
      int lane = 0;
      int earliest = 1 << 30;
      for (int i = 0; i < lanes; i++) {
        if (laneFreeAt[i] <= cue.offsetMs - laneGapMs) {
          lane = i;
          break;
        }
        if (laneFreeAt[i] < earliest) {
          earliest = laneFreeAt[i];
          lane = i;
        }
      }
      // 滚动弹幕占用轨道的时间很短（让出后仍可追尾）；停留式弹幕
      // 要等整条显示完，轨道才算空出来。
      laneFreeAt[lane] = cue.offsetMs + (fixed ? travelMs : 0);
      final double top = fixed && widget.area == DanmakuArea.bottom
          ? size.height - (lane + 1) * lineHeight - 2
          : lane * lineHeight + 2;
      out.add(_CueLayout(cue: cue, painter: painter, top: top));
    }
    for (final _CueLayout old in _layouts) {
      old.painter.dispose();
    }
    _layouts = out;
  }
}
