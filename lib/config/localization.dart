/// Default Localization Configuration.
///
/// These defaults are merged into Config during initialization.
/// Users can override these values in their `config/localization.dart`.
///
/// ## Available Options
///
/// - `locale`: Default locale (e.g., 'en')
/// - `fallback_locale`: Fallback when translation is missing (e.g., 'en')
/// - `supported_locales`: List of supported locale codes
/// - `auto_detect_locale`: Auto-detect from device/browser (default: false)
/// - `path`: Path to translation files (default: 'assets/lang')
/// - `timezone`: Default IANA timezone (e.g., 'UTC', 'America/New_York')
/// - `auto_detect_timezone`: Auto-detect timezone from device (default: false)
/// - `date_format`: Default date format pattern
final defaultLocalizationConfig = <String, dynamic>{
  'localization': {
    /// The default locale for the application.
    'locale': 'en',

    /// The fallback locale when a translation is not found.
    'fallback_locale': 'en',

    /// List of supported locales.
    'supported_locales': ['en'],

    /// Auto-detect locale from device/browser on app start.
    'auto_detect_locale': false,

    /// Path to translation JSON files.
    'path': 'assets/lang',

    /// Default IANA timezone for date operations.
    'timezone': 'UTC',

    /// Auto-detect timezone from device on app start.
    'auto_detect_timezone': false,

    /// Default date format pattern.
    'date_format': 'MMMM do yyyy',
  },
};
