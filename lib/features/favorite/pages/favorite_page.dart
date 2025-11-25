import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/favorite_provider.dart';
import '../../../core/models/favorite_item.dart';
import '../../../l10n/app_localizations.dart';
import '../../../icons/lucide_adapter.dart';
import 'favorite_detail_page.dart';
import '../../../core/services/haptics.dart';

/// 移动端收藏列表页面
class FavoritePage extends StatefulWidget {
  const FavoritePage({super.key});

  @override
  State<FavoritePage> createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> {
  final Set<String> _expandedGroups = {};
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final favorites = context.watch<FavoriteProvider>().favorites;

    // 按话题分组
    final groups = _groupByTitle(favorites);

    // 初始化时默认展开所有分组
    if (!_initialized && groups.isNotEmpty) {
      _initialized = true;
      for (final group in groups) {
        _expandedGroups.add(group.title);
      }
    }

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
        title: Text(l10n.favoritePageTitle),
      ),
      body: favorites.isEmpty
          ? _EmptyState()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _calculateListItemCount(groups),
              itemBuilder: (context, index) {
                return _buildListItem(context, groups, index);
              },
            ),
    );
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

    return grouped.entries.map((entry) {
      return _FavoriteGroup(
        title: entry.key,
        items: entry.value,
      );
    }).toList();
  }

  // 计算列表项总数
  int _calculateListItemCount(List<_FavoriteGroup> groups) {
    int count = 0;
    for (final group in groups) {
      count++; // 分组标题
      if (_expandedGroups.contains(group.title)) {
        count += group.items.length;
      }
    }
    return count;
  }

  // 构建列表项
  Widget _buildListItem(BuildContext context, List<_FavoriteGroup> groups, int index) {
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

      // 分组项
      if (_expandedGroups.contains(group.title)) {
        for (final item in group.items) {
          if (currentIndex == index) {
            return _FavoriteTile(
              item: item,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FavoriteDetailPage(item: item),
                  ),
                );
              },
              onDelete: () => _confirmDelete(context, item),
            );
          }
          currentIndex++;
        }
      }
    }

    return const SizedBox.shrink();
  }

  Future<void> _confirmDelete(BuildContext context, FavoriteItem item) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.favoritePageDeleteTitle),
        content: Text(l10n.favoritePageDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.favoritePageCancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.favoritePageDeleteButton),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<FavoriteProvider>().deleteFavorite(item.id);
    }
  }
}

class _FavoriteGroup {
  final String title;
  final List<FavoriteItem> items;

  _FavoriteGroup({required this.title, required this.items});
}

/// 分组标题
class _GroupHeader extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        Haptics.light();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            AnimatedRotation(
              turns: isExpanded ? 0.25 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Lucide.ChevronRight,
                size: 18,
                color: cs.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$itemCount',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 收藏列表项
class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  final FavoriteItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final question = item.question.trim();
    final displayText = question.isEmpty
        ? AppLocalizations.of(context)!.favoritePageEmpty
        : question.split('\n').first.trim();

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: cs.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Lucide.Trash2, color: cs.onError),
      ),
      confirmDismiss: (direction) async {
        Haptics.medium();
        final l10n = AppLocalizations.of(context)!;
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.favoritePageDeleteTitle),
            content: Text(l10n.favoritePageDeleteMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.favoritePageCancelButton),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: cs.error,
                ),
                child: Text(l10n.favoritePageDeleteButton),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        context.read<FavoriteProvider>().deleteFavorite(item.id);
      },
      child: InkWell(
        onTap: () {
          Haptics.light();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          margin: const EdgeInsets.only(left: 26, bottom: 6),
          decoration: BoxDecoration(
            color: cs.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            displayText,
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurface.withOpacity(0.85),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

/// 空状态
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Lucide.Star,
            size: 64,
            color: cs.onSurface.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.favoritePageEmpty,
            style: TextStyle(
              fontSize: 16,
              color: cs.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.favoritePageEmptyHint,
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withOpacity(0.4),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
