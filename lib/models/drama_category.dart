import 'package:flutter/material.dart';

import 'drama.dart';

/// A browse category on the 分类 tab.
///
/// [displayCount] is the marketing library size shown on the tile; the actual
/// static mock library only contains a handful of titles per category.
@immutable
class DramaCategory {
  const DramaCategory({
    required this.name,
    required this.displayCount,
    required this.coverColors,
    this.matchTags = const <String>[],
    this.subtitle,
  });

  final String name;
  final int displayCount;
  final List<Color> coverColors;
  final List<String> matchTags;
  final String? subtitle;

  String get countLabel => '共$displayCount部';

  bool contains(Drama drama) {
    return drama.category == name ||
        matchTags.any((String tag) => drama.tags.contains(tag));
  }
}
