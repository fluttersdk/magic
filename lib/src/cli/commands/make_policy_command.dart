import 'package:fluttersdk_artisan/artisan.dart';

import '../helpers/magic_stub_loader.dart';
import 'package:path/path.dart' as path;

/// The `make:policy` generator command.
///
/// Scaffolds a new authorization policy class inside `lib/app/policies/`,
/// extending the Magic `Policy` base and registering `Gate.define` callbacks.
///
/// ## Usage
///
/// ```bash
/// artisan make:policy Monitor               # → MonitorPolicy
/// artisan make:policy MonitorPolicy         # Suffix already present
/// artisan make:policy Monitor --model=Monitor
/// artisan make:policy Admin/Dashboard       # Nested path support
/// artisan make:policy Monitor --force       # Overwrite existing file
/// ```
class MakePolicyCommand extends ArtisanGeneratorCommand {
  /// Optional project root override — injected in tests to avoid touching the
  /// real filesystem.
  final String? _testRoot;

  /// Captures the parsed `--model` value during [handle] so [getReplacements]
  /// can consume it without re-reading the [ArtisanContext.input].
  String? _modelOption;

  /// Creates a [MakePolicyCommand].
  ///
  /// Pass [testRoot] to pin the project root to a temp directory during tests.
  MakePolicyCommand({String? testRoot}) : _testRoot = testRoot;

  @override
  CommandBoot get boot => CommandBoot.none;

  @override
  String get name => 'make:policy';

  @override
  String get description => 'Create a new policy class';

  @override
  String getDefaultNamespace() => 'lib/app/policies';

  @override
  String getStub() => MagicStubLoader.load('policy');

  @override
  String getProjectRoot() => _testRoot ?? super.getProjectRoot();

  @override
  void configure(ArgParser parser) {
    super.configure(parser);
    parser.addOption(
      'model',
      abbr: 'm',
      help: 'The model the policy applies to',
    );
  }

  @override
  Future<int> handle(ArtisanContext ctx) async {
    // 1. Capture --model so [getReplacements] (called from [buildClass]) can use it.
    _modelOption = ctx.input.option('model') as String?;
    return super.handle(ctx);
  }

  /// Normalises [name] so the last path segment always carries the `Policy`
  /// suffix. Used by both [getPath] and [buildClass] to keep the class
  /// identifier, file name, and stub substitutions in sync.
  String _normalizeName(String name) {
    final parsed = StringHelper.parseName(name);
    final className = parsed.className.endsWith('Policy')
        ? parsed.className
        : '${parsed.className}Policy';

    return parsed.directory.isEmpty
        ? className
        : '${parsed.directory}/$className';
  }

  /// Override to produce the Policy-suffixed file name as the output path.
  @override
  String getPath(String name) {
    final parsed = StringHelper.parseName(name);
    final className = _resolveClassName(name);
    final fileName = StringHelper.toSnakeCase(className);
    final namespace = getDefaultNamespace();
    final projectRoot = getProjectRoot();

    if (parsed.directory.isEmpty) {
      return path.join(projectRoot, namespace, '$fileName.dart');
    }

    return path.join(
      projectRoot,
      namespace,
      parsed.directory,
      '$fileName.dart',
    );
  }

  /// Overrides stub building so the parent's internal `{{ className }}`
  /// substitution writes the Policy-suffixed class name.
  @override
  String buildClass(String name) => super.buildClass(_normalizeName(name));

  @override
  Map<String, String> getReplacements(String name) {
    // [name] is already normalised (Policy-suffixed) at this point.
    final className = StringHelper.parseName(name).className;

    // Model name: from --model option, or inferred by removing 'Policy' suffix.
    final modelName = _modelOption ?? className.replaceAll('Policy', '');
    final modelSnakeName = StringHelper.toSnakeCase(modelName);

    return {
      '{{ snakeName }}': StringHelper.toSnakeCase(className),
      '{{ modelSnakeName }}': modelSnakeName,
      '{{ modelClass }}': modelName,
      '{{ modelName }}': modelName,
    };
  }

  /// Returns the class name with 'Policy' suffix guaranteed.
  String _resolveClassName(String name) {
    final parsed = StringHelper.parseName(name);
    return parsed.className.endsWith('Policy')
        ? parsed.className
        : '${parsed.className}Policy';
  }
}
