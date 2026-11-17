import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Filter chip. Selected state uses the solid brand fill (orange in light mode,
/// rose in dark) exactly like both prototypes.
class SoftChip extends StatelessWidget {
  const SoftChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dense = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final double radius = dense ? 8 : 10;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? colors.brandStrong : colors.surface,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: dense ? 11 : 14,
              vertical: dense ? 5.5 : 8,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: selected ? Colors.transparent : colors.hairline,
                width: 0.8,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: dense ? 11.5 : 12.5,
                height: 1.2,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? colors.onBrand : colors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
