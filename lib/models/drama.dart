import 'package:flutter/material.dart';

@immutable
class Drama {
  const Drama({
    required this.id,
    required this.title,
    required this.kind,
    required this.category,
    required this.tags,
    required this.episodes,
    required this.rating,
    required this.viewers,
    required this.description,
    required this.coverColors,
    required this.episodeTitles,
    this.coverUrl = '',
    this.badge,
  });

  final String id;
  final String title;

  /// 短剧 / 电视剧 / 电影
  final String kind;
  final String category;
  final List<String> tags;
  final int episodes;
  final double rating;

  /// Human readable viewer count, e.g. "100.1万".
  final String viewers;
  final String description;

  /// Used by the cover placeholder instead of a network image.
  final List<Color> coverColors;

  /// 真实封面图 URL（SDK 提供，带 CDN 签名会过期）；
  /// mock 数据为空字符串，此时只显示渐变占位。
  final String coverUrl;
  final List<String> episodeTitles;
  final String? badge;

  String get ratingLabel => rating.toStringAsFixed(1);

  /// 集数缺失（0）时不显示「N集」，避免「分类 · 0集」。
  String get metaLabel => episodes > 0 ? '$category · $episodes集' : category;

  String get viewersLabel => '$viewers在追';

  String episodeTitle(int number) {
    if (episodeTitles.isEmpty) {
      return title;
    }
    final int index = (number - 1) % episodeTitles.length;
    return episodeTitles[index];
  }
}
