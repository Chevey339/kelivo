import 'package:flutter/widgets.dart';

import '../../render/layout/eqn_array.dart';
import '../../render/layout/shift_baseline.dart';
import '../../utils/iterable_extensions.dart';
import '../options.dart';
import '../size.dart';
import '../style.dart';
import '../syntax_tree.dart';
import '../types.dart';
import 'matrix.dart';
import 'style.dart';
import 'symbol.dart';

/// TeX environment represented by an [EquationArrayNode].
enum EquationArrayEnvironment {
  equation('equation'),
  equationStar('equation*'),
  aligned('aligned', alignsColumns: true),
  align('align', alignsColumns: true),
  alignStar('align*', alignsColumns: true),
  split('split', alignsColumns: true),
  gathered('gathered'),
  gather('gather'),
  gatherStar('gather*'),
  alignedAt('alignedat', alignsColumns: true, takesColumnCount: true),
  alignAt('alignat', alignsColumns: true, takesColumnCount: true),
  alignAtStar('alignat*', alignsColumns: true, takesColumnCount: true);

  const EquationArrayEnvironment(
    this.texName, {
    this.alignsColumns = false,
    this.takesColumnCount = false,
  });

  final String texName;
  final bool alignsColumns;
  final bool takesColumnCount;

  static EquationArrayEnvironment fromTexName(String name) =>
      values.firstWhere((environment) => environment.texName == name);
}

/// A semantic equation label and its rendered form.
///
/// [body] is derived from the current text-style display subtree, excluding the
/// synthetic parentheses of a non-literal tag. Keeping the display subtree as
/// the single source of truth means structural edits are reflected in TeX.
class EquationTagNode extends EquationRowNode {
  EquationTagNode({
    required this.literal,
    required EquationRowNode displayBody,
  }) : super(
          overrideType: displayBody.overrideType,
          children: displayBody.children,
        );

  EquationTagNode._({
    required this.literal,
    required AtomType? overrideType,
    required List<GreenNode> displayChildren,
  }) : super(overrideType: overrideType, children: displayChildren);

  final bool literal;

  late final EquationRowNode body = _deriveBody();

  EquationRowNode _deriveBody() {
    final outer = children.length == 1 ? children.single : null;
    if (outer is! StyleNode || !_isSyntheticWrapper(outer.optionsDiff)) {
      return EquationRowNode(children: children);
    }
    final displayChildren = outer.children;
    if (literal) return EquationRowNode(children: displayChildren);
    if (displayChildren.length >= 2 &&
        _isParenthesis(displayChildren.first, '(') &&
        _isParenthesis(displayChildren.last, ')')) {
      return EquationRowNode(
        children: displayChildren.sublist(1, displayChildren.length - 1),
      );
    }
    return EquationRowNode(children: children);
  }

  static bool _isSyntheticWrapper(OptionsDiff diff) =>
      diff.style == MathStyle.text &&
      diff.textFontOptions == const PartialFontOptions(fontFamily: 'Main') &&
      diff.color == null &&
      diff.size == null &&
      diff.mathFontOptions == null;

  static bool _isParenthesis(GreenNode node, String symbol) =>
      node is SymbolNode && node.mode == Mode.text && node.symbol == symbol;

  @override
  EquationTagNode updateChildren(List<GreenNode> newChildren) =>
      copyWith(children: newChildren);

  @override
  EquationTagNode copyWith({
    AtomType? overrideType,
    List<GreenNode>? children,
  }) =>
      EquationTagNode._(
        literal: literal,
        overrideType: overrideType ?? this.overrideType,
        displayChildren: children ?? this.children,
      );

  @override
  Map<String, Object?> toJson() => super.toJson()
    ..addAll({
      'body': body.toJson(),
      if (literal) 'literal': literal,
    });
}

/// Zero-width placeholder left where a `\\tag` command appeared in a row.
///
/// The semantic tag is owned by [EquationArrayNode], so this marker renders and
/// encodes as nothing while preserving an unambiguous parse result.
class EquationTagMarkerNode extends LeafNode {
  @override
  Mode get mode => Mode.math;

  @override
  BuildResult buildWidget(
    MathOptions options,
    List<BuildResult?> childBuildResults,
  ) =>
      BuildResult(widget: const SizedBox.shrink(), options: options);

  @override
  AtomType get leftType => AtomType.spacing;

  @override
  AtomType get rightType => AtomType.spacing;

  @override
  bool shouldRebuildWidget(MathOptions oldOptions, MathOptions newOptions) =>
      false;
}

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

  /// TeX environment needed to reconstruct this array during encoding.
  ///
  /// A standalone display equation with `\\tag` has no environment. Inner
  /// arrays retain environments such as `aligned` so an enclosing tagged
  /// equation can also round-trip.
  final EquationArrayEnvironment? environment;

  /// Column count argument for `alignedat` and `alignat` environments.
  final int? alignmentColumns;

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
    this.environment,
    this.alignmentColumns,
    this.arrayStretch = 1.0,
    List<MatrixSeparatorStyle>? hlines,
    List<Measurement>? rowSpacings,
  })  : assert(tags == null || tags.length == body.length),
        assert(
          environment?.takesColumnCount == true
              ? alignmentColumns != null
              : alignmentColumns == null,
        ),
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
      if (environment != null) 'environment': environment!.texName,
      if (alignmentColumns != null) 'alignmentColumns': alignmentColumns,
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
    EquationArrayEnvironment? environment,
    int? alignmentColumns,
    List<MatrixSeparatorStyle>? hlines,
    List<Measurement>? rowSpacings,
  }) =>
      EquationArrayNode(
        arrayStretch: arrayStretch ?? this.arrayStretch,
        addJot: addJot ?? this.addJot,
        body: body ?? this.body,
        tags: tags ?? this.tags,
        displayLayout: displayLayout ?? this.displayLayout,
        environment: environment ?? this.environment,
        alignmentColumns: alignmentColumns ?? this.alignmentColumns,
        hlines: hlines ?? this.hlines,
        rowSpacings: rowSpacings ?? this.rowSpacings,
      );
}
