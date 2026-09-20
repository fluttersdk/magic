import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// Serves one catalogue from a map.
class _MapLoader implements TranslationLoader {
  _MapLoader(this._sentences);

  final Map<String, dynamic> _sentences;

  @override
  Future<Map<String, dynamic>> load(Locale locale) async =>
      Map<String, dynamic>.from(_sentences);
}

/// A per-call-site message, which Laravel has and this package did not.
///
/// `Validator::make($data, $rules, $messages)` is the third argument in
/// Laravel and there was no equivalent here: a rule's message came from its
/// own `message()` key and nothing else. A consumer whose screen wants
/// "Şifre gerekli." rather than the catalogue's generic ":attribute alanı
/// zorunludur." had to abandon the rules entirely and hand-roll a closure,
/// which is exactly what the rules exist to stop.
void main() {
  setUp(() async {
    MagicApp.reset();
    Magic.flush();
    Translator.reset();

    Translator.instance.setLoader(
      _MapLoader(<String, dynamic>{
        'validation.required': 'The :attribute field is required.',
        'validation.url': 'The :attribute must start with :schemes.',
        'fields.panel_address': 'Panel address',
        'attributes.password': 'password',
      }),
    );

    await Translator.instance.load(const Locale('en'));
  });

  test('without an override the rule keeps its own catalogue message', () {
    final String? Function(String?) validate = FormValidator.rules<String>(
      <Rule>[const Required()],
      field: 'password',
    );

    expect(validate(''), 'The password field is required.');
  });

  test('an override replaces it, resolved through the catalogue', () {
    // A KEY rather than a sentence, so the override is localised too. An
    // override that took a finished sentence would make every consumer using
    // it monolingual, which is the opposite of the point.
    final String? Function(String?) validate = FormValidator.rules<String>(
      <Rule>[const Required()],
      field: 'address',
      messages: <String, String>{'required': 'fields.panel_address'},
    );

    expect(validate(''), 'Panel address');
  });

  test('a key with no sentence falls through to itself, as trans does', () {
    final String? Function(String?) validate = FormValidator.rules<String>(
      <Rule>[const Required()],
      field: 'address',
      messages: <String, String>{'required': 'nothing.here'},
    );

    expect(validate(''), 'nothing.here');
  });

  test('the override is keyed by rule, so only the named one changes', () {
    // The case that makes this worth a map rather than a single string: a
    // field with two rules wants its own wording for one of them and the
    // catalogue's for the other.
    final String? Function(String?) validate = FormValidator.rules<String>(
      <Rule>[const Required(), const Url()],
      field: 'address',
      messages: <String, String>{'required': 'fields.panel_address'},
    );

    expect(validate(''), 'Panel address');
    expect(validate('not-a-url'), 'The address must start with http, https.');
  });

  test('an override still receives the rule parameters', () {
    final String? Function(String?) validate = FormValidator.rules<String>(
      <Rule>[
        const Url(schemes: <String>['https']),
      ],
      field: 'hook',
      messages: <String, String>{'url': 'validation.url'},
    );

    expect(validate('http://example.com'), 'The hook must start with https.');
  });

  test('an unrelated key in the map is ignored rather than throwing', () {
    // A map is data and a stale entry in one must not crash a form field.
    final String? Function(String?) validate = FormValidator.rules<String>(
      <Rule>[const Required()],
      field: 'address',
      messages: <String, String>{'email': 'fields.panel_address'},
    );

    expect(validate(''), 'The address field is required.');
  });
}
