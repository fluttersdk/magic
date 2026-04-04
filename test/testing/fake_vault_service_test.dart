import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });

  group('FakeVaultService - basic operations', () {
    late FakeVaultService vault;

    setUp(() {
      vault = FakeVaultService();
    });

    test('put stores a value', () async {
      await vault.put('key', 'value');
      expect(await vault.get('key'), equals('value'));
    });

    test('get returns null for missing key', () async {
      expect(await vault.get('missing'), isNull);
    });

    test('remove deletes a stored value', () async {
      await vault.put('key', 'value');
      await vault.remove('key');
      expect(await vault.get('key'), isNull);
    });

    test('flush clears all stored values', () async {
      await vault.put('key1', 'val1');
      await vault.put('key2', 'val2');
      await vault.flush();
      expect(await vault.get('key1'), isNull);
      expect(await vault.get('key2'), isNull);
    });
  });

  group('FakeVaultService - initial values', () {
    test('constructor pre-populates store from initial values', () async {
      final vault = FakeVaultService({'token': 'abc123', 'user_id': '42'});
      expect(await vault.get('token'), equals('abc123'));
      expect(await vault.get('user_id'), equals('42'));
    });

    test('initial values can be overwritten', () async {
      final vault = FakeVaultService({'token': 'old'});
      await vault.put('token', 'new');
      expect(await vault.get('token'), equals('new'));
    });
  });

  group('FakeVaultService - assertions', () {
    late FakeVaultService vault;

    setUp(() {
      vault = FakeVaultService();
    });

    test('assertWritten passes when key was written', () async {
      await vault.put('token', 'abc');
      expect(() => vault.assertWritten('token'), returnsNormally);
    });

    test('assertWritten throws when key was not written', () {
      expect(
        () => vault.assertWritten('missing'),
        throwsA(isA<AssertionError>()),
      );
    });

    test('assertDeleted passes when key was deleted', () async {
      await vault.put('key', 'val');
      await vault.remove('key');
      expect(() => vault.assertDeleted('key'), returnsNormally);
    });

    test('assertDeleted throws when key was not deleted', () {
      expect(
        () => vault.assertDeleted('missing'),
        throwsA(isA<AssertionError>()),
      );
    });

    test('assertContains passes when key exists in store', () async {
      await vault.put('key', 'val');
      expect(() => vault.assertContains('key'), returnsNormally);
    });

    test('assertContains throws when key is missing from store', () {
      expect(
        () => vault.assertContains('missing'),
        throwsA(isA<AssertionError>()),
      );
    });

    test('assertMissing passes when key is not in store', () {
      expect(() => vault.assertMissing('gone'), returnsNormally);
    });

    test('assertMissing throws when key exists in store', () async {
      await vault.put('key', 'val');
      expect(() => vault.assertMissing('key'), throwsA(isA<AssertionError>()));
    });
  });

  group('FakeVaultService - recording', () {
    late FakeVaultService vault;

    setUp(() {
      vault = FakeVaultService();
    });

    test('records put operations', () async {
      await vault.put('token', 'abc');
      expect(vault.recorded, hasLength(1));
      expect(vault.recorded.first.operation, equals('put'));
      expect(vault.recorded.first.key, equals('token'));
    });

    test('records get operations', () async {
      await vault.get('token');
      expect(vault.recorded, hasLength(1));
      expect(vault.recorded.first.operation, equals('get'));
      expect(vault.recorded.first.key, equals('token'));
    });

    test('records remove operations', () async {
      await vault.remove('token');
      expect(vault.recorded, hasLength(1));
      expect(vault.recorded.first.operation, equals('remove'));
      expect(vault.recorded.first.key, equals('token'));
    });

    test('records flush operation', () async {
      await vault.flush();
      expect(vault.recorded, hasLength(1));
      expect(vault.recorded.first.operation, equals('flush'));
    });

    test('records multiple operations in order', () async {
      await vault.put('a', '1');
      await vault.get('a');
      await vault.remove('a');
      expect(vault.recorded, hasLength(3));
      expect(vault.recorded[0].operation, equals('put'));
      expect(vault.recorded[1].operation, equals('get'));
      expect(vault.recorded[2].operation, equals('remove'));
    });
  });

  group('FakeVaultService - reset()', () {
    test('clears store and recorded list', () async {
      final vault = FakeVaultService();
      await vault.put('key', 'val');
      await vault.get('key');
      vault.reset();
      expect(await vault.get('key'), isNull);
      // recorded after reset only has the get from this call
      expect(vault.recorded, hasLength(1));
    });

    test('store is empty after reset', () async {
      final vault = FakeVaultService({'existing': 'val'});
      vault.reset();
      expect(await vault.get('existing'), isNull);
    });
  });

  group('Vault.fake() - facade integration', () {
    test('fake() returns FakeVaultService', () {
      final fake = Vault.fake();
      expect(fake.runtimeType.toString(), equals('FakeVaultService'));
    });

    test('fake() registers service in container', () async {
      final fake = Vault.fake();
      await Vault.put('key', 'value');
      expect(await fake.get('key'), equals('value'));
    });

    test('fake() with initial values pre-populates store', () async {
      Vault.fake({'secret': 'token123'});
      expect(await Vault.get('secret'), equals('token123'));
    });

    test('Vault facade calls are delegated to fake', () async {
      final fake = Vault.fake();
      await Vault.put('x', '1');
      await Vault.get('x');
      await Vault.delete('x');
      expect(fake.recorded, hasLength(3));
    });
  });

  group('Vault.unfake()', () {
    test('unfake() removes fake from container', () {
      Magic.app.singleton('vault', () => MagicVaultService.forTesting());
      Vault.fake();
      Vault.unfake();
      // After unfake, the container resolves from the singleton binding (not a fake)
      final resolved = Magic.make<MagicVaultService>('vault');
      expect(resolved, isA<MagicVaultService>());
      expect(
        resolved.runtimeType.toString(),
        isNot(equals('FakeVaultService')),
      );
    });
  });
}
