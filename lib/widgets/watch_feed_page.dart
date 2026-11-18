import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/drama.dart';
import '../theme/app_colors.dart';
import 'app_pill_button.dart';
import 'poster_artwork.dart';

/// 看剧流单页：视频（未就绪时封面兜底）+ 底部剧集信息 + 看全集。
class WatchFeedPage extends StatelessWidget {
  const WatchFeedPage({
    super.key,
    required this.drama,
    required this.episodeCount,
    required this.player,
    required this.controller,
    required this.ready,
    required this.isLast,
    required this.onTogglePlay,
    required this.onOpenFull,
  });

  final Drama drama;

  /// 真实 feed 的 Drama.episodes 常为 0，用解析到的分集数展示。
  final int episodeCount;
  final Player? player;
  final VideoController? controller;

  /// 首帧完成前继续盖封面，避免播放器黑屏。
  final bool ready;
  final bool isLast;
  final VoidCallback onTogglePlay;
  final VoidCallback onOpenFull;

  /// 真实 feed 的 tags 常只有频道名（如「推荐」），过滤掉避免重复。
  String get _tags => drama.tags
      .where(
        (String tag) =>
            tag.isNotEmpty && tag != '推荐' && tag != drama.category,
      )
      .join(' · ');

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned.fill(
          child: controller == null
              ? PosterArtwork(drama: drama, variant: PosterVariant.full)
              : const ColoredBox(color: AppTokens.playerBackground),
        ),
        if (controller != null)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Video(
                  controller: controller!,
                  controls: NoVideoControls,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        // 首帧未就绪时封面压在最上层，视频黑屏被遮住。
        if (controller != null && !ready)
          Positioned.fill(
            child: IgnorePointer(
              child: PosterArtwork(
                drama: drama,
                variant: PosterVariant.full,
              ),
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
                    Colors.black.withValues(alpha: 0.90),
                  ],
                  stops: const <double>[0, 0.42, 1],
                ),
              ),
            ),
          ),
        ),
        // 点画面播放/暂停；底部 CTA 在更上层，会优先接收点击。
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTogglePlay,
          ),
        ),
        if (player != null && ready)
          StreamBuilder<bool>(
            stream: player!.stream.playing,
            initialData: player!.state.playing,
            builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
              if (snapshot.data ?? true) {
                return const SizedBox.shrink();
              }
              return const IgnorePointer(
                child: Center(
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: 64,
                    color: Color(0x9EFFFFFF),
                    shadows: <Shadow>[
                      Shadow(color: Color(0x59000000), blurRadius: 10),
                    ],
                  ),
                ),
              );
            },
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
                  episodeCount > 0
                      ? '全$episodeCount集 · ${drama.category}'
                      : drama.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                if (_tags.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 5),
                  Text(
                    _tags,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.3,
                      color: Colors.white.withValues(alpha: 0.52),
                    ),
                  ),
                ],
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
                      onPressed: onOpenFull,
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
