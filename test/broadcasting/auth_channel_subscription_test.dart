import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// A [FakeBroadcastDriver] with controllable `onReconnect` and
/// `connectionState` streams, plus a `connect()` counter.
///
/// The shipped [FakeBroadcastDriver] cannot emit a synthetic reconnect or
/// connection-state signal: both streams are `Stream.empty()`. It also cannot
/// distinguish one `connect()` call from two, since `connect()` just flips a
/// bool; counting them is what shows when the subscription asks the driver
/// to connect and when it reuses the live connection.
class _CountingBroadcastDriver extends FakeBroadcastDriver {
  int connectCount = 0;

  /// When set, the next [connect] emits `connecting` on [connectionState]
  /// and then throws, instead of succeeding. Simulates the real Reverb
  /// driver's `connect()` failing after its own `connecting` announcement
  /// (e.g. the server unreachable at boot).
  bool failNextConnect = false;

  final StreamController<void> _reconnectController =
      StreamController<void>.broadcast();
  final StreamController<BroadcastConnectionState> _connectionStateController =
      StreamController<BroadcastConnectionState>.broadcast();

  @override
  Future<void> connect() async {
    connectCount++;
    if (failNextConnect) {
      failNextConnect = false;
      _connectionStateController.add(BroadcastConnectionState.connecting);
      throw StateError('connect failed');
    }
    return super.connect();
  }

  @override
  Stream<void> get onReconnect => _reconnectController.stream;

  @override
  Stream<BroadcastConnectionState> get connectionState =>
      _connectionStateController.stream;

  /// Emits a synthetic `Echo.onReconnect` signal.
  void emitReconnect() => _reconnectController.add(null);

  /// Emits a synthetic `connectionState` transition.
  void emitConnectionState(BroadcastConnectionState state) =>
      _connectionStateController.add(state);
}

/// A [FakeBroadcastManager] handing out a [_CountingBroadcastDriver].
///
/// Overrides `connection()` rather than replacing the parent's driver, which
/// is private and final, so the inherited assertion helpers (`assertSubscribed`
/// etc.) still speak for the parent's unused driver. Read state off [spy]
/// directly in tests that use this manager.
class _CountingBroadcastManager extends FakeBroadcastManager {
  final _CountingBroadcastDriver spy = _CountingBroadcastDriver();

  @override
  BroadcastDriver connection([String? name]) => spy;
}

void main() {
  late FakeBroadcastManager echo;

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    // Bind LogManager so the documented degradation path (a caught `sync`
    // failure logs rather than throwing) resolves the `log` service.
    Magic.singleton('log', () => LogManager());
    echo = Echo.fake();
  });

  tearDown(() {
    Echo.unfake();
    MagicApp.reset();
    Magic.flush();
  });

  /// Lets a stream event queued on a [StreamController] reach its listener
  /// before assertions run.
  Future<void> flushMicrotasks() => Future<void>.delayed(Duration.zero);

  test(
    'the first sync subscribes and a dispatched event reaches its listener',
    () async {
      final List<BroadcastEvent> received = <BroadcastEvent>[];
      final AuthChannelSubscription subscription = AuthChannelSubscription(
        channelName: () => 'teams.1',
        listeners: <String, void Function(BroadcastEvent)>{
          'incident.opened': received.add,
        },
      );

      await subscription.sync();

      echo.assertConnected();
      echo.assertSubscribed('private-teams.1');
      echo.assertListening('private-teams.1', 'incident.opened');

      echo.dispatch(
        'private-teams.1',
        'incident.opened',
        const <String, dynamic>{'id': 'i1'},
      );

      expect(received, hasLength(1));
      expect(received.single.data['id'], 'i1');
    },
  );

  test(
    'a name change leaves the old channel and subscribes to the new one with '
    'exactly one connect',
    () async {
      final _CountingBroadcastManager counting = _CountingBroadcastManager();
      Magic.app.setInstance('broadcasting', counting);

      String channelName = 'teams.1';
      final AuthChannelSubscription subscription = AuthChannelSubscription(
        channelName: () => channelName,
        listeners: <String, void Function(BroadcastEvent)>{},
      );

      await subscription.sync();
      expect(
        counting.spy.connectCount,
        1,
        reason: 'the first sync must connect',
      );
      expect(counting.spy.subscribedChannels, contains('private-teams.1'));

      channelName = 'teams.2';
      await subscription.sync();

      expect(
        counting.spy.connectCount,
        1,
        reason: 'an already-open socket is reused',
      );
      expect(counting.spy.subscribedChannels, contains('private-teams.2'));
      expect(
        counting.spy.subscribedChannels,
        isNot(contains('private-teams.1')),
      );
    },
  );

  test('an unchanged name does not reconnect while the socket is down, the '
      'driver recovers it', () async {
    final _CountingBroadcastManager counting = _CountingBroadcastManager();
    Magic.app.setInstance('broadcasting', counting);

    final AuthChannelSubscription subscription = AuthChannelSubscription(
      channelName: () => 'teams.1',
      listeners: <String, void Function(BroadcastEvent)>{},
    );

    await subscription.sync();
    await counting.spy.disconnect();
    await subscription.sync();

    expect(
      counting.spy.connectCount,
      1,
      reason:
          'an unchanged name is the driver\'s to recover; it resubscribes '
          'on its own',
    );
  });

  test('a name change while the socket is down asks the driver to connect, '
      'whatever state it last reported, and subscribes', () async {
    final _CountingBroadcastManager counting = _CountingBroadcastManager();
    Magic.app.setInstance('broadcasting', counting);

    String channelName = 'teams.1';
    final AuthChannelSubscription subscription = AuthChannelSubscription(
      channelName: () => channelName,
      listeners: <String, void Function(BroadcastEvent)>{},
    );

    await subscription.sync();
    expect(counting.spy.connectCount, 1);

    // The driver dropped its socket and reports a pending reconnect. The
    // subscription no longer second-guesses that: the driver's connect()
    // is idempotent and supersedes its own armed retry.
    counting.spy.emitConnectionState(BroadcastConnectionState.reconnecting);
    await flushMicrotasks();
    await counting.spy.disconnect();

    channelName = 'teams.2';
    await subscription.sync();

    expect(counting.spy.connectCount, 2);
    expect(counting.spy.subscribedChannels, contains('private-teams.2'));
  });

  test('a failed own connect does not strand the subscription: the next sync '
      'connects again and subscribes', () async {
    final _CountingBroadcastManager counting = _CountingBroadcastManager();
    Magic.app.setInstance('broadcasting', counting);
    counting.spy.failNextConnect = true;

    final AuthChannelSubscription subscription = AuthChannelSubscription(
      channelName: () => 'teams.1',
      listeners: <String, void Function(BroadcastEvent)>{},
    );

    await subscription.sync();
    expect(
      counting.spy.connectCount,
      1,
      reason: 'the first sync attempts to connect',
    );
    expect(
      counting.spy.subscribedChannels,
      isEmpty,
      reason: 'a failed connect must not subscribe on a dead driver',
    );

    await subscription.sync();

    expect(
      counting.spy.connectCount,
      2,
      reason: 'the next sync retries the connect',
    );
    expect(counting.spy.subscribedChannels, contains('private-teams.1'));
  });

  test('overlapping syncs serialize and settle on the latest name', () async {
    String channelName = 'teams.1';
    final AuthChannelSubscription subscription = AuthChannelSubscription(
      channelName: () => channelName,
      listeners: <String, void Function(BroadcastEvent)>{},
    );

    // Start the first sync (teams.1) without awaiting; it suspends at
    // `await Echo.connect()`.
    final Future<void> first = subscription.sync();
    // The name changes before the first sync completes. Without the latch
    // this would run concurrently and could leave both channels subscribed.
    channelName = 'teams.2';
    final Future<void> second = subscription.sync();

    await Future.wait(<Future<void>>[first, second]);

    echo.assertSubscribed('private-teams.2');
    echo.assertNotSubscribed('private-teams.1');
    expect(
      echo.driver.subscribedChannels
          .where((String c) => c == 'private-teams.2')
          .length,
      1,
      reason: 'the deferred re-run must not double-subscribe the settled name',
    );
  });

  test('a null channel name leaves the channel and disconnects', () async {
    String? channelName = 'teams.1';
    final AuthChannelSubscription subscription = AuthChannelSubscription(
      channelName: () => channelName,
      listeners: <String, void Function(BroadcastEvent)>{},
    );

    await subscription.sync();
    echo.assertConnected();

    channelName = null;
    await subscription.sync();

    echo.assertDisconnected();
    echo.assertNotSubscribed('private-teams.1');
  });

  test('a null channel name before any subscribe is a safe no-op', () async {
    final AuthChannelSubscription subscription = AuthChannelSubscription(
      channelName: () => null,
      listeners: <String, void Function(BroadcastEvent)>{},
    );

    await subscription.sync();

    echo.assertDisconnected();
  });

  test('a reconnect signal and a connected transition after a drop each fire '
      'onReconnect exactly once', () async {
    final _CountingBroadcastManager counting = _CountingBroadcastManager();
    Magic.app.setInstance('broadcasting', counting);

    int reconnectCount = 0;
    final AuthChannelSubscription subscription = AuthChannelSubscription(
      channelName: () => 'teams.1',
      listeners: <String, void Function(BroadcastEvent)>{},
      onReconnect: () => reconnectCount++,
    );
    await subscription.sync();

    counting.spy.emitReconnect();
    await flushMicrotasks();
    expect(reconnectCount, 1);

    // Simulate a drop and Reverb's silent re-subscribe: the driver reports
    // `connected` again with no `onReconnect` signal of its own.
    counting.spy.emitConnectionState(BroadcastConnectionState.disconnected);
    counting.spy.emitConnectionState(BroadcastConnectionState.connected);
    await flushMicrotasks();

    expect(reconnectCount, 2);
  });

  test('a resync requested while a pass is throwing still runs and settles on '
      'the latest name', () async {
    // `channelName` throws on its very first call, the way a caller's
    // getter might while its own state is mid-update. A second `sync`
    // arrives before that failing pass is caught, so it only sets the
    // resync flag; the fix is that the flag is still honored after the
    // catch, not just after a clean pass.
    int calls = 0;
    String channelName = 'teams.1';
    final AuthChannelSubscription subscription = AuthChannelSubscription(
      channelName: () {
        calls++;
        if (calls == 1) {
          throw StateError('channel name unavailable');
        }
        return channelName;
      },
      listeners: <String, void Function(BroadcastEvent)>{},
    );

    final Future<void> first = subscription.sync();
    channelName = 'teams.2';
    final Future<void> second = subscription.sync();

    await Future.wait(<Future<void>>[first, second]);

    echo.assertSubscribed('private-teams.2');
  });

  test('dispose is idempotent', () async {
    final AuthChannelSubscription subscription = AuthChannelSubscription(
      channelName: () => 'teams.1',
      listeners: <String, void Function(BroadcastEvent)>{},
    );
    await subscription.sync();

    subscription.dispose();
    subscription.dispose();
  });
}
