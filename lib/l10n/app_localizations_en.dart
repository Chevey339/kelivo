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
  String get settingsPageDisplay => 'Display';

  @override
  String get settingsPageDisplaySubtitle => 'Appearance and text size';

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
  String get storageSpaceCategoryChatData => 'Chat Records';

  @override
  String get storageSpaceCategoryAssistantData => 'Assistants';

  @override
  String get storageSpaceCategoryCache => 'Cache';

  @override
  String get storageSpaceCategoryLogs => 'Logs';

  @override
  String get storageSpaceCategoryOther => 'App';

  @override
  String storageSpaceFilesCount(int count) {
    return '$count files';
  }

  @override
  String get storageSpaceSafeToClearHint =>
      'Safe to clear. This will not affect your chat history.';

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
  String get settingsPageAboutSection => 'About';

  @override
  String get settingsPageAbout => 'About';

  @override
  String get settingsPageDocs => 'Docs';

  @override
  String get settingsPageLogs => 'Logs';

  @override
  String get settingsPageSponsor => 'Sponsor';

  @override
  String get settingsPageShare => 'Share';

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
  String assistantProviderSampleAssistantSystemPrompt(
    String model_name,
    String cur_datetime,
    String locale,
    String timezone,
    String device_info,
    String system_version,
  ) {
    return 'You are $model_name, an AI assistant who gladly provides accurate and helpful assistance. The current time is $cur_datetime, the device language is $locale, timezone is $timezone, the user is using $device_info, version $system_version. If the user does not explicitly specify otherwise, please use the user\'s device language when replying.';
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
  String get homePageDeleteMessage => 'Delete Message';

  @override
  String get homePageDeleteMessageConfirm =>
      'Are you sure you want to delete this message? This cannot be undone.';

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
      'Use assistant avatar/name instead of model';

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
  String get codeBlockPreviewButton => 'Preview';

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
  String get assistantSettingsDefaultTag => 'Default';

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
      'Restore completed. Please restart the app.';

  @override
  String get backupPageOK => 'OK';

  @override
  String get backupPageCancel => 'Cancel';

  @override
  String get backupPageSelectImportMode => 'Select Import Mode';

  @override
  String get backupPageSelectImportModeDescription =>
      'Choose how to import the backup data:';

  @override
  String get backupPageOverwriteMode => 'Complete Overwrite';

  @override
  String get backupPageOverwriteModeDescription =>
      'Clear all local data and restore from backup';

  @override
  String get backupPageMergeMode => 'Smart Merge';

  @override
  String get backupPageMergeModeDescription =>
      'Add only non-existing data (intelligent deduplication)';

  @override
  String get backupPageRestore => 'Restore';

  @override
  String get backupPageBackupUploaded => 'Backup uploaded';

  @override
  String get backupPageBackup => 'Backup';

  @override
  String get backupPageExporting => 'Exporting...';

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
  String get backupPageImportFromRikkaHub => 'Import from RikkaHub';

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
  String get backupPageSave => 'Save';

  @override
  String get backupPageBackupNow => 'Backup Now';

  @override
  String get backupPageLocalBackup => 'Local Backup';

  @override
  String get backupPageImportFromCherryStudio => 'Import from Cherry Studio';

  @override
  String get backupPageImportFromChatbox => 'Import from Chatbox';

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
  String get messageMoreSheetCreateBranch => 'Create Branch';

  @override
  String get messageMoreSheetDelete => 'Delete';

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
  String get reasoningBudgetSheetCustomLabel =>
      'Custom Reasoning Budget (tokens)';

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
  String chatMessageWidgetCitationsTitle(int count) {
    return 'Citations ($count)';
  }

  @override
  String get chatMessageWidgetRegenerateTooltip => 'Regenerate';

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
  String get chatMessageWidgetCreateMemory => 'Create Memory';

  @override
  String get chatMessageWidgetEditMemory => 'Edit Memory';

  @override
  String get chatMessageWidgetDeleteMemory => 'Delete Memory';

  @override
  String chatMessageWidgetWebSearch(String query) {
    return 'Web Search: $query';
  }

  @override
  String get chatMessageWidgetBuiltinSearch => 'Built-in Search';

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
    return 'Citations ($count)';
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
  String get sideDrawerMenuMoveTo => 'Move to';

  @override
  String get sideDrawerMenuDelete => 'Delete';

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
  String get sideDrawerSearchHint => 'Search chat history';

  @override
  String get sideDrawerSearchAssistantsHint => 'Search assistants';

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
  String get mcpPageStatusDisabled => 'Disabled';

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
      'Used for summarizing conversation titles; prefer fast & cheap models';

  @override
  String get defaultModelPageSummaryModelTitle => 'Summary Model';

  @override
  String get defaultModelPageSummaryModelSubtitle =>
      'Used for generating conversation summaries; prefer fast and cheap models';

  @override
  String get defaultModelPageTranslateModelTitle => 'Translation Model';

  @override
  String get defaultModelPageTranslateModelSubtitle =>
      'Used for translating message content; prefer fast & accurate models';

  @override
  String get defaultModelPageOcrModelTitle => 'OCR Model';

  @override
  String get defaultModelPageOcrModelSubtitle =>
      'Used for extracting text and descriptions from images';

  @override
  String get defaultModelPagePromptLabel => 'Prompt';

  @override
  String get defaultModelPageTitlePromptHint =>
      'Enter prompt template for title summarization';

  @override
  String get defaultModelPageSummaryPromptHint =>
      'Enter prompt template for summary generation';

  @override
  String get defaultModelPageTranslatePromptHint =>
      'Enter prompt template for translation';

  @override
  String get defaultModelPageOcrPromptHint =>
      'Enter prompt template for OCR image understanding';

  @override
  String get defaultModelPageResetDefault => 'Reset to default';

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
  String defaultModelPageTranslateVars(String sourceVar, String targetVar) {
    return 'Variables: source text: $sourceVar, target language: $targetVar';
  }

  @override
  String get defaultModelPageUseCurrentModel => 'Use current chat model';

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
  String get modelDetailSheetAddBody => 'Add Body';

  @override
  String get modelDetailSheetBuiltinToolsDescription =>
      'Built-in tools only support official APIs.';

  @override
  String get modelDetailSheetGeminiCodeExecutionMutuallyExclusiveHint =>
      'Code execution cannot coexist with Search/URL Context/MCP tools.';

  @override
  String get modelDetailSheetBuiltinToolsUnsupportedHint =>
      'Current provider does not support these built-in tools.';

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
  String get providersPageProviderAddedSnackbar => 'Provider added';

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
  String get searchSettingsSheetTitle => 'Search Settings';

  @override
  String get searchSettingsSheetBuiltinSearchTitle => 'Built-in Search';

  @override
  String get searchSettingsSheetBuiltinSearchDescription =>
      'Enable model\'s built-in search';

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
  String get aboutPageAppDescription => 'Open-source AI Assistant';

  @override
  String get aboutPageNoQQGroup => 'No QQ group yet';

  @override
  String get aboutPageVersion => 'Version';

  @override
  String get aboutPageSystem => 'System';

  @override
  String get aboutPageWebsite => 'Website';

  @override
  String get aboutPageLicense => 'License';

  @override
  String get aboutPageJoinQQGroup => 'Join our QQ Group';

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
  String get displaySettingsPageAutoCollapseThinkingTitle =>
      'Auto-collapse Thinking';

  @override
  String get displaySettingsPageAutoCollapseThinkingSubtitle =>
      'Collapse reasoning after finish';

  @override
  String get displaySettingsPageShowChatListDateTitle => 'Show Chat List Dates';

  @override
  String get displaySettingsPageShowChatListDateSubtitle =>
      'Display date group labels in the conversation list';

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
  String get displaySettingsPageMessageNavButtonsTitle =>
      'Message Navigation Buttons';

  @override
  String get displaySettingsPageMessageNavButtonsSubtitle =>
      'Show quick jump buttons when scrolling';

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
  String get fontPickerGetFromGoogleFonts => 'Browse Google Fonts';

  @override
  String get fontPickerFilterHint => 'Filter fonts...';

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
  String get themeSettingsPageColorPalettesSection => 'Color Palettes';

  @override
  String get ttsServicesPageBackButton => 'Back';

  @override
  String get ttsServicesPageTitle => 'Text-to-Speech';

  @override
  String get ttsServicesPageAddTooltip => 'Add';

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
  String get ttsServicesViewDetailsButton => 'View details';

  @override
  String get ttsServicesDialogErrorTitle => 'Error Details';

  @override
  String get ttsServicesCloseButton => 'Close';

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
  String get imageViewerPageSaveButton => 'Save Image';

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
  String get generationInterrupted => 'Generation interrupted';

  @override
  String get titleForLocale => 'New Chat';

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
  String get assistantEditMemorySwitchTitle => 'Memory';

  @override
  String get assistantEditMemorySwitchDescription =>
      'Allow the assistant to create and use memories across chats.';

  @override
  String get assistantEditRecentChatsSwitchTitle => 'Recent Chats Reference';

  @override
  String get assistantEditRecentChatsSwitchDescription =>
      'Include recent conversation titles to help with context.';

  @override
  String get assistantEditManageMemoryTitle => 'Manage Memories';

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
  String get fileUploadDuplicateTitle => 'File already exists';

  @override
  String fileUploadDuplicateContent(String fileName) {
    return 'A file named $fileName already exists. Use the existing file?';
  }

  @override
  String get fileUploadDuplicateUseExisting => 'Use existing';

  @override
  String get fileUploadDuplicateUploadNew => 'Upload new';

  @override
  String get settingsPageWorldBook => 'World Book';

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
  String get worldBookEntryKeywordsHint =>
      'Type a keyword and tap +. You can paste multiple, separated by commas or new lines.';

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
}
