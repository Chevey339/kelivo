import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/models/context_compression_task.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/text_input/message_editing_controller.dart';
import '../../../shared/widgets/ios_text_button.dart';
import '../../../shared/widgets/long_message_editor.dart';
import '../../../theme/app_semantic_colors.dart';
import '../widgets/context_dialog.dart';

class ContextSummaryEditorPage extends StatefulWidget {
  const ContextSummaryEditorPage({
    super.key,
    required this.summary,
    required this.onSave,
    this.estimate,
    this.budget,
  });
  final String summary;
  final Future<bool> Function(String) onSave;
  final Future<CompressionBudget?> Function(String)? estimate;
  final CompressionBudget? budget;
  @override
  State<ContextSummaryEditorPage> createState() =>
      _ContextSummaryEditorPageState();
}

class _ContextSummaryEditorPageState extends State<ContextSummaryEditorPage> {
  late final MessageEditingController _editor = MessageEditingController(
    text: widget.summary,
  );
  CompressionBudget? _budget;
  Timer? _debounce;
  int _revision = 0;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _budget = widget.budget;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _editor.dispose();
    super.dispose();
  }

  void _changed(String text) {
    setState(() => _error = null);
    final revision = ++_revision;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () async {
      try {
        final budget = await widget.estimate?.call(text);
        if (mounted && revision == _revision) setState(() => _budget = budget);
      } catch (_) {
        /* An unavailable estimate does not discard the edit. */
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    await _editor.flushMessageInput();
    if (!mounted || _editor.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final saved = await widget.onSave(_editor.text);
      if (mounted && saved) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final empty = _editor.text.trim().isEmpty;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 72,
        leading: IosTextButton(
          label: l10n.homePageCancel,
          color: cs.onSurfaceVariant,
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
        ),
        title: Text(
          l10n.contextEditTitle,
          style: const TextStyle(fontSize: 17),
        ),
        centerTitle: true,
        actions: [
          IosTextButton(
            label: l10n.messageEditPageSave,
            onPressed: _saving || empty ? null : _save,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: LongMessageEditor(
                  controller: _editor,
                  autofocus: true,
                  minLines: null,
                  maxLines: null,
                  expands: true,
                  onChanged: _changed,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: context.appColors.surfaceFill,
                    hintText: l10n.contextEditTitle,
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: cs.primary.withValues(alpha: .45),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: cs.primary.withValues(alpha: .45),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: cs.primary, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _error ??
                    (empty
                        ? l10n.contextEditEmpty
                        : _budget == null
                        ? l10n.contextSummaryHint
                        : l10n.contextEditPreview(
                            contextTokenValue(_budget!.usedTokens),
                          )),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: empty || _error != null
                      ? cs.error
                      : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
