import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'watch_sync_document.dart';

/// WebDAV 连接配置（坚果云 / Nextcloud / 群晖等通用 WebDAV）。
class WebDavConfig {
  const WebDavConfig({
    required this.serverUrl,
    required this.username,
    required this.password,
    this.remoteDir = defaultRemoteDir,
  });

  /// 默认按坚果云官方 WebDAV 地址预填；其他服务商可自行修改。
  static const String defaultServerUrl = 'https://dav.jianguoyun.com/dav/';
  static const String defaultRemoteDir = 'ApexDrama';

  /// 1.2.x 及更早版本的默认目录；读取旧配置时自动迁移到
  /// [defaultRemoteDir]，避免老用户同步到两个不同文件夹。
  static const String legacyDefaultRemoteDir = 'apexduanju';

  final String serverUrl;
  final String username;
  final String password;
  final String remoteDir;

  /// Basic 认证用的账号：归一化全角字符并去掉首尾空白。
  ///
  /// 中文输入法下很容易打出全角 `＠`（U+FF20），坚果云会按 US-ASCII
  /// 解码认证头并直接返回 400「Unable to decode byte array…」。
  String get authUsername => normalizeWebDavCredential(username).trim();

  String get authPassword => normalizeWebDavCredential(password);

  /// 归一化后仍有非 ASCII 字符：绝大多数 WebDAV 服务都无法处理。
  bool get hasUnsupportedCredential {
    return !_isAscii(authUsername) || !_isAscii(authPassword);
  }

  bool get isConfigured =>
      serverUrl.trim().isNotEmpty &&
      authUsername.isNotEmpty &&
      authPassword.isNotEmpty;

  WebDavConfig copyWith({
    String? serverUrl,
    String? username,
    String? password,
    String? remoteDir,
  }) {
    return WebDavConfig(
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      remoteDir: remoteDir ?? this.remoteDir,
    );
  }

  /// 服务器地址补全末尾斜杠（`https://dav.jianguoyun.com/dav` → `.../dav/`）。
  String get normalizedServerUrl {
    final String raw = serverUrl.trim();
    return raw.endsWith('/') ? raw : '$raw/';
  }

  /// 远程目录 URI（末尾不带斜杠）。
  Uri get directoryUri => _buildUri();

  /// 同步文件完整 URI。
  Uri get fileUri => _buildUri(fileName: SyncDocument.fileName);

  Uri _buildUri({String? fileName}) {
    final Uri base = Uri.parse(normalizedServerUrl);
    final List<String> segments = <String>[
      ...base.pathSegments.where((String segment) => segment.isNotEmpty),
      ...remoteDir
          .split('/')
          .map((String segment) => segment.trim())
          .where((String segment) => segment.isNotEmpty),
      ?fileName,
    ];
    return base.replace(path: '/${segments.join('/')}');
  }
}

/// 全角 ASCII（U+FF01–U+FF5E）→ 半角、全角空格 / 不间断空格 → 普通空格，
/// 并移除复制粘贴常见的零宽字符。用于账号 / 密码输入。
String normalizeWebDavCredential(String input) {
  final StringBuffer buffer = StringBuffer();
  for (final int rune in input.runes) {
    if (rune >= 0xFF01 && rune <= 0xFF5E) {
      buffer.writeCharCode(rune - 0xFEE0);
    } else if (rune == 0x3000 || rune == 0x00A0) {
      buffer.write(' ');
    } else if (rune == 0x200B ||
        rune == 0x200C ||
        rune == 0x200D ||
        rune == 0xFEFF) {
      // 零宽字符：直接丢弃。
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

bool _isAscii(String value) {
  for (final int rune in value.runes) {
    if (rune > 0x7F) {
      return false;
    }
  }
  return true;
}

/// WebDAV 请求失败（网络 / 鉴权 / 服务端错误），message 直接可展示给用户。
class WebDavException implements Exception {
  const WebDavException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'WebDavException($statusCode): $message';
}

/// 最小 WebDAV 客户端：只做本功能需要的 GET / PUT / MKCOL / PROPFIND，
/// 不引入额外依赖。使用基础认证（坚果云要求「应用密码」）。
class WebDavClient {
  WebDavClient({
    required this.config,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  final WebDavConfig config;
  final Duration timeout;
  final http.Client _client;

  String get _authorizationHeader {
    final String token = base64Encode(
      utf8.encode('${config.authUsername}:${config.authPassword}'),
    );
    return 'Basic $token';
  }

  /// 下载同步文件；文件不存在（首次同步）返回 null。
  ///
  /// 坚果云在「远程目录还不存在」时对 GET 返回 409（而不是 404），因此
  /// 409 同样视为「云端还没有同步文件」，由后续上传流程先 MKCOL 建目录。
  Future<String?> download() async {
    final http.Response response = await _send('GET', config.fileUri);
    if (response.statusCode == 404 || response.statusCode == 409) {
      return null;
    }
    _ensureOk(response, action: '读取云端同步文件');
    return utf8.decode(response.bodyBytes);
  }

  /// 上传同步文件（覆盖写入）。
  ///
  /// 不预先 MKCOL：坚果云对「已存在目录」的 MKCOL 会返回 400，预建目录会
  /// 把本来能成功的上传变成失败。先直接 PUT，只有服务端抱怨目录不存在
  /// （404/409）时才建目录并重试一次。
  Future<void> upload(String content) async {
    final List<int> body = utf8.encode(content);
    http.Response response = await _put(body);
    if (response.statusCode == 404 || response.statusCode == 409) {
      await ensureDirectory();
      response = await _put(body);
    }
    _ensureOk(response, action: '上传同步文件');
  }

  Future<http.Response> _put(List<int> body) {
    return _send(
      'PUT',
      config.fileUri,
      body: body,
      contentType: 'application/json; charset=utf-8',
    );
  }

  /// 确保远程目录存在：201 创建成功，200/400/405 都视为「目录已存在」。
  Future<void> ensureDirectory() async {
    final http.Response response = await _send('MKCOL', config.directoryUri);
    if (response.statusCode == 201 ||
        response.statusCode == 200 ||
        response.statusCode == 400 ||
        response.statusCode == 405) {
      return;
    }
    if (response.statusCode == 409) {
      throw const WebDavException('远程目录的上级目录不存在，请检查服务器地址或目录层级');
    }
    _ensureOk(response, action: '创建远程目录');
  }

  /// 连接测试：PROPFIND 目录。407/404 说明鉴权已通过但目录待创建，也算通。
  Future<void> testConnection() async {
    final http.Response response = await _send(
      'PROPFIND',
      config.directoryUri,
      headers: const <String, String>{'Depth': '0'},
    );
    if (response.statusCode == 404 || response.statusCode == 207) {
      return;
    }
    _ensureOk(
      response,
      allowStatusCodes: const <int>{200, 301, 302},
      action: '测试连接',
    );
  }

  Future<http.Response> _send(
    String method,
    Uri uri, {
    List<int>? body,
    String? contentType,
    Map<String, String>? headers,
  }) async {
    if (config.hasUnsupportedCredential) {
      throw const WebDavException(
        '账号或密码含有无法识别的字符，请改用英文 / 半角输入（全角 ＠ 已自动转换）',
      );
    }
    final http.Request request = http.Request(method, uri);
    request.headers['Authorization'] = _authorizationHeader;
    request.headers['User-Agent'] = 'ApexDrama-WebDAV/1.0';
    if (headers != null) {
      request.headers.addAll(headers);
    }
    if (contentType != null) {
      request.headers['Content-Type'] = contentType;
    }
    if (body != null) {
      request.bodyBytes = body;
    }
    try {
      final http.Response response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
      return response;
    } on TimeoutException {
      throw const WebDavException('连接超时，请检查网络或服务器地址');
    } on SocketException catch (error) {
      throw WebDavException('无法连接服务器：${error.message}');
    } on HandshakeException {
      throw const WebDavException('HTTPS 证书校验失败，请确认服务器地址正确');
    } on http.ClientException catch (error) {
      throw WebDavException('网络请求失败：${error.message}');
    }
  }

  /// 服务端错误时附带一小段响应体，便于定位（坚果云会返回文字说明）。
  String _bodySnippet(http.Response response) {
    try {
      final String text = utf8
          .decode(response.bodyBytes, allowMalformed: true)
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (text.isEmpty) {
        return '';
      }
      final String clipped = text.length > 320 ? text.substring(0, 320) : text;
      return '：$clipped';
    } catch (_) {
      return '';
    }
  }

  void _ensureOk(
    http.Response response, {
    Set<int> allowStatusCodes = const <int>{200, 201, 204},
    String action = 'WebDAV 请求',
  }) {
    final int code = response.statusCode;
    if (allowStatusCodes.contains(code)) {
      return;
    }
    if (kDebugMode) {
      debugPrint(
        'WebDAV $action → HTTP $code ${response.request?.url} ${response.body}',
      );
    }
    switch (code) {
      case 401:
        throw const WebDavException(
          '账号或密码不正确。坚果云请使用「应用密码」，不是网页登录密码',
          statusCode: 401,
        );
      case 403:
        throw const WebDavException('服务器拒绝访问，请检查账号权限或远程目录', statusCode: 403);
      case 507:
        throw const WebDavException('云盘空间不足，无法上传同步文件', statusCode: 507);
      default:
        throw WebDavException(
          '$action失败（HTTP $code）'
          '${response.request?.url.path ?? ''}${_bodySnippet(response)}',
          statusCode: code,
        );
    }
  }
}
