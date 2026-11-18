import 'dart:convert';
import 'dart:io';

import 'package:apexduanju/services/update_manifest.dart';
import 'package:apexduanju/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late HttpServer server;
  late String base;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}';
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test('API 失败时从 updates.json 兜底并拼出下载地址', () async {
    server.listen((HttpRequest request) {
      if (request.uri.path == '/latest') {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.close();
        return;
      }
      final String body = jsonEncode(<String, dynamic>{
        '1.5.1': <String, dynamic>{'date': '2026-11-19', 'notes': '## 国内镜像兜底'},
        '1.5.0': <String, dynamic>{'date': '2026-11-18', 'notes': 'old'},
      });
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(body);
      request.response.close();
    });

    final UpdateInfo? info = await UpdateService.check(
      '1.5.0',
      useCache: false,
      apiUrl: '$base/latest',
      manifestUrls: <String>['$base/updates.json'],
    );

    expect(info, isNotNull);
    expect(info!.version, '1.5.1');
    expect(info.notes, '## 国内镜像兜底');
    expect(
      info.downloadUrl,
      UpdateManifest.assetUrl(
        owner: 'Sxuan-Coder',
        repo: 'open-apex-drama',
        version: '1.5.1',
        windows: Platform.isWindows,
      ),
    );
  });

  test('清单可达但已是最新时返回 null，不抛限流错误', () async {
    server.listen((HttpRequest request) {
      if (request.uri.path == '/latest') {
        request.response.statusCode = HttpStatus.forbidden;
        request.response.close();
        return;
      }
      final String body = jsonEncode(<String, dynamic>{
        '1.5.0': <String, dynamic>{'notes': 'same'},
      });
      request.response
        ..statusCode = HttpStatus.ok
        ..write(body);
      request.response.close();
    });

    final UpdateInfo? info = await UpdateService.check(
      '1.5.0',
      useCache: false,
      apiUrl: '$base/latest',
      manifestUrls: <String>['$base/updates.json'],
    );

    expect(info, isNull);
  });

  test('高版本写下的「已是最新」缓存不会短路低版本的检查', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'update.checkedAt': DateTime.now().millisecondsSinceEpoch,
      'update.version': '1.5.0',
    });
    server.listen((HttpRequest request) {
      final String body = jsonEncode(<String, dynamic>{
        'tag_name': 'v1.5.0',
        'body': 'notes',
        'published_at': '2026-11-18T06:55:11Z',
        'assets': <Map<String, String>>[
          <String, String>{
            'name': 'ApexDrama-v1.5.0-arm64-v8a.apk',
            'browser_download_url': 'https://example.com/a.apk',
          },
          <String, String>{
            'name': 'ApexDrama-1.5.0-windows-x64-setup.exe',
            'browser_download_url': 'https://example.com/setup.exe',
          },
        ],
      });
      request.response
        ..statusCode = HttpStatus.ok
        ..write(body);
      request.response.close();
    });

    // 1.4.0 不应被 1.5.0 写下的「已是最新」标记挡住，应重新检查并
    // 发现 1.5.0。
    final UpdateInfo? info = await UpdateService.check(
      '1.4.0',
      apiUrl: '$base/latest',
      manifestUrls: <String>['$base/updates.json'],
    );
    expect(info?.version, '1.5.0');
  });

  test('API 与清单都失败时抛出 UpdateException', () async {
    server.listen((HttpRequest request) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.close();
    });

    await expectLater(
      UpdateService.check(
        '1.5.0',
        useCache: false,
        apiUrl: '$base/latest',
        manifestUrls: <String>['$base/updates.json'],
      ),
      throwsA(isA<UpdateException>()),
    );
  });
}
