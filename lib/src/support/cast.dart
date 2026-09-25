// Type readers for a value read out of a NESTED wire map.
//
// A model's own attributes go through the ORM's `get<T>`, which coerces. A
// field read out of a sub-object or a pivot row does not, and `m['k'] as
// String?` is a hard cast: it throws when the backend sends another type.
// Every call site these serve sits in a getter a widget build reads, so one
// wrong-typed field takes a whole screen down instead of blanking one line.

/// Static namespace for reading a loosely-typed wire value as a specific
/// Dart type, degrading to a fallback instead of throwing.
///
/// Every reader here is total: it never throws, and it never assumes the
/// value already has the type it asks for. Use it on a value pulled out of a
/// decoded JSON map, not on a model attribute (the ORM already coerces those).
abstract final class Cast {
  const Cast._();

  /// Reads [value] as a String, answering [fallback] when it is anything
  /// else.
  static String stringOr(Object? value, String fallback) =>
      value is String ? value : fallback;

  /// Reads [value] as a String, answering null when it is anything else.
  static String? stringOrNull(Object? value) => value is String ? value : null;

  /// Reads [value] as an int, answering [fallback] when it cannot be one.
  ///
  /// A numeric string parses rather than degrading, because the fields this
  /// serves are orders and durations: silently reading `"3"` as [fallback]
  /// would sort a list wrongly or shorten a delay, which is a quieter failure
  /// than the cast it replaces.
  static int intOr(Object? value, int fallback) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  /// Reads [value] as a number, answering null when it is not one.
  ///
  /// A numeric string does NOT parse here, unlike [intOr]. The fields this
  /// serves are measurements and money, where the caller's own `?? fallback`
  /// decides what an unreadable value means, and quietly inventing a number
  /// from a string the backend was not supposed to send would put a made-up
  /// figure on a chart.
  static num? numOrNull(Object? value) => value is num ? value : null;

  /// Reads [value] as an int, answering null when it is not a number.
  static int? intOrNull(Object? value) => value is num ? value.toInt() : null;

  /// Reads [value] as a double, answering null when it is not a number.
  ///
  /// Checks `is num`, never `is double`: a JSON `3` decodes as a double on
  /// web and an int on the VM, so gating on `is double` would silently drop
  /// the whole-number case on one platform and not the other.
  static double? doubleOrNull(Object? value) =>
      value is num ? value.toDouble() : null;

  /// Reads [value] as a bool, answering [fallback] when it is anything else.
  static bool boolOr(Object? value, bool fallback) =>
      value is bool ? value : fallback;

  /// Reads [value] as a bool, answering null when it is anything else.
  static bool? boolOrNull(Object? value) => value is bool ? value : null;

  /// Reads [value] as a record id, answering null when it is neither a
  /// string nor a number.
  ///
  /// A number STRINGIFIES rather than degrading to null, and that is the
  /// whole point of having this separate from [stringOrNull]. A primary key
  /// can be a uuid or a bigint depending on backend configuration, so an int
  /// id is a configuration away rather than a malformed payload. Reading one
  /// as null would keep the screen up and then corrupt the save: an editor's
  /// save-diff branches on a null id to mean "create this row", so an
  /// existing row would come back duplicated.
  static String? idOrNull(Object? value) {
    if (value is String) return value;
    if (value is num) return value.toString();
    return null;
  }
}
