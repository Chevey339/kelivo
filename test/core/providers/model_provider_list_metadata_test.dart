import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/providers/model_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/model_catalog/catalog_entry.dart';
import 'package:Kelivo/core/services/model_catalog/model_catalog_service.dart';
import 'package:Kelivo/core/services/model_spec/model_spec_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ModelCatalogService.instance.debugSetData(
      ModelCatalogData(
        schemaVersion: 1,
        generatedAt: DateTime.utc(2026),
        providers: const {},
      ),
    );
  });

  test(
    'Vertex publisher pages retain model names, limits, and media-only entries',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var pages = 0;
      server.listen((request) async {
        pages++;
        expect(request.uri.path, '/proxy/v1beta1/publishers/google/models');
        expect(request.headers.value('authorization'), 'Bearer test-key');
        request.response.headers.contentType = ContentType.json;
        if (request.uri.queryParameters['pageToken'] == null) {
          request.response.write(
            jsonEncode({
              'publisherModels': [
                {
                  'name': 'publishers/google/models/gemini-3-pro',
                  'displayName': 'Gemini Pro',
                  'inputTokenLimit': 123456,
                },
              ],
              'nextPageToken': 'page+2',
            }),
          );
        } else {
          expect(request.uri.queryParameters['pageToken'], 'page+2');
          request.response.write(
            jsonEncode({
              'publisherModels': [
                {
                  'name': 'publishers/google/models/veo-3.1-generate-001',
                  'supportedGenerationMethods': ['predictLongRunning'],
                },
              ],
            }),
          );
        }
        await request.response.close();
      });
      final cfg = ProviderConfig(
        id: 'vertex',
        enabled: true,
        name: 'Vertex',
        apiKey: 'test-key',
        providerType: ProviderKind.google,
        vertexAI: true,
        location: 'global',
        projectId: 'project',
        baseUrl: 'http://127.0.0.1:${server.port}/proxy',
      );
      final listed = await ProviderManager.listModels(cfg);
      expect(pages, 2);
      expect(
        listed.map((m) => m.id),
        containsAll(['gemini-3-pro', 'veo-3.1-generate-001']),
      );
      expect(
        listed.firstWhere((m) => m.id == 'gemini-3-pro').contextWindow,
        123456,
      );
    },
  );

  test(
    'partial Google discovery returns the available page while retaining cached capabilities',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var incomplete = false;
      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        if (request.uri.queryParameters['pageToken'] != null) {
          request.response.statusCode = 503;
        } else {
          request.response.write(
            jsonEncode({
              'models': [
                {
                  'name': incomplete ? 'models/page-one' : 'models/cached',
                  'inputTokenLimit': 51234,
                },
              ],
              if (incomplete) 'nextPageToken': 'two',
            }),
          );
        }
        await request.response.close();
      });
      final cfg = ProviderConfig(
        id: 'google-pages',
        enabled: true,
        name: 'Google',
        apiKey: 'test-key',
        providerType: ProviderKind.google,
        baseUrl: 'http://127.0.0.1:${server.port}/v1beta',
      );
      await ProviderManager.listModels(cfg);
      incomplete = true;
      expect((await ProviderManager.listModels(cfg)).map((m) => m.id), [
        'page-one',
      ]);
      expect(
        ModelSpecResolver.instance.spec(cfg, 'cached').contextWindow,
        51234,
      );
    },
  );

  for (final kind in ProviderKind.values) {
    test(
      '$kind list caches numeric fields before resolving and retains them on failure',
      () async {
        const model = 'relay/[times] ExampleModel';
        const displayName = 'Example model';
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        var status = 200;
        final List<Map<String, Object>> rows = [
          if (kind == ProviderKind.google)
            {
              'name': 'models/$model',
              'displayName': displayName,
              'inputTokenLimit': 262144,
              'outputTokenLimit': '16384',
            }
          else
            {
              'id': model,
              'display_name': displayName,
              'context_length': '262144',
              'max_completion_tokens': 16384,
              'pricing': {'completion': '0.0000025'},
            },
        ];
        server.listen((request) async {
          if (request.uri.path == '/api/tags') {
            request.response.statusCode = HttpStatus.notFound;
            await request.response.close();
            return;
          }
          expect(request.uri.path, '/v1/models');
          request.response.statusCode = status;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              (kind == ProviderKind.google ? 'models' : 'data'): rows,
            }),
          );
          await request.response.close();
        });
        final cfg = ProviderConfig(
          id: 'list-${kind.name}',
          enabled: true,
          name: 'Test relay',
          apiKey: 'test-key',
          baseUrl: 'http://${server.address.address}:${server.port}/v1',
          providerType: kind,
        );
        final listed = (await ProviderManager.listModels(cfg)).single;
        expect(listed.id, model);
        expect(
          listed.displayName,
          kind == ProviderKind.openai ? model : displayName,
        );
        expect(listed.contextWindow, 262144);
        expect(listed.maxOutput, 16384);
        expect(
          listed.pricing?.output,
          kind == ProviderKind.google ? null : 2.5,
        );

        final resolver = ModelSpecResolver.instance;
        expect(
          resolver.resolve(cfg, model).sources[ModelSpecField.contextWindow],
          SpecSource.vendor,
        );
        expect(
          resolver.spec(cfg, '[times] ExampleModel').contextWindow,
          isNull,
        );
        expect(cfg.modelOverrides, isEmpty);
        rows.clear();
        status = 503;
        expect(await ProviderManager.listModels(cfg), isEmpty);
        expect(resolver.spec(cfg, model).contextWindow, 262144);

        status = 200;
        expect(await ProviderManager.listModels(cfg), isEmpty);
        expect(resolver.spec(cfg, model).contextWindow, isNull);
      },
    );
  }
}
