import 'dart:convert';

import '../database/business_preferences.dart';
import '../models/quick_phrase.dart';

class QuickPhraseStore {
  QuickPhraseStore(this._preferences);

  static const String _phrasesKey = 'quick_phrases_v1';

  final BusinessPreferences _preferences;

  Future<List<QuickPhrase>> getAll() async {
    await _preferences.load();
    final raw = _preferences.getString(_phrasesKey);
    if (raw == null || raw.isEmpty) return <QuickPhrase>[];
    try {
      final values = jsonDecode(raw) as List;
      return values
          .map(
            (value) =>
                QuickPhrase.fromJson((value as Map).cast<String, dynamic>()),
          )
          .toList();
    } catch (_) {
      return <QuickPhrase>[];
    }
  }

  Future<List<QuickPhrase>> getGlobal() async {
    final all = await getAll();
    return all.where((phrase) => phrase.isGlobal).toList();
  }

  Future<List<QuickPhrase>> getForAssistant(String assistantId) async {
    final all = await getAll();
    return all
        .where(
          (phrase) => !phrase.isGlobal && phrase.assistantId == assistantId,
        )
        .toList();
  }

  Future<void> save(List<QuickPhrase> phrases) {
    return _preferences.setString(
      _phrasesKey,
      jsonEncode(phrases.map((phrase) => phrase.toJson()).toList()),
    );
  }

  Future<void> add(QuickPhrase phrase) async {
    final all = await getAll();
    all.add(phrase);
    await save(all);
  }

  Future<void> update(QuickPhrase phrase) async {
    final all = await getAll();
    final index = all.indexWhere((existing) => existing.id == phrase.id);
    if (index == -1) return;
    all[index] = phrase;
    await save(all);
  }

  Future<void> delete(String id) async {
    final all = await getAll();
    all.removeWhere((phrase) => phrase.id == id);
    await save(all);
  }

  Future<void> clear() => save(const <QuickPhrase>[]);
}
