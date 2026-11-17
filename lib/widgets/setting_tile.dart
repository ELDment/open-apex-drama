import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SettingTile extends StatelessWidget {
  const SettingTile({
    super.key,
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
    this.showDivider = true,
    this.iconSize = 20,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;
  final bool showDivider;
  final double iconSize;

  /// Replaces the default value + chevron, e.g. with a switch.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Column(
      children: <Widget>[
        InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 54,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: <Widget>[
                  Icon(
                    icon,
                    size: iconSize,
                    color: colors.textPrimary.withValues(alpha: 0.86),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.3,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  if (trailing != null)
                    trailing!
                  else ...<Widget>[
                    if (value != null) ...<Widget>[
                      Text(
                        value!,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.2,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 19,
                      color: colors.textTertiary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 0.8,
            thickness: 0.8,
            indent: 50,
            endIndent: 16,
            color: colors.hairline,
          ),
      ],
    );
  }
}
