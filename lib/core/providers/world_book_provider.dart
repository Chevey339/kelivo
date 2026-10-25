import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../database/business_preferences.dart';
import '../models/world_book.dart';
import '../services/world_book_store.dart';

class WorldBookProvider with ChangeNotifier {
  WorldBookProvider({required BusinessPreferences preferences})
    : _store = WorldBookStore(preferences);

  final WorldBookStore _store;
  List<WorldBook> _books = const <WorldBook>[];
  bool _initialized = false;
  Future<void>? _initializationFuture;
  Future<void> _bookOperationTail = Future<void>.value();
  Map<String, List<String>> _activeIdsByAssistant =
      const <String, List<String>>{};
  Map<String, bool> _collapsedBooks = const <String, bool>{};

  List<WorldBook> get books => List<WorldBook>.unmodifiable(_books);

  WorldBook? getById(String id) {
    try {
      return _books.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  List<String> activeBookIdsFor(String? assistantId) {
    final key = WorldBookStore.assistantKey(assistantId);
    if (_activeIdsByAssistant.containsKey(key)) {
      return List<String>.unmodifiable(_activeIdsByAssistant[key]!);
    }
    final fallback =
        _activeIdsByAssistant[WorldBookStore.assistantKey(null)] ??
        const <String>[];
    return List<String>.unmodifiable(fallback);
  }

  bool isBookActive(String id, {String? assistantId}) =>
      activeBookIdsFor(assistantId).contains(id);

  List<WorldBook> activeBooksFor(String? assistantId, {List<String>? bookIds}) {
    final ids = (bookIds ?? activeBookIdsFor(assistantId)).toSet();
    return _books
        .where((book) => book.enabled && ids.contains(book.id))
        .toList(growable: false);
  }

  bool isBookCollapsed(String id) => _collapsedBooks[id] ?? false;

  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    return _initializationFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      await loadAll();
      _initialized = true;
    } finally {
      _initializationFuture = null;
    }
  }

  Future<void> _serializeBookOperation(Future<void> Function() operation) {
    final result = _bookOperationTail.then((_) => operation());
    _bookOperationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> loadAll() => _serializeBookOperation(_loadAll);

  Future<void> _loadAll() async {
    try {
      _books = await _store.getAll();
      _activeIdsByAssistant = await _store.getActiveIdsByAssistant();
      final collapsed = await _store.getCollapsedBooksMap();
      final knownIds = _books.map((e) => e.id).toSet();
      final cleanedCollapsed = <String, bool>{
        for (final entry in collapsed.entries)
          if (knownIds.contains(entry.key)) entry.key: entry.value,
      };
      _collapsedBooks = cleanedCollapsed;

      if (cleanedCollapsed.length != collapsed.length) {
        await _store.setCollapsedMap(cleanedCollapsed);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load world books: $e');
      _books = const <WorldBook>[];
      _activeIdsByAssistant = const <String, List<String>>{};
      _collapsedBooks = const <String, bool>{};
      notifyListeners();
    }
  }

  Future<void> addBook(WorldBook book) => _serializeBookOperation(() async {
    await _store.add(book);
    await _loadAll();
  });

  Future<void> updateBook(
    String id,
    WorldBook Function(WorldBook current) update,
  ) => _serializeBookOperation(() async {
    final current = getById(id);
    if (current == null) return;
    final book = update(current);
    if (!book.enabled) {
      try {
        final map = await _store.getActiveIdsByAssistant();
        final next = <String, List<String>>{};
        bool changed = false;
        for (final entry in map.entries) {
          final filtered = entry.value
              .where((e) => e != book.id)
              .toList(growable: false);
          if (filtered.length != entry.value.length) changed = true;
          next[entry.key] = filtered;
        }
        if (changed) {
          await _store.setActiveIdsMap(next);
        }
      } catch (_) {}
    }
    await _store.update(book);
    await _loadAll();
  });

  Future<void> deleteBook(String id) => _serializeBookOperation(() async {
    await _store.delete(id);
    await _loadAll();
  });

  Future<void> setEntryEnabled(String bookId, String entryId, bool enabled) =>
      _serializeBookOperation(() async {
        final index = _books.indexWhere((book) => book.id == bookId);
        if (index < 0) return;
        final book = _books[index];
        final next = book.copyWith(
          entries: [
            for (final entry in book.entries)
              entry.id == entryId ? entry.copyWith(enabled: enabled) : entry,
          ],
        );
        _books = List<WorldBook>.from(_books)..[index] = next;
        notifyListeners();
        await _store.save(_books);
      });

  Future<void> clear() => _serializeBookOperation(() async {
    await _store.clear();
    _books = const <WorldBook>[];
    _activeIdsByAssistant = const <String, List<String>>{};
    _collapsedBooks = const <String, bool>{};
    notifyListeners();
  });

  Future<void> reorderBooks({required int oldIndex, required int newIndex}) =>
      _serializeBookOperation(() async {
        if (_books.isEmpty) return;
        if (oldIndex < 0 || oldIndex >= _books.length) return;
        if (newIndex < 0 || newIndex >= _books.length) return;
        final list = List<WorldBook>.from(_books);
        final item = list.removeAt(oldIndex);
        list.insert(newIndex, item);
        _books = list;
        notifyListeners();
        await _store.save(_books);
      });

  Future<void> reorderEntries({
    required String bookId,
    required int oldIndex,
    required int newIndex,
  }) => _serializeBookOperation(() async {
    final bookIndex = _books.indexWhere((e) => e.id == bookId);
    if (bookIndex == -1) return;
    final book = _books[bookIndex];
    final entries = List<WorldBookEntry>.from(book.entries);
    if (entries.isEmpty) return;
    if (oldIndex < 0 || oldIndex >= entries.length) return;
    if (newIndex < 0 || newIndex >= entries.length) return;
    final item = entries.removeAt(oldIndex);
    entries.insert(newIndex, item);
    final nextBook = book.copyWith(entries: entries);
    final nextBooks = List<WorldBook>.from(_books);
    nextBooks[bookIndex] = nextBook;
    _books = nextBooks;
    notifyListeners();
    await _store.save(_books);
  });

  Future<void> transferEntries({
    required String sourceBookId,
    required String targetBookId,
    required Set<String> entryIds,
    required bool copy,
  }) {
    final ids = Set<String>.of(entryIds);
    return _serializeBookOperation(
      () => _transferEntries(
        sourceBookId: sourceBookId,
        targetBookId: targetBookId,
        entryIds: ids,
        copy: copy,
      ),
    );
  }

  Future<void> _transferEntries({
    required String sourceBookId,
    required String targetBookId,
    required Set<String> entryIds,
    required bool copy,
  }) async {
    if (entryIds.isEmpty || (!copy && sourceBookId == targetBookId)) return;
    final sourceIndex = _books.indexWhere((book) => book.id == sourceBookId);
    final targetIndex = _books.indexWhere((book) => book.id == targetBookId);
    if (sourceIndex < 0 || targetIndex < 0) {
      throw StateError('World book no longer exists');
    }
    final source = _books[sourceIndex];
    final target = _books[targetIndex];
    final entries = source.entries.where(
      (entry) => entryIds.contains(entry.id),
    );
    if (entries.length != entryIds.length) {
      throw StateError('World book entries have changed');
    }
    final usedIds = target.entries.map((entry) => entry.id).toSet();
    final transferred = <WorldBookEntry>[];
    for (final entry in entries) {
      var id = entry.id;
      if (copy || usedIds.contains(id)) {
        do {
          id = const Uuid().v4();
        } while (usedIds.contains(id));
      }
      usedIds.add(id);
      transferred.add(
        entry.copyWith(id: id, keywords: List.of(entry.keywords)),
      );
    }
    final previous = _books;
    final next = List<WorldBook>.from(_books);
    if (!copy) {
      next[sourceIndex] = source.copyWith(
        entries: source.entries
            .where((entry) => !entryIds.contains(entry.id))
            .toList(),
      );
    }
    next[targetIndex] = target.copyWith(
      entries: [...target.entries, ...transferred],
    );
    // Save both books together; never persist a removal on its own.
    _books = next;
    notifyListeners();
    try {
      await _store.save(next);
    } catch (_) {
      if (identical(_books, next)) {
        _books = previous;
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> setBookCollapsed(String id, bool collapsed) async {
    final key = id.trim();
    if (key.isEmpty) return;

    final next = Map<String, bool>.from(_collapsedBooks);
    next[key] = collapsed;
    _collapsedBooks = next;
    notifyListeners();
    await _store.setCollapsed(key, collapsed);
  }

  Future<void> toggleBookCollapsed(String id) async {
    await setBookCollapsed(id, !isBookCollapsed(id));
  }

  Future<void> setActiveBookIds(List<String> ids, {String? assistantId}) async {
    final key = WorldBookStore.assistantKey(assistantId);
    final nextMap = Map<String, List<String>>.from(_activeIdsByAssistant);
    nextMap[key] = ids.toSet().toList(growable: false);
    _activeIdsByAssistant = nextMap;
    notifyListeners();
    await _store.setActiveIds(ids, assistantId: assistantId);
  }

  Future<void> toggleActiveBookId(String id, {String? assistantId}) async {
    final set = activeBookIdsFor(assistantId).toSet();
    if (set.contains(id)) {
      set.remove(id);
    } else {
      final book = getById(id);
      if (book == null) return;
      if (!book.enabled) return;
      set.add(id);
    }
    await setActiveBookIds(
      set.toList(growable: false),
      assistantId: assistantId,
    );
  }
}
