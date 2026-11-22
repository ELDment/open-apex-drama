import 'package:flutter/material.dart';

import 'drama.dart';

/// 多季信息。
@immutable
class SeasonInfo {
  const SeasonInfo({
    required this.seriesId,
    required this.title,
    required this.index,
    required this.episodeCount,
  });

  final String seriesId;
  final String title;
  final int index;
  final int episodeCount;
}

/// 详情页聚合数据：getSeries 完整数据 + 多季 + 相关推荐。
///
/// SDK 的单季接口（episodes/resolve）与聚合接口都按主 seriesId 寻址；
/// 多季剧切季时用对应 SeasonInfo.seriesId。
@immutable
class SeriesDetailData {
  const SeriesDetailData({
    required this.drama,
    this.seasons = const <SeasonInfo>[],
    this.recommend = const <Drama>[],
    this.recommendTitle = '相关推荐',
    this.isMultiSeason = false,
    this.relatedAlbumId = '',
    this.payType = 0,
  });

  /// 补全后的剧集（真实在追数/描述/题材，评分字段 SDK 不提供则为 0）。
  final Drama drama;
  final List<SeasonInfo> seasons;
  final List<Drama> recommend;

  /// 推荐区标题。匿名推荐是通用的「更多好剧」，不该再叫「相关推荐」；
  /// 按类型替换内容时用「更多漫剧 / 更多电影」。
  final String recommendTitle;
  final bool isMultiSeason;

  /// 多季合集 id（跳转合集用，暂未接入）。
  final String relatedAlbumId;

  /// 付费墙类型：0 免费、1 会员、2 单次购买（SDK PayType）。
  /// 只用于界面提示，不做准入判断——匿名访问常有前几集免费。
  final int payType;

  SeasonInfo? get currentSeason => seasons.isEmpty
      ? null
      : seasons.where((SeasonInfo s) => s.index == 1).firstOrNull ??
          seasons.first;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// 按季生成播放与记账用的 Drama：id、标题、集数取自该季，其余沿用整部剧。
///
/// 播放进度、收藏都以 seriesId 为键，各季天然独立成条目；详情页和播放页
/// 切季时都要用这一份换算，避免两处各写一套。
Drama dramaForSeason(Drama drama, SeasonInfo? season) {
  if (season == null) {
    return drama;
  }
  return Drama(
    id: season.seriesId,
    title: season.title,
    kind: drama.kind,
    category: drama.category,
    tags: drama.tags,
    episodes: season.episodeCount,
    rating: drama.rating,
    viewers: drama.viewers,
    description: drama.description,
    coverColors: drama.coverColors,
    episodeTitles: drama.episodeTitles,
    coverUrl: drama.coverUrl,
    badge: drama.badge,
  );
}
