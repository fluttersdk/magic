import 'package:fluttersdk_artisan/artisan.dart';

/// Shared test harness for `make:*` generator command tests.
///
/// Builds a bare [ArtisanContext] driving [command] with [args]: parses
/// [args] against the command's own [ArgParser] (via [command.configure])
/// and wraps the result in an [ArgvInput], the same shape every
/// `make_*_command_test.dart` file hand-rolled as a local `_ctx` helper
/// (see `make_action_command_test.dart`).
ArtisanContext buildCommandContext(ArtisanCommand command, List<String> args) {
  final parser = ArgParser();
  command.configure(parser);
  final input = ArgvInput.parse(parser, args);
  return ArtisanContext.bare(input, BufferedOutput());
}
