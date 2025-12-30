# Magic Framework - Agent Rules

> Prescriptive rules for AI agents. Magic provides Laravel-style architecture for Flutter.

## Core Import
```dart
import 'package:fluttersdk_magic/fluttersdk_magic.dart';
```
**DO NOT** import dio, go_router directly. Use Magic facades.

---

## Directory Structure
| Path | Purpose |
|------|---------|
| `lib/config/` | Configuration files (app.dart, auth.dart, database.dart) |
| `lib/app/controllers/` | Controllers (suffix: `Controller`) |
| `lib/app/models/` | Eloquent models with HasTimestamps, InteractsWithPersistence |
| `lib/app/policies/` | Authorization policies (suffix: `Policy`) |
| `lib/app/middleware/` | Route middleware classes |
| `lib/resources/views/` | View classes (suffix: `View`) |
| `lib/routes/` | Route definitions (web.dart, api.dart) |
| `lib/database/migrations/` | Database migrations |
| `lib/database/seeders/` | Database seeders |
| `lib/database/factories/` | Model factories |
| `assets/lang/` | JSON translation files (en.json, tr.json) |

---

## Wind UI (Hybrid Strategy)

> [!IMPORTANT]
> **UI Strategy**: Use Wind UI widgets (`WDiv`, `WText`, `WButton`, etc.) for building consistent interfaces. Use standard Flutter widgets (`Container`, `Column`, `Row`) only if requested.

```dart
WDiv(className: "p-4 flex flex-col gap-4", children: [
  WText("Title", className: "text-xl font-bold"),
  WButton(child: Text("Submit"), className: "bg-blue-500"),
])
```

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
  @override bool get useLocal => false;
  @override bool get useRemote => true;

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
final post = Post()..fill({'title': 'Hello', 'body': 'World'});
await post.save(); print(post.id);
final posts = await Post.all();
final post = await Post.find(1);
post.title = 'Updated'; await post.save();
await post.delete();
await post.refresh();
post.isDirty(); post.isDirty('title'); post.getDirty();
```

### Relationship Casting
```dart
class Post extends Model with HasTimestamps, InteractsWithPersistence {
  @override
  Map<String, Model Function()> get relations => {
    'user': User.new,          // Single nested model
    'comments': Comment.new,   // List of nested models
  };

  User? get user => getRelation<User>('user');
  List<Comment> get comments => getRelations<Comment>('comments');
}

final post = await Post.find(1);
print(post?.user?.name);  // "John"
```

---

## Authentication

```dart
// 1. Register user factory (once at boot)
Auth.manager.setUserFactory((data) => User.fromMap(data));

// 2. Login (app handles API, Auth stores state)
final response = await Http.post('/login', data: credentials);
final user = User.fromMap(response['data']['user']);
await Auth.login({
  'token': response['data']['token'],
  'refresh_token': response['data']['refresh_token'],
}, user);

// 3. State checks
Auth.check();        // bool - is logged in?
Auth.user<User>();   // Get typed user model
Auth.id();           // Get user ID

// 4. Logout & Restore
await Auth.logout();
await Auth.restore();  // cache-first, then API

// 5. Token access
await Auth.hasToken();
await Auth.getToken();
await Auth.refreshToken();
```

**Guard Contract:** `login(data, user)`, `logout()`, `check()/guest`, `user<T>()/id()`, `hasToken()/getToken()/refreshToken()`, `restore()`

Features: User caching (instant restore), auto token refresh on 401, driver-agnostic interceptors.

**Register Custom Guard:**
```dart
Auth.manager.extend('firebase', (c) => FirebaseGuard());
```

---

## Authorization (Gate & Policies)
```dart
Gate.define('edit-post', (user, post) => user.id == post.userId);
Gate.define('admin-access', (user, _) => user.isAdmin);

Gate.before((user, ability) {
  if (user.isAdmin) return true;
  return null;  // continue normal check
});

if (Gate.allows('edit-post', post)) { showEditButton(); }
if (Gate.denies('delete-post', post)) { showAccessDenied(); }

MagicCan(ability: 'edit-post', arguments: post, child: EditButton())
MagicCannot(ability: 'view-premium', child: UpgradePrompt())
```

### Policy Template
```dart
class PostPolicy extends Policy {
  @override
  void register() {
    Gate.define('view-post', view);
    Gate.define('update-post', update);
    Gate.define('delete-post', delete);
  }

  bool view(Model user, Post post) => post.isPublished || user.id == post.userId;
  bool update(Model user, Post post) => user.id == post.userId;
  bool delete(Model user, Post post) => user.isAdmin || user.id == post.userId;
}
// Register in boot(): PostPolicy().register();
```

---

## Vault (Secure Storage)
iOS Keychain / Android EncryptedSharedPreferences. **DO NOT** use SharedPreferences for secrets.
```dart
await Vault.put('api_key', 'sk_live_123456');
final token = await Vault.get('api_key');
await Vault.delete('api_key');
await Vault.flush();
```

---

## Cache
```dart
await Cache.get('key', defaultValue: 'default');
await Cache.put('key', 'value', ttl: Duration(minutes: 10));
await Cache.forget('key');
await Cache.flush();
await Cache.remember('users', Duration(minutes: 5), () async => await fetchUsers());
```

---

## Storage
```dart
await Storage.put('avatars/user.jpg', bytes, mimeType: 'image/jpeg');
final bytes = await Storage.get('avatars/user.jpg');
final url = await Storage.url('avatars/user.jpg');
await Storage.delete('avatars/old.jpg');
await Storage.disk('public').put('uploads/file.pdf', bytes);

final img = await Pick.image();
await img!.store('photos/vacation.jpg');
await img!.storeAs('photos');
```

---

## File Picker
```dart
final img = await Pick.image(maxWidth: 800, imageQuality: 80);
final photo = await Pick.camera(preferredCamera: CameraDevice.front);
final video = await Pick.video(maxDuration: Duration(minutes: 5));
final file = await Pick.file(extensions: ['pdf', 'doc']);
final files = await Pick.files(extensions: ['jpg', 'png']);

img.name; img.extension; img.size; img.isImage; img.mimeType;
await img.readAsBytes();
await img.upload('/api/upload', fieldName: 'avatar', data: {'user_id': '123'});
```

---

## Localization
```dart
trans('welcome', {'name': 'User'});  // "Welcome, User!"
await Lang.setLocale(Locale('tr'));
```
JSON files in `assets/lang/{locale}.json`:
```json
{"welcome": "Welcome, :name!"}
```

---

## Carbon (Date/Time)
```dart
Carbon.now(); Carbon.parse('2024-01-15'); Carbon.fromDateTime(DateTime.now());

now.addDays(5); now.subDays(3); now.addMonths(2); now.addHours(6);
now.startOfDay(); now.endOfDay(); now.startOfMonth(); now.endOfMonth();

now.format('yyyy-MM-dd'); now.diffForHumans(); now.toFormattedDateString();

now.isToday(); now.isPast(); now.isFuture(); now.isWeekend();
now.isAfter(other); now.isBefore(other); now.isBetween(start, end);
```

---

## Logging
PSR-3 compatible logging with beautiful console output.
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
Channels: `console`, `stack`. Configure in `config/logging.dart`.

---

## Events
```dart
// Define event
class OrderShipped extends MagicEvent {
  final Order order;
  OrderShipped(this.order);
}

// Define listener class
class SendShippingNotification extends MagicListener<OrderShipped> {
  @override
  Future<void> handle(OrderShipped event) async {
    await NotificationService.send(event.order.userEmail, 'Your order shipped!');
  }
}

// Listen with closure
Event.listen<OrderShipped>((e) => print(e.order.id));

// Dispatch event
await Event.dispatch(OrderShipped(order));
```

---

## MagicStateMixin (State Management)
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

controller.renderState(
  (users) => UsersList(users: users),
  onLoading: CircularProgressIndicator(),
  onError: (msg) => Text(msg),
);
```
Methods: `setLoading()`, `setSuccess(data)`, `setError(msg)`, `isEmpty`, `renderState()`

---

## Validation
```dart
// View
late final form = MagicFormData({'email': '', 'agree': false}, controller: controller);
@override void onClose() => form.dispose();

WFormInput(controller: form['email'], validator: rules([Required(), Email()], field: 'email'));
WButton(onTap: () {
  final data = form.validated();
  if (data.isNotEmpty) controller.register(data);
}, child: Text('Submit'));

// Controller with ValidatesRequests
clearErrors();
final response = await Http.post('/register', data: data);
if (response.successful) setSuccess(true);
else handleApiError(response);
```
Rules: `Required()`, `Email()`, `Min(n)`, `Max(n)`, `Confirmed()`, `Same('field')`, `Accepted()`

`ValidatesRequests` mixin provides `clearErrors()`, `handleApiError(response)`, and binds to `MagicFormData` errors.

---

## Routing
```dart
MagicRoute.page('/path', () => Widget());
MagicRoute.page('/user/:id', (id) => UserView(id: id));
MagicRoute.to('/path');       // navigate (replace)
MagicRoute.push('/path');     // push (back button works)
MagicRoute.back();
MagicRoute.toNamed('user.show', parameters: {'id': '1'});
MagicRoute.group(prefix: '/admin', middleware: ['auth'], layout: (c) => AdminLayout(child: c), routes: () {});
```

---

## HTTP
```dart
await Http.get('/users', query: {'page': 1});
await Http.post('/users', data: {'name': 'John'});
await Http.put('/users/1', data: {...}); await Http.delete('/users/1');
if (response.successful) { }
if (response.unauthorized) { }
if (response.isValidationError) { }
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

## RULES

### ✅ DO
- Use Wind UI widgets (`WDiv`, `WButton`, `WInput`, `WText`, `WCard`)
- Use `MagicRoute` for navigation (not `Navigator`)
- Use `Magic.*` for dialogs, toasts, loading
- Use `DB`, `Http` facades (not `sqflite`, `dio` directly)
- Use `Vault` for secrets (not `SharedPreferences`)
- Follow file naming conventions (`Controller`, `View`, `Policy` suffixes)
- Include `HasTimestamps, InteractsWithPersistence` mixins on models
- Add static `find()` and `all()` helpers on models

### ❌ DON'T
- Use `BuildContext` for navigation
- Import `sqflite`, `dio`, `go_router` directly
- Store secrets in `SharedPreferences`
- Create files outside specified directories