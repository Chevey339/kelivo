part of '../functions.dart';

EncodeResult _equationArrayEncoder(GreenNode node) =>
    _EquationArrayEncodeResult(node as EquationArrayNode);

EncodeResult _equationTagEncoder(GreenNode node) =>
    _EquationTagEncodeResult(node as EquationTagNode);

EncodeResult _equationTagMarkerEncoder(GreenNode node) =>
    const StaticEncodeResult('');

class _EquationTagEncodeResult extends EncodeResult {
  const _EquationTagEncodeResult(this.node);

  final EquationTagNode node;

  @override
  String stringify(TexEncodeConf conf) {
    final body = _encodeTagChildren(node.body.children, conf.text());
    return '\\tag${node.literal ? '*' : ''}{$body}';
  }

  String _encodeTagChildren(List<GreenNode> children, TexEncodeConf conf) =>
      children.map((child) => _encodeTagChild(child, conf)).texJoin();

  String _encodeTagChild(GreenNode child, TexEncodeConf conf) {
    if (child is EquationRowNode) {
      return '{${_encodeTagChildren(child.children, conf)}}';
    }
    if (child is StyleNode &&
        conf.mode == Mode.text &&
        child.optionsDiff.style == MathStyle.text &&
        _containsMathNode(child)) {
      final remainingDiff = child.optionsDiff.removeStyle();
      final mathConf = conf.math();
      final content = _encodeTagChildren(child.children, mathConf);
      final encoded = _encodeStyle(remainingDiff, content, mathConf);
      return r'\(' + encoded + r'\)';
    }
    if (child is StyleNode) {
      final content = _encodeTagChildren(child.children, conf);
      return _encodeStyle(child.optionsDiff, content, conf);
    }
    return child.encodeTeX(conf: conf.ord());
  }

  String _encodeStyle(
    OptionsDiff diff,
    String content,
    TexEncodeConf conf,
  ) =>
      diff.isEmpty
          ? content
          : _optionsDiffEncode(
              diff,
              <dynamic>[StaticEncodeResult(content)],
            ).stringify(conf);

  bool _containsMathNode(GreenNode node) {
    if (node is LeafNode) return node.mode == Mode.math;
    return node.children.whereType<GreenNode>().any(_containsMathNode);
  }
}

class _EquationArrayEncodeResult extends EncodeResult {
  const _EquationArrayEncodeResult(this.node);

  final EquationArrayNode node;

  @override
  String stringify(TexEncodeConf conf) {
    final rows = List.generate(node.body.length, (index) {
      final body = _encodeEquationRow(node.body[index], conf);
      final tag = node.tags[index];
      if (tag == null) return body;
      if (tag is! EquationTagNode) {
        conf.reportNonstrict(
          'unknown equation tag source',
          'Equation tag has no \\tag source metadata',
        );
        return body;
      }
      return '$body${tag.encodeTeX(conf: conf.mathParam())}';
    });
    final body = rows.join(r'\\');
    final environment = node.environment;
    if (environment == null) return body;

    final argument =
        environment.takesColumnCount ? '{${node.alignmentColumns}}' : '';
    return '\\begin{${environment.texName}}$argument'
        '$body\\end{${environment.texName}}';
  }

  String _encodeEquationRow(EquationRowNode row, TexEncodeConf conf) {
    final children = row.children
        .where((child) => child is! EquationTagMarkerNode)
        .toList(growable: false);
    if (node.environment?.alignsColumns != true) {
      return EquationRowTexEncodeResult(
        children.map(encodeTex).toList(growable: false),
      ).stringify(conf.mathParam());
    }

    final lastAligner = children.lastIndexWhere(
      (child) => child is SpaceNode && child.alignerOrSpacer,
    );
    return List.generate(children.length, (index) {
      final child = children[index];
      if (child is SpaceNode && child.alignerOrSpacer) {
        return index == lastAligner ? '' : '&';
      }
      return child.encodeTeX(conf: conf.ord());
    }).texJoin();
  }
}
