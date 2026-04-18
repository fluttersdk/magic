import '../../facades/http.dart';
import '../../facades/log.dart';
import '../contracts/async_rule.dart';

/// Resolver signature for async uniqueness lookups.
///
/// Given the [endpoint], [field], and [value], return `true` if the value is
/// unique (available) and `false` if it is already taken.
typedef UniqueResolver =
    Future<bool> Function(String endpoint, String field, dynamic value);

/// Asynchronously validates that a value is unique by hitting a backend
/// endpoint.
///
/// The default resolver issues `GET {endpoint}?{field}={value}` and treats a
/// `{"unique": true}` (or `{"available": true}`) response body as a pass.
/// Network errors are logged and treated as passes so they never block form
/// submission; the authoritative check still happens on the server.
///
/// ```dart
/// Validator.make(data, {
///   'slug': [Required(), Unique('/validate/unique', field: 'slug')],
/// }).validateAsync();
/// ```
///
/// ## Debounce
///
/// Rapid-fire calls (typing into a field with `autovalidate`) are coalesced
/// via a per-instance debounce window. Only the last call within the window
/// actually reaches the resolver; earlier calls resolve to `true` (stale) and
/// never record errors. Set [debounce] to [Duration.zero] to disable.
///
/// ## Custom Resolver
///
/// Override the HTTP call shape with [via]:
///
/// ```dart
/// Unique('/validate/unique', field: 'slug').via((endpoint, field, value) async {
///   final response = await Http.post(endpoint, data: {field: value});
///   return response.data?['unique'] == true;
/// });
/// ```
class Unique extends AsyncRule {
  Unique(
    this.endpoint, {
    required this.field,
    this.debounce = const Duration(milliseconds: 400),
  });

  /// The endpoint to query.
  final String endpoint;

  /// The field name reported to the endpoint.
  final String field;

  /// Debounce window. Duration.zero disables debouncing.
  final Duration debounce;

  UniqueResolver? _resolver;

  int _token = 0;

  /// Swap the default HTTP resolver for a custom one.
  Unique via(UniqueResolver resolver) {
    _resolver = resolver;
    return this;
  }

  @override
  Future<bool> passesAsync(
    String attribute,
    dynamic value,
    Map<String, dynamic> data,
  ) async {
    final token = ++_token;

    if (debounce > Duration.zero) {
      await Future<void>.delayed(debounce);
      if (token != _token) {
        // A later call superseded this one while we were waiting. Treat as
        // a pass so this stale check never records an error.
        return true;
      }
    }

    final resolver = _resolver ?? _defaultResolver;

    try {
      return await resolver(endpoint, field, value);
    } catch (error) {
      Log.error('Unique rule network error', error);
      return true;
    }
  }

  Future<bool> _defaultResolver(
    String endpoint,
    String field,
    dynamic value,
  ) async {
    final response = await Http.get(
      endpoint,
      query: {field: value?.toString() ?? ''},
    );

    if (response.failed) {
      // Treat transport failures as valid; server-side validation is the
      // source of truth for uniqueness.
      return true;
    }

    final body = response.data;
    if (body is Map<String, dynamic>) {
      return body['unique'] == true || body['available'] == true;
    }

    return true;
  }

  @override
  String message() => 'validation.unique';
}
