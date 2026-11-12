import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:markstream/markstream_core.dart';

import '../../../shared/markdown/markdown_image_sources.dart';

/// Rewrites references inside a copied data directory, before it becomes live.
/// External files and portable kelivo-file URIs keep their existing identity.
final class DataDirectoryPaths {
  DataDirectoryPaths(this.source, this.target);

  final String source;
  final String target;

  static const _providerFields = {
    'signature',
    'thoughtSignature',
    'thought_signature',
    'reasoningDetails',
    'reasoning_details',
    'encrypted_content',
  };

  String rewrite(String value) {
    if (value.startsWith('kelivo-file:')) return value;
    // Some preference values contain another serialized JSON document.
    if (value.startsWith('{') ||
        value.startsWith('[') ||
        value.startsWith('"')) {
      try {
        final decoded = jsonDecode(value);
        final next = jsonEncode(rewriteJson(decoded));
        return next == jsonEncode(decoded) ? value : next;
      } on FormatException {
        // Ordinary message text may also start with a brace.
      }
    }
    return _rewritePlain(_rewriteMarkdown(value));
  }

  String _rewritePlain(String value) {
    final windows = p.windows.isAbsolute(source);
    final variants = <String, String>{
      source: target,
      source.replaceAll('\\', '/'): target.replaceAll('\\', '/'),
      if (windows) source.replaceAll('/', r'\'): target.replaceAll('/', r'\'),
      Uri.directory(source, windows: windows).toString(): Uri.directory(
        target,
        windows: windows,
      ).toString(),
    };
    var result = value;
    // URI form first: a slash path must not consume part of a file: URI.
    for (final entry in variants.entries.toList().reversed) {
      final from = entry.key;
      final trailingSlash = from.endsWith('/');
      result = result.replaceAllMapped(
        RegExp(
          '(?<![a-zA-Z0-9_/\\\\])${RegExp.escape(from)}'
          '${trailingSlash ? '' : r'''(?=$|[/\\\s"'`)\]])'''}',
          caseSensitive: !windows,
        ),
        (_) => entry.value,
      );
    }
    return result;
  }

  String _rewriteMarkdown(String value) {
    if (!value.contains('[') && !value.contains('<')) return value;
    final document = MarkdownParser(
      inlineSyntaxes: const [LocalImagePathSyntax()],
    ).parse(value);
    final edits = <SourceSpan, String>{};
    void visit(MarkdownNode node) {
      final destination = switch (node) {
        LinkNode() => node.destination,
        ImageNode() => node.destination,
        ReferenceDefinitionNode() => node.destination,
        _ => null,
      };
      if (destination != null) {
        final rewritten = _rewritePlain(destination);
        if (rewritten != destination) {
          final replacement = switch (node) {
            LinkNode() => LinkNode(
              span: node.span,
              children: node.children,
              destination: rewritten,
              title: node.title,
              autolink: node.autolink,
            ),
            ImageNode() => ImageNode(
              span: node.span,
              children: node.children,
              destination: rewritten,
              title: node.title,
            ),
            ReferenceDefinitionNode() => ReferenceDefinitionNode(
              span: node.span,
              label: node.label,
              destination: rewritten,
              title: node.title,
            ),
            _ => throw StateError('unreachable_link_node'),
          };
          // Markstream escapes destinations and titles correctly, including
          // spaces and unmatched parentheses. Revisit nested image labels;
          // their destinations may also refer to the old root.
          edits[node.span] = _rewriteMarkdown(
            toMarkdown(replacement, source: value),
          );
          return;
        }
      }
      for (final child in node.children) {
        visit(child);
      }
    }

    visit(document);
    for (final definition in document.references.values) {
      visit(definition);
    }
    var result = value;
    final spans = edits.keys.toList()
      ..sort((a, b) => b.start.compareTo(a.start));
    for (final span in spans) {
      result = result.replaceRange(span.start, span.end, edits[span]!);
    }
    return result;
  }

  Object? rewriteJson(Object? value) => switch (value) {
    String() => rewrite(value),
    List() => value.map(rewriteJson).toList(),
    Map() => value.map(
      (key, item) => MapEntry(
        key,
        _providerFields.contains(key) ? item : rewriteJson(item),
      ),
    ),
    _ => value,
  };

  String _rewriteToolCall(String payload) {
    final Object? decoded;
    try {
      decoded = jsonDecode(payload);
    } on FormatException {
      return payload;
    }
    if (decoded is! Map) return payload;
    // Arguments are the historical provider call and may carry signatures.
    // Only results and client-owned previews should follow the relocated files.
    final rewritten = decoded.map(
      (key, value) => MapEntry(
        key,
        const {'arguments', 'args', 'input'}.contains(key) ||
                _providerFields.contains(key)
            ? value
            : rewriteJson(value),
      ),
    );
    return jsonEncode(rewritten);
  }

  Future<void> rewriteCopy(Directory directory) async {
    final sourcePath = source;
    final targetPath = target;
    final copyPath = directory.path;
    await Isolate.run(() {
      final rewriter = DataDirectoryPaths(sourcePath, targetPath);
      final file = File(p.join(copyPath, 'kelivo.db'));
      if (!file.existsSync()) {
        throw StateError('data_directory_database_missing');
      }
      final db = sqlite3.open(file.path, mode: OpenMode.readWrite);
      try {
        if (db.select('PRAGMA quick_check').single.values.single != 'ok') {
          throw StateError('data_directory_database_invalid');
        }
        db.execute('BEGIN IMMEDIATE');
        try {
          // Only app-owned payload/path columns. SQLite indexes and triggers
          // stay in charge of derived data; no schema or identity is changed.
          final tables = db.select(
            "SELECT name FROM sqlite_master WHERE type = 'table'",
          );
          for (final row in tables) {
            final table = row['name'] as String;
            if (!const {
              'message_part_rows',
              'message_rows',
              'conversation_rows',
              'asset_rows',
              'assistant_rows',
              'provider_rows',
              'mcp_server_rows',
              'preference_rows',
              'extension_entity_rows',
              'gen_ui_surface_state_rows',
              'chat_storage_meta_rows',
              'tts_service_rows',
            }.contains(table)) {
              continue;
            }
            final columns = db.select('PRAGMA table_info("$table")');
            for (final column in columns) {
              final name = column['name'] as String;
              if (!const {
                'payload',
                'extras_json',
                'value',
                'state_json',
                'path',
                'thumbnail_path',
              }.contains(name)) {
                continue;
              }
              var cursor = 0;
              // Signed reasoning and unknown provider blocks must survive
              // byte-for-byte. Only client-owned attachment/text/tool parts
              // contain file references that this relocation may change.
              final partFilter = table == 'message_part_rows'
                  ? " AND kind IN ('text', 'image', 'file', 'tool_call')"
                  : '';
              while (true) {
                final batch = db.select(
                  'SELECT rowid AS relocation_rowid, "$name" AS value '
                  '${table == 'message_part_rows' ? ', kind AS part_kind ' : ''}'
                  'FROM "$table" WHERE rowid > ?$partFilter ORDER BY rowid LIMIT 256',
                  [cursor],
                );
                if (batch.isEmpty) break;
                for (final item in batch) {
                  cursor = item['relocation_rowid'] as int;
                  final before = item['value'];
                  if (before is! String) continue;
                  final after =
                      table == 'message_part_rows' &&
                          item['part_kind'] == 'tool_call'
                      ? rewriter._rewriteToolCall(before)
                      : rewriter.rewrite(before);
                  if (before == after) continue;
                  db.execute(
                    'UPDATE "$table" SET "$name" = ? WHERE rowid = ?',
                    [after, cursor],
                  );
                }
              }
            }
          }
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
        db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
      } finally {
        db.close();
      }
      final browser = File(p.join(copyPath, 'browser', 'state.json'));
      if (browser.existsSync()) {
        final value = jsonDecode(browser.readAsStringSync());
        browser.writeAsStringSync(
          jsonEncode(rewriter.rewriteJson(value)),
          flush: true,
        );
      }
    });
  }
}
