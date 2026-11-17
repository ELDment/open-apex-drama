import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Ambient color wash behind tab pages.
///
/// Light mode gets the warm peach glow of the first prototype; dark mode gets
/// a much quieter rose vignette on near-black, matching the new prototype.
class AmbientGlow extends StatelessWidget {
  const AmbientGlow({super.key, required this.child, this.bottomGlow = false});

  final Widget child;
  final bool bottomGlow;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final double strength = context.isDark ? 0.62 : 1;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ColoredBox(color: colors.page),
        Positioned(
          top: -190,
          right: -120,
          child: _Glow(
            size: 360,
            color: colors.glowPrimary.withValues(alpha: strength),
          ),
        ),
        if (bottomGlow)
          Positioned(
            bottom: -210,
            left: -150,
            child: _Glow(
              size: 440,
              color: colors.glowSecondary.withValues(
                alpha: context.isDark ? 0.45 : 1,
              ),
            ),
          ),
        child,
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
