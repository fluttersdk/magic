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
  /// The response that refused the write, or null when there was none: an ORM
  /// write whose caller did not pass the model's `lastRemoteResponse`, a
  /// driver that threw instead of answering, or a message that came from
  /// elsewhere (see [ActionRequestFailed.withMessage]).
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

  /// Whether the client got no readable answer: the driver reports status 0
  /// for a connection that failed or dropped, a timeout, a cross-origin error
  /// page the browser would not expose, and a 2xx whose body could not be
  /// decoded. False when there is no response at all, which is unknown rather
  /// than proof of either.
  ///
  /// Worth its own branch in a caller, because the right copy differs: nothing
  /// judged the input, so "check the form" is a wrong diagnosis. The write may
  /// or may not have landed, so "try again" is right for a read or an
  /// idempotent write and worth a refresh first for a create.
  bool get isTransportFailure => response?.statusCode == 0;

  /// The backend's own message (a JSON body's non-blank `message`), or null
  /// when it sent none. A message given through
  /// [ActionRequestFailed.withMessage] wins.
  ///
  /// Only the body is read, never [MagicResponse.message]: the driver writes
  /// its own diagnosis there for a status 0 ("The connection errored: ...")
  /// and for a non-JSON error page (a multi-line paragraph about
  /// `validateStatus`), and neither is the backend's word or written for the
  /// person reading a toast. [toString] still carries it for the log line.
  String? get message {
    if (_messageOverride != null) return _messageOverride;

    final Object? data = response?.data;
    if (data is! Map<String, dynamic>) return null;

    // A blank message is no message: `abort(404)` answers `{"message": ""}`,
    // and an empty string would win over a caller's `?? its own copy`.
    final Object? message = data['message'];

    return message is String && message.trim().isNotEmpty ? message : null;
  }

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
  /// (pass the model's `lastRemoteResponse` as [response], since `save()`
  /// consumes its own) or off `MagicResponse.errors` for a raw `Http` write.
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

  /// The log line, which keeps the driver's own diagnosis that [message]
  /// withholds from a toast: a status 0 merges connection errors, timeouts and
  /// decode failures, and that text is what tells them apart.
  @override
  String toString() =>
      'ActionRequestFailed($action: ${statusCode ?? 'no response'} '
      '${_messageOverride ?? response?.errorMessage ?? ''})';
}
