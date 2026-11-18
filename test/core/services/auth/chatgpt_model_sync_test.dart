import 'dart:async';
import 'dart:convert';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/auth/codex_client_version.dart';
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

  for (final previousVersion in [null, '0.159.0']) {
    test(
      'startup refreshes version $previousVersion once across reloads',
      () async {
        final loaded = await loadAccounts([account(version: previousVersion)]);
        var calls = 0;
        final service = ProviderOAuthService(
          clientFactory: (_) => MockClient((request) async {
            calls++;
            expect(request.url.path, '/backend-api/codex/models');
            expect(
              request.url.queryParameters['client_version'],
              defaultCodexClientVersion,
            );
            expect(request.headers['version'], defaultCodexClientVersion);
            expect(request.headers['chatgpt-account-id'], 'account');
            return catalog('gpt-6.2-sol');
          }),
        )..bind(loaded.settings);

        // Startup calls this before SettingsProvider has finished loading.
        await service.syncOutdatedModels(loaded.settings);
        final saved = loaded.settings.providerConfigs['account']!;
        expect(saved.models, containsAll(['gpt-6-sol', 'gpt-6.2-sol']));
        expect(saved.modelOverrides['gpt-6-sol']['temperature'], .7);
        expect(saved.oauthModelsClientVersion, defaultCodexClientVersion);
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
          defaultCodexClientVersion,
        );
        expect(reloaded.providerConfigs['account']!.models, saved.models);
        expect(calls, 1);
      },
    );
  }

  test(
    'checks for a new release even when the startup roster is current',
    () async {
      final config = account(version: defaultCodexClientVersion).copyWith(
        modelOverrides: const {
          'gpt-6-sol': {'oauthServiceTierSessionId': 'session'},
        },
      );
      final loaded = await loadAccounts([config]);
      final requests = <http.Request>[];
      final service = ProviderOAuthService(
        codexVersion: CodexClientVersion(
          clientFactory: () => MockClient((request) async {
            requests.add(request);
            expect(request.url.host, 'registry.npmjs.org');
            return http.Response('{"version":"0.170.0"}', 200);
          }),
        ),
        clientFactory: (_) => MockClient((request) async {
          requests.add(request);
          expect(request.url.host, 'chatgpt.com');
          final version = request.url.queryParameters['client_version'];
          expect(version, '0.170.0');
          expect(request.headers['version'], version);
          return catalog('gpt-6.2-sol');
        }),
      )..bind(loaded.settings);
      addTearDown(service.dispose);

      await service.syncOutdatedModels(loaded.settings);
      await service.syncOutdatedModels(loaded.settings);
      final saved = loaded.settings.getProviderConfig(config.id);
      expect(requests, hasLength(2));
      expect(saved.oauthModelsClientVersion, '0.170.0');
      expect(saved.models, contains('gpt-6.2-sol'));
      final client = service.authenticatedClient(
        MockClient((request) async {
          expect(request.headers['version'], saved.oauthModelsClientVersion);
          return http.Response('{}', 200);
        }),
        config,
      );
      addTearDown(client.close);
      final response = await client.post(
        Uri.parse('${config.baseUrl}/responses'),
        body: '{"model":"gpt-6.2-sol","input":[]}',
      );
      expect(response.statusCode, 200);
      expect(requests, hasLength(2));
    },
  );

  test(
    'a manual version change resyncs other accounts and replaces a pending sync',
    () async {
      final idle = account(id: 'idle', version: defaultCodexClientVersion)
          .copyWith(
            modelOverrides: const {
              'gpt-6-sol': {'oauthServiceTierSessionId': 'session'},
            },
          );
      final loaded = await loadAccounts([
        account(id: 'other'),
        idle.copyWith(id: 'account'),
        idle,
      ]);
      final oldRequestStarted = Completer<void>();
      final oldResponse = Completer<http.Response>();
      var latest = defaultCodexClientVersion;
      var checks = 0;
      final updated = <String>[];
      final service = ProviderOAuthService(
        codexVersion: CodexClientVersion(
          clientFactory: () => MockClient((request) async {
            checks++;
            return http.Response(jsonEncode({'version': latest}), 200);
          }),
        ),
        clientFactory: (config) => MockClient((request) async {
          final version = request.url.queryParameters['client_version'];
          expect(request.headers['version'], version);
          if (version == defaultCodexClientVersion) {
            expect(config.id, 'other');
            oldRequestStarted.complete();
            return oldResponse.future;
          }
          expect(version, '0.170.0');
          updated.add(config.id);
          return catalog('gpt-6.2-sol');
        }),
      )..bind(loaded.settings);
      addTearDown(service.dispose);

      await loaded.settings.loaded;
      final other = service.syncModels('other', checkLatestCodexVersion: true);
      await oldRequestStarted.future;
      latest = '0.170.0';
      await service.syncModels('account', checkLatestCodexVersion: true);
      await other;
      await nextCatalogVersion(loaded.settings, 'idle', '0.170.0');
      oldResponse.complete(catalog());
      await Future<void>.delayed(Duration.zero);

      expect(checks, 2);
      expect(updated, unorderedEquals(['account', 'other', 'idle']));
      for (final id in ['account', 'other', 'idle']) {
        final saved = loaded.settings.getProviderConfig(id);
        expect(saved.models, ['gpt-6-sol', 'gpt-6.2-sol']);
        expect(saved.oauthModelsClientVersion, '0.170.0');
      }
    },
  );

  test('automatic sync finishes while the version check is pending', () async {
    final loaded = await loadAccounts([account()]);
    final checkStarted = Completer<void>();
    final registryResponse = Completer<http.Response>();
    final version = CodexClientVersion(
      clientFactory: () => MockClient((_) {
        checkStarted.complete();
        return registryResponse.future;
      }),
    );
    final service = ProviderOAuthService(
      codexVersion: version,
      clientFactory: (_) => MockClient((request) async {
        return request.headers['version'] == defaultCodexClientVersion
            ? catalog()
            : catalog('gpt-6.2-sol');
      }),
    )..bind(loaded.settings);
    addTearDown(service.dispose);
    await loaded.settings.loaded;

    await service.syncModels('account');
    await checkStarted.future;
    expect(
      loaded.settings.getProviderConfig('account').models,
      contains('gpt-6.1-sol'),
    );
    final resynced = nextCatalogVersion(loaded.settings, 'account', '0.170.0');
    registryResponse.complete(http.Response('{"version":"0.170.0"}', 200));
    await resynced;
    expect(
      loaded.settings.getProviderConfig('account').models,
      contains('gpt-6.2-sol'),
    );
  });

  for (final cachedCatalog in [false, true]) {
    test(
      'manual rollback does not reuse an old lookup or cache (cached=$cachedCatalog)',
      () async {
        const earlier = '0.170.0';
        const later = '0.171.0';
        final original = account(version: cachedCatalog ? earlier : null)
            .copyWith(
              modelOverrides: const {
                'gpt-6-sol': {'oauthServiceTierSessionId': 'session'},
              },
            );
        final loaded = await loadAccounts([original, account(id: 'other')]);
        await loaded.settings.loaded;
        var latest = earlier;
        var earlierCalls = 0;
        final earlierStarted = Completer<void>();
        final earlierResponse = Completer<http.Response>();
        final laterStarted = Completer<void>();
        final laterResponse = Completer<http.Response>();
        final service = ProviderOAuthService(
          codexVersion: CodexClientVersion(
            clientFactory: () => MockClient(
              (_) async => http.Response(jsonEncode({'version': latest}), 200),
            ),
          ),
          clientFactory: (config) => MockClient((request) async {
            if (config.id == 'other') return catalog();
            if (request.headers['version'] == later) {
              laterStarted.complete();
              return laterResponse.future;
            }
            expect(request.headers['version'], earlier);
            earlierCalls++;
            if (!cachedCatalog && earlierCalls == 1) {
              earlierStarted.complete();
              return earlierResponse.future;
            }
            return catalog('fresh-after-rollback');
          }),
        )..bind(loaded.settings);
        addTearDown(service.dispose);

        Future<void>? first;
        if (cachedCatalog) {
          await service.syncModels('other', checkLatestCodexVersion: true);
        } else {
          first = service.syncModels('account', checkLatestCodexVersion: true);
          await earlierStarted.future;
        }
        latest = later;
        final superseded = service.syncModels(
          'account',
          checkLatestCodexVersion: true,
        );
        await laterStarted.future;
        latest = earlier;
        await service.syncModels('other', checkLatestCodexVersion: true);
        await superseded;
        await first;
        earlierResponse.complete(catalog('stale-before-update'));
        laterResponse.complete(catalog('stale-before-rollback'));
        await Future<void>.delayed(Duration.zero);

        final saved = loaded.settings.getProviderConfig('account');
        expect(earlierCalls, cachedCatalog ? 1 : 2);
        expect(saved.models, ['fresh-after-rollback', 'gpt-6-sol']);
        expect(saved.oauthModelsClientVersion, earlier);
      },
    );
  }

  for (final afterRelogin in [false, true]) {
    test(
      'first catalog stays usable if the update fails (relogin=$afterRelogin)',
      () async {
        final loaded = await loadAccounts([
          account().copyWith(
            models: afterRelogin ? ['previous-account-model'] : [],
          ),
        ]);
        final initialStarted = Completer<void>();
        final initialResponse = Completer<http.Response>();
        final latestStarted = Completer<void>();
        final registryResponse = Completer<http.Response>();
        final service = ProviderOAuthService(
          codexVersion: CodexClientVersion(
            clientFactory: () => MockClient((_) => registryResponse.future),
          ),
          clientFactory: (_) => MockClient((request) async {
            if (request.headers['version'] == defaultCodexClientVersion) {
              initialStarted.complete();
              return initialResponse.future;
            }
            latestStarted.complete();
            return http.Response('{}', 503);
          }),
        )..bind(loaded.settings);
        addTearDown(service.dispose);

        await loaded.settings.loaded;
        final sync = afterRelogin
            ? service.syncModels('account')
            : service.syncOutdatedModels(loaded.settings);
        await initialStarted.future;
        registryResponse.complete(http.Response('{"version":"0.170.0"}', 200));
        await latestStarted.future;
        initialResponse.complete(catalog());
        await sync;
        final saved = loaded.settings.getProviderConfig('account');
        expect(saved.oauthModelsClientVersion, defaultCodexClientVersion);
        expect(saved.models, ['gpt-6-sol', 'gpt-6.1-sol']);
      },
    );
  }

  test(
    'startup does not retry a failed catalog when npm learns nothing',
    () async {
      final loaded = await loadAccounts([account()]);
      final failed = Completer<void>();
      final registryResponse = Completer<http.Response>();
      var catalogCalls = 0;
      final service = ProviderOAuthService(
        codexVersion: CodexClientVersion(
          clientFactory: () => MockClient((_) => registryResponse.future),
        ),
        clientFactory: (_) => MockClient((_) async {
          if (++catalogCalls == 1) failed.complete();
          return http.Response('{}', 429);
        }),
      )..bind(loaded.settings);
      addTearDown(service.dispose);

      final startup = service.syncOutdatedModels(loaded.settings);
      await failed.future;
      await Future<void>.delayed(Duration.zero);
      registryResponse.complete(http.Response('{}', 503));
      await startup;
      expect(catalogCalls, 1);
      expect(loaded.settings.getProviderConfig('account').models, [
        'gpt-6-sol',
      ]);
    },
  );

  test(
    'startup skips current, disabled, logged out and other accounts',
    () async {
      final loginRequired = account(id: 'login-required');
      final loaded = await loadAccounts([
        account(id: 'current', version: defaultCodexClientVersion).copyWith(
          modelOverrides: const {
            'gpt-6-sol': {
              'temperature': .7,
              'oauthServiceTierSessionId': 'session',
            },
          },
        ),
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
        defaultCodexClientVersion,
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
        defaultCodexClientVersion,
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
      expect(saved.oauthModelsClientVersion, defaultCodexClientVersion);
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
      expect(saved.oauthModelsClientVersion, defaultCodexClientVersion);
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
        defaultCodexClientVersion,
      );
    },
  );
}

Future<void> nextCatalogVersion(
  SettingsProvider settings,
  String id,
  String version,
) async {
  final reached = Completer<void>();
  void onChanged() {
    if (!reached.isCompleted &&
        settings.getProviderConfig(id).oauthModelsClientVersion == version) {
      reached.complete();
    }
  }

  settings.addListener(onChanged);
  try {
    onChanged();
    await reached.future.timeout(const Duration(seconds: 3));
  } finally {
    settings.removeListener(onChanged);
  }
}
