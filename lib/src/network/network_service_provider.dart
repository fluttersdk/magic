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

    final String appName = Config.get<String>('app.name', 'Magic')!;

    return <String, String>{
      ...headers,
      'User-Agent': '$appName (Flutter; ${_platformName()})',
    };
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
