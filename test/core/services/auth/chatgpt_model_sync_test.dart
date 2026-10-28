import 'dart:async';
import 'dart:convert';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/auth/provider_oauth_adapter.dart';
import 'package:Kelivo/core/services/auth/provider_oauth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../../support/business_test_harness.dart';

ProviderConfig account({
  String id = 'account',
  String? version,
  String session = 'session',
  bool expired = false,
  OAuthProvider provider = OAuthProvider.chatgpt,
}) => ProviderConfig(
  id: id,
  enabled: true,
  name: provider.displayName,
  apiKey: '',
  baseUrl: provider.baseUrl,
  oauthProvider: provider,
  oauthCredentials: ProviderOAuthCredentials(
    accessToken: 'access',
    refreshToken: 'refresh',
    expiresAt: DateTime.now().add(
      expired ? const Duration(seconds: -1) : const Duration(hours: 1),
    ),
    sessionId: session,
    accountId: id,
  ),
  models: const ['gpt-6-sol'],
  modelOverrides: const {
    'gpt-6-sol': {'temperature': .7},
  },
  oauthModelsSyncedAt: DateTime.utc(2026, 9, 1),
  oauthModelsClientVersion: version,
);

http.Response catalog([String model = 'gpt-6.1-sol']) => http.Response(
  jsonEncode({
    'models': [
      {'slug': 'gpt-6-sol'},
      {'slug': model, 'supported_in_api': false},
    ],
  }),
  200,
);

Future<({SettingsProvider settings, BusinessTestHarness harness})> loadAccounts(
  List<ProviderConfig> accounts,
) async {
  final harness = await createBusinessTestHarness(
    initial: {
      'provider_configs_v1': jsonEncode({
        for (final config in accounts) config.id: config.toJson(),
      }),
    },
  );
  final settings = SettingsProvider(harness.preferences);
  addTearDown(settings.dispose);
  return (settings: settings, harness: harness);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'sync retains disabled models across reloads and catalog changes',
    () async {
      final loaded = await loadAccounts([account()]);
      var response = catalog();
      final service = ProviderOAuthService(
        clientFactory: (_) => MockClient((_) async => response),
      )..bind(loaded.settings);
      addTearDown(service.dispose);
      await loaded.settings.loaded;
      await loaded.settings.setModelEnabled('account', 'gpt-6-sol', false);
      await service.syncOutdatedModels(loaded.settings);
      var saved = loaded.settings.getProviderConfig('account');
      expect(saved.enabledModels, ['gpt-6.1-sol']);
      expect(saved.disabledModels, {'gpt-6-sol'});
      expect(saved.modelOverrides['gpt-6-sol']['temperature'], .7);

      final reloaded = SettingsProvider(loaded.harness.preferences);
      addTearDown(reloaded.dispose);
      await reloaded.loaded;
      service.bind(reloaded);
      response = http.Response(
        jsonEncode({
          'models': [
            {'slug': 'gpt-6.1-sol'},
          ],
        }),
        200,
      );
      await service.syncModels('account');
      expect(reloaded.getProviderConfig('account').models, ['gpt-6.1-sol']);
      expect(reloaded.getProviderConfig('account').disabledModels, {
        'gpt-6-sol',
      });

      response = catalog();
      await service.syncModels('account');
      saved = reloaded.getProviderConfig('account');
      expect(saved.models, ['gpt-6-sol', 'gpt-6.1-sol']);
      expect(saved.enabledModels, ['gpt-6.1-sol']);
      await reloaded.setModelEnabled('account', 'gpt-6.1-sol', false);
      await service.syncModels('account');
      expect(reloaded.getProviderConfig('account').enabledModels, isEmpty);
    },
  );

  for (final previousVersion in [null, '0.153.0']) {
    test(
      'startup refreshes version $previousVersion once across reloads',
      () async {
        final loaded = await loadAccounts([account(version: previousVersion)]);
        var calls = 0;
        final service = ProviderOAuthService(
          clientFactory: (_) => MockClient((request) async {
            calls++;
            expect(request.url.path, '/backend-api/codex/models');
            expect(request.url.queryParameters['client_version'], '0.159.0');
            expect(request.headers['version'], '0.159.0');
            expect(request.headers['chatgpt-account-id'], 'account');
            return catalog();
          }),
        )..bind(loaded.settings);

        // Startup calls this before SettingsProvider has finished loading.
        await service.syncOutdatedModels(loaded.settings);
        final saved = loaded.settings.providerConfigs['account']!;
        expect(saved.models, containsAll(['gpt-6-sol', 'gpt-6.1-sol']));
        expect(saved.modelOverrides['gpt-6-sol']['temperature'], .7);
        expect(saved.oauthModelsClientVersion, codexClientVersion);
        expect(
          saved.oauthModelsSyncedAt!.isAfter(DateTime.utc(2026, 9, 1)),
          true,
        );

        final reloaded = SettingsProvider(loaded.harness.preferences);
        addTearDown(reloaded.dispose);
        service.bind(reloaded);
        await service.syncOutdatedModels(reloaded);
        expect(
          reloaded.providerConfigs['account']!.oauthModelsClientVersion,
          codexClientVersion,
        );
        expect(reloaded.providerConfigs['account']!.models, saved.models);
        expect(calls, 1);
      },
    );
  }

  test(
    'startup skips current, disabled, logged out and other accounts',
    () async {
      final loginRequired = account(id: 'login-required');
      final loaded = await loadAccounts([
        account(id: 'current', version: codexClientVersion),
        account(id: 'disabled').copyWith(enabled: false),
        account(id: 'logged-out').copyWith(oauthCredentials: null),
        loginRequired.copyWith(
          oauthCredentials: loginRequired.oauthCredentials!.copyWith(
            requiresLogin: true,
          ),
        ),
        account(id: 'kimi', provider: OAuthProvider.kimi),
      ]);
      var calls = 0;
      final service = ProviderOAuthService(
        clientFactory: (_) => MockClient((_) async {
          calls++;
          return catalog();
        }),
      )..bind(loaded.settings);

      await service.syncOutdatedModels(loaded.settings);
      expect(calls, 0);
    },
  );

  test(
    'a failed account keeps its models and retries without blocking others',
    () async {
      final old = account(id: 'retry', version: '0.153.0');
      final loaded = await loadAccounts([old, account(id: 'healthy')]);
      final calls = <String>[];
      var fail = true;
      final service = ProviderOAuthService(
        clientFactory: (_) => MockClient((request) async {
          final id = request.headers['chatgpt-account-id']!;
          calls.add(id);
          if (id == 'retry' && fail) return http.Response('{}', 503);
          return catalog();
        }),
      )..bind(loaded.settings);

      await service.syncOutdatedModels(loaded.settings);
      final failed = loaded.settings.providerConfigs['retry']!;
      expect(failed.models, old.models);
      expect(failed.modelOverrides, old.modelOverrides);
      expect(failed.oauthModelsClientVersion, '0.153.0');
      expect(failed.oauthModelsSyncedAt, old.oauthModelsSyncedAt);
      expect(failed.oauthCredentials!.requiresLogin, false);
      expect(
        loaded.settings.providerConfigs['healthy']!.oauthModelsClientVersion,
        codexClientVersion,
      );

      fail = false;
      await service.syncOutdatedModels(loaded.settings);
      expect(calls, ['retry', 'healthy', 'retry']);
      expect(
        loaded.settings.providerConfigs['retry']!.models,
        contains('gpt-6.1-sol'),
      );
      expect(
        loaded.settings.providerConfigs['retry']!.oauthModelsClientVersion,
        codexClientVersion,
      );
    },
  );

  test(
    'startup refreshes expired credentials before model discovery',
    () async {
      final loaded = await loadAccounts([account(expired: true)]);
      final paths = <String>[];
      final service = ProviderOAuthService(
        clientFactory: (_) => MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path == '/oauth/token') {
            return http.Response(
              jsonEncode({
                'access_token': 'fresh-access',
                'refresh_token': 'rotated-refresh',
                'expires_in': 3600,
              }),
              200,
            );
          }
          expect(request.headers['Authorization'], 'Bearer fresh-access');
          return catalog();
        }),
      )..bind(loaded.settings);

      await service.syncOutdatedModels(loaded.settings);
      expect(paths, ['/oauth/token', '/backend-api/codex/models']);
      final saved = loaded.settings.providerConfigs['account']!;
      expect(saved.oauthCredentials!.refreshToken, 'rotated-refresh');
      expect(saved.oauthModelsClientVersion, codexClientVersion);
      expect(saved.models, contains('gpt-6.1-sol'));
    },
  );

  test(
    'startup and manual sync share a request and preserve concurrent edits',
    () async {
      final loaded = await loadAccounts([account()]);
      final started = Completer<void>();
      final response = Completer<http.Response>();
      var calls = 0;
      final service = ProviderOAuthService(
        clientFactory: (_) => MockClient((_) {
          calls++;
          if (!started.isCompleted) started.complete();
          return response.future;
        }),
      )..bind(loaded.settings);

      final automatic = service.syncOutdatedModels(loaded.settings);
      await started.future;
      final manual = service.syncModels('account');
      await loaded.settings.setModelEnabled('account', 'gpt-6-sol', false);
      await loaded.settings.setProviderConfig(
        'account',
        loaded.settings.providerConfigs['account']!.copyWith(
          name: 'Renamed',
          modelOverrides: {
            'gpt-6-sol': {
              'name': 'My Sol',
              'type': 'image',
              'temperature': .2,
              'input': ['text', 'audio'],
              'output': ['text', 'audio'],
              'abilities': ['structuredOutput'],
            },
          },
        ),
      );
      response.complete(catalog());
      await Future.wait([automatic, manual]);
      final saved = loaded.settings.providerConfigs['account']!;
      expect(calls, 1);
      expect(saved.name, 'Renamed');
      expect(saved.enabledModels, ['gpt-6.1-sol']);
      expect(saved.modelOverrides['gpt-6-sol']['name'], 'My Sol');
      expect(saved.modelOverrides['gpt-6-sol']['type'], 'image');
      expect(saved.modelOverrides['gpt-6-sol']['temperature'], .2);
      expect(saved.modelOverrides['gpt-6-sol']['input'], contains('audio'));
      expect(saved.modelOverrides['gpt-6-sol']['output'], contains('audio'));
      expect(
        saved.modelOverrides['gpt-6-sol']['abilities'],
        contains('structuredOutput'),
      );
      expect(saved.oauthModelsClientVersion, codexClientVersion);
    },
  );

  for (final action in ['logout', 'relogin', 'remove']) {
    test('a late sync cannot overwrite an account after $action', () async {
      final loaded = await loadAccounts([account()]);
      final started = Completer<void>();
      final response = Completer<http.Response>();
      final service = ProviderOAuthService(
        clientFactory: (_) => MockClient((_) {
          started.complete();
          return response.future;
        }),
      )..bind(loaded.settings);
      final sync = service.syncOutdatedModels(loaded.settings);
      await started.future;

      if (action == 'logout') {
        await service.logout('account');
      } else if (action == 'relogin') {
        await loaded.settings.setProviderConfig(
          'account',
          account(session: 'new'),
        );
      } else {
        await loaded.settings.removeProviderConfig('account');
      }
      response.complete(catalog());
      await sync;
      final saved = loaded.settings.providerConfigs['account'];
      if (action == 'remove') {
        expect(saved, isNull);
      } else {
        expect(saved!.models, ['gpt-6-sol']);
        expect(saved.oauthModelsClientVersion, isNull);
        expect(
          saved.oauthCredentials?.sessionId,
          action == 'logout' ? null : 'new',
        );
      }
    });
  }

  test(
    'restored settings with the same session neither join nor receive an old sync',
    () async {
      final original = await loadAccounts([account()]);
      final started = Completer<void>();
      final response = Completer<http.Response>();
      var calls = 0;
      final service = ProviderOAuthService(
        clientFactory: (_) => MockClient((_) {
          calls++;
          if (calls == 1) {
            started.complete();
            return response.future;
          }
          return Future.value(catalog('restored-model'));
        }),
      )..bind(original.settings);
      final oldSync = service.syncOutdatedModels(original.settings);
      await started.future;
      final restored = await loadAccounts([account()]);
      service.bind(restored.settings);
      await service.syncOutdatedModels(restored.settings);
      response.complete(catalog('old-response-model'));
      await oldSync;

      expect(calls, 2);
      expect(original.settings.providerConfigs['account']!.models, [
        'gpt-6-sol',
      ]);
      expect(restored.settings.providerConfigs['account']!.models, [
        'gpt-6-sol',
        'restored-model',
      ]);
      expect(
        restored.settings.providerConfigs['account']!.oauthModelsClientVersion,
        codexClientVersion,
      );
    },
  );
}
