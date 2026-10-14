import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/plan_mode_binding.dart';
import '../../../core/models/task_execution_binding.dart';
import '../utils/task_plan_parser.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/services/haptics.dart';
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
/// and offers immediate actions: Implement in current chat, Clear context & implement,
/// or expand an interactive revision box to provide feedback.
class ProposedPlanCard extends StatefulWidget {
  const ProposedPlanCard({
    super.key,
    required this.planMarkdown,
    this.conversationId,
    this.onImplementPlan,
    this.onImplementInNewChat,
    this.onRevisePlan,
    this.onSendFeedback,
  });

  final String planMarkdown;
  final String? conversationId;
  final VoidCallback? onImplementPlan;
  final VoidCallback? onImplementInNewChat;
  final VoidCallback? onRevisePlan;
  final ValueChanged<String>? onSendFeedback;

  @override
  State<ProposedPlanCard> createState() => _ProposedPlanCardState();
}

class _ProposedPlanCardState extends State<ProposedPlanCard> {
  bool _expanded = true;
  bool _showRevisionBox = false;
  final TextEditingController _feedbackController = TextEditingController();
  final FocusNode _feedbackFocusNode = FocusNode();

  @override
  void dispose() {
    _feedbackController.dispose();
    _feedbackFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleApproveAndImplement(BuildContext context) async {
    final convId = widget.conversationId;
    if (convId != null) {
      final chatService = context.read<ChatService>();
      final current = PlanModeBinding.fromExtras(
        chatService.getConversation(convId)?.extras ?? const {},
      );
      // Parse markdown plan into structured task steps
      final taskPlan = TaskPlanParser.parse(widget.planMarkdown);
      final taskBinding = TaskExecutionBinding(plan: taskPlan);

      // Switch off plan mode, record approved plan markdown, and store task plan
      await chatService.updateConversationExtras(
        convId,
        (extras) {
          var updated = current
              .copyWith(
                isPlanMode: false,
                currentPlanMarkdown: widget.planMarkdown,
              )
              .applyTo(extras);
          updated = taskBinding.applyTo(updated);
          return updated;
        },
      );
    }
    widget.onImplementPlan?.call();
  }

  Future<void> _handleImplementInNewChat(BuildContext context) async {
    if (widget.onImplementInNewChat != null) {
      widget.onImplementInNewChat!.call();
      return;
    }
    final convId = widget.conversationId;
    final chatService = context.read<ChatService>();
    final currentConv =
        convId != null ? chatService.getConversation(convId) : null;
    final taskPlan = TaskPlanParser.parse(widget.planMarkdown);
    final taskBinding = TaskExecutionBinding(plan: taskPlan);

    final newConv = await chatService.createConversation(
      title: 'Plan: ${currentConv?.title ?? "Implementation"}',
      assistantId: currentConv?.assistantId,
      activate: true,
    );
    if (chatService.currentConversationId != null) {
      await chatService.updateConversationExtras(
        chatService.currentConversationId!,
        (extras) {
          var updated = PlanModeBinding.fromExtras(extras)
              .copyWith(
                isPlanMode: false,
                currentPlanMarkdown: widget.planMarkdown,
              )
              .applyTo(extras);
          updated = taskBinding.applyTo(updated);
          return updated;
        },
      );
    }
    widget.onImplementPlan?.call();
  }

  Future<void> _submitFeedback(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final convId = widget.conversationId;
    if (convId != null) {
      final chatService = context.read<ChatService>();
      final current = PlanModeBinding.fromExtras(
        chatService.getConversation(convId)?.extras ?? const {},
      );
      // Re-affirm that plan mode is strictly active for revision
      await chatService.updateConversationExtras(
        convId,
        (extras) => current.copyWith(isPlanMode: true).applyTo(extras),
      );
    }

    final l10n = AppLocalizations.of(context)!;
    final prompt =
        '${l10n.planModeRevisionPrefix}\n$trimmed\n\n${l10n.planModeRevisionInstruction}';
    widget.onSendFeedback?.call(prompt);
    _feedbackController.clear();
    setState(() => _showRevisionBox = false);
  }

  Widget _buildRevisionPanel(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Lucide.Pencil, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                l10n.planModeRevisePlan,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _showRevisionBox = false),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Lucide.X,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Quick suggestion chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _quickChip(l10n.planModeQuickChipSimplify),
                const SizedBox(width: 6),
                _quickChip(l10n.planModeQuickChipDetail),
                const SizedBox(width: 6),
                _quickChip(l10n.planModeQuickChipTests),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Multiline TextField
          TextField(
            controller: _feedbackController,
            focusNode: _feedbackFocusNode,
            minLines: 1,
            maxLines: 4,
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: l10n.planModeRevisionHint,
              hintStyle: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 1.5,
                ),
              ),
            ),
            onSubmitted: _submitFeedback,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _showRevisionBox = false),
                child: Text(l10n.cancel),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: const Icon(Lucide.Send, size: 14),
                label: Text(l10n.planModeSubmitRevision),
                onPressed: () => _submitFeedback(_feedbackController.text),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickChip(String text) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Haptics.light();
        final current = _feedbackController.text.trim();
        if (current.isEmpty) {
          _feedbackController.text = text;
        } else {
          _feedbackController.text = '$current；$text';
        }
        _feedbackFocusNode.requestFocus();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
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
              child: MarkdownWithCodeHighlight(
                text: widget.planMarkdown,
                conversationId: widget.conversationId,
              ),
            ),
            if (_showRevisionBox) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: _buildRevisionPanel(context),
              ),
            ],
            const Divider(height: 1),
            // Actions
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                alignment: WrapAlignment.end,
                children: [
                  // Revise Plan button
                  OutlinedButton.icon(
                    icon: Icon(
                      _showRevisionBox ? Lucide.ChevronUp : Lucide.Pencil,
                      size: 14,
                    ),
                    label: Text(l10n.planModeRevisePlan),
                    onPressed: () {
                      Haptics.light();
                      setState(() {
                        _showRevisionBox = !_showRevisionBox;
                        if (_showRevisionBox) {
                          _feedbackFocusNode.requestFocus();
                        }
                      });
                    },
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
