part of 'chat_service.dart';

typedef ConversationContextSnapshot = ({
  List<ChatMessage> messages,
  List<ContextOperation> operations,
  String fingerprint,
});

extension ChatContextOperations on ChatService {
  Future<Map<String, Map<String, dynamic>>> readCompressionTaskRecords() =>
      _repo.readCompressionTasks();

  Future<void> saveCompressionTaskRecord(
    String id,
    Map<String, dynamic> record,
  ) async {
    if (!_initialized ||
        _temporaryConversationIds.contains(id) ||
        _draftConversations.containsKey(id)) {
      return;
    }
    await _repo.saveCompressionTask(id, record);
  }

  Future<List<ChatMessage>> messagesForCompression(
    List<ChatMessage> messages, {
    bool includeAttachmentsAndTools = true,
    required String Function(int) quoteMarker,
  }) async {
    if (!includeAttachmentsAndTools) return messages;
    final prompts = await _repo.getMessagePrompts(
      messages
          .where(
            (m) =>
                m.role == 'user' &&
                m.parts.any((p) => p is ImagePart || p is FilePart),
          )
          .map((m) => m.id),
    );
    return [
      for (final message in messages)
        (() {
          final frozen = prompts[message.id];
          var body = message.quotedContent(quoteMarker);
          if (frozen != null) {
            body = frozen.carriesMemorySnapshot
                ? MemoryBlockBuilder.splitInjectedPrefix(
                        frozen.payload,
                      )?.rest ??
                      body
                : frozen.payload;
          }
          final buffer = StringBuffer(LogPayloadElider.elideDataUris(body));
          for (final part in message.parts) {
            if (part is ToolCallPart) {
              try {
                final tool = jsonDecode(part.payloadJson);
                if (tool is! Map) continue;
                final result = toolResultContentForModel(
                  (tool['content'] ?? '').toString(),
                );
                buffer.write('\n[Tool: ${tool['name'] ?? 'unknown'}]\n');
                if (tool['arguments'] != null) {
                  buffer.write(
                    truncateHeadTailUtf16Safe(
                      LogPayloadElider.elide(jsonEncode(tool['arguments'])),
                      2000,
                      marker: '\n[…truncated…]\n',
                    ),
                  );
                  buffer.write('\n');
                }
                buffer.write(
                  truncateHeadTailUtf16Safe(
                    LogPayloadElider.elide(result),
                    8000,
                    marker: '\n[…truncated…]\n',
                  ),
                );
              } on FormatException {
                buffer.write('\n[Unreadable tool record]');
              }
            } else if (part is FilePart) {
              buffer.write(
                '\n[Attachment: ${part.name}; only available text above is included; binary content was not reread]',
              );
            } else if (part is ImagePart) {
              buffer.write(
                '\n[Image attachment; image content not summarized]',
              );
            }
          }
          return message.copyWith(content: buffer.toString(), quotes: const []);
        })(),
    ];
  }

  List<ContextOperation> contextOperationsFor(String conversationId) =>
      List.unmodifiable(_contextOperations[conversationId] ?? const []);

  Future<List<ContextOperation>> loadContextOperations(
    String id, {
    bool refresh = false,
  }) async {
    if (!_initialized) return [];
    if (!refresh &&
        _contextOperations.containsKey(id) &&
        _contextStateVersions[id] == contextRevision(id)) {
      return contextOperationsFor(id);
    }
    if (_temporaryConversationIds.contains(id) ||
        _draftConversations.containsKey(id)) {
      final operations = contextOperationsFor(id);
      final clear = operations
          .where((op) => !op.revoked && !op.isCompression)
          .lastOrNull;
      final messages = _collapseTitleVersions(
        _messagesCache[id] ?? [],
        getVersionSelections(id),
      );
      _contextStartIndices[id] = clear == null
          ? -1
          : messages.indexWhere(
                  (m) => ContextHistory.group(m) == clear.anchorGroupId,
                ) +
                1;
      _contextStateVersions[id] = contextRevision(id);
      return operations;
    }
    final revision = contextRevision(id);
    final operations = await _repo.readContextOperations(id);
    final boundary = await _repo.contextBoundaryIndex(id, operations);
    if (revision != contextRevision(id)) {
      return loadContextOperations(id, refresh: true);
    }
    _contextOperations[id] = operations;
    _contextStartIndices[id] = boundary;
    _contextStateVersions[id] = contextRevision(id);
    final conversation = _conversationsCache[id];
    if (conversation != null) conversation.truncateIndex = -1;
    return operations;
  }

  Future<ConversationContextSnapshot> loadContextSnapshot(String id) async {
    if (!_temporaryConversationIds.contains(id) &&
        !_draftConversations.containsKey(id)) {
      final snapshot = await _repo.readContextSnapshot(id);
      _conversationsCache[id]?.truncateIndex = -1;
      await _cacheMessageArtifacts(snapshot.messages);
      return snapshot;
    }
    final operations = await loadContextOperations(id);
    final messages = await loadRawSelectedContextMessages(
      id,
      limit: 0x7fffffff,
    );
    return (
      messages: messages,
      operations: operations,
      fingerprint: ContextHistory.fingerprint(messages, operations),
    );
  }

  Future<List<ChatMessage>> loadEffectiveContextMessages(
    String conversationId, {
    required int limit,
    String? throughRevisionId,
    bool includeFollowingAssistant = false,
  }) async {
    if (!_initialized || limit <= 0) return [];
    if (!_temporaryConversationIds.contains(conversationId) &&
        !_draftConversations.containsKey(conversationId)) {
      await loadContextOperations(conversationId);
      final messages = await _repo.getEffectiveContextMessages(
        conversationId,
        limit: limit,
        throughRevisionId: throughRevisionId,
        includeFollowingAssistant: includeFollowingAssistant,
      );
      await _cacheMessageArtifacts(
        messages.where((m) => !ContextOperation.isSummary(m)).toList(),
      );
      return messages;
    }
    final operations = await loadContextOperations(conversationId);
    final raw = await loadRawSelectedContextMessages(
      conversationId,
      limit: 0x7fffffff,
    );
    String? throughGroup;
    String? endGroup;
    if (throughRevisionId != null) {
      final target = (_messagesCache[conversationId] ?? [])
          .where((m) => m.id == throughRevisionId)
          .firstOrNull;
      if (target == null) return [];
      throughGroup = ContextHistory.group(target);
      endGroup = throughGroup;
      final index = raw.indexWhere(
        (m) => ContextHistory.group(m) == throughGroup,
      );
      if (includeFollowingAssistant &&
          target.role == 'user' &&
          index >= 0 &&
          index + 1 < raw.length &&
          raw[index + 1].role == 'assistant') {
        endGroup = ContextHistory.group(raw[index + 1]);
      }
    }
    return ContextHistory.resolve(
      raw,
      operations,
      limit: limit,
      throughGroupId: throughGroup,
      endGroupId: endGroup,
    );
  }

  Future<void> appendContextOperation(
    String id,
    ContextOperation operation, {
    required String expectedFingerprint,
  }) async {
    if (getConversation(id) == null) throw StateError('conversation_not_found');
    if (_temporaryConversationIds.contains(id) ||
        _draftConversations.containsKey(id)) {
      final snapshot = await loadContextSnapshot(id);
      if (snapshot.fingerprint != expectedFingerprint) {
        throw StateError('context_changed');
      }
      _contextOperations[id] = [...snapshot.operations, operation];
    } else {
      _contextOperations[id] = await _repo.appendContextOperation(
        id,
        operation,
        expectedFingerprint: expectedFingerprint,
      );
    }
    await loadContextOperations(id, refresh: true);
    _notifyContextChanged(id);
  }

  Future<void> changeContextOperation(
    String id,
    String operationId, {
    String? summary,
    required bool includeDependents,
    required String expectedState,
  }) => contextCompression.runContextChange(id, () async {
    if (_temporaryConversationIds.contains(id) ||
        _draftConversations.containsKey(id)) {
      final operations = contextOperationsFor(id);
      if (ContextHistory.operationsFingerprint(operations) != expectedState) {
        throw StateError('context_changed');
      }
      final affected = ContextHistory.affectedOperations(
        operations,
        operationIds: {operationId},
      );
      if (!includeDependents && affected.length > 1) {
        throw StateError('context_dependents');
      }
      if (summary != null && summary.trim().isEmpty) {
        throw ArgumentError('empty_summary');
      }
      _contextOperations[id] = [
        for (final op in operations)
          if (op.id == operationId && summary != null)
            op.copyWith(summary: summary)
          else if (affected.contains(op.id))
            op.copyWith(revoked: true)
          else
            op,
      ];
    } else {
      _contextOperations[id] = await _repo.changeContextOperation(
        id,
        operationId,
        summary: summary,
        includeDependents: includeDependents,
        expectedState: expectedState,
      );
    }
    await loadContextOperations(id, refresh: true);
    _notifyContextChanged(id);
  });

  Future<Conversation> continueFromContextSummary(
    String id,
    String operationId,
  ) async {
    final snapshot = await loadContextSnapshot(id);
    final operation = snapshot.operations
        .where((op) => op.id == operationId && op.isCompression && !op.revoked)
        .firstOrNull;
    if (operation == null) throw StateError('context_changed');
    final effective = ContextHistory.resolve(
      snapshot.messages,
      snapshot.operations,
    );
    final summaryIndex = effective.indexWhere(
      (message) => message.id == operation.summaryMessageId,
    );
    if (summaryIndex < 0) throw StateError('context_changed');
    return createCompressedConversation(
      id,
      operation,
      expectedFingerprint: snapshot.fingerprint,
      retained: effective.skip(summaryIndex + 1).toList(),
    );
  }

  Future<Conversation> createCompressedConversation(
    String id,
    ContextOperation operation, {
    required String expectedFingerprint,
    required List<ChatMessage> retained,
  }) async {
    if (_temporaryConversationIds.contains(id)) {
      if ((await loadContextSnapshot(id)).fingerprint != expectedFingerprint) {
        throw StateError('context_changed');
      }
      final source = getConversation(id)!;
      final created = await forkConversationFromMessages(
        title: source.title,
        assistantId: source.assistantId,
        activate: false,
        sourceMessages: [
          ChatMessage(
            role: 'user',
            content: operation.summary,
            conversationId: id,
          ),
          ...retained,
        ],
      );
      if ((await loadContextSnapshot(id)).fingerprint != expectedFingerprint) {
        await deleteConversation(created.id);
        throw StateError('context_changed');
      }
      return created;
    }
    final created = await _repo.createCompressedConversation(
      id,
      operation,
      expectedFingerprint: expectedFingerprint,
      retained: retained,
    );
    _conversationsCache[created.id] = created;
    _messageCounts[created.id] = created.messageIds.length;
    _messageOrderIds[created.id] = List.of(created.messageIds);
    _bumpConversationListRevision();
    _notifyContextChanged(created.id);
    return created;
  }

  Future<void> restoreContextOperations(
    String id,
    List<ContextOperation> operations, {
    required String expectedFingerprint,
  }) => contextCompression.runContextChange(id, () async {
    if (_temporaryConversationIds.contains(id) ||
        _draftConversations.containsKey(id)) {
      if ((await loadContextSnapshot(id)).fingerprint != expectedFingerprint) {
        throw StateError('context_changed');
      }
      _contextOperations[id] = operations;
    } else {
      await _repo.restoreContextOperations(
        id,
        operations,
        expectedFingerprint: expectedFingerprint,
      );
    }
    await loadContextOperations(id, refresh: true);
    _notifyContextChanged(id);
  });

  void _revokeTemporaryContext(
    String id,
    Set<String> groups, {
    String? expectedState,
    Set<String> removedGroups = const {},
  }) {
    final operations = contextOperationsFor(id);
    if (expectedState != null &&
        ContextHistory.operationsFingerprint(operations) != expectedState) {
      throw StateError('context_changed');
    }
    final affected = ContextHistory.affectedOperations(
      operations,
      changedGroups: groups,
      removedGroups: removedGroups,
    );
    _contextOperations[id] = [
      for (final op in operations)
        affected.contains(op.id) ? op.copyWith(revoked: true) : op,
    ];
  }

  Future<void> clearConversationContext(String id) =>
      contextCompression.runContextChange(id, () async {
        final snapshot = await loadContextSnapshot(id);
        if (snapshot.messages.isEmpty) return;
        final effective = ContextHistory.resolve(
          snapshot.messages,
          snapshot.operations,
        );
        if (effective.isEmpty) return;
        final tail = ContextHistory.group(snapshot.messages.last);
        await appendContextOperation(
          id,
          ContextOperation(
            id: const Uuid().v4(),
            kind: ContextOperationKind.clear,
            anchorGroupId: tail,
            appliedAfterGroupId: tail,
            sourceGroups: snapshot.messages.map(ContextHistory.group).toList(),
            dependencies: const [],
            createdAt: DateTime.now(),
          ),
          expectedFingerprint: snapshot.fingerprint,
        );
      });
}
