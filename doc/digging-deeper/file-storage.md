# File Storage

The `Storage` facade provides a unified API for reading, writing, and deleting files across multiple named disks, with built-in support for remote downloads and URL generation.

- [Introduction](#introduction)
- [Configuration](#configuration)
- [Storing Files](#storing-files)
- [Retrieving Files](#retrieving-files)
- [File URLs & Downloads](#file-urls-and-downloads)
- [Deleting Files](#deleting-files)
- [Cached Network Images](#cached-network-images)
- [Multiple Disks](#multiple-disks)
- [MagicFile Reference](#magicfile-reference)
- [Testing](#testing)

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

    'downloads': {
      'driver': 'local',
      'root': 'downloads',
      'exclude_from_backup': true,
    },
  },
};
```

A local disk writes under the app's documents directory, which iOS backs up to iCloud and macOS to Time Machine. Set `exclude_from_backup` to `true` on a disk holding large files the app can fetch again, such as downloaded media. On iOS and macOS the disk's root directory is then marked with `kCFURLIsExcludedFromBackupKey` the first time the disk resolves a path, and everything stored under it is left out of the backup. If the platform refuses the mark, that first call throws a `FileSystemException` and the next one tries again. The key defaults to `false` and has no effect on Android, Windows, Linux or the web.

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

<a name="cached-network-images"></a>
## Cached Network Images

`MagicImage` draws a network image from a copy kept on the device. The first draw of an address fetches it and stores the bytes; every draw after that, in this launch or a later one, reads the file and makes no request. Flutter's own `NetworkImage` keeps images in memory only, so a poster grid asks the host again on every launch.

The copies live on a local disk named `images`. Declare it in your `filesystems` config (`defaultFilesystemsConfig` carries the entry, but `Magic.init` does not merge that map by itself, so spread it or copy it), and keep it out of backup, since every file in it can be fetched again:

```dart
'images': {
  'driver': 'local',
  'root': 'images',
  'exclude_from_backup': true,
},
```

Draw through `MagicImage.of`, which answers an `ImageProvider` or `null` when there is no address:

```dart
final ImageProvider? poster = MagicImage.of(item.posterUrl, cacheWidth: 300);

if (poster != null) Image(image: poster);
```

### A Stand-In Address

An item often has two pictures: one a third party sent with a listing, and a better one from your own server once it knows the item. Pass the better one as the address and the other as `fallback`:

```dart
MagicImage.of(item.catalogueUrl, fallback: item.listedUrl);
```

The fallback draws at once when it is already on the device and the address is not; the address replaces it when it lands. When the address cannot be fetched, the fallback is fetched instead and stays, and the next resolve after `retryAfter` (five minutes) asks the address again.

### Size, Failures and Cleaning Up

- **Size.** The folder is capped at 300 MiB. It is trimmed, least recently used first, on the first use of each launch and again after a quarter of the cap has been written. Pass `maxBytes` to a `MagicImageCache` of your own to change the cap.
- **Failures.** A URL that failed is not asked again for `retryAfter`, so a grid scrolled past a dead picture does not hit the host on every frame. A body that is not a JPEG, PNG, GIF or WebP, or is larger than 8 MiB, is refused. An error message never carries the address.
- **Decoding.** `cacheWidth` decodes no wider than that many pixels and never scales up. Only the first frame of an animated GIF is drawn.
- **A full disk.** An image the disk will not keep is still drawn, from memory, and the host is not blamed: `MagicImageCache.file` throws a `MagicImageNotStored` that carries the bytes.
- **A disk that is not there.** When the disk is not declared, is not a local disk, or the platform gives no folder for it, images are drawn as `NetworkImage` would draw them, with no copy kept. One warning is logged, and the disk is opened again on the next call.
- **Cleaning up.** `await MagicImageCache.instance.clear()` removes every stored image and keeps the folder, for a sign-out or a "clear cache" action. It exists on the web too, as a no-op.
- **Another disk.** `MagicImageCache(disk: 'pictures')` keeps the files on another local disk. Assign it to `MagicImageCache.instance` before the first draw.
- **Web.** There is no file store in a browser, so `MagicImage.of` answers a plain `NetworkImage` and the stand-in is not drawn.

In a test, assign `MagicImageCache.instance` a cache built with a `store` over a temporary folder and a `fetch` that answers bytes, and restore the previous one in `tearDown`.

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

<a name="testing"></a>
## Testing

### Replacing the manager

Inject a custom `StorageManager` subclass with `Storage.setManager()` to control disk behavior in tests:

```dart
class FakeStorageManager extends StorageManager {
  // Override disk() to return a test double
}

setUp(() {
  Storage.setManager(FakeStorageManager());
});
```

### Resetting state between tests

Call `Storage.flush()` to clear the cached manager and all cached disk instances. This ensures no state leaks between tests:

```dart
tearDown(() {
  Storage.flush();
});
```

`flush()` sets the internal manager to `null` and calls `flush()` on it first (clearing any cached disk instances), so the next call to any `Storage` method initialises a fresh manager from config.
