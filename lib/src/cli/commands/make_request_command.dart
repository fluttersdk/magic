import 'package:fluttersdk_artisan/artisan.dart';

import '../helpers/magic_stub_loader.dart';
import 'package:path/path.dart' as path;

/// The `make:request` generator command.
///
/// Scaffolds a new form-request class inside `lib/app/validation/requests/`,
/// containing a typed `rules()` method for request validation.
///
/// ## Usage
///
/// ```bash
/// artisan make:request StoreMonitor             # → StoreMonitorRequest
/// artisan make:request StoreMonitorRequest      # Suffix already present
/// artisan make:request StoreMonitor --force     # Overwrite existing file
/// ```
class MakeRequestCommand extends ArtisanGeneratorCommand {
  /// Optional project root override — injected in tests to avoid touching the
  /// real filesystem.
  final String? _testRoot;

  /// Creates a [MakeRequestCommand].
  ///
  /// Pass [testRoot] to pin the project root to a temp directory during tests.
  MakeRequestCommand({String? testRoot}) : _testRoot = testRoot;

  @override
  CommandBoot get boot => CommandBoot.none;

  @override
  String get name => 'make:request';

  @override
  String get description => 'Create a new form request class';

  @override
  String getDefaultNamespace() => 'lib/app/validation/requests';

  @override
  String getStub() => MagicStubLoader.load('request');

  @override
  String getProjectRoot() => _testRoot ?? super.getProjectRoot();

  /// Normalises [name] so the last path segment always carries the `Request`
  /// suffix. Used by [buildClass] so the parent's internal class-name
  /// substitution writes the Request-suffixed identifier.
  String _normalizeName(String name) {
    final parsed = StringHelper.parseName(name);
    final className = parsed.className.endsWith('Request')
        ? parsed.className
        : '${parsed.className}Request';

    return parsed.directory.isEmpty
        ? className
        : '${parsed.directory}/$className';
  }

  /// Override to produce the Request-suffixed file name as the output path.
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
  /// substitution writes the Request-suffixed class name.
  @override
  String buildClass(String name) => super.buildClass(_normalizeName(name));

  @override
  Map<String, String> getReplacements(String name) {
    // [name] is already normalised (Request-suffixed) at this point.
    final className = StringHelper.parseName(name).className;

    return {
      '{{ snakeName }}': StringHelper.toSnakeCase(className),
      '{{ actionDescription }}': _toHumanReadable(className),
    };
  }

  /// Returns the class name with 'Request' suffix guaranteed.
  String _resolveClassName(String name) {
    final parsed = StringHelper.parseName(name);
    return parsed.className.endsWith('Request')
        ? parsed.className
        : '${parsed.className}Request';
  }

  /// Converts a PascalCase class name (with 'Request' stripped) to a
  /// human-readable action description for stub docblocks.
  ///
  /// Example: `StoreMonitorRequest` → `store monitor`
  String _toHumanReadable(String className) {
    final withoutSuffix = className.replaceAll('Request', '');
    return StringHelper.toSnakeCase(withoutSuffix).replaceAll('_', ' ');
  }
}
