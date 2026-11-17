import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:apexduanju/data/local/watch_store.dart';

WatchSnapshot _entry(
  String id, {
  int episode = 1,
  String episodeTitle = '',
  int progress = 0,
  int duration = 0,
  int at = 0,
}) {
  return WatchSnapshot(
    seriesId: id,
    title: '剧$id',
    category: '都市',
    kind: '短剧',
    episodes: 80,
    coverUrl: 'https://cdn.example.com/$id.jpg',
    coverColorsSeed: 'seed-$id',
    lastEpisodeNumber: episode,
    lastEpisodeTitle: episodeTitle.isEmpty ? '第$episode集' : episodeTitle,
    progressSeconds: progress,
    durationSeconds: duration,
    lastWatchAt: at,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // 每个用例独立 mock 存储；setMockInitialValues 会重置底层平台实例
    // 与 legacy 单例缓存，WatchStore.load() 读取的是本次用例的初始值。
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('history', () {
    test('upsert appends, sorts by lastWatchAt desc', () async {
      final WatchStore store = await WatchStore.load();
      await store.upsertHistory(_entry('a', at: 1000));
      await store.upsertHistory(_entry('b', at: 2000));
      await store.upsertHistory(_entry('c', at: 3000));

      final List<WatchSnapshot> list = store.history();
      expect(list.map((WatchSnapshot e) => e.seriesId), <String>['c', 'b', 'a']);
    });

    test('upsert dedupes by seriesId and keeps the newest snapshot', () async {
      final WatchStore store = await WatchStore.load();
      await store.upsertHistory(_entry('a', episode: 1, at: 1000));
      await store.upsertHistory(_entry('b', episode: 2, at: 2000));
      // 同一部剧再次观看：去重并顶到最新，进度取最后一次写入。
      await store.upsertHistory(_entry('a', episode: 7, progress: 42, at: 5000));

      final List<WatchSnapshot> list = store.history();
      expect(list, hasLength(2));
      expect(list.first.seriesId, 'a');
      expect(list.first.lastEpisodeNumber, 7);
      expect(list.first.progressSeconds, 42);
      expect(list.last.seriesId, 'b');
    });

    test('history is capped at 100 entries, oldest dropped', () async {
      final WatchStore store = await WatchStore.load();
      for (int i = 0; i < WatchStore.historyLimit + 10; i++) {
        await store.upsertHistory(_entry('id$i', at: i));
      }
      final List<WatchSnapshot> list = store.history();
      expect(list, hasLength(WatchStore.historyLimit));
      // 最新在首位，最旧的 10 条（id0..id9）被裁掉。
      expect(list.first.seriesId, 'id${WatchStore.historyLimit + 9}');
      expect(list.last.seriesId, 'id10');
    });

    test('removeHistory and clearHistory persist', () async {
      final WatchStore store = await WatchStore.load();
      await store.upsertHistory(_entry('a', at: 1000));
      await store.upsertHistory(_entry('b', at: 2000));
      await store.upsertHistory(_entry('c', at: 3000));

      await store.removeHistory('b');
      expect(store.history().map((WatchSnapshot e) => e.seriesId), <String>[
        'c',
        'a',
      ]);
      // 删除不存在的 id 是无操作。
      await store.removeHistory('ghost');
      expect(store.history(), hasLength(2));

      await store.clearHistory();
      expect(store.history(), isEmpty);

      // 写盘生效：重新加载后与内存一致。
      final WatchStore reloaded = await WatchStore.load();
      expect(reloaded.history(), isEmpty);
    });

    test('json round trip keeps every field', () async {
      const WatchSnapshot entry = WatchSnapshot(
        seriesId: 'flash-marriage',
        title: '闪婚老公是财阀',
        category: '都市',
        kind: '短剧',
        episodes: 80,
        coverUrl: 'https://cdn.example.com/cover.jpg',
        coverColorsSeed: 'flash-marriage闪婚老公是财阀',
        lastEpisodeNumber: 12,
        lastEpisodeTitle: '财阀的秘密',
        progressSeconds: 95,
        durationSeconds: 200,
        lastWatchAt: 1730000000000,
      );

      final WatchStore store = await WatchStore.load();
      await store.upsertHistory(entry);

      // 重新实例化：从 mock prefs 读取写盘 JSON，字段逐项一致。
      final WatchSnapshot restored = (await WatchStore.load()).history().single;
      expect(restored.seriesId, entry.seriesId);
      expect(restored.title, entry.title);
      expect(restored.category, entry.category);
      expect(restored.kind, entry.kind);
      expect(restored.episodes, entry.episodes);
      expect(restored.coverUrl, entry.coverUrl);
      expect(restored.coverColorsSeed, entry.coverColorsSeed);
      expect(restored.lastEpisodeNumber, entry.lastEpisodeNumber);
      expect(restored.lastEpisodeTitle, entry.lastEpisodeTitle);
      expect(restored.progressSeconds, entry.progressSeconds);
      expect(restored.durationSeconds, entry.durationSeconds);
      expect(restored.lastWatchAt, entry.lastWatchAt);

      // toJson → jsonDecode → fromJson 的序列化往返同样无损。
      final WatchSnapshot parsed = WatchSnapshot.fromJson(
        (jsonDecode(jsonEncode(entry.toJson())) as Map).cast<String, Object?>(),
      );
      expect(parsed.seriesId, entry.seriesId);
      expect(parsed.lastWatchAt, entry.lastWatchAt);
      expect(parsed.progressSeconds, entry.progressSeconds);
      expect(parsed.durationSeconds, entry.durationSeconds);
    });

    test('malformed stored json degrades to empty list', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        WatchStore.historyKey: '{not valid json',
        WatchStore.favoritesKey: '42',
      });
      final WatchStore store = await WatchStore.load();
      expect(store.history(), isEmpty);
      expect(store.favorites(), isEmpty);
    });
  });

  group('continue watching', () {
    test('keeps entries with progress that are not finished', () async {
      final WatchStore store = await WatchStore.load();
      await store.upsertHistory(
        _entry('watching', episode: 3, progress: 30, duration: 120, at: 4000),
      );
      await store.upsertHistory(
        _entry('finished', episode: 4, progress: 120, duration: 120, at: 3000),
      );
      await store.upsertHistory(
        _entry('zero', episode: 2, progress: 0, duration: 120, at: 2000),
      );
      await store.upsertHistory(
        _entry('unknown-duration', episode: 5, progress: 12, duration: 0, at: 1000),
      );

      // 0 < progress < duration（总时长未知时视为未播完），时间倒序。
      final List<WatchSnapshot> list = store.continueWatching();
      expect(list.map((WatchSnapshot e) => e.seriesId), <String>[
        'watching',
        'unknown-duration',
      ]);
    });

    test('a finished episode leaves continue watching after re-upsert', () async {
      final WatchStore store = await WatchStore.load();
      await store.upsertHistory(
        _entry('a', episode: 1, progress: 30, duration: 120, at: 1000),
      );
      expect(store.continueWatching(), hasLength(1));
      // 播完自动切集时写入了 progress == duration：移出继续观看，保留历史。
      await store.upsertHistory(
        _entry('a', episode: 1, progress: 120, duration: 120, at: 2000),
      );
      expect(store.continueWatching(), isEmpty);
      expect(store.history(), hasLength(1));
    });
  });

  group('favorites', () {
    test('toggle adds and removes', () async {
      final WatchStore store = await WatchStore.load();
      expect(store.isFavorite('a'), isFalse);

      await store.toggleFavorite(_entry('a', at: 1000));
      expect(store.isFavorite('a'), isTrue);
      expect(store.favorites().single.seriesId, 'a');

      await store.toggleFavorite(_entry('a'));
      expect(store.isFavorite('a'), isFalse);
      expect(store.favorites(), isEmpty);
    });

    test('favorite merges progress from an existing history entry', () async {
      final WatchStore store = await WatchStore.load();
      await store.upsertHistory(
        _entry(
          'a',
          episode: 12,
          episodeTitle: '财阀的秘密',
          progress: 95,
          duration: 200,
          at: 5000,
        ),
      );
      // 详情页收藏：传入的是无进度快照，应继承历史里的观看上下文。
      await store.toggleFavorite(_entry('a', at: 6000));

      final WatchSnapshot favorite = store.favorites().single;
      expect(favorite.lastEpisodeNumber, 12);
      expect(favorite.lastEpisodeTitle, '财阀的秘密');
      expect(favorite.progressSeconds, 95);
      expect(favorite.durationSeconds, 200);
      expect(favorite.lastWatchAt, 6000);

      final WatchStore reloaded = await WatchStore.load();
      expect(reloaded.favorites().single.progressSeconds, 95);
    });

    test('favorites sort by lastWatchAt desc', () async {
      final WatchStore store = await WatchStore.load();
      await store.toggleFavorite(_entry('old', at: 1000));
      await store.toggleFavorite(_entry('new', at: 2000));
      expect(store.favorites().map((WatchSnapshot e) => e.seriesId), <String>[
        'new',
        'old',
      ]);
    });
  });

  group('in-memory store', () {
    test('seeds initial data and never persists', () async {
      final WatchStore seeded = WatchStore.inMemory(
        history: <WatchSnapshot>[_entry('seed', at: 1)],
        favorites: <WatchSnapshot>[_entry('fav', at: 1)],
      );
      expect(seeded.isPersistent, isFalse);
      expect(seeded.history().single.seriesId, 'seed');
      expect(seeded.isFavorite('fav'), isTrue);

      // 写操作照常生效（仅内存），且不落盘。
      await seeded.upsertHistory(_entry('m2', at: 2));
      expect(seeded.history().map((WatchSnapshot e) => e.seriesId), <String>[
        'm2',
        'seed',
      ]);
      final WatchStore fresh = await WatchStore.load();
      expect(fresh.history(), isEmpty);
      expect(fresh.isPersistent, isTrue);
    });
  });
}
