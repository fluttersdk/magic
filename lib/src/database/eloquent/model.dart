import 'dart:convert';

import '../../support/carbon.dart';

/// The base Eloquent Model.
///
/// This abstract class provides the foundation for all Magic models. It handles
/// attribute management, type casting, dirty tracking, and serialization.
///
/// ## Creating a Model
///
/// ```dart
/// class User extends Model with HasTimestamps, InteractsWithPersistence {
///   @override String get table => 'users';
///   @override String get resource => 'users';
///
///   @override
///   List<String> get fillable => ['name', 'email'];
///
///   @override
///   Map<String, String> get casts => {'born_at': 'datetime'};
///
///   // Typed accessors
///   String get name => getAttribute('name');
///   set name(String val) => setAttribute('name', val);
/// }
/// ```
///
/// ## Attribute Casting
///
/// The model automatically casts attributes based on the [casts] map:
/// - `datetime` → Carbon
/// - `json` → Map<String, dynamic>
/// - `bool` → bool
/// - `int` → int
/// - `double` → double
abstract class Model {
  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  /// The model's current attributes.
  final Map<String, dynamic> _attributes = {};

  /// The model's original attributes (for dirty checking).
  final Map<String, dynamic> _original = {};

  /// Indicates if the model exists in the database.
  bool exists = false;

  /// Indicates if the model was recently created.
  bool wasRecentlyCreated = false;

  // ---------------------------------------------------------------------------
  // Configuration (Override in subclasses)
  // ---------------------------------------------------------------------------

  /// The table associated with the model.
  String get table;

  /// The API resource name for remote operations.
  String get resource;

  /// The primary key for the model.
  String get primaryKey => 'id';

  /// Indicates if the primary key is auto-incrementing.
  bool get incrementing => true;

  /// Whether to use local database persistence.
  bool get useLocal => true;

  /// Whether to use remote API persistence.
  bool get useRemote => true;

  /// The attributes that are mass assignable.
  List<String> get fillable => [];

  /// The attributes that are guarded from mass assignment.
  ///
  /// If set to `['*']`, all attributes are guarded by default.
  List<String> get guarded => ['*'];

  /// The attributes that should be cast.
  ///
  /// Supported cast types:
  /// - `datetime` → Carbon
  /// - `json` → Map<String, dynamic>
  /// - `bool` → bool
  /// - `int` → int
  /// - `double` → double
  Map<String, String> get casts => {};

  /// The model relationships for automatic casting.
  ///
  /// Define nested model relationships that should be automatically cast
  /// from API responses. The key is the attribute name, the value is a
  /// factory function that creates the related model.
  ///
  /// ```dart
  /// @override
  /// Map<String, Model Function()> get relations => {
  ///   'user': User.new,
  ///   'comments': Comment.new,
  /// };
  /// ```
  Map<String, Model Function()> get relations => {};

  // ---------------------------------------------------------------------------
  // Lifecycle Hooks
  // ---------------------------------------------------------------------------

  /// Update the model's timestamps.
  ///
  /// This is a no-op in the base class. The [HasTimestamps] mixin overrides
  /// this to set `created_at` and `updated_at` automatically.
  ///
  /// Called automatically before saving.
  void updateTimestamps() {}

  // ---------------------------------------------------------------------------
  // Attribute Accessors
  // ---------------------------------------------------------------------------

  /// Get an attribute from the model.
  ///
  /// Handles type casting based on the [casts] map:
  /// - `datetime` strings are converted to [Carbon]
  /// - `json` strings are decoded to Map
  dynamic getAttribute(String key) {
    final value = _attributes[key];
    final castType = casts[key];

    if (value == null) return null;

    switch (castType) {
      case 'datetime':
        if (value is Carbon) return value;
        if (value is DateTime) return Carbon.fromDateTime(value);
        if (value is String) return Carbon.parse(value);
        return value;

      case 'json':
        if (value is Map) return value;
        if (value is String) return jsonDecode(value) as Map<String, dynamic>;
        return value;

      case 'bool':
        if (value is bool) return value;
        if (value is int) return value == 1;
        if (value is String) return value.toLowerCase() == 'true';
        return value;

      case 'int':
        if (value is int) return value;
        return int.tryParse(value.toString()) ?? value;

      case 'double':
        if (value is double) return value;
        return double.tryParse(value.toString()) ?? value;

      default:
        return value;
    }
  }

  /// Set an attribute on the model.
  ///
  /// Handles type conversion for storage:
  /// - [Carbon] values are converted to ISO 8601 strings
  /// - [Map] values for json casts are encoded to strings
  void setAttribute(String key, dynamic value) {
    final castType = casts[key];

    // Convert types for storage
    if (value is Carbon) {
      _attributes[key] = value.format('yyyy-MM-ddTHH:mm:ss');
    } else if (value is DateTime) {
      _attributes[key] =
          Carbon.fromDateTime(value).format('yyyy-MM-ddTHH:mm:ss');
    } else if (castType == 'json' && value is Map) {
      _attributes[key] = jsonEncode(value);
    } else {
      _attributes[key] = value;
    }
  }

  // ---------------------------------------------------------------------------
  // Convenient Accessors (Alternative to typed getters/setters)
  // ---------------------------------------------------------------------------

  /// Get an attribute value with optional default and type casting.
  ///
  /// This provides a convenient way to access attributes without defining
  /// typed getters for every field.
  ///
  /// ```dart
  /// // Basic usage
  /// final name = user.get<String>('name');
  ///
  /// // With default value
  /// final name = user.get<String>('name', defaultValue: 'Unknown');
  ///
  /// // Works with cast types (datetime returns Carbon)
  /// final bornAt = user.get<Carbon>('born_at');
  ///
  /// // JSON fields return Map
  /// final settings = user.get<Map<String, dynamic>>('settings', defaultValue: {});
  /// ```
  T? get<T>(String key, {T? defaultValue}) {
    final value = getAttribute(key);
    if (value == null) return defaultValue;
    if (value is T) return value;
    return defaultValue;
  }

  /// Get a single related model.
  ///
  /// Automatically casts a Map attribute to the related model type defined
  /// in [relations]. The result is cached for subsequent access.
  ///
  /// ```dart
  /// // In Post model:
  /// @override
  /// Map<String, Model Function()> get relations => {'user': User.new};
  ///
  /// User? get user => getRelation<User>('user');
  ///
  /// // Usage:
  /// final post = await Post.find(1);
  /// print(post?.user?.name); // "John Doe"
  /// ```
  T? getRelation<T extends Model>(String key) {
    final data = _attributes[key];
    if (data == null) return null;
    if (data is T) return data; // Already cast
    if (data is Map<String, dynamic>) {
      final factory = relations[key];
      if (factory != null) {
        final model = factory() as T;
        model.setRawAttributes(data, sync: true);
        model.exists = true;
        _attributes[key] = model; // Cache the cast result
        return model;
      }
    }
    return null;
  }

  /// Get a list of related models.
  ///
  /// Automatically casts a List of Maps to the related model type defined
  /// in [relations]. The result is cached for subsequent access.
  ///
  /// ```dart
  /// // In Post model:
  /// @override
  /// Map<String, Model Function()> get relations => {'comments': Comment.new};
  ///
  /// List<Comment> get comments => getRelations<Comment>('comments');
  ///
  /// // Usage:
  /// final post = await Post.find(1);
  /// for (final comment in post?.comments ?? []) {
  ///   print(comment.body);
  /// }
  /// ```
  List<T> getRelations<T extends Model>(String key) {
    final data = _attributes[key];
    if (data == null) return [];
    if (data is List<T>) return data; // Already cast
    if (data is List) {
      final factory = relations[key];
      if (factory != null) {
        final models = data
            .map((item) {
              if (item is Map<String, dynamic>) {
                final model = factory() as T;
                model.setRawAttributes(item, sync: true);
                model.exists = true;
                return model;
              }
              return null;
            })
            .whereType<T>()
            .toList();
        _attributes[key] = models; // Cache
        return models;
      }
    }
    return [];
  }

  /// Set an attribute value.
  ///
  /// This provides a convenient way to set attributes without defining
  /// typed setters for every field.
  ///
  /// ```dart
  /// user.set('name', 'John Doe');
  /// user.set('born_at', Carbon.now());
  /// user.set('settings', {'theme': 'dark'});
  /// ```
  void set(String key, dynamic value) => setAttribute(key, value);

  /// Check if an attribute exists and is not null.
  ///
  /// ```dart
  /// if (user.has('email')) {
  ///   sendEmail(user.get<String>('email')!);
  /// }
  /// ```
  bool has(String key) =>
      _attributes.containsKey(key) && _attributes[key] != null;

  /// Get the model's primary key value.
  dynamic get id => getAttribute(primaryKey);

  /// Set the model's primary key value.
  set id(dynamic value) => setAttribute(primaryKey, value);

  /// Fill the model with an array of attributes.
  ///
  /// Only fills attributes that are in the [fillable] list, unless [fillable]
  /// is empty and [guarded] doesn't include `'*'`.
  void fill(Map<String, dynamic> attributes) {
    for (final entry in attributes.entries) {
      if (_isFillable(entry.key)) {
        setAttribute(entry.key, entry.value);
      }
    }
  }

  /// Determine if the given attribute is fillable.
  bool _isFillable(String key) {
    // If fillable is explicitly defined, check if key is in it
    if (fillable.isNotEmpty) {
      return fillable.contains(key);
    }

    // If guarded is '*', nothing is fillable by default
    if (guarded.contains('*')) {
      return false;
    }

    // Otherwise, check if it's not guarded
    return !guarded.contains(key);
  }

  /// Get all attributes as a Map.
  Map<String, dynamic> get attributes => Map<String, dynamic>.from(_attributes);

  // ---------------------------------------------------------------------------
  // Serialization (Flutter-Familiar API)
  // ---------------------------------------------------------------------------

  /// Convert the model to a Map.
  ///
  /// This is the same as [toArray] but named to be more familiar to Flutter
  /// developers.
  ///
  /// ```dart
  /// final map = user.toMap();
  /// // {'id': 1, 'name': 'John', 'email': 'john@test.com'}
  /// ```
  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{};

    for (final entry in _attributes.entries) {
      final value = getAttribute(entry.key);
      if (value is Model) {
        result[entry.key] = value.toMap();
      } else if (value is List && value.isNotEmpty && value.first is Model) {
        result[entry.key] = value.map((m) => (m as Model).toMap()).toList();
      } else if (value is Carbon) {
        result[entry.key] = value.format('yyyy-MM-ddTHH:mm:ss');
      } else {
        result[entry.key] = value;
      }
    }

    return result;
  }

  /// Alias for [toMap] - Laravel-style naming.
  Map<String, dynamic> toArray() => toMap();

  /// Convert the model to a JSON string.
  ///
  /// ```dart
  /// final json = user.toJson();
  /// // '{"id":1,"name":"John","email":"john@test.com"}'
  /// ```
  String toJson() => jsonEncode(toMap());

  /// Create a model instance from a Map.
  ///
  /// This static method creates a new model instance and populates it with
  /// the given data. It bypasses the [fillable] guard for convenience.
  ///
  /// ```dart
  /// final user = User.fromMap({'id': 1, 'name': 'John'});
  /// ```
  ///
  /// Note: Subclasses should override this to return the correct type:
  /// ```dart
  /// static User fromMap(Map<String, dynamic> map) {
  ///   return User()..setRawAttributes(map, sync: true)..exists = true;
  /// }
  /// ```

  /// Create a model instance from a JSON string.
  ///
  /// ```dart
  /// final user = User.fromJson('{"id":1,"name":"John"}');
  /// ```
  ///
  /// Note: Subclasses should override this to return the correct type:
  /// ```dart
  /// static User fromJson(String json) => User.fromMap(jsonDecode(json));
  /// ```

  // ---------------------------------------------------------------------------
  // Dirty Checking
  // ---------------------------------------------------------------------------

  /// Determine if the model or a given attribute has been modified.
  ///
  /// ```dart
  /// user.name = 'New Name';
  /// print(user.isDirty()); // true
  /// print(user.isDirty('name')); // true
  /// print(user.isDirty('email')); // false
  /// ```
  bool isDirty([String? attribute]) {
    if (attribute != null) {
      return _attributes[attribute] != _original[attribute];
    }

    // Check all attributes
    for (final key in _attributes.keys) {
      if (_attributes[key] != _original[key]) {
        return true;
      }
    }

    return false;
  }

  /// Get the dirty attributes (those that have changed).
  Map<String, dynamic> getDirty() {
    final dirty = <String, dynamic>{};

    for (final key in _attributes.keys) {
      if (_attributes[key] != _original[key]) {
        dirty[key] = _attributes[key];
      }
    }

    return dirty;
  }

  /// Sync the original attributes with the current.
  ///
  /// Called after saving to mark the model as "clean".
  void syncOriginal() {
    _original.clear();
    _original.addAll(_attributes);
  }

  /// Set the model's raw attributes.
  ///
  /// Used internally when hydrating from database/API.
  void setRawAttributes(Map<String, dynamic> attributes, {bool sync = false}) {
    _attributes.clear();
    _attributes.addAll(attributes);

    if (sync) {
      syncOriginal();
    }
  }

  // ---------------------------------------------------------------------------
  // Magic Methods
  // ---------------------------------------------------------------------------

  @override
  String toString() {
    return '${runtimeType.toString()}(${toJson()})';
  }
}
