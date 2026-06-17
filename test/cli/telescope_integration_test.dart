import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_telescope/telescope.dart';
import 'package:magic/src/cli/telescope_integration.dart';
import 'package:magic/src/foundation/application.dart';
import 'package:magic/src/foundation/magic.dart';
import 'package:magic/src/network/contracts/magic_network_interceptor.dart';
import 'package:magic/src/network/contracts/network_driver.dart';
import 'package:magic/src/network/magic_response.dart';

// ---------------------------------------------------------------------------
// Test-only stubs
// ---------------------------------------------------------------------------

/// [NetworkDriver] stub that captures interceptors added via [addInterceptor].
class _CapturingNetworkDriver implements NetworkDriver {
  final List<MagicNetworkInterceptor> interceptors =
      <MagicNetworkInterceptor>[];

  @override
  void addInterceptor(MagicNetworkInterceptor interceptor) {
    interceptors.add(interceptor);
  }

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) => throw UnimplementedError();

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) => throw UnimplementedError();

  @override
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) => throw UnimplementedError();

  @override
  Future<MagicResponse> delete(String url, {Map<String, String>? headers}) =>
      throw UnimplementedError();

  @override
  Future<MagicResponse> upload(
    String url, {
    required Map<String, dynamic> data,
    required Map<String, dynamic> files,
    Map<String, String>? headers,
  }) => throw UnimplementedError();

  @override
  Future<MagicResponse> index(
    String resource, {
    Map<String, dynamic>? filters,
    Map<String, String>? headers,
  }) => throw UnimplementedError();

  @override
  Future<MagicResponse> show(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) => throw UnimplementedError();

  @override
  Future<MagicResponse> store(
    String resource,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) => throw UnimplementedError();

  @override
  Future<MagicResponse> update(
    String resource,
    String id,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) => throw UnimplementedError();

  @override
  Future<MagicResponse> destroy(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) => throw UnimplementedError();
}

MagicRequest _req(String url, {String method = 'GET'}) =>
    MagicRequest(url: url, method: method);

MagicResponse _ok({int statusCode = 200}) =>
    MagicResponse(data: <String, dynamic>{}, statusCode: statusCode);

void main() {
  group('MagicHttpFacadeAdapter.pendingCount', () {
    late _CapturingNetworkDriver driver;
    late MagicHttpFacadeAdapter adapter;

    setUp(() {
      MagicApp.reset();
      Magic.flush();
      TelescopeStore.resetForTesting();
      driver = _CapturingNetworkDriver();
      Magic.bind('network', () => driver);
      adapter = MagicHttpFacadeAdapter();
    });

    tearDown(() {
      TelescopeStore.resetForTesting();
      MagicApp.reset();
      Magic.flush();
    });

    test('returns 0 BEFORE install() (interceptor not yet attached)', () {
      // Pre-install, _interceptor is null; the getter must short-circuit to 0
      // rather than throw a null deref.
      expect(adapter.pendingCount, equals(0));
    });

    test('returns 0 after install() when no requests are in flight', () {
      adapter.install();
      expect(adapter.pendingCount, equals(0));
    });

    test('returns the count of in-flight requests post-install', () {
      adapter.install();
      final interceptor = driver.interceptors.first;

      // Three requests enter without a matching response/error.
      interceptor.onRequest(_req('/a'));
      interceptor.onRequest(_req('/b'));
      interceptor.onRequest(_req('/c'));

      expect(adapter.pendingCount, equals(3));
    });

    test('decrements as responses pair with pending requests (FIFO)', () {
      adapter.install();
      final interceptor = driver.interceptors.first;

      interceptor.onRequest(_req('/a'));
      interceptor.onRequest(_req('/b'));
      expect(adapter.pendingCount, equals(2));

      interceptor.onResponse(_ok());
      expect(adapter.pendingCount, equals(1));

      interceptor.onResponse(_ok(statusCode: 204));
      expect(adapter.pendingCount, equals(0));
    });

    test(
      'returns 0 again after uninstall() clears the interceptor reference',
      () {
        adapter.install();
        final interceptor = driver.interceptors.first;

        interceptor.onRequest(_req('/a'));
        expect(adapter.pendingCount, equals(1));

        adapter.uninstall();
        // After uninstall the adapter drops its interceptor reference, so the
        // pre-install null-guard fires.
        expect(adapter.pendingCount, equals(0));
      },
    );

    test('flows through TelescopeStore.pendingHttpCount when registered', () {
      TelescopePlugin.registerHttpAdapter(adapter);
      final interceptor = driver.interceptors.first;

      interceptor.onRequest(_req('/sync'));
      interceptor.onRequest(_req('/queue'));

      expect(TelescopeStore.pendingHttpCount, equals(2));

      interceptor.onResponse(_ok());
      expect(TelescopeStore.pendingHttpCount, equals(1));
    });
  });
}
