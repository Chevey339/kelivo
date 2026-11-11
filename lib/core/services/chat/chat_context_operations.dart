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
    final prompts = await _repo.getMessagePrompts(
      messages
          .where(
            (m) =>
                includeAttachmentsAndTools &&
                m.role == 'user' &&
                m.parts.any((p) => p is ImagePart || p is FilePart),
          )
          .map((m) => m.id),
    );
    final images = await RequestImageContext.collectHistory(
      messages,
      parseMarkdownImages: true,
      allowRemoteImages: true,
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
          final buffer = StringBuffer();
          final hasFrozen = frozen != null;
          if (hasFrozen) buffer.write(LogPayloadElider.elideDataUris(body));
          var quoteIndex = 0;
          var textOffset = 0;
          final thinking = message.role == 'assistant'
              ? ThinkingTagParser.parseWithRanges(
                  message.content,
                  protectedRanges: UiMessageSource.of(
                    message.parts,
                  ).protectedJoinedRanges,
                )
              : null;
          for (var ordinal = 0; ordinal < message.parts.length; ordinal++) {
            final part = message.parts[ordinal];
            if (part is TextPart) {
              if (!hasFrozen) {
                final count = quotePlaceholder.allMatches(part.text).length;
                final selectedQuotes = message.quotes
                    .skip(quoteIndex)
                    .take(count)
                    .toList();
                final visible = thinking == null
                    ? part.text
                    : ThinkingTagParser.visibleSlice(
                        message.content,
                        start: textOffset,
                        end: textOffset + part.text.length,
                        hiddenRanges: thinking.hiddenRanges,
                      );
                textOffset += part.text.length;
                final text = formatQuotedMessage(
                  visible,
                  selectedQuotes,
                  quoteMarker: (number) => quoteMarker(number + quoteIndex),
                );
                quoteIndex += count;
                buffer.write(LogPayloadElider.elideDataUris(text));
                for (final image in images.where(
                  (image) =>
                      image.identity.messageId == message.id &&
                      image.identity.slot.startsWith('markdown:') &&
                      image.partOrdinal == ordinal,
                )) {
                  buffer.write(
                    '\n[Image ${image.handle}; image content not summarized]\n',
                  );
                }
              }
            } else if (part is ToolCallPart) {
              if (!includeAttachmentsAndTools) {
                buffer.write('\n[Tool result omitted by the user]\n');
                continue;
              }
              try {
                final tool = jsonDecode(part.payloadJson);
                if (tool is! Map) throw const FormatException('tool');
                final result = toolResultContentForModel(
                  (tool['content'] ?? '').toString(),
                );
                buffer.write(
                  '\n[source tool:${message.id}:$ordinal; id=${tool['id']}; name=${tool['name']}; status=${tool['status'] ?? (tool['error'] == null ? 'completed' : 'error')}]\n',
                );
                if (tool['arguments'] != null) {
                  buffer.write(
                    'Arguments: ${LogPayloadElider.elideDataUris(jsonEncode(tool['arguments']))}\n',
                  );
                }
                buffer.write(LogPayloadElider.elideDataUris(result));
                if (tool['error'] != null) {
                  buffer.write('\nError: ${tool['error']}');
                }
                final imageUris = mcpResultImageUris(
                  readMcpResultMetadata(
                    (tool['metadata'] as Map?)?.cast<String, dynamic>(),
                  ),
                );
                for (var i = 0; i < imageUris.length; i++) {
                  buffer.write(
                    '\n[Image ${ContextImageIdentity(message.id, "tool:${tool['id'] ?? 'part:$ordinal'}", i).handle}; image content not summarized]\n',
                  );
                }
              } on FormatException {
                // Preserve malformed data for the summarizer, with its status.
                buffer.write(
                  '\n[Unreadable tool record $ordinal]\n${LogPayloadElider.elideDataUris(part.payloadJson)}',
                );
              }
            } else if (part is FilePart) {
              buffer.write(
                includeAttachmentsAndTools
                    ? '\n[Attachment: ${part.name}; only available text is included; binary content was not reread]\n'
                    : '\n[Attachment: ${part.name}; content omitted by the user]\n',
              );
            } else if (part is ImagePart) {
              buffer.write(
                '\n[Image ${ContextImageIdentity(message.id, 'part:$ordinal').handle}; image content not summarized]\n',
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
      final boundary = operations
          .where((op) => !op.revoked && (op.isClear || op.isFixedStart))
          .lastOrNull;
      final messages = _collapseTitleVersions(
        _messagesCache[id] ?? [],
        getVersionSelections(id),
      );
      _contextStartIndices[id] = boundary == null
          ? -1
          : messages.indexWhere(
                  (m) => ContextHistory.group(m) == boundary.anchorGroupId,
                ) +
                (boundary.isFixedStart ? 0 : 1);
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
    String? fingerprintThroughId,
    void Function()? checkBeforeCommit,
    Future<void> Function()? validateBeforeCommit,
  }) async {
    if (getConversation(id) == null) throw StateError('conversation_not_found');
    if (_temporaryConversationIds.contains(id) ||
        _draftConversations.containsKey(id)) {
      final snapshot = await loadContextSnapshot(id);
      if (ContextHistory.fingerprint(
            ContextHistory.throughMessage(
              snapshot.messages,
              fingerprintThroughId,
            ),
            snapshot.operations,
          ) !=
          expectedFingerprint) {
        throw StateError('context_changed');
      }
      await validateBeforeCommit?.call();
      checkBeforeCommit?.call();
      _contextOperations[id] = ContextHistory.appendOperation(
        snapshot.operations,
        operation,
      );
    } else {
      _contextOperations[id] = await _repo.appendContextOperation(
        id,
        operation,
        expectedFingerprint: expectedFingerprint,
        fingerprintThroughId: fingerprintThroughId,
        checkBeforeCommit: checkBeforeCommit,
        validateBeforeCommit: validateBeforeCommit,
      );
    }
    await loadContextOperations(id, refresh: true);
    _notifyContextChanged(id);
  }

  Future<ContextMessageCounts> loadContextMessageCounts(
    String id, {
    required int limit,
  }) async {
    if (!_initialized || getConversation(id) == null) {
      throw StateError('conversation_not_found');
    }
    await loadContextOperations(id);
    if (!_temporaryConversationIds.contains(id) &&
        !_draftConversations.containsKey(id)) {
      return _repo.getContextMessageCounts(id, limit: limit);
    }
    final snapshot = await loadContextSnapshot(id);
    if (limit <= 0) {
      return (stored: snapshot.messages.length, messages: 0, summaries: 0);
    }
    final effective = ContextHistory.resolve(
      snapshot.messages,
      snapshot.operations,
      limit: limit,
    );
    final summaries = effective.where(ContextOperation.isSummary).length;
    return (
      stored: snapshot.messages.length,
      messages: effective.length - summaries,
      summaries: summaries,
    );
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
      if (operations.any((op) => op.id == operationId && op.isImportedNative)) {
        throw StateError('native_compaction_originals_unavailable');
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
      if (summary != null &&
          operations.any((op) => op.id == operationId && op.isNative)) {
        throw StateError('native_compaction_read_only');
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
    if (summary == null) contextCompression.skipNextAutomaticTurn(id);
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
    Future<void> Function()? validateBeforeCommit,
    void Function()? checkBeforeCommit,
  }) async {
    if (_temporaryConversationIds.contains(id)) {
      await validateBeforeCommit?.call();
      checkBeforeCommit?.call();
      final snapshot = await loadContextSnapshot(id);
      if (snapshot.fingerprint != expectedFingerprint) {
        throw StateError('context_changed');
      }
      final source = getConversation(id)!;
      final sourceMessages = [
        ChatMessage(
          role: 'user',
          content: operation.summary,
          conversationId: id,
          modelId: operation.model,
        ),
        ...retained,
      ];
      return _forkSelectedMessages(
        title: source.title,
        assistantId: source.assistantId,
        activate: false,
        temporary: true,
        sourceMessages: sourceMessages,
        sourceExtras: Map<String, dynamic>.from(source.extras),
        sourceMcpServerIds: ConversationMcpSettings.isOverridden(source)
            ? List<String>.of(source.mcpServerIds)
            : null,
        activationOwner: _currentConversationId,
        beforePublish: (created) async {
          await validateBeforeCommit?.call();
          checkBeforeCommit?.call();
          _temporaryCompressionSettings[created.id] =
              await compressionOverrides(id);
          final target = await loadContextSnapshot(created.id);
          ContextOperation copySummary(int index) {
            final original = index == 0
                ? operation
                : snapshot.operations.firstWhere(
                    (op) => op.summaryMessageId == sourceMessages[index].id,
                  );
            final keep = countUserMessages(
              sourceMessages.skip(index + 1).toList(),
            );
            return index == 0 || original.isNative
                ? original.copiedTo(
                    target.messages[index],
                    sourceConversationId: id,
                    keepUserMessages: keep,
                  )
                : ContextOperation.forCopiedSummary(
                    target.messages[index],
                    keepUserMessages: keep,
                  );
          }

          await restoreContextOperations(created.id, [
            for (var i = 0; i < sourceMessages.length; i++)
              if (i == 0 || ContextOperation.isSummary(sourceMessages[i]))
                copySummary(i),
          ], expectedFingerprint: target.fingerprint);
          await setConversationModel(
            created.id,
            providerKey: source.chatModelProvider,
            modelId: source.chatModelId,
          );
          if ((await loadContextSnapshot(id)).fingerprint !=
              expectedFingerprint) {
            throw StateError('context_changed');
          }
        },
      );
    }
    final created = await _repo.createCompressedConversation(
      id,
      operation,
      expectedFingerprint: expectedFingerprint,
      retained: retained,
      validateBeforeCommit: validateBeforeCommit,
      checkBeforeCommit: checkBeforeCommit,
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

  /// Pins the inclusive history boundary to a message group, independently of
  /// compression and the assistant's rolling message-count limit.
  Future<void> setConversationContextStart(String id, String messageId) =>
      contextCompression.runContextChange(id, () async {
        final snapshot = await loadContextSnapshot(id);
        final message = snapshot.messages
            .where((message) => message.id == messageId)
            .firstOrNull;
        if (message == null) throw StateError('message_not_found');
        final group = ContextHistory.group(message);
        if (ContextHistory.fixedStart(snapshot.operations)?.anchorGroupId ==
            group) {
          return;
        }
        await appendContextOperation(
          id,
          ContextOperation(
            id: const Uuid().v4(),
            kind: ContextOperationKind.start,
            anchorGroupId: group,
            appliedAfterGroupId: group,
            sourceGroups: [group],
            dependencies: const [],
            createdAt: DateTime.now(),
          ),
          expectedFingerprint: snapshot.fingerprint,
        );
      });
}
