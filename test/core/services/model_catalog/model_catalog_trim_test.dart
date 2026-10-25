import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/model_catalog/model_catalog_trim.dart';

void main() {
  final generatedAt = DateTime.utc(2026, 9, 15, 12);

  Map<String, dynamic> rawFixture() {
    return jsonDecode(_rawFixtureJson) as Map<String, dynamic>;
  }

  Map<String, dynamic> trimmedFixture() {
    return trimModelsDevJson(rawFixture(), generatedAt: generatedAt);
  }

  test('trims providers and skips malformed entries', () {
    final trimmed = trimmedFixture();
    final providers = trimmed['providers'] as Map<String, dynamic>;

    expect(trimmed['schemaVersion'], 1);
    expect(trimmed['generatedAt'], '2026-09-15T12:00:00.000Z');
    expect(providers.keys, ['openai', 'deepseek', 'acme']);
    expect(providers.containsKey('broken'), isFalse);

    final openai = providers['openai'] as Map<String, dynamic>;
    expect(openai.containsKey('api'), isFalse);
    expect(openai['id'], 'openai');
    expect(openai['name'], 'OpenAI');

    final models = openai['models'] as Map<String, dynamic>;
    expect(models.keys, ['gpt-test', 'gpt-old']);
    expect(models.containsKey('missing-id'), isFalse);

    final acmeModels =
        (providers['acme'] as Map<String, dynamic>)['models'] as Map;
    expect(acmeModels.containsKey('no-id'), isFalse);
    expect(acmeModels.keys, ['acme-1']);
  });

  test('drops unused raw fields and extra cost keys', () {
    final trimmed = trimmedFixture();
    final providers = trimmed['providers'] as Map<String, dynamic>;
    final openai = providers['openai'] as Map<String, dynamic>;
    expect(openai.containsKey('env'), isFalse);
    expect(openai.containsKey('npm'), isFalse);
    expect(openai.containsKey('doc'), isFalse);

    final gptTest = (openai['models'] as Map)['gpt-test'] as Map;
    expect(gptTest.containsKey('description'), isFalse);
    expect(gptTest.containsKey('knowledge'), isFalse);
    expect(gptTest.containsKey('release_date'), isFalse);
    expect(gptTest.containsKey('last_updated'), isFalse);
    expect(gptTest.containsKey('open_weights'), isFalse);
    expect(gptTest.containsKey('experimental'), isFalse);
    expect(gptTest.containsKey('provider'), isFalse);
    expect(gptTest.containsKey('cost'), isFalse);
    expect(gptTest['il'], isTrue);
    expect(gptTest.containsKey('temp'), isFalse);

    final gptOld = (openai['models'] as Map)['gpt-old'] as Map;
    expect(gptOld['status'], 'deprecated');
    expect(gptOld['il'], {'field': 'reasoning_details'});
    final cost = gptOld['cost'] as Map;
    expect(cost.keys, ['input', 'output', 'cache_read', 'cache_write']);
    expect(cost.containsKey('reasoning'), isFalse);
    expect(cost.containsKey('input_audio'), isFalse);
    expect(cost.containsKey('tiers'), isFalse);

    final ro = gptOld['ro'] as List;
    expect(ro, [
      {
        'type': 'effort',
        'values': ['low', 'medium', 'high'],
      },
      {'type': 'budget_tokens', 'min': 256, 'max': 24000},
      {'type': 'toggle'},
    ]);
  });

  test('parseTrimmedCatalog round-trips trim output', () {
    final trimmed = trimmedFixture();
    final parsed = parseTrimmedCatalog(trimmed);
    expect(parsed.toJson(), trimmed);

    expect(parsed.providers['openai']!.api, isNull);
    expect(parsed.providers['openai']!.apiHost, isNull);
    expect(parsed.providers['deepseek']!.api, 'https://api.deepseek.com/v1');
    expect(parsed.providers['deepseek']!.apiHost, 'api.deepseek.com');
    expect(parsed.providers['acme']!.apiHost, 'api.acme.test');

    final gptTest = parsed.providers['openai']!.models['gpt-test']!;
    expect(gptTest.costInput, isNull);
    expect(gptTest.interleaved, isTrue);
    expect(gptTest.interleavedField, isNull);
    expect(gptTest.temperature, isTrue);
    expect(gptTest.attachment, isTrue);
    expect(gptTest.contextLimit, 128000);
    expect(gptTest.inputModalities, ['text', 'image']);

    final gptOld = parsed.providers['openai']!.models['gpt-old']!;
    expect(gptOld.status, 'deprecated');
    expect(gptOld.interleaved, isTrue);
    expect(gptOld.interleavedField, 'reasoning_details');
    expect(gptOld.reasoningOptions.map((o) => o.type), [
      'effort',
      'budget_tokens',
      'toggle',
    ]);
    expect(gptOld.reasoningOptions[0].values, ['low', 'medium', 'high']);
    expect(gptOld.reasoningOptions[1].min, 256);
    expect(gptOld.reasoningOptions[1].max, 24000);
    expect(gptOld.costInput, 1.0);
    expect(gptOld.costCacheWrite, 0.2);

    final chat = parsed.providers['deepseek']!.models['deepseek-chat']!;
    expect(chat.temperature, isFalse);
    expect(chat.reasoningOptions, isEmpty);
    expect(chat.costOutput, 0.28);
  });

  test('parseTrimmedCatalog rejects an invalid top-level shape', () {
    expect(
      () => parseTrimmedCatalog(<String, dynamic>{}),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => parseTrimmedCatalog(<String, dynamic>{
        'schemaVersion': 2,
        'providers': <String, dynamic>{},
      }),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => parseTrimmedCatalog(<String, dynamic>{'schemaVersion': 1}),
      throwsA(isA<FormatException>()),
    );
  });

  test('bundled snapshot parses with expected coverage', () {
    final file = File('assets/model_catalog/models_dev.json');
    expect(file.existsSync(), isTrue);
    final decoded = jsonDecode(file.readAsStringSync());
    expect(decoded, isA<Map<String, dynamic>>());
    final catalog = parseTrimmedCatalog(decoded as Map<String, dynamic>);
    var models = 0;
    for (final provider in catalog.providers.values) {
      models += provider.models.length;
    }
    expect(catalog.schemaVersion, 1);
    expect(catalog.providers.length, greaterThan(100));
    expect(models, greaterThan(5000));
    expect(
      catalog.providers['openai']!.models['gpt-5.1']!.contextLimit,
      400000,
    );
  });
}

const String _rawFixtureJson = r'''
{
  "openai": {
    "id": "openai",
    "name": "OpenAI",
    "env": ["OPENAI_API_KEY"],
    "npm": "@ai-sdk/openai",
    "doc": "https://platform.openai.com/docs/models",
    "models": {
      "gpt-test": {
        "id": "gpt-test",
        "name": "GPT Test",
        "description": "should be dropped",
        "family": "gpt",
        "attachment": true,
        "reasoning": true,
        "tool_call": true,
        "structured_output": true,
        "knowledge": "2024-09-30",
        "release_date": "2025-11-13",
        "last_updated": "2025-11-13",
        "open_weights": false,
        "experimental": true,
        "provider": "openai",
        "interleaved": true,
        "modalities": {"input": ["text", "image"], "output": ["text"]},
        "limit": {"context": 128000, "input": 100000, "output": 28000}
      },
      "gpt-old": {
        "id": "gpt-old",
        "name": "GPT Old",
        "status": "deprecated",
        "reasoning": true,
        "tool_call": false,
        "structured_output": false,
        "temperature": true,
        "attachment": false,
        "interleaved": {"field": "reasoning_details"},
        "reasoning_options": [
          {"type": "effort", "values": [null, "low", "medium", "high"]},
          {"type": "budget_tokens", "min": 256, "max": 24000},
          {"type": "toggle"}
        ],
        "modalities": {"input": ["text"], "output": ["text"]},
        "cost": {
          "input": 1.0,
          "output": 2.0,
          "cache_read": 0.1,
          "cache_write": 0.2,
          "reasoning": 99,
          "input_audio": 5,
          "output_audio": 6,
          "context_over_200k": 7,
          "tiers": []
        }
      },
      "missing-id": {
        "name": "No ID",
        "reasoning": true
      }
    }
  },
  "deepseek": {
    "id": "deepseek",
    "name": "DeepSeek",
    "api": "https://api.deepseek.com/v1",
    "models": {
      "deepseek-chat": {
        "id": "deepseek-chat",
        "name": "DeepSeek Chat",
        "reasoning": false,
        "tool_call": true,
        "temperature": false,
        "modalities": {"input": ["text"], "output": ["text"]},
        "limit": {"context": 64000},
        "cost": {"input": 0.14, "output": 0.28, "reasoning": 0.28}
      }
    }
  },
  "acme": {
    "id": "acme",
    "name": "Acme",
    "api": "https://api.acme.test/v1",
    "models": {
      "acme-1": {
        "id": "acme-1",
        "name": "Acme One",
        "reasoning": false,
        "tool_call": true,
        "structured_output": false,
        "modalities": {"input": ["text", "pdf"], "output": ["text"]}
      },
      "no-id": {
        "name": "Missing ID",
        "reasoning": true
      }
    }
  },
  "broken": "not-an-object"
}
''';
