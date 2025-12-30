import 'package:fluttersdk_magic/fluttersdk_magic.dart';

import '../app/controllers/auth_controller.dart';
import '../resources/views/layouts/auth_layout_view.dart';

/// Authentication routes.
///
/// Define login, register, password reset routes here.
void registerAuthRoutes() {
  MagicRoute.group(
    prefix: '/auth',
    middleware: ['guest'],
    layout: (child) => AuthLayoutView(child: child),
    routes: () {
      MagicRoute.page('/login', AuthController.instance.login);
      MagicRoute.page('/register', AuthController.instance.register);
    },
  );
}
