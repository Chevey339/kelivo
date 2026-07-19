import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/backup/backup_settings_validator.dart';

void main() {
  group('BackupSettingsValidator', () {
    test('normalizes legacy string lists before validating', () {
      final settings = <String, dynamic>{
        'pinned_models_v1': jsonEncode(['provider/model']),
        'providers_order_v1': jsonEncode(['provider']),
        'provider_configs_v1': jsonEncode({
          'provider': {'name': 'Provider'},
        }),
      };

      BackupSettingsValidator.normalizeAndValidate(settings);

      expect(settings['pinned_models_v1'], ['provider/model']);
      expect(settings['providers_order_v1'], ['provider']);
    });

    test('accepts supported preference values and ignores local-only keys', () {
      expect(
        BackupSettingsValidator.isLocalOnly('flutter_log_enabled_v1'),
        isTrue,
      );
      expect(
        () => BackupSettingsValidator.validate({
          'bool': true,
          'int': 1,
          'double': 1.5,
          'string': 'value',
          'list': ['a', 'b'],
          'window_width_v1': {'not': 'persistable'},
          'flutter_log_enabled_v1': {'not': 'persistable'},
          'restore_future_marker': {'not': 'persistable'},
          'pinned_chat_ids': {'not': 'persistable'},
          'provider_configs_backup_v1': {'not': 'persistable'},
        }),
        returnsNormally,
      );
      expect(BackupSettingsValidator.isDiscarded('pinned_chat_ids'), isTrue);
    });

    test('rejects malformed structured settings and unsupported values', () {
      expect(
        () => BackupSettingsValidator.validate({
          'assistants_v1': jsonEncode(['not-an-object']),
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => BackupSettingsValidator.validate({
          'provider_group_collapsed_v1': jsonEncode({'group': 'yes'}),
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => BackupSettingsValidator.validate({
          'unsupported': {'value': true},
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects malformed legacy string lists', () {
      expect(
        () => BackupSettingsValidator.normalizeLegacyStringLists({
          'pinned_models_v1': jsonEncode([1]),
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
