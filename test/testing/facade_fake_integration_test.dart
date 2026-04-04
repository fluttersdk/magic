import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

// ---------------------------------------------------------------------------
// Test User Model
// ---------------------------------------------------------------------------

class _TestUser extends Model with HasTimestamps, Authenticatable {
  @override
  String get table => 'users';

  @override
  String get resource => 'users';

  @override
  List<String> get fillable => ['id', 'name', 'email'];

  String? get name => getAttribute('name') as String?;
  set name(String? value) => setAttribute('name', value);

  String? get email => getAttribute('email') as String?;
  set email(String? value) => setAttribute('email', value);
}

_TestUser _makeUser({
  int id = 1,
  String name = 'Alice',
  String email = 'alice@example.com',
}) {
  final user = _TestUser();
  user.fill({'id': id, 'name': name, 'email': email});
  user.exists = true;
  return user;
}

// ---------------------------------------------------------------------------
// Integration Tests
// ---------------------------------------------------------------------------

void main() {
  group('Facade Fake Integration', () {
    setUp(() {
      MagicApp.reset();
      Magic.flush();
    });

    tearDown(() {
      Http.unfake();
      Auth.unfake();
      Cache.unfake();
      Vault.unfake();
      Log.unfake();
    });

    test('all fakes work together without interference', () async {
      // Setup all fakes
      final httpFake = Http.fake({
        'users/*': Http.response({'id': 1, 'name': 'Alice'}, 200),
      });
      final authFake = Auth.fake(user: _makeUser());
      final cacheFake = Cache.fake();
      final vaultFake = Vault.fake({'api_token': 'test-token'});
      final logFake = Log.fake();

      // Http fake responds correctly
      final response = await Http.get('/users/1');
      expect(response.successful, isTrue);

      // Auth fake reports authenticated
      expect(Auth.check(), isTrue);

      // Cache fake stores and retrieves
      await Cache.put('key', 'value');
      expect(Cache.has('key'), isTrue);

      // Vault fake returns pre-seeded value
      final token = await Vault.get('api_token');
      expect(token, equals('test-token'));

      // Log fake captures message
      Log.info('test message');

      // Assert each fake recorded the correct interactions
      httpFake.assertSent((r) => r.url.contains('users'));
      authFake.assertLoggedIn();
      cacheFake.assertHas('key');
      vaultFake.assertContains('api_token');
      logFake.assertLogged('info', 'test message');
    });

    test('fakes do not share state between test runs', () async {
      // First run: put something in cache
      Cache.fake();
      await Cache.put('shared', 'first');
      expect(Cache.has('shared'), isTrue);
      Cache.unfake();

      // Second fake instance starts fresh
      final fresh = Cache.fake();
      expect(Cache.has('shared'), isFalse);
      fresh.assertMissing('shared');
    });

    test('unfake restores each service independently', () async {
      // Fake everything
      Http.fake();
      Auth.fake();
      Cache.fake();
      Vault.fake();
      Log.fake();

      // Unfake Http — others should still work as fakes
      Http.unfake();

      // Auth fake is still active
      expect(Auth.check(), isFalse); // unauthenticated fake still responds

      // Cache fake is still active
      await Cache.put('alive', true);
      expect(Cache.has('alive'), isTrue);

      // Vault fake is still active
      await Vault.put('still', 'fake');
      expect(await Vault.get('still'), equals('fake'));

      // Log fake is still active
      Log.warning('still faked');
      expect(Magic.make<FakeLogManager>('log').entries, isNotEmpty);

      Auth.unfake();
      Cache.unfake();
      Vault.unfake();
      Log.unfake();
    });

    test('auth and cache fakes work together in login flow', () async {
      final authFake = Auth.fake();
      final cacheFake = Cache.fake();
      final logFake = Log.fake();

      // Simulate login
      final user = _makeUser(id: 42, name: 'Bob');
      await authFake.guard().login({'token': 'jwt-secret'}, user);

      // Store session data in cache
      await Cache.put('session_user_id', 42);
      await Cache.put('session_name', 'Bob');

      Log.info('User Bob logged in');

      // Verify all recorded state
      expect(Auth.check(), isTrue);
      expect(Auth.user<_TestUser>()?.name, equals('Bob'));
      expect(Cache.get('session_user_id'), equals(42));
      authFake.assertLoginAttempted();
      cacheFake.assertHas('session_user_id');
      cacheFake.assertHas('session_name');
      logFake.assertLogged('info', 'User Bob logged in');
    });
  });
}
