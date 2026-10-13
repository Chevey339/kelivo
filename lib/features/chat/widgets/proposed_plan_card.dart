import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/chat_input_data.dart';
import '../../../core/models/plan_mode_binding.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/markdown_with_highlight.dart';
import '../../../theme/design_tokens.dart';

/// Helper to parse and extract `<proposed_plan>` blocks from text.
class ProposedPlanExtractor {
  static const String startTag = '<proposed_plan>';
  static const String endTag = '</proposed_plan>';

  final String? planContent;
  final String cleanedText;
  final bool hasPlan;

  const ProposedPlanExtractor({
    this.planContent,
    required this.cleanedText,
    this.hasPlan = false,
  });

  static ProposedPlanExtractor extract(String text) {
    final startIndex = text.indexOf(startTag);
    if (startIndex == -1) {
      return ProposedPlanExtractor(cleanedText: text);
    }
    final endIndex = text.indexOf(endTag, startIndex);
    if (endIndex != -1) {
      final plan =
          text.substring(startIndex + startTag.length, endIndex).trim();
      final before = text.substring(0, startIndex).trim();
      final after = text.substring(endIndex + endTag.length).trim();
      final cleaned = [
        if (before.isNotEmpty) before,
        if (after.isNotEmpty) after,
      ].join('\n\n');
      return ProposedPlanExtractor(
        planContent: plan,
        cleanedText: cleaned,
        hasPlan: true,
      );
    } else {
      // Incomplete or streaming tag
      final plan = text.substring(startIndex + startTag.length).trim();
      final before = text.substring(0, startIndex).trim();
      return ProposedPlanExtractor(
        planContent: plan,
        cleanedText: before,
        hasPlan: true,
      );
    }
  }
}

/// A dedicated UI card that displays the model's `<proposed_plan>`
/// and offers immediate actions: Implement in current chat, Clear context & implement, or Revise.
class ProposedPlanCard extends StatefulWidget {
  const ProposedPlanCard({
    super.key,
    required this.planMarkdown,
    this.conversationId,
    this.onImplementPlan,
    this.onImplementInNewChat,
    this.onRevisePlan,
  });

  final String planMarkdown;
  final String? conversationId;
  final VoidCallback? onImplementPlan;
  final VoidCallback? onImplementInNewChat;
  final VoidCallback? onRevisePlan;

  @override
  State<ProposedPlanCard> createState() => _ProposedPlanCardState();
}

class _ProposedPlanCardState extends State<ProposedPlanCard> {
  bool _expanded = true;

  void _handleApproveAndImplement(BuildContext context) {
    final convId = widget.conversationId;
    if (convId != null) {
      final chatService = context.read<ChatService>();
      final current = PlanModeBinding.fromExtras(
        chatService.getConversation(convId)?.extras ?? const {},
      );
      // Switch off plan mode and store the approved plan
      chatService.updateConversationExtras(
        convId,
        (extras) => current
            .copyWith(isPlanMode: false, currentPlanMarkdown: widget.planMarkdown)
            .applyTo(extras),
      );
    }
    widget.onImplementPlan?.call();
  }

  void _handleImplementInNewChat(BuildContext context) {
    if (widget.onImplementInNewChat != null) {
      widget.onImplementInNewChat!.call();
      return;
    }
    // Fallback implementation: create conversation and send the plan
    final convId = widget.conversationId;
    final chatService = context.read<ChatService>();
    final currentConv = convId != null ? chatService.getConversation(convId) : null;
    final newConv = chatService.createConversation(
      title: 'Plan: ${currentConv?.title ?? "Implementation"}',
      assistantId: currentConv?.assistantId,
      chatModelProvider: currentConv?.chatModelProvider,
      chatModelId: currentConv?.chatModelId,
      extras: {
        // Inherit workspace and skills if present, but plan mode is off
        if (currentConv?.extras['workspace.id'] != null)
          'workspace.id': currentConv!.extras['workspace.id'],
        if (currentConv?.extras['workspace.cwd'] != null)
          'workspace.cwd': currentConv!.extras['workspace.cwd'],
        if (currentConv?.extras['skills.ids'] != null)
          'skills.ids': currentConv!.extras['skills.ids'],
      },
    );
    chatService.selectConversation(newConv.id);

    // Send prompt with the plan into the fresh conversation
    final instruction =
        'A plan was prepared to accomplish the task. '
        'Implement the plan directly in this fresh context. '
        'Treat this plan as the specification:\n\n${widget.planMarkdown}';
    chatService.sendMessage(
      newConv.id,
      ChatInputData(text: instruction),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Lucide.ListTodo,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.planModeTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Lucide.ChevronUp : Lucide.ChevronDown,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // Body
          if (_expanded) ...[
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: MarkdownWithHighlight(
                data: widget.planMarkdown,
                selectable: true,
              ),
            ),
            const Divider(height: 1),
            // Actions
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                alignment: WrapAlignment.end,
                children: [
                  // Revise Plan
                  if (widget.onRevisePlan != null)
                    TextButton.icon(
                      icon: const Icon(Lucide.FileEdit, size: 14),
                      label: Text(l10n.planModeRevisePlan),
                      onPressed: widget.onRevisePlan,
                    ),
                  // Clear context & implement
                  OutlinedButton.icon(
                    icon: const Icon(Lucide.Sparkles, size: 14),
                    label: Text(l10n.planModeImplementInNewChat),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                    ),
                    onPressed: () => _handleImplementInNewChat(context),
                  ),
                  // Implement Plan in current chat
                  FilledButton.icon(
                    icon: const Icon(Lucide.Play, size: 14),
                    label: Text(l10n.planModeImplementPlan),
                    onPressed: () => _handleApproveAndImplement(context),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
