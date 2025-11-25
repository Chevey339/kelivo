import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/favorite_item.dart';
import '../../../core/models/chat_message.dart';
import '../../../l10n/app_localizations.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../features/chat/widgets/chat_message_widget.dart';
import '../../../core/services/haptics.dart';

/// 移动端收藏详情页面
class FavoriteDetailPage extends StatelessWidget {
  const FavoriteDetailPage({
    super.key,
    required this.item,
  });

  final FavoriteItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    // 创建虚拟的ChatMessage对象用于渲染
    final userMessage = ChatMessage(
      role: 'user',
      content: item.question,
      conversationId: 'favorite',
      timestamp: item.createdAt,
    );

    final assistantMessage = ChatMessage(
      role: 'assistant',
      content: item.answer,
      conversationId: 'favorite',
      timestamp: item.createdAt,
      providerId: item.providerId,
      modelId: item.modelId,
    );

    return Scaffold(
      appBar: AppBar(
        leading: Tooltip(
          message: l10n.favoriteDetailBackTooltip,
          child: _TactileIconButton(
            icon: Lucide.ArrowLeft,
            color: cs.onSurface,
            size: 22,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Tooltip(
            message: l10n.favoriteDetailCopyAllTooltip,
            child: _TactileIconButton(
              icon: Lucide.Copy,
              color: cs.onSurface,
              size: 20,
              onTap: () => _copyAll(context),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 话题名称信息栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surfaceVariant.withOpacity(0.3),
              border: Border(
                bottom: BorderSide(
                  color: cs.outlineVariant.withOpacity(0.12),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Lucide.MessageCircle,
                  size: 14,
                  color: cs.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 消息列表
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 用户消息
                ChatMessageWidget(
                  message: userMessage,
                  showUserAvatar: true,
                  showModelIcon: false,
                  showTokenStats: false,
                ),
                const SizedBox(height: 16),
                // 助手消息
                ChatMessageWidget(
                  message: assistantMessage,
                  showModelIcon: item.providerId != null && item.modelId != null,
                  useAssistantAvatar: false,
                  showTokenStats: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _copyAll(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final text = '问题：\n${item.question}\n\n回答：\n${item.answer}';
    Clipboard.setData(ClipboardData(text: text));
    Haptics.light();
    showAppSnackBar(
      context,
      message: l10n.favoriteDetailCopiedAll,
      type: NotificationType.success,
    );
  }
}

/// 触觉反馈图标按钮
class _TactileIconButton extends StatelessWidget {
  const _TactileIconButton({
    required this.icon,
    required this.color,
    required this.size,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: color, size: size),
      onPressed: () {
        Haptics.light();
        onTap();
      },
    );
  }
}
