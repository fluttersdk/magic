import 'package:magic/magic.dart';

import '../resources/views/welcome_view.dart';

/// Application Route Definitions.
///
/// Register all application routes here. This function is called by
/// [RouteServiceProvider.boot()] during the Magic bootstrap lifecycle.
///
/// See also: `lib/app/kernel.dart` for middleware registration.
void registerAppRoutes() {
  // A root route: switched to, never drilled into, so it is left unstacked.
  // `to()` replaces the page list, which is what a tab or a nav destination
  // wants and what keeps a re-tap from growing the stack.
  MagicRoute.page('/', () => const WelcomeView()).title('Welcome');

  // A detail route: pushed, so it can be popped. That is what gives it the
  // iOS edge-swipe back, and on Android it is what keeps the system back
  // button inside the app rather than closing it, since Flutter reports
  // whether the app has anything to pop and the answer with one page is no.
  //
  // `swipeBack(false)` would refuse the gesture alone; reach for `PopScope`
  // when the route should not be left at all, such as a dirty form.
  MagicRoute.page(
    '/welcome/details',
    () => const WelcomeView(),
  ).title('Welcome').stacked().transition(RouteTransition.platform);
}
