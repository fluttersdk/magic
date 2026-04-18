import 'dart:convert';

import '../model.dart';
import 'casts_attributes.dart';

/// Cast a list attribute element-by-element through an inner cast.
///
/// Storage form is a JSON-encoded string (so it survives SQLite TEXT columns
/// and API round-trips). Reads accept either a `List` or a JSON string; writes
/// emit JSON when a `List` is provided and otherwise pass through raw storage
/// forms unchanged.
///
/// ```dart
/// enum MonitorStatus { up, down, paused }
///
/// class Monitor extends Model {
///   @override
///   Map<String, dynamic> get casts => {
///     'statuses': ListCast(EnumCast(MonitorStatus.values)),
///   };
/// }
/// ```
class ListCast<T> implements CastsAttributes<List<T>> {
  const ListCast(this.inner);

  /// The per-element cast applied to every item in the list.
  final CastsAttributes<T> inner;

  @override
  List<T>? get(Model model, String key, Object? raw) {
    if (raw == null) return null;

    final List<dynamic> items = switch (raw) {
      final List<dynamic> list => list,
      final String s => jsonDecode(s) as List<dynamic>,
      _ => <dynamic>[raw],
    };

    final result = <T>[];
    for (final item in items) {
      final cast = inner.get(model, key, item);
      if (cast != null) result.add(cast);
    }
    return result;
  }

  @override
  Object? set(Model model, String key, Object? value) {
    if (value == null) return null;
    if (value is List) {
      final serialized = value
          .map((item) => inner.set(model, key, item))
          .toList();
      return jsonEncode(serialized);
    }
    // Pass through raw storage forms (JSON string / single value).
    return value;
  }
}
