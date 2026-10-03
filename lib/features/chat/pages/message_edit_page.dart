import 'package:flutter/material.dart';
import '../../../core/models/chat_message.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_font_weights.dart';
import '../../../shared/widgets/long_message_editor.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

class MessageEditPage extends StatefulWidget {
  const MessageEditPage({super.key, required this.message});
  final ChatMessage message;

  @override
  State<MessageEditPage> createState() => _MessageEditPageState();
}

class _MessageEditPageState extends State<MessageEditPage> {
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
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.messageEditPageTitle),
        actions: [
          TextButton(
            onPressed: () {
              final text = _controller.text.trim();
              Navigator.of(context).pop<String>(text);
            },
            child: Text(
              l10n.messageEditPageSave,
              style: TextStyle(
                color: cs.primary,
                fontWeight: AppFontWeights.emphasis,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LongMessageEditor(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.messageEditPageHint,
              filled: true,
              fillColor: context.appColors.surfaceFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.transparent),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.transparent),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: cs.primary.withValues(alpha: 0.45),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
