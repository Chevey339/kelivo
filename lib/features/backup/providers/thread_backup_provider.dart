import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/unified_thread.dart';
import '../../../core/models/unified_message.dart';
import '../services/thread_repository.dart';
import '../services/hive_thread_repository.dart';
import '../services/importers/import_manager.dart';

/// State of an import operation.
enum ImportState { idle, parsing, reviewing, complete, error }

/// Central provider for thread backup and sync operations.
///
/// Manages the lifecycle of backed-up threads from multiple chat sources:
/// - Import from JSON exports (ChatGPT, Gemini, Perplexity, Claude)
/// - Local persistence via Hive
/// - Export to single JSON file
/// - Dedup detection across imports
class ThreadBackupProvider extends ChangeNotifier {
  final ThreadRepository _repository;
  final ImportManager _importManager;

  List<UnifiedThread> _threads = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _lastError;

  // Import flow state
  ImportState _importState = ImportState.idle;
  List<UnifiedThread> _pendingImports = [];
  int _duplicatesSkipped = 0;

  ThreadBackupProvider({
    ThreadRepository? repository,
    ImportManager? importManager,
  }) : _repository = repository ?? HiveThreadRepository(),
       _importManager = importManager ?? ImportManager();

  // === Getters ===

  List<UnifiedThread> get threads => List.unmodifiable(_threads);
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get lastError => _lastError;
  ImportState get importState => _importState;
  List<UnifiedThread> get pendingImports => List.unmodifiable(_pendingImports);
  int get duplicatesSkipped => _duplicatesSkipped;

  int get totalCount => _threads.length;

  /// Get a breakdown by source.
  Map<String, int> get sourceBreakdown {
    final map = <String, int>{};
    for (final t in _threads) {
      map[t.source] = (map[t.source] ?? 0) + 1;
    }
    return map;
  }

  /// Number of unique sources present.
  int get sourceCount => sourceBreakdown.length;

  /// Get threads filtered by source.
  List<UnifiedThread> threadsBySource(String source) {
    return _threads.where((t) => t.source == source).toList();
  }

  // === Lifecycle ===

  /// Load all threads from the local repository.
  Future<void> loadAll() async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      _threads = await _repository.getAll();
      _hasLoaded = true;
    } catch (e) {
      _lastError = 'Failed to load threads: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete a single thread.
  Future<void> deleteThread(String id) async {
    try {
      await _repository.delete(id);
      _threads.removeWhere((t) => t.id == id);
      notifyListeners();
    } catch (e) {
      _lastError = 'Failed to delete thread: $e';
      notifyListeners();
    }
  }

  /// Delete all threads.
  Future<void> deleteAll() async {
    try {
      await _repository.deleteAll();
      _threads.clear();
      notifyListeners();
    } catch (e) {
      _lastError = 'Failed to delete all threads: $e';
      notifyListeners();
    }
  }

  // === Import Flow ===

  /// Import threads from a JSON string (auto-detects source).
  /// Returns the import result with dedup applied.
  Future<ImportResult> importFromJson(String jsonString) async {
    _importState = ImportState.parsing;
    _lastError = null;
    notifyListeners();

    try {
      final result = _importManager.importFromJson(jsonString);

      if (result.errors.isNotEmpty && result.imported.isEmpty) {
        _importState = ImportState.error;
        _lastError = result.errors.first.message;
        notifyListeners();
        return result;
      }

      // Apply dedup against existing threads
      final (newThreads, skipped) = _dedupNewThreads(result.imported);
      _pendingImports = newThreads;
      _duplicatesSkipped = skipped;

      _importState =
          newThreads.isEmpty ? ImportState.complete : ImportState.reviewing;
      notifyListeners();

      return ImportResult(
        imported: newThreads,
        errors: result.errors,
      );
    } catch (e) {
      _importState = ImportState.error;
      _lastError = 'Import failed: $e';
      notifyListeners();
      return ImportResult(
        imported: [],
        errors: [ImportError(index: 0, message: _lastError!)],
      );
    }
  }

  /// Import threads from a JSON string with a known source.
  Future<ImportResult> importFromJsonWithSource(
    String jsonString,
    DetectedSource source,
  ) async {
    _importState = ImportState.parsing;
    _lastError = null;
    notifyListeners();

    try {
      final result = _importManager.importWithSource(jsonString, source);

      if (result.errors.isNotEmpty && result.imported.isEmpty) {
        _importState = ImportState.error;
        _lastError = result.errors.first.message;
        notifyListeners();
        return result;
      }

      final (newThreads, skipped) = _dedupNewThreads(result.imported);
      _pendingImports = newThreads;
      _duplicatesSkipped = skipped;

      _importState =
          newThreads.isEmpty ? ImportState.complete : ImportState.reviewing;
      notifyListeners();

      return ImportResult(
        imported: newThreads,
        errors: result.errors,
      );
    } catch (e) {
      _importState = ImportState.error;
      _lastError = 'Import failed: $e';
      notifyListeners();
      return ImportResult(
        imported: [],
        errors: [ImportError(index: 0, message: _lastError!)],
      );
    }
  }

  /// Confirm and persist the current pending imports.
  Future<void> confirmImport() async {
    if (_pendingImports.isEmpty) return;

    _isLoading = true;
    _importState = ImportState.parsing;
    notifyListeners();

    try {
      await _repository.upsertBatch(_pendingImports);
      _threads.addAll(_pendingImports);
      _pendingImports = [];
      _duplicatesSkipped = 0;
      _importState = ImportState.complete;
    } catch (e) {
      _lastError = 'Failed to save imported threads: $e';
      _importState = ImportState.error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cancel the current import, discarding pending threads.
  void cancelImport() {
    _pendingImports = [];
    _duplicatesSkipped = 0;
    _importState = ImportState.idle;
    _lastError = null;
    notifyListeners();
  }

  /// Reset import state after showing results.
  void resetImportState() {
    _importState = ImportState.idle;
    _pendingImports = [];
    _duplicatesSkipped = 0;
    notifyListeners();
  }

  // === Export ===

  /// Export all threads to a JSON string.
  String exportToJson() {
    final list = _threads.map((t) => t.toJson()).toList();
    return _encodeJson(list);
  }

  /// Export all threads to a file at the given path.
  Future<void> exportToFile(String filePath) async {
    try {
      final json = exportToJson();
      final file = File(filePath);
      await file.writeAsString(json);
    } catch (e) {
      _lastError = 'Export failed: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Detect source format from a JSON string (without importing).
  DetectedSource detectSource(String jsonString) {
    try {
      final dynamic parsed = _parseJson(jsonString);
      return _importManager.detectSource(parsed);
    } catch (_) {
      return DetectedSource.unknown;
    }
  }

  // === Internal ===

  /// Dedup: return (threads not already stored, count skipped).
  (List<UnifiedThread>, int) _dedupNewThreads(List<UnifiedThread> candidates) {
    final existingKeys = <String>{};
    for (final t in _threads) {
      existingKeys.add(t.dedupKey);
    }

    final newThreads = <UnifiedThread>[];
    int skipped = 0;

    for (final candidate in candidates) {
      if (existingKeys.contains(candidate.dedupKey)) {
        skipped++;
      } else {
        newThreads.add(candidate);
        existingKeys.add(candidate.dedupKey);
      }
    }

    return (newThreads, skipped);
  }

  dynamic _parseJson(String jsonString) {
    import 'dart:convert' show jsonDecode;
    return jsonDecode(jsonString);
  }

  String _encodeJson(dynamic value) {
    import 'dart:convert' show jsonEncode;
    return jsonEncode(value);
  }
}
