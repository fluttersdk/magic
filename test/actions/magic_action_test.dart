import 'package:flutter_test/flutter_test.dart';
import 'package:magic/src/actions/magic_action.dart';

/// A stateless action whose [handle] just echoes its input, so [resolve]'s
/// return value can be told apart from a bound override by the string it
/// produces.
class _Echo extends MagicAction<String, String> {
  const _Echo();

  @override
  Future<String> handle(String input) async => 'real:$input';
}

/// A second implementation of the same contract, bound over [_Echo] in the
/// override tests to prove [resolve] picks the bound instance, not the
/// fallback.
class _FakeEcho extends _Echo {
  const _FakeEcho();

  @override
  Future<String> handle(String input) async => 'fake:$input';
}

void main() {
  tearDown(() => MagicAction.flush());

  group('MagicAction.resolve', () {
    test('with no binding, returns the fallback instance', () async {
      final action = MagicAction.resolve(_Echo.new);

      expect(action, isA<_Echo>());
      expect(await action.handle('id'), 'real:id');
    });
  });

  group('MagicAction.bind', () {
    test('overrides resolve for the bound type', () async {
      MagicAction.bind<_Echo>(_FakeEcho.new);

      final action = MagicAction.resolve(_Echo.new);

      expect(action, isA<_FakeEcho>());
      expect(await action.handle('id'), 'fake:id');
    });

    test('does not affect resolve for a different type', () async {
      MagicAction.bind<_Echo>(_FakeEcho.new);

      final action = MagicAction.resolve(_OtherEcho.new);

      expect(action, isA<_OtherEcho>());
    });
  });

  group('MagicAction.flush', () {
    test('clears every override so resolve falls back again', () async {
      MagicAction.bind<_Echo>(_FakeEcho.new);
      MagicAction.flush();

      final action = MagicAction.resolve(_Echo.new);

      expect(action, isA<_Echo>());
      expect(action, isNot(isA<_FakeEcho>()));
    });
  });
}

/// An unrelated action, used only to prove a binding keyed by [_Echo] does
/// not leak onto a sibling type's own [MagicAction.resolve] call.
class _OtherEcho extends MagicAction<String, String> {
  const _OtherEcho();

  @override
  Future<String> handle(String input) async => input;
}
