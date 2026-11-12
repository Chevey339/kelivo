import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/models/image_context.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../shared/widgets/snackbar.dart';
import '../utils/ensure_conversation.dart';

/// Shared conversation setting behind the mobile and desktop tool rows.
class ImageRecallControl extends StatefulWidget {
  const ImageRecallControl({
    super.key,
    required this.assistantId,
    required this.conversationId,
    required this.builder,
  });

  final String assistantId;
  final String? conversationId;
  final Widget Function(bool enabled, ValueChanged<bool>? onChanged) builder;

  @override
  State<ImageRecallControl> createState() => _ImageRecallControlState();
}

class _ImageRecallControlState extends State<ImageRecallControl>
    with AutomaticKeepAliveClientMixin {
  String? _draftId;
  (ChatService, String?, int)? _source;
  Future<ImageContextSettings>? _settings;
  bool _saving = false;

  // Keep the draft conversation selected by this control while a desktop
  // tool row scrolls out of the lazily built popover.
  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(ImageRecallControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId ||
        oldWidget.assistantId != widget.assistantId) {
      _draftId = null;
    }
  }

  Future<void> _save(bool enabled) async {
    if (_saving) return;
    final chat = context.read<ChatService>();
    final conversationId = widget.conversationId;
    final assistantId = widget.assistantId;
    setState(() => _saving = true);
    try {
      final id = await ensureConversationId(
        context,
        conversationId: conversationId ?? _draftId,
        assistantId: assistantId,
      );
      if (id == null) return;
      final current = await chat.imageContextSettings(id);
      await chat.setImageContextSettings(
        id,
        ImageContextSettings(
          automatic: current.automatic,
          allowRecall: enabled,
          pinned: current.pinned,
        ),
      );
      if (mounted &&
          widget.conversationId == conversationId &&
          widget.assistantId == assistantId) {
        _draftId = id;
      }
    } catch (error) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: error.toString(),
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final chat = context.watch<ChatService>();
    final id = widget.conversationId ?? _draftId;
    final source = (chat, id, id == null ? 0 : chat.contextRevision(id));
    if (source != _source) {
      _source = source;
      _settings = id == null
          ? Future.value(const ImageContextSettings())
          : chat.imageContextSettings(id);
    }
    return FutureBuilder<ImageContextSettings>(
      key: ValueKey(id),
      future: _settings,
      builder: (context, snapshot) => widget.builder(
        snapshot.data?.allowRecall ?? false,
        _saving || !snapshot.hasData ? null : _save,
      ),
    );
  }
}
