import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:sqlite3/sqlite3.dart' as sqlite;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/services/mcp/mcp_image_snapshot.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';
import '../../../support/claude_test_api.dart' show FakePathProviderPlatform;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late PathProviderPlatform originalPaths;
  late ChatService service;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('browser_preview_assets_');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = FakePathProviderPlatform(root.path);
    SandboxPathResolver.debugSetDirs(docsDir: root.path, supportDir: root.path);
    service = ChatService();
    await service.init();
  });
  tearDown(() async {
    await service.close();
    await Hive.close();
    PathProviderPlatform.instance = originalPaths;
    SandboxPathResolver.debugSetDirs();
    await root.delete(recursive: true);
  });

  Map<String, dynamic> event(String uri) => {
    'id': 'step',
    'name': 'browser',
    'arguments': {'action': 'open'},
    'content': '{"ok":true}',
    'metadata': {
      'browser': {'previewImage': uri},
    },
  };

  Future<File> image() async {
    final file = File('${root.path}/images/mcp_img_preview.png');
    await file.parent.create(recursive: true);
    await file.writeAsString('immutable browser preview');
    return file;
  }

  test(
    'a preview reused as an assistant background survives conversation GC',
    () async {
      final file = await image();
      final uri = SandboxPathResolver.canonicalize(file.path);
      final conversation = await service.createConversation(title: 'Browser');
      await service.addMessage(
        conversationId: conversation.id,
        role: 'assistant',
        parts: [ToolCallPart(jsonEncode(event(uri)))],
      );
      final database = sqlite.sqlite3.open(
        '${root.path}/${AppDatabase.databaseFileName}',
      );
      try {
        database.execute(
          'INSERT INTO assistant_rows (id, sort_order, payload, updated_at) VALUES (?, ?, ?, ?)',
          [
            'appearance',
            0,
            jsonEncode({'id': 'appearance', 'name': 'A', 'background': uri}),
            1,
          ],
        );
        await service.deleteConversation(conversation.id);
        await service.runAssetMaintenance(
          now: DateTime.now().toUtc().add(const Duration(days: 8)),
        );
        expect(await file.exists(), isTrue);
        expect(
          await service.chatRepositoryOrNull!.claimAssetGc(
            now: DateTime.now().toUtc().add(const Duration(days: 8)),
          ),
          isEmpty,
          reason: 'Protected images must not monopolize the next GC batch',
        );
        database.execute("DELETE FROM assistant_rows WHERE id = 'appearance'");
        await service.runAssetMaintenance(
          now: DateTime.now().toUtc().add(const Duration(days: 9)),
        );
        expect(await file.exists(), isFalse);
      } finally {
        database.close();
      }
    },
  );

  for (final writer in ['parts', 'events', 'upsert']) {
    test('$writer registers preview ownership and delayed deletion', () async {
      final file = await image();
      final uri = SandboxPathResolver.canonicalize(file.path);
      final conversation = await service.createConversation(title: 'Browser');
      final message = await service.addMessage(
        conversationId: conversation.id,
        role: 'assistant',
        parts: [if (writer == 'parts') ToolCallPart(jsonEncode(event(uri)))],
      );
      if (writer == 'events') {
        await service.setToolEvents(message.id, [event(uri)]);
      } else if (writer == 'upsert') {
        await service.upsertToolEvent(
          message.id,
          id: 'step',
          name: 'browser',
          arguments: {'action': 'open'},
          metadata: event(uri)['metadata'] as Map<String, dynamic>,
        );
      }
      final repo = service.chatRepositoryOrNull!;
      expect(await repo.getMessageImageContentHashes(message.id), hasLength(1));
      expect(await repo.hasPendingAssetReferenceSync(), isFalse);
      await service.deleteConversation(conversation.id);
      expect(
        await file.exists(),
        isTrue,
        reason: 'Keep the normal GC grace period',
      );
      await service.runAssetMaintenance(
        now: DateTime.now().toUtc().add(const Duration(days: 8)),
      );
      expect(await file.exists(), isFalse);
    });
  }

  for (final preserveVersions in [false, true]) {
    test('fork retains shared preview, versions=$preserveVersions', () async {
      final file = await image();
      final conversation = await service.createConversation(title: 'Browser');
      final message = await service.addMessage(
        conversationId: conversation.id,
        role: 'assistant',
        parts: [
          ToolCallPart(
            jsonEncode(event(SandboxPathResolver.canonicalize(file.path))),
          ),
        ],
      );
      final fork = await service.forkConversationAtRevision(
        sourceConversationId: conversation.id,
        sourceRevisionId: message.id,
        title: 'Copy',
        preserveVersions: preserveVersions,
      );
      await service.deleteConversation(conversation.id);
      await service.runAssetMaintenance(
        now: DateTime.now().toUtc().add(const Duration(days: 8)),
      );
      expect(await file.exists(), isTrue);
      await service.deleteConversation(fork.id);
      await service.runAssetMaintenance(
        now: DateTime.now().toUtc().add(const Duration(days: 8)),
      );
      expect(await file.exists(), isFalse);
    });
  }

  test('optional missing and unowned previews do not become assets', () async {
    final file = File('${root.path}/images/unowned.png');
    await file.parent.create(recursive: true);
    await file.writeAsString('unowned');
    final conversation = await service.createConversation(title: 'Invalid');
    for (final uri in [
      file.path,
      'kelivo-file:///images/mcp_img_missing.png',
      'https://example.com/mcp_img_remote.png',
    ]) {
      final message = await service.addMessage(
        conversationId: conversation.id,
        role: 'assistant',
        parts: [ToolCallPart(jsonEncode(event(uri)))],
      );
      final repo = service.chatRepositoryOrNull!;
      expect(await repo.getMessageImageContentHashes(message.id), isEmpty);
      expect(await repo.hasPendingAssetReferenceSync(), isFalse);
    }
  });

  test('tool-only repository writes can be indexed by maintenance', () async {
    final file = await image();
    final conversation = await service.createConversation(title: 'Browser');
    final message = await service.addMessage(
      conversationId: conversation.id,
      role: 'assistant',
      content: 'Tool result',
    );
    final repo = service.chatRepositoryOrNull!;
    await repo.setToolEvents(message.id, [
      event(SandboxPathResolver.canonicalize(file.path)),
    ]);
    expect(await repo.hasPendingAssetReferenceSync(), isTrue);
    await service.runAssetReferenceMaintenance();
    expect(await repo.getMessageImageContentHashes(message.id), hasLength(1));
    expect(await repo.hasPendingAssetReferenceSync(), isFalse);
  });

  for (final cached in [false, true]) {
    test(
      'reused preview survives GC before the next checkpoint, cached=$cached',
      () async {
        final bytes = img.encodePng(img.Image(width: 3, height: 2));
        final saved = (await McpImageSnapshot.saveBytes(
          bytes,
          deduplicate: true,
        ))!;
        final file = (await McpImageSnapshot.localFile(saved.uri))!;
        final old = await service.createConversation(title: 'Old');
        await service.addMessage(
          conversationId: old.id,
          role: 'assistant',
          parts: [ToolCallPart(jsonEncode(event(saved.uri)))],
        );
        await service.deleteConversation(old.id);
        final past = DateTime.now().toUtc().subtract(const Duration(days: 8));
        await file.setLastModified(past);
        final db = sqlite.sqlite3.open(
          '${root.path}/${AppDatabase.databaseFileName}',
        );
        try {
          db.execute('UPDATE asset_gc_rows SET not_before = ?;', [
            past.microsecondsSinceEpoch,
          ]);
        } finally {
          db.close();
        }
        if (cached) {
          expect(await McpImageSnapshot.reuseLocalFile(saved.uri), isNotNull);
        } else {
          expect(
            (await McpImageSnapshot.saveBytes(bytes, deduplicate: true))!.uri,
            saved.uri,
          );
        }
        // The tool has a result, but the next message checkpoint has not landed.
        await service.runAssetMaintenance();
        expect(await file.exists(), isTrue);
        final next = await service.createConversation(title: 'Next');
        final message = await service.addMessage(
          conversationId: next.id,
          role: 'assistant',
          parts: [ToolCallPart(jsonEncode(event(saved.uri)))],
        );
        expect(
          await service.chatRepositoryOrNull!.getMessageImageContentHashes(
            message.id,
          ),
          hasLength(1),
        );
        await service.deleteConversation(next.id);
        await service.runAssetMaintenance(
          now: DateTime.now().toUtc().add(const Duration(days: 8)),
        );
        expect(await file.exists(), isFalse);
      },
    );
  }

  test('merged backup registers restored preview before pending GC', () async {
    final file = await image();
    final conversation = await service.createConversation(title: 'Browser');
    await service.addMessage(
      conversationId: conversation.id,
      role: 'assistant',
      parts: [
        ToolCallPart(
          jsonEncode(event(SandboxPathResolver.canonicalize(file.path))),
        ),
      ],
    );
    final snapshot = File('${root.path}/browser-backup.sqlite');
    await service.createBackupDatabaseSnapshot(snapshot);
    await service.deleteConversation(conversation.id);
    final report = await service.mergeDatabaseSnapshot(snapshot);
    expect(report.importedConversationIds, hasLength(1));
    await service.runAssetMaintenance(
      now: DateTime.now().toUtc().add(const Duration(days: 8)),
    );
    expect(await file.exists(), isTrue);
    await service.deleteConversation(report.importedConversationIds.single);
    await service.runAssetMaintenance(
      now: DateTime.now().toUtc().add(const Duration(days: 8)),
    );
    expect(await file.exists(), isFalse);
  });

  for (final trackedRun in [false, true]) {
    test('finalize indexes latest tool overlay, tracked=$trackedRun', () async {
      final file = await image();
      final conversation = await service.createConversation(title: 'Browser');
      final generation = await service.beginSendGeneration(
        conversationId: conversation.id,
        userParts: const [TextPart('Open a page')],
        modelId: 'model',
        providerId: 'provider',
      );
      var run = await service.transitionGenerationRun(
        id: generation.run.id,
        expectedState: generation.run.state,
        expectedStateRevision: generation.run.stateRevision,
        nextState: GenerationRunState.requesting,
      );
      run = await service.transitionGenerationRun(
        id: run.id,
        expectedState: run.state,
        expectedStateRevision: run.stateRevision,
        nextState: GenerationRunState.streaming,
      );
      await service.finalizeGenerationRunSilent(
        message: generation.assistantMessage.copyWith(isStreaming: false),
        toolEvents: [event(SandboxPathResolver.canonicalize(file.path))],
        generationRunId: trackedRun ? run.id : null,
        expectedState: trackedRun ? run.state : null,
        expectedStateRevision: trackedRun ? run.stateRevision : null,
        terminalState: GenerationRunState.completed,
      );
      final repo = service.chatRepositoryOrNull!;
      expect(
        await repo.getMessageImageContentHashes(generation.assistantMessage.id),
        hasLength(1),
      );
      expect(await repo.hasPendingAssetReferenceSync(), isFalse);
    });
  }
}
