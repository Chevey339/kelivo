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
      if (e.key.hasMatch(key)) {
        result = 'assets/icons/${e.value}';
        break;
      }
    }
    _cache[key] = result;
    return result;
  }

  /// Clear the in-memory cache (useful after changing mappings at runtime).
  static void clearCache() => _cache.clear();

  static final Map<String, String?> _cache = <String, String?>{};

  // Keep order-specific matching using a list of entries.
  static final List<MapEntry<RegExp, String>> _mapping =
      <MapEntry<RegExp, String>>[
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
        MapEntry(RegExp(r'sensenova|sensetime|商汤|日日新'), 'sensenova-color.svg'),
        MapEntry(RegExp(r'aihubmix'), 'aihubmix-color.svg'),
        MapEntry(RegExp(r'ollama'), 'ollama.svg'),
        MapEntry(RegExp(r'github'), 'github.svg'),
        MapEntry(RegExp(r'cloudflare'), 'cloudflare-color.svg'),
        MapEntry(RegExp(r'minimax'), 'minimax-color.svg'),
        MapEntry(RegExp(r'xai'), 'xai.svg'),
        MapEntry(RegExp(r'juhenext'), 'juhenext.png'),
        MapEntry(
          RegExp(r'kimi|moonshot|月之暗面|(?:^|[-_/])k3(?:$|[-.])'),
          'kimi-color.svg',
        ),
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
        MapEntry(RegExp(r'serper'), 'serper.svg'),
        MapEntry(RegExp(r'querit'), 'querit-color.svg'),
        MapEntry(RegExp(r'bocha|博查'), 'bocha-color.svg'),
        MapEntry(RegExp(r'kat'), 'katkwaipilot-color.svg'),
        MapEntry(RegExp(r'duckduckgo'), 'duckduckgo-color.svg'),
        MapEntry(RegExp(r'inclusionai'), 'ling.png'),
        MapEntry(RegExp(r'mimo|xiaomi|小米'), 'mimo.svg'),
        MapEntry(RegExp(r'codex'), 'codex.svg'),
      ];

  static const List<BrandIconOption> selectableIcons = <BrandIconOption>[
    BrandIconOption(
      id: 'openai',
      label: 'OpenAI',
      asset: 'assets/icons/openai.svg',
    ),
    BrandIconOption(
      id: 'gemini',
      label: 'Gemini',
      asset: 'assets/icons/gemini-color.svg',
    ),
    BrandIconOption(
      id: 'google',
      label: 'Google',
      asset: 'assets/icons/google-color.svg',
    ),
    BrandIconOption(
      id: 'claude',
      label: 'Claude',
      asset: 'assets/icons/claude-color.svg',
    ),
    BrandIconOption(
      id: 'anthropic',
      label: 'Anthropic',
      asset: 'assets/icons/anthropic.svg',
    ),
    BrandIconOption(
      id: 'deepseek',
      label: 'DeepSeek',
      asset: 'assets/icons/deepseek-color.svg',
    ),
    BrandIconOption(id: 'grok', label: 'Grok', asset: 'assets/icons/grok.svg'),
    BrandIconOption(
      id: 'qwen',
      label: 'Qwen',
      asset: 'assets/icons/qwen-color.svg',
    ),
    BrandIconOption(
      id: 'doubao',
      label: 'Doubao',
      asset: 'assets/icons/doubao-color.svg',
    ),
    BrandIconOption(
      id: 'openrouter',
      label: 'OpenRouter',
      asset: 'assets/icons/openrouter.svg',
    ),
    BrandIconOption(
      id: 'zhipu',
      label: 'Zhipu',
      asset: 'assets/icons/zhipu-color.svg',
    ),
    BrandIconOption(
      id: 'mistral',
      label: 'Mistral',
      asset: 'assets/icons/mistral-color.svg',
    ),
    BrandIconOption(
      id: 'metaso',
      label: 'Metaso',
      asset: 'assets/icons/metaso-color.svg',
    ),
    BrandIconOption(
      id: 'meta',
      label: 'Meta',
      asset: 'assets/icons/meta-color.svg',
    ),
    BrandIconOption(
      id: 'hunyuan',
      label: 'Hunyuan',
      asset: 'assets/icons/hunyuan-color.svg',
    ),
    BrandIconOption(
      id: 'gemma',
      label: 'Gemma',
      asset: 'assets/icons/gemma-color.svg',
    ),
    BrandIconOption(
      id: 'perplexity',
      label: 'Perplexity',
      asset: 'assets/icons/perplexity-color.svg',
    ),
    BrandIconOption(
      id: 'alibabacloud',
      label: 'Alibaba Cloud',
      asset: 'assets/icons/alibabacloud-color.svg',
    ),
    BrandIconOption(
      id: 'bytedance',
      label: 'ByteDance',
      asset: 'assets/icons/bytedance-color.svg',
    ),
    BrandIconOption(
      id: 'siliconflow',
      label: 'SiliconFlow',
      asset: 'assets/icons/siliconflow-color.svg',
    ),
    BrandIconOption(
      id: 'sensenova',
      label: 'SenseNova',
      asset: 'assets/icons/sensenova-color.svg',
    ),
    BrandIconOption(
      id: 'aihubmix',
      label: 'AiHubMix',
      asset: 'assets/icons/aihubmix-color.svg',
    ),
    BrandIconOption(
      id: 'ollama',
      label: 'Ollama',
      asset: 'assets/icons/ollama.svg',
    ),
    BrandIconOption(
      id: 'github',
      label: 'GitHub',
      asset: 'assets/icons/github.svg',
    ),
    BrandIconOption(
      id: 'cloudflare',
      label: 'Cloudflare',
      asset: 'assets/icons/cloudflare-color.svg',
    ),
    BrandIconOption(
      id: 'minimax',
      label: 'MiniMax',
      asset: 'assets/icons/minimax-color.svg',
    ),
    BrandIconOption(id: 'xai', label: 'xAI', asset: 'assets/icons/xai.svg'),
    BrandIconOption(
      id: 'juhenext',
      label: 'JuheNext',
      asset: 'assets/icons/juhenext.png',
    ),
    BrandIconOption(
      id: 'kimi',
      label: 'Kimi',
      asset: 'assets/icons/kimi-color.svg',
    ),
    BrandIconOption(
      id: '302ai',
      label: '302.AI',
      asset: 'assets/icons/302ai-color.svg',
    ),
    BrandIconOption(
      id: 'stepfun',
      label: 'StepFun',
      asset: 'assets/icons/stepfun-color.svg',
    ),
    BrandIconOption(
      id: 'internlm',
      label: 'InternLM',
      asset: 'assets/icons/internlm-color.svg',
    ),
    BrandIconOption(
      id: 'cohere',
      label: 'Cohere',
      asset: 'assets/icons/cohere-color.svg',
    ),
    BrandIconOption(
      id: 'kelivo',
      label: 'Kelivo',
      asset: 'assets/icons/kelivo.png',
    ),
    BrandIconOption(
      id: 'tensdaq',
      label: 'Tensdaq',
      asset: 'assets/icons/tensdaq-color.svg',
    ),
    BrandIconOption(
      id: 'longcat',
      label: 'LongCat',
      asset: 'assets/icons/longcat.png',
    ),
    BrandIconOption(
      id: 'iflow',
      label: 'iFlow',
      asset: 'assets/icons/iflow-color.svg',
    ),
    BrandIconOption(
      id: 'sora',
      label: 'Sora',
      asset: 'assets/icons/sora-color.svg',
    ),
    BrandIconOption(
      id: 'bing',
      label: 'Bing',
      asset: 'assets/icons/bing-color.svg',
    ),
    BrandIconOption(
      id: 'tavily',
      label: 'Tavily',
      asset: 'assets/icons/tavily-color.svg',
    ),
    BrandIconOption(
      id: 'exa',
      label: 'Exa',
      asset: 'assets/icons/exa-color.svg',
    ),
    BrandIconOption(
      id: 'linkup',
      label: 'Linkup',
      asset: 'assets/icons/linkup.svg',
    ),
    BrandIconOption(
      id: 'brave',
      label: 'Brave',
      asset: 'assets/icons/brave-color.svg',
    ),
    BrandIconOption(
      id: 'jina',
      label: 'Jina',
      asset: 'assets/icons/jina-color.svg',
    ),
    BrandIconOption(
      id: 'searxng',
      label: 'SearXNG',
      asset: 'assets/icons/searxng-color.svg',
    ),
    BrandIconOption(
      id: 'serper',
      label: 'Serper',
      asset: 'assets/icons/serper.svg',
    ),
    BrandIconOption(
      id: 'querit',
      label: 'Querit',
      asset: 'assets/icons/querit-color.svg',
    ),
    BrandIconOption(
      id: 'bocha',
      label: 'Bocha',
      asset: 'assets/icons/bocha-color.svg',
    ),
    BrandIconOption(
      id: 'kat',
      label: 'KAT',
      asset: 'assets/icons/katkwaipilot-color.svg',
    ),
    BrandIconOption(
      id: 'duckduckgo',
      label: 'DuckDuckGo',
      asset: 'assets/icons/duckduckgo-color.svg',
    ),
    BrandIconOption(id: 'ling', label: 'Ling', asset: 'assets/icons/ling.png'),
    BrandIconOption(id: 'mimo', label: 'MiMo', asset: 'assets/icons/mimo.svg'),
    BrandIconOption(
      id: 'codex',
      label: 'Codex',
      asset: 'assets/icons/codex.svg',
    ),
  ];

  static String? selectableAssetOrNull(String asset) {
    if (asset.isEmpty) return null;
    final normalized = asset.trim();
    for (final opt in selectableIcons) {
      if (opt.asset == normalized) return normalized;
    }
    return null;
  }

  static bool assetNeedsDarkInvert(String asset) {
    return asset.contains('openai') ||
        asset.contains('anthropic') ||
        asset.contains('grok') ||
        asset.contains('xai') ||
        asset.contains('openrouter') ||
        asset.contains('ollama') ||
        asset.contains('github') ||
        asset.contains('codex') ||
        asset.contains('mimo');
  }

  // Build the LobeHub static SVG CDN URL from an icon name (e.g. 'openai').
  static String lobehubIconUrl(String name) {
    final n = name.trim().toLowerCase();
    return 'https://unpkg.com/@lobehub/icons-static-svg@latest/icons/$n.svg';
  }
}

class BrandIconOption {
  const BrandIconOption({
    required this.id,
    required this.label,
    required this.asset,
  });
  final String id;
  final String label;
  final String asset; // e.g. 'assets/icons/openai.svg'
}
