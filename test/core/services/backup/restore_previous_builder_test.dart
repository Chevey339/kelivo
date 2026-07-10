import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/services/backup/restore_durability.dart';
import 'package:Kelivo/core/services/backup/restore_previous_builder.dart';
import 'package:Kelivo/core/services/backup/restore_previous_plan.dart';
import 'package:Kelivo/core/services/backup/restore_receipt.dart';
import 'package:Kelivo/core/services/backup/restore_settings_transition.dart';

const _runId = '0123456789abcdef0123456789abcdef';
const _candidateHash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

RestoreReceipt _receipt({bool chats = false, bool files = false}) {
  return RestoreReceipt.prepared(
    runId: _runId,
    createdAtUtc: DateTime.utc(2026, 7, 9),
    restoreChats: chats,
    restoreFiles: files,
    candidateManifestSha256: _candidateHash,
  );
}

RestoreSettingsTransition _transition() {
  return RestoreSettingsTransition.build(
    currentSettings: const {'theme': 'dark'},
    candidateSettings: const {'theme': 'light'},
    secretsIncluded: true,
  );
}

void main() {
  group('RestorePreviousBuilder', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp(
        'kelivo_previous_builder_test_',
      );
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('describes selected database and all four asset roots', () async {
      final database = File(p.join(root.path, 'kelivo.sqlite'));
      await database.writeAsBytes([1, 2, 3, 4], flush: true);
      final upload = File(p.join(root.path, 'upload', 'nested', 'note.txt'));
      await upload.parent.create(recursive: true);
      await upload.writeAsString('note', flush: true);
      await Directory(p.join(root.path, 'images')).create();
      final font = File(p.join(root.path, 'fonts', 'font.bin'));
      await font.parent.create(recursive: true);
      await font.writeAsBytes(List<int>.filled(2 * 1024 * 1024, 7));

      final bundle = await RestorePreviousBuilder.build(
        appDataDirectory: root,
        preparedReceipt: _receipt(chats: true, files: true),
        settingsTransition: _transition(),
      );

      expect(bundle.plan.database?.state, RestorePreviousDatabaseState.file);
      expect(bundle.plan.database?.descriptor?.bytes, 4);
      expect(
        bundle.plan.database?.descriptor?.sha256,
        sha256.convert([1, 2, 3, 4]).toString(),
      );
      expect(bundle.plan.assets?.rootStates, const {
        'upload': RestorePreviousAssetRootState.directory,
        'images': RestorePreviousAssetRootState.directory,
        'avatars': RestorePreviousAssetRootState.missing,
        'fonts': RestorePreviousAssetRootState.directory,
      });
      expect(bundle.plan.assets?.entries.keys, [
        'fonts/font.bin',
        'upload/nested/note.txt',
      ]);
      expect(bundle.plan.assets?.entries['upload/nested/note.txt']?.bytes, 4);
      expect(
        bundle.plan.settings.validateSnapshotBytes(
          bundle.settingsSnapshotBytes,
        ),
        {'theme': 'dark'},
      );
      await expectLater(
        RestorePreviousBuilder.validateLive(
          appDataDirectory: root,
          expected: bundle.plan,
        ),
        completes,
      );
    });

    test('preserves a selected missing database distinctly', () async {
      final bundle = await RestorePreviousBuilder.build(
        appDataDirectory: root,
        preparedReceipt: _receipt(chats: true),
        settingsTransition: _transition(),
      );

      expect(bundle.plan.database?.state, RestorePreviousDatabaseState.missing);
      expect(bundle.plan.assets, isNull);
    });

    test('does not inspect unselected database or assets', () async {
      await File(p.join(root.path, 'kelivo.sqlite-wal')).writeAsBytes([1]);
      await File(p.join(root.path, 'upload')).writeAsBytes([2]);

      final bundle = await RestorePreviousBuilder.build(
        appDataDirectory: root,
        preparedReceipt: _receipt(),
        settingsTransition: _transition(),
      );

      expect(bundle.plan.selectedComponents, {RestoreComponent.settings});
      expect(bundle.plan.database, isNull);
      expect(bundle.plan.assets, isNull);
    });

    test('rejects database sidecars before describing the main file', () async {
      await File(p.join(root.path, 'kelivo.sqlite')).writeAsBytes([1]);
      await File(p.join(root.path, 'kelivo.sqlite-shm')).writeAsBytes([2]);

      await expectLater(
        RestorePreviousBuilder.build(
          appDataDirectory: root,
          preparedReceipt: _receipt(chats: true),
          settingsTransition: _transition(),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'restore_previous_database_sidecar:-shm',
          ),
        ),
      );
    });

    test('rejects an asset root that is not a directory', () async {
      await File(p.join(root.path, 'images')).writeAsBytes([1]);

      await expectLater(
        RestorePreviousBuilder.build(
          appDataDirectory: root,
          preparedReceipt: _receipt(files: true),
          settingsTransition: _transition(),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('treats nested empty asset directories as non-semantic', () async {
      await Directory(
        p.join(root.path, 'upload', 'empty', 'nested'),
      ).create(recursive: true);

      final bundle = await RestorePreviousBuilder.build(
        appDataDirectory: root,
        preparedReceipt: _receipt(files: true),
        settingsTransition: _transition(),
      );

      expect(
        bundle.plan.assets!.rootStates['upload'],
        RestorePreviousAssetRootState.directory,
      );
      expect(bundle.plan.assets!.entries, isEmpty);
      await RestorePreviousBuilder.validateLive(
        appDataDirectory: root,
        expected: bundle.plan,
      );
    });

    test('detects same-length file changes during the second scan', () async {
      final asset = File(p.join(root.path, 'upload', 'note.txt'));
      await asset.parent.create(recursive: true);
      await asset.writeAsString('old!', flush: true);
      final bundle = await RestorePreviousBuilder.build(
        appDataDirectory: root,
        preparedReceipt: _receipt(files: true),
        settingsTransition: _transition(),
      );

      await asset.writeAsString('new!', flush: true);

      await expectLater(
        RestorePreviousBuilder.validateLive(
          appDataDirectory: root,
          expected: bundle.plan,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'restore_previous_assets_changed',
          ),
        ),
      );
    });

    test(
      'syncs selected asset roots from files to parent directories',
      () async {
        final asset = File(p.join(root.path, 'upload', 'nested', 'note.txt'));
        await asset.parent.create(recursive: true);
        await asset.writeAsString('asset');
        await Directory(p.join(root.path, 'images')).create();
        final expected = await RestorePreviousBuilder.inspectAssets(root);
        final durability = _RecordingDurability(root);

        await RestorePreviousBuilder.syncAssetRoots(
          root: root,
          expected: expected,
          rootNames: const {'upload', 'images'},
          durability: durability,
        );

        expect(durability.events, const [
          'file:upload/nested/note.txt:false',
          'directory:upload/nested:false',
          'directory:images:false',
          'directory:upload:false',
          'directory:.:true',
        ]);
      },
    );

    test('rejects asset content drift after the durability barrier', () async {
      final asset = File(p.join(root.path, 'upload', 'note.txt'));
      await asset.parent.create();
      await asset.writeAsString('old!');
      final expected = await RestorePreviousBuilder.inspectAssets(root);
      await asset.writeAsString('new!');

      await expectLater(
        RestorePreviousBuilder.syncAssetRoots(
          root: root,
          expected: expected,
          rootNames: const {'upload'},
          durability: _RecordingDurability(root),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'restore_previous_asset_sync_changed:upload',
          ),
        ),
      );
    });

    test('rejects links without following them', () async {
      if (Platform.isWindows) return;
      final outside = File(p.join(root.parent.path, 'outside_asset.txt'));
      await outside.writeAsBytes([1, 2, 3]);
      final upload = Directory(p.join(root.path, 'upload'));
      await upload.create();
      final link = Link(p.join(upload.path, 'linked.txt'));
      await link.create(outside.path);
      try {
        await expectLater(
          RestorePreviousBuilder.build(
            appDataDirectory: root,
            preparedReceipt: _receipt(files: true),
            settingsTransition: _transition(),
          ),
          throwsA(isA<StateError>()),
        );
      } finally {
        if (await outside.exists()) await outside.delete();
      }
    });
  });
}

final class _RecordingDurability implements RestoreDurability {
  _RecordingDurability(this.root);

  final Directory root;
  final events = <String>[];

  String _relative(String path) =>
      p.relative(path, from: root.path).replaceAll('\\', '/');

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) async {
    expect(
      await FileSystemEntity.type(file.path, followLinks: false),
      FileSystemEntityType.file,
    );
    events.add('file:${_relative(file.path)}:$fullBarrier');
  }

  @override
  Future<void> syncDirectory(
    Directory directory, {
    bool fullBarrier = false,
  }) async {
    expect(
      await FileSystemEntity.type(directory.path, followLinks: false),
      FileSystemEntityType.directory,
    );
    events.add('directory:${_relative(directory.path)}:$fullBarrier');
  }

  @override
  Future<void> restrictDirectory(Directory directory) =>
      throw UnsupportedError('not used');

  @override
  Future<void> restrictFile(File file) => throw UnsupportedError('not used');

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) => throw UnsupportedError('not used');
}
