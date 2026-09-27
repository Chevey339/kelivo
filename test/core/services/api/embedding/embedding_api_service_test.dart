import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/api_keys.dart';
import 'package:Kelivo/core/providers/model_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/embedding/embedding_api_service.dart';
import 'package:Kelivo/core/services/api/providers/google_vertex.dart';

class _Server {
  _Server._(this._server);

  final HttpServer _server;
  final requests = <({String path, Map<String, String> headers, Map body})>[];
  late Map<String, dynamic> Function(Map body) respond;

  String get origin => 'http://${_server.address.host}:${_server.port}';

  static Future<_Server> start() async {
    final s = _Server._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));
    s._server.listen((req) async {
      final body = jsonDecode(await utf8.decoder.bind(req).join()) as Map;
      final headers = <String, String>{};
      req.headers.forEach((k, v) => headers[k] = v.join(','));
      s.requests.add((path: req.uri.path, headers: headers, body: body));
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode(s.respond(body)));
      await req.response.close();
    });
    return s;
  }

  Future<void> close() => _server.close(force: true);
}

ProviderConfig _cfg(
  String baseUrl,
  ProviderKind kind, {
  Map<String, dynamic> overrides = const {},
  bool vertex = false,
  String location = 'us-central1',
  List<ApiKeyConfig>? apiKeys,
}) {
  return ProviderConfig(
    id: 'Embed',
    enabled: true,
    name: 'Embed',
    apiKey: apiKeys == null ? 'test-key' : '',
    multiKeyEnabled: apiKeys != null,
    apiKeys: apiKeys,
    baseUrl: baseUrl,
    providerType: kind,
    models: const ['embed-model'],
    modelOverrides: {
      'embed-model': {'type': 'embedding', ...overrides},
    },
    vertexAI: vertex ? true : null,
    location: vertex ? location : null,
    projectId: vertex ? 'proj' : null,
  );
}

void main() {
  late _Server server;

  setUp(() async => server = await _Server.start());
  tearDown(() => server.close());

  test('OpenAI-compatible batches inputs and keeps index order', () async {
    server.respond = (body) {
      final input = (body['input'] as List).cast<String>();
      return {
        'data': [
          for (var i = input.length - 1; i >= 0; i--)
            {
              'index': i,
              'embedding': [input[i].length.toDouble(), 1],
            },
        ],
        'usage': {'prompt_tokens': input.length, 'total_tokens': input.length},
      };
    };
    final inputs = [for (var i = 1; i <= 12; i++) 'x' * i];
    final result = await EmbeddingApiService.embed(
      config: _cfg(
        '${server.origin}/v1',
        ProviderKind.openai,
        overrides: {
          'apiModelId': 'text-embedding-3-small',
          'headers': [
            {'name': 'X-Custom', 'value': 'yes'},
          ],
          'body': [
            {'key': 'user', 'value': 'kelivo'},
          ],
        },
      ),
      modelId: 'embed-model',
      inputs: inputs,
      dimensions: 256,
    );

    expect(result.vectors.map((v) => v.first), [
      for (var i = 1; i <= 12; i++) i.toDouble(),
    ]);
    expect(result.promptTokens, 12);
    expect(server.requests.map((r) => (r.body['input'] as List).length), [
      10,
      2,
    ]);
    final first = server.requests.first;
    expect(first.path, '/v1/embeddings');
    expect(first.headers['authorization'], 'Bearer test-key');
    expect(first.headers['x-custom'], 'yes');
    expect(first.body['model'], 'text-embedding-3-small');
    expect(first.body['dimensions'], 256);
    expect(first.body.containsKey('encoding_format'), isFalse);
    expect(first.body['user'], 'kelivo');
  });

  test('Gemini uses batchEmbedContents with the task type', () async {
    server.respond = (body) => {
      'embeddings': [
        for (final _ in body['requests'] as List)
          {
            'values': [0.5, -0.5],
          },
      ],
    };
    final result = await EmbeddingApiService.embed(
      config: _cfg('${server.origin}/v1beta', ProviderKind.google),
      modelId: 'embed-model',
      inputs: const ['a', 'b'],
      task: EmbeddingTask.query,
      dimensions: 768,
    );

    expect(result.vectors, [
      [0.5, -0.5],
      [0.5, -0.5],
    ]);
    final req = server.requests.single;
    expect(req.path, '/v1beta/models/embed-model:batchEmbedContents');
    expect(req.headers['x-goog-api-key'], 'test-key');
    expect(req.body['requests'][0], {
      'model': 'models/embed-model',
      'content': {
        'parts': [
          {'text': 'a'},
        ],
      },
      'taskType': 'RETRIEVAL_QUERY',
      'outputDimensionality': 768,
    });
  });

  test('Gemini Embedding 2 takes the task as a text prefix', () async {
    server.respond = (body) => {
      'embeddings': [
        for (final _ in body['requests'] as List)
          {
            'values': [1],
          },
      ],
      'usageMetadata': {'promptTokenCount': 7},
    };
    final result = await EmbeddingApiService.embed(
      config: _cfg(
        '${server.origin}/v1beta',
        ProviderKind.google,
        overrides: {'apiModelId': 'gemini-embedding-2'},
      ),
      modelId: 'embed-model',
      inputs: const ['a'],
      task: EmbeddingTask.document,
    );

    expect(result.promptTokens, 7);
    final request = server.requests.single.body['requests'][0] as Map;
    expect(request.containsKey('taskType'), isFalse);
    expect(request['content'], {
      'parts': [
        {'text': 'title: none | text: a'},
      ],
    });
  });

  test(
    'Vertex Gemini Embedding 2 uses embedContent in the configured location',
    () async {
      server.respond = (body) => {
        'embedding': {
          'values': [3, 4],
        },
        'usageMetadata': {'promptTokenCount': 2},
      };
      final result = await EmbeddingApiService.embed(
        config: _cfg(
          server.origin,
          ProviderKind.google,
          vertex: true,
          location: 'eu',
          overrides: {'apiModelId': 'gemini-embedding-2'},
        ),
        modelId: 'embed-model',
        inputs: const ['a', 'b'],
        task: EmbeddingTask.query,
        dimensions: 512,
      );

      expect(result.vectors, [
        [3.0, 4.0],
        [3.0, 4.0],
      ]);
      expect(result.promptTokens, 4);
      final first = server.requests.first;
      expect(
        first.path,
        '/v1/projects/proj/locations/eu/publishers/google/models/gemini-embedding-2:embedContent',
      );
      expect(first.body, {
        'content': {
          'parts': [
            {'text': 'task: search result | query: a'},
          ],
        },
        'outputDimensionality': 512,
      });
    },
  );

  test('Vertex authenticates with the selected multi-key entry', () async {
    server.respond = (_) => {
      'predictions': [
        {
          'embeddings': {
            'values': [1],
          },
        },
      ],
    };
    await EmbeddingApiService.embed(
      config: _cfg(
        server.origin,
        ProviderKind.google,
        vertex: true,
        apiKeys: [
          const ApiKeyConfig(
            id: 'k1',
            key: 'pooled-token',
            createdAt: 1,
            updatedAt: 1,
          ),
        ],
      ),
      modelId: 'embed-model',
      inputs: const ['a'],
    );

    expect(
      server.requests.single.headers['authorization'],
      'Bearer pooled-token',
    );
  });

  test('Vertex origin replaces a kept Gemini API base URL', () {
    final cfg = _cfg(
      'https://generativelanguage.googleapis.com/v1beta',
      ProviderKind.google,
      vertex: true,
    );
    expect(
      vertexOrigin(cfg, 'us-central1'),
      'https://us-central1-aiplatform.googleapis.com',
    );
    expect(vertexOrigin(cfg, 'global'), 'https://aiplatform.googleapis.com');
    expect(vertexOrigin(cfg, 'eu'), 'https://aiplatform.eu.rep.googleapis.com');
    final multiRegion = _cfg(
      'https://aiplatform.us.rep.googleapis.com',
      ProviderKind.google,
      vertex: true,
    );
    expect(
      vertexOrigin(multiRegion, 'eu'),
      'https://aiplatform.eu.rep.googleapis.com',
    );
    final psc = _cfg(
      'https://xyz-aiplatform.p.googleapis.com',
      ProviderKind.google,
      vertex: true,
    );
    expect(
      vertexOrigin(psc, 'us-central1'),
      'https://xyz-aiplatform.p.googleapis.com',
    );
  });

  test('experimental 001-era embedding ids keep taskType', () async {
    server.respond = (body) => {
      'embeddings': [
        {
          'values': [1],
        },
      ],
    };
    await EmbeddingApiService.embed(
      config: _cfg(
        '${server.origin}/v1beta',
        ProviderKind.google,
        overrides: {'apiModelId': 'gemini-embedding-exp-03-07'},
      ),
      modelId: 'embed-model',
      inputs: const ['a'],
      task: EmbeddingTask.query,
    );

    final request = server.requests.single.body['requests'][0] as Map;
    expect(request['taskType'], 'RETRIEVAL_QUERY');
  });

  test('Vertex sends one instance per predict call', () async {
    server.respond = (body) => {
      'predictions': [
        {
          'embeddings': {
            'values': [1, 2],
            'statistics': {'token_count': 3},
          },
        },
      ],
    };
    final result = await EmbeddingApiService.embed(
      config: _cfg(server.origin, ProviderKind.google, vertex: true),
      modelId: 'embed-model',
      inputs: const ['a', 'b'],
      task: EmbeddingTask.document,
    );

    expect(result.vectors, [
      [1.0, 2.0],
      [1.0, 2.0],
    ]);
    expect(result.promptTokens, 6);
    expect(server.requests, hasLength(2));
    expect(
      server.requests.first.path,
      '/v1/projects/proj/locations/us-central1/publishers/google/models/embed-model:predict',
    );
    expect(server.requests.first.body['instances'], [
      {'content': 'a', 'task_type': 'RETRIEVAL_DOCUMENT'},
    ]);
    expect(server.requests.first.headers['authorization'], 'Bearer test-key');
  });

  test('provider body keeps embedding fields and drops chat fields', () async {
    server.respond = (_) => {
      'data': [
        {
          'index': 0,
          'embedding': [1],
        },
      ],
    };
    await EmbeddingApiService.embed(
      config: _cfg('${server.origin}/v1', ProviderKind.openai).copyWith(
        customBody: const [
          {'key': 'temperature', 'value': '0.2'},
          {'key': 'dimensions', 'value': '256'},
          {'key': 'user', 'value': 'provider'},
        ],
        modelOverrides: {
          'embed-model': {
            'type': 'embedding',
            'body': [
              {'key': 'user', 'value': 'model'},
            ],
          },
        },
      ),
      modelId: 'embed-model',
      inputs: const ['a'],
    );

    final body = server.requests.single.body;
    expect(body.containsKey('temperature'), isFalse);
    expect(body['dimensions'], 256);
    expect(body['user'], 'model');
  });

  test('a response missing vectors fails instead of misaligning', () async {
    server.respond = (_) => {'data': <Object>[]};
    await expectLater(
      EmbeddingApiService.embed(
        config: _cfg('${server.origin}/v1', ProviderKind.openai),
        modelId: 'embed-model',
        inputs: const ['a'],
      ),
      throwsFormatException,
    );
  });

  test('Anthropic has no embeddings endpoint', () {
    expect(
      EmbeddingApiService.embed(
        config: _cfg(server.origin, ProviderKind.claude),
        modelId: 'embed-model',
        inputs: const ['a'],
      ),
      throwsUnsupportedError,
    );
  });

  test('HTTP errors surface with the response body', () async {
    final dead = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => dead.close(force: true));
    dead.listen((req) async {
      req.response.statusCode = HttpStatus.notFound;
      req.response.write('no embeddings here');
      await req.response.close();
    });
    await expectLater(
      EmbeddingApiService.embed(
        config: _cfg(
          'http://${dead.address.host}:${dead.port}',
          ProviderKind.openai,
        ),
        modelId: 'embed-model',
        inputs: const ['a'],
      ),
      throwsA(
        isA<HttpException>().having(
          (e) => e.message,
          'message',
          contains('no embeddings here'),
        ),
      ),
    );
  });

  test(
    'connection test of an embedding model calls the embeddings API',
    () async {
      server.respond = (_) => {
        'data': [
          {
            'index': 0,
            'embedding': [0.1],
          },
        ],
      };
      await ProviderManager.testConnection(
        _cfg('${server.origin}/v1', ProviderKind.openai),
        'embed-model',
        useStream: true,
      );

      expect(server.requests.single.path, '/v1/embeddings');
      expect(server.requests.single.body['input'], ['hello']);
    },
  );
}
