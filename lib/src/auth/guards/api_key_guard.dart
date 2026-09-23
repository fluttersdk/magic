import '../../facades/log.dart';
import '../authenticatable.dart';
import 'base_guard.dart';

/// API Key Guard.
///
/// Static API key authentication.
///
/// ```dart
/// await Auth.login({'api_key': 'sk_live_xxx'}, user);
/// ```
class ApiKeyGuard extends BaseGuard {
  ApiKeyGuard({
    super.tokenKey = 'api_key',
    super.userEndpoint,
    super.userFactory,
  });

  @override
  Future<void> login(Map<String, dynamic> data, Authenticatable user) async {
    await startSession(user, token: data['api_key'] as String?);
    Log.info('Auth: API key login');
  }
}
