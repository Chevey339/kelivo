import '../../providers/model_provider.dart';
import '../../providers/settings_provider.dart';
import 'troubleshoot_data.dart';

class ErrorAnalyzer {
  static ErrorAnalysisResult? analyze({
    required int statusCode,
    required String errorBody,
    ProviderConfig? config,
    String? modelId,
  }) {
    final bodyLower = errorBody.toLowerCase();

    if (statusCode == 404 && config?.useResponseApi == true) {
      return _result('response_api_not_supported', config);
    }

    if (statusCode == 404 &&
        config?.providerType == ProviderKind.google &&
        config != null &&
        !config.baseUrl.toLowerCase().contains('v1beta')) {
      return _result('gemini_wrong_provider_type', config);
    }

    if (config?.chatPath != null && config!.chatPath!.isEmpty) {
      return _result('empty_api_path', config);
    }

    if (statusCode == 402 || bodyLower.contains('insufficient balance')) {
      return _result('insufficient_balance', config);
    }

    // OpenRouter returns this definitively when the model doesn't support images.
    if (bodyLower.contains('no endpoints found that support image input')) {
      return _result('model_no_vision', config);
    }

    // OpenAI-compatible: only check built-in vision regex, NOT modelOverrides,
    // because users may have incorrectly enabled image input on a non-vision model.
    if (bodyLower.contains('unknown variant `image_url`') &&
        modelId != null &&
        config != null &&
        !ModelRegistry.vision.hasMatch(modelId)) {
      return _result('model_no_vision', config);
    }

    return null;
  }

  static ErrorAnalysisResult unknownError() {
    final entry = findEntryByKey('unknown_error')!;
    return ErrorAnalysisResult(
      faqKey: entry.key,
      titleKey: entry.titleKey,
      summaryKey: entry.summaryKey,
      action: TroubleshootAction(
        type: ActionType.openAbout,
        labelKey: 'troubleshootActionOpenAbout',
      ),
    );
  }

  static ErrorAnalysisResult? _result(String faqKey, ProviderConfig? config) {
    final entry = findEntryByKey(faqKey);
    if (entry == null) return null;
    return ErrorAnalysisResult(
      faqKey: entry.key,
      titleKey: entry.titleKey,
      summaryKey: entry.summaryKey,
      action: entry.actionType != null
          ? TroubleshootAction(
              type: entry.actionType!,
              labelKey: entry.actionLabelKey ?? '',
              params: config != null
                  ? {
                      'providerId': config.id,
                      'providerDisplayName': config.name,
                    }
                  : const {},
            )
          : null,
    );
  }
}
