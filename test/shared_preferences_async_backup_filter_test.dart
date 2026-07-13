import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/backup.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/backup/backup_settings_sanitizer.dart';
import 'package:Kelivo/core/services/backup/data_sync.dart' as backup_sync;
import 'package:Kelivo/core/services/search/search_service.dart';
import 'package:Kelivo/core/services/tts/network_tts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPreferencesAsync backup filter', () {
    test('snapshot excludes local-only chat font scale', () async {
      SharedPreferences.setMockInitialValues({
        'display_chat_font_scale_v1': 1.3,
        'display_auto_scroll_enabled_v1': false,
        'desktop_hotkeys_commands_v1': [
          'close_window=cmd+w',
          'open_settings=cmd+comma',
        ],
        'desktop_hotkeys_enabled_v1': ['close_window=1', 'open_settings=1'],
      });

      final prefs = await backup_sync.SharedPreferencesAsync.instance;
      final snapshot = await prefs.snapshot();

      expect(snapshot.containsKey('display_chat_font_scale_v1'), isFalse);
      expect(snapshot.containsKey('desktop_hotkeys_commands_v1'), isFalse);
      expect(snapshot.containsKey('desktop_hotkeys_enabled_v1'), isFalse);
      expect(snapshot['display_auto_scroll_enabled_v1'], isFalse);
    });

    test(
      'regular backup snapshot includes credentials for full restore',
      () async {
        const secretMarkers = [
          'provider-api-secret',
          'provider-url-password',
          'provider-url-api-secret',
          'service-account-secret',
          'provider-proxy-secret',
          'multi-key-secret',
          'override-header-secret',
          'override-x-auth-secret',
          'override-body-secret',
          'provider-backup-secret',
          'search-api-secret',
          'search-password-secret',
          'search-url-userinfo-secret',
          'search-url-query-secret',
          'search-url-fragment-secret',
          'tts-api-secret',
          'mcp-header-secret',
          'mcp-x-authorization-secret',
          'mcp-arg-secret',
          'mcp-arg-access-secret',
          'mcp-env-secret',
          'mcp-env-access-secret',
          'mcp-env-service-account-secret',
          'webdav-password-secret',
          'webdav-url-password',
          'webdav-url-token',
          's3-access-secret',
          's3-secret-secret',
          's3-session-secret',
          's3-signature-secret',
          'assistant-header-secret',
          'assistant-body-secret',
          'assistant-credentials-secret',
          'assistant-passphrase-secret',
          'global-proxy-secret',
          'future-token-secret',
          'future-camel-token-secret',
          'future-provider-api-secret',
        ];
        SharedPreferences.setMockInitialValues({
          'safe_setting_v1': 'safe-value',
          'display_show_token_stats_v1': true,
          'global_proxy_password_v1': 'global-proxy-secret',
          'future_auth_token_v2': 'future-token-secret',
          'futureAuthToken_v2': 'future-camel-token-secret',
          'provider_configs_v1': jsonEncode({
            'openai': {
              'id': 'provider-openai',
              'name': 'Safe Provider',
              'apiKey': 'provider-api-secret',
              'baseUrl':
                  'https://safe-user:provider-url-password@safe.example/v1'
                  '?api_key=provider-url-api-secret&api-version=2026-01-01',
              'serviceAccountJson': 'service-account-secret',
              'proxyPassword': 'provider-proxy-secret',
              'apiKeys': [
                {
                  'id': 'key-1',
                  'key': 'multi-key-secret',
                  'name': 'Safe key label',
                },
              ],
              'modelOverrides': {
                'safe-model': {
                  'apiModelId': 'safe-upstream-model',
                  'headers': [
                    {
                      'name': 'Authorization',
                      'value': 'override-header-secret',
                    },
                    {'name': 'X-Auth', 'value': 'override-x-auth-secret'},
                    {
                      'name': 'Idempotency-Key',
                      'value': 'safe-idempotency-key',
                    },
                    {'name': 'X-Title', 'value': 'safe-model-title'},
                  ],
                  'body': [
                    {'key': 'token', 'value': 'override-body-secret'},
                    {'key': 'publicKey', 'value': 'safe-public-key-body'},
                    {'key': 'temperature', 'value': '0.3'},
                  ],
                },
                'token': {'apiModelId': 'safe-token-model'},
              },
            },
            'token': {
              'id': 'provider-named-token',
              'name': 'Provider Named Token',
              'apiKey': '',
              'baseUrl': 'https://token-provider.example',
            },
            'KelivoIN': {
              'id': 'KelivoIN',
              'name': 'KelivoIN',
              'apiKey': 'kelivo',
              'baseUrl': 'https://text.pollinations.ai/openai',
            },
          }),
          'provider_configs_v2': jsonEncode({
            'future': {
              'id': 'future',
              'name': 'Future Provider',
              'apiKey': 'future-provider-api-secret',
              'baseUrl': 'https://future.example',
            },
          }),
          'provider_configs_backup_v1': jsonEncode({
            'openai': {
              'id': 'provider-backup',
              'name': 'Safe Backup Provider',
              'apiKey': 'provider-backup-secret',
              'baseUrl': 'https://backup.example',
            },
          }),
          'search_services_v1': jsonEncode([
            {
              'type': 'tavily',
              'id': 'safe-search',
              'apiKey': 'search-api-secret',
            },
            {
              'type': 'searxng',
              'id': 'safe-searxng',
              'url':
                  'https://search-url-userinfo-secret@search.example'
                  '?subscription-key=search-url-query-secret'
                  '#access_token=search-url-fragment-secret',
              'username': 'safe-user',
              'password': 'search-password-secret',
            },
          ]),
          'tts_services_v1': jsonEncode([
            {
              'kind': 'openai',
              'id': 'safe-tts',
              'name': 'Safe TTS',
              'apiKey': 'tts-api-secret',
            },
          ]),
          'mcp_servers_v1': jsonEncode([
            {
              'id': 'safe-mcp',
              'name': 'Safe MCP',
              'transport': 'stdio',
              'command': 'safe-command',
              'args': [
                '-y',
                'safe-mcp-package',
                '--token',
                'mcp-arg-secret',
                '--aws-access-key-id',
                'mcp-arg-access-secret',
                '--public-key',
                'safe-public-arg',
              ],
              'env': {
                'MCP_TOKEN': 'mcp-env-secret',
                'AWS_ACCESS_KEY_ID': 'mcp-env-access-secret',
                'GCP_SERVICE_ACCOUNT_JSON': 'mcp-env-service-account-secret',
                'PUBLIC_KEY': 'safe-public-env',
                'SAFE_PATH': '/safe/path',
              },
              'headers': {
                'Authorization': 'mcp-header-secret',
                'X-Authorization': 'mcp-x-authorization-secret',
                'Idempotency-Key': 'safe-idempotency-key',
                'Sec-WebSocket-Key': 'safe-websocket-key',
                'X-Title': 'safe-mcp-title',
              },
              'tools': [
                {
                  'name': 'safe-schema-tool',
                  'schema': {
                    'type': 'object',
                    'properties': {
                      'headers': {'type': 'object'},
                      'body': {'type': 'object'},
                      'token': {'type': 'string'},
                    },
                  },
                },
              ],
            },
          ]),
          'webdav_config_v1': jsonEncode({
            'url':
                'https://safe-webdav-user:webdav-url-password@webdav.example'
                '?access_token=webdav-url-token&folder=safe-folder',
            'username': 'safe-webdav-user',
            'password': 'webdav-password-secret',
          }),
          's3_config_v1': jsonEncode({
            'endpoint':
                'https://s3.example?X-Amz-Signature=s3-signature-secret'
                '&region=safe-region',
            'bucket': 'safe-bucket',
            'accessKeyId': 's3-access-secret',
            'secretAccessKey': 's3-secret-secret',
            'sessionToken': 's3-session-secret',
          }),
          'assistants_v1': jsonEncode([
            {
              'id': 'safe-assistant',
              'name': 'Safe Assistant',
              'systemPrompt': 'safe prompt',
              'customHeaders': [
                {'name': 'Authorization', 'value': 'assistant-header-secret'},
                {
                  'name': 'Proxy-Authorization',
                  'value': 'assistant-passphrase-secret',
                },
                {'name': 'X-Title', 'value': 'safe-assistant-title'},
              ],
              'customBody': [
                {'key': 'token', 'value': 'assistant-body-secret'},
                {'key': 'credentials', 'value': 'assistant-credentials-secret'},
                {'key': 'passphrase', 'value': 'assistant-passphrase-secret'},
                {'key': 'publicKey', 'value': 'safe-assistant-public-key'},
                {'key': 'temperature', 'value': '0.5'},
              ],
            },
          ]),
        });

        final prefs = await backup_sync.SharedPreferencesAsync.instance;
        final migrationSnapshot = await prefs.snapshot();
        final backupSnapshot = await prefs.snapshotForRegularBackup();
        final regularBackupSnapshot = BackupSettingsSanitizer.sanitize(
          migrationSnapshot,
        );
        final migrationJson = jsonEncode(migrationSnapshot);
        final regularBackupJson = jsonEncode(backupSnapshot);

        for (final marker in secretMarkers) {
          expect(migrationJson, contains(marker));
          expect(regularBackupJson, contains(marker));
        }
        expect(regularBackupSnapshot['safe_setting_v1'], 'safe-value');
        expect(regularBackupSnapshot['display_show_token_stats_v1'], isTrue);
        expect(regularBackupSnapshot['global_proxy_password_v1'], '');
        expect(regularBackupSnapshot['future_auth_token_v2'], '');
        expect(regularBackupSnapshot['futureAuthToken_v2'], '');
        expect(
          regularBackupSnapshot.containsKey('provider_configs_backup_v1'),
          isFalse,
        );

        final providers =
            jsonDecode(regularBackupSnapshot['provider_configs_v1'] as String)
                as Map<String, dynamic>;
        final provider = providers['openai'] as Map<String, dynamic>;
        expect(provider['name'], 'Safe Provider');
        final providerUri = Uri.parse(provider['baseUrl'] as String);
        expect(providerUri.userInfo, isEmpty);
        expect(providerUri.queryParameters['api_key'], '');
        expect(providerUri.queryParameters['api-version'], '2026-01-01');
        expect(provider['apiKey'], '');
        expect(provider['serviceAccountJson'], '');
        expect(provider['proxyPassword'], '');
        final apiKeys = provider['apiKeys'] as List;
        expect(apiKeys, hasLength(1));
        expect((apiKeys.single as Map)['id'], 'key-1');
        expect((apiKeys.single as Map)['name'], 'Safe key label');
        expect((apiKeys.single as Map)['key'], '');
        final modelOverrides = provider['modelOverrides'] as Map;
        final modelOverride = modelOverrides['safe-model'] as Map;
        expect(modelOverride['apiModelId'], 'safe-upstream-model');
        final overrideHeaders = modelOverride['headers'] as List;
        final overrideHeadersByName = {
          for (final item in overrideHeaders)
            (item as Map)['name']: item['value'],
        };
        expect(overrideHeadersByName['Authorization'], '');
        expect(overrideHeadersByName['X-Auth'], '');
        expect(
          overrideHeadersByName['Idempotency-Key'],
          'safe-idempotency-key',
        );
        expect(overrideHeadersByName['X-Title'], 'safe-model-title');
        final overrideBody = modelOverride['body'] as List;
        final overrideBodyByKey = {
          for (final item in overrideBody) (item as Map)['key']: item['value'],
        };
        expect(overrideBodyByKey['token'], '');
        expect(overrideBodyByKey['publicKey'], 'safe-public-key-body');
        expect(overrideBodyByKey['temperature'], '0.3');
        expect(
          (modelOverrides['token'] as Map)['apiModelId'],
          'safe-token-model',
        );
        expect((providers['token'] as Map)['name'], 'Provider Named Token');
        final kelivoInJson = (providers['KelivoIN'] as Map)
            .cast<String, dynamic>();
        expect(kelivoInJson['apiKey'], '');
        expect(ProviderConfig.fromJson(kelivoInJson).apiKey, 'kelivo');
        final futureProviders =
            jsonDecode(regularBackupSnapshot['provider_configs_v2'] as String)
                as Map;
        expect((futureProviders['future'] as Map)['apiKey'], '');

        final searchServices =
            jsonDecode(regularBackupSnapshot['search_services_v1'] as String)
                as List;
        expect((searchServices.first as Map)['apiKey'], '');
        final searxng = searchServices.last as Map;
        final searchUri = Uri.parse(searxng['url'] as String);
        expect(searchUri.userInfo, isEmpty);
        expect(searchUri.queryParameters['subscription-key'], '');
        expect(searchUri.hasFragment, isFalse);
        expect(searxng['username'], 'safe-user');
        expect(searxng['password'], '');

        final ttsServices =
            jsonDecode(regularBackupSnapshot['tts_services_v1'] as String)
                as List;
        final tts = ttsServices.single as Map;
        expect(tts['kind'], 'openai');
        expect(tts['name'], 'Safe TTS');
        expect(tts['apiKey'], '');

        final mcpServers =
            jsonDecode(regularBackupSnapshot['mcp_servers_v1'] as String)
                as List;
        final mcpServer = mcpServers.single as Map;
        expect(mcpServer['name'], 'Safe MCP');
        expect(mcpServer['command'], 'safe-command');
        expect(mcpServer['args'], [
          '-y',
          'safe-mcp-package',
          '--token',
          '',
          '--aws-access-key-id',
          '',
          '--public-key',
          'safe-public-arg',
        ]);
        expect(mcpServer['env'], {
          'MCP_TOKEN': '',
          'AWS_ACCESS_KEY_ID': '',
          'GCP_SERVICE_ACCOUNT_JSON': '',
          'PUBLIC_KEY': 'safe-public-env',
          'SAFE_PATH': '/safe/path',
        });
        expect(mcpServer['headers'], {
          'Authorization': '',
          'X-Authorization': '',
          'Idempotency-Key': 'safe-idempotency-key',
          'Sec-WebSocket-Key': 'safe-websocket-key',
          'X-Title': 'safe-mcp-title',
        });
        final toolSchema = (mcpServer['tools'] as List).single as Map;
        final schema = toolSchema['schema'] as Map;
        final properties = schema['properties'] as Map;
        expect(properties.keys, containsAll(['headers', 'body', 'token']));
        final stdioMcp = McpServerConfig.fromJson(
          mcpServer.cast<String, dynamic>(),
        );
        expect(stdioMcp.args, [
          '-y',
          'safe-mcp-package',
          '--token',
          '',
          '--aws-access-key-id',
          '',
          '--public-key',
          'safe-public-arg',
        ]);
        expect(stdioMcp.env['MCP_TOKEN'], '');
        expect(stdioMcp.env['AWS_ACCESS_KEY_ID'], '');
        expect(stdioMcp.env['GCP_SERVICE_ACCOUNT_JSON'], '');
        expect(stdioMcp.env['PUBLIC_KEY'], 'safe-public-env');
        expect(stdioMcp.env['SAFE_PATH'], '/safe/path');
        final httpMcp = McpServerConfig.fromJson({
          ...mcpServer.cast<String, dynamic>(),
          'transport': 'http',
          'url': 'https://mcp.example',
        });
        expect(httpMcp.headers['Authorization'], '');
        expect(httpMcp.headers['X-Authorization'], '');
        expect(httpMcp.headers['Idempotency-Key'], 'safe-idempotency-key');
        expect(httpMcp.headers['Sec-WebSocket-Key'], 'safe-websocket-key');
        expect(httpMcp.headers['X-Title'], 'safe-mcp-title');

        final assistants =
            jsonDecode(regularBackupSnapshot['assistants_v1'] as String)
                as List;
        final assistant = assistants.single as Map;
        expect(assistant['name'], 'Safe Assistant');
        expect(assistant['systemPrompt'], 'safe prompt');
        final assistantHeaders = assistant['customHeaders'] as List;
        final assistantHeadersByName = {
          for (final item in assistantHeaders)
            (item as Map)['name']: item['value'],
        };
        expect(assistantHeadersByName['Authorization'], '');
        expect(assistantHeadersByName['Proxy-Authorization'], '');
        expect(assistantHeadersByName['X-Title'], 'safe-assistant-title');
        final assistantBody = assistant['customBody'] as List;
        final assistantBodyByKey = {
          for (final item in assistantBody) (item as Map)['key']: item['value'],
        };
        expect(assistantBodyByKey['token'], '');
        expect(assistantBodyByKey['credentials'], '');
        expect(assistantBodyByKey['passphrase'], '');
        expect(assistantBodyByKey['publicKey'], 'safe-assistant-public-key');
        expect(assistantBodyByKey['temperature'], '0.5');
        final decodedAssistant = Assistant.fromJson(
          assistant.cast<String, dynamic>(),
        );
        expect(decodedAssistant.customHeaders.first['value'], '');
        expect(
          decodedAssistant.customHeaders.last['value'],
          'safe-assistant-title',
        );

        final webDav =
            jsonDecode(regularBackupSnapshot['webdav_config_v1'] as String)
                as Map<String, dynamic>;
        final webDavUri = Uri.parse(webDav['url'] as String);
        expect(webDavUri.userInfo, isEmpty);
        expect(webDavUri.queryParameters['access_token'], '');
        expect(webDavUri.queryParameters['folder'], 'safe-folder');
        expect(webDav['username'], 'safe-webdav-user');
        expect(webDav['password'], '');
        final decodedWebDav = WebDavConfig.fromJson(webDav);
        expect(decodedWebDav.password, '');
        expect(decodedWebDav.username, 'safe-webdav-user');

        final s3 =
            jsonDecode(regularBackupSnapshot['s3_config_v1'] as String)
                as Map<String, dynamic>;
        final s3Uri = Uri.parse(s3['endpoint'] as String);
        expect(s3Uri.queryParameters['X-Amz-Signature'], '');
        expect(s3Uri.queryParameters['region'], 'safe-region');
        expect(s3['bucket'], 'safe-bucket');
        expect(s3['accessKeyId'], '');
        expect(s3['secretAccessKey'], '');
        expect(s3['sessionToken'], '');
        final decodedS3 = S3Config.fromJson(s3);
        expect(decodedS3.accessKeyId, '');
        expect(decodedS3.secretAccessKey, '');
        expect(decodedS3.sessionToken, '');

        final decodedSearch = SearchServiceOptions.fromJson(
          (searchServices.first as Map).cast<String, dynamic>(),
        );
        expect((decodedSearch as TavilyOptions).apiKey, '');
        final decodedTts = TtsServiceOptions.fromJson(
          tts.cast<String, dynamic>(),
        );
        expect(decodedTts.toJson()['apiKey'], '');
      },
    );

    test(
      'legacy secret-free sanitizer rejects malformed credential JSON',
      () async {
        SharedPreferences.setMockInitialValues({
          'provider_configs_v1': '{invalid provider json',
        });

        final prefs = await backup_sync.SharedPreferencesAsync.instance;

        await expectLater(
          () async => BackupSettingsSanitizer.sanitize(await prefs.snapshot()),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test(
      'legacy secret-free sanitizer rejects malformed credential shapes',
      () async {
        final invalidSettings = <Map<String, Object>>[
          {
            'provider_configs_v1': jsonEncode({'provider': 'raw-secret'}),
          },
          {
            'search_services_v1': jsonEncode(['raw-secret']),
          },
        ];

        for (final initialValues in invalidSettings) {
          SharedPreferences.setMockInitialValues(initialValues);
          final prefs = await backup_sync.SharedPreferencesAsync.instance;
          await expectLater(
            () async =>
                BackupSettingsSanitizer.sanitize(await prefs.snapshot()),
            throwsA(isA<FormatException>()),
          );
        }
      },
    );

    test(
      'restore ignores chat font scale but restores synced settings',
      () async {
        SharedPreferences.setMockInitialValues({
          'display_chat_font_scale_v1': 1.15,
        });

        final prefs = await backup_sync.SharedPreferencesAsync.instance;
        await prefs.restore({
          'display_chat_font_scale_v1': 1.4,
          'display_auto_scroll_enabled_v1': false,
        });

        final rawPrefs = await SharedPreferences.getInstance();
        expect(rawPrefs.getDouble('display_chat_font_scale_v1'), 1.15);
        expect(rawPrefs.getBool('display_auto_scroll_enabled_v1'), isFalse);
      },
    );

    test('restoreSingle ignores old backup chat font scale entries', () async {
      SharedPreferences.setMockInitialValues({
        'display_chat_font_scale_v1': 0.95,
      });

      final prefs = await backup_sync.SharedPreferencesAsync.instance;
      await prefs.restoreSingle('display_chat_font_scale_v1', 1.5);

      final rawPrefs = await SharedPreferences.getInstance();
      expect(rawPrefs.getDouble('display_chat_font_scale_v1'), 0.95);
    });

    test('restore ignores platform-specific desktop hotkey entries', () async {
      SharedPreferences.setMockInitialValues({
        'desktop_hotkeys_commands_v1': [
          'close_window=ctrl+w',
          'open_settings=ctrl+comma',
        ],
        'desktop_hotkeys_enabled_v1': ['close_window=1', 'open_settings=0'],
      });

      final prefs = await backup_sync.SharedPreferencesAsync.instance;
      await prefs.restore({
        'desktop_hotkeys_commands_v1': [
          'close_window=cmd+w',
          'open_settings=cmd+comma',
        ],
        'desktop_hotkeys_enabled_v1': ['close_window=1', 'open_settings=1'],
      });

      final rawPrefs = await SharedPreferences.getInstance();
      expect(rawPrefs.getStringList('desktop_hotkeys_commands_v1'), [
        'close_window=ctrl+w',
        'open_settings=ctrl+comma',
      ]);
      expect(rawPrefs.getStringList('desktop_hotkeys_enabled_v1'), [
        'close_window=1',
        'open_settings=0',
      ]);
    });

    test('restore reports unsupported setting value types', () async {
      SharedPreferences.setMockInitialValues({});

      final prefs = await backup_sync.SharedPreferencesAsync.instance;

      await expectLater(
        prefs.restore({
          'unsupported_setting': {'nested': true},
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
