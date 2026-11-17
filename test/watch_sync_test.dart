import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:apexduanju/data/local/watch_store.dart';
import 'package:apexduanju/services/watch_sync_document.dart';
import 'package:apexduanju/services/watch_sync_service.dart';
import 'package:apexduanju/services/webdav_client.dart';
import 'package:apexduanju/services/webdav_sync_settings.dart';

WatchSnapshot _entry(
  String id, {
  int episode = 1,
  int progress = 0,
  int at = 0,
}) {
  return WatchSnapshot(
    seriesId: id,
    title: '剧$id',
    category: '都市',
    kind: '短剧',
    episodes: 80,
    coverUrl: '',
    coverColorsSeed: 'seed-$id',
    lastEpisodeNumber: episode,
    lastEpisodeTitle: '第$episode集',
    progressSeconds: progress,
    durationSeconds: 120,
    lastWatchAt: at,
  );
}

SyncDocument _doc({
  List<WatchSnapshot> history = const <WatchSnapshot>[],
  List<WatchSnapshot> favorites = const <WatchSnapshot>[],
  Map<String, int> deletedHistory = const <String, int>{},
  Map<String, int> deletedFavorites = const <String, int>{},
}) {
  return SyncDocument(
    history: history,
    favorites: favorites,
    deletedHistory: deletedHistory,
    deletedFavorites: deletedFavorites,
  );
}

/// 内存版 WebDAV：只模拟同步文件本身。
class _FakeWebDavClient extends WebDavClient {
  _FakeWebDavClient()
    : super(
        config: const WebDavConfig(
          serverUrl: WebDavConfig.defaultServerUrl,
          username: 'u',
          password: 'p',
        ),
      );

  String? content;
  int uploadCount = 0;

  @override
  Future<String?> download() async => content;

  @override
  Future<void> upload(String content) async {
    this.content = content;
    uploadCount++;
  }

  @override
  Future<void> ensureDirectory() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('mergeSyncDocuments', () {
    // 墓碑保留 180 天，测试时间戳必须贴近当前时间，否则会被当作过期墓碑清掉。
    final int base = DateTime.now().millisecondsSinceEpoch;

    test('same series keeps the newer progress', () {
      final SyncDocument merged = mergeSyncDocuments(
        _doc(
          history: <WatchSnapshot>[
            _entry('a', episode: 3, progress: 30, at: base - 1000),
          ],
        ),
        _doc(
          history: <WatchSnapshot>[
            _entry('a', episode: 8, progress: 88, at: base),
          ],
        ),
      );
      expect(merged.history.single.lastEpisodeNumber, 8);
      expect(merged.history.single.progressSeconds, 88);
    });

    test('tombstone newer than the record removes it', () {
      final SyncDocument merged = mergeSyncDocuments(
        _doc(history: <WatchSnapshot>[_entry('a', at: base - 1000)]),
        _doc(deletedHistory: <String, int>{'a': base}),
      );
      expect(merged.history, isEmpty);
      expect(merged.deletedHistory['a'], base);
    });

    test('watching again after deletion revives the record', () {
      final SyncDocument merged = mergeSyncDocuments(
        _doc(
          history: <WatchSnapshot>[_entry('a', episode: 5, at: base)],
          deletedHistory: <String, int>{'a': base - 1000},
        ),
        _doc(deletedHistory: <String, int>{'a': base - 1000}),
      );
      expect(merged.history.single.lastEpisodeNumber, 5);
      expect(merged.deletedHistory.containsKey('a'), isFalse);
    });

    test('favorite deletion propagates, local favorite kept otherwise', () {
      final SyncDocument merged = mergeSyncDocuments(
        _doc(favorites: <WatchSnapshot>[_entry('keep', at: base - 1000)]),
        _doc(
          favorites: <WatchSnapshot>[
            _entry('keep', at: base - 2000),
            _entry('gone', at: base - 3000),
          ],
          deletedFavorites: <String, int>{'gone': base - 1500},
        ),
      );
      expect(
        merged.favorites.map((WatchSnapshot e) => e.seriesId),
        <String>['keep'],
      );
    });

    test('history is capped at the store limit', () {
      final List<WatchSnapshot> many = <WatchSnapshot>[
        for (int i = 0; i < WatchStore.historyLimit + 5; i++)
          _entry('id$i', at: base + i),
      ];
      final SyncDocument merged = mergeSyncDocuments(
        _doc(history: many),
        SyncDocument.empty(),
      );
      expect(merged.history, hasLength(WatchStore.historyLimit));
      expect(merged.history.first.seriesId, 'id${WatchStore.historyLimit + 4}');
    });
  });

  group('SyncDocument json', () {
    test('round trips entries and tombstones', () {
      final SyncDocument source = _doc(
        history: <WatchSnapshot>[_entry('a', episode: 2, progress: 20, at: 10)],
        favorites: <WatchSnapshot>[_entry('b', at: 20)],
        deletedHistory: <String, int>{'c': 30},
        deletedFavorites: <String, int>{'d': 40},
      );
      final SyncDocument decoded = SyncDocument.fromJsonString(
        source.toJsonString(),
      );
      expect(decoded.contentSignature(), source.contentSignature());
    });

    test('rejects non-object json so sync can abort safely', () {
      expect(
        () => SyncDocument.fromJsonString('[]'),
        throwsA(isA<FormatException>()),
      );
    });

    test('skips invalid entries instead of failing the whole file', () {
      final SyncDocument decoded = SyncDocument.fromJsonString(
        '{"history":[{"seriesId":42},{"seriesId":"ok","lastWatchAt":5}]}',
      );
      expect(decoded.history.single.seriesId, 'ok');
    });
  });

  group('WatchStore tombstones', () {
    test('removeFavorite persists a tombstone across reload', () async {
      final WatchStore store = await WatchStore.load();
      await store.toggleFavorite(_entry('a', at: 10));
      await store.removeFavorite('a');

      final WatchStore reloaded = await WatchStore.load();
      expect(reloaded.favorites(), isEmpty);
      expect(reloaded.deletedFavorites().containsKey('a'), isTrue);
    });

    test('clearHistory tombstones every entry', () async {
      final WatchStore store = await WatchStore.load();
      await store.upsertHistory(_entry('a', at: 1));
      await store.upsertHistory(_entry('b', at: 2));
      await store.clearHistory();

      final WatchStore reloaded = await WatchStore.load();
      expect(reloaded.history(), isEmpty);
      expect(reloaded.deletedHistory().keys.toSet(), <String>{'a', 'b'});
    });

    test('re-watching removes the stale tombstone', () async {
      final WatchStore store = await WatchStore.load();
      await store.upsertHistory(_entry('a', at: 10));
      await store.removeHistory('a');
      await store.upsertHistory(_entry('a', at: 20));
      expect(store.deletedHistory().containsKey('a'), isFalse);
    });
  });

  group('WatchSyncService', () {
    test('first sync uploads local data, second device pulls it', () async {
      final _FakeWebDavClient client = _FakeWebDavClient();

      final WatchStore phone = WatchStore.inMemory(
        history: <WatchSnapshot>[_entry('a', episode: 4, progress: 44, at: 100)],
        favorites: <WatchSnapshot>[_entry('b', at: 90)],
      );
      final WatchSyncResult first = await WatchSyncService(
        config: client.config,
        client: client,
      ).sync(phone);
      expect(first.uploaded, isTrue);
      expect(client.uploadCount, 1);

      final WatchStore desktop = WatchStore.inMemory();
      final WatchSyncResult second = await WatchSyncService(
        config: client.config,
        client: client,
      ).sync(desktop);
      expect(second.pulledRecords, 2);
      expect(desktop.history().single.lastEpisodeNumber, 4);
      expect(desktop.favorites().single.seriesId, 'b');
      // 拉取后内容与云端一致，不重复上传。
      expect(client.uploadCount, 1);
    });

    test('deletion on one device removes the record on the other', () async {
      final _FakeWebDavClient client = _FakeWebDavClient();
      final WatchStore phone = WatchStore.inMemory(
        history: <WatchSnapshot>[_entry('a', at: 100)],
      );
      final WatchStore desktop = WatchStore.inMemory(
        history: <WatchSnapshot>[_entry('a', at: 100)],
      );
      await WatchSyncService(config: client.config, client: client).sync(phone);

      await phone.removeHistory('a');
      await WatchSyncService(config: client.config, client: client).sync(phone);
      await WatchSyncService(config: client.config, client: client).sync(
        desktop,
      );

      expect(phone.history(), isEmpty);
      expect(desktop.history(), isEmpty);
    });

    test('corrupt remote file aborts instead of overwriting', () async {
      final _FakeWebDavClient client = _FakeWebDavClient()
        ..content = '{ this is not json';
      final WatchStore store = WatchStore.inMemory(
        history: <WatchSnapshot>[_entry('a', at: 100)],
      );
      await expectLater(
        WatchSyncService(config: client.config, client: client).sync(store),
        throwsA(isA<WatchSyncFormatException>()),
      );
      expect(client.uploadCount, 0);
      expect(store.history(), hasLength(1));
    });

    test('localOverwrite replaces the cloud file with local data', () async {
      final _FakeWebDavClient client = _FakeWebDavClient()
        ..content = _doc(
          history: <WatchSnapshot>[_entry('remote-only', at: 200)],
          favorites: <WatchSnapshot>[_entry('remote-fav', at: 200)],
        ).toJsonString();
      final WatchStore store = WatchStore.inMemory(
        history: <WatchSnapshot>[_entry('local', at: 100)],
      );

      final WatchSyncResult result = await WatchSyncService(
        config: client.config,
        strategy: SyncStrategy.localOverwrite,
        client: client,
      ).sync(store);

      expect(result.uploaded, isTrue);
      expect(result.pulledRecords, 0);
      final SyncDocument remote = SyncDocument.fromJsonString(client.content!);
      expect(
        remote.history.map((WatchSnapshot e) => e.seriesId),
        <String>['local'],
      );
      expect(remote.favorites, isEmpty);
      // 本地数据不被云端内容改写。
      expect(store.history().single.seriesId, 'local');
    });

    test('localOverwrite skips upload when cloud already matches', () async {
      final _FakeWebDavClient client = _FakeWebDavClient();
      final WatchStore store = WatchStore.inMemory(
        history: <WatchSnapshot>[_entry('a', at: 100)],
      );
      final WatchSyncService service = WatchSyncService(
        config: client.config,
        strategy: SyncStrategy.localOverwrite,
        client: client,
      );

      await service.sync(store);
      await service.sync(store);
      expect(client.uploadCount, 1);
    });
  });

  group('WebDavSyncSettings', () {
    test('migrates the legacy default remote dir', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        WebDavSyncSettings.remoteDirKey: WebDavConfig.legacyDefaultRemoteDir,
      });
      final WebDavSyncSettings settings = await WebDavSyncSettings.load();
      expect(settings.config.remoteDir, WebDavConfig.defaultRemoteDir);
      expect(WebDavConfig.defaultRemoteDir, 'ApexDrama');
    });

    test('keeps a custom remote dir untouched', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        WebDavSyncSettings.remoteDirKey: 'my/dramas',
      });
      final WebDavSyncSettings settings = await WebDavSyncSettings.load();
      expect(settings.config.remoteDir, 'my/dramas');
    });

    test('strategy defaults to merge and survives a save', () async {
      final WebDavSyncSettings initial = await WebDavSyncSettings.load();
      expect(initial.strategy, SyncStrategy.merge);

      await initial.copyWith(strategy: SyncStrategy.localOverwrite).save();
      final WebDavSyncSettings reloaded = await WebDavSyncSettings.load();
      expect(reloaded.strategy, SyncStrategy.localOverwrite);
    });
  });
}
