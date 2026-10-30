import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/memory_provider_v2.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/services/memory/memory_gatekeeper.dart';
import '../../../core/services/memory/memory_pipeline.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../theme/app_font_weights.dart';
import '../../../utils/platform_utils.dart';
import '../../settings/pages/memory_entries_page.dart';
import '../../settings/widgets/memory_ui.dart';

/// Memories visible to one assistant (global plus its own): browse, search,
/// add, and organize from the current conversation.
class AssistantMemoryPage extends StatelessWidget {
  const AssistantMemoryPage({super.key, required this.assistantId});

  final String assistantId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        leading: Tooltip(
          message: l10n.settingsPageBackButton,
          child: IosIconButton(
            icon: Lucide.ArrowLeft,
            color: cs.onSurface,
            size: 22,
            minSize: 44,
            semanticLabel: l10n.settingsPageBackButton,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(l10n.assistantMemoryManageTitle),
      ),
      body: AssistantMemoryContent(assistantId: assistantId),
    );
  }
}

class AssistantMemoryContent extends StatelessWidget {
  const AssistantMemoryContent({super.key, required this.assistantId});

  final String assistantId;

  @override
  Widget build(BuildContext context) {
    return MemoryEntriesContent(
      assistantId: assistantId,
      header: _MemoryOrganizeBar(assistantId: assistantId),
    );
  }
}

class _MemoryOrganizeBar extends StatefulWidget {
  const _MemoryOrganizeBar({required this.assistantId});

  final String assistantId;

  @override
  State<_MemoryOrganizeBar> createState() => _MemoryOrganizeBarState();
}

class _MemoryOrganizeBarState extends State<_MemoryOrganizeBar> {
  bool _organizing = false;

  Future<void> _runOrganize() async {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.read<SettingsProvider>();
    if (settings.memoryModelProvider == null ||
        settings.memoryModelId == null) {
      showAppSnackBar(
        context,
        message: l10n.memoryOrganizeNeedsModel,
        type: NotificationType.warning,
      );
      return;
    }
    final chat = context.read<ChatService>();
    final convId = chat.currentConversationId;
    final conv = convId == null ? null : chat.getConversation(convId);
    if (conv == null || conv.assistantId != widget.assistantId) {
      showAppSnackBar(
        context,
        message: l10n.memoryOrganizeNeedsConversation,
        type: NotificationType.warning,
      );
      return;
    }
    setState(() => _organizing = true);
    try {
      final pipeline = context.read<MemoryPipelineService>();
      await pipeline.runNow(
        conversationId: conv.id,
        assistantId: widget.assistantId,
      );
      if (mounted) {
        await context.read<MemoryProviderV2>().refresh(
          assistantId: widget.assistantId,
        );
      }
    } finally {
      if (mounted) setState(() => _organizing = false);
    }
  }

  String _statusLine(AppLocalizations l10n, MemoryOrganizeStatus status) {
    final lastAt = status.lastAt;
    final result = status.lastResult;
    if (lastAt == null || result == null) {
      return l10n.memoryOrganizeStatusNever;
    }
    final when = _formatRelative(l10n, lastAt);
    final parts = <String>[l10n.memoryOrganizeStatusLast(when)];
    if (result.error != null && result.error!.isNotEmpty) {
      final code = result.error!;
      final label = memoryOutcomeLabel(l10n, code);
      if (MemoryPipelineService.skipReasonCodes.contains(code)) {
        parts.add(l10n.memoryOrganizeStatusSkippedReason(label));
      } else {
        parts.add(l10n.memoryOrganizeStatusFailed(label));
      }
    } else if (result.gate == MemoryGateParseResult.skip ||
        (result.extractedCount == 0 && result.advanced)) {
      parts.add(l10n.memoryOrganizeStatusSkipped);
    } else {
      parts.add(l10n.memoryOrganizeStatusExtracted(result.extractedCount));
    }
    return parts.join(' · ');
  }

  String _formatRelative(AppLocalizations l10n, DateTime at) {
    final delta = DateTime.now().difference(at);
    if (delta.inMinutes < 1) return l10n.memoryOrganizeJustNow;
    if (delta.inHours < 1) {
      return l10n.memoryOrganizeMinutesAgo(delta.inMinutes);
    }
    if (delta.inDays < 1) {
      return l10n.memoryOrganizeHoursAgo(delta.inHours);
    }
    return l10n.memoryOrganizeDaysAgo(delta.inDays);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final assistant = context.watch<AssistantProvider>().getById(
      widget.assistantId,
    );
    final chat = context.watch<ChatService>();
    final pipeline = context.read<MemoryPipelineService>();
    final modelMissing =
        settings.memoryModelProvider == null || settings.memoryModelId == null;
    final convId = chat.currentConversationId;
    final conv = convId == null ? null : chat.getConversation(convId);
    final canOrganize =
        !modelMissing &&
        conv != null &&
        conv.assistantId == widget.assistantId &&
        !_organizing;
    final color = canOrganize
        ? cs.primary
        : cs.onSurface.withValues(alpha: 0.35);
    final mutedStyle = TextStyle(
      fontSize: 12,
      color: cs.onSurface.withValues(alpha: 0.55),
    );
    final horizontal = PlatformUtils.isDesktopTarget ? 12.0 : 16.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontal, 4, horizontal, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _statusLine(l10n, pipeline.lastStatus),
                  style: mutedStyle,
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: modelMissing
                    ? l10n.memoryOrganizeNeedsModel
                    : (!canOrganize && !_organizing
                          ? l10n.memoryOrganizeNeedsConversation
                          : l10n.memoryOrganizeButton),
                child: IosCardPress(
                  onTap: canOrganize ? _runOrganize : null,
                  borderRadius: BorderRadius.circular(8),
                  baseColor: Colors.transparent,
                  pressedScale: 0.97,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_organizing)
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: color,
                          ),
                        )
                      else
                        Icon(Lucide.Sparkles, size: 16, color: color),
                      const SizedBox(width: 4),
                      Text(
                        l10n.memoryOrganizeButton,
                        style: TextStyle(
                          color: color,
                          fontWeight: AppFontWeights.semibold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (assistant != null && !assistant.enableMemory)
            Text(l10n.memoryEntryEmptyDisabled, style: mutedStyle),
        ],
      ),
    );
  }
}
