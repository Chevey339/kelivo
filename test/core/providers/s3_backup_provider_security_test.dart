import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/models/backup.dart';
import 'package:Kelivo/core/providers/s3_backup_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.root);

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  group('S3BackupProvider restore paths', () {
    late Directory root;
    late PathProviderPlatform previousPathProvider;
    late AppDatabase database;
    late BusinessRepository businessRepository;

    setUp(() async {
      root = await Directory.systemTemp.createTemp(
        'kelivo_s3_provider_security_',
      );
      previousPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _FakePathProviderPlatform(root.path);
      SharedPreferences.setMockInitialValues({});
      database = AppDatabase.open(file: File('${root.path}/business.sqlite'));
      businessRepository = BusinessRepository(database);
    });

    tearDown(() async {
      await database.close();
      PathProviderPlatform.instance = previousPathProvider;
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('ignores untrusted display names and cleans temp files', () async {
      final settingsFile = File('${root.path}/settings.json');
      await settingsFile.writeAsString('{}');
      final remoteBackup = File('${root.path}/remote.zip');
      final encoder = ZipFileEncoder();
      encoder.create(remoteBackup.path);
      encoder.addFileSync(settingsFile, 'settings.json');
      encoder.closeSync();
      final remoteBackupBytes = await remoteBackup.readAsBytes();

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response.statusCode = HttpStatus.ok;
        request.response.add(remoteBackupBytes);
        await request.response.close();
      });

      final chatService = ChatService();
      addTearDown(chatService.dispose);
      final relativeSentinel = File('${root.path}/s3_relative.zip');
      final absoluteSentinel = File('${root.path}/s3_absolute.zip');
      await relativeSentinel.writeAsString('keep relative');
      await absoluteSentinel.writeAsString('keep absolute');
      final remoteNames = <String>['../s3_relative.zip', absoluteSentinel.path];

      for (var i = 0; i < remoteNames.length; i++) {
        final provider = S3BackupProvider(
          chatService: chatService,
          businessRepository: businessRepository,
          businessPreferences: BusinessPreferences(businessRepository),
          initialConfig: S3Config(
            endpoint: 'http://${server.address.address}:${server.port}',
            bucket: 'backup-bucket',
            accessKeyId: 'test-access-key',
            secretAccessKey: 'test-secret-key',
            includeChats: false,
            includeFiles: false,
          ),
        );
        await provider.restoreFromItem(
          BackupFileItem(
            href: Uri.parse('s3://backup-bucket/kelivo_backups/remote_$i.zip'),
            displayName: remoteNames[i],
            size: remoteBackupBytes.length,
            lastModified: null,
          ),
        );
        provider.dispose();
      }

      expect(await relativeSentinel.readAsString(), 'keep relative');
      expect(await absoluteSentinel.readAsString(), 'keep absolute');
      expect(await Directory('${root.path}/tmp').list().toList(), isEmpty);
    });
  });
}
