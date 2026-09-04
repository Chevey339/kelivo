import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

enum UnifiedDiffLineKind { add, remove, hunk, fileHeader, context }

UnifiedDiffLineKind classifyUnifiedDiffLine(String line) {
  if (line.startsWith('+++') || line.startsWith('---')) {
    return UnifiedDiffLineKind.fileHeader;
  }
  if (line.startsWith('@@')) return UnifiedDiffLineKind.hunk;
  if (line.startsWith('+')) return UnifiedDiffLineKind.add;
  if (line.startsWith('-')) return UnifiedDiffLineKind.remove;
  return UnifiedDiffLineKind.context;
}

({int added, int removed}) countUnifiedDiffChanges(String diff) {
  var added = 0;
  var removed = 0;
  for (final line in const LineSplitter().convert(diff)) {
    switch (classifyUnifiedDiffLine(line)) {
      case UnifiedDiffLineKind.add:
        added++;
      case UnifiedDiffLineKind.remove:
        removed++;
      default:
        break;
    }
  }
  return (added: added, removed: removed);
}

/// Line-by-line unified diff with tinted `+` / `-` / `@@` rows.
///
/// Uses [ListView.builder] when the payload exceeds [virtualizeAfter] lines.
class UnifiedDiffView extends StatelessWidget {
  const UnifiedDiffView({
    super.key,
    required this.diff,
    this.virtualizeAfter,
    this.showHeader = false,
    this.fileName,
    this.added,
    this.removed,
    this.maxLines,
  });

  static const int defaultVirtualizeAfter = 500;
  static const ValueKey<String> viewKey = ValueKey<String>('unified-diff-view');
  static const ValueKey<String> headerKey = ValueKey<String>(
    'unified-diff-header',
  );

  final String diff;
  final int? virtualizeAfter;
  final bool showHeader;
  final String? fileName;
  final int? added;
  final int? removed;
  final int? maxLines;

  int get _threshold => virtualizeAfter ?? defaultVirtualizeAfter;

  String _codeFontFamily(BuildContext context) {
    try {
      final fam = context.watch<SettingsProvider>().codeFontFamily;
      if (fam == null || fam.isEmpty) return 'monospace';
      return fam;
    } on ProviderNotFoundException {
      return 'monospace';
    }
  }

  @override
  Widget build(BuildContext context) {
    final allLines = const LineSplitter().convert(diff);
    final lines = maxLines == null
        ? allLines
        : allLines.take(maxLines!).toList();
    if (allLines.isEmpty) {
      return const SizedBox.shrink(key: viewKey);
    }
    final counts = countUnifiedDiffChanges(diff);
    final addedCount = added ?? counts.added;
    final removedCount = removed ?? counts.removed;
    final fontFamily = _codeFontFamily(context);

    return LayoutBuilder(
      key: viewKey,
      builder: (context, constraints) {
        final maxChars = lines.fold<int>(
          0,
          (m, line) => math.max(m, line.length),
        );
        final estimatedWidth = maxChars * 7.8 + 24;
        final minWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : estimatedWidth;
        final width = math.max(minWidth, estimatedWidth);
        final body = lines.length > _threshold
            ? _virtualized(context, lines, constraints, width, fontFamily)
            : _column(context, lines, width, fontFamily);
        final scrolled = Scrollbar(
          thumbVisibility: false,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: body,
          ),
        );
        if (!showHeader) return scrolled;
        final header = _DiffHeader(
          fileName: fileName ?? '',
          added: addedCount,
          removed: removedCount,
          diff: diff,
        );
        if (constraints.maxHeight.isFinite) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              Expanded(child: scrolled),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [header, scrolled],
        );
      },
    );
  }

  Widget _virtualized(
    BuildContext context,
    List<String> lines,
    BoxConstraints constraints,
    double width,
    String fontFamily,
  ) {
    final height = constraints.maxHeight.isFinite
        ? constraints.maxHeight
        : math.min(lines.length * 18.0, 360.0);
    return SizedBox(
      width: width,
      height: height,
      child: ListView.builder(
        itemCount: lines.length,
        itemBuilder: (context, index) =>
            _DiffLine(line: lines[index], fontFamily: fontFamily),
      ),
    );
  }

  Widget _column(
    BuildContext context,
    List<String> lines,
    double width,
    String fontFamily,
  ) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final line in lines)
            _DiffLine(line: line, fontFamily: fontFamily),
        ],
      ),
    );
  }
}

class _DiffHeader extends StatelessWidget {
  const _DiffHeader({
    required this.fileName,
    required this.added,
    required this.removed,
    required this.diff,
  });

  final String fileName;
  final int added;
  final int removed;
  final String diff;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return Padding(
      key: UnifiedDiffView.headerKey,
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: AppFontWeights.semibold,
                color: cs.onSurface,
              ),
            ),
          ),
          _CountCapsule(label: '+$added', color: colors.success),
          const SizedBox(width: 6),
          _CountCapsule(label: '−$removed', color: cs.error),
          const SizedBox(width: 4),
          Tooltip(
            message: l10n.workspaceToolCopyDiff,
            child: IosIconButton(
              icon: Lucide.Copy,
              size: 16,
              semanticLabel: l10n.workspaceToolCopyDiff,
              onTap: diff.isEmpty
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: diff));
                      if (!context.mounted) return;
                      showAppSnackBar(
                        context,
                        message: l10n.workspaceToolCopied,
                        type: NotificationType.success,
                      );
                    },
            ),
          ),
        ],
      ),
    );
  }
}

class _CountCapsule extends StatelessWidget {
  const _CountCapsule({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: AppFontWeights.medium,
          color: color,
        ),
      ),
    );
  }
}

class _DiffLine extends StatelessWidget {
  const _DiffLine({required this.line, required this.fontFamily});

  final String line;
  final String fontFamily;

  @override
  Widget build(BuildContext context) {
    final kind = classifyUnifiedDiffLine(line);
    final cs = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final (Color? background, Color foreground) = switch (kind) {
      UnifiedDiffLineKind.add => (
        colors.success.withValues(alpha: 0.14),
        colors.success,
      ),
      UnifiedDiffLineKind.remove => (
        cs.error.withValues(alpha: 0.14),
        cs.error,
      ),
      UnifiedDiffLineKind.hunk => (null, cs.onSurface.withValues(alpha: 0.5)),
      UnifiedDiffLineKind.fileHeader => (
        null,
        cs.onSurface.withValues(alpha: 0.5),
      ),
      UnifiedDiffLineKind.context => (
        null,
        cs.onSurface.withValues(alpha: 0.82),
      ),
    };
    return ColoredBox(
      color: background ?? Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        child: SelectableText(
          line,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            height: 1.45,
            color: foreground,
          ),
        ),
      ),
    );
  }
}
