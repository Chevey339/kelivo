part of '../functions.dart';

EncodeResult _equationArrayEncoder(GreenNode node) =>
    _EquationArrayEncodeResult(node as EquationArrayNode);

class _EquationArrayEncodeResult extends EncodeResult {
  const _EquationArrayEncodeResult(this.node);

  final EquationArrayNode node;

  @override
  String stringify(TexEncodeConf conf) => List.generate(node.body.length, (
        index,
      ) {
        final body = node.body[index].encodeTeX(conf: conf.mathParam());
        final tag = node.tags[index]?.encodeTeX(conf: conf.mathParam()) ?? '';
        return '$body$tag';
      }).join(r'\\');
}
