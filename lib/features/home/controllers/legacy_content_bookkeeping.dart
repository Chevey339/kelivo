/// Split-triple bookkeeping used by the legacy renderer.
///
/// When a thinking or tool block is followed by visible text, record
/// `(offset, reasoningCount, toolCount)` so `contentSplits` can reconstruct
/// kind order. Shared by [ChatActions] and the StreamChunkShadow tests.
class LegacyContentBookkeeping {
  LegacyContentBookkeeping({
    this.hadThinkingBlock = false,
    this.fullContentRaw = '',
    List<int>? offsets,
    List<int>? reasoningCounts,
    List<int>? toolCounts,
  }) : offsets = offsets ?? <int>[],
       reasoningCounts = reasoningCounts ?? <int>[],
       toolCounts = toolCounts ?? <int>[];

  bool hadThinkingBlock;
  String fullContentRaw;
  final List<int> offsets;
  final List<int> reasoningCounts;
  final List<int> toolCounts;

  void markThinking() => hadThinkingBlock = true;

  /// Returns true when a new split triple was recorded.
  bool addContent(
    String chunkContent, {
    required int reasoningCount,
    required int toolCount,
  }) {
    var recorded = false;
    if (hadThinkingBlock && chunkContent.isNotEmpty) {
      offsets.add(fullContentRaw.length);
      reasoningCounts.add(reasoningCount);
      toolCounts.add(toolCount);
      hadThinkingBlock = false;
      recorded = true;
    }
    if (chunkContent.isNotEmpty) {
      fullContentRaw += chunkContent;
    }
    return recorded;
  }
}
