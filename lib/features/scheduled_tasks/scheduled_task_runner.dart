import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../core/database/generation_run.dart';
import '../../core/models/chat_input_data.dart';
import '../../core/models/conversation.dart';
import '../../core/models/workspace_binding.dart';
import '../../core/models/scheduled_task.dart';
import '../../core/providers/assistant_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/mcp_provider.dart';
import '../../core/providers/workspace_provider.dart';
import '../../core/providers/world_book_provider.dart';
import '../../core/services/chat/chat_service.dart';
import '../../core/services/scheduled_tasks_service.dart';
import '../home/controllers/chat_actions.dart';
import '../home/controllers/home_view_model.dart';
import '../home/services/ask_user_interaction_service.dart';
import '../home/services/tool_approval_service.dart';

Future<Map<String, Object?>> runScheduledTask(
  BuildContext context,
  HomeViewModel viewModel,
  ScheduledTask task,
  ScheduledRunCancellation cancellation,
  Future<void> Function(String) onConversation,
) async {
  final assistants = context.read<AssistantProvider>();
  final settings = context.read<SettingsProvider>();
  final mcp = context.read<McpProvider>();
  final workspaces = context.read<WorkspaceProvider>();
  final books = context.read<WorldBookProvider>();
  final chat = context.read<ChatService>();
  final approvals = context.read<ToolApprovalService>();
  final questions = context.read<AskUserInteractionService>();
  await Future.wait([
    settings.loaded,
    mcp.loaded,
    assistants.loaded,
    workspaces.loaded,
    books.initialize(),
    chat.init(),
  ]);
  await mcp.workspaceRuntime?.initialization;
  await mcp.workspaceRuntime?.refresh();
  cancellation.check();
  final assistant = assistants.getById(task.assistantId);
  if (assistant == null) throw StateError('assistant_missing');
  Conversation? targetConversation;
  if (task.mode != ScheduledTaskMode.newChat) {
    targetConversation = chat.getConversation(task.conversationId ?? '');
    if (targetConversation == null ||
        chat.isTemporaryConversation(targetConversation.id) ||
        targetConversation.assistantId != assistant.id) {
      throw StateError('conversation_missing');
    }
  }
  final workspaceId = targetConversation == null
      ? assistant.defaultWorkspaceId
      : WorkspaceBinding.fromExtras(targetConversation.extras).workspaceId;
  if (workspaceId != null) {
    if (workspaces.byId(workspaceId) == null) {
      throw StateError('workspace_missing');
    }
    if (mcp.workspaceRuntime?.lastStatus?.ready != true) {
      throw StateError('workspace_unavailable');
    }
  }
  final modelOverride = task.modelProvider != null && task.modelId != null
      ? (providerKey: task.modelProvider!, modelId: task.modelId!)
      : null;
  if (modelOverride != null) {
    final config = settings.getProviderConfig(modelOverride.providerKey);
    if (!config.enabled || !config.models.contains(modelOverride.modelId)) {
      throw StateError('model_missing');
    }
  }
  for (final id in assistant.mcpServerIds) {
    cancellation.check();
    final server = mcp.getById(id);
    if (server == null || !server.enabled) continue;
    await mcp.connect(id);
    cancellation.check();
    // connect() starts tool discovery without waiting for the cached snapshot.
    final toolsReady = mcp.isConnected(id) && await mcp.refreshTools(id);
    cancellation.check();
    if (!toolsReady) {
      throw StateError('mcp_unavailable: ${server.name}');
    }
  }
  cancellation.check();
  if (targetConversation != null &&
      chat.getConversation(targetConversation.id)?.assistantId !=
          assistant.id) {
    throw StateError('conversation_missing');
  }
  final conversation =
      targetConversation ??
      await chat.createConversation(
        title: task.name,
        assistantId: assistant.id,
        activate: false,
      );
  await onConversation(conversation.id);
  cancellation.check();
  void onStarted(String messageId) {
    cancellation.onCancel = () => ChatActions.cancelActiveGenerationFor(
      conversation.id,
      expectedMessageId: messageId,
    );
    if (cancellation.cancelled) unawaited(cancellation.cancel());
  }

  final ChatActionResult result;
  if (task.mode == ScheduledTaskMode.regenerate) {
    final message = await chat.chatRepositoryOrNull?.getMessage(
      task.messageId ?? '',
    );
    cancellation.check();
    if (message == null ||
        message.conversationId != conversation.id ||
        message.role != 'user') {
      throw StateError('message_missing');
    }
    result = await viewModel.regenerateScheduledMessage(
      message: message,
      conversation: conversation,
      assistant: assistant,
      modelOverride: modelOverride,
      onGenerationStarted: onStarted,
    );
  } else {
    result = await viewModel.sendScheduledMessage(
      input: ChatInputData(text: task.prompt),
      conversation: conversation,
      assistant: assistant,
      modelOverride: modelOverride,
      onGenerationStarted: onStarted,
    );
  }
  if (cancellation.cancelled) await cancellation.cancel();
  cancellation.check();
  if (!result.success) {
    throw StateError(result.errorMessage ?? 'generation_failed');
  }
  final repository = chat.chatRepositoryOrNull!;
  final runId = result.generationRunId;
  if (runId == null) throw StateError('generation_run_missing');
  final deadline = DateTime.now().add(const Duration(minutes: 9));
  while (true) {
    cancellation.check();
    final run = await repository.getGenerationRun(runId);
    if (run == null) throw StateError('generation_run_missing');
    if (run.state.isTerminal) {
      final message = await repository.getMessage(result.assistantMessage!.id);
      return {
        'conversationId': conversation.id,
        'status': run.state == GenerationRunState.completed
            ? 'completed'
            : 'failed',
        'preview': (message?.content ?? '').characters.take(200).toString(),
        if (run.errorCode != null) 'error': run.errorCode,
      };
    }
    // Preserve tool approval rules. Unattended runs cannot answer for the user.
    if (approvals.pendingRequests.any(
          (r) => r.conversationId == conversation.id,
        ) ||
        questions.pendingRequests.values.any(
          (r) => r.conversationId == conversation.id,
        )) {
      throw StateError('user_interaction_required');
    }
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('execution_timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
}
