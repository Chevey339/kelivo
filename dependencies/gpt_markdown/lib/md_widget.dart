part of 'gpt_markdown.dart';

/// It creates a markdown widget closed to each other.
class MdWidget extends StatefulWidget {
  const MdWidget(
    this.context,
    this.exp,
    this.includeGlobalComponents, {
    super.key,
    required this.config,
  });

  /// The expression to be displayed.
  final String exp;
  final BuildContext context;

  /// Whether to include global components.
  final bool includeGlobalComponents;

  /// The configuration of the markdown widget.
  final GptMarkdownConfig config;

  @override
  State<MdWidget> createState() => _MdWidgetState();
}

class _MdWidgetState extends State<MdWidget> {
  List<InlineSpan> list = [];
  static final _markdownDelimiter = RegExp(
    r'[\r\n\t\u2028\u2029`*_~\[\](){}<>|\\$]',
  );
  bool _plainAppendable = false;
  // Emphasis in a single prose paragraph can only reopen at an unmatched '*'.
  // Other syntax keeps the full parser, including arbitrary custom blocks.
  static final _nonProseSyntax = RegExp(
    r'[\r\n\t\u2028\u2029`_~\[\](){}<>|\\$#\-\uE000-\uF8FF]',
  );
  bool _prose = false;
  bool _proseTailClosed = false;
  int _stableOffset = 0;
  int _stableSpanCount = 0;
  List<InlineSpan> _previousSpans = const [];
  final _spanGroups = <TextSpan>[];
  @override
  void initState() {
    super.initState();
    _parse(widget.context);
  }

  @override
  void didUpdateWidget(covariant MdWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exp != widget.exp ||
        !oldWidget.config.isSame(widget.config)) {
      if (widget.config.streaming &&
          _plainAppendable &&
          !oldWidget.exp.endsWith('\\') &&
          oldWidget.config.isSame(widget.config) &&
          widget.exp.startsWith(oldWidget.exp) &&
          _sourceUnrewritten) {
        final suffix = widget.exp.substring(oldWidget.exp.length);
        if (!_markdownDelimiter.hasMatch(suffix)) {
          final last = list.isEmpty ? null : list.last;
          if (last is TextSpan &&
              last.children == null &&
              last.style == widget.config.style) {
            list = [
              ...list.take(list.length - 1),
              TextSpan(text: '${last.text ?? ''}$suffix', style: last.style),
            ];
          } else {
            list = [
              ...list,
              TextSpan(text: suffix, style: widget.config.style),
            ];
          }
          if (_prose && !_nonProseSyntax.hasMatch(suffix) && _proseTailClosed) {
            _stableOffset = widget.exp.length;
            _stableSpanCount = list.length;
          } else if (_nonProseSyntax.hasMatch(suffix)) {
            _prose = false;
          }
          return;
        }
        if (_prose && !_nonProseSyntax.hasMatch(suffix)) {
          _parse(context, appendFrom: _stableOffset);
          return;
        }
      }
      _parse(context);
    }
  }

  void _parse(BuildContext parseContext, {int? appendFrom}) {
    final builder = widget.config.spanBuilder;
    if (builder != null) {
      list = builder(parseContext, widget.config);
      _plainAppendable = _prose = _proseTailClosed = false;
      _stableOffset = _stableSpanCount = 0;
      return;
    }
    final source = widget.exp;
    if (appendFrom == null) {
      final first = source.isEmpty ? 0 : source.codeUnitAt(0);
      _prose =
          widget.config.streaming &&
          (first >= 65 && first <= 90 ||
              first >= 97 && first <= 122 ||
              first > 127) &&
          !_nonProseSyntax.hasMatch(source);
      _stableOffset = 0;
      _stableSpanCount = 0;
    }
    final start = appendFrom ?? 0;
    final retained = list.take(_stableSpanCount).toList();
    var count = retained.length;
    var canCommit = _prose;
    final parsed = MarkdownComponent.generate(
      parseContext,
      source.substring(start),
      widget.config,
      appendFrom == null && widget.includeGlobalComponents,
      onSpan:
          !canCommit
              ? null
              : (span, from, to, component, block) {
                count++;
                if (!canCommit) return;
                if (block || span is! TextSpan) {
                  canCommit = false;
                  _prose = false;
                } else if (component is ItalicMd &&
                    to - from > 1 &&
                    source.codeUnitAt(start + from + 1) == 0x2a) {
                  // The default italic regexp can provisionally consume '**x*'
                  // (or '***'). A later '*' upgrades that same opener to bold.
                  canCommit = false;
                } else if (component == null) {
                  if ((span.text ?? '').contains('*')) {
                    canCommit = false;
                  } else {
                    // Commit only through following plain text. A closing '**' at the
                    // end can still be invalidated by another '*' in the next chunk.
                    _stableOffset = start + to;
                    _stableSpanCount = count;
                  }
                }
              },
    );
    if (count == retained.length) _prose = false;
    _proseTailClosed = _prose && canCommit;
    list = [...retained, ...parsed];
    if (_prose) {
      // This path already established that the paragraph has no line breaks,
      // and retained spans were checked before entering the append parser.
      _plainAppendable = parsed.every(_plainSpan);
    } else {
      _updatePlainAppendable();
    }
  }

  static bool _plainSpan(InlineSpan span) =>
      span is TextSpan &&
      span.recognizer == null &&
      span.semanticsLabel == null &&
      (span.children?.every(_plainSpan) ?? true);

  void _updatePlainAppendable() {
    _plainAppendable = false;
    if (!list.every(_plainSpan) || widget.exp.contains('<')) return;
    // One backwards walk to the last logical line. Four lastIndexOf calls
    // repeatedly scanned every CJK code unit for absent CR/LS/PS on Android.
    var start = widget.exp.length;
    while (start > 0) {
      final unit = widget.exp.codeUnitAt(start - 1);
      if (unit == 0x0a || unit == 0x0d || unit == 0x2028 || unit == 0x2029) {
        break;
      }
      start--;
    }
    final first = start < widget.exp.length ? widget.exp.codeUnitAt(start) : 0;
    // A line beginning with a marker, indentation or a number can become a
    // heading/list/rule when a space or punctuation arrives. Such lines, and
    // paragraphs with embedded widgets, continue through the complete parser.
    _plainAppendable =
        (first >= 65 && first <= 90 ||
            first >= 97 && first <= 122 ||
            first > 127) &&
        _sourceUnrewritten;
  }

  bool get _sourceUnrewritten =>
      !widget.includeGlobalComponents ||
      widget.config.preprocessBlocks == null ||
      widget.config.preprocessBlocks!(widget.exp) == widget.exp;

  @override
  Widget build(BuildContext context) {
    // List<InlineSpan> list = MarkdownComponent.generate(
    //   context,
    //   widget.exp,
    //   widget.config,
    //   widget.includeGlobalComponents,
    // );
    final text = widget.config.getRich(
      TextSpan(
        children: _groupedSpans(),
        style: widget.config.style?.copyWith(),
      ),
    );
    return widget.config.textBuilder?.call(text) ?? text;
  }

  List<InlineSpan> _groupedSpans() {
    // Reuse whole completed span groups, so the line renderer can reuse their
    // flattened runs without revisiting every styled token on each append.
    const width = 128;
    if (list.length <= width) {
      _previousSpans = const [];
      _spanGroups.clear();
      return list;
    }
    var unchanged = min(list.length, _previousSpans.length);
    while (unchanged > 0 &&
        !identical(list[unchanged - 1], _previousSpans[unchanged - 1])) {
      unchanged--;
    }
    final keep = min(unchanged ~/ width, _spanGroups.length);
    _spanGroups.removeRange(keep, _spanGroups.length);
    for (var start = keep * width; start < list.length; start += width) {
      _spanGroups.add(
        TextSpan(
          children: list.sublist(start, min(start + width, list.length)),
        ),
      );
    }
    _previousSpans = list;
    return List<InlineSpan>.of(_spanGroups);
  }
}

/// A custom table column width.
class CustomTableColumnWidth extends TableColumnWidth {
  @override
  double maxIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    double width = 50;
    for (var each in cells) {
      each.layout(const BoxConstraints(), parentUsesSize: true);
      width = max(width, each.size.width);
    }
    return min(containerWidth, width);
  }

  @override
  double minIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    return 50;
  }
}
