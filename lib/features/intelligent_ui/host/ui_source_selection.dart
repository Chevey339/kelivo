import 'package:Kelivo/features/chat/utils/message_reasoning_source.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/features/chat/utils/thinking_tag_parser.dart';
import 'ui_source_map.dart';

/// Native-only sources used by runtime, persistence and state projection.
List<UiSourceFence> uiEligibleFences(
  ChatMessage message, {
  bool hasProviderReasoning = false,
}) => uiDisplayFences(
  message,
  hasProviderReasoning: hasProviderReasoning,
).where((fence) => !fence.isWeb).toList();

/// Shared original-source eligibility for both native and Web presentation.
/// The visible block budgets do not change original identity or source authority.
List<UiSourceFence> uiDisplayFences(
  ChatMessage message, {
  bool hasProviderReasoning = false,
}) {
  if (message.role != 'assistant') return const [];
  final source = UiMessageSource.of(message.parts);
  if (!source.hasFences) return const [];
  final providerReasoning =
      hasProviderReasoning || messageHasProviderReasoning(message);
  final hidden = providerReasoning
      ? const <ThinkingTagHiddenRange>[]
      : ThinkingTagParser.parseWithRanges(
          message.content,
          includeUnclosed: true,
          protectedRanges: source.protectedJoinedRanges,
        ).hiddenRanges;
  return [
    for (final run in source.runs)
      for (final fence in run.fences)
        if (fence.topLevel &&
            !hidden.any(
              (range) =>
                  range.start < run.joinedStart + fence.node.span.end &&
                  range.end > run.joinedStart + fence.node.span.start,
            ))
          fence,
  ];
}
