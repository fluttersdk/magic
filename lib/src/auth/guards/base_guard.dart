import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../database/eloquent/model.dart';
import '../../facades/event.dart';
import '../../facades/http.dart';
import '../../facades/log.dart';
import '../../facades/vault.dart';
import '../authenticatable.dart';
import '../contracts/guard.dart';
import '../events/auth_events.dart';

/// Base Guard.
///
/// Provides common functionality for all guards:
/// - User state and caching
/// - Token management (with optional refresh token)
/// - Session restoration with cache-first strategy
///
/// ## Cache Strategy
///
/// On restore:
/// 1. Load user from cache (instant)
/// 2. Sync from API in background (fresh data)
///
/// ## Extending
///
/// ```dart
/// class MyGuard extends BaseGuard {
///   MyGuard() : super(
///     userEndpoint: '/api/me',
///     userFactory: (data) => User.fromMap(data),
///   );
///
///   @override
///   Future<void> login(Map<String, dynamic> data, Authenticatable user) async {
///     await startSession(user, token: data['token'] as String?);
///   }
/// }
/// ```
abstract class BaseGuard implements Guard {
  Authenticatable? _user;
  String? _cachedToken;

  /// Moves, synchronously and before any await, whenever a session opens
  /// ([startSession]) or ends ([logout]). An in-flight boot sync compares it
  /// against the value it captured, which [stateNotifier] cannot do alone: it
  /// bumps only once the user is set or cleared, after the Vault awaits.
  int _sessionEpoch = 0;

  /// Auth state notifier.
  ///
  /// Bumped on every auth state change (setUser, logout, restore).
  /// Allows UI to reactively rebuild when auth state transitions.
  @override
  final ValueNotifier<int> stateNotifier = ValueNotifier<int>(0);

  /// Vault keys.
  final String tokenKey;
  final String? refreshTokenKey;
  final String userCacheKey;

  /// API endpoint to fetch user data.
  final String? userEndpoint;

  /// API endpoint to refresh access token.
  final String? refreshEndpoint;

  /// Factory to create user from API response.
  final Authenticatable Function(Map<String, dynamic>)? userFactory;

  BaseGuard({
    this.tokenKey = 'auth_token',
    this.refreshTokenKey,
    this.userCacheKey = 'auth_user',
    this.userEndpoint,
    this.refreshEndpoint,
    this.userFactory,
  });

  // ---------------------------------------------------------------------------
  // User State
  // ---------------------------------------------------------------------------

  @override
  bool check() => _user != null;

  @override
  bool get guest => !check();

  @override
  T? user<T extends Model>() => _user as T?;

  @override
  dynamic id() => _user?.authIdentifier;

  @override
  @override
  void setUser(Authenticatable user) {
    _user = user;
    stateNotifier.value++;
  }

  // ---------------------------------------------------------------------------
  // Token Management
  // ---------------------------------------------------------------------------

  @override
  Future<bool> hasToken() async {
    final token = await Vault.get(tokenKey);
    return token != null && token.isNotEmpty;
  }

  @override
  Future<String?> getToken() => Vault.get(tokenKey);

  /// Cached token for sync access.
  String? get cachedToken => _cachedToken;

  /// Store token (and optional refresh token).
  ///
  /// The in-memory token moves BEFORE the Vault writes, not after them. A
  /// boot sync still in the air judges a 401 by whether the token it was sent
  /// with is still the one held, and with the writes first a 401 about the
  /// old token landing between them read as a verdict on the current session:
  /// its logout deleted the token just written. A sign-in goes through
  /// [startSession] instead, which also marks the session as changed.
  Future<void> storeToken(String token, [String? refreshToken]) =>
      _holdThenPersist(token, refreshToken);

  /// Open a session: mark it opened and move the in-memory token, persist
  /// [token] (when given) and its [refreshToken], then set [user] and cache it.
  ///
  /// Everything an in-flight boot sync reads moves before the first await.
  /// The sync ignores its answer once [_sessionEpoch] has moved, so neither of
  /// the two windows a sign-in used to open is reachable: with the user set a
  /// few awaits after the token, a late 200 applied the PREVIOUS account
  /// against the NEW token (0.0.17), and with the Vault writes ahead of the
  /// in-memory token, a late 401 logged out and deleted the token the sign-in
  /// had just written (0.0.18). Use this from [login] rather than
  /// [storeToken] followed by [setUser].
  @protected
  Future<void> startSession(
    Authenticatable user, {
    String? token,
    String? refreshToken,
  }) async {
    _sessionEpoch++;

    if (token != null) await _holdThenPersist(token, refreshToken);
    setUser(user);

    await cacheUser(user);
  }

  /// Move the in-memory token to [token], then persist it and [refreshToken].
  ///
  /// When a Vault write throws ([MagicVaultException] on a locked keychain or
  /// a missing entitlement), the in-memory token goes back to what it was, as
  /// long as nothing moved it since, and the failure propagates. A token that
  /// was never stored must not ride on later requests: a guest would carry a
  /// failed sign-in's bearer, and on an account switch the screen would show
  /// one account while the requests carried the other.
  Future<void> _holdThenPersist(String token, String? refreshToken) async {
    final previous = _cachedToken;
    _cachedToken = token;

    try {
      await _persistTokens(token, refreshToken);
    } catch (_) {
      if (_cachedToken == token) _cachedToken = previous;

      rethrow;
    }
  }

  Future<void> _persistTokens(String token, String? refreshToken) async {
    await Vault.put(tokenKey, token);

    if (refreshToken != null && refreshTokenKey != null) {
      await Vault.put(refreshTokenKey!, refreshToken);
    }
  }

  /// Get refresh token.
  Future<String?> getRefreshToken() async {
    if (refreshTokenKey == null) return null;
    return Vault.get(refreshTokenKey!);
  }

  /// Load token into cache.
  Future<void> loadTokenToCache() async {
    _cachedToken = await Vault.get(tokenKey);
  }

  /// Clear all tokens.
  ///
  /// Both deletes are attempted even when the first one fails, and the first
  /// failure is rethrown once both have been tried. A vault delete throws
  /// [MagicVaultException] on a platform error (a locked keychain, a lost
  /// entitlement), and stopping at the first would leave the refresh token
  /// behind, which is a live session on the next launch.
  Future<void> clearTokens() async {
    Object? failure;
    StackTrace? failureStack;

    try {
      await Vault.delete(tokenKey);
    } catch (e, stack) {
      failure = e;
      failureStack = stack;
    }
    _cachedToken = null;

    if (refreshTokenKey != null) {
      try {
        await Vault.delete(refreshTokenKey!);
      } catch (e, stack) {
        failure ??= e;
        failureStack ??= stack;
      }
    }

    if (failure != null) Error.throwWithStackTrace(failure, failureStack!);
  }

  // ---------------------------------------------------------------------------
  // User Caching
  // ---------------------------------------------------------------------------

  /// Cache user data to Vault.
  Future<void> cacheUser(Authenticatable user) async {
    try {
      final data = user.toMap();
      await Vault.put(userCacheKey, jsonEncode(data));
    } catch (e) {
      Log.warning('Auth: Failed to cache user: $e');
    }
  }

  /// Load user from cache.
  Future<Authenticatable?> loadCachedUser() async {
    if (userFactory == null) return null;

    try {
      final cached = await Vault.get(userCacheKey);
      if (cached == null || cached.isEmpty) return null;

      final data = jsonDecode(cached) as Map<String, dynamic>;
      return userFactory!(data);
    } catch (e) {
      Log.warning('Auth: Failed to load cached user: $e');
      return null;
    }
  }

  /// Clear cached user.
  Future<void> clearUserCache() async {
    await Vault.delete(userCacheKey);
  }

  // ---------------------------------------------------------------------------
  // Token Refresh
  // ---------------------------------------------------------------------------

  @override
  Future<bool> refreshToken() async {
    if (refreshEndpoint == null || refreshTokenKey == null) {
      return false;
    }

    final refreshTokenValue = await getRefreshToken();
    if (refreshTokenValue == null) {
      Log.warning('Auth: No refresh token available');
      return false;
    }

    try {
      final response = await Http.post(
        refreshEndpoint!,
        data: {'refresh_token': refreshTokenValue},
      );

      if (!response.successful) {
        Log.warning('Auth: Token refresh failed');
        return false;
      }

      // Extract new tokens from response
      final data = response.data;
      final newToken =
          data?['token'] ??
          data?['access_token'] ??
          data?['data']?['token'] ??
          data?['data']?['access_token'];
      final newRefreshToken =
          data?['refresh_token'] ?? data?['data']?['refresh_token'];

      if (newToken is String) {
        await storeToken(newToken, newRefreshToken as String?);
        Log.info('Auth: Token refreshed');
        return true;
      }

      return false;
    } catch (e) {
      Log.error('Auth: Token refresh error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Session
  // ---------------------------------------------------------------------------

  /// End the session.
  ///
  /// Every step is attempted, whatever the earlier ones did, and the first
  /// failure is rethrown at the end. Vault deletes throw on a platform error,
  /// and running these in sequence without that meant a locked keychain on the
  /// first delete left the cached user on disk, left the user in memory, and
  /// never bumped [stateNotifier], so the app went on rendering a signed-in
  /// session while the caller was told the logout had failed.
  ///
  /// The in-memory clear is last and unconditional on purpose: it is the part
  /// that cannot fail, so it is the part that must not be skipped. The throw
  /// still reaches the caller, because a logout that could not remove a
  /// credential is not a logout, and only the caller can decide what to say
  /// about it.
  ///
  /// [_sessionEpoch] moves first, before any await, so a boot sync answering
  /// while the deletes run is not applied to a session that is ending.
  @override
  Future<void> logout() async {
    _sessionEpoch++;

    Object? failure;
    StackTrace? failureStack;

    try {
      await clearTokens();
    } catch (e, stack) {
      failure = e;
      failureStack = stack;
    }

    try {
      await clearUserCache();
    } catch (e, stack) {
      failure ??= e;
      failureStack ??= stack;
    }

    _user = null;
    stateNotifier.value++;

    if (failure != null) Error.throwWithStackTrace(failure, failureStack!);
  }

  @override
  Future<void> restore() async {
    Log.debug(
      'Auth: Restoring session (tokenKey=$tokenKey, hasFactory=${userFactory != null})',
    );
    await loadTokenToCache();

    if (cachedToken == null) {
      Log.debug('Auth: No token found in storage');
      return;
    }

    Log.debug('Auth: Token loaded from storage');

    // 1. Load from cache first (instant)
    final cachedUser = await loadCachedUser();
    if (cachedUser != null) {
      setUser(cachedUser);
      Log.debug('Auth: Cached user restored');
    } else {
      Log.debug('Auth: No cached user found');
    }

    // 2. Sync from API (fresh data).
    //
    // Awaited only when the cache had nothing to show. `AuthServiceProvider`
    // awaits `restore()`, which holds `Magic.init()`, which holds `runApp`, so
    // anything awaited here is time the user spends looking at a blank window.
    // Against a backend that accepts the connection and then says nothing (a
    // captive portal, a dead mobile link) that is the whole client timeout: on
    // an app configured for 120s it measured as roughly two minutes of white
    // screen on a cold start, with the console stopping dead on the line above.
    //
    // With a cached user already set the screen can render now and correct
    // itself when the sync lands, which is what this class has documented as
    // its cache strategy from the start ("2. Sync from API in background").
    // Without one there is nothing to render and no honest way to route, so the
    // API is the only answer and waiting for it is the point.
    if (cachedUser != null) {
      unawaited(_syncUserFromApi());

      return;
    }

    await _syncUserFromApi();
  }

  /// Sync user data from API.
  ///
  /// [restore] fires this unawaited when the cache had a user, so the session
  /// can change while it is in the air, and two kinds of change need two
  /// different answers.
  ///
  /// A sign-in or a sign-out makes the answer about a session that no longer
  /// exists, so nothing of it is applied. Either is seen from its first line,
  /// through [_sessionEpoch], and a [setUser] from anywhere else through
  /// [stateNotifier]. A 401 used to run [logout], whose [clearTokens] deleted
  /// the token the sign-in had just stored, and a 200 used to put the
  /// previous account back in memory and on disk.
  ///
  /// A token rotation (a refresh, which bumps nothing) keeps the account, so
  /// a 200 is still applied: the interceptor's own refresh-and-retry of this
  /// very request lands here as a 200 under a new token, and on a cold start
  /// with no cached user that 200 is the only thing that can sign the user
  /// in. A 401 or 403 under a rotated token is about the token it replaced,
  /// so it ends nothing by itself: the sync is re-checked once under the
  /// current token ([afterRotation]), and that answer decides. Keeping the
  /// session on the first refusal alone left a viewer holding a token the
  /// server had just refused, when the interceptor's own refresh-and-retry of
  /// this request was the thing refused.
  Future<void> _syncUserFromApi({bool afterRotation = false}) async {
    if (userEndpoint == null || userFactory == null) {
      Log.debug(
        'Auth: Skipping API sync '
        '(endpoint=${userEndpoint ?? 'null'}, hasFactory=${userFactory != null})',
      );
      return;
    }

    final sentToken = cachedToken;
    final sentSession = stateNotifier.value;
    final sentEpoch = _sessionEpoch;

    try {
      final response = await Http.get(userEndpoint!);

      if (_sessionEpoch != sentEpoch || stateNotifier.value != sentSession) {
        Log.debug(
          'Auth: user sync answered for a session that has since changed; '
          'ignoring it',
        );

        return;
      }

      if (!response.successful) {
        // Only the server may end a session. A transport failure (a timeout, a
        // DNS miss, a dead mobile link) reaches here as statusCode 0, because
        // `DioNetworkDriver._handleError` has no response to report: that is
        // "nobody answered", not "your token is bad". Logging out on it threw
        // away a valid session because the phone went through a tunnel, and
        // said "Token invalid" about a server that never spoke.
        if (response.statusCode == 401 || response.statusCode == 403) {
          if (cachedToken != sentToken && !afterRotation) {
            Log.debug(
              'Auth: user sync refused a token the guard has since replaced; '
              're-checking under the current one',
            );

            return await _syncUserFromApi(afterRotation: true);
          }

          Log.warning('Auth: Token rejected by the server, logging out');
          await logout();

          return;
        }

        Log.warning(
          'Auth: user sync failed (status ${response.statusCode}); '
          'keeping the cached session',
        );

        return;
      }

      final userData = extractUserData(response.data);
      if (userData != null) {
        final user = userFactory!(userData);
        setUser(user);
        await cacheUser(user);

        // The cache write is an await, and a sign-in or sign-out can begin
        // inside it. Neither should hear `AuthRestored` for the session this
        // answer was about, and a sign-out that cleared the cache before this
        // write landed would find the user back on disk.
        if (_sessionEpoch != sentEpoch) {
          if (cachedToken == null) await clearUserCache();

          return;
        }

        Log.info('Auth: User synced from API');

        // Dispatch updated event
        await Event.dispatch(AuthRestored(user));
      }
    } catch (e) {
      Log.error('Auth: Sync failed: $e');
      // Keep cached user if sync fails
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Extract user data from API response.
  ///
  /// Supports common Laravel response formats:
  /// - `{ "data": { "user": {...} } }`
  /// - `{ "data": {...} }`
  /// - `{ "user": {...} }`
  /// - `{ "id": ... }` (root level)
  Map<String, dynamic>? extractUserData(Map<String, dynamic>? data) {
    if (data == null) return null;

    // Try: data.user
    if (data['data'] is Map && data['data']['user'] is Map) {
      return data['data']['user'] as Map<String, dynamic>;
    }
    // Try: data (with id)
    if (data['data'] is Map && data['data']['id'] != null) {
      return data['data'] as Map<String, dynamic>;
    }
    // Try: user
    if (data['user'] is Map) {
      return data['user'] as Map<String, dynamic>;
    }
    // Try: root level
    if (data['id'] != null) {
      return data;
    }
    return null;
  }
}
