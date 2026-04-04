import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });

  // ---------------------------------------------------------------------------
  // 1. Default behavior
  // ---------------------------------------------------------------------------

  group('default behavior (no stubs)', () {
    test('get returns 200 empty response', () async {
      final fake = FakeNetworkDriver();

      final response = await fake.get('/users');

      expect(response.statusCode, equals(200));
      expect(response.successful, isTrue);
    });

    test('post returns 200 empty response', () async {
      final fake = FakeNetworkDriver();

      final response = await fake.post('/users', data: {'name': 'John'});

      expect(response.statusCode, equals(200));
      expect(response.successful, isTrue);
    });

    test('put returns 200 empty response', () async {
      final fake = FakeNetworkDriver();

      final response = await fake.put('/users/1', data: {'name': 'Jane'});

      expect(response.statusCode, equals(200));
      expect(response.successful, isTrue);
    });

    test('delete returns 200 empty response', () async {
      final fake = FakeNetworkDriver();

      final response = await fake.delete('/users/1');

      expect(response.statusCode, equals(200));
      expect(response.successful, isTrue);
    });

    test('upload returns 200 empty response', () async {
      final fake = FakeNetworkDriver();

      final response = await fake.upload(
        '/files',
        data: {'name': 'avatar'},
        files: {'file': 'path/to/file.jpg'},
      );

      expect(response.statusCode, equals(200));
      expect(response.successful, isTrue);
    });

    test('all requests are recorded in recorded list', () async {
      final fake = FakeNetworkDriver();

      await fake.get('/users');
      await fake.post('/posts', data: {'title': 'Hello'});

      expect(fake.recorded, hasLength(2));
    });

    test(
      'each recorded entry is a (MagicRequest, MagicResponse) record',
      () async {
        final fake = FakeNetworkDriver();

        await fake.get('/users');

        final entry = fake.recorded.first;
        expect(entry.$1, isA<MagicRequest>());
        expect(entry.$2, isA<MagicResponse>());
      },
    );

    test('recorded entry captures request url and method', () async {
      final fake = FakeNetworkDriver();

      await fake.get('/users');

      final (request, _) = fake.recorded.first;
      expect(request.url, contains('/users'));
      expect(request.method, equals('GET'));
    });
  });

  // ---------------------------------------------------------------------------
  // 2. URL pattern stubs via stub()
  // ---------------------------------------------------------------------------

  group('URL pattern stubs via stub()', () {
    test('stub with wildcard matches single segment', () async {
      final fake = FakeNetworkDriver();
      final stubResponse = MagicResponse(data: {'id': 1}, statusCode: 200);

      fake.stub('users/*', stubResponse);

      final response1 = await fake.get('/users/1');
      final response2 = await fake.get('/users/abc');

      expect(response1.data, equals({'id': 1}));
      expect(response2.data, equals({'id': 1}));
    });

    test('non-matching URL falls through to default 200 response', () async {
      final fake = FakeNetworkDriver();
      final stubResponse = MagicResponse(data: {'id': 1}, statusCode: 404);

      fake.stub('users/*', stubResponse);

      final response = await fake.get('/posts/1');

      expect(response.statusCode, equals(200));
      expect(response.data, isNot(equals({'id': 1})));
    });

    test('exact URL match works without wildcards', () async {
      final fake = FakeNetworkDriver();
      final stubResponse = MagicResponse(data: {'list': true}, statusCode: 200);

      fake.stub('/users', stubResponse);

      final response = await fake.get('/users');

      expect(response.data, equals({'list': true}));
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Map-based stubs via constructor
  // ---------------------------------------------------------------------------

  group('map-based stubs via constructor', () {
    test('constructor accepts Map<String, MagicResponse> stubs', () async {
      final fake = FakeNetworkDriver(
        stubs: {
          'users/*': MagicResponse(data: {'type': 'user'}, statusCode: 200),
        },
      );

      final response = await fake.get('/users/42');

      expect(response.data, equals({'type': 'user'}));
    });

    test('multiple patterns work simultaneously', () async {
      final fake = FakeNetworkDriver(
        stubs: {
          'users/*': MagicResponse(data: {'type': 'user'}, statusCode: 200),
          'posts/*': MagicResponse(data: {'type': 'post'}, statusCode: 201),
        },
      );

      final userResponse = await fake.get('/users/1');
      final postResponse = await fake.get('/posts/1');

      expect(userResponse.data, equals({'type': 'user'}));
      expect(postResponse.data, equals({'type': 'post'}));
      expect(postResponse.statusCode, equals(201));
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Callback stubs via constructor
  // ---------------------------------------------------------------------------

  group('callback stubs (FakeRequestHandler)', () {
    test('constructor accepts FakeRequestHandler callback', () async {
      final fake = FakeNetworkDriver(
        stubs: (MagicRequest request) {
          return MagicResponse(data: {'url': request.url}, statusCode: 200);
        },
      );

      final response = await fake.get('/anything');

      expect(response.data, equals({'url': '/anything'}));
    });

    test(
      'callback receives full MagicRequest with url, method, headers, data',
      () async {
        MagicRequest? captured;

        final fake = FakeNetworkDriver(
          stubs: (MagicRequest request) {
            captured = request;
            return MagicResponse(data: null, statusCode: 200);
          },
        );

        await fake.post(
          '/users',
          data: {'name': 'John'},
          headers: {'X-Token': 'abc'},
        );

        expect(captured, isNotNull);
        expect(captured!.url, contains('/users'));
        expect(captured!.method, equals('POST'));
        expect(captured!.data, equals({'name': 'John'}));
        expect(captured!.headers['X-Token'], equals('abc'));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // 5. Assertions
  // ---------------------------------------------------------------------------

  group('assertions', () {
    test('assertSent passes when matching request exists', () async {
      final fake = FakeNetworkDriver();

      await fake.get('/users');

      expect(
        () => fake.assertSent((r) => r.url.contains('users')),
        returnsNormally,
      );
    });

    test('assertSent throws AssertionError when no match', () async {
      final fake = FakeNetworkDriver();

      await fake.get('/users');

      expect(
        () => fake.assertSent((r) => r.url.contains('admin')),
        throwsA(isA<AssertionError>()),
      );
    });

    test('assertNotSent passes when no matching request exists', () async {
      final fake = FakeNetworkDriver();

      await fake.get('/users');

      expect(
        () => fake.assertNotSent((r) => r.url.contains('admin')),
        returnsNormally,
      );
    });

    test('assertNotSent throws when matching request exists', () async {
      final fake = FakeNetworkDriver();

      await fake.get('/admin/users');

      expect(
        () => fake.assertNotSent((r) => r.url.contains('admin')),
        throwsA(isA<AssertionError>()),
      );
    });

    test('assertNothingSent passes with empty recorded list', () async {
      final fake = FakeNetworkDriver();

      expect(() => fake.assertNothingSent(), returnsNormally);
    });

    test('assertNothingSent throws when any request was recorded', () async {
      final fake = FakeNetworkDriver();

      await fake.get('/users');

      expect(() => fake.assertNothingSent(), throwsA(isA<AssertionError>()));
    });

    test('assertSentCount passes when count matches', () async {
      final fake = FakeNetworkDriver();

      await fake.get('/users');
      await fake.post('/users', data: {'name': 'John'});

      expect(() => fake.assertSentCount(2), returnsNormally);
    });

    test('assertSentCount throws when count does not match', () async {
      final fake = FakeNetworkDriver();

      await fake.get('/users');

      expect(() => fake.assertSentCount(3), throwsA(isA<AssertionError>()));
    });
  });

  // ---------------------------------------------------------------------------
  // 6. preventStrayRequests
  // ---------------------------------------------------------------------------

  group('preventStrayRequests', () {
    test('unmatched request throws StateError', () async {
      final fake = FakeNetworkDriver();
      fake.stub('users/*', MagicResponse(data: null, statusCode: 200));
      fake.preventStrayRequests();

      expect(() async => fake.get('/posts/1'), throwsA(isA<StateError>()));
    });

    test(
      'matched request still works normally with preventStray enabled',
      () async {
        final fake = FakeNetworkDriver();
        final stubResponse = MagicResponse(data: {'id': 1}, statusCode: 200);
        fake.stub('users/*', stubResponse);
        fake.preventStrayRequests();

        final response = await fake.get('/users/1');

        expect(response.data, equals({'id': 1}));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // 7. RESTful methods — correct MagicRequest construction
  // ---------------------------------------------------------------------------

  group('RESTful methods record correct MagicRequest', () {
    test('index records GET with url containing /resource', () async {
      final fake = FakeNetworkDriver();

      await fake.index('users');

      final (request, _) = fake.recorded.first;
      expect(request.method, equals('GET'));
      expect(request.url, contains('/users'));
    });

    test('show records GET with url containing /resource/id', () async {
      final fake = FakeNetworkDriver();

      await fake.show('users', '1');

      final (request, _) = fake.recorded.first;
      expect(request.method, equals('GET'));
      expect(request.url, contains('/users/1'));
    });

    test('store records POST with url and data', () async {
      final fake = FakeNetworkDriver();
      final data = {'name': 'John'};

      await fake.store('users', data);

      final (request, _) = fake.recorded.first;
      expect(request.method, equals('POST'));
      expect(request.url, contains('/users'));
      expect(request.data, equals(data));
    });

    test('update records PUT with url containing /resource/id', () async {
      final fake = FakeNetworkDriver();
      final data = {'name': 'Jane'};

      await fake.update('users', '1', data);

      final (request, _) = fake.recorded.first;
      expect(request.method, equals('PUT'));
      expect(request.url, contains('/users/1'));
      expect(request.data, equals(data));
    });

    test('destroy records DELETE with url containing /resource/id', () async {
      final fake = FakeNetworkDriver();

      await fake.destroy('users', '1');

      final (request, _) = fake.recorded.first;
      expect(request.method, equals('DELETE'));
      expect(request.url, contains('/users/1'));
    });
  });

  // ---------------------------------------------------------------------------
  // 8. Upload
  // ---------------------------------------------------------------------------

  group('upload', () {
    test('records with POST method', () async {
      final fake = FakeNetworkDriver();

      await fake.upload(
        '/files',
        data: {'type': 'avatar'},
        files: {'file': 'path/to/file.jpg'},
      );

      final (request, _) = fake.recorded.first;
      expect(request.method, equals('POST'));
      expect(request.url, contains('/files'));
    });

    test('request data combines data and files maps', () async {
      final fake = FakeNetworkDriver();

      await fake.upload(
        '/files',
        data: {'description': 'My avatar'},
        files: {'photo': 'path/to/photo.png'},
      );

      final (request, _) = fake.recorded.first;
      final combined = request.data as Map<String, dynamic>;
      expect(combined, containsPair('description', 'My avatar'));
      expect(combined, containsPair('photo', 'path/to/photo.png'));
    });
  });

  // ---------------------------------------------------------------------------
  // 9. addInterceptor — no-op
  // ---------------------------------------------------------------------------

  group('addInterceptor', () {
    test('calling addInterceptor does not throw', () {
      final fake = FakeNetworkDriver();
      final interceptor = _NoOpInterceptor();

      expect(() => fake.addInterceptor(interceptor), returnsNormally);
    });
  });

  // ---------------------------------------------------------------------------
  // 10. Stub priority — later stub() calls win
  // ---------------------------------------------------------------------------

  group('stub priority', () {
    test('later stub() call overrides earlier one for same pattern', () async {
      final fake = FakeNetworkDriver();
      final response1 = MagicResponse(data: {'version': 1}, statusCode: 200);
      final response2 = MagicResponse(data: {'version': 2}, statusCode: 200);

      fake.stub('users/*', response1);
      fake.stub('users/*', response2);

      final response = await fake.get('/users/1');

      expect(response.data, equals({'version': 2}));
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

class _NoOpInterceptor extends MagicNetworkInterceptor {}
