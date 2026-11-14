import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

/// Marks a directory so the platform backup leaves it out.
///
/// The seam `LocalAdapter` takes, so a test can count or fail the mark.
/// A marker throws when the platform refuses the mark.
typedef BackupExclusionMarker = void Function(String directoryPath);

/// Sets `kCFURLIsExcludedFromBackupKey` on [directoryPath] on iOS and macOS,
/// keeping it out of iCloud and Time Machine backup. A no-op elsewhere.
///
/// Throws a [FileSystemException] when CoreFoundation refuses the mark, for
/// example when the directory does not exist.
void markExcludedFromBackup(String directoryPath) {
  if (!Platform.isIOS && !Platform.isMacOS) {
    return;
  }

  _CoreFoundation.instance.excludeFromBackup(directoryPath);
}

typedef _CreateUrlNative = Pointer<Void> Function(
  Pointer<Void>,
  Pointer<Uint8>,
  Long,
  Uint8,
);
typedef _CreateUrl = Pointer<Void> Function(
  Pointer<Void>,
  Pointer<Uint8>,
  int,
  int,
);

typedef _SetPropertyNative = Uint8 Function(
  Pointer<Void>,
  Pointer<Void>,
  Pointer<Void>,
  Pointer<Pointer<Void>>,
);
typedef _SetProperty = int Function(
  Pointer<Void>,
  Pointer<Void>,
  Pointer<Void>,
  Pointer<Pointer<Void>>,
);

typedef _ErrorGetCodeNative = Long Function(Pointer<Void>);
typedef _ErrorGetCode = int Function(Pointer<Void>);

typedef _ReleaseNative = Void Function(Pointer<Void>);
typedef _Release = void Function(Pointer<Void>);

typedef _MallocNative = Pointer<Void> Function(Size);
typedef _Malloc = Pointer<Void> Function(int);

typedef _FreeNative = Void Function(Pointer<Void>);
typedef _Free = void Function(Pointer<Void>);

/// The CoreFoundation and libc symbols the mark needs, resolved once from
/// the running process. magic carries no `package:ffi`, so native buffers
/// come from libc `malloc` and `free`.
class _CoreFoundation {
  _CoreFoundation._(DynamicLibrary library)
    : _createUrl = library.lookupFunction<_CreateUrlNative, _CreateUrl>(
        'CFURLCreateFromFileSystemRepresentation',
      ),
      _setProperty = library.lookupFunction<_SetPropertyNative, _SetProperty>(
        'CFURLSetResourcePropertyForKey',
      ),
      _errorGetCode = library
          .lookupFunction<_ErrorGetCodeNative, _ErrorGetCode>('CFErrorGetCode'),
      _release = library.lookupFunction<_ReleaseNative, _Release>('CFRelease'),
      _malloc = library.lookupFunction<_MallocNative, _Malloc>('malloc'),
      _free = library.lookupFunction<_FreeNative, _Free>('free'),
      // Both symbols are `const CFTypeRef` globals: the lookup yields the
      // address of the variable, so read it to get the object itself.
      _excludedFromBackupKey = library
          .lookup<Pointer<Void>>('kCFURLIsExcludedFromBackupKey')
          .value,
      _booleanTrue = library.lookup<Pointer<Void>>('kCFBooleanTrue').value;

  static final _CoreFoundation instance = _CoreFoundation._(
    DynamicLibrary.process(),
  );

  final _CreateUrl _createUrl;
  final _SetProperty _setProperty;
  final _ErrorGetCode _errorGetCode;
  final _Release _release;
  final _Malloc _malloc;
  final _Free _free;
  final Pointer<Void> _excludedFromBackupKey;
  final Pointer<Void> _booleanTrue;

  void excludeFromBackup(String directoryPath) {
    final Uint8List path = utf8.encode(directoryPath);
    final Pointer<Uint8> buffer = _malloc(path.length).cast<Uint8>();
    final Pointer<Pointer<Void>> error = _malloc(sizeOf<Pointer<Void>>())
        .cast<Pointer<Void>>();
    Pointer<Void> url = nullptr;

    try {
      // 1. Hand CoreFoundation the UTF-8 file system representation.
      buffer.asTypedList(path.length).setAll(0, path);
      error.value = nullptr;
      url = _createUrl(nullptr, buffer, path.length, 1);

      if (url == nullptr) {
        throw FileSystemException(
          'Could not build a file URL to exclude from backup',
          directoryPath,
        );
      }

      // 2. Set the flag, and surface a refusal rather than trusting it.
      final int marked = _setProperty(
        url,
        _excludedFromBackupKey,
        _booleanTrue,
        error,
      );

      if (marked == 0) {
        final String code = error.value == nullptr
            ? 'unknown'
            : '${_errorGetCode(error.value)}';

        throw FileSystemException(
          'Could not exclude the directory from backup (CFError $code)',
          directoryPath,
        );
      }
    } finally {
      // 3. Release what Create and the error out-parameter handed back.
      if (url != nullptr) {
        _release(url);
      }
      if (error.value != nullptr) {
        _release(error.value);
      }
      _free(error.cast<Void>());
      _free(buffer.cast<Void>());
    }
  }
}
