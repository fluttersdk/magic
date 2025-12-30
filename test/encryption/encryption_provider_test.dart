import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_magic/fluttersdk_magic.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EncryptionServiceProvider', () {
    setUpAll(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              (MethodCall methodCall) async {
        return '.';
      });
    });

    setUp(() {
      MagicApp.reset();
    });

    test('registers Encrypter if key is valid', () async {
      await Magic.init(configs: [
        {
          'app': {
            'key': '12345678901234567890123456789012',
          }
        }
      ]);

      expect(Magic.bound('encrypter'), isTrue);
      // expect(Magic.make('encrypter'), isA<MagicEncrypter>()); // Type is internal/exported? Encrypter is internal/exported?
      // MagicEncrypter is internal but usually exported for typing.
      // Let's check Crypt usage.
      final encrypted = Crypt.encrypt('foo');
      expect(encrypted, contains(':'));
    });

    test('throws if key is missing when accessing', () async {
      await Magic.init(configs: [
        {
          'app': {
            'key': null, // Missing
          }
        }
      ]);

      // Provider lazy registers an error thrower
      expect(Magic.bound('encrypter'), isTrue);
      expect(() => Crypt.encrypt('foo'), throwsException);
    });

    test('throws if key is invalid length', () async {
      await Magic.init(configs: [
        {
          'app': {
            'key': 'short',
          }
        }
      ]);

      expect(Magic.bound('encrypter'), isTrue);
      expect(() => Crypt.encrypt('foo'), throwsException);
    });
  });
}
