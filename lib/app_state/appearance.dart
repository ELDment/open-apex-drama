import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全局外观模式，由设置页「外观」分组驱动；跨会话持久化。
final ValueNotifier<ThemeMode> appearanceMode =
    ValueNotifier<ThemeMode>(ThemeMode.system);

const String _kAppearanceKey = 'appearance.mode';

/// 启动时恢复上次的设置（在 runApp 前调用）。
Future<void> loadAppearance() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String stored = prefs.getString(_kAppearanceKey) ?? '';
  appearanceMode.value = switch (stored) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

/// 保存外观设置；写入 [mode] 同时同步到 notifier。
Future<void> saveAppearance(ThemeMode mode) async {
  appearanceMode.value = mode;
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kAppearanceKey, switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  });
}
