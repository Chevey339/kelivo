import '../../../core/providers/settings_provider.dart';
import '../../../core/models/assistant.dart';
import '../../../core/models/conversation.dart';

/// Helper class for extracting model display information.
///
/// This class eliminates repetitive code patterns for getting provider/model
/// information that was duplicated across multiple locations in home_page.dart.
class ModelDisplayInfo {
  const ModelDisplayInfo({
    this.providerName,
    this.modelDisplay,
    this.providerKey,
    this.modelId,
  });

  /// Display name of the provider (e.g., "OpenAI", "Anthropic")
  final String? providerName;

  /// Display name of the model (from override, apiModelId, or raw modelId)
  final String? modelDisplay;

  /// Raw provider key used in settings
  final String? providerKey;

  /// Raw model ID
  final String? modelId;

  /// Check if both provider and model are configured
  bool get isConfigured => providerKey != null && modelId != null;

  /// Get the ProviderConfig for this model (if configured)
  ProviderConfig? getConfig(SettingsProvider settings) {
    if (providerKey == null) return null;
    return settings.getProviderConfig(providerKey!);
  }
}

/// Resolves the model a chat sends with, in priority order:
/// conversation override, then assistant default, then global default.
///
/// This is the only place that chain should be written. Every caller that means
/// "the model this chat uses" goes through here or [getActiveModelIds].
({String? providerKey, String? modelId}) resolveChatModel(
  SettingsProvider settings, {
  Conversation? conversation,
  Assistant? assistant,
}) {
  final providerKey =
      conversation?.chatModelProvider ??
      assistant?.chatModelProvider ??
      settings.currentModelProvider;
  final modelId =
      conversation?.chatModelId ??
      assistant?.chatModelId ??
      settings.currentModelId;
  return (providerKey: providerKey, modelId: modelId);
}

/// Extracts model display information from settings, conversation and assistant.
///
/// This consolidates the repeated pattern of resolving the active model and
/// then applying the provider's per-model display overrides.
ModelDisplayInfo getModelDisplayInfo(
  SettingsProvider settings, {
  Conversation? conversation,
  Assistant? assistant,
}) {
  final resolved = resolveChatModel(
    settings,
    conversation: conversation,
    assistant: assistant,
  );
  final providerKey = resolved.providerKey;
  final modelId = resolved.modelId;

  if (providerKey == null || modelId == null) {
    return const ModelDisplayInfo();
  }

  final cfg = settings.getProviderConfig(providerKey);
  final providerName = cfg.name.isNotEmpty ? cfg.name : providerKey;

  // Extract model display name from overrides or use raw modelId
  String modelDisplay = modelId;
  final ov = cfg.modelOverrides[modelId] as Map?;
  if (ov != null) {
    // Priority: override name > apiModelId > api_model_id > raw modelId
    final overrideName = (ov['name'] as String?)?.trim();
    if (overrideName != null && overrideName.isNotEmpty) {
      modelDisplay = overrideName;
    } else {
      final apiId = (ov['apiModelId'] ?? ov['api_model_id'])?.toString().trim();
      if (apiId != null && apiId.isNotEmpty) {
        modelDisplay = apiId;
      }
    }
  }

  return ModelDisplayInfo(
    providerName: providerName,
    modelDisplay: modelDisplay,
    providerKey: providerKey,
    modelId: modelId,
  );
}

/// Gets just the provider key and model ID without display formatting.
///
/// Use this when you only need the raw identifiers for API calls.
({String? providerKey, String? modelId}) getActiveModelIds(
  SettingsProvider settings, {
  Conversation? conversation,
  Assistant? assistant,
}) => resolveChatModel(
  settings,
  conversation: conversation,
  assistant: assistant,
);

/// Gets the ProviderConfig for the active model.
ProviderConfig? getActiveProviderConfig(
  SettingsProvider settings, {
  Conversation? conversation,
  Assistant? assistant,
}) {
  final providerKey = resolveChatModel(
    settings,
    conversation: conversation,
    assistant: assistant,
  ).providerKey;
  if (providerKey == null) return null;
  return settings.getProviderConfig(providerKey);
}
