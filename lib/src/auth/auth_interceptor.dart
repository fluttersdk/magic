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

  @override
  dynamic onResponse(MagicResponse response) => response;

  /// Judge a 401 on the credential the refused request actually presented.
  ///
  /// A 401 only speaks about the guard's token when the request carried it.
  /// A request dispatched BEFORE a sign-in completed goes out with no auth
  /// header at all, and its refusal arrives after the session exists: read as
  /// a rejection, it ends a session the server never saw. Measured in a
  /// browser against a consumer app, where an unauthenticated call made during
  /// bootstrap logged out the guest session that had just been opened. Such a
  /// request is left refused rather than replayed, because it may have been
  /// anonymous on purpose: a failed sign-in answers 401 too.
  ///
  /// A request that carried an OLDER token is the same race with a credential
  /// in it, so against a [BaseGuard] the presented value has to be the one
  /// [onRequest] would write now. When it is not and the guard holds a newer
  /// token, the request raced a sign-in or a rotation, and the only answer
  /// that says anything about the session as it stands is the one the server
  /// gives the newer token: the request is replayed once with it, with no
  /// refresh and no logout, and the replay's own 401 is then judged here like
  /// any other. A guard that keeps no token of its own can only be judged on
  /// whether one was presented at all.
  ///
  /// This is the sibling of the rule [BaseGuard] already applies to a
  /// transport failure: only the server may end a session, and only about a
  /// credential it was actually shown.
  @override
  dynamic onError(MagicError error) async {
    if (!error.isUnauthorized) return error;

    final request = error.request;
    final presented = _presentedCredential(request);
    if (request == null || presented == null) return error;

    if (Auth.guard() is BaseGuard) {
      final current = _currentCredential;
      if (current == null) return error;

      if (presented != current) {
        Log.info('Auth: Request raced a token change, replaying it');

        return await _retryRequest(_withCredential(request, current)) ?? error;
      }
    }

    return _refreshOrLogout(error, request);
  }

  /// Run the refresh-or-logout ladder for a 401 on the current credential.
  Future<dynamic> _refreshOrLogout(
    MagicError error,
    MagicRequest request,
  ) async {
    if (_isRefreshing) return error;

    _isRefreshing = true;

    try {
      final refreshed = await Auth.guard().refreshToken();

      if (!refreshed) {
        Log.warning('Auth: Token refresh failed, logging out');
        await Auth.logout();

        return error;
      }

      Log.info('Auth: Token refreshed, retrying request');

      final current = Auth.guard() is BaseGuard ? _currentCredential : null;
      if (current == null) return error;

      return await _retryRequest(_withCredential(request, current)) ?? error;
    } catch (e) {
      Log.error('Auth: Error during token refresh: $e');

      return error;
    } finally {
      _isRefreshing = false;
    }
  }

  /// The credential [request] presented, or null when it carried none.
  ///
  /// The lookup ignores case because header names do, and because Dio keeps
  /// the casing of a key's first insertion: a caller that passed
  /// `authorization` still owns that key after [onRequest] writes into it.
  String? _presentedCredential(MagicRequest? request) {
    if (request == null) return null;

    final header = _header.toLowerCase();
    final presented = request.headers.entries
        .where((entry) => entry.key.toLowerCase() == header)
        .map((entry) => entry.value?.toString() ?? '')
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');

    return presented.isEmpty ? null : presented;
  }

  /// The credential [onRequest] would attach now, or null when the guard
  /// holds no token. Only meaningful against a [BaseGuard].
  String? get _currentCredential {
    final token = (Auth.guard() as BaseGuard).cachedToken;

    return token == null || token.isEmpty ? null : '$_prefix $token';
  }

  /// [request] with [credential] as its only auth header.
  ///
  /// The refused request's map is a plain, case-sensitive copy of Dio's, so a
  /// key the caller spelled differently would survive beside the one written
  /// here and carry the refused token as well.
  MagicRequest _withCredential(MagicRequest request, String credential) {
    final header = _header.toLowerCase();
    request.headers
      ..removeWhere((key, _) => key.toLowerCase() == header)
      ..[_header] = credential;

    return request;
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
