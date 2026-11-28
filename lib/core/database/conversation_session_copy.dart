import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:markstream/markstream_core.dart' show SourceSpan;

import '../models/message_part.dart' show tryParseContentSplits;
import '../services/workspace/session_file_links.dart';
import '../../utils/app_directories.dart';
import '../../utils/sandbox_path_resolver.dart';
import '../services/storage/attachment_file_lock.dart';
import '../services/storage/storage_attachment_usage.dart';
import '../services/workspace/file_link_resolver.dart';
import '../services/workspace/workspace_file_coordinator.dart';
import '../services/workspace/workspace_session_sync.dart';
import 'app_database.dart';

/// Copies only files referenced by the rows actually retained by a fork. The
/// new directory is published before the database transaction commits.
final class ConversationSessionCopy {
  ConversationSessionCopy._(this.root, this.sourceId, this.targetId);

  final String root;
  final String sourceId;
  final String targetId;
  String get source => p.join(root, 'sessions', sourceId);
  String get target => p.join(root, 'sessions', targetId);
  bool _published = false;

  static Future<ConversationSessionCopy?> locate(
    File? database,
    String sourceId,
    String targetId,
  ) async {
    if (database == null ||
        sourceId.isEmpty ||
        sourceId == '.' ||
        sourceId == '..' ||
        sourceId.contains(RegExp(r'[/\\:\x00]'))) {
      return null;
    }
    final root = await AppDirectories.contentDirectoryFor(database.parent);
    return ConversationSessionCopy._(root.path, sourceId, targetId);
  }

  Future<T> protect<T>(Future<T> Function() write) =>
      AttachmentFileLock.synchronized(
        () => WorkspaceFileCoordinator.runAll([target], () async {
          try {
            return await write();
          } catch (_) {
            if (_published) await Directory(target).delete(recursive: true);
            rethrow;
          }
        }, sharedPaths: [source]),
      );

  Future<void> copyReferencedFiles(AppDatabase db) async {
    // Tools can create or remove a session while the fork is waiting. Missing
    // explicit links still acquire the new owner without creating directories.
    final canReadFiles =
        await FileSystemEntity.type(p.dirname(source), followLinks: false) ==
            FileSystemEntityType.directory &&
        await FileSystemEntity.type(source, followLinks: false) ==
            FileSystemEntityType.directory;
    Directory? staging;
    final shifts = <String, List<SessionTextShift>>{};
    Future<_SessionFileBatch> worker() async {
      if (canReadFiles) {
        staging ??= await Directory(p.dirname(target)).createTemp('.fork-');
      }
      return _SessionFileBatch(root, sourceId, targetId, staging?.path);
    }

    try {
      // The display body joins TextParts. A reference definition or even an
      // individual URI may straddle part boundaries.
      final bodies = await db
          .customSelect(
            r'''SELECT p.revision_id, m.role,
                    max(p.kind IN ('tool_call','reasoning','image')) AS has_steps,
                    CASE WHEN json_valid(m.reasoning_segments_json) THEN
                      CASE WHEN json_type(m.reasoning_segments_json, '$.contentSplits') = 'object' THEN
                        json_extract(m.reasoning_segments_json, '$.contentSplits') END END AS splits
               FROM message_part_rows p JOIN message_rows m ON m.id = p.revision_id
               WHERE p.conversation_id = ? GROUP BY p.revision_id
               HAVING sum(p.kind='text') > 1 OR max(CASE WHEN p.kind='text' THEN
                 p.payload LIKE '%kelivo%' OR instr(p.payload, '/chat/')>0 OR instr(p.payload, ?)>0 ELSE 0 END)''',
            variables: [
              Variable.withString(targetId),
              Variable.withString(sourceId),
            ],
          )
          .get();
      for (var start = 0; start < bodies.length; start += 32) {
        final grouped = <String, _BodyGroup>{
          for (final row in bodies.skip(start).take(32))
            row.read<String>('revision_id'): (
              structured:
                  row.read<String>('role') == 'assistant' &&
                  row.read<int>('has_steps') != 0,
              splits: row.readNullable<String>('splits'),
              parts: [],
            ),
        };
        final ids = grouped.keys;
        final placeholders = List.filled(ids.length, '?').join(',');
        final rows = await db
            .customSelect(
              "SELECT revision_id, ordinal, part_id, payload FROM message_part_rows "
              "WHERE kind = 'text' AND revision_id IN ($placeholders) ORDER BY revision_id, ordinal",
              variables: ids.map(Variable.withString).toList(),
            )
            .get();
        for (final row in rows) {
          grouped[row.read<String>('revision_id')]!.parts.add((
            id: row.read<int>('part_id'),
            ordinal: row.read<int>('ordinal'),
            text: row.read<String>('payload'),
          ));
        }
        final (edits, offsets) = await (await worker()).copyBodies(grouped);
        shifts.addAll(offsets);
        await _updateCopiedValues(
          db,
          'message_part_rows',
          'payload',
          'part_id',
          edits,
        );
      }
      // The translation is rendered as a separate Markdown body. Read both
      // it and the retained parts in bounded batches from the same snapshot.
      const columns = [
        (
          table: 'message_part_rows',
          id: 'part_id',
          value: 'payload',
          kind: 'kind',
          filter: "kind IN ('reasoning','tool_call','file','image')",
        ),
        (
          table: 'message_rows',
          id: 'rowid',
          value: 'translation',
          kind: "'translation'",
          filter: 'translation IS NOT NULL',
        ),
        (
          table: 'message_rows',
          id: 'rowid',
          value: 'reasoning_segments_json',
          kind: "'segments'",
          filter: 'reasoning_segments_json IS NOT NULL',
        ),
      ];
      for (final column in columns) {
        var after = 0;
        while (true) {
          final rows = await db
              .customSelect(
                'SELECT ${column.id} AS id, ${column.kind} AS kind, ${column.value} AS payload '
                'FROM ${column.table} WHERE conversation_id = ? AND ${column.id} > ? AND ${column.filter} '
                "AND (${column.value} LIKE '%kelivo%' OR instr(${column.value}, '/chat/') > 0 OR instr(${column.value}, ?) > 0) "
                'ORDER BY ${column.id} LIMIT 64',
                variables: [
                  Variable.withString(targetId),
                  Variable.withInt(after),
                  Variable.withString(sourceId),
                ],
              )
              .get();
          if (rows.isEmpty) break;
          final parts = [
            for (final row in rows)
              (
                id: row.read<int>('id'),
                kind: row.read<String>('kind'),
                payload: row.read<String>('payload'),
              ),
          ];
          final edits = await (await worker()).copy(parts);
          await _updateCopiedValues(
            db,
            column.table,
            column.value,
            column.id,
            edits,
          );
          after = parts.last.id;
        }
      }
      if (shifts.isNotEmpty) await _moveTextRanges(db, shifts);
      final staged = staging;
      if (staged != null && !await staged.list().isEmpty) {
        if (await FileSystemEntity.type(target, followLinks: false) !=
            FileSystemEntityType.notFound) {
          throw FileSystemException(
            'Conversation session already exists',
            target,
          );
        }
        await copySessionAttachmentIndex(Directory(source), staged);
        await staged.rename(target);
        _published = true;
        staging = null;
      }
    } finally {
      await staging?.delete(recursive: true);
    }
  }

  Future<void> _updateCopiedValues(
    AppDatabase db,
    String table,
    String column,
    String key,
    Map<int, String> edits,
  ) async {
    if (edits.isEmpty) return;
    await db.batch((batch) {
      for (final entry in edits.entries) {
        batch.customStatement('UPDATE $table SET $column = ? WHERE $key = ?', [
          entry.value,
          entry.key,
        ]);
      }
    });
  }

  // Imported conversation IDs can have a different length from a new UUID.
  // Quotes and timeline splits use UTF-16 offsets in the concatenated TextParts.
  Future<void> _moveTextRanges(
    AppDatabase db,
    Map<String, List<SessionTextShift>> byRevision,
  ) async {
    final messages = await db
        .customSelect(
          """SELECT id,extras_json,reasoning_segments_json FROM message_rows WHERE conversation_id=?
         AND (instr(extras_json,'"quotes"')>0 OR instr(reasoning_segments_json,'"contentSplits"')>0)""",
          variables: [Variable.withString(targetId)],
        )
        .get();
    for (final row in messages) {
      final id = row.read<String>('id');
      final extras = jsonDecode(row.read<String>('extras_json')) as Map;
      var quotesChanged = false;
      if (extras['quotes'] case final List quotes) {
        for (final quote in quotes.whereType<Map>()) {
          final changes = byRevision[quote['messageId']];
          if (changes == null || quote['hasSourceRange'] == false) continue;
          for (final key in ['start', 'end']) {
            if (quote[key] case final int offset) {
              quote[key] = _moveOffset(offset, changes);
              quotesChanged |= quote[key] != offset;
            }
          }
        }
      }
      if (quotesChanged) {
        await db.customStatement(
          'UPDATE message_rows SET extras_json=? WHERE id=?',
          [jsonEncode(extras), id],
        );
      }
      final changes = byRevision[id];
      final segments = row.readNullable<String>('reasoning_segments_json');
      if (changes == null ||
          segments == null ||
          !segments.contains('"contentSplits"')) {
        continue;
      }
      Object? decoded;
      try {
        decoded = jsonDecode(segments);
      } on FormatException {
        continue;
      }
      if (decoded case {'contentSplits': {'offsets': final List offsets}}) {
        for (var i = 0; i < offsets.length; i++) {
          if (offsets[i] case final int offset) {
            offsets[i] = _moveOffset(offset, changes);
          }
        }
        await db.customStatement(
          'UPDATE message_rows SET reasoning_segments_json=? WHERE id=?',
          [jsonEncode(decoded), id],
        );
      }
    }
  }

  static int _moveOffset(int offset, List<SessionTextShift> shifts) {
    var delta = 0;
    for (final shift in shifts) {
      if (offset <= shift.at) break;
      if (offset < shift.at + shift.before) {
        return shift.at + delta + math.min(offset - shift.at, shift.after);
      }
      delta += shift.after - shift.before;
    }
    return offset + delta;
  }
}

typedef _Part = ({int id, String kind, String payload});
typedef _BodyGroup = ({
  bool structured,
  String? splits,
  List<({int id, int ordinal, String text})> parts,
});

final class _SessionFileBatch {
  _SessionFileBatch(this.root, this.sourceId, this.targetId, this.staging);
  final String root, sourceId, targetId;
  final String? staging;
  late final source = p.join(root, 'sessions', sourceId);
  late final realSource = p.join(
    Directory(root).resolveSymbolicLinksSync(),
    'sessions',
    sourceId,
  );

  Future<(Map<int, String>, Map<String, List<SessionTextShift>>)> copyBodies(
    Map<String, _BodyGroup> groups,
  ) => Isolate.run(() {
    final edits = <int, String>{};
    final shifts = <String, List<SessionTextShift>>{};
    for (final group in groups.entries) {
      final parts = group.value.parts;
      final body = parts.map((part) => part.text).join();
      final offsets = <SessionTextShift>[];
      final sections = <SourceSpan>{};
      void addSections(Iterable<int> stops) {
        var start = 0;
        for (final end in [...stops, body.length]) {
          if (end > start) sections.add(SourceSpan(start, end));
          start = end;
        }
      }

      var length = 0;
      final boundaries = <int>[];
      for (var i = 0; i < parts.length; i++) {
        if (group.value.structured &&
            i > 0 &&
            parts[i].ordinal != parts[i - 1].ordinal + 1) {
          boundaries.add(length);
        }
        length += parts[i].text.length;
      }
      addSections(boundaries);
      // History can also be displayed using its persisted reasoning/tool
      // splits. Resolve both the stored text blocks and those displayed slices.
      if (group.value.splits case final String raw) {
        final historical = tryParseContentSplits(jsonDecode(raw));
        if (historical != null &&
            historical.offsets.every((at) => at <= body.length)) {
          addSections(historical.offsets);
        }
      }
      final copied = _text(body, lengthChanges: offsets, sections: sections);
      if (copied == body) continue;
      if (offsets.isNotEmpty) shifts[group.key] = offsets;
      var originalEnd = 0, start = 0;
      for (final part in parts) {
        originalEnd += part.text.length;
        final end = ConversationSessionCopy._moveOffset(originalEnd, offsets);
        final next = copied.substring(start, end);
        if (next != part.text) edits[part.id] = next;
        start = end;
      }
    }
    return (edits, shifts);
  });

  Future<Map<int, String>> copy(List<_Part> parts) => Isolate.run(() {
    final edits = <int, String>{};
    for (final part in parts) {
      final next = _part(part);
      if (next != part.payload) edits[part.id] = next;
    }
    return edits;
  });

  String _part(_Part part) {
    if (part.kind == 'translation' || part.kind == 'reasoning') {
      return _text(part.payload);
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(part.payload);
    } on FormatException {
      return part.payload;
    }
    if (part.kind == 'segments') {
      final segments = decoded is Map ? decoded['segments'] : decoded;
      var changed = false;
      if (segments is List) {
        for (final segment in segments.whereType<Map>()) {
          final original = segment['text'];
          if (original is! String) continue;
          final next = _text(original);
          if (next != original) {
            segment['text'] = next;
            changed = true;
          }
        }
      }
      return changed ? jsonEncode(decoded) : part.payload;
    }
    if (decoded is! Map<String, dynamic>) return part.payload;
    var changed = false;
    String visit(String value, {bool exact = false}) {
      final edit = exact ? _transferFile(value)?.edit : null;
      final next = !exact
          ? _text(value, tool: true)
          : edit == null
          ? value
          : value.replaceFirst(edit.from, edit.to);
      if (next != value) changed = true;
      return next;
    }

    if (part.kind == 'tool_call') {
      // The replayed provider blocks and original tool arguments are immutable.
      Object? walk(Object? value, [String? key]) => switch (value) {
        Map() => value.map(
          (k, v) => MapEntry(k, walk(v, k is String ? k : null)),
        ),
        List() => value.map((item) => walk(item, key)).toList(),
        String() => visit(
          value,
          exact: const {
            'link',
            'path',
            'uri',
            'url',
            'imageUris',
            'previewImage',
          }.contains(key),
        ),
        _ => value,
      };
      final content = decoded['content'];
      if (content is String) {
        Object? json;
        try {
          json = jsonDecode(content);
        } on FormatException {
          // Plain text tool output.
        }
        if (json is Map || json is List) {
          final result = walk(json);
          if (changed) decoded['content'] = jsonEncode(result);
        } else {
          decoded['content'] = visit(content);
        }
      }
      final metadata = decoded['metadata'];
      if (metadata is Map) {
        for (final field in const ['workspace', 'mcpResult', 'browser']) {
          if (metadata.containsKey(field)) {
            metadata[field] = walk(metadata[field]);
          }
        }
      }
    } else if (decoded['uri'] case final String uri) {
      decoded['uri'] = visit(uri, exact: true);
    }
    return changed ? jsonEncode(decoded) : part.payload;
  }

  String _text(
    String text, {
    bool tool = false,
    List<SessionTextShift>? lengthChanges,
    Set<SourceSpan>? sections,
  }) {
    if (!text.toLowerCase().contains('kelivo') &&
        !text.contains('/chat/') &&
        !text.contains(sourceId)) {
      return text;
    }
    // A whole native filename may contain unquoted spaces. A URI can carry
    // a query or fragment, so in tool prose it must be tokenized individually.
    final literal = text.trim();
    final whole =
        tool &&
            p.isAbsolute(literal) &&
            !literal.contains('\n') &&
            !literal.contains('\r')
        ? _transferFile(literal)
        : null;
    if (whole != null && whole.present) {
      final edit = whole.edit;
      return edit == null ? text : text.replaceFirst(edit.from, edit.to);
    }
    var result = rewriteSessionFileLinks(
      text,
      (uri) => _transferFile(uri)?.edit,
      toolOutput: tool,
      lengthChanges: lengthChanges,
      sections: sections,
    );
    // A missing whole native path may still contain unquoted spaces in the
    // app data directory. Keep its ownership independent of file existence.
    if (whole?.edit case final edit?) {
      result = result.replaceFirst(edit.from, edit.to);
    }
    return result;
  }

  ({bool present, SessionLinkEdit? edit})? _transferFile(String uri) {
    final path = resolveStorageSessionReference(uri, sourceId, root);
    final local = SandboxPathResolver.tryDecodeLocalFileUri(path) ?? path;
    if (!p.isAbsolute(local) || local.contains('\x00')) return null;
    final base = p.isWithin(source, local) ? source : realSource;
    if (!p.isWithin(base, local)) return null;
    final relative = p.relative(local, from: base);
    final link = KelivoLink.tryParse(uri);
    var present = false;
    if (staging != null &&
        relative != sessionAttachmentIndexName &&
        FileSystemEntity.typeSync(local) == FileSystemEntityType.file) {
      final file = File(local);
      final real = file.resolveSymbolicLinksSync();
      final folder = switch (link?.kind) {
        KelivoLinkKind.chatAttachment => 'attachments',
        KelivoLinkKind.chatOutput => 'outputs',
        KelivoLinkKind.temporaryFile => 'tmp',
        _ => null,
      };
      final allowed = folder == null
          ? realSource
          : Directory(p.join(source, folder)).resolveSymbolicLinksSync();
      if (p.isWithin(realSource, real) && p.isWithin(allowed, real)) {
        present = true;
        final dest = File(p.join(staging!, relative));
        if (!dest.existsSync()) {
          dest.parent.createSync(recursive: true);
          File(real).copySync(dest.path);
        }
      }
    }
    if (link?.conversationId == sourceId) {
      final address = uri.trim();
      final ownerEnd = address.indexOf('/', 'kelivo://chat/'.length);
      final prefix = address.substring(0, 'kelivo://chat/'.length);
      return (
        present: present,
        edit: (
          from: address.substring(0, ownerEnd + 1),
          to: '$prefix$targetId/',
        ),
      );
    }
    if (link != null || uri.startsWith('/chat/')) {
      return (present: present, edit: null);
    }
    // Retain the original path spelling, including file: escapes, the desktop
    // volume alias and query/fragment. Only the ownership component changes.
    final owner = RegExp(
      r'sessions([/\\]+)([^/\\]+)([/\\]+)',
      caseSensitive: !Platform.isWindows,
    );
    for (final match in owner.allMatches(uri)) {
      final prefix = uri.substring(0, match.end);
      final directory =
          SandboxPathResolver.tryDecodeLocalFileUri(prefix) ?? prefix;
      if (p.equals(base, directory)) {
        final before = prefix.substring(
          0,
          prefix.length - match[2]!.length - match[3]!.length,
        );
        return (
          present: present,
          edit: (from: prefix, to: '$before$targetId${match[3]}'),
        );
      }
    }
    return null;
  }
}
