import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/services/search/search_service.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../utils/brand_assets.dart';
import '../../../core/services/haptics.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../theme/app_font_weights.dart';
import 'search_service_editor_page.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';

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

  Future<void> _addService() async {
    final result = await Navigator.of(context).push<SearchServiceEditorResult>(
      MaterialPageRoute(
        builder: (_) => SearchServiceEditorPage(
          commonOptions: context.read<SettingsProvider>().searchCommonOptions,
        ),
      ),
    );
    if (!mounted || result == null || result.deleted) return;
    final service = result.service;
    if (service == null) return;
    setState(() => _services.add(service));
    _saveChanges();
  }

  Future<void> _editService(int index) async {
    final service = _services[index];
    final result = await Navigator.of(context).push<SearchServiceEditorResult>(
      MaterialPageRoute(
        builder: (_) => SearchServiceEditorPage(
          initialService: service,
          commonOptions: context.read<SettingsProvider>().searchCommonOptions,
          canDelete: _services.length > 1,
        ),
      ),
    );
    if (!mounted || result == null) return;
    final currentIndex = _services.indexWhere((item) => item.id == service.id);
    if (currentIndex < 0) return;
    if (result.deleted) {
      _deleteService(currentIndex);
      return;
    }
    final updated = result.service;
    if (updated == null) return;
    setState(() => _services[currentIndex] = updated);
    _saveChanges();
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

  void _saveChanges() {
    final settings = context.read<SettingsProvider>();
    settings.updateSettings(
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
    final settings = context.read<SettingsProvider>();
    setState(() {
      _testing[id] = true;
    });
    try {
      final svc = SearchService.getService(s);
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
      settings.setSearchConnection(id, false);
    } finally {
      if (mounted) {
        setState(() {
          _testing[id] = false;
        });
      }
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
          SectionCard(
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
            fontWeight: AppFontWeights.semibold,
            color: cs.onSurface.withValues(alpha: 0.8),
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
              color: cs.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(width: 8),
          _SmallTactileIcon(icon: Lucide.Plus, onTap: onPlus, enabled: true),
        ],
      );
    }

    return SectionCard(
      children: [
        _TactileRow(
          onTap: () => context
              .read<SettingsProvider>()
              .setSearchAutoTestOnLaunch(!autoTestOnLaunch),
          pressedScale: 0.995,
          builder: (pressed) {
            final baseColor = cs.onSurface.withValues(alpha: 0.9);
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
            final baseColor = cs.onSurface.withValues(alpha: 0.9);
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
            final baseColor = cs.onSurface.withValues(alpha: 0.9);
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
    // Connection/testing status for capsule
    final l10n = AppLocalizations.of(context)!;
    final testing = _testing[s.id] == true;
    final conn = context.watch<SettingsProvider>().searchConnection[s.id];
    String statusText;
    Color statusBg;
    Color statusFg;
    if (testing) {
      statusText = l10n.searchServicesPageTestingStatus;
      statusBg = cs.primary.withValues(alpha: 0.12);
      statusFg = cs.primary;
    } else if (conn == true) {
      statusText = l10n.searchServicesPageConnectedStatus;
      statusBg = context.appColors.success.withValues(alpha: 0.12);
      statusFg = context.appColors.success;
    } else if (conn == false) {
      statusText = l10n.searchServicesPageFailedStatus;
      statusBg = context.appColors.warning.withValues(alpha: 0.12);
      statusFg = context.appColors.warning;
    } else {
      statusText = l10n.searchServicesPageNotTestedStatus;
      statusBg = cs.onSurface.withValues(alpha: 0.06);
      statusFg = cs.onSurface.withValues(alpha: 0.7);
    }
    return _TactileRow(
      onTap: () {
        // Open the full editor page so in-progress input cannot be dismissed
        // by tapping outside a transient surface.
        _editService(index);
      },
      pressedScale: 1.00,
      haptics: false,
      builder: (pressed) {
        final base = cs.onSurface.withValues(alpha: 0.9);
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
                  key: ValueKey('search-service-row-${s.id}'),
                  crossAxisAlignment: CrossAxisAlignment.center,
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
                          fontWeight: AppFontWeights.semibold,
                        ),
                      ),
                    ),
                    if (s is! BingLocalOptions &&
                        s is! KelivoOptions &&
                        statusText.isNotEmpty) ...[
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
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet(
      context: context,
      backgroundColor: context.overlaySurface,
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
    if (s is DoubaoOptions) return 'doubao';
    if (s is SerperOptions) return 'serper';
    if (s is QueritOptions) return 'querit';
    if (s is GrokOptions) return 'grok';
    if (s is StepFunOptions) return 'stepfun';
    if (s is FirecrawlOptions) return 'firecrawl';
    if (s is TinyFishOptions) return 'tinyfish';
    if (s is KelivoOptions) return 'kelivo';
    return 'search';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Use BrandAssets to get the icon path
    final asset = BrandAssets.assetForName(name);
    final bg = cs.primary.withValues(alpha: isDark ? 0.18 : 0.1);
    if (asset != null) {
      if (asset.endsWith('.svg')) {
        final ColorFilter? tint =
            (isDark && BrandAssets.assetNeedsDarkInvert(asset))
            ? ColorFilter.mode(cs.onSurface, BlendMode.srcIn)
            : null;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: SvgPicture.asset(
            asset,
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
            asset,
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
          fontWeight: AppFontWeights.emphasis,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}

// --- iOS-style tactile + section helpers (local copy to avoid ripple) ---

class _TactileIconButton extends StatefulWidget {
  const _TactileIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.size = 22,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;
  @override
  State<_TactileIconButton> createState() => _TactileIconButtonState();
}

class _TactileIconButtonState extends State<_TactileIconButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final base = widget.color;
    final pressColor = base.withValues(alpha: 0.7);
    final icon = Icon(
      widget.icon,
      size: widget.size,
      color: _pressed ? pressColor : base,
    );
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          Haptics.light();
          widget.onTap();
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
                  context.read<SettingsProvider>().hapticsOnListItemTap) {
                Haptics.soft();
              }
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
    final cs = Theme.of(context).colorScheme;
    final target = pressed
        ? (Color.lerp(base, cs.surface, 0.55) ?? base)
        : base;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: target),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, color, _) => builder(color ?? base),
    );
  }
}


Widget _iosDivider(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Divider(
    height: 6,
    thickness: 0.6,
    indent: 54,
    endIndent: 12,
    color: cs.outlineVariant.withValues(alpha: 0.18),
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
          ? (cs.onSurface.withValues(alpha: isDark ? 0.06 : 0.05))
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
    color: cs.outlineVariant.withValues(alpha: 0.18),
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
        ? cs.onSurface.withValues(alpha: _pressed ? 0.6 : 0.9)
        : cs.onSurface.withValues(alpha: 0.3);
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
