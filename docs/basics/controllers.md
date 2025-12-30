# Controllers

## Introduction

Instead of defining all of your request handling logic as closures in your route files, you may wish to organize this behavior using "controller" classes. Controllers can group related request handling logic into a single class. Controllers are stored in the `lib/app/controllers` directory.

## Writing Controllers

### Basic Controllers

A basic controller extends `MagicController` and contains action methods that return widgets:

```dart
import 'package:flutter/material.dart';
import 'package:fluttersdk_magic/fluttersdk_magic.dart';
import '../../resources/views/user/index_view.dart';
import '../../resources/views/user/show_view.dart';

class UserController extends MagicController {
  /// Singleton accessor.
  static UserController get instance => Magic.findOrPut(UserController.new);

  /// Display a listing of users.
  Widget index() => const UsersIndexView();

  /// Display the specified user.
  Widget show(String id) => UserShowView(userId: id);
}
```

You may register the controller's methods as routes:

```dart
MagicRoute.page('/users', () => UserController.instance.index());
MagicRoute.page('/users/:id', (id) => UserController.instance.show(id));
```

### Single Action Controllers

If a controller action is particularly complex, you may find it convenient to dedicate an entire controller class to that single action:

```dart
class ProvisionServerController extends MagicController {
  static ProvisionServerController get instance => 
      Magic.findOrPut(ProvisionServerController.new);

  Widget invoke() {
    // Provision logic...
    return const ProvisioningView();
  }
}
```

## Controller State Management

Controllers may use `MagicStateMixin` to manage async data and loading states:

```dart
class UserController extends MagicController 
    with MagicStateMixin<List<User>> {
  
  static UserController get instance => Magic.findOrPut(UserController.new);

  Widget index() {
    if (isEmpty) loadUsers();
    return const UsersIndexView();
  }

  Future<void> loadUsers() async {
    setLoading();
    
    try {
      final users = await User.all();
      setSuccess(users);
    } catch (e) {
      setError('Failed to load users: $e');
    }
  }
}
```

In your view, use `renderState` to handle the different states:

```dart
@override
Widget build(BuildContext context) {
  return controller.renderState(
    (users) => UsersList(users: users),
    onLoading: const CircularProgressIndicator(),
    onError: (msg) => Text('Error: $msg'),
    onEmpty: const Text('No users found'),
  );
}
```

## Server-Side Validation

Controllers can handle server-side validation errors using the `ValidatesRequests` mixin:

```dart
class AuthController extends MagicController 
    with MagicStateMixin<bool>, ValidatesRequests {
  
  // Clean parameter list thanks to MagicFormData.validated()
  Future<void> register(Map<String, dynamic> data) async {
    setLoading();
    clearErrors();
    
    final response = await Http.post('/register', data: data);
    
    if (response.successful) {
      setSuccess(true);
      MagicRoute.to('/dashboard');
    } else {
      // Handles 422 validation and other errors automatically
      handleApiError(response, fallback: 'Registration failed');
    }
  }
}
```

> **Tip:** Use `MagicFormData` in your view to collect and validate this data cleanly.

### ValidatesRequests Methods

| Method | Description |
|--------|-------------|
| `handleApiError(response)` | Handle 422 and other errors automatically |
| `setErrorsFromResponse(response)` | Populate errors from API 422 |
| `hasError('field')` | Check if field has error |
| `getError('field')` | Get error message |
| `hasErrors` | Check if any errors exist |
| `clearErrors()` | Clear all errors |


## CLI Commands

### Create Controller

```bash
magic make:controller User                    # Basic controller
magic make:controller Todo --stateful         # With MagicStateMixin
magic make:controller Product --resource      # CRUD with views
magic make:controller Admin/Dashboard         # Nested folder
```

**Options:**

| Option | Description |
|--------|-------------|
| `--stateful`, `-s` | Create with MagicStateMixin for state management |
| `--resource`, `-r` | Create resource controller with CRUD actions and views |

**Output:** Creates `lib/app/controllers/<name>_controller.dart`

When using `--resource`, the command also generates 4 views:
- `lib/resources/views/<name>/index_view.dart`
- `lib/resources/views/<name>/show_view.dart`
- `lib/resources/views/<name>/create_view.dart`
- `lib/resources/views/<name>/edit_view.dart`
