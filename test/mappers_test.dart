import 'package:apexduanju/data/mappers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('publishBadge', () {
    test('ISO 时间转为 MM-DD', () {
      expect(
        publishBadge('2026-11-10T16:04:04'),
        '11-10',
      );
    });

    test('空串返回 null（不显示角标）', () {
      expect(publishBadge(''), isNull);
    });

    test('无法解析时原样返回', () {
      expect(publishBadge('未知'), '未知');
    });
  });
}
