# Magic Framework - Agent Rules

> Prescriptive rules for AI agents. Magic provides Laravel-style architecture for Flutter.

## Core Import
```dart
import 'package:fluttersdk_magic/fluttersdk_magic.dart';
```
**DO NOT** import sqflite, dio, go_router directly. Use Magic facades.

---

## Directory Structure
| Path | Purpose |
|------|---------|
| `lib/config/` | Configuration files |
| `lib/app/controllers/` | Controllers (suffix: `Controller`) |
| `lib/app/models/` | Eloquent models |
| `lib/app/policies/` | Policies (suffix: `Policy`) |
| `lib/app/middleware/` | Route middleware |
| `lib/database/migrations/` | Schema migrations |
| `lib/database/seeders/` | Database seeders |
| `lib/database/factories/` | Model factories |
| `lib/resources/views/` | Views (suffix: `View`) |
| `lib/routes/` | Route definitions |
| `assets/lang/` | JSON translation files |

---

## Wind UI (03-wind-ui.md)
**DO NOT** use Flutter `Container`, `Column`, `Row`, `Padding`, `Text`. Use Wind widgets:

```dart
WDiv(className: "flex flex-col p-4 bg-white shadow-lg rounded-xl", children: [...])
WText("Hello", className: "text-xl font-bold text-blue-500")
WButton(onTap: () {}, className: "bg-blue-600 px-4 py-2 rounded-lg text-white", child: WText("Submit"))
WInput(controller: _ctrl, className: "p-3 border rounded-lg focus:ring-2 error:border-red-500")
WImage(src: "url", className: "w-full aspect-video object-cover rounded-xl")
WIcon(Icons.star, className: "text-yellow-400 text-2xl")
```

### State Prefixes
`hover:bg-blue-500`, `focus:ring-2`, `dark:bg-black`, `loading:opacity-50`, `error:border-red-500`

---

## Eloquent Models

### Model Template
```dart
class Post extends Model with HasTimestamps, InteractsWithPersistence {
  @override String get table => 'posts';       // SQLite table
  @override String get resource => 'posts';    // REST API endpoint
  @override List<String> get fillable => ['title', 'body', 'user_id'];
  @override Map<String, String> get casts => {
    'published_at': 'datetime',  // Returns Carbon
    'metadata': 'json',          // Returns Map
    'is_active': 'bool',
  };

  // API/SQLite/Hybrid persistence config
  @override bool get useLocal => false;   // SQLite (default)
  @override bool get useRemote => true;  // REST API (default)

  // Typed accessors
  String? get title => getAttribute('title') as String?;
  set title(String? v) => setAttribute('title', v);
  Carbon? get publishedAt => getAttribute('published_at') as Carbon?;

  // REQUIRED static helpers
  static Future<Post?> find(dynamic id) =>
      InteractsWithPersistence.findById<Post>(id, Post.new);
  static Future<List<Post>> all() =>
      InteractsWithPersistence.allModels<Post>(Post.new);
}
```

### CRUD Operations
```dart
// CREATE
final post = Post()..fill({'title': 'Hello', 'body': 'World'});
await post.save();  // Saves to local + syncs to API
print(post.id);

// READ
final posts = await Post.all();
final post = await Post.find(1);  // Checks local first, then API

// UPDATE
post.title = 'Updated';
await post.save();

// DELETE
await post.delete();

// REFRESH & DIRTY
await post.refresh();
post.isDirty(); post.isDirty('title'); post.getDirty();
```

### Relationship Casting
```dart
// Define relations for nested API responses
class Post extends Model with HasTimestamps, InteractsWithPersistence {
  @override
  Map<String, Model Function()> get relations => {
    'user': User.new,          // Single nested model
    'comments': Comment.new,   // List of nested models
  };

  User? get user => getRelation<User>('user');
  List<Comment> get comments => getRelations<Comment>('comments');
}

// Usage
final post = await Post.find(1);
print(post?.user?.name);  // "John"
```

### MagicStateMixin (State Management)
```dart
class UserController extends MagicController with MagicStateMixin<List<User>> {
  static UserController get instance => Magic.findOrPut(UserController.new);

  Widget index() { if (isEmpty) loadUsers(); return UsersView(); }

  Future<void> loadUsers() async {
    setLoading();
    try { setSuccess(await User.all()); }
    catch (e) { setError('Failed: $e'); }
  }
}

// In View: render states
controller.renderState(
  (users) => UsersList(users: users),
  onLoading: CircularProgressIndicator(),
  onError: (msg) => Text(msg),
);
```
Methods: `setLoading()`, `setSuccess(data)`, `setError(msg)`, `isEmpty`, `renderState()`

---

## Authentication
```dart
// Login
final success = await Auth.attempt({'email': 'user@test.com', 'password': 'secret'});
if (success) MagicRoute.to('/dashboard');
else Magic.error('Error', 'Invalid credentials');

// State checks
Auth.check();       // bool - is logged in?
Auth.guest;         // bool - is NOT logged in?
Auth.user<User>();  // Get typed user model
Auth.id();          // Get user ID

// Logout
await Auth.logout();
await Auth.refreshUser();
```

---

## Authorization (Gate & Policies)
```dart
// Define abilities
Gate.define('edit-post', (user, post) => user.id == post.userId);
Gate.define('admin-access', (user, _) => user.isAdmin);

// Super admin bypass
Gate.before((user, ability) {
  if (user.isAdmin) return true;
  return null;  // continue normal check
});

// Check abilities
if (Gate.allows('edit-post', post)) { showEditButton(); }
if (Gate.denies('delete-post', post)) { showAccessDenied(); }

// UI widgets (show/hide based on ability)
MagicCan(ability: 'edit-post', arguments: post, child: EditButton())
MagicCannot(ability: 'view-premium', child: UpgradePrompt())
```

### Policy Template
```dart
class PostPolicy extends Policy {
  @override void register() {
    Gate.define('update-post', update);
    Gate.define('delete-post', delete);
  }
  bool update(Model user, Post post) => user.id == post.userId;
  bool delete(Model user, Post post) => user.isAdmin || user.id == post.userId;
}
```

---

## Vault (Secure Storage)
iOS Keychain / Android EncryptedSharedPreferences. **DO NOT** use SharedPreferences for secrets.
```dart
await Vault.put('api_key', 'sk_live_123456');
final token = await Vault.get('api_key');
await Vault.delete('api_key');
await Vault.flush();  // clear entire vault
```

---

## Cache
```dart
await Cache.get('key', defaultValue: 'default');
await Cache.put('key', 'value', ttl: Duration(minutes: 10));
await Cache.forget('key');  // remove
await Cache.flush();        // clear all
await Cache.remember('users', Duration(minutes: 5), () async => await fetchUsersFromApi());
```

---

## Storage
```dart
await Storage.put('avatars/user.jpg', bytes);
final bytes = await Storage.get('avatars/user.jpg');
final url = await Storage.url('path'); await Storage.delete('path');
await Pick.image().then((img) => img?.store('photos/pic.jpg'));
```

---

## File Picker
```dart
final img = await Pick.image(maxWidth: 800, imageQuality: 80);
final photo = await Pick.camera(); final video = await Pick.video();
final file = await Pick.file(extensions: ['pdf', 'doc']);
// MagicFile: img.name, img.extension, img.isImage
await img.upload('/api/upload', fieldName: 'avatar');
```

---

## Localization
```dart
trans('welcome', {'name': 'User'});  // "Welcome, User!"
trans('auth.failed');                 // "Authentication failed."
await Lang.setLocale(Locale('tr'));
```
JSON files in `assets/lang/{locale}.json`:
```json
{
  "welcome": "Welcome, :name!",
}
```

---

## Carbon (Date/Time)
```dart
Carbon.now();
Carbon.parse('2024-01-15');
Carbon.fromDateTime(DateTime.now());
Carbon.create(year: 2025);

// Manipulation (immutable)
now.addDays(5); now.subDays(3); now.addMonths(2); now.addHours(6);
now.startOfDay(); now.endOfDay(); now.startOfMonth(); now.endOfMonth();

// Formatting
now.format('yyyy-MM-dd');
now.diffForHumans();  // "2 hours ago"
now.toFormattedDateString();

// Comparison
now.isToday(); now.isPast(); now.isFuture(); now.isWeekend();
now.isAfter(other); now.isBefore(other); now.isBetween(start, end);
```

---

## Logging
```dart
Log.debug('Debugging info');
Log.info('User logged in', {'user_id': userId, 'email': email});
Log.notice('Notable event');
Log.warning('Low storage');
Log.error('Operation failed', {'error': e.toString()});
Log.critical('System down');
Log.alert('Immediate action needed');
Log.emergency('App unusable');
```

---

## Events
```dart
// Define event
class OrderShipped extends MagicEvent {
  final Order order;
  OrderShipped(this.order);
}

// Define listener
class SendNotification extends MagicListener<OrderShipped> {
  @override
  Future<void> handle(OrderShipped event) async {
    //
  }
}

// Listen & dispatch
Event.listen<OrderShipped>((e) => print(e.order.id));
await Event.dispatch(OrderShipped(order));
```

---

## Validation (View-side)
```dart
WFormInput(
  controller: _email,
  type: InputType.email,
  label: 'Email',
  className: "p-3 border rounded-lg focus:ring-2 error:border-red-500",
  validator: FormValidator.rules([Required(), Email()], field: 'email'),
)
```
Rules: `Required()`, `Email()`, `Min(n)`, `Max(n)`, `Confirmed()`, `Same('field')`, `Accepted()`

---

## Routing
```dart
MagicRoute.page('/path', () => Widget());
MagicRoute.page('/user/:id', (id) => UserView(id: id));
MagicRoute.page('/posts/:postId/comments/:commentId', (postId, commentId) => CommentView(...));
MagicRoute.to('/path');       // navigate (replace)
MagicRoute.push('/path');     // push (back button works)
MagicRoute.back();
MagicRoute.toNamed('user.show', parameters: {'id': '1'});
MagicRoute.group(prefix: '/admin', middleware: ['auth'], layout: (c) => AdminLayout(child: c), routes: () { ... });
```

---

## Database (Query Builder)
```dart
await DB.table('users').get();
await DB.table('users').where('id', 1).first();
await DB.table('users').where('age', '>=', 18).get();
await DB.table('users').whereNull('deleted_at').whereNotNull('email').get();
await DB.table('users').orderBy('created_at', 'desc').limit(10).offset(20).get();
await DB.table('users').count(); await DB.table('users').exists();
await DB.table('users').value<String>('email'); await DB.table('users').pluck<String>('email');
await DB.table('users').insert({'name': 'John', 'email': 'j@test.com'});
await DB.table('users').where('id', 1).update({'name': 'Jane'});
await DB.table('users').where('id', 1).delete();
await DB.transaction(() async { ... });
```

---

## HTTP
```dart
await Http.get('/users', query: {'page': 1});
await Http.post('/users', data: {'name': 'John'});
await Http.put('/users/1', data: {...}); await Http.delete('/users/1');
if (response.successful) { ... } if (response.unauthorized) { ... }
```

---

## UI Feedback (Magic Facade)
```dart
Magic.success('Success', 'Saved!'); Magic.error('Error', 'Failed');
Magic.info('Info', 'Update available'); Magic.warning('Warning', 'Low storage');
Magic.loading(message: 'Please wait...'); Magic.closeLoading();
Magic.toast('Copied!');
Magic.dialog(MyWidget()); Magic.closeDialog();
final confirmed = await Magic.confirm(title: 'Delete?', message: 'Cannot be undone', isDangerous: true);
```

---

## CLI Commands
| Command | Description |
|---------|-------------|
| `magic make:model Name --all` | Model + migration + seeder + factory + policy + controller + views |
| `magic make:controller Name --resource` | Controller with CRUD views |
| `magic make:view Name --stateful` | Stateful view |
| `magic make:policy Name --model=Post` | Policy for model |
| `magic make:migration create_x_table` | Migration |
| `magic make:lang fr` | Translation file |

---

## FORBIDDEN
- ❌ `BuildContext` for navigation → use `MagicRoute`
- ❌ `showDialog()`, `showSnackBar()` → use `Magic.*`
- ❌ `Container`, `Column`, `Row`, `Padding` → use `WDiv`
- ❌ `Text` → use `WText`
- ❌ `sqflite`, `dio` directly → use `DB`, `Http` facades
- ❌ `SharedPreferences` for secrets → use `Vault`
- ❌ Files outside specified directories
- ❌ Missing `Controller`/`View`/`Policy` suffixes
- ❌ Models without `HasTimestamps, InteractsWithPersistence` mixins
- ❌ Models without static `find()` and `all()` helpers
