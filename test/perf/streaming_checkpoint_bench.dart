import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

// Explicit benchmark. SQL audit triggers count logical payload writes, not
// filesystem bytes or physical flash wear. Correctness has separate tests.
void main() {
  test('checkpoint write amplification', () async {
    final root = await Directory.systemTemp.createTemp('checkpoint-bench-');
    final file = File('${root.path}/chat.db');
    final repository = ChatDatabaseRepository.open(file: file);
    await repository.ensureReady();
    final message = ChatMessage(
      id: 'reply',
      role: 'assistant',
      conversationId: 'conversation',
      isStreaming: true,
      parts: [
        ReasoningPart(List.filled(65536, '思').join()),
        const TextPart(''),
      ],
    );
    await repository.putMigrationBatch(
      conversations: [
        Conversation(
          id: 'conversation',
          title: 'Bench',
          messageIds: const ['reply'],
        ),
      ],
      messages: [(message: message, messageOrder: 0)],
      toolEventsByMessageId: const {},
      geminiSignaturesByMessageId: const {},
    );
    final raw = sqlite.sqlite3.open(file.path);
    try {
      raw.execute(
        'CREATE TABLE part_write_audit(operation TEXT, bytes INTEGER)',
      );
      for (final operation in ['INSERT', 'UPDATE', 'DELETE']) {
        final value = operation == 'DELETE' ? 'old' : 'new';
        raw.execute('''CREATE TRIGGER audit_${operation.toLowerCase()}
          AFTER $operation ON message_part_rows BEGIN
          INSERT INTO part_write_audit VALUES('$operation', length(CAST($value.payload AS BLOB)));
          END''');
      }
      final watch = Stopwatch()..start();
      for (var i = 1; i <= 48; i++) {
        await repository.updateStreamingCheckpoint(
          message.copyWith(
            parts: [
              message.parts.first,
              TextPart(List.filled(i * 512, '文').join()),
            ],
          ),
          const [],
        );
      }
      watch.stop();
      final writes = raw.select(
        'SELECT operation, count(*) AS count, sum(bytes) AS bytes FROM part_write_audit GROUP BY operation',
      );
      // ignore: avoid_print
      print(
        'CHECKPOINT_BENCH ${jsonEncode({'elapsedUs': watch.elapsedMicroseconds, 'checkpoints': 48, 'writes': writes.map((r) => Map<String, Object?>.from(r)).toList()})}',
      );
    } finally {
      raw.close();
      await repository.close();
      await root.delete(recursive: true);
    }
  });
}
