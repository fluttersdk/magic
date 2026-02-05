# File Storage

- [Introduction](#introduction)
- [Configuration](#configuration)
- [Storing Files](#storing-files)
- [Retrieving Files](#retrieving-files)
- [File URLs & Downloads](#file-urls-and-downloads)
- [Deleting Files](#deleting-files)
- [Multiple Disks](#multiple-disks)
- [MagicFile Reference](#magicfile-reference)

<a name="introduction"></a>
## Introduction

Magic provides a powerful filesystem abstraction thanks to the `Storage` facade. It provides a unified API for interacting with local filesystems across all platforms (iOS, Android, macOS, Windows, Web).

Key features:
- **Cross-Platform**: Same API on mobile, desktop, and web.
- **Disk System**: Configure multiple storage locations.
- **MagicFile Integration**: Seamless workflow with the Pick facade.

<a name="configuration"></a>
## Configuration

Configure storage disks in `lib/config/filesystems.dart`:

```dart
// lib/config/filesystems.dart
final Map<String, dynamic> filesystems = {
  'default': 'local',
  
  'disks': {
    'local': {
      'driver': 'local',
      'root': 'storage/app',
    },
    
    'public': {
      'driver': 'local',
      'root': 'storage/app/public',
    },
    
    'temp': {
      'driver': 'local',
      'root': 'storage/temp',
    },
  },
};
```

<a name="storing-files"></a>
## Storing Files

### From Bytes

```dart
await Storage.put('avatars/1.jpg', imageBytes);

// With MIME type (important for Web blob URLs)
await Storage.put('docs/resume.pdf', bytes, mimeType: 'application/pdf');
```

### From String

```dart
await Storage.put('logs/app.log', 'Log entry...');
```

### From MagicFile

The recommended way when using the Pick facade:

```dart
final file = await Pick.image();
if (file != null) {
  // Manual path
  await file.store('avatars/user.jpg');
  
  // Auto-generated timestamped name
  await file.storeAs('avatars');
  // Result: 'avatars/1704067200000_photo.jpg'
}
```

<a name="retrieving-files"></a>
## Retrieving Files

### As Bytes

```dart
final Uint8List? bytes = await Storage.get('avatars/1.jpg');
```

### As MagicFile

```dart
final MagicFile? file = await Storage.getFile('avatars/1.jpg');
if (file != null) {
  print(file.name);      // '1.jpg'
  print(file.size);      // 102400
  print(file.mimeType);  // 'image/jpeg'
  print(file.extension); // 'jpg'
}
```

### Check Existence

```dart
if (await Storage.exists('avatars/1.jpg')) {
  // File exists
}
```

<a name="file-urls-and-downloads"></a>
## File URLs & Downloads

### Display URLs

Get a URL for use in `Image.network()` or similar widgets:

```dart
final url = await Storage.url('avatars/1.jpg');
```

| Platform | URL Format |
|----------|------------|
| Mobile/Desktop | `file:///path/to/file.jpg` |
| Web | `blob:http://localhost/...` |

### Downloading

Trigger a file download (Web) or share sheet (Mobile):

```dart
await Storage.download('reports/2024.pdf', name: 'Annual Report.pdf');
```

<a name="deleting-files"></a>
## Deleting Files

```dart
await Storage.delete('avatars/1.jpg');
```

<a name="multiple-disks"></a>
## Multiple Disks

Switch between configured disks:

```dart
// Use the 'public' disk
await Storage.disk('public').put('file.txt', 'contents');

// Get from 'temp' disk
final bytes = await Storage.disk('temp').get('cache.dat');
```

<a name="magicfile-reference"></a>
## MagicFile Reference

`MagicFile` is the unified file wrapper used throughout Magic. It's returned by `Pick` methods and can be used with `Storage`.

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `path` | `String?` | Original file path (null on Web) |
| `name` | `String` | File name with extension |
| `size` | `int?` | File size in bytes |
| `mimeType` | `String?` | MIME type (e.g., 'image/jpeg') |
| `extension` | `String` | Extension without dot (e.g., 'jpg') |
| `isImage` | `bool` | True for jpg, png, gif, webp, etc. |
| `isVideo` | `bool` | True for mp4, mov, avi, etc. |

### Methods

#### readAsBytes()

Read file contents as `Uint8List`:

```dart
final bytes = await file.readAsBytes();
```

#### store(path, {disk})

Store to Magic Storage:

```dart
final storedPath = await file.store('uploads/photo.jpg');
// Returns: 'uploads/photo.jpg'
```

#### storeAs(directory, {disk})

Store with auto-generated unique name:

```dart
final storedPath = await file.storeAs('uploads');
// Returns: 'uploads/1704067200000_photo.jpg'
```

#### upload(url, {fieldName, data, headers})

Upload directly to server:

```dart
final response = await file.upload(
  '/api/upload',
  fieldName: 'avatar',
  data: {'user_id': 1},
);

if (response.successful) {
  print(response['url']);
}
```

### Creating MagicFile Manually

```dart
final file = MagicFile(
  name: 'document.pdf',
  size: 1024,
  mimeType: 'application/pdf',
  bytes: pdfBytes,
);
```
