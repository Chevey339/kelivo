import 'package:flutter/foundation.dart';

import '../models/world_book.dart';
import '../services/world_book_store.dart';

class WorldBookProvider with ChangeNotifier {
  List<WorldBook> _books = const <WorldBook>[];
  bool _initialized = false;
  Map<String, List<String>> _activeIdsByAssistant =
      const <String, List<String>>{};

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

  Future<void> initialize() async {
    if (_initialized) return;
    await loadAll();
    _initialized = true;
  }

  Future<void> loadAll() async {
    try {
      _books = await WorldBookStore.getAll();
      _activeIdsByAssistant = await WorldBookStore.getActiveIdsByAssistant();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load world books: $e');
      _books = const <WorldBook>[];
      _activeIdsByAssistant = const <String, List<String>>{};
      notifyListeners();
    }
  }

  Future<void> addBook(WorldBook book) async {
    await WorldBookStore.add(book);
    await loadAll();
  }

  Future<void> updateBook(WorldBook book) async {
    await WorldBookStore.update(book);
    await loadAll();
  }

  Future<void> deleteBook(String id) async {
    await WorldBookStore.delete(id);
    await loadAll();
  }

  Future<void> clear() async {
    await WorldBookStore.clear();
    _books = const <WorldBook>[];
    _activeIdsByAssistant = const <String, List<String>>{};
    notifyListeners();
  }

  Future<void> reorderBooks({
    required int oldIndex,
    required int newIndex,
  }) async {
    if (_books.isEmpty) return;
    if (oldIndex < 0 || oldIndex >= _books.length) return;
    if (newIndex < 0 || newIndex >= _books.length) return;
    final list = List<WorldBook>.from(_books);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    _books = list;
    notifyListeners();
    await WorldBookStore.save(_books);
  }

  Future<void> setActiveBookIds(List<String> ids, {String? assistantId}) async {
    final key = WorldBookStore.assistantKey(assistantId);
    final nextMap = Map<String, List<String>>.from(_activeIdsByAssistant);
    nextMap[key] = ids.toSet().toList(growable: false);
    _activeIdsByAssistant = nextMap;
    notifyListeners();
    await WorldBookStore.setActiveIds(ids, assistantId: assistantId);
  }

  Future<void> toggleActiveBookId(String id, {String? assistantId}) async {
    final set = activeBookIdsFor(assistantId).toSet();
    if (set.contains(id)) {
      set.remove(id);
    } else {
      set.add(id);
    }
    await setActiveBookIds(
      set.toList(growable: false),
      assistantId: assistantId,
    );
  }
}
