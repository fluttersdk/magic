import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// A plain controller whose [onInit] is NOT called from its constructor (the
/// common case: data bootstrap lives in onInit and relies on the view calling
/// it). Mirrors the magic_example showcase controllers.
class _LazyController extends MagicController with MagicStateMixin<int> {
  int initCount = 0;

  @override
  void onInit() {
    super.onInit();
    initCount++;
  }
}

/// A controller that initializes itself in its constructor (the
/// [SimpleMagicController] shape). Mounting a view must NOT call onInit again.
class _EagerController extends MagicController with MagicStateMixin<int> {
  _EagerController() {
    onInit();
  }

  int initCount = 0;

  @override
  void onInit() {
    super.onInit();
    initCount++;
  }
}

class _LazyView extends MagicStatefulView<_LazyController> {
  const _LazyView();

  @override
  State<_LazyView> createState() => _LazyViewState();
}

class _LazyViewState
    extends MagicStatefulViewState<_LazyController, _LazyView> {
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _EagerView extends MagicStatefulView<_EagerController> {
  const _EagerView();

  @override
  State<_EagerView> createState() => _EagerViewState();
}

class _EagerViewState
    extends MagicStatefulViewState<_EagerController, _EagerView> {
  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });
  tearDown(Magic.flush);

  group('MagicStatefulViewState controller.onInit', () {
    testWidgets('calls controller.onInit() once when not yet initialized', (
      tester,
    ) async {
      final controller = _LazyController();
      Magic.put<_LazyController>(controller);

      expect(controller.initialized, isFalse);
      expect(controller.initCount, 0);

      await tester.pumpWidget(const MaterialApp(home: _LazyView()));

      expect(
        controller.initialized,
        isTrue,
        reason: 'mounting the view must initialize its controller',
      );
      expect(controller.initCount, 1);
    });

    testWidgets(
      'does not double-call onInit for a self-initializing controller',
      (tester) async {
        final controller = _EagerController();
        Magic.put<_EagerController>(controller);

        // Already initialized by its own constructor.
        expect(controller.initialized, isTrue);
        expect(controller.initCount, 1);

        await tester.pumpWidget(const MaterialApp(home: _EagerView()));

        // The view must NOT call onInit a second time.
        expect(
          controller.initCount,
          1,
          reason: 'an already-initialized controller is not re-initialized',
        );
      },
    );

    testWidgets('remounting the view does not re-run controller.onInit', (
      tester,
    ) async {
      final controller = _LazyController();
      Magic.put<_LazyController>(controller);

      await tester.pumpWidget(const MaterialApp(home: _LazyView()));
      expect(controller.initCount, 1);

      // Replace then restore the view to force a fresh State + initState.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpWidget(const MaterialApp(home: _LazyView()));

      expect(
        controller.initCount,
        1,
        reason: 'onInit runs once per controller lifetime, not per mount',
      );
    });
  });
}
