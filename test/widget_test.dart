import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apexduanju/app.dart';
import 'package:apexduanju/data/repository/mock_repositories.dart';
import 'package:apexduanju/providers/data_providers.dart';

void main() {
  testWidgets('renders the five tab shell and switches pages', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        // 固定 mock 数据源，避免测试环境触碰网络与原生 SDK。
        overrides: [
          catalogRepositoryProvider.overrideWithValue(MockCatalogRepository()),
          playbackRepositoryProvider
              .overrideWithValue(MockPlaybackRepository()),
          rankRepositoryProvider.overrideWithValue(MockRankRepository()),
        ],
        child: const ApexApp(),
      ),
    );
    // 推进假时钟让 mock 仓库的延迟数据落地（pumpAndSettle 不推进无帧时段）。
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('为你推荐'), findsOneWidget);
    for (final String label in <String>['首页', '分类', '榜单', '追剧', '我的']) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('最近更新'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 1200));
    await tester.pumpAndSettle();

    await tester.tap(find.text('分类'));
    await tester.pumpAndSettle();
    expect(find.text('按题材找到下一部想追的剧'), findsOneWidget);

    await tester.tap(find.text('都市').first);
    await tester.pumpAndSettle();
    expect(find.text('都市 · 精选短剧'), findsOneWidget);
    await tester.tap(find.text('全部'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('榜单'));
    await tester.pumpAndSettle();
    expect(find.text('全站热播 · 每小时更新'), findsOneWidget);
    expect(find.text('热播榜'), findsOneWidget);

    await tester.tap(find.text('追剧'));
    await tester.pumpAndSettle();
    expect(find.text('上次看到哪，这次接着看'), findsOneWidget);
    expect(find.text('我的收藏'), findsOneWidget);

    await tester.tap(find.text('历史'));
    await tester.pumpAndSettle();
    expect(find.text('共 3 条观看记录'), findsOneWidget);

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    // 会员体系未上线：入口按 _showMembershipEntry 隐藏。
    expect(find.text('尊享会员'), findsNothing);
    expect(find.text('开通会员'), findsNothing);
    expect(find.text('观看历史'), findsOneWidget);

    await tester.tap(find.text('观看历史'));
    await tester.pumpAndSettle();
    expect(find.text('共 3 条观看记录'), findsOneWidget);
    expect(find.text('追剧'), findsWidgets);

    await tester.tap(find.text('首页'));
    await tester.pumpAndSettle();
    expect(find.text('为你推荐'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('rank board tabs render provider data and switch boards', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        // 与首个用例一致的 mock 数据源；榜单仓库走 MockRankRepository，
        // Tab 与条目均来自 rankPageProvider 的真实数据流。
        overrides: [
          catalogRepositoryProvider.overrideWithValue(MockCatalogRepository()),
          playbackRepositoryProvider
              .overrideWithValue(MockPlaybackRepository()),
          rankRepositoryProvider.overrideWithValue(MockRankRepository()),
        ],
        child: const ApexApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    await tester.tap(find.text('榜单'));
    await tester.pumpAndSettle();
    // Tab 来自 RankPage.tabs，默认选中 selected==true 的「热播榜」。
    expect(find.text('热播榜'), findsOneWidget);
    expect(find.text('新剧榜'), findsOneWidget);
    expect(find.text('完结榜'), findsOneWidget);
    // 条目已渲染：第 1 名的名次文本存在。
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.text('新剧榜'));
    await tester.pumpAndSettle();
    expect(find.text('热播榜'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('完结榜'));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
