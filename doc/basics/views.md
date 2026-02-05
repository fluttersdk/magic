# Views

- [Introduction](#introduction)
- [Creating Views](#creating-views)
    - [Stateless Views](#stateless-views)
    - [Stateful Views](#stateful-views)
- [Form Handling](#form-handling)
- [Rendering Async State](#rendering-async-state)
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
magic make:view Dashboard
```

<a name="stateless-views"></a>
### Stateless Views

Most of your pages will be stateless, relying on the controller for state management:

```dart
import 'package:flutter/material.dart';
import 'package:fluttersdk_magic/fluttersdk_magic.dart';

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
magic make:view Dashboard

# Stateful view with form support
magic make:view Auth/Login --stateful

# Nested in subfolder
magic make:view Admin/Users/Index
```

### Command Options

| Option | Description |
|--------|-------------|
| `--stateful` | Create stateful view with `MagicFormData` support |

**Output:** Creates `lib/resources/views/<name>_view.dart`
