import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

class _CountingController extends MagicController {
  int closeCount = 0;

  @override
  void onClose() {
    closeCount++;
    super.onClose();
  }
}

class _PlainService {}

/// A bare [ChangeNotifier], not a [MagicController]: its dispose is NOT
/// idempotent, so pinning [Magic.delete]'s behaviour on it also pins that a
/// caller must not dispose it again.
class _PlainNotifier extends ChangeNotifier {}

/// True once [ChangeNotifier.dispose] has run: a disposed notifier refuses
/// new listeners in debug mode.
bool _notifierDisposed(ChangeNotifier notifier) {
  try {
    notifier.addListener(() {});
  } on FlutterError {
    return true;
  }

  return false;
}

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });

  group('Magic.delete', () {
    test('removes and disposes a MagicController', () {
      final controller = Magic.put(_CountingController());

      Magic.delete<_CountingController>();

      expect(Magic.isRegistered<_CountingController>(), isFalse);
      expect(controller.isDisposed, isTrue);
      expect(controller.closeCount, 1);
      expect(_notifierDisposed(controller), isTrue);
    });

    test('a second dispose after delete is a no-op', () {
      final controller = Magic.put(_CountingController());

      Magic.delete<_CountingController>();
      controller.dispose();

      expect(controller.closeCount, 1);
    });

    test('disposes a plain ChangeNotifier that is not a MagicController', () {
      final notifier = Magic.put(_PlainNotifier());

      Magic.delete<_PlainNotifier>();

      expect(Magic.isRegistered<_PlainNotifier>(), isFalse);
      expect(_notifierDisposed(notifier), isTrue);
      expect(() => notifier.dispose(), throwsFlutterError);
    });

    test('removes a value that is not a MagicController', () {
      Magic.put(_PlainService());

      Magic.delete<_PlainService>();

      expect(Magic.isRegistered<_PlainService>(), isFalse);
    });

    test('deleting an unregistered type does nothing', () {
      expect(() => Magic.delete<_CountingController>(), returnsNormally);
    });
  });

  group('MagicController.dispose', () {
    test('runs onClose and the notifier dispose exactly once', () {
      final controller = _CountingController();

      controller.dispose();
      controller.dispose();

      expect(controller.closeCount, 1);
      expect(_notifierDisposed(controller), isTrue);
    });

    test('still disposes the notifier after a manual onClose', () {
      final controller = _CountingController();

      controller.onClose();
      expect(_notifierDisposed(controller), isFalse);

      controller.dispose();
      controller.dispose();

      expect(controller.closeCount, 1);
      expect(_notifierDisposed(controller), isTrue);
    });
  });
}
