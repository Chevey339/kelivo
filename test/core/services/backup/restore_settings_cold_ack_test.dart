import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/services/backup/restore_durability.dart';
import 'package:Kelivo/core/services/backup/restore_settings_cold_ack.dart';

const _runId = '0123456789abcdef0123456789abcdef';
const _otherRunId = 'fedcba9876543210fedcba9876543210';
const _receiptChecksum =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _otherReceiptChecksum =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _leaseId = '11111111111111111111111111111111';
const _nextLeaseId = '22222222222222222222222222222222';
const _processId = 12345;

void main() {
  group('RestoreSettingsColdAckStore', () {
    late Directory root;
    late Directory runDirectory;

    setUp(() async {
      root = await Directory.systemTemp.createTemp(
        'kelivo_settings_cold_ack_test_',
      );
      runDirectory = Directory(p.join(root.path, 'run_$_runId'));
      await runDirectory.create();
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('durably publishes and reads canonical ack', () async {
      final recording = _RecordingDurability(RestorePlatformDurability());
      final store = RestoreSettingsColdAckStore(
        runDirectory: runDirectory,
        durability: recording,
      );

      final written = await store.writeOrReplace(
        terminalReceiptChecksum: _receiptChecksum,
        expected: RestoreSettingsColdAckExpected.target,
        leaseInstanceId: _leaseId,
        processId: _processId,
      );
      final read = (await store.read())!;

      expect(read.checksum, written.checksum);
      expect(read.runId, _runId);
      expect(read.terminalReceiptChecksum, _receiptChecksum);
      expect(read.expected, RestoreSettingsColdAckExpected.target);
      expect(read.leaseInstanceId, _leaseId);
      expect(read.processId, _processId);
      expect(written.runId, _runId);
      final raw = await store.file.readAsString();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(decoded.keys, [
        'version',
        'runId',
        'terminalReceiptChecksum',
        'expected',
        'leaseInstanceId',
        'processId',
        'checksum',
      ]);
      expect(decoded['version'], 1);
      expect(decoded['expected'], 'target');
      expect(decoded['processId'], _processId);
      expect(decoded['checksum'], written.checksum);

      final syncIndex = recording.events.indexWhere(
        (event) => event.startsWith('sync-file:') && event.endsWith(':true'),
      );
      final renameIndex = recording.events.indexWhere(
        (event) => event.endsWith('->settings_cold_ack.json'),
      );
      expect(syncIndex, greaterThanOrEqualTo(0));
      expect(renameIndex, greaterThan(syncIndex));
      expect(
        recording.events.take(renameIndex),
        contains(predicate<String>((event) => event.startsWith('restrict:'))),
      );
      if (!Platform.isWindows) {
        expect((await store.file.stat()).mode & 0x1ff, 0x180);
      }
    });

    test('accepts only target or before and preserves every token', () async {
      final before = RestoreSettingsColdAck(
        runId: _runId,
        terminalReceiptChecksum: _receiptChecksum,
        expected: RestoreSettingsColdAckExpected.before,
        leaseInstanceId: _leaseId,
        processId: _processId,
      );
      expect(
        RestoreSettingsColdAck.fromJson(before.toJson()).expected,
        RestoreSettingsColdAckExpected.before,
      );
      final invalidExpected = Map<String, dynamic>.from(before.toJson())
        ..['expected'] = 'current';
      await expectLater(
        Future<void>.sync(
          () => RestoreSettingsColdAck.fromJson(invalidExpected),
        ),
        throwsFormatException,
      );

      final store = RestoreSettingsColdAckStore(runDirectory: runDirectory);
      await store.writeOrReplace(
        terminalReceiptChecksum: _receiptChecksum,
        expected: RestoreSettingsColdAckExpected.before,
        leaseInstanceId: _leaseId,
        processId: _processId,
      );
      final persisted = (await store.read())!;
      expect(persisted.runId, _runId);
      expect(persisted.terminalReceiptChecksum, _receiptChecksum);
      expect(persisted.expected, RestoreSettingsColdAckExpected.before);
      expect(persisted.leaseInstanceId, _leaseId);
      expect(persisted.processId, _processId);
    });

    test(
      'strictly rejects fields, types, identifiers, and checksum drift',
      () async {
        final store = RestoreSettingsColdAckStore(runDirectory: runDirectory);
        final valid = RestoreSettingsColdAck(
          runId: _runId,
          terminalReceiptChecksum: _receiptChecksum,
          expected: RestoreSettingsColdAckExpected.target,
          leaseInstanceId: _leaseId,
          processId: _processId,
        ).toJson();
        final invalidDocuments = <Map<String, dynamic>>[
          Map<String, dynamic>.from(valid)..['extra'] = true,
          Map<String, dynamic>.from(valid)..remove('version'),
          Map<String, dynamic>.from(valid)..['version'] = 2,
          Map<String, dynamic>.from(valid)..['version'] = '1',
          Map<String, dynamic>.from(valid)..['version'] = 1.0,
          Map<String, dynamic>.from(valid)..['runId'] = _runId.toUpperCase(),
          Map<String, dynamic>.from(valid)
            ..['terminalReceiptChecksum'] = 'a' * 63,
          Map<String, dynamic>.from(valid)..['leaseInstanceId'] = '1' * 31,
          Map<String, dynamic>.from(valid)..['processId'] = 0,
          Map<String, dynamic>.from(valid)..['processId'] = 1.5,
          Map<String, dynamic>.from(valid)..['checksum'] = 'f' * 64,
        ];

        for (final document in invalidDocuments) {
          await store.file.writeAsString(jsonEncode(document), flush: true);
          await expectLater(store.read(), throwsFormatException);
        }
      },
    );

    test(
      'rejects non-canonical JSON even when payload checksum is valid',
      () async {
        final store = RestoreSettingsColdAckStore(runDirectory: runDirectory);
        final ack = RestoreSettingsColdAck(
          runId: _runId,
          terminalReceiptChecksum: _receiptChecksum,
          expected: RestoreSettingsColdAckExpected.target,
          leaseInstanceId: _leaseId,
          processId: _processId,
        );
        final canonical = ack.toJson();
        final reordered = <String, dynamic>{
          'checksum': canonical['checksum'],
          'processId': canonical['processId'],
          'leaseInstanceId': canonical['leaseInstanceId'],
          'expected': canonical['expected'],
          'terminalReceiptChecksum': canonical['terminalReceiptChecksum'],
          'runId': canonical['runId'],
          'version': canonical['version'],
        };
        await store.file.writeAsString(jsonEncode(reordered), flush: true);

        await expectLater(store.read(), throwsFormatException);
      },
    );

    test('rejects oversized ack before decoding', () async {
      final store = RestoreSettingsColdAckStore(runDirectory: runDirectory);
      await store.file.writeAsString('x' * (20 * 1024), flush: true);

      await expectLater(store.read(), throwsFormatException);
    });

    test('binds document runId to the canonical run path', () async {
      expect(
        () => RestoreSettingsColdAckStore(
          runDirectory: Directory(p.join(root.path, 'run_invalid')),
        ),
        throwsArgumentError,
      );
      final store = RestoreSettingsColdAckStore(runDirectory: runDirectory);
      final wrongIdentity = RestoreSettingsColdAck(
        runId: _otherRunId,
        terminalReceiptChecksum: _receiptChecksum,
        expected: RestoreSettingsColdAckExpected.target,
        leaseInstanceId: _leaseId,
        processId: _processId,
      );
      await store.file.writeAsString(
        jsonEncode(wrongIdentity.toJson()),
        flush: true,
      );

      await expectLater(store.read(), throwsFormatException);
    });

    test('rejects ack and run-directory symlinks', () async {
      if (Platform.isWindows) return;
      final store = RestoreSettingsColdAckStore(runDirectory: runDirectory);
      final external = File(p.join(root.path, 'external.json'));
      await external.writeAsString('{}', flush: true);
      await Link(store.file.path).create(external.path);

      await expectLater(store.read(), throwsStateError);

      await Link(store.file.path).delete();
      final realRun = Directory(p.join(root.path, 'real_run'));
      await realRun.create();
      final linkedRun = Link(p.join(root.path, 'run_$_otherRunId'));
      await linkedRun.create(realRun.path);
      final linkedStore = RestoreSettingsColdAckStore(
        runDirectory: Directory(linkedRun.path),
      );
      await expectLater(linkedStore.read(), throwsStateError);
    });

    test(
      'same lease token is idempotent without another publication',
      () async {
        final recording = _RecordingDurability(RestorePlatformDurability());
        final store = RestoreSettingsColdAckStore(
          runDirectory: runDirectory,
          durability: recording,
        );
        final first = await store.writeOrReplace(
          terminalReceiptChecksum: _receiptChecksum,
          expected: RestoreSettingsColdAckExpected.target,
          leaseInstanceId: _leaseId,
          processId: _processId,
        );
        final eventCount = recording.events.length;

        final repeated = await store.writeOrReplace(
          terminalReceiptChecksum: _receiptChecksum,
          expected: RestoreSettingsColdAckExpected.target,
          leaseInstanceId: _leaseId,
          processId: _processId,
        );

        expect(repeated.checksum, first.checksum);
        expect(recording.events, hasLength(eventCount));
      },
    );

    test(
      'atomically replaces only the lease token for the same terminal state',
      () async {
        final recording = _RecordingDurability(RestorePlatformDurability());
        final store = RestoreSettingsColdAckStore(
          runDirectory: runDirectory,
          durability: recording,
        );
        await store.writeOrReplace(
          terminalReceiptChecksum: _receiptChecksum,
          expected: RestoreSettingsColdAckExpected.target,
          leaseInstanceId: _leaseId,
          processId: _processId,
        );
        recording.events.clear();

        final replaced = await store.writeOrReplace(
          terminalReceiptChecksum: _receiptChecksum,
          expected: RestoreSettingsColdAckExpected.target,
          leaseInstanceId: _nextLeaseId,
          processId: _processId,
        );

        expect(replaced.leaseInstanceId, _nextLeaseId);
        expect((await store.read())?.leaseInstanceId, _nextLeaseId);
        expect(
          recording.events.where((event) => event.startsWith('rename:')),
          hasLength(1),
        );
        expect(await _coldAckArtifacts(runDirectory), [
          RestoreSettingsColdAckStore.fileName,
        ]);
      },
    );

    test('rejects replacing a different receipt or expected state', () async {
      final store = RestoreSettingsColdAckStore(runDirectory: runDirectory);
      await store.writeOrReplace(
        terminalReceiptChecksum: _receiptChecksum,
        expected: RestoreSettingsColdAckExpected.target,
        leaseInstanceId: _leaseId,
        processId: _processId,
      );

      await expectLater(
        store.writeOrReplace(
          terminalReceiptChecksum: _otherReceiptChecksum,
          expected: RestoreSettingsColdAckExpected.target,
          leaseInstanceId: _nextLeaseId,
          processId: _processId,
        ),
        throwsStateError,
      );
      await expectLater(
        store.writeOrReplace(
          terminalReceiptChecksum: _receiptChecksum,
          expected: RestoreSettingsColdAckExpected.before,
          leaseInstanceId: _nextLeaseId,
          processId: _processId,
        ),
        throwsStateError,
      );
      expect((await store.read())?.leaseInstanceId, _leaseId);
    });

    test(
      'cleans a unique temp when failure happens before publication',
      () async {
        final initial = RestoreSettingsColdAckStore(runDirectory: runDirectory);
        await initial.writeOrReplace(
          terminalReceiptChecksum: _receiptChecksum,
          expected: RestoreSettingsColdAckExpected.target,
          leaseInstanceId: _leaseId,
          processId: _processId,
        );
        final failing = _RecordingDurability(
          RestorePlatformDurability(),
          failNextTemporarySync: true,
        );
        final store = RestoreSettingsColdAckStore(
          runDirectory: runDirectory,
          durability: failing,
        );

        await expectLater(
          store.writeOrReplace(
            terminalReceiptChecksum: _receiptChecksum,
            expected: RestoreSettingsColdAckExpected.target,
            leaseInstanceId: _nextLeaseId,
            processId: _processId,
          ),
          throwsStateError,
        );

        expect((await store.read())?.leaseInstanceId, _leaseId);
        expect(await _coldAckArtifacts(runDirectory), [
          RestoreSettingsColdAckStore.fileName,
        ]);
      },
    );

    test(
      'ack absence after replacement deletion is safely retryable',
      () async {
        await _seedAck(runDirectory);
        final durability = _RecordingDurability(
          RestorePlatformDurability(),
          failNextDirectorySync: true,
        );
        final store = RestoreSettingsColdAckStore(
          runDirectory: runDirectory,
          durability: durability,
        );

        await expectLater(
          store.writeOrReplace(
            terminalReceiptChecksum: _receiptChecksum,
            expected: RestoreSettingsColdAckExpected.target,
            leaseInstanceId: _nextLeaseId,
            processId: _processId,
          ),
          throwsStateError,
        );

        expect(await store.file.exists(), isFalse);
        expect(await store.read(), isNull);
        expect(await _coldAckArtifacts(runDirectory), isEmpty);
        final retried = await store.writeOrReplace(
          terminalReceiptChecksum: _receiptChecksum,
          expected: RestoreSettingsColdAckExpected.target,
          leaseInstanceId: _nextLeaseId,
          processId: _processId,
        );
        expect(retried.leaseInstanceId, _nextLeaseId);
      },
    );

    test('accepts the published ack after a post-rename fault', () async {
      await _seedAck(runDirectory);
      final durability = _RecordingDurability(
        RestorePlatformDurability(),
        throwAfterRename: 1,
      );
      final store = RestoreSettingsColdAckStore(
        runDirectory: runDirectory,
        durability: durability,
      );

      await expectLater(
        store.writeOrReplace(
          terminalReceiptChecksum: _receiptChecksum,
          expected: RestoreSettingsColdAckExpected.target,
          leaseInstanceId: _nextLeaseId,
          processId: _processId,
        ),
        throwsStateError,
      );

      final rawAck = RestoreSettingsColdAck.fromJson(
        jsonDecode(await store.file.readAsString()) as Map,
      );
      expect(rawAck.leaseInstanceId, _nextLeaseId);
      expect((await store.read())?.leaseInstanceId, _nextLeaseId);
    });

    test(
      'discards exact unpublished temps but rejects unknown siblings',
      () async {
        final store = RestoreSettingsColdAckStore(runDirectory: runDirectory);
        final temporary = File(
          p.join(
            runDirectory.path,
            '${RestoreSettingsColdAckStore.fileName}.123_456_0.tmp',
          ),
        );
        await temporary.writeAsString('{', flush: true);

        expect(await store.read(), isNull);
        expect(await temporary.exists(), isFalse);

        await File(
          p.join(
            runDirectory.path,
            '${RestoreSettingsColdAckStore.fileName}.orphan.tmp',
          ),
        ).writeAsString('{}', flush: true);

        await expectLater(store.read(), throwsStateError);
        await expectLater(
          store.writeOrReplace(
            terminalReceiptChecksum: _receiptChecksum,
            expected: RestoreSettingsColdAckExpected.target,
            leaseInstanceId: _leaseId,
            processId: _processId,
          ),
          throwsStateError,
        );
      },
    );
  });
}

Future<void> _seedAck(Directory runDirectory) async {
  await RestoreSettingsColdAckStore(runDirectory: runDirectory).writeOrReplace(
    terminalReceiptChecksum: _receiptChecksum,
    expected: RestoreSettingsColdAckExpected.target,
    leaseInstanceId: _leaseId,
    processId: _processId,
  );
}

Future<List<String>> _coldAckArtifacts(Directory runDirectory) async {
  final names = <String>[];
  await for (final entity in runDirectory.list(followLinks: false)) {
    final name = p.basename(entity.path);
    if (name.startsWith(RestoreSettingsColdAckStore.fileName)) names.add(name);
  }
  names.sort();
  return names;
}

final class _RecordingDurability implements RestoreDurability {
  _RecordingDurability(
    this.delegate, {
    this.throwAfterRename,
    this.failNextTemporarySync = false,
    this.failNextDirectorySync = false,
  });

  final RestoreDurability delegate;
  final int? throwAfterRename;
  bool failNextTemporarySync;
  bool failNextDirectorySync;
  int _renameCount = 0;
  final events = <String>[];

  @override
  Future<void> restrictDirectory(Directory directory) async {
    events.add('restrict-dir:${p.basename(directory.path)}');
    await delegate.restrictDirectory(directory);
  }

  @override
  Future<void> restrictFile(File file) async {
    events.add('restrict:${p.basename(file.path)}');
    await delegate.restrictFile(file);
  }

  @override
  Future<void> syncDirectory(
    Directory directory, {
    bool fullBarrier = false,
  }) async {
    events.add('sync-dir:${p.basename(directory.path)}:$fullBarrier');
    if (failNextDirectorySync) {
      failNextDirectorySync = false;
      throw StateError('injected_directory_sync_failure');
    }
    await delegate.syncDirectory(directory, fullBarrier: fullBarrier);
  }

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) async {
    events.add('sync-file:${p.basename(file.path)}:$fullBarrier');
    if (failNextTemporarySync && file.path.endsWith('.tmp')) {
      failNextTemporarySync = false;
      throw StateError('injected_sync_failure');
    }
    await delegate.syncFile(file, fullBarrier: fullBarrier);
  }

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    events.add('rename:${p.basename(source.path)}->${p.basename(targetPath)}');
    await delegate.renameAndSync(source: source, targetPath: targetPath);
    _renameCount++;
    if (_renameCount == throwAfterRename) {
      throw StateError('injected_rename_failure:$_renameCount');
    }
  }
}
