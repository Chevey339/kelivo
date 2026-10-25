import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/models/context_operation.dart';
import '../../../core/models/context_compression_task.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/platform_utils.dart';
import 'context_compression_status.dart';

/// A node and a running task share the original clear-context divider geometry.
class ContextOperationDivider extends StatefulWidget {
  const ContextOperationDivider({
    super.key,
    required ContextOperation this.operation,
    required this.onOpen,
    this.onUndo,
    this.superseded = false,
    this.hiddenByClear = false,
  }) : task = null,
       waitingForApproval = false;
  const ContextOperationDivider.task({
    super.key,
    required ContextCompressionTask this.task,
    required this.onOpen,
    this.waitingForApproval = false,
  }) : operation = null,
       onUndo = null,
       superseded = false,
       hiddenByClear = false;
  final ContextOperation? operation;
  final ContextCompressionTask? task;
  final VoidCallback onOpen;
  final VoidCallback? onUndo;
  final bool superseded;
  final bool hiddenByClear;
  final bool waitingForApproval;

  @override
  State<ContextOperationDivider> createState() =>
      _ContextOperationDividerState();
}

class _ContextOperationDividerState extends State<ContextOperationDivider> {
  bool _hovered = false;
  bool _focused = false;
  bool _highlight = false;
  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();
    _updateHighlight();
  }

  @override
  void didUpdateWidget(covariant ContextOperationDivider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.operation?.id != widget.operation?.id) _updateHighlight();
  }

  void _updateHighlight() {
    _highlightTimer?.cancel();
    final operation = widget.operation;
    final age = operation == null
        ? const Duration(seconds: 2)
        : DateTime.now().difference(operation.createdAt);
    _highlight =
        age >= Duration.zero && age < const Duration(milliseconds: 1500);
    if (_highlight) {
      _highlightTimer = Timer(const Duration(milliseconds: 1500) - age, () {
        if (mounted) setState(() => _highlight = false);
      });
    }
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final operation = widget.operation;
    final task = widget.task;
    if (operation?.revoked == true ||
        (task != null && !compressionShowsDivider(task))) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final desktop = PlatformUtils.isDesktopTarget;
    final hovered = desktop && (_hovered || _focused);
    final showUndo =
        operation != null && widget.onUndo != null && (!desktop || hovered);
    final symmetricIcons = showUndo && !desktop;
    final undoSize = desktop ? 18.0 : 28.0;
    final color = _highlight ? cs.primary : cs.onSurface.withValues(alpha: .6);
    final label = task != null
        ? compressionDividerLabel(
            l10n,
            task,
            waitingForApproval: widget.waitingForApproval,
          )
        : '${operation!.isCompression ? l10n.contextDividerCompressed : l10n.homePageClearContext}'
              '${operation.isCompression && operation.isEdited ? ' · ${l10n.contextDividerEdited}' : ''}';
    final undoLabel = operation?.isCompression == true
        ? l10n.contextUndoCompressTooltip
        : l10n.contextUndoClearTooltip;
    final failed =
        task?.phase == CompressionPhase.failed ||
        task?.phase == CompressionPhase.interrupted;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Opacity(
          opacity: widget.superseded || widget.hiddenByClear ? .5 : 1,
          child: SizedBox(
            height: 28,
            child: Row(
              children: [
                Expanded(
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: cs.outlineVariant.withValues(alpha: .6),
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: (constraints.maxWidth - 48).clamp(
                      0.0,
                      double.infinity,
                    ),
                  ),
                  child: Focus(
                    canRequestFocus: false,
                    onFocusChange: (value) => setState(() => _focused = value),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onEnter: (_) => setState(() => _hovered = true),
                      onExit: (_) => setState(() => _hovered = false),
                      child: Container(
                        height: desktop ? 24 : 28,
                        decoration: BoxDecoration(
                          color: hovered
                              ? cs.onSurface.withValues(alpha: .05)
                              : null,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: InkWell(
                                onTap: widget.onOpen,
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    left: 10,
                                    right: symmetricIcons ? 0 : 10,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (task != null && !failed)
                                        SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1.5,
                                            color: color,
                                          ),
                                        )
                                      else
                                        SizedBox(
                                          width: symmetricIcons ? undoSize : 12,
                                          height: symmetricIcons
                                              ? undoSize
                                              : 12,
                                          child: Icon(
                                            failed
                                                ? LucideIcons.circleAlert
                                                : operation?.isCompression ==
                                                      true
                                                ? LucideIcons.package2
                                                : LucideIcons.eraser,
                                            size: 12,
                                            color: failed ? cs.error : color,
                                          ),
                                        ),
                                      if (!symmetricIcons)
                                        const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            height: 1,
                                            color: color,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (showUndo)
                              Padding(
                                padding: EdgeInsets.only(
                                  right: symmetricIcons ? 10 : 6,
                                ),
                                child: Tooltip(
                                  message: undoLabel,
                                  child: SizedBox(
                                    width: undoSize,
                                    height: undoSize,
                                    child: IconButton(
                                      key: ValueKey(
                                        'undo-context-${operation.id}',
                                      ),
                                      onPressed: widget.onUndo,
                                      padding: EdgeInsets.zero,
                                      constraints: BoxConstraints.tightFor(
                                        width: undoSize,
                                        height: undoSize,
                                      ),
                                      style: IconButton.styleFrom(
                                        focusColor: cs.primary.withValues(
                                          alpha: .15,
                                        ),
                                      ),
                                      icon: Icon(
                                        LucideIcons.x,
                                        size: 12,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: cs.outlineVariant.withValues(alpha: .6),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
