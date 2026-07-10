import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:Kelivo/core/services/backup/restore_bundle_preparation.dart';
import 'package:Kelivo/core/services/backup/restore_business_lease.dart';
import 'package:Kelivo/core/services/backup/restore_cutover_executor.dart';
import 'package:Kelivo/core/services/backup/restore_durability.dart';
import 'package:Kelivo/core/services/backup/restore_previous_store.dart';
import 'package:Kelivo/core/services/backup/restore_receipt.dart';
import 'package:Kelivo/core/services/backup/restore_settings_cold_ack.dart';
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

enum _LogicalCutoverInterruption {
  claimed,
  previousReady,
  oldRenamedPublished,
  candidateInstalled,
  newInstalledPublished,
  liveVerified,
  verifiedPublished,
  committedPublished,
  rollingBackPublished,
  rollbackVerified,
  rolledBackPublished,
}

/// Interrupts at real durable boundaries instead of exposing a production
/// failpoint callback. Throwing before a receipt rename models work ahead of
/// the journal; throwing after it models a published state awaiting restart.
final class _InterruptingCutoverDurability implements RestoreDurability {
  _InterruptingCutoverDurability(this.delegate, this.point);

  final RestoreDurability delegate;
  final _LogicalCutoverInterruption point;
  var didInterrupt = false;

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    final targetName = p.basename(targetPath);
    if (point == _LogicalCutoverInterruption.claimed &&
        targetName == RestoreWorkspaceLock.publishingRunFileName) {
      await delegate.renameAndSync(source: source, targetPath: targetPath);
      _interrupt();
    }

    final receipt = await _receiptBeingPublished(source, targetPath);
    if (receipt != null && _beforeReceipt(receipt.state) == point) {
      _interrupt();
    }
    await delegate.renameAndSync(source: source, targetPath: targetPath);
    if (receipt != null && _afterReceipt(receipt.state) == point) {
      _interrupt();
    }
  }

  Future<RestoreReceipt?> _receiptBeingPublished(
    FileSystemEntity source,
    String targetPath,
  ) async {
    if (source is! File ||
        p.basename(p.dirname(targetPath)) != 'receipts' ||
        !RegExp(
          r'^receipt_[0-9]{16}\.json$',
        ).hasMatch(p.basename(targetPath))) {
      return null;
    }
    final decoded = jsonDecode(await source.readAsString());
    if (decoded is! Map) throw const FormatException('test_receipt');
    return RestoreReceipt.fromJson(decoded);
  }

  Never _interrupt() {
    didInterrupt = true;
    throw StateError('injected_${point.name}');
  }

  @override
  Future<void> restrictDirectory(Directory directory) =>
      delegate.restrictDirectory(directory);

  @override
  Future<void> restrictFile(File file) => delegate.restrictFile(file);

  @override
  Future<void> syncDirectory(Directory directory, {bool fullBarrier = false}) =>
      delegate.syncDirectory(directory, fullBarrier: fullBarrier);

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) =>
      delegate.syncFile(file, fullBarrier: fullBarrier);
}

_LogicalCutoverInterruption? _beforeReceipt(RestoreReceiptState state) {
  return switch (state) {
    RestoreReceiptState.oldRenamed => _LogicalCutoverInterruption.previousReady,
    RestoreReceiptState.newInstalled =>
      _LogicalCutoverInterruption.candidateInstalled,
    RestoreReceiptState.verified => _LogicalCutoverInterruption.liveVerified,
    RestoreReceiptState.rolledBack =>
      _LogicalCutoverInterruption.rollbackVerified,
    RestoreReceiptState.prepared ||
    RestoreReceiptState.committed ||
    RestoreReceiptState.rollingBack => null,
  };
}

_LogicalCutoverInterruption? _afterReceipt(RestoreReceiptState state) {
  return switch (state) {
    RestoreReceiptState.oldRenamed =>
      _LogicalCutoverInterruption.oldRenamedPublished,
    RestoreReceiptState.newInstalled =>
      _LogicalCutoverInterruption.newInstalledPublished,
    RestoreReceiptState.verified =>
      _LogicalCutoverInterruption.verifiedPublished,
    RestoreReceiptState.committed =>
      _LogicalCutoverInterruption.committedPublished,
    RestoreReceiptState.rollingBack =>
      _LogicalCutoverInterruption.rollingBackPublished,
    RestoreReceiptState.rolledBack =>
      _LogicalCutoverInterruption.rolledBackPublished,
    RestoreReceiptState.prepared => null,
  };
}

final class _ThrowAfterArchivingMarkerDurability implements RestoreDurability {
  _ThrowAfterArchivingMarkerDurability(this.delegate);

  final RestoreDurability delegate;
  var didThrow = false;

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    await delegate.renameAndSync(source: source, targetPath: targetPath);
    if (!didThrow &&
        p.basename(targetPath) == RestoreWorkspaceLock.archivingRunFileName) {
      didThrow = true;
      throw StateError('injected_terminal_archive');
    }
  }

  @override
  Future<void> restrictDirectory(Directory directory) =>
      delegate.restrictDirectory(directory);

  @override
  Future<void> restrictFile(File file) => delegate.restrictFile(file);

  @override
  Future<void> syncDirectory(Directory directory, {bool fullBarrier = false}) =>
      delegate.syncDirectory(directory, fullBarrier: fullBarrier);

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) =>
      delegate.syncFile(file, fullBarrier: fullBarrier);
}

final class _ThrowAfterDiscardingMarkerDurability implements RestoreDurability {
  _ThrowAfterDiscardingMarkerDurability(this.delegate);

  final RestoreDurability delegate;
  var didThrow = false;

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    await delegate.renameAndSync(source: source, targetPath: targetPath);
    if (!didThrow &&
        p.basename(targetPath) == RestoreWorkspaceLock.discardingRunFileName) {
      didThrow = true;
      throw StateError('injected_unpublished_discard');
    }
  }

  @override
  Future<void> restrictDirectory(Directory directory) =>
      delegate.restrictDirectory(directory);

  @override
  Future<void> restrictFile(File file) => delegate.restrictFile(file);

  @override
  Future<void> syncDirectory(Directory directory, {bool fullBarrier = false}) =>
      delegate.syncDirectory(directory, fullBarrier: fullBarrier);

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) =>
      delegate.syncFile(file, fullBarrier: fullBarrier);
}

Future<({Directory directory, String manifestSha256})> _createBundle(
  Directory root, {
  String theme = 'dark',
  bool secretsIncluded = false,
  String directoryName = 'extracted',
}) async {
  final directory = Directory(p.join(root.path, directoryName));
  await directory.create();
  final settings = File(p.join(directory.path, 'settings.json'));
  await settings.writeAsString(jsonEncode({'theme': theme}), flush: true);
  final manifest = File(p.join(directory.path, 'manifest.json'));
  await manifest.writeAsString(
    jsonEncode({
      'format': 'kelivo-backup',
      'formatVersion': 2,
      'payloadKind': 'settings-only',
      'createdAtUtc': '2026-07-09T00:00:00.000Z',
      'appVersion': 'test',
      'includeChats': false,
      'includeFiles': false,
      'secretsIncluded': secretsIncluded,
      'entries': {
        'settings.json': {
          'bytes': await settings.length(),
          'sha256': (await sha256.bind(settings.openRead()).first).toString(),
        },
      },
    }),
    flush: true,
  );
  return (
    directory: directory,
    manifestSha256: (await sha256.bind(manifest.openRead()).first).toString(),
  );
}

Future<Directory> _createStrictUnpublishedRun({
  required Directory root,
  required String runId,
  required String markerFileName,
  bool includeReceiptTemp = true,
}) async {
  final workspace = Directory(
    p.join(root.path, RestoreWorkspaceLock.workspaceRootName),
  );
  await workspace.create(recursive: true);
  await File(
    p.join(workspace.path, markerFileName),
  ).writeAsString(runId, flush: true);
  final runDirectory = Directory(p.join(workspace.path, 'run_$runId'));
  final candidate = Directory(p.join(runDirectory.path, 'candidate'));
  await candidate.create(recursive: true);
  await File(
    p.join(candidate.path, 'settings.json'),
  ).writeAsString('{"partial":', flush: true);
  await Directory(p.join(candidate.path, 'database')).create();
  final nestedAsset = File(
    p.join(candidate.path, 'upload', 'nested', 'partial.bin'),
  );
  await nestedAsset.parent.create(recursive: true);
  await nestedAsset.writeAsBytes([1, 2, 3], flush: true);
  if (includeReceiptTemp) {
    final receipts = Directory(p.join(runDirectory.path, 'receipts'));
    await receipts.create();
    await File(
      p.join(receipts.path, 'receipt_0000000000000001.json.123456_789.tmp'),
    ).writeAsString('{"partial":', flush: true);
  }
  return runDirectory;
}

Future<RestoreReceipt?> _recoverAcrossColdRestart({
  required Directory appDataDirectory,
  required SharedPreferences preferences,
}) async {
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      return await RestoreStartupGate.recoverAndRequireBusinessReady(
        appDataDirectory: appDataDirectory,
        preferences: preferences,
      );
    } on RestoreColdRestartRequired {
      await simulateRestoreColdProcessBoundary(appDataDirectory);
    }
  }
  throw StateError('restore_test_cold_restart_limit');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RestoreStartupGate', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp(
        'kelivo_restore_startup_gate_test_',
      );
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('allows startup when no restore run exists', () async {
      expect(await RestoreStartupGate.inspect(appDataDirectory: root), isNull);

      final workspace = Directory(
        p.join(root.path, RestoreWorkspaceLock.workspaceRootName),
      );
      await workspace.create();
      await File(
        p.join(workspace.path, RestoreWorkspaceLock.lockFileName),
      ).create();

      expect(await RestoreStartupGate.inspect(appDataDirectory: root), isNull);
      expect(
        await RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
        ),
        isNull,
      );
    });

    test('keeps a caller-owned business lease after gate admission', () async {
      final lease = await RestoreBusinessLease.acquire(appDataDirectory: root);
      addTearDown(lease.close);

      expect(
        await RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
          businessLease: lease,
        ),
        isNull,
      );
      expect(lease.isClosed, isFalse);
      await expectLater(
        RestoreBusinessLease.acquire(appDataDirectory: root),
        throwsA(isA<RestoreBusinessLeaseUnavailable>()),
      );
    });

    test(
      'does not touch a prepared run while another process lease is held',
      () async {
        SharedPreferences.setMockInitialValues({'theme': 'old'});
        final bundle = await _createBundle(
          root,
          theme: 'new',
          secretsIncluded: true,
          directoryName: 'leased_prepared_bundle',
        );
        final prepared = await RestoreBundlePreparation.prepare(
          appDataDirectory: root,
          extractedDirectory: bundle.directory,
          sourceManifestSha256: bundle.manifestSha256,
          bundleIncludesChats: false,
          bundleIncludesFiles: false,
          restoreChats: false,
          restoreFiles: false,
          createdAtUtc: DateTime.utc(2026, 7, 9, 12),
        );
        final lease = await RestoreBusinessLease.acquire(
          appDataDirectory: root,
        );
        addTearDown(lease.close);

        await expectLater(
          RestoreStartupGate.recoverAndRequireBusinessReady(
            appDataDirectory: root,
          ),
          throwsA(isA<RestoreBusinessLeaseUnavailable>()),
        );

        final pending = await RestoreStartupGate.inspect(
          appDataDirectory: root,
        );
        expect(pending?.receipt.checksum, prepared.receipt.checksum);
        expect(pending?.receipt.state, RestoreReceiptState.prepared);
        expect(pending?.markerFileName, RestoreWorkspaceLock.activeRunFileName);
        final preferences = await SharedPreferences.getInstance();
        await preferences.reload();
        expect(preferences.getString('theme'), 'old');
      },
    );

    test('discards marker-only and empty-run staging windows', () async {
      final workspace = Directory(
        p.join(root.path, RestoreWorkspaceLock.workspaceRootName),
      );
      await workspace.create();
      for (final withRunDirectory in const [false, true]) {
        final runId = withRunDirectory
            ? '12121212121212121212121212121212'
            : '34343434343434343434343434343434';
        final marker = File(
          p.join(workspace.path, RestoreWorkspaceLock.activeRunFileName),
        );
        await marker.writeAsString(runId, flush: true);
        final runDirectory = Directory(p.join(workspace.path, 'run_$runId'));
        if (withRunDirectory) await runDirectory.create();

        expect(
          await RestoreStartupGate.recoverAndRequireBusinessReady(
            appDataDirectory: root,
          ),
          isNull,
        );
        expect(await marker.exists(), isFalse);
        expect(await runDirectory.exists(), isFalse);
      }
    });

    test(
      'durably discards strict unpublished runs from recoverable markers',
      () async {
        final markerFileNames = [
          RestoreWorkspaceLock.activeRunFileName,
          RestoreWorkspaceLock.publishingRunFileName,
          RestoreWorkspaceLock.discardingRunFileName,
        ];
        for (var index = 0; index < markerFileNames.length; index++) {
          final runId = index.toRadixString(16).padLeft(32, '0');
          final runDirectory = await _createStrictUnpublishedRun(
            root: root,
            runId: runId,
            markerFileName: markerFileNames[index],
          );

          expect(
            await RestoreStartupGate.recoverAndRequireBusinessReady(
              appDataDirectory: root,
            ),
            isNull,
          );
          expect(await runDirectory.exists(), isFalse);
          for (final marker in markerFileNames) {
            expect(
              await File(
                p.join(
                  root.path,
                  RestoreWorkspaceLock.workspaceRootName,
                  marker,
                ),
              ).exists(),
              isFalse,
            );
          }
          expect(
            await RestoreStartupGate.recoverAndRequireBusinessReady(
              appDataDirectory: root,
            ),
            isNull,
          );
        }
      },
    );

    test('resumes unpublished discard after each marker-only window', () async {
      final workspace = Directory(
        p.join(root.path, RestoreWorkspaceLock.workspaceRootName),
      );
      await workspace.create();
      for (final entry in const [
        (marker: RestoreWorkspaceLock.activeRunFileName, contents: ''),
        (
          marker: RestoreWorkspaceLock.discardingRunFileName,
          contents: 'torn-marker',
        ),
      ]) {
        final marker = File(p.join(workspace.path, entry.marker));
        await marker.writeAsString(entry.contents, flush: true);

        expect(
          await RestoreStartupGate.recoverAndRequireBusinessReady(
            appDataDirectory: root,
          ),
          isNull,
        );
        expect(await marker.exists(), isFalse);
      }
    });

    test('resumes after the durable discarding claim is interrupted', () async {
      const runId = 'cccccccccccccccccccccccccccccccc';
      final runDirectory = await _createStrictUnpublishedRun(
        root: root,
        runId: runId,
        markerFileName: RestoreWorkspaceLock.activeRunFileName,
      );
      final durability = _ThrowAfterDiscardingMarkerDurability(
        RestorePlatformDurability(),
      );

      await expectLater(
        RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
          durability: durability,
        ),
        throwsA(isA<StateError>()),
      );
      expect(durability.didThrow, isTrue);
      expect(await runDirectory.exists(), isTrue);
      expect(
        await File(
          p.join(
            root.path,
            RestoreWorkspaceLock.workspaceRootName,
            RestoreWorkspaceLock.discardingRunFileName,
          ),
        ).readAsString(),
        runId,
      );

      expect(
        await RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
        ),
        isNull,
      );
      expect(await runDirectory.exists(), isFalse);
    });

    test('preserves an unpublished run with an unknown entry', () async {
      const runId = 'dddddddddddddddddddddddddddddddd';
      final runDirectory = await _createStrictUnpublishedRun(
        root: root,
        runId: runId,
        markerFileName: RestoreWorkspaceLock.activeRunFileName,
      );
      final unknown = File(p.join(runDirectory.path, 'unknown'));
      await unknown.writeAsString('do not delete', flush: true);

      await expectLater(
        RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
        ),
        throwsA(isA<StateError>()),
      );
      expect(await unknown.readAsString(), 'do not delete');
      expect(await runDirectory.exists(), isTrue);
    });

    test('never discards cold-ack evidence without a final receipt', () async {
      const runId = 'acacacacacacacacacacacacacacacac';
      final runDirectory = await _createStrictUnpublishedRun(
        root: root,
        runId: runId,
        markerFileName: RestoreWorkspaceLock.activeRunFileName,
      );
      await File(
        p.join(runDirectory.path, RestoreSettingsColdAckStore.fileName),
      ).writeAsString('{}', flush: true);

      await expectLater(
        RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'restore_workspace_unpublished_cold_ack',
          ),
        ),
      );

      expect(await runDirectory.exists(), isTrue);
    });

    test('preserves a run whose marker identity is unreadable', () async {
      const runId = 'abababababababababababababababab';
      final runDirectory = await _createStrictUnpublishedRun(
        root: root,
        runId: runId,
        markerFileName: RestoreWorkspaceLock.activeRunFileName,
      );
      final marker = File(
        p.join(
          root.path,
          RestoreWorkspaceLock.workspaceRootName,
          RestoreWorkspaceLock.activeRunFileName,
        ),
      );
      await marker.writeAsString('torn-marker', flush: true);

      await expectLater(
        RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
        ),
        throwsA(isA<StateError>()),
      );
      expect(await marker.readAsString(), 'torn-marker');
      expect(await runDirectory.exists(), isTrue);
    });

    test(
      'preserves an unpublished run containing a linked asset entry',
      () async {
        const runId = 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
        final runDirectory = await _createStrictUnpublishedRun(
          root: root,
          runId: runId,
          markerFileName: RestoreWorkspaceLock.activeRunFileName,
        );
        final outside = File(p.join(root.path, 'outside'));
        await outside.writeAsString('outside', flush: true);
        final link = Link(
          p.join(runDirectory.path, 'candidate', 'images', 'linked'),
        );
        await link.parent.create(recursive: true);
        await link.create(outside.path);

        await expectLater(
          RestoreStartupGate.recoverAndRequireBusinessReady(
            appDataDirectory: root,
          ),
          throwsA(isA<StateError>()),
        );
        expect(await outside.readAsString(), 'outside');
        expect(await link.exists(), isTrue);
      },
      skip: Platform.isWindows
          ? 'Symlink setup is not portable on Windows.'
          : false,
    );

    test('never discards a run containing a final receipt file', () async {
      const runId = 'ffffffffffffffffffffffffffffffff';
      final runDirectory = await _createStrictUnpublishedRun(
        root: root,
        runId: runId,
        markerFileName: RestoreWorkspaceLock.activeRunFileName,
        includeReceiptTemp: false,
      );
      final finalReceipt = File(
        p.join(runDirectory.path, 'receipts', 'receipt_0000000000000001.json'),
      );
      await finalReceipt.parent.create();
      await finalReceipt.writeAsString('{broken', flush: true);

      await expectLater(
        RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
        ),
        throwsA(isA<FormatException>()),
      );
      expect(await finalReceipt.exists(), isTrue);
      expect(await runDirectory.exists(), isTrue);
    });

    test('resumes a published run with a later exact receipt temp', () async {
      SharedPreferences.setMockInitialValues({'theme': 'old'});
      final preferences = await SharedPreferences.getInstance();
      final bundle = await _createBundle(
        root,
        theme: 'new',
        secretsIncluded: true,
        directoryName: 'later_receipt_temp_bundle',
      );
      final prepared = await RestoreBundlePreparation.prepare(
        appDataDirectory: root,
        extractedDirectory: bundle.directory,
        sourceManifestSha256: bundle.manifestSha256,
        bundleIncludesChats: false,
        bundleIncludesFiles: false,
        restoreChats: false,
        restoreFiles: false,
        createdAtUtc: DateTime.utc(2026, 7, 9, 12),
      );
      final store = RestoreReceiptStore(
        appDataDirectory: root,
        runId: prepared.runId,
      );
      final temporary = File(
        p.join(
          store.receiptDirectory.path,
          'receipt_0000000000000002.json.123456_789.tmp',
        ),
      );
      await temporary.writeAsString(
        jsonEncode(
          prepared.receipt
              .advance(
                RestoreReceiptState.oldRenamed,
                previousManifestSha256:
                    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
                    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
              )
              .toJson(),
        ),
        flush: true,
      );

      await expectLater(
        RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
          preferences: preferences,
        ),
        throwsA(isA<RestoreColdRestartRequired>()),
      );
      expect(await temporary.exists(), isTrue);
      expect((await store.readHistory()).map((receipt) => receipt.state), [
        RestoreReceiptState.prepared,
        RestoreReceiptState.oldRenamed,
        RestoreReceiptState.newInstalled,
        RestoreReceiptState.verified,
        RestoreReceiptState.committed,
      ]);
    });

    test(
      'never discards a later receipt temp without a final receipt',
      () async {
        const runId = 'edededededededededededededededed';
        final runDirectory = await _createStrictUnpublishedRun(
          root: root,
          runId: runId,
          markerFileName: RestoreWorkspaceLock.activeRunFileName,
          includeReceiptTemp: false,
        );
        final temporary = File(
          p.join(
            runDirectory.path,
            'receipts',
            'receipt_0000000000000002.json.123456_789.tmp',
          ),
        );
        await temporary.parent.create();
        await temporary.writeAsString('{"partial":', flush: true);

        await expectLater(
          RestoreStartupGate.recoverAndRequireBusinessReady(
            appDataDirectory: root,
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'restore_workspace_unpublished_receipt_entry',
            ),
          ),
        );
        expect(await temporary.exists(), isTrue);
        expect(await runDirectory.exists(), isTrue);
      },
    );

    test('rejects a publishing marker without its run directory', () async {
      final workspace = Directory(
        p.join(root.path, RestoreWorkspaceLock.workspaceRootName),
      );
      await workspace.create();
      final marker = File(
        p.join(workspace.path, RestoreWorkspaceLock.publishingRunFileName),
      );
      await marker.writeAsString(
        '99999999999999999999999999999999',
        flush: true,
      );

      await expectLater(
        RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
        ),
        throwsA(isA<StateError>()),
      );
      expect(await marker.exists(), isTrue);
    });

    test(
      'recognizes a valid prepared run and blocks business startup',
      () async {
        SharedPreferences.setMockInitialValues(const {});
        final preferences = await SharedPreferences.getInstance();
        final bundle = await _createBundle(root);
        final prepared = await RestoreBundlePreparation.prepare(
          appDataDirectory: root,
          extractedDirectory: bundle.directory,
          sourceManifestSha256: bundle.manifestSha256,
          bundleIncludesChats: false,
          bundleIncludesFiles: false,
          restoreChats: false,
          restoreFiles: false,
          createdAtUtc: DateTime.utc(2026, 7, 9, 12),
        );

        final pending = await RestoreStartupGate.inspect(
          appDataDirectory: root,
        );

        expect(pending?.runId, prepared.runId);
        expect(pending?.receipt.checksum, prepared.receipt.checksum);
        await expectLater(
          RestoreStartupGate.recoverAndRequireBusinessReady(
            appDataDirectory: root,
            preferences: preferences,
          ),
          throwsA(isA<RestoreColdRestartRequired>()),
        );
      },
    );

    test('recovers a prepared run through committed before business', () async {
      SharedPreferences.setMockInitialValues({'theme': 'old'});
      final preferences = await SharedPreferences.getInstance();
      final bundle = await _createBundle(
        root,
        theme: 'new',
        secretsIncluded: true,
        directoryName: 'recovery_bundle',
      );
      final prepared = await RestoreBundlePreparation.prepare(
        appDataDirectory: root,
        extractedDirectory: bundle.directory,
        sourceManifestSha256: bundle.manifestSha256,
        bundleIncludesChats: false,
        bundleIncludesFiles: false,
        restoreChats: false,
        restoreFiles: false,
        createdAtUtc: DateTime.utc(2026, 7, 9, 12),
      );

      await expectLater(
        RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
          preferences: preferences,
        ),
        throwsA(isA<RestoreColdRestartRequired>()),
      );
      await simulateRestoreColdProcessBoundary(root);
      expect(
        (await RestoreStartupGate.inspect(
          appDataDirectory: root,
        ))?.receipt.state,
        RestoreReceiptState.committed,
      );
      final result = await RestoreStartupGate.recoverAndRequireBusinessReady(
        appDataDirectory: root,
        preferences: preferences,
      );
      expect(result?.state, RestoreReceiptState.committed);
      await preferences.reload();

      expect(preferences.getString('theme'), 'new');
      final receiptStore = RestoreReceiptStore(
        appDataDirectory: root,
        runId: prepared.runId,
        archived: true,
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
      final previousSettings = File(
        p.join(
          receiptStore.runDirectory.path,
          RestorePreviousStore.previousDirectoryName,
          RestorePreviousStore.settingsFileName,
        ),
      );
      expect(jsonDecode(await previousSettings.readAsString()), {
        'theme': 'old',
      });

      await RestoreStartupGate.recoverAndRequireBusinessReady(
        appDataDirectory: root,
        preferences: preferences,
      );
      expect((await receiptStore.readHistory()), hasLength(5));
    });

    test(
      'same process cannot acknowledge after closing and reacquiring lease',
      () async {
        SharedPreferences.setMockInitialValues({'theme': 'old'});
        final preferences = await SharedPreferences.getInstance();
        final bundle = await _createBundle(
          root,
          theme: 'new',
          secretsIncluded: true,
          directoryName: 'same_lease_cold_ack',
        );
        await RestoreBundlePreparation.prepare(
          appDataDirectory: root,
          extractedDirectory: bundle.directory,
          sourceManifestSha256: bundle.manifestSha256,
          bundleIncludesChats: false,
          bundleIncludesFiles: false,
          restoreChats: false,
          restoreFiles: false,
          createdAtUtc: DateTime.utc(2026, 7, 9, 12),
        );
        final lease = await RestoreBusinessLease.acquire(
          appDataDirectory: root,
        );
        addTearDown(lease.close);

        for (var attempt = 0; attempt < 2; attempt++) {
          await expectLater(
            RestoreStartupGate.recoverAndRequireBusinessReady(
              appDataDirectory: root,
              preferences: preferences,
              businessLease: lease,
            ),
            throwsA(isA<RestoreColdRestartRequired>()),
          );
        }
        expect(
          (await RestoreStartupGate.inspect(
            appDataDirectory: root,
          ))?.receipt.state,
          RestoreReceiptState.committed,
        );

        await lease.close();
        final reacquired = await RestoreBusinessLease.acquire(
          appDataDirectory: root,
        );
        expect(reacquired.processId, lease.processId);
        expect(reacquired.instanceId, isNot(lease.instanceId));
        await expectLater(
          RestoreStartupGate.recoverAndRequireBusinessReady(
            appDataDirectory: root,
            preferences: preferences,
            businessLease: reacquired,
          ),
          throwsA(isA<RestoreColdRestartRequired>()),
        );
        await reacquired.close();
        expect(
          await RestoreStartupGate.inspect(appDataDirectory: root),
          isNotNull,
        );

        await simulateRestoreColdProcessBoundary(root);
        final admitted =
            await RestoreStartupGate.recoverAndRequireBusinessReady(
              appDataDirectory: root,
              preferences: preferences,
            );
        expect(admitted?.state, RestoreReceiptState.committed);
        expect(
          await RestoreStartupGate.inspect(appDataDirectory: root),
          isNull,
        );
      },
    );

    test(
      'terminal run rejects unknown top-level files, directories, and links',
      () async {
        SharedPreferences.setMockInitialValues({'theme': 'old'});
        final preferences = await SharedPreferences.getInstance();
        final bundle = await _createBundle(
          root,
          theme: 'new',
          secretsIncluded: true,
          directoryName: 'terminal_unknown_entry',
        );
        final prepared = await RestoreBundlePreparation.prepare(
          appDataDirectory: root,
          extractedDirectory: bundle.directory,
          sourceManifestSha256: bundle.manifestSha256,
          bundleIncludesChats: false,
          bundleIncludesFiles: false,
          restoreChats: false,
          restoreFiles: false,
          createdAtUtc: DateTime.utc(2026, 7, 9, 12),
        );
        await expectLater(
          RestoreStartupGate.recoverAndRequireBusinessReady(
            appDataDirectory: root,
            preferences: preferences,
          ),
          throwsA(isA<RestoreColdRestartRequired>()),
        );
        final runDirectory = RestoreReceiptStore(
          appDataDirectory: root,
          runId: prepared.runId,
        ).runDirectory;
        final archivedDirectory = RestoreReceiptStore(
          appDataDirectory: root,
          runId: prepared.runId,
          archived: true,
        ).runDirectory;

        Future<void> expectRejected(FileSystemEntity unknown) async {
          await expectLater(
            RestoreStartupGate.inspect(appDataDirectory: root),
            throwsA(
              isA<StateError>().having(
                (error) => error.message,
                'message',
                'restore_startup_run_entry',
              ),
            ),
          );
          await expectLater(
            RestoreStartupGate.recoverAndRequireBusinessReady(
              appDataDirectory: root,
              preferences: preferences,
            ),
            throwsA(isA<StateError>()),
          );
          expect(
            await FileSystemEntity.type(unknown.path, followLinks: false),
            isNot(FileSystemEntityType.notFound),
          );
          expect(await runDirectory.exists(), isTrue);
          expect(await archivedDirectory.exists(), isFalse);
        }

        final unknownFile = File(p.join(runDirectory.path, 'unknown_file'));
        await unknownFile.writeAsString('preserve', flush: true);
        await expectRejected(unknownFile);
        await unknownFile.delete();

        final unknownDirectory = Directory(
          p.join(runDirectory.path, 'unknown_directory'),
        );
        await unknownDirectory.create();
        await expectRejected(unknownDirectory);
        await unknownDirectory.delete();

        if (!Platform.isWindows) {
          final outside = File(p.join(root.path, 'outside_terminal'));
          await outside.writeAsString('outside', flush: true);
          final unknownLink = Link(p.join(runDirectory.path, 'unknown_link'));
          await unknownLink.create(outside.path);
          await expectRejected(unknownLink);
          expect(await outside.readAsString(), 'outside');
        }
      },
    );

    test('rewritten terminal settings require another cold readback', () async {
      SharedPreferences.setMockInitialValues({'theme': 'old'});
      final preferences = await SharedPreferences.getInstance();
      final bundle = await _createBundle(
        root,
        theme: 'new',
        secretsIncluded: true,
        directoryName: 'rewritten_cold_ack',
      );
      await RestoreBundlePreparation.prepare(
        appDataDirectory: root,
        extractedDirectory: bundle.directory,
        sourceManifestSha256: bundle.manifestSha256,
        bundleIncludesChats: false,
        bundleIncludesFiles: false,
        restoreChats: false,
        restoreFiles: false,
        createdAtUtc: DateTime.utc(2026, 7, 9, 12),
      );

      await expectLater(
        RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
          preferences: preferences,
        ),
        throwsA(isA<RestoreColdRestartRequired>()),
      );
      await simulateRestoreColdProcessBoundary(root);
      expect(await preferences.setString('theme', 'old'), isTrue);
      await expectLater(
        RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
          preferences: preferences,
        ),
        throwsA(isA<RestoreColdRestartRequired>()),
      );
      await simulateRestoreColdProcessBoundary(root);
      expect(preferences.getString('theme'), 'new');
      expect(
        await RestoreStartupGate.inspect(appDataDirectory: root),
        isNotNull,
      );

      final admitted = await RestoreStartupGate.recoverAndRequireBusinessReady(
        appDataDirectory: root,
        preferences: preferences,
      );
      expect(admitted?.state, RestoreReceiptState.committed);
      expect(await RestoreStartupGate.inspect(appDataDirectory: root), isNull);
    });

    test('resumes terminal archival and admits the next restore run', () async {
      SharedPreferences.setMockInitialValues({'theme': 'old'});
      final preferences = await SharedPreferences.getInstance();
      final firstBundle = await _createBundle(
        root,
        theme: 'first',
        secretsIncluded: true,
        directoryName: 'first_terminal_bundle',
      );
      final first = await RestoreBundlePreparation.prepare(
        appDataDirectory: root,
        extractedDirectory: firstBundle.directory,
        sourceManifestSha256: firstBundle.manifestSha256,
        bundleIncludesChats: false,
        bundleIncludesFiles: false,
        restoreChats: false,
        restoreFiles: false,
        createdAtUtc: DateTime.utc(2026, 7, 9, 12),
      );
      final durability = _ThrowAfterArchivingMarkerDurability(
        RestorePlatformDurability(),
      );

      await expectLater(
        RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
          preferences: preferences,
        ),
        throwsA(isA<RestoreColdRestartRequired>()),
      );
      await simulateRestoreColdProcessBoundary(root);
      await expectLater(
        RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
          preferences: preferences,
          durability: durability,
        ),
        throwsA(isA<StateError>()),
      );
      final interrupted = await RestoreStartupGate.inspect(
        appDataDirectory: root,
      );
      expect(interrupted?.receipt.state, RestoreReceiptState.committed);
      expect(
        interrupted?.markerFileName,
        RestoreWorkspaceLock.archivingRunFileName,
      );
      expect(await preferences.setString('theme', 'old'), isTrue);

      await expectLater(
        RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
          preferences: preferences,
        ),
        throwsA(isA<RestoreColdRestartRequired>()),
      );
      await simulateRestoreColdProcessBoundary(root);
      final resumed = await RestoreStartupGate.recoverAndRequireBusinessReady(
        appDataDirectory: root,
        preferences: preferences,
      );
      expect(resumed?.state, RestoreReceiptState.committed);
      await preferences.reload();
      expect(preferences.getString('theme'), 'first');
      expect(await RestoreStartupGate.inspect(appDataDirectory: root), isNull);
      expect(
        (await RestoreReceiptStore(
          appDataDirectory: root,
          runId: first.runId,
          archived: true,
        ).readLatest())?.state,
        RestoreReceiptState.committed,
      );

      final secondBundle = await _createBundle(
        root,
        theme: 'second',
        secretsIncluded: true,
        directoryName: 'second_bundle',
      );
      final second = await RestoreBundlePreparation.prepare(
        appDataDirectory: root,
        extractedDirectory: secondBundle.directory,
        sourceManifestSha256: secondBundle.manifestSha256,
        bundleIncludesChats: false,
        bundleIncludesFiles: false,
        restoreChats: false,
        restoreFiles: false,
        createdAtUtc: DateTime.utc(2026, 7, 9, 13),
      );
      final pending = await RestoreStartupGate.inspect(appDataDirectory: root);
      expect(pending?.runId, second.runId);
      expect(pending?.receipt.state, RestoreReceiptState.prepared);
    });

    for (final point in const [
      _LogicalCutoverInterruption.claimed,
      _LogicalCutoverInterruption.previousReady,
      _LogicalCutoverInterruption.oldRenamedPublished,
      _LogicalCutoverInterruption.candidateInstalled,
      _LogicalCutoverInterruption.newInstalledPublished,
      _LogicalCutoverInterruption.liveVerified,
      _LogicalCutoverInterruption.verifiedPublished,
      _LogicalCutoverInterruption.committedPublished,
    ]) {
      test('resumes after logical interruption at ${point.name}', () async {
        SharedPreferences.setMockInitialValues({'theme': 'old'});
        final preferences = await SharedPreferences.getInstance();
        final bundle = await _createBundle(
          root,
          theme: 'new',
          secretsIncluded: true,
          directoryName: 'interrupted_${point.name}',
        );
        final prepared = await RestoreBundlePreparation.prepare(
          appDataDirectory: root,
          extractedDirectory: bundle.directory,
          sourceManifestSha256: bundle.manifestSha256,
          bundleIncludesChats: false,
          bundleIncludesFiles: false,
          restoreChats: false,
          restoreFiles: false,
          createdAtUtc: DateTime.utc(2026, 7, 9, 12),
        );
        final durability = _InterruptingCutoverDurability(
          RestorePlatformDurability(),
          point,
        );

        await expectLater(
          RestoreStartupGate.recoverAndRequireBusinessReady(
            appDataDirectory: root,
            preferences: preferences,
            durability: durability,
          ),
          throwsA(isA<StateError>()),
        );
        expect(durability.didInterrupt, isTrue);
        if (point == _LogicalCutoverInterruption.committedPublished) {
          expect(await preferences.setString('theme', 'old'), isTrue);
        }

        await _recoverAcrossColdRestart(
          appDataDirectory: root,
          preferences: preferences,
        );
        await preferences.reload();
        final receiptStore = RestoreReceiptStore(
          appDataDirectory: root,
          runId: prepared.runId,
          archived: true,
        );
        expect(preferences.getString('theme'), 'new');
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
    }

    for (final point in const [
      _LogicalCutoverInterruption.rollingBackPublished,
      _LogicalCutoverInterruption.rollbackVerified,
      _LogicalCutoverInterruption.rolledBackPublished,
    ]) {
      test('resumes rollback interruption at ${point.name}', () async {
        SharedPreferences.setMockInitialValues({'theme': 'old'});
        final bundle = await _createBundle(
          root,
          theme: 'new',
          secretsIncluded: true,
          directoryName: 'rollback_interrupted_${point.name}',
        );
        final prepared = await RestoreBundlePreparation.prepare(
          appDataDirectory: root,
          extractedDirectory: bundle.directory,
          sourceManifestSha256: bundle.manifestSha256,
          bundleIncludesChats: false,
          bundleIncludesFiles: false,
          restoreChats: false,
          restoreFiles: false,
          createdAtUtc: DateTime.utc(2026, 7, 9, 12),
        );
        SharedPreferencesStorePlatform.instance =
            _FailingNthSetPreferencesStore({
              'flutter.theme': 'old',
            }, failOnCall: 2);
        final preferences = await SharedPreferences.getInstance();
        final durability = _InterruptingCutoverDurability(
          RestorePlatformDurability(),
          point,
        );

        await expectLater(
          RestoreStartupGate.recoverAndRequireBusinessReady(
            appDataDirectory: root,
            preferences: preferences,
            durability: durability,
          ),
          throwsA(isA<RestoreCutoverRollbackException>()),
        );
        expect(durability.didInterrupt, isTrue);
        if (point == _LogicalCutoverInterruption.rolledBackPublished) {
          expect(await preferences.setString('theme', 'new'), isTrue);
        }

        final result = await _recoverAcrossColdRestart(
          appDataDirectory: root,
          preferences: preferences,
        );
        expect(result?.state, RestoreReceiptState.rolledBack);
        await preferences.reload();
        expect(preferences.getString('theme'), 'old');
        expect(
          (await RestoreReceiptStore(
            appDataDirectory: root,
            runId: prepared.runId,
            archived: true,
          ).readHistory()).map((receipt) => receipt.state),
          [
            RestoreReceiptState.prepared,
            RestoreReceiptState.oldRenamed,
            RestoreReceiptState.newInstalled,
            RestoreReceiptState.rollingBack,
            RestoreReceiptState.rolledBack,
          ],
        );
      });
    }

    test('keeps a divergent committed terminal run fail-closed', () async {
      SharedPreferences.setMockInitialValues({'theme': 'old'});
      final preferences = await SharedPreferences.getInstance();
      final bundle = await _createBundle(
        root,
        theme: 'new',
        secretsIncluded: true,
        directoryName: 'divergent_terminal',
      );
      await RestoreBundlePreparation.prepare(
        appDataDirectory: root,
        extractedDirectory: bundle.directory,
        sourceManifestSha256: bundle.manifestSha256,
        bundleIncludesChats: false,
        bundleIncludesFiles: false,
        restoreChats: false,
        restoreFiles: false,
        createdAtUtc: DateTime.utc(2026, 7, 9, 12),
      );
      final durability = _InterruptingCutoverDurability(
        RestorePlatformDurability(),
        _LogicalCutoverInterruption.committedPublished,
      );

      await expectLater(
        RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
          preferences: preferences,
          durability: durability,
        ),
        throwsA(isA<StateError>()),
      );
      expect(durability.didInterrupt, isTrue);
      expect(await preferences.setString('theme', 'unexpected'), isTrue);

      await expectLater(
        RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: root,
          preferences: preferences,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'restore_settings_projection:theme',
          ),
        ),
      );
      final pending = await RestoreStartupGate.inspect(appDataDirectory: root);
      expect(pending?.receipt.state, RestoreReceiptState.committed);
      expect(
        pending?.markerFileName,
        RestoreWorkspaceLock.publishingRunFileName,
      );
    });

    test('recognizes an interrupted publication phase marker', () async {
      final bundle = await _createBundle(root);
      final prepared = await RestoreBundlePreparation.prepare(
        appDataDirectory: root,
        extractedDirectory: bundle.directory,
        sourceManifestSha256: bundle.manifestSha256,
        bundleIncludesChats: false,
        bundleIncludesFiles: false,
        restoreChats: false,
        restoreFiles: false,
        createdAtUtc: DateTime.utc(2026, 7, 9, 12),
      );
      final workspace = Directory(
        p.join(root.path, RestoreWorkspaceLock.workspaceRootName),
      );
      await File(
        p.join(workspace.path, RestoreWorkspaceLock.activeRunFileName),
      ).rename(
        p.join(workspace.path, RestoreWorkspaceLock.publishingRunFileName),
      );

      final pending = await RestoreStartupGate.inspect(appDataDirectory: root);

      expect(pending?.runId, prepared.runId);
      expect(
        pending?.markerFileName,
        RestoreWorkspaceLock.publishingRunFileName,
      );
    });

    test('rejects a prepared run whose candidate changed', () async {
      final bundle = await _createBundle(root);
      final prepared = await RestoreBundlePreparation.prepare(
        appDataDirectory: root,
        extractedDirectory: bundle.directory,
        sourceManifestSha256: bundle.manifestSha256,
        bundleIncludesChats: false,
        bundleIncludesFiles: false,
        restoreChats: false,
        restoreFiles: false,
        createdAtUtc: DateTime.utc(2026, 7, 9, 12),
      );
      await File(
        p.join(prepared.candidateDirectory.path, 'settings.json'),
      ).writeAsString('{"theme":"changed"}', flush: true);

      await expectLater(
        RestoreStartupGate.inspect(appDataDirectory: root),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects unknown workspace entries', () async {
      final workspace = Directory(
        p.join(root.path, RestoreWorkspaceLock.workspaceRootName),
      );
      await workspace.create();
      await File(p.join(workspace.path, 'unknown')).writeAsString('value');

      await expectLater(
        RestoreStartupGate.inspect(appDataDirectory: root),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects a marker without its matching run directory', () async {
      final workspace = Directory(
        p.join(root.path, RestoreWorkspaceLock.workspaceRootName),
      );
      await workspace.create();
      await File(
        p.join(workspace.path, RestoreWorkspaceLock.activeRunFileName),
      ).writeAsString('0123456789abcdef0123456789abcdef', flush: true);

      await expectLater(
        RestoreStartupGate.inspect(appDataDirectory: root),
        throwsA(isA<StateError>()),
      );
    });
  });
}
