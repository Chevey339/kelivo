import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../icons/lucide_adapter.dart' as lucide;
import '../l10n/app_localizations.dart';
import '../core/providers/settings_provider.dart';
import '../core/providers/assistant_provider.dart';
import '../core/providers/model_provider.dart';

Future<bool?> showDesktopModelEditDialog(BuildContext context, {required String providerKey, required String modelId}) async {
  return _openDialog(context, providerKey: providerKey, modelId: modelId, isNew: false);
}

Future<bool?> showDesktopCreateModelDialog(BuildContext context, {required String providerKey}) async {
  return _openDialog(context, providerKey: providerKey, modelId: '', isNew: true);
}

Future<bool?> _openDialog(BuildContext context, {required String providerKey, required String modelId, required bool isNew}) async {
  bool? result;
  await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.25),
    barrierLabel: 'model-edit-dialog',
    pageBuilder: (ctx, _, __) => _ModelEditDialogBody(providerKey: providerKey, modelId: modelId, isNew: isNew),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(opacity: curved, child: ScaleTransition(scale: Tween<double>(begin: 0.98, end: 1).animate(curved), child: child));
    },
  ).then((v) => result = v);
  return result;
}

class _ModelEditDialogBody extends StatefulWidget {
  const _ModelEditDialogBody({required this.providerKey, required this.modelId, required this.isNew});
  final String providerKey;
  final String modelId;
  final bool isNew;
  @override
  State<_ModelEditDialogBody> createState() => _ModelEditDialogBodyState();
}

enum _TabKind { basic, advanced }

class _ModelEditDialogBodyState extends State<_ModelEditDialogBody> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  _TabKind _tab = _TabKind.basic;

  late TextEditingController _idCtrl;
  late TextEditingController _nameCtrl;
  bool _nameEdited = false;
  ModelType _type = ModelType.chat;
  final Set<Modality> _input = {Modality.text};
  final Set<Modality> _output = {Modality.text};
  final Set<ModelAbility> _abilities = {};
  final List<_HeaderKV> _headers = [];
  final List<_BodyKV> _bodies = [];
  bool _searchTool = false;
  bool _urlContextTool = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() { if (!_tabCtrl.indexIsChanging) setState(() => _tab = _tabCtrl.index == 0 ? _TabKind.basic : _TabKind.advanced); });
    _idCtrl = TextEditingController(text: widget.modelId);
    final settings = context.read<SettingsProvider>();
    final cfg = settings.getProviderConfig(widget.providerKey);
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
        final hdrs = (ov['headers'] as List?) ?? const [];
        for (final h in hdrs) { if (h is Map) { final kv = _HeaderKV(); kv.name.text = (h['name'] as String?) ?? ''; kv.value.text = (h['value'] as String?) ?? ''; _headers.add(kv); } }
        final bds = (ov['body'] as List?) ?? const [];
        for (final b in bds) { if (b is Map) { final kv = _BodyKV(); kv.keyCtrl.text = (b['key'] as String?) ?? ''; kv.valueCtrl.text = (b['value'] as String?) ?? ''; _bodies.add(kv); } }
        final tools = (ov['tools'] as Map?) ?? const {};
        _searchTool = (tools['search'] as bool?) ?? false;
        _urlContextTool = (tools['urlContext'] as bool?) ?? false;
      }
    }
  }

  // Desktop input decoration matching provider settings inputs
  InputDecoration _deskInputDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: isDark ? Colors.white10 : const Color(0xFFF7F7F9),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.12), width: 0.6)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.12), width: 0.6)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cs.primary.withOpacity(0.35), width: 0.8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 540, maxWidth: 880, maxHeight: 760),
        child: Material(
          color: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.08) : cs.outlineVariant.withOpacity(0.25)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  height: 52,
                  color: cs.surface,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 10, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.isNew ? l10n.modelDetailSheetAddModel : l10n.modelDetailSheetEditModel,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.mcpPageClose,
                          onPressed: () => Navigator.of(context).maybePop(false),
                          icon: Icon(lucide.Lucide.X, size: 20, color: cs.onSurface.withOpacity(0.9)),
                        ),
                      ],
                    ),
                  ),
                ),
                // Body
                Expanded(
                  child: Container(
                    color: cs.surface,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: _SegTabBar(controller: _tabCtrl, tabs: [l10n.modelDetailSheetBasicTab, l10n.modelDetailSheetAdvancedTab]),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            children: [
                              ..._buildTabContent(context, l10n),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Footer: right aligned confirm/add
                Container(
                  color: cs.surface,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      const Spacer(),
                      _PrimaryDeskButton(
                        icon: widget.isNew ? lucide.Lucide.Plus : lucide.Lucide.Check,
                        label: widget.isNew ? l10n.modelDetailSheetAddButton : l10n.modelDetailSheetConfirmButton,
                        onTap: _save,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTabContent(BuildContext context, AppLocalizations l10n) {
    switch (_tab) {
      case _TabKind.basic:
        return _buildBasic(context, l10n);
      case _TabKind.advanced:
        return _buildAdvanced(context, l10n);
    }
  }

  List<Widget> _buildBasic(BuildContext context, AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return [
      _label(context, l10n.modelDetailSheetModelIdLabel),
      const SizedBox(height: 6),
      TextField(
        controller: _idCtrl,
        enabled: true,
        onChanged: widget.isNew ? (v) { if (!_nameEdited) { _nameCtrl.text = v; setState(() {}); } } : null,
        decoration: _deskInputDecoration(context).copyWith(hintText: l10n.modelDetailSheetModelIdHint),
      ),
      const SizedBox(height: 12),
      _label(context, l10n.modelDetailSheetModelNameLabel),
      const SizedBox(height: 6),
      TextField(
        controller: _nameCtrl,
        onChanged: (_) { if (!_nameEdited) setState(() => _nameEdited = true); },
        decoration: _deskInputDecoration(context),
      ),
      const SizedBox(height: 12),
      _label(context, l10n.modelDetailSheetModelTypeLabel),
      const SizedBox(height: 6),
      _SegmentedSingle(options: [l10n.modelDetailSheetChatType, l10n.modelDetailSheetEmbeddingType], value: _type == ModelType.chat ? 0 : 1, onChanged: (i) => setState(() => _type = i == 0 ? ModelType.chat : ModelType.embedding)),
      if (_type == ModelType.chat) ...[
        const SizedBox(height: 12),
        _label(context, l10n.modelDetailSheetInputModesLabel),
        const SizedBox(height: 6),
        _SegmentedMulti(
          options: [l10n.modelDetailSheetTextMode, l10n.modelDetailSheetImageMode],
          isSelected: [_input.contains(Modality.text), _input.contains(Modality.image)],
          onChanged: (idx) => setState(() { final mod = idx == 0 ? Modality.text : Modality.image; if (_input.contains(mod)) _input.remove(mod); else _input.add(mod); }),
        ),
        const SizedBox(height: 12),
        _label(context, l10n.modelDetailSheetOutputModesLabel),
        const SizedBox(height: 6),
        _SegmentedMulti(
          options: [l10n.modelDetailSheetTextMode, l10n.modelDetailSheetImageMode],
          isSelected: [_output.contains(Modality.text), _output.contains(Modality.image)],
          onChanged: (idx) => setState(() { final mod = idx == 0 ? Modality.text : Modality.image; if (_output.contains(mod)) _output.remove(mod); else _output.add(mod); }),
        ),
        const SizedBox(height: 12),
        _label(context, l10n.modelDetailSheetAbilitiesLabel),
        const SizedBox(height: 6),
        _SegmentedMulti(
          options: [l10n.modelDetailSheetToolsAbility, l10n.modelDetailSheetReasoningAbility],
          isSelected: [_abilities.contains(ModelAbility.tool), _abilities.contains(ModelAbility.reasoning)],
          onChanged: (idx) => setState(() { final ab = idx == 0 ? ModelAbility.tool : ModelAbility.reasoning; if (_abilities.contains(ab)) _abilities.remove(ab); else _abilities.add(ab); }),
        ),
      ],
    ];
  }

  List<Widget> _buildAdvanced(BuildContext context, AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return [
      Text(l10n.modelDetailSheetCustomHeadersTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      for (final h in _headers)
        _HeaderRow(
          kv: h,
          onDelete: () => setState(() => _headers.remove(h)),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: _OutlinedAddButton(label: l10n.modelDetailSheetAddHeader, onTap: () => setState(() => _headers.add(_HeaderKV()))),
      ),
      const SizedBox(height: 16),
      Text(l10n.modelDetailSheetCustomBodyTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      for (final b in _bodies)
        _BodyRow(
          kv: b,
          onDelete: () => setState(() => _bodies.remove(b)),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: _OutlinedAddButton(label: l10n.modelDetailSheetAddBody, onTap: () => setState(() => _bodies.add(_BodyKV()))),
      ),
    ];
  }

  Widget _label(BuildContext context, String text) => Text(text, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8)));

  Future<void> _save() async {
    final settings = context.read<SettingsProvider>();
    final old = settings.getProviderConfig(widget.providerKey);
    final String prevId = widget.modelId;
    String id = _idCtrl.text.trim();
    if (id.isEmpty || id.length < 2 || id.contains(' ')) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.modelDetailSheetInvalidIdError), backgroundColor: Theme.of(context).colorScheme.error));
      return;
    }
    if (old.models.contains(id) && id != prevId) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.modelDetailSheetModelIdExistsError), backgroundColor: Theme.of(context).colorScheme.error));
      return;
    }
    final ov = Map<String, dynamic>.from(old.modelOverrides);
    final headers = [for (final h in _headers) if (h.name.text.trim().isNotEmpty) {'name': h.name.text.trim(), 'value': h.value.text}];
    final bodies = [for (final b in _bodies) if (b.keyCtrl.text.trim().isNotEmpty) {'key': b.keyCtrl.text.trim(), 'value': b.valueCtrl.text}];
    ov[id] = {
      'name': _nameCtrl.text.trim(),
      'type': _type == ModelType.chat ? 'chat' : 'embedding',
      'input': _input.map((e) => e == Modality.image ? 'image' : 'text').toList(),
      'output': _output.map((e) => e == Modality.image ? 'image' : 'text').toList(),
      'abilities': _abilities.map((e) => e == ModelAbility.reasoning ? 'reasoning' : 'tool').toList(),
      'headers': headers,
      'body': bodies,
    };
    if (id != prevId && ov.containsKey(prevId)) ov.remove(prevId);

    if (prevId.isEmpty || widget.isNew) {
      final list = old.models.toList()..add(id);
      await settings.setProviderConfig(widget.providerKey, old.copyWith(modelOverrides: ov, models: list));
    } else if (id != prevId) {
      final list = <String>[for (final m in old.models) m == prevId ? id : m];
      await settings.setProviderConfig(widget.providerKey, old.copyWith(modelOverrides: ov, models: list));
      if (settings.currentModelProvider == widget.providerKey && settings.currentModelId == prevId) {
        await settings.setCurrentModel(widget.providerKey, id);
      }
      if (settings.titleModelProvider == widget.providerKey && settings.titleModelId == prevId) {
        await settings.setTitleModel(widget.providerKey, id);
      }
      if (settings.translateModelProvider == widget.providerKey && settings.translateModelId == prevId) {
        await settings.setTranslateModel(widget.providerKey, id);
      }
      if (settings.isModelPinned(widget.providerKey, prevId)) {
        await settings.togglePinModel(widget.providerKey, prevId);
        if (!settings.isModelPinned(widget.providerKey, id)) {
          await settings.togglePinModel(widget.providerKey, id);
        }
      }
      try {
        final ap = context.read<AssistantProvider>();
        for (final a in ap.assistants) {
          if (a.chatModelProvider == widget.providerKey && a.chatModelId == prevId) {
            await ap.updateAssistant(a.copyWith(chatModelId: id));
          }
        }
      } catch (_) {}
    } else {
      await settings.setProviderConfig(widget.providerKey, old.copyWith(modelOverrides: ov));
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }
}

class _PrimaryDeskButton extends StatefulWidget {
  const _PrimaryDeskButton({required this.label, required this.onTap, this.icon});
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  @override
  State<_PrimaryDeskButton> createState() => _PrimaryDeskButtonState();
}

class _PrimaryDeskButtonState extends State<_PrimaryDeskButton> {
  bool _hover = false;
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = _pressed ? cs.primary.withOpacity(0.85) : (_hover ? cs.primary.withOpacity(0.92) : cs.primary);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon!, size: 16, color: cs.onPrimary),
                const SizedBox(width: 8),
              ],
              Text(widget.label, style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentedSingle extends StatelessWidget {
  const _SegmentedSingle({required this.options, required this.value, required this.onChanged});
  final List<String> options;
  final int value;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selBg = isDark ? cs.primary.withOpacity(0.20) : cs.primary.withOpacity(0.12);
    final baseBg = isDark ? Colors.white10 : const Color(0xFFF7F7F9);
    final children = <Widget>[];
    for (int i = 0; i < options.length; i++) {
      final selected = i == value;
      children.add(
        Expanded(
          child: InkWell(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? selBg : baseBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: selected ? cs.primary.withOpacity(0.35) : cs.outlineVariant.withOpacity(0.35)),
              ),
              alignment: Alignment.center,
              child: Text(
                options[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: selected ? cs.primary : cs.onSurface.withOpacity(0.82), fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      );
      if (i != options.length - 1) children.add(const SizedBox(width: 8));
    }
    return Row(children: children);
  }
}

class _SegmentedMulti extends StatelessWidget {
  const _SegmentedMulti({required this.options, required this.isSelected, required this.onChanged});
  final List<String> options;
  final List<bool> isSelected;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selBg = isDark ? cs.primary.withOpacity(0.20) : cs.primary.withOpacity(0.12);
    final baseBg = isDark ? Colors.white10 : const Color(0xFFF7F7F9);
    final children = <Widget>[];
    for (int i = 0; i < options.length; i++) {
      final selected = isSelected[i];
      children.add(
        Expanded(
          child: InkWell(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? selBg : baseBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: selected ? cs.primary.withOpacity(0.35) : cs.outlineVariant.withOpacity(0.35)),
              ),
              alignment: Alignment.center,
              child: Text(options[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: selected ? cs.primary : cs.onSurface.withOpacity(0.82), fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      );
      if (i != options.length - 1) children.add(const SizedBox(width: 8));
    }
    return Row(children: children);
  }
}

class _OutlinedAddButton extends StatefulWidget {
  const _OutlinedAddButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  State<_OutlinedAddButton> createState() => _OutlinedAddButtonState();
}

class _OutlinedAddButtonState extends State<_OutlinedAddButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final border = BorderSide(color: cs.primary.withOpacity(0.5));
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hover ? cs.primary.withOpacity(0.06) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.fromBorderSide(border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(lucide.Lucide.Plus, size: 16, color: cs.primary),
            const SizedBox(width: 6),
            Text(widget.label, style: TextStyle(color: cs.primary)),
          ]),
        ),
      ),
    );
  }
}

class _HeaderKV { final TextEditingController name = TextEditingController(); final TextEditingController value = TextEditingController(); }
class _BodyKV { final TextEditingController keyCtrl = TextEditingController(); final TextEditingController valueCtrl = TextEditingController(); }

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.kv, required this.onDelete});
  final _HeaderKV kv;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: kv.name,
              decoration: InputDecoration(
                hintText: l10n.modelDetailSheetHeaderKeyHint,
                filled: true,
                fillColor: isDark ? Colors.white10 : const Color(0xFFF7F7F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.12), width: 0.6)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.12), width: 0.6)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cs.primary.withOpacity(0.35), width: 0.8)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: kv.value,
              decoration: InputDecoration(
                hintText: l10n.modelDetailSheetHeaderValueHint,
                filled: true,
                fillColor: isDark ? Colors.white10 : const Color(0xFFF7F7F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.12), width: 0.6)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.12), width: 0.6)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cs.primary.withOpacity(0.35), width: 0.8)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
          IconButton(icon: Icon(lucide.Lucide.Trash2, size: 18, color: cs.onSurface.withOpacity(0.8)), onPressed: onDelete),
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
      child: Column(children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: kv.keyCtrl,
              decoration: InputDecoration(
                hintText: l10n.modelDetailSheetBodyKeyHint,
                filled: true,
                fillColor: isDark ? Colors.white10 : const Color(0xFFF7F7F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.12), width: 0.6)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.12), width: 0.6)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cs.primary.withOpacity(0.35), width: 0.8)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
          IconButton(icon: Icon(lucide.Lucide.Trash2, size: 18, color: cs.onSurface.withOpacity(0.8)), onPressed: onDelete),
        ]),
        const SizedBox(height: 8),
        TextField(
          controller: kv.valueCtrl,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(
            hintText: l10n.modelDetailSheetBodyJsonHint,
            filled: true,
            fillColor: isDark ? Colors.white10 : const Color(0xFFF7F7F9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.12), width: 0.6)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.12), width: 0.6)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cs.primary.withOpacity(0.35), width: 0.8)),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ]),
    );
  }
}

class _ToolTile extends StatefulWidget {
  const _ToolTile({required this.title, required this.desc, required this.value, required this.onChanged});
  final String title;
  final String desc;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  State<_ToolTile> createState() => _ToolTileState();
}

class _ToolTileState extends State<_ToolTile> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: _hover ? (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.03)) : (isDark ? Colors.white10 : const Color(0xFFF2F3F5)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(widget.desc, style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.7))),
            ]),
          ),
          Switch.adaptive(value: widget.value, onChanged: widget.onChanged),
        ]),
      ),
    );
  }
}

class _SegTabBar extends StatelessWidget {
  const _SegTabBar({required this.controller, required this.tabs});
  final TabController controller;
  final List<String> tabs;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    const double outerHeight = 40;
    const double innerPadding = 4;
    const double gap = 6;
    const double minSegWidth = 88;
    final double pillRadius = 14;
    final double innerRadius = ((pillRadius - innerPadding).clamp(0.0, pillRadius)).toDouble();
    return LayoutBuilder(builder: (context, constraints) {
      final double availWidth = constraints.maxWidth;
      final double innerAvailWidth = availWidth - innerPadding * 2;
      final double segWidth = (innerAvailWidth - gap * (tabs.length - 1)) / tabs.length;
      final double rowWidth = segWidth * tabs.length + gap * (tabs.length - 1);
      final Color shellBg = isDark ? Colors.white.withOpacity(0.08) : Colors.white;
      List<Widget> children = [];
      for (int index = 0; index < tabs.length; index++) {
        final bool selected = controller.index == index;
        children.add(SizedBox(
          width: segWidth < minSegWidth ? minSegWidth : segWidth,
          height: double.infinity,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => controller.index = index,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(color: selected ? cs.primary.withOpacity(0.14) : Colors.transparent, borderRadius: BorderRadius.circular(innerRadius)),
              alignment: Alignment.center,
              child: Text(tabs[index], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: selected ? cs.primary : cs.onSurface.withOpacity(0.82), fontWeight: FontWeight.w600)),
            ),
          ),
        ));
        if (index != tabs.length - 1) children.add(const SizedBox(width: gap));
      }
      return Container(
        height: outerHeight,
        decoration: BoxDecoration(color: shellBg, borderRadius: BorderRadius.circular(pillRadius)),
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
    });
  }
}
