import 'package:fluttersdk_artisan/artisan.dart';
import 'package:path/path.dart' as path;

import '../helpers/run_child.dart';
import 'make_action_command.dart';
import 'make_controller_command.dart';
import 'make_factory_command.dart';
import 'make_form_command.dart';
import 'make_model_command.dart';
import 'make_repository_command.dart';
import 'make_request_command.dart';
import 'make_test_command.dart';
import 'make_view_command.dart';

/// One file of the vertical: the generator that owns it, the arguments that
/// make that generator write it, and where it lands.
///
/// [keepExisting] marks the files a resource is built AROUND (the model and
/// its factory): present ones are skipped with a note instead of clashing.
typedef _Write = ({
  ArtisanCommand command,
  List<String> args,
  String path,
  bool keepExisting,
});

/// The `make:resource` generator command: magic's analogue of Laravel's
/// `make:model --all`.
///
/// Composes the owning generators into one CRUD vertical for a model: model
/// and factory, repository, the create/update/delete actions, the Store and
/// Update requests, the resource form object, a `--resource --actions`
/// controller, and the list and form views, plus the tests for the actions,
/// the form and the controller. It writes no file itself; every file comes
/// from its own generator through [RunChild].
///
/// The run is all-or-nothing: every target path is checked before anything
/// is written. A present model or factory is kept; any other present file
/// fails the run (exit 1, nothing written) unless `--force` is passed.
///
/// The route lines are printed for `RouteServiceProvider.boot()`, never
/// written into it.
///
/// ## Usage
///
/// ```bash
/// artisan make:resource Monitor
/// artisan make:resource Monitor --no-views   # Data and logic layers only
/// artisan make:resource Monitor --no-model   # The model already exists
/// artisan make:resource Monitor --force      # Overwrite the clashes
/// ```
class MakeResourceCommand extends ArtisanGeneratorCommand {
  /// Optional test root override: injected in tests to avoid touching the
  /// real filesystem.
  final String? _testRoot;

  /// Creates a [MakeResourceCommand].
  ///
  /// Pass [testRoot] to pin the project root to a temp directory during tests.
  MakeResourceCommand({String? testRoot}) : _testRoot = testRoot;

  @override
  CommandBoot get boot => CommandBoot.none;

  @override
  String get name => 'make:resource';

  @override
  String get description =>
      'Create a model with its repository, actions, requests, form, '
      'controller, views and tests';

  @override
  String getDefaultNamespace() => 'lib/app';

  /// This command composes other generators; [getStub] is unused (mirrors
  /// `make:test` and `make:component`).
  @override
  String getStub() => '';

  @override
  String getProjectRoot() => _testRoot ?? super.getProjectRoot();

  @override
  void configure(ArgParser parser) {
    super.configure(parser);
    parser.addFlag(
      'views',
      help: 'Generate the list and form views (--no-views to skip).',
      defaultsTo: true,
    );
    parser.addFlag(
      'model',
      help: 'Generate the model and its factory (--no-model to skip).',
      defaultsTo: true,
    );
  }

  @override
  Future<int> handle(ArtisanContext ctx) async {
    final String? model = ctx.input.argument(0);
    if (model == null || model.isEmpty) {
      ctx.output.error('Not enough arguments (missing: "name").');
      return 1;
    }

    // 1. The chained make:test reads the package name from pubspec.yaml;
    //    without it the run would stop halfway through the vertical.
    final String pubspecPath = path.join(getProjectRoot(), 'pubspec.yaml');
    if (!FileHelper.fileExists(pubspecPath)) {
      ctx.output.error('pubspec.yaml not found at $pubspecPath');
      return 1;
    }

    final bool force = ctx.input.hasOption('force');
    final bool withViews = ctx.input.option('views') as bool;
    final List<_Write> plan = _plan(
      model,
      withModel: ctx.input.option('model') as bool,
      withViews: withViews,
    );

    // 2. Preflight every target before the first write, so a clash leaves
    //    the project exactly as it was.
    final List<_Write> writes = <_Write>[];
    final List<String> clashes = <String>[];
    for (final _Write write in plan) {
      if (!FileHelper.fileExists(write.path)) {
        writes.add(write);
      } else if (write.keepExisting) {
        ctx.output.info('Skipped: ${write.path} (already exists)');
      } else if (force) {
        writes.add(write);
      } else {
        clashes.add(write.path);
      }
    }
    if (clashes.isNotEmpty) {
      for (final String clash in clashes) {
        ctx.output.error('File already exists at $clash');
      }
      ctx.output.error('Nothing was written. Pass --force to overwrite.');
      return 1;
    }

    // 3. Hand each file to its owning generator; stop at the first failure.
    for (final _Write write in writes) {
      final int code = await RunChild.run(write.command, <String>[
        ...write.args,
        if (force) '--force',
      ], ctx);
      if (code != 0) return code;
    }

    // 4. Routes belong to the app's RouteServiceProvider: print, never edit.
    if (withViews) _printRoutes(ctx, model);

    return 0;
  }

  /// Builds the ordered list of files the vertical for [model] consists of,
  /// each resolved to its path by its owning generator's own `getPath`.
  List<_Write> _plan(
    String model, {
    required bool withModel,
    required bool withViews,
  }) {
    final String snake = StringHelper.toSnakeCase(model);
    final String plural = StringHelper.toPlural(snake);
    final String pluralClass = StringHelper.toPascalCase(plural);

    final List<_Write> plan = <_Write>[];

    void add(
      ArtisanGeneratorCommand command,
      List<String> args,
      String pathName, {
      TestKind? test,
      bool keepExisting = false,
    }) {
      final String filePath = command.getPath(pathName);
      plan.add((
        command: command,
        args: args,
        path: filePath,
        keepExisting: keepExisting,
      ));
      if (test == null) return;

      plan.add((
        command: MakeTestCommand(testRoot: _testRoot),
        args: <String>[args.first, '--kind=${test.value}'],
        path: _testPathFor(filePath),
        keepExisting: false,
      ));
    }

    // 1. The data layer: model, factory, repository.
    if (withModel) {
      add(
        MakeModelCommand(testRoot: _testRoot),
        <String>[model],
        model,
        keepExisting: true,
      );
      add(
        MakeFactoryCommand(testRoot: _testRoot),
        <String>[model],
        model,
        keepExisting: true,
      );
    }
    add(MakeRepositoryCommand(testRoot: _testRoot), <String>[model], model);

    // 2. The write path: one action per kind, then the requests they send.
    for (final String kind in const <String>['create', 'update', 'delete']) {
      final String action = '$plural/${StringHelper.toPascalCase(kind)}$model';
      add(
        MakeActionCommand(testRoot: _testRoot),
        <String>[action, '--kind=$kind', '--model=$model'],
        action,
        test: TestKind.action,
      );
    }
    for (final String verb in const <String>['Store', 'Update']) {
      add(MakeRequestCommand(testRoot: _testRoot), <String>[
        '$verb$model',
      ], '$verb$model');
    }

    // 3. The form object and the controller that read and write through it.
    add(
      MakeFormCommand(testRoot: _testRoot),
      <String>[model, '--resource=$model'],
      model,
      test: TestKind.form,
    );
    add(
      MakeControllerCommand(testRoot: _testRoot),
      <String>[model, '--resource', '--actions', '--model=$model'],
      '${model}Controller',
      test: TestKind.controller,
    );

    // 4. The screens.
    if (withViews) {
      add(MakeViewCommand(testRoot: _testRoot), <String>[
        '$plural/${pluralClass}List',
        '--controller=$model',
        '--list',
      ], '$plural/${pluralClass}ListView');
      add(MakeViewCommand(testRoot: _testRoot), <String>[
        '$plural/${model}Form',
        '--controller=$model',
        '--form=${model}FormObject',
      ], '$plural/${model}FormView');
    }

    return plan;
  }

  /// The test `make:test` writes for the class at [classPath]: the same path
  /// with `lib/` swapped for `test/` and a `_test` suffix.
  String _testPathFor(String classPath) {
    final String root = getProjectRoot();
    final String relative = path.relative(classPath, from: root);
    final String mirrored = path.joinAll(<String>[
      'test',
      ...path.split(relative).skip(1),
    ]);
    return path.join(root, '${path.withoutExtension(mirrored)}_test.dart');
  }

  /// Prints the index and create routes for [model]'s views, ready to paste
  /// into `RouteServiceProvider.boot()`.
  void _printRoutes(ArtisanContext ctx, String model) {
    final String plural = StringHelper.toPlural(
      StringHelper.toSnakeCase(model),
    );
    final String pluralClass = StringHelper.toPascalCase(plural);

    ctx.output
      ..info('')
      ..info('Add these routes to RouteServiceProvider.boot():')
      ..info(
        "  MagicRoute.page('/$plural', () => const ${pluralClass}ListView())"
        ".name('$plural.index');",
      )
      ..info(
        "  MagicRoute.page('/$plural/create', () => const ${model}FormView())"
        ".name('$plural.create').stacked();",
      );
  }
}
