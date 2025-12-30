import 'package:flutter/widgets.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart';

import '../http/magic_controller.dart';
import 'magic_view.dart';

/// A responsive view that adapts to different screen sizes.
///
/// Uses Wind theme breakpoints for consistency with Wind styling.
/// Breakpoints are read from `WindThemeData.screens`:
/// - sm: 640px
/// - md: 768px
/// - lg: 1024px
/// - xl: 1280px
/// - 2xl: 1536px
///
/// ## Usage
///
/// ```dart
/// class DashboardView extends MagicResponsiveView<DashboardController> {
///   const DashboardView({super.key});
///
///   @override
///   Widget phone(BuildContext context) => MobileLayout();
///
///   @override
///   Widget tablet(BuildContext context) => TabletLayout();
///
///   @override
///   Widget desktop(BuildContext context) => DesktopLayout();
/// }
/// ```
abstract class MagicResponsiveView<T extends MagicController>
    extends MagicView<T> {
  const MagicResponsiveView({super.key});

  /// Build phone layout (< sm breakpoint, default 640px).
  Widget phone(BuildContext context);

  /// Build tablet layout (>= sm and < lg).
  Widget tablet(BuildContext context) => phone(context);

  /// Build desktop layout (>= lg, default 1024px).
  Widget desktop(BuildContext context) => tablet(context);

  /// Build watch layout (< 320px).
  Widget watch(BuildContext context) => phone(context);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    // Get breakpoints from Wind theme
    final screens = _getScreens(context);
    final sm = screens['sm'] ?? 640;
    final lg = screens['lg'] ?? 1024;

    // Watch: < 320px
    if (width < 320) {
      return watch(context);
    }

    // Phone: < sm
    if (width < sm) {
      return phone(context);
    }

    // Tablet: < lg
    if (width < lg) {
      return tablet(context);
    }

    // Desktop: >= lg
    return desktop(context);
  }

  /// Get screens from Wind theme or use defaults.
  Map<String, int> _getScreens(BuildContext context) {
    try {
      return context.windScreens;
    } catch (_) {
      // Default breakpoints if no WindTheme
      return {'sm': 640, 'md': 768, 'lg': 1024, 'xl': 1280, '2xl': 1536};
    }
  }
}

/// Extended responsive view with all Wind breakpoints.
///
/// Uses Wind theme screens directly:
/// - xs: < 320
/// - sm: 640
/// - md: 768
/// - lg: 1024
/// - xl: 1280
/// - 2xl: 1536
abstract class MagicResponsiveViewExtended<T extends MagicController>
    extends MagicView<T> {
  const MagicResponsiveViewExtended({super.key});

  /// Extra small (< 320px) - watch/tiny screens.
  Widget xs(BuildContext context);

  /// Small (>= 320 and < sm) - phone portrait.
  Widget sm(BuildContext context) => xs(context);

  /// Medium (>= sm and < md) - phone landscape / small tablet.
  Widget md(BuildContext context) => sm(context);

  /// Large (>= md and < lg) - tablet.
  Widget lg(BuildContext context) => md(context);

  /// Extra large (>= lg and < xl) - small desktop.
  Widget xl(BuildContext context) => lg(context);

  /// 2XL (>= xl) - large desktop.
  Widget xxl(BuildContext context) => xl(context);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    // Get breakpoints from Wind theme
    final screens = _getScreens(context);
    final smBp = screens['sm'] ?? 640;
    final mdBp = screens['md'] ?? 768;
    final lgBp = screens['lg'] ?? 1024;
    final xlBp = screens['xl'] ?? 1280;

    if (width < 320) return xs(context);
    if (width < smBp) return sm(context);
    if (width < mdBp) return md(context);
    if (width < lgBp) return lg(context);
    if (width < xlBp) return xl(context);
    return xxl(context);
  }

  /// Get screens from Wind theme or use defaults.
  Map<String, int> _getScreens(BuildContext context) {
    try {
      return context.windScreens;
    } catch (_) {
      return {'sm': 640, 'md': 768, 'lg': 1024, 'xl': 1280, '2xl': 1536};
    }
  }
}

/// Helper extension to check current breakpoint from Wind.
extension MagicResponsiveContext on BuildContext {
  /// Current screen width.
  double get screenWidth => MediaQuery.of(this).size.width;

  /// Current screen height.
  double get screenHeight => MediaQuery.of(this).size.height;

  /// Check if phone (< sm).
  bool get isPhone => wIsMobile;

  /// Check if tablet (>= sm and < lg).
  bool get isTablet => wIsTablet;

  /// Check if desktop (>= lg).
  bool get isDesktop => wIsDesktop;

  /// Current active breakpoint name from Wind.
  String get activeBreakpoint => wActiveBreakpoint;

  /// Check if screen is at least the given breakpoint.
  bool isAtLeast(String breakpoint) => wScreenIsExt(breakpoint);
}
