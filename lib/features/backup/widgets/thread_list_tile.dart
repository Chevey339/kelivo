import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/unified_thread.dart';
import 'source_badge.dart';

/// A list tile displaying a unified thread summary.
class ThreadListTile extends StatelessWidget {
  final UnifiedThread thread;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const ThreadListTile({
    super.key,
    required this.thread,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMd().add_jm();

    return ListTile(
      leading: _sourceIcon(thread.source),
      title: Text(
        thread.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Row(
        children: [
          SourceBadge(source: thread.source),
          const SizedBox(width: 8),
          Text(
            '${thread.messages.length} msgs',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            dateFormat.format(thread.updatedAt),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
      trailing: onDelete != null
          ? IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 20,
                color: theme.colorScheme.error,
              ),
              onPressed: onDelete,
            )
          : null,
      onTap: onTap,
    );
  }

  Widget _sourceIcon(String source) {
    switch (source) {
      case 'chatgpt':
        return const Icon(Icons.chat_bubble_outline, color: Color(0xFF10A37F));
      case 'gemini':
        return const Icon(Icons.auto_awesome, color: Color(0xFF4285F4));
      case 'perplexity':
        return const Icon(Icons.travel_explore, color: Color(0xFF5436DA));
      case 'claude':
        return const Icon(Icons.psychology_outline, color: Color(0xFFD97706));
      case 'kelivo':
        return const Icon(Icons.message_outline, color: Color(0xFF6366F1));
      default:
        return const Icon(Icons.forum_outlined, color: Colors.grey);
    }
  }
}
