import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../ast/nodes/matrix.dart';
import '../constants.dart';
import '../utils/render_box_layout.dart';
import '../utils/render_box_offset.dart';
import 'line.dart';

class EqnArrayParentData extends ContainerBoxParentData<RenderBox> {
  int rowIndex = 0;
  bool isTag = false;
}

class _EqnArrayElement extends ParentDataWidget<EqnArrayParentData> {
  const _EqnArrayElement({
    required this.rowIndex,
    required this.isTag,
    required Widget child,
  }) : super(child: child);

  final int rowIndex;
  final bool isTag;

  @override
  void applyParentData(RenderObject renderObject) {
    assert(renderObject.parentData is EqnArrayParentData);
    final parentData = renderObject.parentData! as EqnArrayParentData;
    if (parentData.rowIndex == rowIndex && parentData.isTag == isTag) return;
    parentData
      ..rowIndex = rowIndex
      ..isTag = isTag;
    final targetParent = renderObject.parent;
    if (targetParent is RenderObject) targetParent.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => EqnArray;
}

class EqnArray extends MultiChildRenderObjectWidget {
  final double ruleThickness;
  final double jotSize;
  final double arrayskip;
  final double tagGap;
  final bool expandToMaxWidth;
  final List<MatrixSeparatorStyle> hlines;
  final List<double> rowSpacings;

  EqnArray({
    Key? key,
    required this.ruleThickness,
    required this.jotSize,
    required this.arrayskip,
    required this.tagGap,
    required this.expandToMaxWidth,
    required this.hlines,
    required this.rowSpacings,
    required List<Widget> rows,
    required List<Widget?> tags,
  })  : assert(rows.length == tags.length),
        super(
          key: key,
          children: [
            for (var index = 0; index < rows.length; index++) ...[
              _EqnArrayElement(
                rowIndex: index,
                isTag: false,
                child: rows[index],
              ),
              if (tags[index] != null)
                _EqnArrayElement(
                  rowIndex: index,
                  isTag: true,
                  child: tags[index]!,
                ),
            ],
          ],
        );

  @override
  RenderObject createRenderObject(BuildContext context) => RenderEqnArray(
        ruleThickness: ruleThickness,
        jotSize: jotSize,
        arrayskip: arrayskip,
        tagGap: tagGap,
        expandToMaxWidth: expandToMaxWidth,
        hlines: hlines,
        rowSpacings: rowSpacings,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderEqnArray renderObject,
  ) {
    renderObject
      ..ruleThickness = ruleThickness
      ..jotSize = jotSize
      ..arrayskip = arrayskip
      ..tagGap = tagGap
      ..expandToMaxWidth = expandToMaxWidth
      ..hlines = hlines
      ..rowSpacings = rowSpacings;
  }
}

class RenderEqnArray extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, EqnArrayParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, EqnArrayParentData>,
        DebugOverflowIndicatorMixin {
  RenderEqnArray({
    List<RenderBox>? children,
    required double ruleThickness,
    required double jotSize,
    required double arrayskip,
    required double tagGap,
    required bool expandToMaxWidth,
    required List<MatrixSeparatorStyle> hlines,
    required List<double> rowSpacings,
  })  : _ruleThickness = ruleThickness,
        _jotSize = jotSize,
        _arrayskip = arrayskip,
        _tagGap = tagGap,
        _expandToMaxWidth = expandToMaxWidth,
        _hlines = hlines,
        _rowSpacings = rowSpacings {
    addAll(children);
  }

  double get ruleThickness => _ruleThickness;
  double _ruleThickness;
  set ruleThickness(double value) {
    if (_ruleThickness != value) {
      _ruleThickness = value;
      markNeedsLayout();
    }
  }

  double get jotSize => _jotSize;
  double _jotSize;
  set jotSize(double value) {
    if (_jotSize != value) {
      _jotSize = value;
      markNeedsLayout();
    }
  }

  double get arrayskip => _arrayskip;
  double _arrayskip;
  set arrayskip(double value) {
    if (_arrayskip != value) {
      _arrayskip = value;
      markNeedsLayout();
    }
  }

  double get tagGap => _tagGap;
  double _tagGap;
  set tagGap(double value) {
    if (_tagGap != value) {
      _tagGap = value;
      markNeedsLayout();
    }
  }

  bool get expandToMaxWidth => _expandToMaxWidth;
  bool _expandToMaxWidth;
  set expandToMaxWidth(bool value) {
    if (_expandToMaxWidth != value) {
      _expandToMaxWidth = value;
      markNeedsLayout();
    }
  }

  List<MatrixSeparatorStyle> get hlines => _hlines;
  List<MatrixSeparatorStyle> _hlines;
  set hlines(List<MatrixSeparatorStyle> value) {
    if (!const ListEquality<MatrixSeparatorStyle>().equals(_hlines, value)) {
      _hlines = value;
      markNeedsLayout();
    }
  }

  List<double> get rowSpacings => _rowSpacings;
  List<double> _rowSpacings;
  set rowSpacings(List<double> value) {
    if (!const ListEquality<double>().equals(_rowSpacings, value)) {
      _rowSpacings = value;
      markNeedsLayout();
    }
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! EqnArrayParentData) {
      child.parentData = EqnArrayParentData();
    }
  }

  List<double> hlinePos = [];

  double width = 0.0;

  int get _rowCount => rowSpacings.length;

  @override
  double computeMinIntrinsicWidth(double height) =>
      _computeIntrinsicWidth(height, (child, extent) {
        return child.getMinIntrinsicWidth(extent);
      });

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _computeIntrinsicWidth(height, (child, extent) {
        return child.getMaxIntrinsicWidth(extent);
      });

  double _computeIntrinsicWidth(
    double height,
    double Function(RenderBox child, double extent) childWidth,
  ) {
    final colWidths = <double>[];
    var nonAligningWidth = 0.0;
    var maxTagWidth = 0.0;
    var child = firstChild;
    while (child != null) {
      final parentData = child.parentData! as EqnArrayParentData;
      if (parentData.isTag) {
        maxTagWidth = math.max(maxTagWidth, childWidth(child, height));
      } else {
        final childColWidths = _intrinsicColumnWidths(
          child,
          height,
          childWidth,
        );
        if (childColWidths == null) {
          nonAligningWidth =
              math.max(nonAligningWidth, childWidth(child, height));
        } else {
          _mergeColumnWidths(colWidths, childColWidths);
        }
      }
      child = parentData.nextSibling;
    }
    final bodyWidth = math.max(nonAligningWidth, colWidths.sum);
    return _requiredWidth(bodyWidth, maxTagWidth);
  }

  List<double>? _intrinsicColumnWidths(
    RenderBox row,
    double height,
    double Function(RenderBox child, double extent) childWidth,
  ) {
    if (row is! RenderLine) return null;
    final widths = <double>[0.0];
    var child = row.firstChild;
    var hasAligner = false;
    while (child != null) {
      final parentData = child.parentData! as LineParentData;
      if (parentData.alignerOrSpacer) {
        hasAligner = true;
        widths.add(0.0);
      } else {
        widths[widths.length - 1] +=
            childWidth(child, height) + parentData.trailingMargin;
      }
      child = parentData.nextSibling;
    }
    return hasAligner ? widths : null;
  }

  void _mergeColumnWidths(List<double> target, List<double> candidate) {
    for (var index = 0; index < candidate.length; index++) {
      if (index == target.length) {
        target.add(candidate[index]);
      } else {
        target[index] = math.max(target[index], candidate[index]);
      }
    }
  }

  double _requiredWidth(double bodyWidth, double maxTagWidth) =>
      maxTagWidth == 0.0 ? bodyWidth : bodyWidth + 2 * (tagGap + maxTagWidth);

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _computeLayout(constraints);

  @override
  void performLayout() {
    size = _computeLayout(constraints, dry: false);
  }

  Size _computeLayout(
    BoxConstraints constraints, {
    bool dry = true,
  }) {
    final rows = List<RenderBox?>.filled(_rowCount, null);
    final tags = List<RenderBox?>.filled(_rowCount, null);
    var child = firstChild;
    while (child != null) {
      final parentData = child.parentData! as EqnArrayParentData;
      assert(parentData.rowIndex < _rowCount);
      if (parentData.isTag) {
        tags[parentData.rowIndex] = child;
      } else {
        rows[parentData.rowIndex] = child;
      }
      child = parentData.nextSibling;
    }
    assert(rows.every((row) => row != null));

    final rowSizes = List<Size>.filled(_rowCount, Size.zero);
    final tagSizes = List<Size>.filled(_rowCount, Size.zero);
    final colWidths = <double>[];
    var nonAligningChildrenWidth = 0.0;
    var maxTagWidth = 0.0;

    // First pass: measure bodies and labels independently. Only equation
    // bodies participate in the alignment-column calculation.
    for (var index = 0; index < _rowCount; index++) {
      final row = rows[index]!;
      if (row is RenderLine) row.alignColWidth = null;
      final rowSize = row.getLayoutSize(infiniteConstraint, dry: dry);
      rowSizes[index] = rowSize;

      List<double>? childColWidths;
      if (row is RenderLine) {
        childColWidths = dry
            ? _intrinsicColumnWidths(
                row,
                double.infinity,
                (child, height) => child.getMaxIntrinsicWidth(height),
              )
            : row.alignColWidth;
      }
      if (childColWidths == null) {
        nonAligningChildrenWidth =
            math.max(nonAligningChildrenWidth, rowSize.width);
      } else {
        _mergeColumnWidths(colWidths, childColWidths);
      }

      final tag = tags[index];
      if (tag != null) {
        final tagSize = tag.getLayoutSize(infiniteConstraint, dry: dry);
        tagSizes[index] = tagSize;
        maxTagWidth = math.max(maxTagWidth, tagSize.width);
      }
    }

    final aligningChildrenWidth = colWidths.sum;
    final bodyWidth = math.max(nonAligningChildrenWidth, aligningChildrenWidth);
    final requiredWidth = _requiredWidth(bodyWidth, maxTagWidth);
    final desiredWidth = expandToMaxWidth && constraints.hasBoundedWidth
        ? constraints.maxWidth
        : requiredWidth;
    final layoutWidth = constraints.constrainWidth(desiredWidth);

    var vPos = 0.0;
    if (!dry) hlinePos = [vPos];

    // Second pass: share alignment widths between body rows, center the body
    // block, then place each label independently at the physical right edge.
    for (var index = 0; index < _rowCount; index++) {
      final row = rows[index]!;
      final tag = tags[index];
      var rowSize = rowSizes[index];
      final tagSize = tagSizes[index];
      var hPos = 0.0;

      if (row is RenderLine && row.alignColWidth != null && !dry) {
        row.alignColWidth = colWidths;
        row.layout(
          BoxConstraints(maxWidth: aligningChildrenWidth),
          parentUsesSize: true,
        );
        rowSize = row.size;
        hPos = (layoutWidth - aligningChildrenWidth) / 2 +
            colWidths[0] -
            row.alignColWidth![0];
      } else {
        hPos = (layoutWidth - rowSize.width) / 2;
      }

      final tagHPos = layoutWidth - tagSize.width;
      final tagFitsBesideBody =
          tag == null || hPos + rowSize.width + tagGap <= tagHPos;

      final rowHeight = dry ? 0.0 : row.layoutHeight;
      final rowDepth = dry ? rowSize.height : row.layoutDepth;
      final tagHeight = dry || tag == null ? 0.0 : tag.layoutHeight;
      final tagDepth = dry || tag == null ? tagSize.height : tag.layoutDepth;

      if (tagFitsBesideBody) {
        final height = math.max(rowHeight, tagHeight);
        final depth = math.max(rowDepth, tagDepth);
        vPos += math.max(height, 0.7 * arrayskip);
        if (!dry) {
          (row.parentData! as EqnArrayParentData).offset =
              Offset(hPos, vPos - rowHeight);
          if (tag != null) {
            (tag.parentData! as EqnArrayParentData).offset =
                Offset(tagHPos, vPos - tagHeight);
          }
        }
        vPos += math.max(depth, 0.3 * arrayskip);
      } else {
        // A genuinely tight parent cannot satisfy body centering, right-edge
        // placement, and non-overlap on one line. Keep the first two promises
        // and move this row's label below the equation.
        vPos += math.max(rowHeight, 0.7 * arrayskip);
        if (!dry) {
          (row.parentData! as EqnArrayParentData).offset =
              Offset(hPos, vPos - rowHeight);
        }
        vPos += math.max(rowDepth, 0.3 * arrayskip);
        if (!dry) {
          (tag.parentData! as EqnArrayParentData).offset =
              Offset(tagHPos, vPos);
        }
        vPos += tagSize.height;
      }

      vPos += jotSize + rowSpacings[index];
      if (!dry) hlinePos.add(vPos);
      vPos +=
          hlines[index + 1] != MatrixSeparatorStyle.none ? ruleThickness : 0.0;
    }

    if (!dry) width = layoutWidth;
    return constraints.constrain(Size(layoutWidth, vPos));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
    for (var index = 0; index < hlines.length; index++) {
      if (hlines[index] != MatrixSeparatorStyle.none) {
        final y = hlinePos[index] + ruleThickness / 2;
        context.canvas.drawLine(
          offset + Offset(0, y),
          offset + Offset(width, y),
          Paint()..strokeWidth = ruleThickness,
        );
      }
      // TODO dashed line
    }
  }
}
