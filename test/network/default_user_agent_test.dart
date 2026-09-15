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

    test('every Latin-1 and Latin Extended-A letter survives the fold', () {
      // The claim the docs make, checked rather than trusted. The table is
      // grouped by base letter, so a letter that is not an accented form of
      // one (the IJ ligatures, the kra, the eng, the long s) is invisible to a
      // reader scanning it and was in fact missing: `Ĳsselmeer` went out as
      // `sselmeer`, the mangled word folding exists to avoid.
      //
      // Walking the range is what makes the claim self-checking. Naming the
      // four that were missing would pass forever without noticing a fifth.
      final List<String> dropped = <String>[];

      // The Latin-1 Supplement block starts at U+0080, not at the accented
      // letters, and three of the characters below U+00C0 are letters rather
      // than symbols. They were dropped while the docs claimed the block was
      // covered: `\u00B5Torrent` went out as `Torrent`.
      const Set<int> lettersBelowC0 = <int>{0x00AA, 0x00B5, 0x00BA};

      for (int rune = 0x00A0; rune < 0x0180; rune++) {
        final String letter = String.fromCharCode(rune);

        // Everything else under U+00C0 is punctuation, a sign or a fraction,
        // and a fold that touched those would be mangling rather than folding.
        if (rune < 0x00C0 && !lettersBelowC0.contains(rune)) continue;

        // The two multiplication/division signs sit in the Latin-1 block and
        // are not letters; nothing should fold them.
        if (letter == '\u00D7' || letter == '\u00F7') continue;

        if (agentFor(letter).startsWith('Magic App (Flutter; ')) {
          dropped.add('U+${rune.toRadixString(16).toUpperCase()} $letter');
        }
      }

      expect(dropped, isEmpty, reason: 'these have no ASCII base to fold to');
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
