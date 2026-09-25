import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/model_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/model_catalog/catalog_entry.dart';
import 'package:Kelivo/core/services/model_catalog/model_catalog_service.dart';

late HttpServer server;

void main() {
  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'models': [
            {
              'name': 'models/gemini-2.5-pro',
              'displayName': 'Gemini 2.5 Pro',
              'supportedGenerationMethods': ['generateContent'],
            },
            {
              'name': 'models/claude-opus-4-5@20251101',
              'displayName': 'Claude Opus 4.5',
              'supportedGenerationMethods': ['generateContent'],
            },
          ],
        }),
      );
      await request.response.close();
    });
  });

  test(
    'Vertex listing merges catalog Anthropic models without duplicates',
    () async {
      ModelCatalogService.instance.debugSetData(
        _vertexAnthropicCatalog(const [
          'claude-opus-4-5@20251101',
          'claude-sonnet-4-5@20250929',
          'claude-haiku-4-5@20251001',
        ]),
      );

      final ids = await _listIds(vertexAI: true, baseUrl: _baseUrl());
      expect(ids, contains('gemini-2.5-pro'));
      expect(ids, contains('claude-opus-4-5@20251101'));
      expect(ids, contains('claude-sonnet-4-5@20250929'));
      expect(ids, contains('claude-haiku-4-5@20251001'));
      expect(ids.where((id) => id == 'claude-opus-4-5@20251101').length, 1);
    },
  );

  test('Vertex listing uses the catalog snapshot after a refresh', () async {
    ModelCatalogService.instance.debugSetData(
      _vertexAnthropicCatalog(const ['claude-sonnet-4@20250514']),
    );
    var ids = await _listIds(vertexAI: true, baseUrl: _baseUrl());
    expect(ids, contains('claude-sonnet-4@20250514'));
    expect(ids, isNot(contains('claude-fable-5-1@default')));

    ModelCatalogService.instance.debugSetData(
      _vertexAnthropicCatalog(const ['claude-fable-5-1@default']),
    );
    ids = await _listIds(vertexAI: true, baseUrl: _baseUrl());
    expect(ids, contains('claude-fable-5-1@default'));
    expect(ids, isNot(contains('claude-sonnet-4@20250514')));
  });

  test(
    'non-Vertex Google listing does not inject catalog Anthropic models',
    () async {
      ModelCatalogService.instance.debugSetData(
        _vertexAnthropicCatalog(const ['claude-sonnet-4-5@20250929']),
      );

      final ids = await _listIds(vertexAI: false, baseUrl: _baseUrl());
      expect(ids, ['gemini-2.5-pro', 'claude-opus-4-5@20251101']);
    },
  );
}

String _baseUrl() => 'http://${server.address.address}:${server.port}/v1';

Future<List<String>> _listIds({
  required bool vertexAI,
  required String baseUrl,
}) async {
  final models = await ProviderManager.listModels(
    ProviderConfig(
      id: 'VertexCatalogTest',
      enabled: true,
      name: 'VertexCatalogTest',
      apiKey: 'test-key',
      baseUrl: baseUrl,
      providerType: ProviderKind.google,
      vertexAI: vertexAI,
    ),
  );
  return [for (final model in models) model.id];
}

ModelCatalogData _vertexAnthropicCatalog(List<String> modelIds) {
  return ModelCatalogData(
    schemaVersion: 1,
    generatedAt: DateTime.utc(2026, 9, 15),
    providers: {
      'google-vertex-anthropic': CatalogProvider(
        id: 'google-vertex-anthropic',
        name: 'Vertex (Anthropic)',
        models: {for (final id in modelIds) id: CatalogModel(id: id, name: id)},
      ),
    },
  );
}
