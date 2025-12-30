/// Example Localization Configuration.
///
/// Override these values to customize localization and date behavior.
final localizationConfig = <String, dynamic>{
  'localization': {
    /// The default locale for the application.
    'locale': 'en',

    /// The fallback locale when a translation is not found.
    'fallback_locale': 'en',

    /// List of supported locales.
    'supported_locales': ['en', 'tr'],

    /// Auto-detect locale from device/browser on app start.
    'auto_detect_locale': true,

    /// Path to translation JSON files.
    'path': 'assets/lang',

    /// Default IANA timezone for date operations.
    'timezone': 'Europe/Istanbul',

    /// Auto-detect timezone from device on app start.
    'auto_detect_timezone': true,

    /// Default date format pattern.
    'date_format': 'dd MMMM yyyy',
  },
};
