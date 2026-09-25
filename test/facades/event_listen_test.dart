import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;
import 'package:magic/magic.dart';

class _User extends Model with Authenticatable {
  @override
  String get table => 'users';

  @override
  String get resource => 'users';
}

class _RecordingListener<T extends MagicEvent> extends MagicListener<T> {
  final List<T> received = <T>[];

  @override
  Future<void> handle(T event) async => received.add(event);
}

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });

  tearDown(() {
    MagicApp.reset();
    Magic.flush();
  });

  test('Event.listen registers a listener for the event type', () async {
    final logins = _RecordingListener<AuthLogin>();
    final logouts = _RecordingListener<AuthLogout>();
    Event.listen<AuthLogin>(() => logins);
    Event.listen<AuthLogout>(() => logouts);
    final event = AuthLogin(_User()..setRawAttributes({'id': 1}, sync: true));

    await Event.dispatch(event);

    expect(logins.received, [same(event)]);
    expect(logouts.received, isEmpty);
  });
}
