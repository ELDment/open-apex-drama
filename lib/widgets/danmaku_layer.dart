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

/// 位置更新后的偏差在 [window] 内线性补齐：0 表示刚开始，1 表示已追平。
@visibleForTesting
double danmakuCorrectionProgress({
  required Duration startedAt,
  required Duration now,
  required Duration window,
}) {
  if (window <= Duration.zero) {
    return 1;
  }
  final int elapsedUs = (now - startedAt).inMicroseconds;
  if (elapsedUs <= 0) {
    return 0;
  }
  return (elapsedUs / window.inMicroseconds).clamp(0.0, 1.0);
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

  /// 位置更新与补间时钟的小幅偏差，在 [_correctionWindow] 内线性补齐，
  /// 避免每 500ms 的位置事件把弹幕瞬移回播放器位置。
  Duration _correction = Duration.zero;
  Duration _correctionStartedAtTick = Duration.zero;

  /// 偏差超过该值视为用户跳转进度，直接对齐。
  static const Duration _hardSeekThreshold = Duration(seconds: 1);
  static const Duration _correctionWindow = Duration(milliseconds: 300);

  @visibleForTesting
  Duration get clockForTest => _clock.value;

  List<_CueLayout> _layouts = const <_CueLayout>[];
  List<DanmakuCue>? _preparedCues;
  Size? _preparedSize;
  DanmakuArea? _preparedArea;
  double? _preparedFontSize;
  Duration? _preparedTravel;

  /// 同一轨道内两条滚动弹幕的最小水平间距（像素）。
  static const double _laneGapPx = 24;

  /// 弹幕只占视频顶部/底部这一比例的区域，不铺满画面。
  static const double _laneBandFraction = 0.35;

  /// 单侧最多几条轨道。
  static const int _maxLanes = 5;

  @visibleForTesting
  int get layoutCountForTest => _layouts.length;

  @visibleForTesting
  List<double> get layoutTopsForTest =>
      _layouts.map((_CueLayout layout) => layout.top).toList();

  @visibleForTesting
  List<double> get layoutWidthsForTest =>
      _layouts.map((_CueLayout layout) => layout.width).toList();

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
      _correction = Duration.zero;
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
      _correction = Duration.zero;
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
    final Duration target = widget.position.value;
    final Duration current = _clock.value;
    final Duration drift = target - current;

    // 暂停或用户跳转进度：直接对齐，弹幕应立刻跟到新位置。
    if (!widget.playing.value || drift.abs() > _hardSeekThreshold) {
      _base = target;
      _baseAtTick = _tickNow;
      _correction = Duration.zero;
      _clock.value = target;
      return;
    }

    // 正常播放中的小幅偏差：保留当前补间位置，把误差摊到接下来
    // 300ms 里，避免每次 position 更新（约 500ms）都瞬移一下。
    _base = current;
    _baseAtTick = _tickNow;
    _correction = drift;
    _correctionStartedAtTick = _tickNow;
  }

  /// 播放/暂停切换时把补间基准对齐到真实位置，避免恢复播放时跳一下。
  void _onPlayingChanged() {
    _base = widget.position.value;
    _baseAtTick = _tickNow;
    _correction = Duration.zero;
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
    _clock.value = _applyCorrection(pos, elapsed);
  }

  /// 把位置更新时的偏差在 [_correctionWindow] 内线性吃掉；补完后把
  /// 误差并入基准，避免下一帧又跳回去。
  Duration _applyCorrection(Duration pos, Duration tickNow) {
    final Duration correction = _correction;
    if (correction == Duration.zero) {
      return pos;
    }
    final double progress = danmakuCorrectionProgress(
      startedAt: _correctionStartedAtTick,
      now: tickNow,
      window: _correctionWindow,
    );
    if (progress >= 1) {
      _base += correction;
      _baseAtTick = tickNow;
      _correction = Duration.zero;
      final Duration corrected = pos + correction;
      return corrected.isNegative ? Duration.zero : corrected;
    }
    final Duration corrected = pos + correction * progress;
    return corrected.isNegative ? Duration.zero : corrected;
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
    final double lineHeight = widget.fontSize * 1.15 + 8;
    final double bandHeight = size.height * _laneBandFraction;
    final int lanes = math.max(
      1,
      math.min(_maxLanes, (bandHeight / lineHeight).floor()),
    );
    final List<_Lane> laneStates = List<_Lane>.generate(lanes, (_) => _Lane());
    final List<_CueLayout> out = <_CueLayout>[];
    final List<DanmakuCue> cues = List<DanmakuCue>.of(widget.cues)
      ..sort((DanmakuCue a, DanmakuCue b) => a.offsetMs.compareTo(b.offsetMs));

    for (final DanmakuCue cue in cues) {
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
        ellipsis: '…',
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width * 0.75);
      if (painter.width <= 0) {
        painter.dispose();
        continue;
      }

      // 找一条真正能放下的轨道；全满就丢弃这一条，绝不强行叠字。
      int lane = -1;
      for (int i = 0; i < lanes; i++) {
        final _Lane state = laneStates[i];
        if (!state.occupied) {
          lane = i;
          break;
        }
        if (fixed) {
          // 停留式弹幕占满整个显示时长。
          if (cue.offsetMs - state.startMs >= travelMs) {
            lane = i;
            break;
          }
        } else {
          // 按文字宽度和速度算：上一条的尾巴至少离开右边距 [_laneGapPx]
          // 才允许下一条进入，避免长弹幕在右侧撞在一起。
          final double clearMs =
              (state.width + _laneGapPx) *
              travelMs /
              (size.width + state.width);
          if (cue.offsetMs - state.startMs >= clearMs) {
            lane = i;
            break;
          }
        }
      }
      if (lane < 0) {
        painter.dispose();
        continue;
      }

      laneStates[lane]
        ..occupied = true
        ..startMs = cue.offsetMs
        ..width = painter.width;
      final double top = widget.area == DanmakuArea.bottom
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
