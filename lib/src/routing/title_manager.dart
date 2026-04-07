import 'package:flutter/services.dart';

/// Manages page titles across routing, widgets, and facades.
///
/// Follows the singleton pattern used by [MagicRouter]. Computes the effective
/// title from a priority stack (override → route → app) and optionally appends
/// a shared suffix. Invokes an injectable callback on every change so tests can
/// capture updates without mocking [SystemChrome].
///
/// Priority (highest → lowest):
///   1. [setOverride] — set from `MagicTitle` widget or `setTitle` facade call
///   2. [setRouteTitle] — set from GoRouter route listener
///   3. [setAppTitle] — set from application bootstrap
class TitleManager {
  // ---------------------------------------------------------------------------
  // Singleton Pattern
  // ---------------------------------------------------------------------------

  TitleManager._({
    void Function(String title, int? primaryColor)? onTitleChanged,
  }) : _onTitleChanged = onTitleChanged;

  static TitleManager? _instance;

  /// Access the global [TitleManager] instance.
  static TitleManager get instance {
    _instance ??= TitleManager._();
    return _instance!;
  }

  /// Create or replace the instance with a custom callback (for testing).
  ///
  /// Calls [reset] first so all accumulated state is cleared before the new
  /// instance is installed.
  static void configure({
    void Function(String title, int? primaryColor)? onTitleChanged,
  }) {
    reset();
    _instance = TitleManager._(onTitleChanged: onTitleChanged);
  }

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  String? _suffix;
  String? _appTitle;
  String? _routeTitle;
  String? _overrideTitle;

  /// Callback invoked whenever the effective title changes.
  ///
  /// Defaults to [SystemChrome.setApplicationSwitcherDescription] when not
  /// provided via [configure].
  final void Function(String title, int? primaryColor)? _onTitleChanged;

  // ---------------------------------------------------------------------------
  // Mutators
  // ---------------------------------------------------------------------------

  /// Set the global title suffix (e.g. the app name appended to page titles).
  ///
  /// Passing `null` removes the suffix. Triggers a title recomputation.
  TitleManager setSuffix(String? suffix) {
    _suffix = suffix;
    _applyTitle();
    return this;
  }

  /// Set the application-level title used as the final fallback.
  ///
  /// Triggers a title recomputation.
  TitleManager setAppTitle(String? appTitle) {
    _appTitle = appTitle;
    _applyTitle();
    return this;
  }

  /// Set the route-level title, typically sourced from a [RouteDefinition].
  ///
  /// Triggers a title recomputation.
  TitleManager setRouteTitle(String? routeTitle) {
    if (_routeTitle == routeTitle) return this;
    _routeTitle = routeTitle;
    _applyTitle();
    return this;
  }

  /// Set an explicit override title from `MagicTitle` or the `setTitle` facade.
  ///
  /// Passing `null` clears the override and falls back to route/app title.
  /// Triggers a title recomputation.
  TitleManager setOverride(String? overrideTitle) {
    _overrideTitle = overrideTitle;
    _applyTitle();
    return this;
  }

  // ---------------------------------------------------------------------------
  // Accessors
  // ---------------------------------------------------------------------------

  /// Returns the effective title **without** the suffix applied.
  ///
  /// Resolution order: override → routeTitle → appTitle.
  String? get currentTitle => _overrideTitle ?? _routeTitle ?? _appTitle;

  /// Returns the computed title **with** the suffix applied.
  ///
  /// When both a raw title and a suffix are present the result is
  /// `"$rawTitle - $_suffix"`. When there is no raw title the suffix is
  /// omitted and the app title (or empty string) is returned.
  String get effectiveTitle {
    final rawTitle = _overrideTitle ?? _routeTitle ?? _appTitle;
    if (rawTitle != null && _suffix != null) {
      return '$rawTitle - $_suffix';
    }
    return rawTitle ?? '';
  }

  // ---------------------------------------------------------------------------
  // Reset (Testing)
  // ---------------------------------------------------------------------------

  /// Reset all state and discard the singleton instance.
  ///
  /// Subsequent access to [instance] creates a fresh [TitleManager].
  static void reset() {
    _instance = null;
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  /// Compute [effectiveTitle] and invoke [_onTitleChanged].
  ///
  /// Falls back to [SystemChrome.setApplicationSwitcherDescription] when no
  /// custom callback was provided via [configure].
  void _applyTitle() {
    final title = effectiveTitle;
    if (_onTitleChanged != null) {
      _onTitleChanged(title, null);
    } else {
      SystemChrome.setApplicationSwitcherDescription(
        ApplicationSwitcherDescription(label: title),
      );
    }
  }
}
