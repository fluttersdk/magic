import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_dusk/dusk.dart';
import 'package:magic/magic.dart';

/// Tests for the 5 new enrichers added in Plan Step 17, sub-change (c)
/// alongside the existing `magicFormEnricher` + `magicNavigationEnricher`.
///
/// Each enricher contract:
/// - Synchronous (`String? Function(Element, RefRegistry)`).
/// - Returns null on miss (precondition fails / data unavailable).
/// - Never retains the Element across calls.
/// - Reads only — no shared-state mutation.
///
/// `MagicDuskIntegration.install()` registers all 7 in insertion order;
/// `resetForTesting()` drops all 7.

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

class _TestUser extends Model with Authenticatable {
  @override
  String get table => 'users';
  @override
  String get resource => 'users';
  @override
  List<String> get fillable => ['id', 'name', 'display_name'];
}

_TestUser _user({int id = 7, String name = 'Alice', String? displayName}) {
  final u = _TestUser();
  final Map<String, Object?> data = {'id': id, 'name': name};
  if (displayName != null) {
    data['display_name'] = displayName;
  }
  u.fill(data);
  u.exists = true;
  return u;
}

class _StubController extends MagicController
    with MagicStateMixin<String>, ValidatesRequests {}

/// Captures the first descendant Element of [type] from a pumped tree.
Element _findElement(WidgetTester tester, Type widgetType) {
  return tester.element(find.byType(widgetType).first);
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    TitleManager.reset();
    MagicRouter.reset();
    Gate.manager.flush();
    MagicDuskIntegration.resetForTesting();
  });

  tearDown(() {
    Auth.unfake();
    MagicDuskIntegration.resetForTesting();
  });

  // ---------------------------------------------------------------------------
  // install() / resetForTesting() — covers all 7 enrichers
  // ---------------------------------------------------------------------------

  group('MagicDuskIntegration.install', () {
    test('registers all 7 enrichers in insertion order on first install', () {
      expect(DuskPlugin.enrichers, isEmpty);

      MagicDuskIntegration.install();

      // Insertion order matters per oracle contract: existing two first,
      // then the five new ones.
      expect(DuskPlugin.enrichers, hasLength(7));
      expect(DuskPlugin.enrichers[0], same(magicFormEnricher));
      expect(DuskPlugin.enrichers[1], same(magicNavigationEnricher));
      expect(DuskPlugin.enrichers[2], same(magicControllerEnricher));
      expect(DuskPlugin.enrichers[3], same(magicFormErrorsEnricher));
      expect(DuskPlugin.enrichers[4], same(magicGateResultEnricher));
      expect(DuskPlugin.enrichers[5], same(magicMiddlewareEnricher));
      expect(DuskPlugin.enrichers[6], same(magicAuthUserEnricher));
    });

    test('install() is idempotent (no duplicates on second call)', () {
      MagicDuskIntegration.install();
      MagicDuskIntegration.install();

      expect(DuskPlugin.enrichers, hasLength(7));
    });

    test('resetForTesting() drops all 7 enrichers', () {
      MagicDuskIntegration.install();
      expect(DuskPlugin.enrichers, hasLength(7));

      MagicDuskIntegration.resetForTesting();

      expect(DuskPlugin.enrichers, isEmpty);
      expect(MagicDuskIntegration.isInstalled, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // magicControllerEnricher
  // ---------------------------------------------------------------------------

  group('magicControllerEnricher', () {
    testWidgets('returns null when no controllers are registered', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final element = _findElement(tester, SizedBox);

      expect(magicControllerEnricher(element, RefRegistry.instance), isNull);
    });

    testWidgets(
      'emits `magicControllerState: <Class>.<status>` for a registered MagicStateMixin controller',
      (tester) async {
        final ctrl = _StubController();
        ctrl.setState('hello', status: const RxStatus.success());
        Magic.put<_StubController>(ctrl);

        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        final element = _findElement(tester, SizedBox);

        final emitted = magicControllerEnricher(element, RefRegistry.instance);
        expect(emitted, isNotNull);
        expect(emitted, startsWith('magicControllerState:'));
        expect(emitted, contains('_StubController'));
        expect(emitted, contains('success'));
      },
    );

    testWidgets('reflects current rxStatus (loading after setLoading)', (
      tester,
    ) async {
      final ctrl = _StubController();
      ctrl.setLoading();
      Magic.put<_StubController>(ctrl);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final element = _findElement(tester, SizedBox);

      final emitted = magicControllerEnricher(element, RefRegistry.instance);
      expect(emitted, contains('loading'));
    });

    testWidgets('reflects current rxStatus (error after setError)', (
      tester,
    ) async {
      final ctrl = _StubController();
      ctrl.setError('boom');
      Magic.put<_StubController>(ctrl);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final element = _findElement(tester, SizedBox);

      final emitted = magicControllerEnricher(element, RefRegistry.instance);
      expect(emitted, contains('error'));
    });

    testWidgets('returns null when only non-state controllers are registered', (
      tester,
    ) async {
      // SimpleMagicController has no MagicStateMixin — should be skipped.
      Magic.put<_PlainController>(_PlainController());

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final element = _findElement(tester, SizedBox);

      expect(magicControllerEnricher(element, RefRegistry.instance), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // magicFormErrorsEnricher
  // ---------------------------------------------------------------------------

  group('magicFormErrorsEnricher', () {
    testWidgets('returns null when element has no MagicForm ancestor', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final element = _findElement(tester, SizedBox);

      expect(magicFormErrorsEnricher(element, RefRegistry.instance), isNull);
    });

    testWidgets(
      'returns null when MagicForm controller has no validation errors',
      (tester) async {
        final ctrl = _StubController();
        final form = MagicFormData({'email': ''}, controller: ctrl);

        await tester.pumpWidget(
          MaterialApp(
            home: MagicForm(formData: form, child: const SizedBox()),
          ),
        );
        final element = _findElement(tester, SizedBox);

        expect(magicFormErrorsEnricher(element, RefRegistry.instance), isNull);
      },
    );

    testWidgets(
      'emits `magicFormErrors: <fields>` when controller has validation errors',
      (tester) async {
        final ctrl = _StubController();
        ctrl.validationErrors = {'email': 'Required', 'password': 'Too short'};
        final form = MagicFormData({
          'email': '',
          'password': '',
        }, controller: ctrl);

        await tester.pumpWidget(
          MaterialApp(
            home: MagicForm(formData: form, child: const SizedBox()),
          ),
        );
        final element = _findElement(tester, SizedBox);

        final emitted = magicFormErrorsEnricher(element, RefRegistry.instance);
        expect(emitted, isNotNull);
        expect(emitted, startsWith('magicFormErrors:'));
        expect(emitted, contains('email'));
        expect(emitted, contains('password'));
      },
    );

    testWidgets(
      'lists only fields that the form actually owns (cross-form leak guard)',
      (tester) async {
        final ctrl = _StubController();
        ctrl.validationErrors = {
          'email': 'Required',
          'unrelated_field': 'should not appear',
        };
        final form = MagicFormData({'email': ''}, controller: ctrl);

        await tester.pumpWidget(
          MaterialApp(
            home: MagicForm(formData: form, child: const SizedBox()),
          ),
        );
        final element = _findElement(tester, SizedBox);

        final emitted = magicFormErrorsEnricher(element, RefRegistry.instance);
        expect(emitted, isNotNull);
        expect(emitted, contains('email'));
        expect(emitted, isNot(contains('unrelated_field')));
      },
    );

    testWidgets(
      'returns null when MagicForm has a controller but no ValidatesRequests mixin',
      (tester) async {
        // _PlainController extends MagicController without ValidatesRequests.
        final ctrl = _PlainController();

        await tester.pumpWidget(
          MaterialApp(
            home: MagicForm(
              formKey: GlobalKey<FormState>(),
              controller: ctrl,
              child: const SizedBox(),
            ),
          ),
        );
        final element = _findElement(tester, SizedBox);

        expect(magicFormErrorsEnricher(element, RefRegistry.instance), isNull);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // magicGateResultEnricher
  // ---------------------------------------------------------------------------

  group('magicGateResultEnricher', () {
    testWidgets('returns null when no gate check has been recorded', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final element = _findElement(tester, SizedBox);

      expect(magicGateResultEnricher(element, RefRegistry.instance), isNull);
    });

    testWidgets(
      'emits `magicGateResult: <ability>.allowed` after an allowing check',
      (tester) async {
        Auth.fake(user: _user());
        Gate.define('view-dashboard', (user, _) => true);
        Gate.allows('view-dashboard');

        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        final element = _findElement(tester, SizedBox);

        final emitted = magicGateResultEnricher(element, RefRegistry.instance);
        expect(emitted, isNotNull);
        expect(emitted, contains('view-dashboard'));
        expect(emitted, contains('allowed'));
      },
    );

    testWidgets(
      'emits `magicGateResult: <ability>.denied` after a denying check',
      (tester) async {
        Auth.fake(user: _user());
        Gate.define('admin-only', (user, _) => false);
        Gate.allows('admin-only');

        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        final element = _findElement(tester, SizedBox);

        final emitted = magicGateResultEnricher(element, RefRegistry.instance);
        expect(emitted, isNotNull);
        expect(emitted, contains('admin-only'));
        expect(emitted, contains('denied'));
      },
    );

    testWidgets('reflects the most recently written cache entry', (
      tester,
    ) async {
      Auth.fake(user: _user());
      Gate.define('view-a', (user, _) => true);
      Gate.define('view-b', (user, _) => false);

      Gate.allows('view-a'); // earlier
      Gate.allows('view-b'); // most recent

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final element = _findElement(tester, SizedBox);

      final emitted = magicGateResultEnricher(element, RefRegistry.instance);
      expect(emitted, contains('view-b'));
      expect(emitted, contains('denied'));
    });

    testWidgets('returns null after Gate.manager.flush() clears the cache', (
      tester,
    ) async {
      Auth.fake(user: _user());
      Gate.define('view', (user, _) => true);
      Gate.allows('view');

      Gate.manager.flush();

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final element = _findElement(tester, SizedBox);

      expect(magicGateResultEnricher(element, RefRegistry.instance), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // magicMiddlewareEnricher
  // ---------------------------------------------------------------------------

  group('magicMiddlewareEnricher', () {
    testWidgets('returns null when no route is active', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final element = _findElement(tester, SizedBox);

      expect(magicMiddlewareEnricher(element, RefRegistry.instance), isNull);
    });

    testWidgets('returns null when the active route has zero middlewares', (
      tester,
    ) async {
      MagicRoute.page('/', () => const SizedBox());

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
      );
      await tester.pumpAndSettle();
      final element = _findElement(tester, SizedBox);

      expect(magicMiddlewareEnricher(element, RefRegistry.instance), isNull);
    });

    testWidgets(
      'emits `magicMiddleware: <names>` for the active route\'s middlewares',
      (tester) async {
        final middleware = _NamedMiddleware('auth');
        MagicRoute.page('/', () => const SizedBox()).middleware([middleware]);

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
        );
        await tester.pumpAndSettle();
        final element = _findElement(tester, SizedBox);

        final emitted = magicMiddlewareEnricher(element, RefRegistry.instance);
        expect(emitted, isNotNull);
        expect(emitted, startsWith('magicMiddleware:'));
        expect(emitted, contains('auth'));
      },
    );

    testWidgets('lists multiple middlewares joined by comma', (tester) async {
      final auth = _NamedMiddleware('auth');
      final admin = _NamedMiddleware('admin');
      MagicRoute.page('/', () => const SizedBox()).middleware([auth, admin]);

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
      );
      await tester.pumpAndSettle();
      final element = _findElement(tester, SizedBox);

      final emitted = magicMiddlewareEnricher(element, RefRegistry.instance);
      expect(emitted, contains('auth'));
      expect(emitted, contains('admin'));
      expect(emitted, contains(','));
    });

    testWidgets('emits string-alias middleware names verbatim', (tester) async {
      // String aliases pass through without Kernel resolution — they're
      // surfaced as-is so the snapshot stays useful even when the alias
      // isn't registered.
      MagicRoute.page('/', () => const SizedBox()).middleware(['guest']);

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
      );
      await tester.pumpAndSettle();
      final element = _findElement(tester, SizedBox);

      final emitted = magicMiddlewareEnricher(element, RefRegistry.instance);
      expect(emitted, contains('guest'));
    });
  });

  // ---------------------------------------------------------------------------
  // magicAuthUserEnricher
  // ---------------------------------------------------------------------------

  group('magicAuthUserEnricher', () {
    testWidgets('returns null when no user is authenticated', (tester) async {
      Auth.fake(); // no user

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final element = _findElement(tester, SizedBox);

      expect(magicAuthUserEnricher(element, RefRegistry.instance), isNull);
    });

    testWidgets(
      'emits `magicAuthUser: <id>:<displayName>` when user has display_name',
      (tester) async {
        Auth.fake(user: _user(id: 42, displayName: 'Alice Cooper'));

        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        final element = _findElement(tester, SizedBox);

        final emitted = magicAuthUserEnricher(element, RefRegistry.instance);
        expect(emitted, isNotNull);
        expect(emitted, startsWith('magicAuthUser:'));
        expect(emitted, contains('42'));
        expect(emitted, contains('Alice Cooper'));
      },
    );

    testWidgets('falls back to id-only when user model has no display_name', (
      tester,
    ) async {
      Auth.fake(user: _user(id: 13)); // no displayName

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final element = _findElement(tester, SizedBox);

      final emitted = magicAuthUserEnricher(element, RefRegistry.instance);
      expect(emitted, isNotNull);
      expect(emitted, 'magicAuthUser: 13');
      // No colon between id and an absent display name.
      expect(emitted, isNot(contains('13:')));
    });

    testWidgets('falls back to id-only when display_name is the empty string', (
      tester,
    ) async {
      Auth.fake(user: _user(id: 99, displayName: ''));

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final element = _findElement(tester, SizedBox);

      final emitted = magicAuthUserEnricher(element, RefRegistry.instance);
      expect(emitted, 'magicAuthUser: 99');
    });

    testWidgets(
      'survives across navigation transitions (no element retention)',
      (tester) async {
        Auth.fake(user: _user(id: 1, displayName: 'Bob'));

        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        final firstElement = _findElement(tester, SizedBox);

        final emitted1 = magicAuthUserEnricher(
          firstElement,
          RefRegistry.instance,
        );
        expect(emitted1, contains('Bob'));

        // Re-pump a fresh tree — enricher must not retain prior Element.
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        final secondElement = _findElement(tester, SizedBox);

        final emitted2 = magicAuthUserEnricher(
          secondElement,
          RefRegistry.instance,
        );
        expect(emitted2, contains('Bob'));
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Test helper widgets and controllers
// ---------------------------------------------------------------------------

class _PlainController extends MagicController {}

class _NamedMiddleware extends MagicMiddleware {
  _NamedMiddleware(this.alias);

  /// Stable alias surfaced by [magicMiddlewareEnricher].
  final String alias;

  @override
  String toString() => alias;

  @override
  Future<void> handle(void Function() next) async => next();
}
