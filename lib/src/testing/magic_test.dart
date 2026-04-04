import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// Test bootstrap helper for Magic framework.
///
/// Provides standardized setup/teardown for unit and widget tests.
///
/// ```dart
/// void main() {
///   MagicTest.init();
///   test('my test', () { /* Magic container is clean */ });
/// }
/// ```
class MagicTest {
  MagicTest._();

  /// Initialize test environment with standard setup/teardown.
  ///
  /// Registers:
  /// - `setUpAll`: `TestWidgetsFlutterBinding.ensureInitialized()`
  /// - `setUp`: `MagicApp.reset()` + `Magic.flush()`
  /// - `tearDown`: `Magic.flush()`
  static void init() {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });
    setUp(() {
      MagicApp.reset();
      Magic.flush();
    });
    tearDown(() {
      Magic.flush();
    });
  }

  /// Bootstrap Magic with test configuration.
  ///
  /// Use when you need full Magic.init() with test configs.
  /// Typically called in setUpAll or at the top of main().
  static Future<void> boot({
    List<Map<String, dynamic>> configs = const [],
    String envFileName = '.env.testing',
  }) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    MagicApp.reset();
    Magic.flush();
    await Magic.init(envFileName: envFileName, configs: configs);
  }
}
