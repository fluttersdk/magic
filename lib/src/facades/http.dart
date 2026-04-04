import '../foundation/magic.dart';
import '../network/contracts/network_driver.dart';
import '../network/drivers/fake_network_driver.dart';
import '../network/magic_response.dart';

const Object _omitted = _Omitted();

class _Omitted {
  const _Omitted();
}

/// The HTTP Facade.
///
/// Provides static access to the network driver for making HTTP requests.
///
/// ```dart
/// final response = await Http.get('/users');
/// if (response.successful) {
///   print(response.data);
/// }
/// ```
class Http {
  static NetworkDriver get _driver => Magic.make<NetworkDriver>('network');

  // ---------------------------------------------------------------------------
  // RESTful Resource Methods
  // ---------------------------------------------------------------------------

  /// Fetch all resources (GET /resource).
  static Future<MagicResponse> index(
    String resource, {
    Map<String, dynamic>? filters,
    Map<String, String>? headers,
  }) {
    return _driver.index(resource, filters: filters, headers: headers);
  }

  /// Fetch a single resource (GET /resource/{id}).
  static Future<MagicResponse> show(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) {
    return _driver.show(resource, id, headers: headers);
  }

  /// Create a new resource (POST /resource).
  static Future<MagicResponse> store(
    String resource,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) {
    return _driver.store(resource, data, headers: headers);
  }

  /// Update a resource (PUT /resource/{id}).
  static Future<MagicResponse> update(
    String resource,
    String id,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) {
    return _driver.update(resource, id, data, headers: headers);
  }

  /// Delete a resource (DELETE /resource/{id}).
  static Future<MagicResponse> destroy(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) {
    return _driver.destroy(resource, id, headers: headers);
  }

  // ---------------------------------------------------------------------------
  // Raw HTTP Methods
  // ---------------------------------------------------------------------------

  /// Perform a GET request.
  static Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) {
    return _driver.get(url, query: query, headers: headers);
  }

  /// Perform a POST request.
  static Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) {
    return _driver.post(url, data: data, headers: headers);
  }

  /// Perform a PUT request.
  static Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) {
    return _driver.put(url, data: data, headers: headers);
  }

  /// Perform a DELETE request.
  static Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) {
    return _driver.delete(url, headers: headers);
  }

  /// Upload files via multipart form data.
  static Future<MagicResponse> upload(
    String url, {
    required Map<String, dynamic> data,
    required Map<String, dynamic> files,
    Map<String, String>? headers,
  }) {
    return _driver.upload(url, data: data, files: files, headers: headers);
  }

  // ---------------------------------------------------------------------------
  // Testing Utilities
  // ---------------------------------------------------------------------------

  /// Fake all HTTP requests for testing.
  ///
  /// Replaces the real [NetworkDriver] in the IoC container with a
  /// [FakeNetworkDriver] that returns stubbed responses and records
  /// all requests for assertion.
  ///
  /// [stubs] can be:
  /// - `null` → all requests return 200 empty response
  /// - `Map<String, MagicResponse>` → URL pattern to response mapping
  /// - `FakeRequestHandler` → callback invoked for every request
  static FakeNetworkDriver fake([dynamic stubs]) {
    final driver = FakeNetworkDriver(stubs: stubs);
    Magic.app.setInstance('network', driver);
    return driver;
  }

  /// Create a stubbed [MagicResponse] for use with [fake].
  static MagicResponse response([
    dynamic data = _omitted,
    int statusCode = 200,
  ]) {
    return MagicResponse(
      data: identical(data, _omitted) ? <String, dynamic>{} : data,
      statusCode: statusCode,
    );
  }

  /// Restore the real HTTP driver after faking.
  ///
  /// Removes the fake instance so the next `make()` resolves
  /// the original singleton binding.
  static void unfake() {
    Magic.app.removeInstance('network');
  }
}
