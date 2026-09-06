# File Picker

The `Pick` facade provides a unified interface for accessing the device camera, media gallery, and file system, returning a consistent `MagicFile` object regardless of platform.

- [Introduction](#introduction)
- [Picking Images](#picking-images)
- [Picking Videos](#picking-videos)
- [Picking Files](#picking-files)
- [MagicFile Reference](#magicfile-reference)
    - [Properties](#properties)
    - [Methods](#methods)
- [Complete Examples](#complete-examples)
- [Upgrading to file_picker v12](#upgrading-to-file-picker-v12)

<a name="introduction"></a>
## Introduction

The `Pick` facade provides a Laravel-style interface for accessing the device's camera and file system. It handles platform-specific implementations and permissions, returning a unified `MagicFile` object.

**Underlying packages:**
- `image_picker` for images and camera
- `file_picker` for documents and directories

<a name="picking-images"></a>
## Picking Images

### From Gallery

```dart
// Single image
final MagicFile? image = await Pick.image(
  maxWidth: 1024,
  maxHeight: 1024,
  imageQuality: 85,  // 0-100
);

// Multiple images
final List<MagicFile> images = await Pick.images();
```

### From Camera

```dart
final MagicFile? photo = await Pick.camera(
  preferredCamera: CameraDevice.front,  // or .rear
  maxWidth: 800,
  imageQuality: 90,
  fallbackToGallery: true,  // If camera permission denied
  onError: (e) => print('Camera error: $e'),
);
```

<a name="picking-videos"></a>
## Picking Videos

### From Gallery

```dart
final MagicFile? video = await Pick.video(
  maxDuration: Duration(minutes: 5),
);
```

### Record New Video

```dart
final MagicFile? video = await Pick.recordVideo(
  maxDuration: Duration(seconds: 30),
  preferredCamera: CameraDevice.rear,
);
```

<a name="picking-files"></a>
## Picking Files

### Any File

```dart
final MagicFile? file = await Pick.file();
```

### Filtered by Extension

```dart
final MagicFile? pdf = await Pick.file(extensions: ['pdf']);
final MagicFile? doc = await Pick.file(extensions: ['doc', 'docx']);
```

### Multiple Files

```dart
final List<MagicFile> files = await Pick.files(
  extensions: ['jpg', 'png', 'pdf'],
);
```

### Directory (Mobile/Desktop)

```dart
final String? directoryPath = await Pick.directory();
```

### Saving a File

`Pick.saveFile()` opens the platform save dialog, writes the bytes you hand it, and returns the location it wrote to.

```dart
final Uri? savedTo = await Pick.saveFile(
  fileName: 'report.pdf',
  bytes: pdfBytes,
);
```

The return value is a `Uri` rather than a path because the scheme depends on where the platform put the file: `file` on desktop and iOS, `content` on Android's Storage Access Framework, `blob` on the web. Only a `file` uri can be turned back into a filesystem path.

```dart
if (savedTo != null && savedTo.scheme == 'file') {
  print(savedTo.toFilePath()); // '/Users/me/Documents/report.pdf'
}
```

The MIME type is derived from the file name's extension, so `report.pdf` is registered as `application/pdf`. Pass `mimeType` when the extension does not describe the content, and remember that Android and the browser both use this value to decide which app opens the file.

```dart
await Pick.saveFile(
  fileName: 'export.bin',
  bytes: exportBytes,
  mimeType: 'application/json',
);
```

<a name="magicfile-reference"></a>
## MagicFile Reference

All `Pick` methods return `MagicFile` (or `List<MagicFile>`). This class provides unified access to file data and convenient methods for storage and upload.

<a name="properties"></a>
### Properties

| Property | Type | Description |
|----------|------|-------------|
| `path` | `String?` | Original file path (null on Web, and on an Android pick the platform returned as a `content://` handle) |
| `name` | `String` | File name with extension (e.g., 'photo.jpg') |
| `size` | `int?` | File size in bytes. Filled for every picked file; null only for a `MagicFile` you constructed without one |
| `mimeType` | `String?` | MIME type (e.g., 'image/jpeg') |
| `extension` | `String` | Extension without dot (e.g., 'jpg') |
| `isImage` | `bool` | True for: jpg, jpeg, png, gif, webp, bmp, heic |
| `isVideo` | `bool` | True for: mp4, mov, avi, mkv, webm, m4v |

**Example:**

```dart
final file = await Pick.image();
if (file != null) {
  print(file.name);      // 'IMG_001.jpg'
  print(file.extension); // 'jpg'
  print(file.mimeType);  // 'image/jpeg'
  print(file.size);      // 245760
  print(file.isImage);   // true
  print(file.isVideo);   // false
}
```

<a name="methods"></a>
### Methods

#### readAsBytes()

Read file as byte array. Bytes are cached after first read.

```dart
final Uint8List? bytes = await file.readAsBytes();
```

#### store(path, {disk})

Save to [Magic Storage](./file-storage.md):

```dart
final storedPath = await file.store('avatars/profile.jpg');
// Returns: 'avatars/profile.jpg'

// To specific disk
await file.store('avatars/profile.jpg', disk: 'public');
```

#### storeAs(directory, {disk})

Save with auto-generated unique filename:

```dart
final storedPath = await file.storeAs('uploads');
// Returns: 'uploads/1704067200000_IMG_001.jpg'
```

#### upload(url, {fieldName, data, headers})

Upload to server via multipart form:

```dart
final response = await file.upload(
  '/api/upload',
  fieldName: 'document',  // Form field name (default: 'file')
  data: {
    'user_id': user.id,
    'category': 'profile',
  },
  headers: {
    'X-Custom-Header': 'value',
  },
);

if (response.successful) {
  final uploadedUrl = response['url'];
  Magic.success('Uploaded!', uploadedUrl);
} else {
  Magic.error('Upload failed', response['message']);
}
```

<a name="complete-examples"></a>
## Complete Examples

### Profile Picture Upload

```dart
Future<void> updateAvatar() async {
  final image = await Pick.image(maxWidth: 512, imageQuality: 80);
  if (image == null) return;
  
  Magic.loading(message: 'Uploading...');
  
  final response = await image.upload('/api/user/avatar');
  
  Magic.closeLoading();
  
  if (response.successful) {
    Magic.success('Success', 'Avatar updated!');
    user.avatarUrl = response['url'];
  } else {
    Magic.error('Error', response['message'] ?? 'Upload failed');
  }
}
```

### Document Picker with Local Storage

```dart
Future<void> saveDocument() async {
  final doc = await Pick.file(extensions: ['pdf', 'doc', 'docx']);
  if (doc == null) return;
  
  // Store locally
  final path = await doc.storeAs('documents');
  
  // Save reference
  await Document.create({
    'name': doc.name,
    'path': path,
    'size': doc.size,
    'mime_type': doc.mimeType,
  });
  
  Magic.success('Saved', doc.name);
}
```

### Gallery with Multiple Selection

```dart
Future<void> uploadGallery() async {
  final images = await Pick.images();
  if (images.isEmpty) return;
  
  Magic.loading(message: 'Uploading ${images.length} images...');
  
  for (final image in images) {
    await image.upload('/api/gallery', data: {
      'album_id': currentAlbum.id,
    });
  }
  
  Magic.closeLoading();
  Magic.success('Done', '${images.length} images uploaded');
}
```

<a name="upgrading-to-file-picker-v12"></a>
## Upgrading to file_picker v12

Magic uses `file_picker ^12.2.0`. v12 splits the plugin into federated platform packages and changes enough of the API that a single call site cannot compile against both majors, so magic targets v12 only. Most of that is absorbed by the `Pick` facade, but three things reach your code.

### Pick.saveFile returns a Uri

`Pick.saveFile()` used to return the chosen path as a `String?`. It now returns the `Uri?` the file was written to, because v12 can write to places that have no filesystem path: Android's Storage Access Framework hands back a `content://` handle, and the web hands back a `blob:` url.

**Before:**

```dart
final String? path = await Pick.saveFile(
  fileName: 'report.pdf',
  bytes: pdfBytes,
);
```

**After:**

```dart
final Uri? savedTo = await Pick.saveFile(
  fileName: 'report.pdf',
  bytes: pdfBytes,
);

if (savedTo != null && savedTo.scheme == 'file') {
  final String path = savedTo.toFilePath();
}
```

`fileName` and `bytes` are also `required` now. The previous signature accepted both as nullable and threw an `ArgumentError` when either was missing, so the failure moves from run time to compile time.

> [!NOTE]
> `Pick.directory()` still returns a `String?`. A directory pick is always a real path, so there is nothing for a `Uri` to carry there.

### withData is gone from Pick.file and Pick.files

v12 deprecated the parameter and stopped forwarding it to the platform. Bytes are read on demand instead:

```dart
final file = await Pick.file(extensions: ['pdf']);
final bytes = await file?.readAsBytes(); // reads once, then caches
```

Delete the argument from your call sites. Anything that reads bytes behaves the same; anything that only reads `name` or `size` now avoids pulling the file into memory at all.

### The barrel re-exports five file_picker names

v12 re-exports its platform interface, which declares `AndroidOptions`, `LinuxOptions`, `WebOptions` and `WindowsOptions`. Those names are already taken by `flutter_secure_storage`, which magic also re-exports, so `package:magic/magic.dart` now names what it re-exports: `FilePicker`, `FilePickerStatus`, `FileType`, `IllegalCharacterInFileNameException` and `PlatformFile`.

If you configure per-platform picker options, import the package directly:

```dart
import 'package:file_picker/file_picker.dart' as picker;

await picker.FilePicker.pickFile(
  androidOptions: const picker.AndroidOptions(),
);
```

### PlatformFile reads lazily

If you call `FilePicker` directly rather than through `Pick`, note that `PlatformFile` is now an abstract class with no `size` and no `bytes` fields. Use `length()`, `readAsBytes()` and `readAsByteStream()` instead.

> [!WARNING]
> Prefer `length()` over `lengthSync()`. The synchronous reading only answers when the native picker reported a size, and the Windows dialog and the Linux XDG portal return a path and nothing else, so it is null for every desktop pick. `length()` falls back to measuring the file.
