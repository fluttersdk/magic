import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/encryption/magic_encrypter.dart';
import 'package:magic/src/encryption/exceptions.dart';

void main() {
  group('MagicEncrypter', () {
    const validKey = '12345678901234567890123456789012'; // 32 chars

    test('throws if key is not 32 chars', () {
      expect(() => MagicEncrypter('short'), throwsException);
    });

    group('fromAppKey', () {
      test('accepts a raw 32-character key and round-trips', () {
        final encrypter = MagicEncrypter.fromAppKey(validKey);
        final cipher = encrypter.encrypt('hello');
        expect(encrypter.decrypt(cipher), 'hello');
      });

      test(
        'accepts a base64: key (magic key:generate format) and round-trips',
        () {
          // key:generate writes `base64:<base64 of 32 random bytes>`.
          final appKey = 'base64:${base64.encode(validKey.codeUnits)}';
          final encrypter = MagicEncrypter.fromAppKey(appKey);
          final cipher = encrypter.encrypt('hello');
          expect(encrypter.decrypt(cipher), 'hello');
        },
      );

      test('throws when a base64: key does not decode to 32 bytes', () {
        final shortKey = 'base64:${base64.encode(<int>[1, 2, 3])}';
        expect(() => MagicEncrypter.fromAppKey(shortKey), throwsException);
      });

      test(
        'throws an actionable error when the base64: value is malformed',
        () {
          expect(
            () => MagicEncrypter.fromAppKey('base64:###not-base64###'),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains('not valid base64'),
              ),
            ),
          );
        },
      );
    });

    test('encrypts and decrypts values', () {
      final encrypter = MagicEncrypter(validKey);
      final original = 'Hello World';

      final encrypted = encrypter.encrypt(original);
      expect(encrypted, isNot(original));
      expect(encrypted, contains(':'));

      final decrypted = encrypter.decrypt(encrypted);
      expect(decrypted, original);
    });

    test('generates different outputs for same input (Random IV)', () {
      final encrypter = MagicEncrypter(validKey);
      final val1 = encrypter.encrypt('secret');
      final val2 = encrypter.encrypt('secret');

      expect(val1, isNot(val2));
    });

    test('throws MagicDecryptException on invalid payload', () {
      final encrypter = MagicEncrypter(validKey);
      expect(
        () => encrypter.decrypt('invalid_base64:garbage'),
        throwsA(isA<MagicDecryptException>()),
      );
    });
  });
}
