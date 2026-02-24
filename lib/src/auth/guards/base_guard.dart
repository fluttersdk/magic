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
///     await storeToken(data['token']);
///     await cacheUser(user);
///     setUser(user);
///   }
/// }
/// ```
abstract class BaseGuard implements Guard {
  Authenticatable? _user;
  String? _cachedToken;

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
  Future<void> storeToken(String token, [String? refreshToken]) async {
    await Vault.put(tokenKey, token);
    _cachedToken = token;

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
  Future<void> clearTokens() async {
    await Vault.delete(tokenKey);
    _cachedToken = null;
    if (refreshTokenKey != null) {
      await Vault.delete(refreshTokenKey!);
    }
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
      final response = await Http.post(refreshEndpoint!, data: {
        'refresh_token': refreshTokenValue,
      });

      if (!response.successful) {
        Log.warning('Auth: Token refresh failed');
        return false;
      }

      // Extract new tokens from response
      final data = response.data;
      final newToken = data?['token'] ??
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

  @override
  Future<void> logout() async {
    await clearTokens();
    await clearUserCache();
    _user = null;
    stateNotifier.value++;
  }

  @override
  Future<void> restore() async {
    await loadTokenToCache();

    if (cachedToken == null) {
      Log.debug('Auth: No token found');
      return;
    }

    // 1. Load from cache first (instant)
    final cachedUser = await loadCachedUser();
    if (cachedUser != null) {
      setUser(cachedUser);
    }

    // 2. Sync from API (fresh data)
    await _syncUserFromApi();
  }

  /// Sync user data from API.
  Future<void> _syncUserFromApi() async {
    if (userEndpoint == null || userFactory == null) return;

    try {
      final response = await Http.get(userEndpoint!);

      if (!response.successful) {
        Log.warning('Auth: Token invalid, logging out');
        await logout();
        return;
      }

      final userData = extractUserData(response.data);
      if (userData != null) {
        final user = userFactory!(userData);
        setUser(user);
        await cacheUser(user);
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
