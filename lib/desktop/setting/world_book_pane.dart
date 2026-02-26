import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/world_book.dart';
import '../../core/providers/world_book_provider.dart';
import '../../icons/lucide_adapter.dart' as lucide;
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/ios_switch.dart';
import '../../shared/widgets/snackbar.dart';
import '../widgets/desktop_select_dropdown.dart';

class DesktopWorldBookPane extends StatefulWidget {
  const DesktopWorldBookPane({super.key});

  @override
  State<DesktopWorldBookPane> createState() => _DesktopWorldBookPaneState();
}

class _DesktopWorldBookPaneState extends State<DesktopWorldBookPane> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<WorldBookProvider>().initialize();
    });
  }

  String _safeFileName(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return 'lorebook';
    return cleaned.length > 80 ? cleaned.substring(0, 80) : cleaned;
  }

  String _baseName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    if (parts.isEmpty) return path;
    return parts.last.isEmpty ? path : parts.last;
  }

  Future<String?> _readPickedFileAsString(PlatformFile file) async {
    try {
      if (file.bytes != null && file.bytes!.isNotEmpty) {
        return utf8.decode(file.bytes!, allowMalformed: true);
      }
    } catch (_) {}
    final path = file.path;
    if (path == null || path.isEmpty) return null;
    try {
      return await File(path).readAsString();
    } catch (_) {
      try {
        final bytes = await File(path).readAsBytes();
        return utf8.decode(bytes, allowMalformed: true);
      } catch (_) {
        return null;
      }
    }
  }

  WorldBook? _parseWorldBookImport(dynamic decoded) {
    try {
      if (decoded is Map) {
        final map = decoded.cast<String, dynamic>();
        final data = map['data'];
        if (data is Map) {
          return WorldBook.fromJson(data.cast<String, dynamic>());
        }
        if (map.containsKey('entries')) {
          return WorldBook.fromJson(map);
        }
      }
    } catch (_) {}
    return null;
  }

  WorldBook _normalizeImportedBook(
    WorldBook book, {
    required Set<String> existingBookIds,
  }) {
    var bookId = book.id.trim();
    if (bookId.isEmpty || existingBookIds.contains(bookId)) {
      bookId = const Uuid().v4();
    }

    final seenEntryIds = <String>{};
    final nextEntries = <WorldBookEntry>[];
    for (final entry in book.entries) {
      var entryId = entry.id.trim();
      if (entryId.isEmpty || !seenEntryIds.add(entryId)) {
        entryId = const Uuid().v4();
      }
      nextEntries.add(entry.copyWith(id: entryId));
    }

    return book.copyWith(id: bookId, entries: nextEntries);
  }

  Map<String, dynamic> _toRikkaHubExportJson(WorldBook book) {
    final data = <String, dynamic>{
      'id': book.id,
      'name': book.name,
      'description': book.description,
      'enabled': book.enabled,
      'entries': book.entries
          .map(
            (e) => <String, dynamic>{
              'id': e.id,
              'name': e.name,
              'enabled': e.enabled,
              'priority': e.priority,
              'position': e.position.toJson(),
              'content': e.content,
              'injectDepth': e.injectDepth,
              'role': e.role.toJson(),
              'keywords': e.keywords,
              'useRegex': e.useRegex,
              'caseSensitive': e.caseSensitive,
              'scanDepth': e.scanDepth,
              'constantActive': e.constantActive,
            },
          )
          .toList(growable: false),
    };
    return <String, dynamic>{'version': 1, 'type': 'lorebook', 'data': data};
  }

  Future<void> _importFromFile() async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<WorldBookProvider>();
    await provider.initialize();
    if (!mounted) return;

    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
    } catch (_) {
      return;
    }

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final content = await _readPickedFileAsString(file);
    if (!mounted) return;
    if (content == null || content.trim().isEmpty) {
      showAppSnackBar(
        context,
        message: l10n.assistantEditSystemPromptImportEmpty,
        type: NotificationType.warning,
      );
      return;
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(content);
    } catch (_) {
      showAppSnackBar(
        context,
        message: l10n.mcpJsonEditParseFailed,
        type: NotificationType.error,
      );
      return;
    }

    final imported = _parseWorldBookImport(decoded);
    if (imported == null) {
      showAppSnackBar(
        context,
        message: l10n.assistantEditSystemPromptImportFailed,
        type: NotificationType.error,
      );
      return;
    }

    final normalized = _normalizeImportedBook(
      imported,
      existingBookIds: provider.books.map((e) => e.id).toSet(),
    );
    await provider.addBook(normalized);
  }

  Future<void> _exportBook(WorldBook book) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final fileName = _safeFileName(
        book.name.trim().isEmpty ? 'lorebook' : book.name.trim(),
      );
      final exportName = '$fileName.json';
      final json = jsonEncode(_toRikkaHubExportJson(book));

      final String? savePath = await FilePicker.platform.saveFile(
        dialogTitle: l10n.backupPageExportToFile,
        fileName: exportName,
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (savePath == null) return;

      await File(savePath).parent.create(recursive: true);
      await File(savePath).writeAsString(json);
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: l10n.messageExportSheetExportedAs(_baseName(savePath)),
        type: NotificationType.success,
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: l10n.worldBookExportFailed(e.toString()),
        type: NotificationType.error,
      );
    }
  }

  Future<bool> _confirmDeleteBook(WorldBook book) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.worldBookDeleteTitle),
          content: Text(
            l10n.worldBookDeleteMessage(
              book.name.trim().isEmpty
                  ? l10n.worldBookUnnamed
                  : book.name.trim(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.worldBookCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                l10n.worldBookDelete,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<WorldBook?> _showBookEditDialog({WorldBook? book}) async {
    return showDialog<WorldBook>(
      context: context,
      builder: (ctx) => _WorldBookEditDialog(book: book),
    );
  }

  Future<WorldBookEntry?> _showEntryEditDialog({WorldBookEntry? entry}) async {
    return showDialog<WorldBookEntry>(
      context: context,
      builder: (ctx) => _WorldBookEntryEditDialog(entry: entry),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<WorldBookProvider>();
    final books = provider.books;

    return Container(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 36,
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            l10n.worldBookTitle,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: cs.onSurface.withOpacity(0.9),
                            ),
                          ),
                        ),
                      ),
                      _SmallIconBtn(
                        icon: lucide.Lucide.Import,
                        onTap: _importFromFile,
                        tooltip: l10n.providersPageImportTooltip,
                      ),
                      const SizedBox(width: 6),
                      _SmallIconBtn(
                        icon: lucide.Lucide.Plus,
                        onTap: () async {
                          final result = await _showBookEditDialog();
                          if (!mounted) return;
                          if (result == null) return;
                          await provider.addBook(result);
                        },
                        tooltip: l10n.worldBookAdd,
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              if (books.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            lucide.Lucide.BookOpen,
                            size: 56,
                            color: cs.onSurface.withOpacity(0.28),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.worldBookEmptyMessage,
                            style: TextStyle(
                              color: cs.onSurface.withOpacity(0.65),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final book = books[index];
                    final wbProvider = context.read<WorldBookProvider>();
                    return Padding(
                      key: ValueKey('desktop-world-book-${book.id}'),
                      padding: EdgeInsets.only(
                        bottom: index == books.length - 1 ? 0 : 12,
                      ),
                      child: _WorldBookCard(
                        book: book,
                        collapsed: provider.isBookCollapsed(book.id),
                        onToggleCollapsed: () {
                          context.read<WorldBookProvider>().toggleBookCollapsed(
                            book.id,
                          );
                        },
                        onAddEntry: () async {
                          final entry = await _showEntryEditDialog();
                          if (!mounted) return;
                          if (entry == null) return;
                          final next = book.copyWith(
                            entries: [...book.entries, entry],
                          );
                          await wbProvider.updateBook(next);
                        },
                        onExport: () async => _exportBook(book),
                        onConfig: () async {
                          final edited = await _showBookEditDialog(book: book);
                          if (!mounted) return;
                          if (edited == null) return;
                          await wbProvider.updateBook(edited);
                        },
                        onDelete: () async {
                          final confirm = await _confirmDeleteBook(book);
                          if (!mounted) return;
                          if (!confirm) return;
                          await wbProvider.deleteBook(book.id);
                        },
                        onEditEntry: (entry) async {
                          final edited = await _showEntryEditDialog(
                            entry: entry,
                          );
                          if (!mounted) return;
                          if (edited == null) return;
                          final nextEntries = book.entries
                              .map((e) => e.id == entry.id ? edited : e)
                              .toList(growable: false);
                          await wbProvider.updateBook(
                            book.copyWith(entries: nextEntries),
                          );
                        },
                        onDeleteEntry: (entry) async {
                          final nextEntries = book.entries
                              .where((e) => e.id != entry.id)
                              .toList(growable: false);
                          await wbProvider.updateBook(
                            book.copyWith(entries: nextEntries),
                          );
                        },
                      ),
                    );
                  }, childCount: books.length),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorldBookCard extends StatefulWidget {
  const _WorldBookCard({
    required this.book,
    required this.collapsed,
    required this.onToggleCollapsed,
    required this.onAddEntry,
    required this.onExport,
    required this.onConfig,
    required this.onDelete,
    required this.onEditEntry,
    required this.onDeleteEntry,
  });

  final WorldBook book;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;
  final VoidCallback onAddEntry;
  final VoidCallback onExport;
  final VoidCallback onConfig;
  final VoidCallback onDelete;
  final ValueChanged<WorldBookEntry> onEditEntry;
  final ValueChanged<WorldBookEntry> onDeleteEntry;

  @override
  State<_WorldBookCard> createState() => _WorldBookCardState();
}

class _WorldBookCardState extends State<_WorldBookCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseBg = isDark ? Colors.white10 : Colors.white.withOpacity(0.96);
    final borderColor = _hover
        ? cs.primary.withOpacity(isDark ? 0.35 : 0.45)
        : cs.outlineVariant.withOpacity(isDark ? 0.12 : 0.08);

    final title = widget.book.name.trim().isEmpty
        ? l10n.worldBookUnnamed
        : widget.book.name.trim();
    final subtitle = widget.book.description.trim();

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        decoration: BoxDecoration(
          color: baseBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1.0),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    widget.onToggleCollapsed();
                  },
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: Center(
                      child: AnimatedRotation(
                        turns: widget.collapsed ? 0.0 : 0.25,
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          lucide.Lucide.ChevronRight,
                          size: 16,
                          color: cs.onSurface.withOpacity(0.62),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(lucide.Lucide.BookOpen, size: 20, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (!widget.book.enabled) ...[
                            const SizedBox(width: 8),
                            _TagPill(
                              text: l10n.worldBookDisabledTag,
                              color: cs.error,
                            ),
                          ],
                        ],
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withOpacity(0.72),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _SmallIconBtn(
                  icon: lucide.Lucide.Plus,
                  onTap: widget.onAddEntry,
                  tooltip: l10n.worldBookAddEntry,
                ),
                const SizedBox(width: 6),
                _SmallIconBtn(
                  icon: lucide.Lucide.Share2,
                  onTap: widget.onExport,
                  tooltip: l10n.worldBookExport,
                ),
                const SizedBox(width: 6),
                _SmallIconBtn(
                  icon: lucide.Lucide.Settings2,
                  onTap: widget.onConfig,
                  tooltip: l10n.worldBookConfig,
                ),
                const SizedBox(width: 6),
                _SmallIconBtn(
                  icon: lucide.Lucide.Trash2,
                  onTap: widget.onDelete,
                  tooltip: l10n.worldBookDelete,
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: widget.collapsed
                  ? const SizedBox(width: double.infinity, height: 0)
                  : SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _EntriesPanel(
                          entries: widget.book.entries,
                          onEdit: widget.onEditEntry,
                          onDelete: widget.onDeleteEntry,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntriesPanel extends StatelessWidget {
  const _EntriesPanel({
    required this.entries,
    required this.onEdit,
    required this.onDelete,
  });

  final List<WorldBookEntry> entries;
  final ValueChanged<WorldBookEntry> onEdit;
  final ValueChanged<WorldBookEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = cs.outlineVariant.withOpacity(isDark ? 0.16 : 0.12);
    final bg = isDark
        ? Colors.white.withOpacity(0.04)
        : const Color(0xFFF8F8FA);

    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 0.8),
        ),
        child: Row(
          children: [
            Icon(
              lucide.Lucide.ListTree,
              size: 18,
              color: cs.onSurface.withOpacity(0.55),
            ),
            const SizedBox(width: 10),
            Text(
              l10n.worldBookNoEntriesHint,
              style: TextStyle(color: cs.onSurface.withOpacity(0.65)),
            ),
          ],
        ),
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Column(
        children: [
          for (int i = 0; i < entries.length; i++)
            _EntryRow(entry: entries[i], onEdit: onEdit, onDelete: onDelete),
        ],
      ),
    );
  }
}

class _EntryRow extends StatefulWidget {
  const _EntryRow({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  final WorldBookEntry entry;
  final ValueChanged<WorldBookEntry> onEdit;
  final ValueChanged<WorldBookEntry> onDelete;

  @override
  State<_EntryRow> createState() => _EntryRowState();
}

class _EntryRowState extends State<_EntryRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hoverBg = (isDark ? Colors.white : Colors.black).withOpacity(
      isDark ? 0.08 : 0.04,
    );

    final title = widget.entry.name.trim().isEmpty
        ? l10n.worldBookUnnamedEntry
        : widget.entry.name.trim();
    final detail = !widget.entry.enabled
        ? l10n.worldBookDisabledTag
        : (widget.entry.constantActive ? l10n.worldBookAlwaysOnTag : null);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onEdit(widget.entry),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          color: _hover ? hoverBg : Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  lucide.Lucide.Bookmark,
                  size: 18,
                  color: widget.entry.enabled
                      ? cs.primary
                      : cs.onSurface.withOpacity(0.35),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: widget.entry.enabled
                                ? cs.onSurface
                                : cs.onSurface.withOpacity(0.55),
                          ),
                        ),
                      ),
                      if (detail != null && detail.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _TagPill(
                          text: detail,
                          color: widget.entry.enabled ? cs.primary : cs.error,
                          subtle: true,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _SmallIconBtn(
                  icon: lucide.Lucide.Settings2,
                  onTap: () => widget.onEdit(widget.entry),
                  tooltip: l10n.worldBookEditEntry,
                ),
                const SizedBox(width: 6),
                _SmallIconBtn(
                  icon: lucide.Lucide.Trash2,
                  onTap: () => widget.onDelete(widget.entry),
                  tooltip: l10n.worldBookDeleteEntry,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({
    required this.text,
    required this.color,
    this.subtle = false,
  });

  final String text;
  final Color color;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = subtle
        ? color.withOpacity(isDark ? 0.18 : 0.12)
        : color.withOpacity(isDark ? 0.20 : 0.14);
    final fg = subtle ? color : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: fg,
          height: 1.0,
        ),
      ),
    );
  }
}

class _WorldBookEditDialog extends StatefulWidget {
  const _WorldBookEditDialog({required this.book});
  final WorldBook? book;

  @override
  State<_WorldBookEditDialog> createState() => _WorldBookEditDialogState();
}

class _WorldBookEditDialogState extends State<_WorldBookEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.book?.name ?? '');
    _descController = TextEditingController(
      text: widget.book?.description ?? '',
    );
    _enabled = widget.book?.enabled ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Dialog(
      backgroundColor: cs.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 58),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.book == null
                              ? l10n.worldBookAdd
                              : l10n.worldBookConfig,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _SmallIconBtn(
                        icon: lucide.Lucide.X,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: _deskInputDecoration(
                      context,
                    ).copyWith(hintText: l10n.worldBookNameLabel),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descController,
                    maxLines: 3,
                    decoration: _deskInputDecoration(
                      context,
                    ).copyWith(hintText: l10n.worldBookDescriptionLabel),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.worldBookEnabledLabel,
                          style: TextStyle(
                            color: cs.onSurface.withOpacity(0.8),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IosSwitch(
                        value: _enabled,
                        onChanged: (v) => setState(() => _enabled = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: _DeskIosButton(
                label: l10n.worldBookSave,
                filled: true,
                dense: true,
                onTap: () {
                  final base = widget.book;
                  final id = base?.id ?? const Uuid().v4();
                  Navigator.of(context).pop(
                    WorldBook(
                      id: id,
                      name: _nameController.text.trim(),
                      description: _descController.text.trim(),
                      enabled: _enabled,
                      entries: base?.entries ?? const <WorldBookEntry>[],
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

class _WorldBookEntryEditDialog extends StatefulWidget {
  const _WorldBookEntryEditDialog({required this.entry});
  final WorldBookEntry? entry;

  @override
  State<_WorldBookEntryEditDialog> createState() =>
      _WorldBookEntryEditDialogState();
}

class _WorldBookEntryEditDialogState extends State<_WorldBookEntryEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _contentController;
  late final TextEditingController _priorityController;
  late final TextEditingController _scanDepthController;
  late final TextEditingController _injectDepthController;
  late final TextEditingController _keywordInputController;

  late bool _enabled;
  late bool _useRegex;
  late bool _caseSensitive;
  late bool _constantActive;
  late WorldBookInjectionPosition _position;
  late WorldBookInjectionRole _role;
  late List<String> _keywords;

  @override
  void initState() {
    super.initState();
    final base = widget.entry;
    _nameController = TextEditingController(text: base?.name ?? '');
    _contentController = TextEditingController(text: base?.content ?? '');
    _priorityController = TextEditingController(
      text: (base?.priority ?? 0).toString(),
    );
    _scanDepthController = TextEditingController(
      text: (base?.scanDepth ?? 4).toString(),
    );
    _injectDepthController = TextEditingController(
      text: (base?.injectDepth ?? 4).toString(),
    );
    _keywordInputController = TextEditingController();

    _enabled = base?.enabled ?? true;
    _useRegex = base?.useRegex ?? false;
    _caseSensitive = base?.caseSensitive ?? false;
    _constantActive = base?.constantActive ?? false;
    _position = base?.position ?? WorldBookInjectionPosition.afterSystemPrompt;
    _role = base?.role ?? WorldBookInjectionRole.user;
    _keywords = List<String>.from(base?.keywords ?? const <String>[]);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    _priorityController.dispose();
    _scanDepthController.dispose();
    _injectDepthController.dispose();
    _keywordInputController.dispose();
    super.dispose();
  }

  void _addKeywordsFromInput() {
    final text = _keywordInputController.text.trim();
    if (text.isEmpty) return;
    final set = _keywords.toSet();
    set.add(text);
    setState(() {
      _keywords = set.toList(growable: false);
      _keywordInputController.clear();
    });
  }

  List<DesktopSelectOption<WorldBookInjectionPosition>> _positionOptions(
    AppLocalizations l10n,
  ) {
    return <DesktopSelectOption<WorldBookInjectionPosition>>[
      DesktopSelectOption(
        value: WorldBookInjectionPosition.beforeSystemPrompt,
        label: l10n.worldBookInjectionPositionBeforeSystemPrompt,
      ),
      DesktopSelectOption(
        value: WorldBookInjectionPosition.afterSystemPrompt,
        label: l10n.worldBookInjectionPositionAfterSystemPrompt,
      ),
      DesktopSelectOption(
        value: WorldBookInjectionPosition.topOfChat,
        label: l10n.worldBookInjectionPositionTopOfChat,
      ),
      DesktopSelectOption(
        value: WorldBookInjectionPosition.bottomOfChat,
        label: l10n.worldBookInjectionPositionBottomOfChat,
      ),
      DesktopSelectOption(
        value: WorldBookInjectionPosition.atDepth,
        label: l10n.worldBookInjectionPositionAtDepth,
      ),
    ];
  }

  List<DesktopSelectOption<WorldBookInjectionRole>> _roleOptions(
    AppLocalizations l10n,
  ) {
    return <DesktopSelectOption<WorldBookInjectionRole>>[
      DesktopSelectOption(
        value: WorldBookInjectionRole.user,
        label: l10n.worldBookInjectionRoleUser,
      ),
      DesktopSelectOption(
        value: WorldBookInjectionRole.assistant,
        label: l10n.worldBookInjectionRoleAssistant,
      ),
    ];
  }

  TextStyle _labelStyle(ColorScheme cs) {
    return TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: cs.onSurface.withOpacity(0.82),
    );
  }

  TextStyle _hintStyle(ColorScheme cs) {
    return TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.6));
  }

  Widget _section({
    required ColorScheme cs,
    required bool isDark,
    required Widget child,
  }) {
    final bg = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.03);
    final border = cs.outlineVariant.withOpacity(0.12);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 0.6),
      ),
      child: child,
    );
  }

  Widget _labeledField({
    required ColorScheme cs,
    required String label,
    required Widget child,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: _labelStyle(cs)),
        const SizedBox(height: 6),
        child,
        if ((hint ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(hint!, style: _hintStyle(cs)),
        ],
      ],
    );
  }

  Widget _switchRow({
    required ColorScheme cs,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    String? hint,
  }) {
    final hasHint = (hint ?? '').trim().isNotEmpty;
    return Row(
      crossAxisAlignment: hasHint
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: _labelStyle(cs)),
              if (hasHint) ...[
                const SizedBox(height: 4),
                Text(hint!, style: _hintStyle(cs)),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        IosSwitch(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _smallNumberField({
    required ColorScheme cs,
    required String label,
    required TextEditingController controller,
    double width = 104,
  }) {
    return _labeledField(
      cs: cs,
      label: label,
      child: SizedBox(
        width: width,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          decoration: _deskInputDecoration(context),
        ),
      ),
    );
  }

  DesktopSelectDropdown<T> _formDropdown<T>({
    required bool isDark,
    required T value,
    required List<DesktopSelectOption<T>> options,
    required ValueChanged<T> onSelected,
  }) {
    final fillColor = isDark ? Colors.white10 : const Color(0xFFF7F7F9);
    return DesktopSelectDropdown<T>(
      value: value,
      options: options,
      onSelected: (v) => onSelected(v),
      minHeight: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderRadius: 12,
      triggerFillColor: fillColor,
      maxLabelWidth: 380,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);
    final maxHeight = size.height * 0.9;
    final positionOptions = _positionOptions(l10n);
    final roleOptions = _roleOptions(l10n);

    return Dialog(
      backgroundColor: cs.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 760, maxHeight: maxHeight),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 58),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.entry == null
                              ? l10n.worldBookAddEntry
                              : l10n.worldBookEditEntry,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _SmallIconBtn(
                        icon: lucide.Lucide.X,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: LayoutBuilder(
                        builder: (ctx, constraints) {
                          final wide = constraints.maxWidth >= 720;
                          const gap = 14.0;

                          final matchSection = _section(
                            cs: cs,
                            isDark: isDark,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _labeledField(
                                  cs: cs,
                                  label: l10n.worldBookEntryNameLabel,
                                  child: TextField(
                                    controller: _nameController,
                                    decoration: _deskInputDecoration(context)
                                        .copyWith(
                                          hintText:
                                              l10n.worldBookEntryNameLabel,
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _labeledField(
                                  cs: cs,
                                  label: l10n.worldBookEntryKeywordsLabel,
                                  hint: l10n.worldBookEntryKeywordsHint,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (_keywords.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          child: Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              for (final k in _keywords)
                                                InputChip(
                                                  label: Text(k),
                                                  onDeleted: () => setState(
                                                    () => _keywords = _keywords
                                                        .where((e) => e != k)
                                                        .toList(
                                                          growable: false,
                                                        ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller:
                                                  _keywordInputController,
                                              decoration:
                                                  _deskInputDecoration(
                                                    context,
                                                  ).copyWith(
                                                    hintText: l10n
                                                        .worldBookEntryKeywordInputHint,
                                                  ),
                                              onSubmitted: (_) =>
                                                  _addKeywordsFromInput(),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          _SmallIconBtn(
                                            icon: lucide.Lucide.Plus,
                                            onTap: _addKeywordsFromInput,
                                            tooltip: l10n
                                                .worldBookEntryKeywordAddTooltip,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _switchRow(
                                  cs: cs,
                                  label: l10n.worldBookEntryUseRegexLabel,
                                  value: _useRegex,
                                  onChanged: (v) =>
                                      setState(() => _useRegex = v),
                                ),
                                const SizedBox(height: 10),
                                _switchRow(
                                  cs: cs,
                                  label: l10n.worldBookEntryCaseSensitiveLabel,
                                  value: _caseSensitive,
                                  onChanged: (v) =>
                                      setState(() => _caseSensitive = v),
                                ),
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: _smallNumberField(
                                    cs: cs,
                                    label: l10n.worldBookEntryScanDepthLabel,
                                    controller: _scanDepthController,
                                  ),
                                ),
                              ],
                            ),
                          );

                          final contentSection = _section(
                            cs: cs,
                            isDark: isDark,
                            child: _labeledField(
                              cs: cs,
                              label: l10n.worldBookEntryContentLabel,
                              child: TextField(
                                controller: _contentController,
                                minLines: 12,
                                maxLines: 18,
                                keyboardType: TextInputType.multiline,
                                decoration: _deskInputDecoration(context)
                                    .copyWith(
                                      hintText: l10n.worldBookEntryContentLabel,
                                    ),
                              ),
                            ),
                          );

                          final injectionSection = _section(
                            cs: cs,
                            isDark: isDark,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _switchRow(
                                  cs: cs,
                                  label: l10n.worldBookEntryEnabledLabel,
                                  value: _enabled,
                                  onChanged: (v) =>
                                      setState(() => _enabled = v),
                                ),
                                const SizedBox(height: 10),
                                _switchRow(
                                  cs: cs,
                                  label: l10n.worldBookEntryAlwaysOnLabel,
                                  hint: l10n.worldBookEntryAlwaysOnHint,
                                  value: _constantActive,
                                  onChanged: (v) =>
                                      setState(() => _constantActive = v),
                                ),
                                const SizedBox(height: 12),
                                _labeledField(
                                  cs: cs,
                                  label:
                                      l10n.worldBookEntryInjectionPositionLabel,
                                  child: _formDropdown(
                                    isDark: isDark,
                                    value: _position,
                                    options: positionOptions,
                                    onSelected: (v) =>
                                        setState(() => _position = v),
                                  ),
                                ),
                                if (_position ==
                                    WorldBookInjectionPosition.atDepth) ...[
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: _smallNumberField(
                                      cs: cs,
                                      label:
                                          l10n.worldBookEntryInjectDepthLabel,
                                      controller: _injectDepthController,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                _labeledField(
                                  cs: cs,
                                  label: l10n.worldBookEntryInjectionRoleLabel,
                                  child: _formDropdown(
                                    isDark: isDark,
                                    value: _role,
                                    options: roleOptions,
                                    onSelected: (v) =>
                                        setState(() => _role = v),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: _smallNumberField(
                                    cs: cs,
                                    label: l10n.worldBookEntryPriorityLabel,
                                    controller: _priorityController,
                                  ),
                                ),
                              ],
                            ),
                          );

                          Widget top;
                          if (wide) {
                            top = Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      matchSection,
                                      const SizedBox(height: gap),
                                      contentSection,
                                    ],
                                  ),
                                ),
                                const SizedBox(width: gap),
                                Expanded(child: injectionSection),
                              ],
                            );
                          } else {
                            top = Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                matchSection,
                                const SizedBox(height: gap),
                                contentSection,
                                const SizedBox(height: gap),
                                injectionSection,
                              ],
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [top],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: _DeskIosButton(
                label: l10n.worldBookSave,
                filled: true,
                dense: true,
                onTap: () {
                  final base = widget.entry;
                  final id = base?.id ?? const Uuid().v4();
                  final priority =
                      int.tryParse(_priorityController.text.trim()) ??
                      (base?.priority ?? 0);
                  final scanDepth =
                      int.tryParse(_scanDepthController.text.trim()) ??
                      (base?.scanDepth ?? 4);
                  final injectDepth =
                      int.tryParse(_injectDepthController.text.trim()) ??
                      (base?.injectDepth ?? 4);
                  Navigator.of(context).pop(
                    WorldBookEntry(
                      id: id,
                      name: _nameController.text.trim(),
                      enabled: _enabled,
                      priority: priority,
                      position: _position,
                      content: _contentController.text,
                      injectDepth: injectDepth.clamp(1, 200).toInt(),
                      role: _role,
                      keywords: List<String>.from(_keywords),
                      useRegex: _useRegex,
                      caseSensitive: _caseSensitive,
                      scanDepth: scanDepth.clamp(1, 200).toInt(),
                      constantActive: _constantActive,
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

class _SmallIconBtn extends StatefulWidget {
  const _SmallIconBtn({required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  State<_SmallIconBtn> createState() => _SmallIconBtnState();
}

class _SmallIconBtnState extends State<_SmallIconBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _hover
        ? (isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.05))
        : Colors.transparent;
    final btn = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(widget.icon, size: 18, color: cs.onSurface),
        ),
      ),
    );
    if ((widget.tooltip ?? '').isEmpty) return btn;
    return Tooltip(message: widget.tooltip!, child: btn);
  }
}

class _DeskIosButton extends StatefulWidget {
  const _DeskIosButton({
    required this.label,
    required this.filled,
    required this.dense,
    required this.onTap,
  });
  final String label;
  final bool filled;
  final bool dense;
  final VoidCallback onTap;

  @override
  State<_DeskIosButton> createState() => _DeskIosButtonState();
}

class _DeskIosButtonState extends State<_DeskIosButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = widget.filled
        ? cs.onPrimary
        : cs.onSurface.withOpacity(0.9);
    final bg = widget.filled
        ? (_hover ? cs.primary.withOpacity(0.92) : cs.primary)
        : (_hover
              ? (isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.05))
              : Colors.transparent);
    final borderColor = widget.filled
        ? Colors.transparent
        : cs.outlineVariant.withOpacity(isDark ? 0.22 : 0.18);
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
          scale: _pressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: widget.dense ? 8 : 12,
              horizontal: 12,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: widget.dense ? 13 : 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _deskInputDecoration(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final cs = Theme.of(context).colorScheme;
  return InputDecoration(
    isDense: false,
    filled: true,
    fillColor: isDark ? Colors.white10 : const Color(0xFFF7F7F9),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: cs.outlineVariant.withOpacity(0.2),
        width: 0.8,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: cs.outlineVariant.withOpacity(0.2),
        width: 0.8,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: cs.primary.withOpacity(0.45), width: 1.0),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}
