import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../icons/lucide_adapter.dart' as lucide;
import '../../l10n/app_localizations.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/search/search_service.dart';
import '../../utils/brand_assets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uuid/uuid.dart';
import '../../shared/widgets/ios_switch.dart';

class DesktopSearchServicesPane extends StatefulWidget {
  const DesktopSearchServicesPane({super.key});
  @override
  State<DesktopSearchServicesPane> createState() =>
      _DesktopSearchServicesPaneState();
}

class _DesktopSearchServicesPaneState extends State<DesktopSearchServicesPane> {
  final Map<String, bool> _testing = <String, bool>{};

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final services = settings.searchServices;
    final selected = settings.searchServiceSelected.clamp(
      0,
      services.isNotEmpty ? services.length - 1 : 0,
    );
    final common = settings.searchCommonOptions;

    return Container(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 36,
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            l10n.searchServicesPageTitle,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: cs.onSurface.withOpacity(0.9),
                            ),
                          ),
                        ),
                      ),
                      _SmallIconBtn(
                        icon: lucide.Lucide.Plus,
                        onTap: () async {
                          final created = await _showAddServiceDialog(context);
                          if (created != null) {
                            final list = List<SearchServiceOptions>.from(
                              settings.searchServices,
                            )..add(created);
                            await context
                                .read<SettingsProvider>()
                                .setSearchServices(list);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              SliverReorderableList(
                itemCount: services.length,
                itemBuilder: (context, index) {
                  final s = services[index];
                  return KeyedSubtree(
                    key: ValueKey('desktop-search-service-${s.id}'),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ReorderableDragStartListener(
                        index: index,
                        child: _ServiceCard(
                          service: s,
                          selected: index == selected,
                          testing: _testing[s.id] == true,
                          onTap: () async => context
                              .read<SettingsProvider>()
                              .setSearchServiceSelected(index),
                          onEdit: () async {
                            final updated = await _showEditServiceDialog(
                              context,
                              s,
                            );
                            if (updated != null) {
                              final list = List<SearchServiceOptions>.from(
                                context.read<SettingsProvider>().searchServices,
                              );
                              list[index] = updated;
                              await context
                                  .read<SettingsProvider>()
                                  .setSearchServices(list);
                            }
                          },
                          onDelete: () async {
                            final sp = context.read<SettingsProvider>();
                            final list = List<SearchServiceOptions>.from(
                              sp.searchServices,
                            );
                            if (list.length <= 1) return;
                            list.removeAt(index);
                            await sp.setSearchServices(list);
                            var idx = sp.searchServiceSelected;
                            if (idx >= list.length) idx = list.length - 1;
                            await sp.setSearchServiceSelected(idx);
                          },
                          onTest: () => _testConnection(context, s),
                        ),
                      ),
                    ),
                  );
                },
                onReorder: (oldIndex, newIndex) async {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final sp = context.read<SettingsProvider>();
                  final current = List<SearchServiceOptions>.from(
                    sp.searchServices,
                  );
                  if (oldIndex < 0 ||
                      oldIndex >= current.length ||
                      newIndex < 0 ||
                      newIndex >= current.length)
                    return;
                  final moved = current.removeAt(oldIndex);
                  current.insert(newIndex, moved);
                  final selectedId =
                      (sp.searchServices.isNotEmpty &&
                          sp.searchServiceSelected >= 0 &&
                          sp.searchServiceSelected < sp.searchServices.length)
                      ? sp.searchServices[sp.searchServiceSelected].id
                      : null;
                  await sp.setSearchServices(current);
                  if (selectedId != null) {
                    final newSel = current.indexWhere(
                      (e) => e.id == selectedId,
                    );
                    if (newSel >= 0) await sp.setSearchServiceSelected(newSel);
                  }
                },
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: _sectionCard(
                  children: [
                    _ToggleRow(
                      icon: lucide.Lucide.HeartPulse,
                      label: l10n.searchServicesPageAutoTestTitle,
                      value: settings.searchAutoTestOnLaunch,
                      onChanged: (v) => context
                          .read<SettingsProvider>()
                          .setSearchAutoTestOnLaunch(v),
                    ),
                    _divider(context),
                    _StepperRow(
                      icon: lucide.Lucide.ListOrdered,
                      label: l10n.searchServicesPageMaxResults,
                      value: common.resultSize,
                      onMinus: common.resultSize > 1
                          ? () => context
                                .read<SettingsProvider>()
                                .setSearchCommonOptions(
                                  SearchCommonOptions(
                                    resultSize: common.resultSize - 1,
                                    timeout: common.timeout,
                                  ),
                                )
                          : null,
                      onPlus: common.resultSize < 50
                          ? () => context
                                .read<SettingsProvider>()
                                .setSearchCommonOptions(
                                  SearchCommonOptions(
                                    resultSize: common.resultSize + 1,
                                    timeout: common.timeout,
                                  ),
                                )
                          : null,
                    ),
                    _divider(context),
                    _StepperRow(
                      icon: lucide.Lucide.History,
                      label: l10n.searchServicesPageTimeoutSeconds,
                      value: common.timeout ~/ 1000,
                      onMinus: common.timeout > 1000
                          ? () => context
                                .read<SettingsProvider>()
                                .setSearchCommonOptions(
                                  SearchCommonOptions(
                                    resultSize: common.resultSize,
                                    timeout: common.timeout - 1000,
                                  ),
                                )
                          : null,
                      onPlus: common.timeout < 30000
                          ? () => context
                                .read<SettingsProvider>()
                                .setSearchCommonOptions(
                                  SearchCommonOptions(
                                    resultSize: common.resultSize,
                                    timeout: common.timeout + 1000,
                                  ),
                                )
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // list height helper removed after switching to sliver-based list

  Future<void> _testConnection(
    BuildContext context,
    SearchServiceOptions s,
  ) async {
    final settings = context.read<SettingsProvider>();
    setState(() => _testing[s.id] = true);
    try {
      final svc = SearchService.getService(s);
      await svc.search(
        query: 'connectivity test',
        commonOptions: settings.searchCommonOptions,
        serviceOptions: s,
      );
      settings.setSearchConnection(s.id, true);
    } catch (_) {
      settings.setSearchConnection(s.id, false);
    } finally {
      if (mounted) setState(() => _testing[s.id] = false);
    }
  }
}

class _ServiceCard extends StatefulWidget {
  const _ServiceCard({
    required this.service,
    required this.selected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onTest,
    required this.testing,
  });
  final SearchServiceOptions service;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTest;
  final bool testing;
  @override
  State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = SearchService.getService(widget.service).name;
    final baseBg = isDark ? Colors.white10 : Colors.white.withOpacity(0.96);
    final borderColor = _hover || widget.selected
        ? cs.primary.withOpacity(isDark ? 0.35 : 0.45)
        : cs.outlineVariant.withOpacity(isDark ? 0.12 : 0.08);

    // Connection/testing status capsule
    final l10n = AppLocalizations.of(context)!;
    final conn = context
        .watch<SettingsProvider>()
        .searchConnection[widget.service.id];
    String statusText;
    Color statusBg;
    Color statusFg;
    if (widget.testing) {
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

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: baseBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          padding: const EdgeInsets.all(14),
          constraints: const BoxConstraints(minHeight: 64),
          child: Row(
            children: [
              _BrandBadge.forService(widget.service, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (widget.service is! BingLocalOptions) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 11,
                      color: statusFg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Tooltip(
                message: l10n.searchServicesPageEditServiceTooltip,
                child: _SmallIconBtn(
                  icon: lucide.Lucide.Settings2,
                  onTap: widget.onEdit,
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: l10n.searchServicesPageTestConnectionTooltip,
                child: _SmallIconBtn(
                  icon: lucide.Lucide.HeartPulse,
                  onTap: widget.onTest,
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: l10n.searchServicesPageDeleteServiceTooltip,
                child: _SmallIconBtn(
                  icon: lucide.Lucide.Trash2,
                  onTap: widget.onDelete,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final labelColor = cs.onSurface.withOpacity(0.9);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Icon(icon, size: 18, color: labelColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 15, color: labelColor),
              ),
            ),
            IosSwitch(
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperRow extends StatefulWidget {
  const _StepperRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onMinus,
    this.onPlus,
  });
  final IconData icon;
  final String label;
  final int value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  @override
  State<_StepperRow> createState() => _StepperRowState();
}

class _StepperRowState extends State<_StepperRow> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Icon(
              widget.icon,
              size: 18,
              color: cs.onSurface.withOpacity(0.9),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 15,
                color: cs.onSurface.withOpacity(0.9),
              ),
            ),
          ),
          _StepperButton(
            icon: lucide.Lucide.Minus,
            enabled: widget.onMinus != null,
            onTap: widget.onMinus ?? () {},
          ),
          const SizedBox(width: 8),
          Container(
            width: 42,
            alignment: Alignment.center,
            child: Text(
              '${widget.value}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: cs.onSurface.withOpacity(0.9),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _StepperButton(
            icon: lucide.Lucide.Plus,
            enabled: widget.onPlus != null,
            onTap: widget.onPlus ?? () {},
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatefulWidget {
  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  @override
  State<_StepperButton> createState() => _StepperButtonState();
}

class _StepperButtonState extends State<_StepperButton> {
  bool _hover = false;
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = Colors.transparent;
    final bg = _hover
        ? (isDark
              ? Colors.white.withOpacity(0.10)
              : Colors.black.withOpacity(0.07))
        : base;
    final c = widget.enabled ? cs.onSurface : cs.onSurface.withOpacity(0.4);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: widget.enabled
            ? (_) => setState(() => _pressed = true)
            : null,
        onTapUp: widget.enabled
            ? (_) => setState(() => _pressed = false)
            : null,
        onTapCancel: widget.enabled
            ? () => setState(() => _pressed = false)
            : null,
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOutCubic,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(widget.icon, size: 16, color: c),
          ),
        ),
      ),
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
    return 'search';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asset = BrandAssets.assetForName(name);
    final bg = isDark ? Colors.white10 : cs.primary.withOpacity(0.1);
    if (asset != null) {
      if (asset.endsWith('.svg')) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: SvgPicture.asset(
            asset,
            width: size * 0.62,
            height: size * 0.62,
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
        name.substring(0, 1).toUpperCase(),
        style: TextStyle(
          color: cs.primary,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}

class _SmallIconBtn extends StatefulWidget {
  const _SmallIconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  State<_SmallIconBtn> createState() => _SmallIconBtnState();
}

class _SmallIconBtnState extends State<_SmallIconBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _hover
        ? (isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.05))
        : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(widget.icon, size: 18, color: cs.onSurface),
        ),
      ),
    );
  }
}

Widget _sectionCard({required List<Widget> children}) {
  return Builder(
    builder: (context) {
      final cs = Theme.of(context).colorScheme;
      final isDark = Theme.of(context).brightness == Brightness.dark;
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
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: children),
        ),
      );
    },
  );
}

Widget _divider(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Divider(
    height: 6,
    thickness: 0.6,
    indent: 12,
    endIndent: 12,
    color: cs.outlineVariant.withOpacity(0.18),
  );
}

// ===== Dialogs =====

Future<SearchServiceOptions?> _showAddServiceDialog(
  BuildContext context,
) async {
  return showDialog<SearchServiceOptions>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => const _AddServiceDialog(),
  );
}

Future<SearchServiceOptions?> _showEditServiceDialog(
  BuildContext context,
  SearchServiceOptions s,
) async {
  return showDialog<SearchServiceOptions>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _EditServiceDialog(service: s),
  );
}

class _AddServiceDialog extends StatefulWidget {
  const _AddServiceDialog();
  @override
  State<_AddServiceDialog> createState() => _AddServiceDialogState();
}

class _AddServiceDialogState extends State<_AddServiceDialog> {
  String _selectedType = 'bing_local';
  final Map<String, TextEditingController> _controllers = {
    'apiKey': TextEditingController(),
    'url': TextEditingController(),
    'engines': TextEditingController(),
    'language': TextEditingController(),
    'username': TextEditingController(),
    'password': TextEditingController(),
    'region': TextEditingController(text: 'us-en'),
  };

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Dialog(
      backgroundColor: cs.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 58),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.searchServicesAddDialogTitle,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _SmallIconBtn(
                        icon: lucide.Lucide.X,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: _ServiceTypeDropdown(
                      selectedType: _selectedType,
                      onChanged: (t) => setState(() => _selectedType = t),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._buildFields(),
                ],
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: _DeskIosButton(
                label: l10n.searchServicesAddDialogAdd,
                filled: true,
                dense: true,
                onTap: () {
                  final created = _createService();
                  Navigator.of(context).pop(created);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFields() {
    final l10n = AppLocalizations.of(context)!;
    InputDecoration deco(String hint) =>
        _deskInputDecoration(context).copyWith(hintText: hint);
    switch (_selectedType) {
      case 'duckduckgo':
        return [
          TextField(
            controller: _controllers['region'],
            decoration: deco(l10n.searchServicesAddDialogRegionOptional),
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
          TextField(
            controller: _controllers['apiKey'],
            decoration: deco('API Key'),
          ),
        ];
      case 'searxng':
        return [
          TextField(
            controller: _controllers['url'],
            decoration: deco(l10n.searchServicesAddDialogInstanceUrl),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controllers['engines'],
            decoration: deco(l10n.searchServicesAddDialogEnginesOptional),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controllers['language'],
            decoration: deco('en-US'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controllers['username'],
            decoration: deco(l10n.searchServicesAddDialogUsernameOptional),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controllers['password'],
            decoration: deco(l10n.searchServicesAddDialogPasswordOptional),
            obscureText: true,
          ),
        ];
      case 'bing_local':
      default:
        return [];
    }
  }

  SearchServiceOptions _createService() {
    final id = const Uuid().v4().substring(0, 8);
    switch (_selectedType) {
      case 'tavily':
        return TavilyOptions(id: id, apiKey: _controllers['apiKey']!.text);
      case 'duckduckgo':
        final region = (_controllers['region']?.text ?? 'us-en').trim();
        return DuckDuckGoOptions(
          id: id,
          region: region.isEmpty ? 'us-en' : region,
        );
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
      case 'bing_local':
      default:
        return BingLocalOptions(id: id);
    }
  }
}

class _EditServiceDialog extends StatefulWidget {
  const _EditServiceDialog({required this.service});
  final SearchServiceOptions service;
  @override
  State<_EditServiceDialog> createState() => _EditServiceDialogState();
}

class _EditServiceDialogState extends State<_EditServiceDialog> {
  final Map<String, TextEditingController> _controllers = {};
  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    final s = widget.service;
    if (s is TavilyOptions) {
      _controllers['apiKey'] = TextEditingController(text: s.apiKey);
    } else if (s is DuckDuckGoOptions) {
      _controllers['region'] = TextEditingController(text: s.region);
    } else if (s is ExaOptions) {
      _controllers['apiKey'] = TextEditingController(text: s.apiKey);
    } else if (s is ZhipuOptions) {
      _controllers['apiKey'] = TextEditingController(text: s.apiKey);
    } else if (s is SearXNGOptions) {
      _controllers['url'] = TextEditingController(text: s.url);
      _controllers['engines'] = TextEditingController(text: s.engines);
      _controllers['language'] = TextEditingController(text: s.language);
      _controllers['username'] = TextEditingController(text: s.username);
      _controllers['password'] = TextEditingController(text: s.password);
    } else if (s is LinkUpOptions) {
      _controllers['apiKey'] = TextEditingController(text: s.apiKey);
    } else if (s is BraveOptions) {
      _controllers['apiKey'] = TextEditingController(text: s.apiKey);
    } else if (s is MetasoOptions) {
      _controllers['apiKey'] = TextEditingController(text: s.apiKey);
    } else if (s is OllamaOptions) {
      _controllers['apiKey'] = TextEditingController(text: s.apiKey);
    } else if (s is JinaOptions) {
      _controllers['apiKey'] = TextEditingController(text: s.apiKey);
    } else if (s is PerplexityOptions) {
      _controllers['apiKey'] = TextEditingController(text: s.apiKey);
    } else if (s is BochaOptions) {
      _controllers['apiKey'] = TextEditingController(text: s.apiKey);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final name = SearchService.getService(widget.service).name;
    return Dialog(
      backgroundColor: cs.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 58),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _SmallIconBtn(
                        icon: lucide.Lucide.X,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._buildFields(),
                ],
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: _DeskIosButton(
                label: l10n.searchServicesEditDialogSave,
                filled: true,
                dense: true,
                onTap: () {
                  final updated = _updateService();
                  Navigator.of(context).pop(updated);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFields() {
    final l10n = AppLocalizations.of(context)!;
    final s = widget.service;
    InputDecoration deco(String hint) =>
        _deskInputDecoration(context).copyWith(hintText: hint);
    if (s is TavilyOptions ||
        s is ExaOptions ||
        s is ZhipuOptions ||
        s is LinkUpOptions ||
        s is BraveOptions ||
        s is MetasoOptions ||
        s is JinaOptions ||
        s is OllamaOptions ||
        s is PerplexityOptions ||
        s is BochaOptions) {
      return [
        TextField(
          controller: _controllers['apiKey'],
          decoration: deco('API Key'),
        ),
      ];
    } else if (s is DuckDuckGoOptions) {
      return [
        TextField(
          controller: _controllers['region'],
          decoration: deco(l10n.searchServicesEditDialogRegionOptional),
        ),
      ];
    } else if (s is SearXNGOptions) {
      return [
        TextField(
          controller: _controllers['url'],
          decoration: deco(l10n.searchServicesEditDialogInstanceUrl),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controllers['engines'],
          decoration: deco(l10n.searchServicesAddDialogEnginesOptional),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controllers['language'],
          decoration: deco('en-US'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controllers['username'],
          decoration: deco(l10n.searchServicesAddDialogUsernameOptional),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controllers['password'],
          decoration: deco(l10n.searchServicesAddDialogPasswordOptional),
          obscureText: true,
        ),
      ];
    }
    return [];
  }

  SearchServiceOptions _updateService() {
    final s = widget.service;
    if (s is TavilyOptions)
      return TavilyOptions(id: s.id, apiKey: _controllers['apiKey']!.text);
    if (s is DuckDuckGoOptions) {
      final region = (_controllers['region']?.text ?? s.region).trim();
      return DuckDuckGoOptions(
        id: s.id,
        region: region.isEmpty ? 'us-en' : region,
      );
    }
    if (s is ExaOptions)
      return ExaOptions(id: s.id, apiKey: _controllers['apiKey']!.text);
    if (s is ZhipuOptions)
      return ZhipuOptions(id: s.id, apiKey: _controllers['apiKey']!.text);
    if (s is SearXNGOptions)
      return SearXNGOptions(
        id: s.id,
        url: _controllers['url']!.text,
        engines: _controllers['engines']!.text,
        language: _controllers['language']!.text,
        username: _controllers['username']!.text,
        password: _controllers['password']!.text,
      );
    if (s is LinkUpOptions)
      return LinkUpOptions(id: s.id, apiKey: _controllers['apiKey']!.text);
    if (s is BraveOptions)
      return BraveOptions(id: s.id, apiKey: _controllers['apiKey']!.text);
    if (s is MetasoOptions)
      return MetasoOptions(id: s.id, apiKey: _controllers['apiKey']!.text);
    if (s is JinaOptions)
      return JinaOptions(id: s.id, apiKey: _controllers['apiKey']!.text);
    if (s is OllamaOptions)
      return OllamaOptions(id: s.id, apiKey: _controllers['apiKey']!.text);
    if (s is PerplexityOptions)
      return PerplexityOptions(id: s.id, apiKey: _controllers['apiKey']!.text);
    if (s is BochaOptions)
      return BochaOptions(id: s.id, apiKey: _controllers['apiKey']!.text);
    return s;
  }
}

class _ServiceTypeChips extends StatefulWidget {
  const _ServiceTypeChips({
    required this.selectedType,
    required this.onChanged,
  });
  final String selectedType;
  final ValueChanged<String> onChanged;
  @override
  State<_ServiceTypeChips> createState() => _ServiceTypeChipsState();
}

class _ServiceTypeChipsState extends State<_ServiceTypeChips> {
  static const List<({String type, String name, String brand})> _types = [
    (type: 'bing_local', name: 'Bing (Local)', brand: 'bing'),
    (type: 'duckduckgo', name: 'DuckDuckGo', brand: 'duckduckgo'),
    (type: 'tavily', name: 'Tavily', brand: 'tavily'),
    (type: 'exa', name: 'Exa', brand: 'exa'),
    (type: 'zhipu', name: 'Zhipu', brand: 'zhipu'),
    (type: 'searxng', name: 'SearXNG', brand: 'searxng'),
    (type: 'linkup', name: 'LinkUp', brand: 'linkup'),
    (type: 'brave', name: 'Brave', brand: 'brave'),
    (type: 'metaso', name: 'Metaso', brand: 'metaso'),
    (type: 'jina', name: 'Jina', brand: 'jina'),
    (type: 'ollama', name: 'Ollama', brand: 'ollama'),
    (type: 'perplexity', name: 'Perplexity', brand: 'perplexity'),
    (type: 'bocha', name: 'Bocha', brand: 'bocha'),
  ];
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: _types.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final it = _types[i];
        final selected = it.type == widget.selectedType;
        final bg = selected
            ? cs.primary.withOpacity(isDark ? 0.18 : 0.12)
            : (isDark ? Colors.white12 : const Color(0xFFF7F7F9));
        final fg = selected ? cs.primary : cs.onSurface.withOpacity(0.85);
        return GestureDetector(
          onTap: () => widget.onChanged(it.type),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
              border: selected
                  ? Border.all(color: cs.primary, width: 1.0)
                  : null,
            ),
            child: Row(
              children: [
                _BrandBadge(name: it.brand, size: 18),
                const SizedBox(width: 6),
                Text(
                  it.name,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Custom dropdown for service type selection (desktop style)
class _ServiceTypeDropdown extends StatefulWidget {
  const _ServiceTypeDropdown({
    required this.selectedType,
    required this.onChanged,
  });
  final String selectedType;
  final ValueChanged<String> onChanged;
  @override
  State<_ServiceTypeDropdown> createState() => _ServiceTypeDropdownState();
}

class _ServiceTypeDropdownState extends State<_ServiceTypeDropdown> {
  bool _hover = false;
  bool _open = false;
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;
  final GlobalKey _key = GlobalKey();
  static const List<({String type, String name, String brand})> _types =
      _ServiceTypeChipsState._types;

  void _toggle() {
    _open ? _close() : _openOverlay();
  }

  void _openOverlay() {
    if (_entry != null) return;
    final rb = _key.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return;
    final triggerW = rb.size.width;
    const maxW = 320.0;
    _entry = OverlayEntry(
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final width = triggerW.clamp(200.0, maxW);
        final dx = (triggerW - width) / 2;
        final maxH = MediaQuery.of(ctx).size.height * 0.4;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _close,
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              offset: Offset(dx, rb.size.height + 6),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: width.toDouble(),
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).brightness == Brightness.dark
                            ? const Color(0xFF1C1C1E)
                            : Colors.white,
                        border: Border.all(
                          color: cs.outlineVariant.withOpacity(0.12),
                          width: 0.5,
                        ),
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: maxH,
                          minWidth: width,
                          maxWidth: width,
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (int i = 0; i < _types.length; i++) ...[
                                _DropdownItem(
                                  leading: _BrandBadge(
                                    name: _types[i].brand,
                                    size: 18,
                                  ),
                                  label: _types[i].name,
                                  selected:
                                      widget.selectedType == _types[i].type,
                                  onTap: () {
                                    widget.onChanged(_types[i].type);
                                    _close();
                                  },
                                ),
                                if (i != _types.length - 1)
                                  const SizedBox(height: 6),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context)?.insert(_entry!);
    setState(() => _open = true);
  }

  void _close() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() => _open = false);
  }

  String get _currentLabel => _types
      .firstWhere(
        (e) => e.type == widget.selectedType,
        orElse: () => _types.first,
      )
      .name;
  String get _currentBrand => _types
      .firstWhere(
        (e) => e.type == widget.selectedType,
        orElse: () => _types.first,
      )
      .brand;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _hover || _open
        ? (isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.04))
        : Colors.transparent;
    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        key: _key,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _toggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: cs.outlineVariant.withOpacity(0.12),
                width: 0.6,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _BrandBadge(name: _currentBrand, size: 18),
                const SizedBox(width: 6),
                Text(
                  _currentLabel,
                  style: TextStyle(
                    fontSize: 14.5,
                    color: cs.onSurface.withOpacity(0.9),
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: (_open ? 3.1415926 : 0.0) / (2 * 3.1415926),
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    lucide.Lucide.ChevronDown,
                    size: 16,
                    color: cs.onSurface.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DropdownItem extends StatefulWidget {
  const _DropdownItem({
    required this.leading,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final Widget leading;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  State<_DropdownItem> createState() => _DropdownItemState();
}

class _DropdownItemState extends State<_DropdownItem> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = widget.selected
        ? cs.primary.withOpacity(0.08)
        : (_hover
              ? (isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.04))
              : Colors.transparent);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 24,
                child: Center(child: widget.leading),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurface.withOpacity(0.9),
                  ),
                ),
              ),
              if (widget.selected)
                Icon(lucide.Lucide.Check, size: 16, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeskIosButton extends StatefulWidget {
  const _DeskIosButton({
    required this.label,
    required this.filled,
    required this.dense,
    required this.onTap,
  });
  final String label;
  final bool filled;
  final bool dense;
  final VoidCallback onTap;
  @override
  State<_DeskIosButton> createState() => _DeskIosButtonState();
}

class _DeskIosButtonState extends State<_DeskIosButton> {
  bool _hover = false;
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = widget.filled
        ? cs.primary
        : cs.onSurface.withOpacity(0.8);
    final textColor = widget.filled ? Colors.white : baseColor;
    final bg = widget.filled
        ? (_hover ? cs.primary.withOpacity(0.92) : cs.primary)
        : (_hover
              ? (isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.05))
              : Colors.transparent);
    final borderColor = widget.filled
        ? Colors.transparent
        : cs.outlineVariant.withOpacity(isDark ? 0.22 : 0.18);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: widget.dense ? 8 : 12,
              horizontal: 12,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: widget.dense ? 13 : 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _deskInputDecoration(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final cs = Theme.of(context).colorScheme;
  return InputDecoration(
    isDense: false,
    filled: true,
    fillColor: isDark ? Colors.white10 : const Color(0xFFF7F7F9),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: cs.outlineVariant.withOpacity(0.2),
        width: 0.8,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: cs.outlineVariant.withOpacity(0.2),
        width: 0.8,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: cs.primary.withOpacity(0.45), width: 1.0),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}
