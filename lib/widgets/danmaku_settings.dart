import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../app_state/danmaku_prefs.dart';
import '../theme/app_colors.dart';
import 'danmaku_settings_common.dart';
import 'danmaku_settings_panel.dart';

/// 打开弹幕设置：桌面端浮动面板，移动端底部弹层。
///
/// 两端共用同一份 [danmakuSettingsNotifier]，改动即时通知播放页重绘；
/// 移动端只给少量预设档，桌面端给更细的档位与位置说明。
Future<void> showDanmakuSettings(BuildContext context) {
  if (Platform.isWindows) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (BuildContext context) => const DanmakuSettingsPanel(),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTokens.immersiveSurface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (BuildContext context) => const DanmakuSettingsSheet(),
  );
}

/// 移动端底部弹层：只保留预设档位，点选即生效。
class DanmakuSettingsSheet extends StatelessWidget {
  const DanmakuSettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ValueListenableBuilder<DanmakuSettings>(
        valueListenable: danmakuSettingsNotifier,
        builder: (BuildContext context, DanmakuSettings settings, _) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SheetTitle(title: '弹幕设置', subtitle: '点选立即生效'),
                const DanmakuSectionLabel('字号'),
                _Segmented<double>(
                  choices: kMobileDanmakuSizes,
                  selected: settings.fontSize,
                  onSelected: (double value) =>
                      applyDanmakuSettings(settings.copyWith(fontSize: value)),
                ),
                const DanmakuSectionLabel('速度'),
                _Segmented<int>(
                  choices: kMobileDanmakuSpeeds,
                  selected: settings.travel.inMilliseconds,
                  onSelected: (int value) => applyDanmakuSettings(
                    settings.copyWith(travel: Duration(milliseconds: value)),
                  ),
                ),
                const DanmakuSectionLabel('出现位置'),
                _Segmented<DanmakuArea>(
                  choices: kDanmakuAreas,
                  selected: settings.area,
                  onSelected: (DanmakuArea value) =>
                      applyDanmakuSettings(settings.copyWith(area: value)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 移动端分段选择：等宽按钮行。
class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.choices,
    required this.selected,
    required this.onSelected,
  });

  final List<DanmakuChoice<T>> choices;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < choices.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
              child: DanmakuOptionChip(
                label: choices[i].label,
                selected: choices[i].value == selected,
                onTap: () => onSelected(choices[i].value),
                expand: true,
              ),
            ),
          ),
      ],
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.white.withValues(alpha: 0.48),
            ),
          ),
          const Spacer(),
          const DanmakuCloseButton(),
        ],
      ),
    );
  }
}
