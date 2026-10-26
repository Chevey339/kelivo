import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/ios_text_button.dart';

import '../host/ui_web_document.dart';
import 'genui_clipboard.dart';
import 'genui_content.dart';
import 'genui_control_region.dart';
import 'genui_theme.dart';

class GenUiWebCard extends StatefulWidget {
  const GenUiWebCard({
    super.key,
    required this.document,
    required this.supported,
    this.exporting = false,
    this.onOpen,
    this.onExportHtml,
  });
  final UiWebDocument document;
  final bool supported, exporting;
  final Future<void> Function(UiWebDocument)? onOpen;
  final Future<void> Function(UiWebDocument)? onExportHtml;
  @override
  State<GenUiWebCard> createState() => _GenUiWebCardState();
}

class _GenUiWebCardState extends State<GenUiWebCard> {
  final _openFocus = FocusNode(debugLabel: 'Web preview Open');
  bool _source = false, _busy = false;
  @override
  void dispose() {
    _openFocus.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (_busy ||
        !widget.document.canOpen ||
        !widget.supported ||
        widget.exporting) {
      return;
    }
    final open = widget.onOpen;
    if (open == null) return;
    final document = widget.document;
    setState(() {
      _busy = true;
    });
    try {
      await open(document);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
        _openFocus.requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = GenUiTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final document = widget.document;
    final invalid = document.phase == UiWebPhase.invalid;
    final streaming = document.phase == UiWebPhase.streaming;
    final interrupted = document.phase == UiWebPhase.interrupted;
    final title = document.hasMetadata ? document.title : l10n.genuiWebTitle;
    final reason = invalid
        ? switch (document.error) {
            UiWebError.sourceBudget => l10n.genuiErrorSourceBudget,
            UiWebError.emptyDocument => l10n.genuiWebEmpty,
            _ => l10n.genuiWebInvalidMeta,
          }
        : interrupted
        ? l10n.genuiStatusInterrupted
        : l10n.genuiWebNotReady;
    final actions = !widget.exporting;
    return Semantics(
      container: true,
      label: title,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(theme.cardRadius),
          border: Border.all(color: theme.hairline),
        ),
        child: Padding(
          padding: EdgeInsets.all(theme.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: theme.primaryContainer,
                        borderRadius: BorderRadius.circular(
                          theme.controlRadius,
                        ),
                      ),
                      child: Icon(
                        LucideIcons.globe,
                        size: 18,
                        color: theme.primary,
                      ),
                    ),
                  ),
                  SizedBox(width: theme.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ExcludeSemantics(
                          child: Text(
                            title,
                            style: theme.header,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (document.summary.isNotEmpty) ...[
                          SizedBox(height: theme.xxs),
                          Text(
                            document.summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.caption.copyWith(
                              color: theme.secondaryInk,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (streaming || interrupted)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: GenUiBadge(
                    text: streaming
                        ? l10n.genuiStatusStreaming
                        : l10n.genuiStatusInterrupted,
                    tone: streaming ? 'primary' : 'warning',
                  ),
                ),
              if (invalid ||
                  (!widget.supported && !widget.exporting) ||
                  (streaming && actions)) ...[
                SizedBox(height: theme.xs),
                Text(
                  invalid
                      ? reason
                      : !widget.supported
                      ? l10n.genuiWebUnsupported
                      : reason,
                  style: theme.caption.copyWith(
                    color: invalid ? theme.error : theme.captionInk,
                  ),
                ),
              ],
              if (actions) ...[
                SizedBox(height: theme.xxs),
                Wrap(
                  spacing: theme.xs,
                  runSpacing: theme.xxs,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    GenUiControlRegion(
                      child: IosTextButton(
                        label: l10n.genuiViewSource,
                        icon: LucideIcons.codeXml,
                        color: theme.secondaryInk,
                        onPressed: () => setState(() {
                          _source = !_source;
                        }),
                      ),
                    ),
                    if (widget.supported && !invalid)
                      GenUiWebOpenButton(
                        label: l10n.genuiWebOpen,
                        focusNode: _openFocus,
                        reason: document.canOpen ? null : reason,
                        enabled:
                            document.canOpen && !_busy && widget.onOpen != null,
                        onTap: _open,
                      ),
                    if (!widget.supported && !invalid) ...[
                      GenUiControlRegion(
                        child: IosTextButton(
                          label: l10n.genuiCopySource,
                          icon: LucideIcons.copy,
                          color: theme.primary,
                          onPressed: () =>
                              copyGenUiText(context, document.source),
                        ),
                      ),
                      if (widget.onExportHtml != null)
                        GenUiControlRegion(
                          child: IosTextButton(
                            label: l10n.genuiWebExportHtml,
                            icon: LucideIcons.download,
                            color: theme.primary,
                            onPressed: () => widget.onExportHtml!(document),
                          ),
                        ),
                    ],
                  ],
                ),
              ],
              if (_source && actions) ...[
                SizedBox(height: theme.sm),
                GenUiSource(source: document.source, language: 'kelivo-web'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Use the app press treatment, with a focusable disabled reason and no shrinking
/// of the label at large text scales.
class GenUiWebOpenButton extends StatefulWidget {
  const GenUiWebOpenButton({
    super.key,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.reason,
    this.focusNode,
  });
  final String label;
  final String? reason;
  final bool enabled;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  @override
  State<GenUiWebOpenButton> createState() => _GenUiWebOpenButtonState();
}

class _GenUiWebOpenButtonState extends State<GenUiWebOpenButton> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) {
    final theme = GenUiTheme.of(context);
    final disabled = !widget.enabled;
    Widget button = GenUiControlRegion(
      child: FocusableActionDetector(
        focusNode: widget.focusNode,
        onShowFocusHighlight: (value) => setState(() {
          _focused = value;
        }),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              if (widget.enabled) widget.onTap();
              return null;
            },
          ),
        },
        child: Semantics(
          button: true,
          enabled: widget.enabled,
          label: widget.label,
          hint: widget.reason,
          onTap: disabled ? null : widget.onTap,
          child: ExcludeSemantics(
            child: IosCardPress(
              haptics: false,
              onTap: disabled ? null : widget.onTap,
              baseColor: theme.transparent,
              borderRadius: BorderRadius.circular(theme.controlRadius),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 160),
              pressedScale: MediaQuery.disableAnimationsOf(context) ? 1 : .98,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 32),
                  decoration: BoxDecoration(
                    color: disabled ? theme.fill : theme.primary,
                    borderRadius: BorderRadius.circular(theme.controlRadius),
                    border: Border.all(
                      color: _focused ? theme.primary : theme.transparent,
                      width: 2,
                    ),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: theme.sm,
                    vertical: theme.xxs,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 20,
                      minWidth: 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.externalLink,
                          size: 14,
                          color: disabled ? theme.disabledInk : theme.onPrimary,
                        ),
                        SizedBox(width: theme.xs),
                        Flexible(
                          child: Text(
                            widget.label,
                            style: theme.header.copyWith(
                              color: disabled
                                  ? theme.disabledInk
                                  : theme.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (widget.reason case final reason?) {
      button = Tooltip(message: reason, child: button);
    }
    return button;
  }
}
