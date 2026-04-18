import '../model.dart';

/// Contract for class-based custom attribute casts.
///
/// Implement this interface to define a reusable cast that transforms a raw
/// storage value into a domain type on read, and back into a storage value on
/// write. Register the instance under the attribute name in [Model.casts]:
///
/// ```dart
/// class EnumCast<T extends Enum> implements CastsAttributes<T> { ... }
///
/// class Monitor extends Model {
///   @override
///   Map<String, dynamic> get casts => {
///     'status': EnumCast(MonitorStatus.values),
///     'created_at': 'datetime',
///   };
/// }
/// ```
///
/// The string-based built-ins (`datetime`, `json`, `bool`, `int`, `double`)
/// continue to work side by side.
abstract class CastsAttributes<T> {
  const CastsAttributes();

  /// Transform the raw storage value into the domain type.
  ///
  /// Called from [Model.getAttribute] when reading the attribute. Receives
  /// the value exactly as it sits in storage (API response, database row, or
  /// a previously-set domain value).
  T? get(Model model, String key, Object? raw);

  /// Transform the domain value back into a storage representation.
  ///
  /// Called from [Model.setAttribute] when writing the attribute. If the
  /// incoming value is not of type [T] (e.g. raw string from a fill), the
  /// implementation should return it unchanged so hydration flows keep
  /// working.
  Object? set(Model model, String key, Object? value);
}
