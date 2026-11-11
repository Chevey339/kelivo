import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import '../../core/ast/nodes.dart';
import 'selection_controller.dart';
import 'stable_selection_container.dart';

/// Clipboard projection for an app-rendered block. Native selection offsets
/// remain offsets into the actual descendant glyphs; generated semantic text
/// is never installed as a fictitious selectable range.
class MarkstreamSelectionProjection extends StatefulWidget {
  const MarkstreamSelectionProjection({
    super.key,
    required this.node,
    required this.project,
    this.clipboardByteLimit,
    required this.child,
  });
  final MarkdownNode node;
  final int? clipboardByteLimit;
  final String Function(String selectedText, bool complete) project;
  final Widget child;
  @override
  State<MarkstreamSelectionProjection> createState() =>
      _MarkstreamSelectionProjectionState();
}

class _MarkstreamSelectionProjectionState
    extends State<MarkstreamSelectionProjection> {
  late final _delegate = _ProjectionDelegate(
    (text, complete) => widget.project(text, complete),
  )..addListener(_changed);
  // Nested Markdown retains native selection, but cannot also publish a second
  // copy of this block to the ancestor clipboard controller.
  final _nested = MarkstreamSelectionController();
  bool _registered = false;
  late final _registration = SelectionProjectionRegistration(
    () => widget.node,
    _delegate,
    () => _registered,
    () => widget.clipboardByteLimit,
  );
  DocumentSelectionBinding? _binding;
  void _changed() => _binding?.changed();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final binding = DocumentSelectionScope.maybeOf(context);
    if (_binding == binding) return;
    _binding?.projections.remove(_registration);
    _changed();
    _binding = binding;
    binding?.projections.add(_registration);
    _changed();
  }

  @override
  void didUpdateWidget(MarkstreamSelectionProjection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _changed();
  }

  @override
  Widget build(BuildContext context) {
    _registered =
        _binding != null && SelectionContainer.maybeOf(context) != null;
    final child = MarkstreamSelectionScope(
      controller: _nested,
      child: DocumentSelectionScope(binding: null, child: widget.child),
    );
    return !_registered
        ? child
        : SelectionContainer(delegate: _delegate, child: child);
  }

  @override
  void dispose() {
    _binding?.projections.remove(_registration);
    _changed();
    _delegate.dispose();
    _nested.dispose();
    super.dispose();
  }
}

class _ProjectionDelegate extends StableSelectionDelegate {
  _ProjectionDelegate(this.project);
  final String Function(String, bool) project;
  @override
  SelectedContent? getSelectedContent() {
    final content = super.getSelectedContent();
    if (content == null) return null;
    final range = getSelection();
    final complete =
        range != null &&
        contentLength > 0 &&
        math.min(range.startOffset, range.endOffset) == 0 &&
        math.max(range.startOffset, range.endOffset) == contentLength;
    return SelectedContent(plainText: project(content.plainText, complete));
  }
}
