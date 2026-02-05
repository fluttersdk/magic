import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../app/controllers/auth_controller.dart';

/// Login View.
///
/// Validation rules are defined here in the View using FormValidator.rules().
/// Controller only receives validated data and handles business logic.
class LoginView extends MagicStatefulView<AuthController> {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState
    extends MagicStatefulViewState<AuthController, LoginView> {
  // Form key for native Flutter Form validation
  final _formKey = GlobalKey<FormState>();

  // Input controllers
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void onClose() {
    _email.dispose();
    _password.dispose();
  }

  Future<void> _submit() async {
    // Validate form first using native Form validation
    if (!_formKey.currentState!.validate()) {
      return; // Form has errors, stop here
    }

    // Form is valid, send clean data to controller
    await controller.attemptLogin(
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

            // Global error message (from controller - e.g., "Invalid credentials")
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
                // Email Field
                WFormInput(
                  controller: _email,
                  type: InputType.email,
                  label: 'Email',
                  placeholder: 'you@example.com',
                  className:
                      'w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 error:border-red-500 error:ring-red-200',
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
                  placeholder: 'Enter your password',
                  className:
                      'w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 error:border-red-500 error:ring-red-200',
                  validator: FormValidator.rules([
                    Required(),
                    Min(6),
                  ], field: 'password'),
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
                        : const Text('Sign In'),
                  ),
                ),

                // Register Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    TextButton(
                      onPressed: () => MagicRoute.to('/auth/register'),
                      child: const Text('Register'),
                    ),
                  ],
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
        WIcon(Icons.lock_person, className: 'text-blue-600 text-6xl'),
        WText('Welcome Back', className: 'text-2xl font-bold text-gray-900'),
        WText('Sign in to continue to Magic App', className: 'text-gray-500'),
      ],
    );
  }
}
