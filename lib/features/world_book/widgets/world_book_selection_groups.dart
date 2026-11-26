import 'package:flutter/material.dart';

import '../../../core/models/world_book.dart';
import '../../../core/providers/world_book_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/collapsible_group_header.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../chat/utils/prompt_injection_selection.dart';

Iterable<Widget> worldBookSelectionRows({
  required WorldBookProvider provider,
  required Set<String> selectedIds,
  required Widget Function(WorldBook) buildBook,
  String? assistantId,
  String? conversationId,
}) sync* {
  final names = provider.groups;
  if (names.isEmpty) {
    yield* provider.books.map(buildBook);
    return;
  }
  final booksByGroup = <String?, List<WorldBook>>{};
  for (final book in provider.books) {
    final groupId = provider.groupIdForBook(book.id);
    (booksByGroup[groupId] ??= []).add(book);
  }
  for (final id in [...names.keys, null]) {
    final books = booksByGroup[id];
    if (books == null) continue;
    yield _WorldBookSelectionGroup(
      key: ValueKey('world-book-selection-group-${id ?? 'ungrouped'}'),
      name: names[id],
      books: books,
      selectedIds: selectedIds,
      assistantId: assistantId,
      conversationId: conversationId,
      buildBook: buildBook,
    );
  }
}

class _WorldBookSelectionGroup extends StatefulWidget {
  const _WorldBookSelectionGroup({
    super.key,
    required this.name,
    required this.books,
    required this.selectedIds,
    required this.assistantId,
    required this.conversationId,
    required this.buildBook,
  });

  final String? name;
  final List<WorldBook> books;
  final Set<String> selectedIds;
  final String? assistantId;
  final String? conversationId;
  final Widget Function(WorldBook) buildBook;

  @override
  State<_WorldBookSelectionGroup> createState() =>
      _WorldBookSelectionGroupState();
}

class _WorldBookSelectionGroupState extends State<_WorldBookSelectionGroup> {
  bool _expanded = false;

  Future<void> _toggleGroup(Set<String> books, Set<String> enabledBooks) async {
    try {
      await toggleWorldBookGroupSelection(
        context,
        bookIds: books,
        enabledBookIds: enabledBooks,
        assistantId: widget.assistantId,
        conversationId: widget.conversationId,
      );
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: AppLocalizations.of(context)!.worldBookGroupSaveFailed,
        type: NotificationType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final bookIds = {for (final book in widget.books) book.id};
    final enabledIds = {
      for (final book in widget.books)
        if (book.enabled) book.id,
    };
    final selectedCount = enabledIds.where(widget.selectedIds.contains).length;
    final canToggle =
        enabledIds.isNotEmpty || bookIds.any(widget.selectedIds.contains);
    final allSelected = selectedCount == enabledIds.length;
    final name = widget.name ?? l10n.worldBookGroupUngrouped;
    final selectionAction = allSelected && canToggle
        ? l10n.worldBookGroupClearSelection
        : l10n.worldBookGroupSelectAll;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CollapsibleGroupHeader(
            title: name,
            count: '$selectedCount/${enabledIds.length}',
            collapsed: !_expanded,
            onToggle: () => setState(() => _expanded = !_expanded),
            actions: [
              IosIconButton(
                icon: allSelected && canToggle
                    ? Lucide.Check
                    : Lucide.ListChecks,
                color: allSelected && canToggle ? cs.primary : null,
                tooltip: selectionAction,
                semanticLabel: '$name · $selectionAction',
                minSize: 44,
                enabled: canToggle,
                onTap: () => _toggleGroup(bookIds, enabledIds),
              ),
            ],
          ),
          if (_expanded)
            Column(children: widget.books.map(widget.buildBook).toList()),
        ],
      ),
    );
  }
}
