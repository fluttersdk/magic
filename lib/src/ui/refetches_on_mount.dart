import 'dart:async' show unawaited;

import 'package:magic/magic.dart';

/// Refetches a view's data every time the view mounts.
///
/// ## Why this exists
///
/// magic caches controllers as Type-keyed singletons and fires `onInit` ONCE per
/// controller instance, not once per view mount. A controller that loads its data
/// in `onInit` therefore fetches on the first view that resolves it and never
/// again for the lifetime of the app, so navigating away and back re-renders the
/// same cached rows.
///
/// On a data-heavy screen that reads as fabricated data rather than as
/// staleness: a list view can hold a count and a set of rows from the first
/// load while the backend has since served a different count and a row
/// created moments earlier, and only a hard reload clears it. A realtime path
/// that happens to broadcast an update can mask the gap, but that can be
/// hours apart in a quiet app, so it does not close the gap.
///
/// ## Usage
///
/// Mix onto a [MagicStatefulViewState] and point [refetch] at a load method
/// your controller defines:
///
/// ```dart
/// class _ItemsListViewState
///     extends MagicStatefulViewState<ItemsController, ItemsListView>
///     with RefetchesOnMount<ItemsController, ItemsListView> {
///   @override
///   Future<void> refetch() => controller.ensureFresh();
/// }
/// ```
///
/// `ensureFresh` here is YOUR method, not a framework one, and its contract is
/// what makes the mixin safe: it must JOIN a load that is already in flight
/// rather than start a second one. The mount that creates the controller has
/// already started the same load from `onInit`, so a refetch that always
/// fires a new request sends every request twice on the first mount. Keep a
/// separate method for a refresh after a mutation, which must NOT join an
/// older in-flight request, or it hands back a snapshot without the row the
/// caller just created.
///
/// The refetch is fire-and-forget: `build()` renders the cached data immediately
/// and the view rebuilds when the fresh data lands, so a mount never blocks on
/// the network. Have the load keep its last-known-good data on failure, so a
/// failed refetch leaves the screen as it was instead of flickering into an
/// empty state.
mixin RefetchesOnMount<
  C extends MagicController,
  W extends MagicStatefulView<C>
>
    on MagicStatefulViewState<C, W> {
  @override
  void initState() {
    super.initState();
    unawaited(refetch());
  }

  /// The refetch to run on each mount: a controller load that joins an
  /// in-flight request rather than starting a second one.
  Future<void> refetch();
}
