import 'package:flutter/material.dart';
import 'package:fluttersdk_magic/fluttersdk_magic.dart';

import '../../resources/views/dashboard/index_view.dart';

/// Dashboard Controller - Laravel-style with actions returning views.
///
/// ## Usage
///
/// ```dart
/// MagicRoute.get('/dashboard', () => DashboardController.instance.index());
/// ```
class DashboardController extends MagicController
    with MagicStateMixin<Map<String, dynamic>> {
  /// Singleton accessor with lazy registration.
  static DashboardController get instance =>
      Magic.findOrPut(DashboardController.new);

  // ---------------------------------------------------------------------------
  // Actions (return Widget from resources/views)
  // ---------------------------------------------------------------------------

  /// GET /dashboard - Main dashboard view.
  Widget index() {
    if (isEmpty) {
      loadDashboard();
    }
    return DashboardIndexView(controller: this);
  }

  // ---------------------------------------------------------------------------
  // Business Logic
  // ---------------------------------------------------------------------------

  Future<void> loadDashboard() async {
    setLoading(); // <-- Laravel-style helper

    await Future.delayed(const Duration(seconds: 1));

    setSuccess({
      'totalUsers': 1234,
      'activeUsers': 567,
      'revenue': 45678.90,
      'orders': 89,
    }); // <-- Laravel-style helper
  }
}
