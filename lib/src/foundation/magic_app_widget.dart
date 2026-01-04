import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart';

import '../facades/config.dart';
import '../facades/lang.dart';
import '../facades/log.dart';
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
  });

  @override
  State<MagicApplication> createState() => _MagicApplicationState();
}

class _MagicApplicationState extends State<MagicApplication> {
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _initialize() {
    try {
      // Magic.init() has already been called in main.dart before runApp()
      // So we just need to call onInit callback if provided

      // Configure initial route if different from default
      if (widget.initialRoute != '/') {
        MagicRouter.instance.setInitialLocation(widget.initialRoute);
      }

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

    final windThemeData = widget.windTheme ?? WindThemeData();

    return WindTheme(
      data: windThemeData,
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
}
