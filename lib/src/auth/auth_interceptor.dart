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

  @override
  dynamic onRequest(MagicRequest request) {
    final guard = Auth.guard();

    if (guard is BaseGuard) {
      final token = guard.cachedToken;
      if (token != null && token.isNotEmpty) {
        final authConfig = Config.get<Map<String, dynamic>>('auth', {});
        final tokenConfig = authConfig?['token'] as Map<String, dynamic>?;
        final header = tokenConfig?['header'] as String? ?? 'Authorization';
        final prefix = tokenConfig?['prefix'] as String? ?? 'Bearer';

        request.headers[header] = '$prefix $token';
      }
    }

    return request;
  }

  @override
  dynamic onResponse(MagicResponse response) => response;

  @override
  dynamic onError(MagicError error) async {
    // Handle 401 Unauthorized
    if (error.isUnauthorized && !_isRefreshing) {
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
                final authConfig = Config.get<Map<String, dynamic>>('auth', {});
                final tokenConfig =
                    authConfig?['token'] as Map<String, dynamic>?;
                final header =
                    tokenConfig?['header'] as String? ?? 'Authorization';
                final prefix = tokenConfig?['prefix'] as String? ?? 'Bearer';

                originalRequest.headers[header] = '$prefix $token';

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
          return await Http.get(request.url,
              query: request.queryParameters,
              headers: _stringHeaders(request.headers));
        case 'POST':
          return await Http.post(request.url,
              data: request.data, headers: _stringHeaders(request.headers));
        case 'PUT':
          return await Http.put(request.url,
              data: request.data, headers: _stringHeaders(request.headers));
        case 'DELETE':
          return await Http.delete(request.url,
              headers: _stringHeaders(request.headers));
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
