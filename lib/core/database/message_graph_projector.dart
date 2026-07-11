import 'dart:collection';

import 'package:drift/drift.dart';

import 'app_database.dart';

final class MessageGraphIntegrityException extends StateError {
  MessageGraphIntegrityException(super.message);
}

final class MessageGraphRevision {
  const MessageGraphRevision({
    required this.id,
    required this.conversationId,
    required this.slotId,
    required this.parentRevisionId,
    required this.revisionNo,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
    required this.finalizedAt,
  });

  final String id;
  final String conversationId;
  final String slotId;
  final String? parentRevisionId;
  final int revisionNo;
  final String role;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? finalizedAt;
}

final class MessageGraphPath {
  MessageGraphPath({
    required this.conversationId,
    required this.branchId,
    required this.causalityKind,
    required this.branchLeafRevisionId,
    required this.targetRevisionId,
    required List<MessageGraphRevision> revisions,
  }) : revisions = UnmodifiableListView(revisions);

  final String conversationId;
  final String branchId;
  final String causalityKind;
  final String? branchLeafRevisionId;
  final String? targetRevisionId;
  final List<MessageGraphRevision> revisions;
}

final class ActiveMessageGraphProjection {
  ActiveMessageGraphProjection({
    required this.conversationId,
    required this.branchId,
    required this.causalityKind,
    required this.branchLeafRevisionId,
    required this.targetRevisionId,
    required this.contextStartRevisionId,
    required this.stateRevision,
    required List<MessageGraphRevision> revisions,
    required List<MessageGraphRevision> contextRevisions,
  }) : revisions = UnmodifiableListView(revisions),
       contextRevisions = UnmodifiableListView(contextRevisions);

  final String conversationId;
  final String? branchId;
  final String? causalityKind;
  final String? branchLeafRevisionId;
  final String? targetRevisionId;
  final String? contextStartRevisionId;
  final int stateRevision;
  final List<MessageGraphRevision> revisions;
  final List<MessageGraphRevision> contextRevisions;
}

final class MessageGraphValidationResult {
  const MessageGraphValidationResult({
    required this.branchCount,
    required this.pathRevisionCount,
  });

  final int branchCount;
  final int pathRevisionCount;
}

/// Read-only graph projection and integrity validation.
///
/// UI state and physical row order are deliberately absent from this API. A
/// caller must identify a conversation, branch, and optional target revision.
final class MessageGraphProjector {
  const MessageGraphProjector(this._db);

  final AppDatabase _db;

  Future<MessageGraphPath> projectBranchPath({
    required String conversationId,
    required String branchId,
    String? targetRevisionId,
  }) async {
    final branch =
        await (_db.select(_db.conversationBranchRows)..where(
              (row) =>
                  row.conversationId.equals(conversationId) &
                  row.id.equals(branchId),
            ))
            .getSingleOrNull();
    if (branch == null) {
      throw MessageGraphIntegrityException('message_graph_branch_missing');
    }
    if (branch.deletedAt != null) {
      throw MessageGraphIntegrityException('message_graph_branch_deleted');
    }

    final branchLeafRevisionId = branch.leafRevisionId;
    if (branchLeafRevisionId == null) {
      if (targetRevisionId != null) {
        throw MessageGraphIntegrityException(
          'message_graph_target_not_on_branch',
        );
      }
      return MessageGraphPath(
        conversationId: conversationId,
        branchId: branchId,
        causalityKind: branch.causalityKind,
        branchLeafRevisionId: null,
        targetRevisionId: null,
        revisions: const [],
      );
    }

    final fullPath = await _loadAncestry(
      conversationId: conversationId,
      leafRevisionId: branchLeafRevisionId,
    );
    final effectiveTarget = targetRevisionId ?? branchLeafRevisionId;
    final targetIndex = fullPath.indexWhere(
      (revision) => revision.id == effectiveTarget,
    );
    if (targetIndex < 0) {
      throw MessageGraphIntegrityException(
        'message_graph_target_not_on_branch',
      );
    }
    final projected = fullPath.sublist(0, targetIndex + 1);
    _requireUniqueSlots(projected);
    return MessageGraphPath(
      conversationId: conversationId,
      branchId: branchId,
      causalityKind: branch.causalityKind,
      branchLeafRevisionId: branchLeafRevisionId,
      targetRevisionId: effectiveTarget,
      revisions: projected,
    );
  }

  Future<ActiveMessageGraphProjection?> projectActivePath({
    required String conversationId,
    String? targetRevisionId,
  }) async {
    final state =
        await (_db.select(_db.conversationStateRows)
              ..where((row) => row.conversationId.equals(conversationId)))
            .getSingleOrNull();
    if (state == null) {
      final conversation = await (_db.select(
        _db.conversationRows,
      )..where((row) => row.id.equals(conversationId))).getSingleOrNull();
      if (conversation == null) return null;
      throw MessageGraphIntegrityException('message_graph_state_missing');
    }

    final activeBranchId = state.activeBranchId;
    if (activeBranchId == null) {
      if (state.contextStartRevisionId != null) {
        throw MessageGraphIntegrityException(
          'message_graph_boundary_without_branch',
        );
      }
      if (targetRevisionId != null) {
        throw MessageGraphIntegrityException(
          'message_graph_target_without_branch',
        );
      }
      return ActiveMessageGraphProjection(
        conversationId: conversationId,
        branchId: null,
        causalityKind: null,
        branchLeafRevisionId: null,
        targetRevisionId: null,
        contextStartRevisionId: null,
        stateRevision: state.stateRevision,
        revisions: const [],
        contextRevisions: const [],
      );
    }

    final path = await projectBranchPath(
      conversationId: conversationId,
      branchId: activeBranchId,
      targetRevisionId: targetRevisionId,
    );
    final boundaryId = state.contextStartRevisionId;
    var contextStartIndex = 0;
    if (boundaryId != null) {
      contextStartIndex = path.revisions.indexWhere(
        (revision) => revision.id == boundaryId,
      );
      if (contextStartIndex < 0) {
        throw MessageGraphIntegrityException(
          'message_graph_boundary_not_on_active_path',
        );
      }
    }
    return ActiveMessageGraphProjection(
      conversationId: conversationId,
      branchId: path.branchId,
      causalityKind: path.causalityKind,
      branchLeafRevisionId: path.branchLeafRevisionId,
      targetRevisionId: path.targetRevisionId,
      contextStartRevisionId: boundaryId,
      stateRevision: state.stateRevision,
      revisions: path.revisions,
      contextRevisions: path.revisions.sublist(contextStartIndex),
    );
  }

  Future<MessageGraphValidationResult> validateConversationGraph(
    String conversationId,
  ) async {
    final conversation = await (_db.select(
      _db.conversationRows,
    )..where((row) => row.id.equals(conversationId))).getSingleOrNull();
    if (conversation == null) {
      throw MessageGraphIntegrityException(
        'message_graph_conversation_missing',
      );
    }
    final allBranches = await (_db.select(
      _db.conversationBranchRows,
    )..where((row) => row.conversationId.equals(conversationId))).get();
    _validateBranchParents(allBranches);
    final branches = allBranches
        .where((branch) => branch.deletedAt == null)
        .toList(growable: false);
    var revisionCount = 0;
    for (final branch in branches) {
      final path = await projectBranchPath(
        conversationId: conversationId,
        branchId: branch.id,
      );
      revisionCount += path.revisions.length;
      final parentBranchId = branch.parentBranchId;
      final forkedFromRevisionId = branch.forkedFromRevisionId;
      if (parentBranchId != null && forkedFromRevisionId != null) {
        final parentPath = await projectBranchPath(
          conversationId: conversationId,
          branchId: parentBranchId,
        );
        if (!parentPath.revisions.any(
              (revision) => revision.id == forkedFromRevisionId,
            ) ||
            !path.revisions.any(
              (revision) => revision.id == forkedFromRevisionId,
            )) {
          throw MessageGraphIntegrityException(
            'message_graph_fork_not_on_paths',
          );
        }
      }
    }
    await projectActivePath(conversationId: conversationId);
    return MessageGraphValidationResult(
      branchCount: branches.length,
      pathRevisionCount: revisionCount,
    );
  }

  Future<List<MessageGraphRevision>> _loadAncestry({
    required String conversationId,
    required String leafRevisionId,
  }) async {
    final rows = await _db
        .customSelect(
          '''
WITH RECURSIVE ancestry(
  id, conversation_id, slot_id, parent_revision_id, revision_no,
  created_at, updated_at, finalized_at, deleted_at
) AS (
  SELECT
    id, conversation_id, slot_id, parent_revision_id, revision_no,
    created_at, updated_at, finalized_at, deleted_at
  FROM message_revision_rows
  WHERE conversation_id = ? AND id = ?
  UNION
  SELECT
    parent.id, parent.conversation_id, parent.slot_id,
    parent.parent_revision_id, parent.revision_no,
    parent.created_at, parent.updated_at, parent.finalized_at,
    parent.deleted_at
  FROM message_revision_rows AS parent
  INNER JOIN ancestry AS child
    ON parent.conversation_id = child.conversation_id
   AND parent.id = child.parent_revision_id
)
SELECT
  ancestry.id,
  ancestry.conversation_id,
  ancestry.slot_id,
  ancestry.parent_revision_id,
  ancestry.revision_no,
  ancestry.created_at,
  ancestry.updated_at,
  ancestry.finalized_at,
  ancestry.deleted_at,
  message_slot_rows.role
FROM ancestry
INNER JOIN message_slot_rows
  ON message_slot_rows.conversation_id = ancestry.conversation_id
 AND message_slot_rows.id = ancestry.slot_id;
''',
          variables: [
            Variable<String>(conversationId),
            Variable<String>(leafRevisionId),
          ],
        )
        .get();
    if (rows.isEmpty) {
      throw MessageGraphIntegrityException('message_graph_leaf_missing');
    }

    final byId = <String, _StoredGraphRevision>{};
    for (final row in rows) {
      final id = row.read<String>('id');
      byId[id] = _StoredGraphRevision(
        revision: MessageGraphRevision(
          id: id,
          conversationId: row.read<String>('conversation_id'),
          slotId: row.read<String>('slot_id'),
          parentRevisionId: row.readNullable<String>('parent_revision_id'),
          revisionNo: row.read<int>('revision_no'),
          role: row.read<String>('role'),
          createdAt: DateTime.fromMicrosecondsSinceEpoch(
            row.read<int>('created_at'),
          ),
          updatedAt: DateTime.fromMicrosecondsSinceEpoch(
            row.read<int>('updated_at'),
          ),
          finalizedAt: _readNullableTimestamp(row, 'finalized_at'),
        ),
        deletedAt: _readNullableTimestamp(row, 'deleted_at'),
      );
    }

    final leafToRoot = <MessageGraphRevision>[];
    final visited = <String>{};
    String? currentId = leafRevisionId;
    while (currentId != null) {
      if (!visited.add(currentId)) {
        throw MessageGraphIntegrityException('message_graph_revision_cycle');
      }
      final stored = byId[currentId];
      if (stored == null) {
        throw MessageGraphIntegrityException('message_graph_parent_missing');
      }
      if (stored.deletedAt != null) {
        throw MessageGraphIntegrityException(
          'message_graph_deleted_revision_on_path',
        );
      }
      leafToRoot.add(stored.revision);
      currentId = stored.revision.parentRevisionId;
    }
    return leafToRoot.reversed.toList(growable: false);
  }

  static DateTime? _readNullableTimestamp(QueryRow row, String column) {
    final value = row.readNullable<int>(column);
    return value == null ? null : DateTime.fromMicrosecondsSinceEpoch(value);
  }

  static void _requireUniqueSlots(List<MessageGraphRevision> revisions) {
    final slots = <String>{};
    for (final revision in revisions) {
      if (!slots.add(revision.slotId)) {
        throw MessageGraphIntegrityException(
          'message_graph_duplicate_slot_on_path',
        );
      }
    }
  }

  static void _validateBranchParents(List<ConversationBranchRow> allBranches) {
    final byId = {for (final branch in allBranches) branch.id: branch};
    for (final branch in allBranches.where(
      (candidate) => candidate.deletedAt == null,
    )) {
      final visited = <String>{};
      ConversationBranchRow? current = branch;
      while (current != null) {
        if (!visited.add(current.id)) {
          throw MessageGraphIntegrityException('message_graph_branch_cycle');
        }
        final parentId = current.parentBranchId;
        if (parentId == null) break;
        final parent = byId[parentId];
        if (parent == null) {
          throw MessageGraphIntegrityException(
            'message_graph_parent_branch_missing',
          );
        }
        if (parent.deletedAt != null) {
          throw MessageGraphIntegrityException(
            'message_graph_deleted_parent_branch',
          );
        }
        current = parent;
      }
    }
  }
}

final class _StoredGraphRevision {
  const _StoredGraphRevision({required this.revision, required this.deletedAt});

  final MessageGraphRevision revision;
  final DateTime? deletedAt;
}
