import '../database/eloquent/model.dart';

/// The Authenticatable Mixin.
///
/// This mixin should be applied to User models to make them compatible with
/// the Magic Authentication system. It provides the necessary interface for
/// Guards to identify and authenticate users.
///
/// ## Usage
///
/// ```dart
/// class User extends Model with HasTimestamps, InteractsWithPersistence, Authenticatable {
///   @override String get table => 'users';
///   @override String get resource => 'users';
/// }
/// ```
///
/// ## How It Works
///
/// The mixin exposes:
/// - [authIdentifier] - The unique identifier value (usually the primary key)
/// - [authIdentifierName] - The column name of the identifier
///
/// Guards use these properties to persist and retrieve the authenticated user.
mixin Authenticatable on Model {
  /// Get the unique identifier for the user.
  ///
  /// This is typically the primary key value (e.g., user ID).
  ///
  /// ```dart
  /// print(user.authIdentifier); // 1
  /// ```
  dynamic get authIdentifier => getAttribute(primaryKey);

  /// Get the name of the unique identifier column.
  ///
  /// This is typically 'id' but can be overridden.
  ///
  /// ```dart
  /// print(user.authIdentifierName); // 'id'
  /// ```
  String get authIdentifierName => primaryKey;

  /// Get the password for the user.
  ///
  /// Override this if your password column has a different name.
  ///
  /// ```dart
  /// @override
  /// String? get authPassword => getAttribute('hashed_password');
  /// ```
  String? get authPassword => getAttribute('password') as String?;
}
