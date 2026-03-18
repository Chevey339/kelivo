import '../../providers/settings_provider.dart';

/// Built-in tool name constants for API integrations.
/// Use these constants instead of raw strings to ensure consistency.
abstract class BuiltInToolNames {
  // Common
  static const search = 'search';

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

  static bool isClaudeBuiltInSearchSupportedModel(String? modelId) {
    const supported = <String>{
      'claude-opus-4-6',
      'claude-sonnet-4-5-20250929',
      'claude-sonnet-4-20250514',
      'claude-3-7-sonnet-20250219',
      'claude-haiku-4-5-20251001',
      'claude-3-5-haiku-latest',
      'claude-sonnet-4-6',
      'claude-opus-4-1-20250805',
      'claude-opus-4-20250514',
    };
    return supported.contains(_normalizedModelId(modelId));
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
        );
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
        return isClaudeBuiltInSearchSupportedModel(upstreamModelId);
      case ProviderKind.openai:
        if (isGrokModel(upstreamModelId)) return true;
        if (cfg.useResponseApi == true) {
          if (isOpenAIResponsesBuiltInSearchSupportedModel(upstreamModelId)) {
            return true;
          }
          if (isDashScopeProvider(cfg)) {
            return isDashScopeResponsesBuiltInSearchSupportedModel(
              upstreamModelId,
            );
          }
          return false;
        }
        if (isDashScopeProvider(cfg)) {
          return isDashScopeChatBuiltInSearchSupportedModel(upstreamModelId);
        }
        return false;
    }
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

  /// Check if a provider supports built-in tools configuration.
  static bool supportsBuiltInTools(ProviderKind kind) {
    return kind == ProviderKind.google || kind == ProviderKind.openai;
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
        if (isGrokModel(modelId)) return true;
        if (isDashScopeChatBuiltInSearchSupportedModel(modelId)) return true;
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

    final kind = ProviderConfig.classify(
      cfg.id,
      explicitType: cfg.providerType,
    );
    final rawOv = cfg.modelOverrides[modelId];
    final builtInSet = BuiltInToolNames.parseFromOverride(rawOv);

    final bool searchActive = isBuiltInSearchEnabled(cfg: cfg, modelId: modelId);
    bool codeExecutionActive = false;
    bool urlContextActive = false;
    bool youtubeActive = false;
    bool codeInterpreterActive = false;
    bool imageGenerationActive = false;

    if (kind == ProviderKind.google) {
      codeExecutionActive = builtInSet.contains(BuiltInToolNames.codeExecution);
      urlContextActive = builtInSet.contains(BuiltInToolNames.urlContext);
      youtubeActive = builtInSet.contains(BuiltInToolNames.youtube);
    } else if (kind == ProviderKind.openai) {
      codeInterpreterActive = builtInSet.contains(
        BuiltInToolNames.codeInterpreter,
      );
      imageGenerationActive = builtInSet.contains(
        BuiltInToolNames.imageGeneration,
      );
    }

    return BuiltInToolsState(
      searchActive: searchActive,
      codeExecutionActive: codeExecutionActive,
      urlContextActive: urlContextActive,
      youtubeActive: youtubeActive,
      codeInterpreterActive: codeInterpreterActive,
      imageGenerationActive: imageGenerationActive,
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
