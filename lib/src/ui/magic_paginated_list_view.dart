import 'package:flutter/widgets.dart';

import '../http/magic_paginator.dart';

/// Builds one row of a [MagicPaginatedListView].
typedef MagicPaginatedItemBuilder<E> =
    Widget Function(BuildContext context, E item, int index);

/// A lazily built list over a [MagicPaginator], fetching the next page as the
/// end of the current one comes into view.
///
/// The lazy part is the point. Rendering a long collection as a column of every
/// row costs one build, one layout and one semantics node per row on the first
/// frame, whether or not the reader ever scrolls that far; this builds the rows
/// the viewport can show and asks for more only when the reader gets there.
///
/// ## It needs a bounded height
///
/// This is a [ListView], so it expands to whatever height it is given and
/// throws when it is given an unbounded one. Inside a page that already
/// scrolls, give it a bound:
///
/// ```dart
/// WDiv(
///   className: 'h-[600px]',
///   child: MagicPaginatedListView<CheckRow>(
///     paginator: controller.checks,
///     itemBuilder: (_, CheckRow row, _) => CheckHistoryRow(row: row),
///   ),
/// )
/// ```
///
/// Putting it in a page scroll view WITHOUT a bound, or with `shrinkWrap: true`
/// to make that work, defeats it entirely: shrink-wrapping measures every row,
/// so all of them get built and nothing is saved. A page that wants one
/// continuous scroll needs a sliver-based scaffold instead.
class MagicPaginatedListView<E> extends StatefulWidget {
  /// Creates a lazy list over [paginator].
  const MagicPaginatedListView({
    super.key,
    required this.paginator,
    required this.itemBuilder,
    this.emptyState,
    this.loadingFooter,
    this.loadMoreExtent = 400,
    this.padding,
    this.separatorBuilder,
  });

  /// The collection to render, and the source of the next page.
  final MagicPaginator<E> paginator;

  /// Builds one row.
  final MagicPaginatedItemBuilder<E> itemBuilder;

  /// Rendered instead of the list once a first page has arrived empty.
  final Widget? emptyState;

  /// Rendered below the last row while the next page is in flight.
  final Widget? loadingFooter;

  /// How close to the end, in pixels, triggers the next page.
  ///
  /// Larger fetches earlier, so the rows are usually there before the reader
  /// reaches them; the cost of overshooting is a page fetched and never looked
  /// at. The default is about a screen of a phone-sized list.
  final double loadMoreExtent;

  /// Padding around the list.
  final EdgeInsetsGeometry? padding;

  /// Builds the divider between two rows, when the list wants one.
  final IndexedWidgetBuilder? separatorBuilder;

  @override
  State<MagicPaginatedListView<E>> createState() =>
      _MagicPaginatedListViewState<E>();
}

class _MagicPaginatedListViewState<E> extends State<MagicPaginatedListView<E>> {
  final ScrollController _controller = ScrollController();

  /// The row count the last viewport-fill attempt was made at.
  ///
  /// Guards the fill against asking again for a page that arrived and added
  /// nothing. See [_fillViewport].
  int? _lastFilledCount;

  @override
  void initState() {
    super.initState();
    widget.paginator.addListener(_onPaginatorChanged);
  }

  @override
  void didUpdateWidget(MagicPaginatedListView<E> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.paginator, widget.paginator)) {
      oldWidget.paginator.removeListener(_onPaginatorChanged);
      widget.paginator.addListener(_onPaginatorChanged);
    }
  }

  @override
  void dispose() {
    widget.paginator.removeListener(_onPaginatorChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onPaginatorChanged() {
    if (mounted) setState(() {});
  }

  /// Fetches again when the rows in hand do not fill the viewport.
  ///
  /// [_onScroll] cannot cover this: a list shorter than its own viewport does
  /// not scroll, so no notification is ever posted and the next page is never
  /// asked for. The reader is left with a truncated list and no way to extend
  /// it, which any `perPage` smaller than a tall viewport reaches.
  ///
  /// Runs after the frame, because a viewport measures itself during layout and
  /// `maxScrollExtent` is not known before then.
  ///
  /// ## Why it stops
  ///
  /// This callback re-arms on every build and a failed `loadMore` leaves
  /// `hasMore` true on purpose, so the naive version composes into a fetch per
  /// frame: build, post-frame, fetch, fail, notify, build. Measured at 22
  /// requests across 20 frames against an endpoint that was already returning
  /// 500. Two gates close it, one per shape:
  ///
  /// - **An error stops it.** A failure is not an invitation to retry harder,
  ///   and the retry belongs to whoever renders that error.
  /// - **A page that added no rows stops it.** A server handing back a cursor
  ///   beside an empty `data` array never grows the list, so the viewport is
  ///   never filled and nothing else would ever say stop.
  void _fillViewport(Duration _) {
    if (!mounted || !_controller.hasClients) return;
    if (_controller.position.maxScrollExtent > 0) return;

    final MagicPaginator<E> paginator = widget.paginator;
    if (paginator.error != null) return;

    final int count = paginator.items.length;
    if (_lastFilledCount == count) return;
    _lastFilledCount = count;

    paginator.loadMore();
  }

  /// Asks for the next page when the tail is within [loadMoreExtent].
  ///
  /// Returns false so the notification keeps bubbling: a caller further up may
  /// be listening to the same scroll for its own reasons, and swallowing it
  /// here would be this widget deciding that on their behalf.
  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.extentAfter <= widget.loadMoreExtent) {
      // Safe to call on every frame: the paginator refuses while a request is
      // in flight and while there is nothing more to fetch.
      widget.paginator.loadMore();
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final MagicPaginator<E> paginator = widget.paginator;

    if (paginator.isEmpty && widget.emptyState != null) {
      return widget.emptyState!;
    }

    final List<E> items = paginator.items;
    final bool showFooter =
        widget.loadingFooter != null && paginator.isLoading && items.isNotEmpty;
    final int itemCount = items.length + (showFooter ? 1 : 0);

    Widget rowAt(BuildContext context, int index) {
      if (index >= items.length) return widget.loadingFooter!;

      return widget.itemBuilder(context, items[index], index);
    }

    if (paginator.hasMore) {
      WidgetsBinding.instance.addPostFrameCallback(_fillViewport);
    }

    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: widget.separatorBuilder == null
          ? ListView.builder(
              controller: _controller,
              padding: widget.padding,
              itemCount: itemCount,
              itemBuilder: rowAt,
            )
          : ListView.separated(
              controller: _controller,
              padding: widget.padding,
              itemCount: itemCount,
              itemBuilder: rowAt,
              separatorBuilder: widget.separatorBuilder!,
            ),
    );
  }
}
