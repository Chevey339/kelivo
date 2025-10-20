import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/quick_phrase.dart';
import '../services/quick_phrase_store.dart';
import '../services/icloud_sync_service.dart';

class QuickPhraseProvider with ChangeNotifier {
  List<QuickPhrase> _phrases = [];
  bool _initialized = false;

  List<QuickPhrase> get phrases => List.unmodifiable(_phrases);
  
  List<QuickPhrase> get globalPhrases => 
      _phrases.where((p) => p.isGlobal).toList();
  
  List<QuickPhrase> getForAssistant(String assistantId) =>
      _phrases.where((p) => !p.isGlobal && p.assistantId == assistantId).toList();

  QuickPhraseProvider() {
    if (ICloudSyncService.instance.isSupported) {
      ICloudSyncService.instance.addListener(_handleICloudUpdate);
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;
    await loadAll();
    _initialized = true;
  }

  Future<void> loadAll() async {
    try {
      _phrases = await QuickPhraseStore.getAll();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load quick phrases: $e');
      _phrases = [];
      notifyListeners();
    }
  }

  Future<void> add(QuickPhrase phrase) async {
    await QuickPhraseStore.add(phrase);
    await loadAll();
  }

  Future<void> update(QuickPhrase phrase) async {
    await QuickPhraseStore.update(phrase);
    await loadAll();
  }

  Future<void> delete(String id) async {
    await QuickPhraseStore.delete(id);
    await loadAll();
  }

  Future<void> clear() async {
    await QuickPhraseStore.clear();
    _phrases = [];
    notifyListeners();
  }

  void _handleICloudUpdate() {
    unawaited(loadAll());
  }

  void _reorderInMemory({
    required int oldIndex,
    required int newIndex,
    String? assistantId,
  }) {
    final bool isGlobal = assistantId == null;

    // Determine indices in the subset (global or specific assistant)
    final List<int> subsetIndices = [];
    for (int i = 0; i < _phrases.length; i++) {
      final p = _phrases[i];
      final matches = isGlobal
          ? p.isGlobal
          : (!p.isGlobal && p.assistantId == assistantId);
      if (matches) subsetIndices.add(i);
    }

    if (subsetIndices.isEmpty) return;
    if (oldIndex < 0 || oldIndex >= subsetIndices.length) return;
    if (newIndex < 0 || newIndex >= subsetIndices.length) return;

    // Extract the subset in current order
    final List<QuickPhrase> subset =
        subsetIndices.map((i) => _phrases[i]).toList(growable: true);

    final item = subset.removeAt(oldIndex);
    subset.insert(newIndex, item);

    // Merge reordered subset back into original list
    final List<QuickPhrase> merged = [];
    int take = 0;
    for (int i = 0; i < _phrases.length; i++) {
      final p = _phrases[i];
      final matches = isGlobal
          ? p.isGlobal
          : (!p.isGlobal && p.assistantId == assistantId);
      if (matches) {
        merged.add(subset[take++]);
      } else {
        merged.add(p);
      }
    }
    _phrases = merged;
  }

  Future<void> reorder({
    required int oldIndex,
    required int newIndex,
    String? assistantId,
  }) async {
    _reorderInMemory(oldIndex: oldIndex, newIndex: newIndex, assistantId: assistantId);
    notifyListeners();
    await QuickPhraseStore.save(_phrases);
  }

  // Backward/alternate API name for clarity
  Future<void> reorderPhrases({
    required int oldIndex,
    required int newIndex,
    String? assistantId,
  }) async {
    // Immediate UI update, then persist
    _reorderInMemory(oldIndex: oldIndex, newIndex: newIndex, assistantId: assistantId);
    notifyListeners();
    await QuickPhraseStore.save(_phrases);
  }

  @override
  void dispose() {
    if (ICloudSyncService.instance.isSupported) {
      ICloudSyncService.instance.removeListener(_handleICloudUpdate);
    }
    super.dispose();
  }
}
