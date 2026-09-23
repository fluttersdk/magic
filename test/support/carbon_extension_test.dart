import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/support/carbon_extension.dart';

void main() {
  group('isSameDayAs', () {
    test('is true for two moments on one calendar day', () {
      expect(
        DateTime(2024, 6, 20, 9).isSameDayAs(DateTime(2024, 6, 20, 23, 59)),
        isTrue,
      );
    });

    test('is false across midnight', () {
      expect(
        DateTime(2024, 6, 20, 23, 59).isSameDayAs(DateTime(2024, 6, 21)),
        isFalse,
      );
    });
  });
}
