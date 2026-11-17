import 'dart:io';

import 'package:flutter/services.dart';

/// Android「安装未知应用」授权桥接。
///
/// 安装 APK 受两层限制：Manifest 声明 `REQUEST_INSTALL_PACKAGES`（已声明）
/// 和用户为本应用打开「安装未知应用」。后者没有运行时弹窗，只能跳系统
/// 设置让用户手动开启，因此这里只做状态查询与跳转。
class ApkInstaller {
  const ApkInstaller._();

  static const MethodChannel _channel = MethodChannel('apexduanju/install');

  /// 是否已允许安装未知应用；非 Android 恒为 true。
  static Future<bool> canInstall() async {
    if (!Platform.isAndroid) {
      return true;
    }
    try {
      return await _channel.invokeMethod<bool>('canRequestPackageInstalls') ??
          false;
    } on PlatformException {
      // 通道异常时按未授权处理，引导用户去设置总比静默失败好。
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 跳转系统授权页；跳转成功返回 true。
  static Future<bool> openSettings() async {
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('openInstallSettings') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
