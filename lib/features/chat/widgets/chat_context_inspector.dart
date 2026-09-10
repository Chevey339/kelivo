import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/skills_binding.dart';
import '../../../core/models/conversation.dart';
import '../../../core/models/workspace_binding.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/mcp_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/workspace_provider.dart';
import '../../../core/services/api/generation/generation_capabilities.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/services/chat/prepared_context_store.dart';
import '../../../core/services/logging/context_log_models.dart';
import '../../../core/services/skills/skills_service.dart';
import '../../../core/services/workspace/workspace_runtime.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/responsive/screen_type_helper.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';
import '../../../utils/platform_utils.dart';
import '../../assistant/pages/assistant_settings_edit_page.dart';
import '../../assistant/widgets/runtime_context_settings_card.dart';
import '../../home/services/local_tools_service.dart';
import '../../home/utils/model_display_helper.dart';
import '../../settings/pages/log_viewer_page.dart';

Future<void> showChatContextInspector(
  BuildContext context, {
  required String assistantId,
  required String? conversationId,
  required bool Function(String, String) isToolModel,
  VoidCallback? onManageSearch,
  VoidCallback? onManageWorkspace,
  VoidCallback? onManageSkills,
}) {
  Widget panel(BuildContext panelContext) => ChatContextInspector(
    assistantId: assistantId,
    conversationId: conversationId,
    isToolModel: isToolModel,
    onClose: () => Navigator.of(panelContext).pop(),
    onManage: (section) {
      Navigator.of(panelContext).pop();
      if (!context.mounted) return;
      if (section == 'workspace' && onManageWorkspace != null) {
        onManageWorkspace();
      } else if (section == 'skills' && onManageSkills != null) {
        onManageSkills();
      } else if (section == 'search' && onManageSearch != null) {
        onManageSearch();
      } else {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AssistantSettingsEditPage(
              assistantId: assistantId,
              initialTab: section,
            ),
          ),
        );
      }
    },
  );
  // Narrow desktop windows still use a dialog, never a bottom sheet.
  if (PlatformUtils.isDesktopTarget || ResponsiveHelper.isDesktop(context)) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: SizedBox(
          width: 720,
          height: MediaQuery.sizeOf(ctx).height * .85,
          child: panel(ctx),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.overlaySurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SizedBox(
      height: MediaQuery.sizeOf(ctx).height * .85,
      child: panel(ctx),
    ),
  );
}

class ChatContextInspector extends StatelessWidget {
  const ChatContextInspector({
    super.key,
    required this.assistantId,
    required this.conversationId,
    required this.isToolModel,
    required this.onClose,
    required this.onManage,
  });
  final String assistantId;
  final String? conversationId;
  final bool Function(String, String) isToolModel;
  final VoidCallback onClose;
  final ValueChanged<String> onManage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ap = context.watch<AssistantProvider>();
    final assistant = ap.getById(assistantId);
    final chat = context.read<ChatService>();
    final current = context.select<ChatService, Conversation?>(
      (chat) => chat.getConversation(conversationId ?? ''),
    );
    final settings = context.watch<SettingsProvider>();
    final mcp = context.watch<McpProvider?>();
    final skills = context.watch<SkillsService?>();
    final workspaces = context.watch<WorkspaceProvider?>();
    final runtime = context.watch<WorkspaceRuntimeProvider?>();
    if (assistant == null) {
      return Center(child: Text(l10n.assistantEditPageNotFound));
    }

    final model = getModelDisplayInfo(
      settings,
      assistant: assistant,
      conversation: current,
    );
    final supportsTools =
        model.isConfigured && isToolModel(model.providerKey!, model.modelId!);
    final native = model.isConfigured
        ? GenerationCapabilities.resolve(
            config: model.getConfig(settings)!,
            modelId: model.modelId!,
            clientTools: const [],
          )
        : null;
    final toolsAvailable = supportsTools && (native?.allowsClientTools ?? true);
    final toolReason = !supportsTools
        ? l10n.harnessToolsUnsupported
        : l10n.harnessNativeExclusive;
    final connected =
        mcp?.connectedServers
            .where((server) => server.tools.any((tool) => tool.enabled))
            .map((server) => server.id)
            .toSet() ??
        <String>{};
    final connectedCount = assistant.mcpServerIds
        .where(connected.contains)
        .length;
    final localCount = assistant.localToolIds
        .where(LocalToolsService.isAvailableOnThisPlatform)
        .length;
    final binding = WorkspaceBinding.fromExtras(current?.extras ?? const {});
    final workspaceId =
        binding.workspaceId ??
        (current == null ? assistant.defaultWorkspaceId : null);
    final workspace = workspaceId == null
        ? null
        : workspaces?.byId(workspaceId);
    final selectedSkills =
        skills?.resolveForAssistant(
          assistant,
          conversationOverride: SkillsBinding.fromExtras(
            current?.extras ?? const {},
          ).skillIds,
        ) ??
        const [];
    final configuredSkills = selectedSkills.length;
    final canReadSkills =
        workspace == null || workspace.isToolEnabled('read_file');
    String availability(bool enabled, bool available, String reason) => !enabled
        ? l10n.harnessOff
        : available
        ? l10n.harnessAvailable
        : '${l10n.harnessUnavailable} · $reason';

    String countedAvailability(int eligible, int selected, String reason) {
      final count = toolsAvailable ? eligible : 0;
      final label = count > 0 && count < selected
          ? '${l10n.harnessPartial} · $reason'
          : availability(
              selected > 0,
              count > 0,
              !toolsAvailable ? toolReason : reason,
            );
      return '$label · $count/$selected';
    }

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.harnessTitle,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: AppFontWeights.emphasis,
                    ),
                  ),
                ),
                IosIconButton(
                  icon: Lucide.X,
                  semanticLabel: l10n.harnessClose,
                  onTap: onClose,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  l10n.harnessCurrentConfiguration,
                  style: TextStyle(fontWeight: AppFontWeights.emphasis),
                ),
                const SizedBox(height: 8),
                RuntimeContextSettingsCard(
                  assistant: assistant,
                  conversation: current,
                  onChanged: (next) => ap.updateAssistant(next),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  children: [
                    _StatusRow(
                      title: l10n.harnessMemory,
                      icon: Lucide.Brain,
                      status:
                          !assistant.enableMemory &&
                              !assistant.allowPastConversationRecall
                          ? l10n.harnessOff
                          : assistant.enableMemory && !toolsAvailable
                          ? l10n.harnessMemoryReadOnly
                          : availability(true, toolsAvailable, toolReason),
                      onTap: () => onManage('memory'),
                    ),
                    _StatusRow(
                      title: l10n.harnessSearch,
                      icon: Lucide.Search,
                      status:
                          native?.nativeTools.any(
                                (name) => name.contains('search'),
                              ) ==
                              true
                          ? l10n.harnessNativeTools
                          : availability(
                              assistant.searchEnabled,
                              toolsAvailable,
                              toolReason,
                            ),
                      onTap: () => onManage('search'),
                    ),
                    _StatusRow(
                      title: l10n.harnessLocalTools,
                      icon: Lucide.ToolCase,
                      status: countedAvailability(
                        localCount,
                        assistant.localToolIds.length,
                        l10n.harnessPlatformUnavailable,
                      ),
                      onTap: () => onManage('localTools'),
                    ),
                    _StatusRow(
                      title: 'MCP',
                      icon: Lucide.Wrench,
                      status: countedAvailability(
                        connectedCount,
                        assistant.mcpServerIds.length,
                        l10n.harnessMcpDisconnected,
                      ),
                      onTap: () => onManage('mcp'),
                    ),
                    _StatusRow(
                      title: l10n.harnessSkills,
                      icon: Lucide.WandSparkles,
                      status:
                          '${availability(configuredSkills > 0, toolsAvailable && canReadSkills, !toolsAvailable ? toolReason : l10n.harnessSkillReadUnavailable)} · $configuredSkills',
                      onTap: () => onManage('skills'),
                    ),
                    _StatusRow(
                      title: l10n.harnessWorkspace,
                      icon: Lucide.Folder,
                      status: workspaceId == null
                          ? l10n.harnessOff
                          : workspace == null
                          ? l10n.harnessNotConfigured
                          : '${workspace.name} · '
                                '${!toolsAvailable
                                    ? toolReason
                                    : runtime?.lastStatus?.ready == true
                                    ? l10n.harnessAvailable
                                    : runtime?.lastStatus == null
                                    ? l10n.harnessReadinessPending
                                    : l10n.harnessWorkspaceUnready}',
                      onTap: () => onManage('workspace'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListenableBuilder(
                  listenable: chat.preparedContexts,
                  builder: (context, _) => _LatestRequest(
                    snapshot: chat.preparedContexts.forConversation(
                      conversationId,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.title,
    required this.status,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final String status;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                const SizedBox(height: 4),
                Text(status, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(Lucide.ChevronRight, size: 16),
        ],
      ),
    ),
  );
}

class _LatestRequest extends StatefulWidget {
  const _LatestRequest({this.snapshot});
  final PreparedContextSnapshot? snapshot;
  @override
  State<_LatestRequest> createState() => _LatestRequestState();
}

class _LatestRequestState extends State<_LatestRequest> {
  bool expanded = false;
  @override
  void didUpdateWidget(covariant _LatestRequest oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot?.generationId != widget.snapshot?.generationId) {
      expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final snapshot = widget.snapshot;
    return SectionCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.harnessLatestRequest,
            style: TextStyle(fontWeight: AppFontWeights.emphasis),
          ),
          const SizedBox(height: 8),
          Text(
            snapshot == null
                ? l10n.harnessNoSnapshot
                : l10n.harnessPreparedOnly,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (snapshot != null) ...[
            const SizedBox(height: 8),
            Text(
              '${snapshot.context.model} · ${snapshot.context.timestamp.toLocal()}',
            ),
            Text(l10n.contextLogSnapshotTokens(snapshot.context.totalTokens)),
            Text(
              '${l10n.harnessClientTools}: ${snapshot.toolNames.length} · '
              '${l10n.harnessToolsEstimate}: ${snapshot.toolTokens}',
            ),
            Text(
              '${l10n.harnessNativeTools}: ${snapshot.nativeTools.isEmpty ? '—' : snapshot.nativeTools.join(', ')}',
            ),
            TextButton.icon(
              key: const ValueKey('context-inspector-details'),
              icon: Icon(
                expanded ? Lucide.ChevronUp : Lucide.ChevronDown,
                size: 16,
              ),
              onPressed: () => setState(() => expanded = !expanded),
              label: Text(l10n.harnessDetails),
            ),
            if (expanded) ...[
              SelectableText(
                '${l10n.harnessClientTools}: ${snapshot.toolNames.isEmpty ? '—' : snapshot.toolNames.join(', ')}',
              ),
              for (final issue in snapshot.issues)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${contextSourceLabel(l10n, issue.source)} · ${l10n.harnessNotInjected} · ${issue.reason}',
                  ),
                ),
              Text(
                l10n.harnessPreviewHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              for (final message in _previewMessages(snapshot))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ContextMessageGroup(message: message),
                ),
              TextButton.icon(
                key: const ValueKey('context-inspector-full-request'),
                icon: const Icon(Lucide.ListTree, size: 16),
                label: Text(l10n.harnessFullRequest),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ContextSnapshotDetailPage(snapshot: snapshot.context),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

Iterable<ContextLogMessage> _previewMessages(PreparedContextSnapshot snapshot) {
  final messages = snapshot.context.messages;
  if (messages.isEmpty) return const [];
  final live = messages.where(
    (message) => message.segments.any(
      (segment) => segment.source == ContextSource.runtimeContext,
    ),
  );
  return {messages.first, live.isNotEmpty ? live.last : messages.last};
}
