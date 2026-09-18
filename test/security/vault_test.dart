import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

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

  group('macOS keychain choice', () {
    tearDown(() {
      Magic.flush();
      Config.set('security', <String, dynamic>{});
    });

    test('defaults to the data protection keychain', () {
      // The default has to match `flutter_secure_storage`'s own
      // (`macos_options.dart:24`), because there is no migration between
      // the two keychains: a default that flipped would leave every item an
      // existing macOS consumer had already stored unreachable, and a
      // missing item is indistinguishable from one never written.
      expect(MagicVaultService().macOsUsesDataProtectionKeychain, isTrue);
    });

    test('takes the constructor argument when one is given', () {
      expect(
        MagicVaultService(
          macOsUsesDataProtectionKeychain: false,
        ).macOsUsesDataProtectionKeychain,
        isFalse,
      );
    });

    test('the provider reads the config key', () {
      Config.set('security', <String, dynamic>{
        'vault': <String, dynamic>{'macos_data_protection_keychain': false},
      });

      VaultServiceProvider(Magic.app).register();

      expect(
        Magic.app
            .make<MagicVaultService>('vault')
            .macOsUsesDataProtectionKeychain,
        isFalse,
      );
    });

    test('the provider defaults to true when the config key is absent', () {
      VaultServiceProvider(Magic.app).register();

      expect(
        Magic.app
            .make<MagicVaultService>('vault')
            .macOsUsesDataProtectionKeychain,
        isTrue,
      );
    });

    test(
      'the config map doc/security/vault.md documents reaches the provider',
      () {
        // Byte for byte the snippet on that page, merged the way `Magic.init`
        // merges a `configFactories` entry: verbatim, deriving no domain name
        // from anywhere (`application.dart:115-118`). That is the whole point
        // of this test and the first two versions of it both missed, in the
        // same way, one level apart. The page first showed the file without
        // showing it handed to `Magic.init`; then it showed that and the map
        // was missing its `'security'` domain key, and THIS TEST supplied the
        // wrapper itself, so it discriminated on the dotted path rather than
        // on the documented file and could not fail for the documented reason.
        //
        // So: no wrapper here, ever. Whatever this map has to be for the test
        // to pass is exactly what the page has to show.
        final Map<String, dynamic> securityConfig = <String, dynamic>{
          'security': <String, dynamic>{
            'vault': <String, dynamic>{'macos_data_protection_keychain': false},
          },
        };

        Config.merge(securityConfig);
        VaultServiceProvider(Magic.app).register();

        expect(
          Magic.app
              .make<MagicVaultService>('vault')
              .macOsUsesDataProtectionKeychain,
          isFalse,
        );
      },
    );
  });
}
