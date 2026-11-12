import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/chat/widgets/timeline_projection.dart';
import 'package:Kelivo/features/home/services/local_tools_service.dart';

TimelineProjectedStep tool(
  String id, {
  String name = LocalToolNames.browser,
  int ordinal = 0,
}) => TimelineProjectedStep.tool(
  sourceOrdinal: ordinal,
  tool: TimelineToolRef(
    providerId: id,
    fallbackOrdinal: ordinal,
    toolName: name,
    arguments: const {},
  ),
  reasoningCountAfter: 0,
  toolCountAfter: ordinal + 1,
);
const think = TimelineProjectedStep.reasoning(
  sourceOrdinal: 3,
  reasoning: TimelineReasoningRef(text: 'think'),
  reasoningCountAfter: 1,
  toolCountAfter: 2,
);
void main() {
  test(
    'adjacent browser tools form one stable group, including singletons',
    () {
      final grouped = groupBrowserTimelineSteps([
        tool('a', ordinal: 7),
        tool('b'),
        tool('c'),
        tool('d'),
      ], isPendingApproval: (_) => false);
      expect(grouped, hasLength(1));
      expect(grouped.single.sourceOrdinal, 7);
      expect(grouped.single.browserTools!.map((t) => t.id), [
        'a',
        'b',
        'c',
        'd',
      ]);
      expect(grouped.single.tool!.id, 'd');
      expect(grouped.single.browserLite, isFalse);
      expect(
        groupBrowserTimelineSteps([
          tool('a'),
        ], isPendingApproval: (_) => false).single.browserTools,
        hasLength(1),
      );
    },
  );
  test(
    'reasoning, other tools and pending approvals break groups without reordering',
    () {
      final grouped = groupBrowserTimelineSteps([
        tool('a'),
        think,
        tool('b'),
        tool('approval'),
        tool('c'),
        tool('other', name: 'other'),
        tool('d'),
      ], isPendingApproval: (tool) => tool.id == 'approval');
      expect(grouped, hasLength(7));
      expect(grouped[1], same(think));
      expect(grouped[3].browserTools, isNull);
      expect(grouped[5].browserTools, isNull);
      expect(
        grouped.where((s) => s.browserTools != null).map((s) => s.browserLite),
        [true, true, true, false],
      );
    },
  );
  test(
    'height projection collapses groups as one step and keeps filtered boundaries',
    () {
      final blocks = [
        TimelineProjectedBlock.thinking([
          tool('a'),
          tool('b'),
          think,
          tool('c'),
          tool('d'),
        ]),
      ];
      final visible = collapseProjectedTimeline(
        blocks,
        showThinkingCards: true,
        showToolCards: true,
        collapseThinkingSteps: true,
        isPendingApproval: (_) => false,
      ).single;
      expect(visible.hiddenCount, 1);
      expect(visible.visibleSteps, hasLength(2));
      expect(visible.visibleSteps.last.browserTools, hasLength(2));
      final hiddenThinking = collapseProjectedTimeline(
        blocks,
        showThinkingCards: false,
        showToolCards: true,
        collapseThinkingSteps: true,
        isPendingApproval: (_) => false,
      ).single;
      expect(hiddenThinking.visibleSteps, hasLength(1));
      expect(hiddenThinking.hiddenCount, 0);
      expect(hiddenThinking.visibleSteps.single.browserTools, hasLength(4));
    },
  );
}
