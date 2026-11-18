/// 更新包下载镜像的 URL 拼装与排序。
///
/// 三种镜像的格式不同：
/// - xget：`github.com/owner/repo/...` → `xget.xi-xu.me/gh/owner/repo/...`；
/// - ghfast / gh-proxy：前缀 + 完整原始 URL。
///
/// 默认顺序只在启动测速完成前使用；测速结果由
/// `update_mirror_probe.dart` 写入缓存。
class UpdateMirrors {
  const UpdateMirrors._();

  static const String xgetId = 'xget';
  static const String ghfastId = 'ghfast';
  static const String ghProxyId = 'gh-proxy';

  /// 默认下载顺序：实测 gh-proxy 首字节延迟最低，xget 次之，ghfast 最慢。
  /// 启动测速完成后会被实测顺序覆盖。
  static const List<String> defaultOrder = <String>[
    ghProxyId,
    xgetId,
    ghfastId,
  ];

  /// 后台测速顺序与默认下载顺序分开，避免调整默认顺序时改变“第一个
  /// 被测镜像”的偏差。
  static const List<String> probeOrder = <String>[
    xgetId,
    ghfastId,
    ghProxyId,
  ];

  static const Map<String, String> _prefixes = <String, String>{
    ghfastId: 'https://ghfast.top/',
    ghProxyId: 'https://gh-proxy.com/',
  };

  static const String _xgetPrefix = 'https://xget.xi-xu.me/gh';

  /// 按镜像 id 拼下载地址；非 GitHub 地址不会生成 xget 链接。
  static String? url(String id, String assetUrl) {
    if (id == xgetId) {
      return _xgetUrl(assetUrl);
    }
    final String? prefix = _prefixes[id];
    return prefix == null ? null : '$prefix$assetUrl';
  }

  /// 生成下载候选地址：按 [order] 排序，未列出的镜像补在末尾，
  /// 官方直链始终最后。
  static List<String> candidates(String assetUrl, {List<String>? order}) {
    final List<String> ids = <String>[];
    for (final String id in <String>[...?order, ...defaultOrder]) {
      if (!ids.contains(id)) {
        ids.add(id);
      }
    }
    final List<String> urls = <String>[];
    for (final String id in ids) {
      final String? url = UpdateMirrors.url(id, assetUrl);
      if (url != null) {
        urls.add(url);
      }
    }
    urls.add(assetUrl);
    return urls;
  }

  static String? _xgetUrl(String assetUrl) {
    final Uri? uri = Uri.tryParse(assetUrl);
    if (uri == null || uri.host != 'github.com') {
      return null;
    }
    if (uri.path.isEmpty || uri.path == '/') {
      return null;
    }
    final String query = uri.hasQuery ? '?${uri.query}' : '';
    return '$_xgetPrefix${uri.path}$query';
  }
}
