import '../../render/layout/line.dart';
import '../options.dart';
import '../style.dart';
import '../spacing.dart';
import '../syntax_tree.dart';
import 'multiscripts.dart';
import 'over.dart';
import 'under.dart';

/// Function node
///
/// Examples: `\sin`, `\lim`, `\operatorname`
class FunctionNode extends SlotableNode<EquationRowNode> {
  /// Name of the function.
  final EquationRowNode functionName;

  /// Argument of the function.
  final EquationRowNode argument;

  FunctionNode({
    required this.functionName,
    required this.argument,
  });

  @override
  BuildResult buildWidget(
          MathOptions options, List<BuildResult?> childBuildResults) =>
      BuildResult(
        options: options,
        widget: Line(children: [
          LineElement(
            trailingMargin:
                getSpacingSize(AtomType.op, argument.leftType, options.style)
                    .toLpUnder(options),
            child: childBuildResults[0]!.widget,
          ),
          LineElement(
            trailingMargin: 0.0,
            child: childBuildResults[1]!.widget,
          ),
        ]),
      );

  @override
  List<MathOptions> computeChildOptions(MathOptions options) =>
      List.filled(2, options, growable: false);

  @override
  List<EquationRowNode> computeChildren() => [functionName, argument];

  @override
  AtomType get leftType => AtomType.op;

  @override
  AtomType get rightType => argument.rightType;

  @override
  bool shouldRebuildWidget(MathOptions oldOptions, MathOptions newOptions) =>
      false;

  @override
  FunctionNode updateChildren(List<EquationRowNode> newChildren) =>
      copyWith(functionName: newChildren[0], argument: newChildren[1]);

  @override
  Map<String, Object?> toJson() => super.toJson()
    ..addAll({
      'functionName': functionName.toJson(),
      'argument': argument.toJson(),
    });

  FunctionNode copyWith({
    EquationRowNode? functionName,
    EquationRowNode? argument,
  }) =>
      FunctionNode(
        functionName: functionName ?? this.functionName,
        argument: argument ?? this.argument,
      );
}

/// An operator name with scripts whose default placement follows math style.
///
/// Starred TeX operators such as `\operatorname*{argmax}` place their scripts
/// above and below in display style, and beside the name in all smaller styles.
/// Explicit `\limits` and `\nolimits` override that default.
class OperatorNameNode extends SlotableNode<EquationRowNode?> {
  /// The roman-styled operator name.
  final EquationRowNode functionName;

  /// The atom following the operator.
  final EquationRowNode argument;

  /// Optional lower and upper scripts.
  final EquationRowNode? lowerLimit;
  final EquationRowNode? upperLimit;

  /// An explicit limits override, or null to use [limitsInDisplayStyle].
  final bool? limits;

  /// Whether display style defaults to above-and-below limits.
  final bool limitsInDisplayStyle;

  OperatorNameNode({
    required this.functionName,
    required this.argument,
    this.lowerLimit,
    this.upperLimit,
    this.limits,
    this.limitsInDisplayStyle = false,
  });

  @override
  BuildResult buildWidget(
      MathOptions options, List<BuildResult?> childBuildResults) {
    var functionNameResult = childBuildResults[0]!;
    final shouldUseLimits = limits ??
        (limitsInDisplayStyle && options.style.size == MathStyle.display.size);

    if (lowerLimit != null || upperLimit != null) {
      if (shouldUseLimits) {
        GreenNode renderedName = functionName;
        if (upperLimit != null) {
          final over = OverNode(
            base: renderedName.wrapWithEquationRow(),
            above: upperLimit!,
          );
          functionNameResult = over.buildWidget(
            options,
            [functionNameResult, childBuildResults[2]],
          );
          renderedName = over;
        }
        if (lowerLimit != null) {
          final under = UnderNode(
            base: renderedName.wrapWithEquationRow(),
            below: lowerLimit!,
          );
          functionNameResult = under.buildWidget(
            options,
            [functionNameResult, childBuildResults[1]],
          );
        }
      } else {
        functionNameResult = MultiscriptsNode(
          base: functionName,
          sub: lowerLimit,
          sup: upperLimit,
        ).buildWidget(
          options,
          [
            functionNameResult,
            childBuildResults[1],
            childBuildResults[2],
            null,
            null,
          ],
        );
      }
    }

    return FunctionNode(
      functionName: functionName,
      argument: argument,
    ).buildWidget(
      options,
      [functionNameResult, childBuildResults[3]],
    );
  }

  @override
  List<MathOptions> computeChildOptions(MathOptions options) => [
        options,
        options.havingStyle(options.style.sub()),
        options.havingStyle(options.style.sup()),
        options,
      ];

  @override
  List<EquationRowNode?> computeChildren() => [
        functionName,
        lowerLimit,
        upperLimit,
        argument,
      ];

  @override
  AtomType get leftType => AtomType.op;

  @override
  AtomType get rightType => argument.rightType;

  @override
  bool shouldRebuildWidget(MathOptions oldOptions, MathOptions newOptions) =>
      oldOptions.style.size != newOptions.style.size ||
      oldOptions.sizeMultiplier != newOptions.sizeMultiplier;

  @override
  OperatorNameNode updateChildren(List<EquationRowNode?> newChildren) =>
      OperatorNameNode(
        functionName: newChildren[0]!,
        lowerLimit: newChildren[1],
        upperLimit: newChildren[2],
        argument: newChildren[3]!,
        limits: limits,
        limitsInDisplayStyle: limitsInDisplayStyle,
      );

  @override
  Map<String, Object?> toJson() => super.toJson()
    ..addAll({
      'functionName': functionName.toJson(),
      'argument': argument.toJson(),
      if (lowerLimit != null) 'lowerLimit': lowerLimit!.toJson(),
      if (upperLimit != null) 'upperLimit': upperLimit!.toJson(),
      if (limits != null) 'limits': limits,
      if (limitsInDisplayStyle) 'limitsInDisplayStyle': true,
    });
}
