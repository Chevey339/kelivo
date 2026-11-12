import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import '../models/ui_context_attachment.dart';
import '../widgets/genui_context_chip.dart';

/// Validity belongs to message storage, never to viewport/controller presence.
class UiComposerContextChip extends StatefulWidget {
  const UiComposerContextChip({
    super.key,
    required this.attachment,
    required this.onRemove,
  });
  final UiContextAttachment attachment;
  final VoidCallback? onRemove;
  @override
  State<UiComposerContextChip> createState() => _UiComposerContextChipState();
}

class _UiComposerContextChipState extends State<UiComposerContextChip> {
  ChatService? _service;
  bool _stale = false, _checking = false, _again = false;
  int _epoch = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bind();
  }

  @override
  void didUpdateWidget(UiComposerContextChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment != widget.attachment) {
      _epoch++;
      _stale = false;
      _bind();
    }
  }

  void _bind() {
    final service = widget.attachment.previouslySent
        ? null
        : context.read<ChatService>();
    if (_service != service) {
      _service?.removeListener(_changed);
      _service = service;
      _service?.addListener(_changed);
    }
    _changed();
  }

  void _changed() {
    if (_checking) {
      _again = true;
      return;
    }
    unawaited(_check());
  }

  Future<void> _check() async {
    final source = widget.attachment.source, epoch = _epoch;
    if (source == null || _service == null) return;
    _checking = true;
    try {
      final valid = await _service!.isUiContextCurrent(source);
      if (mounted && epoch == _epoch && _stale == valid) {
        setState(() => _stale = !valid);
      }
    } catch (_) {
      // A transient read failure does not prove deletion. Final send performs
      // an authoritative check in its write transaction and can report errors.
    } finally {
      _checking = false;
      if (mounted && _again) {
        _again = false;
        _changed();
      }
    }
  }

  @override
  void dispose() {
    _epoch++;
    _service?.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GenUiContextChip(
    content: widget.attachment.text,
    stale: _stale,
    onRemove: widget.onRemove,
  );
}
