import 'dart:io';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

// Run on a native target with --release or --profile. JIT tests do not expose
// the unsafe AOT field hoisting that caused the Windows crash in #1342.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AOT persists messages with and without a checkpoint baseline', (
    tester,
  ) async {
    expect(
      kReleaseMode || kProfileMode,
      isTrue,
      reason: 'This regression requires a native --release or --profile run.',
    );
    final directory = await Directory.systemTemp.createTemp(
      'kelivo_message_persistence_aot_',
    );
    final file = File('${directory.path}/chat.sqlite');
    final repository = ChatDatabaseRepository.open(file: file);
    addTearDown(() async {
      await repository.close();
      await directory.delete(recursive: true);
    });
    await repository.ensureReady();

    final timestamp = DateTime.utc(2026, 11, 2);
    var conversation = Conversation(id: 'aot', title: 'AOT regression');
    final user = ChatMessage(
      id: 'question',
      role: 'user',
      conversationId: conversation.id,
      timestamp: timestamp,
      parts: const [TextPart('question')],
    );
    conversation = (await repository.appendLinearMessageToConversation(
      conversation: conversation,
      message: user,
    )).conversation;
    expect((await repository.getMessage(user.id))!.content, 'question');

    final assistant = ChatMessage(
      id: 'answer',
      role: 'assistant',
      conversationId: conversation.id,
      timestamp: timestamp,
      parts: const [],
      isStreaming: true,
    );
    await repository.appendLinearMessageToConversation(
      conversation: conversation,
      message: assistant,
    );
    final emptyAssistant = (await repository.getMessage(assistant.id))!;
    expect(emptyAssistant.content, isEmpty);
    expect(emptyAssistant.isStreaming, isTrue);

    var checkpoint = assistant.copyWith(
      parts: const [ReasoningPart('plan'), TextPart('first')],
    );
    await repository.updateStreamingCheckpoint(checkpoint, const []);

    final raw = sqlite.sqlite3.open(file.path);
    try {
      raw.execute('CREATE TABLE part_attempts (ordinal INTEGER)');
      raw.execute(
        'CREATE TRIGGER audit_parts BEFORE INSERT ON message_part_rows '
        'BEGIN INSERT INTO part_attempts VALUES (NEW.ordinal); END',
      );
      await repository.updateStreamingCheckpoint(checkpoint, const []);
      expect(raw.select('SELECT ordinal FROM part_attempts'), isEmpty);

      checkpoint = checkpoint.copyWith(
        parts: const [ReasoningPart('plan'), TextPart('next')],
      );
      await repository.updateStreamingCheckpoint(checkpoint, const []);
      expect(
        raw
            .select('SELECT ordinal FROM part_attempts')
            .map((r) => r['ordinal']),
        [1],
      );

      raw.execute('DELETE FROM part_attempts');
      checkpoint = checkpoint.copyWith(
        timestamp: timestamp.add(const Duration(seconds: 1)),
      );
      await repository.updateStreamingCheckpoint(checkpoint, const []);
      expect(
        raw
            .select('SELECT ordinal FROM part_attempts')
            .map((r) => r['ordinal']),
        [0, 1],
      );
    } finally {
      raw.close();
    }

    await repository.updateStreamingCheckpoint(
      checkpoint.copyWith(isStreaming: false),
      const [],
    );
    final stored = (await repository.getMessage(assistant.id))!;
    expect(stored.parts, checkpoint.parts);
    expect(stored.timestamp.isAtSameMomentAs(timestamp), isTrue);
    expect(stored.isStreaming, isFalse);
  });
}
