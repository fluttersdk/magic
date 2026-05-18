import 'dart:io';
import 'package:fluttersdk_artisan/artisan.dart';
import 'package:magic/cli.dart' show MagicArtisanProvider;

Future<void> main(List<String> args) async {
  exit(await runArtisan(args, baseProviders: [MagicArtisanProvider()]));
}
