import 'rule.dart';

/// Contract for asynchronous validation rules.
///
/// Some rules cannot decide locally whether a value is valid. Uniqueness
/// checks, remote existence lookups, or captcha verification all need an
/// `await` before they can answer. `AsyncRule` extends [Rule] with a
/// [passesAsync] method; the synchronous [passes] is a permissive
/// placeholder that keeps sync-only validation flows working.
///
/// Validators that understand async rules should detect this subtype and
/// `await` [passesAsync] instead of relying on [passes]. See
/// [Validator.validateAsync].
///
/// ```dart
/// class Exists extends AsyncRule {
///   Exists(this.endpoint);
///   final String endpoint;
///
///   @override
///   Future<bool> passesAsync(String attr, dynamic value, Map<String, dynamic> data) async {
///     final response = await Http.get(endpoint, query: {attr: value?.toString() ?? ''});
///     return response.successful;
///   }
///
///   @override
///   String message() => 'validation.exists';
/// }
/// ```
abstract class AsyncRule extends Rule {
  /// Asynchronously determine if the rule passes.
  Future<bool> passesAsync(
    String attribute,
    dynamic value,
    Map<String, dynamic> data,
  );

  /// Synchronous fallback. Async rules pass sync validation unconditionally so
  /// the async pass can report the real outcome.
  @override
  bool passes(String attribute, dynamic value, Map<String, dynamic> data) =>
      true;
}
