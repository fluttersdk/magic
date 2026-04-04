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

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });

  tearDown(() {
    Auth.unfake();
  });

  // ---------------------------------------------------------------------------
  // 1. Unauthenticated state
  // ---------------------------------------------------------------------------

  group('unauthenticated state', () {
    test('check returns false when no user is set', () {
      final fake = FakeAuthManager();

      expect(fake.guard().check(), isFalse);
    });

    test('guest returns true when no user is set', () {
      final fake = FakeAuthManager();

      expect(fake.guard().guest, isTrue);
    });

    test('user returns null when no user is set', () {
      final fake = FakeAuthManager();

      expect(fake.guard().user<_TestUser>(), isNull);
    });

    test('id returns null when no user is set', () {
      final fake = FakeAuthManager();

      expect(fake.guard().id(), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Authenticated state
  // ---------------------------------------------------------------------------

  group('authenticated state', () {
    test('check returns true when user is provided', () {
      final user = _makeUser();
      final fake = FakeAuthManager(user: user);

      expect(fake.guard().check(), isTrue);
    });

    test('guest returns false when user is provided', () {
      final user = _makeUser();
      final fake = FakeAuthManager(user: user);

      expect(fake.guard().guest, isFalse);
    });

    test('user returns the provided model', () {
      final user = _makeUser();
      final fake = FakeAuthManager(user: user);

      final result = fake.guard().user<_TestUser>();

      expect(result, same(user));
      expect(result?.name, equals('Alice'));
    });

    test('id returns the user auth identifier', () {
      final user = _makeUser(id: 42);
      final fake = FakeAuthManager(user: user);

      expect(fake.guard().id(), equals(42));
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Login flow
  // ---------------------------------------------------------------------------

  group('login flow', () {
    test('login sets user and makes check true', () async {
      final fake = FakeAuthManager();
      final user = _makeUser();

      await fake.guard().login({'token': 'abc123'}, user);

      expect(fake.guard().check(), isTrue);
      expect(fake.guard().user<_TestUser>(), same(user));
    });

    test('login stores token from data map', () async {
      final fake = FakeAuthManager();
      final user = _makeUser();

      await fake.guard().login({'token': 'secret-token'}, user);

      expect(await fake.guard().hasToken(), isTrue);
      expect(await fake.guard().getToken(), equals('secret-token'));
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Logout flow
  // ---------------------------------------------------------------------------

  group('logout flow', () {
    test('logout clears user and makes check false', () async {
      final user = _makeUser();
      final fake = FakeAuthManager(user: user);

      await fake.guard().logout();

      expect(fake.guard().check(), isFalse);
      expect(fake.guard().user<_TestUser>(), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Token management
  // ---------------------------------------------------------------------------

  group('token management', () {
    test('hasToken returns false when no token set', () async {
      final fake = FakeAuthManager();

      expect(await fake.guard().hasToken(), isFalse);
    });

    test('getToken returns null when no token set', () async {
      final fake = FakeAuthManager();

      expect(await fake.guard().getToken(), isNull);
    });

    test('login stores token and hasToken/getToken reflect it', () async {
      final fake = FakeAuthManager();
      final user = _makeUser();

      await fake.guard().login({'token': 'my-jwt'}, user);

      expect(await fake.guard().hasToken(), isTrue);
      expect(await fake.guard().getToken(), equals('my-jwt'));
    });
  });

  // ---------------------------------------------------------------------------
  // 6. Assertions
  // ---------------------------------------------------------------------------

  group('assertions', () {
    test('assertLoggedIn passes when user is set', () {
      final fake = FakeAuthManager(user: _makeUser());

      expect(() => fake.assertLoggedIn(), returnsNormally);
    });

    test('assertLoggedIn throws when no user', () {
      final fake = FakeAuthManager();

      expect(() => fake.assertLoggedIn(), throwsA(isA<AssertionError>()));
    });

    test('assertLoggedOut passes when no user', () {
      final fake = FakeAuthManager();

      expect(() => fake.assertLoggedOut(), returnsNormally);
    });

    test('assertLoggedOut throws when user is set', () {
      final fake = FakeAuthManager(user: _makeUser());

      expect(() => fake.assertLoggedOut(), throwsA(isA<AssertionError>()));
    });

    test('assertLoginAttempted passes after login', () async {
      final fake = FakeAuthManager();

      await fake.guard().login({'token': 'x'}, _makeUser());

      expect(() => fake.assertLoginAttempted(), returnsNormally);
    });

    test('assertLoginAttempted throws when no login occurred', () {
      final fake = FakeAuthManager();

      expect(() => fake.assertLoginAttempted(), throwsA(isA<AssertionError>()));
    });

    test('assertLoginCount passes with correct count', () async {
      final fake = FakeAuthManager();

      await fake.guard().login({'token': 'a'}, _makeUser());
      await fake.guard().login({'token': 'b'}, _makeUser(id: 2));

      expect(() => fake.assertLoginCount(2), returnsNormally);
    });

    test('assertLoginCount throws with wrong count', () async {
      final fake = FakeAuthManager();

      await fake.guard().login({'token': 'a'}, _makeUser());

      expect(() => fake.assertLoginCount(3), throwsA(isA<AssertionError>()));
    });
  });

  // ---------------------------------------------------------------------------
  // 7. stateNotifier
  // ---------------------------------------------------------------------------

  group('stateNotifier', () {
    test('bumps on login', () async {
      final fake = FakeAuthManager();
      final notifier = fake.guard().stateNotifier;
      final initial = notifier.value;

      await fake.guard().login({'token': 'x'}, _makeUser());

      expect(notifier.value, equals(initial + 1));
    });

    test('bumps on logout', () async {
      final fake = FakeAuthManager(user: _makeUser());
      final notifier = fake.guard().stateNotifier;
      final initial = notifier.value;

      await fake.guard().logout();

      expect(notifier.value, equals(initial + 1));
    });
  });

  // ---------------------------------------------------------------------------
  // 8. Auth.fake() — facade integration
  // ---------------------------------------------------------------------------

  group('Auth.fake()', () {
    test('returns a FakeAuthManager instance', () {
      final fake = Auth.fake();

      expect(fake, isA<FakeAuthManager>());
    });

    test('facade check routes through fake', () {
      Auth.fake(user: _makeUser());

      expect(Auth.check(), isTrue);
    });

    test('facade user returns the fake user', () {
      final user = _makeUser();
      Auth.fake(user: user);

      expect(Auth.user<_TestUser>(), same(user));
    });

    test('facade login routes through fake', () async {
      final fake = Auth.fake();
      final user = _makeUser();

      await Auth.login({'token': 'tok'}, user);

      expect(Auth.check(), isTrue);
      fake.assertLoginAttempted();
    });
  });

  // ---------------------------------------------------------------------------
  // 9. Auth.unfake()
  // ---------------------------------------------------------------------------

  group('Auth.unfake()', () {
    test('can be called without throwing', () {
      Auth.fake();

      expect(() => Auth.unfake(), returnsNormally);
    });
  });

  // ---------------------------------------------------------------------------
  // 10. restore / refreshToken — no-op
  // ---------------------------------------------------------------------------

  group('restore and refreshToken', () {
    test('restore completes without error', () async {
      final fake = FakeAuthManager();

      await expectLater(fake.guard().restore(), completes);
    });

    test('refreshToken returns false', () async {
      final fake = FakeAuthManager();

      expect(await fake.guard().refreshToken(), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // 11. setUser
  // ---------------------------------------------------------------------------

  group('setUser', () {
    test('directly sets user without login', () {
      final fake = FakeAuthManager();
      final user = _makeUser();

      fake.guard().setUser(user);

      expect(fake.guard().check(), isTrue);
      expect(fake.guard().user<_TestUser>(), same(user));
    });
  });

  // ---------------------------------------------------------------------------
  // 12. reset
  // ---------------------------------------------------------------------------

  group('reset', () {
    test('clears user, token, and login attempts', () async {
      final fake = FakeAuthManager(user: _makeUser());

      await fake.guard().login({'token': 'abc'}, _makeUser());
      fake.reset();

      expect(fake.guard().check(), isFalse);
      expect(await fake.guard().hasToken(), isFalse);
      expect(() => fake.assertLoginAttempted(), throwsA(isA<AssertionError>()));
    });
  });

  // ---------------------------------------------------------------------------
  // 13. guard() always returns same fake guard regardless of name
  // ---------------------------------------------------------------------------

  group('guard resolution', () {
    test('guard with any name returns the same fake guard', () {
      final fake = FakeAuthManager(user: _makeUser());

      expect(fake.guard().check(), isTrue);
      expect(fake.guard('api').check(), isTrue);
      expect(fake.guard('web').check(), isTrue);
    });
  });
}
