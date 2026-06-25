import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/facades/pick.dart';

void main() {
  group('Pick.saveFile null guard', () {
    test('throws ArgumentError when fileName is null', () {
      expect(
        () => Pick.saveFile(bytes: Uint8List.fromList([1, 2, 3])),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError when bytes is null', () {
      expect(() => Pick.saveFile(fileName: 'report.pdf'), throwsArgumentError);
    });

    test('throws ArgumentError when both are null', () {
      expect(() => Pick.saveFile(), throwsArgumentError);
    });
  });
}
