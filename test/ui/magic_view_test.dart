import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

// Test controller with both ValidatesRequests and MagicStateMixin
class TestAuthController extends MagicController
    with ValidatesRequests, MagicStateMixin<String> {
  TestAuthController() {
    onInit();
  }

  /// Helper to set validation errors directly for testing.
  void setValidationErrors(Map<String, String> errors) {
    validationErrors = errors;
    notifyListeners();
  }
}

// Simple test view
class TestLoginView extends MagicStatefulView<TestAuthController> {
  const TestLoginView({super.key});

  @override
  State<TestLoginView> createState() => _TestLoginViewState();
}

class _TestLoginViewState
    extends MagicStatefulViewState<TestAuthController, TestLoginView> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Error: ${controller.isError}'),
        Text('ValidationErrors: ${controller.validationErrors.length}'),
        if (controller.isError)
          Text('Error Message: ${controller.rxStatus.message}'),
      ],
    );
  }
}

// A view that validates an empty `url` through its own `rules` helper.
class _RulesView extends MagicStatefulView<TestAuthController> {
  const _RulesView();

  @override
  State<_RulesView> createState() => _RulesViewState();
}

class _RulesViewState
    extends MagicStatefulViewState<TestAuthController, _RulesView> {
  @override
  Widget build(BuildContext context) {
    final String? error = rules<String>(
      [Required()],
      field: 'url',
      attribute: 'Server address',
      messages: {'required': 'Enter the :attribute.'},
    )('');

    return Text(error ?? 'valid');
  }
}

void main() {
  group('MagicStatefulViewState.rules', () {
    setUp(() {
      Magic.flush();
      Magic.put<TestAuthController>(TestAuthController());
    });

    tearDown(() {
      Magic.flush();
    });

    testWidgets('forwards the field name and the message override', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: _RulesView()));

      expect(find.text('Enter the Server address.'), findsOneWidget);
    });
  });

  group('MagicStatefulViewState error clearing', () {
    late TestAuthController controller;

    setUp(() {
      // Clear any existing registrations
      Magic.flush();
      controller = TestAuthController();
      Magic.put<TestAuthController>(controller);
    });

    tearDown(() {
      Magic.flush();
    });

    testWidgets('clears validation errors when view initializes', (
      tester,
    ) async {
      // Set validation errors on controller
      controller.setValidationErrors({'email': 'Email is required'});
      expect(controller.validationErrors.isNotEmpty, isTrue);

      // Build the view
      await tester.pumpWidget(
        MaterialApp(
          home: WindTheme(data: WindThemeData(), child: const TestLoginView()),
        ),
      );

      // Validation errors should be cleared on view init
      expect(controller.validationErrors.isEmpty, isTrue);
    });

    testWidgets('clears RxStatus error state when view initializes', (
      tester,
    ) async {
      // Set error state on controller (simulating a failed login)
      controller.setError('Invalid credentials');
      expect(controller.isError, isTrue);
      expect(controller.rxStatus.message, equals('Invalid credentials'));

      // Build the view (simulating navigation to a new page)
      await tester.pumpWidget(
        MaterialApp(
          home: WindTheme(data: WindThemeData(), child: const TestLoginView()),
        ),
      );

      // RxStatus error should be cleared on view init
      // This is the NEW behavior we're implementing
      expect(controller.isError, isFalse);
      expect(controller.isEmpty, isTrue);
    });

    testWidgets('clears both validation and RxStatus errors on view init', (
      tester,
    ) async {
      // Set both types of errors
      controller.validationErrors = {'email': 'Email is required'};
      controller.setError('Server error');

      expect(controller.validationErrors.isNotEmpty, isTrue);
      expect(controller.isError, isTrue);

      // Build the view
      await tester.pumpWidget(
        MaterialApp(
          home: WindTheme(data: WindThemeData(), child: const TestLoginView()),
        ),
      );

      // Both should be cleared
      expect(controller.validationErrors.isEmpty, isTrue);
      expect(controller.isError, isFalse);
    });

    testWidgets('does not clear success state on view init', (tester) async {
      // Set success state
      controller.setSuccess('User logged in');
      expect(controller.isSuccess, isTrue);
      expect(controller.rxState, equals('User logged in'));

      // Build the view
      await tester.pumpWidget(
        MaterialApp(
          home: WindTheme(data: WindThemeData(), child: const TestLoginView()),
        ),
      );

      // Success state should remain
      expect(controller.isSuccess, isTrue);
      expect(controller.rxState, equals('User logged in'));
    });

    testWidgets('does not clear loading state on view init', (tester) async {
      // Set loading state
      controller.setLoading();
      expect(controller.isLoading, isTrue);

      // Build the view
      await tester.pumpWidget(
        MaterialApp(
          home: WindTheme(data: WindThemeData(), child: const TestLoginView()),
        ),
      );

      // Loading state should remain
      expect(controller.isLoading, isTrue);
    });
  });
}
