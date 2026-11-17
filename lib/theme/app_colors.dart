import 'package:flutter/material.dart';

/// Semantic color tokens for the app.
///
/// Light mode keeps the warm "red paper" palette of the first prototype;
/// dark mode follows the newer near-black + rose design language. Every
/// surface, text and brand color is provided here so no screen needs to
/// hard code a theme-specific color.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.page,
    required this.surface,
    required this.surfaceMuted,
    required this.navBar,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.hairline,
    required this.brand,
    required this.brandBright,
    required this.brandStrong,
    required this.brandDeep,
    required this.onBrand,
    required this.accentText,
    required this.accentSoft,
    required this.accentSoftBorder,
    required this.goldText,
    required this.goldSoft,
    required this.rankGold,
    required this.shadow,
    required this.glowPrimary,
    required this.glowSecondary,
  });

  final Color page;
  final Color surface;
  final Color surfaceMuted;
  final Color navBar;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color hairline;

  /// Primary action / selection color. Warm orange in light mode, rose in dark.
  final Color brand;
  final Color brandBright;

  /// Filled brand surface that always carries white text (chips, badges,
  /// CTAs). Kept dark enough for a 4.5:1 contrast ratio.
  final Color brandStrong;

  /// Darker end of the brand gradient.
  final Color brandDeep;
  final Color onBrand;

  /// Brand tinted text on soft surfaces. Always darker/lighter than [brand]
  /// so small labels keep enough contrast.
  final Color accentText;
  final Color accentSoft;
  final Color accentSoftBorder;

  final Color goldText;
  final Color goldSoft;

  /// Color for the second / third place numbers on the ranking screen.
  final Color rankGold;

  final Color shadow;
  final Color glowPrimary;
  final Color glowSecondary;

  /// Diagonal CTA gradient: bright corner to the solid brand color.
  LinearGradient get brandGradient => LinearGradient(
    colors: <Color>[brandStrong, brandDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const AppColors light = AppColors(
    page: Color(0xFFFFF8F3),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF7EFE8),
    navBar: Color(0xFFFFFCFA),
    textPrimary: Color(0xFF1D1917),
    textSecondary: Color(0xFF6F635C),
    textTertiary: Color(0xFF7E7066),
    hairline: Color(0xFFF0E5DD),
    brand: Color(0xFFF04A15),
    brandBright: Color(0xFFFF7A3D),
    brandStrong: Color(0xFFD0410E),
    brandDeep: Color(0xFFC63C0F),
    onBrand: Color(0xFFFFFFFF),
    accentText: Color(0xFFC63C0F),
    accentSoft: Color(0xFFFFEDE2),
    accentSoftBorder: Color(0xFFFFD8C4),
    goldText: Color(0xFF8A5A12),
    goldSoft: Color(0xFFFFF3DD),
    rankGold: Color(0xFFC98A35),
    shadow: Color(0x14000000),
    glowPrimary: Color(0x2EFF6A3D),
    glowSecondary: Color(0x24FFB067),
  );

  static const AppColors dark = AppColors(
    page: Color(0xFF0B0B0E),
    surface: Color(0xFF16161B),
    surfaceMuted: Color(0xFF222228),
    navBar: Color(0xFF0E0E12),
    textPrimary: Color(0xFFF5F3F5),
    textSecondary: Color(0xFFA7A3AD),
    textTertiary: Color(0xFF85818C),
    hairline: Color(0xFF26262D),
    brand: Color(0xFFFF3B5C),
    brandBright: Color(0xFFFF6B85),
    brandStrong: Color(0xFFD91B41),
    brandDeep: Color(0xFFE01F45),
    onBrand: Color(0xFFFFFFFF),
    accentText: Color(0xFFFF8FA0),
    accentSoft: Color(0xFF2A1219),
    accentSoftBorder: Color(0xFF4A1E2B),
    goldText: Color(0xFFF0C078),
    goldSoft: Color(0xFF2A2114),
    rankGold: Color(0xFFF0B45C),
    shadow: Color(0x33000000),
    glowPrimary: Color(0x33FF3B5C),
    glowSecondary: Color(0x1FFF6B85),
  );

  @override
  AppColors copyWith({
    Color? page,
    Color? surface,
    Color? surfaceMuted,
    Color? navBar,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? hairline,
    Color? brand,
    Color? brandBright,
    Color? brandStrong,
    Color? brandDeep,
    Color? onBrand,
    Color? accentText,
    Color? accentSoft,
    Color? accentSoftBorder,
    Color? goldText,
    Color? goldSoft,
    Color? rankGold,
    Color? shadow,
    Color? glowPrimary,
    Color? glowSecondary,
  }) {
    return AppColors(
      page: page ?? this.page,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      navBar: navBar ?? this.navBar,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      hairline: hairline ?? this.hairline,
      brand: brand ?? this.brand,
      brandBright: brandBright ?? this.brandBright,
      brandStrong: brandStrong ?? this.brandStrong,
      brandDeep: brandDeep ?? this.brandDeep,
      onBrand: onBrand ?? this.onBrand,
      accentText: accentText ?? this.accentText,
      accentSoft: accentSoft ?? this.accentSoft,
      accentSoftBorder: accentSoftBorder ?? this.accentSoftBorder,
      goldText: goldText ?? this.goldText,
      goldSoft: goldSoft ?? this.goldSoft,
      rankGold: rankGold ?? this.rankGold,
      shadow: shadow ?? this.shadow,
      glowPrimary: glowPrimary ?? this.glowPrimary,
      glowSecondary: glowSecondary ?? this.glowSecondary,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) {
      return this;
    }
    return AppColors(
      page: Color.lerp(page, other.page, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      navBar: Color.lerp(navBar, other.navBar, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandBright: Color.lerp(brandBright, other.brandBright, t)!,
      brandStrong: Color.lerp(brandStrong, other.brandStrong, t)!,
      brandDeep: Color.lerp(brandDeep, other.brandDeep, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      accentSoftBorder: Color.lerp(
        accentSoftBorder,
        other.accentSoftBorder,
        t,
      )!,
      goldText: Color.lerp(goldText, other.goldText, t)!,
      goldSoft: Color.lerp(goldSoft, other.goldSoft, t)!,
      rankGold: Color.lerp(rankGold, other.rankGold, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      glowPrimary: Color.lerp(glowPrimary, other.glowPrimary, t)!,
      glowSecondary: Color.lerp(glowSecondary, other.glowSecondary, t)!,
    );
  }
}

/// Fixed brand tokens shared by both themes: membership gold, the always-dark
/// immersive surfaces used by the detail and player screens, and layout units.
abstract final class AppTokens {
  static const Color gold = Color(0xFFE9AE5B);
  static const Color goldDeep = Color(0xFFC98A35);
  static const Color goldLight = Color(0xFFF8D79C);

  /// Champagne gradient used by the membership banner and crown badges.
  static const LinearGradient gradientGold = LinearGradient(
    colors: <Color>[Color(0xFFF9D99F), Color(0xFFEAB15C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient gradientCrown = LinearGradient(
    colors: <Color>[Color(0xFFFFE9BE), Color(0xFFF2C172)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Membership strip: warm ivory to muted champagne.
  static const LinearGradient gradientChampagne = LinearGradient(
    colors: <Color>[Color(0xFFF7E3BF), Color(0xFFDFC08A)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Detail and player deliberately stay dark in both themes.
  static const Color playerBackground = Color(0xFF09090B);
  static const Color detailBackground = Color(0xFF0B0B0E);
  static const Color immersiveSurface = Color(0xFF141418);
  static const Color immersiveSurfaceRaised = Color(0xFF1C1C22);
  static const Color immersiveHairline = Color(0xFF2A2A31);
  static const Color immersiveTextSecondary = Color(0xB3FFFFFF);
  static const Color immersiveTextTertiary = Color(0x8AFFFFFF);
  static const Color immersiveAccent = Color(0xFFFF3B5C);
  static const Color immersiveAccentBright = Color(0xFFFF7A93);

  /// Rose used for small text on a light chip inside the dark detail page.
  static const Color immersiveAccentDeep = Color(0xFFC91036);

  static const double pagePadding = 16;
  static const double maxContentWidth = 720;
  static const double cardRadius = 18;
  static const double smallRadius = 12;
}

extension AppColorsContext on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

extension AppColorsShadow on AppColors {
  List<BoxShadow> get softShadow => <BoxShadow>[
    BoxShadow(color: shadow, blurRadius: 20, offset: const Offset(0, 8)),
  ];
}
