import 'package:meta/meta.dart';

/// Deep structural equality over serialized attribute values: maps compare
/// by key set and per-key value regardless of order, lists element by
/// element, and anything else with `==`.
///
/// Internal to magic (not exported from `package:magic/magic.dart`): the auth
/// guard judges whether a user sync changed the held user with it, and
/// `Repository` whether a merge changed a cached row.
@internal
bool sameValue(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;

    for (final Object? key in a.keys) {
      if (!b.containsKey(key) || !sameValue(a[key], b[key])) return false;
    }

    return true;
  }

  if (a is List && b is List) {
    if (a.length != b.length) return false;

    for (int i = 0; i < a.length; i++) {
      if (!sameValue(a[i], b[i])) return false;
    }

    return true;
  }

  return a == b;
}
