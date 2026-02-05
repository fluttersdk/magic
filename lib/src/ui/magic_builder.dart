import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A simplified builder for ValueListenable objects.
///
/// Provides cleaner, more concise syntax than [ValueListenableBuilder] for
/// reactive UI. The builder receives only the value, without context or child.
///
/// ## Usage
///
/// Instead of the verbose [ValueListenableBuilder]:
///
/// ```dart
/// ValueListenableBuilder<List<Monitor>>(
///   valueListenable: controller.monitorsNotifier,
///   builder: (context, monitors, _) => _buildList(monitors),
/// )
/// ```
///
/// Use the cleaner [MagicBuilder]:
///
/// ```dart
/// MagicBuilder<List<Monitor>>(
///   listenable: controller.monitorsNotifier,
///   builder: (monitors) => _buildList(monitors),
/// )
/// ```
///
/// ## When to Use
///
/// Use [MagicBuilder] when:
/// - You need to react to a single [ValueNotifier] or [ValueListenable]
/// - You don't need access to [BuildContext] in the builder
/// - You want cleaner, more readable code
///
/// Use [ValueListenableBuilder] when:
/// - You need access to [BuildContext] (for Theme.of, MediaQuery, etc.)
/// - You need the `child` optimization for static parts of the tree
///
/// ## Type Safety
///
/// [MagicBuilder] is fully generic and type-safe:
///
/// ```dart
/// // The builder receives a strongly-typed value
/// MagicBuilder<int>(
///   listenable: counter,
///   builder: (count) => Text('$count'), // count is int, not dynamic
/// )
/// ```
///
/// ## Example
///
/// ```dart
/// class MonitorShowView extends MagicStatefulView<MonitorController> {
///   @override
///   Widget build(BuildContext context) {
///     return Column(
///       children: [
///         // Stats section rebuilds when checks load
///         MagicBuilder<List<MonitorCheck>>(
///           listenable: controller.checksNotifier,
///           builder: (checks) => _buildStatsSection(checks),
///         ),
///
///         // Real-time toggle
///         MagicBuilder<bool>(
///           listenable: controller.realTimeEnabledNotifier,
///           builder: (enabled) => Switch(value: enabled, ...),
///         ),
///       ],
///     );
///   }
/// }
/// ```
class MagicBuilder<T> extends StatelessWidget {
  /// The [ValueListenable] to listen to.
  ///
  /// When this listenable notifies its listeners, the widget will rebuild
  /// with the new value.
  final ValueListenable<T> listenable;

  /// Builder function called when the listenable changes.
  ///
  /// Receives the current value directly, without context or child.
  /// This is intentionally simpler than [ValueListenableBuilder] to
  /// encourage cleaner code.
  ///
  /// If you need [BuildContext], wrap this widget in a [Builder]:
  ///
  /// ```dart
  /// Builder(
  ///   builder: (context) {
  ///     final theme = Theme.of(context);
  ///     return MagicBuilder<int>(
  ///       listenable: counter,
  ///       builder: (count) => Text('$count', style: theme.textTheme.bodyLarge),
  ///     );
  ///   },
  /// )
  /// ```
  final Widget Function(T value) builder;

  /// Creates a MagicBuilder widget.
  ///
  /// Both [listenable] and [builder] are required.
  const MagicBuilder({
    super.key,
    required this.listenable,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<T>(
      valueListenable: listenable,
      builder: (context, value, _) => builder(value),
    );
  }
}
