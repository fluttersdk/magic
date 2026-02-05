import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;
import 'package:magic/magic.dart';

// Mocks
class TestEvent extends MagicEvent {
  final String data;
  TestEvent(this.data);
}

class TestListener extends MagicListener<TestEvent> {
  static List<String> receivedData = [];

  @override
  Future<void> handle(TestEvent event) async {
    receivedData.add(event.data);
  }
}

class AnotherListener extends MagicListener<TestEvent> {
  static int callCount = 0;

  @override
  Future<void> handle(TestEvent event) async {
    callCount++;
  }
}

void main() {
  group('Magic Event System', () {
    late EventDispatcher dispatcher;

    setUp(() {
      dispatcher = EventDispatcher.instance;
      dispatcher.clear();
      TestListener.receivedData.clear();
      AnotherListener.callCount = 0;
    });

    test('it registers and dispatches events to listeners', () async {
      dispatcher.register(TestEvent, [
        () => TestListener(),
      ]);

      await dispatcher.dispatch(TestEvent('hello'));

      expect(TestListener.receivedData, contains('hello'));
    });

    test('it handles multiple listeners for same event', () async {
      dispatcher.register(TestEvent, [
        () => TestListener(),
        () => AnotherListener(),
      ]);

      await dispatcher.dispatch(TestEvent('magic'));

      expect(TestListener.receivedData, contains('magic'));
      expect(AnotherListener.callCount, 1);
    });

    test('it ignores events with no listeners', () async {
      await dispatcher.dispatch(TestEvent('ignored'));
      expect(TestListener.receivedData, isEmpty);
    });

    test('Event facade proxies to dispatcher', () async {
      dispatcher.register(TestEvent, [
        () => TestListener(),
      ]);

      await Event.dispatch(TestEvent('facade'));

      expect(TestListener.receivedData, contains('facade'));
    });
  });
}
