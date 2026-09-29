import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// The barrel re-exports `package:intl`, whose `TextDirection` class shadows the
// `dart:ui` enum the bare-view hosts below need.
import 'package:magic/magic.dart' hide TextDirection;

/// Controller whose [label] the view renders, so a test can tell a rebuild
/// that read fresh state from one that did not happen.
final class CoveredController extends MagicController {
  CoveredController() {
    onInit();
  }

  String label = 'v0';

  /// Changes [label] and notifies, the way a controller write does.
  void write(String next) {
    label = next;
    refreshUI();
  }
}

/// View that counts its own builds in [builds].
final class CoveredView extends MagicStatefulView<CoveredController> {
  final ValueNotifier<int> builds;

  /// Whether the view depends on [Directionality]. A view with no inherited
  /// dependency gets no `didChangeDependencies` when it moves, only
  /// `activate`, so the move tests turn this off.
  final bool readsDirectionality;

  const CoveredView({
    super.key,
    required this.builds,
    this.readsDirectionality = true,
  });

  @override
  State<CoveredView> createState() => _CoveredViewState();
}

class _CoveredViewState
    extends MagicStatefulViewState<CoveredController, CoveredView> {
  @override
  Widget build(BuildContext context) {
    widget.builds.value++;

    // Depending on Directionality lets a test rebuild the view through an
    // inherited change instead of a controller notification.
    return Text(
      'label ${controller.label}',
      textDirection: widget.readsDirectionality
          ? Directionality.of(context)
          : TextDirection.ltr,
    );
  }
}

/// Hosts [child] under a [TickerMode] the test flips through [enabled], the
/// shape go_router gives an inactive `StatefulShellRoute` branch.
final class TickerModeHost extends StatelessWidget {
  final ValueNotifier<bool> enabled;
  final Widget child;

  const TickerModeHost({super.key, required this.enabled, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: enabled,
      builder: (BuildContext context, bool value, Widget? _) {
        return TickerMode(enabled: value, child: child);
      },
    );
  }
}

void main() {
  late CoveredController controller;
  late ValueNotifier<int> builds;
  final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    controller = CoveredController();
    Magic.put<CoveredController>(controller);
    builds = ValueNotifier<int>(0);
  });

  tearDown(() {
    Magic.flush();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: CoveredView(builds: builds),
      ),
    );
  }

  Future<void> pushOpaqueRoute(WidgetTester tester) async {
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const Text('detail'),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Mounts a dependency-free view under a first [TickerMode] and moves it,
  /// through a [GlobalKey], under a second one when [inSecond] turns true.
  Future<void> pumpMovableView(
    WidgetTester tester, {
    required ValueNotifier<bool> inSecond,
    required bool firstEnabled,
    required ValueNotifier<bool> secondEnabled,
  }) async {
    final GlobalKey viewKey = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ValueListenableBuilder<bool>(
          valueListenable: inSecond,
          builder: (BuildContext context, bool moved, Widget? _) {
            final Widget view = CoveredView(
              key: viewKey,
              builds: builds,
              readsDirectionality: false,
            );

            return Column(
              children: [
                TickerMode(
                  enabled: firstEnabled,
                  child: moved ? const SizedBox() : view,
                ),
                TickerModeHost(
                  enabled: secondEnabled,
                  child: moved ? view : const SizedBox(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  group('MagicStatefulViewState under an opaque route', () {
    testWidgets('does not rebuild while covered', (WidgetTester tester) async {
      await pumpApp(tester);
      await pushOpaqueRoute(tester);
      final int before = builds.value;

      controller.write('v1');
      controller.write('v2');
      controller.write('v3');
      await tester.pump();

      expect(builds.value, before);
    });

    testWidgets('rebuilds exactly once with fresh state when uncovered', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      await pushOpaqueRoute(tester);
      final int before = builds.value;

      controller.write('v1');
      await tester.pump();
      controller.write('v2');
      await tester.pump();
      navigator.currentState!.pop();
      await tester.pumpAndSettle();

      expect(builds.value, before + 1);
      expect(find.text('label v2'), findsOneWidget);
    });

    testWidgets('does not rebuild on uncover when nothing notified', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      await pushOpaqueRoute(tester);
      final int before = builds.value;

      navigator.currentState!.pop();
      await tester.pumpAndSettle();

      expect(builds.value, before);
    });
  });

  group('MagicStatefulViewState that is still painted', () {
    testWidgets('rebuilds immediately under a dialog', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      showDialog<void>(
        context: navigator.currentContext!,
        builder: (BuildContext context) => const Text('dialog'),
      );
      await tester.pumpAndSettle();
      final int before = builds.value;

      controller.write('v1');
      await tester.pump();

      expect(builds.value, before + 1);
      expect(find.text('label v1'), findsOneWidget);
    });

    testWidgets('rebuilds on every notify outside any Navigator', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: CoveredView(builds: builds),
        ),
      );
      expect(builds.value, 1);

      controller.write('v1');
      await tester.pump();
      controller.write('v2');
      await tester.pump();

      expect(builds.value, 3);
      expect(find.text('label v2'), findsOneWidget);
    });
  });

  group('MagicStatefulViewState under a disabled TickerMode', () {
    testWidgets('defers to one rebuild when tickers are re-enabled', (
      WidgetTester tester,
    ) async {
      final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TickerModeHost(
            enabled: enabled,
            child: CoveredView(builds: builds),
          ),
        ),
      );
      enabled.value = false;
      await tester.pump();
      final int before = builds.value;

      controller.write('v1');
      controller.write('v2');
      await tester.pump();
      expect(builds.value, before);

      enabled.value = true;
      await tester.pump();
      expect(builds.value, before + 1);
      expect(find.text('label v2'), findsOneWidget);
    });

    testWidgets('drops the deferred rebuild once a dependency rebuilt it', (
      WidgetTester tester,
    ) async {
      final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);
      final ValueNotifier<TextDirection> direction =
          ValueNotifier<TextDirection>(TextDirection.ltr);
      await tester.pumpWidget(
        ValueListenableBuilder<TextDirection>(
          valueListenable: direction,
          builder: (BuildContext context, TextDirection value, Widget? _) {
            return Directionality(
              textDirection: value,
              child: TickerModeHost(
                enabled: enabled,
                child: CoveredView(builds: builds),
              ),
            );
          },
        ),
      );
      enabled.value = false;
      await tester.pump();
      final int before = builds.value;

      controller.write('v1');
      direction.value = TextDirection.rtl;
      await tester.pump();
      expect(builds.value, before + 1);

      enabled.value = true;
      await tester.pump();
      expect(builds.value, before + 1);
      expect(find.text('label v1'), findsOneWidget);
    });

    testWidgets('drops the deferred rebuild once its parent rebuilt it', (
      WidgetTester tester,
    ) async {
      final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);
      final ValueNotifier<int> parentBuilds = ValueNotifier<int>(0);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ValueListenableBuilder<int>(
            valueListenable: parentBuilds,
            builder: (BuildContext context, int _, Widget? _) {
              return TickerModeHost(
                enabled: enabled,
                child: CoveredView(builds: builds),
              );
            },
          ),
        ),
      );
      enabled.value = false;
      await tester.pump();
      final int before = builds.value;

      controller.write('v1');
      parentBuilds.value++;
      await tester.pump();
      expect(builds.value, before + 1);

      enabled.value = true;
      await tester.pump();
      expect(builds.value, before + 1);
      expect(find.text('label v1'), findsOneWidget);
    });

    testWidgets('follows the TickerMode of its new location after a move', (
      WidgetTester tester,
    ) async {
      final ValueNotifier<bool> inSecond = ValueNotifier<bool>(false);
      final ValueNotifier<bool> secondEnabled = ValueNotifier<bool>(false);
      await pumpMovableView(
        tester,
        inSecond: inSecond,
        firstEnabled: true,
        secondEnabled: secondEnabled,
      );
      inSecond.value = true;
      await tester.pump();
      final int before = builds.value;

      controller.write('v1');
      await tester.pump();

      expect(builds.value, before);
    });

    testWidgets('keeps nothing deferred after a move rebuilt it', (
      WidgetTester tester,
    ) async {
      final ValueNotifier<bool> inSecond = ValueNotifier<bool>(false);
      final ValueNotifier<bool> secondEnabled = ValueNotifier<bool>(true);
      await pumpMovableView(
        tester,
        inSecond: inSecond,
        firstEnabled: false,
        secondEnabled: secondEnabled,
      );
      final int before = builds.value;

      controller.write('v1');
      await tester.pump();
      expect(builds.value, before);

      inSecond.value = true;
      await tester.pump();
      expect(builds.value, before + 1);
      expect(find.text('label v1'), findsOneWidget);

      secondEnabled.value = false;
      await tester.pump();
      secondEnabled.value = true;
      await tester.pump();
      expect(builds.value, before + 1);
    });
  });
}
