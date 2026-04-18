import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

enum MonitorStatus { active, paused, failed }

enum Tag { urgent, review, blocked }

class _UpperCaseCast implements CastsAttributes<String> {
  const _UpperCaseCast();

  @override
  String? get(Model model, String key, Object? raw) {
    if (raw == null) return null;
    return raw.toString().toUpperCase();
  }

  @override
  Object? set(Model model, String key, Object? value) {
    if (value is String) return value.toLowerCase();
    return value;
  }
}

class Monitor extends Model {
  @override
  String get table => 'monitors';

  @override
  String get resource => 'monitors';

  @override
  List<String> get fillable => ['status', 'tags', 'name'];

  @override
  Map<String, dynamic> get casts => {
    'status': EnumCast(MonitorStatus.values),
    'tags': ListCast(EnumCast(Tag.values)),
    'name': const _UpperCaseCast(),
  };

  MonitorStatus? get status => getAttribute('status') as MonitorStatus?;
  set status(MonitorStatus? value) => setAttribute('status', value);

  List<Tag>? get tags => getAttribute('tags') as List<Tag>?;
  set tags(List<Tag>? value) => setAttribute('tags', value);
}

class StrictMonitor extends Model {
  @override
  String get table => 'strict_monitors';

  @override
  String get resource => 'strict_monitors';

  @override
  Map<String, dynamic> get casts => {
    'status': EnumCast(MonitorStatus.values, strict: true),
  };
}

void main() {
  group('EnumCast', () {
    test('round-trips between enum and name', () {
      final monitor = Monitor();
      monitor.status = MonitorStatus.active;

      expect(monitor.status, MonitorStatus.active);
      expect(monitor.attributes['status'], 'active');
    });

    test('reads a raw name from storage as enum', () {
      final monitor = Monitor();
      monitor.setRawAttributes({'status': 'paused'});

      expect(monitor.status, MonitorStatus.paused);
    });

    test('returns null for unknown value by default', () {
      final monitor = Monitor();
      monitor.setRawAttributes({'status': 'archived'});

      expect(monitor.status, isNull);
    });

    test('throws on unknown value when strict', () {
      final monitor = StrictMonitor();
      monitor.setRawAttributes({'status': 'archived'});

      expect(() => monitor.getAttribute('status'), throwsArgumentError);
    });

    test('null raw returns null', () {
      final monitor = Monitor();
      expect(monitor.status, isNull);
    });

    test('raw string passes through set() unchanged', () {
      final monitor = Monitor();
      monitor.setAttribute('status', 'failed');

      expect(monitor.attributes['status'], 'failed');
      expect(monitor.status, MonitorStatus.failed);
    });
  });

  group('ListCast', () {
    test('round-trips a list of enums via JSON', () {
      final monitor = Monitor();
      monitor.tags = [Tag.urgent, Tag.review];

      expect(monitor.attributes['tags'], '["urgent","review"]');
      expect(monitor.tags, [Tag.urgent, Tag.review]);
    });

    test('reads a JSON string from storage', () {
      final monitor = Monitor();
      monitor.setRawAttributes({'tags': '["blocked","urgent"]'});

      expect(monitor.tags, [Tag.blocked, Tag.urgent]);
    });

    test('reads a raw list from storage', () {
      final monitor = Monitor();
      monitor.setRawAttributes({
        'tags': ['review', 'blocked'],
      });

      expect(monitor.tags, [Tag.review, Tag.blocked]);
    });

    test('skips unknown values silently', () {
      final monitor = Monitor();
      monitor.setRawAttributes({
        'tags': ['urgent', 'unknown', 'review'],
      });

      expect(monitor.tags, [Tag.urgent, Tag.review]);
    });

    test('null list returns null', () {
      final monitor = Monitor();
      expect(monitor.tags, isNull);
    });
  });

  group('Custom CastsAttributes', () {
    test('routes through custom get/set', () {
      final monitor = Monitor();
      monitor.setAttribute('name', 'Sentry');

      // set() lowercased, get() uppercased.
      expect(monitor.attributes['name'], 'sentry');
      expect(monitor.getAttribute('name'), 'SENTRY');
    });
  });

  group('Backwards compatibility', () {
    test('string-based casts keep working', () {
      final legacy = _LegacyModel();
      legacy.setAttribute('flag', true);
      expect(legacy.getAttribute('flag'), true);

      legacy.setRawAttributes({'count': '42'});
      expect(legacy.getAttribute('count'), 42);
    });
  });
}

class _LegacyModel extends Model {
  @override
  String get table => 'legacy';

  @override
  String get resource => 'legacy';

  @override
  Map<String, dynamic> get casts => {'flag': 'bool', 'count': 'int'};
}
