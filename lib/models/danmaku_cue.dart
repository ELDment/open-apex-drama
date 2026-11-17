import 'package:flutter/foundation.dart';

/// 一条待渲染的弹幕。
///
/// 只保留渲染需要的两个字段：文案与在分集里的出现时间（毫秒）。
/// SDK 的 Danmaku 还有点赞、发送时间等字段，播放页暂时用不到。
@immutable
class DanmakuCue {
  const DanmakuCue({required this.text, required this.offsetMs});

  final String text;

  /// 在分集里出现的时间，单位毫秒。
  final int offsetMs;

  Duration get offset => Duration(milliseconds: offsetMs);
}
