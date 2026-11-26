import 'package:apexduanju/data/mock_data.dart';
import 'package:apexduanju/data/repository/mock_repositories.dart';
import 'package:apexduanju/models/drama.dart';
import 'package:apexduanju/providers/data_providers.dart';
import 'package:apexduanju/screens/player_screen.dart';
import 'package:apexduanju/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 播放页点击序列回归：单击/双击分离、双击不被拆成两次单击。
///
/// 断言用「锁定入口按钮」（tooltip '锁定控制层'）是否在树上——它只在
/// 移动端横屏且控制层可见时渲染，正好可作为控制层可见性的探针。
void main() {
  final Drama drama = mockFeatured.first;

  // widget 测试里 defaultTargetPlatform 默认就是 android，无需覆盖。

  Future<void> pumpPlayer(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(MockCatalogRepository()),
          playbackRepositoryProvider.overrideWithValue(
            MockPlaybackRepository(),
          ),
          rankRepositoryProvider.overrideWithValue(MockRankRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          home: PlayerScreen(drama: drama),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

  Finder lockEntry() => find.byTooltip('锁定控制层');

  /// 控制层可见性探针：读包裹锁定入口的 AnimatedOpacity 实际透明度
  /// （控制层隐藏时控件仍留在树上，只是 opacity=0 且不接收指针）。
  bool controlsVisible(WidgetTester tester) {
    final Finder wrapper = find
        .ancestor(of: lockEntry(), matching: find.byType(AnimatedOpacity))
        .first;
    return tester.widget<AnimatedOpacity>(wrapper).opacity > 0.5;
  }

  testWidgets('横屏单击切换控制栏，320ms 后生效', (WidgetTester tester) async {
    await pumpPlayer(tester, const Size(800, 400));
    expect(controlsVisible(tester), isTrue);

    await tester.tapAt(const Offset(400, 120));
    // 未过双击窗口前不应立即执行。
    await tester.pump(const Duration(milliseconds: 100));
    expect(controlsVisible(tester), isTrue);
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pumpAndSettle();
    expect(controlsVisible(tester), isFalse);
  });

  testWidgets('横屏双击只切一次，不拆成两次单击', (WidgetTester tester) async {
    await pumpPlayer(tester, const Size(800, 400));
    expect(controlsVisible(tester), isTrue);

    // 两次快速点击（间隔小于 320ms）：应识别为双击，控制栏保持不变。
    await tester.tapAt(const Offset(400, 120));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tapAt(const Offset(400, 120));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(controlsVisible(tester), isTrue);
  });

  testWidgets('竖屏双击不切播放状态（不出现播放又暂停）', (WidgetTester tester) async {
    await pumpPlayer(tester, const Size(400, 800));

    await tester.tapAt(const Offset(200, 260));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tapAt(const Offset(200, 260));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
