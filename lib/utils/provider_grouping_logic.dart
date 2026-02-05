import '../core/models/provider_group.dart';

const String providerUngroupedGroupKey = '__ungrouped__';

// ----- Reorder analysis (UI-independent) -----

sealed class ProviderGroupingRowVM {
  const ProviderGroupingRowVM();
}

class ProviderGroupingHeaderVM extends ProviderGroupingRowVM {
  const ProviderGroupingHeaderVM({required this.groupKey});
  final String groupKey; // groupId or `__ungrouped__`
}

class ProviderGroupingProviderVM extends ProviderGroupingRowVM {
  const ProviderGroupingProviderVM({
    required this.providerKey,
    required this.groupKey,
  });
  final String providerKey;
  final String groupKey; // groupId or `__ungrouped__` (original group)
}

class ProviderGroupingMoveIntent {
  const ProviderGroupingMoveIntent({
    required this.providerKey,
    required this.targetGroupKey,
    required this.targetPos,
  });

  final String providerKey;
  /// groupId or `__ungrouped__`
  final String targetGroupKey;
  /// Position within the target group's visible provider segment (0-based).
  final int targetPos;
}

enum ProviderGroupingReorderBlockedReason {
  targetGroupCollapsed,
}

class ProviderGroupingReorderAnalysis {
  final ProviderGroupingMoveIntent? intent;
  final ProviderGroupingReorderBlockedReason? blockedReason;

  const ProviderGroupingReorderAnalysis._({this.intent, this.blockedReason});

  const ProviderGroupingReorderAnalysis.allowed(ProviderGroupingMoveIntent intent) : this._(intent: intent);

  const ProviderGroupingReorderAnalysis.blocked(ProviderGroupingReorderBlockedReason reason) : this._(blockedReason: reason);

  const ProviderGroupingReorderAnalysis.invalid() : this._();

  bool get isAllowed => intent != null;
  bool get isBlocked => blockedReason != null;
  bool get isInvalid => intent == null && blockedReason == null;
}

ProviderGroupingReorderAnalysis analyzeProviderGroupingReorder({
  required List<ProviderGroupingRowVM> rows,
  required int oldIndex,
  required int newIndex,
  required bool Function(String groupKey) isGroupCollapsed,
  bool disallowInsertBeforeFirstHeader = true,
  bool disallowCrossGroupIntoCollapsedEmpty = true,
}) {
  if (rows.isEmpty) return const ProviderGroupingReorderAnalysis.invalid();
  if (oldIndex < 0 || oldIndex >= rows.length) return const ProviderGroupingReorderAnalysis.invalid();

  // Normalize newIndex because Flutter passes the index after removal.
  if (newIndex > oldIndex) newIndex -= 1;
  newIndex = newIndex.clamp(0, rows.length);
  if (disallowInsertBeforeFirstHeader && newIndex == 0) newIndex = 1;
  if (newIndex == oldIndex) return const ProviderGroupingReorderAnalysis.invalid();

  final moved = rows[oldIndex];
  if (moved is! ProviderGroupingProviderVM) return const ProviderGroupingReorderAnalysis.invalid();
  final oldGroupKey = moved.groupKey;

  final sim = List<ProviderGroupingRowVM>.from(rows);
  final removed = sim.removeAt(oldIndex);
  final insertIndex = newIndex.clamp(0, sim.length);
  sim.insert(insertIndex, removed);
  final movedIndex = insertIndex;

  int headerIndex = -1;
  for (int i = movedIndex - 1; i >= 0; i--) {
    if (sim[i] is ProviderGroupingHeaderVM) {
      headerIndex = i;
      break;
    }
  }
  if (headerIndex < 0) return const ProviderGroupingReorderAnalysis.invalid();

  final targetGroupKey = (sim[headerIndex] as ProviderGroupingHeaderVM).groupKey;

  if (disallowCrossGroupIntoCollapsedEmpty) {
    final isCrossGroup = oldGroupKey != targetGroupKey;
    final targetVisibleCount =
        rows
            .whereType<ProviderGroupingProviderVM>()
            .where((e) => e.groupKey == targetGroupKey && !isGroupCollapsed(e.groupKey))
            .length;
    if (isCrossGroup && isGroupCollapsed(targetGroupKey) && targetVisibleCount == 0) {
      return const ProviderGroupingReorderAnalysis.blocked(ProviderGroupingReorderBlockedReason.targetGroupCollapsed);
    }
  }

  int targetPos = 0;
  for (int i = headerIndex + 1; i < movedIndex; i++) {
    if (sim[i] is ProviderGroupingProviderVM && !isGroupCollapsed((sim[i] as ProviderGroupingProviderVM).groupKey)) {
      targetPos++;
    }
  }

  return ProviderGroupingReorderAnalysis.allowed(
    ProviderGroupingMoveIntent(
      providerKey: moved.providerKey,
      targetGroupKey: targetGroupKey,
      targetPos: targetPos,
    ),
  );
}

// ----- Provider order + group map updates (pure) -----

class ProviderGroupingMoveResult {
  const ProviderGroupingMoveResult({
    required this.providersOrder,
    required this.providerGroupMap,
  });

  final List<String> providersOrder;
  /// providerKey -> groupId (missing = ungrouped)
  final Map<String, String> providerGroupMap;
}

ProviderGroupingMoveResult moveProviderInGroupedOrder({
  required List<String> providersOrder,
  required Map<String, String> providerGroupMap,
  required Set<String> knownProviderKeys,
  required Set<String> validGroupIds,
  required String providerKey,
  required String? targetGroupId,
  required int targetPos,
}) {
  if (!knownProviderKeys.contains(providerKey)) {
    return ProviderGroupingMoveResult(
      providersOrder: List<String>.unmodifiable(providersOrder),
      providerGroupMap: Map<String, String>.unmodifiable(providerGroupMap),
    );
  }

  final normalizedTargetGroupId = (targetGroupId != null && validGroupIds.contains(targetGroupId)) ? targetGroupId : null;

  // Clean mapping first (best-effort) and apply providerKey update.
  final nextMap = <String, String>{};
  for (final entry in providerGroupMap.entries) {
    final k = entry.key;
    final gid = entry.value;
    if (!knownProviderKeys.contains(k)) continue;
    if (!validGroupIds.contains(gid)) continue;
    nextMap[k] = gid;
  }
  if (normalizedTargetGroupId == null) {
    nextMap.remove(providerKey);
  } else {
    nextMap[providerKey] = normalizedTargetGroupId;
  }

  // Normalize order: keep known keys, dedupe, and remove the moved key.
  final nextOrder = <String>[];
  final seen = <String>{};
  for (final k in providersOrder) {
    if (!knownProviderKeys.contains(k)) continue;
    if (!seen.add(k)) continue;
    if (k == providerKey) continue;
    nextOrder.add(k);
  }

  String? groupIdFor(String key) {
    final gid = nextMap[key];
    return (gid != null && validGroupIds.contains(gid)) ? gid : null;
  }

  final targetKeys = [for (final k in nextOrder) if (groupIdFor(k) == normalizedTargetGroupId) k];
  final clampedPos = targetPos.clamp(0, targetKeys.length);

  int insertIndex;
  if (targetKeys.isEmpty) {
    insertIndex = nextOrder.length;
  } else if (clampedPos <= 0) {
    insertIndex = nextOrder.indexOf(targetKeys.first);
  } else if (clampedPos >= targetKeys.length) {
    insertIndex = nextOrder.indexOf(targetKeys.last) + 1;
  } else {
    insertIndex = nextOrder.indexOf(targetKeys[clampedPos]);
  }
  insertIndex = insertIndex.clamp(0, nextOrder.length);
  nextOrder.insert(insertIndex, providerKey);

  return ProviderGroupingMoveResult(
    providersOrder: List<String>.unmodifiable(nextOrder),
    providerGroupMap: Map<String, String>.unmodifiable(nextMap),
  );
}

class ProviderGroupingDeleteGroupResult {
  const ProviderGroupingDeleteGroupResult({
    required this.groups,
    required this.providerGroupMap,
    required this.collapsed,
  });

  final List<ProviderGroup> groups;
  final Map<String, String> providerGroupMap;
  final Map<String, bool> collapsed;
}

ProviderGroupingDeleteGroupResult deleteProviderGroup({
  required List<ProviderGroup> groups,
  required Map<String, String> providerGroupMap,
  required Map<String, bool> collapsed,
  required String groupId,
}) {
  final nextGroups = [for (final g in groups) if (g.id != groupId) g];
  final nextMap = Map<String, String>.from(providerGroupMap)..removeWhere((_, gid) => gid == groupId);
  final nextCollapsed = Map<String, bool>.from(collapsed)..remove(groupId);
  return ProviderGroupingDeleteGroupResult(
    groups: List<ProviderGroup>.unmodifiable(nextGroups),
    providerGroupMap: Map<String, String>.unmodifiable(nextMap),
    collapsed: Map<String, bool>.unmodifiable(nextCollapsed),
  );
}
