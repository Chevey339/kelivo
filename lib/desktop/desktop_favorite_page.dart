import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:provider/provider.dart';
import '../core/providers/favorite_provider.dart';
import '../core/models/favorite_item.dart';
import '../l10n/app_localizations.dart';
import '../icons/lucide_adapter.dart' as lucide;
import 'favorite_detail_page.dart';
import '../desktop/desktop_context_menu.dart';

/// 桌面收藏页面 - 左侧列表 + 右侧详情
class DesktopFavoritePage extends StatefulWidget {
  const DesktopFavoritePage({super.key});

  @override
  State<DesktopFavoritePage> createState() => _DesktopFavoritePageState();
}

class _DesktopFavoritePageState extends State<DesktopFavoritePage> {
  String? _selectedId;
  final Set<String> _expandedGroups = {}; // 记录展开的分组
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoriteProvider>().favorites;
    final cs = Theme.of(context).colorScheme;

    // 按话题分组
    final groups = _groupByTitle(favorites);
    
    // 初始化时默认展开所有分组
    if (!_initialized && groups.isNotEmpty) {
      _initialized = true;
      for (final group in groups) {
        _expandedGroups.add(group.title);
      }
    }

    // 如果有选中项但不在列表中，清除选中
    if (_selectedId != null && !favorites.any((f) => f.id == _selectedId)) {
      _selectedId = null;
    }

    // 如果没有选中项且列表不为空，选中第一项
    if (_selectedId == null && favorites.isNotEmpty) {
      _selectedId = favorites.first.id;
    }

    final selectedItem = _selectedId != null
        ? favorites.firstWhere((f) => f.id == _selectedId, orElse: () => favorites.first)
        : null;

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        children: [
          // 左侧列表
          Container(
            width: 300,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: cs.outlineVariant.withOpacity(0.12),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 标题栏
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '收藏', // TODO: 添加到本地化
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: cs.outlineVariant.withOpacity(0.12),
                ),
                // 列表
                Expanded(
                  child: favorites.isEmpty
                      ? _EmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          itemCount: _calculateListItemCount(groups),
                          itemBuilder: (context, index) {
                            return _buildListItem(context, groups, index, cs);
                          },
                        ),
                ),
              ],
            ),
          ),
          // 右侧详情
          Expanded(
            child: selectedItem != null
                ? FavoriteDetailPage(item: selectedItem, embedded: true)
                : Center(
                    child: Text(
                      '选择一个收藏查看详情',
                      style: TextStyle(
                        fontSize: 14,
                        color: cs.onSurface.withOpacity(0.5),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, FavoriteItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteConfirmDialog(),
    );

    if (confirmed == true && context.mounted) {
      await context.read<FavoriteProvider>().deleteFavorite(item.id);
    }
  }

  // 按话题标题分组
  List<_FavoriteGroup> _groupByTitle(List<FavoriteItem> favorites) {
    final Map<String, List<FavoriteItem>> grouped = {};
    
    for (final item in favorites) {
      if (!grouped.containsKey(item.title)) {
        grouped[item.title] = [];
      }
      grouped[item.title]!.add(item);
    }

    // 转换为分组列表，保持收藏顺序
    return grouped.entries.map((entry) {
      return _FavoriteGroup(
        title: entry.key,
        items: entry.value,
      );
    }).toList();
  }

  // 计算列表项总数（包括分组标题和展开的项）
  int _calculateListItemCount(List<_FavoriteGroup> groups) {
    int count = 0;
    for (final group in groups) {
      count++; // 分组标题
      if (_expandedGroups.contains(group.title)) {
        count += group.items.length; // 展开时显示分组项
      }
    }
    return count;
  }

  // 构建列表项（分组标题或收藏项）
  Widget _buildListItem(BuildContext context, List<_FavoriteGroup> groups, int index, ColorScheme cs) {
    int currentIndex = 0;
    
    for (final group in groups) {
      // 分组标题
      if (currentIndex == index) {
        final isExpanded = _expandedGroups.contains(group.title);
        return _GroupHeader(
          title: group.title,
          itemCount: group.items.length,
          isExpanded: isExpanded,
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedGroups.remove(group.title);
              } else {
                _expandedGroups.add(group.title);
              }
            });
          },
        );
      }
      currentIndex++;

      // 分组项（仅在展开时显示）
      if (_expandedGroups.contains(group.title)) {
        for (final item in group.items) {
          if (currentIndex == index) {
            return Padding(
              padding: const EdgeInsets.only(left: 18), // 向右缩进，与标题首字对齐
              child: _FavoriteTile(
                item: item,
                selected: item.id == _selectedId,
                onTap: () => setState(() => _selectedId = item.id),
                onDelete: () => _confirmDelete(context, item),
                showTitle: false, // 在分组下不显示标题
              ),
            );
          }
          currentIndex++;
        }
      }
    }

    return const SizedBox.shrink();
  }
}

class _FavoriteGroup {
  final String title;
  final List<FavoriteItem> items;
  
  _FavoriteGroup({required this.title, required this.items});
}

/// 分组标题 - 可展开/折叠
class _GroupHeader extends StatefulWidget {
  const _GroupHeader({
    required this.title,
    required this.itemCount,
    required this.isExpanded,
    required this.onTap,
  });

  final String title;
  final int itemCount;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  State<_GroupHeader> createState() => _GroupHeaderState();
}

class _GroupHeaderState extends State<_GroupHeader> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.only(top: 8, bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered
                ? (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              // 展开/折叠图标
              AnimatedRotation(
                turns: widget.isExpanded ? 0.25 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  lucide.Lucide.ChevronRight,
                  size: 16,
                  color: cs.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(width: 6),
              // 标题
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                    decoration: TextDecoration.none,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // 数量标签
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${widget.itemCount}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                    decoration: TextDecoration.none,
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

/// 收藏列表项 - 类似话题列表样式
class _FavoriteTile extends StatefulWidget {
  const _FavoriteTile({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onDelete,
    this.showTitle = true,
  });

  final FavoriteItem item;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool showTitle; // 是否显示标题（在分组下不显示）

  @override
  State<_FavoriteTile> createState() => _FavoriteTileState();
}

class _FavoriteTileState extends State<_FavoriteTile> {
  bool _hovered = false;
  bool get _isDesktop => defaultTargetPlatform == TargetPlatform.macOS || 
                         defaultTargetPlatform == TargetPlatform.windows || 
                         defaultTargetPlatform == TargetPlatform.linux;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapUp: _isDesktop ? (details) => _showContextMenu(details.globalPosition) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.selected
                ? cs.primary.withOpacity(0.12)
                : _hovered
                    ? (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03))
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.showTitle ? widget.item.title : _getDisplayText(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
                    color: widget.selected ? cs.primary : cs.onSurface,
                    decoration: TextDecoration.none,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(Offset globalPosition) async {
    await showDesktopContextMenuAt(
      context,
      globalPosition: globalPosition,
      items: [
        DesktopContextMenuItem(
          icon: lucide.Lucide.Trash2,
          label: '删除',
          danger: true,
          onTap: widget.onDelete,
        ),
      ],
    );
  }

  // 获取显示文本（在分组下显示问题的简略内容）
  String _getDisplayText() {
    final question = widget.item.question.trim();
    if (question.isEmpty) return '空内容';
    
    // 移除换行符，只显示第一行
    final firstLine = question.split('\n').first.trim();
    const maxLength = 50;
    
    if (firstLine.length <= maxLength) return firstLine;
    return '${firstLine.substring(0, maxLength)}...';
  }
}

/// 空状态
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            lucide.Lucide.Star,
            size: 64,
            color: cs.onSurface.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          DefaultTextStyle(
            style: TextStyle(
              fontSize: 16,
              color: cs.onSurface.withOpacity(0.5),
              decoration: TextDecoration.none,
            ),
            child: const Text('暂无收藏'),
          ),
          const SizedBox(height: 8),
          DefaultTextStyle(
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withOpacity(0.4),
              decoration: TextDecoration.none,
            ),
            child: const Text('在聊天中点击收藏按钮添加收藏'),
          ),
        ],
      ),
    );
  }
}

/// 删除确认对话框
class _DeleteConfirmDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题栏
            SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '删除收藏',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(lucide.Lucide.X, size: 18),
                      color: cs.onSurface,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, thickness: 0.5, color: cs.outlineVariant.withOpacity(0.12)),
            // 内容
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '确定要删除这条收藏吗？此操作无法撤销。',
                    style: TextStyle(
                      color: cs.onSurface.withOpacity(0.9),
                      fontSize: 13.5,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _DialogButton(
                        label: '取消',
                        filled: false,
                        onTap: () => Navigator.of(context).pop(false),
                      ),
                      const SizedBox(width: 8),
                      _DialogButton(
                        label: '删除',
                        filled: true,
                        danger: true,
                        onTap: () => Navigator.of(context).pop(true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 对话框按钮
class _DialogButton extends StatefulWidget {
  const _DialogButton({
    required this.label,
    required this.onTap,
    this.filled = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;
  final bool danger;

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton> {
  bool _pressed = false;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = widget.danger ? cs.error : cs.primary;
    final textColor = widget.filled ? (widget.danger ? cs.onError : cs.onPrimary) : baseColor;
    final baseBg = widget.filled ? baseColor : (isDark ? Colors.white10 : Colors.transparent);
    final hoverBg = widget.filled
        ? baseColor.withOpacity(0.92)
        : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04));
    final bg = _hover ? hoverBg : baseBg;
    final borderColor = widget.filled ? Colors.transparent : baseColor.withOpacity(isDark ? 0.6 : 0.5);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textColor,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
