import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';

import 'package:Cuplivo/core/database/app_database.dart';
import 'package:Cuplivo/core/database/chat_database_repository.dart';
import 'package:Cuplivo/core/services/chat/chat_service.dart';
import 'package:Cuplivo/core/models/assistant.dart';
import 'package:Cuplivo/core/providers/assistant_provider.dart';

const _assistantsKey = 'assistants_v1';
const _currentAssistantKey = 'current_assistant_id_v1';

class _MockChatService extends ChatService {
  @override
  final ChatDatabaseRepository repo;
  _MockChatService(this.repo);

  @override
  bool get initialized => true;
}

Future<AssistantProvider> _createProviderWithLoadedAssistants(
  List<Map<String, Object?>> assistants, {
  String? currentAssistantId,
}) async {
  // Mock path_provider so AppDatabase(NativeDatabase.memory()) works in tests.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return Directory.systemTemp.path;
          }
          return null;
        },
      );

  final db = AppDatabase(NativeDatabase.memory());
  final repo = ChatDatabaseRepository(db);
  await repo.putAssistants(
    assistants
        .map((json) => Assistant.fromJson(json.cast<String, dynamic>()))
        .toList(),
  );

  SharedPreferences.setMockInitialValues({
    if (currentAssistantId != null) _currentAssistantKey: currentAssistantId,
  });

  final provider = AssistantProvider(chatService: _MockChatService(repo));
  await provider.ensureLoaded();
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Assistant deletable field migration', () {
    test('does not export deletable in assistant JSON', () {
      final assistant = Assistant(id: 'assistant-1', name: 'Assistant 1');

      expect(assistant.toJson(), isNot(contains('deletable')));
      expect(Assistant.encodeList([assistant]), isNot(contains('deletable')));
    });

    test('ignores legacy deletable field and persists without it', () async {
      final provider = await _createProviderWithLoadedAssistants(const [
        {'id': 'legacy-default', 'name': 'Legacy Default', 'deletable': false},
        {'id': 'regular', 'name': 'Regular Assistant', 'deletable': true},
      ], currentAssistantId: 'legacy-default');

      expect(provider.assistants.map((a) => a.id), [
        'legacy-default',
        'regular',
      ]);

      expect(await provider.deleteAssistant('legacy-default'), isTrue);
      expect(provider.currentAssistantId, 'regular');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_assistantsKey), isNot(contains('deletable')));
    });

    test(
      'keeps the last remaining assistant undeletable by count only',
      () async {
        final provider = await _createProviderWithLoadedAssistants(const [
          {'id': 'only-assistant', 'name': 'Only Assistant', 'deletable': true},
        ], currentAssistantId: 'only-assistant');

        expect(await provider.deleteAssistant('only-assistant'), isFalse);
        expect(provider.assistants.map((a) => a.id), ['only-assistant']);
      },
    );
  });
}
