import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/database_installation_gate.dart';
import 'package:Kelivo/core/database/private_data_storage.dart';
import 'package:Kelivo/core/database/startup_recovery_service.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/services/backup/local_copy_catalog.dart';
import 'package:Kelivo/core/services/backup/local_snapshot_store.dart';
import 'package:Kelivo/core/services/backup/restore_bundle_preparation.dart';
import 'package:Kelivo/core/services/backup/restore_durability.dart';
import 'package:Kelivo/core/services/backup/restore_startup_gate.dart';
import 'package:Kelivo/core/services/backup/restore_receipt.dart';
import 'package:Kelivo/core/services/storage/device_storage_probe.dart';
import 'package:Kelivo/core/services/storage/storage_usage_service.dart';
import 'package:Kelivo/utils/app_directories.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';
import '../../support/recovery_snapshot_fixture.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final Directory root;
  @override
  Future<String?> getApplicationDocumentsPath() async =>
      p.join(root.path, 'Documents');
  @override
  Future<String?> getApplicationSupportPath() async =>
      p.join(root.path, 'Library', 'Application Support');
  @override
  Future<String?> getApplicationCachePath() async =>
      p.join(root.path, 'Library', 'Caches');
  @override
  Future<String?> getTemporaryPath() async => p.join(root.path, 'tmp');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root, documents, databaseRoot;
  late PathProviderPlatform previousPaths;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('kelivo-split-storage-');
    previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    documents = await (await AppDirectories.getContentDirectory()).create(
      recursive: true,
    );
    databaseRoot = await AppDirectories.getAppDataDirectory();
    final repository = ChatDatabaseRepository.open(
      file: File(p.join(documents.path, 'kelivo.db')),
    );
    try {
      await repository.ensureReady();
      await repository.putMigrationBatch(
        conversations: [
          Conversation(id: 'old', title: 'Retained conversation'),
        ],
        messages: const [],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );
      await repository.checkpoint();
    } finally {
      await repository.close();
    }
  });
  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    PathProviderPlatform.instance = previousPaths;
    DeviceStorageProbe.debugOverride = null;
    SandboxPathResolver.debugSetDirs();
    await root.delete(recursive: true);
  });

  test(
    'protects only database state and keeps large public assets in place',
    () async {
      final image = await _write(
        documents,
        'images/photo.png',
        List.filled(4 * 1024 * 1024, 7),
      );
      final snapshot = await _write(
        documents,
        'snapshots 2/kelivo-snapshot-1.zip',
        [8, 9],
      );
      final archivedImage = await _write(
        documents,
        '.kelivo_restore/completed/run_${'1' * 32}/previous/images/large.png',
        List.filled(4 * 1024 * 1024, 3),
      );
      final retiredDatabase = await _write(
        documents,
        'kelivo.db.displaced-1792600000000000/kelivo.db',
        [9, 8, 7],
      );
      final database = File(p.join(documents.path, 'kelivo.db'));
      final before = await database.readAsBytes();
      DeviceStorageProbe.debugOverride = () async =>
          64 * 1024 * 1024 + before.length + 1024;
      await PrivateDataStorage.prepare(source: documents, target: databaseRoot);
      expect(
        await File(p.join(databaseRoot.path, 'kelivo.db')).readAsBytes(),
        before,
      );
      expect(await database.readAsBytes(), before);
      expect(
        await Directory(p.join(databaseRoot.path, 'images')).exists(),
        isFalse,
      );
      expect(
        await Directory(p.join(databaseRoot.path, 'snapshots 2')).exists(),
        isFalse,
      );
      expect(await image.length(), 4 * 1024 * 1024);
      expect(await archivedImage.length(), 4 * 1024 * 1024);
      expect(await retiredDatabase.readAsBytes(), [9, 8, 7]);
      expect(
        await Directory(
          p.join(databaseRoot.path, '.kelivo_restore', 'completed'),
        ).exists(),
        isFalse,
      );
      expect(
        await Directory(
          p.join(databaseRoot.path, 'kelivo.db.displaced-1792600000000000'),
        ).exists(),
        isFalse,
      );
      expect(await snapshot.readAsBytes(), [8, 9]);
      expect(
        (await AppDirectories.getImagesDirectory()).path,
        image.parent.path,
      );
      await SandboxPathResolver.init();
      expect(
        SandboxPathResolver.resolveForIo('kelivo-file:///images/photo.png'),
        image.path,
      );
    },
  );

  test(
    'publishes new snapshots in Files and still finds renamed public copies',
    () async {
      await PrivateDataStorage.prepare(source: documents, target: databaseRoot);
      final archive = await writeRecoverySnapshot(
        File(p.join(root.path, 'prepared.zip')),
      );
      final store = LocalSnapshotStore(appDataDirectory: databaseRoot);
      final entry = await store.publish(
        prepared: archive,
        createdAtUtc: DateTime.utc(2026, 10, 21),
        origin: LocalSnapshotOrigin.manual,
        conversationCount: 2,
        messageCount: 42,
      );
      expect(entry.file.parent.path, p.join(documents.path, 'snapshots'));
      expect(
        await Directory(p.join(databaseRoot.path, 'snapshots')).exists(),
        isFalse,
      );
      final before = await entry.file.readAsBytes();
      await entry.file.parent.rename(p.join(documents.path, 'snapshots 2'));
      final copies = await LocalCopyCatalog(
        appDataDirectory: databaseRoot,
      ).list();
      final snapshot = copies.singleWhere((copy) => copy.isArchive);
      expect(snapshot.file.parent.path, p.join(documents.path, 'snapshots 2'));
      expect(await snapshot.file.readAsBytes(), before);
      await File(
        p.join(databaseRoot.path, 'kelivo.db'),
      ).rename(p.join(root.path, 'removed-db'));
      await expectLater(
        DatabaseInstallationGate.ensureReady(appDataDirectory: databaseRoot),
        throwsA(isA<StateError>()),
      );
      expect(
        await File(p.join(databaseRoot.path, 'kelivo.db')).exists(),
        isFalse,
      );
      expect(await snapshot.file.readAsBytes(), before);
    },
  );

  test(
    'exports both database and public files from the failure screen service',
    () async {
      await _write(documents, 'images/retained.png', [1, 2, 3]);
      await PrivateDataStorage.prepare(source: documents, target: databaseRoot);
      final archive = await StartupDiagnosticsService.createDataArchive(
        appDataDirectory: databaseRoot,
        workingDirectory: Directory(p.join(root.path, 'export')),
      );
      final zip = ZipDecoder().decodeBytes(await archive.readAsBytes());
      expect(zip.findFile('data-0/kelivo.db'), isNotNull);
      expect(zip.findFile('data-1/images/retained.png')!.content, [1, 2, 3]);
      expect(zip.findFile('data-1/kelivo.db'), isNotNull);
    },
  );

  test(
    'accounts for public images and snapshots without classifying everything as Other',
    () async {
      await _write(documents, 'images/photo.png', List.filled(101, 1));
      await _write(
        documents,
        'snapshots 2/kelivo-snapshot-1.zip',
        List.filled(203, 2),
      );
      final oldDatabase = await _write(documents, 'kelivo.db.displaced-123', [
        1,
        2,
      ]);
      final oldWal = await _write(documents, 'kelivo.db.displaced-123-wal', [
        3,
        4,
        5,
      ]);
      await PrivateDataStorage.prepare(source: documents, target: databaseRoot);
      final report = await StorageUsageService.computeReport();
      expect(
        report.categories
            .singleWhere((c) => c.key == StorageUsageCategoryKey.images)
            .stats
            .bytes,
        101,
      );
      expect(
        report.categories
            .singleWhere((c) => c.key == StorageUsageCategoryKey.localSnapshots)
            .stats
            .bytes,
        203,
      );
      expect(
        report.categories.where(
          (c) => c.key == StorageUsageCategoryKey.displacedDatabases,
        ),
        isEmpty,
      );
      await StorageUsageService.clearDisplacedDatabases();
      expect(await oldDatabase.readAsBytes(), [1, 2]);
      expect(await oldWal.readAsBytes(), [3, 4, 5]);
      var databaseBytes = 0;
      for (final suffix in ['', '-wal', '-shm']) {
        final file = File(p.join(databaseRoot.path, 'kelivo.db$suffix'));
        if (await file.exists()) databaseBytes += await file.length();
      }
      expect(
        report.categories
            .singleWhere((c) => c.key == StorageUsageCategoryKey.chatData)
            .stats
            .bytes,
        databaseBytes,
      );
    },
  );

  test(
    'interrupted full restore resumes with the database private and assets public',
    () async {
      final oldImage = await _write(documents, 'images/old.png', [1, 2, 3]);
      await PrivateDataStorage.prepare(source: documents, target: databaseRoot);
      final originalDatabase = await File(
        p.join(documents.path, 'kelivo.db'),
      ).readAsBytes();
      final archive = await writeRecoverySnapshot(
        File(p.join(root.path, 'source.zip')),
      );
      final sourceArchive = await archive.readAsBytes();
      final extracted = await Directory(
        p.join(root.path, 'extracted'),
      ).create();
      extractArchiveToDisk(
        ZipDecoder().decodeBytes(sourceArchive),
        extracted.path,
      );
      final newImage = await _write(extracted, 'images/new.png', [4, 5, 6]);
      final manifestFile = File(p.join(extracted.path, 'manifest.json'));
      final manifest =
          jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
      manifest['includeFiles'] = true;
      (manifest['entries'] as Map)['images/new.png'] = {
        'bytes': 3,
        'sha256': sha256.convert(await newImage.readAsBytes()).toString(),
      };
      await manifestFile.writeAsString(jsonEncode(manifest));
      final prepared = await RestoreBundlePreparation.prepare(
        appDataDirectory: databaseRoot,
        extractedDirectory: extracted,
        sourceManifestSha256: sha256
            .convert(await manifestFile.readAsBytes())
            .toString(),
        bundleIncludesChats: true,
        bundleIncludesFiles: true,
        restoreChats: true,
        restoreFiles: true,
      );
      await expectLater(
        RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: databaseRoot,
          durability: _InterruptImageMove(oldImage.parent.path),
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(_ids(databaseRoot), ['old']);
      expect(
        await File(
          p.join(
            prepared.workspace.path,
            'previous.pending',
            'images',
            'old.png',
          ),
        ).readAsBytes(),
        [1, 2, 3],
      );
      final outcome = await RestoreStartupGate.recoverAndRequireBusinessReady(
        appDataDirectory: databaseRoot,
      );
      expect(outcome!.state, RestoreReceiptState.committed);
      expect(_ids(databaseRoot), ['conversation-0', 'conversation-1']);
      expect(
        await File(p.join(documents.path, 'images', 'new.png')).readAsBytes(),
        [4, 5, 6],
      );
      expect(
        await Directory(p.join(databaseRoot.path, 'images')).exists(),
        isFalse,
      );
      expect(
        await File(p.join(documents.path, 'kelivo.db')).readAsBytes(),
        originalDatabase,
      );
      expect(await archive.readAsBytes(), sourceArchive);
      final retained = await databaseRoot
          .list(recursive: true)
          .where((f) => p.basename(f.path) == 'old.png')
          .toList();
      expect(retained, hasLength(1));
      expect(await File(retained.single.path).readAsBytes(), [1, 2, 3]);
    },
  );
}

Future<File> _write(Directory root, String relative, List<int> bytes) async {
  final file = File(p.join(root.path, relative));
  await file.parent.create(recursive: true);
  return file.writeAsBytes(bytes);
}

List<String> _ids(Directory root) {
  final db = sqlite.sqlite3.open(p.join(root.path, 'kelivo.db'));
  try {
    return db
        .select('SELECT id FROM conversation_rows ORDER BY id')
        .map((r) => r['id'] as String)
        .toList();
  } finally {
    db.close();
  }
}

class _InterruptImageMove implements RestoreDurability {
  _InterruptImageMove(this.imageDirectory);
  final String imageDirectory;
  final delegate = RestorePlatformDurability();
  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    await delegate.renameAndSync(source: source, targetPath: targetPath);
    if (source.path == imageDirectory &&
        targetPath.contains('previous.pending')) {
      throw FileSystemException(
        'simulated exit after preserving images',
        targetPath,
      );
    }
  }

  @override
  Future<void> restrictDirectory(Directory d) => delegate.restrictDirectory(d);
  @override
  Future<void> restrictFile(File f) => delegate.restrictFile(f);
  @override
  Future<void> syncDirectory(Directory d, {bool fullBarrier = false}) =>
      delegate.syncDirectory(d, fullBarrier: fullBarrier);
  @override
  Future<void> syncFile(File f, {bool fullBarrier = false}) =>
      delegate.syncFile(f, fullBarrier: fullBarrier);
}
