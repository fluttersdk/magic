import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart';

import '../facades/config.dart';
import '../facades/lang.dart';
import '../facades/log.dart';
import '../facades/vault.dart';
import '../routing/magic_router.dart';

import 'magic.dart';

/// A wrapper widget that enables soft app restart.
class MagicAppWidget extends StatefulWidget {
  final Widget Function(BuildContext context) builder;
  final ThemeMode? themeMode;

  const MagicAppWidget({
    super.key,
    required this.builder,
    this.themeMode,
  });

  static final GlobalKey<MagicAppWidgetState> _appKey =
      GlobalKey<MagicAppWidgetState>();

  static void restart() {
    _appKey.currentState?.restart();
  }

  static MagicAppWidgetState? get state => _appKey.currentState;

  @override
  State<MagicAppWidget> createState() => MagicAppWidgetState();
}

class MagicAppWidgetState extends State<MagicAppWidget> {
  Key _appKey = UniqueKey();

  void restart() {
    setState(() {
      _appKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _appKey,
      child: widget.builder(context),
    );
  }
}

/// The recommended way to bootstrap a Magic application.
///
/// Handles all internal initialization (environment, config, routing)
/// and wraps the app in WindTheme for Wind widget support.
///
/// Theme preference is automatically persisted to Vault.
/// When a user manually toggles dark/light mode, the preference is saved
/// and restored on next app launch. If no preference is saved, the app
/// follows the system brightness setting.
///
/// ## Usage
///
/// ```dart
/// void main() {
///   runApp(
///     MagicApplication(
///       onInit: () {
///         registerRoutes();
///         Config.merge(appConfig);
///       },
///       windTheme: WindThemeData(
///         colors: {'primary': MaterialColor(0xFF3B82F6, {...})},
///       ),
///     ),
///   );
/// }
/// ```
class MagicApplication extends StatefulWidget {
  /// The app title.
  final String title;

  /// Wind theme data for styling.
  /// MaterialApp theme will be derived from this using controller.toThemeData().
  final WindThemeData? windTheme;

  /// Theme mode (light/dark/system).
  final ThemeMode themeMode;

  /// Locale override (defaults to config `localization.locale`).
  final Locale? locale;

  /// Localization delegates override.
  final Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates;

  /// Callback fired when the user manually toggles the theme.
  ///
  /// This is called IN ADDITION to the built-in theme persistence.
  /// Use this for custom side-effects beyond storage:
  /// ```dart
  /// MagicApplication(
  ///   onThemeChanged: (brightness) => analytics.track('theme_changed'),
  /// )
  /// ```
  final ValueChanged<Brightness>? onThemeChanged;

  /// Debug banner.
  final bool debugShowCheckedModeBanner;

  /// Optional callback to register routes and configs.
  final void Function()? onInit;

  /// Optional initial route (default: '/').
  final String initialRoute;

  /// Create a Magic application.
  const MagicApplication({
    super.key,
    this.title = 'Magic App',
    this.windTheme,
    this.themeMode = ThemeMode.system,
    this.initialRoute = '/',
    this.locale,
    this.localizationsDelegates,
    this.debugShowCheckedModeBanner = false,
    this.onInit,
    this.onThemeChanged,
  });

  @override
  State<MagicApplication> createState() => _MagicApplicationState();
}

class _MagicApplicationState extends State<MagicApplication> {
  /// Vault storage key for theme preference.
  static const _themeKey = 'theme_mode';

  bool _initialized = false;
  bool _hasError = false;

  /// Saved brightness preference loaded from Vault.
  ///
  /// - `null` means no preference saved (follow system).
  /// - Non-null means user has a manual preference.
  Brightness? _savedBrightness;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  /// Initialize the application and load saved theme preference.
  ///
  /// Loads theme preference from Vault before marking as initialized.
  /// If Vault is not available (no VaultServiceProvider registered),
  /// gracefully falls back to system default.
  Future<void> _initialize() async {
    try {
      // 1. Load saved theme preference from Vault.
      _savedBrightness = await _loadThemePreference();

      // 2. Configure initial route if different from default.
      if (widget.initialRoute != '/') {
        MagicRouter.instance.setInitialLocation(widget.initialRoute);
      }

      // 3. Call the app's onInit callback.
      widget.onInit?.call();
      setState(() => _initialized = true);
    } catch (e) {
      Log.error('MagicApplication: Init error', e);
      setState(() => _hasError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Failed to initialize app')),
        ),
      );
    }

    if (!_initialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // 1. Apply saved brightness preference to WindThemeData.
    final windThemeData = _applyThemePreference(
        widget.windTheme ?? WindThemeData(),
    );

    return WindTheme(
      data: windThemeData,
      onThemeChanged: _onThemeChanged,
      builder: (context, controller) => MagicAppWidget(
        key: MagicAppWidget._appKey,
        themeMode: widget.themeMode,
        builder: (context) => MaterialApp.router(
          title: widget.title,
          theme: controller.toThemeData(),
          themeMode: widget.themeMode,
          locale: widget.locale ?? _getLocaleFromConfig(),
          supportedLocales: _getSupportedLocalesFromConfig(),
          localizationsDelegates:
              widget.localizationsDelegates ?? _getLocalizationsDelegates(),
          debugShowCheckedModeBanner: widget.debugShowCheckedModeBanner,
          routerConfig: MagicRouter.instance.routerConfig,
        ),
      ),
    );
  }

  /// Get localization delegates based on translation service registration.
  ///
  /// Only includes [Lang.delegate] if [TranslationServiceProvider] is registered.
  List<LocalizationsDelegate<dynamic>> _getLocalizationsDelegates() {
    final delegates = <LocalizationsDelegate<dynamic>>[
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ];

    // Only add Lang.delegate if localization service is enabled
    if (Magic.bound('localization.enabled')) {
      delegates.insert(0, Lang.delegate);
    }

    return delegates;
  }

  /// Get the locale from config.
  ///
  /// Reads `localization.locale` from config. Defaults to 'en'.
  Locale? _getLocaleFromConfig() {
    final localeStr = Config.get<String>('localization.locale', null);
    if (localeStr == null) return null;
    return Locale(localeStr);
  }

  /// Get supported locales from config.
  ///
  /// Reads `localization.supported_locales` from config. Defaults to `[Locale('en')]`.
  List<Locale> _getSupportedLocalesFromConfig() {
    final locales =
        Config.get<List<dynamic>>('localization.supported_locales', null);
    if (locales == null) return [const Locale('en')];
    return locales.map((code) {
      if (code is Locale) return code;
      return Locale(code.toString());
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Theme Persistence
  // ---------------------------------------------------------------------------

  /// Apply saved brightness preference to the theme data.
  ///
  /// When a saved preference exists, overrides the brightness and disables
  /// system sync. Otherwise, returns the original theme data unchanged.
  WindThemeData _applyThemePreference(WindThemeData data) {
    if (_savedBrightness == null) {
      return data;
    }

    return data.copyWith(
      brightness: _savedBrightness,
      syncWithSystem: false,
    );
  }

  /// Handle theme change — persist to Vault and forward to user callback.
  ///
  /// Called only on user-initiated theme changes (not system changes).
  void _onThemeChanged(Brightness brightness) {
    // 1. Persist the preference to Vault.
    _saveThemePreference(brightness);

    // 2. Forward to user's callback if provided.
    widget.onThemeChanged?.call(brightness);
  }

  /// Load theme preference from Vault.
  ///
  /// Returns the saved [Brightness], or `null` if no preference is stored.
  /// Gracefully handles missing VaultServiceProvider.
  Future<Brightness?> _loadThemePreference() async {
    try {
      if (!Magic.bound('vault')) {
        return null;
      }

      final saved = await Vault.get(_themeKey);

      if (saved == 'dark') {
        Log.info('[MagicApplication] Theme preference loaded: dark');
        return Brightness.dark;
      }

      if (saved == 'light') {
        Log.info('[MagicApplication] Theme preference loaded: light');
        return Brightness.light;
      }

      return null;
    } catch (e) {
      Log.error('[MagicApplication] Failed to load theme preference: $e');
      return null;
    }
  }

  /// Save theme preference to Vault.
  ///
  /// Stores 'dark' or 'light' string. Gracefully handles missing Vault.
  Future<void> _saveThemePreference(Brightness brightness) async {
    try {
      if (!Magic.bound('vault')) {
        return;
      }

      final value = brightness == Brightness.dark ? 'dark' : 'light';
      await Vault.put(_themeKey, value);
      Log.info('[MagicApplication] Theme preference saved: $value');
    } catch (e) {
      Log.error('[MagicApplication] Failed to save theme preference: $e');
    }
  }
}
