/// The storage a `useLocal` model persists its rows to.
///
/// `InteractsWithPersistence` resolves the implementation from the container
/// key `'local_model_store'` before every local leg, and throws a [StateError]
/// naming `magic_local_storage` when nothing is bound, so a missing store fails
/// loudly instead of being swallowed by the leg's error handling.
///
/// Rows are plain attribute maps keyed by column name; [primaryKey] names the
/// column that identifies a row inside [table].
abstract class LocalModelStore {
  /// The row whose [primaryKey] equals [id], or `null` when there is none.
  Future<Map<String, dynamic>?> find(
    String table,
    String primaryKey,
    dynamic id,
  );

  /// Every row of [table], in storage order.
  Future<List<Map<String, dynamic>>> all(String table);

  /// Insert [data] as a new row and return the key the store assigned to it.
  ///
  /// Attributes the store cannot hold (no such column) are dropped.
  Future<dynamic> insert(String table, Map<String, dynamic> data);

  /// Overwrite the row whose [primaryKey] equals [id] with [data].
  ///
  /// Attributes the store cannot hold (no such column) are dropped.
  Future<void> update(
    String table,
    String primaryKey,
    dynamic id,
    Map<String, dynamic> data,
  );

  /// Delete the row whose [primaryKey] equals [id].
  Future<void> delete(String table, String primaryKey, dynamic id);

  /// Write a row pulled from the remote side: update the row whose
  /// [primaryKey] equals [id] when it exists, insert [data] otherwise.
  Future<void> upsert(
    String table,
    String primaryKey,
    dynamic id,
    Map<String, dynamic> data,
  );
}
