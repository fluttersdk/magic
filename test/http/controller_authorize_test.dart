import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

class _User extends Model with Authenticatable {
  @override
  String get table => 'users';

  @override
  String get resource => 'users';

  @override
  List<String> get fillable => ['id'];
}

class _PingController extends MagicController {
  void ping(String ability, [Object? model]) => authorize(ability, model);
}

_User _makeUser() {
  final user = _User();
  user.fill({'id': 1});
  user.exists = true;
  return user;
}

void main() {
  group('MagicController.authorize', () {
    late _User actor;

    setUp(() {
      MagicApp.reset();
      Magic.flush();
      Gate.flush();
      actor = _makeUser();
      Auth.fake(user: actor);
    });

    tearDown(() => Auth.unfake());

    test('passes through when gate allows', () {
      Gate.define('update', (user, model) => true);
      final controller = _PingController();

      expect(() => controller.ping('update', 'x'), returnsNormally);
    });

    test('throws AuthorizationException when gate denies', () {
      Gate.define('update', (user, model) => false);
      final controller = _PingController();

      expect(
        () => controller.ping('update'),
        throwsA(isA<AuthorizationException>()),
      );
    });

    test('uses Auth.user() as the actor', () {
      _User? seen;
      Gate.define('update', (user, model) {
        seen = user as _User;
        return true;
      });

      _PingController().ping('update');
      expect(seen, same(actor));
    });

    test('exception carries the ability name', () {
      Gate.define('delete', (user, model) => false);
      try {
        _PingController().ping('delete');
        fail('expected AuthorizationException');
      } on AuthorizationException catch (e) {
        expect(e.message, contains('delete'));
      }
    });
  });

  group('Gate sugar', () {
    setUp(() {
      MagicApp.reset();
      Magic.flush();
      Gate.flush();
      Auth.fake(user: _makeUser());
    });

    tearDown(() => Auth.unfake());

    test('allowsAny passes when one ability permits', () {
      Gate.define('a', (_, _) => false);
      Gate.define('b', (_, _) => true);
      Gate.define('c', (_, _) => false);

      expect(Gate.allowsAny(['a', 'b', 'c']), isTrue);
    });

    test('allowsAny fails when all deny', () {
      Gate.define('a', (_, _) => false);
      Gate.define('b', (_, _) => false);

      expect(Gate.allowsAny(['a', 'b']), isFalse);
    });

    test('allowsAll passes only when every ability permits', () {
      Gate.define('a', (_, _) => true);
      Gate.define('b', (_, _) => true);

      expect(Gate.allowsAll(['a', 'b']), isTrue);
    });

    test('allowsAll fails when any ability denies', () {
      Gate.define('a', (_, _) => true);
      Gate.define('b', (_, _) => false);

      expect(Gate.allowsAll(['a', 'b']), isFalse);
    });
  });
}
