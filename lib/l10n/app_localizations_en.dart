// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get helloWorld => 'Hello World!';

  @override
  String get settingsPageBackButton => 'Back';

  @override
  String get settingsPageTitle => 'Settings';

  @override
  String get settingsPageDarkMode => 'Dark';

  @override
  String get settingsPageLightMode => 'Light';

  @override
  String get settingsPageSystemMode => 'System';

  @override
  String get settingsPageWarningMessage =>
      'Some services are not configured; features may be limited.';

  @override
  String get settingsPageGeneralSection => 'General';

  @override
  String get settingsPageColorMode => 'Color Mode';

  @override
  String get settingsPageDisplay => 'Preferences';

  @override
  String get settingsPageDisplaySubtitle =>
      'Appearance, behavior, and interaction preferences';

  @override
  String get settingsPageAssistant => 'Assistant';

  @override
  String get settingsPageAssistantSubtitle => 'Default assistant and style';

  @override
  String get settingsPageModelsServicesSection => 'Models & Services';

  @override
  String get settingsPageDefaultModel => 'Default Model';

  @override
  String get settingsPageProviders => 'Providers';

  @override
  String get settingsPageHotkeys => 'Hotkeys';

  @override
  String get settingsPageSearch => 'Search';

  @override
  String get settingsPageTts => 'TTS';

  @override
  String get settingsPageMcp => 'MCP';

  @override
  String get settingsPageQuickPhrase => 'Quick Phrase';

  @override
  String get settingsPageInstructionInjection => 'Instruction Injection';

  @override
  String get settingsPageDataSection => 'Data';

  @override
  String get settingsPageBackup => 'Backup';

  @override
  String get settingsPageChatStorage => 'Chat Storage';

  @override
  String get settingsPageCalculating => 'Calculating…';

  @override
  String settingsPageFilesCount(int count, String size) {
    return '$count files · $size';
  }

  @override
  String get storageSpacePageTitle => 'Storage Space';

  @override
  String get storageSpaceRefreshTooltip => 'Refresh';

  @override
  String get storageSpaceLoadFailed => 'Failed to load storage usage';

  @override
  String get storageSpaceTotalLabel => 'Used';

  @override
  String storageSpaceClearableLabel(String size) {
    return 'Clearable: $size';
  }

  @override
  String storageSpaceClearableHint(String size) {
    return 'Safe to clear: $size';
  }

  @override
  String get storageSpaceCategoryImages => 'Images';

  @override
  String get storageSpaceCategoryFiles => 'Files';

  @override
  String get storageSpaceCategoryFonts => 'Fonts';

  @override
  String get storageSpaceCategoryLocalModels => 'Local Models';

  @override
  String get storageSpaceOtherHint =>
      'Fonts, downloaded local models, and other app files.';

  @override
  String get storageSpaceSubOtherApp => 'App files';

  @override
  String get storageSpaceCategoryChatData => 'Chat Records';

  @override
  String get storageSpaceCategoryLegacyChatData => 'Chat Records (Old)';

  @override
  String get storageSpaceCategoryRestoreTraces => 'Restore Traces';

  @override
  String get storageSpaceCategoryDisplacedDatabases => 'Set-Aside Databases';

  @override
  String get storageSpaceSubDisplacedDatabases =>
      'Kept before an automatic rebuild';

  @override
  String get storageSpaceClearDisplacedDatabasesConfirmMessage =>
      'Delete these set-aside databases? Kelivo kept them when it rebuilt its database, and they may be the only surviving copy of those chats and settings. This cannot be undone.';

  @override
  String get storageSpaceRestoreTracesHint =>
      'Previous data snapshots kept after completed restores. Clearing them does not affect the current app data.';

  @override
  String get storageSpaceClearRestoreTracesButton => 'Clear Restore Traces';

  @override
  String get storageSpaceClearDisplacedDatabasesButton =>
      'Delete Set-Aside Databases';

  @override
  String get storageSpaceClearRestoreTracesConfirmMessage =>
      'Clear completed restore snapshots? Your current database, settings, and files will not be affected.';

  @override
  String get storageSpaceSubCompletedRestoreRuns =>
      'Completed restore snapshots';

  @override
  String get storageSpaceCategoryAssistantData => 'Assistants';

  @override
  String get storageSpaceCategoryCache => 'Cache';

  @override
  String get storageSpaceCategoryLogs => 'Logs';

  @override
  String get storageSpaceCategoryOther => 'Other';

  @override
  String storageSpaceFilesCount(int count) {
    return '$count files';
  }

  @override
  String get storageSpaceSafeToClearHint =>
      'Safe to clear. This will not affect your chat history.';

  @override
  String get storageSpaceLegacyChatDataHint =>
      'These are retained Hive files from before the SQLite migration. Clearing them does not delete your current chat records.';

  @override
  String get storageSpaceNotSafeToClearHint =>
      'May affect your chat history. Delete with care.';

  @override
  String get storageSpaceBreakdownTitle => 'Breakdown';

  @override
  String get storageSpaceSubChatMessages => 'Messages';

  @override
  String get storageSpaceSubChatConversations => 'Conversations';

  @override
  String get storageSpaceSubChatToolEvents => 'Tool events';

  @override
  String get storageSpaceSubChatDatabase => 'Chat database';

  @override
  String get storageSpaceSubChatWriteAheadLog => 'Write-ahead log';

  @override
  String get storageSpaceSubChatSharedMemory => 'Shared memory index';

  @override
  String get storageSpaceSubAssistantAvatars => 'Avatars';

  @override
  String get storageSpaceSubAssistantImages => 'Images';

  @override
  String get storageSpaceSubCacheAvatars => 'Avatar cache';

  @override
  String get storageSpaceSubCacheOther => 'Other cache';

  @override
  String get storageSpaceSubCacheSystem => 'System cache';

  @override
  String get storageSpaceSubLogsContext => 'Context logs';

  @override
  String get storageSpaceSubLogsFlutter => 'Flutter logs';

  @override
  String get storageSpaceSubLogsRequests => 'Network logs';

  @override
  String get storageSpaceSubLogsOther => 'Other logs';

  @override
  String get storageSpaceClearConfirmTitle => 'Confirm clear';

  @override
  String storageSpaceClearConfirmMessage(String targetName) {
    return 'Clear $targetName?';
  }

  @override
  String get storageSpaceClearButton => 'Clear';

  @override
  String storageSpaceClearDone(String targetName) {
    return '$targetName cleared';
  }

  @override
  String storageSpaceClearFailed(String error) {
    return 'Clear failed: $error';
  }

  @override
  String get storageSpaceClearAvatarCacheButton => 'Clear Avatar Cache';

  @override
  String get storageSpaceClearCacheButton => 'Clear Cache';

  @override
  String get storageSpaceClearLogsButton => 'Clear Logs';

  @override
  String get storageSpaceClearLegacyChatDataButton => 'Clear Old Chat Records';

  @override
  String get storageSpaceExportLegacyChatFileButton => 'Export';

  @override
  String storageSpaceExportDone(Object fileName) {
    return '$fileName exported';
  }

  @override
  String storageSpaceExportFailed(Object error) {
    return 'Export failed: $error';
  }

  @override
  String get storageSpaceClearLegacyChatDataConfirmMessage =>
      'Clear the retained old chat files? Your current SQLite chat records will remain available.';

  @override
  String get storageSpaceViewLogsButton => 'View Logs';

  @override
  String get storageSpaceDeleteConfirmTitle => 'Confirm deletion';

  @override
  String storageSpaceDeleteUploadsConfirmMessage(int count) {
    return 'Delete $count items? Attachments in chat history may become unavailable.';
  }

  @override
  String storageSpaceDeletedUploadsDone(int count) {
    return 'Deleted $count items';
  }

  @override
  String get storageSpaceNoUploads => 'No items';

  @override
  String get storageSpaceSelectAll => 'Select all';

  @override
  String get storageSpaceClearSelection => 'Clear selection';

  @override
  String storageSpaceSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String storageSpaceUploadsCount(int count) {
    return '$count items';
  }

  @override
  String get storageSpaceSourceLabel => 'Source';

  @override
  String get storageSpaceSourceAll => 'All';

  @override
  String get storageSpaceSourceUserUpload => 'User uploads';

  @override
  String get storageSpaceSourceAssistant => 'Assistant';

  @override
  String get storageSpaceSortLabel => 'Sort';

  @override
  String get storageSpaceSortNewest => 'Newest';

  @override
  String get storageSpaceSortOldest => 'Oldest';

  @override
  String get storageSpaceSortLargest => 'Largest';

  @override
  String get storageSpaceSortSmallest => 'Smallest';

  @override
  String get settingsPageAboutSection => 'About';

  @override
  String get settingsPageAbout => 'About';

  @override
  String get settingsPageStatistics => 'Statistics';

  @override
  String get settingsPageDocs => 'Docs';

  @override
  String get settingsPageLogs => 'Logs';

  @override
  String get settingsPageSponsor => 'Sponsor';

  @override
  String get settingsPageShare => 'Share';

  @override
  String get statsPageTitle => 'Statistics';

  @override
  String get statsPageRangeAllTime => 'All Time';

  @override
  String get statsPageRangeLast30Days => 'Last 30 Days';

  @override
  String get statsPageRangePreviousMonth => 'Last Month';

  @override
  String get statsPageRangePreviousQuarter => 'Last Quarter';

  @override
  String get statsPageRangeCustom => 'Custom';

  @override
  String get statsPageHeatmapTitle => 'Chat Heatmap';

  @override
  String get statsPageHeatmapLess => 'Less';

  @override
  String get statsPageHeatmapMore => 'More';

  @override
  String get statsPageSummaryTitle => 'Overview';

  @override
  String get statsPageTotalConversations => 'Total Conversations';

  @override
  String get statsPageTotalMessages => 'Total Messages';

  @override
  String get statsPageInputTokens => 'Input Tokens';

  @override
  String get statsPageOutputTokens => 'Output Tokens';

  @override
  String get statsPageCachedTokens => 'Cached Tokens';

  @override
  String get statsPageLaunchCount => 'App Launches';

  @override
  String get statsPageUsageTrendTitle => 'Usage Trend';

  @override
  String get statsPageModelUsageTitle => 'Model Usage';

  @override
  String get statsPageAssistantUsageTitle => 'Assistant Usage';

  @override
  String get statsPageTopicVolumeTitle => 'Topic Volume';

  @override
  String get statsPageModelColumn => 'Model';

  @override
  String get statsPageAssistantColumn => 'Assistant';

  @override
  String get statsPageTopicColumn => 'Topic';

  @override
  String get statsPageMessagesColumn => 'Messages';

  @override
  String get statsPageTopicsColumn => 'Topics';

  @override
  String get statsPageEmptyTitle => 'No statistics yet';

  @override
  String get statsPageShowAllTooltip => 'Show all';

  @override
  String get statsPageClose => 'Close';

  @override
  String get statsPageUnknownProvider => 'Unknown Provider';

  @override
  String get statsPageUnknownAssistant => 'Default Assistant';

  @override
  String get statsPageUnknownModel => 'Unknown Model';

  @override
  String get statsPageUnknownTopic => 'Untitled Topic';

  @override
  String get statsPageCustomRangeTitle => 'Custom Range';

  @override
  String get statsPageCustomRangeStart => 'Start';

  @override
  String get statsPageCustomRangeEnd => 'End';

  @override
  String get statsPageCustomRangeCancel => 'Cancel';

  @override
  String get statsPageCustomRangeApply => 'Apply';

  @override
  String get sponsorPageMethodsSectionTitle => 'Sponsorship Methods';

  @override
  String get sponsorPageSponsorsSectionTitle => 'Sponsors';

  @override
  String get sponsorPageEmpty => 'No sponsors yet';

  @override
  String get sponsorPageAfdianTitle => 'Afdian';

  @override
  String get sponsorPageAfdianSubtitle => 'afdian.com/a/kelivo';

  @override
  String get sponsorPageWeChatTitle => 'WeChat Sponsor';

  @override
  String get sponsorPageWeChatSubtitle => 'WeChat sponsor code';

  @override
  String get sponsorPageScanQrHint => 'Scan the QR code to sponsor';

  @override
  String get languageDisplaySimplifiedChinese => 'Simplified Chinese';

  @override
  String get languageDisplayEnglish => 'English';

  @override
  String get languageDisplayTraditionalChinese => 'Traditional Chinese';

  @override
  String get languageDisplayJapanese => 'Japanese';

  @override
  String get languageDisplayKorean => 'Korean';

  @override
  String get languageDisplayFrench => 'French';

  @override
  String get languageDisplayGerman => 'German';

  @override
  String get languageDisplayItalian => 'Italian';

  @override
  String get languageDisplaySpanish => 'Spanish';

  @override
  String get languageSelectSheetTitle => 'Select Translation Language';

  @override
  String get languageSelectSheetClearButton => 'Clear Translation';

  @override
  String get homePageClearContext => 'Clear Context';

  @override
  String homePageClearContextWithCount(String actual, String configured) {
    return 'Clear Context ($actual/$configured)';
  }

  @override
  String get homePageDefaultAssistant => 'Default Assistant';

  @override
  String get mermaidExportPng => 'Export PNG';

  @override
  String get mermaidExportFailed => 'Export failed';

  @override
  String get mermaidImageTab => 'Image';

  @override
  String get mermaidCodeTab => 'Code';

  @override
  String get mermaidFullScreen => 'Full screen';

  @override
  String get mermaidGeneratingImage => 'Generating image';

  @override
  String get mermaidGenerationFailedHint =>
      'Generation failed. Try asking another way.';

  @override
  String get mermaidPreviewOpen => 'Open Preview';

  @override
  String get mermaidPreviewOpenFailed => 'Cannot open preview';

  @override
  String get assistantProviderDefaultAssistantName => 'Default Assistant';

  @override
  String get assistantProviderSampleAssistantName => 'Sample Assistant';

  @override
  String get assistantProviderNewAssistantName => 'New Assistant';

  @override
  String assistantProviderSampleAssistantSystemPrompt(String model_name) {
    return 'You are $model_name, a helpful AI assistant. Answer accurately and concisely; say when you are unsure. Prefer clear structure (short paragraphs or lists) when it helps. Reply in the user\'s language by default.';
  }

  @override
  String get displaySettingsPageLanguageTitle => 'App Language';

  @override
  String get displaySettingsPageLanguageSubtitle => 'Choose interface language';

  @override
  String get assistantTagsManageTitle => 'Manage Tags';

  @override
  String get assistantTagsCreateButton => 'Create';

  @override
  String get assistantTagsCreateDialogTitle => 'Create Tag';

  @override
  String get assistantTagsCreateDialogOk => 'Create';

  @override
  String get assistantTagsCreateDialogCancel => 'Cancel';

  @override
  String get assistantTagsNameHint => 'Tag name';

  @override
  String get assistantTagsRenameButton => 'Rename';

  @override
  String get assistantTagsRenameDialogTitle => 'Rename Tag';

  @override
  String get assistantTagsRenameDialogOk => 'Rename';

  @override
  String get assistantTagsDeleteButton => 'Delete';

  @override
  String get assistantTagsDeleteConfirmTitle => 'Delete Tag';

  @override
  String get assistantTagsDeleteConfirmContent =>
      'Are you sure you want to delete this tag?';

  @override
  String get assistantTagsDeleteConfirmOk => 'Delete';

  @override
  String get assistantTagsDeleteConfirmCancel => 'Cancel';

  @override
  String get assistantTagsContextMenuEditAssistant => 'Edit Assistant';

  @override
  String get assistantTagsContextMenuManageTags => 'Manage Tags';

  @override
  String get mcpTransportOptionStdio => 'STDIO';

  @override
  String get mcpTransportTagStdio => 'STDIO';

  @override
  String get mcpTransportTagInmemory => 'Built-in';

  @override
  String get mcpTransportTagSse => 'SSE';

  @override
  String get mcpTransportTagHttp => 'HTTP';

  @override
  String get mcpServerEditSheetStdioOnlyDesktop =>
      'STDIO is only available on desktop';

  @override
  String get mcpServerEditSheetStdioCommandLabel => 'Command';

  @override
  String get mcpServerEditSheetStdioArgumentsLabel => 'Arguments';

  @override
  String get mcpServerEditSheetStdioWorkingDirectoryLabel =>
      'Working Directory (optional)';

  @override
  String get mcpServerEditSheetStdioEnvironmentTitle => 'Environment';

  @override
  String get mcpServerEditSheetStdioEnvNameLabel => 'Name';

  @override
  String get mcpServerEditSheetStdioEnvValueLabel => 'Value';

  @override
  String get mcpServerEditSheetStdioAddEnv => 'Add Env';

  @override
  String get mcpServerEditSheetStdioCommandRequired =>
      'Command is required for STDIO';

  @override
  String get assistantTagsContextMenuDeleteAssistant => 'Delete Assistant';

  @override
  String get assistantTagsClearTag => 'Clear Tag';

  @override
  String get displaySettingsPageLanguageChineseLabel => 'Simplified Chinese';

  @override
  String get displaySettingsPageLanguageEnglishLabel => 'English';

  @override
  String get homePagePleaseSelectModel => 'Please select a model first';

  @override
  String get homePageAudioAttachmentUnsupported =>
      'The current model does not support audio attachments. Switch to a model that supports audio input or remove the audio file and try again.';

  @override
  String get homePagePleaseSetupTranslateModel =>
      'Please set a translation model first';

  @override
  String get homePageTranslating => 'Translating...';

  @override
  String homePageTranslateFailed(String error) {
    return 'Translation failed: $error';
  }

  @override
  String get chatServiceDefaultConversationTitle => 'New Chat';

  @override
  String get userProviderDefaultUserName => 'User';

  @override
  String get homePageDeleteMessage => 'Delete This Version';

  @override
  String get homePageDeleteMessageConfirm =>
      'Are you sure you want to delete this version? This cannot be undone.';

  @override
  String get homePageDeleteAllVersions => 'Delete All Versions';

  @override
  String get homePageDeleteAllVersionsConfirm =>
      'Are you sure you want to delete all versions of this message? This cannot be undone.';

  @override
  String get homePageCancel => 'Cancel';

  @override
  String get homePageDelete => 'Delete';

  @override
  String get homePageSelectMessagesToShare => 'Please select messages to share';

  @override
  String get homePageDone => 'Done';

  @override
  String get homePageDropToUpload => 'Drop files to upload';

  @override
  String get assistantEditPageTitle => 'Assistant';

  @override
  String get assistantEditPageNotFound => 'Assistant not found';

  @override
  String get assistantEditPageBasicTab => 'Basic';

  @override
  String get assistantEditPagePromptsTab => 'Prompts';

  @override
  String get assistantEditPageMcpTab => 'MCP';

  @override
  String get assistantEditPageQuickPhraseTab => 'Quick Phrase';

  @override
  String get assistantEditPageCustomTab => 'Custom';

  @override
  String get assistantEditPageRegexTab => 'Regex Replace';

  @override
  String get assistantEditPageLocalToolsTab => 'Local Tools';

  @override
  String get assistantEditTabLayoutTooltip => 'Customize tabs';

  @override
  String get assistantEditTabLayoutTitle => 'Customize tabs';

  @override
  String get assistantEditTabLayoutSubtitle =>
      'Drag tabs to reorder. Turn off tabs you do not need.';

  @override
  String get assistantEditOutlineModeTitle => 'Section list style';

  @override
  String get assistantEditOutlineModeSubtitle =>
      'Show an assistant overview first, then open each setting section from a list.';

  @override
  String get assistantEditTabLayoutResetTooltip => 'Reset tab layout';

  @override
  String get assistantEditTabLayoutAtLeastOneVisible =>
      'Keep at least one tab visible';

  @override
  String assistantEditTabLayoutDragHandle(String tab) {
    return 'Drag to reorder $tab';
  }

  @override
  String get assistantEditRegexDescription =>
      'Create regex rules to rewrite or visually adjust user/assistant messages.';

  @override
  String get assistantEditAddRegexButton => 'Add Regex Rule';

  @override
  String get assistantRegexAddTitle => 'Add Regex Rule';

  @override
  String get assistantRegexEditTitle => 'Edit Regex Rule';

  @override
  String get assistantRegexNameLabel => 'Rule Name';

  @override
  String get assistantRegexPatternLabel => 'Regular Expression';

  @override
  String get assistantRegexReplacementLabel => 'Replacement String';

  @override
  String get assistantRegexScopeLabel => 'Affecting Scope';

  @override
  String get assistantRegexScopeUser => 'User';

  @override
  String get assistantRegexScopeAssistant => 'Assistant';

  @override
  String get assistantRegexScopeVisualOnly => 'Visual Only';

  @override
  String get assistantRegexScopeReplaceOnly => 'Replace Only';

  @override
  String get assistantRegexAddAction => 'Add';

  @override
  String get assistantRegexSaveAction => 'Save';

  @override
  String get assistantRegexDeleteButton => 'Delete';

  @override
  String get assistantRegexValidationError =>
      'Please fill in the name, regex, and select at least one scope.';

  @override
  String get assistantRegexInvalidPattern => 'Invalid regular expression';

  @override
  String get assistantRegexCancelButton => 'Cancel';

  @override
  String get assistantRegexUntitled => 'Untitled Rule';

  @override
  String get assistantEditCustomHeadersTitle => 'Custom Headers';

  @override
  String get assistantEditCustomHeadersAdd => 'Add Header';

  @override
  String get assistantEditCustomHeadersEmpty => 'No headers added';

  @override
  String get assistantEditCustomBodyTitle => 'Custom Body';

  @override
  String get assistantEditCustomBodyAdd => 'Add Body';

  @override
  String get assistantEditCustomBodyEmpty => 'No body items added';

  @override
  String get assistantEditHeaderNameLabel => 'Header Name';

  @override
  String get assistantEditHeaderValueLabel => 'Header Value';

  @override
  String get assistantEditBodyKeyLabel => 'Body Key';

  @override
  String get assistantEditBodyValueLabel => 'Body Value (JSON)';

  @override
  String get assistantEditDeleteTooltip => 'Delete';

  @override
  String get assistantEditAssistantNameLabel => 'Assistant Name';

  @override
  String get assistantEditUseAssistantAvatarTitle => 'Use Assistant Avatar';

  @override
  String get assistantEditUseAssistantAvatarSubtitle =>
      'Use assistant avatar instead of model avatar';

  @override
  String get assistantEditUseAssistantNameTitle => 'Use Assistant Name';

  @override
  String get assistantEditChatModelTitle => 'Chat Model';

  @override
  String get assistantEditChatModelSubtitle =>
      'Default chat model for this assistant (fallback to global)';

  @override
  String get assistantEditTemperatureDescription =>
      'Controls randomness, range 0–2';

  @override
  String get assistantEditTopPDescription =>
      'Do not change unless you know what you are doing';

  @override
  String get assistantEditParameterDisabled =>
      'Disabled (uses provider default)';

  @override
  String get assistantEditParameterDisabled2 => 'Disabled (no restrictions)';

  @override
  String get assistantEditContextMessagesTitle => 'Context Messages';

  @override
  String get assistantEditContextMessagesDescription =>
      'How many recent messages to keep in context';

  @override
  String get assistantEditStreamOutputTitle => 'Stream Output';

  @override
  String get assistantEditStreamOutputDescription =>
      'Enable streaming responses';

  @override
  String get assistantEditThinkingBudgetTitle => 'Thinking Budget';

  @override
  String get assistantEditConfigureButton => 'Configure';

  @override
  String get assistantEditMaxTokensTitle => 'Max Tokens';

  @override
  String get assistantEditMaxTokensDescription => 'Leave empty for unlimited';

  @override
  String get assistantEditMaxTokensHint => 'Unlimited';

  @override
  String get assistantEditChatBackgroundTitle => 'Chat Background';

  @override
  String get assistantEditChatBackgroundDescription =>
      'Set a background image for this assistant';

  @override
  String get assistantEditChooseImageButton => 'Choose Image';

  @override
  String get assistantEditClearButton => 'Clear';

  @override
  String get desktopNavChatTooltip => 'Chat';

  @override
  String get desktopNavTranslateTooltip => 'Translate';

  @override
  String get desktopNavStorageTooltip => 'Storage';

  @override
  String get desktopNavGlobalSearchTooltip => 'Global Search';

  @override
  String get desktopNavThemeToggleTooltip => 'Theme';

  @override
  String get desktopNavSettingsTooltip => 'Settings';

  @override
  String get desktopAvatarMenuUseEmoji => 'Use emoji';

  @override
  String get cameraPermissionDeniedMessage =>
      'Camera unavailable: permission not granted.';

  @override
  String get openSystemSettings => 'Open Settings';

  @override
  String get desktopAvatarMenuChangeFromImage => 'Change from image…';

  @override
  String get desktopAvatarMenuReset => 'Reset avatar';

  @override
  String get assistantEditAvatarChooseImage => 'Choose Image';

  @override
  String get assistantEditAvatarChooseEmoji => 'Choose Emoji';

  @override
  String get assistantEditAvatarEnterLink => 'Enter Link';

  @override
  String get assistantEditAvatarImportQQ => 'Import from QQ';

  @override
  String get assistantEditAvatarReset => 'Reset';

  @override
  String get displaySettingsPageChatMessageBackgroundTitle =>
      'Chat Message Background';

  @override
  String get displaySettingsPageChatMessageBackgroundDefault => 'Default';

  @override
  String get displaySettingsPageChatMessageBackgroundFrosted => 'Frosted Glass';

  @override
  String get displaySettingsPageChatMessageBackgroundSolid => 'Solid Color';

  @override
  String get displaySettingsPageAndroidBackgroundChatTitle =>
      'Background Generation (Android)';

  @override
  String get displaySettingsPageIosBackgroundChatTitle =>
      'Background Generation (iOS)';

  @override
  String get iosBackgroundSettingsPageTitle => 'iOS Background Generation';

  @override
  String get iosBackgroundStatusOn => 'On';

  @override
  String get iosBackgroundStatusOff => 'Off';

  @override
  String get iosBackgroundGenerationEnableTitle => 'Background Generation';

  @override
  String get iosBackgroundGenerationEnableSubtitle =>
      'Use iOS background time to keep the current reply running after the app leaves the foreground.';

  @override
  String get iosBackgroundTaskRefreshTitle => 'Background Task Recovery';

  @override
  String get iosBackgroundTaskRefreshSubtitle =>
      'Ask iOS for refresh and processing opportunities when system conditions allow.';

  @override
  String get iosLiveActivityTitle => 'Live Activity';

  @override
  String get iosLiveActivitySubtitle =>
      'Show background replies on the Lock Screen and Dynamic Island when supported.';

  @override
  String get iosBackgroundNotificationsTitle => 'Task Notifications';

  @override
  String get iosBackgroundNotificationsSubtitle =>
      'Send a local notification when a background reply completes or is interrupted.';

  @override
  String get iosBackgroundLimitNoticeTitle => 'iOS may still suspend work';

  @override
  String get iosBackgroundLimitNoticeBody =>
      'These options use Apple-supported background time, BackgroundTasks, notifications, and Live Activities. They improve continuity but cannot force iOS to keep Kelivo running forever.';

  @override
  String get iosBackgroundUnsupportedLiveActivity =>
      'Requires iOS 16.1 or later and Live Activities enabled in Settings.';

  @override
  String get iosBackgroundNativeStatusTitle => 'System status';

  @override
  String get iosBackgroundNativeStatusUnavailable =>
      'Unavailable until running on iOS';

  @override
  String get iosBackgroundLiveActivityAvailable => 'Live Activities available';

  @override
  String get iosBackgroundLiveActivityUnavailable =>
      'Live Activities unavailable';

  @override
  String get iosBackgroundNotificationsAuthorized => 'Notifications allowed';

  @override
  String get iosBackgroundNotificationsNotAuthorized =>
      'Notifications not allowed';

  @override
  String get iosBackgroundGenerationActiveTitle => 'Kelivo is generating';

  @override
  String get iosBackgroundGenerationActiveDetail =>
      'The assistant is replying in the background';

  @override
  String get iosBackgroundGenerationStreamingDetail =>
      'Receiving assistant response';

  @override
  String iosBackgroundGenerationTokenCount(int count) {
    return '$count tokens';
  }

  @override
  String get iosBackgroundGenerationCompleteTitle => 'Generation complete';

  @override
  String get iosBackgroundGenerationCompleteDetail =>
      'Assistant reply is ready';

  @override
  String get iosBackgroundGenerationInterruptedTitle =>
      'Generation interrupted';

  @override
  String get iosBackgroundGenerationInterruptedDetail =>
      'The background reply stopped before completion';

  @override
  String get iosBackgroundGenerationCancelledDetail => 'Generation stopped';

  @override
  String get androidBackgroundStatusOn => 'On';

  @override
  String get androidBackgroundStatusOff => 'Off';

  @override
  String get androidBackgroundStatusOther => 'On and notify';

  @override
  String get androidBackgroundOptionOn => 'On';

  @override
  String get androidBackgroundOptionOnNotify => 'On and notify when done';

  @override
  String get androidBackgroundOptionOff => 'Off';

  @override
  String get notificationChatCompletedTitle => 'Generation complete';

  @override
  String get notificationChatCompletedBody =>
      'Assistant reply has been generated';

  @override
  String get androidBackgroundNotificationTitle => 'Kelivo is running';

  @override
  String get androidBackgroundNotificationText =>
      'Keeping chat generation alive in background';

  @override
  String get assistantEditEmojiDialogTitle => 'Choose Emoji';

  @override
  String get assistantEditEmojiDialogHint => 'Type or paste any emoji';

  @override
  String get assistantEditEmojiDialogCancel => 'Cancel';

  @override
  String get assistantEditEmojiDialogSave => 'Save';

  @override
  String get assistantEditImageUrlDialogTitle => 'Enter Image URL';

  @override
  String get assistantEditImageUrlDialogHint =>
      'e.g. https://example.com/avatar.png';

  @override
  String get assistantEditImageUrlDialogCancel => 'Cancel';

  @override
  String get assistantEditImageUrlDialogSave => 'Save';

  @override
  String get assistantEditQQAvatarDialogTitle => 'Import from QQ';

  @override
  String get assistantEditQQAvatarDialogHint => 'Enter QQ number (5-12 digits)';

  @override
  String get assistantEditQQAvatarRandomButton => 'Random One';

  @override
  String get assistantEditQQAvatarFailedMessage =>
      'Failed to fetch random QQ avatar. Please try again.';

  @override
  String get assistantEditQQAvatarDialogCancel => 'Cancel';

  @override
  String get assistantEditQQAvatarDialogSave => 'Save';

  @override
  String get assistantEditGalleryErrorMessage =>
      'Unable to open gallery. Try entering an image URL.';

  @override
  String get assistantEditGeneralErrorMessage =>
      'Something went wrong. Try entering an image URL.';

  @override
  String get providerDetailPageMultiKeyModeTitle => 'Multi-Key Mode';

  @override
  String get providerDetailPageManageKeysButton => 'Manage Keys';

  @override
  String get multiKeyPageTitle => 'Multi-Key Manager';

  @override
  String get multiKeyPageDetect => 'Detect';

  @override
  String get multiKeyPageAdd => 'Add';

  @override
  String get multiKeyPageAddHint =>
      'Enter API keys, separated by comma or space';

  @override
  String multiKeyPageImportedSnackbar(int n) {
    return 'Imported $n keys';
  }

  @override
  String get multiKeyPagePleaseAddModel => 'Please add a model first';

  @override
  String get multiKeyPageTotal => 'Total';

  @override
  String get multiKeyPageNormal => 'Normal';

  @override
  String get multiKeyPageError => 'Error';

  @override
  String get multiKeyPageAccuracy => 'Accuracy';

  @override
  String get multiKeyPageStrategyTitle => 'Load Balancing Strategy';

  @override
  String get multiKeyPageStrategyRoundRobin => 'Round Robin';

  @override
  String get multiKeyPageStrategyPriority => 'Priority';

  @override
  String get multiKeyPageStrategyLeastUsed => 'Least Used';

  @override
  String get multiKeyPageStrategyRandom => 'Random';

  @override
  String get multiKeyPageNoKeys => 'No API keys';

  @override
  String get multiKeyPageStatusActive => 'Active';

  @override
  String get multiKeyPageStatusDisabled => 'Disabled';

  @override
  String get multiKeyPageStatusError => 'Error';

  @override
  String get multiKeyPageStatusRateLimited => 'Rate Limited';

  @override
  String get multiKeyPageEditAlias => 'Edit Alias';

  @override
  String get multiKeyPageEdit => 'Edit';

  @override
  String get multiKeyPageKey => 'API Key';

  @override
  String get multiKeyPagePriority => 'Priority (1–10)';

  @override
  String get multiKeyPageDuplicateKeyWarning => 'This key already exists';

  @override
  String get multiKeyPageAlias => 'Alias';

  @override
  String get multiKeyPageCancel => 'Cancel';

  @override
  String get multiKeyPageSave => 'Save';

  @override
  String get multiKeyPageDelete => 'Delete';

  @override
  String get assistantEditSystemPromptTitle => 'System Prompt';

  @override
  String get assistantEditSystemPromptHint => 'Enter system prompt…';

  @override
  String get assistantEditSystemPromptImportButton => 'Import file';

  @override
  String get assistantEditSystemPromptImportSuccess =>
      'System prompt updated from file';

  @override
  String get assistantEditSystemPromptImportFailed => 'Failed to import file';

  @override
  String get assistantEditSystemPromptImportEmpty => 'File is empty';

  @override
  String get assistantEditAvailableVariables => 'Available variables:';

  @override
  String get assistantEditVariableDate => 'Date';

  @override
  String get assistantEditVariableTime => 'Time';

  @override
  String get assistantEditVariableDatetime => 'Datetime';

  @override
  String get assistantEditVariableModelId => 'Model ID';

  @override
  String get assistantEditVariableModelName => 'Model Name';

  @override
  String get assistantEditVariableLocale => 'Locale';

  @override
  String get assistantEditVariableTimezone => 'Timezone';

  @override
  String get assistantEditVariableSystemVersion => 'System Version';

  @override
  String get assistantEditVariableDeviceInfo => 'Device Info';

  @override
  String get assistantEditVariableBatteryLevel => 'Battery Level';

  @override
  String get assistantEditVariableNickname => 'Nickname';

  @override
  String get assistantEditVariableAssistantName => 'Assistant Name';

  @override
  String get assistantEditMessageTemplateTitle => 'Message Template';

  @override
  String get assistantEditVariableRole => 'Role';

  @override
  String get assistantEditVariableMessage => 'Message';

  @override
  String get assistantEditPreviewTitle => 'Preview';

  @override
  String get assistantEditPromptTimeVarWarning =>
      'Using time variables in the system prompt makes the beginning of every request different, so prompt caching cannot hit and both cost and time-to-first-token go up. If the model needs to know the current time, use the \"Append current time\" switch below.';

  @override
  String get assistantEditPromptAppendTimeTitle => 'Append current time';

  @override
  String get assistantEditPromptAppendTimeSubtitle =>
      'Append the send time to the end of each user message. Time stays at the end of the request, so prompt caching is unaffected.';

  @override
  String get assistantEditPromptAppendTimeInfoTitle => 'Appended time format';

  @override
  String assistantEditPromptAppendTimeInfoBody(String example) {
    return 'When enabled, a blank line and then the following tag are appended at the end of each user message:\n\n$example\n\nThe timestamp is that message’s own send time, so it stays stable when you retry.';
  }

  @override
  String get assistantEditPromptAppendTimeInfoClose => 'Got it';

  @override
  String get assistantEditPromptTimeVarDialogTitle =>
      'System prompt contains time variables';

  @override
  String assistantEditPromptTimeVarDialogBody(String variables) {
    return 'Your system prompt uses $variables. The system prompt is re-rendered on every request, so time variables make the beginning of every request different and prompt caching cannot hit. Consider removing these variables and using \"Append current time\" instead — it puts the time at the end of the request and does not affect the prefix.';
  }

  @override
  String get assistantEditPromptTimeVarDialogRemove => 'Go remove';

  @override
  String get assistantEditPromptTimeVarDialogKeep => 'Enable anyway';

  @override
  String get codeBlockPreviewButton => 'Preview';

  @override
  String get codeBlockSaveAsButton => 'Save as file';

  @override
  String get codeBlockCollapseButton => 'Collapse';

  @override
  String get codeBlockExpandButton => 'Expand';

  @override
  String get codeBlockDefaultFileNameStem => 'code';

  @override
  String get markdownTableLabel => 'Table';

  @override
  String get markdownTableExportCsvTooltip => 'Export CSV';

  @override
  String get markdownTableSaveImageTooltip => 'Save to Gallery';

  @override
  String get markdownTableDefaultFileNameStem => 'table';

  @override
  String get markdownTableCopiedCsvSnackbar =>
      'CSV copied. Long press Copy to copy as image.';

  @override
  String get markdownTableCopiedMarkdownSnackbar => 'Table copied.';

  @override
  String codeBlockCollapsedLines(int n) {
    return '… $n lines folded';
  }

  @override
  String get htmlPreviewNotSupportedOnLinux =>
      'HTML preview is not supported on Linux';

  @override
  String get assistantEditSampleUser => 'User';

  @override
  String get assistantEditSampleMessage => 'Hello there';

  @override
  String get assistantEditSampleReply => 'Hello, how can I help you?';

  @override
  String get assistantEditMcpNoServersMessage => 'No running MCP servers';

  @override
  String get assistantEditMcpConnectedTag => 'Connected';

  @override
  String assistantEditMcpToolsCountTag(String enabled, String total) {
    return 'Tools: $enabled/$total';
  }

  @override
  String get assistantEditModelUseGlobalDefault => 'Use global default';

  @override
  String get assistantSettingsPageTitle => 'Assistant Settings';

  @override
  String get assistantSettingsCopyButton => 'Copy';

  @override
  String get assistantSettingsCopySuccess => 'Assistant copied';

  @override
  String get assistantSettingsCopySuffix => 'Copy';

  @override
  String get assistantSettingsDeleteButton => 'Delete';

  @override
  String get assistantSettingsEditButton => 'Edit';

  @override
  String get assistantSettingsAddSheetTitle => 'Assistant Name';

  @override
  String get assistantSettingsAddSheetHint => 'Enter a name';

  @override
  String get assistantSettingsAddSheetCancel => 'Cancel';

  @override
  String get assistantSettingsAddSheetSave => 'Save';

  @override
  String get desktopAssistantsListTitle => 'Assistants';

  @override
  String get desktopSidebarTabAssistants => 'Assistants';

  @override
  String get desktopSidebarTabTopics => 'Topics';

  @override
  String get desktopTrayMenuShowWindow => 'Show Window';

  @override
  String get desktopTrayMenuExit => 'Exit';

  @override
  String get hotkeyToggleAppVisibility => 'Show/Hide App';

  @override
  String get hotkeyCloseWindow => 'Close Window';

  @override
  String get hotkeyOpenSettings => 'Open Settings';

  @override
  String get hotkeyNewTopic => 'New Topic';

  @override
  String get hotkeySwitchModel => 'Switch Model';

  @override
  String get hotkeyToggleAssistantPanel => 'Toggle Assistants';

  @override
  String get hotkeyToggleTopicPanel => 'Toggle Topics';

  @override
  String get hotkeysPressShortcut => 'Press a shortcut';

  @override
  String get hotkeysResetDefault => 'Reset to default';

  @override
  String get hotkeysClearShortcut => 'Clear shortcut';

  @override
  String get hotkeysResetAll => 'Reset all to defaults';

  @override
  String get assistantEditTemperatureTitle => 'Temperature';

  @override
  String get assistantEditTopPTitle => 'Top-p';

  @override
  String get assistantSettingsDeleteDialogTitle => 'Delete Assistant';

  @override
  String get assistantSettingsDeleteDialogContent =>
      'Are you sure you want to delete this assistant? This action cannot be undone.';

  @override
  String get assistantSettingsDeleteDialogCancel => 'Cancel';

  @override
  String get assistantSettingsDeleteDialogConfirm => 'Delete';

  @override
  String get assistantSettingsAtLeastOneAssistantRequired =>
      'At least one assistant is required';

  @override
  String get mcpAssistantSheetTitle => 'MCP Servers';

  @override
  String get mcpAssistantSheetSubtitle => 'Servers enabled for this assistant';

  @override
  String get mcpAssistantSheetSelectAll => 'Select All';

  @override
  String get mcpAssistantSheetClearAll => 'Clear';

  @override
  String get backupPageTitle => 'Backup & Restore';

  @override
  String get backupPageWebDavTab => 'WebDAV';

  @override
  String get backupPageImportExportTab => 'Import/Export';

  @override
  String get backupPageWebDavServerUrl => 'WebDAV Server URL';

  @override
  String get backupPageUsername => 'Username';

  @override
  String get backupPagePassword => 'Password';

  @override
  String get backupPagePath => 'Path';

  @override
  String get backupPageChatsLabel => 'Chats';

  @override
  String get backupPageFilesLabel => 'Files';

  @override
  String get backupPageTestDone => 'Test done';

  @override
  String get backupPageTestConnection => 'Test';

  @override
  String get backupPageRestartRequired => 'Restart Required';

  @override
  String get backupPageRestartContent =>
      'Import successful. Restart Kelivo to apply it safely.';

  @override
  String backupPageRestartContentWithSkipped(int count) {
    return 'Import completed, but $count conversations with invalid message ordering were skipped. Restart Kelivo to apply the imported data safely.';
  }

  @override
  String get restartAppFailedMessage =>
      'Kelivo could not restart automatically. Fully close it, then open it again.';

  @override
  String get backupRestoreRolledBackTitle => 'Restore was rolled back';

  @override
  String get backupRestoreRolledBackContent =>
      'The restore could not be completed. Kelivo verified and kept your previous data.';

  @override
  String get backupRestoreFailureTitle => 'Restore requires attention';

  @override
  String get backupRestoreFailureContent =>
      'Kelivo could not verify a complete old or new data set, so chat data was not opened. Close Kelivo and try again. If this repeats, keep the diagnostic code for support.';

  @override
  String get backupRestoreBusinessLeaseUnavailableTitle =>
      'Kelivo is already running';

  @override
  String get backupRestoreBusinessLeaseUnavailableContent =>
      'Kelivo\'s data is still in use by another app process. Close any other Kelivo window, then restart. Your chat data has not been opened by this process.';

  @override
  String get backupRestoreFailureRestartButton => 'Restart Kelivo';

  @override
  String get backupRestoreFailureCopyButton => 'Copy diagnostic code';

  @override
  String get backupRestoreFailureCopied => 'Diagnostic code copied';

  @override
  String backupRestoreFailureDiagnostic(String code) {
    return 'Diagnostic code: $code';
  }

  @override
  String get startupRecoveryMoreOptions => 'More recovery options';

  @override
  String get startupRecoveryRepairButton => 'Repair and restart';

  @override
  String get startupRecoveryExportButton => 'Export a copy of my data';

  @override
  String get startupRecoveryResetButton => 'Reset data';

  @override
  String get startupRecoveryBusy => 'Working…';

  @override
  String get startupRecoveryExportSucceeded => 'A copy of your data was saved.';

  @override
  String get startupRecoveryExportFailed =>
      'Could not export a copy of your data.';

  @override
  String get startupRecoveryRepairFailed =>
      'Repair could not fix this. Export a copy of your data, then reset.';

  @override
  String get startupRecoveryResetFailed =>
      'Reset failed. Fully close Kelivo, then open it again.';

  @override
  String get startupRecoveryResetDialogTitle => 'Reset all data?';

  @override
  String get startupRecoveryResetDialogContent =>
      'This permanently deletes Kelivo\'s database on this device and starts fresh. If you might need this data, export a copy first. This cannot be undone.';

  @override
  String get startupRecoveryResetDialogConfirm => 'Reset and restart';

  @override
  String get startupRecoveryResetDialogCancel => 'Cancel';

  @override
  String get startupRecoveryWhatFailed => 'What failed';

  @override
  String get startupRecoveryStageLabel => 'Stage';

  @override
  String get startupRecoveryStageRestore => 'Restore gate';

  @override
  String get startupRecoveryStageDatabase => 'Database startup';

  @override
  String get startupRecoveryDiagnosticLabel => 'Diagnostic code';

  @override
  String get startupRecoverySchemaLabel => 'Database version';

  @override
  String startupRecoverySchemaValue(String installed, int expected) {
    return '$installed on disk · $expected expected by this build';
  }

  @override
  String get startupRecoveryAppVersionLabel => 'App';

  @override
  String get startupRecoveryUnknownValue => 'unknown';

  @override
  String get startupRecoveryCollecting => 'Collecting diagnostics…';

  @override
  String get startupRecoveryShowDetails => 'Show technical details';

  @override
  String get startupRecoveryHideDetails => 'Hide technical details';

  @override
  String get startupRecoveryCopyReport => 'Copy full report';

  @override
  String get startupRecoveryReportCopied => 'Full report copied';

  @override
  String get startupRecoveryShareReport => 'Export report';

  @override
  String startupRecoveryReportStored(String path) {
    return 'A copy of this report was saved to $path';
  }

  @override
  String startupRecoveryReportSaved(String path) {
    return 'Report saved to $path';
  }

  @override
  String get startupRecoveryReportShared => 'Report exported.';

  @override
  String get startupRecoveryReportSaveFailed => 'Could not export the report.';

  @override
  String get startupRecoverySectionDataTitle => 'Your data';

  @override
  String get startupRecoverySectionDataBody =>
      'Nothing has been deleted. Save a copy somewhere safe before trying anything below.';

  @override
  String startupRecoveryExportSavedTo(String path) {
    return 'A copy of your data was saved to $path';
  }

  @override
  String get startupRecoverySectionRepairTitle => 'Diagnose and repair';

  @override
  String get startupRecoverySectionRepairBody =>
      'The integrity check only reads the database. Repair clears leftover metadata from an interrupted update and retries startup; it never deletes chats.';

  @override
  String get startupRecoveryIntegrityButton => 'Check database integrity';

  @override
  String get startupRecoveryIntegrityHealthy =>
      'SQLite found no damage in the database file.';

  @override
  String startupRecoveryIntegrityDamaged(String detail) {
    return 'SQLite reported problems — $detail';
  }

  @override
  String get startupRecoveryIntegrityMissing =>
      'No database file was found in the data folder.';

  @override
  String get startupRecoveryIntegrityFailed =>
      'The integrity check could not run.';

  @override
  String get startupRecoveryDangerZone => 'Danger zone';

  @override
  String get startupRecoveryDangerBody =>
      'Resetting permanently deletes Kelivo\'s database on this device. Export a copy of your data first — a reset also destroys the evidence needed to fix the underlying problem.';

  @override
  String get startupRecoveryResetAcknowledge =>
      'I exported a copy, or I do not need this data.';

  @override
  String get startupDatabaseUpdateRequiredTitle => 'Update Kelivo to continue';

  @override
  String get startupDatabaseUpdateRequiredContent =>
      'The chat database on this device was created by a newer version of Kelivo and cannot be opened by this version. Your data has not been changed. Install the latest version of Kelivo, then open it again.';

  @override
  String backupPageRestoreFailedMessage(String error) {
    return 'Restore failed: $error';
  }

  @override
  String backupPageExportFailedMessage(String error) {
    return 'Export failed: $error';
  }

  @override
  String get backupPageOK => 'OK';

  @override
  String get backupPageCancel => 'Cancel';

  @override
  String get backupPageSelectImportMode => 'Select Import Mode';

  @override
  String get backupPageSelectImportModeDescription =>
      'Choose a restore mode. The chat and file switches determine which components are included.';

  @override
  String get backupPageOverwriteMode => 'Complete Overwrite';

  @override
  String get backupPageOverwriteModeDescription =>
      'Replace the selected components; keep unselected components and unrelated local settings';

  @override
  String get backupPageMergeMode => 'Merge';

  @override
  String get backupPageMergeModeDescription =>
      'Keep local data and add backup data. Identical conversations are skipped and conflicting conversations receive new IDs.';

  @override
  String get backupPageRestore => 'Restore';

  @override
  String get backupPageForwardCompatTitle => 'Backup is from a newer version';

  @override
  String backupPageForwardCompatBody(int backupVersion, int currentVersion) {
    return 'This backup was created by a newer version of Kelivo (data format $backupVersion; this version supports $currentVersion), and it does not say whether older versions can read it.\n\nYou can continue: anything this version does not recognise will be skipped, and the backup file itself is not modified. But if the newer version changed how existing data is stored, some content may be imported incorrectly.\n\nUpdating Kelivo first is the safer choice.';
  }

  @override
  String get backupPageForwardCompatContinue => 'Import anyway';

  @override
  String get backupPageForwardCompatCancel => 'Cancel';

  @override
  String get backupPageSchemaTooNewMessage =>
      'This backup was created by a newer version of Kelivo and cannot be read by this version. Please update Kelivo and try again.';

  @override
  String get backupPageBackupUploaded => 'Backup uploaded';

  @override
  String get backupPageBackup => 'Backup';

  @override
  String get backupPageExporting => 'Exporting...';

  @override
  String get backupProgressCancel => 'Cancel';

  @override
  String get backupProgressCancelled => 'Cancelled';

  @override
  String get backupProgressPreparing => 'Preparing';

  @override
  String get backupProgressSnapshotting => 'Creating database snapshot';

  @override
  String get backupProgressPacking => 'Packing';

  @override
  String get backupProgressVerifying => 'Verifying';

  @override
  String get backupProgressUploading => 'Uploading';

  @override
  String get backupProgressDownloading => 'Downloading';

  @override
  String get backupProgressExtracting => 'Extracting';

  @override
  String get backupProgressValidating => 'Validating';

  @override
  String get backupProgressReadingSettings => 'Reading settings';

  @override
  String get backupProgressStaging => 'Staging';

  @override
  String get backupProgressCommitting => 'Committing';

  @override
  String get backupProgressImportingSessions => 'Importing sessions';

  @override
  String get backupProgressImportingMessages => 'Importing messages';

  @override
  String get backupProgressMaterializingFiles => 'Writing files';

  @override
  String get backupProgressListingRemote => 'Listing remote backups';

  @override
  String get backupProgressFinalizing => 'Finishing';

  @override
  String backupProgressBytes(String done, String total) {
    return '$done / $total';
  }

  @override
  String backupProgressItems(String done, String total) {
    return '$done / $total';
  }

  @override
  String get backupPageExportToFile => 'Export to File';

  @override
  String get backupPageExportToFileSubtitle => 'Export app data to a file';

  @override
  String get backupPageImportBackupFile => 'Import Backup File';

  @override
  String get backupPageImportBackupFileSubtitle => 'Import a local backup file';

  @override
  String get backupPageImportFromOtherApps => 'Import from Other Apps';

  @override
  String get backupPageNotSupportedYet => 'Not supported yet';

  @override
  String get backupPageRemoteBackups => 'Remote Backups';

  @override
  String get backupPageNoBackups => 'No backups';

  @override
  String get backupPageRestoreTooltip => 'Restore';

  @override
  String get backupPageDeleteTooltip => 'Delete';

  @override
  String get backupPageDeleteConfirmTitle => 'Confirm Deletion';

  @override
  String backupPageDeleteConfirmContent(Object name) {
    return 'Are you sure you want to delete remote backup \"$name\"? This action cannot be undone.';
  }

  @override
  String get backupPageBackupManagement => 'Backup Management';

  @override
  String get backupPageWebDavBackup => 'WebDAV Backup';

  @override
  String get backupPageWebDavServerSettings => 'WebDAV Server Settings';

  @override
  String get backupPageS3Backup => 'S3 Backup';

  @override
  String get backupPageS3ServerSettings => 'S3 Settings';

  @override
  String get backupPageS3Endpoint => 'Endpoint';

  @override
  String get backupPageS3Region => 'Region';

  @override
  String get backupPageS3Bucket => 'Bucket';

  @override
  String get backupPageS3AccessKeyId => 'Access Key ID';

  @override
  String get backupPageS3SecretAccessKey => 'Secret Access Key';

  @override
  String get backupPageS3SessionToken => 'Session Token (Optional)';

  @override
  String get backupPageS3Prefix => 'Prefix';

  @override
  String get backupPageS3PathStyle => 'Path-style addressing';

  @override
  String get backupPageUserAgent => 'User-Agent';

  @override
  String get backupPageUserAgentHint => 'Optional';

  @override
  String get backupPageSave => 'Save';

  @override
  String get backupPageBackupNow => 'Backup Now';

  @override
  String get backupPageLocalBackup => 'Local Backup';

  @override
  String get backupPageImportFromCherryStudio => 'Import from Cherry Studio';

  @override
  String backupPageCherryStudioUnsupportedBackupVersion(String version) {
    return 'This backup uses Cherry Studio format version $version, which Kelivo cannot import yet. Export from Cherry Studio v1 instead, or wait for a Kelivo update that supports Cherry Studio v2 backups.';
  }

  @override
  String get backupPageImportFromChatbox => 'Import from Chatbox';

  @override
  String get backupReminderSectionTitle => 'Backup Reminder';

  @override
  String get backupReminderEnableTitle => 'Remind me to back up';

  @override
  String get backupReminderFrequencyTitle => 'Frequency';

  @override
  String get backupReminderTimeTitle => 'Reminder Time';

  @override
  String get backupReminderTimeInputHint => 'HH:mm';

  @override
  String get backupReminderTimeInvalid => 'Enter a time from 00:00 to 23:59.';

  @override
  String get backupReminderLastBackupTitle => 'Last Backup';

  @override
  String get backupReminderNextReminderTitle => 'Next Reminder';

  @override
  String get backupReminderNever => 'Never';

  @override
  String get backupReminderDisabled => 'Off';

  @override
  String get backupReminderDueNow => 'Due now';

  @override
  String get backupReminderEveryDay => 'Every day';

  @override
  String get backupReminderEveryThreeDays => 'Every 3 days';

  @override
  String get backupReminderEveryWeek => 'Every week';

  @override
  String get backupReminderEveryFourteenDays => 'Every 14 days';

  @override
  String get backupReminderEveryMonth => 'Every month';

  @override
  String backupReminderCustomDays(int days) {
    return 'Every $days days';
  }

  @override
  String get backupReminderCustomOption => 'Custom...';

  @override
  String get backupReminderCustomDialogTitle => 'Custom Frequency';

  @override
  String get backupReminderCustomDialogDescription =>
      'Enter how many days to wait between backup reminders.';

  @override
  String get backupReminderCustomDaysLabel => 'Days';

  @override
  String get backupReminderCustomDaysInvalid => 'Enter a number from 1 to 365.';

  @override
  String get backupReminderSidebarTitle => 'Backup reminder';

  @override
  String get backupReminderSidebarSubtitle =>
      'Your backup interval has arrived.';

  @override
  String get backupReminderSidebarAction => 'Go to backup';

  @override
  String get backupReminderSnoozeTooltip => 'Remind me later';

  @override
  String get chatHistoryPageTitle => 'Chat History';

  @override
  String get chatHistoryPageSearchTooltip => 'Search';

  @override
  String get chatHistoryPageDeleteAllTooltip => 'Delete Unpinned';

  @override
  String get chatHistoryPageDeleteAllDialogTitle =>
      'Delete Unpinned Conversations';

  @override
  String get chatHistoryPageDeleteAllDialogContent =>
      'Delete every non-pinned conversation for this assistant? Pinned chats stay in place.';

  @override
  String get chatHistoryPageCancel => 'Cancel';

  @override
  String get chatHistoryPageDelete => 'Delete';

  @override
  String get chatHistoryPageDeletedAllSnackbar =>
      'Unpinned conversations deleted';

  @override
  String get chatHistoryPageSearchHint => 'Search conversations';

  @override
  String get chatHistoryPageNoConversations => 'No conversations';

  @override
  String get chatHistoryPagePinnedSection => 'Pinned';

  @override
  String get chatHistoryPagePin => 'Pin';

  @override
  String get chatHistoryPagePinned => 'Pinned';

  @override
  String get messageEditPageTitle => 'Edit Message';

  @override
  String get messageEditPageSave => 'Save';

  @override
  String get messageEditPageSaveAndSend => 'Save & Send';

  @override
  String get messageEditPageHint => 'Enter message…';

  @override
  String get userMessageEditSaveOnly => 'Save Only';

  @override
  String get userMessageEditUnsupportedSnackbar =>
      'This content does not support editing';

  @override
  String get userMessageEditOverwriteTitle => 'Notice';

  @override
  String get userMessageEditOverwriteContent =>
      'Editing will overwrite the existing input. Overwrite it?';

  @override
  String get selectCopyPageTitle => 'Select & Copy';

  @override
  String get selectCopyPageCopyAll => 'Copy All';

  @override
  String get selectCopyPageCopiedAll => 'Copied all';

  @override
  String get bottomToolsSheetCamera => 'Camera';

  @override
  String get bottomToolsSheetPhotos => 'Photos';

  @override
  String get bottomToolsSheetUpload => 'Upload';

  @override
  String get bottomToolsSheetClearContext => 'Clear Context';

  @override
  String get compressContext => 'Compress Context';

  @override
  String get compressContextDesc => 'Summarize and start a new chat';

  @override
  String get clearContextDesc => 'Mark a context boundary';

  @override
  String get contextManagement => 'Context Management';

  @override
  String get compressingContext => 'Compressing context...';

  @override
  String get compressContextFailed => 'Failed to compress context';

  @override
  String get compressContextNoMessages => 'No messages to compress';

  @override
  String get compressContextNoConversation => 'No conversation to compress';

  @override
  String get compressContextNoModel => 'No compression model configured';

  @override
  String get compressContextEmptySummary =>
      'Compression returned an empty summary';

  @override
  String get compressContextOptionsTitle => 'Compress Context';

  @override
  String get compressContextOptionsDesc =>
      'Choose which part of the current chat is sent to the compression model.';

  @override
  String get compressContextKeepStart => 'Start';

  @override
  String get compressContextKeepRecent => 'Recent';

  @override
  String get compressContextUnlimited => 'Unlimited';

  @override
  String get compressContextMaxCharsLabel => 'Characters';

  @override
  String get compressContextInvalidLimit => 'Enter a positive character count';

  @override
  String get compressContextStartButton => 'Compress';

  @override
  String get compressContextModelLabel => 'Model';

  @override
  String get compressContextModelUnset => 'Select a model';

  @override
  String get compressContextKeepRecentMessages => 'Keep N';

  @override
  String get compressContextKeepCountLabel => 'Keep recent messages';

  @override
  String get compressContextKeepAllMessages =>
      'Keeping that many covers all messages — nothing to compress';

  @override
  String compressContextEstimatePreview(
    int summarized,
    int kept,
    int minTokens,
    int maxTokens,
    int totalTokens,
  ) {
    return 'Summarize $summarized chars, keep $kept chars verbatim → about $minTokens–$maxTokens tokens (original about $totalTokens tokens)';
  }

  @override
  String get bottomToolsSheetLearningMode => 'Learning Mode';

  @override
  String get bottomToolsSheetLearningModeDescription =>
      'Help you learn step by step';

  @override
  String get bottomToolsSheetConfigurePrompt => 'Configure prompt';

  @override
  String get bottomToolsSheetPrompt => 'Prompt';

  @override
  String get bottomToolsSheetPromptHint => 'Enter prompt text to inject';

  @override
  String get bottomToolsSheetResetDefault => 'Reset to default';

  @override
  String get bottomToolsSheetSave => 'Save';

  @override
  String get bottomToolsSheetOcr => 'Image OCR';

  @override
  String get messageMoreSheetTitle => 'More Actions';

  @override
  String get messageMoreSheetSelectCopy => 'Select & Copy';

  @override
  String get messageMoreSheetRenderWebView => 'Render Web View';

  @override
  String get messageMoreSheetNotImplemented => 'Not yet implemented';

  @override
  String get messageMoreSheetEdit => 'Edit';

  @override
  String get messageMoreSheetShare => 'Share';

  @override
  String get messageMoreSheetSelectMessages => 'Select Messages';

  @override
  String get messageMoreSheetCreateBranch => 'Create Branch';

  @override
  String get messageMoreSheetDelete => 'Delete This Version';

  @override
  String get messageMoreSheetDeleteAllVersions => 'Delete All Versions';

  @override
  String get reasoningBudgetSheetOff => 'Off';

  @override
  String get reasoningBudgetSheetAuto => 'Auto';

  @override
  String get reasoningBudgetSheetLight => 'Light Reasoning';

  @override
  String get reasoningBudgetSheetMedium => 'Medium Reasoning';

  @override
  String get reasoningBudgetSheetHeavy => 'Heavy Reasoning';

  @override
  String get reasoningBudgetSheetXhigh => 'Extreme Reasoning';

  @override
  String get reasoningBudgetSheetMax => 'Maximum Reasoning';

  @override
  String get reasoningBudgetSheetTitle => 'Reasoning Chain Strength';

  @override
  String reasoningBudgetSheetCurrentLevel(String level) {
    return 'Current Level: $level';
  }

  @override
  String get reasoningBudgetSheetOffSubtitle =>
      'Turn off reasoning, answer directly';

  @override
  String get reasoningBudgetSheetAutoSubtitle =>
      'Let the model decide reasoning level automatically';

  @override
  String get reasoningBudgetSheetLightSubtitle =>
      'Use light reasoning to answer questions';

  @override
  String get reasoningBudgetSheetMediumSubtitle =>
      'Use moderate reasoning to answer questions';

  @override
  String get reasoningBudgetSheetHeavySubtitle =>
      'Use heavy reasoning for complex questions';

  @override
  String get reasoningBudgetSheetXhighSubtitle =>
      'Use maximum reasoning depth for the toughest problems';

  @override
  String get reasoningBudgetSheetCustomLabel => 'Custom Reasoning Budget';

  @override
  String get reasoningBudgetSheetCustomHint => 'e.g. 2048 (-1 auto, 0 off)';

  @override
  String chatMessageWidgetFileNotFound(String fileName) {
    return 'File not found: $fileName';
  }

  @override
  String chatMessageWidgetCannotOpenFile(String message) {
    return 'Cannot open file: $message';
  }

  @override
  String chatMessageWidgetOpenFileError(String error) {
    return 'Failed to open file: $error';
  }

  @override
  String get chatMessageWidgetCopiedToClipboard => 'Copied to clipboard';

  @override
  String get chatMessageWidgetResendTooltip => 'Resend';

  @override
  String get chatMessageWidgetMoreTooltip => 'More';

  @override
  String get chatMessageWidgetThinking => 'Thinking...';

  @override
  String get chatMessageWidgetTranslation => 'Translation';

  @override
  String get chatMessageWidgetTranslating => 'Translating...';

  @override
  String get chatMessageWidgetCitationNotFound => 'Citation source not found';

  @override
  String chatMessageWidgetCannotOpenUrl(String url) {
    return 'Cannot open link: $url';
  }

  @override
  String get chatMessageWidgetOpenLinkError => 'Failed to open link';

  @override
  String get chatMessageWidgetAttachmentUnavailable => 'Attachment unavailable';

  @override
  String chatMessageWidgetCitationsTitle(int count) {
    return 'Citations ($count)';
  }

  @override
  String get chatMessageWidgetSearchResultsTitle => 'Search results';

  @override
  String get chatMessageWidgetCitationSourcesTitle => 'Citation sources';

  @override
  String get chatMessageWidgetRegenerateTooltip => 'Regenerate';

  @override
  String get chatMessageWidgetRegenerateConfirmTitle => 'Confirm Regenerate';

  @override
  String get chatMessageWidgetRegenerateConfirmContent =>
      'Regenerating only updates this message and keeps the messages below it. Continue?';

  @override
  String get chatMessageWidgetRegenerateConfirmDeleteTrailingContent =>
      'Regenerating will delete all messages below this message and cannot be undone. Continue?';

  @override
  String get chatMessageWidgetRegenerateConfirmCancel => 'Cancel';

  @override
  String get chatMessageWidgetRegenerateConfirmOk => 'Regenerate';

  @override
  String get chatMessageWidgetStopTooltip => 'Stop';

  @override
  String get chatMessageWidgetSpeakTooltip => 'Speak';

  @override
  String get chatMessageWidgetTranslateTooltip => 'Translate';

  @override
  String get chatMessageWidgetBuiltinSearchHideNote =>
      'Hide builtin search tool cards';

  @override
  String get chatMessageWidgetDeepThinking => 'Deep Thinking';

  @override
  String chatMessageWidgetWebSearch(String query) {
    return 'Web Search: $query';
  }

  @override
  String get chatMessageWidgetBuiltinSearch => 'Built-in Search';

  @override
  String get chatMessageWidgetReadClipboard => 'Read Clipboard';

  @override
  String get chatMessageWidgetWriteClipboard => 'Write Clipboard';

  @override
  String get chatMessageWidgetSpeakingTitle => 'Speaking:';

  @override
  String chatMessageWidgetSpeakText(String text) {
    return 'Speaking: $text';
  }

  @override
  String get chatMessageWidgetMemoryRead => 'Read Memory';

  @override
  String get chatMessageWidgetMemoryUpdate => 'Update Memory';

  @override
  String get chatMessageWidgetMemorySearchProfile => 'Search Memory';

  @override
  String get chatMessageWidgetMemoryEdit => 'Edit Memory';

  @override
  String get chatMessageWidgetMemoryDelete => 'Delete Memory';

  @override
  String get chatMessageWidgetUpdateUserProfile => 'Update User Profile';

  @override
  String get chatMessageWidgetChatSearch => 'Search Past Chats';

  @override
  String get chatMessageWidgetCreateMemory => 'Create Memory';

  @override
  String chatMessageWidgetToolCall(String name) {
    return 'Tool Call: $name';
  }

  @override
  String chatMessageWidgetToolResult(String name) {
    return 'Tool Result: $name';
  }

  @override
  String get chatMessageWidgetNoResultYet => '(No result yet)';

  @override
  String get chatMessageWidgetArguments => 'Arguments';

  @override
  String get chatMessageWidgetResult => 'Result';

  @override
  String get chatMessageWidgetImages => 'Images';

  @override
  String chatMessageWidgetCitationsCount(int count) {
    return '$count citations';
  }

  @override
  String chatSelectionSelectedCountTitle(int count) {
    return 'Selected $count message(s)';
  }

  @override
  String get chatSelectionExportTxt => 'TXT';

  @override
  String get chatSelectionExportMd => 'MD';

  @override
  String get chatSelectionExportImage => 'Image';

  @override
  String get chatSelectionThinkingTools => 'Thinking tools';

  @override
  String get chatSelectionThinkingContent => 'Thinking content';

  @override
  String get chatSelectionDeleteSelected => 'Delete Selected';

  @override
  String get chatSelectionSelectMessagesToDelete =>
      'Please select messages to delete';

  @override
  String chatSelectionDeleteSelectedConfirm(int count) {
    return 'Delete $count selected version(s)? This cannot be undone.';
  }

  @override
  String chatSelectionDeleteSelectedAllVersionsConfirm(int count) {
    return 'Delete all versions of $count selected message(s)? This cannot be undone.';
  }

  @override
  String get messageExportSheetAssistant => 'Assistant';

  @override
  String get messageExportSheetDefaultTitle => 'New Chat';

  @override
  String get messageExportSheetExporting => 'Exporting…';

  @override
  String messageExportSheetExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String messageExportSheetExportedAs(String filename) {
    return 'Exported as $filename';
  }

  @override
  String get displaySettingsPageEnableDollarLatexTitle =>
      'Inline \$...\$ Rendering';

  @override
  String get displaySettingsPageEnableDollarLatexSubtitle =>
      'Render inline math inside \$...\$';

  @override
  String get displaySettingsPageEnableMathTitle => 'Math Formula Rendering';

  @override
  String get displaySettingsPageEnableMathSubtitle =>
      'Render LaTeX math (inline and block)';

  @override
  String get displaySettingsPageEnableUserMarkdownTitle =>
      'Render user messages with Markdown';

  @override
  String get displaySettingsPageEnableReasoningMarkdownTitle =>
      'Render reasoning (thinking) with Markdown';

  @override
  String get displaySettingsPageEnableAssistantMarkdownTitle =>
      'Render assistant messages with Markdown';

  @override
  String get displaySettingsPageMobileCodeBlockWrapTitle =>
      'Mobile Code Block Word Wrap';

  @override
  String get displaySettingsPageAutoCollapseCodeBlockTitle =>
      'Auto-collapse Code Blocks';

  @override
  String get displaySettingsPageAutoCollapseCodeBlockLinesTitle =>
      'Auto-collapse threshold';

  @override
  String get displaySettingsPageAutoCollapseCodeBlockLinesUnit => 'lines';

  @override
  String get messageExportSheetFormatTitle => 'Export Format';

  @override
  String get messageExportSheetMarkdown => 'Markdown';

  @override
  String get messageExportSheetSingleMarkdownSubtitle =>
      'Export this message as a Markdown file';

  @override
  String get messageExportSheetBatchMarkdownSubtitle =>
      'Export selected messages as a Markdown file';

  @override
  String get messageExportSheetPlainText => 'Plain Text';

  @override
  String get messageExportSheetSingleTxtSubtitle =>
      'Export this message as a TXT file';

  @override
  String get messageExportSheetBatchTxtSubtitle =>
      'Export selected messages as a TXT file';

  @override
  String get messageExportSheetExportImage => 'Export as Image';

  @override
  String get messageExportSheetSingleExportImageSubtitle =>
      'Render this message to a PNG image';

  @override
  String get messageExportSheetBatchExportImageSubtitle =>
      'Render selected messages to a PNG image';

  @override
  String get messageExportSheetShowThinkingAndToolCards =>
      'Show Deep Thinking and tool cards';

  @override
  String get messageExportSheetShowThinkingContent => 'Show thinking content';

  @override
  String get messageExportThinkingContentLabel => 'Thinking content';

  @override
  String get messageExportSheetDateTimeWithSecondsPattern =>
      'yyyy-MM-dd HH:mm:ss';

  @override
  String get exportDisclaimerAiGenerated =>
      'Content generated by AI. Please verify carefully.';

  @override
  String get imagePreviewSheetSaveImage => 'Save Image';

  @override
  String get imagePreviewSheetSaveSuccess => 'Saved to gallery';

  @override
  String imagePreviewSheetSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get sideDrawerMenuRename => 'Rename';

  @override
  String get sideDrawerMenuPin => 'Pin';

  @override
  String get sideDrawerMenuUnpin => 'Unpin';

  @override
  String get sideDrawerMenuRegenerateTitle => 'Regenerate Title';

  @override
  String get sideDrawerMenuCopy => 'Copy';

  @override
  String get sideDrawerMenuMoveTo => 'Move to';

  @override
  String get sideDrawerMenuDelete => 'Delete';

  @override
  String get sideDrawerMenuSelect => 'Select';

  @override
  String sideDrawerSelectionTitle(int count) {
    return 'Selected $count items';
  }

  @override
  String get sideDrawerSelectionSelectAll => 'Select all';

  @override
  String get sideDrawerSelectionDeselectAll => 'Deselect all';

  @override
  String get sideDrawerSelectionPin => 'Pin';

  @override
  String get sideDrawerSelectionUnpin => 'Unpin';

  @override
  String get sideDrawerSelectionMove => 'Move';

  @override
  String get sideDrawerSelectionDelete => 'Delete';

  @override
  String get sideDrawerSelectionDeleteConfirmTitle => 'Delete conversations';

  @override
  String sideDrawerSelectionDeleteConfirmContent(int count) {
    return 'Delete $count conversations?';
  }

  @override
  String sideDrawerDeleteSelectedSnackbar(int count) {
    return 'Deleted $count conversations';
  }

  @override
  String sideDrawerMoveSelectedSnackbar(int count) {
    return 'Moved $count conversations';
  }

  @override
  String sideDrawerDeleteSnackbar(String title) {
    return 'Deleted \"$title\"';
  }

  @override
  String get sideDrawerRenameHint => 'Enter new name';

  @override
  String get sideDrawerCancel => 'Cancel';

  @override
  String get sideDrawerOK => 'OK';

  @override
  String get sideDrawerSave => 'Save';

  @override
  String get sideDrawerGreetingMorning => 'Good morning 👋';

  @override
  String get sideDrawerGreetingNoon => 'Good afternoon 👋';

  @override
  String get sideDrawerGreetingAfternoon => 'Good afternoon 👋';

  @override
  String get sideDrawerGreetingEvening => 'Good evening 👋';

  @override
  String get sideDrawerDateToday => 'Today';

  @override
  String get sideDrawerDateYesterday => 'Yesterday';

  @override
  String get sideDrawerDateShortPattern => 'MMM d';

  @override
  String get sideDrawerDateFullPattern => 'MMM d, yyyy';

  @override
  String get sideDrawerSearchHint => 'Search current assistant';

  @override
  String get sideDrawerSearchAssistantsHint => 'Search assistants';

  @override
  String get sideDrawerTopicSearchModeLabel => 'Topic mode';

  @override
  String get sideDrawerGlobalSearchModeLabel => 'Global mode';

  @override
  String get sideDrawerSearchModeSwipeToTopicHint =>
      'Swipe the search bar for topic search';

  @override
  String get sideDrawerSearchModeSwipeToGlobalHint =>
      'Swipe the search bar for global search';

  @override
  String get sideDrawerGlobalSearchHint => 'Search all sessions';

  @override
  String get sideDrawerGlobalSearchEmptyHint =>
      'Search across titles and messages';

  @override
  String get sideDrawerGlobalSearchNoResults => 'No matching sessions';

  @override
  String sideDrawerGlobalSearchResultCount(int count) {
    return '$count results';
  }

  @override
  String sideDrawerUpdateTitle(String version) {
    return 'New version: $version';
  }

  @override
  String sideDrawerUpdateTitleWithBuild(String version, int build) {
    return 'New version: $version ($build)';
  }

  @override
  String get sideDrawerLinkCopied => 'Link copied';

  @override
  String get sideDrawerPinnedLabel => 'Pinned';

  @override
  String get sideDrawerHistory => 'History';

  @override
  String get sideDrawerSettings => 'Settings';

  @override
  String get sideDrawerChooseAssistantTitle => 'Choose Assistant';

  @override
  String get sideDrawerChooseImage => 'Choose Image';

  @override
  String get sideDrawerChooseEmoji => 'Choose Emoji';

  @override
  String get sideDrawerEnterLink => 'Enter Link';

  @override
  String get sideDrawerImportFromQQ => 'Import from QQ';

  @override
  String get sideDrawerReset => 'Reset';

  @override
  String get providerAvatarChooseBuiltInIcon => 'Choose Built-in Icon';

  @override
  String get providerAvatarIconDialogTitle => 'Choose Built-in Icon';

  @override
  String get providerAvatarIconSearchHint => 'Search icons';

  @override
  String get providerAvatarIconNoResults => 'No icons found';

  @override
  String get providerAvatarInputLobehubIcon => 'Enter LobeHub Icon';

  @override
  String get providerAvatarChooseLobehubIcon => 'Enter LobeHub Icon';

  @override
  String get providerAvatarLobehubDialogTitle => 'Enter LobeHub Icon';

  @override
  String get providerAvatarLobehubDialogHint =>
      'Enter a LobeHub icon name, e.g. openai';

  @override
  String get sideDrawerEmojiDialogTitle => 'Choose Emoji';

  @override
  String get sideDrawerEmojiDialogHint => 'Type or paste any emoji';

  @override
  String get sideDrawerImageUrlDialogTitle => 'Enter Image URL';

  @override
  String get sideDrawerImageUrlDialogHint =>
      'e.g. https://example.com/avatar.png';

  @override
  String get sideDrawerQQAvatarDialogTitle => 'Import from QQ';

  @override
  String get sideDrawerQQAvatarInputHint => 'Enter QQ number (5-12 digits)';

  @override
  String get sideDrawerQQAvatarFetchFailed =>
      'Failed to fetch random QQ avatar. Please try again.';

  @override
  String get sideDrawerRandomQQ => 'Random QQ';

  @override
  String get sideDrawerGalleryOpenError =>
      'Unable to open gallery. Try entering an image URL.';

  @override
  String get sideDrawerGeneralImageError =>
      'Something went wrong. Try entering an image URL.';

  @override
  String get sideDrawerSetNicknameTitle => 'Set Nickname';

  @override
  String get sideDrawerNicknameLabel => 'Nickname';

  @override
  String get sideDrawerNicknameHint => 'Enter new nickname';

  @override
  String get sideDrawerRename => 'Rename';

  @override
  String get chatInputBarHint => 'Type a message for AI';

  @override
  String get chatInputBarSelectModelTooltip => 'Select Model';

  @override
  String get chatInputBarOnlineSearchTooltip => 'Online Search';

  @override
  String get chatInputBarReasoningStrengthTooltip => 'Reasoning Strength';

  @override
  String get chatInputBarMcpServersTooltip => 'MCP Servers';

  @override
  String get chatInputBarMoreTooltip => 'Add';

  @override
  String get chatInputBarVoiceInputTooltip => 'Voice input';

  @override
  String get chatInputBarVoiceCancelTooltip => 'Discard recording';

  @override
  String get chatInputBarVoiceStopTooltip => 'Stop and transcribe to input';

  @override
  String get chatInputBarVoiceSendTooltip => 'Transcribe and send';

  @override
  String get chatInputBarVoiceTranscribing => 'Recognizing…';

  @override
  String get chatInputBarImageProcessing => 'Processing image';

  @override
  String get chatInputBarImageMode => 'Image mode';

  @override
  String get chatInputBarDisableImageModeTooltip => 'Turn off image mode';

  @override
  String get chatInputBarQueuedPending => 'Queued to send';

  @override
  String get chatInputBarQueuedCancel => 'Cancel Queue';

  @override
  String get chatInputBarInsertNewline => 'Newline';

  @override
  String get chatInputBarExpand => 'Expand';

  @override
  String get chatInputBarCollapse => 'Collapse';

  @override
  String get mcpPageBackTooltip => 'Back';

  @override
  String get mcpPageAddMcpTooltip => 'Add MCP';

  @override
  String get mcpPageNoServers => 'No MCP servers';

  @override
  String get mcpPageErrorDialogTitle => 'Connection Error';

  @override
  String get mcpPageErrorNoDetails => 'No details';

  @override
  String get mcpPageClose => 'Close';

  @override
  String get mcpPageReconnect => 'Reconnect';

  @override
  String get mcpPageStatusConnected => 'Connected';

  @override
  String get mcpPageStatusConnecting => 'Connecting…';

  @override
  String get mcpPageStatusDisconnected => 'Disconnected';

  @override
  String get mcpPageStatusAuthorizationRequired => 'Authorization required';

  @override
  String get mcpPageStatusAuthorizing => 'Authorizing…';

  @override
  String get mcpPageStatusDisabled => 'Disabled';

  @override
  String get mcpPageOAuthRequired => 'OAuth sign-in is required';

  @override
  String get mcpPageOAuthSignIn => 'Sign in with OAuth';

  @override
  String mcpPageToolsCount(int enabled, int total) {
    return 'Tools: $enabled/$total';
  }

  @override
  String get mcpPageConnectionFailed => 'Connection failed';

  @override
  String get mcpPageDetails => 'Details';

  @override
  String get mcpPageDelete => 'Delete';

  @override
  String get mcpPageConfirmDeleteTitle => 'Confirm Delete';

  @override
  String get mcpPageConfirmDeleteContent =>
      'This can be undone via Undo. Delete?';

  @override
  String get mcpPageServerDeleted => 'Server deleted';

  @override
  String get mcpPageUndo => 'Undo';

  @override
  String get mcpPageCancel => 'Cancel';

  @override
  String get mcpConversationSheetTitle => 'MCP Servers';

  @override
  String get mcpConversationSheetSubtitle =>
      'Select servers enabled for this conversation';

  @override
  String get mcpConversationSheetSelectAll => 'Select All';

  @override
  String get mcpConversationSheetClearAll => 'Clear';

  @override
  String get mcpConversationSheetNoRunning => 'No running MCP servers';

  @override
  String get mcpConversationSheetConnected => 'Connected';

  @override
  String mcpConversationSheetToolsCount(int enabled, int total) {
    return 'Tools: $enabled/$total';
  }

  @override
  String get mcpServerEditSheetEnabledLabel => 'Enabled';

  @override
  String get mcpServerEditSheetNameLabel => 'Name';

  @override
  String get mcpServerEditSheetTransportLabel => 'Transport';

  @override
  String get mcpServerEditSheetSseRetryHint => 'If SSE fails, try a few times';

  @override
  String get mcpServerEditSheetUrlLabel => 'Server URL';

  @override
  String get mcpServerEditSheetCustomHeadersTitle => 'Custom Headers';

  @override
  String get mcpServerEditSheetHeaderNameLabel => 'Header Name';

  @override
  String get mcpServerEditSheetHeaderNameHint => 'e.g. Authorization';

  @override
  String get mcpServerEditSheetHeaderValueLabel => 'Header Value';

  @override
  String get mcpServerEditSheetHeaderValueHint => 'e.g. Bearer xxxxxx';

  @override
  String get mcpServerEditSheetRemoveHeaderTooltip => 'Remove';

  @override
  String get mcpServerEditSheetAddHeader => 'Add Header';

  @override
  String get mcpServerEditSheetTitleEdit => 'Edit MCP';

  @override
  String get mcpServerEditSheetTitleAdd => 'Add MCP';

  @override
  String get mcpServerEditSheetSyncToolsTooltip => 'Sync Tools';

  @override
  String get mcpServerEditSheetTabBasic => 'Basic';

  @override
  String get mcpServerEditSheetTabTools => 'Tools';

  @override
  String get mcpServerEditSheetNoToolsHint => 'No tools, tap refresh to sync';

  @override
  String get mcpServerEditSheetCancel => 'Cancel';

  @override
  String get mcpServerEditSheetSave => 'Save';

  @override
  String get mcpServerEditSheetUrlRequired => 'Please enter server URL';

  @override
  String get defaultModelPageBackTooltip => 'Back';

  @override
  String get defaultModelPageTitle => 'Default Model';

  @override
  String get defaultModelPageChatModelTitle => 'Chat Model';

  @override
  String get defaultModelPageChatModelSubtitle => 'Global default chat model';

  @override
  String get defaultModelPageTitleModelTitle => 'Title Summary Model';

  @override
  String get defaultModelPageTitleModelSubtitle =>
      'Summarizes conversation titles using the current chat model by default, or a selected model.';

  @override
  String get titleModelThinkingTitle => 'Enable Thinking';

  @override
  String get defaultModelPageSummaryModelTitle => 'Summary Model';

  @override
  String get defaultModelPageSummaryModelSubtitle =>
      'Used for generating conversation summaries; prefer fast and cheap models';

  @override
  String get defaultModelPageSuggestionModelTitle => 'Chat Suggestions Model';

  @override
  String get defaultModelPageSuggestionModelSubtitle =>
      'Generates follow-up suggestion bubbles using the current chat model or a selected model. Disabled by default.';

  @override
  String get assistantEditRecentChatsSummaryFrequencyTitle =>
      'Summary Refresh Frequency';

  @override
  String get assistantEditRecentChatsSummaryFrequencyDescription =>
      'Refresh recent-chat summaries after the selected number of new messages.';

  @override
  String assistantEditRecentChatsSummaryFrequencyOption(int count) {
    return 'Every $count';
  }

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomButton => 'Custom';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomTitle =>
      'Custom Summary Frequency';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomDescription =>
      'Enter how many new messages should accumulate before refreshing the recent-chat summary.';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomLabel =>
      'New message count';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomHint =>
      'Enter a number greater than 0';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomInvalid =>
      'Please enter a whole number greater than 0';

  @override
  String get defaultModelPageTranslateModelTitle => 'Translation Model';

  @override
  String get defaultModelPageTranslateModelSubtitle =>
      'Used for translating message content; prefer fast & accurate models';

  @override
  String get defaultModelPageOcrModelTitle => 'OCR Model';

  @override
  String backgroundTaskFailed(String task, String error) {
    return '$task failed: $error';
  }

  @override
  String get defaultModelPageOcrModelSubtitle =>
      'Used for extracting text and descriptions from images';

  @override
  String get defaultModelPageOcrModelRequiresImageInput =>
      'Select a model tagged with image input for OCR';

  @override
  String get defaultModelPagePromptLabel => 'Prompt';

  @override
  String get defaultModelPageTitlePromptHint =>
      'Enter prompt template for title summarization';

  @override
  String get defaultModelPageSummaryPromptHint =>
      'Enter prompt template for summary generation';

  @override
  String get defaultModelPageSuggestionPromptHint =>
      'Enter prompt template for chat suggestions';

  @override
  String get defaultModelPageTranslatePromptHint =>
      'Enter prompt template for translation';

  @override
  String get defaultModelPageOcrPromptHint =>
      'Enter prompt template for OCR image understanding';

  @override
  String get defaultModelPageResetDefault => 'Reset to default';

  @override
  String get defaultModelPageDisable => 'Disable';

  @override
  String get defaultModelPageSave => 'Save';

  @override
  String defaultModelPageTitleVars(String contentVar, String localeVar) {
    return 'Vars: content: $contentVar, locale: $localeVar';
  }

  @override
  String defaultModelPageSummaryVars(
    String previousSummaryVar,
    String userMessagesVar,
  ) {
    return 'Variables: previous summary: $previousSummaryVar, new messages: $userMessagesVar';
  }

  @override
  String defaultModelPageSuggestionVars(String contentVar, String localeVar) {
    return 'Variables: conversation: $contentVar, language: $localeVar';
  }

  @override
  String get defaultModelPageCompressModelTitle => 'Compress Model';

  @override
  String get defaultModelPageCompressModelSubtitle =>
      'Used for compressing conversation context; prefer fast models';

  @override
  String get defaultModelPageCompressPromptHint =>
      'Enter prompt template for context compression';

  @override
  String defaultModelPageCompressVars(String contentVar, String localeVar) {
    return 'Variables: conversation: $contentVar, language: $localeVar';
  }

  @override
  String defaultModelPageTranslateVars(String sourceVar, String targetVar) {
    return 'Variables: source text: $sourceVar, target language: $targetVar';
  }

  @override
  String get defaultModelPageUseCurrentModel => 'Use current chat model';

  @override
  String get defaultModelPageNotEnabled => 'Not enabled';

  @override
  String get translatePagePasteButton => 'Paste';

  @override
  String get translatePageCopyResult => 'Copy result';

  @override
  String get translatePageClearAll => 'Clear All';

  @override
  String get translatePageInputHint => 'Enter text to translate…';

  @override
  String get translatePageOutputHint => 'Translated result appears here…';

  @override
  String get modelDetailSheetAddModel => 'Add Model';

  @override
  String get modelDetailSheetEditModel => 'Edit Model';

  @override
  String get modelDetailSheetBasicTab => 'Basic';

  @override
  String get modelDetailSheetAdvancedTab => 'Advanced';

  @override
  String get modelDetailSheetBuiltinToolsTab => 'Built-in Tools';

  @override
  String get modelDetailSheetModelIdLabel => 'Model ID';

  @override
  String get modelDetailSheetModelIdHint =>
      'Required, suggest lowercase/digits/hyphens';

  @override
  String modelDetailSheetModelIdDisabledHint(String modelId) {
    return '$modelId';
  }

  @override
  String get modelDetailSheetModelNameLabel => 'Model Name';

  @override
  String get modelDetailSheetModelTypeLabel => 'Model Type';

  @override
  String get modelDetailSheetChatType => 'Chat';

  @override
  String get modelDetailSheetEmbeddingType => 'Embedding';

  @override
  String get modelDetailSheetInputModesLabel => 'Input Modes';

  @override
  String get modelDetailSheetOutputModesLabel => 'Output Modes';

  @override
  String get modelDetailSheetAbilitiesLabel => 'Abilities';

  @override
  String get modelDetailSheetTextMode => 'Text';

  @override
  String get modelDetailSheetImageMode => 'Image';

  @override
  String get modelDetailSheetToolsAbility => 'Tools';

  @override
  String get modelDetailSheetReasoningAbility => 'Reasoning';

  @override
  String get modelDetailSheetProviderOverrideDescription =>
      'Provider overrides: customize provider for a specific model.';

  @override
  String get modelDetailSheetAddProviderOverride => 'Add Provider Override';

  @override
  String get modelDetailSheetCustomHeadersTitle => 'Custom Headers';

  @override
  String get modelDetailSheetAddHeader => 'Add Header';

  @override
  String get modelDetailSheetCustomBodyTitle => 'Custom Body';

  @override
  String get modelFetchInvertTooltip => 'Invert';

  @override
  String get modelDetailSheetSaveFailedMessage =>
      'Save failed. Please try again.';

  @override
  String get modelDetailSheetAddBody => 'Add Body';

  @override
  String get modelDetailSheetBuiltinToolsDescription =>
      'Built-in tools depend on the provider and API mode.';

  @override
  String get modelDetailSheetSearchTool => 'Search';

  @override
  String get modelDetailSheetSearchToolDescription =>
      'Enable Google Search integration';

  @override
  String get modelDetailSheetUrlContextTool => 'URL Context';

  @override
  String get modelDetailSheetUrlContextToolDescription =>
      'Enable URL content ingestion';

  @override
  String get modelDetailSheetCodeExecutionTool => 'Code Execution';

  @override
  String get modelDetailSheetCodeExecutionToolDescription =>
      'Enable code execution tool';

  @override
  String get modelDetailSheetYoutubeTool => 'YouTube';

  @override
  String get modelDetailSheetYoutubeToolDescription =>
      'Enable YouTube URL ingestion (auto-detect links in prompts)';

  @override
  String get modelDetailSheetOpenaiBuiltinToolsResponsesOnlyHint =>
      'Requires OpenAI Responses API.';

  @override
  String get modelDetailSheetWebFetchTool => 'Web Fetch';

  @override
  String get modelDetailSheetOpenrouterWebFetchToolDescription =>
      'Enable OpenRouter web fetch server tool';

  @override
  String get modelDetailSheetClaudeWebFetchToolDescription =>
      'Let Claude fetch pages and PDFs from URLs in the conversation';

  @override
  String get modelDetailSheetClaudeCodeExecutionToolDescription =>
      'Let Claude run Python and Bash in Anthropic\'s sandbox';

  @override
  String get modelDetailSheetOpenrouterShellTool => 'Shell';

  @override
  String get modelDetailSheetOpenrouterShellToolDescription =>
      'Run Shell commands in a hosted, isolated sandbox';

  @override
  String get modelDetailSheetOpenaiCodeInterpreterTool => 'Code Interpreter';

  @override
  String get modelDetailSheetOpenaiCodeInterpreterToolDescription =>
      'Enable code interpreter tool (container auto, memory limit 4g)';

  @override
  String get modelDetailSheetOpenaiImageGenerationTool => 'Image Generation';

  @override
  String get modelDetailSheetOpenaiImageGenerationToolDescription =>
      'Enable image generation tool';

  @override
  String get modelDetailSheetCancelButton => 'Cancel';

  @override
  String get modelDetailSheetAddButton => 'Add';

  @override
  String get modelDetailSheetConfirmButton => 'Confirm';

  @override
  String get modelDetailSheetInvalidIdError =>
      'Please enter a valid model ID (>=2 chars)';

  @override
  String get modelDetailSheetModelIdExistsError => 'Model ID already exists';

  @override
  String get modelDetailSheetHeaderKeyHint => 'Header Key';

  @override
  String get modelDetailSheetHeaderValueHint => 'Header Value';

  @override
  String get modelDetailSheetBodyKeyHint => 'Body Key';

  @override
  String get modelDetailSheetBodyJsonHint => 'Body JSON';

  @override
  String get modelSelectSheetSearchHint => 'Search models or providers';

  @override
  String get modelSelectSheetFavoritesSection => 'Favorites';

  @override
  String get modelSelectSheetFollowAssistant => 'Follow assistant';

  @override
  String get modelSelectSheetFavoriteTooltip => 'Favorite';

  @override
  String get modelSelectSheetChatType => 'Chat';

  @override
  String get modelSelectSheetEmbeddingType => 'Embedding';

  @override
  String get providerDetailPageShareTooltip => 'Share';

  @override
  String get providerDetailPageDeleteProviderTooltip => 'Delete Provider';

  @override
  String get providerDetailPageDeleteProviderTitle => 'Delete Provider';

  @override
  String get providerDetailPageDeleteProviderContent =>
      'Are you sure you want to delete this provider? This cannot be undone.';

  @override
  String get providerDetailPageCancelButton => 'Cancel';

  @override
  String get providerDetailPageDeleteButton => 'Delete';

  @override
  String get providerDetailPageProviderDeletedSnackbar => 'Provider deleted';

  @override
  String get providerDetailPageConfigTab => 'Config';

  @override
  String get providerDetailPageModelsTab => 'Models';

  @override
  String get providerDetailPageCustomRequestTitle => 'Custom Request';

  @override
  String get providerDetailPageCustomRequestDescription =>
      'Applies to every model from this provider. Model settings override these values; these values override assistant settings.';

  @override
  String get providerDetailPageNetworkTab => 'Network';

  @override
  String get providerDetailPageEnabledTitle => 'Enabled';

  @override
  String get providerDetailPageManageSectionTitle => 'Manage';

  @override
  String get providerDetailPageNameLabel => 'Name';

  @override
  String get providerDetailPageApiKeyHint => 'Leave empty to use default';

  @override
  String get providerDetailPageHideTooltip => 'Hide';

  @override
  String get providerDetailPageShowTooltip => 'Show';

  @override
  String get providerDetailPageApiPathLabel => 'API Path';

  @override
  String get providerDetailPageResponseApiTitle => 'Response API (/responses)';

  @override
  String get providerDetailPageAihubmixAppCodeLabel => 'APP-Code (10% off)';

  @override
  String get providerDetailPageAihubmixAppCodeHelp =>
      'Adds header APP-Code requests to get a 10% discount. Only affects AIhubmix.';

  @override
  String get providerDetailPageClaudePromptCachingTitle =>
      'Claude Prompt Caching';

  @override
  String get providerDetailPageClaudePromptCachingHelp =>
      'Adds cache_control to Claude requests through Anthropic or OpenRouter.';

  @override
  String get providerDetailPageClaudePromptCachingTtlTitle => 'Cache TTL';

  @override
  String get providerDetailPageClaudePromptCachingTtlHelp =>
      '5 minutes is the default. 1 hour costs more to write but can reduce rebuilds in long conversations.';

  @override
  String get providerDetailPageClaudePromptCachingTtl5m => '5 min';

  @override
  String get providerDetailPageClaudePromptCachingTtl1h => '1 hour';

  @override
  String get providerDetailPageBalanceTitle => 'Account Balance';

  @override
  String get providerDetailPageBalanceInfo => 'Get account balance';

  @override
  String get providerDetailPageBalanceApiPathLabel => 'Balance API Path';

  @override
  String get providerDetailPageBalanceResultPathLabel => 'Result JSON Path';

  @override
  String get providerDetailPageBalanceQueryButton => 'Check Balance';

  @override
  String get providerDetailPageBalanceQuerying => 'Checking...';

  @override
  String get providerDetailPageBalanceResetDefaultsButton => 'Reset';

  @override
  String get providerDetailPageBalanceResetDefaultsTooltip =>
      'Reset balance settings';

  @override
  String providerDetailPageBalanceResult(String value) {
    return 'Balance: $value';
  }

  @override
  String providerDetailPageBalanceError(String message) {
    return 'Balance query failed: $message';
  }

  @override
  String get providerDetailPageVertexAiTitle => 'Vertex AI';

  @override
  String get providerDetailPageLocationLabel => 'Location';

  @override
  String get providerDetailPageProjectIdLabel => 'Project ID';

  @override
  String get providerDetailPageServiceAccountJsonLabel =>
      'Service Account JSON (paste or import)';

  @override
  String get providerDetailPageImportJsonButton => 'Import JSON';

  @override
  String get providerDetailPageImportJsonReadFailedMessage =>
      'Failed to read file';

  @override
  String get providerDetailPageTestButton => 'Test';

  @override
  String get providerDetailPageSaveButton => 'Save';

  @override
  String get providerDetailPageProviderRemovedMessage => 'Provider removed';

  @override
  String get providerDetailPageNoModelsTitle => 'No Models';

  @override
  String get providerDetailPageNoModelsSubtitle =>
      'Tap the buttons below to add models';

  @override
  String get providerDetailPageDeleteModelButton => 'Delete';

  @override
  String get providerDetailPageConfirmDeleteTitle => 'Confirm Delete';

  @override
  String get providerDetailPageConfirmDeleteContent =>
      'This can be undone via Undo. Delete?';

  @override
  String get providerDetailPageModelDeletedSnackbar => 'Model deleted';

  @override
  String get providerDetailPageUndoButton => 'Undo';

  @override
  String get providerDetailPageAddNewModelButton => 'Add Model';

  @override
  String get providerDetailPageFetchModelsButton => 'Fetch';

  @override
  String get providerDetailPageEnableProxyTitle => 'Enable Proxy';

  @override
  String get providerDetailPageHostLabel => 'Host';

  @override
  String get providerDetailPagePortLabel => 'Port';

  @override
  String get providerDetailPageUsernameOptionalLabel => 'Username (optional)';

  @override
  String get providerDetailPagePasswordOptionalLabel => 'Password (optional)';

  @override
  String get providerDetailPageSavedSnackbar => 'Saved';

  @override
  String get providerDetailPageEmbeddingsGroupTitle => 'Embeddings';

  @override
  String get providerDetailPageOtherModelsGroupTitle => 'Other';

  @override
  String get providerDetailPageRemoveGroupTooltip => 'Remove group';

  @override
  String get providerDetailPageAddGroupTooltip => 'Add group';

  @override
  String get providerDetailPageFilterHint => 'Type model name to filter';

  @override
  String get providerDetailPageDeleteText => 'Delete';

  @override
  String get providerDetailPageEditTooltip => 'Edit';

  @override
  String get providerDetailPageTestConnectionTitle => 'Test Connection';

  @override
  String get providerDetailPageSelectModelButton => 'Select Model';

  @override
  String get providerDetailPageChangeButton => 'Change';

  @override
  String get providerDetailPageUseStreamingLabel => 'Use Streaming';

  @override
  String get providerDetailPageTestingMessage => 'Testing…';

  @override
  String get providerDetailPageTestSuccessMessage => 'Success';

  @override
  String get providersPageTitle => 'Providers';

  @override
  String get providersPageImportTooltip => 'Import';

  @override
  String get providersPageAddTooltip => 'Add';

  @override
  String get providersPageSearchHint => 'Search providers or groups';

  @override
  String get providersPageProviderAddedSnackbar => 'Provider added';

  @override
  String get providerGroupsGroupLabel => 'Group';

  @override
  String get providerGroupsOther => 'Other';

  @override
  String get providerGroupsOtherUngroupedOption => 'Other (Ungrouped)';

  @override
  String get providerGroupsPickerTitle => 'Select group';

  @override
  String get providerGroupsManageTitle => 'Manage groups';

  @override
  String get providerGroupsManageAction => 'Manage groups';

  @override
  String get providerGroupsCreateNewGroupAction => 'New group…';

  @override
  String get providerGroupsCreateDialogTitle => 'New group';

  @override
  String get providerGroupsNameHint => 'Group name';

  @override
  String get providerGroupsCreateDialogCancel => 'Cancel';

  @override
  String get providerGroupsCreateDialogOk => 'Create';

  @override
  String get providerGroupsCreateFailedToast => 'Failed to create group';

  @override
  String get providerGroupsDeleteConfirmTitle => 'Delete group?';

  @override
  String get providerGroupsDeleteConfirmContent =>
      'Providers in this group will be moved to “Other”.';

  @override
  String get providerGroupsDeleteConfirmCancel => 'Cancel';

  @override
  String get providerGroupsDeleteConfirmOk => 'Delete';

  @override
  String get providerGroupsDeletedToast => 'Group deleted';

  @override
  String get providerGroupsEmptyState => 'No groups yet.';

  @override
  String get providerGroupsExpandToMoveToast =>
      'Please expand the group first.';

  @override
  String get providersPageSiliconFlowName => 'SiliconFlow';

  @override
  String get providersPageAliyunName => 'Aliyun';

  @override
  String get providersPageZhipuName => 'Zhipu AI';

  @override
  String get providersPageByteDanceName => 'ByteDance';

  @override
  String get providersPageEnabledStatus => 'ON';

  @override
  String get providersPageDisabledStatus => 'OFF';

  @override
  String get providersPageModelsCountSuffix => ' models';

  @override
  String get providersPageModelsCountSingleSuffix => ' models';

  @override
  String get addProviderSheetTitle => 'Add Provider';

  @override
  String get addProviderSheetEnabledLabel => 'Enabled';

  @override
  String get addProviderSheetNameLabel => 'Name';

  @override
  String get addProviderSheetApiPathLabel => 'API Path';

  @override
  String get addProviderSheetVertexAiLocationLabel => 'Location';

  @override
  String get addProviderSheetVertexAiProjectIdLabel => 'Project ID';

  @override
  String get addProviderSheetVertexAiServiceAccountJsonLabel =>
      'Service Account JSON (paste or import)';

  @override
  String get addProviderSheetImportJsonButton => 'Import JSON';

  @override
  String get addProviderSheetCancelButton => 'Cancel';

  @override
  String get addProviderSheetAddButton => 'Add';

  @override
  String get importProviderSheetTitle => 'Import Provider';

  @override
  String get importProviderSheetScanQrTooltip => 'Scan QR';

  @override
  String get importProviderSheetFromGalleryTooltip => 'From Gallery';

  @override
  String importProviderSheetImportSuccessMessage(int count) {
    return 'Imported $count provider(s)';
  }

  @override
  String importProviderSheetImportFailedMessage(String error) {
    return 'Import failed: $error';
  }

  @override
  String get importProviderSheetDescription =>
      'Paste share strings (multi-line supported) or ChatBox JSON';

  @override
  String get importProviderSheetInputHint => 'ai-provider:v1:... or JSON';

  @override
  String get importProviderSheetCancelButton => 'Cancel';

  @override
  String get importProviderSheetImportButton => 'Import';

  @override
  String get shareProviderSheetTitle => 'Share Provider';

  @override
  String get shareProviderSheetDescription => 'Copy or share via QR code.';

  @override
  String get shareProviderSheetCopiedMessage => 'Copied';

  @override
  String get shareProviderSheetCopyButton => 'Copy';

  @override
  String get shareProviderSheetShareButton => 'Share';

  @override
  String get desktopProviderContextMenuShare => 'Share';

  @override
  String get desktopProviderShareCopyText => 'Copy code';

  @override
  String get desktopProviderShareCopyQr => 'Copy QR';

  @override
  String get providerDetailPageApiBaseUrlLabel => 'API Base URL';

  @override
  String get providerDetailPageModelsTitle => 'Models';

  @override
  String get providerModelsGetButton => 'Get';

  @override
  String get providerDetailPageCapsVision => 'Vision';

  @override
  String get providerDetailPageCapsImage => 'Image';

  @override
  String get providerDetailPageCapsTool => 'Tool';

  @override
  String get providerDetailPageCapsReasoning => 'Reasoning';

  @override
  String get qrScanPageTitle => 'Scan QR';

  @override
  String get qrScanPageInstruction => 'Align the QR code within the frame';

  @override
  String get searchServicesPageBackTooltip => 'Back';

  @override
  String get searchServicesPageTitle => 'Search Services';

  @override
  String get searchServicesPageDone => 'Done';

  @override
  String get searchServicesPageEdit => 'Edit';

  @override
  String get searchServicesPageAddProvider => 'Add Provider';

  @override
  String get searchServicesPageSearchProviders => 'Search Providers';

  @override
  String get searchServicesPageGeneralOptions => 'General Options';

  @override
  String get searchServicesPageAutoTestTitle =>
      'Auto-test connections on launch';

  @override
  String get searchServicesPageMaxResults => 'Max Results';

  @override
  String get searchServicesPageTimeoutSeconds => 'Timeout (seconds)';

  @override
  String get searchServicesPageAtLeastOneServiceRequired =>
      'At least one search service is required';

  @override
  String get searchServicesPageTestingStatus => 'Testing…';

  @override
  String get searchServicesPageConnectedStatus => 'Connected';

  @override
  String get searchServicesPageFailedStatus => 'Failed';

  @override
  String get searchServicesPageNotTestedStatus => 'Not tested';

  @override
  String get searchServicesPageEditServiceTooltip => 'Edit Service';

  @override
  String get searchServicesPageTestConnectionTooltip => 'Test Connection';

  @override
  String get searchServicesPageDeleteServiceTooltip => 'Delete Service';

  @override
  String get searchServicesPageConfiguredStatus => 'Configured';

  @override
  String get miniMapTitle => 'Minimap';

  @override
  String get miniMapTooltip => 'Minimap';

  @override
  String get miniMapScrollToBottomTooltip => 'Scroll to bottom';

  @override
  String miniMapSearchMatchCount(int count) {
    return '$count';
  }

  @override
  String get miniMapSearchNoResults => 'No matching messages';

  @override
  String get searchServicesPageApiKeyRequiredStatus => 'API Key Required';

  @override
  String get searchServicesPageUrlRequiredStatus => 'URL Required';

  @override
  String get searchServicesAddDialogTitle => 'Add Search Service';

  @override
  String get searchServicesAddDialogServiceType => 'Service Type';

  @override
  String get searchServicesAddDialogBingLocal => 'Local';

  @override
  String get searchServicesAddDialogCancel => 'Cancel';

  @override
  String get searchServicesAddDialogAdd => 'Add';

  @override
  String get searchServicesAddDialogApiKeyRequired => 'API Key is required';

  @override
  String get searchServicesFieldCustomUrlOptional => 'Custom URL (optional)';

  @override
  String get searchServicesDialogApiKey => 'API Key';

  @override
  String get searchServicesDialogModel => 'Model';

  @override
  String get searchServicesDialogSystemPrompt => 'System Prompt';

  @override
  String get searchServicesAddDialogInstanceUrl => 'Instance URL';

  @override
  String get searchServicesAddDialogUrlRequired => 'URL is required';

  @override
  String get searchServicesAddDialogEnginesOptional => 'Engines (optional)';

  @override
  String get searchServicesAddDialogLanguageOptional => 'Language (optional)';

  @override
  String get searchServicesAddDialogUsernameOptional => 'Username (optional)';

  @override
  String get searchServicesAddDialogPasswordOptional => 'Password (optional)';

  @override
  String get searchServicesAddDialogRegionOptional =>
      'Region (optional, default: us-en)';

  @override
  String get searchServicesEditDialogEdit => 'Edit';

  @override
  String get searchServicesEditDialogCancel => 'Cancel';

  @override
  String get searchServicesEditDialogSave => 'Save';

  @override
  String get searchServicesEditDialogBingLocalNoConfig =>
      'No configuration required for Bing Local search.';

  @override
  String get searchServicesEditDialogApiKeyRequired => 'API Key is required';

  @override
  String get searchServicesEditDialogInstanceUrl => 'Instance URL';

  @override
  String get searchServicesEditDialogUrlRequired => 'URL is required';

  @override
  String get searchServicesEditDialogEnginesOptional => 'Engines (optional)';

  @override
  String get searchServicesEditDialogLanguageOptional => 'Language (optional)';

  @override
  String get searchServicesEditDialogUsernameOptional => 'Username (optional)';

  @override
  String get searchServicesEditDialogPasswordOptional => 'Password (optional)';

  @override
  String get searchServicesEditDialogRegionOptional =>
      'Region (optional, default: us-en)';

  @override
  String get searchServiceEditorProviderTypeTitle => 'Search provider';

  @override
  String get searchServiceEditorConfigurationTitle => 'Configuration';

  @override
  String get searchServiceEditorNoConfiguration =>
      'This provider does not require additional configuration.';

  @override
  String get searchServiceEditorMultiKeyTitle => 'Multi-key rotation';

  @override
  String get searchServiceEditorMultiKeyNone => 'Not configured';

  @override
  String get searchApiKeysPageDescription =>
      'Keys rotate in the order listed; the first is the primary key. Usage is not queried to avoid provider rate limiting.';

  @override
  String get searchApiKeysPagePrimaryBadge => 'Primary';

  @override
  String get searchApiKeysPageBatchHint =>
      'Paste one or more keys — one per line or comma-separated';

  @override
  String searchApiKeysPageBatchResult(String added, String skipped) {
    return 'Added $added, skipped $skipped duplicate(s)';
  }

  @override
  String get searchApiKeysPageAdd => 'Add';

  @override
  String get searchApiKeysPageEmpty => 'No keys configured yet.';

  @override
  String searchServiceEditorMultiKeyCount(String count) {
    return '$count keys';
  }

  @override
  String get searchServiceEditorUsageTitle => 'Account usage';

  @override
  String get searchServiceEditorUsageNotQueried =>
      'Usage has not been queried yet.';

  @override
  String get searchServiceEditorUsageQuery => 'Check usage';

  @override
  String get searchServiceEditorUsageQuerying => 'Checking…';

  @override
  String searchServiceEditorUsageRemaining(String remaining) {
    return '$remaining credits remaining';
  }

  @override
  String searchServiceEditorUsageBalance(String balance) {
    return 'Balance: $balance';
  }

  @override
  String searchServiceEditorUsageUsed(String used, String limit) {
    return '$used of $limit credits used';
  }

  @override
  String searchServiceEditorUsageFailed(String message) {
    return 'Could not query usage: $message';
  }

  @override
  String get searchServiceEditorTestTitle => 'Test search';

  @override
  String get searchServiceEditorTestQueryHint => 'Enter a query';

  @override
  String get searchServiceEditorTestRun => 'Run test search';

  @override
  String get searchServiceEditorTestRunning => 'Searching…';

  @override
  String get searchServiceEditorTestNoResults =>
      'The provider returned no results.';

  @override
  String searchServiceEditorTestFailed(String message) {
    return 'Search failed: $message';
  }

  @override
  String get searchServiceEditorResultOpenTooltip => 'Open result';

  @override
  String get searchServiceEditorDeleteTooltip => 'Delete search service';

  @override
  String get searchServiceEditorDeleteTitle => 'Delete search service?';

  @override
  String searchServiceEditorDeleteMessage(String provider) {
    return 'Delete $provider? This cannot be undone.';
  }

  @override
  String get searchServiceEditorDeleteConfirm => 'Delete';

  @override
  String get searchServiceEditorDiscardTitle => 'Discard changes?';

  @override
  String get searchServiceEditorDiscardMessage =>
      'Your unsaved search service settings will be lost.';

  @override
  String get searchServiceEditorKeepEditing => 'Keep editing';

  @override
  String get searchServiceEditorDiscard => 'Discard';

  @override
  String get searchSettingsSheetTitle => 'Search Settings';

  @override
  String get searchSettingsSheetBuiltinSearchTitle => 'Built-in Search';

  @override
  String get searchSettingsSheetBuiltinSearchDescription =>
      'Enable model\'s built-in search';

  @override
  String get searchSettingsSheetClaudeDynamicSearchTitle => 'Dynamic filtering';

  @override
  String get searchSettingsSheetClaudeDynamicSearchDescription =>
      'Filter results to save tokens';

  @override
  String get searchSettingsSheetWebSearchTitle => 'Web Search';

  @override
  String get searchSettingsSheetWebSearchDescription =>
      'Enable web search in chat';

  @override
  String get searchSettingsSheetOpenSearchServicesTooltip =>
      'Open search services';

  @override
  String get searchSettingsSheetNoServicesMessage =>
      'No services. Add from Search Services.';

  @override
  String get aboutPageEasterEggMessage =>
      'Thanks for exploring! \n (No egg yet)';

  @override
  String get aboutPageEasterEggButton => 'Nice!';

  @override
  String get aboutPageKelivoSearchUnlocked =>
      'An unnamed door opened a crack. You might find it in Settings.';

  @override
  String get aboutPageKelivoSearchAlreadyUnlocked =>
      'You\'ve already been through this door.';

  @override
  String get aboutPageAppName => 'Kelivo';

  @override
  String get aboutPageAppDescription => 'Open-source AI Assistant';

  @override
  String get aboutPageNoQQGroup => 'No QQ group yet';

  @override
  String get aboutPageVersion => 'Version';

  @override
  String aboutPageVersionDetail(String version, String buildNumber) {
    return '$version / $buildNumber';
  }

  @override
  String get aboutPageSystem => 'System';

  @override
  String get aboutPageLoadingPlaceholder => '...';

  @override
  String get aboutPageUnknownPlaceholder => '-';

  @override
  String get aboutPagePlatformMacos => 'macOS';

  @override
  String get aboutPagePlatformWindows => 'Windows';

  @override
  String get aboutPagePlatformLinux => 'Linux';

  @override
  String get aboutPagePlatformAndroid => 'Android';

  @override
  String get aboutPagePlatformIos => 'iOS';

  @override
  String aboutPagePlatformOther(String os) {
    return 'Other ($os)';
  }

  @override
  String get aboutPageWebsite => 'Website';

  @override
  String get aboutPageGithub => 'GitHub';

  @override
  String get aboutPageLicense => 'License';

  @override
  String get aboutPageJoinQQGroup => 'Join our QQ Group';

  @override
  String get aboutPageQQGroupOne => 'Kelivo Group 1';

  @override
  String get aboutPageQQGroupTwo => 'Kelivo Group 2';

  @override
  String get aboutPageQQGroupThree => 'Kelivo Group 3';

  @override
  String get aboutPageJoinDiscord => 'Join us on Discord';

  @override
  String get displaySettingsPageShowUserAvatarTitle => 'Show User Avatar';

  @override
  String get displaySettingsPageShowUserAvatarSubtitle =>
      'Display user avatar in chat messages';

  @override
  String get displaySettingsPageShowUserNameTimestampTitle =>
      'Show User Name & Timestamp';

  @override
  String get displaySettingsPageShowUserNameTimestampSubtitle =>
      'Show user name and the timestamp below it in chat messages';

  @override
  String get displaySettingsPageShowUserNameTitle => 'Show User Name';

  @override
  String get displaySettingsPageShowUserTimestampTitle => 'Show User Timestamp';

  @override
  String get displaySettingsPageShowUserMessageActionsTitle =>
      'Show User Message Actions';

  @override
  String get displaySettingsPageShowUserMessageActionsSubtitle =>
      'Display copy, resend, and more buttons below your messages';

  @override
  String get displaySettingsPageShowModelNameTimestampTitle =>
      'Show Model Name & Timestamp';

  @override
  String get displaySettingsPageShowModelNameTimestampSubtitle =>
      'Show model name and the timestamp below it in chat messages';

  @override
  String get displaySettingsPageShowModelNameTitle => 'Show Model Name';

  @override
  String get displaySettingsPageShowModelTimestampTitle =>
      'Show Model Timestamp';

  @override
  String get displaySettingsPageShowProviderInChatMessageTitle =>
      'Show Provider After Model Name';

  @override
  String get displaySettingsPageShowProviderInChatMessageSubtitle =>
      'Display provider name after the model ID in chat messages (e.g. model | provider)';

  @override
  String get displaySettingsPageChatModelIconTitle => 'Chat Model Icon';

  @override
  String get displaySettingsPageChatModelIconSubtitle =>
      'Show model icon in chat messages';

  @override
  String get displaySettingsPageShowTokenStatsTitle =>
      'Show Token & Context Stats';

  @override
  String get displaySettingsPageShowTokenStatsSubtitle =>
      'Show token usage and message count';

  @override
  String get displaySettingsPageShowThinkingCardsTitle => 'Show Thinking Cards';

  @override
  String get displaySettingsPageShowThinkingCardsSubtitle =>
      'When off, thinking-process cards are hidden in chat.';

  @override
  String get displaySettingsPageShowToolCardsTitle => 'Show Tool Cards';

  @override
  String get displaySettingsPageShowToolCardsSubtitle =>
      'When off, tool-use cards are hidden in chat.';

  @override
  String get displaySettingsPageAutoCollapseThinkingTitle =>
      'Auto-collapse Thinking';

  @override
  String get displaySettingsPageAutoCollapseThinkingSubtitle =>
      'Collapse reasoning after finish';

  @override
  String get displaySettingsPageCollapseThinkingStepsTitle =>
      'Collapse Thinking Steps';

  @override
  String get displaySettingsPageCollapseThinkingStepsSubtitle =>
      'Show only the latest steps until expanded';

  @override
  String get displaySettingsPageShowToolResultSummaryTitle =>
      'Show Tool Result Summary';

  @override
  String get displaySettingsPageInsertSuggestionOnlyTitle =>
      'Insert suggestions without sending';

  @override
  String get displaySettingsPageShowToolResultSummarySubtitle =>
      'Display the summary text below tool steps';

  @override
  String get displaySettingsPageHideToolResultImagesTitle =>
      'Hide images in tool results';

  @override
  String get displaySettingsPageRegenerateDeleteTrailingMessagesTitle =>
      'Delete messages below when regenerating';

  @override
  String get displaySettingsPageShowRegenerateConfirmDialogTitle =>
      'Confirm before regenerating';

  @override
  String get displaySettingsPageForkKeepMessageVersionsTitle =>
      'Keep Message Versions When Forking';

  @override
  String get displaySettingsPageEditAssistantKeepThinkingToolCardsTitle =>
      'Keep thinking and tool cards when editing assistant';

  @override
  String get displaySettingsPageEditAssistantKeepThinkingToolCardsSubtitle =>
      'When off, the edited version keeps only the assistant text. Switching back still shows previous thinking and tool cards.';

  @override
  String chainOfThoughtExpandSteps(Object count) {
    return 'Show $count more steps';
  }

  @override
  String get chainOfThoughtCollapse => 'Collapse';

  @override
  String get displaySettingsPageShowChatListDateTitle => 'Show Chat List Dates';

  @override
  String get displaySettingsPageShowChatListDateSubtitle =>
      'Display date group labels in the conversation list';

  @override
  String get displaySettingsPageEnableImageCropperTitle =>
      'Enable Image Cropping';

  @override
  String get displaySettingsPageEnableImageCropperSubtitle =>
      'Crop images after selecting from gallery or camera';

  @override
  String get displaySettingsPageKeepSidebarOpenOnAssistantTapTitle =>
      'Keep sidebar open when selecting assistant';

  @override
  String get displaySettingsPageKeepSidebarOpenOnTopicTapTitle =>
      'Keep sidebar open when selecting topic';

  @override
  String get displaySettingsPageKeepAssistantListExpandedOnSidebarCloseTitle =>
      'Don\'t collapse assistant list when closing sidebar';

  @override
  String get displaySettingsPageShowUpdatesTitle => 'Show Updates';

  @override
  String get displaySettingsPageShowUpdatesSubtitle =>
      'Show app update notifications';

  @override
  String get displaySettingsPageKeepScreenOnDuringGenerationTitle =>
      'Keep Screen On While Generating';

  @override
  String get displaySettingsPageKeepScreenOnDuringGenerationSubtitle =>
      'Prevents the lock screen from interrupting generation. Increases battery use.';

  @override
  String get displaySettingsPageMessageNavButtonsTitle =>
      'Message Navigation Buttons';

  @override
  String get displaySettingsPageMessageNavButtonsSubtitle =>
      'Choose when quick jump buttons appear';

  @override
  String get displaySettingsPageMessageNavButtonsModeAlways => 'Always show';

  @override
  String get displaySettingsPageMessageNavButtonsModeScroll =>
      'Show while scrolling';

  @override
  String get displaySettingsPageMessageNavButtonsModeHover =>
      'Show on mouse hover';

  @override
  String get displaySettingsPageMessageNavButtonsModeScrollAndHover =>
      'Show while scrolling or hovering';

  @override
  String get displaySettingsPageMessageNavButtonsModeNever => 'Never show';

  @override
  String get displaySettingsPageUseNewAssistantAvatarUxTitle =>
      'Show assistant avatar in chat title bar';

  @override
  String get displaySettingsPageHapticsOnSidebarTitle => 'Haptics on Sidebar';

  @override
  String get displaySettingsPageHapticsOnSidebarSubtitle =>
      'Enable haptic feedback when opening/closing sidebar';

  @override
  String get displaySettingsPageHapticsGlobalTitle => 'Global Haptics';

  @override
  String get displaySettingsPageHapticsIosSwitchTitle => 'Haptics on Switch';

  @override
  String get displaySettingsPageHapticsOnListItemTapTitle =>
      'Haptics on List Items';

  @override
  String get displaySettingsPageHapticsOnCardTapTitle => 'Haptics on Cards';

  @override
  String get displaySettingsPageHapticsOnGenerateTitle => 'Haptics on Generate';

  @override
  String get displaySettingsPageHapticsOnGenerateSubtitle =>
      'Enable haptic feedback during generation';

  @override
  String get displaySettingsPageNewChatAfterDeleteTitle =>
      'New chat after deleting topic';

  @override
  String get displaySettingsPageNewChatOnAssistantSwitchTitle =>
      'New chat when switching assistants';

  @override
  String get displaySettingsPageNewChatOnLaunchTitle => 'New Chat on Launch';

  @override
  String get displaySettingsPageEnterToSendTitle => 'Enter Key to Send';

  @override
  String get displaySettingsPageLongPasteAsFileTitle =>
      'Paste long text as file';

  @override
  String get displaySettingsPageLongPasteAsFileThresholdTitle =>
      'Conversion threshold';

  @override
  String get displaySettingsPageLongPasteAsFileThresholdUnit => 'characters';

  @override
  String get displaySettingsPageSendShortcutTitle => 'Send Shortcut';

  @override
  String get displaySettingsPageSendShortcutEnter => 'Enter';

  @override
  String get displaySettingsPageSendShortcutCtrlEnter => 'Ctrl/Cmd + Enter';

  @override
  String get displaySettingsPageAutoSwitchTopicsTitle =>
      'Auto switch to Topics';

  @override
  String get desktopDisplaySettingsTopicPositionTitle => 'Topic position';

  @override
  String get desktopDisplaySettingsTopicPositionLeft => 'Left';

  @override
  String get desktopDisplaySettingsTopicPositionRight => 'Right';

  @override
  String get displaySettingsPageNewChatOnLaunchSubtitle =>
      'Automatically create a new chat on launch';

  @override
  String get displaySettingsPageChatFontSizeTitle => 'Chat Font Size';

  @override
  String get displaySettingsPageAutoScrollEnableTitle =>
      'Auto-scroll to bottom';

  @override
  String get displaySettingsPageAutoScrollIdleTitle => 'Auto-Scroll Back Delay';

  @override
  String get displaySettingsPageAutoScrollIdleSubtitle =>
      'Wait time after user scroll before jumping to bottom';

  @override
  String get displaySettingsPageAutoScrollDisabledLabel => 'Off';

  @override
  String get displaySettingsPageChatFontSampleText =>
      'This is a sample chat text';

  @override
  String get displaySettingsPageChatBackgroundMaskTitle =>
      'Chat Background Overlay Opacity';

  @override
  String get displaySettingsPageChatInputBackgroundOpacityTitle =>
      'Input Box Background Opacity';

  @override
  String get displaySettingsPageThemeSettingsTitle => 'Theme Settings';

  @override
  String get displaySettingsPageThemeColorTitle => 'Theme Color';

  @override
  String get desktopSettingsFontsTitle => 'Fonts';

  @override
  String get displaySettingsPageTrayTitle => 'System Tray';

  @override
  String get displaySettingsPageTrayShowTrayTitle => 'Show tray icon';

  @override
  String get displaySettingsPageTrayMinimizeOnCloseTitle =>
      'Minimize to tray on close';

  @override
  String get desktopFontAppLabel => 'App Font';

  @override
  String get desktopFontCodeLabel => 'Code Font';

  @override
  String get desktopFontFamilySystemDefault => 'System Default';

  @override
  String get desktopFontFamilyMonospaceDefault => 'Monospace';

  @override
  String get desktopFontFilterHint => 'Filter fonts...';

  @override
  String get displaySettingsPageAppFontTitle => 'App Font';

  @override
  String get displaySettingsPageCodeFontTitle => 'Code Font';

  @override
  String get fontPickerChooseLocalFile => 'Choose Local File';

  @override
  String get desktopFontLoading => 'Loading fonts…';

  @override
  String get displaySettingsPageFontLocalFileLabel => 'Local file';

  @override
  String get displaySettingsPageFontResetLabel => 'Reset font settings';

  @override
  String get displaySettingsPageOtherSettingsTitle => 'Other Settings';

  @override
  String get themeSettingsPageDynamicColorSection => 'Dynamic Color';

  @override
  String get themeSettingsPageUseDynamicColorTitle => 'System Dynamic Colors';

  @override
  String get themeSettingsPageUseDynamicColorSubtitle =>
      'Match system palette (Android 12+)';

  @override
  String get themeSettingsPageUsePureBackgroundTitle => 'Pure Background';

  @override
  String get themeSettingsPageUsePureBackgroundSubtitle =>
      'Bubbles and accents follow theme.';

  @override
  String get themeAdvancedSettingsPageTitle => 'Theme Advanced';

  @override
  String get themeAdvancedSettingsPageUseLayeredSurfacesTitle =>
      'Layered surfaces (experimental)';

  @override
  String get themeAdvancedSettingsPageUseLayeredSurfacesSubtitle =>
      'Darker page, brighter cards; both keep theme hue. Turn off to restore the previous look.';

  @override
  String get themeAdvancedSettingsPageUseLayeredSheetTilesTitle =>
      'Layered sheet tiles';

  @override
  String get themeAdvancedSettingsPageUseLayeredSheetTilesSubtitle =>
      'By default, tiles match the sheet background.';

  @override
  String get themeSettingsPageColorPalettesSection => 'Color Palettes';

  @override
  String get themeSettingsPageCustomPaletteName => 'Custom';

  @override
  String get themeSettingsPageCustomColorReset => 'Reset';

  @override
  String get themeSettingsPageCustomThemesSection => 'Custom Themes';

  @override
  String get customThemeNewTheme => 'New Theme';

  @override
  String get customThemeEditTheme => 'Edit Theme';

  @override
  String get customThemeImportTheme => 'Import Theme';

  @override
  String get customThemeNameLabel => 'Theme name';

  @override
  String get customThemePrimaryColor => 'Primary';

  @override
  String get customThemeSecondaryColor => 'Secondary';

  @override
  String get customThemeTertiaryColor => 'Tertiary';

  @override
  String get customThemeColorAuto => 'Auto';

  @override
  String get customThemeSave => 'Save';

  @override
  String get customThemeCancel => 'Cancel';

  @override
  String get customThemeDelete => 'Delete';

  @override
  String get customThemeDeleteConfirm => 'Delete this theme?';

  @override
  String get customThemeCopied => 'Theme JSON copied to clipboard';

  @override
  String get customThemeCopyAction => 'Copy';

  @override
  String get customThemeImportHint => 'Paste the theme JSON here';

  @override
  String get customThemeImportInvalid => 'Invalid theme JSON';

  @override
  String get customThemeHexLabel => 'Hex';

  @override
  String get ttsServicesPageBackButton => 'Back';

  @override
  String get ttsServicesPageTitle => 'Voice Services';

  @override
  String get ttsServicesSectionTitle => 'Text-to-Speech';

  @override
  String get ttsServicesPageSettingsTooltip => 'TTS settings';

  @override
  String get ttsServicesPageAddTooltip => 'Add';

  @override
  String get asrServicesSectionTitle => 'Speech Recognition';

  @override
  String get asrServicesSectionDescription =>
      'Turn speech into text with an on-device, system, or cloud service.';

  @override
  String get asrServicesAddTooltip => 'Add speech recognition service';

  @override
  String get asrServicesEmptyTitle => 'No speech recognition service';

  @override
  String get asrServicesEmptySubtitle =>
      'Add one to show the microphone in the chat input.';

  @override
  String get asrServicesOnDeviceGroup => 'On-device';

  @override
  String get asrServicesCloudGroup => 'Cloud';

  @override
  String get asrServicesSystemTitle => 'System';

  @override
  String get asrServicesSystemSubtitle =>
      'Uses the device\'s built-in recognizer';

  @override
  String get asrServicesLocalTitle => 'Offline Model';

  @override
  String get asrServicesLocalSubtitle =>
      'Runs offline on this device after download';

  @override
  String get asrServicesOpenAiTitle => 'OpenAI Realtime';

  @override
  String get asrServicesOpenAiSubtitle => 'Low-latency streaming transcription';

  @override
  String get asrServicesDashScopeTitle => 'DashScope';

  @override
  String get asrServicesDashScopeSubtitle => 'Qwen real-time transcription';

  @override
  String get asrServicesVolcengineTitle => 'Volcengine';

  @override
  String get asrServicesVolcengineSubtitle => 'Doubao streaming transcription';

  @override
  String get asrServicesMimoTitle => 'MiMo';

  @override
  String get asrServicesMimoSubtitle => 'Segmented cloud transcription';

  @override
  String get asrServicesStepTitle => 'Step';

  @override
  String get asrServicesStepSubtitle => 'Step Audio segmented transcription';

  @override
  String get asrServicesAddTitle => 'Add Speech Recognition';

  @override
  String get asrServicesEditTitle => 'Edit Speech Recognition';

  @override
  String get asrServicesSelectedLabel => 'Selected';

  @override
  String get asrServicesUnavailableLabel => 'Unavailable';

  @override
  String get asrServicesEditAction => 'Edit';

  @override
  String get asrServicesDeleteAction => 'Delete';

  @override
  String get asrServicesCancelAction => 'Cancel';

  @override
  String get asrServicesAddAction => 'Add';

  @override
  String get asrServicesSaveAction => 'Save';

  @override
  String get asrServicesNameLabel => 'Name';

  @override
  String get asrServicesApiKeyLabel => 'API Key';

  @override
  String get asrServicesEndpointLabel => 'Endpoint';

  @override
  String get asrServicesModelLabel => 'Model';

  @override
  String get asrServicesResourceIdLabel => 'Resource ID';

  @override
  String get asrServicesLanguageLabel => 'Language';

  @override
  String get asrServicesAutomaticLabel => 'Automatic';

  @override
  String get asrServicesApiKeyRequired =>
      'Enter an API key to use this service.';

  @override
  String get asrServicesChooseModelTitle => 'Model';

  @override
  String get asrServicesModelDownloadAction => 'Download';

  @override
  String get asrServicesModelUseAction => 'Use model';

  @override
  String get asrServicesModelDeleteAction => 'Remove download';

  @override
  String get asrServicesModelDownloadedLabel => 'Downloaded';

  @override
  String get asrServicesModelDownloadingLabel => 'Downloading…';

  @override
  String get asrServicesModelNotDownloadedLabel => 'Not downloaded';

  @override
  String asrServicesDownloadFailed(String error) {
    return 'Model download failed: $error';
  }

  @override
  String get asrServicesSystemChecking => 'Checking…';

  @override
  String get asrServicesSystemAvailable => 'Available';

  @override
  String get asrServicesSystemCheckFailed =>
      'System speech recognition is unavailable on this device.';

  @override
  String get asrServicesMicrophonePermissionDenied =>
      'Microphone permission was not granted.';

  @override
  String get asrServicesNoSpeechDetected => 'No speech was detected.';

  @override
  String asrServicesRecognitionFailed(String error) {
    return 'Speech recognition failed: $error';
  }

  @override
  String get ttsServicesPageAddNotImplemented =>
      'Add TTS service not implemented';

  @override
  String get ttsServicesPageSystemTtsTitle => 'System TTS';

  @override
  String get ttsServicesPageSystemTtsAvailableSubtitle =>
      'Use system built-in TTS';

  @override
  String ttsServicesPageSystemTtsUnavailableSubtitle(String error) {
    return 'Unavailable: $error';
  }

  @override
  String get ttsServicesPageSystemTtsUnavailableNotInitialized =>
      'not initialized';

  @override
  String get ttsServicesPageTestSpeechText => 'Hello, this is a test speech.';

  @override
  String get ttsServicesPageConfigureTooltip => 'Configure';

  @override
  String get ttsServicesPageTestVoiceTooltip => 'Test voice';

  @override
  String get ttsServicesPageStopTooltip => 'Stop';

  @override
  String get ttsServicesPageDeleteTooltip => 'Delete';

  @override
  String get ttsServicesPageSystemTtsSettingsTitle => 'System TTS Settings';

  @override
  String get ttsServicesPageEngineLabel => 'Engine';

  @override
  String get ttsServicesPageAutoLabel => 'Auto';

  @override
  String get ttsServicesPageLanguageLabel => 'Language';

  @override
  String get ttsServicesPageSpeechRateLabel => 'Speech rate';

  @override
  String get ttsServicesPagePitchLabel => 'Pitch';

  @override
  String get ttsServicesPageSettingsSavedMessage => 'Settings saved.';

  @override
  String get ttsServicesPageDoneButton => 'Done';

  @override
  String get ttsServicesPageNetworkSectionTitle => 'Network TTS';

  @override
  String get ttsServicesPageNoNetworkServices => 'No TTS services.';

  @override
  String get ttsServicesDialogAddTitle => 'Add TTS Service';

  @override
  String get ttsServicesDialogEditTitle => 'Edit TTS Service';

  @override
  String get ttsServicesDialogProviderType => 'Provider';

  @override
  String get ttsServicesDialogCancelButton => 'Cancel';

  @override
  String get ttsServicesDialogAddButton => 'Add';

  @override
  String get ttsServicesDialogSaveButton => 'Save';

  @override
  String get ttsServicesFieldNameLabel => 'Name';

  @override
  String get ttsServicesFieldApiKeyLabel => 'API Key';

  @override
  String get ttsServicesFieldBaseUrlLabel => 'API Base URL';

  @override
  String get ttsServicesFieldModelLabel => 'Model';

  @override
  String get ttsServicesFieldVoiceLabel => 'Voice';

  @override
  String get ttsServicesFieldVoiceIdLabel => 'Voice ID';

  @override
  String get ttsServicesFieldEmotionLabel => 'Emotion';

  @override
  String get ttsServicesFieldSpeedLabel => 'Speed';

  @override
  String get ttsServicesFieldLanguageTypeLabel => 'Language type';

  @override
  String get ttsServicesFieldLanguageLabel => 'Language';

  @override
  String get ttsServicesFieldWorkspaceIdLabel => 'Workspace ID';

  @override
  String get ttsServicesFieldRegionLabel => 'Region';

  @override
  String get ttsServicesFieldFormatLabel => 'Audio format';

  @override
  String get ttsServicesFieldOutputFormatLabel => 'Output format';

  @override
  String get ttsServicesFieldSampleRateLabel => 'Sample rate';

  @override
  String get ttsServicesFieldVolumeLabel => 'Volume';

  @override
  String get ttsServicesFieldPitchLabel => 'Pitch';

  @override
  String get ttsServicesFieldLanguageBoostLabel => 'Language boost';

  @override
  String get ttsServicesFieldBitrateLabel => 'Bitrate';

  @override
  String get ttsServicesFieldChannelLabel => 'Channels';

  @override
  String get ttsServicesFieldSubtitlesLabel => 'Generate subtitles';

  @override
  String get ttsServicesFieldPronunciationDictionaryLabel =>
      'Pronunciation dictionary (one entry per line)';

  @override
  String get ttsServicesFieldInstructionLabel => 'Style / voice description';

  @override
  String get ttsServicesFieldStreamingLabel => 'Streaming';

  @override
  String get ttsServicesFieldOptimizeTextPreviewLabel =>
      'Optimize text preview';

  @override
  String get ttsServicesFieldReferenceAudioLabel =>
      'Reference audio (WAV/MP3 data URI)';

  @override
  String get ttsServicesFieldChooseReferenceAudioButton =>
      'Choose reference audio';

  @override
  String get ttsServicesFieldTemperatureLabel => 'Temperature';

  @override
  String get ttsServicesFieldTopPLabel => 'Top P';

  @override
  String get ttsServicesFieldLatencyLabel => 'Latency';

  @override
  String get ttsServicesEmotionAutoLabel => 'Auto match';

  @override
  String get ttsServicesValidationApiKeyRequired => 'API Key is required';

  @override
  String get ttsServicesValidationReferenceIdRequired =>
      'Voice/reference ID is required';

  @override
  String get ttsServicesValidationInstructionRequired =>
      'A voice description is required';

  @override
  String ttsServicesValidationSampleRate(String format, String rates) {
    return '$format requires $rates Hz.';
  }

  @override
  String get ttsServicesViewDetailsButton => 'View details';

  @override
  String get ttsServicesDialogErrorTitle => 'Error Details';

  @override
  String get ttsServicesCloseButton => 'Close';

  @override
  String get ttsSettingsPageTitle => 'TTS Settings';

  @override
  String get ttsSettingsPlaybackSection => 'Playback';

  @override
  String get ttsSettingsAutoPlayTitle => 'Auto-play Assistant Replies';

  @override
  String get ttsSettingsAutoPlayDescription =>
      'Start TTS automatically after an assistant reply finishes.';

  @override
  String get ttsSettingsCacheReplayTitle => 'Reuse Audio for Replay';

  @override
  String get ttsSettingsCacheReplayDescription =>
      'Replay generated network audio without requesting the TTS service again.';

  @override
  String get ttsSettingsTextSelectionSection => 'Text Selection';

  @override
  String get ttsSettingsTextSelectionFallbackDescription =>
      'If no matching text is found, the full reply is played.';

  @override
  String get ttsSettingsTextSelectionFullTextTitle => 'Full text';

  @override
  String get ttsSettingsTextSelectionFullTextDescription =>
      'Play the complete assistant reply.';

  @override
  String get ttsSettingsTextSelectionQuotedOnlyTitle => 'Quoted text only';

  @override
  String get ttsSettingsTextSelectionQuotedOnlyDescription =>
      'Play text inside “”, ‘’, \"\", \'\', 「」, or 『』.';

  @override
  String get ttsSettingsTextSelectionOutsideParenthesesTitle =>
      'Outside parentheses';

  @override
  String get ttsSettingsTextSelectionOutsideParenthesesDescription =>
      'Skip text inside () and （）.';

  @override
  String get ttsSettingsTextSelectionItalicOnlyTitle => 'Italic text only';

  @override
  String get ttsSettingsTextSelectionItalicOnlyDescription =>
      'Play Markdown or HTML italic text.';

  @override
  String get ttsSettingsTextSelectionNonItalicTitle => 'Non-italic text only';

  @override
  String get ttsSettingsTextSelectionNonItalicDescription =>
      'Skip Markdown or HTML italic text.';

  @override
  String get ttsFloatingPlayerLabel => 'TTS player';

  @override
  String get ttsFloatingPauseTooltip => 'Pause';

  @override
  String get ttsFloatingResumeTooltip => 'Resume';

  @override
  String get ttsFloatingReplayTooltip => 'Replay';

  @override
  String get ttsFloatingRewind15Tooltip => 'Back 15 seconds';

  @override
  String get ttsFloatingForward15Tooltip => 'Forward 15 seconds';

  @override
  String get ttsFloatingSpeedTooltip => 'Playback speed';

  @override
  String get ttsFloatingCloseTooltip => 'Close player';

  @override
  String get ttsFloatingExpandTooltip => 'Expand playback controls';

  @override
  String get ttsFloatingCollapseTooltip => 'Collapse playback controls';

  @override
  String get ttsFloatingSaveTooltip => 'Save audio';

  @override
  String get ttsSaveDialogTitle => 'Save TTS audio';

  @override
  String get ttsSaveSuccess => 'Audio saved successfully.';

  @override
  String get ttsSaveNothing => 'No audio is available to save.';

  @override
  String ttsSaveFailed(String message) {
    return 'Failed to save audio: $message';
  }

  @override
  String imageViewerPageShareFailedOpenFile(String message) {
    return 'Unable to share, tried to open file: $message';
  }

  @override
  String imageViewerPageShareFailed(String error) {
    return 'Share failed: $error';
  }

  @override
  String get imageViewerPageShareButton => 'Share Image';

  @override
  String get imageViewerPageCloseButton => 'Close preview';

  @override
  String get imageViewerPageSaveButton => 'Save Image';

  @override
  String get imageViewerPageCopyButton => 'Copy Image';

  @override
  String get imageViewerPagePreviousButton => 'Previous Image';

  @override
  String get imageViewerPageNextButton => 'Next Image';

  @override
  String get imageViewerPageZoomInButton => 'Zoom In';

  @override
  String get imageViewerPageZoomOutButton => 'Zoom Out';

  @override
  String get imageViewerPageResetZoomButton => 'Reset Zoom';

  @override
  String get imageViewerPageFlipHorizontalButton => 'Flip Horizontal';

  @override
  String get imageViewerPageFlipVerticalButton => 'Flip Vertical';

  @override
  String get imageViewerPageRotateLeftButton => 'Rotate Left';

  @override
  String get imageViewerPageRotateRightButton => 'Rotate Right';

  @override
  String imageViewerPageCounter(int index, int total) {
    return '$index/$total';
  }

  @override
  String imageViewerPageImageLabel(int index, int total) {
    return 'Image $index of $total';
  }

  @override
  String get imageViewerPageImageLoadFailed => 'Unable to load image';

  @override
  String get imageViewerPageSaveSuccess => 'Saved to gallery';

  @override
  String imageViewerPageSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get settingsShare => 'Kelivo - Open Source AI Assistant';

  @override
  String get searchProviderBingLocalDescription =>
      'Uses web scraping to fetch Bing results. No API key required; may be unstable.';

  @override
  String get searchProviderDuckDuckGoDescription =>
      'Privacy-focused DuckDuckGo search via DDGS. No API key required; supports region selection.';

  @override
  String get searchProviderBraveDescription =>
      'Independent search engine by Brave. Privacy-focused with no tracking or profiling.';

  @override
  String get searchProviderExaDescription =>
      'Neural search with semantic understanding. Great for research and finding specific content.';

  @override
  String get searchProviderLinkUpDescription =>
      'Search API with sourced answers. Provides both results and AI-generated summaries.';

  @override
  String get searchProviderMetasoDescription =>
      'Chinese search by Metaso. Optimized for Chinese content with AI capabilities.';

  @override
  String get searchProviderSearXNGDescription =>
      'Privacy-respecting metasearch engine. Self-hosted instance required; no tracking.';

  @override
  String get searchProviderTavilyDescription =>
      'AI search API optimized for LLMs. Provides high-quality, relevant results.';

  @override
  String get searchProviderZhipuDescription =>
      'Chinese AI search by Zhipu AI. Optimized for Chinese content and queries.';

  @override
  String get searchProviderOllamaDescription =>
      'Ollama web search API. Augments models with up-to-date information.';

  @override
  String get searchProviderJinaDescription =>
      'AI search foundation with embeddings, rerankers, web reader, deepsearch, and small language models. Multilingual and multimodal.';

  @override
  String get searchServiceNameBingLocal => 'Bing (Local)';

  @override
  String get searchServiceNameDuckDuckGo => 'DuckDuckGo';

  @override
  String get searchServiceNameTavily => 'Tavily';

  @override
  String get searchServiceNameExa => 'Exa';

  @override
  String get searchServiceNameZhipu => 'Zhipu AI';

  @override
  String get searchServiceNameSearXNG => 'SearXNG';

  @override
  String get searchServiceNameLinkUp => 'LinkUp';

  @override
  String get searchServiceNameBrave => 'Brave Search';

  @override
  String get searchServiceNameMetaso => 'Metaso';

  @override
  String get searchServiceNameOllama => 'Ollama';

  @override
  String get searchServiceNameJina => 'Jina';

  @override
  String get searchServiceNamePerplexity => 'Perplexity';

  @override
  String get searchProviderPerplexityDescription =>
      'Perplexity Search API. Ranked web results with region and domain filters.';

  @override
  String get searchServiceNameBocha => 'Bocha';

  @override
  String get searchProviderBochaDescription =>
      'Bocha web search API. Accurate web results with optional summaries.';

  @override
  String get searchServiceNameDoubao => 'Doubao';

  @override
  String get searchProviderDoubaoDescription =>
      'Doubao web search API by Volcano Engine.';

  @override
  String get searchServiceNameSerper => 'Serper';

  @override
  String get searchProviderSerperDescription =>
      'Serper Google Search API. Fast web results with optional country, language, time, and page filters.';

  @override
  String get searchServiceNameQuerit => 'Querit';

  @override
  String get searchProviderQueritDescription =>
      'Querit Search API for LLM applications. Returns real-time web results with site, time, country, and language filters.';

  @override
  String get searchServiceNameGrok => 'Grok';

  @override
  String get searchProviderGrokDescription =>
      'Grok search via xAI Responses API. Uses web and X search tools and returns cited sources.';

  @override
  String get searchServiceNameStepFun => 'StepFun';

  @override
  String get searchProviderStepFunDescription =>
      'StepFun web search via POST /v1/search.';

  @override
  String get searchServiceNameFirecrawl => 'Firecrawl';

  @override
  String get searchProviderFirecrawlDescription =>
      'Firecrawl Search API v2. API key is optional. Scrape is not supported here.';

  @override
  String get searchServiceNameTinyFish => 'TinyFish';

  @override
  String get searchProviderTinyFishDescription =>
      'TinyFish Search API with region/language filters. Requires an API key. Fetch/Scrape is not supported here.';

  @override
  String get searchServiceNameAnySearch => 'AnySearch';

  @override
  String get searchProviderAnySearchDescription =>
      'Unified search for AI agents with automatic routing across web and specialist data sources. API key is optional.';

  @override
  String get searchServiceNameParallel => 'Parallel';

  @override
  String get searchProviderParallelDescription =>
      'Parallel Search API. Returns LLM-optimized web excerpts with turbo, fast, basic, and advanced modes.';

  @override
  String get searchServicesDialogSearchMode => 'Search mode';

  @override
  String get searchServiceNameYou => 'You.com';

  @override
  String get searchProviderYouDescription =>
      'You.com Search API. Returns web and news results with highlights or snippets.';

  @override
  String get searchServicesDialogContentMode => 'Content mode';

  @override
  String get searchServicesDialogHighlights => 'Highlights';

  @override
  String get searchServicesDialogSnippets => 'Snippets';

  @override
  String get searchServicesDialogWebSearch => 'Web Search';

  @override
  String get searchServicesDialogLlmContext => 'LLM Context';

  @override
  String get searchServicesDialogMaximumTokens => 'Maximum tokens';

  @override
  String get searchServicesDialogMaximumTokensInvalid =>
      'Maximum tokens must be between 1024 and 32768.';

  @override
  String get searchServiceNameKelivo => 'Kelivo';

  @override
  String get searchServicesDialogCountryOptional => 'Country/region (optional)';

  @override
  String get searchServicesDialogLanguageOptional => 'Language (optional)';

  @override
  String get searchServicesDialogTimeFilterOptional => 'Time filter (optional)';

  @override
  String get searchServicesDialogPageOptional => 'Page (optional)';

  @override
  String get searchServicesDialogPageInvalid =>
      'Page must be a positive integer.';

  @override
  String get searchServicesDialogSitesIncludeOptional =>
      'Include sites (optional)';

  @override
  String get searchServicesDialogSitesExcludeOptional =>
      'Exclude sites (optional)';

  @override
  String get searchServicesDialogTimeRangeOptional => 'Time range (optional)';

  @override
  String get searchServicesDialogCountriesOptional => 'Countries (optional)';

  @override
  String get searchServicesDialogLanguagesOptional => 'Languages (optional)';

  @override
  String get searchServicesDialogSitesHint => 'example.com, docs.example.com';

  @override
  String get searchServicesDialogTimeRangeHint => 'd7';

  @override
  String get searchServicesDialogCountriesHint => 'united states, japan';

  @override
  String get searchServicesDialogLanguagesHint => 'english, japanese';

  @override
  String get generationInterrupted => 'Generation interrupted';

  @override
  String get titleForLocale => 'New Chat';

  @override
  String get temporaryChatTitle => 'Temporary Chat';

  @override
  String get temporaryChatEmptyMessage =>
      'Temporary chats do not appear in history and will be deleted completely after you leave.';

  @override
  String get temporaryChatToggleTooltip => 'Toggle temporary chat';

  @override
  String get quickPhraseBackTooltip => 'Back';

  @override
  String get quickPhraseGlobalTitle => 'Quick Phrase';

  @override
  String get quickPhraseAssistantTitle => 'Assistant Quick Phrase';

  @override
  String get quickPhraseAddTooltip => 'Add Quick Phrase';

  @override
  String get quickPhraseEmptyMessage => 'No quick phrases yet';

  @override
  String get quickPhraseAddTitle => 'Add Quick Phrase';

  @override
  String get quickPhraseEditTitle => 'Edit Quick Phrase';

  @override
  String get quickPhraseTitleLabel => 'Title';

  @override
  String get quickPhraseContentLabel => 'Content';

  @override
  String get quickPhraseCancelButton => 'Cancel';

  @override
  String get quickPhraseSaveButton => 'Save';

  @override
  String get instructionInjectionTitle => 'Instruction Injection';

  @override
  String get instructionInjectionBackTooltip => 'Back';

  @override
  String get instructionInjectionAddTooltip => 'Add Instruction';

  @override
  String get instructionInjectionImportTooltip => 'Import from files';

  @override
  String get instructionInjectionEmptyMessage =>
      'No instruction injection cards yet';

  @override
  String get instructionInjectionDefaultTitle => 'Learning Mode';

  @override
  String get instructionInjectionAddTitle => 'Add Instruction Injection';

  @override
  String get instructionInjectionEditTitle => 'Edit Instruction Injection';

  @override
  String get instructionInjectionNameLabel => 'Name';

  @override
  String get instructionInjectionPromptLabel => 'Prompt';

  @override
  String get instructionInjectionUngroupedGroup => 'Ungrouped';

  @override
  String get instructionInjectionGroupLabel => 'Group';

  @override
  String get instructionInjectionGroupHint => 'Optional';

  @override
  String instructionInjectionImportSuccess(int count) {
    return 'Imported $count instruction(s)';
  }

  @override
  String get instructionInjectionSheetSubtitle =>
      'Choose a prompt to apply before chatting';

  @override
  String get mcpJsonEditButtonTooltip => 'Edit JSON';

  @override
  String get mcpJsonEditTitle => 'Edit JSON';

  @override
  String get mcpJsonEditParseFailed => 'JSON parse failed';

  @override
  String get mcpJsonEditSavedApplied => 'Saved and applied';

  @override
  String get mcpTimeoutSettingsTooltip => 'Set tool call timeout';

  @override
  String get mcpTimeoutDialogTitle => 'Tool call timeout';

  @override
  String get mcpTimeoutSecondsLabel => 'Tool call timeout (seconds)';

  @override
  String get mcpTimeoutInvalid => 'Enter a positive number of seconds';

  @override
  String get quickPhraseEditButton => 'Edit';

  @override
  String get quickPhraseDeleteButton => 'Delete';

  @override
  String get quickPhraseMenuTitle => 'Quick Phrase';

  @override
  String get chatInputBarQuickPhraseTooltip => 'Quick Phrase';

  @override
  String get assistantEditQuickPhraseDescription =>
      'Manage quick phrases for this assistant. Click the button below to add phrases.';

  @override
  String get assistantEditManageQuickPhraseButton => 'Manage Quick Phrases';

  @override
  String get assistantEditPageMemoryTab => 'Memory';

  @override
  String get assistantEditLocalToolTimeInfoTitle => 'Time Info';

  @override
  String get assistantEditLocalToolTimeInfoSubtitle =>
      'Read the device date, weekday, time, timezone, UTC offset, and timestamp.';

  @override
  String get assistantEditLocalToolClipboardTitle => 'Clipboard';

  @override
  String get assistantEditLocalToolClipboardSubtitle =>
      'Read or write plain text from the device clipboard when explicitly needed.';

  @override
  String get assistantEditLocalToolTextToSpeechTitle => 'Text to Speech';

  @override
  String get assistantEditLocalToolTextToSpeechSubtitle =>
      'Let the assistant read text aloud with the configured TTS playback.';

  @override
  String get assistantEditLocalToolAskUserTitle => 'Ask User';

  @override
  String get assistantEditLocalToolAskUserSubtitle =>
      'Let the assistant ask short questions and continue after you answer.';

  @override
  String get assistantEditLocalToolCalculateTitle => 'Calculator';

  @override
  String get assistantEditLocalToolCalculateSubtitle =>
      'Evaluate mathematical expressions, supports + - * / power sqrt sin cos etc.';

  @override
  String get assistantEditLocalToolScreenTimeTitle => 'Screen Time';

  @override
  String get assistantEditLocalToolScreenTimeSubtitle =>
      'Query app screen usage on this device, requires the Usage access permission.';

  @override
  String get chatMessageWidgetScreenTimeTotal => 'Total screen time';

  @override
  String get chatMessageWidgetScreenTimePermissionRequired =>
      'Usage access permission is not granted. Please enable it in system settings and try again.';

  @override
  String get assistantEditLocalToolCalendarQueryTitle => 'Query Calendar';

  @override
  String get assistantEditLocalToolCalendarQuerySubtitle =>
      'Read calendar events on this device, requires the calendar permission.';

  @override
  String get assistantEditLocalToolCalendarCreateTitle => 'Create Event';

  @override
  String get assistantEditLocalToolCalendarCreateSubtitle =>
      'Create calendar events on this device with your confirmation, requires the calendar permission.';

  @override
  String get assistantEditLocalToolLocationTitle => 'Current Location';

  @override
  String get assistantEditLocalToolLocationSubtitle =>
      'Read a one-shot location from this device, requires the location permission.';

  @override
  String get assistantEditLocalToolWeatherTitle => 'Weather';

  @override
  String get assistantEditLocalToolWeatherSubtitle =>
      'Get Apple Weather for the current or a specified location. WeatherKit attribution is shown in the result.';

  @override
  String get assistantEditLocalToolHealthTitle => 'Health Summary';

  @override
  String get assistantEditLocalToolHealthSubtitle =>
      'Read a privacy-preserving activity summary from Apple Health, requires Health access.';

  @override
  String get assistantEditLocalToolRemindersQueryTitle => 'Query Reminders';

  @override
  String get assistantEditLocalToolRemindersQuerySubtitle =>
      'Read reminders on this device, requires full reminders access.';

  @override
  String get assistantEditLocalToolRemindersCreateTitle => 'Create Reminder';

  @override
  String get assistantEditLocalToolRemindersCreateSubtitle =>
      'Create a reminder on this device with your confirmation, requires full reminders access.';

  @override
  String get assistantEditLocalToolRemindersCompleteTitle =>
      'Complete Reminder';

  @override
  String get assistantEditLocalToolRemindersCompleteSubtitle =>
      'Mark a reminder as done with your confirmation, requires full reminders access.';

  @override
  String get assistantEditMemorySwitchDescription =>
      'Allow the assistant to create and use memories across chats.';

  @override
  String get assistantEditRecentChatsSwitchTitle => 'Recent Chats Reference';

  @override
  String get assistantEditRecentChatsSwitchDescription =>
      'Include recent conversation titles to help with context.';

  @override
  String get assistantEditAddMemoryButton => 'Add Memory';

  @override
  String get assistantEditMemoryEmpty => 'No memories yet';

  @override
  String get assistantEditMemoryDialogTitle => 'Memory';

  @override
  String get assistantEditMemoryDialogHint => 'Enter memory content';

  @override
  String get assistantEditAddQuickPhraseButton => 'Add Quick Phrase';

  @override
  String get multiKeyPageDeleteSnackbarDeletedOne => 'Deleted 1 key';

  @override
  String get multiKeyPageUndo => 'Undo';

  @override
  String get multiKeyPageUndoRestored => 'Restored';

  @override
  String get multiKeyPageDeleteErrorsTooltip => 'Delete errors';

  @override
  String get multiKeyPageDeleteErrorsConfirmTitle => 'Delete all error keys?';

  @override
  String get multiKeyPageDeleteErrorsConfirmContent =>
      'This will remove all keys marked as error.';

  @override
  String multiKeyPageDeletedErrorsSnackbar(int n) {
    return 'Deleted $n error keys';
  }

  @override
  String get providerDetailPageProviderTypeTitle => 'Provider Type';

  @override
  String get displaySettingsPageChatItemDisplayTitle => 'Chat item display';

  @override
  String get displaySettingsPageRenderingSettingsTitle => 'Rendering settings';

  @override
  String get displaySettingsPageBehaviorStartupTitle => 'Behavior & startup';

  @override
  String get displaySettingsPageHapticsSettingsTitle => 'Haptics';

  @override
  String get assistantSettingsNoPromptPlaceholder => 'No prompt yet';

  @override
  String get providersPageMultiSelectTooltip => 'Multi-select';

  @override
  String get providersPageDeleteSelectedConfirmContent =>
      'Delete selected providers? This cannot be undone.';

  @override
  String get providersPageDeleteSelectedSnackbar =>
      'Deleted selected providers';

  @override
  String providersPageExportSelectedTitle(int count) {
    return 'Export $count providers';
  }

  @override
  String get providersPageExportCopyButton => 'Copy';

  @override
  String get providersPageExportShareButton => 'Share';

  @override
  String get providersPageExportCopiedSnackbar => 'Copied export code';

  @override
  String get providersPageDeleteAction => 'Delete';

  @override
  String get providersPageExportAction => 'Export';

  @override
  String get assistantEditPresetTitle => 'Preset conversation';

  @override
  String get assistantEditPresetAddUser => 'Add user preset';

  @override
  String get assistantEditPresetAddAssistant => 'Add assistant preset';

  @override
  String get assistantEditPresetInputHintUser => 'Enter user message…';

  @override
  String get assistantEditPresetInputHintAssistant =>
      'Enter assistant message…';

  @override
  String get assistantEditPresetEmpty => 'No preset messages yet';

  @override
  String get assistantEditPresetEditDialogTitle => 'Edit preset message';

  @override
  String get assistantEditPresetRoleUser => 'User';

  @override
  String get assistantEditPresetRoleAssistant => 'Assistant';

  @override
  String get desktopTtsPleaseAddProvider => 'Please add a TTS provider first';

  @override
  String get settingsPageNetworkProxy => 'Network Proxy';

  @override
  String get networkProxyEnableLabel => 'Enable Proxy';

  @override
  String get networkProxySettingsHeader => 'Proxy Settings';

  @override
  String get networkProxyType => 'Proxy Type';

  @override
  String get networkProxyTypeHttp => 'HTTP';

  @override
  String get networkProxyTypeHttps => 'HTTPS';

  @override
  String get networkProxyTypeSocks5 => 'SOCKS5';

  @override
  String get networkProxyServerHost => 'Server';

  @override
  String get networkProxyPort => 'Port';

  @override
  String get networkProxyUsername => 'Username';

  @override
  String get networkProxyPassword => 'Password';

  @override
  String get networkProxyBypassLabel => 'Proxy bypass';

  @override
  String get networkProxyBypassHint =>
      'Comma-separated hosts/CIDR, e.g. localhost,127.0.0.1,192.168.0.0/16,*.local';

  @override
  String get networkProxyOptionalHint => 'Optional';

  @override
  String get networkProxyTestHeader => 'Connection Test';

  @override
  String get networkProxyTestUrlHint => 'Test URL';

  @override
  String get networkProxyTestButton => 'Test';

  @override
  String get networkProxyTesting => 'Testing…';

  @override
  String get networkProxyTestSuccess => 'Connection successful';

  @override
  String networkProxyTestFailed(String error) {
    return 'Test failed: $error';
  }

  @override
  String get networkProxyNoUrl => 'Please enter a URL';

  @override
  String get networkProxyPriorityNote =>
      'When both global and provider proxies are enabled, provider-level proxy takes priority.';

  @override
  String get desktopShowProviderInModelCapsule =>
      'Show provider in model capsule';

  @override
  String get messageWebViewOpenInBrowser => 'Open in Browser';

  @override
  String get messageWebViewConsoleLogs => 'Console Logs';

  @override
  String get messageWebViewNoConsoleMessages => 'No console messages';

  @override
  String get messageWebViewRefreshTooltip => 'Refresh';

  @override
  String get messageWebViewForwardTooltip => 'Forward';

  @override
  String get chatInputBarOcrTooltip => 'Image OCR';

  @override
  String get providerDetailPageMultiSelectButton => 'Multi-select';

  @override
  String get providerDetailPageBatchDetectButton => 'Detect';

  @override
  String get providerDetailPageBatchDetecting => 'Detecting...';

  @override
  String get providerDetailPageBatchDetectStart => 'Start Detection';

  @override
  String get providerDetailPageDetectSuccess => 'Detection successful';

  @override
  String get providerDetailPageDetectFailed => 'Detection failed';

  @override
  String get providerDetailPageDeleteSelectedModelsButton => 'Delete';

  @override
  String get providerDetailPageDeleteSelectedModelsTooltip =>
      'Delete selected models';

  @override
  String providerDetailPageDeleteSelectedModelsConfirm(int count) {
    return 'Delete $count selected model(s)? This cannot be undone.';
  }

  @override
  String get providerDetailPageDeleteFailedDetectedModelsButton =>
      'Delete unavailable';

  @override
  String get providerDetailPageDeleteFailedDetectedModelsTooltip =>
      'Delete models that failed detection';

  @override
  String providerDetailPageDeleteFailedDetectedModelsConfirm(int count) {
    return 'Delete $count model(s) that failed detection? This cannot be undone.';
  }

  @override
  String providerDetailPageSelectedModelsDeletedSnackbar(int count) {
    return 'Deleted $count model(s)';
  }

  @override
  String get providerDetailPageDeleteAllModelsTooltip => 'Delete all models';

  @override
  String get providerDetailPageDeleteAllModelsWarning =>
      'This action cannot be undone.';

  @override
  String get requestLogSettingTitle => 'Request Logging';

  @override
  String get requestLogSettingSubtitle =>
      'When enabled, request/response details are written to logs/logs.txt (rotated daily).';

  @override
  String get flutterLogSettingTitle => 'Flutter Logging';

  @override
  String get flutterLogSettingSubtitle =>
      'When enabled, Flutter errors and print output are written to logs/flutter_logs.txt (rotated daily).';

  @override
  String get contextLogSettingTitle => 'Context Logging';

  @override
  String get contextLogSettingSubtitle =>
      'When enabled, the exact messages sent to the model are written to logs/context_logs.txt (rotated daily).';

  @override
  String get contextLogViewerTitle => 'Context';

  @override
  String contextLogSnapshotMessages(int count) {
    return '$count messages';
  }

  @override
  String contextLogSnapshotTokens(int count) {
    return '$count tokens';
  }

  @override
  String get contextLogSourceSystemPrompt => 'System prompt';

  @override
  String get contextLogSourceMemoryRules => 'Memory rules';

  @override
  String get contextLogSourceSearchPrompt => 'Search prompt';

  @override
  String get contextLogSourceInstructionInjection => 'Instruction';

  @override
  String get contextLogSourceWorldBook => 'World book';

  @override
  String get contextLogSourceMemorySnapshot => 'Memory snapshot';

  @override
  String get contextLogSourceChatHistory => 'Chat history';

  @override
  String get contextLogSourceToolCall => 'Tool call';

  @override
  String get contextLogSourceToolResult => 'Tool result';

  @override
  String get contextLogTokensEstimateHint =>
      'Token counts are estimates only; use the model\'s actual usage as the source of truth.';

  @override
  String contextLogSnapshotsCount(int count) {
    return '$count snapshots';
  }

  @override
  String get contextLogSnapshotFallbackTitle => 'Snapshot';

  @override
  String get contextLogKindFull => 'Full snapshot';

  @override
  String get contextLogKindUpdate => 'Incremental update';

  @override
  String get contextLogSectionComposition => 'Composition';

  @override
  String get contextLogLoadOlder => 'Load earlier logs';

  @override
  String get contextLogLoading => 'Loading...';

  @override
  String get contextLogAllLoaded => 'All logs loaded';

  @override
  String get logViewerTitle => 'Request Logs';

  @override
  String get logViewerEmpty => 'No logs yet';

  @override
  String get logViewerCurrentLog => 'Current Log';

  @override
  String get logViewerExport => 'Export';

  @override
  String get logViewerOpenFolder => 'Open Logs Folder';

  @override
  String logViewerRequestsCount(int count) {
    return '$count requests';
  }

  @override
  String get logViewerFieldId => 'ID';

  @override
  String get logViewerFieldMethod => 'Method';

  @override
  String get logViewerFieldStatus => 'Status';

  @override
  String get logViewerFieldStarted => 'Started';

  @override
  String get logViewerFieldEnded => 'Ended';

  @override
  String get logViewerFieldDuration => 'Duration';

  @override
  String get logViewerSectionSummary => 'Summary';

  @override
  String get logViewerSectionParameters => 'Parameters';

  @override
  String get logViewerSectionRequestHeaders => 'Request Headers';

  @override
  String get logViewerSectionRequestBody => 'Request Body';

  @override
  String get logViewerSectionResponseHeaders => 'Response Headers';

  @override
  String get logViewerSectionResponseBody => 'Response Body';

  @override
  String get logViewerSectionWarnings => 'Warnings';

  @override
  String get logViewerErrorTitle => 'Error';

  @override
  String logViewerMoreCount(int count) {
    return '+$count more';
  }

  @override
  String get logViewerSectionAttachments => 'Attachments';

  @override
  String get logViewerPayloadOmitted => 'omitted';

  @override
  String get logViewerShowMore => 'Show more';

  @override
  String get logSettingsTitle => 'Log Settings';

  @override
  String get logSettingsSaveOutput => 'Save Response Output';

  @override
  String get logSettingsSaveOutputSubtitle =>
      'Log every streaming chunk (can slow generation). HTTP error bodies are always recorded.';

  @override
  String get logSettingsElidePayloads => 'Omit Large Payloads';

  @override
  String get logSettingsElidePayloadsSubtitle =>
      'Replace inline base64 images and files with a placeholder. Keeps logs small and the viewer fast.';

  @override
  String get logSettingsAutoDelete => 'Auto-delete';

  @override
  String get logSettingsAutoDeleteSubtitle =>
      'Delete logs older than specified days';

  @override
  String get logSettingsAutoDeleteDisabled => 'Disabled';

  @override
  String logSettingsAutoDeleteDays(int count) {
    return '$count days';
  }

  @override
  String get logSettingsMaxSize => 'Max Log Size';

  @override
  String get logSettingsMaxSizeSubtitle => 'Oldest logs deleted when exceeded';

  @override
  String get logSettingsMaxSizeUnlimited => 'Unlimited';

  @override
  String get assistantEditManageSummariesTitle => 'Manage Summaries';

  @override
  String get assistantEditSummaryEmpty => 'No summaries yet';

  @override
  String get assistantEditSummaryDialogTitle => 'Edit Summary';

  @override
  String get assistantEditSummaryDialogHint => 'Enter summary content';

  @override
  String get assistantEditDeleteSummaryTitle => 'Clear Summary';

  @override
  String get assistantEditDeleteSummaryContent =>
      'Are you sure you want to clear this summary?';

  @override
  String get homePageProcessingFiles => 'Processing files...';

  @override
  String get settingsPageWorldBook => 'World Book';

  @override
  String get settingsPageMemory => 'Memory';

  @override
  String get memorySettingsPageTitle => 'Memory';

  @override
  String get memorySettingsGlobalSubtitle => 'Memory mode, model, and prompts';

  @override
  String get memorySettingsModeSection => 'Memory mode';

  @override
  String get memorySettingsModelSection => 'Memory model';

  @override
  String get memorySettingsModelTitle => 'Processing model';

  @override
  String get memorySettingsModelUnset => 'Not selected';

  @override
  String get memorySettingsModelTip =>
      'After Auto-organize memory is enabled, this model is called frequently in the background. Prefer a cheap, fast model.';

  @override
  String get memorySettingsAboutTitle => 'About memory';

  @override
  String get memorySettingsAboutSubtitle => 'How memory works and when it runs';

  @override
  String get memoryAboutQuickstartTitle => 'Get started';

  @override
  String get memoryAboutQuickstartBody =>
      '1. In Settings → Memory, choose a processing model.\n2. On the assistant Memory tab, turn on long-term memory and Auto-organize.\n3. Chat for a few turns or tap Organize, then open All memories to see what was saved.';

  @override
  String get memoryAboutTypesTitle => 'Memory types';

  @override
  String get memoryAboutTypesBody =>
      'Identity: stable facts about the user, such as how to address them, role, language, and long-term preferences. Write complete third-person statements.\n\nWorkflow: how they like to get work done — tools, formats, and review habits.\n\nVoice: how they want the assistant to sound — tone, length, and language style.\n\nInstruction: standing rules the assistant should follow, not one-off tasks from this chat.';

  @override
  String get memoryAboutScopeTitle => 'Global vs assistant';

  @override
  String get memoryAboutScopeBody =>
      'Global memories are injected for every assistant. Assistant-scope memories are only visible to that assistant. Use global for facts that should follow the user everywhere; use assistant scope for rules or context that belong to one persona.';

  @override
  String get memoryAboutInjectionTitle => 'How memories are injected';

  @override
  String get memoryAboutInjectionBody =>
      'At the start of a chat, the newest items of each type are placed in the model context. If a type exceeds the injection limit, the block is marked mode=\"summary\" with total and shown counts; the rest can be fetched with memory_search_profile. Raise the limit in Settings → Memory for more completeness at a higher token cost.';

  @override
  String get memoryAboutPipelineTitle => 'Background pipeline';

  @override
  String get memoryAboutPipelineBody =>
      'Auto-organize runs after chats: decide whether anything is worth remembering, extract candidates, dedupe and merge, then distill identity items into the user profile when needed. You can also tap Organize on the assistant Memory tab. That is why the processing model is called often.';

  @override
  String get memoryAboutCacheTitle => 'Keep caching healthy';

  @override
  String get memoryAboutCacheBody =>
      'The injected memory prefix is kept stable so unchanged chats can reuse the prompt cache, lowering cost and latency. Avoid pointless bulk edits or reshuffles. Day-to-day single-entry edits usually have limited impact.';

  @override
  String get memoryAboutFaqTitle => 'FAQ';

  @override
  String get memoryAboutFaqWhyNotRememberedTitle =>
      'Why wasn\'t this remembered?';

  @override
  String get memoryAboutFaqWhyNotRememberedBody =>
      'Organize is skipped when there are not enough new messages to organize, no new messages to organize, or no memory processing model selected. Temporary chats are not saved to memory. You can also turn memory or Auto-organize off per assistant.';

  @override
  String get memorySettingsThinkingTitle => 'Enable thinking';

  @override
  String get memorySettingsThinkingSubtitle =>
      'Allow the memory model to use reasoning when supported';

  @override
  String get memorySettingsInjectionSection => 'Memory injection';

  @override
  String get memorySettingsInjectionMaxItemsTitle => 'Items injected per type';

  @override
  String get memorySettingsInjectionMaxItemsSubtitle =>
      'When a type exceeds this limit, only the newest items are injected. The rest can be fetched with memory_search_profile. A larger number is more complete but uses more tokens. If you customized the rules prompt, update it or restore the default.';

  @override
  String memorySettingsInjectionMaxItemsOption(int n) {
    return '$n';
  }

  @override
  String get memorySettingsInjectionMaxItemsCustomButton => 'Custom';

  @override
  String get memorySettingsInjectionMaxItemsCustomTitle =>
      'Custom injection count';

  @override
  String get memorySettingsInjectionMaxItemsCustomDescription =>
      'Enter a number between 1 and 100.';

  @override
  String get memorySettingsInjectionMaxItemsCustomLabel => 'Count';

  @override
  String get memorySettingsInjectionMaxItemsCustomHint => '1–100';

  @override
  String get memorySettingsInjectionMaxItemsCustomInvalid =>
      'Enter a number between 1 and 100';

  @override
  String get memorySettingsPromptLangSection => 'Prompt language';

  @override
  String get memorySettingsPromptLangAuto => 'Auto';

  @override
  String get memorySettingsPromptLangAutoSubtitle =>
      'Follow the UI language (Chinese → zh, otherwise en)';

  @override
  String get memorySettingsPromptLangZh => 'Chinese';

  @override
  String get memorySettingsPromptLangZhSubtitle =>
      'Always use Chinese memory prompts and tool descriptions';

  @override
  String get memorySettingsPromptLangEn => 'English';

  @override
  String get memorySettingsPromptLangEnSubtitle =>
      'Always use English memory prompts and tool descriptions';

  @override
  String get memorySettingsPromptsSection => 'Prompt templates';

  @override
  String get memorySettingsLegacyPromptTitle => 'Legacy memory rules';

  @override
  String get memoryPromptEditRulesTitle => 'Memory rules';

  @override
  String get memoryPromptEditRulesSubtitle =>
      'Injected into the main chat system prompt';

  @override
  String get memoryPromptEditGateTitle => 'Gatekeeper';

  @override
  String get memoryPromptEditGateSubtitle =>
      'Decides whether a turn is worth remembering';

  @override
  String get memoryPromptEditExtractTitle => 'Extract';

  @override
  String get memoryPromptEditExtractSubtitle =>
      'Extracts candidate memory items from a conversation';

  @override
  String get memoryPromptEditSmartAddTitle => 'Smart Add';

  @override
  String get memoryPromptEditSmartAddSubtitle =>
      'NEW / MERGE / CONFLICT / SKIP dedupe judge';

  @override
  String get memoryPromptEditDistillTitle => 'Profile Distiller';

  @override
  String get memoryPromptEditDistillSubtitle =>
      'Distills identity memories into profile fields';

  @override
  String get memoryPromptEditMigrateTitle => 'Legacy migration';

  @override
  String get memoryPromptEditMigrateSubtitle =>
      'Used when migration rewrites memory wording';

  @override
  String get memoryPromptEditReset => 'Reset to default';

  @override
  String get memoryPromptEditSave => 'Save';

  @override
  String get memoryPromptEditSectionPerItem => 'Per-item prompt';

  @override
  String get memoryPromptEditSectionBatch => 'Batched prompt';

  @override
  String get memorySettingsEntriesSection => 'All memories';

  @override
  String get memorySettingsLegacySection => 'Legacy memory';

  @override
  String get memorySettingsEntriesTitle => 'Memory list';

  @override
  String get memorySettingsEntriesSubtitle =>
      'Browse, edit, archive, and delete memories';

  @override
  String get memorySettingsProfileTitle => 'User profile';

  @override
  String get memorySettingsProfileSubtitle =>
      'Structured identity fields for the model';

  @override
  String get memorySettingsLegacyTitle => 'Legacy memories (read-only)';

  @override
  String get memorySettingsLegacySubtitle =>
      'Old memories from previous versions';

  @override
  String get memoryEntryTypeIdentity => 'Identity';

  @override
  String get memoryEntryTypeWorkflow => 'Workflow';

  @override
  String get memoryEntryTypeVoice => 'Voice';

  @override
  String get memoryEntryTypeInstruction => 'Instruction';

  @override
  String get memoryEntryScopeGlobal => 'Global';

  @override
  String get memoryEntryScopeAssistant => 'This assistant';

  @override
  String memoryEntryScopeAssistantNamed(String name) {
    return '$name';
  }

  @override
  String get memoryEntrySourceManual => 'Manual';

  @override
  String get memoryEntrySourceTool => 'Tool';

  @override
  String get memoryEntrySourceExtracted => 'Extracted';

  @override
  String get memoryEntrySourceDistilled => 'Distilled';

  @override
  String get memoryEntryStatusActive => 'Active';

  @override
  String get memoryEntryStatusArchived => 'Archived';

  @override
  String memoryEntryUpdatedAt(String date) {
    return 'Updated $date';
  }

  @override
  String get memoryEntryActionEdit => 'Edit';

  @override
  String get memoryEntryActionDelete => 'Delete';

  @override
  String get memoryEntryActionArchive => 'Archive';

  @override
  String get memoryEntryActionRestore => 'Restore';

  @override
  String get memoryEntryActionSwitchScope => 'Change scope';

  @override
  String get memoryEntryActionBatchDelete => 'Delete selected';

  @override
  String get memoryEntryActionAdd => 'Add memory';

  @override
  String get memoryEntryDeleteConfirmTitle => 'Delete memory?';

  @override
  String get memoryEntryDeleteConfirmContent =>
      'This permanently deletes the memory. This cannot be undone.';

  @override
  String memoryEntryBatchDeleteConfirmTitle(int count) {
    return 'Delete $count memories?';
  }

  @override
  String get memoryEntryBatchDeleteConfirmContent =>
      'Selected memories will be permanently deleted.';

  @override
  String get memoryEntrySwitchScopeConfirmTitle => 'Change memory scope?';

  @override
  String get memoryEntrySwitchScopeToGlobal =>
      'Make this memory global (shared across assistants)?';

  @override
  String get memoryEntrySwitchScopeToAssistant =>
      'Limit this memory to the current assistant?';

  @override
  String get memoryEntryArchivedSection => 'Archived';

  @override
  String get memoryEntryEmpty => 'No memories yet';

  @override
  String get memoryEntryEmptyDisabled =>
      'Long-term memory is off for this assistant';

  @override
  String get memoryEntryEditTitle => 'Edit memory';

  @override
  String get memoryEntryCreateTitle => 'New memory';

  @override
  String get memoryEntryContentHint => 'Enter memory content';

  @override
  String get memoryEntryTypeLabel => 'Type';

  @override
  String get memoryEntryScopeLabel => 'Scope';

  @override
  String get memoryFilterScopeAll => 'All scopes';

  @override
  String get memoryFilterScopeGlobal => 'Global only';

  @override
  String get memoryFilterScopeAssistant => 'Assistant';

  @override
  String get memoryFilterTypeAll => 'All types';

  @override
  String get memoryFilterStatusAll => 'All statuses';

  @override
  String get memoryFilterStatusActive => 'Active';

  @override
  String get memoryFilterStatusArchived => 'Archived';

  @override
  String get memorySearchHint => 'Search memories';

  @override
  String get memorySearchEmpty => 'No matching memories';

  @override
  String memoryOrphanBanner(int count) {
    return '$count orphaned assistant memories (assistant deleted)';
  }

  @override
  String get memoryOrphanCleanupButton => 'Clean up';

  @override
  String get memoryOrphanConfirmTitle => 'Clean up orphaned memories?';

  @override
  String memoryOrphanConfirmContent(int count) {
    return 'Permanently delete $count memories whose assistant no longer exists.';
  }

  @override
  String get memoryOrganizeButton => 'Organize';

  @override
  String get memoryOrganizeNeedsConversation =>
      'Open a chat with this assistant to organize memories';

  @override
  String get memoryOrganizeNeedsModel =>
      'Select a memory model in Settings → Memory first';

  @override
  String get memoryOrganizeStatusNever => 'Not organized yet';

  @override
  String memoryOrganizeStatusLast(String when) {
    return 'Last organized: $when';
  }

  @override
  String memoryOrganizeStatusExtracted(int count) {
    return 'extracted $count';
  }

  @override
  String get memoryOrganizeStatusSkipped => 'nothing to remember';

  @override
  String memoryOrganizeStatusFailed(String reason) {
    return 'Failed: $reason';
  }

  @override
  String memoryOrganizeStatusSkippedReason(String reason) {
    return 'skipped: $reason';
  }

  @override
  String get memoryOutcomeTemporaryConversation =>
      'Temporary chats are not saved to memory';

  @override
  String get memoryOutcomeMemoryDisabled => 'Memory is off for this assistant';

  @override
  String get memoryOutcomeAutoOrganizeOff => 'Auto-organize is off';

  @override
  String get memoryOutcomeStreaming =>
      'Skipped while a reply is still streaming';

  @override
  String get memoryOutcomeBelowThreshold =>
      'Not enough new messages to organize';

  @override
  String get memoryOutcomeEmptyWindow => 'No new messages to organize';

  @override
  String get memoryOutcomeMemoryModelUnset =>
      'No memory processing model selected';

  @override
  String get memoryOutcomeMemoryModelMissing =>
      'The selected memory model is no longer available';

  @override
  String get memoryOutcomeAssistantMissing => 'Assistant not found';

  @override
  String get memoryOutcomeConversationMissing => 'Conversation not found';

  @override
  String get memoryOutcomeQueueOverflow =>
      'The organize queue was full, so this run was dropped';

  @override
  String get memoryOutcomeGateRequestFailed =>
      'Could not reach the memory model for the remember/skip check';

  @override
  String get memoryOutcomeGateParseFailed =>
      'The remember/skip check returned an unreadable reply';

  @override
  String get memoryOutcomeExtractRequestFailed =>
      'Could not reach the memory model to extract memories';

  @override
  String get memoryOutcomeExtractParseFailed =>
      'The memory extract reply could not be parsed';

  @override
  String get memoryOutcomeDistillFailed => 'Could not distill the user profile';

  @override
  String get memoryOutcomeMemoryExecutionError => 'A memory tool failed to run';

  @override
  String get memoryOutcomeUnsupportedTool => 'Unsupported memory tool';

  @override
  String get memoryOutcomeInvalidMemoryType => 'Invalid memory type';

  @override
  String get memoryOutcomeInvalidMemoryContent => 'Invalid memory content';

  @override
  String get memoryOutcomeInvalidQuery => 'Invalid search query';

  @override
  String get memoryOutcomeInvalidMemoryId => 'Invalid memory id';

  @override
  String get memoryOutcomeMemoryNotFound => 'Memory not found';

  @override
  String get memoryOutcomeInvalidProfileFields => 'Invalid profile fields';

  @override
  String get memoryOutcomeChatSearchUnavailable => 'Chat search is unavailable';

  @override
  String get memoryOrganizeJustNow => 'just now';

  @override
  String memoryOrganizeMinutesAgo(int n) {
    return '$n min ago';
  }

  @override
  String memoryOrganizeHoursAgo(int n) {
    return '$n h ago';
  }

  @override
  String memoryOrganizeDaysAgo(int n) {
    return '$n d ago';
  }

  @override
  String get memoryModelMissingNotice =>
      'Select a memory processing model in Settings → Memory first.';

  @override
  String get memoryModelMissingGoSelect => 'Choose model';

  @override
  String get memoryEntriesPageTitle => 'All memories';

  @override
  String get userProfilePageTitle => 'User profile';

  @override
  String get userProfilePreferredName => 'Preferred name';

  @override
  String get userProfilePreferredNameHint =>
      'How the model should address you — unrelated to the sidebar display name';

  @override
  String get userProfileGender => 'Gender';

  @override
  String get userProfilePronouns => 'Pronouns';

  @override
  String get userProfilePreferredLanguage => 'Preferred language';

  @override
  String get userProfileTimezone => 'Timezone';

  @override
  String get userProfileOccupation => 'Occupation';

  @override
  String get userProfileLocation => 'Location';

  @override
  String get userProfileCustomSection => 'Custom fields';

  @override
  String get userProfileAddCustom => 'Add custom field';

  @override
  String get userProfileCustomKeyHint => 'Key (custom.name)';

  @override
  String get userProfileCustomValueHint => 'Value';

  @override
  String get userProfileInvalidKey =>
      'Key must be custom. followed by 1–32 letters, digits, _ or -';

  @override
  String get userProfileClear => 'Clear';

  @override
  String get userProfileSave => 'Save';

  @override
  String get userProfileEmptyValue => 'Not set';

  @override
  String get legacyMemoryPageTitle => 'Legacy memories';

  @override
  String get legacyMemoryBanner =>
      'These memories came from an older version and are not used in chats. You can migrate them into the current memory system.';

  @override
  String get legacyMemoryEmpty => 'No legacy memories';

  @override
  String get legacyMemoryCopy => 'Copy';

  @override
  String get legacyMemoryCopied => 'Copied';

  @override
  String get legacyMemoryExport => 'Export';

  @override
  String get legacyMemoryExportTitle => 'Kelivo legacy memory export';

  @override
  String legacyMemoryAssistantHeader(String name) {
    return 'Assistant: $name';
  }

  @override
  String get legacyMemorySearchHint => 'Search legacy memories';

  @override
  String get legacyMemoryMigrate => 'Migrate';

  @override
  String get legacyMemoryMigrationTitle => 'Migrate legacy memories';

  @override
  String legacyMemoryMigrationSubtitle(int count) {
    return 'Use a model to classify and clean up $count legacy memories. The originals stay unchanged.';
  }

  @override
  String get legacyMemoryMigrationModel => 'Migration model';

  @override
  String get legacyMemoryMigrationChooseModel => 'Choose a model';

  @override
  String get legacyMemoryMigrationTarget => 'Save to';

  @override
  String get legacyMemoryMigrationTargetGlobal => 'Global';

  @override
  String get legacyMemoryMigrationTargetAssistant => 'Current assistant';

  @override
  String get legacyMemoryMigrationTargetOriginalAssistants =>
      'Original assistants';

  @override
  String get legacyMemoryMigrationTargetGlobalDescription =>
      'Available to every assistant';

  @override
  String get legacyMemoryMigrationTargetAssistantDescription =>
      'Only available to this assistant';

  @override
  String get legacyMemoryMigrationTargetOriginalDescription =>
      'Keep each memory with its original assistant';

  @override
  String get legacyMemoryMigrationStart => 'Start migration';

  @override
  String get legacyMemoryMigrationAnalyzing => 'Analyzing with model';

  @override
  String get legacyMemoryMigrationWriting => 'Saving memories';

  @override
  String legacyMemoryMigrationProgress(int current, int total) {
    return '$current of $total';
  }

  @override
  String get legacyMemoryMigrationComplete => 'Migration complete';

  @override
  String legacyMemoryMigrationResult(int created, int skipped) {
    return '$created migrated · $skipped already existed';
  }

  @override
  String get legacyMemoryMigrationFailed =>
      'Migration stopped. You can retry; memories already saved will be skipped.';

  @override
  String get legacyMemoryMigrationRetry => 'Retry';

  @override
  String get legacyMemoryMigrationClose => 'Done';

  @override
  String get legacyMemoryMigrationContentMode => 'Content';

  @override
  String get legacyMemoryMigrationContentPreserve => 'Keep original';

  @override
  String get legacyMemoryMigrationContentOrganize => 'Rewrite with model';

  @override
  String get legacyMemoryMigrationContentPreserveDescription =>
      'The model only assigns a type. The original wording is saved as-is.';

  @override
  String get legacyMemoryMigrationContentOrganizeDescription =>
      'The model classifies and rewrites each memory using the editable migrate prompt.';

  @override
  String get legacyMemoryMigrationBatchSize => 'Batch size';

  @override
  String legacyMemoryMigrationPartial(int created, int skipped, int failed) {
    return '$created migrated · $skipped skipped · $failed failed';
  }

  @override
  String get legacyMemoryMigrationContinue => 'Continue migration';

  @override
  String get legacyMemoryMigrationErrorNetwork =>
      'Network error. Check the connection and try again.';

  @override
  String get legacyMemoryMigrationErrorFormat =>
      'The model returned an invalid response.';

  @override
  String get legacyMemoryMigrationErrorAuth =>
      'Authentication failed. Check the API key.';

  @override
  String legacyMemoryMigrationErrorOther(String message) {
    return 'Migration failed: $message';
  }

  @override
  String get legacyMemoryModeTitle => 'Use legacy memory';

  @override
  String get legacyMemoryModeSubtitle => 'Global setting for all assistants';

  @override
  String legacyMemoryModeCacheWarning(String token) {
    return 'The default template injects the current time via $token, which affects cache hit rate. Remove it if you do not need it.';
  }

  @override
  String get memoryUiContentLabel => 'Content';

  @override
  String get memoryUiValueLabel => 'Value';

  @override
  String get memoryUiCustomKeyLabel => 'Key';

  @override
  String get memoryUiStatusLabel => 'Status';

  @override
  String get memoryUiAssistantLabel => 'Assistant';

  @override
  String get memoryUiAssistantAll => 'All assistants';

  @override
  String get memoryUiSearchClear => 'Clear search';

  @override
  String get memoryUiAssistantLegacyTitle => 'Legacy memories (read-only)';

  @override
  String get memoryUiAssistantLegacySubtitle =>
      'Old memories of this assistant from previous versions';

  @override
  String get assistantEditMemorySwitchTitle => 'Use long-term memory';

  @override
  String get assistantEditMemorySwitchSubtitle =>
      'Inject saved memories into chats and let this assistant write new ones';

  @override
  String get assistantEditAutoOrganizeTitle => 'Auto-organize memory';

  @override
  String get assistantEditAutoOrganizeSubtitle =>
      'Run the memory pipeline after chats';

  @override
  String get assistantEditAllowPastRecallTitle => 'Allow recalling past chats';

  @override
  String get assistantEditAllowPastRecallSubtitle =>
      'Enable chat search across past conversations';

  @override
  String get assistantEditGenerateSummaryTitle =>
      'Generate conversation summaries';

  @override
  String get assistantEditGenerateSummarySubtitle =>
      'Summaries are only used by chat search';

  @override
  String get assistantEditManageMemoryTitle =>
      'Memories visible to this assistant';

  @override
  String get assistantEditWriteScopeTitle => 'Memory write scope';

  @override
  String get assistantEditWriteScopeSubtitle =>
      'Where new memories are stored by default';

  @override
  String get assistantEditWriteScopeAlwaysGlobal => 'Always global';

  @override
  String get assistantEditWriteScopeAlwaysGlobalSubtitle =>
      'New memories are shared with every assistant';

  @override
  String get assistantEditWriteScopeAlwaysAssistant => 'Always this assistant';

  @override
  String get assistantEditWriteScopeAlwaysAssistantSubtitle =>
      'New memories stay private to this assistant';

  @override
  String get assistantEditWriteScopeToolDefaultGlobal =>
      'Model chooses (default global)';

  @override
  String get assistantEditWriteScopeToolDefaultGlobalSubtitle =>
      'The model may pick global or this assistant; default is global';

  @override
  String get assistantEditWriteScopeToolDefaultAssistant =>
      'Model chooses (default assistant)';

  @override
  String get assistantEditWriteScopeToolDefaultAssistantSubtitle =>
      'The model may pick global or this assistant; default is this assistant';

  @override
  String get assistantEditDedupeModeTitle => 'Dedupe mode';

  @override
  String get assistantEditDedupeModeSubtitle =>
      'How candidates are judged against existing memories';

  @override
  String get assistantEditDedupeModeBatched => 'Batched';

  @override
  String get assistantEditDedupeModeBatchedSubtitle =>
      'Judge all new candidates in one request. Faster and cheaper; less precise when many items arrive at once.';

  @override
  String get assistantEditDedupeModePerItem => 'Per item';

  @override
  String get assistantEditDedupeModePerItemSubtitle =>
      'Judge each candidate in its own request. More accurate; uses more model calls.';

  @override
  String get assistantEditOrganizeFrequencyTitle => 'Organize every N turns';

  @override
  String get assistantEditOrganizeFrequencySubtitle =>
      'Run auto-organize after this many assistant replies';

  @override
  String assistantEditOrganizeFrequencyOption(int n) {
    return 'Every $n';
  }

  @override
  String get assistantEditOrganizeFrequencyCustomButton => 'Custom';

  @override
  String get assistantEditOrganizeFrequencyCustomTitle => 'Custom frequency';

  @override
  String get assistantEditOrganizeFrequencyCustomDescription =>
      'Enter a number between 1 and 20.';

  @override
  String get assistantEditOrganizeFrequencyCustomLabel => 'Turns';

  @override
  String get assistantEditOrganizeFrequencyCustomHint => '1–20';

  @override
  String get assistantEditOrganizeFrequencyCustomInvalid =>
      'Enter a number between 1 and 20';

  @override
  String get worldBookTitle => 'World Book';

  @override
  String get worldBookAdd => 'Add World Book';

  @override
  String get worldBookEmptyMessage => 'No world books yet';

  @override
  String get worldBookUnnamed => 'Unnamed World Book';

  @override
  String get worldBookDisabledTag => 'Disabled';

  @override
  String get worldBookAlwaysOnTag => 'Always On';

  @override
  String get worldBookAddEntry => 'Add Entry';

  @override
  String get worldBookExport => 'Share / Export';

  @override
  String get worldBookConfig => 'Configure';

  @override
  String get worldBookDeleteTitle => 'Delete World Book';

  @override
  String worldBookDeleteMessage(String name) {
    return 'Delete “$name”? This cannot be undone.';
  }

  @override
  String get worldBookCancel => 'Cancel';

  @override
  String get worldBookDelete => 'Delete';

  @override
  String worldBookExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get worldBookNoEntriesHint => 'No entries';

  @override
  String get worldBookUnnamedEntry => 'Unnamed Entry';

  @override
  String worldBookKeywordsLine(String keywords) {
    return 'Keywords: $keywords';
  }

  @override
  String get worldBookEditEntry => 'Edit Entry';

  @override
  String get worldBookDeleteEntry => 'Delete Entry';

  @override
  String get worldBookNameLabel => 'Name';

  @override
  String get worldBookDescriptionLabel => 'Description';

  @override
  String get worldBookEnabledLabel => 'Enabled';

  @override
  String get worldBookSave => 'Save';

  @override
  String get worldBookEntryNameLabel => 'Entry name';

  @override
  String get worldBookEntryEnabledLabel => 'Entry enabled';

  @override
  String get worldBookEntryPriorityLabel => 'Priority';

  @override
  String get worldBookEntryKeywordsLabel => 'Keywords';

  @override
  String get worldBookEntryKeywordsHint => 'Type a keyword and tap + to add.';

  @override
  String get worldBookEntryKeywordInputHint => 'Type a keyword';

  @override
  String get worldBookEntryKeywordAddTooltip => 'Add keyword';

  @override
  String get worldBookEntryUseRegexLabel => 'Use regex';

  @override
  String get worldBookEntryCaseSensitiveLabel => 'Case sensitive';

  @override
  String get worldBookEntryAlwaysOnLabel => 'Always active';

  @override
  String get worldBookEntryAlwaysOnHint =>
      'Always inject without keyword matching';

  @override
  String get worldBookEntryScanDepthLabel => 'Scan depth';

  @override
  String get worldBookEntryContentLabel => 'Content';

  @override
  String get worldBookEntryInjectionPositionLabel => 'Injection position';

  @override
  String get worldBookEntryInjectionRoleLabel => 'Injection role';

  @override
  String get worldBookEntryInjectDepthLabel => 'Injection depth';

  @override
  String get worldBookInjectionPositionBeforeSystemPrompt =>
      'Before system prompt';

  @override
  String get worldBookInjectionPositionAfterSystemPrompt =>
      'After system prompt';

  @override
  String get worldBookInjectionPositionTopOfChat => 'Top of chat';

  @override
  String get worldBookInjectionPositionBottomOfChat => 'Bottom of chat';

  @override
  String get worldBookInjectionPositionAtDepth => 'At depth';

  @override
  String get worldBookInjectionRoleUser => 'User';

  @override
  String get worldBookInjectionRoleAssistant => 'Assistant';

  @override
  String get mcpToolNeedsApproval => 'Require approval';

  @override
  String get toolApprovalPending => 'Waiting for approval';

  @override
  String get toolApprovalApprove => 'Approve';

  @override
  String get toolApprovalDeny => 'Deny';

  @override
  String get toolApprovalDenyTitle => 'Deny tool call';

  @override
  String get toolApprovalDenyHint => 'Reason (optional)';

  @override
  String toolApprovalDeniedMessage(Object reason, Object toolName) {
    return 'Tool call \"$toolName\" was denied by user. Reason: $reason';
  }

  @override
  String get askUserCardSubmit => 'Submit answer';

  @override
  String get askUserCardCustomHint => 'Type your answer';

  @override
  String get askUserCardSomethingElse => 'Something else';

  @override
  String get askUserCardSkip => 'Skip';

  @override
  String get askUserCardSkipped => 'Skipped';

  @override
  String get askUserCardAnswered => 'Answered';

  @override
  String get askUserCardInactive =>
      'This question is no longer active. Regenerate or continue the conversation.';

  @override
  String get askUserCardCancelled => 'Question cancelled';

  @override
  String askUserCardQuestionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ask $count questions',
      one: 'Ask 1 question',
    );
    return '$_temp0';
  }

  @override
  String tokenDetailPromptTokens(int count) {
    return '$count tokens';
  }

  @override
  String tokenDetailPromptTokensWithCache(int count, int cached) {
    return '$count tokens ($cached cached)';
  }

  @override
  String tokenDetailCompletionTokens(int count) {
    return '$count tokens';
  }

  @override
  String tokenDetailSpeed(String value) {
    return '$value tok/s';
  }

  @override
  String tokenDetailDuration(String value) {
    return '${value}s';
  }

  @override
  String tokenDetailTotalTokens(int count) {
    return '$count tokens';
  }

  @override
  String get debugPageTitle => 'Debug';

  @override
  String get debugPageConversationToolsTitle => 'Conversation tools';

  @override
  String get debugPageCreateOversizedConversationButton =>
      'Create oversized conversation (30 MB)';

  @override
  String get debugPageCreateManyMessagesConversationButton =>
      'Create 1024-message conversation';

  @override
  String get debugPageCreateDailyMixedMarkdownConversationButton =>
      'Create 3000 daily mixed Markdown messages';

  @override
  String get debugPageCreateLongReasoningConversationButton =>
      'Create long reasoning conversation (128 messages)';

  @override
  String get debugPageCreatingButton => 'Creating...';

  @override
  String get debugPageCreatingOversizedConversation =>
      'Creating a 30 MB oversized conversation...';

  @override
  String get debugPageCreatingManyMessagesConversation =>
      'Creating a 1024-message conversation...';

  @override
  String get debugPageCreatingDailyMixedMarkdownConversation =>
      'Creating a 3000-message daily mixed Markdown conversation...';

  @override
  String get debugPageCreatingLongReasoningConversation =>
      'Creating a long reasoning debug conversation...';

  @override
  String get debugPageNoCurrentAssistant =>
      'No current assistant. Create or select an assistant first.';

  @override
  String debugPageConversationCreated(int count) {
    return 'Created debug conversation with $count messages.';
  }

  @override
  String debugPageCreateConversationFailed(String error) {
    return 'Failed to create debug conversation: $error';
  }

  @override
  String debugPageOversizedConversationTitle(int sizeMB) {
    return 'Oversized conversation test ($sizeMB MB)';
  }

  @override
  String debugPageManyMessagesConversationTitle(int count) {
    return '$count-message conversation test';
  }

  @override
  String debugPageDailyMixedMarkdownConversationTitle(int count) {
    return '$count-message daily mixed Markdown test';
  }

  @override
  String debugPageLongReasoningConversationTitle(int count) {
    return '$count-message long reasoning test';
  }

  @override
  String get debugPageOversizedConversationSeedText =>
      'This is long debug text for reproducing slow rendering in oversized conversations. It includes repeated Markdown-like text, punctuation, CJK content, and plain words so chat rendering, storage, and scrolling can be profiled.';

  @override
  String debugPageManyMessagesSeedText(String role, int index) {
    return '$role message #$index: quick random debug sample for testing list rendering, scrolling stability, message grouping, and conversation history performance.';
  }

  @override
  String get migrationIntroTitle => 'Upgrade Chat Storage';

  @override
  String get migrationIntroSubtitle =>
      'Kelivo is moving chat history to a faster SQLite database. The upgrade runs before the app opens so your data stays consistent.';

  @override
  String get migrationBackupNote =>
      'Before migration starts, Kelivo exports a ZIP backup with settings, chat history, and local files.';

  @override
  String get migrationPerformanceNote =>
      'After migration, startup, history loading, and search use SQLite indexes for smoother long-chat performance.';

  @override
  String get migrationSourceDatabaseLabel => 'Hive';

  @override
  String get migrationTargetDatabaseLabel => 'SQLite';

  @override
  String get migrationChooseFolderButton => 'Choose Folder and Back Up';

  @override
  String get migrationSaveBackupButton => 'Save Backup ZIP';

  @override
  String get migrationStartWithoutBackupButton => 'Migrate Without Backing Up';

  @override
  String get migrationSkipChatsJsonOption => 'Skip chats.json';

  @override
  String get migrationSkipChatsJsonDescription =>
      'Still backs up the original Hive files, settings, and local files. Recommended for very large histories.';

  @override
  String get migrationSkipBackupOption => 'Skip this backup';

  @override
  String get migrationSkipBackupDescription =>
      'Only select this if you already have a verified backup. Migration will start immediately.';

  @override
  String get migrationBackingUpTitle => 'Backing Up';

  @override
  String get migrationBackingUpSubtitle =>
      'Exporting settings, chat history, uploaded files, images, and fonts. Keep Kelivo open until this finishes.';

  @override
  String get migrationMigratingTitle => 'Migrating to SQLite';

  @override
  String get migrationMigratingSubtitle =>
      'Writing conversations and messages in batches so large histories do not overload memory. Keep Kelivo in the foreground until migration finishes.';

  @override
  String migrationBackingUpDetail(String fileName) {
    return 'Backing up $fileName';
  }

  @override
  String migrationMigratingDetail(int count) {
    return 'Migrated $count messages';
  }

  @override
  String get migrationMigratingPrepareDetail => 'Preparing SQLite database';

  @override
  String get migrationMigratingToolEventsDetail => 'Migrating tool records';

  @override
  String get migrationMigratingValidateDetail => 'Validating migrated data';

  @override
  String get migrationBackupReadyDetail => 'Backup ZIP is ready';

  @override
  String get migrationSavingBackupZipDetail => 'Saving backup ZIP';

  @override
  String get migrationBackupFileSavedTitle => 'Backup ZIP saved';

  @override
  String get migrationChecklistBackupFiles => 'Export Hive backup ZIP';

  @override
  String get migrationChecklistPrepareSqlite => 'Prepare SQLite database';

  @override
  String get migrationChecklistMigrateMessages =>
      'Migrate conversations and messages';

  @override
  String get migrationChecklistMigrateToolEvents => 'Migrate tool records';

  @override
  String get migrationChecklistValidate => 'Validate migrated data';

  @override
  String get migrationStepBackup => 'Backup';

  @override
  String get migrationStepMigrate => 'Migrate';

  @override
  String get migrationStepComplete => 'Done';

  @override
  String get migrationCompleteTitle => 'Upgrade Complete';

  @override
  String get migrationCompleteSubtitle =>
      'Your chat history is now stored in SQLite. Restart Kelivo to enter the upgraded app.';

  @override
  String get migrationConversationCount => 'Conversations';

  @override
  String get migrationMessageCount => 'Messages';

  @override
  String get migrationConvertedCount => 'Converted';

  @override
  String get migrationMalformedCount => 'Malformed';

  @override
  String get migrationMissingFilesCount => 'Missing files';

  @override
  String get migrationRestartButton => 'Restart Kelivo';

  @override
  String get migrationFailedTitle => 'Migration Failed';

  @override
  String get migrationFailedSubtitle =>
      'The original Hive data is still intact. Any backup that finished earlier is unchanged. Review the reason below, then retry.';

  @override
  String get migrationUnknownError => 'Unknown migration error.';

  @override
  String get migrationFailureLogTitle => 'Failure log';

  @override
  String get migrationRetryButton => 'Retry Migration';

  @override
  String get migrationSkipButton => 'Skip Migration and Start Fresh';

  @override
  String get migrationSkipDialogTitle => 'Skip migration?';

  @override
  String get migrationSkipDialogMessage =>
      'Kelivo will start with an empty chat database. Your old chat history stays on disk (renamed with a .retired suffix) but will NOT be migrated and will not appear in the app. Use your backup ZIP if you need to recover it later.';

  @override
  String get migrationSkipDialogCancel => 'Cancel';

  @override
  String get migrationSkipDialogConfirm => 'Skip and Start Fresh';

  @override
  String get migrationChatsExportDegradedNote =>
      'The chats.json export was skipped because of an error. The backup ZIP still contains the raw Hive files with your complete chat history.';

  @override
  String get timelineJumpToLatest => 'Jump to latest';

  @override
  String largeContentShowMore(int count) {
    return 'Show $count more';
  }

  @override
  String get largeContentCollapse => 'Collapse';

  @override
  String get imageSettingsPageTitle => 'Image Processing';

  @override
  String get imageSettingsPageEditSectionTitle => 'Editing';

  @override
  String get imageSettingsPageQualitySectionTitle => 'Upload Image Quality';

  @override
  String get imageSettingsPageQualityOriginal => 'Original';

  @override
  String get imageSettingsPageQualityOriginalSubtitle =>
      'Don\'t compress; upload as-is';

  @override
  String get imageSettingsPageQualityHigh => 'High Quality';

  @override
  String get imageSettingsPageQualityHighSubtitle =>
      'Long edge 2048 px · quality 90';

  @override
  String get imageSettingsPageQualityBalanced => 'Balanced';

  @override
  String get imageSettingsPageQualityBalancedSubtitle =>
      'Long edge 1568 px · quality 85';

  @override
  String get imageSettingsPageQualitySaver => 'Data Saver';

  @override
  String get imageSettingsPageQualitySaverSubtitle =>
      'Long edge 1024 px · quality 70';

  @override
  String get imageSettingsPageQualityCustom => 'Custom';

  @override
  String get imageSettingsPageQualityCustomSubtitle =>
      'Choose the compression quality';

  @override
  String get imageSettingsPageCustomQualityTitle => 'Compression Quality';

  @override
  String get imageSettingsPageCompressTransparentTitle =>
      'Compress Transparent & Animated Images';

  @override
  String get imageSettingsPageCompressTransparentSubtitle =>
      'When enabled, transparent PNG, GIF, and similar formats are compressed; transparent areas become white and animations keep only the first frame.';

  @override
  String get imageSettingsPageFooter =>
      'Compression happens when images are added. Previously saved or sent images are not affected. Compressed images are sent as JPEG files.';

  @override
  String get memoryTraceSettingsTitle => 'Pipeline Traces';

  @override
  String get memoryTraceSettingsSubtitle =>
      'Inspect every background memory run step by step';

  @override
  String get memoryTracePageTitle => 'Memory Pipeline Traces';

  @override
  String get memoryTraceRecordingSection => 'Recording';

  @override
  String get memoryTraceToggleTitle => 'Record pipeline traces';

  @override
  String get memoryTraceToggleSubtitle =>
      'Keeps prompts, responses and changes of recent background runs in memory only';

  @override
  String get memoryTraceRunsSection => 'Recent runs';

  @override
  String get memoryTraceEmptyTitle => 'No traces yet';

  @override
  String get memoryTraceEmptySubtitle =>
      'Traces appear here after the background memory pipeline runs.';

  @override
  String get memoryTraceDisabledTitle => 'Recording is off';

  @override
  String get memoryTraceDisabledSubtitle =>
      'Turn recording on to capture the next background memory run.';

  @override
  String get memoryTraceClearAction => 'Clear';

  @override
  String get memoryTraceClearSheetTitle => 'Clear traces';

  @override
  String get memoryTraceClearSheetMessage =>
      'This removes every recorded trace. Traces are never written to disk, so nothing else is affected.';

  @override
  String get memoryTraceClearConfirm => 'Clear traces';

  @override
  String get memoryTraceCancel => 'Cancel';

  @override
  String get memoryTraceClearedToast => 'Traces cleared';

  @override
  String get memoryTraceCopyAction => 'Copy';

  @override
  String get memoryTraceCopiedToast => 'Copied to clipboard';

  @override
  String get memoryTraceTriggerAuto => 'Auto';

  @override
  String get memoryTraceTriggerManual => 'Manual';

  @override
  String get memoryTraceTriggerTool => 'Tool call';

  @override
  String get memoryTraceTriggerSummary => 'Summary';

  @override
  String get memoryTraceScopeAssistant => 'Assistant';

  @override
  String get memoryTraceScopeGlobal => 'Global';

  @override
  String get memoryTraceStepGatekeeper => 'Gatekeeper';

  @override
  String get memoryTraceStepExtract => 'Extract';

  @override
  String get memoryTraceStepSmartAdd => 'Smart Add';

  @override
  String get memoryTraceStepDistiller => 'Profile Distiller';

  @override
  String get memoryTraceStepSummary => 'Conversation Summary';

  @override
  String get memoryTraceStepChatSearch => 'Past Conversation Recall';

  @override
  String get memoryTraceStepTool => 'Memory Tool';

  @override
  String get memoryTraceStatusSuccess => 'Success';

  @override
  String get memoryTraceStatusFailed => 'Failed';

  @override
  String get memoryTraceStatusSkipped => 'Skipped';

  @override
  String get memoryTraceStatusRunning => 'Running';

  @override
  String get memoryTraceOutcomeAdvanced => 'Watermark advanced';

  @override
  String get memoryTraceOutcomeHeld => 'Watermark held';

  @override
  String get memoryTraceOutcomeForced => 'Forced advance';

  @override
  String get memoryTraceDetailTitle => 'Trace detail';

  @override
  String get memoryTraceSectionOverview => 'Overview';

  @override
  String get memoryTraceSectionPrompt => 'Prompt';

  @override
  String get memoryTraceSectionResponse => 'Raw response';

  @override
  String get memoryTraceSectionParsed => 'Parsed result';

  @override
  String get memoryTraceSectionMutations => 'Changes applied';

  @override
  String get memoryTraceFieldTime => 'Started';

  @override
  String get memoryTraceFieldDuration => 'Duration';

  @override
  String get memoryTraceFieldTrigger => 'Trigger';

  @override
  String get memoryTraceFieldScope => 'Scope';

  @override
  String get memoryTraceFieldConversation => 'Chat';

  @override
  String get memoryTraceFieldAssistant => 'Assistant';

  @override
  String get memoryTraceFieldWindow => 'Window';

  @override
  String get memoryTraceFieldWatermark => 'Watermark';

  @override
  String get memoryTraceFieldOutcome => 'Outcome';

  @override
  String get memoryTraceFieldError => 'Error';

  @override
  String get memoryTraceMutationCreated => 'Created';

  @override
  String get memoryTraceMutationMerged => 'Merged';

  @override
  String get memoryTraceMutationEdited => 'Edited';

  @override
  String get memoryTraceMutationArchived => 'Archived';

  @override
  String get memoryTraceMutationLinked => 'Linked';

  @override
  String get memoryTraceMutationProfileWritten => 'Profile field written';

  @override
  String get memoryTraceMutationProfileCleared => 'Profile field cleared';

  @override
  String get memoryTraceMutationSummary => 'Chat summary written';

  @override
  String get memoryTraceBefore => 'Before';

  @override
  String get memoryTraceAfter => 'After';

  @override
  String get memoryTraceEmptyValue => '(empty)';

  @override
  String memoryTraceStepsCount(int count) {
    return '$count steps';
  }

  @override
  String memoryTraceMutationsCount(int count) {
    return '$count changes';
  }

  @override
  String memoryTraceRepeatCount(int count) {
    return 'repeated $count×';
  }

  @override
  String memoryTraceWindowValue(int size, int start, int end) {
    return '$size messages · #$start–#$end';
  }

  @override
  String get memoryTraceShowMore => 'Show full text';

  @override
  String get memoryTraceShowLess => 'Collapse';

  @override
  String get messageStyleSettingsPageTitle => 'Message Style';

  @override
  String get messageStyleSettingsPageReset => 'Reset';

  @override
  String get messageStyleSettingsPageResetConfirm =>
      'Reset all message style customizations?';

  @override
  String get messageStyleSettingsPageCancel => 'Cancel';

  @override
  String get messageStyleSettingsPageLight => 'Light';

  @override
  String get messageStyleSettingsPageDark => 'Dark';

  @override
  String get messageStyleSettingsPageDefaultHint =>
      'Default style follows the current theme and has no extra controls.';

  @override
  String get messageStyleSettingsPageStyleDefaultSubtitle =>
      'Follows the theme; not customizable';

  @override
  String get messageStyleSettingsPageAssistantFitContent =>
      'Fit assistant bubble to content';

  @override
  String get messageStyleSettingsPageAssistantFitContentSubtitle =>
      'Assistant bubbles hug their text instead of filling the row';

  @override
  String get messageStyleSettingsPageStyleFrostedSubtitle =>
      'Translucent frosted glass';

  @override
  String get messageStyleSettingsPageStyleSolidSubtitle => 'Opaque solid fill';

  @override
  String get messageStyleSettingsPageBlur => 'Blur';

  @override
  String get messageStyleSettingsPageBlurHint =>
      'Blur applies to content behind the bubble. It is barely visible without a chat wallpaper.';

  @override
  String get messageStyleSettingsPageBackgroundColor => 'Background';

  @override
  String get messageStyleSettingsPageBackgroundOpacity => 'Background Opacity';

  @override
  String get messageStyleSettingsPageBorderColor => 'Border';

  @override
  String get messageStyleSettingsPageBorderOpacity => 'Border Opacity';

  @override
  String get messageStyleSettingsPageBorderWidth => 'Border Width';

  @override
  String get messageStyleSettingsPageTextColor => 'Text';

  @override
  String get messageStyleSettingsPageCornerRadius => 'Corner Radius';

  @override
  String get messageStyleSettingsPagePreviewUser => 'This is a user message';

  @override
  String get messageStyleSettingsPagePreviewAssistant =>
      'This is an assistant reply.';

  @override
  String get messageStyleSettingsPagePreviewThinking => 'Thinking';

  @override
  String get messageStyleSettingsPageRoleUser => 'User';

  @override
  String get messageStyleSettingsPageRoleAssistant => 'Assistant';

  @override
  String get messageStyleSettingsPageRoleAssistantHint =>
      'Assistant settings also apply to thinking, tool-call, and translation cards.';

  @override
  String get localSnapshotSectionTitle => 'Local Copies';

  @override
  String get localSnapshotEnabledTitle => 'Keep local copies';

  @override
  String get localSnapshotEnabledSubtitle =>
      'Kelivo periodically saves a copy of its database on this device, so it is never the only one.';

  @override
  String get localSnapshotIntervalTitle => 'How often';

  @override
  String get localSnapshotIntervalAutomatic => 'Automatic';

  @override
  String get localSnapshotIntervalAutomaticDetail =>
      'Daily, less often as the database grows';

  @override
  String localSnapshotIntervalDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Every $days days',
      one: 'Every day',
    );
    return '$_temp0';
  }

  @override
  String get localSnapshotKeepTitle => 'Copies to keep';

  @override
  String localSnapshotKeepValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count copies',
      one: '1 copy',
    );
    return '$_temp0';
  }

  @override
  String get localSnapshotKeepSubtitle =>
      'Plus one from last week and one from last month, so a problem that went unnoticed is still recoverable.';

  @override
  String get localSnapshotKeepWeekly => 'Keep one from last week';

  @override
  String get localSnapshotKeepMonthly => 'Keep one from last month';

  @override
  String get localSnapshotKeepProtectedNote =>
      'The most recent copy that still contains data is never removed automatically, whatever this is set to.';

  @override
  String get localSnapshotMaximumTitle => 'Space limit';

  @override
  String get localSnapshotMaximumUnlimited => 'No limit';

  @override
  String get localSnapshotAnnounceTitle => 'Notify when a copy is saved';

  @override
  String get localSnapshotAnnounceSubtitle =>
      'Failures are always reported. This only adds a brief message on success.';

  @override
  String get localSnapshotTakeNow => 'Save a copy now';

  @override
  String get localSnapshotManageCopies => 'Manage copies';

  @override
  String localSnapshotUsage(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count copies',
      one: '1 copy',
      zero: 'No copies',
    );
    return '$_temp0 · $size';
  }

  @override
  String get localSnapshotStatusNever => 'No copy saved yet';

  @override
  String localSnapshotStatusSuccess(String when) {
    return 'Last copy $when';
  }

  @override
  String localSnapshotStatusFailure(String when, String reason) {
    return 'Last attempt failed $when: $reason';
  }

  @override
  String get localSnapshotStatusSkippedSpace =>
      'Skipped: not enough free space on this device';

  @override
  String get localSnapshotStatusUnchanged =>
      'Nothing has changed since the last copy';

  @override
  String get localSnapshotCopiesTitle => 'Local Copies';

  @override
  String get localSnapshotCopiesEmpty => 'No local copies yet';

  @override
  String get localSnapshotCopiesEmptyHint =>
      'A copy is saved automatically as your data changes, and one is always saved before a restore.';

  @override
  String get localSnapshotCopiesScopeNote =>
      'Local copies live on this device only. They protect against damage to your data inside the app, not against losing the device or uninstalling Kelivo — use WebDAV or S3 backup for that.';

  @override
  String get localSnapshotOriginAutomatic => 'Automatic';

  @override
  String get localSnapshotOriginManual => 'Saved by you';

  @override
  String get localSnapshotOriginBeforeRestore => 'Before a restore';

  @override
  String get localSnapshotKindRecovered => 'Set aside by recovery';

  @override
  String localSnapshotCopyContents(int conversations, int messages) {
    String _temp0 = intl.Intl.pluralLogic(
      conversations,
      locale: localeName,
      other: '$conversations chats',
      one: '1 chat',
    );
    String _temp1 = intl.Intl.pluralLogic(
      messages,
      locale: localeName,
      other: '$messages messages',
      one: '1 message',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get localSnapshotCopyContentsUnknown =>
      'Contents unknown until restored';

  @override
  String get localSnapshotCopyPinned => 'Kept';

  @override
  String get localSnapshotActionRestore => 'Restore';

  @override
  String get localSnapshotActionExport => 'Export';

  @override
  String get localSnapshotActionDelete => 'Delete';

  @override
  String get localSnapshotActionPin => 'Keep this copy';

  @override
  String get localSnapshotActionUnpin => 'Stop keeping';

  @override
  String get localSnapshotRestoreTitle => 'Restore this copy?';

  @override
  String localSnapshotRestoreMessage(String when) {
    return 'Your current chats and settings will be replaced by this copy from $when. A copy of what you have now is saved first, so this can be undone.';
  }

  @override
  String get localSnapshotRestorePreparing => 'Preparing copy';

  @override
  String get localSnapshotDeleteTitle => 'Delete this copy?';

  @override
  String get localSnapshotDeleteMessage =>
      'This copy will be removed from the device permanently. Any data it holds that is not in your current database will be gone.';

  @override
  String get localSnapshotDeleteLastWarning =>
      'This is the only copy that still contains data.';

  @override
  String get localSnapshotExportPreparing => 'Preparing export';

  @override
  String get localSnapshotExportDone => 'Copy exported';

  @override
  String localSnapshotExportFailed(String reason) {
    return 'Could not export the copy: $reason';
  }

  @override
  String get localSnapshotTakeDone => 'Copy saved';

  @override
  String localSnapshotTakeFailed(String reason) {
    return 'Could not save a copy: $reason';
  }

  @override
  String get localSnapshotDeleteDone => 'Copy deleted';

  @override
  String get localSnapshotBusyMessage =>
      'Another backup task is already running';

  @override
  String get localSnapshotRunInBackground => 'Continue in background';

  @override
  String get localSnapshotRunningInBackground =>
      'Saving a copy in the background';

  @override
  String startupRecoveryLocalCopiesAvailable(int count, String when) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count local copies',
      one: '1 local copy',
    );
    return 'This device still holds $_temp0, the most recent from $when. Resetting does not delete them — after restarting you can restore one from Settings › Backup › Local Copies.';
  }

  @override
  String startupRecoveryRecoveredCopiesDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count database copies',
      one: '1 database copy',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'those',
      one: 'it',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'them',
      one: 'it',
    );
    return 'It also holds $_temp0 set aside by an earlier repair, and resetting DOES delete $_temp1 permanently. Export your data first if you want to keep $_temp2.';
  }
}
