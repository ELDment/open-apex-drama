import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mappers.dart';
import '../data/remote/openhongguo_service.dart';
import '../data/repository/repositories.dart';
import '../models/catalog.dart';
import '../models/drama.dart';
import '../providers/data_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/ambient_glow.dart';
import '../widgets/app_icon_button.dart';
import '../widgets/app_pill_button.dart';
import '../widgets/drama_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/page_layout.dart';
import '../widgets/section_header.dart';
import '../widgets/soft_chip.dart';
import 'drama_detail_screen.dart';

/// 搜索页入口：压栈全屏搜索页。
Future<void> openSearch(BuildContext context) {
  return Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (BuildContext _) => const SearchScreen()));
}

/// 搜索页三态：
/// 1. 未输入 → [searchHomeProvider]（猜你想搜 + 热搜榜）；
/// 2. 输入中（350ms debounce 后）→ [suggestProvider] 联想词；
/// 3. 已提交 → [searchResultProvider] 结果网格。
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  static const Duration _suggestDebounce = Duration(milliseconds: 350);

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  /// 输入框草稿（每次按键都更新）。
  String _draft = '';

  /// debounce 落地后的联想前缀；空串一律不请求。
  String _suggestQuery = '';

  /// 已提交的搜索词；与草稿一致时展示结果态。
  String _committed = '';

  Timer? _debounce;

  /// 追加的后续页（第一页来自 [searchResultProvider]）。
  List<Drama> _more = const <Drama>[];
  String _moreCursor = '';
  bool _moreHasMore = false;
  bool _loadingMore = false;

  /// [_more] 属于哪个关键词；换词后不再套用，避免结果串味。
  String _moreFor = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  bool get _showResults =>
      _committed.isNotEmpty && _draft.trim() == _committed;

  bool get _showSuggestions => !_showResults && _draft.trim().isNotEmpty;

  void _onChanged(String value) {
    final String text = value.trim();
    _debounce?.cancel();
    if (text.isEmpty) {
      // 空串不请求联想词，直接回到首页态。
      if (_draft.trim().isNotEmpty || _suggestQuery.isNotEmpty) {
        setState(() {
          _draft = '';
          _suggestQuery = '';
        });
      }
      return;
    }
    if (_draft != value) {
      setState(() => _draft = value);
    }
    _debounce = Timer(_suggestDebounce, () {
      if (!mounted || _suggestQuery == text) {
        return;
      }
      setState(() => _suggestQuery = text);
    });
  }

  void _resetPaging() {
    _more = const <Drama>[];
    _moreCursor = '';
    _moreHasMore = false;
    _moreFor = '';
  }

  /// 加载下一页并追加。游标取自当前关键词的最新一页响应，
  /// 换词后旧请求返回会因 [_moreFor] / [_committed] 不一致被丢弃。
  Future<void> _loadMore(String query, SearchPage page) async {
    if (_loadingMore) {
      return;
    }
    final bool chained = _moreFor == query;
    final String cursor = chained ? _moreCursor : page.cursor;
    if (cursor.isEmpty) {
      return;
    }
    setState(() => _loadingMore = true);
    try {
      final SearchPage next = await ref
          .read(catalogRepositoryProvider)
          .searchPage(query, cursor: cursor);
      if (!mounted || query != _committed) {
        return;
      }
      setState(() {
        final Set<String> seen = <String>{
          for (final Drama drama in page.items) drama.id,
          for (final Drama drama in _more) drama.id,
        };
        _more = <Drama>[
          ..._more,
          for (final Drama drama in next.items)
            if (seen.add(drama.id)) drama,
        ];
        _moreFor = query;
        _moreCursor = next.cursor;
        _moreHasMore = next.hasMore;
      });
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error.userMessage)));
      }
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  void _submit(String query) {
    final String text = query.trim();
    if (text.isEmpty) {
      _focusNode.requestFocus();
      return;
    }
    _debounce?.cancel();
    _focusNode.unfocus();
    setState(() {
      _committed = text;
      _draft = text;
      _suggestQuery = '';
      _resetPaging();
      if (_controller.text != text) {
        _controller.text = text;
        _controller.selection = TextSelection.collapsed(offset: text.length);
      }
    });
  }

  /// 清空输入回到首页态（也是空结果的兜底动作）。
  void _clear() {
    _debounce?.cancel();
    _focusNode.requestFocus();
    setState(() {
      _controller.clear();
      _draft = '';
      _suggestQuery = '';
      _committed = '';
      _resetPaging();
    });
  }

  /// 热词条目直跳详情：用候选词构造最小 Drama，缺失字段 UI 自动隐藏。
  void _openCandidate(SearchCandidate candidate) {
    final Drama drama = Drama(
      id: candidate.seriesId,
      title: candidate.text,
      kind: '短剧',
      category: '短剧',
      tags: const <String>['短剧'],
      episodes: candidate.episodeCount,
      rating: 0,
      viewers: '',
      description: '',
      coverColors: paletteFor(candidate.text),
      coverUrl: candidate.coverUrl,
      episodeTitles: const <String>[],
    );
    openDramaDetail(context, drama);
  }

  @override
  Widget build(BuildContext context) {
    final double horizontal = horizontalPagePadding(context);
    final double contentWidth = pageContentWidth(context);

    final List<Widget> bodySlivers = _showResults
        ? _resultSlivers(horizontal, contentWidth)
        : _showSuggestions
        ? _suggestSlivers(horizontal)
        : _homeSlivers(horizontal);

    return Scaffold(
      body: AmbientGlow(
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(child: _buildTopBar(context, horizontal)),
              ...bodySlivers,
              const SliverToBoxAdapter(child: SizedBox(height: 26)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, double horizontal) {
    final AppColors colors = context.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontal - 8, 6, horizontal, 4),
      child: Row(
        children: <Widget>[
          AppIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            tooltip: '返回',
            onPressed: () => Navigator.of(context).maybePop(),
            size: 38,
            iconSize: 20,
            plain: true,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(21),
                border: Border.all(color: colors.hairline, width: 0.8),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                textInputAction: TextInputAction.search,
                cursorColor: colors.brand,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.25,
                  color: colors.textPrimary,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: '搜短剧、剧名',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    height: 1.25,
                    color: colors.textTertiary,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  suffixIcon: _draft.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '清空',
                          onPressed: _clear,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 26,
                            height: 26,
                          ),
                          icon: Icon(
                            Icons.cancel_rounded,
                            size: 17,
                            color: colors.textTertiary,
                          ),
                        ),
                ),
                onSubmitted: _submit,
                onChanged: _onChanged,
              ),
            ),
          ),
          const SizedBox(width: 8),
          AppPillButton(
            label: '搜索',
            onPressed: () => _submit(_controller.text),
            height: 38,
            horizontalPadding: 15,
            fontSize: 13.5,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- 首页态。

  List<Widget> _homeSlivers(double horizontal) {
    final AsyncValue<SearchHome> async = ref.watch(searchHomeProvider);
    return async.when(
      loading: () => <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(horizontal, 14, horizontal, 0),
            child: const _HomeSkeleton(),
          ),
        ),
      ],
      error: (Object error, StackTrace stackTrace) => <Widget>[
        _errorSliver(
          icon: Icons.wifi_off_rounded,
          title: '热搜加载失败',
          message: '网络似乎开小差了，稍后再试试',
          onRetry: () => ref.invalidate(searchHomeProvider),
        ),
      ],
      data: (SearchHome home) => <Widget>[
        if (home.guesses.isEmpty && home.hotBoard.isEmpty)
          _errorSliver(
            icon: Icons.local_fire_department_rounded,
            title: '暂无热搜数据',
            message: '休息一下，稍后再来看看大家在追什么',
            onRetry: () => ref.invalidate(searchHomeProvider),
            retryLabel: '刷新',
          )
        else ...<Widget>[
          if (home.guesses.isNotEmpty) ...<Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 0),
                child: const SectionHeader(title: '猜你想搜'),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 50,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: horizontal),
                  itemCount: home.guesses.length,
                  separatorBuilder: (BuildContext _, int _) =>
                      const SizedBox(width: 8),
                  itemBuilder: (BuildContext context, int index) {
                    return Center(
                      child: SoftChip(
                        label: home.guesses[index].text,
                        selected: false,
                        onTap: () => _submit(home.guesses[index].text),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 0),
              child: const SectionHeader(title: '热搜榜'),
            ),
          ),
          if (home.hotBoard.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 18),
                child: EmptyState(
                  icon: Icons.local_fire_department_rounded,
                  title: '热搜榜暂时空空如也',
                  message: '稍后再来看看大家在追什么',
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(horizontal + 6, 4, horizontal, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                    final SearchCandidate candidate = home.hotBoard[index];
                    return _HotRow(
                      rank: index + 1,
                      candidate: candidate,
                      onTap: () => _openCandidate(candidate),
                    );
                  },
                  childCount: home.hotBoard.length,
                ),
              ),
            ),
        ],
      ],
    );
  }

  // -------------------------------------------------------------- 联想词态。

  List<Widget> _suggestSlivers(double horizontal) {
    if (_suggestQuery.isEmpty) {
      // debounce 等待窗口：先出骨架，不发请求。
      return <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(horizontal + 6, 8, horizontal, 0),
            child: const _SuggestSkeleton(),
          ),
        ),
      ];
    }
    final AsyncValue<List<String>> async = ref.watch(
      suggestProvider(_suggestQuery),
    );
    return async.when(
      loading: () => <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(horizontal + 6, 8, horizontal, 0),
            child: const _SuggestSkeleton(),
          ),
        ),
      ],
      error: (Object error, StackTrace stackTrace) => <Widget>[
        _errorSliver(
          icon: Icons.wifi_off_rounded,
          title: '联想词加载失败',
          message: '网络似乎开小差了，稍后再试试',
          onRetry: () => ref.invalidate(suggestProvider(_suggestQuery)),
        ),
      ],
      data: (List<String> words) {
        if (words.isEmpty) {
          return <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 18),
                child: EmptyState(
                  icon: Icons.search_off_rounded,
                  title: '暂无联想词',
                  message: '直接点「搜索」找「$_suggestQuery」，或换个说法试试',
                ),
              ),
            ),
          ];
        }
        return <Widget>[
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontal + 6, 4, horizontal, 0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  final String word = words[index];
                  return _SuggestRow(
                    word: word,
                    onTap: () => _submit(word),
                  );
                },
                childCount: words.length,
              ),
            ),
          ),
        ];
      },
    );
  }

  // ---------------------------------------------------------------- 结果态。

  List<Widget> _resultSlivers(double horizontal, double contentWidth) {
    final AsyncValue<SearchPage> async = ref.watch(
      searchResultProvider(_committed),
    );
    final int columns = dramaGridColumns(contentWidth);
    final double cardWidth = (contentWidth - (columns - 1) * 11) / columns;
    final double itemExtent = cardWidth * 4 / 3 + 62;
    return async.when(
      loading: () => <Widget>[
        SliverPadding(
          padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 0),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 18,
              crossAxisSpacing: 11,
              mainAxisExtent: itemExtent,
            ),
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) => const _ResultSkeleton(),
              childCount: columns * 2,
            ),
          ),
        ),
      ],
      error: (Object error, StackTrace stackTrace) => <Widget>[
        _errorSliver(
          icon: Icons.wifi_off_rounded,
          title: '搜索失败',
          message: '网络似乎开小差了，稍后再试试',
          onRetry: () => ref.invalidate(searchResultProvider(_committed)),
        ),
      ],
      data: (SearchPage page) {
        final bool chained = _moreFor == _committed;
        final List<Drama> results = <Drama>[
          ...page.items,
          if (chained) ..._more,
        ];
        final bool hasMore = chained ? _moreHasMore : page.hasMore;
        return <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 0),
            child: Text(
              '「$_committed」 · 找到 ${results.length} 部作品',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
                color: context.colors.textSecondary,
              ),
            ),
          ),
        ),
        if (results.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: '没有找到相关短剧',
                message: '换个关键词试试，或回到热搜榜看看大家在追什么',
                actionLabel: '回到热搜榜',
                onAction: _clear,
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontal, 10, horizontal, 0),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 18,
                crossAxisSpacing: 11,
                mainAxisExtent: itemExtent,
              ),
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  final Drama drama = results[index];
                  return DramaCard(
                    drama: drama,
                    onTap: () => openDramaDetail(context, drama),
                  );
                },
                childCount: results.length,
              ),
            ),
          ),
        if (hasMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(horizontal, 14, horizontal, 6),
              child: Center(
                child: AppPillButton(
                  label: _loadingMore ? '加载中…' : '加载更多',
                  onPressed: _loadingMore
                      ? null
                      : () => _loadMore(_committed, page),
                ),
              ),
            ),
          ),
        ];
      },
    );
  }

  Widget _errorSliver({
    required IconData icon,
    required String title,
    required String message,
    required VoidCallback onRetry,
    String retryLabel = '点按重试',
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 18),
        child: EmptyState(
          icon: icon,
          title: title,
          message: message,
          actionLabel: retryLabel,
          onAction: onRetry,
        ),
      ),
    );
  }
}

/// 热搜榜条目：名次 + 标题 + 右侧 score；1-3 名用品牌色系高亮。
class _HotRow extends StatelessWidget {
  const _HotRow({
    required this.rank,
    required this.candidate,
    required this.onTap,
  });

  final int rank;
  final SearchCandidate candidate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final bool top = rank <= 3;
    final Color rankColor = rank == 1
        ? colors.brand
        : top
        ? colors.rankGold
        : colors.textTertiary;
    return Semantics(
      button: true,
      label: '热搜第$rank名，${candidate.text}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 34,
                child: Text(
                  '$rank',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: top ? 22 : 17,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -0.5,
                    color: rankColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  candidate.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.3,
                    fontWeight: top ? FontWeight.w600 : FontWeight.w500,
                    color: top ? colors.textPrimary : colors.textSecondary,
                  ),
                ),
              ),
              if (candidate.score.isNotEmpty) ...<Widget>[
                const SizedBox(width: 8),
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 13,
                  color: colors.brand,
                ),
                const SizedBox(width: 3),
                Text(
                  candidate.score,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: colors.accentText,
                  ),
                ),
              ],
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: colors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 联想词条目：点击即提交搜索。
class _SuggestRow extends StatelessWidget {
  const _SuggestRow({required this.word, required this.onTap});

  final String word;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Semantics(
      button: true,
      label: '搜索$word',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: <Widget>[
              Icon(Icons.search_rounded, size: 16, color: colors.textTertiary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  word,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.north_west_rounded,
                size: 15,
                color: colors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 首页态骨架：chip 流 + 热搜行的占位。
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    final Color base = context.colors.surfaceMuted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _bone(base, width: 88, height: 20),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          // 与真实 chip 流一致横向可滚，窄屏不溢出。
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (int i = 0; i < 5; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 8),
                  _bone(base, width: 64 + (i % 3) * 12, height: 34, radius: 10),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 26),
        _bone(base, width: 72, height: 20),
        const SizedBox(height: 10),
        for (int i = 0; i < 5; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: 10),
          _bone(base, width: double.infinity, height: 28, radius: 10),
        ],
      ],
    );
  }
}

/// 联想词态骨架。
class _SuggestSkeleton extends StatelessWidget {
  const _SuggestSkeleton();

  @override
  Widget build(BuildContext context) {
    final Color base = context.colors.surfaceMuted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < 4; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: 18),
          Row(
            children: <Widget>[
              _bone(base, width: 16, height: 16, radius: 8),
              const SizedBox(width: 10),
              _bone(base, width: 120 + (i % 3) * 36, height: 16, radius: 8),
            ],
          ),
        ],
      ],
    );
  }
}

/// 结果网格骨架（与 DramaCard 同构的海报占位）。
class _ResultSkeleton extends StatelessWidget {
  const _ResultSkeleton();

  @override
  Widget build(BuildContext context) {
    final Color base = context.colors.surfaceMuted;
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
        _bone(base, width: 72, height: 12, radius: 4),
        const SizedBox(height: 5),
        _bone(base, width: 48, height: 9, radius: 4),
      ],
    );
  }
}

Widget _bone(Color color, {required double width, required double height, double radius = 6}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}
