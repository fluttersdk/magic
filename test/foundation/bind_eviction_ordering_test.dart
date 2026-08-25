import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

class _Driver {
  _Driver(this.tag);
  final String tag;
}

/// Pins the ordering rule that dropping stale instances on `bind` introduces.
///
/// `setInstance` is how every facade installs a driver or a fake
/// (`Log.setDriver`, `Auth.setDriver`, `Cache.setDriver`, `Http.setDriver`,
/// `Vault.setDriver`, `Echo.setManager`). Since `bind` now evicts whatever the
/// key already resolved to, a fake placed BEFORE the binding that owns that key
/// is discarded, and one placed after wins. That is the correct trade, but it
/// is a rule a caller has to know, so it is asserted here rather than left in
/// prose in the changelog.
void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });

  test('a fake installed AFTER the binding wins', () {
    // The ordinary order: the framework and its providers bind their keys
    // during init and registration, then a test installs its fake.
    final app = MagicApp.instance;
    app.singleton('svc', () => _Driver('real'));

    app.setInstance('svc', _Driver('fake'));

    expect(app.make<_Driver>('svc').tag, 'fake');
  });

  test('a fake installed BEFORE the binding is evicted by it', () {
    // The trap. Nothing warns, and the caller sees the real driver.
    final app = MagicApp.instance;
    app.setInstance('svc', _Driver('fake'));

    app.singleton('svc', () => _Driver('real'));

    expect(
      app.make<_Driver>('svc').tag,
      'real',
      reason: 'binding a key discards what it previously resolved to',
    );
  });

  test('a key that is only ever setInstance is never evicted', () {
    // Which is why `config` is safe: `MagicApp.init` places it with
    // setInstance and nothing binds that key.
    final app = MagicApp.instance;
    final held = _Driver('held');
    app.setInstance('only-instance', held);

    app.singleton('some-other-key', () => _Driver('unrelated'));

    expect(identical(app.make<_Driver>('only-instance'), held), isTrue);
  });

  test('bound() still reports a key that only has an instance', () {
    final app = MagicApp.instance;
    app.setInstance('svc', _Driver('fake'));

    expect(app.bound('svc'), isTrue);
  });
}
