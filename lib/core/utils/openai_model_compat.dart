import '../model_capabilities/builtin_model_rules.dart';
import '../model_capabilities/model_capabilities.dart';

/// Legacy-shaped view over a model's resolved reasoning support.
///
/// Built from the capability cascade rather than a private dispatch table.
class OpenAIReasoningSupport {
  const OpenAIReasoningSupport({
    required this.supportedEfforts,
    this.samplingRequiresNone = false,
    this.samplingAllowsAuto = true,
    this.effortParameterSupported = true,
    this.offFallback,
  });

  final List<String> supportedEfforts;
  final bool samplingRequiresNone;
  final bool samplingAllowsAuto;
  final bool effortParameterSupported;
  final String? offFallback;

  bool get supportsNone => supportedEfforts.contains('none');
  bool get supportsXhigh => supportedEfforts.contains('xhigh');
  bool get supportsMax => supportedEfforts.contains('max');
}

String resolveApiModelIdOverride(
  Map<String, dynamic>? override,
  String fallbackModelId,
) {
  final raw = (override?['apiModelId'] ?? override?['api_model_id'])
      ?.toString()
      .trim();
  if (raw != null && raw.isNotEmpty) return raw;
  return fallbackModelId;
}

bool isGlm53FamilyModel(String modelId) {
  return _matchesModel(
    modelId.trim().toLowerCase(),
    r'(^|[/_:@])glm-5\.3(?:$|[-.])',
  );
}

bool isGlm52FamilyModel(String modelId) {
  return _matchesModel(
    modelId.trim().toLowerCase(),
    r'(^|[/_:@])glm-5\.2(?:$|[-.])',
  );
}

bool openAISupportsXhighReasoning(String modelId) {
  return openAIReasoningSupport(modelId)?.supportsXhigh ?? false;
}

bool openAISupportsMaxReasoning(String modelId) {
  return openAIReasoningSupport(modelId)?.supportsMax ?? false;
}

bool openAISupportsNoneReasoning(String modelId) {
  return openAIReasoningSupport(modelId)?.supportsNone ?? false;
}

bool openAIChatCompletionsToolsRequireNone(String modelId) {
  return _quirksFor(modelId).contains(CapabilityQuirk.toolsForceEffortNone);
}

String openAINormalizeReasoningEffort(String effort, String modelId) {
  final normalizedEffort = effort.trim().toLowerCase();
  if (normalizedEffort.isEmpty) return effort;
  if (normalizedEffort == 'auto') return 'auto';

  final quirks = _quirksFor(modelId);
  if (quirks.contains(CapabilityQuirk.effortParameterUnsupported)) {
    return 'auto';
  }
  if (normalizedEffort == 'xhigh' &&
      quirks.contains(CapabilityQuirk.xhighEffortMapsToMax)) {
    return 'max';
  }

  final efforts = _effortsFor(modelId);
  if (normalizedEffort == 'off') {
    if (efforts == null) return 'off';
    if (efforts.contains('none')) return 'none';
    if (quirks.contains(CapabilityQuirk.reasoningAlwaysOn)) {
      return efforts.first;
    }
    return 'off';
  }
  if ((normalizedEffort == 'xhigh' || normalizedEffort == 'max') &&
      efforts == null) {
    return 'high';
  }
  if (efforts == null) return normalizedEffort;
  if (efforts.contains(normalizedEffort)) return normalizedEffort;

  return _pickSupportedEffort(efforts, _preferenceOrder(normalizedEffort));
}

bool openAIAllowsSamplingParams(String modelId, {required String effort}) {
  final quirks = _quirksFor(modelId);
  if (!quirks.contains(CapabilityQuirk.samplingRequiresNoThinking)) return true;
  final normalizedEffort = openAINormalizeReasoningEffort(effort, modelId);
  return normalizedEffort == 'none' ||
      normalizedEffort == 'off' ||
      (normalizedEffort == 'auto' &&
          !quirks.contains(CapabilityQuirk.autoDisallowsSampling));
}

OpenAIReasoningSupport? openAIReasoningSupport(String modelId) {
  return _supportCache.putIfAbsent(modelId, () {
    final efforts = _effortsFor(modelId);
    final quirks = _quirksFor(modelId);
    if (efforts == null && quirks.isEmpty) return null;
    return OpenAIReasoningSupport(
      supportedEfforts: efforts ?? const <String>[],
      samplingRequiresNone: quirks.contains(
        CapabilityQuirk.samplingRequiresNoThinking,
      ),
      samplingAllowsAuto: !quirks.contains(
        CapabilityQuirk.autoDisallowsSampling,
      ),
      effortParameterSupported: !quirks.contains(
        CapabilityQuirk.effortParameterUnsupported,
      ),
      offFallback:
          quirks.contains(CapabilityQuirk.reasoningAlwaysOn) &&
              (efforts?.isNotEmpty ?? false)
          ? efforts!.first
          : null,
    );
  });
}

final Map<String, ModelCapabilities> _capabilitiesCache =
    <String, ModelCapabilities>{};
final Map<String, OpenAIReasoningSupport?> _supportCache =
    <String, OpenAIReasoningSupport?>{};

ModelCapabilities _capabilitiesFor(String modelId) =>
    _capabilitiesCache.putIfAbsent(
      modelId,
      () => builtinCapabilityCascade.resolve(modelId).capabilities,
    );

Set<CapabilityQuirk> _quirksFor(String modelId) =>
    _capabilitiesFor(modelId).quirks ?? const <CapabilityQuirk>{};

List<String>? _effortsFor(String modelId) {
  final options = _capabilitiesFor(modelId).reasoningOptions;
  if (options == null) return null;
  final values = <String>[
    for (final option in options)
      if (option.type == ReasoningOptionType.effort) ...option.values,
  ];
  if (values.isEmpty) return null;
  return values;
}

List<String> _preferenceOrder(String effort) {
  switch (effort) {
    case 'none':
      return const <String>['none', 'low', 'medium', 'high', 'xhigh', 'max'];
    case 'low':
      return const <String>['low', 'medium', 'high', 'xhigh', 'max'];
    case 'medium':
      return const <String>['medium', 'high', 'xhigh', 'max', 'low'];
    case 'high':
      return const <String>['high', 'xhigh', 'max', 'medium', 'low', 'none'];
    case 'xhigh':
      return const <String>['xhigh', 'high', 'max', 'medium', 'low', 'none'];
    case 'max':
      return const <String>['max', 'xhigh', 'high', 'medium', 'low', 'none'];
    default:
      return const <String>[];
  }
}

String _pickSupportedEffort(
  List<String> supportedEfforts,
  List<String> preferenceOrder,
) {
  for (final effort in preferenceOrder) {
    if (supportedEfforts.contains(effort)) return effort;
  }
  return supportedEfforts.last;
}

bool _matchesModel(String modelId, String pattern) {
  return RegExp(pattern, caseSensitive: false).hasMatch(modelId);
}
