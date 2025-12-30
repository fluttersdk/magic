import 'package:flutter/material.dart';
import 'package:fluttersdk_magic/fluttersdk_magic.dart';

import '../../../app/controllers/auth_controller.dart';

/// Register View.
///
/// Validation rules are defined here in the View using FormValidator.rules().
/// Controller only receives validated data and handles business logic.
class RegisterView extends MagicStatefulView<AuthController> {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState
    extends MagicStatefulViewState<AuthController, RegisterView> {
  // Form key for native Flutter Form validation
  final _formKey = GlobalKey<FormState>();

  // Input controllers
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  bool _terms = false;

  @override
  void onClose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
  }

  Future<void> _submit() async {
    // Validate form first using native Form validation
    if (!_formKey.currentState!.validate()) {
      return; // Form has errors, stop here
    }

    // Form is valid, send clean data to controller
    await controller.attemptRegister(
      name: _name.text.trim(),
      email: _email.text.trim(),
      password: _password.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return controller.renderState(
      (_) => _buildForm(),
      onLoading: _buildForm(),
      onEmpty: _buildForm(),
      onError: (msg) => _buildForm(errorMessage: msg),
    );
  }

  Widget _buildForm({String? errorMessage}) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: WDiv(
          className: 'flex flex-col items-center p-6 gap-6',
          children: [
            // Header
            _buildHeader(),

            // Global error message
            if (errorMessage != null)
              WDiv(
                className:
                    'w-full max-w-sm p-3 bg-red-50 border border-red-200 rounded-lg',
                child: WText(errorMessage, className: 'text-red-600 text-sm'),
              ),

            // Form Fields
            WDiv(
              className: 'flex flex-col w-full max-w-sm gap-4',
              children: [
                // Name Field
                WFormInput(
                  controller: _name,
                  label: 'Full Name',
                  placeholder: 'Enter your name',
                  className:
                      'w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 error:border-red-500',
                  validator: FormValidator.rules([
                    Required(),
                    Min(2),
                  ], field: 'name'),
                ),

                // Email Field
                WFormInput(
                  controller: _email,
                  type: InputType.email,
                  label: 'Email',
                  placeholder: 'you@example.com',
                  className:
                      'w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 error:border-red-500',
                  validator: FormValidator.rules([
                    Required(),
                    Email(),
                  ], field: 'email'),
                ),

                // Password Field
                WFormInput(
                  controller: _password,
                  type: InputType.password,
                  label: 'Password',
                  placeholder: 'At least 8 characters',
                  className:
                      'w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 error:border-red-500',
                  validator: FormValidator.rules([
                    Required(),
                    Min(8),
                  ], field: 'password'),
                ),

                // Password Confirmation Field
                WFormInput(
                  controller: _passwordConfirm,
                  type: InputType.password,
                  label: 'Confirm Password',
                  placeholder: 'Repeat your password',
                  className:
                      'w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 error:border-red-500',
                  validator: FormValidator.rules(
                    [Required(), Same('password')],
                    field: 'password confirmation',
                    extraData: {'password': _password.text},
                  ),
                ),

                // Terms Checkbox - using WFormCheckbox with form validation
                WFormCheckbox(
                  value: _terms,
                  onChanged: (v) => setState(() => _terms = v),
                  className:
                      'w-5 h-5 rounded border border-gray-300 checked:bg-blue-500 error:border-red-500',
                  label: WText(
                    'I agree to the Terms of Service and Privacy Policy',
                    className: 'text-gray-700 text-sm',
                  ),
                  validator: (value) =>
                      value != true ? 'You must agree to the terms' : null,
                ),

                // Submit Button
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: controller.isLoading ? null : _submit,
                    child: controller.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Create Account'),
                  ),
                ),

                // Login Link
                TextButton(
                  onPressed: () => MagicRoute.to('/auth/login'),
                  child: const Text('Already have an account? Sign In'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return WDiv(
      className: 'flex flex-col items-center gap-2',
      children: [
        WIcon(Icons.person_add, className: 'text-blue-600 text-6xl'),
        WText('Create Account', className: 'text-2xl font-bold text-gray-900'),
        WText('Join the Magic App community', className: 'text-gray-500'),
      ],
    );
  }
}
