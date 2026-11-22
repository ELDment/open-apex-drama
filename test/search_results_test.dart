import 'package:apexduanju/models/drama.dart';
import 'package:apexduanju/models/search_results.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Drama _drama(String title) {
  return Drama(
    id: title,
    title: title,
    kind: '短剧',
    category: '短剧',
    tags: const <String>['短剧'],
    episodes: 10,
    rating: 0,
    viewers: '',
    description: '',
    coverColors: const <Color>[],
    episodeTitles: const <String>[],
  );
}

void main() {
  test('把标题命中的结果与猜你喜欢拆开并保持原顺序', () {
    final SearchResultGroups groups = groupSearchResults(
      <Drama>[
        _drama('总裁是我前女友'),
        _drama('离婚夜，季总的暗恋藏不住了'),
        _drama('总裁归来：从天桥开始'),
      ],
      '总裁',
    );

    expect(
      groups.matched.map((Drama d) => d.title).toList(),
      <String>['总裁是我前女友', '总裁归来：从天桥开始'],
    );
    expect(
      groups.suggested.map((Drama d) => d.title).toList(),
      <String>['离婚夜，季总的暗恋藏不住了'],
    );
  });

  test('匹配忽略大小写与空白', () {
    final SearchResultGroups groups = groupSearchResults(
      <Drama>[_drama('HOLD 住！我的老板'), _drama('别的剧')],
      ' hold 住 ',
    );

    expect(groups.matched.single.title, 'HOLD 住！我的老板');
    expect(groups.suggested.single.title, '别的剧');
  });

  test('全部命中时不产生猜你喜欢分组', () {
    final SearchResultGroups groups = groupSearchResults(
      <Drama>[_drama('闪婚老公是财阀')],
      '财阀',
    );

    expect(groups.matched, hasLength(1));
    expect(groups.suggested, isEmpty);
    expect(groups.hasSuggested, isFalse);
  });
}
