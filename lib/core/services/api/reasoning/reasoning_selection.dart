import '../../../models/assistant.dart';
import '../../../models/model_spec.dart';
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

/// Maps the current slider/popover integers onto [ReasoningRequest].
///
/// Fixed stops stay 1024/16000/32000/64000/128000 -> low/medium/high/xhigh/max.
ReasoningRequest reasoningFromUiBudget(int value) {
  if (value == 0) return ReasoningRequest.off;
  if (value == -1) return ReasoningRequest.auto;
  final level = switch (value) {
    1024 => ReasoningLevel.low,
    16000 => ReasoningLevel.medium,
    32000 => ReasoningLevel.high,
    64000 => ReasoningLevel.xhigh,
    128000 => ReasoningLevel.max,
    _ when value < 1024 => ReasoningLevel.off,
    _ when value <= 2000 => ReasoningLevel.low,
    _ when value <= 20000 => ReasoningLevel.medium,
    _ when value <= 32000 => ReasoningLevel.high,
    _ when value <= 64000 => ReasoningLevel.xhigh,
    _ => ReasoningLevel.max,
  };
  return ReasoningRequest(level, budgetTokens: value > 0 ? value : null);
}

int uiBudgetFromReasoning(ReasoningRequest? request) {
  if (request == null) return -1;
  if (request.budgetTokens != null && request.budgetTokens! > 0) {
    return request.budgetTokens!;
  }
  return switch (request.level) {
    ReasoningLevel.off => 0,
    ReasoningLevel.auto => -1,
    ReasoningLevel.minimal || ReasoningLevel.low => 1024,
    ReasoningLevel.medium => 16000,
    ReasoningLevel.high => 32000,
    ReasoningLevel.xhigh => 64000,
    ReasoningLevel.max => 128000,
  };
}
