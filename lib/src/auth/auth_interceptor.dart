import 'package:dio/dio.dart' show FormData;

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
  /// bootstrap logged out the guest session that had just been opened.
  ///
  /// A request that carried an OLDER token is the same race with a credential
  /// in it, so against a [BaseGuard] the presented value has to be the one
  /// [onRequest] would write now. Such a request is handed back refused and
  /// NOT replayed with the newer token: from here a rotation and a different
  /// account signing in look identical, and a replay would answer a screen
  /// still rendering one account with another account's data. The caller that
  /// asked is the one that knows whether its question still stands. A guard
  /// that keeps no token of its own can only be judged on whether one was
  /// presented at all.
  ///
  /// This is the sibling of the rule [BaseGuard] already applies to a
  /// transport failure: only the server may end a session, and only about a
  /// credential it was actually shown.
  @override
  dynamic onError(MagicError error) async {
    if (!error.isUnauthorized) return error;

    final request = error.request;
    if (request == null || _presentedCredential(request) == null) return error;

    if (Auth.guard() is BaseGuard &&
        _presentedCredential(request) != _currentCredential) {
      return error;
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

  /// A copy of [request] carrying [credential] as its only auth header.
  ///
  /// A copy, so the refused request handed back when the retry yields nothing
  /// still shows the header it was actually sent with. The refused request's
  /// map is a plain, case-sensitive copy of Dio's, so a key the caller spelled
  /// differently has to go too, or it would carry the refused token beside
  /// the fresh one. A [FormData] body is single use (Dio throws on a second
  /// `finalize()`), so an upload's body is cloned rather than re-sent.
  MagicRequest _withCredential(MagicRequest request, String credential) {
    final header = _header.toLowerCase();
    final data = request.data;

    return MagicRequest(
      url: request.url,
      method: request.method,
      headers: {
        for (final entry in request.headers.entries)
          if (entry.key.toLowerCase() != header) entry.key: entry.value,
        _header: credential,
      },
      data: data is FormData ? data.clone() : data,
      queryParameters: request.queryParameters,
    );
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
