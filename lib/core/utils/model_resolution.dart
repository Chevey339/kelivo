import '../models/assistant.dart';
import '../models/conversation.dart';
import '../providers/settings_provider.dart';

/// Resolves the model a chat sends with, in priority order:
/// conversation override, then assistant default, then global default.
///
/// The conversation layer is skipped entirely when
/// [SettingsProvider.perChatModelEnabled] is off; pins stay in the database so
/// turning the setting back on restores each conversation's own model.
///
/// This is the only place that chain should be written. Every caller that means
/// "the model this chat uses" goes through here or [getActiveModelIds].
({String? providerKey, String? modelId}) resolveChatModel(
  SettingsProvider settings, {
  Conversation? conversation,
  Assistant? assistant,
}) {
  final pinned = settings.perChatModelEnabled ? conversation : null;
  final providerKey =
      pinned?.chatModelProvider ??
      assistant?.chatModelProvider ??
      settings.currentModelProvider;
  final modelId =
      pinned?.chatModelId ?? assistant?.chatModelId ?? settings.currentModelId;
  return (providerKey: providerKey, modelId: modelId);
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
