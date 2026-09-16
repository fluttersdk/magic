import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// Pins what [MagicApplication.pageTransitionsTheme] does and, just as
/// importantly, what it leaves alone.
///
/// [RouteTransition.platform] has no animation of its own: its page mixes in
/// `MaterialRouteTransitionMixin`, which reads
/// `Theme.of(context).pageTransitionsTheme`. Unset, that is Flutter's
/// per-platform default and the whole reason the transition is called
/// `platform`. The override exists for the case a per-route value cannot
/// express, a surface that wants a different animation for every route it has.
///
/// The iOS assertions double as the back-gesture assertions, because Flutter
/// builds its edge-swipe detector INSIDE `CupertinoPageTransition` rather than
/// beside it: an override that REPLACES `TargetPlatform.iOS` with another
/// builder drops the swipe, which is the failure mode worth having a test for.
///
/// OMITTING iOS does not, and the distinction is worth stating because this
/// doc block claimed otherwise until it was read against the Flutter source.
/// An unnamed platform keeps its own default rather than falling through to a
/// shared one (`material/page_transitions_theme.dart:881-889`), so a partial
/// map is a partial override. The third test pins that, and it is the one an
/// adopter's reading of this file depends on.
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

  void registerTwoPages() {
    MagicRoute.page('/', () => const Text('home'));
    MagicRoute.page(
      '/detail',
      () => const Text('detail'),
    ).stacked().transition(RouteTransition.platform);
  }

  Future<void> pumpAndPush(
    WidgetTester tester, {
    PageTransitionsTheme? pageTransitionsTheme,
  }) async {
    registerTwoPages();

    await tester.pumpWidget(
      MagicApplication(
        title: 'test',
        pageTransitionsTheme: pageTransitionsTheme,
      ),
    );
    await tester.pumpAndSettle();

    MagicRouter.instance.to('/detail');
    await tester.pumpAndSettle();
  }

  testWidgets('unset, iOS gets the system animation and its swipe', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await pumpAndPush(tester);

      expect(find.text('detail'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('detail'),
          matching: find.byType(CupertinoPageTransition),
        ),
        findsOneWidget,
        reason:
            'the default theme should have resolved to '
            'CupertinoPageTransitionsBuilder, which is what carries the '
            'edge-swipe detector',
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('an override replaces the animation for the named platform', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await pumpAndPush(
        tester,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder()},
        ),
      );

      expect(find.text('detail'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('detail'),
          matching: find.byType(CupertinoPageTransition),
        ),
        findsNothing,
        reason:
            'the override named a different builder for iOS, so the Cupertino '
            'transition and the swipe detector inside it are both gone',
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('a platform left out of the map keeps its own default', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      // Names only macOS. If an unnamed platform fell through to a shared
      // builder, iOS would lose the Cupertino transition and the swipe
      // detector inside it; it does not.
      await pumpAndPush(
        tester,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder()},
        ),
      );

      expect(
        find.ancestor(
          of: find.text('detail'),
          matching: find.byType(CupertinoPageTransition),
        ),
        findsOneWidget,
        reason:
            'omitting a platform is not overriding it: Flutter answers an '
            'unnamed iOS with CupertinoPageTransitionsBuilder',
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('the override leaves the rest of the wind theme intact', (
    tester,
  ) async {
    late ThemeData theme;

    MagicRoute.page(
      '/',
      () => Builder(
        builder: (context) {
          theme = Theme.of(context);
          return const Text('home');
        },
      ),
    );

    await tester.pumpWidget(
      MagicApplication(
        title: 'test',
        windTheme: WindThemeData(
          colors: {
            'primary': const MaterialColor(0xFF00857F, <int, Color>{
              50: Color(0xFFE0F2F1),
              100: Color(0xFFB2DFDB),
              200: Color(0xFF80CBC4),
              300: Color(0xFF4DB6AC),
              400: Color(0xFF26A69A),
              500: Color(0xFF00857F),
              600: Color(0xFF00796B),
              700: Color(0xFF00695C),
              800: Color(0xFF004D40),
              900: Color(0xFF00382E),
            }),
          },
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder()},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // `copyWith` is the mechanism, so the risk worth pinning is that the theme
    // gets REPLACED rather than amended and the app silently loses its brand.
    // Compared as a packed value: wind hands the ColorScheme the caller's
    // MaterialColor itself, which is not `==` to a plain Color of the same
    // channels.
    expect(theme.colorScheme.primary.toARGB32(), 0xFF00857F);
    expect(
      theme.pageTransitionsTheme.builders[TargetPlatform.iOS],
      isA<FadeUpwardsPageTransitionsBuilder>(),
    );
  });
}
