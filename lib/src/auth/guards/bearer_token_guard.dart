import '../../facades/log.dart';
import '../authenticatable.dart';
import 'base_guard.dart';

/// Bearer Token Guard.
///
/// Token-based authentication (most common for APIs).
///
/// ```dart
/// final response = await Http.post('/login', data: credentials);
/// final user = User.fromMap(response['data']['user']);
/// await Auth.login({
///   'token': response['data']['token'],
///   'refresh_token': response['data']['refresh_token'], // optional
/// }, user);
/// ```
class BearerTokenGuard extends BaseGuard {
  BearerTokenGuard({
    super.tokenKey,
    super.refreshTokenKey,
    super.userEndpoint = '/api/user',
    super.userFactory,
  });

  @override
  Future<void> login(Map<String, dynamic> data, Authenticatable user) async {
    final token = data['token'] as String?;
    final refreshToken = data['refresh_token'] as String?;

    if (token != null) {
      await storeToken(token, refreshToken);
    }
    setUser(user);
    await cacheUser(user);
    Log.info('Auth: User logged in');
  }
}
