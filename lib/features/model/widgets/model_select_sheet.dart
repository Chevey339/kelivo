import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/model_provider.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../icons/lucide_adapter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'model_detail_sheet.dart';
import '../../provider/pages/provider_detail_page.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/brand_assets.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/model_tag_wrap.dart';
import '../../../desktop/desktop_home_page.dart' show DesktopHomePage;
import '../../provider/widgets/provider_avatar.dart';
import '../../../core/services/model_override_resolver.dart';

class ModelSelection {
  final String providerKey;
  final String modelId;
  ModelSelection(this.providerKey, this.modelId);
}

// Prevent re-entrant model selector dialogs
bool _modelSelectorOpen = false;

// Data class for compute function
class _ModelProcessingData {
  final Map<String, dynamic> providerConfigs;
  final Set<String> pinnedModels;
  final String currentModelKey;
  final List<String> providersOrder;
  final String? limitProviderKey;
  
  _ModelProcessingData({
    required this.providerConfigs,
    required this.pinnedModels,
    required this.currentModelKey,
    required this.providersOrder,
    this.limitProviderKey,
  });
}

class _ModelProcessingResult {
  final Map<String, _ProviderGroup> groups;
  final List<_ModelItem> favItems;
  final List<String> orderedKeys;
  
  _ModelProcessingResult({
    required this.groups,
    required this.favItems,
    required this.orderedKeys,
  });
}

// Lightweight brand asset resolver usable in isolates
String? _assetForNameStatic(String n) {
  return BrandAssets.assetForName(n);
}

// Static function for compute - must be top-level
_ModelProcessingResult _processModelsInBackground(_ModelProcessingData data) {
  final providers = data.limitProviderKey == null
      ? data.providerConfigs
      : {
    if (data.providerConfigs.containsKey(data.limitProviderKey))
      data.limitProviderKey!: data.providerConfigs[data.limitProviderKey]!,
  };
  
  // Build data map: providerKey -> (displayName, models)
  final Map<String, _ProviderGroup> groups = {};
  
  providers.forEach((key, cfg) {
    // Skip disabled providers entirely so they can't be selected
    if (!(cfg['enabled'] as bool)) return;
    final models = cfg['models'] as List<dynamic>? ?? [];
    if (models.isEmpty) return;
    
    final name = (cfg['name'] as String?) ?? '';
    final overrides = (cfg['overrides'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ?? const <String, dynamic>{};
    final list = <_ModelItem>[
      for (final id in models)
        () {
          final String mid = id.toString();
          final ov = overrides[mid] as Map?;
          // Use upstream/api model id for inference when available so that
          // brand assets and default capabilities stay accurate even when the
          // logical key is a custom alias.
          String baseId = mid;
          if (ov != null) {
            final raw = (ov['apiModelId'] ?? ov['api_model_id'])?.toString().trim();
            if (raw != null && raw.isNotEmpty) baseId = raw;
          }
          ModelInfo base = ModelRegistry.infer(ModelInfo(id: baseId, displayName: baseId));
          if (ov != null) {
            base = ModelOverrideResolver.applyModelOverride(base, ov, applyDisplayName: true);
          }
          return _ModelItem(
            providerKey: key,
            providerName: name.isNotEmpty ? name : key,
            id: mid,
            info: base,
            pinned: data.pinnedModels.contains('$key::$mid'),
            selected: data.currentModelKey == '$key::$mid',
            asset: _assetForNameStatic(baseId),
          );
        }()
    ];
    groups[key] = _ProviderGroup(name: name.isNotEmpty ? name : key, items: list);
  });
  
  // Build favorites group (duplicate items)
  final favItems = <_ModelItem>[];
  for (final k in data.pinnedModels) {
    final parts = k.split('::');
    if (parts.length < 2) continue;
    final pk = parts[0];
    final mid = parts.sublist(1).join('::');
    final g = groups[pk];
    if (g == null) continue;
    final found = g.items.firstWhere(
      (e) => e.id == mid,
      orElse: () => _ModelItem(
        providerKey: pk,
        providerName: g.name,
        id: mid,
        info: ModelRegistry.infer(ModelInfo(id: mid, displayName: mid)),
        pinned: true,
        selected: data.currentModelKey == '$pk::$mid',
      ),
    );
    favItems.add(found.copyWith(pinned: true));
  }
  
  // Provider sections ordered by ProvidersPage order
  final orderedKeys = <String>[];
  for (final k in data.providersOrder) {
    if (groups.containsKey(k)) orderedKeys.add(k);
  }
  for (final k in groups.keys) {
    if (!orderedKeys.contains(k)) orderedKeys.add(k);
  }
  
  return _ModelProcessingResult(
    groups: groups,
    favItems: favItems,
    orderedKeys: orderedKeys,
  );
}

Future<ModelSelection?> showModelSelector(BuildContext context, {String? limitProviderKey}) async {
  if (_modelSelectorOpen) return null;
  _modelSelectorOpen = true;
  try {
  // Desktop platforms use a custom dialog, mobile keeps the bottom sheet UX.
  final platform = defaultTargetPlatform;
  if (platform == TargetPlatform.macOS || platform == TargetPlatform.windows || platform == TargetPlatform.linux) {
    return await _showDesktopModelSelector(context, limitProviderKey: limitProviderKey);
  }
  final cs = Theme.of(context).colorScheme;
  return await showModalBottomSheet<ModelSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _ModelSelectSheet(limitProviderKey: limitProviderKey),
  );
  } finally {
    _modelSelectorOpen = false;
  }
}

Future<void> showModelSelectSheet(BuildContext context, {bool updateAssistant = true}) async {
  final sel = await showModelSelector(context);
  if (sel != null) {
    if (updateAssistant) {
      // Update assistant's model instead of global default
      final assistantProvider = context.read<AssistantProvider>();
      final assistant = assistantProvider.currentAssistant;
      if (assistant != null) {
        await assistantProvider.updateAssistant(
          assistant.copyWith(
            chatModelProvider: sel.providerKey,
            chatModelId: sel.modelId,
          ),
        );
      }
    } else {
      // Only update global default when explicitly requested (e.g., from settings)
      final settings = context.read<SettingsProvider>();
      await settings.setCurrentModel(sel.providerKey, sel.modelId);
    }
  }
}

class _ModelSelectSheet extends StatefulWidget {
  const _ModelSelectSheet({this.limitProviderKey});
  final String? limitProviderKey;
  @override
  State<_ModelSelectSheet> createState() => _ModelSelectSheetState();
}

class _ModelSelectSheetState extends State<_ModelSelectSheet> {
  final TextEditingController _search = TextEditingController();
  final DraggableScrollableController _sheetCtrl = DraggableScrollableController();
  static const double _initialSize = 0.8;
  static const double _maxSize = 0.8;
  String _lastQuery = '';
  // ScrollablePositionedList controllers
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  
  // Flattened rows + index maps for precise jumps
  final List<_ListRow> _rows = <_ListRow>[];
  final Map<String, int> _headerIndexMap = <String, int>{}; // providerKey or '__fav__' -> index
  final Map<String, int> _modelIndexMap = <String, int>{};  // 'pk::modelId' in provider sections -> index
  final Map<String, int> _favModelIndexMap = <String, int>{}; // 'pk::modelId' in favorites -> index
  
  // Async loading state
  bool _isLoading = true;
  Map<String, _ProviderGroup> _groups = {};
  List<_ModelItem> _favItems = [];
  List<String> _orderedKeys = [];
  bool _autoScrolled = false; // ensure we only auto-scroll once per open

  @override
  void initState() {
    super.initState();
    // Delay loading to allow the sheet to open first
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        _loadModelsAsync();
      }
    });
  }

  Future<void> _loadModelsAsync() async {
    try {
      final settings = context.read<SettingsProvider>();
      final assistant = context.read<AssistantProvider>().currentAssistant;
      
      // Determine current model - use assistant's model if set, otherwise global default
      final currentProvider = assistant?.chatModelProvider ?? settings.currentModelProvider;
      final currentModelId = assistant?.chatModelId ?? settings.currentModelId;
      final currentKey = (currentProvider != null && currentModelId != null) 
          ? '$currentProvider::$currentModelId' 
          : '';
      
      // Prepare data for background processing
      final processingData = _ModelProcessingData(
        providerConfigs: Map<String, dynamic>.from(
          settings.providerConfigs.map((key, value) => MapEntry(key, {
            'enabled': value.enabled,
            'name': value.name,
            'models': value.models,
            'overrides': value.modelOverrides,
          })),
        ),
        pinnedModels: settings.pinnedModels,
        currentModelKey: currentKey,
        providersOrder: settings.providersOrder,
        limitProviderKey: widget.limitProviderKey,
      );
      
      // Process in background isolate
      final result = await compute(_processModelsInBackground, processingData);
      
      if (mounted) {
        setState(() {
          _groups = result.groups;
          _favItems = result.favItems;
          _orderedKeys = result.orderedKeys;
          _isLoading = false;
        });
        _scheduleAutoScrollToCurrent();
      }
    } catch (e) {
      // If compute fails (e.g., on web), fall back to synchronous processing
      if (mounted) {
        _loadModelsSynchronously();
      }
    }
  }

  Future<void> _expandSheetIfNeeded(double target, {Duration duration = const Duration(milliseconds: 300)}) async {
    // Safely attempt to read size and animate; ignore if controller not yet attached
    try {
      final current = _sheetCtrl.size;
      if (current < target) {
        await _sheetCtrl.animateTo(target, duration: duration, curve: Curves.easeOutCubic);
        // allow a brief settle time after expansion
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (_) {}
  }
  
  void _loadModelsSynchronously() {
    final settings = context.read<SettingsProvider>();
    final assistant = context.read<AssistantProvider>().currentAssistant;
    
    // Determine current model - use assistant's model if set, otherwise global default
    final currentProvider = assistant?.chatModelProvider ?? settings.currentModelProvider;
    final currentModelId = assistant?.chatModelId ?? settings.currentModelId;
    final currentKey = (currentProvider != null && currentModelId != null) 
        ? '$currentProvider::$currentModelId' 
        : '';
    
    final processingData = _ModelProcessingData(
      providerConfigs: Map<String, dynamic>.from(
        settings.providerConfigs.map((key, value) => MapEntry(key, {
          'enabled': value.enabled,
          'name': value.name,
          'models': value.models,
          'overrides': value.modelOverrides,
        })),
      ),
      pinnedModels: settings.pinnedModels,
      currentModelKey: currentKey,
      providersOrder: settings.providersOrder,
      limitProviderKey: widget.limitProviderKey,
    );
    
    final result = _processModelsInBackground(processingData);
    
    setState(() {
      _groups = result.groups;
      _favItems = result.favItems;
      _orderedKeys = result.orderedKeys;
      _isLoading = false;
    });
    _scheduleAutoScrollToCurrent();
  }

  void _scheduleAutoScrollToCurrent() {
    if (_autoScrolled) return;
    // Wait until the content has been laid out and offsets computed in _buildContent
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _autoScrolled) return;
      await _jumpToCurrentSelection();
    });
  }

  Future<void> _jumpToCurrentSelection() async {
    // If user has entered a search query, decouple from previous selection
    // and jump to the first matching provider group instead.
    final currentQuery = _search.text.trim();
    if (currentQuery.isNotEmpty) {
      await _scrollToFirstSearchGroup(initial: true);
      return;
    }

    final settings = context.read<SettingsProvider>();
    final assistant = context.read<AssistantProvider>().currentAssistant;
    
    // Use assistant's model if set, otherwise fall back to global default
    final pk = assistant?.chatModelProvider ?? settings.currentModelProvider;
    final mid = assistant?.chatModelId ?? settings.currentModelId;
    if (pk == null || mid == null) return;

    // Optionally expand a bit for better context
    await _expandSheetIfNeeded(_initialSize.clamp(0.0, _maxSize), duration: const Duration(milliseconds: 200));

    // If current model is pinned and favorites section is visible, jump there first
    final currentKey = '${pk}::${mid}';
    final bool showFavorites = widget.limitProviderKey == null && (_search.text.isEmpty);
    final bool isPinned = settings.pinnedModels.contains(currentKey);

    // Ensure the list is attached before attempting to scroll
    if (!_itemScrollController.isAttached) {
      // Try again shortly after the list attaches
      Future.delayed(const Duration(milliseconds: 60), () {
        if (mounted && !_autoScrolled) {
          _jumpToCurrentSelection();
        }
      });
      return;
    }

    int? targetIndex;
    if (showFavorites && isPinned) {
      targetIndex = _favModelIndexMap[currentKey];
    }
    targetIndex ??= _modelIndexMap[currentKey];
    targetIndex ??= _headerIndexMap[pk];

    if (targetIndex != null) {
      try {
        await _itemScrollController.scrollTo(
          index: targetIndex,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
        );
        _autoScrolled = true;
      } catch (_) {
        // If scroll fails for any reason, try again once.
        Future.delayed(const Duration(milliseconds: 80), () async {
          if (!mounted || _autoScrolled) return;
          try {
            await _itemScrollController.scrollTo(
              index: targetIndex!,
              duration: const Duration(milliseconds: 360),
              curve: Curves.easeOutCubic,
            );
            _autoScrolled = true;
          } catch (_) {}
        });
      }
    }
  }

  // Scroll to the first matching provider group when searching.
  Future<void> _scrollToFirstSearchGroup({bool initial = false}) async {
    // Expand a bit for better context
    await _expandSheetIfNeeded(_initialSize.clamp(0.0, _maxSize), duration: const Duration(milliseconds: 200));

    if (!_itemScrollController.isAttached) {
      Future.delayed(const Duration(milliseconds: 60), () {
        if (mounted) {
          _scrollToFirstSearchGroup(initial: initial);
        }
      });
      return;
    }

    int? targetIndex;
    // Prefer favorites section when it exists in current filtered rows
    targetIndex = _headerIndexMap['__fav__'];
    // Otherwise, use the first provider section (per ordered keys) that exists in current rows
    if (targetIndex == null) {
      for (final pk in _orderedKeys) {
        final idx = _headerIndexMap[pk];
        if (idx != null) {
          targetIndex = idx;
          break;
        }
      }
    }

    if (targetIndex == null) return;

    try {
      await _itemScrollController.scrollTo(
        index: targetIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
      if (initial) _autoScrolled = true;
    } catch (_) {}
  }

  @override
  void dispose() {
    _search.dispose();
    _sheetCtrl.dispose();
    super.dispose();
  }

  // Match model name/id only (avoid provider key causing false positives)
  bool _matchesSearch(String query, _ModelItem item, String providerName) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return item.id.toLowerCase().contains(q) || item.info.displayName.toLowerCase().contains(q);
  }

  // Check if a provider should be shown based on search query (match display name only)
  bool _providerMatchesSearch(String query, String providerName) {
    if (query.isEmpty) return true;
    final lowerQuery = query.toLowerCase();
    final lowerProviderName = providerName.toLowerCase();
    return lowerProviderName.contains(lowerQuery);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: DraggableScrollableSheet(
          controller: _sheetCtrl,
          expand: false,
          initialChildSize: _initialSize,
          maxChildSize: _maxSize,
          minChildSize: 0.4,
          builder: (c, controller) {
            return Column(
              children: [
                // Fixed header section with rounded corners
                Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      // Header drag indicator
                      Column(children: [
                        const SizedBox(height: 8),
                        Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(999))),
                        const SizedBox(height: 8),
                      ]),
                      // Fixed search field (iOS-like input style)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: TextField(
                          controller: _search,
                          enabled: !_isLoading,
                          onChanged: (_) {
                            final q = _search.text.trim();
                            final enteringSearch = _lastQuery.isEmpty && q.isNotEmpty;
                            setState(() {});
                            if (enteringSearch) {
                              WidgetsBinding.instance.addPostFrameCallback((_) async {
                                if (!mounted) return;
                                await _scrollToFirstSearchGroup();
                              });
                            }
                            _lastQuery = q;
                          },
                          // Ensure high-contrast input text in both themes
                          style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
                          cursorColor: cs.primary,
                          decoration: InputDecoration(
                            hintText: l10n.modelSelectSheetSearchHint,
                            prefixIcon: Icon(Lucide.Search, size: 18, color: cs.onSurface.withOpacity(_isLoading ? 0.35 : 0.6)),
                            // Use IconButton for reliable alignment at the far right
                            suffixIcon: (widget.limitProviderKey == null && context.watch<SettingsProvider>().pinnedModels.isNotEmpty)
                                ? ExcludeSemantics(
                                    child: IconButton(
                                      icon: Icon(Lucide.Bookmark, size: 18, color: cs.onSurface.withOpacity(_isLoading ? 0.35 : 0.7)),
                                      onPressed: _isLoading ? null : _jumpToFavorites,
                                      splashColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      tooltip: l10n.modelSelectSheetFavoritesSection,
                                    ),
                                  )
                                : null,
                            suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            filled: true,
                            fillColor: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withOpacity(0.10)
                                : Colors.white.withOpacity(0.64),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4)),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.25)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: cs.primary.withOpacity(0.5)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Scrollable content
                Expanded(
                  child: Container(
                    color: cs.surface, // Ensure background color continuity
                    child: _isLoading 
                      ? const Center(child: CircularProgressIndicator())
                      : _buildContent(context),
                  ),
                ),
                // Fixed bottom tabs
                Container(
                  color: cs.surface, // Ensure background color continuity
                  child: _buildBottomTabs(context),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final query = _search.text.trim();
    // Build flattened rows and index maps for precise positioning
    _rows.clear();
    _headerIndexMap.clear();
    _modelIndexMap.clear();
    _favModelIndexMap.clear();

    final Set<String> favMatchedKeys = <String>{};

    if (widget.limitProviderKey == null) {
      final pinned = context.watch<SettingsProvider>().pinnedModels;
      if (pinned.isNotEmpty) {
        final favs = <_ModelItem>[];
        for (final k in pinned) {
          final parts = k.split('::');
          if (parts.length < 2) continue;
          final pk = parts[0];
          final mid = parts.sublist(1).join('::');
          final g = _groups[pk];
          if (g == null) continue;
          final found = g.items.firstWhere(
            (e) => e.id == mid,
            orElse: () => _ModelItem(
              providerKey: pk,
              providerName: g.name,
              id: mid,
              info: ModelRegistry.infer(ModelInfo(id: mid, displayName: mid)),
              pinned: true,
              selected: false,
            ),
          );
          if (_matchesSearch(query, found, found.providerName)) {
            favs.add(found.copyWith(pinned: true));
            favMatchedKeys.add('$pk::$mid');
          }
        }
        if (favs.isNotEmpty) {
          _headerIndexMap['__fav__'] = _rows.length;
          _rows.add(_HeaderRow(l10n.modelSelectSheetFavoritesSection));
          for (final m in favs) {
            _favModelIndexMap['${m.providerKey}::${m.id}'] = _rows.length;
            _rows.add(_ModelRow(m, showProviderLabel: true));
          }
        }
      }
    }

    for (final pk in _orderedKeys) {
      final g = _groups[pk]!;
      List<_ModelItem> items;
      if (query.isEmpty) {
        items = g.items;
      } else {
        final providerMatches = _providerMatchesSearch(query, g.name);
        items = providerMatches ? g.items : g.items.where((e) => _matchesSearch(query, e, g.name)).toList();
        if (favMatchedKeys.isNotEmpty) {
          items = items.where((e) => !favMatchedKeys.contains('${e.providerKey}::${e.id}')).toList();
        }
      }
      if (items.isEmpty) continue;
      _headerIndexMap[pk] = _rows.length;
      _rows.add(_HeaderRow(g.name));
      for (final m in items) {
        _modelIndexMap['${m.providerKey}::${m.id}'] = _rows.length;
        _rows.add(_ModelRow(m));
      }
    }

    if (_rows.isEmpty) return const SizedBox.shrink();

    return ScrollablePositionedList.builder(
      itemCount: _rows.length,
      itemScrollController: _itemScrollController,
      itemPositionsListener: _itemPositionsListener,
      padding: const EdgeInsets.only(bottom: 12),
      itemBuilder: (context, index) {
        final row = _rows[index];
        if (row is _HeaderRow) {
          return _sectionHeader(context, row.title);
        } else if (row is _ModelRow) {
          return _modelTile(context, row.item, showProviderLabel: row.showProviderLabel);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildBottomTabs(BuildContext context) {
    // Bottom provider tabs (ordered per ProvidersPage order)
    final List<Widget> providerTabs = <Widget>[];
    if (widget.limitProviderKey == null && !_isLoading) {
      String? selectedProviderKey;
      // Find which provider currently holds the selected model
      _groups.forEach((pk, group) {
        if (selectedProviderKey == null && group.items.any((m) => m.selected)) {
          selectedProviderKey = pk;
        }
      });
      for (final k in _orderedKeys) {
        final g = _groups[k];
        if (g != null) {
          providerTabs.add(_providerTab(context, k, g.name, selected: k == selectedProviderKey));
        }
      }
    }

    if (providerTabs.isEmpty) return const SizedBox.shrink();

    return Padding(
      // SafeArea already applies bottom inset; avoid doubling it here.
      padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: providerTabs),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface.withOpacity(0.6))),
    );
  }

  Widget _modelTile(BuildContext context, _ModelItem m, {bool showProviderLabel = false}) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final settings = context.read<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = m.selected ? (isDark ? cs.primary.withOpacity(0.12) : cs.primary.withOpacity(0.08)) : cs.surface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: RepaintBoundary(
        child: IosCardPress(
          baseColor: bg,
          borderRadius: BorderRadius.circular(14),
          pressedBlendStrength: 0.10,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          onTap: () => Navigator.of(context).pop(ModelSelection(m.providerKey, m.id)),
          onLongPress: () async {
            await showModelDetailSheet(context, providerKey: m.providerKey, modelId: m.id);
            if (mounted) {
              _isLoading = true;
              setState(() {});
              await _loadModelsAsync();
            }
          },
          child: SizedBox(
            width: double.infinity,
            child: Row(
            children: [
              _BrandAvatar(name: m.id, assetOverride: m.asset, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!showProviderLabel)
                      Text(
                        m.info.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      )
                    else
                      Text.rich(
                        TextSpan(
                          text: m.info.displayName,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          children: [
                            TextSpan(
                              text: ' | ${m.providerName}',
                              style: TextStyle(
                                color: cs.onSurface.withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    ModelTagWrap(model: m.info),
                  ],
                ),
              ),
              Builder(builder: (context) {
                final pinnedNow = context.select<SettingsProvider, bool>((s) => s.isModelPinned(m.providerKey, m.id));
                final icon = pinnedNow ? Icons.favorite : Icons.favorite_border;
                return Tooltip(
                  message: l10n.modelSelectSheetFavoriteTooltip,
                  child: IosIconButton(
                    icon: icon,
                    size: 20,
                    color: cs.primary,
                    onTap: () => settings.togglePinModel(m.providerKey, m.id),
                    padding: const EdgeInsets.all(6),
                    minSize: 36,
                  ),
                );
              }),
            ],
          )),
        ),
      ),
    );
  }

  Widget _providerTab(BuildContext context, String key, String name, {bool selected = false}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: _ProviderChip(
        avatar: ProviderAvatar(providerKey: key, displayName: name, size: 18),
        label: name,
        selected: selected,
        borderColor: cs.outlineVariant.withOpacity(0.25),
        onTap: () async { await _jumpToProvider(key); },
        onLongPress: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ProviderDetailPage(keyName: key, displayName: name)),
          );
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Future<void> _jumpToProvider(String pk) async {
    // Expand sheet first if needed
    await _expandSheetIfNeeded(_maxSize);

    // Use precise index jump via ScrollablePositionedList
    final idx = _headerIndexMap[pk];
    if (idx != null) {
      if (!_itemScrollController.isAttached) {
        // Retry shortly if list not yet attached
        Future.delayed(const Duration(milliseconds: 60), () {
          if (mounted) {
            _jumpToProvider(pk);
          }
        });
        return;
      }
      try {
        await _itemScrollController.scrollTo(
          index: idx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      } catch (_) {}
    }
  }

  String _displayName(BuildContext context, _ModelItem m) => m.info.displayName;
  ModelInfo _effectiveInfo(BuildContext context, _ModelItem m) => m.info;

  Future<void> _jumpToFavorites() async {
    if (widget.limitProviderKey != null) return;
    // Expand sheet first to reveal more content
    await _expandSheetIfNeeded(_maxSize);

    // If search text hides favorites section, clear it to ensure favorites are visible
    if (_search.text.isNotEmpty) {
      setState(() => _search.clear());
      await Future.delayed(const Duration(milliseconds: 150));
    }

    // Jump to favorites header index if present
    final idx = _headerIndexMap['__fav__'];
    if (idx != null) {
      if (!_itemScrollController.isAttached) {
        Future.delayed(const Duration(milliseconds: 60), () {
          if (mounted) _jumpToFavorites();
        });
        return;
      }
      try {
        await _itemScrollController.scrollTo(
          index: idx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      } catch (_) {}
    }
  }
}

class _ProviderChip extends StatefulWidget {
  const _ProviderChip({required this.avatar, required this.label, required this.onTap, this.onLongPress, this.borderColor, this.selected = false});
  final Widget avatar;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color? borderColor;
  final bool selected;

  @override
  State<_ProviderChip> createState() => _ProviderChipState();
}

class _ProviderChipState extends State<_ProviderChip> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isSelected = widget.selected;
    // Subtle background tint when selected (less conspicuous)
    final Color baseBg = isSelected
        ? (isDark ? cs.primary.withOpacity(0.08) : cs.primary.withOpacity(0.05))
        : cs.surface;
    final Color overlay = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05);
    final Color bg = _pressed ? Color.alphaBlend(overlay, baseBg) : baseBg;
    // Slightly stronger border when selected; keep label color unchanged for subtlety
    final Color borderColor = widget.borderColor ?? cs.outlineVariant.withOpacity(0.25);
    final Color labelColor = cs.onSurface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            widget.avatar,
            const SizedBox(width: 6),
            Text(widget.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: labelColor)),
          ],
        ),
      ),
    );
  }
}

class _ProviderGroup {
  final String name;
  final List<_ModelItem> items;
  _ProviderGroup({required this.name, required this.items});
}

class _ModelItem {
  final String providerKey;
  final String providerName;
  final String id;
  final ModelInfo info;
  final bool pinned;
  final bool selected;
  final String? asset; // pre-resolved avatar asset for performance
  _ModelItem({required this.providerKey, required this.providerName, required this.id, required this.info, this.pinned = false, this.selected = false, this.asset});
  _ModelItem copyWith({bool? pinned, bool? selected}) => _ModelItem(providerKey: providerKey, providerName: providerName, id: id, info: info, pinned: pinned ?? this.pinned, selected: selected ?? this.selected, asset: asset);
}

// Virtualization entry: fixed height + lazy builder
// Rows for flattened list
abstract class _ListRow {}
class _HeaderRow extends _ListRow {
  final String title;
  _HeaderRow(this.title);
}
class _ModelRow extends _ListRow {
  final _ModelItem item;
  final bool showProviderLabel;
  _ModelRow(this.item, {this.showProviderLabel = false});
}

// Reuse badges and avatars similar to provider detail
class _BrandAvatar extends StatelessWidget {
  const _BrandAvatar({required this.name, this.size = 20, this.assetOverride});
  final String name;
  final double size;
  final String? assetOverride;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asset = assetOverride ?? BrandAssets.assetForName(name);
    Widget inner;
    if (asset != null) {
      if (asset.endsWith('.svg')) {
        final isColorful = asset.contains('color');
        final dark = Theme.of(context).brightness == Brightness.dark;
        final ColorFilter? tint = (dark && !isColorful)
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

// ===== Desktop dialog implementation =====

Future<ModelSelection?> _showDesktopModelSelector(BuildContext context, {String? limitProviderKey}) async {
  return showGeneralDialog<ModelSelection>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'model-select-desktop',
    barrierColor: Colors.black.withOpacity(0.25),
    pageBuilder: (ctx, _, __) => _DesktopModelSelectDialogBody(limitProviderKey: limitProviderKey),
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

class _DesktopModelSelectDialogBody extends StatefulWidget {
  const _DesktopModelSelectDialogBody({this.limitProviderKey});
  final String? limitProviderKey;
  @override
  State<_DesktopModelSelectDialogBody> createState() => _DesktopModelSelectDialogBodyState();
}

class _DesktopModelSelectDialogBodyState extends State<_DesktopModelSelectDialogBody> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _loading = true;
  Map<String, _ProviderGroup> _groups = const {};
  List<_ModelItem> _favItems = const [];
  List<String> _orderedKeys = const [];
  // Flattened rows and precise index mapping for jump
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  final List<_ListRow> _rows = <_ListRow>[];
  final Map<String, int> _headerIndexMap = <String, int>{}; // providerKey or '__fav__' -> index
  final Map<String, int> _modelIndexMap = <String, int>{};  // 'pk::modelId' in provider sections -> index
  final Map<String, int> _favModelIndexMap = <String, int>{}; // 'pk::modelId' in favorites -> index
  bool _autoScrolled = false; // auto-scroll once when dialog opens

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusSearchField());
    Future.microtask(_loadModels);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadModels() async {
    final settings = context.read<SettingsProvider>();
    final assistant = context.read<AssistantProvider>().currentAssistant;
    final currentProvider = assistant?.chatModelProvider ?? settings.currentModelProvider;
    final currentModelId = assistant?.chatModelId ?? settings.currentModelId;
    final currentKey = (currentProvider != null && currentModelId != null) ? '$currentProvider::$currentModelId' : '';

    final data = _ModelProcessingData(
      providerConfigs: Map<String, dynamic>.from(
        settings.providerConfigs.map((key, value) => MapEntry(key, {
              'enabled': value.enabled,
              'name': value.name,
              'models': value.models,
              'overrides': value.modelOverrides,
            })),
      ),
      pinnedModels: settings.pinnedModels,
      currentModelKey: currentKey,
      providersOrder: settings.providersOrder,
      limitProviderKey: widget.limitProviderKey,
    );
    // Synchronous processing is fast enough here
    final result = _processModelsInBackground(data);
    if (!mounted) return;
    setState(() {
      _groups = result.groups;
      _favItems = result.favItems;
      _orderedKeys = result.orderedKeys;
      _loading = false;
    });
    _focusSearchField(defer: true);
    // Defer auto-scroll until list is built and attached
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_autoScrolled) {
        _autoScrollToCurrent();
      }
    });
  }

  bool _matchesSearch(String query, _ModelItem item, String providerName) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return item.id.toLowerCase().contains(q) || item.info.displayName.toLowerCase().contains(q);
  }

  bool _providerMatchesSearch(String query, String providerName) {
    if (query.isEmpty) return true;
    final lowerQuery = query.toLowerCase();
    return providerName.toLowerCase().contains(lowerQuery);
  }

  void _focusSearchField({bool defer = false}) {
    if (!mounted) return;
    void request() {
      if (!mounted) return;
      if (_searchFocusNode.hasFocus) return;
      FocusScope.of(context).requestFocus(_searchFocusNode);
    }
    if (defer) {
      WidgetsBinding.instance.addPostFrameCallback((_) => request());
    } else {
      request();
    }
  }

  void _rebuildRows() {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.read<SettingsProvider>();
    final query = _searchCtrl.text.trim();
    _rows.clear();
    _headerIndexMap.clear();
    _modelIndexMap.clear();
    _favModelIndexMap.clear();

    final Set<String> favMatchedKeys = <String>{};

    if (widget.limitProviderKey == null) {
      final pinned = settings.pinnedModels;
      if (pinned.isNotEmpty) {
        final favs = <_ModelItem>[];
        for (final k in pinned) {
          final parts = k.split('::');
          if (parts.length < 2) continue;
          final pk = parts[0];
          final mid = parts.sublist(1).join('::');
          final g = _groups[pk];
          if (g == null) continue;
          final found = g.items.firstWhere(
            (e) => e.id == mid,
            orElse: () => _ModelItem(
              providerKey: pk,
              providerName: g.name,
              id: mid,
              info: ModelRegistry.infer(ModelInfo(id: mid, displayName: mid)),
              pinned: true,
              selected: false,
            ),
          );
          if (_matchesSearch(query, found, found.providerName)) {
            favs.add(found.copyWith(pinned: true));
            favMatchedKeys.add('$pk::$mid');
          }
        }
        if (favs.isNotEmpty) {
          _headerIndexMap['__fav__'] = _rows.length;
          _rows.add(_HeaderRow(l10n.modelSelectSheetFavoritesSection));
          for (final m in favs) {
            _favModelIndexMap['${m.providerKey}::${m.id}'] = _rows.length;
            _rows.add(_ModelRow(m, showProviderLabel: true));
          }
        }
      }
    }

    for (final pk in _orderedKeys) {
      final g = _groups[pk];
      if (g == null) continue;
      List<_ModelItem> items;
      if (query.isEmpty) {
        items = g.items;
      } else {
        final providerMatches = _providerMatchesSearch(query, g.name);
        items = providerMatches ? g.items : g.items.where((e) => _matchesSearch(query, e, g.name)).toList();
        if (favMatchedKeys.isNotEmpty) {
          items = items.where((e) => !favMatchedKeys.contains('${e.providerKey}::${e.id}')).toList();
        }
      }
      if (items.isEmpty) continue;
      // When limiting to a single provider, hide the provider header (and its settings button)
      if (widget.limitProviderKey == null) {
        _headerIndexMap[pk] = _rows.length;
        _rows.add(_HeaderRow(g.name));
      }
      for (final m in items) {
        _modelIndexMap['${m.providerKey}::${m.id}'] = _rows.length;
        _rows.add(_ModelRow(m));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    final dialog = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 460, maxWidth: 620, maxHeight: 560),
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
                // Body
                Expanded(
                  child: Container(
                    color: cs.surface,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                          child: TextField(
                            controller: _searchCtrl,
                            focusNode: _searchFocusNode,
                            autofocus: true,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: l10n.modelSelectSheetSearchHint,
                              isDense: true,
                              filled: true,
                              fillColor: isDark ? Colors.white10 : const Color(0xFFF2F3F5),
                              prefixIcon: Icon(Lucide.Search, size: 16, color: cs.onSurface.withOpacity(0.7)),
                              suffixIcon: (widget.limitProviderKey == null && context.watch<SettingsProvider>().pinnedModels.isNotEmpty)
                                  ? Tooltip(
                                      message: l10n.modelSelectSheetFavoritesSection,
                                      child: IconButton(
                                        icon: Icon(Lucide.Bookmark, size: 16, color: cs.onSurface.withOpacity(0.7)),
                                        onPressed: _jumpToFavorites,
                                      ),
                                    )
                                  : null,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.transparent)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.transparent)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary.withOpacity(0.4))),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ),
                        Expanded(
                          child: _loading
                              ? const Center(child: CircularProgressIndicator())
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
    // Watch pinned models to keep the favorites section live when user toggles
    // favorites from any item.
    final _ = context.watch<SettingsProvider>().pinnedModels.length;
    // Build flattened rows based on current search and pinned state
    _rebuildRows();
    // After rows are rebuilt and rendered, perform initial auto-scroll
    if (!_autoScrolled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_autoScrolled) {
          _autoScrollToCurrent();
        }
      });
    }
    if (_rows.isEmpty) return const Center(child: SizedBox());
    return ScrollablePositionedList.builder(
      itemCount: _rows.length,
      itemScrollController: _itemScrollController,
      itemPositionsListener: _itemPositionsListener,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
      itemBuilder: (context, index) {
        final row = _rows[index];
        if (row is _HeaderRow) {
          final isFav = _headerIndexMap['__fav__'] == index;
          if (isFav) {
            return _favoritesHeader(context, row.title);
          }
          // Find provider key by matching header index if needed
          String? providerKey;
          _headerIndexMap.forEach((k, v) {
            if (v == index && k != '__fav__') providerKey = k;
          });
          return _providerHeader(context, providerKey, row.title);
        } else if (row is _ModelRow) {
          return _desktopModelTile(context, row.item, showProviderLabel: row.showProviderLabel);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Future<void> _autoScrollToCurrent() async {
    // Ensure controller is attached to the list before scrolling
    if (!_itemScrollController.isAttached) {
      Future.delayed(const Duration(milliseconds: 60), () {
        if (mounted && !_autoScrolled) _autoScrollToCurrent();
      });
      return;
    }

    final settings = context.read<SettingsProvider>();
    final assistant = context.read<AssistantProvider>().currentAssistant;
    final pk = assistant?.chatModelProvider ?? settings.currentModelProvider;
    final mid = assistant?.chatModelId ?? settings.currentModelId;
    if (pk == null || mid == null) return;

    // Rebuild to ensure index maps are current
    _rebuildRows();

    final currentKey = '$pk::$mid';
    final bool showFavorites = widget.limitProviderKey == null && _searchCtrl.text.isEmpty;
    final bool isPinned = settings.pinnedModels.contains(currentKey);

    int? targetIndex;
    if (showFavorites && isPinned) {
      targetIndex = _favModelIndexMap[currentKey];
    }
    targetIndex ??= _modelIndexMap[currentKey];
    // If provider headers are visible, fall back to its section header
    if (widget.limitProviderKey == null) {
      targetIndex ??= _headerIndexMap[pk];
    }

    if (targetIndex == null) return;

    try {
      await _itemScrollController.scrollTo(
        index: targetIndex,
        alignment: 0.5, // try to center the current model
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
      _autoScrolled = true;
    } catch (_) {
      // Retry once shortly after if initial scroll fails
      Future.delayed(const Duration(milliseconds: 80), () async {
        if (!mounted || _autoScrolled) return;
        try {
          await _itemScrollController.scrollTo(
            index: targetIndex!,
            alignment: 0.5,
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutCubic,
          );
          _autoScrolled = true;
        } catch (_) {}
      });
    }
  }

  Widget _desktopModelTile(BuildContext context, _ModelItem m, {bool showProviderLabel = false}) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final bg = m.selected ? (isDark ? cs.primary.withOpacity(0.12) : cs.primary.withOpacity(0.08)) : cs.surface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: IosCardPress(
        baseColor: bg,
        borderRadius: BorderRadius.circular(14),
        pressedBlendStrength: 0.10,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        onTap: () => Navigator.of(context).pop(ModelSelection(m.providerKey, m.id)),
        child: Row(
          children: [
            _BrandAvatar(name: m.id, assetOverride: m.asset, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: m.info.displayName,
                  style: const TextStyle(fontSize: 12.5),
                  children: [
                    if (showProviderLabel)
                      TextSpan(text: ' | ${m.providerName}', style: TextStyle(fontSize: 11.5, color: cs.onSurface.withOpacity(0.6))),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: ModelCapsulesRow(
                model: m.info,
                iconSize: 11,
                pillPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                bgOpacityDark: 0.18,
                bgOpacityLight: 0.14,
                borderOpacity: 0.22,
                itemSpacing: 4,
              ),
            ),
            const SizedBox(width: 4),
            Builder(builder: (context) {
              final pinnedNow = context.select<SettingsProvider, bool>((s) => s.isModelPinned(m.providerKey, m.id));
              final icon = pinnedNow ? Icons.favorite : Icons.favorite_border;
              return Tooltip(
                message: l10n.modelSelectSheetFavoriteTooltip,
                child: IosIconButton(
                  icon: icon,
                  size: 16,
                  color: cs.primary,
                  onTap: () => context.read<SettingsProvider>().togglePinModel(m.providerKey, m.id),
                  padding: const EdgeInsets.all(3),
                  minSize: 26,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _favoritesHeader(BuildContext context, String title) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Row(
        children: [
          Icon(Lucide.Bookmark, size: 14, color: cs.onSurface.withOpacity(0.6)),
          const SizedBox(width: 6),
          Text(title, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: cs.onSurface.withOpacity(0.6))),
        ],
      ),
    );
  }

  Widget _providerHeader(BuildContext context, String? providerKey, String displayName) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Row(
        children: [
          Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: cs.onSurface.withOpacity(0.6)),
          ),
          const Spacer(),
          if (providerKey != null)
            Tooltip(
              message: AppLocalizations.of(context)!.settingsPageTitle,
              child: IosIconButton(
                icon: Lucide.Settings2,
                size: 16,
                color: cs.onSurface.withOpacity(0.8),
                onTap: () async {
                  final nav = Navigator.of(context);
                  // Close model dialog first
                  nav.pop();
                  // Then navigate to DesktopHomePage with Settings tab open and provider preselected
                  Future.microtask(() {
                    nav.push(
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => DesktopHomePage(initialTabIndex: 3, initialProviderKey: providerKey),
                        transitionDuration: const Duration(milliseconds: 220),
                        reverseTransitionDuration: const Duration(milliseconds: 200),
                        transitionsBuilder: (ctx, anim, sec, child) {
                          final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
                          return FadeTransition(opacity: curved, child: child);
                        },
                      ),
                    );
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _jumpToFavorites() async {
    // Ensure rows are current
    _rebuildRows();
    final idx = _headerIndexMap['__fav__'];
    if (idx == null) return;
    if (!_itemScrollController.isAttached) {
      Future.delayed(const Duration(milliseconds: 60), _jumpToFavorites);
      return;
    }
    try {
      await _itemScrollController.scrollTo(index: idx, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
    } catch (_) {}
  }
}

// (desktop tactile row removed in favor of IosCardPress for consistency)
