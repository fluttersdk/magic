import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/testing.dart';

void main() {
  // ---------------------------------------------------------------------------
  // 1. MagicTest.init() sets up clean container
  // ---------------------------------------------------------------------------

  group('MagicTest.init() sets up clean container', () {
    MagicTest.init();

    test('container is clean at start of first test', () {
      expect(() => Magic.make<Object>('nonexistent'), throwsA(anything));
    });
  });

  // ---------------------------------------------------------------------------
  // 2. MagicTest.init() provides test isolation
  // ---------------------------------------------------------------------------

  group('MagicTest.init() provides test isolation', () {
    MagicTest.init();

    test('first test — registers a binding', () {
      MagicApp.instance.bind('isolation_key', () => Object());

      expect(MagicApp.instance.bound('isolation_key'), isTrue);
    });

    test('second test — binding from first test is gone', () {
      expect(MagicApp.instance.bound('isolation_key'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. MagicTest.init() tearDown flushes
  // ---------------------------------------------------------------------------

  group('MagicTest.init() tearDown flushes', () {
    MagicTest.init();

    test('bindings registered during test are cleaned up after', () {
      MagicApp.instance.singleton('teardown_key', () => Object());

      expect(MagicApp.instance.bound('teardown_key'), isTrue);
      // Verification of cleanup happens implicitly when subsequent tests
      // run with a clean container — tested by the isolation group above.
    });
  });

  // ---------------------------------------------------------------------------
  // 4. MagicTest.boot() initializes Magic with configs
  // ---------------------------------------------------------------------------

  group('MagicTest.boot() initializes Magic with configs', () {
    setUp(() {
      MagicApp.reset();
      Magic.flush();
    });

    tearDown(() {
      Magic.flush();
    });

    test('boot() completes without error', () async {
      await expectLater(
        MagicTest.boot(configs: const [], envFileName: '.env.testing'),
        completes,
      );
    });

    test('boot() with default parameters completes', () async {
      MagicApp.reset();
      Magic.flush();

      await expectLater(MagicTest.boot(), completes);
    });

    test('boot() resets container before initializing', () async {
      // Pre-pollute the container
      MagicApp.instance.bind('stale_key', () => Object());

      await MagicTest.boot();

      // Container was reset before init — stale binding should be gone
      expect(MagicApp.instance.bound('stale_key'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Testing barrel — MagicTest importable from package:magic/testing.dart
  // ---------------------------------------------------------------------------

  group('Testing barrel — MagicTest importable', () {
    test('MagicTest type is accessible from testing barrel', () {
      expect(MagicTest, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // 6. Testing barrel — all fake classes importable
  // ---------------------------------------------------------------------------

  group('Testing barrel — all fake classes importable', () {
    test('FakeAuthManager is accessible', () {
      expect(FakeAuthManager, isNotNull);
    });

    test('FakeCacheManager is accessible', () {
      expect(FakeCacheManager, isNotNull);
    });

    test('FakeVaultService is accessible', () {
      expect(FakeVaultService, isNotNull);
    });

    test('FakeLogManager is accessible', () {
      expect(FakeLogManager, isNotNull);
    });

    test('FakeNetworkDriver is accessible', () {
      expect(FakeNetworkDriver, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // 7. MagicTest.init() resets Gate between tests
  // ---------------------------------------------------------------------------

  group('MagicTest.init() resets Gate between tests', () {
    MagicTest.init();

    test('first test: defines an ability', () {
      Gate.define('gate-isolation-key', (user, arguments) => true);

      expect(Gate.has('gate-isolation-key'), isTrue);
    });

    test('second test: ability from first test is gone', () {
      expect(Gate.has('gate-isolation-key'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // 8. MagicTest.loadTranslations() loads a catalogue for trans()
  // ---------------------------------------------------------------------------

  group('MagicTest.loadTranslations() loads a catalogue for trans()', () {
    MagicTest.init();

    test(
      'nested key resolves after loading a temp directory catalogue',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'magic_test_translations_',
        );
        addTearDown(() => tempDir.delete(recursive: true));

        final trFile = File('${tempDir.path}/tr.json');
        await trFile.writeAsString(
          jsonEncode({
            'a': {'b': 'merhaba'},
          }),
        );

        await MagicTest.loadTranslations('tr', directory: tempDir.path);

        expect(trans('a.b'), 'merhaba');
      },
    );

    test('the next test starts on the default locale again', () {
      expect(Lang.current.languageCode, 'en');
      expect(trans('a.b'), 'a.b');
    });
  });
}
