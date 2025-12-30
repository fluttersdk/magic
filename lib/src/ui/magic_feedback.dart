import 'package:flutter/material.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart';

import '../routing/magic_router.dart';
import '../facades/config.dart';
import '../facades/log.dart';
import 'magic_view_registry.dart';

/// The Magic Feedback Engine.
///
/// Internal helper class that provides context-free UI feedback using
/// `MagicRouter.navigatorKey`. Uses Wind widgets for styling with
/// Config-driven customization.
class MagicFeedback {
  MagicFeedback._();

  static bool _isLoadingOpen = false;

  // ---------------------------------------------------------------------------
  // Context Access
  // ---------------------------------------------------------------------------

  static BuildContext? get _context {
    return MagicRouter.instance.navigatorKey.currentContext;
  }

  static bool get _isMounted => _context != null;

  // ---------------------------------------------------------------------------
  // Config Helpers
  // ---------------------------------------------------------------------------

  static String _getConfig(String key, String defaultValue) {
    return Config.get<String>(key, defaultValue) ?? defaultValue;
  }

  static int _getIntConfig(String key, int defaultValue) {
    return Config.get<int>(key, defaultValue) ?? defaultValue;
  }

  // ---------------------------------------------------------------------------
  // Snackbar
  // ---------------------------------------------------------------------------

  /// Show a snackbar notification.
  static void showSnackbar(
    // Renamed from snackbar
    String title,
    String message, {
    String type = 'info', // Added
    Duration? duration, // Modified
    Color? backgroundColor,
    Color? color,
  }) {
    if (_context == null) {
      Log.warning('MagicFeedback: Cannot show snackbar - context not mounted');
      return;
    }

    final context = _context!;
    final durationMs =
        duration?.inMilliseconds ?? // Modified duration calculation
            _getIntConfig('view.snackbar.duration', 4000);
    final styleClass = _getConfig(
      'view.snackbar.style.$type',
      'bg-gray-900 text-white', // Modified default value
    );

    Widget snackbarContent;

    if (MagicViewRegistry.instance.hasSnackbarBuilder) {
      snackbarContent = MagicViewRegistry.instance.buildSnackbar(
        title,
        message,
        type,
      );
    } else {
      snackbarContent = WDiv(
        className: '$styleClass flex flex-col',
        children: [
          WText(title, className: 'font-bold text-sm'),
          if (message.isNotEmpty)
            WText(message, className: 'text-sm mt-1 opacity-90'),
        ],
      );
    }

    final snackBar = SnackBar(
      content: snackbarContent,
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      padding: EdgeInsets.zero,
      duration: Duration(milliseconds: durationMs),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  /// Show a success snackbar.
  static void success(String title, String message) {
    showSnackbar(title, message, type: 'success');
  }

  /// Show an error snackbar.
  static void error(String title, String message) {
    showSnackbar(title, message, type: 'error');
  }

  /// Show an info snackbar.
  static void info(String title, String message) {
    showSnackbar(title, message, type: 'info');
  }

  /// Show a warning snackbar.
  static void warning(String title, String message) {
    showSnackbar(title, message, type: 'warning');
  }

  // ---------------------------------------------------------------------------
  // Dialog
  // ---------------------------------------------------------------------------

  /// Show a custom dialog.
  static Future<T?> showCustomDialog<T>(
    Widget content, {
    bool barrierDismissible = true,
  }) {
    if (_context == null) {
      Log.warning('MagicFeedback: Cannot show dialog - context not mounted');
      return Future.value(null);
    }

    final dismissible = barrierDismissible;
    final containerClass = _getConfig(
      'view.dialog.class',
      'bg-white rounded-xl p-6 shadow-2xl w-80 max-w-md',
    );

    return showDialog<T>(
      context: _context!,
      barrierDismissible: dismissible,
      barrierColor: Colors.black54,
      builder: (context) {
        Widget dialogContent;

        if (MagicViewRegistry.instance.hasDialogBuilder) {
          dialogContent = MagicViewRegistry.instance.buildDialog(
            context,
            content,
          );
        } else {
          dialogContent = Center(
            child: Material(
              color: Colors.transparent,
              child: WDiv(
                className: containerClass,
                child: content,
              ),
            ),
          );
        }

        return dialogContent;
      },
    );
  }

  /// Show a confirmation dialog.
  static Future<bool> confirm({
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDangerous = false,
  }) async {
    if (!_isMounted) return false;

    final containerClass = _getConfig(
      'view.confirm.container_class',
      'bg-white rounded-xl p-6 shadow-2xl w-80',
    );
    final titleClass = _getConfig(
      'view.confirm.title_class',
      'text-lg font-bold text-gray-900',
    );
    final messageClass = _getConfig(
      'view.confirm.message_class',
      'text-gray-600 mt-2',
    );
    final cancelBtnClass = _getConfig(
      'view.confirm.button_cancel_class',
      'px-4 py-2 text-gray-600',
    );
    final confirmBtnClass = isDangerous
        ? _getConfig(
            'view.confirm.button_danger_class',
            'px-4 py-2 bg-red-500 text-white rounded-lg',
          )
        : _getConfig(
            'view.confirm.button_confirm_class',
            'px-4 py-2 bg-blue-500 text-white rounded-lg',
          );

    final result = await showDialog<bool>(
      context: _context!,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) {
        if (MagicViewRegistry.instance.hasConfirmBuilder) {
          return MagicViewRegistry.instance.buildConfirm(
            context,
            title,
            message,
            confirmText,
            cancelText,
            isDangerous,
            (result) => Navigator.of(context).pop(result),
          );
        }

        return Center(
          child: Material(
            color: Colors.transparent,
            child: WDiv(
              className: containerClass,
              children: [
                WText(title, className: titleClass),
                WText(message, className: messageClass),
                WDiv(
                  className: 'flex flex-row justify-end gap-2 mt-6',
                  children: [
                    WAnchor(
                      onTap: () => Navigator.of(context).pop(false),
                      child: WDiv(
                        className: cancelBtnClass,
                        child: WText(cancelText),
                      ),
                    ),
                    WAnchor(
                      onTap: () => Navigator.of(context).pop(true),
                      child: WDiv(
                        className: confirmBtnClass,
                        child: WText(confirmText, className: 'text-white'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    return result ?? false;
  }

  // ---------------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------------

  /// Show a loading dialog.
  static void showLoading({String? message}) {
    if (_context == null) {
      Log.warning('MagicFeedback: Cannot show loading - context not mounted');
      return;
    }

    if (_isLoadingOpen) {
      Log.info('MagicFeedback: Loading dialog already open');
      return;
    }

    _isLoadingOpen = true;

    final containerClass = _getConfig(
      'view.loading.container_class',
      'bg-white rounded-xl p-6 shadow-2xl',
    );
    final spinnerClass = _getConfig(
      'view.loading.spinner_class',
      'text-blue-500',
    );
    final textClass = _getConfig(
      'view.loading.text_class',
      'text-gray-600 text-sm mt-4',
    );

    showDialog(
      context: _context!,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) {
        if (MagicViewRegistry.instance.hasLoadingBuilder) {
          return MagicViewRegistry.instance.buildLoading(context, message);
        }

        return PopScope(
          canPop: false,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: WDiv(
                className: '$containerClass flex flex-col items-center',
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _parseWindColor(spinnerClass),
                      ),
                    ),
                  ),
                  if (message != null) WText(message, className: textClass),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Close the loading dialog.
  static void closeLoading() {
    if (!_isLoadingOpen) return;

    if (_isMounted) {
      Navigator.of(_context!, rootNavigator: true).pop();
    }

    _isLoadingOpen = false;
  }

  /// Check if loading is shown.
  static bool get isLoading => _isLoadingOpen;

  // ---------------------------------------------------------------------------
  // Toast
  // ---------------------------------------------------------------------------

  /// Show a toast message.
  static void toast(
    String message, {
    Duration? duration,
  }) {
    if (!_isMounted) return;

    final durationMs =
        duration?.inMilliseconds ?? _getIntConfig('view.toast.duration', 2000);
    final toastClass = _getConfig(
      'view.toast.class',
      'bg-gray-800 text-white px-6 py-3 rounded-full shadow-lg',
    );

    Widget toastContent;

    if (MagicViewRegistry.instance.hasToastBuilder) {
      toastContent = MagicViewRegistry.instance.buildToast(message);
    } else {
      toastContent = WDiv(
        className: toastClass,
        child: WText(message, className: 'text-sm text-center'),
      );
    }

    final snackBar = SnackBar(
      content: Center(child: toastContent),
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      padding: EdgeInsets.zero,
      duration: Duration(milliseconds: durationMs),
    );

    ScaffoldMessenger.of(_context!)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Parse Wind color class to Flutter Color.
  static Color _parseWindColor(String className) {
    if (className.contains('blue')) return const Color(0xFF3B82F6);
    if (className.contains('green')) return const Color(0xFF22C55E);
    if (className.contains('red')) return const Color(0xFFEF4444);
    if (className.contains('amber')) return const Color(0xFFF59E0B);
    if (className.contains('gray')) return const Color(0xFF6B7280);
    return const Color(0xFF3B82F6);
  }
}
