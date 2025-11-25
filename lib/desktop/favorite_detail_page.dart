import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/models/favorite_item.dart';
import '../core/models/chat_message.dart';
import '../icons/lucide_adapter.dart' as lucide;
import '../shared/widgets/snackbar.dart';
import '../features/chat/widgets/chat_message_widget.dart';
import 'package:provider/provider.dart';
import '../core/providers/user_provider.dart';
import '../core/providers/assistant_provider.dart';
import '../core/providers/settings_provider.dart';
import '../utils/brand_assets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:characters/characters.dart';
import '../l10n/app_localizations.dart';

/// 收藏详情页面
class FavoriteDetailPage extends StatelessWidget {
  const FavoriteDetailPage({
    super.key, 
    required this.item,
    this.embedded = false,
  });

  final FavoriteItem item;
  final bool embedded; // 是否嵌入在其他页面中

  @override
  Widget build(BuildContext context) {
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

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 顶部标题栏
        if (!embedded)
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _IconButton(
                  icon: lucide.Lucide.ArrowLeft,
                  onTap: () => Navigator.of(context).pop(),
                  tooltip: AppLocalizations.of(context)!.favoriteDetailBackTooltip,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _IconButton(
                  icon: lucide.Lucide.Copy,
                  onTap: () => _copyAll(context),
                  tooltip: AppLocalizations.of(context)!.favoriteDetailCopyAllTooltip,
                ),
              ],
            ),
          ),
        if (!embedded)
          Divider(
            height: 1,
            thickness: 0.5,
            color: cs.outlineVariant.withOpacity(0.12),
          ),
        // 话题名称信息栏
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                lucide.Lucide.MessageCircle,
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
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        // 消息列表
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(embedded ? 16 : 24),
            children: [
              // 用户消息
              ChatMessageWidget(
                message: userMessage,
                showUserAvatar: true,
                showModelIcon: false,
                showTokenStats: false,
              ),
              const SizedBox(height: 16),
              // 助手消息 - 显示模型图标和名称
              ChatMessageWidget(
                message: assistantMessage,
                modelIcon: (item.providerId != null && item.modelId != null)
                    ? _ModelIcon(
                        providerKey: item.providerId!,
                        modelId: item.modelId!,
                      )
                    : null,
                showModelIcon: true,
                useAssistantAvatar: false,
                showTokenStats: false,
              ),
            ],
          ),
        ),
      ],
    );

    if (embedded) {
      return body;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: body,
    );
  }

  void _copyText(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    showAppSnackBar(context, message: message, type: NotificationType.success);
  }

  void _copyAll(BuildContext context) {
    final text = '问题：\n${item.question}\n\n回答：\n${item.answer}';
    Clipboard.setData(ClipboardData(text: text));
    showAppSnackBar(
      context, 
      message: AppLocalizations.of(context)!.favoriteDetailCopiedAll, 
      type: NotificationType.success,
    );
  }
}

/// 模型图标
class _ModelIcon extends StatelessWidget {
  const _ModelIcon({
    required this.providerKey,
    required this.modelId,
  });

  final String providerKey;
  final String modelId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    String? asset = BrandAssets.assetForName(modelId);
    asset ??= BrandAssets.assetForName(providerKey);
    
    Widget inner;
    if (asset != null) {
      if (asset.endsWith('.svg')) {
        final isColorful = asset.contains('color');
        final ColorFilter? tint = (isDark && !isColorful)
            ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
            : null;
        inner = SvgPicture.asset(
          asset,
          width: 15,
          height: 15,
          colorFilter: tint,
        );
      } else {
        inner = Image.asset(asset, width: 15, height: 15, fit: BoxFit.contain);
      }
    } else {
      inner = Text(
        modelId.isNotEmpty ? modelId.characters.first.toUpperCase() : '?',
        style: TextStyle(
          color: cs.primary,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      );
    }
    
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : cs.primary.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: inner,
    );
  }
}

/// 图标按钮
class _IconButton extends StatefulWidget {
  const _IconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  State<_IconButton> createState() => _IconButtonState();
}

class _IconButtonState extends State<_IconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _hover
                  ? (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(
              widget.icon,
              size: 18,
              color: cs.onSurface.withOpacity(0.8),
            ),
          ),
        ),
      ),
    );
  }
}
