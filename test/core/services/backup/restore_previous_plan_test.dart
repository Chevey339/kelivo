import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/backup/restore_previous_plan.dart';
import 'package:Kelivo/core/services/backup/restore_receipt.dart';

const _hashA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _hashB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _hashC =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _runId = '0123456789abcdef0123456789abcdef';
const _otherRunId = 'ffffffffffffffffffffffffffffffff';

RestoreReceipt _preparedReceipt({
  bool restoreFiles = false,
  String candidateManifestSha256 = _hashB,
}) {
  return RestoreReceipt.prepared(
    runId: _runId,
    createdAtUtc: DateTime.utc(2026, 7, 9, 12),
    restoreFiles: restoreFiles,
    candidateManifestSha256: candidateManifestSha256,
  );
}

RestorePreviousPlan _databaseOnlyPlan() {
  return RestorePreviousPlan.forPreparedReceipt(
    receipt: _preparedReceipt(),
    database: RestorePreviousDatabasePlan.missing(),
  );
}

Map<String, dynamic> _withChecksum(Map<String, dynamic> source) {
  final payload = Map<String, dynamic>.from(source)..remove('checksum');
  return {
    ...payload,
    'checksum': sha256.convert(utf8.encode(jsonEncode(payload))).toString(),
  };
}

void main() {
  group('RestorePreviousPlan', () {
    test('round trips the canonical database-only plan', () {
      final plan = _databaseOnlyPlan();

      final restored = RestorePreviousPlan.fromJson(
        plan.toJson(),
        preparedReceipt: _preparedReceipt(),
      );

      expect(restored.runId, _runId);
      expect(restored.selectedComponents, {RestoreComponent.database});
      expect(restored.database.state, RestorePreviousDatabaseState.missing);
      expect(restored.assets, isNull);
      expect(restored.toJson(), isNot(contains('settings')));
      expect(restored.checksum, plan.checksum);
    });

    test('preserves missing asset roots and a populated database', () {
      final plan = RestorePreviousPlan.forPreparedReceipt(
        receipt: _preparedReceipt(restoreFiles: true),
        database: RestorePreviousDatabasePlan.file(
          const RestoreFileDescriptor(bytes: 7, sha256: _hashA),
        ),
        assets: RestorePreviousAssetsPlan(
          rootStates: const {
            'upload': RestorePreviousAssetRootState.directory,
            'images': RestorePreviousAssetRootState.directory,
            'avatars': RestorePreviousAssetRootState.missing,
            'fonts': RestorePreviousAssetRootState.directory,
          },
          entries: const {
            'upload/note.txt': RestoreFileDescriptor(bytes: 4, sha256: _hashC),
          },
        ),
      );

      final restored = RestorePreviousPlan.fromJson(
        plan.toJson(),
        preparedReceipt: _preparedReceipt(restoreFiles: true),
      );

      expect(restored.database.state, RestorePreviousDatabaseState.file);
      expect(restored.database.descriptor?.bytes, 7);
      expect(
        restored.assets?.rootStates['avatars'],
        RestorePreviousAssetRootState.missing,
      );
      expect(restored.assets?.entries.keys, ['upload/note.txt']);
    });

    test('rejects checksum changes, unknown fields, and three-leg plans', () {
      final json = _databaseOnlyPlan().toJson();

      expect(
        () => RestorePreviousPlan.fromJson({
          ...json,
          'runId': _otherRunId,
        }, preparedReceipt: _preparedReceipt()),
        throwsFormatException,
      );
      expect(
        () => RestorePreviousPlan.fromJson({
          ...json,
          'unknown': true,
        }, preparedReceipt: _preparedReceipt()),
        throwsFormatException,
      );
      expect(
        () => RestorePreviousPlan.fromJson(
          _withChecksum({
            ...json,
            'formatVersion': 1,
            'selectedComponents': ['settings', 'database'],
            'settings': const <String, dynamic>{},
          }),
          preparedReceipt: _preparedReceipt(),
        ),
        throwsFormatException,
      );
    });

    test('rejects plans inconsistent with the selected components', () {
      expect(
        () => RestorePreviousPlan.forPreparedReceipt(
          receipt: _preparedReceipt(restoreFiles: true),
          database: RestorePreviousDatabasePlan.missing(),
        ),
        throwsArgumentError,
      );
      expect(
        () => RestorePreviousPlan.forPreparedReceipt(
          receipt: _preparedReceipt(),
          database: RestorePreviousDatabasePlan.missing(),
          assets: RestorePreviousAssetsPlan(
            rootStates: const {
              'upload': RestorePreviousAssetRootState.missing,
              'images': RestorePreviousAssetRootState.missing,
              'avatars': RestorePreviousAssetRootState.missing,
              'fonts': RestorePreviousAssetRootState.missing,
            },
            entries: const {},
          ),
        ),
        throwsArgumentError,
      );
    });

    test('binds the plan to one exact prepared receipt', () {
      final receipt = _preparedReceipt();
      final plan = RestorePreviousPlan.forPreparedReceipt(
        receipt: receipt,
        database: RestorePreviousDatabasePlan.missing(),
      );

      expect(() => plan.validatePreparedReceipt(receipt), returnsNormally);
      expect(
        () => plan.validatePreparedReceipt(
          _preparedReceipt(candidateManifestSha256: _hashC),
        ),
        throwsStateError,
      );
    });

    test('rejects unsafe assets and invalid database descriptors', () {
      expect(
        () => RestorePreviousAssetsPlan(
          rootStates: const {
            'upload': RestorePreviousAssetRootState.directory,
            'images': RestorePreviousAssetRootState.directory,
            'avatars': RestorePreviousAssetRootState.directory,
            'fonts': RestorePreviousAssetRootState.directory,
          },
          entries: const {
            'upload/../secret': RestoreFileDescriptor(bytes: 1, sha256: _hashA),
          },
        ),
        throwsArgumentError,
      );
      expect(
        () => RestorePreviousDatabasePlan.file(
          const RestoreFileDescriptor(bytes: -1, sha256: _hashA),
        ),
        throwsArgumentError,
      );
    });
  });
}
