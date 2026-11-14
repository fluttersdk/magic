import 'package:dowel/dowel.dart';

import '../helpers/magic_stub_loader.dart';
import '../helpers/run_child.dart';

import 'make_controller_command.dart';
import 'make_policy_command.dart';
import 'make_repository_command.dart';

/// The `make:model` generator command.
///
/// Scaffolds a new Eloquent model class using the model stub template.
/// Can optionally generate related classes (migration, controller, factory,
/// seeder, policy) using the corresponding flags.
///
/// The migration, factory and seeder generators ship with magic_local_storage,
/// so they are looked up in the dowel registry by name; without the plugin
/// each flag prints a hint and the rest of the run carries on.
///
/// ## Usage
///
/// ```bash
/// dowel make:model Monitor
/// dowel make:model Monitor -mcfsp
/// dowel make:model Monitor --all
/// ```
class MakeModelCommand extends DowelGeneratorCommand {
  /// Optional test root override; enables isolation in unit tests.
  final String? _testRoot;

  /// Creates a [MakeModelCommand].
  ///
  /// [_testRoot] overrides the project root resolution, used in tests only.
  MakeModelCommand({this._testRoot});

  @override
  CommandBoot get boot => CommandBoot.none;

  @override
  String get name => 'make:model';

  @override
  String get description => 'Create a new Eloquent model class';

  @override
  String getDefaultNamespace() => 'lib/app/models';

  @override
  String getProjectRoot() => _testRoot ?? super.getProjectRoot();

  @override
  void configure(ArgParser parser) {
    super.configure(parser);
    parser.addFlag(
      'migration',
      abbr: 'm',
      help: 'Create a new migration file for the model',
      negatable: false,
    );
    parser.addFlag(
      'controller',
      abbr: 'c',
      help: 'Create a new controller for the model',
      negatable: false,
    );
    parser.addFlag(
      'factory',
      abbr: 'f',
      help: 'Create a new factory for the model',
      negatable: false,
    );
    parser.addFlag(
      'seeder',
      abbr: 's',
      help: 'Create a new seeder for the model',
      negatable: false,
    );
    parser.addFlag(
      'policy',
      abbr: 'p',
      help: 'Create a new policy for the model',
      negatable: false,
    );
    parser.addFlag(
      'all',
      abbr: 'a',
      help: 'Generate a migration, seeder, factory, policy, and resource controller for the model',
      negatable: false,
    );
  }

  @override
  String getStub() => MagicStubLoader.load('model');

  @override
  Map<String, String> getReplacements(String name) {
    final parsed = StringHelper.parseName(name);
    final className = parsed.className;
    final tableName = StringHelper.toPlural(
      StringHelper.toSnakeCase(className),
    );

    return {
      '{{ className }}': className,
      '{{ tableName }}': tableName,
      '{{ resourceName }}': tableName,
      '{{ snakeName }}': StringHelper.toSnakeCase(className),
    };
  }

  @override
  Future<int> handle(DowelContext ctx) async {
    final name = ctx.input.argument(0);
    if (name == null || name.isEmpty) {
      ctx.output.error('Not enough arguments (missing: "name").');
      return 1;
    }

    // 1. Generate the model class itself.
    final filePath = getPath(name);
    //    An existing model without --force stops the run, as every other
    //    generator does, so no companion file is written against it.
    if (FileHelper.fileExists(filePath) && !ctx.input.hasOption('force')) {
      ctx.output.error('File already exists at $filePath');
      return 1;
    }
    FileHelper.writeFile(filePath, buildClass(name));
    ctx.output.success('Created: $filePath');

    // 2. Determine whether --all was passed.
    final doAll = ctx.input.hasOption('all');

    final parsed = StringHelper.parseName(name);
    final className = parsed.className;

    // 3. Generate Migration.
    if (doAll || ctx.input.hasOption('migration')) {
      final tableName = StringHelper.toPlural(
        StringHelper.toSnakeCase(className),
      );
      await _runDatabaseGenerator(ctx, 'make:migration', [
        'create_${tableName}_table',
        '--create=$tableName',
      ]);
    }

    // 4. Generate Factory.
    if (doAll || ctx.input.hasOption('factory')) {
      await _runDatabaseGenerator(ctx, 'make:factory', [className]);
    }

    // 5. Generate Seeder.
    if (doAll || ctx.input.hasOption('seeder')) {
      await _runDatabaseGenerator(ctx, 'make:seeder', [className]);
    }

    // 6. Generate Policy.
    if (doAll || ctx.input.hasOption('policy')) {
      await RunChild.run(MakePolicyCommand(testRoot: _testRoot), [
        className,
        '--model=$className',
      ], ctx);
    }

    // 7. Generate Repository (only for --all: a --resource controller reads
    //    through one, so it must exist before the controller is chained).
    if (doAll) {
      await RunChild.run(MakeRepositoryCommand(testRoot: _testRoot), [
        className,
      ], ctx);
    }

    // 8. Generate Controller.
    if (doAll || ctx.input.hasOption('controller')) {
      final controllerArgs = [className];
      if (doAll) {
        controllerArgs
          ..add('--resource')
          ..add('--model=$className');
      }
      await RunChild.run(
        MakeControllerCommand(testRoot: _testRoot),
        controllerArgs,
        ctx,
      );
    }

    return 0;
  }

  /// The generator magic_local_storage registers under [commandName], looked
  /// up in the dispatching application's registry.
  ///
  /// Returns `null` after printing a hint naming the plugin when it is not
  /// installed (or [ctx] carries no registry), so the caller skips that one
  /// file and carries on. Core must never fall back to a generator of its own:
  /// the plugin registering the same name would make dowel exit.
  static DowelCommand? databaseGenerator(DowelContext ctx, String commandName) {
    final command = ctx.registry?.find(commandName);
    if (command != null) return command;

    ctx.output.warning(
      'Skipped $commandName: it ships with magic_local_storage. Add the '
      'package, then run `dart run magic:dowel plugin:install '
      'magic_local_storage`.',
    );
    return null;
  }

  /// Runs the registered [commandName] with [args], or prints the hint.
  Future<void> _runDatabaseGenerator(
    DowelContext ctx,
    String commandName,
    List<String> args,
  ) async {
    final command = databaseGenerator(ctx, commandName);
    if (command == null) return;

    await RunChild.run(command, args, ctx);
  }
}
