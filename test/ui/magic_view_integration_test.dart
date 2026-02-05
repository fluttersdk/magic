import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

// Test controller with both ValidatesRequests and MagicStateMixin
class TestAuthController extends MagicController
    with ValidatesRequests, MagicStateMixin<String> {
  TestAuthController() {
    onInit();
  }
}

// Login view
class TestLoginView extends MagicStatefulView<TestAuthController> {
  const TestLoginView({super.key});

  @override
  State<TestLoginView> createState() => _TestLoginViewState();
}

class _TestLoginViewState
    extends MagicStatefulViewState<TestAuthController, TestLoginView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Column(
        children: [
          Text('Login Error: ${controller.isError}'),
          if (controller.isError)
            Text('Error Message: ${controller.rxStatus.message}'),
          ElevatedButton(
            key: const Key('login_button'),
            onPressed: () {
              // Simulate failed login
              controller.setError('Invalid credentials');
            },
            child: const Text('Login'),
          ),
          ElevatedButton(
            key: const Key('go_to_register'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TestRegisterView()),
              );
            },
            child: const Text('Go to Register'),
          ),
        ],
      ),
    );
  }
}

// Register view
class TestRegisterView extends MagicStatefulView<TestAuthController> {
  const TestRegisterView({super.key});

  @override
  State<TestRegisterView> createState() => _TestRegisterViewState();
}

class _TestRegisterViewState
    extends MagicStatefulViewState<TestAuthController, TestRegisterView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Column(
        children: [
          Text('Register Error: ${controller.isError}'),
          ElevatedButton(
            key: const Key('go_back'),
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }
}

void main() {
  group('MagicStatefulView navigation integration', () {
    late TestAuthController controller;

    setUp(() {
      Magic.flush();
      controller = TestAuthController();
      Magic.put<TestAuthController>(controller);
    });

    tearDown(() {
      Magic.flush();
    });

    testWidgets('error state is cleared when navigating to new view',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WindTheme(
            data: WindThemeData(),
            child: const TestLoginView(),
          ),
        ),
      );

      // Verify initial state is not error
      expect(find.text('Login Error: false'), findsOneWidget);

      // Trigger failed login
      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pump();

      // Verify error state is set
      expect(find.text('Login Error: true'), findsOneWidget);
      expect(find.text('Error Message: Invalid credentials'), findsOneWidget);

      // Navigate to register view
      await tester.tap(find.byKey(const Key('go_to_register')));
      await tester.pumpAndSettle();

      // Error should be cleared when new view initializes
      expect(find.text('Register Error: false'), findsOneWidget);
    });

    testWidgets('error state remains cleared after navigating back',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WindTheme(
            data: WindThemeData(),
            child: const TestLoginView(),
          ),
        ),
      );

      // Set error and navigate away
      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pump();
      expect(controller.isError, isTrue);

      // Navigate to register - this clears the error
      await tester.tap(find.byKey(const Key('go_to_register')));
      await tester.pumpAndSettle();

      // Error should be cleared by register view init
      expect(controller.isError, isFalse);

      // Navigate back to login
      await tester.tap(find.byKey(const Key('go_back')));
      await tester.pumpAndSettle();

      // Controller state should still be cleared
      // Note: The UI text may not update immediately since we clear with notify: false
      // to avoid "setState during build" errors. The important thing is the controller
      // state is correct - UI will update on next interaction.
      expect(controller.isError, isFalse);
    });

    testWidgets('validation errors are also cleared on navigation',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WindTheme(
            data: WindThemeData(),
            child: const TestLoginView(),
          ),
        ),
      );

      // Set validation errors
      controller.validationErrors = {'email': 'Email is required'};
      expect(controller.validationErrors.isNotEmpty, isTrue);

      // Navigate to register
      await tester.tap(find.byKey(const Key('go_to_register')));
      await tester.pumpAndSettle();

      // Validation errors should be cleared
      expect(controller.validationErrors.isEmpty, isTrue);
    });
  });
}
