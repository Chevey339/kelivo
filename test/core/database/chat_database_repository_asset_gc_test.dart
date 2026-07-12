import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';

void main() {
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
      await repository.backfillMissingMessageGraphs();
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

      await repository.linkMessageAsset(
        conversationId: conversation.id,
        revisionId: message.id,
        assetId: 'asset-1',
        kind: 'image',
      );
      expect(await repository.claimAssetGc(now: now), isEmpty);
      expect(await repository.completeAssetGc(assetId: 'asset-1'), isFalse);

      await repository.unlinkMessageAsset(
        revisionId: message.id,
        assetId: 'asset-1',
      );
      await repository.scheduleUnreferencedAssetGc(notBefore: now);
      expect(await repository.completeAssetGc(assetId: 'asset-1'), isTrue);
    },
  );
}
