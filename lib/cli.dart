/// CLI barrel for Magic framework.
///
/// Exposes ONLY the artisan-CLI surface (MagicArtisanProvider + the
/// integration glue classes). Does NOT export Magic runtime (no Flutter
/// dart:ui imports), so this barrel is safe for consumption from
/// pure-Dart artisan dispatchers.
///
/// Consumers register the provider in their `bin/artisan.dart`:
///
/// ```dart
/// import 'package:fluttersdk_artisan/artisan.dart';
/// import 'package:magic/cli.dart' show MagicArtisanProvider;
///
/// Future<void> main(List<String> args) async {
///   final registry = ArtisanRegistry()
///     ..registerAll(<ArtisanCommand>[...], providerName: 'fluttersdk_artisan')
///     ..registerProvider(MagicArtisanProvider());
///   exit(await ArtisanApplication(registry: registry).dispatch(args));
/// }
/// ```
///
/// Runtime consumers (lib/main.dart of a Magic-based app) continue to
/// import `package:magic/magic.dart` for facades + Magic.init().
library;

export 'src/cli/magic_artisan_provider.dart';
export 'src/cli/install_stubs.dart';
export 'src/cli/helpers/magic_main_dart_editor.dart';
