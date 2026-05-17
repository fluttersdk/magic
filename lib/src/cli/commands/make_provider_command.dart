import 'package:fluttersdk_artisan/artisan.dart';

/// Make Provider Command.
///
/// Scaffolds a new Magic service provider class using the `provider` stub
/// template. Automatically appends `ServiceProvider` suffix when not already
/// present.
///
/// ## Usage
///
/// ```bash
/// artisan make:provider App                # → AppServiceProvider
/// artisan make:provider AppServiceProvider # → AppServiceProvider (no double suffix)
/// ```
///
/// ## Output
///
/// Creates a file in `lib/app/providers/` with `register()` and `boot()` stubs.
class MakeProviderCommand extends ArtisanGeneratorCommand {
  @override
  CommandBoot get boot => CommandBoot.none;

  @override
  String get name => 'make:provider';

  @override
  String get description => 'Create a new service provider class';

  @override
  String getDefaultNamespace() => 'lib/app/providers';

  @override
  String getStub() => 'provider';

  /// Normalises [name] so the last path segment always carries the
  /// `ServiceProvider` suffix. Used by both [getPath] and [buildClass] to keep
  /// the class identifier, file name, and stub substitutions in sync.
  String _normalizeName(String name) {
    final parsed = StringHelper.parseName(name);
    final className = parsed.className.endsWith('ServiceProvider')
        ? parsed.className
        : '${parsed.className}ServiceProvider';

    return parsed.directory.isEmpty
        ? className
        : '${parsed.directory}/$className';
  }

  /// Overrides path resolution to use the ServiceProvider-suffixed file name.
  @override
  String getPath(String name) => super.getPath(_normalizeName(name));

  /// Overrides stub building so the parent's internal `{{ className }}`
  /// substitution writes the ServiceProvider-suffixed class name.
  @override
  String buildClass(String name) => super.buildClass(_normalizeName(name));

  /// Returns placeholder replacements for the provider stub.
  ///
  /// Replaces `{{ snakeName }}` and `{{ description }}`. The `{{ className }}`
  /// placeholder is handled upstream by [buildClass] normalisation.
  @override
  Map<String, String> getReplacements(String name) {
    // [name] is already normalised (ServiceProvider-suffixed) at this point.
    final parsed = StringHelper.parseName(name);
    final className = parsed.className;

    // 1. Derive snake_case identifier from the final class name.
    final snakeName = StringHelper.toSnakeCase(className);

    // 2. Build a human-readable description from the base name.
    final baseName = className.replaceAll('ServiceProvider', '');
    final description =
        '${StringHelper.toSnakeCase(baseName).replaceAll('_', ' ')} services';

    return {'{{ snakeName }}': snakeName, '{{ description }}': description};
  }
}
