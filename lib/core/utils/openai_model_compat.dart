class OpenAIReasoningSupport {
  const OpenAIReasoningSupport({
    required this.supportedEfforts,
    this.samplingRequiresNone = false,
  });

  final List<String> supportedEfforts;
  final bool samplingRequiresNone;

  bool get supportsNone => supportedEfforts.contains('none');
  bool get supportsXhigh => supportedEfforts.contains('xhigh');
}

const OpenAIReasoningSupport _gpt5Support = OpenAIReasoningSupport(
  supportedEfforts: <String>['none', 'low', 'medium', 'high'],
);
const OpenAIReasoningSupport _gpt5ProSupport = OpenAIReasoningSupport(
  supportedEfforts: <String>['high'],
);
const OpenAIReasoningSupport _gpt51Support = OpenAIReasoningSupport(
  supportedEfforts: <String>['none', 'low', 'medium', 'high'],
);
const OpenAIReasoningSupport _gpt51ChatLatestSupport = OpenAIReasoningSupport(
  supportedEfforts: <String>['none', 'low', 'medium', 'high'],
);
const OpenAIReasoningSupport _gpt52Support = OpenAIReasoningSupport(
  supportedEfforts: <String>['none', 'low', 'medium', 'high', 'xhigh'],
  samplingRequiresNone: true,
);
const OpenAIReasoningSupport _gpt52ChatLatestSupport = OpenAIReasoningSupport(
  supportedEfforts: <String>['none', 'low', 'medium', 'high', 'xhigh'],
);
const OpenAIReasoningSupport _gpt52ProSupport = OpenAIReasoningSupport(
  supportedEfforts: <String>['medium', 'high', 'xhigh'],
);
const OpenAIReasoningSupport _gpt52CodexSupport = OpenAIReasoningSupport(
  supportedEfforts: <String>['low', 'medium', 'high', 'xhigh'],
);
const OpenAIReasoningSupport _gpt53ChatLatestSupport = OpenAIReasoningSupport(
  supportedEfforts: <String>['none', 'low', 'medium', 'high', 'xhigh'],
);
const OpenAIReasoningSupport _gpt53CodexSupport = OpenAIReasoningSupport(
  supportedEfforts: <String>['low', 'medium', 'high', 'xhigh'],
);
const OpenAIReasoningSupport _gpt54Support = OpenAIReasoningSupport(
  supportedEfforts: <String>['none', 'low', 'medium', 'high', 'xhigh'],
  samplingRequiresNone: true,
);
const OpenAIReasoningSupport _gpt54ProSupport = OpenAIReasoningSupport(
  supportedEfforts: <String>['medium', 'high', 'xhigh'],
);
const OpenAIReasoningSupport _gpt55Support = OpenAIReasoningSupport(
  supportedEfforts: <String>['none', 'low', 'medium', 'high', 'xhigh'],
  samplingRequiresNone: true,
);
const OpenAIReasoningSupport _gpt55ProSupport = OpenAIReasoningSupport(
  supportedEfforts: <String>['medium', 'high', 'xhigh'],
);
const OpenAIReasoningSupport _deepSeekSupport = OpenAIReasoningSupport(
  supportedEfforts: <String>['low', 'medium', 'high', 'xhigh'],
);

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

bool isOpenAIGpt5FamilyModel(String modelId) {
  return RegExp(r'gpt-5(?=$|[-.])', caseSensitive: false).hasMatch(modelId);
}

bool openAISupportsXhighReasoning(String modelId) {
  return openAIReasoningSupport(modelId)?.supportsXhigh ?? false;
}

bool openAISupportsNoneReasoning(String modelId) {
  return openAIReasoningSupport(modelId)?.supportsNone ?? false;
}

String openAINormalizeReasoningEffort(String effort, String modelId) {
  final normalizedEffort = effort.trim().toLowerCase();
  if (normalizedEffort.isEmpty) return effort;
  if (normalizedEffort == 'auto') return 'auto';

  final support = openAIReasoningSupport(modelId);
  if (normalizedEffort == 'off') {
    return support?.supportsNone == true ? 'none' : 'off';
  }
  if (normalizedEffort == 'xhigh' && support == null) {
    return 'high';
  }
  if (support == null) return normalizedEffort;
  if (support.supportedEfforts.contains(normalizedEffort)) {
    return normalizedEffort;
  }

  switch (normalizedEffort) {
    case 'none':
      return _pickSupportedEffort(support, const <String>[
        'none',
        'low',
        'medium',
        'high',
        'xhigh',
      ]);
    case 'low':
      return _pickSupportedEffort(support, const <String>[
        'low',
        'medium',
        'high',
        'xhigh',
      ]);
    case 'medium':
      return _pickSupportedEffort(support, const <String>[
        'medium',
        'high',
        'xhigh',
        'low',
      ]);
    case 'high':
      return _pickSupportedEffort(support, const <String>[
        'high',
        'xhigh',
        'medium',
        'low',
        'none',
      ]);
    case 'xhigh':
      return _pickSupportedEffort(support, const <String>[
        'xhigh',
        'high',
        'medium',
        'low',
        'none',
      ]);
    default:
      return normalizedEffort;
  }
}

bool openAIAllowsSamplingParams(String modelId, {required String effort}) {
  final support = openAIReasoningSupport(modelId);
  if (support == null || !support.samplingRequiresNone) return true;
  final normalizedEffort = openAINormalizeReasoningEffort(effort, modelId);
  return normalizedEffort == 'none' ||
      normalizedEffort == 'off' ||
      normalizedEffort == 'auto';
}

OpenAIReasoningSupport? openAIReasoningSupport(String modelId) {
  final normalized = modelId.trim().toLowerCase();
  if (normalized.contains('deepseek')) return _deepSeekSupport;
  if (!isOpenAIGpt5FamilyModel(normalized)) return null;

  if (_matchesModel(normalized, r'^gpt-5\.5-pro(?:$|[-.])')) {
    return _gpt55ProSupport;
  }
  if (_matchesModel(normalized, r'^gpt-5\.5-(?:codex|chat-latest)(?:$|[-.])')) {
    return null;
  }
  if (_matchesModel(normalized, r'^gpt-5\.5(?:$|[-.])')) {
    return _gpt55Support;
  }
  if (_matchesModel(normalized, r'^gpt-5\.4-pro(?:$|[-.])')) {
    return _gpt54ProSupport;
  }
  if (_matchesModel(normalized, r'^gpt-5\.4-(?:codex|chat-latest)(?:$|[-.])')) {
    return null;
  }
  if (_matchesModel(normalized, r'^gpt-5\.4(?:$|[-.])')) {
    return _gpt54Support;
  }
  if (_matchesModel(normalized, r'^gpt-5\.3-codex(?:$|[-.])')) {
    return _gpt53CodexSupport;
  }
  if (_matchesModel(normalized, r'^gpt-5\.3-chat-latest(?:$|[-.])')) {
    return _gpt53ChatLatestSupport;
  }
  if (_matchesModel(normalized, r'^gpt-5\.3-(?:pro|chat-latest)(?:$|[-.])')) {
    return null;
  }
  if (_matchesModel(normalized, r'^gpt-5\.3(?:$|[-.])')) {
    return null;
  }
  if (_matchesModel(normalized, r'^gpt-5\.2-pro(?:$|[-.])')) {
    return _gpt52ProSupport;
  }
  if (_matchesModel(normalized, r'^gpt-5\.2-codex(?:$|[-.])')) {
    return _gpt52CodexSupport;
  }
  if (_matchesModel(normalized, r'^gpt-5\.2-chat-latest(?:$|[-.])')) {
    return _gpt52ChatLatestSupport;
  }
  if (_matchesModel(normalized, r'^gpt-5\.2(?:$|[-.])')) {
    return _gpt52Support;
  }
  if (_matchesModel(normalized, r'^gpt-5\.1-chat-latest(?:$|[-.])')) {
    return _gpt51ChatLatestSupport;
  }
  if (_matchesModel(normalized, r'^gpt-5\.1-(?:pro|codex)(?:$|[-.])')) {
    return null;
  }
  if (_matchesModel(normalized, r'^gpt-5\.1(?:$|[-.])')) {
    return _gpt51Support;
  }
  if (_matchesModel(normalized, r'^gpt-5-pro(?:$|[-.])')) {
    return _gpt5ProSupport;
  }
  if (_matchesModel(normalized, r'^gpt-5-(?:codex|chat-latest)(?:$|[-.])')) {
    return null;
  }
  if (_matchesModel(normalized, r'^gpt-5(?:$|-)')) {
    return _gpt5Support;
  }
  return null;
}

String _pickSupportedEffort(
  OpenAIReasoningSupport support,
  List<String> preferenceOrder,
) {
  for (final effort in preferenceOrder) {
    if (support.supportedEfforts.contains(effort)) return effort;
  }
  return support.supportedEfforts.last;
}

bool _matchesModel(String modelId, String pattern) {
  return RegExp(pattern, caseSensitive: false).hasMatch(modelId);
}
