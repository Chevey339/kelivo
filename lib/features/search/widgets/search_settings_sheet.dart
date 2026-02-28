import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/search/search_service.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/services/api/builtin_tools.dart';
import '../../../icons/lucide_adapter.dart';
import '../pages/search_services_page.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/brand_assets.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../core/services/haptics.dart';

Future<void> showSearchSettingsSheet(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => const _SearchSettingsSheet(),
  );
}

class _SearchSettingsSheet extends StatelessWidget {
  const _SearchSettingsSheet();

  String _nameOf(BuildContext context, SearchServiceOptions s) {
    final svc = SearchService.getService(s);
    return svc.name;
  }

  String? _statusOf(BuildContext context, SearchServiceOptions s) {
    final l10n = AppLocalizations.of(context)!;
    if (s is BingLocalOptions) return null;
    if (s is DuckDuckGoOptions) return l10n.searchServicesPageConfiguredStatus;
    if (s is TavilyOptions)
      return s.apiKey.isNotEmpty
          ? l10n.searchServicesPageConfiguredStatus
          : l10n.searchServicesPageApiKeyRequiredStatus;
    if (s is ExaOptions)
      return s.apiKey.isNotEmpty
          ? l10n.searchServicesPageConfiguredStatus
          : l10n.searchServicesPageApiKeyRequiredStatus;
    if (s is ZhipuOptions)
      return s.apiKey.isNotEmpty
          ? l10n.searchServicesPageConfiguredStatus
          : l10n.searchServicesPageApiKeyRequiredStatus;
    if (s is SearXNGOptions)
      return s.url.isNotEmpty
          ? l10n.searchServicesPageConfiguredStatus
          : l10n.searchServicesPageUrlRequiredStatus;
    if (s is LinkUpOptions)
      return s.apiKey.isNotEmpty
          ? l10n.searchServicesPageConfiguredStatus
          : l10n.searchServicesPageApiKeyRequiredStatus;
    if (s is BraveOptions)
      return s.apiKey.isNotEmpty
          ? l10n.searchServicesPageConfiguredStatus
          : l10n.searchServicesPageApiKeyRequiredStatus;
    if (s is MetasoOptions)
      return s.apiKey.isNotEmpty
          ? l10n.searchServicesPageConfiguredStatus
          : l10n.searchServicesPageApiKeyRequiredStatus;
    if (s is OllamaOptions)
      return s.apiKey.isNotEmpty
          ? l10n.searchServicesPageConfiguredStatus
          : l10n.searchServicesPageApiKeyRequiredStatus;
    if (s is JinaOptions)
      return s.apiKey.isNotEmpty
          ? l10n.searchServicesPageConfiguredStatus
          : l10n.searchServicesPageApiKeyRequiredStatus;
    if (s is PerplexityOptions)
      return s.apiKey.isNotEmpty
          ? l10n.searchServicesPageConfiguredStatus
          : l10n.searchServicesPageApiKeyRequiredStatus;
    if (s is BochaOptions)
      return s.apiKey.isNotEmpty
          ? l10n.searchServicesPageConfiguredStatus
          : l10n.searchServicesPageApiKeyRequiredStatus;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final ap = context.watch<AssistantProvider>();
    final a = ap.currentAssistant;
    final services = settings.searchServices;
    final selected = settings.searchServiceSelected.clamp(
      0,
      services.isNotEmpty ? services.length - 1 : 0,
    );
    final enabled = settings.searchEnabled;

    // Determine if current selected model supports built-in search
    final providerKey = a?.chatModelProvider ?? settings.currentModelProvider;
    final modelId = a?.chatModelId ?? settings.currentModelId;
    final cfg = (providerKey != null)
        ? settings.getProviderConfig(providerKey)
        : null;
    final isGeminiProvider =
        cfg != null && cfg.providerType == ProviderKind.google;
    final isClaude = cfg != null && cfg.providerType == ProviderKind.claude;
    final isOpenAIResponses =
        cfg != null &&
        cfg.providerType == ProviderKind.openai &&
        (cfg.useResponseApi == true);
    final isGrok =
        cfg != null &&
        cfg.providerType == ProviderKind.openai &&
        (modelId ?? '').toLowerCase().contains('grok');

    // Read current built-in search/url_context toggle from modelOverrides
    bool hasBuiltInSearch = false;
    bool hasUrlContext = false;
    if ((isGeminiProvider || isClaude || isOpenAIResponses || isGrok) &&
        providerKey != null &&
        (modelId ?? '').isNotEmpty) {
      final mid = modelId!;
      final rawOv = cfg!.modelOverrides[mid];
      final ov = rawOv is Map ? rawOv : null;
      final builtInSet = BuiltInToolNames.parseAndNormalize(ov?['builtInTools']);
      hasBuiltInSearch = builtInSet.contains(BuiltInToolNames.search);
      hasUrlContext = builtInSet.contains(BuiltInToolNames.urlContext);
    }
    // When url_context is active, treat as built-in search mode (hide external search options)
    final builtInMode = hasBuiltInSearch || hasUrlContext;
    // Claude supported models per Anthropic docs
    final claudeSupportedModels = <String>{
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
    final isClaudeSupportedModel =
        isClaude &&
        (modelId != null) &&
        claudeSupportedModels.contains(modelId.toLowerCase());
    // OpenAI Responses supported models for web_search tool
    bool _isOpenAIResponsesSupportedModel(String id) {
      final m = id.toLowerCase();
      return m.startsWith('gpt-4o') ||
          m.startsWith('gpt-4.1') ||
          m.startsWith('o4-mini') ||
          m == 'o3' ||
          m.startsWith('o3-') ||
          m.startsWith('gpt-5');
    }

    final isOpenAIResponsesSupportedModel =
        isOpenAIResponses &&
        (modelId != null) &&
        _isOpenAIResponsesSupportedModel(modelId!);

    final maxHeight = MediaQuery.of(context).size.height * 0.8;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    l10n.searchSettingsSheetTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Built-in search toggle (Gemini, Claude supported, or OpenAI Responses supported)
                if ((isGeminiProvider ||
                        isClaudeSupportedModel ||
                        isOpenAIResponsesSupportedModel ||
                        isGrok) &&
                    (providerKey != null) &&
                    (modelId ?? '').isNotEmpty) ...[
                  IosCardPress(
                    borderRadius: BorderRadius.circular(14),
                    baseColor: cs.surface,
                    duration: const Duration(milliseconds: 260),
                    onTap: () async {
                      if (providerKey == null || (modelId ?? '').isEmpty)
                        return;
                      Haptics.light();
                      final bool v = !hasBuiltInSearch;
                      final mid = modelId!;
                      final overrides = Map<String, dynamic>.from(
                        cfg!.modelOverrides,
                      );
                      final rawMo = overrides[mid];
                      final baseMo = rawMo is Map ? rawMo : null;
                      final mo = Map<String, dynamic>.from(
                        baseMo?.map(
                              (k, val) => MapEntry(k.toString(), val),
                            ) ??
                            const <String, dynamic>{},
                      );
                      final builtIns = BuiltInToolNames.parseAndNormalize(mo['builtInTools']);
                      if (v) {
                        builtIns.add(BuiltInToolNames.search);
                      } else {
                        builtIns.remove(BuiltInToolNames.search);
                      }
                      if (builtIns.isEmpty) {
                        mo.remove('builtInTools');
                      } else {
                        mo['builtInTools'] = BuiltInToolNames.orderedForStorage(builtIns);
                      }
                      overrides[mid] = mo;
                      await context.read<SettingsProvider>().setProviderConfig(
                        providerKey,
                        cfg.copyWith(modelOverrides: overrides),
                      );
                      if (v) {
                        await context.read<SettingsProvider>().setSearchEnabled(
                          false,
                        );
                      }
                    },
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Icon(Lucide.Search, size: 20, color: cs.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.searchSettingsSheetBuiltinSearchTitle,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        IosSwitch(
                          value: hasBuiltInSearch,
                          onChanged: (v) async {
                            if (providerKey == null || (modelId ?? '').isEmpty)
                              return;
                            Haptics.light();
                            final mid = modelId!;
                            final overrides = Map<String, dynamic>.from(
                              cfg!.modelOverrides,
                            );
                            final rawMo = overrides[mid];
                            final baseMo = rawMo is Map ? rawMo : null;
                            final mo = Map<String, dynamic>.from(
                              baseMo?.map(
                                    (k, val) => MapEntry(k.toString(), val),
                                  ) ??
                                  const <String, dynamic>{},
                            );
                            final builtIns = BuiltInToolNames.parseAndNormalize(mo['builtInTools']);
                            if (v) {
                              builtIns.add(BuiltInToolNames.search);
                            } else {
                              builtIns.remove(BuiltInToolNames.search);
                            }
                            if (builtIns.isEmpty) {
                              mo.remove('builtInTools');
                            } else {
                              mo['builtInTools'] = BuiltInToolNames.orderedForStorage(builtIns);
                            }
                            overrides[mid] = mo;
                            await context
                                .read<SettingsProvider>()
                                .setProviderConfig(
                                  providerKey,
                                  cfg.copyWith(modelOverrides: overrides),
                                );
                            if (v) {
                              await context
                                  .read<SettingsProvider>()
                                  .setSearchEnabled(false);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Toggle card
                if (!builtInMode) ...[
                  IosCardPress(
                    borderRadius: BorderRadius.circular(14),
                    baseColor: cs.surface,
                    duration: const Duration(milliseconds: 260),
                    onTap: () {
                      Haptics.light();
                      context.read<SettingsProvider>().setSearchEnabled(
                        !enabled,
                      );
                    },
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Icon(Lucide.Globe, size: 20, color: cs.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.searchSettingsSheetWebSearchTitle,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip:
                              l10n.searchSettingsSheetOpenSearchServicesTooltip,
                          icon: Icon(Lucide.Settings, size: 20),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SearchServicesPage(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 4),
                        IosSwitch(
                          value: enabled,
                          onChanged: (v) => context
                              .read<SettingsProvider>()
                              .setSearchEnabled(v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                // Services list (iOS-style rows like learning mode)
                if (!builtInMode && services.isNotEmpty) ...[
                  ...List.generate(services.length, (i) {
                    final s = services[i];
                    final bool isSelected = i == selected;
                    final Color onColor = isSelected
                        ? cs.primary
                        : cs.onSurface;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: SizedBox(
                        height: 48,
                        child: IosCardPress(
                          borderRadius: BorderRadius.circular(14),
                          baseColor: cs.surface,
                          duration: const Duration(milliseconds: 260),
                          onTap: () {
                            Haptics.light();
                            context
                                .read<SettingsProvider>()
                                .setSearchServiceSelected(i);
                            Navigator.of(context).maybePop();
                          },
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              // Brand icon
                              _BrandBadge.forService(s, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _nameOf(context, s),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: onColor,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(Lucide.Check, size: 18, color: cs.primary)
                              else
                                const SizedBox(width: 18),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                ] else if (!builtInMode) ...[
                  Text(
                    l10n.searchSettingsSheetNoServicesMessage,
                    style: TextStyle(color: cs.onSurface.withOpacity(0.7)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceTileLarge extends StatelessWidget {
  const _ServiceTileLarge({
    this.leading,
    required this.label,
    required this.selected,
    this.status,
    required this.onTap,
  });
  final Widget? leading;
  final String label;
  final bool selected;
  final _TileStatus? status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = selected
        ? cs.primary.withOpacity(isDark ? 0.18 : 0.12)
        : (isDark ? Colors.white12 : const Color(0xFFF7F7F9));
    final fg = selected ? cs.primary : cs.onSurface.withOpacity(0.85);
    final border = selected ? Border.all(color: cs.primary, width: 1.2) : null;
    final statusBg = status?.bg ?? cs.onSurface.withOpacity(0.06);
    final statusFg = status?.fg ?? cs.onSurface.withOpacity(0.7);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: border,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: fg.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: leading ?? Icon(Lucide.Search, size: 18, color: fg),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                    if ((status?.text ?? '').isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status!.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10.5, color: statusFg),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileStatus {
  final String text;
  final Color bg;
  final Color fg;
  const _TileStatus({required this.text, required this.bg, required this.fg});
}

// Brand badge for known services using assets/icons; falls back to letter if unknown
class _BrandBadge extends StatelessWidget {
  const _BrandBadge({required this.name, this.size = 20});
  final String name;
  final double size;

  static Widget forService(SearchServiceOptions s, {double size = 24}) {
    final n = _nameForService(s);
    return _BrandBadge(name: n, size: size);
  }

  static String _nameForService(SearchServiceOptions s) {
    if (s is BingLocalOptions) return 'bing';
    if (s is DuckDuckGoOptions) return 'duckduckgo';
    if (s is TavilyOptions) return 'tavily';
    if (s is ExaOptions) return 'exa';
    if (s is ZhipuOptions) return 'zhipu';
    if (s is SearXNGOptions) return 'searxng';
    if (s is LinkUpOptions) return 'linkup';
    if (s is BraveOptions) return 'brave';
    if (s is MetasoOptions) return 'metaso';
    if (s is OllamaOptions) return 'ollama';
    if (s is JinaOptions) return 'jina';
    if (s is PerplexityOptions) return 'perplexity';
    if (s is BochaOptions) return 'bocha';
    return 'search';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Use BrandAssets to get the icon path
    final asset = BrandAssets.assetForName(name);
    final bg = isDark ? Colors.white10 : cs.primary.withOpacity(0.1);
    if (asset != null) {
      if (asset!.endsWith('.svg')) {
        final isColorful = asset!.contains('color');
        final ColorFilter? tint = (isDark && !isColorful)
            ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
            : null;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: SvgPicture.asset(
            asset!,
            width: size * 0.62,
            height: size * 0.62,
            colorFilter: tint,
          ),
        );
      } else {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Image.asset(
            asset!,
            width: size * 0.62,
            height: size * 0.62,
            fit: BoxFit.contain,
          ),
        );
      }
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
        style: TextStyle(
          color: cs.primary,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}
