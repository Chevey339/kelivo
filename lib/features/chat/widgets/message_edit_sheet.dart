import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import '../../../core/models/chat_message.dart';
import '../models/message_edit_result.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/plain_text_code_editor.dart';
import '../../../core/services/haptics.dart';
import '../../../utils/re_editor_utils.dart';

Future<MessageEditResult?> showMessageEditSheet(BuildContext context, {required ChatMessage message}) async {
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<MessageEditResult?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(top: false, child: _MessageEditSheet(message: message)),
  );
}

class _MessageEditSheet extends StatefulWidget {
  const _MessageEditSheet({required this.message});
  final ChatMessage message;
  @override
  State<_MessageEditSheet> createState() => _MessageEditSheetState();
}

class _MessageEditSheetState extends State<_MessageEditSheet> {
  late final CodeLineEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CodeLineEditingController();
    _syncControllerText(widget.message.content);
  }

  @override
  void didUpdateWidget(covariant _MessageEditSheet oldWidget) {
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
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      // Ensure keyboard-safe bottom inset for the sheet
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (c, sc) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            children: [
              Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurface.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999))),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 32,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IosCardPress(
                        onTap: () {
                          Haptics.light();
                          final text = _controller.text.trim();
                          // TODO: Provide user feedback (disable button or show snackbar) when content is empty.
                          if (text.isEmpty) return;
                          Navigator.of(context).pop<MessageEditResult>(
                            MessageEditResult(content: text, shouldSend: true),
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        baseColor: Colors.transparent,
                        pressedBlendStrength: Theme.of(context).brightness == Brightness.dark ? 0.10 : 0.06,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Text(l10n.messageEditPageSaveAndSend, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    Center(
                      child: Text(
                        l10n.messageEditPageTitle,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IosCardPress(
                        onTap: () {
                          Haptics.light();
                          final text = _controller.text.trim();
                          // TODO: Provide user feedback (disable button or show snackbar) when content is empty.
                          if (text.isEmpty) return;
                          Navigator.of(context).pop<MessageEditResult>(
                            MessageEditResult(content: text, shouldSend: false),
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        baseColor: Colors.transparent,
                        pressedBlendStrength: Theme.of(context).brightness == Brightness.dark ? 0.10 : 0.06,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Text(l10n.messageEditPageSave, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF2F3F5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: PlainTextCodeEditor(
                    controller: _controller,
                    autofocus: false,
                    hint: l10n.messageEditPageHint,
                    padding: const EdgeInsets.all(16),
                    fontSize: 15,
                    fontHeight: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
