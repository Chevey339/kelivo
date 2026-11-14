import 'dart:convert';
import 'dart:io';

import 'context_log_models.dart';
import 'reverse_log_reader.dart';

/// Resume point for backward JSONL reads, at a complete line boundary.
class ContextLogTailCursor {
  const ContextLogTailCursor({this.position, this.snapshot});
  final LogFileSnapshot? snapshot;
  final int? position;
  bool get isExhausted => position != null && position! <= 0;
}

class ContextLogTailPage {
  const ContextLogTailPage({required this.snapshots, required this.cursor});
  final List<ContextLogSnapshot> snapshots;
  final ContextLogTailCursor cursor;
  bool get hasMore => !cursor.isExhausted;
}

class ContextLogTailReader {
  static const int defaultPageSize = 30;
  static const int defaultChunkSize = 128 * 1024;

  static Future<ContextLogTailPage> readPage({
    required File file,
    ContextLogTailCursor cursor = const ContextLogTailCursor(),
    int limit = defaultPageSize,
    int chunkSize = defaultChunkSize,
    int maxBytes = 256 * 1024,
  }) async {
    if (limit <= 0) {
      return ContextLogTailPage(snapshots: const [], cursor: cursor);
    }
    if (!await file.exists()) {
      return const ContextLogTailPage(
        snapshots: [],
        cursor: ContextLogTailCursor(position: 0),
      );
    }
    final reader = await ReverseLogReader.open(
      file,
      end: cursor.position,
      chunkSize: chunkSize,
      snapshot: cursor.snapshot,
    );
    try {
      final end = reader.position;
      final snapshots = <ContextLogSnapshot>[];
      while (reader.position > 0 &&
          snapshots.length < limit &&
          end - reader.position < maxBytes) {
        final line = await reader.readLine();
        if (line == null) break;
        try {
          final decoded = jsonDecode(
            utf8.decode(line.bytes, allowMalformed: true),
          );
          if (decoded is Map) {
            snapshots.add(
              ContextLogSnapshot.fromJson(Map<String, dynamic>.from(decoded)),
            );
          }
        } catch (_) {
          // A partial trailing write or malformed line does not hide older logs.
        }
      }
      return ContextLogTailPage(
        snapshots: snapshots,
        cursor: ContextLogTailCursor(
          position: reader.position,
          snapshot: reader.snapshot,
        ),
      );
    } finally {
      await reader.close();
    }
  }
}
