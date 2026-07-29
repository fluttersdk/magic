import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:jiffy/jiffy.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../facades/config.dart';
import '../facades/log.dart';
import '../foundation/magic.dart';
import '../localization/translator.dart';

/// The Date Manager Service.
///
/// Singleton service that initializes date/time handling and manages
/// locale synchronization with the optional Localization system.
///
/// This service is automatically booted by the framework. You don't need
/// to interact with it directly - use the [Carbon] class instead.
///
/// ## Features
///
/// - Initializes IANA timezone database
/// - Auto-detects device timezone
/// - Lists all available timezones
/// - Sets Jiffy and Intl locale defaults
/// - Syncs with Translator when Localization is enabled
/// - Works standalone when Localization is disabled
class DateManager {
  // ---------------------------------------------------------------------------
  // Singleton
  // ---------------------------------------------------------------------------

  static DateManager? _instance;

  /// Get the singleton instance.
  static DateManager get instance {
    _instance ??= DateManager._();
    return _instance!;
  }

  DateManager._();

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  /// Whether the manager has been booted.
  bool _booted = false;

  /// Current timezone location.
  tz.Location? _timezone;

  /// Current timezone name.
  String _timezoneName = 'UTC';

  /// The IANA identifier reported by the platform, cached.
  ///
  /// The platform lookup is asynchronous while [detectTimezone] is part of the
  /// published synchronous API, so the async resolver stores its answer here
  /// and the synchronous path reads it back.
  String? _platformTimezone;

  /// Current locale.
  String _locale = 'en';

  // ---------------------------------------------------------------------------
  // Boot
  // ---------------------------------------------------------------------------

  /// Boot the date manager.
  ///
  /// Initializes timezone database, sets defaults from config, and
  /// optionally syncs with the Translator service.
  Future<void> boot() async {
    if (_booted) return;

    // Initialize IANA timezone database
    tz.initializeTimeZones();

    // Check for auto-detect timezone
    final autoDetectTimezone =
        Config.get<bool>('localization.auto_detect_timezone', false) ?? false;

    if (autoDetectTimezone) {
      // Warm the platform identifier before the synchronous detection runs:
      // asking the platform is async, detectAndSetTimezone() is not.
      await detectPlatformTimezone();

      final detected = detectAndSetTimezone();
      _logDebug('Timezone auto-detected', {'timezone': detected});
    } else {
      // Use configured timezone
      final timezone =
          Config.get<String>('localization.timezone', 'UTC') ?? 'UTC';
      _setTimezoneInternal(timezone);
    }

    // Load locale from config
    _locale = Config.get<String>('localization.locale', 'en') ?? 'en';

    // Set locale defaults
    await _setLocale(_locale);

    // Conditional sync with Translator (if Localization is enabled)
    _setupTranslatorSync();

    _booted = true;
  }

  /// Set up sync with Translator service if available.
  void _setupTranslatorSync() {
    // Check if Localization service is enabled
    if (!Magic.bound('localization.enabled')) return;

    // Listen to Translator changes
    Translator.instance.addListener(_onTranslatorChange);
  }

  /// Handle Translator locale changes.
  void _onTranslatorChange() {
    final newLocale = Translator.instance.locale.languageCode;
    if (newLocale != _locale) {
      _setLocale(newLocale);
    }
  }

  /// Set the locale for date formatting.
  Future<void> _setLocale(String locale) async {
    _locale = locale;

    // Set Jiffy locale
    try {
      await Jiffy.setLocale(locale);
    } catch (_) {
      // Jiffy might not support all locales
    }

    // Set Intl default locale
    Intl.defaultLocale = locale;
  }

  /// Internal method to set timezone.
  void _setTimezoneInternal(String timezone) {
    // "UTC" is resolved against the package's const [tz.UTC] rather than the
    // database, because the database that `timezone/data/latest.dart` loads has
    // no entry under that name (it ships `Etc/UTC`). Going through
    // getLocation('UTC') therefore threw, which made the UTC fallback below
    // unreachable, and reported the documented default of
    // `localization.timezone` as invalid.
    if (timezone == _utcName) {
      _applyUtc();
      return;
    }

    try {
      _timezone = tz.getLocation(timezone);
      _timezoneName = timezone;
      tz.setLocalLocation(_timezone!);
    } catch (e) {
      // Fallback to UTC if timezone not found. This must not throw: boot()
      // calls it with whatever detection or config produced, and an
      // unresolvable zone is not a reason to fail application startup.
      _logError('Invalid timezone: $timezone, falling back to UTC');
      _applyUtc();
    }
  }

  /// The canonical UTC identifier this class reports.
  ///
  /// A literal rather than `tz.UTC.name`, because that name is NOT stable:
  /// `initializeTimeZones()` rebinds the package's UTC location from the loaded
  /// database, so it reads `UTC` on some hosts and `Etc/UTC` on others (a Linux
  /// CI runner reports the latter). Deriving the spelling from it made the
  /// reported timezone host-dependent, and made the equality check below miss
  /// on exactly the hosts where the fallback matters most.
  static const String _utcName = 'UTC';

  /// Apply UTC without consulting the database.
  ///
  /// [tz.UTC] is the location (always offset zero whichever name it carries);
  /// [_utcName] is what we report, so the identifier is the same everywhere.
  void _applyUtc() {
    _timezone = tz.UTC;
    _timezoneName = _utcName;
    tz.setLocalLocation(tz.UTC);
  }

  // ---------------------------------------------------------------------------
  // Timezone Detection
  // ---------------------------------------------------------------------------

  /// Detect and set the device timezone.
  ///
  /// Applies whatever [detectTimezone] resolves. When detection yields
  /// nothing, the configured `localization.timezone` stays in effect: an
  /// undetectable device is never worth a guess.
  ///
  /// Call [detectPlatformTimezone] first (the framework does so during [boot])
  /// so the platform identifier is available to this synchronous path.
  ///
  /// ```dart
  /// await DateManager.instance.detectPlatformTimezone();
  /// DateManager.instance.detectAndSetTimezone();
  /// ```
  String detectAndSetTimezone() {
    try {
      final detected = detectTimezone();
      if (detected != null) {
        _setTimezoneInternal(detected);
        return detected;
      }
    } catch (e) {
      _logError('Failed to detect timezone: $e');
    }

    // Fallback to config timezone
    final fallback =
        Config.get<String>('localization.timezone', 'UTC') ?? 'UTC';
    _setTimezoneInternal(fallback);
    return fallback;
  }

  /// Resolve the device's IANA timezone identifier from the platform.
  ///
  /// Asks the operating system (or the browser on web) for its zone
  /// identifier, validates it against the IANA database, and caches it for the
  /// synchronous [detectTimezone].
  ///
  /// Returns the identifier, or null when the platform reports nothing usable.
  /// Never throws: a missing plugin registration or a platform channel failure
  /// degrades to null so the configured timezone stays in place.
  ///
  /// Requires the IANA database to be initialized, which [boot] does; call
  /// this after `Magic.init()`.
  ///
  /// ```dart
  /// final zone = await DateManager.instance.detectPlatformTimezone();
  /// print(zone); // "Europe/Istanbul"
  /// ```
  Future<String?> detectPlatformTimezone() async {
    try {
      final TimezoneInfo info = await FlutterTimezone.getLocalTimezone();
      final String identifier = info.identifier.trim();

      // An identifier the database does not know is worse than none at all:
      // consumers forward it to a backend as if it were authoritative.
      if (identifier.isEmpty || !_isValidTimezone(identifier)) {
        _logError('Platform reported an unusable timezone: "$identifier"');
        return null;
      }

      _platformTimezone = identifier;

      return identifier;
    } catch (e) {
      _logError('Platform timezone lookup failed: $e');
      return null;
    }
  }

  /// Detect the device timezone without setting it.
  ///
  /// Resolution order:
  ///
  /// 1. The platform identifier resolved by [detectPlatformTimezone].
  /// 2. `DateTime.now().timeZoneName`, but only when it happens to be a real
  ///    IANA identifier: most platforms report an abbreviation there (`"+03"`,
  ///    `"EET"`), which names no zone.
  ///
  /// Returns null when neither yields a valid identifier. The UTC offset
  /// deliberately plays no part: many zones share an offset while differing in
  /// DST rules, so an offset match resolves to a plausible but wrong city.
  ///
  /// ```dart
  /// final tz = DateManager.instance.detectTimezone();
  /// print(tz); // "Europe/Istanbul"
  /// ```
  String? detectTimezone() {
    final String? platformTimezone = _platformTimezone;
    if (platformTimezone != null) {
      return platformTimezone;
    }

    final String deviceTzName = DateTime.now().timeZoneName;
    if (_isValidTimezone(deviceTzName)) {
      return deviceTzName;
    }

    return null;
  }

  /// Get all available timezones from the IANA database.
  ///
  /// ```dart
  /// final timezones = DateManager.instance.getAvailableTimezones();
  /// print(timezones.length); // 429
  /// ```
  List<String> getAvailableTimezones() {
    return tz.timeZoneDatabase.locations.keys.toList();
  }

  /// Check if a timezone identifier is valid.
  bool _isValidTimezone(String name) {
    // "UTC" is valid even though the loaded database has no entry under that
    // name; see [_setTimezoneInternal]. Without this, the documented default
    // of `localization.timezone` reads as invalid.
    if (name == _utcName) return true;

    try {
      tz.getLocation(name);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Log an error gracefully.
  void _logError(String message) {
    try {
      if (Magic.bound('log')) {
        Log.error(message);
      } else {
        debugPrint('[DateManager] $message');
      }
    } catch (_) {
      debugPrint('[DateManager] $message');
    }
  }

  /// Log debug info gracefully.
  void _logDebug(String message, [Map<String, dynamic>? context]) {
    try {
      if (Magic.bound('log')) {
        Log.debug(message, context);
      } else {
        debugPrint('[DateManager] $message ${context ?? ''}');
      }
    } catch (_) {
      debugPrint('[DateManager] $message');
    }
  }

  // ---------------------------------------------------------------------------
  // Accessors
  // ---------------------------------------------------------------------------

  /// Get the current timezone location.
  tz.Location get timezone => _timezone ?? tz.getLocation('UTC');

  /// Get the current IANA timezone identifier (e.g., "Europe/Istanbul").
  String get timezoneName => _timezoneName;

  /// Get the current locale.
  String get locale => _locale;

  /// Check if the manager has been booted.
  bool get isBooted => _booted;

  /// Get the default date format from config.
  String get dateFormat =>
      Config.get<String>('localization.date_format', 'MMMM do yyyy') ??
      'MMMM do yyyy';

  // ---------------------------------------------------------------------------
  // Methods
  // ---------------------------------------------------------------------------

  /// Set the timezone manually.
  ///
  /// ```dart
  /// DateManager.instance.setTimezone('America/New_York');
  /// ```
  void setTimezone(String timezone) {
    _setTimezoneInternal(timezone);
  }

  /// Set the locale manually.
  Future<void> setLocale(String locale) async {
    await _setLocale(locale);
  }

  // ---------------------------------------------------------------------------
  // Testing
  // ---------------------------------------------------------------------------

  /// Reset the manager (for testing).
  static void reset() {
    _instance = null;
  }
}
