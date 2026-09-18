import '../model.dart';
import '../../query/query_builder.dart';
import '../../database_manager.dart';
import '../../../facades/http.dart';
import '../../../network/magic_response.dart';
import '../../../facades/event.dart';
import '../../events/model_events.dart';

/// The Persistence Concern.
///
/// This mixin provides Active Record pattern methods for hybrid persistence.
/// Models can be persisted to local SQLite database, remote API, or both.
///
/// ## Usage
///
/// ```dart
/// class User extends Model with HasTimestamps, InteractsWithPersistence {
///   @override String get table => 'users';
///   @override String get resource => 'users';
/// }
///
/// // Find a user
/// final user = await User.find<User>(1);
///
/// // Get all users
/// final users = await User.all<User>();
///
/// // Save changes
/// user.name = 'New Name';
/// await user.save();
///
/// // Delete
/// await user.delete();
/// ```
///
/// ## Hybrid Persistence
///
/// By default, models use both local and remote persistence. Configure this
/// with [useLocal] and [useRemote]:
///
/// ```dart
/// class ApiOnlyModel extends Model with InteractsWithPersistence {
///   @override bool get useLocal => false;
///   @override bool get useRemote => true;
/// }
/// ```
mixin InteractsWithPersistence on Model {
  // ---------------------------------------------------------------------------
  // Validation State
  // ---------------------------------------------------------------------------

  /// Per-field validation errors from the most recent remote [save].
  ///
  /// Populated when a remote save receives a Laravel validation response
  /// (`{message: ..., errors: {field: [msg, ...]}}`, typically a 422) and reset
  /// on every remote save attempt. Always holds a deeply unmodifiable map (see
  /// [_extractValidationErrors]), so [validationErrors] hands it out directly.
  Map<String, List<String>> _validationErrors = const {};

  /// The per-field validation errors from the most recent [save].
  ///
  /// A remote save that fails with the Laravel validation shape
  /// (`{message: ..., errors: {field: [msg, ...]}}`, typically a 422) fills this
  /// map so the caller can render the messages under the matching form fields
  /// instead of a generic failure.
  ///
  /// It is cleared at the start of every remote save, so it stays empty after a
  /// remote save that succeeded or returned no field errors, and after a thrown
  /// transport error (which the caller treats as a non-field failure). A model
  /// that never saves remotely never fills it.
  ///
  /// It tracks the REMOTE leg, not [save]'s return value: a hybrid model
  /// (`useRemote` and `useLocal` both true) whose remote leg returns a 422 while
  /// its local write succeeds returns `true` from [save] with this map filled.
  /// Check it even after a save reported success when local persistence is on.
  ///
  /// Deeply unmodifiable: neither the map nor the message lists inside it can be
  /// mutated through this getter.
  Map<String, List<String>> get validationErrors => _validationErrors;

  /// The first validation message for [field], or `null` when [field] has none.
  ///
  /// A convenience over [validationErrors] for the common form case of showing
  /// a single message per field.
  String? validationError(String field) {
    final List<String>? messages = _validationErrors[field];

    if (messages == null || messages.isEmpty) {
      return null;
    }

    return messages.first;
  }

  // ---------------------------------------------------------------------------
  // Static Factory Methods
  // ---------------------------------------------------------------------------

  /// Create a new model instance from raw attributes.
  ///
  /// This is used internally to hydrate models from database/API results.
  static T hydrate<T extends Model>(
    Map<String, dynamic> data,
    T Function() factory,
  ) {
    final model = factory();
    model.setRawAttributes(data, sync: true);
    model.exists = true;
    return model;
  }

  // ---------------------------------------------------------------------------
  // Query Builder Access
  // ---------------------------------------------------------------------------

  /// Get a query builder for the model's table.
  QueryBuilder query() => QueryBuilder(table);

  // ---------------------------------------------------------------------------
  // Retrieval Methods
  // ---------------------------------------------------------------------------

  /// Find a model by its primary key.
  ///
  /// Attempts local database first (if [useLocal] is true), then falls back
  /// to remote API (if [useRemote] is true). If found remotely, syncs to local.
  ///
  /// ```dart
  /// final user = await User.findById<User>(1, User.new);
  /// if (user != null) {
  ///   print(user.name);
  /// }
  /// ```
  static Future<T?> findById<T extends Model>(
    dynamic id,
    T Function() factory,
  ) async {
    final sample = factory();

    // Try local first
    if (sample.useLocal) {
      try {
        final row = await QueryBuilder(
          sample.table,
        ).where(sample.primaryKey, id).first();

        if (row != null) {
          return hydrate<T>(row, factory);
        }
      } catch (_) {
        // Local failed, try remote
      }
    }

    // Try remote
    if (sample.useRemote) {
      try {
        final response = await Http.show(sample.resource, id.toString());
        if (response.successful && response.data != null) {
          final data = _extractModelData(response);
          if (data != null) {
            final model = hydrate<T>(data, factory);

            // Sync to local if enabled
            if (sample.useLocal) {
              await _syncToLocal(model);
            }

            return model;
          }
        }
      } catch (_) {
        // Remote failed
      }
    }

    return null;
  }

  /// Get all models.
  ///
  /// Retrieves from local database (if [useLocal] is true), or remote API
  /// (if [useRemote] is true).
  ///
  /// ```dart
  /// final users = await User.allModels<User>(User.new);
  /// for (final user in users) {
  ///   print(user.name);
  /// }
  /// ```
  static Future<List<T>> allModels<T extends Model>(
    T Function() factory,
  ) async {
    final sample = factory();
    final results = <T>[];

    // Try local first
    if (sample.useLocal) {
      try {
        final rows = await QueryBuilder(sample.table).get();
        for (final row in rows) {
          results.add(hydrate<T>(row, factory));
        }
        return results;
      } catch (_) {
        // Local failed, try remote
      }
    }

    // Try remote
    if (sample.useRemote) {
      try {
        final response = await Http.index(sample.resource);
        if (response.successful && response.data != null) {
          final items = _extractListData(response);
          for (final item in items) {
            final model = hydrate<T>(item, factory);

            // Sync to local if enabled
            if (sample.useLocal) {
              await _syncToLocal(model);
            }

            results.add(model);
          }
          return results;
        }
      } catch (_) {
        // Remote failed
      }
    }

    return results;
  }

  // ---------------------------------------------------------------------------
  // Persistence Methods
  // ---------------------------------------------------------------------------

  /// Save the model to the database and/or remote API.
  ///
  /// If the model already exists, it updates. Otherwise, it creates.
  /// Automatically calls [updateTimestamps] before saving.
  ///
  /// ```dart
  /// final user = User()
  ///   ..fill({'name': 'John', 'email': 'john@example.com'});
  /// await user.save();
  /// print(user.id); // The new ID
  /// ```
  Future<bool> save() async {
    // Fire Saving event
    await Event.dispatch(ModelSaving(this));

    // Determine lifecycle
    final isCreating = !exists;
    if (isCreating) {
      await Event.dispatch(ModelCreating(this));
    } else {
      await Event.dispatch(ModelUpdating(this));
    }

    // Update timestamps (hook from HasTimestamps or base Model no-op)
    updateTimestamps();

    // Prepare data
    final data = toArray();
    var success = false;

    // Save to remote
    if (useRemote) {
      // Drop any field errors from a prior save before the round trip.
      _validationErrors = const {};
      try {
        MagicResponse response;
        if (exists) {
          response = await Http.update(resource, id.toString(), data);
        } else {
          response = await Http.store(resource, data);
        }

        if (response.successful) {
          success = true;
          // Update ID from response if created
          if (!exists && response.data != null) {
            final responseData = _extractModelData(response);
            if (responseData != null && responseData[primaryKey] != null) {
              id = responseData[primaryKey];
            }
          }
        } else {
          // A non-2xx (a 422 validation failure and the like) carries the
          // per-field error shape; surface it for the caller without changing
          // the bool return contract.
          _validationErrors = _extractValidationErrors(response);
        }
      } catch (_) {
        // Remote failed (transport). Leave _validationErrors empty so the
        // caller treats this as a non-field failure.
      }
    }

    // Save to local
    if (useLocal) {
      try {
        final db = DatabaseManager();
        if (!db.isInitialized) {
          await db.init();
        }

        // Filter to only columns that exist in the table
        final columns = await db.getColumns(table);
        final filteredData = <String, dynamic>{};
        for (final entry in data.entries) {
          if (columns.contains(entry.key)) {
            filteredData[entry.key] = entry.value;
          }
        }

        if (exists) {
          await QueryBuilder(table).where(primaryKey, id).update(filteredData);
        } else {
          final newId = await QueryBuilder(table).insert(filteredData);
          id ??= newId;
        }
        success = true;
      } catch (_) {
        // Local failed
      }
    }

    if (success) {
      exists = true;
      wasRecentlyCreated = !exists;
      syncOriginal();

      // Fire post-save events
      if (isCreating) {
        await Event.dispatch(ModelCreated(this));
      } else {
        await Event.dispatch(ModelUpdated(this));
      }
      await Event.dispatch(ModelSaved(this));
    }

    return success;
  }

  /// Delete the model from the database and/or remote API.
  ///
  /// ```dart
  /// await user.delete();
  /// print(user.exists); // false
  /// ```
  Future<bool> delete() async {
    if (!exists) return false;

    var success = false;

    // Delete from remote
    if (useRemote) {
      try {
        final response = await Http.destroy(resource, id.toString());
        if (response.successful) {
          success = true;
        }
      } catch (_) {
        // Remote failed
      }
    }

    // Delete from local
    if (useLocal) {
      try {
        await QueryBuilder(table).where(primaryKey, id).delete();
        success = true;
      } catch (_) {
        // Local failed
      }
    }

    if (success) {
      exists = false;
      await Event.dispatch(ModelDeleted(this));
    }

    return success;
  }

  /// Refresh the model from the database/API.
  ///
  /// ```dart
  /// await user.refresh();
  /// ```
  Future<bool> refresh() async {
    if (!exists || id == null) return false;

    // Try local first
    if (useLocal) {
      try {
        final row = await QueryBuilder(table).where(primaryKey, id).first();
        if (row != null) {
          setRawAttributes(row, sync: true);
          return true;
        }
      } catch (_) {
        // Local failed
      }
    }

    // Try remote
    if (useRemote) {
      try {
        final response = await Http.show(resource, id.toString());
        if (response.successful && response.data != null) {
          final data = _extractModelData(response);
          if (data != null) {
            setRawAttributes(data, sync: true);
            return true;
          }
        }
      } catch (_) {
        // Remote failed
      }
    }

    return false;
  }

  // ---------------------------------------------------------------------------
  // Helper Methods
  // ---------------------------------------------------------------------------

  /// Sync a model to local database.
  static Future<void> _syncToLocal<T extends Model>(T model) async {
    try {
      final db = DatabaseManager();
      if (!db.isInitialized) {
        await db.init();
      }

      final columns = await db.getColumns(model.table);
      final data = <String, dynamic>{};
      for (final entry in model.toArray().entries) {
        if (columns.contains(entry.key)) {
          data[entry.key] = entry.value;
        }
      }

      // Check if exists
      final existing = await QueryBuilder(
        model.table,
      ).where(model.primaryKey, model.id).first();

      if (existing != null) {
        await QueryBuilder(
          model.table,
        ).where(model.primaryKey, model.id).update(data);
      } else {
        await QueryBuilder(model.table).insert(data);
      }
    } catch (_) {
      // Sync failed silently
    }
  }

  /// Extract the Laravel validation error shape from a failed [response].
  ///
  /// Reads `response.data`'s `{errors: {field: [msg, ...]}}` block (the shape
  /// Laravel returns on a 422) and returns `{}` when that shape is absent, so a
  /// non-validation failure yields no field errors. Delegates the parsing to
  /// [MagicResponse.errors], the framework's canonical parser for this shape.
  ///
  /// The result is frozen at both levels: [MagicResponse.errors] builds a fresh
  /// mutable map of mutable lists, and a shallow `Map.unmodifiable` would still
  /// let a caller mutate the per-field lists it hands out.
  Map<String, List<String>> _extractValidationErrors(MagicResponse response) {
    return Map<String, List<String>>.unmodifiable({
      for (final MapEntry<String, List<String>> entry
          in response.errors.entries)
        entry.key: List<String>.unmodifiable(entry.value),
    });
  }

  /// Extract model data from API response.
  ///
  /// Handles both direct data and nested `data` key.
  static Map<String, dynamic>? _extractModelData(MagicResponse response) {
    final data = response.data;
    if (data is Map<String, dynamic>) {
      // Check for nested 'data' key (common API pattern)
      if (data.containsKey('data') && data['data'] is Map) {
        return data['data'] as Map<String, dynamic>;
      }
      return data;
    }
    return null;
  }

  /// Extract list data from API response.
  static List<Map<String, dynamic>> _extractListData(MagicResponse response) {
    final data = response.data;

    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }

    if (data is Map<String, dynamic>) {
      // Check for nested 'data' key
      if (data.containsKey('data') && data['data'] is List) {
        return (data['data'] as List).cast<Map<String, dynamic>>();
      }
    }

    return [];
  }
}
