import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/assistant_provider.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import '../../../shared/widgets/snackbar.dart';
import '../services/debug_conversation_factory.dart';

class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  State<DebugPage> createState() => _DebugPageState();
}

@visibleForTesting
const debugCreateOversizedConversationButtonKey = Key(
  'debug_create_oversized_conversation_button',
);

@visibleForTesting
const debugCreateManyMessagesConversationButtonKey = Key(
  'debug_create_many_messages_conversation_button',
);

@visibleForTesting
const debugCreateDailyMixedMarkdownConversationButtonKey = Key(
  'debug_create_daily_mixed_markdown_conversation_button',
);

@visibleForTesting
const debugCreateLongReasoningConversationButtonKey = Key(
  'debug_create_long_reasoning_conversation_button',
);

class _DebugPageState extends State<DebugPage> {
  _DebugAction? _runningAction;

  bool get _isBusy => _runningAction != null;

  Future<void> _createOversizedConversation() async {
    await _runAction(
      action: _DebugAction.oversized,
      busyMessage: (l10n) => l10n.debugPageCreatingOversizedConversation,
      createSeed: (l10n, assistantId) =>
          DebugConversationFactory.createOversizedConversation(
            title: l10n.debugPageOversizedConversationTitle(30),
            assistantId: assistantId,
            chunkText: l10n.debugPageOversizedConversationSeedText,
          ),
    );
  }

  Future<void> _createManyMessagesConversation() async {
    await _runAction(
      action: _DebugAction.manyMessages,
      busyMessage: (l10n) => l10n.debugPageCreatingManyMessagesConversation,
      createSeed: (l10n, assistantId) =>
          DebugConversationFactory.createManyMessagesConversation(
            title: l10n.debugPageManyMessagesConversationTitle(
              DebugConversationFactory.manyMessagesCount,
            ),
            assistantId: assistantId,
            contentBuilder: (index, role) =>
                l10n.debugPageManyMessagesSeedText(role, index + 1),
          ),
    );
  }

  Future<void> _createLongReasoningConversation() async {
    await _runAction(
      action: _DebugAction.longReasoning,
      busyMessage: (l10n) => l10n.debugPageCreatingLongReasoningConversation,
      createSeed: (l10n, assistantId) =>
          DebugConversationFactory.createLongReasoningConversation(
            title: l10n.debugPageLongReasoningConversationTitle(
              DebugConversationFactory.longReasoningMessagesCount,
            ),
            assistantId: assistantId,
          ),
    );
  }

  Future<void> _createDailyMixedMarkdownConversation() async {
    await _runAction(
      action: _DebugAction.dailyMixedMarkdown,
      busyMessage: (l10n) =>
          l10n.debugPageCreatingDailyMixedMarkdownConversation,
      createSeed: (l10n, assistantId) =>
          DebugConversationFactory.createDailyMixedMarkdownConversation(
            title: l10n.debugPageDailyMixedMarkdownConversationTitle(
              DebugConversationFactory.dailyMixedMarkdownMessagesCount,
            ),
            assistantId: assistantId,
          ),
    );
  }

  Future<void> _runAction({
    required _DebugAction action,
    required String Function(AppLocalizations l10n) busyMessage,
    required DebugConversationSeed Function(
      AppLocalizations l10n,
      String? assistantId,
    )
    createSeed,
  }) async {
    if (_isBusy) return;
    final l10n = AppLocalizations.of(context)!;
    final assistant = context.read<AssistantProvider>().currentAssistant;
    if (assistant == null) {
      showAppSnackBar(
        context,
        message: l10n.debugPageNoCurrentAssistant,
        type: NotificationType.error,
      );
      return;
    }

    setState(() => _runningAction = action);
    showAppSnackBar(context, message: busyMessage(l10n));

    try {
      final seed = createSeed(l10n, assistant.id);
      await context.read<ChatService>().restoreConversation(
        seed.conversation,
        seed.messages,
      );
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: l10n.debugPageConversationCreated(seed.messages.length),
        type: NotificationType.success,
      );
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: l10n.debugPageCreateConversationFailed(error.toString()),
        type: NotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _runningAction = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.settingsPageBackButton,
          icon: Icon(Lucide.ArrowLeft, color: cs.onSurface),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l10n.debugPageTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          _DebugSectionCard(
            title: l10n.debugPageConversationToolsTitle,
            children: [
              IosTileButton(
                key: debugCreateOversizedConversationButtonKey,
                label: _runningAction == _DebugAction.oversized
                    ? l10n.debugPageCreatingButton
                    : l10n.debugPageCreateOversizedConversationButton,
                icon: Lucide.Database,
                backgroundColor: cs.primary,
                enabled: !_isBusy,
                onTap: _createOversizedConversation,
              ),
              const SizedBox(height: 12),
              IosTileButton(
                key: debugCreateManyMessagesConversationButtonKey,
                label: _runningAction == _DebugAction.manyMessages
                    ? l10n.debugPageCreatingButton
                    : l10n.debugPageCreateManyMessagesConversationButton,
                icon: Lucide.MessagesSquare,
                backgroundColor: cs.primary,
                enabled: !_isBusy,
                onTap: _createManyMessagesConversation,
              ),
              const SizedBox(height: 12),
              IosTileButton(
                key: debugCreateDailyMixedMarkdownConversationButtonKey,
                label: _runningAction == _DebugAction.dailyMixedMarkdown
                    ? l10n.debugPageCreatingButton
                    : l10n.debugPageCreateDailyMixedMarkdownConversationButton,
                icon: Lucide.FileText,
                backgroundColor: cs.primary,
                enabled: !_isBusy,
                onTap: _createDailyMixedMarkdownConversation,
              ),
              const SizedBox(height: 12),
              IosTileButton(
                key: debugCreateLongReasoningConversationButtonKey,
                label: _runningAction == _DebugAction.longReasoning
                    ? l10n.debugPageCreatingButton
                    : l10n.debugPageCreateLongReasoningConversationButton,
                icon: Lucide.Brain,
                backgroundColor: cs.primary,
                enabled: !_isBusy,
                onTap: _createLongReasoningConversation,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _DebugAction { oversized, manyMessages, dailyMixedMarkdown, longReasoning }

class _DebugSectionCard extends StatelessWidget {
  const _DebugSectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          width: 0.5,
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : cs.outlineVariant.withValues(alpha: 0.12),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}
