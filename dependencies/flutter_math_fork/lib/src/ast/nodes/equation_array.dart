import '../../render/layout/eqn_array.dart';
import '../../render/layout/shift_baseline.dart';
import '../../utils/iterable_extensions.dart';
import '../options.dart';
import '../size.dart';
import '../syntax_tree.dart';
import 'matrix.dart';

/// Equantion array node. Brings support for equationa alignment.
class EquationArrayNode extends SlotableNode<EquationRowNode?> {
  /// `arrayStretch` parameter from the context.
  ///
  /// Affects the minimum row height and row depth for each row.
  ///
  /// `\smallmatrix` has an `arrayStretch` of 0.5.
  final double arrayStretch;

  /// Whether to add an extra 3 pt spacing between each row.
  ///
  /// True for `\aligned` and `\alignedat`
  final bool addJot;

  /// Arrayed equations.
  final List<EquationRowNode> body;

  /// Optional equation labels, parallel to [body].
  ///
  /// Keeping labels in their own slots lets the renderer center equation
  /// bodies independently from labels placed at the edge of a display.
  final List<EquationRowNode?> tags;

  /// Whether this array owns the available display width.
  ///
  /// This is true for outer display environments such as `align` and
  /// `gather`, and for a standalone equation with an explicit tag. Inner
  /// environments such as `aligned` remain intrinsically sized.
  final bool displayLayout;

  /// Style for horizontal separator lines.
  ///
  /// This includes outermost lines. Different from MathML!
  final List<MatrixSeparatorStyle> hlines;

  /// Spacings between rows;
  final List<Measurement> rowSpacings;

  EquationArrayNode({
    this.addJot = false,
    required this.body,
    List<EquationRowNode?>? tags,
    this.displayLayout = false,
    this.arrayStretch = 1.0,
    List<MatrixSeparatorStyle>? hlines,
    List<Measurement>? rowSpacings,
  })  : assert(tags == null || tags.length == body.length),
        tags = tags ?? List<EquationRowNode?>.filled(body.length, null),
        hlines = (hlines ?? [])
            .extendToByFill(body.length + 1, MatrixSeparatorStyle.none),
        rowSpacings =
            (rowSpacings ?? []).extendToByFill(body.length, Measurement.zero);

  @override
  BuildResult buildWidget(
          MathOptions options, List<BuildResult?> childBuildResults) =>
      BuildResult(
        options: options,
        widget: ShiftBaseline(
          relativePos: 0.5,
          offset: options.fontMetrics.axisHeight.cssEm.toLpUnder(options),
          child: EqnArray(
            ruleThickness: options.fontMetrics.defaultRuleThickness.cssEm
                .toLpUnder(options),
            jotSize: addJot ? 3.0.pt.toLpUnder(options) : 0.0,
            arrayskip: 12.0.pt.toLpUnder(options) * arrayStretch,
            hlines: hlines,
            tagGap: 1.0.em.toLpUnder(options),
            expandToMaxWidth: displayLayout,
            rowSpacings: rowSpacings
                .map((e) => e.toLpUnder(options))
                .toList(growable: false),
            rows: List.generate(
              body.length,
              (index) => childBuildResults[index * 2]!.widget,
              growable: false,
            ),
            tags: List.generate(
              body.length,
              (index) => childBuildResults[index * 2 + 1]?.widget,
              growable: false,
            ),
          ),
        ),
        isDisplayLayout: displayLayout,
      );

  @override
  List<MathOptions> computeChildOptions(MathOptions options) =>
      List.filled(children.length, options, growable: false);

  @override
  List<EquationRowNode?> computeChildren() => [
        for (var index = 0; index < body.length; index++) ...[
          body[index],
          tags[index],
        ],
      ];

  @override
  AtomType get leftType => AtomType.ord;

  @override
  AtomType get rightType => AtomType.ord;

  @override
  bool shouldRebuildWidget(MathOptions oldOptions, MathOptions newOptions) =>
      false;

  @override
  EquationArrayNode updateChildren(List<EquationRowNode?> newChildren) {
    assert(newChildren.length == body.length * 2);
    return copyWith(
      body: List.generate(
        body.length,
        (index) => newChildren[index * 2]!,
        growable: false,
      ),
      tags: List.generate(
        body.length,
        (index) => newChildren[index * 2 + 1],
        growable: false,
      ),
    );
  }

  @override
  Map<String, Object?> toJson() => super.toJson()
    ..addAll({
      if (addJot != false) 'addJot': addJot,
      'body': body.map((e) => e.toJson()),
      'tags': tags.map((e) => e?.toJson()),
      if (displayLayout != false) 'displayLayout': displayLayout,
      if (arrayStretch != 1.0) 'arrayStretch': arrayStretch,
      'hlines': hlines.map((e) => e.toString()),
      'rowSpacings': rowSpacings.map((e) => e.toString())
    });

  EquationArrayNode copyWith({
    double? arrayStretch,
    bool? addJot,
    List<EquationRowNode>? body,
    List<EquationRowNode?>? tags,
    bool? displayLayout,
    List<MatrixSeparatorStyle>? hlines,
    List<Measurement>? rowSpacings,
  }) =>
      EquationArrayNode(
        arrayStretch: arrayStretch ?? this.arrayStretch,
        addJot: addJot ?? this.addJot,
        body: body ?? this.body,
        tags: tags ?? this.tags,
        displayLayout: displayLayout ?? this.displayLayout,
        hlines: hlines ?? this.hlines,
        rowSpacings: rowSpacings ?? this.rowSpacings,
      );
}
