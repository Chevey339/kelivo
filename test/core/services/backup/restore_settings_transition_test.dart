import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/backup/backup_settings_sanitizer.dart';
import 'package:Kelivo/core/services/backup/restore_settings_transition.dart';

void main() {
  group('RestoreSettingsTransition', () {
    test('builds an exact secret-free touched-key transition', () {
      final current = <String, dynamic>{
        'theme': 'old',
        'keep_me': 7,
        'window_width_v1': 900.0,
        'old_api_key_v1': 'old-secret',
        'provider_configs_backup_v1': 'legacy-secret-cache',
      };
      final candidate = BackupSettingsSanitizer.sanitize({
        'theme': 'new',
        'new_key': true,
        'provider_api_key_v1': 'candidate-secret',
      });

      final transition = RestoreSettingsTransition.build(
        currentSettings: current,
        candidateSettings: candidate,
        secretsIncluded: false,
      );

      expect(transition.valuesToSet, candidate);
      expect(transition.keysToRemove, {
        'old_api_key_v1',
        'provider_configs_backup_v1',
      });
      expect(transition.plan.touchedKeys, {
        ...candidate.keys,
        'old_api_key_v1',
        'provider_configs_backup_v1',
      });
      expect(
        transition.plan.missingKeys,
        candidate.keys.where((key) => key != 'theme').toSet(),
      );
      expect(jsonDecode(utf8.decode(transition.snapshotBytes)), {
        'old_api_key_v1': 'old-secret',
        'provider_configs_backup_v1': 'legacy-secret-cache',
        'theme': 'old',
      });
      expect(transition.plan.validateSnapshotBytes(transition.snapshotBytes), {
        'old_api_key_v1': 'old-secret',
        'provider_configs_backup_v1': 'legacy-secret-cache',
        'theme': 'old',
      });
      expect(current['keep_me'], 7);
      expect(current['window_width_v1'], 900.0);
    });

    test('rejects a secret-free candidate that still contains credentials', () {
      expect(
        () => RestoreSettingsTransition.build(
          currentSettings: const {},
          candidateSettings: const {'provider_api_key_v1': 'secret'},
          secretsIncluded: false,
        ),
        throwsFormatException,
      );
    });

    test(
      'does not clear absent credentials from a secret-including bundle',
      () {
        final transition = RestoreSettingsTransition.build(
          currentSettings: const {
            'theme': 'old',
            'provider_api_key_v1': 'keep-secret',
          },
          candidateSettings: const {'theme': 'new'},
          secretsIncluded: true,
        );

        expect(transition.plan.touchedKeys, {'theme'});
        expect(transition.valuesToSet, {'theme': 'new'});
        expect(transition.keysToRemove, isEmpty);
      },
    );

    test('produces canonical output independent of source map order', () {
      final first = RestoreSettingsTransition.build(
        currentSettings: const {'b': 2, 'a': 1},
        candidateSettings: const {'b': 4, 'a': 3},
        secretsIncluded: true,
      );
      final second = RestoreSettingsTransition.build(
        currentSettings: const {'a': 1, 'b': 2},
        candidateSettings: const {'a': 3, 'b': 4},
        secretsIncluded: true,
      );

      expect(second.snapshotBytes, first.snapshotBytes);
      expect(second.plan.beforeFingerprint, first.plan.beforeFingerprint);
      expect(second.plan.targetFingerprint, first.plan.targetFingerprint);
    });

    test('does not retain mutable string-list aliases', () {
      final models = <String>['provider/model-a'];
      final transition = RestoreSettingsTransition.build(
        currentSettings: const {},
        candidateSettings: {'pinned_models_v1': models},
        secretsIncluded: true,
      );

      models.add('provider/model-b');

      expect(transition.valuesToSet['pinned_models_v1'], ['provider/model-a']);
      expect(
        () => (transition.valuesToSet['pinned_models_v1'] as List<String>).add(
          'provider/model-c',
        ),
        throwsUnsupportedError,
      );
    });

    test('rejects malformed structured values before building a plan', () {
      expect(
        () => RestoreSettingsTransition.build(
          currentSettings: const {},
          candidateSettings: const {'assistants_v1': '["invalid"]'},
          secretsIncluded: true,
        ),
        throwsFormatException,
      );
      expect(
        () => RestoreSettingsTransition.build(
          currentSettings: const {
            'provider_configs_v1': '{"provider":"invalid"}',
          },
          candidateSettings: const {'provider_configs_v1': '{}'},
          secretsIncluded: true,
        ),
        throwsFormatException,
      );
    });

    test('rebuilds the same transition from a durable previous plan', () {
      final candidate = BackupSettingsSanitizer.sanitize({
        'theme': 'new',
        'provider_api_key_v1': 'candidate-secret',
      });
      final initial = RestoreSettingsTransition.build(
        currentSettings: const {'theme': 'old', 'old_api_key_v1': 'old-secret'},
        candidateSettings: candidate,
        secretsIncluded: false,
      );

      final resumed = RestoreSettingsTransition.resume(
        plan: initial.plan,
        snapshotBytes: initial.snapshotBytes,
        candidateSettings: candidate,
        secretsIncluded: false,
      );

      expect(resumed.plan, same(initial.plan));
      expect(resumed.snapshotBytes, initial.snapshotBytes);
      expect(resumed.valuesToSet, initial.valuesToSet);
      expect(resumed.keysToRemove, initial.keysToRemove);
    });

    test('rejects a resumed candidate that differs from the frozen target', () {
      final initial = RestoreSettingsTransition.build(
        currentSettings: const {'theme': 'old'},
        candidateSettings: const {'theme': 'new'},
        secretsIncluded: true,
      );

      expect(
        () => RestoreSettingsTransition.resume(
          plan: initial.plan,
          snapshotBytes: initial.snapshotBytes,
          candidateSettings: const {'theme': 'changed'},
          secretsIncluded: true,
        ),
        throwsFormatException,
      );
    });
  });
}
