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

      /// Copies of network images, read by `MagicImage`. Everything in it can
      /// be fetched again, so it stays out of the device backup.
      ///
      /// `Magic.init` does not merge this map by itself: an app that passes
      /// its own `filesystems` config declares this disk there, or builds its
      /// config from this map.
      'images': {
        'driver': 'local',
        'root': 'images',
        'exclude_from_backup': true,
      },
    },
  },
};
