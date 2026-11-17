import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/watch_store.dart';
import '../models/drama.dart';
import '../providers/sync_providers.dart';
import '../providers/watch_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/ambient_glow.dart';
import '../widgets/app_icon_button.dart';
import '../widgets/app_pill_button.dart';
import '../widgets/drama_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/page_layout.dart';
import '../widgets/poster_artwork.dart';
import '../widgets/section_header.dart';
import '../widgets/underline_tabs.dart';
import 'drama_detail_screen.dart';
import 'player_screen.dart';
import 'webdav_sync_screen.dart';

enum FollowingTab { continueWatching, favorites, history }

class FollowingScreen extends StatelessWidget {
  const FollowingScreen({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
  });

  final FollowingTab selectedTab;
  final ValueChanged<FollowingTab> onTabChanged;

  static const List<String> _labels = <String>['继续观看', '收藏', '历史'];

  int get _tabIndex => FollowingTab.values.indexOf(selectedTab);

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final double horizontal = horizontalPagePadding(context);

    return AmbientGlow(
      bottomGlow: true,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '追剧',
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
                          '上次看到哪，这次接着看',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _SyncHeaderActions(),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 0),
              child: UnderlineTabs(
                labels: _labels,
                selectedIndex: _tabIndex,
                onChanged: (int index) =>
                    onTabChanged(FollowingTab.values[index]),
              ),
            ),
            Expanded(
              child: switch (selectedTab) {
                FollowingTab.continueWatching => _ContinueTab(
                  onOpenTab: onTabChanged,
                ),
                FollowingTab.favorites => const _FavoritesTab(),
                FollowingTab.history => const _HistoryTab(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 追剧页右上角：云图标 = 立即手动同步一次；齿轮 = WebDAV 同步设置页。
class _SyncHeaderActions extends ConsumerWidget {
  const _SyncHeaderActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final WebDavSyncState? state = ref.watch(webDavSyncProvider).value;
    final bool syncing = state?.syncing ?? false;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: 38,
          height: 38,
          child: syncing
              ? Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.brand,
                    ),
                  ),
                )
              : AppIconButton(
                  icon: Icons.cloud_sync_outlined,
                  tooltip: '立即同步',
                  onPressed: () => _syncNow(context, ref),
                  size: 38,
                  iconSize: 22,
                  plain: true,
                ),
        ),
        AppIconButton(
          icon: Icons.settings_outlined,
          tooltip: '云同步设置',
          onPressed: () => openWebDavSync(context),
          size: 38,
          iconSize: 21,
          plain: true,
        ),
      ],
    );
  }

  /// 手动同步：未配置时直接进设置页；已配置则同步并 toast 结果。
  Future<void> _syncNow(BuildContext context, WidgetRef ref) async {
    final WebDavSyncState? state = ref.read(webDavSyncProvider).value;
    if (state == null) {
      return;
    }
    if (!state.isConfigured) {
      await openWebDavSync(context);
      return;
    }
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String message = await ref
        .read(webDavSyncProvider.notifier)
        .syncNow();
    if (!context.mounted) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontSize: 13)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }
}

/// 继续观看：store 里 progress>0 且未播完的条目（时间倒序），下面挂收藏横滑。
class _ContinueTab extends ConsumerWidget {
  const _ContinueTab({required this.onOpenTab});

  final ValueChanged<FollowingTab> onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double horizontal = horizontalPagePadding(context);
    final List<WatchSnapshot> continueList = ref.watch(
      continueWatchingProvider,
    );
    final List<WatchSnapshot> favorites =
        ref.watch(favoritesProvider).value ?? const <WatchSnapshot>[];

    if (continueList.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.play_circle_outline_rounded,
          title: '还没有正在追的剧',
          message: '点开一集短剧，播放进度会自动保存到这里',
        ),
      );
    }

    // 桌面宽窗多列：继续观看卡由单列大卡改为 2-3 列并排，提高空间利用率。
    final double width = MediaQuery.sizeOf(context).width;
    final int columns = width >= 1160 ? 3 : (width >= 720 ? 2 : 1);

    return ListView(
      padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 28),
      children: <Widget>[
        for (int i = 0; i < continueList.length; i += columns)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (int j = i; j < i + columns; j++) ...<Widget>[
                  Expanded(
                    child: j < continueList.length
                        ? _ContinueCard(snapshot: continueList[j])
                        : const SizedBox.shrink(),
                  ),
                  if (j < i + columns - 1) const SizedBox(width: 16),
                ],
              ],
            ),
          ),
        if (favorites.isNotEmpty) ...<Widget>[
          SectionHeader(
            title: '我的收藏',
            trailing: '查看更多',
            onTrailingTap: () => onOpenTab(FollowingTab.favorites),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: favorites.length,
              separatorBuilder: (BuildContext _, int _) =>
                  const SizedBox(width: 11),
              itemBuilder: (BuildContext context, int index) {
                final Drama drama = favorites[index].toDrama();
                return _MiniPoster(
                  drama: drama,
                  onTap: () => openDramaDetail(context, drama),
                );
              },
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: Text(
              '收藏的短剧会在这里持续更新',
              style: TextStyle(
                fontSize: 10.5,
                height: 1.3,
                color: context.colors.textTertiary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.snapshot});

  final WatchSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final Drama drama = snapshot.toDrama();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () =>
                openPlayer(context, drama, episodeNumber: snapshot.lastEpisodeNumber),
            child: AspectRatio(
              aspectRatio: 1.48,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  PosterArtwork(drama: drama, variant: PosterVariant.full),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.black.withValues(alpha: 0.10),
                          Colors.black.withValues(alpha: 0.08),
                          Colors.black.withValues(alpha: 0.78),
                        ],
                        stops: const <double>[0, 0.42, 1],
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.72),
                          width: 1.2,
                        ),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                snapshot.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 19,
                                  height: 1.25,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '已观看至 ${snapshot.lastEpisodeNumber} 集 / 共 ${snapshot.episodes} 集',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  height: 1.2,
                                  color: Colors.white.withValues(alpha: 0.72),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        AppPillButton(
                          label: '继续播放',
                          icon: Icons.play_arrow_rounded,
                          onPressed: () => openPlayer(
                            context,
                            drama,
                            episodeNumber: snapshot.lastEpisodeNumber,
                          ),
                          height: 34,
                          radius: 17,
                          horizontalPadding: 13,
                          fontSize: 12,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // 进度条 = 已播秒数 / 总秒数。
        Row(
          children: <Widget>[
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: snapshot.progressFraction,
                  minHeight: 3,
                  backgroundColor: colors.surfaceMuted,
                  color: colors.brand,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '已看 ${snapshot.percentLabel}',
              style: TextStyle(
                fontSize: 10,
                height: 1.2,
                color: colors.textTertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniPoster extends StatelessWidget {
  const _MiniPoster({required this.drama, required this.onTap});

  final Drama drama;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
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
            const SizedBox(height: 6),
            Text(
              drama.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 收藏网格：收藏快照重建的最小 Drama（评分/在追自动隐藏）。
class _FavoritesTab extends ConsumerWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double horizontal = horizontalPagePadding(context);
    final double contentWidth = pageContentWidth(context);
    final int columns = dramaGridColumns(contentWidth);
    final double cardWidth = (contentWidth - (columns - 1) * 11) / columns;
    final List<WatchSnapshot> favorites =
        ref.watch(favoritesProvider).value ?? const <WatchSnapshot>[];

    if (favorites.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.star_outline_rounded,
          title: '还没有收藏的短剧',
          message: '在详情页点一下收藏，好剧就不会丢',
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 28),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 18,
        crossAxisSpacing: 11,
        mainAxisExtent: cardWidth * 4 / 3 + 62,
      ),
      itemCount: favorites.length,
      itemBuilder: (BuildContext context, int index) {
        final Drama drama = favorites[index].toDrama();
        return DramaCard(
          drama: drama,
          onTap: () => openDramaDetail(context, drama),
        );
      },
    );
  }
}

/// 历史列表：时间倒序，支持单条删除与一键清空。
class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.colors;
    final double horizontal = horizontalPagePadding(context);
    final List<WatchSnapshot> history =
        ref.watch(historyProvider).value ?? const <WatchSnapshot>[];

    if (history.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.history_rounded,
          title: '还没有观看记录',
          message: '随便点开一集，记录会自动保存',
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(horizontal, 14, horizontal, 28),
      itemCount: history.length + 1,
      separatorBuilder: (BuildContext _, int _) => const SizedBox(height: 14),
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return Row(
            children: <Widget>[
              Text(
                '共 ${history.length} 条观看记录',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  color: colors.textTertiary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => ref
                    .read(historyProvider.notifier)
                    .clearHistory(),
                style: TextButton.styleFrom(
                  foregroundColor: colors.textTertiary,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(36, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '清空',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          );
        }
        final WatchSnapshot snapshot = history[index - 1];
        return _HistoryRow(
          snapshot: snapshot,
          onTap: () => openPlayer(
            context,
            snapshot.toDrama(),
            episodeNumber: snapshot.lastEpisodeNumber,
          ),
          onDelete: () => ref
              .read(historyProvider.notifier)
              .removeHistory(snapshot.seriesId),
        );
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.snapshot,
    required this.onTap,
    required this.onDelete,
  });

  final WatchSnapshot snapshot;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final Drama drama = snapshot.toDrama();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 64,
              height: 86,
              child: PosterArtwork(drama: drama, variant: PosterVariant.thumb),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  snapshot.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  snapshot.episodeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: snapshot.progressFraction,
                          minHeight: 3,
                          backgroundColor: colors.surfaceMuted,
                          color: colors.brand,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      snapshot.percentLabel,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.2,
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // 单条删除。
          IconButton(
            tooltip: '删除记录',
            onPressed: onDelete,
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: colors.textTertiary,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 32),
          ),
          const SizedBox(width: 2),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.surfaceMuted,
            ),
            child: Icon(
              Icons.play_arrow_rounded,
              size: 19,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
