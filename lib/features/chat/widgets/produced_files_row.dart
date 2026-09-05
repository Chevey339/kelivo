import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:Kelivo/core/services/workspace/file_link_resolver.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

import 'workspace_tool_ui.dart';

class ProducedFileEntry {
  const ProducedFileEntry({
    required this.label,
    this.link,
    required this.isImage,
  });

  final String label;
  final String? link;
  final bool isImage;

  String get dedupeKey => (link != null && link!.isNotEmpty) ? link! : label;
}

const int kProducedFilesLimit = 12;

List<ProducedFileEntry> collectProducedFileEntries(
  Iterable<WorkspaceToolPart> parts,
) {
  final seen = <String>{};
  final out = <ProducedFileEntry>[];
  for (final part in parts) {
    if (part.toolName != 'write_file' && part.toolName != 'edit_file') {
      continue;
    }
    final meta = workspaceMetadataFrom(part.metadata);
    final links = <String>[
      if (meta?.changedLinks != null) ...meta!.changedLinks!,
    ];
    if (links.isEmpty && meta?.link != null && meta!.link!.isNotEmpty) {
      links.add(meta.link!);
    }
    final files = meta?.changedFiles ?? const <String>[];
    if (links.isEmpty) {
      for (final file in files) {
        if (file.isEmpty || !seen.add(file)) continue;
        out.add(
          ProducedFileEntry(label: file, isImage: isWorkspaceImagePath(file)),
        );
      }
      continue;
    }
    for (var i = 0; i < links.length; i++) {
      final link = links[i];
      if (link.isEmpty || !seen.add(link)) continue;
      final path = i < files.length && files[i].isNotEmpty
          ? files[i]
          : KelivoLink.tryParse(link)?.relativePath ?? link;
      out.add(
        ProducedFileEntry(
          label: path,
          link: link,
          isImage: isWorkspaceImagePath(path) || isWorkspaceImagePath(link),
        ),
      );
    }
  }
  return out;
}

/// Deduped chips / image thumbs for files written or edited in a turn.
class ProducedFilesRow extends StatelessWidget {
  const ProducedFilesRow({
    super.key,
    required this.parts,
    required this.conversationId,
  });

  static const ValueKey<String> rowKey = ValueKey<String>('produced-files-row');
  static const ValueKey<String> moreKey = ValueKey<String>(
    'produced-files-more',
  );

  final List<WorkspaceToolPart> parts;
  final String conversationId;

  @override
  Widget build(BuildContext context) {
    final entries = collectProducedFileEntries(parts);
    if (entries.isEmpty) return const SizedBox.shrink();
    final visible = entries.length <= kProducedFilesLimit
        ? entries
        : entries.sublist(0, kProducedFilesLimit);
    final overflow = entries.length - visible.length;
    final l10n = AppLocalizations.of(context)!;
    return Wrap(
      key: rowKey,
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final entry in visible)
          entry.isImage
              ? _ProducedImageThumb(
                  entry: entry,
                  conversationId: conversationId,
                )
              : WorkspaceFileChip(
                  path: entry.label,
                  link: entry.link,
                  conversationId: conversationId,
                ),
        if (overflow > 0)
          Text(
            key: moreKey,
            l10n.workspaceToolMoreFiles(overflow),
            style: TextStyle(
              fontSize: 12,
              fontWeight: AppFontWeights.medium,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
      ],
    );
  }
}

class _ProducedImageThumb extends StatefulWidget {
  const _ProducedImageThumb({
    required this.entry,
    required this.conversationId,
  });

  final ProducedFileEntry entry;
  final String conversationId;

  @override
  State<_ProducedImageThumb> createState() => _ProducedImageThumbState();
}

class _ProducedImageThumbState extends State<_ProducedImageThumb> {
  File? _file;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_resolve());
  }

  @override
  void didUpdateWidget(covariant _ProducedImageThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.dedupeKey != widget.entry.dedupeKey ||
        oldWidget.conversationId != widget.conversationId) {
      unawaited(_resolve());
    }
  }

  Future<void> _resolve() async {
    setState(() {
      _failed = false;
      _file = null;
    });
    final file = await resolveWorkspaceLinkedFile(
      context,
      widget.entry.link,
      conversationId: widget.conversationId,
    );
    if (!mounted) return;
    setState(() {
      _file = file;
      _failed = file == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: widget.entry.label,
      child: IosCardPress(
        borderRadius: BorderRadius.circular(10),
        baseColor: Colors.transparent,
        padding: EdgeInsets.zero,
        onTap: widget.entry.link == null
            ? null
            : () {
                unawaited(
                  openWorkspaceLinkedFile(
                    context,
                    widget.entry.link,
                    conversationId: widget.conversationId,
                    title: widget.entry.label,
                  ),
                );
              },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 56,
            height: 56,
            child: _file != null
                ? Image.file(
                    _file!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(cs),
                  )
                : _placeholder(cs),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme cs) {
    return ColoredBox(
      color: context.appColors.surfaceFill,
      child: Icon(
        _failed ? Lucide.ImageOff : Lucide.Image,
        size: 18,
        color: cs.onSurface.withValues(alpha: 0.4),
      ),
    );
  }
}
