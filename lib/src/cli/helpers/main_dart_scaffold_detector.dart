/// Heuristic detector for the default `flutter create` counter-app scaffold.
///
/// Uses a simple marker-count strategy: if a `main.dart` source string contains
/// at least 3 of the 4 well-known counter-app identifiers, it is treated as an
/// unmodified (or lightly modified) scaffold that is safe to overwrite during
/// `magic:install`.
///
/// **Accepted limitation**: markers matched via plain [String.contains], so a
/// marker that appears only inside a comment still increments the count. This
/// favors silent overwrite for the common case and is documented at the call
/// site.
class MainDartScaffoldDetector {
  const MainDartScaffoldDetector._();

  /// The four well-known identifiers emitted by `flutter create` for the
  /// default counter-app scaffold.
  static const List<String> _markers = [
    '_MyHomePageState',
    '_counter',
    'MyHomePage',
    'You have pushed the button',
  ];

  /// Returns `true` when [source] contains at least 3 of the 4 default Flutter
  /// counter-app markers, indicating the file is an unmodified (or minimally
  /// modified) `flutter create` scaffold.
  ///
  /// Markers are matched via [String.contains] — comments containing a marker
  /// string also count toward the threshold. This is an accepted limitation;
  /// the heuristic favors silent overwrite for the common case over false
  /// negatives on hand-authored files.
  ///
  /// @param source  The full source text of `main.dart` to inspect.
  /// @return        `true` when the match count is >= 3, `false` otherwise.
  static bool isFlutterCreateScaffold(String source) {
    var count = 0;
    for (final marker in _markers) {
      if (source.contains(marker)) count++;
    }
    return count >= 3;
  }
}
