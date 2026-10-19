import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/ast/nodes.dart';
import '../../core/ast/source_span.dart';
import '../../core/serialize/to_markdown.dart';
import '../../core/text_index/text_index.dart';
import 'selected_document.dart' as selection_slice;
import 'stable_selection_container.dart';

/// A consumer may share one controller among multiple Markdown views inside
/// the same SelectionArea. It owns no gesture handling or SelectionArea.
class MarkstreamSelectionController extends ChangeNotifier {
  final _documents = <DocumentSelectionBinding>{};
  bool _scheduled = false, _disposed = false;
  void attach(DocumentSelectionBinding binding) {
    _documents.add(binding);
    changed();
  }

  void detach(DocumentSelectionBinding binding) {
    _documents.remove(binding);
    changed();
  }

  void changed() {
    if (_scheduled || _disposed) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!_disposed) notifyListeners();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  List<DocumentSelectionBinding> get _orderedDocuments =>
      _documents.toList()..sort((a, b) {
        final first = a.globalPosition, second = b.globalPosition;
        final vertical = first.dy.compareTo(second.dy);
        return vertical != 0 ? vertical : first.dx.compareTo(second.dx);
      });
  bool get hasSelection => _documents.any(
    (binding) => binding.fragments.any((fragment) => fragment.hasSelection),
  );
  String get selectedPlainText => _orderedDocuments
      .map((binding) => binding.plainText)
      .whereType<String>()
      .join('\n\n');
  List<MarkstreamSelection> get selections => [
    for (final binding in _orderedDocuments)
      if (binding.selection case final selection?) selection,
  ];
  List<DocumentNode> get selectedDocuments =>
      selections.map((selection) => selection.content).toList();
  String get selectedMarkdown =>
      selections.map((selection) => selection.markdown).join('\n\n');
  Future<void> copySelectionAsMarkdown() async {
    final value = selectedMarkdown;
    if (value.isNotEmpty) await Clipboard.setData(ClipboardData(text: value));
  }

  @override
  void dispose() {
    _disposed = true;
    _documents.clear();
    super.dispose();
  }
}

/// One selected document, retaining the provenance of its local source offsets.
class MarkstreamSelection {
  MarkstreamSelection({
    required this.document,
    required this.content,
    required List<TextSegment> segments,
  }) : segments = List.unmodifiable(segments);
  final DocumentNode document;
  final DocumentNode content;
  final List<TextSegment> segments;
  List<SourceSpan> get sourceRanges => [
    for (final segment in segments)
      if (!segment.sourceSpan.isEmpty) segment.sourceSpan,
  ];
  String get markdown => toMarkdown(content);
}

/// Supplies an app-owned controller to descendant views without changing a
/// compatibility wrapper's public constructor.
class MarkstreamSelectionScope extends InheritedWidget {
  const MarkstreamSelectionScope({
    super.key,
    required this.controller,
    required super.child,
  });
  final MarkstreamSelectionController controller;
  static MarkstreamSelectionController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<MarkstreamSelectionScope>()
      ?.controller;
  @override
  bool updateShouldNotify(MarkstreamSelectionScope oldWidget) =>
      oldWidget.controller != controller;
}

class SelectionGroupRegistration {
  SelectionGroupRegistration(this.node, this.delegate, this.root);
  final MarkdownNode? Function() node;
  final StableSelectionDelegate delegate;
  final bool Function() root;
  bool get complete {
    final range = delegate.getSelection();
    return range != null &&
        delegate.contentLength > 0 &&
        math.min(range.startOffset, range.endOffset) == 0 &&
        math.max(range.startOffset, range.endOffset) == delegate.contentLength;
  }
}

class DocumentSelectionBinding {
  DocumentSelectionBinding(this.document, this.controller, this.renderBox);
  final RenderBox? Function() renderBox;
  Offset get globalPosition {
    final box = renderBox();
    return box != null && box.hasSize
        ? box.localToGlobal(Offset.zero)
        : Offset.zero;
  }

  DocumentNode document;
  MarkstreamSelectionController controller;
  final fragments = <_MarkstreamSelectionFragmentState>{};
  final groups = <SelectionGroupRegistration>{};
  void changed() => controller.changed();
  List<_MarkstreamSelectionFragmentState> get _ordered => fragments.toList()
    ..sort(
      (a, b) => a.widget.node.span.start.compareTo(b.widget.node.span.start),
    );
  TextIndex get textIndex => TextIndex.fromSegments(
    _ordered.expand((fragment) => fragment.widget.segments),
  );
  List<TextSegment> get selectedSegments => [
    for (final fragment in _ordered) ...fragment.selectedSegments,
  ];
  String? get plainText => groups
      .where((group) => group.root())
      .firstOrNull
      ?.delegate
      .getSelectedContent()
      ?.plainText;
  MarkstreamSelection? get selection {
    final segments = selectedSegments;
    if (segments.isEmpty) return null;
    return MarkstreamSelection(
      document: document,
      segments: segments,
      content: selection_slice.selectedDocument(
        document,
        segments,
        visible: {
          for (final fragment in fragments) fragment.widget.node,
          for (final fragment in fragments)
            for (final segment in fragment.widget.segments)
              if (segment.node != null) segment.node!,
          for (final group in groups)
            if (group.node() != null) group.node()!,
        },
        complete: {
          for (final group in groups)
            if (group.node() != null && group.complete) group.node()!,
        },
      ),
    );
  }
}

class DocumentSelectionScope extends InheritedWidget {
  const DocumentSelectionScope({
    super.key,
    required this.binding,
    required super.child,
  });
  final DocumentSelectionBinding? binding;
  static DocumentSelectionBinding? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<DocumentSelectionScope>()
      ?.binding;
  @override
  bool updateShouldNotify(DocumentSelectionScope oldWidget) =>
      oldWidget.binding != binding;
}

/// Explicit projection for extension widgets. Each fragment must describe
/// exactly the selectable UTF-16 text underneath it, excluding nested fragments.
class MarkstreamSelectionFragment extends StatefulWidget {
  const MarkstreamSelectionFragment({
    super.key,
    required this.node,
    required this.segments,
    required this.child,
  });
  final MarkdownNode node;
  final List<TextSegment> segments;
  final Widget child;
  @override
  State<MarkstreamSelectionFragment> createState() =>
      _MarkstreamSelectionFragmentState();
}

class _MarkstreamSelectionFragmentState
    extends State<MarkstreamSelectionFragment> {
  final _delegate = StableSelectionDelegate();
  bool _registered = false;
  DocumentSelectionBinding? _binding;
  late TextIndex _index;
  @override
  void initState() {
    super.initState();
    _index = TextIndex.fromSegments(widget.segments);
    _delegate.addListener(_changed);
  }

  void _changed() => _binding?.changed();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final binding = DocumentSelectionScope.maybeOf(context);
    if (_binding != binding) {
      _binding?.fragments.remove(this);
      _changed();
      _binding = binding;
      binding?.fragments.add(this);
      _changed();
    }
  }

  @override
  void didUpdateWidget(MarkstreamSelectionFragment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.segments != widget.segments)
      _index = TextIndex.fromSegments(widget.segments);
    _changed();
  }

  TextRange? get _selectedRange {
    if (!_registered) return null;
    final range = _delegate.getSelection();
    if (range == null) return null;
    // Native edge indices can briefly refer to the previous tail during a
    // streaming merge. The settled frame supplies the current exact range.
    final start = math
        .min(range.startOffset, range.endOffset)
        .clamp(0, _index.length);
    final end = math
        .max(range.startOffset, range.endOffset)
        .clamp(start, _index.length);
    return TextRange(start: start, end: end);
  }

  bool get hasSelection => _selectedRange?.isCollapsed == false;

  List<TextSegment> get selectedSegments {
    final range = _selectedRange;
    return range == null
        ? const []
        : _index.segmentsForRange(range.start, range.end);
  }

  @override
  Widget build(BuildContext context) {
    _registered =
        _binding != null && SelectionContainer.maybeOf(context) != null;
    // This delegate already owns the exact range and emits selection changes.
    // A second SelectionListener container would rebuild all selected line
    // geometry and walk the same ranges again on every handle movement.
    return _registered
        ? SelectionContainer(delegate: _delegate, child: widget.child)
        : widget.child;
  }

  @override
  void dispose() {
    _binding?.fragments.remove(this);
    _changed();
    _delegate.dispose();
    super.dispose();
  }
}
