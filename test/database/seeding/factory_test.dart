import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

class Monitor extends Model {
  /// Whether [Model.isUnguarded] was on at each [save], in call order.
  final List<bool> savedUnguarded = [];

  @override
  String get table => 'monitors';

  @override
  String get resource => 'monitors';

  @override
  List<String> get fillable => ['name'];

  /// Stands in for `InteractsWithPersistence.save`, which [Factory.create]
  /// calls dynamically.
  Future<bool> save() async {
    savedUnguarded.add(Model.isUnguarded);
    exists = true;
    syncOriginal();

    return true;
  }
}

class MonitorFactory extends Factory<Monitor> {
  int definitions = 0;

  @override
  Factory<Monitor> newFactory() => MonitorFactory();

  @override
  Monitor newInstance() => Monitor();

  @override
  Map<String, dynamic> definition() {
    definitions++;

    return {
      'id': definitions,
      'name': 'Monitor $definitions',
      'last_status': 'up',
    };
  }
}

extension MonitorFactoryStates on Factory<Monitor> {
  Factory<Monitor> down() => state({'last_status': 'down'});
}

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });

  group('Factory.make', () {
    test('keeps keys the model does not list as fillable', () {
      final monitor = MonitorFactory().make().single;

      expect(monitor.id, 1);
      expect(monitor.getAttribute('name'), 'Monitor 1');
      expect(monitor.getAttribute('last_status'), 'up');
    });

    test('leaves the guard on once it returns', () {
      MonitorFactory().make();

      expect(Model.isUnguarded, isFalse);
      expect((Monitor()..fill({'id': 1})).id, isNull);
    });

    test('leaves the model unsaved and dirty', () {
      final monitor = MonitorFactory().make().single;

      expect(monitor.exists, isFalse);
      expect(monitor.isDirty('id'), isTrue);
      expect(monitor.isDirty('last_status'), isTrue);
    });

    test('merges state over the definition', () {
      final monitor = MonitorFactory()
          .state({'last_status': 'degraded'})
          .make()
          .single;

      expect(monitor.getAttribute('last_status'), 'degraded');
      expect(monitor.getAttribute('name'), 'Monitor 1');
    });

    test('builds count models from fresh definitions', () {
      final monitors = MonitorFactory().count(3).make();

      expect(monitors.map((m) => m.id), [1, 2, 3]);
    });
  });

  group('Factory copy-on-write', () {
    test('state() does not change the factory it was called on', () {
      final factory = MonitorFactory();
      factory.state({'a': 1});

      expect(factory.make().single.getAttribute('a'), isNull);
    });

    test('count() does not change the factory it was called on', () {
      final factory = MonitorFactory();
      factory.count(3);

      expect(factory.make(), hasLength(1));
    });

    test('state() and count() carry what came before', () {
      final monitors = MonitorFactory()
          .count(2)
          .state({'a': 1})
          .state({'b': 2})
          .make();

      expect(monitors, hasLength(2));
      expect(monitors.first.getAttribute('a'), 1);
      expect(monitors.first.getAttribute('b'), 2);
    });

    test('a named state written as an extension chains', () {
      final monitors = MonitorFactory().down().count(2).make();

      expect(monitors, hasLength(2));
      expect(
        monitors.map((m) => m.getAttribute('last_status')),
        ['down', 'down'],
      );
    });

    test('a branch off a shared base does not leak into its sibling', () {
      final base = MonitorFactory().state({'name': 'shared'});
      final down = base.down();

      expect(base.make().single.getAttribute('last_status'), 'up');
      expect(down.make().single.getAttribute('last_status'), 'down');
      expect(down.make().single.getAttribute('name'), 'shared');
    });
  });

  group('Factory.raw', () {
    test('returns one attribute map without count', () {
      final raw = MonitorFactory().state({'last_status': 'down'}).raw();

      expect(raw, [
        {
          'id': 1,
          'name': 'Monitor 1',
          'last_status': 'down',
        },
      ]);
    });

    test('returns count attribute maps with count', () {
      final raw = MonitorFactory().count(2).raw();

      expect(raw.map((attributes) => attributes['id']), [1, 2]);
    });
  });

  group('Factory.create', () {
    test('keeps non-fillable keys and saves each model guarded', () async {
      final monitors = await MonitorFactory().count(2).create();

      expect(monitors.map((m) => m.id), [1, 2]);
      expect(monitors.first.getAttribute('last_status'), 'up');
      expect(monitors.first.exists, isTrue);
      expect(monitors.first.savedUnguarded, [false]);
      expect(Model.isUnguarded, isFalse);
    });
  });
}
