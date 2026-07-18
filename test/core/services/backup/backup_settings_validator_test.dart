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
        () => BackupSettingsValidator.validate({
          'bool': true,
          'int': 1,
          'double': 1.5,
          'string': 'value',
          'list': ['a', 'b'],
          'window_width_v1': {'not': 'persistable'},
        }),
        returnsNormally,
      );
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

    test('merges multi-model selections and remaps only imported chats', () {
      String selections({
        required String scope,
        required Map<String, dynamic> assistants,
        required Map<String, dynamic> conversations,
        required Map<String, dynamic> nextMessages,
      }) => jsonEncode({
        'version': 1,
        'scope': scope,
        'assistants': assistants,
        'conversations': conversations,
        'nextMessages': nextMessages,
      });

      final localTargets = [
        {'providerKey': 'local', 'modelId': 'one'},
        {'providerKey': 'local', 'modelId': 'two'},
      ];
      final importedTargets = [
        {'providerKey': 'remote', 'modelId': 'one'},
        {'providerKey': 'remote', 'modelId': 'two'},
      ];
      final merged =
          jsonDecode(
                BackupSettingsValidator.mergeChatModelSelectionsForRestore(
                  existingValue: selections(
                    scope: 'conversation',
                    assistants: {'same-assistant': localTargets},
                    conversations: {'collision': localTargets},
                    nextMessages: {'local-next': localTargets},
                  ),
                  incomingValue: selections(
                    scope: 'nextMessage',
                    assistants: {'same-assistant': importedTargets},
                    conversations: {'collision': importedTargets},
                    nextMessages: {'incoming-next': importedTargets},
                  ),
                  remappedConversationIds: {
                    'collision': 'imported-copy',
                    'incoming-next': 'remapped-next',
                  },
                ),
              )
              as Map<String, dynamic>;

      expect(merged['scope'], 'conversation');
      expect(merged['assistants']['same-assistant'], localTargets);
      expect(merged['conversations']['collision'], localTargets);
      expect(merged['conversations']['imported-copy'], importedTargets);
      expect(merged['nextMessages']['local-next'], localTargets);
      expect(merged['nextMessages']['remapped-next'], importedTargets);
    });

    test('rejects malformed multi-model selection targets', () {
      expect(
        () => BackupSettingsValidator.validate({
          'chat_model_selections_v1': jsonEncode({
            'scope': 'conversation',
            'conversations': {
              'conversation': [
                {'providerKey': 'provider', 'modelId': 'only-one'},
              ],
            },
          }),
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects unknown multi-model selection storage versions', () {
      expect(
        () => BackupSettingsValidator.validate({
          'chat_model_selections_v1': jsonEncode({
            'version': 2,
            'scope': 'conversation',
            'conversations': {
              'conversation': [
                {'providerKey': 'provider', 'modelId': 'one'},
                {'providerKey': 'provider', 'modelId': 'two'},
              ],
            },
          }),
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
