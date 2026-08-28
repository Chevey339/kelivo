import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/utils/multimodal_input_utils.dart';
import 'package:Kelivo/features/home/services/message_builder_service.dart';

import '../../../support/business_test_harness.dart';

class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeChatService extends ChatService {
  @override
  List<Map<String, dynamic>> getToolEvents(String assistantMessageId) =>
      const [];
}

void main() {
  late Directory tempDir;
  late File csv;
  late File notes;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kelivo_sandbox_files');
    csv = File('${tempDir.path}/sales.csv')
      ..writeAsStringSync('region,amount\nnorth,1\n');
    notes = File('${tempDir.path}/notes.txt')..writeAsStringSync('read me');
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  ChatMessage userWithFiles() => ChatMessage(
    id: 'u1',
    role: 'user',
    conversationId: 'c1',
    parts: [
      const TextPart('analyse this'),
      FilePart(uri: csv.path, name: 'sales.csv', mime: 'text/csv'),
      FilePart(uri: notes.path, name: 'notes.txt', mime: 'text/plain'),
    ],
  );

  Future<
    ({MessageBuilderService service, SettingsProvider settings, ChatMessage m})
  >
  setUpService() async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    final service = MessageBuilderService(
      chatService: _FakeChatService(),
      contextProvider: _FakeBuildContext(),
    );
    return (service: service, settings: settings, m: userWithFiles());
  }

  test(
    'buildApiMessages lists documents under the document-paths key',
    () async {
      final s = await setUpService();
      final apiMessages = s.service.buildApiMessages(
        messages: [s.m],
        versionSelections: const {},
        currentConversation: Conversation(title: 'test'),
      );
      final refs = parseInternalDocumentRefs(
        apiMessages.single[multimodalInternalDocumentPathsKey],
      );
      expect(refs.map((r) => r.name), ['sales.csv', 'notes.txt']);
      expect(refs.first.uri, csv.path);
      expect(
        apiMessages.single.containsKey(multimodalInternalMediaPathsKey),
        isFalse,
      );
    },
  );

  test(
    'without a sandbox every document is extracted into the prompt',
    () async {
      final s = await setUpService();
      final apiMessages = s.service.buildApiMessages(
        messages: [s.m],
        versionSelections: const {},
        currentConversation: Conversation(title: 'test'),
      );
      expect(
        s.service.hasPendingAttachmentWork(
          apiMessages,
          s.settings,
          sourceMessages: [s.m],
        ),
        isTrue,
      );
      await s.service.processUserMessagesForApi(
        apiMessages,
        s.settings,
        const Assistant(id: 'a1', name: 'test'),
        sourceMessages: [s.m],
      );
      final content = apiMessages.single['content'] as String;
      expect(content, contains('region,amount'));
      expect(content, contains('read me'));
    },
  );

  test('with a sandbox the data file stays out of the prompt', () async {
    final s = await setUpService();
    final apiMessages = s.service.buildApiMessages(
      messages: [s.m],
      versionSelections: const {},
      currentConversation: Conversation(title: 'test'),
    );
    await s.service.processUserMessagesForApi(
      apiMessages,
      s.settings,
      const Assistant(id: 'a1', name: 'test'),
      sourceMessages: [s.m],
      sandboxDataFiles: true,
    );
    final content = apiMessages.single['content'] as String;
    expect(content, isNot(contains('region,amount')));
    expect(content, contains('read me'), reason: 'prose is still extracted');
    expect(content, contains('analyse this'));
    // The provider still finds the file to upload.
    final refs = parseInternalDocumentRefs(
      apiMessages.single[multimodalInternalDocumentPathsKey],
    );
    expect(refs.map((r) => r.name), contains('sales.csv'));
  });

  test('a lone data file is no pending extraction work', () async {
    final s = await setUpService();
    final onlyCsv = ChatMessage(
      id: 'u2',
      role: 'user',
      conversationId: 'c1',
      parts: [FilePart(uri: csv.path, name: 'sales.csv', mime: 'text/csv')],
    );
    final apiMessages = s.service.buildApiMessages(
      messages: [onlyCsv],
      versionSelections: const {},
      currentConversation: Conversation(title: 'test'),
    );
    expect(
      s.service.hasPendingAttachmentWork(
        apiMessages,
        s.settings,
        sourceMessages: [onlyCsv],
        sandboxDataFiles: true,
      ),
      isFalse,
    );
    expect(
      s.service.hasPendingAttachmentWork(
        apiMessages,
        s.settings,
        sourceMessages: [onlyCsv],
      ),
      isTrue,
    );
  });
}
