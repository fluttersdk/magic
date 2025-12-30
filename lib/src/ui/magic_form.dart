import 'package:flutter/material.dart';

import '../concerns/validates_requests.dart';
import '../http/magic_controller.dart';
import 'magic_form_data.dart';

/// A Form widget that integrates with Magic's validation system.
///
/// `MagicForm` wraps Flutter's [Form] widget and automatically manages
/// `autovalidateMode` based on the controller's server-side validation errors.
///
/// ## Usage with MagicFormData (Recommended)
///
/// ```dart
/// class _RegisterViewState extends MagicStatefulViewState<AuthController, RegisterView> {
///   late final form = MagicFormData({
///     'email': '',
///     'password': '',
///     'accept_terms': false,
///   }, controller: controller);
///
///   @override
///   Widget build(BuildContext context) {
///     return MagicForm(
///       formData: form,  // Auto-extracts formKey and controller
///       child: Column(
///         children: [
///           form.field('email', rules: [Required(), Email()]),
///           form.checkbox('accept_terms'),
///           WButton(
///             onTap: () {
///               if (form.validate()) {
///                 controller.register(form.data);
///               }
///             },
///             child: Text('Submit'),
///           ),
///         ],
///       ),
///     );
///   }
/// }
/// ```
///
/// ## Usage with explicit formKey (Legacy)
///
/// ```dart
/// MagicForm(
///   formKey: _formKey,
///   controller: controller,
///   child: Column(...),
/// )
/// ```
class MagicForm extends StatelessWidget {
  /// The form data manager (recommended).
  ///
  /// When provided, `formKey` and `controller` are automatically extracted.
  final MagicFormData? formData;

  /// The form key for accessing form state.
  ///
  /// Optional when `formData` is provided.
  final GlobalKey<FormState>? formKey;

  /// The controller that may contain server-side validation errors.
  ///
  /// Optional when `formData` is provided.
  final MagicController? controller;

  /// The form content.
  final Widget child;

  /// Optional explicit autovalidate mode.
  ///
  /// If not provided, the form will automatically use:
  /// - `AutovalidateMode.always` when controller has errors
  /// - `AutovalidateMode.disabled` otherwise
  final AutovalidateMode? autovalidateMode;

  /// Called when one of the form fields changes.
  final VoidCallback? onChanged;

  /// Enables the form to veto attempts by the user to dismiss the
  /// [ModalRoute] that contains the form.
  final WillPopCallback? onWillPop;

  /// Restoration ID to save and restore the state of the [Form].
  final String? restorationId;

  /// Creates a MagicForm.
  ///
  /// Either `formData` or both `formKey` and `controller` must be provided.
  const MagicForm({
    super.key,
    this.formData,
    this.formKey,
    this.controller,
    required this.child,
    this.autovalidateMode,
    this.onChanged,
    this.onWillPop,
    this.restorationId,
  }) : assert(
          formData != null || controller != null,
          'Either formData or controller must be provided',
        );

  @override
  Widget build(BuildContext context) {
    // Extract formKey and controller from formData if provided
    final effectiveFormKey = formData?.formKey ?? formKey;
    final effectiveController = formData?.controller ?? controller;

    // Determine autovalidate mode
    AutovalidateMode effectiveMode =
        autovalidateMode ?? AutovalidateMode.disabled;

    // If controller has server-side errors, force validation to show them
    if (effectiveController is ValidatesRequests) {
      final validator = effectiveController as ValidatesRequests;
      if (validator.hasErrors) {
        effectiveMode = AutovalidateMode.always;
      }
    }

    return Form(
      key: effectiveFormKey,
      autovalidateMode: effectiveMode,
      onChanged: onChanged,
      onWillPop: onWillPop,
      child: child,
    );
  }
}
