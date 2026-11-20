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
