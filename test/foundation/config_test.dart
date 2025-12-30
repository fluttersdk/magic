import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_magic/fluttersdk_magic.dart';

void main() {
  group('ConfigRepository', () {
    late ConfigRepository config;

    setUp(() {
      config = ConfigRepository();
    });

    test('get() returns value for simple key', () {
      config.set('name', 'Test App');

      expect(config.get('name'), 'Test App');
    });

    test('get() returns value via dot notation', () {
      config.merge({
        'database': {
          'host': 'localhost',
          'port': 5432,
        }
      });

      expect(config.get('database.host'), 'localhost');
      expect(config.get('database.port'), 5432);
    });

    test('get() returns default for missing key', () {
      expect(config.get('missing', 'default'), 'default');
      expect(config.get('nested.missing', 42), 42);
    });

    test('set() creates nested structure via dot notation', () {
      config.set('services.mail.driver', 'smtp');

      expect(config.get('services.mail.driver'), 'smtp');
    });

    test('has() checks key existence', () {
      config.set('exists', true);

      expect(config.has('exists'), isTrue);
      expect(config.has('missing'), isFalse);
    });

    test('merge() deeply merges without overwriting', () {
      config.merge({
        'database': {
          'host': 'localhost',
          'port': 5432,
        }
      });

      config.merge({
        'database': {
          'name': 'myapp', // Add new key
        }
      });

      expect(config.get('database.host'), 'localhost'); // Preserved
      expect(config.get('database.port'), 5432); // Preserved
      expect(config.get('database.name'), 'myapp'); // Added
    });

    test('merge() overwrites non-map values', () {
      config.set('level', 1);

      config.merge({'level': 2});

      expect(config.get('level'), 2);
    });

    test('push() adds to array config', () {
      config.set('providers', ['A']);

      config.push('providers', 'B');

      expect(config.get<List>('providers'), ['A', 'B']);
    });

    test('prepend() adds to beginning of array', () {
      config.set('middlewares', ['B']);

      config.prepend('middlewares', 'A');

      expect(config.get<List>('middlewares'), ['A', 'B']);
    });

    test('forget() removes key', () {
      config.set('temp', 'value');

      config.forget('temp');

      expect(config.has('temp'), isFalse);
    });

    test('all() returns entire config', () {
      config.merge({
        'app': {'name': 'Test'},
      });

      final all = config.all();

      expect(all['app']['name'], 'Test');
    });

    test('flush() clears all config', () {
      config.set('key', 'value');

      config.flush();

      expect(config.all(), isEmpty);
    });
  });

  group('Config Facade', () {
    setUp(() {
      Config.flush();
    });

    test('Config.get() uses dot notation', () {
      Config.set('app.name', 'Magic');

      expect(Config.get('app.name'), 'Magic');
    });

    test('Config.merge() deeply merges', () {
      Config.merge({
        'database': {'host': 'localhost'},
      });
      Config.merge({
        'database': {'port': 5432},
      });

      expect(Config.get('database.host'), 'localhost');
      expect(Config.get('database.port'), 5432);
    });
  });
}
