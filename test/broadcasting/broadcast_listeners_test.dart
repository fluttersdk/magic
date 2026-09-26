import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// What this pins: [BroadcastListeners] owns exactly one
/// [AuthChannelSubscription] per alias, no matter how many callbacks are
/// registered for it; a callback added after the alias is already subscribed
/// is wired straight onto the live channel rather than waiting on a resync
/// (`sync()` returns early once a channel's name has not changed); the last
/// callback for an event leaves the channel with nothing listening for it;
/// and one callback's exception never stops the next one in the fan-out.
void main() {
  late FakeBroadcastManager echo;

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    echo = Echo.fake();
    Log.fake();
  });

  tearDown(() {
    BroadcastListeners.reset();
    Echo.unfake();
    Log.unfake();
    MagicApp.reset();
    Magic.flush();
  });

  group('BroadcastListeners.channel + sync', () {
    test('an alias whose resolver returns null subscribes nothing', () async {
      BroadcastListeners.channel('team', () => null);

      await BroadcastListeners.sync();

      echo.assertNotSubscribed('private-teams.1');
    });

    test(
      'a listener added before the first sync is wired once sync subscribes',
      () async {
        BroadcastListeners.channel('team', () => 'teams.1');
        final List<BroadcastEvent> received = <BroadcastEvent>[];
        BroadcastListeners.add('team', 'check.recorded', received.add);

        echo.assertNotSubscribed('private-teams.1');

        await BroadcastListeners.sync();

        echo.assertListening('private-teams.1', 'check.recorded');
        echo.dispatch(
          'private-teams.1',
          'check.recorded',
          const <String, dynamic>{'id': '1'},
        );

        expect(received, hasLength(1));
      },
    );
  });

  group('BroadcastListeners.add', () {
    test('a new event on an already-subscribed alias is listened directly, '
        'without a resync', () async {
      BroadcastListeners.channel('team', () => 'teams.1');
      await BroadcastListeners.sync();

      final List<BroadcastEvent> received = <BroadcastEvent>[];
      BroadcastListeners.add('team', 'check.recorded', received.add);

      echo.assertListening('private-teams.1', 'check.recorded');
      echo.dispatch(
        'private-teams.1',
        'check.recorded',
        const <String, dynamic>{'id': '1'},
      );
      expect(received, hasLength(1));
    });

    test(
      'two callbacks on the same alias and event both run, in registration order',
      () async {
        BroadcastListeners.channel('team', () => 'teams.1');
        await BroadcastListeners.sync();

        final List<String> order = <String>[];
        BroadcastListeners.add(
          'team',
          'check.recorded',
          (_) => order.add('first'),
        );
        BroadcastListeners.add(
          'team',
          'check.recorded',
          (_) => order.add('second'),
        );

        echo.dispatch(
          'private-teams.1',
          'check.recorded',
          const <String, dynamic>{},
        );

        expect(order, <String>['first', 'second']);
      },
    );

    test('removing one callback keeps the other receiving', () async {
      BroadcastListeners.channel('team', () => 'teams.1');
      await BroadcastListeners.sync();

      int firstCount = 0;
      int secondCount = 0;
      final BroadcastListenerToken firstToken = BroadcastListeners.add(
        'team',
        'check.recorded',
        (_) => firstCount++,
      );
      BroadcastListeners.add('team', 'check.recorded', (_) => secondCount++);

      BroadcastListeners.remove(firstToken);

      echo.dispatch(
        'private-teams.1',
        'check.recorded',
        const <String, dynamic>{},
      );

      expect(firstCount, equals(0));
      expect(secondCount, equals(1));
      echo.assertListening('private-teams.1', 'check.recorded');
    });

    test(
      'removing the last callback for an event stops listening on the channel',
      () async {
        BroadcastListeners.channel('team', () => 'teams.1');
        await BroadcastListeners.sync();

        final BroadcastListenerToken token = BroadcastListeners.add(
          'team',
          'check.recorded',
          (_) {},
        );

        BroadcastListeners.remove(token);

        echo.assertNotListening('private-teams.1', 'check.recorded');
      },
    );

    test(
      'an exception in one handler is logged and does not stop the next handler',
      () async {
        BroadcastListeners.channel('team', () => 'teams.1');
        await BroadcastListeners.sync();

        bool secondRan = false;
        BroadcastListeners.add(
          'team',
          'check.recorded',
          (_) => throw StateError('boom'),
        );
        BroadcastListeners.add(
          'team',
          'check.recorded',
          (_) => secondRan = true,
        );

        echo.dispatch(
          'private-teams.1',
          'check.recorded',
          const <String, dynamic>{},
        );

        expect(secondRan, isTrue);
      },
    );

    test('add throws when the alias was never declared', () {
      expect(
        () => BroadcastListeners.add('missing', 'check.recorded', (_) {}),
        throwsStateError,
      );
    });
  });

  group('BroadcastListeners onReconnect forwarding', () {
    test("onReconnect forwards to the alias's AuthChannelSubscription", () {
      // `Echo.fake()`'s driver cannot emit a synthetic reconnect: its
      // `onReconnect` and `connectionState` streams are both
      // `Stream.empty()` (see `FakeBroadcastDriver`). This reads the
      // AuthChannelSubscription seam directly instead, per the step brief.
      int reconnects = 0;
      BroadcastListeners.channel(
        'team',
        () => 'teams.1',
        onReconnect: () => reconnects++,
      );

      final AuthChannelSubscription? subscription =
          BroadcastListeners.subscriptionForTesting('team');

      subscription!.onReconnect!();

      expect(reconnects, equals(1));
    });
  });
}
