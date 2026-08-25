import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/encryption/exceptions.dart';
import 'package:magic/src/encryption/magic_encrypter.dart';

/// Pins what `MagicEncrypter` actually guarantees, because its docstring used
/// to claim the MAC that Laravel's `Encrypter` has and this one does not.
///
/// These tests assert the WEAKNESS on purpose. They are not approval of it:
/// they are what makes the corrected documentation checkable, and they are the
/// tests that would go red the day a MAC is added, which is exactly when
/// someone should be forced to read them.
void main() {
  final encrypter = MagicEncrypter('0123456789abcdef0123456789abcdef');

  group('what the cipher does provide', () {
    test('a round trip returns the value', () {
      expect(encrypter.decrypt(encrypter.encrypt('hello')), 'hello');
    });

    test('the same value twice produces different payloads', () {
      // A fresh random IV per call, so a repeated value is not a repeated
      // ciphertext.
      expect(encrypter.encrypt('same'), isNot(encrypter.encrypt('same')));
    });

    test('a payload from another key does not decrypt', () {
      final other = MagicEncrypter('fedcba9876543210fedcba9876543210');
      expect(
        () => encrypter.decrypt(other.encrypt('secret')),
        throwsA(isA<MagicDecryptException>()),
      );
    });

    test('a malformed payload is refused rather than guessed at', () {
      expect(
        () => encrypter.decrypt('not-a-payload'),
        throwsA(isA<MagicDecryptException>()),
      );
      expect(
        () => encrypter.decrypt('a:b:c'),
        throwsA(isA<MagicDecryptException>()),
      );
    });
  });

  group('what it does NOT provide, which the docs now say out loud', () {
    test('flipping a bit in the IV silently changes the plaintext', () {
      // The concrete shape of CBC malleability. The payload still decrypts,
      // no error is raised, and the caller receives a value an attacker chose
      // part of. A MAC over iv + ciphertext is what would refuse this.
      final payload = encrypter.encrypt('transfer 100 to alice');
      final parts = payload.split(':');
      final iv = base64.decode(parts[0]);

      iv[0] = iv[0] ^ 0x01;
      final tampered = '${base64.encode(iv)}:${parts[1]}';

      final out = encrypter.decrypt(tampered);

      expect(
        out,
        isNot('transfer 100 to alice'),
        reason: 'the first block changed, predictably',
      );
      expect(
        out.length,
        'transfer 100 to alice'.length,
        reason: 'and it decrypted cleanly, with nothing to flag it',
      );
    });

    test('the payload carries no third component to verify', () {
      // If this ever becomes 3, a MAC has been added and the class and facade
      // docs, which currently promise the opposite, have to be rewritten.
      expect(encrypter.encrypt('x').split(':'), hasLength(2));
    });
  });
}
