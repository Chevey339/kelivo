import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/world_book.dart';
import '../../../core/providers/world_book_provider.dart';
import '../../../core/services/haptics.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_form_text_field.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/snackbar.dart';

class WorldBookPage extends StatefulWidget {
  const WorldBookPage({super.key});

  @override
  State<WorldBookPage> createState() => _WorldBookPageState();
}

class _WorldBookPageState extends State<WorldBookPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<WorldBookProvider>().initialize();
    });
  }

  Future<WorldBook?> _showBookConfigSheet({WorldBook? book}) async {
    final cs = Theme.of(context).colorScheme;
    return showModalBottomSheet<WorldBook>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        final maxHeight = MediaQuery.sizeOf(sheetCtx).height * 0.9;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: _WorldBookEditSheet(book: book),
        );
      },
    );
  }

  Future<WorldBookEntry?> _showEntryEditSheet({WorldBookEntry? entry}) async {
    final cs = Theme.of(context).colorScheme;
    return showModalBottomSheet<WorldBookEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        final maxHeight = MediaQuery.sizeOf(sheetCtx).height * 0.9;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: _WorldBookEntryEditSheet(entry: entry),
        );
      },
    );
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

  Future<void> _importBookFromFile() async {
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

  String _baseName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    if (parts.isEmpty) return path;
    return parts.last.isEmpty ? path : parts.last;
  }

  Future<void> _exportBook(WorldBook book) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final fileName = _safeFileName(
        book.name.trim().isEmpty ? 'lorebook' : book.name.trim(),
      );
      final exportName = '$fileName.json';
      final json = jsonEncode(_toRikkaHubExportJson(book));

      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
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
        return;
      }

      final bytes = Uint8List.fromList(utf8.encode(json));
      final String? savePath = await FilePicker.platform.saveFile(
        dialogTitle: l10n.backupPageExportToFile,
        fileName: exportName,
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: bytes,
      );
      if (savePath == null) return;
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

  String _safeFileName(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[\\\\/:*?\"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return 'lorebook';
    return cleaned.length > 80 ? cleaned.substring(0, 80) : cleaned;
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final provider = context.watch<WorldBookProvider>();
    final books = provider.books;

    return Scaffold(
      appBar: AppBar(
        leading: Tooltip(
          message: l10n.settingsPageBackButton,
          child: IosIconButton(
            icon: Lucide.ArrowLeft,
            minSize: 44,
            size: 22,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(l10n.worldBookTitle),
        actions: [
          Tooltip(
            message: l10n.providersPageImportTooltip,
            child: IosIconButton(
              icon: Lucide.cloudDownload,
              minSize: 44,
              size: 22,
              onTap: () async {
                Haptics.light();
                await _importBookFromFile();
              },
            ),
          ),
          Tooltip(
            message: l10n.worldBookAdd,
            child: IosIconButton(
              icon: Lucide.Plus,
              minSize: 44,
              size: 22,
              onTap: () async {
                Haptics.light();
                final result = await _showBookConfigSheet();
                if (result == null) return;
                await context.read<WorldBookProvider>().addBook(result);
              },
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: books.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Lucide.BookOpen,
                    size: 64,
                    color: cs.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.worldBookEmptyMessage,
                    style: TextStyle(
                      color: cs.onSurface.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                for (int index = 0; index < books.length; index++)
                  Padding(
                    key: ValueKey('mobile-world-book-${books[index].id}'),
                    padding: EdgeInsets.only(
                      bottom: index == books.length - 1 ? 0 : 14,
                    ),
                    child: _WorldBookSection(
                      book: books[index],
                      collapsed: provider.isBookCollapsed(books[index].id),
                      onToggleCollapsed: () {
                        Haptics.light();
                        context.read<WorldBookProvider>().toggleBookCollapsed(
                          books[index].id,
                        );
                      },
                      onAddEntry: () async {
                        Haptics.light();
                        final edited = await _showEntryEditSheet();
                        if (edited == null) return;
                        final next = books[index].copyWith(
                          entries: [...books[index].entries, edited],
                        );
                        await context.read<WorldBookProvider>().updateBook(next);
                      },
                      onExport: () async {
                        Haptics.light();
                        await _exportBook(books[index]);
                      },
                      onConfig: () async {
                        Haptics.light();
                        final updated = await _showBookConfigSheet(
                          book: books[index],
                        );
                        if (updated == null) return;
                        await context.read<WorldBookProvider>().updateBook(
                          updated,
                        );
                      },
                      onDelete: () async {
                        Haptics.light();
                        final confirm = await _confirmDeleteBook(books[index]);
                        if (!confirm) return;
                        await context.read<WorldBookProvider>().deleteBook(
                          books[index].id,
                        );
                      },
                      onEditEntry: (entry) async {
                        Haptics.light();
                        final edited = await _showEntryEditSheet(entry: entry);
                        if (edited == null) return;
                        final nextEntries = books[index].entries
                            .map((e) => e.id == entry.id ? edited : e)
                            .toList(growable: false);
                        await context.read<WorldBookProvider>().updateBook(
                          books[index].copyWith(entries: nextEntries),
                        );
                      },
                      onDeleteEntry: (entry) async {
                        Haptics.light();
                        final nextEntries = books[index].entries
                            .where((e) => e.id != entry.id)
                            .toList(growable: false);
                        await context.read<WorldBookProvider>().updateBook(
                          books[index].copyWith(entries: nextEntries),
                        );
                      },
                    ),
                  ),
              ],
            ),
      backgroundColor: isDark ? cs.surface : cs.surface,
    );
  }
}

class _WorldBookSection extends StatelessWidget {
  const _WorldBookSection({
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
  final Future<void> Function(WorldBookEntry entry) onEditEntry;
  final Future<void> Function(WorldBookEntry entry) onDeleteEntry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    final title = book.name.trim().isEmpty
        ? l10n.worldBookUnnamed
        : book.name.trim();
    final subtitle = book.description.trim();
    final entries = book.entries;

    Future<void> showEntryActions(WorldBookEntry entry) async {
      final result = await showModalBottomSheet<_EntryAction>(
        context: context,
        backgroundColor: cs.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          final localL10n = AppLocalizations.of(ctx)!;
          final localCs = Theme.of(ctx).colorScheme;

          Widget actionRow({
            required IconData icon,
            required String label,
            Color? color,
            required VoidCallback onTap,
          }) {
            final c = color ?? localCs.onSurface.withOpacity(0.9);
            return IosCardPress(
              baseColor: Colors.transparent,
              borderRadius: BorderRadius.zero,
              pressedBlendStrength: 0,
              pressedScale: 1.0,
              haptics: false,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    SizedBox(width: 28, child: Icon(icon, size: 20, color: c)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: c,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          Widget divider() => Divider(
            height: 6,
            thickness: 0.6,
            indent: 12,
            endIndent: 12,
            color: localCs.outlineVariant.withOpacity(0.18),
          );

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: localCs.onSurface.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _IosSectionCard(
                    children: [
                      actionRow(
                        icon: Lucide.Settings2,
                        label: localL10n.worldBookEditEntry,
                        onTap: () => Navigator.of(ctx).pop(_EntryAction.edit),
                      ),
                      divider(),
                      actionRow(
                        icon: Lucide.Trash2,
                        label: localL10n.worldBookDeleteEntry,
                        color: localCs.error,
                        onTap: () => Navigator.of(ctx).pop(_EntryAction.delete),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _IosSectionCard(
                    children: [
                      actionRow(
                        icon: Lucide.X,
                        label: localL10n.worldBookCancel,
                        onTap: () => Navigator.of(ctx).pop(_EntryAction.cancel),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (result == null || result == _EntryAction.cancel) return;
      if (result == _EntryAction.edit) {
        await onEditEntry(entry);
      } else if (result == _EntryAction.delete) {
        await onDeleteEntry(entry);
      }
    }

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: IosCardPress(
              baseColor: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              pressedBlendStrength: 0.04,
              pressedScale: 1.0,
              haptics: false,
              onTap: onToggleCollapsed,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    AnimatedRotation(
                      turns: collapsed ? 0.0 : 0.25,
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Lucide.ChevronRight,
                        size: 16,
                        color: cs.onSurface.withOpacity(0.62),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                              if (!book.enabled) ...[
                                const SizedBox(width: 8),
                                _TagPill(
                                  text: l10n.worldBookDisabledTag,
                                  color: cs.error,
                                ),
                              ],
                            ],
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: cs.onSurface.withOpacity(0.65),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _HeaderIconButton(
            icon: Lucide.Plus,
            tooltip: l10n.worldBookAddEntry,
            onTap: onAddEntry,
          ),
          _HeaderIconButton(
            icon: Lucide.Share2,
            tooltip: l10n.worldBookExport,
            onTap: onExport,
          ),
          _HeaderIconButton(
            icon: Lucide.Settings2,
            tooltip: l10n.worldBookConfig,
            onTap: onConfig,
          ),
          _HeaderIconButton(
            icon: Lucide.Trash2,
            tooltip: l10n.worldBookDelete,
            onTap: onDelete,
            color: cs.error,
          ),
        ],
      ),
    );

    final children = <Widget>[];
    if (entries.isEmpty) {
      children.add(
        _IosListRow(icon: Lucide.ListTree, label: l10n.worldBookNoEntriesHint),
      );
    } else {
      for (int i = 0; i < entries.length; i++) {
        final entry = entries[i];
        final entryTitle = entry.name.trim().isEmpty
            ? l10n.worldBookUnnamedEntry
            : entry.name.trim();
        final detail = !entry.enabled
            ? l10n.worldBookDisabledTag
            : (entry.constantActive ? l10n.worldBookAlwaysOnTag : null);
        children.add(
          _IosListRow(
            icon: Lucide.Bookmark,
            label: entryTitle,
            detailText: detail,
            enabled: entry.enabled,
            onTap: () {
              onEditEntry(entry);
            },
            onLongPress: () {
              showEntryActions(entry);
            },
          ),
        );
        if (i != entries.length - 1) {
          children.add(_iosDivider(context));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: collapsed
              ? const SizedBox(width: double.infinity, height: 0)
              : SizedBox(
                  width: double.infinity,
                  child: _IosSectionCard(children: children),
                ),
        ),
      ],
    );
  }
}

enum _EntryAction { edit, delete, cancel }

class _IosSectionCard extends StatelessWidget {
  const _IosSectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? Colors.white10 : Colors.white.withOpacity(0.96);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outlineVariant.withOpacity(isDark ? 0.08 : 0.06),
          width: 0.6,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: children),
      ),
    );
  }
}

Widget _iosDivider(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Divider(
    height: 6,
    thickness: 0.6,
    indent: 54,
    endIndent: 12,
    color: cs.outlineVariant.withOpacity(0.18),
  );
}

class _IosListRow extends StatelessWidget {
  const _IosListRow({
    required this.icon,
    required this.label,
    this.detailText,
    this.enabled = true,
    this.onTap,
    this.onLongPress,
  });

  final IconData icon;
  final String label;
  final String? detailText;
  final bool enabled;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final opacity = enabled ? 1.0 : 0.55;
    final baseColor = cs.onSurface.withOpacity(0.9 * opacity);
    final interactive = onTap != null || onLongPress != null;

    return IosCardPress(
      baseColor: Colors.transparent,
      borderRadius: BorderRadius.zero,
      pressedBlendStrength: 0,
      pressedScale: 1.0,
      haptics: interactive,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            SizedBox(width: 36, child: Icon(icon, size: 20, color: baseColor)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: baseColor,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (detailText != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  detailText!,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withOpacity(0.6 * opacity),
                  ),
                ),
              ),
            if (onTap != null)
              Icon(Lucide.ChevronRight, size: 16, color: baseColor),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: IosIconButton(
        icon: icon,
        size: 18,
        padding: const EdgeInsets.all(8),
        color: color ?? cs.onSurface.withOpacity(0.9),
        onTap: onTap,
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = color.withOpacity(0.14);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: cs.onSurface,
        ),
      ),
    );
  }
}

class _WorldBookEditSheet extends StatefulWidget {
  const _WorldBookEditSheet({required this.book});
  final WorldBook? book;

  @override
  State<_WorldBookEditSheet> createState() => _WorldBookEditSheetState();
}

class _WorldBookEditSheetState extends State<_WorldBookEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  bool _enabled = true;

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
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    final base = widget.book;

    Widget switchRow({
      required String label,
      String? hint,
      required bool value,
      required ValueChanged<bool> onChanged,
    }) {
      return IosCardPress(
        baseColor: Colors.transparent,
        borderRadius: BorderRadius.zero,
        pressedBlendStrength: 0,
        pressedScale: 1.0,
        haptics: false,
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface.withOpacity(0.9),
                      ),
                    ),
                    if (hint != null && hint.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        hint,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: cs.onSurface.withOpacity(0.6),
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IosSwitch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 10,
          right: 10,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                base == null ? l10n.worldBookAdd : l10n.worldBookConfig,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _IosSectionCard(
                      children: [
                        IosFormTextField(
                          label: l10n.worldBookNameLabel,
                          controller: _nameController,
                          autofocus: base == null,
                          textAlign: TextAlign.start,
                          textInputAction: TextInputAction.next,
                          inlineLabel: false,
                        ),
                        IosFormTextField(
                          label: l10n.worldBookDescriptionLabel,
                          controller: _descController,
                          maxLines: 2,
                          minLines: 2,
                          keyboardType: TextInputType.multiline,
                          textAlign: TextAlign.start,
                          textInputAction: TextInputAction.newline,
                          inlineLabel: false,
                        ),
                        switchRow(
                          label: l10n.worldBookEnabledLabel,
                          value: _enabled,
                          onChanged: (v) => setState(() => _enabled = v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _IosOutlineButton(
                    label: l10n.worldBookCancel,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _IosFilledButton(
                    label: l10n.worldBookSave,
                    onTap: () {
                      final result = WorldBook(
                        id: base?.id ?? const Uuid().v4(),
                        name: _nameController.text.trim(),
                        description: _descController.text.trim(),
                        enabled: _enabled,
                        entries: base?.entries ?? const <WorldBookEntry>[],
                      );
                      Navigator.of(context).pop(result);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WorldBookEntryEditSheet extends StatefulWidget {
  const _WorldBookEntryEditSheet({required this.entry});
  final WorldBookEntry? entry;

  @override
  State<_WorldBookEntryEditSheet> createState() =>
      _WorldBookEntryEditSheetState();
}

class _WorldBookEntryEditSheetState extends State<_WorldBookEntryEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _keywordInputController;
  late final TextEditingController _contentController;
  late final TextEditingController _priorityController;
  late final TextEditingController _scanDepthController;
  late final TextEditingController _injectDepthController;
  List<String> _keywords = <String>[];

  bool _enabled = true;
  bool _useRegex = false;
  bool _caseSensitive = false;
  bool _constantActive = false;
  late WorldBookInjectionPosition _position;
  late WorldBookInjectionRole _role;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _nameController = TextEditingController(text: entry?.name ?? '');
    _keywordInputController = TextEditingController();
    _contentController = TextEditingController(text: entry?.content ?? '');
    _priorityController = TextEditingController(
      text: (entry?.priority ?? 0).toString(),
    );
    _scanDepthController = TextEditingController(
      text: (entry?.scanDepth ?? 4).toString(),
    );
    _injectDepthController = TextEditingController(
      text: (entry?.injectDepth ?? 4).toString(),
    );
    _enabled = entry?.enabled ?? true;
    _useRegex = entry?.useRegex ?? false;
    _caseSensitive = entry?.caseSensitive ?? false;
    _constantActive = entry?.constantActive ?? false;
    _keywords = _cleanKeywords(entry?.keywords ?? const <String>[]);
    _position = entry?.position ?? WorldBookInjectionPosition.afterSystemPrompt;
    _role = entry?.role ?? WorldBookInjectionRole.user;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _keywordInputController.dispose();
    _contentController.dispose();
    _priorityController.dispose();
    _scanDepthController.dispose();
    _injectDepthController.dispose();
    super.dispose();
  }

  List<String> _cleanKeywords(Iterable<String> raw) {
    final seen = <String>{};
    final out = <String>[];
    for (final item in raw) {
      final k = item.trim();
      if (k.isEmpty) continue;
      if (seen.add(k)) out.add(k);
    }
    return out;
  }

  List<String> _parseKeywordInput(String raw) {
    final parts = raw.split(RegExp(r'[\n,，;；]'));
    final seen = <String>{};
    final out = <String>[];
    for (final p in parts) {
      final k = p.trim();
      if (k.isEmpty) continue;
      if (seen.add(k)) out.add(k);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final base = widget.entry;

    final canSave = _constantActive || _keywords.isNotEmpty;

    String positionLabel(WorldBookInjectionPosition p) {
      return switch (p) {
        WorldBookInjectionPosition.beforeSystemPrompt =>
          l10n.worldBookInjectionPositionBeforeSystemPrompt,
        WorldBookInjectionPosition.afterSystemPrompt =>
          l10n.worldBookInjectionPositionAfterSystemPrompt,
        WorldBookInjectionPosition.topOfChat =>
          l10n.worldBookInjectionPositionTopOfChat,
        WorldBookInjectionPosition.bottomOfChat =>
          l10n.worldBookInjectionPositionBottomOfChat,
        WorldBookInjectionPosition.atDepth =>
          l10n.worldBookInjectionPositionAtDepth,
      };
    }

    String roleLabel(WorldBookInjectionRole r) {
      return switch (r) {
        WorldBookInjectionRole.user => l10n.worldBookInjectionRoleUser,
        WorldBookInjectionRole.assistant =>
          l10n.worldBookInjectionRoleAssistant,
      };
    }

    void addKeywordsFromInput() {
      final parts = _parseKeywordInput(_keywordInputController.text);
      if (parts.isEmpty) return;
      setState(() {
        for (final k in parts) {
          if (_keywords.contains(k)) continue;
          _keywords.add(k);
        }
      });
      _keywordInputController.clear();
    }

    Widget switchRow({
      required String label,
      String? hint,
      required bool value,
      required ValueChanged<bool> onChanged,
    }) {
      return IosCardPress(
        baseColor: Colors.transparent,
        borderRadius: BorderRadius.zero,
        pressedBlendStrength: 0,
        pressedScale: 1.0,
        haptics: false,
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface.withOpacity(0.9),
                      ),
                    ),
                    if (hint != null && hint.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        hint,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: cs.onSurface.withOpacity(0.6),
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IosSwitch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      );
    }

    Widget valueRow({
      required String label,
      required String valueText,
      required VoidCallback onTap,
    }) {
      return IosCardPress(
        baseColor: Colors.transparent,
        borderRadius: BorderRadius.zero,
        pressedBlendStrength: 0,
        pressedScale: 1.0,
        haptics: false,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface.withOpacity(0.9),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                valueText,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withOpacity(0.62),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Lucide.ChevronRight,
                size: 16,
                color: cs.onSurface.withOpacity(0.55),
              ),
            ],
          ),
        ),
      );
    }

    Widget keywordChip(String keyword) {
      final color = cs.primary;
      final bg = color.withOpacity(isDark ? 0.22 : 0.12);
      final border = color.withOpacity(isDark ? 0.36 : 0.26);
      return Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border, width: 0.6),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: 10,
                right: 6,
                top: 6,
                bottom: 6,
              ),
              child: Text(
                keyword,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withOpacity(0.9),
                ),
              ),
            ),
            IosIconButton(
              icon: Lucide.X,
              size: 14,
              padding: const EdgeInsets.all(6),
              color: cs.onSurface.withOpacity(0.65),
              onTap: () => setState(() => _keywords.remove(keyword)),
            ),
            const SizedBox(width: 2),
          ],
        ),
      );
    }

    Future<void> pickPosition() async {
      final selected = await showModalBottomSheet<WorldBookInjectionPosition>(
        context: context,
        backgroundColor: cs.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          final localL10n = AppLocalizations.of(ctx)!;
          final localCs = Theme.of(ctx).colorScheme;

          Widget option(WorldBookInjectionPosition p) {
            final selected = _position == p;
            return IosCardPress(
              baseColor: Colors.transparent,
              borderRadius: BorderRadius.zero,
              pressedBlendStrength: 0,
              pressedScale: 1.0,
              haptics: false,
              onTap: () => Navigator.of(ctx).pop(p),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        positionLabel(p),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: localCs.onSurface.withOpacity(0.9),
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(Lucide.Check, size: 18, color: localCs.primary),
                  ],
                ),
              ),
            );
          }

          Widget divider() => Divider(
            height: 6,
            thickness: 0.6,
            indent: 12,
            endIndent: 12,
            color: localCs.outlineVariant.withOpacity(0.18),
          );

          final options = <WorldBookInjectionPosition>[
            WorldBookInjectionPosition.beforeSystemPrompt,
            WorldBookInjectionPosition.afterSystemPrompt,
            WorldBookInjectionPosition.topOfChat,
            WorldBookInjectionPosition.bottomOfChat,
            WorldBookInjectionPosition.atDepth,
          ];

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Text(
                      localL10n.worldBookEntryInjectionPositionLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _IosSectionCard(
                    children: [
                      for (int i = 0; i < options.length; i++) ...[
                        option(options[i]),
                        if (i != options.length - 1) divider(),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
      if (selected == null) return;
      setState(() => _position = selected);
    }

    Future<void> pickRole() async {
      final selected = await showModalBottomSheet<WorldBookInjectionRole>(
        context: context,
        backgroundColor: cs.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          final localL10n = AppLocalizations.of(ctx)!;
          final localCs = Theme.of(ctx).colorScheme;

          Widget option(WorldBookInjectionRole r) {
            final selected = _role == r;
            return IosCardPress(
              baseColor: Colors.transparent,
              borderRadius: BorderRadius.zero,
              pressedBlendStrength: 0,
              pressedScale: 1.0,
              haptics: false,
              onTap: () => Navigator.of(ctx).pop(r),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        roleLabel(r),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: localCs.onSurface.withOpacity(0.9),
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(Lucide.Check, size: 18, color: localCs.primary),
                  ],
                ),
              ),
            );
          }

          Widget divider() => Divider(
            height: 6,
            thickness: 0.6,
            indent: 12,
            endIndent: 12,
            color: localCs.outlineVariant.withOpacity(0.18),
          );

          final options = <WorldBookInjectionRole>[
            WorldBookInjectionRole.user,
            WorldBookInjectionRole.assistant,
          ];

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Text(
                      localL10n.worldBookEntryInjectionRoleLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _IosSectionCard(
                    children: [
                      for (int i = 0; i < options.length; i++) ...[
                        option(options[i]),
                        if (i != options.length - 1) divider(),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
      if (selected == null) return;
      setState(() => _role = selected);
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                base == null ? l10n.worldBookAddEntry : l10n.worldBookEditEntry,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _IosSectionCard(
                      children: [
                        IosFormTextField(
                          label: l10n.worldBookEntryNameLabel,
                          controller: _nameController,
                          autofocus: base == null,
                          textAlign: TextAlign.start,
                        ),
                        switchRow(
                          label: l10n.worldBookEntryEnabledLabel,
                          value: _enabled,
                          onChanged: (v) => setState(() => _enabled = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _IosSectionCard(
                      children: [
                        IosFormTextField(
                          label: l10n.worldBookEntryContentLabel,
                          controller: _contentController,
                          maxLines: 12,
                          minLines: 8,
                          inlineLabel: false,
                          textAlign: TextAlign.start,
                          textInputAction: TextInputAction.newline,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _IosSectionCard(
                      children: [
                        switchRow(
                          label: l10n.worldBookEntryAlwaysOnLabel,
                          hint: l10n.worldBookEntryAlwaysOnHint,
                          value: _constantActive,
                          onChanged: (v) => setState(() => _constantActive = v),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.worldBookEntryKeywordsLabel,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface.withOpacity(0.85),
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (_keywords.isNotEmpty)
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final k in _keywords) keywordChip(k),
                                  ],
                                ),
                              if (_keywords.isNotEmpty)
                                const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 40,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white12
                                              : const Color(0xFFF2F3F5),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 9,
                                        ),
                                        child: TextField(
                                          controller: _keywordInputController,
                                          onChanged: (_) => setState(() {}),
                                          textInputAction: TextInputAction.done,
                                          onSubmitted: (_) =>
                                              addKeywordsFromInput(),
                                          textAlignVertical:
                                              TextAlignVertical.center,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            color: cs.onSurface.withOpacity(
                                              0.92,
                                            ),
                                            height: 1.15,
                                          ),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            isCollapsed: true,
                                            hintText: l10n
                                                .worldBookEntryKeywordInputHint,
                                            hintStyle: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              color: cs.onSurface.withOpacity(
                                                isDark ? 0.42 : 0.46,
                                              ),
                                              height: 1.15,
                                            ),
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: Tooltip(
                                      message:
                                          l10n.worldBookEntryKeywordAddTooltip,
                                      child: IosCardPress(
                                        baseColor: isDark
                                            ? Colors.white12
                                            : const Color(0xFFF2F3F5),
                                        borderRadius: BorderRadius.circular(12),
                                        pressedScale: 0.98,
                                        haptics: false,
                                        onTap:
                                            _keywordInputController.text
                                                .trim()
                                                .isEmpty
                                            ? null
                                            : () {
                                                Haptics.light();
                                                addKeywordsFromInput();
                                              },
                                        child: Center(
                                          child: Icon(
                                            Lucide.Plus,
                                            size: 18,
                                            color: cs.onSurface.withOpacity(
                                              _keywordInputController.text
                                                      .trim()
                                                      .isEmpty
                                                  ? 0.35
                                                  : 0.9,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.worldBookEntryKeywordsHint,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: cs.onSurface.withOpacity(0.6),
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        switchRow(
                          label: l10n.worldBookEntryUseRegexLabel,
                          value: _useRegex,
                          onChanged: (v) => setState(() => _useRegex = v),
                        ),
                        switchRow(
                          label: l10n.worldBookEntryCaseSensitiveLabel,
                          value: _caseSensitive,
                          onChanged: (v) => setState(() => _caseSensitive = v),
                        ),
                        IosFormTextField(
                          label: l10n.worldBookEntryScanDepthLabel,
                          controller: _scanDepthController,
                          keyboardType: TextInputType.number,
                          fieldWidth: 64,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _IosSectionCard(
                      children: [
                        valueRow(
                          label: l10n.worldBookEntryInjectionPositionLabel,
                          valueText: positionLabel(_position),
                          onTap: pickPosition,
                        ),
                        if (_position ==
                            WorldBookInjectionPosition.atDepth) ...[
                          IosFormTextField(
                            label: l10n.worldBookEntryInjectDepthLabel,
                            controller: _injectDepthController,
                            keyboardType: TextInputType.number,
                            fieldWidth: 64,
                          ),
                        ],
                        valueRow(
                          label: l10n.worldBookEntryInjectionRoleLabel,
                          valueText: roleLabel(_role),
                          onTap: pickRole,
                        ),
                        IosFormTextField(
                          label: l10n.worldBookEntryPriorityLabel,
                          controller: _priorityController,
                          keyboardType: TextInputType.number,
                          fieldWidth: 64,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _IosOutlineButton(
                    label: l10n.worldBookCancel,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _IosFilledButton(
                    label: l10n.worldBookSave,
                    enabled: canSave,
                    onTap: () {
                      final id = base?.id ?? const Uuid().v4();
                      final keywords = List<String>.from(_keywords);
                      final priority =
                          int.tryParse(_priorityController.text.trim()) ??
                          (base?.priority ?? 0);
                      final scanDepth =
                          int.tryParse(_scanDepthController.text.trim()) ??
                          (base?.scanDepth ?? 4);
                      final injectDepth =
                          int.tryParse(_injectDepthController.text.trim()) ??
                          (base?.injectDepth ?? 4);

                      final result = WorldBookEntry(
                        id: id,
                        name: _nameController.text.trim(),
                        enabled: _enabled,
                        priority: priority,
                        position: _position,
                        content: _contentController.text,
                        injectDepth: injectDepth.clamp(1, 200).toInt(),
                        role: _role,
                        keywords: keywords,
                        useRegex: _useRegex,
                        caseSensitive: _caseSensitive,
                        scanDepth: scanDepth.clamp(1, 200).toInt(),
                        constantActive: _constantActive,
                      );
                      Navigator.of(context).pop(result);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IosOutlineButton extends StatefulWidget {
  const _IosOutlineButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<_IosOutlineButton> createState() => _IosOutlineButtonState();
}

class _IosOutlineButtonState extends State<_IosOutlineButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = Theme.of(context).brightness == Brightness.dark
        ? Colors.white10
        : const Color(0xFFF2F3F5);
    final overlay = _pressed
        ? (Theme.of(context).brightness == Brightness.dark
              ? Colors.white12
              : Colors.black12)
        : Colors.transparent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        Haptics.light();
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 44,
        decoration: BoxDecoration(
          color: Color.alphaBlend(overlay, bg),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
      ),
    );
  }
}

class _IosFilledButton extends StatefulWidget {
  const _IosFilledButton({
    required this.label,
    required this.onTap,
    this.enabled = true,
  });
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  State<_IosFilledButton> createState() => _IosFilledButtonState();
}

class _IosFilledButtonState extends State<_IosFilledButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = widget.enabled ? cs.primary : cs.primary.withOpacity(0.4);
    final overlay = _pressed
        ? Colors.black.withOpacity(0.12)
        : Colors.transparent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: widget.enabled
          ? () => setState(() => _pressed = false)
          : null,
      onTap: widget.enabled
          ? () {
              Haptics.light();
              widget.onTap();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 44,
        decoration: BoxDecoration(
          color: Color.alphaBlend(overlay, bg),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: cs.onPrimary.withOpacity(widget.enabled ? 1 : 0.6),
          ),
        ),
      ),
    );
  }
}
