import 'package:Kelivo/core/services/storage/attachment_file_lock.dart';
import 'dart:convert';
import 'package:image/image.dart' as img;
import 'package:Kelivo/core/services/mcp/mcp_image_snapshot.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/attachment_retention.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/storage/storage_attachment_usage.dart';
import 'package:Kelivo/core/services/storage/storage_usage_service.dart';
import 'package:Kelivo/core/services/workspace/workspace_file_coordinator.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';

import '../../../support/storage_images_test_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageImagesFixture fixture;
  late ChatDatabaseRepository repository;
  late ChatService chat;

  setUp(() async {
    fixture = await StorageImagesFixture.create();
    repository = ChatDatabaseRepository(fixture.database);
    chat = ChatService(existingRepository: repository);
    await chat.init();
    await chat.runAssetReferenceMaintenance();
    await chat.runAssetMaintenance();
  });
  tearDown(() async {
    await chat.close();
    await fixture.dispose();
  });

  Future<({File file, ChatMessage message})> upload() async {
    final file = await fixture.file('upload/shared.txt');
    final conversation = await chat.createConversation(title: 'Original');
    final message = await chat.addMessage(
      conversationId: conversation.id,
      role: 'user',
      parts: [
        FilePart(
          uri: SandboxPathResolver.canonicalize(file.path),
          name: 'shared.txt',
        ),
      ],
    );
    return (file: file, message: message);
  }

  test(
    'zero days removes the last reference immediately and keeps a fork',
    () async {
      await fixture.preferences.setInt(AttachmentRetention.preferenceKey, 0);
      final source = await upload();
      final fork = (await chat.duplicateConversation(
        source.message.conversationId,
      ))!;
      final before = (await StorageUsageService.listUploadEntries(
        images: false,
      )).single;
      expect(before.conversations.keys.toSet(), {
        source.message.conversationId,
        fork.id,
      });
      expect(before.isInUse, isTrue);
      expect(
        await StorageUsageService.deleteUploadFiles([
          source.file.path,
        ], images: false),
        0,
      );
      await chat.deleteConversation(source.message.conversationId);
      expect(source.file.existsSync(), isTrue);
      expect(
        (await StorageUsageService.listUploadEntries(
          images: false,
        )).single.conversations.keys,
        [fork.id],
      );
      await chat.deleteConversation(fork.id);
      expect(source.file.existsSync(), isFalse);
    },
  );

  test(
    'zero days collects finished tool previews but keeps in-flight generations',
    () async {
      await fixture.preferences.setInt(AttachmentRetention.preferenceKey, 0);
      final saved = (await McpImageSnapshot.saveBytes(
        img.encodePng(img.Image(width: 2, height: 2)),
        deduplicate: true,
      ))!;
      final file = (await McpImageSnapshot.localFile(saved.uri))!;
      final original = await chat.createConversation(title: 'Browser');
      await chat.addMessage(
        conversationId: original.id,
        role: 'assistant',
        parts: [
          ToolCallPart(
            jsonEncode({
              'name': 'browser',
              'metadata': {
                'browser': {'previewImage': saved.uri},
              },
            }),
          ),
        ],
      );
      final other = await chat.createConversation(title: 'In flight');
      final pending = await chat.addMessage(
        conversationId: other.id,
        role: 'assistant',
        isStreaming: true,
      );
      await chat.deleteConversation(original.id);
      expect(file.existsSync(), isTrue);
      expect(
        await StorageUsageService.deleteUploadFiles([file.path], images: true),
        0,
      );
      await chat.deleteMessage(pending.id);
      expect(file.existsSync(), isFalse);
    },
  );

  test('physical aliases are collected once', () async {
    await fixture.preferences.setInt(AttachmentRetention.preferenceKey, 0);
    final source = await upload();
    final hash = (await repository.getMessageImageContentHashes(
      source.message.id,
    ));
    // File references use the same content-addressed registry as images.
    final rows = await fixture.database
        .customSelect('SELECT id, content_hash FROM asset_rows')
        .get();
    expect(hash, isEmpty);
    await repository.registerAsset(
      id: rows.single.read<String>('id'),
      contentHash: rows.single.read<String>('content_hash'),
      path: source.file.path,
      byteSize: await source.file.length(),
    );
    await chat.deleteMessage(source.message.id);
    expect(source.file.existsSync(), isFalse);
  });

  test(
    'a missing original still cleans its unreferenced session copy',
    () async {
      await fixture.preferences.setInt(AttachmentRetention.preferenceKey, 0);
      final source = await upload();
      final copy = await fixture.file(
        'sessions/${source.message.conversationId}/attachments/shared.txt',
      );
      final index = await fixture.file(
        'sessions/${source.message.conversationId}/.attachment-index.json',
      );
      await index.writeAsString(
        jsonEncode({
          SandboxPathResolver.canonicalize(source.file.path): {
            'name': 'shared.txt',
          },
        }),
      );
      await source.file.delete();
      await chat.deleteMessage(source.message.id);
      expect(copy.existsSync(), isFalse);
    },
  );

  test(
    'manual source cleanup preserves a session copy held by a temporary chat',
    () async {
      final source = await fixture.file('upload/source.txt');
      final copy = await fixture.file(
        'sessions/session/attachments/source.txt',
      );
      final index = await fixture.file(
        'sessions/session/.attachment-index.json',
      );
      await index.writeAsString(
        jsonEncode({
          SandboxPathResolver.canonicalize(source.path): {'name': 'source.txt'},
        }),
      );
      expect(
        await StorageUsageService.deleteUploadFiles(
          [source.path],
          images: false,
          protectedPaths: {copy.path},
        ),
        1,
      );
      expect(copy.existsSync(), isTrue);
    },
  );

  test(
    'active responses protect direct uploads until the final reference is released',
    () async {
      await fixture.preferences.setInt(AttachmentRetention.preferenceKey, 0);
      final source = await upload();
      final pending = await chat.addMessage(
        conversationId: source.message.conversationId,
        role: 'assistant',
        isStreaming: true,
      );
      await chat.deleteMessage(source.message.id);
      expect(source.file.existsSync(), isTrue);
      expect(
        await StorageUsageService.deleteUploadFiles([
          source.file.path,
        ], images: false),
        0,
      );
      await chat.deleteMessage(pending.id);
      expect(source.file.existsSync(), isFalse);
    },
  );

  test(
    'completed temporary tool overlays retain shared browser images',
    () async {
      await fixture.preferences.setInt(AttachmentRetention.preferenceKey, 0);
      final file = await fixture.file('images/mcp_img_temporary.png');
      final uri = SandboxPathResolver.canonicalize(file.path);
      final event = <String, dynamic>{
        'name': 'browser',
        'metadata': {
          'browser': {'previewImage': uri},
        },
      };
      final original = await chat.createConversation(title: 'Original');
      await chat.addMessage(
        conversationId: original.id,
        role: 'assistant',
        parts: [ToolCallPart(jsonEncode(event))],
      );
      final temporary = await chat.createDraftConversation(
        temporary: true,
        title: 'Temporary',
      );
      final message = await chat.addMessage(
        conversationId: temporary.id,
        role: 'assistant',
      );
      await chat.setToolEvents(message.id, [event]);
      await chat.deleteConversation(original.id);
      expect(file.existsSync(), isTrue);
      expect(
        await StorageUsageService.deleteUploadFiles([file.path], images: true),
        0,
      );
      final listed = (await StorageUsageService.listUploadEntries(
        images: true,
      )).single;
      expect(listed.conversations.keys, [temporary.id]);
      await chat.deleteConversation(temporary.id);
      expect(file.existsSync(), isFalse);
    },
  );

  test(
    'reopened service recycles the last reference when leaving a temporary chat',
    () async {
      await chat.close();
      await chat.init();
      await fixture.preferences.setInt(AttachmentRetention.preferenceKey, 0);
      final source = await upload();
      final temporary = await chat.createDraftConversation(temporary: true);
      await chat.addMessage(
        conversationId: temporary.id,
        role: 'user',
        parts: [FilePart(uri: source.file.path, name: 'Shared')],
      );
      await chat.deleteConversation(source.message.conversationId);
      expect(source.file.existsSync(), isTrue);
      chat.setCurrentConversation(null);
      for (var i = 0; i < 200 && source.file.existsSync(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(source.file.existsSync(), isFalse);
    },
  );

  test(
    'temporary generation publication waits for an ongoing file cleanup',
    () async {
      final temporary = await chat.createDraftConversation(temporary: true);
      final lease = await AttachmentFileLock.acquire();
      var published = false;
      final message = chat
          .addMessage(
            conversationId: temporary.id,
            role: 'assistant',
            isStreaming: true,
          )
          .then((value) {
            published = true;
            return value;
          });
      await Future<void>.delayed(Duration.zero);
      expect(published, isFalse);
      expect(chat.hasTransientGeneration, isFalse);
      lease.release();
      await message;
      expect(chat.hasTransientGeneration, isTrue);
    },
  );

  test(
    'queued deadlines change with the preference and default to seven days',
    () async {
      final source = await upload();
      await chat.deleteMessage(source.message.id);
      final first = (await StorageUsageService.listUploadEntries(
        images: false,
      )).single;
      expect(first.isInUse, isFalse);
      expect(first.pendingDeletionAt, isNotNull);
      expect(first.pendingDeletionAt!.difference(DateTime.now()).inDays, 6);
      await fixture.preferences.setInt(AttachmentRetention.preferenceKey, 30);
      await chat.runAssetMaintenance();
      final updated = (await StorageUsageService.listUploadEntries(
        images: false,
      )).single;
      expect(
        updated.pendingDeletionAt!.difference(first.pendingDeletionAt!),
        const Duration(days: 23),
      );
      await fixture.preferences.setInt(AttachmentRetention.preferenceKey, 0);
      await chat.runAssetMaintenance();
      expect(source.file.existsSync(), isFalse);
    },
  );

  test('immediate collection drains more than one batch', () async {
    await fixture.preferences.setInt(AttachmentRetention.preferenceKey, 0);
    final conversation = await chat.createConversation(title: 'Batch');
    final files = <File>[];
    for (var index = 0; index < 55; index++) {
      files.add(await fixture.file('upload/$index.txt', [index]));
    }
    await chat.addMessage(
      conversationId: conversation.id,
      role: 'user',
      parts: [for (final file in files) FilePart(uri: file.path, name: 'File')],
    );
    await chat.deleteConversation(conversation.id);
    expect(files.where((file) => file.existsSync()), isEmpty);
  });

  test(
    'identical uploads at different paths are both recycled after the last reference',
    () async {
      await fixture.preferences.setInt(AttachmentRetention.preferenceKey, 0);
      final source = await upload();
      final copy = await fixture.file('upload/another.txt');
      final other = await chat.createConversation(title: 'Same bytes');
      await chat.addMessage(
        conversationId: other.id,
        role: 'user',
        parts: [FilePart(uri: copy.path, name: 'another.txt')],
      );
      await chat.deleteConversation(source.message.conversationId);
      expect(copy.existsSync(), isTrue);
      await chat.deleteConversation(other.id);
      expect(copy.existsSync(), isFalse);
      expect(source.file.existsSync(), isFalse);
    },
  );

  test(
    'manual cleanup rechecks unindexed references added after listing',
    () async {
      final file = await fixture.file('upload/new.txt');
      final listed = (await StorageUsageService.listUploadEntries(
        images: false,
      )).single;
      expect(listed.isInUse, isFalse);
      final conversation = Conversation(title: 'New reference');
      await repository.putConversation(conversation);
      await repository.putMessage(
        ChatMessage(
          role: 'user',
          conversationId: conversation.id,
          parts: [FilePart(uri: file.uri.toString(), name: 'New')],
        ),
      );
      expect(
        await StorageUsageService.deleteUploadFiles([file.path], images: false),
        0,
      );
      expect(file.existsSync(), isTrue);
    },
  );

  test('manual cleanup ignores the delay for unused attachments', () async {
    final source = await upload();
    await chat.deleteMessage(source.message.id);
    expect(source.file.existsSync(), isTrue);
    expect(
      await StorageUsageService.deleteUploadFiles([
        source.file.path,
      ], images: false),
      1,
    );
    expect(source.file.existsSync(), isFalse);
  });

  test(
    'session cleanup removes index-only roots and preserves referenced orphan outputs',
    () async {
      final conversation = await chat.createConversation(title: 'Still here');
      await fixture.file('sessions/${conversation.id}/.attachment-index.json', [
        123,
        125,
      ]);
      final empty = Directory(
        '${fixture.root.path}/sessions/${conversation.id}',
      );
      await Directory('${empty.path}/attachments').create();
      final output = await fixture.file('sessions/gone/outputs/keep.txt');
      await chat.addMessage(
        conversationId: conversation.id,
        role: 'user',
        parts: [FilePart(uri: output.path, name: 'Shared output')],
      );
      final removed = await StorageAttachmentUsage.cleanSessions(
        includeOrphans: true,
      );
      expect(removed.directories, 1);
      expect(empty.existsSync(), isFalse);
      expect(output.existsSync(), isTrue);
      expect(chat.getConversation(conversation.id), isNotNull);
    },
  );

  test(
    'cross-conversation kelivo links protect orphaned session outputs',
    () async {
      final conversation = await chat.createConversation(
        title: 'Linked output',
      );
      final file = await fixture.file('sessions/deleted/outputs/report.txt');
      await chat.addMessage(
        conversationId: conversation.id,
        role: 'assistant',
        parts: [
          const TextPart('[Report](kelivo://chat/deleted/outputs/report.txt)'),
        ],
      );
      final cleanup = await StorageAttachmentUsage.cleanSessions(
        includeOrphans: true,
      );
      expect(cleanup.directories, 0);
      expect(file.existsSync(), isTrue);
      final usage = await StorageAttachmentUsage.load();
      expect(usage.conversationsFor(file.path).keys, [conversation.id]);
    },
  );

  test(
    'empty-folder cleanup waits for a tool writer and preserves its new file',
    () async {
      final conversation = await chat.createConversation(title: 'Working');
      final session = Directory(
        '${fixture.root.path}/sessions/${conversation.id}',
      );
      await session.create(recursive: true);
      late Future<({int bytes, int files, int directories})> cleanup;
      await WorkspaceFileCoordinator.run(session.path, () async {
        cleanup = StorageAttachmentUsage.cleanSessions();
        await fixture.file('sessions/${conversation.id}/outputs/new.txt');
      });
      expect((await cleanup).directories, 0);
      expect(File('${session.path}/outputs/new.txt').existsSync(), isTrue);
    },
  );
}
