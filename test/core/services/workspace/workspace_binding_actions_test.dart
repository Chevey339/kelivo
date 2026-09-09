import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/workspace/workspace_binding_actions.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';

import '../../../support/business_test_harness.dart';

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
  late BusinessTestHarness harness;
  late AppDatabase database;
  late ChatService chat;
  late AssistantProvider assistants;
  late WorkspaceProvider workspaces;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'kelivo_workspace_binding_actions_',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    SandboxPathResolver.debugSetDirs(
      docsDir: tempDir.path,
      supportDir: tempDir.path,
    );
    harness = await BusinessTestHarness.create();
    database = AppDatabase(NativeDatabase.memory());
    await database.customSelect('SELECT 1;').getSingle();
    await harness.preferences.setString(
      'assistants_v1',
      jsonEncode([
        {'id': 'asst-1', 'name': 'Alpha'},
        {'id': 'asst-2', 'name': 'Beta', 'defaultWorkspaceId': 'ws-keep'},
      ]),
    );
    assistants = AssistantProvider(preferences: harness.preferences);
    await assistants.loaded;
    chat = ChatService();
    await chat.init();
    workspaces = WorkspaceProvider(
      store: ExtensionEntityStore(database),
      assistants: assistants,
    );
    await workspaces.loaded;
  });

  tearDown(() async {
    await chat.close();
    await database.close();
    await harness.close();
    await Hive.close();
    SandboxPathResolver.debugSetDirs(docsDir: null, supportDir: null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Workspace sampleWorkspace(String id, {String cwd = 'src'}) {
    final now = DateTime.utc(2026, 1, 1);
    return Workspace(
      id: id,
      name: 'Desk',
      kind: WorkspaceKind.managed,
      defaultCwd: cwd,
      createdAt: now,
      updatedAt: now,
    );
  }

  test(
    'bind writes extras and sets assistant default when different',
    () async {
      final conversation = await chat.createConversation(
        title: 'Chat',
        assistantId: 'asst-1',
      );
      final workspace = sampleWorkspace('ws-new');
      final actions = WorkspaceBindingActions(
        chat: chat,
        assistants: assistants,
      );

      final result = await actions.bind(
        conversationId: conversation.id,
        workspace: workspace,
      );

      expect(result.assistantDefaultChanged, isTrue);
      expect(result.assistantName, 'Alpha');
      final extras = chat.getConversation(conversation.id)!.extras;
      final binding = WorkspaceBinding.fromExtras(extras);
      expect(binding.workspaceId, 'ws-new');
      expect(binding.cwd, 'src');
      expect(assistants.getById('asst-1')!.defaultWorkspaceId, 'ws-new');
      expect(assistants.getById('asst-2')!.defaultWorkspaceId, 'ws-keep');
    },
  );

  test('bind does not report a change when default is already equal', () async {
    await assistants.updateAssistant(
      assistants.getById('asst-1')!.copyWith(defaultWorkspaceId: 'ws-same'),
    );
    final conversation = await chat.createConversation(
      title: 'Chat',
      assistantId: 'asst-1',
    );
    final actions = WorkspaceBindingActions(chat: chat, assistants: assistants);

    final result = await actions.bind(
      conversationId: conversation.id,
      workspace: sampleWorkspace('ws-same', cwd: 'lib'),
    );

    expect(result.assistantDefaultChanged, isFalse);
    expect(assistants.getById('asst-1')!.defaultWorkspaceId, 'ws-same');
    expect(
      WorkspaceBinding.fromExtras(
        chat.getConversation(conversation.id)!.extras,
      ).cwd,
      'lib',
    );
  });

  test('unbind clears extras and leaves the assistant untouched', () async {
    await assistants.updateAssistant(
      assistants.getById('asst-1')!.copyWith(defaultWorkspaceId: 'ws-bound'),
    );
    final conversation = await chat.createConversation(
      title: 'Chat',
      assistantId: 'asst-1',
    );
    final actions = WorkspaceBindingActions(chat: chat, assistants: assistants);
    await actions.bind(
      conversationId: conversation.id,
      workspace: sampleWorkspace('ws-bound'),
    );

    await actions.unbind(conversationId: conversation.id);

    expect(
      WorkspaceBinding.fromExtras(
        chat.getConversation(conversation.id)!.extras,
      ).isBound,
      isFalse,
    );
    expect(assistants.getById('asst-1')!.defaultWorkspaceId, 'ws-bound');
  });

  test('deleting a workspace clears matching assistant defaults', () async {
    final workspace = await workspaces.create(name: 'Doomed');
    await assistants.updateAssistant(
      assistants.getById('asst-1')!.copyWith(defaultWorkspaceId: workspace.id),
    );
    await assistants.updateAssistant(
      assistants.getById('asst-2')!.copyWith(defaultWorkspaceId: workspace.id),
    );

    await workspaces.delete(workspace.id, deleteFiles: false);

    expect(assistants.getById('asst-1')!.defaultWorkspaceId, isNull);
    expect(assistants.getById('asst-2')!.defaultWorkspaceId, isNull);
  });

  test('conversation without an assistant binds without error', () async {
    final conversation = await chat.createConversation(title: 'Orphan');
    expect(conversation.assistantId, isNull);
    final actions = WorkspaceBindingActions(chat: chat, assistants: assistants);

    final result = await actions.bind(
      conversationId: conversation.id,
      workspace: sampleWorkspace('ws-orphan'),
    );

    expect(result.assistantDefaultChanged, isFalse);
    expect(
      WorkspaceBinding.fromExtras(
        chat.getConversation(conversation.id)!.extras,
      ).workspaceId,
      'ws-orphan',
    );
    expect(assistants.getById('asst-1')!.defaultWorkspaceId, isNull);
    expect(assistants.getById('asst-2')!.defaultWorkspaceId, 'ws-keep');
  });

  test('new assistants default to no workspace', () async {
    const constructed = Assistant(id: 'new', name: 'New');
    expect(constructed.defaultWorkspaceId, isNull);

    final id = await assistants.addAssistant(name: 'Fresh');
    expect(assistants.getById(id)!.defaultWorkspaceId, isNull);
  });

  test('new conversation extras inherit the assistant default workspace', () {
    final workspace = sampleWorkspace('ws-default', cwd: 'notes');
    final extras = workspaceExtrasForNewConversation(
      assistant: assistants
          .getById('asst-1')!
          .copyWith(defaultWorkspaceId: workspace.id),
      workspaceById: (id) => id == workspace.id ? workspace : null,
    );
    final binding = WorkspaceBinding.fromExtras(extras);
    expect(binding.workspaceId, 'ws-default');
    expect(binding.cwd, 'notes');

    expect(
      workspaceExtrasForNewConversation(
        assistant: assistants.getById('asst-1'),
        workspaceById: (_) => workspace,
      ),
      isEmpty,
    );
    expect(
      workspaceExtrasForNewConversation(
        assistant: assistants
            .getById('asst-1')!
            .copyWith(defaultWorkspaceId: 'missing'),
        workspaceById: (_) => null,
      ),
      isEmpty,
    );
  });

  test('ChatService applies inherited extras on createConversation', () async {
    final workspace = sampleWorkspace('ws-inherit', cwd: 'app');
    chat.newConversationExtras = (assistantId) {
      if (assistantId == null) return const <String, dynamic>{};
      return workspaceExtrasForNewConversation(
        assistant: assistants.getById(assistantId),
        workspaceById: (id) => id == workspace.id ? workspace : null,
      );
    };
    await assistants.updateAssistant(
      assistants.getById('asst-1')!.copyWith(defaultWorkspaceId: workspace.id),
    );

    final conversation = await chat.createConversation(
      title: 'Inherited',
      assistantId: 'asst-1',
    );
    final binding = WorkspaceBinding.fromExtras(conversation.extras);
    expect(binding.workspaceId, 'ws-inherit');
    expect(binding.cwd, 'app');

    final unbound = await chat.createConversation(
      title: 'Plain',
      assistantId: 'asst-2',
    );
    expect(WorkspaceBinding.fromExtras(unbound.extras).isBound, isFalse);
  });
}
