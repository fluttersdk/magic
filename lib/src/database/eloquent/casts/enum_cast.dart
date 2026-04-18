import '../model.dart';
import 'casts_attributes.dart';

/// Cast a string-backed enum attribute to/from its Dart [Enum] value.
///
/// Pass the enum's `.values` list so the cast can resolve names back to
/// instances:
///
/// ```dart
/// enum MonitorStatus { active, paused, failed }
///
/// class Monitor extends Model {
///   @override
///   Map<String, dynamic> get casts => {
///     'status': EnumCast(MonitorStatus.values),
///   };
///
///   MonitorStatus? get status => getAttribute('status') as MonitorStatus?;
///   set status(MonitorStatus? value) => setAttribute('status', value);
/// }
/// ```
///
/// Unknown names return `null` by default. Pass `strict: true` to throw an
/// [ArgumentError] instead, useful when the backend should never ship an
/// unexpected value.
class EnumCast<T extends Enum> implements CastsAttributes<T> {
  const EnumCast(this.values, {this.strict = false});

  /// The enum's `.values` list used to resolve names.
  final List<T> values;

  /// When `true`, an unknown name throws [ArgumentError] instead of returning
  /// `null`.
  final bool strict;

  @override
  T? get(Model model, String key, Object? raw) {
    if (raw == null) return null;
    if (raw is T) return raw;

    final name = raw.toString();
    for (final value in values) {
      if (value.name == name) return value;
    }

    if (strict) {
      throw ArgumentError.value(
        raw,
        key,
        'Unknown $T value. Expected one of: '
        '${values.map((v) => v.name).join(', ')}',
      );
    }

    return null;
  }

  @override
  Object? set(Model model, String key, Object? value) {
    if (value == null) return null;
    if (value is T) return value.name;
    // Allow raw strings to pass through for hydration flows.
    return value;
  }
}
