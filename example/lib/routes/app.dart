import 'package:fluttersdk_magic/fluttersdk_magic.dart';

import '../app/controllers/user_controller.dart';
import '../app/controllers/dashboard_controller.dart';
import '../app/controllers/welcome_controller.dart';
import '../app/controllers/about_controller.dart';
import '../app/controllers/todo_controller.dart';
import '../app/controllers/newsletter_controller.dart';

/// Application routes.
///
/// Routes call controller actions (Laravel-style).
void registerAppRoutes() {
  // Public routes (no middleware)
  MagicRoute.page('/', () => WelcomeController.instance.index());
  MagicRoute.page('/about', () => AboutController.instance.index());

  // Todo List - Database Demo
  MagicRoute.page('/todos', () => TodoController.instance.index());

  // Newsletter - Form Validation Demo
  MagicRoute.page('/newsletter', () => NewsletterController.instance.index());

  // Protected routes (require auth)
  MagicRoute.page(
    '/user',
    () => UserController.instance.index(),
  ).middleware(['auth']);
  MagicRoute.page(
    '/user/:id',
    (id) => UserController.instance.show(id),
  ).middleware(['auth']);

  MagicRoute.page('/dashboard', () => DashboardController.instance.index());
}
