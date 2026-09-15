import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// Resolves the driver the way an app does, through the container, so the test
/// exercises the provider rather than a hand-built driver.
DioNetworkDriver _resolveDriver() => Magic.make<DioNetworkDriver>('network');

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    Config.set('app', <String, dynamic>{'name': 'Uptizm'});
    Config.set('network', <String, dynamic>{
      'drivers': <String, dynamic>{
        'api': <String, dynamic>{
          'base_url': 'https://api.example.test',
          'headers': <String, String>{'Accept': 'application/json'},
        },
      },
    });
    NetworkServiceProvider(MagicApp.instance).register();
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('the default User-Agent', () {
    test('names the app and its platform', () {
      // Dart's own default is `Dart/<sdk> (dart:io)`, which says nothing about
      // the app and is identical across every Flutter client a backend has. A
      // server-side session list built on a user-agent parser matched no
      // browser and no platform against it, and filed a phone under desktop.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      MagicApp.reset();
      Magic.flush();
      Config.set('app', <String, dynamic>{'name': 'Uptizm'});
      Config.set('network', <String, dynamic>{
        'drivers': <String, dynamic>{
          'api': <String, dynamic>{'base_url': 'https://api.example.test'},
        },
      });
      NetworkServiceProvider(MagicApp.instance).register();

      expect(
        _resolveDriver().defaultHeaders['User-Agent'],
        'Uptizm (Flutter; iOS)',
      );
    });

    test('keeps the host headers beside it', () {
      expect(_resolveDriver().defaultHeaders['Accept'], 'application/json');
      expect(
        _resolveDriver().defaultHeaders.containsKey('User-Agent'),
        isTrue,
      );
    });

    test('does not overwrite one the host set', () {
      MagicApp.reset();
      Magic.flush();
      Config.set('app', <String, dynamic>{'name': 'Uptizm'});
      Config.set('network', <String, dynamic>{
        'drivers': <String, dynamic>{
          'api': <String, dynamic>{
            'base_url': 'https://api.example.test',
            'headers': <String, String>{'User-Agent': 'Custom/9.9'},
          },
        },
      });
      NetworkServiceProvider(MagicApp.instance).register();

      expect(_resolveDriver().defaultHeaders['User-Agent'], 'Custom/9.9');
    });

    test('matches the host key case-insensitively', () {
      // HTTP header names are case-insensitive, so a host writing `user-agent`
      // would otherwise end up sending two agents on one request.
      MagicApp.reset();
      Magic.flush();
      Config.set('app', <String, dynamic>{'name': 'Uptizm'});
      Config.set('network', <String, dynamic>{
        'drivers': <String, dynamic>{
          'api': <String, dynamic>{
            'base_url': 'https://api.example.test',
            'headers': <String, String>{'user-agent': 'Custom/9.9'},
          },
        },
      });
      NetworkServiceProvider(MagicApp.instance).register();

      final headers = _resolveDriver().defaultHeaders;

      expect(
        headers.keys.where((String k) => k.toLowerCase() == 'user-agent'),
        hasLength(1),
      );
      expect(headers['user-agent'], 'Custom/9.9');
    });

    test('falls back to a name when the app config has none', () {
      MagicApp.reset();
      Magic.flush();
      Config.set('network', <String, dynamic>{
        'drivers': <String, dynamic>{
          'api': <String, dynamic>{'base_url': 'https://api.example.test'},
        },
      });
      NetworkServiceProvider(MagicApp.instance).register();

      expect(
        _resolveDriver().defaultHeaders['User-Agent'],
        startsWith('Magic (Flutter; '),
      );
    });
  });
}
