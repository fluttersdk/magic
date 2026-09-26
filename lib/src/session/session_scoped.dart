/// Contract for anything whose cached state belongs to exactly ONE
/// authenticated session: a controller or a repository holding rows fetched
/// for the identity that is signed in right now.
///
/// magic resolves controllers as Type-keyed singletons and runs `onInit` once
/// per instance lifetime, so a logout followed by a login, or a team switch,
/// never re-runs the initial fetch on its own. On a team-scoped product that
/// shows one tenant's data to another. [SessionScope] calls [resetForSession]
/// on every registered controller implementing this, plus every holder passed
/// to `SessionScope.register`, whenever the identity changes.
///
/// [resetForSession] must CLEAR before it refetches. Ordinary reload paths are
/// deliberately non-destructive (a transport failure keeps the last-known-good
/// rows), and that is wrong across an identity change: a failed refetch must
/// leave the screen empty, never populated with the previous session's data.
///
/// ```dart
/// class ProjectController extends MagicController
///     with MagicStateMixin<List<Project>>
///     implements SessionScoped {
///   @override
///   Future<void> resetForSession() async {
///     setEmpty();
///     await loadProjects();
///   }
/// }
/// ```
abstract interface class SessionScoped {
  /// Drops every cached row for the previous session, publishes the cleared
  /// state, then refetches for the identity that is now authenticated.
  ///
  /// Called on login and on team switch, never on logout: from the login
  /// screen a refetch can only produce 401s. Runs IN PLACE on the live
  /// instance; the caller never deletes or re-creates it. A throw is isolated
  /// and logged by the caller, but leaves this holder cleared and unrefetched.
  Future<void> resetForSession();
}
