import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/src/events/event_dispatcher.dart' as magic_events;

class _Ping extends MagicEvent {}

/// Counts how many times it ran, so a listener registered twice is visible as
/// a count of two rather than as nothing at all.
class _Counter implements MagicListener<_Ping> {
  static int runs = 0;

  @override
  Future<void> handle(_Ping event) async {
    runs++;
  }
}

/// A provider that maps the event to the listener, the way an app does.
class _EventsProvider extends BaseEventServiceProvider {
  _EventsProvider(super.app);

  @override
  Map<Type, List<MagicListener Function()>> get listen => {
    _Ping: [_Counter.new],
  };
}

void main() {
  setUp(() {
    _Counter.runs = 0;
    magic_events.EventDispatcher.instance.clear();
    MagicApp.reset();
    Magic.flush();
  });

  test('resetting the app clears registered event listeners', () async {
    // `EventDispatcher` is its own static singleton, so `MagicApp.flush()`
    // used to leave every listener registered. Two consequences: a test file
    // that forgets to clear the dispatcher leaks listeners into the next one,
    // and an app that re-bootstraps (a logout that tears the container down
    // and builds it again) ends up with two of every listener, so one event
    // sends two emails.
    final app = MagicApp.instance;
    app.register(_EventsProvider(app));
    await app.boot();

    await magic_events.EventDispatcher.instance.dispatch(_Ping());
    expect(_Counter.runs, 1);

    MagicApp.reset();

    // Nothing is registered any more, so the event reaches nobody.
    await magic_events.EventDispatcher.instance.dispatch(_Ping());
    expect(_Counter.runs, 1, reason: 'the listener went with the container');
  });

  test('re-bootstrapping after a reset runs each listener once', () async {
    final first = MagicApp.instance;
    first.register(_EventsProvider(first));
    await first.boot();

    MagicApp.reset();

    final second = MagicApp.instance;
    second.register(_EventsProvider(second));
    await second.boot();

    await magic_events.EventDispatcher.instance.dispatch(_Ping());
    expect(
      _Counter.runs,
      1,
      reason: 'a second bootstrap must not double every listener',
    );
  });

  test('flush() alone also clears listeners', () async {
    final app = MagicApp.instance;
    app.register(_EventsProvider(app));
    await app.boot();

    app.flush();

    await magic_events.EventDispatcher.instance.dispatch(_Ping());
    expect(_Counter.runs, 0);
  });
}
