import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// Pins that [MagicDecryptException] reaches a consumer through
/// `package:magic/magic.dart` alone, the type `Crypt.decrypt`'s own doc
/// comment tells a caller to catch.
void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });

  tearDown(() {
    Magic.flush();
  });

  test('Crypt.decrypt throws a catchable MagicDecryptException', () async {
    Config.set('app.key', '12345678901234567890123456789012');
    await Magic.register(EncryptionServiceProvider(Magic.app));
    await Magic.boot();

    expect(
      () => Crypt.decrypt('not-a-payload'),
      throwsA(isA<MagicDecryptException>()),
    );
  });
}
