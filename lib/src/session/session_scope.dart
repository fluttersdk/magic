import 'dart:async';

import 'package:flutter/foundation.dart';

import '../facades/auth.dart';
import '../facades/log.dart';
import '../foundation/magic.dart';
import 'session_scoped.dart';

/// Keeps every [SessionScoped] controller and registered holder pointed at
/// the session that is authenticated right now.
///
/// Static because everything it coordinates is process-wide: `Auth.stateNotifier`
/// is one notifier per guard and `Magic.controllers` is one registry. A second
/// instance would listen to the same notifier and reset everything twice per
/// identity change.
///
/// [attach] is explicit: no core provider calls it, because it must be the
/// LAST `Auth.stateNotifier` listener so realtime, polling and locale already
/// point at the new session before its data is refetched.
///
/// ```dart
/// @override
/// Future<void> boot() async {
///   SessionScope.identity = () => Auth.check() ? '${Auth.id()}:$teamId' : null;
///   SessionScope.attach();
/// }
/// ```
class SessionScope {
  SessionScope._();

  /// Reads the identity that owns the data in scope, or null while nobody is
  /// signed in.
  ///
  /// Defaults to the authenticated user id. A team-scoped app sets a resolver
  /// that includes the active team (`<userId>:<teamId>`), so a team switch by
  /// the same user also counts as a change. Null means unauthenticated and
  /// nothing else.
  static String? Function() identity = _authenticatedUserId;

  /// The identity the scoped holders currently hold data for.
  static String? _current;

  /// The notifier [attach] subscribed to, held so [detach] unsubscribes from
  /// that exact instance: re-binding the guard hands back a different notifier
  /// through the facade. Doubles as the attached flag.
  static ValueNotifier<int>? _notifier;

  /// Non-controller holders (repositories) reset alongside the controllers.
  static final Set<SessionScoped> _holders = <SessionScoped>{};

  /// Whether a subscription to auth state changes is currently active.
  static bool get isAttached => _notifier != null;

  static String? _authenticatedUserId() => Auth.check() ? '${Auth.id()}' : null;

  /// Records the identity the app boots with, then resets every scoped holder
  /// on each later identity change.
  ///
  /// Idempotent: while attached this is a no-op, because a second subscription
  /// would reset everything twice per change.
  static void attach() {
    if (_notifier != null) return;

    // Records the boot identity; nothing has resolved a scoped holder yet, so
    // the first REAL change is the first one that resets.
    sync();

    _notifier = Auth.stateNotifier..addListener(sync);
  }

  /// Unsubscribes from auth state changes and forgets the recorded identity.
  ///
  /// Registered holders and the [identity] resolver are kept: they belong to
  /// their owners, not to the subscription.
  static void detach() {
    _notifier?.removeListener(sync);
    _notifier = null;
    _current = null;
  }

  /// Adds a non-controller [holder] (a repository) to every later reset.
  /// Controllers need no registration; they are found in `Magic.controllers`.
  static void register(SessionScoped holder) {
    _holders.add(holder);
  }

  /// Removes [holder] from later resets; call it when the holder is disposed.
  static void unregister(SessionScoped holder) {
    _holders.remove(holder);
  }

  /// Compares the current [identity] with the recorded one and, on a change to
  /// a non-null identity, resets every scoped controller and holder in place.
  ///
  /// An unchanged identity is a no-op, since `Auth.stateNotifier` also bumps on
  /// a plain session restore. A change to null (logout) is recorded without a
  /// reset: from the login screen a refetch can only 401, and the next login
  /// resets before any authenticated view renders. Controllers are never
  /// deleted here: a mounted `MagicStatefulView` holds its instance, and a
  /// deleted-then-disposed controller would freeze that view.
  static void sync() {
    final String? next = identity();
    if (next == _current) return;

    _current = next;
    if (next == null) return;

    // Snapshot first: a reset may resolve and register another controller,
    // which would otherwise mutate the registry mid-iteration. A Set, so a
    // controller that is also registered as a holder resets once.
    final Set<SessionScoped> scoped = <SessionScoped>{
      ...Magic.controllers.whereType<SessionScoped>(),
      ..._holders,
    };

    for (final SessionScoped holder in scoped) {
      // Listeners are synchronous and a reset is not, so it runs unawaited;
      // catchError keeps one failure from aborting the others or escaping as
      // an unhandled async error. Logged rather than rethrown because there is
      // no caller left to hand it to.
      unawaited(
        holder.resetForSession().catchError((Object error) {
          Log.error('[SessionScope] session reset failed: $error');
        }),
      );
    }
  }
}
