import '../database/eloquent/model.dart';
import '../network/magic_response.dart';
import 'authenticatable.dart';

/// Authentication Result.
///
/// A simple result object for authentication operations.
/// Useful when you want to return structured data from auth methods.
///
/// ## Usage
///
/// ```dart
/// // In your controller
/// AuthResult doLogin(...) {
///   final response = await Http.post('/login', data: ...);
///   if (response.successful) {
///     final user = User.fromMap(response['data']['user']);
///     await Auth.login({'token': response['data']['token']}, user);
///     return AuthResult.success(user: user, token: response['data']['token']);
///   }
///   return AuthResult.failure(message: response.errorMessage);
/// }
/// ```
class AuthResult {
  /// The underlying HTTP response (if available).
  final MagicResponse? response;

  /// Whether the authentication was successful.
  final bool success;

  /// The authenticated user (if successful).
  final Authenticatable? authenticatable;

  /// The access token (if successful).
  final String? token;

  /// A message (success or error).
  final String? message;

  /// Validation errors keyed by field name.
  final Map<String, List<String>> errors;

  const AuthResult._({
    this.response,
    required this.success,
    this.authenticatable,
    this.token,
    this.message,
    this.errors = const {},
  });

  /// Whether the authentication failed.
  bool get failed => !success;

  /// Get the authenticated user cast to your model type.
  T? user<T extends Model>() => authenticatable as T?;

  /// Get the first error for a specific field.
  String? firstError(String field) => errors[field]?.firstOrNull;

  /// Create a successful result.
  factory AuthResult.success({
    required Authenticatable user,
    String? token,
    String? message,
    MagicResponse? response,
  }) {
    return AuthResult._(
      response: response,
      success: true,
      authenticatable: user,
      token: token,
      message: message,
    );
  }

  /// Create a failed result.
  factory AuthResult.failure({
    String? message,
    Map<String, List<String>>? errors,
    MagicResponse? response,
  }) {
    return AuthResult._(
      response: response,
      success: false,
      message: message,
      errors: errors ?? const {},
    );
  }

  /// Create a result from an HTTP response.
  ///
  /// Useful helper to construct based on response status.
  factory AuthResult.fromResponse(
    MagicResponse response, {
    Authenticatable? user,
    String? token,
  }) {
    if (response.successful) {
      return AuthResult._(
        response: response,
        success: true,
        authenticatable: user,
        token: token,
      );
    }
    return AuthResult._(
      response: response,
      success: false,
      message: response.errorMessage,
      errors: response.errors,
    );
  }

  @override
  String toString() {
    if (success) {
      return 'AuthResult.success(user: $authenticatable)';
    }
    return 'AuthResult.failure(message: $message)';
  }
}
