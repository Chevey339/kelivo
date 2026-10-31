import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/services/storage/storage_space.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/database_installation_gate.dart';
import 'package:Kelivo/core/database/private_data_storage.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/providers/local_snapshot_provider.dart';
import 'package:Kelivo/core/services/backup/data_sync.dart';
import 'package:Kelivo/core/services/backup/local_copy_catalog.dart';
import 'package:Kelivo/core/services/backup/recovery_file_discovery.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/storage/device_storage_probe.dart';
import 'package:Kelivo/utils/app_directories.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';
import '../../support/recovery_fault_durability.dart';
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

int chatsIn(File file) {
  final db = sqlite.sqlite3.open(file.path, mode: sqlite.OpenMode.readOnly);
  try {
    return db.select('SELECT COUNT(*) AS n FROM conversation_rows').single['n']
        as int;
  } finally {
    db.close();
  }
}

Future<String> digest(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory root, documents, private;
  late File source;
  late String originalHash;
  late PathProviderPlatform previous;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('release132-check-');
    previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    documents = await (await AppDirectories.getContentDirectory()).create(
      recursive: true,
    );
    private = await AppDirectories.getAppDataDirectory();
    source = File(p.join(documents.path, 'kelivo.db'));
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Kelivo',
      packageName: 'Kelivo',
      version: '1.3.2',
      buildNumber: '82',
      buildSignature: 'test',
    );
    DeviceStorageProbe.debugOverride = () async => 1024 * 1024 * 1024;
    final repository = ChatDatabaseRepository.open(file: source);
    try {
      await repository.ensureReady();
      await repository.putConversation(
        Conversation(id: 'before-upgrade', title: 'Before upgrade'),
      );
      await repository.checkpoint();
    } finally {
      await repository.close();
    }
    originalHash = await digest(source);
  });
  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    PathProviderPlatform.instance = previous;
    DeviceStorageProbe.debugOverride = null;
    SandboxPathResolver.debugSetDirs();
    await root.delete(recursive: true);
  });

  test(
    'snapshot builder reads private database after migration, even when public original is renamed',
    () async {
      await PrivateDataStorage.prepare(source: documents, target: private);
      await DatabaseInstallationGate.ensureReady(appDataDirectory: private);
      final privateFile = File(p.join(private.path, 'kelivo.db'));
      final db = AppDatabase.open(file: privateFile);
      final repository = ChatDatabaseRepository(db, databaseFile: privateFile);
      final business = BusinessRepository(db);
      final prefs = BusinessPreferences(business);
      await prefs.load();
      final chat = ChatService(existingRepository: repository);
      final provider = LocalSnapshotProvider(
        appDataDirectory: private,
        chatService: chat,
        businessRepository: business,
        businessPreferences: prefs,
        autoLoad: false,
      );
      try {
        await chat.init();
        await repository.putConversation(
          Conversation(id: 'private-only', title: 'Created after upgrade'),
        );
        final publicRenamed = await source.rename(
          p.join(documents.path, 'kelivo 2.db'),
        );
        final entry = await provider.takeNow(prune: false);
        final info = await DataSync.inspectRecoverySnapshot(entry.file);
        expect(info.conversationCount, 2);
        expect(entry.file.parent.path, p.join(documents.path, 'snapshots'));
        expect(await digest(publicRenamed), originalHash);
      } finally {
        provider.dispose();
        await chat.close();
        chat.dispose();
        await repository.close();
      }
    },
  );

  test(
    'low-space migration blocks startup but retains old DB and can retry',
    () async {
      DeviceStorageProbe.debugOverride = () async => 1024;
      await expectLater(
        PrivateDataStorage.prepare(source: documents, target: private),
        throwsA(isA<InsufficientStorageSpace>()),
      );
      expect(await digest(source), originalHash);
      expect(await private.exists(), false);
      DeviceStorageProbe.debugOverride = () async => 1024 * 1024 * 1024;
      await PrivateDataStorage.prepare(source: documents, target: private);
      await DatabaseInstallationGate.ensureReady(appDataDirectory: private);
      expect(chatsIn(File(p.join(private.path, 'kelivo.db'))), 1);
      expect(await digest(source), originalHash);
    },
  );

  test(
    'ENOSPC injected after database copy preserves source and resumes',
    () async {
      final durability = FaultDurability()
        ..onSync = (file) async {
          if (p.basename(file.path) == 'kelivo.db' &&
              file.path.contains('.kelivo-data-staging-')) {
            throw FileSystemException(
              'No space left on device',
              file.path,
              const OSError('No space left on device', 28),
            );
          }
        };
      await expectLater(
        PrivateDataStorage.prepare(
          source: documents,
          target: private,
          durability: durability,
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(await digest(source), originalHash);
      expect(await private.exists(), false);
      await PrivateDataStorage.prepare(source: documents, target: private);
      await DatabaseInstallationGate.ensureReady(appDataDirectory: private);
      expect(chatsIn(File(p.join(private.path, 'kelivo.db'))), 1);
      expect(await digest(source), originalHash);
    },
  );

  test(
    'preexisting renamed DB yields markers-only private directory plus explicit missing-prior-data error',
    () async {
      final renamed = await source.rename(
        p.join(documents.path, 'kelivo 2.db'),
      );
      await PrivateDataStorage.prepare(source: documents, target: private);
      expect(await File(p.join(private.path, 'kelivo.db')).exists(), false);
      expect(
        await File(p.join(private.path, PrivateDataStorage.readyName)).exists(),
        true,
      );
      await expectLater(
        DatabaseInstallationGate.ensureReady(appDataDirectory: private),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'database_missing_with_prior_data',
          ),
        ),
      );
      expect(await digest(renamed), originalHash);
      final copies = await LocalCopyCatalog(appDataDirectory: private).list();
      expect(copies.any((c) => c.file.path == renamed.path), true);
    },
  );

  test(
    'app-local trash copies block fresh initialization and remain discoverable',
    () async {
      final trash = await Directory(
        p.join(documents.path, '.Trash', 'retained'),
      ).create(recursive: true);
      final retained = await source.rename(p.join(trash.path, 'kelivo.db'));
      final snapshot = await writeRecoverySnapshot(
        File(
          p.join(
            trash.path,
            'snapshots',
            'kelivo-snapshot-1792421104232879.zip',
          ),
        ),
      );
      expect(
        (await DataSync.inspectRecoverySnapshot(snapshot)).messageCount,
        42,
      );
      final snapshotHash = await digest(snapshot);
      await PrivateDataStorage.prepare(source: documents, target: private);
      final copies = await LocalCopyCatalog(appDataDirectory: private).list();
      expect(
        copies.map((c) => c.file.path),
        containsAll([retained.path, snapshot.path]),
      );
      expect(await RecoveryFileDiscovery.hasPriorData(private), true);
      await expectLater(
        DatabaseInstallationGate.ensureReady(appDataDirectory: private),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'code',
            'database_missing_with_prior_data',
          ),
        ),
      );
      expect(await File(p.join(private.path, 'kelivo.db')).exists(), false);
      expect(await digest(retained), originalHash);
      expect(await digest(snapshot), snapshotHash);
    },
  );
}
