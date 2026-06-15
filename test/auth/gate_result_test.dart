import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// Tests for the [GateResult] data class (Plan Step 17, sub-change b-i).
///
/// Contract:
/// - Final, const-constructible.
/// - Fields: ability (String), allowed (bool), argumentType (Type?),
///   checkedAt (DateTime).
/// - Field assignment round-trips through the constructor.
void main() {
  group('GateResult', () {
    test('assigns all fields via the const constructor', () {
      final now = DateTime(2026, 5, 19, 12, 0, 0);

      const ability = 'monitors.update';
      final result = GateResult(
        ability: ability,
        allowed: true,
        argumentType: int,
        checkedAt: now,
      );

      expect(result.ability, ability);
      expect(result.allowed, isTrue);
      expect(result.argumentType, int);
      expect(result.checkedAt, now);
    });

    test('argumentType is nullable (no-argument check)', () {
      final result = GateResult(
        ability: 'view-dashboard',
        allowed: false,
        checkedAt: DateTime(2026, 5, 19),
      );

      expect(result.argumentType, isNull);
      expect(result.allowed, isFalse);
    });

    test('two results with identical field values hold identical fields', () {
      final timestamp = DateTime(2026, 1, 1);

      final a = GateResult(
        ability: 'delete-post',
        allowed: false,
        argumentType: String,
        checkedAt: timestamp,
      );
      final b = GateResult(
        ability: 'delete-post',
        allowed: false,
        argumentType: String,
        checkedAt: timestamp,
      );

      // Identity is not required (no operator== override is part of the
      // contract), but field round-trip must match.
      expect(a.ability, b.ability);
      expect(a.allowed, b.allowed);
      expect(a.argumentType, b.argumentType);
      expect(a.checkedAt, b.checkedAt);
    });
  });
}
