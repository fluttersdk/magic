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
  /// This method checks for the presence of an `app.key` in the configuration.
  /// If the key is missing, it registers a factory that throws a clear exception
  /// when the [Crypt] facade is accessed.
  ///
  /// Otherwise it binds a lazy [MagicEncrypter] built via
  /// [MagicEncrypter.fromAppKey], which accepts both a `base64:`-prefixed key
  /// (as produced by `magic key:generate`) and a raw 32-character key, and
  /// throws a clear error on access if the resolved key is not 32 bytes.
  @override
  Future<void> boot() async {
    final key = Config.get<String>('app.key');

    if (key == null || key.isEmpty) {
      // We bind a lazy singleton that throws on access to avoid crashing
      // the app during boot if encryption isn't used immediately.
      app.singleton('encrypter', () {
        throw Exception(
          'Missing App Key. Please set [app.key] in your config or run "magic key:generate".',
        );
      });
      return;
    }

    // Lazy: an invalid key surfaces a clear error when Crypt is first used,
    // not during boot. fromAppKey handles both base64: and raw 32-char keys.
    app.singleton('encrypter', () => MagicEncrypter.fromAppKey(key));
  }
}
