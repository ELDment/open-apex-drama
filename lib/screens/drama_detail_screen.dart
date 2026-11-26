import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/watch_store.dart';
import '../data/mock_data.dart';
import '../models/drama.dart';
import '../models/playback.dart';
import '../models/series_detail.dart';
import '../providers/data_providers.dart';
import '../providers/watch_providers.dart';
import '../services/drama_share.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_pill_button.dart';
import '../widgets/page_layout.dart';
import '../widgets/poster_artwork.dart';
import '../widgets/section_header.dart';
import '../widgets/underline_tabs.dart';
import 'placeholder_screen.dart';
import 'player_screen.dart';

Future<void> openDramaDetail(BuildContext context, Drama drama) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext _) => DramaDetailScreen(drama: drama),
    ),
  );
}

class DramaDetailScreen extends ConsumerStatefulWidget {
  const DramaDetailScreen({super.key, required this.drama});

  final Drama drama;

  @override
  ConsumerState<DramaDetailScreen> createState() => _DramaDetailScreenState();
}

class _DramaDetailScreenState extends ConsumerState<DramaDetailScreen> {
  int _tabIndex = 0;
  int _episode = 1;

  /// 选中的季；-1 表示尚未选择，跟随详情数据的 currentSeason（第 1 季）。
  int _seasonIndex = -1;

  void _selectSeason(int index) {
    if (index == _seasonIndex) {
      return;
    }
    setState(() {
      _seasonIndex = index;
      // 换季后分集列表会重新加载，选集回到第 1 集。
      _episode = 1;
    });
  }

  void _retryDetail() {
    ref.invalidate(seriesDetailProvider(widget.drama.id));
  }

  @override
  Widget build(BuildContext context) {
    // 详情聚合（完整数据 + 多季 + 相关推荐）；加载中/失败时沿用传入的剧，
    // 页面始终有内容可看，不闪空也不白屏。
    final AsyncValue<SeriesDetailData> detailAsync =
        ref.watch(seriesDetailProvider(widget.drama.id));
    final SeriesDetailData? detail = detailAsync.value;
    final Drama drama = detail?.drama ?? widget.drama;

    final List<SeasonInfo> seasons = detail?.seasons ?? const <SeasonInfo>[];
    final bool showSeasons =
        detail != null && detail.isMultiSeason && seasons.isNotEmpty;
    int seasonIndex = _seasonIndex;
    if (showSeasons && (seasonIndex < 0 || seasonIndex >= seasons.length)) {
      // 默认选中第 1 季（currentSeason），数据异常时退回首项。
      final SeasonInfo current = detail.currentSeason ?? seasons.first;
      seasonIndex = seasons.indexOf(current);
      if (seasonIndex < 0) {
        seasonIndex = 0;
      }
    }

    // 真实分集：多季剧按选中季的 seriesId 拉取，其余情况用剧 id；
    // 加载失败时回退到剧本身的集数字段。
    final String episodesSeriesId =
        showSeasons ? seasons[seasonIndex].seriesId : drama.id;
    final AsyncValue<List<EpisodeInfo>> episodesAsync =
        ref.watch(episodesProvider(episodesSeriesId));
    // 收藏态与追剧页共用同一 store，状态天然联动。
    final bool isFavorite = ref.watch(isFavoriteProvider(drama.id));
    final double horizontal = horizontalPagePadding(context) < 20
        ? 20
        : horizontalPagePadding(context);
    // 推荐位：聚合数据就绪前用本地 mock 过渡，就绪后换真实推荐。
    // 匿名推荐是通用榜单，标题用服务端给的「更多好剧」而不是「相关推荐」；
    // 类型对齐后可以是「更多漫剧 / 更多电影」，拿不到同类型内容时为空并隐藏。
    final List<Drama> related = detail?.recommend ?? _related;
    final String recommendTitle = detail?.recommendTitle ?? '相关推荐';

    // The detail page is always dark, so it also uses the dark token set even
    // when the rest of the app is in light mode.
    return Theme(
      data: AppTheme.dark,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: AppTokens.detailBackground,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: AppTokens.detailBackground,
          body: Stack(
            children: <Widget>[
              Positioned(
                top: -180,
                left: -80,
                right: -80,
                height: 420,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: <Color>[
                          drama.coverColors[1].withValues(alpha: 0.24),
                          drama.coverColors[1].withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Column(
                  children: <Widget>[
                    _DetailTopBar(
                      drama: drama,
                      isFavorite: isFavorite,
                      onToggleFavorite: () => ref
                          .read(favoritesProvider.notifier)
                          .toggleFavorite(snapshotFromDrama(drama)),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          horizontal,
                          8,
                          horizontal,
                          22 + MediaQuery.paddingOf(context).bottom,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _DetailHead(drama: drama),
                            const SizedBox(height: 16),
                            Text(
                              drama.description,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.7,
                                color: Colors.white.withValues(alpha: 0.60),
                              ),
                            ),
                            const SizedBox(height: 18),
                            if (detailAsync.hasError) ...<Widget>[
                              _DetailErrorRow(onRetry: _retryDetail),
                              const SizedBox(height: 12),
                            ],
                            UnderlineTabs(
                              labels: const <String>['选集', '详情'],
                              selectedIndex: _tabIndex,
                              dense: true,
                              showDivider: false,
                              onChanged: (int index) =>
                                  setState(() => _tabIndex = index),
                            ),
                            const SizedBox(height: 14),
                            if (_tabIndex == 0)
                              _EpisodeSection(
                                episodes: episodesAsync.value,
                                isLoading: episodesAsync.isLoading,
                                selectedEpisode: _episode,
                                onSelect: (int episode) =>
                                    setState(() => _episode = episode),
                                // 季切换并入选集区：一个区域里先选季、再选集。
                                seasons: showSeasons
                                    ? seasons
                                    : const <SeasonInfo>[],
                                selectedSeasonIndex: seasonIndex,
                                onSelectSeason: _selectSeason,
                                // 分集拉取失败/未返回时用当前季的集数占位，
                                // 不能回落到整部剧的集数（各季集数不同）。
                                fallbackEpisodes: showSeasons
                                    ? seasons[seasonIndex].episodeCount
                                    : drama.episodes,
                                onPlay: () => openPlayer(
                                  context,
                                  dramaForSeason(
                                    drama,
                                    showSeasons ? seasons[seasonIndex] : null,
                                  ),
                                  episodeNumber: _episode,
                                ),
                              )
                            else
                              // 详情里的集数要跟当前选中的季一致，
                              // 不能一直显示整部剧的总集数。
                              _SynopsisSection(
                                drama: dramaForSeason(
                                  drama,
                                  showSeasons ? seasons[seasonIndex] : null,
                                ),
                                payType: detail?.payType ?? 0,
                              ),
                            if (related.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 26),
                              SectionHeader(
                                title: recommendTitle,
                                trailing: '查看更多',
                                onTrailingTap: () => openPlaceholder(
                                  context,
                                  title: recommendTitle,
                                  icon: Icons.movie_filter_outlined,
                                  message: '更多同类好剧正在整理中',
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 198,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: related.length,
                                  separatorBuilder: (BuildContext _, int _) =>
                                      const SizedBox(width: 11),
                                  itemBuilder: (BuildContext context, int index) {
                                    final Drama item = related[index];
                                    return _RelatedCard(
                                      drama: item,
                                      onTap: () =>
                                          openDramaDetail(context, item),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 聚合数据未就绪（加载中/失败）时的推荐位过渡列表。
  List<Drama> get _related => mockDramas
      .where((Drama item) => item.id != widget.drama.id)
      .take(6)
      .toList(growable: false);
}

class _SeasonRow extends StatefulWidget {
  const _SeasonRow({
    required this.seasons,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<SeasonInfo> seasons;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  State<_SeasonRow> createState() => _SeasonRowState();
}

class _SeasonRowState extends State<_SeasonRow> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 桌面滚轮默认不作用于横向列表：把垂直滚轮增量转成横向滚动。
    return Listener(
      onPointerSignal: (PointerSignalEvent event) {
        if (event is! PointerScrollEvent || !_controller.hasClients) {
          return;
        }
        final double target = (_controller.position.pixels +
                event.scrollDelta.dy)
            .clamp(0.0, _controller.position.maxScrollExtent);
        _controller.jumpTo(target);
      },
      child: SizedBox(
      key: const Key('detail-season-row'),
      height: 34,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        itemCount: widget.seasons.length,
        separatorBuilder: (BuildContext _, int _) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final SeasonInfo season = widget.seasons[index];
          final bool selected = index == widget.selectedIndex;
          return Semantics(
            button: true,
            selected: selected,
            child: Material(
              color: selected
                  ? const Color(0xFFE6E4EA)
                  : AppTokens.immersiveSurfaceRaised,
              borderRadius: BorderRadius.circular(10),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => widget.onSelect(index),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Center(
                    child: Text(
                      season.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.1,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected
                            ? AppTokens.immersiveAccentDeep
                            : Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      ),
    );
  }
}

/// 聚合数据拉取失败时的小字提示；主体内容仍然展示，点按重试。
class _DetailErrorRow extends StatelessWidget {
  const _DetailErrorRow({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTokens.immersiveSurfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTokens.immersiveHairline, width: 0.8),
      ),
      child: InkWell(
        onTap: onRetry,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.cloud_off_rounded,
                size: 14,
                color: AppTokens.immersiveTextTertiary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '完整信息加载失败，点按重试',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.25,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailTopBar extends StatelessWidget {
  const _DetailTopBar({
    required this.drama,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  final Drama drama;

  /// 收藏态：图标随状态切换（实心高亮 / 空心）。
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: '返回',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 19,
              color: Colors.white,
            ),
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          ),
          const Spacer(),
          IconButton(
            tooltip: isFavorite ? '取消收藏' : '收藏',
            onPressed: onToggleFavorite,
            icon: Icon(
              isFavorite
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              size: 22,
              color: isFavorite
                  ? AppTokens.immersiveAccentBright
                  : Colors.white,
            ),
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          ),
          IconButton(
            tooltip: '分享',
            onPressed: () => DramaShare.share(context, drama.title),
            icon: const Icon(
              Icons.ios_share_rounded,
              size: 20,
              color: Colors.white,
            ),
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          ),
        ],
      ),
    );
  }
}

class _DetailHead extends StatelessWidget {
  const _DetailHead({required this.drama});

  final Drama drama;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 112,
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 0.8,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: PosterArtwork(drama: drama, variant: PosterVariant.full),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                drama.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                drama.tags.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.2,
                  color: Colors.white.withValues(alpha: 0.52),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: <Widget>[
                  // 真实数据没有评分/在追数时隐藏，避免出现「0.0分 在追」。
                  if (drama.rating > 0)
                    Text(
                      '${drama.ratingLabel}分',
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: AppTokens.immersiveAccentBright,
                      ),
                    ),
                  if (drama.viewers.isNotEmpty)
                    Text(
                      '${drama.viewers}在追',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.2,
                        color: Colors.white.withValues(alpha: 0.58),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                '${drama.category} · 全${drama.episodes}集 · ${drama.kind}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.2,
                  color: Colors.white.withValues(alpha: 0.48),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 选集区：季切换 chips + 集号网格 + 立即播放。
///
/// 季切换并进这里（原先在 tab 上方单独一行），用户不用「先选季、再去下面
/// 找集号」。集数多时默认只渲染前 [_initialLimit] 集，底部给「展开全部」，
/// 兼顾滚动长度与首屏渲染成本。
class _EpisodeSection extends StatefulWidget {
  const _EpisodeSection({
    required this.episodes,
    required this.isLoading,
    required this.selectedEpisode,
    required this.onSelect,
    required this.onPlay,
    required this.fallbackEpisodes,
    this.seasons = const <SeasonInfo>[],
    this.selectedSeasonIndex = 0,
    this.onSelectSeason,
  });

  /// 真实分集列表；null 表示还在加载（此时用 [fallbackEpisodes] 占位）。
  final List<EpisodeInfo>? episodes;
  final bool isLoading;
  final int selectedEpisode;
  final ValueChanged<int> onSelect;
  final VoidCallback onPlay;

  /// 分集列表不可用时用于占位的集数（多季剧取当前季的集数）。
  final int fallbackEpisodes;

  /// 多季剧的季列表；不足两季时为空，不显示季行。
  final List<SeasonInfo> seasons;
  final int selectedSeasonIndex;
  final ValueChanged<int>? onSelectSeason;

  @override
  State<_EpisodeSection> createState() => _EpisodeSectionState();
}

class _EpisodeSectionState extends State<_EpisodeSection> {
  /// 默认只展示前 20 集；更多交给「展开全部」或播放页选集。
  static const int _initialLimit = 20;

  bool _expanded = false;

  @override
  void didUpdateWidget(covariant _EpisodeSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSeasonIndex != widget.selectedSeasonIndex) {
      _expanded = false; // 换季回到折叠态，避免一进来就铺满几百个按钮
    }
  }

  /// 服务端标记 disable_play 的分集不可播；分集列表未就绪时按可播处理。
  bool _playableAt(int index) {
    final List<EpisodeInfo>? episodes = widget.episodes;
    if (episodes == null || index >= episodes.length) {
      return true;
    }
    return episodes[index].playable;
  }

  @override
  Widget build(BuildContext context) {
    final int total = widget.episodes?.length ?? widget.fallbackEpisodes;
    final int visible =
        _expanded || total <= _initialLimit ? total : _initialLimit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.seasons.length > 1) ...<Widget>[
          _SeasonRow(
            seasons: widget.seasons,
            selectedIndex: widget.selectedSeasonIndex,
            onSelect: (int index) => widget.onSelectSeason?.call(index),
          ),
          const SizedBox(height: 12),
        ],
        if (total <= 0)
          Text(
            '该季暂未开播',
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.white.withValues(alpha: 0.60),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (int index = 0; index < visible; index++)
                _EpisodeChip(
                  number: index + 1,
                  selected: index + 1 == widget.selectedEpisode,
                  enabled: _playableAt(index),
                  onTap: () {
                    if (!_playableAt(index)) {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(content: Text('该集暂不可播放')),
                        );
                      return;
                    }
                    widget.onSelect(index + 1);
                  },
                ),
            ],
          ),
        if (total > visible) ...<Widget>[
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _expanded = true),
              child: Text('展开全部 $total 集', style: const TextStyle(fontSize: 12.5)),
            ),
          ),
        ],
        const SizedBox(height: 16),
        AppPillButton(
          label: '立即播放',
          icon: Icons.play_arrow_rounded,
          onPressed: widget.onPlay,
          expand: true,
          height: 52,
          radius: 14,
          fontSize: 15.5,
          fontWeight: FontWeight.w700,
          horizontalPadding: 20,
        ),
      ],
    );
  }
}

/// 单个集号按钮：选中态浅底深字，与季 chip 保持同一套视觉。
class _EpisodeChip extends StatelessWidget {
  const _EpisodeChip({
    required this.number,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final int number;
  final bool selected;
  final VoidCallback onTap;

  /// false 表示服务端禁止播放该集，置灰但仍可点（点了给提示）。
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final Color background = !enabled
        ? AppTokens.immersiveSurfaceRaised.withValues(alpha: 0.5)
        : selected
        ? const Color(0xFFE6E4EA)
        : AppTokens.immersiveSurfaceRaised;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 14,
                height: 1.1,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: !enabled
                    ? Colors.white.withValues(alpha: 0.34)
                    : selected
                    ? AppTokens.immersiveAccentDeep
                    : Colors.white.withValues(alpha: 0.76),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SynopsisSection extends StatelessWidget {
  const _SynopsisSection({required this.drama, this.payType = 0});

  final Drama drama;

  /// 付费墙类型（0 免费 / 1 会员 / 2 单集购买），只作提示不阻断。
  final int payType;

  @override
  Widget build(BuildContext context) {
    final List<(String, String)> rows = <(String, String)>[
      ('分类', drama.category),
      ('类型', drama.kind),
      ('集数', '全${drama.episodes}集'),
      ('评分', '${drama.ratingLabel}分'),
      ('状态', '全集已上线'),
      if (payType == 1) ('观看', '会员专享'),
      if (payType == 2) ('观看', '单集购买'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final (String label, String value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 62,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.2,
                      color: Colors.white.withValues(alpha: 0.40),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.2,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final String tag in <String>[
              drama.category,
              ...drama.tags,
              drama.kind,
            ])
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTokens.immersiveSurfaceRaised,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: AppTokens.immersiveHairline,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.2,
                    color: Colors.white.withValues(alpha: 0.66),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Icon(
              Icons.update_rounded,
              size: 14,
              color: Colors.white.withValues(alpha: 0.42),
            ),
            const SizedBox(width: 5),
            Text(
              '全集已上线 · 支持 1080P 与倍速',
              style: TextStyle(
                fontSize: 11,
                height: 1.2,
                color: Colors.white.withValues(alpha: 0.42),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RelatedCard extends StatelessWidget {
  const _RelatedCard({required this.drama, required this.onTap});

  final Drama drama;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              height: 142,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: PosterArtwork(drama: drama),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              drama.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: Colors.white.withValues(alpha: 0.84),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
