import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';

/// Conversation extras applied when starting a chat with [assistant].
Map<String, dynamic> workspaceExtrasForNewConversation({
  required Assistant? assistant,
  required Workspace? Function(String id) workspaceById,
}) {
  final workspaceId = assistant?.defaultWorkspaceId;
  if (workspaceId == null || workspaceId.isEmpty) {
    return const <String, dynamic>{};
  }
  final workspace = workspaceById(workspaceId);
  if (workspace == null) {
    return const <String, dynamic>{};
  }
  return WorkspaceBinding(
    workspaceId: workspace.id,
    cwd: workspace.defaultCwd,
  ).applyTo({});
}

typedef WorkspaceDefaultNotice = ({
  Assistant assistant,
  bool automaticallyRemembered,
});

/// Binds the conversation and handles the assistant's one-time default setup.
Future<WorkspaceDefaultNotice?> bindConversationWorkspace(
  ChatService chat, {
  required AssistantProvider assistants,
  required String conversationId,
  required Workspace workspace,
}) async {
  await assistants.loaded;
  await chat.updateConversationExtras(
    conversationId,
    WorkspaceBinding(
      workspaceId: workspace.id,
      cwd: workspace.defaultCwd,
    ).applyTo,
  );
  final conversation = chat.getConversation(conversationId);
  if (conversation == null ||
      chat.isTemporaryConversation(conversationId) ||
      WorkspaceBinding.fromExtras(conversation.extras).workspaceId !=
          workspace.id) {
    return null;
  }
  final assistantId = conversation.assistantId;
  final assistant = assistantId == null
      ? null
      : assistants.getById(assistantId);
  if (assistant == null ||
      (assistant.defaultWorkspaceId?.isNotEmpty ?? false) ||
      assistant.defaultWorkspaceSetup == DefaultWorkspaceSetup.completed) {
    return null;
  }
  final automaticallyRemembered =
      assistant.defaultWorkspaceSetup == DefaultWorkspaceSetup.automatic;
  final updated = assistant.copyWith(
    defaultWorkspaceId: automaticallyRemembered ? workspace.id : null,
    defaultWorkspaceSetup: DefaultWorkspaceSetup.completed,
  );
  await assistants.updateAssistant(updated);
  return (assistant: updated, automaticallyRemembered: automaticallyRemembered);
}

/// Clears [Assistant.defaultWorkspaceId] on every assistant bound to [workspaceId].
Future<void> clearAssistantDefaultsForDeletedWorkspace(
  AssistantProvider assistants, {
  required String workspaceId,
}) async {
  for (final assistant in List<Assistant>.of(assistants.assistants)) {
    if (assistant.defaultWorkspaceId == workspaceId) {
      await assistants.updateAssistant(
        assistant.copyWith(clearDefaultWorkspaceId: true),
      );
    }
  }
}
