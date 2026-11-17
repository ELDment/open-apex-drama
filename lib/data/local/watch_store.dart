import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/drama.dart';
import '../mappers.dart';

/// 观看数据快照：历史 / 收藏共用的持久化条目。
///
/// 刻意不落盘完整 [Drama]：真实封面 URL 带签名会过期，因此只存
/// [coverColorsSeed]（展示时用 `paletteFor` 重建三色渐变）；
/// 评分 / 在追数等易变字段也不存（rating=0、viewers='' 时 UI 自动隐藏）。
@immutable
class WatchSnapshot {
  const WatchSnapshot({
    required this.seriesId,
    required this.title,
    required this.category,
    required this.kind,
    required this.episodes,
    required this.coverColorsSeed,
    this.coverUrl = '',
    this.lastEpisodeNumber = 1,
    this.lastEpisodeTitle = '',
    this.progressSeconds = 0,
    this.durationSeconds = 0,
    this.lastWatchAt = 0,
  });

  final String seriesId;
  final String title;

  /// 分类（如「都市」）与类型（短剧 / 电视剧 / 电影）。
  final String category;
  final String kind;
  final int episodes;

  /// 真实封面 URL；带签名会过期，仅作展示加速，过期后回落渐变占位。
  final String coverUrl;

  /// 渐变种子：paletteFor(coverColorsSeed) 重建封面三色。
  final String coverColorsSeed;

  /// 停在哪一集与该集标题。
  final int lastEpisodeNumber;
  final String lastEpisodeTitle;

  /// 已播秒数与该集总秒数（未知为 0）。
  final int progressSeconds;
  final int durationSeconds;

  /// 最近观看时间（unix 毫秒），历史 / 收藏按它倒序。
  final int lastWatchAt;

  /// 进度条取值 0.0 - 1.0；总时长未知时给 0（无法换算比例）。
  double get progressFraction {
    if (durationSeconds <= 0) {
      return 0;
    }
    return (progressSeconds / durationSeconds).clamp(0.0, 1.0);
  }

  String get percentLabel => '${(progressFraction * 100).round()}%';

  /// 本集已播完（真实播完的不再进「继续观看」）。
  bool get isFinished => durationSeconds > 0 && progressSeconds >= durationSeconds;

  /// 有进度且未播完 → 可出现在「继续观看」。
  bool get isInProgress => progressSeconds > 0 && !isFinished;

  String get episodeLabel => '看到第 $lastEpisodeNumber 集 / 共 $episodes 集';

  /// 重建最小可用 Drama：评分 0 / 在追数空，对应 UI 自动隐藏这两处。
  Drama toDrama() {
    return Drama(
      id: seriesId,
      title: title,
      kind: kind,
      category: category,
      tags: <String>[category],
      episodes: episodes,
      rating: 0,
      viewers: '',
      description: '',
      coverColors: paletteFor(coverColorsSeed),
      coverUrl: coverUrl,
      episodeTitles: const <String>[],
    );
  }

  WatchSnapshot copyWith({
    int? lastEpisodeNumber,
    String? lastEpisodeTitle,
    int? progressSeconds,
    int? durationSeconds,
    int? lastWatchAt,
  }) {
    return WatchSnapshot(
      seriesId: seriesId,
      title: title,
      category: category,
      kind: kind,
      episodes: episodes,
      coverUrl: coverUrl,
      coverColorsSeed: coverColorsSeed,
      lastEpisodeNumber: lastEpisodeNumber ?? this.lastEpisodeNumber,
      lastEpisodeTitle: lastEpisodeTitle ?? this.lastEpisodeTitle,
      progressSeconds: progressSeconds ?? this.progressSeconds,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      lastWatchAt: lastWatchAt ?? this.lastWatchAt,
    );
  }

  Map<String, Object> toJson() {
    return <String, Object>{
      'seriesId': seriesId,
      'title': title,
      'category': category,
      'kind': kind,
      'episodes': episodes,
      'coverUrl': coverUrl,
      'coverColorsSeed': coverColorsSeed,
      'lastEpisodeNumber': lastEpisodeNumber,
      'lastEpisodeTitle': lastEpisodeTitle,
      'progressSeconds': progressSeconds,
      'durationSeconds': durationSeconds,
      'lastWatchAt': lastWatchAt,
    };
  }

  /// 字段级防御解析：坏数据（类型不符 / 缺字段）回落默认值，不让脏
  /// JSON 打崩整个列表。
  factory WatchSnapshot.fromJson(Map<String, Object?> json) {
    return WatchSnapshot(
      seriesId: json['seriesId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      episodes: (json['episodes'] as num?)?.toInt() ?? 0,
      coverUrl: json['coverUrl'] as String? ?? '',
      coverColorsSeed: json['coverColorsSeed'] as String? ?? '',
      lastEpisodeNumber: (json['lastEpisodeNumber'] as num?)?.toInt() ?? 1,
      lastEpisodeTitle: json['lastEpisodeTitle'] as String? ?? '',
      progressSeconds: (json['progressSeconds'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      lastWatchAt: (json['lastWatchAt'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 从剧信息生成快照。渐变种子与生产逻辑一致（`id + title` → paletteFor，
/// 见 mappers.dart / sdk_repositories.dart），恢复后封面渐变与原来相同。
WatchSnapshot snapshotFromDrama(
  Drama drama, {
  int episodeNumber = 1,
  String episodeTitle = '',
  int progressSeconds = 0,
  int durationSeconds = 0,
  int? lastWatchAt,
}) {
  return WatchSnapshot(
    seriesId: drama.id,
    title: drama.title,
    category: drama.category,
    kind: drama.kind,
    episodes: drama.episodes,
    coverUrl: drama.coverUrl,
    coverColorsSeed: '${drama.id}${drama.title}',
    lastEpisodeNumber: episodeNumber,
    lastEpisodeTitle: episodeTitle,
    progressSeconds: progressSeconds,
    durationSeconds: durationSeconds,
    lastWatchAt:
        lastWatchAt ?? DateTime.now().millisecondsSinceEpoch,
  );
}

/// 观看数据本地存储：历史 + 收藏，SharedPreferences JSON 持久化。
///
/// - 历史按 seriesId 去重（重复观看顶到最新）、[lastWatchAt] 倒序、
///   上限 [historyLimit] 条；
/// - 收藏为快照列表（同字段、无进度），toggleFavorite 已收藏则移除；
/// - 「继续观看」= 历史里 progress>0 且未播完的条目（时间倒序）。
///
/// 内存态为准、写盘异步跟随；SharedPreferences 不可用（纯 Dart
/// widget 测试、插件未注册）时降级为纯内存实例，接口行为一致，
/// 上层用 [isPersistent] 判断是否落盘。
class WatchStore {
  WatchStore._(
    this._prefs,
    List<WatchSnapshot> history,
    List<WatchSnapshot> favorites, {
    Map<String, int> deletedHistory = const <String, int>{},
    Map<String, int> deletedFavorites = const <String, int>{},
  }) : _history = List<WatchSnapshot>.of(history),
       _favorites = List<WatchSnapshot>.of(favorites),
       _deletedHistory = Map<String, int>.of(deletedHistory),
       _deletedFavorites = Map<String, int>.of(deletedFavorites);

  /// 历史与收藏的存储 key（JSON 数组字符串）。
  static const String historyKey = 'watch.history.v1';
  static const String favoritesKey = 'watch.favorites.v1';

  /// 删除墓碑：seriesId → 删除时间（unix 毫秒）。WebDAV 同步靠它把
  /// 「取消收藏 / 删除记录」传播到其他设备；本地不展示。
  static const String deletedHistoryKey = 'watch.deleted.history.v1';
  static const String deletedFavoritesKey = 'watch.deleted.favorites.v1';

  /// 墓碑保留时长：足够覆盖长期不联网的设备，之后自动清理。
  static const Duration tombstoneRetention = Duration(days: 180);

  /// 历史上限：超出时裁掉最旧的记录。
  static const int historyLimit = 100;

  /// 初始化超时：SharedPreferences 插件未注册的环境（纯 Dart widget
  /// 测试、部分桌面 shell）下 getInstance() 会永远挂起而不是报错，
  /// 因此加超时兜底降级内存库。正常设备上远快于该值。
  static const Duration _loadTimeout = Duration(milliseconds: 300);

  final SharedPreferences? _prefs;
  List<WatchSnapshot> _history;
  List<WatchSnapshot> _favorites;
  final Map<String, int> _deletedHistory;
  final Map<String, int> _deletedFavorites;

  /// 本地数据变更通知（每次成功写入后触发，WebDAV 自动同步监听）。
  final StreamController<void> _changes = StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;

  /// SharedPreferences 可用且数据真实落盘。
  bool get isPersistent => _prefs != null;

  /// 读取磁盘（初始化一次）；插件不可用 / 挂起时降级为内存空库。
  static Future<WatchStore> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance()
          .timeout(_loadTimeout);
      return WatchStore._(
        prefs,
        _decodeList(prefs.getString(historyKey)),
        _decodeList(prefs.getString(favoritesKey)),
        deletedHistory: _decodeTombstones(prefs.getString(deletedHistoryKey)),
        deletedFavorites: _decodeTombstones(
          prefs.getString(deletedFavoritesKey),
        ),
      );
    } catch (_) {
      // MissingPluginException / TimeoutException：测试环境 / 插件未
      // 注册，走内存降级（providers 侧会播种演示数据）。
      return WatchStore._(null, const <WatchSnapshot>[], const <WatchSnapshot>[]);
    }
  }

  /// 纯内存实例（测试 / 降级播种用），可带初始数据。
  factory WatchStore.inMemory({
    List<WatchSnapshot> history = const <WatchSnapshot>[],
    List<WatchSnapshot> favorites = const <WatchSnapshot>[],
  }) {
    return WatchStore._(null, history, favorites);
  }

  /// 历史（时间倒序的只读副本）。
  List<WatchSnapshot> history() => List<WatchSnapshot>.unmodifiable(_history);

  /// 收藏（时间倒序的只读副本）。
  List<WatchSnapshot> favorites() =>
      List<WatchSnapshot>.unmodifiable(_favorites);

  /// 删除墓碑只读视图（WebDAV 同步合并用）。
  Map<String, int> deletedHistory() =>
      Map<String, int>.unmodifiable(_deletedHistory);

  Map<String, int> deletedFavorites() =>
      Map<String, int>.unmodifiable(_deletedFavorites);

  bool isFavorite(String seriesId) =>
      _favorites.any((WatchSnapshot e) => e.seriesId == seriesId);

  /// 继续观看：历史里有进度且未播完的条目，保持时间倒序。
  List<WatchSnapshot> continueWatching() {
    return List<WatchSnapshot>.unmodifiable(
      <WatchSnapshot>[
        for (final WatchSnapshot entry in _history)
          if (entry.isInProgress) entry,
      ],
    );
  }

  /// 写入 / 更新播放进度：去重、时间倒序、裁剪到上限后落盘。
  Future<void> upsertHistory(WatchSnapshot entry) async {
    _history.removeWhere((WatchSnapshot e) => e.seriesId == entry.seriesId);
    _history.add(entry);
    _sortByTime(_history);
    if (_history.length > historyLimit) {
      _history.removeRange(historyLimit, _history.length);
    }
    // 重新观看 = 复活该条记录，旧墓碑作废。
    final bool revived = _deletedHistory.remove(entry.seriesId) != null;
    await _saveHistory();
    if (revived) {
      await _saveTombstones();
    }
    _notify();
  }

  Future<void> removeHistory(String seriesId) async {
    final int before = _history.length;
    _history.removeWhere((WatchSnapshot e) => e.seriesId == seriesId);
    if (_history.length == before) {
      return;
    }
    _deletedHistory[seriesId] = _now();
    await _saveHistory();
    await _saveTombstones();
    _notify();
  }

  Future<void> clearHistory() async {
    if (_history.isEmpty) {
      return;
    }
    final int now = _now();
    for (final WatchSnapshot entry in _history) {
      _deletedHistory[entry.seriesId] = now;
    }
    _history.clear();
    await _saveHistory();
    await _saveTombstones();
    _notify();
  }

  /// 收藏切换：未收藏则加入（若历史里有同一部，继承其进度与时间，
  /// 让收藏排序与「继续观看」上下文连贯），已收藏则移除。
  Future<void> toggleFavorite(WatchSnapshot entry) async {
    bool tombstoneChanged = false;
    if (isFavorite(entry.seriesId)) {
      _favorites.removeWhere(
        (WatchSnapshot e) => e.seriesId == entry.seriesId,
      );
      _deletedFavorites[entry.seriesId] = _now();
      tombstoneChanged = true;
    } else {
      WatchSnapshot merged = entry;
      for (final WatchSnapshot seen in _history) {
        if (seen.seriesId == entry.seriesId) {
          merged = entry.copyWith(
            lastEpisodeNumber: seen.lastEpisodeNumber,
            lastEpisodeTitle: seen.lastEpisodeTitle,
            progressSeconds: seen.progressSeconds,
            durationSeconds: seen.durationSeconds,
            lastWatchAt:
                entry.lastWatchAt > 0 ? entry.lastWatchAt : seen.lastWatchAt,
          );
          break;
        }
      }
      _favorites.add(merged);
      _sortByTime(_favorites);
      tombstoneChanged = _deletedFavorites.remove(entry.seriesId) != null;
    }
    await _saveFavorites();
    if (tombstoneChanged) {
      await _saveTombstones();
    }
    _notify();
  }

  Future<void> removeFavorite(String seriesId) async {
    final int before = _favorites.length;
    _favorites.removeWhere((WatchSnapshot e) => e.seriesId == seriesId);
    if (_favorites.length == before) {
      return;
    }
    _deletedFavorites[seriesId] = _now();
    await _saveFavorites();
    await _saveTombstones();
    _notify();
  }

  /// 应用云端合并结果（WebDAV 同步）：整个列表以合并后的文档为准，
  /// 一次落盘。刻意不触发 [changes]：数据刚由同步写入，不应再唤起一轮
  /// 自动同步；界面刷新由同步控制器 invalidate provider 完成。
  Future<void> applySyncedData({
    required List<WatchSnapshot> history,
    required List<WatchSnapshot> favorites,
    required Map<String, int> deletedHistory,
    required Map<String, int> deletedFavorites,
  }) async {
    _history = List<WatchSnapshot>.of(history);
    _favorites = List<WatchSnapshot>.of(favorites);
    _sortByTime(_history);
    _sortByTime(_favorites);
    if (_history.length > historyLimit) {
      _history.removeRange(historyLimit, _history.length);
    }
    _deletedHistory
      ..clear()
      ..addAll(deletedHistory);
    _deletedFavorites
      ..clear()
      ..addAll(deletedFavorites);
    await _saveHistory();
    await _saveFavorites();
    await _saveTombstones();
  }

  static int _now() => DateTime.now().millisecondsSinceEpoch;

  static void _sortByTime(List<WatchSnapshot> entries) {
    entries.sort(
      (WatchSnapshot a, WatchSnapshot b) => b.lastWatchAt.compareTo(
        a.lastWatchAt,
      ),
    );
  }

  Future<void> _saveHistory() async {
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) {
      return;
    }
    await prefs.setString(historyKey, encodeEntries(_history));
  }

  Future<void> _saveFavorites() async {
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) {
      return;
    }
    await prefs.setString(favoritesKey, encodeEntries(_favorites));
  }

  Future<void> _saveTombstones() async {
    _pruneTombstones();
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) {
      return;
    }
    await prefs.setString(
      deletedHistoryKey,
      jsonEncode(_deletedHistory),
    );
    await prefs.setString(
      deletedFavoritesKey,
      jsonEncode(_deletedFavorites),
    );
  }

  /// 丢弃过期墓碑；已复活（记录比删除更新）或条目本就不存在时也一并清掉。
  void _pruneTombstones() {
    final int cutoff =
        DateTime.now().subtract(tombstoneRetention).millisecondsSinceEpoch;
    final Map<String, WatchSnapshot> historyById = <String, WatchSnapshot>{
      for (final WatchSnapshot entry in _history) entry.seriesId: entry,
    };
    final Map<String, WatchSnapshot> favoritesById = <String, WatchSnapshot>{
      for (final WatchSnapshot entry in _favorites) entry.seriesId: entry,
    };
    _deletedHistory.removeWhere((String id, int deletedAt) {
      if (deletedAt < cutoff) {
        return true;
      }
      final WatchSnapshot? record = historyById[id];
      return record != null && record.lastWatchAt >= deletedAt;
    });
    _deletedFavorites.removeWhere((String id, int deletedAt) {
      if (deletedAt < cutoff) {
        return true;
      }
      final WatchSnapshot? record = favoritesById[id];
      return record != null && record.lastWatchAt >= deletedAt;
    });
  }

  void _notify() {
    if (_changes.isClosed) {
      return;
    }
    _changes.add(null);
  }

  /// 条目列表 → 存储字符串（测试播种复用同一格式）。
  static String encodeEntries(List<WatchSnapshot> entries) {
    return jsonEncode(
      <Object>[for (final WatchSnapshot entry in entries) entry.toJson()],
    );
  }

  static Map<String, int> _decodeTombstones(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const <String, int>{};
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map) {
        return <String, int>{
          for (final MapEntry<Object?, Object?> entry in decoded.entries)
            if (entry.key is String && entry.value is num)
              entry.key! as String: (entry.value! as num).toInt(),
        };
      }
    } on FormatException {
      // 脏数据按空处理。
    }
    return const <String, int>{};
  }

  static List<WatchSnapshot> _decodeList(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const <WatchSnapshot>[];
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is List) {
        return <WatchSnapshot>[
          for (final Object? item in decoded)
            if (item is Map)
              WatchSnapshot.fromJson(item.cast<String, Object?>()),
        ];
      }
    } on FormatException {
      // 脏数据按空处理，等待新写入覆盖。
    } on TypeError {
      // 同上：字段类型异常的 JSON 不应打崩读取。
    }
    return const <WatchSnapshot>[];
  }
}
