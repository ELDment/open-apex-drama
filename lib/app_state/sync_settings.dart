import 'package:shared_preferences/shared_preferences.dart';

import 'playback_prefs.dart';
import 'profile.dart';

/// 可跨设备同步的「应用设置」：播放倍速 + 昵称。
///
/// 与观看记录不同，设置项少且互相独立，云端不做逐字段合并，而是整块按
/// [SyncableSettings.updatedAt]「新者胜」——语义简单、不会出现半新半旧的
/// 组合，也省掉每个字段一个时间戳。
class SyncableSettings {
  const SyncableSettings({
    required this.playbackRate,
    required this.nickname,
    required this.updatedAt,
  });

  final double playbackRate;
  final String nickname;

  /// 本机最后一次修改设置的时间（unix 毫秒），用于整块比较新旧。
  final int updatedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'playbackRate': playbackRate,
    'nickname': nickname,
  };

  /// 解析云端 settings 字段；缺字段时回落到本机现有值，避免把设置清空。
  static SyncableSettings? fromJson(Object? raw, int updatedAt) {
    if (raw is! Map) {
      return null;
    }
    final double? rate = (raw['playbackRate'] as num?)?.toDouble();
    final String nickname = (raw['nickname'] as String?)?.trim() ?? '';
    if (rate == null && nickname.isEmpty) {
      return null;
    }
    return SyncableSettings(
      playbackRate: rate ?? playbackRateNotifier.value,
      nickname: nickname.isEmpty ? profileNotifier.value.nickname : nickname,
      updatedAt: updatedAt,
    );
  }
}

const String _kSettingsUpdatedAtKey = 'settings.updatedAt.v1';

Future<int> readSettingsUpdatedAt() async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kSettingsUpdatedAtKey) ?? 0;
  } catch (_) {
    return 0;
  }
}

/// 本地设置改动后调用：把版本时间推到当前时刻。
Future<void> touchSettingsUpdatedAt() async {
  await setSettingsUpdatedAt(DateTime.now().millisecondsSinceEpoch);
}

Future<void> setSettingsUpdatedAt(int value) async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSettingsUpdatedAtKey, value);
  } catch (_) {
    // 落盘失败只影响本次同步的新旧判断，不影响本机使用。
  }
}

/// 当前本机的可同步设置。
Future<SyncableSettings> readSyncableSettings() async {
  return SyncableSettings(
    playbackRate: playbackRateNotifier.value,
    nickname: profileNotifier.value.nickname,
    updatedAt: await readSettingsUpdatedAt(),
  );
}

/// 记住用户新选的倍速（本地 + 同步时间戳）。
Future<void> rememberPlaybackRate(double rate) async {
  await savePlaybackRate(rate);
  await touchSettingsUpdatedAt();
}

/// 记住用户改的昵称（本地 + 同步时间戳）。
Future<void> rememberNickname(String nickname) async {
  await saveNickname(nickname);
  await touchSettingsUpdatedAt();
}

/// 应用云端设置：先写本地内存/存储，再把时间戳回写成云端那份，
/// 否则本地时间戳被刷新成「现在」，下一次同步会反向上传覆盖云端。
Future<void> applySyncedSettings(SyncableSettings settings) async {
  await savePlaybackRate(settings.playbackRate);
  await saveNickname(settings.nickname);
  await setSettingsUpdatedAt(settings.updatedAt);
}
