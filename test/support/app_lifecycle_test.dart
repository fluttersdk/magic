import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/support/app_lifecycle.dart';

void main() {
  // Runs first and deliberately never initialises a binding: a provider's
  // register() constructs a service before any binding exists, and
  // AppLifecycle.states() has to survive that unlisted-to.
  test('states() does not throw before any binding is initialised', () {
    expect(AppLifecycle.states, returnsNormally);
  });

  group('once a binding exists', () {
    setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

    test('a listener receives the state the binding reports', () async {
      final List<AppLifecycleState> received = <AppLifecycleState>[];
      final StreamSubscription<AppLifecycleState> subscription =
          AppLifecycle.states().listen(received.add);
      addTearDown(subscription.cancel);

      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );
      await Future<void>.delayed(Duration.zero);

      expect(received, <AppLifecycleState>[AppLifecycleState.paused]);
    });

    test('cancelling the subscription stops further delivery', () async {
      final List<AppLifecycleState> received = <AppLifecycleState>[];
      final StreamSubscription<AppLifecycleState> subscription =
          AppLifecycle.states().listen(received.add);

      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await Future<void>.delayed(Duration.zero);

      expect(received, <AppLifecycleState>[AppLifecycleState.paused]);
    });

    test('a second listen receives its own next state', () async {
      final List<AppLifecycleState> first = <AppLifecycleState>[];
      final List<AppLifecycleState> second = <AppLifecycleState>[];

      final StreamSubscription<AppLifecycleState> firstSubscription =
          AppLifecycle.states().listen(first.add);
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );
      await Future<void>.delayed(Duration.zero);
      await firstSubscription.cancel();

      final StreamSubscription<AppLifecycleState> secondSubscription =
          AppLifecycle.states().listen(second.add);
      addTearDown(secondSubscription.cancel);

      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await Future<void>.delayed(Duration.zero);

      expect(first, <AppLifecycleState>[AppLifecycleState.paused]);
      expect(second, <AppLifecycleState>[AppLifecycleState.resumed]);
    });
  });
}
