import 'package:flutter/material.dart';

import 'drama.dart';

/// 发现页（首页频道）的一页：条目 + 下一页游标。
///
/// [cursor] 为空表示没有下一页；调用方把它原样回传给仓库即可继续翻页。
@immutable
class DramaPage {
  const DramaPage({
    required this.items,
    this.cursor = '',
    this.hasMore = false,
  });

  final List<Drama> items;
  final String cursor;
  final bool hasMore;
}

/// 榜单页数据：顶部内容/榜单 Tab + 条目列表。
@immutable
class RankTab {
  const RankTab({
    required this.label,
    this.contentId = '',
    this.boardId = '',
    this.selected = false,
  });

  final String label;
  final String contentId;
  final String boardId;
  final bool selected;
}

@immutable
class RankEntry {
  const RankEntry({
    required this.rank,
    required this.drama,
    this.score = '',
    this.actor = '',
  });

  final int rank;
  final Drama drama;

  /// 显示热度，如 "2550万热度"。
  final String score;
  final String actor;
}

@immutable
class RankPage {
  const RankPage({required this.tabs, required this.entries});

  final List<RankTab> tabs;
  final List<RankEntry> entries;
}

/// 搜索候选：联想词或热词条目。
@immutable
class SearchCandidate {
  const SearchCandidate({
    required this.text,
    this.seriesId = '',
    this.coverUrl = '',
    this.episodeCount = 0,
    this.score = '',
  });

  final String text;

  /// 热词条目携带剧集信息；纯联想词为空。
  final String seriesId;
  final String coverUrl;
  final int episodeCount;
  final String score;
}

/// 搜索首页（未输入时）：猜你想搜 + 热搜榜。
@immutable
class SearchHome {
  const SearchHome({required this.guesses, required this.hotBoard});

  final List<SearchCandidate> guesses;

  /// 主热搜榜（HotSearch.boards 第一个）。
  final List<SearchCandidate> hotBoard;
}

/// 分类筛选面板：多个筛选项（题材/状态/排序…），每项一组可选值。
@immutable
class FilterGroupData {
  const FilterGroupData({
    required this.key,
    required this.name,
    required this.options,
  });

  final String key;
  final String name;
  final List<(String label, String value)> options;
}
