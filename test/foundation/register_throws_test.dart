import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// A provider whose `register()` fails the way a real one does: a missing env
/// key, a dependency that will not resolve.
class _BrokenProvider extends ServiceProvider {
  _BrokenProvider(super.app);

  @override
  void register() {
    throw StateError('APP_KEY is missing');
  }
}

/// A provider that registers fine and fails later, during boot.
class _BrokenBootProvider extends ServiceProvider {
  _BrokenBootProvider(super.app);

  @override
  void register() {}

  @override
  Future<void> boot() async {
    throw StateError('boot went wrong');
  }
}

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });

  test('a provider whose register() throws fails where the caller stands', () {
    // The register phase is synchronous by contract, and `Magic.init()` calls
    // it through a facade that does not await. If the throw were captured into
    // a returned future it would arrive later as an unhandled zone error, and
    // bootstrap would walk on with a half-built provider instead of stopping.
    final app = MagicApp.instance;

    expect(
      () => app.register(_BrokenProvider(app)),
      throwsA(isA<StateError>()),
      reason: 'the register phase must throw synchronously',
    );
  });

  test('the static facade propagates it too', () {
    // `Magic.register` is what the docs recommend, so it must not be the
    // path where the failure goes quiet.
    expect(
      () => Magic.register(_BrokenProvider(Magic.app)),
      throwsA(isA<StateError>()),
    );
  });

  test('a late boot that throws reaches an awaiting caller', () async {
    final app = MagicApp.instance;
    await app.boot();

    await expectLater(
      app.register(_BrokenBootProvider(app)),
      throwsA(isA<StateError>()),
      reason: 'the future exists so this failure has somewhere to go',
    );
  });

  test('a boot-phase throw still surfaces from boot()', () async {
    final app = MagicApp.instance;
    app.register(_BrokenBootProvider(app));

    await expectLater(app.boot(), throwsA(isA<StateError>()));
  });
}
