import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/src/events/event_dispatcher.dart' as magic_events;

class _Ping extends MagicEvent {}

class _TypedListener implements MagicListener<_Ping> {
  static final List<String> order = [];

  @override
  Future<void> handle(_Ping event) async {
    order.add('typed');
  }
}

void main() {
  setUp(() {
    magic_events.EventDispatcher.instance.clear();
    _TypedListener.order.clear();
  });

  test(
    'a wildcard listener receives a typed event after its typed listener',
    () async {
      final List<MagicEvent> received = [];
      magic_events.EventDispatcher.instance.register(_Ping, [
        () => _TypedListener(),
      ]);
      magic_events.EventDispatcher.instance.listenAny((MagicEvent event) {
        _TypedListener.order.add('wildcard');
        received.add(event);
      });

      await magic_events.EventDispatcher.instance.dispatch(_Ping());

      expect(received, hasLength(1));
      expect(received.single, isA<_Ping>());
      expect(_TypedListener.order, ['typed', 'wildcard']);
    },
  );

  test(
    'a throwing wildcard callback does not stop dispatch or other wildcards',
    () async {
      final fake = Log.fake();
      int survivorRuns = 0;

      magic_events.EventDispatcher.instance.listenAny((MagicEvent event) {
        throw StateError('boom');
      });
      magic_events.EventDispatcher.instance.listenAny((MagicEvent event) {
        survivorRuns++;
      });

      await magic_events.EventDispatcher.instance.dispatch(_Ping());

      expect(survivorRuns, 1);
      fake.assertLoggedCount(1);

      Log.unfake();
    },
  );

  test(
    'the remover returned by listenAny stops that callback from running again',
    () async {
      int runs = 0;
      final remove = magic_events.EventDispatcher.instance.listenAny((
        MagicEvent event,
      ) {
        runs++;
      });

      await magic_events.EventDispatcher.instance.dispatch(_Ping());
      expect(runs, 1);

      remove();

      await magic_events.EventDispatcher.instance.dispatch(_Ping());
      expect(
        runs,
        1,
        reason: 'the callback was removed before the second dispatch',
      );
    },
  );

  test('Event.listenAny registers through the facade', () async {
    int runs = 0;
    Event.listenAny((MagicEvent event) => runs++);

    await magic_events.EventDispatcher.instance.dispatch(_Ping());

    expect(runs, 1);
  });
}
