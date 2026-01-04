# Forms

- [Introduction](#introduction)
- [MagicFormData](#magicformdata)
    - [Creating Form Data](#creating-form-data)
    - [Accessing Values](#accessing-values)
    - [Setting Values](#setting-values)
- [MagicForm Widget](#magicform-widget)
- [Form Inputs](#form-inputs)
    - [WFormInput](#wforminput)
    - [WFormCheckbox](#wformcheckbox)
    - [WFormSelect](#wformselect)
- [Form Validation](#form-validation)
- [Submitting Forms](#submitting-forms)
- [Complete Example](#complete-example)

<a name="introduction"></a>
## Introduction

Magic provides a powerful form handling system that combines the simplicity of Laravel's request handling with Flutter's form widgets. Forms are managed through `MagicFormData`, which centralizes form state, validation, and data extraction.

<a name="magicformdata"></a>
## MagicFormData

<a name="creating-form-data"></a>
### Creating Form Data

Create a form data instance in your stateful view:

```dart
class LoginView extends MagicStatefulView<AuthController> {
  const LoginView({super.key});
  
  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends MagicStatefulViewState<AuthController, LoginView> {
  // Define form fields with initial values
  // String values create TextEditingControllers
  // bool values create ValueNotifiers
  late final form = MagicFormData({
    'email': '',
    'password': '',
    'remember_me': false,
  }, controller: controller);

  @override
  void onClose() => form.dispose();  // Always dispose
}
```

<a name="accessing-values"></a>
### Accessing Values

```dart
// Get string value
String email = form.get('email');

// Get typed value
bool? rememberMe = form.value<bool>('remember_me');
int? age = form.value<int>('age');

// Get TextEditingController for text fields
TextEditingController emailController = form['email'];
```

<a name="setting-values"></a>
### Setting Values

```dart
// Set any value
form.setValue('email', 'john@example.com');
form.setValue('remember_me', true);
form.setValue('tags', ['flutter', 'magic']);

// Reset form to initial values
form.reset();
```

<a name="magicform-widget"></a>
## MagicForm Widget

Wrap your form fields with `MagicForm` for automatic state management:

```dart
@override
Widget build(BuildContext context) {
  return MagicForm(
    formData: form,
    child: WDiv(
      className: 'flex flex-col gap-4',
      children: [
        WFormInput(
          controller: form['email'],
          label: trans('attributes.email'),
          validator: rules([Required(), Email()], field: 'email'),
        ),
        WFormInput(
          controller: form['password'],
          type: InputType.password,
          label: trans('attributes.password'),
          validator: rules([Required(), Min(8)], field: 'password'),
        ),
        WButton(
          onTap: _submit,
          child: WText(trans('auth.login')),
        ),
      ],
    ),
  );
}
```

`MagicForm` provides:
- Form key for validation
- Auto-validation mode when errors exist
- Automatic error state binding
- Server-side error display

<a name="form-inputs"></a>
## Form Inputs

<a name="wforminput"></a>
### WFormInput

The primary text input widget with Wind UI styling:

```dart
WFormInput(
  controller: form['email'],
  label: trans('attributes.email'),
  placeholder: trans('fields.email_placeholder'),
  type: InputType.email,  // text, password, email, number, multiline
  validator: rules([Required(), Email()], field: 'email'),
  className: '''
    w-full bg-slate-900 border border-gray-700 rounded-lg p-3 text-white
    focus:border-primary focus:ring-2 focus:ring-primary/30
    error:border-red-500 error:ring-red-200
  ''',
  labelClassName: 'text-sm font-medium text-gray-300 mb-1',
  placeholderClassName: 'text-gray-400',
)
```

#### Input Types

| Type | Description |
|------|-------------|
| `InputType.text` | Standard text input (default) |
| `InputType.password` | Obscured password input |
| `InputType.email` | Email keyboard |
| `InputType.number` | Numeric keyboard |
| `InputType.phone` | Phone number keyboard |
| `InputType.multiline` | Multi-line text area |

<a name="wformcheckbox"></a>
### WFormCheckbox

Checkbox with validation support:

```dart
WFormCheckbox(
  value: form.value<bool>('accept_terms'),
  onChanged: (v) => form.setValue('accept_terms', v),
  label: WText(trans('auth.accept_terms')),
  validator: rules([Accepted()], field: 'accept_terms'),
  className: 'w-5 h-5 checked:bg-primary error:border-red-500',
)
```

<a name="wformselect"></a>
### WFormSelect

Dropdown select with search support:

```dart
WFormSelect<String>(
  value: form.get('country'),
  options: [
    SelectOption(value: 'us', label: 'United States'),
    SelectOption(value: 'gb', label: 'United Kingdom'),
    SelectOption(value: 'tr', label: 'Turkey'),
  ],
  onChange: (v) => form.setValue('country', v),
  label: trans('attributes.country'),
  searchable: true,
  placeholder: trans('fields.select_country'),
  validator: rules([Required()], field: 'country'),
  className: 'w-full bg-slate-900 border border-gray-700 rounded-lg',
)
```

<a name="form-validation"></a>
## Form Validation

### Client-Side Validation

Use the `rules()` helper for client-side validation:

```dart
WFormInput(
  controller: form['email'],
  validator: rules([Required(), Email()], field: 'email'),
)

WFormInput(
  controller: form['password_confirmation'],
  validator: rules([
    Required(),
    Same('password', valueGetter: () => form['password'].text),
  ], field: 'password_confirmation'),
)
```

### Server-Side Errors

Server-side validation errors are automatically displayed when using `ValidatesRequests` mixin in your controller:

```dart
class AuthController extends MagicController with ValidatesRequests {
  Future<void> register(Map<String, dynamic> data) async {
    clearErrors();  // Clear previous errors
    
    final response = await Http.post('/register', data: data);
    
    if (!response.successful) {
      handleApiError(response);  // Auto-populates field errors
    }
  }
}
```

<a name="submitting-forms"></a>
## Submitting Forms

### Using validated()

The `validated()` method validates the form and returns data if valid:

```dart
void _submit() {
  final data = form.validated();
  
  if (data.isNotEmpty) {
    // Form is valid, submit to controller
    controller.register(data);
  }
  // If empty, validation failed (errors are shown automatically)
}
```

### Using validate()

For more control, use `validate()` separately:

```dart
void _submit() {
  if (form.validate()) {
    // Form is valid
    final data = {
      'email': form.get('email'),
      'password': form.get('password'),
      'remember_me': form.value<bool>('remember_me'),
    };
    controller.login(data);
  }
}
```

<a name="complete-example"></a>
## Complete Example

```dart
class RegisterView extends MagicStatefulView<AuthController> {
  const RegisterView({super.key});
  
  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends MagicStatefulViewState<AuthController, RegisterView> {
  late final form = MagicFormData({
    'name': '',
    'email': '',
    'password': '',
    'password_confirmation': '',
    'accept_terms': false,
  }, controller: controller);

  @override
  void onClose() => form.dispose();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _buildForm(),
    );
  }
  
  Widget _buildForm() {
    return WDiv(
      className: 'max-w-md mx-auto p-6 bg-slate-900 rounded-xl',
      child: MagicForm(
        formData: form,
        child: WDiv(
          className: 'flex flex-col gap-4',
          children: [
            WText(trans('auth.register_title'), 
              className: 'text-2xl font-bold text-white text-center'),
            
            WFormInput(
              controller: form['name'],
              label: trans('attributes.name'),
              validator: rules([Required(), Min(2)], field: 'name'),
              className: _inputClass,
            ),
            
            WFormInput(
              controller: form['email'],
              type: InputType.email,
              label: trans('attributes.email'),
              validator: rules([Required(), Email()], field: 'email'),
              className: _inputClass,
            ),
            
            WFormInput(
              controller: form['password'],
              type: InputType.password,
              label: trans('attributes.password'),
              validator: rules([Required(), Min(8)], field: 'password'),
              className: _inputClass,
            ),
            
            WFormInput(
              controller: form['password_confirmation'],
              type: InputType.password,
              label: trans('attributes.password_confirmation'),
              validator: rules([
                Required(),
                Same('password', valueGetter: () => form['password'].text),
              ], field: 'password_confirmation'),
              className: _inputClass,
            ),
            
            WFormCheckbox(
              value: form.value<bool>('accept_terms'),
              onChanged: (v) => setState(() => form.setValue('accept_terms', v)),
              label: WText(trans('auth.accept_terms'), className: 'text-gray-300'),
              validator: rules([Accepted()], field: 'accept_terms'),
            ),
            
            SizedBox(height: 8),
            
            WButton(
              isLoading: controller.isLoading,
              onTap: _submit,
              className: 'w-full bg-primary p-4 rounded-lg',
              child: WText(trans('auth.register'), className: 'text-white text-center'),
            ),
          ],
        ),
      ),
    );
  }
  
  String get _inputClass => '''
    w-full bg-slate-800 border border-gray-700 rounded-lg p-3 text-white
    focus:border-primary error:border-red-500
  ''';
  
  void _submit() {
    final data = form.validated();
    if (data.isNotEmpty) {
      controller.register(data);
    }
  }
}
```
