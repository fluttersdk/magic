import '../magic_response.dart';
import 'magic_network_interceptor.dart';

/// The Network Driver interface.
///
/// All network drivers must implement this interface to ensure consistent
/// behavior across different HTTP clients.
abstract class NetworkDriver {
  /// Add an interceptor to the driver.
  void addInterceptor(MagicNetworkInterceptor interceptor);

  // ---------------------------------------------------------------------------
  // RESTful Resource Methods
  // ---------------------------------------------------------------------------

  /// Fetch all resources (GET /resource).
  Future<MagicResponse> index(
    String resource, {
    Map<String, dynamic>? filters,
    Map<String, String>? headers,
  });

  /// Fetch a single resource (GET /resource/{id}).
  Future<MagicResponse> show(
    String resource,
    String id, {
    Map<String, String>? headers,
  });

  /// Create a new resource (POST /resource).
  Future<MagicResponse> store(
    String resource,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  });

  /// Update a resource (PUT /resource/{id}).
  Future<MagicResponse> update(
    String resource,
    String id,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  });

  /// Delete a resource (DELETE /resource/{id}).
  Future<MagicResponse> destroy(
    String resource,
    String id, {
    Map<String, String>? headers,
  });

  // ---------------------------------------------------------------------------
  // Raw HTTP Methods
  // ---------------------------------------------------------------------------

  /// Perform a GET request.
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  });

  /// Perform a POST request.
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  });

  /// Perform a PUT request.
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  });

  /// Perform a DELETE request.
  Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  });

  /// Upload files via multipart form data.
  Future<MagicResponse> upload(
    String url, {
    required Map<String, dynamic> data,
    required Map<String, dynamic> files,
    Map<String, String>? headers,
  });
}
