import 'package:fluttersdk_artisan/artisan.dart';

/// Make Lang Command.
///
/// Scaffolds a new JSON translation file using the `lang` stub template.
/// Generates a `.json` file (not `.dart`) at `assets/lang/{code}.json`.
///
/// ## Usage
///
/// ```bash
/// artisan make:lang tr
/// artisan make:lang en
/// ```
///
/// ## Output
///
/// Creates `assets/lang/{code}.json` containing `{}` — an empty translation map
/// ready to populate.
class MakeLangCommand extends ArtisanGeneratorCommand {
  @override
  CommandBoot get boot => CommandBoot.none;

  @override
  String get name => 'make:lang';

  @override
  String get description => 'Create a new language file';

  @override
  String getDefaultNamespace() => 'assets/lang';

  @override
  String getStub() => 'lang';

  /// Overrides to produce a `.json` path instead of the default `.dart`.
  ///
  /// The [name] is a language code (e.g., `tr`, `en`). The file is placed
  /// directly inside [getDefaultNamespace] — no nested path support needed.
  @override
  String getPath(String name) {
    final projectRoot = getProjectRoot();
    final namespace = getDefaultNamespace();

    return '$projectRoot/$namespace/$name.json';
  }

  /// No placeholder replacements — the lang stub is already valid JSON (`{}`).
  @override
  Map<String, String> getReplacements(String name) => const {};
}
