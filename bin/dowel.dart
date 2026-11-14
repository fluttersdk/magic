import 'dart:io';

import 'package:dowel/dowel.dart';
import 'package:magic/cli.dart' show MagicDowelProvider;

/// `dart run magic:dowel <command>`.
///
/// Keeps dowel's default delegation on purpose. In an app without a
/// `bin/dispatcher.dart` (before `magic:install`) the commands run here, on
/// the dowel builtins plus [MagicDowelProvider]. Once `magic:install` has
/// scaffolded the dispatcher, every call is handed to `dart run :dispatcher`,
/// whose `lib/app/_plugins.g.dart` lists magic and each plugin registered by
/// `plugin:install`, so plugin commands resolve through this executable too.
/// The dispatcher itself runs with delegation off, so the hand-off cannot loop.
Future<void> main(List<String> args) async {
  exit(await runDowel(args, baseProviders: [MagicDowelProvider()]));
}
