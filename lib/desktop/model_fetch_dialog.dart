import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/providers/settings_provider.dart';
import '../core/providers/model_provider.dart';
import '../l10n/app_localizations.dart';
import '../icons/lucide_adapter.dart' as lucide;
import '../utils/brand_assets.dart';
import 'package:characters/characters.dart';
import '../utils/model_grouping.dart';
import '../shared/widgets/model_tag_wrap.dart';

Future<void> showModelFetchDialog(
  BuildContext context, {
  required String providerKey,
  required String providerDisplayName,
}) async {
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'model-fetch-dialog',
    barrierColor: Colors.black.withOpacity(0.25),
    pageBuilder: (ctx, _, __) {
      return _ModelFetchDialogBody(
        providerKey: providerKey,
        providerDisplayName: providerDisplayName,
      );
    },
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _ModelFetchDialogBody extends StatefulWidget {
  const _ModelFetchDialogBody({required this.providerKey, required this.providerDisplayName});
  final String providerKey;
  final String providerDisplayName;

  @override
  State<_ModelFetchDialogBody> createState() => _ModelFetchDialogBodyState();
}

class _ModelFetchDialogBodyState extends State<_ModelFetchDialogBody> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _loading = true;
  String _error = '';
  List<ModelInfo> _items = const [];
  final Map<String, bool> _collapsed = <String, bool>{};

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = context.read<SettingsProvider>();
    final cfg = settings.getProviderConfig(widget.providerKey, defaultName: widget.providerDisplayName);
    final bool isDefaultSilicon = widget.providerKey.toLowerCase() == 'siliconflow';
    final bool hasUserKey = (cfg.multiKeyEnabled == true && (cfg.apiKeys?.isNotEmpty == true)) || cfg.apiKey.trim().isNotEmpty;
    final bool restrictToFree = isDefaultSilicon && !hasUserKey;
    try {
      if (restrictToFree) {
        final list = <ModelInfo>[
          ModelRegistry.infer(ModelInfo(id: 'THUDM/GLM-4-9B-0414', displayName: 'THUDM/GLM-4-9B-0414')),
          ModelRegistry.infer(ModelInfo(id: 'Qwen/Qwen3-8B', displayName: 'Qwen/Qwen3-8B')),
        ];
        setState(() {
          _items = list;
          _loading = false;
          _error = '';
        });
      } else {
        final list = await ProviderManager.listModels(cfg);
        if (!mounted) return;
        setState(() {
          _items = list;
          _loading = false;
          _error = '';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items = const [];
        _loading = false;
        _error = '$e';
      });
    }
  }

  String _groupFor(BuildContext context, ModelInfo m) {
    final l10n = AppLocalizations.of(context)!;
    return ModelGrouping.groupFor(
      m,
      embeddingsLabel: l10n.providerDetailPageEmbeddingsGroupTitle,
      otherLabel: l10n.providerDetailPageOtherModelsGroupTitle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final settingsWatch = context.watch<SettingsProvider>();

    // Compute header filtered list and selection state for toggle icon
    final headerQuery = _searchCtrl.text.trim().toLowerCase();
    final headerFiltered = <ModelInfo>[
      for (final m in _items)
        if (headerQuery.isEmpty || m.id.toLowerCase().contains(headerQuery) || m.displayName.toLowerCase().contains(headerQuery)) m,
    ];
    final headerSelectedSet = settingsWatch
        .getProviderConfig(widget.providerKey, defaultName: widget.providerDisplayName)
        .models
        .toSet();
    final bool allHeaderFilteredSelected = headerFiltered.isNotEmpty && headerFiltered.every((m) => headerSelectedSet.contains(m.id));

    final dialog = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 520, maxWidth: 860, maxHeight: 720),
        child: Material(
          color: cs.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? Colors.white.withOpacity(0.08) : cs.outlineVariant.withOpacity(0.25),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title bar with inset divider
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: cs.surface,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${widget.providerDisplayName} ${l10n.providerDetailPageModelsTab}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.mcpPageClose,
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: Icon(lucide.Lucide.X, size: 20, color: cs.onSurface.withOpacity(0.9)),
                        ),
                      ],
                    ),
                  ),
                ),
                // Body area uses desktop surface background
                Expanded(
                  child: Container(
                    color: cs.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: l10n.providerDetailPageFilterHint,
                              isDense: true,
                              filled: true,
                              fillColor: isDark ? Colors.white10 : const Color(0xFFF2F3F5),
                              prefixIcon: Icon(lucide.Lucide.Search, size: 18, color: cs.onSurface.withOpacity(0.7)),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Tooltip(
                                    message: allHeaderFilteredSelected ? l10n.mcpAssistantSheetClearAll : l10n.mcpAssistantSheetSelectAll,
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 180),
                                      switchInCurve: Curves.easeOutCubic,
                                      switchOutCurve: Curves.easeInCubic,
                                      transitionBuilder: (child, anim) => FadeTransition(
                                        opacity: anim,
                                        child: ScaleTransition(scale: Tween<double>(begin: 0.92, end: 1).animate(anim), child: child),
                                      ),
                                      child: IconButton(
                                        key: ValueKey(allHeaderFilteredSelected ? 'deselect-all' : 'select-all'),
                                        icon: Icon(
                                          allHeaderFilteredSelected ? lucide.Lucide.Square : lucide.Lucide.CheckSquare,
                                          size: 18,
                                          color: cs.onSurface.withOpacity(0.7),
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
                                        onPressed: () async {
                                          final settings = context.read<SettingsProvider>();
                                          final cfg = settings.getProviderConfig(widget.providerKey, defaultName: widget.providerDisplayName);
                                          final q = _searchCtrl.text.trim().toLowerCase();
                                          final filtered = <ModelInfo>[
                                            for (final m in _items)
                                              if (q.isEmpty || m.id.toLowerCase().contains(q) || m.displayName.toLowerCase().contains(q)) m,
                                          ];
                                          if (filtered.isEmpty) return;
                                          if (allHeaderFilteredSelected) {
                                            // Deselect all filtered
                                            final toRemove = filtered.map((m) => m.id).toSet();
                                            final next = cfg.models.where((id) => !toRemove.contains(id)).toList();
                                            await settings.setProviderConfig(widget.providerKey, cfg.copyWith(models: next));
                                          } else {
                                            // Select all filtered
                                            final setIds = cfg.models.toSet();
                                            setIds.addAll(filtered.map((m) => m.id));
                                            await settings.setProviderConfig(widget.providerKey, cfg.copyWith(models: setIds.toList()));
                                          }
                                          if (mounted) setState(() {});
                                        },
                                      ),
                                    ),
                                  ),
                                  Tooltip(
                                    message: l10n.modelFetchInvertTooltip,
                                    child: IconButton(
                                      icon: Icon(lucide.Lucide.Repeat, size: 18, color: cs.onSurface.withOpacity(0.7)),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
                                      onPressed: () async {
                                        final settings = context.read<SettingsProvider>();
                                        final cfg = settings.getProviderConfig(widget.providerKey, defaultName: widget.providerDisplayName);
                                        final q = _searchCtrl.text.trim().toLowerCase();
                                        final filtered = <ModelInfo>[
                                          for (final m in _items)
                                            if (q.isEmpty || m.id.toLowerCase().contains(q) || m.displayName.toLowerCase().contains(q)) m,
                                        ];
                                        if (filtered.isEmpty) return;
                                        final current = cfg.models.toSet();
                                        for (final m in filtered) {
                                          if (current.contains(m.id)) {
                                            current.remove(m.id);
                                          } else {
                                            current.add(m.id);
                                          }
                                        }
                                        await settings.setProviderConfig(widget.providerKey, cfg.copyWith(models: current.toList()));
                                        if (mounted) setState(() {});
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.transparent)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.transparent)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary.withOpacity(0.4))),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                          ),
                        ),
                        Expanded(
                          child: _loading
                              ? const Center(child: CircularProgressIndicator())
                              : _error.isNotEmpty
                                  ? Center(child: Text(_error, style: TextStyle(color: cs.error)))
                                  : _buildList(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Material(type: MaterialType.transparency, child: dialog);
  }

  Widget _buildList(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final selected = settings.getProviderConfig(widget.providerKey, defaultName: widget.providerDisplayName).models.toSet();

    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = <ModelInfo>[
      for (final m in _items)
        if (q.isEmpty || m.id.toLowerCase().contains(q) || m.displayName.toLowerCase().contains(q)) m,
    ];

    final Map<String, List<ModelInfo>> grouped = {};
    for (final m in filtered) {
      final g = _groupFor(context, m);
      (grouped[g] ??= []).add(m);
    }
    final groupKeys = grouped.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    if (groupKeys.isEmpty) {
      return const Center(child: Text(''));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      children: [
        for (final g in groupKeys) ...[
          // Group header
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
            child: _TactileRow(
              onTap: () => setState(() => _collapsed[g] = !(_collapsed[g] == true)),
              builder: (_) {
                final allAdded = grouped[g]!.every((m) => selected.contains(m.id));
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF2F3F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Center(
                            child: AnimatedRotation(
                              turns: (_collapsed[g] == true) ? 0.0 : 0.25,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              child: Icon(lucide.Lucide.ChevronRight, size: 18, color: cs.onSurface.withOpacity(0.7)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            g,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: allAdded ? AppLocalizations.of(context)!.providerDetailPageRemoveGroupTooltip : AppLocalizations.of(context)!.providerDetailPageAddGroupTooltip,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
                          icon: Icon(allAdded ? lucide.Lucide.Minus : lucide.Lucide.Plus, size: 18, color: cs.onSurface.withOpacity(0.75)),
                          onPressed: () async {
                            final old = context.read<SettingsProvider>().getProviderConfig(widget.providerKey, defaultName: widget.providerDisplayName);
                            if (allAdded) {
                              final toRemove = grouped[g]!.map((m) => m.id).toSet();
                              final list = old.models.where((id) => !toRemove.contains(id)).toList();
                              await context.read<SettingsProvider>().setProviderConfig(widget.providerKey, old.copyWith(models: list));
                            } else {
                              final toAdd = grouped[g]!.where((m) => !selected.contains(m.id)).map((m) => m.id).toList();
                              if (toAdd.isNotEmpty) {
                                final set = old.models.toSet()..addAll(toAdd);
                                await context.read<SettingsProvider>().setProviderConfig(widget.providerKey, old.copyWith(models: set.toList()));
                              }
                            }
                            if (mounted) setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: (_collapsed[g] == true)
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      for (final m in grouped[g]!) _modelRow(context, m),
                    ],
                  ),
          ),
        ],
      ],
    );
  }

  Widget _modelRow(BuildContext context, ModelInfo m) {
    final cs = Theme.of(context).colorScheme;
    final settings = context.read<SettingsProvider>();
    final selected = settings.getProviderConfig(widget.providerKey, defaultName: widget.providerDisplayName).models.toSet();
    final added = selected.contains(m.id);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: _TactileRow(
        builder: (_) => Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                SizedBox(width: 28, child: Center(child: _BrandAvatar(name: m.id, size: 24))),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    m.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5),
                  ),
                ),
                const SizedBox(width: 8),
                ModelCapsulesRow(model: m),
                const SizedBox(width: 8),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
                  onPressed: () async {
                    final old = context.read<SettingsProvider>().getProviderConfig(widget.providerKey, defaultName: widget.providerDisplayName);
                    final list = old.models.toList();
                    if (added) {
                      list.removeWhere((e) => e == m.id);
                    } else {
                      list.add(m.id);
                    }
                    await context.read<SettingsProvider>().setProviderConfig(widget.providerKey, old.copyWith(models: list));
                    if (mounted) setState(() {});
                  },
                  icon: Icon(added ? lucide.Lucide.Minus : lucide.Lucide.Plus, size: 18, color: cs.onSurface.withOpacity(0.75)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TactileRow extends StatefulWidget {
  const _TactileRow({required this.builder, this.onTap});
  final Widget Function(bool pressed) builder;
  final VoidCallback? onTap;
  @override
  State<_TactileRow> createState() => _TactileRowState();
}

class _TactileRowState extends State<_TactileRow> {
  bool _pressed = false;
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlay = () {
      if (_pressed) return isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);
      if (_hovered) return isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03);
      return Colors.transparent;
    }();
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 120),
          scale: _pressed ? 0.98 : 1,
          child: Stack(
            children: [
              widget.builder(_pressed),
              Positioned.fill(child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(color: overlay, borderRadius: BorderRadius.circular(12))))),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandAvatar extends StatelessWidget {
  const _BrandAvatar({required this.name, this.size = 20});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asset = BrandAssets.assetForName(name);
    Widget inner;
    if (asset != null) {
      if (asset.endsWith('.svg')) {
        final isColorful = asset.contains('color');
        final ColorFilter? tint = (isDark && !isColorful)
            ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
            : null;
        inner = SvgPicture.asset(
          asset,
          width: size * 0.62,
          height: size * 0.62,
          colorFilter: tint,
        );
      } else {
        inner = Image.asset(asset, width: size * 0.62, height: size * 0.62, fit: BoxFit.contain);
      }
    } else {
      inner = Text(name.isNotEmpty ? name.characters.first.toUpperCase() : '?', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, fontSize: size * 0.42));
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : cs.primary.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: inner,
    );
  }
}
