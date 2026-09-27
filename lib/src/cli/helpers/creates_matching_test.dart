import 'package:fluttersdk_artisan/artisan.dart';

import '../commands/make_test_command.dart';
import 'run_child.dart';

/// Adds a shared `--test` flag to a `make:*` generator, so `--test` chains
/// `make:test` to scaffold the matching test right after the class itself.
///
/// A host command applies the mixin (`class MakeXCommand extends
/// ArtisanGeneratorCommand with CreatesMatchingTest`), which registers
/// `--test` automatically via [configure]; the host's `handle` calls
/// [createMatchingTest] when `ctx.input.hasOption('test')` is true.
mixin CreatesMatchingTest on ArtisanGeneratorCommand {
  @override
  void configure(ArgParser parser) {
    super.configure(parser);
    parser.addFlag(
      'test',
      help: 'Also scaffold the matching test for the generated class.',
      negatable: false,
    );
  }

  /// Chains `make:test <name> --kind=<kind>` through [RunChild], reusing
  /// [ctx]'s output stream so both files report in the same feedback block.
  ///
  /// [name] is the same name the host generator received (nested paths like
  /// `Monitors/CreateMonitor` are supported), so the generated test mirrors
  /// the generated class's location. The child's project root is pinned to
  /// this command's own [getProjectRoot], so the chained write lands in the
  /// same (possibly test-isolated) tree the host wrote to.
  Future<int> createMatchingTest(
    ArtisanContext ctx,
    TestKind kind,
    String name,
  ) {
    return RunChild.run(MakeTestCommand(testRoot: getProjectRoot()), <String>[
      name,
      '--kind=${kind.value}',
      // A host run with --force regenerates its test too, rather than
      // stopping on the test the previous run wrote.
      if (ctx.input.hasOption('force')) '--force',
    ], ctx);
  }
}
