import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/database/business_restore_service.dart';
import 'package:Kelivo/core/models/skill_record.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/backup/data_sync.dart';
import 'package:Kelivo/core/services/workspace/host_file_tools.dart';
import 'package:Kelivo/core/services/workspace/workspace_paths.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/core/services/workspace/workspace_tools_service.dart';

class PausedRuntime extends WorkspaceRuntime {
  final started = Completer<void>();
  final finish = Completer<void>();
  @override
  Future<RuntimeStatus> status() async =>
      const RuntimeStatus(ready: true, engine: 'fake', sandboxed: true);
  @override
  Stream<CommandEvent> run(CommandRequest request) async* {
    started.complete();
    yield const CommandStarted();
    await finish.future;
    yield const CommandExited(
      exitCode: 0,
      timedOut: false,
      cancelled: false,
      interrupted: false,
      duration: Duration.zero,
    );
  }

  @override
  Future<void> cancel(String runId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late WorkspacePaths paths;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('kelivo-workspace-integrity-');
    for (final name in ['ws', 'session', 'skills', 'session/outputs']) {
      await Directory('${temp.path}/$name').create(recursive: true);
    }
    paths = WorkspacePaths.sandboxed(
      workspaceHostRoot: '${temp.path}/ws',
      sessionHostDir: '${temp.path}/session',
      skillsHostDir: '${temp.path}/skills',
    );
  });
  tearDown(() => temp.delete(recursive: true));

  test(
    'read_file respects its documented 32 KiB cap for one long line',
    () async {
      await File(
        '${temp.path}/ws/minified.json',
      ).writeAsString('x' * (128 * 1024));
      final result = await HostFileTools(
        paths,
      ).readFile('/workspace/minified.json', limit: 1);
      expect(
        utf8.encode(result.text!).length,
        lessThanOrEqualTo(HostFileTools.readCapBytes),
      );
    },
  );

  test('finishing an old shell preserves switching workspaces', () async {
    final runtime = PausedRuntime();
    final provider = WorkspaceRuntimeProvider()..register(runtime);
    var extras = const WorkspaceBinding(workspaceId: 'ws-a').applyTo({});
    final service = WorkspaceToolsService(
      runtimeProvider: provider,
      updateConversationExtras: (id, update) async {
        extras = update(extras);
      },
    );
    final now = DateTime.utc(2026);
    final context = WorkspaceToolContext(
      workspace: Workspace(
        id: 'ws-a',
        name: 'A',
        kind: WorkspaceKind.managed,
        createdAt: now,
        updatedAt: now,
      ),
      binding: WorkspaceBinding.fromExtras(extras),
      paths: paths,
      sessionDir: Directory(paths.sessionHostDir),
      outputsDir: Directory('${paths.sessionHostDir}/outputs'),
      conversationId: 'conv',
      runtimeRegistered: true,
      runtimeStatus: await runtime.status(),
    );
    final running = service.handle(context, 'shell', {
      'command': 'sleep 1',
    }, toolCallId: 'run-a');
    await runtime.started.future;
    extras = const WorkspaceBinding(
      workspaceId: 'ws-b',
      cwd: 'new-cwd',
    ).applyTo(extras);
    runtime.finish.complete();
    await running;
    expect(WorkspaceBinding.fromExtras(extras).workspaceId, 'ws-b');
    expect(WorkspaceBinding.fromExtras(extras).cwd, 'new-cwd');
  });

  test('finishing an old shell preserves unbinding workspace', () async {
    final runtime = PausedRuntime();
    final provider = WorkspaceRuntimeProvider()..register(runtime);
    var extras = const WorkspaceBinding(workspaceId: 'ws-a').applyTo({});
    final service = WorkspaceToolsService(
      runtimeProvider: provider,
      updateConversationExtras: (id, update) async {
        extras = update(extras);
      },
    );
    final now = DateTime.utc(2026);
    final context = WorkspaceToolContext(
      workspace: Workspace(
        id: 'ws-a',
        name: 'A',
        kind: WorkspaceKind.managed,
        createdAt: now,
        updatedAt: now,
      ),
      binding: WorkspaceBinding.fromExtras(extras),
      paths: paths,
      sessionDir: Directory(paths.sessionHostDir),
      outputsDir: Directory('${paths.sessionHostDir}/outputs'),
      conversationId: 'conv',
      runtimeRegistered: true,
      runtimeStatus: await runtime.status(),
    );
    final running = service.handle(context, 'shell', {
      'command': 'sleep 1',
    }, toolCallId: 'run-a');
    await runtime.started.future;
    extras = const WorkspaceBinding().applyTo(extras);
    runtime.finish.complete();
    await running;
    expect(WorkspaceBinding.fromExtras(extras).workspaceId, null);
    expect(WorkspaceBinding.fromExtras(extras).cwd, '');
  });

  test(
    'finishing an old shell preserves changing current workspace options',
    () async {
      final runtime = PausedRuntime();
      final provider = WorkspaceRuntimeProvider()..register(runtime);
      var extras = const WorkspaceBinding(workspaceId: 'ws-a').applyTo({});
      final service = WorkspaceToolsService(
        runtimeProvider: provider,
        updateConversationExtras: (id, update) async {
          extras = update(extras);
        },
      );
      final now = DateTime.utc(2026);
      final context = WorkspaceToolContext(
        workspace: Workspace(
          id: 'ws-a',
          name: 'A',
          kind: WorkspaceKind.managed,
          createdAt: now,
          updatedAt: now,
        ),
        binding: WorkspaceBinding.fromExtras(extras),
        paths: paths,
        sessionDir: Directory(paths.sessionHostDir),
        outputsDir: Directory('${paths.sessionHostDir}/outputs'),
        conversationId: 'conv',
        runtimeRegistered: true,
        runtimeStatus: await runtime.status(),
      );
      final running = service.handle(context, 'shell', {
        'command': 'sleep 1',
      }, toolCallId: 'run-a');
      await runtime.started.future;
      extras = const WorkspaceBinding(
        workspaceId: 'ws-a',
        cwd: 'new-cwd',
        allowAll: true,
      ).applyTo(extras);
      runtime.finish.complete();
      await running;
      expect(WorkspaceBinding.fromExtras(extras).workspaceId, 'ws-a');
      expect(WorkspaceBinding.fromExtras(extras).cwd, 'new-cwd');
      expect(WorkspaceBinding.fromExtras(extras).allowAll, isTrue);
      expect(WorkspaceBinding.fromExtras(extras).toolsUsed, isTrue);
    },
  );

  for (final merge in [false, true]) {
    test(
      'settings backup restores workspace and disabled skill metadata (merge=$merge)',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        final target = AppDatabase(NativeDatabase.memory());
        try {
          final store = ExtensionEntityStore(db);
          final workspace = Workspace(
            id: 'backup-ws',
            name: 'Backup',
            kind: WorkspaceKind.managed,
            shellNeedsApproval: true,
            disabledTools: const {'edit_file'},
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          );
          await store.upsert('workspace', workspace.id, workspace.toJson());
          final skill = SkillRecord(
            id: 'skill-one',
            enabled: false,
            useCount: 7,
            source: SkillSource.file,
            installedAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          );
          await store.upsert('skill', skill.id, skill.toJson());
          await store.upsert('externalMounts', 'global', {
            'localGrant': 'do-not-export',
          });
          final exported = await DataSync.exportBusinessSettingsFrom(
            BusinessRepository(db),
          );
          expect(exported.settingsJson, isNot(contains('do-not-export')));
          final settings = Map<String, Object?>.from(
            jsonDecode(exported.settingsJson) as Map,
          );
          final restore = BusinessRestoreService(BusinessRepository(target));
          if (merge) {
            await restore.merge(settings);
          } else {
            await restore.overwrite(settings);
          }
          final restored = ExtensionEntityStore(target);
          final provider = WorkspaceProvider(store: restored);
          await provider.loaded;
          expect(provider.byId(workspace.id), workspace);
          provider.dispose();
          expect(
            (await restored.get('workspace', 'backup-ws'))?.payload['name'],
            'Backup',
          );
          expect(
            (await restored.get('skill', skill.id))?.payload,
            skill.toJson(),
          );
        } finally {
          await db.close();
          await target.close();
        }
      },
    );
  }

  test(
    'snapshot merge retains the workspace referenced by the imported chat',
    () async {
      final sourceFile = File('${temp.path}/source.sqlite');
      final sourceDb = AppDatabase(NativeDatabase(sourceFile));
      final targetDb = AppDatabase(NativeDatabase.memory());
      final source = ChatDatabaseRepository(sourceDb);
      final target = ChatDatabaseRepository(targetDb);
      try {
        await source.ensureReady();
        await target.ensureReady();
        await ExtensionEntityStore(sourceDb).upsert('workspace', 'review-ws', {
          'id': 'review-ws',
          'name': 'Review',
        });
        await source.putMigrationBatch(
          conversations: [
            Conversation(
              id: 'review-conv',
              title: 'Review',
              extras: const WorkspaceBinding(
                workspaceId: 'review-ws',
              ).applyTo({}),
            ),
          ],
          messages: [],
          toolEventsByMessageId: {},
          geminiSignaturesByMessageId: {},
        );
        await source.markMigrationComplete();
        final snapshot = File('${temp.path}/snapshot.sqlite');
        await ChatDatabaseRepository.createConsistentSnapshot(
          sourceFile: sourceFile,
          destinationFile: snapshot,
        );
        final report = await target.mergeBackupSnapshot(snapshot);
        expect(report.importedConversations, 1);
        expect(
          await ExtensionEntityStore(targetDb).get('workspace', 'review-ws'),
          isNotNull,
        );
      } finally {
        await source.close();
        await target.close();
      }
    },
  );
}
