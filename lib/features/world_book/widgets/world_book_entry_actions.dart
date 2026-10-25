import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/world_book.dart';
import '../../../core/providers/world_book_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/responsive/screen_type_helper.dart';
import '../../../shared/widgets/ios_checkbox.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_text_button.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../theme/app_semantic_colors.dart';

Future<bool> showWorldBookEntryTransfer(
  BuildContext context, {
  required String sourceBookId,
  required Set<String> entryIds,
  required bool copy,
}) async {
  if (entryIds.isEmpty) return false;
  final provider = context.read<WorldBookProvider>();
  final ids = Set<String>.of(entryIds);
  final targets = provider.books
      .where((book) => copy || book.id != sourceBookId)
      .toList();
  final platform = Theme.of(context).platform;
  final desktop =
      ResponsiveHelper.isDesktop(context) ||
      platform == TargetPlatform.macOS ||
      platform == TargetPlatform.windows ||
      platform == TargetPlatform.linux;
  Widget picker(BuildContext context) =>
      _DestinationPicker(books: targets, copy: copy);
  final targetId = desktop
      ? await showDialog<String>(
          context: context,
          builder: (context) => Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440, maxHeight: 540),
              child: picker(context),
            ),
          ),
        )
      : await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          backgroundColor: context.overlaySurface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (context) => ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .75,
            ),
            child: picker(context),
          ),
        );
  if (targetId == null || !context.mounted) return false;
  final l10n = AppLocalizations.of(context)!;
  try {
    await provider.transferEntries(
      sourceBookId: sourceBookId,
      targetBookId: targetId,
      entryIds: ids,
      copy: copy,
    );
    if (context.mounted) {
      showAppSnackBar(
        context,
        message: copy
            ? l10n.worldBookEntriesCopied(ids.length)
            : l10n.worldBookEntriesMoved(ids.length),
      );
    }
    return true;
  } catch (_) {
    if (context.mounted) {
      showAppSnackBar(
        context,
        message: l10n.worldBookTransferFailed,
        type: NotificationType.error,
      );
    }
    return false;
  }
}

class _DestinationPicker extends StatelessWidget {
  const _DestinationPicker({required this.books, required this.copy});

  final List<WorldBook> books;
  final bool copy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    copy
                        ? l10n.worldBookCopyEntries
                        : l10n.worldBookMoveEntries,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IosIconButton(
                  icon: Lucide.X,
                  tooltip: l10n.worldBookCancel,
                  minSize: 44,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            if (books.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(l10n.worldBookNoMoveTargets),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: books.length,
                  itemBuilder: (context, index) {
                    final book = books[index];
                    return IosCardPress(
                      key: ValueKey('world-book-destination-${book.id}'),
                      baseColor: Colors.transparent,
                      onTap: () => Navigator.of(context).pop(book.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Icon(Lucide.BookOpen, size: 20, color: cs.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                book.name.trim().isEmpty
                                    ? l10n.worldBookUnnamed
                                    : book.name,
                              ),
                            ),
                            if (!book.enabled) ...[
                              const SizedBox(width: 8),
                              Text(
                                l10n.worldBookDisabledTag,
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class WorldBookEntrySelectionBar extends StatelessWidget {
  const WorldBookEntrySelectionBar({
    super.key,
    required this.selectedCount,
    required this.totalCount,
    required this.onSelectAll,
    required this.onCancel,
    required this.onCopy,
    required this.onMove,
    this.busy = false,
  });

  final int selectedCount;
  final int totalCount;
  final bool busy;
  final VoidCallback onSelectAll;
  final VoidCallback onCancel;
  final VoidCallback onCopy;
  final VoidCallback onMove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final allSelected = totalCount > 0 && selectedCount == totalCount;
    final selectAllLabel = allSelected
        ? l10n.sideDrawerSelectionDeselectAll
        : l10n.sideDrawerSelectionSelectAll;
    final countLabel = l10n.worldBookSelectedEntries(selectedCount);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth <
              640 * MediaQuery.textScalerOf(context).scale(14) / 14;

          Widget action({
            required String name,
            required String label,
            required IconData icon,
            required VoidCallback? onPressed,
          }) {
            final key = ValueKey('world-book-selection-$name');
            return compact
                ? IosIconButton(
                    key: key,
                    icon: icon,
                    tooltip: label,
                    minSize: 44,
                    size: 19,
                    enabled: onPressed != null,
                    onTap: onPressed,
                  )
                : IosTextButton(
                    key: key,
                    label: label,
                    icon: name == 'done' ? null : icon,
                    onPressed: onPressed,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  );
          }

          return Row(
            children: [
              Tooltip(
                message: selectAllLabel,
                child: IosCheckbox(
                  value: allSelected,
                  semanticLabel: selectAllLabel,
                  hitTestSize: 44,
                  onChanged: busy || totalCount == 0
                      ? null
                      : (_) => onSelectAll(),
                ),
              ),
              Expanded(
                child: Tooltip(
                  message: countLabel,
                  child: Text(
                    countLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              action(
                name: 'copy',
                label: l10n.worldBookCopyEntries,
                icon: Lucide.Copy,
                onPressed: busy || selectedCount == 0 ? null : onCopy,
              ),
              action(
                name: 'move',
                label: l10n.worldBookMoveEntries,
                icon: Lucide.FolderInput,
                onPressed: busy || selectedCount == 0 ? null : onMove,
              ),
              Container(
                width: 1,
                height: 16,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              action(
                name: 'done',
                label: l10n.worldBookSelectionDone,
                icon: Lucide.X,
                onPressed: busy ? null : onCancel,
              ),
            ],
          );
        },
      ),
    );
  }
}
