import 'package:flutter/material.dart';

import '../models/drama.dart';
import 'gradient_artwork.dart';

enum PosterVariant { card, thumb, full }

/// 剧集封面：优先显示真实封面图（[Drama.coverUrl]），加载中/失败/
/// 无封面时回落到三色渐变生成式占位，因此任何情况下都不空屏。
class PosterArtwork extends StatelessWidget {
  const PosterArtwork({
    super.key,
    required this.drama,
    this.variant = PosterVariant.card,
  });

  final Drama drama;
  final PosterVariant variant;

  @override
  Widget build(BuildContext context) {
    final double scrim = switch (variant) {
      PosterVariant.card => 0.30,
      PosterVariant.thumb => 0.50,
      PosterVariant.full => 0.58,
    };
    final bool hasCover = drama.coverUrl.isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // 渐变兜底永远在底层：图片加载期间与失败时自然露出。
        GradientArtwork(
          colors: drama.coverColors,
          glyph: drama.title,
          scrim: scrim,
          wordmarkOpacity: variant == PosterVariant.full ? 0.06 : 0.10,
          wordmarkScale: variant == PosterVariant.full ? 0.50 : 0.64,
        ),
        if (hasCover)
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              // 按实际布局宽度解码：源图常见 750~1080 宽，而桌面卡片只有
              // 一两百逻辑像素，全尺寸解码白白占内存与 UI 线程时间。
              final double width = constraints.maxWidth;
              final int? cacheWidth = width.isFinite && width > 0
                  ? (width * MediaQuery.devicePixelRatioOf(context)).round()
                  : null;
              return Image.network(
                drama.coverUrl,
                cacheWidth: cacheWidth,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                // CDN 签名 URL 可能随时失效；失败时静默回落渐变占位。
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
                // 加载完成前也露出渐变底，避免闪白。
                frameBuilder: (
                  BuildContext context,
                  Widget child,
                  int? frame,
                  bool wasLoaded,
                ) {
                  if (wasLoaded || frame != null) {
                    return child;
                  }
                  return const SizedBox.shrink();
                },
              );
            },
          ),
        // 真实封面压一层暗色遮罩，保证角标/标题可读（与渐变占位的 scrim 一致）。
        if (hasCover)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.black.withValues(alpha: scrim * 0.6),
                  Colors.transparent,
                  Colors.black.withValues(alpha: scrim),
                ],
                stops: const <double>[0, 0.45, 1],
              ),
            ),
          ),
        if (variant == PosterVariant.thumb) const Center(child: _PlayGlyph()),
      ],
    );
  }
}

class _PlayGlyph extends StatelessWidget {
  const _PlayGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.38),
          width: 0.8,
        ),
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        size: 18,
        color: Colors.white,
      ),
    );
  }
}
