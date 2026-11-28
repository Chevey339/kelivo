part of 'storage_attachment_usage.dart';

class ChatImageRemoval {
  const ChatImageRemoval(
    this.deleted,
    this.changedRevisions, {
    this.copiesPending = false,
    this.frozen = false,
  });
  static const retained = ChatImageRemoval(false, {});
  final bool deleted;
  final bool copiesPending;
  final bool frozen;
  final Set<String> changedRevisions;
}

/// Only called for one explicitly confirmed image, on the storage worker.
ChatImageRemoval removeStoredChatImage({
  required String root,
  required String databasePath,
  required String path,
  required int bytes,
  required DateTime modifiedAt,
  required Set<String> conversations,
  required TransientAttachmentSnapshot transient,
  required String deletedLabel,
}) {
  final file = File(path);
  if (transient.generationActive ||
      conversations.isEmpty ||
      !['upload', 'images'].any((dir) => p.isWithin(p.join(root, dir), path)) ||
      !File(databasePath).existsSync()) {
    return ChatImageRemoval.retained;
  }
  final expectedReal = p.join(
    Directory(root).resolveSymbolicLinksSync(),
    p.relative(path, from: root),
  );
  bool sameFile() {
    final stat = file.statSync();
    return stat.type == FileSystemEntityType.file &&
        stat.size == bytes &&
        stat.modified == modifiedAt &&
        p.equals(file.resolveSymbolicLinksSync(), expectedReal);
  }

  if (!sameFile()) return ChatImageRemoval.retained;
  final transientUsage = StorageAttachmentUsage._(root, _AttachmentReferences())
    ..includeConversations(transient.resolve());
  if (transientUsage.isInUse(path) || transientUsage.isInUse(expectedReal)) {
    return ChatImageRemoval.retained;
  }

  final db = sqlite3.open(databasePath, mode: OpenMode.readWrite);
  final changed = <String>{};
  try {
    db.execute('PRAGMA foreign_keys = ON');
    db.execute('PRAGMA busy_timeout = 5000');
    // Do the expensive reference scan on a read snapshot. Writers can proceed
    // under WAL. Recheck its version once we hold the writer lock.
    int version() =>
        db.select('PRAGMA data_version').single.values.first as int;
    if (!_finishImageRemoval(db, root)) return ChatImageRemoval.retained;
    db.execute('BEGIN');
    final before = version();
    final usage = StorageAttachmentUsage._(
      root,
      _readReferences(db, true, root),
    );
    final paths = {p.normalize(path), expectedReal};
    final owners = {
      for (final name in paths) ...usage.conversationsFor(name).keys,
    };
    if (usage._references.hasActiveGenerations ||
        paths.any(
          (name) =>
              usage._appearance.contains(name) ||
              usage._protected.contains(name),
        ) ||
        owners.isEmpty ||
        !conversations.containsAll(owners)) {
      return ChatImageRemoval.retained;
    }
    final compressing = db.select(
      r"SELECT 1 FROM extension_entity_rows WHERE kind='contextCompressionTask' AND id IN (SELECT value FROM json_each(?)) "
      r"AND json_extract(payload,'$.phase') IN ('waiting','preparing','summarizing','merging','review','applying') LIMIT 1",
      [jsonEncode(owners.toList())],
    );
    if (compressing.isNotEmpty) return ChatImageRemoval.retained;
    final matched = <String, bool>{};
    bool matches(String uri) {
      if (uri.startsWith('data:') ||
          uri.startsWith('http:') ||
          uri.startsWith('https:')) {
        return false;
      }
      return matched.putIfAbsent(
        uri,
        () => _paths(uri, root).any(
          (candidate) => paths.any((target) => p.equals(candidate, target)),
        ),
      );
    }

    final edits = <({int id, String revision, String kind, String payload})>[];
    final statement = db.prepare(
      'SELECT part_id, revision_id, kind, payload FROM message_part_rows '
      'WHERE conversation_id IN (SELECT value FROM json_each(?)) AND '
      "(kind IN ('image','file','tool_call') OR "
      "(kind='text' AND (instr(payload,'![')>0 OR instr(lower(payload),'<img')>0)))",
    );
    try {
      final rows = statement.selectCursor([jsonEncode(owners.toList())]);
      while (rows.moveNext()) {
        final row = rows.current;
        final part = _detachImage(
          row['kind'] as String,
          row['payload'] as String,
          matches,
          deletedLabel,
        );
        if (part != null) {
          edits.add((
            id: row['part_id'] as int,
            revision: row['revision_id'] as String,
            kind: part.kind,
            payload: part.encodePayload(),
          ));
        }
      }
    } finally {
      statement.close();
    }
    final revisions = {for (final edit in edits) edit.revision};
    if (_hasFrozenImageSource(db, owners, revisions, file)) {
      return const ChatImageRemoval(false, {}, frozen: true);
    }
    final assetEdits = _imageAssetEdits(db, root, matches);
    if (assetEdits == null) return ChatImageRemoval.retained;
    db.execute('COMMIT');
    db.execute('BEGIN IMMEDIATE');
    if (version() != before || !sameFile()) return ChatImageRemoval.retained;
    final token = const Uuid().v4();
    final stage = _imageRemovalStage(root, token);
    if (FileSystemEntity.typeSync(stage.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      return ChatImageRemoval.retained;
    }
    // If the process exits before the history transaction commits, recovery
    // restores this exact file. A committed removal only has bytes left to free.
    db.execute('INSERT INTO chat_storage_meta_rows(key,value) VALUES (?,?)', [
      ChatStorageMetaKeys.pendingImageRemoval,
      jsonEncode({'token': token, 'source': p.relative(path, from: root)}),
    ]);
    db.execute('COMMIT');
    db.execute('BEGIN IMMEDIATE');
    if (version() != before || !sameFile()) return ChatImageRemoval.retained;
    try {
      file.renameSync(stage.path);
    } on FileSystemException {
      return ChatImageRemoval.retained;
    }
    try {
      final now = DateTime.now().microsecondsSinceEpoch;
      for (final edit in edits) {
        db.execute(
          'UPDATE message_part_rows SET kind=?, payload=?, updated_at=max(updated_at,?) WHERE part_id=?',
          [edit.kind, edit.payload, now, edit.id],
        );
        changed.add(edit.revision);
      }
      if (changed.isNotEmpty) {
        final ids = jsonEncode(changed.toList());
        db.execute(
          'UPDATE message_rows SET updated_at=max(updated_at,?) WHERE id IN (SELECT value FROM json_each(?))',
          [now, ids],
        );
        db.execute(
          'INSERT OR IGNORE INTO asset_reference_dirty_rows(revision_id) SELECT value FROM json_each(?)',
          [ids],
        );
      }
      for (final edit in assetEdits) {
        if (edit.primary == null) {
          db.execute('DELETE FROM asset_rows WHERE id=?', [edit.id]);
        } else {
          db.execute(
            'UPDATE asset_rows SET path=?,extras_json=?,thumbnail_path=? WHERE id=?',
            [edit.primary, edit.extras, edit.thumbnail, edit.id],
          );
        }
      }
      db.execute(
        "INSERT INTO chat_storage_meta_rows(key,value) VALUES (?,json_array(?)) "
        "ON CONFLICT(key) DO UPDATE SET value=json_insert(value,'\$[#]',?)",
        [
          ChatStorageMetaKeys.pendingImageCopies,
          p.relative(path, from: root),
          p.relative(path, from: root),
        ],
      );
      db.execute('UPDATE chat_storage_meta_rows SET value=? WHERE key=?', [
        jsonEncode({'token': token}),
        ChatStorageMetaKeys.pendingImageRemoval,
      ]);
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      _finishImageRemoval(db, root);
      rethrow;
    }
    _finishImageRemoval(db, root);
    return ChatImageRemoval(true, changed);
  } finally {
    db.close();
  }
}

File _imageRemovalStage(String root, String token) =>
    File(p.join(root, '.kelivo-pending-chat-image-$token'));

Future<void> recoverStoredChatImageRemoval(String root) =>
    AttachmentFileLock.synchronized(() async {
      final path = p.join(
        (await AppDirectories.getAppDataDirectory()).path,
        AppDatabase.databaseFileName,
      );
      await Isolate.run(() {
        final db = sqlite3.open(path, mode: OpenMode.readWrite);
        try {
          db.execute('PRAGMA busy_timeout = 5000');
          _finishImageRemoval(db, root);
        } finally {
          db.close();
        }
      });
      await cleanRemovedChatImageCopies(root, path);
    });

/// The copy sweep is retryable after a failed directory read or an interrupted
/// run. It must not unlink new session copies if a source has been restored.
Future<bool> cleanRemovedChatImageCopies(
  String root,
  String databasePath,
) async {
  try {
    final sources = await Isolate.run(() {
      final db = sqlite3.open(databasePath, mode: OpenMode.readOnly);
      try {
        final rows = db.select(
          'SELECT value FROM chat_storage_meta_rows WHERE key=?',
          [ChatStorageMetaKeys.pendingImageCopies],
        );
        if (rows.isEmpty) return <String>{};
        return (jsonDecode(rows.single['value'] as String) as List)
            .cast<String>()
            .toSet();
      } finally {
        db.close();
      }
    });
    if (sources.isEmpty) return true;
    final missing = <String>{};
    for (final relative in sources) {
      final path = p.normalize(p.join(root, relative));
      if (!p.isAbsolute(relative) &&
          ['upload', 'images'].any((d) => p.isWithin(p.join(root, d), path)) &&
          await FileSystemEntity.type(path, followLinks: false) ==
              FileSystemEntityType.notFound) {
        missing.add(path);
      }
    }
    if (missing.isNotEmpty) {
      await deleteSessionAttachmentCopies(
        missing,
        sessionsDirectory: await AppDirectories.getSessionsDirectory(),
      );
    }
    await Isolate.run(() {
      final db = sqlite3.open(databasePath, mode: OpenMode.readWrite);
      try {
        db.execute('PRAGMA busy_timeout = 5000');
        db.execute('BEGIN IMMEDIATE');
        db.execute(
          'UPDATE chat_storage_meta_rows SET value=(SELECT json_group_array(value) FROM json_each(chat_storage_meta_rows.value) '
          'WHERE value NOT IN (SELECT value FROM json_each(?))) WHERE key=?',
          [
            jsonEncode(sources.toList()),
            ChatStorageMetaKeys.pendingImageCopies,
          ],
        );
        db.execute(
          "DELETE FROM chat_storage_meta_rows WHERE key=? AND value='[]'",
          [ChatStorageMetaKeys.pendingImageCopies],
        );
        db.execute('COMMIT');
      } finally {
        db.close();
      }
    });
    return true;
  } on Exception {
    // The original is already gone. Keep the receipt for asset maintenance.
    return false;
  }
}

/// Hold the writer lock while consuming a receipt, including across processes.
/// A changed or externally occupied destination is never overwritten.
bool _finishImageRemoval(Database db, String root) {
  db.execute('BEGIN IMMEDIATE');
  try {
    final rows = db.select(
      'SELECT value FROM chat_storage_meta_rows WHERE key=?',
      [ChatStorageMetaKeys.pendingImageRemoval],
    );
    if (rows.isEmpty) return true;
    final receipt = jsonDecode(rows.single['value'] as String) as Map;
    final token = receipt['token'];
    if (token is! String || !Uuid.isValidUUID(fromString: token)) return false;
    final source = receipt['source'] as String?;
    final stage = _imageRemovalStage(root, token);
    final type = FileSystemEntity.typeSync(stage.path, followLinks: false);
    if (type == FileSystemEntityType.file) {
      if (source == null) {
        stage.deleteSync();
      } else {
        final path = p.normalize(p.join(root, source));
        if (p.isAbsolute(source) ||
            ![
              'upload',
              'images',
            ].any((dir) => p.isWithin(p.join(root, dir), path)) ||
            FileSystemEntity.typeSync(path, followLinks: false) !=
                FileSystemEntityType.notFound ||
            !p.equals(
              Directory(p.dirname(path)).resolveSymbolicLinksSync(),
              p.join(
                Directory(root).resolveSymbolicLinksSync(),
                p.relative(p.dirname(path), from: root),
              ),
            )) {
          return false;
        }
        stage.renameSync(path);
      }
    } else if (type != FileSystemEntityType.notFound) {
      return false;
    }
    db.execute('DELETE FROM chat_storage_meta_rows WHERE key=?', [
      ChatStorageMetaKeys.pendingImageRemoval,
    ]);
    return true;
  } on FileSystemException {
    return false;
  } finally {
    db.execute('COMMIT');
  }
}

bool _hasFrozenImageSource(
  Database db,
  Set<String> owners,
  Set<String> revisions,
  File image,
) {
  if (revisions.isEmpty) return false;
  final groups = {
    for (final row in db.select(
      'SELECT coalesce(group_id,id) AS id FROM message_rows WHERE id IN (SELECT value FROM json_each(?))',
      [jsonEncode(revisions.toList())],
    ))
      row['id'] as String,
  };
  final names = jsonEncode(owners.toList());
  // An imported native summary retains the frozen wire but drops its original
  // group IDs. Compare actual pixels only when this provenance is ambiguous.
  String? encoded;
  bool hasPixels(Map<String, dynamic> wire) {
    final content = wire[nativeCompactionPartsField(wire)];
    if (content is! List) return false;
    for (final part in content) {
      if (part is! Map || part['type'] != 'input_image') continue;
      final url = part['image_url'];
      if (url is! String || !url.startsWith('data:')) continue;
      final comma = url.indexOf(',');
      if (comma < 0 ||
          url.length - comma - 1 != ((image.lengthSync() + 2) ~/ 3) * 4) {
        continue;
      }
      encoded ??= base64Encode(image.readAsBytesSync());
      if (url.startsWith(encoded!, comma + 1)) return true;
    }
    return false;
  }

  for (final row in db.select(
    r"SELECT e.payload FROM extension_entity_rows e WHERE e.kind=? AND (e.id IN (SELECT value FROM json_each(?)) OR "
    r"(instr(e.payload,'nativeSourceConversationId')>0 AND EXISTS(SELECT 1 FROM json_each(e.payload) op WHERE "
    r"json_extract(op.value,'$.compressionDetails.nativeSourceConversationId') IN (SELECT value FROM json_each(?)))))",
    [ContextOperation.entityKind, names, names],
  )) {
    final operations = [
      for (final raw in jsonDecode(row['payload'] as String) as List)
        ContextOperation.fromJson(raw as Map<String, dynamic>),
    ];
    final affected = ContextHistory.affectedOperations(
      operations,
      changedGroups: groups,
    );
    for (final op in operations) {
      if (op.revoked) continue;
      if (op.isNative && affected.contains(op.id)) return true;
      if (op.isImportedNative && op.nativePayload!.output.any(hasPixels)) {
        return true;
      }
      if (op.carried?.items.any(
            (item) =>
                revisions.contains(item.sourceMessageId) &&
                (item.imageHandles.isNotEmpty ||
                    (item.wire?['content'] is List &&
                        (item.wire!['content'] as List).any(
                          (part) =>
                              part is Map && part['type'] == 'input_image',
                        ))),
          ) ==
          true) {
        return true;
      }
    }
  }
  return false;
}

typedef _ImageAssetEdit = ({
  String id,
  String? primary,
  String? extras,
  String? thumbnail,
});
List<_ImageAssetEdit>? _imageAssetEdits(
  Database db,
  String root,
  bool Function(String) matches,
) {
  final edits = <_ImageAssetEdit>[];
  // Asset IDs identify content. Two independent upload paths may share one ID.
  final statement = db.prepare(
    'SELECT id,path,extras_json,thumbnail_path FROM asset_rows',
  );
  try {
    final rows = statement.selectCursor();
    while (rows.moveNext()) {
      final row = rows.current;
      final id = row['id'] as String;
      final path = row['path'] as String;
      final extras = jsonDecode(row['extras_json'] as String) as Map;
      final aliases = (extras['localPaths'] as List? ?? const [])
          .cast<String>();
      final remaining = aliases.where((uri) => !matches(uri)).toList();
      final primaryRemoved = matches(path);
      final thumbnail = row['thumbnail_path'] as String?;
      final thumbnailRemoved = thumbnail != null && matches(thumbnail);
      if (!primaryRemoved &&
          remaining.length == aliases.length &&
          !thumbnailRemoved) {
        continue;
      }
      if (primaryRemoved && remaining.isEmpty) {
        edits.add((id: id, primary: null, extras: null, thumbnail: null));
        continue;
      }
      var primary = path;
      if (primaryRemoved) {
        final replacement = remaining.indexWhere(
          (uri) => _paths(uri, root).any(
            (alias) =>
                FileSystemEntity.typeSync(alias, followLinks: false) ==
                FileSystemEntityType.file,
          ),
        );
        if (replacement < 0) return null;
        primary = remaining.removeAt(replacement);
      }
      if (remaining.isEmpty) {
        extras.remove('localPaths');
      } else {
        extras['localPaths'] = remaining;
      }
      edits.add((
        id: id,
        primary: primary,
        extras: jsonEncode(extras),
        thumbnail: thumbnailRemoved ? null : thumbnail,
      ));
    }
  } finally {
    statement.close();
  }
  return edits;
}

MessagePart? _detachImage(
  String kind,
  String payload,
  bool Function(String) matches,
  String deletedLabel,
) {
  if (kind == 'text') {
    final text = _removeMarkdownImage(payload, matches, deletedLabel);
    return text == payload ? null : TextPart(text);
  }
  if (kind == 'image' || kind == 'file') {
    final part = jsonDecode(payload);
    return part is Map &&
            part['uri'] is String &&
            matches(part['uri'] as String)
        ? ImagePart.deleted
        : null;
  }
  // A tool's arguments and provider-signed history describe the original call.
  // Only the client-owned image results and their displayed Markdown change.
  final Object? event;
  try {
    event = jsonDecode(payload);
  } on FormatException {
    return null;
  }
  if (event is! Map) return null;
  var changed = false;
  final metadata = event['metadata'];
  if (metadata is Map) {
    final result = metadata['mcpResult'];
    if (result is Map && result['imageUris'] is List) {
      final images = result['imageUris'] as List;
      for (var i = 0; i < images.length; i++) {
        if (images[i] is String && matches(images[i] as String)) {
          // Preserve ordinals used by other images' pins and exclusions.
          images[i] = ImagePart.deleted.uri;
          changed = true;
        }
      }
    }
    final preview = browserPreviewImageFromToolEvent(event);
    if (preview != null && matches(preview)) {
      (metadata['browser'] as Map).remove('previewImage');
      changed = true;
    }
  }
  if (event['content'] case final String content) {
    final next = _removeMarkdownImage(content, matches, deletedLabel);
    if (next != content) {
      event['content'] = next;
      changed = true;
    }
  }
  return changed ? ToolCallPart(jsonEncode(event)) : null;
}

String _removeMarkdownImage(
  String text,
  bool Function(String) matches,
  String label,
) {
  if (!text.contains('![') && !text.toLowerCase().contains('<img')) return text;
  final document = MarkdownParser(
    inlineSyntaxes: const [LocalImagePathSyntax()],
  ).parse(text);
  final spans = <SourceSpan>[];
  void visit(MarkdownNode node) {
    final uri = switch (node) {
      ImageNode(:final destination) => destination,
      HtmlElementNode(tag: 'img', :final attributes) => attributes['src'],
      _ => null,
    };
    if (uri != null && matches(uri)) {
      spans.add(node.span);
      return;
    }
    for (final child in node.children) {
      visit(child);
    }
  }

  visit(document);
  for (final span in spans.reversed) {
    text = text.replaceRange(span.start, span.end, label);
  }
  return text;
}
