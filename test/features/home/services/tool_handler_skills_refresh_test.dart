import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/mcp/mcp_tool_service.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';
import 'package:Kelivo/core/services/workspace/tool_run_registry.dart';
import 'package:Kelivo/core/services/workspace/workspace_paths.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/core/services/workspace/workspace_tools_service.dart';
import 'package:Kelivo/features/home/services/tool_handler_service.dart';
import 'package:Kelivo/features/workspace/widgets/skills/conversation_skills_sheet.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skills_pane.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';
import '../../../support/fake_workspace_runtime.dart';
import '../../workspace/skills/skills_test_fakes.dart';

class _InstallingRuntime extends FakeWorkspaceRuntime {
  Future<void> Function()? action;

  @override
  Stream<CommandEvent> run(CommandRequest request) async* {
    await action?.call();
    yield const CommandExited(
      exitCode: 0,
      timedOut: false,
      cancelled: false,
      interrupted: false,
      duration: Duration.zero,
    );
  }
}

void main() {
  late Directory tmp;
  late AppDatabase database;
  late WorkspaceProvider workspaces;
  late Workspace workspace;
  late SkillsService skills;
  late Directory workspaceDir;
  late Directory sessionDir;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('kelivo_agent_skills_');
    workspaceDir = Directory(p.join(tmp.path, 'workspace'))..createSync();
    sessionDir = Directory(p.join(tmp.path, 'session'))..createSync();
    Directory(p.join(sessionDir.path, 'outputs')).createSync();
    database = AppDatabase(NativeDatabase.memory());
    final store = ExtensionEntityStore(database);
    workspaces = WorkspaceProvider(store: store);
    workspace = await workspaces.create(
      name: 'Test',
      kind: WorkspaceKind.linked,
      hostPath: workspaceDir.path,
    );
    skills = SkillsService(
      store: store,
      skillsDirectory: Directory(p.join(tmp.path, 'skills')),
    );
    await skills.loaded;
    await skills.importFromText(
      '---\nname: existing\ndescription: Keep choices\n---\n',
    );
    await skills.setEnabled('existing', false);
    await skills.incrementUseCount('existing');
  });

  tearDown(() async {
    skills.dispose();
    workspaces.dispose();
    await database.close();
    await tmp.delete(recursive: true);
  });

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  ]) {
    testWidgets(
      'agent changes refresh visible skill lists on $platform',
      (tester) async {
        tester.view.physicalSize = const Size(600, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final settings = SettingsProvider(createBusinessTestPreferences());
        final assistants = AssistantProvider(
          preferences: createBusinessTestPreferences(),
        );
        final mcp = McpProvider(preferences: createBusinessTestPreferences());
        final toolService = McpToolService();
        final chat = FakeChatService();
        final runtime = _InstallingRuntime();
        final runtimes = WorkspaceRuntimeProvider()..register(runtime);
        final registry = ToolRunRegistry();
        addTearDown(settings.dispose);
        addTearDown(assistants.dispose);
        addTearDown(mcp.dispose);
        addTearDown(toolService.dispose);
        addTearDown(chat.dispose);
        addTearDown(runtimes.dispose);
        addTearDown(registry.dispose);
        await tester.runAsync(
          () => Future.wait([settings.loaded, assistants.loaded]),
        );
        late BuildContext context;
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<SettingsProvider>.value(value: settings),
              ChangeNotifierProvider<AssistantProvider>.value(
                value: assistants,
              ),
              ChangeNotifierProvider<McpProvider>.value(value: mcp),
              ChangeNotifierProvider<McpToolService>.value(value: toolService),
              ChangeNotifierProvider<ChatService>.value(value: chat),
              ChangeNotifierProvider<WorkspaceProvider>.value(
                value: workspaces,
              ),
              ChangeNotifierProvider<WorkspaceRuntimeProvider>.value(
                value: runtimes,
              ),
              ChangeNotifierProvider<ToolRunRegistry>.value(value: registry),
              ChangeNotifierProvider<SkillsService>.value(value: skills),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder: (ctx) {
                    context = ctx;
                    return const Column(
                      children: [
                        Expanded(child: SkillsPane()),
                        ConversationSkillsPanel(
                          conversationId: 'chat',
                          assistant: null,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final sandboxed = platform != TargetPlatform.macOS;
        final handler = ToolHandlerService(contextProvider: context)
            .buildToolCallHandler(
              settings,
              null,
              workspaceContext: WorkspaceToolContext(
                workspace: workspace,
                binding: WorkspaceBinding(
                  workspaceId: workspace.id,
                  allowAll: true,
                ),
                paths: sandboxed
                    ? WorkspacePaths.sandboxed(
                        workspaceHostRoot: workspaceDir.path,
                        sessionHostDir: sessionDir.path,
                        skillsHostDir: skills.skillsDirectory.path,
                      )
                    : WorkspacePaths.native(
                        workspaceHostRoot: workspaceDir.path,
                        sessionHostDir: sessionDir.path,
                        skillsHostDir: skills.skillsDirectory.path,
                      ),
                sessionDir: sessionDir,
                outputsDir: Directory(p.join(sessionDir.path, 'outputs')),
                runtimeStatus: RuntimeStatus(
                  ready: true,
                  engine: 'test',
                  sandboxed: sandboxed,
                ),
              ),
            )!;
        final installed = Directory(
          p.join(skills.skillsDirectory.path, 'agent-installed'),
        );
        Future<void> run(Future<void> Function() action) async {
          runtime.action = action;
          await tester.runAsync(() async {
            final result = await handler('shell', {
              'command': 'install or update a skill',
            }, toolCallId: 'run');
            expect(
              WorkspaceToolMetadata.fromJson(
                ClientToolResult.fromHandler(result).metadata!,
              ).status,
              'ok',
            );
          });
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        expect(find.text('Agent skill'), findsNothing);
        await run(() async {
          await installed.create();
          await File(p.join(installed.path, 'SKILL.md')).writeAsString(
            '---\nname: Agent skill\ndescription: Installed by a command\n---\n',
          );
        });
        expect(find.text('Agent skill'), findsNWidgets(2));
        expect(
          skills.resolveForAssistant(null).single.record.id,
          'agent-installed',
        );
        expect(
          skills.skills
              .firstWhere((s) => s.record.id == 'existing')
              .record
              .enabled,
          isFalse,
        );
        expect(
          skills.skills
              .firstWhere((s) => s.record.id == 'existing')
              .record
              .useCount,
          1,
        );

        await run(
          () => File(p.join(installed.path, 'SKILL.md')).writeAsString(
            '---\nname: Renamed skill\ndescription: Updated by a command\n---\n',
          ),
        );
        expect(find.text('Agent skill'), findsNothing);
        expect(find.text('Renamed skill'), findsNWidgets(2));
        await run(() => installed.delete(recursive: true));
        expect(find.text('Renamed skill'), findsNothing);
        expect(skills.resolveForAssistant(null), isEmpty);
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }
}
