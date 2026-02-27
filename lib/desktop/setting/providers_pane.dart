part of '../desktop_settings_page.dart';

// ===== Providers (Desktop right content) =====

class _DesktopProvidersBody extends StatefulWidget {
  const _DesktopProvidersBody({super.key, this.initialSelectedKey});
  final String? initialSelectedKey;
  @override
  State<_DesktopProvidersBody> createState() => _DesktopProvidersBodyState();
}

class _DesktopProvidersBodyState extends State<_DesktopProvidersBody> {
  String? _selectedKey;
  final GlobalKey<_DesktopProviderDetailPaneState> _detailKey =
      GlobalKey<_DesktopProviderDetailPaneState>();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _normalizeSearchQuery(String value) => value.trim().toLowerCase();

  bool _matchesQuery(String value, String normalizedQuery) {
    if (normalizedQuery.isEmpty) return true;
    return value.toLowerCase().contains(normalizedQuery);
  }

  bool _providerMatches({
    required ({String name, String key}) item,
    required SettingsProvider settings,
    required String normalizedQuery,
  }) {
    if (normalizedQuery.isEmpty) return true;
    final cfg = settings.getProviderConfig(item.key, defaultName: item.name);
    final displayName = cfg.name.isNotEmpty ? cfg.name : item.name;
    return _matchesQuery(displayName, normalizedQuery);
  }

  List<({String name, String key})> _applySearchToProviders({
    required List<({String name, String key})> items,
    required SettingsProvider settings,
    required String normalizedQuery,
  }) {
    if (normalizedQuery.isEmpty) return items;
    return [
      for (final item in items)
        if (_providerMatches(
          item: item,
          settings: settings,
          normalizedQuery: normalizedQuery,
        ))
          item,
    ];
  }

  List<_DesktopProviderGroupingRowVM> _buildProviderGroupingRows({
    required AppLocalizations l10n,
    required SettingsProvider settings,
    required List<({String name, String key})> items,
    String normalizedQuery = '',
  }) {
    final ungroupedKey = SettingsProvider.providerUngroupedGroupKey;
    final groups = settings.providerGroups;
    final groupById = {for (final g in groups) g.id: g};
    final providersByGroupKey = <String, List<({String name, String key})>>{
      for (final g in groups) g.id: <({String name, String key})>[],
      ungroupedKey: <({String name, String key})>[],
    };

    for (final p in items) {
      final gid = settings.groupIdForProvider(p.key);
      final groupKey = (gid != null && groupById.containsKey(gid))
          ? gid
          : ungroupedKey;
      (providersByGroupKey[groupKey] ??= <({String name, String key})>[]).add(
        p,
      );
    }

    final rows = <_DesktopProviderGroupingRowVM>[];
    final searching = normalizedQuery.isNotEmpty;

    List<({String name, String key})> providersForGroup(
      String groupKey,
      String title,
    ) {
      final list =
          providersByGroupKey[groupKey] ??
          const <({String name, String key})>[];
      if (!searching) return list;
      final groupMatched = _matchesQuery(title, normalizedQuery);
      if (groupMatched) return list;
      return [
        for (final item in list)
          if (_providerMatches(
            item: item,
            settings: settings,
            normalizedQuery: normalizedQuery,
          ))
            item,
      ];
    }

    for (final g in groups) {
      final list = providersForGroup(g.id, g.name);
      if (list.isEmpty) continue;
      final collapsed = searching ? false : settings.isGroupCollapsed(g.id);
      rows.add(
        _DesktopProviderGroupingHeaderVM(
          groupKey: g.id,
          title: g.name,
          count: list.length,
          collapsed: collapsed,
        ),
      );
      for (final p in list) {
        rows.add(_DesktopProviderGroupingProviderVM(item: p, groupKey: g.id));
      }
    }

    final ungrouped = providersForGroup(ungroupedKey, l10n.providerGroupsOther);
    if (ungrouped.isNotEmpty) {
      final collapsed = searching
          ? false
          : settings.isGroupCollapsed(ungroupedKey);
      rows.add(
        _DesktopProviderGroupingHeaderVM(
          groupKey: ungroupedKey,
          title: l10n.providerGroupsOther,
          count: ungrouped.length,
          collapsed: collapsed,
        ),
      );
      for (final p in ungrouped) {
        rows.add(
          _DesktopProviderGroupingProviderVM(item: p, groupKey: ungroupedKey),
        );
      }
    }
    return rows;
  }

  Future<void> _showShareDialog(String providerKey, String displayName) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _DesktopProviderShareDialog(
        providerKey: providerKey,
        displayName: displayName,
      ),
    );
  }

  Widget _buildDesktopProviderRow({
    required ({String name, String key}) item,
    required SettingsProvider settings,
    required List<({String name, String key})> ordered,
    required Set<String> baseKeys,
    required ColorScheme colorScheme,
  }) {
    final cfg = settings.getProviderConfig(item.key, defaultName: item.name);
    final enabled = cfg.enabled;
    final selected = item.key == _selectedKey;
    final bg = selected
        ? colorScheme.primary.withOpacity(0.08)
        : Colors.transparent;
    return _ProviderListRow(
      name: item.name,
      keyName: item.key,
      enabled: enabled,
      selected: selected,
      background: bg,
      onTap: () => setState(() => _selectedKey = item.key),
      onEdit: () {
        setState(() => _selectedKey = item.key);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _detailKey.currentState?._showProviderSettingsDialog(context);
        });
      },
      onShare: () {
        setState(() => _selectedKey = item.key);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showShareDialog(
            item.key,
            cfg.name.isNotEmpty ? cfg.name : item.name,
          );
        });
      },
      onDelete: baseKeys.contains(item.key)
          ? null
          : () async {
              final l10n = AppLocalizations.of(context)!;
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l10n.providerDetailPageDeleteProviderTitle),
                  content: Text(l10n.providerDetailPageDeleteProviderContent),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(l10n.providerDetailPageCancelButton),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(
                        l10n.providerDetailPageDeleteButton,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
              if (ok != true) return;
              try {
                final ap = context.read<AssistantProvider>();
                for (final assistant in ap.assistants) {
                  if (assistant.chatModelProvider == item.key) {
                    await ap.updateAssistant(
                      assistant.copyWith(clearChatModel: true),
                    );
                  }
                }
              } catch (_) {}
              await settings.removeProviderConfig(item.key);
              if (!mounted) return;
              setState(() {
                if (_selectedKey == item.key) {
                  _selectedKey = ordered.isNotEmpty ? ordered.first.key : null;
                }
              });
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();

    // Base providers (same as mobile list)
    List<({String name, String key})> base() => [
      (name: 'OpenAI', key: 'OpenAI'),
      (name: l10n.providersPageSiliconFlowName, key: 'SiliconFlow'),
      (name: 'Gemini', key: 'Gemini'),
      (name: 'OpenRouter', key: 'OpenRouter'),
      (name: 'KelivoIN', key: 'KelivoIN'),
      (name: 'Tensdaq', key: 'Tensdaq'),
      (name: 'DeepSeek', key: 'DeepSeek'),
      (name: 'AIhubmix', key: 'AIhubmix'),
      (name: l10n.providersPageAliyunName, key: 'Aliyun'),
      (name: l10n.providersPageZhipuName, key: 'Zhipu AI'),
      (name: 'Claude', key: 'Claude'),
      (name: 'Grok', key: 'Grok'),
      (name: l10n.providersPageByteDanceName, key: 'ByteDance'),
    ];

    final cfgs = settings.providerConfigs;
    final baseKeys = {for (final p in base()) p.key};
    final dynamicItems = <({String name, String key})>[];
    cfgs.forEach((key, cfg) {
      if (!baseKeys.contains(key)) {
        dynamicItems.add((
          name: (cfg.name.isNotEmpty ? cfg.name : key),
          key: key,
        ));
      }
    });
    // Apply saved order
    final merged = <({String name, String key})>[...base(), ...dynamicItems];
    final order = settings.providersOrder;
    final map = {for (final p in merged) p.key: p};
    final ordered = <({String name, String key})>[];
    for (final k in order) {
      final v = map.remove(k);
      if (v != null) ordered.add(v);
    }
    ordered.addAll(map.values);
    final filteredOrdered = _applySearchToProviders(
      items: ordered,
      settings: settings,
      normalizedQuery: _searchQuery,
    );
    final groupingActive = settings.providerGroupingActive;
    final groupingRows = groupingActive
        ? _buildProviderGroupingRows(
            l10n: l10n,
            settings: settings,
            items: ordered,
            normalizedQuery: _searchQuery,
          )
        : const <_DesktopProviderGroupingRowVM>[];

    _selectedKey ??=
        (widget.initialSelectedKey ??
        (ordered.isNotEmpty ? ordered.first.key : null));
    final selectedKey = _selectedKey;
    final rightPane = selectedKey == null
        ? const SizedBox()
        : _DesktopProviderDetailPane(
            key: _detailKey,
            providerKey: selectedKey,
            displayName: settings.getProviderConfig(selectedKey).name.isNotEmpty
                ? settings.getProviderConfig(selectedKey).name
                : selectedKey,
          );

    return Container(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            children: [
              // Left providers list
              SizedBox(
                width: 256,
                child: Column(
                  children: [
                    _DesktopProvidersSearchField(
                      controller: _searchController,
                      hintText: l10n.providersPageSearchHint,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = _normalizeSearchQuery(value);
                        });
                      },
                      onClear: () {
                        if (_searchController.text.isEmpty) return;
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: groupingActive
                          ? ReorderableListView.builder(
                              buildDefaultDragHandles: false,
                              padding: EdgeInsets.zero,
                              itemCount: groupingRows.length,
                              onReorder: (oldIndex, newIndex) async {
                                if (_searchQuery.isNotEmpty) return;
                                if (groupingRows.isEmpty) return;
                                final sp = context.read<SettingsProvider>();

                                final logicRows = <ProviderGroupingRowVM>[
                                  for (final r in groupingRows)
                                    if (r is _DesktopProviderGroupingHeaderVM)
                                      ProviderGroupingHeaderVM(
                                        groupKey: r.groupKey,
                                      )
                                    else if (r
                                        is _DesktopProviderGroupingProviderVM)
                                      ProviderGroupingProviderVM(
                                        providerKey: r.item.key,
                                        groupKey: r.groupKey,
                                      ),
                                ];

                                final analysis = analyzeProviderGroupingReorder(
                                  rows: logicRows,
                                  oldIndex: oldIndex,
                                  newIndex: newIndex,
                                  isGroupCollapsed: sp.isGroupCollapsed,
                                );

                                if (analysis.blockedReason ==
                                    ProviderGroupingReorderBlockedReason
                                        .targetGroupCollapsed) {
                                  showAppSnackBar(
                                    context,
                                    message:
                                        l10n.providerGroupsExpandToMoveToast,
                                    type: NotificationType.info,
                                  );
                                  if (mounted) setState(() {});
                                  return;
                                }

                                final intent = analysis.intent;
                                if (intent == null) return;
                                final targetGroupId =
                                    intent.targetGroupKey ==
                                        SettingsProvider
                                            .providerUngroupedGroupKey
                                    ? null
                                    : intent.targetGroupKey;
                                await sp.moveProvider(
                                  intent.providerKey,
                                  targetGroupId,
                                  intent.targetPos,
                                );
                              },
                              proxyDecorator: (child, index, animation) {
                                return AnimatedBuilder(
                                  animation: animation,
                                  builder: (context, _) => ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: child,
                                  ),
                                );
                              },
                              itemBuilder: (ctx, i) {
                                final row = groupingRows[i];
                                if (row is _DesktopProviderGroupingHeaderVM) {
                                  return KeyedSubtree(
                                    key: ValueKey(
                                      'desktop-provider-group-header-${row.groupKey}',
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        bottom: 6,
                                        top: i == 0 ? 0 : 6,
                                      ),
                                      child: _DesktopProviderGroupHeaderRow(
                                        title: row.title,
                                        count: row.count,
                                        collapsed: row.collapsed,
                                        onToggle: _searchQuery.isNotEmpty
                                            ? null
                                            : () => unawaited(
                                                context
                                                    .read<SettingsProvider>()
                                                    .toggleGroupCollapsed(
                                                      row.groupKey,
                                                    ),
                                              ),
                                      ),
                                    ),
                                  );
                                }
                                if (row is _DesktopProviderGroupingProviderVM) {
                                  final collapsed = _searchQuery.isNotEmpty
                                      ? false
                                      : settings.isGroupCollapsed(row.groupKey);
                                  return KeyedSubtree(
                                    key: ValueKey(
                                      'desktop-prov-${row.item.key}',
                                    ),
                                    child: AnimatedSize(
                                      duration: const Duration(
                                        milliseconds: 260,
                                      ),
                                      curve: Curves.easeInOutCubic,
                                      alignment: Alignment.topCenter,
                                      child: collapsed
                                          ? const SizedBox.shrink()
                                          : Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 8,
                                              ),
                                              child: _searchQuery.isNotEmpty
                                                  ? _buildDesktopProviderRow(
                                                      item: row.item,
                                                      settings: settings,
                                                      ordered: ordered,
                                                      baseKeys: baseKeys,
                                                      colorScheme: cs,
                                                    )
                                                  : ReorderableDragStartListener(
                                                      index: i,
                                                      child:
                                                          _buildDesktopProviderRow(
                                                            item: row.item,
                                                            settings: settings,
                                                            ordered: ordered,
                                                            baseKeys: baseKeys,
                                                            colorScheme: cs,
                                                          ),
                                                    ),
                                            ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            )
                          : ReorderableListView.builder(
                              buildDefaultDragHandles: false,
                              padding: EdgeInsets.zero,
                              itemCount: filteredOrdered.length,
                              onReorder: (oldIndex, newIndex) async {
                                if (_searchQuery.isNotEmpty) return;
                                if (newIndex > oldIndex) newIndex -= 1;
                                final list =
                                    List<({String name, String key})>.from(
                                      ordered,
                                    );
                                final item = list.removeAt(oldIndex);
                                list.insert(newIndex, item);
                                final newOrder = [for (final e in list) e.key];
                                await settings.setProvidersOrder(newOrder);
                                if (mounted) setState(() {});
                              },
                              proxyDecorator: (child, index, animation) {
                                // No shadow; clip to rounded corners to avoid white outside of the grey card
                                return AnimatedBuilder(
                                  animation: animation,
                                  builder: (context, _) => ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: child,
                                  ),
                                );
                              },
                              itemBuilder: (ctx, i) {
                                final item = filteredOrdered[i];
                                final row = _buildDesktopProviderRow(
                                  item: item,
                                  settings: settings,
                                  ordered: ordered,
                                  baseKeys: baseKeys,
                                  colorScheme: cs,
                                );
                                return KeyedSubtree(
                                  key: ValueKey('desktop-prov-${item.key}'),
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _searchQuery.isNotEmpty
                                        ? row
                                        : ReorderableDragStartListener(
                                            index: i,
                                            child: row,
                                          ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 8),
                    // Bottom add button
                    _AddFullWidthButton(
                      height: 36,
                      label: l10n.addProviderSheetAddButton,
                      onTap: () async {
                        final created = await showDesktopAddProviderDialog(
                          context,
                        );
                        if (!mounted) return;
                        if (created != null && created.isNotEmpty) {
                          setState(() {
                            _selectedKey = created;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              VerticalDivider(
                width: 1,
                thickness: 0.5,
                color: cs.outlineVariant.withOpacity(0.12),
              ),
              // Right detail pane
              Expanded(child: rightPane),
            ],
          ),
        ),
      ),
    );
  }
}

sealed class _DesktopProviderGroupingRowVM {
  const _DesktopProviderGroupingRowVM();
}

class _DesktopProviderGroupingHeaderVM extends _DesktopProviderGroupingRowVM {
  const _DesktopProviderGroupingHeaderVM({
    required this.groupKey,
    required this.title,
    required this.count,
    required this.collapsed,
  });

  final String groupKey;
  final String title;
  final int count;
  final bool collapsed;
}

class _DesktopProviderGroupingProviderVM extends _DesktopProviderGroupingRowVM {
  const _DesktopProviderGroupingProviderVM({
    required this.item,
    required this.groupKey,
  });

  final ({String name, String key}) item;
  final String groupKey;
}

class _DesktopProvidersSearchField extends StatelessWidget {
  const _DesktopProvidersSearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final hasText = controller.text.trim().isNotEmpty;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
        fontSize: 14,
      ),
      cursorColor: cs.primary,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: cs.onSurface.withOpacity(0.5),
          fontSize: 13.5,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        prefixIcon: Icon(
          lucide.Lucide.Search,
          size: 16,
          color: cs.onSurface.withOpacity(0.5),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 34,
          minHeight: 34,
        ),
        suffixIcon: hasText
            ? IconButton(
                onPressed: onClear,
                icon: Icon(
                  lucide.Lucide.X,
                  size: 14,
                  color: cs.onSurface.withOpacity(0.48),
                ),
                tooltip: hintText,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                hoverColor: Colors.transparent,
              )
            : null,
        suffixIconConstraints: const BoxConstraints(
          minWidth: 34,
          minHeight: 34,
        ),
        filled: true,
        fillColor: isDark
            ? Colors.white.withOpacity(0.12)
            : const Color(0xFFEBEBEB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _DesktopProviderGroupHeaderRow extends StatefulWidget {
  const _DesktopProviderGroupHeaderRow({
    required this.title,
    required this.count,
    required this.collapsed,
    this.onToggle,
  });

  final String title;
  final int count;
  final bool collapsed;
  final VoidCallback? onToggle;

  @override
  State<_DesktopProviderGroupHeaderRow> createState() =>
      _DesktopProviderGroupHeaderRowState();
}

class _DesktopProviderGroupHeaderRowState
    extends State<_DesktopProviderGroupHeaderRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _hover
        ? (isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.04))
        : Colors.transparent;

    return MouseRegion(
      cursor: widget.onToggle == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Row(
            children: [
              AnimatedRotation(
                turns: widget.collapsed ? 0.0 : 0.25, // right -> down
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                child: Icon(
                  lucide.Lucide.ChevronRight,
                  size: 16,
                  color: cs.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface.withOpacity(0.9),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _GreyCapsule(label: '${widget.count}'),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopProviderDetailPane extends StatefulWidget {
  const _DesktopProviderDetailPane({
    super.key,
    required this.providerKey,
    required this.displayName,
  });
  final String providerKey;
  final String displayName;
  @override
  State<_DesktopProviderDetailPane> createState() =>
      _DesktopProviderDetailPaneState();
}

class _DesktopProviderDetailPaneState
    extends State<_DesktopProviderDetailPane> {
  bool _showSearch = false;
  final TextEditingController _filterCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _showApiKey = false;
  bool _eyeHover = false;

  // 批量选择模式相关
  bool _isSelectionMode = false;
  final Set<String> _selectedModels = {};
  bool _isDetecting = false;
  bool _detectUseStream = false;
  final Map<String, bool> _detectionResults = {};
  final Map<String, String> _detectionErrorMessages = {};
  String? _currentDetectingModel;
  final Set<String> _pendingModels = {};

  // Connection test state for inline dialog
  // Keep local to this file to avoid cross-file coupling

  // Persistent controllers for provider top inputs (desktop)
  // Avoid rebuilding controllers each frame which breaks focus/IME
  final TextEditingController _apiKeyCtrl = TextEditingController();
  final TextEditingController _baseUrlCtrl = TextEditingController();
  final TextEditingController _locationCtrl = TextEditingController();
  final TextEditingController _projectIdCtrl = TextEditingController();
  final TextEditingController _saJsonCtrl = TextEditingController();
  final TextEditingController _apiPathCtrl = TextEditingController();

  void _syncCtrl(TextEditingController c, String newText) {
    final v = c.value;
    // Do not disturb ongoing IME composition
    if (v.composing.isValid) return;
    if (c.text != newText) {
      c.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
  }

  void _syncControllersFromConfig(ProviderConfig cfg) {
    _syncCtrl(_apiKeyCtrl, cfg.apiKey);
    _syncCtrl(_baseUrlCtrl, cfg.baseUrl);
    _syncCtrl(_apiPathCtrl, cfg.chatPath ?? '/chat/completions');
    _syncCtrl(_locationCtrl, cfg.location ?? '');
    _syncCtrl(_projectIdCtrl, cfg.projectId ?? '');
    _syncCtrl(_saJsonCtrl, cfg.serviceAccountJson ?? '');
  }

  @override
  void dispose() {
    _filterCtrl.dispose();
    _searchFocus.dispose();
    _apiKeyCtrl.dispose();
    _baseUrlCtrl.dispose();
    _locationCtrl.dispose();
    _projectIdCtrl.dispose();
    _saJsonCtrl.dispose();
    _apiPathCtrl.dispose();
    super.dispose();
  }

  Future<String?> _inputDialog(
    BuildContext context, {
    required String title,
    required String hint,
  }) async {
    final cs = Theme.of(context).colorScheme;
    final ctrl = TextEditingController();
    String? result;
    await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _IconBtn(
                      icon: lucide.Lucide.X,
                      onTap: () => Navigator.of(ctx).maybePop(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  style: const TextStyle(fontSize: 13),
                  decoration: _inputDecoration(ctx).copyWith(hintText: hint),
                  onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: _DeskIosButton(
                    label: AppLocalizations.of(
                      context,
                    )!.assistantEditEmojiDialogSave,
                    filled: true,
                    dense: true,
                    onTap: () => Navigator.of(ctx).pop(ctrl.text.trim()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((v) => result = v);
    return (result ?? '').trim().isEmpty ? null : result!.trim();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    final cfg = sp.getProviderConfig(
      widget.providerKey,
      defaultName: widget.displayName,
    );
    // Keep controllers synced without breaking IME composition
    _syncControllersFromConfig(cfg);
    final kind = ProviderConfig.classify(
      widget.providerKey,
      explicitType: cfg.providerType,
    );

    final models = List<String>.from(cfg.models);
    final allSelected =
        _selectedModels.length == models.length && models.isNotEmpty;
    final filtered = _applyFilter(models, _filterCtrl.text.trim());
    final groups = _groupModels(filtered);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 36,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                // Title + Settings button grouped at left, per request
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Text(
                        cfg.name.isNotEmpty ? cfg.name : widget.providerKey,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _IconBtn(
                      icon: lucide.Lucide.Settings,
                      onTap: () => _showProviderSettingsDialog(context),
                    ),
                  ],
                ),
                const Spacer(),
                IosSwitch(
                  value: cfg.enabled,
                  onChanged: (v) async {
                    final old = sp.getProviderConfig(
                      widget.providerKey,
                      defaultName: widget.displayName,
                    );
                    await sp.setProviderConfig(
                      widget.providerKey,
                      old.copyWith(enabled: v),
                    );
                    // If provider is now disabled, clear model selections referencing it
                    if (!v && old.enabled) {
                      await sp.clearSelectionsForProvider(widget.providerKey);
                      try {
                        final ap = context.read<AssistantProvider>();
                        for (final a in ap.assistants) {
                          if (a.chatModelProvider == widget.providerKey) {
                            await ap.updateAssistant(
                              a.copyWith(clearChatModel: true),
                            );
                          }
                        }
                      } catch (_) {}
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Divider(
            height: 1,
            thickness: 0.5,
            color: cs.outlineVariant.withOpacity(0.12),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              // Partner info banners
              if (widget.providerKey.toLowerCase() == 'tensdaq') ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.primary.withOpacity(0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '革命性竞价 AI MaaS 平台，价格由市场供需决定，告别高成本固定定价。',
                        style: TextStyle(color: cs.onSurface.withOpacity(0.8)),
                      ),
                      const SizedBox(height: 6),
                      Text.rich(
                        TextSpan(
                          text: '官网：',
                          style: TextStyle(
                            color: cs.onSurface.withOpacity(0.8),
                          ),
                          children: [
                            TextSpan(
                              text: 'https://dashboard.x-aio.com',
                              style: TextStyle(
                                color: cs.primary,
                                fontWeight: FontWeight.w700,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () async {
                                  final uri = Uri.parse(
                                    'https://dashboard.x-aio.com',
                                  );
                                  try {
                                    final ok = await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                    if (!ok) {
                                      await launchUrl(uri);
                                    }
                                  } catch (_) {
                                    await launchUrl(uri);
                                  }
                                },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              if (widget.providerKey.toLowerCase() == 'siliconflow') ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.primary.withOpacity(0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '已内置硅基流动的免费模型，无需 API Key。若需更强大的模型，请申请并在此配置你自己的 API Key。',
                        style: TextStyle(color: cs.onSurface.withOpacity(0.8)),
                      ),
                      const SizedBox(height: 6),
                      Text.rich(
                        TextSpan(
                          text: '官网：',
                          style: TextStyle(
                            color: cs.onSurface.withOpacity(0.8),
                          ),
                          children: [
                            TextSpan(
                              text: 'https://siliconflow.cn',
                              style: TextStyle(
                                color: cs.primary,
                                fontWeight: FontWeight.w700,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () async {
                                  final uri = Uri.parse(
                                    'https://siliconflow.cn',
                                  );
                                  try {
                                    final ok = await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                    if (!ok) {
                                      await launchUrl(uri);
                                    }
                                  } catch (_) {
                                    await launchUrl(uri);
                                  }
                                },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // API Key (hidden when Google Vertex)
              if (!(kind == ProviderKind.google && (cfg.vertexAI == true))) ...[
                Row(
                  children: [
                    Expanded(
                      child: _sectionLabel(
                        context,
                        AppLocalizations.of(context)!.multiKeyPageKey,
                        bold: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: l10n.providerDetailPageTestButton,
                      child: _IconTextBtn(
                        icon: lucide.Lucide.HeartPulse,
                        label: l10n.providerDetailPageTestButton,
                        onTap: () => _showTestConnectionDialog(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (cfg.multiKeyEnabled == true)
                  Row(
                    children: [
                      Expanded(
                        child: AbsorbPointer(
                          child: Opacity(
                            opacity: 0.6,
                            child: TextField(
                              controller: TextEditingController(
                                text: '••••••••',
                              ),
                              readOnly: true,
                              style: const TextStyle(fontSize: 14),
                              decoration: _inputDecoration(context),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _DeskIosButton(
                        label: l10n.providerDetailPageManageKeysButton,
                        filled: false,
                        dense: true,
                        onTap: () => _showMultiKeyDialog(context),
                      ),
                    ],
                  )
                else
                  TextField(
                    controller: _apiKeyCtrl,
                    obscureText: !_showApiKey ? true : false,
                    onChanged: (v) async {
                      // For API keys, save immediately regardless of IME composition
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      await sp.setProviderConfig(
                        widget.providerKey,
                        old.copyWith(apiKey: v),
                      );
                    },
                    style: const TextStyle(fontSize: 14),
                    decoration: _inputDecoration(context).copyWith(
                      hintText: l10n.providerDetailPageApiKeyHint,
                      suffixIcon: MouseRegion(
                        onEnter: (_) => setState(() => _eyeHover = true),
                        onExit: (_) => setState(() => _eyeHover = false),
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _showApiKey = !_showApiKey),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _eyeHover
                                  ? (Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white.withOpacity(0.06)
                                        : Colors.black.withOpacity(0.04))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              transitionBuilder: (child, anim) =>
                                  FadeTransition(opacity: anim, child: child),
                              child: AnimatedRotation(
                                key: ValueKey(_showApiKey),
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                                turns: _showApiKey ? 0.5 : 0.0,
                                child: Icon(
                                  _showApiKey
                                      ? lucide.Lucide.EyeOff
                                      : lucide.Lucide.Eye,
                                  size: 18,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.8),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 20,
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
              ],

              // API Base URL or Vertex AI fields
              if (!(kind == ProviderKind.google && (cfg.vertexAI == true))) ...[
                _sectionLabel(
                  context,
                  AppLocalizations.of(
                    context,
                  )!.providerDetailPageApiBaseUrlLabel,
                  bold: true,
                ),
                const SizedBox(height: 6),
                Focus(
                  onFocusChange: (has) async {
                    if (!has) {
                      final v = _baseUrlCtrl.text;
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      await sp.setProviderConfig(
                        widget.providerKey,
                        old.copyWith(baseUrl: v),
                      );
                    }
                  },
                  child: TextField(
                    controller: _baseUrlCtrl,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) async {
                      final v = _baseUrlCtrl.text;
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      await sp.setProviderConfig(
                        widget.providerKey,
                        old.copyWith(baseUrl: v),
                      );
                    },
                    onEditingComplete: () async {
                      final v = _baseUrlCtrl.text;
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      await sp.setProviderConfig(
                        widget.providerKey,
                        old.copyWith(baseUrl: v),
                      );
                    },
                    onChanged: (v) async {
                      if (_baseUrlCtrl.value.composing.isValid) return;
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      await sp.setProviderConfig(
                        widget.providerKey,
                        old.copyWith(baseUrl: v),
                      );
                    },
                    style: const TextStyle(fontSize: 14),
                    decoration: _inputDecoration(context).copyWith(
                      hintText: ProviderConfig.defaultsFor(
                        widget.providerKey,
                        displayName: widget.displayName,
                      ).baseUrl,
                    ),
                  ),
                ),
              ] else ...[
                _sectionLabel(
                  context,
                  l10n.providerDetailPageLocationLabel,
                  bold: true,
                ),
                const SizedBox(height: 6),
                Focus(
                  onFocusChange: (has) async {
                    if (!has) {
                      final v = _locationCtrl.text.trim();
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      await sp.setProviderConfig(
                        widget.providerKey,
                        old.copyWith(location: v),
                      );
                    }
                  },
                  child: TextField(
                    controller: _locationCtrl,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) async {
                      final v = _locationCtrl.text.trim();
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      await sp.setProviderConfig(
                        widget.providerKey,
                        old.copyWith(location: v),
                      );
                    },
                    onEditingComplete: () async {
                      final v = _locationCtrl.text.trim();
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      await sp.setProviderConfig(
                        widget.providerKey,
                        old.copyWith(location: v),
                      );
                    },
                    onChanged: (v) async {
                      if (_locationCtrl.value.composing.isValid) return;
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      await sp.setProviderConfig(
                        widget.providerKey,
                        old.copyWith(location: v.trim()),
                      );
                    },
                    style: const TextStyle(fontSize: 14),
                    decoration: _inputDecoration(
                      context,
                    ).copyWith(hintText: 'us-central1'),
                  ),
                ),
                const SizedBox(height: 14),
                _sectionLabel(
                  context,
                  l10n.providerDetailPageProjectIdLabel,
                  bold: true,
                ),
                const SizedBox(height: 6),
                Focus(
                  onFocusChange: (has) async {
                    if (!has) {
                      final v = _projectIdCtrl.text.trim();
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      await sp.setProviderConfig(
                        widget.providerKey,
                        old.copyWith(projectId: v),
                      );
                    }
                  },
                  child: TextField(
                    controller: _projectIdCtrl,
                    onChanged: (v) async {
                      if (_projectIdCtrl.value.composing.isValid) return;
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      await sp.setProviderConfig(
                        widget.providerKey,
                        old.copyWith(projectId: v.trim()),
                      );
                    },
                    onSubmitted: (_) async {
                      final v = _projectIdCtrl.text.trim();
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      await sp.setProviderConfig(
                        widget.providerKey,
                        old.copyWith(projectId: v),
                      );
                    },
                    onEditingComplete: () async {
                      final v = _projectIdCtrl.text.trim();
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      await sp.setProviderConfig(
                        widget.providerKey,
                        old.copyWith(projectId: v),
                      );
                    },
                    style: const TextStyle(fontSize: 14),
                    decoration: _inputDecoration(
                      context,
                    ).copyWith(hintText: 'my-project-id'),
                  ),
                ),
                const SizedBox(height: 14),
                _sectionLabel(
                  context,
                  l10n.providerDetailPageServiceAccountJsonLabel,
                  bold: true,
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 120),
                  child: Focus(
                    onFocusChange: (has) async {
                      if (!has) {
                        final v = _saJsonCtrl.text;
                        final old = sp.getProviderConfig(
                          widget.providerKey,
                          defaultName: widget.displayName,
                        );
                        await sp.setProviderConfig(
                          widget.providerKey,
                          old.copyWith(serviceAccountJson: v),
                        );
                      }
                    },
                    child: TextField(
                      controller: _saJsonCtrl,
                      maxLines: null,
                      minLines: 6,
                      onChanged: (v) async {
                        if (_saJsonCtrl.value.composing.isValid) return;
                        final old = sp.getProviderConfig(
                          widget.providerKey,
                          defaultName: widget.displayName,
                        );
                        await sp.setProviderConfig(
                          widget.providerKey,
                          old.copyWith(serviceAccountJson: v),
                        );
                      },
                      style: const TextStyle(fontSize: 14),
                      decoration: _inputDecoration(context).copyWith(
                        hintText: '{\n  "type": "service_account", ...\n}',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _DeskIosButton(
                    label: l10n.providerDetailPageImportJsonButton,
                    filled: false,
                    dense: true,
                    onTap: () async {
                      final res = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['json'],
                        withData: true,
                      );
                      if (res == null || res.files.isEmpty) return;

                      final file = res.files.first;
                      // Desktop FilePicker may not include bytes unless withData is true; fall back to disk read.
                      String? content;
                      if (file.bytes != null && file.bytes!.isNotEmpty) {
                        content = utf8.decode(file.bytes!);
                      } else if (file.path != null && file.path!.isNotEmpty) {
                        try {
                          content = await File(file.path!).readAsString();
                        } catch (_) {}
                      }
                      if (content == null || content.trim().isEmpty) {
                        showAppSnackBar(
                          context,
                          message: 'Failed to read file',
                          type: NotificationType.error,
                        );
                        return;
                      }

                      String projectId = cfg.projectId ?? '';
                      try {
                        final obj = jsonDecode(content);
                        projectId =
                            (obj['project_id'] as String?)?.trim() ?? projectId;
                      } catch (_) {}
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      final updated = old.copyWith(
                        serviceAccountJson: content,
                        projectId: projectId,
                      );
                      _syncControllersFromConfig(updated);
                      await sp.setProviderConfig(widget.providerKey, updated);
                    },
                  ),
                ),
              ],

              // API Path (OpenAI chat)
              if (kind == ProviderKind.openai &&
                  (cfg.useResponseApi != true)) ...[
                const SizedBox(height: 14),
                _sectionLabel(
                  context,
                  l10n.providerDetailPageApiPathLabel,
                  bold: true,
                ),
                const SizedBox(height: 6),
                Focus(
                  onFocusChange: (has) async {
                    if (!has) {
                      final v = _apiPathCtrl.text;
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      await sp.setProviderConfig(
                        widget.providerKey,
                        old.copyWith(chatPath: v),
                      );
                    }
                  },
                  child: TextField(
                    controller: _apiPathCtrl,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) async {
                      final v = _apiPathCtrl.text;
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      await sp.setProviderConfig(
                        widget.providerKey,
                        old.copyWith(chatPath: v),
                      );
                    },
                    onEditingComplete: () async {
                      final v = _apiPathCtrl.text;
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      await sp.setProviderConfig(
                        widget.providerKey,
                        old.copyWith(chatPath: v),
                      );
                    },
                    onChanged: (v) async {
                      if (_apiPathCtrl.value.composing.isValid) return;
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      await sp.setProviderConfig(
                        widget.providerKey,
                        old.copyWith(chatPath: v),
                      );
                    },
                    style: const TextStyle(fontSize: 14),
                    decoration: _inputDecoration(
                      context,
                    ).copyWith(hintText: '/chat/completions'),
                  ),
                ),
              ],

              const SizedBox(height: 18),
              // Models header with count + search + actions (test / add / fetch)
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          AppLocalizations.of(
                            context,
                          )!.providerDetailPageModelsTitle,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _GreyCapsule(label: '${models.length}'),
                        const Spacer(),
                        Flexible(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              width: _showSearch ? 180 : 28,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 140),
                                transitionBuilder: (child, anim) =>
                                    FadeTransition(opacity: anim, child: child),
                                child: _showSearch
                                    ? TextField(
                                        key: const ValueKey('search-field'),
                                        controller: _filterCtrl,
                                        focusNode: _searchFocus,
                                        autofocus: true,
                                        style: const TextStyle(fontSize: 14),
                                        decoration: _inputDecoration(context)
                                            .copyWith(
                                              hintText: l10n
                                                  .providerDetailPageFilterHint,
                                              isDense: true,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 8,
                                                  ),
                                            ),
                                        onChanged: (_) => setState(() {}),
                                      )
                                    : _IconBtn(
                                        key: const ValueKey('search-icon'),
                                        icon: lucide.Lucide.Search,
                                        onTap: () => setState(() {
                                          _showSearch = true;
                                          _searchFocus.addListener(() {
                                            if (!_searchFocus.hasFocus)
                                              setState(
                                                () => _showSearch = false,
                                              );
                                          });
                                        }),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (_isSelectionMode) ...[
                    Tooltip(
                      message: l10n.homePageCancel,
                      child: _IconBtn(
                        icon: lucide.Lucide.X,
                        onTap: _exitSelectionMode,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: allSelected
                          ? l10n.mcpAssistantSheetClearAll
                          : l10n.mcpAssistantSheetSelectAll,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: _IconBtn(
                          key: ValueKey(allSelected),
                          icon: allSelected
                              ? lucide.Lucide.Square
                              : lucide.Lucide.CheckSquare,
                          color: cs.onSurface.withOpacity(0.85),
                          onTap: () {
                            setState(() {
                              if (allSelected) {
                                _selectedModels.clear();
                              } else {
                                _selectedModels.clear();
                                _selectedModels.addAll(models);
                              }
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: l10n.providerDetailPageUseStreamingLabel,
                      child: GestureDetector(
                        onTap: () => setState(
                          () => _detectUseStream = !_detectUseStream,
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: _detectUseStream
                                ? cs.onSurface.withOpacity(0.08)
                                : Colors.transparent,
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            transitionBuilder: (child, anim) =>
                                ScaleTransition(scale: anim, child: child),
                            child: Icon(
                              _detectUseStream
                                  ? lucide.Lucide.AudioWaveform
                                  : lucide.Lucide.SquareEqual,
                              key: ValueKey(_detectUseStream),
                              size: 18,
                              color: cs.onSurface.withOpacity(0.85),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: _isDetecting
                          ? l10n.providerDetailPageBatchDetecting
                          : l10n.providerDetailPageBatchDetectStart,
                      child: _IconTextBtn(
                        icon: _isDetecting
                            ? lucide.Lucide.Loader
                            : lucide.Lucide.HeartPulse,
                        label: _isDetecting
                            ? l10n.providerDetailPageBatchDetecting
                            : l10n.providerDetailPageBatchDetectButton,
                        color: _selectedModels.isEmpty
                            ? cs.onSurface.withOpacity(0.4)
                            : null,
                        onTap: () {
                          if (_selectedModels.isEmpty) return;
                          _startDetection();
                        },
                      ),
                    ),
                  ] else ...[
                    if (!_isDetecting)
                      Tooltip(
                        message: l10n.searchServicesPageTestConnectionTooltip,
                        child: _IconBtn(
                          icon: lucide.Lucide.HeartPulse,
                          onTap: _enterSelectionMode,
                        ),
                      )
                    else
                      Tooltip(
                        message: l10n.providerDetailPageBatchDetecting,
                        child: _IconBtn(
                          icon: lucide.Lucide.Loader,
                          onTap: () {},
                        ),
                      ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: l10n.providerDetailPageAddNewModelButton,
                      child: _IconBtn(
                        icon: lucide.Lucide.Plus,
                        onTap: () => _createModel(context),
                      ),
                    ),
                    if (models.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Tooltip(
                        message: '删除全部模型',
                        child: _IconBtn(
                          icon: lucide.Lucide.Trash2,
                          color: cs.onSurface.withOpacity(0.85),
                          onTap: _confirmDeleteAllModels,
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    Tooltip(
                      message: l10n.providerDetailPageFetchModelsButton,
                      child: _IconTextBtn(
                        icon: lucide.Lucide.RefreshCcwDot,
                        label: l10n.providerDetailPageFetchModelsButton,
                        onTap: () async {
                          final providerName = widget.displayName;
                          await showModelFetchDialog(
                            context,
                            providerKey: widget.providerKey,
                            providerDisplayName: providerName,
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 6),
              // Accordion groups
              for (final entry in groups.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ModelGroupAccordion(
                    group: entry.key,
                    modelIds: entry.value,
                    providerKey: widget.providerKey,
                    isSelectionMode: _isSelectionMode,
                    selectedModels: _selectedModels,
                    onSelectionChanged: (newSelection) {
                      setState(() {
                        _selectedModels.clear();
                        _selectedModels.addAll(newSelection);
                      });
                    },
                    detectionResults: _detectionResults,
                    detectionErrorMessages: _detectionErrorMessages,
                    currentDetectingModel: _currentDetectingModel,
                    pendingModels: _pendingModels,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Map<String, List<String>> _groupModels(List<String> models) {
    final map = <String, List<String>>{};
    for (final m in models) {
      var g = m;
      if (m.contains('/'))
        g = m.split('/').first;
      else if (m.contains(':'))
        g = m.split(':').first;
      else if (m.contains('-'))
        g = m.split('-').first;
      (map[g] ??= <String>[])..add(m);
    }
    // Keep stable order by key
    final entries = map.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    return {for (final e in entries) e.key: e.value};
  }

  List<String> _applyFilter(List<String> src, String q) {
    if (q.isEmpty) return src;
    final k = q.toLowerCase();
    return [
      for (final m in src)
        if (m.toLowerCase().contains(k)) m,
    ];
  }

  InputDecoration _inputDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: isDark ? Colors.white10 : const Color(0xFFF7F7F9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: cs.outlineVariant.withOpacity(0.12),
          width: 0.6,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: cs.outlineVariant.withOpacity(0.12),
          width: 0.6,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: cs.primary.withOpacity(0.35), width: 0.8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Future<void> _showProviderSettingsDialog(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final sp = context.read<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;
    ProviderConfig cfg = sp.getProviderConfig(
      widget.providerKey,
      defaultName: widget.displayName,
    );
    ProviderKind kind = ProviderConfig.classify(
      widget.providerKey,
      explicitType: cfg.providerType,
    );
    bool multi = cfg.multiKeyEnabled ?? false;
    bool openaiResp = cfg.useResponseApi ?? false;
    bool googleVertex = cfg.vertexAI ?? false;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final GlobalKey _avatarKey = GlobalKey();
        final nameCtrl = TextEditingController(text: cfg.name);
        final proxyHostCtrl = TextEditingController(text: cfg.proxyHost ?? '');
        final proxyPortCtrl = TextEditingController(
          text: cfg.proxyPort ?? '8080',
        );
        final proxyUserCtrl = TextEditingController(
          text: cfg.proxyUsername ?? '',
        );
        final proxyPassCtrl = TextEditingController(
          text: cfg.proxyPassword ?? '',
        );
        ProviderKind tmpKind = kind;
        bool tmpMulti = multi;
        bool tmpResp = openaiResp;
        bool tmpVertex = googleVertex;
        return Dialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Consumer<SettingsProvider>(
              builder: (c, spWatch, _) {
                final cfgNow = spWatch.getProviderConfig(
                  widget.providerKey,
                  defaultName: widget.displayName,
                );
                // IME-friendly sync: avoid overwriting while composing
                void syncCtrl(TextEditingController ctrl, String text) {
                  final v = ctrl.value;
                  if (v.composing.isValid) return;
                  if (ctrl.text != text) {
                    ctrl.value = TextEditingValue(
                      text: text,
                      selection: TextSelection.collapsed(offset: text.length),
                    );
                  }
                }

                syncCtrl(nameCtrl, cfgNow.name);
                syncCtrl(proxyHostCtrl, cfgNow.proxyHost ?? '');
                syncCtrl(proxyPortCtrl, cfgNow.proxyPort ?? '8080');
                syncCtrl(proxyUserCtrl, cfgNow.proxyUsername ?? '');
                syncCtrl(proxyPassCtrl, cfgNow.proxyPassword ?? '');
                final kindNow =
                    cfgNow.providerType ??
                    ProviderConfig.classify(
                      cfgNow.id,
                      explicitType: cfgNow.providerType,
                    );
                final multiNow = cfgNow.multiKeyEnabled ?? false;
                final respNow = cfgNow.useResponseApi ?? false;
                final vertexNow = cfgNow.vertexAI ?? false;
                final proxyEnabledNow = cfgNow.proxyEnabled ?? false;
                final aihubmixAppCodeEnabled =
                    cfgNow.aihubmixAppCodeEnabled ?? false;
                final groupsNow = spWatch.providerGroups;
                final groupValue =
                    spWatch.groupIdForProvider(widget.providerKey) ??
                    SettingsProvider.providerUngroupedGroupKey;
                final groupOptions = <DesktopSelectOption<String>>[
                  DesktopSelectOption(
                    value: SettingsProvider.providerUngroupedGroupKey,
                    label: l10n.providerGroupsOtherUngroupedOption,
                  ),
                  for (final g in groupsNow)
                    DesktopSelectOption(value: g.id, label: g.name),
                ];
                Widget row(String label, Widget trailing) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            color: cs.onSurface.withOpacity(0.9),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(width: 260, child: trailing),
                    ],
                  ),
                );
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 44,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                cfgNow.name.isNotEmpty
                                    ? cfgNow.name
                                    : widget.providerKey,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            _IconBtn(
                              icon: lucide.Lucide.X,
                              onTap: () => Navigator.of(ctx).maybePop(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Divider(
                        height: 1,
                        thickness: 0.5,
                        color: cs.outlineVariant.withOpacity(0.12),
                      ),
                    ),
                    // Centered provider avatar (smaller than user dialog)
                    Padding(
                      padding: const EdgeInsets.only(top: 14, bottom: 6),
                      child: Center(
                        child: GestureDetector(
                          key: _avatarKey,
                          onTapDown: (_) async {
                            // Open avatar menu (anchored)
                            final l10n2 = AppLocalizations.of(context)!;
                            await showDesktopAnchoredMenu(
                              context,
                              anchorKey: _avatarKey,
                              offset: const Offset(0, 8),
                              items: [
                                DesktopContextMenuItem(
                                  icon: lucide.Lucide.Image,
                                  label: l10n2.sideDrawerChooseImage,
                                  onTap: () async {
                                    try {
                                      final res = await FilePicker.platform
                                          .pickFiles(
                                            allowMultiple: false,
                                            withData: false,
                                            type: FileType.custom,
                                            allowedExtensions: const [
                                              'png',
                                              'jpg',
                                              'jpeg',
                                              'gif',
                                              'webp',
                                              'heic',
                                              'heif',
                                            ],
                                          );
                                      final f =
                                          (res != null && res.files.isNotEmpty)
                                          ? res.files.first
                                          : null;
                                      final path = f?.path;
                                      if (path != null && path.isNotEmpty) {
                                        await context
                                            .read<SettingsProvider>()
                                            .setProviderAvatarFilePath(
                                              widget.providerKey,
                                              path,
                                            );
                                      }
                                    } catch (_) {}
                                  },
                                ),
                                DesktopContextMenuItem(
                                  icon: lucide.Lucide.Link,
                                  label: l10n2.sideDrawerEnterLink,
                                  onTap: () async {
                                    await _inputProviderAvatarUrl(
                                      context,
                                      widget.providerKey,
                                    );
                                  },
                                ),
                                DesktopContextMenuItem(
                                  icon: lucide.Lucide.RotateCw,
                                  label: l10n2.desktopAvatarMenuReset,
                                  onTap: () async {
                                    await context
                                        .read<SettingsProvider>()
                                        .resetProviderAvatar(
                                          widget.providerKey,
                                        );
                                  },
                                ),
                              ],
                            );
                          },
                          child: ProviderAvatar(
                            providerKey: widget.providerKey,
                            displayName: widget.displayName,
                            size: 64,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1) Name
                          row(
                            l10n.providerDetailPageNameLabel,
                            Focus(
                              onFocusChange: (has) async {
                                if (!has) {
                                  final v = nameCtrl.text.trim();
                                  final old = spWatch.getProviderConfig(
                                    widget.providerKey,
                                    defaultName: widget.displayName,
                                  );
                                  await spWatch.setProviderConfig(
                                    widget.providerKey,
                                    old.copyWith(
                                      name: v.isEmpty ? widget.displayName : v,
                                    ),
                                  );
                                }
                              },
                              child: TextField(
                                controller: nameCtrl,
                                style: const TextStyle(fontSize: 14),
                                decoration: _inputDecoration(ctx),
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) async {
                                  final v = nameCtrl.text.trim();
                                  final old = spWatch.getProviderConfig(
                                    widget.providerKey,
                                    defaultName: widget.displayName,
                                  );
                                  await spWatch.setProviderConfig(
                                    widget.providerKey,
                                    old.copyWith(
                                      name: v.isEmpty ? widget.displayName : v,
                                    ),
                                  );
                                },
                                onEditingComplete: () async {
                                  final v = nameCtrl.text.trim();
                                  final old = spWatch.getProviderConfig(
                                    widget.providerKey,
                                    defaultName: widget.displayName,
                                  );
                                  await spWatch.setProviderConfig(
                                    widget.providerKey,
                                    old.copyWith(
                                      name: v.isEmpty ? widget.displayName : v,
                                    ),
                                  );
                                },
                                onChanged: (_) async {
                                  // Avoid saving during IME composing to prevent glitches with Pinyin input
                                  if (nameCtrl.value.composing.isValid) return;
                                  final v = nameCtrl.text.trim();
                                  final old = spWatch.getProviderConfig(
                                    widget.providerKey,
                                    defaultName: widget.displayName,
                                  );
                                  await spWatch.setProviderConfig(
                                    widget.providerKey,
                                    old.copyWith(
                                      name: v.isEmpty ? widget.displayName : v,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // 1.5) Group
                          row(
                            l10n.providerGroupsGroupLabel,
                            Row(
                              children: [
                                Expanded(
                                  child: DesktopSelectDropdown<String>(
                                    value: groupValue,
                                    options: groupOptions,
                                    maxLabelWidth: 150,
                                    triggerFillColor:
                                        Theme.of(ctx).brightness ==
                                            Brightness.dark
                                        ? Colors.white10
                                        : const Color(0xFFF7F7F9),
                                    onSelected: (v) async {
                                      if (v ==
                                          SettingsProvider
                                              .providerUngroupedGroupKey) {
                                        await spWatch.setProviderGroup(
                                          widget.providerKey,
                                          null,
                                        );
                                      } else {
                                        await spWatch.setProviderGroup(
                                          widget.providerKey,
                                          v,
                                        );
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _IconBtn(
                                  icon: lucide.Lucide.Plus,
                                  onTap: () => unawaited(() async {
                                    final controller = TextEditingController();
                                    final ok = await showDialog<bool>(
                                      context: ctx,
                                      barrierColor: Colors.black.withOpacity(
                                        0.12,
                                      ),
                                      builder: (dctx) => AlertDialog(
                                        title: Text(
                                          l10n.providerGroupsCreateDialogTitle,
                                        ),
                                        content: TextField(
                                          controller: controller,
                                          autofocus: true,
                                          decoration: InputDecoration(
                                            hintText:
                                                l10n.providerGroupsNameHint,
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(dctx).pop(false),
                                            child: Text(
                                              l10n.providerGroupsCreateDialogCancel,
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(dctx).pop(true),
                                            child: Text(
                                              l10n.providerGroupsCreateDialogOk,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (ok != true) return;
                                    final name = controller.text.trim();
                                    if (name.isEmpty) return;
                                    final id = await spWatch.createGroup(name);
                                    if (id.isEmpty) return;
                                    await spWatch.setProviderGroup(
                                      widget.providerKey,
                                      id,
                                    );
                                  }()),
                                ),
                                const SizedBox(width: 4),
                                _IconBtn(
                                  icon: lucide.Lucide.Settings,
                                  onTap: () => unawaited(
                                    showDialog<void>(
                                      context: ctx,
                                      barrierDismissible: true,
                                      barrierColor: Colors.black.withOpacity(
                                        0.12,
                                      ),
                                      builder: (_) =>
                                          const _DesktopProviderGroupsDialog(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          // 2) Provider type
                          row(
                            l10n.providerDetailPageProviderTypeTitle,
                            _ProviderTypeDropdown(
                              value: kindNow,
                              onChanged: (k) async {
                                final old = spWatch.getProviderConfig(
                                  widget.providerKey,
                                  defaultName: widget.displayName,
                                );
                                await spWatch.setProviderConfig(
                                  widget.providerKey,
                                  old.copyWith(providerType: k),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 4),
                          // 3) Multi-Key
                          row(
                            l10n.providerDetailPageMultiKeyModeTitle,
                            Align(
                              alignment: Alignment.centerRight,
                              child: IosSwitch(
                                value: multiNow,
                                onChanged: (v) async {
                                  final old = spWatch.getProviderConfig(
                                    widget.providerKey,
                                    defaultName: widget.displayName,
                                  );
                                  await spWatch.setProviderConfig(
                                    widget.providerKey,
                                    old.copyWith(multiKeyEnabled: v),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // 4) Response (OpenAI) or Vertex (Google). Hide for Claude, with animation.
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: () {
                              if (kindNow == ProviderKind.openai) {
                                return KeyedSubtree(
                                  key: const ValueKey('openai-resp'),
                                  child: row(
                                    l10n.providerDetailPageResponseApiTitle,
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: IosSwitch(
                                        value: respNow,
                                        onChanged: (v) async {
                                          final old = spWatch.getProviderConfig(
                                            widget.providerKey,
                                            defaultName: widget.displayName,
                                          );
                                          await spWatch.setProviderConfig(
                                            widget.providerKey,
                                            old.copyWith(useResponseApi: v),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              }
                              if (kindNow == ProviderKind.google) {
                                return KeyedSubtree(
                                  key: const ValueKey('google-vertex'),
                                  child: row(
                                    l10n.providerDetailPageVertexAiTitle,
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: IosSwitch(
                                        value: vertexNow,
                                        onChanged: (v) async {
                                          final old = spWatch.getProviderConfig(
                                            widget.providerKey,
                                            defaultName: widget.displayName,
                                          );
                                          await spWatch.setProviderConfig(
                                            widget.providerKey,
                                            old.copyWith(vertexAI: v),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink(
                                key: ValueKey('none'),
                              );
                            }(),
                          ),
                          const SizedBox(height: 4),
                          if (_isAihubmix(cfgNow))
                            row(
                              l10n.providerDetailPageAihubmixAppCodeLabel,
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Tooltip(
                                    message: l10n
                                        .providerDetailPageAihubmixAppCodeHelp,
                                    child: Icon(
                                      Icons.help_outline,
                                      size: 16,
                                      color: cs.onSurface.withOpacity(0.6),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IosSwitch(
                                    value: aihubmixAppCodeEnabled,
                                    onChanged: (v) async {
                                      final old = spWatch.getProviderConfig(
                                        widget.providerKey,
                                        defaultName: widget.displayName,
                                      );
                                      await spWatch.setProviderConfig(
                                        widget.providerKey,
                                        old.copyWith(aihubmixAppCodeEnabled: v),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 4),
                          // 5) Network proxy inline
                          row(
                            l10n.providerDetailPageNetworkTab,
                            Align(
                              alignment: Alignment.centerRight,
                              child: IosSwitch(
                                value: proxyEnabledNow,
                                onChanged: (v) async {
                                  final old = spWatch.getProviderConfig(
                                    widget.providerKey,
                                    defaultName: widget.displayName,
                                  );
                                  await spWatch.setProviderConfig(
                                    widget.providerKey,
                                    old.copyWith(proxyEnabled: v),
                                  );
                                },
                              ),
                            ),
                          ),
                          AnimatedCrossFade(
                            firstChild: const SizedBox.shrink(),
                            secondChild: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  row(
                                    l10n.providerDetailPageHostLabel,
                                    Focus(
                                      onFocusChange: (has) async {
                                        if (!has) {
                                          final v = proxyHostCtrl.text.trim();
                                          final old = spWatch.getProviderConfig(
                                            widget.providerKey,
                                            defaultName: widget.displayName,
                                          );
                                          await spWatch.setProviderConfig(
                                            widget.providerKey,
                                            old.copyWith(proxyHost: v),
                                          );
                                        }
                                      },
                                      child: TextField(
                                        controller: proxyHostCtrl,
                                        style: const TextStyle(fontSize: 13),
                                        decoration: _inputDecoration(
                                          ctx,
                                        ).copyWith(hintText: '127.0.0.1'),
                                        onChanged: (_) async {
                                          if (proxyHostCtrl
                                              .value
                                              .composing
                                              .isValid)
                                            return;
                                          final old = spWatch.getProviderConfig(
                                            widget.providerKey,
                                            defaultName: widget.displayName,
                                          );
                                          await spWatch.setProviderConfig(
                                            widget.providerKey,
                                            old.copyWith(
                                              proxyHost: proxyHostCtrl.text
                                                  .trim(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  row(
                                    l10n.providerDetailPagePortLabel,
                                    Focus(
                                      onFocusChange: (has) async {
                                        if (!has) {
                                          final v = proxyPortCtrl.text.trim();
                                          final old = spWatch.getProviderConfig(
                                            widget.providerKey,
                                            defaultName: widget.displayName,
                                          );
                                          await spWatch.setProviderConfig(
                                            widget.providerKey,
                                            old.copyWith(proxyPort: v),
                                          );
                                        }
                                      },
                                      child: TextField(
                                        controller: proxyPortCtrl,
                                        style: const TextStyle(fontSize: 13),
                                        decoration: _inputDecoration(
                                          ctx,
                                        ).copyWith(hintText: '8080'),
                                        onChanged: (_) async {
                                          if (proxyPortCtrl
                                              .value
                                              .composing
                                              .isValid)
                                            return;
                                          final old = spWatch.getProviderConfig(
                                            widget.providerKey,
                                            defaultName: widget.displayName,
                                          );
                                          await spWatch.setProviderConfig(
                                            widget.providerKey,
                                            old.copyWith(
                                              proxyPort: proxyPortCtrl.text
                                                  .trim(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  row(
                                    l10n.providerDetailPageUsernameOptionalLabel,
                                    Focus(
                                      onFocusChange: (has) async {
                                        if (!has) {
                                          final v = proxyUserCtrl.text.trim();
                                          final old = spWatch.getProviderConfig(
                                            widget.providerKey,
                                            defaultName: widget.displayName,
                                          );
                                          await spWatch.setProviderConfig(
                                            widget.providerKey,
                                            old.copyWith(proxyUsername: v),
                                          );
                                        }
                                      },
                                      child: TextField(
                                        controller: proxyUserCtrl,
                                        style: const TextStyle(fontSize: 13),
                                        decoration: _inputDecoration(ctx),
                                        onChanged: (_) async {
                                          if (proxyUserCtrl
                                              .value
                                              .composing
                                              .isValid)
                                            return;
                                          final old = spWatch.getProviderConfig(
                                            widget.providerKey,
                                            defaultName: widget.displayName,
                                          );
                                          await spWatch.setProviderConfig(
                                            widget.providerKey,
                                            old.copyWith(
                                              proxyUsername: proxyUserCtrl.text
                                                  .trim(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  row(
                                    l10n.providerDetailPagePasswordOptionalLabel,
                                    Focus(
                                      onFocusChange: (has) async {
                                        if (!has) {
                                          final v = proxyPassCtrl.text.trim();
                                          final old = spWatch.getProviderConfig(
                                            widget.providerKey,
                                            defaultName: widget.displayName,
                                          );
                                          await spWatch.setProviderConfig(
                                            widget.providerKey,
                                            old.copyWith(proxyPassword: v),
                                          );
                                        }
                                      },
                                      child: TextField(
                                        controller: proxyPassCtrl,
                                        style: const TextStyle(fontSize: 13),
                                        obscureText: true,
                                        decoration: _inputDecoration(ctx),
                                        onChanged: (_) async {
                                          if (proxyPassCtrl
                                              .value
                                              .composing
                                              .isValid)
                                            return;
                                          final old = spWatch.getProviderConfig(
                                            widget.providerKey,
                                            defaultName: widget.displayName,
                                          );
                                          await spWatch.setProviderConfig(
                                            widget.providerKey,
                                            old.copyWith(
                                              proxyPassword: proxyPassCtrl.text
                                                  .trim(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            crossFadeState: proxyEnabledNow
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                            duration: const Duration(milliseconds: 180),
                            sizeCurve: Curves.easeOutCubic,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _inputProviderAvatarUrl(
    BuildContext context,
    String providerKey,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        bool valid(String s) =>
            s.trim().startsWith('http://') || s.trim().startsWith('https://');
        String value = '';
        return StatefulBuilder(
          builder: (ctx2, setLocal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: cs.surface,
              title: Text(l10n.sideDrawerImageUrlDialogTitle),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.sideDrawerImageUrlDialogHint,
                  filled: true,
                  fillColor: Theme.of(ctx2).brightness == Brightness.dark
                      ? Colors.white10
                      : const Color(0xFFF2F3F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.transparent),
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: Colors.transparent),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.primary.withOpacity(0.4)),
                  ),
                ),
                onChanged: (v) => setLocal(() => value = v),
                onSubmitted: (_) {
                  if (valid(value)) Navigator.of(ctx2).pop(true);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(l10n.sideDrawerCancel),
                ),
                TextButton(
                  onPressed: valid(value)
                      ? () => Navigator.of(ctx).pop(true)
                      : null,
                  child: Text(
                    l10n.sideDrawerSave,
                    style: TextStyle(
                      color: valid(value)
                          ? cs.primary
                          : cs.onSurface.withOpacity(0.38),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    if (ok == true) {
      final url = controller.text.trim();
      if (url.isNotEmpty) {
        await context.read<SettingsProvider>().setProviderAvatarUrl(
          providerKey,
          url,
        );
      }
    }
  }

  bool _isAihubmix(ProviderConfig cfg) {
    final base = cfg.baseUrl.toLowerCase();
    final key = cfg.id.toLowerCase();
    return key.contains('aihubmix') || base.contains('aihubmix.com');
  }

  Future<void> _showNetworkDialog(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final sp = context.read<SettingsProvider>();
    final cfg = sp.getProviderConfig(
      widget.providerKey,
      defaultName: widget.displayName,
    );
    bool enabled = cfg.proxyEnabled ?? false;
    final host = TextEditingController(text: cfg.proxyHost ?? '');
    final port = TextEditingController(text: cfg.proxyPort ?? '8080');
    final user = TextEditingController(text: cfg.proxyUsername ?? '');
    final pass = TextEditingController(text: cfg.proxyPassword ?? '');
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: StatefulBuilder(
            builder: (ctx, setSt) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 44,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              AppLocalizations.of(
                                ctx,
                              )!.providerDetailPageNetworkTab,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(lucide.Lucide.X, size: 18),
                            color: cs.onSurface,
                            onPressed: () => Navigator.of(ctx).maybePop(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Divider(
                      height: 1,
                      thickness: 0.5,
                      color: cs.outlineVariant.withOpacity(0.12),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _rowSwitch(
                          ctx,
                          label: AppLocalizations.of(
                            ctx,
                          )!.providerDetailPageEnableProxyTitle,
                          value: enabled,
                          onChanged: (v) async {
                            setSt(() => enabled = v);
                            final old = sp.getProviderConfig(
                              widget.providerKey,
                              defaultName: widget.displayName,
                            );
                            await sp.setProviderConfig(
                              widget.providerKey,
                              old.copyWith(proxyEnabled: v),
                            );
                          },
                        ),
                        AnimatedCrossFade(
                          firstChild: const SizedBox.shrink(),
                          secondChild: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 12),
                              _sectionLabel(
                                ctx,
                                AppLocalizations.of(
                                  ctx,
                                )!.providerDetailPageHostLabel,
                              ),
                              const SizedBox(height: 6),
                              Focus(
                                onFocusChange: (has) async {
                                  if (!has) {
                                    final v = host.text.trim();
                                    final old = sp.getProviderConfig(
                                      widget.providerKey,
                                      defaultName: widget.displayName,
                                    );
                                    await sp.setProviderConfig(
                                      widget.providerKey,
                                      old.copyWith(proxyHost: v),
                                    );
                                  }
                                },
                                child: TextField(
                                  controller: host,
                                  style: const TextStyle(fontSize: 13),
                                  decoration: _inputDecoration(
                                    ctx,
                                  ).copyWith(hintText: '127.0.0.1'),
                                  onChanged: (_) async {
                                    final old = sp.getProviderConfig(
                                      widget.providerKey,
                                      defaultName: widget.displayName,
                                    );
                                    await sp.setProviderConfig(
                                      widget.providerKey,
                                      old.copyWith(proxyHost: host.text.trim()),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              _sectionLabel(
                                ctx,
                                AppLocalizations.of(
                                  ctx,
                                )!.providerDetailPagePortLabel,
                              ),
                              const SizedBox(height: 6),
                              Focus(
                                onFocusChange: (has) async {
                                  if (!has) {
                                    final v = port.text.trim();
                                    final old = sp.getProviderConfig(
                                      widget.providerKey,
                                      defaultName: widget.displayName,
                                    );
                                    await sp.setProviderConfig(
                                      widget.providerKey,
                                      old.copyWith(proxyPort: v),
                                    );
                                  }
                                },
                                child: TextField(
                                  controller: port,
                                  style: const TextStyle(fontSize: 13),
                                  decoration: _inputDecoration(
                                    ctx,
                                  ).copyWith(hintText: '8080'),
                                  onChanged: (_) async {
                                    final old = sp.getProviderConfig(
                                      widget.providerKey,
                                      defaultName: widget.displayName,
                                    );
                                    await sp.setProviderConfig(
                                      widget.providerKey,
                                      old.copyWith(proxyPort: port.text.trim()),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              _sectionLabel(
                                ctx,
                                AppLocalizations.of(
                                  ctx,
                                )!.providerDetailPageUsernameOptionalLabel,
                              ),
                              const SizedBox(height: 6),
                              Focus(
                                onFocusChange: (has) async {
                                  if (!has) {
                                    final v = user.text.trim();
                                    final old = sp.getProviderConfig(
                                      widget.providerKey,
                                      defaultName: widget.displayName,
                                    );
                                    await sp.setProviderConfig(
                                      widget.providerKey,
                                      old.copyWith(proxyUsername: v),
                                    );
                                  }
                                },
                                child: TextField(
                                  controller: user,
                                  style: const TextStyle(fontSize: 13),
                                  decoration: _inputDecoration(ctx),
                                  onChanged: (_) async {
                                    final old = sp.getProviderConfig(
                                      widget.providerKey,
                                      defaultName: widget.displayName,
                                    );
                                    await sp.setProviderConfig(
                                      widget.providerKey,
                                      old.copyWith(
                                        proxyUsername: user.text.trim(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              _sectionLabel(
                                ctx,
                                AppLocalizations.of(
                                  ctx,
                                )!.providerDetailPagePasswordOptionalLabel,
                              ),
                              const SizedBox(height: 6),
                              Focus(
                                onFocusChange: (has) async {
                                  if (!has) {
                                    final v = pass.text.trim();
                                    final old = sp.getProviderConfig(
                                      widget.providerKey,
                                      defaultName: widget.displayName,
                                    );
                                    await sp.setProviderConfig(
                                      widget.providerKey,
                                      old.copyWith(proxyPassword: v),
                                    );
                                  }
                                },
                                child: TextField(
                                  controller: pass,
                                  style: const TextStyle(fontSize: 13),
                                  obscureText: true,
                                  decoration: _inputDecoration(ctx),
                                  onChanged: (_) async {
                                    final old = sp.getProviderConfig(
                                      widget.providerKey,
                                      defaultName: widget.displayName,
                                    );
                                    await sp.setProviderConfig(
                                      widget.providerKey,
                                      old.copyWith(
                                        proxyPassword: pass.text.trim(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          crossFadeState: enabled
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 180),
                          sizeCurve: Curves.easeOutCubic,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showMultiKeyDialog(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final sp = context.read<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        ProviderConfig cfg = sp.getProviderConfig(
          widget.providerKey,
          defaultName: widget.displayName,
        );
        LoadBalanceStrategy strat =
            cfg.keyManagement?.strategy ?? LoadBalanceStrategy.roundRobin;
        final keys = List<ApiKeyConfig>.from(
          cfg.apiKeys ?? const <ApiKeyConfig>[],
        );
        final listCtrl = ScrollController();
        Future<void> saveStrategy(LoadBalanceStrategy s) async {
          final old = sp.getProviderConfig(
            widget.providerKey,
            defaultName: widget.displayName,
          );
          final km = (old.keyManagement ?? const KeyManagementConfig())
              .copyWith(strategy: s);
          await sp.setProviderConfig(
            widget.providerKey,
            old.copyWith(keyManagement: km),
          );
        }

        // addKeys defined below after detection helpers
        // Persisted state across inner StatefulBuilder rebuilds
        String? detectModelId;
        bool detecting = false;
        String? testingKeyId;
        StateSetter? _setDRef;

        Future<void> _pickDetectModel(BuildContext dctx) async {
          final sel = await showModelSelector(
            dctx,
            limitProviderKey: widget.providerKey,
          );
          if (sel != null) {
            detectModelId = sel.modelId;
            _setDRef?.call(() {});
          }
        }

        Future<void> _testSingleKey(
          ProviderConfig baseCfg,
          String modelId,
          ApiKeyConfig key,
        ) async {
          // Force using the specific key by disabling multi-key selection
          final cfg2 = baseCfg.copyWith(
            apiKey: key.key,
            multiKeyEnabled: false,
            apiKeys: const [],
          );
          await ProviderManager.testConnection(cfg2, modelId);
        }

        Future<void> _testKeysAndSave(
          BuildContext dctx,
          List<ApiKeyConfig> fullList,
          List<ApiKeyConfig> toTest,
          String modelId,
        ) async {
          final settings = dctx.read<SettingsProvider>();
          final base = settings.getProviderConfig(
            widget.providerKey,
            defaultName: widget.displayName,
          );
          final out = List<ApiKeyConfig>.from(fullList);
          for (int i = 0; i < toTest.length; i++) {
            final k = toTest[i];
            bool ok = true;
            try {
              await _testSingleKey(base, modelId, k);
            } catch (_) {
              ok = false;
            }
            final idx = out.indexWhere((e) => e.id == k.id);
            if (idx >= 0)
              out[idx] = k.copyWith(
                status: ok ? ApiKeyStatus.active : ApiKeyStatus.error,
                usage: k.usage.copyWith(
                  totalRequests: k.usage.totalRequests + 1,
                  successfulRequests: k.usage.successfulRequests + (ok ? 1 : 0),
                  failedRequests: k.usage.failedRequests + (ok ? 0 : 1),
                  consecutiveFailures: ok
                      ? 0
                      : (k.usage.consecutiveFailures + 1),
                  lastUsed: DateTime.now().millisecondsSinceEpoch,
                ),
                lastError: ok ? null : 'Test failed',
                updatedAt: DateTime.now().millisecondsSinceEpoch,
              );
            await Future.delayed(const Duration(milliseconds: 120));
          }
          await settings.setProviderConfig(
            widget.providerKey,
            base.copyWith(apiKeys: out),
          );
        }

        Future<void> _detectAll(BuildContext dctx) async {
          if (detecting) return;
          final settings = dctx.read<SettingsProvider>();
          final cfgX = settings.getProviderConfig(
            widget.providerKey,
            defaultName: widget.displayName,
          );
          final models = cfgX.models;
          if (detectModelId == null) {
            if (models.isEmpty) {
              showAppSnackBar(
                dctx,
                message: AppLocalizations.of(dctx)!.multiKeyPagePleaseAddModel,
                type: NotificationType.warning,
              );
              return;
            }
            detectModelId = models.first;
          }
          detecting = true;
          _setDRef?.call(() {});
          try {
            final list = List<ApiKeyConfig>.from(
              cfgX.apiKeys ?? const <ApiKeyConfig>[],
            );
            await _testKeysAndSave(dctx, list, list, detectModelId!);
          } finally {
            detecting = false;
            _setDRef?.call(() {});
          }
        }

        Future<void> _detectOnly(BuildContext dctx, List<String> keys) async {
          final settings = dctx.read<SettingsProvider>();
          final cfgX = settings.getProviderConfig(
            widget.providerKey,
            defaultName: widget.displayName,
          );
          final models = cfgX.models;
          if (detectModelId == null) {
            if (models.isEmpty) {
              showAppSnackBar(
                dctx,
                message: AppLocalizations.of(dctx)!.multiKeyPagePleaseAddModel,
                type: NotificationType.warning,
              );
              return;
            }
            detectModelId = models.first;
          }
          final list = List<ApiKeyConfig>.from(
            cfgX.apiKeys ?? const <ApiKeyConfig>[],
          );
          final toTest = list.where((e) => keys.contains(e.key)).toList();
          await _testKeysAndSave(dctx, list, toTest, detectModelId!);
        }

        Future<void> _detectOne(BuildContext dctx, ApiKeyConfig key) async {
          if (detecting || testingKeyId != null) return;
          final settings = dctx.read<SettingsProvider>();
          final cfgX = settings.getProviderConfig(
            widget.providerKey,
            defaultName: widget.displayName,
          );
          final models = cfgX.models;
          if (detectModelId == null) {
            if (models.isEmpty) {
              showAppSnackBar(
                dctx,
                message: AppLocalizations.of(dctx)!.multiKeyPagePleaseAddModel,
                type: NotificationType.warning,
              );
              return;
            }
            detectModelId = models.first;
          }
          testingKeyId = key.id;
          _setDRef?.call(() {});
          try {
            final list = List<ApiKeyConfig>.from(
              cfgX.apiKeys ?? const <ApiKeyConfig>[],
            );
            final toTest = list.where((e) => e.id == key.id).toList();
            await _testKeysAndSave(dctx, list, toTest, detectModelId!);
          } finally {
            testingKeyId = null;
            _setDRef?.call(() {});
          }
        }

        Future<void> _deleteAllErrorKeys(BuildContext dctx) async {
          final settings = dctx.read<SettingsProvider>();
          final cfgX = settings.getProviderConfig(
            widget.providerKey,
            defaultName: widget.displayName,
          );
          final keys = List<ApiKeyConfig>.from(
            cfgX.apiKeys ?? const <ApiKeyConfig>[],
          );
          final errorKeys = keys
              .where((e) => e.status == ApiKeyStatus.error)
              .toList();
          if (errorKeys.isEmpty) return;
          final l10nX = AppLocalizations.of(dctx)!;
          final csX = Theme.of(dctx).colorScheme;
          final ok = await showDialog<bool>(
            context: dctx,
            builder: (ctx2) => AlertDialog(
              title: Text(l10nX.multiKeyPageDeleteErrorsConfirmTitle),
              content: Text(l10nX.multiKeyPageDeleteErrorsConfirmContent),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx2).pop(false),
                  child: Text(l10nX.multiKeyPageCancel),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx2).pop(true),
                  style: TextButton.styleFrom(foregroundColor: csX.error),
                  child: Text(l10nX.multiKeyPageDelete),
                ),
              ],
            ),
          );
          if (ok != true) return;
          final remain = keys
              .where((e) => e.status != ApiKeyStatus.error)
              .toList();
          await settings.setProviderConfig(
            widget.providerKey,
            cfgX.copyWith(apiKeys: remain),
          );
          showAppSnackBar(
            dctx,
            message: l10nX.multiKeyPageDeletedErrorsSnackbar(errorKeys.length),
            type: NotificationType.success,
          );
          _setDRef?.call(() {});
        }

        Future<ApiKeyConfig?> _showEditKeyDialog(
          BuildContext dctx,
          ApiKeyConfig k,
        ) async {
          final cs2 = Theme.of(dctx).colorScheme;
          final l10n2 = AppLocalizations.of(dctx)!;
          final aliasCtrl = TextEditingController(text: k.name ?? '');
          final keyCtrl = TextEditingController(text: k.key);
          final priCtrl = TextEditingController(text: k.priority.toString());
          final res = await showDialog<ApiKeyConfig?>(
            context: dctx,
            barrierDismissible: true,
            builder: (c2) => Dialog(
              backgroundColor: cs2.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: StatefulBuilder(
                  builder: (cc, setCC) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 44,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    l10n2.multiKeyPageEdit,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                _IconBtn(
                                  icon: lucide.Lucide.X,
                                  onTap: () => Navigator.of(c2).maybePop(),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Divider(
                          height: 1,
                          thickness: 0.5,
                          color: cs2.outlineVariant.withOpacity(0.12),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _sectionLabel(cc, l10n2.multiKeyPageAlias),
                              const SizedBox(height: 6),
                              TextField(
                                controller: aliasCtrl,
                                style: const TextStyle(fontSize: 13),
                                decoration: _inputDecoration(cc),
                              ),
                              const SizedBox(height: 12),
                              _sectionLabel(cc, l10n2.multiKeyPageKey),
                              const SizedBox(height: 6),
                              TextField(
                                controller: keyCtrl,
                                style: const TextStyle(fontSize: 13),
                                decoration: _inputDecoration(cc),
                              ),
                              const SizedBox(height: 12),
                              _sectionLabel(cc, l10n2.multiKeyPagePriority),
                              const SizedBox(height: 6),
                              TextField(
                                controller: priCtrl,
                                style: const TextStyle(fontSize: 13),
                                decoration: _inputDecoration(
                                  cc,
                                ).copyWith(hintText: '1-10'),
                              ),
                              const SizedBox(height: 14),
                              Align(
                                alignment: Alignment.centerRight,
                                child: _DeskIosButton(
                                  label: l10n2.multiKeyPageEdit,
                                  filled: true,
                                  onTap: () {
                                    final p =
                                        int.tryParse(priCtrl.text.trim()) ??
                                        k.priority;
                                    final clamped = p.clamp(1, 10) as int;
                                    Navigator.of(c2).pop(
                                      k.copyWith(
                                        name: aliasCtrl.text.trim().isEmpty
                                            ? null
                                            : aliasCtrl.text.trim(),
                                        key: keyCtrl.text.trim(),
                                        priority: clamped,
                                        updatedAt: DateTime.now()
                                            .millisecondsSinceEpoch,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
          return res;
        }

        // Define addKeys now that helpers are in scope
        Future<void> addKeys(BuildContext c) async {
          final text = await _inputDialog(
            c,
            title: l10n.multiKeyPageAdd,
            hint: l10n.multiKeyPageAddHint,
          );
          if (text == null || text.trim().isEmpty) return;
          final parts = text
              .split(RegExp(r'[\s,]+'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
          if (parts.isEmpty) return;
          final existing =
              sp
                  .getProviderConfig(
                    widget.providerKey,
                    defaultName: widget.displayName,
                  )
                  .apiKeys ??
              const <ApiKeyConfig>[];
          final existingSet = existing.map((e) => e.key.trim()).toSet();
          final list = List<ApiKeyConfig>.from(existing);
          final uniqueAdded = <String>[];
          for (final k in parts) {
            if (!existingSet.contains(k)) {
              list.add(ApiKeyConfig.create(k));
              uniqueAdded.add(k);
            }
          }
          final old = sp.getProviderConfig(
            widget.providerKey,
            defaultName: widget.displayName,
          );
          await sp.setProviderConfig(
            widget.providerKey,
            old.copyWith(apiKeys: list, multiKeyEnabled: true),
          );
          if (uniqueAdded.isNotEmpty) {
            showAppSnackBar(
              c,
              message: l10n.multiKeyPageImportedSnackbar(uniqueAdded.length),
              type: NotificationType.success,
            );
            await _detectOnly(c, uniqueAdded);
          } else {
            showAppSnackBar(c, message: l10n.multiKeyPageImportedSnackbar(0));
          }
        }

        return Dialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 620),
            child: StatefulBuilder(
              builder: (dctx, setD) {
                _setDRef = setD;
                ProviderConfig cfg2 = sp.getProviderConfig(
                  widget.providerKey,
                  defaultName: widget.displayName,
                );
                final keyList = List<ApiKeyConfig>.from(
                  cfg2.apiKeys ?? const <ApiKeyConfig>[],
                );
                final currentStrat =
                    cfg2.keyManagement?.strategy ??
                    LoadBalanceStrategy.roundRobin;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 44,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.multiKeyPageTitle,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            // Delete all error keys
                            Tooltip(
                              message: l10n.multiKeyPageDeleteErrorsTooltip,
                              child: _IconBtn(
                                icon: lucide.Lucide.Trash2,
                                onTap: () => _deleteAllErrorKeys(dctx),
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Detect / test all keys
                            if (detecting)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: cs.primary,
                                  ),
                                ),
                              )
                            else
                              Tooltip(
                                message: l10n.multiKeyPageDetect,
                                child: _IconBtn(
                                  icon: lucide.Lucide.HeartPulse,
                                  onTap: () => _detectAll(dctx),
                                  onLongPress: () => _pickDetectModel(dctx),
                                ),
                              ),
                            const SizedBox(width: 6),
                            _IconBtn(
                              icon: lucide.Lucide.X,
                              onTap: () => Navigator.of(ctx).maybePop(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: cs.outlineVariant.withOpacity(0.12),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.multiKeyPageStrategyTitle,
                              style: TextStyle(
                                fontSize: 14,
                                color: cs.onSurface.withOpacity(0.9),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: _StrategyDropdown(
                              value: currentStrat,
                              onChanged: (s) async {
                                await saveStrategy(s);
                                setD(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Scrollbar(
                        thumbVisibility: true,
                        controller: listCtrl,
                        child: ListView(
                          controller: listCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          children: [
                            _DesktopIosSectionCard(
                              children: [
                                if (keyList.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    child: Center(
                                      child: Text(
                                        AppLocalizations.of(
                                          context,
                                        )!.multiKeyPageNoKeys,
                                      ),
                                    ),
                                  )
                                else
                                  for (int i = 0; i < keyList.length; i++)
                                    _DesktopKeyRow(
                                      keyConfig: keyList[i],
                                      showDivider: false,
                                      onToggle: (v) async {
                                        final old = sp.getProviderConfig(
                                          widget.providerKey,
                                          defaultName: widget.displayName,
                                        );
                                        final list = List<ApiKeyConfig>.from(
                                          old.apiKeys ?? const <ApiKeyConfig>[],
                                        );
                                        final idx = list.indexWhere(
                                          (e) => e.id == keyList[i].id,
                                        );
                                        if (idx >= 0)
                                          list[idx] = keyList[i].copyWith(
                                            isEnabled: v,
                                            updatedAt: DateTime.now()
                                                .millisecondsSinceEpoch,
                                          );
                                        await sp.setProviderConfig(
                                          widget.providerKey,
                                          old.copyWith(apiKeys: list),
                                        );
                                        setD(() {});
                                      },
                                      onEdit: () async {
                                        final updated =
                                            await _showEditKeyDialog(
                                              dctx,
                                              keyList[i],
                                            );
                                        if (updated == null) return;
                                        // Prevent duplicate keys
                                        final latest = sp.getProviderConfig(
                                          widget.providerKey,
                                          defaultName: widget.displayName,
                                        );
                                        final list = List<ApiKeyConfig>.from(
                                          latest.apiKeys ??
                                              const <ApiKeyConfig>[],
                                        );
                                        final dup = list.any(
                                          (e) =>
                                              e.id != keyList[i].id &&
                                              e.key.trim() ==
                                                  updated.key.trim(),
                                        );
                                        if (dup) {
                                          showAppSnackBar(
                                            dctx,
                                            message: AppLocalizations.of(
                                              dctx,
                                            )!.multiKeyPageDuplicateKeyWarning,
                                            type: NotificationType.warning,
                                          );
                                          return;
                                        }
                                        final idx = list.indexWhere(
                                          (e) => e.id == keyList[i].id,
                                        );
                                        if (idx >= 0) list[idx] = updated;
                                        await sp.setProviderConfig(
                                          widget.providerKey,
                                          latest.copyWith(apiKeys: list),
                                        );
                                        setD(() {});
                                      },
                                      onTest: () =>
                                          _detectOne(dctx, keyList[i]),
                                      testing: testingKeyId == keyList[i].id,
                                      onDelete: () async {
                                        final old = sp.getProviderConfig(
                                          widget.providerKey,
                                          defaultName: widget.displayName,
                                        );
                                        final list = List<ApiKeyConfig>.from(
                                          old.apiKeys ?? const <ApiKeyConfig>[],
                                        );
                                        final idx = list.indexWhere(
                                          (e) => e.id == keyList[i].id,
                                        );
                                        if (idx >= 0) {
                                          list.removeAt(idx);
                                          await sp.setProviderConfig(
                                            widget.providerKey,
                                            old.copyWith(apiKeys: list),
                                          );
                                          setD(() {});
                                        }
                                      },
                                    ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _DeskIosButton(
                            label: l10n.multiKeyPageAdd,
                            filled: false,
                            onTap: () => addKeys(dctx),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  // Replaced with desktop centered dialog: showModelFetchDialog

  // Future<void> _showGetModelsDialog(BuildContext context) async {
  //   // For now this acts similar to Detect, but kept separate per spec.
  //   return _showDetectModelsDialog(context);
  // }

  Future<void> _createModel(BuildContext context) async {
    final res = await showDesktopCreateModelDialog(
      context,
      providerKey: widget.providerKey,
    );
    if (res == true && mounted) setState(() {});
  }

  Future<void> _showTestConnectionDialog(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    String? selectedModelId;
    _TestState state = _TestState.idle;
    String errorMessage = '';
    bool useStream = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        Future<void> pickModel() async {
          // Use the desktop model selector dialog and limit to current provider
          final sel = await showModelSelector(
            ctx,
            limitProviderKey: widget.providerKey,
          );
          if (sel != null) {
            selectedModelId = sel.modelId;
            (ctx as Element).markNeedsBuild();
          }
        }

        Future<void> doTest() async {
          if (selectedModelId == null) return;
          state = _TestState.loading;
          errorMessage = '';
          (ctx as Element).markNeedsBuild();
          try {
            final sp = context.read<SettingsProvider>();
            final cfg = sp.getProviderConfig(
              widget.providerKey,
              defaultName: widget.displayName,
            );
            await ProviderManager.testConnection(
              cfg,
              selectedModelId!,
              useStream: useStream,
            );
            state = _TestState.success;
          } catch (e) {
            state = _TestState.error;
            errorMessage = e.toString();
          }
          (ctx as Element).markNeedsBuild();
        }

        final l10n = AppLocalizations.of(ctx)!;
        final canTest = selectedModelId != null && state != _TestState.loading;
        String message;
        Color color;
        switch (state) {
          case _TestState.idle:
            message = selectedModelId == null
                ? l10n.modelSelectSheetSearchHint
                : l10n.providerDetailPageTestingMessage;
            color = cs.onSurface.withOpacity(0.8);
            break;
          case _TestState.loading:
            message = l10n.providerDetailPageTestingMessage;
            color = cs.primary;
            break;
          case _TestState.success:
            message = l10n.providerDetailPageTestSuccessMessage;
            color = Colors.green;
            break;
          case _TestState.error:
            message = errorMessage.isNotEmpty ? errorMessage : 'Error';
            color = cs.error;
            break;
        }
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Dialog(
              backgroundColor: cs.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Text(
                          l10n.providerDetailPageTestConnectionTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: pickModel,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(ctx).brightness == Brightness.dark
                                ? Colors.white10
                                : const Color(0xFFF7F7F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: cs.outlineVariant.withOpacity(0.12),
                              width: 0.6,
                            ),
                          ),
                          child: Row(
                            children: [
                              if (selectedModelId != null)
                                _BrandCircle(name: selectedModelId!, size: 22),
                              if (selectedModelId != null)
                                const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  selectedModelId ??
                                      l10n.providerDetailPageSelectModelButton,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.providerDetailPageUseStreamingLabel,
                              style: TextStyle(
                                fontSize: 14,
                                color: cs.onSurface.withOpacity(0.9),
                              ),
                            ),
                          ),
                          IosSwitch(
                            value: useStream,
                            onChanged: (v) => setState(() => useStream = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (state == _TestState.loading)
                        Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.primary,
                            ),
                          ),
                        )
                      else if (state != _TestState.idle)
                        Center(
                          child: Text(
                            message,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: color,
                              fontSize: 14,
                              fontWeight: state == _TestState.success
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _DeskIosButton(
                            label: l10n.providerDetailPageCancelButton,
                            filled: false,
                            dense: true,
                            onTap: () => Navigator.of(ctx).maybePop(),
                          ),
                          const SizedBox(width: 8),
                          _DeskIosButton(
                            label: l10n.providerDetailPageTestButton,
                            filled: true,
                            dense: true,
                            onTap: canTest ? doTest : () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _enterSelectionMode() {
    setState(() {
      _isSelectionMode = true;
      _selectedModels.clear();
      _detectionResults.clear();
      _detectionErrorMessages.clear();
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedModels.clear();
      _detectionResults.clear();
      _detectionErrorMessages.clear();
    });
  }

  Future<void> _confirmDeleteAllModels() async {
    final sp = context.read<SettingsProvider>();
    final cfg = sp.getProviderConfig(
      widget.providerKey,
      defaultName: widget.displayName,
    );
    if (cfg.models.isEmpty) return;
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.providerDetailPageConfirmDeleteTitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _IconBtn(
                      icon: lucide.Lucide.X,
                      onTap: () => Navigator.of(ctx).maybePop(false),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 0.5,
                color: cs.outlineVariant.withOpacity(0.12),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.providerDetailPageDeleteAllModelsWarning,
                    style: TextStyle(color: cs.onSurface.withOpacity(0.85)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _DeskIosButton(
                      label: l10n.providerDetailPageCancelButton,
                      filled: false,
                      dense: true,
                      onTap: () => Navigator.of(ctx).maybePop(false),
                    ),
                    const SizedBox(width: 8),
                    _DeskIosButton(
                      label: l10n.providerDetailPageDeleteButton,
                      filled: true,
                      dense: true,
                      onTap: () => Navigator.of(ctx).maybePop(true),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    final cleared = cfg.copyWith(models: const [], modelOverrides: const {});
    await sp.setProviderConfig(widget.providerKey, cleared);
    if (!mounted) return;
    setState(() {
      _selectedModels.clear();
      _detectionResults.clear();
      _detectionErrorMessages.clear();
      _pendingModels.clear();
      _currentDetectingModel = null;
      _isSelectionMode = false;
    });
  }

  Future<void> _startDetection() async {
    if (_selectedModels.isEmpty || _isDetecting) return;

    final modelsToTest = Set<String>.from(_selectedModels);

    setState(() {
      _isDetecting = true;
      _detectionResults.clear();
      _detectionErrorMessages.clear();
      _isSelectionMode = false;
      _selectedModels.clear();
      _pendingModels.clear();
      _pendingModels.addAll(modelsToTest);
      _currentDetectingModel = null;
    });

    final sp = context.read<SettingsProvider>();
    final cfg = sp.getProviderConfig(
      widget.providerKey,
      defaultName: widget.displayName,
    );

    for (final modelId in modelsToTest) {
      if (mounted) {
        setState(() {
          _currentDetectingModel = modelId;
          _pendingModels.remove(modelId);
        });
      }

      try {
        await ProviderManager.testConnection(
          cfg,
          modelId,
          useStream: _detectUseStream,
        );
        if (mounted) {
          setState(() {
            _detectionResults[modelId] = true;
            _detectionErrorMessages.remove(modelId);
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _detectionResults[modelId] = false;
            _detectionErrorMessages[modelId] = e.toString();
          });
        }
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (mounted) {
      setState(() {
        _isDetecting = false;
        _currentDetectingModel = null;
        _pendingModels.clear();
      });
    }
  }
}

enum _TestState { idle, loading, success, error }

class _ProviderTypeDropdown extends StatefulWidget {
  const _ProviderTypeDropdown({required this.value, required this.onChanged});
  final ProviderKind value;
  final ValueChanged<ProviderKind> onChanged;
  @override
  State<_ProviderTypeDropdown> createState() => _ProviderTypeDropdownState();
}

class _ProviderTypeDropdownState extends State<_ProviderTypeDropdown> {
  bool _hover = false;
  bool _open = false;
  final GlobalKey _key = GlobalKey();
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  void _close() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() => _open = false);
  }

  void _openMenu() {
    if (_entry != null) return;
    final rb = _key.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(context)?.context.findRenderObject() as RenderBox?;
    if (rb == null || overlayBox == null) return;
    final size = rb.size;
    final triggerW = size.width;
    const maxW = 280.0; // unused after width sync, kept for reference
    final items = const [
      (ProviderKind.openai, 'OpenAI'),
      (ProviderKind.google, 'Google'),
      (ProviderKind.claude, 'Claude'),
    ];
    _entry = OverlayEntry(
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final content = Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color:
                  (Provider.of<SettingsProvider>(
                    ctx,
                    listen: false,
                  ).usePureBackground)
                  ? (isDark ? Colors.black : Colors.white)
                  : (isDark ? const Color(0xFF1C1C1E) : Colors.white),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cs.outlineVariant.withOpacity(0.12),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 2),
              itemBuilder: (c, i) {
                final k = items[i].$1;
                final label = items[i].$2;
                final selected = widget.value == k;
                return _OverlayMenuItem(
                  label: label,
                  selected: selected,
                  onTap: () {
                    widget.onChanged(k);
                    _close();
                  },
                );
              },
            ),
          ),
        );
        final width = triggerW; // menu width equals trigger width
        final dx = 0.0; // align left edges
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _close,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              offset: Offset(dx, size.height + 6),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: width, maxWidth: width),
                child: content,
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context)?.insert(_entry!);
    setState(() => _open = true);
  }

  @override
  Widget build(BuildContext context) {
    final label = switch (widget.value) {
      ProviderKind.openai => 'OpenAI',
      ProviderKind.google => 'Google',
      ProviderKind.claude => 'Claude',
    };
    return CompositedTransformTarget(
      link: _link,
      child: _HoverDropdownButton(
        key: _key,
        hovered: _hover,
        open: _open,
        label: label,
        fontSize: 14,
        verticalPadding: 10,
        borderRadius: 10,
        rightAlignArrow: true,
        onHover: (v) => setState(() => _hover = v),
        onTap: () => _open ? _close() : _openMenu(),
      ),
    );
  }
}

class _StrategyDropdown extends StatefulWidget {
  const _StrategyDropdown({required this.value, required this.onChanged});
  final LoadBalanceStrategy value;
  final ValueChanged<LoadBalanceStrategy> onChanged;
  @override
  State<_StrategyDropdown> createState() => _StrategyDropdownState();
}

class _StrategyDropdownState extends State<_StrategyDropdown> {
  bool _hover = false;
  bool _open = false;
  final GlobalKey _key = GlobalKey();
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  void _close() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() => _open = false);
  }

  void _openMenu() {
    if (_entry != null) return;
    final rb = _key.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return;
    final size = rb.size;
    final triggerW = size.width;
    final labelFor = (LoadBalanceStrategy s) =>
        s == LoadBalanceStrategy.roundRobin
        ? AppLocalizations.of(context)!.multiKeyPageStrategyRoundRobin
        : AppLocalizations.of(context)!.multiKeyPageStrategyRandom;
    final entries = [
      LoadBalanceStrategy.roundRobin,
      LoadBalanceStrategy.random,
    ];
    _entry = OverlayEntry(
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _close,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 6),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: BoxConstraints(
                    minWidth: triggerW,
                    maxWidth: triggerW,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (Provider.of<SettingsProvider>(
                          ctx,
                          listen: false,
                        ).usePureBackground)
                        ? (isDark ? Colors.black : Colors.white)
                        : (isDark ? const Color(0xFF1C1C1E) : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cs.outlineVariant.withOpacity(0.12),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    shrinkWrap: true,
                    itemCount: entries.length,
                    itemBuilder: (c, i) {
                      final s = entries[i];
                      final selected = widget.value == s;
                      return _OverlayMenuItem(
                        label: labelFor(s),
                        selected: selected,
                        onTap: () {
                          widget.onChanged(s);
                          _close();
                        },
                      );
                    },
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

  @override
  Widget build(BuildContext context) {
    final label = widget.value == LoadBalanceStrategy.roundRobin
        ? AppLocalizations.of(context)!.multiKeyPageStrategyRoundRobin
        : AppLocalizations.of(context)!.multiKeyPageStrategyRandom;
    return CompositedTransformTarget(
      link: _link,
      child: _HoverDropdownButton(
        key: _key,
        hovered: _hover,
        open: _open,
        label: label,
        fontSize: 14,
        verticalPadding: 10,
        borderRadius: 10,
        rightAlignArrow: true,
        onHover: (v) => setState(() => _hover = v),
        onTap: () => _open ? _close() : _openMenu(),
      ),
    );
  }
}

Widget _rowSwitch(
  BuildContext context, {
  required String label,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  final cs = Theme.of(context).colorScheme;
  return Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: cs.onSurface.withOpacity(0.9),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      IosSwitch(value: value, onChanged: onChanged),
    ],
  );
}

Widget _rowButton(
  BuildContext context, {
  required String label,
  required VoidCallback onTap,
}) {
  final cs = Theme.of(context).colorScheme;
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface.withOpacity(0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Icon(lucide.Lucide.ChevronRight, size: 16),
        ],
      ),
    ),
  );
}

// Small, consistent section label used in providers pane dialogs
Widget _sectionLabel(BuildContext context, String text, {bool bold = false}) {
  final cs = Theme.of(context).colorScheme;
  return Text(
    text,
    style: TextStyle(
      fontSize: 13,
      color: cs.onSurface.withOpacity(0.8),
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
    ),
  );
}

class _GreyCapsule extends StatelessWidget {
  const _GreyCapsule({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? Colors.white.withOpacity(0.06)
        : const Color(0xFFF2F3F5);
    final fg = Theme.of(context).colorScheme.onSurface.withOpacity(0.85);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _IconBtn extends StatefulWidget {
  const _IconBtn({
    super.key,
    required this.icon,
    required this.onTap,
    this.onLongPress,
    this.color,
  });
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
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
        onLongPress: widget.onLongPress,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: 18,
            color: widget.color ?? cs.onSurface,
          ),
        ),
      ),
    );
  }
}

class _IconTextBtn extends StatefulWidget {
  const _IconTextBtn({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  @override
  State<_IconTextBtn> createState() => _IconTextBtnState();
}

class _IconTextBtnState extends State<_IconTextBtn> {
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
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16, color: widget.color ?? cs.onSurface),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  color: widget.color ?? cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopProviderGroupsDialog extends StatefulWidget {
  const _DesktopProviderGroupsDialog();

  @override
  State<_DesktopProviderGroupsDialog> createState() =>
      _DesktopProviderGroupsDialogState();
}

class _DesktopProviderGroupsDialogState
    extends State<_DesktopProviderGroupsDialog> {
  Future<String?> _promptName(
    BuildContext context, {
    required String title,
    String initialText = '',
    required String okText,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: initialText);
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.12),
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.providerGroupsNameHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.providerGroupsCreateDialogCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(okText),
          ),
        ],
      ),
    );
    if (ok != true) return null;
    final name = controller.text.trim();
    if (name.isEmpty) return null;
    return name;
  }

  Future<void> _createGroup(BuildContext context) async {
    final sp = context.read<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;
    final name = await _promptName(
      context,
      title: l10n.providerGroupsCreateDialogTitle,
      okText: l10n.providerGroupsCreateDialogOk,
    );
    if (name == null) return;
    final id = await sp.createGroup(name);
    if (id.isEmpty && context.mounted) {
      showAppSnackBar(
        context,
        message: l10n.providerGroupsCreateFailedToast,
        type: NotificationType.error,
      );
    }
  }

  Future<void> _renameGroup(
    BuildContext context, {
    required String groupId,
    required String oldName,
  }) async {
    final sp = context.read<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;
    final name = await _promptName(
      context,
      title: l10n.providerDetailPageEditTooltip,
      initialText: oldName,
      okText: l10n.sideDrawerSave,
    );
    if (name == null) return;
    await sp.renameGroup(groupId, name);
  }

  Future<void> _deleteGroup(BuildContext context, String groupId) async {
    final sp = context.read<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.12),
      builder: (ctx) => AlertDialog(
        title: Text(l10n.providerGroupsDeleteConfirmTitle),
        content: Text(l10n.providerGroupsDeleteConfirmContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.providerGroupsDeleteConfirmCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l10n.providerGroupsDeleteConfirmOk,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await sp.deleteGroup(groupId);
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      message: l10n.providerGroupsDeletedToast,
      type: NotificationType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final groups = sp.providerGroups;

    final counts = <String, int>{};
    for (final k in sp.providersOrder) {
      final gid = sp.groupIdForProvider(k);
      if (gid != null) counts[gid] = (counts[gid] ?? 0) + 1;
    }

    return Dialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.providerGroupsManageTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _IconBtn(
                      icon: lucide.Lucide.Plus,
                      onTap: () => unawaited(_createGroup(context)),
                    ),
                    const SizedBox(width: 6),
                    _IconBtn(
                      icon: lucide.Lucide.X,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: groups.isEmpty
                  ? Center(
                      child: Text(
                        l10n.providerGroupsEmptyState,
                        style: TextStyle(
                          color: cs.onSurface.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                      itemCount: groups.length,
                      buildDefaultDragHandles: false,
                      proxyDecorator: (child, index, animation) {
                        return ScaleTransition(
                          scale: Tween<double>(
                            begin: 1.0,
                            end: 1.02,
                          ).animate(animation),
                          child: child,
                        );
                      },
                      onReorder: (oldIndex, newIndex) async {
                        if (newIndex > oldIndex) newIndex -= 1;
                        await context
                            .read<SettingsProvider>()
                            .reorderProviderGroups(oldIndex, newIndex);
                      },
                      itemBuilder: (ctx, i) {
                        final g = groups[i];
                        final count = counts[g.id] ?? 0;
                        return KeyedSubtree(
                          key: ValueKey('desktop-provider-group-${g.id}'),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _DesktopProviderGroupCard(
                              title: g.name,
                              count: count,
                              onEdit: () => unawaited(
                                _renameGroup(
                                  context,
                                  groupId: g.id,
                                  oldName: g.name,
                                ),
                              ),
                              onDelete: () =>
                                  unawaited(_deleteGroup(context, g.id)),
                              dragHandle: ReorderableDragStartListener(
                                index: i,
                                child: const _DesktopDragHandle(),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopProviderGroupCard extends StatelessWidget {
  const _DesktopProviderGroupCard({
    required this.title,
    required this.count,
    required this.onEdit,
    required this.onDelete,
    required this.dragHandle,
  });

  final String title;
  final int count;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Widget dragHandle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white10 : const Color(0xFFF7F7F9);
    final borderColor = cs.outlineVariant.withOpacity(isDark ? 0.12 : 0.10);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          _DesktopCountPill(count: count),
          const SizedBox(width: 10),
          _IconBtn(icon: lucide.Lucide.Pencil, onTap: onEdit),
          const SizedBox(width: 4),
          _IconBtn(
            icon: lucide.Lucide.Trash2,
            color: cs.error,
            onTap: onDelete,
          ),
          const SizedBox(width: 4),
          dragHandle,
        ],
      ),
    );
  }
}

class _DesktopCountPill extends StatelessWidget {
  const _DesktopCountPill({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = cs.primary.withOpacity(0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 12,
          color: cs.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DesktopDragHandle extends StatefulWidget {
  const _DesktopDragHandle();

  @override
  State<_DesktopDragHandle> createState() => _DesktopDragHandleState();
}

class _DesktopDragHandleState extends State<_DesktopDragHandle> {
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
      cursor: SystemMouseCursors.grab,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(
          lucide.Lucide.GripVertical,
          size: 18,
          color: cs.onSurface.withOpacity(0.7),
        ),
      ),
    );
  }
}

class _DesktopProviderShareDialog extends StatefulWidget {
  const _DesktopProviderShareDialog({
    required this.providerKey,
    required this.displayName,
  });
  final String providerKey;
  final String displayName;

  @override
  State<_DesktopProviderShareDialog> createState() =>
      _DesktopProviderShareDialogState();
}

class _DesktopProviderShareDialogState
    extends State<_DesktopProviderShareDialog> {
  late final String _code;
  final GlobalKey _qrKey = GlobalKey();
  bool _copyingQr = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    final cfg =
        settings.providerConfigs[widget.providerKey] ??
        settings.getProviderConfig(
          widget.providerKey,
          defaultName: widget.displayName,
        );
    _code = encodeProviderConfig(cfg);
  }

  Future<void> _copyText() async {
    await Clipboard.setData(ClipboardData(text: _code));
    if (!mounted) return;
    showAppSnackBar(
      context,
      message: AppLocalizations.of(context)!.shareProviderSheetCopiedMessage,
      type: NotificationType.success,
    );
  }

  Future<Uint8List?> _captureQrBytes() async {
    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<bool> _writeQrToClipboard(Uint8List bytes) async {
    try {
      final clipboard = SystemClipboard.instance;
      if (clipboard != null) {
        final item = DataWriterItem(suggestedName: 'provider-qr.png');
        item.add(Formats.png(bytes));
        await clipboard.write([item]);
        return true;
      }
    } catch (_) {}

    try {
      final file = File(
        p.join(Directory.systemTemp.path, 'kelivo-provider-qr.png'),
      );
      await file.writeAsBytes(bytes, flush: true);
      return await ClipboardImages.setImagePath(file.path);
    } catch (_) {
      return false;
    }
  }

  Future<void> _copyQr() async {
    if (_copyingQr) return;
    setState(() => _copyingQr = true);
    bool ok = false;
    try {
      final bytes = await _captureQrBytes();
      if (bytes != null && bytes.isNotEmpty) {
        ok = await _writeQrToClipboard(bytes);
      }
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _copyingQr = false);
    final l10n = AppLocalizations.of(context)!;
    showAppSnackBar(
      context,
      message: ok
          ? l10n.shareProviderSheetCopiedMessage
          : l10n.messageExportSheetExportFailed('copy-failed'),
      type: ok ? NotificationType.success : NotificationType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    return Dialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.shareProviderSheetTitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _IconBtn(
                    icon: lucide.Lucide.X,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                l10n.shareProviderSheetDescription,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withOpacity(0.85),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: RepaintBoundary(
                  key: _qrKey,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: cs.outlineVariant.withOpacity(0.2),
                      ),
                    ),
                    child: PrettyQr(
                      data: _code,
                      size: 180,
                      roundEdges: true,
                      errorCorrectLevel: QrErrorCorrectLevel.M,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.04)
                      : Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: cs.outlineVariant.withOpacity(0.25),
                  ),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _code,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.35,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _DialogActionButton(
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    label: l10n.desktopProviderShareCopyText,
                    filled: false,
                    onTap: _copyText,
                  ),
                  const SizedBox(width: 10),
                  _DialogActionButton(
                    icon: _copyingQr
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CupertinoActivityIndicator(radius: 8),
                          )
                        : const Icon(Icons.qr_code_2, size: 18),
                    label: l10n.desktopProviderShareCopyQr,
                    filled: true,
                    onTap: _copyingQr ? null : _copyQr,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogActionButton extends StatefulWidget {
  const _DialogActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });
  final Widget icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  State<_DialogActionButton> createState() => _DialogActionButtonState();
}

class _DialogActionButtonState extends State<_DialogActionButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = widget.onTap != null;
    final baseBg = widget.filled ? cs.primary : Colors.transparent;
    final hoverOverlay = widget.filled
        ? Colors.white.withOpacity(isDark ? 0.08 : 0.10)
        : cs.primary.withOpacity(isDark ? 0.12 : 0.10);
    final bg = Color.alphaBlend(
      (_hover ? hoverOverlay : Colors.transparent),
      baseBg,
    );
    final borderColor = widget.filled
        ? cs.primary.withOpacity(isDark ? 0.30 : 0.25)
        : cs.primary.withOpacity(0.35);
    final fg = widget.filled ? cs.onPrimary : cs.primary;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: enabled ? bg : baseBg.withOpacity(0.4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconTheme.merge(
                  data: IconThemeData(color: fg, size: 18),
                  child: widget.icon,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: enabled ? fg : fg.withOpacity(0.5),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
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

class _BrandCircle extends StatelessWidget {
  const _BrandCircle({required this.name, this.size = 22});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asset = BrandAssets.assetForName(name);
    Widget inner;
    if (asset == null) {
      inner = Text(
        name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
        style: TextStyle(
          color: cs.primary,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.45,
        ),
      );
    } else if (asset.endsWith('.svg')) {
      inner = SvgPicture.asset(
        asset,
        width: size * 0.62,
        height: size * 0.62,
        fit: BoxFit.contain,
      );
    } else {
      inner = Image.asset(
        asset,
        width: size * 0.62,
        height: size * 0.62,
        fit: BoxFit.contain,
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : cs.primary.withOpacity(0.10),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: inner,
    );
  }
}

class _ProviderListRow extends StatefulWidget {
  const _ProviderListRow({
    required this.name,
    required this.keyName,
    required this.enabled,
    required this.selected,
    required this.background,
    required this.onTap,
    required this.onEdit,
    required this.onShare,
    this.onDelete,
  });
  final String name;
  final String keyName;
  final bool enabled;
  final bool selected;
  final Color background;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onShare;
  final Future<void> Function()? onDelete;
  @override
  State<_ProviderListRow> createState() => _ProviderListRowState();
}

class _ProviderListRowState extends State<_ProviderListRow> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hoverBg = _hover && !widget.selected
        ? Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.04)
        : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapDown: (details) async {
          final items = <DesktopContextMenuItem>[
            DesktopContextMenuItem(
              icon: lucide.Lucide.Share2,
              label: AppLocalizations.of(
                context,
              )!.desktopProviderContextMenuShare,
              onTap: widget.onShare,
            ),
            DesktopContextMenuItem(
              icon: lucide.Lucide.Pencil,
              label: AppLocalizations.of(
                context,
              )!.providerDetailPageEditTooltip,
              onTap: widget.onEdit,
            ),
            if (widget.onDelete != null)
              DesktopContextMenuItem(
                icon: lucide.Lucide.Trash2,
                label: AppLocalizations.of(
                  context,
                )!.providerDetailPageDeleteProviderTooltip,
                danger: true,
                onTap: () => widget.onDelete?.call(),
              ),
          ];
          await showDesktopContextMenuAt(
            context,
            globalPosition: details.globalPosition,
            items: items,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: Color.alphaBlend(hoverBg, widget.background),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              ProviderAvatar(
                providerKey: widget.keyName,
                displayName: widget.name,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (widget.enabled ? Colors.green : Colors.orange)
                      .withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                  // No border for left list status
                ),
                child: Text(
                  widget.enabled
                      ? AppLocalizations.of(context)!.providersPageEnabledStatus
                      : AppLocalizations.of(
                          context,
                        )!.providersPageDisabledStatus,
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.enabled ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddFullWidthButton extends StatefulWidget {
  const _AddFullWidthButton({
    required this.label,
    required this.onTap,
    this.height = 44,
  });
  final String label;
  final VoidCallback onTap;
  final double height;
  @override
  State<_AddFullWidthButton> createState() => _AddFullWidthButtonState();
}

class _AddFullWidthButtonState extends State<_AddFullWidthButton> {
  bool _pressed = false;
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseBg = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.04);
    final hoverBg = isDark
        ? Colors.white.withOpacity(0.10)
        : Colors.black.withOpacity(0.06);
    final bg = _hover ? hoverBg : baseBg;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          child: Container(
            height: widget.height,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(lucide.Lucide.Plus, size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
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

class _DesktopIosSectionCard extends StatelessWidget {
  const _DesktopIosSectionCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final Color base = cs.surface;
    final Color bg = isDark
        ? Color.lerp(base, Colors.white, 0.06)!
        : const Color(0xFFF7F7F9);
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
      child: Column(children: children),
    );
  }
}

class _DesktopKeyRow extends StatelessWidget {
  const _DesktopKeyRow({
    required this.keyConfig,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
    required this.onTest,
    this.testing = false,
    this.showDivider = false,
  });
  final ApiKeyConfig keyConfig;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onTest;
  final bool testing;
  final bool showDivider;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    String label;
    if ((keyConfig.name ?? '').trim().isNotEmpty) {
      label = keyConfig.name!.trim();
    } else {
      final s = keyConfig.key.trim();
      label = s.length <= 8
          ? '••••'
          : '${s.substring(0, 4)}••••${s.substring(s.length - 4)}';
    }
    Color statusColor(ApiKeyStatus st) {
      switch (st) {
        case ApiKeyStatus.active:
          return Colors.green;
        case ApiKeyStatus.disabled:
          return cs.onSurface.withOpacity(0.6);
        case ApiKeyStatus.error:
          return cs.error;
        case ApiKeyStatus.rateLimited:
          return cs.tertiary;
      }
    }

    String statusText(ApiKeyStatus st) {
      switch (st) {
        case ApiKeyStatus.active:
          return l10n.multiKeyPageStatusActive;
        case ApiKeyStatus.disabled:
          return l10n.multiKeyPageStatusDisabled;
        case ApiKeyStatus.error:
          return l10n.multiKeyPageStatusError;
        case ApiKeyStatus.rateLimited:
          return l10n.multiKeyPageStatusRateLimited;
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              // Status capsule
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor(keyConfig.status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusText(keyConfig.status),
                  style: TextStyle(
                    color: statusColor(keyConfig.status),
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IosSwitch(
                value: keyConfig.isEnabled,
                onChanged: onToggle,
                width: 46,
                height: 28,
              ),
              const SizedBox(width: 6),
              if (testing)
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.primary,
                  ),
                )
              else
                Tooltip(
                  message: l10n.multiKeyPageDetect,
                  child: _IconBtn(
                    icon: lucide.Lucide.HeartPulse,
                    onTap: onTest,
                    color: cs.primary,
                  ),
                ),
              const SizedBox(width: 4),
              _IconBtn(
                icon: lucide.Lucide.Pencil,
                onTap: onEdit,
                color: cs.primary,
              ),
              const SizedBox(width: 4),
              _IconBtn(
                icon: lucide.Lucide.Trash2,
                onTap: onDelete,
                color: cs.error,
              ),
            ],
          ),
        ),
        if (showDivider)
          Container(height: 0.6, color: cs.outlineVariant.withOpacity(0.25)),
      ],
    );
  }
}

class _ModelGroupAccordion extends StatefulWidget {
  const _ModelGroupAccordion({
    required this.group,
    required this.modelIds,
    required this.providerKey,
    this.isSelectionMode = false,
    this.selectedModels = const {},
    this.onSelectionChanged,
    this.detectionResults = const {},
    this.detectionErrorMessages = const {},
    this.currentDetectingModel,
    this.pendingModels = const {},
  });
  final String group;
  final List<String> modelIds;
  final String providerKey;
  final bool isSelectionMode;
  final Set<String> selectedModels;
  final Map<String, String> detectionErrorMessages;
  final ValueChanged<Set<String>>? onSelectionChanged;
  final Map<String, bool> detectionResults;
  final String? currentDetectingModel;
  final Set<String> pendingModels;
  @override
  State<_ModelGroupAccordion> createState() => _ModelGroupAccordionState();
}

class _ModelGroupAccordionState extends State<_ModelGroupAccordion> {
  bool _open = true;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: InkWell(
                highlightColor: Colors.transparent,
                splashColor: Colors.transparent,
                hoverColor: Colors.transparent,
                focusColor: Colors.transparent,
                onTap: () => setState(() => _open = !_open),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.03)
                        : Colors.black.withOpacity(0.02),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      AnimatedRotation(
                        turns: _open ? 0.25 : 0.0, // right (0) -> down (0.25)
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          lucide.Lucide.ChevronRight,
                          size: 16,
                          color: cs.onSurface.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.group,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: [
                  for (final id in widget.modelIds)
                    _ModelRow(
                      modelId: id,
                      providerKey: widget.providerKey,
                      isSelectionMode: widget.isSelectionMode,
                      isSelected: widget.selectedModels.contains(id),
                      onSelectionChanged: (selected) {
                        final newSelection = Set<String>.from(
                          widget.selectedModels,
                        );
                        if (selected) {
                          newSelection.add(id);
                        } else {
                          newSelection.remove(id);
                        }
                        widget.onSelectionChanged?.call(newSelection);
                      },
                      detectionErrorMessage: widget.detectionErrorMessages[id],
                      detectionResult: widget.detectionResults[id],
                      isDetecting: widget.currentDetectingModel == id,
                      isPending: widget.pendingModels.contains(id),
                    ),
                ],
              ),
              crossFadeState: _open
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 180),
              sizeCurve: Curves.easeOutCubic,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({
    required this.modelId,
    required this.providerKey,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.detectionErrorMessage,
    this.onSelectionChanged,
    this.detectionResult,
    this.isDetecting = false,
    this.isPending = false,
  });
  final String modelId;
  final String providerKey;
  final bool isSelectionMode;
  final bool isSelected;
  final String? detectionErrorMessage;
  final ValueChanged<bool>? onSelectionChanged;
  final bool? detectionResult;
  final bool isDetecting;
  final bool isPending;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    final cfg = sp.getProviderConfig(providerKey);
    ModelInfo _infer(String id) =>
        ModelRegistry.infer(ModelInfo(id: id, displayName: id));
    // Resolve upstream/api model id for inference + capsules
    String baseId = modelId;
    final ov = cfg.modelOverrides[modelId] as Map?;
    if (ov != null) {
      final apiId = (ov['apiModelId'] ?? ov['api_model_id'])?.toString().trim();
      if (apiId != null && apiId.isNotEmpty) {
        baseId = apiId;
      }
    }

    ModelInfo _effective() {
      final base = _infer(baseId);
      if (ov == null) return base;
      ModelType? type;
      final t = (ov['type'] as String?) ?? '';
      if (t == 'embedding')
        type = ModelType.embedding;
      else if (t == 'chat')
        type = ModelType.chat;
      List<Modality>? input;
      if (ov['input'] is List) {
        input = [
          for (final e in (ov['input'] as List))
            (e.toString() == 'image' ? Modality.image : Modality.text),
        ];
      }
      List<Modality>? output;
      if (ov['output'] is List) {
        output = [
          for (final e in (ov['output'] as List))
            (e.toString() == 'image' ? Modality.image : Modality.text),
        ];
      }
      List<ModelAbility>? abilities;
      if (ov['abilities'] is List) {
        abilities = [
          for (final e in (ov['abilities'] as List))
            (e.toString() == 'reasoning'
                ? ModelAbility.reasoning
                : ModelAbility.tool),
        ];
      }
      return base.copyWith(
        type: type ?? base.type,
        input: input ?? base.input,
        output: output ?? base.output,
        abilities: abilities ?? base.abilities,
      );
    }

    final info = _effective();
    // Display label: prefer override name, then upstream model id, then logical key
    String displayName = modelId;
    if (ov != null) {
      final overrideName = (ov['name'] as String?)?.trim();
      if (overrideName != null && overrideName.isNotEmpty) {
        displayName = overrideName;
      } else {
        displayName = baseId;
      }
    } else {
      displayName = baseId;
    }

    Widget cap(String text) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final bg = isDark
          ? Colors.white.withOpacity(0.06)
          : const Color(0xFFF2F3F5);
      final fg = cs.onSurface.withOpacity(0.85);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text, style: TextStyle(fontSize: 11, color: fg)),
      );
    }

    // Build capsule pill style like mobile
    final caps = <Widget>[];
    Widget pillCapsule(Widget icon, Color color) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final bg = isDark ? color.withOpacity(0.20) : color.withOpacity(0.16);
      final bd = color.withOpacity(0.25);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: bd, width: 0.5),
        ),
        child: icon,
      );
    }

    // Build from effective info similar to mobile
    if (info.input.contains(Modality.image)) {
      caps.add(
        pillCapsule(
          Icon(lucide.Lucide.Eye, size: 12, color: cs.secondary),
          cs.secondary,
        ),
      );
    }
    if (info.output.contains(Modality.image)) {
      caps.add(
        pillCapsule(
          Icon(lucide.Lucide.Image, size: 12, color: cs.tertiary),
          cs.tertiary,
        ),
      );
    }
    for (final ab in info.abilities) {
      if (ab == ModelAbility.tool) {
        caps.add(
          pillCapsule(
            Icon(lucide.Lucide.Hammer, size: 12, color: cs.primary),
            cs.primary,
          ),
        );
      } else if (ab == ModelAbility.reasoning) {
        caps.add(
          pillCapsule(
            SvgPicture.asset(
              'assets/icons/deepthink.svg',
              width: 12,
              height: 12,
              colorFilter: ColorFilter.mode(cs.secondary, BlendMode.srcIn),
            ),
            cs.secondary,
          ),
        );
      }
    }

    return GestureDetector(
      onTap: isSelectionMode
          ? () => onSelectionChanged?.call(!isSelected)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            if (isSelectionMode) ...[
              IosCheckbox(
                value: isSelected,
                onChanged: (value) => onSelectionChanged?.call(value),
              ),
              const SizedBox(width: 10),
            ],
            _BrandCircle(name: displayName, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5),
              ),
            ),
            const SizedBox(width: 8),
            if (isDetecting) ...[
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 8),
            ] else if (isPending) ...[
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: cs.onSurface.withOpacity(0.3),
                    width: 2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ] else if (detectionResult != null) ...[
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Tooltip(
                  message: detectionResult!
                      ? l10n.providerDetailPageDetectSuccess
                      : (detectionErrorMessage ??
                            l10n.providerDetailPageDetectFailed),
                  child: Icon(
                    detectionResult!
                        ? lucide.Lucide.CheckCircle
                        : lucide.Lucide.XCircle,
                    size: 16,
                    color: detectionResult! ? Colors.green : cs.error,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (!isSelectionMode) ...[
              Row(
                children: caps
                    .map(
                      (w) => Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: w,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(width: 8),
              _IconBtn(
                icon: lucide.Lucide.Settings2,
                onTap: () async {
                  await showDesktopModelEditDialog(
                    context,
                    providerKey: providerKey,
                    modelId: modelId,
                  );
                },
              ),
              const SizedBox(width: 4),
              _IconBtn(
                icon: lucide.Lucide.Minus,
                onTap: () async {
                  final sp = context.read<SettingsProvider>();
                  final old = sp.getProviderConfig(providerKey);
                  final list = List<String>.from(old.models)
                    ..removeWhere((e) => e == modelId);
                  await sp.setProviderConfig(
                    providerKey,
                    old.copyWith(models: list),
                  );
                  // Clear global and assistant-level model selections that reference the deleted model
                  await sp.clearSelectionsForModel(providerKey, modelId);
                  try {
                    final ap = context.read<AssistantProvider>();
                    for (final a in ap.assistants) {
                      if (a.chatModelProvider == providerKey &&
                          a.chatModelId == modelId) {
                        await ap.updateAssistant(
                          a.copyWith(clearChatModel: true),
                        );
                      }
                    }
                  } catch (_) {}
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CardPress extends StatefulWidget {
  const _CardPress({
    required this.builder,
    this.onTap,
    this.pressedScale = 0.98,
  });
  final Widget Function(bool pressed, Color overlay) builder;
  final VoidCallback? onTap;
  final double pressedScale;
  @override
  State<_CardPress> createState() => _CardPressState();
}

class _CardPressState extends State<_CardPress> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlay = _pressed
        ? (isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.04))
        : Colors.transparent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() => _pressed = true),
      onTapUp: widget.onTap == null
          ? null
          : (_) => setState(() => _pressed = false),
      onTapCancel: widget.onTap == null
          ? null
          : () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: widget.builder(_pressed, overlay),
        ),
      ),
    );
  }
}

// Removed embedded default model pane; now in setting/default_model_pane.dart

// Removed default model prompt dialogs; migrated to setting/default_model_pane.dart

// Removed embedded default model card; now in setting/default_model_pane.dart

// ===== Display Settings Body =====

