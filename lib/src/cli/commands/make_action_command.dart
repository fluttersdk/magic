import 'package:fluttersdk_artisan/artisan.dart';

import '../helpers/magic_stub_loader.dart';

/// The `make:action` generator command.
///
/// Scaffolds a new [MagicAction] subclass inside `lib/app/actions/`.
///
/// ## Usage
///
/// ```bash
/// artisan make:action PauseMonitor            # -> lib/app/actions/pause_monitor.dart
/// artisan make:action Monitors/PauseMonitor   # Nested path support
/// artisan make:action PauseMonitor --force    # Overwrite existing file
/// ```
class MakeActionCommand extends ArtisanGeneratorCommand {
  /// Optional test root override: injected in tests to avoid touching the
  /// real filesystem.
  final String? _testRoot;

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
  String getStub() => MagicStubLoader.load('action');

  @override
  String getProjectRoot() => _testRoot ?? super.getProjectRoot();
}
