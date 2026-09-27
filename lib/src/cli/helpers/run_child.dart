import 'package:fluttersdk_artisan/artisan.dart';

/// Runs a sibling artisan command programmatically, in-process.
///
/// Shared by every `make:*` command that chains another generator:
/// `make:model --all` (migration/factory/seeder/policy/controller),
/// `make:component` (`previews:refresh`), and [CreatesMatchingTest]'s
/// `--test` flag (`make:test`).
class RunChild {
  const RunChild._();

  /// Parses [args] against [command]'s own [ArgParser], wraps the result in
  /// an [ArgvInput], and hands the child a [ArtisanContext.bare] that reuses
  /// [parentCtx]'s [ArtisanOutput] so the operator sees one uninterrupted
  /// feedback stream.
  ///
  /// The child runs in a bare context: chained `make:*` commands never need
  /// a VM Service connection.
  static Future<int> run(
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
