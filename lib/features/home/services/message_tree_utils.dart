import '../../../core/models/chat_message.dart';

/// Shared utilities for tree-aware message version collapsing.
///
/// Used by both [ChatController] and [MessageBuilderService] to avoid
/// duplicating the tree traversal logic.
class MessageTreeUtils {
  MessageTreeUtils._();

  /// Collapse message versions, choosing tree traversal when parentId is
  /// present, otherwise falling back to flat order for legacy data.
  static List<ChatMessage> collapseVersions(
    List<ChatMessage> items,
    Map<String, int> versionSelections,
  ) {
    if (items.isEmpty) return <ChatMessage>[];

    final hasTree = items.any((m) => m.parentId != null);
    if (!hasTree) {
      return collapseVersionsFlat(items, versionSelections);
    }
    return _collapseVersionsTree(items, versionSelections);
  }

  /// Original flat collapse logic for backward compatibility.
  static List<ChatMessage> collapseVersionsFlat(
    List<ChatMessage> items,
    Map<String, int> versionSelections,
  ) {
    final Map<String, List<ChatMessage>> byGroup =
        <String, List<ChatMessage>>{};
    final List<String> order = <String>[];

    for (final m in items) {
      final gid = (m.groupId ?? m.id);
      final list = byGroup.putIfAbsent(gid, () {
        order.add(gid);
        return <ChatMessage>[];
      });
      list.add(m);
    }

    for (final e in byGroup.entries) {
      e.value.sort((a, b) => a.version.compareTo(b.version));
    }

    final out = <ChatMessage>[];
    for (final gid in order) {
      final vers = byGroup[gid]!;
      final sel = versionSelections[gid];
      final idx = (sel != null && sel >= 0 && sel < vers.length)
          ? sel
          : (vers.length - 1);
      out.add(vers[idx]);
    }

    return out;
  }

  /// Tree-aware collapse: traverse from root following selected versions
  /// and parentId chains.
  static List<ChatMessage> _collapseVersionsTree(
    List<ChatMessage> items,
    Map<String, int> versionSelections,
  ) {
    // Group all messages by groupId
    final Map<String, List<ChatMessage>> byGroup =
        <String, List<ChatMessage>>{};
    for (final m in items) {
      final gid = (m.groupId ?? m.id);
      byGroup.putIfAbsent(gid, () => <ChatMessage>[]).add(m);
    }
    for (final e in byGroup.entries) {
      e.value.sort((a, b) => a.version.compareTo(b.version));
    }

    // Select the active message from each group
    ChatMessage selectFromGroup(List<ChatMessage> vers) {
      final gid = vers.first.groupId ?? vers.first.id;
      final sel = versionSelections[gid];
      final idx = (sel != null && sel >= 0 && sel < vers.length)
          ? sel
          : (vers.length - 1);
      return vers[idx];
    }

    // Build children index: parentMsgId → set of child groupIds.
    // Register ALL unique parentIds from every version in the group so that
    // the tree traversal can find children regardless of which version is
    // selected (e.g., after editing a user message, the new assistant version
    // has parentId pointing to the new user version id).
    final Map<String, Set<String>> childGroupsByParent =
        <String, Set<String>>{};
    for (final entry in byGroup.entries) {
      for (final m in entry.value) {
        final parentId = m.parentId;
        if (parentId != null && parentId.isNotEmpty) {
          childGroupsByParent
              .putIfAbsent(parentId, () => <String>{})
              .add(entry.key);
        }
      }
    }

    // Find root groups (parentId == null for first member)
    final rootGroups = <String>[];
    for (final entry in byGroup.entries) {
      final parentId = entry.value.first.parentId;
      if (parentId == null || parentId.isEmpty) {
        rootGroups.add(entry.key);
      }
    }

    // Maintain original order among root groups using item list order
    final Map<String, int> groupFirstIndex = <String, int>{};
    for (int i = 0; i < items.length; i++) {
      final gid = items[i].groupId ?? items[i].id;
      groupFirstIndex.putIfAbsent(gid, () => i);
    }
    rootGroups.sort(
      (a, b) => (groupFirstIndex[a] ?? 0).compareTo(groupFirstIndex[b] ?? 0),
    );

    // DFS from roots, following selected versions
    final out = <ChatMessage>[];
    final visited = <String>{};

    void traverse(String groupId) {
      if (visited.contains(groupId)) return;
      visited.add(groupId);

      final vers = byGroup[groupId];
      if (vers == null || vers.isEmpty) return;

      final selected = selectFromGroup(vers);
      out.add(selected);

      // Find child groups that point to this selected message
      final childGids = childGroupsByParent[selected.id];
      if (childGids == null || childGids.isEmpty) return;

      final sortedChildren = childGids.toList()
        ..sort(
          (a, b) =>
              (groupFirstIndex[a] ?? 0).compareTo(groupFirstIndex[b] ?? 0),
        );

      for (final childGid in sortedChildren) {
        traverse(childGid);
      }
    }

    for (final rootGid in rootGroups) {
      traverse(rootGid);
    }

    return out;
  }
}