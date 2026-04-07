import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    TitleManager.reset();
  });

  group('MagicTitle — mount behavior', () {
    testWidgets('sets override on mount', (tester) async {
      final titles = <String>[];
      TitleManager.configure(onTitleChanged: (title, _) => titles.add(title));
      TitleManager.instance.setAppTitle('App');

      await tester.pumpWidget(
        MaterialApp(
          home: MagicTitle(title: 'Page A', child: const Text('content')),
        ),
      );

      expect(TitleManager.instance.currentTitle, 'Page A');
    });

    testWidgets('updates on title change', (tester) async {
      final titles = <String>[];
      TitleManager.configure(onTitleChanged: (title, _) => titles.add(title));
      TitleManager.instance.setAppTitle('App');

      await tester.pumpWidget(
        MaterialApp(
          home: MagicTitle(title: 'Page A', child: const Text('content')),
        ),
      );

      expect(TitleManager.instance.currentTitle, 'Page A');

      await tester.pumpWidget(
        MaterialApp(
          home: MagicTitle(title: 'Page B', child: const Text('content')),
        ),
      );

      expect(TitleManager.instance.currentTitle, 'Page B');
    });

    testWidgets('clears override on dispose', (tester) async {
      final titles = <String>[];
      TitleManager.configure(onTitleChanged: (title, _) => titles.add(title));
      TitleManager.instance.setAppTitle('App');

      await tester.pumpWidget(
        MaterialApp(
          home: MagicTitle(title: 'Page A', child: const Text('content')),
        ),
      );

      expect(TitleManager.instance.currentTitle, 'Page A');

      // Remove MagicTitle from the tree — triggers dispose.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // Override cleared — falls back to appTitle.
      expect(TitleManager.instance.currentTitle, 'App');
    });
  });

  group('MagicTitle — didUpdateWidget', () {
    testWidgets('fires callback with correct sequence on title change', (
      tester,
    ) async {
      final titles = <String>[];
      TitleManager.configure(onTitleChanged: (title, _) => titles.add(title));
      TitleManager.instance.setAppTitle('App');

      await tester.pumpWidget(
        MaterialApp(
          home: MagicTitle(title: 'First', child: const Text('content')),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MagicTitle(title: 'Second', child: const Text('content')),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MagicTitle(title: 'Third', child: const Text('content')),
        ),
      );

      // Sequence: setAppTitle('App'), setOverride('First'),
      //           setOverride('Second'), setOverride('Third')
      expect(titles, contains('First'));
      expect(titles, contains('Second'));
      expect(titles, contains('Third'));
      expect(TitleManager.instance.currentTitle, 'Third');
    });

    testWidgets('does not fire when title stays the same', (tester) async {
      int callCount = 0;
      TitleManager.configure(onTitleChanged: (_, _) => callCount++);
      TitleManager.instance.setAppTitle('App');

      await tester.pumpWidget(
        MaterialApp(
          home: MagicTitle(title: 'Same', child: const Text('v1')),
        ),
      );

      final countAfterMount = callCount;

      // Re-pump with same title but different child — should not trigger.
      await tester.pumpWidget(
        MaterialApp(
          home: MagicTitle(title: 'Same', child: const Text('v2')),
        ),
      );

      expect(callCount, countAfterMount);
    });
  });

  group('MagicTitle — suffix integration', () {
    testWidgets('effective title includes suffix when set', (tester) async {
      final titles = <String>[];
      TitleManager.configure(onTitleChanged: (title, _) => titles.add(title));
      TitleManager.instance
        ..setAppTitle('App')
        ..setSuffix('MySite');

      await tester.pumpWidget(
        MaterialApp(
          home: MagicTitle(title: 'Dashboard', child: const Text('content')),
        ),
      );

      expect(TitleManager.instance.effectiveTitle, 'Dashboard - MySite');
      expect(titles.last, 'Dashboard - MySite');
    });
  });

  group('MagicTitle — lifecycle edge cases', () {
    testWidgets('override clears to route title on dispose', (tester) async {
      TitleManager.configure(onTitleChanged: (_, _) {});
      TitleManager.instance
        ..setAppTitle('App')
        ..setRouteTitle('Route Page');

      await tester.pumpWidget(
        MaterialApp(
          home: MagicTitle(title: 'Override', child: const Text('content')),
        ),
      );

      expect(TitleManager.instance.currentTitle, 'Override');

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // Falls back to routeTitle after override is cleared.
      expect(TitleManager.instance.currentTitle, 'Route Page');
    });

    testWidgets('renders child widget correctly', (tester) async {
      TitleManager.configure(onTitleChanged: (_, _) {});

      await tester.pumpWidget(
        MaterialApp(
          home: MagicTitle(title: 'Test', child: const Text('Hello World')),
        ),
      );

      expect(find.text('Hello World'), findsOneWidget);
    });
  });
}
