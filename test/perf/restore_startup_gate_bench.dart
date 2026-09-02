// Measures the cold-start restore gate on a realistic bundle.
//
// Not a test: prints timings and counters, contains no expect(). Run with
//   flutter test test/perf/restore_startup_gate_bench.dart
// Size is configurable:
//   KELIVO_BENCH_ASSET_MB (default 150) and KELIVO_BENCH_ASSET_FILES (300).
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/services/backup/restore_bundle_preparation.dart';
import 'package:Kelivo/core/services/backup/restore_durability.dart';
import 'package:Kelivo/core/services/backup/restore_startup_gate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'restore startup gate cold-start cost',
    () async {
      final assetMb =
          int.tryParse(Platform.environment['KELIVO_BENCH_ASSET_MB'] ?? '') ??
          150;
      final assetFiles =
          int.tryParse(
            Platform.environment['KELIVO_BENCH_ASSET_FILES'] ?? '',
          ) ??
          300;
      final root = await Directory.systemTemp.createTemp(
        'kelivo_restore_bench_',
      );
      final appData = Directory(p.join(root.path, 'app_data'));
      await appData.create();

      final fixtureWatch = Stopwatch()..start();
      final liveDatabase = File(p.join(appData.path, 'kelivo.db'));
      await _createDatabase(liveDatabase, conversationId: 'old');
      final liveBytes = await _writeAssets(
        Directory(p.join(appData.path, 'upload')),
        totalMb: assetMb,
        files: assetFiles,
        seed: 1,
      );

      final extracted = Directory(p.join(root.path, 'extracted'));
      await extracted.create();
      final candidateDatabase = File(
        p.join(extracted.path, 'database', 'kelivo.db'),
      );
      await candidateDatabase.parent.create(recursive: true);
      await _createDatabase(candidateDatabase, conversationId: 'new');
      final databaseInfo =
          await ChatDatabaseRepository.prepareSnapshotForRestore(
            candidateDatabase,
          );
      final candidateBytes = await _writeAssets(
        Directory(p.join(extracted.path, 'upload')),
        totalMb: assetMb,
        files: assetFiles,
        seed: 2,
      );
      final settings = File(p.join(extracted.path, 'settings.json'));
      await settings.writeAsString('{"theme":"new"}', flush: true);

      final entries = <String, dynamic>{
        'settings.json': await _descriptor(settings),
        'database/kelivo.db': await _descriptor(candidateDatabase),
      };
      await for (final entity in Directory(
        p.join(extracted.path, 'upload'),
      ).list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final name = p
            .relative(entity.path, from: extracted.path)
            .replaceAll(r'\', '/');
        entries[name] = await _descriptor(entity);
      }
      final manifest = File(p.join(extracted.path, 'manifest.json'));
      await manifest.writeAsString(
        jsonEncode({
          'format': 'kelivo-backup',
          'formatVersion': 2,
          'payloadKind': 'sqlite',
          'createdAtUtc': '2026-07-09T00:00:00.000Z',
          'appVersion': 'bench',
          'includeChats': true,
          'includeFiles': true,
          'secretsIncluded': true,
          'database': {
            'entry': 'database/kelivo.db',
            'schemaVersion': databaseInfo.schemaVersion,
            'conversationCount': databaseInfo.conversationCount,
            'messageCount': databaseInfo.messageCount,
          },
          'entries': entries,
        }),
        flush: true,
      );
      fixtureWatch.stop();

      final prepareWatch = Stopwatch()..start();
      await RestoreBundlePreparation.prepare(
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
      prepareWatch.stop();

      final rollback = Platform.environment['KELIVO_BENCH_ROLLBACK'] == '1';
      final durability = _CountingDurability(
        rollback
            ? _ThrowAfterCandidateDatabaseRename(
                appDataDirectory: appData,
                delegate: RestorePlatformDurability(),
              )
            : RestorePlatformDurability(),
      );
      final stages = <String>[];
      final gateWatch = Stopwatch()..start();
      final outcome = await RestoreStartupGate.recoverAndRequireBusinessReady(
        appDataDirectory: appData,
        durability: durability,
        onStage: (stage) =>
            stages.add('${gateWatch.elapsedMilliseconds}ms  ${stage.name}'),
      );
      gateWatch.stop();

      // ignore: avoid_print
      print('''
--- restore startup gate bench ---
live assets       ${_mb(liveBytes)} MB in $assetFiles files
candidate assets  ${_mb(candidateBytes)} MB in $assetFiles files
fixture build     ${fixtureWatch.elapsedMilliseconds} ms
import (prepare)  ${prepareWatch.elapsedMilliseconds} ms
STARTUP GATE      ${gateWatch.elapsedMilliseconds} ms   -> ${outcome?.state}
  stages          ${stages.join('\n                  ')}
  syncFile        ${durability.syncFiles}
  syncDirectory   ${durability.syncDirectories}
  renameAndSync   ${durability.renames}
  rename timeline ${durability.timeline.join('\n                  ')}
''');

      await root.delete(recursive: true);
    },
    timeout: const Timeout(Duration(minutes: 30)),
  );
}

String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

Future<int> _writeAssets(
  Directory root, {
  required int totalMb,
  required int files,
  required int seed,
}) async {
  await root.create(recursive: true);
  final perFile = (totalMb * 1024 * 1024) ~/ files;
  final random = Random(seed);
  final chunk = Uint8List(perFile);
  for (var i = 0; i < chunk.length; i += 4096) {
    chunk[i] = random.nextInt(256);
  }
  var total = 0;
  for (var index = 0; index < files; index++) {
    final directory = Directory(p.join(root.path, 'bucket${index % 16}'));
    if (index < 16) await directory.create(recursive: true);
    chunk[0] = index & 0xff;
    chunk[1] = (index >> 8) & 0xff;
    final file = File(p.join(directory.path, 'asset_$index.bin'));
    await file.writeAsBytes(chunk, flush: true);
    total += chunk.length;
  }
  return total;
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

Future<Map<String, dynamic>> _descriptor(File file) async => {
  'bytes': await file.length(),
  'sha256': (await sha256.bind(file.openRead()).first).toString(),
};

final class _CountingDurability implements RestoreDurability {
  _CountingDurability(this.delegate) : _watch = Stopwatch()..start();

  final RestoreDurability delegate;
  final Stopwatch _watch;
  final List<String> timeline = <String>[];
  int syncFiles = 0;
  int syncDirectories = 0;
  int renames = 0;

  @override
  Future<void> restrictFile(File file) => delegate.restrictFile(file);

  @override
  Future<void> restrictDirectory(Directory directory) =>
      delegate.restrictDirectory(directory);

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) {
    syncFiles++;
    return delegate.syncFile(file, fullBarrier: fullBarrier);
  }

  @override
  Future<void> syncDirectory(Directory directory, {bool fullBarrier = false}) {
    syncDirectories++;
    return delegate.syncDirectory(directory, fullBarrier: fullBarrier);
  }

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) {
    renames++;
    timeline.add(
      '${_watch.elapsedMilliseconds}ms  ${p.basename(p.dirname(source.path))}/'
      '${p.basename(source.path)} -> '
      '${p.basename(p.dirname(targetPath))}/${p.basename(targetPath)}',
    );
    return delegate.renameAndSync(source: source, targetPath: targetPath);
  }
}

/// Forces the cutover to fail right after the candidate database lands, so the
/// bench can time the compensating rollback.
final class _ThrowAfterCandidateDatabaseRename implements RestoreDurability {
  _ThrowAfterCandidateDatabaseRename({
    required this.appDataDirectory,
    required this.delegate,
  });

  final Directory appDataDirectory;
  final RestoreDurability delegate;
  var _didThrow = false;

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    await delegate.renameAndSync(source: source, targetPath: targetPath);
    if (!_didThrow &&
        p.basename(source.path) == AppDatabase.databaseFileName &&
        p.basename(p.dirname(source.path)) == 'database' &&
        p.equals(
          targetPath,
          p.join(appDataDirectory.path, AppDatabase.databaseFileName),
        ) &&
        source.path.contains('${p.separator}candidate${p.separator}')) {
      _didThrow = true;
      throw StateError('injected_after_candidate_database_rename');
    }
  }

  @override
  Future<void> restrictFile(File file) => delegate.restrictFile(file);

  @override
  Future<void> restrictDirectory(Directory directory) =>
      delegate.restrictDirectory(directory);

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) =>
      delegate.syncFile(file, fullBarrier: fullBarrier);

  @override
  Future<void> syncDirectory(Directory directory, {bool fullBarrier = false}) =>
      delegate.syncDirectory(directory, fullBarrier: fullBarrier);
}
