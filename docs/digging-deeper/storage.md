# Storage

## Introduction

Magic provides a powerful file storage abstraction with a unified API that works seamlessly across Mobile, Desktop, and Web platforms. The `Storage` facade provides a clean, Laravel-style interface for file operations.

## Configuration

### Create Filesystems Config

```dart
// lib/config/filesystems.dart
Map<String, dynamic> get filesystemsConfig => {
  'filesystems': {
    'default': 'local',
    'disks': {
      'local': {
        'driver': 'local',
        'root': 'app_storage',
      },
      'public': {
        'driver': 'local',
        'root': 'public',
      },
    },
  },
};
```

## Storing Files

### Store Bytes

```dart
await Storage.put('avatars/user.jpg', bytes, mimeType: 'image/jpeg');
await Storage.put('notes/readme.txt', 'Hello World');
```

### Store MagicFile

```dart
final image = await Pick.image();
await Storage.put('photos/vacation.jpg', image);

// Or use MagicFile directly
await image!.store('photos/vacation.jpg');

// Auto-generate unique filename
await image!.storeAs('photos'); // -> 'photos/1703836800000_image.jpg'
```

### Store to Specific Disk

```dart
await Storage.disk('public').put('uploads/file.pdf', bytes);
```

## Retrieving Files

### Get as Bytes

```dart
final bytes = await Storage.get('avatars/user.jpg');
```

### Get as MagicFile

```dart
final file = await Storage.getFile('avatars/user.jpg');
if (file != null) {
  print(file.name);       // 'user.jpg'
  print(file.extension);  // 'jpg'
  print(file.isImage);    // true
}
```

### Check Existence

```dart
if (await Storage.exists('avatars/user.jpg')) {
  print('Avatar exists!');
}
```

## File URLs

Get a displayable URL for files:

```dart
final url = await Storage.url('avatars/user.jpg');
Image.network(url);
```

| Platform | URL Format |
|----------|------------|
| Mobile/Desktop | `file:///path/to/file.jpg` |
| Web | `blob:http://localhost/uuid` |

## Downloading Files

```dart
await Storage.download('reports/monthly.pdf', name: 'report.pdf');
```

| Platform | Behavior |
|----------|----------|
| Mobile | Opens share sheet |
| Web | Triggers browser download dialog |

## Deleting Files

```dart
final deleted = await Storage.delete('avatars/old.jpg');
```

## Using Multiple Disks

```dart
await Storage.disk('local').put('settings.json', data);
await Storage.disk('public').put('images/logo.png', bytes);
```
