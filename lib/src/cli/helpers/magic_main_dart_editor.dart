import 'package:fluttersdk_artisan/artisan.dart' show MainDartEditor;

/// Magic-specific thin wrapper around [MainDartEditor] that pins the
/// `'Magic.init'` anchor so callers never hardcode the magic-internal call
/// site name.
///
/// All methods are pure functional transforms: they accept a source string and
/// return the modified string with no file I/O. Both methods delegate directly
/// to the generic [MainDartEditor.injectBeforeAnchor] / [MainDartEditor.injectAfterAnchor]
/// helpers so the magic-side wrapper carries zero duplicated logic.
///
/// ## Usage
///
/// ```dart
/// // Insert plugin-install code before Magic.init().
/// final updated = MagicMainDartEditor.injectBeforeMagicInit(
///   source: source,
///   snippet: '  DuskPlugin.install();\n',
/// );
///
/// // Insert post-init adapter code after Magic.init().
/// final updated = MagicMainDartEditor.injectAfterMagicInit(
///   source: source,
///   snippet: '  MagicDuskIntegration.install();\n',
/// );
/// ```
class MagicMainDartEditor {
  const MagicMainDartEditor._();

  /// Insert [snippet] immediately before the line containing `Magic.init`
  /// in [source].
  ///
  /// Delegates to [MainDartEditor.injectBeforeAnchor] with `anchor: 'Magic.init'`,
  /// pinning the anchor so callers never hardcode it.
  ///
  /// Idempotent: returns [source] unchanged when [snippet] (trimmed) is already
  /// present, or when no line in [source] contains `'Magic.init'`.
  ///
  /// When [indent] is supplied it is prepended to every non-blank line of
  /// [snippet] before insertion.
  ///
  /// @param source  The full source text to transform.
  /// @param snippet The text block to insert, including trailing newline(s).
  /// @param indent  Optional leading whitespace to prepend to each snippet line.
  /// @return        The transformed source, or [source] unchanged.
  static String injectBeforeMagicInit({
    required String source,
    required String snippet,
    String? indent,
  }) {
    return MainDartEditor.injectBeforeAnchor(
      source: source,
      anchor: 'Magic.init',
      snippet: snippet,
      indent: indent,
    );
  }

  /// Insert [snippet] immediately after the closing `);` of
  /// `await Magic.init(...)` in [source].
  ///
  /// Delegates to [MainDartEditor.injectAfterAnchor] with `anchor: 'Magic.init'`.
  /// The underlying helper uses a paren-depth counter so multi-line
  /// `Magic.init(...)` calls with nested `configFactories` lists are handled
  /// correctly.
  ///
  /// Idempotent: returns [source] unchanged when [snippet] (trimmed) is already
  /// present anywhere in [source], or when no `Magic.init` call can be found.
  ///
  /// @param source  The full source text to transform.
  /// @param snippet The text block to insert, including trailing newline(s).
  /// @return        The transformed source, or [source] unchanged.
  static String injectAfterMagicInit({
    required String source,
    required String snippet,
  }) {
    return MainDartEditor.injectAfterAnchor(
      source: source,
      anchor: 'Magic.init',
      snippet: snippet,
    );
  }
}
