import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/encryption/magic_encrypter.dart';
import 'package:magic/src/encryption/exceptions.dart';

void main() {
  group('MagicEncrypter', () {
    const validKey = '12345678901234567890123456789012'; // 32 chars

    test('throws if key is not 32 chars', () {
      expect(() => MagicEncrypter('short'), throwsException);
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
