import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/conversation_prompt_settings.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/responsive/screen_type_helper.dart';
import '../../../shared/widgets/ios_form_text_field.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/app_semantic_colors.dart';
import '../../../theme/app_font_weights.dart';
import '../../chat/utils/ensure_conversation.dart';

class ConversationSystemPromptButton extends StatelessWidget {
  const ConversationSystemPromptButton({
    super.key,
    this.conversationId,
    required this.assistantId,
  });
  final String? conversationId;
  final String assistantId;

  @override
  Widget build(BuildContext context) {
    final prompt = context.select<ChatService, String>(
      (chat) => ConversationPromptSettings.fromExtras(
        chat.getConversation(conversationId ?? '')?.extras ?? const {},
      ).systemPrompt,
    );
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Align(
      alignment: Alignment.centerLeft,
      child: IosCardPress(
        key: const ValueKey('conversation-system-prompt-button'),
        baseColor: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          final chat = context.read<ChatService>();
          final id = await ensureConversationId(
            context,
            conversationId: conversationId,
            assistantId: assistantId,
          );
          if (id == null || !context.mounted) return;
          final initial = ConversationPromptSettings.fromExtras(
            chat.getConversation(id)?.extras ?? const {},
          ).systemPrompt;
          final result = await showConversationSystemPromptEditor(
            context,
            initial: initial,
          );
          if (result == null) return;
          await chat.updateConversationExtras(id, (extras) {
            final next = Map<String, dynamic>.from(extras);
            if (result.trim().isEmpty) {
              next.remove(ConversationPromptSettings.systemPromptKey);
            } else {
              next[ConversationPromptSettings.systemPromptKey] = result;
            }
            return next;
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Lucide.FileText,
                size: 16,
                color: prompt.isEmpty ? cs.onSurfaceVariant : cs.primary,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.conversationSystemPromptTitle,
                style: TextStyle(
                  fontSize: 12,
                  color: prompt.isEmpty ? cs.onSurfaceVariant : cs.primary,
                ),
              ),
              if (prompt.isNotEmpty) ...[
                const SizedBox(width: 5),
                Icon(Lucide.Check, size: 14, color: cs.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> showConversationSystemPromptEditor(
  BuildContext context, {
  required String initial,
}) {
  final platform = Theme.of(context).platform;
  if (ResponsiveHelper.isDesktop(context) ||
      platform == TargetPlatform.macOS ||
      platform == TargetPlatform.windows ||
      platform == TargetPlatform.linux) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: ctx.overlaySurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: _ConversationSystemPromptEditor(initial: initial),
        ),
      ),
    );
  }
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.overlaySurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _ConversationSystemPromptEditor(initial: initial),
  );
}

class _ConversationSystemPromptEditor extends StatefulWidget {
  const _ConversationSystemPromptEditor({required this.initial});
  final String initial;

  @override
  State<_ConversationSystemPromptEditor> createState() =>
      _ConversationSystemPromptEditorState();
}

class _ConversationSystemPromptEditorState
    extends State<_ConversationSystemPromptEditor> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.conversationSystemPromptTitle,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: AppFontWeights.emphasis,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.conversationSystemPromptHint,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: IosFormTextField(
                    key: const ValueKey('conversation-system-prompt-input'),
                    label: '',
                    controller: _controller,
                    minLines: 5,
                    maxLines: 14,
                    keyboardType: TextInputType.multiline,
                    outerPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: IosTileButton(
                      label: l10n.conversationSystemPromptClear,
                      icon: Lucide.RotateCcw,
                      onTap: () => Navigator.of(context).pop(''),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: IosTileButton(
                      label: l10n.worldBookCancel,
                      icon: Lucide.X,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: IosTileButton(
                      label: l10n.worldBookSave,
                      icon: Lucide.Check,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      onTap: () => Navigator.of(context).pop(_controller.text),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
