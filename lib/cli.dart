/// CLI barrel for Magic framework.
///
/// Exposes ONLY the dowel CLI surface (MagicDowelProvider + the
/// integration glue classes). Does NOT export Magic runtime (no Flutter
/// dart:ui imports), so this barrel is safe for consumption from
/// pure-Dart dowel dispatchers.
///
/// Consumers do not wire the provider by hand: `magic:install` records it
/// in `.dowel/plugins.json`, and `plugins:refresh` lists it in
/// `lib/app/_plugins.g.dart`, which the consumer's `bin/dispatcher.dart`
/// loads. Magic's own executable registers it directly:
///
/// ```dart
/// import 'package:dowel/dowel.dart';
/// import 'package:magic/cli.dart' show MagicDowelProvider;
///
/// Future<void> main(List<String> args) async {
///   exit(await runDowel(args, baseProviders: [MagicDowelProvider()]));
/// }
/// ```
///
/// Runtime consumers (lib/main.dart of a Magic-based app) continue to
/// import `package:magic/magic.dart` for facades + Magic.init().
library;

export 'src/cli/magic_dowel_provider.dart';
export 'src/cli/install_stubs.dart';
export 'src/cli/helpers/magic_main_dart_editor.dart';
export 'src/cli/helpers/main_dart_scaffold_detector.dart';
export 'src/cli/helpers/main_dart_smart_merger.dart';
