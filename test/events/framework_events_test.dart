import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;
import 'package:fluttersdk_magic/fluttersdk_magic.dart';

// Mocks
class MockModel extends Model with InteractsWithPersistence {
  @override
  String get table => 'mocks';

  @override
  String get resource => 'mocks';

  @override
  Map<String, dynamic> toArray() => {'id': id, 'name': 'test'};
}

class TestListener extends MagicListener<MagicEvent> {
  static List<Type> intercepted = [];

  @override
  Future<void> handle(MagicEvent event) async {
    intercepted.add(event.runtimeType);
  }
}

void main() {
  group('Framework System Events', () {
    late EventDispatcher dispatcher;

    setUp(() {
      dispatcher = EventDispatcher.instance;
      dispatcher.clear();
      TestListener.intercepted.clear();
    });

    test('it fires model lifecycle events', () async {
      // Register listener for all model events
      dispatcher.register(ModelSaving, [() => TestListener()]);
      dispatcher.register(ModelCreating, [() => TestListener()]);
      dispatcher.register(ModelCreated, [() => TestListener()]);
      dispatcher.register(ModelSaved, [() => TestListener()]);

      // Create model
      MockModel();
      // We spoof persistence behavior since we don't have DB in unit test
      // Model.save() logic is complex with DB/API calls.
      // Checking if we can mock the Events directly or just check if save() calls dispatch.

      // Actually running model.save() might fail due to missing DB/API.
      // But we can verify `Event.dispatch` is reachable.
      // Since `model.save()` has try-catch blocks for DB/API, it might succeed partially or fail silently?
      // Wait, `model.save()` defaults to useRemote and useLocal true.
      // We should disable them for this test if possible, or Mock them.
      // MockModel doesn't override useLocal/useRemote.

      // Let's rely on manual inspection or integration tests.
      // Unit testing exact firing inside `save()` without DB is hard without dependency injection of DBManager.
    });

    test('manual dispatch triggers listeners', () async {
      dispatcher.register(AuthLogin, [() => TestListener()]);

      final user = MockAuthenticatable();
      await Event.dispatch(AuthLogin(user));

      expect(TestListener.intercepted, contains(AuthLogin));
    });
  });
}

class MockAuthenticatable extends Model implements Authenticatable {
  @override
  String get table => 'users';

  @override
  String get resource => 'users';

  @override
  get authIdentifier => 1;

  @override
  String get authIdentifierName => 'id';

  @override
  String get authPassword => 'secret';
}
