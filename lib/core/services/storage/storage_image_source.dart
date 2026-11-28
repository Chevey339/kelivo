import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../../../shared/markdown/markdown_image_sources.dart';
import '../../../shared/markdown/tool_result_images.dart'
    show parseToolResultImages;
import '../../../utils/app_directories.dart';
import '../../../utils/kelivo_file_uri.dart';
import '../../../utils/mcp_structured_image.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../database/app_database.dart';
import '../../database/message_timeline_index.dart';
import '../../models/message_part.dart';
import 'attachment_file_lock.dart';

typedef StorageImageSource = ({String? messageId, bool busy});
typedef _Cursor = ({int order, int ordinal});
typedef _Page = ({_Cursor? next, StorageImageSource result});
const _missing = (messageId: null, busy: false);
const _busy = (messageId: null, busy: true);

/// Look up just the first visible use in the chat chosen by the user. Each
/// worker closes its read snapshot before the next page can be requested.
Future<StorageImageSource> findStorageImageSource({
  required String path,
  required String conversationId,
  required bool Function() isCurrent,
}) async {
  final root = (await AppDirectories.getContentDirectory()).path;
  final databasePath = p.join(
    (await AppDirectories.getAppDataDirectory()).path,
    AppDatabase.databaseFileName,
  );
  var cursor = (order: -1, ordinal: -1);
  while (isCurrent()) {
    if (AttachmentFileLock.hasActiveTransientGeneration) return _busy;
    final page = await compute(_readPage, (
      path: path,
      root: root,
      database: databasePath,
      chat: conversationId,
      cursor: cursor,
    ), debugLabel: 'Storage image source');
    if (!isCurrent()) return _missing;
    if (AttachmentFileLock.hasActiveTransientGeneration) return _busy;
    if (page.next == null) return page.result;
    cursor = page.next!;
  }
  return _missing;
}

_Page _readPage(
  ({String path, String root, String database, String chat, _Cursor cursor})
  args,
) {
  const limit = 1024;
  final db = sqlite3.open(args.database, mode: OpenMode.readOnly);
  try {
    bool generating() => db
        .select('SELECT 1 FROM message_rows WHERE is_streaming=1 LIMIT 1')
        .isNotEmpty;
    db.execute('BEGIN');
    if (generating()) return (next: null, result: _busy);
    final statement = db.prepare("""
      SELECT m.id, COALESCE(m.group_id,m.id) AS group_id, m.message_order, p.ordinal, p.kind,
        CASE WHEN p.kind IN ('image','file','tool_call') OR
          (p.kind='text' AND (instr(p.payload,'[')>0 OR instr(p.payload,'<')>0))
          THEN p.payload END AS payload
      FROM message_rows m CROSS JOIN message_part_rows p
        ON p.revision_id=m.id AND p.ordinal > CASE WHEN m.message_order=?2 THEN ?3 ELSE -1 END
      WHERE m.conversation_id=?1 AND m.message_order>=?2 AND m.role IN ('user','assistant')
      ORDER BY m.message_order,p.ordinal LIMIT $limit
    """);
    var count = 0;
    var yielded = false;
    _Cursor? last;
    String? found;
    Map? selections;
    try {
      final rows = statement.selectCursor([
        args.chat,
        args.cursor.order,
        args.cursor.ordinal,
      ]);
      final clock = Stopwatch()..start();
      while (rows.moveNext()) {
        if (last != null && clock.elapsedMilliseconds >= 16) {
          yielded = true;
          break;
        }
        final row = rows.current;
        count++;
        last = (
          order: row['message_order'] as int,
          ordinal: row['ordinal'] as int,
        );
        final raw = row['payload'] as String?;
        if (raw == null ||
            !_usesImage(row['kind'] as String, raw, args.root, args.path)) {
          continue;
        }
        final group = row['group_id'] as String;
        selections ??=
            jsonDecode(
                  db.select(
                        'SELECT version_selections_json FROM conversation_rows WHERE id=?',
                        [args.chat],
                      ).single['version_selections_json']
                      as String,
                )
                as Map;
        // Use the timeline's exact selection rule, including its default to
        // the latest version. No timeline installation or backfill is needed.
        final active = db.select(
          'WITH g(conversation_id,group_id) AS (VALUES (?,?)), s(version) AS (VALUES (?)) '
          'SELECT ${MessageTimelineIndex.selectedRevision('g')} AS id FROM g,s',
          [args.chat, group, selections[group]],
        ).single['id'];
        if (active == row['id']) {
          found = active as String;
          break;
        }
      }
    } finally {
      statement.close();
    }
    db.execute('COMMIT');
    if (generating()) return (next: null, result: _busy);
    return (
      next: found == null && (yielded || count == limit) ? last : null,
      result: (messageId: found, busy: false),
    );
  } finally {
    db.close();
  }
}

/// Compare actual local destinations. Independent uploads can have identical
/// bytes or names. Looking up a reference never needs to read image pixels.
bool _usesImage(String kind, String raw, String root, String path) {
  bool matches(String uri) {
    if (KelivoFileUri.isKelivoFileUri(uri)) {
      final resolved = KelivoFileUri.resolveToAbsolute(uri, root: root);
      return resolved != null && p.equals(path, resolved);
    }
    if (p.isAbsolute(uri)) return p.equals(path, uri);
    final local = SandboxPathResolver.tryDecodeLocalFileUri(uri);
    return local != null && p.equals(path, local);
  }

  if (kind == 'text') {
    return markdownImageSources(raw, includeLinks: true).any(matches);
  }
  final Object? data;
  try {
    data = jsonDecode(raw);
  } on FormatException {
    return false;
  }
  if (data is! Map<String, dynamic>) return false;
  if (kind != 'tool_call') {
    final uri = data['uri'];
    return data['unavailable'] != true && uri is String && matches(uri);
  }
  final preview = browserPreviewImageFromToolEvent(data);
  if (preview != null && matches(preview)) return true;
  final metadata = data['metadata'];
  final typed = metadata is Map<String, dynamic>
      ? readMcpResultMetadata(metadata)
      : null;
  if (typed != null) return mcpResultImageUris(typed).any(matches);
  final content = data['content'];
  return content is String &&
      content.contains('![') &&
      parseToolResultImages(content).$2.any(matches);
}
