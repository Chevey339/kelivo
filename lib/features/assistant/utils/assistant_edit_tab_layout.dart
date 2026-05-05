const String assistantEditTabBasic = 'basic';
const String assistantEditTabPrompts = 'prompts';
const String assistantEditTabMemory = 'memory';
const String assistantEditTabMcp = 'mcp';
const String assistantEditTabQuickPhrase = 'quickPhrase';
const String assistantEditTabCustom = 'custom';
const String assistantEditTabRegex = 'regex';

const List<String> defaultAssistantEditTabIds = [
  assistantEditTabBasic,
  assistantEditTabPrompts,
  assistantEditTabMemory,
  assistantEditTabMcp,
  assistantEditTabQuickPhrase,
  assistantEditTabCustom,
  assistantEditTabRegex,
];

List<String> orderAssistantEditTabIds({
  required List<String> savedOrder,
  List<String> defaultOrder = defaultAssistantEditTabIds,
}) {
  final validIds = defaultOrder.toSet();
  final seen = <String>{};
  final result = <String>[];
  for (final id in savedOrder) {
    if (validIds.contains(id) && seen.add(id)) result.add(id);
  }
  for (final id in defaultOrder) {
    if (seen.add(id)) result.add(id);
  }
  return List.unmodifiable(result);
}

List<String> visibleAssistantEditTabIds({
  required List<String> savedOrder,
  required Set<String> hiddenIds,
  List<String> defaultOrder = defaultAssistantEditTabIds,
}) {
  final ordered = orderAssistantEditTabIds(
    savedOrder: savedOrder,
    defaultOrder: defaultOrder,
  );
  final visible = ordered.where((id) => !hiddenIds.contains(id)).toList();
  return List.unmodifiable(visible.isNotEmpty ? visible : [ordered.first]);
}

int visualAssistantEditTabIndex({
  required double animationValue,
  required int tabCount,
}) {
  if (tabCount <= 0) return 0;
  return animationValue.round().clamp(0, tabCount - 1);
}
