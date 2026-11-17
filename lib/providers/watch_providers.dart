import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/watch_store.dart';
import '../data/mock_data.dart';
import '../models/drama.dart';

/// 本地观看数据（历史 / 收藏 / 继续观看）的 Riverpod 包装。
///
/// [watchStoreProvider] 承载唯一的 [WatchStore] 实例；测试可用
/// `watchStoreProvider.overrideWith((ref) async => store)` 注入内存库。
///
/// SharedPreferences 不可用（纯 Dart widget 测试、插件未注册）时 store
/// 会降级为内存实现——与 homeFeedProvider 失败降级 mock 的策略一致，
/// 此时播种演示数据，保证追剧页在降级环境下仍有内容可看。

final FutureProvider<WatchStore> watchStoreProvider =
    FutureProvider<WatchStore>((Ref ref) => WatchStore.load());

/// 历史记录（时间倒序，按 seriesId 去重，上限 100）。
class HistoryNotifier extends AsyncNotifier<List<WatchSnapshot>> {
  @override
  Future<List<WatchSnapshot>> build() async {
    final WatchStore store = await ref.watch(watchStoreProvider.future);
    await _seedDemoData(store);
    return store.history();
  }

  /// 播放进度落盘（播放页节流写入 + 关键节点即时写入）。
  Future<void> upsertWatchProgress(WatchSnapshot entry) async {
    final WatchStore store = await ref.read(watchStoreProvider.future);
    await _seedDemoData(store);
    await store.upsertHistory(entry);
    state = AsyncData<List<WatchSnapshot>>(store.history());
  }

  /// 单条删除历史。
  Future<void> removeHistory(String seriesId) async {
    final WatchStore store = await ref.read(watchStoreProvider.future);
    await store.removeHistory(seriesId);
    state = AsyncData<List<WatchSnapshot>>(store.history());
  }

  /// 清空全部历史（收藏不受影响）。
  Future<void> clearHistory() async {
    final WatchStore store = await ref.read(watchStoreProvider.future);
    await store.clearHistory();
    state = AsyncData<List<WatchSnapshot>>(store.history());
  }
}

final AsyncNotifierProvider<HistoryNotifier, List<WatchSnapshot>>
historyProvider =
    AsyncNotifierProvider<HistoryNotifier, List<WatchSnapshot>>(
      HistoryNotifier.new,
    );

/// 收藏列表（快照、无进度要求；时间倒序）。
class FavoritesNotifier extends AsyncNotifier<List<WatchSnapshot>> {
  @override
  Future<List<WatchSnapshot>> build() async {
    final WatchStore store = await ref.watch(watchStoreProvider.future);
    await _seedDemoData(store);
    return store.favorites();
  }

  /// 收藏切换：详情页与追剧页共用，状态天然联动。
  Future<void> toggleFavorite(WatchSnapshot entry) async {
    final WatchStore store = await ref.read(watchStoreProvider.future);
    await _seedDemoData(store);
    await store.toggleFavorite(entry);
    state = AsyncData<List<WatchSnapshot>>(store.favorites());
  }

  /// 取消收藏。
  Future<void> removeFavorite(String seriesId) async {
    final WatchStore store = await ref.read(watchStoreProvider.future);
    await store.removeFavorite(seriesId);
    state = AsyncData<List<WatchSnapshot>>(store.favorites());
  }
}

final AsyncNotifierProvider<FavoritesNotifier, List<WatchSnapshot>>
favoritesProvider =
    AsyncNotifierProvider<FavoritesNotifier, List<WatchSnapshot>>(
      FavoritesNotifier.new,
    );

/// 继续观看 = 历史里有进度且未播完的条目（时间倒序）。
final Provider<List<WatchSnapshot>> continueWatchingProvider =
    Provider<List<WatchSnapshot>>((Ref ref) {
      final List<WatchSnapshot>? history = ref.watch(historyProvider).value;
      if (history == null) {
        return const <WatchSnapshot>[];
      }
      return List<WatchSnapshot>.unmodifiable(
        <WatchSnapshot>[
          for (final WatchSnapshot entry in history)
            if (entry.isInProgress) entry,
        ],
      );
    });

/// 某部剧是否已收藏（详情页收藏态图标用）。
/// family 的具体类型（ProviderFamily）未从 flutter_riverpod 主出口导出，依赖推断。
final isFavoriteProvider = Provider.family<bool, String>((
  Ref ref,
  String seriesId,
) {
  final List<WatchSnapshot>? favorites = ref.watch(favoritesProvider).value;
  if (favorites == null) {
    return false;
  }
  return favorites.any((WatchSnapshot entry) => entry.seriesId == seriesId);
});

/// 演示播种：仅在 store 降级为内存实现且对应列表为空时执行，幂等。
/// mock 假设一集约 2 分钟；时间按列表顺序递减，保证与 mock 观感一致
/// （排在前面的条目更新）。
///
/// 历史里只有最新一条保留观看中进度（继续观看页维持原 mock 的单卡
/// 布局），其余条目进度归零、只出现在历史列表。
Future<void> _seedDemoData(WatchStore store) async {
  if (store.isPersistent) {
    return;
  }
  if (store.history().isEmpty) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    const int episodeSeconds = 120;
    for (int i = 0; i < mockWatchHistory.length; i++) {
      final Drama drama = mockWatchHistory[i].drama;
      await store.upsertHistory(
        snapshotFromDrama(
          drama,
          episodeNumber: mockWatchHistory[i].lastEpisode,
          episodeTitle: drama.episodeTitle(mockWatchHistory[i].lastEpisode),
          progressSeconds: i == 0
              ? (mockWatchHistory[i].progress * episodeSeconds).round()
              : 0,
          durationSeconds: episodeSeconds,
          lastWatchAt: now - i * Duration.millisecondsPerHour,
        ),
      );
    }
  }
  if (store.favorites().isEmpty) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    for (int i = 0; i < mockFavorites.length; i++) {
      await store.toggleFavorite(
        snapshotFromDrama(
          mockFavorites[i],
          lastWatchAt: now - i * Duration.millisecondsPerHour,
        ),
      );
    }
  }
}
