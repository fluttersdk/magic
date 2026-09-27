import 'package:magic/src/network/magic_response.dart';
import 'package:magic/src/support/cast.dart';
import 'package:magic/src/validation/exceptions/validation_exception.dart';

/// Why a `MagicAction` refused to report success: the backend answered
/// non-2xx, or an ORM write answered `false` without the field errors a 422
/// carries.
///
/// A distinct type rather than a bare [Exception] because [RunsActions.runAction]
/// (and any controller catching a refusal directly) needs a single shape every
/// resource action can throw, whichever endpoint or ORM call answered it.
///
/// Named apart from magic's `ActionFailed`, the `ActionOutcome` case that
/// carries one of these (or a [ValidationException]) as its `error`.
class ActionRequestFailed implements Exception {
  /// The response that refused the write, or null when there was none: the
  /// ORM consumed it internally (a `save()` or `delete()` that answered
  /// `false`), or the message came from elsewhere (see
  /// [ActionRequestFailed.withMessage]).
  final MagicResponse? response;

  /// What was attempted, for the log line.
  final String action;

  /// The message a refusal with no response to read carries directly.
  final String? _messageOverride;

  /// Creates an [ActionRequestFailed] for [action] from a refusing [response].
  const ActionRequestFailed(this.action, [this.response])
    : _messageOverride = null;

  /// Creates an [ActionRequestFailed] for [action] carrying [message]
  /// directly, for a refusal with no [MagicResponse] to read (a `save()` that
  /// consumed its own response and answered `false`, whose field errors a
  /// vertical with no error slot still wants to say).
  const ActionRequestFailed.withMessage(this.action, String? message)
    : response = null,
      _messageOverride = message;

  /// The refusing response's status code, or null when there was none.
  int? get statusCode => response?.statusCode;

  /// The backend's own message, or null when it sent none. A message given
  /// through [ActionRequestFailed.withMessage] wins.
  String? get message => _messageOverride ?? response?.errorMessage;

  /// Seconds until a refused request may run again, read from a 429 body's
  /// `retry_after_seconds` (the manual-check cooldown), or 1 when the body
  /// carries no usable value, so a button waiting on it still recovers rather
  /// than staying disabled forever.
  int get retryAfterSeconds {
    final Object? data = response?.data;
    if (data is! Map<String, dynamic>) return 1;

    return Cast.intOr(data['retry_after_seconds'], 1);
  }

  /// The exception a refused write stands for: a [ValidationException] holding
  /// the first message per field when [errors] carries any (a 422), otherwise
  /// an [ActionRequestFailed] for [action] carrying [response].
  ///
  /// [errors] is the raw wire map, read off an ORM write's own error-tracking
  /// (whose `save()` consumes its own response, so [response] stays null) or
  /// off `MagicResponse.errors` for a raw `Http` write.
  static Exception refusalOf(
    String action,
    Map<String, List<String>> errors, [
    MagicResponse? response,
  ]) {
    if (errors.isEmpty) return ActionRequestFailed(action, response);

    return ValidationException(<String, String>{
      for (final MapEntry<String, List<String>> entry in errors.entries)
        if (entry.value.isNotEmpty) entry.key: entry.value.first,
    });
  }

  @override
  String toString() =>
      'ActionRequestFailed($action: ${statusCode ?? 'no response'} '
      '${message ?? ''})';
}
