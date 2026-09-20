import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// The `Url` rule, which Laravel has and this package did not.
///
/// Written against what a consumer actually validates: an address a user typed
/// into a field, which is either a usable http(s) endpoint or something to
/// send them back to fix. It is not an RFC 3986 parser and does not try to be.
void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });

  /// Runs the rule the way `FormValidator` does.
  bool passes(dynamic value, {List<String>? schemes}) =>
      (schemes == null ? const Url() : Url(schemes: schemes)).passes(
        'site',
        value,
        <String, dynamic>{'site': value},
      );

  group('what it accepts', () {
    test('an http or https address with a host', () {
      expect(passes('http://example.com'), isTrue);
      expect(passes('https://example.com'), isTrue);
      expect(passes('https://example.com/path?q=1#frag'), isTrue);
      expect(passes('http://192.168.1.10:8080/player_api.php'), isTrue);
      expect(passes('https://sub.domain.example.co.uk'), isTrue);
    });

    test('null and empty, which belong to Required', () {
      // Every other rule in this package defers the presence question, so a
      // field with `[Url()]` and no `Required()` is optional by design.
      expect(passes(null), isTrue);
      expect(passes(''), isTrue);
    });
  });

  group('what it rejects', () {
    test('an address with no scheme, which is the common typo', () {
      expect(passes('example.com'), isFalse);
      expect(passes('//example.com'), isFalse);
    });

    test('a scheme with no host', () {
      expect(passes('http://'), isFalse);
      expect(passes('https:///path'), isFalse);
    });

    test('a scheme outside the allowed set', () {
      // `Uri.parse` accepts these happily, so nothing but an explicit scheme
      // check keeps a `javascript:` or a `file:` out of a field that will be
      // turned into a network request.
      expect(passes('ftp://example.com'), isFalse);
      expect(passes('file:///etc/passwd'), isFalse);
      expect(passes('javascript:alert(1)'), isFalse);
    });

    test('a value that is not a string', () {
      expect(passes(42), isFalse);
      expect(passes(<String>['http://example.com']), isFalse);
    });

    test('something Uri.parse refuses outright', () {
      // `Uri.parse` throws rather than returning a bad Uri, and a rule that
      // let that escape would turn a typo into a crash in a form field.
      expect(passes('http://exa mple.com'), isFalse);
      expect(passes('::::'), isFalse);
    });
  });

  group('the scheme set is the caller\'s', () {
    test('a narrower set refuses http', () {
      expect(passes('http://example.com', schemes: <String>['https']), isFalse);
      expect(passes('https://example.com', schemes: <String>['https']), isTrue);
    });

    test('a wider set admits what the default refuses', () {
      expect(
        passes('ws://example.com', schemes: <String>['ws', 'wss']),
        isTrue,
      );
    });

    test('the scheme comparison ignores case, as a URI scheme does', () {
      expect(passes('HTTPS://example.com'), isTrue);
    });
  });

  test('the message is a catalogue key like every other rule', () {
    expect(const Url().message(), 'validation.url');
  });

  test('the allowed schemes reach the message as a parameter', () {
    // So a catalogue can write "must start with http:// or https://" rather
    // than a sentence that goes stale when a caller narrows the set.
    expect(const Url().params(), <String, dynamic>{'schemes': 'http, https'});
    expect(Url(schemes: const <String>['https']).params(), <String, dynamic>{
      'schemes': 'https',
    });
  });
}
