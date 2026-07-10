import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/services/backup/restore_bundle_staging.dart';
import 'package:Kelivo/core/services/backup/restore_receipt.dart';
import 'package:Kelivo/core/services/backup/restore_workspace_lock.dart';

String _hash(String character) => List.filled(64, character).join();
const _runId = '0123456789abcdef0123456789abcdef';

RestoreReceipt _preparedReceipt({String hashCharacter = 'a'}) {
  return RestoreReceipt.prepared(
    runId: _runId,
    createdAtUtc: DateTime.utc(2026, 7, 9, 12),
    restoreChats: true,
    restoreFiles: false,
    candidateManifestSha256: _hash(hashCharacter),
  );
}

RestoreReceipt _preparedReceiptForManifest(
  String candidateManifestSha256, {
  DateTime? createdAtUtc,
}) {
  return RestoreReceipt.prepared(
    runId: _runId,
    createdAtUtc: createdAtUtc ?? DateTime.utc(2026, 7, 9, 12),
    restoreChats: false,
    restoreFiles: false,
    candidateManifestSha256: candidateManifestSha256,
  );
}

Future<String> _writeCandidateManifest(RestoreReceiptStore store) async {
  final candidate = Directory(p.join(store.runDirectory.path, 'candidate'));
  await candidate.create(recursive: true);
  await File(
    p.join(store.workspaceRoot.path, RestoreWorkspaceLock.activeRunFileName),
  ).writeAsString(_runId, flush: true);
  final settings = File(p.join(candidate.path, 'settings.json'));
  await settings.writeAsString('{"theme":"dark"}', flush: true);
  final manifest = File(p.join(candidate.path, 'manifest.json'));
  await manifest.writeAsString(
    jsonEncode({
      'format': 'kelivo-backup',
      'formatVersion': 2,
      'payloadKind': 'settings-only',
      'createdAtUtc': '2026-07-09T00:00:00.000Z',
      'appVersion': 'test',
      'includeChats': false,
      'includeFiles': false,
      'secretsIncluded': false,
      'entries': {
        'settings.json': {
          'bytes': await settings.length(),
          'sha256': (await sha256.bind(settings.openRead()).first).toString(),
        },
      },
    }),
    flush: true,
  );
  return (await sha256.bind(manifest.openRead()).first).toString();
}

RestoreReceipt _withPrevious(RestoreReceipt receipt) {
  return receipt.advance(
    RestoreReceiptState.oldRenamed,
    previousManifestSha256: _hash('b'),
  );
}

void main() {
  group('RestoreReceipt', () {
    test('round trips a checksummed prepared receipt', () {
      final source = _preparedReceipt();

      final decoded = RestoreReceipt.fromJson(source.toJson());

      expect(decoded.sequence, 1);
      expect(decoded.state, RestoreReceiptState.prepared);
      expect(decoded.runId, _runId);
      expect(decoded.createdAtUtc, DateTime.utc(2026, 7, 9, 12));
      expect(decoded.selectedComponents, {
        RestoreComponent.settings,
        RestoreComponent.database,
      });
      expect(decoded.previousChecksum, isNull);
      expect(decoded.previousManifestSha256, isNull);
      expect(decoded.candidateManifestSha256, _hash('a'));
    });

    test('rejects checksum tampering and unknown fields', () {
      final source = _preparedReceipt().toJson();
      final tampered = Map<String, dynamic>.from(source)
        ..['selectedComponents'] = ['settings'];
      final extended = Map<String, dynamic>.from(source)..['future'] = true;

      expect(
        () => RestoreReceipt.fromJson(tampered),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => RestoreReceipt.fromJson(extended),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects path-like run IDs and invalid transitions', () {
      expect(
        () => RestoreReceipt.prepared(
          runId: '../escape',
          createdAtUtc: DateTime.utc(2026, 7, 9),
          restoreChats: true,
          restoreFiles: true,
          candidateManifestSha256: _hash('a'),
        ),
        throwsArgumentError,
      );
      expect(
        () => _preparedReceipt().advance(RestoreReceiptState.newInstalled),
        throwsStateError,
      );
    });

    test('requires an explicit rollback intent before rolled back', () {
      final oldRenamed = _withPrevious(_preparedReceipt());
      final newInstalled = oldRenamed.advance(RestoreReceiptState.newInstalled);
      final verified = newInstalled.advance(RestoreReceiptState.verified);

      for (final source in [oldRenamed, newInstalled, verified]) {
        expect(
          () => source.advance(RestoreReceiptState.rolledBack),
          throwsStateError,
        );
        final rollingBack = source.advance(RestoreReceiptState.rollingBack);
        final rolledBack = rollingBack.advance(RestoreReceiptState.rolledBack);
        expect(
          RestoreReceipt.fromJson(rolledBack.toJson()).state,
          RestoreReceiptState.rolledBack,
        );
      }
      expect(
        () => verified
            .advance(RestoreReceiptState.committed)
            .advance(RestoreReceiptState.rollingBack),
        throwsStateError,
      );
    });
  });

  group('RestoreReceiptStore', () {
    late Directory root;
    late RestoreReceiptStore store;
    late String candidateManifestSha256;

    RestoreReceipt prepared({DateTime? createdAtUtc}) {
      return _preparedReceiptForManifest(
        candidateManifestSha256,
        createdAtUtc: createdAtUtc,
      );
    }

    setUp(() async {
      root = await Directory.systemTemp.createTemp('kelivo_receipt_test_');
      store = RestoreReceiptStore(appDataDirectory: root, runId: _runId);
      candidateManifestSha256 = await _writeCandidateManifest(store);
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('publishes an append-only validated state history', () async {
      final initial = prepared();
      final previousPrepared = _withPrevious(initial);

      await store.publish(initial);
      await store.publish(previousPrepared);

      final latest = await store.readLatest();
      expect(latest?.sequence, 2);
      expect(latest?.state, RestoreReceiptState.oldRenamed);
      expect(latest?.previousChecksum, initial.checksum);
      expect(latest?.previousManifestSha256, _hash('b'));
      final names = await store.receiptDirectory
          .list(followLinks: false)
          .map((entity) => entity.uri.pathSegments.last)
          .toList();
      expect(names..sort(), [
        'receipt_0000000000000001.json',
        'receipt_0000000000000002.json',
      ]);
      final history = await store.readHistory();
      expect(history.map((receipt) => receipt.state), [
        RestoreReceiptState.prepared,
        RestoreReceiptState.oldRenamed,
      ]);
    });

    test('rejects candidate components not selected by the receipt', () async {
      final candidate = Directory(p.join(store.runDirectory.path, 'candidate'));
      for (final rootName in const ['upload', 'images', 'avatars', 'fonts']) {
        await Directory(p.join(candidate.path, rootName)).create();
      }
      final asset = File(p.join(candidate.path, 'upload', 'extra.txt'));
      await asset.writeAsString('not selected', flush: true);
      final settings = File(p.join(candidate.path, 'settings.json'));
      final manifest = File(p.join(candidate.path, 'manifest.json'));
      await manifest.writeAsString(
        jsonEncode({
          'format': 'kelivo-backup',
          'formatVersion': 2,
          'payloadKind': 'settings-only',
          'createdAtUtc': '2026-07-09T00:00:00.000Z',
          'appVersion': 'test',
          'includeChats': false,
          'includeFiles': true,
          'secretsIncluded': false,
          'entries': {
            'settings.json': {
              'bytes': await settings.length(),
              'sha256': (await sha256.bind(settings.openRead()).first)
                  .toString(),
            },
            'upload/extra.txt': {
              'bytes': await asset.length(),
              'sha256': (await sha256.bind(asset.openRead()).first).toString(),
            },
          },
        }),
        flush: true,
      );
      candidateManifestSha256 = (await sha256.bind(manifest.openRead()).first)
          .toString();

      await expectLater(
        store.publish(prepared()),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'restore_receipt_candidate_selection',
          ),
        ),
      );
      expect(await store.readLatest(), isNull);
    });

    test(
      'reads and publishes without reentering a held workspace lock',
      () async {
        final initial = prepared();
        await store.publish(initial);
        final workspaceLock = RestoreWorkspaceLock(appDataDirectory: root);

        await workspaceLock.synchronized(() async {
          await workspaceLock.claimCutoverRunWhileWorkspaceLocked(
            runId: _runId,
            observedMarkerFileName: RestoreWorkspaceLock.activeRunFileName,
          );
          expect(await store.readHistoryWhileWorkspaceLocked(), hasLength(1));
          await store.publishWhileWorkspaceLocked(_withPrevious(initial));
          expect(
            (await store.readHistoryWhileWorkspaceLocked()).last.state,
            RestoreReceiptState.oldRenamed,
          );
        });
      },
    );

    test('rejects sequence gaps instead of using an older state', () async {
      final first = prepared();
      final second = _withPrevious(first);
      final third = second.advance(RestoreReceiptState.newInstalled);
      await store.publish(first);
      await store.publish(second);
      await store.publish(third);
      await File(
        '${store.receiptDirectory.path}/receipt_0000000000000002.json',
      ).delete();

      await expectLater(store.readLatest(), throwsStateError);
    });

    test('rejects a corrupted latest receipt without falling back', () async {
      await store.publish(prepared());
      final receiptFile = File(
        '${store.receiptDirectory.path}/receipt_0000000000000001.json',
      );
      final decoded = jsonDecode(await receiptFile.readAsString()) as Map;
      decoded['selectedComponents'] = ['settings', 'database'];
      await receiptFile.writeAsString(jsonEncode(decoded), flush: true);

      await expectLater(store.readLatest(), throwsA(isA<FormatException>()));
    });

    test(
      'rejects an oversized final receipt before reading its JSON',
      () async {
        await store.receiptDirectory.create(recursive: true);
        await File(
          '${store.receiptDirectory.path}/receipt_0000000000000001.json',
        ).writeAsBytes(List.filled(64 * 1024 + 1, 0), flush: true);

        await expectLater(store.readLatest(), throwsA(isA<FormatException>()));
      },
    );

    test('accepts the longest rollback history', () async {
      final first = prepared();
      final second = _withPrevious(first);
      final third = second.advance(RestoreReceiptState.newInstalled);
      final fourth = third.advance(RestoreReceiptState.verified);
      final fifth = fourth.advance(RestoreReceiptState.rollingBack);
      final sixth = fifth.advance(RestoreReceiptState.rolledBack);

      for (final receipt in [first, second, third, fourth, fifth, sixth]) {
        await store.publish(receipt);
      }

      expect((await store.readHistory()).map((receipt) => receipt.state), [
        RestoreReceiptState.prepared,
        RestoreReceiptState.oldRenamed,
        RestoreReceiptState.newInstalled,
        RestoreReceiptState.verified,
        RestoreReceiptState.rollingBack,
        RestoreReceiptState.rolledBack,
      ]);
    });

    test('rejects more records than the state machine can produce', () async {
      await store.receiptDirectory.create(recursive: true);
      for (var sequence = 1; sequence <= 7; sequence++) {
        final digits = sequence.toString().padLeft(16, '0');
        await File(
          '${store.receiptDirectory.path}/receipt_$digits.json',
        ).writeAsString('{}', flush: true);
      }

      await expectLater(store.readLatest(), throwsA(isA<FormatException>()));
    });

    test(
      'rejects a self-consistent replacement that breaks the chain',
      () async {
        final first = prepared();
        await store.publish(first);
        await store.publish(_withPrevious(first));
        await File(
          '${store.receiptDirectory.path}/receipt_0000000000000001.json',
        ).writeAsString(
          jsonEncode(_preparedReceipt(hashCharacter: 'c').toJson()),
          flush: true,
        );

        await expectLater(store.readLatest(), throwsStateError);
      },
    );

    test('ignores only an exact unpublished receipt temp file', () async {
      final initial = prepared();
      await store.publish(initial);
      await File(
        '${store.receiptDirectory.path}/receipt_0000000000000002.json.'
        '1783612800000000_12345.tmp',
      ).writeAsString('partial', flush: true);

      final latest = await store.readLatest();
      expect(latest?.checksum, initial.checksum);
    });

    test('rejects unknown or malformed receipt temp files', () async {
      final initial = prepared();
      await store.publish(initial);
      const invalidNames = [
        'orphan.json.tmp',
        'receipt_2.json.1783612800000000_12345.tmp',
        'receipt_0000000000000002.json.timestamp_12345.tmp',
        'receipt_0000000000000002.json.1783612800000000_pid.tmp',
        'receipt_0000000000000007.json.1783612800000000_12345.tmp',
      ];

      for (final name in invalidNames) {
        final temporary = File(p.join(store.receiptDirectory.path, name));
        await temporary.writeAsString('partial', flush: true);

        await expectLater(
          store.readLatest(),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              'restore_receipt_directory_entry',
            ),
          ),
          reason: name,
        );

        await temporary.delete();
      }
    });

    test(
      'rejects a linked run directory',
      () async {
        final outside = Directory('${root.path}/outside');
        await outside.create(recursive: true);
        await store.runDirectory.delete(recursive: true);
        await Link(store.runDirectory.path).create(outside.path);

        await expectLater(store.publish(prepared()), throwsStateError);
        await expectLater(store.readLatest(), throwsStateError);
        expect(await outside.list().toList(), isEmpty);
      },
      skip: Platform.isWindows
          ? 'Creating a symbolic link requires elevated Windows privileges.'
          : false,
    );

    test('allows an identical retry but rejects a skipped sequence', () async {
      final first = prepared();
      await store.publish(first);

      await store.publish(first);
      await expectLater(
        store.publish(
          _withPrevious(first).advance(RestoreReceiptState.newInstalled),
        ),
        throwsStateError,
      );
    });

    test('rejects a prepared retry after previous state appears', () async {
      final first = prepared();
      await store.publish(first);
      await Directory(p.join(store.runDirectory.path, 'previous')).create();

      await expectLater(store.publish(first), throwsStateError);

      expect((await store.readLatest())?.checksum, first.checksum);
      expect(
        await Directory(p.join(store.runDirectory.path, 'previous')).exists(),
        isTrue,
      );
    });

    test('serializes conflicting concurrent initial receipts', () async {
      Future<Object?> publishResult(RestoreReceipt receipt) async {
        try {
          await store.publish(receipt);
          return null;
        } catch (error) {
          return error;
        }
      }

      final first = prepared();
      final conflicting = prepared(createdAtUtc: DateTime.utc(2026, 7, 9, 13));
      final results = await Future.wait([
        publishResult(first),
        publishResult(conflicting),
      ]);

      final names = await store.receiptDirectory
          .list(followLinks: false)
          .where((entity) => entity.path.endsWith('.json'))
          .map((entity) => entity.uri.pathSegments.last)
          .toList();
      expect(names..sort(), ['receipt_0000000000000001.json']);
      expect(results.where((result) => result == null), hasLength(1));
      expect(results.whereType<StateError>(), hasLength(1));
      expect(
        (await store.readLatest())?.checksum,
        anyOf(first.checksum, conflicting.checksum),
      );
    });

    test('rejects an initial receipt when its run is missing', () async {
      await store.runDirectory.delete(recursive: true);

      await expectLater(store.publish(prepared()), throwsStateError);

      expect(await store.runDirectory.exists(), isFalse);
    });

    test('rejects a missing active-run admission marker', () async {
      await File(
        p.join(
          store.workspaceRoot.path,
          RestoreWorkspaceLock.activeRunFileName,
        ),
      ).delete();

      await expectLater(store.publish(prepared()), throwsStateError);

      expect(await store.receiptDirectory.exists(), isFalse);
    });

    test('rejects a candidate manifest hash mismatch', () async {
      final mismatched = _preparedReceipt(hashCharacter: 'c');

      await expectLater(
        store.publish(mismatched),
        throwsA(isA<FormatException>()),
      );

      expect(await store.receiptDirectory.exists(), isFalse);
      expect(
        await File(
          p.join(
            store.workspaceRoot.path,
            RestoreWorkspaceLock.activeRunFileName,
          ),
        ).readAsString(),
        _runId,
      );
      expect(
        await File(
          p.join(
            store.workspaceRoot.path,
            RestoreWorkspaceLock.publishingRunFileName,
          ),
        ).exists(),
        isFalse,
      );
    });

    test('rejects an unknown temp in a receipt directory', () async {
      await store.receiptDirectory.create();
      final temporary = File(p.join(store.receiptDirectory.path, 'left.tmp'));
      await temporary.writeAsString('partial', flush: true);

      await expectLater(
        store.publish(prepared()),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'restore_receipt_directory_entry',
          ),
        ),
      );

      expect(await temporary.exists(), isTrue);
    });

    test('rejects publication when a second run exists', () async {
      await Directory(
        p.join(
          store.workspaceRoot.path,
          'run_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        ),
      ).create();

      await expectLater(store.publish(prepared()), throwsStateError);

      expect(await store.receiptDirectory.exists(), isFalse);
    });

    test(
      'rejects an incomplete candidate with a valid manifest hash',
      () async {
        await File(
          p.join(store.runDirectory.path, 'candidate', 'settings.json'),
        ).delete();

        await expectLater(
          store.publish(prepared()),
          throwsA(isA<FormatException>()),
        );

        expect(await store.receiptDirectory.exists(), isFalse);
      },
    );

    test(
      'rejects a malformed candidate manifest bound by the receipt',
      () async {
        final manifest = File(
          p.join(store.runDirectory.path, 'candidate', 'manifest.json'),
        );
        await manifest.writeAsString('{"format":"test"}', flush: true);
        final manifestSha256 = (await sha256.bind(manifest.openRead()).first)
            .toString();

        await expectLater(
          store.publish(_preparedReceiptForManifest(manifestSha256)),
          throwsA(isA<FormatException>()),
        );

        expect(await store.receiptDirectory.exists(), isFalse);
      },
    );

    test('rejects a selected component absent from the candidate', () async {
      final receipt = RestoreReceipt.prepared(
        runId: _runId,
        createdAtUtc: DateTime.utc(2026, 7, 9, 12),
        restoreChats: true,
        restoreFiles: false,
        candidateManifestSha256: candidateManifestSha256,
      );

      await expectLater(store.publish(receipt), throwsStateError);

      expect(await store.receiptDirectory.exists(), isFalse);
    });

    test('rejects residual entries beside an initial candidate', () async {
      await Directory(p.join(store.runDirectory.path, 'previous')).create();

      await expectLater(store.publish(prepared()), throwsStateError);

      expect(await store.receiptDirectory.exists(), isFalse);
    });

    test('serializes publish and discard across worker isolates', () async {
      final appDataPath = root.path;
      final manifestSha256 = candidateManifestSha256;

      final results = await Future.wait([
        Isolate.run(() async {
          try {
            final workerStore = RestoreReceiptStore(
              appDataDirectory: Directory(appDataPath),
              runId: _runId,
            );
            await workerStore.publish(
              _preparedReceiptForManifest(manifestSha256),
            );
            return true;
          } catch (_) {
            return false;
          }
        }),
        Isolate.run(() async {
          try {
            await RestoreBundleStaging.discardUnpublished(
              appDataDirectory: Directory(appDataPath),
              runId: _runId,
            );
            return true;
          } catch (_) {
            return false;
          }
        }),
      ]);

      expect(results.where((result) => result), hasLength(1));
      if (results.first) {
        expect(await store.runDirectory.exists(), isTrue);
        expect(
          await File(
            p.join(
              store.receiptDirectory.path,
              'receipt_0000000000000001.json',
            ),
          ).exists(),
          isTrue,
        );
        expect(
          await File(
            p.join(
              store.workspaceRoot.path,
              RestoreWorkspaceLock.activeRunFileName,
            ),
          ).readAsString(),
          _runId,
        );
      } else {
        expect(await store.runDirectory.exists(), isFalse);
        expect(
          await File(
            p.join(
              store.workspaceRoot.path,
              RestoreWorkspaceLock.activeRunFileName,
            ),
          ).exists(),
          isFalse,
        );
      }
    });
  });
}
