import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

/// Reads its own route's parameters through the context-bound readers, in
/// `didChangeDependencies` as the contract asks, and renders what it saw.
class _Probe extends StatefulWidget {
  const _Probe({required this.label});

  final String label;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  String? _token;
  String? _tab;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _token = MagicRouter.instance.pathParameterOf(context, 'token');
    _tab = MagicRouter.instance.queryParameterOf(context, 'tab');
  }

  @override
  Widget build(BuildContext context) {
    return Text('${widget.label} of=$_token tab=$_tab');
  }
}

/// Tests for [MagicRouter.pathParameterOf] and [MagicRouter.queryParameterOf].
///
/// The static readers answer from the state of the last page builder to run.
/// A page pushed across layout shells is built before the shell underneath is
/// rebuilt, so that "last" state is the page UNDER the pushed one and the
/// pushed page reads another page's parameters. The context-bound readers ask
/// the enclosing route page instead.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    TitleManager.reset();
    MagicRouter.reset();
  });

  Future<void> mountTwoShells(WidgetTester tester) async {
    // Two shells, each its own layout group: a page in one is pushed over a
    // page in the other, which is the shape that makes go_router build the
    // pushed page first and the shell underneath after it.
    MagicRoute.group(
      layout: (child) => Column(children: [Expanded(child: child)]),
      routes: () {
        MagicRoute.page('/a/:token', (token) => const _Probe(label: 'A'));
      },
    );
    MagicRoute.group(
      layoutId: 'other',
      layout: (child) => Column(children: [Expanded(child: child)]),
      routes: () {
        MagicRoute.page(
          '/b/:token',
          (token) => const _Probe(label: 'B'),
        ).stacked();
      },
    );
    MagicRouter.instance.setInitialLocation('/a/token-a?tab=tab-a');

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
    );
    await tester.pumpAndSettle();
  }

  group('context-bound parameter readers', () {
    testWidgets('reads its own page when pushed over another shell', (
      tester,
    ) async {
      await mountTwoShells(tester);
      expect(find.text('A of=token-a tab=tab-a'), findsOneWidget);

      MagicRoute.to('/b/token-b?tab=tab-b');
      await tester.pumpAndSettle();

      expect(find.text('B of=token-b tab=tab-b'), findsOneWidget);
      // The defect the context-bound readers exist for: the static reader
      // answers from the page built last, which is the one underneath.
      expect(MagicRouter.instance.pathParameter('token'), 'token-a');
      expect(MagicRouter.instance.queryParameter('tab'), 'tab-a');
    });

    testWidgets('throws when no router page sits above the context', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: _Probe(label: 'bare')));

      expect(tester.takeException(), isA<GoError>());
    });
  });
}
