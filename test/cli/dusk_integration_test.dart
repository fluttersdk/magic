import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_dusk/dusk.dart';
import 'package:fluttersdk_telescope/telescope.dart';
import 'package:magic/dusk_integration.dart';
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
    test('registers all 14 enrichers in insertion order on first install', () {
      expect(DuskPlugin.enrichers, isEmpty);

      MagicDuskIntegration.install();

      // Insertion order matters per oracle contract: original two first,
      // then Plan-Step-17 enrichers (slots 2..6), then Step-1.1 (slots 7..8),
      // then Step-1.2 enrichers (slots 9..10), then Step-1.3 telescope-bridge
      // enrichers (slots 11..13).
      expect(DuskPlugin.enrichers, hasLength(14));
      expect(DuskPlugin.enrichers[0], same(magicFormEnricher));
      expect(DuskPlugin.enrichers[1], same(magicNavigationEnricher));
      expect(DuskPlugin.enrichers[2], same(magicControllerEnricher));
      expect(DuskPlugin.enrichers[3], same(magicFormErrorsEnricher));
      expect(DuskPlugin.enrichers[4], same(magicGateResultEnricher));
      expect(DuskPlugin.enrichers[5], same(magicMiddlewareEnricher));
      expect(DuskPlugin.enrichers[6], same(magicAuthUserEnricher));
      expect(DuskPlugin.enrichers[7], same(magicControllerFlagsEnricher));
      expect(DuskPlugin.enrichers[8], same(magicRouteParamsEnricher));
      expect(DuskPlugin.enrichers[9], same(magicEchoConnectionEnricher));
      expect(DuskPlugin.enrichers[10], same(magicGateResultsAllEnricher));
      expect(DuskPlugin.enrichers[11], same(magicRecentHttpEnricher));
      expect(DuskPlugin.enrichers[12], same(magicRecentLogsEnricher));
      expect(DuskPlugin.enrichers[13], same(magicRecentExceptionsEnricher));
    });

    test('install() is idempotent (no duplicates on second call)', () {
      MagicDuskIntegration.install();
      MagicDuskIntegration.install();

      expect(DuskPlugin.enrichers, hasLength(14));
    });

    test('resetForTesting() drops all 14 enrichers', () {
      MagicDuskIntegration.install();
      expect(DuskPlugin.enrichers, hasLength(14));

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
      'emits quoted per-field error text when controller has validation errors',
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
        // Step 1.1 (a): error text now emitted per field, quoted.
        expect(emitted, contains('email="Required"'));
        expect(emitted, contains('password="Too short"'));
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
        expect(emitted, contains('email="Required"'));
        expect(emitted, isNot(contains('unrelated_field')));
      },
    );

    // -------------------------------------------------------------------------
    // Step 1.1 (a) — quoting / truncation / null preservation / insertion
    // -------------------------------------------------------------------------

    testWidgets(
      'truncates error text longer than 80 characters with an ellipsis',
      (tester) async {
        final ctrl = _StubController();
        // 100 character message — must be truncated to 80 chars total in
        // the emitted output (77 chars of message + "...").
        final long = 'x' * 100;
        ctrl.validationErrors = {'name': long};
        final form = MagicFormData({'name': ''}, controller: ctrl);

        await tester.pumpWidget(
          MaterialApp(
            home: MagicForm(formData: form, child: const SizedBox()),
          ),
        );
        final element = _findElement(tester, SizedBox);

        final emitted = magicFormErrorsEnricher(element, RefRegistry.instance);
        expect(emitted, isNotNull);
        expect(emitted, startsWith('magicFormErrors: name="'));
        // The 100-char raw message should not appear in full.
        expect(emitted, isNot(contains('x' * 100)));
        // The emitted value should end with ellipsis-suffix + closing quote.
        expect(emitted, contains('..."'));
      },
    );

    testWidgets(
      'leaves messages shorter than 80 characters unchanged (no truncation)',
      (tester) async {
        final ctrl = _StubController();
        ctrl.validationErrors = {'url': 'invalid format'};
        final form = MagicFormData({'url': ''}, controller: ctrl);

        await tester.pumpWidget(
          MaterialApp(
            home: MagicForm(formData: form, child: const SizedBox()),
          ),
        );
        final element = _findElement(tester, SizedBox);

        final emitted = magicFormErrorsEnricher(element, RefRegistry.instance);
        expect(emitted, equals('magicFormErrors: url="invalid format"'));
      },
    );

    testWidgets('preserves insertion order across multiple error fields', (
      tester,
    ) async {
      final ctrl = _StubController();
      // Insertion order: name, url, type — emitted output must mirror.
      ctrl.validationErrors = {
        'name': 'taken',
        'url': 'invalid',
        'type': 'unknown',
      };
      final form = MagicFormData({
        'name': '',
        'url': '',
        'type': '',
      }, controller: ctrl);

      await tester.pumpWidget(
        MaterialApp(
          home: MagicForm(formData: form, child: const SizedBox()),
        ),
      );
      final element = _findElement(tester, SizedBox);

      final emitted = magicFormErrorsEnricher(element, RefRegistry.instance);
      expect(
        emitted,
        'magicFormErrors: name="taken",url="invalid",type="unknown"',
      );
    });

    testWidgets(
      'emits the empty-string sentinel quoted when a field error is empty',
      (tester) async {
        final ctrl = _StubController();
        ctrl.validationErrors = {'email': ''};
        final form = MagicFormData({'email': ''}, controller: ctrl);

        await tester.pumpWidget(
          MaterialApp(
            home: MagicForm(formData: form, child: const SizedBox()),
          ),
        );
        final element = _findElement(tester, SizedBox);

        final emitted = magicFormErrorsEnricher(element, RefRegistry.instance);
        // Empty error message stays in the map (it's still a recorded
        // error key); enricher emits the quoted empty value rather than
        // skipping the field.
        expect(emitted, equals('magicFormErrors: email=""'));
      },
    );

    testWidgets('returns null after the controller clears validation errors', (
      tester,
    ) async {
      final ctrl = _StubController();
      ctrl.validationErrors = {'email': 'Required'};
      final form = MagicFormData({'email': ''}, controller: ctrl);

      await tester.pumpWidget(
        MaterialApp(
          home: MagicForm(formData: form, child: const SizedBox()),
        ),
      );
      final element = _findElement(tester, SizedBox);

      // Clear errors mid-test — the enricher must reflect fresh state.
      ctrl.validationErrors = {};
      expect(magicFormErrorsEnricher(element, RefRegistry.instance), isNull);
    });

    testWidgets('does not retain the Element across calls (fresh-read)', (
      tester,
    ) async {
      final ctrl = _StubController();
      ctrl.validationErrors = {'email': 'Required'};
      final form = MagicFormData({'email': ''}, controller: ctrl);

      await tester.pumpWidget(
        MaterialApp(
          home: MagicForm(formData: form, child: const SizedBox()),
        ),
      );
      final firstElement = _findElement(tester, SizedBox);
      magicFormErrorsEnricher(firstElement, RefRegistry.instance);

      // Re-pump a fresh tree with a new MagicForm + controller.
      final ctrl2 = _StubController();
      ctrl2.validationErrors = {'url': 'Bad format'};
      final form2 = MagicFormData({'url': ''}, controller: ctrl2);
      await tester.pumpWidget(
        MaterialApp(
          home: MagicForm(formData: form2, child: const SizedBox()),
        ),
      );
      final secondElement = _findElement(tester, SizedBox);
      final emitted = magicFormErrorsEnricher(
        secondElement,
        RefRegistry.instance,
      );

      expect(emitted, contains('url="Bad format"'));
      expect(emitted, isNot(contains('email')));
    });

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

  // ---------------------------------------------------------------------------
  // magicControllerFlagsEnricher (Step 1.1 (b))
  // ---------------------------------------------------------------------------

  group('magicControllerFlagsEnricher', () {
    testWidgets('returns null when no controllers are registered', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final element = _findElement(tester, SizedBox);

      expect(
        magicControllerFlagsEnricher(element, RefRegistry.instance),
        isNull,
      );
    });

    testWidgets(
      'emits `magicControllerFlags: <Class>.isLoading=true,...` after setLoading',
      (tester) async {
        final ctrl = _StubController();
        ctrl.setLoading();
        Magic.put<_StubController>(ctrl);

        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        final element = _findElement(tester, SizedBox);

        final emitted = magicControllerFlagsEnricher(
          element,
          RefRegistry.instance,
        );
        expect(emitted, isNotNull);
        expect(emitted, startsWith('magicControllerFlags:'));
        expect(emitted, contains('_StubController'));
        expect(emitted, contains('isLoading=true'));
        expect(emitted, contains('isSuccess=false'));
        expect(emitted, contains('isError=false'));
        expect(emitted, contains('isEmpty=false'));
      },
    );

    testWidgets(
      'reflects all four flags after setError (isError=true, others false)',
      (tester) async {
        final ctrl = _StubController();
        ctrl.setError('boom');
        Magic.put<_StubController>(ctrl);

        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        final element = _findElement(tester, SizedBox);

        final emitted = magicControllerFlagsEnricher(
          element,
          RefRegistry.instance,
        );
        expect(emitted, contains('isLoading=false'));
        expect(emitted, contains('isSuccess=false'));
        expect(emitted, contains('isError=true'));
        expect(emitted, contains('isEmpty=false'));
      },
    );

    testWidgets(
      'preserves flag insertion order: isLoading, isSuccess, isError, isEmpty',
      (tester) async {
        final ctrl = _StubController();
        ctrl.setSuccess('ok');
        Magic.put<_StubController>(ctrl);

        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        final element = _findElement(tester, SizedBox);

        final emitted = magicControllerFlagsEnricher(
          element,
          RefRegistry.instance,
        );
        expect(emitted, isNotNull);
        // Strict ordering: the four built-ins surface in declaration order.
        expect(
          emitted,
          contains(
            'isLoading=false,isSuccess=true,isError=false,isEmpty=false',
          ),
        );
      },
    );

    testWidgets('returns null when only non-state controllers are registered', (
      tester,
    ) async {
      Magic.put<_PlainController>(_PlainController());

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final element = _findElement(tester, SizedBox);

      expect(
        magicControllerFlagsEnricher(element, RefRegistry.instance),
        isNull,
      );
    });

    testWidgets('does not retain the Element across calls (fresh-read)', (
      tester,
    ) async {
      final ctrl = _StubController();
      ctrl.setLoading();
      Magic.put<_StubController>(ctrl);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final firstElement = _findElement(tester, SizedBox);
      magicControllerFlagsEnricher(firstElement, RefRegistry.instance);

      // Flip status, re-pump a fresh tree.
      ctrl.setSuccess('done');
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final secondElement = _findElement(tester, SizedBox);

      final emitted = magicControllerFlagsEnricher(
        secondElement,
        RefRegistry.instance,
      );
      // Reads fresh state, not the stale loading value.
      expect(emitted, contains('isLoading=false'));
      expect(emitted, contains('isSuccess=true'));
    });
  });

  // ---------------------------------------------------------------------------
  // magicEchoConnectionEnricher (Step 1.2 (a))
  // ---------------------------------------------------------------------------

  group('magicEchoConnectionEnricher', () {
    testWidgets('returns null when broadcasting provider is not registered', (
      tester,
    ) async {
      // No Echo.fake() / BroadcastServiceProvider registered — Magic.bound
      // must be false, enricher must return null.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final element = _findElement(tester, SizedBox);

      expect(
        magicEchoConnectionEnricher(element, RefRegistry.instance),
        isNull,
      );
    });

    testWidgets(
      'emits `magicEchoConnection: connected` when driver is connected',
      (tester) async {
        final fake = Echo.fake();
        await fake.driver.connect();

        MagicDuskIntegration.install();

        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        final element = _findElement(tester, SizedBox);

        final emitted = magicEchoConnectionEnricher(
          element,
          RefRegistry.instance,
        );
        expect(emitted, isNotNull);
        expect(emitted, equals('magicEchoConnection: connected'));
      },
    );

    testWidgets(
      'emits `magicEchoConnection: disconnected` when driver is disconnected',
      (tester) async {
        final fake = Echo.fake();
        // Ensure driver is disconnected (default state).
        await fake.driver.disconnect();

        MagicDuskIntegration.install();

        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        final element = _findElement(tester, SizedBox);

        final emitted = magicEchoConnectionEnricher(
          element,
          RefRegistry.instance,
        );
        expect(emitted, isNotNull);
        expect(emitted, equals('magicEchoConnection: disconnected'));
      },
    );

    testWidgets('subscription cancelled and state cleared on resetForTesting', (
      tester,
    ) async {
      Echo.fake();
      MagicDuskIntegration.install();

      expect(MagicDuskIntegration.isInstalled, isTrue);

      // resetForTesting() is called in setUp via tearDown — calling it again
      // here must not throw (subscription cancel is idempotent).
      MagicDuskIntegration.resetForTesting();

      expect(MagicDuskIntegration.isInstalled, isFalse);

      // After reset, without broadcasting re-registered, enricher returns null.
      MagicApp.reset();
      Magic.flush();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final element = _findElement(tester, SizedBox);

      expect(
        magicEchoConnectionEnricher(element, RefRegistry.instance),
        isNull,
      );
    });

    testWidgets(
      'emits `magicEchoConnection: connected` after _lastEchoState is set via stream event',
      (tester) async {
        // Use a StreamController to push a state event and verify the
        // module-private cache is updated.
        final controller = StreamController<BroadcastConnectionState>();
        final fakeManager = _StreamableFakeBroadcastManager(
          stateStream: controller.stream,
          connected: true,
        );

        Magic.app.setInstance('broadcasting', fakeManager);

        MagicDuskIntegration.install();

        // Push a connected event into the stream.
        controller.add(BroadcastConnectionState.connected);
        await tester.pump(); // let stream subscriber fire

        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        final element = _findElement(tester, SizedBox);

        final emitted = magicEchoConnectionEnricher(
          element,
          RefRegistry.instance,
        );
        expect(emitted, equals('magicEchoConnection: connected'));

        await controller.close();
      },
    );
  });

  // ---------------------------------------------------------------------------
  // magicGateResultsAllEnricher (Step 1.2 (b))
  // ---------------------------------------------------------------------------

  group('magicGateResultsAllEnricher', () {
    testWidgets('returns null when no gate checks have been run', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final element = _findElement(tester, SizedBox);

      expect(
        magicGateResultsAllEnricher(element, RefRegistry.instance),
        isNull,
      );
    });

    testWidgets(
      'returns null when abilities are defined but none have been checked',
      (tester) async {
        Gate.define('view-dashboard', (user, _) => true);
        // No Gate.allows() call — lastResult must be null for all abilities.

        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        final element = _findElement(tester, SizedBox);

        expect(
          magicGateResultsAllEnricher(element, RefRegistry.instance),
          isNull,
        );
      },
    );

    testWidgets(
      'emits `magicGateResultsAll: ability=allowed` after a single allowed check',
      (tester) async {
        Auth.fake(user: _user());
        Gate.define('monitors.destroy', (user, _) => true);
        Gate.allows('monitors.destroy');

        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        final element = _findElement(tester, SizedBox);

        final emitted = magicGateResultsAllEnricher(
          element,
          RefRegistry.instance,
        );
        expect(emitted, isNotNull);
        expect(emitted, startsWith('magicGateResultsAll:'));
        expect(emitted, contains('monitors.destroy=allowed'));
      },
    );

    testWidgets(
      'emits `magicGateResultsAll: ability=denied` after a denied check',
      (tester) async {
        Auth.fake(user: _user());
        Gate.define('admin-only', (user, _) => false);
        Gate.allows('admin-only');

        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        final element = _findElement(tester, SizedBox);

        final emitted = magicGateResultsAllEnricher(
          element,
          RefRegistry.instance,
        );
        expect(emitted, isNotNull);
        expect(emitted, contains('admin-only=denied'));
      },
    );

    testWidgets(
      'truncates to 5 most recently checked abilities when more are cached',
      (tester) async {
        Auth.fake(user: _user());
        for (int i = 1; i <= 7; i++) {
          Gate.define('ability.$i', (user, _) => true);
          Gate.allows('ability.$i');
        }

        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        final element = _findElement(tester, SizedBox);

        final emitted = magicGateResultsAllEnricher(
          element,
          RefRegistry.instance,
        );
        expect(emitted, isNotNull);
        // Must contain at most 5 entries (comma-separated).
        final parts = emitted!
            .replaceFirst('magicGateResultsAll: ', '')
            .split(',');
        expect(parts, hasLength(lessThanOrEqualTo(5)));
      },
    );

    testWidgets('returns null after Gate.manager.flush() clears the cache', (
      tester,
    ) async {
      Auth.fake(user: _user());
      Gate.define('view', (user, _) => true);
      Gate.allows('view');

      Gate.manager.flush();

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final element = _findElement(tester, SizedBox);

      expect(
        magicGateResultsAllEnricher(element, RefRegistry.instance),
        isNull,
      );
    });

    testWidgets(
      'does not retain the Element across calls (fresh-read after flush)',
      (tester) async {
        Auth.fake(user: _user());
        Gate.define('monitors.update', (user, _) => true);
        Gate.allows('monitors.update');

        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        final firstElement = _findElement(tester, SizedBox);
        final first = magicGateResultsAllEnricher(
          firstElement,
          RefRegistry.instance,
        );
        expect(first, contains('monitors.update=allowed'));

        // Flush cache and re-check with a fresh element.
        Gate.manager.flush();
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        final secondElement = _findElement(tester, SizedBox);
        final second = magicGateResultsAllEnricher(
          secondElement,
          RefRegistry.instance,
        );
        // No results left after flush.
        expect(second, isNull);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // magicRouteParamsEnricher (Step 1.1 (c))
  // ---------------------------------------------------------------------------

  group('magicRouteParamsEnricher', () {
    testWidgets('returns null when no route is active (router not built)', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final element = _findElement(tester, SizedBox);

      expect(magicRouteParamsEnricher(element, RefRegistry.instance), isNull);
    });

    testWidgets(
      'returns null when route has neither path params nor query params',
      (tester) async {
        MagicRoute.page('/', () => const SizedBox());

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
        );
        await tester.pumpAndSettle();
        final element = _findElement(tester, SizedBox);

        expect(magicRouteParamsEnricher(element, RefRegistry.instance), isNull);
      },
    );

    testWidgets('emits `magicRouteParams: id=42` for a single path parameter', (
      tester,
    ) async {
      MagicRoute.page('/', () => const SizedBox());
      MagicRoute.page('/monitors/:id', () => const SizedBox());

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
      );
      await tester.pumpAndSettle();

      MagicRouter.instance.to('/monitors/42');
      await tester.pumpAndSettle();
      final element = _findElement(tester, SizedBox);

      final emitted = magicRouteParamsEnricher(element, RefRegistry.instance);
      expect(emitted, isNotNull);
      expect(emitted, startsWith('magicRouteParams:'));
      expect(emitted, contains('id=42'));
    });

    testWidgets('emits both path params and query params joined by comma', (
      tester,
    ) async {
      MagicRoute.page('/', () => const SizedBox());
      MagicRoute.page('/monitors/:id', () => const SizedBox());

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
      );
      await tester.pumpAndSettle();

      MagicRouter.instance.to(
        '/monitors/42',
        queryParameters: {'tab': 'metrics'},
      );
      await tester.pumpAndSettle();
      final element = _findElement(tester, SizedBox);

      final emitted = magicRouteParamsEnricher(element, RefRegistry.instance);
      expect(emitted, isNotNull);
      expect(emitted, contains('id=42'));
      expect(emitted, contains('tab=metrics'));
      expect(emitted, contains(','));
    });

    testWidgets('preserves insertion order: path params before query params', (
      tester,
    ) async {
      MagicRoute.page('/', () => const SizedBox());
      MagicRoute.page('/teams/:team/monitors/:id', () => const SizedBox());

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
      );
      await tester.pumpAndSettle();

      MagicRouter.instance.to(
        '/teams/7/monitors/42',
        queryParameters: {'tab': 'metrics', 'view': 'grid'},
      );
      await tester.pumpAndSettle();
      final element = _findElement(tester, SizedBox);

      final emitted = magicRouteParamsEnricher(element, RefRegistry.instance);
      expect(emitted, isNotNull);
      // Path params (team, id) appear before query params (tab, view).
      final indexTeam = emitted!.indexOf('team=7');
      final indexId = emitted.indexOf('id=42');
      final indexTab = emitted.indexOf('tab=metrics');
      expect(indexTeam, isNonNegative);
      expect(indexId, greaterThan(indexTeam));
      expect(indexTab, greaterThan(indexId));
    });

    testWidgets('does not retain the Element across calls (fresh-read)', (
      tester,
    ) async {
      MagicRoute.page('/', () => const SizedBox());
      MagicRoute.page('/monitors/:id', () => const SizedBox());

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
      );
      await tester.pumpAndSettle();

      MagicRouter.instance.to('/monitors/42');
      await tester.pumpAndSettle();
      final firstElement = _findElement(tester, SizedBox);
      final first = magicRouteParamsEnricher(
        firstElement,
        RefRegistry.instance,
      );
      expect(first, contains('id=42'));

      // Navigate to a new id — enricher must reflect the fresh state.
      MagicRouter.instance.to('/monitors/99');
      await tester.pumpAndSettle();
      final secondElement = _findElement(tester, SizedBox);
      final second = magicRouteParamsEnricher(
        secondElement,
        RefRegistry.instance,
      );
      expect(second, contains('id=99'));
      expect(second, isNot(contains('id=42')));
    });
  });

  // ---------------------------------------------------------------------------
  // magicRecentHttpEnricher (Step 1.3 (a))
  // ---------------------------------------------------------------------------

  group('magicRecentHttpEnricher', () {
    setUp(() {
      TelescopeStore.resetForTesting();
    });

    tearDown(() {
      TelescopeStore.resetForTesting();
    });

    testWidgets(
      'returns null when the telescope http buffer is empty (also covers the '
      'telescope-absent fallback: guards the try/catch path with a graceful null)',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        final element = _findElement(tester, SizedBox);

        // Buffer empty after resetForTesting — the static call returns [] and
        // the enricher must coalesce to null (no throw, no empty-suffix emit).
        expect(magicRecentHttpEnricher(element, RefRegistry.instance), isNull);
      },
    );

    testWidgets(
      'emits `magicRecentHttp: METHOD url status durationMs` for non-empty buffer',
      (tester) async {
        TelescopeStore.recordHttp(
          HttpRequestRecord(
            url: '/monitors',
            method: 'GET',
            statusCode: 200,
            durationMs: 142,
            isError: false,
            timestamp: DateTime.now(),
          ),
        );

        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        final element = _findElement(tester, SizedBox);

        final emitted = magicRecentHttpEnricher(element, RefRegistry.instance);
        expect(emitted, isNotNull);
        expect(emitted, startsWith('magicRecentHttp:'));
        expect(emitted, contains('GET /monitors 200 142ms'));
      },
    );

    testWidgets('truncates URLs longer than 40 characters with an ellipsis', (
      tester,
    ) async {
      // 60-char URL — must be cropped to 40 chars total in emitted output
      // (37 chars + "..." suffix per the 40-char budget).
      final long = '/api/v1/${'x' * 80}/show';
      TelescopeStore.recordHttp(
        HttpRequestRecord(
          url: long,
          method: 'POST',
          statusCode: 422,
          durationMs: 89,
          isError: true,
          timestamp: DateTime.now(),
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final element = _findElement(tester, SizedBox);

      final emitted = magicRecentHttpEnricher(element, RefRegistry.instance);
      expect(emitted, isNotNull);
      // The full raw URL must not appear verbatim.
      expect(emitted, isNot(contains(long)));
      // The truncation marker is present and the trailing status segment too.
      expect(emitted, contains('...'));
      expect(emitted, contains(' 422 89ms'));
    });

    testWidgets(
      'preserves insertion order across multiple http records and caps at 5',
      (tester) async {
        // Insert 7 records — recentHttp(limit: 5) keeps the latest 5 in
        // insertion order (FIFO over the buffer).
        for (int i = 1; i <= 7; i++) {
          TelescopeStore.recordHttp(
            HttpRequestRecord(
              url: '/r$i',
              method: 'GET',
              statusCode: 200,
              durationMs: i,
              isError: false,
              timestamp: DateTime.now(),
            ),
          );
        }

        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        final element = _findElement(tester, SizedBox);

        final emitted = magicRecentHttpEnricher(element, RefRegistry.instance);
        expect(emitted, isNotNull);
        final parts = emitted!.replaceFirst('magicRecentHttp: ', '').split(',');
        expect(parts, hasLength(5));
        // Oldest two (/r1, /r2) are dropped; /r3..r7 survive in order.
        expect(parts.first, contains('/r3'));
        expect(parts.last, contains('/r7'));
        expect(emitted, isNot(contains('/r1 ')));
        expect(emitted, isNot(contains('/r2 ')));
      },
    );

    testWidgets('joins multiple records with a single comma separator', (
      tester,
    ) async {
      TelescopeStore.recordHttp(
        HttpRequestRecord(
          url: '/a',
          method: 'GET',
          statusCode: 200,
          durationMs: 10,
          isError: false,
          timestamp: DateTime.now(),
        ),
      );
      TelescopeStore.recordHttp(
        HttpRequestRecord(
          url: '/b',
          method: 'POST',
          statusCode: 201,
          durationMs: 20,
          isError: false,
          timestamp: DateTime.now(),
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final element = _findElement(tester, SizedBox);

      final emitted = magicRecentHttpEnricher(element, RefRegistry.instance);
      expect(
        emitted,
        equals('magicRecentHttp: GET /a 200 10ms,POST /b 201 20ms'),
      );
    });

    testWidgets('does not retain the Element across calls (fresh-read)', (
      tester,
    ) async {
      TelescopeStore.recordHttp(
        HttpRequestRecord(
          url: '/first',
          method: 'GET',
          statusCode: 200,
          durationMs: 5,
          isError: false,
          timestamp: DateTime.now(),
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final firstElement = _findElement(tester, SizedBox);
      final first = magicRecentHttpEnricher(firstElement, RefRegistry.instance);
      expect(first, contains('/first'));

      // Append a fresh record, re-pump a fresh element — second read must
      // surface BOTH entries (no stale element retention, fresh buffer read).
      TelescopeStore.recordHttp(
        HttpRequestRecord(
          url: '/second',
          method: 'POST',
          statusCode: 201,
          durationMs: 8,
          isError: false,
          timestamp: DateTime.now(),
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final secondElement = _findElement(tester, SizedBox);
      final second = magicRecentHttpEnricher(
        secondElement,
        RefRegistry.instance,
      );
      expect(second, contains('/first'));
      expect(second, contains('/second'));
    });
  });

  // ---------------------------------------------------------------------------
  // magicRecentLogsEnricher (Step 1.3 (b))
  // ---------------------------------------------------------------------------

  group('magicRecentLogsEnricher', () {
    setUp(() {
      TelescopeStore.resetForTesting();
    });

    tearDown(() {
      TelescopeStore.resetForTesting();
    });

    testWidgets(
      'returns null when the telescope log buffer is empty (also covers the '
      'telescope-absent fallback)',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        final element = _findElement(tester, SizedBox);

        expect(magicRecentLogsEnricher(element, RefRegistry.instance), isNull);
      },
    );

    testWidgets(
      'emits `magicRecentLogs: [WARN] msg,[ERROR] msg` for warning/severe entries',
      (tester) async {
        TelescopeStore.recordLog(
          LogRecordEntry(
            level: 'WARNING',
            levelValue: 900,
            message: 'Auth refresh failed',
            loggerName: 'auth',
            time: DateTime.now(),
          ),
        );
        TelescopeStore.recordLog(
          LogRecordEntry(
            level: 'SEVERE',
            levelValue: 1000,
            message: 'Echo disconnect',
            loggerName: 'echo',
            time: DateTime.now(),
          ),
        );

        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        final element = _findElement(tester, SizedBox);

        final emitted = magicRecentLogsEnricher(element, RefRegistry.instance);
        expect(emitted, isNotNull);
        expect(emitted, startsWith('magicRecentLogs:'));
        expect(emitted, contains('[WARN] Auth refresh failed'));
        expect(emitted, contains('[ERROR] Echo disconnect'));
      },
    );

    testWidgets(
      'filters out logs below the WARNING threshold (info/fine are dropped)',
      (tester) async {
        TelescopeStore.recordLog(
          LogRecordEntry(
            level: 'INFO',
            levelValue: 800,
            message: 'noise',
            loggerName: 'app',
            time: DateTime.now(),
          ),
        );
        TelescopeStore.recordLog(
          LogRecordEntry(
            level: 'WARNING',
            levelValue: 900,
            message: 'kept',
            loggerName: 'app',
            time: DateTime.now(),
          ),
        );

        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        final element = _findElement(tester, SizedBox);

        final emitted = magicRecentLogsEnricher(element, RefRegistry.instance);
        expect(emitted, isNotNull);
        expect(emitted, contains('kept'));
        expect(emitted, isNot(contains('noise')));
      },
    );

    testWidgets(
      'truncates messages longer than 50 characters with an ellipsis',
      (tester) async {
        final long = 'y' * 80;
        TelescopeStore.recordLog(
          LogRecordEntry(
            level: 'WARNING',
            levelValue: 900,
            message: long,
            loggerName: 'app',
            time: DateTime.now(),
          ),
        );

        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        final element = _findElement(tester, SizedBox);

        final emitted = magicRecentLogsEnricher(element, RefRegistry.instance);
        expect(emitted, isNotNull);
        // The raw 80-char string must not survive verbatim.
        expect(emitted, isNot(contains(long)));
        // The ellipsis suffix is present.
        expect(emitted, contains('...'));
        expect(emitted, startsWith('magicRecentLogs: [WARN]'));
      },
    );

    testWidgets('preserves insertion order and caps at 3 entries', (
      tester,
    ) async {
      for (int i = 1; i <= 5; i++) {
        TelescopeStore.recordLog(
          LogRecordEntry(
            level: 'WARNING',
            levelValue: 900,
            message: 'msg$i',
            loggerName: 'app',
            time: DateTime.now(),
          ),
        );
      }

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final element = _findElement(tester, SizedBox);

      final emitted = magicRecentLogsEnricher(element, RefRegistry.instance);
      expect(emitted, isNotNull);
      final parts = emitted!.replaceFirst('magicRecentLogs: ', '').split(',');
      expect(parts, hasLength(3));
      // recentLogs(limit: 3) keeps the latest 3 in insertion order.
      expect(parts.first, contains('msg3'));
      expect(parts.last, contains('msg5'));
    });

    testWidgets('does not retain the Element across calls (fresh-read)', (
      tester,
    ) async {
      TelescopeStore.recordLog(
        LogRecordEntry(
          level: 'WARNING',
          levelValue: 900,
          message: 'first',
          loggerName: 'app',
          time: DateTime.now(),
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final firstElement = _findElement(tester, SizedBox);
      magicRecentLogsEnricher(firstElement, RefRegistry.instance);

      // Clear and re-record — second read must reflect fresh state.
      TelescopeStore.resetForTesting();
      TelescopeStore.recordLog(
        LogRecordEntry(
          level: 'SEVERE',
          levelValue: 1000,
          message: 'fresh',
          loggerName: 'app',
          time: DateTime.now(),
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final secondElement = _findElement(tester, SizedBox);
      final emitted = magicRecentLogsEnricher(
        secondElement,
        RefRegistry.instance,
      );
      expect(emitted, contains('fresh'));
      expect(emitted, isNot(contains('first')));
    });
  });

  // ---------------------------------------------------------------------------
  // magicRecentExceptionsEnricher (Step 1.3 (c))
  // ---------------------------------------------------------------------------

  group('magicRecentExceptionsEnricher', () {
    setUp(() {
      TelescopeStore.resetForTesting();
    });

    tearDown(() {
      TelescopeStore.resetForTesting();
    });

    testWidgets(
      'returns null when the telescope exceptions buffer is empty (also covers '
      'the telescope-absent fallback)',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        final element = _findElement(tester, SizedBox);

        expect(
          magicRecentExceptionsEnricher(element, RefRegistry.instance),
          isNull,
        );
      },
    );

    testWidgets(
      'emits `magicRecentExceptions: Type at file.dart:line` for non-empty buffer',
      (tester) async {
        TelescopeStore.recordException(
          ExceptionRecord(
            exceptionType: 'HttpException',
            message: 'request failed',
            time: DateTime.now(),
            stackTrace:
                '#0      ApiClient.get (package:app/api.dart:142:5)\n'
                '#1      Other.fn (package:app/other.dart:50:3)',
          ),
        );

        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        final element = _findElement(tester, SizedBox);

        final emitted = magicRecentExceptionsEnricher(
          element,
          RefRegistry.instance,
        );
        expect(emitted, isNotNull);
        expect(emitted, startsWith('magicRecentExceptions:'));
        expect(emitted, contains('HttpException'));
        expect(emitted, contains('api.dart:142'));
      },
    );

    testWidgets(
      'truncates to type plus first line of stackTrace only (drops deeper frames)',
      (tester) async {
        TelescopeStore.recordException(
          ExceptionRecord(
            exceptionType: 'FormatException',
            message: 'bad input',
            time: DateTime.now(),
            stackTrace:
                '#0      Parser.parse (package:app/parser.dart:88:1)\n'
                '#1      ThisShouldNotAppear.fn (package:app/secret.dart:99:9)',
          ),
        );

        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        final element = _findElement(tester, SizedBox);

        final emitted = magicRecentExceptionsEnricher(
          element,
          RefRegistry.instance,
        );
        expect(emitted, isNotNull);
        expect(emitted, contains('parser.dart:88'));
        // Deeper frames must not leak into the snapshot.
        expect(emitted, isNot(contains('secret.dart')));
        expect(emitted, isNot(contains('ThisShouldNotAppear')));
      },
    );

    testWidgets(
      'falls back to the type only when the stackTrace is null or unparseable',
      (tester) async {
        TelescopeStore.recordException(
          ExceptionRecord(
            exceptionType: 'StateError',
            message: 'no state',
            time: DateTime.now(),
            stackTrace: null,
          ),
        );

        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        final element = _findElement(tester, SizedBox);

        final emitted = magicRecentExceptionsEnricher(
          element,
          RefRegistry.instance,
        );
        expect(emitted, isNotNull);
        expect(emitted, contains('StateError'));
        // No bogus ` at <null>` suffix when there is no stack location.
        expect(emitted, isNot(contains('null')));
      },
    );

    testWidgets('preserves insertion order and caps at 3 entries', (
      tester,
    ) async {
      for (int i = 1; i <= 5; i++) {
        TelescopeStore.recordException(
          ExceptionRecord(
            exceptionType: 'E$i',
            message: 'msg$i',
            time: DateTime.now(),
            stackTrace: '#0 Fn (package:app/file$i.dart:$i:1)',
          ),
        );
      }

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final element = _findElement(tester, SizedBox);

      final emitted = magicRecentExceptionsEnricher(
        element,
        RefRegistry.instance,
      );
      expect(emitted, isNotNull);
      final parts = emitted!
          .replaceFirst('magicRecentExceptions: ', '')
          .split(',');
      expect(parts, hasLength(3));
      // recentExceptions(limit: 3) keeps the latest 3 in insertion order.
      expect(parts.first, contains('E3'));
      expect(parts.last, contains('E5'));
    });

    testWidgets('does not retain the Element across calls (fresh-read)', (
      tester,
    ) async {
      TelescopeStore.recordException(
        ExceptionRecord(
          exceptionType: 'FirstError',
          message: 'first',
          time: DateTime.now(),
          stackTrace: '#0 Fn (package:app/first.dart:1:1)',
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final firstElement = _findElement(tester, SizedBox);
      final first = magicRecentExceptionsEnricher(
        firstElement,
        RefRegistry.instance,
      );
      expect(first, contains('FirstError'));

      // Clear and re-record — second element must read the fresh buffer state.
      TelescopeStore.resetForTesting();
      TelescopeStore.recordException(
        ExceptionRecord(
          exceptionType: 'SecondError',
          message: 'second',
          time: DateTime.now(),
          stackTrace: '#0 Fn (package:app/second.dart:2:2)',
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final secondElement = _findElement(tester, SizedBox);
      final second = magicRecentExceptionsEnricher(
        secondElement,
        RefRegistry.instance,
      );
      expect(second, contains('SecondError'));
      expect(second, isNot(contains('FirstError')));
    });
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

/// A [BroadcastManager] variant whose driver exposes a controllable
/// [connectionState] stream, used by the echo-enricher subscribe-lifecycle test.
///
/// Accepts an external [stateStream] so the test can push state events via a
/// [StreamController] and a [connected] flag that backs [isConnected].
class _StreamableFakeBroadcastManager extends BroadcastManager {
  _StreamableFakeBroadcastManager({
    required Stream<BroadcastConnectionState> stateStream,
    required bool connected,
  }) : _driver = _StreamableFakeBroadcastDriver(
         stateStream: stateStream,
         connected: connected,
       );

  final _StreamableFakeBroadcastDriver _driver;

  @override
  BroadcastDriver connection([String? name]) => _driver;
}

class _StreamableFakeBroadcastDriver implements BroadcastDriver {
  _StreamableFakeBroadcastDriver({
    required Stream<BroadcastConnectionState> stateStream,
    required bool connected,
  }) : _stateStream = stateStream,
       _connected = connected;

  final Stream<BroadcastConnectionState> _stateStream;
  final bool _connected;

  @override
  bool get isConnected => _connected;

  @override
  String? get socketId => _connected ? 'fake-socket-id' : null;

  @override
  Stream<BroadcastConnectionState> get connectionState => _stateStream;

  @override
  Stream<void> get onReconnect => const Stream.empty();

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  BroadcastChannel channel(String name) => throw UnimplementedError();

  @override
  BroadcastChannel private(String name) => throw UnimplementedError();

  @override
  BroadcastPresenceChannel join(String name) => throw UnimplementedError();

  @override
  void leave(String name) {}

  @override
  void addInterceptor(BroadcastInterceptor interceptor) {}
}
