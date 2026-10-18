import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  });
  final CodeBlockNode node;
  final MarkstreamTheme theme;
  final MarkstreamExtensions extensions;
  final CodeBlockOptions options;
  final MarkstreamLabels labels;
  final CodeHighlighter? highlighter;
  final bool streaming;
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
        oldWidget.node.info != widget.node.info)
      _restore();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme.code;
    final lines = codeLineCount(toPlainText(widget.node));
    final expanded =
        _manual ??
        (!widget.options.autoCollapse ||
            lines <= widget.options.collapsedLines);
    final mobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    Widget action(
      MarkstreamActionKind kind,
      String label,
      VoidCallback invoke,
    ) => MarkstreamActionButton(
      action: MarkstreamAction(kind: kind, label: label, onInvoke: invoke),
      builder: widget.extensions.actionButtonBuilder,
    );
    final body = Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: MarkstreamCodeContent(
            node: widget.node,
            theme: widget.theme,
            highlighter: widget.highlighter,
            streaming: widget.streaming,
            wrap: !mobile || widget.options.mobileWrap,
            highlight: widget.options.highlight,
            maxLines: expanded ? null : widget.options.collapsedLines,
          ),
        ),
        if (!expanded)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: theme.fadeHeight,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.backgroundColor.withValues(alpha: 0),
                      theme.backgroundColor,
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    return Container(
      margin: theme.margin,
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        border: Border.all(color: theme.borderColor),
        borderRadius: BorderRadius.circular(theme.radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectionContainer.disabled(
            child: ColoredBox(
              color: theme.headerBackgroundColor,
              child: Padding(
                padding: theme.headerPadding,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _language.isEmpty
                            ? widget.labels.unnamedCode
                            : _language,
                        style: theme.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Flexible(
                      flex: 4,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        primary: false,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (lines > widget.options.collapsedLines)
                              action(
                                expanded
                                    ? MarkstreamActionKind.collapse
                                    : MarkstreamActionKind.expand,
                                expanded
                                    ? widget.labels.collapse
                                    : widget.labels.expand,
                                () {
                                  setState(() => _manual = !expanded);
                                  widget.options.expansionState?.remember(
                                    _language,
                                    widget.node.code,
                                    !expanded,
                                  );
                                },
                              ),
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
                                kind: MarkstreamActionKind.copyCode,
                                label: widget.labels.copyCode,
                                onInvoke: () => Clipboard.setData(
                                  ClipboardData(text: widget.node.code),
                                ),
                              ),
                              builder: widget.extensions.actionButtonBuilder,
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
          AnimatedSize(
            duration: theme.collapseDuration,
            alignment: Alignment.topCenter,
            child: body,
          ),
        ],
      ),
    );
  }
}
