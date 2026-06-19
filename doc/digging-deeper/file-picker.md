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
- [Upgrading to file_picker v11](#upgrading-to-file-picker-v11)

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

<a name="magicfile-reference"></a>
## MagicFile Reference

All `Pick` methods return `MagicFile` (or `List<MagicFile>`). This class provides unified access to file data and convenient methods for storage and upload.

<a name="properties"></a>
### Properties

| Property | Type | Description |
|----------|------|-------------|
| `path` | `String?` | Original file path (null on Web) |
| `name` | `String` | File name with extension (e.g., 'photo.jpg') |
| `size` | `int?` | File size in bytes |
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

<a name="upgrading-to-file-picker-v11"></a>
## Upgrading to file_picker v11

Magic uses `file_picker ^11.0.2`. If you are migrating a project that pinned an older version, this section describes the breaking changes.

### Static API (breaking change)

`file_picker` v11 removed the `FilePicker.platform` instance accessor. All methods are now called directly on the `FilePicker` class as static methods.

**Before (v10 and earlier):**

```dart
// Old pattern, no longer compiles in v11
final result = await FilePicker.platform.pickFiles();
final path = await FilePicker.platform.getDirectoryPath();
```

**After (v11):**

```dart
// New static API
final result = await FilePicker.pickFiles();
final path = await FilePicker.getDirectoryPath();
```

The `Pick` facade wraps `file_picker` entirely behind its own static methods, so if you use `Pick.file()`, `Pick.files()`, `Pick.directory()`, and `Pick.saveFile()` exclusively, this change is transparent and requires no action on your part.

If your code calls `FilePicker.platform` directly (bypassing the `Pick` facade), you must remove `.platform` from every call site.

### Android path traversal security fix (CWE-22)

`file_picker` v11.0.2 patches a path traversal vulnerability (CWE-22) on Android. The vulnerability allowed a malicious file name returned by a document provider to traverse outside the intended directory. Upgrading ensures returned file paths are sanitized before they reach your application code.

No API changes are required on your side to benefit from this fix.

### WASM web support

`file_picker` v11 adds support for Flutter Web compiled to WebAssembly (WASM). If you target `flutter build web --wasm`, file picking now works in that build mode without additional configuration.
