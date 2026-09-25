import 'cast.dart';

/// Static namespace for dot-path access into a nested `Map<String, dynamic>`,
/// mirroring Laravel's `Arr::get` / `has` / `set` / `dot`.
///
/// This carries only path operations, deliberately: there is no typed reader
/// here (an `intOr`, a `stringOrNull`). Typing a value read off a path is
/// [Cast]'s job, composed at the call site: `Cast.intOr(Arr.get(m, 'a.b'), 0)`.
/// `Arr.get` performs no type check of its own; it returns exactly what the
/// wire held at that path.
abstract final class Arr {
  const Arr._();

  /// Reads the value at the dotted [path] in [map], answering [fallback]
  /// when the path cannot be reached.
  ///
  /// A null [path] answers [map] itself. An exact key equal to [path] wins
  /// over walking the path, so a map that happens to hold a literal
  /// `'a.b'` key reads that value rather than descending into `map['a']['b']`.
  /// A numeric path segment indexes into a `List` at that position.
  ///
  /// This performs no type check: the caller composes with [Cast] for a
  /// typed read, e.g. `Cast.intOr(Arr.get(m, 'a.b'), 0)`.
  static Object? get(
    Map<String, dynamic>? map,
    String? path, [
    Object? fallback,
  ]) {
    if (map == null) return fallback;
    if (path == null) return map;
    if (map.containsKey(path)) return map[path];

    Object? current = map;
    for (final String segment in path.split('.')) {
      final Object? next = _step(current, segment);
      if (next == _notFound) return fallback;
      current = next;
    }
    return current;
  }

  /// True when the dotted [path] can be reached in [map], even when the
  /// value found there is null.
  static bool has(Map<String, dynamic>? map, String path) {
    if (map == null || map.isEmpty) return false;
    if (map.containsKey(path)) return true;

    Object? current = map;
    for (final String segment in path.split('.')) {
      final Object? next = _step(current, segment);
      if (next == _notFound) return false;
      current = next;
    }
    return true;
  }

  /// Writes [value] at the dotted [path] in [map], creating an intermediate
  /// `Map<String, dynamic>` for every missing (or non-map) segment along the
  /// way.
  static void set(Map<String, dynamic> map, String path, Object? value) {
    final List<String> segments = path.split('.');
    Map<String, dynamic> current = map;

    for (int i = 0; i < segments.length - 1; i++) {
      final String segment = segments[i];
      final Object? existing = current[segment];
      if (existing is Map<String, dynamic>) {
        current = existing;
      } else {
        final Map<String, dynamic> created = <String, dynamic>{};
        current[segment] = created;
        current = created;
      }
    }

    current[segments.last] = value;
  }

  /// Flattens a nested [map] into a single-level map whose keys are the
  /// dotted paths to each leaf, prefixed with [prepend].
  ///
  /// An empty nested map is itself kept as a leaf rather than dropped, so
  /// flattening and re-nesting a map that happens to hold `{}` somewhere
  /// does not silently lose that key.
  static Map<String, dynamic> dot(
    Map<String, dynamic> map, {
    String prepend = '',
  }) {
    final Map<String, dynamic> result = <String, dynamic>{};

    for (final MapEntry<String, dynamic> entry in map.entries) {
      final String key = '$prepend${entry.key}';
      final Object? value = entry.value;

      if (value is Map<String, dynamic> && value.isNotEmpty) {
        result.addAll(dot(value, prepend: '$key.'));
      } else {
        result[key] = value;
      }
    }

    return result;
  }

  /// Sentinel distinguishing "the segment was not reachable" from a
  /// genuinely-present null value while walking a path.
  static const Object _notFound = Object();

  /// Steps one dotted [segment] into [current], which is either a
  /// `Map<String, dynamic>` or a `List`. Answers [_notFound] when [segment]
  /// cannot be resolved against [current]'s shape.
  static Object? _step(Object? current, String segment) {
    if (current is Map<String, dynamic>) {
      return current.containsKey(segment) ? current[segment] : _notFound;
    }
    if (current is List) {
      final int? index = int.tryParse(segment);
      if (index == null || index < 0 || index >= current.length) {
        return _notFound;
      }
      return current[index];
    }
    return _notFound;
  }
}
