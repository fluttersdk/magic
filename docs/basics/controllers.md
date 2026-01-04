# Controllers

- [Introduction](#introduction)
- [Writing Controllers](#writing-controllers)
    - [Basic Controllers](#basic-controllers)
    - [Single Action Controllers](#single-action-controllers)
- [Controller State Management](#controller-state-management)
    - [The MagicStateMixin](#the-magicstatemixin)
    - [Rendering State](#rendering-state)
- [Validation Handling](#validation-handling)
- [Controller Lifecycle](#controller-lifecycle)
- [Generating Controllers](#generating-controllers)

<a name="introduction"></a>
## Introduction

Instead of defining all of your request handling logic as closures in your route files, you may wish to organize this behavior using "controller" classes. Controllers can group related request handling logic into a single class. Controllers are stored in the `lib/app/controllers` directory.

<a name="writing-controllers"></a>
## Writing Controllers

<a name="basic-controllers"></a>
### Basic Controllers

To generate a new controller, use the `make:controller` Magic CLI command:

```bash
magic make:controller User
```

A basic controller extends `MagicController` and contains action methods that return widgets:

```dart
import 'package:flutter/material.dart';
import 'package:fluttersdk_magic/fluttersdk_magic.dart';
import '../../resources/views/users/user_list_view.dart';
import '../../resources/views/users/user_show_view.dart';

class UserController extends MagicController {
  /// Singleton accessor - the Magic way!
  static UserController get instance => Magic.findOrPut(UserController.new);

  /// Display a listing of users.
  Widget index() => const UserListView();

  /// Display the specified user.
  Widget show(String id) => UserShowView(userId: id);
  
  /// Show the form for creating a new user.
  Widget create() => const CreateUserView();
}
```

Register the controller's methods as routes:

```dart
MagicRoute.page('/users', () => UserController.instance.index());
MagicRoute.page('/users/create', () => UserController.instance.create());
MagicRoute.page('/users/:id', (id) => UserController.instance.show(id));
```

> [!NOTE]
> The `Magic.findOrPut()` pattern ensures a single controller instance exists, similar to Laravel's service container.

<a name="single-action-controllers"></a>
### Single Action Controllers

If a controller action is particularly complex, you may dedicate an entire controller class to that single action:

```dart
class ExportReportController extends MagicController {
  static ExportReportController get instance => 
      Magic.findOrPut(ExportReportController.new);

  Widget invoke() {
    return const ExportReportView();
  }
}
```

<a name="controller-state-management"></a>
## Controller State Management

<a name="the-magicstatemixin"></a>
### The MagicStateMixin

Controllers may use `MagicStateMixin<T>` to manage async data and loading states:

```dart
class UserController extends MagicController 
    with MagicStateMixin<List<User>> {
  
  static UserController get instance => Magic.findOrPut(UserController.new);

  Widget index() {
    if (isEmpty) loadUsers();
    return const UserListView();
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

#### State Methods

| Method | Description |
|--------|-------------|
| `setLoading()` | Set loading state |
| `setSuccess(T data)` | Set success state with data |
| `setError(String message)` | Set error state with message |
| `setEmpty()` | Set empty state (no data) |

#### State Properties

| Property | Type | Description |
|----------|------|-------------|
| `isLoading` | bool | Currently loading |
| `isSuccess` | bool | Successfully loaded |
| `isError` | bool | Error occurred |
| `isEmpty` | bool | Empty/no data |
| `rxState` | T? | The current data |

<a name="rendering-state"></a>
### Rendering State

Use `renderState` in your view to declaratively handle different states—like Blade's `@if` directives:

```dart
class UserListView extends MagicView {
  @override
  Widget build(BuildContext context) {
    final controller = UserController.instance;
    
    return controller.renderState(
      (users) => ListView.builder(
        itemCount: users.length,
        itemBuilder: (_, i) => UserCard(user: users[i]),
      ),
      onLoading: Center(child: CircularProgressIndicator()),
      onError: (msg) => ErrorWidget(message: msg),
      onEmpty: EmptyState(message: 'No users yet'),
    );
  }
}
```

<a name="validation-handling"></a>
## Validation Handling

Controllers can handle server-side validation errors using the `ValidatesRequests` mixin:

```dart
class AuthController extends MagicController 
    with MagicStateMixin<bool>, ValidatesRequests {
  
  static AuthController get instance => Magic.findOrPut(AuthController.new);

  Future<void> register(Map<String, dynamic> data) async {
    setLoading();
    clearErrors();  // Clear previous validation errors
    
    final response = await Http.post('/register', data: data);
    
    if (response.successful) {
      setSuccess(true);
      Magic.success('Success', 'Account created!');
      MagicRoute.to('/dashboard');
    } else {
      // Automatically handles 422 validation errors
      handleApiError(response, fallback: 'Registration failed');
    }
  }
}
```

### ValidatesRequests Methods

| Method | Description |
|--------|-------------|
| `handleApiError(response)` | Handle 422 and other API errors automatically |
| `setErrorsFromResponse(response)` | Populate errors from 422 validation response |
| `hasError('field')` | Check if a field has an error |
| `getError('field')` | Get error message for a field |
| `hasErrors` | Check if any validation errors exist |
| `clearErrors()` | Clear all validation errors |

> [!TIP]
> Use `MagicFormData` in your view to collect form data. The validation errors automatically bind to form fields.

<a name="controller-lifecycle"></a>
## Controller Lifecycle

Controllers have lifecycle methods you can override:

```dart
class UserController extends MagicController {
  @override
  void onInit() {
    super.onInit();
    // Called when controller is first created
    // Initialize data, start listeners, etc.
  }

  @override
  void onClose() {
    // Called when controller is disposed
    // Cancel subscriptions, clean up resources
    super.onClose();
  }
}
```

<a name="generating-controllers"></a>
## Generating Controllers

The Magic CLI can generate controllers with various options:

```bash
# Basic controller
magic make:controller User

# With state management (MagicStateMixin)
magic make:controller Todo --stateful

# Resource controller with CRUD actions and views
magic make:controller Product --resource

# Nested in subfolder
magic make:controller Admin/Dashboard
```

### Command Options

| Option | Alias | Description |
|--------|-------|-------------|
| `--stateful` | `-s` | Include `MagicStateMixin` for state management |
| `--resource` | `-r` | Generate CRUD controller with associated views |

### Resource Controllers

When using `--resource`, the command generates a full resource controller with:

**Controller actions:**
- `index()` - Display a listing
- `create()` - Show creation form
- `store(data)` - Handle creation
- `show(id)` - Display single item
- `edit(id)` - Show edit form
- `update(id, data)` - Handle update
- `destroy(id)` - Handle deletion

**Views:**
- `lib/resources/views/<name>/index_view.dart`
- `lib/resources/views/<name>/show_view.dart`
- `lib/resources/views/<name>/create_view.dart`
- `lib/resources/views/<name>/edit_view.dart`

Example:

```bash
magic make:controller Task --resource
```

This generates a TaskController with all CRUD actions and four corresponding views.
