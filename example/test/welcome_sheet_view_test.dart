import 'package:example/resources/views/welcome_sheet_view.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

const _screen = Size(1440, 900);

/// Opens [WelcomeSheetView] in the frame an overlay route builds: a bare
/// `DialogRoute` or a transparent, scroll-controlled modal bottom sheet.
Future<void> _open(WidgetTester tester, {required bool dialog}) async {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  late BuildContext context;

  await tester.pumpWidget(
    WindTheme(
      data: WindThemeData(),
      child: MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;

            return const SizedBox();
          },
        ),
      ),
    ),
  );

  if (dialog) {
    showDialog<void>(
      context: context,
      useSafeArea: false,
      builder: (_) => const WelcomeSheetView(),
    );
  } else {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const WelcomeSheetView(),
    );
  }

  await tester.pumpAndSettle();
}

/// The painted card: the outermost rounded box of the panel. The panel's own
/// `WDiv` is wider, because `mx-auto` wraps it in a box that takes the room.
Finder _card() => find
    .descendant(
      of: find.byType(WDiv).first,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).borderRadius != null,
      ),
    )
    .first;

Rect _panel(WidgetTester tester) => tester.getRect(_card());

BorderRadius _corners(WidgetTester tester) =>
    (tester.widget<DecoratedBox>(_card()).decoration as BoxDecoration)
            .borderRadius!
        as BorderRadius;

void main() {
  group('WelcomeSheetView', () {
    testWidgets('is a centred card with four rounded corners in a dialog', (
      tester,
    ) async {
      await _open(tester, dialog: true);

      final panel = _panel(tester);

      expect(panel.width, 480);
      expect(panel.height, lessThan(_screen.height));
      expect(panel.center.dx, closeTo(_screen.width / 2, 1));
      expect(panel.center.dy, closeTo(_screen.height / 2, 1));
      expect(_corners(tester).bottomLeft.x, greaterThan(0));
      expect(_corners(tester).topLeft.x, greaterThan(0));
    });

    testWidgets('sits on the bottom edge with top corners in a sheet', (
      tester,
    ) async {
      await _open(tester, dialog: false);

      final panel = _panel(tester);

      expect(panel.width, 480);
      expect(panel.bottom, _screen.height);
      expect(panel.center.dx, closeTo(_screen.width / 2, 1));
      expect(_corners(tester).topLeft.x, greaterThan(0));
      expect(_corners(tester).bottomLeft, Radius.zero);
    });
  });
}
