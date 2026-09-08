import 'package:flutter/widgets.dart';

import '../http/magic_controller.dart';

/// Rebuilds one subtree when one part of a controller changes, and leaves it
/// alone the rest of the time.
///
/// [MagicController.refreshUI] notifies every listener, and
/// `MagicStatefulViewState` answers by calling `setState` on the whole view.
/// That is the right default: a controller does not know which of its fields a
/// screen reads, and a view that rebuilds is always correct. It stops being
/// cheap on a screen where one field changes often and most of the screen does
/// not care. A search field is the worked example: every keystroke is a
/// notification, and a consumer measured one keystroke rebuilding 220 styled
/// containers, almost none of which could have looked different.
///
/// ```dart
/// MagicSelector<GuideController, String>(
///   controller: controller,
///   selector: (GuideController c) => c.countLabel,
///   builder: (String label) => WText(label),
/// )
/// ```
///
/// ## How it avoids the rebuild
///
/// It caches the widget the builder returned and, while the selected value
/// compares equal, returns that same INSTANCE. `Element.updateChild` short
/// circuits when the new widget is `==` to the mounted one, so an identical
/// instance ends the descent right there and the subtree is never visited.
/// That is what makes this work under a parent that rebuilds anyway: a widget
/// that merely skipped its own `setState` would still be rebuilt from above.
///
/// ## The contract this buys
///
/// [builder] must be a pure function of the value it is handed. A cached child
/// cannot see anything else the closure captured, so this is stale for as long
/// as `count` happens not to move:
///
/// ```dart
/// // WRONG: `total` is captured, and nothing here watches it.
/// MagicSelector<C, int>(
///   controller: c,
///   selector: (C c) => c.count,
///   builder: (int count) => WText('$count of $total'),
/// )
/// ```
///
/// Select both instead. A Dart record has value equality, so it compares by
/// content and the cache still holds:
///
/// ```dart
/// MagicSelector<C, (int, int)>(
///   controller: c,
///   selector: (C c) => (c.count, c.total),
///   builder: ((int, int) v) => WText('${v.$1} of ${v.$2}'),
/// )
/// ```
///
/// Reading an [InheritedWidget] inside the cached subtree is fine and needs no
/// selection: `Theme.of`, `MediaQuery.of` and `WindTheme.of` register their own
/// dependency, and the framework rebuilds a dependent element directly rather
/// than through its parent.
///
/// ## Equality
///
/// Plain `==`, deliberately. A selector that returns a freshly built `List` or
/// `Map` therefore never matches its own cache, because Dart gives collections
/// identity equality, and the subtree rebuilds every notification exactly as it
/// would have without this widget. Deep comparison was the alternative and is
/// worse where it matters: walking a ten thousand channel list on every
/// keystroke costs more than the rebuild it prevents. Select a scalar, a
/// record, or an object whose identity is stable across notifications.
///
/// See also:
///
///  * [MagicBuilder], for a plain [ValueListenable] with no selection step.
class MagicSelector<C extends MagicController, T> extends StatefulWidget {
  /// The controller to watch.
  final C controller;

  /// Reads the one piece of [controller] this subtree depends on.
  ///
  /// Called on every notification, so keep it cheap: a field read or a
  /// memoized getter, never a scan that the controller has not already cached.
  final T Function(C controller) selector;

  /// Builds the subtree from the selected value, and from nothing else.
  ///
  /// Takes no [BuildContext] for the same reason [MagicBuilder] does not: the
  /// value is the whole input. Wrap the result in a [Builder] if a descendant
  /// needs a context of its own.
  final Widget Function(T value) builder;

  /// Creates a [MagicSelector].
  const MagicSelector({
    super.key,
    required this.controller,
    required this.selector,
    required this.builder,
  });

  @override
  State<MagicSelector<C, T>> createState() => _MagicSelectorState<C, T>();
}

class _MagicSelectorState<C extends MagicController, T>
    extends State<MagicSelector<C, T>> {
  late T _value;

  /// The widget [MagicSelector.builder] last returned.
  ///
  /// Returning this instance again is the entire mechanism; see the class doc.
  Widget? _child;

  @override
  void initState() {
    super.initState();
    _value = widget.selector(widget.controller);
    widget.controller.addListener(_onNotified);
  }

  @override
  void didUpdateWidget(covariant MagicSelector<C, T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_onNotified);
      widget.controller.addListener(_onNotified);
      _value = widget.selector(widget.controller);
      _child = null;
    }
  }

  // A changed `selector` or `builder` deliberately does NOT invalidate the
  // cache, and that is the decision the whole widget rests on. Both are written
  // inline in a parent's `build`, so both are a fresh closure on every parent
  // rebuild and comparing them by identity would drop the cache every time,
  // which is the case this exists to serve. A changed selector still takes
  // effect the moment it returns a different value, because `build` re-reads
  // it. A changed builder that would render differently from the same value is
  // the one thing this cannot see, which is why the class doc makes purity a
  // contract rather than a suggestion.

  @override
  void dispose() {
    // `removeListener` during a notification is safe: `ChangeNotifier`
    // tombstones the slot and compacts the list once the outer call finishes.
    widget.controller.removeListener(_onNotified);
    super.dispose();
  }

  void _onNotified() {
    if (!mounted) return;

    final T next = widget.selector(widget.controller);
    if (next == _value) return;

    setState(() {
      _value = next;
      _child = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Re-read here as well as in the listener. A parent can rebuild this widget
    // without any notification having fired (a `setState` higher up, a hot
    // reload), and the cached child would then outlive the value it was built
    // from.
    final T next = widget.selector(widget.controller);
    if (next != _value) {
      _value = next;
      _child = null;
    }

    return _child ??= widget.builder(_value);
  }
}
