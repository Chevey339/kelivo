import 'dart:io';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/quote_ref.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'quotes survive writes, metadata updates, edits, reopen and conversation copies',
    () async {
      final directory = await Directory.systemTemp.createTemp('kelivo_quotes_');
      var repository = ChatDatabaseRepository.open(
        file: File('${directory.path}/chat.sqlite'),
      );
      addTearDown(() async {
        await repository.close();
        await directory.delete(recursive: true);
      });
      await repository.ensureReady();
      final source = ChatMessage(
        id: 'source',
        role: 'assistant',
        content: 'same text same text',
        conversationId: 'chat',
      );
      final quote = QuoteRef(
        id: 'q',
        messageId: source.id,
        start: 10,
        end: 19,
        text: 'same text',
        model: 'model',
        createdAt: source.timestamp,
      );
      final reasoningQuote = QuoteRef(
        id: 'reasoning',
        messageId: source.id,
        start: 0,
        end: 0,
        text: 'selected thought',
        model: 'model',
        createdAt: source.timestamp,
        hasSourceRange: false,
      );
      final quotes = [quote, reasoningQuote];
      final reply = ChatMessage(
        id: 'reply',
        role: 'user',
        content: 'Why \uFFFC and \uFFFC?',
        quotes: quotes,
        conversationId: 'chat',
      );
      await repository.putMigrationBatch(
        conversations: [
          Conversation(
            id: 'chat',
            title: 'Quotes',
            messageIds: ['source', 'reply'],
          ),
        ],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
        messages: [
          (message: source, messageOrder: 0),
          (message: reply, messageOrder: 1),
        ],
      );
      await repository.updateMessage(reply.copyWith(totalTokens: 20));
      await repository.updateMessageFields(
        reply.id,
        translation: 'full translation',
      );
      expect((await repository.getMessage(reply.id))!.quotes, quotes);
      final edited = await repository.appendMessageVersion(
        messageId: reply.id,
        content: '\uFFFC \uFFFC Explain',
        quotes: quotes,
      );
      expect(edited!.message.quotes, quotes);
      final copy = await repository.duplicateConversation('chat');
      final copied = await repository.getMessagesByIds(copy!.messageIds);
      final copiedSource = copied.singleWhere((m) => m.role == 'assistant');
      for (final message in copied.where((m) => m.role == 'user')) {
        expect(
          message.quotes,
          quotes.map((quote) => quote.withMessageId(copiedSource.id)).toList(),
        );
      }
      await repository.close();
      repository = ChatDatabaseRepository.open(
        file: File('${directory.path}/chat.sqlite'),
      );
      await repository.ensureReady();
      final loaded = (await repository.getMessage(edited.message.id))!;
      expect(loaded.content, '\uFFFC \uFFFC Explain');
      expect(loaded.quotes, quotes);
      final without = await repository.appendMessageVersion(
        messageId: loaded.id,
        content: 'No quote',
        quotes: [],
      );
      expect(without!.message.quotes, isEmpty);
    },
  );
}
