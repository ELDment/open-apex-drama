import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_data.dart';
import '../models/drama.dart';
import '../providers/data_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/ambient_glow.dart';
import '../widgets/app_icon_button.dart';
import '../widgets/drama_card.dart';
import '../widgets/page_layout.dart';
import '../widgets/poster_artwork.dart';
import '../widgets/section_header.dart';
import 'drama_detail_screen.dart';
import 'rank_screen.dart';
import 'recent_updates_screen.dart';
import 'search_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const List<String> _tabs = <String>['推荐', '漫剧', '短剧', '电影'];

  int _tabIndex = 0;

  /// 当前频道的分页游标；空串表示第一页。
  String _cursor = '';

  /// 本地轮转次数：仅在服务端没有下一页（单页频道 / 降级数据）时使用。
  int _rotation = 0;
  int _bannerIndex = 0;
  late final PageController _bannerController = PageController();

  @override
  void dispose() {
    _bannerController.dispose();
    super.dispose();
  }

  /// 当前频道数据（含 mock 降级标记）。
  AsyncValue<HomeFeed> get _feedAsync =>
      ref.watch(homeFeedProvider(HomeFeedKey(_tabs[_tabIndex], _cursor)));

  /// 兜底轮转：服务端已无下一页时至少让「换一换」有可见反馈。
  List<Drama> _rotated(List<Drama> base) {
    if (_rotation == 0 || base.length < 2) {
      return base;
    }
    final int offset = _rotation % base.length;
    return <Drama>[...base.sublist(offset), ...base.sublist(0, offset)];
  }

  /// 「换一换」：优先取服务端的下一页内容，没有下一页才退回本地轮转。
  void _shuffleFeed() {
    final HomeFeed? feed = _feedAsync.value;
    if (feed == null) {
      return; // 上一页还没加载完，避免并发翻页。
    }
    final String next = feed.hasMore && feed.cursor.isNotEmpty
        ? feed.cursor
        : '';
    if (next != _cursor) {
      // 有下一页 → 换一批内容；已在最后一页 → 回到第一页重新开始。
      setState(() {
        _cursor = next;
        _rotation = 0;
      });
      return;
    }
    setState(() => _rotation++);
  }

  void _onSearch() {
    openSearch(context);
  }

  void _openRank() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => const RankScreen(),
      ),
    );
  }

  void _openUpdates() {
    openRecentUpdates(context);
  }

  void _retry() {
    ref.invalidate(homeFeedProvider(HomeFeedKey(_tabs[_tabIndex], _cursor)));
  }

  @override
  Widget build(BuildContext context) {
    final double horizontal = horizontalPagePadding(context);
    final double contentWidth = pageContentWidth(context);
    final int columns = dramaGridColumns(contentWidth);
    final double cardWidth = (contentWidth - (columns - 1) * 11) / columns;
    final double itemExtent = cardWidth * 4 / 3 + 62;
    final AsyncValue<HomeFeed> feedAsync = _feedAsync;
    // 「换一换」轮转后的展示列表；推荐网格与轮播共用，否则桌面端点了没反应。
    final List<Drama> feed = _rotated(
      feedAsync.value?.items ?? const <Drama>[],
    );
    final HomeFeed? feedValue = feedAsync.value;

    return AmbientGlow(
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(horizontal, 6, horizontal - 8, 0),
                child: _HomeTopBar(
                  selectedIndex: _tabIndex,
                  onSelect: (int index) => setState(() {
                    _tabIndex = index;
                    // 换频道回到该频道第一页，避免沿用上一个频道的游标。
                    _cursor = '';
                    _rotation = 0;
                  }),
                  onSearch: _onSearch,
                  onRank: _openRank,
                ),
              ),
            ),
            if (feedValue != null && feedValue.isFallback)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(horizontal, 10, horizontal, 0),
                  child: _FallbackBanner(
                    reason: feedValue.fallbackReason,
                    onRetry: _retry,
                  ),
                ),
              ),
            // 首页轮播：移动端保留；桌面版暂时隐藏（宽窗下横幅比例失衡，
            // 且当前没有运营位内容）。_HeroCarousel 代码保留，恢复时去掉条件即可。
            if (!Platform.isWindows)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 0),
                sliver: SliverToBoxAdapter(
                  child: _HeroCarousel(
                    controller: _bannerController,
                    activeIndex: _bannerIndex,
                    banners: feed.take(3).toList(growable: false),
                    onPageChanged: (int index) =>
                        setState(() => _bannerIndex = index),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 12),
                child: SectionHeader(
                  title: '为你推荐',
                  trailing: '换一换',
                  trailingIcon: Icons.refresh_rounded,
                  onTrailingTap: _shuffleFeed,
                ),
              ),
            ),
            if (feedAsync.isLoading && feed.isEmpty)
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: horizontal),
                sliver: SliverGrid(
                  gridDelegate:
                      SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 18,
                    crossAxisSpacing: 11,
                    mainAxisExtent: itemExtent,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) =>
                        const _SkeletonCard(),
                    childCount: columns * 2,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: horizontal),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 18,
                    crossAxisSpacing: 11,
                    mainAxisExtent: itemExtent,
                  ),
                  delegate: SliverChildBuilderDelegate((
                    BuildContext context,
                    int index,
                  ) {
                    final Drama drama = feed[index];
                    return DramaCard(
                      drama: drama,
                      onTap: () => openDramaDetail(context, drama),
                    );
                  }, childCount: feed.length),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(horizontal, 26, horizontal, 12),
                child: SectionHeader(
                  title: '最近更新',
                  trailing: '查看更多',
                  onTrailingTap: _openUpdates,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 198,
                child: _RecentUpdatesRow(horizontal: horizontal),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 26)),
          ],
        ),
      ),
    );
  }
}

/// 降级提示条：真实数据拉取失败时显示原因并允许重试。
class _FallbackBanner extends StatelessWidget {
  const _FallbackBanner({required this.reason, required this.onRetry});

  final String reason;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Material(
      color: colors.accentSoft,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onRetry,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: <Widget>[
              Icon(Icons.cloud_off_rounded, size: 15, color: colors.accentText),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '演示数据 · $reason',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.25,
                    color: colors.accentText,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '点按重试',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: colors.accentText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final Color base = colors.surfaceMuted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 9),
        Container(
          height: 12,
          width: 72,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 5),
        Container(
          height: 9,
          width: 48,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({
    required this.selectedIndex,
    required this.onSelect,
    required this.onSearch,
    required this.onRank,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onSearch;
  final VoidCallback onRank;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (int i = 0; i < _HomeScreenState._tabs.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 18),
                    child: _TopTab(
                      label: _HomeScreenState._tabs[i],
                      selected: i == selectedIndex,
                      onTap: () => onSelect(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 4),
        AppIconButton(
          icon: Icons.emoji_events_outlined,
          tooltip: '榜单',
          onPressed: onRank,
          size: 38,
          iconSize: 21,
          plain: true,
        ),
        AppIconButton(
          icon: Icons.search_rounded,
          tooltip: '搜索',
          onPressed: onSearch,
          size: 38,
          iconSize: 22,
          plain: true,
        ),
      ],
    );
  }
}

class _TopTab extends StatelessWidget {
  const _TopTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontSize: selected ? 19 : 14.5,
                  height: 1.25,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  color: selected ? colors.textPrimary : colors.textSecondary,
                  letterSpacing: 0.1,
                ),
                child: Text(label),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: selected ? 16 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: colors.brand,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCarousel extends StatelessWidget {
  const _HeroCarousel({
    required this.controller,
    required this.activeIndex,
    required this.banners,
    required this.onPageChanged,
  });

  final PageController controller;
  final int activeIndex;
  final List<Drama> banners;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    if (banners.isEmpty) {
      return const SizedBox(height: 0);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // 移动端维持 1.30 竖版比例；桌面同比例但限高 380：更宽的窗口
          // 不再线性撑高（1.30 在 900+ 宽会撑出 700px），窄窗口自动回到
          // 原比例，任何宽度都不会压到底部标题溢出。
          final double height = math.min(constraints.maxWidth / 1.30, 380);
          return SizedBox(
            height: Platform.isWindows
                ? height
                : constraints.maxWidth / 1.30,
            child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            PageView.builder(
              controller: controller,
              itemCount: banners.length,
              onPageChanged: onPageChanged,
              itemBuilder: (BuildContext context, int index) {
                return _HeroPage(drama: banners[index]);
              },
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: IgnorePointer(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    for (int i = 0; i < banners.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        width: i == activeIndex ? 14 : 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: i == activeIndex
                              ? colors.brand
                              : Colors.white.withValues(alpha: 0.38),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
      ),
    );
  }
}

class _HeroPage extends StatelessWidget {
  const _HeroPage({required this.drama});

  final Drama drama;

  String get _stackedTitle {
    if (drama.title.length <= 2) {
      return drama.title;
    }
    final int middle = (drama.title.length / 2).ceil();
    return '${drama.title.substring(0, middle)}\n'
        '${drama.title.substring(middle)}';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        PosterArtwork(drama: drama, variant: PosterVariant.full),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
              colors: <Color>[
                Colors.black.withValues(alpha: 0.82),
                Colors.black.withValues(alpha: 0.30),
                Colors.transparent,
              ],
              stops: const <double>[0, 0.48, 1],
            ),
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => openDramaDetail(context, drama),
            splashColor: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              Text(
                _stackedTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 30,
                  height: 1.12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 3,
                  color: Colors.white,
                  fontFamilyFallback: const <String>[
                    'Songti SC',
                    'STSong',
                    'Noto Serif CJK SC',
                    'serif',
                  ],
                  shadows: <Shadow>[
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  if (drama.rating > 0) ...<Widget>[
                    Text(
                      '${drama.ratingLabel}分',
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFFB199),
                      ),
                    ),
                    _Dot(),
                  ],
                  if (drama.viewers.isNotEmpty) ...<Widget>[
                    Text(
                      '${drama.viewers}在追',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.2,
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                    _Dot(),
                  ],
                  // 上游集数缺失（0）时隐藏，避免「全0集」。
                  if (drama.episodes > 0)
                    Text(
                      '全${drama.episodes}集',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.2,
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.40),
      ),
    );
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({required this.drama, required this.onTap});

  final Drama drama;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return SizedBox(
      width: 116,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              height: 148,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    PosterArtwork(drama: drama),
                    // 上游集数缺失（0）时隐藏角标。
                    if (drama.episodes > 0)
                      Positioned(
                        left: 7,
                        bottom: 7,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.52),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '全${drama.episodes}集',
                            style: TextStyle(
                              fontSize: 8.5,
                              height: 1.1,
                              color: Colors.white.withValues(alpha: 0.92),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              drama.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${drama.category} · ${drama.ratingLabel}分',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.25,
                color: colors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// 最近更新横滑：newReleases 真实数据，加载/失败回落 mock 过渡。
class _RecentUpdatesRow extends ConsumerWidget {
  const _RecentUpdatesRow({required this.horizontal});

  final double horizontal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Drama>> async =
        ref.watch(newReleasesProvider(''));
    final List<Drama> items =
        async.value ?? mockRecentUpdates;
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: horizontal),
      itemCount: items.length,
      separatorBuilder: (BuildContext _, int _) => const SizedBox(width: 11),
      itemBuilder: (BuildContext context, int index) {
        final Drama drama = items[index];
        return _UpdateCard(
          drama: drama,
          onTap: () => openDramaDetail(context, drama),
        );
      },
    );
  }
}
