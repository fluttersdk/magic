import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

import '../facades/config.dart';
import '../network/drivers/dio_network_driver.dart';
import '../support/service_provider.dart';
import '../support/str.dart';

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
  /// [Str.ascii] folds accented Latin letters to their base letter rather
  /// than dropping them, because dropping leaves a mangled word where the
  /// adopter would have picked a plain-ASCII name. It covers every letter in
  /// Latin-1 Supplement and Latin Extended-A, so Turkish, German, French,
  /// Spanish, Nordic, Polish, Czech and Dutch names survive legibly, and a
  /// test walks both ranges so the claim checks itself. A script with no
  /// Latin base (CJK, Arabic, Cyrillic) has nothing to fold to and is left
  /// as-is by [Str.ascii], then dropped below by the printable-ASCII filter.
  ///
  /// Everything still outside printable ASCII goes, which also closes the
  /// injection shape: a name carrying a carriage return or newline cannot split
  /// the header, because both are below 0x20.
  ///
  /// Falls back to [_fallbackAppName] when nothing legible survives, so the
  /// agent still names the platform rather than opening with a bare space.
  static String _headerSafeAppName(String name) {
    final StringBuffer folded = StringBuffer();

    for (final int rune in Str.ascii(name).runes) {
      // Printable ASCII only: 0x20 (space) through 0x7E (tilde). [Str.ascii]
      // folds Latin diacritics but leaves non-Latin scripts and control code
      // points in place, so this filter still has to run.
      if (rune >= 0x20 && rune <= 0x7E) folded.write(String.fromCharCode(rune));
    }

    final String cleaned = folded
        .toString()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return cleaned.isEmpty ? _fallbackAppName : cleaned;
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
