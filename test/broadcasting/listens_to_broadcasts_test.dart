import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// A controller that only backs a view: it never touches [BroadcastListeners]
/// on its own, `onInit` (called once by a `MagicStatefulViewState`) is what
/// starts it.
class _ViewBackedController extends MagicController with ListensToBroadcasts {
  final List<BroadcastEvent> received = <BroadcastEvent>[];

  @override
  Map<String, void Function(BroadcastEvent)> get listeners =>
      <String, void Function(BroadcastEvent)>{
        'team:check.recorded': received.add,
      };
}

/// A second, independent controller listening on the same alias and event,
/// so a test can prove closing one never touches the other.
class _OtherViewBackedController extends MagicController
    with ListensToBroadcasts {
  final List<BroadcastEvent> received = <BroadcastEvent>[];

  @override
  Map<String, void Function(BroadcastEvent)> get listeners =>
      <String, void Function(BroadcastEvent)>{
        'team:check.recorded': received.add,
      };
}

/// A controller read only through `.instance`, never mounted in a view, so
/// `onInit` never runs (`magic_view.dart`'s `initialized` guard). It starts
/// itself from its own constructor, as the mixin's doc comment requires.
class _SelfStartingController extends MagicController with ListensToBroadcasts {
  _SelfStartingController() {
    startListening();
  }

  final List<BroadcastEvent> received = <BroadcastEvent>[];

  @override
  Map<String, void Function(BroadcastEvent)> get listeners =>
      <String, void Function(BroadcastEvent)>{
        'team:check.recorded': received.add,
      };
}

/// What this pins: [ListensToBroadcasts] never opens its own subscription.
/// Every controller listening on the same alias shares the ONE
/// [AuthChannelSubscription] [BroadcastListeners] owns, so closing one
/// controller removes only its own callbacks and leaves a sibling controller,
/// and the shared channel, alone.
void main() {
  late FakeBroadcastManager echo;

  setUp(() async {
    MagicApp.reset();
    Magic.flush();
    echo = Echo.fake();
    Log.fake();
    BroadcastListeners.channel('team', () => 'teams.1');
    await BroadcastListeners.sync();
  });

  tearDown(() {
    BroadcastListeners.reset();
    Echo.unfake();
    Log.unfake();
    MagicApp.reset();
    Magic.flush();
  });

  void dispatchCheckRecorded() => echo.dispatch(
    'private-teams.1',
    'check.recorded',
    const <String, dynamic>{'id': '1'},
  );

  test('two controllers listening to the same event both receive it', () {
    final _ViewBackedController a = _ViewBackedController();
    final _OtherViewBackedController b = _OtherViewBackedController();
    a.onInit();
    b.onInit();

    dispatchCheckRecorded();

    expect(a.received, hasLength(1));
    expect(b.received, hasLength(1));
  });

  test('closing one controller keeps the other receiving', () {
    // This is the whole reason BroadcastListeners exists rather than each
    // controller opening its own AuthChannelSubscription: a design that
    // gave `a` its own subscription to `teams.1` would have `a.dispose()`
    // leave (or tear down) that channel, and `b.received` below would go
    // back to empty the moment that happened, since `b`'s events travel on
    // the same private channel.
    final _ViewBackedController a = _ViewBackedController();
    final _OtherViewBackedController b = _OtherViewBackedController();
    a.onInit();
    b.onInit();

    a.dispose();

    dispatchCheckRecorded();

    expect(a.received, isEmpty);
    expect(b.received, hasLength(1));
  });

  test('closing the last controller does not leave a dangling listener', () {
    final _ViewBackedController a = _ViewBackedController();
    a.onInit();

    a.dispose();

    echo.assertNotListening('private-teams.1', 'check.recorded');
  });

  test('startListening is idempotent', () {
    final _ViewBackedController a = _ViewBackedController();
    a.startListening();
    a.startListening();

    dispatchCheckRecorded();

    expect(a.received, hasLength(1));
  });

  test('a controller started from its own constructor receives events without '
      'ever backing a view', () {
    final _SelfStartingController controller = _SelfStartingController();

    dispatchCheckRecorded();

    expect(controller.received, hasLength(1));
    expect(controller.initialized, isFalse);
  });
}
