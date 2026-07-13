import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../database/chat_database_repository.dart';
import '../../models/chat_message.dart';
import '../../models/conversation.dart';

enum PortableChatScope { activeBranchCompleted, allRevisions }

final class PortableChatExportResult {
  const PortableChatExportResult({
    required this.conversations,
    required this.messages,
    required this.sha256,
  });

  final int conversations;
  final int messages;
  final String sha256;
}

/// Explicit, portable chat interchange. Full backups continue to use SQLite.
final class PortableNdjsonV2 {
  PortableNdjsonV2._();

  static const _format = 'kelivo-portable-chat';
  static const _version = 2;
  static const _pageSize = 100;
  static const _maximumRecords = 2000000;

  static Future<PortableChatExportResult> exportToFile({
    required ChatDatabaseRepository repository,
    required File destination,
    PortableChatScope scope = PortableChatScope.activeBranchCompleted,
  }) async {
    await destination.parent.create(recursive: true);
    final sink = destination.openWrite(mode: FileMode.writeOnly);
    var conversationCount = 0;
    var messageCount = 0;
    try {
      sink.writeln(
        jsonEncode({
          'type': 'header',
          'format': _format,
          'version': _version,
          'scope': scope.name,
          'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
        }),
      );
      final conversations = await repository.getAllConversationSummaries();
      for (final conversation in conversations) {
        final conversationJson = conversation.toJson()
          ..['messageIds'] = const <String>[];
        sink.writeln(
          jsonEncode({'type': 'conversation', 'value': conversationJson}),
        );
        conversationCount++;

        if (scope == PortableChatScope.activeBranchCompleted) {
          String? afterRevisionId;
          while (true) {
            final page = await repository.loadActiveTimelinePage(
              conversationId: conversation.id,
              afterRevisionId: afterRevisionId,
              fromStart: afterRevisionId == null,
              limit: _pageSize,
            );
            if (page == null || page.slots.isEmpty) break;
            final ids = page.slots
                .map((slot) => slot.revisionId)
                .toList(growable: false);
            final loaded = await repository.getMessagesByIds(ids);
            final byId = {for (final message in loaded) message.id: message};
            for (final id in ids) {
              final message = byId[id];
              if (message == null || message.isStreaming) continue;
              _writeMessage(sink, message);
              messageCount++;
            }
            if (!page.hasMoreAfter) break;
            afterRevisionId = page.slots.last.revisionId;
          }
        } else {
          final total = await repository.getMessageCount(conversation.id);
          for (var start = 0; start < total; start += _pageSize) {
            final messages = await repository.getMessagesRange(
              conversation.id,
              start: start,
              limit: _pageSize,
            );
            for (final message in messages) {
              _writeMessage(sink, message);
              messageCount++;
            }
          }
        }
      }
    } finally {
      await sink.flush();
      await sink.close();
    }

    final recordsHash = (await sha256.bind(destination.openRead()).first)
        .toString();
    final footerSink = destination.openWrite(mode: FileMode.append);
    footerSink.writeln(
      jsonEncode({
        'type': 'footer',
        'conversations': conversationCount,
        'messages': messageCount,
        'recordsSha256': recordsHash,
      }),
    );
    await footerSink.flush();
    await footerSink.close();
    return PortableChatExportResult(
      conversations: conversationCount,
      messages: messageCount,
      sha256: recordsHash,
    );
  }

  static void _writeMessage(IOSink sink, ChatMessage message) {
    sink.writeln(jsonEncode({'type': 'message', 'value': message.toJson()}));
  }

  static Future<BackupMergeReport> importFromFile({
    required ChatDatabaseRepository target,
    required File source,
  }) async {
    if (!await source.exists()) {
      throw FileSystemException('Portable archive does not exist', source.path);
    }
    final temp = await Directory.systemTemp.createTemp('kelivo_ndjson_v2_');
    final candidateFile = File('${temp.path}/candidate.sqlite');
    final candidate = ChatDatabaseRepository.open(file: candidateFile);
    try {
      Conversation? conversation;
      final messages = <ChatMessage>[];
      var conversations = 0;
      var messageCount = 0;
      var records = 0;
      var headerSeen = false;
      var footerSeen = false;
      final digestSink = _DigestSink();
      final hashSink = sha256.startChunkedConversion(digestSink);

      Future<void> flushConversation() async {
        final current = conversation;
        if (current == null) return;
        await candidate.putMigrationBatch(
          conversations: [
            current.copyWith(
              messageIds: [for (final message in messages) message.id],
            ),
          ],
          messages: [
            for (final (index, message) in messages.indexed)
              (message: message, messageOrder: index),
          ],
          toolEventsByMessageId: const {},
          geminiSignaturesByMessageId: const {},
        );
        conversation = null;
        messages.clear();
      }

      await for (final line
          in source
              .openRead()
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (line.trim().isEmpty) continue;
        final decoded = jsonDecode(line);
        if (decoded is! Map) throw const FormatException('portable_record');
        final record = decoded.cast<String, dynamic>();
        final type = record['type'];
        if (type == 'footer') {
          if (!headerSeen || footerSeen) {
            throw const FormatException('portable_footer_order');
          }
          await flushConversation();
          hashSink.close();
          footerSeen = true;
          if (record['conversations'] != conversations ||
              record['messages'] != messageCount ||
              record['recordsSha256'] != digestSink.digest?.toString()) {
            throw const FormatException('portable_footer');
          }
          continue;
        }
        if (footerSeen) throw const FormatException('portable_trailing_record');
        hashSink.add(utf8.encode('$line\n'));
        records++;
        if (records > _maximumRecords) {
          throw const FormatException('portable_record_budget');
        }
        if (type == 'header') {
          if (headerSeen ||
              record['format'] != _format ||
              record['version'] != _version ||
              PortableChatScope.values.every(
                (scope) => scope.name != record['scope'],
              )) {
            throw const FormatException('portable_header');
          }
          headerSeen = true;
        } else if (type == 'conversation') {
          if (!headerSeen) throw const FormatException('portable_header');
          await flushConversation();
          final value = record['value'];
          if (value is! Map) {
            throw const FormatException('portable_conversation');
          }
          conversation = Conversation.fromJson(value.cast<String, dynamic>());
          conversations++;
        } else if (type == 'message') {
          final current = conversation;
          final value = record['value'];
          if (current == null || value is! Map) {
            throw const FormatException('portable_message_order');
          }
          final message = ChatMessage.fromJson(value.cast<String, dynamic>());
          if (message.conversationId != current.id) {
            throw const FormatException('portable_message_conversation');
          }
          messages.add(message);
          messageCount++;
        } else {
          throw const FormatException('portable_record_type');
        }
      }
      if (!headerSeen || !footerSeen) {
        throw const FormatException('portable_incomplete');
      }
      await candidate.close();
      return await target.mergeBackupSnapshot(candidateFile);
    } finally {
      await candidate.close();
      await temp.delete(recursive: true);
    }
  }
}

final class _DigestSink implements Sink<Digest> {
  Digest? digest;

  @override
  void add(Digest data) => digest = data;

  @override
  void close() {}
}
