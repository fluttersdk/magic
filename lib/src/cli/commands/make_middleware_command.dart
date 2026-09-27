import 'package:fluttersdk_artisan/artisan.dart';

import '../helpers/magic_stub_loader.dart';

/// Make Middleware Command.
///
/// Scaffolds a new Magic middleware class using the `middleware` stub template.
///
/// ## Usage
///
/// ```bash
/// artisan make:middleware EnsureAuthenticated
/// artisan make:middleware Admin/RoleCheck
/// ```
///
/// ## Output
///
/// Creates a file in `lib/app/middleware/` with full nested path support.
class MakeMiddlewareCommand extends ArtisanGeneratorCommand {
  /// Optional project root override — injected in tests to avoid touching the
  /// real filesystem.
  final String? _testRoot;

  /// Creates a [MakeMiddlewareCommand].
  ///
  /// Pass [testRoot] to pin the project root to a temp directory during tests.
  MakeMiddlewareCommand({String? testRoot}) : _testRoot = testRoot;

  @override
  CommandBoot get boot => CommandBoot.none;

  @override
  String get name => 'make:middleware';

  @override
  String get description => 'Create a new middleware class';

  @override
  String getDefaultNamespace() => 'lib/app/middleware';

  @override
  String getStub() => MagicStubLoader.load('middleware');

  @override
  String getProjectRoot() => _testRoot ?? super.getProjectRoot();

  /// Returns placeholder replacements for the middleware stub.
  ///
  /// Replaces `{{ className }}` and `{{ snakeName }}` from the parsed name.
  @override
  Map<String, String> getReplacements(String name) {
    final parsed = StringHelper.parseName(name);

    return {
      '{{ className }}': parsed.className,
      '{{ snakeName }}': StringHelper.toSnakeCase(parsed.className),
    };
  }
}
