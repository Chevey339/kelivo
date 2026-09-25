import 'dart:convert';
import 'dart:io' show HttpException;
import 'dart:math' show min;

import 'package:dio/dio.dart' show CancelToken;
import 'package:http/http.dart' as http;

import '../../../providers/settings_provider.dart';
import '../../auth/provider_oauth_service.dart';
import '../../custom_request_merger.dart';
import '../../network/provider_http_client.dart';
import '../chat_api_helpers.dart';
import '../provider_request_headers.dart';
import '../providers/google_vertex.dart';

/// What the vectors will be used for. Only Gemini uses it to tune the
/// embedding; other APIs ignore it.
enum EmbeddingTask { query, document }

class EmbeddingResult {
  const EmbeddingResult({required this.vectors, this.promptTokens});

  /// One vector per input, in input order.
  final List<List<double>> vectors;

  /// Billed input tokens, when the API reports them.
  final int? promptTokens;
}

/// Calls a provider's embeddings endpoint for a model of type embedding.
///
/// OpenAI-compatible providers use `/embeddings`, the Gemini API uses
/// `:batchEmbedContents`, and Vertex AI uses `:predict`. Anthropic has no
/// embeddings API.
class EmbeddingApiService {
  /// OpenAI-compatible vendors cap inputs per call differently (DashScope
  /// allows 10); this stays under the smallest common limit.
  static const int _openAIBatchSize = 10;
  static const int _geminiBatchSize = 100;

  /// Vertex `gemini-embedding-*` models accept one instance per `:predict`.
  static const int _vertexBatchSize = 1;

  static Future<EmbeddingResult> embed({
    required ProviderConfig config,
    required String modelId,
    required List<String> inputs,
    EmbeddingTask? task,
    int? dimensions,
    CancelToken? cancelToken,
  }) async {
    if (inputs.isEmpty) return const EmbeddingResult(vectors: []);
    config = await ProviderOAuthService.instance.resolve(config);
    final kind = ProviderConfig.classify(
      config.id,
      explicitType: config.providerType,
    );
    if (kind == ProviderKind.claude) {
      throw UnsupportedError('Anthropic does not offer an embeddings API.');
    }
    final client = ProviderOAuthService.instance.authenticatedClient(
      providerHttpClient(config, cancelToken: cancelToken),
      config,
    );
    try {
      final (send, batchSize) = switch (kind) {
        ProviderKind.google when _isVertex(config) => (
          _vertex,
          _vertexBatchSize,
        ),
        ProviderKind.google => (_gemini, _geminiBatchSize),
        _ => (_openAI, _openAIBatchSize),
      };
      final vectors = <List<double>>[];
      int? tokens;
      for (var i = 0; i < inputs.length; i += batchSize) {
        final batch = inputs.sublist(i, min(i + batchSize, inputs.length));
        final result = await send(
          client,
          config,
          modelId,
          batch,
          task: task,
          dimensions: dimensions,
        );
        if (result.vectors.length != batch.length) {
          throw const FormatException(
            'Embedding response count does not match the inputs.',
          );
        }
        vectors.addAll(result.vectors);
        if (result.promptTokens != null) {
          tokens = (tokens ?? 0) + result.promptTokens!;
        }
      }
      return EmbeddingResult(vectors: vectors, promptTokens: tokens);
    } finally {
      client.close();
    }
  }

  static Future<EmbeddingResult> _openAI(
    http.Client client,
    ProviderConfig config,
    String modelId,
    List<String> inputs, {
    EmbeddingTask? task,
    int? dimensions,
  }) async {
    final body = <String, dynamic>{
      'model': apiModelId(config, modelId),
      'input': inputs,
      'encoding_format': 'float',
      'dimensions': ?dimensions,
    };
    final json = await _post(
      client,
      Uri.parse('${_base(config)}/embeddings'),
      config,
      modelId,
      body,
      baseHeaders: {
        'Authorization': 'Bearer ${apiKeyForRequest(config, modelId)}',
        ...?providerSessionHeaders(config),
      },
    );
    final data = (json['data'] as List? ?? const []).whereType<Map>().toList();
    data.sort(
      (a, b) =>
          ((a['index'] as num?) ?? 0).compareTo((b['index'] as num?) ?? 0),
    );
    final usage = json['usage'];
    return EmbeddingResult(
      vectors: [for (final e in data) _vector(e['embedding'])],
      promptTokens: usage is Map
          ? ((usage['prompt_tokens'] ?? usage['total_tokens']) as num?)?.toInt()
          : null,
    );
  }

  static Future<EmbeddingResult> _gemini(
    http.Client client,
    ProviderConfig config,
    String modelId,
    List<String> inputs, {
    EmbeddingTask? task,
    int? dimensions,
  }) async {
    final upstream = apiModelId(config, modelId);
    final body = <String, dynamic>{
      'requests': [
        for (final text in inputs)
          {
            'model': 'models/$upstream',
            'content': {
              'parts': [
                {'text': text},
              ],
            },
            'taskType': ?_geminiTaskType(task),
            'outputDimensionality': ?dimensions,
          },
      ],
    };
    final key = effectiveApiKey(config);
    final json = await _post(
      client,
      Uri.parse('${_base(config)}/models/$upstream:batchEmbedContents'),
      config,
      modelId,
      body,
      baseHeaders: {if (key.isNotEmpty) 'x-goog-api-key': key},
    );
    return EmbeddingResult(
      vectors: [
        for (final e in (json['embeddings'] as List? ?? const []))
          _vector((e as Map)['values']),
      ],
    );
  }

  static Future<EmbeddingResult> _vertex(
    http.Client client,
    ProviderConfig config,
    String modelId,
    List<String> inputs, {
    EmbeddingTask? task,
    int? dimensions,
  }) async {
    final loc = config.location!.trim();
    final proj = config.projectId!.trim();
    final upstream = apiModelId(config, modelId);
    final body = <String, dynamic>{
      'instances': [
        for (final text in inputs)
          {'content': text, 'task_type': ?_geminiTaskType(task)},
      ],
      if (dimensions != null)
        'parameters': {'outputDimensionality': dimensions},
    };
    final token = await maybeVertexAccessToken(config);
    final json = await _post(
      client,
      Uri.parse(
        '${vertexOrigin(config, loc)}/v1/projects/$proj/locations/$loc/publishers/google/models/$upstream:predict',
      ),
      config,
      modelId,
      body,
      baseHeaders: {
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        'X-Goog-User-Project': proj,
      },
    );
    var tokens = 0;
    final vectors = <List<double>>[];
    for (final p in (json['predictions'] as List? ?? const [])) {
      final embeddings = (p as Map)['embeddings'] as Map;
      vectors.add(_vector(embeddings['values']));
      final stats = embeddings['statistics'];
      if (stats is Map) tokens += (stats['token_count'] as num?)?.toInt() ?? 0;
    }
    return EmbeddingResult(vectors: vectors, promptTokens: tokens);
  }

  static Future<Map<String, dynamic>> _post(
    http.Client client,
    Uri url,
    ProviderConfig config,
    String modelId,
    Map<String, dynamic> body, {
    required Map<String, String> baseHeaders,
  }) async {
    CustomRequestMerger.applyBody(body, customBody(config, modelId));
    final res = await client.post(
      url,
      headers: customHeaders(
        config,
        modelId,
        baseHeaders: {...baseHeaders, 'Content-Type': 'application/json'},
      ),
      body: jsonEncode(body),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException('HTTP ${res.statusCode}: ${res.body}');
    }
    return (jsonDecode(utf8.decode(res.bodyBytes)) as Map)
        .cast<String, dynamic>();
  }

  static List<double> _vector(Object? raw) {
    if (raw is! List) {
      throw const FormatException('Embedding response has no vector.');
    }
    return [for (final v in raw) (v as num).toDouble()];
  }

  static String? _geminiTaskType(EmbeddingTask? task) => switch (task) {
    EmbeddingTask.query => 'RETRIEVAL_QUERY',
    EmbeddingTask.document => 'RETRIEVAL_DOCUMENT',
    null => null,
  };

  static bool _isVertex(ProviderConfig config) =>
      config.vertexAI == true &&
      (config.location?.trim().isNotEmpty ?? false) &&
      (config.projectId?.trim().isNotEmpty ?? false);

  static String _base(ProviderConfig config) => config.baseUrl.endsWith('/')
      ? config.baseUrl.substring(0, config.baseUrl.length - 1)
      : config.baseUrl;
}
