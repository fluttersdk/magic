import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'widget_build_counter.dart';

/// Controller backing the granular-rebuild scenarios.
///
/// Carries [MagicStateMixin] so the full-view path can drive a rebuild through
/// [setLoading], and [ValidatesRequests] so [MagicForm] can bind to it exactly
/// as a generated controller would.
final class RebuildController extends MagicController
    with ValidatesRequests, MagicStateMixin<String> {
  RebuildController() {
    onInit();
  }
}

/// View that loads a submit button through [MagicForm] + [MagicBuilder].
///
/// The submit button subtree is scoped to [MagicFormData.processingListenable];
/// the sibling is a plain child outside any builder. A processing toggle must
/// rebuild the button subtree only, never the sibling.
final class GranularFormView extends MagicStatefulView<RebuildController> {
  final ValueNotifier<int> buttonBuilds;
  final ValueNotifier<int> siblingBuilds;
  final MagicFormData form;

  const GranularFormView({
    super.key,
    required this.buttonBuilds,
    required this.siblingBuilds,
    required this.form,
  });

  @override
  State<GranularFormView> createState() => _GranularFormViewState();
}

class _GranularFormViewState
    extends MagicStatefulViewState<RebuildController, GranularFormView> {
  @override
  Widget build(BuildContext context) {
    return MagicForm(
      formData: widget.form,
      child: Column(
        children: [
          WidgetBuildCounter(
            counter: widget.siblingBuilds,
            child: const WText('Sibling field'),
          ),
          MagicBuilder<bool>(
            listenable: widget.form.processingListenable,
            builder: (isProcessing) => WidgetBuildCounter(
              counter: widget.buttonBuilds,
              child: WButton(
                isLoading: isProcessing,
                onTap: isProcessing ? null : () {},
                child: const WText('Save'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  group('Granular rebuild path (scaffolded default)', () {
    late RebuildController controller;

    setUp(() {
      MagicApp.reset();
      Magic.flush();
      controller = RebuildController();
      Magic.put<RebuildController>(controller);
    });

    tearDown(() {
      Magic.flush();
    });

    testWidgets(
      'processing toggle rebuilds the button subtree but not the sibling',
      (tester) async {
        final buttonBuilds = ValueNotifier<int>(0);
        final siblingBuilds = ValueNotifier<int>(0);
        final form = MagicFormData({'name': ''}, controller: controller);

        await tester.pumpWidget(
          MaterialApp(
            home: WindTheme(
              data: WindThemeData(),
              child: GranularFormView(
                buttonBuilds: buttonBuilds,
                siblingBuilds: siblingBuilds,
                form: form,
              ),
            ),
          ),
        );

        final siblingAtStart = siblingBuilds.value;
        final buttonAtStart = buttonBuilds.value;

        // Drive processing on through the form-scoped listenable.
        final pending = form.process(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();

        // Button subtree rebuilt to reflect the loading state.
        expect(
          buttonBuilds.value,
          greaterThan(buttonAtStart),
          reason: 'MagicBuilder should rebuild the button on processing change',
        );

        // Sibling is outside the builder: its count must be frozen.
        expect(
          siblingBuilds.value,
          equals(siblingAtStart),
          reason: 'granular path must not rebuild the sibling subtree',
        );

        // Let processing settle back to false and confirm the sibling stays put.
        await tester.pump(const Duration(milliseconds: 40));
        await pending;
        await tester.pump();

        expect(siblingBuilds.value, equals(siblingAtStart));

        form.dispose();
        buttonBuilds.dispose();
        siblingBuilds.dispose();
      },
    );

    testWidgets('full-view setLoading path rebuilds the sibling subtree', (
      tester,
    ) async {
      final buttonBuilds = ValueNotifier<int>(0);
      final siblingBuilds = ValueNotifier<int>(0);
      final form = MagicFormData({'name': ''}, controller: controller);

      await tester.pumpWidget(
        MaterialApp(
          home: WindTheme(
            data: WindThemeData(),
            child: GranularFormView(
              buttonBuilds: buttonBuilds,
              siblingBuilds: siblingBuilds,
              form: form,
            ),
          ),
        ),
      );

      final siblingAtStart = siblingBuilds.value;

      // Drive the full-view path: notifyListeners rebuilds the whole view.
      controller.setLoading();
      await tester.pump();

      expect(
        siblingBuilds.value,
        greaterThan(siblingAtStart),
        reason:
            'full-view setLoading must rebuild the sibling, '
            'demonstrating why the granular path is preferred',
      );

      form.dispose();
      buttonBuilds.dispose();
      siblingBuilds.dispose();
    });
  });
}
