import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 用系统浏览器打开外部链接；失败（无浏览器 / 链接非法）时轻提示，
/// 不抛异常打断调用方 UI。
Future<void> openInBrowser(BuildContext context, String url) async {
  final Uri? uri = Uri.tryParse(url);
  if (uri == null) {
    _toast(context);
    return;
  }
  try {
    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      _toast(context);
    }
  } catch (_) {
    if (context.mounted) {
      _toast(context);
    }
  }
}

void _toast(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('无法打开浏览器，请手动访问链接')),
  );
}
