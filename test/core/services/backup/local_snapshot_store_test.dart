import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/services/backup/local_snapshot_retention.dart';
import 'package:Kelivo/core/services/backup/local_snapshot_schedule.dart';
import 'package:Kelivo/core/services/backup/local_snapshot_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('LocalSnapshotStore', () {
    late Directory root;
    late LocalSnapshotStore store;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('kelivo_local_snapshot_');
      store = LocalSnapshotStore(appDataDirectory: root);
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    Future<File> prepared(String content) async {
      final file = File(
        p.join(root.path, 'staged_${DateTime.now().microsecondsSinceEpoch}'),
      );
      await file.writeAsString(content);
      return file;
    }

    Future<LocalSnapshotEntry> publish({
      required DateTime at,
      int messageCount = 10,
      LocalSnapshotOrigin origin = LocalSnapshotOrigin.automatic,
      bool pinned = false,
      String content = 'archive-bytes',
    }) async => store.publish(
      prepared: await prepared(content),
      createdAtUtc: at,
      origin: origin,
      pinned: pinned,
      conversationCount: 3,
      messageCount: messageCount,
      appVersion: '1.2.4+1',
    );

    test('发布后归档与元数据都在，且能读回', () async {
      final at = DateTime.utc(2026, 5, 1);
      final entry = await publish(at: at);

      expect(await entry.file.exists(), isTrue);
      expect(p.dirname(entry.file.path), store.directory.path);

      final listed = await store.list();
      expect(listed, hasLength(1));
      expect(listed.single.createdAt, at);
      expect(listed.single.messageCount, 10);
      expect(listed.single.conversationCount, 3);
      expect(listed.single.appVersion, '1.2.4+1');
      expect(listed.single.origin, LocalSnapshotOrigin.automatic);
    });

    test('发布消费掉源文件，不留临时残骸', () async {
      final source = await prepared('archive-bytes');
      await store.publish(
        prepared: source,
        createdAtUtc: DateTime.utc(2026, 5, 1),
        origin: LocalSnapshotOrigin.manual,
        conversationCount: 1,
        messageCount: 1,
      );

      expect(await source.exists(), isFalse);
      final names = await store.directory
          .list()
          .map((entity) => p.basename(entity.path))
          .toList();
      expect(
        names.where(
          (name) => name.startsWith(LocalSnapshotPaths.temporaryPrefix),
        ),
        isEmpty,
      );
    });

    test('空归档不予发布，且不留下半份元数据', () async {
      final source = await prepared('');
      await expectLater(
        store.publish(
          prepared: source,
          createdAtUtc: DateTime.utc(2026, 5, 1),
          origin: LocalSnapshotOrigin.automatic,
          conversationCount: 0,
          messageCount: 0,
        ),
        throwsA(isA<StateError>()),
      );
      expect(await store.list(), isEmpty);
      final leftovers = await store.directory
          .list()
          .map((entity) => p.basename(entity.path))
          .toList();
      expect(leftovers, isEmpty);
    });

    test('元数据丢了也要照样列出，且不被当成空副本清掉', () async {
      final entry = await publish(
        at: DateTime.utc(2026, 5, 1),
        messageCount: 0,
      );
      await File(
        '${entry.file.path}${LocalSnapshotPaths.metadataSuffix}',
      ).delete();

      final listed = await store.list();
      expect(listed, hasLength(1));
      // 未知不等于空：0 会让保留策略把它当作可丢弃的。
      expect(listed.single.messageCount, greaterThan(0));
    });

    test('恢复前副本创建时即 pinned', () async {
      final entry = await publish(
        at: DateTime.utc(2026, 5, 1),
        origin: LocalSnapshotOrigin.beforeRestore,
        pinned: true,
      );
      expect(entry.retention.pinned, isTrue);
    });

    test('恢复前副本可以被取消保留，不然会永久堆积', () async {
      // pinned 若从 origin 反推，取消保留的按钮就是死的，而且每恢复一次就多
      // 一份保留策略永远无权回收的副本。
      final entry = await publish(
        at: DateTime.utc(2026, 5, 1),
        origin: LocalSnapshotOrigin.beforeRestore,
        pinned: true,
      );

      await store.setPinned(entry.id, false);

      final listed = await store.list();
      expect(listed.single.pinned, isFalse);
      expect(listed.single.retention.pinned, isFalse);
    });

    test('清理按策略删除，且元数据一起删掉', () async {
      for (var day = 1; day <= 5; day++) {
        await publish(at: DateTime.utc(2026, 5, day));
      }
      expect(await store.list(), hasLength(5));

      final removed = await store.prune(
        const LocalSnapshotRetentionPolicy(
          keepRecent: 2,
          keepWeekly: false,
          keepMonthly: false,
        ),
        now: DateTime.utc(2026, 5, 6),
      );

      expect(removed, hasLength(3));
      expect(await store.list(), hasLength(2));
      final remaining = await store.directory
          .list()
          .map((entity) => p.basename(entity.path))
          .toList();
      // 每份副本一个归档 + 一个 sidecar，没有孤儿。
      expect(remaining, hasLength(4));
    });

    test('sweepIncomplete 也清掉没有归档的孤儿元数据', () async {
      // 元数据先落盘、归档后改名，中间崩一次就会留下一个 list() 永远看不见、
      // 因此永远清不掉的 sidecar。
      await store.ensureDirectory();
      final orphan = File(
        p.join(
          store.directory.path,
          '${LocalSnapshotPaths.fileNameFor(DateTime.utc(2026, 5, 1))}'
          '${LocalSnapshotPaths.metadataSuffix}',
        ),
      );
      await orphan.writeAsString('{}');

      await store.sweepIncomplete();

      expect(await orphan.exists(), isFalse);
    });

    test('sweepIncomplete 不碰有归档的元数据', () async {
      final entry = await publish(at: DateTime.utc(2026, 5, 1));
      final sidecar = File(
        '${entry.file.path}${LocalSnapshotPaths.metadataSuffix}',
      );

      await store.sweepIncomplete();

      expect(await sidecar.exists(), isTrue);
      expect(await store.list(), hasLength(1));
    });

    test('删不掉时如实报错，而不是假装删掉了', () async {
      final entry = await publish(at: DateTime.utc(2026, 5, 1));
      // 归档换成目录：删文件的调用删不动它。
      await entry.file.delete();
      await Directory(entry.file.path).create();

      await expectLater(
        store.delete(entry.id),
        throwsA(isA<FileSystemException>()),
      );

      await Directory(entry.file.path).delete();
    });

    test('sweepIncomplete 清掉中断留下的半成品', () async {
      await store.ensureDirectory();
      final debris = File(
        p.join(
          store.directory.path,
          '${LocalSnapshotPaths.temporaryPrefix}'
          '${LocalSnapshotPaths.fileNameFor(DateTime.utc(2026, 5, 1))}',
        ),
      );
      await debris.writeAsString('half');

      await store.sweepIncomplete();

      expect(await debris.exists(), isFalse);
    });

    test('半成品不会被当成可用副本列出', () async {
      await store.ensureDirectory();
      await File(
        p.join(
          store.directory.path,
          '${LocalSnapshotPaths.temporaryPrefix}'
          '${LocalSnapshotPaths.fileNameFor(DateTime.utc(2026, 5, 1))}',
        ),
      ).writeAsString('half');

      expect(await store.list(), isEmpty);
    });

    test('setPinned 落盘后能读回', () async {
      final entry = await publish(at: DateTime.utc(2026, 5, 1));
      await store.setPinned(entry.id, true);

      final listed = await store.list();
      expect(listed.single.pinned, isTrue);
      expect(listed.single.retention.pinned, isTrue);
    });

    test('损坏的 sidecar 不会让副本消失', () async {
      final entry = await publish(at: DateTime.utc(2026, 5, 1));
      await File(
        '${entry.file.path}${LocalSnapshotPaths.metadataSuffix}',
      ).writeAsString('{not json');

      final listed = await store.list();
      expect(listed, hasLength(1));
      expect(listed.single.messageCount, greaterThan(0));
    });

    test('sidecar 记录的字段可被外部读取校验', () async {
      final entry = await publish(at: DateTime.utc(2026, 5, 1));
      final sidecar = File(
        '${entry.file.path}${LocalSnapshotPaths.metadataSuffix}',
      );
      final decoded =
          jsonDecode(await sidecar.readAsString()) as Map<String, dynamic>;

      expect(decoded['origin'], 'automatic');
      expect(decoded['messageCount'], 10);
      expect(decoded['bytes'], await entry.file.length());
    });
  });
}
