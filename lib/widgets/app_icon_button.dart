import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Small icon button used for search / settings entry points.
///
/// [plain] renders a bare icon (used on the photo-like top bars of the new
/// prototype), while the default renders a soft circular surface.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 40,
    this.iconSize = 20,
    this.plain = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: plain ? Colors.transparent : colors.surface,
        shape: CircleBorder(
          side: BorderSide(
            color: plain ? Colors.transparent : colors.hairline,
            width: 0.8,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: Icon(icon, size: iconSize, color: colors.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
