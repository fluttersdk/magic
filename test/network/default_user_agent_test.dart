import 'dart:io';

import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, TargetPlatform;
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
      expect(_resolveDriver().defaultHeaders.containsKey('User-Agent'), isTrue);
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
      // `Magic App` rather than `Magic`, matching what `lib/config/app.dart`
      // ships, so the value a booted app produces and the value this composes
      // when it cannot read one agree.
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
        startsWith('Magic App (Flutter; '),
      );
    });
  });

  group('a non-ASCII app name', () {
    /// Registers the provider with [name] and answers the composed agent.
    String agentFor(String name) {
      MagicApp.reset();
      Magic.flush();
      Config.set('app', <String, dynamic>{'name': name});
      Config.set('network', <String, dynamic>{
        'drivers': <String, dynamic>{
          'api': <String, dynamic>{'base_url': 'https://api.example.test'},
        },
      });
      NetworkServiceProvider(MagicApp.instance).register();

      return _resolveDriver().defaultHeaders['User-Agent']!;
    }

    test('folds accented Latin to its base letter', () {
      // Dropping instead of folding turns these into `irket Takip` and `Caf`,
      // which is worse than the ASCII name the adopter would have chosen.
      expect(agentFor('Şirket Takip'), startsWith('Sirket Takip (Flutter; '));
      expect(agentFor('Café Münster'), startsWith('Cafe Munster (Flutter; '));
      expect(agentFor('Łódź Główna'), startsWith('Lodz Glowna (Flutter; '));
    });

    test('falls back when nothing legible survives', () {
      // A script with no Latin base has nothing to fold to. Without the
      // fallback the agent would read `" (Flutter; iOS)"`, naming nothing.
      expect(agentFor('日本'), startsWith('Magic App (Flutter; '));
    });

    test('drops a CRLF rather than splitting the header', () {
      final String agent = agentFor('Evil\r\nX-Injected: 1');

      expect(agent, isNot(contains('\r')));
      expect(agent, isNot(contains('\n')));
    });

    test('dart:io accepts every one of them', () async {
      // The assertion that matters, and the one a string comparison cannot
      // make. `dart:io` refuses a header value with any byte above 127 and
      // throws a `FormatException` from `HttpHeaders.set`, which Dio surfaces
      // as a `DioException` on EVERY request: an app lost all of its HTTP
      // traffic because of its display name. Measured against the same
      // `HttpClient` path Dio's IO adapter uses.
      final HttpServer server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      server.listen(
        (HttpRequest r) => r.response
          ..statusCode = 200
          ..close(),
      );

      final HttpClient client = HttpClient();

      try {
        for (final String name in <String>[
          'Uptizm',
          'Şirket Takip',
          'Café Münster',
          '日本',
          'Evil\r\nX-Injected: 1',
        ]) {
          final HttpClientRequest request = await client.getUrl(
            Uri.parse('http://127.0.0.1:${server.port}/'),
          );

          expect(
            () => request.headers.set('User-Agent', agentFor(name)),
            returnsNormally,
            reason: '`$name` composed an agent dart:io refuses',
          );

          await (await request.close()).drain<void>();
        }
      } finally {
        client.close();
        await server.close();
      }
    });
  });
}
