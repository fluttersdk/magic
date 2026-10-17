import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// The debug diagnostic for a host that split one shell in two.
///
/// Two ShellRoutes whose layouts build the same widget type tear the shell
/// down on every crossing, so the router says so once per type in debug.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  late DebugPrintCallback originalDebugPrint;
  late List<String> printed;

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    TitleManager.reset();
    MagicRouter.reset();
    Log.fake();

    originalDebugPrint = debugPrint;
    printed = [];
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null && message.contains('as separate shells')) {
        printed.add(message);
      }
    };
  });

  tearDown(() {
    debugPrint = originalDebugPrint;
    MagicRouter.reset();
  });

  /// Mounts the router and visits [paths] in order.
  ///
  /// `debugPrint` is handed back before returning: flutter_test checks that
  /// it is restored when the test body ends, which is before `tearDown` runs.
  Future<void> visit(WidgetTester tester, List<String> paths) async {
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
    );
    await tester.pumpAndSettle();

    for (final path in paths) {
      MagicRouter.instance.to(path);
      await tester.pumpAndSettle();
    }

    debugPrint = originalDebugPrint;
  }

  group('duplicate shell diagnostic', () {
    testWidgets('same widget type in two shells prints exactly once', (
      tester,
    ) async {
      MagicRoute.group(
        layout: (child) => _ShellA(child: child),
        routes: () => MagicRoute.page('/a', () => const Text('a')),
      );
      MagicRoute.group(
        layout: (child) => _ShellA(child: child),
        routes: () => MagicRoute.page('/b', () => const Text('b')),
      );

      await visit(tester, ['/a', '/b', '/a', '/b']);

      expect(printed, hasLength(1));
      expect(printed.single, contains('_ShellA'));
      expect(printed.single, contains('same layoutId'));
    });

    testWidgets('different widget types print nothing', (tester) async {
      MagicRoute.group(
        layout: (child) => _ShellA(child: child),
        routes: () => MagicRoute.page('/a', () => const Text('a')),
      );
      MagicRoute.group(
        layout: (child) => _ShellB(child: child),
        routes: () => MagicRoute.page('/b', () => const Text('b')),
      );

      await visit(tester, ['/a', '/b']);

      expect(printed, isEmpty);
    });

    testWidgets('one shared-id shell prints nothing', (tester) async {
      MagicRoute.group(
        layoutId: 'app',
        layout: (child) => _ShellA(child: child),
        routes: () => MagicRoute.page('/a', () => const Text('a')),
      );
      MagicRoute.group(
        layoutId: 'app',
        layout: (child) => _ShellA(child: child),
        routes: () => MagicRoute.page('/b', () => const Text('b')),
      );

      await visit(tester, ['/a', '/b']);

      expect(printed, isEmpty);
    });
  });
}

class _ShellA extends StatelessWidget {
  const _ShellA({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class _ShellB extends StatelessWidget {
  const _ShellB({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
