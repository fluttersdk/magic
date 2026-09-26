import '../facades/config.dart';
import '../facades/lang.dart';
import '../foundation/env.dart';
import 'str.dart';

/// Builds absolute URLs against the app's configured origin (Laravel's
/// `url()` / `URL::to`).
///
/// The class is not named `Url`: that name is already taken by the
/// validation rule at `lib/src/validation/rules/url.dart`, and a second
/// public `Url` would collide with it in every file that imports both.
class UrlGenerator {
  // Prevent instantiation: every member is static.
  UrlGenerator._();

  /// The config key the origin is read from.
  ///
  /// `app.url` by default, matching Laravel's `APP_URL`. A consumer whose
  /// origin config lives under a different key (uptizm's marketing site
  /// origin is `app.web_url`, distinct from the API base URL at `app.url`)
  /// overrides this once, before any [to] or [localized] call.
  static String originKey = 'app.url';

  /// Composes an absolute URL from [path] and the configured origin.
  ///
  /// The origin is read from [originKey] in [Config], falling back to
  /// [Env.filled] (`APP_URL`, empty default) when that config slot is
  /// empty; either value has a wrapping quote pair stripped via [Str.unwrap]
  /// (a `.env` parser can leave one attached) and its trailing slashes
  /// removed, so `path` never has to guard against a doubled `//`.
  ///
  /// [query], when given, is appended as a `?key=value&...` string.
  static String to(String path, {Map<String, String>? query}) {
    final String url = '${_origin()}$path';
    if (query == null || query.isEmpty) return url;

    final Uri uri = Uri.parse(url);
    return uri.replace(queryParameters: query).toString();
  }

  /// Composes an absolute URL from [path], prefixed with the active
  /// language unless that language is the configured default one.
  ///
  /// Mirrors the rule the website itself applies (uptizm's
  /// `lib/app/support/web_links.dart`): the default language
  /// (`localization.locale`) lives on the bare path, every other language
  /// listed in `localization.supported_locales` gets a `/<lang>` prefix, and
  /// an unlisted language degrades to the bare path rather than composing an
  /// address nobody serves.
  static String localized(String path) {
    final String active = Lang.current.languageCode;
    final String prefix = _localePrefix(active);

    return to('$prefix$path');
  }

  /// The website origin, without a trailing slash.
  static String _origin() {
    final String configured = _clean(Config.get<String>(originKey, ''));
    final String origin = configured.isEmpty
        ? Env.filled('APP_URL', '')
        : configured;

    return origin.replaceAll(RegExp(r'/+$'), '');
  }

  /// The path prefix for [active], empty for the default language and for
  /// any language not listed as supported.
  static String _localePrefix(String active) {
    if (active.isEmpty) return '';

    final String defaultLocale = _clean(
      Config.get<String>('localization.locale', ''),
    );
    if (active == defaultLocale) return '';

    if (!_supportedLocales().contains(active)) return '';

    return '/$active';
  }

  /// The language codes listed under `localization.supported_locales`.
  static List<String> _supportedLocales() {
    final List<dynamic> configured =
        Config.get<List<dynamic>>(
          'localization.supported_locales',
          const <dynamic>[],
        ) ??
        const <dynamic>[];

    return configured.map((dynamic code) => _clean(code.toString())).toList();
  }

  /// Strips surrounding whitespace and one wrapping quote pair (`"` or `'`)
  /// from a raw config value.
  static String _clean(String? value) {
    if (value == null) return '';

    final String trimmed = value.trim();
    if (trimmed.length < 2) return trimmed;

    final String first = trimmed[0];
    final bool wrapped =
        (first == '"' || first == "'") && trimmed.endsWith(first);

    return wrapped ? Str.unwrap(trimmed, first).trim() : trimmed;
  }
}

/// Composes an absolute URL from [path] against the configured app origin
/// (Laravel's global `url()` helper).
///
/// ```dart
/// url('/terms'); // 'https://example.com/terms'
/// ```
String url(String path) => UrlGenerator.to(path);
