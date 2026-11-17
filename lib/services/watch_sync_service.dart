import '../app_state/sync_settings.dart';
import '../data/local/watch_store.dart';
import 'watch_sync_document.dart';
import 'webdav_client.dart';
import 'webdav_sync_settings.dart';

/// 一次双向同步的结果（用于 UI 文案）。
class WatchSyncResult {
  const WatchSyncResult({
    required this.historyCount,
    required this.favoriteCount,
    required this.uploaded,
    required this.pulledRecords,
  });

  final int historyCount;
  final int favoriteCount;

  /// 云端文件是否被本次同步重写。
  final bool uploaded;

  /// 本次从云端合并进本机的条目数（含历史 + 收藏）。
  final int pulledRecords;
}

/// 同步时发现云端文件无法解析：中止而不是覆盖，避免把用户的云端数据
/// 用空文档冲掉。
class WatchSyncFormatException implements Exception {
  const WatchSyncFormatException(this.message);

  final String message;

  @override
  String toString() => 'WatchSyncFormatException: $message';
}

/// 观看数据同步编排：
/// 1. GET 云端 JSON（不存在视为空文档）；
/// 2. 与本地文档按记录时间戳合并（删除用墓碑传播）；
/// 3. 云端内容与合并结果不同才 PUT（省流量、省请求次数）；
/// 4. 把合并结果写回本地存储。
///
/// [SyncStrategy.localOverwrite] 时跳过第 2、4 步：本机数据直接覆盖云端。
class WatchSyncService {
  WatchSyncService({
    required this.config,
    this.strategy = SyncStrategy.merge,
    WebDavClient? client,
  }) : _client = client ?? WebDavClient(config: config);

  final WebDavConfig config;
  final SyncStrategy strategy;
  final WebDavClient _client;

  Future<WatchSyncResult> sync(WatchStore store) async {
    final SyncDocument local = SyncDocument.fromStore(
      store,
      settings: await readSyncableSettings(),
    );

    final String? remoteRaw;
    try {
      remoteRaw = await _client.download();
    } on FormatException {
      throw const WatchSyncFormatException(
        '云端同步文件无法按 UTF-8 解析，已停止同步以避免覆盖',
      );
    }
    if (strategy == SyncStrategy.localOverwrite) {
      return _overwriteRemote(local, remoteRaw);
    }
    SyncDocument remote;
    if (remoteRaw == null || remoteRaw.trim().isEmpty) {
      remote = SyncDocument.empty();
    } else {
      try {
        remote = SyncDocument.fromJsonString(remoteRaw);
      } on FormatException {
        throw const WatchSyncFormatException(
          '云端同步文件格式异常，已停止同步以避免覆盖，请检查远程目录中的 watch-sync.json',
        );
      }
    }

    final SyncDocument merged = mergeSyncDocuments(local, remote);
    // 设置（倍速/昵称）整块新者胜：合并结果与本地不同才落盘，
    // 避免每次同步都重写一份时间戳。
    final SyncableSettings? mergedSettings = merged.settings;
    if (mergedSettings != null &&
        mergedSettings.updatedAt != local.settings?.updatedAt) {
      await applySyncedSettings(mergedSettings);
    }

    final bool contentChanged =
        remoteRaw == null || merged.contentSignature() != remote.contentSignature();
    if (contentChanged) {
      await _client.upload(merged.toJsonString());
    }

    // 合并结果与本地一致时跳过写盘，避免无意义的变更通知。
    final bool localChanged =
        merged.contentSignature() != local.contentSignature();
    if (localChanged) {
      await store.applySyncedData(
        history: merged.history,
        favorites: merged.favorites,
        deletedHistory: merged.deletedHistory,
        deletedFavorites: merged.deletedFavorites,
      );
    }

    return WatchSyncResult(
      historyCount: merged.history.length,
      favoriteCount: merged.favorites.length,
      uploaded: contentChanged,
      pulledRecords: _countNew(local, merged),
    );
  }

  /// 「以本地为准」：不读云端内容做合并，直接把本机数据写成新的云端文件。
  /// 损坏的云端文件也直接替换（用户已在界面上确认过覆盖）。
  Future<WatchSyncResult> _overwriteRemote(
    SyncDocument local,
    String? remoteRaw,
  ) async {
    final SyncDocument document = SyncDocument(
      history: local.history,
      favorites: local.favorites,
      deletedHistory: local.deletedHistory,
      deletedFavorites: local.deletedFavorites,
      settings: local.settings,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    bool remoteDiffers = true;
    if (remoteRaw != null && remoteRaw.trim().isNotEmpty) {
      try {
        remoteDiffers =
            SyncDocument.fromJsonString(
              remoteRaw,
            ).contentSignature() !=
            document.contentSignature();
      } on FormatException {
        remoteDiffers = true;
      }
    }
    if (remoteDiffers) {
      await _client.upload(document.toJsonString());
    }
    return WatchSyncResult(
      historyCount: document.history.length,
      favoriteCount: document.favorites.length,
      uploaded: remoteDiffers,
      pulledRecords: 0,
    );
  }

  /// 测试连接（不读写同步文件）。
  Future<void> testConnection() => _client.testConnection();

  /// 合并后比本地多出来的条目数（仅用于提示「拉取了 N 条」）。
  static int _countNew(SyncDocument local, SyncDocument merged) {
    final Set<String> localIds = <String>{
      for (final WatchSnapshot entry in local.history) 'h:${entry.seriesId}',
      for (final WatchSnapshot entry in local.favorites) 'f:${entry.seriesId}',
    };
    int count = 0;
    for (final WatchSnapshot entry in merged.history) {
      if (!localIds.contains('h:${entry.seriesId}')) {
        count++;
      }
    }
    for (final WatchSnapshot entry in merged.favorites) {
      if (!localIds.contains('f:${entry.seriesId}')) {
        count++;
      }
    }
    return count;
  }
}
