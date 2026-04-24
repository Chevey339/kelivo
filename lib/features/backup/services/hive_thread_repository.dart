import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/models/unified_thread.dart';
import '../../../core/models/unified_message.dart';
import '../../../core/models/message_attachment.dart';
import 'thread_repository.dart';

/// ThreadRepository implementation backed by Hive local storage.
class HiveThreadRepository implements ThreadRepository {
  static const String _boxName = 'unified_threads';

  Box<UnifiedThread>? _box;

  Future<Box<UnifiedThread>> get _ensureBox async {
    if (_box != null && _box!.isOpen) return _box!;

    // Register adapters if not already registered
    if (!Hive.isAdapterRegistered(50)) {
      Hive.registerAdapter(UnifiedThreadAdapter());
    }
    if (!Hive.isAdapterRegistered(51)) {
      Hive.registerAdapter(UnifiedMessageAdapter());
    }
    if (!Hive.isAdapterRegistered(52)) {
      Hive.registerAdapter(MessageAttachmentAdapter());
    }
    if (!Hive.isAdapterRegistered(53)) {
      Hive.registerAdapter(MessageRoleAdapter());
    }

    _box = await Hive.openBox<UnifiedThread>(_boxName);
    return _box!;
  }

  @override
  Future<List<UnifiedThread>> getAll() async {
    final box = await _ensureBox;
    return box.values.toList();
  }

  @override
  Future<UnifiedThread?> getById(String id) async {
    final box = await _ensureBox;
    return box.get(id);
  }

  @override
  Future<void> upsert(UnifiedThread thread) async {
    final box = await _ensureBox;
    await box.put(thread.id, thread);
  }

  @override
  Future<void> upsertBatch(List<UnifiedThread> threads) async {
    final box = await _ensureBox;
    final map = <String, UnifiedThread>{};
    for (final t in threads) {
      map[t.id] = t;
    }
    await box.putAll(map);
  }

  @override
  Future<void> delete(String id) async {
    final box = await _ensureBox;
    await box.delete(id);
  }

  @override
  Future<void> deleteAll() async {
    final box = await _ensureBox;
    await box.clear();
  }

  @override
  Future<int> count() async {
    final box = await _ensureBox;
    return box.length;
  }

  @override
  Future<List<UnifiedThread>> getBySource(String source) async {
    final box = await _ensureBox;
    return box.values.where((t) => t.source == source).toList();
  }

  @override
  Future<UnifiedThread?> findByOriginalId(
    String source,
    String originalId,
  ) async {
    final box = await _ensureBox;
    try {
      return box.values.firstWhere(
        (t) => t.source == source && t.originalId == originalId,
      );
    } catch (_) {
      return null;
    }
  }

  /// Close the Hive box (call on app shutdown).
  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
      _box = null;
    }
  }
}
