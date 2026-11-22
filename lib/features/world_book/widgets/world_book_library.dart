import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/world_book.dart';
import '../../../core/providers/world_book_provider.dart';
import '../../../core/services/haptics.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/action_sheet.dart';
import '../../../shared/widgets/adaptive_form.dart';
import '../../../shared/widgets/collapsible_group_header.dart';
import '../../../shared/widgets/form_sheet.dart';
import '../../../shared/widgets/ios_settings_rows.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_text_button.dart';
import '../../../shared/widgets/selection_back_scope.dart';
import '../../../shared/widgets/snackbar.dart';
import 'world_book_card_header.dart';
import 'world_book_group_actions.dart';

class WorldBookLibrary extends StatefulWidget {
  const WorldBookLibrary({
    super.key,
    required this.desktop,
    required this.onAddBook,
    required this.onImport,
    required this.buildBook,
  });

  final bool desktop;
  final Future<void> Function({String? groupId}) onAddBook;
  final Future<void> Function({String? groupId}) onImport;
  final Widget Function(
    WorldBook book,
    int index,
    bool canReorder,
    WorldBookSelection? selection,
  )
  buildBook;

  @override
  State<WorldBookLibrary> createState() => _WorldBookLibraryState();
}

class _WorldBookLibraryState extends State<WorldBookLibrary> {
  final _collapsedGroups = <String?>{};
  final _scroll = ScrollController();
  Set<String>? _selectedBooks;
  bool _arranging = false;
  bool _saving = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _leaveEditing() {
    if (_saving) return;
    setState(() {
      _selectedBooks = null;
      _arranging = false;
    });
  }

  void _showSaveError() {
    if (!mounted) return;
    showAppSnackBar(
      context,
      message: AppLocalizations.of(context)!.worldBookGroupSaveFailed,
      type: NotificationType.error,
    );
  }

  Future<bool> _save(Future<void> Function() change) async {
    if (_saving || !mounted) return false;
    setState(() => _saving = true);
    try {
      await change();
      return true;
    } catch (_) {
      _showSaveError();
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editGroupName({String? id}) async {
    final provider = context.read<WorldBookProvider>();
    final name = await promptWorldBookGroupName(context, groupId: id);
    if (name == null || !mounted) return;
    final saved = await _save(() async {
      if (id == null) {
        await provider.createGroup(name);
      } else {
        await provider.renameGroup(id, name);
      }
    });
    if (saved && mounted && id == null && _scroll.hasClients) {
      _scroll.jumpTo(0);
    }
  }

  Future<void> _deleteGroup(String id, String name) async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<WorldBookProvider>();
    final confirmed = await showAdaptiveForm<bool>(
      context,
      desktop: widget.desktop,
      builder: (dialogContext) => AdaptiveForm(
        desktop: widget.desktop,
        title: l10n.worldBookGroupDelete,
        actions: FormSheetActions(
          cancelLabel: l10n.worldBookCancel,
          confirmLabel: l10n.worldBookDelete,
          destructive: true,
          onCancel: () => Navigator.of(dialogContext).pop(),
          onConfirm: () => Navigator.of(dialogContext).pop(true),
        ),
        children: [Text(l10n.worldBookGroupDeleteMessage(name))],
      ),
    );
    if (confirmed != true || !mounted) return;
    final saved = await _save(() => provider.deleteGroup(id));
    if (saved && mounted) {
      setState(() {
        _collapsedGroups.remove(id);
        _collapsedGroups.remove(null);
      });
    }
  }

  Future<void> _moveBooks() async {
    final selected = _selectedBooks;
    if (selected == null || selected.isEmpty) return;
    final provider = context.read<WorldBookProvider>();
    final destination = await chooseWorldBookGroup(
      context,
      desktop: widget.desktop,
      moving: true,
    );
    if (destination == null || !mounted) return;
    final saved = await _save(
      () => provider.moveBooksToGroup(selected, destination.groupId),
    );
    if (saved && mounted) {
      setState(() {
        _selectedBooks = null;
        _collapsedGroups.remove(destination.groupId);
      });
    }
  }

  void _openGroupMenu(BuildContext anchor, String id, String name) {
    final l10n = AppLocalizations.of(context)!;
    _showActions(
      anchor,
      title: name,
      items: [
        ActionSheetItem(
          icon: Lucide.Plus,
          label: l10n.worldBookAdd,
          onTap: () => widget.onAddBook(groupId: id),
        ),
        ActionSheetItem(
          icon: Lucide.Import,
          label: l10n.providersPageImportTooltip,
          onTap: () => widget.onImport(groupId: id),
        ),
        ActionSheetItem(
          icon: Lucide.Pencil,
          label: l10n.worldBookGroupRename,
          onTap: () => _editGroupName(id: id),
        ),
        ActionSheetItem(
          icon: Lucide.Trash2,
          label: l10n.worldBookGroupDelete,
          destructive: true,
          onTap: () => _deleteGroup(id, name),
        ),
      ],
    );
  }

  void _showActions(
    BuildContext anchor, {
    String? title,
    required List<ActionSheetItem> items,
  }) {
    final box = anchor.findRenderObject() as RenderBox;
    showAdaptiveActionMenu(
      context,
      anchor: box.localToGlobal(Offset(0, box.size.height)),
      title: title,
      items: items,
    );
  }

  Widget _groupHeading(String? id, String name, int count) {
    final l10n = AppLocalizations.of(context)!;
    return CollapsibleGroupHeader(
      title: name,
      count: '$count',
      collapsed: _collapsedGroups.contains(id),
      onToggle: count == 0
          ? null
          : () => setState(() {
              if (!_collapsedGroups.remove(id)) _collapsedGroups.add(id);
            }),
      actions: [
        if (id != null && _selectedBooks == null)
          Builder(
            builder: (anchor) => IosIconButton(
              key: ValueKey('world-book-group-menu-$id'),
              icon: Lucide.Ellipsis,
              size: 16,
              minSize: 44,
              tooltip: l10n.worldBookGroupActions,
              semanticLabel: '$name · ${l10n.worldBookGroupActions}',
              enabled: !_saving,
              onTap: () => _openGroupMenu(anchor, id, name),
            ),
          ),
      ],
    );
  }

  Widget _bookList(WorldBookProvider provider, AppLocalizations l10n) {
    final names = _arranging ? const <String, String>{} : provider.groups;
    final selected = _selectedBooks;
    final books = provider.books;
    if (books.isEmpty && names.isEmpty) {
      final color = Theme.of(context).colorScheme.onSurfaceVariant;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Lucide.BookOpen, size: 52, color: color.withValues(alpha: .5)),
            const SizedBox(height: 12),
            Text(l10n.worldBookEmptyMessage, style: TextStyle(color: color)),
          ],
        ),
      );
    }
    final padding = widget.desktop
        ? EdgeInsets.zero
        : const EdgeInsets.symmetric(horizontal: 16);
    return CustomScrollView(
      controller: _scroll,
      slivers: [
        SliverPadding(
          padding: padding.add(EdgeInsets.only(top: names.isEmpty ? 12 : 4)),
          sliver: SliverMainAxisGroup(
            slivers: [
              if (names.isEmpty)
                ..._section(provider, null, null, books, selected)
              else
                for (final id in <String?>[...names.keys, null])
                  if (id != null || provider.booksInGroup(null).isNotEmpty)
                    ..._section(
                      provider,
                      id,
                      id == null ? l10n.worldBookGroupUngrouped : names[id]!,
                      provider.booksInGroup(id),
                      selected,
                    ),
            ],
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: widget.desktop ? 0 : 84)),
      ],
    );
  }

  List<Widget> _section(
    WorldBookProvider provider,
    String? id,
    String? name,
    List<WorldBook> books,
    Set<String>? selected,
  ) {
    final grouped = name != null;
    return [
      if (name != null)
        SliverToBoxAdapter(
          key: ValueKey(('world-book-folder', id)),
          child: _groupHeading(id, name, books.length),
        ),
      if (books.isNotEmpty && (!grouped || !_collapsedGroups.contains(id)))
        SliverReorderableList(
          key: ValueKey(('world-book-folder-contents', id)),
          itemCount: books.length,
          onReorderStart: (_) => Tooltip.dismissAllToolTips(),
          proxyDecorator: _bookDragProxy,
          onReorderItem: (oldIndex, newIndex) async {
            Haptics.light();
            try {
              await provider.reorderBooks(
                group: grouped ? (id: id) : null,
                oldIndex: oldIndex,
                newIndex: newIndex,
              );
            } catch (_) {
              _showSaveError();
            }
          },
          itemBuilder: (context, index) {
            final book = books[index];
            if (_arranging) return _orderRow(book, index);
            return widget.buildBook(
              book,
              index,
              selected == null && books.length > 1,
              selected == null
                  ? null
                  : (
                      checked: selected.contains(book.id),
                      onToggle: () {
                        if (_saving) return;
                        setState(() {
                          if (!selected.remove(book.id)) selected.add(book.id);
                        });
                      },
                    ),
            );
          },
        ),
    ];
  }

  Widget _orderRow(WorldBook book, int index) {
    final l10n = AppLocalizations.of(context)!;
    return IosNavRow(
      key: ValueKey('world-book-order-${book.id}'),
      icon: Lucide.BookOpen,
      label: book.name.trim().isEmpty
          ? l10n.worldBookUnnamed
          : book.name.trim(),
      trailing: ReorderableDragStartListener(
        index: index,
        child: Tooltip(
          message: l10n.worldBookDragToReorder,
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Lucide.GripVertical, size: 18),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bookDragProxy(Widget child, int index, Animation<double> animation) {
    if (widget.desktop) return TooltipVisibility(visible: false, child: child);
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) => Transform.scale(
        scale: 0.985 + 0.015 * Curves.easeOutCubic.transform(animation.value),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorldBookProvider>();
    final l10n = AppLocalizations.of(context)!;
    final selected = _selectedBooks;
    final available = !_saving;
    final title = _arranging
        ? l10n.worldBookOrder
        : selected == null
        ? l10n.worldBookTitle
        : l10n.worldBookGroupSelectedBooks(selected.length);
    final doneButton = IosIconButton(
      icon: _arranging ? Lucide.Check : Lucide.X,
      minSize: 44,
      tooltip: l10n.worldBookSelectionDone,
      enabled: !_saving,
      onTap: _leaveEditing,
    );
    final actions = _arranging
        ? [doneButton]
        : selected == null
        ? [
            if (widget.desktop)
              IosTextButton(
                label: l10n.worldBookGroupNew,
                icon: Lucide.FolderPlus,
                fontSize: 13,
                onPressed: available ? _editGroupName : null,
              )
            else
              IosIconButton(
                icon: Lucide.FolderPlus,
                minSize: 44,
                tooltip: l10n.worldBookGroupNew,
                enabled: available,
                onTap: _editGroupName,
              ),
            if (provider.groups.isNotEmpty && provider.books.isNotEmpty)
              Builder(
                builder: (anchor) => IosIconButton(
                  key: const ValueKey('world-book-library-menu'),
                  icon: Lucide.Ellipsis,
                  minSize: 44,
                  tooltip: l10n.worldBookGroupActions,
                  enabled: available,
                  onTap: () => _showActions(
                    anchor,
                    items: [
                      ActionSheetItem(
                        icon: Lucide.ListChecks,
                        label: l10n.worldBookGroupSelectBooks,
                        onTap: () => setState(() => _selectedBooks = {}),
                      ),
                      if (provider.books.length > 1)
                        ActionSheetItem(
                          icon: Lucide.ListOrdered,
                          label: l10n.worldBookOrder,
                          onTap: () {
                            setState(() => _arranging = true);
                            if (_scroll.hasClients) _scroll.jumpTo(0);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            IosIconButton(
              icon: Lucide.Import,
              minSize: 44,
              tooltip: l10n.providersPageImportTooltip,
              enabled: available,
              onTap: widget.onImport,
            ),
            IosIconButton(
              icon: Lucide.Plus,
              minSize: 44,
              tooltip: l10n.worldBookAdd,
              enabled: available,
              onTap: widget.onAddBook,
            ),
          ]
        : [
            IosTextButton(
              icon: Lucide.FolderInput,
              label: l10n.worldBookGroupMove,
              onPressed: !_saving && selected.isNotEmpty ? _moveBooks : null,
            ),
            doneButton,
          ];
    final body = _bookList(provider, l10n);

    if (widget.desktop) {
      return Container(
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  ...actions,
                ],
              ),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }
    return SelectionBackScope(
      selecting: selected != null || _arranging,
      onCancel: _leaveEditing,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          leading: IosIconButton(
            tooltip: l10n.settingsPageBackButton,
            icon: Lucide.ArrowLeft,
            minSize: 44,
            onTap: () {
              if (selected != null || _arranging) {
                _leaveEditing();
              } else {
                Navigator.of(context).maybePop();
              }
            },
          ),
          title: Text(title),
          actions: [...actions, const SizedBox(width: 8)],
        ),
        body: body,
      ),
    );
  }
}
