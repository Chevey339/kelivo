import '../models/quick_phrase.dart';
import 'json_blob_store.dart';

class QuickPhraseStore extends JsonBlobStore<QuickPhrase> {
  QuickPhraseStore(super._preferences);

  static const String _phrasesKey = 'quick_phrases_v1';

  @override
  String get storageKey => _phrasesKey;

  @override
  QuickPhrase decodeItem(Map<String, dynamic> json) =>
      QuickPhrase.fromJson(json);

  @override
  Map<String, dynamic> encodeItem(QuickPhrase item) => item.toJson();

  Future<List<QuickPhrase>> getAll() => readAll();

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
    return runExclusive(() => writeAll(phrases));
  }

  Future<void> add(QuickPhrase phrase) {
    return runExclusive(() async {
      final all = await readAll();
      all.add(phrase);
      await writeAll(all);
    });
  }

  Future<void> update(QuickPhrase phrase) {
    return runExclusive(() async {
      final all = await readAll();
      final index = all.indexWhere((existing) => existing.id == phrase.id);
      if (index == -1) return;
      all[index] = phrase;
      await writeAll(all);
    });
  }

  Future<void> delete(String id) {
    return runExclusive(() async {
      final all = await readAll();
      all.removeWhere((phrase) => phrase.id == id);
      await writeAll(all);
    });
  }

  Future<void> clear() => save(const <QuickPhrase>[]);
}
