import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全局播放偏好：倍速。
///
/// 倍速是「用户习惯」而不是「单集状态」：在任意一部剧里调过之后，
/// 换剧、切集、重启应用都沿用同一个值。模式与 appearance.dart /
/// profile.dart 一致——全局 ValueNotifier + 启动加载 + 写入即通知。
final ValueNotifier<double> playbackRateNotifier = ValueNotifier<double>(1.0);

const String _kRateKey = 'playback.rate.v1';

/// 本地默认倍速；1.0 表示原速。
const double kDefaultPlaybackRate = 1.0;

/// 启动时恢复上次选择的倍速（在 runApp 前调用）。
///
/// SharedPreferences 不可用（widget 测试 / 插件未注册）时降级为原速，
/// 接口行为一致。
Future<void> loadPlaybackPrefs() async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final double? rate = prefs.getDouble(_kRateKey);
    if (rate != null && rate > 0) {
      playbackRateNotifier.value = rate;
    }
  } catch (_) {
    playbackRateNotifier.value = kDefaultPlaybackRate;
  }
}

/// 记住用户新选的倍速：更新全局状态并落盘，失败只影响下次启动的恢复。
Future<void> savePlaybackRate(double rate) async {
  if (rate <= 0) {
    return;
  }
  playbackRateNotifier.value = rate;
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kRateKey, rate);
  } catch (_) {
    // 落盘失败不影响本次播放。
  }
}
