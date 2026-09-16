import 'package:flutter/material.dart';

/// A page whose route carries the platform's own transition and back gestures.
///
/// go_router's `CustomTransitionPage` builds a bare `PageRoute` and calls the
/// caller's `transitionsBuilder` directly, which is why none of magic's other
/// transitions has ever had a back gesture: Flutter installs the iOS
/// edge-swipe detector INSIDE `CupertinoPageTransition` rather than beside it,
/// and it reaches a route only through a transition mixin. Mixing in
/// [MaterialRouteTransitionMixin] routes the whole thing through
/// `Theme.of(context).pageTransitionsTheme`, so one page type answers every
/// platform: the Cupertino slide plus its swipe on iOS and macOS, predictive
/// back on Android, the zoom on Windows and Linux.
///
/// [swipeBack] is the per-route opt-out. It refuses the GESTURE only; Flutter's
/// `popGestureEnabled` already refuses a route guarded by `PopScope`, which is
/// the right tool when the answer is "not yet" rather than "not by swiping".
@immutable
class MagicPlatformPage<T> extends Page<T> {
  /// The screen this page shows.
  final Widget child;

  /// Whether a back gesture may pop this page.
  final bool swipeBack;

  /// Creates a page that uses the running platform's page transition.
  const MagicPlatformPage({
    required this.child,
    this.swipeBack = true,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  @override
  Route<T> createRoute(BuildContext context) =>
      _MagicPlatformPageRoute<T>(this);
}

class _MagicPlatformPageRoute<T> extends PageRoute<T>
    with MaterialRouteTransitionMixin<T> {
  _MagicPlatformPageRoute(MagicPlatformPage<T> page) : super(settings: page);

  MagicPlatformPage<T> get _page => settings as MagicPlatformPage<T>;

  @override
  Widget buildContent(BuildContext context) => _page.child;

  // `ModalRoute` declares this abstract, so an answer is required rather than
  // optional. Const true, which is what go_router's own pages answer: a page
  // still in the list keeps its state while another covers it.
  @override
  bool get maintainState => true;

  // Narrowing only. `super` already refuses when the route is first in the
  // stack, when a pop would be handled internally, when a `PopScope` vetoes
  // it, and mid-animation, so this adds the app's own answer on top of
  // Flutter's rather than replacing it.
  @override
  bool get popGestureEnabled => _page.swipeBack && super.popGestureEnabled;
}
