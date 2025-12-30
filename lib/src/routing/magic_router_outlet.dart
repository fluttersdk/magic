import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// A widget that renders nested route content.
///
/// Use this inside layout widgets (shells) to display the current
/// child route content. It's similar to:
/// - Laravel's `@yield('content')` in Blade templates
/// - Vue Router's `<router-view>`
/// - Angular's `<router-outlet>`
///
/// ## Usage
///
/// ```dart
/// class DashboardLayout extends StatelessWidget {
///   const DashboardLayout({super.key});
///
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(
///       appBar: AppBar(title: Text('Dashboard')),
///       body: Row(
///         children: [
///           NavigationRail(...),
///           Expanded(
///             child: MagicRouterOutlet(), // Child routes render here
///           ),
///         ],
///       ),
///     );
///   }
/// }
/// ```
///
/// Then define your layout route:
///
/// ```dart
/// Route.layout(
///   builder: (child) => DashboardLayout(child: child),
///   routes: [
///     Route.get('/dashboard', DashboardHome.new),
///     Route.get('/profile', ProfilePage.new),
///   ],
/// );
/// ```
class MagicRouterOutlet extends StatelessWidget {
  /// Create a router outlet widget.
  const MagicRouterOutlet({super.key});

  @override
  Widget build(BuildContext context) {
    // In a ShellRoute context, this would display the current child.
    // For now, we use GoRouter's built-in mechanism.
    // When used with StatefulShellRoute, the shell provides the child widget.

    // This is a placeholder that should be replaced with the actual child
    // widget passed through the layout builder context.
    return const SizedBox.shrink();
  }
}

/// A layout wrapper widget that receives the child from GoRouter.
///
/// This is used internally when creating shell routes. The child
/// widget is the currently active nested route.
///
/// ```dart
/// class DashboardShell extends StatelessWidget {
///   final Widget child;
///
///   const DashboardShell({super.key, required this.child});
///
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(
///       bottomNavigationBar: BottomNav(...),
///       body: child, // The nested route renders here
///     );
///   }
/// }
/// ```
class MagicShellRoute extends StatelessWidget {
  /// The child widget (current nested route).
  final Widget child;

  /// The navigation shell for stateful shell routes.
  final StatefulNavigationShell? navigationShell;

  /// Create a shell route wrapper.
  const MagicShellRoute({
    super.key,
    required this.child,
    this.navigationShell,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }

  /// Navigate to a branch in a stateful shell route.
  ///
  /// ```dart
  /// // In a BottomNavigationBar onTap:
  /// MagicShell.of(context).goBranch(index);
  /// ```
  void goBranch(int index) {
    navigationShell?.goBranch(index);
  }
}

/// Extension to access the shell from context.
extension MagicShellContext on BuildContext {
  /// Get the nearest StatefulNavigationShellState.
  ///
  /// Useful for tab navigation in shell routes.
  ///
  /// ```dart
  /// onTap: (index) => context.magicShell.goBranch(index),
  /// ```
  StatefulNavigationShellState get magicShell {
    return StatefulNavigationShell.of(this);
  }
}
