import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

import '../facades/config.dart';
import '../network/drivers/dio_network_driver.dart';
import '../support/service_provider.dart';

/// The Network Service Provider.
///
/// Registers the default network driver and applies configured interceptors.
class NetworkServiceProvider extends ServiceProvider {
  NetworkServiceProvider(super.app);

  @override
  void register() {
    app.singleton('network', () {
      final config =
          Config.get<Map<String, dynamic>>('network.drivers.api') ?? {};

      return DioNetworkDriver(
        baseUrl: config['base_url'] ?? '',
        timeout: config['timeout'] ?? 10000,
        defaultHeaders: _withUserAgent(
          Map<String, String>.from(config['headers'] ?? {}),
        ),
      );
    });
  }

  /// Adds a `User-Agent` naming this app, unless [headers] already carries one.
  ///
  /// Dart's HTTP client sends `Dart/<sdk> (dart:io)` by default, which says
  /// nothing about the app and is indistinguishable between every Flutter
  /// client a backend has. Anything the server derives from the agent then
  /// answers wrongly rather than partially: a session list built on a
  /// user-agent parser matched no browser and no platform and filed a phone
  /// under desktop, so a native app's own session read as a browser session on
  /// an unknown machine.
  ///
  /// `<App Name> (Flutter; <platform>)`. No version, because nothing in magic
  /// knows the app's build number and inventing a key an adopter has to fill in
  /// would leave the useful half empty in most apps.
  ///
  /// Skipped on WEB, where it would be a no-op at best. `User-Agent` is a
  /// forbidden header name for `XMLHttpRequest`, so the browser drops it and
  /// sends its own, which is the right agent there anyway.
  ///
  /// A host that sets its own `User-Agent` in `network.drivers.api.headers`
  /// keeps it. The match is case-insensitive, because HTTP header names are and
  /// a host writing `user-agent` would otherwise end up sending two.
  static Map<String, String> _withUserAgent(Map<String, String> headers) {
    if (kIsWeb) return headers;

    final bool hostSetOne = headers.keys.any(
      (String key) => key.toLowerCase() == 'user-agent',
    );
    if (hostSetOne) return headers;

    final String appName = _headerSafeAppName(
      Config.get<String>('app.name', _fallbackAppName)!,
    );

    return <String, String>{
      ...headers,
      'User-Agent': '$appName (Flutter; ${_platformName()})',
    };
  }

  /// The name used when `app.name` is unset or survives sanitising as nothing.
  ///
  /// Matches what `lib/config/app.dart` ships, so the value a booted app
  /// produces and the value this composes when it cannot read one agree.
  static const String _fallbackAppName = 'Magic App';

  /// [name] reduced to something a header value may legally carry.
  ///
  /// This is not cosmetic. `dart:io` refuses any header value with a byte above
  /// 127 and throws a `FormatException` from `HttpHeaders.set`, which Dio
  /// surfaces as a `DioException` on EVERY request. So an app called `Cafe`
  /// with an accent, or `Sirket Takip` with a cedilla, would lose all of its
  /// HTTP traffic because of its display name, with nothing at build time to
  /// connect the two. Measured against the same `HttpClient` path Dio's IO
  /// adapter uses: `Invalid HTTP header field value`.
  ///
  /// Accented Latin letters are folded to their base letter rather than
  /// dropped, because dropping leaves a mangled word where the adopter would
  /// have picked a plain-ASCII name. The table covers every letter in Latin-1
  /// Supplement and Latin Extended-A, so Turkish, German, French, Spanish,
  /// Nordic, Polish, Czech and Dutch names survive legibly, and a test walks
  /// both ranges so the claim checks itself. A script with no Latin base (CJK,
  /// Arabic, Cyrillic) has nothing to fold to and is dropped.
  ///
  /// Everything still outside printable ASCII goes, which also closes the
  /// injection shape: a name carrying a carriage return or newline cannot split
  /// the header, because both are below 0x20.
  ///
  /// Falls back to [_fallbackAppName] when nothing legible survives, so the
  /// agent still names the platform rather than opening with a bare space.
  static String _headerSafeAppName(String name) {
    final StringBuffer folded = StringBuffer();

    for (final int rune in name.runes) {
      final String? base = _latinFolding[rune];

      if (base != null) {
        folded.write(base);
        continue;
      }

      // Printable ASCII only: 0x20 (space) through 0x7E (tilde).
      if (rune >= 0x20 && rune <= 0x7E) folded.write(String.fromCharCode(rune));
    }

    final String cleaned = folded
        .toString()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return cleaned.isEmpty ? _fallbackAppName : cleaned;
  }

  /// Accented Latin letters to their base letter, keyed by rune.
  ///
  /// Built from grouped strings rather than entry by entry, so the coverage of
  /// each base letter is readable at a glance and a missing accent is visible
  /// rather than buried in sixty lines of map literal.
  static final Map<int, String> _latinFolding = _buildFolding(<String, String>{
    'A': 'ÀÁÂÃÄÅĀĂĄ',
    'a': 'àáâãäåāăąª',
    'C': 'ÇĆĈĊČ',
    'c': 'çćĉċč',
    'D': 'ÐĎĐ',
    'd': 'ðďđ',
    'E': 'ÈÉÊËĒĔĖĘĚ',
    'e': 'èéêëēĕėęě',
    'G': 'ĜĞĠĢ',
    'g': 'ĝğġģ',
    'H': 'ĤĦ',
    'h': 'ĥħ',
    'I': 'ÌÍÎÏĨĪĬĮİ',
    'i': 'ìíîïĩīĭįı',
    'J': 'Ĵ',
    'j': 'ĵ',
    'K': 'Ķ',
    'k': 'ķĸ',
    'L': 'ĹĻĽĿŁ',
    'l': 'ĺļľŀł',
    'N': 'ÑŃŅŇŊ',
    'n': 'ñńņňŉŋ',
    'O': 'ÒÓÔÕÖØŌŎŐ',
    'o': 'òóôõöøōŏőº',
    'R': 'ŔŖŘ',
    'r': 'ŕŗř',
    'S': 'ŚŜŞŠ',
    's': 'śŝşšſ',
    'T': 'ŢŤŦ',
    't': 'ţťŧ',
    'U': 'ÙÚÛÜŨŪŬŮŰŲ',
    'u': 'ùúûüũūŭůűųµ',
    'W': 'Ŵ',
    'w': 'ŵ',
    'Y': 'ÝŶŸ',
    'y': 'ýÿŷ',
    'Z': 'ŹŻŽ',
    'z': 'źżž',
    'AE': 'ÆǼ',
    'ae': 'æǽ',
    'OE': 'Œ',
    'oe': 'œ',
    'ss': 'ß',
    'TH': 'Þ',
    'th': 'þ',
    // The two ligatures, the only entries whose base is two letters and so the
    // only ones that cannot join a group above. The kra, the eng and the long s
    // were missing for the same reason and are folded into `k`, `N`/`n` and `s`
    // rather than added here: a repeated key in a Dart map literal takes the
    // LAST value, so a fresh `'n': 'ŋ'` would have silently replaced the five
    // accented n's above it.
    'IJ': 'Ĳ',
    'ij': 'ĳ',
  });

  /// Inverts the grouped folding table into a rune-keyed lookup.
  static Map<int, String> _buildFolding(Map<String, String> groups) {
    final Map<int, String> table = <int, String>{};

    groups.forEach((String base, String accented) {
      for (final int rune in accented.runes) {
        table[rune] = base;
      }
    });

    return table;
  }

  /// The platform name a server can read, in the casing Apple and Google use.
  static String _platformName() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.android => 'Android',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.linux => 'Linux',
      TargetPlatform.fuchsia => 'Fuchsia',
    };
  }

  @override
  Future<void> boot() async {
    // Interceptors can be added here if resolved from container
    // final driver = app.make<NetworkDriver>('network');
    // final interceptors = Config.get<List>('network.drivers.api.interceptors') ?? [];
    // for (final factory in interceptors) {
    //   driver.addInterceptor(factory());
    // }
  }
}
