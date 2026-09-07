import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/models/environment_variable.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/workspace/workspace_paths.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/core/services/workspace/workspace_tools_service.dart';
import 'package:Kelivo/features/home/services/message_builder_service.dart';
import '../../../support/business_test_harness.dart';

class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeChatService extends ChatService {}

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
      final fragment = WorkspaceToolsService.buildPromptFragment(
        sandboxed,
        attachments: const [
          AttachmentInfo(
            name: 'notes.pdf',
            size: 12,
            modelPath: '/chat/attachments/notes.pdf',
          ),
        ],
      );
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
      expect(fragment, contains('notes.pdf'));
      expect(fragment, contains('12 bytes'));
      expect(fragment, contains('Ubuntu (PRoot)'));
      final withoutAttachments = fragment.replaceAll(
        RegExp(r'Attachments under[\s\S]*?(?=</workspace>)'),
        '',
      );
      expect(withoutAttachments.length, lessThan(1200));
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
          attachments: const [
            AttachmentInfo(
              name: 'a.txt',
              size: 1,
              modelPath: '/chat/attachments/a.txt',
            ),
          ],
        ),
      );
      final content = apiMessages.single['content'] as String;
      expect(content, startsWith('sys'));
      expect(content, contains('<workspace>'));
      expect(content, contains('a.txt'));
      expect(content, contains('API_KEY'));
      expect(content, isNot(contains('never-send-this-secret')));
      expect(content, isNot(contains('private-note')));
    },
  );
}
