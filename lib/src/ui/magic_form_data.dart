import 'package:flutter/material.dart';

import '../concerns/validates_requests.dart';
import '../http/magic_controller.dart';

/// Centralized form data management for Magic framework.
///
/// `MagicFormData` provides a Laravel-style approach to form handling with
/// automatic type inference from initial values:
/// - `String` values → `TextEditingController`
/// - `bool` values → `ValueNotifier<bool>`
/// - Other values → `ValueNotifier<T>`
///
/// ## Usage
///
/// ```dart
/// class _RegisterViewState extends MagicStatefulViewState<AuthController, RegisterView> {
///   late final form = MagicFormData({
///     'name': 'John Doe',          // String → TextEditingController
///     'email': '',                  // String → TextEditingController
///     'accept_terms': false,        // bool → ValueNotifier<bool>
///     'avatar': null as MagicFile?, // MagicFile? → ValueNotifier
///   }, controller: controller);
///
///   @override
///   void onClose() => form.dispose();
///
///   @override
///   Widget build(BuildContext context) {
///     return MagicForm(
///       formData: form,
///       child: Column(
///         children: [
///           WFormInput(
///             controller: form['email'],
///             validator: rules([Required(), Email()], field: 'email'),
///           ),
///           WFormCheckbox(
///             value: form.value<bool>('accept_terms'),
///             onChanged: (value) => form.setValue('accept_terms', value),
///             label: WText(
///               trans('fields.accept_terms'),
///               className: 'text-gray-300 hover:text-gray-400 ml-1',
///             ),
///           ),
///         ],
///       ),
///     );
///   }
///
///   void _submit() {
///     if (!form.validate()) return;
///     controller.register(form.data);
///   }
/// }
/// ```
class MagicFormData {
  /// Internal form key for validation.
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  /// Internal map of text field names to their controllers.
  final Map<String, TextEditingController> _textControllers = {};

  /// Internal map of value field names to their notifiers.
  final Map<String, ValueNotifier<dynamic>> _valueNotifiers = {};

  /// The controller that manages validation errors.
  final MagicController? controller;

  /// Create a new MagicFormData instance with type-inferred fields.
  ///
  /// Field types are automatically inferred from initial values:
  /// - `String` → TextEditingController
  /// - `bool`, `MagicFile`, etc. → ValueNotifier<T>
  ///
  /// ```dart
  /// final form = MagicFormData({
  ///   'name': 'John Doe',
  ///   'email': '',
  ///   'accept_terms': false,
  ///   'avatar': null as MagicFile?,
  /// }, controller: controller);
  /// ```
  MagicFormData(Map<String, dynamic> fields, {this.controller}) {
    for (final entry in fields.entries) {
      final field = entry.key;
      final value = entry.value;

      if (value is String) {
        // String → TextEditingController
        _textControllers[field] = TextEditingController(text: value);

        // Auto-clear validation error when user types
        if (controller != null && controller is ValidatesRequests) {
          _textControllers[field]!.addListener(() {
            (controller as ValidatesRequests).clearFieldError(field);
          });
        }
      } else {
        // Other types → ValueNotifier<dynamic>
        _valueNotifiers[field] = ValueNotifier<dynamic>(value);

        // Auto-clear validation error when value changes
        if (controller != null && controller is ValidatesRequests) {
          _valueNotifiers[field]!.addListener(() {
            (controller as ValidatesRequests).clearFieldError(field);
          });
        }
      }
    }
  }

  /// Validate the form.
  ///
  /// Returns `true` if form is valid.
  bool validate() {
    // Clear server errors before validation
    if (controller != null && controller is ValidatesRequests) {
      (controller as ValidatesRequests).clearErrors();
    }
    return formKey.currentState?.validate() ?? false;
  }

  /// Validate the form and return the data if valid.
  ///
  /// Returns an empty map if form is invalid.
  Map<String, dynamic> validated() {
    if (!validate()) return {};
    return data;
  }

  /// Get the TextEditingController for a text field.
  ///
  /// ```dart
  /// WFormInput(
  ///   controller: form['email'],
  ///   validator: rules([Required(), Email()], field: 'email'),
  /// )
  /// ```
  TextEditingController operator [](String field) {
    assert(
      _textControllers.containsKey(field),
      'Text field "$field" not found. Use value<T>("$field") for non-text fields.',
    );
    return _textControllers[field]!;
  }

  /// Get a typed value for a non-text field.
  ///
  /// ```dart
  /// form.value<bool>('accept_terms')
  /// ```
  T value<T>(String field) {
    assert(
      _valueNotifiers.containsKey(field),
      'Value field "$field" not found. Use form["$field"] for text fields.',
    );
    return _valueNotifiers[field]!.value as T;
  }

  /// Set a typed value for a non-text field.
  ///
  /// ```dart
  /// form.setValue('accept_terms', true);
  /// ```
  void setValue<T>(String field, T newValue) {
    assert(
      _valueNotifiers.containsKey(field),
      'Value field "$field" not found.',
    );
    _valueNotifiers[field]!.value = newValue;
  }

  /// Get all form data as a Map.
  ///
  /// Text values are trimmed automatically.
  ///
  /// ```dart
  /// controller.register(form.data);
  /// // {'name': 'John', 'email': 'john@test.com', 'accept_terms': true, ...}
  /// ```
  Map<String, dynamic> get data {
    final result = <String, dynamic>{};

    for (final entry in _textControllers.entries) {
      result[entry.key] = entry.value.text.trim();
    }

    for (final entry in _valueNotifiers.entries) {
      result[entry.key] = entry.value.value;
    }

    return result;
  }

  /// Get a specific text field value (trimmed).
  String get(String field) {
    assert(
      _textControllers.containsKey(field),
      'Text field "$field" not found.',
    );
    return _textControllers[field]!.text.trim();
  }

  /// Set a specific text field value.
  void set(String field, String textValue) {
    assert(
      _textControllers.containsKey(field),
      'Text field "$field" not found.',
    );
    _textControllers[field]!.text = textValue;
  }

  /// Dispose all controllers and notifiers.
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    for (final notifier in _valueNotifiers.values) {
      notifier.dispose();
    }
    _textControllers.clear();
    _valueNotifiers.clear();
  }
}
