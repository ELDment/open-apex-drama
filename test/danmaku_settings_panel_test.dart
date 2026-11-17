import 'package:apexduanju/app_state/danmaku_prefs.dart';
import 'package:apexduanju/widgets/danmaku_settings_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('桌面端弹幕面板紧凑横排且不溢出', (WidgetTester tester) async {
    danmakuSettingsNotifier.value = const DanmakuSettings();
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: DanmakuSettingsPanel())),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // 字号与速度档位横向排布：相邻档位在同一行。
    expect(
      tester.getCenter(find.text('11')).dy,
      tester.getCenter(find.text('13')).dy,
    );
    expect(
      tester.getCenter(find.text('很慢')).dy,
      tester.getCenter(find.text('慢')).dy,
    );
    // 出现位置三宫格同样横排。
    expect(
      tester.getCenter(find.text('顶部')).dy,
      tester.getCenter(find.text('底部')).dy,
    );

    // 面板不应占满整个视口（旧实现每个档位独占一行，内容高度接近 700）。
    // Dialog 外壳会撑满可用空间，这里量真正的内容区。
    final Size content = tester.getSize(find.byType(SingleChildScrollView));
    expect(content.height, lessThan(480));
    expect(content.width, lessThanOrEqualTo(440));
  });
}
