import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/conversation_prompt_settings.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/responsive/screen_type_helper.dart';
import '../../../shared/widgets/form_sheet.dart';
import '../../../shared/widgets/ios_form_text_field.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';

Future<void> editConversationSystemPrompt(
  BuildContext context, {
  required String conversationId,
}) async {
  final chat = context.read<ChatService>();
  final initial = ConversationPromptSettings.fromExtras(
    chat.getConversation(conversationId)?.extras ?? const {},
  ).systemPrompt;
  final result = await showConversationSystemPromptEditor(
    context,
    initial: initial,
  );
  if (result == null) return;
  await chat.updateConversationExtras(conversationId, (extras) {
    final next = Map<String, dynamic>.from(extras);
    if (result.trim().isEmpty) {
      next.remove(ConversationPromptSettings.systemPromptKey);
    } else {
      next[ConversationPromptSettings.systemPromptKey] = result;
    }
    return next;
  });
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
          constraints: BoxConstraints(
            maxWidth: 600,
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.8,
          ),
          child: _ConversationSystemPromptEditor(
            initial: initial,
            desktop: true,
          ),
        ),
      ),
    );
  }
  return showFormSheet<String>(
    context,
    builder: (_) => _ConversationSystemPromptEditor(initial: initial),
  );
}

class _ConversationSystemPromptEditor extends StatefulWidget {
  const _ConversationSystemPromptEditor({
    required this.initial,
    this.desktop = false,
  });
  final String initial;
  final bool desktop;

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
    final cs = Theme.of(context).colorScheme;
    final children = <Widget>[
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          l10n.conversationSystemPromptHint,
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: cs.onSurfaceVariant,
          ),
        ),
      ),
      const SizedBox(height: 16),
      IosFormTextField(
        key: const ValueKey('conversation-system-prompt-input'),
        label: '',
        hintText: l10n.conversationSystemPromptPlaceholder,
        controller: _controller,
        minLines: 6,
        maxLines: 14,
        keyboardType: TextInputType.multiline,
        outerPadding: EdgeInsets.zero,
      ),
      if (widget.initial.trim().isNotEmpty) ...[
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: IosCardPress(
            baseColor: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            onTap: () => Navigator.of(context).pop(''),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Lucide.RotateCcw, size: 15, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    l10n.conversationSystemPromptClear,
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ];
    final actions = FormSheetActions(
      cancelLabel: l10n.worldBookCancel,
      confirmLabel: l10n.worldBookSave,
      onCancel: () => Navigator.of(context).pop(),
      onConfirm: () => Navigator.of(context).pop(_controller.text),
    );
    if (!widget.desktop) {
      return FormSheet(
        title: l10n.conversationSystemPromptTitle,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        actions: actions,
        children: children,
      );
    }
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.conversationSystemPromptTitle,
            style: TextStyle(fontSize: 17, fontWeight: AppFontWeights.emphasis),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: children),
            ),
          ),
          const SizedBox(height: 16),
          actions,
        ],
      ),
    );
  }
}
