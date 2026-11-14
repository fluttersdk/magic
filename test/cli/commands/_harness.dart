import 'package:dowel/dowel.dart';

/// Shared test harness for `make:*` generator command tests.
///
/// Builds a bare [DowelContext] driving [command] with [args]: parses
/// [args] against the command's own [ArgParser] (via [command.configure])
/// and wraps the result in an [ArgvInput], the same shape every
/// `make_*_command_test.dart` file hand-rolled as a local `_ctx` helper
/// (see `make_action_command_test.dart`).
///
/// Pass [registry] to give the command the application registry a real
/// dispatch would, for commands that look a sibling up by name.
DowelContext buildCommandContext(
  DowelCommand command,
  List<String> args, {
  DowelRegistry? registry,
}) {
  final parser = ArgParser();
  command.configure(parser);
  final input = ArgvInput.parse(parser, args);
  return DowelContext.bare(input, BufferedOutput(), registry: registry);
}

/// Stands in for a generator a plugin registers (`make:migration`,
/// `make:factory`, `make:seeder` from magic_local_storage), recording every
/// invocation instead of writing a file.
class RecordingGenerator extends DowelGeneratorCommand {
  RecordingGenerator(this.name, {required this.root});

  @override
  final String name;

  /// Project root [getPath] resolves against.
  final String root;

  /// The name argument and the `--create` option of each run, in order.
  final List<({String? argument, String? create})> runs =
      <({String? argument, String? create})>[];

  @override
  String get description => 'Recording stand-in for $name';

  @override
  String getStub() => '';

  @override
  String getDefaultNamespace() => 'lib/database/recorded';

  @override
  String getProjectRoot() => root;

  @override
  void configure(ArgParser parser) {
    super.configure(parser);
    parser.addOption('create');
  }

  @override
  Future<int> handle(DowelContext ctx) async {
    runs.add((
      argument: ctx.input.argument(0),
      create: ctx.input.option('create') as String?,
    ));
    return 0;
  }
}
