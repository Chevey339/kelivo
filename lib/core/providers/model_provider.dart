import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'settings_provider.dart';
import '../services/api_key_manager.dart';
import 'package:Kelivo/secrets/fallback.dart';
import '../services/api/google_service_account_auth.dart';

enum ModelType { chat, embedding }
enum Modality { text, image }
enum ModelAbility { tool, reasoning }

class ModelInfo {
  final String id;
  final String displayName;
  final ModelType type;
  final List<Modality> input;
  final List<Modality> output;
  final List<ModelAbility> abilities;
  ModelInfo({
    required this.id,
    required this.displayName,
    this.type = ModelType.chat,
    this.input = const [Modality.text],
    this.output = const [Modality.text],
    this.abilities = const [],
  });

  ModelInfo copyWith({
    String? id,
    String? displayName,
    ModelType? type,
    List<Modality>? input,
    List<Modality>? output,
    List<ModelAbility>? abilities,
  }) => ModelInfo(
        id: id ?? this.id,
        displayName: displayName ?? this.displayName,
        type: type ?? this.type,
        input: input ?? this.input,
        output: output ?? this.output,
        abilities: abilities ?? this.abilities,
      );
}

class ModelRegistry {
  // Updated model groups to reflect new series
  // Vision-capable models (text + image input)
  static final RegExp vision = RegExp(
      // GPT family incl. 4o, 4.1, 5 (exclude gpt-5-chat), and OpenAI o* series
      r'(gpt-4o|gpt-4\.1|gpt-5(?!-chat)|o\d|gemini|claude|doubao.+1([-.])6|grok-4|step-3|intern-s1)',
      caseSensitive: false);
  // Tool-using models
  static final RegExp tool = RegExp(
      (
              r'(gpt-4o|gpt-4\.1|gpt-oss|gpt-5(?!-chat)|o\d|'
              r'gemini|claude|'
              r'qwen-?3|doubao.+1([-.])6|grok-4|kimi-k2|'
              r'step-3|intern-s1|glm-4\.5|glm-4\.6|minimax-m2|'
              r'deepseek-(?:r1|v3|chat|v3\.1|v3\.2)|'
              r'deepseek-reasoner'
              r')'
          )
          .replaceAll(' ', ''),
      caseSensitive: false);
  static final RegExp reasoning = RegExp(
      (
              r'(gpt-oss|gpt-5(?!-chat)|o\d|'
              r'gemini-(?:2\.5|3).*|gemini-(?:flash-latest|pro-latest)|'
              r'gemini-3-pro-image-preview|'
              r'claude|'
              r'qwen-?3|doubao.+1([-.])6|grok-4|kimi-k2|'
              r'step-3|intern-s1|glm-4\.5|glm-4\.6|minimax-m2|'
              r'deepseek-(?:r1|v3\.1|v3\.2)|'
              r'deepseek-reasoner'
              r')'
          )
          .replaceAll(' ', ''),
      caseSensitive: false);

  static ModelInfo infer(ModelInfo base) {
    final id = base.id.toLowerCase();
    final inMods = <Modality>[...base.input];
    final outMods = <Modality>[...base.output];
    final ab = <ModelAbility>[...base.abilities];
    // If model id contains 'image', treat it as an image model:
    // - Input and output both include image
    // - No tool or reasoning abilities
    if (id.contains('image')) {
      if (!inMods.contains(Modality.image)) inMods.add(Modality.image);
      if (!outMods.contains(Modality.image)) outMods.add(Modality.image);
      ab.removeWhere((x) => x == ModelAbility.tool || x == ModelAbility.reasoning);
      return base.copyWith(input: inMods, output: outMods, abilities: ab);
    }
    if (vision.hasMatch(id)) {
      if (!inMods.contains(Modality.image)) inMods.add(Modality.image);
    }
    if (tool.hasMatch(id) && !ab.contains(ModelAbility.tool)) ab.add(ModelAbility.tool);
    if (reasoning.hasMatch(id) && !ab.contains(ModelAbility.reasoning)) ab.add(ModelAbility.reasoning);
    return base.copyWith(input: inMods, output: outMods, abilities: ab);
  }
}

abstract class BaseProvider {
  Future<List<ModelInfo>> listModels(ProviderConfig cfg);
}

class _Http {
  static http.Client clientFor(ProviderConfig cfg) {
    final enabled = cfg.proxyEnabled == true;
    final host = (cfg.proxyHost ?? '').trim();
    final portStr = (cfg.proxyPort ?? '').trim();
    final user = (cfg.proxyUsername ?? '').trim();
    final pass = (cfg.proxyPassword ?? '').trim();
    if (enabled && host.isNotEmpty && portStr.isNotEmpty) {
      final port = int.tryParse(portStr) ?? 8080;
      final io = HttpClient();
      io.idleTimeout = const Duration(minutes: 5);
      io.findProxy = (uri) => 'PROXY $host:$port';
      if (user.isNotEmpty) {
        io.addProxyCredentials(host, port, '', HttpClientBasicCredentials(user, pass));
      }
      // Allow self-signed certificates for proxy connections
      io.badCertificateCallback = (cert, host, port) => true;
      return IOClient(io);
    }
    // 非代理情况也需要设置 idleTimeout
    final io = HttpClient();
    io.idleTimeout = const Duration(minutes: 5);
    // Allow self-signed certificates for third-party proxies
    io.badCertificateCallback = (cert, host, port) => true;
    return IOClient(io);
  }
}

class OpenAIProvider extends BaseProvider {
  @override
  Future<List<ModelInfo>> listModels(ProviderConfig cfg) async {
    final key = ProviderManager._effectiveApiKey(cfg);
    if (key.isEmpty) return [];
    final client = _Http.clientFor(cfg);
    try {
      final uri = Uri.parse('${cfg.baseUrl}/models');
      final res = await client.get(uri, headers: {
        'Authorization': 'Bearer $key',
      });
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = (jsonDecode(res.body)['data'] as List?) ?? [];
        return [
          for (final e in data)
            if (e is Map && e['id'] is String)
              ModelRegistry.infer(ModelInfo(id: e['id'] as String, displayName: e['id'] as String))
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
  Future<List<ModelInfo>> listModels(ProviderConfig cfg) async {
    final key = ProviderManager._effectiveApiKey(cfg);
    if (key.isEmpty) return [];
    final client = _Http.clientFor(cfg);
    try {
      final uri = Uri.parse('${cfg.baseUrl}/models');

      // Try Anthropic native format first
      var res = await client.get(uri, headers: {
        'x-api-key': key,
        'anthropic-version': anthropicVersion,
      });

      // If failed, try OpenAI-compatible format (for third-party proxies)
      if (res.statusCode >= 400) {
        res = await client.get(uri, headers: {
          'Authorization': 'Bearer $key',
        });
      }

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        // Support both Anthropic native format {"data": [...]} and third-party proxy formats
        List<dynamic> data = [];
        if (decoded is Map) {
          final obj = decoded as Map<String, dynamic>;
          if (obj['data'] is List) {
            // Anthropic native format or OpenAI format
            data = obj['data'] as List;
          } else if (obj['models'] is List) {
            // Alternative format used by some proxies
            data = obj['models'] as List;
          }
        } else if (decoded is List) {
          // Direct array response
          data = decoded;
        }
        return [
          for (final e in data)
            if (e is Map && e['id'] is String)
              ModelRegistry.infer(ModelInfo(
                id: e['id'] as String,
                displayName: (e['display_name'] as String?) ?? (e['id'] as String),
              ))
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
    if (cfg.vertexAI == true && (cfg.location?.isNotEmpty == true) && (cfg.projectId?.isNotEmpty == true)) {
      final loc = cfg.location!;
      final proj = cfg.projectId!;
      return 'https://aiplatform.googleapis.com/v1/projects/$proj/locations/$loc/publishers/google/models';
    }
    final base = cfg.baseUrl.endsWith('/') ? cfg.baseUrl.substring(0, cfg.baseUrl.length - 1) : cfg.baseUrl;
    final key = ProviderManager._effectiveApiKey(cfg);
    if (key.isNotEmpty) {
      return '$base/models?key=${Uri.encodeQueryComponent(key)}';
    }
    return '$base/models';
  }

  @override
  Future<List<ModelInfo>> listModels(ProviderConfig cfg) async {
    final client = _Http.clientFor(cfg);
    try {
      final url = _buildUrl(cfg);
      final headers = <String, String>{};
      if (cfg.vertexAI == true) {
        final jsonStr = (cfg.serviceAccountJson ?? '').trim();
        if (jsonStr.isNotEmpty) {
          try {
            final token = await GoogleServiceAccountAuth.getAccessTokenFromJson(jsonStr);
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
      }
      final res = await client.get(Uri.parse(url), headers: headers);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final obj = jsonDecode(res.body) as Map<String, dynamic>;
        final arr = (obj['models'] as List?) ?? [];
        final out = <ModelInfo>[];
        for (final e in arr) {
          if (e is Map) {
            final name = (e['name'] as String?) ?? '';
            final id = name.contains('/') ? name.split('/').last : name;
            final displayName = (e['displayName'] as String?) ?? id;
            final methods = (e['supportedGenerationMethods'] as List?)?.map((m) => m.toString()).toSet() ?? {};
            if (!(methods.contains('generateContent') || methods.contains('embedContent'))) continue;
            out.add(ModelRegistry.infer(ModelInfo(
              id: id,
              displayName: displayName,
              type: methods.contains('generateContent') ? ModelType.chat : ModelType.embedding,
            )));
          }
        }
        return out;
      }
      return [];
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
  static Map<String, dynamic> _modelOverride(ProviderConfig cfg, String modelId) {
    final ov = cfg.modelOverrides[modelId];
    if (ov is Map<String, dynamic>) return ov;
    return const <String, dynamic>{};
  }

  static Map<String, String> _customHeaders(ProviderConfig cfg, String modelId) {
    final ov = _modelOverride(cfg, modelId);
    final list = (ov['headers'] as List?) ?? const <dynamic>[];
    final out = <String, String>{};
    for (final e in list) {
      if (e is Map) {
        final name = (e['name'] ?? e['key'] ?? '').toString().trim();
        final value = (e['value'] ?? '').toString();
        if (name.isNotEmpty) out[name] = value;
      }
    }
    return out;
  }

  static dynamic _parseOverrideValue(String v) {
    final s = v.trim();
    if (s.isEmpty) return s;
    if (s == 'true') return true;
    if (s == 'false') return false;
    if (s == 'null') return null;
    final i = int.tryParse(s);
    if (i != null) return i;
    final d = double.tryParse(s);
    if (d != null) return d;
    if ((s.startsWith('{') && s.endsWith('}')) || (s.startsWith('[') && s.endsWith(']'))) {
      try { return jsonDecode(s); } catch (_) {}
    }
    return v;
  }

  static Map<String, dynamic> _customBody(ProviderConfig cfg, String modelId) {
    final ov = _modelOverride(cfg, modelId);
    final list = (ov['body'] as List?) ?? const <dynamic>[];
    final out = <String, dynamic>{};
    for (final e in list) {
      if (e is Map) {
        final key = (e['key'] ?? e['name'] ?? '').toString().trim();
        final val = (e['value'] ?? '').toString();
        if (key.isNotEmpty) out[key] = _parseOverrideValue(val);
      }
    }
    return out;
  }
  static BaseProvider forConfig(ProviderConfig cfg) {
    final kind = ProviderConfig.classify(cfg.id, explicitType: cfg.providerType);
    switch (kind) {
      case ProviderKind.google:
        return GoogleProvider();
      case ProviderKind.claude:
        return ClaudeProvider();
      case ProviderKind.openai:
      default:
        return OpenAIProvider();
    }
  }

  static Future<List<ModelInfo>> listModels(ProviderConfig cfg) {
    return forConfig(cfg).listModels(cfg);
  }

  static Future<void> testConnection(ProviderConfig cfg, String modelId, {bool useStream = false}) async {
    final kind = ProviderConfig.classify(cfg.id, explicitType: cfg.providerType);
    final client = _Http.clientFor(cfg);
    try {
      if (kind == ProviderKind.openai) {
        final base = cfg.baseUrl.endsWith('/') ? cfg.baseUrl.substring(0, cfg.baseUrl.length - 1) : cfg.baseUrl;
        final path = (cfg.useResponseApi == true) ? '/responses' : (cfg.chatPath ?? '/chat/completions');
        final url = Uri.parse('$base$path');
        final body = cfg.useResponseApi == true
            ? {
                'model': modelId,
                'input': [
                  {'role': 'user', 'content': 'hello'}
                ],
                if (useStream) 'stream': true,
              }
            : {
                'model': modelId,
                'messages': [
                  {'role': 'user', 'content': 'hello'}
                ],
                if (useStream) 'stream': true,
              };
        // Merge custom body overrides
        final extra = _customBody(cfg, modelId);
        if (extra.isNotEmpty) (body as Map<String, dynamic>).addAll(extra);
        // Merge custom headers overrides
        // SiliconFlow fallback key for built-in free models when no API key provided
        String apiKey = _effectiveApiKey(cfg);
        try {
          if ((cfg.id) == 'SiliconFlow') {
            final host = Uri.tryParse(cfg.baseUrl)?.host.toLowerCase() ?? '';
            if (host.contains('siliconflow') && apiKey.trim().isEmpty) {
              final m = modelId.toLowerCase();
              final allowed = m == 'thudm/glm-4-9b-0414' || m == 'qwen/qwen3-8b';
              final fb = siliconflowFallbackKey.trim();
              if (allowed && fb.isNotEmpty) apiKey = fb;
            }
          }
        } catch (_) {}
        final headers = <String, String>{
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        };
        headers.addAll(_customHeaders(cfg, modelId));
        final res = await client.post(url, headers: headers, body: jsonEncode(body));
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
        final base = cfg.baseUrl.endsWith('/') ? cfg.baseUrl.substring(0, cfg.baseUrl.length - 1) : cfg.baseUrl;
        final url = Uri.parse('$base/messages');
        final body = {
          'model': modelId,
          'max_tokens': 8,
          'messages': [
            {
              'role': 'user',
              'content': 'hello',
            }
          ],
          if (useStream) 'stream': true,
        };
        final extra = _customBody(cfg, modelId);
        if (extra.isNotEmpty) (body as Map<String, dynamic>).addAll(extra);

        // Auto-detect authentication format: Anthropic native vs OpenAI-compatible proxy
        final bool isOfficialAnthropic = cfg.baseUrl.contains('anthropic.com') ||
                                          cfg.baseUrl.contains('claude.ai');
        final apiKey = _effectiveApiKey(cfg);

        final headers = <String, String>{
          if (isOfficialAnthropic) ...{
            'x-api-key': apiKey,
            'anthropic-version': ClaudeProvider.anthropicVersion,
          } else ...{
            'Authorization': 'Bearer $apiKey',
          },
          'Content-Type': 'application/json',
        };
        headers.addAll(_customHeaders(cfg, modelId));
        final res = await client.post(url, headers: headers, body: jsonEncode(body));
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
          final raw = (ov['apiModelId'] ?? ov['api_model_id'])?.toString().trim();
          if (raw != null && raw.isNotEmpty) upstreamId = raw;
        } catch (_) {}

        String url;
        final endpoint = useStream ? 'streamGenerateContent' : 'generateContent';
        if (cfg.vertexAI == true && (cfg.location?.isNotEmpty == true) && (cfg.projectId?.isNotEmpty == true)) {
          final loc = cfg.location!;
          final proj = cfg.projectId!;
          url = 'https://aiplatform.googleapis.com/v1/projects/$proj/locations/$loc/publishers/google/models/$upstreamId:$endpoint';
        } else {
          final base = cfg.baseUrl.endsWith('/') ? cfg.baseUrl.substring(0, cfg.baseUrl.length - 1) : cfg.baseUrl;
          url = '$base/models/$upstreamId:$endpoint';
          if (cfg.apiKey.isNotEmpty) {
            url = '$url?key=${Uri.encodeQueryComponent(cfg.apiKey)}';
          }
        }
        // Determine if model outputs images (override wins; otherwise inference)
        bool wantsImageOutput = false;
        if (ov['output'] is List) {
          final outList = (ov['output'] as List).map((e) => e.toString().toLowerCase()).toList();
          wantsImageOutput = outList.contains('image');
        } else {
          wantsImageOutput = ModelRegistry.infer(ModelInfo(id: upstreamId, displayName: upstreamId)).output.contains(Modality.image);
        }
        final body = {
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': 'hello'}
              ]
            }
          ],
          if (wantsImageOutput)
            'generationConfig': {
              'responseModalities': ['TEXT', 'IMAGE'],
            },
        };
        final headers = <String, String>{'Content-Type': 'application/json'};
        if (cfg.vertexAI == true) {
          final jsonStr = (cfg.serviceAccountJson ?? '').trim();
          if (jsonStr.isNotEmpty) {
            try {
              final token = await GoogleServiceAccountAuth.getAccessTokenFromJson(jsonStr);
              headers['Authorization'] = 'Bearer $token';
            } catch (_) {}
          } else if (cfg.apiKey.isNotEmpty) {
            headers['Authorization'] = 'Bearer ${cfg.apiKey}';
          }
        }
        headers.addAll(_customHeaders(cfg, modelId));
        final extra = _customBody(cfg, modelId);
        if (extra.isNotEmpty) (body as Map<String, dynamic>).addAll(extra);
        final res = await client.post(Uri.parse(url), headers: headers, body: jsonEncode(body));
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
