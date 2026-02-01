# MVC Architecture Reference

## Controllers

```dart
class UserController extends MagicController with MagicStateMixin<User>, ValidatesRequests {
  @override
  void onInit() {
    super.onInit();
    fetchUser();
  }

  Future<void> fetchUser() async {
    setLoading();
    try {
      final user = await User.find(1);
      user != null ? setSuccess(user) : setEmpty();
    } catch (e) {
      setError(e.toString());
    }
  }
}
```

### MagicStateMixin<T>
- `setLoading()` — show loading state
- `setSuccess(T data)` — show data
- `setError(String message)` — show error
- `setEmpty()` — show empty state
- `renderState(Widget Function(T) onSuccess, {onError, onLoading, onEmpty})` — declarative UI

### ValidatesRequests
- `setErrors(Map<String, List<String>>)` — set server validation errors
- `hasErrors` → bool
- `getError(String field)` → String?
- `clearErrors()` → void

## Views

### Stateless View
```dart
class UserView extends MagicView<UserController> {
  const UserView({super.key});

  @override
  Widget build(BuildContext context) {
    return controller.renderState(
      (user) => Text(user.name),
      onError: (msg) => Text('Error: $msg'),
      onLoading: () => CircularProgressIndicator(),
      onEmpty: () => Text('No data'),
    );
  }
}
```

### Stateful View
```dart
class LoginView extends MagicStatefulView<AuthController> {
  const LoginView({super.key});
  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends MagicStatefulViewState<AuthController, LoginView> {
  @override void onInit() { /* after controller resolved */ }
  @override void onClose() { /* cleanup */ }
  @override
  Widget build(BuildContext context) => Scaffold(...);
}
```

Auto-features: controller injection via `Magic.find<T>()`, auto-listen, auto-rebuild on `notifyListeners()`.

## MagicForm

```dart
MagicForm(
  formData: form,
  child: Column(children: [
    form.field('email', rules: [Required(), Email()]),
    form.field('password', rules: [Required(), Min(8)]),
    ElevatedButton(
      onPressed: () {
        if (form.validate()) controller.submit(form.data);
      },
      child: Text('Submit'),
    ),
  ]),
)
```

### MagicFormData
```dart
late final form = MagicFormData({
  'email': '',
  'password': '',
}, controller: controller);
```

Methods: `field()`, `checkbox()`, `validate()`, `data` getter, `reset()`.

## MagicFeedback (Context-Free UI)

```dart
Magic.snackbar('Title', 'Message');
Magic.success('Done', 'Saved successfully');
Magic.error('Oops', 'Something failed');
Magic.toast('Quick message');
Magic.dialog(MyDialogWidget());
Magic.confirm(title: 'Delete?', message: 'Are you sure?');  // → Future<bool>
Magic.loading(message: 'Please wait...');
Magic.closeLoading();
```

## MagicResponsiveView

```dart
class DashboardView extends MagicResponsiveView<DashboardController> {
  @override Widget mobile() => MobileLayout();
  @override Widget tablet() => TabletLayout();
  @override Widget desktop() => DesktopLayout();
}
```

## MagicCan (Authorization UI)

```dart
MagicCan(
  ability: 'edit-post',
  arguments: [post],
  child: EditButton(),
  fallback: DisabledButton(),  // optional
)
```
