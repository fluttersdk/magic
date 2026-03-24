# UI LAYER

View, form, feedback, and authorization widget system for the Magic Framework.

## STRUCTURE

```
ui/
├── magic_view.dart           # MagicView<T>, MagicStatefulView<T>
├── magic_builder.dart       # MagicBuilder<T> — ValueListenableBuilder wrapper
├── magic_responsive_view.dart # MagicResponsiveView — breakpoint-aware layouts
├── magic_view_registry.dart  # MagicViewRegistry — view instance tracking
├── magic_form.dart           # MagicForm widget
├── magic_form_data.dart      # MagicFormData — form state + validation
├── magic_feedback.dart       # MagicFeedback — snackbar, dialog, loading, confirm
└── magic_can.dart            # MagicCan / MagicCannot authorization widgets
```

## VIEW SYSTEM

**MagicView<T>** — stateless, auto-injects controller via `Magic.find<T>()`. Controller MUST be registered in the IoC container before the view is rendered.

```dart
class MonitorListView extends MagicView<MonitorController> {
  Widget build(BuildContext context) => controller.renderState(
    onLoading: () => const CircularProgressIndicator(),
    onSuccess: (data) => MonitorList(data),
    onError: (msg) => ErrorWidget(msg),
  );
}
```

**MagicStatefulView<T>** — stateful version with lifecycle hooks.

```dart
class DashboardView extends MagicStatefulView<DashboardController> {
  @override
  void onInit() => controller.fetchData();

  @override
  void onClose() => controller.dispose();

  @override
  Widget build(BuildContext context) => controller.renderState(...);
}
```

**MagicBuilder<T>** — thin `ValueListenableBuilder` wrapper. Use when you need reactive rebuilds on a specific `ValueNotifier` without rebuilding the full view.

```dart
MagicBuilder<String>(
  listenable: controller.titleNotifier,
  builder: (context, value, _) => Text(value),
);
```

## FORM SYSTEM

**MagicFormData** — maps initial values to `TextEditingController` (text fields) or `ValueNotifier` (non-text fields). Provides unified validation and server error integration.

- `validate()` — clears existing server errors first, then runs local rule-based validation.
- `hasRelevantErrors(fields)` — checks errors ONLY for the provided field list. Prevents cross-form error leakage when multiple `MagicFormData` instances share a parent scope.
- `setServerErrors(Map<String, List<String>>)` — maps Laravel validation errors from `MagicResponse.errors` directly onto form fields.

```dart
final form = MagicFormData(initial: {'email': '', 'password': ''});

// In submit handler:
if (!form.validate()) return;
final res = await Http.post('/login', data: form.values);
if (res.failed) form.setServerErrors(res.errors);
```

**MagicForm** — widget wrapper that passes `MagicFormData` down the tree and handles `WillPopScope` dirty-state checks.

## FEEDBACK SYSTEM

**MagicFeedback** provides context-free UI via `MagicRouter.navigatorKey`. No `BuildContext` required at call site.

| Method | Behavior |
|--------|----------|
| `Magic.snackbar(msg)` | Bottom snackbar with optional action |
| `Magic.dialog(widget)` | Centered modal dialog |
| `Magic.loading()` | Full-screen loading overlay; returns `dismiss` callback |
| `Magic.confirm(title, msg)` | Returns `Future<bool>` — true if confirmed |

```dart
final dismiss = Magic.loading();
await someOperation();
dismiss();

final confirmed = await Magic.confirm('Delete', 'Are you sure?');
if (confirmed) await item.delete();
```

## AUTHORIZATION WIDGETS

**MagicCan / MagicCannot** — declarative show/hide driven by `Gate.allows(ability, args)`.

```dart
MagicCan(
  ability: 'update-monitor',
  args: {'monitor': monitor},
  child: EditButton(),
);

MagicCannot(
  ability: 'delete-monitor',
  child: DisabledDeleteButton(),
);
```

Gate abilities must be defined via `Gate.define()` before these widgets render — typically in a `ServiceProvider.boot()`.

## UI TESTING

```dart
setUp(() {
  MagicApp.reset();
  Magic.flush();
  Magic.put<MonitorController>(FakeMonitorController());
});
```

`Magic.put<T>()` registers an existing instance — the view's `Magic.find<T>()` call resolves it without needing a full provider setup.

## GOTCHAS

1. Controller MUST be in the IoC container before `MagicView` builds — register in provider `boot()` or call `Magic.put()` in tests.
2. `onClose()` in `MagicStatefulView` is not a destructor — avoid heavy cleanup; the controller lifecycle is managed by the IoC container.
3. `hasRelevantErrors` is required when sibling forms share an ancestor — without it, one form's errors surface in another.
4. `Magic.loading()` returns a dismiss callback — always call it, even on error, or the overlay persists.
5. `Gate.allows()` is synchronous — policy evaluation must not do async work.
