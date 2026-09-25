import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// Usage of magic's Support helpers as an app writes them.
///
/// Runnable with `flutter test` from `example/`; CI runs only the package's
/// own suite, so this file is checked by hand when an API it calls changes.
void main() {
  test('Number and Str format for the reader\'s locale', () {
    expect(
      Number.format(1234567.891, maxPrecision: 3, locale: 'tr'),
      '1.234.567,891',
    );
    expect(Number.percentage(99.95, precision: 2, locale: 'en'), '99.95%');
    expect(Str.upper('istanbul', locale: 'tr'), 'İSTANBUL');
    expect(Str.initials('ada lovelace', capitalize: true), 'AL');
  });

  test('Arr reads a path and Cast types what it found', () {
    final Map<String, dynamic> payload = <String, dynamic>{
      'meta': <String, dynamic>{'priority': '3', 'label': 42},
    };

    expect(Cast.intOr(Arr.get(payload, 'meta.priority'), 0), 3);
    expect(Cast.stringOrNull(Arr.get(payload, 'meta.label')), isNull);
  });

  test('shortDiffForHumans reads against Carbon\'s clock', () {
    final Carbon now = Carbon.parse('2026-01-01 12:00:00');
    Carbon.setTestNow(now);
    addTearDown(Carbon.setTestNow);

    expect(now.subMinutes(14).shortDiffForHumans(), '14m ago');
  });

  testWidgets('SubmitsOnce drops a second tap while the first is in flight', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _SaveButton()));

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(_SaveButtonState.saves, 1);
  });
}

class _SaveButton extends StatefulWidget {
  const _SaveButton();

  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton>
    with SubmitsOnce<_SaveButton> {
  static int saves = 0;

  Future<void> _save() async {
    saves++;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isSubmitting ? null : () => submitOnce(_save),
      child: const Text('Save'),
    );
  }
}
