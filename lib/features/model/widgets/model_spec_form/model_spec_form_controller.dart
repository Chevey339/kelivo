import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../../../core/models/model_spec.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/services/api/builtin_tools.dart';
import '../../../../core/services/logging/flutter_logger.dart';
import '../../../../core/services/model_spec/model_spec_resolver.dart';
import '../../../../l10n/app_localizations.dart';

const List<ReasoningLevel> kModelSpecEditableLevels = [
  ReasoningLevel.minimal,
  ReasoningLevel.low,
  ReasoningLevel.medium,
  ReasoningLevel.high,
  ReasoningLevel.xhigh,
  ReasoningLevel.max,
];

class ModelSpecFormController extends ChangeNotifier {
  ModelSpecFormController({
    required ProviderConfig config,
    required String modelKey,
    required bool isNew,
  }) : _config = config,
       _modelKey = modelKey,
       isNew = isNew {
    final displayModelId = _initialDisplayModelId(config, modelKey, isNew);
    final resolveKey = isNew
        ? (displayModelId.isEmpty ? 'custom' : displayModelId)
        : modelKey;
    final resolved = ModelSpecResolver.instance.resolve(
      isNew ? config.copyWith(modelOverrides: const {}) : config,
      resolveKey,
      displayName: displayModelId.isEmpty ? '' : displayModelId,
    );
    base = resolved.base;
    sources = resolved.sources;
    draft = resolved.override;
    apiModelIdController = TextEditingController(
      text: isNew ? '' : resolved.spec.upstreamId,
    );
    displayNameController = TextEditingController(
      text: resolved.spec.displayName,
    );
    contextWindowController = TextEditingController(
      text: _formatInt(resolved.spec.contextWindow),
    );
    maxOutputController = TextEditingController(
      text: _formatInt(resolved.spec.maxOutput),
    );
    final pricing = resolved.spec.pricing;
    pricingInputController = TextEditingController(
      text: _formatDouble(pricing?.input),
    );
    pricingOutputController = TextEditingController(
      text: _formatDouble(pricing?.output),
    );
    pricingCacheReadController = TextEditingController(
      text: _formatDouble(pricing?.cacheRead),
    );
    pricingCacheWriteController = TextEditingController(
      text: _formatDouble(pricing?.cacheWrite),
    );
    currencyController = TextEditingController(
      text: isOverridden(ModelSpecField.pricing)
          ? (draft.pricing?.currency ?? 'USD')
          : (pricing?.currency ?? ''),
    );
    for (final level in kModelSpecEditableLevels) {
      budgetControllers[level] = TextEditingController(
        text: _formatInt(draft.reasoning?.budgets?[level]),
      );
      customPatchControllers[level] = TextEditingController(
        text: _encodePatch(
          draft.reasoning?.customPatches?[level] ??
              resolved.spec.reasoning.customPatches[level],
        ),
      );
    }
  }

  final ProviderConfig _config;
  final String _modelKey;
  final bool isNew;
  bool _displayNameTouched = false;

  late ModelSpec base;
  late Map<ModelSpecField, SpecSource> sources;
  late ModelSpecOverride draft;
  ModelSpec? _spec;
  bool _reasoningTouched = false;

  late final TextEditingController apiModelIdController;
  late final TextEditingController displayNameController;
  late final TextEditingController contextWindowController;
  late final TextEditingController maxOutputController;
  late final TextEditingController pricingInputController;
  late final TextEditingController pricingOutputController;
  late final TextEditingController pricingCacheReadController;
  late final TextEditingController pricingCacheWriteController;
  late final TextEditingController currencyController;
  final Map<ReasoningLevel, TextEditingController> budgetControllers = {};
  final Map<ReasoningLevel, TextEditingController> customPatchControllers = {};
  final Map<ReasoningLevel, String?> _customPatchErrors = {};

  String get providerId => _config.id;
  String get modelKey => _modelKey;
  ProviderConfig get config => _config;

  ModelSpec get spec => _spec ??= draft.applyTo(base, applyDisplayName: true);

  bool get isApiModelIdOverridden => draft.apiModelId != null;
  bool get isDisplayNameOverridden => draft.displayName != null;
  bool get isHeadersOverridden => draft.headers != null;
  bool get isBodyOverridden => draft.body != null;
  bool get isBuiltInToolsOverridden => draft.builtInTools != null;

  bool isOverridden(ModelSpecField field) {
    final reasoning = draft.reasoning;
    return switch (field) {
      ModelSpecField.type => draft.type != null,
      ModelSpecField.input => draft.input != null,
      ModelSpecField.output => draft.output != null,
      ModelSpecField.abilities => draft.abilities != null,
      ModelSpecField.reasoningDialect => reasoning?.dialect != null,
      ModelSpecField.reasoningLevels => reasoning?.levels != null,
      ModelSpecField.reasoningCanDisable => reasoning?.canDisable != null,
      ModelSpecField.reasoningDefaultLevel => reasoning?.defaultLevel != null,
      ModelSpecField.reasoningBudgets => reasoning?.budgets != null,
      ModelSpecField.reasoningReplay =>
        reasoning?.replay != null || reasoning?.replayField != null,
      ModelSpecField.sampling => draft.sampling != null,
      ModelSpecField.contextWindow => draft.contextWindow != null,
      ModelSpecField.maxOutput => draft.maxOutput != null,
      ModelSpecField.pricing => draft.pricing != null,
      ModelSpecField.dynamicWebSearch => draft.dynamicWebSearch != null,
      ModelSpecField.remoteImageUrls => draft.remoteImageUrls != null,
      ModelSpecField.promptCacheControl => draft.promptCacheControl != null,
    };
  }

  SpecSource sourceOf(ModelSpecField field) {
    if (isOverridden(field)) return SpecSource.override;
    return sources[field] ?? SpecSource.fallback;
  }

  void reset(ModelSpecField field) {
    switch (field) {
      case ModelSpecField.type:
        draft = draft.copyWith(clearType: true);
      case ModelSpecField.input:
        draft = draft.copyWith(clearInput: true);
      case ModelSpecField.output:
        draft = draft.copyWith(clearOutput: true);
      case ModelSpecField.abilities:
        draft = draft.copyWith(clearAbilities: true);
      case ModelSpecField.reasoningDialect:
        _patchReasoning((current) => current.copyWith(clearDialect: true));
      case ModelSpecField.reasoningLevels:
        _patchReasoning((current) => current.copyWith(clearLevels: true));
      case ModelSpecField.reasoningCanDisable:
        _patchReasoning((current) => current.copyWith(clearCanDisable: true));
      case ModelSpecField.reasoningDefaultLevel:
        _patchReasoning((current) => current.copyWith(clearDefaultLevel: true));
      case ModelSpecField.reasoningBudgets:
        _patchReasoning((current) => current.copyWith(clearBudgets: true));
        for (final level in kModelSpecEditableLevels) {
          _setControllerText(budgetControllers[level]!, '');
        }
      case ModelSpecField.reasoningReplay:
        _patchReasoning(
          (current) =>
              current.copyWith(clearReplay: true, clearReplayField: true),
        );
      case ModelSpecField.sampling:
        draft = draft.copyWith(clearSampling: true);
      case ModelSpecField.contextWindow:
        draft = draft.copyWith(clearContextWindow: true);
        _setControllerText(
          contextWindowController,
          _formatInt(base.contextWindow),
        );
      case ModelSpecField.maxOutput:
        draft = draft.copyWith(clearMaxOutput: true);
        _setControllerText(maxOutputController, _formatInt(base.maxOutput));
      case ModelSpecField.pricing:
        draft = draft.copyWith(clearPricing: true);
        _syncPricingControllers(base.pricing);
      case ModelSpecField.dynamicWebSearch:
        draft = draft.copyWith(clearDynamicWebSearch: true);
      case ModelSpecField.remoteImageUrls:
        draft = draft.copyWith(clearRemoteImageUrls: true);
      case ModelSpecField.promptCacheControl:
        draft = draft.copyWith(clearPromptCacheControl: true);
    }
    _changed();
  }

  void resetApiModelId() {
    draft = draft.copyWith(clearApiModelId: true);
    if (isNew) {
      _setControllerText(apiModelIdController, '');
      _reresolveBase();
    } else {
      _setControllerText(apiModelIdController, spec.upstreamId);
    }
    _changed();
  }

  void resetDisplayName() {
    _displayNameTouched = false;
    draft = draft.copyWith(clearDisplayName: true);
    _setControllerText(
      displayNameController,
      isNew ? (draft.apiModelId ?? '') : base.displayName,
    );
    _changed();
  }

  void resetHeaders() {
    draft = draft.copyWith(clearHeaders: true);
    _changed();
  }

  void resetBody() {
    draft = draft.copyWith(clearBody: true);
    _changed();
  }

  void resetBuiltInTools() {
    draft = draft.copyWith(clearBuiltInTools: true);
    _changed();
  }

  void setType(ModelType type) {
    draft = draft.copyWith(type: type);
    _changed();
  }

  void setInput(List<Modality> input) {
    draft = draft.copyWith(input: List<Modality>.from(input));
    _changed();
  }

  void toggleInput(Modality modality) {
    final next = {...spec.input};
    if (next.contains(modality)) {
      if (modality == Modality.text && next.length == 1) return;
      next.remove(modality);
      if (next.isEmpty) next.add(Modality.text);
    } else {
      next.add(modality);
    }
    setInput(next.toList());
  }

  void setOutput(List<Modality> output) {
    draft = draft.copyWith(output: List<Modality>.from(output));
    _changed();
  }

  void toggleOutput(Modality modality) {
    final next = {...spec.output};
    if (next.contains(modality)) {
      if (modality == Modality.text && next.length == 1) return;
      next.remove(modality);
      if (next.isEmpty) next.add(Modality.text);
    } else {
      next.add(modality);
    }
    setOutput(next.toList());
  }

  void setAbilities(List<ModelAbility> abilities) {
    draft = draft.copyWith(abilities: List<ModelAbility>.from(abilities));
    _changed();
  }

  void toggleAbility(ModelAbility ability) {
    final next = [...spec.abilities];
    if (next.contains(ability)) {
      next.remove(ability);
    } else {
      next.add(ability);
    }
    setAbilities(next);
  }

  void setDialect(ReasoningDialect dialect) {
    _patchReasoning((current) => current.copyWith(dialect: dialect));
    _changed();
  }

  void setLevels(List<ReasoningLevel> levels) {
    _patchReasoning((current) => current.copyWith(levels: levels));
    _changed();
  }

  void toggleLevel(ReasoningLevel level) {
    final next = [...spec.reasoning.levels];
    if (next.contains(level)) {
      next.remove(level);
    } else {
      next.add(level);
    }
    setLevels(next);
  }

  void setCanDisable(bool value) {
    _patchReasoning((current) => current.copyWith(canDisable: value));
    _changed();
  }

  void setDefaultLevel(ReasoningLevel level) {
    _patchReasoning((current) => current.copyWith(defaultLevel: level));
    _changed();
  }

  void setBudget(ReasoningLevel level, int? tokens) {
    final next = Map<ReasoningLevel, int>.from(
      draft.reasoning?.budgets ?? spec.reasoning.budgets,
    );
    if (tokens == null) {
      next.remove(level);
    } else {
      next[level] = tokens;
    }
    _patchReasoning((current) => current.copyWith(budgets: next));
    _changed();
  }

  void setCustomPatch(ReasoningLevel level, Map<String, dynamic>? patch) {
    final next = <ReasoningLevel, Map<String, dynamic>>{
      ...(draft.reasoning?.customPatches ?? spec.reasoning.customPatches),
    };
    if (patch == null) {
      next.remove(level);
    } else {
      next[level] = patch;
    }
    _patchReasoning((current) => current.copyWith(customPatches: next));
    _customPatchErrors.remove(level);
    _changed();
  }

  void setCustomPatchText(ReasoningLevel level, String text) {
    final controller = customPatchControllers[level]!;
    if (controller.text != text) {
      _setControllerText(controller, text);
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      _customPatchErrors.remove(level);
      setCustomPatch(level, null);
      return;
    }
    final parsed = _tryParseJsonObject(trimmed);
    if (parsed == null) {
      _customPatchErrors[level] = '';
      notifyListeners();
      return;
    }
    _customPatchErrors.remove(level);
    setCustomPatch(level, parsed);
  }

  String customPatchText(ReasoningLevel level) =>
      customPatchControllers[level]?.text ?? '';

  String? customPatchError(ReasoningLevel level) => _customPatchErrors[level];

  void setReplay(ReasoningReplayPolicy replay) {
    _patchReasoning((current) => current.copyWith(replay: replay));
    _changed();
  }

  void setReplayField(ReasoningReplayField replayField) {
    _patchReasoning((current) => current.copyWith(replayField: replayField));
    _changed();
  }

  void setDynamicWebSearch(bool value) {
    draft = draft.copyWith(dynamicWebSearch: value);
    _changed();
  }

  void setRemoteImageUrls(bool value) {
    draft = draft.copyWith(remoteImageUrls: value);
    _changed();
  }

  void setPromptCacheControl(bool value) {
    draft = draft.copyWith(promptCacheControl: value);
    _changed();
  }

  void setSampling(SamplingPolicy sampling) {
    draft = draft.copyWith(sampling: sampling);
    _changed();
  }

  void setContextWindow(int? value) {
    draft = value == null
        ? draft.copyWith(clearContextWindow: true)
        : draft.copyWith(contextWindow: value);
    _changed();
  }

  void setMaxOutput(int? value) {
    draft = value == null
        ? draft.copyWith(clearMaxOutput: true)
        : draft.copyWith(maxOutput: value);
    _changed();
  }

  void setPricingInput(double? value) => _setPricing(
    (current) => _pricing(current, input: value, clearInput: true),
  );

  void setPricingOutput(double? value) => _setPricing(
    (current) => _pricing(current, output: value, clearOutput: true),
  );

  void setPricingCacheRead(double? value) => _setPricing(
    (current) => _pricing(current, cacheRead: value, clearCacheRead: true),
  );

  void setPricingCacheWrite(double? value) => _setPricing(
    (current) => _pricing(current, cacheWrite: value, clearCacheWrite: true),
  );

  void setCurrency(String? value) {
    final currency = (value ?? '').trim();
    _setPricing(
      (current) => ModelPricing(
        input: current.input,
        output: current.output,
        cacheRead: current.cacheRead,
        cacheWrite: current.cacheWrite,
        currency: currency.isEmpty ? 'USD' : currency.toUpperCase(),
      ),
    );
  }

  void setApiModelId(String value) {
    final trimmed = value.trim();
    draft = trimmed.isEmpty
        ? draft.copyWith(clearApiModelId: true)
        : draft.copyWith(apiModelId: trimmed);
    if (apiModelIdController.text != value) {
      _setControllerText(apiModelIdController, value);
    }
    if (isNew) {
      _reresolveBase();
      if (!_displayNameTouched) {
        _setControllerText(displayNameController, trimmed);
      }
    }
    _changed();
  }

  void setDisplayName(String value) {
    _displayNameTouched = true;
    final trimmed = value.trim();
    draft = trimmed.isEmpty
        ? draft.copyWith(clearDisplayName: true)
        : draft.copyWith(displayName: trimmed);
    if (displayNameController.text != value) {
      _setControllerText(displayNameController, value);
    }
    _changed();
  }

  void setHeaders(List<Map<String, String>> rows) {
    draft = draft.copyWith(
      headers: [for (final row in rows) Map<String, String>.from(row)],
    );
    _changed();
  }

  void setBody(List<Map<String, String>> rows) {
    draft = draft.copyWith(
      body: [for (final row in rows) Map<String, String>.from(row)],
    );
    _changed();
  }

  void setBuiltInTools(List<String> tools) {
    draft = draft.copyWith(builtInTools: List<String>.from(tools));
    _changed();
  }

  void toggleBuiltInTool(String name, bool on) {
    final next = draft.builtInTools != null
        ? {...draft.builtInTools!}
        : BuiltInToolNames.parseFromOverride(draft.toJson());
    if (on) {
      next.add(name);
    } else {
      next.remove(name);
    }
    setBuiltInTools(next.toList());
  }

  bool isBuiltInToolOn(String name) {
    if (draft.builtInTools != null) {
      return draft.builtInTools!.contains(name);
    }
    return BuiltInToolNames.parseFromOverride(draft.toJson()).contains(name);
  }

  String? validate(AppLocalizations l10n) {
    final apiModelId = apiModelIdController.text.trim();
    if (apiModelId.isEmpty || apiModelId.length < 2) {
      return l10n.modelDetailSheetInvalidIdError;
    }
    if (_invalidNumber(contextWindowController.text) ||
        _invalidNumber(maxOutputController.text) ||
        _invalidNumber(pricingInputController.text, decimal: true) ||
        _invalidNumber(pricingOutputController.text, decimal: true) ||
        _invalidNumber(pricingCacheReadController.text, decimal: true) ||
        _invalidNumber(pricingCacheWriteController.text, decimal: true)) {
      return l10n.modelSpecFormInvalidNumber;
    }
    for (final controller in budgetControllers.values) {
      if (_invalidNumber(controller.text)) {
        return l10n.modelSpecFormInvalidNumber;
      }
    }
    if (spec.reasoning.dialect == ReasoningDialect.custom) {
      for (final level in spec.reasoning.levels) {
        final raw = customPatchControllers[level]?.text.trim() ?? '';
        if (raw.isEmpty) {
          _customPatchErrors.remove(level);
          continue;
        }
        if (_tryParseJsonObject(raw) == null) {
          _customPatchErrors[level] = l10n.modelSpecFormInvalidJson;
          notifyListeners();
          return l10n.modelSpecFormInvalidJson;
        }
        _customPatchErrors.remove(level);
      }
    }
    return null;
  }

  Future<bool> save(SettingsProvider settings) async {
    if (!_hasValidDraft()) return false;
    _commitIdentityFields();

    final current = settings.providerConfigs[providerId] ?? _config;
    final apiModelId = apiModelIdController.text.trim();
    final key = isNew ? _nextModelKey(current, apiModelId) : _modelKey;
    final prev = current.modelOverrides[key];
    final payload = _payloadForSave(
      currentConfig: current,
      previous: prev,
      logicalKey: key,
    );
    final overrides = Map<String, dynamic>.from(current.modelOverrides);
    overrides[key] = payload;
    try {
      if (isNew) {
        await settings.setProviderConfig(
          providerId,
          current.copyWith(
            modelOverrides: overrides,
            models: [...current.models, key],
          ),
        );
      } else {
        await settings.setProviderConfig(
          providerId,
          current.copyWith(modelOverrides: overrides),
        );
      }
    } catch (e, st) {
      FlutterLogger.log('[ModelSpecForm] save failed: $e\n$st', tag: 'Model');
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    apiModelIdController.dispose();
    displayNameController.dispose();
    contextWindowController.dispose();
    maxOutputController.dispose();
    pricingInputController.dispose();
    pricingOutputController.dispose();
    pricingCacheReadController.dispose();
    pricingCacheWriteController.dispose();
    currencyController.dispose();
    for (final controller in budgetControllers.values) {
      controller.dispose();
    }
    for (final controller in customPatchControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _changed() {
    _spec = null;
    notifyListeners();
  }

  void _reresolveBase() {
    final id = draft.apiModelId ?? '';
    final resolved = ModelSpecResolver.instance.resolve(
      _config.copyWith(modelOverrides: const {}),
      id.isEmpty ? 'custom' : id,
      displayName: draft.displayName ?? (id.isEmpty ? '' : id),
    );
    base = resolved.base;
    sources = resolved.sources;
    if (!isOverridden(ModelSpecField.contextWindow)) {
      _setControllerText(
        contextWindowController,
        _formatInt(base.contextWindow),
      );
    }
    if (!isOverridden(ModelSpecField.maxOutput)) {
      _setControllerText(maxOutputController, _formatInt(base.maxOutput));
    }
    if (!isOverridden(ModelSpecField.pricing)) {
      _syncPricingControllers(base.pricing);
    }
  }

  void _patchReasoning(
    ReasoningSpecOverride Function(ReasoningSpecOverride current) update,
  ) {
    _reasoningTouched = true;
    final next = update(draft.reasoning ?? const ReasoningSpecOverride());
    draft = next.isEmpty
        ? draft.copyWith(clearReasoning: true)
        : draft.copyWith(reasoning: next);
  }

  void _setPricing(ModelPricing Function(ModelPricing current) update) {
    final current = draft.pricing ?? base.pricing ?? const ModelPricing();
    draft = draft.copyWith(pricing: update(current));
    _changed();
  }

  ModelPricing _pricing(
    ModelPricing current, {
    double? input,
    bool clearInput = false,
    double? output,
    bool clearOutput = false,
    double? cacheRead,
    bool clearCacheRead = false,
    double? cacheWrite,
    bool clearCacheWrite = false,
  }) {
    return ModelPricing(
      input: clearInput ? input : (input ?? current.input),
      output: clearOutput ? output : (output ?? current.output),
      cacheRead: clearCacheRead ? cacheRead : (cacheRead ?? current.cacheRead),
      cacheWrite: clearCacheWrite
          ? cacheWrite
          : (cacheWrite ?? current.cacheWrite),
      currency: current.currency,
    );
  }

  void _syncPricingControllers(ModelPricing? pricing) {
    _setControllerText(pricingInputController, _formatDouble(pricing?.input));
    _setControllerText(pricingOutputController, _formatDouble(pricing?.output));
    _setControllerText(
      pricingCacheReadController,
      _formatDouble(pricing?.cacheRead),
    );
    _setControllerText(
      pricingCacheWriteController,
      _formatDouble(pricing?.cacheWrite),
    );
    _setControllerText(
      currencyController,
      isOverridden(ModelSpecField.pricing)
          ? (draft.pricing?.currency ?? 'USD')
          : (pricing?.currency ?? ''),
    );
  }

  void _commitIdentityFields() {
    final apiModelId = apiModelIdController.text.trim();
    if (apiModelId.isNotEmpty) {
      draft = draft.copyWith(apiModelId: apiModelId);
    }
    final name = displayNameController.text.trim();
    if (name.isNotEmpty &&
        (isNew || _displayNameTouched || isDisplayNameOverridden)) {
      draft = draft.copyWith(displayName: name);
    }
    _spec = null;
  }

  bool _hasValidDraft() {
    final apiModelId = apiModelIdController.text.trim();
    if (apiModelId.isEmpty || apiModelId.length < 2) return false;
    if (_invalidNumber(contextWindowController.text) ||
        _invalidNumber(maxOutputController.text) ||
        _invalidNumber(pricingInputController.text, decimal: true) ||
        _invalidNumber(pricingOutputController.text, decimal: true) ||
        _invalidNumber(pricingCacheReadController.text, decimal: true) ||
        _invalidNumber(pricingCacheWriteController.text, decimal: true)) {
      return false;
    }
    for (final controller in budgetControllers.values) {
      if (_invalidNumber(controller.text)) return false;
    }
    if (spec.reasoning.dialect == ReasoningDialect.custom) {
      for (final level in spec.reasoning.levels) {
        final raw = customPatchControllers[level]?.text.trim() ?? '';
        if (raw.isEmpty) continue;
        if (_tryParseJsonObject(raw) == null) return false;
      }
    }
    return true;
  }

  Map<String, dynamic> _payloadForSave({
    required ProviderConfig currentConfig,
    required Object? previous,
    required String logicalKey,
  }) {
    final json = Map<String, dynamic>.from(draft.toJson());
    if (draft.headers != null) {
      json['headers'] = [
        for (final row in draft.headers!)
          if ((row['name'] ?? '').trim().isNotEmpty)
            {'name': row['name']!.trim(), 'value': row['value'] ?? ''},
      ];
    }
    if (draft.body != null) {
      json['body'] = [
        for (final row in draft.body!)
          if ((row['key'] ?? '').trim().isNotEmpty)
            {'key': row['key']!.trim(), 'value': row['value'] ?? ''},
      ];
    }
    final currentTools = BuiltInToolNames.parseFromOverride(previous);
    final selected = draft.builtInTools ?? currentTools;
    final builtInSet = BuiltInToolsHelper.replaceModelSettingsTools(
      cfg: currentConfig,
      current: currentTools,
      selected: selected,
      modelId: isNew ? '' : logicalKey,
    );
    final builtInTools = BuiltInToolNames.orderedForStorage(builtInSet);
    if (spec.type == ModelType.embedding || builtInTools.isEmpty) {
      json.remove('builtInTools');
    } else {
      json['builtInTools'] = builtInTools;
    }
    if (spec.type == ModelType.embedding) {
      json.remove('output');
      json.remove('abilities');
    }
    if (previous is Map) {
      final prev = Map<String, dynamic>.from(previous);
      for (final entry in prev.entries) {
        if (_ownedSaveKeys.contains(entry.key)) continue;
        json[entry.key] = entry.value;
      }
      if (!_reasoningTouched && prev.containsKey('reasoning')) {
        json['reasoning'] = prev['reasoning'];
      }
    }
    return json;
  }

  static const _ownedSaveKeys = {
    'apiModelId',
    'api_model_id',
    'name',
    'displayName',
    'type',
    'input',
    'output',
    'abilities',
    'reasoning',
    'sampling',
    'contextWindow',
    'maxOutput',
    'pricing',
    'dynamicWebSearch',
    'remoteImageUrls',
    'promptCacheControl',
    'headers',
    'body',
    'builtInTools',
    'tools',
    'built_in_tools',
  };

  static String _nextModelKey(ProviderConfig cfg, String apiModelId) {
    final existing = <String>{...cfg.models, ...cfg.modelOverrides.keys};
    if (!existing.contains(apiModelId)) return apiModelId;
    var i = 2;
    while (true) {
      final candidate = '$apiModelId#$i';
      if (!existing.contains(candidate)) return candidate;
      i++;
    }
  }

  static String _initialDisplayModelId(
    ProviderConfig config,
    String modelKey,
    bool isNew,
  ) {
    if (isNew) return '';
    final raw = config.modelOverrides[modelKey];
    if (raw is Map) {
      final api = (raw['apiModelId'] ?? raw['api_model_id'])?.toString().trim();
      if (api != null && api.isNotEmpty) return api;
    }
    return modelKey;
  }

  static void _setControllerText(
    TextEditingController controller,
    String text,
  ) {
    if (controller.text == text) return;
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  static String _formatInt(int? value) => value?.toString() ?? '';

  static String _formatDouble(double? value) {
    if (value == null) return '';
    if (value == value.roundToDouble()) return '${value.toInt()}';
    return value.toString();
  }

  static String _encodePatch(Map<String, dynamic>? patch) {
    if (patch == null || patch.isEmpty) return '';
    return const JsonEncoder.withIndent('  ').convert(patch);
  }

  static Map<String, dynamic>? _tryParseJsonObject(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return <String, dynamic>{
          for (final entry in decoded.entries)
            entry.key.toString(): entry.value,
        };
      }
    } catch (_) {}
    return null;
  }

  static bool _invalidNumber(String raw, {bool decimal = false}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return false;
    return decimal
        ? double.tryParse(trimmed) == null
        : int.tryParse(trimmed) == null;
  }
}
