import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/context_operation.dart';
import 'package:Kelivo/core/services/storage/storage_attachment_usage.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/services/api/request_image_context.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/storage/attachment_file_lock.dart';
import 'package:Kelivo/core/services/storage/storage_usage_service.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';

import '../../../support/storage_images_test_fixture.dart';

AttachmentReferenceReader _temporaryPhoto(String uri) =>
    () => {
      uri: {'temp': 'Temp'},
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageImagesFixture fixture;
  late ChatDatabaseRepository repo;
  late File photo;
  late String uri;
  setUp(() async {
    fixture = await StorageImagesFixture.create();
    repo = ChatDatabaseRepository(fixture.database);
    photo = await fixture.file('upload/chat.png');
    uri = SandboxPathResolver.canonicalize(photo.path);
  });
  tearDown(() => fixture.dispose());

  Future<StorageFileEntry> list() async =>
      (await StorageUsageService.listUploadEntries(
        images: true,
      )).singleWhere((e) => e.path == photo.path);
  Future<ChatMessage> message(
    String title,
    List<MessagePart> parts, {
    bool streaming = false,
  }) async {
    final conversation = Conversation(title: title);
    await repo.putConversation(conversation);
    final message = ChatMessage(
      role: 'user',
      conversationId: conversation.id,
      parts: parts,
      isStreaming: streaming,
    );
    await repo.putMessage(message);
    return message;
  }

  Future<bool> remove(StorageFileEntry confirmed) async =>
      (await StorageUsageService.removeChatImage(
        confirmed,
        deletedLabel: 'Image deleted',
      )).deleted;

  test(
    'explicit removal detaches only the selected PNG in every fork and preserves other uploads and their pixels',
    () async {
      final chat = ChatService(existingRepository: repo);
      await chat.init();
      addTearDown(chat.close);
      await chat.runAssetReferenceMaintenance();
      final unrelated = await fixture.file('upload/other.png');
      final original = await chat.createConversation(title: 'Original');
      final msg = await chat.addMessage(
        conversationId: original.id,
        role: 'user',
        parts: [
          const TextPart('Keep the text'),
          ImagePart(uri: uri),
          ImagePart(uri: unrelated.path),
        ],
      );
      final fork = (await chat.duplicateConversation(original.id))!;
      final entry = await list();
      expect(entry.conversations.keys.toSet(), {original.id, fork.id});
      expect(
        await StorageUsageService.deleteUploadFiles([photo.path], images: true),
        0,
      );
      final copy = await fixture.file(
        'sessions/${original.id}/attachments/chat.png',
      );
      await fixture.file(
        'sessions/${original.id}/.attachment-index.json',
        utf8.encode(
          jsonEncode({
            uri: {'name': 'chat.png'},
          }),
        ),
      );
      final result = await StorageUsageService.removeChatImage(
        entry,
        deletedLabel: 'Image deleted',
      );
      expect(result.deleted, isTrue);
      await chat.refreshRemovedChatImage(
        entry.conversations.keys,
        result.changedRevisions,
      );
      expect(result.changedRevisions, contains(msg.id));
      expect(result.changedRevisions, hasLength(2));
      for (final revision in result.changedRevisions) {
        final stored = (await repo.getMessage(revision))!;
        expect(stored.parts[0], const TextPart('Keep the text'));
        expect(stored.parts[1], ImagePart.deleted);
        expect((stored.parts[2] as ImagePart).unavailable, isFalse);
        expect(
          RequestImageContext.collect([stored]).where((i) => i.unavailable),
          hasLength(1),
        );
      }
      expect(photo.existsSync(), isFalse);
      expect(copy.existsSync(), isFalse);
      expect(unrelated.existsSync(), isTrue);
      await chat.runAssetReferenceMaintenance();
      expect(await repo.hasPendingAssetReferenceSync(), isFalse);
    },
  );

  test(
    'tool observations keep sibling image ordinals and original arguments, and Markdown keeps text and literal code',
    () async {
      final other = await fixture.file('images/mcp_img_other.png');
      final event = {
        'name': 'view_image',
        'arguments': {'path': uri},
        'content': 'Result ![preview]($uri)',
        'metadata': {
          'chatImage': {
            'version': 1,
            'sourceKey': 'original|part:1',
            'directAsset': true,
            'mime': 'image/png',
          },
          'mcpResult': {
            'version': 1,
            'imageUris': [uri, other.path],
          },
        },
      };
      final msg = await message('Chat', [
        TextPart('Before ![one]($uri) after, `![sample]($uri)`'),
        ToolCallPart(jsonEncode(event)),
      ]);
      expect(await remove(await list()), isTrue);
      final parts = (await repo.getMessage(msg.id))!.parts;
      expect(
        (parts.first as TextPart).text,
        'Before Image deleted after, `![sample]($uri)`',
      );
      final tool = jsonDecode((parts.last as ToolCallPart).payloadJson);
      expect(tool['arguments'], event['arguments']);
      expect(tool['content'], 'Result Image deleted');
      expect(tool['metadata']['mcpResult']['imageUris'], [
        ImagePart.deleted.uri,
        other.path,
      ]);
      expect(other.existsSync(), isTrue);
    },
  );

  test(
    'confirmation cannot authorize a newly affected chat or a replacement file',
    () async {
      final msg = await message('First', [ImagePart(uri: uri)]);
      final first = await list();
      await message('Second', [ImagePart(uri: uri)]);
      expect(await remove(first), isFalse);
      final both = await list();
      await photo.writeAsBytes([1, 2, 3, 4]);
      expect(await remove(both), isFalse);
      expect(
        (await repo.getMessage(msg.id))!.parts.single,
        ImagePart(uri: uri),
      );
      expect(photo.existsSync(), isTrue);
    },
  );

  test('failed history commit restores the original file and message', () async {
    final msg = await message('First', [ImagePart(uri: uri)]);
    final entry = await list();
    await fixture.database.customStatement(
      "CREATE TRIGGER abort_removal BEFORE UPDATE OF payload ON message_part_rows BEGIN SELECT RAISE(ABORT,'write failed'); END",
    );
    await expectLater(remove(entry), throwsA(isA<Exception>()));
    expect(await photo.readAsBytes(), [1, 2, 3]);
    expect((await repo.getMessage(msg.id))!.parts.single, ImagePart(uri: uri));
    await fixture.database.customStatement('DROP TRIGGER abort_removal');
    expect(await remove(entry), isTrue);
  });

  test(
    'recovery restores staged originals and discards committed bytes',
    () async {
      const token = '1e2b7cf8-6b01-4943-8f24-231d20870349';
      final stage = File(
        '${fixture.root.path}/.kelivo-pending-chat-image-$token',
      );
      await photo.rename(stage.path);
      await fixture.database.customStatement(
        'INSERT INTO chat_storage_meta_rows(key,value) VALUES (?,?)',
        [
          ChatStorageMetaKeys.pendingImageRemoval,
          jsonEncode({'token': token, 'source': 'upload/chat.png'}),
        ],
      );
      await recoverStoredChatImageRemoval(fixture.root.path);
      expect(await photo.readAsBytes(), [1, 2, 3]);
      expect(stage.existsSync(), isFalse);
      await photo.rename(stage.path);
      await fixture.database.customStatement(
        'INSERT INTO chat_storage_meta_rows(key,value) VALUES (?,?)',
        [
          ChatStorageMetaKeys.pendingImageRemoval,
          jsonEncode({'token': token}),
        ],
      );
      await recoverStoredChatImageRemoval(fixture.root.path);
      expect(photo.existsSync(), isFalse);
      expect(stage.existsSync(), isFalse);
    },
  );

  test(
    'a failed session copy sweep still publishes the deletion and retries on recovery',
    () async {
      final msg = await message('First', [ImagePart(uri: uri)]);
      final copy = await fixture.file(
        'sessions/${msg.conversationId}/attachments/chat.png',
      );
      final index = await fixture.file(
        'sessions/${msg.conversationId}/.attachment-index.json',
        [0xff, 0xfe],
      );
      final result = await StorageUsageService.removeChatImage(
        await list(),
        deletedLabel: 'Image deleted',
      );
      expect(result.deleted, isTrue);
      expect(result.copiesPending, isTrue);
      expect(result.changedRevisions, {msg.id});
      expect(photo.existsSync(), isFalse);
      expect(copy.existsSync(), isTrue);
      await index.writeAsString(
        jsonEncode({
          uri: {'name': 'chat.png'},
        }),
      );
      await recoverStoredChatImageRemoval(fixture.root.path);
      expect(copy.existsSync(), isFalse);
    },
  );

  test(
    'removing a primary hash path promotes the undisturbed duplicate',
    () async {
      final other = await fixture.file('upload/other.png');
      final otherUri = SandboxPathResolver.canonicalize(other.path);
      final survivor = await message('Other', [
        ImagePart(uri: otherUri, assetId: 'shared'),
      ]);
      final intended = await message('Target', [
        ImagePart(uri: uri, assetId: 'shared'),
      ]);
      for (final (msg, source) in [(survivor, otherUri), (intended, uri)]) {
        await repo.replaceMessageAssetReferences(
          conversationId: msg.conversationId,
          revisionId: msg.id,
          assets: [
            MessageAssetRegistration(
              assetId: 'shared',
              contentHash: 'shared',
              path: source,
              byteSize: 3,
              kind: 'image',
            ),
          ],
        );
      }
      // An older restored upload can leave a missing alias after the live one.
      await fixture.database.customStatement(
        "UPDATE asset_rows SET extras_json=? WHERE id='shared'",
        [
          jsonEncode({
            'localPaths': [otherUri, 'kelivo-file:///upload/gone.png'],
          }),
        ],
      );
      expect(await remove(await list()), isTrue);
      final asset = await fixture.database
          .customSelect("SELECT path FROM asset_rows WHERE id='shared'")
          .getSingle();
      expect(asset.read<String>('path'), otherUri);
      expect(
        (await repo.getMessage(survivor.id))!.parts.single,
        ImagePart(uri: otherUri, assetId: 'shared'),
      );
      expect(other.existsSync(), isTrue);
    },
  );

  test(
    'an active native compaction keeps its source and refuses removal',
    () async {
      final msg = await message('Frozen', [ImagePart(uri: uri)]);
      final op = ContextOperation(
        id: 'native',
        kind: ContextOperationKind.compress,
        anchorGroupId: msg.id,
        appliedAfterGroupId: msg.id,
        sourceGroups: [msg.id],
        dependencies: const [],
        createdAt: DateTime.now(),
        compressionDetails: const {
          'nativeCompaction': {
            'protocol': 'codex',
            'scope': 's',
            'modelId': 'm',
            'output': [
              {'type': 'compaction', 'encrypted_content': 'opaque'},
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'input_image',
                    'image_url': 'data:image/png;base64,AQID',
                  },
                ],
              },
            ],
          },
        },
      );
      await fixture.database.customStatement(
        'INSERT INTO extension_entity_rows(kind,id,sort_order,payload,updated_at) VALUES (?,?,0,?,0)',
        [
          ContextOperation.entityKind,
          msg.conversationId,
          jsonEncode([op.toJson()]),
        ],
      );
      final result = await StorageUsageService.removeChatImage(
        await list(),
        deletedLabel: 'Image deleted',
      );
      expect(result.frozen, isTrue);
      expect(result.deleted, isFalse);
      expect(
        (await repo.getMessage(msg.id))!.parts.single,
        ImagePart(uri: uri),
      );
      expect(photo.existsSync(), isTrue);
      // A compressed new conversation has no local groups for the source.
      await fixture.database.customStatement(
        'DELETE FROM extension_entity_rows WHERE kind=?',
        [ContextOperation.entityKind],
      );
      final summary = await message('Copied summary', [
        const TextPart('Summary'),
      ]);
      final imported = op.copiedTo(
        summary,
        keepUserMessages: 0,
        sourceConversationId: msg.conversationId,
      );
      await fixture.database.customStatement(
        'INSERT INTO extension_entity_rows(kind,id,sort_order,payload,updated_at) VALUES (?,?,0,?,0)',
        [
          ContextOperation.entityKind,
          summary.conversationId,
          jsonEncode([imported.toJson()]),
        ],
      );
      expect(
        (await StorageUsageService.removeChatImage(
          await list(),
          deletedLabel: 'Image deleted',
        )).frozen,
        isTrue,
      );
      for (final type in ['function_call_output', 'custom_tool_call_output']) {
        final data = imported.toJson();
        data['compressionDetails'] = {
          ...imported.compressionDetails,
          'nativeCompaction': {
            ...imported.nativePayload!.toJson(),
            'output': [
              {'type': 'compaction', 'encrypted_content': 'opaque'},
              {
                'type': type,
                'call_id': 'c',
                'output': [
                  {
                    'type': 'input_image',
                    'image_url': 'data:image/png;base64,AQID',
                  },
                ],
              },
            ],
          },
        };
        await fixture.database.customStatement(
          'UPDATE extension_entity_rows SET payload=? WHERE kind=? AND id=?',
          [
            jsonEncode([data]),
            ContextOperation.entityKind,
            summary.conversationId,
          ],
        );
        expect(
          (await StorageUsageService.removeChatImage(
            await list(),
            deletedLabel: 'Image deleted',
          )).frozen,
          isTrue,
        );
      }
      expect(photo.existsSync(), isTrue);
    },
  );

  test(
    'appearance, draft, live temporary reference and active generation each protect a shared chat image',
    () async {
      final msg = await message('First', [ImagePart(uri: uri)]);
      final entry = await list();
      await fixture.assistants([
        {'id': 'a', 'name': 'A', 'avatar': uri},
      ]);
      expect(await remove(entry), isFalse);
      await fixture.assistants([]);
      await fixture.database.customStatement(
        "INSERT INTO extension_entity_rows(kind,id,sort_order,payload,updated_at) VALUES ('composerDraft','draft',0,?,0)",
        [
          jsonEncode({
            'attachments': [uri],
          }),
        ],
      );
      expect(await remove(entry), isFalse);
      await fixture.database.customStatement(
        "DELETE FROM extension_entity_rows WHERE kind='composerDraft'",
      );
      final owner = Object();
      AttachmentFileLock.registerTransientOwner(
        owner,
        capture: () => _temporaryPhoto(uri),
        active: () => false,
      );
      try {
        expect(await remove(entry), isFalse);
      } finally {
        AttachmentFileLock.unregisterTransientOwner(owner);
      }
      await message('Active', [const TextPart('generating')], streaming: true);
      expect(await remove(entry), isFalse);
      expect(
        (await repo.getMessage(msg.id))!.parts.single,
        ImagePart(uri: uri),
      );
      expect(photo.existsSync(), isTrue);
    },
  );
}
