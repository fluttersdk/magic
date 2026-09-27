import 'package:fluttersdk_artisan/artisan.dart';

import '../helpers/creates_matching_test.dart';
import '../helpers/magic_stub_loader.dart';
import 'make_test_command.dart';

/// The `make:action` generator command.
///
/// Scaffolds a new [MagicAction] subclass inside `lib/app/actions/`. Plain
/// (no `--kind`) scaffolds the default stateless skeleton; `--kind` with
/// `--model` scaffolds one of the three write variants against that model
/// (see [_kinds]).
///
/// ## Usage
///
/// ```bash
/// artisan make:action PauseMonitor            # -> lib/app/actions/pause_monitor.dart
/// artisan make:action Monitors/PauseMonitor   # Nested path support
/// artisan make:action PauseMonitor --force    # Overwrite existing file
/// artisan make:action Monitors/CreateMonitor --kind=create --model=Monitor
/// artisan make:action Monitors/PauseMonitor --test  # Also scaffold the test
/// ```
class MakeActionCommand extends ArtisanGeneratorCommand
    with CreatesMatchingTest {
  /// Optional test root override: injected in tests to avoid touching the
  /// real filesystem.
  final String? _testRoot;

  /// The write variants `--kind` accepts, each backed by its own
  /// `action.<kind>.stub`.
  static const Set<String> _kinds = <String>{'create', 'update', 'delete'};

  /// Captures the parsed `--kind` value during [handle] so [getStub] and
  /// [getReplacements] can consume it without re-reading [ArtisanContext.input].
  String? _kindOption;

  /// Captures the parsed `--model` value during [handle]; see [_kindOption].
  String? _modelOption;

  /// Creates a [MakeActionCommand].
  ///
  /// Pass [testRoot] to pin the project root to a temp directory during tests.
  MakeActionCommand({String? testRoot}) : _testRoot = testRoot;

  @override
  CommandBoot get boot => CommandBoot.none;

  @override
  String get name => 'make:action';

  @override
  String get description => 'Create a new action class';

  @override
  String getDefaultNamespace() => 'lib/app/actions';

  @override
  String getStub() {
    final String? kind = _kindOption;
    if (kind == null) return MagicStubLoader.load('action');
    return MagicStubLoader.load('action.$kind');
  }

  @override
  String getProjectRoot() => _testRoot ?? super.getProjectRoot();

  @override
  void configure(ArgParser parser) {
    super.configure(parser);
    parser.addOption(
      'kind',
      help: 'The write variant to scaffold: ${_kinds.join('|')}.',
    );
    parser.addOption(
      'model',
      help: 'The model this action writes; required alongside --kind.',
    );
  }

  @override
  Future<int> handle(ArtisanContext ctx) async {
    // 1. Validate --kind against the known set, when given.
    final String? kind = ctx.input.option('kind') as String?;
    if (kind != null && !_kinds.contains(kind)) {
      ctx.output.error(
        'Unknown --kind "$kind". Expected one of: ${_kinds.join(', ')}.',
      );
      return 1;
    }

    // 2. --kind always needs a target model to write against.
    final String? model = ctx.input.option('model') as String?;
    if (kind != null && (model == null || model.isEmpty)) {
      ctx.output.error('--kind requires --model.');
      return 1;
    }

    // 3. Stash both so getStub/getReplacements (called from buildClass,
    //    inside the generator's own handle below) can read them without
    //    re-parsing ctx.input.
    _kindOption = kind;
    _modelOption = model;

    final int code = await super.handle(ctx);
    if (code != 0 || !ctx.input.hasOption('test')) return code;

    // 4. Chain the matching test onto a successful write. The default action
    //    test stub calls `.handle(null)`, which only compiles for the
    //    untyped default action; combined with --kind it still writes that
    //    default test (see wave-1 wisdom in the plan briefing).
    final String name = ctx.input.argument(0)!;
    return createMatchingTest(ctx, TestKind.action, name);
  }

  @override
  Map<String, String> getReplacements(String name) {
    final String? kind = _kindOption;
    final String? model = _modelOption;
    if (kind == null || model == null) return const {};

    final parsed = StringHelper.parseName(name);
    final String modelSnakeName = StringHelper.toSnakeCase(model);
    final String modelVariable = StringHelper.toCamelCase(model);
    final String prefix = _importPrefix(parsed.directory);

    final Map<String, String> replacements = <String, String>{
      '{{ modelName }}': model,
      '{{ modelVariable }}': modelVariable,
      '{{ modelImport }}': "import '${prefix}models/$modelSnakeName.dart';",
    };

    if (kind == 'delete') {
      replacements['{{ repositoryName }}'] = '${model}Repository';
      replacements['{{ repositoryImport }}'] =
          "import '${prefix}repositories/${modelSnakeName}_repository.dart';";
      replacements['{{ modelIdInterpolation }}'] = '\${$modelVariable.id}';
    }

    return replacements;
  }

  /// The `../` prefix reaching `lib/app/` from a generated action file: one
  /// level for [getDefaultNamespace]'s own `actions` segment, plus one more
  /// per nested directory segment in [directory] (e.g. `monitors`).
  String _importPrefix(String directory) {
    final int depth = 1 + (directory.isEmpty ? 0 : directory.split('/').length);
    return '../' * depth;
  }
}
