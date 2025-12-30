import 'package:flutter/material.dart';
import 'package:fluttersdk_magic/fluttersdk_magic.dart';

import '../../../app/controllers/newsletter_controller.dart';

/// Newsletter Signup View.
///
/// Demonstrates using Magic validation rules with Flutter's native Form widget.
/// This pattern is familiar to Flutter developers who learned from
/// "Build a form with validation" Flutter cookbook.
class NewsletterView extends MagicStatefulView<NewsletterController> {
  const NewsletterView({super.key});

  @override
  State<NewsletterView> createState() => _NewsletterViewState();
}

class _NewsletterViewState
    extends MagicStatefulViewState<NewsletterController, NewsletterView> {
  // Flutter's native form key
  final _formKey = GlobalKey<FormState>();

  // Form field controllers
  final _name = TextEditingController();
  final _email = TextEditingController();

  @override
  void onClose() {
    _name.dispose();
    _email.dispose();
  }

  void _submit() {
    // Use Flutter's native form validation
    if (_formKey.currentState!.validate()) {
      // Form is valid! Call controller action
      controller.subscribe(_name.text.trim(), _email.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📬 Join Newsletter'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                const Icon(Icons.mail_outline, size: 80, color: Colors.indigo),
                const SizedBox(height: 16),
                const Text(
                  'Stay Updated!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Subscribe to our newsletter for the latest updates.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 32),

                // Name Field - Using Magic Rules with Flutter Form
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: 'Your Name',
                    hintText: 'Enter your name',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  // 🔥 Magic Rules with Flutter's validator!
                  validator: FormValidator.rules([
                    Required(),
                    Min(2),
                    Max(50),
                  ], field: 'name'),
                ),
                const SizedBox(height: 16),

                // Email Field - Using Magic Rules with Flutter Form
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'you@example.com',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  // 🔥 Magic Rules with Flutter's validator!
                  validator: FormValidator.rules([
                    Required(),
                    Email(),
                  ], field: 'email'),
                ),
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: controller.isLoading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: controller.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Subscribe Now',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Privacy note
                Text(
                  'We respect your privacy. Unsubscribe at any time.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
