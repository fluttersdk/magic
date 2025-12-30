import 'package:flutter/widgets.dart';

import '../concerns/validates_requests.dart';
import '../foundation/magic.dart';
import '../http/magic_controller.dart';
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
abstract class MagicStatefulViewState<T extends MagicController,
    V extends MagicStatefulView<T>> extends State<V> {
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
    onInit();
  }

  /// Clear validation errors if controller supports it.
  ///
  /// This prevents validation errors from one page showing on another page.
  /// Laravel does this automatically per-request; we do it per-view.
  void _clearValidationErrors() {
    // Check if controller implements HasValidationErrors (ValidatesRequests mixin)
    if (_controller is HasValidationErrors) {
      (_controller as HasValidationErrors).clearErrors();
    }
  }

  @override
  void dispose() {
    onClose();
    // Remove listener to prevent memory leaks
    _controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  /// Called when controller notifies listeners.
  /// Triggers a rebuild of this view.
  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
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
