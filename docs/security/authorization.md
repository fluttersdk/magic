# Authorization

## Introduction

In addition to authentication, Magic provides a simple way to authorize user actions against a given resource. Authorization logic is defined using the `Gate` facade and may be checked with `Gate.allows()` or the declarative `MagicCan` widget.

```dart
// Define (in provider)
Gate.define('update-post', (user, post) => user.id == post.userId);

// Check (in code)
if (Gate.allows('update-post', post)) { ... }

// Declarative (in UI)
MagicCan(
  ability: 'update-post',
  arguments: post,
  child: EditButton(),
)
```

## Defining Abilities

Register abilities using `Gate.define()`. The callback receives the authenticated user as the first argument and optional model/data as the second:

```dart
// Simple ability
Gate.define('view-dashboard', (user, _) => user.isActive);

// With model
Gate.define('update-post', (user, post) => user.id == post.userId);

// Complex logic
Gate.define('delete-post', (user, post) {
  return user.isAdmin || user.id == post.userId;
});
```

## Checking Abilities

```dart
// Check if allowed
if (Gate.allows('update-post', post)) {
  showEditButton();
}

// Check if denied
if (Gate.denies('delete-post', post)) {
  showAccessDenied();
}

// Alias for allows
if (Gate.check('view-admin')) { ... }
```

## Super Admin Bypass

Use `Gate.before()` to register a global check that runs before all abilities:

```dart
Gate.before((user, ability) {
  // Admins can do everything
  if (user.isAdmin) return true;
  
  // Continue with normal check
  return null;
});
```

- Return `true` → Allow immediately
- Return `false` → Deny immediately
- Return `null` → Continue with normal ability check

## Policies

Organize related authorization logic into Policy classes with type-safe model parameters:

```dart
import '../models/post.dart';

class PostPolicy extends Policy {
  @override
  void register() {
    Gate.define('view-post', view);
    Gate.define('create-post', create);
    Gate.define('update-post', update);
    Gate.define('delete-post', delete);
  }

  bool view(Model user, Post post) =>
      post.isPublished || user.id == post.userId;

  bool create(Model user, Post? post) =>
      user.isActive;

  bool update(Model user, Post post) =>
      user.id == post.userId;

  bool delete(Model user, Post post) =>
      user.isAdmin || user.id == post.userId;
}
```

Register policies in your provider:

```dart
@override
Future<void> boot() async {
  PostPolicy().register();
  CommentPolicy().register();
}
```

## UI Integration

### MagicCan Widget

Conditionally render content based on authorization:

```dart
MagicCan(
  ability: 'update-post',
  arguments: post,
  child: WButton(
    text: 'Edit Post',
    onTap: () => controller.edit(post),
  ),
)
```

### With Placeholder

```dart
MagicCan(
  ability: 'view-admin-panel',
  child: AdminPanel(),
  placeholder: Text('Access Denied'),
)
```

### MagicCannot Widget

Show content only when user LACKS an ability:

```dart
MagicCannot(
  ability: 'view-premium',
  child: UpgradePrompt(),
)
```

## GateServiceProvider

Create a provider to register all your abilities:

```dart
class AppGateServiceProvider extends GateServiceProvider {
  AppGateServiceProvider(super.app);

  @override
  Future<void> boot() async {
    await super.boot();

    // Super admin bypass
    Gate.before((user, ability) {
      if (user.isAdmin) return true;
      return null;
    });

    // Register abilities
    Gate.define('update-post', (user, post) => user.id == post.userId);

    // Or use policies
    PostPolicy().register();
  }
}
```

Register in `config/app.dart`:

```dart
'providers': [
  (app) => AppGateServiceProvider(app),
],
```

## Events

The Gate system fires events:

| Event | When Fired |
|-------|------------|
| `GateAbilityDefined` | `Gate.define()` is called |
| `GateAccessChecked` | After any ability check |
| `GateAccessDenied` | When access is denied |

### Logging Denied Access

```dart
Event.listen<GateAccessDenied>((event) {
  Log.warning('Denied: ${event.ability} for user ${event.user?.id}');
});
```

## CLI Commands

### Create Policy

```bash
magic make:policy PostPolicy
magic make:policy Post           # Auto-appends 'Policy'
magic make:policy Comment --model=Comment
```

**Options:**

| Option | Description |
|--------|-------------|
| `--model`, `-m` | The model that the policy applies to |

**Output:** Creates `lib/app/policies/post_policy.dart` with CRUD ability definitions.
