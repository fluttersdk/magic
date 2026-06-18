# UI Helpers

Magic provides context-free UI feedback utilities, reactive widget builders, declarative page-title management, responsive layouts, form-processing helpers, and data-loading shortcuts that integrate with the controller state lifecycle.

- [Introduction](#introduction)
- [Snackbars](#snackbars)
    - [Typed Snackbars](#typed-snackbars)
- [Dialogs](#dialogs)
    - [Custom Dialogs](#custom-dialogs)
    - [Confirmation Dialogs](#confirmation-dialogs)
- [Loading Overlay](#loading-overlay)
- [Toast Messages](#toast-messages)
- [Configuration](#configuration)
- [MagicBuilder](#magic-builder)
- [MagicTitle](#magic-title)
- [MagicResponsiveView](#magic-responsive-view)
    - [Extended Breakpoints](#extended-breakpoints)
    - [Context Helpers](#context-helpers)
- [Advanced MagicFormData](#advanced-magic-form-data)
    - [Processing State](#processing-state)
    - [Granular Rebuilds with processingListenable](#processing-listenable)
- [Data Loading Helpers](#data-loading-helpers)
    - [fetchList](#fetch-list)
    - [fetchOne](#fetch-one)
    - [Rendering State with renderState](#render-state)

<a name="introduction"></a>
## Introduction

Magic provides context-free UI feedback utilities through the `Magic` facade. Show snackbars, dialogs, confirmations, loading overlays, and toasts from **anywhere**—controllers, services, or callbacks—without passing `BuildContext`.

```dart
// No context needed!
Magic.success('Done', 'User created successfully');
Magic.confirm(title: 'Delete?', message: 'This cannot be undone');
Magic.loading();
```

This is a game-changer for Flutter developers. No more passing `context` down through your widget tree just to show a simple notification.

<a name="snackbars"></a>
## Snackbars

Show notification messages at the bottom of the screen.

### Basic Snackbar

```dart
Magic.snackbar('Title', 'Message');
```

<a name="typed-snackbars"></a>
### Typed Snackbars

Use typed helpers for semantic styling:

```dart
Magic.success('Success', 'Operation completed');  // Green
Magic.error('Error', 'Something went wrong');     // Red
Magic.info('Info', 'New update available');       // Blue
Magic.warning('Warning', 'Low storage space');    // Amber
```

### With Custom Duration

```dart
Magic.snackbar(
  'Custom',
  'Message',
  type: 'info',
  duration: Duration(seconds: 5),
);
```

<a name="dialogs"></a>
## Dialogs

<a name="custom-dialogs"></a>
### Custom Dialogs

Display any widget in a centered dialog:

```dart
Magic.dialog(
  WDiv(
    className: 'p-6 bg-white rounded-xl max-w-md',
    children: [
      WText('Custom Dialog', className: 'text-xl font-bold'),
      WText('Any content goes here.', className: 'text-gray-600 mt-2'),
      WDiv(
        className: 'flex justify-end gap-4 mt-6',
        children: [
          WButton(
            onTap: () => Magic.closeDialog(),
            className: 'px-4 py-2 text-gray-600',
            child: WText('Cancel'),
          ),
          WButton(
            onTap: () {
              // Handle action
              Magic.closeDialog();
            },
            className: 'px-4 py-2 bg-primary text-white rounded-lg',
            child: WText('Confirm'),
          ),
        ],
      ),
    ],
  ),
);
```

### Close Dialog

```dart
Magic.closeDialog();
```

<a name="confirmation-dialogs"></a>
### Confirmation Dialogs

Ask the user to confirm an action:

```dart
final confirmed = await Magic.confirm(
  title: 'Delete Item',
  message: 'Are you sure you want to delete this item?',
  confirmText: 'Delete',
  cancelText: 'Cancel',
);

if (confirmed == true) {
  await deleteItem();
}
```

### Dangerous Actions

Use `isDangerous: true` for destructive confirmations (styled in red):

```dart
final confirmed = await Magic.confirm(
  title: 'Delete Account',
  message: 'This action cannot be undone. All your data will be permanently removed.',
  confirmText: 'Delete Forever',
  isDangerous: true,
);

if (confirmed == true) {
  await deleteAccount();
  MagicRoute.to('/goodbye');
}
```

<a name="loading-overlay"></a>
## Loading Overlay

Show a blocking loading overlay during async operations.

### Show Loading

```dart
Magic.loading();

// With message
Magic.loading(message: 'Please wait...');
```

### Close Loading

```dart
Magic.closeLoading();
```

### Pattern: Wrap Async Operations

```dart
Future<void> submitForm() async {
  Magic.loading(message: 'Saving...');
  try {
    await api.save(data);
    Magic.success('Saved', 'Your changes have been saved');
  } catch (e) {
    Magic.error('Error', e.toString());
  } finally {
    Magic.closeLoading();
  }
}
```

### Controller Pattern

```dart
class OrderController extends MagicController with MagicStateMixin<Order> {
  Future<void> placeOrder(Map<String, dynamic> data) async {
    Magic.loading(message: trans('orders.processing'));
    
    try {
      final response = await Http.post('/orders', data: data);
      
      if (response.successful) {
        setSuccess(Order.fromMap(response.body));
        Magic.success(
          trans('common.success'),
          trans('orders.placed'),
        );
        MagicRoute.to('/orders/${response['id']}');
      } else {
        Magic.error(trans('common.error'), response.errorMessage ?? '');
      }
    } finally {
      Magic.closeLoading();
    }
  }
}
```

<a name="toast-messages"></a>
## Toast Messages

Show brief, non-intrusive messages (centered, pill-shaped):

```dart
Magic.toast('Item added to cart');

// Custom duration
Magic.toast('Copied!', duration: Duration(seconds: 1));
```

Toasts are ideal for quick confirmations that don't require user interaction.

<a name="configuration"></a>
## Configuration

Customize appearance via `config/view.dart`:

```dart
Map<String, dynamic> get viewConfig => {
  'view': {
    // Snackbar styling
    'snackbar': {
      'duration': 4000,
      'style': {
        'success': 'bg-green-500 text-white p-4 rounded-lg',
        'error': 'bg-red-500 text-white p-4 rounded-lg',
        'info': 'bg-blue-500 text-white p-4 rounded-lg',
        'warning': 'bg-amber-500 text-white p-4 rounded-lg',
      },
    },
    
    // Dialog container
    'dialog': {
      'class': 'bg-white rounded-xl p-6 shadow-2xl w-80 max-w-md',
    },
    
    // Confirmation dialog
    'confirm': {
      'container_class': 'bg-white rounded-xl p-6 shadow-2xl w-80',
      'title_class': 'text-lg font-bold text-gray-900',
      'message_class': 'text-gray-600 mt-2',
      'button_cancel_class': 'px-4 py-2 text-gray-600',
      'button_confirm_class': 'px-4 py-2 bg-primary text-white rounded-lg',
      'button_danger_class': 'px-4 py-2 bg-red-500 text-white rounded-lg',
    },
    
    // Loading overlay
    'loading': {
      'container_class': 'bg-white rounded-xl p-6 shadow-2xl',
      'spinner_class': 'text-primary',
      'text_class': 'text-gray-600 text-sm mt-4',
    },
    
    // Toast
    'toast': {
      'duration': 2000,
      'class': 'bg-gray-800 text-white px-6 py-3 rounded-full shadow-lg',
    },
  },
};
```

> [!TIP]
> Use Wind UI utility classes in your config for consistent styling across all UI helpers.

<a name="magic-builder"></a>
## MagicBuilder

`MagicBuilder<T>` is a concise reactive widget that rebuilds a subtree whenever a `ValueListenable<T>` changes. It wraps `ValueListenableBuilder` but drops the unused `context` and `child` parameters so the builder closure stays focused on the value.

```dart
MagicBuilder<int>(
  listenable: controller.counterNotifier,
  builder: (count) => WText('$count'),
)
```

The two required parameters are:

| Parameter | Type | Purpose |
|-----------|------|---------|
| `listenable` | `ValueListenable<T>` | The notifier to observe |
| `builder` | `Widget Function(T value)` | Called on every change with the new value |

When you also need `BuildContext` inside the builder, wrap the `MagicBuilder` in a `Builder`:

```dart
Builder(
  builder: (context) {
    final theme = Theme.of(context);
    return MagicBuilder<bool>(
      listenable: controller.enabledNotifier,
      builder: (enabled) => Switch(
        value: enabled,
        activeColor: theme.colorScheme.primary,
        onChanged: (_) => controller.toggle(),
      ),
    );
  },
)
```

The classic use case is a multi-section view where only one section depends on a notifier:

```dart
class MonitorShowView extends MagicStatefulView<MonitorController> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Rebuilds only when checksNotifier fires
        MagicBuilder<List<MonitorCheck>>(
          listenable: controller.checksNotifier,
          builder: (checks) => _buildStatsSection(checks),
        ),

        // Rebuilds only when the toggle changes
        MagicBuilder<bool>(
          listenable: controller.realTimeEnabledNotifier,
          builder: (enabled) => Switch(
            value: enabled,
            onChanged: (_) => controller.toggleRealTime(),
          ),
        ),
      ],
    );
  }
}
```

> [!TIP]
> For E2E drivability, prefer `MagicBuilder` over `setState` on the parent widget. Targeted subtree rebuilds keep interactive element identity stable so dusk agents do not lose their references mid-action.

<a name="magic-title"></a>
## MagicTitle

`MagicTitle` is a declarative title-override widget. Wrap any part of the widget tree with it to push a page title through `TitleManager` while the widget is mounted. The configured app-name suffix is applied automatically.

```dart
class UserProfileView extends MagicView<UserController> {
  @override
  Widget build(BuildContext context) {
    return MagicTitle(
      title: 'Edit Profile',
      child: Column(
        children: [
          // page content
        ],
      ),
    );
  }
}
```

The constructor accepts two required parameters:

| Parameter | Type | Purpose |
|-----------|------|---------|
| `title` | `String` | The page title to display |
| `child` | `Widget` | The subtree to render |

`MagicTitle` calls `TitleManager.instance.setOverride(title)` in `initState`, updates it in `didUpdateWidget` when `title` changes, and clears the override in `dispose`. This makes it safe for data-dependent titles that resolve after the route is already mounted:

```dart
MagicTitle(
  title: controller.isSuccess ? controller.rxState!.name : 'Loading...',
  child: _buildContent(),
)
```

> [!NOTE]
> `MagicTitle` updates the browser tab title on web and integrates with route-level title observers. It does not replace the `title` parameter on `MagicRoute.page()`. Use `MagicRoute.page()` titles for static route titles and `MagicTitle` for dynamic or data-dependent ones.

<a name="magic-responsive-view"></a>
## MagicResponsiveView

`MagicResponsiveView<T extends MagicController>` is an abstract view base class that dispatches to a different widget method depending on the current screen width. Breakpoints are read from the active `WindThemeData.screens` so they stay consistent with your Wind utility classes.

Subclass it and override the layout methods you need:

```dart
class DashboardView extends MagicResponsiveView<DashboardController> {
  const DashboardView({super.key});

  @override
  Widget phone(BuildContext context) => MobileDashboard();

  @override
  Widget tablet(BuildContext context) => TabletDashboard();

  @override
  Widget desktop(BuildContext context) => DesktopDashboard();
}
```

The dispatch order is:

| Condition | Method called |
|-----------|--------------|
| `width < 320 px` | `watch(context)` |
| `width < sm` (default 640 px) | `phone(context)` |
| `width < lg` (default 1024 px) | `tablet(context)` |
| `width >= lg` | `desktop(context)` |

Only `phone` is abstract; the others fall back up the chain by default (`watch` calls `phone`, `tablet` calls `phone`, `desktop` calls `tablet`). Override only the breakpoints where your layout actually differs.

<a name="extended-breakpoints"></a>
### Extended Breakpoints

For fine-grained control over all five Wind breakpoints, extend `MagicResponsiveViewExtended<T>` instead:

```dart
class AdminView extends MagicResponsiveViewExtended<AdminController> {
  const AdminView({super.key});

  @override
  Widget xs(BuildContext context) => MobileAdminView();   // < 320 px

  @override
  Widget sm(BuildContext context) => PhoneAdminView();    // >= 320, < sm

  @override
  Widget lg(BuildContext context) => TabletAdminView();   // >= md, < lg

  @override
  Widget xxl(BuildContext context) => WideAdminView();    // >= xl
}
```

Methods that you do not override cascade to the next smaller breakpoint, so you only implement the layouts where behavior changes.

<a name="context-helpers"></a>
### Context Helpers

The `MagicResponsiveContext` extension on `BuildContext` exposes breakpoint checks for use inside any `build` method:

```dart
Widget build(BuildContext context) {
  if (context.isDesktop) {
    return Row(children: [_sidebar(), _content()]);
  }
  return _content();
}
```

Available getters:

| Getter | Type | Meaning |
|--------|------|---------|
| `screenWidth` | `double` | `MediaQuery.of(context).size.width` |
| `screenHeight` | `double` | `MediaQuery.of(context).size.height` |
| `isPhone` | `bool` | Width is below the `sm` breakpoint |
| `isTablet` | `bool` | Width is between `sm` and `lg` |
| `isDesktop` | `bool` | Width is at or above `lg` |
| `activeBreakpoint` | `String` | Current Wind breakpoint name (e.g. `'md'`) |
| `isAtLeast(String)` | `bool` | True if screen is at or above the given breakpoint |

<a name="advanced-magic-form-data"></a>
## Advanced MagicFormData

The basics of `MagicFormData` are covered in the [Forms](forms.md) page. This section documents the processing-state API that powers submit flows.

<a name="processing-state"></a>
### Processing State

`process<T>()` wraps an async action with automatic processing-state management. It sets `isProcessing` to `true` before the action and back to `false` when it completes (whether it succeeds or throws). If `process()` is called again while already running, it throws a `StateError` to prevent duplicate submissions.

```dart
Future<void> _submit() async {
  if (!form.validate()) return;

  await form.process(() => controller.updateProfile(
    name: form.get('name'),
    email: form.get('email'),
  ));
}
```

| Member | Type | Description |
|--------|------|-------------|
| `process<T>(Future<T> Function() action)` | `Future<T>` | Runs `action` with automatic `isProcessing` tracking |
| `isProcessing` | `bool` | `true` while `process()` is executing |
| `processingListenable` | `ValueListenable<bool>` | Notifier backing `isProcessing`; use with `MagicBuilder` |

<a name="processing-listenable"></a>
### Granular Rebuilds with processingListenable

Use `form.processingListenable` together with `MagicBuilder<bool>` to rebuild only the submit button while the rest of the form stays static. This keeps the widget tree stable and preserves dusk locators during the async operation:

```dart
MagicBuilder<bool>(
  listenable: form.processingListenable,
  builder: (isProcessing) => WButton(
    semanticLabel: 'Save profile',
    isLoading: isProcessing,
    onTap: isProcessing ? null : _submit,
    child: WText(trans('common.save')),
  ),
)
```

Passing `null` to `onTap` while `isProcessing` is `true` also prevents double-tap submissions because `form.process()` would throw a `StateError` on a concurrent call regardless.

> [!TIP]
> This pattern is the scaffolded default in generated view stubs.

<a name="data-loading-helpers"></a>
## Data Loading Helpers

Controllers that mix in `MagicStateMixin<T>` gain two convenience methods for the most common data-fetch patterns. Both methods handle the full loading/success/error/empty lifecycle automatically.

<a name="fetch-list"></a>
### fetchList

`fetchList<E>()` fetches a paginated or plain list from a URL and maps each item through a `fromMap` factory. It is generic over the element type `E` and expects the controller's state type `T` to be `List<E>`.

```dart
class UserController extends MagicController with MagicStateMixin<List<User>> {
  @override
  void onInit() {
    super.onInit();
    fetchList<User>('/api/users', User.fromMap);
  }
}
```

Signature:

```dart
Future<void> fetchList<E>(
  String url,
  E Function(Map<String, dynamic>) fromMap, {
  String dataKey = 'data',
  Map<String, dynamic>? query,
  Map<String, String>? headers,
})
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `url` | required | The endpoint to GET |
| `fromMap` | required | Factory that maps a JSON object to type `E` |
| `dataKey` | `'data'` | Key in the response payload that holds the list |
| `query` | `null` | Optional query-string parameters |
| `headers` | `null` | Optional request headers |

The helper sets `setLoading()` before the request. On success it calls `setSuccess(items)`. If the list is absent or empty it calls `setEmpty()`. On a failed response it calls `setError(message)`.

<a name="fetch-one"></a>
### fetchOne

`fetchOne()` fetches a single resource and maps it through a `fromMap` factory.

```dart
class UserController extends MagicController with MagicStateMixin<User> {
  @override
  void onInit() {
    super.onInit();
    fetchOne('/api/users/1', User.fromMap);
  }
}
```

Signature:

```dart
Future<void> fetchOne(
  String url,
  T Function(Map<String, dynamic>) fromMap, {
  String dataKey = 'data',
  Map<String, dynamic>? query,
  Map<String, String>? headers,
})
```

The parameters are identical to `fetchList`. The helper sets `setLoading()`, then on a successful response calls `setSuccess(fromMap(data[dataKey]))`. On failure or a malformed payload it calls `setError(message)`.

<a name="render-state"></a>
### Rendering State with renderState

After either fetch helper resolves, use `renderState` to build the UI declaratively against `rxStatus`:

```dart
class UserProfileView extends MagicView<UserController> {
  @override
  Widget build(BuildContext context) {
    return controller.renderState(
      (user) => UserCard(user: user),
      onLoading: const Center(child: CircularProgressIndicator()),
      onError: (msg) => WText('Error: $msg', className: 'text-red-500'),
      onEmpty: WText('No user found.', className: 'text-gray-400'),
    );
  }
}
```

`renderState` uses `AnimatedBuilder` on the controller so the view rebuilds automatically whenever status or state changes. All four callbacks are optional; omitted states fall back to built-in default widgets.
