import 'package:fluttersdk_artisan/artisan.dart';

import '../helpers/magic_stub_loader.dart';

/// Make Enum Command.
///
/// Scaffolds a new string-backed enum class using the `enum` stub template.
///
/// ## Usage
///
/// ```bash
/// artisan make:enum MonitorType
/// artisan make:enum Status/OrderStatus
/// ```
///
/// ## Output
///
/// Creates a file in `lib/app/enums/` with value/label pattern,
/// `fromValue()` factory, and `selectOptions` getter.
class MakeEnumCommand extends ArtisanGeneratorCommand {
  @override
  CommandBoot get boot => CommandBoot.none;

  @override
  String get name => 'make:enum';

  @override
  String get description => 'Create a new enum';

  @override
  String getDefaultNamespace() => 'lib/app/enums';

  @override
  String getStub() => MagicStubLoader.load('enum');

  /// Returns placeholder replacements for the enum stub.
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
