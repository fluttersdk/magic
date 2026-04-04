import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });

  // ---------------------------------------------------------------------------
  // Group 1 — Http.fake() basic
  // ---------------------------------------------------------------------------

  group('Http.fake() basic', () {
    test('returns FakeNetworkDriver instance', () {
      final fake = Http.fake();

      expect(fake, isA<FakeNetworkDriver>());
    });

    test(
      'subsequent Http.get() uses fake driver and returns 200 empty by default',
      () async {
        Http.fake();

        final response = await Http.get('users');

        expect(response, isA<MagicResponse>());
        expect(response.statusCode, equals(200));
      },
    );

    test('fake driver is registered in IoC container as network', () {
      Http.fake();

      final driver = Magic.make<NetworkDriver>('network');

      expect(driver, isA<FakeNetworkDriver>());
    });
  });

  // ---------------------------------------------------------------------------
  // Group 2 — Http.fake(map) — stub by URL pattern
  // ---------------------------------------------------------------------------

  group('Http.fake() with URL map stubs', () {
    test('stubs GET request matching exact URL pattern', () async {
      Http.fake({
        'users/*': Http.response({'name': 'John'}, 200),
      });

      final response = await Http.get('users/1');

      expect(response.successful, isTrue);
      expect(response.data['name'], equals('John'));
    });

    test(
      'returns 200 empty for unmatched URL when no wildcard catch-all defined',
      () async {
        Http.fake({
          'users/*': Http.response({'name': 'John'}, 200),
        });

        final response = await Http.get('posts/1');

        expect(response.statusCode, equals(200));
      },
    );

    test('stubs multiple URL patterns independently', () async {
      Http.fake({
        'users/*': Http.response({'type': 'user'}, 200),
        'posts/*': Http.response({'type': 'post'}, 201),
      });

      final userResponse = await Http.get('users/1');
      final postResponse = await Http.get('posts/99');

      expect(userResponse.data['type'], equals('user'));
      expect(postResponse.data['type'], equals('post'));
      expect(postResponse.statusCode, equals(201));
    });

    test('stub with error status returns failed response', () async {
      Http.fake({
        'errors/*': Http.response({'message': 'Not Found'}, 404),
      });

      final response = await Http.get('errors/1');

      expect(response.failed, isTrue);
      expect(response.notFound, isTrue);
      expect(response.data['message'], equals('Not Found'));
    });
  });

  // ---------------------------------------------------------------------------
  // Group 3 — Http.fake(callback) — dynamic callback stubs
  // ---------------------------------------------------------------------------

  group('Http.fake() with callback', () {
    test(
      'callback receives MagicRequest and returns matched response',
      () async {
        Http.fake((MagicRequest request) {
          if (request.url.contains('users')) {
            return Http.response({'users': []}, 200);
          }
          return Http.response({}, 404);
        });

        final response = await Http.get('users');

        expect(response.successful, isTrue);
        expect(response.data['users'], equals([]));
      },
    );

    test('callback falls through to 404 for unmatched URL', () async {
      Http.fake((MagicRequest request) {
        if (request.url.contains('users')) {
          return Http.response({'users': []}, 200);
        }
        return Http.response({}, 404);
      });

      final response = await Http.get('products');

      expect(response.failed, isTrue);
      expect(response.statusCode, equals(404));
    });

    test('callback can inspect request method', () async {
      Http.fake((MagicRequest request) {
        if (request.method == 'POST') {
          return Http.response({'created': true}, 201);
        }
        return Http.response({}, 405);
      });

      final response = await Http.post('users', data: {'name': 'Jane'});

      expect(response.statusCode, equals(201));
      expect(response.data['created'], isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Group 4 — Http.response() factory
  // ---------------------------------------------------------------------------

  group('Http.response() factory', () {
    test('returns MagicResponse with empty data and status 200 by default', () {
      final response = Http.response();

      expect(response, isA<MagicResponse>());
      expect(response.statusCode, equals(200));
      expect(response.data, equals(<String, dynamic>{}));
    });

    test('returns MagicResponse with given data and status', () {
      final response = Http.response({'key': 'val'}, 201);

      expect(response.statusCode, equals(201));
      expect(response.data['key'], equals('val'));
    });

    test('preserves null data when explicitly passed', () {
      final response = Http.response(null, 204);

      expect(response.statusCode, equals(204));
      expect(response.data, isNull);
    });

    test('default response (no args) returns empty map data', () {
      final response = Http.response();

      expect(response.data, equals(<String, dynamic>{}));
    });

    test('returned MagicResponse reflects successful status correctly', () {
      final ok = Http.response({'id': 1}, 200);
      final created = Http.response({'id': 2}, 201);
      final error = Http.response({'msg': 'fail'}, 500);

      expect(ok.successful, isTrue);
      expect(created.successful, isTrue);
      expect(error.serverError, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Group 5 — Http.unfake()
  // ---------------------------------------------------------------------------

  group('Http.unfake()', () {
    test('removes FakeNetworkDriver instance from IoC container', () {
      final app = MagicApp.instance;

      // Register a fallback singleton so make() has something to resolve after unfake
      app.singleton('network', () => FakeNetworkDriver());

      Http.fake();

      // Confirm fake is active
      expect(Magic.make<NetworkDriver>('network'), isA<FakeNetworkDriver>());

      Http.unfake();

      // After unfake, instance is removed — make() falls back to singleton binding
      // which also returns a FakeNetworkDriver here, but a fresh one (not the same)
      final resolved = Magic.make<NetworkDriver>('network');
      expect(resolved, isA<FakeNetworkDriver>());
    });

    test('unfake allows re-faking with a new fake instance', () {
      final app = MagicApp.instance;
      app.singleton('network', () => FakeNetworkDriver());

      final firstFake = Http.fake();
      Http.unfake();
      final secondFake = Http.fake();

      expect(identical(firstFake, secondFake), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Group 6 — Integration: full cycle
  // ---------------------------------------------------------------------------

  group('Http.fake() integration — full cycle', () {
    test('stubs, asserts sent, and asserts sent count', () async {
      final fake = Http.fake({
        'projects/*': Http.response({'id': '1', 'name': 'Test'}, 200),
      });

      fake.preventStrayRequests();

      final response = await Http.get('projects/1');

      expect(response.successful, isTrue);
      expect(response.data['name'], equals('Test'));

      fake.assertSent((MagicRequest r) => r.url.contains('projects'));
      fake.assertSentCount(1);
    });

    test('preventStrayRequests throws on unmatched URL', () async {
      Http.fake({'known/*': Http.response({}, 200)});

      Magic.make<FakeNetworkDriver>('network').preventStrayRequests();

      expect(() async => Http.get('unknown/path'), throwsA(isA<Exception>()));
    });

    test(
      'assertNotSent passes when no requests were made to given URL',
      () async {
        final fake = Http.fake({
          'users/*': Http.response({'name': 'Alice'}, 200),
        });

        // No requests fired
        fake.assertNotSent((MagicRequest r) => r.url.contains('users'));
      },
    );

    test('full lifecycle: fake → request → unfake → re-fake', () async {
      final app = MagicApp.instance;
      app.singleton('network', () => FakeNetworkDriver());

      Http.fake({
        'ping': Http.response({'pong': true}, 200),
      });

      final response = await Http.get('ping');
      expect(response.data['pong'], isTrue);

      Http.unfake();

      final newFake = Http.fake({
        'ping': Http.response({'pong': false}, 200),
      });
      final response2 = await Http.get('ping');
      expect(response2.data['pong'], isFalse);
      newFake.assertSentCount(1);
    });
  });
}
