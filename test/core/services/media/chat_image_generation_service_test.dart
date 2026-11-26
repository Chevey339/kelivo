import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/media_repository.dart';
import 'package:Kelivo/core/models/image_context.dart';
import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/features/home/services/message_generation_service.dart';
import 'package:Kelivo/core/models/media_creation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/request_image_context.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_handler.dart';
import 'package:Kelivo/core/services/api/tool_call_cancellation.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/media/chat_image_generation_service.dart';
import 'package:Kelivo/core/services/media/media_file_store.dart';
import 'package:Kelivo/core/services/media/media_generation_runner.dart';
import 'package:Kelivo/core/services/media/media_models.dart';
import 'package:Kelivo/core/services/media/media_request.dart';
import 'package:Kelivo/core/services/tools/view_image_tool.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';
import 'package:Kelivo/utils/kelivo_file_uri.dart';
import 'package:Kelivo/core/services/tools/generate_image_tool.dart';
import 'package:Kelivo/features/home/services/message_builder_service.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';
import 'package:flutter/widgets.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as image;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../../support/business_test_harness.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getApplicationCachePath() async => '$root/cache';

  @override
  Future<String?> getTemporaryPath() async => '$root/tmp';
}

class _Context extends Fake implements BuildContext {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late AppDatabase database;
  late ChatDatabaseRepository repository;
  late MediaRepository media;
  late ChatService chat;
  late SettingsProvider settings;
  late String conversationId;
  late String messageId;
  late RequestImageContext context;
  final savedPng = base64Encode(
    image.encodePng(image.Image(width: 16, height: 12)),
  );
  final provider = ProviderConfig(
    id: 'image-test',
    name: 'Image Test',
    enabled: true,
    apiKey: 'fixture-key',
    baseUrl: 'https://images.example.test/v1',
    models: const ['gpt-image-2', 'dall-e-3'],
  );

  setUp(() async {
    final preferences = await createBusinessTestHarness();
    settings = SettingsProvider(preferences.preferences);
    await settings.loaded;
    await settings.setProviderConfig(provider.id, provider);
    await settings.setCreationModel(CreationModelSlot.image, (
      providerKey: provider.id,
      modelId: 'gpt-image-2',
    ));
    root = await Directory.systemTemp.createTemp('chat-creation-test');
    final previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root.path);
    addTearDown(() async {
      SandboxPathResolver.debugSetDirs();
      PathProviderPlatform.instance = previous;
      await root.delete(recursive: true);
    });
    SandboxPathResolver.debugSetDirs(docsDir: root.path);
    final dbFile = File('${root.path}/chat.sqlite');
    database = AppDatabase.open(file: dbFile);
    repository = ChatDatabaseRepository(database, databaseFile: dbFile);
    await repository.ensureReady();
    media = repository.mediaRepository;
    chat = ChatService(existingRepository: repository);
    await chat.init();
    addTearDown(() async {
      settings.dispose();
      await chat.close();
      await repository.close();
    });
    conversationId = (await chat.createConversation(title: 'Image chat')).id;
    await chat.addMessage(
      conversationId: conversationId,
      role: 'user',
      content: 'Draw a cat',
    );
    final message = await chat.addMessage(
      conversationId: conversationId,
      role: 'assistant',
      content: '',
      isStreaming: true,
    );
    messageId = message.id;
    context = RequestImageContext(
      ownsCreationImage: media.ownsImage,
      settings: const ImageContextSettings(),
      images: const [],
      targetMessageId: messageId,
    );
  });

  MediaGenerationRunner runner(MediaHttpClientFactory clientFactory) {
    final instance = MediaGenerationRunner(
      repository: media,
      files: MediaFileStore(
        directory: () async => Directory('${root.path}/generations'),
      ),
      clientFactory: clientFactory,
    );
    addTearDown(() async {
      await instance.shutdown();
      instance.dispose();
    });
    return instance;
  }

  ChatImageGenerationService service(MediaGenerationRunner runner) =>
      ChatImageGenerationService(
        runner: runner,
        chat: chat,
        settings: settings,
      );

  http.Response result() => http.Response(
    jsonEncode({
      'data': [
        {'b64_json': savedPng, 'revised_prompt': 'A cat in sunlight'},
      ],
    }),
    200,
  );

  test(
    'a generated handle can be viewed during its own turn with recall off',
    () async {
      const oldPart = ImagePart(
        uri: 'kelivo-file:///generations/a/old.png',
        generationItemId: 'old',
      );
      final creator = RequestImageContext(
        settings: const ImageContextSettings(),
        images: [],
        targetMessageId: 'previous',
      );
      final old = creator.registerGeneratedImage(oldPart);
      final request = RequestImageContext(
        settings: const ImageContextSettings(),
        images: creator.images,
        targetMessageId: messageId,
      );
      final candidate = ViewImageTool.withHistory();
      expect(
        RequestImageContext.toolsForRequest([candidate], imageContext: request),
        isEmpty,
      );
      final id = request.registerGeneratedImage(
        const ImagePart(
          uri: 'kelivo-file:///generations/b/new.png',
          generationItemId: 'new',
        ),
      );
      expect(
        RequestImageContext.toolsForRequest([candidate], imageContext: request),
        [candidate],
      );
      for (final arg in [
        id,
        'kelivo://chat/outputs/$id.png',
        '/chat/outputs/$id.png',
      ]) {
        expect(
          request
              .readImage(
                ViewImageTool.imageIdFromPath(arg)!,
                allowHistory: false,
                allowedMessages: {messageId},
              )
              .metadata,
          isNotNull,
        );
      }
      expect(request.readImage(old, allowHistory: false).metadata, isNull);
      expect(
        request.readImage(id, allowedMessages: {'foreign'}).metadata,
        isNull,
      );
      expect(
        request.readImage(id, excluded: {request.images.last.key}).metadata,
        isNull,
      );
      expect(ViewImageTool.imageIdFromPath('/work/$id.png'), isNull);
      for (final ctx in [
        RequestImageContext(
          settings: const ImageContextSettings(),
          images: [],
          targetMessageId: messageId,
          omitImages: true,
        ),
        RequestImageContext(
          settings: const ImageContextSettings(),
          images: [],
          targetMessageId: messageId,
          canImageInput: false,
        ),
      ]) {
        final handle = ctx.registerGeneratedImage(oldPart);
        expect(ctx.readImage(handle).metadata, isNull);
        expect(
          RequestImageContext.toolsForRequest([candidate], imageContext: ctx),
          isEmpty,
        );
      }
    },
  );

  test(
    'explicitly reattaching an original sends and recalls it as a user attachment',
    () async {
      final backend = runner((_, _) => MockClient((_) async => result()));
      final generated = await service(backend).run(
        {'prompt': 'Bird'},
        conversationId: conversationId,
        context: context,
        enabled: () => true,
      );
      final original = GenerateImageTool.attachment(generated.metadata)!;
      final path = SandboxPathResolver.resolveForIo(original.uri)!;
      final parts =
          await MessageGenerationService.buildPersistedUserMessageParts(
            ChatInputData(text: 'Look at this', imagePaths: [path]),
            assistant: null,
          );
      expect(
        parts.whereType<ImagePart>().single.generationItemId,
        original.generationItemId,
      );
      final message = ChatMessage(
        id: 'attached',
        role: 'user',
        content: 'Look at this',
        conversationId: conversationId,
        timestamp: DateTime.now(),
        parts: parts,
      );
      expect(MessageBuilderService.mediaRefsFromParts(message), hasLength(1));
      var checks = 0;
      final request = RequestImageContext(
        settings: const ImageContextSettings(allowRecall: true),
        images: RequestImageContext.collect([message]),
        latestUserId: message.id,
        ownsCreationImage: (uri) {
          checks++;
          return media.ownsImage(uri);
        },
      );
      final attached = request.images.single;
      expect(attached.identity.slot, 'part:1');
      await request.project({
        'messages': [
          {'role': 'user', 'content': 'hello'},
        ],
      });
      expect(checks, 0);
      final observed = request.readImage(attached.handle);
      final recalled = request
          .toolReferences(
            'view_image',
            mcpResultImageUris(readMcpResultMetadata(observed.metadata)),
            observed.metadata,
            'recalled',
          )
          .single;
      for (final ref in [attached.reference, recalled]) {
        final projected = await request.project({
          'input': [
            {
              'role': 'user',
              'content': [
                {'type': 'input_image', 'image_url': ref},
              ],
            },
          ],
        });
        expect(
          projected['input'][0]['content'][0]['image_url'],
          'data:image/png;base64,$savedPng',
        );
      }
    },
  );

  for (final shared in [false, true]) {
    test(
      'upgrade recovers a missing original and respects other upload owners (shared=$shared)',
      () async {
        await chat.runAssetReferenceMaintenance();
        final backend = runner((_, _) => MockClient((_) async => result()));
        final generated = await service(backend).run(
          {'prompt': 'Draw an image'},
          conversationId: conversationId,
          context: context,
          enabled: () => true,
        );
        final item = (await media.itemsForBatch(
          generated.metadata![GenerateImageTool.batchKey] as String,
        )).single;
        final source = File(SandboxPathResolver.resolveForIo(item.path)!);
        final uploads = await Directory(
          '${root.path}/upload',
        ).create(recursive: true);
        final old = await source.copy('${uploads.path}/old.png');
        const oldUri = 'kelivo-file:///upload/old.png';
        final legacyPart = ImagePart(
          uri: oldUri,
          mime: item.mime,
          generationItemId: item.id,
        );
        final metadata = {
          GenerateImageTool.batchKey: item.batchId,
          GenerateImageTool.attachmentKey: legacyPart.encodePayload(),
        };
        await chat.updateMessage(
          messageId,
          parts: [
            ToolCallPart(
              jsonEncode({
                'id': 'g',
                'name': GenerateImageTool.name,
                'metadata': metadata,
              }),
            ),
            legacyPart,
            ToolCallPart(
              jsonEncode({
                'id': 'v',
                'name': 'view_image',
                'metadata': {
                  'mcpResult': {
                    'imageUris': [oldUri],
                  },
                  'chatImage': {
                    'version': 1,
                    'sourceKey': '$messageId|creation:${item.id}|0',
                    'directAsset': true,
                    'mime': item.mime,
                  },
                },
              }),
            ),
          ],
          isStreaming: false,
        );
        if (shared) {
          await chat.addMessage(
            conversationId: conversationId,
            role: 'user',
            content: '',
            parts: [const ImagePart(uri: oldUri, mime: 'image/png')],
          );
        }
        await source.delete();
        await database.customStatement(
          "DELETE FROM chat_storage_meta_rows WHERE key='creation_chat_originals_v1'",
        );
        await chat.runAssetReferenceMaintenance();
        final saved = (await repository.getMessage(messageId))!;
        expect(saved.parts.whereType<ImagePart>().single.uri, item.path);
        final tools = saved.parts
            .whereType<ToolCallPart>()
            .map((p) => jsonDecode(p.payloadJson)['metadata'])
            .toList();
        expect(
          GenerateImageTool.attachment(
            Map<String, dynamic>.from(tools.first),
          )?.uri,
          item.path,
        );
        expect(tools.last['mcpResult']['imageUris'], [item.path]);
        expect(await source.readAsBytes(), base64Decode(savedPng));
        expect(await old.exists(), shared);
        // Simulate restarting between the SQLite commit and removing the file.
        if (!shared) await source.copy(old.path);
        await database
            .into(database.chatStorageMetaRows)
            .insertOnConflictUpdate(
              ChatStorageMetaRowsCompanion.insert(
                key: 'creation-copy/$oldUri',
                value: item.path,
              ),
            );
        final offline = await source.rename('${source.path}.offline');
        await chat.runAssetReferenceMaintenance();
        expect(
          await (database.select(
            database.chatStorageMetaRows,
          )..where((r) => r.key.equals('creation-copy/$oldUri'))).get(),
          hasLength(1),
        );
        await offline.rename(source.path);
        await chat.runAssetReferenceMaintenance();
        expect(await old.exists(), shared);
        expect(
          await (database.select(
            database.chatStorageMetaRows,
          )..where((r) => r.key.equals('creation-copy/$oldUri'))).get(),
          isEmpty,
        );
      },
    );
  }

  test(
    'restoring a backup preserves artwork identity across repeated relocations',
    () {
      const prefix = 'restored-e42a034f-d3fe-4fa1-b278-f3e6a9b86ce7-';
      final uri =
          'kelivo-file:///generations/batch/$prefix${prefix}an-image.png';
      expect(KelivoFileUri.generationImageItemId(uri), 'an-image');
      expect(
        KelivoFileUri.generationImageItemId(
          'kelivo-file:///generations/batch/refs/an-image.png',
        ),
        isNull,
      );
    },
  );

  test(
    'historical edit snapshots are shared only when the source and bytes agree',
    () async {
      await chat.runAssetReferenceMaintenance();
      final backend = runner((_, _) => MockClient((_) async => result()));
      final api = service(backend);
      final original = await api.run(
        {'prompt': 'Poster'},
        conversationId: conversationId,
        context: context,
        enabled: () => true,
      );
      final source = GenerateImageTool.attachment(original.metadata)!;
      final handle =
          jsonDecode(original.content)['images'][0]['image_id'] as String;
      final edit = await api.run(
        {
          'prompt': 'Recolor',
          'image_ids': [handle],
        },
        conversationId: conversationId,
        context: context,
        enabled: () => true,
      );
      final editId = edit.metadata![GenerateImageTool.batchKey] as String;
      final second = GenerateImageTool.attachment(edit.metadata)!;
      final dir = await Directory(
        '${root.path}/generations/$editId/refs',
      ).create(recursive: true);
      final src = File(SandboxPathResolver.resolveForIo(source.uri)!);
      final stored = await src.copy('${dir.path}/0.png'),
          independent = await src.copy('${dir.path}/1.png');
      final refs = [
        for (final f in [stored, independent])
          MediaReference(
            KelivoFileUri.encodeFromAbsolute(f.path, root: root.path)!,
          ),
      ];
      await media.updateBatch(
        editId,
        GenerationBatchRowsCompanion(
          referencesJson: Value(jsonEncode([for (final r in refs) r.toJson()])),
        ),
      );
      await chat.updateMessage(
        messageId,
        parts: [
          source,
          second,
          ToolCallPart(
            jsonEncode({
              'name': GenerateImageTool.name,
              'arguments': {
                'image_ids': [handle],
              },
              'metadata': edit.metadata,
            }),
          ),
        ],
        isStreaming: false,
      );
      await database.customStatement(
        "DELETE FROM chat_storage_meta_rows WHERE key='creation_chat_originals_v1'",
      );
      await chat.runAssetReferenceMaintenance();
      final linked = MediaReference.forBatch((await media.batch(editId))!);
      expect(linked.map((r) => r.path), [source.uri, refs.last.path]);
      expect(await stored.exists(), isFalse);
      expect(await independent.exists(), isTrue);
      expect(await src.exists(), isTrue);
      await media.deleteItem(source.generationItemId!);
      final removed = MediaReference.forBatch((await media.batch(editId))!);
      expect(removed.map((r) => r.unavailable), [true, false]);
      expect(await media.referencedFiles(), isNot(contains(source.uri)));
    },
  );

  test(
    'an overwrite restore relinks existing chat parts to the installed original',
    () async {
      final backend = runner((_, _) => MockClient((_) async => result()));
      final generated = await service(backend).run(
        {'prompt': 'Poster'},
        conversationId: conversationId,
        context: context,
        enabled: () => true,
      );
      final part = GenerateImageTool.attachment(generated.metadata)!;
      final read = context.readImage(
        context.images.single.handle,
        allowedMessages: {messageId},
      );
      final observed = Map<String, dynamic>.from(read.metadata!);
      // Deleting an artwork empties the reader result. Restoring the artwork
      // alone should reconnect that result through its stable source key.
      observed[kMcpResultMetadataKey] = mcpResultMetadata([]);
      await chat.updateMessage(
        messageId,
        parts: [
          part,
          ToolCallPart(
            jsonEncode({'name': 'view_image', 'metadata': observed}),
          ),
        ],
        isStreaming: false,
      );
      final moved = part.uri.replaceFirst(
        '/${part.generationItemId}.png',
        '/restored-387d08f1-b6ff-484a-a338-e46cce7b398e-${part.generationItemId}.png',
      );
      final old = File(SandboxPathResolver.resolveForIo(part.uri)!);
      await old.rename(SandboxPathResolver.resolveForIo(moved)!);
      await media.importFrom(
        media,
        overwrite: true,
        restoredPaths: {part.uri: moved},
      );
      await chat.runAssetReferenceMaintenance();
      final restored = (await repository.getMessage(
        messageId,
      ))!.parts.whereType<ImagePart>().single;
      expect(restored.uri, moved);
      final reader = (await repository.getMessage(
        messageId,
      ))!.parts.whereType<ToolCallPart>().single;
      expect(
        jsonDecode(reader.payloadJson)['metadata']['mcpResult']['imageUris'],
        [moved],
      );
      expect(await media.ownsImage(moved), true);
      expect(await old.exists(), false);
    },
  );

  test(
    'tool output becomes an owned image part and can be edited within the turn',
    () async {
      var calls = 0;
      final backend = runner(
        (_, _) => MockClient((request) async {
          calls++;
          if (calls == 1) {
            expect(request.url.path, '/v1/images/generations');
            expect(jsonDecode(request.body)['n'], 1);
          } else {
            expect(request.url.path, '/v1/images/edits');
            expect(
              ascii.decode(request.bodyBytes, allowInvalid: true),
              contains('name="image[]"'),
            );
          }
          return result();
        }),
      );
      final api = service(backend);
      final generated = await api.run(
        {'prompt': 'Draw a cat'},
        conversationId: conversationId,
        context: context,
        enabled: () => true,
      );
      final output = jsonDecode(generated.content) as Map<String, dynamic>;
      expect(output['model'], 'gpt-image-2');
      final handle = output['images'].single['image_id'] as String;
      expect(output['view_image'], {'image_id': handle});
      final observation = context.readImage(
        handle,
        allowHistory: false,
        allowedMessages: {messageId},
      );
      final uris = mcpResultImageUris(
        readMcpResultMetadata(observation.metadata),
      );
      final reference = context
          .toolReferences('view_image', uris, observation.metadata, 'observe')
          .single;
      final body = {
        'input': [
          {
            'type': 'function_call_output',
            'call_id': 'observe',
            'output': [
              {'type': 'input_image', 'image_url': reference},
            ],
          },
        ],
      };
      final projected = await context.project(body);
      expect(
        projected['input'][0]['output'][0]['image_url'],
        'data:image/png;base64,$savedPng',
      );
      final untrusted = RequestImageContext(
        settings: const ImageContextSettings(allowRecall: true),
        images: [
          ChatContextImage(
            identity: ContextImageIdentity.markdown(messageId, uris.single),
            uri: SandboxPathResolver.resolveForIo(uris.single)!,
            source: ContextImageSource.assistant,
            label: 'Markdown link',
          ),
        ],
      );
      untrusted.toolReferences('other_tool', uris, null, 'unrelated');
      for (final item in untrusted.images) {
        expect(
          untrusted.generationReference(
            item.handle,
            allowedMessages: {messageId},
            currentSettings: const ImageContextSettings(allowRecall: true),
          ),
          isNull,
        );
        expect(await untrusted.localAttachmentPath(item.handle), isNull);
        expect(await untrusted.attachmentPath(item.handle), isNull);
      }
      expect(output['revised_prompt'], 'A cat in sunlight');
      final id = (output['images'] as List).single['image_id'] as String;
      expect(id, matches(GenerateImageTool.imageIdPattern));
      expect(generated.content, isNot(contains('kelivo-file:')));

      final handler = StreamChunkHandler();
      handler.handle(
        const ToolCallStart(id: 'tool-1', toolName: GenerateImageTool.name),
      );
      handler.handle(
        ToolCallResult(
          id: 'tool-1',
          output: generated.content,
          metadata: generated.metadata,
        ),
      );
      final part = handler.parts.whereType<ImagePart>().single;
      final batchId = generated.metadata![GenerateImageTool.batchKey] as String;
      final batch = (await media.batch(batchId))!;
      expect(
        (batch.source, batch.topicId, batch.conversationId, batch.messageId),
        (GenerationSource.chat, null, conversationId, messageId),
      );
      expect(part.uri, startsWith('kelivo-file:///generations/'));
      expect(
        part.generationItemId,
        (await media.itemsForBatch(batchId)).single.id,
      );
      await chat.updateMessage(messageId, parts: handler.parts);
      final persisted = (await repository.getMessage(messageId))!;
      expect(
        RequestImageContext.collect([
          persisted.copyWith(id: 'forked'),
        ]).single.handle,
        id,
      );

      expect(RequestImageContext.collect([persisted]).single.handle, id);
      expect(MessageBuilderService.mediaRefsFromParts(persisted), isEmpty);

      final edited = await api.run(
        {
          'prompt': 'Make the cat black',
          'image_ids': [id],
        },
        conversationId: conversationId,
        context: context,
        enabled: () => true,
      );
      expect(jsonDecode(edited.content)['images'], hasLength(1));
      expect(calls, 2);
      final excluded = await api.run(
        {
          'prompt': 'Use a foreign image',
          'image_ids': ['img_00000000000000000000'],
        },
        conversationId: conversationId,
        context: context,
        enabled: () => true,
      );
      expect(jsonDecode(excluded.content)['error'], isNotEmpty);
      expect(calls, 2);

      final editBatch = (await media.watchBatches().first).firstWhere(
        (b) => b.id != batchId,
      );
      final input = MediaRequest.fromBatch(editBatch).references.single;
      expect(input.path, part.uri);
      expect(
        await Directory(
          '${root.path}/generations/${editBatch.id}/refs',
        ).exists(),
        false,
      );
      expect(
        await Directory('${root.path}/upload').exists() &&
            (await Directory(
              '${root.path}/upload',
            ).list().toList()).whereType<File>().isNotEmpty,
        false,
      );
      // The row can be retired before its file is physically removed.
      await media.deleteBatch(batchId);
      expect(
        await File(SandboxPathResolver.resolveForIo(part.uri)!).exists(),
        isTrue,
      );
      expect(
        jsonEncode(await context.project(body)),
        isNot(contains(savedPng)),
      );
      await backend.files.deleteBatch(batchId);
      expect(
        await File(SandboxPathResolver.resolveForIo(part.uri)!).exists(),
        false,
      );
      expect(
        MediaRequest.fromBatch(
          (await media.batch(editBatch.id))!,
        ).references.single.unavailable,
        true,
      );
      expect(
        (await repository.getMessage(
          messageId,
        ))!.parts.whereType<ImagePart>().single.unavailable,
        true,
      );
    },
  );

  test(
    'a text-only follow-up edits the selected previous output with recall off',
    () async {
      final requests = <http.Request>[];
      final api = service(
        runner(
          (_, _) => MockClient((request) async {
            requests.add(request);
            return result();
          }),
        ),
      );
      final generated = await api.run(
        {'prompt': 'Draw a tabby cat at the window'},
        conversationId: conversationId,
        context: context,
        enabled: () => true,
      );
      final id =
          jsonDecode(generated.content)['images'].single['image_id'] as String;
      final handler = StreamChunkHandler()
        ..handle(
          const ToolCallStart(id: 'cat', toolName: GenerateImageTool.name),
        )
        ..handle(
          ToolCallResult(
            id: 'cat',
            output: generated.content,
            metadata: generated.metadata,
          ),
        );
      await chat.updateMessage(
        messageId,
        parts: [...handler.parts, const TextPart('Here is the cat.')],
        isStreaming: false,
      );
      final nextUser = await chat.addMessage(
        conversationId: conversationId,
        role: 'user',
        content: 'Make it white',
      );
      final nextReply = await chat.addMessage(
        conversationId: conversationId,
        role: 'assistant',
        content: '',
        isStreaming: true,
      );
      final history = await chat.imageContextHistory(
        conversationId,
        throughMessageId: nextUser.id,
      );
      final imageSettings = await chat.imageContextSettings(conversationId);
      expect(imageSettings.allowRecall, isFalse);
      final inputs =
          MessageBuilderService(
            chatService: chat,
            contextProvider: _Context(),
          ).buildApiMessages(
            messages: await chat.loadSelectedContextMessages(
              conversationId,
              limit: 20,
              throughRevisionId: nextUser.id,
            ),
            versionSelections: {},
            currentConversation: chat.getConversation(conversationId),
          );
      final next = RequestImageContext(
        images: await RequestImageContext.collectHistory(
          history,
          parseMarkdownImages: false,
          allowRemoteImages: false,
        ),
        settings: imageSettings,
        canImageInput: false,
        latestUserId: nextUser.id,
        targetMessageId: nextReply.id,
      );
      await next.prepareMessages(
        inputs,
        [],
        parseMarkdownImages: false,
        allowRemoteImages: false,
        includeGeneratedReferences: true,
      );
      expect(inputs.last['content'], 'Make it white');
      final originalReply = inputs.singleWhere(
        (message) => message[imageContextOwnerKey] == messageId,
      );
      expect(originalReply['content'], contains(id));
      expect(jsonEncode(inputs), isNot(contains(savedPng)));

      Future<dynamic> edit() async => jsonDecode(
        (await api.run(
          {
            'prompt': 'Change the coat to white',
            'image_ids': [id],
          },
          conversationId: conversationId,
          context: next,
          enabled: () => true,
        )).content,
      );
      await chat.setImageContextSettings(
        conversationId,
        imageSettings.exclude({next.images.single.exclusionKey}, true),
      );
      expect((await edit())['error'], isNotEmpty);
      await chat.setImageContextSettings(conversationId, imageSettings);
      await next.prepareMessages(
        [inputs.last],
        [],
        parseMarkdownImages: false,
        allowRemoteImages: false,
        includeGeneratedReferences: true,
      );

      expect((await edit())['error'], isNotEmpty);
      expect(requests, hasLength(1));
      await next.prepareMessages(
        inputs,
        [],
        parseMarkdownImages: false,
        allowRemoteImages: false,
        includeGeneratedReferences: true,
      );
      next.compressedOwners.add(messageId);
      expect((await edit())['error'], isNotEmpty);
      next.compressedOwners.clear();
      expect((await edit())['images'], hasLength(1));
      expect(requests.map((r) => r.url.path), [
        '/v1/images/generations',
        '/v1/images/edits',
      ]);
      expect(
        latin1.decode(requests.last.bodyBytes),
        contains(latin1.decode(base64Decode(savedPng))),
      );
    },
  );

  test(
    'a manual retry attaches the image to the original completed message',
    () async {
      var calls = 0;
      final backend = runner(
        (_, _) => MockClient((_) async {
          return ++calls == 1
              ? http.Response('{"error":"failed"}', 400)
              : result();
        }),
      );
      final api = service(backend);
      final failure = await api.run(
        {'prompt': 'Draw a cat'},
        conversationId: conversationId,
        context: context,
        enabled: () => true,
      );
      expect(jsonDecode(failure.content)['error'], isNotNull);
      final batchId = failure.metadata![GenerateImageTool.batchKey] as String;
      final handler = StreamChunkHandler();
      handler.handle(
        const ToolCallStart(id: 'tool-1', toolName: GenerateImageTool.name),
      );
      handler.handle(
        ToolCallResult(
          id: 'tool-1',
          output: failure.content,
          metadata: failure.metadata,
        ),
      );
      final streaming = (await repository.getMessage(messageId))!;
      await chat.updateStreamingCheckpointSilent(
        streaming.copyWith(parts: handler.parts),
        [handler.toolPayload('tool-1')!],
      );
      await chat.updateMessage(messageId, isStreaming: false);
      expect(
        jsonDecode(
          chat.getToolEvents(messageId).single['content'] as String,
        )['error'],
        isNotNull,
      );

      final batch = (await media.batch(batchId))!;
      expect(batch.status, GenerationStatus.failed);
      expect(await api.retry(batch), isTrue);
      expect(calls, 2);
      final updated = (await repository.getMessage(messageId))!;
      final part = updated.parts.whereType<ImagePart>().single;
      final tool = updated.parts.whereType<ToolCallPart>().single;
      final content = jsonDecode(
        jsonDecode(tool.payloadJson)['content'] as String,
      );
      expect(content['images'], [
        {
          'image_id': RequestImageContext.collect([updated]).single.handle,
        },
      ]);
      expect(part.uri, startsWith('kelivo-file:///generations/'));
      expect(
        jsonDecode(
          chat.getToolEventsForMessage(updated).single['content'] as String,
        ),
        content,
      );
    },
  );

  test('cancelling the owning chat request cancels the media runner', () async {
    final started = Completer<void>();
    final stopped = Completer<void>();
    var calls = 0;
    final backend = runner(
      (_, token) => MockClient((_) async {
        if (++calls > 1) return result();
        started.complete();
        throw await token.whenCancel;
      }),
    );
    final api = service(backend);
    final cancellation = ToolCallCancellation(
      isCancelled: () => stopped.isCompleted,
      cancelled: stopped.future,
    );
    final operation = cancellation.run(
      () => api.run(
        {'prompt': 'Draw a cat'},
        conversationId: conversationId,
        context: context,
        enabled: () => true,
        toolCallId: 'cancelled-image',
      ),
    );
    await started.future;
    stopped.complete();
    final output = await operation;
    final batchId = output.metadata![GenerateImageTool.batchKey] as String;
    final batch = (await media.batch(batchId))!;
    expect(batch.status, GenerationStatus.cancelled);
    expect(jsonDecode(output.content)['error'], contains('cancelled'));
    expect(await media.itemsForBatch(batchId), isEmpty);

    final transcript = StreamChunkHandler()
      ..handle(
        const ToolCallStart(
          id: 'cancelled-image',
          toolName: GenerateImageTool.name,
        ),
      )
      ..handle(const ToolCallEnd('cancelled-image'));
    await chat.updateMessage(
      messageId,
      parts: transcript.parts,
      isStreaming: false,
    );
    expect(await api.retry(batch), isTrue);
    final resumed = (await repository.getMessage(messageId))!;
    final tool = resumed.parts.whereType<ToolCallPart>().single;
    final outputJson = jsonDecode(
      jsonDecode(tool.payloadJson)['content'] as String,
    );
    expect(outputJson['images'], [
      {
        'image_id': RequestImageContext.collect([resumed]).single.handle,
      },
    ]);
  });

  test(
    'automatic references reject private URLs and unmanaged files',
    () async {
      await chat.updateImageContextSettings(
        conversationId,
        (_) => const ImageContextSettings(allowRecall: true),
      );
      final owner = (await chat.imageContextHistory(conversationId)).first.id;
      final local = await File(
        '${root.path}/outside-upload.png',
      ).writeAsBytes(base64Decode(savedPng));
      final refs = [
        for (final (index, uri) in [
          local.path,
          'http://127.0.0.1:9/image.png',
        ].indexed)
          ChatContextImage(
            identity: ContextImageIdentity(owner, 'part:$index'),
            uri: uri,
            source: ContextImageSource.user,
            label: 'reference',
          ),
      ];
      final request = RequestImageContext(
        settings: const ImageContextSettings(allowRecall: true),
        images: refs,
        targetMessageId: messageId,
      );
      var outbound = 0;
      final backend = runner(
        (_, _) => MockClient((_) async {
          outbound++;
          return result();
        }),
      );
      for (final reference in refs) {
        final response = await service(backend).run(
          {
            'prompt': 'Edit this',
            'image_ids': [reference.handle],
          },
          conversationId: conversationId,
          context: request,
          enabled: () => true,
        );
        expect(jsonDecode(response.content)['error'], isNotNull);
      }
      expect(outbound, 0);
    },
  );

  test(
    'schema follows the configured image model reference capabilities',
    () async {
      final choice = resolveDefaultImageModel(settings)!;
      expect(choice.capabilities.maxReferences, greaterThan(0));
      await settings.setCreationModel(CreationModelSlot.image, (
        providerKey: provider.id,
        modelId: 'dall-e-3',
      ));
      final noEdits = resolveDefaultImageModel(settings)!;
      expect(noEdits.capabilities.maxReferences, 0);
      final schema =
          GenerateImageTool.definition(allowReferences: false)['function']
              as Map;
      expect((schema['parameters'] as Map)['properties'], contains('prompt'));
      expect(
        (schema['parameters'] as Map)['properties'],
        isNot(contains('image_ids')),
      );
      expect(
        schema['description'],
        isNot(contains('already in this conversation')),
      );
      await settings.clearSelectionsForModel(provider.id, 'dall-e-3');
      expect(resolveDefaultImageModel(settings), isNull);
    },
  );
}
