import 'package:apexduanju/app_state/danmaku_prefs.dart';
import 'package:apexduanju/models/danmaku_cue.dart';
import 'package:apexduanju/widgets/danmaku_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('暂停时弹幕时钟停在当前播放位置，不随流逝时间推进', () {
    const Duration base = Duration(seconds: 5);
    const Duration baseAtTick = Duration(seconds: 1);
    const Duration tickNow = Duration(seconds: 3);

    expect(
      danmakuClockAt(
        base: base,
        baseAtTick: baseAtTick,
        tickNow: tickNow,
        playing: false,
      ),
      base,
    );
    // 播放时按两次真实位置更新之间的流逝时间补间。
    expect(
      danmakuClockAt(
        base: base,
        baseAtTick: baseAtTick,
        tickNow: tickNow,
        playing: true,
      ),
      const Duration(seconds: 7),
    );
    // 倍速播放时补间同样按倍速推进，避免落后进度条。
    expect(
      danmakuClockAt(
        base: base,
        baseAtTick: baseAtTick,
        tickNow: tickNow,
        playing: true,
        rate: 2.0,
      ),
      const Duration(seconds: 9),
    );
  });

  test('竖屏手机按视频比例居中，弹幕避开上下黑边', () {
    final Rect rect = danmakuVideoRect(
      area: const Size(360, 800),
      videoWidth: 1920,
      videoHeight: 1080,
    );
    expect(rect.width, 360);
    expect(rect.height, closeTo(202.5, 0.01));
    // 垂直居中：上方留出状态栏与标题栏，下方留出控制栏。
    expect(rect.top, closeTo(298.75, 0.01));
  });

  test('视频尺寸未知时弹幕使用整个可用区域', () {
    final Rect rect = danmakuVideoRect(
      area: const Size(360, 800),
      videoWidth: 0,
      videoHeight: 0,
    );
    expect(rect, const Rect.fromLTWH(0, 0, 360, 800));
  });

  testWidgets('弹幕层随播放位置推进且不抛异常', (WidgetTester tester) async {
    final ValueNotifier<Duration> position = ValueNotifier<Duration>(
      Duration.zero,
    );
    final ValueNotifier<bool> playing = ValueNotifier<bool>(true);
    addTearDown(position.dispose);
    addTearDown(playing.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: DanmakuLayer(
              cues: const <DanmakuCue>[
                DanmakuCue(text: '第一条弹幕', offsetMs: 0),
                DanmakuCue(text: '第二条弹幕，稍长一点', offsetMs: 1200),
                DanmakuCue(text: '第三条弹幕', offsetMs: 3000),
              ],
              position: position,
              playing: playing,
            ),
          ),
        ),
      ),
    );

    // 依次推进位置：进入、中途、离开窗口，覆盖绘制分支。
    for (final int ms in <int>[0, 600, 1600, 4000, 12000]) {
      position.value = Duration(milliseconds: ms);
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(tester.takeException(), isNull);
    expect(find.byType(DanmakuLayer), findsOneWidget);
  });

  testWidgets('顶部与底部弹幕按新参数重排且不抛异常', (WidgetTester tester) async {
    final ValueNotifier<Duration> position = ValueNotifier<Duration>(
      Duration.zero,
    );
    final ValueNotifier<bool> playing = ValueNotifier<bool>(true);
    addTearDown(position.dispose);
    addTearDown(playing.dispose);

    Widget buildLayer(DanmakuArea area, double fontSize) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: DanmakuLayer(
              cues: const <DanmakuCue>[
                DanmakuCue(text: '顶部弹幕', offsetMs: 0),
                DanmakuCue(text: '会话弹幕', offsetMs: 1500),
              ],
              position: position,
              playing: playing,
              area: area,
              fontSize: fontSize,
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildLayer(DanmakuArea.top, 13));
    position.value = const Duration(milliseconds: 100);
    await tester.pump(const Duration(milliseconds: 16));

    await tester.pumpWidget(buildLayer(DanmakuArea.bottom, 19));
    position.value = const Duration(milliseconds: 1600);
    await tester.pump(const Duration(milliseconds: 16));

    expect(tester.takeException(), isNull);
  });

  test('位置偏差在 300ms 内线性补齐', () {
    expect(
      danmakuCorrectionProgress(
        startedAt: Duration.zero,
        now: Duration.zero,
        window: const Duration(milliseconds: 300),
      ),
      0,
    );
    expect(
      danmakuCorrectionProgress(
        startedAt: Duration.zero,
        now: const Duration(milliseconds: 150),
        window: const Duration(milliseconds: 300),
      ),
      closeTo(0.5, 0.001),
    );
    expect(
      danmakuCorrectionProgress(
        startedAt: Duration.zero,
        now: const Duration(milliseconds: 300),
        window: const Duration(milliseconds: 300),
      ),
      1,
    );
    expect(
      danmakuCorrectionProgress(
        startedAt: Duration.zero,
        now: const Duration(seconds: 1),
        window: const Duration(milliseconds: 300),
      ),
      1,
    );
  });

  testWidgets('位置小幅回跳不会瞬移，300ms 内平滑追平', (WidgetTester tester) async {
    final ValueNotifier<Duration> position = ValueNotifier<Duration>(
      Duration.zero,
    );
    final ValueNotifier<bool> playing = ValueNotifier<bool>(true);
    addTearDown(position.dispose);
    addTearDown(playing.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: DanmakuLayer(
              cues: const <DanmakuCue>[DanmakuCue(text: '平滑', offsetMs: 0)],
              position: position,
              playing: playing,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    final dynamic state = tester.state(find.byType(DanmakuLayer));
    final Duration before = state.clockForTest as Duration;

    // 播放器位置比补间时钟落后 200ms：不能瞬移回去，只能小幅修正。
    position.value = const Duration(milliseconds: 300);
    await tester.pump(const Duration(milliseconds: 16));
    final Duration after = state.clockForTest as Duration;
    expect((after - before).abs(), lessThan(const Duration(milliseconds: 50)));

    // 300ms 内把误差追平。
    await tester.pump(const Duration(milliseconds: 300));
    final Duration caughtUp = state.clockForTest as Duration;
    expect(caughtUp, greaterThanOrEqualTo(const Duration(milliseconds: 580)));
  });

  testWidgets('没有弹幕时不构建绘制层', (WidgetTester tester) async {
    final ValueNotifier<Duration> position = ValueNotifier<Duration>(
      Duration.zero,
    );
    final ValueNotifier<bool> playing = ValueNotifier<bool>(true);
    addTearDown(position.dispose);
    addTearDown(playing.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DanmakuLayer(
            cues: const <DanmakuCue>[],
            position: position,
            playing: playing,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    // 只看弹幕层内部：Material/Scaffold 自己也有 CustomPaint。
    expect(
      find.descendant(
        of: find.byType(DanmakuLayer),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
  });
}
