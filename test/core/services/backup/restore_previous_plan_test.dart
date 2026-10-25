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

    for (final restoreFiles in [false, true]) {
      test('reads v2 plans without changing their bytes ($restoreFiles)', () {
        final receipt = _preparedReceipt(restoreFiles: restoreFiles);
        // The persisted v1.3.0 schema, independent of the current writer.
        final json = _withChecksum({
          'format': 'kelivo.restore-previous-plan',
          'formatVersion': 2,
          'runId': receipt.runId,
          'preparedReceiptChecksum': receipt.checksum,
          'candidateManifestSha256': receipt.candidateManifestSha256,
          'selectedComponents': ['database', if (restoreFiles) 'assets'],
          'createdAtUtc': receipt.createdAtUtc.toIso8601String(),
          'database': {
            'state': 'file',
            'path': 'database/kelivo.db',
            'descriptor': {'bytes': 7, 'sha256': _hashA},
          },
          'assets': restoreFiles
              ? {
                  'roots': {
                    'upload': 'directory',
                    'images': 'missing',
                    'avatars': 'missing',
                    'fonts': 'missing',
                    'skills': 'missing',
                    'workspaces': 'missing',
                    'sessions': 'missing',
                  },
                  'entries': {
                    'upload/old.txt': {'bytes': 4, 'sha256': _hashC},
                  },
                }
              : null,
        });

        final restored = RestorePreviousPlan.fromJson(
          json,
          preparedReceipt: receipt,
        );

        expect(jsonEncode(restored.toJson()), jsonEncode(json));
        expect(restored.checksum, json['checksum']);
        if (restoreFiles) {
          final entry = restored.assets!.entries['upload/old.txt']!;
          expect(entry.type, RestoreAssetEntryType.file);
          expect(entry.file?.sha256, _hashC);
        }
        expect(
          () => RestorePreviousPlan.fromJson({
            ...json,
            'checksum': _hashA,
          }, preparedReceipt: receipt),
          throwsFormatException,
        );
        for (final invalidVersion in [1, 4, 2.0, '2']) {
          expect(
            () => RestorePreviousPlan.fromJson(
              _withChecksum({...json, 'formatVersion': invalidVersion}),
              preparedReceipt: receipt,
            ),
            throwsFormatException,
          );
        }
        if (restoreFiles) {
          expect(
            () => RestorePreviousPlan.fromJson(
              _withChecksum({...json, 'formatVersion': 3}),
              preparedReceipt: receipt,
            ),
            throwsFormatException,
          );
          ((json['assets'] as Map)['entries'] as Map)['upload/old.txt'] = {
            'type': 'file',
            'descriptor': {'bytes': 4, 'sha256': _hashC},
          };
          expect(
            () => RestorePreviousPlan.fromJson(
              _withChecksum(json),
              preparedReceipt: receipt,
            ),
            throwsFormatException,
          );
        }
      });
    }

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
            'skills': RestorePreviousAssetRootState.missing,
            'workspaces': RestorePreviousAssetRootState.missing,
            'sessions': RestorePreviousAssetRootState.missing,
          },
          entries: const {
            'upload/note.txt': RestoreAssetDescriptor.file(
              RestoreFileDescriptor(bytes: 4, sha256: _hashC),
            ),
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

    test(
      'round trips typed local entries and binds link targets to the checksum',
      () {
        final receipt = _preparedReceipt(restoreFiles: true);
        final plan = RestorePreviousPlan.forPreparedReceipt(
          receipt: receipt,
          database: RestorePreviousDatabasePlan.missing(),
          assets: RestorePreviousAssetsPlan(
            rootStates: const {
              'workspaces': RestorePreviousAssetRootState.directory,
            },
            entries: const {
              'workspaces/file': RestoreAssetDescriptor.file(
                RestoreFileDescriptor(bytes: 4, sha256: _hashC),
              ),
              'workspaces/link': RestoreAssetDescriptor.link('../external'),
              'workspaces/pipe': RestoreAssetDescriptor.pipe(),
              'workspaces/socket': RestoreAssetDescriptor.socket(),
            },
          ),
        );
        final restored = RestorePreviousPlan.fromJson(
          plan.toJson(),
          preparedReceipt: receipt,
        );
        expect(restored.toJson(), plan.toJson());
        for (final entry in plan.assets!.entries.entries) {
          expect(
            entry.value.matches(restored.assets!.entries[entry.key]),
            isTrue,
          );
        }
        final json = plan.toJson();
        (((json['assets'] as Map)['entries'] as Map)['workspaces/link']
                as Map)['target'] =
            '../changed';
        expect(
          () => RestorePreviousPlan.fromJson(json, preparedReceipt: receipt),
          throwsFormatException,
        );
      },
    );

    test('rejects malformed or unrecognized local entry descriptors', () {
      for (final descriptor in [
        {'type': 'directory'},
        {'type': 'link'},
        {'type': 'link', 'target': null},
        {'type': 'link', 'target': ''},
        {'type': 'link', 'target': 'bad\u0000target'},
        {'type': 'pipe', 'target': 'unexpected'},
        {'type': 'socket', 'descriptor': <String, dynamic>{}},
        {
          'type': 'file',
          'descriptor': {'bytes': -1, 'sha256': _hashA},
        },
      ]) {
        expect(
          () => RestoreAssetDescriptor.fromJson(descriptor, 'upload/entry'),
          throwsFormatException,
          reason: '$descriptor',
        );
      }
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
              'skills': RestorePreviousAssetRootState.missing,
              'workspaces': RestorePreviousAssetRootState.missing,
              'sessions': RestorePreviousAssetRootState.missing,
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
            'skills': RestorePreviousAssetRootState.directory,
            'workspaces': RestorePreviousAssetRootState.directory,
            'sessions': RestorePreviousAssetRootState.directory,
          },
          entries: const {
            'upload/../secret': RestoreAssetDescriptor.file(
              RestoreFileDescriptor(bytes: 1, sha256: _hashA),
            ),
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
