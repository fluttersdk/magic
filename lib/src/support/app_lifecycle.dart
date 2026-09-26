import 'dart:async';

import 'package:flutter/widgets.dart';

/// Forwards every [WidgetsBinding] lifecycle callback to one stream listener.
///
/// Private, and the only instances are the ones [AppLifecycle.states] holds:
/// the binding keeps its observers for the process's life, so an object that
/// added itself and never came off is a leak that keeps answering.
class _LifecycleObserver with WidgetsBindingObserver {
  _LifecycleObserver(this._report);

  final void Function(AppLifecycleState state) _report;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _report(state);
}

/// The app lifecycle exposed as a stream, for readers constructed before a
/// [WidgetsBinding] necessarily exists.
///
/// A dependency built inside a service provider's `register()` runs before
/// the app has bound anything, so reaching for [WidgetsBinding.instance] at
/// construction time throws. [states] defers that lookup to the moment a
/// listener actually subscribes, and each subscription owns its own observer:
/// the observer goes on the binding at `listen` and comes off at `cancel`, so
/// nothing outlives its reader and nothing before the first listen touches
/// the binding at all.
///
/// Prefer Flutter's own [AppLifecycleListener] when the reader is a
/// widget-lifetime object: it binds to [WidgetsBinding] at construction,
/// which is exactly right once a binding is guaranteed to exist, and it
/// carries the metrics/exit-request callbacks this class deliberately does
/// not. Reach for [AppLifecycle.states] only when construction has to happen
/// before that guarantee holds.
abstract final class AppLifecycle {
  /// The app lifecycle as a stream, reaching [WidgetsBinding] only on listen.
  ///
  /// Built with [Stream.multi] rather than a [StreamController] of this
  /// method's own: a controller built here has nobody to close it, so its
  /// observer would leave the binding only if some caller remembered to close
  /// a sink it never saw. This shape puts the removal on the cancel, which
  /// each listener's own teardown performs.
  static Stream<AppLifecycleState> states() => Stream<AppLifecycleState>.multi((
    MultiStreamController<AppLifecycleState> listener,
  ) {
    final _LifecycleObserver observer = _LifecycleObserver(listener.add);

    WidgetsBinding.instance.addObserver(observer);

    listener.onCancel = () => WidgetsBinding.instance.removeObserver(observer);
  });
}
