import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// Regression tests for the login double-mount bug.
///
/// Background: redirect-style guards (auth / guest) used to redirect from
/// inside the post-mount `_MiddlewareGuard` via an imperative `MagicRoute.to`.
/// That made the destination view (e.g. the login screen) mount more than
/// once and recreate its form state on every mount.
///
/// The fix moves redirect gating into go_router's synchronous `redirect`
/// callback (pre-build) via [MagicMiddleware.redirectTarget]. A guarded route
/// now resolves its redirect BEFORE any page builds, so the destination view
/// mounts exactly once.
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
    _LoginProbe.mountCount = 0;
    _DashboardProbe.mountCount = 0;
  });

  group('redirect-style guard pre-build gating', () {
    testWidgets(
      'unauthenticated boot redirects to /login and mounts it exactly once',
      (tester) async {
        // 'auth' guard redirects unauthenticated users to /login pre-build.
        Kernel.register('auth', () => _AuthGuard(authenticated: false));
        // 'guest' guard lets unauthenticated users stay on /login.
        Kernel.register('guest', () => _GuestGuard(authenticated: false));

        MagicRoute.page(
          '/',
          () => const _DashboardProbe(),
        ).middleware(['auth']);
        MagicRoute.page(
          '/login',
          () => const _LoginProbe(),
        ).middleware(['guest']);

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
        );
        await tester.pumpAndSettle();

        // (a) The redirect actually fired: we are on /login, not the dashboard.
        expect(MagicRouter.instance.currentPath, '/login');
        expect(
          _DashboardProbe.mountCount,
          0,
          reason: 'dashboard must never build for an unauthenticated user',
        );

        // (b) The login view mounted exactly once (no double-mount).
        expect(
          _LoginProbe.mountCount,
          1,
          reason: 'login must mount exactly once across the boot redirect',
        );
      },
    );

    testWidgets('authenticated boot stays on / and never mounts /login', (
      tester,
    ) async {
      Kernel.register('auth', () => _AuthGuard(authenticated: true));
      Kernel.register('guest', () => _GuestGuard(authenticated: true));

      MagicRoute.page('/', () => const _DashboardProbe()).middleware(['auth']);
      MagicRoute.page(
        '/login',
        () => const _LoginProbe(),
      ).middleware(['guest']);

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
      );
      await tester.pumpAndSettle();

      expect(MagicRouter.instance.currentPath, '/');
      expect(_DashboardProbe.mountCount, 1);
      expect(_LoginProbe.mountCount, 0);
    });

    testWidgets('redirect gating resolves through a layout (ShellRoute) too', (
      tester,
    ) async {
      Kernel.register('auth', () => _AuthGuard(authenticated: false));
      Kernel.register('guest', () => _GuestGuard(authenticated: false));

      MagicRoute.group(
        middleware: ['auth'],
        layoutId: 'app',
        layout: (child) => _LayoutShell(child: child),
        routes: () {
          MagicRoute.page('/', () => const _DashboardProbe());
        },
      );
      MagicRoute.group(
        middleware: ['guest'],
        layoutId: 'guest',
        layout: (child) => _LayoutShell(child: child),
        routes: () {
          MagicRoute.page('/login', () => const _LoginProbe());
        },
      );

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
      );
      await tester.pumpAndSettle();

      expect(MagicRouter.instance.currentPath, '/login');
      expect(_LoginProbe.mountCount, 1);
      expect(_DashboardProbe.mountCount, 0);
    });
  });

  group('AuthorizeMiddleware (can:) pre-build gating', () {
    testWidgets('denied ability redirects to /unauthorized before build', (
      tester,
    ) async {
      Auth.fake(user: _fakeUser());
      Gate.define('edit-post', (user, _) => false);
      Kernel.register('can:edit-post', () => AuthorizeMiddleware('edit-post'));

      // _LoginProbe stands in for the protected page; _DashboardProbe for
      // the unauthorized destination.
      MagicRoute.page('/', () => const Text('home'));
      MagicRoute.page(
        '/edit',
        () => const _LoginProbe(),
      ).middleware(['can:edit-post']);
      MagicRoute.page('/unauthorized', () => const _DashboardProbe());

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
      );
      await tester.pumpAndSettle();

      MagicRouter.instance.to('/edit');
      await tester.pumpAndSettle();

      expect(MagicRouter.instance.currentPath, '/unauthorized');
      expect(
        _LoginProbe.mountCount,
        0,
        reason: 'a denied route must never build',
      );
      expect(_DashboardProbe.mountCount, 1);
    });

    testWidgets('allowed ability builds the protected route once', (
      tester,
    ) async {
      Auth.fake(user: _fakeUser());
      Gate.define('edit-post', (user, _) => true);
      Kernel.register('can:edit-post', () => AuthorizeMiddleware('edit-post'));

      MagicRoute.page('/', () => const Text('home'));
      MagicRoute.page(
        '/edit',
        () => const _LoginProbe(),
      ).middleware(['can:edit-post']);
      MagicRoute.page('/unauthorized', () => const _DashboardProbe());

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
      );
      await tester.pumpAndSettle();

      MagicRouter.instance.to('/edit');
      await tester.pumpAndSettle();

      expect(MagicRouter.instance.currentPath, '/edit');
      expect(_LoginProbe.mountCount, 1);
      expect(_DashboardProbe.mountCount, 0);
    });
  });
}

/// Auth guard: redirects to /login pre-build when not authenticated.
class _AuthGuard extends MagicMiddleware {
  _AuthGuard({required this.authenticated});

  final bool authenticated;

  @override
  String? redirectTarget(String location) {
    if (!authenticated && location != '/login') return '/login';
    return null;
  }

  @override
  Future<void> handle(void Function() next) async => next();
}

/// Guest guard: redirects authenticated users away from guest routes.
class _GuestGuard extends MagicMiddleware {
  _GuestGuard({required this.authenticated});

  final bool authenticated;

  @override
  String? redirectTarget(String location) {
    if (authenticated && location != '/') return '/';
    return null;
  }

  @override
  Future<void> handle(void Function() next) async => next();
}

class _LoginProbe extends StatefulWidget {
  const _LoginProbe();

  static int mountCount = 0;

  @override
  State<_LoginProbe> createState() => _LoginProbeState();
}

class _LoginProbeState extends State<_LoginProbe> {
  @override
  void initState() {
    super.initState();
    _LoginProbe.mountCount++;
  }

  @override
  Widget build(BuildContext context) => const Text('login');
}

class _DashboardProbe extends StatefulWidget {
  const _DashboardProbe();

  static int mountCount = 0;

  @override
  State<_DashboardProbe> createState() => _DashboardProbeState();
}

class _DashboardProbeState extends State<_DashboardProbe> {
  @override
  void initState() {
    super.initState();
    _DashboardProbe.mountCount++;
  }

  @override
  Widget build(BuildContext context) => const Text('dashboard');
}

class _LayoutShell extends StatelessWidget {
  const _LayoutShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// Minimal authenticated user for the AuthorizeMiddleware tests.
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
