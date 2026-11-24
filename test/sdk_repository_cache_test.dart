import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openhongguo/openhongguo.dart';

import 'package:apexduanju/data/repository/sdk_repositories.dart';
import 'package:apexduanju/data/remote/openhongguo_service.dart';
import 'package:apexduanju/models/playback.dart';
import 'package:apexduanju/models/series_detail.dart';

/// 可编程的 SDK 客户端替身：只实现仓库会调到的方法，并统计调用次数。
class _FakeClient implements OpenhongguoClient {
  /// 每次解析返回的结果；长度用尽后重复最后一个。
  final List<Future<PlaybackResult> Function()> resolveSteps =
      <Future<PlaybackResult> Function()>[];
  bool seasonsFail = false;

  int episodesCalls = 0;
  bool episodesFail = false;
  bool episodesEmpty = false;
  int resolveCalls = 0;
  final List<String> resolveIds = <String>[];

  final List<Future<Series> Function()> seriesSteps =
      <Future<Series> Function()>[];
  int seriesCalls = 0;

  int seasonsCalls = 0;
  final Set<String> seasonsIds = <String>{};

  int searchCalls = 0;
  String searchQuery = '';


  @override
  Future<PlaybackResult> resolvePlayback(String episodeId) {
    resolveCalls++;
    resolveIds.add(episodeId);
    final Future<PlaybackResult> Function() step =
        resolveSteps[(resolveCalls - 1).clamp(0, resolveSteps.length - 1)];
    return step();
  }

  @override
  Future<Series> getSeries(String seriesId) {
    seriesCalls++;
    return seriesSteps[(seriesCalls - 1).clamp(0, seriesSteps.length - 1)]();
  }

  @override
  Future<Recommend> seriesRecommend(String seriesId) async =>
      const Recommend();

  @override
  Future<Album> seasons(String seriesId) async {
    seasonsCalls++;
    if (seasonsFail) {
      throw OpenhongguoException(ErrorCode.transport, '网络抖动');
    }
    seasonsIds.add(seriesId);
    return Album(seasonCount: seasonsCountForAll);
  }

  int seasonsCountForAll = 1;

  @override
  Future<List<SeriesDetail>> getSeriesBatch(List<String> seriesIds) async =>
      <SeriesDetail>[
        for (final String id in seriesIds)
          SeriesDetail(series: Series(id: id, title: '测试剧', isMultiSeason: true)),
      ];

  @override
  Future<PagedResult<SeriesSummary>> search(
    String query, [
    SearchOptions options = const SearchOptions(),
  ]) async {
    searchCalls++;
    searchQuery = query;
    return PagedResult<SeriesSummary>(
      items: <SeriesSummary>[
        const SeriesSummary(id: 's1', title: '测试剧', episodeCount: 10),
      ],
      cursor: '',
      hasMore: false,
    );
  }

  @override
  Future<PagedResult<Episode>> listEpisodes(
    String seriesId, [
    EpisodeOptions options = const EpisodeOptions(),
  ]) async {
    episodesCalls++;
    if (episodesFail) {
      throw OpenhongguoException(ErrorCode.transport, '网络抖动');
    }
    return PagedResult<Episode>(
      items: List<Episode>.generate(
        episodesEmpty ? 0 : 3,
        (int i) => Episode(id: '$seriesId-ep${i + 1}', number: i + 1),
      ),
      cursor: '',
      hasMore: false,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeService implements OpenhongguoService {
  _FakeService(this._client);

  final _FakeClient _client;

  @override
  Future<OpenhongguoClient> client() async => _client;

  @override
  Future<void> resetDevice() async {}

  @override
  Future<void> release() async {}
}

PlaybackResult _result(String url, {int expiresAt = 0}) {
  return PlaybackResult(
    playback: Playback(
      episodeId: '',
      expiresAt: expiresAt,
      streams: <VideoStream>[
        VideoStream(definition: '720p', url: url, height: 720),
      ],
    ),
  );
}

Future<PlaybackResult> _ok(String url, {int expiresAt = 0}) async =>
    _result(url, expiresAt: expiresAt);

Future<PlaybackResult> _fail() async =>
    throw OpenhongguoException(ErrorCode.transport, '网络抖动');

OpenhongguoException _code(String wire) => OpenhongguoException(
      ErrorCode.values.firstWhere((ErrorCode e) => e.wire == wire),
      wire,
    );

const List<Duration> _noBackoff = <Duration>[];

void main() {
  late _FakeClient client;
  late DateTime now;

  /// 固定「当前时间」的仓库，退避设为零，测试不真实等待。
  SdkPlaybackRepository repo({List<Duration>? backoff}) {
    return SdkPlaybackRepository(
      service: _FakeService(client),
      now: () => now,
      resolveBackoff: backoff ?? _noBackoff,
    );
  }

  setUp(() {
    client = _FakeClient();
    now = DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000);
  });

  int nowSeconds() => now.millisecondsSinceEpoch ~/ 1000;

  group('播放解析缓存', () {
    test('同一集重复解析只请求一次', () async {
      client.resolveSteps.add(() => _ok('a'));
      final SdkPlaybackRepository r = repo();
      final PlaybackBundle first = await r.resolve('ep1');
      final PlaybackBundle second = await r.resolve('ep1');

      expect(client.resolveCalls, 1);
      expect(second, same(first));
    });

    test('并发解析同一集只请求一次', () async {
      final Completer<void> gate = Completer<void>();
      // 门闩由下面的 resolveSteps 闭包自己 await。
      client.resolveSteps.add(() async {
        await gate.future;
        return _result('a');
      });
      final SdkPlaybackRepository r = repo();

      final Future<PlaybackBundle> f1 = r.resolve('ep1');
      final Future<PlaybackBundle> f2 = r.resolve('ep1');
      gate.complete();
      final List<PlaybackBundle> results = await Future.wait(
        <Future<PlaybackBundle>>[f1, f2],
      );

      expect(client.resolveCalls, 1);
      expect(results[1], same(results[0]));
    });

    test('并发解析不同集各请求一次', () async {
      client.resolveSteps.add(() => _ok('a'));
      final SdkPlaybackRepository r = repo();

      await Future.wait(<Future<PlaybackBundle>>[
        r.resolve('ep1'),
        r.resolve('ep2'),
      ]);

      expect(client.resolveIds, unorderedEquals(<String>['ep1', 'ep2']));
    });

    test('并发请求共享同一次失败，且不缓存失败', () async {
      client.resolveSteps.add(() => _fail());
      client.resolveSteps.add(() => _ok('a'));
      final SdkPlaybackRepository r = repo();

      final List<Object> errors = <Object>[];
      await Future.wait(<Future<PlaybackBundle>>[
        r.resolve('ep1'),
        r.resolve('ep1'),
      ]).catchError((Object e) {
        errors.add(e);
        return <PlaybackBundle>[];
      });
      final PlaybackBundle retry = await r.resolve('ep1');

      expect(errors, hasLength(1));
      expect(client.resolveCalls, 2);
      expect(retry.preferred?.url, 'a');
    });

    test('invalidate 只作废指定的那一集', () async {
      client.resolveSteps.add(() => _ok('a'));
      client.resolveSteps.add(() => _ok('a'));
      client.resolveSteps.add(() => _ok('b'));
      final SdkPlaybackRepository r = repo();
      await r.resolve('ep1');
      await r.resolve('ep2');

      r.invalidate('ep1');
      final PlaybackBundle ep1 = await r.resolve('ep1');
      final PlaybackBundle ep2 = await r.resolve('ep2');

      expect(ep1.preferred?.url, 'b');
      expect(ep2.preferred?.url, 'a');
      expect(client.resolveCalls, 3);
    });

    test('解析进行中时作废：后续请求另起一次，旧结果不回写缓存', () async {
      final Completer<void> gate = Completer<void>();
      client.resolveSteps.add(() async {
        await gate.future;
        return _result('stale');
      });
      client.resolveSteps.add(() => _ok('fresh'));
      final SdkPlaybackRepository r = repo();

      final Future<PlaybackBundle> stale = r.resolve('ep1');
      // 让第一次请求真正发出并挂起。
      await Future<void>.delayed(Duration.zero);
      r.invalidate('ep1');
      final PlaybackBundle fresh = await r.resolve('ep1');
      gate.complete();
      await stale;
      final PlaybackBundle again = await r.resolve('ep1');

      expect(fresh.preferred?.url, 'fresh');
      expect(again.preferred?.url, 'fresh');
      expect(client.resolveCalls, 2);
    });

    test('作废某一集不影响其他集在途解析的缓存', () async {
      final Completer<void> gate = Completer<void>();
      client.resolveSteps.add(() async {
        await gate.future;
        return _result('b');
      });
      client.resolveSteps.add(() => _ok('a'));
      client.resolveSteps.add(() => _ok('b2'));
      final SdkPlaybackRepository r = repo();

      final Future<PlaybackBundle> ep2 = r.resolve('ep2');
      await Future<void>.delayed(Duration.zero);
      r.invalidate('ep1');
      await r.resolve('ep1');
      gate.complete();
      await ep2;
      await r.resolve('ep2');

      // ep2 的在途解析照常写进缓存：第三次调用没有再发请求。
      expect(client.resolveIds, <String>['ep2', 'ep1']);
    });

    test('旧请求完成时不会摘掉替换它的新请求', () async {
      final Completer<void> gateA = Completer<void>();
      final Completer<void> gateB = Completer<void>();
      client.resolveSteps.add(() async {
        await gateA.future;
        return _result('old');
      });
      client.resolveSteps.add(() async {
        await gateB.future;
        return _result('new');
      });
      client.resolveSteps.add(() => _ok('third'));
      final SdkPlaybackRepository r = repo();

      final Future<PlaybackBundle> old = r.resolve('ep1');
      await Future<void>.delayed(Duration.zero);
      r.invalidate('ep1');
      final Future<PlaybackBundle> fresh = r.resolve('ep1');
      await Future<void>.delayed(Duration.zero);
      // 旧请求先完成：不能把表里的新请求摘掉，第三个调用应并入新请求。
      gateA.complete();
      await old;
      final Future<PlaybackBundle> joiner = r.resolve('ep1');
      gateB.complete();
      await fresh;
      await joiner;

      expect(client.resolveCalls, 2);
      expect((await fresh).preferred?.url, 'new');
    });

    test('服务端给了过期时间且已到期时重新取址', () async {
      client.resolveSteps.add(() => _ok('old', expiresAt: nowSeconds() + 60));
      client.resolveSteps.add(() => _ok('new'));
      final SdkPlaybackRepository r = repo();
      final PlaybackBundle first = await r.resolve('ep1');

      now = now.add(const Duration(minutes: 5));
      final PlaybackBundle second = await r.resolve('ep1');

      expect(first.preferred?.url, 'old');
      expect(second.preferred?.url, 'new');
      expect(client.resolveCalls, 2);
    });

    test('到期前 30 秒内就视为过期（开流要时间）', () async {
      client.resolveSteps.add(() => _ok('old', expiresAt: nowSeconds() + 60));
      client.resolveSteps.add(() => _ok('new'));
      final SdkPlaybackRepository r = repo();
      await r.resolve('ep1');

      now = now.add(const Duration(seconds: 31));
      final PlaybackBundle second = await r.resolve('ep1');

      expect(second.preferred?.url, 'new');
      expect(client.resolveCalls, 2);
    });

    test('未到期时继续复用缓存', () async {
      client.resolveSteps.add(() => _ok('a', expiresAt: nowSeconds() + 600));
      final SdkPlaybackRepository r = repo();
      await r.resolve('ep1');

      now = now.add(const Duration(minutes: 5));
      final PlaybackBundle second = await r.resolve('ep1');

      expect(second.preferred?.url, 'a');
      expect(client.resolveCalls, 1);
    });

    test('服务端没给过期时间时始终复用（不消耗额度）', () async {
      client.resolveSteps.add(() => _ok('a'));
      final SdkPlaybackRepository r = repo();
      await r.resolve('ep1');

      now = now.add(const Duration(days: 1));
      final PlaybackBundle second = await r.resolve('ep1');

      expect(second.preferred?.url, 'a');
      expect(client.resolveCalls, 1);
    });

    test('过期后重新取址失败时抛错，不回退到失效地址', () async {
      client.resolveSteps.add(() => _ok('old', expiresAt: nowSeconds() + 60));
      client.resolveSteps.add(() => _fail());
      final SdkPlaybackRepository r = repo();
      await r.resolve('ep1');
      now = now.add(const Duration(minutes: 5));

      await expectLater(
        r.resolve('ep1'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('分集列表缓存', () {
    test('同一部剧反复取列表只请求一次', () async {
      final SdkPlaybackRepository r = repo();
      await r.episodes('s1');
      await r.episodes('s1');
      await r.episodes('s1');

      expect(client.episodesCalls, 1);
    });

    test('并发取同一部剧的列表只请求一次', () async {
      final SdkPlaybackRepository r = repo();

      await Future.wait(<Future<List<EpisodeInfo>>>[
        r.episodes('s1'),
        r.episodes('s1'),
      ]);

      expect(client.episodesCalls, 1);
    });

    test('缓存过期后重新拉取', () async {
      final SdkPlaybackRepository r = repo();
      await r.episodes('s1');

      now = now.add(const Duration(minutes: 11));
      await r.episodes('s1');

      expect(client.episodesCalls, 2);
    });

    test('过期后刷新失败时退回旧列表', () async {
      final SdkPlaybackRepository r = repo();
      await r.episodes('s1');

      client.episodesFail = true;
      now = now.add(const Duration(minutes: 11));
      final List<EpisodeInfo> items = await r.episodes('s1');

      expect(items, hasLength(3));
      expect(client.episodesCalls, 2);
    });

    test('沿用旧列表后进入冷却，不逐次重试', () async {
      final SdkPlaybackRepository r = repo();
      await r.episodes('s1');

      client.episodesFail = true;
      now = now.add(const Duration(minutes: 11));
      await r.episodes('s1');
      await r.episodes('s1');
      await r.episodes('s1');

      expect(client.episodesCalls, 2);
    });

    test('过期后刷新拿到空列表时沿用旧列表', () async {
      final SdkPlaybackRepository r = repo();
      await r.episodes('s1');

      client.episodesEmpty = true;
      now = now.add(const Duration(minutes: 11));
      final List<EpisodeInfo> items = await r.episodes('s1');

      expect(items, hasLength(3));
      expect(client.episodesCalls, 2);
    });

    test('没有缓存时拉取失败照常抛错', () async {
      client.episodesFail = true;
      final SdkPlaybackRepository r = repo();

      await expectLater(
        r.episodes('s1'),
        throwsA(isA<ApiException>()),
      );
      expect(client.episodesCalls, 1);
    });
  });

  group('播放解析重试', () {
    SdkPlaybackRepository retryRepo() => repo(
          backoff: const <Duration>[Duration.zero, Duration.zero],
        );

    test('可重试错误先退避再重试，成功后只缓存一份', () async {
      client.resolveSteps.add(() => _fail());
      client.resolveSteps.add(() => _ok('a'));
      final PlaybackBundle bundle = await retryRepo().resolve('ep1');

      expect(client.resolveCalls, 2);
      expect(bundle.preferred?.url, 'a');
    });

    test('重试次数用尽后抛出最后一次的错误', () async {
      client.resolveSteps.add(() => _fail());
      final SdkPlaybackRepository r = retryRepo();

      await expectLater(
        r.resolve('ep1'),
        throwsA(
          isA<ApiException>().having((ApiException e) => e.code, 'code', 'TRANSPORT'),
        ),
      );
      expect(client.resolveCalls, 3);
    });

    test('不可重试的错误不重试', () async {
      client.resolveSteps.add(() async => throw _code('CONTENT_UNAVAILABLE'));
      final SdkPlaybackRepository r = retryRepo();

      await expectLater(r.resolve('ep1'), throwsA(isA<ApiException>()));
      expect(client.resolveCalls, 1);
    });
  });

  group('详情缓存', () {
    test('并发请求同一部剧只发一次详情请求', () async {
      final Completer<void> gate = Completer<void>();
      client.seriesSteps.add(() async {
        await gate.future;
        return const Series(id: 's1', title: '测试剧');
      });
      final SdkCatalogRepository r = SdkCatalogRepository(
        service: _FakeService(client),
      );

      final Future<SeriesDetailData> f1 = r.seriesDetail('s1');
      final Future<SeriesDetailData> f2 = r.seriesDetail('s1');
      gate.complete();
      final List<SeriesDetailData> results = await Future.wait(
        <Future<SeriesDetailData>>[f1, f2],
      );

      expect(client.seriesCalls, 1);
      expect(results[1], same(results[0]));
    });

    test('并发请求共享失败，之后的请求可以重新发起', () async {
      client.seriesSteps.add(() async => throw _code('TRANSPORT'));
      final SdkCatalogRepository r = SdkCatalogRepository(
        service: _FakeService(client),
      );

      final List<Object> errors = <Object>[];
      await Future.wait(<Future<SeriesDetailData>>[
        r.seriesDetail('s1'),
        r.seriesDetail('s1'),
      ]).catchError((Object e) {
        errors.add(e);
        return <SeriesDetailData>[];
      });
      client.seriesSteps.add(() async => const Series(id: 's1'));
      final SeriesDetailData data = await r.seriesDetail('s1');

      expect(errors, hasLength(1));
      expect(client.seriesCalls, 2);
      expect(data.drama.id, 's1');
    });
  });

  group('搜索季数探测', () {
    Future<void> search(SdkCatalogRepository r) async {
      await r.searchPage('测试剧');
    }

    test('多季：探测一次后复用缓存', () async {
      client.seasonsCountForAll = 3;
      final SdkCatalogRepository r = SdkCatalogRepository(
        service: _FakeService(client),
      );

      await search(r);
      await search(r);

      expect(client.seasonsCalls, 1);
    });

    test('单季：同样记住，不重复探测', () async {
      client.seasonsCountForAll = 1;
      final SdkCatalogRepository r = SdkCatalogRepository(
        service: _FakeService(client),
      );

      await search(r);
      await search(r);

      expect(client.seasonsCalls, 1);
    });

    test('返回 0 季：冷却期内不重探，冷却到期后重新探测', () async {
      client.seasonsCountForAll = 0;
      final SdkCatalogRepository r = SdkCatalogRepository(
        service: _FakeService(client),
        now: () => now,
      );

      await search(r);
      await search(r);
      expect(client.seasonsCalls, 1);

      now = now.add(const Duration(minutes: 11));
      await search(r);

      expect(client.seasonsCalls, 2);
    });

    test('探测失败：冷却到期后重新探测', () async {
      client.seasonsFail = true;
      final SdkCatalogRepository r = SdkCatalogRepository(
        service: _FakeService(client),
        now: () => now,
      );

      await search(r);
      await search(r);
      now = now.add(const Duration(minutes: 11));
      await search(r);

      expect(client.seasonsCalls, 2);
    });

    test('探测失败：冷却期内不重复探测', () async {
      client.seasonsFail = true;
      final SdkCatalogRepository r = SdkCatalogRepository(
        service: _FakeService(client),
      );

      await search(r);
      await search(r);
      await search(r);

      expect(client.seasonsCalls, 1);
    });
  });
}
