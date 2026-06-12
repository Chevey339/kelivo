enum ActionType {
  openProviderDetail,
  openProviderBalance,
  openDefaultModel,
  openSearchServices,
  openAssistantSettings,
  openBackupSettings,
  openCommunityLinks,
  openAbout,
}

class TroubleshootAction {
  final ActionType type;
  final String labelKey;
  final Map<String, String> params;

  const TroubleshootAction({
    required this.type,
    required this.labelKey,
    this.params = const {},
  });

  String? get providerId => params['providerId'];
  String? get providerDisplayName => params['providerDisplayName'];
}

class TroubleshootEntry {
  final String key;
  final String titleKey;
  final String summaryKey;
  final ActionType? actionType;
  final String? actionLabelKey;
  final Map<String, String> actionParams;
  final bool isErrorMatch;

  const TroubleshootEntry({
    required this.key,
    required this.titleKey,
    required this.summaryKey,
    this.actionType,
    this.actionLabelKey,
    this.actionParams = const {},
    this.isErrorMatch = false,
  });
}

class ErrorAnalysisResult {
  final String faqKey;
  final String titleKey;
  final String summaryKey;
  final TroubleshootAction? action;

  const ErrorAnalysisResult({
    required this.faqKey,
    required this.titleKey,
    required this.summaryKey,
    this.action,
  });
}

const List<TroubleshootEntry> troubleshootEntries = [
  TroubleshootEntry(
    key: 'response_api_not_supported',
    titleKey: 'troubleshootEntryResponseApiTitle',
    summaryKey: 'troubleshootEntryResponseApiSummary',
    actionType: ActionType.openProviderDetail,
    actionLabelKey: 'troubleshootActionProviderSettings',
    isErrorMatch: true,
  ),
  TroubleshootEntry(
    key: 'gemini_wrong_provider_type',
    titleKey: 'troubleshootEntryGeminiTypeTitle',
    summaryKey: 'troubleshootEntryGeminiTypeSummary',
    actionType: ActionType.openProviderDetail,
    actionLabelKey: 'troubleshootActionProviderSettings',
    isErrorMatch: true,
  ),
  TroubleshootEntry(
    key: 'empty_api_path',
    titleKey: 'troubleshootEntryEmptyPathTitle',
    summaryKey: 'troubleshootEntryEmptyPathSummary',
    actionType: ActionType.openProviderDetail,
    actionLabelKey: 'troubleshootActionProviderSettings',
    isErrorMatch: true,
  ),
  TroubleshootEntry(
    key: 'insufficient_balance',
    titleKey: 'troubleshootEntryBalanceTitle',
    summaryKey: 'troubleshootEntryBalanceSummary',
    actionType: ActionType.openProviderBalance,
    actionLabelKey: 'troubleshootActionProviderBalance',
    isErrorMatch: true,
  ),
  TroubleshootEntry(
    key: 'model_no_vision',
    titleKey: 'troubleshootEntryNoVisionTitle',
    summaryKey: 'troubleshootEntryNoVisionSummary',
    actionType: ActionType.openDefaultModel,
    actionLabelKey: 'troubleshootActionDefaultModel',
    isErrorMatch: true,
  ),
  TroubleshootEntry(
    key: 'search_quality',
    titleKey: 'troubleshootEntrySearchQualityTitle',
    summaryKey: 'troubleshootEntrySearchQualitySummary',
    actionType: ActionType.openSearchServices,
    actionLabelKey: 'troubleshootActionSearchServices',
    isErrorMatch: false,
  ),
  TroubleshootEntry(
    key: 'low_cache_hitrate',
    titleKey: 'troubleshootEntryCacheHitrateTitle',
    summaryKey: 'troubleshootEntryCacheHitrateSummary',
    actionType: ActionType.openAssistantSettings,
    actionLabelKey: 'troubleshootActionAssistantSettings',
    isErrorMatch: false,
  ),
  TroubleshootEntry(
    key: 'backup_sync',
    titleKey: 'troubleshootEntryBackupSyncTitle',
    summaryKey: 'troubleshootEntryBackupSyncSummary',
    actionType: ActionType.openBackupSettings,
    actionLabelKey: 'troubleshootActionBackupSettings',
    isErrorMatch: false,
  ),
  TroubleshootEntry(
    key: 'unknown_error',
    titleKey: 'troubleshootUnknownErrorTitle',
    summaryKey: 'troubleshootUnknownErrorSummary',
    actionType: null,
    actionLabelKey: null,
    isErrorMatch: true,
  ),
  TroubleshootEntry(
    key: 'chat_suggestions',
    titleKey: 'troubleshootEntryChatSuggestionsTitle',
    summaryKey: 'troubleshootEntryChatSuggestionsSummary',
    actionType: ActionType.openDefaultModel,
    actionLabelKey: 'troubleshootActionDefaultModel',
    isErrorMatch: false,
  ),
  TroubleshootEntry(
    key: 'multiple_billing',
    titleKey: 'troubleshootEntryMultiBillingTitle',
    summaryKey: 'troubleshootEntryMultiBillingSummary',
    actionType: ActionType.openDefaultModel,
    actionLabelKey: 'troubleshootActionDefaultModel',
    isErrorMatch: false,
  ),
];

TroubleshootEntry? findEntryByKey(String key) {
  try {
    return troubleshootEntries.firstWhere((e) => e.key == key);
  } catch (_) {
    return null;
  }
}
