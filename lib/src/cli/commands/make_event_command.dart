import 'package:fluttersdk_artisan/artisan.dart';

import '../helpers/magic_stub_loader.dart';

/// Make Event Command.
///
/// Scaffolds a new MagicEvent subclass using the `event` stub template.
///
/// ## Usage
///
/// ```bash
/// artisan make:event UserLoggedIn
/// artisan make:event Auth/TokenRefreshed
/// ```
///
/// ## Output
///
/// Creates a file in `lib/app/events/` with a dispatchable event class
/// that extends `MagicEvent`.
class MakeEventCommand extends ArtisanGeneratorCommand {
  @override
  CommandBoot get boot => CommandBoot.none;

  @override
  String get name => 'make:event';

  @override
  String get description => 'Create a new event class';

  @override
  String getDefaultNamespace() => 'lib/app/events';

  @override
  String getStub() => MagicStubLoader.load('event');

  /// Returns placeholder replacements for the event stub.
  ///
  /// Replaces `{{ className }}`, `{{ snakeName }}`, and `{{ description }}`
  /// from the parsed name.
  @override
  Map<String, String> getReplacements(String name) {
    final parsed = StringHelper.parseName(name);

    return {
      '{{ className }}': parsed.className,
      '{{ snakeName }}': StringHelper.toSnakeCase(parsed.className),
      '{{ description }}': 'the ${parsed.className} action occurs',
    };
  }
}
