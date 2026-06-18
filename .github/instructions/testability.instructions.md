---
applyTo: lib/src/ui/**/*.dart
---
# Building Views That Are Stable and E2E-Drivable

Views are part of the definition of done only when their primary user flows can be driven end to end by a dusk agent or a CI test. The rules below keep widget identity and semantic labels stable enough for label-based resolution (rules 1-3) and make dusk drivability part of the definition of done (rule 4).

## 1. Drive button loading state with `processingListenable` + `MagicBuilder`

Use a targeted subtree rebuild instead of a full-view `setState`. This keeps the button tree stable, avoids identity loss, and prevents the dusk agent from losing its reference mid-action.

Pattern (`magic_form_data.dart:267`, `magic_builder.dart:76`):

```dart
MagicBuilder<bool>(
  listenable: form.processingListenable,
  builder: (isProcessing) => WButton(
    semanticLabel: 'Save profile',
    isLoading: isProcessing,
    // Disable while processing: form.process() throws StateError if
    // called again mid-flight (magic_form_data.dart:285), and it blocks
    // duplicate submits / double-taps.
    onTap: isProcessing ? null : () => form.process(_submit),
    child: WText(trans('common.save')),
  ),
)
```

- `form.processingListenable` is a `ValueListenable<bool>` on `MagicFormData` — only the `MagicBuilder` subtree rebuilds.
- `MagicBuilder<T>` wraps `ValueListenableBuilder` with a cleaner API; see `magic_builder.dart:76`.
- Cross-link: Step M1 makes `processingListenable` + `MagicBuilder` the scaffolded default in generated view stubs.
- Never replace this with `setState(() => _loading = ...)` on the parent widget — it tears down and remounts interactive descendants, breaking dusk locators.

## 2. Assign stable `ValueKey` to interactive elements that can be conditionally rendered or reordered

Widget identity in the Flutter element tree is position-based by default. When a button toggles between states or appears in a dynamic list, a stable key guarantees dusk resolves the same element across frames.

```dart
// Submit button that conditionally renders a loading state
WButton(
  key: const ValueKey('submit-profile'),
  semanticLabel: 'Save profile',
  ...
),

// Action button inside a dynamic list item
WButton(
  key: ValueKey('delete-item-${item.id}'),
  semanticLabel: 'Delete ${item.name}',
  ...
),
```

Rule of thumb: any interactive widget (`WButton`, `WInput`, custom controls) inside a `Column`/`ListView` with conditional siblings, or one that can be toggled visible/invisible, needs a `ValueKey`.

## 3. Set `semanticLabel` on icon-only and ambiguous interactive widgets

The dusk agent resolves elements by semantic label. Without a label, an icon-only button is invisible to label-based resolution.

`WButton.semanticLabel` (`wind/lib/src/widgets/w_button.dart:113`) propagates to the `Semantics` node wrapping the interactive surface:

```dart
// Icon-only button — no visible text, must have a label
WButton(
  key: const ValueKey('back-button'),
  semanticLabel: 'Go back',
  onTap: () => Route.back(),
  child: WIcon(Icons.arrow_back),
),

// Ambiguous action (same icon used multiple times on screen)
WButton(
  key: ValueKey('edit-user-${user.id}'),
  semanticLabel: 'Edit user ${user.name}',
  onTap: () => _edit(user),
  child: WIcon(Icons.edit),
),
```

For generic Flutter widgets that do not accept `semanticLabel` directly, wrap with `Semantics(label: '...', child: widget)`.

## 4. Definition of done for view work includes dusk drivability

A view is done when:
- Its primary user flows (form submit, list action, navigation) can be driven by a dusk agent using semantic labels and stable keys.
- No interactive element in a primary flow is label-free or identity-unstable across a state change.
- The processingListenable + MagicBuilder pattern is used for any submit/loading state.

"Tests pass" and "looks correct" are necessary but not sufficient — dusk drivability is the third gate.
