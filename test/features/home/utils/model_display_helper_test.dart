import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/home/utils/model_display_helper.dart';

import '../../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsProvider settings;

  setUp(() async {
    settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    await settings.setCurrentModel('GlobalProvider', 'global-model');
  });

  Assistant assistantWithModel({String? providerKey, String? modelId}) =>
      Assistant(
        id: 'assistant',
        name: 'Assistant',
        chatModelProvider: providerKey,
        chatModelId: modelId,
      );

  Conversation conversationWithModel({String? providerKey, String? modelId}) =>
      Conversation(
        title: 'Chat',
        chatModelProvider: providerKey,
        chatModelId: modelId,
      );

  test('per-chat models default to off', () {
    expect(settings.perChatModelEnabled, isFalse);
  });

  test('falls back to the global default when nothing overrides it', () {
    final resolved = resolveChatModel(
      settings,
      conversation: conversationWithModel(),
      assistant: assistantWithModel(),
    );

    expect(resolved.providerKey, 'GlobalProvider');
    expect(resolved.modelId, 'global-model');
  });

  test('the assistant outranks the global default', () {
    final resolved = resolveChatModel(
      settings,
      conversation: conversationWithModel(),
      assistant: assistantWithModel(
        providerKey: 'AssistantProvider',
        modelId: 'assistant-model',
      ),
    );

    expect(resolved.providerKey, 'AssistantProvider');
    expect(resolved.modelId, 'assistant-model');
  });

  test('the conversation outranks the assistant when enabled', () async {
    await settings.setPerChatModelEnabled(true);

    final resolved = resolveChatModel(
      settings,
      conversation: conversationWithModel(
        providerKey: 'ConversationProvider',
        modelId: 'conversation-model',
      ),
      assistant: assistantWithModel(
        providerKey: 'AssistantProvider',
        modelId: 'assistant-model',
      ),
    );

    expect(resolved.providerKey, 'ConversationProvider');
    expect(resolved.modelId, 'conversation-model');
  });

  test('a conversation without an override follows the assistant', () {
    final resolved = resolveChatModel(
      settings,
      conversation: conversationWithModel(),
      assistant: assistantWithModel(
        providerKey: 'AssistantProvider',
        modelId: 'assistant-model',
      ),
    );

    expect(resolved.providerKey, 'AssistantProvider');
  });

  test('a null conversation resolves as before this feature', () {
    final resolved = resolveChatModel(
      settings,
      assistant: assistantWithModel(
        providerKey: 'AssistantProvider',
        modelId: 'assistant-model',
      ),
    );

    expect(resolved.providerKey, 'AssistantProvider');
    expect(resolved.modelId, 'assistant-model');
  });

  test(
    'the conversation layer is skipped when per-chat models are off',
    () async {
      await settings.setPerChatModelEnabled(false);

      final resolved = resolveChatModel(
        settings,
        conversation: conversationWithModel(
          providerKey: 'ConversationProvider',
          modelId: 'conversation-model',
        ),
        assistant: assistantWithModel(
          providerKey: 'AssistantProvider',
          modelId: 'assistant-model',
        ),
      );

      expect(resolved.providerKey, 'AssistantProvider');
      expect(resolved.modelId, 'assistant-model');
    },
  );

  test('turning per-chat models back on restores the pin', () async {
    final conversation = conversationWithModel(
      providerKey: 'ConversationProvider',
      modelId: 'conversation-model',
    );
    final assistant = assistantWithModel(
      providerKey: 'AssistantProvider',
      modelId: 'assistant-model',
    );

    await settings.setPerChatModelEnabled(false);
    await settings.setPerChatModelEnabled(true);

    final resolved = resolveChatModel(
      settings,
      conversation: conversation,
      assistant: assistant,
    );

    expect(resolved.providerKey, 'ConversationProvider');
    expect(resolved.modelId, 'conversation-model');
  });

  test('getActiveModelIds and getModelDisplayInfo agree with it', () async {
    await settings.setPerChatModelEnabled(true);

    final conversation = conversationWithModel(
      providerKey: 'ConversationProvider',
      modelId: 'conversation-model',
    );
    final assistant = assistantWithModel(
      providerKey: 'AssistantProvider',
      modelId: 'assistant-model',
    );

    final ids = getActiveModelIds(
      settings,
      conversation: conversation,
      assistant: assistant,
    );
    final display = getModelDisplayInfo(
      settings,
      conversation: conversation,
      assistant: assistant,
    );

    expect(ids.providerKey, 'ConversationProvider');
    expect(ids.modelId, 'conversation-model');
    expect(display.providerKey, 'ConversationProvider');
    expect(display.modelId, 'conversation-model');
    expect(display.isConfigured, isTrue);
  });
}
