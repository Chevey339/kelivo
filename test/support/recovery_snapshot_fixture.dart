import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/backup.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/chat_message.dart';

Future<File> writeRecoverySnapshot(
  File destination, {
  int conversations = 2,
  int messages = 42,
}) async {
  final output = destination.absolute.path;
  await destination.parent.create(recursive: true);
  return File(
    await Isolate.run(() async {
      final staging = await Directory.systemTemp.createTemp(
        'kelivo-recovery-fixture-',
      );
      try {
        final database = File('${staging.path}/kelivo.db');
        final repository = ChatDatabaseRepository.open(file: database);
        try {
          await repository.ensureReady();
          await repository.putMigrationBatch(
            conversations: [
              for (var c = 0; c < conversations; c++)
                Conversation(id: 'conversation-$c', title: 'Conversation $c'),
            ],
            messages: [
              for (var m = 0; m < messages; m++)
                (
                  message: ChatMessage(
                    id: 'message-$m',
                    conversationId: 'conversation-0',
                    role: 'user',
                    content: 'Retained message $m',
                  ),
                  messageOrder: m,
                ),
            ],
            toolEventsByMessageId: const {},
            geminiSignaturesByMessageId: const {},
          );
          await repository.checkpoint();
        } finally {
          await repository.close();
        }
        final info = await ChatDatabaseRepository.prepareSnapshotForRestore(
          database,
        );
        final settings = File('${staging.path}/settings.json');
        await settings.writeAsString('{}');
        final files = {
          'settings.json': settings,
          'database/kelivo.db': database,
        };
        final entries = <String, Object>{};
        for (final entry in files.entries) {
          entries[entry.key] = {
            'bytes': await entry.value.length(),
            'sha256': (await sha256.bind(entry.value.openRead()).first)
                .toString(),
          };
        }
        final manifest = File('${staging.path}/manifest.json');
        await manifest.writeAsString(
          jsonEncode({
            'format': 'kelivo-backup',
            'formatVersion': 3,
            'payloadKind': 'sqlite',
            'createdAtUtc': '2026-10-19T14:45:11Z',
            'appVersion': '1.3.1+80',
            'includeChats': true,
            'includeFiles': false,
            'secretsIncluded': true,
            'scope': {
              for (final category in BackupCategory.values) category.name: true,
            },
            'database': {
              'entry': 'database/kelivo.db',
              'schemaVersion': info.schemaVersion,
              'conversationCount': info.conversationCount,
              'messageCount': info.messageCount,
            },
            'entries': entries,
          }),
        );
        final encoder = ZipFileEncoder()..create(output);
        encoder.addFileSync(manifest, 'manifest.json');
        for (final entry in files.entries) {
          encoder.addFileSync(entry.value, entry.key);
        }
        encoder.closeSync();
        return output;
      } finally {
        await staging.delete(recursive: true);
      }
    }),
  );
}
