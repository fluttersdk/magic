import 'package:magic_cli/magic_cli.dart';

/// Magic CLI entry point.
void main(List<String> args) async {
  final kernel = Kernel();

  // 1. Register all 18 commands.
  kernel.registerMany([
    InstallCommand(),
    KeyGenerateCommand(),
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
  ]);

  // 2. Execute requested command.
  await kernel.handle(args);
}
