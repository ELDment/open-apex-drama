part of 'danmaku_layer.dart';

/// 一条弹幕预排后的位置与已 layout 的文本。
class _CueLayout {
  _CueLayout({required this.cue, required this.painter, required this.top});

  final DanmakuCue cue;
  final TextPainter painter;
  final double top;

  double get width => painter.width;
}

/// 单条轨道的占用状态，用于按文字宽度做碰撞检测。
class _Lane {
  bool occupied = false;
  int startMs = 0;
  double width = 0;
}

/// 弹幕绘制器：滚动弹幕从右往左，顶部/底部弹幕水平居中停留。
class _DanmakuPainter extends CustomPainter {
  _DanmakuPainter({
    required this.layouts,
    required this.clock,
    required this.travel,
    required this.fontSize,
    required this.area,
  }) : super(repaint: clock);

  final List<_CueLayout> layouts;
  final ValueListenable<Duration> clock;
  final Duration travel;
  final double fontSize;
  final DanmakuArea area;

  @override
  void paint(Canvas canvas, Size size) {
    final double ms = clock.value.inMilliseconds.toDouble();
    final double travelMs = travel.inMilliseconds.toDouble();
    final bool fixed = area != DanmakuArea.scroll;
    for (final _CueLayout layout in layouts) {
      final double start = layout.cue.offsetMs.toDouble();
      if (ms < start || ms > start + travelMs) {
        continue;
      }
      final double x;
      if (fixed) {
        // 顶部/底部弹幕水平居中，停留 travel 时长后消失。
        x = (size.width - layout.width) / 2;
      } else {
        final double progress = (ms - start) / travelMs;
        x = size.width - progress * (size.width + layout.width);
        if (x > size.width || x + layout.width < 0) {
          continue;
        }
      }
      layout.painter.paint(canvas, Offset(x, layout.top));
    }
  }

  @override
  bool shouldRepaint(covariant _DanmakuPainter oldDelegate) {
    return oldDelegate.layouts != layouts ||
        oldDelegate.travel != travel ||
        oldDelegate.fontSize != fontSize ||
        oldDelegate.area != area;
  }
}
