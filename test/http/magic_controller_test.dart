import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

// Test controller with MagicStateMixin
class TestController extends MagicController with MagicStateMixin<String> {
  TestController() {
    onInit();
  }
}

// For fetchList tests — T is List<Map<String, dynamic>>
class _ListController extends MagicController
    with MagicStateMixin<List<Map<String, dynamic>>> {
  _ListController() {
    onInit();
  }
}

// For fetchOne tests — T is Map<String, dynamic>
class _SingleController extends MagicController
    with MagicStateMixin<Map<String, dynamic>> {
  _SingleController() {
    onInit();
  }
}

void main() {
  group('MagicStateMixin', () {
    late TestController controller;

    setUp(() {
      controller = TestController();
    });

    test('initial state is empty', () {
      expect(controller.isEmpty, isTrue);
      expect(controller.isLoading, isFalse);
      expect(controller.isSuccess, isFalse);
      expect(controller.isError, isFalse);
    });

    test('setLoading changes state to loading', () {
      controller.setLoading();
      expect(controller.isLoading, isTrue);
      expect(controller.isEmpty, isFalse);
    });

    test('setSuccess changes state to success with data', () {
      controller.setSuccess('test data');
      expect(controller.isSuccess, isTrue);
      expect(controller.rxState, equals('test data'));
    });

    test('setError changes state to error', () {
      controller.setError('error message');
      expect(controller.isError, isTrue);
      expect(controller.rxStatus.message, equals('error message'));
    });

    test('setEmpty changes state to empty', () {
      controller.setSuccess('data');
      controller.setEmpty();
      expect(controller.isEmpty, isTrue);
      expect(controller.rxState, isNull);
    });

    test('error state can be checked and cleared', () {
      // Set error state
      controller.setError('Login failed');

      // Verify error state is set
      expect(controller.isError, isTrue);
      expect(controller.rxStatus.message, equals('Login failed'));

      // Clear error by setting empty
      controller.setEmpty();

      // Verify error state is cleared
      expect(controller.isError, isFalse);
      expect(controller.isEmpty, isTrue);
    });

    test('error state persists until explicitly cleared', () {
      controller.setError('Persistent error');

      // Error should persist after multiple checks
      expect(controller.isError, isTrue);
      expect(controller.isError, isTrue);
      expect(controller.rxStatus.message, equals('Persistent error'));

      // Only setEmpty/setLoading/setSuccess should clear it
      expect(controller.isError, isTrue);
    });
  });

  group('MagicController lifecycle', () {
    test('onInit is called during construction', () {
      final controller = TestController();
      expect(controller.initialized, isTrue);
    });

    test('dispose sets isDisposed to true', () {
      final controller = TestController();
      expect(controller.isDisposed, isFalse);
      controller.dispose();
      expect(controller.isDisposed, isTrue);
    });
  });

  group('MagicStateMixin.fetchList', () {
    late _ListController controller;

    setUp(() {
      MagicApp.reset();
      Magic.flush();
      controller = _ListController();
    });

    tearDown(() {
      Http.unfake();
    });

    test('success: sets isSuccess and rxState with mapped list', () async {
      Http.fake({
        'items': Http.response({
          'data': [
            {'id': 1, 'name': 'A'},
            {'id': 2, 'name': 'B'},
          ],
        }, 200),
      });

      await controller.fetchList<Map<String, dynamic>>('items', (m) => m);

      expect(controller.isSuccess, isTrue);
      expect(controller.rxState, isNotNull);
      expect(controller.rxState!.length, equals(2));
    });

    test('empty list: sets isEmpty when data array is empty', () async {
      Http.fake({
        'items': Http.response({'data': []}, 200),
      });

      await controller.fetchList<Map<String, dynamic>>('items', (m) => m);

      expect(controller.isEmpty, isTrue);
    });

    test('null data key: sets isEmpty when data value is null', () async {
      Http.fake({
        'items': Http.response({'data': null}, 200),
      });

      await controller.fetchList<Map<String, dynamic>>('items', (m) => m);

      expect(controller.isEmpty, isTrue);
    });

    test('error response: sets isError with server message', () async {
      Http.fake({
        'items': Http.response({'message': 'Server error'}, 500),
      });

      await controller.fetchList<Map<String, dynamic>>('items', (m) => m);

      expect(controller.isError, isTrue);
      expect(controller.rxStatus.message, contains('Server error'));
    });

    test('custom dataKey: reads list from specified key', () async {
      Http.fake({
        'items': Http.response({
          'results': [
            {'id': 1},
          ],
        }, 200),
      });

      await controller.fetchList<Map<String, dynamic>>(
        'items',
        (m) => m,
        dataKey: 'results',
      );

      expect(controller.isSuccess, isTrue);
      expect(controller.rxState!.length, equals(1));
    });

    test('query params: forwards query parameters to the request', () async {
      Http.fake({
        'items': (request) {
          expect(request.queryParameters['page'], equals('2'));
          expect(request.queryParameters['limit'], equals('10'));
          return Http.response({'data': []}, 200);
        },
      });

      await controller.fetchList<Map<String, dynamic>>(
        'items',
        (m) => m,
        query: {'page': '2', 'limit': '10'},
      );
    });

    test('headers: forwards custom headers to the request', () async {
      Http.fake({
        'items': (request) {
          expect(request.headers['X-Custom-Header'], equals('test-value'));
          return Http.response({'data': []}, 200);
        },
      });

      await controller.fetchList<Map<String, dynamic>>(
        'items',
        (m) => m,
        headers: {'X-Custom-Header': 'test-value'},
      );
    });

    test('loading state: completes with success after loading phase', () async {
      Http.fake({
        'items': Http.response({
          'data': [
            {'id': 1},
          ],
        }, 200),
      });

      await controller.fetchList<Map<String, dynamic>>('items', (m) => m);

      // After awaiting, final state is success (went through loading internally)
      expect(controller.isSuccess, isTrue);
      expect(controller.isLoading, isFalse);
    });
  });

  group('MagicStateMixin.fetchOne', () {
    late _SingleController controller;

    setUp(() {
      MagicApp.reset();
      Magic.flush();
      controller = _SingleController();
    });

    tearDown(() {
      Http.unfake();
    });

    test('success: sets isSuccess and rxState with mapped object', () async {
      Http.fake({
        'user': Http.response({
          'data': {'id': 1, 'name': 'Alice'},
        }, 200),
      });

      await controller.fetchOne('user', (m) => m);

      expect(controller.isSuccess, isTrue);
      expect(controller.rxState, isNotNull);
      expect(controller.rxState!['id'], equals(1));
      expect(controller.rxState!['name'], equals('Alice'));
    });

    test('null data: sets isError with "Resource not found" message', () async {
      Http.fake({
        'user': Http.response({'data': null}, 200),
      });

      await controller.fetchOne('user', (m) => m);

      expect(controller.isError, isTrue);
      expect(controller.rxStatus.message, equals('Resource not found'));
    });

    test('error response: sets isError with server message', () async {
      Http.fake({
        'user': Http.response({'message': 'Not found'}, 404),
      });

      await controller.fetchOne('user', (m) => m);

      expect(controller.isError, isTrue);
      expect(controller.rxStatus.message, contains('Not found'));
    });

    test('custom dataKey: reads object from specified key', () async {
      Http.fake({
        'user': Http.response({
          'item': {'id': 1},
        }, 200),
      });

      await controller.fetchOne('user', (m) => m, dataKey: 'item');

      expect(controller.isSuccess, isTrue);
      expect(controller.rxState!['id'], equals(1));
    });

    test('query and headers: forwards both to the request', () async {
      Http.fake({
        'user': (request) {
          expect(request.queryParameters['include'], equals('profile'));
          expect(request.headers['Authorization'], equals('Bearer token'));
          return Http.response({
            'data': {'id': 1},
          }, 200);
        },
      });

      await controller.fetchOne(
        'user',
        (m) => m,
        query: {'include': 'profile'},
        headers: {'Authorization': 'Bearer token'},
      );
    });

    test('loading state: completes with success after loading phase', () async {
      Http.fake({
        'user': Http.response({
          'data': {'id': 1, 'name': 'Alice'},
        }, 200),
      });

      await controller.fetchOne('user', (m) => m);

      expect(controller.isSuccess, isTrue);
      expect(controller.isLoading, isFalse);
    });

    test('non-map response data: sets isError with format message', () async {
      Http.fake({'user': Http.response('plain string', 200)});

      await controller.fetchOne('user', (m) => m);

      expect(controller.isError, isTrue);
      expect(controller.rxStatus.message, contains('Invalid response'));
    });

    test('non-map data under dataKey: sets isError', () async {
      Http.fake({
        'user': Http.response({'data': 'not a map'}, 200),
      });

      await controller.fetchOne('user', (m) => m);

      expect(controller.isError, isTrue);
      expect(controller.rxStatus.message, contains('Invalid response'));
    });
  });

  group('MagicStateMixin.fetchList — defensive', () {
    late _ListController controller;

    setUp(() {
      MagicApp.reset();
      Magic.flush();
      controller = _ListController();
    });

    tearDown(() {
      Http.unfake();
    });

    test('non-map response data: sets isEmpty', () async {
      Http.fake({'items': Http.response('plain string', 200)});

      await controller.fetchList<Map<String, dynamic>>('items', (m) => m);

      expect(controller.isEmpty, isTrue);
    });

    test('non-list data under dataKey: sets isEmpty', () async {
      Http.fake({
        'items': Http.response({'data': 'not a list'}, 200),
      });

      await controller.fetchList<Map<String, dynamic>>('items', (m) => m);

      expect(controller.isEmpty, isTrue);
    });
  });
}
