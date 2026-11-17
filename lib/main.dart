import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'app_state/appearance.dart';
import 'app_state/danmaku_prefs.dart';
import 'app_state/playback_prefs.dart';
import 'app_state/profile.dart';
import 'providers/data_providers.dart';

/// 编译期数据源开关：`--dart-define=USE_MOCK=true` 时启动即用 Mock 数据
/// （桌面开发等场景）；缺省仍为 SDK 直连，Android 行为不变。
/// 运行时仍可在 SDK 调试页手动切换。
const bool _useMock = bool.fromEnvironment('USE_MOCK');

/// 初始状态为 mock 的 [DataModeNotifier]，其余行为（含手动切换）全部沿用。
class _MockFirstDataModeNotifier extends DataModeNotifier {
  @override
  DataMode build() => DataMode.mock;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // window_manager（播放页窗口全屏用）要求在 runApp 前初始化。
  // 该插件只有桌面实现：Android 上调用其 channel 会抛 MissingPluginException
  // 且发生在 runApp 之前 → 黑屏（v1.1.0 线上事故），必须按平台 gating。
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
  }
  try {
    MediaKit.ensureInitialized();
  } catch (error) {
    // Windows 桌面壳阶段尚未引入 media_kit_libs_windows_video，libmpv-2.dll
    // 缺失时 ensureInitialized 会抛异常。降级放行让 UI 壳照常启动；播放
    // 内核依赖补齐后此处自然恢复成功，无需改回。Android/iOS 不受影响。
    debugPrint('MediaKit.ensureInitialized skipped: $error');
  }
  await loadAppearance();
  await loadProfile();
  await loadPlaybackPrefs();
  await loadDanmakuPrefs();
  runApp(
    ProviderScope(
      overrides: [
        if (_useMock)
          dataModeProvider.overrideWith(_MockFirstDataModeNotifier.new),
      ],
      child: const ApexApp(),
    ),
  );
}
