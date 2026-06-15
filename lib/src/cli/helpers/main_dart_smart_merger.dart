import 'package:fluttersdk_artisan/artisan.dart' show MainDartEditor;

/// Preserve-mode smart merger for `lib/main.dart`.
///
/// Takes an existing user-authored `main.dart` source string and surgically
/// injects Magic without overwriting the user's code: adds Magic + Wind
/// imports, injects `await Magic.init(...)` at the top of `main()`, and
/// wraps the existing `runApp(X)` call with `MagicApplication(child: X,
/// appName: '<name>')`.
///
/// All three mutations are idempotent: re-running on already-merged source
/// returns equivalent output (no duplicate imports, no double Magic.init,
/// no double wrap).
///
/// ## Constraints
///
/// - Only `void main() async { ... }` or `Future<void> main() async { ... }`
///   shapes are supported. A synchronous `main()` is rejected with a
///   [FormatException] whose message names both `--preserve` (re-run after
///   converting to async) and `--force` (replace entirely) as alternatives.
/// - The existing source MUST contain a `runApp(...)` call. When absent a
///   [StateError] is thrown.
///
/// ## Usage
///
/// ```dart
/// final merged = MainDartSmartMerger.mergeMagicInto(
///   existingSource,
///   appName: 'Uptizm',
///   configImports: ["import 'config/app.dart';"],
///   configFactories: ['() => appConfig'],
/// );
/// ```
class MainDartSmartMerger {
  const MainDartSmartMerger._();

  /// Pattern matching `void main() async {` or `Future<void> main() async {`.
  static final RegExp _asyncMainPattern = RegExp(
    r'(?:void|Future<\s*void\s*>)\s+main\s*\(\s*\)\s*async\s*\{',
  );

  /// Pattern matching the opening of any `runApp(` call.
  static final RegExp _runAppPattern = RegExp(r'runApp\s*\(');

  /// Merges Magic into [existingSource].
  ///
  /// @param existingSource    Current contents of `lib/main.dart`.
  /// @param appName           Title-Cased app name (extracted from pubspec).
  /// @param configImports     Import statements for each magic config file
  ///                          (e.g. `"import 'config/app.dart';"`).
  /// @param configFactories   Factory expressions for `Magic.init`'s
  ///                          `configFactories:` list (e.g. `'() => appConfig'`).
  /// @return                  Transformed source with Magic injected.
  /// @throws FormatException  When `main()` is not async.
  /// @throws StateError       When the source has no `runApp(` call.
  static String mergeMagicInto(
    String existingSource, {
    required String appName,
    required List<String> configImports,
    required List<String> configFactories,
  }) {
    // 1. Reject sync main() with an actionable message naming both alternatives.
    if (_asyncMainPattern.firstMatch(existingSource) == null) {
      throw FormatException(
        'main() must be async to use Magic. Convert: '
        '`void main() async { ... }` then re-run install --preserve. '
        'To replace entirely, use --force.',
      );
    }

    var result = existingSource;

    // 2. Add imports (Magic + Wind + each configImport) idempotently. Each
    //    call to injectBeforeAnchor returns the source unchanged when the
    //    snippet is already present, so re-runs do not duplicate.
    const magicImport = "import 'package:magic/magic.dart';";
    const windImport = "import 'package:fluttersdk_wind/fluttersdk_wind.dart';";
    const flutterMaterialAnchor = "import 'package:flutter/material.dart'";

    result = MainDartEditor.injectBeforeAnchor(
      source: result,
      anchor: flutterMaterialAnchor,
      snippet: '$magicImport\n',
    );
    result = MainDartEditor.injectBeforeAnchor(
      source: result,
      anchor: flutterMaterialAnchor,
      snippet: '$windImport\n',
    );
    for (final imp in configImports) {
      result = MainDartEditor.injectBeforeAnchor(
        source: result,
        anchor: flutterMaterialAnchor,
        snippet: '$imp\n',
      );
    }

    // 3. Inject `await Magic.init(...)` immediately after the `main() async {`
    //    line. Skip when an existing call is already present (idempotency).
    if (!result.contains('await Magic.init(')) {
      result = _injectMagicInitAfterMainOpen(result, configFactories);
    }

    // 4. Wrap `runApp(X)` with `MagicApplication(child: X, appName: '...')`.
    //    Skip when MagicApplication already wraps the call (idempotency).
    if (!result.contains('MagicApplication(')) {
      result = _wrapRunAppWithMagicApplication(result, appName);
    }

    return result;
  }

  /// Inserts an `await Magic.init(configFactories: [...]);` block immediately
  /// after the opening `{` of `main()` (on the next line).
  static String _injectMagicInitAfterMainOpen(
    String source,
    List<String> configFactories,
  ) {
    final match = _asyncMainPattern.firstMatch(source);
    if (match == null) {
      // Defensive: mergeMagicInto already validated async-ness; this is
      // unreachable in practice but kept safe to avoid silent corruption.
      return source;
    }

    // Compose the Magic.init body. Empty factory list still emits the call
    // (with an empty configFactories list) so the bootstrap is in place; the
    // user can fill it in later.
    final String body;
    if (configFactories.isEmpty) {
      body = '  await Magic.init(configFactories: []);\n';
    } else {
      final entries = configFactories.map((f) => '    $f,').join('\n');
      body = '  await Magic.init(configFactories: [\n$entries\n  ]);\n';
    }

    // The match ends at the `{`; advance past the next newline so the
    // snippet lands on its own line inside the function body.
    var insertPos = match.end;
    while (insertPos < source.length && source[insertPos] != '\n') {
      insertPos++;
    }
    if (insertPos < source.length) insertPos++; // past the newline

    return source.substring(0, insertPos) + body + source.substring(insertPos);
  }

  /// Wraps the existing `runApp(<inner>)` call with
  /// `runApp(MagicApplication(child: <inner>, appName: '<appName>'))`.
  ///
  /// Uses paren-depth counting so multi-line `runApp(...)` calls with nested
  /// arguments (e.g. `runApp(MyApp(child: Foo()))`) are handled correctly.
  static String _wrapRunAppWithMagicApplication(String source, String appName) {
    final match = _runAppPattern.firstMatch(source);
    if (match == null) {
      throw StateError(
        'MainDartSmartMerger: no `runApp(` call found in source. '
        'Magic requires an existing runApp(...) anchor to wrap; '
        're-run install --force to overwrite with the Magic template.',
      );
    }

    // The opening `(` is the last character of the match.
    final openParen = match.end - 1;
    final closeParen = _findMatchingParen(source, openParen);
    final inner = source.substring(openParen + 1, closeParen);
    final wrapped = "MagicApplication(child: $inner, appName: '$appName')";

    return source.substring(0, openParen + 1) +
        wrapped +
        source.substring(closeParen);
  }

  /// Walks [source] from [openParenIndex] (which points at `(`) and returns
  /// the index of the matching `)` via paren-depth counting.
  ///
  /// Throws [StateError] when the source ends before the paren is closed.
  static int _findMatchingParen(String source, int openParenIndex) {
    var depth = 0;
    for (var i = openParenIndex; i < source.length; i++) {
      final ch = source[i];
      if (ch == '(') {
        depth++;
      } else if (ch == ')') {
        depth--;
        if (depth == 0) return i;
      }
    }
    throw StateError(
      'MainDartSmartMerger: unmatched `(` at offset $openParenIndex '
      'while scanning runApp call.',
    );
  }
}
