import 'dart:io';

import 'package:fluttersdk_artisan/artisan.dart';
import 'package:path/path.dart' as path;

import '../helpers/magic_stub_loader.dart';
import '../helpers/run_child.dart';
import 'previews_refresh_command.dart';

/// `make:component <Name> [--variants=intent,size] [--slots] [--preview|--no-preview]`:
/// scaffolds an atomic component folder (`<name>.dart`, `<name>.recipe.dart`,
/// `index.dart`, and conditionally `<name>.preview.dart`) under
/// `lib/ui/components/<name>/`, plus its matching widget test at
/// `test/ui/components/<name>/<name>_test.dart`.
///
/// The component class is unprefixed PascalCase (`make:component Avatar` ->
/// `class Avatar`); the folder + files are `lower_snake_case`. The recipe is
/// seeded with the requested `--variants` axes (each value left empty for the
/// author to fill with token classNames). `--slots` seeds a [WindSlotRecipe]
/// shape instead of a single-element [WindRecipe].
///
/// ## Preview auto-detection
///
/// The preview file (and the chained `previews:refresh`) is only scaffolded
/// when the target project already maintains a preview catalogue: any
/// `*.preview.dart` file or a `_previews.g.dart` index anywhere under `lib/`.
/// `--preview` / `--no-preview` override the detection in either direction;
/// the flag wins because it was explicitly given, not merely because it
/// parsed truthy ([ArgvInput.hasOption] reports a negated flag as present).
///
/// Chaining follows the `make:model --all` pattern: a child command is parsed
/// against its own [ArgParser] and handled with a bare context that reuses the
/// parent output, so the operator sees one uninterrupted feedback stream.
class MakeComponentCommand extends ArtisanGeneratorCommand {
  /// Creates a [MakeComponentCommand].
  ///
  /// [testRoot] overrides the project root resolution, used in tests only.
  MakeComponentCommand({String? testRoot}) : _testRoot = testRoot;

  final String? _testRoot;

  @override
  CommandBoot get boot => CommandBoot.none;

  @override
  String get name => 'make:component';

  @override
  String get description =>
      'Scaffold an atomic component folder (recipe + component + preview + index)';

  @override
  String getDefaultNamespace() => 'lib/ui/components';

  @override
  String getProjectRoot() => _testRoot ?? super.getProjectRoot();

  /// Stub names resolve through the standard loader; this command writes four
  /// files directly so [getStub] is unused.
  @override
  String getStub() => '';

  @override
  void configure(ArgParser parser) {
    super.configure(parser);
    parser.addOption(
      'variants',
      help: 'Comma-separated variant axis names (e.g. intent,size).',
    );
    parser.addFlag(
      'slots',
      help: 'Scaffold a multi-part WindSlotRecipe instead of a single recipe.',
      negatable: false,
    );
    parser.addFlag(
      'preview',
      help:
          'Force the preview file (and previews:refresh) on/off, overriding '
          'catalogue auto-detection.',
    );
    // Test seam: point the stub loader at a checkout-local assets/stubs dir
    // without setting a process-wide env var.
    parser.addOption(
      'stubs-dir',
      help: 'Override the stubs directory (testing only).',
    );
  }

  @override
  Future<int> handle(ArtisanContext ctx) async {
    final rawName = ctx.input.argument(0);
    if (rawName == null || rawName.isEmpty) {
      ctx.output.error('Not enough arguments (missing: "name").');
      return 1;
    }

    // 1. Resolve names: unprefixed PascalCase class, snake_case folder + files.
    final parsed = StringHelper.parseName(rawName);
    final className = StringHelper.toPascalCase(parsed.className);
    final snakeName = StringHelper.toSnakeCase(parsed.className);
    final camelName = StringHelper.toCamelCase(parsed.className);

    final componentDir = path.join(
      getProjectRoot(),
      getDefaultNamespace(),
      snakeName,
    );

    // 2. Abort early if the folder already holds the component (unless --force).
    final componentFile = path.join(componentDir, '$snakeName.dart');
    if (FileHelper.fileExists(componentFile) && !ctx.input.hasOption('force')) {
      ctx.output.error('Component already exists at $componentFile');
      return 1;
    }

    // 3. Parse the requested variant axes and the recipe shape (--slots).
    final variantAxes = _parseVariants(ctx.input.option('variants') as String?);
    final stubsDir = ctx.input.option('stubs-dir') as String?;
    final slots = ctx.input.hasOption('slots');

    final replacements = <String, String>{
      '{{ className }}': className,
      '{{ snakeName }}': snakeName,
      '{{ camelName }}': camelName,
      '{{ variantAxes }}': _renderVariantAxes(variantAxes),
      '{{ slotVariantAxes }}': _renderSlotVariantAxes(variantAxes),
      '{{ defaultVariants }}': _renderDefaultVariants(variantAxes),
    };

    // 4. Write the three always-on atomic files from their stubs. --slots
    //    swaps the single-element recipe + component for the WindSlotRecipe
    //    variants. The preview is conditional (see step 5).
    _writeStub(
      slots ? 'component.slots' : 'component',
      '$snakeName.dart',
      componentDir,
      replacements,
      stubsDir,
    );
    _writeStub(
      slots ? 'component.slot_recipe' : 'component.recipe',
      '$snakeName.recipe.dart',
      componentDir,
      replacements,
      stubsDir,
    );
    _writeStub(
      'component_index',
      'index.dart',
      componentDir,
      replacements,
      stubsDir,
    );

    ctx.output.success('Created component: $componentDir');

    // 5. Only scaffold the preview (and chain previews:refresh) when the
    //    project already maintains a preview catalogue, unless --preview /
    //    --no-preview explicitly overrides the detection.
    final libDir = path.join(getProjectRoot(), 'lib');
    final previewGiven = ctx.input.hasOption('preview');
    final bool writePreview;
    final String previewReason;
    if (previewGiven) {
      writePreview = ctx.input.option('preview') as bool;
      previewReason = writePreview
          ? '--preview forced it on'
          : '--no-preview forced it off';
    } else {
      writePreview = _hasPreviewCatalogue(libDir);
      previewReason = writePreview
          ? 'an existing *.preview.dart or _previews.g.dart catalogue was '
                'found under lib/'
          : 'no *.preview.dart or _previews.g.dart catalogue was found '
                'under lib/';
    }

    if (writePreview) {
      _writeStub(
        'preview',
        '$snakeName.preview.dart',
        componentDir,
        replacements,
        stubsDir,
      );
      ctx.output.info('Preview: written ($previewReason)');
      await RunChild.run(
        PreviewsRefreshCommand(projectRoot: getProjectRoot()),
        const <String>[],
        ctx,
      );
    } else {
      ctx.output.info('Preview: skipped ($previewReason)');
    }

    // 6. Scaffold the matching widget test, unless the target project has no
    //    pubspec.yaml to resolve its package name from.
    _writeMatchingTest(ctx, className, snakeName, stubsDir);

    return 0;
  }

  /// Writes `test/ui/components/<snakeName>/<snakeName>_test.dart` from
  /// `component_test.stub`, importing the component through
  /// `package:<packageName>/ui/components/<snakeName>/index.dart`.
  ///
  /// [packageName] is read from the target project's own `pubspec.yaml`;
  /// when that file is absent, the test is skipped with a printed note
  /// rather than failing the whole command (the component itself already
  /// landed).
  void _writeMatchingTest(
    ArtisanContext ctx,
    String className,
    String snakeName,
    String? stubsDir,
  ) {
    final pubspecPath = path.join(getProjectRoot(), 'pubspec.yaml');
    if (!FileHelper.fileExists(pubspecPath)) {
      ctx.output.warning(
        'Skipped matching test: no pubspec.yaml found at $pubspecPath',
      );
      return;
    }

    final packageName = FileHelper.readYamlFile(pubspecPath)['name'] as String;
    var content = stubsDir != null
        ? MagicStubLoader.loadFrom('component_test', stubsDir)
        : MagicStubLoader.load('component_test');
    content = content
        .replaceAll('{{ className }}', className)
        .replaceAll('{{ snakeName }}', snakeName)
        .replaceAll('{{ packageName }}', packageName);

    final testPath = path.join(
      getProjectRoot(),
      'test',
      'ui',
      'components',
      snakeName,
      '${snakeName}_test.dart',
    );
    FileHelper.writeFile(testPath, content);
    ctx.output.success('Created: $testPath');
  }

  /// Whether [libDir] already carries a preview catalogue: any
  /// `*.preview.dart` file, or a `_previews.g.dart` index, anywhere in its
  /// tree.
  bool _hasPreviewCatalogue(String libDir) {
    final dir = Directory(libDir);
    if (!dir.existsSync()) return false;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File) continue;
      final base = path.basename(entity.path);
      if (base.endsWith('.preview.dart') || base == '_previews.g.dart') {
        return true;
      }
    }
    return false;
  }

  /// Loads [stubName], applies [replacements], and writes the rendered content
  /// to `<dir>/<fileName>`.
  void _writeStub(
    String stubName,
    String fileName,
    String dir,
    Map<String, String> replacements,
    String? stubsDir,
  ) {
    var content = stubsDir != null
        ? MagicStubLoader.loadFrom(stubName, stubsDir)
        : MagicStubLoader.load(stubName);
    for (final entry in replacements.entries) {
      content = content.replaceAll(entry.key, entry.value);
    }
    FileHelper.writeFile(path.join(dir, fileName), content);
  }

  /// Splits the `--variants` option into trimmed, non-empty axis names.
  List<String> _parseVariants(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const <String>[];
    return raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Renders the `variants:` map body for the recipe stub. Each axis gets a
  /// single placeholder value the author fills in with token classNames.
  String _renderVariantAxes(List<String> axes) {
    if (axes.isEmpty) return '';
    final buf = StringBuffer();
    for (final axis in axes) {
      buf
        ..writeln("      '$axis': {")
        ..writeln("        'default': '',")
        ..writeln('      },');
    }
    return buf.toString();
  }

  /// Renders the `variants:` map body for the slot recipe stub. Each axis value
  /// carries a per-slot className map (only the `root` slot is seeded).
  String _renderSlotVariantAxes(List<String> axes) {
    if (axes.isEmpty) return '';
    final buf = StringBuffer();
    for (final axis in axes) {
      buf
        ..writeln("      '$axis': {")
        ..writeln("        'default': {'root': ''},")
        ..writeln('      },');
    }
    return buf.toString();
  }

  /// Renders the `defaultVariants:` block, or an empty string when there are
  /// no axes (so the recipe stub stays analyzer-clean).
  String _renderDefaultVariants(List<String> axes) {
    if (axes.isEmpty) return '';
    final buf = StringBuffer()..writeln('    defaultVariants: {');
    for (final axis in axes) {
      buf.writeln("      '$axis': 'default',");
    }
    buf.writeln('    },');
    return buf.toString();
  }
}
