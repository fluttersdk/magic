import '../../../support/carbon.dart';
import '../model.dart';

/// The Timestamps Concern.
///
/// This mixin provides automatic timestamp management for models. When applied,
/// it will set `created_at` on new records and update `updated_at` on every save.
///
/// ## Usage
///
/// ```dart
/// class User extends Model with HasTimestamps, InteractsWithPersistence {
///   @override String get table => 'users';
///   @override String get resource => 'users';
/// }
///
/// // Timestamps are set automatically on save
/// final user = User()..fill({'name': 'John'});
/// await user.save();
/// print(user.createdAt.diffForHumans()); // "a few seconds ago"
/// ```
///
/// ## Disabling Timestamps
///
/// Override [timestamps] to disable automatic timestamp:
///
/// ```dart
/// class Log extends Model with HasTimestamps {
///   @override bool get timestamps => false;
/// }
/// ```
///
/// ## Custom Column Names
///
/// Override [createdAtColumn] or [updatedAtColumn] to use different columns:
///
/// ```dart
/// class Post extends Model with HasTimestamps {
///   @override String get createdAtColumn => 'date_created';
///   @override String get updatedAtColumn => 'date_modified';
/// }
/// ```
mixin HasTimestamps on Model {
  /// Indicates if the model should be timestamped.
  bool get timestamps => true;

  /// The name of the "created at" column.
  String get createdAtColumn => 'created_at';

  /// The name of the "updated at" column.
  String get updatedAtColumn => 'updated_at';

  /// Get the created_at timestamp.
  ///
  /// Returns a [Carbon] instance for easy date manipulation.
  ///
  /// ```dart
  /// print(user.createdAt.diffForHumans()); // "2 hours ago"
  /// print(user.createdAt.format('MMMM do, yyyy')); // "December 28th, 2024"
  /// ```
  Carbon? get createdAt {
    final value = getAttribute(createdAtColumn);
    if (value == null) return null;
    if (value is Carbon) return value;
    if (value is DateTime) return Carbon.fromDateTime(value);
    if (value is String) return Carbon.parse(value);
    return null;
  }

  /// Get the updated_at timestamp.
  ///
  /// Returns a [Carbon] instance for easy date manipulation.
  ///
  /// ```dart
  /// print(user.updatedAt.diffForHumans()); // "a few seconds ago"
  /// ```
  Carbon? get updatedAt {
    final value = getAttribute(updatedAtColumn);
    if (value == null) return null;
    if (value is Carbon) return value;
    if (value is DateTime) return Carbon.fromDateTime(value);
    if (value is String) return Carbon.parse(value);
    return null;
  }

  /// Set the created_at timestamp.
  set createdAt(dynamic value) => setAttribute(createdAtColumn, value);

  /// Set the updated_at timestamp.
  set updatedAt(dynamic value) => setAttribute(updatedAtColumn, value);

  /// Get a fresh timestamp for the model.
  ///
  /// Returns the current time as a [Carbon] instance.
  Carbon freshTimestamp() => Carbon.now();

  /// Get a fresh timestamp as a string for storage.
  String freshTimestampString() =>
      freshTimestamp().format('yyyy-MM-ddTHH:mm:ss');

  /// Update the creation and update timestamps.
  ///
  /// This method is called automatically before saving. It:
  /// - Sets [createdAtColumn] to the current time (if the model is new)
  /// - Sets [updatedAtColumn] to the current time (always)
  ///
  /// Only runs if [timestamps] is true.
  @override
  void updateTimestamps() {
    if (!timestamps) return;

    final time = freshTimestamp();

    // Always update updated_at (unless already dirty - developer set it)
    if (!isDirty(updatedAtColumn)) {
      setAttribute(updatedAtColumn, time);
    }

    // Only set created_at on new models (unless already dirty)
    if (!exists && !isDirty(createdAtColumn)) {
      setAttribute(createdAtColumn, time);
    }
  }

  /// Touch the model (update updated_at to now).
  ///
  /// This can be called manually to update the timestamp without other changes.
  ///
  /// ```dart
  /// await user.touch();
  /// ```
  void touch() {
    if (!timestamps) return;
    setAttribute(updatedAtColumn, freshTimestamp());
  }
}
