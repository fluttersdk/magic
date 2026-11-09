import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// The page a layout's shell is built as.
///
/// go_router builds a `ShellRoute` that has only a `builder` as a `MaterialPage`
/// when it recognises a `MaterialApp`, and as a `NoTransitionPage` otherwise.
/// go_router 18 recognises only material_ui's `MaterialApp`, so under Flutter's
/// own the shell would silently lose its page transition. The router names the
/// page itself, so the answer does not depend on go_router's app detection.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    TitleManager.reset();
    MagicRouter.reset();
    Log.fake();
  });

  tearDown(() {
    MagicRouter.reset();
  });

  testWidgets('a layout shell is a MaterialPage under Flutter\'s MaterialApp', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    ModalRoute<dynamic>? shellRoute;

    MagicRoute.group(
      layout: (child) => Builder(
        builder: (context) {
          shellRoute = ModalRoute.of(context);

          return child;
        },
      ),
      routes: () => MagicRoute.page('/a', () => const Text('a')),
    );

    try {
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
      );
      await tester.pumpAndSettle();

      MagicRouter.instance.to('/a');
      await tester.pumpAndSettle();

      expect(find.text('a'), findsOneWidget);
      expect(shellRoute, isNotNull);
      expect(shellRoute!.settings, isA<MaterialPage<dynamic>>());
      expect(shellRoute, isA<MaterialRouteTransitionMixin<dynamic>>());
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
