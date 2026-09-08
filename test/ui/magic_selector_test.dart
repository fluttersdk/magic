import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
// `hide TextDirection`: the magic barrel blanket-exports `package:intl`, whose
// `TextDirection` CLASS shadows the `dart:ui` enum, so `_wrap` below would not
// compile. Tracked separately; it is not this change.
import 'package:magic/magic.dart' hide TextDirection;

import 'widget_build_counter.dart';

/// Gives the `Text` widgets below a direction to lay out in.
Widget _wrap(Widget child) =>
    Directionality(textDirection: TextDirection.ltr, child: child);

/// Controller with three independent fields, so a selector can be shown to
/// ignore the two it did not ask for.
final class ProfileController extends SimpleMagicController {
  String name = 'ada';
  String query = '';
  int visits = 0;

  void rename(String value) {
    name = value;
    refreshUI();
  }

  void search(String value) {
    query = value;
    refreshUI();
  }

  void visit() {
    visits++;
    refreshUI();
  }

  /// How many listeners are attached right now.
  ///
  /// Counted here rather than read off `ChangeNotifier.hasListeners`, which is
  /// `@protected` and only legal inside a subclass instance member. A test
  /// asserting that a widget detached cleanly has to see the count from
  /// outside, so the controller under test keeps its own.
  int listeners = 0;

  @override
  void addListener(VoidCallback listener) {
    listeners++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    listeners--;
    super.removeListener(listener);
  }
}

/// A view that puts one probe inside a selector and one outside it.
///
/// The one outside is the control: it stands for everything on a real screen
/// that a keystroke cannot change, and its count is what a full-view rebuild
/// inflates.
final class ProfileView extends MagicStatefulView<ProfileController> {
  final ValueNotifier<int> scopedBuilds;
  final ValueNotifier<int> siblingBuilds;

  const ProfileView({
    super.key,
    required this.scopedBuilds,
    required this.siblingBuilds,
  });

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState
    extends MagicStatefulViewState<ProfileController, ProfileView> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        WidgetBuildCounter(
          counter: widget.siblingBuilds,
          child: const Text('static'),
        ),
        MagicSelector<ProfileController, String>(
          controller: controller,
          selector: (ProfileController c) => c.name,
          builder: (String name) => WidgetBuildCounter(
            counter: widget.scopedBuilds,
            child: Text(name),
          ),
        ),
      ],
    );
  }
}

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });

  group('under a rebuilding parent', () {
    late ProfileController controller;
    late ValueNotifier<int> scoped;
    late ValueNotifier<int> sibling;

    Future<void> pump(WidgetTester tester) async {
      controller = ProfileController();
      Magic.put<ProfileController>(controller);
      scoped = ValueNotifier<int>(0);
      sibling = ValueNotifier<int>(0);

      await tester.pumpWidget(
        _wrap(ProfileView(scopedBuilds: scoped, siblingBuilds: sibling)),
      );
    }

    testWidgets('an unrelated change leaves the scoped subtree alone', (
      tester,
    ) async {
      await pump(tester);
      expect(scoped.value, 1);
      expect(sibling.value, 1);

      controller.search('bbc');
      await tester.pump();

      // The whole view rebuilt, which is what `refreshUI` means today, and the
      // sibling proves it. The selector still returned the same name, so its
      // subtree was never asked to build.
      expect(sibling.value, 2);
      expect(scoped.value, 1);
    });

    testWidgets('many unrelated changes still cost the subtree nothing', (
      tester,
    ) async {
      await pump(tester);

      for (int i = 0; i < 7; i++) {
        controller.search('term $i');
        await tester.pump();
      }

      expect(sibling.value, 8);
      expect(scoped.value, 1);
    });

    testWidgets('a change to the selected value rebuilds the subtree', (
      tester,
    ) async {
      await pump(tester);

      controller.rename('grace');
      await tester.pump();

      expect(scoped.value, 2);
      expect(find.text('grace'), findsOneWidget);
    });

    testWidgets('and the new value reaches the builder, not a stale one', (
      tester,
    ) async {
      await pump(tester);

      controller.rename('grace');
      await tester.pump();
      controller.rename('hopper');
      await tester.pump();

      expect(scoped.value, 3);
      expect(find.text('hopper'), findsOneWidget);
    });
  });

  group('standing alone', () {
    testWidgets('it listens to the controller without a MagicStatefulView', (
      tester,
    ) async {
      final ProfileController controller = ProfileController();
      final ValueNotifier<int> builds = ValueNotifier<int>(0);

      await tester.pumpWidget(
        _wrap(
          MagicSelector<ProfileController, int>(
            controller: controller,
            selector: (ProfileController c) => c.visits,
            builder: (int visits) =>
                WidgetBuildCounter(counter: builds, child: Text('$visits')),
          ),
        ),
      );

      expect(find.text('0'), findsOneWidget);

      controller.visit();
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(builds.value, 2);
    });

    testWidgets('a notification that does not move the value builds nothing', (
      tester,
    ) async {
      final ProfileController controller = ProfileController();
      final ValueNotifier<int> builds = ValueNotifier<int>(0);

      await tester.pumpWidget(
        _wrap(
          MagicSelector<ProfileController, String>(
            controller: controller,
            selector: (ProfileController c) => c.name,
            builder: (String name) =>
                WidgetBuildCounter(counter: builds, child: Text(name)),
          ),
        ),
      );

      controller.visit();
      controller.visit();
      await tester.pump();

      expect(builds.value, 1);
    });

    testWidgets('it swaps listeners when the controller instance changes', (
      tester,
    ) async {
      final ProfileController first = ProfileController();
      final ProfileController second = ProfileController()..name = 'grace';

      Future<void> pumpWith(ProfileController c) {
        return tester.pumpWidget(
          _wrap(
            MagicSelector<ProfileController, String>(
              controller: c,
              selector: (ProfileController x) => x.name,
              builder: (String name) => Text(name),
            ),
          ),
        );
      }

      await pumpWith(first);
      expect(find.text('ada'), findsOneWidget);

      await pumpWith(second);
      expect(find.text('grace'), findsOneWidget);

      // The old controller must no longer drive this widget, or a replaced
      // controller keeps a live listener and the screen answers to two sources.
      expect(first.listeners, 0);
      expect(second.listeners, 1);
    });

    testWidgets('a changed selector re-reads rather than serving the cache', (
      tester,
    ) async {
      final ProfileController controller = ProfileController();

      Future<void> pumpWith(String Function(ProfileController) selector) {
        return tester.pumpWidget(
          _wrap(
            MagicSelector<ProfileController, String>(
              controller: controller,
              selector: selector,
              builder: (String value) => Text(value),
            ),
          ),
        );
      }

      await pumpWith((ProfileController c) => c.name);
      expect(find.text('ada'), findsOneWidget);

      controller.search('bbc');
      await pumpWith((ProfileController c) => c.query);

      expect(find.text('bbc'), findsOneWidget);
    });

    testWidgets('it stops listening when removed from the tree', (
      tester,
    ) async {
      final ProfileController controller = ProfileController();

      await tester.pumpWidget(
        _wrap(
          MagicSelector<ProfileController, String>(
            controller: controller,
            selector: (ProfileController c) => c.name,
            builder: (String name) => Text(name),
          ),
        ),
      );
      expect(controller.listeners, 1);

      await tester.pumpWidget(_wrap(const SizedBox.shrink()));

      expect(controller.listeners, 0);
    });
  });

  group('the caching contract, pinned rather than fixed', () {
    testWidgets('a hot reload drops the cache', (tester) async {
      // Without this, an edit to the builder is invisible until the selected
      // value happens to move: hot reload marks descendants dirty, but the
      // cached instance is what they rebuild against.
      final ProfileController controller = ProfileController();
      final ValueNotifier<int> builds = ValueNotifier<int>(0);

      await tester.pumpWidget(
        _wrap(
          MagicSelector<ProfileController, String>(
            controller: controller,
            selector: (ProfileController c) => c.name,
            builder: (String name) =>
                WidgetBuildCounter(counter: builds, child: Text(name)),
          ),
        ),
      );
      expect(builds.value, 1);

      // What `flutter run`'s `r` triggers.
      tester.binding.reassembleApplication();
      await tester.pump();

      expect(builds.value, 2);
    });

    testWidgets('a changed builder is NOT seen while the value holds', (
      tester,
    ) async {
      // The hole the purity contract exists to rule out, written down so the
      // next reader meets it as a decision rather than as a surprise. Nothing
      // here is a fix: it documents what the cache costs.
      final ProfileController controller = ProfileController();

      Future<void> pumpWith(String suffix) {
        return tester.pumpWidget(
          _wrap(
            MagicSelector<ProfileController, String>(
              controller: controller,
              selector: (ProfileController c) => c.name,
              builder: (String name) => Text('$name $suffix'),
            ),
          ),
        );
      }

      await pumpWith('one');
      expect(find.text('ada one'), findsOneWidget);

      await pumpWith('two');

      expect(find.text('ada one'), findsOneWidget, reason: 'still cached');
      expect(find.text('ada two'), findsNothing);

      // And it takes effect the moment the value moves.
      controller.rename('grace');
      await tester.pump();
      expect(find.text('grace two'), findsOneWidget);
    });
  });

  group('the equality contract', () {
    testWidgets('a record selects several fields at once', (tester) async {
      // The documented way to watch more than one field. A record has value
      // equality, so it compares by content and the cache holds.
      final ProfileController controller = ProfileController();
      final ValueNotifier<int> builds = ValueNotifier<int>(0);

      await tester.pumpWidget(
        _wrap(
          MagicSelector<ProfileController, (String, int)>(
            controller: controller,
            selector: (ProfileController c) => (c.name, c.visits),
            builder: ((String, int) value) => WidgetBuildCounter(
              counter: builds,
              child: Text('${value.$1}/${value.$2}'),
            ),
          ),
        ),
      );

      controller.search('irrelevant');
      await tester.pump();
      expect(builds.value, 1);

      controller.visit();
      await tester.pump();
      expect(builds.value, 2);
      expect(find.text('ada/1'), findsOneWidget);
    });

    testWidgets('a freshly built list rebuilds every time, as documented', (
      tester,
    ) async {
      // Dart's `List` has identity equality, so a selector that builds one is a
      // selector that never matches its own cache. This is pinned rather than
      // fixed: a deep comparison of a ten thousand element list on every
      // notification costs more than the rebuild it would prevent.
      final ProfileController controller = ProfileController();
      final ValueNotifier<int> builds = ValueNotifier<int>(0);

      await tester.pumpWidget(
        _wrap(
          MagicSelector<ProfileController, List<String>>(
            controller: controller,
            selector: (ProfileController c) => <String>[c.name],
            builder: (List<String> value) =>
                WidgetBuildCounter(counter: builds, child: Text(value.first)),
          ),
        ),
      );

      controller.visit();
      await tester.pump();

      expect(builds.value, 2);
    });
  });
}
