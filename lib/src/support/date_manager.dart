import 'package:flutter/foundation.dart';
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
    try {
      _timezone = tz.getLocation(timezone);
      _timezoneName = timezone;
      tz.setLocalLocation(_timezone!);
    } catch (e) {
      // Fallback to UTC if timezone not found
      _logError('Invalid timezone: $timezone, falling back to UTC');
      _timezone = tz.getLocation('UTC');
      _timezoneName = 'UTC';
      tz.setLocalLocation(_timezone!);
    }
  }

  // ---------------------------------------------------------------------------
  // Timezone Detection
  // ---------------------------------------------------------------------------

  /// Detect and set the device timezone.
  ///
  /// Uses the device's DateTime to detect timezone by matching offset
  /// against the IANA timezone database.
  ///
  /// ```dart
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

  /// Detect the device timezone without setting it.
  ///
  /// Returns the detected IANA timezone identifier or null if detection fails.
  ///
  /// ```dart
  /// final tz = DateManager.instance.detectTimezone();
  /// print(tz); // "Europe/Istanbul"
  /// ```
  String? detectTimezone() {
    try {
      final now = DateTime.now();
      final offset = now.timeZoneOffset;
      final deviceTzName = now.timeZoneName;

      // Try direct IANA name first
      if (_isValidTimezone(deviceTzName)) {
        return deviceTzName;
      }

      // Search in timezone database for matching offset
      final locations = tz.timeZoneDatabase.locations;
      for (final entry in locations.entries) {
        final location = entry.value;
        final tzNow = tz.TZDateTime.now(location);
        if (tzNow.timeZoneOffset == offset) {
          return entry.key;
        }
      }

      // Fallback to common offset mapping
      return _findTimezoneByOffset(offset);
    } catch (e) {
      _logError('Timezone detection error: $e');
      return null;
    }
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
    try {
      tz.getLocation(name);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Find a timezone by offset (fallback).
  String? _findTimezoneByOffset(Duration offset) {
    final offsetHours = offset.inHours;
    final offsetMinutes = offset.inMinutes % 60;

    // Common timezones by offset
    final commonTimezones = <int, String>{
      -12: 'Etc/GMT+12',
      -11: 'Pacific/Midway',
      -10: 'Pacific/Honolulu',
      -9: 'America/Anchorage',
      -8: 'America/Los_Angeles',
      -7: 'America/Denver',
      -6: 'America/Chicago',
      -5: 'America/New_York',
      -4: 'America/Caracas',
      -3: 'America/Sao_Paulo',
      -2: 'Atlantic/South_Georgia',
      -1: 'Atlantic/Azores',
      0: 'UTC',
      1: 'Europe/Paris',
      2: 'Europe/Berlin',
      3: 'Europe/Istanbul',
      4: 'Asia/Dubai',
      5: 'Asia/Karachi',
      6: 'Asia/Dhaka',
      7: 'Asia/Bangkok',
      8: 'Asia/Singapore',
      9: 'Asia/Tokyo',
      10: 'Australia/Sydney',
      11: 'Pacific/Noumea',
      12: 'Pacific/Auckland',
    };

    // Handle special offsets
    if (offsetMinutes == 30 && offsetHours == 5) return 'Asia/Kolkata';
    if (offsetMinutes == 30 && offsetHours == 9) return 'Australia/Darwin';
    if (offsetMinutes == 45 && offsetHours == 5) return 'Asia/Kathmandu';

    return commonTimezones[offsetHours];
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
