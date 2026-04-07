import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();
  });

  group('URL Strategy Config Resolution', () {
    test('default config returns null for routing.url_strategy', () async {
      await Magic.init(
        configs: [
          {
            'app': {'name': 'Test App'},
          },
        ],
      );

      expect(Config.get('routing.url_strategy'), isNull);
    });

    test('path strategy config is accessible after init', () async {
      await Magic.init(
        configs: [
          {
            'routing': {'url_strategy': 'path'},
          },
        ],
      );

      expect(Config.get('routing.url_strategy'), 'path');
    });

    test('hash strategy config is accessible after init', () async {
      await Magic.init(
        configs: [
          {
            'routing': {'url_strategy': 'hash'},
          },
        ],
      );

      expect(Config.get('routing.url_strategy'), 'hash');
    });
  });

  group('Magic.init completes without error for all URL strategy values', () {
    test('path strategy — Magic.init completes without throwing', () async {
      await expectLater(
        Magic.init(
          configs: [
            {
              'routing': {'url_strategy': 'path'},
            },
          ],
        ),
        completes,
      );
    });

    test('hash strategy — Magic.init completes without throwing', () async {
      await expectLater(
        Magic.init(
          configs: [
            {
              'routing': {'url_strategy': 'hash'},
            },
          ],
        ),
        completes,
      );
    });

    test(
      'null strategy (default) — Magic.init completes without throwing',
      () async {
        await expectLater(
          Magic.init(
            configs: [
              {
                'routing': {'url_strategy': null},
              },
            ],
          ),
          completes,
        );
      },
    );

    test(
      'unrecognized strategy — Magic.init completes without throwing (silent no-op)',
      () async {
        await expectLater(
          Magic.init(
            configs: [
              {
                'routing': {'url_strategy': 'invalid'},
              },
            ],
          ),
          completes,
        );
      },
    );
  });
}
