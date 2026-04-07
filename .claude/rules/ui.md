---
path: "lib/src/ui/**/*.dart"
---

# UI Domain (Views & Forms)

- `MagicView<T extends MagicController>` — stateless, auto-injects controller via `Magic.find<T>()`
- Register controller before view: `Magic.put(UserController())` — or resolve fails
- `MagicStatefulView<T>` + `MagicStatefulViewState<T, W>` — stateful variant with `controller` access and auto-rebuild on controller changes
- `MagicStatefulViewState` auto-calls `controller.onInit()` in `initState()` and `controller.onClose()` in `dispose()`
- `MagicForm(formData: form, child: ...)` — recommended pattern. Auto-extracts `formKey` and `controller` from `MagicFormData`
- Legacy: `MagicForm(formKey: key, controller: ctrl, child: ...)` — explicit key/controller
- `MagicFormData({'field': defaultValue}, controller: ctrl)` — form state manager with field builders
- Form field builders: `form.field('name', rules: [Required()])`, `form.checkbox('terms')` — auto-wired validation
- `form.validate()` — runs all field rules, returns bool
- `form.data` — returns `Map<String, dynamic>` of current form values
- `form.process(Future Function(Map) callback)` — async submit with `isProcessing` / `processingListenable` tracking
- Auto-validation: `MagicForm` switches to `AutovalidateMode.always` when controller has server-side errors
- `MagicResponsiveView` — responsive layout widget using Wind breakpoints (`sm`, `md`, `lg`, `xl`)
- `MagicFeedback` — toast/snackbar feedback integration
- `MagicTitle(title: 'Page', child: widget)` — declarative title override widget. Sets `TitleManager.setOverride()` on mount, clears on dispose. Updates on `didUpdateWidget` when title changes. Use for data-dependent titles that resolve after route mount
- Wind UI integration: views use `WDiv`, `WText`, `WButton` etc. for styling via `className` props
