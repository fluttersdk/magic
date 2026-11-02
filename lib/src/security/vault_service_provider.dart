import '../facades/config.dart';
import '../support/service_provider.dart';
import 'magic_vault_service.dart';

class VaultServiceProvider extends ServiceProvider {
  VaultServiceProvider(super.app);

  @override
  void register() {
    // Read inside the factory rather than beside it. `Magic.init` merges
    // the configuration before it registers providers
    // (`magic.dart:79` then `:94`), so both positions work at boot, but
    // `register()` runs the moment `app.register(provider)` is called
    // (`application.dart:335`) while this closure does not run until the
    // first `Vault` call. A consumer that registers the provider by hand,
    // or a test that sets the key afterwards, is then still read.
    //
    // An absent key is `null`, which makes the service probe the macOS
    // keychain on first use rather than assume the data protection one.
    app.singleton(
      'vault',
      () => MagicVaultService(
        macOsUsesDataProtectionKeychain: Config.get<bool>(
          'security.vault.macos_data_protection_keychain',
        ),
      ),
    );
  }

  @override
  Future<void> boot() async {
    // No async boot required for FlutterSecureStorage
  }
}
