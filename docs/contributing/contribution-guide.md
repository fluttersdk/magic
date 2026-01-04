# Contribution Guide

- [Introduction](#introduction)
- [Development Setup](#development-setup)
- [Project Structure](#project-structure)
- [Coding Style](#coding-style)
- [Testing](#testing)
- [Pull Requests](#pull-requests)
- [Documentation](#documentation)

<a name="introduction"></a>
## Introduction

Thank you for considering contributing to Magic! This guide will help you get started with contributing to the framework.

<a name="development-setup"></a>
## Development Setup

### Prerequisites

- Dart SDK 3.4.0 or higher
- Flutter 3.22.0 or higher
- Git

### Clone the Repository

```bash
git clone https://github.com/fluttersdk/magic.git
cd magic
```

### Install Dependencies

```bash
flutter pub get
```

### Run Tests

```bash
flutter test
```

<a name="project-structure"></a>
## Project Structure

```
lib/
├── src/
│   ├── auth/           # Authentication system
│   ├── cache/          # Caching
│   ├── database/       # Database & Eloquent
│   ├── events/         # Event system
│   ├── facades/        # Facade classes
│   ├── foundation/     # Core Magic class
│   ├── http/           # HTTP client & controllers
│   ├── localization/   # i18n
│   ├── providers/      # Service providers
│   ├── routing/        # Router
│   ├── support/        # Helpers & utilities
│   ├── ui/             # View system
│   └── validation/     # Validation rules
└── fluttersdk_magic.dart  # Barrel export
```

### Key Files

| File | Purpose |
|------|---------|
| `lib/src/foundation/magic.dart` | Core Magic facade |
| `lib/src/facades/*.dart` | Public API facades |
| `lib/src/providers/*.dart` | Service providers |
| `lib/fluttersdk_magic.dart` | Public exports |

<a name="coding-style"></a>
## Coding Style

### Dart Style

Follow the [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style):

```dart
// Use camelCase for variables and functions
final userName = 'John';
void loadUsers() {}

// Use PascalCase for classes
class UserController {}

// Use snake_case for file names
// user_controller.dart
```

### Documentation

Document all public APIs using DartDoc:

```dart
/// Retrieves a configuration value using dot notation.
/// 
/// ```dart
/// final name = Config.get<String>('app.name', 'Default');
/// ```
/// 
/// Returns [defaultValue] if the key doesn't exist.
static T? get<T>(String key, [T? defaultValue]) {
  // ...
}
```

### Laravel-Style APIs

When designing APIs, follow Laravel's patterns:

```dart
// ✅ Good - Laravel-like fluent API
MagicRoute.page('/users', () => UserController.instance.index())
    .name('users.index')
    .middleware(['auth']);

// ❌ Bad - Non-fluent API
registerRoute('/users', 'users.index', UserController, 'index', ['auth']);
```

<a name="testing"></a>
## Testing

### Test Structure

```
test/
├── unit/           # Unit tests for individual classes
├── feature/        # Integration tests
└── test_helper.dart
```

### Writing Tests

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClassName', () {
    test('method does something', () {
      // Arrange
      final instance = ClassName();
      
      // Act
      final result = instance.method();
      
      // Assert
      expect(result, equals(expected));
    });
  });
}
```

### Test Coverage

Aim for high test coverage on new code:

```bash
flutter test --coverage
```

<a name="pull-requests"></a>
## Pull Requests

### Before Submitting

1. **Fork** the repository
2. **Create a branch** for your feature/fix
3. **Write tests** for new functionality
4. **Run all tests** to ensure nothing is broken
5. **Update documentation** if needed
6. **Follow the coding style**

### PR Template

```markdown
## Description
Brief description of changes.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Checklist
- [ ] Tests pass locally
- [ ] New tests added for new features
- [ ] Documentation updated
- [ ] No breaking changes (or documented if any)
```

### Commit Messages

Use clear, descriptive commit messages:

```
feat(auth): add token refresh functionality

- Add refreshToken() method to Guard contract
- Implement auto-refresh in AuthInterceptor
- Update documentation
```

Prefixes:
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation only
- `refactor:` - Code refactoring
- `test:` - Adding tests
- `chore:` - Maintenance

<a name="documentation"></a>
## Documentation

### Updating Docs

Documentation lives in the `docs/` directory:

```
docs/
├── getting-started/
├── basics/
├── security/
├── digging-deeper/
├── eloquent/
├── database/
├── testing/
└── packages/
```

### Documentation Style

Follow Laravel's documentation style:

1. Start with a table of contents
2. Use anchor links for sections
3. Include code examples
4. Use GitHub-style alerts for important notes
5. Keep explanations concise

### Building Docs

Preview documentation locally:

```bash
# If using a docs site generator
npm run docs:dev
```

---

## Questions?

If you have questions about contributing, feel free to:

1. Open a GitHub issue
2. Join our Discord community
3. Email the maintainers

We appreciate all contributions, from bug reports to documentation improvements to new features. Thank you for helping make Magic better!
