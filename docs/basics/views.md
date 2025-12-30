# Views

## Introduction

Magic Views provide a structured way to separate your UI from your business logic, following the MVC pattern. Instead of standard Flutter widgets, Magic views extend `MagicView` or `MagicStatefulView`.

### Why Use MagicView?

1. **Auto-Injection**: The controller is automatically available as `controller`
2. **Type Safety**: The controller is fully typed (`MagicView<UserController>`)
3. **Consistency**: Matches Laravel's MVC structure

## Creating Views

### Stateless Views

Most of your pages will be stateless, relying on the controller for state management:

```dart
import 'package:flutter/material.dart';
import 'package:fluttersdk_magic/fluttersdk_magic.dart';
import '../../app/controllers/greeting_controller.dart';

class GreetingView extends MagicView<GreetingController> {
  const GreetingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Hello, ${controller.userName}'),
      ),
    );
  }
}
```

### Stateful Views

Use `MagicStatefulView` when you need Flutter lifecycle methods or local widget state:

```dart
class LoginView extends MagicStatefulView<AuthController> {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends MagicStatefulViewState<AuthController, LoginView> {
  // Centralized form data - types inferred from initial values
  late final form = MagicFormData({
    'email': '',
    'password': '',
  }, controller: controller);

  @override
  void onClose() => form.dispose();

  @override
  Widget build(BuildContext context) {
    return MagicForm(
      formData: form, // Auto-configuration
      child: Column(
        children: [
          WFormInput(
            controller: form['email'],
            label: 'Email',
            // rules() helper handles server-side error checking
            validator: rules([Required(), Email()], field: 'email'),
          ),
          if (controller.hasError('email'))
            Text(controller.getError('email')!),
            
          WButton(
            onTap: () {
              // Validates and returns data map
              final data = form.validated();
              if (data.isNotEmpty) {
                controller.login(data);
              }
            },
            child: Text('Submit'),
          ),
        ],
      ),
    );
  }
}
```

**Key Features of Stateful Views:**
- **Auto-Binding**: View rebuilds when controller calls `notifyListeners()`
- **Auto-Clear**: Validation errors are cleared on view init
- **Lifecycle Hooks**: `onInit()` and `onClose()` for clean setup/teardown
- **rules() Helper**: Auto-injects controller into `FormValidator.rules()`

## Rendering Async State

Use `controller.renderState()` to elegantly handle loading, error, and success states:

```dart
@override
Widget build(BuildContext context) {
  return controller.renderState(
    (user) => Text('Welcome ${user.name}'),
    onLoading: const CircularProgressIndicator(),
    onError: (error) => Text('Error: $error'),
    onEmpty: const Text('No data found'),
  );
}
```

## Responsive Views

For building responsive layouts that adapt to screen size, use `MagicResponsiveView`:

```dart
class DashboardView extends MagicResponsiveView<DashboardController> {
  const DashboardView({super.key});

  @override
  Widget mobile(BuildContext context) {
    return MobileDashboard();
  }

  @override
  Widget tablet(BuildContext context) {
    return TabletDashboard();
  }

  @override
  Widget desktop(BuildContext context) {
    return DesktopDashboard();
  }
}
```

## CLI Commands

### Create View

```bash
magic make:view Dashboard                     # Stateless view
magic make:view Auth/Login --stateful         # Stateful in subfolder
magic make:view Dashboard --responsive        # Responsive view
```

**Options:**

| Option | Description |
|--------|-------------|
| `--stateful` | Create stateful view with lifecycle hooks |
| `--responsive`, `-r` | Create responsive view with mobile/tablet/desktop layouts |

**Output:** Creates `lib/resources/views/<name>_view.dart`
