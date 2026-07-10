import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/services/backup/backup_settings_sanitizer.dart';
import 'package:Kelivo/core/services/backup/restore_settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RestoreSettingsStore', () {
    late SharedPreferences preferences;
    late RestoreSettingsStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'theme': 'old',
        'keep_me': 7,
        'window_width_v1': 900.0,
        'old_api_key_v1': 'old-secret',
      });
      preferences = await SharedPreferences.getInstance();
      store = RestoreSettingsStore(preferences);
    });

    test('applies and reload-verifies a secret-free transition', () async {
      final candidate = BackupSettingsSanitizer.sanitize({
        'theme': 'new',
        'new_key': true,
        'provider_api_key_v1': 'candidate-secret',
      });
      final transition = await store.buildTransition(
        candidateSettings: candidate,
        secretsIncluded: false,
      );

      await store.validateBefore(transition);
      await store.apply(transition);
      await store.validateTarget(transition);
      await preferences.reload();

      expect(preferences.getString('theme'), 'new');
      expect(preferences.getBool('new_key'), isTrue);
      expect(preferences.getString('provider_api_key_v1'), '');
      expect(preferences.containsKey('old_api_key_v1'), isFalse);
      expect(preferences.getInt('keep_me'), 7);
      expect(preferences.getDouble('window_width_v1'), 900.0);
      await store.apply(transition);
    });

    test('rolls an applied transition back to values and tombstones', () async {
      await preferences.setStringList('models', ['a']);
      final transition = await store.buildTransition(
        candidateSettings: const {
          'theme': 'new',
          'new_key': true,
          'models': ['b'],
        },
        secretsIncluded: true,
      );
      await store.apply(transition);

      await store.rollback(transition);
      await preferences.reload();

      expect(preferences.getString('theme'), 'old');
      expect(preferences.containsKey('new_key'), isFalse);
      expect(preferences.getStringList('models'), ['a']);
      expect(preferences.getInt('keep_me'), 7);
      expect(preferences.getDouble('window_width_v1'), 900.0);
    });

    test(
      'resumes when only part of the target projection is applied',
      () async {
        final transition = await store.buildTransition(
          candidateSettings: const {'theme': 'new', 'new_key': true},
          secretsIncluded: true,
        );
        await preferences.setString('theme', 'new');

        await store.apply(transition);

        expect(preferences.getString('theme'), 'new');
        expect(preferences.getBool('new_key'), isTrue);
      },
    );

    test('serializes concurrent apply and rollback operations', () async {
      final transition = await store.buildTransition(
        candidateSettings: const {'theme': 'new', 'new_key': true},
        secretsIncluded: true,
      );

      await Future.wait([store.apply(transition), store.rollback(transition)]);
      await preferences.reload();

      expect(preferences.getString('theme'), 'old');
      expect(preferences.containsKey('new_key'), isFalse);
    });

    test('rejects an unrelated mutation in a touched key', () async {
      final transition = await store.buildTransition(
        candidateSettings: const {'theme': 'new'},
        secretsIncluded: true,
      );
      await preferences.setString('theme', 'external');

      await expectLater(store.apply(transition), throwsStateError);

      expect(preferences.getString('theme'), 'external');
    });

    test('reports target, before, and recoverable partial readback', () async {
      final transition = await store.buildTransition(
        candidateSettings: const {'theme': 'new', 'new_key': true},
        secretsIncluded: true,
      );

      expect(
        await store.inspectReadback(
          transition: transition,
          expected: RestoreSettingsExpectedProjection.before,
        ),
        RestoreSettingsReadback.expected,
      );
      await preferences.setString('theme', 'new');
      expect(
        await store.inspectReadback(
          transition: transition,
          expected: RestoreSettingsExpectedProjection.target,
        ),
        RestoreSettingsReadback.recoverableNeedsWrite,
      );
      await store.apply(transition);
      expect(
        await store.inspectReadback(
          transition: transition,
          expected: RestoreSettingsExpectedProjection.target,
        ),
        RestoreSettingsReadback.expected,
      );
    });

    test(
      'readback rejects a divergent touched value without writing',
      () async {
        final transition = await store.buildTransition(
          candidateSettings: const {'theme': 'new'},
          secretsIncluded: true,
        );
        await preferences.setString('theme', 'external');

        await expectLater(
          store.inspectReadback(
            transition: transition,
            expected: RestoreSettingsExpectedProjection.target,
          ),
          throwsStateError,
        );
        expect(preferences.getString('theme'), 'external');
      },
    );

    test('returns defensive copies from fresh reads', () async {
      await preferences.setStringList('models', ['a']);

      final values = await store.readAll();
      (values['models'] as List<String>).add('b');
      final reread = await store.readAll();

      expect(reread['models'], ['a']);
    });
  });
}
