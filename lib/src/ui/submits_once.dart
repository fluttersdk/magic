import 'package:flutter/widgets.dart';

/// Guards a form's submit against a second tap while the first write is in
/// flight.
///
/// ## Why this exists
///
/// A submit handler is `async`, and wiring it straight to a button
/// (`onPressed: _onSubmit`) leaves nothing disabling the button for the
/// duration of the await, so a double tap fires the write twice. On a create
/// path that is not idempotent: two taps create two records instead of one,
/// each counting against whatever limit or downstream side effect the create
/// carries. On an edit path it is the same write twice, which is harmless but
/// still a request nobody asked for.
///
/// A double tap is not a hypothetical on web, where it costs nothing.
///
/// This is a mixin rather than a flag invented once per form, because the
/// second and third form that need it would otherwise have forgotten it.
///
/// ## Usage
///
/// Mix onto the form's [State], route the handler through [submitOnce], and feed
/// [isSubmitting] to the button's `isLoading`. That last part is what actually
/// blocks the tap: a well-behaved button computes
/// `isInteractive = !isLoading && !disabled` and passes `null` for `onTap`
/// when it is false, so the spinner and the guard are the same switch.
///
/// ```dart
/// MSButton(
///   isLoading: isSubmitting,
///   onPressed: () => submitOnce(_onSubmit),
///   child: WText(trans('...')),
/// )
/// ```
mixin SubmitsOnce<W extends StatefulWidget> on State<W> {
  bool _submitting = false;

  /// Whether a submit is currently in flight.
  bool get isSubmitting => _submitting;

  /// Runs [body] unless a submit is already in flight, in which case the call is
  /// dropped.
  ///
  /// The reset runs in a `finally` so a throwing submit re-arms the button
  /// instead of leaving it spinning forever, and it is deliberately NOT a
  /// `catch`: swallowing the error here would hide a failure the handler's own
  /// error path is responsible for surfacing. The [mounted] check matters
  /// because a successful submit usually navigates away, so this state is often
  /// gone by the time [body] returns.
  Future<void> submitOnce(Future<void> Function() body) async {
    if (_submitting) return;

    setState(() => _submitting = true);
    try {
      await body();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
