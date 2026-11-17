import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/catalog.dart';
import '../providers/data_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/ambient_glow.dart';
import '../widgets/empty_state.dart';
import '../widgets/page_layout.dart';
import '../widgets/poster_artwork.dart';
import '../widgets/underline_tabs.dart';
import 'drama_detail_screen.dart';

class RankScreen extends ConsumerStatefulWidget {
  const RankScreen({super.key});

  @override
  ConsumerState<RankScreen> createState() => _RankScreenState();
}

class _RankScreenState extends ConsumerState<RankScreen> {
  /// 默认榜单的 family 键：[contentId, boardId] 均传空串。
  /// const 字面量保证键值稳定，命中同一条 provider 缓存。
  static const List<String> _defaultIds = <String>['', ''];

  List<String> _ids = _defaultIds;
  int _tabIndex = 0;

  /// 最近一次拿到的 Tab 集合；切 Tab 重新加载时保持 Tab 条不闪空。
  List<RankTab> _tabs = const <RankTab>[];

  /// 是否已按服务端返回的 selected 标记对齐过默认 Tab。
  bool _tabSynced = false;

  AsyncValue<RankPage> get _pageAsync => ref.watch(rankPageProvider(_ids));

  void _onTabChanged(int index) {
    if (index < 0 || index >= _tabs.length || index == _tabIndex) {
      return;
    }
    final RankTab tab = _tabs[index];
    setState(() {
      _tabIndex = index;
      _ids = <String>[tab.contentId, tab.boardId];
    });
  }

  void _retry() {
    ref.invalidate(rankPageProvider(_ids));
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final double horizontal = horizontalPagePadding(context);
    final AsyncValue<RankPage> pageAsync = _pageAsync;
    final RankPage? page = pageAsync.value;
    final List<RankTab> pageTabs = page?.tabs ?? const <RankTab>[];

    // 首次拿到数据后对齐服务端标记的选中 Tab；无标记则保持第 0 个。
    if (!_tabSynced && pageTabs.isNotEmpty) {
      _tabSynced = true;
      final int selected = pageTabs.indexWhere((RankTab tab) => tab.selected);
      _tabIndex = selected >= 0 ? selected : 0;
    }
    if (pageTabs.isNotEmpty) {
      _tabs = pageTabs;
    }

    return AmbientGlow(
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '榜单',
                      style: TextStyle(
                        fontSize: 26,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '全站热播 · 每小时更新',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 0),
                child: _tabs.isEmpty
                    ? const _SkeletonTabs()
                    : UnderlineTabs(
                        labels: <String>[
                          for (final RankTab tab in _tabs) tab.label,
                        ],
                        selectedIndex: _tabIndex,
                        onChanged: _onTabChanged,
                      ),
              ),
            ),
            ..._bodySlivers(pageAsync, horizontal),
          ],
        ),
      ),
    );
  }

  /// 榜单主体三态：首载骨架 / 错误重试 / 空数据 / 正常列表。
  List<Widget> _bodySlivers(AsyncValue<RankPage> pageAsync, double horizontal) {
    if (pageAsync.isLoading && !pageAsync.hasValue) {
      return <Widget>[
        SliverPadding(
          padding: EdgeInsets.fromLTRB(horizontal, 6, horizontal, 0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) => const _SkeletonRankRow(),
              childCount: 6,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ];
    }

    if (pageAsync.hasError && !pageAsync.isLoading) {
      return <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 36),
            child: EmptyState(
              icon: Icons.leaderboard_outlined,
              title: '榜单加载失败',
              message: '网络似乎开小差了，稍后再试试',
              actionLabel: '重新加载',
              onAction: _retry,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ];
    }

    final List<RankEntry> entries =
        pageAsync.value?.entries ?? const <RankEntry>[];
    if (entries.isEmpty) {
      return <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 36),
            child: EmptyState(
              icon: Icons.leaderboard_outlined,
              title: '榜单正在整理中',
              message: '更多好剧正在集结，稍后再来看看',
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ];
    }

    // 桌面宽窗多列：榜单行 2-3 列并排，避免整行只放一个条目。
    final double width = MediaQuery.sizeOf(context).width;
    final int columns = width >= 1160 ? 3 : (width >= 720 ? 2 : 1);

    return <Widget>[
      SliverPadding(
        padding: EdgeInsets.fromLTRB(horizontal, 6, horizontal, 0),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((
            BuildContext context,
            int index,
          ) {
            final int start = index * columns;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (int j = start; j < start + columns; j++) ...<Widget>[
                    Expanded(
                      child: j < entries.length
                          ? _RankRow(
                              entry: entries[j],
                              onTap: () => openDramaDetail(
                                context,
                                entries[j].drama,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    if (j < start + columns - 1) const SizedBox(width: 18),
                  ],
                ],
              ),
            );
          }, childCount: (entries.length + columns - 1) ~/ columns),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 24),
          child: Center(
            child: Text(
              '榜单每日 00:00 更新 · 数据来自全站播放热度',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.3,
                color: context.colors.textTertiary,
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

/// Tab 数据未就绪时的占位条，高度与 [UnderlineTabs] 对齐。
class _SkeletonTabs extends StatelessWidget {
  const _SkeletonTabs();

  @override
  Widget build(BuildContext context) {
    final Color base = context.colors.surfaceMuted;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 2, top: 10, bottom: 7),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < 3; i++)
            Padding(
              padding: EdgeInsets.only(right: i == 2 ? 0 : 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    height: 14,
                    width: i == 0 ? 44 : 52,
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 榜单行骨架：名次 + 海报 + 两行文字的灰色占位。
class _SkeletonRankRow extends StatelessWidget {
  const _SkeletonRankRow();

  @override
  Widget build(BuildContext context) {
    final Color base = context.colors.surfaceMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 62,
            height: 84,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  height: 13,
                  width: 128,
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 9),
                Container(
                  height: 10,
                  width: 84,
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  width: 60,
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.entry, required this.onTap});

  final RankEntry entry;
  final VoidCallback onTap;

  int get _rank => entry.rank;

  Color _rankColor(AppColors colors) {
    if (_rank == 1) {
      return colors.brand;
    }
    if (_rank <= 3) {
      return colors.rankGold;
    }
    return colors.textTertiary;
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Semantics(
      button: true,
      label: '第$_rank名，${entry.drama.title}，${entry.score}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 34,
                child: Text(
                  '$_rank',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: _rank <= 3 ? 24 : 20,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    color: _rankColor(colors),
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 62,
                height: 84,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: colors.hairline.withValues(alpha: 0.7),
                    width: 0.8,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: PosterArtwork(
                    drama: entry.drama,
                    variant: PosterVariant.thumb,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      entry.drama.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: 13,
                          color: colors.brand,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            entry.score,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.2,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (entry.actor.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 5),
                      Text(
                        entry.actor,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          height: 1.2,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      entry.drama.metaLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.2,
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.play_circle_outline_rounded,
                size: 24,
                color: colors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
