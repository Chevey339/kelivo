import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:Kelivo/core/models/workspace_binding.dart';
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
      'kelivo_chat_workspace_extras_',
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

  Map<String, dynamic> bindingExtras(String id, {String cwd = ''}) {
    return WorkspaceBinding(workspaceId: id, cwd: cwd).applyTo({});
  }

  test('newConversationExtras is applied on createConversation', () async {
    final service = createService();
    service.newConversationExtras = (_) =>
        bindingExtras('ws-create', cwd: 'src');
    await service.init();
    final conversation = await service.createConversation(title: 'Chat');
    final binding = WorkspaceBinding.fromExtras(conversation.extras);
    expect(binding.workspaceId, 'ws-create');
    expect(binding.cwd, 'src');
  });

  test(
    'background creation preserves the active temporary draft and workspace',
    () async {
      final service = createService();
      await service.init();
      final draft = await service.createDraftConversation(
        temporary: true,
        title: 'Unsent draft',
      );
      service.newConversationExtras = (id) => bindingExtras('workspace-$id');
      final taskChat = await service.createConversation(
        title: 'Scheduled',
        assistantId: 'task-assistant',
        activate: false,
      );
      expect(service.currentConversationId, draft.id);
      expect(service.getConversation(draft.id), isNotNull);
      expect(service.isTemporaryConversation(draft.id), isTrue);
      expect(service.getConversation(taskChat.id), isNotNull);
      expect(
        WorkspaceBinding.fromExtras(taskChat.extras).workspaceId,
        'workspace-task-assistant',
      );
    },
  );

  test('newConversationExtras is applied on createDraftConversation', () async {
    final service = createService();
    service.newConversationExtras = (_) => bindingExtras('ws-draft');
    await service.init();
    final draft = await service.createDraftConversation(title: 'Draft');
    expect(WorkspaceBinding.fromExtras(draft.extras).workspaceId, 'ws-draft');
  });

  test('fork copies the source workspace binding', () async {
    final service = createService();
    await service.init();
    final source = await service.createConversation(title: 'Source');
    await service.updateConversationExtras(
      source.id,
      (_) => WorkspaceBinding(
        workspaceId: 'ws-source',
        cwd: 'lib',
        toolsUsed: true,
        allowAll: true,
      ).applyTo({}),
    );
    final message = await service.addMessage(
      conversationId: source.id,
      role: 'user',
      content: 'hello',
    );
    service.newConversationExtras = (_) => bindingExtras('ws-default');
    final fork = await service.forkConversationFromMessages(
      title: 'Fork',
      assistantId: source.assistantId,
      sourceMessages: [message],
    );
    final binding = WorkspaceBinding.fromExtras(fork.extras);
    expect(binding.workspaceId, 'ws-source');
    expect(binding.cwd, 'lib');
    expect(binding.allowAll, isTrue);
    expect(binding.toolsUsed, isFalse);
  });

  test('draft promotion keeps extras', () async {
    final service = createService();
    service.newConversationExtras = (_) =>
        bindingExtras('ws-keep', cwd: 'notes');
    await service.init();
    final draft = await service.createDraftConversation(title: 'Draft');
    expect(WorkspaceBinding.fromExtras(draft.extras).workspaceId, 'ws-keep');
    await service.addMessage(
      conversationId: draft.id,
      role: 'user',
      content: 'hi',
    );
    final persisted = service.getConversation(draft.id);
    expect(persisted, isNotNull);
    final binding = WorkspaceBinding.fromExtras(persisted!.extras);
    expect(binding.workspaceId, 'ws-keep');
    expect(binding.cwd, 'notes');
  });
}
