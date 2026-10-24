import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import '../models/ui_context_attachment.dart';
import 'genui_theme.dart';

/// A frozen, inspectable attachment. Source validity is supplied by the host;
/// this presentation never reads or modifies a surface's current values.
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
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
        key: const ValueKey('genui-context-chip'),
        padding: EdgeInsets.all(theme.sm),
        decoration: BoxDecoration(
          color: widget.stale ? theme.warningContainer : theme.fill,
          borderRadius: BorderRadius.circular(theme.cardRadius),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: widget.stale
                          ? theme.transparent
                          : theme.primaryContainer,
                      borderRadius: BorderRadius.circular(theme.controlRadius),
                    ),
                    child: Icon(
                      widget.stale
                          ? LucideIcons.unlink
                          : LucideIcons.panelsTopLeft,
                      size: 18,
                      color: widget.stale ? ink : theme.onPrimaryContainer,
                    ),
                  ),
                ),
                SizedBox(width: theme.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.content.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.header.copyWith(color: ink),
                      ),
                      SizedBox(height: theme.xxs),
                      Text(
                        widget.content.summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.label.copyWith(
                          color: widget.stale ? ink : theme.captionInk,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!widget.readOnly) ...[
                  Semantics(
                    expanded: _expanded,
                    child: IosIconButton(
                      key: const ValueKey('genui-context-expand'),
                      minSize: 44,
                      icon: _expanded
                          ? LucideIcons.chevronUp
                          : LucideIcons.chevronDown,
                      semanticLabel: _expanded
                          ? l10n.codeBlockCollapseButton
                          : l10n.genuiExpand,
                      tooltip: _expanded
                          ? l10n.codeBlockCollapseButton
                          : l10n.genuiExpand,
                      color: ink,
                      onTap: () => setState(() => _expanded = !_expanded),
                    ),
                  ),
                  IosIconButton(
                    key: const ValueKey('genui-context-remove'),
                    minSize: 44,
                    icon: LucideIcons.x,
                    semanticLabel: l10n.genuiChipRemove,
                    tooltip: l10n.genuiChipRemove,
                    color: ink,
                    enabled: widget.onRemove != null,
                    onTap: widget.onRemove,
                  ),
                ],
              ],
            ),
            if (widget.stale) ...[
              SizedBox(height: theme.xs),
              Semantics(
                liveRegion: true,
                child: Text(
                  l10n.genuiChipStale,
                  style: theme.caption.copyWith(color: ink),
                ),
              ),
            ],
            if (_expanded && !widget.readOnly) ...[
              SizedBox(height: theme.sm),
              Text(
                l10n.genuiChipExactText,
                style: theme.caption.copyWith(color: ink),
              ),
              SizedBox(height: theme.xs),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: SingleChildScrollView(
                  child: SelectableText(
                    widget.content.exactText,
                    key: const ValueKey('genui-context-exact-text'),
                    textDirection: TextDirection.ltr,
                    style: theme.mono.copyWith(fontSize: 12, color: ink),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
