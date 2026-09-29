import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

import '../concerns/validates_requests.dart';
import '../foundation/magic.dart';
import '../http/magic_controller.dart';
import '../http/rx_status.dart';
import '../validation/contracts/rule.dart';
import '../validation/form_validator.dart';

/// The Base View for Magic MVC.
///
/// Provides automatic controller injection - just like accessing
/// `$controller` in a Laravel Blade file.
///
/// ## Usage
///
/// ```dart
/// class UserView extends MagicView<UserController> {
///   const UserView({super.key});
///
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(
///       body: controller.renderState(
///         (user) => WText(user.name),
///         onError: (msg) => WText('Error: $msg'),
///       ),
///     );
///   }
/// }
/// ```
///
/// The controller is automatically resolved from the Magic container.
/// Make sure to register your controller before using the view:
///
/// ```dart
/// Magic.put(UserController());
/// ```
abstract class MagicView<T extends MagicController> extends StatelessWidget {
  const MagicView({super.key});

  /// Get the controller instance.
  ///
  /// This auto-injects the controller from Magic's container,
  /// similar to accessing `$controller` in Blade.
  T get controller => Magic.find<T>();
}

/// A stateful version of MagicView.
///
/// Use this when you need Flutter lifecycle methods (initState, dispose)
/// or local widget state (TextEditingController, etc).
///
/// The view automatically listens to controller changes and rebuilds.
abstract class MagicStatefulView<T extends MagicController>
    extends StatefulWidget {
  const MagicStatefulView({super.key});
}

/// State for MagicStatefulView.
///
/// Automatically binds to the controller and rebuilds when it changes.
/// This is the "Magic" - you don't need to manually call setState or
/// wrap widgets in AnimatedBuilder for controller changes.
///
/// ## Usage
///
/// ```dart
/// class LoginView extends MagicStatefulView<AuthController> {
///   const LoginView({super.key});
///
///   @override
///   State<LoginView> createState() => _LoginViewState();
/// }
///
/// class _LoginViewState extends MagicStatefulViewState<AuthController, LoginView> {
///   final _email = TextEditingController();
///
///   @override
///   void onClose() {
///     _email.dispose();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return MagicForm(
///       controller: controller,
///       child: Column(
///         children: [
///           WFormInput(
///             controller: _email,
///             // Use rules() helper - controller is auto-injected
///             validator: rules([Required(), Email()], field: 'email'),
///           ),
///           if (controller.hasError('email'))
///             Text(controller.getError('email')!),
///           FilledButton(
///             onPressed: controller.isLoading ? null : _submit,
///             child: controller.isLoading
///                 ? CircularProgressIndicator()
///                 : Text('Submit'),
///           ),
///         ],
///       ),
///     );
///   }
/// }
/// ```
abstract class MagicStatefulViewState<
  T extends MagicController,
  V extends MagicStatefulView<T>
>
    extends State<V> {
  /// Cached controller instance.
  late final T _controller;

  /// Get the controller instance.
  T get controller => _controller;

  @override
  void initState() {
    super.initState();
    _controller = Magic.find<T>();
    // Auto-listen to controller changes (Laravel-like binding)
    _controller.addListener(_onControllerChanged);
    // Auto-clear validation errors when new view initializes (Laravel-like)
    _clearValidationErrors();
    // Run the controller's onInit lifecycle hook the first time it backs a
    // view (data bootstrap, table creation, initial load live here). Guarded by
    // `initialized` so a SimpleMagicController that already ran onInit in its
    // constructor is not initialized twice, and a singleton controller reused
    // across re-mounts runs onInit exactly once per lifetime.
    if (!_controller.initialized) {
      _controller.onInit();
    }
    onInit();
  }

  /// Clear error states if controller supports them.
  ///
  /// This prevents error states from one page showing on another page.
  /// Laravel does this automatically per-request; we do it per-view.
  ///
  /// Clears:
  /// - Validation errors (from [ValidatesRequests] mixin)
  /// - RxStatus error state (from [MagicStateMixin])
  ///
  /// Note: Clears are done silently (without notifyListeners) to avoid
  /// "setState called during build" errors during initState.
  void _clearValidationErrors() {
    // Check if controller implements HasValidationErrors (ValidatesRequests mixin)
    // Clear silently without triggering rebuild during initState
    if (_controller is ValidatesRequests) {
      (_controller as ValidatesRequests).validationErrors = {};
    }

    // Clear RxStatus error state if controller uses MagicStateMixin
    // Use notify: false to avoid setState during build
    if (_controller is MagicStateMixin) {
      final mixin = _controller as MagicStateMixin;
      if (mixin.isError) {
        mixin.setState(null, status: const RxStatus.empty(), notify: false);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A build always follows, and it reads the controller fresh.
    _rebuildPending = false;
    _listenToTickerMode();
  }

  @override
  void didUpdateWidget(covariant V oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A build always follows, and it reads the controller fresh.
    _rebuildPending = false;
  }

  @override
  void activate() {
    super.activate();
    // The element rebuilds on activation, and a move can land the view under
    // a different TickerMode.
    _rebuildPending = false;
    _listenToTickerMode();
  }

  @override
  void dispose() {
    onClose();
    // Remove listener to prevent memory leaks
    _controller.removeListener(_onControllerChanged);
    _tickerMode?.removeListener(_onTickerModeChanged);
    super.dispose();
  }

  /// The [TickerMode] values of this view's current location.
  ///
  /// Read through [TickerMode.getValuesNotifier] rather than
  /// [TickerMode.valuesOf] on purpose: the latter registers a dependency, and
  /// the view would then rebuild every time it is covered or uncovered even
  /// with nothing to show.
  ValueListenable<TickerModeData>? _tickerMode;

  /// Whether the controller notified while tickers were disabled and no build
  /// has read the controller since.
  bool _rebuildPending = false;

  void _listenToTickerMode() {
    final ValueListenable<TickerModeData> next = TickerMode.getValuesNotifier(
      context,
    );
    if (identical(next, _tickerMode)) return;

    _tickerMode?.removeListener(_onTickerModeChanged);
    next.addListener(_onTickerModeChanged);
    _tickerMode = next;
  }

  /// Called when controller notifies listeners.
  ///
  /// Rebuilds the view, unless its tickers are disabled. Flutter disables
  /// tickers for content it does not paint: a route under an opaque route
  /// ([Overlay]), an inactive go_router shell branch, an offstage
  /// [IndexedStack] child, a hero placeholder. A rebuild there produces frames
  /// nobody sees, so the notification is remembered instead and built once
  /// when the tickers come back. A view under a dialog, a bottom sheet or a
  /// popover keeps its tickers and rebuilds as before.
  ///
  /// The contract is the ticker mode, not visibility: an app that wraps a
  /// painted view in `TickerMode(enabled: false)` (to freeze its animations)
  /// also freezes its controller rebuilds until the tickers are re-enabled.
  void _onControllerChanged() {
    if (!mounted) return;

    if (_tickerMode?.value.enabled == false) {
      _rebuildPending = true;
      return;
    }
    setState(() {});
  }

  /// Builds the notifications deferred while tickers were disabled.
  void _onTickerModeChanged() {
    if (!_rebuildPending || !mounted || !_tickerMode!.value.enabled) return;

    _rebuildPending = false;
    setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Form Validation Helpers
  // ---------------------------------------------------------------------------

  /// Create a form validator with automatic controller injection.
  ///
  /// This is a convenience method that wraps [FormValidator.rules] and
  /// automatically passes the controller for server-side error checking.
  ///
  /// Use this inside [MagicForm] to get automatic server-side error display:
  ///
  /// ```dart
  /// MagicForm(
  ///   controller: controller,
  ///   child: WFormInput(
  ///     validator: rules([Required(), Email()], field: 'email'),
  ///   ),
  /// )
  /// ```
  ///
  /// When the API returns a 422 error and you call `setErrorsFromResponse()`,
  /// the form will automatically display the error under the corresponding field.
  String? Function(R?) rules<R>(
    List<Rule> validationRules, {
    required String field,
    Map<String, dynamic>? extraData,
  }) {
    return FormValidator.rules<R>(
      validationRules,
      field: field,
      extraData: extraData,
      controller: _controller,
    );
  }

  /// Called when view is initialized.
  ///
  /// Controller is available at this point.
  void onInit() {}

  /// Called when view is disposed.
  ///
  /// Use this to clean up resources like TextEditingController.
  void onClose() {}
}
