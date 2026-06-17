import 'package:flutter/widgets.dart';

/// Test probe that records how many times its subtree is rebuilt.
///
/// Each [build] increments [counter]. Mount one in a position whose rebuilds
/// matter, then read the counter before and after a state change to prove
/// whether that subtree was rebuilt. Granular paths (a [ValueNotifier] driving
/// a scoped builder) should leave a sibling probe's count untouched, while a
/// full-view rebuild bumps every probe in the tree.
final class WidgetBuildCounter extends StatelessWidget {
  /// Mutable build tally; the enclosing test owns and inspects it.
  final ValueNotifier<int> counter;

  /// Subtree rendered on every build.
  final Widget child;

  const WidgetBuildCounter({
    super.key,
    required this.counter,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Count synchronously: post-frame would miss rebuilds that pump() flushes.
    counter.value++;

    return child;
  }
}
