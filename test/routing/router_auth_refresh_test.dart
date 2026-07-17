import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// Tests for wiring the GoRouter `refreshListenable` to the auth guard's
/// `stateNotifier`.
///
/// Background: a passive 401 (expired or revoked token) routes through
/// `AuthInterceptor.onError`, which logs the user out when the refresh fails.
/// Logout bumps the guard's `stateNotifier`. With the notifier wired as the
/// router's refresh signal, GoRouter re-runs its redirect chain on that bump,
/// ejecting the user from a protected screen to the login route without an
/// explicit navigation call.
///
/// These tests read live auth state inside the middleware (rather than a fixed
/// boolean), so they exercise the actual re-evaluation trigger and prove the
/// eject happens purely from a state change.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    TitleManager.reset();
    MagicRouter.reset();
    Kernel.flush();
    Gate.manager.flush();
    Log.fake();
  });

  tearDown(() {
    Auth.unfake();
  });

  testWidgets('a passive logout re-runs redirects and ejects to /login', (
    tester,
  ) async {
    // 1. Start authenticated: the protected route is reachable.
    Auth.fake(user: _fakeUser());
    Kernel.register('auth', () => _LiveAuthGuard());
    Kernel.register('guest', () => _LiveGuestGuard());

    MagicRoute.page('/', () => const Text('dashboard')).middleware(['auth']);
    MagicRoute.page('/login', () => const Text('login')).middleware(['guest']);

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
    );
    await tester.pumpAndSettle();

    expect(MagicRouter.instance.currentPath, '/');

    // 2. Simulate the passive 401 -> AuthInterceptor logout. This only bumps
    //    the guard's stateNotifier; there is no explicit navigation here.
    await Auth.logout();
    await tester.pumpAndSettle();

    // 3. The router re-evaluated the redirect chain off the state change and
    //    ejected the now-guest user to the login route.
    expect(MagicRouter.instance.currentPath, '/login');
  });

  testWidgets('a logged-out user resting on /login does not loop', (
    tester,
  ) async {
    // Guest (no user) sitting on the guest route: the guest middleware must
    // return null (allow), so the refresh-driven re-evaluation stays put and
    // go_router never exceeds its redirect budget.
    Auth.fake();
    Kernel.register('auth', () => _LiveAuthGuard());
    Kernel.register('guest', () => _LiveGuestGuard());

    MagicRoute.page('/', () => const Text('dashboard')).middleware(['auth']);
    MagicRoute.page('/login', () => const Text('login')).middleware(['guest']);

    MagicRouter.instance.setInitialLocation('/login');

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
    );
    await tester.pumpAndSettle();

    expect(MagicRouter.instance.currentPath, '/login');

    // A spurious state bump (e.g. a failed restore) must not start a loop.
    Auth.stateNotifier.value++;
    await tester.pumpAndSettle();

    expect(MagicRouter.instance.currentPath, '/login');
  });
}

/// Auth guard reading live auth state: redirects a guest off protected routes.
class _LiveAuthGuard extends MagicMiddleware {
  @override
  String? redirectTarget(String location) {
    if (Auth.guest && location != '/login') return '/login';
    return null;
  }

  @override
  Future<void> handle(void Function() next) async => next();
}

/// Guest guard reading live auth state: redirects an authenticated user home.
class _LiveGuestGuard extends MagicMiddleware {
  @override
  String? redirectTarget(String location) {
    if (Auth.check() && location != '/') return '/';
    return null;
  }

  @override
  Future<void> handle(void Function() next) async => next();
}

/// Minimal authenticated user for the fake auth manager.
class _FakeUser extends Model with Authenticatable {
  @override
  String get table => 'users';

  @override
  String get resource => 'users';

  @override
  List<String> get fillable => ['id', 'name'];
}

_FakeUser _fakeUser() {
  final user = _FakeUser();
  user.fill({'id': 1, 'name': 'Alice'});
  user.exists = true;
  return user;
}
