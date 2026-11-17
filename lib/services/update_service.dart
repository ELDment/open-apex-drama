import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// GitHub Release 检查更新。
///
/// Release 仓库（公开）：Sxuan-Coder/open-apex-drama——存放各平台安装包
/// （Android APK / Windows zip 等）与更新说明，代码在私有仓库。
/// 仓库尚无 release 时 API 返回 404，视为无更新。
class UpdateService {
  const UpdateService._();

  static const String _owner = 'Sxuan-Coder';
  static const String _repo = 'open-apex-drama';
  static const String _latestUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  /// GitHub 匿名 API 限流：每小时每 IP 只有 60 次。启动、手动点击、
  /// 反复重试都会各自消耗一次，共享出口（公司/运营商 NAT/代理）很容易打满，
  /// 满额后一律 403。所以结果缓存 [_cacheWindow] 分钟，窗口内直接用缓存，
  /// 不再发请求。
  static const Duration _cacheWindow = Duration(minutes: 10);

  static const String _cCheckedAt = 'update.checkedAt';
  static const String _cVersion = 'update.version';
  static const String _cNotes = 'update.notes';
  static const String _cUrl = 'update.downloadUrl';
  static const String _cPublishedAt = 'update.publishedAt';

  /// 检查最新版本。
  ///
  /// 返回 [UpdateInfo] 表示有新版本可更新；返回 null 表示已是最新
  /// （含仓库暂无 release）；仓库不可达等网络错误原样抛出 [UpdateException]，
  /// 由调用方决定提示文案。
  ///
  /// [useCache] 为 true 时，[_cacheWindow] 内重复检查直接用上次结果，
  /// 避免把匿名 API 配额浪费在连点上。
  static Future<UpdateInfo?> check(
    String currentVersion, {
    bool useCache = true,
  }) async {
    if (useCache) {
      final UpdateInfo? cached = await _readCache(currentVersion);
      if (cached != null) {
        return cached;
      }
      final bool? cachedNoUpdate = await _readCacheSaysLatest();
      if (cachedNoUpdate == true) {
        return null;
      }
    }
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final HttpClientRequest request =
          await client.getUrl(Uri.parse(_latestUrl));
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      request.headers.set(HttpHeaders.userAgentHeader, 'ApexDrama-App');
      final HttpClientResponse response = await request.close();
      // 404：仓库还没有任何 release——正常路径，不算错误。
      if (response.statusCode == HttpStatus.notFound) {
        return null;
      }
      if (response.statusCode == HttpStatus.forbidden) {
        // 限流是 403 的主因：把剩余等待时间翻译成人话，而不是「服务返回 403」。
        throw UpdateException(_rateLimitMessage(response));
      }
      if (response.statusCode != HttpStatus.ok) {
        throw UpdateException('服务返回 ${response.statusCode}');
      }
      final Map<String, dynamic> json = jsonDecode(
        await response.transform(utf8.decoder).join(),
      ) as Map<String, dynamic>;

      final String tag = (json['tag_name'] as String?)?.trim() ?? '';
      final String latest = tag.replaceFirst(RegExp('^v'), '');
      final bool newer = latest.isNotEmpty && _isNewer(latest, currentVersion);
      final UpdateInfo info = UpdateInfo(
        version: latest,
        notes: (json['body'] as String?)?.trim() ?? '',
        downloadUrl: _pickApkUrl(json['assets'] as List<dynamic>?),
        publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
      );
      await _writeCache(info, newer: newer);
      return newer ? info : null;
    } on UpdateException {
      rethrow;
    } catch (_) {
      throw UpdateException('网络异常，请稍后重试');
    } finally {
      client.close(force: true);
    }
  }

  /// 403 的提示文案：带上 GitHub 给的配额重置时间（x-ratelimit-reset）。
  static String _rateLimitMessage(HttpClientResponse response) {
    final String? resetHeader = response.headers.value('x-ratelimit-reset');
    final int resetSeconds = int.tryParse(resetHeader ?? '') ?? 0;
    if (resetSeconds <= 0) {
      return 'GitHub 接口请求过于频繁，请稍后再试';
    }
    final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final int waitMinutes = ((resetSeconds - now) / 60).ceil();
    if (waitMinutes <= 0) {
      return 'GitHub 接口请求过于频繁，请重试';
    }
    return 'GitHub 接口限流，请 $waitMinutes 分钟后再试';
  }

  /// 读缓存：命中窗口内且确实有更新时返回 [UpdateInfo]。
  static Future<UpdateInfo?> _readCache(String currentVersion) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!_isFresh(prefs)) {
      return null;
    }
    final String version = prefs.getString(_cVersion) ?? '';
    if (version.isEmpty || !_isNewer(version, currentVersion)) {
      return null;
    }
    return UpdateInfo(
      version: version,
      notes: prefs.getString(_cNotes) ?? '',
      downloadUrl: prefs.getString(_cUrl) ?? _releasePageUrl(),
      publishedAt: DateTime.tryParse(prefs.getString(_cPublishedAt) ?? ''),
    );
  }

  /// 读缓存：窗口内上次检查判定「已是最新」时返回 true。
  static Future<bool?> _readCacheSaysLatest() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!_isFresh(prefs)) {
      return null;
    }
    return prefs.getString(_cVersion) != null;
  }

  static bool _isFresh(SharedPreferences prefs) {
    final int checkedAt = prefs.getInt(_cCheckedAt) ?? 0;
    if (checkedAt <= 0) {
      return false;
    }
    final int elapsed =
        DateTime.now().millisecondsSinceEpoch - checkedAt;
    return elapsed >= 0 && elapsed < _cacheWindow.inMilliseconds;
  }

  static Future<void> _writeCache(UpdateInfo info, {required bool newer}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _cCheckedAt,
      DateTime.now().millisecondsSinceEpoch,
    );
    if (!newer) {
      // 已是最新：保留版本号用于判定命中，但不当作可更新结果。
      await prefs.setString(_cVersion, info.version.isEmpty ? '0.0.0' : info.version);
      await prefs.remove(_cNotes);
      await prefs.remove(_cUrl);
      await prefs.remove(_cPublishedAt);
      return;
    }
    await prefs.setString(_cVersion, info.version);
    await prefs.setString(_cNotes, info.notes);
    await prefs.setString(_cUrl, info.downloadUrl);
    await prefs.setString(
      _cPublishedAt,
      info.publishedAt?.toIso8601String() ?? '',
    );
  }

  /// 从 release assets 里挑当前平台的下载资产（按 dart:io 平台分支）：
  /// - Windows：`.zip` / `.msix` / `.exe`，名称含 `windows-x64` 优先；
  /// - Android / 其他：`.apk`，arm64-v8a 优先（原有逻辑不变）；
  /// 都没有则回退 release 页面（浏览器里手动选择）。
  static String _pickApkUrl(List<dynamic>? assets) {
    if (assets == null || assets.isEmpty) {
      return _releasePageUrl();
    }
    return Platform.isWindows
        ? _pickWindowsAssetUrl(assets)
        : _pickAndroidApkUrl(assets);
  }

  /// Windows 资产筛选：优先名称含 `windows-x64` 的 zip/msix/exe（发布
  /// 命名约定如 `ApexDrama-1.1.0-windows-x64.zip`），其次任意匹配
  /// 扩展名的资产，都没有则回退 release 页面。
  static String _pickWindowsAssetUrl(List<dynamic> assets) {
    String? any;
    for (final dynamic asset in assets) {
      final Map<String, dynamic> a = asset as Map<String, dynamic>;
      final String name = (a['name'] as String?) ?? '';
      final String url = (a['browser_download_url'] as String?) ?? '';
      if (url.isEmpty || !_isWindowsAssetName(name)) {
        continue;
      }
      if (name.toLowerCase().contains('windows-x64')) {
        return url;
      }
      any ??= url;
    }
    return any ?? _releasePageUrl();
  }

  static bool _isWindowsAssetName(String name) {
    return name.endsWith('.zip') ||
        name.endsWith('.msix') ||
        name.endsWith('.exe');
  }

  /// Android 资产筛选：优先 arm64（主流机型），其次任意 .apk。
  static String _pickAndroidApkUrl(List<dynamic> assets) {
    String? any;
    for (final dynamic asset in assets) {
      final Map<String, dynamic> a = asset as Map<String, dynamic>;
      final String name = (a['name'] as String?) ?? '';
      final String url = (a['browser_download_url'] as String?) ?? '';
      if (!url.isNotEmpty || !name.endsWith('.apk')) {
        continue;
      }
      if (name.contains('arm64-v8a')) {
        return url;
      }
      any ??= url;
    }
    return any ?? _releasePageUrl();
  }

  static String _releasePageUrl() => 'https://github.com/$_owner/$_repo/releases/latest';

  /// 语义化版本比较：逐段数字比较，段数不足补 0。
  /// 1.10 > 1.9；1.0.1 > 1.0；非法字符按 0 处理。
  static bool _isNewer(String candidate, String current) {
    final List<int> a = _versionSegments(candidate);
    final List<int> b = _versionSegments(current);
    final int len = a.length > b.length ? a.length : b.length;
    for (int i = 0; i < len; i++) {
      final int x = i < a.length ? a[i] : 0;
      final int y = i < b.length ? b[i] : 0;
      if (x != y) {
        return x > y;
      }
    }
    return false;
  }

  static List<int> _versionSegments(String version) {
    return version
        .split('.')
        .map((String part) => int.tryParse(part.trim()) ?? 0)
        .toList();
  }
}

/// 可用的更新信息。
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.notes,
    required this.downloadUrl,
    this.publishedAt,
  });

  /// 新版本号（tag 去掉 v 前缀），如 1.0.1。
  final String version;

  /// Release 说明正文（Markdown 原文，UI 以纯文本分行展示）。
  final String notes;

  /// 下载地址（浏览器打开）：Android 为 APK，Windows 为 zip/msix/exe
  /// 安装包；没有匹配资产时回退 release 页面。
  final String downloadUrl;
  final DateTime? publishedAt;
}

/// 检查失败（网络不可达 / 服务异常）。
class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}
