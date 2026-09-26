import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// Blocks on [gate] until the test completes it, so a test can observe
/// [RunsActions.isRunning] while the action is still in flight.
///
/// The output type is [Object?] rather than `void`, purely so the test can
/// assign a call's result to a variable and assert on it: a `void`-typed
/// expression cannot be used in most expression positions in Dart.
class _Blocks extends MagicAction<int, Object?> {
  _Blocks(this.gate);

  final Completer<void> gate;

  @override
  Future<Object?> handle(int input) async {
    await gate.future;
    return null;
  }
}

/// Throws whatever [error] is, so both the [ValidationException] path and
/// the generic-failure path can be exercised through the same shape.
class _Fails extends MagicAction<int, Object?> {
  const _Fails(this.error);

  final Object error;

  @override
  Future<Object?> handle(int input) async => throw error;
}

/// Succeeds immediately with a non-null value, so a caller can tell a real
/// completion apart from the `null` [RunsActions.runAction] answers on
/// refusal or failure.
class _Returns extends MagicAction<int, String> {
  const _Returns();

  @override
  Future<String> handle(int input) async => 'done';
}

class _ValidatingController extends MagicController
    with ValidatesRequests, RunsActions {}

/// A [RunsActions] host that does NOT mix in [ValidatesRequests], to prove
/// [RunsActions.runAction] never assumes the error bag is there.
class _PlainController extends MagicController with RunsActions {}

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });

  group('RunsActions.isRunning / running-key guard', () {
    test('a key is running only while its action is in flight', () async {
      final controller = _ValidatingController();
      final gate = Completer<void>();

      expect(controller.isRunning('k'), isFalse);

      final future = controller.runAction(_Blocks(gate), 0, key: 'k');
      expect(controller.isRunning('k'), isTrue);

      gate.complete();
      await future;
      expect(controller.isRunning('k'), isFalse);
    });

    test('refuses a second run under the same key, returning null', () async {
      final controller = _ValidatingController();
      final gate = Completer<void>();
      final action = _Blocks(gate);

      final first = controller.runAction(action, 0, key: 'k');
      final second = await controller.runAction(action, 0, key: 'k');

      expect(second, isNull);

      gate.complete();
      await first;
    });

    test('two different keys run independently', () async {
      final controller = _ValidatingController();
      final gateA = Completer<void>();
      final gateB = Completer<void>();

      final futureA = controller.runAction(_Blocks(gateA), 0, key: 'a');
      final futureB = controller.runAction(_Blocks(gateB), 0, key: 'b');

      expect(controller.isRunning('a'), isTrue);
      expect(controller.isRunning('b'), isTrue);

      gateA.complete();
      gateB.complete();
      await futureA;
      await futureB;
    });

    test('an unkeyed call and a keyed call do not block each other', () async {
      final controller = _ValidatingController();
      final gate = Completer<void>();

      final unkeyed = controller.runAction(_Blocks(gate), 0);
      expect(controller.isRunning(), isTrue);
      expect(controller.isRunning('k'), isFalse);

      // A distinct explicit key is unaffected by the still-running default
      // (unkeyed) slot: it actually runs and answers its real result, not
      // the `null` a refusal would answer.
      final keyedResult = await controller.runAction(
        const _Returns(),
        0,
        key: 'k',
      );
      expect(keyedResult, 'done');

      gate.complete();
      await unkeyed;
    });
  });

  group('RunsActions.runAction, ValidationException', () {
    test(
      'paints the errors onto a ValidatesRequests controller and returns null',
      () async {
        final controller = _ValidatingController();

        final result = await controller.runAction(
          _Fails(ValidationException({'name': 'Required.'})),
          0,
        );

        expect(result, isNull);
        expect(controller.getError('name'), 'Required.');
        expect(controller.isRunning(), isFalse);
      },
    );

    test('never throws on a controller without ValidatesRequests', () async {
      final controller = _PlainController();

      final result = await controller.runAction(
        _Fails(ValidationException({'name': 'Required.'})),
        0,
      );

      expect(result, isNull);
    });
  });

  group('RunsActions.runAction, other failures', () {
    Widget harness() {
      return WindTheme(
        data: WindThemeData(),
        child: MaterialApp(
          navigatorKey: MagicRouter.instance.navigatorKey,
          home: const SizedBox.shrink(),
        ),
      );
    }

    testWidgets('shows a toast titled with the fallback translation key', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      final controller = _ValidatingController();

      final result = await controller.runAction(_Fails(Exception('boom')), 0);
      await tester.pump();

      expect(result, isNull);
      expect(find.text('common.error_occurred'), findsOneWidget);

      // Settle the toast's auto-dismiss timer so it does not outlive the
      // test (see magic_feedback_test.dart for the same pattern).
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('failureMessage overrides the exception text in the toast', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      final controller = _ValidatingController();

      await controller.runAction(
        _Fails(Exception('boom')),
        0,
        failureMessage: 'Could not pause the monitor.',
      );
      await tester.pump();

      expect(find.text('Could not pause the monitor.'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('onFailure replaces the default toast with the caller\'s own', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      final controller = _ValidatingController();
      Object? seen;

      final result = await controller.runAction(
        _Fails(Exception('boom')),
        0,
        onFailure: (Object error) => seen = error,
      );
      await tester.pump();

      expect(result, isNull);
      expect(seen, isA<Exception>());
      expect(find.text('common.error_occurred'), findsNothing);
    });
  });
}
