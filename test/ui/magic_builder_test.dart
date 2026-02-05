import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

void main() {
  group('MagicBuilder', () {
    testWidgets('rebuilds when ValueNotifier changes', (tester) async {
      final counter = ValueNotifier<int>(0);

      await tester.pumpWidget(
        MaterialApp(
          home: WindTheme(
            data: WindThemeData(),
            child: MagicBuilder<int>(
              listenable: counter,
              builder: (value) => Text('Count: $value'),
            ),
          ),
        ),
      );

      // Initial value
      expect(find.text('Count: 0'), findsOneWidget);

      // Update value
      counter.value = 5;
      await tester.pump();

      // Should rebuild with new value
      expect(find.text('Count: 5'), findsOneWidget);
    });

    testWidgets('provides only value to builder (no context or child)',
        (tester) async {
      final name = ValueNotifier<String>('John');
      late String receivedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: WindTheme(
            data: WindThemeData(),
            child: MagicBuilder<String>(
              listenable: name,
              builder: (value) {
                receivedValue = value;
                return Text('Name: $value');
              },
            ),
          ),
        ),
      );

      expect(receivedValue, equals('John'));
      expect(find.text('Name: John'), findsOneWidget);
    });

    testWidgets('works with nullable types', (tester) async {
      final user = ValueNotifier<String?>(null);

      await tester.pumpWidget(
        MaterialApp(
          home: WindTheme(
            data: WindThemeData(),
            child: MagicBuilder<String?>(
              listenable: user,
              builder: (value) => Text(value ?? 'No user'),
            ),
          ),
        ),
      );

      expect(find.text('No user'), findsOneWidget);

      user.value = 'Alice';
      await tester.pump();

      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('works with complex types', (tester) async {
      final users = ValueNotifier<List<String>>([]);

      await tester.pumpWidget(
        MaterialApp(
          home: WindTheme(
            data: WindThemeData(),
            child: MagicBuilder<List<String>>(
              listenable: users,
              builder: (list) => Text('Users: ${list.length}'),
            ),
          ),
        ),
      );

      expect(find.text('Users: 0'), findsOneWidget);

      users.value = ['Alice', 'Bob', 'Charlie'];
      await tester.pump();

      expect(find.text('Users: 3'), findsOneWidget);
    });

    testWidgets('can be used with key', (tester) async {
      final counter = ValueNotifier<int>(0);

      await tester.pumpWidget(
        MaterialApp(
          home: WindTheme(
            data: WindThemeData(),
            child: MagicBuilder<int>(
              key: const Key('counter_builder'),
              listenable: counter,
              builder: (value) => Text('Count: $value'),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('counter_builder')), findsOneWidget);
    });

    testWidgets('can access BuildContext through enclosing Builder',
        (tester) async {
      final counter = ValueNotifier<int>(0);
      ThemeData? capturedTheme;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: WindTheme(
            data: WindThemeData(),
            child: Builder(
              builder: (context) {
                capturedTheme = Theme.of(context);
                return MagicBuilder<int>(
                  listenable: counter,
                  builder: (value) => Text('Count: $value'),
                );
              },
            ),
          ),
        ),
      );

      expect(capturedTheme?.brightness, equals(Brightness.dark));
    });
  });

  group('MagicBuilder type safety', () {
    testWidgets('strongly typed - cannot assign wrong type', (tester) async {
      final counter = ValueNotifier<int>(42);

      await tester.pumpWidget(
        MaterialApp(
          home: WindTheme(
            data: WindThemeData(),
            child: MagicBuilder<int>(
              listenable: counter,
              builder: (value) {
                // value is statically typed as int
                final doubled =
                    value * 2; // This compiles only because value is int
                return Text('Doubled: $doubled');
              },
            ),
          ),
        ),
      );

      expect(find.text('Doubled: 84'), findsOneWidget);
    });
  });
}
