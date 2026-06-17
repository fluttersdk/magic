import 'package:fluttersdk_artisan/artisan.dart';

import '../helpers/magic_stub_loader.dart';

import 'make_controller_command.dart';
import 'make_factory_command.dart';
import 'make_migration_command.dart';
import 'make_policy_command.dart';
import 'make_seeder_command.dart';

/// The `make:model` generator command.
///
/// Scaffolds a new Eloquent model class using the model stub template.
/// Can optionally generate related classes (migration, controller, factory,
/// seeder, policy) using the corresponding flags.
///
/// ## Usage
///
/// ```bash
/// artisan make:model Monitor
/// artisan make:model Monitor -mcfsp
/// artisan make:model Monitor --all
/// ```
class MakeModelCommand extends ArtisanGeneratorCommand {
  /// Optional test root override — enables isolation in unit tests.
  final String? _testRoot;

  /// Creates a [MakeModelCommand].
  ///
  /// [testRoot] overrides the project root resolution, used in tests only.
  MakeModelCommand({String? testRoot}) : _testRoot = testRoot;

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
      help:
          'Generate a migration, seeder, factory, policy, and resource controller for the model',
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
  Future<int> handle(ArtisanContext ctx) async {
    final name = ctx.input.argument(0);
    if (name == null || name.isEmpty) {
      ctx.output.error('Not enough arguments (missing: "name").');
      return 1;
    }

    // 1. Generate the model class itself.
    final filePath = getPath(name);
    if (FileHelper.fileExists(filePath) && !ctx.input.hasOption('force')) {
      ctx.output.error('File already exists at $filePath');
    } else {
      final content = buildClass(name);
      FileHelper.writeFile(filePath, content);
      ctx.output.success('Created: $filePath');
    }

    // 2. Determine whether --all was passed.
    final doAll = ctx.input.hasOption('all');

    final parsed = StringHelper.parseName(name);
    final className = parsed.className;

    // 3. Generate Migration.
    if (doAll || ctx.input.hasOption('migration')) {
      final tableName = StringHelper.toPlural(
        StringHelper.toSnakeCase(className),
      );
      await _runChild(MakeMigrationCommand(testRoot: _testRoot), [
        'create_${tableName}_table',
        '--create=$tableName',
      ], ctx);
    }

    // 4. Generate Factory.
    if (doAll || ctx.input.hasOption('factory')) {
      await _runChild(MakeFactoryCommand(testRoot: _testRoot), [
        className,
      ], ctx);
    }

    // 5. Generate Seeder.
    if (doAll || ctx.input.hasOption('seeder')) {
      await _runChild(MakeSeederCommand(testRoot: _testRoot), [className], ctx);
    }

    // 6. Generate Policy.
    if (doAll || ctx.input.hasOption('policy')) {
      await _runChild(MakePolicyCommand(testRoot: _testRoot), [
        className,
        '--model=$className',
      ], ctx);
    }

    // 7. Generate Controller.
    if (doAll || ctx.input.hasOption('controller')) {
      final controllerArgs = [className];
      if (doAll) controllerArgs.add('--resource');
      await _runChild(
        MakeControllerCommand(testRoot: _testRoot),
        controllerArgs,
        ctx,
      );
    }

    return 0;
  }

  /// Runs a sibling artisan command programmatically.
  ///
  /// Parses [args] against the child's own [ArgParser], wraps the result in an
  /// [ArgvInput], and reuses the parent's [ArtisanOutput] so the user sees a
  /// single uninterrupted stream of feedback.
  ///
  /// The child runs in a [ArtisanContext.bare] — chained `make:*` commands
  /// never need a VM Service connection.
  Future<int> _runChild(
    ArtisanCommand command,
    List<String> args,
    ArtisanContext parentCtx,
  ) async {
    final parser = ArgParser();
    command.configure(parser);
    final input = ArgvInput.parse(parser, args);
    return command.handle(ArtisanContext.bare(input, parentCtx.output));
  }
}
