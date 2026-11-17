import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 本地个人信息：无账号体系，昵称与用户 ID 全部保存在本机
/// （SharedPreferences），跨会话持久化。模式与 appearance.dart 一致：
/// 全局 ValueNotifier + 启动加载 + 写入即通知。
class UserProfile {
  const UserProfile({required this.nickname, required this.userId});

  final String nickname;
  final String userId;

  /// 头像圆标展示的字：昵称首字；空昵称回落「剧」。
  String get avatarChar {
    final Runes runes = nickname.trim().runes;
    if (runes.isEmpty) {
      return '剧';
    }
    return String.fromCharCode(runes.first);
  }
}

/// 全局资料状态，「我的」页头部直接读 [value]。
final ValueNotifier<UserProfile> profileNotifier =
    ValueNotifier<UserProfile>(
      const UserProfile(nickname: _defaultNickname, userId: ''),
    );

const String _kNicknameKey = 'profile.nickname.v1';
const String _kUserIdKey = 'profile.userId.v1';
const String _defaultNickname = '剧友';

/// 启动时恢复本地资料；首次使用时生成 8 位用户 ID 并落盘（在 runApp
/// 前调用）。SharedPreferences 不可用（widget 测试、插件未注册）时
/// 降级为内存默认值，接口行为一致。
Future<void> loadProfile() async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String userId = prefs.getString(_kUserIdKey) ?? '';
    if (userId.isEmpty) {
      userId = ((DateTime.now().millisecondsSinceEpoch ~/ 1000) %
              100000000)
          .toString()
          .padLeft(8, '0');
      await prefs.setString(_kUserIdKey, userId);
    }
    final String nickname = prefs.getString(_kNicknameKey) ?? '';
    profileNotifier.value = UserProfile(
      nickname: nickname.isEmpty ? _defaultNickname : nickname,
      userId: userId,
    );
  } catch (_) {
    // MissingPluginException：测试环境降级，保证「我的」页仍有资料可展示。
    if (profileNotifier.value.userId.isEmpty) {
      profileNotifier.value = const UserProfile(
        nickname: _defaultNickname,
        userId: '00000001',
      );
    }
  }
}

/// 保存昵称（空白串忽略）；内存态即时生效，落盘异步跟随。
Future<void> saveNickname(String nickname) async {
  final String trimmed = nickname.trim();
  if (trimmed.isEmpty || trimmed == profileNotifier.value.nickname) {
    return;
  }
  profileNotifier.value = UserProfile(
    nickname: trimmed,
    userId: profileNotifier.value.userId,
  );
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNicknameKey, trimmed);
  } catch (_) {
    // 落盘失败不阻断 UI：内存态已更新，重启后回到旧昵称可接受。
  }
}
