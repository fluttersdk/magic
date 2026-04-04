import '../contracts/magic_network_interceptor.dart';
import '../contracts/network_driver.dart';
import '../magic_response.dart';

/// Callback signature for dynamic request handling.
typedef FakeRequestHandler = MagicResponse Function(MagicRequest request);

/// Thrown when a stray request is made while [FakeNetworkDriver.preventStrayRequests] is enabled.
///
/// Extends [StateError] for compatibility with tests asserting [StateError],
/// and implements [Exception] for compatibility with tests asserting [Exception].
class StrayRequestException extends StateError implements Exception {
  StrayRequestException(super.message);
}

/// A fake network driver for testing.
///
/// Records all requests and allows stubbing responses via URL patterns,
/// maps, or callback handlers. Inspired by Laravel's `Http::fake()`.
///
/// ```dart
/// final fake = FakeNetworkDriver();
/// fake.stub('users/*', MagicResponse(data: {'id': 1}, statusCode: 200));
///
/// final response = await fake.get('/users/42');
/// fake.assertSent((r) => r.url.contains('users'));
/// ```
class FakeNetworkDriver implements NetworkDriver {
  /// Recorded request/response pairs.
  final List<(MagicRequest, MagicResponse)> recorded = [];

  final List<_Stub> _stubs = [];
  bool _preventStrayRequests = false;

  /// Creates a [FakeNetworkDriver].
  ///
  /// [stubs] accepts:
  /// - `null` — all requests return 200 with empty data
  /// - `Map<String, MagicResponse>` — URL pattern to response mapping
  /// - `FakeRequestHandler` — callback receiving [MagicRequest], returning [MagicResponse]
  FakeNetworkDriver({dynamic stubs}) {
    if (stubs is Map<String, MagicResponse>) {
      for (final entry in stubs.entries) {
        _stubs.add(_Stub.pattern(entry.key, entry.value));
      }
    } else if (stubs is FakeRequestHandler) {
      _stubs.add(_Stub.callback(stubs));
    }
  }

  /// Register a URL pattern stub.
  ///
  /// Later calls take priority over earlier ones (inserted at index 0).
  FakeNetworkDriver stub(String urlPattern, MagicResponse response) {
    _stubs.insert(0, _Stub.pattern(urlPattern, response));
    return this;
  }

  /// Enable strict mode — unmatched requests throw [StrayRequestException].
  FakeNetworkDriver preventStrayRequests() {
    _preventStrayRequests = true;
    return this;
  }

  // ---------------------------------------------------------------------------
  // Assertions
  // ---------------------------------------------------------------------------

  /// Assert that at least one recorded request matches [predicate].
  void assertSent(bool Function(MagicRequest request) predicate) {
    if (!recorded.any((entry) => predicate(entry.$1))) {
      throw AssertionError('Expected a matching request but none was found.');
    }
  }

  /// Assert that no recorded request matches [predicate].
  void assertNotSent(bool Function(MagicRequest request) predicate) {
    if (recorded.any((entry) => predicate(entry.$1))) {
      throw AssertionError('Expected no matching request but one was found.');
    }
  }

  /// Assert that no requests were recorded at all.
  void assertNothingSent() {
    if (recorded.isNotEmpty) {
      throw AssertionError(
        'Expected no requests but ${recorded.length} were recorded.',
      );
    }
  }

  /// Assert that exactly [expected] requests were recorded.
  void assertSentCount(int expected) {
    if (recorded.length != expected) {
      throw AssertionError(
        'Expected $expected requests but ${recorded.length} were recorded.',
      );
    }
  }

  /// Reset all recorded requests for reuse.
  void reset() {
    recorded.clear();
    _stubs.clear();
    _preventStrayRequests = false;
  }

  // ---------------------------------------------------------------------------
  // NetworkDriver — Raw HTTP Methods
  // ---------------------------------------------------------------------------

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    return _handle(
      MagicRequest(
        url: url,
        method: 'GET',
        headers: headers ?? const {},
        queryParameters: query,
      ),
    );
  }

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    return _handle(
      MagicRequest(
        url: url,
        method: 'POST',
        headers: headers ?? const {},
        data: data,
      ),
    );
  }

  @override
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    return _handle(
      MagicRequest(
        url: url,
        method: 'PUT',
        headers: headers ?? const {},
        data: data,
      ),
    );
  }

  @override
  Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) async {
    return _handle(
      MagicRequest(url: url, method: 'DELETE', headers: headers ?? const {}),
    );
  }

  @override
  Future<MagicResponse> upload(
    String url, {
    required Map<String, dynamic> data,
    required Map<String, dynamic> files,
    Map<String, String>? headers,
  }) async {
    return _handle(
      MagicRequest(
        url: url,
        method: 'POST',
        headers: headers ?? const {},
        data: <String, dynamic>{...data, ...files},
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // NetworkDriver — RESTful Resource Methods
  // ---------------------------------------------------------------------------

  @override
  Future<MagicResponse> index(
    String resource, {
    Map<String, dynamic>? filters,
    Map<String, String>? headers,
  }) async {
    return get('/$resource', query: filters, headers: headers);
  }

  @override
  Future<MagicResponse> show(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async {
    return get('/$resource/$id', headers: headers);
  }

  @override
  Future<MagicResponse> store(
    String resource,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async {
    return post('/$resource', data: data, headers: headers);
  }

  @override
  Future<MagicResponse> update(
    String resource,
    String id,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async {
    return put('/$resource/$id', data: data, headers: headers);
  }

  @override
  Future<MagicResponse> destroy(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async {
    return delete('/$resource/$id', headers: headers);
  }

  // ---------------------------------------------------------------------------
  // NetworkDriver — Interceptor (no-op)
  // ---------------------------------------------------------------------------

  @override
  void addInterceptor(MagicNetworkInterceptor interceptor) {
    // No-op for fake driver.
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  MagicResponse _handle(MagicRequest request) {
    for (final stub in _stubs) {
      final response = stub.match(request);
      if (response != null) {
        recorded.add((request, response));
        return response;
      }
    }

    if (_preventStrayRequests) {
      throw StrayRequestException(
        'Unexpected request: ${request.method} ${request.url}. '
        'No matching stub found and stray requests are prevented.',
      );
    }

    final defaultResponse = MagicResponse(
      data: <String, dynamic>{},
      statusCode: 200,
    );
    recorded.add((request, defaultResponse));
    return defaultResponse;
  }
}

// ---------------------------------------------------------------------------
// Private stub matcher
// ---------------------------------------------------------------------------

class _Stub {
  final RegExp? _pattern;
  final MagicResponse? _response;
  final FakeRequestHandler? _handler;

  _Stub.pattern(String pattern, MagicResponse response)
    : _pattern = RegExp('^${RegExp.escape(pattern).replaceAll(r'\*', '.*')}\$'),
      _response = response,
      _handler = null;

  _Stub.callback(FakeRequestHandler handler)
    : _pattern = null,
      _response = null,
      _handler = handler;

  MagicResponse? match(MagicRequest request) {
    if (_handler != null) {
      return _handler(request);
    }

    // Strip leading slash for matching, try both with and without.
    final url = request.url;
    final normalizedUrl = url.startsWith('/') ? url.substring(1) : url;

    final pattern = _pattern!;
    if (pattern.hasMatch(url) || pattern.hasMatch(normalizedUrl)) {
      return _response;
    }

    return null;
  }
}
