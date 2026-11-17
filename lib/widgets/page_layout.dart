import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Horizontal page padding that keeps content centered and capped at 720dp on
/// tablets while staying at 16dp on phones.
/// Windows 桌面放宽到 1200dp：宽窗下内容铺满（对标桌面短剧客户端），
/// 移动端（含平板）维持原 720dp 封顶不变。
double horizontalPagePadding(BuildContext context) {
  final double width = MediaQuery.sizeOf(context).width;
  final double maxContentWidth = Platform.isWindows
      ? 1200
      : AppTokens.maxContentWidth;
  if (width > maxContentWidth + AppTokens.pagePadding * 2) {
    return (width - maxContentWidth) / 2;
  }
  return AppTokens.pagePadding;
}

/// Page content width after [horizontalPagePadding], floored at zero so the
/// first frame (viewport metrics still empty) cannot yield negative grid
/// extents.
double pageContentWidth(BuildContext context) {
  return math.max(0, MediaQuery.sizeOf(context).width - horizontalPagePadding(context) * 2);
}

/// Responsive column count for the poster grid.
/// 宽窗（桌面）阶梯放宽到 6 列，海报尺寸保持接近移动端的观感。
int dramaGridColumns(double contentWidth) {
  if (contentWidth < 300) {
    return 2;
  }
  if (contentWidth >= 1160) {
    return 6;
  }
  if (contentWidth >= 880) {
    return 5;
  }
  if (contentWidth >= 600) {
    return 4;
  }
  return 3;
}
