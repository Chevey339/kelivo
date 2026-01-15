import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../icons/lucide_adapter.dart' as lucide;
import '../l10n/app_localizations.dart';
import '../core/providers/settings_provider.dart';
import '../core/providers/model_provider.dart';
import '../core/services/api/builtin_tools.dart';
import '../shared/widgets/ios_switch.dart';
import '../shared/widgets/snackbar.dart';
import '../features/model/widgets/model_edit_state_helper.dart';

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

enum _TabKind { basic, advanced, tools }

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
  // Session-only cache: allow user to flip chat -> embedding -> chat without losing chat settings.
  Set<Modality>? _cachedChatInput;
  Set<Modality>? _cachedChatOutput;
  Set<ModelAbility>? _cachedChatAbilities;
  // Session-only cache: allow user to flip chat <-> embedding without losing embedding input modes.
  Set<Modality>? _cachedEmbeddingInput;
  final List<_HeaderKV> _headers = [];
  final List<_BodyKV> _bodies = [];

  // Provider kind for conditional UI
  ProviderKind? _providerKind;

  // Google built-in tools
  bool _googleUrlContextTool = false;
  bool _googleCodeExecutionTool = false;
  bool _googleYoutubeTool = false;

  // OpenAI built-in tools
  bool _openaiCodeInterpreterTool = false;
  bool _openaiImageGenerationTool = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    final cfg = settings.getProviderConfig(widget.providerKey);
    _providerKind = cfg.providerType;

    // Determine tab count: 3 for Google/OpenAI (has tools tab), 2 for others
    final hasToolsTab = _providerKind == ProviderKind.google || _providerKind == ProviderKind.openai;
    _tabCtrl = TabController(length: hasToolsTab ? 3 : 2, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        setState(() {
          if (_tabCtrl.index == 0) {
            _tab = _TabKind.basic;
          } else if (_tabCtrl.index == 1) {
            _tab = _TabKind.advanced;
          } else {
            _tab = _TabKind.tools;
          }
        });
      }
    });

    // Resolve display model id from per-model overrides when present (apiModelId),
    // falling back to the logical key for backwards compatibility.
    Map? _initialOv;
    if (!widget.isNew) {
      final raw = cfg.modelOverrides[widget.modelId];
      if (raw is Map) _initialOv = raw;
    }
    String displayModelId = widget.modelId;
    if (_initialOv != null) {
      final raw = (_initialOv['apiModelId'] ?? _initialOv['api_model_id'])?.toString().trim();
      if (raw != null && raw.isNotEmpty) displayModelId = raw;
    }
    _idCtrl = TextEditingController(text: displayModelId);
    final base = ModelRegistry.infer(
      ModelInfo(
        id: displayModelId.isEmpty ? 'custom' : displayModelId,
        displayName: displayModelId.isEmpty ? '' : displayModelId,
      ),
    );
    _nameCtrl = TextEditingController(text: base.displayName);
    _type = base.type;
    _input..clear()..addAll(base.input);
    _output..clear()..addAll(base.output);
    _abilities..clear()..addAll(base.abilities);
    // Normalize embedding invariants on init even when there is no explicit override `type`.
    if (_type == ModelType.embedding) {
      _abilities.clear();
      _output
        ..clear()
        ..add(Modality.text);
      if (_input.isEmpty) _input.add(Modality.text);
      _cachedEmbeddingInput = {..._input};
    } else if (_type == ModelType.chat) {
      // Defensive: prevent invalid empty modality sets from being loaded.
      if (_input.isEmpty) _input.add(Modality.text);
      if (_output.isEmpty) _output.add(Modality.text);
    }

    if (!widget.isNew) {
      final rawOv = _initialOv ?? cfg.modelOverrides[widget.modelId];
      final Map<String, dynamic>? ov =
          rawOv is Map ? {for (final e in rawOv.entries) e.key.toString(): e.value} : null;
      if (ov != null) {
        final overrideName = ov['name']?.toString().trim();
        if (overrideName != null && overrideName.isNotEmpty) {
          _nameCtrl.text = overrideName;
        }
        final t = (ov['type'] ?? '').toString().trim().toLowerCase();
        if (t == 'embedding') {
          _setType(ModelType.embedding);
        } else if (t == 'chat') {
          _setType(ModelType.chat);
        }
        if (_type == ModelType.chat) {
          final inArr = (ov['input'] as List?)?.map((e) => e.toString()).toList() ?? [];
          final outArr = (ov['output'] as List?)?.map((e) => e.toString()).toList() ?? [];
          final abArr = (ov['abilities'] as List?)?.map((e) => e.toString()).toList() ?? [];
          _input..clear()..addAll(inArr.map((e) => e == 'image' ? Modality.image : Modality.text));
          _output..clear()..addAll(outArr.map((e) => e == 'image' ? Modality.image : Modality.text));
          _abilities..clear()..addAll(abArr.map((e) => e == 'reasoning' ? ModelAbility.reasoning : ModelAbility.tool));
          if (_input.isEmpty) _input.add(Modality.text);
          if (_output.isEmpty) _output.add(Modality.text);
        } else if (_type == ModelType.embedding) {
          // Embedding supports explicit input modalities (e.g., text/image). Abilities remain chat-only.
          final inArr = (ov['input'] as List?)?.map((e) => e.toString()).toList() ?? [];
          if (inArr.isNotEmpty) {
            _input..clear()..addAll(inArr.map((e) => e == 'image' ? Modality.image : Modality.text));
            if (_input.isEmpty) _input.add(Modality.text);
          }
        }
        final hdrs = (ov['headers'] as List?) ?? const [];
        for (final h in hdrs) { if (h is Map) { final kv = _HeaderKV(); kv.name.text = (h['name'] as String?) ?? ''; kv.value.text = (h['value'] as String?) ?? ''; _headers.add(kv); } }
        final bds = (ov['body'] as List?) ?? const [];
        for (final b in bds) { if (b is Map) { final kv = _BodyKV(); kv.keyCtrl.text = (b['key'] as String?) ?? ''; kv.valueCtrl.text = (b['value'] as String?) ?? ''; _bodies.add(kv); } }

        // Read built-in tools from builtInTools array
        final builtInSet = BuiltInToolNames.parseAndNormalize(ov['builtInTools']);
        // Google tools
        _googleUrlContextTool = builtInSet.contains(BuiltInToolNames.urlContext);
        _googleCodeExecutionTool = builtInSet.contains(BuiltInToolNames.codeExecution);
        _googleYoutubeTool = builtInSet.contains(BuiltInToolNames.youtube);
        // OpenAI tools
        _openaiCodeInterpreterTool = builtInSet.contains(BuiltInToolNames.codeInterpreter);
        _openaiImageGenerationTool = builtInSet.contains(BuiltInToolNames.imageGeneration);
      }
    }
  }

  void _setType(ModelType next) {
    final prev = _type;
    if (prev == next) return;

    _type = next;
    // Pass state-owned sets; helper mutates in place.
    final cache = ModelEditTypeSwitch.apply(
      prev: prev,
      next: next,
      input: _input,
      output: _output,
      abilities: _abilities,
      cachedChatInput: _cachedChatInput,
      cachedChatOutput: _cachedChatOutput,
      cachedChatAbilities: _cachedChatAbilities,
      cachedEmbeddingInput: _cachedEmbeddingInput,
    );
    _cachedChatInput = cache.cachedChatInput;
    _cachedChatOutput = cache.cachedChatOutput;
    _cachedChatAbilities = cache.cachedChatAbilities;
    _cachedEmbeddingInput = cache.cachedEmbeddingInput;
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
    for (final h in _headers) {
      h.name.dispose();
      h.value.dispose();
    }
    for (final b in _bodies) {
      b.keyCtrl.dispose();
      b.valueCtrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 540, maxWidth: 700, maxHeight: 650),
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
                          child: _SegTabBar(
                            controller: _tabCtrl,
                            tabs: [
                              l10n.modelDetailSheetBasicTab,
                              l10n.modelDetailSheetAdvancedTab,
                              if (_providerKind == ProviderKind.google || _providerKind == ProviderKind.openai)
                                l10n.modelDetailSheetBuiltinToolsTab,
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, anim) {
                              final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
                              return FadeTransition(
                                opacity: curved,
                                child: SlideTransition(
                                  position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(curved),
                                  child: child,
                                ),
                              );
                            },
                            child: ListView(
                              key: ValueKey(_tab),
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                              children: _buildTabContent(context, l10n),
                            ),
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
      case _TabKind.tools:
        return _buildTools(context, l10n);
    }
  }

  List<Widget> _buildBasic(BuildContext context, AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;
    return [
      _DeskCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(context, l10n.modelDetailSheetModelIdLabel),
            const SizedBox(height: 6),
            TextField(
              controller: _idCtrl,
              readOnly: !widget.isNew,
              enableInteractiveSelection: widget.isNew,
              style: TextStyle(color: widget.isNew ? null : cs.onSurface.withOpacity(0.6)),
              onChanged: widget.isNew
                  ? (v) {
                      if (!_nameEdited) {
                        _nameCtrl.text = v;
                        setState(() {});
                      }
                    }
                  : null,
              decoration: _deskInputDecoration(context).copyWith(
                hintText: l10n.modelDetailSheetModelIdHint,
                suffixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 40),
                suffixIcon: widget.isNew
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: _CopySuffixButton(
                          onTap: () {
                            final text = _idCtrl.text.trim();
                            if (text.isEmpty) return;
                            Clipboard.setData(ClipboardData(text: text));
                            showAppSnackBar(
                              context,
                              message: l10n.shareProviderSheetCopiedMessage,
                              type: NotificationType.success,
                            );
                          },
                          tooltip: l10n.shareProviderSheetCopyButton,
                          icon: lucide.Lucide.Copy,
                          color: cs.onSurface.withOpacity(0.9),
                          hoverColor: cs.onSurface.withOpacity(0.08),
                          pressedColor: cs.onSurface.withOpacity(0.12),
                        ),
                      ),
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
              decoration: _deskInputDecoration(context),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _DeskCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(context, l10n.modelDetailSheetModelTypeLabel),
            const SizedBox(height: 6),
            _SegmentedSingle(
              options: [l10n.modelDetailSheetChatType, l10n.modelDetailSheetEmbeddingType],
              value: _type == ModelType.chat ? 0 : 1,
              onChanged: (i) => setState(() => _setType(i == 0 ? ModelType.chat : ModelType.embedding)),
            ),
              const SizedBox(height: 12),
              _label(context, l10n.modelDetailSheetInputModesLabel),
              const SizedBox(height: 6),
              _SegmentedMulti(
                options: [l10n.modelDetailSheetTextMode, l10n.modelDetailSheetImageMode],
                isSelected: [_input.contains(Modality.text), _input.contains(Modality.image)],
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
            if (_type == ModelType.chat) ...[
              const SizedBox(height: 12),
              _label(context, l10n.modelDetailSheetOutputModesLabel),
              const SizedBox(height: 6),
              _SegmentedMulti(
                options: [l10n.modelDetailSheetTextMode, l10n.modelDetailSheetImageMode],
                isSelected: [_output.contains(Modality.text), _output.contains(Modality.image)],
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
                isSelected: [_abilities.contains(ModelAbility.tool), _abilities.contains(ModelAbility.reasoning)],
                onChanged: (idx) => setState(() {
                  final ab = idx == 0 ? ModelAbility.tool : ModelAbility.reasoning;
                  if (_abilities.contains(ab)) _abilities.remove(ab);
                  else _abilities.add(ab);
                }),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildAdvanced(BuildContext context, AppLocalizations l10n) {
    return [
      _DeskCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(l10n.modelDetailSheetCustomHeadersTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                _OutlinedAddButton(label: l10n.modelDetailSheetAddHeader, onTap: () => setState(() => _headers.add(_HeaderKV()))),
              ],
            ),
            if (_headers.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final h in _headers)
                _HeaderRow(
                  kv: h,
                  onDelete: () => setState(() {
                    h.name.dispose();
                    h.value.dispose();
                    _headers.remove(h);
                  }),
                ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      _DeskCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(l10n.modelDetailSheetCustomBodyTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                _OutlinedAddButton(label: l10n.modelDetailSheetAddBody, onTap: () => setState(() => _bodies.add(_BodyKV()))),
              ],
            ),
            if (_bodies.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final b in _bodies)
                _BodyRow(
                  kv: b,
                  onDelete: () => setState(() {
                    b.keyCtrl.dispose();
                    b.valueCtrl.dispose();
                    _bodies.remove(b);
                  }),
                ),
            ],
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildTools(BuildContext context, AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final cfg = settings.getProviderConfig(widget.providerKey);
    final bool disableTools = _type == ModelType.embedding;
    final bool hasTiles = _providerKind == ProviderKind.google || _providerKind == ProviderKind.openai;
    return [
      _DeskCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.modelDetailSheetBuiltinToolsDescription,
              style: TextStyle(color: cs.onSurface.withOpacity(0.8), fontSize: 13),
            ),
            if (_providerKind == ProviderKind.google) ...[
              const SizedBox(height: 6),
              Text(
                l10n.modelDetailSheetGeminiCodeExecutionMutuallyExclusiveHint,
                style: TextStyle(color: cs.onSurface.withOpacity(0.65), fontSize: 12),
              ),
            ] else if (_providerKind == ProviderKind.openai && cfg.useResponseApi != true) ...[
              const SizedBox(height: 6),
              Text(
                l10n.modelDetailSheetOpenaiBuiltinToolsResponsesOnlyHint,
                style: TextStyle(color: cs.onSurface.withOpacity(0.65), fontSize: 12),
              ),
            ] else if (!hasTiles) ...[
              const SizedBox(height: 6),
              Text(
                l10n.modelDetailSheetBuiltinToolsUnsupportedHint,
                style: TextStyle(color: cs.onSurface.withOpacity(0.65), fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      if (hasTiles) const SizedBox(height: 10),
      if (_providerKind == ProviderKind.google) ...[
        _ToolTile(
          title: l10n.modelDetailSheetUrlContextTool,
          desc: l10n.modelDetailSheetUrlContextToolDescription,
          value: _googleUrlContextTool,
          // URL Context is disabled when Code Execution is enabled (mutually exclusive)
          onChanged: disableTools
              ? null
              : (_googleCodeExecutionTool ? null : (v) => setState(() => _googleUrlContextTool = v)),
        ),
        const SizedBox(height: 8),
        _ToolTile(
          title: l10n.modelDetailSheetCodeExecutionTool,
          desc: l10n.modelDetailSheetCodeExecutionToolDescription,
          value: _googleCodeExecutionTool,
          // Code Execution is disabled when URL Context is enabled (mutually exclusive)
          onChanged: disableTools
              ? null
              : (_googleUrlContextTool ? null : (v) => setState(() => _googleCodeExecutionTool = v)),
        ),
        const SizedBox(height: 8),
        _ToolTile(
          title: l10n.modelDetailSheetYoutubeTool,
          desc: l10n.modelDetailSheetYoutubeToolDescription,
          value: _googleYoutubeTool,
          onChanged: disableTools ? null : (v) => setState(() => _googleYoutubeTool = v),
        ),
      ] else if (_providerKind == ProviderKind.openai) ...[
        _ToolTile(
          title: l10n.modelDetailSheetOpenaiCodeInterpreterTool,
          desc: l10n.modelDetailSheetOpenaiCodeInterpreterToolDescription,
          value: _openaiCodeInterpreterTool,
          onChanged: disableTools
              ? null
              : ((cfg.useResponseApi == true)
                  ? (v) => setState(() => _openaiCodeInterpreterTool = v)
                  : null),
        ),
        const SizedBox(height: 8),
        _ToolTile(
          title: l10n.modelDetailSheetOpenaiImageGenerationTool,
          desc: l10n.modelDetailSheetOpenaiImageGenerationToolDescription,
          value: _openaiImageGenerationTool,
          onChanged: disableTools
              ? null
              : ((cfg.useResponseApi == true)
                  ? (v) => setState(() => _openaiImageGenerationTool = v)
                  : null),
        ),
      ],
    ];
  }

  Widget _label(BuildContext context, String text) => Text(text, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8)));

  // Generate a unique logical key for a model instance within a provider.
  // This allows multiple configurations to share the same upstream API model id.
  String _nextModelKey(ProviderConfig cfg, String apiModelId) {
    final existing = <String>{...cfg.models, ...cfg.modelOverrides.keys};
    if (!existing.contains(apiModelId)) return apiModelId;
    int i = 2;
    while (true) {
      final candidate = '$apiModelId#$i';
      if (!existing.contains(candidate)) return candidate;
      i++;
    }
  }

  Future<void> _save() async {
    final settings = context.read<SettingsProvider>();
    final old = settings.getProviderConfig(widget.providerKey);
    final String prevKey = widget.modelId;
    final String apiModelId = _idCtrl.text.trim();
    if (apiModelId.isEmpty || apiModelId.length < 2) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.modelDetailSheetInvalidIdError), backgroundColor: Theme.of(context).colorScheme.error));
      return;
    }
    final ov = Map<String, dynamic>.from(old.modelOverrides);
    final headers = [for (final h in _headers) if (h.name.text.trim().isNotEmpty) {'name': h.name.text.trim(), 'value': h.value.text}];
    final bodies = [for (final b in _bodies) if (b.keyCtrl.text.trim().isNotEmpty) {'key': b.keyCtrl.text.trim(), 'value': b.valueCtrl.text}];

    // Build builtInTools list based on provider type
    final builtInTools = <String>[];
    if (_providerKind == ProviderKind.google) {
      if (_googleUrlContextTool) builtInTools.add(BuiltInToolNames.urlContext);
      if (_googleCodeExecutionTool) builtInTools.add(BuiltInToolNames.codeExecution);
      if (_googleYoutubeTool) builtInTools.add(BuiltInToolNames.youtube);
    } else if (_providerKind == ProviderKind.openai) {
      if (_openaiCodeInterpreterTool) builtInTools.add(BuiltInToolNames.codeInterpreter);
      if (_openaiImageGenerationTool) builtInTools.add(BuiltInToolNames.imageGeneration);
    }

    final String key = (prevKey.isEmpty || widget.isNew) ? _nextModelKey(old, apiModelId) : prevKey;
    final bool isEmbedding = _type == ModelType.embedding;
    ov[key] = {
      'apiModelId': apiModelId,
      'name': _nameCtrl.text.trim(),
      'type': _type == ModelType.chat ? 'chat' : 'embedding',
      // Input modalities are configurable for both chat and embedding.
      'input': _input.map((e) => e == Modality.image ? 'image' : 'text').toList(),
      if (!isEmbedding)
      'output': _output.map((e) => e == Modality.image ? 'image' : 'text').toList(),
      if (!isEmbedding)
      'abilities': _abilities.map((e) => e == ModelAbility.reasoning ? 'reasoning' : 'tool').toList(),
      'headers': headers,
      'body': bodies,
      if (!isEmbedding) 'builtInTools': builtInTools,
    };

    if (prevKey.isEmpty || widget.isNew) {
      final list = old.models.toList()..add(key);
      await settings.setProviderConfig(widget.providerKey, old.copyWith(modelOverrides: ov, models: list));
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
            mouseCursor: SystemMouseCursors.click,
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
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
            mouseCursor: SystemMouseCursors.click,
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
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
  final ValueChanged<bool>? onChanged;
  @override
  State<_ToolTile> createState() => _ToolTileState();
}

class _ToolTileState extends State<_ToolTile> {
  bool _hover = false;
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final bool isDisabled = widget.onChanged == null;
    final baseBg = isDark ? Colors.white10 : const Color(0xFFF2F3F5);
    final hoverBg = Color.alphaBlend(cs.primary.withOpacity(isDark ? 0.10 : 0.06), baseBg);
    final pressedBg = Color.alphaBlend(cs.primary.withOpacity(isDark ? 0.16 : 0.10), baseBg);
    final bg = isDisabled ? baseBg : (_pressed ? pressedBg : (_hover ? hoverBg : baseBg));
    final borderColor = (!isDisabled && _hover)
        ? cs.primary.withOpacity(isDark ? 0.28 : 0.22)
        : cs.outlineVariant.withOpacity(0.35);
    return Opacity(
      opacity: isDisabled ? 0.45 : 1.0,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() {
          _hover = false;
          _pressed = false;
        }),
        cursor: isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: isDisabled ? null : (_) => setState(() => _pressed = true),
            onTapUp: isDisabled ? null : (_) => setState(() => _pressed = false),
            onTapCancel: isDisabled ? null : () => setState(() => _pressed = false),
            onTap: isDisabled ? null : () => widget.onChanged?.call(!widget.value),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(widget.desc, style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.7))),
                  ]),
                ),
                IosSwitch(value: widget.value, onChanged: widget.onChanged),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeskCard extends StatelessWidget {
  const _DeskCard({required this.child, this.padding = const EdgeInsets.all(12)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF2F3F5);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(isDark ? 0.22 : 0.18), width: 0.8),
      ),
      padding: padding,
      child: child,
    );
  }
}

class _SegTabBar extends StatefulWidget {
  const _SegTabBar({required this.controller, required this.tabs});
  final TabController controller;
  final List<String> tabs;

  @override
  State<_SegTabBar> createState() => _SegTabBarState();
}

class _SegTabBarState extends State<_SegTabBar> {
  int _hover = -1;

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

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return LayoutBuilder(builder: (context, constraints) {
          final tabs = widget.tabs;
          final controller = widget.controller;
          final double availWidth = constraints.maxWidth;
          final double innerAvailWidth = availWidth - innerPadding * 2;
          final double segWidth = (innerAvailWidth - gap * (tabs.length - 1)) / tabs.length;
          final double rowWidth = segWidth * tabs.length + gap * (tabs.length - 1);
          final Color shellBg = isDark ? Colors.white.withOpacity(0.08) : Colors.white;

          List<Widget> children = [];
          for (int index = 0; index < tabs.length; index++) {
            final bool selected = controller.index == index;
            final bool hovered = _hover == index;
            final Color bg = selected
                ? cs.primary.withOpacity(0.14)
                : hovered
                    ? (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.03))
                    : Colors.transparent;
            final Color fg = selected ? cs.primary : cs.onSurface.withOpacity(0.82);

            children.add(
              SizedBox(
                width: segWidth < minSegWidth ? minSegWidth : segWidth,
                height: double.infinity,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _hover = index),
                  onExit: (_) => setState(() => _hover = -1),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => controller.index = index,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(innerRadius),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        tabs[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: fg, fontWeight: FontWeight.w600),
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
      },
    );
  }
}

class _CopySuffixButton extends StatefulWidget {
  const _CopySuffixButton({
    required this.onTap,
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.hoverColor,
    required this.pressedColor,
  });
  final VoidCallback onTap;
  final String tooltip;
  final IconData icon;
  final Color color;
  final Color hoverColor;
  final Color pressedColor;

  @override
  State<_CopySuffixButton> createState() => _CopySuffixButtonState();
}

class _CopySuffixButtonState extends State<_CopySuffixButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bg = _pressed ? widget.pressedColor : (_hover ? widget.hoverColor : Colors.transparent);
    final icon = Icon(widget.icon, size: 18, color: widget.color);

    Widget child = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: icon,
    );

    child = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: child,
      ),
    );

    return Tooltip(message: widget.tooltip, child: child);
  }
}
