import 'package:fluttersdk_artisan/artisan.dart';
import 'package:path/path.dart' as path;

import '../helpers/magic_stub_loader.dart';

/// The `make:repository` generator command.
///
/// Scaffolds a new [Repository] subclass inside `lib/app/repositories/`,
/// caching one REST resource's rows by id (Eloquent's identity map).
///
/// ## Usage
///
/// ```bash
/// artisan make:repository Monitor            # -> MonitorRepository
/// artisan make:repository MonitorRepository  # Suffix already present
/// artisan make:repository Monitor --force    # Overwrite existing file
/// ```
class MakeRepositoryCommand extends ArtisanGeneratorCommand {
  /// Optional test root override: injected in tests to avoid touching the
  /// real filesystem.
  final String? _testRoot;

  /// Creates a [MakeRepositoryCommand].
  ///
  /// Pass [testRoot] to pin the project root to a temp directory during tests.
  MakeRepositoryCommand({String? testRoot}) : _testRoot = testRoot;

  @override
  CommandBoot get boot => CommandBoot.none;

  @override
  String get name => 'make:repository';

  @override
  String get description => 'Create a new repository class';

  @override
  String getDefaultNamespace() => 'lib/app/repositories';

  @override
  String getStub() => MagicStubLoader.load('repository');

  @override
  String getProjectRoot() => _testRoot ?? super.getProjectRoot();

  /// Normalises [name] so the last path segment always carries the
  /// `Repository` suffix. Used by both [getPath] and [buildClass] to keep
  /// the class identifier, file name, and stub substitutions in sync.
  String _normalizeName(String name) {
    final parsed = StringHelper.parseName(name);
    final className = parsed.className.endsWith('Repository')
        ? parsed.className
        : '${parsed.className}Repository';

    return parsed.directory.isEmpty
        ? className
        : '${parsed.directory}/$className';
  }

  /// Returns the class name with the `Repository` suffix guaranteed.
  String _resolveClassName(String name) {
    final parsed = StringHelper.parseName(name);
    return parsed.className.endsWith('Repository')
        ? parsed.className
        : '${parsed.className}Repository';
  }

  /// Overrides to produce the Repository-suffixed file name as the output path.
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
  /// substitution writes the Repository-suffixed class name.
  @override
  String buildClass(String name) => super.buildClass(_normalizeName(name));

  @override
  Map<String, String> getReplacements(String name) {
    // [name] is already normalised (Repository-suffixed) at this point.
    final className = StringHelper.parseName(name).className;
    final modelName = className.replaceAll('Repository', '');
    final modelSnakeName = StringHelper.toSnakeCase(modelName);

    return {
      '{{ modelName }}': modelName,
      '{{ modelSnakeName }}': modelSnakeName,
      '{{ resourceName }}': StringHelper.toPlural(modelSnakeName),
    };
  }
}
