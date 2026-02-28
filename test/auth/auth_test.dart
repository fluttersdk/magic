import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

// ---------------------------------------------------------------------------
// Mock User Model for Testing
// ---------------------------------------------------------------------------

class MockUser extends Model with HasTimestamps, Authenticatable {
  @override
  String get table => 'users';

  @override
  String get resource => 'users';

  String? get name => getAttribute('name') as String?;
  set name(String? value) => setAttribute('name', value);

  String? get email => getAttribute('email') as String?;
  set email(String? value) => setAttribute('email', value);
}

// ---------------------------------------------------------------------------
// Mock Guard for Testing
// ---------------------------------------------------------------------------

class MockGuard implements Guard {
  Authenticatable? _user;
  bool validateResult = true;
  String? mockToken = 'mock-token';

  @override
  final ValueNotifier<int> stateNotifier = ValueNotifier<int>(0);

  @override
  Future<void> login(Map<String, dynamic> data, Authenticatable user) async {
    mockToken = data['token'] as String?;
    _user = user;
  }

  @override
  Future<void> logout() async {
    _user = null;
    mockToken = null;
    stateNotifier.value++;
  }

  @override
  bool check() => _user != null;

  @override
  bool get guest => !check();

  @override
  T? user<T extends Model>() => _user as T?;

  @override
  dynamic id() => _user?.authIdentifier;

  @override
  void setUser(Authenticatable user) {
    _user = user;
    stateNotifier.value++;
  }

  @override
  Future<bool> hasToken() async => mockToken != null;

  @override
  Future<String?> getToken() async => mockToken;

  @override
  Future<bool> refreshToken() async => true;

  @override
  Future<void> restore() async {
    // Mock restore - sets a default user if token exists
    if (mockToken != null) {
      setUser(
        MockUser()
          ..setRawAttributes({'id': 1, 'name': 'Restored User'}, sync: true),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Authenticatable Mixin', () {
    test('authIdentifier returns primary key value', () {
      final user = MockUser()
        ..setRawAttributes({'id': 42, 'name': 'Test'}, sync: true);

      expect(user.authIdentifier, 42);
    });

    test('authIdentifierName returns primary key column name', () {
      final user = MockUser();
      expect(user.authIdentifierName, 'id');
    });

    test('authPassword returns password attribute', () {
      final user = MockUser()
        ..setRawAttributes({'password': 'hashed_secret'}, sync: true);

      expect(user.authPassword, 'hashed_secret');
    });
  });

  group('Guard Contract', () {
    late MockGuard guard;

    setUp(() {
      guard = MockGuard();
    });

    test('login sets user and token', () async {
      final user = MockUser()
        ..setRawAttributes({'id': 1, 'email': 'test@example.com'}, sync: true);

      await guard.login({'token': 'new-token'}, user);

      expect(guard.check(), isTrue);
      expect(await guard.getToken(), 'new-token');
      expect(guard.user<MockUser>()?.email, 'test@example.com');
    });

    test('check returns true when authenticated', () async {
      final user = MockUser()..setRawAttributes({'id': 1}, sync: true);
      await guard.login({'token': 'token'}, user);

      expect(guard.check(), isTrue);
      expect(guard.guest, isFalse);
    });

    test('guest returns true when not authenticated', () {
      guard.mockToken = null;
      expect(guard.guest, isTrue);
      expect(guard.check(), isFalse);
    });

    test('user returns null when not authenticated', () {
      expect(guard.user<MockUser>(), isNull);
    });

    test('user returns authenticated user', () async {
      final user = MockUser()
        ..setRawAttributes({
          'id': 1,
          'email': 'test@example.com',
        }, sync: true);
      await guard.login({'token': 'token'}, user);

      final retrieved = guard.user<MockUser>();
      expect(retrieved, isNotNull);
      expect(retrieved?.email, 'test@example.com');
    });

    test('id returns user identifier', () async {
      final user = MockUser()..setRawAttributes({'id': 1}, sync: true);
      await guard.login({'token': 'token'}, user);

      expect(guard.id(), 1);
    });

    test('logout clears user and token', () async {
      final user = MockUser()..setRawAttributes({'id': 1}, sync: true);
      await guard.login({'token': 'token'}, user);
      expect(guard.check(), isTrue);

      await guard.logout();
      expect(guard.check(), isFalse);
      expect(guard.user<MockUser>(), isNull);
      expect(await guard.getToken(), isNull);
    });

    test('setUser sets authenticated user', () {
      final user = MockUser()
        ..setRawAttributes({'id': 5, 'name': 'Manual'}, sync: true);

      guard.setUser(user);

      expect(guard.check(), isTrue);
      expect(guard.id(), 5);
    });

    test('hasToken returns true when token exists', () async {
      expect(await guard.hasToken(), isTrue);
    });

    test('getToken returns the token', () async {
      expect(await guard.getToken(), 'mock-token');
    });

    test('refreshToken returns true', () async {
      expect(await guard.refreshToken(), isTrue);
    });

    test('restore restores user from token', () async {
      guard.mockToken = 'stored-token';
      await guard.restore();

      expect(guard.check(), isTrue);
      expect(guard.user<MockUser>()?.name, 'Restored User');
    });

    test('stateNotifier bumps on setUser', () {
      int notifyCount = 0;
      guard.stateNotifier.addListener(() => notifyCount++);

      final user = MockUser()
        ..setRawAttributes({'id': 1, 'name': 'New'}, sync: true);
      guard.setUser(user);

      expect(notifyCount, 1);
    });

    test('stateNotifier bumps on logout', () async {
      final user = MockUser()..setRawAttributes({'id': 1}, sync: true);
      await guard.login({'token': 'token'}, user);

      int notifyCount = 0;
      guard.stateNotifier.addListener(() => notifyCount++);

      await guard.logout();

      expect(notifyCount, 1);
    });

    test('stateNotifier bumps on restore', () async {
      guard.mockToken = 'stored-token';

      int notifyCount = 0;
      guard.stateNotifier.addListener(() => notifyCount++);

      await guard.restore();

      expect(notifyCount, greaterThanOrEqualTo(1));
    });
  });

  group('AuthManager', () {
    late AuthManager manager;

    setUp(() {
      manager = AuthManager();
      manager.forgetGuards();
    });

    test('setUserFactory stores factory', () {
      expect(
        () => manager.setUserFactory(
            (data) => MockUser()..setRawAttributes(data, sync: true)),
        returnsNormally,
      );
    });

    test('extend registers custom driver', () {
      manager.extend('custom', (config) => MockGuard());

      expect(
        () => manager.extend('another', (c) => MockGuard()),
        returnsNormally,
      );
    });

    test('forgetGuards clears cached guards', () {
      manager.forgetGuards();
      // No assertion needed - just verifies method doesn't throw
    });
  });

  group('AuthResult', () {
    test('success creates successful result', () {
      final user = MockUser()
        ..setRawAttributes({'id': 1, 'name': 'Test'}, sync: true);

      final result = AuthResult.success(user: user, token: 'test-token');

      expect(result.success, isTrue);
      expect(result.failed, isFalse);
      expect(result.token, 'test-token');
      expect(result.user<MockUser>(), isNotNull);
    });

    test('failure creates failed result', () {
      final result = AuthResult.failure(
        message: 'Invalid credentials',
        errors: {
          'email': ['Email not found']
        },
      );

      expect(result.success, isFalse);
      expect(result.failed, isTrue);
      expect(result.message, 'Invalid credentials');
      expect(result.errors['email'], ['Email not found']);
    });

    test('firstError returns first error for field', () {
      final result = AuthResult.failure(
        errors: {
          'email': ['First error', 'Second error']
        },
      );

      expect(result.firstError('email'), 'First error');
      expect(result.firstError('password'), isNull);
    });

    test('fromResponse creates result from MagicResponse', () {
      final successResponse = MagicResponse(
        data: {
          'user': {'id': 1}
        },
        statusCode: 200,
      );

      final user = MockUser()..setRawAttributes({'id': 1}, sync: true);

      final result = AuthResult.fromResponse(
        successResponse,
        user: user,
        token: 'token',
      );

      expect(result.success, isTrue);
    });

    test('fromResponse creates failure for error response', () {
      final errorResponse = MagicResponse(
        data: {
          'message': 'Validation failed',
          'errors': {
            'email': ['Invalid email']
          },
        },
        statusCode: 422,
      );

      final result = AuthResult.fromResponse(errorResponse);

      expect(result.success, isFalse);
      expect(result.message, 'Validation failed');
      expect(result.errors['email'], ['Invalid email']);
    });
  });
}
