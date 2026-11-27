import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apexduanju/models/drama.dart';
import 'package:apexduanju/services/cover_cache.dart';
import 'package:apexduanju/widgets/poster_artwork.dart';

/// 1x1 透明 PNG，足够让 ImageProvider 成功解码。
final List<int> _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
  'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// 同步写一张临时 PNG。widget 测试默认跑在假时钟里，异步文件 IO 不会回来。
File _writePng(String name) {
  final File file = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}'
    'apex_cover_$name.png',
  );
  file.writeAsBytesSync(_pngBytes, flush: true);
  addTearDown(file.delete);
  return file;
}

/// 只记录请求并返回固定文件的取图函数，不触磁盘缓存实现。
Stream<File> Function(String url, String key) _recordingFetch({
  List<(String url, String key)>? requests,
  Object? failWith,
}) {
  return (String url, String key) async* {
    requests?.add((url, key));
    if (failWith != null) {
      throw failWith;
    }
    yield _writePng('${identityHashCode(requests)}_${requests?.length}');
  };
}

/// 当前显示的封面文件路径；按宽度解码时外层会包一层 ResizeImage。
String _shownPath(WidgetTester tester) {
  final Image image = tester.widget<Image>(find.byType(Image));
  ImageProvider provider = image.image;
  if (provider is ResizeImage) {
    provider = provider.imageProvider;
  }
  return (provider as FileImage).file.path;
}

/// 在真实时钟与假时钟之间来回推几轮：读文件、解码是真实 IO，回调要等真实
/// 时间，回调之后的微任务又要靠 pump 冲刷。
Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 5; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await tester.pump();
  }
}

void _useCoverCache(Stream<File> Function(String url, String key) fetch) {
  final CoverCache original = CoverCache.instance;
  CoverCache.instance = CoverCache.forTesting(fetch);
  addTearDown(() => CoverCache.instance = original);
}

Drama _drama({String id = 's1', String coverUrl = 'https://cdn/a.png'}) {
  return Drama(
    id: id,
    title: '测试剧',
    kind: '短剧',
    category: '都市',
    tags: const <String>[],
    episodes: 1,
    rating: 9.0,
    viewers: '1万',
    description: '',
    coverColors: const <Color>[Colors.red, Colors.blue, Colors.green],
    episodeTitles: const <String>[],
    coverUrl: coverUrl,
  );
}

void main() {
  testWidgets('封面缓存键用剧集 ID，不用带签名的地址', (WidgetTester tester) async {
    final List<(String url, String key)> requests = <(String, String)>[];
    _useCoverCache(_recordingFetch(requests: requests));

    await tester.pumpWidget(
      MaterialApp(
        home: PosterArtwork(drama: _drama(coverUrl: 'https://cdn/a?sig=1')),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: PosterArtwork(drama: _drama(coverUrl: 'https://cdn/a?sig=2')),
      ),
    );
    await tester.pump();

    expect(
      requests.map(((String url, String key) r) => r.$2).toList(),
      <String>['cover:s1', 'cover:s1'],
    );
  });

  testWidgets('缓存读取失败时静默回落渐变占位，不抛异常', (WidgetTester tester) async {
    _useCoverCache(_recordingFetch(failWith: const SocketException('断网')));

    await tester.pumpWidget(MaterialApp(home: PosterArtwork(drama: _drama())));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('过期时先显示旧封面，新封面到了再替换', (WidgetTester tester) async {
    // 整段放真实时钟里跑：读文件、解码是真实 IO，假时钟下永远不完成，
    // 图片文件也会一直被占用。
    await tester.runAsync(() async {
      final StreamController<File> stream = StreamController<File>();
      addTearDown(stream.close);
      _useCoverCache((_, _) => stream.stream);
      final File oldFile = _writePng('old');
      final File newFile = _writePng('new');

      await tester.pumpWidget(
        MaterialApp(home: PosterArtwork(drama: _drama())),
      );
      stream.add(oldFile);
      await _settle(tester);
      expect(_shownPath(tester), oldFile.path);

      stream.add(newFile);
      await _settle(tester);
      expect(_shownPath(tester), newFile.path);

      // 重新下载失败：已经显示的封面保持不动，不闪回占位图。
      stream.addError(const SocketException('断网'));
      await _settle(tester);
      expect(_shownPath(tester), newFile.path);
      expect(tester.takeException(), isNull);

      // Windows 上图片文件被读取器占用，组件销毁、解码收尾后才能删。
      await tester.pumpWidget(const SizedBox());
      await _settle(tester);
    });
  });
}
