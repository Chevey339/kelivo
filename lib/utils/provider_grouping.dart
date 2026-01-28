import '../core/providers/settings_provider.dart';

/// Provider "channel" grouping used by the Providers UI.
///
/// `ProviderConfig.group` stores one of the known ids below, or null for auto.
class ProviderGrouping {
  static const String idOfficial = 'official';
  static const String idSelfHosted = 'self_hosted';
  static const String idLocal = 'local';
  static const String idPublic = 'public';
  static const String idOther = 'other';

  static const List<String> orderedGroupIds = <String>[
    idOfficial,
    idSelfHosted,
    idLocal,
    idPublic,
  ];

  static String? normalizeId(String? id) {
    final v = id?.trim();
    if (v == null || v.isEmpty) return null;
    switch (v) {
      case idOfficial:
      case idSelfHosted:
      case idLocal:
      case idPublic:
        return v;
      default:
        return null;
    }
  }

  static String classify({
    required String providerKey,
    required ProviderConfig config,
  }) {
    final override = normalizeId(config.group);
    if (override != null) return override;

    final host = _hostOf(config.baseUrl);
    if (_isLocalHost(host) || _isPrivateIp(host)) return idLocal;

    final keyLower = providerKey.trim().toLowerCase();
    if (keyLower == 'kelivoin' || host.endsWith('pollinations.ai')) return idPublic;

    if (_isKnownOfficialHost(host) || _isBuiltInProviderKey(keyLower)) return idOfficial;

    return idSelfHosted;
  }

  static bool _isBuiltInProviderKey(String keyLower) {
    // Keep this small and stable; it is only used for auto-classification.
    const builtIn = <String>{
      'openai',
      'gemini',
      'google',
      'siliconflow',
      'openrouter',
      'tensdaq',
      'deepseek',
      'aihubmix',
      'aliyun',
      'zhipu ai',
      'claude',
      'grok',
      'bytedance',
    };
    return builtIn.contains(keyLower);
  }

  static bool _isKnownOfficialHost(String hostLower) {
    if (hostLower.isEmpty) return false;
    const suffixes = <String>[
      'openai.com',
      'anthropic.com',
      'googleapis.com',
      'siliconflow.cn',
      'openrouter.ai',
      'aihubmix.com',
      'aliyuncs.com',
      'bigmodel.cn',
      'volces.com',
      'deepseek.com',
      'x.ai',
      'x-aio.com',
    ];
    return suffixes.any((s) => hostLower == s || hostLower.endsWith('.$s'));
  }

  static bool _isLocalHost(String hostLower) {
    if (hostLower.isEmpty) return false;
    return hostLower == 'localhost' || hostLower == '127.0.0.1' || hostLower == '::1' || hostLower.endsWith('.local');
  }

  static bool _isPrivateIp(String hostLower) {
    // Match common private IPv4 ranges (and link-local).
    final m = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').firstMatch(hostLower);
    if (m == null) return false;
    final parts = hostLower.split('.').map((e) => int.tryParse(e) ?? -1).toList();
    if (parts.length != 4 || parts.any((e) => e < 0 || e > 255)) return false;
    final a = parts[0];
    final b = parts[1];
    if (a == 10) return true;
    if (a == 127) return true;
    if (a == 192 && b == 168) return true;
    if (a == 169 && b == 254) return true; // link-local
    if (a == 172 && b >= 16 && b <= 31) return true;
    return false;
  }

  static String _hostOf(String baseUrl) {
    final s = baseUrl.trim();
    if (s.isEmpty) return '';
    final uri = Uri.tryParse(s);
    if (uri != null && uri.host.isNotEmpty) return uri.host.toLowerCase();
    // Fallback for inputs without scheme, e.g. "api.example.com/v1".
    final parts = s.split('/').where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    return parts.first.toLowerCase();
  }
}
