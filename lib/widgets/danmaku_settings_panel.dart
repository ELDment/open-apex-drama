import 'package:flutter/material.dart';

import '../app_state/danmaku_prefs.dart';
import '../theme/app_colors.dart';
import 'danmaku_settings_common.dart';

/// 桌面端弹幕设置浮动面板：细档位 + 位置说明 + 静态预览。
class DanmakuSettingsPanel extends StatelessWidget {
  const DanmakuSettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTokens.immersiveSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: ValueListenableBuilder<DanmakuSettings>(
          valueListenable: danmakuSettingsNotifier,
          builder: (BuildContext context, DanmakuSettings settings, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Text(
                        '弹幕设置',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '调整即时生效',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.white.withValues(alpha: 0.48),
                        ),
                      ),
                      const Spacer(),
                      const DanmakuCloseButton(),
                    ],
                  ),
                  const DanmakuSectionLabel('字号'),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final double size in kDesktopDanmakuSizes)
                        DanmakuOptionChip(
                          label: size.toInt().toString(),
                          selected: settings.fontSize == size,
                          onTap: () => applyDanmakuSettings(
                            settings.copyWith(fontSize: size),
                          ),
                        ),
                    ],
                  ),
                  const DanmakuSectionLabel('滚动速度'),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final DanmakuChoice<int> speed
                          in kDesktopDanmakuSpeeds)
                        DanmakuOptionChip(
                          label: speed.label,
                          selected:
                              settings.travel.inMilliseconds == speed.value,
                          onTap: () => applyDanmakuSettings(
                            settings.copyWith(
                              travel: Duration(milliseconds: speed.value),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const DanmakuSectionLabel('出现位置'),
                  Row(
                    children: <Widget>[
                      for (int i = 0; i < kDanmakuAreas.length; i++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                            child: _AreaOption(
                              area: kDanmakuAreas[i].value,
                              label: kDanmakuAreas[i].label,
                              selected:
                                  settings.area == kDanmakuAreas[i].value,
                              onTap: () => applyDanmakuSettings(
                                settings.copyWith(
                                  area: kDanmakuAreas[i].value,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _Preview(settings: settings),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 桌面端位置选项：三宫格横排，图标 + 简述。
class _AreaOption extends StatelessWidget {
  const _AreaOption({
    required this.area,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final DanmakuArea area;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const Map<DanmakuArea, IconData> _icons = <DanmakuArea, IconData>{
    DanmakuArea.scroll: Icons.swap_horiz_rounded,
    DanmakuArea.top: Icons.vertical_align_top_rounded,
    DanmakuArea.bottom: Icons.vertical_align_bottom_rounded,
  };

  static const Map<DanmakuArea, String> _descriptions = <DanmakuArea, String>{
    DanmakuArea.scroll: '右 → 左',
    DanmakuArea.top: '画面上方',
    DanmakuArea.bottom: '画面下方',
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppTokens.immersiveAccent.withValues(alpha: 0.22)
          : Colors.white.withValues(alpha: 0.05),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected
              ? AppTokens.immersiveAccentBright.withValues(alpha: 0.75)
              : Colors.transparent,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                _icons[area],
                size: 18,
                color: selected
                    ? AppTokens.immersiveAccentBright
                    : Colors.white.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(
                        alpha: selected ? 1 : 0.82,
                      ),
                    ),
                  ),
                  if (selected) ...<Widget>[
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: AppTokens.immersiveAccentBright,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _descriptions[area]!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  color: Colors.white.withValues(alpha: 0.46),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 桌面端静态预览：按当前字号与位置展示一条示例弹幕。
class _Preview extends StatelessWidget {
  const _Preview({required this.settings});

  final DanmakuSettings settings;

  @override
  Widget build(BuildContext context) {
    final double fontSize = settings.fontSize.clamp(10, 24).toDouble();
    final Alignment alignment = switch (settings.area) {
      DanmakuArea.scroll => Alignment.centerLeft,
      DanmakuArea.top => Alignment.topCenter,
      DanmakuArea.bottom => Alignment.bottomCenter,
    };
    return Container(
      height: 76,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Align(
        alignment: alignment,
        child: Text(
          settings.area == DanmakuArea.scroll ? '弹幕预览 ▶' : '弹幕预览',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.92),
            shadows: const <Shadow>[
              Shadow(color: Color(0xCC000000), blurRadius: 3),
            ],
          ),
        ),
      ),
    );
  }
}
