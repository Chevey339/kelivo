import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import '../core/models/chat_message.dart';
import '../features/chat/models/message_edit_result.dart';
import '../l10n/app_localizations.dart';
import '../icons/lucide_adapter.dart';
import '../shared/widgets/plain_text_code_editor.dart';
import '../utils/re_editor_utils.dart';

Future<MessageEditResult?> showMessageEditDesktopDialog(BuildContext context, {required ChatMessage message}) async {
  return showDialog<MessageEditResult?>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _MessageEditDesktopDialog(message: message),
  );
}

class _MessageEditDesktopDialog extends StatefulWidget {
  const _MessageEditDesktopDialog({required this.message});
  final ChatMessage message;

  @override
  State<_MessageEditDesktopDialog> createState() => _MessageEditDesktopDialogState();
}

class _MessageEditDesktopDialogState extends State<_MessageEditDesktopDialog> {
  late final CodeLineEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CodeLineEditingController();
    _syncControllerText(widget.message.content);
  }

  @override
  void didUpdateWidget(covariant _MessageEditDesktopDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.content != widget.message.content &&
        _controller.text == oldWidget.message.content) {
      _syncControllerText(widget.message.content);
    }
  }

  void _syncControllerText(String text) {
    _controller.setTextSafely(text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    return Dialog(
      elevation: 12,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 520, maxWidth: 720, maxHeight: 680),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Material(
            color: cs.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      Text(l10n.messageEditPageTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          final text = _controller.text.trim();
                          // TODO: Provide user feedback (disable button or show snackbar) when content is empty.
                          if (text.isEmpty) return;
                          Navigator.of(context).pop<MessageEditResult>(
                            MessageEditResult(content: text, shouldSend: true),
                          );
                        },
                        icon: Icon(Lucide.MessageCirclePlus, size: 18, color: cs.primary),
                        label: Text(l10n.messageEditPageSaveAndSend, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: () {
                          final text = _controller.text.trim();
                          // TODO: Provide user feedback (disable button or show snackbar) when content is empty.
                          if (text.isEmpty) return;
                          Navigator.of(context).pop<MessageEditResult>(
                            MessageEditResult(content: text, shouldSend: false),
                          );
                        },
                        icon: Icon(Lucide.Check, size: 18, color: cs.primary),
                        label: Text(l10n.messageEditPageSave, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
                      ),
                      IconButton(
                        tooltip: l10n.mcpPageClose,
                        onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(Lucide.X, size: 18, color: cs.onSurface.withValues(alpha: 0.75)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // Body
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : const Color(0xFFF7F7F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.18),
                          width: 0.6,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: PlainTextCodeEditor(
                        controller: _controller,
                        autofocus: true,
                        hint: l10n.messageEditPageHint,
                        padding: const EdgeInsets.all(12),
                        fontSize: 15,
                        fontHeight: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
