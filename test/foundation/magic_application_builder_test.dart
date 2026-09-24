import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// Pins where [MagicApplication.builder] puts its widget and that it outlives
/// every navigation.
///
/// The parameter exists for a layer that must never be remounted while the
/// viewer moves between pages, a floating video player whose platform view
/// would restart its stream if its element were rebuilt from scratch. So the
/// assertion that matters is State identity across route changes, both a
/// replacing `to()` and a stacked push followed by `back()`, and not merely
/// that the widget is found again afterwards.
void main() {
  const layerKey = ValueKey<String>('persistent-layer');

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();
    Translator.reset();
  });

  tearDown(() {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();
    Translator.reset();
  });

  /// Register three pages: a root, a sibling reached by a replacing `to()`,
  /// and a stacked detail reached by a push.
  void registerPages() {
    MagicRoute.page('/', () => const Text('home'));
    MagicRoute.page('/other', () => const Text('other'));
    MagicRoute.page('/detail', () => const Text('detail')).stacked();
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    TransitionBuilder? builder,
  }) async {
    registerPages();

    await tester.pumpWidget(MagicApplication(title: 'test', builder: builder));
    await tester.pumpAndSettle();
  }

  Widget wrapInLayer(BuildContext context, Widget? child) {
    return _PersistentLayer(key: layerKey, child: child!);
  }

  State<_PersistentLayer> layerState(WidgetTester tester) {
    return tester.state<State<_PersistentLayer>>(find.byKey(layerKey));
  }

  testWidgets('wraps the router output above the Navigator', (tester) async {
    await pumpApp(tester, builder: wrapInLayer);

    expect(
      find.ancestor(of: find.text('home'), matching: find.byKey(layerKey)),
      findsOneWidget,
      reason: 'the routed page is the child the builder was handed',
    );
    expect(
      find.ancestor(of: find.byType(Navigator), matching: find.byKey(layerKey)),
      findsOneWidget,
      reason: 'the layer sits above the Navigator, not inside a route',
    );
    expect(
      find.ancestor(of: find.byKey(layerKey), matching: find.byType(Navigator)),
      findsNothing,
      reason: 'no route Overlay owns the layer, so no pop can remove it',
    );
    expect(
      find.ancestor(
        of: find.byKey(layerKey),
        matching: find.byType(Localizations),
      ),
      findsOneWidget,
      reason: 'the layer is inside MaterialApp, so it can read localizations',
    );

    final context = tester.element(find.byKey(layerKey));
    expect(Directionality.maybeOf(context), isNotNull);
    expect(MediaQuery.maybeOf(context), isNotNull);
    expect(
      Overlay.maybeOf(context),
      isNull,
      reason: 'the documented caveat: a tooltip in the layer needs its own',
    );
  });

  testWidgets('keeps the same State across every route change', (tester) async {
    await pumpApp(tester, builder: wrapInLayer);
    final original = layerState(tester);

    MagicRoute.to('/other');
    await tester.pumpAndSettle();
    expect(find.text('other'), findsOneWidget);
    expect(layerState(tester), same(original));

    MagicRoute.to('/detail');
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsOneWidget);
    expect(layerState(tester), same(original));

    MagicRoute.back();
    await tester.pumpAndSettle();
    expect(find.text('other'), findsOneWidget);
    expect(layerState(tester), same(original));
  });

  testWidgets('a soft restart remounts the layer with everything else', (
    tester,
  ) async {
    await pumpApp(tester, builder: wrapInLayer);
    final original = layerState(tester);

    Magic.reload();
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(
      layerState(tester),
      isNot(same(original)),
      reason: 'the documented limit: reload re-keys the whole MaterialApp',
    );
  });

  testWidgets('left null, the page renders with no wrapper', (tester) async {
    await pumpApp(tester);

    expect(find.text('home'), findsOneWidget);
    expect(find.byKey(layerKey), findsNothing);
  });
}

/// A stateful stand-in for a layer whose State must never be recreated.
class _PersistentLayer extends StatefulWidget {
  const _PersistentLayer({super.key, required this.child});

  final Widget child;

  @override
  State<_PersistentLayer> createState() => _PersistentLayerState();
}

class _PersistentLayerState extends State<_PersistentLayer> {
  @override
  Widget build(BuildContext context) => widget.child;
}
