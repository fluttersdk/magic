import 'package:fluttersdk_artisan/artisan.dart';

import '../helpers/magic_stub_loader.dart';

/// The `make:controller` generator command.
///
/// Scaffolds a new MagicController class using the controller stub templates.
///
/// ## Usage
///
/// ```bash
/// artisan make:controller Monitor            # → lib/app/controllers/monitor_controller.dart
/// artisan make:controller Admin/Dashboard    # → lib/app/controllers/admin/dashboard_controller.dart
/// artisan make:controller Monitor --resource # → Resource controller with CRUD methods
/// ```
///
/// The `Controller` suffix is appended automatically when omitted.
class MakeControllerCommand extends ArtisanGeneratorCommand {
  /// Optional test root override — enables isolation in unit tests.
  final String? _testRoot;

  /// Captures the parsed `--resource` flag at [handle] time so [getStub] can
  /// honour it without re-reading the [ArtisanContext.input].
  bool _resourceFlag = false;

  /// Creates a [MakeControllerCommand].
  ///
  /// [testRoot] overrides the project root resolution, used in tests only.
  MakeControllerCommand({String? testRoot}) : _testRoot = testRoot;

  @override
  CommandBoot get boot => CommandBoot.none;

  @override
  String get name => 'make:controller';

  @override
  String get description => 'Create a new controller class';

  @override
  String getDefaultNamespace() => 'lib/app/controllers';

  @override
  String getProjectRoot() => _testRoot ?? super.getProjectRoot();

  @override
  void configure(ArgParser parser) {
    // 1. Register --force (and base args) from parent first.
    super.configure(parser);

    // 2. Add controller-specific flags.
    parser.addFlag(
      'resource',
      abbr: 'r',
      help: 'Generate a resource controller with CRUD methods',
      negatable: false,
    );
    parser.addOption(
      'model',
      abbr: 'm',
      help: 'The model the controller applies to',
    );
  }

  @override
  String getStub() => MagicStubLoader.load(
    _resourceFlag ? 'controller.resource' : 'controller',
  );

  /// Provides extra placeholder replacements for the controller stub.
  ///
  /// [name] is the BASE name without the `Controller` suffix
  /// (e.g., `Monitor`, `Admin/Dashboard`).
  @override
  Map<String, String> getReplacements(String name) {
    final parsed = StringHelper.parseName(name);
    return {'{{ snakeName }}': StringHelper.toSnakeCase(parsed.className)};
  }

  @override
  Future<int> handle(ArtisanContext ctx) async {
    final rawName = ctx.input.argument(0);
    if (rawName == null || rawName.isEmpty) {
      ctx.output.error('Not enough arguments (missing: "name").');
      return 1;
    }

    // 1. Capture --resource so [getStub] selects the right template.
    _resourceFlag = ctx.input.hasOption('resource');

    // 2. Derive base name (no Controller suffix) and full name (with suffix).
    final baseName = _stripSuffix(rawName, 'Controller');
    final fullName = _withSuffix(rawName, 'Controller');

    // 3. Resolve output path using the FULL name so filename is correct
    //    (e.g., MonitorController → monitor_controller.dart).
    final filePath = getPath(fullName);

    // 4. Abort if file exists and --force was not provided.
    if (FileHelper.fileExists(filePath) && !ctx.input.hasOption('force')) {
      ctx.output.error('File already exists at $filePath');
      return 1;
    }

    // 5. Build stub content using the BASE name so {{ className }} resolves
    //    correctly — the stub appends "Controller" to the placeholder itself.
    final content = buildClass(baseName);
    FileHelper.writeFile(filePath, content);

    ctx.output.success('Created: $filePath');
    return 0;
  }

  /// Returns [name] with [suffix] appended to the last path segment if absent.
  String _withSuffix(String name, String suffix) {
    final parts = name.split('/');
    final last = parts.last;
    final normalisedLast = last.endsWith(suffix) ? last : '$last$suffix';
    return [...parts.sublist(0, parts.length - 1), normalisedLast].join('/');
  }

  /// Returns [name] with [suffix] removed from the last path segment if present.
  String _stripSuffix(String name, String suffix) {
    final parts = name.split('/');
    final last = parts.last;
    final strippedLast = last.endsWith(suffix)
        ? last.substring(0, last.length - suffix.length)
        : last;
    return [...parts.sublist(0, parts.length - 1), strippedLast].join('/');
  }
}
