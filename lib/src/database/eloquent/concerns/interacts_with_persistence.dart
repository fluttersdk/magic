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
        final row = await QueryBuilder(sample.table)
            .where(sample.primaryKey, id)
            .first();

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
        }
      } catch (_) {
        // Remote failed, continue to local
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
      final existing = await QueryBuilder(model.table)
          .where(model.primaryKey, model.id)
          .first();

      if (existing != null) {
        await QueryBuilder(model.table)
            .where(model.primaryKey, model.id)
            .update(data);
      } else {
        await QueryBuilder(model.table).insert(data);
      }
    } catch (_) {
      // Sync failed silently
    }
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
