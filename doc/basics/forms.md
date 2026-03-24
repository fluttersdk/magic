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
- [Form Processing](#form-processing)
- [Error Management](#error-management)
- [Form Introspection](#form-introspection)
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
// Set text field value
form.set('email', 'john@example.com');

// Set non-text field value (bool, list, etc.)
form.setValue('remember_me', true);
form.setValue('tags', ['flutter', 'magic']);
```

> [!NOTE]
> `set(field, value)` is for text fields (backed by `TextEditingController`).
> `setValue(field, value)` is for non-text fields (backed by `ValueNotifier`).

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

<a name="form-processing"></a>
## Form Processing

The `process()` method wraps an async action with automatic loading state management. It sets `isProcessing` to `true` before execution and `false` after, regardless of success or failure.

### Basic Usage

```dart
void _submit() async {
  final data = form.validated();
  if (data.isEmpty) return;

  await form.process(() => controller.register(data));
}
```

### Preventing Double Submissions

`process()` throws a `StateError` if the form is already processing, preventing concurrent submissions:

```dart
void _submit() async {
  final data = form.validated();
  if (data.isEmpty) return;

  try {
    await form.process(() => controller.register(data));
  } on StateError {
    // Already processing, ignore
  }
}
```

### Processing-Aware UI

Use `isProcessing` for simple checks, or `processingListenable` for granular rebuilds:

```dart
// Simple: check in build
WButton(
  isLoading: form.isProcessing,
  onTap: _submit,
  child: WText(trans('common.save')),
)

// Efficient: rebuild only the button when processing state changes
MagicBuilder<bool>(
  listenable: form.processingListenable,
  builder: (isProcessing) => WButton(
    isLoading: isProcessing,
    onTap: _submit,
    child: WText(trans('common.save')),
  ),
)
```

> [!TIP]
> Prefer `form.isProcessing` over `controller.isLoading` when you need form-scoped loading state. This avoids full-page rebuilds and keeps loading indicators tied to the specific form being submitted.

<a name="error-management"></a>
## Error Management

### Clearing All Errors

Use `clearErrors()` on the controller to remove all validation errors at once:

```dart
class AuthController extends MagicController with ValidatesRequests {
  Future<void> register(Map<String, dynamic> data) async {
    clearErrors();  // Clear previous errors before new submission

    final response = await Http.post('/register', data: data);

    if (!response.successful) {
      handleApiError(response);
    }
  }
}
```

### Clearing a Single Field Error

Use `clearFieldError(field)` to remove the error for a specific field. This is called automatically when the user types in a text field or changes a non-text field value, thanks to `MagicFormData`'s built-in listeners:

```dart
// Automatic: MagicFormData auto-clears field errors on input change.
// No manual wiring needed for fields registered in MagicFormData.

// Manual: clear a specific field error explicitly
controller.clearFieldError('email');
```

> [!NOTE]
> `clearErrors()` and `clearFieldError()` live on the `ValidatesRequests` mixin, not on `MagicFormData`. They are accessed through the controller.

<a name="form-introspection"></a>
## Form Introspection

### fieldNames

The `fieldNames` getter returns a `Set<String>` of all registered field names (both text and non-text fields):

```dart
final form = MagicFormData({
  'name': '',
  'email': '',
  'accept_terms': false,
});

print(form.fieldNames); // {'name', 'email', 'accept_terms'}
```

### hasRelevantErrors

The `hasRelevantErrors` getter checks if the controller has validation errors that match fields in this form. This prevents cross-form error leakage when multiple forms share a controller:

```dart
if (form.hasRelevantErrors) {
  // At least one of this form's fields has a server-side error
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
