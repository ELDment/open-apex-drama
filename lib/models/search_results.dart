import 'package:flutter/foundation.dart';

import 'drama.dart';

/// 搜索结果分组：官方接口会把「关键词直接命中」和「猜你喜欢」混在同一页。
///
/// 命中判定只做标题包含匹配——这是客户端能稳定拿到的唯一信号（官方的
/// `search_high_light` 字段 SDK 尚未透传）。宁可多算命中，也不要把真正
/// 搜到的剧藏进推荐位。
@immutable
class SearchResultGroups {
  const SearchResultGroups({
    required this.matched,
    required this.suggested,
  });

  /// 标题直接包含关键词的结果，保持服务端原有顺序。
  final List<Drama> matched;

  /// 无关键词命中、由服务端语义推荐带出的同类内容。
  final List<Drama> suggested;

  bool get isEmpty => matched.isEmpty && suggested.isEmpty;

  bool get hasSuggested => suggested.isNotEmpty;
}

/// 按标题是否包含 [query] 把结果拆成精准命中与猜你喜欢。
///
/// 匹配忽略大小写与空白，兼容「持械 入宋」这类带空格输入。
SearchResultGroups groupSearchResults(Iterable<Drama> items, String query) {
  final List<Drama> matched = <Drama>[];
  final List<Drama> suggested = <Drama>[];
  for (final Drama drama in items) {
    if (titleMatchesQuery(drama.title, query)) {
      matched.add(drama);
    } else {
      suggested.add(drama);
    }
  }
  return SearchResultGroups(matched: matched, suggested: suggested);
}

/// 标题是否直接命中关键词；忽略大小写与空白。
bool titleMatchesQuery(String title, String query) {
  final String needle = _normalize(query);
  return needle.isEmpty || _normalize(title).contains(needle);
}

String _normalize(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
