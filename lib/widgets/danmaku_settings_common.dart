import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state/danmaku_prefs.dart';
import '../theme/app_colors.dart';

/// 弹幕设置的预设档位与两端共用的小组件。
///
/// 移动端只取其中少量档位，桌面端使用更细的字号/速度列表。

/// 移动端字号 / 速度 / 位置预设。
const List<DanmakuChoice<double>> kMobileDanmakuSizes = <DanmakuChoice<double>>[
  DanmakuChoice<double>('小', 13),
  DanmakuChoice<double>('中', kDefaultDanmakuFontSize),
  DanmakuChoice<double>('大', 19),
];
const List<DanmakuChoice<int>> kMobileDanmakuSpeeds = <DanmakuChoice<int>>[
  DanmakuChoice<int>('慢', 10000),
  DanmakuChoice<int>('中', kDefaultDanmakuTravelMs),
  DanmakuChoice<int>('快', 6000),
];

/// 桌面端提供更细的字号与速度档。
const List<double> kDesktopDanmakuSizes = <double>[11, 13, 15, 17, 19, 21, 24];
const List<DanmakuChoice<int>> kDesktopDanmakuSpeeds = <DanmakuChoice<int>>[
  DanmakuChoice<int>('很慢', 12000),
  DanmakuChoice<int>('慢', 10000),
  DanmakuChoice<int>('标准', kDefaultDanmakuTravelMs),
  DanmakuChoice<int>('快', 6000),
  DanmakuChoice<int>('很快', 4500),
];

const List<DanmakuChoice<DanmakuArea>> kDanmakuAreas =
    <DanmakuChoice<DanmakuArea>>[
      DanmakuChoice<DanmakuArea>('滚动', DanmakuArea.scroll),
      DanmakuChoice<DanmakuArea>('顶部', DanmakuArea.top),
      DanmakuChoice<DanmakuArea>('底部', DanmakuArea.bottom),
    ];

/// 立即生效；落盘由 prefs 内部处理，失败不影响本次播放。
void applyDanmakuSettings(DanmakuSettings settings) {
  unawaited(saveDanmakuSettings(settings));
}

/// 带显示文案的档位。
class DanmakuChoice<T> {
  const DanmakuChoice(this.label, this.value);

  final String label;
  final T value;
}

class DanmakuSectionLabel extends StatelessWidget {
  const DanmakuSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.62),
        ),
      ),
    );
  }
}

class DanmakuCloseButton extends StatelessWidget {
  const DanmakuCloseButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '关闭',
      onPressed: () => Navigator.of(context).pop(),
      icon: Icon(
        Icons.close_rounded,
        size: 20,
        color: Colors.white.withValues(alpha: 0.72),
      ),
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
    );
  }
}

/// 设置项按钮：选中高亮，未选中为半透明底。
class DanmakuOptionChip extends StatelessWidget {
  const DanmakuOptionChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.expand = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 等宽铺满（移动端分段选择用），否则按内容宽度。
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppTokens.immersiveAccent
          : Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(9),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 34,
          padding: EdgeInsets.symmetric(horizontal: expand ? 0 : 13),
          // 不用 alignment：它会撑满 Wrap 给的整行宽，导致每个档位独占一行。
          // widthFactor 让按钮按文字宽度收缩，桌面端才能横向网格排列。
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.78),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
