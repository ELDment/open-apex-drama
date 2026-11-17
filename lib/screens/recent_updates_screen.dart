import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/drama.dart';
import '../providers/data_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/ambient_glow.dart';
import '../widgets/drama_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/page_header.dart';
import '../widgets/page_layout.dart';
import '../widgets/soft_chip.dart';
import 'drama_detail_screen.dart';

/// 更新日历展示的天数：今天前后各一周（与 SDK 的 dates 范围一致）。
const int _daySpan = 7;

void openRecentUpdates(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext _) => const RecentUpdatesScreen(),
    ),
  );
}

/// 最近更新页：按日期查看当天上线的短剧。
class RecentUpdatesScreen extends ConsumerStatefulWidget {
  const RecentUpdatesScreen({super.key});

  @override
  ConsumerState<RecentUpdatesScreen> createState() =>
      _RecentUpdatesScreenState();
}

class _RecentUpdatesScreenState extends ConsumerState<RecentUpdatesScreen> {
  late final DateTime _today;
  late DateTime _selected;

  /// 日期条初始把「今天」滚到中间，避免打开时选中项在屏幕外。
  final GlobalKey _todayChipKey = GlobalKey();
  final ScrollController _daysController = ScrollController();

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _selected = _today;
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealToday());
  }

  @override
  void dispose() {
    _daysController.dispose();
    super.dispose();
  }

  void _revealToday() {
    final BuildContext? chipContext = _todayChipKey.currentContext;
    if (chipContext == null) {
      return;
    }
    Scrollable.ensureVisible(chipContext, alignment: 0.5);
  }

  List<DateTime> get _days => <DateTime>[
        for (int i = -_daySpan; i <= _daySpan; i++)
          _today.add(Duration(days: i)),
      ];

  /// SDK 约定的日期格式：YYYYMMDD。
  static String dateKey(DateTime date) {
    return '${date.year}${_two(date.month)}${_two(date.day)}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  String _dayLabel(DateTime date) {
    final int diff = date.difference(_today).inDays;
    return switch (diff) {
      0 => '今天',
      -1 => '昨天',
      1 => '明天',
      _ => '${date.month}/${date.day}',
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final double horizontal = horizontalPagePadding(context);

    return Scaffold(
      backgroundColor: colors.page,
      body: AmbientGlow(
        child: Column(
          children: <Widget>[
            const PageHeader(title: '最近更新'),
            SizedBox(
              height: 46,
              // 只有 15 个日期，全部构建后用 ensureVisible 居中「今天」。
              child: SingleChildScrollView(
                controller: _daysController,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: horizontal),
                child: Row(
                  children: <Widget>[
                    for (int index = 0; index < _days.length; index++)
                      ...<Widget>[
                        if (index > 0) const SizedBox(width: 8),
                        Center(
                          key: dateKey(_days[index]) == dateKey(_today)
                              ? _todayChipKey
                              : null,
                          child: SoftChip(
                            dense: true,
                            label: _dayLabel(_days[index]),
                            selected: dateKey(_days[index]) == dateKey(_selected),
                            onTap: () =>
                                setState(() => _selected = _days[index]),
                          ),
                        ),
                      ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(child: _buildBody(horizontal)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(double horizontal) {
    final String key = dateKey(_selected);
    final AsyncValue<List<Drama>> async = ref.watch(newReleasesProvider(key));
    final double contentWidth = pageContentWidth(context);
    final int columns = dramaGridColumns(contentWidth);

    return async.when(
      loading: () => _skeletonGrid(horizontal, columns, contentWidth),
      error: (Object error, StackTrace stackTrace) => Center(
        child: SingleChildScrollView(
          child: EmptyState(
            icon: Icons.wifi_off_rounded,
            title: '更新列表加载失败',
            message: '网络似乎开小差了，稍后再试试',
            actionLabel: '点按重试',
            onAction: () => ref.invalidate(newReleasesProvider(key)),
          ),
        ),
      ),
      data: (List<Drama> items) {
        if (items.isEmpty) {
          return Center(
            child: SingleChildScrollView(
              child: EmptyState(
                icon: Icons.event_busy_rounded,
                title: '这一天暂无更新',
                message: '换个日期看看，或者过几天再来',
                actionLabel: '回到今天',
                onAction: () => setState(() => _selected = _today),
              ),
            ),
          );
        }
        final double cardWidth = (contentWidth - (columns - 1) * 11) / columns;
        final double itemExtent = cardWidth * 4 / 3 + 62;
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 18,
            crossAxisSpacing: 11,
            mainAxisExtent: itemExtent,
          ),
          itemCount: items.length,
          itemBuilder: (BuildContext context, int index) {
            final Drama drama = items[index];
            return DramaCard(
              drama: drama,
              onTap: () => openDramaDetail(context, drama),
            );
          },
        );
      },
    );
  }

  Widget _skeletonGrid(double horizontal, int columns, double contentWidth) {
    final double cardWidth = (contentWidth - (columns - 1) * 11) / columns;
    final double itemExtent = cardWidth * 4 / 3 + 62;
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 18,
        crossAxisSpacing: 11,
        mainAxisExtent: itemExtent,
      ),
      itemCount: columns * 2,
      itemBuilder: (BuildContext _, int _) {
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
            _bone(base, width: 72, height: 12),
            const SizedBox(height: 5),
            _bone(base, width: 48, height: 9),
          ],
        );
      },
    );
  }

  static Widget _bone(Color color, {required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
