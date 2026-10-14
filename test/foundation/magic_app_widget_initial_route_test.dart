import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// Pins that the boot-phase [MaterialApp]s of [MagicApplication] ignore the
/// browser's deep path.
///
/// On web the platform's default route name is the URL path. A [MaterialApp]
/// built with `home` receives it as its initial route, finds no named route
/// for it and makes Flutter's debug assert report "Could not navigate to
/// initial route". The loading and failure screens have no routes at all, and
/// GoRouter has already captured the deep link by then, so they must show
/// their home page whatever the platform asks for.
void main() {
  const String deepPath = '/incidents/new';

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();
    Translator.reset();
    Magic.singleton('log', () => LogManager());
  });

  tearDown(() {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();
    Translator.reset();
  });

  /// Whether [error] is Flutter's "Could not navigate to initial route" report.
  bool isInitialRouteError(Object? error) =>
      error.toString().contains('Could not navigate to initial route');

  testWidgets('the loading screen shows its own page on a deep link without an '
      'initial route error', (tester) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = deepPath;
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
    MagicRoute.page('/', () => const Text('home'));
    MagicRoute.page(deepPath, () => const Text('incident form'));

    await tester.pumpWidget(const MagicApplication(title: 'test'));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final Object? error = tester.takeException();
    expect(
      isInitialRouteError(error),
      isFalse,
      reason: 'the loading screen must not take the deep path as its route',
    );

    await tester.pumpAndSettle();
    expect(
      find.text('incident form'),
      findsOneWidget,
      reason: 'GoRouter still receives the deep link once boot completes',
    );
  });

  testWidgets('the failure screen shows its own page on a deep link without an '
      'initial route error', (tester) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = deepPath;
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );

    await tester.pumpWidget(
      MagicApplication(
        title: 'test',
        onInit: () => throw StateError('boot failed'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Failed to initialize app'), findsOneWidget);
    final Object? error = tester.takeException();
    expect(
      isInitialRouteError(error),
      isFalse,
      reason: 'the failure screen must not take the deep path as its route',
    );
  });
}
