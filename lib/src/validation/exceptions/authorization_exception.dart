/// Thrown when a [FormRequest.authorize] check (or a controller `authorize()`
/// call) denies the current actor.
///
/// Apps typically catch this at the controller boundary and surface either a
/// 403 page or a toast. The optional [message] lets you give the user a hint
/// when the default "Unauthorized." feels too terse.
class AuthorizationException implements Exception {
  const AuthorizationException([this.message = 'Unauthorized.']);

  final String message;

  @override
  String toString() => 'AuthorizationException: $message';
}
