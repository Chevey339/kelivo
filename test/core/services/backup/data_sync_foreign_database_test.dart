import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/database/business_restore_service.dart';
import 'package:Kelivo/core/services/backup/data_sync.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);

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

Map<String, Object?> _entryFrom(File archiveFile, String name) {
  final archive = ZipDecoder().decodeBytes(archiveFile.readAsBytesSync());
  final entry = archive.findFile(name);
  if (entry == null) throw StateError(name);
  return jsonDecode(utf8.decode(entry.readBytes()!)) as Map<String, Object?>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DataSync.prepareBackupFileFromDatabase', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('kelivo_foreign_db_');
      PathProviderPlatform.instance = _FakePathProvider(root.path);
      PackageInfo.setMockInitialValues(
        appName: 'Kelivo',
        packageName: 'Kelivo',
        version: '1.0.0-test',
        buildNumber: '1',
        buildSignature: 'test',
      );
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    /// Writes a standalone database carrying [secret], the way a set-aside
    /// copy on a user's device would look.
    Future<File> writeDatabase(String name, String secret) async {
      final file = File('${root.path}/$name');
      final database = AppDatabase.open(file: file);
      try {
        await BusinessRestoreService(BusinessRepository(database)).overwrite({
          'provider_configs_v1': jsonEncode({
            'only': {'id': 'only', 'name': 'Only', 'apiKey': secret},
          }),
          'providers_order_v1': <String>['only'],
        });
      } finally {
        await database.close();
      }
      return file;
    }

    test('把一份独立数据库打成标准备份归档', () async {
      final source = await writeDatabase('kelivo.db.displaced-0001', 'aside');
      final live = await writeDatabase('live.sqlite', 'current');
      final liveDatabase = AppDatabase.open(file: live);
      File? archive;
      try {
        archive = await DataSync(
          chatService: ChatService(),
          businessRepository: BusinessRepository(liveDatabase),
        ).prepareBackupFileFromDatabase(source);

        final manifest = _entryFrom(archive, 'manifest.json');
        expect(manifest['format'], 'kelivo-backup');
        expect(manifest['payloadKind'], 'sqlite');
        expect(manifest['includeChats'], isTrue);
        // 附件不进本地副本：它们和活库在同一块盘上。
        expect(manifest['includeFiles'], isFalse);
        expect(
          (manifest['database'] as Map)['schemaVersion'],
          AppDatabase.currentSchemaVersion,
        );

        final settings = _entryFrom(archive, 'settings.json');
        final providers =
            jsonDecode(settings['provider_configs_v1'] as String) as Map;
        // 关键：设置必须来自被打包的那份库，而不是当前活着的那份。
        expect((providers['only'] as Map)['apiKey'], 'aside');
      } finally {
        await liveDatabase.close();
        await DataSync.cleanupTemporaryBackupFile(archive);
      }
    });

    test('归档自带数据库，不引用原文件', () async {
      final source = await writeDatabase('kelivo.db.displaced-0002', 'aside');
      final live = await writeDatabase('live.sqlite', 'current');
      final liveDatabase = AppDatabase.open(file: live);
      File? archive;
      try {
        archive = await DataSync(
          chatService: ChatService(),
          businessRepository: BusinessRepository(liveDatabase),
        ).prepareBackupFileFromDatabase(source);

        final entries = ZipDecoder()
            .decodeBytes(await archive.readAsBytes())
            .files
            .map((file) => file.name)
            .toSet();
        expect(entries, contains('database/kelivo.db'));
        expect(entries, contains('settings.json'));
        expect(entries, contains('manifest.json'));
      } finally {
        await liveDatabase.close();
        await DataSync.cleanupTemporaryBackupFile(archive);
      }
    });

    test('不修改源副本', () async {
      final source = await writeDatabase('kelivo.db.displaced-0003', 'aside');
      final before = await source.readAsBytes();
      final live = await writeDatabase('live.sqlite', 'current');
      final liveDatabase = AppDatabase.open(file: live);
      File? archive;
      try {
        archive = await DataSync(
          chatService: ChatService(),
          businessRepository: BusinessRepository(liveDatabase),
        ).prepareBackupFileFromDatabase(source);
        expect(await source.readAsBytes(), before);
      } finally {
        await liveDatabase.close();
        await DataSync.cleanupTemporaryBackupFile(archive);
      }
    });

    test('源文件不存在时明确报错', () async {
      final live = await writeDatabase('live.sqlite', 'current');
      final liveDatabase = AppDatabase.open(file: live);
      try {
        await expectLater(
          DataSync(
            chatService: ChatService(),
            businessRepository: BusinessRepository(liveDatabase),
          ).prepareBackupFileFromDatabase(File('${root.path}/missing.db')),
          throwsA(isA<FileSystemException>()),
        );
      } finally {
        await liveDatabase.close();
      }
    });
  });
}
