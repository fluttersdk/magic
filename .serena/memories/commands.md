# Project Commands

## Development
```bash
# Run example app
cd example && flutter run

# Watch for changes (hot reload in IDE)
flutter run --hot
```

## Code Quality
```bash
# Analyze code for issues
dart analyze

# Format code
dart format .

# Fix auto-fixable issues
dart fix --apply
```

## Testing
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/specific_test.dart

# Run with coverage
flutter test --coverage
```

## Dependencies
```bash
# Get dependencies
flutter pub get

# Upgrade dependencies
flutter pub upgrade

# Check outdated packages
flutter pub outdated
```

## Documentation
```bash
# Generate API docs
dart doc .
```

## Publishing (for package maintainers)
```bash
# Dry run publish check
flutter pub publish --dry-run

# Publish to pub.dev
flutter pub publish
```

## Magic CLI Commands (for end users)
```bash
# Install CLI globally
dart pub global activate fluttersdk_magic_cli

# Initialize Magic in a project
magic init

# Scaffolding commands
magic make:model User
magic make:controller UserController
magic make:view LoginView
magic make:policy PostPolicy
magic make:migration create_users_table
magic make:seeder UserSeeder
magic make:provider PaymentProvider
magic make:lang tr
```
