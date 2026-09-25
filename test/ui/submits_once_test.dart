import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/ui/submits_once.dart';

/// A form-shaped harness that deliberately does NOT wire [SubmitsOnce.isSubmitting]
/// to its button.
///
/// This is the case the mixin's own early return exists for. A properly wired
/// button drops its `onTap` while loading, so the tap never arrives in the
/// first place, which makes the two guards indistinguishable through the UI: a
/// test that taps a properly wired button passes with either one alone.
/// Testing the early return therefore means removing the outer guard, which is
/// also the realistic failure mode, a caller wiring the handler and forgetting
/// the loading prop.
class _UnwiredForm extends StatefulWidget {
  final Future<void> Function() onSubmit;

  const _UnwiredForm({required this.onSubmit});

  @override
  State<_UnwiredForm> createState() => _UnwiredFormState();
}

class _UnwiredFormState extends State<_UnwiredForm>
    with SubmitsOnce<_UnwiredForm> {
  @override
  Widget build(BuildContext context) {
    // `opaque` because the child is an empty box: the default `deferToChild`
    // has nothing to hit test against, so the tap would never arrive.
    //
    // The `catchError` stands in for what a real caller does with a failed
    // write (surfacing it as a toast). It is here so the throw does not escape
    // as an unhandled async error and derail the test; what is under test is
    // that the mixin re-arms afterwards, not who reports the failure.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => submitOnce(widget.onSubmit).catchError((Object _) {}),
      child: const SizedBox(width: 100, height: 40),
    );
  }
}

void main() {
  testWidgets('a second call during the flight is dropped', (tester) async {
    var submits = 0;
    final Completer<void> inFlight = Completer<void>();

    await tester.pumpWidget(
      _UnwiredForm(
        onSubmit: () async {
          submits++;
          await inFlight.future;
        },
      ),
    );

    await tester.tap(find.byType(SizedBox));
    await tester.pump();
    await tester.tap(find.byType(SizedBox));
    await tester.pump();

    expect(submits, 1, reason: 'the in-flight guard must drop the second call');

    inFlight.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('the guard re-arms once the flight completes', (tester) async {
    var submits = 0;
    Completer<void> inFlight = Completer<void>();

    await tester.pumpWidget(
      _UnwiredForm(
        onSubmit: () async {
          submits++;
          await inFlight.future;
        },
      ),
    );

    await tester.tap(find.byType(SizedBox));
    await tester.pump();
    inFlight.complete();
    await tester.pumpAndSettle();

    // A dropped second call must not become a permanently dead button: the
    // operator who fixed a validation error and tapped again gets their submit.
    inFlight = Completer<void>();
    await tester.tap(find.byType(SizedBox));
    await tester.pump();

    expect(submits, 2);

    inFlight.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('a throwing submit re-arms instead of spinning forever', (
    tester,
  ) async {
    // The reset lives in a `finally` for this: a submit that throws must leave
    // the button usable. The throw itself still propagates, because swallowing
    // it here would hide a failure the handler is responsible for surfacing.
    var submits = 0;

    await tester.pumpWidget(
      _UnwiredForm(
        onSubmit: () async {
          submits++;
          throw StateError('write failed');
        },
      ),
    );

    await tester.tap(find.byType(SizedBox));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SizedBox));
    await tester.pumpAndSettle();

    expect(submits, 2, reason: 'a failed submit must not lock the button');
  });
}
