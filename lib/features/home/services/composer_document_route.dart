import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/models/assistant.dart';
import '../../../core/models/chat_input_data.dart';
import '../../../core/models/conversation.dart';
import '../../../core/models/conversation_mcp_settings.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/models/workspace_binding.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/mcp_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/workspace_provider.dart';
import '../../../core/services/api/builtin_tools.dart' show BuiltInToolsHelper;
import '../../../core/services/mcp/mcp_tool_service.dart';
import '../../../core/services/chat/document_text_extractor.dart';
import '../../../core/services/model_spec/model_spec_resolver.dart';
import '../../../core/utils/multimodal_input_utils.dart';
import 'built_in_tool_names.dart';

typedef ComposerDocumentRoute = ({
  bool workspaceBound,
  bool workspaceFiles,
  bool nativePdf,
  bool sandboxData,
});
const regularDocumentRoute = (
  workspaceBound: false,
  workspaceFiles: false,
  nativePdf: false,
  sandboxData: false,
);

/// Timeline notifications should not rebuild the composer on each token.
/// Observe only conversation fields that change the attachment/model route.
Conversation? watchComposerConversation(
  BuildContext context,
  Conversation? selected,
) {
  if (selected == null) return null;
  final id = selected.id;
  context.select<ChatService, List<Object?>>((chat) {
    final c = chat.getConversation(id);
    return [
      c?.assistantId,
      c?.chatModelProvider,
      c?.chatModelId,
      c?.extras[WorkspaceBinding.keyId],
      ConversationMcpSettings.isOverridden(c),
      ...?c?.mcpServerIds,
    ];
  });
  return context.read<ChatService>().getConversation(id) ?? selected;
}

ComposerDocumentRoute resolveComposerDocumentRoute(
  BuildContext context, {
  required Conversation? conversation,
  required SettingsProvider settings,
  required Assistant? assistant,
  required ({String? providerKey, String? modelId}) model,
  bool listen = false,
}) {
  final id = WorkspaceBinding.fromExtras(
    conversation?.extras ?? const {},
  ).workspaceId;
  final workspace = id == null
      ? null
      : Provider.of<WorkspaceProvider?>(context, listen: listen)?.byId(id);
  final cfg = model.providerKey == null || model.modelId == null
      ? null
      : settings
            .getProviderConfig(model.providerKey!)
            .forModelProtocol(model.modelId!);
  final spec = cfg == null || model.modelId == null
      ? null
      : ModelSpecResolver.instance.spec(cfg, model.modelId!);
  var sandbox = BuiltInToolsHelper.sendsDataFilesToSandbox(
    cfg: cfg,
    modelId: model.modelId,
  );
  // An MCP function with the same exposed name displaces Claude's hosted tool.
  if (sandbox && spec?.supportsTool == true) {
    final mcp = Provider.of<McpProvider?>(context, listen: listen);
    final tools = Provider.of<McpToolService?>(context, listen: listen);
    if (mcp != null && tools != null) {
      sandbox = !tools
          .captureRoutesForAssistant(
            mcp,
            context.read<AssistantProvider>(),
            assistantId: assistant?.id,
            conversation: conversation,
            reservedNames: BuiltInToolNames.all,
          )
          .containsExposedName('code_execution');
    }
  }
  return (
    workspaceBound: workspace != null,
    workspaceFiles:
        workspace != null &&
        spec?.supportsTool == true &&
        (workspace.isToolEnabled('read_file') ||
            workspace.isToolEnabled('shell')),
    nativePdf: spec?.supportsPdfInput == true,
    sandboxData: sandbox,
  );
}

extension ComposerDocumentRouting on ComposerDocumentRoute {
  Future<void> validate(
    Iterable<DocumentAttachment> documents,
    DocumentExtractionCache cache,
  ) async {
    for (final file in documents) {
      if (!needsLocalText(file)) continue;
      try {
        await cache.read(file);
      } on AttachmentReadError catch (error) {
        if (workspaceBound &&
            !workspaceFiles &&
            error.problem != AttachmentProblem.missing) {
          throw AttachmentReadError(AttachmentProblem.workspace, file.fileName);
        }
        rethrow;
      }
    }
  }

  bool needsLocalText(DocumentAttachment file) {
    if (workspaceFiles) return false;
    final mime = resolveDocumentAttachmentMime(file);
    return !isImageMime(mime) &&
        !isAudioMime(mime) &&
        !isVideoMime(mime) &&
        !(nativePdf && isPdfMime(mime)) &&
        !(sandboxData &&
            isSandboxDataFile(fileName: file.fileName, mime: mime));
  }
}
