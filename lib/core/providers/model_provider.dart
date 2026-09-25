import '../services/auth/provider_oauth_service.dart';
export '../models/model_spec.dart';

import 'dart:convert';
import 'dart:io' show HttpException;
import 'settings_provider.dart';
import '../services/network/provider_http_client.dart';
import '../services/api_key_manager.dart';
import '../services/api/provider_request_headers.dart';
import '../services/model_override_payload_parser.dart';
import '../services/custom_request_merger.dart';
import 'package:Kelivo/secrets/fallback.dart';
import '../services/api/embedding/embedding_api_service.dart';
import '../services/api/google_service_account_auth.dart';
import '../models/model_spec.dart';
import '../services/model_spec/model_spec_resolver.dart';
import '../services/model_catalog/model_catalog_service.dart';

abstract class BaseProvider {
  Future<List<ModelSpec>> listModels(ProviderConfig cfg);
}

class _Http {
  static Map<String, String> modelListHeaders(
    ProviderConfig cfg,
    Map<String, String> base,
  ) {
    return CustomRequestMerger.mergeHeaders(
      base: base,
      provider: ModelOverridePayloadParser.customHeadersFromRows(
        cfg.customHeaders,
      ),
    );
  }
}

class OpenAIProvider extends BaseProvider {
  @override
  Future<List<ModelSpec>> listModels(ProviderConfig cfg) async {
    final key = ProviderManager._effectiveApiKey(cfg);
    final client = providerHttpClient(cfg);
    try {
      final uri = Uri.parse('${cfg.baseUrl}/models');
      final headers = <String, String>{};
      if (key.isNotEmpty) headers['Authorization'] = 'Bearer $key';
      final res = await client.get(
        uri,
        headers: _Http.modelListHeaders(cfg, headers),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = (jsonDecode(res.body)['data'] as List?) ?? [];
        return [
          for (final e in data)
            if (e is Map && e['id'] is String)
              ModelSpecResolver.instance
                  .resolve(
                    cfg,
                    e['id'] as String,
                    displayName: e['id'] as String,
                  )
                  .spec,
        ];
      }
      return [];
    } finally {
      client.close();
    }
  }
}

class ClaudeProvider extends BaseProvider {
  static const String anthropicVersion = '2023-06-01';
  @override
  Future<List<ModelSpec>> listModels(ProviderConfig cfg) async {
    final key = ProviderManager._effectiveApiKey(cfg);
    final client = providerHttpClient(cfg);
    try {
      final uri = Uri.parse('${cfg.baseUrl}/models');
      final headers = <String, String>{'anthropic-version': anthropicVersion};
      if (key.isNotEmpty) headers['x-api-key'] = key;
      final res = await client.get(
        uri,
        headers: _Http.modelListHeaders(cfg, headers),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final obj = jsonDecode(res.body) as Map<String, dynamic>;
        final data = (obj['data'] as List?) ?? [];
        return [
          for (final e in data)
            if (e is Map && e['id'] is String)
              ModelSpecResolver.instance
                  .resolve(
                    cfg,
                    e['id'] as String,
                    displayName:
                        (e['display_name'] as String?) ?? (e['id'] as String),
                  )
                  .spec,
        ];
      }
      return [];
    } finally {
      client.close();
    }
  }
}

class GoogleProvider extends BaseProvider {
  String _buildUrl(ProviderConfig cfg) {
    if (cfg.vertexAI == true &&
        (cfg.location?.isNotEmpty == true) &&
        (cfg.projectId?.isNotEmpty == true)) {
      final loc = cfg.location!;
      final proj = cfg.projectId!;
      return 'https://aiplatform.googleapis.com/v1/projects/$proj/locations/$loc/publishers/google/models';
    }
    final base = cfg.baseUrl.endsWith('/')
        ? cfg.baseUrl.substring(0, cfg.baseUrl.length - 1)
        : cfg.baseUrl;
    return '$base/models';
  }

  @override
  Future<List<ModelSpec>> listModels(ProviderConfig cfg) async {
    final client = providerHttpClient(cfg);
    try {
      final url = _buildUrl(cfg);
      final headers = <String, String>{};
      if (cfg.vertexAI == true) {
        final jsonStr = (cfg.serviceAccountJson ?? '').trim();
        if (jsonStr.isNotEmpty) {
          try {
            final token = await GoogleServiceAccountAuth.getAccessTokenFromJson(
              jsonStr,
            );
            headers['Authorization'] = 'Bearer $token';
            final proj = (cfg.projectId ?? '').trim();
            if (proj.isNotEmpty) headers['X-Goog-User-Project'] = proj;
          } catch (_) {}
        } else {
          final key = ProviderManager._effectiveApiKey(cfg);
          if (key.isNotEmpty) {
            // Fallback: treat apiKey as a bearer token if user pasted one
            headers['Authorization'] = 'Bearer $key';
          }
        }
      } else {
        final key = ProviderManager._effectiveApiKey(cfg);
        if (key.isNotEmpty) {
          headers['x-goog-api-key'] = key;
        }
      }
      final out = <ModelSpec>[];
      try {
        final res = await client.get(
          Uri.parse(url),
          headers: _Http.modelListHeaders(cfg, headers),
        );
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final obj = jsonDecode(res.body) as Map<String, dynamic>;
          final arr = (obj['models'] as List?) ?? [];
          for (final e in arr) {
            if (e is Map) {
              final name = (e['name'] as String?) ?? '';
              final id = name.startsWith('models/')
                  ? name.substring('models/'.length)
                  : name;
              final displayName = (e['displayName'] as String?) ?? id;
              final methods =
                  (e['supportedGenerationMethods'] as List?)
                      ?.map((m) => m.toString())
                      .toSet() ??
                  {};
              if (!(methods.contains('generateContent') ||
                  methods.contains('embedContent'))) {
                continue;
              }
              out.add(
                ModelSpecResolver.instance
                    .resolve(cfg, id, displayName: displayName)
                    .spec,
              );
            }
          }
        }
      } catch (_) {}

      // Vertex listModels only returns Gemini under publishers/google.
      // Merge Anthropic ids from the models.dev Vertex Anthropic catalog.
      if (cfg.vertexAI == true) {
        final catalog = ModelCatalogService.instance;
        await catalog.ensureLoaded();
        for (final model in catalog.modelsOfProvider(
          'google-vertex-anthropic',
        )) {
          if (!out.any((m) => m.id == model.id)) {
            out.add(
              ModelSpecResolver.instance
                  .resolve(
                    cfg,
                    model.id,
                    displayName: model.name.isEmpty ? null : model.name,
                  )
                  .spec,
            );
          }
        }
      }
      return out;
    } finally {
      client.close();
    }
  }
}

class ProviderManager {
  static String _effectiveApiKey(ProviderConfig cfg) {
    try {
      if (cfg.multiKeyEnabled == true && (cfg.apiKeys?.isNotEmpty == true)) {
        final sel = ApiKeyManager().selectForProvider(cfg);
        if (sel.key != null) return sel.key!.key;
      }
    } catch (_) {}
    return cfg.apiKey;
  }

  // Per-model override helpers (duplicated logic from ChatApiService)
  static Map<String, dynamic> _modelOverride(
    ProviderConfig cfg,
    String modelId,
  ) {
    return ModelOverridePayloadParser.modelOverride(
      cfg.modelOverrides,
      modelId,
    );
  }

  static Map<String, String> _customHeaders(
    ProviderConfig cfg,
    String modelId,
  ) {
    final ov = _modelOverride(cfg, modelId);
    return CustomRequestMerger.mergeHeaders(
      providerAutomatic: providerDefaultHeaders(cfg),
      provider: ModelOverridePayloadParser.customHeadersFromRows(
        cfg.customHeaders,
      ),
      model: ModelOverridePayloadParser.customHeaders(ov),
    );
  }

  static Map<String, dynamic> _customBody(ProviderConfig cfg, String modelId) {
    final ov = _modelOverride(cfg, modelId);
    return CustomRequestMerger.mergeBody(
      providerRows: cfg.customBody,
      model: ModelOverridePayloadParser.customBody(ov),
    );
  }

  static BaseProvider forConfig(ProviderConfig cfg) {
    final kind = ProviderConfig.classify(
      cfg.id,
      explicitType: cfg.providerType,
    );
    switch (kind) {
      case ProviderKind.google:
        return GoogleProvider();
      case ProviderKind.claude:
        return ClaudeProvider();
      case ProviderKind.openai:
        return OpenAIProvider();
    }
  }

  static Future<List<ModelSpec>> listModels(ProviderConfig cfg) {
    if (cfg.isOAuth) return ProviderOAuthService.instance.models(cfg);
    return forConfig(cfg).listModels(cfg);
  }

  static Future<void> testConnection(
    ProviderConfig cfg,
    String modelId, {
    bool useStream = false,
  }) async {
    if (ModelSpecResolver.instance.spec(cfg, modelId).isEmbedding) {
      await EmbeddingApiService.embed(
        config: cfg,
        modelId: modelId,
        inputs: const ['hello'],
      );
      return;
    }
    cfg = await ProviderOAuthService.instance.resolve(cfg);
    if (cfg.oauthProvider == OAuthProvider.chatgpt) useStream = true;
    if (cfg.oauthProvider == OAuthProvider.kimi &&
        (cfg.modelOverrides[modelId] as Map?)?['oauthProtocol'] ==
            'anthropic') {
      cfg = cfg.copyWith(providerType: ProviderKind.claude);
    }
    final kind = ProviderConfig.classify(
      cfg.id,
      explicitType: cfg.providerType,
    );
    final client = ProviderOAuthService.instance.authenticatedClient(
      providerHttpClient(cfg),
      cfg,
    );
    try {
      if (kind == ProviderKind.openai) {
        final base = cfg.baseUrl.endsWith('/')
            ? cfg.baseUrl.substring(0, cfg.baseUrl.length - 1)
            : cfg.baseUrl;
        final path = (cfg.useResponseApi == true)
            ? '/responses'
            : (cfg.chatPath ?? '/chat/completions');
        final url = Uri.parse('$base$path');
        final ov = _modelOverride(cfg, modelId);
        String upstreamId = modelId;
        try {
          final raw = (ov['apiModelId'] ?? ov['api_model_id'])
              ?.toString()
              .trim();
          if (raw != null && raw.isNotEmpty) upstreamId = raw;
        } catch (_) {}
        final Map<String, dynamic> body = cfg.useResponseApi == true
            ? <String, dynamic>{
                'model': upstreamId,
                'input': [
                  {'role': 'user', 'content': 'hello'},
                ],
                if (useStream) 'stream': true,
              }
            : <String, dynamic>{
                'model': upstreamId,
                'messages': [
                  {'role': 'user', 'content': 'hello'},
                ],
                if (useStream) 'stream': true,
              };
        // Merge custom body overrides
        final extra = _customBody(cfg, modelId);
        CustomRequestMerger.applyBody(body, extra);
        // Merge custom headers overrides
        // SiliconFlow fallback key for built-in free models when no API key provided
        String apiKey = _effectiveApiKey(cfg);
        try {
          if ((cfg.id) == 'SiliconFlow') {
            final host = Uri.tryParse(cfg.baseUrl)?.host.toLowerCase() ?? '';
            if (host.contains('siliconflow') && apiKey.trim().isEmpty) {
              final m = upstreamId.toLowerCase();
              final allowed =
                  m == 'thudm/glm-4-9b-0414' || m == 'qwen/qwen3-8b';
              final fb = siliconflowFallbackKey.trim();
              if (allowed && fb.isNotEmpty) apiKey = fb;
            }
          }
        } catch (_) {}
        final headers = <String, String>{
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          ...?providerSessionHeaders(cfg),
        };
        headers.addAll(_customHeaders(cfg, modelId));
        final res = await client.post(
          url,
          headers: headers,
          body: jsonEncode(body),
        );
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw HttpException('HTTP ${res.statusCode}: ${res.body}');
        }
        // For streaming, verify the response contains SSE data
        if (useStream) {
          final contentType = res.headers['content-type'] ?? '';
          if (!contentType.contains('text/event-stream') && res.body.isEmpty) {
            throw HttpException('Stream response expected but not received');
          }
        }
        return;
      } else if (kind == ProviderKind.claude) {
        final base = cfg.baseUrl.endsWith('/')
            ? cfg.baseUrl.substring(0, cfg.baseUrl.length - 1)
            : cfg.baseUrl;
        final url = Uri.parse('$base/messages');
        final ov = _modelOverride(cfg, modelId);
        String upstreamId = modelId;
        try {
          final raw = (ov['apiModelId'] ?? ov['api_model_id'])
              ?.toString()
              .trim();
          if (raw != null && raw.isNotEmpty) upstreamId = raw;
        } catch (_) {}
        final body = <String, dynamic>{
          'model': upstreamId,
          'max_tokens': 8,
          'messages': [
            {'role': 'user', 'content': 'hello'},
          ],
          if (useStream) 'stream': true,
        };
        final extra = _customBody(cfg, modelId);
        CustomRequestMerger.applyBody(body, extra);
        final headers = <String, String>{
          'x-api-key': _effectiveApiKey(cfg),
          'anthropic-version': ClaudeProvider.anthropicVersion,
          'Content-Type': 'application/json',
        };
        headers.addAll(_customHeaders(cfg, modelId));
        final res = await client.post(
          url,
          headers: headers,
          body: jsonEncode(body),
        );
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw HttpException('HTTP ${res.statusCode}: ${res.body}');
        }
        // For streaming, verify the response contains SSE data
        if (useStream) {
          final contentType = res.headers['content-type'] ?? '';
          if (!contentType.contains('text/event-stream') && res.body.isEmpty) {
            throw HttpException('Stream response expected but not received');
          }
        }
        return;
      } else if (kind == ProviderKind.google) {
        // Generative Language API (default) or Vertex AI when vertexAI == true
        final ov = _modelOverride(cfg, modelId);
        // Resolve upstream/api model id for this logical key when present.
        String upstreamId = modelId;
        try {
          final raw = (ov['apiModelId'] ?? ov['api_model_id'])
              ?.toString()
              .trim();
          if (raw != null && raw.isNotEmpty) upstreamId = raw;
        } catch (_) {}

        String url;
        final endpoint = useStream
            ? 'streamGenerateContent'
            : 'generateContent';
        final bool isVertex =
            cfg.vertexAI == true &&
            (cfg.location?.isNotEmpty == true) &&
            (cfg.projectId?.isNotEmpty == true);
        final bool isVertexClaude =
            isVertex && upstreamId.toLowerCase().startsWith('claude-');
        if (isVertex) {
          final loc = cfg.location!;
          final proj = cfg.projectId!;
          if (isVertexClaude) {
            final ep = useStream ? 'streamRawPredict' : 'rawPredict';
            url =
                'https://aiplatform.googleapis.com/v1/projects/$proj/locations/$loc/publishers/anthropic/models/$upstreamId:$ep';
          } else {
            url =
                'https://aiplatform.googleapis.com/v1/projects/$proj/locations/$loc/publishers/google/models/$upstreamId:$endpoint';
          }
        } else {
          final base = cfg.baseUrl.endsWith('/')
              ? cfg.baseUrl.substring(0, cfg.baseUrl.length - 1)
              : cfg.baseUrl;
          url = '$base/models/$upstreamId:$endpoint';
        }
        final wantsImageOutput = ModelSpecResolver.instance
            .spec(cfg, modelId)
            .output
            .contains(Modality.image);
        final Map<String, dynamic> body = isVertexClaude
            ? <String, dynamic>{
                'anthropic_version': 'vertex-2023-10-16',
                'messages': [
                  {'role': 'user', 'content': 'hello'},
                ],
                'max_tokens': 32,
                if (useStream) 'stream': true,
              }
            : <String, dynamic>{
                'contents': [
                  {
                    'role': 'user',
                    'parts': [
                      {'text': 'hello'},
                    ],
                  },
                ],
                if (wantsImageOutput)
                  'generationConfig': {
                    'responseModalities': ['TEXT', 'IMAGE'],
                  },
              };
        final headers = <String, String>{'Content-Type': 'application/json'};
        final effectiveKey = _effectiveApiKey(cfg);
        if (cfg.vertexAI == true) {
          final jsonStr = (cfg.serviceAccountJson ?? '').trim();
          if (jsonStr.isNotEmpty) {
            try {
              final token =
                  await GoogleServiceAccountAuth.getAccessTokenFromJson(
                    jsonStr,
                  );
              headers['Authorization'] = 'Bearer $token';
            } catch (_) {}
          } else if (effectiveKey.isNotEmpty) {
            headers['Authorization'] = 'Bearer $effectiveKey';
          }
        } else {
          if (effectiveKey.isNotEmpty) {
            headers['x-goog-api-key'] = effectiveKey;
          }
        }
        headers.addAll(_customHeaders(cfg, modelId));
        final extra = _customBody(cfg, modelId);
        CustomRequestMerger.applyBody(body, extra);
        final res = await client.post(
          Uri.parse(url),
          headers: headers,
          body: jsonEncode(body),
        );
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw HttpException('HTTP ${res.statusCode}: ${res.body}');
        }
        // For streaming, verify the response is not empty
        if (useStream && res.body.isEmpty) {
          throw HttpException('Stream response expected but not received');
        }
        return;
      }
    } finally {
      client.close();
    }
  }
}
