import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/backup/restore_receipt.dart';

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
  });

  group('RestoreReceiptStore', () {
    late Directory root;
    late RestoreReceiptStore store;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('kelivo_receipt_test_');
      store = RestoreReceiptStore(appDataDirectory: root, runId: _runId);
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('publishes an append-only validated state history', () async {
      final prepared = _preparedReceipt();
      final previousPrepared = _withPrevious(prepared);

      await store.publish(prepared);
      await store.publish(previousPrepared);

      final latest = await store.readLatest();
      expect(latest?.sequence, 2);
      expect(latest?.state, RestoreReceiptState.oldRenamed);
      expect(latest?.previousChecksum, prepared.checksum);
      expect(latest?.previousManifestSha256, _hash('b'));
      final names = await store.receiptDirectory
          .list(followLinks: false)
          .map((entity) => entity.uri.pathSegments.last)
          .toList();
      expect(names..sort(), [
        'receipt_0000000000000001.json',
        'receipt_0000000000000002.json',
      ]);
    });

    test('rejects sequence gaps instead of using an older state', () async {
      final first = _preparedReceipt();
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
      await store.publish(_preparedReceipt());
      final receiptFile = File(
        '${store.receiptDirectory.path}/receipt_0000000000000001.json',
      );
      final decoded = jsonDecode(await receiptFile.readAsString()) as Map;
      decoded['selectedComponents'] = ['settings'];
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

    test('rejects more records than the state machine can produce', () async {
      await store.receiptDirectory.create(recursive: true);
      for (var sequence = 1; sequence <= 6; sequence++) {
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
        final first = _preparedReceipt();
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

    test('ignores unpublished temp files', () async {
      final prepared = _preparedReceipt();
      await store.publish(prepared);
      await File(
        '${store.receiptDirectory.path}/orphan.json.tmp',
      ).writeAsString('partial', flush: true);

      final latest = await store.readLatest();
      expect(latest?.checksum, prepared.checksum);
    });

    test(
      'rejects a linked run directory',
      () async {
        final outside = Directory('${root.path}/outside');
        await outside.create(recursive: true);
        await store.workspaceRoot.create(recursive: true);
        await Link(store.runDirectory.path).create(outside.path);

        await expectLater(store.publish(_preparedReceipt()), throwsStateError);
        await expectLater(store.readLatest(), throwsStateError);
        expect(await outside.list().toList(), isEmpty);
      },
      skip: Platform.isWindows
          ? 'Creating a symbolic link requires elevated Windows privileges.'
          : false,
    );

    test('allows an identical retry but rejects a skipped sequence', () async {
      final first = _preparedReceipt();
      await store.publish(first);

      await store.publish(first);
      await expectLater(
        store.publish(
          _withPrevious(first).advance(RestoreReceiptState.newInstalled),
        ),
        throwsStateError,
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

      final first = _preparedReceipt();
      final conflicting = _preparedReceipt(hashCharacter: 'c');
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
  });
}
