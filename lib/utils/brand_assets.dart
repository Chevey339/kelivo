/// Centralized brand icon resolver.
/// Returns an asset path like `assets/icons/openai.svg` for a given name/model.
class BrandAssets {
  BrandAssets._();

  /// Resolve an icon asset path for a provider/model name.
  /// Returns null if no known mapping matches.
  static String? assetForName(String name) {
    final key = name.trim().toLowerCase();
    if (key.isEmpty) return null;
    // Recompute if previously cached as null so newly added mappings take effect without restart.
    if (_cache.containsKey(key) && _cache[key] != null) return _cache[key];
    String? result;
    for (final e in _mapping) {
      if (e.key.hasMatch(key)) { result = 'assets/icons/${e.value}'; break; }
    }
    _cache[key] = result;
    return result;
  }

  /// Clear the in-memory cache (useful after changing mappings at runtime).
  static void clearCache() => _cache.clear();

  static final Map<String, String?> _cache = <String, String?>{};

  // Keep order-specific matching using a list of entries.
  static final List<MapEntry<RegExp, String>> _mapping = <MapEntry<RegExp, String>>[
    MapEntry(RegExp(r'memorylake'), 'memorylake.svg'),
    MapEntry(RegExp(r'openai|gpt|o\d'), 'openai.svg'),
    MapEntry(RegExp(r'gemini'), 'gemini-color.svg'),
    MapEntry(RegExp(r'google'), 'google-color.svg'),
    MapEntry(RegExp(r'claude'), 'claude-color.svg'),
    MapEntry(RegExp(r'anthropic'), 'anthropic.svg'),
    MapEntry(RegExp(r'deepseek'), 'deepseek-color.svg'),
    MapEntry(RegExp(r'grok'), 'grok.svg'),
    MapEntry(RegExp(r'qwen|qwq|qvq'), 'qwen-color.svg'),
    MapEntry(RegExp(r'doubao'), 'doubao-color.svg'),
    MapEntry(RegExp(r'openrouter'), 'openrouter.svg'),
    MapEntry(RegExp(r'zhipu|智谱|glm'), 'zhipu-color.svg'),
    MapEntry(RegExp(r'mistral'), 'mistral-color.svg'),
    MapEntry(RegExp(r'metaso|秘塔'), 'metaso-color.svg'),
    MapEntry(RegExp(r'(?<!o)llama|meta'), 'meta-color.svg'),
    MapEntry(RegExp(r'hunyuan|tencent'), 'hunyuan-color.svg'),
    MapEntry(RegExp(r'gemma'), 'gemma-color.svg'),
    MapEntry(RegExp(r'perplexity'), 'perplexity-color.svg'),
    MapEntry(RegExp(r'aliyun|阿里云|百炼'), 'alibabacloud-color.svg'),
    MapEntry(RegExp(r'bytedance|火山'), 'bytedance-color.svg'),
    MapEntry(RegExp(r'silicon|硅基'), 'siliconflow-color.svg'),
    MapEntry(RegExp(r'aihubmix'), 'aihubmix-color.svg'),
    MapEntry(RegExp(r'ollama'), 'ollama.svg'),
    MapEntry(RegExp(r'github'), 'github.svg'),
    MapEntry(RegExp(r'cloudflare'), 'cloudflare-color.svg'),
    MapEntry(RegExp(r'minimax'), 'minimax-color.svg'),
    MapEntry(RegExp(r'xai'), 'xai.svg'),
    MapEntry(RegExp(r'juhenext'), 'juhenext.png'),
    MapEntry(RegExp(r'kimi'), 'kimi-color.svg'),
    MapEntry(RegExp(r'302'), '302ai-color.svg'),
    MapEntry(RegExp(r'step|阶跃'), 'stepfun-color.svg'),
    MapEntry(RegExp(r'internlm|书生'), 'internlm-color.svg'),
    MapEntry(RegExp(r'cohere|command-.+'), 'cohere-color.svg'),
    MapEntry(RegExp(r'kelivo'), 'kelivo.png'),
    MapEntry(RegExp(r'tensdaq'), 'tensdaq-color.svg'),
    MapEntry(RegExp(r'longcat'), 'longcat.png'),
    MapEntry(RegExp(r'iflow|心流'), 'iflow-color.svg'),
    MapEntry(RegExp(r'sora'), 'sora-color.svg'),
    MapEntry(RegExp(r'bing|必应'), 'bing-color.svg'),
    MapEntry(RegExp(r'tavily'), 'tavily-color.svg'),
    MapEntry(RegExp(r'exa'), 'exa-color.svg'),
    MapEntry(RegExp(r'linkup'), 'linkup.svg'),
    MapEntry(RegExp(r'brave'), 'brave-color.svg'),
    MapEntry(RegExp(r'jina'), 'jina-color.svg'),
    MapEntry(RegExp(r'searxng'), 'searxng-color.svg'),
    MapEntry(RegExp(r'bocha|博查'), 'bocha-color.svg'),
    MapEntry(RegExp(r'kat'), 'katkwaipilot-color.svg'),
    MapEntry(RegExp(r'duckduckgo'), 'duckduckgo-color.svg'),
    MapEntry(RegExp(r'inclusionai'), 'ling.png'),
    MapEntry(RegExp(r'mimo|xiaomi|小米'), 'mimo.svg'),
  ];
}
