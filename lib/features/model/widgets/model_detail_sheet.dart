import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/model_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_tile_button.dart';

Future<bool?> showModelDetailSheet(BuildContext context, {required String providerKey, required String modelId}) {
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _ModelDetailSheet(providerKey: providerKey, modelId: modelId, isNew: false),
      ),
    ),
  );
}

Future<bool?> showCreateModelSheet(BuildContext context, {required String providerKey}) {
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _ModelDetailSheet(providerKey: providerKey, modelId: '', isNew: true),
      ),
    ),
  );
}

class _ModelDetailSheet extends StatefulWidget {
  const _ModelDetailSheet({required this.providerKey, required this.modelId, this.isNew = false});
  final String providerKey;
  final String modelId;
  final bool isNew;
  @override
  State<_ModelDetailSheet> createState() => _ModelDetailSheetState();
}

enum _TabKind { basic, advanced, tools }

class _ModelDetailSheetState extends State<_ModelDetailSheet> with SingleTickerProviderStateMixin {
  _TabKind _tab = _TabKind.basic;
  late final TabController _tabCtrl;

  late TextEditingController _idCtrl;
  late TextEditingController _nameCtrl;
  bool _nameEdited = false;
  ModelType _type = ModelType.chat;
  final Set<Modality> _input = {Modality.text};
  final Set<Modality> _output = {Modality.text};
  final Set<ModelAbility> _abilities = {};

  // Advanced (UI only)
  final List<_HeaderKV> _headers = [];
  final List<_BodyKV> _bodies = [];
  bool _searchTool = false;
  bool _urlContextTool = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      if (_tabCtrl.indexIsChanging) return;
      setState(() {
        _tab = (_tabCtrl.index == 0) ? _TabKind.basic : _TabKind.advanced;
      });
    });
    _idCtrl = TextEditingController(text: widget.modelId);
    final settings = context.read<SettingsProvider>();
    final cfg = settings.getProviderConfig(widget.providerKey);
    // Defaults from inferred base if id provided; otherwise generic defaults for new
    final base = ModelRegistry.infer(ModelInfo(id: widget.modelId.isEmpty ? 'custom' : widget.modelId, displayName: widget.modelId.isEmpty ? '' : widget.modelId));
    _nameCtrl = TextEditingController(text: base.displayName);
    _type = base.type;
    _input..clear()..addAll(base.input);
    _output..clear()..addAll(base.output);
    _abilities..clear()..addAll(base.abilities);

    if (!widget.isNew) {
      final ov = cfg.modelOverrides[widget.modelId] as Map?;
      if (ov != null) {
        _nameCtrl.text = (ov['name'] as String?)?.trim().isNotEmpty == true ? (ov['name'] as String) : _nameCtrl.text;
        final t = (ov['type'] as String?) ?? '';
        if (t == 'embedding') _type = ModelType.embedding; else if (t == 'chat') _type = ModelType.chat;
        final inArr = (ov['input'] as List?)?.map((e) => e.toString()).toList() ?? [];
        final outArr = (ov['output'] as List?)?.map((e) => e.toString()).toList() ?? [];
        final abArr = (ov['abilities'] as List?)?.map((e) => e.toString()).toList() ?? [];
        _input..clear()..addAll(inArr.map((e) => e == 'image' ? Modality.image : Modality.text));
        _output..clear()..addAll(outArr.map((e) => e == 'image' ? Modality.image : Modality.text));
        _abilities..clear()..addAll(abArr.map((e) => e == 'reasoning' ? ModelAbility.reasoning : ModelAbility.tool));
        // headers/body
        final hdrs = (ov['headers'] as List?) ?? const [];
        for (final h in hdrs) {
          if (h is Map) {
            final kv = _HeaderKV();
            kv.name.text = (h['name'] as String?) ?? '';
            kv.value.text = (h['value'] as String?) ?? '';
            _headers.add(kv);
          }
        }
        final bds = (ov['body'] as List?) ?? const [];
        for (final b in bds) {
          if (b is Map) {
            final kv = _BodyKV();
            kv.keyCtrl.text = (b['key'] as String?) ?? '';
            kv.valueCtrl.text = (b['value'] as String?) ?? '';
            _bodies.add(kv);
          }
        }
        // tools toggles
        final tools = (ov['tools'] as Map?) ?? const {};
        _searchTool = (tools['search'] as bool?) ?? false;
        _urlContextTool = (tools['urlContext'] as bool?) ?? false;
      }
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _idCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (c, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(999))),
            const SizedBox(height: 8),
            _buildHeader(context, l10n),
            _buildTabs(context, l10n),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.zero,
                children: [
                  ..._buildTabContent(context, l10n),
                  const SizedBox(height: 12),
                  SizedBox(height: MediaQuery.of(context).padding.bottom),
                ],
              ),
            ),
            _buildFooter(context, l10n),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            IosIconButton(
              icon: Lucide.X,
              size: 22,
              color: cs.onSurface,
              minSize: 36,
              onTap: () => Navigator.of(context, rootNavigator: true).pop(false),
              semanticLabel: l10n.modelDetailSheetCancelButton,
            ),
            Expanded(
              child: Center(
                child: Text(
                  widget.isNew ? l10n.modelDetailSheetAddModel : l10n.modelDetailSheetEditModel,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            // Right spacer to balance title centering
            const SizedBox(width: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs(BuildContext context, AppLocalizations l10n) {
    // iOS segmented tabs like provider add sheet
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _SegTabBar(
        controller: _tabCtrl,
        tabs: [l10n.modelDetailSheetBasicTab, l10n.modelDetailSheetAdvancedTab],
      ),
    );
  }

  List<Widget> _buildTabContent(BuildContext context, AppLocalizations l10n) {
    switch (_tab) {
      case _TabKind.basic:
        return _buildBasic(context, l10n);
      case _TabKind.advanced:
        return _buildAdvanced(context, l10n);
      case _TabKind.tools:
        return _buildTools(context, l10n);
    }
  }

  List<Widget> _buildBasic(BuildContext context, AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(context, l10n.modelDetailSheetModelIdLabel),
            const SizedBox(height: 6),
            TextField(
              controller: _idCtrl,
              enabled: true, // allow editing existing model ID
              onChanged: widget.isNew
                  ? (v) {
                      if (!_nameEdited) {
                        _nameCtrl.text = v;
                        setState(() {});
                      }
                    }
                  : null,
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.white,
                hintText: l10n.modelDetailSheetModelIdHint,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5))),
              ),
            ),
            const SizedBox(height: 12),
            _label(context, l10n.modelDetailSheetModelNameLabel),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              onChanged: (_) {
                if (!_nameEdited) setState(() => _nameEdited = true);
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5))),
              ),
            ),
            const SizedBox(height: 12),
            _label(context, l10n.modelDetailSheetModelTypeLabel),
            const SizedBox(height: 6),
            _SegmentedSingle(
              options: [l10n.modelDetailSheetChatType, l10n.modelDetailSheetEmbeddingType],
              value: _type == ModelType.chat ? 0 : 1,
              onChanged: (i) => setState(() => _type = i == 0 ? ModelType.chat : ModelType.embedding),
            ),
          ],
        ),
      ),
      if (_type == ModelType.chat)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label(context, l10n.modelDetailSheetInputModesLabel),
              const SizedBox(height: 6),
              _SegmentedMulti(
                options: [l10n.modelDetailSheetTextMode, l10n.modelDetailSheetImageMode],
                isSelected: [
                  _input.contains(Modality.text),
                  _input.contains(Modality.image),
                ],
                onChanged: (idx) => setState(() {
                  final mod = idx == 0 ? Modality.text : Modality.image;
                  if (_input.contains(mod)) {
                    _input.remove(mod);
                    if (_input.isEmpty) _input.add(Modality.text);
                  } else {
                    _input.add(mod);
                  }
                }),
              ),
              const SizedBox(height: 12),
              _label(context, l10n.modelDetailSheetOutputModesLabel),
              const SizedBox(height: 6),
              _SegmentedMulti(
                options: [l10n.modelDetailSheetTextMode, l10n.modelDetailSheetImageMode],
                isSelected: [
                  _output.contains(Modality.text),
                  _output.contains(Modality.image),
                ],
                onChanged: (idx) => setState(() {
                  final mod = idx == 0 ? Modality.text : Modality.image;
                  if (_output.contains(mod)) {
                    _output.remove(mod);
                    if (_output.isEmpty) _output.add(Modality.text);
                  } else {
                    _output.add(mod);
                  }
                }),
              ),
              const SizedBox(height: 12),
              _label(context, l10n.modelDetailSheetAbilitiesLabel),
              const SizedBox(height: 6),
              _SegmentedMulti(
                options: [l10n.modelDetailSheetToolsAbility, l10n.modelDetailSheetReasoningAbility],
                isSelected: [
                  _abilities.contains(ModelAbility.tool),
                  _abilities.contains(ModelAbility.reasoning),
                ],
                allowEmpty: true,
                onChanged: (idx) => setState(() {
                  final ab = idx == 0 ? ModelAbility.tool : ModelAbility.reasoning;
                  if (_abilities.contains(ab)) {
                    _abilities.remove(ab);
                  } else {
                    _abilities.add(ab);
                  }
                }),
              ),
            ],
          ),
        ),
    ];
  }

  List<Widget> _buildAdvanced(BuildContext context, AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.modelDetailSheetProviderOverrideDescription,
              style: TextStyle(color: cs.onSurface.withOpacity(0.8), fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Center(
              child: _OutlinedAddButton(
                label: l10n.modelDetailSheetAddProviderOverride,
                onTap: () {},
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Text(l10n.modelDetailSheetCustomHeadersTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          children: [
            for (int i = 0; i < _headers.length; i++) _HeaderRow(kv: _headers[i], onDelete: () => setState(() => _headers.removeAt(i))),
            const SizedBox(height: 8),
            _OutlinedAddButton(
              label: l10n.modelDetailSheetAddHeader,
              onTap: () => setState(() => _headers.add(_HeaderKV())),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Text(l10n.modelDetailSheetCustomBodyTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          children: [
            for (int i = 0; i < _bodies.length; i++) _BodyRow(kv: _bodies[i], onDelete: () => setState(() => _bodies.removeAt(i))),
            const SizedBox(height: 8),
            _OutlinedAddButton(
              label: l10n.modelDetailSheetAddBody,
              onTap: () => setState(() => _bodies.add(_BodyKV())),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildTools(BuildContext context, AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Text(
          l10n.modelDetailSheetBuiltinToolsDescription,
          style: TextStyle(color: cs.onSurface.withOpacity(0.8), fontSize: 13),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: _ToolTile(
          title: l10n.modelDetailSheetSearchTool,
          desc: l10n.modelDetailSheetSearchToolDescription,
          value: _searchTool,
          onChanged: (v) => setState(() => _searchTool = v),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: _ToolTile(
          title: l10n.modelDetailSheetUrlContextTool,
          desc: l10n.modelDetailSheetUrlContextToolDescription,
          value: _urlContextTool,
          onChanged: (v) => setState(() => _urlContextTool = v),
        ),
      ),
    ];
  }

  Widget _buildFooter(BuildContext context, AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 10 + MediaQuery.of(context).padding.bottom),
      child: SizedBox(
        width: double.infinity,
        child: IosTileButton(
          icon: widget.isNew ? Lucide.Plus : Lucide.Check,
          label: widget.isNew ? l10n.modelDetailSheetAddButton : l10n.modelDetailSheetConfirmButton,
          backgroundColor: cs.primary,
          onTap: _save,
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Text(text, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8)));

  Color _segSelectedColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? cs.primary.withOpacity(0.20) : cs.primary.withOpacity(0.14);
  }

  Future<void> _save() async {
    final settings = context.read<SettingsProvider>();
    final old = settings.getProviderConfig(widget.providerKey);
    // Determine target ID (allow editing even when not new)
    final String prevId = widget.modelId;
    String id = _idCtrl.text.trim();
    // Basic validation
    if (id.isEmpty || id.length < 2 || id.contains(' ')) {
      final l10n = AppLocalizations.of(context)!;
      showAppSnackBar(
        context,
        message: l10n.modelDetailSheetInvalidIdError,
        type: NotificationType.error,
      );
      return;
    }
    // Prevent duplicate IDs in models list (except self when unchanged)
    if (old.models.contains(id) && id != prevId) {
      final l10n = AppLocalizations.of(context)!;
      showAppSnackBar(
        context,
        message: l10n.modelDetailSheetModelIdExistsError,
        type: NotificationType.error,
      );
      return;
    }

    final ov = Map<String, dynamic>.from(old.modelOverrides);
    final headers = [
      for (final h in _headers)
        if (h.name.text.trim().isNotEmpty)
          {'name': h.name.text.trim(), 'value': h.value.text}
    ];
    final bodies = [
      for (final b in _bodies)
        if (b.keyCtrl.text.trim().isNotEmpty)
          {'key': b.keyCtrl.text.trim(), 'value': b.valueCtrl.text}
    ];
    final abilitiesList = _abilities.map((e) => e == ModelAbility.reasoning ? 'reasoning' : 'tool').toList();
    debugPrint('[Model Save] id=$id, abilities=$abilitiesList, _abilities=$_abilities');

    ov[id] = {
      'name': _nameCtrl.text.trim(),
      'type': _type == ModelType.chat ? 'chat' : 'embedding',
      'input': _input.map((e) => e == Modality.image ? 'image' : 'text').toList(),
      'output': _output.map((e) => e == Modality.image ? 'image' : 'text').toList(),
      'abilities': abilitiesList,
      'headers': headers,
      'body': bodies,
      'tools': {
        'search': _searchTool,
        'urlContext': _urlContextTool,
      },
    };
    // When editing, remove old override key if ID changed
    if (id != prevId && ov.containsKey(prevId)) {
      ov.remove(prevId);
    }

    // Apply updates to provider config
    if (prevId.isEmpty || widget.isNew) {
      // Creating a new model
      final list = old.models.toList()..add(id);
      await settings.setProviderConfig(widget.providerKey, old.copyWith(modelOverrides: ov, models: list));
    } else if (id != prevId) {
      // Renaming existing model ID: update models list entry
      final list = <String>[for (final m in old.models) m == prevId ? id : m];
      await settings.setProviderConfig(widget.providerKey, old.copyWith(modelOverrides: ov, models: list));
      // Update selections referencing this model
      if (settings.currentModelProvider == widget.providerKey && settings.currentModelId == prevId) {
        await settings.setCurrentModel(widget.providerKey, id);
      }
      if (settings.titleModelProvider == widget.providerKey && settings.titleModelId == prevId) {
        await settings.setTitleModel(widget.providerKey, id);
      }
      if (settings.translateModelProvider == widget.providerKey && settings.translateModelId == prevId) {
        await settings.setTranslateModel(widget.providerKey, id);
      }
      // Update pinned models
      if (settings.isModelPinned(widget.providerKey, prevId)) {
        await settings.togglePinModel(widget.providerKey, prevId); // remove old
        if (!settings.isModelPinned(widget.providerKey, id)) {
          await settings.togglePinModel(widget.providerKey, id); // add new
        }
      }
      // Update assistants default model references
      try {
        final ap = context.read<AssistantProvider>();
        for (final a in ap.assistants) {
          if (a.chatModelProvider == widget.providerKey && a.chatModelId == prevId) {
            await ap.updateAssistant(a.copyWith(chatModelId: id));
          }
        }
      } catch (_) {}
    } else {
      // ID unchanged; just persist overrides
      await settings.setProviderConfig(widget.providerKey, old.copyWith(modelOverrides: ov));
    }
    if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(true);
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.label, required this.selected, this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = selected ? (isDark ? cs.primary.withOpacity(0.25) : cs.primary.withOpacity(0.15)) : Colors.transparent;
    final fg = selected ? (isDark ? cs.primary : cs.primary) : cs.onSurface.withOpacity(0.8);
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? cs.primary.withOpacity(0.25) : cs.outlineVariant.withOpacity(0.4), width: 1),
          ),
          child: Text(label, style: TextStyle(fontSize: 13, color: fg, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

class _SegmentedSingle extends StatelessWidget {
  const _SegmentedSingle({required this.options, required this.value, required this.onChanged});
  final List<String> options;
  final int value; // index
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color sel = isDark ? cs.primary.withOpacity(0.20) : cs.primary.withOpacity(0.14);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isDark ? Colors.white10 : const Color(0xFFF2F3F5),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          for (int i = 0; i < options.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: i == value ? sel : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (i == value) Padding(padding: const EdgeInsets.only(right: 6), child: Icon(Lucide.Check, size: 16, color: cs.primary)),
                      Text(options[i], style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentedMulti extends StatelessWidget {
  const _SegmentedMulti({
    required this.options,
    required this.isSelected,
    required this.onChanged,
    this.allowEmpty = false,
  });

  final List<String> options;
  final List<bool> isSelected;
  final ValueChanged<int> onChanged;
  final bool allowEmpty;

  @override
  Widget build(BuildContext context) {
    assert(options.length == isSelected.length);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool allSelected = isSelected.isNotEmpty && isSelected.every((e) => e);
    final int selectedCount = isSelected.where((e) => e).length;

    final base = isDark ? Colors.white10 : const Color(0xFFF2F3F5);
    final sel  = isDark ? cs.primary.withOpacity(0.20) : cs.primary.withOpacity(0.14);
    final r = BorderRadius.circular(12);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        color: base, // 外层始终用同一个“底色”
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.35)),
      ),
      child: ClipRRect( // 确保内部遮罩遵守圆角
        borderRadius: r,
        child: Stack(
          children: [
            // 全选时：在“同一个底色”上叠加一层 sel（与单选的叠加路径一致）
            if (allSelected)
              Positioned.fill(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  decoration: BoxDecoration(color: sel, borderRadius: r),
                ),
              ),
            Row(
              children: [
                for (int i = 0; i < options.length; i++)
                  Expanded(
                    child: InkWell(
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      onTap: () => onChanged(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          // 全选时子项透明，让上面的整条遮罩生效；
                          // 非全选时按原逻辑逐项着色
                          color: allSelected
                              ? Colors.transparent
                              : (isSelected[i] ? sel : Colors.transparent),
                          borderRadius: selectedCount == 1 && isSelected[i]
                              ? r
                              : i == 0
                              ? const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12))
                              : (i == options.length - 1
                              ? const BorderRadius.only(topRight: Radius.circular(12), bottomRight: Radius.circular(12))
                              : BorderRadius.zero),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isSelected[i])
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Icon(Lucide.Check, size: 16, color: cs.primary),
                              ),
                            Text(options[i], style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


class _HeaderKV {
  final TextEditingController name = TextEditingController();
  final TextEditingController value = TextEditingController();
}

class _BodyKV {
  final TextEditingController keyCtrl = TextEditingController();
  final TextEditingController valueCtrl = TextEditingController();
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.kv, required this.onDelete});
  final _HeaderKV kv;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: kv.name,
                  decoration: InputDecoration(
                    hintText: l10n.modelDetailSheetHeaderKeyHint,
                    filled: true,
                    fillColor: isDark ? Colors.white10 : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cs.primary.withOpacity(0.5))),
                  ),
                ),
              ),
              IosIconButton(
                icon: Lucide.Trash2,
                size: 20,
                color: cs.onSurface.withOpacity(0.8),
                onTap: onDelete,
                semanticLabel: 'Delete header',
                minSize: 40,
              )
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: kv.value,
            decoration: InputDecoration(
              hintText: l10n.modelDetailSheetHeaderValueHint,
              filled: true,
              fillColor: isDark ? Colors.white10 : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5))),
            ),
          ),
        ],
      ),
    );
  }
}

class _BodyRow extends StatelessWidget {
  const _BodyRow({required this.kv, required this.onDelete});
  final _BodyKV kv;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: kv.keyCtrl,
                  decoration: InputDecoration(
                    hintText: l10n.modelDetailSheetBodyKeyHint,
                    filled: true,
                    fillColor: isDark ? Colors.white10 : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5))),
                  ),
                ),
              ),
              IosIconButton(
                icon: Lucide.Trash2,
                size: 20,
                color: cs.onSurface.withOpacity(0.8),
                onTap: onDelete,
                semanticLabel: 'Delete entry',
                minSize: 40,
              )
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: kv.valueCtrl,
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: l10n.modelDetailSheetBodyJsonHint,
              filled: true,
              fillColor: isDark ? Colors.white10 : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5))),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.title, required this.desc, required this.value, required this.onChanged});
  final String title;
  final String desc;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? Colors.white10 : const Color(0xFFF2F3F5),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(desc, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
                ],
              ),
            ),
            IosSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _OutlinedAddButton extends StatelessWidget {
  const _OutlinedAddButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final border = BorderSide(color: cs.primary.withOpacity(0.5));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.fromBorderSide(border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Lucide.Plus, size: 18, color: cs.primary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: cs.primary)),
          ],
        ),
      ),
    );
  }
}

// Segmented tab bar matching provider add sheet style
class _SegTabBar extends StatelessWidget {
  const _SegTabBar({required this.controller, required this.tabs});
  final TabController controller;
  final List<String> tabs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    const double outerHeight = 44;
    const double innerPadding = 4;
    const double gap = 6;
    const double minSegWidth = 88;
    final double pillRadius = 18;
    final double innerRadius = ((pillRadius - innerPadding).clamp(0.0, pillRadius)).toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availWidth = constraints.maxWidth;
        final double innerAvailWidth = availWidth - innerPadding * 2;
        final double segWidth =
            (innerAvailWidth - gap * (tabs.length - 1)) / tabs.length;
        final double rowWidth = segWidth * tabs.length + gap * (tabs.length - 1);

        final Color shellBg = isDark ? Colors.white.withOpacity(0.08) : Colors.white;

        List<Widget> children = [];
        for (int index = 0; index < tabs.length; index++) {
          final bool selected = controller.index == index;
          children.add(
            SizedBox(
              width: segWidth < minSegWidth ? minSegWidth : segWidth,
              height: double.infinity,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => controller.index = index,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: selected ? cs.primary.withOpacity(0.14) : Colors.transparent,
                    borderRadius: BorderRadius.circular(innerRadius),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    tabs[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? cs.primary : cs.onSurface.withOpacity(0.82),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
          if (index != tabs.length - 1) children.add(const SizedBox(width: gap));
        }

        return Container(
          height: outerHeight,
          decoration: BoxDecoration(
            color: shellBg,
            borderRadius: BorderRadius.circular(pillRadius),
          ),
          clipBehavior: Clip.hardEdge,
          child: Padding(
            padding: const EdgeInsets.all(innerPadding),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: innerAvailWidth),
                child: SizedBox(width: rowWidth, child: Row(children: children)),
              ),
            ),
          ),
        );
      },
    );
  }
}
