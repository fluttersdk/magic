import 'package:fluttersdk_artisan/artisan.dart';
import 'package:path/path.dart' as path;

import '../helpers/magic_stub_loader.dart';
import 'previews_refresh_command.dart';

/// `make:component <Name> [--variants=intent,size] [--slots]`: scaffolds an
/// atomic 4-file component folder (`<name>.dart`, `<name>.recipe.dart`,
/// `<name>.preview.dart`, `index.dart`) under `lib/ui/components/<name>/`, then
/// chains `previews:refresh` so the new preview lands in `_previews.g.dart`.
///
/// The component class is unprefixed PascalCase (`make:component Avatar` ->
/// `class Avatar`); the folder + files are `lower_snake_case`. The recipe is
/// seeded with the requested `--variants` axes (each value left empty for the
/// author to fill with token classNames). `--slots` seeds a [WindSlotRecipe]
/// shape instead of a single-element [WindRecipe].
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

    // 4. Write the four atomic files from their stubs. --slots swaps the
    //    single-element recipe + component for the WindSlotRecipe variants.
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
      'preview',
      '$snakeName.preview.dart',
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

    // 5. Chain previews:refresh so the new preview lands in _previews.g.dart.
    await _runChild(
      PreviewsRefreshCommand(projectRoot: getProjectRoot()),
      const <String>[],
      ctx,
    );

    return 0;
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

  /// Runs a sibling artisan command programmatically (the `make:model --all`
  /// chaining pattern): parse [args] against the child's own [ArgParser], wrap
  /// in an [ArgvInput], reuse the parent [ArtisanOutput] so the user sees one
  /// uninterrupted feedback stream.
  Future<int> _runChild(
    ArtisanCommand command,
    List<String> args,
    ArtisanContext parentCtx,
  ) async {
    final parser = ArgParser();
    command.configure(parser);
    final input = ArgvInput.parse(parser, args);
    return command.handle(ArtisanContext.bare(input, parentCtx.output));
  }
}
