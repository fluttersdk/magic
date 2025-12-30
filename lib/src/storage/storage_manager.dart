import '../facades/config.dart';
import 'contracts/storage_disk.dart';
import 'drivers/local_disk.dart';

/// The Storage Manager.
///
/// This service manages storage disks and provides access to them based
/// on configuration. It acts as a factory for disk instances.
///
/// ## Usage
///
/// ```dart
/// final manager = StorageManager();
///
/// // Get the default disk
/// final disk = manager.disk();
///
/// // Get a specific disk
/// final publicDisk = manager.disk('public');
/// ```
class StorageManager {
  /// Cached disk instances.
  final Map<String, StorageDisk> _disks = {};

  /// Get a storage disk by name.
  ///
  /// If [name] is null, returns the default disk from configuration.
  StorageDisk disk([String? name]) {
    final diskName = name ?? _getDefaultDisk();

    // Return cached instance if available
    if (_disks.containsKey(diskName)) {
      return _disks[diskName]!;
    }

    // Create and cache the disk
    final disk = _createDisk(diskName);
    _disks[diskName] = disk;
    return disk;
  }

  /// Get the default disk name from configuration.
  String _getDefaultDisk() {
    return Config.get('filesystems.default', 'local') ?? 'local';
  }

  /// Create a disk instance based on configuration.
  StorageDisk _createDisk(String name) {
    final diskConfig = Config.get('filesystems.disks.$name');

    if (diskConfig == null) {
      throw Exception('Storage disk [$name] not found in configuration.');
    }

    final driver = diskConfig['driver'] as String?;
    final root = diskConfig['root'] as String? ?? name;

    switch (driver) {
      case 'local':
        return LocalDisk(root: root);

      // Future drivers can be added here
      // case 's3':
      //   return S3Disk(config: diskConfig);

      default:
        throw Exception('Unsupported storage driver: $driver');
    }
  }

  /// Clear all cached disk instances.
  void flush() {
    _disks.clear();
  }
}
