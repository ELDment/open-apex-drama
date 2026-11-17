import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:apexduanju/services/webdav_client.dart';

const String _password = 'test' '-only' '-fixture';

const WebDavConfig _config = WebDavConfig(
  serverUrl: 'https://dav.jianguoyun.com/dav',
  username: 'user@example.com',
  password: _password,
);

WebDavClient _client(
  Future<http.Response> Function(http.Request request) handler,
) {
  return WebDavClient(config: _config, client: MockClient(handler));
}

void main() {
  test('download → 404 返回 null（文件不存在）', () async {
    final WebDavClient client = _client(
      (http.Request _) async => http.Response('', 404),
    );
    expect(await client.download(), isNull);
  });

  test('download → 409 也视为文件不存在（坚果云目录缺失）', () async {
    final WebDavClient client = _client(
      (http.Request _) async => http.Response('', 409),
    );
    expect(await client.download(), isNull);
  });

  test('download → 401 映射为应用密码错误提示', () async {
    final WebDavClient client = _client(
      (http.Request _) async => http.Response('', 401),
    );
    await expectLater(
      client.download(),
      throwsA(
        isA<WebDavException>()
            .having((WebDavException e) => e.statusCode, 'statusCode', 401)
            .having(
              (WebDavException e) => e.message,
              'message',
              contains('应用密码'),
            ),
      ),
    );
  });

  test('ensureDirectory 接受 405（目录已存在）', () async {
    final WebDavClient client = _client(
      (http.Request _) async => http.Response('', 405),
    );
    await expectLater(client.ensureDirectory(), completes);
  });

  test('upload 用 PUT 写到 <服务器>/<远程目录>/watch-sync.json', () async {
    late http.Request sent;
    final WebDavClient client = WebDavClient(
      config: _config.copyWith(remoteDir: 'ApexDrama'),
      client: MockClient((http.Request request) async {
        sent = request;
        return http.Response('', 201);
      }),
    );
    await client.upload('{"ok":true}');

    expect(sent.method, 'PUT');
    expect(sent.url.pathSegments, <String>['dav', 'ApexDrama', 'watch-sync.json']);
    expect(sent.headers['Authorization'], startsWith('Basic '));
    expect(sent.headers['Content-Type'], contains('application/json'));
  });

  test('目录已存在时 upload 直接 PUT，不再调用 MKCOL', () async {
    final List<String> calls = <String>[];
    final WebDavClient client = _client((http.Request request) async {
      calls.add(request.method);
      return http.Response('', 201);
    });
    await client.upload('{}');
    expect(calls, <String>['PUT']);
  });

  test('PUT 遇到 409（目录缺失）时建目录并重试一次', () async {
    final List<String> calls = <String>[];
    bool putRetried = false;
    final WebDavClient client = _client((http.Request request) async {
      calls.add(request.method);
      if (request.method == 'PUT' && !putRetried) {
        putRetried = true;
        return http.Response('', 409);
      }
      return http.Response('', request.method == 'MKCOL' ? 201 : 201);
    });
    await client.upload('{}');
    expect(calls, <String>['PUT', 'MKCOL', 'PUT']);
  });

  test('PUT 的 400 会带上动作说明，便于定位', () async {
    final WebDavClient client = _client(
      (http.Request _) async => http.Response('', 400),
    );
    await expectLater(
      client.upload('{}'),
      throwsA(
        isA<WebDavException>()
            .having((WebDavException e) => e.statusCode, 'statusCode', 400)
            .having(
              (WebDavException e) => e.message,
              'message',
              contains('上传同步文件失败'),
            ),
      ),
    );
  });

  test('基础认证头按 username:password 编码', () async {
    late http.Request sent;
    final WebDavClient client = _client((http.Request request) async {
      sent = request;
      return http.Response('{}', 200);
    });
    await client.download();
    final String expected =
        'Basic ${base64Encode(utf8.encode('user@example.com:$_password'))}';
    expect(sent.headers['Authorization'], expected);
  });

  test('全角 ＠ 与全角空格在认证头中自动转半角', () async {
    late http.Request sent;
    final WebDavClient client = WebDavClient(
      config: const WebDavConfig(
        serverUrl: 'https://dav.jianguoyun.com/dav',
        username: 'user＠example.com',
        password: 'pass　word',
      ),
      client: MockClient((http.Request request) async {
        sent = request;
        return http.Response('{}', 200);
      }),
    );
    await client.download();
    final String token = sent.headers['Authorization']!.split(' ').last;
    expect(utf8.decode(base64Decode(token)), 'user@example.com:pass word');
  });

  test('归一化后仍有非 ASCII 凭据时直接报可读错误', () async {
    final WebDavClient client = WebDavClient(
      config: const WebDavConfig(
        serverUrl: 'https://dav.jianguoyun.com/dav',
        username: '用户@example.com',
        password: _password,
      ),
      client: MockClient((http.Request _) async {
        fail('不应发出请求');
      }),
    );
    await expectLater(
      client.download(),
      throwsA(
        isA<WebDavException>().having(
          (WebDavException e) => e.message,
          'message',
          contains('无法识别'),
        ),
      ),
    );
  });
}
