import '../../../core/models/unified_thread.dart';

/// Abstract repository for persisted [UnifiedThread] storage.
/// Implementations can be local (Hive), cloud (Supabase), or file-based.
abstract class ThreadRepository {
  /// Load all threads from this repository.
  Future<List<UnifiedThread>> getAll();

  /// Get a single thread by its local ID.
  Future<UnifiedThread?> getById(String id);

  /// Insert or update a thread.
  Future<void> upsert(UnifiedThread thread);

  /// Insert or update multiple threads in batch.
  Future<void> upsertBatch(List<UnifiedThread> threads);

  /// Delete a thread by its local ID.
  Future<void> delete(String id);

  /// Delete all threads from this repository.
  Future<void> deleteAll();

  /// Get the total count of threads.
  Future<int> count();

  /// Get threads filtered by source.
  Future<List<UnifiedThread>> getBySource(String source);

  /// Find a thread by its dedup key (source + originalId).
  Future<UnifiedThread?> findByOriginalId(String source, String originalId);
}
