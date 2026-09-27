import 'dart:convert';
import 'dart:io';

import 'package:fluttersdk_artisan/artisan.dart';
import 'package:path/path.dart' as p;

import '../helpers/magic_stub_loader.dart';

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
/// artisan make:lang tr --from=en   # copy en.json's key tree into tr.json
/// artisan make:lang tr --force     # Overwrite existing file
/// ```
///
/// ## Output
///
/// When `assets/lang/<from>.json` exists (`--from` defaults to `en`), writes
/// `assets/lang/{code}.json` with the SAME key tree, each leaf copied
/// verbatim from the source so the catalogue is complete and ready for a
/// human translator. Otherwise writes an empty translation map (`{}`).
class MakeLangCommand extends ArtisanGeneratorCommand {
  /// Optional test root override: injected in tests to avoid touching the
  /// real filesystem.
  final String? _testRoot;

  /// Creates a [MakeLangCommand].
  ///
  /// Pass [testRoot] to pin the project root to a temp directory during tests.
  MakeLangCommand({String? testRoot}) : _testRoot = testRoot;

  @override
  CommandBoot get boot => CommandBoot.none;

  @override
  String get name => 'make:lang';

  @override
  String get description => 'Create a new language file';

  @override
  String getDefaultNamespace() => 'assets/lang';

  @override
  String getStub() => MagicStubLoader.load('lang');

  @override
  String getProjectRoot() => _testRoot ?? super.getProjectRoot();

  /// Overrides to produce a `.json` path instead of the default `.dart`.
  ///
  /// The [name] is a language code (e.g., `tr`, `en`). The file is placed
  /// directly inside [getDefaultNamespace]; no nested path support needed.
  @override
  String getPath(String name) {
    final projectRoot = getProjectRoot();
    final namespace = getDefaultNamespace();

    return '$projectRoot/$namespace/$name.json';
  }

  /// No placeholder replacements; the lang stub is already valid JSON (`{}`).
  @override
  Map<String, String> getReplacements(String name) => const {};

  @override
  void configure(ArgParser parser) {
    super.configure(parser);
    parser.addOption(
      'from',
      defaultsTo: 'en',
      help: "Source locale to copy the key tree from (defaults to 'en').",
    );
  }

  @override
  Future<int> handle(ArtisanContext ctx) async {
    final name = ctx.input.argument(0);
    if (name == null || name.isEmpty) {
      ctx.output.error('Not enough arguments (missing: "name").');
      return 1;
    }

    final filePath = getPath(name);
    if (FileHelper.fileExists(filePath) && !ctx.input.hasOption('force')) {
      ctx.output.error('File already exists at $filePath');
      return 1;
    }

    final from = ctx.input.option('from') as String? ?? 'en';
    final content = _buildContent(from);
    FileHelper.writeFile(filePath, content);
    ctx.output.success('Created: $filePath');
    return 0;
  }

  /// Builds the JSON content for the new locale.
  ///
  /// Copies [from]'s key tree verbatim (each leaf's value included) when
  /// `assets/lang/<from>.json` exists on disk and decodes to a JSON object;
  /// otherwise falls back to an empty map. Output is two-space indented.
  String _buildContent(String from) {
    final sourcePath = p.join(
      getProjectRoot(),
      getDefaultNamespace(),
      '$from.json',
    );
    final sourceFile = File(sourcePath);
    if (!sourceFile.existsSync()) {
      return '{}';
    }

    final decoded = jsonDecode(sourceFile.readAsStringSync());
    if (decoded is! Map<String, dynamic> || decoded.isEmpty) {
      return '{}';
    }

    return const JsonEncoder.withIndent('  ').convert(decoded);
  }
}
