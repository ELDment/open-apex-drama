import 'package:flutter/material.dart';

import '../models/drama.dart';
import '../theme/app_colors.dart';
import 'poster_artwork.dart';

class DramaCard extends StatelessWidget {
  const DramaCard({
    super.key,
    required this.drama,
    required this.onTap,
    this.showBadge = true,
  });

  final Drama drama;
  final VoidCallback onTap;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    // 真实数据可能没有评分（rating<=0）与在追数（viewers 为空），此时隐藏。
    final String metaLine = drama.rating > 0
        ? '${drama.ratingLabel}分 · ${drama.category}'
        : drama.category;
    return Semantics(
      button: true,
      label: '${drama.title}，${drama.metaLabel}'
          '${drama.rating > 0 ? '，评分${drama.ratingLabel}' : ''}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.hairline.withValues(alpha: 0.7),
                    width: 0.8,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      PosterArtwork(drama: drama),
                      if (showBadge && drama.badge != null)
                        Positioned(
                          top: 7,
                          left: 7,
                          child: _Tag(
                            label: drama.badge!,
                            background: colors.brandStrong,
                            foreground: colors.onBrand,
                          ),
                        ),
                      // 上游 episodeCount 缺失（0）时隐藏角标，避免「全0集」。
                      if (showBadge && drama.episodes > 0)
                        Positioned(
                          left: 7,
                          bottom: 7,
                          child: _Tag(
                            label: '全${drama.episodes}集',
                            background: Colors.black.withValues(alpha: 0.52),
                            foreground: Colors.white.withValues(alpha: 0.92),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              drama.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.32,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              metaLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
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

class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          height: 1.1,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
          color: foreground,
        ),
      ),
    );
  }
}
