import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:Kelivo/core/services/chat/chat_service.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getApplicationSupportPath() async => path;

  @override
  Future<String?> getApplicationCachePath() async => '$path/cache';

  @override
  Future<String?> getTemporaryPath() async => '$path/tmp';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  final services = <ChatService>[];

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'kelivo_chat_list_revision_test_',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() async {
    for (final service in services) {
      await service.close();
    }
    services.clear();
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  ChatService createService({Future<String> Function(File)? assetContentHash}) {
    final service = ChatService(assetContentHash: assetContentHash);
    services.add(service);
    return service;
  }

  group('conversationListRevision', () {
    test('bumps on create, rename, pin, mcp, assistant move, delete', () async {
      final service = createService();
      await service.init();
      final initial = service.conversationListRevision;

      final conversation = await service.createConversation(title: 'A');
      expect(service.conversationListRevision, greaterThan(initial));

      var last = service.conversationListRevision;
      await service.renameConversation(conversation.id, 'B');
      expect(service.conversationListRevision, greaterThan(last));

      last = service.conversationListRevision;
      await service.togglePinConversation(conversation.id);
      expect(service.conversationListRevision, greaterThan(last));

      last = service.conversationListRevision;
      await service.setConversationMcpServers(conversation.id, ['server-1']);
      expect(service.conversationListRevision, greaterThan(last));

      last = service.conversationListRevision;
      await service.moveConversationToAssistant(
        conversationId: conversation.id,
        assistantId: 'assistant-1',
      );
      expect(service.conversationListRevision, greaterThan(last));

      last = service.conversationListRevision;
      await service.deleteConversation(conversation.id);
      expect(service.conversationListRevision, greaterThan(last));
    });

    test('does not bump on selection, streaming, or summary updates', () async {
      final service = createService();
      await service.init();
      final conversation = await service.createConversation(title: 'A');
      final message = await service.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: 'hello',
      );

      var last = service.conversationListRevision;
      service.setCurrentConversation(conversation.id);
      expect(service.conversationListRevision, last);

      await service.updateMessage(message.id, content: 'hello world');
      expect(service.conversationListRevision, last);

      await service.updateMessageSilent(message.id, content: 'hello again');
      expect(service.conversationListRevision, last);

      await service.updateStreamingCheckpointSilent(message, const []);
      expect(service.conversationListRevision, last);

      await service.updateConversationSummary(conversation.id, 'summary', 1);
      expect(service.conversationListRevision, last);

      await service.updateConversationSuggestions(conversation.id, ['s']);
      expect(service.conversationListRevision, last);
    });

    test('persisted message append bumps; temporary draft does not', () async {
      final service = createService();
      await service.init();
      final conversation = await service.createConversation(title: 'A');

      final last = service.conversationListRevision;
      await service.addMessage(
        conversationId: conversation.id,
        role: 'user',
        content: 'hello',
      );
      expect(service.conversationListRevision, greaterThan(last));

      final temporary = await service.createDraftConversation(
        title: 'Temp',
        temporary: true,
      );
      final beforeTemporary = service.conversationListRevision;
      await service.addMessage(
        conversationId: temporary.id,
        role: 'user',
        content: 'secret',
      );
      expect(service.conversationListRevision, beforeTemporary);
    });
  });

  group('sorted conversation cache', () {
    test(
      'returns equal lists across calls and caller mutation is isolated',
      () async {
        final service = createService();
        await service.init();
        await service.createConversation(title: 'A');
        await service.createConversation(title: 'B');

        final first = service.getAllConversations();
        final second = service.getAllConversations();
        expect(second.map((c) => c.id), first.map((c) => c.id));
        expect(
          service.conversationListRevision,
          service.conversationListRevision,
        );

        first.clear();
        expect(service.getAllConversations(), hasLength(2));
      },
    );

    test('rename invalidates the cached order', () async {
      final service = createService();
      await service.init();
      final older = await service.createConversation(title: 'Older');
      final newer = await service.createConversation(title: 'Newer');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(service.getAllConversations().first.id, newer.id);

      await service.renameConversation(older.id, 'Older renamed');
      expect(service.getAllConversations().first.id, older.id);
      expect(service.getConversation(older.id)!.title, 'Older renamed');
    });
  });

  group('resolveImageContentHashes cache', () {
    test('hashes each unchanged file once and rehashes after change', () async {
      var hashCalls = 0;
      final service = createService(
        assetContentHash: (file) async {
          hashCalls++;
          final bytes = await file.readAsBytes();
          return 'hash-${bytes.length}';
        },
      );
      await service.init();

      final image = File('${tempDir.path}/images/pic.png');
      await image.parent.create(recursive: true);
      await image.writeAsBytes(List.filled(8, 1));

      final first = await service.resolveImageContentHashes([image.path]);
      expect(first[image.path], 'hash-8');
      expect(hashCalls, 1);

      final second = await service.resolveImageContentHashes([
        image.path,
        image.path,
      ]);
      expect(second[image.path], 'hash-8');
      expect(hashCalls, 1, reason: 'unchanged file must not be re-read');

      await image.writeAsBytes(List.filled(16, 2), flush: true);
      final third = await service.resolveImageContentHashes([image.path]);
      expect(third[image.path], 'hash-16');
      expect(hashCalls, 2, reason: 'changed file must be re-hashed');
    });

    test('skips missing files and leaves data URLs uncached', () async {
      var hashCalls = 0;
      final service = createService(
        assetContentHash: (file) async {
          hashCalls++;
          return 'hash';
        },
      );
      await service.init();

      final missing = await service.resolveImageContentHashes([
        '${tempDir.path}/images/missing.png',
      ]);
      expect(missing, isEmpty);
      expect(hashCalls, 0);

      const dataUrl = 'data:image/png;base64,aGVsbG8=';
      final first = await service.resolveImageContentHashes([dataUrl]);
      final second = await service.resolveImageContentHashes([dataUrl]);
      expect(first[dataUrl], second[dataUrl]);
      expect(hashCalls, 0);
    });
  });
}
