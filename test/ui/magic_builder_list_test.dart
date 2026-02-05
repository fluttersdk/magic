import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

void main() {
  group('MagicBuilder with List', () {
    testWidgets('renders list items reactively', (tester) async {
      final items = ValueNotifier<List<String>>(['Apple', 'Banana']);

      await tester.pumpWidget(
        MaterialApp(
          home: WindTheme(
            data: WindThemeData(),
            child: MagicBuilder<List<String>>(
              listenable: items,
              builder: (list) => Column(
                children: list.map((item) => Text(item)).toList(),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Banana'), findsOneWidget);

      // Add item
      items.value = [...items.value, 'Cherry'];
      await tester.pump();

      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Banana'), findsOneWidget);
      expect(find.text('Cherry'), findsOneWidget);
    });

    testWidgets('handles empty list correctly', (tester) async {
      final items = ValueNotifier<List<String>>([]);

      await tester.pumpWidget(
        MaterialApp(
          home: WindTheme(
            data: WindThemeData(),
            child: MagicBuilder<List<String>>(
              listenable: items,
              builder: (list) => list.isEmpty
                  ? const Text('No items')
                  : Column(
                      children: list.map((item) => Text(item)).toList(),
                    ),
            ),
          ),
        ),
      );

      expect(find.text('No items'), findsOneWidget);

      // Add items
      items.value = ['First item'];
      await tester.pump();

      expect(find.text('No items'), findsNothing);
      expect(find.text('First item'), findsOneWidget);
    });

    testWidgets('handles list becoming empty', (tester) async {
      final items = ValueNotifier<List<String>>(['Item 1', 'Item 2']);

      await tester.pumpWidget(
        MaterialApp(
          home: WindTheme(
            data: WindThemeData(),
            child: MagicBuilder<List<String>>(
              listenable: items,
              builder: (list) => list.isEmpty
                  ? const Text('Empty')
                  : Text('Count: ${list.length}'),
            ),
          ),
        ),
      );

      expect(find.text('Count: 2'), findsOneWidget);

      // Clear list
      items.value = [];
      await tester.pump();

      expect(find.text('Empty'), findsOneWidget);
    });

    testWidgets('works with list of complex objects', (tester) async {
      final users = ValueNotifier<List<Map<String, dynamic>>>([
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: WindTheme(
            data: WindThemeData(),
            child: MagicBuilder<List<Map<String, dynamic>>>(
              listenable: users,
              builder: (list) => Column(
                children: list
                    .map((user) => Text('${user['name']} (ID: ${user['id']})'))
                    .toList(),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Alice (ID: 1)'), findsOneWidget);
      expect(find.text('Bob (ID: 2)'), findsOneWidget);

      // Update a user
      users.value = [
        {'id': 1, 'name': 'Alice Updated'},
        {'id': 2, 'name': 'Bob'},
        {'id': 3, 'name': 'Charlie'},
      ];
      await tester.pump();

      expect(find.text('Alice Updated (ID: 1)'), findsOneWidget);
      expect(find.text('Charlie (ID: 3)'), findsOneWidget);
    });

    testWidgets('common pattern: ListView.builder inside MagicBuilder',
        (tester) async {
      final items = ValueNotifier<List<String>>([
        'Item 1',
        'Item 2',
        'Item 3',
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: WindTheme(
            data: WindThemeData(),
            child: Scaffold(
              body: MagicBuilder<List<String>>(
                listenable: items,
                builder: (list) => ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) => ListTile(
                    title: Text(list[index]),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Item 3'), findsOneWidget);

      // Remove an item
      items.value = ['Item 1', 'Item 3'];
      await tester.pump();

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsNothing);
      expect(find.text('Item 3'), findsOneWidget);
    });

    testWidgets('common pattern: loading state with nullable list',
        (tester) async {
      final items = ValueNotifier<List<String>?>(null); // null = loading

      await tester.pumpWidget(
        MaterialApp(
          home: WindTheme(
            data: WindThemeData(),
            child: MagicBuilder<List<String>?>(
              listenable: items,
              builder: (list) {
                if (list == null) {
                  return const Text('Loading...');
                }
                if (list.isEmpty) {
                  return const Text('No items found');
                }
                return Column(
                  children: list.map((item) => Text(item)).toList(),
                );
              },
            ),
          ),
        ),
      );

      // Initially loading
      expect(find.text('Loading...'), findsOneWidget);

      // Data loaded but empty
      items.value = [];
      await tester.pump();
      expect(find.text('No items found'), findsOneWidget);

      // Data loaded with items
      items.value = ['Data 1', 'Data 2'];
      await tester.pump();
      expect(find.text('Data 1'), findsOneWidget);
      expect(find.text('Data 2'), findsOneWidget);
    });
  });
}
