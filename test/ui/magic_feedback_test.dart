import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// Covers the overlay-delivered toast path: it must render in a Scaffold-less
/// (Wind-only) view, replace a previous toast, and auto-dismiss without the
/// late timer throwing on an already-detached entry.
void main() {
  setUp(() => Magic.flush());
  tearDown(() => Magic.flush());

  // WindTheme sits ABOVE MaterialApp so the Navigator overlay (where the toast
  // is inserted) can resolve it; the home is Scaffold-less on purpose.
  Widget harness() {
    return WindTheme(
      data: WindThemeData(),
      child: MaterialApp(
        navigatorKey: MagicRouter.instance.navigatorKey,
        home: const SizedBox.shrink(),
      ),
    );
  }

  testWidgets('shows in a Scaffold-less view and auto-dismisses cleanly', (
    tester,
  ) async {
    await tester.pumpWidget(harness());

    MagicFeedback.info('Heads up', 'It works without a Scaffold');
    await tester.pump();

    expect(find.text('Heads up'), findsOneWidget);
    expect(find.text('It works without a Scaffold'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Auto-dismiss after the duration; the late timer must not throw on the
    // (now removed) entry.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Heads up'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a second toast replaces the first', (tester) async {
    await tester.pumpWidget(harness());

    MagicFeedback.success('First', '');
    await tester.pump();
    expect(find.text('First'), findsOneWidget);

    MagicFeedback.error('Second', '');
    await tester.pump();
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
