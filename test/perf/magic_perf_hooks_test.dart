import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/src/events/event_dispatcher.dart' as magic_events;

/// What this pins: [MagicPerfHooks.sink] receives one [MagicPerfEvent] per
/// instrumented seam, a [ControllerNotified] names the ROOT path that caused
/// the notification (falling back to [MagicNotifyCause.direct]), a throwing
/// sink never stops a repaint, and with no sink installed not a single event
/// object is built.
class _StateController extends MagicController with MagicStateMixin<String> {
  _StateController() {
    onInit();
  }
}

class _ActionController extends MagicController with RunsActions {}

class _Row extends Model {
  @override
  String get table => 'perf_rows';

  @override
  String get resource => 'perf_rows';

  @override
  List<String> get fillable => const <String>['id', 'name'];

  @override
  Map<String, dynamic> get casts => const <String, dynamic>{
    'born_at': 'datetime',
    'settings': 'json',
  };

  static _Row fromMap(Map<String, dynamic> map) {
    return _Row()
      ..fill(map)
      ..exists = true;
  }
}

class _RowRepository extends Repository<_Row> {
  @override
  String get resource => 'perf_rows';

  @override
  _Row Function(Map<String, dynamic>) get fromMap => _Row.fromMap;
}

class _Succeeds extends MagicAction<int, String> {
  const _Succeeds();

  @override
  Future<String> handle(int input) async => 'done';
}

class _Throws extends MagicAction<int, String> {
  const _Throws();

  @override
  Future<String> handle(int input) async => throw StateError('boom');
}

class _Ping extends MagicEvent {}

class _PingListener implements MagicListener<_Ping> {
  @override
  Future<void> handle(_Ping event) async {}
}

MagicResponse _page(List<Map<String, dynamic>> rows) {
  return Http.response(<String, dynamic>{
    'data': rows,
    'meta': <String, dynamic>{'next_cursor': null},
  }, 200);
}

void main() {
  late List<MagicPerfEvent> events;

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    magic_events.EventDispatcher.instance.clear();
    MagicPerfEvent.debugEventsConstructed = 0;
    events = <MagicPerfEvent>[];
    MagicPerfHooks.sink = events.add;
  });

  tearDown(() {
    MagicPerfHooks.sink = null;
    Http.unfake();
  });

  Iterable<MagicNotifyCause> causesFor(MagicController controller) {
    return events
        .whereType<ControllerNotified>()
        .where((ControllerNotified e) => identical(e.controller, controller))
        .map((ControllerNotified e) => e.cause);
  }

  group('ControllerNotified cause', () {
    test('a setSuccess reports setState', () {
      final _StateController controller = _StateController();

      controller.setSuccess('a');

      expect(causesFor(controller), <MagicNotifyCause>[
        MagicNotifyCause.setState,
      ]);
    });

    test('a notify outside every instrumented path reports direct', () {
      final _StateController controller = _StateController();

      controller.refreshUI();

      expect(causesFor(controller), <MagicNotifyCause>[
        MagicNotifyCause.direct,
      ]);
    });

    test('a Countdown tick reports timerTick, also through a nested setState, '
        'and the cause does not outlive the tick', () async {
      final _StateController ticking = _StateController();
      final _StateController nested = _StateController();
      final Countdown countdown = Countdown()
        ..onTick = (Object key, int remaining) {
          ticking.refreshUI();
          nested.setSuccess('$remaining');
        };

      countdown.start('retry', 1);
      await Future<void>.delayed(const Duration(milliseconds: 1100));

      expect(events.whereType<TimerTicked>().single.ownerType, Countdown);
      expect(causesFor(ticking), <MagicNotifyCause>[
        MagicNotifyCause.timerTick,
      ]);
      // The root cause wins: the setState ran because the timer fired.
      expect(causesFor(nested), <MagicNotifyCause>[MagicNotifyCause.timerTick]);

      ticking.refreshUI();
      expect(causesFor(ticking).last, MagicNotifyCause.direct);
    });

    test('a Debouncer fire reports timerTick', () async {
      final _StateController controller = _StateController();
      final Debouncer debouncer = Debouncer();

      debouncer.run(
        'reload',
        const Duration(milliseconds: 10),
        controller.refreshUI,
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(events.whereType<TimerTicked>().single.ownerType, Debouncer);
      expect(causesFor(controller), <MagicNotifyCause>[
        MagicNotifyCause.timerTick,
      ]);
    });

    test('a Poll read reports timerTick', () async {
      final _StateController controller = _StateController();

      final PollHandle<int> handle = Poll.until<int>(
        read: () async {
          controller.refreshUI();
          return 1;
        },
        done: (int value) => true,
        every: const Duration(milliseconds: 10),
        maxAttempts: 1,
      );
      await handle.result;

      expect(events.whereType<TimerTicked>().single.ownerType, Poll);
      expect(causesFor(controller), <MagicNotifyCause>[
        MagicNotifyCause.timerTick,
      ]);
    });

    test('a RepositoryQuery change reports repositoryQuery', () {
      final _RowRepository repository = _RowRepository();
      final RepositoryQuery<_Row> query = RepositoryQuery<_Row>(
        repository: repository,
      );
      final _StateController controller = _StateController();
      query.addListener(controller.refreshUI);

      repository.upsertFromList(<_Row>[
        _Row.fromMap(<String, dynamic>{'id': '1', 'name': 'a'}),
      ]);

      expect(causesFor(controller), <MagicNotifyCause>[
        MagicNotifyCause.repositoryQuery,
      ]);

      query.dispose();
      repository.dispose();
    });

    test('a broadcast dispatch reports broadcast', () async {
      final FakeBroadcastManager echo = Echo.fake();
      Log.fake();
      addTearDown(() {
        BroadcastListeners.reset();
        Echo.unfake();
        Log.unfake();
      });
      final _StateController controller = _StateController();
      BroadcastListeners.channel('team', () => 'teams.1');
      await BroadcastListeners.sync();
      BroadcastListeners.add(
        'team',
        'check.recorded',
        (BroadcastEvent _) => controller.refreshUI(),
      );

      echo.dispatch(
        'private-teams.1',
        'check.recorded',
        const <String, dynamic>{'id': '1'},
      );

      expect(
        events.whereType<BroadcastReceived>().single.event,
        'check.recorded',
      );
      expect(causesFor(controller), <MagicNotifyCause>[
        MagicNotifyCause.broadcast,
      ]);
    });

    test('a disposed controller reports nothing', () {
      final _StateController controller = _StateController();
      controller.dispose();

      controller.refreshUI();

      expect(causesFor(controller), isEmpty);
    });
  });

  group('event kinds', () {
    test('RepositoryUpserted counts the rows a list or show read merged', () {
      final _RowRepository repository = _RowRepository();

      repository.upsertFromList(<_Row>[
        _Row.fromMap(<String, dynamic>{'id': '1'}),
        _Row.fromMap(<String, dynamic>{'id': '2'}),
      ]);
      repository.upsertFromShow(_Row.fromMap(<String, dynamic>{'id': '3'}));

      final List<RepositoryUpserted> upserts = events
          .whereType<RepositoryUpserted>()
          .toList();
      expect(upserts.map((RepositoryUpserted e) => e.type), <Type>[_Row, _Row]);
      expect(upserts.map((RepositoryUpserted e) => e.count), <int>[2, 1]);

      repository.dispose();
    });

    test('QueryReloaded spans a reload, and a joined first load is marked '
        'fromCache', () async {
      Http.fake((MagicRequest request) {
        return _page(<Map<String, dynamic>>[
          <String, dynamic>{'id': '1', 'name': 'a'},
        ]);
      });
      final _RowRepository repository = _RowRepository();
      final RepositoryQuery<_Row> query = RepositoryQuery<_Row>(
        repository: repository,
      );

      final Future<void> first = query.reload();
      final Future<void> joined = query.ensureFresh();
      await Future.wait(<Future<void>>[first, joined]);

      final List<QueryReloaded> reloads = events
          .whereType<QueryReloaded>()
          .toList();
      expect(reloads, hasLength(2));
      expect(reloads.map((QueryReloaded e) => e.type).toSet(), <Type>{_Row});
      expect(reloads.map((QueryReloaded e) => e.fromCache).toSet(), <bool>{
        false,
        true,
      });
      for (final QueryReloaded reload in reloads) {
        expect(reload.endUs, greaterThanOrEqualTo(reload.startUs));
      }

      query.dispose();
      repository.dispose();
    });

    test(
      'ActionRan carries the action type, its span and its outcome',
      () async {
        Log.fake();
        addTearDown(Log.unfake);
        final _ActionController controller = _ActionController();

        await controller.runAction(const _Succeeds(), 1);
        await controller.runAction(
          const _Throws(),
          1,
          onFailure: (Object error) {},
        );

        final List<ActionRan> runs = events.whereType<ActionRan>().toList();
        expect(runs.map((ActionRan e) => e.type), <Type>[_Succeeds, _Throws]);
        expect(runs.first.outcome, isA<ActionSucceeded<Object?>>());
        expect(runs.last.outcome, isA<ActionFailed<Object?>>());
        for (final ActionRan run in runs) {
          expect(run.endUs, greaterThanOrEqualTo(run.startUs));
        }
      },
    );

    test('EventDispatched counts typed and wildcard listeners', () async {
      magic_events.EventDispatcher.instance.register(
        _Ping,
        <MagicListener Function()>[
          () => _PingListener(),
          () => _PingListener(),
        ],
      );
      magic_events.EventDispatcher.instance.listenAny((MagicEvent event) {});

      await magic_events.EventDispatcher.instance.dispatch(_Ping());

      final EventDispatched dispatched = events
          .whereType<EventDispatched>()
          .single;
      expect(dispatched.type, _Ping);
      expect(dispatched.listenerCount, 3);
      expect(dispatched.endUs, greaterThanOrEqualTo(dispatched.startUs));
    });

    test('AttributeCast reports each computed cast; a memo hit is not a '
        'cast and json is cast on every read', () {
      final _Row row = _Row()
        ..setRawAttributes(<String, dynamic>{
          'born_at': '2026-01-01T00:00:00Z',
          'settings': '{"theme":"dark"}',
          'name': 'plain',
        }, sync: true);

      row.getAttribute('born_at');
      row.getAttribute('born_at');
      row.getAttribute('settings');
      row.getAttribute('settings');
      row.getAttribute('name');

      expect(
        events.whereType<AttributeCast>().map((AttributeCast e) => e.castType),
        <String>['datetime', 'json', 'json'],
      );
    });
  });

  group('the sink contract', () {
    test('a sink that throws does not stop the repaint', () {
      MagicPerfHooks.sink = (MagicPerfEvent event) =>
          throw StateError('observer is broken');
      final _StateController controller = _StateController();
      int listenerCalls = 0;
      controller.addListener(() => listenerCalls++);

      expect(() => controller.setSuccess('a'), returnsNormally);
      expect(() => controller.setSuccess('b'), returnsNormally);
      expect(listenerCalls, 2);
    });

    test('with no sink installed no event object is ever built', () async {
      MagicPerfHooks.sink = null;
      Log.fake();
      addTearDown(Log.unfake);
      Http.fake((MagicRequest request) {
        return _page(<Map<String, dynamic>>[
          <String, dynamic>{'id': '1'},
        ]);
      });
      final _StateController controller = _StateController();
      final _RowRepository repository = _RowRepository();
      final RepositoryQuery<_Row> query = RepositoryQuery<_Row>(
        repository: repository,
      );
      query.addListener(controller.refreshUI);
      magic_events.EventDispatcher.instance.register(
        _Ping,
        <MagicListener Function()>[() => _PingListener()],
      );

      controller.setSuccess('a');
      controller.refreshUI();
      await query.reload();
      await _ActionController().runAction(const _Succeeds(), 1);
      await magic_events.EventDispatcher.instance.dispatch(_Ping());
      (_Row()
            ..setRawAttributes(<String, dynamic>{'settings': '{}'}, sync: true))
          .getAttribute('settings');
      Debouncer().run(
        'k',
        const Duration(milliseconds: 5),
        controller.refreshUI,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(MagicPerfEvent.debugEventsConstructed, 0);

      query.dispose();
      repository.dispose();
    });
  });
}
