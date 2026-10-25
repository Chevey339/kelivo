import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import '../models/ui_context_attachment.dart';
import 'genui_theme.dart';

/// The attachment is frozen. Presentation never reads the source's live values.
class GenUiContextChip extends StatefulWidget {
  const GenUiContextChip({
    super.key,
    required this.content,
    this.stale = false,
    this.readOnly = false,
    this.onRemove,
  });
  final UiContextText content;
  final bool stale, readOnly;
  final VoidCallback? onRemove;
  @override
  State<GenUiContextChip> createState() => _GenUiContextChipState();
}

class _GenUiContextChipState extends State<GenUiContextChip> {
  bool _expanded = false;
  @override
  void didUpdateWidget(GenUiContextChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content || widget.readOnly) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) =>
      GenUiThemeScope(child: Builder(builder: _build));

  Widget _build(BuildContext context) {
    final theme = GenUiTheme.of(context), l10n = AppLocalizations.of(context)!;
    final ink = widget.stale ? theme.onWarningContainer : theme.ink;
    final summary = widget.content.body
        .split('\n')
        .where(
          (line) =>
              line.trim().isNotEmpty &&
              line.trim() != widget.content.title.trim(),
        )
        .take(2)
        .join(' · ');
    Widget heading() => Row(
      children: [
        ExcludeSemantics(
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: widget.stale ? theme.transparent : theme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.stale ? LucideIcons.unlink : LucideIcons.panelsTopLeft,
              size: 16,
              color: widget.stale ? ink : theme.onPrimaryContainer,
            ),
          ),
        ),
        SizedBox(width: theme.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.content.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.header.copyWith(color: ink),
              ),
              Semantics(
                liveRegion: widget.stale,
                child: Text(
                  widget.stale ? l10n.genuiChipStale : summary,
                  maxLines: widget.stale ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.badge.copyWith(
                    fontWeight: FontWeight.normal,
                    color: widget.stale ? ink : theme.captionInk,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!widget.readOnly) ...[
          SizedBox(width: theme.xxs),
          Icon(
            _expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
            size: 14,
            color: theme.captionInk,
          ),
        ],
      ],
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
        key: const ValueKey('genui-context-chip'),
        padding: EdgeInsetsDirectional.fromSTEB(
          theme.xs,
          theme.xxs,
          widget.readOnly ? theme.xs : 0,
          theme.xxs,
        ),
        decoration: BoxDecoration(
          color: widget.stale ? theme.warningContainer : theme.cardFill,
          borderRadius: BorderRadius.circular(theme.cardRadius),
          border: Border.all(
            color: widget.stale
                ? theme.onWarningContainer.withValues(alpha: .15)
                : theme.hairline,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: widget.readOnly
                      ? Padding(
                          padding: EdgeInsets.symmetric(vertical: theme.xxs),
                          child: heading(),
                        )
                      : Semantics(
                          expanded: _expanded,
                          child: IosIconButton(
                            key: const ValueKey('genui-context-expand'),
                            minSize: 44,
                            padding: EdgeInsets.zero,
                            tooltip: _expanded
                                ? l10n.codeBlockCollapseButton
                                : l10n.genuiExpand,
                            builder: (_) => heading(),
                            onTap: () => setState(() => _expanded = !_expanded),
                          ),
                        ),
                ),
                if (!widget.readOnly)
                  IosIconButton(
                    key: const ValueKey('genui-context-remove'),
                    icon: LucideIcons.x,
                    size: 15,
                    minSize: 44,
                    visualSize: 28,
                    tooltip: l10n.genuiChipRemove,
                    color: theme.captionInk,
                    enabled: widget.onRemove != null,
                    onTap: widget.onRemove,
                  ),
              ],
            ),
            if (_expanded && !widget.readOnly)
              Padding(
                padding: EdgeInsetsDirectional.only(
                  end: theme.xs,
                  bottom: theme.xxs,
                ),
                child: Container(
                  padding: EdgeInsets.all(theme.xs),
                  decoration: BoxDecoration(
                    color: theme.card,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            LucideIcons.lockKeyhole,
                            size: 12,
                            color: theme.captionInk,
                          ),
                          SizedBox(width: theme.xxs),
                          Expanded(
                            child: Text(
                              l10n.genuiChipExactText,
                              style: theme.badge.copyWith(
                                color: theme.captionInk,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: theme.xs),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 132),
                        child: SingleChildScrollView(
                          primary: false,
                          child: SelectableText(
                            widget.content.exactText,
                            key: const ValueKey('genui-context-exact-text'),
                            textDirection: TextDirection.ltr,
                            style: theme.mono.copyWith(
                              fontSize: theme.label.fontSize,
                              height: 1.5,
                              color: theme.secondaryInk,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
