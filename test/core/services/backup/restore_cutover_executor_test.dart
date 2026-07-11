import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/services/backup/restore_bundle_preparation.dart';
import 'package:Kelivo/core/services/backup/restore_cutover_executor.dart';
import 'package:Kelivo/core/services/backup/restore_previous_store.dart';
import 'package:Kelivo/core/services/backup/restore_receipt.dart';
import 'package:Kelivo/core/services/backup/restore_startup_gate.dart';
import 'package:Kelivo/core/services/backup/restore_workspace_lock.dart';

import 'restore_cold_process_test_helper.dart';

final class _FailingNthSetPreferencesStore
    extends InMemorySharedPreferencesStore {
  _FailingNthSetPreferencesStore(super.data, {required this.failOnCall})
    : super.withData();

  final int failOnCall;
  var _setCalls = 0;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    _setCalls++;
    if (_setCalls == failOnCall) return false;
    return super.setValue(valueType, key, value);
  }
}

final class _FailingSetCallsPreferencesStore
    extends InMemorySharedPreferencesStore {
  _FailingSetCallsPreferencesStore(super.data, {required this.failOnCalls})
    : super.withData();

  final Set<int> failOnCalls;
  var _setCalls = 0;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    _setCalls++;
    if (failOnCalls.contains(_setCalls)) return false;
    return super.setValue(valueType, key, value);
  }
}

enum _TerminalTamperTarget { database, asset }

extension on _TerminalTamperTarget {
  String get label => switch (this) {
    _TerminalTamperTarget.database => 'database',
    _TerminalTamperTarget.asset => 'asset',
  };

  String get expectedError => switch (this) {
    _TerminalTamperTarget.database => 'restore_mover_file_descriptor',
    _TerminalTamperTarget.asset => 'restore_mover_asset_descriptor:upload',
  };
}

final class _CompleteBundleFixture {
  const _CompleteBundleFixture({
    required this.prepared,
    required this.liveDatabase,
    required this.oldUpload,
    required this.liveNewUpload,
  });

  final PreparedRestoreBundle prepared;
  final File liveDatabase;
  final File oldUpload;
  final File liveNewUpload;
}

typedef _CutoverCase = ({
  String label,
  int? failOnSetCall,
  RestoreReceiptState expectedState,
});

const List<_CutoverCase> _cutoverCases = [
  (
    label: 'committed',
    failOnSetCall: null,
    expectedState: RestoreReceiptState.committed,
  ),
  (
    label: 'rolled back after verified validation fails',
    failOnSetCall: 3,
    expectedState: RestoreReceiptState.rolledBack,
  ),
];

const _databaseFamilyFileNames = [
  'kelivo.sqlite',
  'kelivo.sqlite-wal',
  'kelivo.sqlite-shm',
  'kelivo.sqlite-journal',
];
const _assetRootNames = ['upload', 'images', 'avatars', 'fonts'];

final class _SelectedDatabaseFixture {
  const _SelectedDatabaseFixture({
    required this.prepared,
    required this.candidateDescriptor,
  });

  final PreparedRestoreBundle prepared;
  final Map<String, dynamic> candidateDescriptor;
}

final class _SettingsOnlyFixture {
  const _SettingsOnlyFixture({
    required this.prepared,
    required this.livePayloadSnapshot,
  });

  final PreparedRestoreBundle prepared;
  final Map<String, Object?> livePayloadSnapshot;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RestoreCutoverExecutor', () {
    late Directory root;
    late Directory appData;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'theme': 'old'});
      root = await Directory.systemTemp.createTemp(
        'kelivo_restore_cutover_test_',
      );
      appData = Directory(p.join(root.path, 'app_data'));
      await appData.create();
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    for (final cutoverCase in _cutoverCases) {
      test('selected database with a missing live database family is '
          '${cutoverCase.label}', () async {
        final fixture = await _prepareSelectedDatabaseBundle(
          root: root,
          appData: appData,
          directoryName: 'missing_database_${cutoverCase.expectedState.name}',
        );
        final missingDatabaseFamily = {
          for (final name in _databaseFamilyFileNames) name: null,
        };
        expect(await _databaseFamilySnapshot(appData), missingDatabaseFamily);
        if (cutoverCase.failOnSetCall case final failOnSetCall?) {
          SharedPreferencesStorePlatform.instance =
              _FailingNthSetPreferencesStore({
                'flutter.theme': 'old',
              }, failOnCall: failOnSetCall);
        }
        final preferences = await SharedPreferences.getInstance();

        final result = await _recoverAfterColdRestart(
          appDataDirectory: appData,
          preferences: preferences,
        );

        expect(result?.state, cutoverCase.expectedState);
        final receiptStore = RestoreReceiptStore(
          appDataDirectory: appData,
          runId: fixture.prepared.runId,
          archived: true,
        );
        expect(
          (await receiptStore.readHistory()).map((receipt) => receipt.state),
          cutoverCase.expectedState == RestoreReceiptState.committed
              ? [
                  RestoreReceiptState.prepared,
                  RestoreReceiptState.oldRenamed,
                  RestoreReceiptState.newInstalled,
                  RestoreReceiptState.verified,
                  RestoreReceiptState.committed,
                ]
              : [
                  RestoreReceiptState.prepared,
                  RestoreReceiptState.oldRenamed,
                  RestoreReceiptState.newInstalled,
                  RestoreReceiptState.verified,
                  RestoreReceiptState.rollingBack,
                  RestoreReceiptState.rolledBack,
                ],
        );
        final previousDirectory = _previousDirectory(receiptStore);
        expect(await _topLevelNames(previousDirectory), [
          RestorePreviousStore.manifestFileName,
          RestorePreviousStore.settingsFileName,
        ]);
        final previousManifest = await _previousManifest(previousDirectory);
        expect(previousManifest['database'], {
          'state': 'missing',
          'path': 'database/kelivo.sqlite',
          'descriptor': null,
        });
        expect(previousManifest['assets'], isNull);
        final archivedCandidateDatabase = File(
          p.join(
            receiptStore.runDirectory.path,
            'candidate',
            'database',
            'kelivo.sqlite',
          ),
        );

        if (cutoverCase.expectedState == RestoreReceiptState.committed) {
          expect(await _databaseFamilySnapshot(appData), {
            'kelivo.sqlite': fixture.candidateDescriptor,
            for (final name in _databaseFamilyFileNames.skip(1)) name: null,
          });
          expect(await archivedCandidateDatabase.exists(), isFalse);
          expect(
            await _conversationIds(File(p.join(appData.path, 'kelivo.sqlite'))),
            ['new'],
          );
        } else {
          expect(await _databaseFamilySnapshot(appData), missingDatabaseFamily);
          expect(
            await _descriptor(archivedCandidateDatabase),
            fixture.candidateDescriptor,
          );
          expect(await _conversationIds(archivedCandidateDatabase), ['new']);
          expect(await _topLevelNames(archivedCandidateDatabase.parent), [
            'kelivo.sqlite',
          ]);
        }
      });
    }

    for (final cutoverCase in _cutoverCases) {
      test(
        'settings-only restore keeps unselected live payload byte-exact when '
        '${cutoverCase.label}',
        () async {
          final fixture = await _prepareSettingsOnlyBundle(
            root: root,
            appData: appData,
            directoryName: 'settings_only_${cutoverCase.expectedState.name}',
          );
          if (cutoverCase.failOnSetCall case final failOnSetCall?) {
            SharedPreferencesStorePlatform.instance =
                _FailingNthSetPreferencesStore({
                  'flutter.theme': 'old',
                }, failOnCall: failOnSetCall);
          }
          final preferences = await SharedPreferences.getInstance();

          final result = await _recoverAfterColdRestart(
            appDataDirectory: appData,
            preferences: preferences,
          );

          expect(result?.state, cutoverCase.expectedState);
          expect(
            await _livePayloadSnapshot(appData),
            fixture.livePayloadSnapshot,
          );
          final receiptStore = RestoreReceiptStore(
            appDataDirectory: appData,
            runId: fixture.prepared.runId,
            archived: true,
          );
          final previousDirectory = _previousDirectory(receiptStore);
          expect(await _topLevelNames(previousDirectory), [
            RestorePreviousStore.manifestFileName,
            RestorePreviousStore.settingsFileName,
          ]);
          final previousManifest = await _previousManifest(previousDirectory);
          expect(previousManifest['database'], isNull);
          expect(previousManifest['assets'], isNull);
        },
      );
    }

    test('commits a complete SQLite, settings, and assets bundle', () async {
      final fixture = await _prepareCompleteBundle(
        root: root,
        appData: appData,
        directoryName: 'extracted',
      );
      final preferences = await SharedPreferences.getInstance();

      await _recoverAfterColdRestart(
        appDataDirectory: appData,
        preferences: preferences,
      );

      await preferences.reload();
      expect(preferences.getString('theme'), 'new');
      expect(await _conversationIds(fixture.liveDatabase), ['new']);
      expect(await fixture.oldUpload.exists(), isFalse);
      expect(await fixture.liveNewUpload.readAsString(), 'new asset');
      for (final assetRoot in const ['upload', 'images', 'avatars', 'fonts']) {
        expect(
          await Directory(p.join(appData.path, assetRoot)).exists(),
          isTrue,
        );
      }

      final receiptStore = RestoreReceiptStore(
        appDataDirectory: appData,
        runId: fixture.prepared.runId,
        archived: true,
      );
      final previousDirectory = Directory(
        p.join(
          receiptStore.runDirectory.path,
          RestorePreviousStore.previousDirectoryName,
        ),
      );
      final previousDatabase = File(
        p.join(previousDirectory.path, 'database', 'kelivo.sqlite'),
      );
      expect(await _conversationIds(previousDatabase), ['old']);
      expect(
        await File(
          p.join(previousDirectory.path, 'upload', 'old.txt'),
        ).readAsString(),
        'old asset',
      );
      expect(
        (await receiptStore.readHistory()).map((receipt) => receipt.state),
        [
          RestoreReceiptState.prepared,
          RestoreReceiptState.oldRenamed,
          RestoreReceiptState.newInstalled,
          RestoreReceiptState.verified,
          RestoreReceiptState.committed,
        ],
      );
    });

    for (final tamperTarget in _TerminalTamperTarget.values) {
      test(
        'keeps a committed complete bundle active when the live '
        '${tamperTarget.label} diverges before cold acknowledgement',
        () async {
          final fixture = await _prepareCompleteBundle(
            root: root,
            appData: appData,
            directoryName: 'terminal_${tamperTarget.label}',
          );
          final preferences = await SharedPreferences.getInstance();

          await expectLater(
            RestoreStartupGate.recoverAndRequireBusinessReady(
              appDataDirectory: appData,
              preferences: preferences,
            ),
            throwsA(isA<RestoreColdRestartRequired>()),
          );
          await simulateRestoreColdProcessBoundary(appData);

          final pendingBeforeTamper = await RestoreStartupGate.inspect(
            appDataDirectory: appData,
          );
          expect(
            pendingBeforeTamper?.receipt.state,
            RestoreReceiptState.committed,
          );
          expect(
            pendingBeforeTamper?.markerFileName,
            RestoreWorkspaceLock.publishingRunFileName,
          );
          final activeReceiptStore = RestoreReceiptStore(
            appDataDirectory: appData,
            runId: fixture.prepared.runId,
            archived: false,
          );
          expect(
            (await activeReceiptStore.readHistory()).last.state,
            RestoreReceiptState.committed,
          );
          await preferences.reload();
          expect(preferences.getString('theme'), 'new');

          switch (tamperTarget) {
            case _TerminalTamperTarget.database:
              _tamperDatabase(fixture.liveDatabase);
              break;
            case _TerminalTamperTarget.asset:
              await fixture.liveNewUpload.writeAsString(
                'tampered asset',
                flush: true,
              );
              break;
          }

          await expectLater(
            RestoreStartupGate.recoverAndRequireBusinessReady(
              appDataDirectory: appData,
              preferences: preferences,
            ),
            throwsA(
              isA<StateError>().having(
                (error) => error.message,
                'message',
                tamperTarget.expectedError,
              ),
            ),
          );

          final pendingAfterFailure = await RestoreStartupGate.inspect(
            appDataDirectory: appData,
          );
          expect(
            pendingAfterFailure?.receipt.state,
            RestoreReceiptState.committed,
          );
          expect(
            pendingAfterFailure?.markerFileName,
            RestoreWorkspaceLock.publishingRunFileName,
          );
          expect(
            (await activeReceiptStore.readHistory()).last.state,
            RestoreReceiptState.committed,
          );
          await preferences.reload();
          expect(preferences.getString('theme'), 'new');
          expect(
            await RestoreReceiptStore(
              appDataDirectory: appData,
              runId: fixture.prepared.runId,
              archived: true,
            ).runDirectory.exists(),
            isFalse,
          );
          expect(await fixture.oldUpload.exists(), isFalse);
          expect(await _conversationIds(fixture.liveDatabase), ['new']);
          expect(
            await fixture.liveNewUpload.readAsString(),
            tamperTarget == _TerminalTamperTarget.asset
                ? 'tampered asset'
                : 'new asset',
          );

          final previousDirectory = Directory(
            p.join(
              activeReceiptStore.runDirectory.path,
              RestorePreviousStore.previousDirectoryName,
            ),
          );
          expect(
            await _conversationIds(
              File(p.join(previousDirectory.path, 'database', 'kelivo.sqlite')),
            ),
            ['old'],
          );
          expect(
            await File(
              p.join(previousDirectory.path, 'upload', 'old.txt'),
            ).readAsString(),
            'old asset',
          );
        },
      );
    }

    test(
      'rolls back a fully installed bundle when verification fails',
      () async {
        final fixture = await _prepareCompleteBundle(
          root: root,
          appData: appData,
          directoryName: 'rollback_extracted',
        );
        SharedPreferencesStorePlatform.instance =
            _FailingNthSetPreferencesStore({
              'flutter.theme': 'old',
            }, failOnCall: 2);
        final preferences = await SharedPreferences.getInstance();

        final result = await _recoverAfterColdRestart(
          appDataDirectory: appData,
          preferences: preferences,
        );

        expect(result?.state, RestoreReceiptState.rolledBack);
        await preferences.reload();
        expect(preferences.getString('theme'), 'old');
        expect(await _conversationIds(fixture.liveDatabase), ['old']);
        expect(await fixture.oldUpload.readAsString(), 'old asset');
        expect(await fixture.liveNewUpload.exists(), isFalse);

        final receiptStore = RestoreReceiptStore(
          appDataDirectory: appData,
          runId: fixture.prepared.runId,
          archived: true,
        );
        final candidateDirectory = Directory(
          p.join(receiptStore.runDirectory.path, 'candidate'),
        );
        expect(
          await _conversationIds(
            File(p.join(candidateDirectory.path, 'database', 'kelivo.sqlite')),
          ),
          ['new'],
        );
        expect(
          await File(
            p.join(candidateDirectory.path, 'upload', 'new.txt'),
          ).readAsString(),
          'new asset',
        );
        expect(
          (await receiptStore.readHistory()).map((receipt) => receipt.state),
          [
            RestoreReceiptState.prepared,
            RestoreReceiptState.oldRenamed,
            RestoreReceiptState.newInstalled,
            RestoreReceiptState.rollingBack,
            RestoreReceiptState.rolledBack,
          ],
        );
        final previousDirectory = Directory(
          p.join(
            receiptStore.runDirectory.path,
            RestorePreviousStore.previousDirectoryName,
          ),
        );
        expect(
          (await previousDirectory
                .list(followLinks: false)
                .map((entity) => p.basename(entity.path))
                .toList()
            ..sort()),
          [
            RestorePreviousStore.manifestFileName,
            RestorePreviousStore.settingsFileName,
          ],
        );
      },
    );

    test(
      'preserves cutover and rollback failures while keeping rollingBack',
      () async {
        final fixture = await _prepareCompleteBundle(
          root: root,
          appData: appData,
          directoryName: 'rollback_failure_extracted',
        );
        SharedPreferencesStorePlatform.instance =
            _FailingSetCallsPreferencesStore(
              {'flutter.theme': 'old'},
              failOnCalls: {2, 3},
            );
        final preferences = await SharedPreferences.getInstance();

        Object? failure;
        StackTrace? failureStackTrace;
        try {
          await RestoreStartupGate.recoverAndRequireBusinessReady(
            appDataDirectory: appData,
            preferences: preferences,
          );
        } catch (error, stackTrace) {
          failure = error;
          failureStackTrace = stackTrace;
        }

        expect(failure, isA<RestoreCutoverRollbackException>());
        final combined = failure! as RestoreCutoverRollbackException;
        expect(combined.cutoverError, isA<StateError>());
        expect(combined.cutoverStackTrace, isA<StackTrace>());
        expect(combined.rollbackError, isA<StateError>());
        expect(combined.rollbackStackTrace, isA<StackTrace>());
        expect(
          failureStackTrace.toString(),
          combined.rollbackStackTrace.toString(),
        );
        expect(combined.toString(), isNot(contains('theme')));

        final receiptStore = RestoreReceiptStore(
          appDataDirectory: appData,
          runId: fixture.prepared.runId,
        );
        expect(
          (await receiptStore.readHistory()).last.state,
          RestoreReceiptState.rollingBack,
        );
      },
    );
  });
}

Future<_SelectedDatabaseFixture> _prepareSelectedDatabaseBundle({
  required Directory root,
  required Directory appData,
  required String directoryName,
}) async {
  final extracted = Directory(p.join(root.path, directoryName));
  await extracted.create();
  final settings = File(p.join(extracted.path, 'settings.json'));
  await settings.writeAsString('{"theme":"new"}', flush: true);
  final sourceDatabase = File(
    p.join(extracted.path, 'database', 'kelivo.sqlite'),
  );
  await sourceDatabase.parent.create(recursive: true);
  await _createDatabase(sourceDatabase, conversationId: 'new');
  final databaseInfo = await ChatDatabaseRepository.prepareSnapshotForRestore(
    sourceDatabase,
  );
  final manifest = File(p.join(extracted.path, 'manifest.json'));
  await manifest.writeAsString(
    jsonEncode({
      'format': 'kelivo-backup',
      'formatVersion': 2,
      'payloadKind': 'sqlite',
      'createdAtUtc': '2026-07-09T00:00:00.000Z',
      'appVersion': 'test',
      'includeChats': true,
      'includeFiles': false,
      'secretsIncluded': true,
      'database': {
        'entry': 'database/kelivo.sqlite',
        'schemaVersion': databaseInfo.schemaVersion,
        'conversationCount': databaseInfo.conversationCount,
        'messageCount': databaseInfo.messageCount,
      },
      'entries': {
        'settings.json': await _descriptor(settings),
        'database/kelivo.sqlite': await _descriptor(sourceDatabase),
      },
    }),
    flush: true,
  );
  final prepared = await RestoreBundlePreparation.prepare(
    appDataDirectory: appData,
    extractedDirectory: extracted,
    sourceManifestSha256: (await sha256.bind(manifest.openRead()).first)
        .toString(),
    bundleIncludesChats: true,
    bundleIncludesFiles: false,
    restoreChats: true,
    restoreFiles: false,
    createdAtUtc: DateTime.utc(2026, 7, 9, 12),
  );
  final candidateDatabase = File(
    p.join(prepared.candidateDirectory.path, 'database', 'kelivo.sqlite'),
  );
  return _SelectedDatabaseFixture(
    prepared: prepared,
    candidateDescriptor: await _descriptor(candidateDatabase),
  );
}

Future<_SettingsOnlyFixture> _prepareSettingsOnlyBundle({
  required Directory root,
  required Directory appData,
  required String directoryName,
}) async {
  await _createDatabase(
    File(p.join(appData.path, 'kelivo.sqlite')),
    conversationId: 'old',
  );
  await File(
    p.join(appData.path, 'kelivo.sqlite-wal'),
  ).writeAsBytes([0x77, 0x61, 0x6c], flush: true);
  await File(
    p.join(appData.path, 'kelivo.sqlite-shm'),
  ).writeAsBytes([0x73, 0x68, 0x6d], flush: true);
  await File(
    p.join(appData.path, 'kelivo.sqlite-journal'),
  ).writeAsBytes([0x6a, 0x6f, 0x75, 0x72, 0x6e, 0x61, 0x6c], flush: true);
  final upload = File(p.join(appData.path, 'upload', 'nested', 'note.bin'));
  await upload.parent.create(recursive: true);
  await upload.writeAsBytes([0, 1, 2, 255], flush: true);
  await Directory(p.join(appData.path, 'images')).create();
  final avatar = File(p.join(appData.path, 'avatars', 'avatar.txt'));
  await avatar.parent.create();
  await avatar.writeAsString('old avatar', flush: true);
  await Directory(p.join(appData.path, 'fonts')).create();
  final livePayloadSnapshot = await _livePayloadSnapshot(appData);

  final extracted = Directory(p.join(root.path, directoryName));
  await extracted.create();
  final settings = File(p.join(extracted.path, 'settings.json'));
  await settings.writeAsString('{"theme":"new"}', flush: true);
  final manifest = File(p.join(extracted.path, 'manifest.json'));
  await manifest.writeAsString(
    jsonEncode({
      'format': 'kelivo-backup',
      'formatVersion': 2,
      'payloadKind': 'settings-only',
      'createdAtUtc': '2026-07-09T00:00:00.000Z',
      'appVersion': 'test',
      'includeChats': false,
      'includeFiles': false,
      'secretsIncluded': true,
      'entries': {'settings.json': await _descriptor(settings)},
    }),
    flush: true,
  );
  final prepared = await RestoreBundlePreparation.prepare(
    appDataDirectory: appData,
    extractedDirectory: extracted,
    sourceManifestSha256: (await sha256.bind(manifest.openRead()).first)
        .toString(),
    bundleIncludesChats: false,
    bundleIncludesFiles: false,
    restoreChats: false,
    restoreFiles: false,
    createdAtUtc: DateTime.utc(2026, 7, 9, 12),
  );
  return _SettingsOnlyFixture(
    prepared: prepared,
    livePayloadSnapshot: livePayloadSnapshot,
  );
}

Directory _previousDirectory(RestoreReceiptStore receiptStore) => Directory(
  p.join(
    receiptStore.runDirectory.path,
    RestorePreviousStore.previousDirectoryName,
  ),
);

Future<Map<String, dynamic>> _previousManifest(Directory directory) async =>
    (jsonDecode(
              await File(
                p.join(directory.path, RestorePreviousStore.manifestFileName),
              ).readAsString(),
            )
            as Map)
        .cast<String, dynamic>();

Future<List<String>> _topLevelNames(Directory directory) async =>
    (await directory
          .list(followLinks: false)
          .map((entity) => p.basename(entity.path))
          .toList()
      ..sort());

Future<Map<String, Object?>> _databaseFamilySnapshot(Directory root) async {
  final snapshot = <String, Object?>{};
  for (final name in _databaseFamilyFileNames) {
    final path = p.join(root.path, name);
    final type = await FileSystemEntity.type(path, followLinks: false);
    snapshot[name] = switch (type) {
      FileSystemEntityType.notFound => null,
      FileSystemEntityType.file => await _descriptor(File(path)),
      _ => type.toString(),
    };
  }
  return snapshot;
}

Future<Map<String, Object?>> _livePayloadSnapshot(Directory root) async {
  final snapshot = <String, Object?>{
    for (final entry in (await _databaseFamilySnapshot(root)).entries)
      entry.key: entry.value,
  };
  for (final rootName in _assetRootNames) {
    final assetRoot = Directory(p.join(root.path, rootName));
    final rootType = await FileSystemEntity.type(
      assetRoot.path,
      followLinks: false,
    );
    snapshot['$rootName/'] = rootType.toString();
    if (rootType != FileSystemEntityType.directory) continue;
    final entities =
        await assetRoot.list(recursive: true, followLinks: false).toList()
          ..sort((left, right) => left.path.compareTo(right.path));
    for (final entity in entities) {
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      final relative = p
          .relative(entity.path, from: root.path)
          .replaceAll(p.separator, '/');
      snapshot[type == FileSystemEntityType.directory
          ? '$relative/'
          : relative] = switch (type) {
        FileSystemEntityType.file => await _descriptor(File(entity.path)),
        _ => type.toString(),
      };
    }
  }
  return snapshot;
}

Future<_CompleteBundleFixture> _prepareCompleteBundle({
  required Directory root,
  required Directory appData,
  required String directoryName,
}) async {
  final liveDatabase = File(p.join(appData.path, 'kelivo.sqlite'));
  await _createDatabase(liveDatabase, conversationId: 'old');
  final oldUpload = File(p.join(appData.path, 'upload', 'old.txt'));
  await oldUpload.parent.create();
  await oldUpload.writeAsString('old asset', flush: true);
  await Directory(p.join(appData.path, 'images')).create();

  final extracted = Directory(p.join(root.path, directoryName));
  await extracted.create();
  final settings = File(p.join(extracted.path, 'settings.json'));
  await settings.writeAsString('{"theme":"new"}', flush: true);
  final candidateDatabase = File(
    p.join(extracted.path, 'database', 'kelivo.sqlite'),
  );
  await candidateDatabase.parent.create(recursive: true);
  await _createDatabase(candidateDatabase, conversationId: 'new');
  final databaseInfo = await ChatDatabaseRepository.prepareSnapshotForRestore(
    candidateDatabase,
  );
  final candidateUpload = File(p.join(extracted.path, 'upload', 'new.txt'));
  await candidateUpload.parent.create();
  await candidateUpload.writeAsString('new asset', flush: true);
  final manifest = File(p.join(extracted.path, 'manifest.json'));
  await manifest.writeAsString(
    jsonEncode({
      'format': 'kelivo-backup',
      'formatVersion': 2,
      'payloadKind': 'sqlite',
      'createdAtUtc': '2026-07-09T00:00:00.000Z',
      'appVersion': 'test',
      'includeChats': true,
      'includeFiles': true,
      'secretsIncluded': true,
      'database': {
        'entry': 'database/kelivo.sqlite',
        'schemaVersion': databaseInfo.schemaVersion,
        'conversationCount': databaseInfo.conversationCount,
        'messageCount': databaseInfo.messageCount,
      },
      'entries': {
        'settings.json': await _descriptor(settings),
        'database/kelivo.sqlite': await _descriptor(candidateDatabase),
        'upload/new.txt': await _descriptor(candidateUpload),
      },
    }),
    flush: true,
  );
  final prepared = await RestoreBundlePreparation.prepare(
    appDataDirectory: appData,
    extractedDirectory: extracted,
    sourceManifestSha256: (await sha256.bind(manifest.openRead()).first)
        .toString(),
    bundleIncludesChats: true,
    bundleIncludesFiles: true,
    restoreChats: true,
    restoreFiles: true,
    createdAtUtc: DateTime.utc(2026, 7, 9, 12),
  );
  return _CompleteBundleFixture(
    prepared: prepared,
    liveDatabase: liveDatabase,
    oldUpload: oldUpload,
    liveNewUpload: File(p.join(appData.path, 'upload', 'new.txt')),
  );
}

Future<RestoreReceipt?> _recoverAfterColdRestart({
  required Directory appDataDirectory,
  required SharedPreferences preferences,
}) async {
  await expectLater(
    RestoreStartupGate.recoverAndRequireBusinessReady(
      appDataDirectory: appDataDirectory,
      preferences: preferences,
    ),
    throwsA(isA<RestoreColdRestartRequired>()),
  );
  await simulateRestoreColdProcessBoundary(appDataDirectory);
  return RestoreStartupGate.recoverAndRequireBusinessReady(
    appDataDirectory: appDataDirectory,
    preferences: preferences,
  );
}

Future<void> _createDatabase(
  File file, {
  required String conversationId,
}) async {
  final repository = ChatDatabaseRepository.open(file: file);
  try {
    await repository.ensureReady();
    await repository.putMigrationBatch(
      conversations: [Conversation(id: conversationId, title: conversationId)],
      messages: const [],
      toolEventsByMessageId: const {},
      geminiSignaturesByMessageId: const {},
    );
    await repository.markMigrationComplete();
    await repository.checkpoint();
  } finally {
    await repository.close();
  }
}

void _tamperDatabase(File file) {
  final database = sqlite.sqlite3.open(file.path);
  try {
    database.execute(
      "UPDATE conversation_rows SET title = 'tampered' WHERE id = 'new';",
    );
  } finally {
    database.close();
  }
}

Future<Map<String, dynamic>> _descriptor(File file) async {
  return {
    'bytes': await file.length(),
    'sha256': (await sha256.bind(file.openRead()).first).toString(),
  };
}

Future<List<String>> _conversationIds(File file) async {
  final database = sqlite.sqlite3.open(
    file.path,
    mode: sqlite.OpenMode.readOnly,
  );
  try {
    return database
        .select('SELECT id FROM conversation_rows ORDER BY id;')
        .map((row) => row['id'] as String)
        .toList(growable: false);
  } finally {
    database.close();
  }
}
