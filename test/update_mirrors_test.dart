import 'package:apexduanju/services/update_mirrors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const String asset =
      'https://github.com/o/r/releases/download/v1.5.0/ApexDrama-v1.5.0-arm64-v8a.apk';

  group('UpdateMirrors.candidates', () {
    test('默认顺序：gh-proxy → xget → ghfast → 官方直链', () {
      expect(UpdateMirrors.candidates(asset), <String>[
        'https://gh-proxy.com/$asset',
        'https://xget.xi-xu.me/gh/o/r/releases/download/v1.5.0/ApexDrama-v1.5.0-arm64-v8a.apk',
        'https://ghfast.top/$asset',
        asset,
      ]);
    });

    test('测速顺序优先，未列出的镜像补在末尾', () {
      expect(
        UpdateMirrors.candidates(asset, order: <String>['gh-proxy']),
        <String>[
          'https://gh-proxy.com/$asset',
          'https://xget.xi-xu.me/gh/o/r/releases/download/v1.5.0/ApexDrama-v1.5.0-arm64-v8a.apk',
          'https://ghfast.top/$asset',
          asset,
        ],
      );
    });

    test('未知镜像 id 被忽略', () {
      final List<String> urls = UpdateMirrors.candidates(
        asset,
        order: <String>['unknown'],
      );
      expect(urls.first, startsWith('https://gh-proxy.com/'));
      expect(urls.last, asset);
    });

    test('非 GitHub 地址不生成 xget 候选', () {
      const String direct = 'https://example.com/ApexDrama.apk';
      expect(UpdateMirrors.candidates(direct), <String>[
        'https://gh-proxy.com/$direct',
        'https://ghfast.top/$direct',
        direct,
      ]);
    });
  });
}
