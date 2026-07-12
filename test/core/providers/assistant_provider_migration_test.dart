import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';

import 'package:Cuplivo/core/database/app_database.dart';
import 'package:Cuplivo/core/database/chat_database_repository.dart';
import 'package:Cuplivo/core/services/chat/chat_service.dart';
import 'package:Cuplivo/core/providers/assistant_provider.dart';
import 'package:Cuplivo/core/models/assistant.dart';

/// A minimal [ChatService] subclass backed by an in-memory database.
/// Only overrides the members [AssistantProvider] actually touches.
class _InMemoryChatService extends ChatService {
  late final AppDatabase db;
  late final ChatDatabaseRepository _testRepo;

  _InMemoryChatService() {
    db = AppDatabase(NativeDatabase.memory());
    _testRepo = ChatDatabaseRepository(db);
  }

  @override
  bool get initialized => true;

  @override
  ChatDatabaseRepository get repo => _testRepo;

  @override
  Future<List<Assistant>> getAllAssistants() => _testRepo.getAllAssistants();

  @override
  Future<void> putAssistants(List<Assistant> list) =>
      _testRepo.putAssistants(list);

  Future<void> closeDb() async {
    await _testRepo.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AssistantProvider — SharedPreferences → DB migration', () {
    late _InMemoryChatService chatService;

    setUp(() {
      chatService = _InMemoryChatService();
    });

    tearDown(() async {
      await chatService.closeDb();
    });

    test(
      'migrates assistants_v1 from SharedPreferences to DB when DB empty',
      () async {
        SharedPreferences.setMockInitialValues({
          'assistants_v1': jsonEncode([
            {'id': 'a1', 'name': 'Migrated A'},
            {'id': 'a2', 'name': 'Migrated B'},
          ]),
          'current_assistant_id_v1': 'a1',
        });

        final provider = AssistantProvider(chatService: chatService);
        await provider.ensureLoaded();

        expect(provider.assistants.length, 2);
        expect(provider.assistants[0].name, 'Migrated A');
        expect(provider.currentAssistantId, 'a1');

        final fromDb = await chatService.getAllAssistants();
        expect(fromDb.length, 2);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey('assistants_v1'), isFalse);
      },
      timeout: const Timeout(Duration(seconds: 5)),
    );

    test(
      'keeps DB data when both DB and SharedPreferences have data',
      () async {
        await chatService.putAssistants([
          Assistant(id: 'db-a', name: 'DB Alpha'),
        ]);

        SharedPreferences.setMockInitialValues({
          'assistants_v1': jsonEncode([
            {'id': 'sp-a', 'name': 'SP Alpha'},
          ]),
        });

        final provider = AssistantProvider(chatService: chatService);
        await provider.ensureLoaded();

        expect(provider.assistants.length, 1);
        expect(provider.assistants[0].id, 'db-a');
      },
    );

    test('persist writes to DB when chatService is available', () async {
      SharedPreferences.setMockInitialValues({
        'assistants_v1': jsonEncode([
          {'id': 'p1', 'name': 'Persist Test'},
        ]),
      });

      final provider = AssistantProvider(chatService: chatService);
      await provider.ensureLoaded();

      await provider.updateAssistant(
        provider.assistants[0].copyWith(name: 'Persisted'),
      );

      final fromDb = await chatService.getAllAssistants();
      expect(fromDb.length, 1);
      expect(fromDb[0].name, 'Persisted');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('assistants_v1'), isFalse);
    });
  });
}
