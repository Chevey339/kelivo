import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/models/environment_variable.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/logging/context_logger.dart';
import 'package:Kelivo/core/services/workspace/workspace_paths.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/core/services/workspace/workspace_tools_service.dart';
import 'package:Kelivo/core/utils/multimodal_input_utils.dart';
import 'package:Kelivo/features/home/controllers/generation_controller.dart';
import 'package:Kelivo/features/home/controllers/stream_controller.dart'
    as stream_ctrl;
import 'package:Kelivo/features/home/services/message_builder_service.dart';
import 'package:Kelivo/features/home/services/message_generation_service.dart';
import '../../../support/business_test_harness.dart';

class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeChatService extends ChatService {
  @override
  List<Map<String, dynamic>> getToolEvents(String assistantMessageId) => [];
}

class _StubGenerationController extends Fake implements GenerationController {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #buildToolCallHandler) return null;
    return super.noSuchMethod(invocation);
  }
}

class _StubStreamController extends Fake
    implements stream_ctrl.StreamController {}

class _PackedGenerationService extends MessageGenerationService {
  _PackedGenerationService({
    required this.packed,
    required super.chatService,
    required super.messageBuilderService,
    required super.contextProvider,
  }) : super(
         generationController: _StubGenerationController(),
         streamController: _StubStreamController(),
       );

  final UnprocessedRequestContext packed;

  @override
  Future<UnprocessedRequestContext> assembleUnprocessedRequestContext({
    bool? fixedContextStart,
    DateTime? promptTime,
    bool forceResponses = false,
    bool applyMessageLimit = true,
    required List<ChatMessage> messages,
    required Map<String, int> versionSelections,
    required Conversation? currentConversation,
    required SettingsProvider settings,
    required Assistant? assistant,
    required String? assistantId,
    required String providerKey,
    required String modelId,
    String? requiredAttachmentMessageId,
    bool syncWorkspaceAttachments = true,
    bool persistWorldBookActivation = true,
    void Function(int before, int after)? onWorldBookActivationPersisted,
  }) async => packed;
}

void main() {
  late Directory tmp;
  late WorkspaceToolContext sandboxed;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('kelivo_ws_prompt_');
    final workspace = Directory(p.join(tmp.path, 'ws'))..createSync();
    final session = Directory(p.join(tmp.path, 'session'))..createSync();
    final skills = Directory(p.join(tmp.path, 'skills'))..createSync();
    sandboxed = WorkspaceToolContext(
      workspace: Workspace(
        id: 'ws1',
        name: 'Demo',
        kind: WorkspaceKind.managed,
        defaultCwd: '/workspace',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
      binding: const WorkspaceBinding(workspaceId: 'ws1', cwd: '/workspace'),
      paths: WorkspacePaths.sandboxed(
        workspaceHostRoot: workspace.path,
        sessionHostDir: session.path,
        skillsHostDir: skills.path,
      ),
      sessionDir: session,
      outputsDir: Directory(p.join(session.path, 'outputs'))..createSync(),
      runtimeStatus: const RuntimeStatus(
        ready: true,
        engine: 'proot',
        sandboxed: true,
      ),
      runtimeRegistered: true,
    );
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test('fragment includes the ${platform.name} directory description', () {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final fragment = WorkspaceToolsService.buildPromptFragment(sandboxed);
      expect(fragment, contains('<workspace>'));
      expect(fragment, contains('/workspace'));
      expect(fragment, contains('/chat'));
      expect(fragment, contains('/skills'));
      expect(fragment, contains('/tmp'));
      expect(fragment, contains('- /mounts/<name>/'));
      expect(
        fragment.contains('from iOS Files'),
        platform == TargetPlatform.iOS,
      );
      expect(fragment.contains('iCloud'), platform == TargetPlatform.iOS);
      expect(
        fragment.contains('on-device folders'),
        platform == TargetPlatform.android,
      );
      expect(fragment, contains('list /mounts/ first for external/user files'));
      expect(
        fragment,
        contains('File tools reject writes to read-only mounts'),
      );
      expect(
        fragment.indexOf('/mounts/<name>/'),
        lessThan(fragment.indexOf('cwd:')),
      );
      expect(fragment, isNot(contains('<external_mounts>')));
      expect(fragment, contains('cwd: /workspace'));
      expect(fragment, contains('kelivo://workspace/rel/path'));
      expect(fragment, contains('kelivo://chat/outputs/x.txt'));
      expect(fragment, contains('kelivo://workspace/plot.png'));
      expect(fragment, contains('Linux (PRoot)'));
      expect(fragment, contains('/etc/os-release'));
      // Custom-shell support adds this guidance to the prompt. Keep the
      // original size budget for the remaining directory/tool instructions.
      const shellSyntaxHint = 'Use the syntax of the selected shell.';
      expect(fragment, contains(shellSyntaxHint));
      expect(fragment.length, lessThan(1200 + shellSyntaxHint.length));
    });
  }

  test('fragment warns when the sandbox is not installed', () {
    final fragment = WorkspaceToolsService.buildPromptFragment(
      WorkspaceToolContext(
        workspace: sandboxed.workspace,
        binding: sandboxed.binding,
        paths: sandboxed.paths,
        sessionDir: sandboxed.sessionDir,
        outputsDir: sandboxed.outputsDir,
        runtimeRegistered: false,
      ),
    );
    expect(
      fragment,
      contains('Sandbox environment not installed — `shell` will fail'),
    );
  });

  test('injectWorkspacePrompt is absent when unbound', () async {
    final service = MessageBuilderService(
      chatService: _FakeChatService(),
      contextProvider: _FakeBuildContext(),
    );
    final apiMessages = <Map<String, dynamic>>[
      {'role': 'system', 'content': 'sys'},
    ];
    await service.injectWorkspacePrompt(
      apiMessages,
      const Assistant(id: 'a1', name: 'A'),
    );
    expect(apiMessages.single['content'], 'sys');
    expect(apiMessages.single['content'], isNot(contains('<workspace>')));
  });

  testWidgets(
    'adding an image preserves the system and earlier message prefix',
    (tester) async {
      late EnvironmentProvider environment;
      late SettingsProvider settings;
      await tester.runAsync(() async {
        environment = EnvironmentProvider(
          preferences: createBusinessTestPreferences(),
        );
        settings = SettingsProvider(createBusinessTestPreferences());
        await settings.loaded;
      });
      addTearDown(environment.dispose);
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: environment,
          child: const SizedBox(),
        ),
      );
      final service = MessageBuilderService(
        chatService: _FakeChatService(),
        contextProvider: tester.element(find.byType(SizedBox)),
      );
      const assistant = Assistant(id: 'a1', name: 'A');
      final conversation = Conversation(id: 'conv-1', title: 'Images');
      final firstImage = File(p.join(tmp.path, 'first.png'));
      final secondImage = File(p.join(tmp.path, 'second.png'));
      final first = ChatMessage(
        id: 'u1',
        role: 'user',
        conversationId: conversation.id,
        parts: [
          const TextPart('Describe this'),
          ImagePart(uri: firstImage.path, mime: 'image/png'),
        ],
      );
      final reply = ChatMessage(
        id: 'a1',
        role: 'assistant',
        conversationId: conversation.id,
        content: 'First image description',
      );
      final second = ChatMessage(
        id: 'u2',
        role: 'user',
        conversationId: conversation.id,
        parts: [ImagePart(uri: secondImage.path, mime: 'image/png')],
      );

      Future<List<Map<String, dynamic>>> request(
        List<ChatMessage> messages,
      ) async {
        final attachments = await syncAttachments(sandboxed, messages);
        final apiMessages = service.buildApiMessages(
          messages: messages,
          versionSelections: const {},
          currentConversation: conversation,
        );
        await service.injectWorkspacePrompt(
          apiMessages,
          assistant,
          workspaceContext: sandboxed,
        );
        await service.processUserMessagesForApi(
          apiMessages,
          settings,
          assistant,
          sourceMessages: messages,
          workspaceAttachments: {
            for (final file in attachments) file.sourceUri: file,
          },
        );
        service.stripInternalRevisionIds(apiMessages);
        return apiMessages;
      }

      await tester.runAsync(() async {
        await firstImage.writeAsBytes([1, 2, 3]);
        await secondImage.writeAsBytes([4, 5, 6]);
        final before = await request([first, reply]);
        final after = await request([first, reply, second]);
        expect(after.take(before.length).toList(), before);
        expect(after.first['role'], 'system');
        expect(after.first['content'], isNot(contains('first.png')));
        expect(after.first['content'], isNot(contains('second.png')));
        expect(after[1]['content'], contains('/chat/attachments/first.png'));
        expect(after[1]['content'], isNot(contains('second.png')));
        expect(after.last['content'], contains('/chat/attachments/second.png'));
        expect(after.last['content'], isNot(contains('first.png')));
        expect(
          parseInternalMediaRefs(
            after[1][multimodalInternalMediaPathsKey],
          ).single.uri,
          firstImage.path,
        );
        expect(
          parseInternalMediaRefs(
            after.last[multimodalInternalMediaPathsKey],
          ).single.uri,
          secondImage.path,
        );
        expect(
          await File(
            p.join(sandboxed.sessionDir.path, 'attachments', 'first.png'),
          ).readAsBytes(),
          [1, 2, 3],
        );
        expect(
          await File(
            p.join(sandboxed.sessionDir.path, 'attachments', 'second.png'),
          ).readAsBytes(),
          [4, 5, 6],
        );
        expect(await request([first, reply, second]), after);
      });
    },
  );

  testWidgets(
    'view_image-only workspace retains paths while documents are still extracted',
    (tester) async {
      final loggingEnabled = ContextLogger.enabled;
      addTearDown(() => ContextLogger.setEnabled(loggingEnabled));
      late SettingsProvider settings;
      await tester.runAsync(() async {
        await ContextLogger.setEnabled(false);
        settings = SettingsProvider(createBusinessTestPreferences());
        await settings.loaded;
      });
      addTearDown(settings.dispose);
      await tester.pumpWidget(const SizedBox());
      final context = tester.element(find.byType(SizedBox));
      final chat = _FakeChatService();
      final builder = MessageBuilderService(
        chatService: chat,
        contextProvider: context,
      );
      final image = File(p.join(tmp.path, 'image.png'));
      final notes = File(p.join(tmp.path, 'notes.txt'));
      final message = ChatMessage(
        id: 'mixed',
        role: 'user',
        conversationId: 'c1',
        parts: [
          const TextPart('Read these'),
          ImagePart(uri: image.path, mime: 'image/png'),
          FilePart(uri: notes.path, name: 'notes.txt', mime: 'text/plain'),
        ],
      );
      final workspace = WorkspaceToolContext(
        workspace: sandboxed.workspace.copyWith(
          disabledTools: WorkspaceToolsService.toolNames.difference({
            'view_image',
          }),
        ),
        binding: sandboxed.binding,
        paths: sandboxed.paths,
        sessionDir: sandboxed.sessionDir,
        outputsDir: sandboxed.outputsDir,
        runtimeStatus: sandboxed.runtimeStatus,
        runtimeRegistered: true,
      );

      await tester.runAsync(() async {
        await image.writeAsBytes([1, 2, 3]);
        await notes.writeAsString(
          'Document content must still reach the model.',
        );
        final attachments = await syncAttachments(workspace, [message]);
        final apiMessages = builder.buildApiMessages(
          messages: [message],
          versionSelections: const {},
          currentConversation: null,
        );
        await builder.injectWorkspacePrompt(
          apiMessages,
          null,
          workspaceContext: workspace,
        );
        final tools = WorkspaceToolsService().buildToolDefinitions(workspace);
        expect(tools.map((tool) => (tool['function'] as Map)['name']), [
          'view_image',
        ]);
        final generation = _PackedGenerationService(
          packed: UnprocessedRequestContext(
            apiMessages: apiMessages,
            toolDefs: tools,
            hasBuiltInSearch: false,
            workspaceContext: workspace,
            mcpRouteSnapshot: null,
            workspaceAttachments: attachments,
            cfg: settings.getProviderConfig('openai'),
          ),
          chatService: chat,
          messageBuilderService: builder,
          contextProvider: context,
        );
        final processing = <String>[];
        generation.onFileProcessingStarted = (id) =>
            processing.add('start:$id');
        generation.onFileProcessingFinished = (id) =>
            processing.add('finish:$id');
        final prepared = await generation.prepareApiMessagesWithInjections(
          messages: [message],
          versionSelections: const {},
          currentConversation: null,
          settings: settings,
          assistant: null,
          assistantId: null,
          providerKey: 'openai',
          modelId: 'gpt-4.1',
          processingMessageId: message.id,
        );
        expect(processing, ['start:mixed', 'finish:mixed']);
        final user = prepared.apiMessages.last;
        expect(user['content'], contains('/chat/attachments/image.png'));
        expect(user['content'], contains('/chat/attachments/notes.txt'));
        expect(
          user['content'],
          contains('Document content must still reach the model.'),
        );
        expect(
          parseInternalMediaRefs(
            user[multimodalInternalMediaPathsKey],
          ).single.uri,
          image.path,
        );
      });
    },
  );

  testWidgets(
    'injectWorkspacePrompt appends the fragment and variable names without values',
    (tester) async {
      late EnvironmentProvider environment;
      await tester.runAsync(() async {
        environment = EnvironmentProvider(
          preferences: createBusinessTestPreferences(),
        );
        await environment.saveVariable(
          const EnvironmentVariable(
            name: 'API_KEY',
            value: 'never-send-this-secret',
            note: 'private-note',
          ),
        );
      });
      addTearDown(environment.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: environment,
          child: const SizedBox(),
        ),
      );
      final service = MessageBuilderService(
        chatService: _FakeChatService(),
        contextProvider: tester.element(find.byType(SizedBox)),
      );
      final apiMessages = <Map<String, dynamic>>[
        {'role': 'system', 'content': 'sys'},
      ];
      await tester.runAsync(
        () => service.injectWorkspacePrompt(
          apiMessages,
          const Assistant(id: 'a1', name: 'A'),
          conversationId: 'conv-1',
          workspaceContext: sandboxed,
        ),
      );
      final content = apiMessages.single['content'] as String;
      expect(content, startsWith('sys'));
      expect(content, contains('<workspace>'));
      expect(content, contains('API_KEY'));
      expect(content, isNot(contains('never-send-this-secret')));
      expect(content, isNot(contains('private-note')));
    },
  );
}
