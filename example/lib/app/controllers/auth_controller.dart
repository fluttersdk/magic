import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import '../../resources/views/auth/login_view.dart';
import '../../resources/views/auth/register_view.dart';
import '../middleware/ensure_authenticated.dart';

/// Authentication Controller.
///
/// Handles all authentication-related actions: login, register, logout.
/// Uses MagicStateMixin for state-based loading management.
///
/// Note: Validation rules are in Views using FormValidator.rules().
/// Controller receives pre-validated data and handles business logic only.
class AuthController extends MagicController with MagicStateMixin<void> {
  /// Singleton accessor with lazy registration.
  static AuthController get instance => Magic.findOrPut(AuthController.new);

  // ---------------------------------------------------------------------------
  // Views (Laravel-style: Controller returns Views)
  // ---------------------------------------------------------------------------

  /// Show Login Page
  Widget login() => const LoginView();

  /// Show Register Page
  Widget register() => const RegisterView();

  // ---------------------------------------------------------------------------
  // Actions (Handle pre-validated data)
  // ---------------------------------------------------------------------------

  /// Handle Login with pre-validated data.
  ///
  /// Validation is done in View using WFormInput + FormValidator.rules().
  /// This method receives clean, validated data only.
  Future<void> attemptLogin({
    required String email,
    required String password,
  }) async {
    setLoading();

    try {
      // Simulate API call
      await Future.delayed(const Duration(milliseconds: 500));

      // Mock: Check credentials (in real app, call Auth.attempt)
      if (email == 'test@test.com' && password == 'wrongpassword') {
        setError('Invalid email or password');
        return;
      }

      String token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
      await Vault.put('auth_token', token);
      Cache.put('user_email', email);

      EnsureAuthenticated.mockIsLoggedIn = true;
      Magic.snackbar('Success', 'Logged in successfully');
      MagicRoute.to('/user');
    } catch (e) {
      setError('Login failed: $e');
    } finally {
      setEmpty();
    }
  }

  /// Handle Register with pre-validated data.
  ///
  /// Validation is done in View using WFormInput + FormValidator.rules().
  /// This method receives clean, validated data only.
  Future<void> attemptRegister({
    required String name,
    required String email,
    required String password,
  }) async {
    setLoading();

    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));

      await Vault.put('auth_token', 'new_registered_token');
      Cache.put('user_email', email);
      Cache.put('user_name', name);

      EnsureAuthenticated.mockIsLoggedIn = true;
      Magic.snackbar('Success', 'Account created! Welcome.');
      MagicRoute.to('/dashboard');
    } catch (e) {
      setError('Registration failed: $e');
    } finally {
      setEmpty();
    }
  }

  /// Handle Logout.
  Future<void> logout() async {
    await Vault.delete('auth_token');
    Cache.forget('user_email');
    Cache.forget('user_name');

    EnsureAuthenticated.mockIsLoggedIn = false;
    Magic.snackbar('Success', 'Logged out successfully');
    MagicRoute.to('/auth/login');
  }
}
