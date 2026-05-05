import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/features/assistant/utils/assistant_edit_tab_layout.dart';

void main() {
  group('assistant edit tab layout', () {
    test('orders saved ids first and appends missing defaults', () {
      final ordered = orderAssistantEditTabIds(
        savedOrder: const ['mcp', 'basic'],
      );

      expect(ordered.take(4), const ['mcp', 'basic', 'prompts', 'memory']);
      expect(ordered, containsAll(defaultAssistantEditTabIds));
    });

    test('ignores duplicate and unknown saved ids', () {
      final ordered = orderAssistantEditTabIds(
        savedOrder: const ['mcp', 'unknown', 'mcp', 'regex'],
      );

      expect(ordered.take(2), const ['mcp', 'regex']);
      expect(ordered.where((id) => id == 'mcp'), hasLength(1));
      expect(ordered, isNot(contains('unknown')));
    });

    test('hides requested ids while keeping order', () {
      final visible = visibleAssistantEditTabIds(
        savedOrder: const ['mcp', 'basic'],
        hiddenIds: const {'prompts', 'mcp'},
      );

      expect(visible.take(3), const ['basic', 'memory', 'quickPhrase']);
      expect(visible, isNot(contains('mcp')));
      expect(visible, isNot(contains('prompts')));
    });

    test('keeps first ordered tab visible when all tabs are hidden', () {
      final visible = visibleAssistantEditTabIds(
        savedOrder: const ['regex', 'basic'],
        hiddenIds: defaultAssistantEditTabIds.toSet(),
      );

      expect(visible, const ['regex']);
    });

    test('visual tab index switches as swipe animation crosses halfway', () {
      expect(visualAssistantEditTabIndex(animationValue: 0.49, tabCount: 4), 0);
      expect(visualAssistantEditTabIndex(animationValue: 0.51, tabCount: 4), 1);
      expect(visualAssistantEditTabIndex(animationValue: 2.60, tabCount: 4), 3);
    });

    test('visual tab index is clamped to available tabs', () {
      expect(visualAssistantEditTabIndex(animationValue: -0.8, tabCount: 4), 0);
      expect(visualAssistantEditTabIndex(animationValue: 8.2, tabCount: 4), 3);
    });
  });
}
