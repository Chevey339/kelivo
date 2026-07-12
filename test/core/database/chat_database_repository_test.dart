import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:Cuplivo/core/database/app_database.dart';
import 'package:Cuplivo/core/database/chat_database_repository.dart';
import 'package:Cuplivo/core/models/assistant.dart';
import 'package:Cuplivo/core/models/assistant_regex.dart';
import 'package:Cuplivo/core/models/preset_message.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatDatabaseRepository — AssistantRows', () {
    late AppDatabase db;
    late ChatDatabaseRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = ChatDatabaseRepository(db);
    });

    tearDown(() async {
      await repo.close();
    });

    test('putAssistants and getAllAssistants round-trip', () async {
      final assistants = [
        Assistant(id: 'a1', name: 'Alpha', systemPrompt: 'Be helpful'),
        Assistant(
          id: 'a2',
          name: 'Beta',
          temperature: 0.5,
          searchEnabled: true,
          mcpServerIds: ['mcp-1', 'mcp-2'],
        ),
      ];

      await repo.putAssistants(assistants);
      final loaded = await repo.getAllAssistants();

      expect(loaded.length, 2);
      expect(loaded[0].id, 'a1');
      expect(loaded[0].name, 'Alpha');
      expect(loaded[0].systemPrompt, 'Be helpful');
      expect(loaded[1].id, 'a2');
      expect(loaded[1].temperature, 0.5);
      expect(loaded[1].searchEnabled, isTrue);
      expect(loaded[1].mcpServerIds, ['mcp-1', 'mcp-2']);
    });

    test('putAssistant updates existing row', () async {
      final a = Assistant(id: 'x1', name: 'Original');
      await repo.putAssistants([a]);

      final updated = a.copyWith(name: 'Updated Name');
      await repo.putAssistant(updated);
      final loaded = await repo.getAllAssistants();

      expect(loaded.length, 1);
      expect(loaded[0].name, 'Updated Name');
    });

    test('deleteAssistant removes row', () async {
      await repo.putAssistants([
        Assistant(id: 'a1', name: 'A'),
        Assistant(id: 'a2', name: 'B'),
      ]);

      await repo.deleteAssistant('a1');
      final loaded = await repo.getAllAssistants();

      expect(loaded.length, 1);
      expect(loaded[0].id, 'a2');
    });

    test('putAssistants replaces all rows', () async {
      await repo.putAssistants([
        Assistant(id: 'a1', name: 'A'),
        Assistant(id: 'a2', name: 'B'),
      ]);

      await repo.putAssistants([Assistant(id: 'a3', name: 'C')]);

      final loaded = await repo.getAllAssistants();
      expect(loaded.length, 1);
      expect(loaded[0].id, 'a3');
    });

    test('getAssistant returns single by id', () async {
      await repo.putAssistants([
        Assistant(id: 'a1', name: 'A'),
        Assistant(id: 'a2', name: 'B'),
      ]);

      final a = await repo.getAssistant('a2');
      expect(a, isNotNull);
      expect(a!.name, 'B');

      final missing = await repo.getAssistant('not-exist');
      expect(missing, isNull);
    });

    test('getAssistantCount returns correct count', () async {
      expect(await repo.getAssistantCount(), 0);

      await repo.putAssistants([
        Assistant(id: 'a1', name: 'A'),
        Assistant(id: 'a2', name: 'B'),
      ]);
      expect(await repo.getAssistantCount(), 2);
    });

    test(
      'putAssistants and getAllAssistants round-trip with all JSON fields',
      () async {
        final presetMsg = PresetMessage(
          role: 'user',
          content: 'hello',
          id: 'p1',
        );
        final regexRule = AssistantRegex(
          id: 'r1',
          name: 'rule1',
          pattern: r'\d+',
          replacement: 'N',
        );
        final assistant = Assistant(
          id: 'full',
          name: 'Full',
          presetMessages: [presetMsg],
          regexRules: [regexRule],
          customHeaders: [
            {'name': 'X-Test', 'value': 'test'},
          ],
          customBody: [
            {'key': 'bodyKey', 'value': 'bodyVal'},
          ],
          mcpServerIds: ['mcp-1'],
          localToolIds: ['tool-1'],
        );

        await repo.putAssistants([assistant]);
        final loaded = await repo.getAllAssistants();

        expect(loaded.length, 1);
        final a = loaded[0];
        expect(a.id, 'full');
        expect(a.presetMessages.length, 1);
        expect(a.presetMessages[0].id, 'p1');
        expect(a.presetMessages[0].role, 'user');
        expect(a.presetMessages[0].content, 'hello');
        expect(a.regexRules.length, 1);
        expect(a.regexRules[0].id, 'r1');
        expect(a.regexRules[0].pattern, r'\d+');
        expect(a.regexRules[0].replacement, 'N');
        expect(a.customHeaders, [
          {'name': 'X-Test', 'value': 'test'},
        ]);
        expect(a.customBody, [
          {'key': 'bodyKey', 'value': 'bodyVal'},
        ]);
        expect(a.mcpServerIds, ['mcp-1']);
        expect(a.localToolIds, ['tool-1']);
      },
    );
  });

  group('ChatDatabaseRepository — CacheRows', () {
    late AppDatabase db;
    late ChatDatabaseRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = ChatDatabaseRepository(db);
    });

    tearDown(() async {
      await repo.close();
    });

    test('putCacheEntry and getCacheEntry round-trip', () async {
      await repo.putCacheEntry('ocr', 'path/to/img.png', 'text content');

      final entry = await repo.getCacheEntry('ocr', 'path/to/img.png');
      expect(entry, isNotNull);
      expect(entry!.value, 'text content');
      expect(entry.updatedAt, isNotNull);
    });

    test('getCacheEntry returns null for missing key', () async {
      final entry = await repo.getCacheEntry('ocr', 'nonexistent');
      expect(entry, isNull);
    });

    test('putCacheEntry upserts same key', () async {
      await repo.putCacheEntry('ocr', 'k', 'v1');
      await repo.putCacheEntry('ocr', 'k', 'v2');

      final entry = await repo.getCacheEntry('ocr', 'k');
      expect(entry!.value, 'v2');
    });

    test('same key different type are independent', () async {
      await repo.putCacheEntry('ocr', 'k', 'ocr-value');

      final entry = await repo.getCacheEntry('translate', 'k');
      expect(entry, isNull);
    });

    test('deleteCacheEntry removes row', () async {
      await repo.putCacheEntry('ocr', 'img1', 'text1');
      await repo.putCacheEntry('ocr', 'img2', 'text2');

      await repo.deleteCacheEntry('ocr', 'img1');

      expect(await repo.getCacheEntry('ocr', 'img1'), isNull);
      expect(await repo.getCacheEntry('ocr', 'img2'), isNotNull);
    });

    test('clearCacheByType removes all rows for type', () async {
      await repo.putCacheEntry('ocr', 'img1', 't1');
      await repo.putCacheEntry('ocr', 'img2', 't2');
      await repo.putCacheEntry('other', 'k', 'v');

      await repo.clearCacheByType('ocr');

      expect(await repo.getCacheEntry('ocr', 'img1'), isNull);
      expect(await repo.getCacheEntry('ocr', 'img2'), isNull);
      expect(await repo.getCacheEntry('other', 'k'), isNotNull);
    });
  });
}
