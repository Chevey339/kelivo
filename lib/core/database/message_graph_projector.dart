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

final class MessageGraphTimelineRevision {
  const MessageGraphTimelineRevision({
    required this.revisionId,
    required this.slotId,
    required this.parentRevisionId,
    required this.revisionNo,
    required this.role,
    required this.text,
    required this.reasoning,
    required this.createdAt,
    required this.updatedAt,
    required this.finalizedAt,
  });

  final String revisionId;
  final String slotId;
  final String? parentRevisionId;
  final int revisionNo;
  final String role;
  final String text;
  final String? reasoning;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? finalizedAt;
}

/// Immutable business read model. Selection and context are stable graph IDs;
/// legacy list positions and conversation JSON never participate.
final class MessageGraphTimelineProjection {
  MessageGraphTimelineProjection({
    required this.conversationId,
    required this.branchId,
    required this.stateRevision,
    required this.contextStartRevisionId,
    required List<MessageGraphTimelineRevision> activeRevisions,
    required Map<String, List<MessageGraphTimelineRevision>> revisionsBySlot,
    required Map<String, String> selectedRevisionBySlot,
  }) : activeRevisions = UnmodifiableListView(activeRevisions),
       revisionsBySlot = UnmodifiableMapView({
         for (final entry in revisionsBySlot.entries)
           entry.key: UnmodifiableListView(entry.value),
       }),
       selectedRevisionBySlot = UnmodifiableMapView(selectedRevisionBySlot);

  final String conversationId;
  final String? branchId;
  final int stateRevision;
  final String? contextStartRevisionId;
  final List<MessageGraphTimelineRevision> activeRevisions;
  final Map<String, List<MessageGraphTimelineRevision>> revisionsBySlot;
  final Map<String, String> selectedRevisionBySlot;

  List<MessageGraphTimelineRevision> get contextRevisions {
    final boundary = contextStartRevisionId;
    if (boundary == null) return activeRevisions;
    final index = activeRevisions.indexWhere(
      (revision) => revision.revisionId == boundary,
    );
    if (index < 0) {
      throw MessageGraphIntegrityException(
        'message_graph_boundary_not_on_active_path',
      );
    }
    return UnmodifiableListView(activeRevisions.sublist(index));
  }
}

final class ActiveTimelineSlot {
  const ActiveTimelineSlot({
    required this.slotId,
    required this.revisionId,
    required this.parentRevisionId,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
    required this.finalizedAt,
    required this.versionCount,
    required this.logicalIndex,
  });

  final String slotId;
  final String revisionId;
  final String? parentRevisionId;
  final String role;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? finalizedAt;
  final int versionCount;
  final int logicalIndex;
}

final class ActiveTimelinePage {
  ActiveTimelinePage({
    required this.conversationId,
    required this.branchId,
    required this.stateRevision,
    required this.contextStartRevisionId,
    required List<ActiveTimelineSlot> slots,
    required this.hasMoreBefore,
    required this.hasMoreAfter,
    required this.totalSlotCount,
  }) : slots = UnmodifiableListView(slots);

  final String conversationId;
  final String? branchId;
  final int stateRevision;
  final String? contextStartRevisionId;
  final List<ActiveTimelineSlot> slots;
  final bool hasMoreBefore;
  final bool hasMoreAfter;
  final int totalSlotCount;

  String? get beforeRevisionId =>
      hasMoreBefore && slots.isNotEmpty ? slots.first.revisionId : null;
  String? get afterRevisionId =>
      hasMoreAfter && slots.isNotEmpty ? slots.last.revisionId : null;
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

  Future<ActiveTimelinePage?> projectActiveTimelinePage({
    required String conversationId,
    String? beforeRevisionId,
    String? afterRevisionId,
    String? aroundRevisionId,
    bool fromStart = false,
    int limit = 40,
  }) async {
    if (limit <= 0) throw ArgumentError.value(limit, 'limit');
    final cursorCount = [
      beforeRevisionId,
      afterRevisionId,
      aroundRevisionId,
    ].where((cursor) => cursor != null).length;
    if (cursorCount > 1 || (fromStart && cursorCount != 0)) {
      throw ArgumentError('Only one timeline cursor may be supplied.');
    }
    final state =
        await (_db.select(_db.conversationStateRows)
              ..where((row) => row.conversationId.equals(conversationId)))
            .getSingleOrNull();
    if (state == null) {
      final exists = await (_db.select(
        _db.conversationRows,
      )..where((row) => row.id.equals(conversationId))).getSingleOrNull();
      if (exists == null) return null;
      throw MessageGraphIntegrityException('message_graph_state_missing');
    }
    final branchId = state.activeBranchId;
    if (branchId == null) {
      return ActiveTimelinePage(
        conversationId: conversationId,
        branchId: null,
        stateRevision: state.stateRevision,
        contextStartRevisionId: state.contextStartRevisionId,
        slots: const [],
        hasMoreBefore: false,
        hasMoreAfter: false,
        totalSlotCount: 0,
      );
    }
    final branch =
        await (_db.select(_db.conversationBranchRows)..where(
              (row) =>
                  row.conversationId.equals(conversationId) &
                  row.id.equals(branchId) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (branch == null) {
      throw MessageGraphIntegrityException('message_graph_branch_missing');
    }
    final leafRevisionId = branch.leafRevisionId;
    if (leafRevisionId == null) {
      return ActiveTimelinePage(
        conversationId: conversationId,
        branchId: branchId,
        stateRevision: state.stateRevision,
        contextStartRevisionId: state.contextStartRevisionId,
        slots: const [],
        hasMoreBefore: false,
        hasMoreAfter: false,
        totalSlotCount: 0,
      );
    }

    final cursor = beforeRevisionId ?? afterRevisionId ?? aroundRevisionId;
    if (cursor != null &&
        !await _activePathContains(
          conversationId: conversationId,
          leafRevisionId: leafRevisionId,
          revisionId: cursor,
        )) {
      throw MessageGraphIntegrityException(
        'message_graph_cursor_not_on_active_path',
      );
    }

    final aroundLeading = limit ~/ 2;
    final aroundTrailing = limit - aroundLeading - 1;
    final aroundCursorCte = aroundRevisionId == null
        ? ''
        : ', cursor_depth AS ('
              'SELECT depth FROM active_path WHERE id = ?'
              ')';
    final cursorPredicate = beforeRevisionId != null
        ? 'WHERE depth > (SELECT depth FROM active_path WHERE id = ?)'
        : afterRevisionId != null
        ? 'WHERE depth < (SELECT depth FROM active_path WHERE id = ?)'
        : aroundRevisionId != null
        ? 'WHERE path.depth BETWEEN '
              'MAX(0, (SELECT depth FROM cursor_depth) - ?) '
              'AND (SELECT depth FROM cursor_depth) + ?'
        : '';
    final order =
        afterRevisionId != null || aroundRevisionId != null || fromStart
        ? 'DESC'
        : 'ASC';
    final variables = <Variable<Object>>[
      Variable.withString(leafRevisionId),
      Variable.withString(conversationId),
      Variable.withString(conversationId),
      if (cursor != null) Variable.withString(cursor),
      if (aroundRevisionId != null) ...[
        Variable.withInt(aroundTrailing),
        Variable.withInt(aroundLeading),
      ],
      Variable.withInt(aroundRevisionId == null ? limit + 1 : limit),
    ];
    final rows = await _db
        .customSelect(
          '''
WITH RECURSIVE active_path(
  id, slot_id, parent_revision_id, created_at, updated_at, finalized_at, depth
) AS (
  SELECT id, slot_id, parent_revision_id, created_at, updated_at, finalized_at, 0
  FROM message_revision_rows
  WHERE id = ? AND conversation_id = ? AND deleted_at IS NULL
  UNION ALL
  SELECT parent.id, parent.slot_id, parent.parent_revision_id,
         parent.created_at, parent.updated_at, parent.finalized_at,
         child.depth + 1
  FROM message_revision_rows AS parent
  JOIN active_path AS child ON child.parent_revision_id = parent.id
  WHERE parent.conversation_id = ?
    AND parent.deleted_at IS NULL
)
$aroundCursorCte
SELECT path.id, path.slot_id, path.parent_revision_id,
       path.created_at, path.updated_at, path.finalized_at,
       slot.role, path.depth,
       (SELECT COUNT(*) FROM active_path) AS total_slot_count
FROM active_path AS path
JOIN message_slot_rows AS slot ON slot.id = path.slot_id
$cursorPredicate
ORDER BY path.depth $order
LIMIT ?;
''',
          variables: variables,
          readsFrom: {_db.messageRevisionRows, _db.messageSlotRows},
        )
        .get();
    final hasExtra = rows.length > limit;
    final selectedRows = rows.take(limit).toList(growable: true);
    final orderedRows =
        afterRevisionId == null && aroundRevisionId == null && !fromStart
        ? selectedRows.reversed.toList(growable: false)
        : selectedRows;
    final slotIds = orderedRows
        .map((row) => row.read<String>('slot_id'))
        .toSet();
    final versionCounts = <String, int>{};
    if (slotIds.isNotEmpty) {
      final slot = _db.messageRevisionRows.slotId;
      final count = _db.messageRevisionRows.id.count();
      final countRows =
          await (_db.selectOnly(_db.messageRevisionRows)
                ..addColumns([slot, count])
                ..where(
                  _db.messageRevisionRows.conversationId.equals(
                        conversationId,
                      ) &
                      _db.messageRevisionRows.slotId.isIn(slotIds) &
                      _db.messageRevisionRows.deletedAt.isNull(),
                )
                ..groupBy([slot]))
              .get();
      for (final row in countRows) {
        versionCounts[row.read(slot)!] = row.read(count) ?? 0;
      }
    }
    final slots = [
      for (final row in orderedRows)
        ActiveTimelineSlot(
          slotId: row.read<String>('slot_id'),
          revisionId: row.read<String>('id'),
          parentRevisionId: row.readNullable<String>('parent_revision_id'),
          role: row.read<String>('role'),
          createdAt: _readDateTime(row, 'created_at'),
          updatedAt: _readDateTime(row, 'updated_at'),
          finalizedAt: _readNullableDateTime(row, 'finalized_at'),
          versionCount: versionCounts[row.read<String>('slot_id')] ?? 1,
          logicalIndex:
              row.read<int>('total_slot_count') - 1 - row.read<int>('depth'),
        ),
    ];
    final totalSlotCount = rows.isEmpty
        ? await _activePathLength(
            conversationId: conversationId,
            leafRevisionId: leafRevisionId,
          )
        : rows.first.read<int>('total_slot_count');
    return ActiveTimelinePage(
      conversationId: conversationId,
      branchId: branchId,
      stateRevision: state.stateRevision,
      contextStartRevisionId: state.contextStartRevisionId,
      slots: slots,
      hasMoreBefore: aroundRevisionId != null
          ? slots.isNotEmpty && slots.first.logicalIndex > 0
          : fromStart
          ? false
          : beforeRevisionId != null
          ? hasExtra
          : afterRevisionId != null
          ? true
          : hasExtra,
      hasMoreAfter: aroundRevisionId != null
          ? slots.isNotEmpty && slots.last.logicalIndex < totalSlotCount - 1
          : fromStart
          ? hasExtra
          : afterRevisionId != null
          ? hasExtra
          : beforeRevisionId != null,
      totalSlotCount: totalSlotCount,
    );
  }

  Future<int> _activePathLength({
    required String conversationId,
    required String leafRevisionId,
  }) async {
    final row = await _db
        .customSelect(
          '''
WITH RECURSIVE active_path(id, parent_revision_id) AS (
  SELECT id, parent_revision_id FROM message_revision_rows
  WHERE id = ? AND conversation_id = ? AND deleted_at IS NULL
  UNION ALL
  SELECT parent.id, parent.parent_revision_id
  FROM message_revision_rows AS parent
  JOIN active_path AS child ON child.parent_revision_id = parent.id
  WHERE parent.conversation_id = ? AND parent.deleted_at IS NULL
)
SELECT COUNT(*) AS slot_count FROM active_path;
''',
          variables: [
            Variable.withString(leafRevisionId),
            Variable.withString(conversationId),
            Variable.withString(conversationId),
          ],
          readsFrom: {_db.messageRevisionRows},
        )
        .getSingle();
    return row.read<int>('slot_count');
  }

  Future<bool> _activePathContains({
    required String conversationId,
    required String leafRevisionId,
    required String revisionId,
  }) async {
    final row = await _db
        .customSelect(
          '''
WITH RECURSIVE active_path(id, parent_revision_id) AS (
  SELECT id, parent_revision_id
  FROM message_revision_rows
  WHERE id = ? AND conversation_id = ? AND deleted_at IS NULL
  UNION ALL
  SELECT parent.id, parent.parent_revision_id
  FROM message_revision_rows AS parent
  JOIN active_path AS child ON child.parent_revision_id = parent.id
  WHERE parent.conversation_id = ? AND parent.deleted_at IS NULL
)
SELECT EXISTS(SELECT 1 FROM active_path WHERE id = ?) AS found;
''',
          variables: [
            Variable.withString(leafRevisionId),
            Variable.withString(conversationId),
            Variable.withString(conversationId),
            Variable.withString(revisionId),
          ],
          readsFrom: {_db.messageRevisionRows},
        )
        .getSingle();
    return row.read<int>('found') != 0;
  }

  DateTime _readDateTime(QueryRow row, String key) =>
      DateTime.fromMicrosecondsSinceEpoch(row.read<int>(key));

  DateTime? _readNullableDateTime(QueryRow row, String key) {
    final value = row.readNullable<int>(key);
    return value == null ? null : DateTime.fromMicrosecondsSinceEpoch(value);
  }

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

  Future<MessageGraphTimelineProjection?> projectTimeline({
    required String conversationId,
  }) async {
    final active = await projectActivePath(conversationId: conversationId);
    if (active == null) return null;
    if (active.revisions.isEmpty) {
      return MessageGraphTimelineProjection(
        conversationId: conversationId,
        branchId: active.branchId,
        stateRevision: active.stateRevision,
        contextStartRevisionId: active.contextStartRevisionId,
        activeRevisions: const [],
        revisionsBySlot: const {},
        selectedRevisionBySlot: const {},
      );
    }

    final slotIds = active.revisions.map((revision) => revision.slotId).toSet();
    final revisionRows =
        await (_db.select(_db.messageRevisionRows)
              ..where(
                (row) =>
                    row.conversationId.equals(conversationId) &
                    row.slotId.isIn(slotIds) &
                    row.deletedAt.isNull(),
              )
              ..orderBy([
                (row) => OrderingTerm.asc(row.revisionNo),
                (row) => OrderingTerm.asc(row.id),
              ]))
            .get();
    final revisionIds = revisionRows.map((row) => row.id).toSet();
    final partRows =
        await (_db.select(_db.messagePartRows)
              ..where(
                (row) =>
                    row.conversationId.equals(conversationId) &
                    row.revisionId.isIn(revisionIds),
              )
              ..orderBy([
                (row) => OrderingTerm.asc(row.revisionId),
                (row) => OrderingTerm.asc(row.ordinal),
              ]))
            .get();
    final partsByRevision = <String, List<MessagePartRow>>{};
    for (final part in partRows) {
      partsByRevision.putIfAbsent(part.revisionId, () => []).add(part);
    }
    final roleBySlot = {
      for (final revision in active.revisions) revision.slotId: revision.role,
    };
    final timelineById = <String, MessageGraphTimelineRevision>{};
    final revisionsBySlot = <String, List<MessageGraphTimelineRevision>>{};
    for (final row in revisionRows) {
      final parts = partsByRevision[row.id] ?? const <MessagePartRow>[];
      final reasoning = parts
          .where((part) => part.kind == 'reasoning')
          .map((part) => part.payload)
          .join();
      final revision = MessageGraphTimelineRevision(
        revisionId: row.id,
        slotId: row.slotId,
        parentRevisionId: row.parentRevisionId,
        revisionNo: row.revisionNo,
        role: roleBySlot[row.slotId]!,
        text: parts
            .where((part) => part.kind == 'text')
            .map((part) => part.payload)
            .join(),
        reasoning: reasoning.isEmpty ? null : reasoning,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        finalizedAt: row.finalizedAt,
      );
      timelineById[row.id] = revision;
      revisionsBySlot.putIfAbsent(row.slotId, () => []).add(revision);
    }
    final activeTimeline = [
      for (final revision in active.revisions) timelineById[revision.id]!,
    ];
    return MessageGraphTimelineProjection(
      conversationId: conversationId,
      branchId: active.branchId,
      stateRevision: active.stateRevision,
      contextStartRevisionId: active.contextStartRevisionId,
      activeRevisions: activeTimeline,
      revisionsBySlot: revisionsBySlot,
      selectedRevisionBySlot: {
        for (final revision in activeTimeline)
          revision.slotId: revision.revisionId,
      },
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
