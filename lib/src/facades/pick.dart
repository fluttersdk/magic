import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../storage/magic_file.dart';

/// The Pick Facade.
///
/// A Laravel-style facade for file and image picking that integrates
/// seamlessly with the Magic Storage system.
///
/// ## Quick Start
///
/// ```dart
/// // Pick an image from gallery
/// final image = await Pick.image();
/// if (image != null) {
///   await image.store('avatars/user.jpg');
/// }
///
/// // Capture from camera
/// final photo = await Pick.camera();
///
/// // Pick any file
/// final file = await Pick.file(extensions: ['pdf', 'doc']);
/// ```
///
/// ## Platform Support
///
/// | Method | Android | iOS | Web | Desktop |
/// |--------|---------|-----|-----|---------|
/// | `image()` | ✅ | ✅ | ✅ | ✅ |
/// | `images()` | ✅ | ✅ | ✅ | ✅ |
/// | `camera()` | ✅ | ✅ | ✅ | ⚠️ |
/// | `video()` | ✅ | ✅ | ✅ | ✅ |
/// | `file()` | ✅ | ✅ | ✅ | ✅ |
/// | `files()` | ✅ | ✅ | ✅ | ✅ |
/// | `directory()` | ✅ | ✅ | ❌ | ✅ |
///
/// ⚠️ Desktop camera requires custom delegate setup.
class Pick {
  /// The image picker instance.
  static final ImagePicker _imagePicker = ImagePicker();

  // ---------------------------------------------------------------------------
  // Image Picking
  // ---------------------------------------------------------------------------

  /// Pick a single image from the gallery.
  ///
  /// **Parameters:**
  /// - [maxWidth]: Maximum width of the picked image.
  /// - [maxHeight]: Maximum height of the picked image.
  /// - [imageQuality]: Quality of the picked image (0-100).
  ///
  /// **Returns:** A `MagicFile` or `null` if cancelled.
  ///
  /// ```dart
  /// final image = await Pick.image(maxWidth: 800, imageQuality: 80);
  /// if (image != null) {
  ///   await image.store('photos/profile.jpg');
  /// }
  /// ```
  static Future<MagicFile?> image({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    final xFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );

    return xFile != null ? _xFileToMagicFile(xFile) : null;
  }

  /// Pick multiple images from the gallery.
  ///
  /// **Returns:** A list of `MagicFile` (empty if cancelled).
  ///
  /// ```dart
  /// final images = await Pick.images();
  /// for (final img in images) {
  ///   await img.storeAs('gallery');
  /// }
  /// ```
  static Future<List<MagicFile>> images({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    final xFiles = await _imagePicker.pickMultiImage(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );

    return xFiles.map(_xFileToMagicFile).toList();
  }

  /// Capture a photo using the camera.
  ///
  /// **Parameters:**
  /// - [preferredCamera]: Front or back camera.
  /// - [maxWidth]: Maximum width of the captured photo.
  /// - [maxHeight]: Maximum height of the captured photo.
  /// - [imageQuality]: Quality of the captured image (0-100).
  /// - [fallbackToGallery]: If true, falls back to gallery picker when camera
  ///   fails or is unavailable. Default: false.
  /// - [onError]: Callback invoked when camera fails. Receives the exception.
  ///   If [fallbackToGallery] is true, this is called before falling back.
  ///
  /// **Returns:** A `MagicFile` or `null` if cancelled.
  ///
  /// ```dart
  /// // Basic usage
  /// final photo = await Pick.camera(preferredCamera: CameraDevice.front);
  ///
  /// // With gallery fallback (e.g., when camera permission denied)
  /// final photo = await Pick.camera(
  ///   fallbackToGallery: true,
  ///   onError: (e) => print('Camera failed: $e, falling back to gallery'),
  /// );
  ///
  /// // Handle errors without fallback
  /// final photo = await Pick.camera(
  ///   onError: (e) => showSnackbar('Camera unavailable: $e'),
  /// );
  /// ```
  static Future<MagicFile?> camera({
    CameraDevice preferredCamera = CameraDevice.rear,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    bool fallbackToGallery = false,
    void Function(Object error)? onError,
  }) async {
    try {
      final xFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: preferredCamera,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );

      // User cancelled camera - check if we should fallback
      if (xFile == null && fallbackToGallery) {
        // Awaited, not just returned: an un-awaited future escapes this try
        // block, so a failure inside the gallery fallback would never reach the
        // `catch` below and `onError` would never fire.
        return await image(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          imageQuality: imageQuality,
        );
      }

      return xFile != null ? _xFileToMagicFile(xFile) : null;
    } catch (e) {
      // Call error callback if provided
      onError?.call(e);

      // Fallback to gallery if enabled
      if (fallbackToGallery) {
        return image(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          imageQuality: imageQuality,
        );
      }

      // Re-throw if not handling
      if (onError == null) {
        rethrow;
      }

      return null;
    }
  }

  /// Pick a single image or video from the gallery.
  ///
  /// Allows the user to select either an image or video.
  ///
  /// ```dart
  /// final media = await Pick.media();
  /// print(media?.isVideo); // true or false
  /// ```
  static Future<MagicFile?> media({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    final xFile = await _imagePicker.pickMedia(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );

    return xFile != null ? _xFileToMagicFile(xFile) : null;
  }

  // ---------------------------------------------------------------------------
  // Video Picking
  // ---------------------------------------------------------------------------

  /// Pick a video from the gallery.
  ///
  /// **Parameters:**
  /// - [maxDuration]: Maximum duration of the video.
  ///
  /// ```dart
  /// final video = await Pick.video(maxDuration: Duration(seconds: 30));
  /// await video?.store('videos/clip.mp4');
  /// ```
  static Future<MagicFile?> video({Duration? maxDuration}) async {
    final xFile = await _imagePicker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: maxDuration,
    );

    return xFile != null ? _xFileToMagicFile(xFile) : null;
  }

  /// Record a video using the camera.
  ///
  /// **Parameters:**
  /// - [preferredCamera]: Front or back camera.
  /// - [maxDuration]: Maximum duration of the video.
  /// - [fallbackToGallery]: If true, falls back to gallery picker when camera
  ///   fails or is unavailable. Default: false.
  /// - [onError]: Callback invoked when camera fails.
  ///
  /// ```dart
  /// // Basic usage
  /// final recording = await Pick.recordVideo(maxDuration: Duration(minutes: 1));
  ///
  /// // With gallery fallback
  /// final video = await Pick.recordVideo(
  ///   fallbackToGallery: true,
  ///   onError: (e) => print('Camera failed: $e'),
  /// );
  /// ```
  static Future<MagicFile?> recordVideo({
    CameraDevice preferredCamera = CameraDevice.rear,
    Duration? maxDuration,
    bool fallbackToGallery = false,
    void Function(Object error)? onError,
  }) async {
    try {
      final xFile = await _imagePicker.pickVideo(
        source: ImageSource.camera,
        preferredCameraDevice: preferredCamera,
        maxDuration: maxDuration,
      );

      // User cancelled - check if we should fallback
      if (xFile == null && fallbackToGallery) {
        // Awaited for the same reason as the image fallback above.
        return await video(maxDuration: maxDuration);
      }

      return xFile != null ? _xFileToMagicFile(xFile) : null;
    } catch (e) {
      onError?.call(e);

      if (fallbackToGallery) {
        return video(maxDuration: maxDuration);
      }

      if (onError == null) {
        rethrow;
      }

      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // File Picking
  // ---------------------------------------------------------------------------

  /// Pick a single file with optional extension filtering.
  ///
  /// Bytes are read on demand through [MagicFile.readAsBytes] rather than
  /// eagerly at pick time, so a large selection costs nothing until it is
  /// stored or uploaded.
  ///
  /// **Parameters:**
  /// - [extensions]: List of allowed extensions (without dot).
  ///
  /// ```dart
  /// final pdf = await Pick.file(extensions: ['pdf']);
  /// await pdf?.store('documents/report.pdf');
  /// ```
  static Future<MagicFile?> file({List<String>? extensions}) async {
    final file = await FilePicker.pickFile(
      type: extensions != null ? FileType.custom : FileType.any,
      allowedExtensions: extensions,
    );

    return file != null ? await _platformFileToMagicFile(file) : null;
  }

  /// Pick multiple files with optional extension filtering.
  ///
  /// Returns an empty list when the user cancels.
  ///
  /// ```dart
  /// final docs = await Pick.files(extensions: ['pdf', 'doc', 'docx']);
  /// for (final doc in docs) {
  ///   await doc.storeAs('uploads');
  /// }
  /// ```
  static Future<List<MagicFile>> files({List<String>? extensions}) async {
    final files = await FilePicker.pickFiles(
      type: extensions != null ? FileType.custom : FileType.any,
      allowedExtensions: extensions,
    );

    return Future.wait(files.map(_platformFileToMagicFile));
  }

  /// Pick a directory.
  ///
  /// **Note:** Not supported on Web.
  ///
  /// ```dart
  /// final path = await Pick.directory();
  /// if (path != null) {
  ///   print('Selected: $path');
  /// }
  /// ```
  static Future<String?> directory() async {
    return FilePicker.getDirectoryPath();
  }

  /// Open a save file dialog.
  ///
  /// Returns the [Uri] the file was written to, or null if cancelled. The
  /// scheme is platform-dependent: `file` on desktop and iOS, `content` on
  /// Android SAF, `blob` on the web. Read [Uri.toFilePath] only after checking
  /// for a `file` scheme.
  ///
  /// **Parameters:**
  /// - [fileName]: File name to save as, extension included.
  /// - [bytes]: Bytes to write to the file.
  /// - [mimeType]: Content type to register the file under. Derived from
  ///   [fileName]'s extension when omitted, falling back to
  ///   `application/octet-stream`. Android SAF and the web browser both key
  ///   the file association off this value.
  /// - [dialogTitle]: Title of the save dialog.
  ///
  /// ```dart
  /// final savedTo = await Pick.saveFile(
  ///   fileName: 'report.pdf',
  ///   bytes: pdfBytes,
  /// );
  /// ```
  static Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
    String? dialogTitle,
  }) {
    return FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      bytes: bytes,
      mimeType:
          mimeType ?? _getMimeType(fileName) ?? 'application/octet-stream',
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Convert XFile (from image_picker) to MagicFile.
  static MagicFile _xFileToMagicFile(XFile xFile) {
    return MagicFile(
      path: xFile.path,
      name: xFile.name,
      mimeType: xFile.mimeType,
      bytesReader: () => xFile.readAsBytes(),
    );
  }

  /// Convert PlatformFile (from file_picker) to MagicFile.
  ///
  /// Size comes from [PlatformFile.length] rather than [PlatformFile.lengthSync]
  /// because the Windows and Linux pickers return a path and no size, so the
  /// synchronous reading is null for every desktop pick. `length()` returns the
  /// size the picker reported when there is one (web and Android always report
  /// it) and stats the file when there is not, so it costs I/O only where the
  /// alternative was no answer at all.
  ///
  /// Every shipped `length()` implementation returns 0 when that stat throws,
  /// so a file removed or made unreadable between the pick and this call maps
  /// to a size of 0 rather than to null. Callers guarding an upload limit read
  /// 0 as "well under it"; see the same warning on [MagicFile.size].
  static Future<MagicFile> _platformFileToMagicFile(PlatformFile file) async {
    return MagicFile(
      path: file.path,
      name: file.name,
      size: await file.length(),
      mimeType: _getMimeType(file.name),
      bytesReader: file.readAsBytes,
    );
  }

  /// Get the MIME type for [fileName], or null when its extension is missing
  /// or unknown to the table below.
  static String? _getMimeType(String fileName) {
    final extension = p.extension(fileName);
    if (extension.isEmpty) return null;

    const mimeTypes = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'bmp': 'image/bmp',
      'heic': 'image/heic',
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'avi': 'video/x-msvideo',
      'mkv': 'video/x-matroska',
      'webm': 'video/webm',
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt': 'application/vnd.ms-powerpoint',
      'pptx':
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'txt': 'text/plain',
      'json': 'application/json',
      'xml': 'application/xml',
      'zip': 'application/zip',
      'rar': 'application/vnd.rar',
    };

    return mimeTypes[extension.substring(1).toLowerCase()];
  }
}
