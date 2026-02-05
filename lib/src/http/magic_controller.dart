import 'package:flutter/material.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart';

import 'rx_status.dart';

/// The Base Controller for Magic MVC.
///
/// Extends [ChangeNotifier] and provides lifecycle methods similar to Laravel.
///
/// ## Usage
///
/// ```dart
/// class UserController extends MagicController with MagicStateMixin<User> {
///   @override
///   void onInit() {
///     super.onInit();
///     fetchUser();
///   }
///
///   Future<void> fetchUser() async {
///     setLoading();
///     final user = await api.getUser();
///     setSuccess(user);
///   }
/// }
/// ```
abstract class MagicController extends ChangeNotifier {
  bool _initialized = false;
  bool _disposed = false;

  /// Whether the controller has been initialized.
  bool get initialized => _initialized;

  /// Whether the controller has been disposed.
  bool get isDisposed => _disposed;

  /// Called when the controller is first created.
  ///
  /// Override this to perform initialization logic (fetch data, etc).
  @mustCallSuper
  void onInit() {
    _initialized = true;
  }

  /// Called when the controller is about to be disposed.
  ///
  /// Override this to clean up resources (cancel streams, etc).
  @mustCallSuper
  void onClose() {
    _disposed = true;
  }

  @override
  void dispose() {
    if (!_disposed) {
      onClose();
    }
    super.dispose();
  }

  /// Refresh the UI by notifying listeners.
  void refreshUI() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}

/// State mixin for reactive data management.
///
/// Provides state, status, and the `renderState` method for
/// declarative UI based on status.
///
/// ## Usage
///
/// ```dart
/// class UserController extends MagicController with MagicStateMixin<User> {
///   @override
///   void onInit() {
///     super.onInit();
///     fetchUser();
///   }
///
///   Future<void> fetchUser() async {
///     setLoading();
///     try {
///       final user = await api.getUser();
///       setSuccess(user);
///     } catch (e) {
///       setError(e.toString());
///     }
///   }
/// }
/// ```
mixin MagicStateMixin<T> on MagicController {
  /// The current state data.
  T? _state;

  /// The current status.
  RxStatus _status = const RxStatus.empty();

  /// Get the current state.
  T? get rxState => _state;

  /// Get the current status.
  RxStatus get rxStatus => _status;

  /// Check if currently loading.
  bool get isLoading => _status.isLoading;

  /// Check if successfully loaded.
  bool get isSuccess => _status.isSuccess;

  /// Check if an error occurred.
  bool get isError => _status.isError;

  /// Check if empty (no data).
  bool get isEmpty => _status.isEmpty;

  /// Update state and/or status.
  ///
  /// This is the low-level method. Prefer using the helper methods:
  /// - [setLoading] - Set loading state
  /// - [setSuccess] - Set success with data
  /// - [setError] - Set error with message
  /// - [setEmpty] - Set empty state
  ///
  /// Set [notify] to `false` to update state without triggering a rebuild.
  /// This is useful when clearing state during initState to avoid
  /// "setState called during build" errors.
  void setState(T? newState, {RxStatus? status, bool notify = true}) {
    _state = newState;
    if (status != null) {
      _status = status;
    }
    if (notify) {
      refreshUI();
    }
  }

  // ---------------------------------------------------------------------------
  // State Helpers (Laravel-style)
  // ---------------------------------------------------------------------------

  /// Set loading state.
  ///
  /// ```dart
  /// Future<void> fetchUser() async {
  ///   setLoading();
  ///   final user = await api.getUser();
  ///   setSuccess(user);
  /// }
  /// ```
  void setLoading() {
    setState(null, status: const RxStatus.loading());
  }

  /// Set success state with data.
  ///
  /// ```dart
  /// setSuccess(user);
  /// ```
  void setSuccess(T data) {
    setState(data, status: const RxStatus.success());
  }

  /// Set error state with message.
  ///
  /// ```dart
  /// setError('Failed to load user');
  /// ```
  void setError(String message) {
    setState(null, status: RxStatus.error(message));
  }

  /// Set empty state (no data).
  ///
  /// ```dart
  /// setEmpty();
  /// ```
  void setEmpty() {
    setState(null, status: const RxStatus.empty());
  }

  /// Render UI based on current status.
  ///
  /// This is the "Magic" - declarative UI like Blade's @if directives.
  ///
  /// ```dart
  /// controller.renderState(
  ///   (user) => WText(user.name), // Success
  ///   onLoading: WText('Loading...'),
  ///   onError: (msg) => WText('Error: $msg'),
  ///   onEmpty: WText('No data'),
  /// )
  /// ```
  Widget renderState(
    Widget Function(T state) onSuccess, {
    Widget? onLoading,
    Widget Function(String message)? onError,
    Widget? onEmpty,
  }) {
    return AnimatedBuilder(
      animation: this,
      builder: (context, child) {
        switch (_status.type) {
          case RxStatusType.loading:
            return onLoading ?? _defaultLoading();

          case RxStatusType.success:
            if (_state != null) {
              return onSuccess(_state as T);
            }
            return onEmpty ?? _defaultEmpty();

          case RxStatusType.error:
            if (onError != null) {
              return onError(_status.message ?? 'Unknown error');
            }
            return _defaultError(_status.message ?? 'Unknown error');

          case RxStatusType.empty:
            return onEmpty ?? _defaultEmpty();
        }
      },
    );
  }

  /// Default loading widget (Wind spinner).
  Widget _defaultLoading() {
    return Center(
      child: WDiv(
        className: 'flex flex-col items-center gap-4',
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          WText('Loading...', className: 'text-gray-500 text-sm'),
        ],
      ),
    );
  }

  /// Default error widget.
  Widget _defaultError(String message) {
    return Center(
      child: WDiv(
        className: 'flex flex-col items-center gap-4 p-6',
        children: [
          WIcon(Icons.error_outline, className: 'text-red-500 text-4xl'),
          WText(message, className: 'text-red-500 text-center'),
        ],
      ),
    );
  }

  /// Default empty widget.
  Widget _defaultEmpty() {
    return Center(
      child: WDiv(
        className: 'flex flex-col items-center gap-4 p-6',
        children: [
          WIcon(Icons.inbox_outlined, className: 'text-gray-400 text-4xl'),
          WText('No data', className: 'text-gray-400'),
        ],
      ),
    );
  }
}

/// A simple controller without state mixin.
///
/// Use this for controllers that don't need reactive state.
abstract class SimpleMagicController extends MagicController {
  SimpleMagicController() {
    onInit();
  }
}
