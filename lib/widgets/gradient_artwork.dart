import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Generative artwork used for posters and category tiles.
///
/// A cinematic gradient, a light shaft, soft orbs, a faint horizon rule and a
/// serif wordmark. No network images, no image cache: the whole library is
/// drawn with Dart, but it still reads as a designed poster rather than a flat
/// color block.
class GradientArtwork extends StatelessWidget {
  const GradientArtwork({
    super.key,
    required this.colors,
    required this.glyph,
    this.scrim = 0.46,
    this.wordmarkOpacity = 0.10,
    this.wordmarkScale = 0.72,
  });

  final List<Color> colors;
  final String glyph;

  /// Strength of the bottom black gradient, so overlaid text stays legible.
  final double scrim;
  final double wordmarkOpacity;

  /// Relative to the shortest side of the artwork.
  final double wordmarkScale;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 120;
        final double height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 160;
        final double shortest = math.min(width, height);
        final String mark = glyph.isEmpty ? '剧' : glyph.substring(0, 1);

        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              Positioned(
                top: -height * 0.30,
                left: -width * 0.28,
                child: Transform.rotate(
                  angle: 0.46,
                  child: Container(
                    width: width * 1.4,
                    height: height * 0.62,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          Colors.white.withValues(alpha: 0.16),
                          Colors.white.withValues(alpha: 0.02),
                          Colors.transparent,
                        ],
                        stops: const <double>[0, 0.45, 1],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -shortest * 0.42,
                right: -shortest * 0.30,
                child: _Orb(
                  diameter: shortest * 1.04,
                  color: Colors.white.withValues(alpha: 0.20),
                ),
              ),
              Positioned(
                bottom: -shortest * 0.55,
                left: -shortest * 0.42,
                child: _Orb(
                  diameter: shortest * 1.02,
                  color: Colors.black.withValues(alpha: 0.18),
                ),
              ),
              Positioned(
                top: height * 0.63,
                left: width * 0.06,
                right: width * 0.06,
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(alpha: 0.10),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -width * 0.02,
                bottom: -height * 0.10,
                child: Text(
                  mark,
                  style: TextStyle(
                    fontSize: shortest * wordmarkScale,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: wordmarkOpacity),
                    fontFamilyFallback: const <String>[
                      'Songti SC',
                      'STSong',
                      'Noto Serif CJK SC',
                      'serif',
                    ],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.transparent,
                      Colors.black.withValues(alpha: scrim),
                    ],
                    stops: const <double>[0.40, 1],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.diameter, required this.color});

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
