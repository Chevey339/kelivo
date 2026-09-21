import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/assistant.dart';
import '../models/auto_retry_options.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../models/scheduled_task.dart';
import '../models/scheduled_task_payload.dart';
import '../providers/assistant_provider.dart';
import '../providers/settings_provider.dart';
import 'api/chat_api_service.dart';
import 'chat/chat_service.dart';
import 'scheduled_task_preparation.dart';
import 'scheduled_tasks_service.dart';
import '../../features/home/utils/model_display_helper.dart';
import '../../features/chat/utils/thinking_tag_parser.dart';

typedef ScheduledTextContextBuilder =
    Future<List<Map<String, dynamic>>> Function(
      ScheduledTask task,
      Assistant assistant,
      Conversation? conversation,
      String modelId,
    );

/// A text-only, detached computation. No UI, chat writes, tools, or attachments.
class ScheduledTaskTextExecutor implements ScheduledTaskPreparation {
  ScheduledTaskTextExecutor({
    required this.chat,
    required this.assistants,
    required this.settings,
    required this.buildContext,
    required this.busy,
    required this.promptConfiguration,
    this.onPublished,
  });
  final ChatService chat;
  final AssistantProvider assistants;
  final SettingsProvider settings;
  final ScheduledTextContextBuilder buildContext;
  final bool Function(String?) busy;
  final FutureOr<Object?> Function(String assistantId) promptConfiguration;
  final Future<void> Function(String conversationId)? onPublished;

  Assistant _assistant(ScheduledTask task) {
    final assistant = assistants.getById(task.assistantId);
    if (assistant == null) throw StateError('assistant_missing');
    return assistant;
  }

  Conversation? _conversation(ScheduledTask task) {
    if (task.mode == ScheduledTaskMode.newChat) return null;
    final conversation = chat.getConversation(task.conversationId ?? '');
    if (conversation == null ||
        conversation.assistantId != task.assistantId ||
        chat.isTemporaryConversation(conversation.id)) {
      throw StateError('conversation_missing');
    }
    return conversation;
  }

  ({String providerKey, String modelId}) _model(
    ScheduledTask task,
    Assistant assistant,
    Conversation? conversation,
  ) {
    final inherited = resolveChatModel(
      settings,
      assistant: assistant,
      conversation: conversation,
    );
    final providerKey = task.modelProvider ?? inherited.providerKey;
    final modelId = task.modelId ?? inherited.modelId;
    if (providerKey == null || modelId == null) {
      throw StateError('model_missing');
    }
    final config = settings.getProviderConfig(providerKey);
    if (!config.enabled || !config.models.contains(modelId)) {
      throw StateError('model_missing');
    }
    return (providerKey: providerKey, modelId: modelId);
  }

  @override
  Future<String> revision(ScheduledTask task) async {
    final assistant = _assistant(task);
    final conversation = _conversation(task);
    final model = _model(task, assistant, conversation);
    final chatRevision = conversation == null
        ? null
        : await chat.chatRepositoryOrNull!.scheduledContextRevision(
            conversation.id,
          );
    if (conversation != null && chatRevision == null) {
      throw StateError('conversation_missing');
    }
    final config = sha256
        .convert(
          utf8.encode(
            jsonEncode({
              'assistant': assistant.toJson(),
              'model': [model.providerKey, model.modelId],
              'provider': {
                'baseUrl': settings
                    .getProviderConfig(model.providerKey)
                    .baseUrl,
                'model': settings
                    .getProviderConfig(model.providerKey)
                    .modelOverrides[model.modelId],
              },
              if (conversation == null)
                'newConversationExtras': chat.newConversationExtras?.call(
                  assistant.id,
                ),
              'prompts': await promptConfiguration(assistant.id),
            }),
          ),
        )
        .toString();
    return jsonEncode({'chat': chatRevision, 'config': config});
  }

  @override
  bool sameConfiguration(String before, String after) =>
      (jsonDecode(before) as Map)['config'] ==
      (jsonDecode(after) as Map)['config'];

  @override
  bool isBusy(ScheduledTask task) => busy(task.conversationId);

  @override
  Future<ScheduledTaskPayload> prepare(
    ScheduledTask task,
    ScheduledTaskRun run,
    ScheduledRunCancellation cancellation,
  ) async {
    if (!task.canPrepare) throw StateError('preparation_not_allowed');
    if (isBusy(task)) throw StateError('in_flight');
    final assistant = _assistant(task);
    final conversation = _conversation(task);
    final model = _model(task, assistant, conversation);
    final before = await revision(task);
    final messages = await buildContext(
      task,
      assistant,
      conversation,
      model.modelId,
    );
    cancellation.check();
    if (before != await revision(task)) {
      throw StateError('scheduled_context_changed');
    }
    final preparationPrompt = task.preparationPrompt
        .replaceAll('{{scheduled_time}}', run.scheduledFor!.toIso8601String())
        .replaceAll(
          '{{utc_offset}}',
          run.scheduledFor!.timeZoneOffset.toString(),
        )
        .trim();
    if (preparationPrompt.isNotEmpty) {
      messages.add({'role': 'system', 'content': preparationPrompt});
    }
    messages.add({'role': 'user', 'content': task.prompt});
    final requestId = '${run.id}:prepare:${run.prepareAttempts}';
    cancellation.onCancel = () async => ChatApiService.cancelRequest(requestId);
    cancellation.check();
    final response = await ChatApiService.generateMessage(
      config: settings.getProviderConfig(model.providerKey),
      modelId: model.modelId,
      messages: messages,
      requestId: requestId,
      conversationId: conversation?.id,
      temperature: assistant.temperature,
      topP: assistant.topP,
      thinkingBudget: assistant.thinkingBudget,
      maxTokens: (assistant.maxTokens ?? 4096).clamp(1, 4096),
      extraHeaders: {
        for (final h in assistant.customHeaders) h['name']!: h['value']!,
      },
      textOnly: true,
      retryOverride: const AutoRetryOptions.defaults(),
    );
    cancellation.check();
    final text = ThinkingTagParser.parseWithRanges(
      response.text,
    ).visibleContent.trim();
    if (text.isEmpty) throw StateError('empty_preparation');
    return ScheduledTaskPayload(
      text: text,
      title: assistant.name,
      conversationId: conversation?.id ?? '${run.id}:chat',
      messageId: '${run.id}:result',
      contextRevision: before,
      providerId: model.providerKey,
      modelId: model.modelId,
      totalTokens: response.usage?.totalTokens,
    );
  }

  @override
  Future<String> publish(
    ScheduledTask task,
    ScheduledTaskRun run,
    ScheduledTaskPayload payload,
  ) async {
    // Freeze the delivered body, not the existence of its owner and target.
    _assistant(task);
    final conversation =
        _conversation(task) ??
        Conversation(
          id: payload.conversationId,
          title: task.name,
          assistantId: task.assistantId,
          createdAt: run.scheduledFor,
          updatedAt: run.scheduledFor,
          extras:
              chat.newConversationExtras?.call(task.assistantId) ?? const {},
        );
    await chat.publishScheduledMessages(
      conversation: conversation,
      createConversation: task.mode == ScheduledTaskMode.newChat,
      // The coordinator validates latest-context results before their due
      // time. Publication then restores that same, frozen notification body.
      instruction: ChatMessage(
        id: '${run.id}:instruction',
        conversationId: conversation.id,
        role: 'user',
        content: task.prompt,
        timestamp: run.scheduledFor,
      ),
      response: ChatMessage(
        id: payload.messageId,
        conversationId: conversation.id,
        role: 'assistant',
        content: payload.text,
        timestamp: run.scheduledFor,
        providerId: payload.providerId,
        modelId: payload.modelId,
        totalTokens: payload.totalTokens,
      ),
    );
    await onPublished?.call(conversation.id);
    return conversation.id;
  }
}
