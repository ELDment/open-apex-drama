import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 弹幕开关：全局记忆，播放页控制栏的「弹」按钮切换。
///
/// 与倍速一样属于用户习惯，换剧、重启都沿用；模式参考 playback_prefs。
final ValueNotifier<bool> danmakuEnabledNotifier = ValueNotifier<bool>(true);

/// 弹幕出现位置。
enum DanmakuArea { scroll, top, bottom }

/// 弹幕渲染参数：字号、滚动速度（横穿屏幕所需时间）与出现位置。
///
/// 同样是全局偏好，换剧、切集、重启都沿用；播放页与设置面板共用同一份。
@immutable
class DanmakuSettings {
  const DanmakuSettings({
    this.fontSize = kDefaultDanmakuFontSize,
    this.travel = const Duration(milliseconds: kDefaultDanmakuTravelMs),
    this.area = DanmakuArea.scroll,
  });

  /// 字号，单位逻辑像素。
  final double fontSize;

  /// 一条弹幕从右边缘走到左边缘外所需时间；越短越快。
  final Duration travel;

  /// 出现位置：滚动 / 顶部 / 底部。
  ///
  /// 顶部与底部为停留式弹幕（水平居中、显示 [travel] 后消失）。
  final DanmakuArea area;

  DanmakuSettings copyWith({
    double? fontSize,
    Duration? travel,
    DanmakuArea? area,
  }) {
    return DanmakuSettings(
      fontSize: fontSize ?? this.fontSize,
      travel: travel ?? this.travel,
      area: area ?? this.area,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DanmakuSettings &&
        other.fontSize == fontSize &&
        other.travel == travel &&
        other.area == area;
  }

  @override
  int get hashCode => Object.hash(fontSize, travel, area);
}

/// 默认字号与滚动时长；与改动前的弹幕观感保持一致。
const double kDefaultDanmakuFontSize = 15;
const int kDefaultDanmakuTravelMs = 8000;

/// 字号合法区间：防止脏数据把弹幕画到看不见。
const double kMinDanmakuFontSize = 10;
const double kMaxDanmakuFontSize = 40;
const int kMinDanmakuTravelMs = 2000;
const int kMaxDanmakuTravelMs = 20000;

/// 弹幕设置的全局状态（默认值即旧版观感）。
final ValueNotifier<DanmakuSettings> danmakuSettingsNotifier =
    ValueNotifier<DanmakuSettings>(const DanmakuSettings());

const String _kEnabledKey = 'danmaku.enabled.v1';
const String _kFontSizeKey = 'danmaku.fontSize.v1';
const String _kTravelMsKey = 'danmaku.travelMs.v1';
const String _kAreaKey = 'danmaku.area.v1';

/// 启动时恢复开关与设置（runApp 前调用）。SharedPreferences 不可用时用默认值。
Future<void> loadDanmakuPrefs() async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    danmakuEnabledNotifier.value = prefs.getBool(_kEnabledKey) ?? true;
    danmakuSettingsNotifier.value = _readSettings(prefs);
  } catch (_) {
    danmakuEnabledNotifier.value = true;
    danmakuSettingsNotifier.value = const DanmakuSettings();
  }
}

DanmakuSettings _readSettings(SharedPreferences prefs) {
  final double? font = prefs.getDouble(_kFontSizeKey);
  final int? travelMs = prefs.getInt(_kTravelMsKey);
  final int? areaIndex = prefs.getInt(_kAreaKey);
  return DanmakuSettings(
    fontSize:
        font != null &&
            font >= kMinDanmakuFontSize &&
            font <= kMaxDanmakuFontSize
        ? font
        : kDefaultDanmakuFontSize,
    travel: Duration(
      milliseconds:
          travelMs != null &&
              travelMs >= kMinDanmakuTravelMs &&
              travelMs <= kMaxDanmakuTravelMs
          ? travelMs
          : kDefaultDanmakuTravelMs,
    ),
    area:
        areaIndex != null &&
            areaIndex >= 0 &&
            areaIndex < DanmakuArea.values.length
        ? DanmakuArea.values[areaIndex]
        : DanmakuArea.scroll,
  );
}

/// 记住开关状态；落盘失败只影响下次启动的恢复。
Future<void> saveDanmakuEnabled(bool enabled) async {
  danmakuEnabledNotifier.value = enabled;
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabledKey, enabled);
  } catch (_) {
    // 落盘失败不影响本次播放。
  }
}

/// 应用并记住弹幕设置：立即通知播放页重绘，再落盘。
Future<void> saveDanmakuSettings(DanmakuSettings settings) async {
  danmakuSettingsNotifier.value = settings;
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kFontSizeKey, settings.fontSize);
    await prefs.setInt(_kTravelMsKey, settings.travel.inMilliseconds);
    await prefs.setInt(_kAreaKey, settings.area.index);
  } catch (_) {
    // 落盘失败不影响本次播放。
  }
}
