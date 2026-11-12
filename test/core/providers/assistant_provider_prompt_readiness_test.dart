import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/database/business_data.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/services/chat/prompt_transformer.dart';

import '../../support/business_preferences_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BusinessPreferencesTestHarness harness;
  late BusinessPreferencesTestSession session;

  setUp(() async {
    harness = await BusinessPreferencesTestHarness.create();
    session = await harness.open();
  });

  tearDown(() => harness.dispose());

  test(
    'restores prompt templates synchronously from the startup snapshot',
    () async {
      await session.preferences.setString(
        'assistants_v1',
        jsonEncode(const [
          {
            'id': 'assistant-with-prompts',
            'name': 'Prompt Assistant',
            'systemPrompt': 'Current: {cur_datetime}',
            'messageTemplate': '{{ date }} {{ time }} {{ message }}',
          },
        ]),
      );
      await session.preferences.setString(
        'current_assistant_id_v1',
        'assistant-with-prompts',
      );

      final provider = AssistantProvider(preferences: session.preferences);

      expect(provider.currentAssistantId, 'assistant-with-prompts');
      expect(
        provider.currentAssistant?.systemPrompt,
        'Current: {cur_datetime}',
      );
      expect(
        provider.currentAssistant?.messageTemplate,
        '{{ date }} {{ time }} {{ message }}',
      );
      expect(
        PromptTransformer.replacePlaceholders(
          provider.currentAssistant!.systemPrompt,
          const {'{cur_datetime}': '2026-07-19 09:30'},
        ),
        'Current: 2026-07-19 09:30',
      );
      expect(
        PromptTransformer.applyMessageTemplate(
          provider.currentAssistant!.messageTemplate,
          role: 'user',
          message: 'hello',
          now: DateTime(2026, 7, 19, 9, 30),
        ),
        '2026-07-19 09:30 hello',
      );
      await provider.loaded;
    },
  );

  test('ignores a non-string persisted current assistant id', () async {
    await session.preferences.setString(
      'assistants_v1',
      jsonEncode(const [
        {'id': 'assistant-a', 'name': 'Assistant A'},
      ]),
    );
    await session.preferences.setBool('current_assistant_id_v1', true);

    final provider = AssistantProvider(preferences: session.preferences);

    await expectLater(provider.loaded, completes);
    expect(provider.currentAssistantId, 'assistant-a');
    expect(provider.currentAssistant?.id, 'assistant-a');
  });

  test('failed assistant loading cannot seed replacement default IDs', () async {
    final repository = BusinessRepository(session.database);
    final source = jsonEncode({
      'id': 'original-id',
      'name': 'Original',
      'useGradientBackground': 'true',
    });
    await repository.replaceEntities(BusinessEntityKind.assistant, [
      BusinessEntityValue(id: 'original-id', sortOrder: 0, payload: source),
    ]);
    final provider = AssistantProvider(
      preferences: BusinessPreferences(repository),
    );
    await expectLater(provider.loaded, throwsFormatException);
    // Loading must fail before localization or the default UUID generator is
    // reached, even if a caller still asks to initialize the default assistants.
    await expectLater(provider.ensureDefaults(null), throwsFormatException);
    final stored = await repository.readEntities(BusinessEntityKind.assistant);
    expect(stored.single.id, 'original-id');
    expect(stored.single.payload, source);
    provider.dispose();
  });

  test(
    'missing selection uses the displayed assistant for new chats',
    () async {
      await session.preferences.setString(
        'assistants_v1',
        jsonEncode(const [
          {'id': 'assistant-a', 'name': 'Assistant A'},
          {'id': 'assistant-b', 'name': 'Assistant B'},
        ]),
      );
      await session.preferences.setString('current_assistant_id_v1', 'removed');
      final provider = AssistantProvider(preferences: session.preferences);
      await provider.loaded;

      expect(provider.currentAssistantId, provider.currentAssistant!.id);
      await provider.setCurrentAssistant('assistant-b');
      await provider.setCurrentAssistant('removed');
      expect(provider.currentAssistantId, 'assistant-b');
      expect(provider.currentAssistant!.id, 'assistant-b');
      expect(
        session.preferences.getString('current_assistant_id_v1'),
        'assistant-b',
      );
    },
  );

  test(
    'conversation ownership stays independent of the selected assistant',
    () async {
      await session.preferences.setString(
        'assistants_v1',
        jsonEncode(const [
          {'id': 'assistant-a', 'name': 'Assistant A'},
          {'id': 'assistant-b', 'name': 'Assistant B'},
        ]),
      );
      final provider = AssistantProvider(preferences: session.preferences);
      await provider.loaded;
      await provider.setCurrentAssistant('assistant-b');

      expect(provider.resolveConversationAssistant(null)!.id, 'assistant-b');
      expect(
        provider.resolveConversationAssistant('assistant-b')!.id,
        'assistant-b',
      );
      expect(
        provider.resolveConversationAssistant('assistant-a')!.id,
        'assistant-a',
      );
      expect(
        provider.resolveConversationAssistant('missing')!.id,
        'assistant-a',
      );
      expect(provider.resolveConversationAssistant('')!.id, 'assistant-a');
      expect(provider.getById('missing'), isNull);
    },
  );

  for (final savedRecovery in <Object?>[null, 'removed', true]) {
    test(
      'recovery identity survives reorder and restart: $savedRecovery',
      () async {
        await session.preferences.setString(
          'assistants_v1',
          jsonEncode(const [
            {'id': 'assistant-a', 'name': 'Assistant A'},
            {'id': 'assistant-b', 'name': 'Assistant B'},
          ]),
        );
        const recoveryKey = 'orphaned_conversations_assistant_id_v1';
        if (savedRecovery is String) {
          await session.preferences.setString(recoveryKey, savedRecovery);
          await session.preferences.setString(
            'current_assistant_id_v1',
            savedRecovery,
          );
        } else if (savedRecovery is bool) {
          await session.preferences.setBool(recoveryKey, savedRecovery);
          await session.preferences.setBool(
            'current_assistant_id_v1',
            savedRecovery,
          );
        }
        final provider = AssistantProvider(preferences: session.preferences);
        await provider.loaded;
        await provider.setCurrentAssistant('assistant-a');
        await provider.reorderAssistantsWithin(
          subsetIds: ['assistant-a', 'assistant-b'],
          oldIndex: 1,
          newIndex: 0,
        );
        expect(
          provider.resolveConversationAssistant('missing')!.id,
          'assistant-a',
        );
        provider.dispose();
        await session.close();

        session = await harness.open();
        final reopened = AssistantProvider(preferences: session.preferences);
        await reopened.loaded;
        expect(reopened.assistants.first.id, 'assistant-b');
        expect(reopened.currentAssistantId, 'assistant-a');
        expect(
          reopened.resolveConversationAssistant('missing')!.id,
          'assistant-a',
        );
        await reopened.updateAssistant(
          reopened.currentAssistant!.copyWith(chatModelId: 'updated-model'),
        );
        expect(
          reopened.resolveConversationAssistant('missing')!.chatModelId,
          'updated-model',
        );
        await reopened.deleteAssistant('assistant-a');
        expect(
          reopened.resolveConversationAssistant('missing')!.id,
          'assistant-b',
        );
        reopened.dispose();
        await session.close();

        session = await harness.open();
        final afterDeletion = AssistantProvider(
          preferences: session.preferences,
        );
        await afterDeletion.loaded;
        expect(afterDeletion.currentAssistantId, 'assistant-b');
        expect(
          afterDeletion.resolveConversationAssistant('missing')!.id,
          'assistant-b',
        );
        afterDeletion.dispose();
      },
    );
  }

  test(
    'first added assistant remains the recovery assistant after reorder',
    () async {
      final provider = AssistantProvider(preferences: session.preferences);
      await provider.loaded;
      expect(provider.resolveConversationAssistant('missing'), isNull);
      final first = await provider.addAssistant(name: 'First');
      await provider.addAssistant(name: 'Second');
      await provider.reorderAssistants(1, 0);
      expect(provider.resolveConversationAssistant('missing')!.id, first);
      provider.dispose();
      await session.close();
      session = await harness.open();
      final reopened = AssistantProvider(preferences: session.preferences);
      await reopened.loaded;
      expect(reopened.resolveConversationAssistant('missing')!.id, first);
      reopened.dispose();
    },
  );
}
