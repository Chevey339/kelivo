import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'backup_settings_sanitizer.dart';
import 'backup_settings_validator.dart';
import 'restore_previous_plan.dart';

/// Immutable settings delta used by the startup restore state machine.
///
/// It preserves the existing overwrite compatibility boundary: imported keys
/// replace matching non-local keys, unrelated keys remain untouched, and a
/// secret-free bundle additionally removes known target credentials.
final class RestoreSettingsTransition {
  RestoreSettingsTransition._({
    required this.plan,
    required List<int> snapshotBytes,
    required Map<String, dynamic> valuesToSet,
    required Set<String> keysToRemove,
  }) : snapshotBytes = List.unmodifiable(snapshotBytes),
       valuesToSet = Map.unmodifiable(valuesToSet),
       keysToRemove = Set.unmodifiable(keysToRemove);

  final RestorePreviousSettingsPlan plan;
  final List<int> snapshotBytes;
  final Map<String, dynamic> valuesToSet;
  final Set<String> keysToRemove;

  factory RestoreSettingsTransition.build({
    required Map<String, dynamic> currentSettings,
    required Map<String, dynamic> candidateSettings,
    required bool secretsIncluded,
  }) {
    final candidate = Map<String, dynamic>.from(candidateSettings);
    BackupSettingsValidator.normalizeAndValidate(candidate);
    if (!secretsIncluded) {
      BackupSettingsSanitizer.validateSecretFree(candidate);
    }

    final candidateValues = <String, dynamic>{};
    for (final key in (candidate.keys.toList()..sort())) {
      if (!BackupSettingsValidator.isLocalOnly(key)) {
        candidateValues[key] = _freezePreferenceValue(candidate[key]);
      }
    }
    final touchedKeys = candidateValues.keys.toSet();
    if (!secretsIncluded) {
      touchedKeys.addAll(
        currentSettings.keys.where(
          (key) =>
              !BackupSettingsValidator.isLocalOnly(key) &&
              BackupSettingsSanitizer.shouldClearBeforeSecretFreeOverwrite(key),
        ),
      );
    }

    final snapshotValues = <String, dynamic>{};
    for (final key in (touchedKeys.toList()..sort())) {
      if (currentSettings.containsKey(key)) {
        final value = currentSettings[key];
        BackupSettingsValidator.validateValue(key, value);
        snapshotValues[key] = _freezePreferenceValue(value);
      }
    }
    BackupSettingsValidator.validate(snapshotValues);
    final missingKeys = touchedKeys.difference(snapshotValues.keys.toSet());
    final keysToRemove = touchedKeys.difference(candidateValues.keys.toSet());
    final snapshotBytes = utf8.encode(jsonEncode(snapshotValues));
    final settingsPlan = RestorePreviousSettingsPlan(
      snapshot: RestoreFileDescriptor(
        bytes: snapshotBytes.length,
        sha256: sha256.convert(snapshotBytes).toString(),
      ),
      beforeFingerprint: RestorePreviousSettingsPlan.fingerprintProjection(
        snapshotValues,
        touchedKeys,
      ),
      targetFingerprint: RestorePreviousSettingsPlan.fingerprintProjection(
        candidateValues,
        touchedKeys,
      ),
      touchedKeys: touchedKeys,
      missingKeys: missingKeys,
    );
    settingsPlan.validateSnapshotBytes(snapshotBytes);
    settingsPlan.validateTargetProjection(candidateValues);
    return RestoreSettingsTransition._(
      plan: settingsPlan,
      snapshotBytes: snapshotBytes,
      valuesToSet: candidateValues,
      keysToRemove: keysToRemove,
    );
  }

  factory RestoreSettingsTransition.resume({
    required RestorePreviousSettingsPlan plan,
    required List<int> snapshotBytes,
    required Map<String, dynamic> candidateSettings,
    required bool secretsIncluded,
  }) {
    plan.validateSnapshotBytes(snapshotBytes);
    final candidate = Map<String, dynamic>.from(candidateSettings);
    BackupSettingsValidator.normalizeAndValidate(candidate);
    if (!secretsIncluded) {
      BackupSettingsSanitizer.validateSecretFree(candidate);
    }
    final candidateValues = <String, dynamic>{};
    for (final key in (candidate.keys.toList()..sort())) {
      if (!BackupSettingsValidator.isLocalOnly(key)) {
        candidateValues[key] = _freezePreferenceValue(candidate[key]);
      }
    }
    plan.validateTargetProjection(candidateValues);
    return RestoreSettingsTransition._(
      plan: plan,
      snapshotBytes: snapshotBytes,
      valuesToSet: candidateValues,
      keysToRemove: plan.touchedKeys.difference(candidateValues.keys.toSet()),
    );
  }
}

dynamic _freezePreferenceValue(dynamic value) {
  if (value is List) return List<String>.unmodifiable(value.cast<String>());
  return value;
}
