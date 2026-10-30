part of 'chat_database_repository.dart';

extension ChatContextRepository on ChatDatabaseRepository {
  // Read only selection metadata for the excluded prefix. Large message parts
  // and provider artifacts are hydrated only for history actually being sent.
  Future<List<ChatMessage>> _contextMetadata(String id) async {
    await _timelineIndex.ensureConversation(id);
    final rows = await _db
        .customSelect(
          'SELECT g.group_id,m.id,m.role FROM timeline_group_rows g '
          'LEFT JOIN timeline_selection_rows s ON s.conversation_id=g.conversation_id AND s.group_id=g.group_id '
          'JOIN message_rows m ON m.id=${MessageTimelineIndex.selectedRevision('g')} '
          'WHERE g.conversation_id=? ORDER BY g.anchor_order,g.group_id',
          variables: [Variable<String>(id)],
        )
        .get();
    return [
      for (final row in rows)
        ChatMessage(
          id: row.read<String>('id'),
          groupId: row.read<String>('group_id'),
          role: row.read<String>('role'),
          conversationId: id,
        ),
    ];
  }

  Future<
    ({
      List<ChatMessage> messages,
      List<ContextOperation> operations,
      String fingerprint,
    })
  >
  readContextSnapshot(String id) => _db.transaction(() async {
    final operations = await readContextOperations(id);
    final messages = await getSelectedContextMessages(id, limit: 0x7fffffff);
    return (
      messages: messages,
      operations: operations,
      fingerprint: ContextHistory.fingerprint(messages, operations),
    );
  });

  Future<List<ChatMessage>> getEffectiveContextMessages(
    String id, {
    required int limit,
    String? throughRevisionId,
    bool includeFollowingAssistant = false,
  }) => _db.transaction(() async {
    final operations = await readContextOperations(id);
    if (operations.every((op) => op.revoked)) {
      return getSelectedContextMessages(
        id,
        limit: limit,
        throughRevisionId: throughRevisionId,
        includeFollowingAssistant: includeFollowingAssistant,
      );
    }
    final metadata = await _contextMetadata(id);
    String? throughGroup;
    String? endGroup;
    if (throughRevisionId != null) {
      final target =
          await (_db.select(_db.messageRows)..where(
                (r) =>
                    r.id.equals(throughRevisionId) &
                    r.conversationId.equals(id),
              ))
              .getSingleOrNull();
      if (target == null) return <ChatMessage>[];
      throughGroup = target.groupId ?? target.id;
      endGroup = throughGroup;
      final index = metadata.indexWhere(
        (m) => ContextHistory.group(m) == throughGroup,
      );
      if (includeFollowingAssistant &&
          target.role == 'user' &&
          index >= 0 &&
          index + 1 < metadata.length &&
          metadata[index + 1].role == 'assistant') {
        endGroup = ContextHistory.group(metadata[index + 1]);
      }
    }
    final projected = ContextHistory.resolve(
      metadata,
      operations,
      limit: limit,
      throughGroupId: throughGroup,
      endGroupId: endGroup,
    );
    final hydrated = await getMessagesByIds([
      for (final m in projected)
        if (!ContextOperation.isSummary(m)) m.id,
    ]);
    final byId = {for (final m in hydrated) m.id: m};
    return [
      for (final m in projected)
        ContextOperation.isSummary(m) ? m : byId[m.id]!,
    ];
  });

  Future<int> contextBoundaryIndex(
    String id,
    List<ContextOperation> operations,
  ) => _db.transaction(() async {
    final clear = operations
        .where((op) => !op.revoked && !op.isCompression)
        .lastOrNull;
    if (clear == null) return -1;
    await _timelineIndex.ensureConversation(id);
    final anchor = await _db
        .customSelect(
          'SELECT anchor_order FROM timeline_group_rows WHERE conversation_id=? AND group_id=?',
          variables: [
            Variable<String>(id),
            Variable<String>(clear.anchorGroupId),
          ],
        )
        .getSingleOrNull();
    if (anchor == null) throw StateError('context_boundary_missing');
    final count = await _db
        .customSelect(
          'SELECT COUNT(*) AS n FROM timeline_group_rows WHERE conversation_id=? '
          'AND (anchor_order,group_id)<=(?,?)',
          variables: [
            Variable<String>(id),
            Variable<int>(anchor.read<int>('anchor_order')),
            Variable<String>(clear.anchorGroupId),
          ],
        )
        .getSingle();
    return count.read<int>('n');
  });

  Future<void> saveCompressionTask(
    String conversationId,
    Map<String, dynamic> task,
  ) => _db.transaction(() async {
    if (await (_db.select(
          _db.conversationRows,
        )..where((r) => r.id.equals(conversationId))).getSingleOrNull() ==
        null) {
      return;
    }
    await _db
        .into(_db.extensionEntityRows)
        .insertOnConflictUpdate(
          ExtensionEntityRowsCompanion.insert(
            kind: 'contextCompressionTask',
            id: conversationId,
            ownerId: Value(conversationId),
            sortOrder: 0,
            payload: jsonEncode(task),
            updatedAt: DateTime.now(),
          ),
        );
  });

  Future<Map<String, Map<String, dynamic>>> readCompressionTasks() async {
    final rows = await (_db.select(
      _db.extensionEntityRows,
    )..where((r) => r.kind.equals('contextCompressionTask'))).get();
    return {
      for (final row in rows)
        row.id: Map<String, dynamic>.from(jsonDecode(row.payload) as Map),
    };
  }

  Future<Object?> _contextFingerprintData(
    String schema,
    String id,
    Map<String, int> groups, {
    required int legacyTruncateIndex,
    required DateTime legacyUpdatedAt,
  }) async {
    final row = await _db
        .customSelect(
          'SELECT payload FROM $schema.extension_entity_rows WHERE kind=? AND id=?',
          variables: [
            Variable<String>(ContextOperation.entityKind),
            Variable<String>(id),
          ],
        )
        .getSingleOrNull();
    final operations = row == null
        ? <ContextOperation>[]
        : (jsonDecode(row.read<String>('payload')) as List)
              .map(
                (value) => ContextOperation.fromJson(
                  Map<String, dynamic>.from(value as Map),
                ),
              )
              .toList();
    if (legacyTruncateIndex > 0) {
      if (operations.isNotEmpty) throw StateError('context_boundary_conflict');
      operations.add(
        _legacyClearOperation(
          legacyTruncateIndex,
          groups.keys.toList(),
          legacyUpdatedAt,
        ),
      );
    }
    if (operations.isEmpty) return null;
    final ordinals = {
      for (var i = 0; i < operations.length; i++) operations[i].id: i,
    };
    return [
      for (final op in operations)
        {
          ...op.toJson()
            ..remove('id')
            // Conversion timestamps are bookkeeping, not clear semantics.
            ..removeWhere(
              (key, _) => op.convertedFromLegacyClear && key == 'createdAt',
            ),
          'anchor': groups[op.anchorGroupId],
          'appliedAfter': groups[op.appliedAfterGroupId],
          'groups': op.sourceGroups.map((id) => groups[id]).toList(),
          'dependencies': op.dependencies.map((id) => ordinals[id]).toList(),
        },
    ];
  }

  ContextOperation _legacyClearOperation(
    int boundary,
    List<String> groups,
    DateTime createdAt,
  ) {
    if (boundary <= 0 || boundary > groups.length) {
      throw StateError('context_boundary_missing');
    }
    return ContextOperation(
      id: const Uuid().v4(),
      kind: ContextOperationKind.clear,
      anchorGroupId: groups[boundary - 1],
      appliedAfterGroupId: groups[boundary - 1],
      sourceGroups: groups.take(boundary).toList(),
      dependencies: const [],
      createdAt: createdAt,
      convertedFromLegacyClear: true,
    );
  }

  Future<List<ContextOperation>> readContextOperations(String conversationId) =>
      _db.transaction(() async {
        final conversation = await (_db.select(
          _db.conversationRows,
        )..where((row) => row.id.equals(conversationId))).getSingleOrNull();
        if (conversation == null) return [];
        final record =
            await (_db.select(_db.extensionEntityRows)..where(
                  (row) =>
                      row.kind.equals(ContextOperation.entityKind) &
                      row.id.equals(conversationId),
                ))
                .getSingleOrNull();
        final operations = record == null
            ? <ContextOperation>[]
            : (jsonDecode(record.payload) as List)
                  .map(
                    (value) => ContextOperation.fromJson(
                      Map<String, dynamic>.from(value as Map),
                    ),
                  )
                  .toList();
        // Explicitly approved one-time conversion. Clearing this column and
        // saving the node share a transaction, including on backup imports.
        if (conversation.truncateIndex >= 0) {
          final index = conversation.truncateIndex;
          if (index > 0) {
            if (operations.isNotEmpty) {
              throw StateError('context_boundary_conflict');
            }
            final selected = await _contextMetadata(conversationId);
            operations.add(
              _legacyClearOperation(
                index,
                selected.map(ContextHistory.group).toList(),
                conversation.updatedAt,
              ),
            );
            await _writeContextOperations(conversationId, operations);
          }
          await (_db.update(_db.conversationRows)
                ..where((row) => row.id.equals(conversationId)))
              .write(const ConversationRowsCompanion(truncateIndex: Value(-1)));
        }
        return operations;
      });

  Future<void> _writeContextOperations(
    String id,
    List<ContextOperation> operations,
  ) async {
    await _db
        .into(_db.extensionEntityRows)
        .insertOnConflictUpdate(
          ExtensionEntityRowsCompanion.insert(
            kind: ContextOperation.entityKind,
            id: id,
            ownerId: Value(id),
            sortOrder: 0,
            payload: jsonEncode(operations.map((op) => op.toJson()).toList()),
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<List<ContextOperation>> appendContextOperation(
    String conversationId,
    ContextOperation operation, {
    required String expectedFingerprint,
  }) => _db.transaction(() async {
    if (await getConversation(conversationId) == null) {
      throw StateError('conversation_not_found');
    }
    final operations = await readContextOperations(conversationId);
    if (operations.any((op) => op.id == operation.id)) return operations;
    final selected = await getSelectedContextMessages(
      conversationId,
      limit: 0x7fffffff,
    );
    if (ContextHistory.fingerprint(selected, operations) !=
        expectedFingerprint) {
      throw StateError('context_changed');
    }
    final next = [...operations, operation];
    await _writeContextOperations(conversationId, next);
    // Commit the task outcome with the node so a crash cannot invite a second
    // compression after a successful application.
    final task =
        await (_db.select(_db.extensionEntityRows)..where(
              (r) =>
                  r.kind.equals('contextCompressionTask') &
                  r.id.equals(conversationId),
            ))
            .getSingleOrNull();
    if (task != null) {
      final value = Map<String, dynamic>.from(jsonDecode(task.payload) as Map);
      if (value['id'] == operation.id) {
        value['phase'] = 'completed';
        await saveCompressionTask(conversationId, value);
      }
    }
    return next;
  });

  Future<List<ContextOperation>> changeContextOperation(
    String conversationId,
    String operationId, {
    String? summary,
    required bool includeDependents,
    required String expectedState,
  }) => _db.transaction(() async {
    final operations = await readContextOperations(conversationId);
    if (ContextHistory.operationsFingerprint(operations) != expectedState) {
      throw StateError('context_changed');
    }
    final target = operations.firstWhere((op) => op.id == operationId);
    if (target.revoked) throw StateError('context_changed');
    if (summary != null && (!target.isCompression || summary.trim().isEmpty)) {
      throw ArgumentError('empty_summary');
    }
    final affected = ContextHistory.affectedOperations(
      operations,
      operationIds: {operationId},
    );
    if (!includeDependents && affected.length > 1) {
      throw StateError('context_dependents');
    }
    final next = [
      for (final op in operations)
        if (op.id == operationId && summary != null)
          op.copyWith(summary: summary)
        else if (affected.contains(op.id))
          op.copyWith(revoked: true)
        else
          op,
    ];
    await _writeContextOperations(conversationId, next);
    return next;
  });

  Future<Conversation> createCompressedConversation(
    String sourceId,
    ContextOperation operation, {
    required String expectedFingerprint,
    required List<ChatMessage> retained,
  }) async {
    // Copy the newest accepted UI state before entering the shared writer.
    // Nested message writes and their publications must use this same owner.
    await genUiStates.flush();
    return _writeTransaction(() async {
      final snapshot = await readContextSnapshot(sourceId);
      if (snapshot.fingerprint != expectedFingerprint) {
        throw StateError('context_changed');
      }
      final source = await getConversation(sourceId);
      if (source == null) throw StateError('conversation_not_found');
      final id = const Uuid().v4();
      final now = DateTime.now();
      final target = Conversation(
        id: id,
        title: source.title,
        assistantId: source.assistantId,
        createdAt: now,
        updatedAt: now,
        chatModelProvider: source.chatModelProvider,
        chatModelId: source.chatModelId,
        mcpServerIds: source.mcpServerIds,
        extras: ToolPermissionMode.withoutGrant(source.extras),
      );
      final summary = ChatMessage(
        role: 'user',
        content: operation.summary,
        conversationId: id,
      );
      await _appendLinearMessageToConversation(
        conversation: target,
        message: summary,
        selectVersion: false,
        touchUpdatedAt: true,
      );
      final retainedIds = [
        for (final m in retained)
          if (!ContextOperation.isSummary(m)) m.id,
      ];
      final rows =
          await (_db.select(_db.messageRows)..where(
                (r) =>
                    r.conversationId.equals(sourceId) & r.id.isIn(retainedIds),
              ))
              .get();
      final byId = {for (final row in rows) row.id: row};
      if (byId.length != retainedIds.length) {
        throw StateError('context_changed');
      }
      final ordered = [
        for (var i = 0; i < retained.length; i++)
          if (!ContextOperation.isSummary(retained[i]))
            byId[retained[i].id]!.copyWith(messageOrder: i + 1),
      ];
      for (var i = 0; i < retained.length; i++) {
        if (ContextOperation.isSummary(retained[i])) {
          final background = ChatMessage(
            role: 'user',
            content: retained[i].content,
            conversationId: id,
          );
          await _db
              .into(_db.messageRows)
              .insert(_messageCompanion(background, i + 1));
          await _replaceMessageParts(background);
        }
      }
      final ids = {for (final row in ordered) row.id: const Uuid().v4()};
      await _copyMessageRowsInto(
        targetConversationId: id,
        messages: ordered,
        messageIdMap: ids,
        groupIdMap: {
          for (final row in ordered) row.groupId ?? row.id: ids[row.id]!,
        },
        resetVersions: true,
      );
      final task =
          await (_db.select(_db.extensionEntityRows)..where(
                (r) =>
                    r.kind.equals('contextCompressionTask') &
                    r.id.equals(sourceId),
              ))
              .getSingleOrNull();
      if (task != null) {
        final value = Map<String, dynamic>.from(
          jsonDecode(task.payload) as Map,
        );
        // Continuing from an installed summary leaves its original task alone.
        if (value['id'] == operation.id &&
            !snapshot.operations.any((op) => op.id == operation.id)) {
          value['phase'] = 'completed';
          value['resultConversationId'] = id;
          await saveCompressionTask(sourceId, value);
        }
      }
      return (await getConversation(id))!;
    });
  }

  Future<void> restoreContextOperations(
    String id,
    List<ContextOperation> operations, {
    required String expectedFingerprint,
  }) => _db.transaction(() async {
    if ((await readContextSnapshot(id)).fingerprint != expectedFingerprint) {
      throw StateError('context_changed');
    }
    await _writeContextOperations(id, operations);
  });

  Future<void> _assertContextState(String id, String? expected) async {
    if (expected == null) return;
    final operations = await readContextOperations(id);
    if (ContextHistory.operationsFingerprint(operations) != expected) {
      throw StateError('context_changed');
    }
  }

  /// Called inside the same transaction as the actual source mutation.
  Future<void> _revokeContextForGroups(
    String id,
    Set<String> groups, {
    Set<String> removedGroups = const {},
  }) async {
    final operations = await readContextOperations(id);
    if (operations.isEmpty) return;
    final affected = ContextHistory.affectedOperations(
      operations,
      changedGroups: groups,
      removedGroups: removedGroups,
    );
    if (affected.isEmpty) return;
    await _writeContextOperations(id, [
      for (final op in operations)
        affected.contains(op.id) ? op.copyWith(revoked: true) : op,
    ]);
  }

  Future<void> _copyContextOperations({
    required String sourceId,
    required String targetId,
    required Map<String, String> groups,
    String? sourcePayload,
    bool completeHistory = false,
  }) async {
    final source = sourcePayload == null
        ? await readContextOperations(sourceId)
        : (jsonDecode(sourcePayload) as List)
              .map(
                (value) => ContextOperation.fromJson(
                  Map<String, dynamic>.from(value as Map),
                ),
              )
              .toList();
    final remappedGroups = Map<String, String>.of(groups);
    if (completeHistory) {
      for (final op in source) {
        for (final group in {
          op.anchorGroupId,
          op.appliedAfterGroupId,
          ...op.sourceGroups,
        }) {
          if (!remappedGroups.containsKey(group)) {
            if (!op.revoked) throw StateError('context_boundary_missing');
            remappedGroups[group] = const Uuid().v4();
          }
        }
      }
    }
    final kept = <ContextOperation>[];
    for (final op in source) {
      if (remappedGroups.containsKey(op.anchorGroupId) &&
          remappedGroups.containsKey(op.appliedAfterGroupId) &&
          op.sourceGroups.every(remappedGroups.containsKey) &&
          op.dependencies.every((id) => kept.any((other) => other.id == id))) {
        kept.add(op);
      }
    }
    if (kept.isEmpty) return;
    final ids = {for (final op in kept) op.id: const Uuid().v4()};
    await _writeContextOperations(
      targetId,
      kept
          .map((op) => op.remap(groups: remappedGroups, operations: ids))
          .toList(),
    );
  }
}
