import 'dart:convert';
import 'dart:io';

import 'package:apexduanju/services/update_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UpdateManifest.latest', () {
    test('选出版本号最大的合法条目', () {
      final UpdateManifestEntry? entry = UpdateManifest.latest(
        <String, dynamic>{
          '1.4.0': <String, dynamic>{'date': '2026-11-17', 'notes': 'old'},
          '1.10.0': <String, dynamic>{'date': '2026-12-01', 'notes': 'new'},
          '1.9.9': <String, dynamic>{'date': '2026-11-20', 'notes': 'mid'},
          'bad': <String, dynamic>{'notes': 'ignored'},
        },
      );
      expect(entry?.version, '1.10.0');
      expect(entry?.notes, 'new');
      expect(entry?.publishedAt, DateTime(2026, 12, 1));
    });

    test('忽略缺 notes 或结构错误的条目', () {
      final UpdateManifestEntry? entry = UpdateManifest.latest(
        <String, dynamic>{
          '1.5.0': <String, dynamic>{'notes': 'ok'},
          '1.6.0': <String, dynamic>{'notes': '  '},
          '1.7.0': 'not-a-map',
        },
      );
      expect(entry?.version, '1.5.0');
    });

    test('没有合法条目返回 null', () {
      expect(UpdateManifest.latest(<String, dynamic>{}), isNull);
      expect(
        UpdateManifest.latest(<String, dynamic>{'bad': <String, dynamic>{}}),
        isNull,
      );
    });

    test('downloads 映射按平台读取', () {
      final UpdateManifestEntry? entry = UpdateManifest.latest(
        <String, dynamic>{
          '1.5.0': <String, dynamic>{
            'notes': 'x',
            'downloads': <String, dynamic>{
              'windows-x64': 'https://example.com/setup.exe',
            },
          },
        },
      );
      expect(
        entry?.downloadFor(windows: true),
        'https://example.com/setup.exe',
      );
      expect(entry?.downloadFor(windows: false), isNull);
    });
  });

  group('UpdateManifest.isNewerVersion', () {
    test('逐段数字比较，段数不足补 0', () {
      expect(UpdateManifest.isNewerVersion('1.10.0', '1.9.9'), isTrue);
      expect(UpdateManifest.isNewerVersion('1.0.1', '1.0'), isTrue);
      expect(UpdateManifest.isNewerVersion('1.0', '1.0.0'), isFalse);
      expect(UpdateManifest.isNewerVersion('1.0.0', '1.0.0'), isFalse);
      expect(UpdateManifest.isNewerVersion('0.9.9', '1.0.0'), isFalse);
    });
  });

  group('UpdateManifest.assetUrl', () {
    test('Windows 用 setup.exe，Android 用 arm64 APK', () {
      expect(
        UpdateManifest.assetUrl(
          owner: 'o',
          repo: 'r',
          version: '1.5.1',
          windows: true,
        ),
        'https://github.com/o/r/releases/download/v1.5.1/'
        'ApexDrama-1.5.1-windows-x64-setup.exe',
      );
      expect(
        UpdateManifest.assetUrl(
          owner: 'o',
          repo: 'r',
          version: '1.5.1',
          windows: false,
        ),
        'https://github.com/o/r/releases/download/v1.5.1/'
        'ApexDrama-v1.5.1-arm64-v8a.apk',
      );
    });
  });

  test('镜像列表包含 xget 与 jsDelivr 双节点', () {
    final List<String> urls = UpdateManifest.urls(owner: 'o', repo: 'r');
    expect(urls.first, 'https://xget.xi-xu.me/gh/o/r/raw/master/updates.json');
    expect(
      urls,
      contains('https://cdn.jsdelivr.net/gh/o/r@master/updates.json'),
    );
    expect(
      urls,
      contains('https://fastly.jsdelivr.net/gh/o/r@master/updates.json'),
    );
    expect(
      urls,
      contains('https://raw.githubusercontent.com/o/r/master/updates.json'),
    );
  });

  test('仓库 updates.json 可被解析出最新版本', () {
    final Map<String, dynamic> json = jsonDecode(
      File('updates.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final UpdateManifestEntry? entry = UpdateManifest.latest(json);
    expect(entry, isNotNull);
    expect(entry!.notes, isNotEmpty);
  });
}
