import 'dart:io';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late ChatDatabaseRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'kelivo_ocr_artifact_test_',
    );
    repository = ChatDatabaseRepository.open(
      file: File('${directory.path}/chat.sqlite'),
    );
    await repository.ensureReady();
  });

  tearDown(() async {
    await repository.close();
    await directory.delete(recursive: true);
  });

  Future<void> seedUserMessage({
    required String conversationId,
    required String messageId,
    required String content,
  }) async {
    await repository.appendLinearMessageToConversation(
      conversation: Conversation(id: conversationId, title: 'OCR'),
      message: ChatMessage(
        id: messageId,
        role: 'user',
        content: content,
        conversationId: conversationId,
        groupId: messageId,
      ),
    );
  }

  test('upsert and batch-load OCR artifacts by revision', () async {
    await seedUserMessage(
      conversationId: 'c1',
      messageId: 'u1',
      content: 'hello\n[image:/tmp/a.png]',
    );
    await seedUserMessage(
      conversationId: 'c1',
      messageId: 'u2',
      content: 'world\n[image:/tmp/b.png]',
    );

    await repository.upsertImageOcrArtifactItems(
      revisionId: 'u1',
      items: {'hash-a': 'text-a'},
    );
    await repository.upsertImageOcrArtifactItems(
      revisionId: 'u2',
      items: {'hash-b': 'text-b'},
    );

    final loaded = await repository.getImageOcrArtifacts(const ['u1', 'u2']);
    expect(loaded['u1'], {'hash-a': 'text-a'});
    expect(loaded['u2'], {'hash-b': 'text-b'});
  });

  test('upsert merges items for the same revision', () async {
    await seedUserMessage(
      conversationId: 'c1',
      messageId: 'u1',
      content: 'hello\n[image:/tmp/a.png]',
    );

    await repository.upsertImageOcrArtifactItems(
      revisionId: 'u1',
      items: {'hash-a': 'text-a'},
    );
    await repository.upsertImageOcrArtifactItems(
      revisionId: 'u1',
      items: {'hash-b': 'text-b'},
    );

    final loaded = await repository.getImageOcrArtifacts(const ['u1']);
    expect(loaded['u1'], {'hash-a': 'text-a', 'hash-b': 'text-b'});
  });

  test('inherit copies retained hashes to the new revision', () async {
    await seedUserMessage(
      conversationId: 'c1',
      messageId: 'u1',
      content: 'hello\n[image:/tmp/a.png]\n[image:/tmp/b.png]',
    );
    await repository.upsertImageOcrArtifactItems(
      revisionId: 'u1',
      items: {'hash-a': 'text-a', 'hash-b': 'text-b'},
    );

    final appended = await repository.appendMessageVersion(
      messageId: 'u1',
      content: 'edited\n[image:/tmp/a.png]',
    );
    expect(appended, isNotNull);

    await repository.inheritImageOcrArtifacts(
      fromRevisionId: 'u1',
      toRevisionId: appended!.message.id,
      retainedContentHashes: {'hash-a'},
    );

    final loaded = await repository.getImageOcrArtifacts([
      appended.message.id,
    ]);
    expect(loaded[appended.message.id], {'hash-a': 'text-a'});
  });

  test('deleting a message cascades OCR artifacts', () async {
    await seedUserMessage(
      conversationId: 'c1',
      messageId: 'u1',
      content: 'hello\n[image:/tmp/a.png]',
    );
    await repository.upsertImageOcrArtifactItems(
      revisionId: 'u1',
      items: {'hash-a': 'text-a'},
    );

    await repository.deleteMessages(
      conversationId: 'c1',
      messageIds: {'u1'},
      versionSelectionChanges: const {'u1': null},
    );

    final loaded = await repository.getImageOcrArtifacts(const ['u1']);
    expect(loaded, isEmpty);
  });

  test('empty OCR text is not persisted', () async {
    await seedUserMessage(
      conversationId: 'c1',
      messageId: 'u1',
      content: 'hello\n[image:/tmp/a.png]',
    );

    await repository.upsertImageOcrArtifactItems(
      revisionId: 'u1',
      items: {'hash-a': '   ', 'hash-b': 'ok'},
    );

    final loaded = await repository.getImageOcrArtifacts(const ['u1']);
    expect(loaded['u1'], {'hash-b': 'ok'});
  });

  test('path hash lookup omits paths with multiple content hashes', () async {
    await repository.registerAsset(
      id: 'asset_h1',
      contentHash: 'h1',
      path: '/tmp/shared.png',
      byteSize: 10,
    );
    await repository.registerAsset(
      id: 'asset_h2',
      contentHash: 'h2',
      path: '/tmp/shared.png',
      byteSize: 12,
    );
    await repository.registerAsset(
      id: 'asset_unique',
      contentHash: 'unique',
      path: '/tmp/unique.png',
      byteSize: 8,
    );

    final hashes = await repository.getAssetContentHashesByPaths(const [
      '/tmp/shared.png',
      '/tmp/unique.png',
    ]);
    expect(hashes.containsKey('/tmp/shared.png'), isFalse);
    expect(hashes['/tmp/unique.png'], 'unique');
  });

  test('concurrent OCR upserts merge instead of clobbering', () async {
    await seedUserMessage(
      conversationId: 'c1',
      messageId: 'u1',
      content: 'hello\n[image:/tmp/a.png]',
    );

    await Future.wait([
      repository.upsertImageOcrArtifactItems(
        revisionId: 'u1',
        items: {'hash-a': 'text-a'},
      ),
      repository.upsertImageOcrArtifactItems(
        revisionId: 'u1',
        items: {'hash-b': 'text-b'},
      ),
    ]);

    final loaded = await repository.getImageOcrArtifacts(const ['u1']);
    expect(loaded['u1'], {'hash-a': 'text-a', 'hash-b': 'text-b'});
  });

  test('inherit copies data-URL image OCR by content hash', () async {
    const dataUrl = 'data:image/png;base64,aGVsbG8=';
    await seedUserMessage(
      conversationId: 'c1',
      messageId: 'u1',
      content: 'hello\n[image:$dataUrl]',
    );
    await repository.upsertImageOcrArtifactItems(
      revisionId: 'u1',
      items: {'data-hash': 'ocr-from-data-url'},
    );

    final appended = await repository.appendMessageVersion(
      messageId: 'u1',
      content: 'edited text only\n[image:$dataUrl]',
    );
    expect(appended, isNotNull);

    await repository.inheritImageOcrArtifacts(
      fromRevisionId: 'u1',
      toRevisionId: appended!.message.id,
      retainedContentHashes: {'data-hash'},
    );

    final loaded = await repository.getImageOcrArtifacts([
      appended.message.id,
    ]);
    expect(loaded[appended.message.id], {'data-hash': 'ocr-from-data-url'});
  });
}
