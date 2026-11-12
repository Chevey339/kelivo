part of 'chat_database_repository.dart';

extension ChatImageContextRepository on ChatDatabaseRepository {
  Future<List<ChatMessage>> readImageContextHistory(
    String id, {
    String? throughMessageId,
  }) => _db.transaction(() async {
    final operations = await readContextOperations(id);
    final metadata = await _contextMetadata(id);
    final cutoff = throughMessageId == null
        ? metadata.length - 1
        : metadata.indexWhere((m) => m.id == throughMessageId);
    if (cutoff < 0) return <ChatMessage>[];
    final allowed = metadata.take(cutoff + 1).map((m) => m.id).toSet();
    final selected = ContextHistory.project(
      metadata,
      operations.where((op) => !op.isCompression).toList(),
    ).where((m) => allowed.contains(m.id)).toList();
    final byId = <String, List<MessagePart>>{};
    for (var start = 0; start < selected.length; start += 400) {
      final ids = selected.skip(start).take(400).map((m) => m.id).toList();
      final placeholders = List.filled(ids.length, '?').join(',');
      final rows = await _db
          .customSelect(
            "SELECT revision_id,ordinal,kind,payload FROM message_part_rows WHERE revision_id IN ($placeholders) "
            "AND (kind IN ('image','file') OR (kind='text' AND revision_id IN ("
            "SELECT revision_id FROM message_part_rows WHERE revision_id IN ($placeholders) AND kind='text' AND instr(payload,'![')>0)) "
            "OR (kind='tool_call' AND CASE WHEN json_valid(payload) THEN "
            r"json_array_length(json_extract(payload,'$.metadata.mcpResult.imageUris')) ELSE 0 END > 0)) ORDER BY ordinal",
            variables: [...ids, ...ids].map(Variable<String>.new).toList(),
          )
          .get();
      for (final row in rows) {
        final revision = row.read<String>('revision_id');
        final ordinal = row.read<int>('ordinal');
        final parts = byId.putIfAbsent(revision, () => []);
        while (parts.length <= ordinal) {
          parts.add(const TextPart(''));
        }
        parts[ordinal] = ChatDatabaseRepository._hydratePart(
          revisionId: revision,
          ordinal: ordinal,
          kind: row.read<String>('kind'),
          payload: row.read<String>('payload'),
        );
      }
    }
    return [
      for (final message in selected)
        ChatMessage(
          id: message.id,
          groupId: message.groupId,
          role: message.role,
          conversationId: id,
          parts: byId[message.id] ?? [],
        ),
    ];
  });

  Future<ImageContextSettings> readImageContextSettings(String id) async {
    final row =
        await (_db.select(_db.extensionEntityRows)..where(
              (r) =>
                  r.kind.equals(ImageContextSettings.entityKind) &
                  r.id.equals(id),
            ))
            .getSingleOrNull();
    return row == null
        ? const ImageContextSettings()
        : ImageContextSettings.fromJson(
            jsonDecode(row.payload) as Map<String, dynamic>,
          );
  }

  Future<void> saveImageContextSettings(
    String id,
    ImageContextSettings settings,
  ) => _db.transaction(() async {
    if (await (_db.select(
          _db.conversationRows,
        )..where((r) => r.id.equals(id))).getSingleOrNull() ==
        null) {
      return;
    }
    await _db
        .into(_db.extensionEntityRows)
        .insertOnConflictUpdate(
          ExtensionEntityRowsCompanion.insert(
            kind: ImageContextSettings.entityKind,
            id: id,
            ownerId: Value(id),
            sortOrder: 0,
            payload: jsonEncode(settings.toJson()),
            updatedAt: DateTime.now(),
          ),
        );
  });

  Future<Object> _imageContextFingerprint(
    String schema,
    String id,
    Map<String, String> messages,
  ) async {
    final row = await _db
        .customSelect(
          'SELECT payload FROM $schema.extension_entity_rows WHERE kind=? AND id=?',
          variables: [
            Variable<String>(ImageContextSettings.entityKind),
            Variable<String>(id),
          ],
        )
        .getSingleOrNull();
    final settings = row == null
        ? const ImageContextSettings()
        : ImageContextSettings.fromJson(
            jsonDecode(row.read<String>('payload')) as Map<String, dynamic>,
          );
    return settings.remap(messages).toJson();
  }

  Future<void> _copyImageContext(
    String source,
    String target,
    Map<String, String> messages, {
    String? payload,
  }) async {
    final settings = payload == null
        ? await readImageContextSettings(source)
        : ImageContextSettings.fromJson(
            jsonDecode(payload) as Map<String, dynamic>,
          );
    await saveImageContextSettings(target, settings.remap(messages));
  }
}
