import 'package:flutter/material.dart';
import 'package:fluttersdk_magic/fluttersdk_magic.dart';
import '../../resources/views/welcome_view.dart';

class WelcomeController extends MagicController {
  // One-line lazy registration!
  static WelcomeController get instance =>
      Magic.findOrPut(WelcomeController.new);

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Show the Welcome Page.
  ///
  /// This is the main entry point for the '/' route.
  Widget index() {
    return const WelcomeView();
  }

  // ---------------------------------------------------------------------------
  // Business Logic & Data
  // ---------------------------------------------------------------------------

  String get appName => Config.get<String>('app.name', 'Unknown')!;
  String get appEnv => Config.get<String>('app.env', 'production')!;
  String get dbHost => Config.get<String>('database.host', 'localhost')!;
  int get dbPort => Config.get<int>('database.port', 5432)!;

  /// Example: Store a secret using encryption.
  void storeSecret() {
    const secret = 'My Super Secret Credit Card';
    final encrypted = Crypt.encrypt(secret);

    Magic.snackbar('Encrypted', encrypted);

    final decrypted = Crypt.decrypt(encrypted);

    if (decrypted == secret) {
      Magic.success('Success', 'Decryption matched original secret');
    }
  }
}
