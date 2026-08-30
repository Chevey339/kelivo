import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/database_installation_gate.dart';
import 'package:Kelivo/core/services/backup/local_copy_catalog.dart';
import 'package:Kelivo/core/services/backup/local_snapshot_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('LocalCopyCatalog', () {
    late Directory root;
    late LocalSnapshotStore store;
    late LocalCopyCatalog catalog;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('kelivo_local_copies_');
      store = LocalSnapshotStore(appDataDirectory: root);
      catalog = LocalCopyCatalog(appDataDirectory: root, store: store);
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    Future<void> publishSnapshot(DateTime at) async {
      final staged = File(
        p.join(root.path, 'staged_${at.microsecondsSinceEpoch}'),
      );
      await staged.writeAsString('archive');
      await store.publish(
        prepared: staged,
        createdAtUtc: at,
        origin: LocalSnapshotOrigin.automatic,
        conversationCount: 2,
        messageCount: 20,
      );
    }

    /// Produces a displaced family the way crash recovery does.
    Future<void> displaceOnce() async {
      await DatabaseInstallationGate.ensureReady(appDataDirectory: root);
      await for (final entity in root.list(followLinks: false)) {
        if (p.basename(entity.path).startsWith('database_installation_')) {
          await entity.delete();
        }
      }
      await DatabaseInstallationGate.rebuildFresh(appDataDirectory: root);
    }

    test('两种副本合成一个列表，按时间倒序', () async {
      await displaceOnce();
      await publishSnapshot(DateTime.utc(2020, 1, 1));

      final copies = await catalog.list();

      expect(copies, hasLength(2));
      // 改名副本是刚刚产生的，所以排在 2020 年那份快照前面。
      expect(copies.first.kind, LocalCopyKind.displaced);
      expect(copies.last.kind, LocalCopyKind.snapshot);
    });

    test('快照带内容计数，改名副本不猜', () async {
      await displaceOnce();
      await publishSnapshot(DateTime.utc(2026, 5, 1));

      final copies = await catalog.list();
      final snapshot = copies.firstWhere(
        (copy) => copy.kind == LocalCopyKind.snapshot,
      );
      final displaced = copies.firstWhere(
        (copy) => copy.kind == LocalCopyKind.displaced,
      );

      expect(snapshot.messageCount, 20);
      expect(snapshot.isArchive, isTrue);
      expect(displaced.messageCount, isNull);
      expect(displaced.isArchive, isFalse);
    });

    test('删除按种类分发到各自的归属处', () async {
      await displaceOnce();
      await publishSnapshot(DateTime.utc(2026, 5, 1));

      for (final copy in await catalog.list()) {
        await catalog.delete(copy);
      }

      expect(await catalog.list(), isEmpty);
      expect(
        await DatabaseInstallationGate.hasDisplacedDatabases(
          appDataDirectory: root,
        ),
        isFalse,
      );
      // 活库不受影响。
      expect(
        await File(p.join(root.path, AppDatabase.databaseFileName)).exists(),
        isTrue,
      );
    });

    test('空目录返回空列表而不是抛错', () async {
      expect(await catalog.list(), isEmpty);
      expect(await catalog.totalBytes(), 0);
    });
  });
}
