import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/core/models/context_operation.dart';
import 'package:Kelivo/core/models/image_context.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/services/api/request_image_context.dart';
import 'package:Kelivo/core/services/api/tool_result_content.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/services/mcp/mcp_tool_service.dart';
import 'package:Kelivo/features/home/services/tool_handler_service.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/mcp/mcp_image_snapshot.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';
import '../../../support/claude_test_api.dart' show FakePathProviderPlatform;
import '../../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late PathProviderPlatform originalPaths;
  late ChatService service;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('chat_image_assets_');
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

  Future<({File file, ChatMessage upload, Map<String, dynamic> event})>
  uploadAndRead() async {
    final file = File('${root.path}/upload/photo.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );
    final conversation = await service.createConversation(title: 'Image');
    final upload = await service.addMessage(
      conversationId: conversation.id,
      role: 'user',
      parts: [
        ImagePart(
          uri: SandboxPathResolver.canonicalize(file.path),
          mime: 'image/png',
        ),
      ],
    );
    final context = RequestImageContext(
      settings: const ImageContextSettings(),
      images: RequestImageContext.collect([upload]),
    );
    final result = context.readImage(context.images.single.handle);
    return (
      file: file,
      upload: upload,
      event: {
        'id': 'read',
        'name': 'view_image',
        'arguments': {'image_id': context.images.single.handle},
        'content': result.content,
        'metadata': result.metadata,
      },
    );
  }

  Future<void> collectDueAssets() => service.runAssetMaintenance(
    now: DateTime.now().toUtc().add(const Duration(days: 8)),
  );

  testWidgets('the live tool handler lists and reads a persisted attachment', (
    tester,
  ) async {
    final source = (await tester.runAsync(uploadAndRead))!;
    final target = (await tester.runAsync(
      () => service.addMessage(
        conversationId: source.upload.conversationId,
        role: 'assistant',
        content: '',
      ),
    ))!;
    final assistants = AssistantProvider(
      preferences: createBusinessTestPreferences(),
    );
    final mcp = McpProvider(preferences: createBusinessTestPreferences());
    final tools = McpToolService();
    final settings = SettingsProvider(createBusinessTestPreferences());
    addTearDown(assistants.dispose);
    addTearDown(mcp.dispose);
    addTearDown(tools.dispose);
    addTearDown(settings.dispose);
    await settings.loaded;
    await assistants.loaded;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ChatService>.value(value: service),
          ChangeNotifierProvider<AssistantProvider>.value(value: assistants),
          ChangeNotifierProvider<McpProvider>.value(value: mcp),
          ChangeNotifierProvider<McpToolService>.value(value: tools),
        ],
        child: const SizedBox.shrink(),
      ),
    );
    final handler =
        ToolHandlerService(
          contextProvider: tester.element(find.byType(SizedBox)),
        ).buildToolCallHandler(
          settings,
          null,
          conversationId: source.upload.conversationId,
        )!;
    final context = RequestImageContext(
      settings: const ImageContextSettings(),
      images: RequestImageContext.collect([source.upload]),
      targetMessageId: target.id,
    );
    await tester.runAsync(
      () => context.run(() async* {
        final listed = ClientToolResult.fromHandler(
          await handler('view_image', {}),
        );
        final images = (jsonDecode(listed.content) as Map)['images'] as List;
        expect(images, hasLength(1));
        final imageId = images.single['image_id'];
        final guessed = ClientToolResult.fromHandler(
          await handler('view_image', {'image_id': 'img_1'}),
        );
        expect(guessed.metadata, isNull);
        final read = ClientToolResult.fromHandler(
          await handler('view_image', {'image_id': imageId}),
        );
        expect(read.metadata, isNotNull);
        final pixels = await ToolResultContent.read(
          'view_image',
          read.content,
          metadata: read.metadata,
        );
        expect(pixels.imageUrls, hasLength(1));
        final request = await context.project({
          'input': [
            {
              'type': 'function_call_output',
              'call_id': 'read',
              'output': [
                {'type': 'input_image', 'image_url': pixels.imageUrls.single},
              ],
            },
          ],
        });
        expect(
          request['input'][0]['output'][0]['image_url'],
          startsWith('data:image/png;base64,'),
        );
        yield 0;
      }).drain<void>(),
    );
  });

  for (final writer in ['parts', 'events', 'upsert']) {
    test(
      '$writer retains a recalled upload after its message is deleted',
      () async {
        final source = await uploadAndRead();
        final saved = await service.addMessage(
          conversationId: source.upload.conversationId,
          role: 'assistant',
          parts: [
            if (writer == 'parts') ToolCallPart(jsonEncode(source.event)),
          ],
        );
        if (writer == 'events') {
          await service.setToolEvents(saved.id, [source.event]);
        } else if (writer == 'upsert') {
          await service.upsertToolEvent(
            saved.id,
            id: 'read',
            name: 'view_image',
            arguments: source.event['arguments'] as Map<String, dynamic>,
            content: source.event['content'] as String,
            metadata: source.event['metadata'] as Map<String, dynamic>,
          );
        }
        final repo = service.chatRepositoryOrNull!;
        expect(await repo.getMessageImageContentHashes(saved.id), hasLength(1));
        expect(await repo.hasPendingAssetReferenceSync(), isFalse);
        await service.deleteMessage(source.upload.id);
        await collectDueAssets();
        expect(await source.file.exists(), isTrue);
        await service.deleteConversation(saved.conversationId);
        await collectDueAssets();
        expect(await source.file.exists(), isFalse);
      },
    );
  }

  test(
    'renaming the viewer preserves ownership of saved observations',
    () async {
      final source = await uploadAndRead();
      final saved = await service.addMessage(
        conversationId: source.upload.conversationId,
        role: 'assistant',
        parts: [
          ToolCallPart(
            jsonEncode({...source.event, 'name': 'read_chat_image'}),
          ),
        ],
      );
      final images = RequestImageContext.collect([saved]);
      expect(images.single.materializationKey, contains(source.upload.id));
      expect(images.single.workspaceSnapshot, isTrue);
      await service.deleteMessage(source.upload.id);
      await collectDueAssets();
      expect(await source.file.exists(), isTrue);
    },
  );

  for (final preserveVersions in [false, true]) {
    test(
      'summary and fork retain an unindexed read, versions=$preserveVersions',
      () async {
        final source = await uploadAndRead();
        final saved = await service.addMessage(
          conversationId: source.upload.conversationId,
          role: 'assistant',
          content: 'Recalled image',
        );
        final repo = service.chatRepositoryOrNull!;
        // A persisted tool overlay may still be awaiting the asset backfill.
        await repo.setToolEvents(saved.id, [source.event]);
        expect(await repo.getMessageImageContentHashes(saved.id), isEmpty);
        final snapshot = await repo.readContextSnapshot(saved.conversationId);
        final retained = snapshot.messages.singleWhere((m) => m.id == saved.id);
        final compressed = await service.createCompressedConversation(
          saved.conversationId,
          ContextOperation(
            id: 'summary',
            kind: ContextOperationKind.compress,
            anchorGroupId: source.upload.groupId ?? source.upload.id,
            appliedAfterGroupId: saved.groupId ?? saved.id,
            sourceGroups: [source.upload.groupId ?? source.upload.id],
            dependencies: const [],
            createdAt: DateTime.now(),
            summary: 'The earlier upload has been summarized.',
          ),
          expectedFingerprint: snapshot.fingerprint,
          retained: [retained],
        );
        await service.deleteConversation(saved.conversationId);
        await collectDueAssets();
        expect(
          await source.file.exists(),
          isTrue,
          reason:
              'The copied dirty read must protect the asset before backfill',
        );
        await service.runAssetReferenceMaintenance();
        final copied = (await repo.readContextSnapshot(
          compressed.id,
        )).messages.last;
        expect(
          await repo.getMessageImageContentHashes(copied.id),
          hasLength(1),
        );
        final fork = await service.forkConversationAtRevision(
          sourceConversationId: compressed.id,
          sourceRevisionId: copied.id,
          preserveVersions: preserveVersions,
        );
        await service.deleteConversation(compressed.id);
        await collectDueAssets();
        expect(await source.file.exists(), isTrue);
        final replay = RequestImageContext(
          settings: const ImageContextSettings(),
          images: RequestImageContext.collect(
            await service.imageContextHistory(fork.id),
          ),
        );
        expect(replay.images, hasLength(1));
        final body = await replay.project({
          'input': [
            {
              'type': 'function_call_output',
              'call_id': 'read',
              'output': [
                {
                  'type': 'input_image',
                  'image_url': replay.images.single.reference,
                },
              ],
            },
          ],
        });
        expect(
          body['input'][0]['output'][0]['image_url'],
          startsWith('data:image/png;base64,'),
        );
        await service.deleteConversation(fork.id);
        await collectDueAssets();
        expect(await source.file.exists(), isFalse);
      },
    );
  }

  test(
    'generation finalization indexes a newly returned read result',
    () async {
      final source = await uploadAndRead();
      final generation = await service.beginSendGeneration(
        conversationId: source.upload.conversationId,
        userParts: const [TextPart('Read the old image again')],
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
        toolEvents: [source.event],
        generationRunId: run.id,
        expectedState: run.state,
        expectedStateRevision: run.stateRevision,
        terminalState: GenerationRunState.completed,
      );
      expect(
        await service.chatRepositoryOrNull!.getMessageImageContentHashes(
          generation.assistantMessage.id,
        ),
        hasLength(1),
      );
      await service.deleteMessage(source.upload.id);
      await collectDueAssets();
      expect(await source.file.exists(), isTrue);
    },
  );

  test(
    'a merged snapshot retains a read after the original upload is gone',
    () async {
      final source = await uploadAndRead();
      final saved = await service.addMessage(
        conversationId: source.upload.conversationId,
        role: 'assistant',
        parts: [ToolCallPart(jsonEncode(source.event))],
      );
      await service.deleteMessage(source.upload.id);
      final snapshot = File('${root.path}/image-backup.sqlite');
      await service.createBackupDatabaseSnapshot(snapshot);
      await service.deleteConversation(saved.conversationId);
      final report = await service.mergeDatabaseSnapshot(snapshot);
      expect(report.importedConversationIds, hasLength(1));
      await collectDueAssets();
      expect(await source.file.exists(), isTrue);
      final restored = (await service.chatRepositoryOrNull!.readContextSnapshot(
        report.importedConversationIds.single,
      )).messages.single;
      expect(
        await service.chatRepositoryOrNull!.getMessageImageContentHashes(
          restored.id,
        ),
        hasLength(1),
      );
      await service.deleteConversation(restored.conversationId);
      await collectDueAssets();
      expect(await source.file.exists(), isFalse);
    },
  );

  test('a recalled browser snapshot survives removal of its preview', () async {
    final snapshot = (await McpImageSnapshot.saveBytes(
      img.encodePng(img.Image(width: 3, height: 2)),
      deduplicate: true,
    ))!;
    final file = (await McpImageSnapshot.localFile(snapshot.uri))!;
    final conversation = await service.createConversation(title: 'Browser');
    final browser = await service.addMessage(
      conversationId: conversation.id,
      role: 'assistant',
      parts: [
        ToolCallPart(
          jsonEncode({
            'id': 'browser',
            'name': 'browser',
            'metadata': {
              'browser': {'previewImage': snapshot.uri},
              kMcpResultMetadataKey: mcpResultMetadata([snapshot.uri]),
            },
          }),
        ),
      ],
    );
    final request = RequestImageContext(
      settings: const ImageContextSettings(),
      images: RequestImageContext.collect([browser]),
    );
    final read = request.readImage(request.images.single.handle);
    expect(read.metadata!['chatImage']['directAsset'], isFalse);
    final saved = await service.addMessage(
      conversationId: conversation.id,
      role: 'assistant',
      parts: [
        ToolCallPart(
          jsonEncode({
            'id': 'read',
            'name': 'view_image',
            'content': read.content,
            'metadata': read.metadata,
          }),
        ),
      ],
    );
    expect(
      await service.chatRepositoryOrNull!.getMessageImageContentHashes(
        saved.id,
      ),
      hasLength(1),
    );
    await service.deleteMessage(browser.id);
    await collectDueAssets();
    expect(await file.exists(), isTrue);
    await service.deleteConversation(conversation.id);
    await collectDueAssets();
    expect(await file.exists(), isFalse);
  });

  for (final forgedKind in ['ordinary MCP', 'non-direct reader']) {
    test('$forgedKind cannot retain or directly read an upload', () async {
      final source = await uploadAndRead();
      final metadata = source.event['metadata'] as Map<String, dynamic>;
      final forged = {
        ...source.event,
        if (forgedKind == 'ordinary MCP')
          'name': 'external_mcp_tool'
        else
          'metadata': {
            ...metadata,
            'chatImage': {
              ...metadata['chatImage'] as Map,
              'directAsset': false,
            },
          },
      };
      final saved = await service.addMessage(
        conversationId: source.upload.conversationId,
        role: 'assistant',
        parts: [ToolCallPart(jsonEncode(forged))],
      );
      expect(
        await service.chatRepositoryOrNull!.getMessageImageContentHashes(
          saved.id,
        ),
        isEmpty,
      );
      expect(await McpImageSnapshot.localFile(source.file.path), isNull);
      final replay = RequestImageContext(
        settings: const ImageContextSettings(),
        images: RequestImageContext.collect([saved]),
      );
      final body = await replay.project({
        'input': [
          {
            'type': 'function_call_output',
            'call_id': 'read',
            'output': [
              {
                'type': 'input_image',
                'image_url': replay.images.single.reference,
              },
            ],
          },
        ],
      });
      expect(body['input'][0]['output'][0]['type'], 'input_text');
      await service.deleteMessage(source.upload.id);
      await collectDueAssets();
      expect(await source.file.exists(), isFalse);
    });
  }
}
