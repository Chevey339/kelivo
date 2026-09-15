import '../../../models/assistant.dart';
import '../../../providers/settings_provider.dart';
import '../../model_spec/model_spec_resolver.dart';
import 'reasoning_dialects.dart';

ReasoningRequest selectReasoningRequest({
  required SettingsProvider settings,
  required ProviderConfig config,
  required String modelId,
  Assistant? assistant,
}) {
  return settings.reasoningChoiceFor(config.id, modelId) ??
      assistant?.reasoning ??
      ReasoningRequest(
        ModelSpecResolver.instance.spec(config, modelId).reasoning.defaultLevel,
      );
}

ReasoningResolution effectiveReasoning({
  required SettingsProvider settings,
  required ProviderConfig config,
  required String modelId,
  Assistant? assistant,
}) {
  final spec = ModelSpecResolver.instance.spec(config, modelId);
  return resolveReasoning(
    spec,
    selectReasoningRequest(
      settings: settings,
      config: config,
      modelId: modelId,
      assistant: assistant,
    ),
  );
}
