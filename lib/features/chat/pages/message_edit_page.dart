import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import '../../../core/models/chat_message.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/plain_text_code_editor.dart';

class MessageEditPage extends StatefulWidget {
  const MessageEditPage({super.key, required this.message});
  final ChatMessage message;

  @override
  State<MessageEditPage> createState() => _MessageEditPageState();
}

class _MessageEditPageState extends State<MessageEditPage> {
  late final CodeLineEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CodeLineEditingController.fromText(widget.message.content);
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
              style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF2F3F5),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: PlainTextCodeEditor(
              controller: _controller,
              autofocus: true,
              hint: l10n.messageEditPageHint,
              padding: const EdgeInsets.all(16),
              fontSize: 15,
              fontHeight: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
