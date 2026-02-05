import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import '../../resources/views/about_view.dart';

class AboutController extends MagicController {
  // One-line lazy registration!
  static AboutController get instance => Magic.findOrPut(AboutController.new);

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Show the About Page.
  Widget index() {
    return const AboutView();
  }

  // ---------------------------------------------------------------------------
  // Business Logic
  // ---------------------------------------------------------------------------

  String get appName => Config.get<String>('app.name', 'Magic App')!;
  String get appEnv => Config.get<String>('app.env', 'production')!;
}
