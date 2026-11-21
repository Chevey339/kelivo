import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/model_catalog/catalog_entry.dart';
import 'package:Kelivo/core/services/model_catalog/model_catalog_service.dart';
import 'package:Kelivo/core/services/model_catalog/model_catalog_trim.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late DateTime now;

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    tempDir = await Directory.systemTemp.createTemp('model_catalog_svc_');
    now = DateTime.utc(2026, 9, 15, 12);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  ModelCatalogService service({
    http.Client Function()? clientFactory,
    Future<String> Function()? loadBundledJson,
    Future<SharedPreferences> Function()? prefs,
    DateTime Function()? clock,
  }) {
    return ModelCatalogService(
      loadBundledJson: loadBundledJson ?? () async => _trimmedFixtureJson,
      cacheDirectory: () async => tempDir,
      clientFactory:
          clientFactory ??
          () => MockClient((_) async => http.Response('{}', 500)),
      prefs: prefs ?? SharedPreferences.getInstance,
      now: clock ?? () => now,
    );
  }

  group('catalogProviderIdsFor', () {
    test('official kinds with empty or official baseUrl', () {
      final svc = service()..debugSetData(_matchingCatalog());

      expect(svc.catalogProviderIdsFor(_cfg(kind: ProviderKind.openai)), [
        'openai',
      ]);
      expect(
        svc.catalogProviderIdsFor(
          _cfg(kind: ProviderKind.openai, baseUrl: 'https://api.openai.com/v1'),
        ),
        ['openai'],
      );
      expect(svc.catalogProviderIdsFor(_cfg(kind: ProviderKind.claude)), [
        'anthropic',
      ]);
      expect(
        svc.catalogProviderIdsFor(
          _cfg(kind: ProviderKind.claude, baseUrl: 'https://api.anthropic.com'),
        ),
        ['anthropic'],
      );
      expect(svc.catalogProviderIdsFor(_cfg(kind: ProviderKind.google)), [
        'google',
      ]);
      expect(
        svc.catalogProviderIdsFor(
          _cfg(
            kind: ProviderKind.google,
            baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
          ),
        ),
        ['google'],
      );
    });

    test('shared host is ordered by id length', () {
      final svc = service()..debugSetData(_matchingCatalog());
      expect(
        svc.catalogProviderIdsFor(
          _cfg(baseUrl: 'https://open.bigmodel.cn/api/paas/v4'),
        ),
        ['zhipuai', 'zhipuai-coding-plan'],
      );
    });

    test('vertexAI maps to vertex catalog providers', () {
      final svc = service()..debugSetData(_matchingCatalog());
      final vertexCfg = _cfg(
        kind: ProviderKind.google,
        vertexAI: true,
        baseUrl: '',
      );
      expect(vertexCfg.vertexAI, isTrue);
      expect(svc.catalogProviderIdsFor(vertexCfg), [
        'google-vertex',
        'google-vertex-anthropic',
      ]);
      expect(
        svc.catalogProviderIdsFor(
          _cfg(
            kind: ProviderKind.google,
            baseUrl: 'https://us-central1-aiplatform.googleapis.com',
          ),
        ),
        ['google-vertex', 'google-vertex-anthropic'],
      );
    });

    test('unknown host falls back by kind for claude and google', () {
      final svc = service()..debugSetData(_matchingCatalog());
      expect(
        svc.catalogProviderIdsFor(
          _cfg(kind: ProviderKind.claude, baseUrl: 'https://proxy.example.com'),
        ),
        ['anthropic'],
      );
      expect(
        svc.catalogProviderIdsFor(
          _cfg(kind: ProviderKind.google, baseUrl: 'https://proxy.example.com'),
        ),
        ['google'],
      );
      expect(
        svc.catalogProviderIdsFor(
          _cfg(kind: ProviderKind.openai, baseUrl: 'https://proxy.example.com'),
        ),
        isEmpty,
      );
    });
  });

  group('lookup', () {
    test(
      'exact, normalized :free/@date, vendor prefix, first-party, unknown',
      () {
        final svc = service()..debugSetData(_matchingCatalog());
        final openai = _cfg(
          kind: ProviderKind.openai,
          baseUrl: 'https://api.openai.com/v1',
        );
        final vertex = _cfg(kind: ProviderKind.google, vertexAI: true);
        final openrouter = _cfg(baseUrl: 'https://openrouter.ai/api/v1');
        final custom = _cfg(baseUrl: 'https://proxy.example.com');

        final exact = svc.lookup(openai, 'gpt-4o');
        expect(exact?.kind, CatalogMatchKind.providerExact);
        expect(exact?.provider.id, 'openai');
        expect(exact?.model.id, 'gpt-4o');

        final ci = svc.lookup(openai, 'GPT-4o');
        expect(ci?.kind, CatalogMatchKind.providerNormalized);
        expect(ci?.model.id, 'gpt-4o');

        final free = svc.lookup(
          _cfg(baseUrl: 'https://api.deepseek.com/v1'),
          'deepseek-chat:free',
        );
        expect(free?.kind, CatalogMatchKind.providerNormalized);
        expect(free?.provider.id, 'deepseek');
        expect(free?.model.id, 'deepseek-chat');

        final dated = svc.lookup(vertex, 'gemini-1.5-pro@20250915');
        expect(dated?.kind, CatalogMatchKind.providerNormalized);
        expect(dated?.provider.id, 'google-vertex');
        expect(dated?.model.id, 'gemini-1.5-pro');

        final openrouterExact = svc.lookup(
          openrouter,
          'anthropic/claude-sonnet-4.6',
        );
        expect(openrouterExact?.kind, CatalogMatchKind.providerExact);
        expect(openrouterExact?.provider.id, 'openrouter');

        final vendor = svc.lookup(custom, 'anthropic/claude-sonnet-4.6');
        expect(vendor?.kind, CatalogMatchKind.global);
        expect(vendor?.provider.id, 'anthropic');
        expect(vendor?.model.id, 'claude-sonnet-4.6');

        final vendorFree = svc.lookup(custom, 'deepseek/deepseek-chat:free');
        expect(vendorFree?.kind, CatalogMatchKind.global);
        expect(vendorFree?.provider.id, 'deepseek');
        expect(vendorFree?.model.id, 'deepseek-chat');

        final firstParty = svc.lookup(custom, 'gpt-4o');
        expect(firstParty?.kind, CatalogMatchKind.global);
        expect(firstParty?.provider.id, 'openai');

        expect(svc.lookup(openai, 'totally-unknown-model'), isNull);
      },
    );

    test('path and channel labels find exact model IDs', () {
      final svc = service()..debugSetData(_matchingCatalog());
      final custom = _cfg(baseUrl: 'https://proxy.example.com');

      for (final id in [
        'loomy/GLM-5.3-Flash',
        'GLM-5.3-Flash',
        'glm-5.3-flash',
        'zai-org/GLM-5.3-Flash',
        'aimlapi/z-ai/glm-5.3-flash',
        'loomy/ GLM-5.3-Flash // ',
      ]) {
        final match = svc.lookup(custom, id);
        expect(match?.model.id, 'glm-5.3-flash', reason: id);
        expect(match?.provider.id, 'zhipuai', reason: id);
        expect(match?.inferred, isTrue, reason: id);
      }

      for (final id in [
        '[times] gemini-3.8-flash',
        '【times】 gemini-3.8-flash',
        '[times]gemini-3.8-flash',
        'loomy/[times] gemini-3.8-flash',
        '[times] loomy/gemini-3.8-flash',
        '[Times] Gemini-3.8-Flash',
        'gemini-3.8-flash (WB)',
        'gemini-3.8-flash(wb)',
        'gemini-3.8-flash(high)',
        '（team）-.gemini-3.8-flash ·_「WB」',
        'gemini-3.8-flash [relay] (2)',
      ]) {
        expect(
          svc.lookup(custom, id)?.model.id,
          'gemini-3.8-flash',
          reason: id,
        );
      }
      expect(svc.lookup(custom, '[times] glm-5')?.model.id, 'glm-5');
      expect(svc.lookup(custom, 'glm-5.3')?.model.id, 'glm-5.3');
    });

    test('provider full ID wins before a scoped vendor prefix match', () {
      final svc = service()..debugSetData(_matchingCatalog());
      final custom = _cfg(baseUrl: 'https://proxy.example.com');
      final openrouter = _cfg(baseUrl: 'https://openrouter.ai/api/v1');

      final exact = svc.lookup(openrouter, 'z-ai/glm-5.3-flash');
      expect(exact?.provider.id, 'openrouter');
      expect(exact?.kind, CatalogMatchKind.providerExact);
      expect(exact?.inferred, isFalse);
      final mapped = svc.lookup(custom, 'z-ai/nested/[relay] GLM-5-3-Flash/');
      expect(mapped?.provider.id, 'zai');
      expect(mapped?.model.id, 'glm-5.3-flash');
      expect(mapped?.inferred, isFalse);
      expect(svc.lookup(custom, 'z-ai/glm-5'), isNull);
      expect(svc.lookup(openrouter, 'z-ai/glm-5')?.provider.id, 'openrouter');
    });

    test('window hints require a catalog match for the marked base ID', () {
      final svc = service()..debugSetData(_matchingCatalog());
      final custom = _cfg(baseUrl: 'https://proxy.example.com');
      final marked = svc.lookup(custom, 'gemini-3.8-flash[1m]');
      expect(marked?.model.id, 'gemini-3.8-flash');
      expect(marked?.model.contextLimit, 262144);
      expect(marked?.contextWindowHint, 1000000);
      expect(
        svc
            .lookup(custom, '[relay] Gemini-3-8-Flash[1.5M](WB)')
            ?.contextWindowHint,
        1500000,
      );
      expect(
        svc.lookup(custom, 'gemini-3.8-flash [1m]')?.contextWindowHint,
        isNull,
      );
      expect(
        svc.lookup(custom, 'gemini-3.8-flash[200K]')?.contextWindowHint,
        200000,
      );
      expect(
        svc.lookup(custom, 'gemini-3.8-flash[1.001m]')?.contextWindowHint,
        1001000,
      );

      for (final id in [
        'unlisted[1m]',
        '[1m]',
        'claude-[1m]',
        'gemini-3.8-flash[infm]',
        'gemini-3.8-flash[1M]x',
        'gemini-3.8-flash[0k]',
      ]) {
        expect(svc.lookup(custom, id), isNull, reason: id);
      }
    });

    test('folds only spelling separators and recognized snapshot dates', () {
      final svc = service()..debugSetData(_matchingCatalog());
      final custom = _cfg(baseUrl: 'https://proxy.example.com');
      for (final (id, canonical) in [
        ('glm-5-3-flash', 'glm-5.3-flash'),
        ('loomy/GLM-5-3-Flash:free', 'glm-5.3-flash'),
        ('loomy/GLM-5-3-Flash@20250915', 'glm-5.3-flash'),
        ('glm-5.3-flash-260828', 'glm-5.3-flash'),
        ('【WB】DeepSeek\u00a0V4.1_Flash', 'deepseek-v4.1-flash'),
        ('deepseek-v4p1-flash', 'deepseek-v4.1-flash'),
        ('kimi-k3-1-pro-261024', 'kimi-k3.1-pro'),
        ('Kimi-K3.1-Pro-20261024', 'kimi-k3.1-pro'),
        ('kimi-k3-1-pro@20261024', 'kimi-k3.1-pro'),
        ('snapshots/model-3-1', 'model-3.1-20261024'),
      ]) {
        expect(svc.lookup(custom, id)?.model.id, canonical, reason: id);
      }
      final first = svc.lookup(custom, 'GLM 5 3 FLASH');
      expect(first?.provider.id, 'zhipuai');
      expect(first?.model.id, 'glm-5.3-flash');
      expect(first?.inferred, isTrue);
    });

    test('does not infer variants, partial IDs or router aliases', () {
      final svc = service()..debugSetData(_matchingCatalog());
      final custom = _cfg(baseUrl: 'https://proxy.example.com');
      for (final id in [
        'foo/glm-5.3-flash-uncensored',
        'foo/gpt-4o-custom',
        'totally-unknown-model',
        'foo/totally-unknown-model',
        'loomy/',
        '/',
        'ds.4.1(WB)',
        'deepseek-v4.1-flashy (WB)',
        'deepseek-v4.1 (WB) flash',
        'gemini-3.8-flash[fast]',
        'gemini-3.8-flash(preview)',
        'gemini-3.8-flash (thinking)',
        'gemini-3.8-flash（beta）',
        'gemini-3.8-flash(free)',
        'gemini-3.8-flash(experimental)',
        'cn:glm-5.3-flash',
        'gemini-3.8-flash:thinking',
        'gemini-3.8-flash:nitro',
        'gemini-3.8-flash:beta',
        'gemini-3.8-flash:extended',
        'nyro-gpt-4o',
        'claude-deepseek-v4.1-flash',
        'kimi-k3-1-pro-2610',
        'kimi-k3.1-pro-261324',
        'kimi-k3.1-pro-max',
        'gpt-4o-2024-08-06',
        'openrouter/auto',
        'auto',
        '[relay] default',
        'proxy/free:free',
      ]) {
        expect(svc.lookup(custom, id), isNull, reason: id);
      }
      final openrouter = _cfg(baseUrl: 'https://openrouter.ai/api/v1');
      expect(
        svc.lookup(openrouter, 'openrouter/auto')?.kind,
        CatalogMatchKind.providerExact,
      );
    });

    test('rebuilds index after debugSetData version bump', () {
      final svc = service()..debugSetData(_matchingCatalog());
      expect(svc.version, 1);
      expect(svc.lookup(_cfg(), 'gpt-4o')?.provider.id, 'openai');
      expect(svc.lookup(_cfg(), 'gpt 4o')?.provider.id, 'openai');

      svc.debugSetData(
        ModelCatalogData(
          schemaVersion: 1,
          generatedAt: DateTime.utc(2026, 2, 1),
          providers: {
            'deepseek': _provider(
              'deepseek',
              api: 'https://api.deepseek.com/v1',
              models: [_model('deepseek-chat')],
            ),
          },
        ),
      );
      expect(svc.version, 2);
      expect(svc.lookup(_cfg(), 'gpt-4o'), isNull);
      expect(svc.lookup(_cfg(), 'gpt 4o'), isNull);
      expect(svc.lookup(_cfg(), 'deepseek chat')?.provider.id, 'deepseek');
      expect(svc.lookup(_cfg(), 'deepseek-chat')?.provider.id, 'deepseek');
    });

    test('returns null and starts load when empty', () async {
      final svc = service();
      expect(svc.lookup(_cfg(), 'gpt-4o'), isNull);
      await svc.ensureLoaded();
      expect(svc.isLoaded, isTrue);
    });
  });

  group('refresh', () {
    test('writes cache, bumps version, clears bundled, notifies', () async {
      var httpCalls = 0;
      var notifications = 0;
      final svc = service(
        clientFactory: () => MockClient((request) async {
          httpCalls += 1;
          expect(request.url, kModelCatalogRemoteUri);
          return http.Response(_rawModelsDevPayload, 200);
        }),
      );
      svc.addListener(() => notifications += 1);
      svc.debugSetData(_matchingCatalog(), bundled: true);
      expect(svc.version, 1);
      expect(svc.isBundled, isTrue);

      final changed = await svc.refresh(force: true);
      expect(changed, isTrue);
      expect(httpCalls, 1);
      expect(svc.version, 2);
      expect(svc.isBundled, isFalse);
      expect(svc.refreshing, isFalse);
      expect(svc.data?.providers.containsKey('acme'), isTrue);
      expect(notifications, greaterThan(0));

      final cache = File('${tempDir.path}/$kModelCatalogCacheFileName');
      expect(await cache.exists(), isTrue);
      final cached =
          jsonDecode(await cache.readAsString()) as Map<String, dynamic>;
      expect(cached['schemaVersion'], 1);
      expect((cached['providers'] as Map)['acme'], isNotNull);
    });

    test('invalid JSON sets lastError and leaves data', () async {
      final svc = service(
        clientFactory: () =>
            MockClient((_) async => http.Response('not-json{', 200)),
      );
      svc.debugSetData(_matchingCatalog(), bundled: false);
      final version = svc.version;
      final changed = await svc.refresh(force: true);
      expect(changed, isFalse);
      expect(svc.lastError, isNotNull);
      expect(svc.lastError, isNotEmpty);
      expect(svc.version, version);
      expect(svc.data?.providers.containsKey('openai'), isTrue);
    });

    test('skips HTTP when not force and not stale', () async {
      var httpCalls = 0;
      final svc = service(
        clientFactory: () => MockClient((_) async {
          httpCalls += 1;
          return http.Response(_rawModelsDevPayload, 200);
        }),
        clock: () => now,
      );
      svc.debugSetData(_matchingCatalog(generatedAt: now), bundled: false);
      expect(svc.isStale, isFalse);
      expect(await svc.refresh(), isFalse);
      expect(httpCalls, 0);
    });

    test(
      'maybeAutoRefresh does not call HTTP when autoUpdate is false',
      () async {
        SharedPreferences.setMockInitialValues(const <String, Object>{
          kModelCatalogAutoUpdatePrefsKey: false,
        });
        var httpCalls = 0;
        final svc = service(
          clientFactory: () => MockClient((_) async {
            httpCalls += 1;
            return http.Response(_rawModelsDevPayload, 200);
          }),
        );
        await svc.maybeAutoRefresh();
        expect(svc.autoUpdate, isFalse);
        expect(httpCalls, 0);
        expect(svc.isLoaded, isTrue);
        expect(svc.isBundled, isTrue);
      },
    );
  });

  group('modelsOfProvider', () {
    test('empty before load, fixture after ensureLoaded', () async {
      final svc = service();
      expect(svc.modelsOfProvider('openai'), isEmpty);

      await svc.ensureLoaded();
      expect(svc.modelsOfProvider('openai').map((m) => m.id), ['gpt-4o']);
      expect(svc.modelsOfProvider('missing'), isEmpty);
    });

    test('reads the currently loaded catalog after refresh', () async {
      final svc = service(
        clientFactory: () =>
            MockClient((_) async => http.Response(_rawModelsDevPayload, 200)),
      );
      svc.debugSetData(
        ModelCatalogData(
          schemaVersion: 1,
          generatedAt: DateTime.utc(2026, 1, 1),
          providers: {
            'google-vertex-anthropic': _provider(
              'google-vertex-anthropic',
              models: [
                _model('claude-opus-4-5@20251101'),
                _model('claude-sonnet-4-5@20250929'),
              ],
            ),
          },
        ),
        bundled: true,
      );
      expect(svc.modelsOfProvider('google-vertex-anthropic').map((m) => m.id), [
        'claude-opus-4-5@20251101',
        'claude-sonnet-4-5@20250929',
      ]);

      final changed = await svc.refresh(force: true);
      expect(changed, isTrue);
      expect(svc.modelsOfProvider('google-vertex-anthropic'), isEmpty);
      expect(svc.modelsOfProvider('acme').map((m) => m.id), ['acme-1']);
    });
  });

  group('ensureLoaded', () {
    test('loads injected bundled trimmed JSON', () async {
      final svc = service(loadBundledJson: () async => _trimmedFixtureJson);
      await svc.ensureLoaded();
      expect(svc.isLoaded, isTrue);
      expect(svc.isBundled, isTrue);
      expect(svc.version, 1);
      expect(svc.data?.providers.containsKey('openai'), isTrue);
      await svc.ensureLoaded();
      expect(svc.version, 1);
    });

    test('prefers cache and deletes a corrupt cache file', () async {
      final cache = File('${tempDir.path}/$kModelCatalogCacheFileName');
      await cache.writeAsString(_trimmedFixtureJson);
      var bundledCalls = 0;
      final fromCache = service(
        loadBundledJson: () async {
          bundledCalls += 1;
          return _trimmedFixtureJson;
        },
      );
      await fromCache.ensureLoaded();
      expect(fromCache.isBundled, isFalse);
      expect(bundledCalls, 0);

      await cache.writeAsString('broken');
      final fromBroken = service(
        loadBundledJson: () async {
          bundledCalls += 1;
          return _trimmedFixtureJson;
        },
      );
      await fromBroken.ensureLoaded();
      expect(fromBroken.isBundled, isTrue);
      expect(bundledCalls, 1);
      expect(await cache.exists(), isFalse);
    });
  });
}

ProviderConfig _cfg({
  String id = 'test',
  String baseUrl = '',
  ProviderKind? kind,
  bool? vertexAI,
}) {
  return ProviderConfig(
    id: id,
    enabled: true,
    name: id,
    apiKey: '',
    baseUrl: baseUrl,
    providerType: kind,
    vertexAI: vertexAI,
  );
}

CatalogModel _model(String id, {String? family, int? context}) {
  return CatalogModel(id: id, name: id, family: family, contextLimit: context);
}

CatalogProvider _provider(
  String id, {
  String? api,
  required List<CatalogModel> models,
}) {
  return CatalogProvider(
    id: id,
    name: id,
    api: api,
    models: <String, CatalogModel>{for (final model in models) model.id: model},
  );
}

ModelCatalogData _matchingCatalog({DateTime? generatedAt}) {
  return ModelCatalogData(
    schemaVersion: 1,
    generatedAt: generatedAt ?? DateTime.utc(2026, 1, 1),
    providers: <String, CatalogProvider>{
      'openai': _provider(
        'openai',
        models: [_model('gpt-4o'), _model('gpt-4o-mini')],
      ),
      'anthropic': _provider(
        'anthropic',
        models: [_model('claude-sonnet-4.6'), _model('claude')],
      ),
      'deepseek': _provider(
        'deepseek',
        api: 'https://api.deepseek.com/v1',
        models: [_model('deepseek-chat'), _model('deepseek-v4.1-flash')],
      ),
      'zai': _provider('zai', models: [_model('glm-5.3-flash')]),
      'moonshotai': _provider('moonshotai', models: [_model('kimi-k3.1-pro')]),
      'google': _provider(
        'google',
        models: [_model('gemini-3.8-flash', context: 262144)],
      ),
      'zhipuai': _provider(
        'zhipuai',
        api: 'https://open.bigmodel.cn/api/paas/v4',
        models: [
          _model('glm-4'),
          _model('glm-5'),
          _model('glm-5.3'),
          _model('glm-5.3-flash'),
          _model('glm-5-3-flash-20261024'),
        ],
      ),
      'zhipuai-coding-plan': _provider(
        'zhipuai-coding-plan',
        api: 'https://open.bigmodel.cn/api/paas/v4',
        models: [_model('glm-4-coding')],
      ),
      'openrouter': _provider(
        'openrouter',
        api: 'https://openrouter.ai/api/v1',
        models: [
          _model('anthropic/claude-sonnet-4.6'),
          _model('deepseek/deepseek-chat:free'),
          _model('gpt-4o'),
          _model('z-ai/glm-5.3-flash'),
          _model('z-ai/glm-5'),
          _model('openrouter/auto'),
          _model('auto'),
          _model('default'),
          _model('free'),
          _model('loomy'),
          _model('model-3.1-20261024'),
        ],
      ),
      'google-vertex': _provider(
        'google-vertex',
        models: [_model('gemini-1.5-pro')],
      ),
    },
  );
}

const String _rawModelsDevPayload = '''
{
  "acme": {
    "id": "acme",
    "name": "Acme",
    "api": "https://api.acme.test/v1",
    "models": {
      "acme-1": {
        "id": "acme-1",
        "name": "Acme 1"
      }
    }
  }
}
''';

final String _trimmedFixtureJson = jsonEncode(
  parseModelsDevCatalog(<String, dynamic>{
    'openai': <String, dynamic>{
      'id': 'openai',
      'name': 'OpenAI',
      'models': <String, dynamic>{
        'gpt-4o': <String, dynamic>{'id': 'gpt-4o', 'name': 'GPT-4o'},
      },
    },
  }, generatedAt: DateTime.utc(2026, 1, 1)).toJson(),
);
