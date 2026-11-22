import 'package:flutter/material.dart';
import 'package:openhongguo/openhongguo.dart';

import '../models/drama.dart';
import '../models/playback.dart';

/// SDK 模型 → App 域模型的映射。SDK 类型不允许越过这一层。

/// 首页频道 → discover channel 取值（见 SDK internal/protocol/channel.go）。
///
/// 实测结论（B4）：SDK discover 无「电视剧」频道（书城频道全集：推荐/漫剧/真人剧/
/// 找剧/电影/听书/小说/社区/漫画/大视听/经典/知识），首页第 2 频道采用「漫剧」。
const Map<String, String> kDiscoverChannels = <String, String>{
  '推荐': '',
  '漫剧': '漫剧',
  '短剧': '真人剧',
  '电影': '电影',
};

/// 为字符串稳定生成一套封面渐变三色（真实剧集无内置封面色时的占位方案）。
List<Color> paletteFor(String seed) {
  int hash = 0x811c9dc5;
  for (final int code in seed.codeUnits) {
    hash ^= code;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  final double hueBase = (hash % 360).toDouble();
  final double hueMid = (hueBase + 28) % 360;
  final double hueDeep = (hueBase + 312) % 360;
  return <Color>[
    HSLColor.fromAHSL(1, hueMid, 0.62, 0.58).toColor(),
    HSLColor.fromAHSL(1, hueBase, 0.66, 0.44).toColor(),
    HSLColor.fromAHSL(1, hueDeep, 0.58, 0.30).toColor(),
  ];
}

/// SDK content_type → App 的界面类型名。
///
/// 详情接口拿到的剧如果只按默认「短剧」映射，漫剧/电影会被标错类型，
/// 推荐区也会跟着错位。
String kindForContentType(int value) {
  switch (value) {
    case 1004:
      return '漫剧';
    case 5:
      return '电影';
    case 6:
      return '电视剧';
    default:
      return '短剧';
  }
}

/// SeriesSummary（发现/搜索结果条目）→ Drama。
Drama dramaFromSummary(
  SeriesSummary summary, {
  String kind = '短剧',
  String? coverUrl,
  int seasonCount = 0,
}) {
  final String category = summary.category.trim();
  return Drama(
    id: summary.id,
    title: summary.title,
    kind: kind,
    category: category.isEmpty ? kind : category,
    tags: <String>[category.isEmpty ? kind : category],
    episodes: summary.episodeCount,
    rating: 0,
    viewers: '',
    description: summary.description,
    coverColors: paletteFor(summary.id + summary.title),
    // 搜索接口本身不带封面，调用方可传入补齐后的地址。
    coverUrl: coverUrl ?? summary.coverUrl,
    episodeTitles: const <String>[],
    seasonCount: seasonCount,
  );
}

/// 万级计数格式化：12345 → "1.2万"，123456789 → "1.23亿"。
String formatCount(int value) {
  if (value >= 100000000) {
    final double yi = value / 100000000;
    return '${yi.toStringAsFixed(yi >= 10 ? 0 : 2)}亿';
  }
  if (value >= 10000) {
    final double wan = value / 10000;
    return '${wan.toStringAsFixed(wan >= 10 ? 0 : 1)}万';
  }
  return '$value';
}

/// Series（getSeries 完整详情）→ Drama，补全摘要版没有的字段。
Drama dramaFromSeries(Series series, {String kind = '短剧'}) {
  final Drama base = dramaFromSummary(
    SeriesSummary(
      id: series.id,
      title: series.title,
      description: series.description,
      coverUrl: series.coverUrl,
      episodeCount: series.episodeCount,
      author: series.author,
      category: series.category,
    ),
    kind: kind,
  );
  return Drama(
    id: base.id,
    title: base.title,
    kind: base.kind,
    category: base.category,
    tags: series.subtitles.isNotEmpty ? series.subtitles : base.tags,
    episodes: base.episodes,
    rating: 0, // SDK 不提供数字评分；rating=0 时 UI 自动隐藏评分位
    viewers: series.followCount > 0 ? formatCount(series.followCount) : '',
    description: base.description,
    coverColors: base.coverColors,
    coverUrl: base.coverUrl,
    episodeTitles: const <String>[],
  );
}

/// 上游 publish_at 是 ISO 字符串（如 2026-11-10T16:04:04），封面角标只显示
/// 可读的「MM-DD」（具体时刻无意义，且角标宽度有限）。
/// 空串返回 null，无法解析时原样返回。
String? publishBadge(String raw) {
  if (raw.isEmpty) {
    return null;
  }
  final DateTime? time = DateTime.tryParse(raw)?.toLocal();
  if (time == null) {
    return raw;
  }
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(time.month)}-${two(time.day)}';
}

/// Episode（SDK 分集）→ EpisodeInfo。
EpisodeInfo episodeInfoFrom(Episode episode) {
  final String fallback = '第${episode.number}集';
  return EpisodeInfo(
    id: episode.id,
    seriesId: episode.seriesId,
    number: episode.number,
    title: episode.title.isEmpty ? fallback : episode.title,
    playable: episode.playable,
  );
}

/// PlaybackResult（SDK 播放解析）→ PlaybackBundle。
PlaybackBundle bundleFrom(PlaybackResult result) {
  final Playback playback = result.playback;
  return PlaybackBundle(
    episodeId: playback.episodeId,
    streams: <StreamInfo>[
      for (final VideoStream s in playback.streams)
        StreamInfo(
          definition: s.definition,
          url: s.url,
          backupUrl: s.backupUrl,
          codec: s.codec,
          width: s.width,
          height: s.height,
          hls: s.hls,
          dash: s.dash,
          protected: s.protected,
          encryption: s.encryption,
        ),
    ],
    contentKeyHex: result.contentKey?.key ?? '',
    expiresAt: playback.expiresAt,
    durationSeconds: playback.durationSeconds,
  );
}
