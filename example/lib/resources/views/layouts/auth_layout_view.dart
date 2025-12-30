import 'package:flutter/material.dart';
import 'package:fluttersdk_magic/fluttersdk_magic.dart';
import '../../../../app/controllers/auth_controller.dart';

class AuthLayoutView extends MagicView<AuthController> {
  final Widget child;
  final String? title;

  const AuthLayoutView({super.key, required this.child, this.title});

  @override
  Widget build(BuildContext context) {
    // Lazily register AuthController if used here (though routes usually do it)
    // Actually, MagicView does Magic.find, so we rely on Route to register or explicit registration.
    // However, layouts in ShellRoute might build BEFORE page route?
    // Let's ensure registration via instance check if needed, but standard MagicView usage assumes registration.
    // Since AuthController uses lazy singleton, we could force access it, but MagicView does `Magic.find`.
    // If AuthLayoutView is built before any page accesses AuthController.instance, `find` will fail.
    // Fix: Use AuthController.instance in build or init?
    // Or just manually put if not registered?
    if (!Magic.isRegistered<AuthController>()) {
      Magic.put(AuthController());
    }

    return Scaffold(
      appBar: title != null ? AppBar(title: Text(title!)) : null,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Example interaction with controller
          Magic.toast('FAB Clicked');
        },
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
