import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';

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
      'kelivo_conversation_model_test_',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    SandboxPathResolver.debugSetDirs(
      docsDir: tempDir.path,
      supportDir: tempDir.path,
    );
  });

  tearDown(() async {
    for (final service in services) {
      await service.close();
    }
    services.clear();
    await Hive.close();
    SandboxPathResolver.debugSetDirs(docsDir: null, supportDir: null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  ChatService createService() {
    final service = ChatService();
    services.add(service);
    return service;
  }

  test('a new conversation inherits, carrying no override', () async {
    final service = createService();
    await service.init();
    final conversation = await service.createConversation(title: 'Chat');

    expect(conversation.chatModelProvider, isNull);
    expect(conversation.chatModelId, isNull);
  });

  test('the override survives a restart', () async {
    final first = createService();
    await first.init();
    final conversation = await first.createConversation(title: 'Chat');

    final updated = await first.setConversationModel(
      conversation.id,
      providerKey: 'OpenAI',
      modelId: 'gpt-5',
    );
    expect(updated?.chatModelProvider, 'OpenAI');
    expect(updated?.chatModelId, 'gpt-5');

    await first.close();
    services.remove(first);

    final restarted = createService();
    await restarted.init();
    final reloaded = restarted.getConversation(conversation.id);

    expect(reloaded?.chatModelProvider, 'OpenAI');
    expect(reloaded?.chatModelId, 'gpt-5');
  });

  test('passing null for both clears the override', () async {
    final service = createService();
    await service.init();
    final conversation = await service.createConversation(title: 'Chat');
    await service.setConversationModel(
      conversation.id,
      providerKey: 'OpenAI',
      modelId: 'gpt-5',
    );

    final cleared = await service.setConversationModel(conversation.id);

    expect(cleared?.chatModelProvider, isNull);
    expect(cleared?.chatModelId, isNull);
  });

  test('half a pair is rejected, since it would silently inherit', () async {
    final service = createService();
    await service.init();
    final conversation = await service.createConversation(title: 'Chat');

    final onlyProvider = await service.setConversationModel(
      conversation.id,
      providerKey: 'OpenAI',
    );
    expect(onlyProvider?.chatModelProvider, isNull);
    expect(onlyProvider?.chatModelId, isNull);

    final onlyModel = await service.setConversationModel(
      conversation.id,
      modelId: 'gpt-5',
    );
    expect(onlyModel?.chatModelProvider, isNull);
    expect(onlyModel?.chatModelId, isNull);
  });

  test('one conversation pinning a model leaves the others alone', () async {
    final service = createService();
    await service.init();
    final pinned = await service.createConversation(title: 'Pinned');
    final following = await service.createConversation(title: 'Following');

    await service.setConversationModel(
      pinned.id,
      providerKey: 'OpenAI',
      modelId: 'gpt-5',
    );

    expect(
      service.getConversation(following.id)?.chatModelProvider,
      isNull,
      reason: 'other conversations keep following the assistant',
    );
  });

  group('legacy chats.json import', () {
    // Legacy backups predate the override, so their JSON has no such keys. The
    // import decodes with Conversation.fromJson and writes with
    // restoreConversation, which is the path this group pins down.

    test('a legacy record decodes as inheriting', () {
      // Exactly the shape an old chats.json carries: no model keys at all.
      final legacy = Conversation.fromJson({
        'id': 'legacy-1',
        'title': 'Old chat',
        'createdAt': '2024-01-01T00:00:00.000Z',
        'updatedAt': '2024-01-02T00:00:00.000Z',
        'messageIds': <String>[],
        'isPinned': false,
        'assistantId': 'assistant-1',
      });

      expect(legacy.chatModelProvider, isNull);
      expect(legacy.chatModelId, isNull);
      expect(legacy.title, 'Old chat');
      expect(legacy.assistantId, 'assistant-1');
    });

    test('restoring a legacy record keeps it inheriting', () async {
      final service = createService();
      await service.init();
      final legacy = Conversation.fromJson({
        'id': 'legacy-2',
        'title': 'Old chat',
        'createdAt': '2024-01-01T00:00:00.000Z',
        'updatedAt': '2024-01-02T00:00:00.000Z',
        'messageIds': <String>[],
        'isPinned': true,
      });

      await service.restoreConversation(legacy, const []);

      final restored = service.getConversation('legacy-2');
      expect(restored, isNotNull);
      expect(restored!.title, 'Old chat');
      expect(restored.isPinned, isTrue);
      expect(restored.chatModelProvider, isNull);
    });

    test('restoreConversation no longer drops carried-over fields', () async {
      final service = createService();
      await service.init();
      // restoreConversation rebuilds the record field by field, so anything it
      // forgets is lost silently on import.
      final source = Conversation(
        id: 'carried',
        title: 'Carried',
        summary: 'a summary',
        injectedMemoryHash: 'hash-1',
        lastMemoryExtractedOrder: 7,
        chatModelProvider: 'OpenAI',
        chatModelId: 'gpt-5',
      );

      await service.restoreConversation(source, const []);

      final restored = service.getConversation('carried')!;
      expect(restored.chatModelProvider, 'OpenAI');
      expect(restored.chatModelId, 'gpt-5');
      expect(restored.summary, 'a summary');
      expect(restored.injectedMemoryHash, 'hash-1');
      expect(restored.lastMemoryExtractedOrder, 7);
    });

    test('the override survives a JSON round trip', () {
      final source = Conversation(
        id: 'round-trip',
        title: 'Chat',
        chatModelProvider: 'Anthropic',
        chatModelId: 'claude',
      );

      final decoded = Conversation.fromJson(source.toJson());

      expect(decoded.chatModelProvider, 'Anthropic');
      expect(decoded.chatModelId, 'claude');
    });
  });

  group('clearConversationModelOverrides', () {
    test('clears every conversation pinned to a provider', () async {
      final service = createService();
      await service.init();
      final a = await service.createConversation(title: 'A');
      final b = await service.createConversation(title: 'B');
      final other = await service.createConversation(title: 'Other');
      await service.setConversationModel(
        a.id,
        providerKey: 'OpenAI',
        modelId: 'gpt-5',
      );
      await service.setConversationModel(
        b.id,
        providerKey: 'OpenAI',
        modelId: 'gpt-4',
      );
      await service.setConversationModel(
        other.id,
        providerKey: 'Anthropic',
        modelId: 'claude',
      );

      await service.clearConversationModelOverrides(providerKey: 'OpenAI');

      expect(service.getConversation(a.id)?.chatModelProvider, isNull);
      expect(service.getConversation(b.id)?.chatModelProvider, isNull);
      expect(
        service.getConversation(other.id)?.chatModelProvider,
        'Anthropic',
        reason: 'a different provider is untouched',
      );
    });

    test('narrows to a single model when one is given', () async {
      final service = createService();
      await service.init();
      final deleted = await service.createConversation(title: 'Deleted model');
      final kept = await service.createConversation(title: 'Kept model');
      await service.setConversationModel(
        deleted.id,
        providerKey: 'OpenAI',
        modelId: 'gpt-5',
      );
      await service.setConversationModel(
        kept.id,
        providerKey: 'OpenAI',
        modelId: 'gpt-4',
      );

      await service.clearConversationModelOverrides(
        providerKey: 'OpenAI',
        modelId: 'gpt-5',
      );

      expect(service.getConversation(deleted.id)?.chatModelProvider, isNull);
      expect(service.getConversation(kept.id)?.chatModelId, 'gpt-4');
    });

    test('the clear survives a restart', () async {
      final first = createService();
      await first.init();
      final conversation = await first.createConversation(title: 'Chat');
      await first.setConversationModel(
        conversation.id,
        providerKey: 'OpenAI',
        modelId: 'gpt-5',
      );
      await first.clearConversationModelOverrides(providerKey: 'OpenAI');
      await first.close();
      services.remove(first);

      final restarted = createService();
      await restarted.init();

      expect(
        restarted.getConversation(conversation.id)?.chatModelProvider,
        isNull,
      );
    });
  });
}
