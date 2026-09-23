import '../network/magic_response.dart';
import '../network/contracts/magic_network_interceptor.dart';
import '../facades/auth.dart';
import '../facades/config.dart';
import '../facades/http.dart';
import '../facades/log.dart';
import 'guards/base_guard.dart';

/// Auth Interceptor.
///
/// - Attaches auth headers to requests
/// - Handles 401 responses with automatic token refresh
class AuthInterceptor extends MagicNetworkInterceptor {
  bool _isRefreshing = false;

  /// The header carrying the token, as `auth.token.header` names it.
  String get _header {
    final authConfig = Config.get<Map<String, dynamic>>('auth', {});
    final tokenConfig = authConfig?['token'] as Map<String, dynamic>?;

    return tokenConfig?['header'] as String? ?? 'Authorization';
  }

  /// The scheme written before the token, as `auth.token.prefix` names it.
  String get _prefix {
    final authConfig = Config.get<Map<String, dynamic>>('auth', {});
    final tokenConfig = authConfig?['token'] as Map<String, dynamic>?;

    return tokenConfig?['prefix'] as String? ?? 'Bearer';
  }

  @override
  dynamic onRequest(MagicRequest request) {
    final guard = Auth.guard();

    if (guard is BaseGuard) {
      final token = guard.cachedToken;
      if (token != null && token.isNotEmpty) {
        request.headers[_header] = '$_prefix $token';
      }
    }

    return request;
  }

  /// Whether the refused request actually presented a credential.
  ///
  /// A 401 only speaks about the guard's token when the request carried it.
  /// A request dispatched BEFORE a sign-in completed goes out with no auth
  /// header at all, and its refusal arrives after the session exists: read as
  /// a rejection, it ends a session the server never saw. Measured in a
  /// browser against a consumer app, where an unauthenticated call made during
  /// bootstrap logged out the guest session that had just been opened.
  ///
  /// The lookup ignores case because header names do, and because Dio keeps
  /// the casing of a key's first insertion: a caller that passed
  /// `authorization` still owns that key after [onRequest] writes into it.
  ///
  /// This is the sibling of the rule [BaseGuard] already applies to a
  /// transport failure: only the server may end a session, and only about a
  /// credential it was actually shown.
  bool _presentedCredential(MagicRequest? request) {
    if (request == null) return false;

    final header = _header.toLowerCase();

    return request.headers.entries.any(
      (entry) =>
          entry.key.toLowerCase() == header &&
          (entry.value?.toString() ?? '').isNotEmpty,
    );
  }

  @override
  dynamic onResponse(MagicResponse response) => response;

  @override
  dynamic onError(MagicError error) async {
    // Handle 401 Unauthorized, but only for a request that presented the
    // token: one that carried none was never judged by the server.
    if (error.isUnauthorized &&
        !_isRefreshing &&
        _presentedCredential(error.request)) {
      _isRefreshing = true;

      try {
        final refreshed = await Auth.guard().refreshToken();

        if (refreshed) {
          Log.info('Auth: Token refreshed, retrying request');

          // Retry original request
          final originalRequest = error.request;
          if (originalRequest != null) {
            // Update header with new token
            final guard = Auth.guard();
            if (guard is BaseGuard) {
              final token = guard.cachedToken;
              if (token != null) {
                originalRequest.headers[_header] = '$_prefix $token';

                // Retry via Http facade
                final response = await _retryRequest(originalRequest);
                if (response != null) {
                  return response;
                }
              }
            }
          }
        } else {
          Log.warning('Auth: Token refresh failed, logging out');
          await Auth.logout();
        }
      } catch (e) {
        Log.error('Auth: Error during token refresh: $e');
      } finally {
        _isRefreshing = false;
      }
    }

    return error;
  }

  /// Retry the original request.
  Future<MagicResponse?> _retryRequest(MagicRequest request) async {
    try {
      switch (request.method.toUpperCase()) {
        case 'GET':
          return await Http.get(
            request.url,
            query: request.queryParameters,
            headers: _stringHeaders(request.headers),
          );
        case 'POST':
          return await Http.post(
            request.url,
            data: request.data,
            headers: _stringHeaders(request.headers),
          );
        case 'PUT':
          return await Http.put(
            request.url,
            data: request.data,
            headers: _stringHeaders(request.headers),
          );
        case 'DELETE':
          return await Http.delete(
            request.url,
            headers: _stringHeaders(request.headers),
          );
        default:
          return null;
      }
    } catch (e) {
      Log.error('Auth: Retry failed: $e');
      return null;
    }
  }

  Map<String, String>? _stringHeaders(Map<String, dynamic> headers) {
    if (headers.isEmpty) return null;
    return headers.map((k, v) => MapEntry(k, v.toString()));
  }
}
