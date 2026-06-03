part of 'chat_api_service.dart';

// Top-level shims so provider-specific implementations (split into parts)
// can keep calling the existing helper names without qualifying `ChatApiService.`.

String _apiModelId(ProviderConfig cfg, String modelId) =>
    ChatApiService._apiModelId(cfg, modelId);

String _apiKeyForRequest(ProviderConfig cfg, String modelId) =>
    ChatApiService._apiKeyForRequest(cfg, modelId);

String _effectiveApiKey(ProviderConfig cfg) =>
    ChatApiService._effectiveApiKey(cfg);

Set<String> _builtInTools(ProviderConfig cfg, String modelId) =>
    ChatApiService._builtInTools(cfg, modelId);

Map<String, String> _customHeaders(ProviderConfig cfg, String modelId) =>
    ChatApiService._customHeaders(cfg, modelId);

dynamic _parseOverrideValue(String v) => ChatApiService._parseOverrideValue(v);

Map<String, dynamic> _customBody(ProviderConfig cfg, String modelId) =>
    ChatApiService._customBody(cfg, modelId);

ModelInfo _effectiveModelInfo(ProviderConfig cfg, String modelId) =>
    ChatApiService._effectiveModelInfo(cfg, modelId);

String _mimeFromPath(String path) => ChatApiService._mimeFromPath(path);

String _mimeFromDataUrl(String dataUrl) =>
    ChatApiService._mimeFromDataUrl(dataUrl);

Future<_ParsedTextAndImages> _parseTextAndImages(
  String raw, {
  required bool allowRemoteImages,
  required bool allowLocalImages,
  bool allowDataImages = true,
  bool keepRemoteMarkdownText = true,
  bool keepDisallowedImageText = true,
}) => ChatApiService._parseTextAndImages(
  raw,
  allowRemoteImages: allowRemoteImages,
  allowLocalImages: allowLocalImages,
  allowDataImages: allowDataImages,
  keepRemoteMarkdownText: keepRemoteMarkdownText,
  keepDisallowedImageText: keepDisallowedImageText,
);

Future<String> _encodeBase64File(String path, {bool withPrefix = false}) =>
    ChatApiService._encodeBase64File(path, withPrefix: withPrefix);

bool _isOff(int? budget) => ChatApiService._isOff(budget);

String _effortForBudget(int? budget) => ChatApiService._effortForBudget(budget);

bool _isClaudeReasoningEnabled(int? budget) =>
    ChatApiService._isClaudeReasoningEnabled(budget);

Map<String, dynamic>? _claudeThinkingConfig(String modelId, int? budget) =>
    ChatApiService._claudeThinkingConfig(modelId, budget);

Map<String, dynamic>? _claudeOutputConfig(String modelId, int? budget) =>
    ChatApiService._claudeOutputConfig(modelId, budget);

bool _claudeShouldOmitSamplingParams(String modelId, int? budget) =>
    ChatApiService._claudeShouldOmitSamplingParams(modelId, budget);

double? _claudeCompatibleTopP(String modelId, int? budget, double? topP) =>
    ChatApiService._claudeCompatibleTopP(modelId, budget, topP);

Map<String, dynamic> _cleanSchemaForGemini(Map<String, dynamic> schema) =>
    ChatApiService._cleanSchemaForGemini(schema);
