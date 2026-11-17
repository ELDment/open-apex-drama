import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.trailingIcon,
    this.onTrailingTap,
  });

  final String title;
  final String? trailing;
  final IconData? trailingIcon;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final Widget? trailingWidget = trailing == null
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (trailingIcon != null) ...<Widget>[
                Icon(trailingIcon, size: 13, color: colors.textTertiary),
                const SizedBox(width: 3),
              ],
              Text(
                trailing!,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.2,
                  color: colors.textTertiary,
                ),
              ),
              const SizedBox(width: 1),
              Icon(
                Icons.chevron_right_rounded,
                size: 15,
                color: colors.textTertiary,
              ),
            ],
          );

    return Row(
      children: <Widget>[
        Text(
          title,
          style: TextStyle(
            fontSize: 17.5,
            height: 1.25,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
            color: colors.textPrimary,
          ),
        ),
        const Spacer(),
        if (trailingWidget != null)
          if (onTrailingTap != null)
            InkWell(
              onTap: onTrailingTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: trailingWidget,
              ),
            )
          else
            trailingWidget,
      ],
    );
  }
}
