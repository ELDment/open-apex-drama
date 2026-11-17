import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/app_pill_button.dart';
import '../widgets/page_header.dart';
import '../widgets/ambient_glow.dart';

void openPlaceholder(
  BuildContext context, {
  required String title,
  required IconData icon,
  String message = '该功能将在后续版本开放',
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext _) =>
          PlaceholderScreen(title: title, icon: icon, message: message),
    ),
  );
}

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.message,
  });

  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Scaffold(
      backgroundColor: colors.page,
      body: AmbientGlow(
        child: Column(
          children: <Widget>[
            PageHeader(title: title),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.accentSoft,
                          border: Border.all(
                            color: colors.accentSoftBorder,
                            width: 0.8,
                          ),
                        ),
                        child: Icon(icon, size: 34, color: colors.accentText),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      AppPillButton(
                        label: '返回',
                        onPressed: () => Navigator.of(context).maybePop(),
                        tone: AppButtonTone.tonal,
                        height: 40,
                        horizontalPadding: 26,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
