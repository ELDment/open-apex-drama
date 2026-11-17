import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repository/mock_repositories.dart';
import '../data/repository/repositories.dart';
import '../data/repository/sdk_repositories.dart';
import '../data/remote/openhongguo_service.dart';
import '../models/catalog.dart';
import '../models/drama.dart';
import '../models/playback.dart';
import '../models/series_detail.dart';

/// 数据源模式：SDK 直连 / mock 演示。
enum DataMode { sdk, mock }

class DataModeNotifier extends Notifier<DataMode> {
  @override
  DataMode build() => DataMode.sdk;

  void set(DataMode mode) => state = mode;

  void toggle() => state = state == DataMode.sdk ? DataMode.mock : DataMode.sdk;
}

final NotifierProvider<DataModeNotifier, DataMode> dataModeProvider =
    NotifierProvider<DataModeNotifier, DataMode>(DataModeNotifier.new);

final Provider<CatalogRepository> catalogRepositoryProvider =
    Provider<CatalogRepository>((Ref ref) {
  switch (ref.watch(dataModeProvider)) {
    case DataMode.sdk:
      return SdkCatalogRepository();
    case DataMode.mock:
      return MockCatalogRepository();
  }
});

final Provider<PlaybackRepository> playbackRepositoryProvider =
    Provider<PlaybackRepository>((Ref ref) {
  switch (ref.watch(dataModeProvider)) {
    case DataMode.sdk:
      return SdkPlaybackRepository();
    case DataMode.mock:
      return MockPlaybackRepository();
  }
});

final Provider<RankRepository> rankRepositoryProvider =
    Provider<RankRepository>((Ref ref) {
  switch (ref.watch(dataModeProvider)) {
    case DataMode.sdk:
      return SdkRankRepository();
    case DataMode.mock:
      return MockRankRepository();
  }
});

/// 榜单页（按 contentId/boardId 缓存不同 Tab）。
final rankPageProvider = FutureProvider.family<RankPage, List<String>>(
  (Ref ref, List<String> ids) {
    return ref
        .watch(rankRepositoryProvider)
        .rankPage(contentId: ids[0], boardId: ids[1]);
  },
);

/// 搜索首页（热搜 + 猜你想搜）。
final searchHomeProvider = FutureProvider<SearchHome>((Ref ref) {
  return ref.watch(catalogRepositoryProvider).searchHome();
});

/// 搜索联想词（输入变化时 debounce 后调用）。
final suggestProvider =
    FutureProvider.family<List<String>, String>((Ref ref, String prefix) {
  return ref.watch(catalogRepositoryProvider).suggest(prefix);
});

/// 搜索结果。
final searchResultProvider =
    FutureProvider.family<SearchPage, String>((Ref ref, String query) {
  return ref.watch(catalogRepositoryProvider).searchPage(query);
});

/// 分类筛选面板。
final filterPanelProvider = FutureProvider<List<FilterGroupData>>((Ref ref) {
  return ref.watch(catalogRepositoryProvider).filterPanel();
});

/// 分类筛选结果（ selections 的 key 按字典序拼接作为缓存键 ）。
final filterResultProvider = FutureProvider.family<List<Drama>, String>(
  (Ref ref, String selectionsKey) {
    final Map<String, List<String>> selections = <String, List<String>>{};
    for (final String pair in selectionsKey.split(';')) {
      if (pair.isEmpty) {
        continue;
      }
      final int split = pair.indexOf('=');
      if (split <= 0) {
        continue;
      }
      selections[pair.substring(0, split)] = pair.substring(split + 1).split(',');
    }
    return ref
        .watch(catalogRepositoryProvider)
        .filter(selections: selections);
  },
);

/// 某部短剧的分集列表（mock id 由 mock 仓库处理，真实 id 走 SDK）。
final episodesProvider =
    FutureProvider.family<List<EpisodeInfo>, String>((Ref ref, String seriesId) {
  return ref.watch(playbackRepositoryProvider).episodes(seriesId);
});

/// 详情页聚合（完整数据 + 多季 + 相关推荐）。
final seriesDetailProvider =
    FutureProvider.family<SeriesDetailData, String>((Ref ref, String seriesId) {
  return ref.watch(catalogRepositoryProvider).seriesDetail(seriesId);
});

/// 上新日历（date 为 YYYYMMDD，空取今日）。
final newReleasesProvider = FutureProvider.family<List<Drama>, String>(
  (Ref ref, String date) {
    return ref
        .watch(catalogRepositoryProvider)
        .newReleases(date: date.isEmpty ? null : date);
  },
);

/// 首页频道数据；SDK 失败或频道未接入时降级 mock 并标记。
@immutable
class HomeFeed {
  const HomeFeed({
    required this.items,
    this.isFallback = false,
    this.fallbackReason = '',
  });

  final List<Drama> items;
  final bool isFallback;
  final String fallbackReason;
}

final homeFeedProvider = FutureProvider.family<HomeFeed, String>(
  (Ref ref, String channelLabel) async {
    final CatalogRepository repo = ref.watch(catalogRepositoryProvider);
    if (repo is MockCatalogRepository) {
      return HomeFeed(items: await repo.discoverFeed(channelLabel));
    }
    try {
      final List<Drama> items = await repo.discoverFeed(channelLabel);
      if (items.isNotEmpty) {
        return HomeFeed(items: items);
      }
      return await _fallback(channelLabel, '该频道暂时没有内容');
    } on ApiException catch (error) {
      return await _fallback(channelLabel, error.userMessage);
    } on UnsupportedError {
      return await _fallback(channelLabel, '该频道暂未接入真实数据');
    }
  },
);

Future<HomeFeed> _fallback(String channelLabel, String reason) async {
  final List<Drama> items =
      await MockCatalogRepository().discoverFeed(channelLabel);
  return HomeFeed(items: items, isFallback: true, fallbackReason: reason);
}
