import 'dart:convert';

import '../../facades/log.dart';
import '../authenticatable.dart';
import 'base_guard.dart';

/// Basic Auth Guard.
///
/// HTTP Basic Authentication.
///
/// ```dart
/// await Auth.login({'username': 'user', 'password': 'secret'}, user);
/// ```
class BasicAuthGuard extends BaseGuard {
  BasicAuthGuard({
    super.tokenKey = 'basic_auth_credentials',
    super.userEndpoint,
    super.userFactory,
  });

  @override
  Future<void> login(Map<String, dynamic> data, Authenticatable user) async {
    final username = data['username'] as String?;
    final password = data['password'] as String?;

    if (username != null && password != null) {
      final credentials = base64Encode(utf8.encode('$username:$password'));
      await storeToken(credentials);
    }
    setUser(user);
    await cacheUser(user);
    Log.info('Auth: Basic auth login');
  }
}
