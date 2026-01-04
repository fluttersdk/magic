# Authorization

- [Introduction](#introduction)
- [Defining Abilities](#defining-abilities)
- [Checking Abilities](#checking-abilities)
- [Super Admin Bypass](#super-admin-bypass)
- [Policies](#policies)
- [UI Integration](#ui-integration)
    - [MagicCan Widget](#magiccan-widget)
    - [MagicCannot Widget](#magiccannot-widget)
- [GateServiceProvider](#gateserviceprovider)
- [Generating Policies](#generating-policies)

<a name="introduction"></a>
## Introduction

In addition to authentication, Magic provides a simple way to authorize user actions against a given resource. Like Laravel, authorization logic is defined using the `Gate` facade and may be checked anywhere in your application.

```dart
// Define abilities (in provider)
Gate.define('update-post', (user, post) => user.id == post.userId);

// Check abilities (in code)
if (Gate.allows('update-post', post)) {
  showEditButton();
}

// Declarative (in UI)
MagicCan(
  ability: 'update-post',
  arguments: post,
  child: EditButton(),
)
```

<a name="defining-abilities"></a>
## Defining Abilities

Register abilities using `Gate.define()`. The callback receives the authenticated user as the first argument and optional model/data as the second:

```dart
// Simple ability (no model)
Gate.define('view-dashboard', (user, _) => user.isActive);

// With model
Gate.define('update-post', (user, post) => user.id == post.userId);

// Complex logic
Gate.define('delete-post', (user, post) {
  return user.isAdmin || user.id == post.userId;
});

// Multiple conditions
Gate.define('manage-team', (user, team) {
  return team.ownerId == user.id || 
         team.admins.contains(user.id);
});
```

<a name="checking-abilities"></a>
## Checking Abilities

### In Controllers

```dart
class PostController extends MagicController {
  Future<void> update(String id, Map<String, dynamic> data) async {
    final post = await Post.find(id);
    
    if (Gate.denies('update-post', post)) {
      Magic.error('Forbidden', 'You cannot edit this post.');
      return;
    }
    
    await post.fill(data).save();
    Magic.success('Success', 'Post updated!');
  }
}
```

### Available Methods

```dart
// Check if allowed
if (Gate.allows('update-post', post)) {
  // User can update
}

// Check if denied
if (Gate.denies('delete-post', post)) {
  // User cannot delete
}

// Alias for allows
if (Gate.check('view-admin')) {
  // Same as allows
}
```

<a name="super-admin-bypass"></a>
## Super Admin Bypass

Use `Gate.before()` to register a global check that runs before all ability checks:

```dart
Gate.before((user, ability) {
  // Super admins bypass all checks
  if (user.role == 'super_admin') return true;
  
  // Continue with normal ability check
  return null;
});
```

Return values:
- `true` → Allow immediately, skip ability check
- `false` → Deny immediately, skip ability check
- `null` → Continue with normal ability check

<a name="policies"></a>
## Policies

Policies organize related authorization logic into classes. This is the recommended approach for complex applications:

```dart
import 'package:fluttersdk_magic/fluttersdk_magic.dart';
import '../models/post.dart';

class PostPolicy extends Policy {
  @override
  void register() {
    Gate.define('view-post', view);
    Gate.define('create-post', create);
    Gate.define('update-post', update);
    Gate.define('delete-post', delete);
  }

  bool view(Authenticatable user, Post post) =>
      post.isPublished || user.id == post.userId;

  bool create(Authenticatable user, Post? post) =>
      (user as User).isActive;

  bool update(Authenticatable user, Post post) =>
      user.id == post.userId;

  bool delete(Authenticatable user, Post post) =>
      (user as User).isAdmin || user.id == post.userId;
}
```

### Registering Policies

Register policies in a service provider:

```dart
class AppGateServiceProvider extends GateServiceProvider {
  AppGateServiceProvider(super.app);

  @override
  Future<void> boot() async {
    await super.boot();

    // Register policies
    PostPolicy().register();
    CommentPolicy().register();
    TeamPolicy().register();
  }
}
```

<a name="ui-integration"></a>
## UI Integration

<a name="magiccan-widget"></a>
### MagicCan Widget

Conditionally render UI based on authorization:

```dart
// Basic usage
MagicCan(
  ability: 'update-post',
  arguments: post,
  child: WButton(
    onTap: () => controller.edit(post),
    child: WText('Edit Post'),
  ),
)

// With placeholder for denied access
MagicCan(
  ability: 'view-admin-panel',
  child: AdminPanel(),
  placeholder: WText('Access Denied', className: 'text-red-500'),
)

// Without arguments
MagicCan(
  ability: 'view-dashboard',
  child: DashboardStats(),
)
```

<a name="magiccannot-widget"></a>
### MagicCannot Widget

Show content only when user **lacks** an ability:

```dart
// Show upgrade prompt to non-premium users
MagicCannot(
  ability: 'access-premium',
  child: WDiv(
    className: 'p-4 bg-amber-500/10 rounded-lg',
    children: [
      WText('Upgrade to Premium', className: 'font-bold text-amber-500'),
      WText('Unlock all features with our premium plan.'),
    ],
  ),
)

// Show read-only indicator
MagicCannot(
  ability: 'edit-post',
  arguments: post,
  child: WText('Read Only', className: 'text-gray-500 italic'),
)
```

<a name="gateserviceprovider"></a>
## GateServiceProvider

Create a dedicated provider for all authorization logic:

```dart
import 'package:fluttersdk_magic/fluttersdk_magic.dart';

class AppGateServiceProvider extends GateServiceProvider {
  AppGateServiceProvider(super.app);

  @override
  Future<void> boot() async {
    await super.boot();

    // Super admin bypass
    Gate.before((user, ability) {
      if ((user as User).role == 'admin') return true;
      return null;
    });

    // Simple abilities
    Gate.define('view-dashboard', (user, _) => true);
    Gate.define('manage-settings', (user, _) => (user as User).isAdmin);

    // Register policies
    PostPolicy().register();
    TeamPolicy().register();
    MonitorPolicy().register();
  }
}
```

Register in `config/app.dart`:

```dart
'providers': [
  (app) => AppGateServiceProvider(app),
  // ... other providers
],
```

<a name="generating-policies"></a>
## Generating Policies

Use Magic CLI to generate policy classes:

```bash
magic make:policy Post
magic make:policy PostPolicy          # Explicit naming
magic make:policy Comment --model=Comment
```

### Options

| Option | Shortcut | Description |
|--------|----------|-------------|
| `--model` | `-m` | The model that the policy applies to |

**Output:** Creates `lib/app/policies/<name>_policy.dart` with CRUD method stubs.

### Generated Policy Template

```dart
import 'package:fluttersdk_magic/fluttersdk_magic.dart';
import '../models/post.dart';

class PostPolicy extends Policy {
  @override
  void register() {
    Gate.define('view-post', view);
    Gate.define('create-post', create);
    Gate.define('update-post', update);
    Gate.define('delete-post', delete);
  }

  bool view(Authenticatable user, Post post) {
    return true;
  }

  bool create(Authenticatable user, Post? post) {
    return true;
  }

  bool update(Authenticatable user, Post post) {
    return user.id == post.userId;
  }

  bool delete(Authenticatable user, Post post) {
    return user.id == post.userId;
  }
}
```

> [!TIP]
> Use policies for model-specific authorization and simple `Gate.define()` calls for general abilities like "view-dashboard" or "access-admin".
