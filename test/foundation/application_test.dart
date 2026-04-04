import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// A simple test service for testing container operations.
class TestService {
  final String name;
  TestService([this.name = 'default']);
}

void main() {
  // Reset the container before each test
  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });

  group('MagicApp.removeInstance()', () {
    test('removeInstance removes a cached instance', () {
      final app = MagicApp.instance;
      final instance = TestService('cached');

      // Set an instance and verify it's cached
      app.setInstance('test', instance);
      expect(identical(app.make<TestService>('test'), instance), isTrue);

      // Remove the instance
      app.removeInstance('test');

      // Verify that make() now resolves from the binding factory instead
      // We need a binding to fall back to
      app.bind('test', () {
        return TestService('from-factory');
      });

      final resolved = app.make<TestService>('test');
      expect(resolved.name, 'from-factory');
      expect(identical(resolved, instance), isFalse);
    });

    test('removeInstance with non-existent key does not throw', () {
      final app = MagicApp.instance;

      // Should not throw when removing a key that doesn't exist
      expect(() => app.removeInstance('nonexistent'), returnsNormally);
    });
  });
}
