# Magic Framework Guide

Magic is a Laravel-inspired Flutter framework.

## Core Concepts

- **MVC Architecture**: Controllers handle logic, Models handle data, Views handle UI.
- **Eloquent ORM**: Models extend `Model` and use `InteractsWithPersistence`.
- **Routing**: Use `Route` facade in `routes/app.dart` and `routes/auth.dart`.
- **Facades**: Global access to services via `Magic.instance` or specific facades like `Auth`, `Route`, `Log`.
- **Service Providers**: Register services in `config/app.dart`.

## Coding Standards

- Use `snake_case` for filenames, `PascalCase` for classes.
- Models should define `table`, `resource`, `fillable`.
- Controllers should return `Widget` or `Future<Widget>`.
- Use `MagicRoute` for navigation.

## Common Patterns

### Model
```dart
class User extends Model with HasTimestamps, InteractsWithPersistence {
  @override String get table => 'users';
  @override String get resource => 'users';
  @override List<String> get fillable => ['name', 'email'];
}
```

### Controller
```dart
class UserController extends Controller {
  Future<Widget> index() async {
    final users = await User.all();
    return view('users.index', {'users': users});
  }
}
```
