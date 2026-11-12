import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/providers/model_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/reasoning/reasoning_dialects.dart';
import 'package:Kelivo/core/services/model_catalog/catalog_entry.dart';
import 'package:Kelivo/core/services/model_catalog/model_catalog_service.dart';
import 'package:Kelivo/core/services/model_spec/model_spec_resolver.dart';
import 'package:Kelivo/core/services/model_spec/ollama_model_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProviderConfig _config([String url = 'http://127.0.0.1:11434/v1']) =>
    ProviderConfig(
      id: 'local',
      name: 'Local',
      enabled: true,
      apiKey: '',
      baseUrl: url,
      providerType: ProviderKind.openai,
    );

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

Map<String, dynamic> _tags(Map<String, String> models) => {
  'models': [
    for (final e in models.entries)
      {'name': e.key, 'model': e.key, 'digest': e.value},
  ],
};

ModelSpecResolver _resolver(OllamaModelService service) => ModelSpecResolver(
  ollama: service,
  catalog: ModelCatalogService()
    ..debugSetData(
      ModelCatalogData(
        schemaVersion: 1,
        generatedAt: DateTime(2026),
        providers: const {},
      ),
    ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'only local OpenAI endpoints are candidates, preserving proxy prefixes',
    () {
      for (final host in [
        'localhost',
        'ollama.localhost',
        '127.0.0.2',
        '10.0.0.2',
        '172.16.2.3',
        '172.31.255.1',
        '192.168.1.2',
        '169.254.2.3',
        '[::1]',
        '[fd00::123]',
        '[fe80::1]',
        '[::ffff:192.168.1.2]',
      ]) {
        final root = OllamaModelService.apiRoot(
          _config('http://$host:11434/ollama/v1/'),
        );
        expect(root?.path, '/ollama/api/', reason: host);
      }
      for (final host in [
        'api.openai.com',
        'ollama.example.com',
        '8.8.8.8',
        '172.15.0.1',
        '172.32.0.1',
        '192.169.0.1',
        '[2001:4860:4860::8888]',
      ]) {
        expect(
          OllamaModelService.apiRoot(_config('https://$host/v1')),
          isNull,
          reason: host,
        );
      }
      expect(
        OllamaModelService.apiRoot(
          _config().copyWith(providerType: ProviderKind.google),
        ),
        isNull,
      );
      expect(
        OllamaModelService.apiRoot(_config('file://localhost/v1')),
        isNull,
      );
    },
  );

  test('public services never create a discovery client', () async {
    final service = OllamaModelService(
      clientFactory: (_) => throw StateError('unexpected probe'),
    );
    expect(
      await service.fetchModels(_config('https://api.openai.com/v1'), {}),
      isNull,
    );
  });

  test(
    'discovery enriches resolver, corrects false positives and preserves manual overrides',
    () async {
      const id = 'huihui_ai/qwen3-abliterated:14b-v2';
      final service = OllamaModelService(
        clientFactory: (_) => MockClient((request) async {
          if (request.url.path.endsWith('/tags')) {
            return _json(_tags({id: 'digest1'}));
          }
          return _json({
            'capabilities': ['completion', 'vision', 'audio'],
            'thinking': {
              'values': [false],
              'default': false,
            },
          });
        }),
      );
      final resolver = _resolver(service);
      final config = _config();
      expect(resolver.spec(config, id).supportsReasoning, isTrue);
      final models = await OpenAIProvider(
        ollama: service,
        resolver: resolver,
      ).listModels(config);
      expect(models.single.id, id);
      final spec = resolver.spec(config, id);
      expect(spec.input, [Modality.text, Modality.image, Modality.audio]);
      expect(spec.abilities, isEmpty);
      expect(spec.reasoning.dialect, ReasoningDialect.none);
      expect(spec.reasoning.levels, isEmpty);

      final overridden = config.copyWith(
        modelOverrides: {
          'my-alias': {
            'apiModelId': id,
            'input': ['text'],
            'abilities': ['tool'],
            'reasoning': {'dialect': 'custom'},
          },
        },
      );
      final resolved = resolver.resolve(overridden, 'my-alias');
      expect(resolved.base.supportsImageInput, isTrue);
      expect(resolved.spec.input, [Modality.text]);
      expect(resolved.spec.abilities, [ModelAbility.tool]);
      expect(resolved.spec.reasoning.dialect, ReasoningDialect.custom);
      expect(resolved.sources[ModelSpecField.input], SpecSource.override);
      expect(resolver.spec(config.copyWith(useResponseApi: true), id).input, [
        Modality.text,
        Modality.image,
      ]);
    },
  );

  test(
    'named reasoning controls use only advertised efforts and the server default',
    () {
      final metadata = OllamaModelMetadata.fromJson({
        'capabilities': ['completion', 'tools', 'thinking'],
        'thinking': {
          'values': ['low', 'medium', 'high'],
          'default': 'medium',
        },
      })!;
      final spec = metadata.applyTo(
        ModelSpec(id: 'my-gpt', displayName: 'my-gpt'),
      );
      expect(spec.supportsTool, isTrue);
      expect(spec.reasoning.levels, [
        ReasoningLevel.low,
        ReasoningLevel.medium,
        ReasoningLevel.high,
      ]);
      expect(spec.reasoning.defaultLevel, ReasoningLevel.medium);
      expect(spec.reasoning.canDisable, isFalse);
      expect(
        applyReasoning(
          {},
          spec,
          const ReasoningRequest(ReasoningLevel.max),
          transport: ReasoningTransport.chatCompletions,
        ),
        {'reasoning_effort': 'high'},
      );
      expect(
        applyReasoning(
          {},
          spec,
          ReasoningRequest.off,
          transport: ReasoningTransport.chatCompletions,
        ),
        {'reasoning_effort': 'low'},
      );
    },
  );

  test(
    'boolean controls provide on/off, including models disabled by default',
    () {
      for (final defaultThinking in [false, true]) {
        final spec = OllamaModelMetadata.fromJson({
          'capabilities': ['completion', 'thinking'],
          'thinking': {
            'values': [false, true],
            'default': defaultThinking,
          },
        })!.applyTo(ModelSpec(id: 'qwen3', displayName: 'qwen3'));
        expect(spec.reasoning.levels, [ReasoningLevel.on]);
        expect(
          spec.reasoning.defaultLevel,
          defaultThinking ? ReasoningLevel.on : ReasoningLevel.off,
        );
        expect(
          applyReasoning(
            {},
            spec,
            ReasoningRequest.off,
            transport: ReasoningTransport.chatCompletions,
          ),
          {'reasoning_effort': 'none'},
        );
        expect(
          applyReasoning(
            {},
            spec,
            const ReasoningRequest(ReasoningLevel.on),
            transport: ReasoningTransport.chatCompletions,
          ),
          {'reasoning_effort': 'high'},
        );
        expect(
          applyReasoning(
            {},
            spec,
            ReasoningRequest.auto,
            transport: ReasoningTransport.chatCompletions,
          ),
          isEmpty,
        );
        expect(
          applyReasoning(
            {},
            spec,
            const ReasoningRequest(ReasoningLevel.on),
            transport: ReasoningTransport.responses,
          ),
          {
            'reasoning': {'effort': 'high', 'summary': 'auto'},
          },
        );
      }
    },
  );

  test('missing thinking metadata does not invent levels or an off switch', () {
    final spec = OllamaModelMetadata.fromJson({
      'capabilities': ['completion', 'thinking'],
    })!.applyTo(ModelSpec(id: 'custom', displayName: 'custom'));
    expect(spec.supportsReasoning, isTrue);
    expect(spec.reasoning.levels, isEmpty);
    expect(spec.reasoning.canDisable, isFalse);
    expect(spec.reasoning.defaultLevel, ReasoningLevel.auto);
  });

  test('embedding models are classified from capabilities, not their name', () {
    final spec = OllamaModelMetadata.fromJson({
      'capabilities': ['embedding'],
    })!.applyTo(ModelSpec(id: 'my-model', displayName: 'my-model'));
    expect(spec.type, ModelType.embedding);
    expect(spec.abilities, isEmpty);
  });

  test(
    'digest cache survives restart and only changed models are fetched again',
    () async {
      var digest = 'old';
      var showCalls = 0;
      http.Client client(ProviderConfig _) => MockClient((request) async {
        if (request.url.path.endsWith('/tags')) {
          return _json(_tags({'my-model': digest}));
        }
        showCalls++;
        return _json({
          'capabilities': ['completion', if (digest == 'new') 'vision'],
        });
      });
      final service = OllamaModelService(clientFactory: client);
      final config = _config();
      await service.fetchModels(config, {});
      await service.fetchModels(config, {});
      expect(showCalls, 1);
      final restored = OllamaModelService(clientFactory: client);
      final resolver = _resolver(restored);
      expect(resolver.spec(config, 'my-model').supportsImageInput, isFalse);
      await restored.ensureLoaded();
      expect(restored.lookup(config, 'my-model'), isNotNull);
      await restored.fetchModels(config, {});
      expect(showCalls, 1);
      digest = 'new';
      await restored.fetchModels(config, {});
      expect(showCalls, 2);
      expect(resolver.spec(config, 'my-model').supportsImageInput, isTrue);
    },
  );

  test(
    'metadata is isolated by provider, endpoint and credentials, including memo hits',
    () async {
      final service = OllamaModelService(
        clientFactory: (_) => MockClient(
          (request) async => _json(
            request.url.path.endsWith('/tags')
                ? _tags({'my-model': 'digest'})
                : {
                    'capabilities': ['completion', 'vision'],
                  },
          ),
        ),
      );
      final config = _config().copyWith(apiKey: 'secret-token');
      final resolver = _resolver(service);
      await service.fetchModels(config, {});
      expect(resolver.spec(config, 'my-model').supportsImageInput, isTrue);
      for (final other in [
        config.copyWith(id: 'other'),
        config.copyWith(apiKey: 'another-token'),
        config.copyWith(baseUrl: 'http://127.0.0.1:11435/v1'),
        config.copyWith(
          customHeaders: [
            {'name': 'X-Tenant', 'value': 'other'},
          ],
        ),
      ]) {
        expect(resolver.spec(other, 'my-model').supportsImageInput, isFalse);
      }
      final raw = (await SharedPreferences.getInstance()).getString(
        OllamaModelService.cacheKey,
      )!;
      expect(raw, isNot(contains('secret-token')));
    },
  );

  test('negative probes are cached briefly and then retried', () async {
    var now = DateTime(2026);
    var requests = 0;
    final service = OllamaModelService(
      now: () => now,
      clientFactory: (_) => MockClient((_) async {
        requests++;
        return _json({'data': []});
      }),
    );
    expect(await service.fetchModels(_config(), {}), isNull);
    expect(await service.fetchModels(_config(), {}), isNull);
    expect(requests, 1);
    now = now.add(const Duration(minutes: 6));
    expect(await service.fetchModels(_config(), {}), isNull);
    expect(requests, 2);
  });

  test(
    'show failures retain the list but invalidate stale metadata for a new digest',
    () async {
      var failed = false;
      final service = OllamaModelService(
        clientFactory: (_) => MockClient((request) async {
          if (request.url.path.endsWith('/tags')) {
            return _json(_tags({'m': failed ? 'new' : 'old'}));
          }
          return failed
              ? _json({'error': 'missing'}, 404)
              : _json({
                  'capabilities': ['completion', 'vision'],
                });
        }),
      );
      await service.fetchModels(_config(), {});
      expect(service.lookup(_config(), 'm'), isNotNull);
      failed = true;
      expect(await service.fetchModels(_config(), {}), ['m']);
      expect(service.lookup(_config(), 'm'), isNull);
    },
  );

  test(
    'removed models are evicted and concurrent discovery is deduplicated',
    () async {
      var tagsCalls = 0;
      var models = {'m': 'digest'};
      final service = OllamaModelService(
        clientFactory: (_) => MockClient((request) async {
          if (request.url.path.endsWith('/tags')) {
            tagsCalls++;
            await Future<void>.delayed(const Duration(milliseconds: 5));
            return _json(_tags(models));
          }
          if (request.url.path.endsWith('/version')) {
            return _json({'version': '0.40.0'});
          }
          return _json({
            'capabilities': ['completion'],
          });
        }),
      );
      await Future.wait([
        service.fetchModels(_config(), {}),
        service.fetchModels(_config(), {}),
      ]);
      expect(tagsCalls, 1);
      models = {};
      expect(await service.fetchModels(_config(), {}), isEmpty);
      expect(service.lookup(_config(), 'm'), isNull);
    },
  );

  test(
    'slow and redirected probes fail quietly without following redirects',
    () async {
      final slow = OllamaModelService(
        requestTimeout: const Duration(milliseconds: 5),
        clientFactory: (_) =>
            MockClient((_) => Completer<http.Response>().future),
      );
      expect(await slow.fetchModels(_config(), {}), isNull);
      final redirected = OllamaModelService(
        clientFactory: (_) => MockClient((request) async {
          expect(request.followRedirects, isFalse);
          return http.Response(
            '',
            302,
            headers: {'location': 'https://example.com/api/tags'},
          );
        }),
      );
      expect(await redirected.fetchModels(_config(), {}), isNull);
    },
  );

  test(
    'native discovery forwards provider headers and falls back to the normal list',
    () async {
      final paths = <String>[];
      var native = false;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        paths.add(request.uri.path);
        expect(request.headers.value('authorization'), 'Bearer configured-key');
        expect(request.headers.value('x-provider'), 'custom');
        request.response.headers.contentType = ContentType.json;
        if (native) {
          if (request.uri.path.endsWith('/tags')) {
            request.response.write(
              jsonEncode(_tags({'native-model': 'digest'})),
            );
          } else {
            expect(request.uri.path, '/proxy/api/show');
            expect(request.method, 'POST');
            expect(jsonDecode(await utf8.decoder.bind(request).join()), {
              'model': 'native-model',
            });
            request.response.write(
              jsonEncode({
                'capabilities': ['completion', 'vision'],
              }),
            );
          }
          await request.response.close();
          return;
        }
        request.response.write(
          jsonEncode(
            request.uri.path.endsWith('/tags')
                ? {'not': 'ollama'}
                : {
                    'data': [
                      {'id': 'normal-model'},
                    ],
                  },
          ),
        );
        await request.response.close();
      });
      final service = OllamaModelService();
      final models =
          await OpenAIProvider(
            ollama: service,
            resolver: _resolver(service),
          ).listModels(
            _config('http://127.0.0.1:${server.port}/proxy/v1').copyWith(
              apiKey: 'configured-key',
              customHeaders: [
                {'name': 'X-Provider', 'value': 'custom'},
              ],
            ),
          );
      expect(models.single.id, 'normal-model');
      expect(paths, ['/proxy/api/tags', '/proxy/v1/models']);
      native = true;
      final nativeService = OllamaModelService();
      final nativeModels =
          await OpenAIProvider(
            ollama: nativeService,
            resolver: _resolver(nativeService),
          ).listModels(
            _config('http://127.0.0.1:${server.port}/proxy/v1').copyWith(
              apiKey: 'configured-key',
              customHeaders: [
                {'name': 'X-Provider', 'value': 'custom'},
              ],
            ),
          );
      expect(nativeModels.single.id, 'native-model');
      expect(nativeModels.single.supportsImageInput, isTrue);
      expect(paths.skip(2), ['/proxy/api/tags', '/proxy/api/show']);
    },
  );

  test(
    'server metadata is refreshed after a day even when the model digest is unchanged',
    () async {
      var now = DateTime(2026);
      var showCalls = 0;
      final service = OllamaModelService(
        now: () => now,
        clientFactory: (_) => MockClient((request) async {
          if (request.url.path.endsWith('/tags')) {
            return _json(_tags({'m': 'digest'}));
          }
          showCalls++;
          return _json({
            'capabilities': ['completion', if (showCalls > 1) 'thinking'],
          });
        }),
      );
      await service.fetchModels(_config(), {});
      now = now.add(const Duration(days: 2));
      await service.fetchModels(_config(), {});
      expect(showCalls, 2);
      expect(
        service.lookup(_config(), 'm')!.capabilities,
        contains('thinking'),
      );
    },
  );

  test(
    'Ollama default registry, namespace and tag aliases share discovered capabilities',
    () async {
      final service = OllamaModelService(
        clientFactory: (_) => MockClient((request) async {
          return _json(
            request.url.path.endsWith('/tags')
                ? _tags({
                    'qwen3:latest': 'digest',
                    'registry.local:5000/team/custom:latest': 'custom-digest',
                  })
                : {
                    'capabilities': ['completion', 'vision'],
                  },
          );
        }),
      );
      await service.fetchModels(_config(), {});
      final resolver = _resolver(service);
      for (final id in [
        'qwen3',
        'Qwen3:Latest',
        'library/qwen3',
        'registry.ollama.ai/library/qwen3:latest',
        'https://registry.ollama.ai/library/qwen3',
      ]) {
        final spec = resolver.spec(
          _config().copyWith(
            modelOverrides: {
              'alias': {'apiModelId': id},
            },
          ),
          'alias',
        );
        expect(spec.supportsImageInput, isTrue, reason: id);
        expect(spec.supportsReasoning, isFalse, reason: id);
      }
      expect(
        service.lookup(_config(), 'registry.local:5000/team/custom'),
        isNotNull,
      );
      expect(service.lookup(_config(), 'qwen3:other'), isNull);
      expect(service.lookup(_config(), 'team/qwen3'), isNull);
    },
  );

  test(
    'request timeout aborts a real connection to an unresponsive local service',
    () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final disconnected = Completer<void>();
      final sockets = <Socket>[];
      addTearDown(() async {
        for (final socket in sockets) {
          socket.destroy();
        }
        await server.close();
      });
      server.listen((socket) {
        sockets.add(socket);
        socket.listen(
          (_) {},
          onDone: () {
            if (!disconnected.isCompleted) disconnected.complete();
          },
          onError: (Object _) {
            if (!disconnected.isCompleted) disconnected.complete();
          },
        );
      });
      final service = OllamaModelService(
        requestTimeout: const Duration(milliseconds: 100),
      );
      expect(
        await service.fetchModels(
          _config('http://127.0.0.1:${server.port}/v1'),
          {},
        ),
        isNull,
      );
      expect(sockets, hasLength(1));
      await disconnected.future.timeout(const Duration(seconds: 2));
    },
  );

  test(
    'discovery budget preserves completed metadata and stops further batches',
    () async {
      var slow = true;
      final shows = <String, int>{};
      final service = OllamaModelService(
        discoveryTimeout: const Duration(milliseconds: 30),
        requestTimeout: const Duration(seconds: 1),
        clientFactory: (_) => MockClient((request) async {
          if (request.url.path.endsWith('/tags')) {
            return _json(
              _tags({for (var i = 0; i < 8; i++) 'm$i': 'digest$i'}),
            );
          }
          final id = (jsonDecode(request.body) as Map)['model'] as String;
          shows[id] = (shows[id] ?? 0) + 1;
          if (slow && id != 'm0') {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
          return _json({
            'capabilities': ['completion', 'vision'],
          });
        }),
      );
      expect(await service.fetchModels(_config(), {}), hasLength(8));
      expect(service.lookup(_config(), 'm0'), isNotNull);
      expect(shows, hasLength(4));
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(shows, hasLength(4));
      slow = false;
      await service.fetchModels(_config(), {});
      expect(shows['m0'], 1);
      expect(service.lookup(_config(), 'm7'), isNotNull);
    },
  );
}
