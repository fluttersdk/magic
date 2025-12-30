# UI Helpers

## Introduction

Magic provides context-free UI feedback utilities through the `Magic` facade. Show snackbars, dialogs, confirmations, loading overlays, and toasts from **anywhere**—controllers, services, or callbacks—without passing `BuildContext`.

```dart
// No context needed!
Magic.success('Done', 'User created successfully');
Magic.confirm(title: 'Delete?', message: 'This cannot be undone');
Magic.loading();
```

## Snackbars

Show notification messages at the bottom of the screen.

### Basic Snackbar

```dart
Magic.snackbar('Title', 'Message');
```

### Typed Snackbars

```dart
Magic.success('Success', 'Operation completed');
Magic.error('Error', 'Something went wrong');
Magic.info('Info', 'New update available');
Magic.warning('Warning', 'Low storage space');
```

### With Options

```dart
Magic.snackbar(
  'Custom',
  'Message',
  type: 'info',
  duration: Duration(seconds: 5),
);
```

## Dialogs

### Custom Dialog

Display any widget in a centered dialog:

```dart
Magic.dialog(
  WDiv(
    className: 'p-6',
    children: [
      WText('Custom Content'),
      WButton(onTap: () => Magic.closeDialog(), child: Text('Close')),
    ],
  ),
);
```

### Confirmation Dialog

Ask the user to confirm an action:

```dart
final confirmed = await Magic.confirm(
  title: 'Delete Item',
  message: 'Are you sure you want to delete this item?',
  confirmText: 'Delete',
  cancelText: 'Cancel',
);

if (confirmed) {
  await deleteItem();
}
```

### Dangerous Actions

Use `isDangerous: true` for destructive confirmations (styled in red):

```dart
final confirmed = await Magic.confirm(
  title: 'Delete Account',
  message: 'This action cannot be undone.',
  confirmText: 'Delete Forever',
  isDangerous: true,
);
```

## Loading Overlay

Show a blocking loading overlay during async operations.

### Show Loading

```dart
Magic.loading();
// or with message
Magic.loading(message: 'Please wait...');
```

### Close Loading

```dart
Magic.closeLoading();
```

### Pattern: Wrap Async Operations

```dart
Future<void> submitForm() async {
  Magic.loading(message: 'Saving...');
  try {
    await api.save(data);
    Magic.success('Saved', 'Your changes have been saved');
  } catch (e) {
    Magic.error('Error', e.toString());
  } finally {
    Magic.closeLoading();
  }
}
```

## Toast

Show brief, non-intrusive messages (centered, pill-shaped):

```dart
Magic.toast('Item added to cart');

// Custom duration
Magic.toast('Copied!', duration: Duration(seconds: 1));
```

## Configuration

Customize appearance via `config/view.dart`:

```dart
'view': {
  // Snackbar
  'snackbar': {
    'duration': 4000,
    'style': {
      'success': 'bg-green-500 text-white p-4 rounded-lg',
      'error': 'bg-red-500 text-white p-4 rounded-lg',
      'info': 'bg-blue-500 text-white p-4 rounded-lg',
      'warning': 'bg-amber-500 text-white p-4 rounded-lg',
    },
  },
  
  // Dialog
  'dialog': {
    'class': 'bg-white rounded-xl p-6 shadow-2xl w-80 max-w-md',
  },
  
  // Confirm
  'confirm': {
    'container_class': 'bg-white rounded-xl p-6 shadow-2xl w-80',
    'title_class': 'text-lg font-bold text-gray-900',
    'message_class': 'text-gray-600 mt-2',
    'button_cancel_class': 'px-4 py-2 text-gray-600',
    'button_confirm_class': 'px-4 py-2 bg-blue-500 text-white rounded-lg',
    'button_danger_class': 'px-4 py-2 bg-red-500 text-white rounded-lg',
  },
  
  // Loading
  'loading': {
    'container_class': 'bg-white rounded-xl p-6 shadow-2xl',
    'spinner_class': 'text-blue-500',
    'text_class': 'text-gray-600 text-sm mt-4',
  },
  
  // Toast
  'toast': {
    'duration': 2000,
    'class': 'bg-gray-800 text-white px-6 py-3 rounded-full shadow-lg',
  },
}
```

## Custom Builders

Override default UI with custom builders in your `AppServiceProvider`:

```dart
@override
void boot() {
  MagicViewRegistry.instance.registerSnackbarBuilder((title, message, type) {
    return MyCustomSnackbar(title: title, message: message, type: type);
  });
  
  MagicViewRegistry.instance.registerLoadingBuilder((context, message) {
    return MyCustomLoadingWidget(message: message);
  });
}
```
