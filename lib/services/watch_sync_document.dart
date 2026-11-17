import 'dart:convert';

import '../app_state/sync_settings.dart';
import '../data/local/watch_store.dart';

/// 云端同步文档：收藏 + 观看记录（含进度/集数）+ 删除墓碑。
///
/// 采用「单 JSON 文件 + 记录级时间戳合并」而不是多文件 / 数据库：
/// WebDAV 没有服务端合并能力，多文件逐个比对请求数会成倍增长；单个
/// 文档可以一次 GET / 一次 PUT 完成双向同步，且内容可直接用文本编辑器
/// 查看。每个条目自带 `lastWatchAt` 作为版本时间，删除记录写入墓碑，
/// 冲突时「新者胜」。
class SyncDocument {
  const SyncDocument({
    required this.history,
    required this.favorites,
    required this.deletedHistory,
    required this.deletedFavorites,
    this.settings,
    this.updatedAt = 0,
  });

  static const int schemaVersion = 1;
  static const String appId = 'ApexDrama';

  /// 文件名固定：远程目录由用户配置。
  static const String fileName = 'watch-sync.json';

  final List<WatchSnapshot> history;
  final List<WatchSnapshot> favorites;

  /// seriesId → 删除时间（unix 毫秒）。
  final Map<String, int> deletedHistory;
  final Map<String, int> deletedFavorites;

  /// 应用设置（倍速、昵称）。老版本客户端不认这个字段，忽略即可；
  /// 它们回写云端时会丢字段，属于已知的降级行为。
  final SyncableSettings? settings;

  /// 文档自身更新时间，仅作可读信息，不参与合并。
  final int updatedAt;

  factory SyncDocument.empty() {
    return const SyncDocument(
      history: <WatchSnapshot>[],
      favorites: <WatchSnapshot>[],
      deletedHistory: <String, int>{},
      deletedFavorites: <String, int>{},
    );
  }

  factory SyncDocument.fromStore(WatchStore store, {SyncableSettings? settings}) {
    return SyncDocument(
      history: store.history(),
      favorites: store.favorites(),
      deletedHistory: store.deletedHistory(),
      deletedFavorites: store.deletedFavorites(),
      settings: settings,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'app': appId,
      'schema': schemaVersion,
      'updatedAt': updatedAt,
      'history': <Object>[
        for (final WatchSnapshot entry in _sortedById(history)) entry.toJson(),
      ],
      'favorites': <Object>[
        for (final WatchSnapshot entry in _sortedById(favorites))
          entry.toJson(),
      ],
      'deletedHistory': _sortedMap(deletedHistory),
      'deletedFavorites': _sortedMap(deletedFavorites),
      if (settings != null) 'settings': settings!.toJson(),
      if (settings != null) 'settingsUpdatedAt': settings!.updatedAt,
    };
  }

  String toJsonString({bool pretty = true}) {
    final Object json = toJson();
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(json)
        : jsonEncode(json);
  }

  /// 解析云端文件。结构不合法时抛 [FormatException]（调用方应停止同步，
  /// 避免用空数据覆盖用户的云端文件）。
  factory SyncDocument.fromJsonString(String raw) {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('云端文件不是 JSON 对象');
    }
    final Map<String, Object?> json = decoded.cast<String, Object?>();
    final Object? historyRaw = json['history'];
    final Object? favoritesRaw = json['favorites'];
    if (historyRaw != null && historyRaw is! List) {
      throw const FormatException('history 字段格式错误');
    }
    if (favoritesRaw != null && favoritesRaw is! List) {
      throw const FormatException('favorites 字段格式错误');
    }
    return SyncDocument(
      history: _decodeEntries(historyRaw),
      favorites: _decodeEntries(favoritesRaw),
      deletedHistory: _decodeTombstones(json['deletedHistory']),
      deletedFavorites: _decodeTombstones(json['deletedFavorites']),
      settings: SyncableSettings.fromJson(
        json['settings'],
        (json['settingsUpdatedAt'] as num?)?.toInt() ?? 0,
      ),
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
    );
  }

  /// 内容签名：忽略 updatedAt / 排版差异，用于判断云端是否需要重写。
  String contentSignature() {
    return jsonEncode(<String, Object?>{
      'history': <Object>[
        for (final WatchSnapshot entry in _sortedById(history)) entry.toJson(),
      ],
      'favorites': <Object>[
        for (final WatchSnapshot entry in _sortedById(favorites))
          entry.toJson(),
      ],
      'deletedHistory': _sortedMap(deletedHistory),
      'deletedFavorites': _sortedMap(deletedFavorites),
      if (settings != null) 'settings': settings!.toJson(),
    });
  }

  static List<WatchSnapshot> _decodeEntries(Object? raw) {
    if (raw is! List) {
      return const <WatchSnapshot>[];
    }
    final List<WatchSnapshot> entries = <WatchSnapshot>[];
    for (final Object? item in raw) {
      if (item is! Map) {
        continue;
      }
      try {
        final WatchSnapshot entry = WatchSnapshot.fromJson(
          item.cast<String, Object?>(),
        );
        if (entry.seriesId.isNotEmpty) {
          entries.add(entry);
        }
      } catch (_) {
        // 单条脏数据跳过，不影响其余记录同步。
      }
    }
    return entries;
  }

  static Map<String, int> _decodeTombstones(Object? raw) {
    if (raw is! Map) {
      return const <String, int>{};
    }
    return <String, int>{
      for (final MapEntry<Object?, Object?> entry in raw.entries)
        if (entry.key is String && entry.value is num)
          entry.key! as String: (entry.value! as num).toInt(),
    };
  }

  static List<WatchSnapshot> _sortedById(List<WatchSnapshot> entries) {
    final List<WatchSnapshot> copy = List<WatchSnapshot>.of(entries)
      ..sort((WatchSnapshot a, WatchSnapshot b) => a.seriesId.compareTo(b.seriesId));
    return copy;
  }

  static Map<String, int> _sortedMap(Map<String, int> source) {
    final List<String> keys = source.keys.toList()..sort();
    return <String, int>{for (final String key in keys) key: source[key]!};
  }
}

/// 双向合并：同一 seriesId 取 `lastWatchAt` 更新者；墓碑时间晚于记录
/// 时间则视为删除。历史按上限裁剪，三端（本机 / 云端 / 其他设备）收敛
/// 到同一份数据。
SyncDocument mergeSyncDocuments(
  SyncDocument local,
  SyncDocument remote,
) {
  final Map<String, int> deletedHistory = _mergeTombstones(
    local.deletedHistory,
    remote.deletedHistory,
  );
  final Map<String, int> deletedFavorites = _mergeTombstones(
    local.deletedFavorites,
    remote.deletedFavorites,
  );

  final List<WatchSnapshot> history = _mergeEntries(
    local.history,
    remote.history,
    deletedHistory,
  );
  if (history.length > WatchStore.historyLimit) {
    history.removeRange(WatchStore.historyLimit, history.length);
  }
  _dropObsoleteTombstones(deletedHistory, history);

  final List<WatchSnapshot> favorites = _mergeEntries(
    local.favorites,
    remote.favorites,
    deletedFavorites,
  );
  _dropObsoleteTombstones(deletedFavorites, favorites);

  final int updatedAt = <int>[
    local.updatedAt,
    remote.updatedAt,
    if (history.isNotEmpty) history.first.lastWatchAt,
    if (favorites.isNotEmpty) favorites.first.lastWatchAt,
    ...deletedHistory.values,
    ...deletedFavorites.values,
  ].fold<int>(0, (int max, int value) => value > max ? value : max);

  return SyncDocument(
    history: history,
    favorites: favorites,
    deletedHistory: deletedHistory,
    deletedFavorites: deletedFavorites,
    settings: _mergeSettings(local.settings, remote.settings),
    updatedAt: updatedAt,
  );
}

/// 设置整块合并：谁的 [SyncableSettings.updatedAt] 更新用谁；
/// 只有一边有设置时直接采用那边。
SyncableSettings? _mergeSettings(
  SyncableSettings? local,
  SyncableSettings? remote,
) {
  if (local == null) {
    return remote;
  }
  if (remote == null) {
    return local;
  }
  return remote.updatedAt > local.updatedAt ? remote : local;
}

List<WatchSnapshot> _mergeEntries(
  List<WatchSnapshot> local,
  List<WatchSnapshot> remote,
  Map<String, int> tombstones,
) {
  final Map<String, WatchSnapshot> byId = <String, WatchSnapshot>{};
  // 远端先放、本地后放：时间相同时保留本地对象。
  for (final WatchSnapshot entry in <WatchSnapshot>[...remote, ...local]) {
    final WatchSnapshot? existing = byId[entry.seriesId];
    if (existing == null || entry.lastWatchAt >= existing.lastWatchAt) {
      byId[entry.seriesId] = entry;
    }
  }
  byId.removeWhere(
    (String id, WatchSnapshot entry) =>
        (tombstones[id] ?? 0) > entry.lastWatchAt,
  );
  final List<WatchSnapshot> merged = byId.values.toList()
    ..sort(
      (WatchSnapshot a, WatchSnapshot b) =>
          b.lastWatchAt.compareTo(a.lastWatchAt),
    );
  return merged;
}

Map<String, int> _mergeTombstones(
  Map<String, int> local,
  Map<String, int> remote,
) {
  final Map<String, int> merged = Map<String, int>.of(remote);
  for (final MapEntry<String, int> entry in local.entries) {
    final int? existing = merged[entry.key];
    if (existing == null || entry.value > existing) {
      merged[entry.key] = entry.value;
    }
  }
  final int cutoff = DateTime.now()
      .subtract(WatchStore.tombstoneRetention)
      .millisecondsSinceEpoch;
  merged.removeWhere((String _, int deletedAt) => deletedAt < cutoff);
  return merged;
}

/// 记录在删除之后又被观看 / 收藏（时间更新），墓碑失效并清理。
void _dropObsoleteTombstones(
  Map<String, int> tombstones,
  List<WatchSnapshot> records,
) {
  for (final WatchSnapshot record in records) {
    final int? deletedAt = tombstones[record.seriesId];
    if (deletedAt != null && record.lastWatchAt >= deletedAt) {
      tombstones.remove(record.seriesId);
    }
  }
}
