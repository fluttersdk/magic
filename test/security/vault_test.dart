import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_magic/fluttersdk_magic.dart';

void main() {
  setUp(() {
    // Mock the platform channel for secure storage
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('MagicVaultService', () {
    late MagicVaultService vault;

    setUp(() {
      vault = MagicVaultService();
    });

    test('can store and retrieve values', () async {
      await vault.put('api_token', 'secret_abc');
      final value = await vault.get('api_token');

      expect(value, equals('secret_abc'));
    });

    test('returns null for non-existent keys', () async {
      final value = await vault.get('missing_key');
      expect(value, isNull);
    });

    test('can remove values', () async {
      await vault.put('token', 'xyz');
      await vault.remove('token');
      final value = await vault.get('token');

      expect(value, isNull);
    });

    test('can flush all values', () async {
      await vault.put('key1', 'val1');
      await vault.put('key2', 'val2');

      await vault.flush();

      expect(await vault.get('key1'), isNull);
      expect(await vault.get('key2'), isNull);
    });
  });

  group('Vault Facade', () {
    setUp(() async {
      // Bind the service to the container
      Magic.app.singleton('vault', () => MagicVaultService());
    });

    tearDown(() {
      Magic.flush();
    });

    test('facade proxies calls to service', () async {
      await Vault.put('facade_key', 'facade_val');
      final value = await Vault.get('facade_key');

      expect(value, equals('facade_val'));

      await Vault.delete('facade_key');
      expect(await Vault.get('facade_key'), isNull);
    });
  });
}
