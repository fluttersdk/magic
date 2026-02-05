import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

// Test controller with MagicStateMixin
class TestController extends MagicController with MagicStateMixin<String> {
  TestController() {
    onInit();
  }
}

void main() {
  group('MagicStateMixin', () {
    late TestController controller;

    setUp(() {
      controller = TestController();
    });

    test('initial state is empty', () {
      expect(controller.isEmpty, isTrue);
      expect(controller.isLoading, isFalse);
      expect(controller.isSuccess, isFalse);
      expect(controller.isError, isFalse);
    });

    test('setLoading changes state to loading', () {
      controller.setLoading();
      expect(controller.isLoading, isTrue);
      expect(controller.isEmpty, isFalse);
    });

    test('setSuccess changes state to success with data', () {
      controller.setSuccess('test data');
      expect(controller.isSuccess, isTrue);
      expect(controller.rxState, equals('test data'));
    });

    test('setError changes state to error', () {
      controller.setError('error message');
      expect(controller.isError, isTrue);
      expect(controller.rxStatus.message, equals('error message'));
    });

    test('setEmpty changes state to empty', () {
      controller.setSuccess('data');
      controller.setEmpty();
      expect(controller.isEmpty, isTrue);
      expect(controller.rxState, isNull);
    });

    test('error state can be checked and cleared', () {
      // Set error state
      controller.setError('Login failed');

      // Verify error state is set
      expect(controller.isError, isTrue);
      expect(controller.rxStatus.message, equals('Login failed'));

      // Clear error by setting empty
      controller.setEmpty();

      // Verify error state is cleared
      expect(controller.isError, isFalse);
      expect(controller.isEmpty, isTrue);
    });

    test('error state persists until explicitly cleared', () {
      controller.setError('Persistent error');

      // Error should persist after multiple checks
      expect(controller.isError, isTrue);
      expect(controller.isError, isTrue);
      expect(controller.rxStatus.message, equals('Persistent error'));

      // Only setEmpty/setLoading/setSuccess should clear it
      expect(controller.isError, isTrue);
    });
  });

  group('MagicController lifecycle', () {
    test('onInit is called during construction', () {
      final controller = TestController();
      expect(controller.initialized, isTrue);
    });

    test('dispose sets isDisposed to true', () {
      final controller = TestController();
      expect(controller.isDisposed, isFalse);
      controller.dispose();
      expect(controller.isDisposed, isTrue);
    });
  });
}
