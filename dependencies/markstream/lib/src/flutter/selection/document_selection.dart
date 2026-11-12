import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../core/ast/nodes.dart';
import 'selection_controller.dart';
import 'stable_selection_container.dart';

/// Adds clipboard-only block separators and list markers. They do not consume
/// native selection offsets or register additional selectable glyphs.
class DocumentSelectionDelegate extends StableSelectionDelegate {
  DocumentSelectionDelegate({
    this.separator = '\n\n',
    this.prefix = '',
    this.continuation = '',
  });
  String separator, prefix, continuation;
  @override
  SelectedContent? getSelectedContent() {
    final pieces = <String>[];
    for (final child in selectables) {
      final content = child.getSelectedContent();
      if (content != null && content.plainText.isNotEmpty)
        pieces.add(content.plainText);
    }
    if (pieces.isEmpty) return null;
    final text = pieces.join(separator);
    if (prefix.isEmpty) return SelectedContent(plainText: text);
    final range = getSelection();
    final startsAtBeginning =
        range != null && math.min(range.startOffset, range.endOffset) == 0;
    return SelectedContent(
      plainText: startsAtBeginning
          ? '$prefix${text.replaceAll('\n', '\n$continuation')}'
          : text,
    );
  }
}

class DocumentSelectionGroup extends StatefulWidget {
  const DocumentSelectionGroup({
    super.key,
    required this.child,
    this.node,
    this.separator = '\n\n',
    this.prefix = '',
    this.continuation = '',
    this.root = false,
  });
  final Widget child;
  final MarkdownNode? node;
  final String separator, prefix, continuation;
  final bool root;
  @override
  State<DocumentSelectionGroup> createState() => _DocumentSelectionGroupState();
}

class _DocumentSelectionGroupState extends State<DocumentSelectionGroup> {
  late final delegate = DocumentSelectionDelegate(
    separator: widget.separator,
    prefix: widget.prefix,
    continuation: widget.continuation,
  )..addListener(_changed);
  DocumentSelectionBinding? _binding;
  late final registration = SelectionGroupRegistration(
    () => widget.node,
    delegate,
    () => widget.root,
  );
  void _changed() => _binding?.changed();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final binding = DocumentSelectionScope.maybeOf(context);
    if (_binding != binding) {
      _binding?.groups.remove(registration);
      _binding?.changed();
      _binding = binding;
      binding?.groups.add(registration);
      binding?.changed();
    }
  }

  @override
  void didUpdateWidget(DocumentSelectionGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    delegate
      ..separator = widget.separator
      ..prefix = widget.prefix
      ..continuation = widget.continuation;
    _changed();
  }

  @override
  Widget build(BuildContext context) =>
      SelectionContainer.maybeOf(context) == null
      ? widget.child
      : SelectionContainer(delegate: delegate, child: widget.child);
  @override
  void dispose() {
    _binding?.groups.remove(registration);
    _changed();
    delegate.dispose();
    super.dispose();
  }
}
