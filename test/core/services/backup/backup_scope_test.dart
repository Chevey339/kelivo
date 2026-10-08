import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_data.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_restore_service.dart';
import 'package:Kelivo/core/database/business_settings_router.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/backup.dart';
import 'package:Kelivo/core/services/backup/backup_cancel_token.dart';
import 'package:Kelivo/core/services/backup/backup_task_progress.dart';
import 'package:Kelivo/core/services/backup/data_sync.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final String root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getTemporaryPath() async => '$root/tmp';
}

class _SnapshotChat extends ChatService {
  _SnapshotChat(this.file);
  final File file;

  @override
  Future<ChatDatabaseSnapshotInfo> createBackupDatabaseSnapshot(
    File destinationFile, {
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
    Duration timeout = const Duration(minutes: 10),
  }) => ChatDatabaseRepository.createConsistentSnapshot(
    sourceFile: file,
    destinationFile: destinationFile,
  );
}

class _MergingChat extends ChatService {
  _MergingChat(this.repository);
  final ChatDatabaseRepository repository;

  @override
  Future<BackupMergeReport> mergeDatabaseSnapshot(File snapshotFile) =>
      repository.mergeBackupSnapshot(snapshotFile);
}

BackupScope _only(Set<BackupCategory> categories) =>
    BackupScope(excluded: BackupCategory.values.toSet().difference(categories));

Map<String, Object?> _fixture(String prefix) => {
  'provider_configs_v1': jsonEncode({
    prefix: {'id': prefix, 'apiKey': '$prefix-provider-secret'},
  }),
  'providers_order_v1': [prefix],
  'assistants_v1': jsonEncode([
    {'id': prefix, 'name': '$prefix assistant'},
  ]),
  'mcp_servers_v1': jsonEncode([
    {'id': prefix, 'name': '$prefix MCP'},
  ]),
  'world_books_v1': jsonEncode([
    {'id': prefix, 'name': '$prefix book'},
  ]),
  'skills_v1': jsonEncode([
    {
      'id': prefix,
      'source': 'local',
      'installedAt': '2026-01-01T00:00:00Z',
      'updatedAt': '2026-01-01T00:00:00Z',
    },
  ]),
  'workspaces_v1': jsonEncode([
    {'id': prefix, 'name': prefix, 'kind': 'managed'},
  ]),
  'quick_phrases_v1': jsonEncode([
    {'id': prefix, 'content': '$prefix phrase'},
  ]),
  'instruction_injections_v1': jsonEncode([
    {'id': prefix, 'content': '$prefix prompt'},
  ]),
  'search_services_v1': jsonEncode([
    {'id': prefix, 'type': 'tavily', 'apiKey': '$prefix search'},
  ]),
  'tts_services_v1': jsonEncode([
    {'id': prefix, 'apiKey': '$prefix speech'},
  ]),
  'memory_entries_v1': jsonEncode([
    {
      'id': prefix,
      'scope': 'global',
      'type': 'identity',
      'content': '$prefix memory',
      'createdAt': 1786012880106000,
      'updatedAt': 1786012880106000,
    },
  ]),
  'environment_variables_v1': jsonEncode([
    {'name': prefix.toUpperCase(), 'value': '$prefix-env-secret'},
  ]),
  'theme_mode_v1': prefix == 'source' ? 'dark' : 'light',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late AppDatabase source;
  late AppDatabase target;
  late BusinessRepository sourceRepository;
  late BusinessRepository targetRepository;
  late DataSync exporter;
  late DataSync importer;
  late PathProviderPlatform previousPaths;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kelivo_backup_scope_');
    previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root.path);
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Kelivo',
      packageName: 'Kelivo',
      version: 'test',
      buildNumber: '1',
      buildSignature: 'test',
    );
    source = AppDatabase.open(file: File('${root.path}/source.db'));
    target = AppDatabase.open(file: File('${root.path}/kelivo.db'));
    sourceRepository = BusinessRepository(source);
    targetRepository = BusinessRepository(target);
    await BusinessRestoreService(
      sourceRepository,
    ).overwrite(_fixture('source'));
    await BusinessRestoreService(targetRepository).overwrite(_fixture('local'));
    exporter = DataSync(
      chatService: _SnapshotChat(File('${root.path}/source.db')),
      businessRepository: sourceRepository,
    );
    importer = DataSync(
      chatService: ChatService(),
      businessRepository: targetRepository,
    );
  });

  tearDown(() async {
    await source.close();
    await target.close();
    PathProviderPlatform.instance = previousPaths;
    await root.delete(recursive: true);
  });

  test(
    'all categories default on and both remote configs persist selection',
    () {
      expect(const WebDavConfig().scope.excluded, isEmpty);
      expect(const S3Config().scope.excluded, isEmpty);
      final scope = _only({
        BackupCategory.mcp,
        BackupCategory.environmentVariables,
      });
      expect(
        WebDavConfig.fromJsonString(
          WebDavConfig(scope: scope).toJsonString(),
        ).scope.excluded,
        scope.excluded,
      );
      expect(
        S3Config.fromJsonString(
          S3Config(scope: scope).toJsonString(),
        ).scope.excluded,
        scope.excluded,
      );
    },
  );

  const keys = {
    BackupCategory.assistants: 'assistants_v1',
    BackupCategory.providers: 'provider_configs_v1',
    BackupCategory.mcp: 'mcp_servers_v1',
    BackupCategory.environmentVariables: 'environment_variables_v1',
    BackupCategory.skills: 'skills_v1',
    BackupCategory.worldBooks: 'world_books_v1',
    BackupCategory.memories: 'memory_entries_v1',
    BackupCategory.quickPhrases: 'quick_phrases_v1',
    BackupCategory.instructions: 'instruction_injections_v1',
    BackupCategory.workspaces: 'workspaces_v1',
    BackupCategory.searchServices: 'search_services_v1',
    BackupCategory.speechServices: 'tts_services_v1',
    BackupCategory.settings: 'theme_mode_v1',
  };

  for (final category in keys.keys) {
    for (final filterExport in [false, true]) {
      test(
        '${category.name}: ${filterExport ? 'partial archive' : 'selected import'} preserves other categories',
        () async {
          final selected = _only({category});
          final backup = await exporter.prepareBackupFile(
            WebDavConfig(
              scope: filterExport
                  ? selected
                  : const BackupScope(excluded: {BackupCategory.chats}),
            ),
          );
          final archive = ZipDecoder().decodeBytes(await backup.readAsBytes());
          final exported =
              jsonDecode(
                    utf8.decode(
                      archive.findFile('settings.json')!.readBytes()!,
                    ),
                  )
                  as Map;
          if (filterExport) {
            for (final entry in keys.entries) {
              expect(
                exported.containsKey(entry.value),
                entry.key == category,
                reason: entry.key.name,
              );
            }
            expect(archive.findFile('database/kelivo.db'), isNull);
          }
          final before = await BusinessRestoreService(
            targetRepository,
          ).exportSettings();
          final incoming = await BusinessRestoreService(
            sourceRepository,
          ).exportSettings();
          await importer.restoreFromLocalFile(
            backup,
            WebDavConfig(scope: filterExport ? const BackupScope() : selected),
          );
          final after = await BusinessRestoreService(
            targetRepository,
          ).exportSettings();
          for (final entry in keys.entries) {
            expect(
              after[entry.value],
              entry.key == category
                  ? incoming[entry.value]
                  : before[entry.value],
              reason: entry.key.name,
            );
          }
        },
      );
    }
  }

  for (final category in [
    BackupCategory.files,
    BackupCategory.skills,
    BackupCategory.workspaces,
    BackupCategory.providers,
  ]) {
    test('${category.name} exports only its own file roots', () async {
      const roots = [
        'upload',
        'images',
        'avatars',
        'fonts',
        'sessions',
        'skills',
        'workspaces',
      ];
      for (final name in roots) {
        final file = File('${root.path}/$name/example.txt');
        await file.parent.create(recursive: true);
        await file.writeAsString(name);
      }
      final backup = await exporter.prepareBackupFile(
        WebDavConfig(scope: _only({category})),
      );
      final archive = ZipDecoder().decodeBytes(await backup.readAsBytes());
      final expectedRoots = switch (category) {
        BackupCategory.files => {
          'upload',
          'images',
          'avatars',
          'fonts',
          'sessions',
        },
        BackupCategory.skills => {'skills'},
        BackupCategory.workspaces => {'workspaces'},
        _ => <String>{},
      };
      for (final name in roots) {
        expect(
          archive.findFile('$name/example.txt') != null,
          expectedRoots.contains(name),
          reason: name,
        );
      }
    });
  }

  test(
    'merging chats does not import disabled skill and workspace rows from SQLite',
    () async {
      final backup = await exporter.prepareBackupFile(const WebDavConfig());
      final chatRepository = ChatDatabaseRepository.open(
        file: File('${root.path}/kelivo.db'),
      );
      try {
        await chatRepository.ensureReady();
        await DataSync(
          chatService: _MergingChat(chatRepository),
          businessRepository: targetRepository,
        ).restoreFromLocalFile(
          backup,
          WebDavConfig(
            scope: _only({BackupCategory.chats, BackupCategory.files}),
          ),
          mode: RestoreMode.merge,
        );
        for (final kind in [
          BusinessEntityKind.skill,
          BusinessEntityKind.workspace,
        ]) {
          expect(
            (await targetRepository.readEntities(kind)).map((row) => row.id),
            ['local'],
          );
        }
      } finally {
        await chatRepository.close();
      }
    },
  );

  test(
    'incomplete archive scope is rejected before changing local data',
    () async {
      final backup = await exporter.prepareBackupFile(
        WebDavConfig(scope: _only({BackupCategory.providers})),
      );
      final archive = ZipDecoder().decodeBytes(await backup.readAsBytes());
      final manifest =
          jsonDecode(
                utf8.decode(archive.findFile('manifest.json')!.readBytes()!),
              )
              as Map<String, dynamic>;
      manifest['scope'] = {'providers': true};
      final malformed = Archive();
      for (final entry in archive.files) {
        if (entry.name != 'manifest.json') malformed.add(entry);
      }
      malformed.add(ArchiveFile.string('manifest.json', jsonEncode(manifest)));
      final file = File('${root.path}/incomplete-scope.zip');
      await file.writeAsBytes(ZipEncoder().encodeBytes(malformed));
      final before = await BusinessRestoreService(
        targetRepository,
      ).exportSettings();
      await expectLater(
        importer.restoreFromLocalFile(file, const WebDavConfig()),
        throwsFormatException,
      );
      expect(
        await BusinessRestoreService(targetRepository).exportSettings(),
        before,
      );
    },
  );

  test(
    'an older archive without environment variables preserves local variables',
    () async {
      final archive = Archive()
        ..add(
          ArchiveFile.string(
            'settings.json',
            jsonEncode({'theme_mode_v1': 'dark'}),
          ),
        );
      final file = File('${root.path}/older-backup.zip');
      await file.writeAsBytes(ZipEncoder().encodeBytes(archive));
      final before = await targetRepository.getPreference(
        'environment_variables_v1',
      );
      await importer.restoreFromLocalFile(file, const WebDavConfig());
      expect(
        await targetRepository.getPreference('environment_variables_v1'),
        before,
      );
    },
  );

  test('all switches off leaves existing data untouched', () async {
    final backup = await exporter.prepareBackupFile(const WebDavConfig());
    final before = await BusinessRestoreService(
      targetRepository,
    ).exportSettings();
    await importer.restoreFromLocalFile(backup, WebDavConfig(scope: _only({})));
    expect(
      await BusinessRestoreService(targetRepository).exportSettings(),
      before,
    );
    expect(await Directory('${root.path}/.kelivo_restore').exists(), isFalse);
  });

  test('environment merge keeps existing values and adds new names', () async {
    await targetRepository.setPreference(
      'environment_variables_v1',
      jsonEncode([
        {'name': 'SOURCE', 'value': 'keep-local'},
        {'name': 'LOCAL', 'value': 'local-only'},
      ]),
    );
    await sourceRepository.setPreference(
      'environment_variables_v1',
      jsonEncode([
        {'name': 'SOURCE', 'value': 'replace-me'},
        {'name': 'NEW', 'value': 'new-value'},
      ]),
    );
    final backup = await exporter.prepareBackupFile(
      WebDavConfig(scope: _only({BackupCategory.environmentVariables})),
    );
    await importer.restoreFromLocalFile(
      backup,
      const WebDavConfig(),
      mode: RestoreMode.merge,
    );
    final variables =
        jsonDecode(
              (await targetRepository.getPreference('environment_variables_v1'))
                  as String,
            )
            as List;
    expect(
      {for (final value in variables) value['name']: value['value']},
      {'SOURCE': 'keep-local', 'LOCAL': 'local-only', 'NEW': 'new-value'},
    );
  });

  test('skills carry their directory with files disabled', () async {
    final skill = File('${root.path}/skills/source/SKILL.md');
    await skill.parent.create(recursive: true);
    await skill.writeAsString('skill-content');
    final attachment = File('${root.path}/upload/local.txt');
    await attachment.parent.create(recursive: true);
    await attachment.writeAsString('keep-attachment');
    final backup = await exporter.prepareBackupFile(
      WebDavConfig(scope: _only({BackupCategory.skills})),
    );
    final archive = ZipDecoder().decodeBytes(await backup.readAsBytes());
    expect(archive.findFile('skills/source/SKILL.md'), isNotNull);
    expect(archive.findFile('upload/local.txt'), isNull);
    await skill.writeAsString('outdated-skill');
    await importer.restoreFromLocalFile(backup, const WebDavConfig());
    expect(await skill.readAsString(), 'skill-content');
    expect(await attachment.readAsString(), 'keep-attachment');
  });

  test(
    'chat archive removes unselected settings from raw SQLite as well as JSON',
    () async {
      final backup = await exporter.prepareBackupFile(
        WebDavConfig(scope: _only({BackupCategory.chats})),
      );
      final archive = ZipDecoder().decodeBytes(await backup.readAsBytes());
      final databaseBytes = archive
          .findFile('database/kelivo.db')!
          .readBytes()!;
      final file = File('${root.path}/inspection.db');
      await file.writeAsBytes(databaseBytes);
      final inspection = AppDatabase.open(file: file);
      try {
        final snapshot = await BusinessRepository(inspection).readSnapshot();
        expect(snapshot.preferences, isEmpty);
        for (final kind in BusinessEntityKind.values) {
          expect(snapshot.entities[kind], isEmpty, reason: kind.name);
        }
        expect(
          latin1.decode(databaseBytes),
          isNot(contains('source-provider-secret')),
        );
        expect(
          latin1.decode(databaseBytes),
          isNot(contains('source-env-secret')),
        );
      } finally {
        await inspection.close();
      }
    },
  );

  test(
    'staged chat and skill overwrite retains unselected business and files',
    () async {
      final skill = File('${root.path}/skills/source/SKILL.md');
      await skill.parent.create(recursive: true);
      await skill.writeAsString('backup-skill');
      final backup = await exporter.prepareBackupFile(const WebDavConfig());
      await skill.writeAsString('old-skill');
      final upload = File('${root.path}/upload/keep.txt');
      await upload.parent.create(recursive: true);
      await upload.writeAsString('local-attachment');
      final scope = _only({BackupCategory.chats, BackupCategory.skills});
      final preferences = BusinessPreferences(targetRepository);
      await preferences.load();
      final queuedWrite = preferences.setString('theme_mode_v1', 'system');
      Future<Object?>? blockedWrite;
      await DataSync(
        chatService: ChatService(),
        businessRepository: targetRepository,
        businessPreferences: preferences,
      ).restoreFromLocalFile(
        backup,
        WebDavConfig(scope: scope),
        onProgress: (progress) {
          if (progress.phase == BackupPhase.stagingCandidate) {
            blockedWrite ??= preferences
                .setString('theme_mode_v1', 'dark')
                .then<Object?>((_) => null, onError: (Object error) => error);
          }
        },
      );
      await queuedWrite;
      expect(await blockedWrite, isA<StateError>());
      await expectLater(
        preferences.setString('theme_mode_v1', 'light'),
        throwsStateError,
      );
      final workspace = Directory('${root.path}/.kelivo_restore');
      final candidate =
          (await workspace
                  .list(recursive: true)
                  .where((e) => e is Directory && e.path.endsWith('/candidate'))
                  .toList())
              .single;
      expect(await Directory('${candidate.path}/upload').exists(), isFalse);
      expect(
        await File('${candidate.path}/skills/source/SKILL.md').readAsString(),
        'backup-skill',
      );
      final inspectionFile = await File(
        '${candidate.path}/database/kelivo.db',
      ).copy('${root.path}/inspection.db');
      final inspection = AppDatabase.open(file: inspectionFile);
      try {
        final settings = BusinessSettingsRouter.exportSnapshot(
          await BusinessRepository(inspection).readSnapshot(),
        );
        final before = await BusinessRestoreService(
          targetRepository,
        ).exportSettings();
        for (final entry in keys.entries) {
          if (entry.key != BackupCategory.skills) {
            expect(
              settings[entry.value],
              before[entry.value],
              reason: entry.key.name,
            );
          }
        }
        expect(
          jsonDecode(settings['skills_v1'] as String).single['id'],
          'source',
        );
      } finally {
        await inspection.close();
      }
      expect(await skill.readAsString(), 'old-skill');
      expect(await upload.readAsString(), 'local-attachment');
    },
  );

  test('cancelled staging releases the business write fence', () async {
    final backup = await exporter.prepareBackupFile(const WebDavConfig());
    final preferences = BusinessPreferences(targetRepository);
    await preferences.load();
    final token = BackupCancelToken();
    await expectLater(
      DataSync(
        chatService: ChatService(),
        businessRepository: targetRepository,
        businessPreferences: preferences,
      ).restoreFromLocalFile(
        backup,
        WebDavConfig(scope: _only({BackupCategory.chats})),
        cancelToken: token,
        onProgress: (progress) {
          if (progress.phase == BackupPhase.stagingCandidate) token.cancel();
        },
      ),
      throwsA(isA<BackupCancelledException>()),
    );
    await preferences.setString('theme_mode_v1', 'system');
    expect(await targetRepository.getPreference('theme_mode_v1'), 'system');
  });
}
