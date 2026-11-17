import 'dart:io';

import 'package:apexduanju/services/update_downloader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late HttpServer server;
  late String assetUrl;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('update_downloader_');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    assetUrl = 'http://127.0.0.1:${server.port}/ApexDrama-v9.9.9-arm64-v8a.apk';
    server.listen((HttpRequest request) {
      final List<int> body = 'fake-apk-content'.codeUnits;
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentLength = body.length
        ..add(body);
      request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('下载完成后写正式文件，二次调用直接复用不再请求', () async {
    final String? first = await UpdateDownloader.download(
      assetUrl,
      directory: tempDir,
      urls: <String>[assetUrl],
    );
    expect(first, isNotNull);
    expect(File(first!).readAsStringSync(), 'fake-apk-content');
    // 完成后不应残留 .part
    expect(File('$first.part').existsSync(), isFalse);

    // 关掉服务端，若仍去下载会失败；能拿到路径说明走了复用分支。
    await server.close(force: true);
    final String? second = await UpdateDownloader.download(
      assetUrl,
      directory: tempDir,
      urls: <String>[assetUrl],
    );
    expect(second, first);
    expect(File(second!).readAsStringSync(), 'fake-apk-content');
  });

  test('下载失败不留下可复用的正式文件', () async {
    final String badUrl = 'http://127.0.0.1:1/ApexDrama-v9.9.9-arm64-v8a.apk';
    final String? path = await UpdateDownloader.download(
      badUrl,
      directory: tempDir,
      urls: <String>[badUrl],
    );
    expect(path, isNull);
    expect(tempDir.listSync(), isEmpty);
  });
}
