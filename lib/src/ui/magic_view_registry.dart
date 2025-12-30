import 'package:flutter/widgets.dart';

/// Registry for custom view builders.
///
/// Allows developers to replace default UI components with custom implementations
/// via their `AppServiceProvider`.
///
/// ## Usage
///
/// ```dart
/// class AppServiceProvider extends ServiceProvider {
///   @override
///   void boot() {
///     Magic.view.setLoadingBuilder((context) {
///       return MyCustomLoadingWidget();
///     });
///
///     Magic.view.setSnackbarBuilder((title, message, type) {
///       return MyCustomSnackbar(title: title, message: message);
///     });
///   }
/// }
/// ```
class MagicViewRegistry {
  MagicViewRegistry._();

  static final MagicViewRegistry _instance = MagicViewRegistry._();

  /// Get the singleton instance.
  static MagicViewRegistry get instance => _instance;

  // ---------------------------------------------------------------------------
  // Custom Builders
  // ---------------------------------------------------------------------------

  /// Custom loading widget builder.
  Widget Function(BuildContext context, String? message)? _loadingBuilder;

  /// Custom snackbar widget builder.
  Widget Function(String title, String message, String type)? _snackbarBuilder;

  /// Custom dialog wrapper builder.
  Widget Function(BuildContext context, Widget content)? _dialogBuilder;

  /// Custom toast widget builder.
  Widget Function(String message)? _toastBuilder;

  /// Custom confirm dialog builder.
  Widget Function(
    BuildContext context,
    String title,
    String message,
    String confirmText,
    String cancelText,
    bool isDangerous,
    void Function(bool) onResult,
  )? _confirmBuilder;

  // ---------------------------------------------------------------------------
  // Setters
  // ---------------------------------------------------------------------------

  /// Set a custom loading widget builder.
  ///
  /// ```dart
  /// Magic.view.setLoadingBuilder((context, message) {
  ///   return WDiv(
  ///     className: 'flex items-center justify-center h-full',
  ///     child: WText('Loading...'),
  ///   );
  /// });
  /// ```
  void setLoadingBuilder(
    Widget Function(BuildContext context, String? message) builder,
  ) {
    _loadingBuilder = builder;
  }

  /// Set a custom snackbar widget builder.
  ///
  /// ```dart
  /// Magic.view.setSnackbarBuilder((title, message, type) {
  ///   return WDiv(
  ///     className: 'p-4 bg-blue-500 rounded-lg',
  ///     children: [
  ///       WText(title, className: 'font-bold text-white'),
  ///       WText(message, className: 'text-white'),
  ///     ],
  ///   );
  /// });
  /// ```
  void setSnackbarBuilder(
    Widget Function(String title, String message, String type) builder,
  ) {
    _snackbarBuilder = builder;
  }

  /// Set a custom dialog wrapper builder.
  ///
  /// ```dart
  /// Magic.view.setDialogBuilder((context, content) {
  ///   return WDiv(
  ///     className: 'bg-white rounded-xl p-6 shadow-2xl',
  ///     child: content,
  ///   );
  /// });
  /// ```
  void setDialogBuilder(
    Widget Function(BuildContext context, Widget content) builder,
  ) {
    _dialogBuilder = builder;
  }

  /// Set a custom toast widget builder.
  void setToastBuilder(Widget Function(String message) builder) {
    _toastBuilder = builder;
  }

  /// Set a custom confirm dialog builder.
  void setConfirmBuilder(
    Widget Function(
      BuildContext context,
      String title,
      String message,
      String confirmText,
      String cancelText,
      bool isDangerous,
      void Function(bool) onResult,
    ) builder,
  ) {
    _confirmBuilder = builder;
  }

  // ---------------------------------------------------------------------------
  // Getters (Internal Use)
  // ---------------------------------------------------------------------------

  /// Check if custom loading builder exists.
  bool get hasLoadingBuilder => _loadingBuilder != null;

  /// Check if custom snackbar builder exists.
  bool get hasSnackbarBuilder => _snackbarBuilder != null;

  /// Check if custom dialog builder exists.
  bool get hasDialogBuilder => _dialogBuilder != null;

  /// Check if custom toast builder exists.
  bool get hasToastBuilder => _toastBuilder != null;

  /// Check if custom confirm builder exists.
  bool get hasConfirmBuilder => _confirmBuilder != null;

  /// Build custom loading widget.
  Widget buildLoading(BuildContext context, String? message) {
    return _loadingBuilder!(context, message);
  }

  /// Build custom snackbar widget.
  Widget buildSnackbar(String title, String message, String type) {
    return _snackbarBuilder!(title, message, type);
  }

  /// Build custom dialog wrapper.
  Widget buildDialog(BuildContext context, Widget content) {
    return _dialogBuilder!(context, content);
  }

  /// Build custom toast widget.
  Widget buildToast(String message) {
    return _toastBuilder!(message);
  }

  /// Build custom confirm dialog.
  Widget buildConfirm(
    BuildContext context,
    String title,
    String message,
    String confirmText,
    String cancelText,
    bool isDangerous,
    void Function(bool) onResult,
  ) {
    return _confirmBuilder!(
      context,
      title,
      message,
      confirmText,
      cancelText,
      isDangerous,
      onResult,
    );
  }

  /// Reset all custom builders (for testing).
  void reset() {
    _loadingBuilder = null;
    _snackbarBuilder = null;
    _dialogBuilder = null;
    _toastBuilder = null;
    _confirmBuilder = null;
  }
}
