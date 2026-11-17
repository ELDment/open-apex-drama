import 'package:flutter/material.dart';

/// 一条公开列出的分集（来自 listEpisodes）。
@immutable
class EpisodeInfo {
  const EpisodeInfo({
    required this.id,
    required this.seriesId,
    required this.number,
    required this.title,
    required this.playable,
  });

  final String id;
  final String seriesId;
  final int number;
  final String title;
  final bool playable;
}

/// 播放模型中的一个流表示形式。
@immutable
class StreamInfo {
  const StreamInfo({
    required this.definition,
    required this.url,
    required this.backupUrl,
    this.codec = '',
    this.width = 0,
    this.height = 0,
    this.hls = false,
    this.dash = false,
    this.protected = false,
    this.encryption = '',
  });

  /// 分辨率标签，如 "720p"。
  final String definition;
  final String url;
  final String backupUrl;
  final String codec;
  final int width;
  final int height;
  final bool hls;
  final bool dash;

  /// 加密流标记；加密方案见 [encryption]（如 "cenc-aes-ctr"）。
  final bool protected;
  final String encryption;

  String get label {
    final StringBuffer sb = StringBuffer(definition.isEmpty ? '未知' : definition);
    if (hls) {
      sb.write(' · HLS');
    } else if (dash) {
      sb.write(' · DASH');
    }
    if (protected) {
      sb.write(' · 加密');
    }
    return sb.toString();
  }
}

/// 一次播放解析的结果：候选流 + 可用的内容密钥。
@immutable
class PlaybackBundle {
  const PlaybackBundle({
    required this.episodeId,
    required this.streams,
    this.contentKeyHex = '',
    this.expiresAt = 0,
    this.durationSeconds = 0,
  });

  final String episodeId;
  final List<StreamInfo> streams;

  /// 16 字节 AES 密钥的小写十六进制；未加密或解析失败时为空。
  final String contentKeyHex;

  /// 流 URL 失效时间（unix 秒）；0 表示未知。
  final int expiresAt;
  final int durationSeconds;

  bool get hasKey => contentKeyHex.isNotEmpty;

  /// 默认选流：先未加密，再取分辨率最高。
  StreamInfo? get preferred {
    if (streams.isEmpty) {
      return null;
    }
    final List<StreamInfo> clear =
        streams.where((StreamInfo s) => !s.protected && s.url.isNotEmpty).toList();
    final List<StreamInfo> pool = clear.isNotEmpty ? clear : streams;
    pool.sort((StreamInfo a, StreamInfo b) => b.height.compareTo(a.height));
    return pool.first;
  }
}
