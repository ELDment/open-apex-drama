import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_pill_button.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Optional accent; defaults to the theme brand color.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final Color tint = accent ?? colors.brand;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: 156,
            height: 118,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Container(
                  width: 118,
                  height: 96,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    gradient: RadialGradient(
                      colors: <Color>[
                        tint.withValues(alpha: 0.16),
                        tint.withValues(alpha: 0.02),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        tint.withValues(alpha: 0.12),
                        tint.withValues(alpha: 0.24),
                      ],
                    ),
                    border: Border.all(
                      color: tint.withValues(alpha: 0.18),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(icon, size: 40, color: tint),
                ),
                Positioned(
                  top: 6,
                  right: 22,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 17,
                    color: tint.withValues(alpha: 0.55),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 18,
                  child: Icon(
                    Icons.circle,
                    size: 5,
                    color: tint.withValues(alpha: 0.35),
                  ),
                ),
                Positioned(
                  top: 30,
                  left: 10,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 11,
                    color: tint.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: colors.textSecondary,
            ),
          ),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: 20),
            AppPillButton(
              label: actionLabel!,
              onPressed: onAction,
              height: 42,
              horizontalPadding: 28,
              fontSize: 14,
            ),
          ],
        ],
      ),
    );
  }
}
