import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// The Environment Facade.
///
/// Provides access to environment variables loaded from `.env` files.
/// This is a wrapper around `flutter_dotenv` that mimics Laravel's `env()`.
///
/// ## Setup
///
/// 1. Create a `.env` file in your project root:
/// ```
/// APP_NAME=My Awesome App
/// APP_ENV=production
/// API_URL=https://api.example.com
/// ```
///
/// 2. Add to your `pubspec.yaml` assets:
/// ```yaml
/// flutter:
///   assets:
///     - .env
/// ```
///
/// 3. Load during app initialization:
/// ```dart
/// await Env.load();
/// ```
///
/// ## Usage
///
/// ```dart
/// // Via class method
/// final appName = Env.get('APP_NAME', 'Default');
///
/// // Via global helper (Laravel-style)
/// final apiUrl = env('API_URL', 'http://localhost');
/// ```
class Env {
  // Prevent instantiation
  Env._();

  /// Whether the environment has been loaded.
  static bool _isLoaded = false;

  /// Fallback values when dotenv is not loaded.
  static final Map<String, String> _fallback = {};

  // ---------------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------------

  /// Load environment variables from `.env` file.
  ///
  /// Call this during app initialization, before accessing any env vars.
  ///
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await Env.load();
  ///   runApp(MyApp());
  /// }
  /// ```
  ///
  /// **Parameters:**
  /// - [fileName]: Path to the .env file (default: `.env`)
  /// - [mergeWith]: Additional values to merge (useful for testing)
  static Future<void> load({
    String fileName = '.env',
    Map<String, String>? mergeWith,
  }) async {
    if (_isLoaded) return;

    debugPrint('Env: Loading environment variables from $fileName');

    try {
      await dotenv.load(fileName: fileName, mergeWith: mergeWith ?? {});
      debugPrint('Env: Environment variables loaded successfully');
      _isLoaded = true;
    } catch (e) {
      // .env file might not exist - that's okay, use fallback values
      debugPrint('Env: .env file not found, using default values');
      if (mergeWith != null) {
        _fallback.addAll(mergeWith);
      }
      _isLoaded = true;
    }
  }

  /// Check if environment has been loaded.
  static bool get isLoaded => _isLoaded;

  // ---------------------------------------------------------------------------
  // Access
  // ---------------------------------------------------------------------------

  /// Get an environment variable value.
  ///
  /// ```dart
  /// final dbHost = Env.get('DB_HOST', 'localhost');
  /// final debug = Env.get<bool>('DEBUG', false);
  /// final port = Env.get<int>('PORT', 3000);
  /// ```
  ///
  /// **Parameters:**
  /// - [key]: The environment variable name
  /// - [defaultValue]: Value to return if key doesn't exist
  ///
  /// **Type Casting:**
  /// - Strings are returned as-is
  /// - 'true'/'false' strings are converted to bool if T is bool
  /// - Numeric strings are converted to int/double if T is num
  static T get<T>(String key, [T? defaultValue]) {
    // If not loaded, return default value
    if (!_isLoaded) {
      return defaultValue as T;
    }

    // Try dotenv first, then fallback
    String? value;
    try {
      value = dotenv.maybeGet(key);
    } catch (e) {
      // dotenv not initialized, use fallback
      value = _fallback[key];
    }

    value ??= _fallback[key];

    if (value == null) {
      return defaultValue as T;
    }

    // Type casting based on T
    if (T == bool) {
      return (['true', '1', 'yes'].contains(value.toLowerCase())) as T;
    }

    if (T == int) {
      return (int.tryParse(value) ?? defaultValue) as T;
    }

    if (T == double) {
      return (double.tryParse(value) ?? defaultValue) as T;
    }

    return value as T;
  }

  /// Get an environment variable as a string.
  ///
  /// Convenience method when you don't need type inference.
  static String getString(String key, [String defaultValue = '']) {
    return get<String>(key, defaultValue);
  }

  /// Get an environment variable as a boolean.
  ///
  /// Returns `true` for 'true', '1', 'yes' (case-insensitive).
  static bool getBool(String key, [bool defaultValue = false]) {
    return get<bool>(key, defaultValue);
  }

  /// Get an environment variable as an integer.
  static int getInt(String key, [int defaultValue = 0]) {
    return get<int>(key, defaultValue);
  }

  /// Check if an environment variable exists.
  static bool has(String key) {
    if (!_isLoaded) return false;
    try {
      return dotenv.maybeGet(key) != null || _fallback.containsKey(key);
    } catch (e) {
      return _fallback.containsKey(key);
    }
  }

  /// Get all environment variables as a Map.
  static Map<String, String> all() {
    if (!_isLoaded) return Map<String, String>.from(_fallback);
    try {
      return {..._fallback, ...dotenv.env};
    } catch (e) {
      return Map<String, String>.from(_fallback);
    }
  }

  /// Reset the Env state (for testing).
  static void reset() {
    _isLoaded = false;
    _fallback.clear();
  }
}

// ---------------------------------------------------------------------------
// Global Helper Function
// ---------------------------------------------------------------------------

/// Get an environment variable value.
///
/// This is a global helper function that mimics Laravel's `env()`:
///
/// ```dart
/// final appName = env('APP_NAME', 'My App');
/// final debug = env('DEBUG', false);
/// final port = env('PORT', 3000);
/// ```
///
/// The function automatically casts values based on the default value type.
T env<T>(String key, [T? defaultValue]) {
  return Env.get<T>(key, defaultValue);
}
