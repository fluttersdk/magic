import '../support/service_provider.dart';
import '../facades/config.dart';
import 'magic_encrypter.dart';

class EncryptionServiceProvider extends ServiceProvider {
  EncryptionServiceProvider(super.app);

  @override
  void register() {
    //
  }

  /// Bootstrap the encryption services.
  ///
  /// This method checks for the presence of a valid 32-character `app.key`
  /// in the configuration. If the key is missing or invalid, it registers
  /// a factory that throws a clear exception when the [Crypt] facade is accessed.
  ///
  /// If the key is valid, it binds the [MagicEncrypter] as a singleton.
  @override
  Future<void> boot() async {
    final key = Config.get<String>('app.key');

    if (key == null || key.isEmpty) {
      // We bind a lazy singleton that throws on access to avoid crashing
      // the app during boot if encryption isn't used immediately.
      app.singleton('encrypter', () {
        throw Exception(
            'Missing App Key. Please set [app.key] in your config or run "magic key:generate".');
      });
      return;
    }

    if (key.length != 32) {
      app.singleton('encrypter', () {
        throw Exception('App Key must be 32 characters for AES-256.');
      });
      return;
    }

    app.singleton('encrypter', () => MagicEncrypter(key));
  }
}
