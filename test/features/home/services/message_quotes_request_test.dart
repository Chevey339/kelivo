import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/compress_context_options.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/models/quote_ref.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/services/message_builder_service.dart';
import 'package:Kelivo/features/home/services/message_generation_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../support/business_test_harness.dart';

class _Context implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Chat extends ChatService {
  @override
  List<ChatMessage> getMessages(String id) => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'every compression mode includes the frozen quote even without its source',
    () {
      final quote = QuoteRef(
        id: 'q',
        messageId: 'deleted-source',
        start: 0,
        end: 5,
        text: 'critical original\nsecond line',
        model: null,
        createdAt: DateTime(2026),
      );
      final message = ChatMessage(
        role: 'user',
        conversationId: 'c',
        content: 'Follow \uFFFC',
        quotes: [quote],
      );
      for (final mode in CompressContextLimitMode.values) {
        final text = buildCompressRequestContents([
          message,
        ], CompressContextOptions(mode: mode, maxChars: 10000)).join();
        expect(text, contains('> [引用1] critical original\n> second line'));
        expect(text, contains('Follow [引用1]'));
        expect(text, isNot(contains(quotePlaceholder)));
      }
    },
  );
  test(
    'storage keeps inline positions; both request stages expand quotes exactly once',
    () async {
      final quote = QuoteRef(
        id: 'q',
        messageId: 'source',
        start: 3,
        end: 10,
        text: 'first line\nsecond line',
        model: 'model',
        createdAt: DateTime(2026),
      );
      final input = ChatInputData(text: 'Before \uFFFC after', quotes: [quote]);
      final parts =
          await MessageGenerationService.buildPersistedUserMessageParts(
            input,
            assistant: null,
          );
      expect((parts.single as TextPart).text, 'Before \uFFFC after');
      final message = ChatMessage(
        id: 'reply',
        conversationId: 'c',
        role: 'user',
        parts: parts,
        quotes: input.quotes,
      );
      final service = MessageBuilderService(
        chatService: _Chat(),
        contextProvider: _Context(),
      );
      final api = service.buildApiMessages(
        messages: [message],
        versionSelections: const {},
        currentConversation: Conversation(id: 'c', title: 'test'),
      );
      const expected =
          '> [引用1] first line\n> second line\n\nBefore [引用1] after';
      expect(api.single['content'], expected);
      final settings = SettingsProvider(createBusinessTestPreferences());
      addTearDown(settings.dispose);
      await settings.loaded;
      await service.processUserMessagesForApi(
        api,
        settings,
        const Assistant(id: 'a', name: 'test'),
        sourceMessages: [message],
        previewOnly: true,
      );
      expect(api.single['content'], expected);
      final edit = service.parseInputFromMessage(message);
      expect(edit.text, input.text);
      expect(edit.quotes, [quote]);
    },
  );
}
