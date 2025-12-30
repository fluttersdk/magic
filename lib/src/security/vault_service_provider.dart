import '../support/service_provider.dart';
import 'magic_vault_service.dart';

class VaultServiceProvider extends ServiceProvider {
  VaultServiceProvider(super.app);

  @override
  void register() {
    app.singleton('vault', () => MagicVaultService());
  }

  @override
  Future<void> boot() async {
    // No async boot required for FlutterSecureStorage
  }
}
