import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/model_provider.dart';
import '../../../core/services/api/builtin_tools.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import 'model_edit_state_helper.dart';

Future<bool?> showModelDetailSheet(BuildContext context, {required String providerKey, required String modelId}) {
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
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
  late final ProviderKind _providerKind;
  late final bool _showBuiltinToolsTab;

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

  // Advanced (UI only)
  final List<_HeaderKV> _headers = [];
  final List<_BodyKV> _bodies = [];

  // Built-in tools (per provider)
  bool _googleUrlContextTool = false;
  bool _googleCodeExecutionTool = false;
  bool _googleYoutubeTool = false;
  bool _openaiCodeInterpreterTool = false;
  bool _openaiImageGenerationTool = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    final cfg = settings.getProviderConfig(widget.providerKey);
    _providerKind = ProviderConfig.classify(cfg.id, explicitType: cfg.providerType);
    _showBuiltinToolsTab = _providerKind == ProviderKind.google || _providerKind == ProviderKind.openai;
    _tabCtrl = TabController(length: _showBuiltinToolsTab ? 3 : 2, vsync: this);
    _tabCtrl.addListener(() {
      if (_tabCtrl.indexIsChanging) return;
      setState(() {
        if (_tabCtrl.index == 0) {
          _tab = _TabKind.basic;
        } else if (_tabCtrl.index == 1) {
          _tab = _TabKind.advanced;
        } else {
          _tab = _TabKind.tools;
        }
      });
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
      if (raw != null && raw.isNotEmpty) {
        displayModelId = raw;
      }
    }
    _idCtrl = TextEditingController(text: displayModelId);
    // Defaults from inferred base if id provided; otherwise generic defaults for new
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
    // Normalize embedding invariants on init (avoid running transition/caching logic during init).
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
      final rawOv = cfg.modelOverrides[widget.modelId];
      final ov = _initialOv ?? (rawOv is Map ? rawOv : null);
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
        // headers/body
        final rawHdrs = ov['headers'];
        final hdrs = (rawHdrs is List) ? rawHdrs : const <dynamic>[];
        for (final h in hdrs) {
          if (h is Map) {
            final kv = _HeaderKV();
            kv.name.text = (h['name'] as String?) ?? '';
            kv.value.text = (h['value'] as String?) ?? '';
            _headers.add(kv);
          }
        }
        final rawBds = ov['body'];
        final bds = (rawBds is List) ? rawBds : const <dynamic>[];
        for (final b in bds) {
          if (b is Map) {
            final kv = _BodyKV();
            kv.keyCtrl.text = (b['key'] as String?) ?? '';
            kv.valueCtrl.text = (b['value'] as String?) ?? '';
            _bodies.add(kv);
          }
        }
        // Built-in tools toggles
        final builtInSet = BuiltInToolNames.parseAndNormalize(ov['builtInTools']);

        _googleUrlContextTool = builtInSet.contains(BuiltInToolNames.urlContext);
        _googleCodeExecutionTool = builtInSet.contains(BuiltInToolNames.codeExecution);
        _googleYoutubeTool = builtInSet.contains(BuiltInToolNames.youtube);

        _openaiCodeInterpreterTool = builtInSet.contains(BuiltInToolNames.codeInterpreter);
        _openaiImageGenerationTool = builtInSet.contains(BuiltInToolNames.imageGeneration);

        // Backward compatibility: legacy UI-only tools map (older versions)
        final rawTools = ov['tools'];
        final tools = rawTools is Map ? rawTools : const <dynamic, dynamic>{};
        _googleUrlContextTool = _googleUrlContextTool || ((tools['urlContext'] as bool?) ?? false);
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
              onTap: () => Navigator.of(context).maybePop(false),
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
    final tabs = <String>[
      l10n.modelDetailSheetBasicTab,
      l10n.modelDetailSheetAdvancedTab,
      if (_showBuiltinToolsTab) l10n.modelDetailSheetBuiltinToolsTab,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _SegTabBar(
        controller: _tabCtrl,
        tabs: tabs,
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
              readOnly: !widget.isNew, // existing model ID is read-only
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
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.white,
                hintText: l10n.modelDetailSheetModelIdHint,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5))),
                suffixIconConstraints: const BoxConstraints(minWidth: 46, minHeight: 40),
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
                          icon: Lucide.Copy,
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
              onChanged: (i) => setState(() => _setType(i == 0 ? ModelType.chat : ModelType.embedding)),
            ),
          ],
        ),
      ),
      // Input modalities are configurable for both chat and embedding.
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
            if (_type == ModelType.chat) ...[
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
            for (int i = 0; i < _headers.length; i++)
              _HeaderRow(
                kv: _headers[i],
                onDelete: () => setState(() {
                  final kv = _headers.removeAt(i);
                  kv.name.dispose();
                  kv.value.dispose();
                }),
              ),
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
            for (int i = 0; i < _bodies.length; i++)
              _BodyRow(
                kv: _bodies[i],
                onDelete: () => setState(() {
                  final kv = _bodies.removeAt(i);
                  kv.keyCtrl.dispose();
                  kv.valueCtrl.dispose();
                }),
              ),
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
    final settings = context.watch<SettingsProvider>();
    final cfg = settings.getProviderConfig(widget.providerKey);
    final bool disableTools = _type == ModelType.embedding;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Text(
          l10n.modelDetailSheetBuiltinToolsDescription,
          style: TextStyle(color: cs.onSurface.withOpacity(0.8), fontSize: 13),
        ),
      ),
      if (_providerKind == ProviderKind.google) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text(
            l10n.modelDetailSheetGeminiCodeExecutionMutuallyExclusiveHint,
            style: TextStyle(color: cs.onSurface.withOpacity(0.65), fontSize: 12),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: _ToolTile(
            title: l10n.modelDetailSheetUrlContextTool,
            desc: l10n.modelDetailSheetUrlContextToolDescription,
            value: _googleUrlContextTool,
            // URL Context is disabled when Code Execution is enabled (mutually exclusive)
            onChanged: disableTools
                ? null
                : (_googleCodeExecutionTool ? null : (v) => setState(() => _googleUrlContextTool = v)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _ToolTile(
            title: l10n.modelDetailSheetCodeExecutionTool,
            desc: l10n.modelDetailSheetCodeExecutionToolDescription,
            value: _googleCodeExecutionTool,
            // Code Execution is disabled when URL Context is enabled (mutually exclusive)
            onChanged: disableTools
                ? null
                : (_googleUrlContextTool ? null : (v) => setState(() => _googleCodeExecutionTool = v)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _ToolTile(
            title: l10n.modelDetailSheetYoutubeTool,
            desc: l10n.modelDetailSheetYoutubeToolDescription,
            value: _googleYoutubeTool,
            onChanged: disableTools ? null : (v) => setState(() => _googleYoutubeTool = v),
          ),
        ),
      ] else if (_providerKind == ProviderKind.openai) ...[
        if (cfg.useResponseApi != true)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              l10n.modelDetailSheetOpenaiBuiltinToolsResponsesOnlyHint,
              style: TextStyle(color: cs.onSurface.withOpacity(0.65), fontSize: 12),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: _ToolTile(
            title: l10n.modelDetailSheetOpenaiCodeInterpreterTool,
            desc: l10n.modelDetailSheetOpenaiCodeInterpreterToolDescription,
            value: _openaiCodeInterpreterTool,
            onChanged: disableTools
                ? null
                : ((cfg.useResponseApi == true)
                    ? (v) => setState(() => _openaiCodeInterpreterTool = v)
                    : null),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _ToolTile(
            title: l10n.modelDetailSheetOpenaiImageGenerationTool,
            desc: l10n.modelDetailSheetOpenaiImageGenerationToolDescription,
            value: _openaiImageGenerationTool,
            onChanged: disableTools
                ? null
                : ((cfg.useResponseApi == true)
                    ? (v) => setState(() => _openaiImageGenerationTool = v)
                    : null),
          ),
        ),
      ] else
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Text(
            l10n.modelDetailSheetBuiltinToolsUnsupportedHint,
            style: TextStyle(color: cs.onSurface.withOpacity(0.65), fontSize: 12),
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
    // Logical key used inside configs (stable across edits)
    final String prevKey = widget.modelId;
    // Upstream/vendor model id typed by the user
    final String apiModelId = _idCtrl.text.trim();
    // Basic validation
    if (apiModelId.isEmpty || apiModelId.length < 2) {
      final l10n = AppLocalizations.of(context)!;
      showAppSnackBar(
        context,
        message: l10n.modelDetailSheetInvalidIdError,
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
    final prev = (prevKey.isNotEmpty && ov[prevKey] is Map)
        ? (ov[prevKey] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final builtInSet = BuiltInToolNames.parseAndNormalize(prev['builtInTools']);
    if (_providerKind == ProviderKind.google) {
      builtInSet.remove(BuiltInToolNames.urlContext);
      builtInSet.remove(BuiltInToolNames.codeExecution);
      builtInSet.remove(BuiltInToolNames.youtube);
      if (_googleUrlContextTool) builtInSet.add(BuiltInToolNames.urlContext);
      if (_googleCodeExecutionTool) builtInSet.add(BuiltInToolNames.codeExecution);
      if (_googleYoutubeTool) builtInSet.add(BuiltInToolNames.youtube);
    } else if (_providerKind == ProviderKind.openai) {
      builtInSet.remove(BuiltInToolNames.codeInterpreter);
      builtInSet.remove(BuiltInToolNames.imageGeneration);
      if (_openaiCodeInterpreterTool) builtInSet.add(BuiltInToolNames.codeInterpreter);
      if (_openaiImageGenerationTool) builtInSet.add(BuiltInToolNames.imageGeneration);
    }
    final builtInTools = BuiltInToolNames.orderedForStorage(builtInSet);
    // Decide which logical key to use for this instance
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
      if (!isEmbedding && builtInTools.isNotEmpty) 'builtInTools': builtInTools,
    };

    // Apply updates to provider config
    if (prevKey.isEmpty || widget.isNew) {
      // Creating a new model
      final list = old.models.toList()..add(key);
      await settings.setProviderConfig(widget.providerKey, old.copyWith(modelOverrides: ov, models: list));
    } else {
      // Existing model instance; keep logical key stable and just persist overrides
      await settings.setProviderConfig(widget.providerKey, old.copyWith(modelOverrides: ov));
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
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
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final bool isDisabled = onChanged == null;
    return Opacity(
      opacity: isDisabled ? 0.45 : 1.0,
      child: Material(
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
                    Text(desc, style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.7))),
                  ],
                ),
              ),
              IosSwitch(value: value, onChanged: onChanged),
            ],
          ),
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
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
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
