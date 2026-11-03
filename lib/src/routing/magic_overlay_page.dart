import 'package:flutter/material.dart';

/// A page that shows its route as a modal bottom sheet over the page below.
///
/// Built by the router for a route declared with `RouteDefinition.overlay`.
/// The frame reproduces `showModalBottomSheet(backgroundColor:
/// Colors.transparent, isScrollControlled: true, useRootNavigator: true)`,
/// the call a panel component makes when it opens itself imperatively, so a
/// panel that draws its own surface, handle and safe-area padding gets the
/// same frame whichever way it was opened. No `constraints` are set, so the
/// Material 3 default width cap applies. A page has no caller context, so no
/// themes are captured: the sheet inherits the app-level ones, not a
/// layout's own `Theme` or `DefaultTextStyle`.
@immutable
class MagicOverlayPage<T> extends Page<T> {
  /// The panel the sheet shows.
  final Widget child;

  /// Asked before the sheet closes; null lets every dismissal through.
  final bool Function()? canDismiss;

  /// Whether a scrim tap or a drag should close the sheet through the
  /// browser's Back right now; null off the web.
  final bool Function()? closesThroughBrowser;

  /// Steps the browser back, used when [closesThroughBrowser] says so; the
  /// callback it is given runs if the browser never answers.
  final void Function([VoidCallback? onGivenUp])? stepBrowserBack;

  /// Creates a page that opens [child] as a bottom sheet.
  const MagicOverlayPage({
    required this.child,
    this.canDismiss,
    this.closesThroughBrowser,
    this.stepBrowserBack,
    super.key,
    super.name,
  });

  @override
  Route<T> createRoute(BuildContext context) {
    final MaterialLocalizations localizations = MaterialLocalizations.of(
      context,
    );

    return _MagicOverlayRoute<T>(
      page: this,
      barrierLabel: localizations.scrimLabel,
      barrierOnTapHint: localizations.scrimOnTapHint(
        localizations.bottomSheetLabel,
      ),
      modalBarrierColor: Theme.of(context).bottomSheetTheme.modalBarrierColor,
    );
  }
}

class _MagicOverlayRoute<T> extends ModalBottomSheetRoute<T> {
  _MagicOverlayRoute({
    required MagicOverlayPage<T> page,
    super.barrierLabel,
    super.barrierOnTapHint,
    super.modalBarrierColor,
  }) : super(
         settings: page,
         // Read through the route rather than captured, so a page update
         // (a new query, a router refresh) reaches the sheet.
         builder: (context) =>
             (ModalRoute.of(context)!.settings as MagicOverlayPage<T>).child,
         backgroundColor: Colors.transparent,
         isScrollControlled: true,
       );

  MagicOverlayPage<T> get _page => settings as MagicOverlayPage<T>;

  bool get _dismissible => _page.canDismiss?.call() ?? true;

  // Read again every time the route rebuilds its barrier and its sheet, so a
  // guard that says no turns the scrim and the drag off rather than letting
  // them start a close the router then refuses.
  @override
  bool get isDismissible => _dismissible;

  @override
  bool get enableDrag => _dismissible;

  /// Whether a close the user makes now goes through the browser's Back.
  bool get _throughBrowser =>
      _dismissible && (_page.closesThroughBrowser?.call() ?? false);

  /// Whether the sheet is sliding shut on its own: a drag let go below the
  /// close threshold, which `BottomSheet` flings shut before it pops.
  bool get _closingByDrag =>
      controller!.status == AnimationStatus.reverse ||
      controller!.status == AnimationStatus.dismissed;

  /// Whether a `maybePop` (a scrim tap, Escape, a `BackButton`) would pop the
  /// sheet now and should go through the browser's Back instead.
  ///
  /// Only when Flutter itself would pop: a panel's `PopScope(canPop: false)`,
  /// a `Form` that refuses, or a local history entry answers first, and the
  /// sheet then stays where it is with the browser untouched.
  bool get _maybePopsThroughBrowser =>
      super.popDisposition == RoutePopDisposition.pop && _throughBrowser;

  // A scrim tap asks `Navigator.maybePop`, which reads this first. Refusing
  // here and stepping back in [onPopInvokedWithResult] keeps the in-app pop,
  // and the history entry it would add, from happening at all.
  @override
  RoutePopDisposition get popDisposition => _maybePopsThroughBrowser
      ? RoutePopDisposition.doNotPop
      : super.popDisposition;

  @override
  void onPopInvokedWithResult(bool didPop, T? result) {
    if (!didPop && _maybePopsThroughBrowser) {
      _page.stepBrowserBack!();

      return;
    }

    super.onPopInvokedWithResult(didPop, result);
  }

  // A drag calls `Navigator.pop` directly, which go_router hands to this route
  // first only when it says it handles the pop itself. Said only while a drag
  // is closing the sheet, so a `Navigator.pop` or `popUntil` from the app
  // keeps go_router's synchronous pop.
  @override
  bool get willHandlePopInternally =>
      (_closingByDrag && _throughBrowser) || super.willHandlePopInternally;

  @override
  bool didPop(T? result) {
    if (_closingByDrag && _throughBrowser) {
      _page.stepBrowserBack!(_slideBackUp);

      return false;
    }

    return super.didPop(result);
  }

  /// Open a sheet a drag slid shut again, when the browser never answered
  /// the step back that drag asked for.
  void _slideBackUp() {
    if (!isActive || !controller!.isDismissed) return;

    controller!.forward();
    changedInternalState();
  }

  @override
  void install() {
    super.install();
    controller!.addStatusListener(_reopenAfterRefusedClose);
  }

  /// Slide the sheet back up when a drag closed it and the guard refused.
  ///
  /// `BottomSheet` flings itself shut before it asks the navigator to pop,
  /// and the router's exit check can only refuse the pop, not the fling. A
  /// guard that turned to no after the sheet was built (a form that became
  /// dirty) still had dragging on, so without this the route would stay on
  /// the stack with nothing visible and the scrim swallowing every tap.
  void _reopenAfterRefusedClose(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || !isCurrent || _dismissible) {
      return;
    }

    controller!.forward();
    changedInternalState();
  }
}
