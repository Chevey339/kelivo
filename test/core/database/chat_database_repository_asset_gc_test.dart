import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';

void main() {
  test('dirty browser preview protects every stage of asset GC', () async {
    final root = await Directory.systemTemp.createTemp('browser_preview_gc_');
    final repository = ChatDatabaseRepository.open(
      file: File('${root.path}/assets.sqlite'),
    );
    addTearDown(() async {
      await repository.close();
      await root.delete(recursive: true);
    });
    final now = DateTime.now().toUtc();
    const uri = 'kelivo-file:///images/mcp_img_preview.png';
    final conversation = Conversation(
      id: 'browser',
      title: 'Browser',
      createdAt: now,
      updatedAt: now,
    );
    final message = ChatMessage(
      id: 'tool-owner',
      role: 'assistant',
      conversationId: conversation.id,
      content: 'Browser',
    );
    await repository.putMigrationBatch(
      conversations: [conversation],
      messages: [(message: message, messageOrder: 0)],
      toolEventsByMessageId: const {},
      geminiSignaturesByMessageId: const {},
    );
    await repository.registerAsset(
      id: 'preview',
      contentHash: 'a' * 64,
      path: uri,
      byteSize: 20,
      createdAt: now,
    );
    await repository.scheduleUnreferencedAssetGc(notBefore: now);
    final candidate = (await repository.claimAssetGc(now: now)).single;
    expect(await repository.isAssetGcClaimStillValid(candidate), isTrue);
    await repository.setToolEvents(message.id, [
      {
        'name': 'browser',
        'metadata': {
          'browser': {'previewImage': uri},
        },
      },
    ]);
    expect(await repository.hasPendingAssetReferenceSync(), isTrue);
    expect(await repository.isAssetGcClaimStillValid(candidate), isFalse);
    expect(
      await repository.completeAssetGc(
        assetId: candidate.assetId,
        expectedGeneration: candidate.generation,
        path: candidate.path,
      ),
      isFalse,
    );
    expect(await repository.claimAssetGc(now: now), isEmpty);
  });

  test(
    'asset references cancel delayed GC and unreferenced assets are claimed',
    () async {
      final root = await Directory.systemTemp.createTemp('asset_gc_test_');
      final repository = ChatDatabaseRepository.open(
        file: File('${root.path}/assets.sqlite'),
      );
      addTearDown(() async {
        await repository.close();
        await root.delete(recursive: true);
      });
      final now = DateTime.utc(2026, 7, 12);
      final conversation = Conversation(
        id: 'conversation-1',
        title: 'Assets',
        createdAt: now,
        updatedAt: now,
        messageIds: const ['revision-1'],
      );
      final message = ChatMessage(
        id: 'revision-1',
        role: 'user',
        content: 'asset',
        timestamp: now,
        conversationId: conversation.id,
      );
      await repository.putMigrationBatch(
        conversations: [conversation],
        messages: [(message: message, messageOrder: 0)],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );
      await repository.registerAsset(
        id: 'asset-1',
        contentHash: List.filled(64, 'a').join(),
        path: '${root.path}/image.png',
        byteSize: 4096,
        width: 1200,
        height: 800,
        thumbnailPath: '${root.path}/image.thumb.webp',
        createdAt: now,
      );
      await repository.linkMessageAsset(
        conversationId: conversation.id,
        revisionId: message.id,
        assetId: 'asset-1',
        kind: 'image',
      );

      expect(await repository.scheduleUnreferencedAssetGc(notBefore: now), 0);
      await repository.unlinkMessageAsset(
        revisionId: message.id,
        assetId: 'asset-1',
      );
      expect(await repository.scheduleUnreferencedAssetGc(notBefore: now), 1);
      final candidate = (await repository.claimAssetGc(now: now)).single;
      expect(candidate.assetId, 'asset-1');
      expect(candidate.thumbnailPath, endsWith('image.thumb.webp'));
      expect(await repository.isAssetGcClaimStillValid(candidate), isTrue);

      await repository.linkMessageAsset(
        conversationId: conversation.id,
        revisionId: message.id,
        assetId: 'asset-1',
        kind: 'image',
      );
      expect(await repository.isAssetGcClaimStillValid(candidate), isFalse);
      expect(await repository.claimAssetGc(now: now), isEmpty);
      expect(
        await repository.completeAssetGc(
          assetId: 'asset-1',
          expectedGeneration: candidate.generation,
          path: candidate.path,
        ),
        isFalse,
      );

      await repository.unlinkMessageAsset(
        revisionId: message.id,
        assetId: 'asset-1',
      );
      await repository.scheduleUnreferencedAssetGc(notBefore: now);
      expect(
        await repository.completeAssetGc(
          assetId: 'asset-1',
          expectedGeneration: candidate.generation,
          path: candidate.path,
        ),
        isFalse,
        reason: 'a stale claim cannot complete a newly scheduled generation',
      );
      final nextCandidate = (await repository.claimAssetGc(now: now)).single;
      expect(nextCandidate.generation, isNot(candidate.generation));
      expect(
        await repository.completeAssetGc(
          assetId: 'asset-1',
          expectedGeneration: nextCandidate.generation,
          path: nextCandidate.path,
        ),
        isTrue,
      );
    },
  );

  test('kelivo-file asset path dual-form text refs block GC', () async {
    final root = await Directory.systemTemp.createTemp('asset_gc_kelivo_');
    final repository = ChatDatabaseRepository.open(
      file: File('${root.path}/assets.sqlite'),
    );
    addTearDown(() async {
      await repository.close();
      SandboxPathResolver.debugSetDirs(docsDir: null, supportDir: null);
      await root.delete(recursive: true);
    });
    SandboxPathResolver.debugSetDirs(docsDir: root.path);

    final absPath = '${root.path}/images/gen.png';
    Directory('${root.path}/images').createSync(recursive: true);
    File(absPath).writeAsBytesSync(const [1, 2, 3]);
    const canonical = 'kelivo-file:///images/gen.png';

    final now = DateTime.utc(2026, 7, 12);
    final conversation = Conversation(
      id: 'conversation-k',
      title: 'Kelivo assets',
      createdAt: now,
      updatedAt: now,
      messageIds: const ['revision-k'],
    );
    final message = ChatMessage(
      id: 'revision-k',
      role: 'assistant',
      content: 'see ![image]($absPath)',
      timestamp: now,
      conversationId: conversation.id,
      parts: [TextPart('see ![image]($absPath)')],
    );
    await repository.putMigrationBatch(
      conversations: [conversation],
      messages: [(message: message, messageOrder: 0)],
      toolEventsByMessageId: const {},
      geminiSignaturesByMessageId: const {},
    );
    await repository.registerAsset(
      id: 'asset-k',
      contentHash: List.filled(64, 'b').join(),
      path: canonical,
      byteSize: 3,
      createdAt: now,
    );
    await repository.linkMessageAsset(
      conversationId: conversation.id,
      revisionId: message.id,
      assetId: 'asset-k',
      kind: 'image',
    );
    await repository.unlinkMessageAsset(
      revisionId: message.id,
      assetId: 'asset-k',
    );
    await repository.markMessageAssetReferencesDirty(message.id);
    expect(await repository.scheduleUnreferencedAssetGc(notBefore: now), 1);
    // Dual-form text refs must block claim (not only complete) so the file is
    // never quarantined while still referenced as an absolute path.
    expect(await repository.claimAssetGc(now: now), isEmpty);

    // Clear text refs so GC can finish.
    await repository.putMigrationBatch(
      conversations: [conversation],
      messages: [
        (
          message: message.copyWith(parts: const [TextPart('no refs')]),
          messageOrder: 0,
        ),
      ],
      toolEventsByMessageId: const {},
      geminiSignaturesByMessageId: const {},
    );
    await repository.markMessageAssetReferencesDirty(message.id);
    await repository.scheduleUnreferencedAssetGc(notBefore: now);
    // First claim deferred the protected row; advance past the defer window.
    final later = now.add(const Duration(hours: 6));
    final next = (await repository.claimAssetGc(now: later)).single;
    expect(
      await repository.completeAssetGc(
        assetId: 'asset-k',
        expectedGeneration: next.generation,
        path: next.path,
      ),
      isTrue,
    );
  });

  test('dirty malformed attachment payload blocks GC until repaired', () async {
    final root = await Directory.systemTemp.createTemp('asset_gc_malformed_');
    final dbFile = File('${root.path}/assets.sqlite');
    final repository = ChatDatabaseRepository.open(file: dbFile);
    addTearDown(() async {
      await repository.close();
      await root.delete(recursive: true);
    });

    final now = DateTime.utc(2026, 8, 10);
    const assetPath = r'C:\Users\Alice\Kelivo\images\corrupt.png';
    const conversationId = 'conversation-malformed-gc';
    const messageId = 'revision-malformed-gc';
    const assetId = 'asset-malformed-gc';
    final conversation = Conversation(
      id: conversationId,
      title: 'Malformed GC',
      createdAt: now,
      updatedAt: now,
      messageIds: const [messageId],
    );
    final message = ChatMessage(
      id: messageId,
      role: 'user',
      conversationId: conversationId,
      timestamp: now,
      parts: [ImagePart(uri: assetPath)],
    );
    await repository.putMigrationBatch(
      conversations: [conversation],
      messages: [(message: message, messageOrder: 0)],
      toolEventsByMessageId: const {},
      geminiSignaturesByMessageId: const {},
    );
    await repository.registerAsset(
      id: assetId,
      contentHash: List.filled(64, 'c').join(),
      path: assetPath,
      byteSize: 3,
      createdAt: now,
    );
    await repository.linkMessageAsset(
      conversationId: conversationId,
      revisionId: messageId,
      assetId: assetId,
      kind: 'image',
    );
    await repository.unlinkMessageAsset(
      revisionId: messageId,
      assetId: assetId,
    );

    final raw = sqlite.sqlite3.open(dbFile.path);
    try {
      raw.execute(
        'DELETE FROM asset_reference_dirty_rows WHERE revision_id = ?;',
        [messageId],
      );
    } finally {
      raw.close();
    }
    expect(await repository.scheduleUnreferencedAssetGc(notBefore: now), 1);
    final candidate = (await repository.claimAssetGc(now: now)).single;

    final malformedPayload = '${jsonEncode({'uri': assetPath})}broken';
    expect(malformedPayload.contains(assetPath), isFalse);
    final corrupt = sqlite.sqlite3.open(dbFile.path);
    try {
      corrupt.execute(
        'UPDATE message_part_rows SET payload = ? '
        'WHERE revision_id = ? AND kind = ?;',
        [malformedPayload, messageId, 'image'],
      );
      corrupt.execute(
        'INSERT OR IGNORE INTO asset_reference_dirty_rows(revision_id) '
        'VALUES (?);',
        [messageId],
      );
    } finally {
      corrupt.close();
    }

    expect(await repository.isAssetGcClaimStillValid(candidate), isFalse);
    expect(
      await repository.completeAssetGc(
        assetId: assetId,
        expectedGeneration: candidate.generation,
        path: candidate.path,
      ),
      isFalse,
    );
    expect(await repository.claimAssetGc(now: now), isEmpty);

    await repository.updateMessage(
      message.copyWith(parts: const [TextPart('attachment repaired')]),
    );
    await repository.replaceMessageAssetReferences(
      conversationId: conversationId,
      revisionId: messageId,
      assets: const [],
    );
    final repairedCandidate = (await repository.claimAssetGc(
      now: now.add(const Duration(hours: 6)),
    )).single;
    expect(
      await repository.completeAssetGc(
        assetId: assetId,
        expectedGeneration: repairedCandidate.generation,
        path: repairedCandidate.path,
      ),
      isTrue,
    );
  });

  test('claimAssetGc scans past text-protected page head', () async {
    final root = await Directory.systemTemp.createTemp('asset_gc_starve_');
    final repository = ChatDatabaseRepository.open(
      file: File('${root.path}/assets.sqlite'),
    );
    addTearDown(() async {
      await repository.close();
      await root.delete(recursive: true);
    });

    final now = DateTime.utc(2026, 7, 12);
    // IDs sort so the 50 protected rows precede the free candidate under
    // ORDER BY asset_id (the pre-filter SQL LIMIT surface).
    final protectedIds = <String>[
      for (var i = 0; i < 50; i++) 'asset-${i.toString().padLeft(2, '0')}',
    ];
    final protectedPaths = <String>[
      for (var i = 0; i < 50; i++) '${root.path}/protected_$i.png',
    ];
    const freeId = 'asset-50-free';
    final freePath = '${root.path}/free.png';

    final conversation = Conversation(
      id: 'conversation-starve',
      title: 'Starve',
      createdAt: now,
      updatedAt: now,
      messageIds: const ['revision-starve'],
    );
    final refs = protectedPaths.join(' ');
    final message = ChatMessage(
      id: 'revision-starve',
      role: 'assistant',
      content: 'refs $refs',
      timestamp: now,
      conversationId: conversation.id,
      parts: [TextPart('refs $refs')],
    );
    await repository.putMigrationBatch(
      conversations: [conversation],
      messages: [(message: message, messageOrder: 0)],
      toolEventsByMessageId: const {},
      geminiSignaturesByMessageId: const {},
    );

    String hashFor(int i) =>
        (i.toRadixString(16).padLeft(2, '0') * 32).substring(0, 64);

    for (var i = 0; i < 50; i++) {
      await repository.registerAsset(
        id: protectedIds[i],
        contentHash: hashFor(i),
        path: protectedPaths[i],
        byteSize: 1,
        createdAt: now,
      );
      await repository.linkMessageAsset(
        conversationId: conversation.id,
        revisionId: message.id,
        assetId: protectedIds[i],
        kind: 'image',
      );
      await repository.unlinkMessageAsset(
        revisionId: message.id,
        assetId: protectedIds[i],
      );
    }
    await repository.registerAsset(
      id: freeId,
      contentHash: hashFor(99),
      path: freePath,
      byteSize: 1,
      createdAt: now,
    );
    await repository.linkMessageAsset(
      conversationId: conversation.id,
      revisionId: message.id,
      assetId: freeId,
      kind: 'image',
    );
    await repository.unlinkMessageAsset(
      revisionId: message.id,
      assetId: freeId,
    );

    await repository.markMessageAssetReferencesDirty(message.id);
    expect(await repository.scheduleUnreferencedAssetGc(notBefore: now), 51);

    final claimed = await repository.claimAssetGc(now: now, limit: 1);
    expect(claimed, hasLength(1));
    expect(claimed.single.assetId, freeId);

    // Protected rows were deferred; a follow-up claim at the same [now]
    // should not surface them (not_before pushed into the future).
    final again = await repository.claimAssetGc(now: now, limit: 50);
    expect(again.map((c) => c.assetId), isNot(contains(protectedIds.first)));
    // The free asset may be re-claimed until completeAssetGc removes it.
    expect(again.where((c) => protectedIds.contains(c.assetId)), isEmpty);
  });

  test('chats-only recompute marks local attachments unavailable', () async {
    final root = await Directory.systemTemp.createTemp('chats_only_');
    final repository = ChatDatabaseRepository.open(
      file: File('${root.path}/assets.sqlite'),
    );
    addTearDown(() async {
      await repository.close();
      await root.delete(recursive: true);
    });
    final now = DateTime.utc(2026, 8, 1);
    final localPath = '${root.path}/images/local.png';
    Directory('${root.path}/images').createSync(recursive: true);
    File(localPath).writeAsBytesSync(const [9, 9, 9]);

    final conversation = Conversation(
      id: 'conversation-chats-only',
      title: 'Chats only',
      createdAt: now,
      updatedAt: now,
      messageIds: const ['revision-chats-only'],
    );
    final message = ChatMessage(
      id: 'revision-chats-only',
      role: 'user',
      content: '',
      timestamp: now,
      conversationId: conversation.id,
      parts: [
        ImagePart(uri: localPath, mime: 'image/png', unavailable: false),
        ImagePart(
          uri: 'https://cdn.example.com/a.png',
          mime: 'image/png',
          unavailable: false,
        ),
      ],
    );
    await repository.putMigrationBatch(
      conversations: [conversation],
      messages: [(message: message, messageOrder: 0)],
      toolEventsByMessageId: const {},
      geminiSignaturesByMessageId: const {},
    );

    final updated = await repository
        .recomputeAttachmentAvailabilityForConversations(
          conversationIds: [conversation.id],
          filesRestored: false,
        );
    expect(updated, 1);
    final after = (await repository.getMessagesRange(
      conversation.id,
      start: 0,
      limit: 10,
    )).single;
    final parts = after.parts.whereType<ImagePart>().toList();
    expect(parts[0].unavailable, isTrue);
    expect(parts[1].unavailable, isFalse);
  });

  test(
    'overwrite chats-only offline recompute marks local unavailable even when path exists',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'overwrite_chats_only_',
      );
      addTearDown(() async {
        if (root.existsSync()) await root.delete(recursive: true);
      });
      final dbFile = File('${root.path}/candidate.sqlite');
      final targetPath = '${root.path}/images/photo.png';
      Directory('${root.path}/images').createSync(recursive: true);
      // Target file exists with bytes B.
      File(targetPath).writeAsBytesSync(const [2, 2, 2, 2]);

      final repository = ChatDatabaseRepository.open(file: dbFile);
      final now = DateTime.utc(2026, 9, 1);
      final conversation = Conversation(
        id: 'conversation-overwrite',
        title: 'Overwrite',
        createdAt: now,
        updatedAt: now,
        messageIds: const ['revision-overwrite'],
      );
      // Candidate records hash A for the same path (different from live bytes).
      await repository.registerAsset(
        id: 'asset_hash_a',
        contentHash: 'hash-A-not-live-bytes',
        path: targetPath,
        byteSize: 4,
      );
      final message = ChatMessage(
        id: 'revision-overwrite',
        role: 'user',
        content: '',
        timestamp: now,
        conversationId: conversation.id,
        parts: [
          ImagePart(
            uri: targetPath,
            mime: 'image/png',
            assetId: 'asset_hash_a',
            unavailable: false,
          ),
          ImagePart(
            uri: 'https://cdn.example.com/remote.png',
            mime: 'image/png',
            unavailable: false,
          ),
          ImagePart(
            uri: 'data:image/png;base64,aaa',
            mime: 'image/png',
            unavailable: false,
          ),
        ],
      );
      await repository.putMigrationBatch(
        conversations: [conversation],
        messages: [(message: message, messageOrder: 0)],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );
      await repository.close();

      final updated =
          await ChatDatabaseRepository.recomputeAttachmentAvailabilityOnDatabaseFile(
            databaseFile: dbFile,
            filesRestored: false,
          );
      expect(updated, 1);

      final verify = ChatDatabaseRepository.open(file: dbFile);
      addTearDown(verify.close);
      final after = (await verify.getMessagesRange(
        conversation.id,
        start: 0,
        limit: 10,
      )).single;
      final parts = after.parts.whereType<ImagePart>().toList();
      expect(
        parts[0].unavailable,
        isTrue,
      ); // local path must not stay available
      expect(parts[1].unavailable, isFalse); // remote
      expect(parts[2].unavailable, isFalse); // data
    },
  );
}
