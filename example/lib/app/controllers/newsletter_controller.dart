import 'package:flutter/material.dart';
import 'package:fluttersdk_magic/fluttersdk_magic.dart';

import '../../resources/views/newsletter/newsletter_view.dart';

/// Newsletter Controller.
///
/// Demonstrates using Magic validation with Flutter's native Form widget.
class NewsletterController extends MagicController with MagicStateMixin<void> {
  /// Singleton accessor with lazy registration.
  static NewsletterController get instance =>
      Magic.findOrPut(NewsletterController.new);

  // ---------------------------------------------------------------------------
  // Views
  // ---------------------------------------------------------------------------

  /// Show Newsletter Signup Page
  Widget index() => const NewsletterView();

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Handle newsletter subscription.
  ///
  /// This demonstrates controller-side processing after form validation.
  Future<void> subscribe(String name, String email) async {
    setLoading();

    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));

      // Success!
      Magic.success('Subscribed!', 'Welcome to our newsletter, $name!');

      // Could navigate to a thank you page
      // MagicRoute.to('/newsletter/thanks');
    } catch (e) {
      Magic.error('Error', 'Failed to subscribe: $e');
    } finally {
      setEmpty();
    }
  }
}
