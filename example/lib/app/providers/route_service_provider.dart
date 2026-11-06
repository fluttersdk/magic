import 'package:flutter/widgets.dart' show MediaQuery;
import 'package:magic/magic.dart';

import '../kernel.dart';
import '../../routes/app.dart';

/// Route Service Provider.
///
/// Registers the HTTP kernel and application routes.
class RouteServiceProvider extends ServiceProvider {
  RouteServiceProvider(super.app);

  @override
  void register() {
    // Register middleware kernel — runs synchronously during bootstrap.
    registerKernel();
  }

  @override
  Future<void> boot() async {
    // Choose the frame an overlay route opens in, once per open: a centred
    // dialog from 1024 px (Wind's `lg`), a bottom sheet below. Magic holds no
    // breakpoint, so the app decides. An open frame keeps its form when the
    // window is resized.
    MagicRoute.useOverlayPresentation(
      (context) => MediaQuery.sizeOf(context).width >= 1024
          ? MagicOverlayPresentation.dialog
          : MagicOverlayPresentation.sheet,
    );

    // Register application route definitions.
    registerAppRoutes();
  }
}
