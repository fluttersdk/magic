import 'package:fluttersdk_artisan/artisan.dart';

import 'commands/design_lint_command.dart';
import 'commands/design_sync_command.dart';
import 'commands/key_generate_command.dart';
import 'commands/magic_install_command.dart';
import 'commands/make_component_command.dart';
import 'commands/make_controller_command.dart';
import 'commands/make_enum_command.dart';
import 'commands/make_event_command.dart';
import 'commands/make_factory_command.dart';
import 'commands/make_lang_command.dart';
import 'commands/make_listener_command.dart';
import 'commands/make_middleware_command.dart';
import 'commands/make_migration_command.dart';
import 'commands/make_model_command.dart';
import 'commands/make_policy_command.dart';
import 'commands/make_provider_command.dart';
import 'commands/make_request_command.dart';
import 'commands/make_seeder_command.dart';
import 'commands/make_view_command.dart';
import 'commands/previews_refresh_command.dart';

/// Contributes magic:* (and make:* / key:generate) commands to the artisan
/// dispatcher.
///
/// Host integration:
/// ```dart
/// // lib/config/app.dart
/// final appConfig = {
///   'artisan': {
///     'providers': [MagicArtisanProvider.new],
///   },
/// };
/// ```
///
/// Ships the magic code-gen surface: 15 make:* generators + `previews:refresh`
/// + `design:sync` + `design:lint` + `magic:install` + `key:generate`.
class MagicArtisanProvider extends ArtisanServiceProvider {
  @override
  String get providerName => 'magic';

  @override
  List<ArtisanCommand> commands() => <ArtisanCommand>[
    MakeControllerCommand(),
    MakeViewCommand(),
    MakeMigrationCommand(),
    MakeSeederCommand(),
    MakeFactoryCommand(),
    MakeMiddlewareCommand(),
    MakeProviderCommand(),
    MakeLangCommand(),
    MakeEnumCommand(),
    MakeEventCommand(),
    MakeListenerCommand(),
    MakePolicyCommand(),
    MakeRequestCommand(),
    MakeModelCommand(),
    MakeComponentCommand(),
    PreviewsRefreshCommand(),
    DesignSyncCommand(),
    DesignLintCommand(),
    MagicInstallCommand(),
    KeyGenerateCommand(),
  ];
}
