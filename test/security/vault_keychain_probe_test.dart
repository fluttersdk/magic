import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

const MethodChannel _channel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

/// The two macOS keychains behind `flutter_secure_storage`'s method channel.
///
/// An item lives in exactly one of them and there is no migration, which is
/// how the real keychains behave. When [entitled] is false the data
/// protection one answers like an unsigned build: a read finds nothing
/// (`errSecItemNotFound`, measured) while a write or a delete fails with
/// `errSecMissingEntitlement` (-34018, measured).
final class _Keychains {
  _Keychains({required this.entitled});

  final bool entitled;
  final Map<String, String> dataProtection = <String, String>{};
  final Map<String, String> legacy = <String, String>{};
  final List<({String method, String key, bool dataProtection})> calls =
      <({String method, String key, bool dataProtection})>[];

  /// Fails the next write once with this status, whichever keychain it hits.
  int? failNextWriteWith;

  List<({String method, String key, bool dataProtection})> get probeWrites =>
      calls.where((c) => c.method == 'write' && c.key != 'api_token').toList();

  Future<Object?> handle(MethodCall call) async {
    final args = call.arguments as Map<Object?, Object?>;
    final options = args['options'] as Map<Object?, Object?>;
    // Only the macOS options carry this key; every other platform omits it.
    final bool useDataProtection =
        options['usesDataProtectionKeychain'] == 'true';
    final String key = (args['key'] as String?) ?? '';

    calls.add((
      method: call.method,
      key: key,
      dataProtection: useDataProtection,
    ));

    final store = useDataProtection ? dataProtection : legacy;
    final bool refused = useDataProtection && !entitled;

    switch (call.method) {
      case 'write':
        final int? status = failNextWriteWith;
        if (status != null) {
          failNextWriteWith = null;
          throw _statusError(status);
        }
        if (refused) throw _statusError(-34018);
        store[key] = args['value'] as String;
        return null;
      case 'read':
        return store[key];
      case 'delete':
        if (refused) throw _statusError(-34018);
        store.remove(key);
        return null;
      case 'deleteAll':
        if (refused) throw _statusError(-34018);
        store.clear();
        return null;
    }
    throw MissingPluginException(call.method);
  }

  PlatformException _statusError(int status) => PlatformException(
    code: 'Unexpected security result code',
    message: 'Code: $status, Message: keychain refused',
    details: status,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLogManager log;

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    log = Log.fake();
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  _Keychains install({required bool entitled}) {
    final keychains = _Keychains(entitled: entitled);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, keychains.handle);
    return keychains;
  }

  group('keychain probe on macOS', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.macOS);

    test('an unsigned build stores in the legacy keychain', () async {
      final keychains = install(entitled: false);
      final vault = MagicVaultService();

      await vault.put('api_token', 'secret');

      expect(await vault.get('api_token'), 'secret');
      expect(vault.usesDataProtectionKeychain, isFalse);
      expect(keychains.legacy['api_token'], 'secret');
      expect(keychains.dataProtection, isEmpty);
    });

    test('the fallback is named once in the log', () async {
      install(entitled: false);
      final vault = MagicVaultService();

      await vault.put('api_token', 'one');
      await vault.put('api_token', 'two');

      final warnings = log.entries.where((e) => e.level == 'warning').toList();
      expect(warnings, hasLength(1));
      expect(warnings.single.message, contains('keychain-access-groups'));
    });

    test('a signed build keeps the data protection keychain', () async {
      final keychains = install(entitled: true);
      final vault = MagicVaultService();

      await vault.put('api_token', 'secret');

      expect(vault.usesDataProtectionKeychain, isTrue);
      expect(keychains.dataProtection, <String, String>{'api_token': 'secret'});
      expect(keychains.legacy, isEmpty);
      log.assertNothingLogged();
    });

    test('the probe leaves no item behind', () async {
      final keychains = install(entitled: true);

      await MagicVaultService().put('api_token', 'secret');

      expect(keychains.dataProtection.keys, <String>['api_token']);
    });

    test('the probe runs once however many operations follow', () async {
      final keychains = install(entitled: false);
      final vault = MagicVaultService();

      await Future.wait(<Future<void>>[
        vault.put('api_token', 'a'),
        vault.put('api_token', 'b'),
        vault.get('api_token'),
      ]);
      await vault.get('api_token');

      expect(keychains.probeWrites, hasLength(1));
    });

    test('a read before any write still resolves the keychain', () async {
      final keychains = install(entitled: false);
      final vault = MagicVaultService();

      expect(await vault.get('api_token'), isNull);

      expect(vault.usesDataProtectionKeychain, isFalse);
      expect(keychains.probeWrites, hasLength(1));
    });

    test('an explicit true is honoured without a probe', () async {
      final keychains = install(entitled: false);
      final vault = MagicVaultService(macOsUsesDataProtectionKeychain: true);

      await expectLater(
        vault.put('api_token', 'secret'),
        throwsA(
          isA<MagicVaultException>().having(
            (e) => e.isMissingEntitlement,
            'isMissingEntitlement',
            isTrue,
          ),
        ),
      );

      expect(keychains.probeWrites, isEmpty);
      expect(vault.usesDataProtectionKeychain, isTrue);
    });

    test('an explicit false skips the probe', () async {
      final keychains = install(entitled: true);
      final vault = MagicVaultService(macOsUsesDataProtectionKeychain: false);

      await vault.put('api_token', 'secret');

      expect(keychains.probeWrites, isEmpty);
      expect(keychains.legacy['api_token'], 'secret');
      expect(vault.usesDataProtectionKeychain, isFalse);
    });

    test(
      'another failure surfaces and the next operation probes again',
      () async {
        final keychains = install(entitled: true)..failNextWriteWith = -25308;
        final vault = MagicVaultService();

        await expectLater(
          vault.put('api_token', 'secret'),
          throwsA(
            isA<MagicVaultException>().having(
              (e) => e.statusCode,
              'statusCode',
              -25308,
            ),
          ),
        );
        expect(vault.usesDataProtectionKeychain, isNull);

        await vault.put('api_token', 'secret');

        expect(vault.usesDataProtectionKeychain, isTrue);
        expect(keychains.dataProtection['api_token'], 'secret');
      },
    );

    test('flush and remove run on the resolved keychain', () async {
      final keychains = install(entitled: false);
      final vault = MagicVaultService();

      await vault.put('api_token', 'secret');
      await vault.remove('api_token');
      await vault.put('api_token', 'secret');
      await vault.flush();

      expect(keychains.legacy, isEmpty);
    });
  });

  group('off macOS', () {
    test('no probe runs and the service just works', () async {
      final keychains = install(entitled: false);
      final vault = MagicVaultService();

      await vault.put('api_token', 'secret');

      expect(keychains.probeWrites, isEmpty);
      expect(vault.usesDataProtectionKeychain, isNull);
      expect(await vault.get('api_token'), 'secret');
    });
  });

  group('MagicVaultException', () {
    test('reads the platform status from the wrapped error', () {
      final error = MagicVaultException(
        'Failed to write to vault',
        PlatformException(
          code: 'Unexpected security result code',
          details: -34018,
        ),
      );

      expect(error.statusCode, -34018);
      expect(error.isMissingEntitlement, isTrue);
    });

    test('has no status when the wrapped error carries none', () {
      expect(MagicVaultException('plain').statusCode, isNull);
      expect(MagicVaultException('plain').isMissingEntitlement, isFalse);
      expect(
        MagicVaultException(
          'Failed to read from vault',
          PlatformException(code: 'x', details: 'not a number'),
        ).statusCode,
        isNull,
      );
    });

    test('a missing entitlement is named in the service message', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      install(entitled: false);
      final vault = MagicVaultService(macOsUsesDataProtectionKeychain: true);

      await expectLater(
        vault.put('api_token', 'secret'),
        throwsA(
          isA<MagicVaultException>().having(
            (e) => e.message,
            'message',
            contains('keychain-access-groups'),
          ),
        ),
      );
    });
  });
}
