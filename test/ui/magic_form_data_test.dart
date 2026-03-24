import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// Minimal controller for test isolation.
class _TestController extends MagicController
    with MagicStateMixin<bool>, ValidatesRequests {
  _TestController() {
    onInit();
  }
}

void main() {
  group('MagicFormData.isProcessing', () {
    late _TestController controller;
    late MagicFormData form;

    setUp(() {
      controller = _TestController();
      form = MagicFormData({'name': '', 'email': ''}, controller: controller);
    });

    tearDown(() {
      form.dispose();
      controller.dispose();
    });

    test('defaults to false', () {
      expect(form.isProcessing, isFalse);
    });

    test('processingListenable is a ValueListenable<bool>', () {
      expect(form.processingListenable, isA<ValueListenable<bool>>());
      expect(form.processingListenable.value, isFalse);
    });
  });

  group('MagicFormData.process()', () {
    late _TestController controller;
    late MagicFormData form;

    setUp(() {
      controller = _TestController();
      form = MagicFormData({'name': '', 'email': ''}, controller: controller);
    });

    tearDown(() {
      form.dispose();
      controller.dispose();
    });

    test('sets isProcessing to true during action', () async {
      bool? wasTrueDuringAction;

      await form.process(() async {
        wasTrueDuringAction = form.isProcessing;
        return true;
      });

      expect(wasTrueDuringAction, isTrue);
      expect(form.isProcessing, isFalse);
    });

    test('returns the action result on success', () async {
      final result = await form.process(() async => 42);

      expect(result, equals(42));
    });

    test('resets isProcessing to false after success', () async {
      await form.process(() async => true);

      expect(form.isProcessing, isFalse);
    });

    test('resets isProcessing to false after exception', () async {
      try {
        await form.process(() async {
          throw Exception('API failure');
        });
      } catch (_) {
        // Expected.
      }

      expect(form.isProcessing, isFalse);
    });

    test('rethrows exception from action', () async {
      expect(
        () => form.process(() async {
          throw Exception('API failure');
        }),
        throwsA(isA<Exception>()),
      );
    });

    test('throws StateError when already processing', () async {
      final completer = Completer<bool>();

      // 1. Start a long-running process.
      final first = form.process(() => completer.future);

      // 2. Attempt concurrent process — should throw.
      expect(() => form.process(() async => true), throwsA(isA<StateError>()));

      // 3. Complete the first process.
      completer.complete(true);
      await first;
    });

    test('notifies processingListenable listeners', () async {
      final values = <bool>[];
      form.processingListenable.addListener(
        () => values.add(form.processingListenable.value),
      );

      await form.process(() async => true);

      // Should have notified: true (start), false (end).
      expect(values, equals([true, false]));
    });
  });

  group('MagicFormData.process() with controller', () {
    late _TestController controller;
    late MagicFormData profileForm;
    late MagicFormData passwordForm;

    setUp(() {
      controller = _TestController();
      profileForm = MagicFormData({
        'name': '',
        'email': '',
      }, controller: controller);
      passwordForm = MagicFormData({
        'current_password': '',
        'password': '',
      }, controller: controller);
    });

    tearDown(() {
      profileForm.dispose();
      passwordForm.dispose();
      controller.dispose();
    });

    test('one form processing does not affect another form', () async {
      final completer = Completer<bool>();

      // 1. Start processing on profileForm.
      final future = profileForm.process(() => completer.future);

      // 2. Verify only profileForm is processing.
      expect(profileForm.isProcessing, isTrue);
      expect(passwordForm.isProcessing, isFalse);

      // 3. Complete.
      completer.complete(true);
      await future;

      expect(profileForm.isProcessing, isFalse);
    });
  });

  group('MagicFormData.dispose() with processing', () {
    late _TestController controller;
    late MagicFormData form;

    setUp(() {
      controller = _TestController();
      form = MagicFormData({'name': ''}, controller: controller);
    });

    tearDown(() {
      controller.dispose();
    });

    test('dispose cleans up processing notifier', () {
      // 1. Add a listener to prove the notifier is alive.
      // ignore: unused_local_variable
      var notified = false;
      form.processingListenable.addListener(() => notified = true);

      // 2. Dispose.
      form.dispose();

      // 3. Verify the notifier no longer fires (disposed).
      //    FlutterError is thrown when accessing disposed notifier.
      expect(
        () => (form.processingListenable as ValueNotifier<bool>).value = true,
        throwsA(isA<FlutterError>()),
      );
    });
  });

  group('MagicFormData backward compatibility', () {
    late _TestController controller;
    late MagicFormData form;

    setUp(() {
      controller = _TestController();
      form = MagicFormData({
        'name': 'John',
        'email': '',
        'accept_terms': false,
      }, controller: controller);
    });

    tearDown(() {
      form.dispose();
      controller.dispose();
    });

    test('text field operator[] still works', () {
      expect(form['name'].text, equals('John'));
      expect(form['email'].text, equals(''));
    });

    test('get() and set() still work', () {
      form.set('name', 'Jane');
      expect(form.get('name'), equals('Jane'));
    });

    test('value<T>() still works for non-text fields', () {
      expect(form.value<bool>('accept_terms'), isFalse);
    });

    test('data getter still returns all fields', () {
      form.set('name', 'Jane');
      final data = form.data;

      expect(data['name'], equals('Jane'));
      expect(data['email'], equals(''));
      expect(data['accept_terms'], equals(false));
    });

    test('fieldNames includes all registered fields', () {
      expect(form.fieldNames, containsAll(['name', 'email', 'accept_terms']));
    });
  });
}
