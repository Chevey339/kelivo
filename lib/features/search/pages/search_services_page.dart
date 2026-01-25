import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/search/search_service.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../utils/brand_assets.dart';
import '../../../core/services/haptics.dart';
import '../../../shared/widgets/ios_switch.dart';

class SearchServicesPage extends StatefulWidget {
  const SearchServicesPage({super.key});

  @override
  State<SearchServicesPage> createState() => _SearchServicesPageState();
}

class _SearchServicesPageState extends State<SearchServicesPage> {
  List<SearchServiceOptions> _services = [];
  int _selectedIndex = 0;
  final Map<String, bool> _testing = <String, bool>{}; // serviceId -> testing
  // Use SettingsProvider for connection results; keep only local testing spinner state

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _services = List.from(settings.searchServices);
    _selectedIndex = settings.searchServiceSelected;
    // Do not auto test here; rely on app-start tests. Users can test manually.
  }

  void _addService() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      backgroundColor: Colors.transparent,
      builder: (context) => _AddServiceBottomSheet(
        onAdd: (service) {
          setState(() {
            _services.add(service);
          });
          _saveChanges();
        },
      ),
    );
  }

  void _editService(int index) {
    final service = _services[index];
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _EditServiceSheet(
        service: service,
        onSave: (updated) {
          setState(() {
            _services[index] = updated;
          });
          _saveChanges();
        },
      ),
    );
  }

  void _deleteService(int index) {
    if (_services.length <= 1) {
      final l10n = AppLocalizations.of(context)!;
      showAppSnackBar(
        context,
        message: l10n.searchServicesPageAtLeastOneServiceRequired,
        type: NotificationType.warning,
      );
      return;
    }

    setState(() {
      _services.removeAt(index);
      if (_selectedIndex >= _services.length) {
        _selectedIndex = _services.length - 1;
      } else if (_selectedIndex > index) {
        _selectedIndex--;
      }
    });
    _saveChanges();
  }

  void _selectService(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _saveChanges();
  }

  void _saveChanges() {
    final settings = context.read<SettingsProvider>();
    context.read<SettingsProvider>().updateSettings(
      settings.copyWith(
        searchServices: _services,
        searchServiceSelected: _selectedIndex,
      ),
    );
  }

  Future<void> _testConnection(int index) async {
    if (index < 0 || index >= _services.length) return;
    final s = _services[index];
    final id = s.id;
    setState(() {
      _testing[id] = true;
    });
    try {
      final svc = SearchService.getService(s);
      final settings = context.read<SettingsProvider>();
      // Use a tiny search to validate connectivity
      final common = SearchCommonOptions(
        resultSize: 1,
        timeout: settings.searchCommonOptions.timeout,
      );
      await svc.search(
        query: 'connectivity test',
        commonOptions: common,
        serviceOptions: s,
      );
      settings.setSearchConnection(id, true);
    } catch (_) {
      context.read<SettingsProvider>().setSearchConnection(id, false);
    } finally {
      setState(() {
        _testing[id] = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        leading: Tooltip(
          message: l10n.searchServicesPageBackTooltip,
          child: _TactileIconButton(
            icon: Lucide.ArrowLeft,
            color: cs.onSurface,
            size: 22,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(l10n.searchServicesPageTitle),
        actions: [
          Tooltip(
            message: l10n.searchServicesPageAddProvider,
            child: _TactileIconButton(
              icon: Lucide.Plus,
              color: cs.onSurface,
              size: 22,
              onTap: _addService,
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _sectionHeader(
            l10n.searchServicesPageSearchProviders,
            cs,
            first: true,
          ),
          _iosSectionCard(
            children: [
              for (int i = 0; i < _services.length; i++) ...[
                _iosProviderRow(context, index: i),
                if (i != _services.length - 1) _iosDivider(context),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _sectionHeader(l10n.searchServicesPageGeneralOptions, cs),
          _buildCommonOptionsSection(context),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text, ColorScheme cs, {bool first = false}) =>
      Padding(
        padding: EdgeInsets.fromLTRB(12, first ? 2 : 18, 12, 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: cs.onSurface.withOpacity(0.8),
          ),
        ),
      );

  Widget _buildCommonOptionsSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final common = settings.searchCommonOptions;
    final autoTestOnLaunch = settings.searchAutoTestOnLaunch;
    final l10n = AppLocalizations.of(context)!;

    Widget stepper({
      required int value,
      required VoidCallback onMinus,
      required VoidCallback onPlus,
      String? unit,
    }) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SmallTactileIcon(icon: Lucide.Minus, onTap: onMinus, enabled: true),
          const SizedBox(width: 8),
          Text(
            unit == null ? '$value' : '$value$unit',
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurface.withOpacity(0.8),
            ),
          ),
          const SizedBox(width: 8),
          _SmallTactileIcon(icon: Lucide.Plus, onTap: onPlus, enabled: true),
        ],
      );
    }

    return _iosSectionCard(
      children: [
        _TactileRow(
          onTap: () => context
              .read<SettingsProvider>()
              .setSearchAutoTestOnLaunch(!autoTestOnLaunch),
          pressedScale: 0.995,
          builder: (pressed) {
            final baseColor = cs.onSurface.withOpacity(0.9);
            return _AnimatedPressColor(
              pressed: pressed,
              base: baseColor,
              builder: (c) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: Icon(Lucide.HeartPulse, size: 18, color: c),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.searchServicesPageAutoTestTitle,
                              style: TextStyle(fontSize: 15, color: c),
                            ),
                          ],
                        ),
                      ),
                      IosSwitch(
                        value: autoTestOnLaunch,
                        onChanged: (v) => context
                            .read<SettingsProvider>()
                            .setSearchAutoTestOnLaunch(v),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        _iosDivider(context),
        _TactileRow(
          onTap: null, // no navigation, so no chevron
          pressedScale: 1.00,
          haptics: false,
          builder: (pressed) {
            final baseColor = cs.onSurface.withOpacity(0.9);
            return _AnimatedPressColor(
              pressed: pressed,
              base: baseColor,
              builder: (c) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: Icon(Lucide.ListOrdered, size: 18, color: c),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.searchServicesPageMaxResults,
                          style: TextStyle(fontSize: 15, color: c),
                        ),
                      ),
                      stepper(
                        value: common.resultSize,
                        onMinus: common.resultSize > 1
                            ? () => context
                                  .read<SettingsProvider>()
                                  .updateSettings(
                                    settings.copyWith(
                                      searchCommonOptions: SearchCommonOptions(
                                        resultSize: common.resultSize - 1,
                                        timeout: common.timeout,
                                      ),
                                    ),
                                  )
                            : () {},
                        onPlus: common.resultSize < 50
                            ? () => context
                                  .read<SettingsProvider>()
                                  .updateSettings(
                                    settings.copyWith(
                                      searchCommonOptions: SearchCommonOptions(
                                        resultSize: common.resultSize + 1,
                                        timeout: common.timeout,
                                      ),
                                    ),
                                  )
                            : () {},
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        _iosDivider(context),
        _TactileRow(
          onTap: null,
          pressedScale: 1.00,
          haptics: false,
          builder: (pressed) {
            final baseColor = cs.onSurface.withOpacity(0.9);
            return _AnimatedPressColor(
              pressed: pressed,
              base: baseColor,
              builder: (c) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: Icon(Lucide.History, size: 18, color: c),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.searchServicesPageTimeoutSeconds,
                          style: TextStyle(fontSize: 15, color: c),
                        ),
                      ),
                      stepper(
                        value: common.timeout ~/ 1000,
                        onMinus: common.timeout > 1000
                            ? () => context
                                  .read<SettingsProvider>()
                                  .updateSettings(
                                    settings.copyWith(
                                      searchCommonOptions: SearchCommonOptions(
                                        resultSize: common.resultSize,
                                        timeout: common.timeout - 1000,
                                      ),
                                    ),
                                  )
                            : () {},
                        onPlus: common.timeout < 30000
                            ? () => context
                                  .read<SettingsProvider>()
                                  .updateSettings(
                                    settings.copyWith(
                                      searchCommonOptions: SearchCommonOptions(
                                        resultSize: common.resultSize,
                                        timeout: common.timeout + 1000,
                                      ),
                                    ),
                                  )
                            : () {},
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _iosProviderRow(BuildContext context, {required int index}) {
    final s = _services[index];
    final cs = Theme.of(context).colorScheme;
    final name = SearchService.getService(s).name;
    final selected = index == _selectedIndex;
    // Connection/testing status for capsule
    final l10n = AppLocalizations.of(context)!;
    final testing = _testing[s.id] == true;
    final conn = context.watch<SettingsProvider>().searchConnection[s.id];
    String statusText;
    Color statusBg;
    Color statusFg;
    if (testing) {
      statusText = l10n.searchServicesPageTestingStatus;
      statusBg = cs.primary.withOpacity(0.12);
      statusFg = cs.primary;
    } else if (conn == true) {
      statusText = l10n.searchServicesPageConnectedStatus;
      statusBg = Colors.green.withOpacity(0.12);
      statusFg = Colors.green;
    } else if (conn == false) {
      statusText = l10n.searchServicesPageFailedStatus;
      statusBg = Colors.orange.withOpacity(0.12);
      statusFg = Colors.orange;
    } else {
      statusText = l10n.searchServicesPageNotTestedStatus;
      statusBg = cs.onSurface.withOpacity(0.06);
      statusFg = cs.onSurface.withOpacity(0.7);
    }
    return _TactileRow(
      onTap: () {
        // Tap to edit (bottom sheet)
        _editService(index);
      },
      pressedScale: 1.00,
      haptics: false,
      builder: (pressed) {
        final base = cs.onSurface.withOpacity(0.9);
        return _AnimatedPressColor(
          pressed: pressed,
          base: base,
          builder: (c) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: () => _showServiceActions(context, index),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Center(child: _BrandBadge.forService(s, size: 22)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          color: c,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (s is! BingLocalOptions && statusText.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: statusFg),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Icon(Lucide.ChevronRight, size: 16, color: c),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showServiceActions(BuildContext context, int index) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sheetOption(
                  ctx,
                  icon: Lucide.Activity,
                  label: l10n.searchServicesPageTestConnectionTooltip,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _testConnection(index);
                  },
                ),
                _sheetDivider(ctx),
                _sheetOption(
                  ctx,
                  icon: Lucide.Trash2,
                  label: l10n.providerDetailPageDeleteButton,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _deleteService(index);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getServiceIcon(SearchServiceOptions service) {
    if (service is BingLocalOptions) return Lucide.Search;
    if (service is DuckDuckGoOptions) return Lucide.Search;
    if (service is TavilyOptions) return Lucide.Sparkles;
    if (service is ExaOptions) return Lucide.Brain;
    if (service is ZhipuOptions) return Lucide.Languages;
    if (service is SearXNGOptions) return Lucide.Shield;
    if (service is LinkUpOptions) return Lucide.Link2;
    if (service is BraveOptions) return Lucide.Shield;
    if (service is MetasoOptions) return Lucide.Compass;
    if (service is JinaOptions) return Lucide.Sparkles;
    if (service is PerplexityOptions) return Lucide.Search;
    if (service is BochaOptions) return Lucide.Search;
    return Lucide.Search;
  }

  String? _getServiceStatus(SearchServiceOptions service) {
    final l10n = AppLocalizations.of(context)!;
    if (service is BingLocalOptions) return null;
    if (service is DuckDuckGoOptions)
      return l10n.searchServicesPageConfiguredStatus;
    if (service is TavilyOptions)
      return service.apiKey.isNotEmpty
          ? l10n.searchServicesPageConfiguredStatus
          : l10n.searchServicesPageApiKeyRequiredStatus;
    if (service is ExaOptions)
      return service.apiKey.isNotEmpty
          ? l10n.searchServicesPageConfiguredStatus
          : l10n.searchServicesPageApiKeyRequiredStatus;
    if (service is ZhipuOptions)
      return service.apiKey.isNotEmpty
          ? l10n.searchServicesPageConfiguredStatus
          : l10n.searchServicesPageApiKeyRequiredStatus;
    if (service is SearXNGOptions)
      return service.url.isNotEmpty
          ? l10n.searchServicesPageConfiguredStatus
          : l10n.searchServicesPageUrlRequiredStatus;
    if (service is LinkUpOptions)
      return service.apiKey.isNotEmpty
          ? l10n.searchServicesPageConfiguredStatus
          : l10n.searchServicesPageApiKeyRequiredStatus;
    if (service is BraveOptions)
      return service.apiKey.isNotEmpty
          ? l10n.searchServicesPageConfiguredStatus
          : l10n.searchServicesPageApiKeyRequiredStatus;
    if (service is MetasoOptions)
      return service.apiKey.isNotEmpty
          ? l10n.searchServicesPageConfiguredStatus
          : l10n.searchServicesPageApiKeyRequiredStatus;
    if (service is OllamaOptions)
      return service.apiKey.isNotEmpty
          ? l10n.searchServicesPageConfiguredStatus
          : l10n.searchServicesPageApiKeyRequiredStatus;
    if (service is JinaOptions)
      return service.apiKey.isNotEmpty
          ? l10n.searchServicesPageConfiguredStatus
          : l10n.searchServicesPageApiKeyRequiredStatus;
    if (service is BochaOptions)
      return service.apiKey.isNotEmpty
          ? l10n.searchServicesPageConfiguredStatus
          : l10n.searchServicesPageApiKeyRequiredStatus;
    return null;
  }

  // Brand badge for known services using assets/icons; falls back to letter if unknown
  // ignore: unused_element
  Widget _brandBadgeForName(String name, {double size = 20}) =>
      _BrandBadge(name: name, size: size);
}

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

// Add Service Bottom Sheet - iOS Style
class _AddServiceBottomSheet extends StatefulWidget {
  final Function(SearchServiceOptions) onAdd;

  const _AddServiceBottomSheet({required this.onAdd});

  @override
  State<_AddServiceBottomSheet> createState() => _AddServiceBottomSheetState();
}

class _AddServiceBottomSheetState extends State<_AddServiceBottomSheet> {
  String? _selectedType;
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title with animation
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: Padding(
                    key: ValueKey<String?>(_selectedType),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Text(
                      _selectedType == null
                          ? l10n.searchServicesAddDialogTitle
                          : _getServiceName(_selectedType!),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                // Service type selection or form with fade animation
                Flexible(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: _selectedType == null
                        ? _buildServiceTypeList()
                        : _buildFormView(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceTypeList() {
    final l10n = AppLocalizations.of(context)!;
    final services = [
      {'type': 'bing_local', 'name': l10n.searchServiceNameBingLocal},
      {'type': 'duckduckgo', 'name': l10n.searchServiceNameDuckDuckGo},
      {'type': 'tavily', 'name': l10n.searchServiceNameTavily},
      {'type': 'exa', 'name': l10n.searchServiceNameExa},
      {'type': 'zhipu', 'name': l10n.searchServiceNameZhipu},
      {'type': 'searxng', 'name': l10n.searchServiceNameSearXNG},
      {'type': 'linkup', 'name': l10n.searchServiceNameLinkUp},
      {'type': 'brave', 'name': l10n.searchServiceNameBrave},
      {'type': 'metaso', 'name': l10n.searchServiceNameMetaso},
      {'type': 'jina', 'name': l10n.searchServiceNameJina},
      {'type': 'ollama', 'name': l10n.searchServiceNameOllama},
      {'type': 'perplexity', 'name': l10n.searchServiceNamePerplexity},
      {'type': 'bocha', 'name': l10n.searchServiceNameBocha},
    ];
    return ListView.builder(
      key: const ValueKey('service_list'),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      shrinkWrap: true,
      itemCount: services.length,
      itemBuilder: (context, index) {
        final item = services[index];
        return Column(
          children: [
            _sheetOption(
              context,
              icon: Lucide.Globe,
              label: item['name'] as String,
              leading: _ServiceIcon(
                type: item['type'] as String,
                name: item['name'] as String,
                size: 36,
              ),
              bgOnPress: false,
              onTap: () {
                setState(() => _selectedType = item['type'] as String);
              },
            ),
            if (index != services.length - 1) _sheetDivider(context),
          ],
        );
      },
    );
  }

  String _getServiceName(String type) {
    final l10n = AppLocalizations.of(context)!;
    switch (type) {
      case 'bing_local':
        return l10n.searchServiceNameBingLocal;
      case 'duckduckgo':
        return l10n.searchServiceNameDuckDuckGo;
      case 'tavily':
        return l10n.searchServiceNameTavily;
      case 'exa':
        return l10n.searchServiceNameExa;
      case 'zhipu':
        return l10n.searchServiceNameZhipu;
      case 'searxng':
        return l10n.searchServiceNameSearXNG;
      case 'linkup':
        return l10n.searchServiceNameLinkUp;
      case 'brave':
        return l10n.searchServiceNameBrave;
      case 'metaso':
        return l10n.searchServiceNameMetaso;
      case 'jina':
        return l10n.searchServiceNameJina;
      case 'ollama':
        return l10n.searchServiceNameOllama;
      case 'perplexity':
        return l10n.searchServiceNamePerplexity;
      case 'bocha':
        return l10n.searchServiceNameBocha;
      default:
        return '';
    }
  }

  Widget _buildFormView() {
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      key: const ValueKey('form_view'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            ..._buildFieldsForType(_selectedType!),
            const SizedBox(height: 20),
            // Add button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final service = _createService();
                    widget.onAdd(service);
                    Navigator.pop(context);
                  }
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  l10n.searchServicesAddDialogAdd,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFieldsForType(String type) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget _buildTextField({
      required String key,
      required String label,
      String? hint,
      bool obscureText = false,
      String? initialValue,
      String? Function(String?)? validator,
    }) {
      _controllers[key] ??= TextEditingController(text: initialValue);
      return Container(
        decoration: BoxDecoration(
          color: cs.surfaceVariant.withOpacity(isDark ? 0.18 : 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextFormField(
          controller: _controllers[key],
          obscureText: obscureText,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          validator: validator,
        ),
      );
    }

    switch (type) {
      case 'bing_local':
        return [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceVariant.withOpacity(isDark ? 0.18 : 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Lucide.Search, size: 20, color: cs.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.searchServiceNameBingLocal,
                    style: TextStyle(
                      fontSize: 14,
                      color: cs.onSurface.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ];
      case 'duckduckgo':
        return [
          _buildTextField(
            key: 'region',
            label: l10n.searchServicesAddDialogRegionOptional,
            hint: 'us-en',
            initialValue: 'us-en',
          ),
        ];
      case 'tavily':
      case 'exa':
      case 'zhipu':
      case 'linkup':
      case 'brave':
      case 'metaso':
      case 'jina':
      case 'ollama':
      case 'perplexity':
      case 'bocha':
        return [
          _buildTextField(
            key: 'apiKey',
            label: 'API Key',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.searchServicesAddDialogApiKeyRequired;
              }
              return null;
            },
          ),
        ];
      case 'searxng':
        return [
          _buildTextField(
            key: 'url',
            label: l10n.searchServicesAddDialogInstanceUrl,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.searchServicesAddDialogUrlRequired;
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          _buildTextField(
            key: 'engines',
            label: l10n.searchServicesAddDialogEnginesOptional,
            hint: 'google,duckduckgo',
          ),
          const SizedBox(height: 12),
          _buildTextField(
            key: 'language',
            label: l10n.searchServicesAddDialogLanguageOptional,
            hint: 'en-US',
          ),
          const SizedBox(height: 12),
          _buildTextField(
            key: 'username',
            label: l10n.searchServicesAddDialogUsernameOptional,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            key: 'password',
            label: l10n.searchServicesAddDialogPasswordOptional,
            obscureText: true,
          ),
        ];
      default:
        return [];
    }
  }

  SearchServiceOptions _createService() {
    final uuid = const Uuid();
    final id = uuid.v4().substring(0, 8);

    switch (_selectedType) {
      case 'bing_local':
        return BingLocalOptions(id: id);
      case 'duckduckgo':
        final region = (_controllers['region']?.text ?? 'us-en').trim();
        return DuckDuckGoOptions(
          id: id,
          region: region.isEmpty ? 'us-en' : region,
        );
      case 'tavily':
        return TavilyOptions(id: id, apiKey: _controllers['apiKey']!.text);
      case 'exa':
        return ExaOptions(id: id, apiKey: _controllers['apiKey']!.text);
      case 'zhipu':
        return ZhipuOptions(id: id, apiKey: _controllers['apiKey']!.text);
      case 'searxng':
        return SearXNGOptions(
          id: id,
          url: _controllers['url']!.text,
          engines: _controllers['engines']!.text,
          language: _controllers['language']!.text,
          username: _controllers['username']!.text,
          password: _controllers['password']!.text,
        );
      case 'linkup':
        return LinkUpOptions(id: id, apiKey: _controllers['apiKey']!.text);
      case 'brave':
        return BraveOptions(id: id, apiKey: _controllers['apiKey']!.text);
      case 'metaso':
        return MetasoOptions(id: id, apiKey: _controllers['apiKey']!.text);
      case 'jina':
        return JinaOptions(id: id, apiKey: _controllers['apiKey']!.text);
      case 'ollama':
        return OllamaOptions(id: id, apiKey: _controllers['apiKey']!.text);
      case 'perplexity':
        return PerplexityOptions(id: id, apiKey: _controllers['apiKey']!.text);
      case 'bocha':
        return BochaOptions(id: id, apiKey: _controllers['apiKey']!.text);
      default:
        return BingLocalOptions(id: id);
    }
  }
}

// Edit Service Bottom Sheet (iOS style)
class _EditServiceSheet extends StatefulWidget {
  final SearchServiceOptions service;
  final Function(SearchServiceOptions) onSave;

  const _EditServiceSheet({required this.service, required this.onSave});

  @override
  State<_EditServiceSheet> createState() => _EditServiceSheetState();
}

class _EditServiceSheetState extends State<_EditServiceSheet> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    final service = widget.service;
    if (service is TavilyOptions) {
      _controllers['apiKey'] = TextEditingController(text: service.apiKey);
    } else if (service is DuckDuckGoOptions) {
      _controllers['region'] = TextEditingController(text: service.region);
    } else if (service is ExaOptions) {
      _controllers['apiKey'] = TextEditingController(text: service.apiKey);
    } else if (service is ZhipuOptions) {
      _controllers['apiKey'] = TextEditingController(text: service.apiKey);
    } else if (service is SearXNGOptions) {
      _controllers['url'] = TextEditingController(text: service.url);
      _controllers['engines'] = TextEditingController(text: service.engines);
      _controllers['language'] = TextEditingController(text: service.language);
      _controllers['username'] = TextEditingController(text: service.username);
      _controllers['password'] = TextEditingController(text: service.password);
    } else if (service is LinkUpOptions) {
      _controllers['apiKey'] = TextEditingController(text: service.apiKey);
    } else if (service is BraveOptions) {
      _controllers['apiKey'] = TextEditingController(text: service.apiKey);
    } else if (service is MetasoOptions) {
      _controllers['apiKey'] = TextEditingController(text: service.apiKey);
    } else if (service is OllamaOptions) {
      _controllers['apiKey'] = TextEditingController(text: service.apiKey);
    } else if (service is JinaOptions) {
      _controllers['apiKey'] = TextEditingController(text: service.apiKey);
    } else if (service is BochaOptions) {
      _controllers['apiKey'] = TextEditingController(text: service.apiKey);
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final searchService = SearchService.getService(widget.service);
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            // Title (match Add sheet style: centered name)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Center(
                child: Text(
                  searchService.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _buildFields(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final updated = _updateService();
                    widget.onSave(updated);
                    Navigator.of(context).pop();
                  }
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  l10n.searchServicesEditDialogSave,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFields() {
    final l10n = AppLocalizations.of(context)!;
    final service = widget.service;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget _buildTextField({
      required String key,
      required String label,
      String? hint,
      bool obscureText = false,
      String? Function(String?)? validator,
    }) {
      _controllers[key] = _controllers[key] ?? TextEditingController();
      return Container(
        decoration: BoxDecoration(
          color: cs.surfaceVariant.withOpacity(isDark ? 0.18 : 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextFormField(
          controller: _controllers[key],
          obscureText: obscureText,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          validator: validator,
        ),
      );
    }

    if (service is BingLocalOptions) {
      return [Text(l10n.searchServicesEditDialogBingLocalNoConfig)];
    } else if (service is DuckDuckGoOptions) {
      return [
        _buildTextField(
          key: 'region',
          label: l10n.searchServicesEditDialogRegionOptional,
          hint: 'us-en',
        ),
      ];
    } else if (service is TavilyOptions ||
        service is ExaOptions ||
        service is ZhipuOptions ||
        service is LinkUpOptions ||
        service is BraveOptions ||
        service is MetasoOptions ||
        service is OllamaOptions ||
        service is JinaOptions ||
        service is BochaOptions) {
      return [
        _buildTextField(
          key: 'apiKey',
          label: 'API Key',
          validator: (value) {
            if (value == null || value.isEmpty) {
              return l10n.searchServicesEditDialogApiKeyRequired;
            }
            return null;
          },
        ),
      ];
    } else if (service is SearXNGOptions) {
      return [
        _buildTextField(
          key: 'url',
          label: l10n.searchServicesEditDialogInstanceUrl,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return l10n.searchServicesEditDialogUrlRequired;
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        _buildTextField(
          key: 'engines',
          label: l10n.searchServicesEditDialogEnginesOptional,
          hint: 'google,duckduckgo',
        ),
        const SizedBox(height: 12),
        _buildTextField(
          key: 'language',
          label: l10n.searchServicesEditDialogLanguageOptional,
          hint: 'en-US',
        ),
        const SizedBox(height: 12),
        _buildTextField(
          key: 'username',
          label: l10n.searchServicesEditDialogUsernameOptional,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          key: 'password',
          label: l10n.searchServicesEditDialogPasswordOptional,
          obscureText: true,
        ),
      ];
    }

    return [];
  }

  SearchServiceOptions _updateService() {
    final service = widget.service;

    if (service is TavilyOptions) {
      return TavilyOptions(
        id: service.id,
        apiKey: _controllers['apiKey']!.text,
      );
    } else if (service is DuckDuckGoOptions) {
      final region = (_controllers['region']?.text ?? service.region).trim();
      return DuckDuckGoOptions(
        id: service.id,
        region: region.isEmpty ? 'us-en' : region,
      );
    } else if (service is ExaOptions) {
      return ExaOptions(id: service.id, apiKey: _controllers['apiKey']!.text);
    } else if (service is ZhipuOptions) {
      return ZhipuOptions(id: service.id, apiKey: _controllers['apiKey']!.text);
    } else if (service is SearXNGOptions) {
      return SearXNGOptions(
        id: service.id,
        url: _controllers['url']!.text,
        engines: _controllers['engines']!.text,
        language: _controllers['language']!.text,
        username: _controllers['username']!.text,
        password: _controllers['password']!.text,
      );
    } else if (service is LinkUpOptions) {
      return LinkUpOptions(
        id: service.id,
        apiKey: _controllers['apiKey']!.text,
      );
    } else if (service is BraveOptions) {
      return BraveOptions(id: service.id, apiKey: _controllers['apiKey']!.text);
    } else if (service is MetasoOptions) {
      return MetasoOptions(
        id: service.id,
        apiKey: _controllers['apiKey']!.text,
      );
    } else if (service is OllamaOptions) {
      return OllamaOptions(
        id: service.id,
        apiKey: _controllers['apiKey']!.text,
      );
    } else if (service is JinaOptions) {
      return JinaOptions(id: service.id, apiKey: _controllers['apiKey']!.text);
    } else if (service is PerplexityOptions) {
      return PerplexityOptions(
        id: service.id,
        apiKey: _controllers['apiKey']!.text,
        country: service.country,
        searchDomainFilter: service.searchDomainFilter,
        maxTokensPerPage: service.maxTokensPerPage,
      );
    } else if (service is BochaOptions) {
      return BochaOptions(
        id: service.id,
        apiKey: _controllers['apiKey']!.text,
        freshness: service.freshness,
        summary: service.summary,
        include: service.include,
        exclude: service.exclude,
      );
    }

    return service;
  }
}

// Service Icon Widget - Uses BrandAssets
class _ServiceIcon extends StatelessWidget {
  const _ServiceIcon({required this.type, required this.name, this.size = 40});

  final String type; // Service type like 'bing_local', 'tavily', etc.
  final String name; // Display name for fallback
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Use type for matching, not the localized name
    final matchName = _getMatchName(type);
    final asset = BrandAssets.assetForName(matchName);
    final bg = isDark ? Colors.white10 : cs.primary.withOpacity(0.1);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: asset != null
          ? _buildAssetIcon(asset, size, isDark)
          : _buildLetterIcon(name, size, cs),
    );
  }

  Widget _buildAssetIcon(String asset, double size, bool isDark) {
    final iconSize = size * 0.62;
    if (asset.endsWith('.svg')) {
      final isColorful = asset.contains('color');
      final ColorFilter? tint = (isDark && !isColorful)
          ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
          : null;
      return SvgPicture.asset(
        asset,
        width: iconSize,
        height: iconSize,
        colorFilter: tint,
      );
    } else {
      return Image.asset(
        asset,
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
      );
    }
  }

  Widget _buildLetterIcon(String name, double size, ColorScheme cs) {
    return Text(
      name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
      style: TextStyle(
        color: cs.primary,
        fontWeight: FontWeight.w700,
        fontSize: size * 0.42,
      ),
    );
  }

  // Map service type to name for BrandAssets matching
  String _getMatchName(String type) {
    switch (type) {
      case 'bing_local':
        return 'bing';
      case 'tavily':
        return 'tavily';
      case 'exa':
        return 'exa';
      case 'zhipu':
        return 'zhipu';
      case 'searxng':
        return 'searxng';
      case 'linkup':
        return 'linkup';
      case 'brave':
        return 'brave';
      case 'metaso':
        return 'metaso';
      case 'jina':
        return 'jina';
      case 'ollama':
        return 'ollama';
      case 'bocha':
        return 'bocha';
      default:
        return type;
    }
  }
}

// --- iOS-style tactile + section helpers (local copy to avoid ripple) ---

class _TactileIconButton extends StatefulWidget {
  const _TactileIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.size = 22,
    this.haptics = true,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;
  final double size;
  final bool haptics;
  @override
  State<_TactileIconButton> createState() => _TactileIconButtonState();
}

class _TactileIconButtonState extends State<_TactileIconButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final base = widget.color;
    final pressColor = base.withOpacity(0.7);
    final icon = Icon(
      widget.icon,
      size: widget.size,
      color: _pressed ? pressColor : base,
      semanticLabel: widget.semanticLabel,
    );
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          if (widget.haptics) Haptics.light();
          widget.onTap();
        },
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                if (widget.haptics) Haptics.light();
                widget.onLongPress!.call();
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: icon,
        ),
      ),
    );
  }
}

class _TactileRow extends StatefulWidget {
  const _TactileRow({
    required this.builder,
    this.onTap,
    this.pressedScale = 1.00,
    this.haptics = true,
  });
  final Widget Function(bool pressed) builder;
  final VoidCallback? onTap;
  final double pressedScale;
  final bool haptics;
  @override
  State<_TactileRow> createState() => _TactileRowState();
}

class _TactileRowState extends State<_TactileRow> {
  bool _pressed = false;
  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
      onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptics &&
                  context.read<SettingsProvider>().hapticsOnListItemTap)
                Haptics.soft();
              widget.onTap!.call();
            },
      child: widget.builder(_pressed),
    );
  }
}

class _AnimatedPressColor extends StatelessWidget {
  const _AnimatedPressColor({
    required this.pressed,
    required this.base,
    required this.builder,
  });
  final bool pressed;
  final Color base;
  final Widget Function(Color color) builder;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final target = pressed
        ? (Color.lerp(base, isDark ? Colors.black : Colors.white, 0.55) ?? base)
        : base;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: target),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, color, _) => builder(color ?? base),
    );
  }
}

Widget _iosSectionCard({required List<Widget> children}) {
  return Builder(
    builder: (context) {
      final theme = Theme.of(context);
      final cs = theme.colorScheme;
      final isDark = theme.brightness == Brightness.dark;
      final Color bg = isDark ? Colors.white10 : Colors.white.withOpacity(0.96);
      return Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cs.outlineVariant.withOpacity(isDark ? 0.08 : 0.06),
            width: 0.6,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: children),
        ),
      );
    },
  );
}

Widget _iosDivider(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Divider(
    height: 6,
    thickness: 0.6,
    indent: 54,
    endIndent: 12,
    color: cs.outlineVariant.withOpacity(0.18),
  );
}

// Sheet helpers (align with settings page)
Widget _sheetOption(
  BuildContext context, {
  required String label,
  required VoidCallback onTap,
  IconData? icon,
  Widget? leading,
  bool bgOnPress = true,
}) {
  final cs = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return _TactileRow(
    pressedScale: 1.00,
    haptics: true,
    onTap: onTap,
    builder: (pressed) {
      final base = cs.onSurface;
      final bgTarget = (bgOnPress && pressed)
          ? (isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.05))
          : Colors.transparent;
      return _AnimatedPressColor(
        pressed: pressed,
        base: base,
        builder: (c) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            color: bgTarget,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 36,
                  child: Center(
                    child:
                        leading ??
                        Icon(icon ?? Lucide.ChevronRight, size: 20, color: c),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label, style: TextStyle(fontSize: 15, color: c)),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _sheetDivider(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Divider(
    height: 1,
    thickness: 0.6,
    indent: 56,
    endIndent: 16,
    color: cs.outlineVariant.withOpacity(0.18),
  );
}

class _SmallTactileIcon extends StatefulWidget {
  const _SmallTactileIcon({
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  @override
  State<_SmallTactileIcon> createState() => _SmallTactileIconState();
}

class _SmallTactileIconState extends State<_SmallTactileIcon> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = widget.enabled
        ? cs.onSurface.withOpacity(_pressed ? 0.6 : 0.9)
        : cs.onSurface.withOpacity(0.3);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: widget.enabled
          ? () => setState(() => _pressed = false)
          : null,
      onTap: widget.enabled
          ? () {
              Haptics.soft();
              widget.onTap();
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Icon(widget.icon, size: 18, color: c),
      ),
    );
  }
}

// (removed: now implemented as instance method on state)
