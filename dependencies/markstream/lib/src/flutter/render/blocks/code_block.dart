import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/ast/nodes.dart';
import '../../../core/serialize/to_plain_text.dart';
import '../../extensions/registry.dart';
import '../../interfaces/renderers.dart';
import '../../theme/markstream_theme.dart';
import '../chrome.dart';
import 'code_content.dart';

class MarkstreamCodeBlock extends StatefulWidget {
  const MarkstreamCodeBlock({
    super.key,
    required this.node,
    required this.theme,
    required this.extensions,
    required this.options,
    required this.labels,
    this.highlighter,
    this.streaming = false,
    this.exporting = false,
  });
  final CodeBlockNode node;
  final MarkstreamTheme theme;
  final MarkstreamExtensions extensions;
  final CodeBlockOptions options;
  final MarkstreamLabels labels;
  final CodeHighlighter? highlighter;
  final bool streaming, exporting;
  @override
  State<MarkstreamCodeBlock> createState() => _MarkstreamCodeBlockState();
}

class _MarkstreamCodeBlockState extends State<MarkstreamCodeBlock> {
  bool? _manual;
  String get _language => widget.node.info.trim().split(RegExp(r'\s+')).first;
  @override
  void initState() {
    super.initState();
    _restore();
  }

  void _restore() => _manual = widget.options.expansionState?.read(
    _language,
    widget.node.code,
  );
  @override
  void didUpdateWidget(MarkstreamCodeBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.span.start != widget.node.span.start ||
        !toPlainText(widget.node).startsWith(toPlainText(oldWidget.node)) ||
        oldWidget.node.info != widget.node.info) {
      _restore();
    } else if (_manual != null && oldWidget.node.code != widget.node.code) {
      // A very short stream can be toggled before its 16-character anchor is
      // complete. Carry that choice forward so a later remount can find it.
      widget.options.expansionState?.remember(
        _language,
        widget.node.code,
        _manual!,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme.code;
    final chrome = widget.theme.chrome;
    final lines = codeLineCount(toPlainText(widget.node));
    final expanded =
        widget.exporting ||
        (_manual ??
            (!widget.options.autoCollapse ||
                lines <= widget.options.collapsedLines));
    final mobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    void toggle() {
      setState(() => _manual = !expanded);
      widget.options.expansionState?.remember(
        _language,
        widget.node.code,
        !expanded,
      );
    }

    Widget content = MarkstreamCodeContent(
      node: widget.node,
      theme: widget.theme,
      highlighter: widget.highlighter,
      streaming: widget.streaming,
      exporting: widget.exporting,
      wrap: widget.exporting || !mobile || widget.options.mobileWrap,
      highlight: widget.options.highlight,
      maxLines: expanded ? null : widget.options.collapsedLines,
    );
    if (!expanded &&
        lines > widget.options.collapsedLines &&
        theme.fadeHeight > 0) {
      // Fade the code itself so translucent surfaces retain their backdrop.
      content = ShaderMask(
        key: const ValueKey('markstream-code-collapse-fade'),
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) =>
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black,
                Colors.black.withValues(alpha: .28),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromLTRB(
                bounds.left,
                (bounds.bottom - theme.fadeHeight).clamp(
                  bounds.top,
                  bounds.bottom,
                ),
                bounds.right,
                bounds.bottom,
              ),
            ),
        child: content,
      );
    }
    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: content,
    );
    return Container(
      key: const ValueKey('markstream-code-surface'),
      margin: theme.margin,
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: BorderRadius.circular(theme.radius),
      ),
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: theme.borderColor),
        borderRadius: BorderRadius.circular(theme.radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectionContainer.disabled(
            child: Container(
              key: const ValueKey('markstream-code-header'),
              height: chrome.height,
              decoration: BoxDecoration(
                color: chrome.background,
                border: Border(
                  bottom: BorderSide(
                    color: chrome.divider,
                    width: MarkstreamTheme.stroke,
                  ),
                ),
              ),
              child: Padding(
                padding: chrome.padding,
                child: LayoutBuilder(
                  builder: (context, constraints) => Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          key: const ValueKey('markstream-code-toggle'),
                          button: !widget.exporting,
                          expanded: expanded,
                          label: widget.exporting
                              ? null
                              : expanded
                              ? widget.labels.collapse
                              : widget.labels.expand,
                          child: TextButton(
                            onPressed: widget.exporting ? null : toggle,
                            style:
                                TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  minimumSize: Size(0, chrome.actionSize),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  alignment: Alignment.centerLeft,
                                  foregroundColor: theme.label.color,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      chrome.actionRadius,
                                    ),
                                  ),
                                  splashFactory: NoSplash.splashFactory,
                                ).copyWith(
                                  overlayColor: WidgetStateProperty.resolveWith(
                                    (states) =>
                                        states.contains(WidgetState.pressed)
                                        ? Colors.transparent
                                        : null,
                                  ),
                                ),
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _language.isEmpty
                                        ? widget.labels.unnamedCode
                                        : _language,
                                    style: theme.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (!expanded)
                                  ExcludeSemantics(
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Icon(
                                        LucideIcons.chevronRight,
                                        size: 14,
                                        color: chrome.actionColor,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (!widget.exporting)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth * .75,
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            primary: false,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ...?widget.extensions.codeExtraActions?.call(
                                  context,
                                  CodeActionContext(
                                    code: widget.node,
                                    theme: widget.theme,
                                    streaming: widget.streaming,
                                  ),
                                ),
                                MarkstreamActionButton(
                                  action: MarkstreamAction(
                                    chrome: chrome,
                                    kind: MarkstreamActionKind.copyCode,
                                    label: widget.labels.copyCode,
                                    onInvoke: () => Clipboard.setData(
                                      ClipboardData(text: widget.node.code),
                                    ),
                                  ),
                                  builder:
                                      widget.extensions.actionButtonBuilder,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (widget.exporting)
            body
          else
            AnimatedSize(
              duration: theme.collapseDuration,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: body,
            ),
        ],
      ),
    );
  }
}
