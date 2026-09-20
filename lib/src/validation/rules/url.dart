import '../contracts/rule.dart';

/// The Url Rule.
///
/// Validates that the field is an address the app could actually make a
/// request to. Laravel has `url`; this package did not, so every consumer
/// validating a typed-in endpoint wrote the same `startsWith('http://')` pair
/// by hand and each one drew its own conclusion about a scheme it had not
/// thought of.
///
/// ## Usage
///
/// ```dart
/// validate(data, {
///   'website': [Required(), Url()],
///   'webhook': [Url(schemes: ['https'])],
/// });
/// ```
///
/// ## What it checks, and what it deliberately does not
///
/// A scheme from [schemes] and a non-empty host. That is what separates an
/// address a request can be built from, from the two things a user actually
/// types: a bare `example.com` with no scheme, and a `https://` with nothing
/// after it.
///
/// It is not an RFC 3986 parser and does not try to be. It does not reach the
/// network, does not resolve the host, and takes no view on whether the path
/// exists: a rule that answers a form field synchronously cannot know any of
/// that, and a rule that pretended to would be wrong in the direction that
/// blocks a valid address.
///
/// **The scheme check is the security-shaped half.** `Uri.parse` accepts
/// `javascript:alert(1)` and `file:///etc/passwd` without complaint, and both
/// have a scheme and parse cleanly. Nothing but an explicit allowlist keeps
/// them out of a field whose value becomes a request or a link.
class Url extends Rule {
  /// The schemes an address may carry, compared case insensitively.
  ///
  /// `http` and `https` by default, which is what a field asking for an
  /// address means in practice. Narrow it to `['https']` for anything
  /// carrying a credential; widen it for `ws`, and know that every scheme
  /// added is one the rest of the app then has to handle.
  final List<String> schemes;

  /// Creates a [Url] rule.
  const Url({this.schemes = const <String>['http', 'https']});

  /// Any whitespace, which a typed address never legitimately carries.
  static final RegExp _whitespace = RegExp(r'\s');

  @override
  bool passes(String attribute, dynamic value, Map<String, dynamic> data) {
    if (value == null) return true; // Let Required handle null
    if (value is! String) return false;
    if (value.isEmpty) return true; // Let Required handle empty

    // Whitespace, checked before parsing because `Uri` does not treat it as an
    // error. Measured: `Uri.tryParse('http://exa mple.com')` succeeds and
    // percent-encodes the space into the host as `exa%20mple.com`, so the
    // parse alone would admit an address no DNS lookup can ever resolve.
    // Laravel's `url` rejects it, via `FILTER_VALIDATE_URL`.
    if (_whitespace.hasMatch(value)) return false;

    final Uri? parsed = Uri.tryParse(value);

    // `tryParse` answers null rather than throwing, which is what keeps a
    // typo in a form field from becoming an exception in a validator.
    if (parsed == null) return false;

    // An empty host is what separates `https://example.com` from the two
    // shapes that parse cleanly and address nothing: `https://` on its own,
    // and `javascript:alert(1)`.
    if (parsed.host.isEmpty) return false;

    return schemes.any(
      (String scheme) => scheme.toLowerCase() == parsed.scheme.toLowerCase(),
    );
  }

  @override
  String message() => 'validation.url';

  @override
  Map<String, dynamic> params() => <String, dynamic>{
    'schemes': schemes.join(', '),
  };
}
