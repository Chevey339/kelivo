import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/backup/backup_settings_validator.dart';

void main() {
  group('BackupSettingsValidator', () {
    test(
      'validates portable environment variable names, values and duplicates',
      () {
        void validate(Object value) => BackupSettingsValidator.validate({
          'environment_variables_v1': value,
        });
        expect(
          () => validate(
            jsonEncode([
              {'name': 'API_KEY', 'value': 'secret', 'note': ''},
            ]),
          ),
          returnsNormally,
        );
        for (final value in <Object>[
          true,
          '{}',
          '[1]',
          jsonEncode([
            {'name': '1INVALID', 'value': 'secret'},
          ]),
          jsonEncode([
            {'name': 'VALID', 'value': 3},
          ]),
          jsonEncode([
            {'name': 'VALID', 'value': ''},
          ]),
          jsonEncode([
            {'name': 'VALID', 'value': 'bad\u0000value'},
          ]),
          jsonEncode([
            {'name': 'VALID', 'value': 'ok', 'note': 3},
          ]),
          jsonEncode([
            {'name': 'SAME', 'value': 'first'},
            {'name': 'SAME', 'value': 'second'},
          ]),
        ]) {
          expect(() => validate(value), throwsFormatException);
        }
      },
    );

    test('requires a string for the page reading setting', () {
      for (final value in ['follow', 'local', 'off', 'configured-service-id']) {
        expect(
          () =>
              BackupSettingsValidator.validate({'search_web_fetch_v1': value}),
          returnsNormally,
        );
      }
      for (final value in [
        true,
        3,
        1.5,
        ['follow'],
      ]) {
        expect(
          () =>
              BackupSettingsValidator.validate({'search_web_fetch_v1': value}),
          throwsFormatException,
        );
      }
    });
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

    test('portable ASR export contains cloud providers only', () {
      final settings = <String, dynamic>{
        'asr_services_v1': jsonEncode([
          {'id': 'system', 'kind': 'system'},
          {
            'id': 'local',
            'kind': 'sherpa_onnx',
            'modelDirectory': '/device/sandbox/model',
          },
          {'id': 'openai', 'kind': 'openai_realtime'},
          {'id': 'step', 'kind': 'step'},
        ]),
        'asr_selected_service_id_v1': 'local',
      };

      BackupSettingsValidator.retainCloudAsrForExport(settings);

      final services =
          jsonDecode(settings['asr_services_v1'] as String) as List;
      expect(services.map((entry) => (entry as Map)['id']), ['openai', 'step']);
      expect(settings, isNot(contains('asr_selected_service_id_v1')));
    });
  });
}
