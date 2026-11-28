import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/chat/chat_service.dart';
import '../../../core/services/storage/storage_image_source.dart';
import '../../../core/services/storage/storage_usage_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_settings_rows.dart';

class StorageImageSources extends StatefulWidget {
  const StorageImageSources({
    super.key,
    required this.entry,
    required this.onFound,
  });
  final StorageFileEntry entry;
  final void Function(String conversationId, String messageId) onFound;

  @override
  State<StorageImageSources> createState() => _StorageImageSourcesState();
}

class _StorageImageSourcesState extends State<StorageImageSources> {
  String? _searching;
  ({String id, String text})? _notice;

  bool _canOpen(String id) {
    final chat = context.read<ChatService?>();
    return chat != null &&
        !chat.isTemporaryConversation(chat.currentConversationId) &&
        !chat.isTemporaryConversation(id);
  }

  Future<void> _find(String id) async {
    if (_searching != null || !_canOpen(id)) return;
    final route = ModalRoute.of(context);
    final l10n = AppLocalizations.of(context)!;
    bool current() => mounted && route?.isCurrent != false;
    setState(() {
      _searching = id;
      _notice = null;
    });
    try {
      final result = await findStorageImageSource(
        path: widget.entry.path,
        conversationId: id,
        isCurrent: current,
      );
      if (!current() || !_canOpen(id)) return;
      if (result.messageId case final messageId?) {
        widget.onFound(id, messageId);
        return;
      }
      _notice = (
        id: id,
        text: result.busy
            ? l10n.storageImageSourceBusy
            : l10n.storageImageSourceNotFound,
      );
    } catch (_) {
      if (current()) _notice = (id: id, text: l10n.storageImageSourceFailed);
    } finally {
      if (mounted) setState(() => _searching = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final chats = widget.entry.conversations.entries.toList(growable: false);
    return ListView.builder(
      shrinkWrap: true,
      itemCount: chats.length,
      itemBuilder: (context, index) {
        final chat = chats[index];
        final enabled = _canOpen(chat.key);
        return IosNavRow(
          label: chat.value.trim().isEmpty
              ? l10n.incomingShareNewChat
              : chat.value,
          subtitle: _notice?.id == chat.key
              ? _notice?.text
              : enabled
              ? l10n.storageImageShowSource
              : null,
          subtitleMaxLines: null,
          focusable: enabled,
          onTap: enabled && _searching == null ? () => _find(chat.key) : null,
          trailing: _searching == chat.key
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
        );
      },
    );
  }
}
