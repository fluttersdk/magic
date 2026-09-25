# Views

Views extend `MagicView` or `MagicStatefulView` to give each screen a typed controller reference, async-state rendering helpers, and a clean MVC separation between UI and business logic.

- [Introduction](#introduction)
- [Creating Views](#creating-views)
    - [Stateless Views](#stateless-views)
    - [Stateful Views](#stateful-views)
- [Form Handling](#form-handling)
- [Rendering Async State](#rendering-async-state)
- [Refetching Data on Mount](#refetching-on-mount)
- [Guarding a Submit Against a Double Tap](#submits-once)
- [Responsive Views](#responsive-views)
- [Generating Views](#generating-views)

<a name="introduction"></a>
## Introduction

Magic Views provide a structured way to separate your UI from your business logic, following the MVC pattern familiar to Laravel developers. Instead of standard Flutter widgets, Magic views extend `MagicView` or `MagicStatefulView`.

### Why Use MagicView?

- **Auto-Injection**: The controller is automatically available via `controller` property
- **Type Safety**: The controller is fully typed (`MagicView<UserController>`)
- **Consistency**: Matches Laravel's MVC structure
- **Wind UI Integration**: Build UIs with utility-first classes

<a name="creating-views"></a>
## Creating Views

To generate a new view, use the Magic CLI:

```bash
dart run magic:artisan make:view Dashboard
```

<a name="stateless-views"></a>
### Stateless Views

Most of your pages will be stateless, relying on the controller for state management:

```dart
import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

class DashboardView extends MagicView {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'p-6 flex flex-col gap-4',
      children: [
        WText('Dashboard', className: 'text-2xl font-bold text-white'),
        WText('Welcome back!', className: 'text-gray-400'),
      ],
    );
  }
}
```

<a name="stateful-views"></a>
### Stateful Views

Use `MagicStatefulView` when you need local widget state or form handling:

```dart
class LoginView extends MagicStatefulView<AuthController> {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends MagicStatefulViewState<AuthController, LoginView> {
  late final form = MagicFormData({
    'email': '',
    'password': '',
    'remember_me': false,
  }, controller: controller);

  @override
  void onClose() => form.dispose();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _buildForm(),
    );
  }
  
  Widget _buildForm() {
    return MagicForm(
      formData: form,
      child: WDiv(
        className: 'max-w-md p-6 bg-slate-900 rounded-xl',
        children: [
          WFormInput(
            controller: form['email'],
            label: trans('attributes.email'),
            placeholder: trans('fields.email_placeholder'),
            type: InputType.email,
            validator: rules([Required(), Email()], field: 'email'),
          ),
          WFormInput(
            controller: form['password'],
            label: trans('attributes.password'),
            type: InputType.password,
            validator: rules([Required(), Min(8)], field: 'password'),
          ),
          WButton(
            isLoading: controller.isLoading,
            onTap: _submit,
            className: 'w-full bg-primary p-4 rounded-lg',
            child: WText(trans('auth.login'), className: 'text-white text-center'),
          ),
        ],
      ),
    );
  }
  
  void _submit() {
    final data = form.validated();
    if (data.isNotEmpty) {
      controller.login(data);
    }
  }
}
```

<a name="form-handling"></a>
## Form Handling

Views use `MagicFormData` for centralized form management:

```dart
late final form = MagicFormData({
  'name': '',
  'email': '',
  'age': 0,
  'active': true,
}, controller: controller);

// Access values
form.get('name');              // String value
form.value<bool>('active');    // Typed value
form['email'];                 // TextEditingController

// Set values
form.setValue('name', 'John');

// Validation
final data = form.validated(); // Returns {} if invalid
form.validate();               // Returns bool

// Cleanup
@override
void onClose() => form.dispose();
```

### Validation Rules

Use the `rules()` helper within views for client-side validation:

```dart
WFormInput(
  controller: form['email'],
  validator: rules([Required(), Email()], field: 'email'),
);

WFormInput(
  controller: form['password_confirmation'],
  validator: rules([
    Required(),
    Same('password', valueGetter: () => form['password'].text),
  ], field: 'password_confirmation'),
);
```

<a name="rendering-async-state"></a>
## Rendering Async State

Use `controller.renderState()` to elegantly handle loading, error, and success states:

```dart
@override
Widget build(BuildContext context) {
  return controller.renderState(
    (users) => UserList(users: users),
    onLoading: Center(child: CircularProgressIndicator()),
    onError: (msg) => ErrorWidget(message: msg),
    onEmpty: EmptyState(message: trans('users.empty')),
  );
}
```

Each callback is optional. Magic provides sensible defaults if omitted.

<a name="refetching-on-mount"></a>
## Refetching Data on Mount

Controllers are Type-keyed singletons and fire `onInit` ONCE per controller instance, not once per view mount, so a controller that loads its data in `onInit` fetches on the first view that resolves it and never again for the lifetime of the app. Navigating away and back re-renders the same cached rows, which reads as stale or fabricated data rather than as a stale screen.

Mix `RefetchesOnMount<Controller, View>` onto a `MagicStatefulViewState` and point `refetch` at the controller's `ensureFresh` (not `reload`, which would send every request twice: the mount that creates the controller has already started the same load from `onInit`):

```dart
class _ItemsListViewState
    extends MagicStatefulViewState<ItemsController, ItemsListView>
    with RefetchesOnMount<ItemsController, ItemsListView> {
  @override
  Future<void> refetch() => controller.ensureFresh();
}
```

The refetch is fire-and-forget: `build()` renders the cached data immediately and the view rebuilds once the fresh data lands, so a mount never blocks on the network. A failed refetch leaves the screen as it was, since every controller's `reload()` keeps its last-known-good cache on failure.

<a name="submits-once"></a>
## Guarding a Submit Against a Double Tap

An `async` submit handler wired straight to a button (`onTap: _onSubmit`) leaves nothing disabling the button for the duration of the await, so a double tap fires the write twice. On a create path that is not idempotent, two taps create two records.

Mix `SubmitsOnce<W>` onto the form's `State`, route the handler through `submitOnce`, and feed `isSubmitting` to the button's `isLoading`:

```dart
class _RegisterFormState extends State<RegisterForm> with SubmitsOnce<RegisterForm> {
  Future<void> _onSubmit() async {
    await Http.post('/register', data: form.data);
  }

  @override
  Widget build(BuildContext context) {
    return WButton(
      isLoading: isSubmitting,
      onTap: () => submitOnce(_onSubmit),
      child: WText(trans('auth.register')),
    );
  }
}
```

Feeding `isSubmitting` to the button's `isLoading` is what actually blocks the second tap: a well-behaved button computes `isInteractive = !isLoading && !disabled` and passes `null` for `onTap` when that is false, so the spinner and the guard are the same switch. A throwing submit re-arms the button rather than leaving it spinning forever, since the reset runs in a `finally`.

<a name="responsive-views"></a>
## Responsive Views

For layouts that adapt to screen size, use `LayoutBuilder` with Wind's responsive helpers:

```dart
class DashboardView extends MagicView {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = wScreenIs(context, 'lg');
        
        if (isDesktop) {
          return _buildDesktopLayout();
        }
        return _buildMobileLayout();
      },
    );
  }
}
```

Or use Wind's responsive prefixes:

```dart
WDiv(
  className: '''
    flex flex-col gap-4
    md:flex-row md:gap-6
    lg:gap-8
  ''',
  children: [...],
)
```

<a name="generating-views"></a>
## Generating Views

The Magic CLI can generate different types of views:

```bash
# Basic stateless view
dart run magic:artisan make:view Dashboard

# Stateful view with form support
dart run magic:artisan make:view Auth/Login --stateful

# Nested in subfolder
dart run magic:artisan make:view Admin/Users/Index
```

### Command Options

| Option | Description |
|--------|-------------|
| `--stateful` | Create stateful view with `MagicFormData` support |

**Output:** Creates `lib/resources/views/<name>_view.dart`
