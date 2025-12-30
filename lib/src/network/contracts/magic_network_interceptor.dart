import '../magic_response.dart';

/// The Magic Network Interceptor contract.
///
/// Driver-agnostic interceptor for modifying requests, responses, and errors.
/// Each driver translates to/from these types.
///
/// ```dart
/// class LoggingInterceptor extends MagicNetworkInterceptor {
///   @override
///   MagicRequest onRequest(MagicRequest request) {
///     print('Request: ${request.method} ${request.url}');
///     return request;
///   }
///
///   @override
///   MagicResponse onResponse(MagicResponse response) {
///     print('Response: ${response.statusCode}');
///     return response;
///   }
/// }
/// ```
abstract class MagicNetworkInterceptor {
  /// Called before each request is sent.
  ///
  /// Modify headers, data, etc. and return the request.
  dynamic onRequest(MagicRequest request) => request;

  /// Called after a successful response is received.
  dynamic onResponse(MagicResponse response) => response;

  /// Called when an error occurs.
  ///
  /// Can return:
  /// - `MagicError` to continue with error
  /// - `MagicResponse` to resolve as success (e.g., after retry)
  dynamic onError(MagicError error) => error;
}
