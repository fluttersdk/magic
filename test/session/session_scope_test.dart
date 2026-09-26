import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

class _TestUser extends Model with Authenticatable {
  _TestUser(int id) {
    fill({'id': id});
    exists = true;
  }

  @override
  String get table => 'users';

  @override
  String get resource => 'users';

  @override
  List<String> get fillable => ['id'];
}

/// A controller whose cached rows belong to one session.
class _ScopedController extends MagicController implements SessionScoped {
  int resetCount = 0;

  @override
  Future<void> resetForSession() async {
    resetCount++;
  }
}

/// Fails before any await, so a broken loop would skip every later holder.
class _ThrowingController extends MagicController implements SessionScoped {
  int resetCount = 0;

  @override
  Future<void> resetForSession() {
    resetCount++;

    return Future<void>.error(StateError('boom'));
  }
}

/// A non-controller holder, the shape a repository registers as.
class _ScopedHolder implements SessionScoped {
  int resetCount = 0;

  @override
  Future<void> resetForSession() async {
    resetCount++;
  }
}

/// A controller outside the contract; a sync must never touch it.
class _PlainController extends MagicController {}

void main() {
  late String? Function() defaultIdentity;
  late FakeLogManager log;
  final List<SessionScoped> registered = <SessionScoped>[];

  setUpAll(() {
    defaultIdentity = SessionScope.identity;
  });

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    log = Log.fake();
    Auth.fake();

    // SessionScope is process-wide static state that neither MagicApp.reset()
    // nor Magic.flush() touches, so every test starts detached.
    SessionScope.detach();
    SessionScope.identity = defaultIdentity;
  });

  tearDown(() {
    SessionScope.detach();
    SessionScope.identity = defaultIdentity;
    registered.forEach(SessionScope.unregister);
    registered.clear();
    Auth.unfake();
    Log.unfake();
  });

  /// Registers [holder] and remembers it so tearDown can unregister it.
  T register<T extends SessionScoped>(T holder) {
    SessionScope.register(holder);
    registered.add(holder);

    return holder;
  }

  Future<void> loginAs(int id) async {
    await Auth.login({'token': 'token-$id'}, _TestUser(id));
  }

  group('SessionScope', () {
    test('attaches and detaches its auth state listener', () {
      expect(SessionScope.isAttached, isFalse);

      SessionScope.attach();
      expect(SessionScope.isAttached, isTrue);

      SessionScope.detach();
      expect(SessionScope.isAttached, isFalse);
    });

    test('the default identity is the authenticated user id', () async {
      expect(SessionScope.identity(), isNull);

      await loginAs(7);

      expect(SessionScope.identity(), '7');
    });

    test('does not reset what is registered at attach time', () async {
      await loginAs(1);
      SessionScope.attach();

      final controller = Magic.put(_ScopedController());
      final holder = register(_ScopedHolder());
      await pumpEventQueue();

      expect(controller.resetCount, 0);
      expect(holder.resetCount, 0);
    });

    test(
      'an identity change resets controllers and registered holders',
      () async {
        await loginAs(1);
        SessionScope.attach();

        final controller = Magic.put(_ScopedController());
        final holder = register(_ScopedHolder());

        await loginAs(2);
        await pumpEventQueue();

        expect(controller.resetCount, 1);
        expect(holder.resetCount, 1);
      },
    );

    test('a team change for the same user resets in place when the resolver '
        'includes the team', () async {
      String team = 'a';
      SessionScope.identity = () => Auth.check() ? '${Auth.id()}:$team' : null;

      await loginAs(1);
      SessionScope.attach();

      final controller = Magic.findOrPut(_ScopedController.new);

      team = 'b';
      Auth.stateNotifier.value++;
      await pumpEventQueue();

      expect(controller.resetCount, 1);
      expect(Magic.isRegistered<_ScopedController>(), isTrue);
      expect(Magic.find<_ScopedController>(), same(controller));
      expect(controller.isDisposed, isFalse);
    });

    test('an unchanged identity resets nothing', () async {
      await loginAs(1);
      SessionScope.attach();

      final controller = Magic.put(_ScopedController());
      final holder = register(_ScopedHolder());

      Auth.stateNotifier.value++;
      SessionScope.sync();
      await pumpEventQueue();

      expect(controller.resetCount, 0);
      expect(holder.resetCount, 0);
    });

    test('logout records the null identity and resets nothing', () async {
      await loginAs(1);
      SessionScope.attach();

      final controller = Magic.put(_ScopedController());
      final holder = register(_ScopedHolder());

      await Auth.logout();
      await pumpEventQueue();

      expect(controller.resetCount, 0);
      expect(holder.resetCount, 0);

      // The null was recorded: the same user signing back in is a change.
      await loginAs(1);
      await pumpEventQueue();

      expect(controller.resetCount, 1);
      expect(holder.resetCount, 1);
    });

    test('a reset never removes a controller from the registry', () async {
      await loginAs(1);
      SessionScope.attach();

      final controller = Magic.put(_ScopedController());

      await loginAs(2);
      await pumpEventQueue();

      expect(Magic.controllers, contains(controller));
      expect(Magic.find<_ScopedController>(), same(controller));
      expect(controller.isDisposed, isFalse);
    });

    test('isolates a failing reset and logs it', () async {
      await loginAs(1);
      SessionScope.attach();

      final throwing = Magic.put(_ThrowingController());
      final controller = Magic.put(_ScopedController());
      final holder = register(_ScopedHolder());

      await loginAs(2);
      await pumpEventQueue();

      expect(throwing.resetCount, 1);
      expect(controller.resetCount, 1);
      expect(holder.resetCount, 1);
      log.assertLoggedError(
        '[SessionScope] session reset failed: Bad state: boom',
      );
    });

    test('ignores controllers outside the contract', () async {
      await loginAs(1);
      SessionScope.attach();

      final plain = Magic.put(_PlainController());

      await loginAs(2);
      await pumpEventQueue();

      expect(plain.isDisposed, isFalse);
      expect(Magic.find<_PlainController>(), same(plain));
    });

    test('resets a controller that is also registered only once', () async {
      await loginAs(1);
      SessionScope.attach();

      final controller = register(Magic.put(_ScopedController()));

      await loginAs(2);
      await pumpEventQueue();

      expect(controller.resetCount, 1);
    });

    test('an unregistered holder is no longer reset', () async {
      await loginAs(1);
      SessionScope.attach();

      final holder = _ScopedHolder();
      SessionScope.register(holder);
      SessionScope.unregister(holder);

      await loginAs(2);
      await pumpEventQueue();

      expect(holder.resetCount, 0);
    });

    test('stops resetting after detach', () async {
      await loginAs(1);
      SessionScope.attach();

      final controller = Magic.put(_ScopedController());

      SessionScope.detach();
      await loginAs(2);
      await pumpEventQueue();

      expect(controller.resetCount, 0);
    });

    test('a second attach does not double the reset', () async {
      await loginAs(1);
      SessionScope.attach();
      SessionScope.attach();

      final controller = Magic.put(_ScopedController());

      await loginAs(2);
      await pumpEventQueue();

      expect(controller.resetCount, 1);
    });
  });
}
