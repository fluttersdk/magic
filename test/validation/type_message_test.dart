import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

void main() {
  group('Type-Based Validation Messages', () {
    test('Min rule returns correct message for String', () {
      final rule = Min(5);
      expect(rule.passes('test', 'abc', {}), false);
      expect(rule.message(), 'validation.min.string');
    });

    test('Min rule returns correct message for Numeric', () {
      final rule = Min(5);
      expect(rule.passes('test', 3, {}), false);
      expect(rule.message(), 'validation.min.numeric');
    });

    test('Min rule returns correct message for List', () {
      final rule = Min(3);
      expect(rule.passes('test', [1, 2], {}), false);
      expect(rule.message(), 'validation.min.list');
    });

    test('Max rule returns correct message for String', () {
      final rule = Max(5);
      expect(rule.passes('test', 'abcdef', {}), false);
      expect(rule.message(), 'validation.max.string');
    });

    test('Max rule returns correct message for Numeric', () {
      final rule = Max(5);
      expect(rule.passes('test', 10, {}), false);
      expect(rule.message(), 'validation.max.numeric');
    });

    test('Max rule returns correct message for List', () {
      final rule = Max(2);
      expect(rule.passes('test', [1, 2, 3], {}), false);
      expect(rule.message(), 'validation.max.list');
    });
  });
}
