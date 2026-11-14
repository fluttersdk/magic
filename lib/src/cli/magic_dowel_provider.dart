import 'package:dowel/dowel.dart';

import 'commands/design_lint_command.dart';
import 'commands/design_sync_command.dart';
import 'commands/magic_install_command.dart';
import 'commands/make_action_command.dart';
import 'commands/make_component_command.dart';
import 'commands/make_controller_command.dart';
import 'commands/make_enum_command.dart';
import 'commands/make_event_command.dart';
import 'commands/make_form_command.dart';
import 'commands/make_lang_command.dart';
import 'commands/make_listener_command.dart';
import 'commands/make_middleware_command.dart';
import 'commands/make_model_command.dart';
import 'commands/make_policy_command.dart';
import 'commands/make_provider_command.dart';
import 'commands/make_repository_command.dart';
import 'commands/make_request_command.dart';
import 'commands/make_resource_command.dart';
import 'commands/make_test_command.dart';
import 'commands/make_view_command.dart';
import 'commands/previews_refresh_command.dart';

/// Contributes magic:* (and make:*) commands to the dowel dispatcher.
///
/// Wired in two places: `bin/dowel.dart` passes it as a base provider so
/// `dart run magic:dowel magic:install` works in an app that has no
/// `bin/dispatcher.dart` yet, and `magic:install` records it in the
/// consumer's `.dowel/plugins.json` so `plugins:refresh` lists it in
/// `lib/app/_plugins.g.dart`, which the consumer's `bin/dispatcher.dart`
/// loads.
///
/// Ships the magic code-gen surface: 17 make:* generators + `previews:refresh`
/// + `design:sync` + `design:lint` + `magic:install`. `make:migration`,
/// `make:seeder` and `make:factory` belong to magic_local_storage's provider;
/// registering them here too would make dowel exit on the name collision.
class MagicDowelProvider extends DowelServiceProvider {
  @override
  String get providerName => 'magic';

  @override
  List<DowelCommand> commands() => <DowelCommand>[
    MakeControllerCommand(),
    MakeViewCommand(),
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
    MakeActionCommand(),
    MakeFormCommand(),
    MakeRepositoryCommand(),
    MakeResourceCommand(),
    MakeTestCommand(),
    PreviewsRefreshCommand(),
    DesignSyncCommand(),
    DesignLintCommand(),
    MagicInstallCommand(),
  ];
}
