import '../../providers/settings_provider.dart';

class BuiltInToolsRequestPayload {
  final List<Map<String, dynamic>> tools;
  final Map<String, dynamic> body;

  const BuiltInToolsRequestPayload({
    this.tools = const <Map<String, dynamic>>[],
    this.body = const <String, dynamic>{},
  });
}

/// Built-in tool name constants for API integrations.
/// Use these constants instead of raw strings to ensure consistency.
abstract class BuiltInToolNames {
  // Common
  static const search = 'search';

  // OpenRouter server tools
  static const webFetch = 'web_fetch';
  static const shell = 'shell';

  // Google/Gemini specific
  static const urlContext = 'url_context';
  static const codeExecution = 'code_execution';
  static const youtube = 'youtube';

  // OpenAI specific
  static const codeInterpreter = 'code_interpreter';
  static const imageGeneration = 'image_generation';

  /// Normalize a tool name to snake_case format.
  /// Handles legacy camelCase formats for backward compatibility.
  static String normalize(String name) {
    final lower = name.trim().toLowerCase();
    switch (lower) {
      case 'urlcontext':
        return urlContext;
      case 'codeexecution':
        return codeExecution;
      case 'codeinterpreter':
        return codeInterpreter;
      case 'imagegeneration':
        return imageGeneration;
      case 'webfetch':
        return webFetch;
      default:
        return lower;
    }
  }

  /// Parse tool names from persisted settings and normalize them.
  ///
  /// Accepts legacy/unknown types defensively (e.g. null, non-iterables).
  /// Returns a mutable Set even when empty to avoid read-only mutation crashes.
  static Set<String> parseAndNormalize(Object? raw) {
    if (raw == null) return <String>{};
    if (raw is! Iterable) return <String>{};
    final out = <String>{};
    for (final e in raw) {
      final v = normalize(e.toString());
      if (v.isNotEmpty) out.add(v);
    }
    return out;
  }

  /// Parse built-in tools from a per-model override map.
  ///
  /// Supports:
  /// - `builtInTools`: `List<String>` (current format)
  /// - `built_in_tools`: `List<String>` (legacy format)
  /// - `tools`: `Map<String, bool>` (legacy boolean flags, e.g. `urlContext=true`)
  static Set<String> parseFromOverride(Object? rawOverride) {
    final ov = rawOverride is Map ? rawOverride : null;
    final builtInSet = parseAndNormalize(
      ov?['builtInTools'] ?? ov?['built_in_tools'],
    );

    final legacyTools = ov?['tools'];
    if (legacyTools is Map) {
      for (final entry in legacyTools.entries) {
        if (entry.value == true) {
          final v = normalize(entry.key.toString());
          if (v.isNotEmpty) builtInSet.add(v);
        }
      }
    }
    return builtInSet;
  }

  /// Stable ordering for persisting tool lists (keeps UI diffs minimal).
  static List<String> orderedForStorage(Iterable<String> tools) {
    final remaining = Set<String>.from(tools);
    const preferredOrder = <String>[
      BuiltInToolNames.search,
      BuiltInToolNames.urlContext,
      BuiltInToolNames.codeExecution,
      BuiltInToolNames.youtube,
      BuiltInToolNames.codeInterpreter,
      BuiltInToolNames.imageGeneration,
      BuiltInToolNames.webFetch,
      BuiltInToolNames.shell,
    ];
    final out = <String>[
      for (final k in preferredOrder)
        if (remaining.remove(k)) k,
      ...remaining,
    ];
    return out;
  }

  /// Resolve the upstream model id that will actually be sent to the vendor.
  static String effectiveModelId({
    required ProviderConfig? cfg,
    required String? modelId,
  }) {
    final fallback = (modelId ?? '').trim();
    if (cfg == null || fallback.isEmpty) return fallback;
    final rawOverride = cfg.modelOverrides[fallback];
    final ov = rawOverride is Map ? rawOverride : null;
    final rawApiModelId = (ov?['apiModelId'] ?? ov?['api_model_id'])
        ?.toString()
        .trim();
    if (rawApiModelId != null && rawApiModelId.isNotEmpty) {
      return rawApiModelId;
    }
    return fallback;
  }
}

/// Utility class for checking provider-specific built-in tool support.
abstract class BuiltInToolsHelper {
  static const String _dashScopeHost = 'dashscope.aliyuncs.com';

  static bool _isDashScopeHost(String host) {
    return host == _dashScopeHost;
  }

  static String _normalizedModelId(String? modelId) {
    return modelId?.trim().toLowerCase() ?? '';
  }

  static DateTime? _snapshotDate(String normalizedModelId) {
    final m = RegExp(r'-(\d{4}-\d{2}-\d{2})$').firstMatch(normalizedModelId);
    if (m == null) return null;
    try {
      return DateTime.parse(m.group(1)!);
    } catch (_) {
      return null;
    }
  }

  static bool _matchesExactOrSnapshot(
    String normalizedModelId, {
    required String alias,
    String? minSnapshot,
    List<String> extraExact = const <String>[],
  }) {
    if (normalizedModelId == alias) return true;
    if (extraExact.contains(normalizedModelId)) return true;
    if (minSnapshot == null || !normalizedModelId.startsWith('$alias-')) {
      return false;
    }
    final date = _snapshotDate(normalizedModelId);
    if (date == null) return false;
    return !date.isBefore(DateTime.parse(minSnapshot));
  }

  static int? _readIntish(Object? raw) {
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }

  static bool isDashScopeProvider(ProviderConfig? cfg) {
    if (cfg == null) return false;
    final host = Uri.tryParse(cfg.baseUrl)?.host.toLowerCase() ?? '';
    return _isDashScopeHost(host);
  }

  static bool isGrokModel(String? modelId) {
    return _normalizedModelId(modelId).contains('grok');
  }

  /// Claude model gating: internal builds always qualify, everything else has
  /// to be listed explicitly because Anthropic ids carry no version ordering.
  static bool _isClaudeModelIn(String? modelId, Set<String> supported) {
    final normalized = _normalizedModelId(modelId);
    return normalized.contains('mythos') || supported.contains(normalized);
  }

  /// Current-generation Claude ids, which support every server tool below.
  static const _claudeCurrentModels = <String>{
    'claude-fable-5',
    'claude-opus-5',
    'claude-opus-4-8',
    'claude-opus-4-7',
    'claude-opus-4-6',
    'claude-sonnet-5',
    'claude-sonnet-4-6',
  };

  static bool isClaudeBuiltInSearchSupportedModel(String? modelId) {
    return _isClaudeModelIn(modelId, const <String>{
      ..._claudeCurrentModels,
      'claude-sonnet-4-5-20250929',
      'claude-sonnet-4-20250514',
      'claude-3-7-sonnet-20250219',
      'claude-haiku-4-5-20251001',
      'claude-3-5-haiku-latest',
      'claude-opus-4-1-20250805',
      'claude-opus-4-20250514',
    });
  }

  static bool isClaudeDynamicWebSearchSupportedModel(String? modelId) {
    return _isClaudeModelIn(modelId, _claudeCurrentModels);
  }

  static bool isClaudeCodeExecutionSupportedModel(String? modelId) {
    return _isClaudeModelIn(modelId, const <String>{
      ..._claudeCurrentModels,
      'claude-opus-4-5-20251101',
      'claude-sonnet-4-5-20250929',
      'claude-haiku-4-5-20251001',
    });
  }

  static bool isOpenAIResponsesBuiltInSearchSupportedModel(String? modelId) {
    final m = _normalizedModelId(modelId);
    return m.startsWith('gpt-4o') ||
        m.startsWith('gpt-4.1') ||
        m.startsWith('o4-mini') ||
        m == 'o3' ||
        m.startsWith('o3-') ||
        m.startsWith('gpt-5');
  }

  static bool isOpenRouterProvider(ProviderConfig? cfg) {
    if (cfg == null) return false;
    final host = Uri.tryParse(cfg.baseUrl)?.host.toLowerCase() ?? '';
    final providerId = cfg.id.toLowerCase();
    return host.contains('openrouter.ai') || providerId.contains('openrouter');
  }

  static Map<String, dynamic>? _openRouterServerTool(String toolName) {
    switch (BuiltInToolNames.normalize(toolName)) {
      case BuiltInToolNames.search:
        return {'type': 'openrouter:web_search'};
      case BuiltInToolNames.webFetch:
        return {'type': 'openrouter:web_fetch'};
      case BuiltInToolNames.imageGeneration:
        return {'type': 'openrouter:image_generation'};
      case BuiltInToolNames.shell:
        return {
          'type': 'openrouter:shell',
          'parameters': {'engine': 'openrouter'},
        };
      default:
        return null;
    }
  }

  static bool isDeepSeekProvider(ProviderConfig? cfg) =>
      ProviderConfig.isDeepSeekConfig(cfg);

  /// Whether [cfg] talks to Anthropic itself. The Anthropic-hosted server tools
  /// only work there: a Claude-compatible relay either rejects the tool types
  /// outright or answers from an account pool, and results from a pool cannot
  /// be replayed because the next request decrypts them against a different
  /// organisation. An empty base url is the official endpoint by default.
  static bool isOfficialAnthropicEndpoint(ProviderConfig? cfg) {
    if (cfg == null) return false;
    final raw = cfg.baseUrl.trim();
    if (raw.isEmpty) return true;
    return (Uri.tryParse(raw)?.host.toLowerCase() ?? '') == 'api.anthropic.com';
  }

  static bool isDeepSeekResponsesBuiltInSearchSupportedModel(String? modelId) {
    return _normalizedModelId(modelId).startsWith('deepseek-v4-');
  }

  static bool isDashScopeChatBuiltInSearchSupportedModel(String? modelId) {
    final m = _normalizedModelId(modelId);
    return _matchesExactOrSnapshot(
          m,
          alias: 'qwen-max',
          minSnapshot: '2024-09-19',
          extraExact: const <String>['qwen-max-latest'],
        ) ||
        _matchesExactOrSnapshot(
          m,
          alias: 'qwen3-max',
          minSnapshot: '2025-09-23',
          extraExact: const <String>['qwen3-max-preview'],
        ) ||
        _matchesExactOrSnapshot(
          m,
          alias: 'qwen-plus',
          minSnapshot: '2025-07-14',
          extraExact: const <String>['qwen-plus-latest'],
        ) ||
        _matchesExactOrSnapshot(
          m,
          alias: 'qwen3.5-plus',
          minSnapshot: '2026-02-15',
        ) ||
        _matchesExactOrSnapshot(
          m,
          alias: 'qwen-flash',
          minSnapshot: '2025-07-28',
        ) ||
        _matchesExactOrSnapshot(
          m,
          alias: 'qwen3.5-flash',
          minSnapshot: '2026-02-23',
        ) ||
        _matchesExactOrSnapshot(
          m,
          alias: 'qwen-turbo',
          minSnapshot: '2025-07-15',
          extraExact: const <String>['qwen-turbo-latest'],
        ) ||
        m == 'qwq-plus';
  }

  static bool isDashScopeResponsesBuiltInSearchSupportedModel(String? modelId) {
    final m = _normalizedModelId(modelId);
    return _matchesExactOrSnapshot(
          m,
          alias: 'qwen3.6-plus',
          minSnapshot: '2026-04-02',
        ) ||
        _matchesExactOrSnapshot(
          m,
          alias: 'qwen3.6-flash',
          minSnapshot: '2026-04-16',
        ) ||
        _matchesExactOrSnapshot(
          m,
          alias: 'qwen3.5-plus',
          minSnapshot: '2026-02-15',
        ) ||
        _matchesExactOrSnapshot(
          m,
          alias: 'qwen3.5-flash',
          minSnapshot: '2026-02-23',
        ) ||
        _matchesExactOrSnapshot(
          m,
          alias: 'qwen3-max',
          minSnapshot: '2026-01-23',
        ) ||
        // Official Responses web_search whitelist additions:
        // Qwen3.7 Max / Plus. Do NOT guess-enable 3.7 Flash.
        _matchesExactOrSnapshot(
          m,
          alias: 'qwen3.7-max',
          minSnapshot: '2026-05-17',
          extraExact: const <String>['qwen3.7-max-preview'],
        ) ||
        _matchesExactOrSnapshot(
          m,
          alias: 'qwen3.7-plus',
          minSnapshot: '2026-05-26',
        ) ||
        // Token Plan / Responses only for the preview SKU. Plain
        // `qwen3.8-max` is intentionally not opened without Key verification.
        m == 'qwen3.8-max-preview';
  }

  static bool isArkProvider(ProviderConfig? cfg) {
    if (cfg == null) return false;
    final host = Uri.tryParse(cfg.baseUrl)?.host.toLowerCase() ?? '';
    final providerId = cfg.id.toLowerCase();
    final providerName = cfg.name.toLowerCase();
    return host.contains('ark.cn-beijing.volces.com') ||
        host.contains('volces.com') ||
        ((host.contains('ark') || host.contains('volc')) &&
            (providerId.contains('doubao') ||
                providerId.contains('volc') ||
                providerId.contains('ark') ||
                providerName.contains('doubao') ||
                providerName.contains('火山') ||
                providerName.contains('方舟')));
  }

  static bool isMimoProvider(ProviderConfig? cfg) {
    if (cfg == null) return false;
    final host = Uri.tryParse(cfg.baseUrl)?.host.toLowerCase() ?? '';
    final providerId = cfg.id.toLowerCase();
    final providerName = cfg.name.toLowerCase();
    return host.contains('xiaomimimo') ||
        host.contains('mimo') ||
        providerId.contains('mimo') ||
        providerName.contains('mimo') ||
        providerName.contains('小米');
  }

  static bool isMoonshotProvider(ProviderConfig? cfg) {
    if (cfg == null) return false;
    final host = Uri.tryParse(cfg.baseUrl)?.host.toLowerCase() ?? '';
    final providerId = cfg.id.toLowerCase();
    final providerName = cfg.name.toLowerCase();
    return host.contains('moonshot') ||
        host.contains('kimi.ai') ||
        providerId.contains('moonshot') ||
        providerId.contains('kimi') ||
        providerName.contains('moonshot') ||
        providerName.contains('kimi') ||
        providerName.contains('月之暗面');
  }

  static bool isZhipuProvider(ProviderConfig? cfg) {
    if (cfg == null) return false;
    final host = Uri.tryParse(cfg.baseUrl)?.host.toLowerCase() ?? '';
    final providerId = cfg.id.toLowerCase();
    final providerName = cfg.name.toLowerCase();
    return host.contains('open.bigmodel.cn') ||
        host.contains('bigmodel') ||
        host == 'api.z.ai' ||
        providerId.contains('zhipu') ||
        providerId.contains('智谱') ||
        providerName.contains('zhipu') ||
        providerName.contains('智谱');
  }

  static bool isMimoBuiltInSearchSupportedModel(String? modelId) {
    final m = _normalizedModelId(modelId);
    return m.startsWith('mimo-v2') || m.contains('/mimo-v2');
  }

  static bool isKimiK3Model(String? modelId) {
    return RegExp(
      r'(^|[/_:@])kimi-k3(?:$|[-.])',
      caseSensitive: false,
    ).hasMatch(_normalizedModelId(modelId));
  }

  static bool isGlmBuiltInSearchSupportedModel(String? modelId) {
    final m = _normalizedModelId(modelId);
    return RegExp(r'(^|[/_:@])glm-').hasMatch(m) || m.startsWith('glm');
  }

  static bool isDoubaoResponsesBuiltInSearchSupportedModel(String? modelId) {
    final m = _normalizedModelId(modelId);
    return m.contains('doubao') ||
        m.contains('seed-1') ||
        m.contains('seed-2') ||
        m.contains('seed-evolving');
  }

  static bool supportsBuiltInSearchForModel({
    required ProviderConfig? cfg,
    required String? modelId,
  }) {
    if (cfg == null || (modelId ?? '').trim().isEmpty) return false;
    final kind = ProviderConfig.classify(
      cfg.id,
      explicitType: cfg.providerType,
    );
    final upstreamModelId = BuiltInToolNames.effectiveModelId(
      cfg: cfg,
      modelId: modelId,
    );
    switch (kind) {
      case ProviderKind.google:
        return true;
      case ProviderKind.claude:
        if (isDeepSeekProvider(cfg)) return true;
        return isClaudeBuiltInSearchSupportedModel(upstreamModelId);
      case ProviderKind.openai:
        if (isOpenRouterProvider(cfg)) {
          return true;
        }
        if (isGrokModel(upstreamModelId)) return true;
        if (cfg.useResponseApi == true) {
          if (isOpenAIResponsesBuiltInSearchSupportedModel(upstreamModelId)) {
            return true;
          }
          if (isDeepSeekProvider(cfg)) {
            return isDeepSeekResponsesBuiltInSearchSupportedModel(
              upstreamModelId,
            );
          }
          if (isDashScopeProvider(cfg)) {
            return isDashScopeResponsesBuiltInSearchSupportedModel(
              upstreamModelId,
            );
          }
          if (isArkProvider(cfg)) {
            return isDoubaoResponsesBuiltInSearchSupportedModel(
              upstreamModelId,
            );
          }
          return false;
        }
        if (isDashScopeProvider(cfg)) {
          return isDashScopeChatBuiltInSearchSupportedModel(upstreamModelId);
        }
        if (isMimoProvider(cfg)) {
          return isMimoBuiltInSearchSupportedModel(upstreamModelId);
        }
        if (isMoonshotProvider(cfg) && isKimiK3Model(upstreamModelId)) {
          return true;
        }
        if (isZhipuProvider(cfg)) {
          return isGlmBuiltInSearchSupportedModel(upstreamModelId);
        }
        return false;
    }
  }

  static Set<String> _configuredTools(
    ProviderConfig cfg,
    String modelId,
    Iterable<String>? override,
  ) {
    return override == null
        ? BuiltInToolNames.parseFromOverride(cfg.modelOverrides[modelId])
        : BuiltInToolNames.parseAndNormalize(override);
  }

  /// Builds provider-native tools and top-level fields for a Responses request.
  static BuiltInToolsRequestPayload buildResponsesTools({
    required ProviderConfig cfg,
    required String modelId,
    required String upstreamModelId,
    Iterable<String>? configuredTools,
  }) {
    final configured = _configuredTools(cfg, modelId, configuredTools);
    final tools = <Map<String, dynamic>>[];
    final body = <String, dynamic>{};

    void add(Map<String, dynamic> tool) {
      final type = (tool['type'] ?? '').toString();
      if (type.isEmpty || tools.any((item) => item['type'] == type)) return;
      tools.add(tool);
    }

    if (configured.contains(BuiltInToolNames.codeInterpreter)) {
      add({
        'type': 'code_interpreter',
        'container': {'type': 'auto', 'memory_limit': '4g'},
      });
    }

    if (isOpenRouterProvider(cfg)) {
      const supported = <String>{
        BuiltInToolNames.search,
        BuiltInToolNames.webFetch,
        BuiltInToolNames.imageGeneration,
        BuiltInToolNames.shell,
      };
      for (final name in configured) {
        if (!supported.contains(name)) continue;
        final tool = _openRouterServerTool(name);
        if (tool != null) add(tool);
      }
      return BuiltInToolsRequestPayload(tools: tools);
    }

    if (configured.contains(BuiltInToolNames.imageGeneration)) {
      add({'type': 'image_generation'});
    }
    if (!configured.contains(BuiltInToolNames.search)) {
      return BuiltInToolsRequestPayload(tools: tools);
    }
    if (isGrokModel(upstreamModelId)) {
      body['search_parameters'] = {'mode': 'auto', 'return_citations': true};
      return BuiltInToolsRequestPayload(tools: tools, body: body);
    }

    final supportsSearch =
        isOpenAIResponsesBuiltInSearchSupportedModel(upstreamModelId) ||
        (isDeepSeekProvider(cfg) &&
            isDeepSeekResponsesBuiltInSearchSupportedModel(upstreamModelId)) ||
        (isDashScopeProvider(cfg) &&
            isDashScopeResponsesBuiltInSearchSupportedModel(upstreamModelId)) ||
        (isArkProvider(cfg) &&
            isDoubaoResponsesBuiltInSearchSupportedModel(upstreamModelId));
    if (!supportsSearch) return BuiltInToolsRequestPayload(tools: tools);
    if (isDashScopeProvider(cfg) || isArkProvider(cfg)) {
      add({'type': 'web_search'});
      return BuiltInToolsRequestPayload(tools: tools);
    }

    final rawOverride = cfg.modelOverrides[modelId];
    final override = rawOverride is Map ? rawOverride : null;
    final rawSearch = override?['webSearch'];
    final search = rawSearch is Map
        ? rawSearch.cast<String, dynamic>()
        : const <String, dynamic>{};
    final usePreview =
        search['preview'] == true ||
        (search['tool'] ?? '').toString() == 'preview';
    final tool = <String, dynamic>{
      'type': usePreview ? 'web_search_preview' : 'web_search',
    };
    final allowedDomains = search['allowed_domains'];
    if (allowedDomains is List && allowedDomains.isNotEmpty) {
      tool['filters'] = {
        'allowed_domains': List<String>.from(
          allowedDomains.map((value) => value.toString()),
        ),
      };
    }
    if (search['user_location'] is Map) {
      tool['user_location'] = (search['user_location'] as Map)
          .cast<String, dynamic>();
    }
    if (usePreview && search['search_context_size'] is String) {
      tool['search_context_size'] = search['search_context_size'];
    }
    add(tool);
    return BuiltInToolsRequestPayload(tools: tools);
  }

  /// Builds provider-native tools and top-level fields for Chat Completions.
  static BuiltInToolsRequestPayload buildChatCompletionsTools({
    required ProviderConfig cfg,
    required String modelId,
    required String upstreamModelId,
    Iterable<String>? configuredTools,
  }) {
    final configured = _configuredTools(cfg, modelId, configuredTools);
    if (isOpenRouterProvider(cfg)) {
      const supported = <String>{
        BuiltInToolNames.search,
        BuiltInToolNames.webFetch,
        BuiltInToolNames.imageGeneration,
      };
      return BuiltInToolsRequestPayload(
        tools: <Map<String, dynamic>>[
          for (final name in configured)
            if (supported.contains(name)) _openRouterServerTool(name)!,
        ],
      );
    }
    if (!configured.contains(BuiltInToolNames.search)) {
      return const BuiltInToolsRequestPayload();
    }
    if (isGrokModel(upstreamModelId)) {
      return const BuiltInToolsRequestPayload(
        body: <String, dynamic>{
          'search_parameters': <String, dynamic>{
            'mode': 'auto',
            'return_citations': true,
          },
        },
      );
    }
    if (isDashScopeProvider(cfg) &&
        isDashScopeChatBuiltInSearchSupportedModel(upstreamModelId)) {
      final options = dashScopeSearchOptionsFromOverride(
        cfg.modelOverrides[modelId],
      );
      return BuiltInToolsRequestPayload(
        body: <String, dynamic>{
          'enable_search': true,
          if (options.isNotEmpty) 'search_options': options,
        },
      );
    }
    if (isMimoProvider(cfg) &&
        isMimoBuiltInSearchSupportedModel(upstreamModelId)) {
      return const BuiltInToolsRequestPayload(
        tools: <Map<String, dynamic>>[
          <String, dynamic>{'type': 'web_search'},
        ],
      );
    }
    if (isZhipuProvider(cfg) &&
        isGlmBuiltInSearchSupportedModel(upstreamModelId)) {
      return const BuiltInToolsRequestPayload(
        tools: <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'web_search',
            'web_search': <String, dynamic>{
              'enable': true,
              'search_result': true,
            },
          },
        ],
      );
    }
    return const BuiltInToolsRequestPayload();
  }

  static bool isBuiltInSearchEnabled({
    required ProviderConfig? cfg,
    required String? modelId,
    bool requireSupport = true,
  }) {
    if (cfg == null || modelId == null || modelId.trim().isEmpty) {
      return false;
    }
    final rawOv = cfg.modelOverrides[modelId];
    final builtInSet = BuiltInToolNames.parseFromOverride(rawOv);
    if (!builtInSet.contains(BuiltInToolNames.search)) return false;
    if (!requireSupport) return true;
    return supportsBuiltInSearchForModel(cfg: cfg, modelId: modelId);
  }

  /// Upstream model id when [cfg] talks to the official Claude API, or null
  /// for anything else — Vertex and Claude-compatible vendors reject the
  /// Anthropic-hosted server tools.
  static String? _claudeUpstreamModelId({
    required ProviderConfig? cfg,
    required String? modelId,
  }) {
    if (cfg == null || (modelId ?? '').trim().isEmpty) return null;
    final kind = ProviderConfig.classify(
      cfg.id,
      explicitType: cfg.providerType,
    );
    if (kind != ProviderKind.claude || !isOfficialAnthropicEndpoint(cfg)) {
      return null;
    }
    return BuiltInToolNames.effectiveModelId(cfg: cfg, modelId: modelId);
  }

  static bool supportsClaudeDynamicWebSearchForModel({
    required ProviderConfig? cfg,
    required String? modelId,
  }) {
    final upstreamModelId = _claudeUpstreamModelId(cfg: cfg, modelId: modelId);
    return upstreamModelId != null &&
        isClaudeDynamicWebSearchSupportedModel(upstreamModelId);
  }

  /// Persisted marker for the dynamic-filtering web search opt-in. Kept as a
  /// tool type string for backward compatibility with settings written before
  /// newer versions shipped; [claudeSearchToolTypeDynamic] is what gets sent.
  static const claudeSearchToolVersionMarker = 'web_search_20260209';

  static const claudeSearchToolTypeBasic = 'web_search_20250305';
  static const claudeSearchToolTypeDynamic = 'web_search_20260318';
  static const claudeFetchToolTypeBasic = 'web_fetch_20250910';
  static const claudeFetchToolTypeDynamic = 'web_fetch_20260318';

  /// Unbounded by default, and a large documentation page is worth ~25k
  /// tokens. Bound it low enough that a couple of fetches in one turn still
  /// leave room to answer. Text only: the API does not apply this to binary
  /// content, so a fetched PDF still arrives whole.
  static const claudeFetchMaxContentTokens = 30000;

  /// Dynamic filtering runs inside code execution, which requires this version
  /// or later; older types make the API inject a conflicting `code_execution`.
  static const claudeCodeExecutionToolType = 'code_execution_20260521';

  static bool isClaudeDynamicWebSearchEnabled({
    required ProviderConfig? cfg,
    required String? modelId,
  }) {
    if (!supportsClaudeDynamicWebSearchForModel(cfg: cfg, modelId: modelId)) {
      return false;
    }
    if (cfg == null || modelId == null || modelId.trim().isEmpty) {
      return false;
    }
    final rawOv = cfg.modelOverrides[modelId];
    final ov = rawOv is Map ? rawOv : null;
    final rawWs = ov?['webSearch'];
    if (rawWs is! Map) return false;
    final ws = rawWs.cast<String, dynamic>();
    return ws['toolVersion'] == claudeSearchToolVersionMarker ||
        ws['tool_version'] == claudeSearchToolVersionMarker;
  }

  /// [rawOverride] with the dynamic-filtering opt-in set to [enabled] — the
  /// write side of [isClaudeDynamicWebSearchEnabled].
  static Map<String, dynamic> withClaudeDynamicWebSearch(
    Object? rawOverride,
    bool enabled,
  ) {
    final mo = <String, dynamic>{
      if (rawOverride is Map)
        for (final e in rawOverride.entries) e.key.toString(): e.value,
    };
    final rawWs = mo['webSearch'];
    final ws = <String, dynamic>{
      if (rawWs is Map)
        for (final e in rawWs.entries) e.key.toString(): e.value,
    };
    if (enabled) {
      ws['toolVersion'] = claudeSearchToolVersionMarker;
    } else {
      ws.remove('toolVersion');
      ws.remove('tool_version');
    }
    if (ws.isEmpty) {
      mo.remove('webSearch');
    } else {
      mo['webSearch'] = ws;
    }
    return mo;
  }

  static String claudeBuiltInSearchToolType({
    required ProviderConfig? cfg,
    required String? modelId,
  }) {
    return isClaudeDynamicWebSearchEnabled(cfg: cfg, modelId: modelId)
        ? claudeSearchToolTypeDynamic
        : claudeSearchToolTypeBasic;
  }

  /// Anthropic ships web fetch on the same models as built-in search, with one
  /// documented hole: Opus 5 runs every other server tool but not this one, so
  /// declaring it there is an error rather than an unused tool.
  static bool isClaudeWebFetchSupportedModel(String? modelId) =>
      _normalizedModelId(modelId) != 'claude-opus-5' &&
      isClaudeBuiltInSearchSupportedModel(modelId);

  /// Request entries for the Anthropic-hosted server tools beyond search, whose
  /// entry is shaped by the per-model web search options instead. These run on
  /// the official Claude API only; Claude-compatible vendors and Vertex reject
  /// them.
  static List<Map<String, dynamic>> claudeServerToolEntries({
    required ProviderConfig? cfg,
    required String? modelId,
    required Set<String> enabled,
  }) {
    final upstreamModelId = _claudeUpstreamModelId(cfg: cfg, modelId: modelId);
    if (upstreamModelId == null) return const <Map<String, dynamic>>[];
    final dynamicFiltering = isClaudeDynamicWebSearchEnabled(
      cfg: cfg,
      modelId: modelId,
    );
    return <Map<String, dynamic>>[
      if (enabled.contains(BuiltInToolNames.webFetch) &&
          isClaudeWebFetchSupportedModel(upstreamModelId))
        <String, dynamic>{
          'type': dynamicFiltering
              ? claudeFetchToolTypeDynamic
              : claudeFetchToolTypeBasic,
          'name': 'web_fetch',
          'max_content_tokens': claudeFetchMaxContentTokens,
        },
      if (enabled.contains(BuiltInToolNames.codeExecution) &&
          isClaudeCodeExecutionSupportedModel(upstreamModelId))
        <String, dynamic>{
          'type': claudeCodeExecutionToolType,
          'name': 'code_execution',
        },
    ];
  }

  /// Whether a turn for [modelId] on [cfg] hands the user's data files to a
  /// code execution sandbox instead of reading them into the prompt.
  ///
  /// The message builder skips text extraction for those files on the
  /// strength of this answer, so it has to agree exactly with the provider
  /// that does the upload: today only the official Claude endpoint, whose
  /// Files API feeds `container_upload`. Gemini shares the
  /// `code_execution` tool name but takes no files from us yet, so
  /// [BuiltInToolsState.codeExecutionActive] alone is the wrong test. A
  /// client tool of that name displaces the hosted one in the request, and
  /// with it the upload, so the [clientTools] definitions are part of the
  /// answer too.
  static bool sendsDataFilesToSandbox({
    required ProviderConfig? cfg,
    required String? modelId,
    Iterable<Map<String, dynamic>> clientTools = const [],
  }) {
    final upstreamModelId = _claudeUpstreamModelId(cfg: cfg, modelId: modelId);
    if (upstreamModelId == null) return false;
    if (!isClaudeCodeExecutionSupportedModel(upstreamModelId)) return false;
    if (clientTools.map(claimedToolName).contains('code_execution')) {
      return false;
    }
    return getActiveTools(cfg: cfg, modelId: modelId).codeExecutionActive;
  }

  /// The name a client tool definition claims, and takes from a hosted tool
  /// of the same name: `function.name` in the OpenAI shape the app assembles,
  /// empty for anything else, which the Claude adapter's conversion also
  /// drops. Every reader of a tool name goes through here, so no caller can
  /// look in the wrong place, and the predicate cannot count a definition the
  /// request will not carry.
  static String claimedToolName(Map<String, dynamic> tool) {
    final fn = tool['function'];
    return fn is Map ? (fn['name'] ?? '').toString() : '';
  }

  static Map<String, dynamic> dashScopeSearchOptionsFromOverride(
    Object? rawOverride,
  ) {
    final ov = rawOverride is Map ? rawOverride : null;
    final rawWs = ov?['webSearch'];
    if (rawWs is! Map) return const <String, dynamic>{};
    final ws = rawWs.cast<String, dynamic>();
    final out = <String, dynamic>{};

    final strategy = ws['search_strategy']?.toString().trim();
    if (strategy != null && strategy.isNotEmpty) {
      out['search_strategy'] = strategy;
    }

    if (ws['forced_search'] is bool) {
      out['forced_search'] = ws['forced_search'];
    }
    if (ws['enable_search_extension'] is bool) {
      out['enable_search_extension'] = ws['enable_search_extension'];
    }

    final freshness = _readIntish(ws['freshness']);
    if (freshness != null) {
      out['freshness'] = freshness;
    }

    final assignedSites = ws['assigned_site_list'] ?? ws['allowed_domains'];
    if (assignedSites is List && assignedSites.isNotEmpty) {
      out['assigned_site_list'] = List<String>.from(
        assignedSites
            .map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty),
      );
    }

    if (ws['intention_options'] is Map) {
      out['intention_options'] = (ws['intention_options'] as Map)
          .cast<String, dynamic>();
    } else {
      final promptIntervene = ws['prompt_intervene']?.toString().trim();
      if (promptIntervene != null && promptIntervene.isNotEmpty) {
        out['intention_options'] = {'prompt_intervene': promptIntervene};
      }
    }

    return out;
  }

  /// Tool names edited in a model's built-in tools tab. Search is excluded
  /// because it is controlled from the chat search switch.
  static Set<String> modelSettingsToolNames(ProviderConfig cfg) {
    final kind = ProviderConfig.classify(
      cfg.id,
      explicitType: cfg.providerType,
    );
    if (kind == ProviderKind.google) {
      return const <String>{
        BuiltInToolNames.urlContext,
        BuiltInToolNames.codeExecution,
        BuiltInToolNames.youtube,
      };
    }
    if (kind == ProviderKind.claude) {
      if (isDeepSeekProvider(cfg)) return const <String>{};
      return const <String>{
        BuiltInToolNames.webFetch,
        BuiltInToolNames.codeExecution,
      };
    }
    if (kind != ProviderKind.openai) return const <String>{};
    if (isOpenRouterProvider(cfg)) {
      return <String>{
        BuiltInToolNames.webFetch,
        BuiltInToolNames.imageGeneration,
        if (cfg.useResponseApi == true) BuiltInToolNames.codeInterpreter,
        if (cfg.useResponseApi == true) BuiltInToolNames.shell,
      };
    }
    return const <String>{
      BuiltInToolNames.codeInterpreter,
      BuiltInToolNames.imageGeneration,
    };
  }

  static Set<String> replaceModelSettingsTools({
    required ProviderConfig cfg,
    required Iterable<String> current,
    required Iterable<String> selected,
  }) {
    final editable = modelSettingsToolNames(cfg);
    final result = BuiltInToolNames.parseAndNormalize(current);
    // Only clear what this API mode can edit, so tools hidden by the current
    // mode (e.g. OpenRouter code_interpreter on Chat Completions) survive a save.
    result.removeAll(editable);
    result.addAll(
      selected.map(BuiltInToolNames.normalize).where(editable.contains),
    );
    return result;
  }

  /// Check if the provider/model combination supports search tool.
  static bool supportsSearch({
    required ProviderKind kind,
    required bool useResponseApi,
    String? modelId,
  }) {
    switch (kind) {
      case ProviderKind.google:
        return true;
      case ProviderKind.claude:
        return true;
      case ProviderKind.openai:
        // OpenAI requires Responses API, or Grok models
        if (useResponseApi &&
            isOpenAIResponsesBuiltInSearchSupportedModel(modelId)) {
          return true;
        }
        if (useResponseApi &&
            isDashScopeResponsesBuiltInSearchSupportedModel(modelId)) {
          return true;
        }
        if (useResponseApi &&
            isDoubaoResponsesBuiltInSearchSupportedModel(modelId)) {
          return true;
        }
        if (isGrokModel(modelId)) return true;
        if (isDashScopeChatBuiltInSearchSupportedModel(modelId)) return true;
        if (isMimoBuiltInSearchSupportedModel(modelId)) return true;
        if (isKimiK3Model(modelId)) return true;
        if (isGlmBuiltInSearchSupportedModel(modelId)) return true;
        return false;
    }
  }

  /// Get active built-in tools from model overrides.
  static BuiltInToolsState getActiveTools({
    required ProviderConfig? cfg,
    required String? modelId,
  }) {
    if (cfg == null || modelId == null) {
      return const BuiltInToolsState();
    }

    final rawOv = cfg.modelOverrides[modelId];
    final builtInSet = BuiltInToolNames.parseFromOverride(rawOv);

    final bool searchActive = isBuiltInSearchEnabled(
      cfg: cfg,
      modelId: modelId,
    );
    final active = builtInSet.intersection(modelSettingsToolNames(cfg));

    return BuiltInToolsState(
      searchActive: searchActive,
      codeExecutionActive: active.contains(BuiltInToolNames.codeExecution),
      urlContextActive: active.contains(BuiltInToolNames.urlContext),
      youtubeActive: active.contains(BuiltInToolNames.youtube),
      codeInterpreterActive: active.contains(BuiltInToolNames.codeInterpreter),
      imageGenerationActive: active.contains(BuiltInToolNames.imageGeneration),
    );
  }
}

/// State class representing active built-in tools.
class BuiltInToolsState {
  final bool searchActive;
  final bool codeExecutionActive;
  final bool urlContextActive;
  final bool youtubeActive;
  final bool codeInterpreterActive;
  final bool imageGenerationActive;

  const BuiltInToolsState({
    this.searchActive = false,
    this.codeExecutionActive = false,
    this.urlContextActive = false,
    this.youtubeActive = false,
    this.codeInterpreterActive = false,
    this.imageGenerationActive = false,
  });

  /// Returns true if any Gemini-specific built-in tool is active.
  bool get anyGeminiToolActive =>
      codeExecutionActive || urlContextActive || youtubeActive;
}
