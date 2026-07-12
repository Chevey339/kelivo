import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'app_database.dart';
import 'message_graph_projector.dart';

enum MessageGraphRevisionMutation { editUser, regenerateAssistant }

final class MessageGraphMutationResult {
  const MessageGraphMutationResult({
    required this.revisionId,
    required this.branchId,
    required this.projection,
  });

  final String revisionId;
  final String branchId;
  final ActiveMessageGraphProjection projection;
}

final class MessageGraphDeleteResult {
  const MessageGraphDeleteResult({
    required this.deletedRevisionCount,
    required this.deletedBranchCount,
    required this.projection,
  });

  final int deletedRevisionCount;
  final int deletedBranchCount;
  final ActiveMessageGraphProjection projection;
}

final class MessageGraphForkResult {
  MessageGraphForkResult({
    required this.conversationId,
    required this.branchId,
    required this.projection,
    required Map<String, String> revisionIds,
  }) : revisionIds = Map.unmodifiable(revisionIds);

  final String conversationId;
  final String branchId;
  final ActiveMessageGraphProjection projection;
  final Map<String, String> revisionIds;
}

final class MessageGraphCommands {
  MessageGraphCommands(
    this._db, {
    String Function()? createId,
    DateTime Function()? now,
  }) : _createId = createId ?? const Uuid().v4,
       _now = now ?? (() => DateTime.now().toUtc());

  final AppDatabase _db;
  final String Function() _createId;
  final DateTime Function() _now;

  Future<MessageGraphMutationResult> createRevisionBranch({
    required String conversationId,
    required String targetRevisionId,
    required String text,
    required MessageGraphRevisionMutation mutation,
    int? expectedStateRevision,
    String? revisionId,
    String? branchId,
  }) {
    return _db.transaction(() async {
      final projector = MessageGraphProjector(_db);
      final current = await projector.projectActivePath(
        conversationId: conversationId,
      );
      if (current == null || current.branchId == null) {
        throw StateError('message_graph_active_branch_missing');
      }
      _requireExpectedState(current, expectedStateRevision);
      final targetIndex = current.revisions.indexWhere(
        (revision) => revision.id == targetRevisionId,
      );
      if (targetIndex < 0) {
        throw ArgumentError.value(
          targetRevisionId,
          'targetRevisionId',
          'must identify a revision on the active path',
        );
      }
      final target = current.revisions[targetIndex];
      final expectedRole = mutation == MessageGraphRevisionMutation.editUser
          ? 'user'
          : 'assistant';
      if (target.role != expectedRole) {
        throw StateError('message_graph_mutation_role');
      }

      final maxRevision = _db.messageRevisionRows.revisionNo.max();
      final maxRow =
          await (_db.selectOnly(_db.messageRevisionRows)
                ..addColumns([maxRevision])
                ..where(
                  _db.messageRevisionRows.conversationId.equals(
                        conversationId,
                      ) &
                      _db.messageRevisionRows.slotId.equals(target.slotId),
                ))
              .getSingle();
      final nextRevisionNo = (maxRow.read(maxRevision) ?? -1) + 1;
      final createdRevisionId = revisionId ?? _createId();
      final createdBranchId = branchId ?? _createId();
      final timestamp = _now();
      await _db
          .into(_db.messageRevisionRows)
          .insert(
            MessageRevisionRowsCompanion.insert(
              id: createdRevisionId,
              conversationId: conversationId,
              slotId: target.slotId,
              parentRevisionId: Value(target.parentRevisionId),
              revisionNo: nextRevisionNo,
              createdAt: timestamp,
              updatedAt: timestamp,
              finalizedAt: mutation == MessageGraphRevisionMutation.editUser
                  ? Value(timestamp)
                  : const Value.absent(),
            ),
          );
      await _insertTextPart(
        conversationId: conversationId,
        revisionId: createdRevisionId,
        text: text,
        timestamp: timestamp,
      );
      await _db
          .into(_db.conversationBranchRows)
          .insert(
            ConversationBranchRowsCompanion.insert(
              id: createdBranchId,
              conversationId: conversationId,
              parentBranchId: Value(current.branchId),
              forkedFromRevisionId: Value(target.parentRevisionId),
              leafRevisionId: Value(createdRevisionId),
              causalityKind: 'native',
              createdAt: timestamp,
            ),
          );
      final boundary = _boundaryBeforeTarget(current, targetIndex);
      await _activateBranch(
        conversationId: conversationId,
        branchId: createdBranchId,
        boundaryRevisionId: boundary,
        currentStateRevision: current.stateRevision,
      );
      final projection = await projector.projectActivePath(
        conversationId: conversationId,
      );
      return MessageGraphMutationResult(
        revisionId: createdRevisionId,
        branchId: createdBranchId,
        projection: projection!,
      );
    });
  }

  Future<MessageGraphMutationResult> graftRevision({
    required String conversationId,
    required String targetRevisionId,
    required String text,
    required MessageGraphRevisionMutation mutation,
    int? expectedStateRevision,
    String? revisionId,
  }) {
    return _db.transaction(() async {
      final projector = MessageGraphProjector(_db);
      final current = await projector.projectActivePath(
        conversationId: conversationId,
      );
      if (current == null || current.branchId == null) {
        throw StateError('message_graph_active_branch_missing');
      }
      _requireExpectedState(current, expectedStateRevision);
      final targetIndex = current.revisions.indexWhere(
        (revision) => revision.id == targetRevisionId,
      );
      if (targetIndex < 0) {
        throw ArgumentError.value(
          targetRevisionId,
          'targetRevisionId',
          'must identify a revision on the active path',
        );
      }
      final target = current.revisions[targetIndex];
      final expectedRole = mutation == MessageGraphRevisionMutation.editUser
          ? 'user'
          : 'assistant';
      if (target.role != expectedRole) {
        throw StateError('message_graph_mutation_role');
      }

      final maxRevision = _db.messageRevisionRows.revisionNo.max();
      final maxRow =
          await (_db.selectOnly(_db.messageRevisionRows)
                ..addColumns([maxRevision])
                ..where(
                  _db.messageRevisionRows.conversationId.equals(
                        conversationId,
                      ) &
                      _db.messageRevisionRows.slotId.equals(target.slotId),
                ))
              .getSingle();
      final timestamp = _now();
      final createdRevisionId = revisionId ?? _createId();
      await _db
          .into(_db.messageRevisionRows)
          .insert(
            MessageRevisionRowsCompanion.insert(
              id: createdRevisionId,
              conversationId: conversationId,
              slotId: target.slotId,
              parentRevisionId: Value(target.parentRevisionId),
              revisionNo: (maxRow.read(maxRevision) ?? -1) + 1,
              createdAt: timestamp,
              updatedAt: timestamp,
              finalizedAt: mutation == MessageGraphRevisionMutation.editUser
                  ? Value(timestamp)
                  : const Value.absent(),
            ),
          );
      await _insertTextPart(
        conversationId: conversationId,
        revisionId: createdRevisionId,
        text: text,
        timestamp: timestamp,
      );

      if (targetIndex + 1 < current.revisions.length) {
        final child = current.revisions[targetIndex + 1];
        final updatedChild =
            await (_db.update(_db.messageRevisionRows)..where(
                  (row) =>
                      row.conversationId.equals(conversationId) &
                      row.id.equals(child.id) &
                      row.parentRevisionId.equals(target.id),
                ))
                .write(
                  MessageRevisionRowsCompanion(
                    parentRevisionId: Value(createdRevisionId),
                    updatedAt: Value(timestamp),
                  ),
                );
        if (updatedChild != 1) {
          throw StateError('message_graph_graft_child_conflict');
        }
      } else {
        final updatedBranch =
            await (_db.update(_db.conversationBranchRows)..where(
                  (row) =>
                      row.conversationId.equals(conversationId) &
                      row.id.equals(current.branchId!) &
                      row.leafRevisionId.equals(target.id) &
                      row.deletedAt.isNull(),
                ))
                .write(
                  ConversationBranchRowsCompanion(
                    leafRevisionId: Value(createdRevisionId),
                  ),
                );
        if (updatedBranch != 1) {
          throw StateError('message_graph_graft_leaf_conflict');
        }
      }

      final boundary = current.contextStartRevisionId == target.id
          ? createdRevisionId
          : current.contextStartRevisionId;
      final updatedState =
          await (_db.update(_db.conversationStateRows)..where(
                (row) =>
                    row.conversationId.equals(conversationId) &
                    row.activeBranchId.equals(current.branchId!) &
                    row.stateRevision.equals(current.stateRevision),
              ))
              .write(
                ConversationStateRowsCompanion(
                  contextStartRevisionId: Value(boundary),
                  stateRevision: Value(current.stateRevision + 1),
                ),
              );
      if (updatedState != 1) throw StateError('message_graph_state_conflict');
      final projection = await projector.projectActivePath(
        conversationId: conversationId,
      );
      return MessageGraphMutationResult(
        revisionId: createdRevisionId,
        branchId: current.branchId!,
        projection: projection!,
      );
    });
  }

  Future<ActiveMessageGraphProjection> selectRevision({
    required String conversationId,
    required String revisionId,
    int? expectedStateRevision,
  }) {
    return _db.transaction(() async {
      final projector = MessageGraphProjector(_db);
      final current = await projector.projectActivePath(
        conversationId: conversationId,
      );
      if (current == null || current.branchId == null) {
        throw StateError('message_graph_active_branch_missing');
      }
      _requireExpectedState(current, expectedStateRevision);
      final revision =
          await (_db.select(_db.messageRevisionRows)..where(
                (row) =>
                    row.conversationId.equals(conversationId) &
                    row.id.equals(revisionId) &
                    row.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (revision == null) {
        throw StateError('message_graph_revision_missing');
      }
      final currentSlotIndex = current.revisions.indexWhere(
        (candidate) => candidate.slotId == revision.slotId,
      );
      if (currentSlotIndex >= 0) {
        final selected = current.revisions[currentSlotIndex];
        if (selected.id == revision.id) return current;
        if (current.causalityKind == 'native' &&
            selected.parentRevisionId == revision.parentRevisionId) {
          final timestamp = _now();
          if (currentSlotIndex + 1 < current.revisions.length) {
            final child = current.revisions[currentSlotIndex + 1];
            final updatedChild =
                await (_db.update(_db.messageRevisionRows)..where(
                      (row) =>
                          row.conversationId.equals(conversationId) &
                          row.id.equals(child.id) &
                          row.parentRevisionId.equals(selected.id),
                    ))
                    .write(
                      MessageRevisionRowsCompanion(
                        parentRevisionId: Value(revision.id),
                        updatedAt: Value(timestamp),
                      ),
                    );
            if (updatedChild != 1) {
              throw StateError('message_graph_graft_child_conflict');
            }
          } else {
            final updatedBranch =
                await (_db.update(_db.conversationBranchRows)..where(
                      (row) =>
                          row.conversationId.equals(conversationId) &
                          row.id.equals(current.branchId!) &
                          row.leafRevisionId.equals(selected.id) &
                          row.deletedAt.isNull(),
                    ))
                    .write(
                      ConversationBranchRowsCompanion(
                        leafRevisionId: Value(revision.id),
                      ),
                    );
            if (updatedBranch != 1) {
              throw StateError('message_graph_graft_leaf_conflict');
            }
          }
          final boundary = current.contextStartRevisionId == selected.id
              ? revision.id
              : current.contextStartRevisionId;
          final updatedState =
              await (_db.update(_db.conversationStateRows)..where(
                    (row) =>
                        row.conversationId.equals(conversationId) &
                        row.activeBranchId.equals(current.branchId!) &
                        row.stateRevision.equals(current.stateRevision),
                  ))
                  .write(
                    ConversationStateRowsCompanion(
                      contextStartRevisionId: Value(boundary),
                      stateRevision: Value(current.stateRevision + 1),
                    ),
                  );
          if (updatedState != 1) {
            throw StateError('message_graph_state_conflict');
          }
          return (await projector.projectActivePath(
            conversationId: conversationId,
          ))!;
        }
      }
      final activation = await _findOrCreateBranchForRevision(
        projector: projector,
        current: current,
        revision: revision,
      );
      await _activateBranch(
        conversationId: conversationId,
        branchId: activation.branchId,
        boundaryRevisionId: activation.boundaryRevisionId,
        currentStateRevision: current.stateRevision,
      );
      return (await projector.projectActivePath(
        conversationId: conversationId,
      ))!;
    });
  }

  Future<MessageGraphDeleteResult> deleteRevision({
    required String conversationId,
    required String revisionId,
    required bool confirmCascade,
    int? expectedStateRevision,
  }) {
    return _db.transaction(() async {
      final projector = MessageGraphProjector(_db);
      final current = await projector.projectActivePath(
        conversationId: conversationId,
      );
      if (current == null || current.branchId == null) {
        throw StateError('message_graph_active_branch_missing');
      }
      _requireExpectedState(current, expectedStateRevision);
      final target =
          await (_db.select(_db.messageRevisionRows)..where(
                (row) =>
                    row.conversationId.equals(conversationId) &
                    row.id.equals(revisionId) &
                    row.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (target == null) {
        throw StateError('message_graph_revision_missing');
      }
      final alternates =
          await (_db.select(_db.messageRevisionRows)
                ..where(
                  (row) =>
                      row.conversationId.equals(conversationId) &
                      row.slotId.equals(target.slotId) &
                      row.id.equals(revisionId).not() &
                      row.deletedAt.isNull(),
                )
                ..orderBy([
                  (row) => OrderingTerm.desc(row.revisionNo),
                  (row) => OrderingTerm.asc(row.id),
                ]))
              .get();
      if (alternates.isEmpty && !confirmCascade) {
        throw StateError('message_graph_delete_requires_confirmation');
      }

      final descendants = await _descendants(
        conversationId: conversationId,
        revisionId: revisionId,
      );
      final liveBranches =
          await (_db.select(_db.conversationBranchRows)..where(
                (row) =>
                    row.conversationId.equals(conversationId) &
                    row.deletedAt.isNull(),
              ))
              .get();
      final directlyAffectedBranchIds = <String>{};
      for (final branch in liveBranches) {
        final path = await projector.projectBranchPath(
          conversationId: conversationId,
          branchId: branch.id,
        );
        if (path.revisions.any(
          (revision) => descendants.ids.contains(revision.id),
        )) {
          directlyAffectedBranchIds.add(branch.id);
        }
      }
      var expanded = true;
      while (expanded) {
        expanded = false;
        for (final branch in liveBranches) {
          final parentId = branch.parentBranchId;
          if (parentId != null &&
              directlyAffectedBranchIds.contains(parentId) &&
              directlyAffectedBranchIds.add(branch.id)) {
            expanded = true;
          }
        }
      }
      final affectedBranches = liveBranches
          .where((branch) => directlyAffectedBranchIds.contains(branch.id))
          .toList(growable: false);
      final activeAffected = affectedBranches.any(
        (branch) => branch.id == current.branchId,
      );
      var timestamp = _now();
      if (timestamp.isBefore(descendants.latestCreatedAt)) {
        timestamp = descendants.latestCreatedAt;
      }
      for (final branch in affectedBranches) {
        if (timestamp.isBefore(branch.createdAt)) timestamp = branch.createdAt;
      }
      for (final branch in affectedBranches) {
        await (_db.update(
          _db.conversationBranchRows,
        )..where((row) => row.id.equals(branch.id))).write(
          ConversationBranchRowsCompanion(deletedAt: Value(timestamp)),
        );
      }
      await _markDescendantsDeleted(
        conversationId: conversationId,
        revisionId: revisionId,
        timestamp: timestamp,
      );

      if (activeAffected) {
        final replacementLeaf = alternates.isNotEmpty
            ? alternates.first.id
            : target.parentRevisionId;
        final branchId = _createId();
        await _db
            .into(_db.conversationBranchRows)
            .insert(
              ConversationBranchRowsCompanion.insert(
                id: branchId,
                conversationId: conversationId,
                forkedFromRevisionId: Value(target.parentRevisionId),
                leafRevisionId: Value(replacementLeaf),
                causalityKind: 'native',
                createdAt: timestamp,
              ),
            );
        final repairedPath = await projector.projectBranchPath(
          conversationId: conversationId,
          branchId: branchId,
        );
        final boundary = current.contextStartRevisionId;
        final preservedBoundary =
            boundary != null &&
                repairedPath.revisions.any(
                  (revision) => revision.id == boundary,
                )
            ? boundary
            : null;
        await _activateBranch(
          conversationId: conversationId,
          branchId: branchId,
          boundaryRevisionId: preservedBoundary,
          currentStateRevision: current.stateRevision,
        );
      }
      final projection = await projector.projectActivePath(
        conversationId: conversationId,
      );
      return MessageGraphDeleteResult(
        deletedRevisionCount: descendants.ids.length,
        deletedBranchCount: affectedBranches.length,
        projection: projection!,
      );
    });
  }

  Future<MessageGraphForkResult> forkConversation({
    required String sourceConversationId,
    required String sourceBranchId,
    required String sourceRevisionId,
    required String targetConversationId,
    required String title,
  }) {
    return _db.transaction(() async {
      final projector = MessageGraphProjector(_db);
      final sourcePath = await projector.projectBranchPath(
        conversationId: sourceConversationId,
        branchId: sourceBranchId,
        targetRevisionId: sourceRevisionId,
      );
      final sourceConversation = await (_db.select(
        _db.conversationRows,
      )..where((row) => row.id.equals(sourceConversationId))).getSingle();
      final timestamp = _now();
      await _db
          .into(_db.conversationRows)
          .insert(
            ConversationRowsCompanion.insert(
              id: targetConversationId,
              title: title,
              createdAt: timestamp,
              updatedAt: timestamp,
              isPinned: const Value(false),
              assistantId: Value(sourceConversation.assistantId),
            ),
          );

      final slotIds = <String, String>{};
      final revisionIds = <String, String>{};
      String? parentRevisionId;
      for (final sourceRevision in sourcePath.revisions) {
        final slotId = slotIds.putIfAbsent(sourceRevision.slotId, _createId);
        if (!revisionIds.containsKey(sourceRevision.id)) {
          await _db
              .into(_db.messageSlotRows)
              .insert(
                MessageSlotRowsCompanion.insert(
                  id: slotId,
                  conversationId: targetConversationId,
                  role: sourceRevision.role,
                  createdAt: sourceRevision.createdAt,
                ),
                mode: InsertMode.insertOrIgnore,
              );
        }
        final revisionId = _createId();
        revisionIds[sourceRevision.id] = revisionId;
        await _db
            .into(_db.messageRevisionRows)
            .insert(
              MessageRevisionRowsCompanion.insert(
                id: revisionId,
                conversationId: targetConversationId,
                slotId: slotId,
                parentRevisionId: Value(parentRevisionId),
                revisionNo: sourceRevision.revisionNo,
                createdAt: sourceRevision.createdAt,
                updatedAt: sourceRevision.updatedAt,
                finalizedAt: Value(sourceRevision.finalizedAt),
              ),
            );
        final parts =
            await (_db.select(_db.messagePartRows)..where(
                  (row) =>
                      row.conversationId.equals(sourceConversationId) &
                      row.revisionId.equals(sourceRevision.id),
                ))
                .get();
        for (final part in parts) {
          await _db
              .into(_db.messagePartRows)
              .insert(
                MessagePartRowsCompanion.insert(
                  conversationId: targetConversationId,
                  revisionId: revisionId,
                  ordinal: part.ordinal,
                  kind: part.kind,
                  payload: part.payload,
                  createdAt: part.createdAt,
                  updatedAt: part.updatedAt,
                ),
              );
        }
        parentRevisionId = revisionId;
      }
      final branchId = _createId();
      await _db
          .into(_db.conversationBranchRows)
          .insert(
            ConversationBranchRowsCompanion.insert(
              id: branchId,
              conversationId: targetConversationId,
              leafRevisionId: Value(parentRevisionId),
              causalityKind: 'native',
              createdAt: timestamp,
            ),
          );
      final sourceState =
          await (_db.select(_db.conversationStateRows)..where(
                (row) => row.conversationId.equals(sourceConversationId),
              ))
              .getSingleOrNull();
      final mappedBoundary = sourceState?.contextStartRevisionId == null
          ? null
          : revisionIds[sourceState!.contextStartRevisionId];
      await _db
          .into(_db.conversationStateRows)
          .insert(
            ConversationStateRowsCompanion.insert(
              conversationId: targetConversationId,
              activeBranchId: Value(branchId),
              contextStartRevisionId: Value(mappedBoundary),
            ),
          );
      final projection = await projector.projectActivePath(
        conversationId: targetConversationId,
      );
      return MessageGraphForkResult(
        conversationId: targetConversationId,
        branchId: branchId,
        projection: projection!,
        revisionIds: revisionIds,
      );
    });
  }

  Future<void> _insertTextPart({
    required String conversationId,
    required String revisionId,
    required String text,
    required DateTime timestamp,
  }) => _db
      .into(_db.messagePartRows)
      .insert(
        MessagePartRowsCompanion.insert(
          conversationId: conversationId,
          revisionId: revisionId,
          ordinal: 0,
          kind: 'text',
          payload: text,
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );

  Future<_BranchActivation> _findOrCreateBranchForRevision({
    required MessageGraphProjector projector,
    required ActiveMessageGraphProjection current,
    required MessageRevisionRow revision,
  }) async {
    final branches =
        await (_db.select(_db.conversationBranchRows)
              ..where(
                (row) =>
                    row.conversationId.equals(current.conversationId) &
                    row.deletedAt.isNull(),
              )
              ..orderBy([
                (row) => OrderingTerm.desc(row.createdAt),
                (row) => OrderingTerm.asc(row.id),
              ]))
            .get();
    MessageGraphPath? selectedPath;
    for (final branch in branches) {
      final path = await projector.projectBranchPath(
        conversationId: current.conversationId,
        branchId: branch.id,
      );
      if (path.revisions.any((node) => node.id == revision.id)) {
        if (path.branchLeafRevisionId == revision.id) {
          selectedPath = path;
          break;
        }
        selectedPath ??= path;
      }
    }
    if (selectedPath == null ||
        selectedPath.branchLeafRevisionId != revision.id) {
      final branchId = _createId();
      await _db
          .into(_db.conversationBranchRows)
          .insert(
            ConversationBranchRowsCompanion.insert(
              id: branchId,
              conversationId: current.conversationId,
              parentBranchId: Value(current.branchId),
              forkedFromRevisionId: Value(revision.parentRevisionId),
              leafRevisionId: Value(revision.id),
              causalityKind: 'native',
              createdAt: _now(),
            ),
          );
      selectedPath = await projector.projectBranchPath(
        conversationId: current.conversationId,
        branchId: branchId,
      );
    }
    final boundary = current.contextStartRevisionId;
    return _BranchActivation(
      branchId: selectedPath.branchId,
      boundaryRevisionId:
          boundary != null &&
              selectedPath.revisions.any((node) => node.id == boundary)
          ? boundary
          : null,
    );
  }

  String? _boundaryBeforeTarget(
    ActiveMessageGraphProjection current,
    int targetIndex,
  ) {
    final boundary = current.contextStartRevisionId;
    if (boundary == null) return null;
    final boundaryIndex = current.revisions.indexWhere(
      (revision) => revision.id == boundary,
    );
    return boundaryIndex >= 0 && boundaryIndex < targetIndex ? boundary : null;
  }

  Future<void> _activateBranch({
    required String conversationId,
    required String branchId,
    required String? boundaryRevisionId,
    required int currentStateRevision,
  }) async {
    final updated =
        await (_db.update(_db.conversationStateRows)..where(
              (row) =>
                  row.conversationId.equals(conversationId) &
                  row.stateRevision.equals(currentStateRevision),
            ))
            .write(
              ConversationStateRowsCompanion(
                activeBranchId: Value(branchId),
                contextStartRevisionId: Value(boundaryRevisionId),
                stateRevision: Value(currentStateRevision + 1),
              ),
            );
    if (updated != 1) throw StateError('message_graph_state_conflict');
  }

  Future<_Descendants> _descendants({
    required String conversationId,
    required String revisionId,
  }) async {
    final rows = await _db
        .customSelect(
          '''
WITH RECURSIVE descendants(id, created_at) AS (
  SELECT id, created_at FROM message_revision_rows
  WHERE conversation_id = ? AND id = ?
  UNION
  SELECT child.id, child.created_at
  FROM message_revision_rows AS child
  INNER JOIN descendants AS parent
    ON child.parent_revision_id = parent.id
  WHERE child.conversation_id = ? AND child.deleted_at IS NULL
)
SELECT id, created_at FROM descendants;
''',
          variables: [
            Variable<String>(conversationId),
            Variable<String>(revisionId),
            Variable<String>(conversationId),
          ],
        )
        .get();
    final ids = <String>{};
    var latestCreatedAt = DateTime.fromMicrosecondsSinceEpoch(0);
    for (final row in rows) {
      ids.add(row.read<String>('id'));
      final createdAt = DateTime.fromMicrosecondsSinceEpoch(
        row.read<int>('created_at'),
      );
      if (createdAt.isAfter(latestCreatedAt)) latestCreatedAt = createdAt;
    }
    return _Descendants(ids: ids, latestCreatedAt: latestCreatedAt);
  }

  Future<void> _markDescendantsDeleted({
    required String conversationId,
    required String revisionId,
    required DateTime timestamp,
  }) => _db.customStatement(
    '''
WITH RECURSIVE descendants(id) AS (
  SELECT id FROM message_revision_rows
  WHERE conversation_id = ? AND id = ?
  UNION
  SELECT child.id
  FROM message_revision_rows AS child
  INNER JOIN descendants AS parent
    ON child.parent_revision_id = parent.id
  WHERE child.conversation_id = ? AND child.deleted_at IS NULL
)
UPDATE message_revision_rows
SET deleted_at = ?, updated_at = ?
WHERE conversation_id = ? AND id IN (SELECT id FROM descendants);
''',
    [
      conversationId,
      revisionId,
      conversationId,
      timestamp.microsecondsSinceEpoch,
      timestamp.microsecondsSinceEpoch,
      conversationId,
    ],
  );

  static void _requireExpectedState(
    ActiveMessageGraphProjection projection,
    int? expectedStateRevision,
  ) {
    if (expectedStateRevision != null &&
        projection.stateRevision != expectedStateRevision) {
      throw StateError('message_graph_state_conflict');
    }
  }
}

final class _BranchActivation {
  const _BranchActivation({
    required this.branchId,
    required this.boundaryRevisionId,
  });

  final String branchId;
  final String? boundaryRevisionId;
}

final class _Descendants {
  const _Descendants({required this.ids, required this.latestCreatedAt});

  final Set<String> ids;
  final DateTime latestCreatedAt;
}
