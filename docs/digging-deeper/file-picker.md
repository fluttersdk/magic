# File Picker

## Introduction

The `Pick` facade provides a Laravel-style API for picking files and images. It wraps `image_picker` and `file_picker` packages with seamless integration into Storage and HTTP systems.

```dart
final image = await Pick.image();
if (image != null) {
  await image.store('avatars/user.jpg');
  // or
  await image.upload('/api/upload');
}
```

## Picking Images

### Single Image

```dart
final image = await Pick.image();

// With options
final image = await Pick.image(
  maxWidth: 800,
  maxHeight: 600,
  imageQuality: 80,
);
```

### Multiple Images

```dart
final images = await Pick.images();
for (final img in images) {
  await img.storeAs('gallery');
}
```

## Camera Capture

### Take Photo

```dart
final photo = await Pick.camera();

// Specify camera
final selfie = await Pick.camera(
  preferredCamera: CameraDevice.front,
  imageQuality: 90,
);
```

### Camera Fallback

```dart
// Automatic fallback to gallery if camera fails
final photo = await Pick.camera(
  fallbackToGallery: true,
);
```

## Picking Videos

```dart
final video = await Pick.video(
  maxDuration: Duration(minutes: 5),
);
```

## Picking Files

```dart
// Any file
final file = await Pick.file();

// With extension filter
final pdf = await Pick.file(extensions: ['pdf', 'doc', 'docx']);

// Multiple files
final files = await Pick.files(extensions: ['jpg', 'png']);
```

## Working with MagicFile

All pick methods return `MagicFile` objects:

```dart
final file = await Pick.image();

print(file.name);       // 'photo.jpg'
print(file.extension);  // 'jpg'
print(file.size);       // 1024 (bytes)
print(file.mimeType);   // 'image/jpeg'
print(file.isImage);    // true

final bytes = await file.readAsBytes();
```

## Storage Integration

```dart
// Store at specific path
await image!.store('avatars/profile.jpg');

// Store with auto-generated unique name
await image!.storeAs('photos');
// -> 'photos/1703836800000_IMG_001.jpg'
```

## HTTP Upload Integration

```dart
final response = await image!.upload(
  '/api/upload',
  fieldName: 'avatar',
  data: {'user_id': '123'},
);
```

## Platform Support

| Method | Android | iOS | Web | Desktop |
|--------|:-------:|:---:|:---:|:-------:|
| `image()` | ✅ | ✅ | ✅ | ✅ |
| `camera()` | ✅ | ✅ | ✅ | ⚠️ |
| `video()` | ✅ | ✅ | ✅ | ✅ |
| `file()` | ✅ | ✅ | ✅ | ✅ |
