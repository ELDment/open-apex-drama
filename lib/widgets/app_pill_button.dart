import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum AppButtonTone { primary, tonal, white, gold, dark }

/// The single CTA primitive used across the app. Defaults to a pill; large
/// primary actions can pass a smaller [radius] to match the new prototype's
/// rounded rectangle buttons.
class AppPillButton extends StatelessWidget {
  const AppPillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.tone = AppButtonTone.primary,
    this.height = 40,
    this.horizontalPadding = 18,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w600,
    this.expand = false,
    this.radius,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonTone tone;
  final double height;
  final double horizontalPadding;
  final double fontSize;
  final FontWeight fontWeight;
  final bool expand;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final double effectiveRadius = radius ?? height / 2;

    late final Color foreground;
    Color? background;
    LinearGradient? gradient;
    Border? border;
    List<BoxShadow>? shadows;

    switch (tone) {
      case AppButtonTone.primary:
        foreground = colors.onBrand;
        gradient = colors.brandGradient;
        shadows = <BoxShadow>[
          BoxShadow(
            color: colors.brand.withValues(alpha: context.isDark ? 0.30 : 0.22),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ];
      case AppButtonTone.tonal:
        foreground = colors.accentText;
        background = colors.accentSoft;
        border = Border.all(color: colors.accentSoftBorder, width: 0.8);
      case AppButtonTone.white:
        foreground = const Color(0xFF171210);
        background = Colors.white;
      case AppButtonTone.gold:
        foreground = const Color(0xFF4A2D00);
        gradient = AppTokens.gradientGold;
      case AppButtonTone.dark:
        foreground = Colors.white;
        background = Colors.white.withValues(alpha: 0.14);
        border = Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 0.8,
        );
    }

    Widget button = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(effectiveRadius),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: gradient,
          color: background,
          borderRadius: BorderRadius.circular(effectiveRadius),
          border: border,
        ),
        child: InkWell(
          onTap: onPressed,
          splashColor: foreground.withValues(alpha: 0.12),
          highlightColor: foreground.withValues(alpha: 0.06),
          child: Container(
            height: height,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: fontSize + 4, color: foreground),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: fontWeight,
                      color: foreground,
                      height: 1.1,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (shadows != null) {
      button = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(effectiveRadius),
          boxShadow: shadows,
        ),
        child: button,
      );
    }

    if (expand) {
      button = SizedBox(width: double.infinity, child: button);
    }

    return Opacity(opacity: onPressed == null ? 0.5 : 1, child: button);
  }
}
