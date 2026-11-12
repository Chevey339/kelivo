import '../../ast/nodes.dart';
import '../dialect.dart';

/// Classifies a scanned leaf block without changing its structural source boundary.
/// Use the built-in directive or fence grammar for custom multiline containers.
/// Returning null leaves the block available to the next registered syntax.
abstract class BlockSyntax {
  const BlockSyntax();
  BlockNode? parse(BlockSyntaxContext context);
}

final class BlockSyntaxContext {
  const BlockSyntaxContext({
    required this.source,
    required this.block,
    required this.options,
    required this.streaming,
  });
  final String source;
  final BlockNode block;
  final ParserOptions options;
  final bool streaming;
  String get sourceText => block.span.slice(source);
}
