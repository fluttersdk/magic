import 'contracts/rule.dart';
import 'exceptions/authorization_exception.dart';
import 'validator.dart';

/// Laravel-style request object — collapses the "authorize, normalize,
/// validate" ceremony every controller hand-rolls into a single class.
///
/// Subclass [FormRequest], declare [rules], optionally override [authorize]
/// for access checks and [prepared] for input normalization (trim, slugify,
/// merge defaults). Pass the raw form payload to [validate] and it returns
/// the prepared, rule-approved data:
///
/// ```dart
/// class StoreMonitorRequest extends FormRequest {
///   StoreMonitorRequest(this.actor);
///
///   final User actor;
///
///   @override
///   bool authorize() => actor.can('monitor.create');
///
///   @override
///   Map<String, dynamic> prepared(Map<String, dynamic> data) => {
///     ...data,
///     'slug': slugify(data['name'] as String? ?? ''),
///   };
///
///   @override
///   Map<String, List<Rule>> rules() => {
///     'name': [Required(), Max(120)],
///     'slug': [Required()],
///   };
/// }
///
/// // In the controller:
/// final payload = StoreMonitorRequest(Auth.user()!).validate(form.data);
/// await Http.post('/monitors', data: payload);
/// ```
///
/// Failure modes:
/// - [authorize] returns `false` → [AuthorizationException]
/// - Any rule in [rules] fails → [ValidationException] with field-keyed map
abstract class FormRequest {
  const FormRequest();

  /// The rules to apply to the prepared payload.
  Map<String, List<Rule>> rules();

  /// Authorization gate — override to return `false` to block the request.
  bool authorize() => true;

  /// Normalize the incoming payload before validation runs. Default is a
  /// pass-through. Use this for trim/slugify/inject-defaults work so rules
  /// always see consistent input.
  Map<String, dynamic> prepared(Map<String, dynamic> data) => data;

  /// Run authorize → prepare → validate. Returns the prepared payload,
  /// filtered to the keys declared in [rules] (same contract as
  /// `Validator.validate`).
  ///
  /// Throws:
  /// - [AuthorizationException] when [authorize] returns `false`
  /// - `ValidationException` when a rule fails
  Map<String, dynamic> validate(Map<String, dynamic> data) {
    if (!authorize()) {
      throw const AuthorizationException();
    }

    final normalized = prepared(data);
    return Validator.make(normalized, rules()).validate();
  }
}
