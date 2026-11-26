import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../app_state/project_info.dart';

/// 调起系统分享面板分享剧集。
///
/// 无第三方平台 SDK，由系统分享面板分发到 QQ / 微信等已安装应用。
class DramaShare {
  const DramaShare._();

  /// 分享文案：剧名 + 仓库下载地址（固定指向 Releases 所在页）。
  static String message(String title) =>
      '我在用ApexDrama看水果短剧《$title》，推荐给你！\n'
      '下载地址：$projectRepoUrl';

  /// 失败不抛给调用方，改为在 [context] 上提示，不打断播放。
  static Future<void> share(BuildContext context, String title) async {
    final bool ok = await _share(title);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前设备无法调起系统分享')),
      );
    }
  }

  static Future<bool> _share(String title) async {
    try {
      await SharePlus.instance.share(ShareParams(text: message(title)));
      return true;
    } catch (_) {
      return false;
    }
  }
}
