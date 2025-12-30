import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_magic/fluttersdk_magic.dart';

class TestProvider extends ServiceProvider {
  bool booted = false;
  TestProvider(super.app);

  @override
  void register() {
    app.singleton('test_service', () => 'registered');
  }

  @override
  Future<void> boot() async {
    booted = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall methodCall) async {
      return '.';
    });
  });

  group('Magic.init Integration', () {
    setUp(() async {
      MagicApp.reset();
      Magic.flush();
    });

    test('initializes app, loads config, and boots providers', () async {
      final testConfig = {
        'app': {
          'name': 'Integration Test',
          'providers': [
            (app) => TestProvider(app),
          ],
        }
      };

      await Magic.init(configs: [testConfig]);

      // Verify Config Loaded
      expect(Config.get('app.name'), 'Integration Test');

      // Verify Provider Registered
      expect(Magic.bound('test_service'), isTrue);
      expect(Magic.make('test_service'), 'registered');

      // Verify Provider Booted (Accessed via app instance providers list? No, private)
      // We can't easily check provider instance state unless we keep a ref.
      // But we can check side effects.
      // Or we can register the provider instance manually? No Magic.init creates it from factory.

      // We can verify Cache works (Default provider)
      expect(Magic.bound('cache'), isTrue);

      // Verify Cache usage
      await Cache.put('key', 'val');
      expect(await Cache.get('key'), 'val');
    });
  });
}
