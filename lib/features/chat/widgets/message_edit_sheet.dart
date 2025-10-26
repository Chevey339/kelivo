import 'package:flutter/material.dart';
import '../../../core/models/chat_message.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../core/services/haptics.dart';

Future<String?> showMessageEditSheet(BuildContext context, {required ChatMessage message}) async {
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<String?>(
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
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.message.content);
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
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(999))),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 32,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Invisible left button to balance layout so title truly centers
                    Opacity(
                      opacity: 0,
                      child: IgnorePointer(
                        child: IosCardPress(
                          onTap: () {},
                          borderRadius: BorderRadius.circular(20),
                          baseColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Text(l10n.messageEditPageSave, style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          l10n.messageEditPageTitle,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    IosCardPress(
                      onTap: () {
                        Haptics.light();
                        final text = _controller.text.trim();
                        Navigator.of(context).pop<String>(text);
                      },
                      borderRadius: BorderRadius.circular(20),
                      baseColor: Colors.transparent,
                      pressedBlendStrength: Theme.of(context).brightness == Brightness.dark ? 0.10 : 0.06,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Text(l10n.messageEditPageSave, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  controller: sc,
                  child: TextField(
                    controller: _controller,
                    autofocus: false,
                    keyboardType: TextInputType.multiline,
                    minLines: 8,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: l10n.messageEditPageHint,
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF2F3F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Colors.transparent),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Colors.transparent),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: cs.primary.withOpacity(0.45)),
                      ),
                    ),
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
