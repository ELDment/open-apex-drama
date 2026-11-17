import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apexduanju/data/repository/mock_repositories.dart';
import 'package:apexduanju/providers/data_providers.dart';
import 'package:apexduanju/screens/home_screen.dart';
import 'package:apexduanju/theme/app_theme.dart';
import 'package:apexduanju/widgets/drama_card.dart';

/// 当前网格中的剧集顺序（按渲染顺序取 seriesId）。
List<String> _gridOrder(WidgetTester tester) => tester
    .widgetList<DramaCard>(find.byType(DramaCard))
    .map((DramaCard card) => card.drama.id)
    .toList(growable: false);

Future<void> _pumpHome(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      // 固定 mock 数据源，避免测试环境触碰网络与原生 SDK。
      overrides: [
        catalogRepositoryProvider.overrideWithValue(MockCatalogRepository()),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: HomeScreen()),
      ),
    ),
  );
  // 推进假时钟让 mock 仓库的延迟数据落地。
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

Future<void> _tapShuffle(WidgetTester tester) async {
  await tester.tap(find.text('换一换'));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('点击「换一换」后换成另一批内容', (WidgetTester tester) async {
    await _pumpHome(tester);
    final Set<String> before = _gridOrder(tester).toSet();
    expect(before.length, greaterThan(1));

    await _tapShuffle(tester);

    final Set<String> after = _gridOrder(tester).toSet();
    // 关键诉求：内容本身要变，而不是同一批重新排序。
    expect(after.intersection(before).length, lessThan(before.length));
  });

  testWidgets('连续点击「换一换」每次都换一批', (WidgetTester tester) async {
    await _pumpHome(tester);
    Set<String> previous = _gridOrder(tester).toSet();

    for (int click = 1; click <= 3; click++) {
      await _tapShuffle(tester);
      final Set<String> current = _gridOrder(tester).toSet();
      expect(
        current.intersection(previous).length,
        lessThan(previous.length),
        reason: '第 $click 次点击没有换内容',
      );
      previous = current;
    }
  });

  testWidgets('切换频道后「换一换」仍然生效', (WidgetTester tester) async {
    await _pumpHome(tester);

    await tester.tap(find.text('短剧'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    final Set<String> before = _gridOrder(tester).toSet();
    expect(before.length, greaterThan(1));

    await _tapShuffle(tester);

    final Set<String> after = _gridOrder(tester).toSet();
    expect(after.intersection(before).length, lessThan(before.length));
  });
}
