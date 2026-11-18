import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_data.dart';
import '../models/drama.dart';
import '../providers/data_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/app_pill_button.dart';
import '../widgets/poster_artwork.dart';
import 'drama_detail_screen.dart';
import 'player_screen.dart';

/// 「看剧」Tab：全屏竖向推荐流。
///
/// 当前版本先用封面 + 信息浮层做完整交互；视频预览与相邻预加载留在
/// 下一阶段接入（匿名解析额度有限，不能在每张卡上自动 resolve）。
class WatchFeedScreen extends ConsumerStatefulWidget {
  const WatchFeedScreen({super.key});

  @override
  ConsumerState<WatchFeedScreen> createState() => _WatchFeedScreenState();
}

class _WatchFeedScreenState extends ConsumerState<WatchFeedScreen> {
  static const HomeFeedKey _feedKey = HomeFeedKey('推荐');

  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _shuffle() {
    ref.invalidate(homeFeedProvider(_feedKey));
    if (_controller.hasClients) {
      _controller.jumpToPage(0);
    }
    setState(() => _index = 0);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<HomeFeed> feedAsync = ref.watch(
      homeFeedProvider(_feedKey),
    );
    final List<Drama> fetched = feedAsync.value?.items ?? const <Drama>[];
    final List<Drama> feed = fetched.isEmpty ? mockDramas : fetched;
    final int total = feed.length;
    if (total == 0) {
      return const ColoredBox(
        color: AppTokens.playerBackground,
        child: Center(
          child: Text('暂无推荐', style: TextStyle(color: Colors.white70)),
        ),
      );
    }
    final int index = _index.clamp(0, total - 1);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppTokens.playerBackground,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: ColoredBox(
        color: AppTokens.playerBackground,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            PageView.builder(
              controller: _controller,
              scrollDirection: Axis.vertical,
              itemCount: total,
              onPageChanged: (int page) => setState(() => _index = page),
              itemBuilder: (BuildContext context, int page) => _WatchFeedPage(
                drama: feed[page],
                isLast: page == total - 1,
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 8, 0),
                child: Row(
                  children: <Widget>[
                    const Text(
                      '推荐',
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${index + 1} / $total',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.2,
                        color: Colors.white.withValues(alpha: 0.68),
                      ),
                    ),
                    IconButton(
                      tooltip: '换一批',
                      onPressed: _shuffle,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        size: 22,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WatchFeedPage extends StatelessWidget {
  const _WatchFeedPage({required this.drama, required this.isLast});

  final Drama drama;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => openDramaDetail(context, drama),
            child: PosterArtwork(drama: drama, variant: PosterVariant.full),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.34),
                    Colors.black.withValues(alpha: 0.02),
                    Colors.black.withValues(alpha: 0.88),
                  ],
                  stops: const <double>[0, 0.42, 1],
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  drama.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 24,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  drama.episodes > 0
                      ? '全${drama.episodes}集 · ${drama.category}'
                      : drama.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  drama.tags.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.3,
                    color: Colors.white.withValues(alpha: 0.52),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  drama.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.6,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    AppPillButton(
                      label: '看全集',
                      icon: Icons.play_arrow_rounded,
                      height: 46,
                      radius: 14,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      horizontalPadding: 22,
                      onPressed: () => openPlayer(context, drama),
                    ),
                    const SizedBox(width: 14),
                    if (!isLast)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.keyboard_arrow_up_rounded,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.50),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '上滑看下一部',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.2,
                              color: Colors.white.withValues(alpha: 0.50),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
