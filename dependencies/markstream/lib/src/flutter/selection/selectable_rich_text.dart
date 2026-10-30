import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'selection_edge_initialization.dart';
import 'selection_rect_collection.dart';

/// Preserves inline widget identity while the paragraph's selectable fragments
/// change. Plain text keeps Flutter's ordinary Text rendering path.
Widget buildSelectableText(Text text) {
  var embedded = false;
  text.textSpan?.visitChildren((span) {
    if (span is WidgetSpan) embedded = true;
    return !embedded;
  });
  return embedded ? _SelectableRichText(text) : text;
}

class _SelectableRichText extends Text {
  _SelectableRichText(Text text)
    : super.rich(
        text.textSpan!,
        key: text.key,
        style: text.style,
        strutStyle: text.strutStyle,
        textAlign: text.textAlign,
        textDirection: text.textDirection,
        locale: text.locale,
        softWrap: text.softWrap,
        overflow: text.overflow,
        textScaler: text.textScaler,
        maxLines: text.maxLines,
        semanticsLabel: text.semanticsLabel,
        semanticsIdentifier: text.semanticsIdentifier,
        textWidthBasis: text.textWidthBasis,
        textHeightBehavior: text.textHeightBehavior,
        selectionColor: text.selectionColor,
      );

  @override
  Widget build(BuildContext context) => _SelectableParagraph(text: this);
}

class _SelectableParagraph extends StatefulWidget {
  const _SelectableParagraph({required this.text});
  final Text text;

  @override
  State<_SelectableParagraph> createState() => _SelectableParagraphState();
}

class _SelectableParagraphState extends State<_SelectableParagraph> {
  final _paragraphKey = GlobalKey();
  late final _ParagraphSelectionDelegate _delegate;

  @override
  void initState() {
    super.initState();
    _delegate = _ParagraphSelectionDelegate(
      () =>
          _paragraphKey.currentContext!.findRenderObject()! as RenderParagraph,
    );
  }

  @override
  void dispose() {
    _delegate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    final selectable = SelectionContainer.maybeOf(context) != null;
    final defaults = DefaultTextStyle.of(context);
    var style = text.style == null || text.style!.inherit
        ? defaults.style.merge(text.style)
        : text.style!;
    if (MediaQuery.boldTextOf(context)) {
      style = style.merge(const TextStyle(fontWeight: FontWeight.bold));
    }
    final height = MediaQuery.maybeLineHeightScaleFactorOverrideOf(context);
    final letterSpacing = MediaQuery.maybeLetterSpacingOverrideOf(context);
    final wordSpacing = MediaQuery.maybeWordSpacingOverrideOf(context);
    var span = TextSpan(
      style: style,
      text: text.data,
      locale: text.locale,
      children: text.textSpan == null ? null : [text.textSpan!],
    );
    if (height != null || letterSpacing != null || wordSpacing != null) {
      span = _withSpacing(
        span,
        TextStyle(
          height: height,
          letterSpacing: letterSpacing,
          wordSpacing: wordSpacing,
        ),
      );
    }
    Widget result = Builder(
      builder: (context) {
        final paragraph = RichText(
          key: _paragraphKey,
          text: span,
          textAlign: text.textAlign ?? defaults.textAlign ?? TextAlign.start,
          textDirection: text.textDirection,
          softWrap: text.softWrap ?? defaults.softWrap,
          overflow: text.overflow ?? style.overflow ?? defaults.overflow,
          textScaler: text.textScaler ?? MediaQuery.textScalerOf(context),
          maxLines: text.maxLines ?? defaults.maxLines,
          locale: text.locale,
          strutStyle: text.strutStyle?.merge(StrutStyle(height: height)),
          textWidthBasis: text.textWidthBasis ?? defaults.textWidthBasis,
          textHeightBehavior:
              text.textHeightBehavior ??
              defaults.textHeightBehavior ??
              DefaultTextHeightBehavior.maybeOf(context),
          selectionColor:
              text.selectionColor ??
              DefaultSelectionStyle.of(context).selectionColor ??
              DefaultSelectionStyle.defaultColor,
          selectionRegistrar: SelectionContainer.maybeOf(context),
        );
        return selectable
            ? MouseRegion(
                cursor:
                    DefaultSelectionStyle.of(context).mouseCursor ??
                    SystemMouseCursors.text,
                child: paragraph,
              )
            : paragraph;
      },
    );
    if (selectable) {
      result = SelectionContainer(delegate: _delegate, child: result);
    }
    if (text.semanticsLabel != null || text.semanticsIdentifier != null) {
      result = Semantics(
        textDirection: text.textDirection,
        label: text.semanticsLabel,
        identifier: text.semanticsIdentifier,
        child: ExcludeSemantics(
          excluding: text.semanticsLabel != null,
          child: result,
        ),
      );
    }
    return Directionality(
      textDirection: text.textDirection ?? Directionality.of(context),
      child: result,
    );
  }
}

TextSpan _withSpacing(TextSpan span, TextStyle spacing) => TextSpan(
  text: span.text,
  style: span.style?.merge(spacing) ?? spacing,
  children: span.children
      ?.map(
        (child) => child.runtimeType == TextSpan
            ? _withSpacing(child as TextSpan, spacing)
            : child,
      )
      .toList(),
  recognizer: span.recognizer,
  mouseCursor: span.mouseCursor,
  onEnter: span.onEnter,
  onExit: span.onExit,
  semanticsLabel: span.semanticsLabel,
  semanticsIdentifier: span.semanticsIdentifier,
  locale: span.locale,
  spellOut: span.spellOut,
);

class _ParagraphSelectionDelegate
    extends MultiSelectableSelectionContainerDelegate
    with SelectionEdgeInitialization, SelectionRectCollection {
  _ParagraphSelectionDelegate(this._paragraph) {
    addListener(WidgetsBinding.instance.ensureVisualUpdate);
  }
  final RenderParagraph Function() _paragraph;

  SelectionEdgeUpdateEvent? _startEvent;
  SelectionEdgeUpdateEvent? _endEvent;

  // Route outside-fragment edges by logical offsets. Flutter's rectangle
  // clamping treats the left side as preceding even inside RTL paragraphs.
  SelectionResult _send(Selectable child, SelectionEvent event) {
    if (event is! SelectionEdgeUpdateEvent) {
      return child.dispatchSelectionEvent(event);
    }
    final paragraph = _paragraph();
    final localPosition = paragraph.globalToLocal(event.globalPosition);
    final offset = localPosition.dy < 0
        ? 0
        : localPosition.dy >= paragraph.size.height
        ? paragraph.text.toPlainText(includeSemanticsLabels: false).length
        : paragraph.getPositionForOffset(localPosition).offset;
    if (!paragraph.selectableBelongsToParagraph(child)) {
      return child.dispatchSelectionEvent(event);
    }
    final start = _fragmentStart(child);
    final end = start + child.contentLength;
    if (offset <= start || offset >= end) {
      final forward = offset >= end;
      final text = paragraph.text.toPlainText(includeSemanticsLabels: false);
      final boundary = CharacterBoundary(
        text,
      ).getTextBoundaryAt(forward ? end - 1 : start);
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: boundary.start, extentOffset: boundary.end),
      );
      final box = forward ? boxes.last : boxes.first;
      final right = forward == (box.direction == TextDirection.ltr);
      final bounds = child.boundingBoxes.reduce((a, b) => a.expandToInclude(b));
      final x = bounds.width < 0.002
          ? bounds.left + (forward ? 1 : -1)
          : box.left == box.right
          ? box.left.clamp(bounds.left + 0.001, bounds.right - 0.001)
          : right
          ? box.right - 0.001
          : box.left + 0.001;
      final point = paragraph.localToGlobal(
        Offset(x, (box.top + box.bottom) / 2),
      );
      child.dispatchSelectionEvent(
        event.type == SelectionEventType.endEdgeUpdate
            ? SelectionEdgeUpdateEvent.forEnd(globalPosition: point)
            : SelectionEdgeUpdateEvent.forStart(globalPosition: point),
      );
      if (forward && box.left == box.right && bounds.width >= 0.002) {
        // A trailing line break has no drawable width. Advancing to the
        // next line reaches the fragment boundary including that break.
        final initializeOther = child.getSelection() == null;
        if (initializeOther) {
          child.dispatchSelectionEvent(
            event.type == SelectionEventType.endEdgeUpdate
                ? SelectionEdgeUpdateEvent.forStart(globalPosition: point)
                : SelectionEdgeUpdateEvent.forEnd(globalPosition: point),
          );
        }
        child.dispatchSelectionEvent(
          DirectionallyExtendSelectionEvent(
            dx: point.dx,
            isEnd: event.type == SelectionEventType.endEdgeUpdate,
            direction: SelectionExtendDirection.nextLine,
          ),
        );
        if (initializeOther) {
          child.dispatchSelectionEvent(
            DirectionallyExtendSelectionEvent(
              dx: point.dx,
              isEnd: event.type != SelectionEventType.endEdgeUpdate,
              direction: SelectionExtendDirection.nextLine,
            ),
          );
        }
      }
      return forward ? SelectionResult.next : SelectionResult.previous;
    }
    return child.dispatchSelectionEvent(event);
  }

  @override
  void ensureChildUpdated(Selectable child) {
    // This runs during the framework's additions merge. Dispatch directly to
    // the child; never re-enter the delegate with partially rebased indices.
    if (_startEvent case final start?) _send(child, start);
    if (_endEvent case final end?) _send(child, end);
  }

  @override
  SelectionResult dispatchSelectionEventToChild(
    Selectable child,
    SelectionEvent event,
  ) {
    if (event is SelectionEdgeUpdateEvent) ensureChildUpdated(child);
    return _send(child, event);
  }

  @override
  void didChangeSelectables() {
    if (_endEvent case final end?) handleSelectionEdgeUpdate(end);
    if (_startEvent case final start?) handleSelectionEdgeUpdate(start);
    super.didChangeSelectables();
  }

  void _rememberBoundary() {
    Offset? point(int index, bool end) {
      if (index < 0 || index >= selectables.length) return null;
      final child = selectables[index];
      final point = end
          ? child.value.endSelectionPoint
          : child.value.startSelectionPoint;
      return point == null
          ? null
          : MatrixUtils.transformPoint(
              child.getTransformTo(null),
              point.localPosition - Offset(0, point.lineHeight / 2),
            );
    }

    final start = point(currentSelectionStartIndex, false);
    final end = point(currentSelectionEndIndex, true);
    _startEvent = start == null
        ? null
        : SelectionEdgeUpdateEvent.forStart(globalPosition: start);
    _endEvent = end == null
        ? null
        : SelectionEdgeUpdateEvent.forEnd(globalPosition: end);
  }

  @override
  SelectionResult handleSelectAll(SelectAllSelectionEvent event) {
    final result = super.handleSelectAll(event);
    _rememberBoundary();
    return result;
  }

  @override
  SelectionResult handleSelectWord(SelectWordSelectionEvent event) {
    final result = super.handleSelectWord(event);
    _rememberBoundary();
    return result;
  }

  @override
  SelectionResult handleClearSelection(ClearSelectionEvent event) {
    _startEvent = _endEvent = null;
    _startParagraph = _endParagraph = null;
    return super.handleClearSelection(event);
  }

  @override
  Comparator<Selectable> get compareOrder {
    final paragraph = _paragraph();
    // A sort compares the same fragments repeatedly. Keep logical offsets
    // within this comparator only, so later layouts always use fresh geometry.
    final offsets = Map<Selectable, int>.identity();
    int offset(Selectable child) => offsets.putIfAbsent(
      child,
      () => paragraph.selectableBelongsToParagraph(child)
          ? _fragmentStart(child)
          : _placeholderOffset(child),
    );
    return (a, b) => offset(a).compareTo(offset(b));
  }

  int _fragmentStart(Selectable selectable) {
    final paragraph = _paragraph();
    final boxes = selectable.boundingBoxes;
    var start = paragraph.getPositionForOffset(boxes.first.centerLeft).offset;
    // Zero is already the minimum possible offset. Long leading fragments
    // otherwise hit-test every line even when only their color has changed.
    if (start == 0) return start;
    for (final box in boxes) {
      start = math.min(
        start,
        paragraph.getPositionForOffset(box.centerLeft).offset,
      );
      start = math.min(
        start,
        paragraph.getPositionForOffset(box.centerRight).offset,
      );
      if (start == 0) break;
    }
    return start;
  }

  int _placeholderOffset(Selectable selectable) {
    final paragraph = _paragraph();
    final transform = selectable.getTransformTo(paragraph);
    final box = MatrixUtils.transformRect(
      transform,
      selectable.boundingBoxes.first,
    );
    return math.min(
      paragraph.getPositionForOffset(box.centerLeft).offset,
      paragraph.getPositionForOffset(box.centerRight).offset,
    );
  }

  @override
  SelectedContentRange? getSelection() {
    if (currentSelectionStartIndex < 0 || currentSelectionEndIndex < 0) {
      return null;
    }
    final paragraph = _paragraph();
    var offset = 0;
    int? first, last, collapsed;
    final ordered = selectables;
    final firstChild = selectables[currentSelectionStartIndex];
    final lastChild = selectables[currentSelectionEndIndex];
    var forward = ordered.indexOf(firstChild) <= ordered.indexOf(lastChild);
    for (final child in ordered) {
      final range = child.getSelection();
      if (paragraph.selectableBelongsToParagraph(child) &&
          range != null &&
          range.startOffset != range.endOffset) {
        forward = range.startOffset < range.endOffset;
        break;
      }
    }
    for (var i = 0; i < ordered.length; i++) {
      final selectable = ordered[i];
      final range = selectable.getSelection();
      if (range != null) {
        final base = paragraph.selectableBelongsToParagraph(selectable)
            ? _fragmentStart(selectable)
            : 0;
        final a =
            offset +
            (range.startOffset - base).clamp(0, selectable.contentLength);
        final b =
            offset +
            (range.endOffset - base).clamp(0, selectable.contentLength);
        if (currentSelectionStartIndex == currentSelectionEndIndex &&
            identical(selectable, firstChild)) {
          forward = a <= b;
        }
        if (a == b) {
          collapsed ??= a;
        } else {
          first = first == null
              ? math.min(a, b)
              : math.min(first, math.min(a, b));
          last = last == null ? math.max(a, b) : math.max(last, math.max(a, b));
        }
      }
      offset += selectable.contentLength;
    }
    if (first == null) {
      return collapsed == null
          ? null
          : SelectedContentRange(startOffset: collapsed, endOffset: collapsed);
    }
    return SelectedContentRange(
      startOffset: forward ? first : last!,
      endOffset: forward ? last! : first,
    );
  }

  TextRange? _startParagraph;
  TextRange? _endParagraph;

  TextRange _paragraphAt(Offset globalPosition) {
    final paragraph = _paragraph();
    final text = paragraph.text.toPlainText(includeSemanticsLabels: false);
    if (text.isEmpty) return TextRange.empty;
    final position = paragraph.getPositionForOffset(
      paragraph.globalToLocal(globalPosition),
    );
    return ParagraphBoundary(
      text,
    ).getTextBoundaryAt(position.offset.clamp(0, text.length - 1));
  }

  Offset _caretPosition(int offset) {
    final paragraph = _paragraph();
    final position = TextPosition(offset: offset);
    return paragraph.localToGlobal(
      paragraph.getOffsetForCaret(position, Rect.zero) + const Offset(0, 1),
    );
  }

  @override
  SelectionResult handleSelectionEdgeUpdate(SelectionEdgeUpdateEvent event) {
    if (event.granularity != TextGranularity.paragraph ||
        _startParagraph == null ||
        _endParagraph == null) {
      if (event.type == SelectionEventType.endEdgeUpdate) {
        _endEvent = event;
      } else {
        _startEvent = event;
      }
      return super.handleSelectionEdgeUpdate(event);
    }
    final boundary = _paragraphAt(event.globalPosition);
    if (!boundary.isValid) return SelectionResult.none;
    if (event.type == SelectionEventType.endEdgeUpdate) {
      _endParagraph = boundary;
    } else {
      _startParagraph = boundary;
    }
    final forward = _startParagraph!.start <= _endParagraph!.start;
    final start = forward ? _startParagraph!.start : _startParagraph!.end;
    final end = forward ? _endParagraph!.end : _endParagraph!.start;
    _startEvent = SelectionEdgeUpdateEvent.forStart(
      globalPosition: _caretPosition(start),
    );
    _endEvent = SelectionEdgeUpdateEvent.forEnd(
      globalPosition: _caretPosition(end),
    );
    super.handleSelectionEdgeUpdate(_startEvent!);
    super.handleSelectionEdgeUpdate(_endEvent!);
    return SelectionUtils.getResultBasedOnRect(
      Offset.zero & _paragraph().size,
      _paragraph().globalToLocal(event.globalPosition),
    );
  }

  @override
  SelectionResult handleSelectParagraph(SelectParagraphSelectionEvent event) {
    _startParagraph = _endParagraph = _paragraphAt(event.globalPosition);
    if (event.absorb) {
      handleSelectAll(const SelectAllSelectionEvent());
      return SelectionResult.next;
    }
    final paragraph = _paragraph();
    for (final selectable in selectables) {
      if (paragraph.selectableBelongsToParagraph(selectable)) continue;
      for (final box in selectable.boundingBoxes) {
        if (MatrixUtils.transformRect(
          selectable.getTransformTo(null),
          box,
        ).contains(event.globalPosition)) {
          return super.handleSelectParagraph(event);
        }
      }
    }
    final text = paragraph.text.toPlainText(includeSemanticsLabels: false);
    final position = paragraph.getPositionForOffset(
      paragraph.globalToLocal(event.globalPosition),
    );
    final boundary = ParagraphBoundary(
      text,
    ).getTextBoundaryAt(position.offset.clamp(0, math.max(0, text.length - 1)));
    currentSelectionStartIndex = currentSelectionEndIndex = -1;
    for (var i = 0; i < selectables.length; i++) {
      final child = selectables[i];
      dispatchSelectionEventToChild(child, const ClearSelectionEvent());
      if (paragraph.selectableBelongsToParagraph(child)) {
        dispatchSelectionEventToChild(child, event);
      } else {
        final offset = _placeholderOffset(child);
        if (boundary.start <= offset && offset < boundary.end) {
          dispatchSelectionEventToChild(
            child,
            SelectParagraphSelectionEvent(
              globalPosition: event.globalPosition,
              absorb: true,
            ),
          );
        }
      }
      final range = child.getSelection();
      if (range != null && range.startOffset != range.endOffset) {
        if (currentSelectionStartIndex < 0) currentSelectionStartIndex = i;
        currentSelectionEndIndex = i;
      }
    }
    _rememberBoundary();
    return SelectionResult.end;
  }
}
