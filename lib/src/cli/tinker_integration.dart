import 'package:flutter/foundation.dart';
import 'package:fluttersdk_artisan/artisan.dart' show Tinker;

import '../database/eloquent/model.dart';

/// Glues magic's facade surface into the magic_tinker REPL hooks.
///
/// Host integration (debug-only):
/// ```dart
/// if (kDebugMode) {
///   TinkerPlugin.install();
///   MagicTinkerIntegration.install();
/// }
/// ```
///
/// Populates three magic_tinker hooks:
/// 1. [Tinker.autocompleteCorpus] — ~30 Magic facade symbols seed the
///    REPL Tab completion. The CLI-side TinkerCommand merges this with
///    runtime `vmService.getClassList()` results (Strategy C lazy cache).
/// 2. [Tinker.classAliases] — empty in V1; host apps populate via
///    `Tinker.classAliases['User'] = 'package:app/models/user.dart#User'`
///    after install. Magic facade scope only (no project-specific names).
/// 3. [Tinker.casters] — registers a pretty-printer for [Model] instances
///    that renders the model class name + fillable fields as a multi-line
///    table (Laravel TinkerCaster::castModel analog).
class MagicTinkerIntegration {
  MagicTinkerIntegration._();

  /// Idempotent install. Safe to call multiple times within the same
  /// isolate lifetime.
  static void install() {
    if (_installed) return;
    _installed = true;
    Tinker.autocompleteCorpus.addAll(_magicCorpusSeed);
    Tinker.classAliases.addAll(_magicClassAliases);
    Tinker.casters.add(eloquentModelCaster);
  }

  /// Whether [install] has been called at least once.
  @visibleForTesting
  static bool get isInstalled => _installed;

  /// Test-only reset. Removes everything this integration added back from
  /// the [Tinker] static hooks and drops the idempotency guard.
  @visibleForTesting
  static void resetForTesting() {
    for (final String symbol in _magicCorpusSeed) {
      Tinker.autocompleteCorpus.remove(symbol);
    }
    for (final String key in _magicClassAliases.keys) {
      Tinker.classAliases.remove(key);
    }
    Tinker.casters.remove(eloquentModelCaster);
    _installed = false;
  }

  static bool _installed = false;
}

/// Magic facade-symbol autocomplete corpus (Strategy C seed).
///
/// Kept const so the publish-time analyzer can fold it into rodata. Host
/// apps extend by mutating [Tinker.autocompleteCorpus] directly after
/// [MagicTinkerIntegration.install] returns.
const List<String> _magicCorpusSeed = <String>[
  'Magic.find',
  'Magic.put',
  'Magic.findOrPut',
  'Magic.singleton',
  'Magic.bound',
  'Auth.user',
  'Auth.check',
  'Auth.attempt',
  'Auth.logout',
  'Http.get',
  'Http.post',
  'Http.put',
  'Http.delete',
  'Cache.get',
  'Cache.put',
  'Cache.forget',
  'Cache.remember',
  'DB.table',
  'DB.statement',
  'Event.dispatch',
  'Event.listen',
  'Gate.allows',
  'Gate.denies',
  'Gate.authorize',
  'Log.info',
  'Log.warning',
  'Log.error',
  'Log.debug',
  'MagicRoute.to',
  'MagicRoute.push',
  'MagicRoute.back',
];

/// Magic-scope class aliases. V1 ships empty — project-specific mappings
/// live in the host app (per Must-NOT: corpus seed is Magic facade scope
/// only).
const Map<String, String> _magicClassAliases = <String, String>{};

/// Pretty-printer for [Model] instances.
///
/// Returns a multi-line block:
/// ```
/// User#42 {
///   id: 42
///   email: "jane@test.com"
///   name: "Jane"
/// }
/// ```
/// Returns null for non-Model values so the next caster in
/// [Tinker.casters] gets a turn.
@visibleForTesting
String? eloquentModelCaster(Object? value) {
  if (value is! Model) return null;

  // 1. Class name + primary key header.
  final String className = value.runtimeType.toString();
  final dynamic key = value.id;
  final String header = key == null ? className : '$className#$key';

  // 2. Pick fields — prefer fillable; fall back to live attributes map
  //    when fillable is empty (subclasses with `guarded = []`).
  final List<String> fields = value.fillable.isNotEmpty
      ? value.fillable
      : value.attributes.keys.toList(growable: false);

  if (fields.isEmpty) {
    return '$header {}';
  }

  // 3. Render each row, quoting strings, leaving other types unquoted.
  final StringBuffer buffer = StringBuffer()..writeln('$header {');
  for (final String field in fields) {
    final dynamic raw = value.getAttribute(field);
    buffer.writeln('  $field: ${_formatScalar(raw)}');
  }
  buffer.write('}');
  return buffer.toString();
}

/// Format an attribute value for the pretty-print table.
///
/// Strings get double-quoted; everything else falls back to `toString()`.
/// Nulls are rendered as `null` so the table reads naturally.
String _formatScalar(Object? value) {
  if (value == null) return 'null';
  if (value is String) return '"$value"';
  return value.toString();
}
