part of 'chat_database_repository.dart';

extension ChatContextRepository on ChatDatabaseRepository {
  Future<ContextMutationState> readContextMutationState(String id) =>
      _db.transaction(() async {
        await _convertContextBoundary(id);
        return _contextIndex.read(id);
      });

  Future<void> _convertContextBoundary(String id) async {
    final row =
        await (_db.selectOnly(_db.conversationRows)
              ..addColumns([_db.conversationRows.truncateIndex])
              ..where(_db.conversationRows.id.equals(id)))
            .getSingleOrNull();
    if (row == null) throw StateError('conversation_not_found');
    // Preserve the existing atomic conversion before reading context records.
    if (row.read(_db.conversationRows.truncateIndex)! >= 0) {
      await readContextOperations(id);
    }
  }

  /// Select and bound list data on SQLite's worker before crossing to the UI.
  Future<ContextOperationPage> readContextOperationPage(
    String id, {
    required int offset,
    required int limit,
  }) => _db.transaction(() async {
    RangeError.checkNotNegative(offset, 'offset');
    RangeError.checkValueInInterval(limit, 1, 0x7fffffff, 'limit');
    await _convertContextBoundary(id);
    await _contextIndex.ensure(id);
    final rows = await _db
        .customSelect(
          r'''
WITH state AS MATERIALIZED (
  SELECT revision,metadata FROM context_operation_state WHERE conversation_id=?
), metadata AS MATERIALIZED (
  SELECT CAST(j.key AS INTEGER) AS ordinal, j.value
  FROM state, json_each(state.metadata) j
), page AS MATERIALIZED (
  SELECT ordinal, value,
    kelivo_timestamp_micros(json_extract(value,'$.createdAt')) AS timestamp
  FROM metadata ORDER BY timestamp DESC, ordinal DESC LIMIT ? OFFSET ?
)
SELECT s.revision, json_extract(p.value,'$.id') AS id,
  json_extract(p.value,'$.kind') AS kind,
  json_extract(p.value,'$.createdAt') AS created_at,
  json_extract(p.value,'$.revoked') AS revoked,
  COALESCE(json_type(e.payload,'$['||p.ordinal||'].compressionDetails.nativeCompaction')='object',0) AS native,
  COALESCE(json_extract(e.payload,'$['||p.ordinal||'].compressionDetails.nativeContextImported'),0) AS imported,
  substr(COALESCE(json_extract(e.payload,'$['||p.ordinal||'].summary'),''),1,240) AS preview,
  (SELECT json_array_length(metadata) FROM state) AS total,
  EXISTS(SELECT 1 FROM metadata n
    WHERE n.ordinal>p.ordinal AND NOT json_extract(n.value,'$.revoked')
    AND (json_extract(n.value,'$.kind')='start'
      OR (json_extract(n.value,'$.kind')='clear' AND EXISTS(
        SELECT 1 FROM json_each(n.value,'$.groups') g
        WHERE g.value=json_extract(p.value,'$.anchor'))))) AS hidden,
  EXISTS(SELECT 1 FROM metadata n, json_each(n.value,'$.dependencies') d
    WHERE NOT json_extract(n.value,'$.revoked')
    AND json_extract(p.value,'$.kind')='compress'
    AND d.value=json_extract(p.value,'$.id')) AS superseded
FROM state s LEFT JOIN page p ON 1
LEFT JOIN extension_entity_rows e ON e.kind=? AND e.id=?
ORDER BY p.timestamp DESC, p.ordinal DESC
''',
          variables: [
            Variable<String>(id),
            Variable<int>(limit),
            Variable<int>(offset),
            Variable<String>(ContextOperation.entityKind),
            Variable<String>(id),
          ],
        )
        .get();
    final items = rows
        .where((row) => row.readNullable<String>('id') != null)
        .toList();
    return (
      items: [
        for (final row in items)
          ContextOperationSummary(
            id: row.read<String>('id'),
            kind: ContextOperationKind.values.byName(row.read<String>('kind')),
            createdAt: DateTime.parse(row.read<String>('created_at')),
            revoked: row.read<int>('revoked') != 0,
            hidden: row.read<int>('hidden') != 0,
            superseded: row.read<int>('superseded') != 0,
            isNative: row.read<int>('native') != 0,
            isImportedNative:
                row.read<int>('native') != 0 && row.read<int>('imported') != 0,
            summaryPreview: row.read<int>('native') != 0
                ? ''
                : truncateHeadUtf16Safe(row.read<String>('preview'), 240),
          ),
      ],
      hasMore: offset + items.length < rows.first.read<int>('total'),
      revision: rows.first.read<String>('revision'),
    );
  });

  Future<ContextOperation?> readContextOperation(
    String id,
    String operationId,
  ) => _db.transaction(() async {
    await _convertContextBoundary(id);
    final row = await _db
        .customSelect(
          r'''SELECT j.value AS payload FROM extension_entity_rows e, json_each(e.payload) j
WHERE e.kind=? AND e.id=? AND json_extract(j.value,'$.id')=? LIMIT 1''',
          variables: [
            Variable<String>(ContextOperation.entityKind),
            Variable<String>(id),
            Variable<String>(operationId),
          ],
        )
        .getSingleOrNull();
    if (row == null) return null;
    return _decodeContextOperation(row.read<String>('payload'));
  });

  Future<({List<ChatMessage> messages, List<ContextOperation> operations})>
  readContextMutationPreview(String id, {required String expectedState}) =>
      _db.transaction(() async {
        await _assertContextState(id, expectedState);
        return (
          messages: await getSelectedContextMessages(id, limit: 0x7fffffff),
          operations: await readContextOperations(id),
        );
      });
  // Read only selection metadata for the excluded prefix. Large message parts
  // and provider artifacts are hydrated only for history actually being sent.
  Future<List<ContextMessageMetadata>> _contextMetadata(
    String id, {
    bool contentInfo = false,
  }) async {
    await _timelineIndex.ensureConversation(id);
    final rows = await _db
        .customSelect(
          '''SELECT g.group_id,m.id,m.role${contentInfo ? """,
              COALESCE(SUM(CASE WHEN p.kind='text' THEN kelivo_text_length(p.payload) ELSE 0 END),0) AS content_length,
              COALESCE(MAX(CASE WHEN p.kind IN ('text','image','file') THEN kelivo_has_context_content(p.kind,p.payload) ELSE 0 END),0) AS has_content,
              EXISTS(SELECT 1 FROM provider_artifact_rows a WHERE a.revision_id=m.id AND a.kind='openai_native_compaction') AS native
            """ : ''} FROM timeline_group_rows g '''
          'LEFT JOIN timeline_selection_rows s ON s.conversation_id=g.conversation_id AND s.group_id=g.group_id '
          'JOIN message_rows m ON m.id=${MessageTimelineIndex.selectedRevision('g')} '
          "${contentInfo ? 'LEFT JOIN message_part_rows p ON p.revision_id=m.id ' : ''}"
          'WHERE g.conversation_id=? '
          "${contentInfo ? 'GROUP BY g.group_id ' : ''}"
          'ORDER BY g.anchor_order,g.group_id',
          variables: [Variable<String>(id)],
        )
        .get();
    return [
      for (final row in rows)
        ContextMessageMetadata(
          id: row.read<String>('id'),
          groupId: row.read<String>('group_id'),
          role: row.read<String>('role'),
          contentLength: contentInfo ? row.read<int>('content_length') : 0,
          hasContent: contentInfo && row.read<int>('has_content') != 0,
          native: contentInfo && row.read<int>('native') != 0,
        ),
    ];
  }

  Future<CompressionHistory> readCompressionHistory(String id) =>
      _db.transaction(() async {
        final operations = await readContextOperations(id);
        return CompressionHistory(
          messages: await _contextMetadata(id, contentInfo: true),
          operations: operations,
        );
      });

  Future<({List<ChatMessage> messages, List<ContextOperation> operations})>
  readContextHistory(String id) => _db.transaction(
    () async => (
      operations: await readContextOperations(id),
      messages: await getSelectedContextMessages(id, limit: 0x7fffffff),
    ),
  );

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
      fingerprint: await _contextSnapshotFingerprint(messages, operations),
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
      final index = metadata.indexWhere((m) => m.groupId == throughGroup);
      if (includeFollowingAssistant &&
          target.role == 'user' &&
          index >= 0 &&
          index + 1 < metadata.length &&
          metadata[index + 1].role == 'assistant') {
        endGroup = metadata[index + 1].groupId;
      }
    }
    final projected = ContextHistory.project(
      metadata,
      operations,
      limit: limit,
      throughGroupId: throughGroup,
      endGroupId: endGroup,
    );
    final hydrated = await getMessagesByIds([
      for (final m in projected)
        if (!m.isSummary) m.id,
    ]);
    return ContextHistory.materialize(
      hydrated,
      operations,
      projected,
      conversationId: id,
    );
  });

  /// Counts the same projection used for sending without loading message bodies.
  Future<ContextMessageCounts> getContextMessageCounts(
    String id, {
    required int limit,
  }) => _db.transaction(() async {
    final operations = (await readContextMutationState(id)).operations;
    final metadata = await _contextMetadata(id);
    return _contextMessageCounts(metadata, operations, limit);
  });

  Future<int> contextBoundaryIndex(
    String id,
    List<ContextOperation> operations,
  ) => _db.transaction(() async {
    final boundary = operations
        .where((op) => !op.revoked && (op.isClear || op.isFixedStart))
        .lastOrNull;
    if (boundary == null) return -1;
    await _timelineIndex.ensureConversation(id);
    final anchor = await _db
        .customSelect(
          'SELECT anchor_order FROM timeline_group_rows WHERE conversation_id=? AND group_id=?',
          variables: [
            Variable<String>(id),
            Variable<String>(boundary.anchorGroupId),
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
            Variable<String>(boundary.anchorGroupId),
          ],
        )
        .getSingle();
    return count.read<int>('n') - (boundary.isFixedStart ? 1 : 0);
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
          ...op.remapSources({
              for (final (i, id)
                  in (op.compressionDetails['sourceRevisionIds'] as List? ??
                          const [])
                      .indexed)
                id as String: 'source:$i',
            }).toJson()
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
        final state = await _contextIndex.read(conversationId);
        final cached = _contextOperationCache;
        if (conversation.truncateIndex < 0 &&
            cached?.id == conversationId &&
            cached?.revision == state.revision) {
          return cached!.operations;
        }
        final record =
            await (_db.select(_db.extensionEntityRows)..where(
                  (row) =>
                      row.kind.equals(ContextOperation.entityKind) &
                      row.id.equals(conversationId),
                ))
                .getSingleOrNull();
        final operations = record == null
            ? <ContextOperation>[]
            : await _decodeContextOperations(record.payload);
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
                selected.map((m) => m.groupId).toList(),
                conversation.updatedAt,
              ),
            );
            await _writeContextOperations(conversationId, operations);
          }
          await (_db.update(_db.conversationRows)
                ..where((row) => row.id.equals(conversationId)))
              .write(const ConversationRowsCompanion(truncateIndex: Value(-1)));
        }
        final result = List<ContextOperation>.unmodifiable(operations);
        _contextOperationCache = (
          id: conversationId,
          revision: state.revision,
          operations: result,
        );
        return result;
      });

  Future<void> _writeContextOperations(
    String id,
    List<ContextOperation> operations,
  ) async {
    final payload = await _encodeContextOperations(operations);
    await _db
        .into(_db.extensionEntityRows)
        .insertOnConflictUpdate(
          ExtensionEntityRowsCompanion.insert(
            kind: ContextOperation.entityKind,
            id: id,
            ownerId: Value(id),
            sortOrder: 0,
            payload: payload,
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<List<ContextOperation>> appendContextOperation(
    String conversationId,
    ContextOperation operation, {
    required String expectedFingerprint,
    String? fingerprintThroughId,
    void Function()? checkBeforeCommit,
    Future<void> Function()? validateBeforeCommit,
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
    if (ContextHistory.fingerprint(
          ContextHistory.throughMessage(selected, fingerprintThroughId),
          operations,
        ) !=
        expectedFingerprint) {
      throw StateError('context_changed');
    }
    await validateBeforeCommit?.call();
    checkBeforeCommit?.call();
    final next = ContextHistory.appendOperation(operations, operation);
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
    checkBeforeCommit?.call();
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
    if (target.isImportedNative) {
      throw StateError('native_compaction_originals_unavailable');
    }
    if (summary != null &&
        (!target.isCompression || target.isNative || summary.trim().isEmpty)) {
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
    Future<void> Function()? validateBeforeCommit,
    void Function()? checkBeforeCommit,
  }) async {
    // Copy the newest accepted UI state before entering the shared writer.
    // Nested message writes and their publications must use this same owner.
    await genUiStates.flush();
    return _writeTransaction(() async {
      final snapshot = await readContextSnapshot(sourceId);
      if (snapshot.fingerprint != expectedFingerprint) {
        throw StateError('context_changed');
      }
      await validateBeforeCommit?.call();
      checkBeforeCommit?.call();
      final source = await getConversation(sourceId);
      if (source == null) throw StateError('conversation_not_found');
      final id = const Uuid().v4();
      final now = DateTime.now();
      final target = Conversation(
        id: id,
        title: await _nextForkTitle(source.title),
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
        modelId: operation.model,
      );
      final targetOperations = [
        operation.copiedTo(
          summary,
          sourceConversationId: sourceId,
          keepUserMessages: countUserMessages(retained),
        ),
      ];
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
          final retainedOperation = snapshot.operations.firstWhere(
            (op) => op.summaryMessageId == retained[i].id,
          );
          final background = ChatMessage(
            role: 'user',
            content: retained[i].content,
            conversationId: id,
            modelId: retainedOperation.model,
          );
          await _db
              .into(_db.messageRows)
              .insert(_messageCompanion(background, i + 1));
          await _replaceMessageParts(background);
          final keep = countUserMessages(retained.skip(i + 1).toList());
          targetOperations.add(
            retainedOperation.isNative
                ? retainedOperation.copiedTo(
                    background,
                    sourceConversationId: sourceId,
                    keepUserMessages: keep,
                  )
                : ContextOperation.forCopiedSummary(
                    background,
                    keepUserMessages: keep,
                  ),
          );
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
      await _copyImageContext(sourceId, id, ids);
      await compression.saveOverrides(
        id,
        await compression.overrides(sourceId),
      );
      await _writeContextOperations(id, targetOperations);
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
      checkBeforeCommit?.call();
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
    if ((await readContextMutationState(id)).revision != expected) {
      throw StateError('context_changed');
    }
  }

  /// Called inside the same transaction as the actual source mutation.
  Future<void> _revokeContextForGroups(
    String id,
    Set<String> groups, {
    Set<String> removedGroups = const {},
  }) async {
    final state = await readContextMutationState(id);
    if (state.operations.isEmpty) return;
    final affected = ContextHistory.affectedOperations(
      state.operations,
      changedGroups: groups,
      removedGroups: removedGroups,
    );
    if (affected.isEmpty) return;
    final operations = await readContextOperations(id);
    await _writeContextOperations(id, [
      for (final op in operations)
        affected.contains(op.id) ? op.copyWith(revoked: true) : op,
    ]);
  }

  Future<void> _copyContextOperations({
    required String sourceId,
    required String targetId,
    required Map<String, String> groups,
    Map<String, String> messages = const {},
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
          .map(
            (op) => op.remap(
              groups: remappedGroups,
              operations: ids,
              messages: messages,
            ),
          )
          .toList(),
    );
  }
}

Future<ContextOperation> _decodeContextOperation(String payload) => Isolate.run(
  () => ContextOperation.fromJson(jsonDecode(payload) as Map<String, dynamic>),
);

Future<List<ContextOperation>> _decodeContextOperations(String payload) =>
    Isolate.run(
      () => [
        for (final value in jsonDecode(payload) as List)
          ContextOperation.fromJson(Map<String, dynamic>.from(value as Map)),
      ],
    );

Future<String> _encodeContextOperations(List<ContextOperation> operations) =>
    Isolate.run(() => jsonEncode(operations.map((op) => op.toJson()).toList()));

Future<String> _contextSnapshotFingerprint(
  List<ChatMessage> messages,
  List<ContextOperation> operations,
) => Isolate.run(() => ContextHistory.fingerprint(messages, operations));

Future<ContextMessageCounts> _contextMessageCounts(
  List<ContextMessageMetadata> metadata,
  List<ContextOperationMetadata> operations,
  int limit,
) => Isolate.run(() {
  if (limit <= 0) {
    return (stored: metadata.length, messages: 0, summaries: 0);
  }
  final effective = ContextHistory.project(metadata, operations, limit: limit);
  final summaries = effective.where((m) => m.isSummary).length;
  return (
    stored: metadata.length,
    messages: effective.length - summaries,
    summaries: summaries,
  );
});
