import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// Pins that a routed page paints an opaque background.
///
/// It did not, for as long as `_buildPage` has existed. The wrapper was
/// `Material(type: MaterialType.canvas)`, which paints `Theme.canvasColor`
/// (`material.dart:460`), and `fluttersdk_wind` sets that to
/// `Colors.transparent` on purpose (`wind_theme_data.dart:514`) so a Material
/// surface never paints over a Wind `bg-*` className. Since every magic app
/// themes through wind, every page was transparent and the comment on that line
/// claimed the opposite.
///
/// Nothing could show it until routes started stacking: `to()` calls `go()`,
/// which replaces the whole page list, so there was never a second page
/// underneath to show through. Once a `.stacked()` route puts one there, the
/// outgoing page is visible THROUGH the incoming one for the length of the
/// push, which is what a reader on an iPhone reported as the old screen sitting
/// half-way across with the new one drawn over it.
///
/// So the assertion is on ALPHA under a real `WindThemeData`, not on the widget
/// type: a test that found a `Material` would have been green throughout.
void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();
  });

  tearDown(() {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();
  });

  testWidgets('a page under the wind theme paints an opaque background', (
    tester,
  ) async {
    late BuildContext pageContext;

    MagicRoute.page(
      '/',
      () => Builder(
        builder: (context) {
          pageContext = context;
          return const Text('page');
        },
      ),
    );

    await tester.pumpWidget(MagicApplication(title: 'test'));
    await tester.pumpAndSettle();

    // The nearest Material ABOVE the page content is the wrapper `_buildPage`
    // installs. `Material.of` returns the render object, so the widget is found
    // by walking the element tree instead.
    final Material wrapper = tester.widget<Material>(
      find
          .ancestor(of: find.byType(Text), matching: find.byType(Material))
          .first,
    );

    expect(
      wrapper.color?.a,
      1.0,
      reason:
          'a transparent page shows the page below it through the whole '
          'push animation',
    );

    // And the value it must NOT have taken. Stated as its own assertion so a
    // future theme change that makes `scaffoldBackgroundColor` transparent
    // fails on the alpha above rather than quietly reintroducing this.
    expect(
      Theme.of(pageContext).canvasColor.a,
      0.0,
      reason:
          'wind sets canvasColor transparent on purpose; if that ever stops '
          'being true, the assertion above stops proving anything',
    );
  });

  /// A different invariant, and NOT a second guard on the one above: it stays
  /// green with the transparent wrapper restored, because `opaque => true`
  /// makes the Navigator offstage the route below whatever the page paints.
  /// What it does catch is that route going non-opaque, which would leave the
  /// covered page in the tree for the life of the push.
  testWidgets('a pushed route is opaque, so the Navigator offstages below it', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      MagicRoute.page('/', () => const Text('below'));
      MagicRoute.page(
        '/detail',
        () => const Text('above'),
      ).stacked().transition(RouteTransition.platform);

      await tester.pumpWidget(MagicApplication(title: 'test'));
      await tester.pumpAndSettle();

      MagicRouter.instance.to('/detail');
      await tester.pumpAndSettle();

      expect(find.text('above'), findsOneWidget);
      expect(
        find.text('below'),
        findsNothing,
        reason:
            'the route on top is not opaque, so the covered page stays '
            'built and painted underneath it',
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
