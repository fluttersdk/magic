# UI Helpers

- [Introduction](#introduction)
- [Snackbars](#snackbars)
    - [Typed Snackbars](#typed-snackbars)
- [Dialogs](#dialogs)
    - [Custom Dialogs](#custom-dialogs)
    - [Confirmation Dialogs](#confirmation-dialogs)
- [Loading Overlay](#loading-overlay)
- [Toast Messages](#toast-messages)
- [Configuration](#configuration)

<a name="introduction"></a>
## Introduction

Magic provides context-free UI feedback utilities through the `Magic` facade. Show snackbars, dialogs, confirmations, loading overlays, and toasts from **anywhere**—controllers, services, or callbacks—without passing `BuildContext`.

```dart
// No context needed!
Magic.success('Done', 'User created successfully');
Magic.confirm(title: 'Delete?', message: 'This cannot be undone');
Magic.loading();
```

This is a game-changer for Flutter developers. No more passing `context` down through your widget tree just to show a simple notification.

<a name="snackbars"></a>
## Snackbars

Show notification messages at the bottom of the screen.

### Basic Snackbar

```dart
Magic.snackbar('Title', 'Message');
```

<a name="typed-snackbars"></a>
### Typed Snackbars

Use typed helpers for semantic styling:

```dart
Magic.success('Success', 'Operation completed');  // Green
Magic.error('Error', 'Something went wrong');     // Red
Magic.info('Info', 'New update available');       // Blue
Magic.warning('Warning', 'Low storage space');    // Amber
```

### With Custom Duration

```dart
Magic.snackbar(
  'Custom',
  'Message',
  type: 'info',
  duration: Duration(seconds: 5),
);
```

<a name="dialogs"></a>
## Dialogs

<a name="custom-dialogs"></a>
### Custom Dialogs

Display any widget in a centered dialog:

```dart
Magic.dialog(
  WDiv(
    className: 'p-6 bg-white rounded-xl max-w-md',
    children: [
      WText('Custom Dialog', className: 'text-xl font-bold'),
      WText('Any content goes here.', className: 'text-gray-600 mt-2'),
      WDiv(
        className: 'flex justify-end gap-4 mt-6',
        children: [
          WButton(
            onTap: () => Magic.closeDialog(),
            className: 'px-4 py-2 text-gray-600',
            child: WText('Cancel'),
          ),
          WButton(
            onTap: () {
              // Handle action
              Magic.closeDialog();
            },
            className: 'px-4 py-2 bg-primary text-white rounded-lg',
            child: WText('Confirm'),
          ),
        ],
      ),
    ],
  ),
);
```

### Close Dialog

```dart
Magic.closeDialog();
```

<a name="confirmation-dialogs"></a>
### Confirmation Dialogs

Ask the user to confirm an action:

```dart
final confirmed = await Magic.confirm(
  title: 'Delete Item',
  message: 'Are you sure you want to delete this item?',
  confirmText: 'Delete',
  cancelText: 'Cancel',
);

if (confirmed == true) {
  await deleteItem();
}
```

### Dangerous Actions

Use `isDangerous: true` for destructive confirmations (styled in red):

```dart
final confirmed = await Magic.confirm(
  title: 'Delete Account',
  message: 'This action cannot be undone. All your data will be permanently removed.',
  confirmText: 'Delete Forever',
  isDangerous: true,
);

if (confirmed == true) {
  await deleteAccount();
  MagicRoute.to('/goodbye');
}
```

<a name="loading-overlay"></a>
## Loading Overlay

Show a blocking loading overlay during async operations.

### Show Loading

```dart
Magic.loading();

// With message
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

### Controller Pattern

```dart
class OrderController extends MagicController with MagicStateMixin<Order> {
  Future<void> placeOrder(Map<String, dynamic> data) async {
    Magic.loading(message: trans('orders.processing'));
    
    try {
      final response = await Http.post('/orders', data: data);
      
      if (response.successful) {
        setSuccess(Order.fromMap(response.body));
        Magic.success(
          trans('common.success'),
          trans('orders.placed'),
        );
        MagicRoute.to('/orders/${response['id']}');
      } else {
        Magic.error(trans('common.error'), response.errorMessage ?? '');
      }
    } finally {
      Magic.closeLoading();
    }
  }
}
```

<a name="toast-messages"></a>
## Toast Messages

Show brief, non-intrusive messages (centered, pill-shaped):

```dart
Magic.toast('Item added to cart');

// Custom duration
Magic.toast('Copied!', duration: Duration(seconds: 1));
```

Toasts are ideal for quick confirmations that don't require user interaction.

<a name="configuration"></a>
## Configuration

Customize appearance via `config/view.dart`:

```dart
Map<String, dynamic> get viewConfig => {
  'view': {
    // Snackbar styling
    'snackbar': {
      'duration': 4000,
      'style': {
        'success': 'bg-green-500 text-white p-4 rounded-lg',
        'error': 'bg-red-500 text-white p-4 rounded-lg',
        'info': 'bg-blue-500 text-white p-4 rounded-lg',
        'warning': 'bg-amber-500 text-white p-4 rounded-lg',
      },
    },
    
    // Dialog container
    'dialog': {
      'class': 'bg-white rounded-xl p-6 shadow-2xl w-80 max-w-md',
    },
    
    // Confirmation dialog
    'confirm': {
      'container_class': 'bg-white rounded-xl p-6 shadow-2xl w-80',
      'title_class': 'text-lg font-bold text-gray-900',
      'message_class': 'text-gray-600 mt-2',
      'button_cancel_class': 'px-4 py-2 text-gray-600',
      'button_confirm_class': 'px-4 py-2 bg-primary text-white rounded-lg',
      'button_danger_class': 'px-4 py-2 bg-red-500 text-white rounded-lg',
    },
    
    // Loading overlay
    'loading': {
      'container_class': 'bg-white rounded-xl p-6 shadow-2xl',
      'spinner_class': 'text-primary',
      'text_class': 'text-gray-600 text-sm mt-4',
    },
    
    // Toast
    'toast': {
      'duration': 2000,
      'class': 'bg-gray-800 text-white px-6 py-3 rounded-full shadow-lg',
    },
  },
};
```

> [!TIP]
> Use Wind UI utility classes in your config for consistent styling across all UI helpers.
