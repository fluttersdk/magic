/// Default Filesystems Configuration.
///
/// This configuration defines the available storage disks and their drivers.
/// Similar to Laravel's `config/filesystems.php`.
///
/// ## Usage
///
/// ```dart
/// // Use the default disk
/// await Storage.put('avatars/user.jpg', bytes);
///
/// // Use a specific disk
/// await Storage.disk('public').put('uploads/file.pdf', bytes);
/// ```
Map<String, dynamic> defaultFilesystemsConfig = {
  'filesystems': {
    /// The default disk to use when no disk is specified.
    'default': 'local',

    /// Available storage disks.
    'disks': {
      /// Local disk - stores files in the app's documents directory.
      'local': {
        'driver': 'local',
        'root': 'storage', // Subfolder in AppDocsDir
      },
    },
  },
};
