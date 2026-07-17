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

RestorePreviousSettingsPlan _settingsPlan() {
  return RestorePreviousSettingsPlan(
    snapshot: const RestoreFileDescriptor(bytes: 18, sha256: _hashA),
    beforeFingerprint: _hashB,
    targetFingerprint: _hashC,
    touchedKeys: {'theme', 'provider_api_key'},
    missingKeys: {'provider_api_key'},
  );
}

RestoreReceipt _preparedReceipt({
  bool restoreChats = false,
  bool restoreFiles = false,
  String candidateManifestSha256 = _hashB,
}) {
  return RestoreReceipt.prepared(
    runId: _runId,
    createdAtUtc: DateTime.utc(2026, 7, 9, 12),
    restoreChats: restoreChats,
    restoreFiles: restoreFiles,
    candidateManifestSha256: candidateManifestSha256,
  );
}

RestorePreviousPlan _settingsOnlyPlan() {
  return RestorePreviousPlan.forPreparedReceipt(
    receipt: _preparedReceipt(),
    settings: _settingsPlan(),
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
    test('round trips a canonical settings-only plan', () {
      final plan = _settingsOnlyPlan();

      final restored = RestorePreviousPlan.fromJson(
        plan.toJson(),
        preparedReceipt: _preparedReceipt(),
      );

      expect(restored.runId, _runId);
      expect(restored.selectedComponents, {RestoreComponent.settings});
      expect(restored.settings.touchedKeys, {'provider_api_key', 'theme'});
      expect(restored.settings.missingKeys, {'provider_api_key'});
      expect(restored.database, isNull);
      expect(restored.assets, isNull);
      expect(restored.checksum, plan.checksum);
    });

    test('preserves missing, empty, and populated previous objects', () {
      final plan = RestorePreviousPlan.forPreparedReceipt(
        receipt: _preparedReceipt(restoreChats: true, restoreFiles: true),
        settings: _settingsPlan(),
        database: RestorePreviousDatabasePlan.missing(),
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
        preparedReceipt: _preparedReceipt(
          restoreChats: true,
          restoreFiles: true,
        ),
      );

      expect(restored.database?.state, RestorePreviousDatabaseState.missing);
      expect(
        restored.assets?.rootStates['images'],
        RestorePreviousAssetRootState.directory,
      );
      expect(
        restored.assets?.rootStates['avatars'],
        RestorePreviousAssetRootState.missing,
      );
      expect(restored.assets?.entries.keys, ['upload/note.txt']);
    });

    test('rejects checksum changes and unknown fields', () {
      final json = _settingsOnlyPlan().toJson();

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
        () => RestorePreviousPlan.fromJson({
          ...json,
          'formatVersion': 1.0,
        }, preparedReceipt: _preparedReceipt()),
        throwsFormatException,
      );
    });

    test('rejects payloads inconsistent with selected components', () {
      expect(
        () => RestorePreviousPlan.forPreparedReceipt(
          receipt: _preparedReceipt(restoreChats: true),
          settings: _settingsPlan(),
        ),
        throwsArgumentError,
      );

      final json = _settingsOnlyPlan().toJson();
      final selected = (json['selectedComponents'] as List).cast<String>()
        ..add('database');
      expect(
        () => RestorePreviousPlan.fromJson(
          _withChecksum({...json, 'selectedComponents': selected}),
          preparedReceipt: _preparedReceipt(),
        ),
        throwsFormatException,
      );
    });

    test('binds the plan to one exact prepared receipt', () {
      final receipt = _preparedReceipt();
      final plan = RestorePreviousPlan.forPreparedReceipt(
        receipt: receipt,
        settings: _settingsPlan(),
      );

      expect(() => plan.validatePreparedReceipt(receipt), returnsNormally);
      expect(
        () => plan.validatePreparedReceipt(
          _preparedReceipt(candidateManifestSha256: _hashC),
        ),
        throwsStateError,
      );
    });

    test('verifies settings snapshot bytes, keys, and fingerprints', () {
      final beforeValues = <String, dynamic>{'theme': 'dark'};
      final targetValues = <String, dynamic>{'theme': 'light'};
      final touchedKeys = {'theme', 'provider_api_key'};
      final bytes = utf8.encode(jsonEncode(beforeValues));
      final settings = RestorePreviousSettingsPlan(
        snapshot: RestoreFileDescriptor(
          bytes: bytes.length,
          sha256: sha256.convert(bytes).toString(),
        ),
        beforeFingerprint: RestorePreviousSettingsPlan.fingerprintProjection(
          beforeValues,
          touchedKeys,
        ),
        targetFingerprint: RestorePreviousSettingsPlan.fingerprintProjection(
          targetValues,
          touchedKeys,
        ),
        touchedKeys: touchedKeys,
        missingKeys: {'provider_api_key'},
      );

      expect(settings.validateSnapshotBytes(bytes), beforeValues);
      expect(
        () => settings.validateTargetProjection(targetValues),
        returnsNormally,
      );
      expect(
        () => settings.validateSnapshotBytes(utf8.encode('{}')),
        throwsFormatException,
      );
      final emptyBytes = utf8.encode('{}');
      final missingRequiredValue = RestorePreviousSettingsPlan(
        snapshot: RestoreFileDescriptor(
          bytes: emptyBytes.length,
          sha256: sha256.convert(emptyBytes).toString(),
        ),
        beforeFingerprint: RestorePreviousSettingsPlan.fingerprintProjection(
          {},
          touchedKeys,
        ),
        targetFingerprint: settings.targetFingerprint,
        touchedKeys: touchedKeys,
        missingKeys: {'provider_api_key'},
      );
      expect(
        () => missingRequiredValue.validateSnapshotBytes(emptyBytes),
        throwsFormatException,
      );
      expect(
        () => settings.validateTargetProjection({'theme': 'changed'}),
        throwsFormatException,
      );
    });

    test('rejects unsafe assets and invalid settings tombstones', () {
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
        () => RestorePreviousSettingsPlan(
          snapshot: const RestoreFileDescriptor(bytes: 2, sha256: _hashA),
          beforeFingerprint: _hashB,
          targetFingerprint: _hashC,
          touchedKeys: {'theme'},
          missingKeys: {'not_touched'},
        ),
        throwsArgumentError,
      );
    });
  });
}
