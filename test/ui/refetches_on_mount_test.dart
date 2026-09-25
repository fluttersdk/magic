import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// A controller that counts how often its data was fetched, and (like a real
/// list-backed controller) loads once from magic's `onInit`.
class _CountingController extends MagicController {
  int fetches = 0;

  @override
  void onInit() {
    super.onInit();
    reload();
  }

  Future<void> reload() async {
    fetches++;
  }
}

class _CountingView extends MagicStatefulView<_CountingController> {
  const _CountingView();

  @override
  State<_CountingView> createState() => _CountingViewState();
}

class _CountingViewState
    extends MagicStatefulViewState<_CountingController, _CountingView>
    with RefetchesOnMount<_CountingController, _CountingView> {
  @override
  void initState() {
    Magic.findOrPut(_CountingController.new);
    super.initState();
  }

  @override
  Future<void> refetch() => controller.reload();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// The same view WITHOUT the mixin, present to prove the mixin is what makes
/// the difference rather than some property of the harness.
class _PlainView extends MagicStatefulView<_CountingController> {
  const _PlainView();

  @override
  State<_PlainView> createState() => _PlainViewState();
}

class _PlainViewState
    extends MagicStatefulViewState<_CountingController, _PlainView> {
  @override
  void initState() {
    Magic.findOrPut(_CountingController.new);
    super.initState();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });

  tearDown(() {
    MagicApp.reset();
    Magic.flush();
  });

  testWidgets('a remount refetches, so re-entering a route is never stale', (
    tester,
  ) async {
    // magic caches controllers as Type-keyed singletons and fires `onInit` once
    // per controller INSTANCE, so without this mixin the second mount serves the
    // data fetched by the first.
    await tester.pumpWidget(const _CountingView());
    await tester.pump();

    final _CountingController controller = Magic.find<_CountingController>();
    final int afterFirstMount = controller.fetches;
    expect(afterFirstMount, greaterThan(0));

    // Unmount, then mount the same view type again: the container hands back the
    // SAME controller instance, so `onInit` does not fire a second time.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(const _CountingView());
    await tester.pump();

    expect(
      Magic.find<_CountingController>().fetches,
      greaterThan(afterFirstMount),
      reason:
          'the second mount must fetch again, not serve the first '
          'mount\'s data',
    );
  });

  testWidgets('without the mixin a remount does NOT refetch', (tester) async {
    // Pins the mechanism the mixin works around, so a future change to magic's
    // controller lifecycle that makes `onInit` fire per mount shows up here as a
    // failure rather than leaving the mixin silently redundant.
    await tester.pumpWidget(const _PlainView());
    await tester.pump();

    final int afterFirstMount = Magic.find<_CountingController>().fetches;

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(const _PlainView());
    await tester.pump();

    expect(
      Magic.find<_CountingController>().fetches,
      equals(afterFirstMount),
      reason:
          'onInit fires once per controller instance, which is exactly why '
          'RefetchesOnMount exists',
    );
  });
}
