// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get helloWorld => '你好，世界！';

  @override
  String get settingsPageBackButton => '返回';

  @override
  String get settingsPageTitle => '设置';

  @override
  String get settingsPageDarkMode => '深色';

  @override
  String get settingsPageLightMode => '浅色';

  @override
  String get settingsPageSystemMode => '跟随系统';

  @override
  String get settingsPageWarningMessage => '部分服务未配置，某些功能可能不可用';

  @override
  String get settingsPageGeneralSection => '通用设置';

  @override
  String get settingsPageColorMode => '颜色模式';

  @override
  String get settingsPageDisplay => '显示设置';

  @override
  String get settingsPageDisplaySubtitle => '界面主题与字号等外观设置';

  @override
  String get settingsPageAssistant => '助手';

  @override
  String get settingsPageAssistantSubtitle => '默认助手与对话风格';

  @override
  String get settingsPageModelsServicesSection => '模型与服务';

  @override
  String get settingsPageDefaultModel => '默认模型';

  @override
  String get settingsPageProviders => '供应商';

  @override
  String get settingsPageHotkeys => '快捷键';

  @override
  String get settingsPageSearch => '搜索服务';

  @override
  String get settingsPageTts => '语音服务';

  @override
  String get settingsPageMcp => 'MCP';

  @override
  String get settingsPageQuickPhrase => '快捷短语';

  @override
  String get settingsPageInstructionInjection => '指令注入';

  @override
  String get settingsPageDataSection => '数据设置';

  @override
  String get settingsPageBackup => '数据备份';

  @override
  String get settingsPageChatStorage => '聊天记录存储';

  @override
  String get settingsPageCalculating => '统计中…';

  @override
  String settingsPageFilesCount(int count, String size) {
    return '共 $count 个文件 · $size';
  }

  @override
  String get storageSpacePageTitle => '存储空间';

  @override
  String get storageSpaceRefreshTooltip => '刷新';

  @override
  String get storageSpaceLoadFailed => '加载失败';

  @override
  String get storageSpaceTotalLabel => '已用空间';

  @override
  String storageSpaceClearableLabel(String size) {
    return '可清理：$size';
  }

  @override
  String storageSpaceClearableHint(String size) {
    return '共发现可清理空间 $size';
  }

  @override
  String get storageSpaceCategoryImages => '图片';

  @override
  String get storageSpaceCategoryFiles => '文件';

  @override
  String get storageSpaceCategoryChatData => '聊天记录';

  @override
  String get storageSpaceCategoryAssistantData => '助手';

  @override
  String get storageSpaceCategoryCache => '缓存';

  @override
  String get storageSpaceCategoryLogs => '日志';

  @override
  String get storageSpaceCategoryOther => '应用';

  @override
  String storageSpaceFilesCount(int count) {
    return '$count 个文件';
  }

  @override
  String get storageSpaceSafeToClearHint => '可安全清理，不影响聊天记录。';

  @override
  String get storageSpaceNotSafeToClearHint => '可能影响聊天记录，请谨慎删除。';

  @override
  String get storageSpaceBreakdownTitle => '明细';

  @override
  String get storageSpaceSubChatMessages => '消息';

  @override
  String get storageSpaceSubChatConversations => '会话';

  @override
  String get storageSpaceSubChatToolEvents => '工具事件';

  @override
  String get storageSpaceSubAssistantAvatars => '头像';

  @override
  String get storageSpaceSubAssistantImages => '图片';

  @override
  String get storageSpaceSubCacheAvatars => '头像缓存';

  @override
  String get storageSpaceSubCacheOther => '其他缓存';

  @override
  String get storageSpaceSubCacheSystem => '系统缓存';

  @override
  String get storageSpaceSubLogsFlutter => '运行日志';

  @override
  String get storageSpaceSubLogsRequests => '网络日志';

  @override
  String get storageSpaceSubLogsOther => '其他日志';

  @override
  String get storageSpaceClearConfirmTitle => '确认清理';

  @override
  String storageSpaceClearConfirmMessage(String targetName) {
    return '确定要清理 $targetName 吗？';
  }

  @override
  String get storageSpaceClearButton => '清理';

  @override
  String storageSpaceClearDone(String targetName) {
    return '已清理 $targetName';
  }

  @override
  String storageSpaceClearFailed(String error) {
    return '清理失败：$error';
  }

  @override
  String get storageSpaceClearAvatarCacheButton => '清理头像缓存';

  @override
  String get storageSpaceClearCacheButton => '清理缓存';

  @override
  String get storageSpaceClearLogsButton => '清理日志';

  @override
  String get storageSpaceDeleteConfirmTitle => '确认删除';

  @override
  String storageSpaceDeleteUploadsConfirmMessage(int count) {
    return '删除 $count 个项目？删除后聊天记录中的附件可能无法打开。';
  }

  @override
  String storageSpaceDeletedUploadsDone(int count) {
    return '已删除 $count 个项目';
  }

  @override
  String get storageSpaceNoUploads => '暂无内容';

  @override
  String get storageSpaceSelectAll => '全选';

  @override
  String get storageSpaceClearSelection => '清空选择';

  @override
  String storageSpaceSelectedCount(int count) {
    return '已选 $count 项';
  }

  @override
  String storageSpaceUploadsCount(int count) {
    return '共 $count 项';
  }

  @override
  String get settingsPageAboutSection => '关于';

  @override
  String get settingsPageAbout => '关于';

  @override
  String get settingsPageDocs => '使用文档';

  @override
  String get settingsPageSponsor => '赞助';

  @override
  String get settingsPageShare => '分享';

  @override
  String get sponsorPageMethodsSectionTitle => '赞助方式';

  @override
  String get sponsorPageSponsorsSectionTitle => '赞助用户';

  @override
  String get sponsorPageEmpty => '暂无赞助者';

  @override
  String get sponsorPageAfdianTitle => '爱发电';

  @override
  String get sponsorPageAfdianSubtitle => 'afdian.com/a/kelivo';

  @override
  String get sponsorPageWeChatTitle => '微信赞助';

  @override
  String get sponsorPageWeChatSubtitle => '微信赞助码';

  @override
  String get languageDisplaySimplifiedChinese => '简体中文';

  @override
  String get languageDisplayEnglish => 'English';

  @override
  String get languageDisplayTraditionalChinese => '繁體中文';

  @override
  String get languageDisplayJapanese => '日本語';

  @override
  String get languageDisplayKorean => '한국어';

  @override
  String get languageDisplayFrench => 'Français';

  @override
  String get languageDisplayGerman => 'Deutsch';

  @override
  String get languageDisplayItalian => 'Italiano';

  @override
  String get languageDisplaySpanish => 'Español';

  @override
  String get languageSelectSheetTitle => '选择翻译语言';

  @override
  String get languageSelectSheetClearButton => '清空翻译';

  @override
  String get homePageClearContext => '清空上下文';

  @override
  String homePageClearContextWithCount(String actual, String configured) {
    return '清空上下文 ($actual/$configured)';
  }

  @override
  String get homePageDefaultAssistant => '默认助手';

  @override
  String get mermaidExportPng => '导出 PNG';

  @override
  String get mermaidExportFailed => '导出失败';

  @override
  String get mermaidPreviewOpen => '浏览器预览';

  @override
  String get mermaidPreviewOpenFailed => '无法打开预览';

  @override
  String get assistantProviderDefaultAssistantName => '默认助手';

  @override
  String get assistantProviderSampleAssistantName => '示例助手';

  @override
  String get assistantProviderNewAssistantName => '新助手';

  @override
  String assistantProviderSampleAssistantSystemPrompt(
    String model_name,
    String cur_datetime,
    String locale,
    String timezone,
    String device_info,
    String system_version,
  ) {
    return '你是$model_name, 一个人工智能助手，乐意为用户提供准确，有益的帮助。现在时间是$cur_datetime，用户设备语言为$locale，时区为$timezone，用户正在使用$device_info，版本$system_version。如果用户没有明确说明，请使用用户设备语言进行回复。';
  }

  @override
  String get displaySettingsPageLanguageTitle => '应用语言';

  @override
  String get displaySettingsPageLanguageSubtitle => '选择界面语言';

  @override
  String get assistantTagsManageTitle => '管理标签';

  @override
  String get assistantTagsCreateButton => '创建';

  @override
  String get assistantTagsCreateDialogTitle => '创建标签';

  @override
  String get assistantTagsCreateDialogOk => '创建';

  @override
  String get assistantTagsCreateDialogCancel => '取消';

  @override
  String get assistantTagsNameHint => '标签名称';

  @override
  String get assistantTagsRenameButton => '重命名';

  @override
  String get assistantTagsRenameDialogTitle => '重命名标签';

  @override
  String get assistantTagsRenameDialogOk => '重命名';

  @override
  String get assistantTagsDeleteButton => '删除';

  @override
  String get assistantTagsDeleteConfirmTitle => '删除标签';

  @override
  String get assistantTagsDeleteConfirmContent => '确定要删除该标签吗？';

  @override
  String get assistantTagsDeleteConfirmOk => '删除';

  @override
  String get assistantTagsDeleteConfirmCancel => '取消';

  @override
  String get assistantTagsContextMenuEditAssistant => '编辑助手';

  @override
  String get assistantTagsContextMenuManageTags => '管理标签';

  @override
  String get mcpTransportOptionStdio => 'STDIO';

  @override
  String get mcpTransportTagStdio => 'STDIO';

  @override
  String get mcpTransportTagInmemory => '内置';

  @override
  String get mcpServerEditSheetStdioOnlyDesktop => 'STDIO 仅在桌面端可用';

  @override
  String get mcpServerEditSheetStdioCommandLabel => '命令';

  @override
  String get mcpServerEditSheetStdioArgumentsLabel => '参数';

  @override
  String get mcpServerEditSheetStdioWorkingDirectoryLabel => '工作目录（可选）';

  @override
  String get mcpServerEditSheetStdioEnvironmentTitle => '环境变量';

  @override
  String get mcpServerEditSheetStdioEnvNameLabel => '名称';

  @override
  String get mcpServerEditSheetStdioEnvValueLabel => '值';

  @override
  String get mcpServerEditSheetStdioAddEnv => '添加环境变量';

  @override
  String get mcpServerEditSheetStdioCommandRequired => 'STDIO 需要填写命令';

  @override
  String get assistantTagsContextMenuDeleteAssistant => '删除助手';

  @override
  String get assistantTagsClearTag => '清除标签';

  @override
  String get displaySettingsPageLanguageChineseLabel => '简体中文';

  @override
  String get displaySettingsPageLanguageEnglishLabel => 'English';

  @override
  String get homePagePleaseSelectModel => '请先选择模型';

  @override
  String get homePagePleaseSetupTranslateModel => '请先设置翻译模型';

  @override
  String get homePageTranslating => '翻译中...';

  @override
  String homePageTranslateFailed(String error) {
    return '翻译失败: $error';
  }

  @override
  String get chatServiceDefaultConversationTitle => '新对话';

  @override
  String get userProviderDefaultUserName => '用户';

  @override
  String get homePageDeleteMessage => '删除消息';

  @override
  String get homePageDeleteMessageConfirm => '确定要删除这条消息吗？此操作不可撤销。';

  @override
  String get homePageCancel => '取消';

  @override
  String get homePageDelete => '删除';

  @override
  String get homePageSelectMessagesToShare => '请选择要分享的消息';

  @override
  String get homePageDone => '完成';

  @override
  String get homePageDropToUpload => '将文件拖拽到此处上传';

  @override
  String get assistantEditPageTitle => '助手';

  @override
  String get assistantEditPageNotFound => '助手不存在';

  @override
  String get assistantEditPageBasicTab => '基础设置';

  @override
  String get assistantEditPagePromptsTab => '提示词';

  @override
  String get assistantEditPageMcpTab => 'MCP';

  @override
  String get assistantEditPageQuickPhraseTab => '快捷短语';

  @override
  String get assistantEditPageCustomTab => '自定义请求';

  @override
  String get assistantEditPageRegexTab => '正则替换';

  @override
  String get assistantEditRegexDescription => '为用户/助手消息配置正则规则，可修改或仅调整显示效果。';

  @override
  String get assistantEditAddRegexButton => '添加正则规则';

  @override
  String get assistantRegexAddTitle => '添加正则规则';

  @override
  String get assistantRegexEditTitle => '编辑正则规则';

  @override
  String get assistantRegexNameLabel => '规则名称';

  @override
  String get assistantRegexPatternLabel => '正则表达式';

  @override
  String get assistantRegexReplacementLabel => '替换字符串';

  @override
  String get assistantRegexScopeLabel => '影响范围';

  @override
  String get assistantRegexScopeUser => '用户';

  @override
  String get assistantRegexScopeAssistant => '助手';

  @override
  String get assistantRegexScopeVisualOnly => '仅视觉';

  @override
  String get assistantRegexAddAction => '添加';

  @override
  String get assistantRegexSaveAction => '保存';

  @override
  String get assistantRegexDeleteButton => '删除';

  @override
  String get assistantRegexValidationError => '请填写名称、正则表达式，并至少选择一个范围。';

  @override
  String get assistantRegexInvalidPattern => '正则表达式无效';

  @override
  String get assistantRegexCancelButton => '取消';

  @override
  String get assistantRegexUntitled => '未命名规则';

  @override
  String get assistantEditCustomHeadersTitle => '自定义 Header';

  @override
  String get assistantEditCustomHeadersAdd => '添加 Header';

  @override
  String get assistantEditCustomHeadersEmpty => '未添加 Header';

  @override
  String get assistantEditCustomBodyTitle => '自定义 Body';

  @override
  String get assistantEditCustomBodyAdd => '添加 Body';

  @override
  String get assistantEditCustomBodyEmpty => '未添加 Body 项';

  @override
  String get assistantEditHeaderNameLabel => 'Header 名称';

  @override
  String get assistantEditHeaderValueLabel => 'Header 值';

  @override
  String get assistantEditBodyKeyLabel => 'Body Key';

  @override
  String get assistantEditBodyValueLabel => 'Body 值 (JSON)';

  @override
  String get assistantEditDeleteTooltip => '删除';

  @override
  String get assistantEditAssistantNameLabel => '助手名称';

  @override
  String get assistantEditUseAssistantAvatarTitle => '使用助手头像';

  @override
  String get assistantEditUseAssistantAvatarSubtitle =>
      '在聊天中使用助手头像和名字而不是模型头像和名字';

  @override
  String get assistantEditChatModelTitle => '聊天模型';

  @override
  String get assistantEditChatModelSubtitle => '为该助手设置默认聊天模型（未设置时使用全局默认）';

  @override
  String get assistantEditTemperatureDescription => '控制输出的随机性，范围 0–2';

  @override
  String get assistantEditTopPDescription => '请不要修改此值，除非你知道自己在做什么';

  @override
  String get assistantEditParameterDisabled => '已关闭（使用服务商默认）';

  @override
  String get assistantEditParameterDisabled2 => '已关闭（无限制）';

  @override
  String get assistantEditContextMessagesTitle => '上下文消息数量';

  @override
  String get assistantEditContextMessagesDescription =>
      '多少历史消息会被当作上下文发送给模型，超过数量会忽略，只保留最近 N 条';

  @override
  String get assistantEditStreamOutputTitle => '流式输出';

  @override
  String get assistantEditStreamOutputDescription => '是否启用消息的流式输出';

  @override
  String get assistantEditThinkingBudgetTitle => '思考预算';

  @override
  String get assistantEditConfigureButton => '配置';

  @override
  String get assistantEditMaxTokensTitle => '最大 Token 数';

  @override
  String get assistantEditMaxTokensDescription => '留空表示无限制';

  @override
  String get assistantEditMaxTokensHint => '无限制';

  @override
  String get assistantEditChatBackgroundTitle => '聊天背景';

  @override
  String get assistantEditChatBackgroundDescription => '设置助手聊天页面的背景图片';

  @override
  String get assistantEditChooseImageButton => '选择背景图片';

  @override
  String get assistantEditClearButton => '清除';

  @override
  String get desktopNavChatTooltip => '聊天';

  @override
  String get desktopNavTranslateTooltip => '翻译';

  @override
  String get desktopNavStorageTooltip => '存储';

  @override
  String get desktopNavThemeToggleTooltip => '主题切换';

  @override
  String get desktopNavSettingsTooltip => '设置';

  @override
  String get desktopAvatarMenuUseEmoji => '使用表情符号';

  @override
  String get cameraPermissionDeniedMessage => '未授予相机权限';

  @override
  String get openSystemSettings => '去设置';

  @override
  String get desktopAvatarMenuChangeFromImage => '从图片更换…';

  @override
  String get desktopAvatarMenuReset => '重置头像';

  @override
  String get assistantEditAvatarChooseImage => '选择图片';

  @override
  String get assistantEditAvatarChooseEmoji => '选择表情';

  @override
  String get assistantEditAvatarEnterLink => '输入链接';

  @override
  String get assistantEditAvatarImportQQ => 'QQ头像';

  @override
  String get assistantEditAvatarReset => '重置';

  @override
  String get displaySettingsPageChatMessageBackgroundTitle => '聊天消息背景';

  @override
  String get displaySettingsPageChatMessageBackgroundDefault => '默认';

  @override
  String get displaySettingsPageChatMessageBackgroundFrosted => '模糊';

  @override
  String get displaySettingsPageChatMessageBackgroundSolid => '纯色';

  @override
  String get displaySettingsPageAndroidBackgroundChatTitle => '后台聊天生成';

  @override
  String get androidBackgroundStatusOn => '开启';

  @override
  String get androidBackgroundStatusOff => '关闭';

  @override
  String get androidBackgroundStatusOther => '开启并通知';

  @override
  String get androidBackgroundOptionOn => '开启';

  @override
  String get androidBackgroundOptionOnNotify => '开启并在生成完时发送消息';

  @override
  String get androidBackgroundOptionOff => '关闭';

  @override
  String get notificationChatCompletedTitle => '生成完成';

  @override
  String get notificationChatCompletedBody => '助手回复已生成';

  @override
  String get androidBackgroundNotificationTitle => 'Kelivo 正在运行';

  @override
  String get androidBackgroundNotificationText => '后台保持聊天生成';

  @override
  String get assistantEditEmojiDialogTitle => '选择表情';

  @override
  String get assistantEditEmojiDialogHint => '输入或粘贴任意表情';

  @override
  String get assistantEditEmojiDialogCancel => '取消';

  @override
  String get assistantEditEmojiDialogSave => '保存';

  @override
  String get assistantEditImageUrlDialogTitle => '输入图片链接';

  @override
  String get assistantEditImageUrlDialogHint =>
      '例如: https://example.com/avatar.png';

  @override
  String get assistantEditImageUrlDialogCancel => '取消';

  @override
  String get assistantEditImageUrlDialogSave => '保存';

  @override
  String get assistantEditQQAvatarDialogTitle => '使用QQ头像';

  @override
  String get assistantEditQQAvatarDialogHint => '输入QQ号码（5-12位）';

  @override
  String get assistantEditQQAvatarRandomButton => '随机QQ';

  @override
  String get assistantEditQQAvatarFailedMessage => '获取随机QQ头像失败，请重试';

  @override
  String get assistantEditQQAvatarDialogCancel => '取消';

  @override
  String get assistantEditQQAvatarDialogSave => '保存';

  @override
  String get assistantEditGalleryErrorMessage => '无法打开相册，试试输入图片链接';

  @override
  String get assistantEditGeneralErrorMessage => '发生错误，试试输入图片链接';

  @override
  String get providerDetailPageMultiKeyModeTitle => '多Key模式';

  @override
  String get providerDetailPageManageKeysButton => '多Key管理';

  @override
  String get multiKeyPageTitle => '多Key管理';

  @override
  String get multiKeyPageDetect => '检测';

  @override
  String get multiKeyPageAdd => '添加';

  @override
  String get multiKeyPageAddHint => '请输入API Key（多个用逗号或空格分隔）';

  @override
  String multiKeyPageImportedSnackbar(int n) {
    return '已导入$n个key';
  }

  @override
  String get multiKeyPagePleaseAddModel => '请先添加模型';

  @override
  String get multiKeyPageTotal => '总数';

  @override
  String get multiKeyPageNormal => '正常';

  @override
  String get multiKeyPageError => '错误';

  @override
  String get multiKeyPageAccuracy => '正确率';

  @override
  String get multiKeyPageStrategyTitle => '负载均衡策略';

  @override
  String get multiKeyPageStrategyRoundRobin => '轮询';

  @override
  String get multiKeyPageStrategyPriority => '优先级';

  @override
  String get multiKeyPageStrategyLeastUsed => '最少使用';

  @override
  String get multiKeyPageStrategyRandom => '随机';

  @override
  String get multiKeyPageNoKeys => '暂无Key';

  @override
  String get multiKeyPageStatusActive => '正常';

  @override
  String get multiKeyPageStatusDisabled => '已关闭';

  @override
  String get multiKeyPageStatusError => '错误';

  @override
  String get multiKeyPageStatusRateLimited => '限速';

  @override
  String get multiKeyPageEditAlias => '编辑别名';

  @override
  String get multiKeyPageEdit => '编辑';

  @override
  String get multiKeyPageKey => 'API Key';

  @override
  String get multiKeyPagePriority => '优先级（1–10）';

  @override
  String get multiKeyPageDuplicateKeyWarning => '该 Key 已存在';

  @override
  String get multiKeyPageAlias => '别名';

  @override
  String get multiKeyPageCancel => '取消';

  @override
  String get multiKeyPageSave => '保存';

  @override
  String get multiKeyPageDelete => '删除';

  @override
  String get assistantEditSystemPromptTitle => '系统提示词';

  @override
  String get assistantEditSystemPromptHint => '输入系统提示词…';

  @override
  String get assistantEditSystemPromptImportButton => '从文件导入';

  @override
  String get assistantEditSystemPromptImportSuccess => '已从文件更新系统提示词';

  @override
  String get assistantEditSystemPromptImportFailed => '导入失败';

  @override
  String get assistantEditSystemPromptImportEmpty => '文件内容为空';

  @override
  String get assistantEditAvailableVariables => '可用变量：';

  @override
  String get assistantEditVariableDate => '日期';

  @override
  String get assistantEditVariableTime => '时间';

  @override
  String get assistantEditVariableDatetime => '日期和时间';

  @override
  String get assistantEditVariableModelId => '模型ID';

  @override
  String get assistantEditVariableModelName => '模型名称';

  @override
  String get assistantEditVariableLocale => '语言环境';

  @override
  String get assistantEditVariableTimezone => '时区';

  @override
  String get assistantEditVariableSystemVersion => '系统版本';

  @override
  String get assistantEditVariableDeviceInfo => '设备信息';

  @override
  String get assistantEditVariableBatteryLevel => '电池电量';

  @override
  String get assistantEditVariableNickname => '用户昵称';

  @override
  String get assistantEditVariableAssistantName => '助手名称';

  @override
  String get assistantEditMessageTemplateTitle => '聊天内容模板';

  @override
  String get assistantEditVariableRole => '助手';

  @override
  String get assistantEditVariableMessage => '内容';

  @override
  String get assistantEditPreviewTitle => '预览';

  @override
  String get codeBlockPreviewButton => '预览';

  @override
  String codeBlockCollapsedLines(int n) {
    return '… 已折叠 $n 行';
  }

  @override
  String get htmlPreviewNotSupportedOnLinux => 'Linux 暂不支持 HTML 预览';

  @override
  String get assistantEditSampleUser => '用户';

  @override
  String get assistantEditSampleMessage => '你好啊';

  @override
  String get assistantEditSampleReply => '你好，有什么我可以帮你的吗？';

  @override
  String get assistantEditMcpNoServersMessage => '暂无已启动的 MCP 服务器';

  @override
  String get assistantEditMcpConnectedTag => '已连接';

  @override
  String assistantEditMcpToolsCountTag(String enabled, String total) {
    return '工具: $enabled/$total';
  }

  @override
  String get assistantEditModelUseGlobalDefault => '使用全局默认';

  @override
  String get assistantSettingsPageTitle => '助手设置';

  @override
  String get assistantSettingsDefaultTag => '默认';

  @override
  String get assistantSettingsCopyButton => '复制';

  @override
  String get assistantSettingsCopySuccess => '已复制助手';

  @override
  String get assistantSettingsCopySuffix => '副本';

  @override
  String get assistantSettingsDeleteButton => '删除';

  @override
  String get assistantSettingsEditButton => '编辑';

  @override
  String get assistantSettingsAddSheetTitle => '助手名称';

  @override
  String get assistantSettingsAddSheetHint => '输入助手名称';

  @override
  String get assistantSettingsAddSheetCancel => '取消';

  @override
  String get assistantSettingsAddSheetSave => '保存';

  @override
  String get desktopAssistantsListTitle => '助手列表';

  @override
  String get desktopSidebarTabAssistants => '助手';

  @override
  String get desktopSidebarTabTopics => '话题';

  @override
  String get desktopTrayMenuShowWindow => '显示窗口';

  @override
  String get desktopTrayMenuExit => '退出';

  @override
  String get hotkeyToggleAppVisibility => '显示/隐藏应用';

  @override
  String get hotkeyCloseWindow => '关闭窗口';

  @override
  String get hotkeyOpenSettings => '打开设置';

  @override
  String get hotkeyNewTopic => '新建话题';

  @override
  String get hotkeySwitchModel => '切换模型';

  @override
  String get hotkeyToggleAssistantPanel => '切换助手显示';

  @override
  String get hotkeyToggleTopicPanel => '切换话题显示';

  @override
  String get hotkeysPressShortcut => '按下快捷键';

  @override
  String get hotkeysResetDefault => '重置为默认';

  @override
  String get hotkeysClearShortcut => '清除快捷键';

  @override
  String get hotkeysResetAll => '重置所有快捷键为默认';

  @override
  String get assistantEditTemperatureTitle => '温度';

  @override
  String get assistantEditTopPTitle => 'Top-p';

  @override
  String get assistantSettingsDeleteDialogTitle => '删除助手';

  @override
  String get assistantSettingsDeleteDialogContent => '确定要删除该助手吗？此操作不可撤销。';

  @override
  String get assistantSettingsDeleteDialogCancel => '取消';

  @override
  String get assistantSettingsDeleteDialogConfirm => '删除';

  @override
  String get assistantSettingsAtLeastOneAssistantRequired => '至少需要保留一个助手';

  @override
  String get mcpAssistantSheetTitle => 'MCP服务器';

  @override
  String get mcpAssistantSheetSubtitle => '为该助手启用的服务';

  @override
  String get mcpAssistantSheetSelectAll => '全选';

  @override
  String get mcpAssistantSheetClearAll => '全不选';

  @override
  String get backupPageTitle => '备份与恢复';

  @override
  String get backupPageWebDavTab => 'WebDAV 备份';

  @override
  String get backupPageImportExportTab => '导入和导出';

  @override
  String get backupPageWebDavServerUrl => 'WebDAV 服务器地址';

  @override
  String get backupPageUsername => '用户名';

  @override
  String get backupPagePassword => '密码';

  @override
  String get backupPagePath => '路径';

  @override
  String get backupPageChatsLabel => '聊天记录';

  @override
  String get backupPageFilesLabel => '文件';

  @override
  String get backupPageTestDone => '测试完成';

  @override
  String get backupPageTestConnection => '测试连接';

  @override
  String get backupPageRestartRequired => '需要重启应用';

  @override
  String get backupPageRestartContent => '恢复完成，需要重启以完全生效。';

  @override
  String get backupPageOK => '好的';

  @override
  String get backupPageCancel => '取消';

  @override
  String get backupPageSelectImportMode => '选择导入模式';

  @override
  String get backupPageSelectImportModeDescription => '请选择如何导入备份数据：';

  @override
  String get backupPageOverwriteMode => '完全覆盖';

  @override
  String get backupPageOverwriteModeDescription => '清空本地所有数据后恢复';

  @override
  String get backupPageMergeMode => '智能合并';

  @override
  String get backupPageMergeModeDescription => '仅添加不存在的数据（智能去重）';

  @override
  String get backupPageRestore => '恢复';

  @override
  String get backupPageBackupUploaded => '已上传备份';

  @override
  String get backupPageBackup => '立即备份';

  @override
  String get backupPageExporting => '正在导出...';

  @override
  String get backupPageExportToFile => '导出为文件';

  @override
  String get backupPageExportToFileSubtitle => '导出APP数据为文件';

  @override
  String get backupPageImportBackupFile => '备份文件导入';

  @override
  String get backupPageImportBackupFileSubtitle => '导入本地备份文件';

  @override
  String get backupPageImportFromOtherApps => '从其他APP导入';

  @override
  String get backupPageImportFromRikkaHub => '从 RikkaHub 导入';

  @override
  String get backupPageNotSupportedYet => '暂不支持';

  @override
  String get backupPageRemoteBackups => '远端备份';

  @override
  String get backupPageNoBackups => '暂无备份';

  @override
  String get backupPageRestoreTooltip => '恢复';

  @override
  String get backupPageDeleteTooltip => '删除';

  @override
  String get backupPageBackupManagement => '备份管理';

  @override
  String get backupPageWebDavBackup => 'WebDAV 备份';

  @override
  String get backupPageWebDavServerSettings => 'WebDAV 服务器设置';

  @override
  String get backupPageSave => '保存';

  @override
  String get backupPageBackupNow => '立即备份';

  @override
  String get backupPageLocalBackup => '本地备份';

  @override
  String get backupPageImportFromCherryStudio => '从 Cherry Studio 导入';

  @override
  String get backupPageImportFromChatbox => '从 Chatbox 导入';

  @override
  String get chatHistoryPageTitle => '聊天历史';

  @override
  String get chatHistoryPageSearchTooltip => '搜索';

  @override
  String get chatHistoryPageDeleteAllTooltip => '删除未置顶';

  @override
  String get chatHistoryPageDeleteAllDialogTitle => '删除未置顶对话';

  @override
  String get chatHistoryPageDeleteAllDialogContent =>
      '确定要删除所有未置顶的对话吗？已置顶的将会保留。';

  @override
  String get chatHistoryPageCancel => '取消';

  @override
  String get chatHistoryPageDelete => '删除';

  @override
  String get chatHistoryPageDeletedAllSnackbar => '已删除未置顶的对话';

  @override
  String get chatHistoryPageSearchHint => '搜索对话';

  @override
  String get chatHistoryPageNoConversations => '暂无对话';

  @override
  String get chatHistoryPagePinnedSection => '置顶';

  @override
  String get chatHistoryPagePin => '置顶';

  @override
  String get chatHistoryPagePinned => '已置顶';

  @override
  String get messageEditPageTitle => '编辑消息';

  @override
  String get messageEditPageSave => '保存';

  @override
  String get messageEditPageSaveAndSend => '保存并发送';

  @override
  String get messageEditPageHint => '输入消息内容…';

  @override
  String get selectCopyPageTitle => '选择复制';

  @override
  String get selectCopyPageCopyAll => '复制全部';

  @override
  String get selectCopyPageCopiedAll => '已复制全部';

  @override
  String get bottomToolsSheetCamera => '拍照';

  @override
  String get bottomToolsSheetPhotos => '照片';

  @override
  String get bottomToolsSheetUpload => '上传文件';

  @override
  String get bottomToolsSheetClearContext => '清空上下文';

  @override
  String get bottomToolsSheetLearningMode => '学习模式';

  @override
  String get bottomToolsSheetLearningModeDescription => '帮助你循序渐进地学习知识';

  @override
  String get bottomToolsSheetConfigurePrompt => '设置提示词';

  @override
  String get bottomToolsSheetPrompt => '提示词';

  @override
  String get bottomToolsSheetPromptHint => '输入要注入的提示词内容';

  @override
  String get bottomToolsSheetResetDefault => '重置为默认';

  @override
  String get bottomToolsSheetSave => '保存';

  @override
  String get bottomToolsSheetOcr => 'OCR 文字识别';

  @override
  String get messageMoreSheetTitle => '更多操作';

  @override
  String get messageMoreSheetSelectCopy => '选择复制';

  @override
  String get messageMoreSheetRenderWebView => '网页视图渲染';

  @override
  String get messageMoreSheetNotImplemented => '暂未实现';

  @override
  String get messageMoreSheetEdit => '编辑';

  @override
  String get messageMoreSheetShare => '分享';

  @override
  String get messageMoreSheetCreateBranch => '创建分支';

  @override
  String get messageMoreSheetDelete => '删除';

  @override
  String get reasoningBudgetSheetOff => '关闭';

  @override
  String get reasoningBudgetSheetAuto => '自动';

  @override
  String get reasoningBudgetSheetLight => '轻度推理';

  @override
  String get reasoningBudgetSheetMedium => '中度推理';

  @override
  String get reasoningBudgetSheetHeavy => '重度推理';

  @override
  String get reasoningBudgetSheetTitle => '思维链强度';

  @override
  String reasoningBudgetSheetCurrentLevel(String level) {
    return '当前档位：$level';
  }

  @override
  String get reasoningBudgetSheetOffSubtitle => '关闭推理功能，直接回答';

  @override
  String get reasoningBudgetSheetAutoSubtitle => '由模型自动决定推理级别';

  @override
  String get reasoningBudgetSheetLightSubtitle => '使用少量推理来回答问题';

  @override
  String get reasoningBudgetSheetMediumSubtitle => '使用较多推理来回答问题';

  @override
  String get reasoningBudgetSheetHeavySubtitle => '使用大量推理来回答问题，适合复杂问题';

  @override
  String get reasoningBudgetSheetCustomLabel => '自定义推理预算 (tokens)';

  @override
  String get reasoningBudgetSheetCustomHint => '例如：2048 (-1 自动，0 关闭)';

  @override
  String chatMessageWidgetFileNotFound(String fileName) {
    return '文件不存在: $fileName';
  }

  @override
  String chatMessageWidgetCannotOpenFile(String message) {
    return '无法打开文件: $message';
  }

  @override
  String chatMessageWidgetOpenFileError(String error) {
    return '打开文件失败: $error';
  }

  @override
  String get chatMessageWidgetCopiedToClipboard => '已复制到剪贴板';

  @override
  String get chatMessageWidgetResendTooltip => '重新发送';

  @override
  String get chatMessageWidgetMoreTooltip => '更多';

  @override
  String get chatMessageWidgetThinking => '正在思考...';

  @override
  String get chatMessageWidgetTranslation => '翻译';

  @override
  String get chatMessageWidgetTranslating => '翻译中...';

  @override
  String get chatMessageWidgetCitationNotFound => '未找到引用来源';

  @override
  String chatMessageWidgetCannotOpenUrl(String url) {
    return '无法打开链接: $url';
  }

  @override
  String get chatMessageWidgetOpenLinkError => '打开链接失败';

  @override
  String chatMessageWidgetCitationsTitle(int count) {
    return '引用（共$count条）';
  }

  @override
  String get chatMessageWidgetRegenerateTooltip => '重新生成';

  @override
  String get chatMessageWidgetStopTooltip => '停止';

  @override
  String get chatMessageWidgetSpeakTooltip => '朗读';

  @override
  String get chatMessageWidgetTranslateTooltip => '翻译';

  @override
  String get chatMessageWidgetBuiltinSearchHideNote => '隐藏内置搜索工具卡片';

  @override
  String get chatMessageWidgetDeepThinking => '深度思考';

  @override
  String get chatMessageWidgetCreateMemory => '创建记忆';

  @override
  String get chatMessageWidgetEditMemory => '编辑记忆';

  @override
  String get chatMessageWidgetDeleteMemory => '删除记忆';

  @override
  String chatMessageWidgetWebSearch(String query) {
    return '联网检索: $query';
  }

  @override
  String get chatMessageWidgetBuiltinSearch => '模型内置搜索';

  @override
  String chatMessageWidgetToolCall(String name) {
    return '调用工具: $name';
  }

  @override
  String chatMessageWidgetToolResult(String name) {
    return '调用工具: $name';
  }

  @override
  String get chatMessageWidgetNoResultYet => '（暂无结果）';

  @override
  String get chatMessageWidgetArguments => '参数';

  @override
  String get chatMessageWidgetResult => '结果';

  @override
  String chatMessageWidgetCitationsCount(int count) {
    return '共$count条引用';
  }

  @override
  String get messageExportSheetAssistant => '助手';

  @override
  String get messageExportSheetDefaultTitle => '新对话';

  @override
  String get messageExportSheetExporting => '正在导出…';

  @override
  String messageExportSheetExportFailed(String error) {
    return '导出失败: $error';
  }

  @override
  String messageExportSheetExportedAs(String filename) {
    return '已导出为 $filename';
  }

  @override
  String get displaySettingsPageEnableDollarLatexTitle => '启用 \$...\$ 渲染';

  @override
  String get displaySettingsPageEnableDollarLatexSubtitle =>
      '将 \$...\$ 之间的内容按行内数学公式渲染';

  @override
  String get displaySettingsPageEnableMathTitle => '启用数学公式渲染';

  @override
  String get displaySettingsPageEnableMathSubtitle => '渲染 LaTeX 数学公式（行内与块级）';

  @override
  String get displaySettingsPageEnableUserMarkdownTitle => '用户消息 Markdown 渲染';

  @override
  String get displaySettingsPageEnableReasoningMarkdownTitle =>
      '思维链 Markdown 渲染';

  @override
  String get displaySettingsPageMobileCodeBlockWrapTitle => '移动端代码块自动换行';

  @override
  String get displaySettingsPageAutoCollapseCodeBlockTitle => '自动折叠代码块';

  @override
  String get displaySettingsPageAutoCollapseCodeBlockLinesTitle => '超过多少行自动折叠';

  @override
  String get displaySettingsPageAutoCollapseCodeBlockLinesUnit => '行';

  @override
  String get messageExportSheetFormatTitle => '导出格式';

  @override
  String get messageExportSheetMarkdown => 'Markdown';

  @override
  String get messageExportSheetSingleMarkdownSubtitle => '将该消息导出为 Markdown 文件';

  @override
  String get messageExportSheetBatchMarkdownSubtitle => '将选中的消息导出为 Markdown 文件';

  @override
  String get messageExportSheetPlainText => '纯文本';

  @override
  String get messageExportSheetSingleTxtSubtitle => '将该消息导出为 TXT 文件';

  @override
  String get messageExportSheetBatchTxtSubtitle => '将选中的消息导出为 TXT 文件';

  @override
  String get messageExportSheetExportImage => '导出为图片';

  @override
  String get messageExportSheetSingleExportImageSubtitle => '将该消息渲染为 PNG 图片';

  @override
  String get messageExportSheetBatchExportImageSubtitle => '将选中的消息渲染为 PNG 图片';

  @override
  String get messageExportSheetShowThinkingAndToolCards => '显示思考卡片和工具卡片';

  @override
  String get messageExportSheetShowThinkingContent => '显示思考内容';

  @override
  String get messageExportSheetDateTimeWithSecondsPattern =>
      'yyyy年M月d日 HH:mm:ss';

  @override
  String get exportDisclaimerAiGenerated => '内容由 AI 生成，请仔细甄别';

  @override
  String get imagePreviewSheetSaveImage => '保存图片';

  @override
  String get imagePreviewSheetSaveSuccess => '已保存到相册';

  @override
  String imagePreviewSheetSaveFailed(String error) {
    return '保存失败: $error';
  }

  @override
  String get sideDrawerMenuRename => '重命名';

  @override
  String get sideDrawerMenuPin => '置顶';

  @override
  String get sideDrawerMenuUnpin => '取消置顶';

  @override
  String get sideDrawerMenuRegenerateTitle => '重新生成标题';

  @override
  String get sideDrawerMenuMoveTo => '移动到';

  @override
  String get sideDrawerMenuDelete => '删除';

  @override
  String sideDrawerDeleteSnackbar(String title) {
    return '已删除“$title”';
  }

  @override
  String get sideDrawerRenameHint => '输入新名称';

  @override
  String get sideDrawerCancel => '取消';

  @override
  String get sideDrawerOK => '确定';

  @override
  String get sideDrawerSave => '保存';

  @override
  String get sideDrawerGreetingMorning => '早上好 👋';

  @override
  String get sideDrawerGreetingNoon => '中午好 👋';

  @override
  String get sideDrawerGreetingAfternoon => '下午好 👋';

  @override
  String get sideDrawerGreetingEvening => '晚上好 👋';

  @override
  String get sideDrawerDateToday => '今天';

  @override
  String get sideDrawerDateYesterday => '昨天';

  @override
  String get sideDrawerDateShortPattern => 'M月d日';

  @override
  String get sideDrawerDateFullPattern => 'yyyy年M月d日';

  @override
  String get sideDrawerSearchHint => '搜索聊天记录';

  @override
  String get sideDrawerSearchAssistantsHint => '搜索助手';

  @override
  String sideDrawerUpdateTitle(String version) {
    return '发现新版本：$version';
  }

  @override
  String sideDrawerUpdateTitleWithBuild(String version, int build) {
    return '发现新版本：$version ($build)';
  }

  @override
  String get sideDrawerLinkCopied => '已复制下载链接';

  @override
  String get sideDrawerPinnedLabel => '置顶';

  @override
  String get sideDrawerHistory => '聊天历史';

  @override
  String get sideDrawerSettings => '设置';

  @override
  String get sideDrawerChooseAssistantTitle => '选择助手';

  @override
  String get sideDrawerChooseImage => '选择图片';

  @override
  String get sideDrawerChooseEmoji => '选择表情';

  @override
  String get sideDrawerEnterLink => '输入链接';

  @override
  String get sideDrawerImportFromQQ => 'QQ头像';

  @override
  String get sideDrawerReset => '重置';

  @override
  String get sideDrawerEmojiDialogTitle => '选择表情';

  @override
  String get sideDrawerEmojiDialogHint => '输入或粘贴任意表情';

  @override
  String get sideDrawerImageUrlDialogTitle => '输入图片链接';

  @override
  String get sideDrawerImageUrlDialogHint =>
      '例如: https://example.com/avatar.png';

  @override
  String get sideDrawerQQAvatarDialogTitle => '使用QQ头像';

  @override
  String get sideDrawerQQAvatarInputHint => '输入QQ号码（5-12位）';

  @override
  String get sideDrawerQQAvatarFetchFailed => '获取随机QQ头像失败，请重试';

  @override
  String get sideDrawerRandomQQ => '随机QQ';

  @override
  String get sideDrawerGalleryOpenError => '无法打开相册，试试输入图片链接';

  @override
  String get sideDrawerGeneralImageError => '发生错误，试试输入图片链接';

  @override
  String get sideDrawerSetNicknameTitle => '设置昵称';

  @override
  String get sideDrawerNicknameLabel => '昵称';

  @override
  String get sideDrawerNicknameHint => '输入新的昵称';

  @override
  String get sideDrawerRename => '重命名';

  @override
  String get chatInputBarHint => '输入消息与AI聊天';

  @override
  String get chatInputBarSelectModelTooltip => '选择模型';

  @override
  String get chatInputBarOnlineSearchTooltip => '联网搜索';

  @override
  String get chatInputBarReasoningStrengthTooltip => '思维链强度';

  @override
  String get chatInputBarMcpServersTooltip => 'MCP服务器';

  @override
  String get chatInputBarMoreTooltip => '更多';

  @override
  String get chatInputBarInsertNewline => '换行';

  @override
  String get chatInputBarExpand => '展开';

  @override
  String get chatInputBarCollapse => '收起';

  @override
  String get mcpPageBackTooltip => '返回';

  @override
  String get mcpPageAddMcpTooltip => '添加 MCP';

  @override
  String get mcpPageNoServers => '暂无 MCP 服务器';

  @override
  String get mcpPageErrorDialogTitle => '连接错误';

  @override
  String get mcpPageErrorNoDetails => '未提供错误详情';

  @override
  String get mcpPageClose => '关闭';

  @override
  String get mcpPageReconnect => '重新连接';

  @override
  String get mcpPageStatusConnected => '已连接';

  @override
  String get mcpPageStatusConnecting => '连接中…';

  @override
  String get mcpPageStatusDisconnected => '未连接';

  @override
  String get mcpPageStatusDisabled => '已禁用';

  @override
  String mcpPageToolsCount(int enabled, int total) {
    return '工具: $enabled/$total';
  }

  @override
  String get mcpPageConnectionFailed => '连接失败';

  @override
  String get mcpPageDetails => '详情';

  @override
  String get mcpPageDelete => '删除';

  @override
  String get mcpPageConfirmDeleteTitle => '确认删除';

  @override
  String get mcpPageConfirmDeleteContent => '删除后可通过撤销恢复。是否删除？';

  @override
  String get mcpPageServerDeleted => '已删除服务器';

  @override
  String get mcpPageUndo => '撤销';

  @override
  String get mcpPageCancel => '取消';

  @override
  String get mcpConversationSheetTitle => 'MCP服务器';

  @override
  String get mcpConversationSheetSubtitle => '选择在此助手中启用的服务';

  @override
  String get mcpConversationSheetSelectAll => '全选';

  @override
  String get mcpConversationSheetClearAll => '全不选';

  @override
  String get mcpConversationSheetNoRunning => '暂无已启动的 MCP 服务器';

  @override
  String get mcpConversationSheetConnected => '已连接';

  @override
  String mcpConversationSheetToolsCount(int enabled, int total) {
    return '工具: $enabled/$total';
  }

  @override
  String get mcpServerEditSheetEnabledLabel => '是否启用';

  @override
  String get mcpServerEditSheetNameLabel => '名称';

  @override
  String get mcpServerEditSheetTransportLabel => '传输类型';

  @override
  String get mcpServerEditSheetSseRetryHint => '如果SSE连接失败，请多试几次';

  @override
  String get mcpServerEditSheetUrlLabel => '服务器地址';

  @override
  String get mcpServerEditSheetCustomHeadersTitle => '自定义请求头';

  @override
  String get mcpServerEditSheetHeaderNameLabel => '请求头名称';

  @override
  String get mcpServerEditSheetHeaderNameHint => '如 Authorization';

  @override
  String get mcpServerEditSheetHeaderValueLabel => '请求头值';

  @override
  String get mcpServerEditSheetHeaderValueHint => '如 Bearer xxxxxx';

  @override
  String get mcpServerEditSheetRemoveHeaderTooltip => '删除';

  @override
  String get mcpServerEditSheetAddHeader => '添加请求头';

  @override
  String get mcpServerEditSheetTitleEdit => '编辑 MCP';

  @override
  String get mcpServerEditSheetTitleAdd => '添加 MCP';

  @override
  String get mcpServerEditSheetSyncToolsTooltip => '同步工具';

  @override
  String get mcpServerEditSheetTabBasic => '基础设置';

  @override
  String get mcpServerEditSheetTabTools => '工具';

  @override
  String get mcpServerEditSheetNoToolsHint => '暂无工具，点击上方同步';

  @override
  String get mcpServerEditSheetCancel => '取消';

  @override
  String get mcpServerEditSheetSave => '保存';

  @override
  String get mcpServerEditSheetUrlRequired => '请输入服务器地址';

  @override
  String get defaultModelPageBackTooltip => '返回';

  @override
  String get defaultModelPageTitle => '默认模型';

  @override
  String get defaultModelPageChatModelTitle => '聊天模型';

  @override
  String get defaultModelPageChatModelSubtitle => '全局默认的聊天模型';

  @override
  String get defaultModelPageTitleModelTitle => '标题总结模型';

  @override
  String get defaultModelPageTitleModelSubtitle => '用于总结对话标题的模型，推荐使用快速且便宜的模型';

  @override
  String get defaultModelPageSummaryModelTitle => '摘要模型';

  @override
  String get defaultModelPageSummaryModelSubtitle => '用于生成对话摘要的模型，推荐使用快速且便宜的模型';

  @override
  String get defaultModelPageTranslateModelTitle => '翻译模型';

  @override
  String get defaultModelPageTranslateModelSubtitle =>
      '用于翻译消息内容的模型，推荐使用快速且准确的模型';

  @override
  String get defaultModelPageOcrModelTitle => 'OCR 模型';

  @override
  String get defaultModelPageOcrModelSubtitle => '用于对图片执行文字识别的模型';

  @override
  String get defaultModelPagePromptLabel => '提示词';

  @override
  String get defaultModelPageTitlePromptHint => '输入用于标题总结的提示词模板';

  @override
  String get defaultModelPageSummaryPromptHint => '输入用于生成摘要的提示词模板';

  @override
  String get defaultModelPageTranslatePromptHint => '输入用于翻译的提示词模板';

  @override
  String get defaultModelPageOcrPromptHint => '输入用于 OCR 识别的提示词模板';

  @override
  String get defaultModelPageResetDefault => '重置为默认';

  @override
  String get defaultModelPageSave => '保存';

  @override
  String defaultModelPageTitleVars(String contentVar, String localeVar) {
    return '变量: 对话内容: $contentVar, 语言: $localeVar';
  }

  @override
  String defaultModelPageSummaryVars(
    String previousSummaryVar,
    String userMessagesVar,
  ) {
    return '变量：旧摘要：$previousSummaryVar，新消息：$userMessagesVar';
  }

  @override
  String defaultModelPageTranslateVars(String sourceVar, String targetVar) {
    return '变量：原始文本：$sourceVar，目标语言：$targetVar';
  }

  @override
  String get defaultModelPageUseCurrentModel => '使用当前对话模型';

  @override
  String get translatePagePasteButton => '粘贴';

  @override
  String get translatePageCopyResult => '复制结果';

  @override
  String get translatePageClearAll => '清空全部';

  @override
  String get translatePageInputHint => '输入要翻译的内容…';

  @override
  String get translatePageOutputHint => '翻译结果会显示在这里…';

  @override
  String get modelDetailSheetAddModel => '添加模型';

  @override
  String get modelDetailSheetEditModel => '编辑模型';

  @override
  String get modelDetailSheetBasicTab => '基本设置';

  @override
  String get modelDetailSheetAdvancedTab => '高级设置';

  @override
  String get modelDetailSheetBuiltinToolsTab => '内置工具';

  @override
  String get modelDetailSheetModelIdLabel => '模型 ID';

  @override
  String get modelDetailSheetModelIdHint => '必填，建议小写字母、数字、连字符';

  @override
  String modelDetailSheetModelIdDisabledHint(String modelId) {
    return '$modelId';
  }

  @override
  String get modelDetailSheetModelNameLabel => '模型名称';

  @override
  String get modelDetailSheetModelTypeLabel => '模型类型';

  @override
  String get modelDetailSheetChatType => '聊天';

  @override
  String get modelDetailSheetEmbeddingType => '嵌入';

  @override
  String get modelDetailSheetInputModesLabel => '输入模式';

  @override
  String get modelDetailSheetOutputModesLabel => '输出模式';

  @override
  String get modelDetailSheetAbilitiesLabel => '能力';

  @override
  String get modelDetailSheetTextMode => '文本';

  @override
  String get modelDetailSheetImageMode => '图片';

  @override
  String get modelDetailSheetToolsAbility => '工具';

  @override
  String get modelDetailSheetReasoningAbility => '推理';

  @override
  String get modelDetailSheetProviderOverrideDescription =>
      '供应商重写：允许为特定模型自定义供应商设置。（暂未实现）';

  @override
  String get modelDetailSheetAddProviderOverride => '添加供应商重写';

  @override
  String get modelDetailSheetCustomHeadersTitle => '自定义 Headers';

  @override
  String get modelDetailSheetAddHeader => '添加 Header';

  @override
  String get modelDetailSheetCustomBodyTitle => '自定义 Body';

  @override
  String get modelFetchInvertTooltip => '反选';

  @override
  String get modelDetailSheetAddBody => '添加 Body';

  @override
  String get modelDetailSheetBuiltinToolsDescription => '内置工具仅支持官方 API。';

  @override
  String get modelDetailSheetGeminiCodeExecutionMutuallyExclusiveHint =>
      '代码执行无法与搜索/URL 上下文/MCP 工具共存。';

  @override
  String get modelDetailSheetBuiltinToolsUnsupportedHint => '当前供应商不支持这些内置工具。';

  @override
  String get modelDetailSheetSearchTool => '搜索';

  @override
  String get modelDetailSheetSearchToolDescription => '启用 Google 搜索集成';

  @override
  String get modelDetailSheetUrlContextTool => 'URL 上下文';

  @override
  String get modelDetailSheetUrlContextToolDescription => '启用 URL 内容处理';

  @override
  String get modelDetailSheetCodeExecutionTool => '代码执行';

  @override
  String get modelDetailSheetCodeExecutionToolDescription => '启用代码执行工具';

  @override
  String get modelDetailSheetYoutubeTool => 'YouTube';

  @override
  String get modelDetailSheetYoutubeToolDescription =>
      '启用 YouTube 链接读取（自动识别提示词中的链接）';

  @override
  String get modelDetailSheetOpenaiBuiltinToolsResponsesOnlyHint =>
      '需要启用 OpenAI Responses API。';

  @override
  String get modelDetailSheetOpenaiCodeInterpreterTool => '代码解释器';

  @override
  String get modelDetailSheetOpenaiCodeInterpreterToolDescription =>
      '启用代码解释器工具（容器自动，内存上限 4g）';

  @override
  String get modelDetailSheetOpenaiImageGenerationTool => '图像生成';

  @override
  String get modelDetailSheetOpenaiImageGenerationToolDescription => '启用图像生成工具';

  @override
  String get modelDetailSheetCancelButton => '取消';

  @override
  String get modelDetailSheetAddButton => '添加';

  @override
  String get modelDetailSheetConfirmButton => '确认';

  @override
  String get modelDetailSheetInvalidIdError => '请输入有效的模型 ID（不少于2个字符）';

  @override
  String get modelDetailSheetModelIdExistsError => '模型 ID 已存在';

  @override
  String get modelDetailSheetHeaderKeyHint => 'Header Key';

  @override
  String get modelDetailSheetHeaderValueHint => 'Header Value';

  @override
  String get modelDetailSheetBodyKeyHint => 'Body Key';

  @override
  String get modelDetailSheetBodyJsonHint => 'Body JSON';

  @override
  String get modelSelectSheetSearchHint => '搜索模型或服务商';

  @override
  String get modelSelectSheetFavoritesSection => '收藏';

  @override
  String get modelSelectSheetFavoriteTooltip => '收藏';

  @override
  String get modelSelectSheetChatType => '聊天';

  @override
  String get modelSelectSheetEmbeddingType => '嵌入';

  @override
  String get providerDetailPageShareTooltip => '分享';

  @override
  String get providerDetailPageDeleteProviderTooltip => '删除供应商';

  @override
  String get providerDetailPageDeleteProviderTitle => '删除供应商';

  @override
  String get providerDetailPageDeleteProviderContent => '确定要删除该供应商吗？此操作不可撤销。';

  @override
  String get providerDetailPageCancelButton => '取消';

  @override
  String get providerDetailPageDeleteButton => '删除';

  @override
  String get providerDetailPageProviderDeletedSnackbar => '已删除供应商';

  @override
  String get providerDetailPageConfigTab => '配置';

  @override
  String get providerDetailPageModelsTab => '模型';

  @override
  String get providerDetailPageNetworkTab => '网络代理';

  @override
  String get providerDetailPageEnabledTitle => '是否启用';

  @override
  String get providerDetailPageManageSectionTitle => '管理';

  @override
  String get providerDetailPageNameLabel => '名称';

  @override
  String get providerDetailPageApiKeyHint => '留空则使用上层默认';

  @override
  String get providerDetailPageHideTooltip => '隐藏';

  @override
  String get providerDetailPageShowTooltip => '显示';

  @override
  String get providerDetailPageApiPathLabel => 'API 路径';

  @override
  String get providerDetailPageResponseApiTitle => 'Response API (/responses)';

  @override
  String get providerDetailPageAihubmixAppCodeLabel => '应用 Code（享 10% 优惠）';

  @override
  String get providerDetailPageAihubmixAppCodeHelp =>
      '为请求附加 APP-Code，可享 10% 优惠，仅对 AIhubmix 生效。';

  @override
  String get providerDetailPageVertexAiTitle => 'Vertex AI';

  @override
  String get providerDetailPageLocationLabel => '区域 Location';

  @override
  String get providerDetailPageProjectIdLabel => '项目 ID';

  @override
  String get providerDetailPageServiceAccountJsonLabel => '服务账号 JSON（粘贴或导入）';

  @override
  String get providerDetailPageImportJsonButton => '导入 JSON';

  @override
  String get providerDetailPageTestButton => '测试';

  @override
  String get providerDetailPageSaveButton => '保存';

  @override
  String get providerDetailPageProviderRemovedMessage => '供应商已删除';

  @override
  String get providerDetailPageNoModelsTitle => '暂无模型';

  @override
  String get providerDetailPageNoModelsSubtitle => '点击下方按钮添加模型';

  @override
  String get providerDetailPageDeleteModelButton => '删除';

  @override
  String get providerDetailPageConfirmDeleteTitle => '确认删除';

  @override
  String get providerDetailPageConfirmDeleteContent => '删除后可通过撤销恢复。是否删除？';

  @override
  String get providerDetailPageModelDeletedSnackbar => '已删除模型';

  @override
  String get providerDetailPageUndoButton => '撤销';

  @override
  String get providerDetailPageAddNewModelButton => '添加新模型';

  @override
  String get providerDetailPageFetchModelsButton => '获取';

  @override
  String get providerDetailPageEnableProxyTitle => '是否启用代理';

  @override
  String get providerDetailPageHostLabel => '主机地址';

  @override
  String get providerDetailPagePortLabel => '端口';

  @override
  String get providerDetailPageUsernameOptionalLabel => '用户名（可选）';

  @override
  String get providerDetailPagePasswordOptionalLabel => '密码（可选）';

  @override
  String get providerDetailPageSavedSnackbar => '已保存';

  @override
  String get providerDetailPageEmbeddingsGroupTitle => '嵌入';

  @override
  String get providerDetailPageOtherModelsGroupTitle => '其他模型';

  @override
  String get providerGroupLabel => '分组';

  @override
  String get providerGroupAuto => '自动';

  @override
  String get providerGroupOfficial => '官方';

  @override
  String get providerGroupSelfHosted => '自建';

  @override
  String get providerGroupLocal => '本地';

  @override
  String get providerGroupPublic => '公益站';

  @override
  String get providerDetailPageRemoveGroupTooltip => '移除本组';

  @override
  String get providerDetailPageAddGroupTooltip => '添加本组';

  @override
  String get providerDetailPageFilterHint => '输入模型名称筛选';

  @override
  String get providerDetailPageDeleteText => '删除';

  @override
  String get providerDetailPageEditTooltip => '编辑';

  @override
  String get providerDetailPageTestConnectionTitle => '测试连接';

  @override
  String get providerDetailPageSelectModelButton => '选择模型';

  @override
  String get providerDetailPageChangeButton => '更换';

  @override
  String get providerDetailPageUseStreamingLabel => '使用流式';

  @override
  String get providerDetailPageTestingMessage => '正在测试…';

  @override
  String get providerDetailPageTestSuccessMessage => '测试成功';

  @override
  String get providersPageTitle => '供应商';

  @override
  String get providersPageImportTooltip => '导入';

  @override
  String get providersPageAddTooltip => '新增';

  @override
  String get providersPageProviderAddedSnackbar => '已添加供应商';

  @override
  String get providersPageSiliconFlowName => '硅基流动';

  @override
  String get providersPageAliyunName => '阿里云千问';

  @override
  String get providersPageZhipuName => '智谱';

  @override
  String get providersPageByteDanceName => '火山引擎';

  @override
  String get providersPageEnabledStatus => '启用';

  @override
  String get providersPageDisabledStatus => '禁用';

  @override
  String get providersPageModelsCountSuffix => ' models';

  @override
  String get providersPageModelsCountSingleSuffix => '个模型';

  @override
  String get addProviderSheetTitle => '添加供应商';

  @override
  String get addProviderSheetEnabledLabel => '是否启用';

  @override
  String get addProviderSheetNameLabel => '名称';

  @override
  String get addProviderSheetApiPathLabel => 'API 路径';

  @override
  String get addProviderSheetVertexAiLocationLabel => '位置';

  @override
  String get addProviderSheetVertexAiProjectIdLabel => '项目ID';

  @override
  String get addProviderSheetVertexAiServiceAccountJsonLabel =>
      '服务账号 JSON（粘贴或导入）';

  @override
  String get addProviderSheetImportJsonButton => '导入 JSON';

  @override
  String get addProviderSheetCancelButton => '取消';

  @override
  String get addProviderSheetAddButton => '添加';

  @override
  String get importProviderSheetTitle => '导入供应商';

  @override
  String get importProviderSheetScanQrTooltip => '扫码导入';

  @override
  String get importProviderSheetFromGalleryTooltip => '从相册导入';

  @override
  String importProviderSheetImportSuccessMessage(int count) {
    return '已导入$count个供应商';
  }

  @override
  String importProviderSheetImportFailedMessage(String error) {
    return '导入失败: $error';
  }

  @override
  String get importProviderSheetDescription =>
      '粘贴分享字符串（可多行，每行一个）或 ChatBox JSON';

  @override
  String get importProviderSheetInputHint => 'ai-provider:v1:...';

  @override
  String get importProviderSheetCancelButton => '取消';

  @override
  String get importProviderSheetImportButton => '导入';

  @override
  String get shareProviderSheetTitle => '分享供应商配置';

  @override
  String get shareProviderSheetDescription => '复制下面的分享字符串，或使用二维码分享。';

  @override
  String get shareProviderSheetCopiedMessage => '已复制';

  @override
  String get shareProviderSheetCopyButton => '复制';

  @override
  String get shareProviderSheetShareButton => '分享';

  @override
  String get desktopProviderContextMenuShare => '分享';

  @override
  String get desktopProviderShareCopyText => '复制文字';

  @override
  String get desktopProviderShareCopyQr => '复制二维码';

  @override
  String get providerDetailPageApiBaseUrlLabel => 'API Base URL';

  @override
  String get providerDetailPageModelsTitle => '模型';

  @override
  String get providerModelsGetButton => '获取';

  @override
  String get providerDetailPageCapsVision => '视觉';

  @override
  String get providerDetailPageCapsImage => '生图';

  @override
  String get providerDetailPageCapsTool => '工具';

  @override
  String get providerDetailPageCapsReasoning => '推理';

  @override
  String get qrScanPageTitle => '扫码导入';

  @override
  String get qrScanPageInstruction => '将二维码对准取景框';

  @override
  String get searchServicesPageBackTooltip => '返回';

  @override
  String get searchServicesPageTitle => '搜索服务';

  @override
  String get searchServicesPageDone => '完成';

  @override
  String get searchServicesPageEdit => '编辑';

  @override
  String get searchServicesPageAddProvider => '添加提供商';

  @override
  String get searchServicesPageSearchProviders => '搜索提供商';

  @override
  String get searchServicesPageGeneralOptions => '通用选项';

  @override
  String get searchServicesPageAutoTestTitle => '启动时自动测试连接';

  @override
  String get searchServicesPageMaxResults => '最大结果数';

  @override
  String get searchServicesPageTimeoutSeconds => '超时时间（秒）';

  @override
  String get searchServicesPageAtLeastOneServiceRequired => '至少需要一个搜索服务';

  @override
  String get searchServicesPageTestingStatus => '测试中…';

  @override
  String get searchServicesPageConnectedStatus => '已连接';

  @override
  String get searchServicesPageFailedStatus => '连接失败';

  @override
  String get searchServicesPageNotTestedStatus => '未测试';

  @override
  String get searchServicesPageEditServiceTooltip => '编辑服务';

  @override
  String get searchServicesPageTestConnectionTooltip => '测试连接';

  @override
  String get searchServicesPageDeleteServiceTooltip => '删除服务';

  @override
  String get searchServicesPageConfiguredStatus => '已配置';

  @override
  String get miniMapTitle => '迷你地图';

  @override
  String get miniMapTooltip => '迷你地图';

  @override
  String get searchServicesPageApiKeyRequiredStatus => '需要 API Key';

  @override
  String get searchServicesPageUrlRequiredStatus => '需要 URL';

  @override
  String get searchServicesAddDialogTitle => '添加搜索服务';

  @override
  String get searchServicesAddDialogServiceType => '服务类型';

  @override
  String get searchServicesAddDialogBingLocal => '本地';

  @override
  String get searchServicesAddDialogCancel => '取消';

  @override
  String get searchServicesAddDialogAdd => '添加';

  @override
  String get searchServicesAddDialogApiKeyRequired => 'API Key 必填';

  @override
  String get searchServicesAddDialogInstanceUrl => '实例 URL';

  @override
  String get searchServicesAddDialogUrlRequired => 'URL 必填';

  @override
  String get searchServicesAddDialogEnginesOptional => '搜索引擎（可选）';

  @override
  String get searchServicesAddDialogLanguageOptional => '语言（可选）';

  @override
  String get searchServicesAddDialogUsernameOptional => '用户名（可选）';

  @override
  String get searchServicesAddDialogPasswordOptional => '密码（可选）';

  @override
  String get searchServicesAddDialogRegionOptional => '地区（可选，默认 us-en）';

  @override
  String get searchServicesEditDialogEdit => '编辑';

  @override
  String get searchServicesEditDialogCancel => '取消';

  @override
  String get searchServicesEditDialogSave => '保存';

  @override
  String get searchServicesEditDialogBingLocalNoConfig => 'Bing 本地搜索不需要配置。';

  @override
  String get searchServicesEditDialogApiKeyRequired => 'API Key 必填';

  @override
  String get searchServicesEditDialogInstanceUrl => '实例 URL';

  @override
  String get searchServicesEditDialogUrlRequired => 'URL 必填';

  @override
  String get searchServicesEditDialogEnginesOptional => '搜索引擎（可选）';

  @override
  String get searchServicesEditDialogLanguageOptional => '语言（可选）';

  @override
  String get searchServicesEditDialogUsernameOptional => '用户名（可选）';

  @override
  String get searchServicesEditDialogPasswordOptional => '密码（可选）';

  @override
  String get searchServicesEditDialogRegionOptional => '地区（可选，默认 us-en）';

  @override
  String get searchSettingsSheetTitle => '搜索设置';

  @override
  String get searchSettingsSheetBuiltinSearchTitle => '模型内置搜索';

  @override
  String get searchSettingsSheetBuiltinSearchDescription => '是否启用模型内置的搜索功能';

  @override
  String get searchSettingsSheetWebSearchTitle => '网络搜索';

  @override
  String get searchSettingsSheetWebSearchDescription => '是否启用网页搜索';

  @override
  String get searchSettingsSheetOpenSearchServicesTooltip => '打开搜索服务设置';

  @override
  String get searchSettingsSheetNoServicesMessage => '暂无可用服务，请先在\"搜索服务\"中添加';

  @override
  String get aboutPageEasterEggMessage => '\n（好吧现在还没彩蛋）';

  @override
  String get aboutPageEasterEggButton => '好的';

  @override
  String get aboutPageAppDescription => '开源AI 助手';

  @override
  String get aboutPageNoQQGroup => '暂无QQ群';

  @override
  String get aboutPageVersion => '版本';

  @override
  String get aboutPageSystem => '系统';

  @override
  String get aboutPageWebsite => '官网';

  @override
  String get aboutPageLicense => '许可证';

  @override
  String get aboutPageJoinQQGroup => '加入QQ群';

  @override
  String get aboutPageJoinDiscord => '在 Discord 中加入我们';

  @override
  String get displaySettingsPageShowUserAvatarTitle => '显示用户头像';

  @override
  String get displaySettingsPageShowUserAvatarSubtitle => '是否在聊天消息中显示用户头像';

  @override
  String get displaySettingsPageShowUserNameTimestampTitle => '显示用户名称和时间戳';

  @override
  String get displaySettingsPageShowUserNameTimestampSubtitle =>
      '是否在聊天消息中显示用户名称和时间戳';

  @override
  String get displaySettingsPageShowUserMessageActionsTitle => '显示用户消息操作按钮';

  @override
  String get displaySettingsPageShowUserMessageActionsSubtitle =>
      '在用户消息下方显示复制、重发与更多按钮';

  @override
  String get displaySettingsPageShowModelNameTimestampTitle => '显示模型名称和时间戳';

  @override
  String get displaySettingsPageShowModelNameTimestampSubtitle =>
      '是否在聊天消息中显示模型名称和时间戳';

  @override
  String get displaySettingsPageChatModelIconTitle => '聊天列表模型图标';

  @override
  String get displaySettingsPageChatModelIconSubtitle => '是否在聊天消息中显示模型图标';

  @override
  String get displaySettingsPageShowTokenStatsTitle => '显示Token和上下文统计';

  @override
  String get displaySettingsPageShowTokenStatsSubtitle => '显示 token 用量与消息数量';

  @override
  String get displaySettingsPageAutoCollapseThinkingTitle => '自动折叠思考';

  @override
  String get displaySettingsPageAutoCollapseThinkingSubtitle =>
      '思考完成后自动折叠，保持界面简洁';

  @override
  String get displaySettingsPageShowChatListDateTitle => '显示对话列表日期';

  @override
  String get displaySettingsPageShowChatListDateSubtitle => '在左侧对话列表中显示日期分组标签';

  @override
  String get displaySettingsPageKeepSidebarOpenOnAssistantTapTitle =>
      '点选助手时不自动关闭侧边栏';

  @override
  String get displaySettingsPageKeepSidebarOpenOnTopicTapTitle =>
      '点选话题时不自动关闭侧边栏';

  @override
  String get displaySettingsPageKeepAssistantListExpandedOnSidebarCloseTitle =>
      '关闭侧边栏时不折叠助手列表';

  @override
  String get displaySettingsPageShowUpdatesTitle => '显示更新';

  @override
  String get displaySettingsPageShowUpdatesSubtitle => '显示应用更新通知';

  @override
  String get displaySettingsPageMessageNavButtonsTitle => '消息导航按钮';

  @override
  String get displaySettingsPageMessageNavButtonsSubtitle => '滚动时显示快速跳转按钮';

  @override
  String get displaySettingsPageHapticsOnSidebarTitle => '侧边栏触觉反馈';

  @override
  String get displaySettingsPageHapticsOnSidebarSubtitle => '打开/关闭侧边栏时启用触觉反馈';

  @override
  String get displaySettingsPageHapticsGlobalTitle => '全局触觉反馈';

  @override
  String get displaySettingsPageHapticsIosSwitchTitle => '开关触觉反馈';

  @override
  String get displaySettingsPageHapticsOnListItemTapTitle => '列表项触觉反馈';

  @override
  String get displaySettingsPageHapticsOnCardTapTitle => '卡片触觉反馈';

  @override
  String get displaySettingsPageHapticsOnGenerateTitle => '消息生成触觉反馈';

  @override
  String get displaySettingsPageHapticsOnGenerateSubtitle => '生成消息时启用触觉反馈';

  @override
  String get displaySettingsPageNewChatAfterDeleteTitle => '删除话题后新建对话';

  @override
  String get displaySettingsPageNewChatOnAssistantSwitchTitle => '切换助手时新建对话';

  @override
  String get displaySettingsPageNewChatOnLaunchTitle => '启动时新建对话';

  @override
  String get displaySettingsPageAutoSwitchTopicsTitle => '自动切换话题';

  @override
  String get desktopDisplaySettingsTopicPositionTitle => '话题位置';

  @override
  String get desktopDisplaySettingsTopicPositionLeft => '左侧';

  @override
  String get desktopDisplaySettingsTopicPositionRight => '右侧';

  @override
  String get displaySettingsPageNewChatOnLaunchSubtitle => '应用启动时自动创建新对话';

  @override
  String get displaySettingsPageChatFontSizeTitle => '聊天字体大小';

  @override
  String get displaySettingsPageAutoScrollEnableTitle => '自动回到底部';

  @override
  String get displaySettingsPageAutoScrollIdleTitle => '自动回到底部延迟';

  @override
  String get displaySettingsPageAutoScrollIdleSubtitle => '用户停止滚动后等待多久再自动回到底部';

  @override
  String get displaySettingsPageAutoScrollDisabledLabel => '已关闭';

  @override
  String get displaySettingsPageChatFontSampleText => '这是一个示例的聊天文本';

  @override
  String get displaySettingsPageChatBackgroundMaskTitle => '背景图片遮罩透明度';

  @override
  String get displaySettingsPageThemeSettingsTitle => '主题设置';

  @override
  String get displaySettingsPageThemeColorTitle => '主题颜色';

  @override
  String get desktopSettingsFontsTitle => '字体设置';

  @override
  String get displaySettingsPageTrayTitle => '托盘';

  @override
  String get displaySettingsPageTrayShowTrayTitle => '显示托盘图标';

  @override
  String get displaySettingsPageTrayMinimizeOnCloseTitle => '关闭时最小化到托盘';

  @override
  String get desktopFontAppLabel => '应用字体';

  @override
  String get desktopFontCodeLabel => '代码字体';

  @override
  String get desktopFontFamilySystemDefault => '系统默认';

  @override
  String get desktopFontFamilyMonospaceDefault => '系统默认';

  @override
  String get desktopFontFilterHint => '输入以过滤字体…';

  @override
  String get displaySettingsPageAppFontTitle => '应用字体';

  @override
  String get displaySettingsPageCodeFontTitle => '代码字体';

  @override
  String get fontPickerChooseLocalFile => '选择本地文件';

  @override
  String get fontPickerGetFromGoogleFonts => '从 Google Fonts 获取';

  @override
  String get fontPickerFilterHint => '输入以过滤字体…';

  @override
  String get desktopFontLoading => '正在加载字体…';

  @override
  String get displaySettingsPageFontLocalFileLabel => '本地文件';

  @override
  String get displaySettingsPageFontResetLabel => '恢复默认';

  @override
  String get displaySettingsPageOtherSettingsTitle => '其他设置';

  @override
  String get themeSettingsPageDynamicColorSection => '动态颜色';

  @override
  String get themeSettingsPageUseDynamicColorTitle => '系统动态配色';

  @override
  String get themeSettingsPageUseDynamicColorSubtitle => '跟随系统取色（Android 12+）';

  @override
  String get themeSettingsPageUsePureBackgroundTitle => '纯色背景';

  @override
  String get themeSettingsPageUsePureBackgroundSubtitle => '仅气泡与强调色随主题变化';

  @override
  String get themeSettingsPageColorPalettesSection => '配色方案';

  @override
  String get ttsServicesPageBackButton => '返回';

  @override
  String get ttsServicesPageTitle => '语音服务';

  @override
  String get ttsServicesPageAddTooltip => '新增';

  @override
  String get ttsServicesPageAddNotImplemented => '新增 TTS 服务暂未实现';

  @override
  String get ttsServicesPageSystemTtsTitle => '系统TTS';

  @override
  String get ttsServicesPageSystemTtsAvailableSubtitle => '使用系统内置语音合成';

  @override
  String ttsServicesPageSystemTtsUnavailableSubtitle(String error) {
    return '不可用：$error';
  }

  @override
  String get ttsServicesPageSystemTtsUnavailableNotInitialized => '未初始化';

  @override
  String get ttsServicesPageTestSpeechText => '你好，这是一次测试语音。';

  @override
  String get ttsServicesPageConfigureTooltip => '配置';

  @override
  String get ttsServicesPageTestVoiceTooltip => '测试语音';

  @override
  String get ttsServicesPageStopTooltip => '停止';

  @override
  String get ttsServicesPageDeleteTooltip => '删除';

  @override
  String get ttsServicesPageSystemTtsSettingsTitle => '系统 TTS 设置';

  @override
  String get ttsServicesPageEngineLabel => '引擎';

  @override
  String get ttsServicesPageAutoLabel => '自动';

  @override
  String get ttsServicesPageLanguageLabel => '语言';

  @override
  String get ttsServicesPageSpeechRateLabel => '语速';

  @override
  String get ttsServicesPagePitchLabel => '音调';

  @override
  String get ttsServicesPageSettingsSavedMessage => '设置已保存。';

  @override
  String get ttsServicesPageDoneButton => '完成';

  @override
  String get ttsServicesPageNetworkSectionTitle => '网络 TTS';

  @override
  String get ttsServicesPageNoNetworkServices => '暂无语音服务';

  @override
  String get ttsServicesDialogAddTitle => '添加语音服务';

  @override
  String get ttsServicesDialogEditTitle => '编辑语音服务';

  @override
  String get ttsServicesDialogProviderType => '服务提供方';

  @override
  String get ttsServicesDialogCancelButton => '取消';

  @override
  String get ttsServicesDialogAddButton => '添加';

  @override
  String get ttsServicesDialogSaveButton => '保存';

  @override
  String get ttsServicesFieldNameLabel => '名称';

  @override
  String get ttsServicesFieldApiKeyLabel => 'API Key';

  @override
  String get ttsServicesFieldBaseUrlLabel => 'API 基址';

  @override
  String get ttsServicesFieldModelLabel => '模型';

  @override
  String get ttsServicesFieldVoiceLabel => '音色';

  @override
  String get ttsServicesFieldVoiceIdLabel => '音色 ID';

  @override
  String get ttsServicesFieldEmotionLabel => '情感';

  @override
  String get ttsServicesFieldSpeedLabel => '语速';

  @override
  String get ttsServicesViewDetailsButton => '查看详情';

  @override
  String get ttsServicesDialogErrorTitle => '错误详情';

  @override
  String get ttsServicesCloseButton => '关闭';

  @override
  String imageViewerPageShareFailedOpenFile(String message) {
    return '无法分享，已尝试打开文件: $message';
  }

  @override
  String imageViewerPageShareFailed(String error) {
    return '分享失败: $error';
  }

  @override
  String get imageViewerPageShareButton => '分享图片';

  @override
  String get imageViewerPageSaveButton => '保存图片';

  @override
  String get imageViewerPageSaveSuccess => '已保存到相册';

  @override
  String imageViewerPageSaveFailed(String error) {
    return '保存失败: $error';
  }

  @override
  String get settingsShare => 'Kelivo - 开源AI助手';

  @override
  String get searchProviderBingLocalDescription =>
      '使用网络抓取工具获取必应搜索结果。无需 API 密钥，但可能不够稳定。';

  @override
  String get searchProviderDuckDuckGoDescription =>
      '基于 DDGS 的 DuckDuckGo 隐私搜索，无需 API 密钥，支持设置地区。';

  @override
  String get searchProviderBraveDescription => 'Brave 独立搜索引擎。注重隐私，无跟踪或画像。';

  @override
  String get searchProviderExaDescription => '具备语义理解的神经搜索引擎。适合研究与查找特定内容。';

  @override
  String get searchProviderLinkUpDescription =>
      '提供来源可追溯答案的搜索 API，同时提供搜索结果与 AI 摘要。';

  @override
  String get searchProviderMetasoDescription => '秘塔中文搜索引擎。面向中文内容优化并提供 AI 能力。';

  @override
  String get searchProviderSearXNGDescription => '注重隐私的元搜索引擎。需自建实例，无跟踪。';

  @override
  String get searchProviderTavilyDescription =>
      '为大型语言模型（LLMs）优化的 AI 搜索 API，提供高质量、相关的搜索结果。';

  @override
  String get searchProviderZhipuDescription =>
      '智谱 AI 旗下中文 AI 搜索服务，针对中文内容与查询进行了优化。';

  @override
  String get searchProviderOllamaDescription =>
      'Ollama 网络搜索 API。为模型补充最新信息，减少幻觉并提升准确性。';

  @override
  String get searchProviderJinaDescription => '适合开发者和企业用于 AI 搜索应用。支持多语言与多模态。';

  @override
  String get searchServiceNameBingLocal => 'Bing（Local）';

  @override
  String get searchServiceNameDuckDuckGo => 'DuckDuckGo';

  @override
  String get searchServiceNameTavily => 'Tavily';

  @override
  String get searchServiceNameExa => 'Exa';

  @override
  String get searchServiceNameZhipu => '智谱';

  @override
  String get searchServiceNameSearXNG => 'SearXNG';

  @override
  String get searchServiceNameLinkUp => 'LinkUp';

  @override
  String get searchServiceNameBrave => 'Brave';

  @override
  String get searchServiceNameMetaso => '秘塔';

  @override
  String get searchServiceNameOllama => 'Ollama';

  @override
  String get searchServiceNameJina => 'Jina';

  @override
  String get searchServiceNamePerplexity => 'Perplexity';

  @override
  String get searchProviderPerplexityDescription =>
      'Perplexity 搜索 API。提供排序的网页结果，支持区域与域名过滤。';

  @override
  String get searchServiceNameBocha => '博查';

  @override
  String get searchProviderBochaDescription =>
      '博查 AI 全网网页搜索，支持时间范围与摘要，更适合 AI 使用。';

  @override
  String get generationInterrupted => '生成已中断';

  @override
  String get titleForLocale => '新对话';

  @override
  String get quickPhraseBackTooltip => '返回';

  @override
  String get quickPhraseGlobalTitle => '快捷短语';

  @override
  String get quickPhraseAssistantTitle => '助手快捷短语';

  @override
  String get quickPhraseAddTooltip => '添加快捷短语';

  @override
  String get quickPhraseEmptyMessage => '暂无快捷短语';

  @override
  String get quickPhraseAddTitle => '添加快捷短语';

  @override
  String get quickPhraseEditTitle => '编辑快捷短语';

  @override
  String get quickPhraseTitleLabel => '标题';

  @override
  String get quickPhraseContentLabel => '内容';

  @override
  String get quickPhraseCancelButton => '取消';

  @override
  String get quickPhraseSaveButton => '保存';

  @override
  String get instructionInjectionTitle => '指令注入';

  @override
  String get instructionInjectionBackTooltip => '返回';

  @override
  String get instructionInjectionAddTooltip => '添加指令注入';

  @override
  String get instructionInjectionImportTooltip => '从文件导入';

  @override
  String get instructionInjectionEmptyMessage => '暂无指令注入卡片';

  @override
  String get instructionInjectionDefaultTitle => '学习模式';

  @override
  String get instructionInjectionAddTitle => '添加指令注入';

  @override
  String get instructionInjectionEditTitle => '编辑指令注入';

  @override
  String get instructionInjectionNameLabel => '名称';

  @override
  String get instructionInjectionPromptLabel => '提示词';

  @override
  String instructionInjectionImportSuccess(int count) {
    return '已导入 $count 个指令注入';
  }

  @override
  String get instructionInjectionSheetSubtitle => '为当前对话选择并应用一条指令提示词';

  @override
  String get mcpJsonEditButtonTooltip => '编辑 JSON';

  @override
  String get mcpJsonEditTitle => '编辑json';

  @override
  String get mcpJsonEditParseFailed => 'JSON 解析失败';

  @override
  String get mcpJsonEditSavedApplied => '已保存并应用';

  @override
  String get mcpTimeoutSettingsTooltip => '设置工具调用超时';

  @override
  String get mcpTimeoutDialogTitle => '工具调用超时';

  @override
  String get mcpTimeoutSecondsLabel => '工具调用超时（秒）';

  @override
  String get mcpTimeoutInvalid => '请输入大于 0 的秒数';

  @override
  String get quickPhraseEditButton => '编辑';

  @override
  String get quickPhraseDeleteButton => '删除';

  @override
  String get quickPhraseMenuTitle => '快捷短语';

  @override
  String get chatInputBarQuickPhraseTooltip => '快捷短语';

  @override
  String get assistantEditQuickPhraseDescription => '管理该助手的快捷短语。点击下方按钮添加短语。';

  @override
  String get assistantEditManageQuickPhraseButton => '管理快捷短语';

  @override
  String get assistantEditPageMemoryTab => '记忆';

  @override
  String get assistantEditMemorySwitchTitle => '记忆';

  @override
  String get assistantEditMemorySwitchDescription => '允许助手主动存储并在对话间引用用户相关信息';

  @override
  String get assistantEditRecentChatsSwitchTitle => '参考历史聊天记录';

  @override
  String get assistantEditRecentChatsSwitchDescription =>
      '在新对话中引用最近的对话标题以增强上下文';

  @override
  String get assistantEditManageMemoryTitle => '管理记忆';

  @override
  String get assistantEditAddMemoryButton => '添加记忆';

  @override
  String get assistantEditMemoryEmpty => '暂无记忆';

  @override
  String get assistantEditMemoryDialogTitle => '记忆';

  @override
  String get assistantEditMemoryDialogHint => '输入记忆内容';

  @override
  String get assistantEditAddQuickPhraseButton => '添加快捷短语';

  @override
  String get multiKeyPageDeleteSnackbarDeletedOne => '已删除 1 个 Key';

  @override
  String get multiKeyPageUndo => '撤回';

  @override
  String get multiKeyPageUndoRestored => '已撤回删除';

  @override
  String get multiKeyPageDeleteErrorsTooltip => '删除错误';

  @override
  String get multiKeyPageDeleteErrorsConfirmTitle => '删除所有错误的 Key？';

  @override
  String get multiKeyPageDeleteErrorsConfirmContent => '这将移除所有状态为错误的 Key。';

  @override
  String multiKeyPageDeletedErrorsSnackbar(int n) {
    return '已删除 $n 个错误 Key';
  }

  @override
  String get providerDetailPageProviderTypeTitle => '供应商类型';

  @override
  String get displaySettingsPageChatItemDisplayTitle => '聊天项显示';

  @override
  String get displaySettingsPageRenderingSettingsTitle => '渲染设置';

  @override
  String get displaySettingsPageBehaviorStartupTitle => '行为与启动';

  @override
  String get displaySettingsPageHapticsSettingsTitle => '触觉反馈';

  @override
  String get assistantSettingsNoPromptPlaceholder => '暂无提示词';

  @override
  String get providersPageMultiSelectTooltip => '多选';

  @override
  String get providersPageDeleteSelectedConfirmContent =>
      '确定要删除选中的供应商吗？该操作不可撤销。';

  @override
  String get providersPageDeleteSelectedSnackbar => '已删除选中的供应商';

  @override
  String providersPageExportSelectedTitle(int count) {
    return '导出 $count 个供应商';
  }

  @override
  String get providersPageExportCopyButton => '复制';

  @override
  String get providersPageExportShareButton => '分享';

  @override
  String get providersPageExportCopiedSnackbar => '已复制导出代码';

  @override
  String get providersPageDeleteAction => '删除';

  @override
  String get providersPageExportAction => '导出';

  @override
  String get assistantEditPresetTitle => '预设对话信息';

  @override
  String get assistantEditPresetAddUser => '添加预设用户信息';

  @override
  String get assistantEditPresetAddAssistant => '添加预设助手信息';

  @override
  String get assistantEditPresetInputHintUser => '输入用户消息…';

  @override
  String get assistantEditPresetInputHintAssistant => '输入助手消息…';

  @override
  String get assistantEditPresetEmpty => '暂无预设消息';

  @override
  String get assistantEditPresetEditDialogTitle => '编辑预设消息';

  @override
  String get assistantEditPresetRoleUser => '用户';

  @override
  String get assistantEditPresetRoleAssistant => '助手';

  @override
  String get desktopTtsPleaseAddProvider => '请先在设置中添加语音服务商';

  @override
  String get settingsPageNetworkProxy => '网络代理';

  @override
  String get networkProxyEnableLabel => '启动代理';

  @override
  String get networkProxySettingsHeader => '代理设置';

  @override
  String get networkProxyType => '代理类型';

  @override
  String get networkProxyTypeHttp => 'HTTP';

  @override
  String get networkProxyTypeHttps => 'HTTPS';

  @override
  String get networkProxyTypeSocks5 => 'SOCKS5';

  @override
  String get networkProxyServerHost => '服务器地址';

  @override
  String get networkProxyPort => '端口';

  @override
  String get networkProxyUsername => '用户名';

  @override
  String get networkProxyPassword => '密码';

  @override
  String get networkProxyOptionalHint => '可选';

  @override
  String get networkProxyTestHeader => '连接测试';

  @override
  String get networkProxyTestUrlHint => '测试地址';

  @override
  String get networkProxyTestButton => '测试';

  @override
  String get networkProxyTesting => '测试中…';

  @override
  String get networkProxyTestSuccess => '连接成功';

  @override
  String networkProxyTestFailed(String error) {
    return '测试失败：$error';
  }

  @override
  String get networkProxyNoUrl => '请输入测试地址';

  @override
  String get networkProxyPriorityNote => '当同时开启全局代理与供应商代理时，将优先使用供应商代理。';

  @override
  String get desktopShowProviderInModelCapsule => '模型胶囊显示供应商';

  @override
  String get messageWebViewOpenInBrowser => '在浏览器中打开';

  @override
  String get messageWebViewConsoleLogs => '控制台日志';

  @override
  String get messageWebViewNoConsoleMessages => '暂无控制台消息';

  @override
  String get messageWebViewRefreshTooltip => '刷新';

  @override
  String get messageWebViewForwardTooltip => '前进';

  @override
  String get chatInputBarOcrTooltip => 'OCR 文字识别';

  @override
  String get providerDetailPageBatchDetectButton => '检测';

  @override
  String get providerDetailPageBatchDetecting => '检测中...';

  @override
  String get providerDetailPageBatchDetectStart => '开始检测';

  @override
  String get providerDetailPageDetectSuccess => '检测成功';

  @override
  String get providerDetailPageDetectFailed => '检测失败';

  @override
  String get providerDetailPageDeleteAllModelsWarning => '此操作不可撤回';

  @override
  String get requestLogSettingTitle => '请求日志打印';

  @override
  String get requestLogSettingSubtitle => '开启后会将请求/响应详情写入 logs/logs.txt';

  @override
  String get flutterLogSettingTitle => '应用日志打印';

  @override
  String get flutterLogSettingSubtitle =>
      '开启后会将 Flutter 错误与 print 输出写入 logs/flutter_logs.txt';

  @override
  String get logViewerTitle => '请求日志';

  @override
  String get logViewerEmpty => '暂无日志';

  @override
  String get logViewerCurrentLog => '当前日志';

  @override
  String get logViewerExport => '导出';

  @override
  String get logViewerOpenFolder => '打开日志目录';

  @override
  String get assistantEditManageSummariesTitle => '管理摘要';

  @override
  String get assistantEditSummaryEmpty => '暂无摘要';

  @override
  String get assistantEditSummaryDialogTitle => '编辑摘要';

  @override
  String get assistantEditSummaryDialogHint => '输入摘要内容';

  @override
  String get assistantEditDeleteSummaryTitle => '清除摘要';

  @override
  String get assistantEditDeleteSummaryContent => '确定要清除此摘要吗？';
}

/// The translations for Chinese, using the Han script (`zh_Hans`).
class AppLocalizationsZhHans extends AppLocalizationsZh {
  AppLocalizationsZhHans() : super('zh_Hans');

  @override
  String get helloWorld => '你好，世界！';

  @override
  String get settingsPageBackButton => '返回';

  @override
  String get settingsPageTitle => '设置';

  @override
  String get settingsPageDarkMode => '深色';

  @override
  String get settingsPageLightMode => '浅色';

  @override
  String get settingsPageSystemMode => '跟随系统';

  @override
  String get settingsPageWarningMessage => '部分服务未配置，某些功能可能不可用';

  @override
  String get settingsPageGeneralSection => '通用设置';

  @override
  String get settingsPageColorMode => '颜色模式';

  @override
  String get settingsPageDisplay => '显示设置';

  @override
  String get settingsPageDisplaySubtitle => '界面主题与字号等外观设置';

  @override
  String get settingsPageAssistant => '助手';

  @override
  String get settingsPageAssistantSubtitle => '默认助手与对话风格';

  @override
  String get settingsPageModelsServicesSection => '模型与服务';

  @override
  String get settingsPageDefaultModel => '默认模型';

  @override
  String get settingsPageProviders => '供应商';

  @override
  String get settingsPageHotkeys => '快捷键';

  @override
  String get settingsPageSearch => '搜索服务';

  @override
  String get settingsPageTts => '语音服务';

  @override
  String get settingsPageMcp => 'MCP';

  @override
  String get settingsPageQuickPhrase => '快捷短语';

  @override
  String get settingsPageInstructionInjection => '指令注入';

  @override
  String get settingsPageDataSection => '数据设置';

  @override
  String get settingsPageBackup => '数据备份';

  @override
  String get settingsPageChatStorage => '聊天记录存储';

  @override
  String get settingsPageCalculating => '统计中…';

  @override
  String settingsPageFilesCount(int count, String size) {
    return '共 $count 个文件 · $size';
  }

  @override
  String get storageSpacePageTitle => '存储空间';

  @override
  String get storageSpaceRefreshTooltip => '刷新';

  @override
  String get storageSpaceLoadFailed => '加载失败';

  @override
  String get storageSpaceTotalLabel => '已用空间';

  @override
  String storageSpaceClearableLabel(String size) {
    return '可清理：$size';
  }

  @override
  String storageSpaceClearableHint(String size) {
    return '共发现可清理空间 $size';
  }

  @override
  String get storageSpaceCategoryImages => '图片';

  @override
  String get storageSpaceCategoryFiles => '文件';

  @override
  String get storageSpaceCategoryChatData => '聊天记录';

  @override
  String get storageSpaceCategoryAssistantData => '助手';

  @override
  String get storageSpaceCategoryCache => '缓存';

  @override
  String get storageSpaceCategoryLogs => '日志';

  @override
  String get storageSpaceCategoryOther => '应用';

  @override
  String storageSpaceFilesCount(int count) {
    return '$count 个文件';
  }

  @override
  String get storageSpaceSafeToClearHint => '可安全清理，不影响聊天记录。';

  @override
  String get storageSpaceNotSafeToClearHint => '可能影响聊天记录，请谨慎删除。';

  @override
  String get storageSpaceBreakdownTitle => '明细';

  @override
  String get storageSpaceSubChatMessages => '消息';

  @override
  String get storageSpaceSubChatConversations => '会话';

  @override
  String get storageSpaceSubChatToolEvents => '工具事件';

  @override
  String get storageSpaceSubAssistantAvatars => '头像';

  @override
  String get storageSpaceSubAssistantImages => '图片';

  @override
  String get storageSpaceSubCacheAvatars => '头像缓存';

  @override
  String get storageSpaceSubCacheOther => '其他缓存';

  @override
  String get storageSpaceSubCacheSystem => '系统缓存';

  @override
  String get storageSpaceSubLogsFlutter => '运行日志';

  @override
  String get storageSpaceSubLogsRequests => '网络日志';

  @override
  String get storageSpaceSubLogsOther => '其他日志';

  @override
  String get storageSpaceClearConfirmTitle => '确认清理';

  @override
  String storageSpaceClearConfirmMessage(String targetName) {
    return '确定要清理 $targetName 吗？';
  }

  @override
  String get storageSpaceClearButton => '清理';

  @override
  String storageSpaceClearDone(String targetName) {
    return '已清理 $targetName';
  }

  @override
  String storageSpaceClearFailed(String error) {
    return '清理失败：$error';
  }

  @override
  String get storageSpaceClearAvatarCacheButton => '清理头像缓存';

  @override
  String get storageSpaceClearCacheButton => '清理缓存';

  @override
  String get storageSpaceClearLogsButton => '清理日志';

  @override
  String get storageSpaceDeleteConfirmTitle => '确认删除';

  @override
  String storageSpaceDeleteUploadsConfirmMessage(int count) {
    return '删除 $count 个项目？删除后聊天记录中的附件可能无法打开。';
  }

  @override
  String storageSpaceDeletedUploadsDone(int count) {
    return '已删除 $count 个项目';
  }

  @override
  String get storageSpaceNoUploads => '暂无内容';

  @override
  String get storageSpaceSelectAll => '全选';

  @override
  String get storageSpaceClearSelection => '清空选择';

  @override
  String storageSpaceSelectedCount(int count) {
    return '已选 $count 项';
  }

  @override
  String storageSpaceUploadsCount(int count) {
    return '共 $count 项';
  }

  @override
  String get settingsPageAboutSection => '关于';

  @override
  String get settingsPageAbout => '关于';

  @override
  String get settingsPageDocs => '使用文档';

  @override
  String get settingsPageSponsor => '赞助';

  @override
  String get settingsPageShare => '分享';

  @override
  String get sponsorPageMethodsSectionTitle => '赞助方式';

  @override
  String get sponsorPageSponsorsSectionTitle => '赞助用户';

  @override
  String get sponsorPageEmpty => '暂无赞助者';

  @override
  String get sponsorPageAfdianTitle => '爱发电';

  @override
  String get sponsorPageAfdianSubtitle => 'afdian.com/a/kelivo';

  @override
  String get sponsorPageWeChatTitle => '微信赞助';

  @override
  String get sponsorPageWeChatSubtitle => '微信赞助码';

  @override
  String get languageDisplaySimplifiedChinese => '简体中文';

  @override
  String get languageDisplayEnglish => 'English';

  @override
  String get languageDisplayTraditionalChinese => '繁體中文';

  @override
  String get languageDisplayJapanese => '日本語';

  @override
  String get languageDisplayKorean => '한국어';

  @override
  String get languageDisplayFrench => 'Français';

  @override
  String get languageDisplayGerman => 'Deutsch';

  @override
  String get languageDisplayItalian => 'Italiano';

  @override
  String get languageDisplaySpanish => 'Español';

  @override
  String get languageSelectSheetTitle => '选择翻译语言';

  @override
  String get languageSelectSheetClearButton => '清空翻译';

  @override
  String get homePageClearContext => '清空上下文';

  @override
  String homePageClearContextWithCount(String actual, String configured) {
    return '清空上下文 ($actual/$configured)';
  }

  @override
  String get homePageDefaultAssistant => '默认助手';

  @override
  String get mermaidExportPng => '导出 PNG';

  @override
  String get mermaidExportFailed => '导出失败';

  @override
  String get mermaidPreviewOpen => '浏览器预览';

  @override
  String get mermaidPreviewOpenFailed => '无法打开预览';

  @override
  String get assistantProviderDefaultAssistantName => '默认助手';

  @override
  String get assistantProviderSampleAssistantName => '示例助手';

  @override
  String get assistantProviderNewAssistantName => '新助手';

  @override
  String assistantProviderSampleAssistantSystemPrompt(
    String model_name,
    String cur_datetime,
    String locale,
    String timezone,
    String device_info,
    String system_version,
  ) {
    return '你是$model_name, 一个人工智能助手，乐意为用户提供准确，有益的帮助。现在时间是$cur_datetime，用户设备语言为$locale，时区为$timezone，用户正在使用$device_info，版本$system_version。如果用户没有明确说明，请使用用户设备语言进行回复。';
  }

  @override
  String get displaySettingsPageLanguageTitle => '应用语言';

  @override
  String get displaySettingsPageLanguageSubtitle => '选择界面语言';

  @override
  String get assistantTagsManageTitle => '管理标签';

  @override
  String get assistantTagsCreateButton => '创建';

  @override
  String get assistantTagsCreateDialogTitle => '创建标签';

  @override
  String get assistantTagsCreateDialogOk => '创建';

  @override
  String get assistantTagsCreateDialogCancel => '取消';

  @override
  String get assistantTagsNameHint => '标签名称';

  @override
  String get assistantTagsRenameButton => '重命名';

  @override
  String get assistantTagsRenameDialogTitle => '重命名标签';

  @override
  String get assistantTagsRenameDialogOk => '重命名';

  @override
  String get assistantTagsDeleteButton => '删除';

  @override
  String get assistantTagsDeleteConfirmTitle => '删除标签';

  @override
  String get assistantTagsDeleteConfirmContent => '确定要删除该标签吗？';

  @override
  String get assistantTagsDeleteConfirmOk => '删除';

  @override
  String get assistantTagsDeleteConfirmCancel => '取消';

  @override
  String get assistantTagsContextMenuEditAssistant => '编辑助手';

  @override
  String get assistantTagsContextMenuManageTags => '管理标签';

  @override
  String get mcpTransportOptionStdio => 'STDIO';

  @override
  String get mcpTransportTagStdio => 'STDIO';

  @override
  String get mcpTransportTagInmemory => '内置';

  @override
  String get mcpServerEditSheetStdioOnlyDesktop => 'STDIO 仅在桌面端可用';

  @override
  String get mcpServerEditSheetStdioCommandLabel => '命令';

  @override
  String get mcpServerEditSheetStdioArgumentsLabel => '参数';

  @override
  String get mcpServerEditSheetStdioWorkingDirectoryLabel => '工作目录（可选）';

  @override
  String get mcpServerEditSheetStdioEnvironmentTitle => '环境变量';

  @override
  String get mcpServerEditSheetStdioEnvNameLabel => '名称';

  @override
  String get mcpServerEditSheetStdioEnvValueLabel => '值';

  @override
  String get mcpServerEditSheetStdioAddEnv => '添加环境变量';

  @override
  String get mcpServerEditSheetStdioCommandRequired => 'STDIO 需要填写命令';

  @override
  String get assistantTagsContextMenuDeleteAssistant => '删除助手';

  @override
  String get assistantTagsClearTag => '清除标签';

  @override
  String get displaySettingsPageLanguageChineseLabel => '简体中文';

  @override
  String get displaySettingsPageLanguageEnglishLabel => 'English';

  @override
  String get homePagePleaseSelectModel => '请先选择模型';

  @override
  String get homePagePleaseSetupTranslateModel => '请先设置翻译模型';

  @override
  String get homePageTranslating => '翻译中...';

  @override
  String homePageTranslateFailed(String error) {
    return '翻译失败: $error';
  }

  @override
  String get chatServiceDefaultConversationTitle => '新对话';

  @override
  String get userProviderDefaultUserName => '用户';

  @override
  String get homePageDeleteMessage => '删除消息';

  @override
  String get homePageDeleteMessageConfirm => '确定要删除这条消息吗？此操作不可撤销。';

  @override
  String get homePageCancel => '取消';

  @override
  String get homePageDelete => '删除';

  @override
  String get homePageSelectMessagesToShare => '请选择要分享的消息';

  @override
  String get homePageDone => '完成';

  @override
  String get homePageDropToUpload => '将文件拖拽到此处上传';

  @override
  String get assistantEditPageTitle => '助手';

  @override
  String get assistantEditPageNotFound => '助手不存在';

  @override
  String get assistantEditPageBasicTab => '基础设置';

  @override
  String get assistantEditPagePromptsTab => '提示词';

  @override
  String get assistantEditPageMcpTab => 'MCP';

  @override
  String get assistantEditPageQuickPhraseTab => '快捷短语';

  @override
  String get assistantEditPageCustomTab => '自定义请求';

  @override
  String get assistantEditPageRegexTab => '正则替换';

  @override
  String get assistantEditRegexDescription => '为用户/助手消息配置正则规则，可修改或仅调整显示效果。';

  @override
  String get assistantEditAddRegexButton => '添加正则规则';

  @override
  String get assistantRegexAddTitle => '添加正则规则';

  @override
  String get assistantRegexEditTitle => '编辑正则规则';

  @override
  String get assistantRegexNameLabel => '规则名称';

  @override
  String get assistantRegexPatternLabel => '正则表达式';

  @override
  String get assistantRegexReplacementLabel => '替换字符串';

  @override
  String get assistantRegexScopeLabel => '影响范围';

  @override
  String get assistantRegexScopeUser => '用户';

  @override
  String get assistantRegexScopeAssistant => '助手';

  @override
  String get assistantRegexScopeVisualOnly => '仅视觉';

  @override
  String get assistantRegexAddAction => '添加';

  @override
  String get assistantRegexSaveAction => '保存';

  @override
  String get assistantRegexDeleteButton => '删除';

  @override
  String get assistantRegexValidationError => '请填写名称、正则表达式，并至少选择一个范围。';

  @override
  String get assistantRegexInvalidPattern => '正则表达式无效';

  @override
  String get assistantRegexCancelButton => '取消';

  @override
  String get assistantRegexUntitled => '未命名规则';

  @override
  String get assistantEditCustomHeadersTitle => '自定义 Header';

  @override
  String get assistantEditCustomHeadersAdd => '添加 Header';

  @override
  String get assistantEditCustomHeadersEmpty => '未添加 Header';

  @override
  String get assistantEditCustomBodyTitle => '自定义 Body';

  @override
  String get assistantEditCustomBodyAdd => '添加 Body';

  @override
  String get assistantEditCustomBodyEmpty => '未添加 Body 项';

  @override
  String get assistantEditHeaderNameLabel => 'Header 名称';

  @override
  String get assistantEditHeaderValueLabel => 'Header 值';

  @override
  String get assistantEditBodyKeyLabel => 'Body Key';

  @override
  String get assistantEditBodyValueLabel => 'Body 值 (JSON)';

  @override
  String get assistantEditDeleteTooltip => '删除';

  @override
  String get assistantEditAssistantNameLabel => '助手名称';

  @override
  String get assistantEditUseAssistantAvatarTitle => '使用助手头像';

  @override
  String get assistantEditUseAssistantAvatarSubtitle =>
      '在聊天中使用助手头像和名字而不是模型头像和名字';

  @override
  String get assistantEditChatModelTitle => '聊天模型';

  @override
  String get assistantEditChatModelSubtitle => '为该助手设置默认聊天模型（未设置时使用全局默认）';

  @override
  String get assistantEditTemperatureDescription => '控制输出的随机性，范围 0–2';

  @override
  String get assistantEditTopPDescription => '请不要修改此值，除非你知道自己在做什么';

  @override
  String get assistantEditParameterDisabled => '已关闭（使用服务商默认）';

  @override
  String get assistantEditParameterDisabled2 => '已关闭（无限制）';

  @override
  String get assistantEditContextMessagesTitle => '上下文消息数量';

  @override
  String get assistantEditContextMessagesDescription =>
      '多少历史消息会被当作上下文发送给模型，超过数量会忽略，只保留最近 N 条';

  @override
  String get assistantEditStreamOutputTitle => '流式输出';

  @override
  String get assistantEditStreamOutputDescription => '是否启用消息的流式输出';

  @override
  String get assistantEditThinkingBudgetTitle => '思考预算';

  @override
  String get assistantEditConfigureButton => '配置';

  @override
  String get assistantEditMaxTokensTitle => '最大 Token 数';

  @override
  String get assistantEditMaxTokensDescription => '留空表示无限制';

  @override
  String get assistantEditMaxTokensHint => '无限制';

  @override
  String get assistantEditChatBackgroundTitle => '聊天背景';

  @override
  String get assistantEditChatBackgroundDescription => '设置助手聊天页面的背景图片';

  @override
  String get assistantEditChooseImageButton => '选择背景图片';

  @override
  String get assistantEditClearButton => '清除';

  @override
  String get desktopNavChatTooltip => '聊天';

  @override
  String get desktopNavTranslateTooltip => '翻译';

  @override
  String get desktopNavStorageTooltip => '存储';

  @override
  String get desktopNavThemeToggleTooltip => '主题切换';

  @override
  String get desktopNavSettingsTooltip => '设置';

  @override
  String get desktopAvatarMenuUseEmoji => '使用表情符号';

  @override
  String get cameraPermissionDeniedMessage => '未授予相机权限';

  @override
  String get openSystemSettings => '去设置';

  @override
  String get desktopAvatarMenuChangeFromImage => '从图片更换…';

  @override
  String get desktopAvatarMenuReset => '重置头像';

  @override
  String get assistantEditAvatarChooseImage => '选择图片';

  @override
  String get assistantEditAvatarChooseEmoji => '选择表情';

  @override
  String get assistantEditAvatarEnterLink => '输入链接';

  @override
  String get assistantEditAvatarImportQQ => 'QQ头像';

  @override
  String get assistantEditAvatarReset => '重置';

  @override
  String get displaySettingsPageChatMessageBackgroundTitle => '聊天消息背景';

  @override
  String get displaySettingsPageChatMessageBackgroundDefault => '默认';

  @override
  String get displaySettingsPageChatMessageBackgroundFrosted => '模糊';

  @override
  String get displaySettingsPageChatMessageBackgroundSolid => '纯色';

  @override
  String get displaySettingsPageAndroidBackgroundChatTitle => '后台聊天生成';

  @override
  String get androidBackgroundStatusOn => '开启';

  @override
  String get androidBackgroundStatusOff => '关闭';

  @override
  String get androidBackgroundStatusOther => '开启并通知';

  @override
  String get androidBackgroundOptionOn => '开启';

  @override
  String get androidBackgroundOptionOnNotify => '开启并在生成完时通知';

  @override
  String get androidBackgroundOptionOff => '关闭';

  @override
  String get notificationChatCompletedTitle => '生成完成';

  @override
  String get notificationChatCompletedBody => '助手回复已生成';

  @override
  String get androidBackgroundNotificationTitle => 'Kelivo 正在运行';

  @override
  String get androidBackgroundNotificationText => '后台保持聊天生成';

  @override
  String get assistantEditEmojiDialogTitle => '选择表情';

  @override
  String get assistantEditEmojiDialogHint => '输入或粘贴任意表情';

  @override
  String get assistantEditEmojiDialogCancel => '取消';

  @override
  String get assistantEditEmojiDialogSave => '保存';

  @override
  String get assistantEditImageUrlDialogTitle => '输入图片链接';

  @override
  String get assistantEditImageUrlDialogHint =>
      '例如: https://example.com/avatar.png';

  @override
  String get assistantEditImageUrlDialogCancel => '取消';

  @override
  String get assistantEditImageUrlDialogSave => '保存';

  @override
  String get assistantEditQQAvatarDialogTitle => '使用QQ头像';

  @override
  String get assistantEditQQAvatarDialogHint => '输入QQ号码（5-12位）';

  @override
  String get assistantEditQQAvatarRandomButton => '随机QQ';

  @override
  String get assistantEditQQAvatarFailedMessage => '获取随机QQ头像失败，请重试';

  @override
  String get assistantEditQQAvatarDialogCancel => '取消';

  @override
  String get assistantEditQQAvatarDialogSave => '保存';

  @override
  String get assistantEditGalleryErrorMessage => '无法打开相册，试试输入图片链接';

  @override
  String get assistantEditGeneralErrorMessage => '发生错误，试试输入图片链接';

  @override
  String get providerDetailPageMultiKeyModeTitle => '多Key模式';

  @override
  String get providerDetailPageManageKeysButton => '多Key管理';

  @override
  String get multiKeyPageTitle => '多Key管理';

  @override
  String get multiKeyPageDetect => '检测';

  @override
  String get multiKeyPageAdd => '添加';

  @override
  String get multiKeyPageAddHint => '请输入API Key（多个用逗号或空格分隔）';

  @override
  String multiKeyPageImportedSnackbar(int n) {
    return '已导入$n个key';
  }

  @override
  String get multiKeyPagePleaseAddModel => '请先添加模型';

  @override
  String get multiKeyPageTotal => '总数';

  @override
  String get multiKeyPageNormal => '正常';

  @override
  String get multiKeyPageError => '错误';

  @override
  String get multiKeyPageAccuracy => '正确率';

  @override
  String get multiKeyPageStrategyTitle => '负载均衡策略';

  @override
  String get multiKeyPageStrategyRoundRobin => '轮询';

  @override
  String get multiKeyPageStrategyPriority => '优先级';

  @override
  String get multiKeyPageStrategyLeastUsed => '最少使用';

  @override
  String get multiKeyPageStrategyRandom => '随机';

  @override
  String get multiKeyPageNoKeys => '暂无Key';

  @override
  String get multiKeyPageStatusActive => '正常';

  @override
  String get multiKeyPageStatusDisabled => '已关闭';

  @override
  String get multiKeyPageStatusError => '错误';

  @override
  String get multiKeyPageStatusRateLimited => '限速';

  @override
  String get multiKeyPageEditAlias => '编辑别名';

  @override
  String get multiKeyPageEdit => '编辑';

  @override
  String get multiKeyPageKey => 'API Key';

  @override
  String get multiKeyPagePriority => '优先级（1–10）';

  @override
  String get multiKeyPageDuplicateKeyWarning => '该 Key 已存在';

  @override
  String get multiKeyPageAlias => '别名';

  @override
  String get multiKeyPageCancel => '取消';

  @override
  String get multiKeyPageSave => '保存';

  @override
  String get multiKeyPageDelete => '删除';

  @override
  String get assistantEditSystemPromptTitle => '系统提示词';

  @override
  String get assistantEditSystemPromptHint => '输入系统提示词…';

  @override
  String get assistantEditSystemPromptImportButton => '从文件导入';

  @override
  String get assistantEditSystemPromptImportSuccess => '已从文件更新系统提示词';

  @override
  String get assistantEditSystemPromptImportFailed => '导入失败';

  @override
  String get assistantEditSystemPromptImportEmpty => '文件内容为空';

  @override
  String get assistantEditAvailableVariables => '可用变量：';

  @override
  String get assistantEditVariableDate => '日期';

  @override
  String get assistantEditVariableTime => '时间';

  @override
  String get assistantEditVariableDatetime => '日期和时间';

  @override
  String get assistantEditVariableModelId => '模型ID';

  @override
  String get assistantEditVariableModelName => '模型名称';

  @override
  String get assistantEditVariableLocale => '语言环境';

  @override
  String get assistantEditVariableTimezone => '时区';

  @override
  String get assistantEditVariableSystemVersion => '系统版本';

  @override
  String get assistantEditVariableDeviceInfo => '设备信息';

  @override
  String get assistantEditVariableBatteryLevel => '电池电量';

  @override
  String get assistantEditVariableNickname => '用户昵称';

  @override
  String get assistantEditVariableAssistantName => '助手名称';

  @override
  String get assistantEditMessageTemplateTitle => '聊天内容模板';

  @override
  String get assistantEditVariableRole => '角色';

  @override
  String get assistantEditVariableMessage => '内容';

  @override
  String get assistantEditPreviewTitle => '预览';

  @override
  String get codeBlockPreviewButton => '预览';

  @override
  String codeBlockCollapsedLines(int n) {
    return '… 已折叠 $n 行';
  }

  @override
  String get htmlPreviewNotSupportedOnLinux => 'Linux 暂不支持 HTML 预览';

  @override
  String get assistantEditSampleUser => '用户';

  @override
  String get assistantEditSampleMessage => '你好啊';

  @override
  String get assistantEditSampleReply => '你好，有什么我可以帮你的吗？';

  @override
  String get assistantEditMcpNoServersMessage => '暂无已启动的 MCP 服务器';

  @override
  String get assistantEditMcpConnectedTag => '已连接';

  @override
  String assistantEditMcpToolsCountTag(String enabled, String total) {
    return '工具: $enabled/$total';
  }

  @override
  String get assistantEditModelUseGlobalDefault => '使用全局默认';

  @override
  String get assistantSettingsPageTitle => '助手设置';

  @override
  String get assistantSettingsDefaultTag => '默认';

  @override
  String get assistantSettingsCopyButton => '复制';

  @override
  String get assistantSettingsCopySuccess => '已复制助手';

  @override
  String get assistantSettingsCopySuffix => '副本';

  @override
  String get assistantSettingsDeleteButton => '删除';

  @override
  String get assistantSettingsEditButton => '编辑';

  @override
  String get assistantSettingsAddSheetTitle => '助手名称';

  @override
  String get assistantSettingsAddSheetHint => '输入助手名称';

  @override
  String get assistantSettingsAddSheetCancel => '取消';

  @override
  String get assistantSettingsAddSheetSave => '保存';

  @override
  String get desktopAssistantsListTitle => '助手列表';

  @override
  String get desktopSidebarTabAssistants => '助手';

  @override
  String get desktopSidebarTabTopics => '话题';

  @override
  String get desktopTrayMenuShowWindow => '显示窗口';

  @override
  String get desktopTrayMenuExit => '退出';

  @override
  String get hotkeyToggleAppVisibility => '显示/隐藏应用';

  @override
  String get hotkeyCloseWindow => '关闭窗口';

  @override
  String get hotkeyOpenSettings => '打开设置';

  @override
  String get hotkeyNewTopic => '新建话题';

  @override
  String get hotkeySwitchModel => '切换模型';

  @override
  String get hotkeyToggleAssistantPanel => '切换助手显示';

  @override
  String get hotkeyToggleTopicPanel => '切换话题显示';

  @override
  String get hotkeysPressShortcut => '按下快捷键';

  @override
  String get hotkeysResetDefault => '重置为默认';

  @override
  String get hotkeysClearShortcut => '清除快捷键';

  @override
  String get hotkeysResetAll => '重置所有快捷键为默认';

  @override
  String get assistantEditTemperatureTitle => '温度';

  @override
  String get assistantEditTopPTitle => 'Top-p';

  @override
  String get assistantSettingsDeleteDialogTitle => '删除助手';

  @override
  String get assistantSettingsDeleteDialogContent => '确定要删除该助手吗？此操作不可撤销。';

  @override
  String get assistantSettingsDeleteDialogCancel => '取消';

  @override
  String get assistantSettingsDeleteDialogConfirm => '删除';

  @override
  String get assistantSettingsAtLeastOneAssistantRequired => '至少需要保留一个助手';

  @override
  String get mcpAssistantSheetTitle => 'MCP服务器';

  @override
  String get mcpAssistantSheetSubtitle => '为该助手启用的服务';

  @override
  String get mcpAssistantSheetSelectAll => '全选';

  @override
  String get mcpAssistantSheetClearAll => '全不选';

  @override
  String get backupPageTitle => '备份与恢复';

  @override
  String get backupPageWebDavTab => 'WebDAV 备份';

  @override
  String get backupPageImportExportTab => '导入和导出';

  @override
  String get backupPageWebDavServerUrl => 'WebDAV 服务器地址';

  @override
  String get backupPageUsername => '用户名';

  @override
  String get backupPagePassword => '密码';

  @override
  String get backupPagePath => '路径';

  @override
  String get backupPageChatsLabel => '聊天记录';

  @override
  String get backupPageFilesLabel => '文件';

  @override
  String get backupPageTestDone => '测试完成';

  @override
  String get backupPageTestConnection => '测试连接';

  @override
  String get backupPageRestartRequired => '需要重启应用';

  @override
  String get backupPageRestartContent => '恢复完成，需要重启以完全生效。';

  @override
  String get backupPageOK => '好的';

  @override
  String get backupPageCancel => '取消';

  @override
  String get backupPageSelectImportMode => '选择导入模式';

  @override
  String get backupPageSelectImportModeDescription => '请选择如何导入备份数据：';

  @override
  String get backupPageOverwriteMode => '完全覆盖';

  @override
  String get backupPageOverwriteModeDescription => '清空本地所有数据后恢复';

  @override
  String get backupPageMergeMode => '智能合并';

  @override
  String get backupPageMergeModeDescription => '仅添加不存在的数据（智能去重）';

  @override
  String get backupPageRestore => '恢复';

  @override
  String get backupPageBackupUploaded => '已上传备份';

  @override
  String get backupPageBackup => '立即备份';

  @override
  String get backupPageExporting => '正在导出...';

  @override
  String get backupPageExportToFile => '导出为文件';

  @override
  String get backupPageExportToFileSubtitle => '导出APP数据为文件';

  @override
  String get backupPageImportBackupFile => '备份文件导入';

  @override
  String get backupPageImportBackupFileSubtitle => '导入本地备份文件';

  @override
  String get backupPageImportFromOtherApps => '从其他APP导入';

  @override
  String get backupPageImportFromRikkaHub => '从 RikkaHub 导入';

  @override
  String get backupPageNotSupportedYet => '暂不支持';

  @override
  String get backupPageRemoteBackups => '远端备份';

  @override
  String get backupPageNoBackups => '暂无备份';

  @override
  String get backupPageRestoreTooltip => '恢复';

  @override
  String get backupPageDeleteTooltip => '删除';

  @override
  String get backupPageBackupManagement => '备份管理';

  @override
  String get backupPageWebDavBackup => 'WebDAV 备份';

  @override
  String get backupPageWebDavServerSettings => 'WebDAV 服务器设置';

  @override
  String get backupPageSave => '保存';

  @override
  String get backupPageBackupNow => '立即备份';

  @override
  String get backupPageLocalBackup => '本地备份';

  @override
  String get backupPageImportFromCherryStudio => '从 Cherry Studio 导入';

  @override
  String get backupPageImportFromChatbox => '从 Chatbox 导入';

  @override
  String get chatHistoryPageTitle => '聊天历史';

  @override
  String get chatHistoryPageSearchTooltip => '搜索';

  @override
  String get chatHistoryPageDeleteAllTooltip => '删除未置顶';

  @override
  String get chatHistoryPageDeleteAllDialogTitle => '删除未置顶对话';

  @override
  String get chatHistoryPageDeleteAllDialogContent =>
      '确定要删除所有未置顶的对话吗？已置顶的将会保留。';

  @override
  String get chatHistoryPageCancel => '取消';

  @override
  String get chatHistoryPageDelete => '删除';

  @override
  String get chatHistoryPageDeletedAllSnackbar => '已删除未置顶的对话';

  @override
  String get chatHistoryPageSearchHint => '搜索对话';

  @override
  String get chatHistoryPageNoConversations => '暂无对话';

  @override
  String get chatHistoryPagePinnedSection => '置顶';

  @override
  String get chatHistoryPagePin => '置顶';

  @override
  String get chatHistoryPagePinned => '已置顶';

  @override
  String get messageEditPageTitle => '编辑消息';

  @override
  String get messageEditPageSave => '保存';

  @override
  String get messageEditPageSaveAndSend => '保存并发送';

  @override
  String get messageEditPageHint => '输入消息内容…';

  @override
  String get selectCopyPageTitle => '选择复制';

  @override
  String get selectCopyPageCopyAll => '复制全部';

  @override
  String get selectCopyPageCopiedAll => '已复制全部';

  @override
  String get bottomToolsSheetCamera => '拍照';

  @override
  String get bottomToolsSheetPhotos => '照片';

  @override
  String get bottomToolsSheetUpload => '上传文件';

  @override
  String get bottomToolsSheetClearContext => '清空上下文';

  @override
  String get bottomToolsSheetLearningMode => '学习模式';

  @override
  String get bottomToolsSheetLearningModeDescription => '帮助你循序渐进地学习知识';

  @override
  String get bottomToolsSheetConfigurePrompt => '设置提示词';

  @override
  String get bottomToolsSheetPrompt => '提示词';

  @override
  String get bottomToolsSheetPromptHint => '输入要注入的提示词内容';

  @override
  String get bottomToolsSheetResetDefault => '重置为默认';

  @override
  String get bottomToolsSheetSave => '保存';

  @override
  String get bottomToolsSheetOcr => 'OCR 文字识别';

  @override
  String get messageMoreSheetTitle => '更多操作';

  @override
  String get messageMoreSheetSelectCopy => '选择复制';

  @override
  String get messageMoreSheetRenderWebView => '网页视图渲染';

  @override
  String get messageMoreSheetNotImplemented => '暂未实现';

  @override
  String get messageMoreSheetEdit => '编辑';

  @override
  String get messageMoreSheetShare => '分享';

  @override
  String get messageMoreSheetCreateBranch => '创建分支';

  @override
  String get messageMoreSheetDelete => '删除';

  @override
  String get reasoningBudgetSheetOff => '关闭';

  @override
  String get reasoningBudgetSheetAuto => '自动';

  @override
  String get reasoningBudgetSheetLight => '轻度推理';

  @override
  String get reasoningBudgetSheetMedium => '中度推理';

  @override
  String get reasoningBudgetSheetHeavy => '重度推理';

  @override
  String get reasoningBudgetSheetTitle => '思维链强度';

  @override
  String reasoningBudgetSheetCurrentLevel(String level) {
    return '当前档位：$level';
  }

  @override
  String get reasoningBudgetSheetOffSubtitle => '关闭推理功能，直接回答';

  @override
  String get reasoningBudgetSheetAutoSubtitle => '由模型自动决定推理级别';

  @override
  String get reasoningBudgetSheetLightSubtitle => '使用少量推理来回答问题';

  @override
  String get reasoningBudgetSheetMediumSubtitle => '使用较多推理来回答问题';

  @override
  String get reasoningBudgetSheetHeavySubtitle => '使用大量推理来回答问题，适合复杂问题';

  @override
  String get reasoningBudgetSheetCustomLabel => '自定义推理预算 (tokens)';

  @override
  String get reasoningBudgetSheetCustomHint => '例如：2048 (-1 自动，0 关闭)';

  @override
  String chatMessageWidgetFileNotFound(String fileName) {
    return '文件不存在: $fileName';
  }

  @override
  String chatMessageWidgetCannotOpenFile(String message) {
    return '无法打开文件: $message';
  }

  @override
  String chatMessageWidgetOpenFileError(String error) {
    return '打开文件失败: $error';
  }

  @override
  String get chatMessageWidgetCopiedToClipboard => '已复制到剪贴板';

  @override
  String get chatMessageWidgetResendTooltip => '重新发送';

  @override
  String get chatMessageWidgetMoreTooltip => '更多';

  @override
  String get chatMessageWidgetThinking => '正在思考...';

  @override
  String get chatMessageWidgetTranslation => '翻译';

  @override
  String get chatMessageWidgetTranslating => '翻译中...';

  @override
  String get chatMessageWidgetCitationNotFound => '未找到引用来源';

  @override
  String chatMessageWidgetCannotOpenUrl(String url) {
    return '无法打开链接: $url';
  }

  @override
  String get chatMessageWidgetOpenLinkError => '打开链接失败';

  @override
  String chatMessageWidgetCitationsTitle(int count) {
    return '引用（共$count条）';
  }

  @override
  String get chatMessageWidgetRegenerateTooltip => '重新生成';

  @override
  String get chatMessageWidgetStopTooltip => '停止';

  @override
  String get chatMessageWidgetSpeakTooltip => '朗读';

  @override
  String get chatMessageWidgetTranslateTooltip => '翻译';

  @override
  String get chatMessageWidgetBuiltinSearchHideNote => '隐藏内置搜索工具卡片';

  @override
  String get chatMessageWidgetDeepThinking => '深度思考';

  @override
  String get chatMessageWidgetCreateMemory => '创建记忆';

  @override
  String get chatMessageWidgetEditMemory => '编辑记忆';

  @override
  String get chatMessageWidgetDeleteMemory => '删除记忆';

  @override
  String chatMessageWidgetWebSearch(String query) {
    return '联网检索: $query';
  }

  @override
  String get chatMessageWidgetBuiltinSearch => '模型内置搜索';

  @override
  String chatMessageWidgetToolCall(String name) {
    return '调用工具: $name';
  }

  @override
  String chatMessageWidgetToolResult(String name) {
    return '调用工具: $name';
  }

  @override
  String get chatMessageWidgetNoResultYet => '（暂无结果）';

  @override
  String get chatMessageWidgetArguments => '参数';

  @override
  String get chatMessageWidgetResult => '结果';

  @override
  String chatMessageWidgetCitationsCount(int count) {
    return '共$count条引用';
  }

  @override
  String get messageExportSheetAssistant => '助手';

  @override
  String get messageExportSheetDefaultTitle => '新对话';

  @override
  String get messageExportSheetExporting => '正在导出…';

  @override
  String messageExportSheetExportFailed(String error) {
    return '导出失败: $error';
  }

  @override
  String messageExportSheetExportedAs(String filename) {
    return '已导出为 $filename';
  }

  @override
  String get displaySettingsPageEnableDollarLatexTitle => '启用 \$...\$ 渲染';

  @override
  String get displaySettingsPageEnableDollarLatexSubtitle =>
      '将 \$...\$ 之间的内容按行内数学公式渲染';

  @override
  String get displaySettingsPageEnableMathTitle => '启用数学公式渲染';

  @override
  String get displaySettingsPageEnableMathSubtitle => '渲染 LaTeX 数学公式（行内与块级）';

  @override
  String get displaySettingsPageEnableUserMarkdownTitle => '用户消息 Markdown 渲染';

  @override
  String get displaySettingsPageEnableReasoningMarkdownTitle =>
      '思维链 Markdown 渲染';

  @override
  String get displaySettingsPageMobileCodeBlockWrapTitle => '移动端代码块自动换行';

  @override
  String get displaySettingsPageAutoCollapseCodeBlockTitle => '自动折叠代码块';

  @override
  String get displaySettingsPageAutoCollapseCodeBlockLinesTitle => '超过多少行自动折叠';

  @override
  String get displaySettingsPageAutoCollapseCodeBlockLinesUnit => '行';

  @override
  String get messageExportSheetFormatTitle => '导出格式';

  @override
  String get messageExportSheetMarkdown => 'Markdown';

  @override
  String get messageExportSheetSingleMarkdownSubtitle => '将该消息导出为 Markdown 文件';

  @override
  String get messageExportSheetBatchMarkdownSubtitle => '将选中的消息导出为 Markdown 文件';

  @override
  String get messageExportSheetPlainText => '纯文本';

  @override
  String get messageExportSheetSingleTxtSubtitle => '将该消息导出为 TXT 文件';

  @override
  String get messageExportSheetBatchTxtSubtitle => '将选中的消息导出为 TXT 文件';

  @override
  String get messageExportSheetExportImage => '导出为图片';

  @override
  String get messageExportSheetSingleExportImageSubtitle => '将该消息渲染为 PNG 图片';

  @override
  String get messageExportSheetBatchExportImageSubtitle => '将选中的消息渲染为 PNG 图片';

  @override
  String get messageExportSheetShowThinkingAndToolCards => '显示思考卡片和工具卡片';

  @override
  String get messageExportSheetShowThinkingContent => '显示思考内容';

  @override
  String get messageExportSheetDateTimeWithSecondsPattern =>
      'yyyy年M月d日 HH:mm:ss';

  @override
  String get exportDisclaimerAiGenerated => '内容由 AI 生成，请仔细甄别';

  @override
  String get imagePreviewSheetSaveImage => '保存图片';

  @override
  String get imagePreviewSheetSaveSuccess => '已保存到相册';

  @override
  String imagePreviewSheetSaveFailed(String error) {
    return '保存失败: $error';
  }

  @override
  String get sideDrawerMenuRename => '重命名';

  @override
  String get sideDrawerMenuPin => '置顶';

  @override
  String get sideDrawerMenuUnpin => '取消置顶';

  @override
  String get sideDrawerMenuRegenerateTitle => '重新生成标题';

  @override
  String get sideDrawerMenuMoveTo => '移动到';

  @override
  String get sideDrawerMenuDelete => '删除';

  @override
  String sideDrawerDeleteSnackbar(String title) {
    return '已删除“$title”';
  }

  @override
  String get sideDrawerRenameHint => '输入新名称';

  @override
  String get sideDrawerCancel => '取消';

  @override
  String get sideDrawerOK => '确定';

  @override
  String get sideDrawerSave => '保存';

  @override
  String get sideDrawerGreetingMorning => '早上好 👋';

  @override
  String get sideDrawerGreetingNoon => '中午好 👋';

  @override
  String get sideDrawerGreetingAfternoon => '下午好 👋';

  @override
  String get sideDrawerGreetingEvening => '晚上好 👋';

  @override
  String get sideDrawerDateToday => '今天';

  @override
  String get sideDrawerDateYesterday => '昨天';

  @override
  String get sideDrawerDateShortPattern => 'M月d日';

  @override
  String get sideDrawerDateFullPattern => 'yyyy年M月d日';

  @override
  String get sideDrawerSearchHint => '搜索聊天记录';

  @override
  String get sideDrawerSearchAssistantsHint => '搜索助手';

  @override
  String sideDrawerUpdateTitle(String version) {
    return '发现新版本：$version';
  }

  @override
  String sideDrawerUpdateTitleWithBuild(String version, int build) {
    return '发现新版本：$version ($build)';
  }

  @override
  String get sideDrawerLinkCopied => '已复制下载链接';

  @override
  String get sideDrawerPinnedLabel => '置顶';

  @override
  String get sideDrawerHistory => '聊天历史';

  @override
  String get sideDrawerSettings => '设置';

  @override
  String get sideDrawerChooseAssistantTitle => '选择助手';

  @override
  String get sideDrawerChooseImage => '选择图片';

  @override
  String get sideDrawerChooseEmoji => '选择表情';

  @override
  String get sideDrawerEnterLink => '输入链接';

  @override
  String get sideDrawerImportFromQQ => 'QQ头像';

  @override
  String get sideDrawerReset => '重置';

  @override
  String get sideDrawerEmojiDialogTitle => '选择表情';

  @override
  String get sideDrawerEmojiDialogHint => '输入或粘贴任意表情';

  @override
  String get sideDrawerImageUrlDialogTitle => '输入图片链接';

  @override
  String get sideDrawerImageUrlDialogHint =>
      '例如: https://example.com/avatar.png';

  @override
  String get sideDrawerQQAvatarDialogTitle => '使用QQ头像';

  @override
  String get sideDrawerQQAvatarInputHint => '输入QQ号码（5-12位）';

  @override
  String get sideDrawerQQAvatarFetchFailed => '获取随机QQ头像失败，请重试';

  @override
  String get sideDrawerRandomQQ => '随机QQ';

  @override
  String get sideDrawerGalleryOpenError => '无法打开相册，试试输入图片链接';

  @override
  String get sideDrawerGeneralImageError => '发生错误，试试输入图片链接';

  @override
  String get sideDrawerSetNicknameTitle => '设置昵称';

  @override
  String get sideDrawerNicknameLabel => '昵称';

  @override
  String get sideDrawerNicknameHint => '输入新的昵称';

  @override
  String get sideDrawerRename => '重命名';

  @override
  String get chatInputBarHint => '输入消息与AI聊天';

  @override
  String get chatInputBarSelectModelTooltip => '选择模型';

  @override
  String get chatInputBarOnlineSearchTooltip => '联网搜索';

  @override
  String get chatInputBarReasoningStrengthTooltip => '思维链强度';

  @override
  String get chatInputBarMcpServersTooltip => 'MCP服务器';

  @override
  String get chatInputBarMoreTooltip => '更多';

  @override
  String get chatInputBarInsertNewline => '换行';

  @override
  String get chatInputBarExpand => '展开';

  @override
  String get chatInputBarCollapse => '收起';

  @override
  String get mcpPageBackTooltip => '返回';

  @override
  String get mcpPageAddMcpTooltip => '添加 MCP';

  @override
  String get mcpPageNoServers => '暂无 MCP 服务器';

  @override
  String get mcpPageErrorDialogTitle => '连接错误';

  @override
  String get mcpPageErrorNoDetails => '未提供错误详情';

  @override
  String get mcpPageClose => '关闭';

  @override
  String get mcpPageReconnect => '重新连接';

  @override
  String get mcpPageStatusConnected => '已连接';

  @override
  String get mcpPageStatusConnecting => '连接中…';

  @override
  String get mcpPageStatusDisconnected => '未连接';

  @override
  String get mcpPageStatusDisabled => '已禁用';

  @override
  String mcpPageToolsCount(int enabled, int total) {
    return '工具: $enabled/$total';
  }

  @override
  String get mcpPageConnectionFailed => '连接失败';

  @override
  String get mcpPageDetails => '详情';

  @override
  String get mcpPageDelete => '删除';

  @override
  String get mcpPageConfirmDeleteTitle => '确认删除';

  @override
  String get mcpPageConfirmDeleteContent => '删除后可通过撤销恢复。是否删除？';

  @override
  String get mcpPageServerDeleted => '已删除服务器';

  @override
  String get mcpPageUndo => '撤销';

  @override
  String get mcpPageCancel => '取消';

  @override
  String get mcpConversationSheetTitle => 'MCP服务器';

  @override
  String get mcpConversationSheetSubtitle => '选择在此助手中启用的服务';

  @override
  String get mcpConversationSheetSelectAll => '全选';

  @override
  String get mcpConversationSheetClearAll => '全不选';

  @override
  String get mcpConversationSheetNoRunning => '暂无已启动的 MCP 服务器';

  @override
  String get mcpConversationSheetConnected => '已连接';

  @override
  String mcpConversationSheetToolsCount(int enabled, int total) {
    return '工具: $enabled/$total';
  }

  @override
  String get mcpServerEditSheetEnabledLabel => '是否启用';

  @override
  String get mcpServerEditSheetNameLabel => '名称';

  @override
  String get mcpServerEditSheetTransportLabel => '传输类型';

  @override
  String get mcpServerEditSheetSseRetryHint => '如果SSE连接失败，请多试几次';

  @override
  String get mcpServerEditSheetUrlLabel => '服务器地址';

  @override
  String get mcpServerEditSheetCustomHeadersTitle => '自定义请求头';

  @override
  String get mcpServerEditSheetHeaderNameLabel => '请求头名称';

  @override
  String get mcpServerEditSheetHeaderNameHint => '如 Authorization';

  @override
  String get mcpServerEditSheetHeaderValueLabel => '请求头值';

  @override
  String get mcpServerEditSheetHeaderValueHint => '如 Bearer xxxxxx';

  @override
  String get mcpServerEditSheetRemoveHeaderTooltip => '删除';

  @override
  String get mcpServerEditSheetAddHeader => '添加请求头';

  @override
  String get mcpServerEditSheetTitleEdit => '编辑 MCP';

  @override
  String get mcpServerEditSheetTitleAdd => '添加 MCP';

  @override
  String get mcpServerEditSheetSyncToolsTooltip => '同步工具';

  @override
  String get mcpServerEditSheetTabBasic => '基础设置';

  @override
  String get mcpServerEditSheetTabTools => '工具';

  @override
  String get mcpServerEditSheetNoToolsHint => '暂无工具，点击上方同步';

  @override
  String get mcpServerEditSheetCancel => '取消';

  @override
  String get mcpServerEditSheetSave => '保存';

  @override
  String get mcpServerEditSheetUrlRequired => '请输入服务器地址';

  @override
  String get defaultModelPageBackTooltip => '返回';

  @override
  String get defaultModelPageTitle => '默认模型';

  @override
  String get defaultModelPageChatModelTitle => '聊天模型';

  @override
  String get defaultModelPageChatModelSubtitle => '全局默认的聊天模型';

  @override
  String get defaultModelPageTitleModelTitle => '标题总结模型';

  @override
  String get defaultModelPageTitleModelSubtitle => '用于总结对话标题的模型，推荐使用快速且便宜的模型';

  @override
  String get defaultModelPageTranslateModelTitle => '翻译模型';

  @override
  String get defaultModelPageTranslateModelSubtitle =>
      '用于翻译消息内容的模型，推荐使用快速且准确的模型';

  @override
  String get defaultModelPageOcrModelTitle => 'OCR 模型';

  @override
  String get defaultModelPageOcrModelSubtitle => '用于对图片执行文字识别的模型';

  @override
  String get defaultModelPagePromptLabel => '提示词';

  @override
  String get defaultModelPageTitlePromptHint => '输入用于标题总结的提示词模板';

  @override
  String get defaultModelPageTranslatePromptHint => '输入用于翻译的提示词模板';

  @override
  String get defaultModelPageOcrPromptHint => '输入用于 OCR 识别的提示词模板';

  @override
  String get defaultModelPageResetDefault => '重置为默认';

  @override
  String get defaultModelPageSave => '保存';

  @override
  String defaultModelPageTitleVars(String contentVar, String localeVar) {
    return '变量: 对话内容: $contentVar, 语言: $localeVar';
  }

  @override
  String defaultModelPageTranslateVars(String sourceVar, String targetVar) {
    return '变量：原始文本：$sourceVar，目标语言：$targetVar';
  }

  @override
  String get defaultModelPageUseCurrentModel => '使用当前对话模型';

  @override
  String get translatePagePasteButton => '粘贴';

  @override
  String get translatePageCopyResult => '复制结果';

  @override
  String get translatePageClearAll => '清空全部';

  @override
  String get translatePageInputHint => '输入要翻译的内容…';

  @override
  String get translatePageOutputHint => '翻译结果会显示在这里…';

  @override
  String get modelDetailSheetAddModel => '添加模型';

  @override
  String get modelDetailSheetEditModel => '编辑模型';

  @override
  String get modelDetailSheetBasicTab => '基本设置';

  @override
  String get modelDetailSheetAdvancedTab => '高级设置';

  @override
  String get modelDetailSheetBuiltinToolsTab => '内置工具';

  @override
  String get modelDetailSheetModelIdLabel => '模型 ID';

  @override
  String get modelDetailSheetModelIdHint => '必填，建议小写字母、数字、连字符';

  @override
  String modelDetailSheetModelIdDisabledHint(String modelId) {
    return '$modelId';
  }

  @override
  String get modelDetailSheetModelNameLabel => '模型名称';

  @override
  String get modelDetailSheetModelTypeLabel => '模型类型';

  @override
  String get modelDetailSheetChatType => '聊天';

  @override
  String get modelDetailSheetEmbeddingType => '嵌入';

  @override
  String get modelDetailSheetInputModesLabel => '输入模式';

  @override
  String get modelDetailSheetOutputModesLabel => '输出模式';

  @override
  String get modelDetailSheetAbilitiesLabel => '能力';

  @override
  String get modelDetailSheetTextMode => '文本';

  @override
  String get modelDetailSheetImageMode => '图片';

  @override
  String get modelDetailSheetToolsAbility => '工具';

  @override
  String get modelDetailSheetReasoningAbility => '推理';

  @override
  String get modelDetailSheetProviderOverrideDescription =>
      '供应商重写：允许为特定模型自定义供应商设置。（暂未实现）';

  @override
  String get modelDetailSheetAddProviderOverride => '添加供应商重写';

  @override
  String get modelDetailSheetCustomHeadersTitle => '自定义 Headers';

  @override
  String get modelDetailSheetAddHeader => '添加 Header';

  @override
  String get modelDetailSheetCustomBodyTitle => '自定义 Body';

  @override
  String get modelFetchInvertTooltip => '反选';

  @override
  String get modelDetailSheetAddBody => '添加 Body';

  @override
  String get modelDetailSheetBuiltinToolsDescription => '内置工具仅支持官方 API。';

  @override
  String get modelDetailSheetGeminiCodeExecutionMutuallyExclusiveHint =>
      '代码执行无法与搜索/URL 上下文/MCP 工具共存。';

  @override
  String get modelDetailSheetBuiltinToolsUnsupportedHint => '当前供应商不支持这些内置工具。';

  @override
  String get modelDetailSheetSearchTool => '搜索';

  @override
  String get modelDetailSheetSearchToolDescription => '启用 Google 搜索集成';

  @override
  String get modelDetailSheetUrlContextTool => 'URL 上下文';

  @override
  String get modelDetailSheetUrlContextToolDescription => '启用 URL 内容处理';

  @override
  String get modelDetailSheetCodeExecutionTool => '代码执行';

  @override
  String get modelDetailSheetCodeExecutionToolDescription => '启用代码执行工具';

  @override
  String get modelDetailSheetYoutubeTool => 'YouTube';

  @override
  String get modelDetailSheetYoutubeToolDescription =>
      '启用 YouTube 链接读取（自动识别提示词中的链接）';

  @override
  String get modelDetailSheetOpenaiBuiltinToolsResponsesOnlyHint =>
      '需要启用 OpenAI Responses API。';

  @override
  String get modelDetailSheetOpenaiCodeInterpreterTool => '代码解释器';

  @override
  String get modelDetailSheetOpenaiCodeInterpreterToolDescription =>
      '启用代码解释器工具（容器自动，内存上限 4g）';

  @override
  String get modelDetailSheetOpenaiImageGenerationTool => '图像生成';

  @override
  String get modelDetailSheetOpenaiImageGenerationToolDescription => '启用图像生成工具';

  @override
  String get modelDetailSheetCancelButton => '取消';

  @override
  String get modelDetailSheetAddButton => '添加';

  @override
  String get modelDetailSheetConfirmButton => '确认';

  @override
  String get modelDetailSheetInvalidIdError => '请输入有效的模型 ID（不少于2个字符）';

  @override
  String get modelDetailSheetModelIdExistsError => '模型 ID 已存在';

  @override
  String get modelDetailSheetHeaderKeyHint => 'Header Key';

  @override
  String get modelDetailSheetHeaderValueHint => 'Header Value';

  @override
  String get modelDetailSheetBodyKeyHint => 'Body Key';

  @override
  String get modelDetailSheetBodyJsonHint => 'Body JSON';

  @override
  String get modelSelectSheetSearchHint => '搜索模型或服务商';

  @override
  String get modelSelectSheetFavoritesSection => '收藏';

  @override
  String get modelSelectSheetFavoriteTooltip => '收藏';

  @override
  String get modelSelectSheetChatType => '聊天';

  @override
  String get modelSelectSheetEmbeddingType => '嵌入';

  @override
  String get providerDetailPageShareTooltip => '分享';

  @override
  String get providerDetailPageDeleteProviderTooltip => '删除供应商';

  @override
  String get providerDetailPageDeleteProviderTitle => '删除供应商';

  @override
  String get providerDetailPageDeleteProviderContent => '确定要删除该供应商吗？此操作不可撤销。';

  @override
  String get providerDetailPageCancelButton => '取消';

  @override
  String get providerDetailPageDeleteButton => '删除';

  @override
  String get providerDetailPageProviderDeletedSnackbar => '已删除供应商';

  @override
  String get providerDetailPageConfigTab => '配置';

  @override
  String get providerDetailPageModelsTab => '模型';

  @override
  String get providerDetailPageNetworkTab => '网络代理';

  @override
  String get providerDetailPageEnabledTitle => '是否启用';

  @override
  String get providerDetailPageManageSectionTitle => '管理';

  @override
  String get providerDetailPageNameLabel => '名称';

  @override
  String get providerDetailPageApiKeyHint => '留空则使用上层默认';

  @override
  String get providerDetailPageHideTooltip => '隐藏';

  @override
  String get providerDetailPageShowTooltip => '显示';

  @override
  String get providerDetailPageApiPathLabel => 'API 路径';

  @override
  String get providerDetailPageResponseApiTitle => 'Response API (/responses)';

  @override
  String get providerDetailPageAihubmixAppCodeLabel => '应用 Code（享 10% 优惠）';

  @override
  String get providerDetailPageAihubmixAppCodeHelp =>
      '为请求附加 APP-Code，可享 10% 优惠，仅对 AIhubmix 生效。';

  @override
  String get providerDetailPageVertexAiTitle => 'Vertex AI';

  @override
  String get providerDetailPageLocationLabel => '区域 Location';

  @override
  String get providerDetailPageProjectIdLabel => '项目 ID';

  @override
  String get providerDetailPageServiceAccountJsonLabel => '服务账号 JSON（粘贴或导入）';

  @override
  String get providerDetailPageImportJsonButton => '导入 JSON';

  @override
  String get providerDetailPageTestButton => '测试';

  @override
  String get providerDetailPageSaveButton => '保存';

  @override
  String get providerDetailPageProviderRemovedMessage => '供应商已删除';

  @override
  String get providerDetailPageNoModelsTitle => '暂无模型';

  @override
  String get providerDetailPageNoModelsSubtitle => '点击下方按钮添加模型';

  @override
  String get providerDetailPageDeleteModelButton => '删除';

  @override
  String get providerDetailPageConfirmDeleteTitle => '确认删除';

  @override
  String get providerDetailPageConfirmDeleteContent => '删除后可通过撤销恢复。是否删除？';

  @override
  String get providerDetailPageModelDeletedSnackbar => '已删除模型';

  @override
  String get providerDetailPageUndoButton => '撤销';

  @override
  String get providerDetailPageAddNewModelButton => '添加新模型';

  @override
  String get providerDetailPageFetchModelsButton => '获取';

  @override
  String get providerDetailPageEnableProxyTitle => '是否启用代理';

  @override
  String get providerDetailPageHostLabel => '主机地址';

  @override
  String get providerDetailPagePortLabel => '端口';

  @override
  String get providerDetailPageUsernameOptionalLabel => '用户名（可选）';

  @override
  String get providerDetailPagePasswordOptionalLabel => '密码（可选）';

  @override
  String get providerDetailPageSavedSnackbar => '已保存';

  @override
  String get providerDetailPageEmbeddingsGroupTitle => '嵌入';

  @override
  String get providerDetailPageOtherModelsGroupTitle => '其他模型';

  @override
  String get providerGroupLabel => '分组';

  @override
  String get providerGroupAuto => '自动';

  @override
  String get providerGroupOfficial => '官方';

  @override
  String get providerGroupSelfHosted => '自建';

  @override
  String get providerGroupLocal => '本地';

  @override
  String get providerGroupPublic => '公益站';

  @override
  String get providerDetailPageRemoveGroupTooltip => '移除本组';

  @override
  String get providerDetailPageAddGroupTooltip => '添加本组';

  @override
  String get providerDetailPageFilterHint => '输入模型名称筛选';

  @override
  String get providerDetailPageDeleteText => '删除';

  @override
  String get providerDetailPageEditTooltip => '编辑';

  @override
  String get providerDetailPageTestConnectionTitle => '测试连接';

  @override
  String get providerDetailPageSelectModelButton => '选择模型';

  @override
  String get providerDetailPageChangeButton => '更换';

  @override
  String get providerDetailPageUseStreamingLabel => '使用流式';

  @override
  String get providerDetailPageTestingMessage => '正在测试…';

  @override
  String get providerDetailPageTestSuccessMessage => '测试成功';

  @override
  String get providersPageTitle => '供应商';

  @override
  String get providersPageImportTooltip => '导入';

  @override
  String get providersPageAddTooltip => '新增';

  @override
  String get providersPageProviderAddedSnackbar => '已添加供应商';

  @override
  String get providersPageSiliconFlowName => '硅基流动';

  @override
  String get providersPageAliyunName => '阿里云千问';

  @override
  String get providersPageZhipuName => '智谱';

  @override
  String get providersPageByteDanceName => '火山引擎';

  @override
  String get providersPageEnabledStatus => '启用';

  @override
  String get providersPageDisabledStatus => '禁用';

  @override
  String get providersPageModelsCountSuffix => ' models';

  @override
  String get providersPageModelsCountSingleSuffix => '个模型';

  @override
  String get addProviderSheetTitle => '添加供应商';

  @override
  String get addProviderSheetEnabledLabel => '是否启用';

  @override
  String get addProviderSheetNameLabel => '名称';

  @override
  String get addProviderSheetApiPathLabel => 'API 路径';

  @override
  String get addProviderSheetVertexAiLocationLabel => '位置';

  @override
  String get addProviderSheetVertexAiProjectIdLabel => '项目ID';

  @override
  String get addProviderSheetVertexAiServiceAccountJsonLabel =>
      '服务账号 JSON（粘贴或导入）';

  @override
  String get addProviderSheetImportJsonButton => '导入 JSON';

  @override
  String get addProviderSheetCancelButton => '取消';

  @override
  String get addProviderSheetAddButton => '添加';

  @override
  String get importProviderSheetTitle => '导入供应商';

  @override
  String get importProviderSheetScanQrTooltip => '扫码导入';

  @override
  String get importProviderSheetFromGalleryTooltip => '从相册导入';

  @override
  String importProviderSheetImportSuccessMessage(int count) {
    return '已导入$count个供应商';
  }

  @override
  String importProviderSheetImportFailedMessage(String error) {
    return '导入失败: $error';
  }

  @override
  String get importProviderSheetDescription =>
      '粘贴分享字符串（可多行，每行一个）或 ChatBox JSON';

  @override
  String get importProviderSheetInputHint => 'ai-provider:v1:...';

  @override
  String get importProviderSheetCancelButton => '取消';

  @override
  String get importProviderSheetImportButton => '导入';

  @override
  String get shareProviderSheetTitle => '分享供应商配置';

  @override
  String get shareProviderSheetDescription => '复制下面的分享字符串，或使用二维码分享。';

  @override
  String get shareProviderSheetCopiedMessage => '已复制';

  @override
  String get shareProviderSheetCopyButton => '复制';

  @override
  String get shareProviderSheetShareButton => '分享';

  @override
  String get desktopProviderContextMenuShare => '分享';

  @override
  String get desktopProviderShareCopyText => '复制文字';

  @override
  String get desktopProviderShareCopyQr => '复制二维码';

  @override
  String get providerDetailPageApiBaseUrlLabel => 'API Base URL';

  @override
  String get providerDetailPageModelsTitle => '模型';

  @override
  String get providerModelsGetButton => '获取';

  @override
  String get providerDetailPageCapsVision => '视觉';

  @override
  String get providerDetailPageCapsImage => '生图';

  @override
  String get providerDetailPageCapsTool => '工具';

  @override
  String get providerDetailPageCapsReasoning => '推理';

  @override
  String get qrScanPageTitle => '扫码导入';

  @override
  String get qrScanPageInstruction => '将二维码对准取景框';

  @override
  String get searchServicesPageBackTooltip => '返回';

  @override
  String get searchServicesPageTitle => '搜索服务';

  @override
  String get searchServicesPageDone => '完成';

  @override
  String get searchServicesPageEdit => '编辑';

  @override
  String get searchServicesPageAddProvider => '添加提供商';

  @override
  String get searchServicesPageSearchProviders => '搜索提供商';

  @override
  String get searchServicesPageGeneralOptions => '通用选项';

  @override
  String get searchServicesPageAutoTestTitle => '启动时自动测试连接';

  @override
  String get searchServicesPageMaxResults => '最大结果数';

  @override
  String get searchServicesPageTimeoutSeconds => '超时时间（秒）';

  @override
  String get searchServicesPageAtLeastOneServiceRequired => '至少需要一个搜索服务';

  @override
  String get searchServicesPageTestingStatus => '测试中…';

  @override
  String get searchServicesPageConnectedStatus => '已连接';

  @override
  String get searchServicesPageFailedStatus => '连接失败';

  @override
  String get searchServicesPageNotTestedStatus => '未测试';

  @override
  String get searchServicesPageEditServiceTooltip => '编辑服务';

  @override
  String get searchServicesPageTestConnectionTooltip => '测试连接';

  @override
  String get searchServicesPageDeleteServiceTooltip => '删除服务';

  @override
  String get searchServicesPageConfiguredStatus => '已配置';

  @override
  String get miniMapTitle => '迷你地图';

  @override
  String get miniMapTooltip => '迷你地图';

  @override
  String get searchServicesPageApiKeyRequiredStatus => '需要 API Key';

  @override
  String get searchServicesPageUrlRequiredStatus => '需要 URL';

  @override
  String get searchServicesAddDialogTitle => '添加搜索服务';

  @override
  String get searchServicesAddDialogServiceType => '服务类型';

  @override
  String get searchServicesAddDialogBingLocal => '本地';

  @override
  String get searchServicesAddDialogCancel => '取消';

  @override
  String get searchServicesAddDialogAdd => '添加';

  @override
  String get searchServicesAddDialogApiKeyRequired => 'API Key 必填';

  @override
  String get searchServicesAddDialogInstanceUrl => '实例 URL';

  @override
  String get searchServicesAddDialogUrlRequired => 'URL 必填';

  @override
  String get searchServicesAddDialogEnginesOptional => '搜索引擎（可选）';

  @override
  String get searchServicesAddDialogLanguageOptional => '语言（可选）';

  @override
  String get searchServicesAddDialogUsernameOptional => '用户名（可选）';

  @override
  String get searchServicesAddDialogPasswordOptional => '密码（可选）';

  @override
  String get searchServicesAddDialogRegionOptional => '地区（可选，默认 us-en）';

  @override
  String get searchServicesEditDialogEdit => '编辑';

  @override
  String get searchServicesEditDialogCancel => '取消';

  @override
  String get searchServicesEditDialogSave => '保存';

  @override
  String get searchServicesEditDialogBingLocalNoConfig => 'Bing 本地搜索不需要配置。';

  @override
  String get searchServicesEditDialogApiKeyRequired => 'API Key 必填';

  @override
  String get searchServicesEditDialogInstanceUrl => '实例 URL';

  @override
  String get searchServicesEditDialogUrlRequired => 'URL 必填';

  @override
  String get searchServicesEditDialogEnginesOptional => '搜索引擎（可选）';

  @override
  String get searchServicesEditDialogLanguageOptional => '语言（可选）';

  @override
  String get searchServicesEditDialogUsernameOptional => '用户名（可选）';

  @override
  String get searchServicesEditDialogPasswordOptional => '密码（可选）';

  @override
  String get searchServicesEditDialogRegionOptional => '地区（可选，默认 us-en）';

  @override
  String get searchSettingsSheetTitle => '搜索设置';

  @override
  String get searchSettingsSheetBuiltinSearchTitle => '模型内置搜索';

  @override
  String get searchSettingsSheetBuiltinSearchDescription => '是否启用模型内置的搜索功能';

  @override
  String get searchSettingsSheetWebSearchTitle => '网络搜索';

  @override
  String get searchSettingsSheetWebSearchDescription => '是否启用网页搜索';

  @override
  String get searchSettingsSheetOpenSearchServicesTooltip => '打开搜索服务设置';

  @override
  String get searchSettingsSheetNoServicesMessage => '暂无可用服务，请先在\"搜索服务\"中添加';

  @override
  String get aboutPageEasterEggMessage => '\n（好吧现在还没彩蛋）';

  @override
  String get aboutPageEasterEggButton => '好的';

  @override
  String get aboutPageAppDescription => '开源 AI 助手';

  @override
  String get aboutPageNoQQGroup => '暂无QQ群';

  @override
  String get aboutPageVersion => '版本';

  @override
  String get aboutPageSystem => '系统';

  @override
  String get aboutPageWebsite => '官网';

  @override
  String get aboutPageLicense => '许可证';

  @override
  String get aboutPageJoinQQGroup => '加入QQ群';

  @override
  String get aboutPageJoinDiscord => '在 Discord 中加入我们';

  @override
  String get displaySettingsPageShowUserAvatarTitle => '显示用户头像';

  @override
  String get displaySettingsPageShowUserAvatarSubtitle => '是否在聊天消息中显示用户头像';

  @override
  String get displaySettingsPageShowUserNameTimestampTitle => '显示用户名称和时间戳';

  @override
  String get displaySettingsPageShowUserNameTimestampSubtitle =>
      '是否在聊天消息中显示用户名称和时间戳';

  @override
  String get displaySettingsPageShowUserMessageActionsTitle => '显示用户消息操作按钮';

  @override
  String get displaySettingsPageShowUserMessageActionsSubtitle =>
      '在用户消息下方显示复制、重发与更多按钮';

  @override
  String get displaySettingsPageShowModelNameTimestampTitle => '显示模型名称和时间戳';

  @override
  String get displaySettingsPageShowModelNameTimestampSubtitle =>
      '是否在聊天消息中显示模型名称和时间戳';

  @override
  String get displaySettingsPageChatModelIconTitle => '聊天列表模型图标';

  @override
  String get displaySettingsPageChatModelIconSubtitle => '是否在聊天消息中显示模型图标';

  @override
  String get displaySettingsPageShowTokenStatsTitle => '显示Token和上下文统计';

  @override
  String get displaySettingsPageShowTokenStatsSubtitle => '显示 token 用量与消息数量';

  @override
  String get displaySettingsPageAutoCollapseThinkingTitle => '自动折叠思考';

  @override
  String get displaySettingsPageAutoCollapseThinkingSubtitle =>
      '思考完成后自动折叠，保持界面简洁';

  @override
  String get displaySettingsPageShowChatListDateTitle => '显示对话列表日期';

  @override
  String get displaySettingsPageShowChatListDateSubtitle => '在左侧对话列表中显示日期分组标签';

  @override
  String get displaySettingsPageKeepSidebarOpenOnAssistantTapTitle =>
      '点选助手时不自动关闭侧边栏';

  @override
  String get displaySettingsPageKeepSidebarOpenOnTopicTapTitle =>
      '点选话题时不自动关闭侧边栏';

  @override
  String get displaySettingsPageKeepAssistantListExpandedOnSidebarCloseTitle =>
      '关闭侧边栏时不折叠助手列表';

  @override
  String get displaySettingsPageShowUpdatesTitle => '显示更新';

  @override
  String get displaySettingsPageShowUpdatesSubtitle => '显示应用更新通知';

  @override
  String get displaySettingsPageMessageNavButtonsTitle => '消息导航按钮';

  @override
  String get displaySettingsPageMessageNavButtonsSubtitle => '滚动时显示快速跳转按钮';

  @override
  String get displaySettingsPageHapticsOnSidebarTitle => '侧边栏触觉反馈';

  @override
  String get displaySettingsPageHapticsOnSidebarSubtitle => '打开/关闭侧边栏时启用触觉反馈';

  @override
  String get displaySettingsPageHapticsGlobalTitle => '全局触觉反馈';

  @override
  String get displaySettingsPageHapticsIosSwitchTitle => '开关触觉反馈';

  @override
  String get displaySettingsPageHapticsOnListItemTapTitle => '列表项触觉反馈';

  @override
  String get displaySettingsPageHapticsOnCardTapTitle => '卡片触觉反馈';

  @override
  String get displaySettingsPageHapticsOnGenerateTitle => '消息生成触觉反馈';

  @override
  String get displaySettingsPageHapticsOnGenerateSubtitle => '生成消息时启用触觉反馈';

  @override
  String get displaySettingsPageNewChatAfterDeleteTitle => '删除话题后新建对话';

  @override
  String get displaySettingsPageNewChatOnAssistantSwitchTitle => '切换助手时新建对话';

  @override
  String get displaySettingsPageNewChatOnLaunchTitle => '启动时新建对话';

  @override
  String get displaySettingsPageAutoSwitchTopicsTitle => '自动切换话题';

  @override
  String get desktopDisplaySettingsTopicPositionTitle => '话题位置';

  @override
  String get desktopDisplaySettingsTopicPositionLeft => '左侧';

  @override
  String get desktopDisplaySettingsTopicPositionRight => '右侧';

  @override
  String get displaySettingsPageNewChatOnLaunchSubtitle => '应用启动时自动创建新对话';

  @override
  String get displaySettingsPageChatFontSizeTitle => '聊天字体大小';

  @override
  String get displaySettingsPageAutoScrollEnableTitle => '自动回到底部';

  @override
  String get displaySettingsPageAutoScrollIdleTitle => '自动回到底部延迟';

  @override
  String get displaySettingsPageAutoScrollIdleSubtitle => '用户停止滚动后等待多久再自动回到底部';

  @override
  String get displaySettingsPageAutoScrollDisabledLabel => '已关闭';

  @override
  String get displaySettingsPageChatFontSampleText => '这是一个示例的聊天文本';

  @override
  String get displaySettingsPageChatBackgroundMaskTitle => '背景图片遮罩透明度';

  @override
  String get displaySettingsPageThemeSettingsTitle => '主题设置';

  @override
  String get displaySettingsPageThemeColorTitle => '主题颜色';

  @override
  String get desktopSettingsFontsTitle => '字体设置';

  @override
  String get displaySettingsPageTrayTitle => '托盘';

  @override
  String get displaySettingsPageTrayShowTrayTitle => '显示托盘图标';

  @override
  String get displaySettingsPageTrayMinimizeOnCloseTitle => '关闭时最小化到托盘';

  @override
  String get desktopFontAppLabel => '应用字体';

  @override
  String get desktopFontCodeLabel => '代码字体';

  @override
  String get desktopFontFamilySystemDefault => '系统默认';

  @override
  String get desktopFontFamilyMonospaceDefault => '系统默认';

  @override
  String get desktopFontFilterHint => '输入以过滤字体…';

  @override
  String get displaySettingsPageAppFontTitle => '应用字体';

  @override
  String get displaySettingsPageCodeFontTitle => '代码字体';

  @override
  String get fontPickerChooseLocalFile => '选择本地文件';

  @override
  String get fontPickerGetFromGoogleFonts => '从 Google Fonts 获取';

  @override
  String get fontPickerFilterHint => '输入以过滤字体…';

  @override
  String get desktopFontLoading => '正在加载字体…';

  @override
  String get displaySettingsPageFontLocalFileLabel => '本地文件';

  @override
  String get displaySettingsPageFontResetLabel => '恢复默认';

  @override
  String get displaySettingsPageOtherSettingsTitle => '其他设置';

  @override
  String get themeSettingsPageDynamicColorSection => '动态颜色';

  @override
  String get themeSettingsPageUseDynamicColorTitle => '系统动态配色';

  @override
  String get themeSettingsPageUseDynamicColorSubtitle => '跟随系统取色（Android 12+）';

  @override
  String get themeSettingsPageUsePureBackgroundTitle => '纯色背景';

  @override
  String get themeSettingsPageUsePureBackgroundSubtitle => '仅气泡与强调色随主题变化';

  @override
  String get themeSettingsPageColorPalettesSection => '配色方案';

  @override
  String get ttsServicesPageBackButton => '返回';

  @override
  String get ttsServicesPageTitle => '语音服务';

  @override
  String get ttsServicesPageAddTooltip => '新增';

  @override
  String get ttsServicesPageAddNotImplemented => '新增 TTS 服务暂未实现';

  @override
  String get ttsServicesPageSystemTtsTitle => '系统TTS';

  @override
  String get ttsServicesPageSystemTtsAvailableSubtitle => '使用系统内置语音合成';

  @override
  String ttsServicesPageSystemTtsUnavailableSubtitle(String error) {
    return '不可用：$error';
  }

  @override
  String get ttsServicesPageSystemTtsUnavailableNotInitialized => '未初始化';

  @override
  String get ttsServicesPageTestSpeechText => '你好，这是一次测试语音。';

  @override
  String get ttsServicesPageConfigureTooltip => '配置';

  @override
  String get ttsServicesPageTestVoiceTooltip => '测试语音';

  @override
  String get ttsServicesPageStopTooltip => '停止';

  @override
  String get ttsServicesPageDeleteTooltip => '删除';

  @override
  String get ttsServicesPageSystemTtsSettingsTitle => '系统 TTS 设置';

  @override
  String get ttsServicesPageEngineLabel => '引擎';

  @override
  String get ttsServicesPageAutoLabel => '自动';

  @override
  String get ttsServicesPageLanguageLabel => '语言';

  @override
  String get ttsServicesPageSpeechRateLabel => '语速';

  @override
  String get ttsServicesPagePitchLabel => '音调';

  @override
  String get ttsServicesPageSettingsSavedMessage => '设置已保存。';

  @override
  String get ttsServicesPageDoneButton => '完成';

  @override
  String get ttsServicesPageNetworkSectionTitle => '网络 TTS';

  @override
  String get ttsServicesPageNoNetworkServices => '暂无语音服务';

  @override
  String get ttsServicesDialogAddTitle => '添加语音服务';

  @override
  String get ttsServicesDialogEditTitle => '编辑语音服务';

  @override
  String get ttsServicesDialogProviderType => '服务提供方';

  @override
  String get ttsServicesDialogCancelButton => '取消';

  @override
  String get ttsServicesDialogAddButton => '添加';

  @override
  String get ttsServicesDialogSaveButton => '保存';

  @override
  String get ttsServicesFieldNameLabel => '名称';

  @override
  String get ttsServicesFieldApiKeyLabel => 'API Key';

  @override
  String get ttsServicesFieldBaseUrlLabel => 'API 基址';

  @override
  String get ttsServicesFieldModelLabel => '模型';

  @override
  String get ttsServicesFieldVoiceLabel => '音色';

  @override
  String get ttsServicesFieldVoiceIdLabel => '音色 ID';

  @override
  String get ttsServicesFieldEmotionLabel => '情感';

  @override
  String get ttsServicesFieldSpeedLabel => '语速';

  @override
  String get ttsServicesViewDetailsButton => '查看详情';

  @override
  String get ttsServicesDialogErrorTitle => '错误详情';

  @override
  String get ttsServicesCloseButton => '关闭';

  @override
  String imageViewerPageShareFailedOpenFile(String message) {
    return '无法分享，已尝试打开文件: $message';
  }

  @override
  String imageViewerPageShareFailed(String error) {
    return '分享失败: $error';
  }

  @override
  String get imageViewerPageShareButton => '分享图片';

  @override
  String get imageViewerPageSaveButton => '保存图片';

  @override
  String get imageViewerPageSaveSuccess => '已保存到相册';

  @override
  String imageViewerPageSaveFailed(String error) {
    return '保存失败: $error';
  }

  @override
  String get settingsShare => 'Kelivo - 开源AI助手';

  @override
  String get searchProviderBingLocalDescription =>
      '使用网络抓取工具获取必应搜索结果。无需 API 密钥，但可能不够稳定。';

  @override
  String get searchProviderDuckDuckGoDescription =>
      '基于 DDGS 的 DuckDuckGo 隐私搜索，无需 API 密钥，支持设置地区。';

  @override
  String get searchProviderBraveDescription => 'Brave 独立搜索引擎。注重隐私，无跟踪或画像。';

  @override
  String get searchProviderExaDescription => '具备语义理解的神经搜索引擎。适合研究与查找特定内容。';

  @override
  String get searchProviderLinkUpDescription =>
      '提供来源可追溯答案的搜索 API，同时提供搜索结果与 AI 摘要。';

  @override
  String get searchProviderMetasoDescription => '秘塔中文搜索引擎。面向中文内容优化并提供 AI 能力。';

  @override
  String get searchProviderSearXNGDescription => '注重隐私的元搜索引擎。需自建实例，无跟踪。';

  @override
  String get searchProviderTavilyDescription =>
      '为大型语言模型（LLMs）优化的 AI 搜索 API，提供高质量、相关的搜索结果。';

  @override
  String get searchProviderZhipuDescription =>
      '智谱 AI 旗下中文 AI 搜索服务，针对中文内容与查询进行了优化。';

  @override
  String get searchProviderOllamaDescription =>
      'Ollama 网络搜索 API。为模型补充最新信息，减少幻觉并提升准确性。';

  @override
  String get searchProviderJinaDescription => '适合开发者和企业用于 AI 搜索应用。支持多语言与多模态。';

  @override
  String get searchServiceNameBingLocal => 'Bing（Local）';

  @override
  String get searchServiceNameDuckDuckGo => 'DuckDuckGo';

  @override
  String get searchServiceNameTavily => 'Tavily';

  @override
  String get searchServiceNameExa => 'Exa';

  @override
  String get searchServiceNameZhipu => '智谱';

  @override
  String get searchServiceNameSearXNG => 'SearXNG';

  @override
  String get searchServiceNameLinkUp => 'LinkUp';

  @override
  String get searchServiceNameBrave => 'Brave';

  @override
  String get searchServiceNameMetaso => '秘塔';

  @override
  String get searchServiceNameOllama => 'Ollama';

  @override
  String get searchServiceNameJina => 'Jina';

  @override
  String get searchServiceNamePerplexity => 'Perplexity';

  @override
  String get searchProviderPerplexityDescription =>
      'Perplexity 搜索 API。提供排序的网页结果，支持区域与域名过滤。';

  @override
  String get searchServiceNameBocha => '博查';

  @override
  String get searchProviderBochaDescription =>
      '博查 AI 全网网页搜索，支持时间范围与摘要，更适合 AI 使用。';

  @override
  String get generationInterrupted => '生成已中断';

  @override
  String get titleForLocale => '新对话';

  @override
  String get quickPhraseBackTooltip => '返回';

  @override
  String get quickPhraseGlobalTitle => '快捷短语';

  @override
  String get quickPhraseAssistantTitle => '助手快捷短语';

  @override
  String get quickPhraseAddTooltip => '添加快捷短语';

  @override
  String get quickPhraseEmptyMessage => '暂无快捷短语';

  @override
  String get quickPhraseAddTitle => '添加快捷短语';

  @override
  String get quickPhraseEditTitle => '编辑快捷短语';

  @override
  String get quickPhraseTitleLabel => '标题';

  @override
  String get quickPhraseContentLabel => '内容';

  @override
  String get quickPhraseCancelButton => '取消';

  @override
  String get quickPhraseSaveButton => '保存';

  @override
  String get instructionInjectionTitle => '指令注入';

  @override
  String get instructionInjectionBackTooltip => '返回';

  @override
  String get instructionInjectionAddTooltip => '添加指令注入';

  @override
  String get instructionInjectionImportTooltip => '从文件导入';

  @override
  String get instructionInjectionEmptyMessage => '暂无指令注入卡片';

  @override
  String get instructionInjectionDefaultTitle => '学习模式';

  @override
  String get instructionInjectionAddTitle => '添加指令注入';

  @override
  String get instructionInjectionEditTitle => '编辑指令注入';

  @override
  String get instructionInjectionNameLabel => '名称';

  @override
  String get instructionInjectionPromptLabel => '提示词';

  @override
  String instructionInjectionImportSuccess(int count) {
    return '已导入 $count 个指令注入';
  }

  @override
  String get instructionInjectionSheetSubtitle => '为当前对话选择并应用一条指令提示词';

  @override
  String get mcpJsonEditButtonTooltip => '编辑 JSON';

  @override
  String get mcpJsonEditTitle => '编辑json';

  @override
  String get mcpJsonEditParseFailed => 'JSON 解析失败';

  @override
  String get mcpJsonEditSavedApplied => '已保存并应用';

  @override
  String get mcpTimeoutSettingsTooltip => '设置工具调用超时';

  @override
  String get mcpTimeoutDialogTitle => '工具调用超时';

  @override
  String get mcpTimeoutSecondsLabel => '工具调用超时（秒）';

  @override
  String get mcpTimeoutInvalid => '请输入大于 0 的秒数';

  @override
  String get quickPhraseEditButton => '编辑';

  @override
  String get quickPhraseDeleteButton => '删除';

  @override
  String get quickPhraseMenuTitle => '快捷短语';

  @override
  String get chatInputBarQuickPhraseTooltip => '快捷短语';

  @override
  String get assistantEditQuickPhraseDescription => '管理该助手的快捷短语。点击下方按钮添加或编辑短语。';

  @override
  String get assistantEditManageQuickPhraseButton => '管理快捷短语';

  @override
  String get assistantEditPageMemoryTab => '记忆';

  @override
  String get assistantEditMemorySwitchTitle => '记忆';

  @override
  String get assistantEditMemorySwitchDescription => '允许助手主动存储并在对话间引用用户相关信息';

  @override
  String get assistantEditRecentChatsSwitchTitle => '参考历史聊天记录';

  @override
  String get assistantEditRecentChatsSwitchDescription =>
      '在新对话中引用最近的对话标题以增强上下文';

  @override
  String get assistantEditManageMemoryTitle => '管理记忆';

  @override
  String get assistantEditAddMemoryButton => '添加记忆';

  @override
  String get assistantEditMemoryEmpty => '暂无记忆';

  @override
  String get assistantEditMemoryDialogTitle => '记忆';

  @override
  String get assistantEditMemoryDialogHint => '输入记忆内容';

  @override
  String get assistantEditAddQuickPhraseButton => '添加快捷短语';

  @override
  String get multiKeyPageDeleteSnackbarDeletedOne => '已删除 1 个 Key';

  @override
  String get multiKeyPageUndo => '撤回';

  @override
  String get multiKeyPageUndoRestored => '已撤回删除';

  @override
  String get multiKeyPageDeleteErrorsTooltip => '删除错误';

  @override
  String get multiKeyPageDeleteErrorsConfirmTitle => '删除所有错误的 Key？';

  @override
  String get multiKeyPageDeleteErrorsConfirmContent => '这将移除所有状态为错误的 Key。';

  @override
  String multiKeyPageDeletedErrorsSnackbar(int n) {
    return '已删除 $n 个错误 Key';
  }

  @override
  String get providerDetailPageProviderTypeTitle => '供应商类型';

  @override
  String get displaySettingsPageChatItemDisplayTitle => '聊天项显示';

  @override
  String get displaySettingsPageRenderingSettingsTitle => '渲染设置';

  @override
  String get displaySettingsPageBehaviorStartupTitle => '行为与启动';

  @override
  String get displaySettingsPageHapticsSettingsTitle => '触觉反馈';

  @override
  String get assistantSettingsNoPromptPlaceholder => '暂无提示词';

  @override
  String get providersPageMultiSelectTooltip => '多选';

  @override
  String get providersPageDeleteSelectedConfirmContent =>
      '确定要删除选中的供应商吗？该操作不可撤销。';

  @override
  String get providersPageDeleteSelectedSnackbar => '已删除选中的供应商';

  @override
  String providersPageExportSelectedTitle(int count) {
    return '导出 $count 个供应商';
  }

  @override
  String get providersPageExportCopyButton => '复制';

  @override
  String get providersPageExportShareButton => '分享';

  @override
  String get providersPageExportCopiedSnackbar => '已复制导出代码';

  @override
  String get providersPageDeleteAction => '删除';

  @override
  String get providersPageExportAction => '导出';

  @override
  String get assistantEditPresetTitle => '预设对话信息';

  @override
  String get assistantEditPresetAddUser => '添加预设用户信息';

  @override
  String get assistantEditPresetAddAssistant => '添加预设助手信息';

  @override
  String get assistantEditPresetInputHintUser => '输入用户消息…';

  @override
  String get assistantEditPresetInputHintAssistant => '输入助手消息…';

  @override
  String get assistantEditPresetEmpty => '暂无预设消息';

  @override
  String get assistantEditPresetEditDialogTitle => '编辑预设消息';

  @override
  String get assistantEditPresetRoleUser => '用户';

  @override
  String get assistantEditPresetRoleAssistant => '助手';

  @override
  String get desktopTtsPleaseAddProvider => '请先在设置中添加语音服务商';

  @override
  String get settingsPageNetworkProxy => '网络代理';

  @override
  String get networkProxyEnableLabel => '启动代理';

  @override
  String get networkProxySettingsHeader => '代理设置';

  @override
  String get networkProxyType => '代理类型';

  @override
  String get networkProxyTypeHttp => 'HTTP';

  @override
  String get networkProxyTypeHttps => 'HTTPS';

  @override
  String get networkProxyTypeSocks5 => 'SOCKS5';

  @override
  String get networkProxyServerHost => '服务器地址';

  @override
  String get networkProxyPort => '端口';

  @override
  String get networkProxyUsername => '用户名';

  @override
  String get networkProxyPassword => '密码';

  @override
  String get networkProxyOptionalHint => '可选';

  @override
  String get networkProxyTestHeader => '连接测试';

  @override
  String get networkProxyTestUrlHint => '测试地址';

  @override
  String get networkProxyTestButton => '测试';

  @override
  String get networkProxyTesting => '测试中…';

  @override
  String get networkProxyTestSuccess => '连接成功';

  @override
  String networkProxyTestFailed(String error) {
    return '测试失败：$error';
  }

  @override
  String get networkProxyNoUrl => '请输入测试地址';

  @override
  String get networkProxyPriorityNote => '当同时开启全局代理与供应商代理时，将优先使用供应商代理。';

  @override
  String get desktopShowProviderInModelCapsule => '模型胶囊显示供应商';

  @override
  String get messageWebViewOpenInBrowser => '在浏览器中打开';

  @override
  String get messageWebViewConsoleLogs => '控制台日志';

  @override
  String get messageWebViewNoConsoleMessages => '暂无控制台消息';

  @override
  String get messageWebViewRefreshTooltip => '刷新';

  @override
  String get messageWebViewForwardTooltip => '前进';

  @override
  String get chatInputBarOcrTooltip => 'OCR 文字识别';

  @override
  String get providerDetailPageBatchDetectButton => '检测';

  @override
  String get providerDetailPageBatchDetecting => '检测中...';

  @override
  String get providerDetailPageBatchDetectStart => '开始检测';

  @override
  String get providerDetailPageDetectSuccess => '检测成功';

  @override
  String get providerDetailPageDetectFailed => '检测失败';

  @override
  String get providerDetailPageDeleteAllModelsWarning => '此操作不可撤回';

  @override
  String get requestLogSettingTitle => '请求日志打印';

  @override
  String get requestLogSettingSubtitle => '开启后会将请求/响应详情写入 logs/logs.txt';

  @override
  String get flutterLogSettingTitle => '应用日志打印';

  @override
  String get flutterLogSettingSubtitle =>
      '开启后会将 Flutter 错误与 print 输出写入 logs/flutter_logs.txt';

  @override
  String get logViewerTitle => '请求日志';

  @override
  String get logViewerEmpty => '暂无日志';

  @override
  String get logViewerCurrentLog => '当前日志';

  @override
  String get logViewerExport => '导出';

  @override
  String get logViewerOpenFolder => '打开日志目录';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get helloWorld => '你好，世界！';

  @override
  String get settingsPageBackButton => '返回';

  @override
  String get settingsPageTitle => '設定';

  @override
  String get settingsPageDarkMode => '深色';

  @override
  String get settingsPageLightMode => '淺色';

  @override
  String get settingsPageSystemMode => '跟隨系統';

  @override
  String get settingsPageWarningMessage => '部分服務未設定，某些功能可能不可用';

  @override
  String get settingsPageGeneralSection => '通用設定';

  @override
  String get settingsPageColorMode => '顏色模式';

  @override
  String get settingsPageDisplay => '顯示設定';

  @override
  String get settingsPageDisplaySubtitle => '介面主題與字號等外觀設定';

  @override
  String get settingsPageAssistant => '助理';

  @override
  String get settingsPageAssistantSubtitle => '預設助理與對話風格';

  @override
  String get settingsPageModelsServicesSection => '模型與服務';

  @override
  String get settingsPageDefaultModel => '預設模型';

  @override
  String get settingsPageProviders => '供應商';

  @override
  String get settingsPageHotkeys => '快捷鍵';

  @override
  String get settingsPageSearch => '搜尋服務';

  @override
  String get settingsPageTts => '語音服務';

  @override
  String get settingsPageMcp => 'MCP';

  @override
  String get settingsPageQuickPhrase => '快捷短语';

  @override
  String get settingsPageInstructionInjection => '指令注入';

  @override
  String get settingsPageDataSection => '資料設定';

  @override
  String get settingsPageBackup => '資料備份';

  @override
  String get settingsPageChatStorage => '聊天記錄儲存';

  @override
  String get settingsPageCalculating => '統計中…';

  @override
  String settingsPageFilesCount(int count, String size) {
    return '共 $count 個檔案 · $size';
  }

  @override
  String get storageSpacePageTitle => '儲存空間';

  @override
  String get storageSpaceRefreshTooltip => '重新整理';

  @override
  String get storageSpaceLoadFailed => '載入失敗';

  @override
  String get storageSpaceTotalLabel => '已用空間';

  @override
  String storageSpaceClearableLabel(String size) {
    return '可清理：$size';
  }

  @override
  String storageSpaceClearableHint(String size) {
    return '共發現可清理空間 $size';
  }

  @override
  String get storageSpaceCategoryImages => '圖片';

  @override
  String get storageSpaceCategoryFiles => '檔案';

  @override
  String get storageSpaceCategoryChatData => '聊天記錄';

  @override
  String get storageSpaceCategoryAssistantData => '助理';

  @override
  String get storageSpaceCategoryCache => '快取';

  @override
  String get storageSpaceCategoryLogs => '日誌';

  @override
  String get storageSpaceCategoryOther => '應用';

  @override
  String storageSpaceFilesCount(int count) {
    return '$count 個檔案';
  }

  @override
  String get storageSpaceSafeToClearHint => '可安全清理，不影響聊天記錄。';

  @override
  String get storageSpaceNotSafeToClearHint => '可能影響聊天記錄，請謹慎刪除。';

  @override
  String get storageSpaceBreakdownTitle => '明細';

  @override
  String get storageSpaceSubChatMessages => '訊息';

  @override
  String get storageSpaceSubChatConversations => '對話';

  @override
  String get storageSpaceSubChatToolEvents => '工具事件';

  @override
  String get storageSpaceSubAssistantAvatars => '頭像';

  @override
  String get storageSpaceSubAssistantImages => '圖片';

  @override
  String get storageSpaceSubCacheAvatars => '頭像快取';

  @override
  String get storageSpaceSubCacheOther => '其他快取';

  @override
  String get storageSpaceSubCacheSystem => '系統快取';

  @override
  String get storageSpaceSubLogsFlutter => '執行日誌';

  @override
  String get storageSpaceSubLogsRequests => '網路日誌';

  @override
  String get storageSpaceSubLogsOther => '其他日誌';

  @override
  String get storageSpaceClearConfirmTitle => '確認清理';

  @override
  String storageSpaceClearConfirmMessage(String targetName) {
    return '確定要清理 $targetName 嗎？';
  }

  @override
  String get storageSpaceClearButton => '清理';

  @override
  String storageSpaceClearDone(String targetName) {
    return '已清理 $targetName';
  }

  @override
  String storageSpaceClearFailed(String error) {
    return '清理失敗：$error';
  }

  @override
  String get storageSpaceClearAvatarCacheButton => '清理頭像快取';

  @override
  String get storageSpaceClearCacheButton => '清理快取';

  @override
  String get storageSpaceClearLogsButton => '清理日誌';

  @override
  String get storageSpaceDeleteConfirmTitle => '確認刪除';

  @override
  String storageSpaceDeleteUploadsConfirmMessage(int count) {
    return '刪除 $count 個項目？刪除後聊天記錄中的附件可能無法開啟。';
  }

  @override
  String storageSpaceDeletedUploadsDone(int count) {
    return '已刪除 $count 個項目';
  }

  @override
  String get storageSpaceNoUploads => '暫無內容';

  @override
  String get storageSpaceSelectAll => '全選';

  @override
  String get storageSpaceClearSelection => '清除選取';

  @override
  String storageSpaceSelectedCount(int count) {
    return '已選 $count 項';
  }

  @override
  String storageSpaceUploadsCount(int count) {
    return '共 $count 項';
  }

  @override
  String get settingsPageAboutSection => '關於';

  @override
  String get settingsPageAbout => '關於';

  @override
  String get settingsPageDocs => '使用文件';

  @override
  String get settingsPageSponsor => '贊助';

  @override
  String get settingsPageShare => '分享';

  @override
  String get sponsorPageMethodsSectionTitle => '贊助方式';

  @override
  String get sponsorPageSponsorsSectionTitle => '贊助用戶';

  @override
  String get sponsorPageEmpty => '暫無贊助者';

  @override
  String get sponsorPageAfdianTitle => '愛發電';

  @override
  String get sponsorPageAfdianSubtitle => 'afdian.com/a/kelivo';

  @override
  String get sponsorPageWeChatTitle => '微信贊助';

  @override
  String get sponsorPageWeChatSubtitle => '微信贊助碼';

  @override
  String get languageDisplaySimplifiedChinese => '简体中文';

  @override
  String get languageDisplayEnglish => 'English';

  @override
  String get languageDisplayTraditionalChinese => '繁體中文';

  @override
  String get languageDisplayJapanese => '日本語';

  @override
  String get languageDisplayKorean => '한국어';

  @override
  String get languageDisplayFrench => 'Français';

  @override
  String get languageDisplayGerman => 'Deutsch';

  @override
  String get languageDisplayItalian => 'Italiano';

  @override
  String get languageDisplaySpanish => 'Español';

  @override
  String get languageSelectSheetTitle => '選擇翻譯語言';

  @override
  String get languageSelectSheetClearButton => '清空翻譯';

  @override
  String get homePageClearContext => '清空上下文';

  @override
  String homePageClearContextWithCount(String actual, String configured) {
    return '清空上下文 ($actual/$configured)';
  }

  @override
  String get homePageDefaultAssistant => '預設助理';

  @override
  String get mermaidExportPng => '匯出 PNG';

  @override
  String get mermaidExportFailed => '匯出失敗';

  @override
  String get mermaidPreviewOpen => '瀏覽器預覽';

  @override
  String get mermaidPreviewOpenFailed => '無法打開預覽';

  @override
  String get assistantProviderDefaultAssistantName => '預設助理';

  @override
  String get assistantProviderSampleAssistantName => '範例助理';

  @override
  String get assistantProviderNewAssistantName => '新助理';

  @override
  String assistantProviderSampleAssistantSystemPrompt(
    String model_name,
    String cur_datetime,
    String locale,
    String timezone,
    String device_info,
    String system_version,
  ) {
    return '你是$model_name, 一個人工智慧助理，樂意為使用者提供準確，有益的幫助。現在時間是$cur_datetime，使用者裝置語言為$locale，時區為$timezone，使用者正在使用$device_info，版本$system_version。如果使用者沒有明確說明，請使用使用者裝置語言進行回覆。';
  }

  @override
  String get displaySettingsPageLanguageTitle => '應用程式語言';

  @override
  String get displaySettingsPageLanguageSubtitle => '選擇介面語言';

  @override
  String get assistantTagsManageTitle => '管理標籤';

  @override
  String get assistantTagsCreateButton => '建立';

  @override
  String get assistantTagsCreateDialogTitle => '建立標籤';

  @override
  String get assistantTagsCreateDialogOk => '建立';

  @override
  String get assistantTagsCreateDialogCancel => '取消';

  @override
  String get assistantTagsNameHint => '標籤名稱';

  @override
  String get assistantTagsRenameButton => '重新命名';

  @override
  String get assistantTagsRenameDialogTitle => '重新命名標籤';

  @override
  String get assistantTagsRenameDialogOk => '重新命名';

  @override
  String get assistantTagsDeleteButton => '刪除';

  @override
  String get assistantTagsDeleteConfirmTitle => '刪除標籤';

  @override
  String get assistantTagsDeleteConfirmContent => '確定要刪除該標籤嗎？';

  @override
  String get assistantTagsDeleteConfirmOk => '刪除';

  @override
  String get assistantTagsDeleteConfirmCancel => '取消';

  @override
  String get assistantTagsContextMenuEditAssistant => '編輯助理';

  @override
  String get assistantTagsContextMenuManageTags => '管理標籤';

  @override
  String get mcpTransportOptionStdio => 'STDIO';

  @override
  String get mcpTransportTagStdio => 'STDIO';

  @override
  String get mcpTransportTagInmemory => '內建';

  @override
  String get mcpServerEditSheetStdioOnlyDesktop => 'STDIO 僅在桌面端可用';

  @override
  String get mcpServerEditSheetStdioCommandLabel => '命令';

  @override
  String get mcpServerEditSheetStdioArgumentsLabel => '參數';

  @override
  String get mcpServerEditSheetStdioWorkingDirectoryLabel => '工作目錄（可選）';

  @override
  String get mcpServerEditSheetStdioEnvironmentTitle => '環境變數';

  @override
  String get mcpServerEditSheetStdioEnvNameLabel => '名稱';

  @override
  String get mcpServerEditSheetStdioEnvValueLabel => '值';

  @override
  String get mcpServerEditSheetStdioAddEnv => '新增環境變數';

  @override
  String get mcpServerEditSheetStdioCommandRequired => 'STDIO 需要填寫命令';

  @override
  String get assistantTagsContextMenuDeleteAssistant => '刪除助理';

  @override
  String get assistantTagsClearTag => '清除標籤';

  @override
  String get displaySettingsPageLanguageChineseLabel => '简体中文';

  @override
  String get displaySettingsPageLanguageEnglishLabel => 'English';

  @override
  String get homePagePleaseSelectModel => '請先選擇模型';

  @override
  String get homePagePleaseSetupTranslateModel => '請先設定翻譯模型';

  @override
  String get homePageTranslating => '翻譯中...';

  @override
  String homePageTranslateFailed(String error) {
    return '翻譯失敗: $error';
  }

  @override
  String get chatServiceDefaultConversationTitle => '新對話';

  @override
  String get userProviderDefaultUserName => '使用者';

  @override
  String get homePageDeleteMessage => '刪除訊息';

  @override
  String get homePageDeleteMessageConfirm => '確定要刪除這條訊息嗎？此操作不可撤銷。';

  @override
  String get homePageCancel => '取消';

  @override
  String get homePageDelete => '刪除';

  @override
  String get homePageSelectMessagesToShare => '請選擇要分享的訊息';

  @override
  String get homePageDone => '完成';

  @override
  String get homePageDropToUpload => '將檔案拖曳到此處以上傳';

  @override
  String get assistantEditPageTitle => '助理';

  @override
  String get assistantEditPageNotFound => '助理不存在';

  @override
  String get assistantEditPageBasicTab => '基礎設定';

  @override
  String get assistantEditPagePromptsTab => '提示詞';

  @override
  String get assistantEditPageMcpTab => 'MCP';

  @override
  String get assistantEditPageQuickPhraseTab => '快捷片語';

  @override
  String get assistantEditPageCustomTab => '自訂請求';

  @override
  String get assistantEditPageRegexTab => '正則替換';

  @override
  String get assistantEditRegexDescription => '為使用者/助理訊息配置正則規則，可修改或僅調整顯示效果。';

  @override
  String get assistantEditAddRegexButton => '新增正則規則';

  @override
  String get assistantRegexAddTitle => '新增正則規則';

  @override
  String get assistantRegexEditTitle => '編輯正則規則';

  @override
  String get assistantRegexNameLabel => '規則名稱';

  @override
  String get assistantRegexPatternLabel => '正則表達式';

  @override
  String get assistantRegexReplacementLabel => '替換字串';

  @override
  String get assistantRegexScopeLabel => '影響範圍';

  @override
  String get assistantRegexScopeUser => '使用者';

  @override
  String get assistantRegexScopeAssistant => '助理';

  @override
  String get assistantRegexScopeVisualOnly => '僅視覺';

  @override
  String get assistantRegexAddAction => '新增';

  @override
  String get assistantRegexSaveAction => '儲存';

  @override
  String get assistantRegexDeleteButton => '刪除';

  @override
  String get assistantRegexValidationError => '請填寫名稱、正則表達式，並至少選擇一個範圍。';

  @override
  String get assistantRegexInvalidPattern => '正則表達式無效';

  @override
  String get assistantRegexCancelButton => '取消';

  @override
  String get assistantRegexUntitled => '未命名規則';

  @override
  String get assistantEditCustomHeadersTitle => '自訂 Header';

  @override
  String get assistantEditCustomHeadersAdd => '新增 Header';

  @override
  String get assistantEditCustomHeadersEmpty => '未新增 Header';

  @override
  String get assistantEditCustomBodyTitle => '自訂 Body';

  @override
  String get assistantEditCustomBodyAdd => '新增 Body';

  @override
  String get assistantEditCustomBodyEmpty => '未新增 Body 項';

  @override
  String get assistantEditHeaderNameLabel => 'Header 名稱';

  @override
  String get assistantEditHeaderValueLabel => 'Header 值';

  @override
  String get assistantEditBodyKeyLabel => 'Body Key';

  @override
  String get assistantEditBodyValueLabel => 'Body 值 (JSON)';

  @override
  String get assistantEditDeleteTooltip => '刪除';

  @override
  String get assistantEditAssistantNameLabel => '助理名稱';

  @override
  String get assistantEditUseAssistantAvatarTitle => '使用助理頭像';

  @override
  String get assistantEditUseAssistantAvatarSubtitle =>
      '在聊天中使用助理頭像和名字而不是模型頭像和名字';

  @override
  String get assistantEditChatModelTitle => '聊天模型';

  @override
  String get assistantEditChatModelSubtitle => '為該助理設定預設聊天模型（未設定時使用全域預設）';

  @override
  String get assistantEditTemperatureDescription => '控制輸出的隨機性，範圍 0–2';

  @override
  String get assistantEditTopPDescription => '請不要修改此值，除非你知道自己在做什麼';

  @override
  String get assistantEditParameterDisabled => '已關閉（使用服務商預設）';

  @override
  String get assistantEditParameterDisabled2 => '已關閉（無限制）';

  @override
  String get assistantEditContextMessagesTitle => '上下文訊息數量';

  @override
  String get assistantEditContextMessagesDescription =>
      '多少歷史訊息會被當作上下文傳送給模型，超過數量會忽略，只保留最近 N 條';

  @override
  String get assistantEditStreamOutputTitle => '串流輸出';

  @override
  String get assistantEditStreamOutputDescription => '是否啟用訊息的串流輸出';

  @override
  String get assistantEditThinkingBudgetTitle => '思考預算';

  @override
  String get assistantEditConfigureButton => '設定';

  @override
  String get assistantEditMaxTokensTitle => '最大 Token 數';

  @override
  String get assistantEditMaxTokensDescription => '留空表示無限制';

  @override
  String get assistantEditMaxTokensHint => '無限制';

  @override
  String get assistantEditChatBackgroundTitle => '聊天背景';

  @override
  String get assistantEditChatBackgroundDescription => '設定助理聊天頁面的背景圖片';

  @override
  String get assistantEditChooseImageButton => '選擇背景圖片';

  @override
  String get assistantEditClearButton => '清除';

  @override
  String get desktopNavChatTooltip => '聊天';

  @override
  String get desktopNavTranslateTooltip => '翻譯';

  @override
  String get desktopNavStorageTooltip => '儲存';

  @override
  String get desktopNavThemeToggleTooltip => '主題切換';

  @override
  String get desktopNavSettingsTooltip => '設定';

  @override
  String get desktopAvatarMenuUseEmoji => '使用表情符號';

  @override
  String get cameraPermissionDeniedMessage => '未授予相機權限';

  @override
  String get openSystemSettings => '前往設定';

  @override
  String get desktopAvatarMenuChangeFromImage => '從圖片更換…';

  @override
  String get desktopAvatarMenuReset => '重置頭像';

  @override
  String get assistantEditAvatarChooseImage => '選擇圖片';

  @override
  String get assistantEditAvatarChooseEmoji => '選擇表情';

  @override
  String get assistantEditAvatarEnterLink => '輸入連結';

  @override
  String get assistantEditAvatarImportQQ => 'QQ頭像';

  @override
  String get assistantEditAvatarReset => '重設';

  @override
  String get displaySettingsPageChatMessageBackgroundTitle => '聊天訊息背景';

  @override
  String get displaySettingsPageChatMessageBackgroundDefault => '預設';

  @override
  String get displaySettingsPageChatMessageBackgroundFrosted => '模糊';

  @override
  String get displaySettingsPageChatMessageBackgroundSolid => '純色';

  @override
  String get displaySettingsPageAndroidBackgroundChatTitle => '後台聊天生成';

  @override
  String get androidBackgroundStatusOn => '開啟';

  @override
  String get androidBackgroundStatusOff => '關閉';

  @override
  String get androidBackgroundStatusOther => '關閉並發送消息';

  @override
  String get androidBackgroundOptionOn => '開啟';

  @override
  String get androidBackgroundOptionOnNotify => '開啟並在生成完時發送消息';

  @override
  String get androidBackgroundOptionOff => '關閉';

  @override
  String get notificationChatCompletedTitle => '生成完成';

  @override
  String get notificationChatCompletedBody => '助手回覆已生成';

  @override
  String get androidBackgroundNotificationTitle => 'Kelivo 正在運行';

  @override
  String get androidBackgroundNotificationText => '後台保持聊天生成';

  @override
  String get assistantEditEmojiDialogTitle => '選擇表情';

  @override
  String get assistantEditEmojiDialogHint => '輸入或貼上任意表情';

  @override
  String get assistantEditEmojiDialogCancel => '取消';

  @override
  String get assistantEditEmojiDialogSave => '儲存';

  @override
  String get assistantEditImageUrlDialogTitle => '輸入圖片連結';

  @override
  String get assistantEditImageUrlDialogHint =>
      '例如: https://example.com/avatar.png';

  @override
  String get assistantEditImageUrlDialogCancel => '取消';

  @override
  String get assistantEditImageUrlDialogSave => '儲存';

  @override
  String get assistantEditQQAvatarDialogTitle => '使用QQ頭像';

  @override
  String get assistantEditQQAvatarDialogHint => '輸入QQ號碼（5-12位）';

  @override
  String get assistantEditQQAvatarRandomButton => '隨機QQ';

  @override
  String get assistantEditQQAvatarFailedMessage => '取得隨機QQ頭像失敗，請重試';

  @override
  String get assistantEditQQAvatarDialogCancel => '取消';

  @override
  String get assistantEditQQAvatarDialogSave => '儲存';

  @override
  String get assistantEditGalleryErrorMessage => '無法開啟相簿，試試輸入圖片連結';

  @override
  String get assistantEditGeneralErrorMessage => '發生錯誤，試試輸入圖片連結';

  @override
  String get providerDetailPageMultiKeyModeTitle => '多Key模式';

  @override
  String get providerDetailPageManageKeysButton => '多Key管理';

  @override
  String get multiKeyPageTitle => '多Key管理';

  @override
  String get multiKeyPageDetect => '檢測';

  @override
  String get multiKeyPageAdd => '新增';

  @override
  String get multiKeyPageAddHint => '請輸入 API Key（多個以逗號或空格分隔）';

  @override
  String multiKeyPageImportedSnackbar(int n) {
    return '已匯入 $n 個 key';
  }

  @override
  String get multiKeyPagePleaseAddModel => '請先新增模型';

  @override
  String get multiKeyPageTotal => '總數';

  @override
  String get multiKeyPageNormal => '正常';

  @override
  String get multiKeyPageError => '錯誤';

  @override
  String get multiKeyPageAccuracy => '正確率';

  @override
  String get multiKeyPageStrategyTitle => '負載平衡策略';

  @override
  String get multiKeyPageStrategyRoundRobin => '輪詢';

  @override
  String get multiKeyPageStrategyPriority => '優先級';

  @override
  String get multiKeyPageStrategyLeastUsed => '最少使用';

  @override
  String get multiKeyPageStrategyRandom => '隨機';

  @override
  String get multiKeyPageNoKeys => '暫無 Key';

  @override
  String get multiKeyPageStatusActive => '正常';

  @override
  String get multiKeyPageStatusDisabled => '已關閉';

  @override
  String get multiKeyPageStatusError => '錯誤';

  @override
  String get multiKeyPageStatusRateLimited => '限速';

  @override
  String get multiKeyPageEditAlias => '編輯別名';

  @override
  String get multiKeyPageEdit => '編輯';

  @override
  String get multiKeyPageKey => 'API Key';

  @override
  String get multiKeyPagePriority => '優先級（1–10）';

  @override
  String get multiKeyPageDuplicateKeyWarning => '該 Key 已存在';

  @override
  String get multiKeyPageAlias => '別名';

  @override
  String get multiKeyPageCancel => '取消';

  @override
  String get multiKeyPageSave => '儲存';

  @override
  String get multiKeyPageDelete => '刪除';

  @override
  String get assistantEditSystemPromptTitle => '系統提示詞';

  @override
  String get assistantEditSystemPromptHint => '輸入系統提示詞…';

  @override
  String get assistantEditSystemPromptImportButton => '從檔案匯入';

  @override
  String get assistantEditSystemPromptImportSuccess => '已從檔案更新系統提示詞';

  @override
  String get assistantEditSystemPromptImportFailed => '匯入失敗';

  @override
  String get assistantEditSystemPromptImportEmpty => '檔案內容為空';

  @override
  String get assistantEditAvailableVariables => '可用變數：';

  @override
  String get assistantEditVariableDate => '日期';

  @override
  String get assistantEditVariableTime => '時間';

  @override
  String get assistantEditVariableDatetime => '日期和時間';

  @override
  String get assistantEditVariableModelId => '模型ID';

  @override
  String get assistantEditVariableModelName => '模型名稱';

  @override
  String get assistantEditVariableLocale => '語言環境';

  @override
  String get assistantEditVariableTimezone => '時區';

  @override
  String get assistantEditVariableSystemVersion => '系統版本';

  @override
  String get assistantEditVariableDeviceInfo => '裝置資訊';

  @override
  String get assistantEditVariableBatteryLevel => '電池電量';

  @override
  String get assistantEditVariableNickname => '使用者暱稱';

  @override
  String get assistantEditVariableAssistantName => '助理名稱';

  @override
  String get assistantEditMessageTemplateTitle => '聊天內容範本';

  @override
  String get assistantEditVariableRole => '角色';

  @override
  String get assistantEditVariableMessage => '內容';

  @override
  String get assistantEditPreviewTitle => '預覽';

  @override
  String get codeBlockPreviewButton => '預覽';

  @override
  String codeBlockCollapsedLines(int n) {
    return '… 已摺疊 $n 行';
  }

  @override
  String get htmlPreviewNotSupportedOnLinux => 'Linux 暫不支援 HTML 預覽';

  @override
  String get assistantEditSampleUser => '使用者';

  @override
  String get assistantEditSampleMessage => '你好啊';

  @override
  String get assistantEditSampleReply => '你好，有什麼我可以幫你的嗎？';

  @override
  String get assistantEditMcpNoServersMessage => '暫無已啟動的 MCP 伺服器';

  @override
  String get assistantEditMcpConnectedTag => '已連線';

  @override
  String assistantEditMcpToolsCountTag(String enabled, String total) {
    return '工具: $enabled/$total';
  }

  @override
  String get assistantEditModelUseGlobalDefault => '使用全域預設';

  @override
  String get assistantSettingsPageTitle => '助理設定';

  @override
  String get assistantSettingsDefaultTag => '預設';

  @override
  String get assistantSettingsCopyButton => '複製';

  @override
  String get assistantSettingsCopySuccess => '已複製助理';

  @override
  String get assistantSettingsCopySuffix => '副本';

  @override
  String get assistantSettingsDeleteButton => '刪除';

  @override
  String get assistantSettingsEditButton => '編輯';

  @override
  String get assistantSettingsAddSheetTitle => '助理名稱';

  @override
  String get assistantSettingsAddSheetHint => '輸入助理名稱';

  @override
  String get assistantSettingsAddSheetCancel => '取消';

  @override
  String get assistantSettingsAddSheetSave => '儲存';

  @override
  String get desktopAssistantsListTitle => '助理列表';

  @override
  String get desktopSidebarTabAssistants => '助理';

  @override
  String get desktopSidebarTabTopics => '主題';

  @override
  String get desktopTrayMenuShowWindow => '顯示視窗';

  @override
  String get desktopTrayMenuExit => '結束';

  @override
  String get hotkeyToggleAppVisibility => '顯示/隱藏應用';

  @override
  String get hotkeyCloseWindow => '關閉視窗';

  @override
  String get hotkeyOpenSettings => '打開設定';

  @override
  String get hotkeyNewTopic => '新建話題';

  @override
  String get hotkeySwitchModel => '切換模型';

  @override
  String get hotkeyToggleAssistantPanel => '切換助理顯示';

  @override
  String get hotkeyToggleTopicPanel => '切換話題顯示';

  @override
  String get hotkeysPressShortcut => '按下快捷鍵';

  @override
  String get hotkeysResetDefault => '重置為預設';

  @override
  String get hotkeysClearShortcut => '清除快捷鍵';

  @override
  String get hotkeysResetAll => '重置所有快捷鍵為預設';

  @override
  String get assistantEditTemperatureTitle => '溫度';

  @override
  String get assistantEditTopPTitle => 'Top-p';

  @override
  String get assistantSettingsDeleteDialogTitle => '刪除助理';

  @override
  String get assistantSettingsDeleteDialogContent => '確定要刪除該助理嗎？此操作不可撤銷。';

  @override
  String get assistantSettingsDeleteDialogCancel => '取消';

  @override
  String get assistantSettingsDeleteDialogConfirm => '刪除';

  @override
  String get assistantSettingsAtLeastOneAssistantRequired => '至少需要保留一個助理';

  @override
  String get mcpAssistantSheetTitle => 'MCP伺服器';

  @override
  String get mcpAssistantSheetSubtitle => '為該助理啟用的服務';

  @override
  String get mcpAssistantSheetSelectAll => '全選';

  @override
  String get mcpAssistantSheetClearAll => '全不選';

  @override
  String get backupPageTitle => '備份與還原';

  @override
  String get backupPageWebDavTab => 'WebDAV 備份';

  @override
  String get backupPageImportExportTab => '匯入和匯出';

  @override
  String get backupPageWebDavServerUrl => 'WebDAV 伺服器地址';

  @override
  String get backupPageUsername => '使用者名稱';

  @override
  String get backupPagePassword => '密碼';

  @override
  String get backupPagePath => '路徑';

  @override
  String get backupPageChatsLabel => '聊天記錄';

  @override
  String get backupPageFilesLabel => '檔案';

  @override
  String get backupPageTestDone => '測試完成';

  @override
  String get backupPageTestConnection => '測試連線';

  @override
  String get backupPageRestartRequired => '需要重啟應用程式';

  @override
  String get backupPageRestartContent => '還原完成，需要重啟以完全生效。';

  @override
  String get backupPageOK => '好的';

  @override
  String get backupPageCancel => '取消';

  @override
  String get backupPageSelectImportMode => '選擇匯入模式';

  @override
  String get backupPageSelectImportModeDescription => '請選擇如何匯入備份資料：';

  @override
  String get backupPageOverwriteMode => '完全覆蓋';

  @override
  String get backupPageOverwriteModeDescription => '清空本地所有資料後恢復';

  @override
  String get backupPageMergeMode => '智能合併';

  @override
  String get backupPageMergeModeDescription => '僅添加不存在的資料（智能去重）';

  @override
  String get backupPageRestore => '還原';

  @override
  String get backupPageBackupUploaded => '已上傳備份';

  @override
  String get backupPageBackup => '立即備份';

  @override
  String get backupPageExporting => '正在匯出...';

  @override
  String get backupPageExportToFile => '匯出為檔案';

  @override
  String get backupPageExportToFileSubtitle => '匯出APP資料為檔案';

  @override
  String get backupPageImportBackupFile => '備份檔案匯入';

  @override
  String get backupPageImportBackupFileSubtitle => '匯入本機備份檔案';

  @override
  String get backupPageImportFromOtherApps => '從其他APP匯入';

  @override
  String get backupPageImportFromRikkaHub => '從 RikkaHub 匯入';

  @override
  String get backupPageNotSupportedYet => '暫不支援';

  @override
  String get backupPageRemoteBackups => '遠端備份';

  @override
  String get backupPageNoBackups => '暫無備份';

  @override
  String get backupPageRestoreTooltip => '還原';

  @override
  String get backupPageDeleteTooltip => '刪除';

  @override
  String get backupPageBackupManagement => '備份管理';

  @override
  String get backupPageWebDavBackup => 'WebDAV 備份';

  @override
  String get backupPageWebDavServerSettings => 'WebDAV 伺服器設定';

  @override
  String get backupPageSave => '儲存';

  @override
  String get backupPageBackupNow => '立即備份';

  @override
  String get backupPageLocalBackup => '本機備份';

  @override
  String get backupPageImportFromCherryStudio => '從 Cherry Studio 匯入';

  @override
  String get backupPageImportFromChatbox => '從 Chatbox 匯入';

  @override
  String get chatHistoryPageTitle => '聊天歷史';

  @override
  String get chatHistoryPageSearchTooltip => '搜尋';

  @override
  String get chatHistoryPageDeleteAllTooltip => '刪除未置頂';

  @override
  String get chatHistoryPageDeleteAllDialogTitle => '刪除未置頂對話';

  @override
  String get chatHistoryPageDeleteAllDialogContent => '確認要刪除所有未置頂的對話嗎？已置頂的會保留。';

  @override
  String get chatHistoryPageCancel => '取消';

  @override
  String get chatHistoryPageDelete => '刪除';

  @override
  String get chatHistoryPageDeletedAllSnackbar => '已刪除未置頂的對話';

  @override
  String get chatHistoryPageSearchHint => '搜尋對話';

  @override
  String get chatHistoryPageNoConversations => '暫無對話';

  @override
  String get chatHistoryPagePinnedSection => '置頂';

  @override
  String get chatHistoryPagePin => '置頂';

  @override
  String get chatHistoryPagePinned => '已置頂';

  @override
  String get messageEditPageTitle => '編輯訊息';

  @override
  String get messageEditPageSave => '儲存';

  @override
  String get messageEditPageSaveAndSend => '儲存並發送';

  @override
  String get messageEditPageHint => '輸入訊息內容…';

  @override
  String get selectCopyPageTitle => '選擇複製';

  @override
  String get selectCopyPageCopyAll => '複製全部';

  @override
  String get selectCopyPageCopiedAll => '已複製全部';

  @override
  String get bottomToolsSheetCamera => '拍照';

  @override
  String get bottomToolsSheetPhotos => '照片';

  @override
  String get bottomToolsSheetUpload => '上傳檔案';

  @override
  String get bottomToolsSheetClearContext => '清空上下文';

  @override
  String get bottomToolsSheetLearningMode => '學習模式';

  @override
  String get bottomToolsSheetLearningModeDescription => '幫助你循序漸進地學習知識';

  @override
  String get bottomToolsSheetConfigurePrompt => '設定提示詞';

  @override
  String get bottomToolsSheetPrompt => '提示詞';

  @override
  String get bottomToolsSheetPromptHint => '輸入要注入的提示詞內容';

  @override
  String get bottomToolsSheetResetDefault => '重設為預設';

  @override
  String get bottomToolsSheetSave => '儲存';

  @override
  String get bottomToolsSheetOcr => 'OCR 文字辨識';

  @override
  String get messageMoreSheetTitle => '更多操作';

  @override
  String get messageMoreSheetSelectCopy => '選擇複製';

  @override
  String get messageMoreSheetRenderWebView => '網頁視圖渲染';

  @override
  String get messageMoreSheetNotImplemented => '暫未實現';

  @override
  String get messageMoreSheetEdit => '編輯';

  @override
  String get messageMoreSheetShare => '分享';

  @override
  String get messageMoreSheetCreateBranch => '建立分支';

  @override
  String get messageMoreSheetDelete => '刪除';

  @override
  String get reasoningBudgetSheetOff => '關閉';

  @override
  String get reasoningBudgetSheetAuto => '自動';

  @override
  String get reasoningBudgetSheetLight => '輕度推理';

  @override
  String get reasoningBudgetSheetMedium => '中度推理';

  @override
  String get reasoningBudgetSheetHeavy => '重度推理';

  @override
  String get reasoningBudgetSheetTitle => '思維鏈強度';

  @override
  String reasoningBudgetSheetCurrentLevel(String level) {
    return '目前檔位：$level';
  }

  @override
  String get reasoningBudgetSheetOffSubtitle => '關閉推理功能，直接回答';

  @override
  String get reasoningBudgetSheetAutoSubtitle => '由模型自動決定推理級別';

  @override
  String get reasoningBudgetSheetLightSubtitle => '使用少量推理來回答問題';

  @override
  String get reasoningBudgetSheetMediumSubtitle => '使用較多推理來回答問題';

  @override
  String get reasoningBudgetSheetHeavySubtitle => '使用大量推理來回答問題，適合複雜問題';

  @override
  String get reasoningBudgetSheetCustomLabel => '自訂推理預算 (tokens)';

  @override
  String get reasoningBudgetSheetCustomHint => '例如：2048 (-1 自動，0 關閉)';

  @override
  String chatMessageWidgetFileNotFound(String fileName) {
    return '檔案不存在: $fileName';
  }

  @override
  String chatMessageWidgetCannotOpenFile(String message) {
    return '無法開啟檔案: $message';
  }

  @override
  String chatMessageWidgetOpenFileError(String error) {
    return '開啟檔案失敗: $error';
  }

  @override
  String get chatMessageWidgetCopiedToClipboard => '已複製到剪貼簿';

  @override
  String get chatMessageWidgetResendTooltip => '重新傳送';

  @override
  String get chatMessageWidgetMoreTooltip => '更多';

  @override
  String get chatMessageWidgetThinking => '正在思考...';

  @override
  String get chatMessageWidgetTranslation => '翻譯';

  @override
  String get chatMessageWidgetTranslating => '翻譯中...';

  @override
  String get chatMessageWidgetCitationNotFound => '未找到引用來源';

  @override
  String chatMessageWidgetCannotOpenUrl(String url) {
    return '無法開啟連結: $url';
  }

  @override
  String get chatMessageWidgetOpenLinkError => '開啟連結失敗';

  @override
  String chatMessageWidgetCitationsTitle(int count) {
    return '引用（共$count條）';
  }

  @override
  String get chatMessageWidgetRegenerateTooltip => '重新生成';

  @override
  String get chatMessageWidgetStopTooltip => '停止';

  @override
  String get chatMessageWidgetSpeakTooltip => '朗讀';

  @override
  String get chatMessageWidgetTranslateTooltip => '翻譯';

  @override
  String get chatMessageWidgetBuiltinSearchHideNote => '隱藏內建搜尋工具卡片';

  @override
  String get chatMessageWidgetDeepThinking => '深度思考';

  @override
  String get chatMessageWidgetCreateMemory => '建立記憶';

  @override
  String get chatMessageWidgetEditMemory => '編輯記憶';

  @override
  String get chatMessageWidgetDeleteMemory => '刪除記憶';

  @override
  String chatMessageWidgetWebSearch(String query) {
    return '聯網檢索: $query';
  }

  @override
  String get chatMessageWidgetBuiltinSearch => '模型內建搜尋';

  @override
  String chatMessageWidgetToolCall(String name) {
    return '呼叫工具: $name';
  }

  @override
  String chatMessageWidgetToolResult(String name) {
    return '呼叫工具: $name';
  }

  @override
  String get chatMessageWidgetNoResultYet => '（暫無結果）';

  @override
  String get chatMessageWidgetArguments => '參數';

  @override
  String get chatMessageWidgetResult => '結果';

  @override
  String chatMessageWidgetCitationsCount(int count) {
    return '共$count條引用';
  }

  @override
  String get messageExportSheetAssistant => '助理';

  @override
  String get messageExportSheetDefaultTitle => '新對話';

  @override
  String get messageExportSheetExporting => '正在匯出…';

  @override
  String messageExportSheetExportFailed(String error) {
    return '匯出失敗: $error';
  }

  @override
  String messageExportSheetExportedAs(String filename) {
    return '已匯出為 $filename';
  }

  @override
  String get displaySettingsPageEnableDollarLatexTitle => '啟用 \$...\$ 渲染';

  @override
  String get displaySettingsPageEnableDollarLatexSubtitle =>
      '將 \$...\$ 之間的內容以行內數學公式渲染';

  @override
  String get displaySettingsPageEnableMathTitle => '啟用數學公式渲染';

  @override
  String get displaySettingsPageEnableMathSubtitle => '渲染 LaTeX 數學公式（行內與區塊）';

  @override
  String get displaySettingsPageEnableUserMarkdownTitle => '使用者訊息 Markdown 渲染';

  @override
  String get displaySettingsPageEnableReasoningMarkdownTitle =>
      '思维鏈 Markdown 渲染';

  @override
  String get displaySettingsPageMobileCodeBlockWrapTitle => '行動端程式碼區塊自動換行';

  @override
  String get displaySettingsPageAutoCollapseCodeBlockTitle => '自動摺疊程式碼區塊';

  @override
  String get displaySettingsPageAutoCollapseCodeBlockLinesTitle => '超過多少行自動摺疊';

  @override
  String get displaySettingsPageAutoCollapseCodeBlockLinesUnit => '行';

  @override
  String get messageExportSheetFormatTitle => '匯出格式';

  @override
  String get messageExportSheetMarkdown => 'Markdown';

  @override
  String get messageExportSheetSingleMarkdownSubtitle => '將該訊息匯出為 Markdown 檔案';

  @override
  String get messageExportSheetBatchMarkdownSubtitle => '將選中的訊息匯出為 Markdown 檔案';

  @override
  String get messageExportSheetPlainText => '純文字';

  @override
  String get messageExportSheetSingleTxtSubtitle => '將該訊息匯出為 TXT 檔案';

  @override
  String get messageExportSheetBatchTxtSubtitle => '將選中的訊息匯出為 TXT 檔案';

  @override
  String get messageExportSheetExportImage => '匯出為圖片';

  @override
  String get messageExportSheetSingleExportImageSubtitle => '將該訊息渲染為 PNG 圖片';

  @override
  String get messageExportSheetBatchExportImageSubtitle => '將選中的訊息渲染為 PNG 圖片';

  @override
  String get messageExportSheetShowThinkingAndToolCards => '顯示深度思考卡片與工具卡片';

  @override
  String get messageExportSheetShowThinkingContent => '顯示思考內容';

  @override
  String get messageExportSheetDateTimeWithSecondsPattern =>
      'yyyy年M月d日 HH:mm:ss';

  @override
  String get exportDisclaimerAiGenerated => '內容由 AI 生成，請仔細甄別';

  @override
  String get imagePreviewSheetSaveImage => '保存圖片';

  @override
  String get imagePreviewSheetSaveSuccess => '已儲存到相簿';

  @override
  String imagePreviewSheetSaveFailed(String error) {
    return '保存失敗: $error';
  }

  @override
  String get sideDrawerMenuRename => '重新命名';

  @override
  String get sideDrawerMenuPin => '置頂';

  @override
  String get sideDrawerMenuUnpin => '取消置頂';

  @override
  String get sideDrawerMenuRegenerateTitle => '重新生成標題';

  @override
  String get sideDrawerMenuMoveTo => '移動到';

  @override
  String get sideDrawerMenuDelete => '刪除';

  @override
  String sideDrawerDeleteSnackbar(String title) {
    return '已刪除「$title」';
  }

  @override
  String get sideDrawerRenameHint => '輸入新名稱';

  @override
  String get sideDrawerCancel => '取消';

  @override
  String get sideDrawerOK => '確定';

  @override
  String get sideDrawerSave => '儲存';

  @override
  String get sideDrawerGreetingMorning => '早安 👋';

  @override
  String get sideDrawerGreetingNoon => '午安 👋';

  @override
  String get sideDrawerGreetingAfternoon => '午安 👋';

  @override
  String get sideDrawerGreetingEvening => '晚安 👋';

  @override
  String get sideDrawerDateToday => '今天';

  @override
  String get sideDrawerDateYesterday => '昨天';

  @override
  String get sideDrawerDateShortPattern => 'M月d日';

  @override
  String get sideDrawerDateFullPattern => 'yyyy年M月d日';

  @override
  String get sideDrawerSearchHint => '搜尋聊天記錄';

  @override
  String get sideDrawerSearchAssistantsHint => '搜尋助理';

  @override
  String sideDrawerUpdateTitle(String version) {
    return '發現新版本：$version';
  }

  @override
  String sideDrawerUpdateTitleWithBuild(String version, int build) {
    return '發現新版本：$version ($build)';
  }

  @override
  String get sideDrawerLinkCopied => '已複製下載連結';

  @override
  String get sideDrawerPinnedLabel => '置頂';

  @override
  String get sideDrawerHistory => '聊天歷史';

  @override
  String get sideDrawerSettings => '設定';

  @override
  String get sideDrawerChooseAssistantTitle => '選擇助理';

  @override
  String get sideDrawerChooseImage => '選擇圖片';

  @override
  String get sideDrawerChooseEmoji => '選擇表情';

  @override
  String get sideDrawerEnterLink => '輸入連結';

  @override
  String get sideDrawerImportFromQQ => 'QQ頭像';

  @override
  String get sideDrawerReset => '重設';

  @override
  String get sideDrawerEmojiDialogTitle => '選擇表情';

  @override
  String get sideDrawerEmojiDialogHint => '輸入或貼上任意表情';

  @override
  String get sideDrawerImageUrlDialogTitle => '輸入圖片連結';

  @override
  String get sideDrawerImageUrlDialogHint =>
      '例如: https://example.com/avatar.png';

  @override
  String get sideDrawerQQAvatarDialogTitle => '使用QQ頭像';

  @override
  String get sideDrawerQQAvatarInputHint => '輸入QQ號碼（5-12位）';

  @override
  String get sideDrawerQQAvatarFetchFailed => '取得隨機QQ頭像失敗，請重試';

  @override
  String get sideDrawerRandomQQ => '隨機QQ';

  @override
  String get sideDrawerGalleryOpenError => '無法開啟相簿，試試輸入圖片連結';

  @override
  String get sideDrawerGeneralImageError => '發生錯誤，試試輸入圖片連結';

  @override
  String get sideDrawerSetNicknameTitle => '設定暱稱';

  @override
  String get sideDrawerNicknameLabel => '暱稱';

  @override
  String get sideDrawerNicknameHint => '輸入新的暱稱';

  @override
  String get sideDrawerRename => '重新命名';

  @override
  String get chatInputBarHint => '輸入訊息與AI聊天';

  @override
  String get chatInputBarSelectModelTooltip => '選擇模型';

  @override
  String get chatInputBarOnlineSearchTooltip => '聯網搜尋';

  @override
  String get chatInputBarReasoningStrengthTooltip => '思維鏈強度';

  @override
  String get chatInputBarMcpServersTooltip => 'MCP伺服器';

  @override
  String get chatInputBarMoreTooltip => '更多';

  @override
  String get chatInputBarInsertNewline => '換行';

  @override
  String get chatInputBarExpand => '展開';

  @override
  String get chatInputBarCollapse => '收起';

  @override
  String get mcpPageBackTooltip => '返回';

  @override
  String get mcpPageAddMcpTooltip => '新增 MCP';

  @override
  String get mcpPageNoServers => '暫無 MCP 伺服器';

  @override
  String get mcpPageErrorDialogTitle => '連線錯誤';

  @override
  String get mcpPageErrorNoDetails => '未提供錯誤詳情';

  @override
  String get mcpPageClose => '關閉';

  @override
  String get mcpPageReconnect => '重新連線';

  @override
  String get mcpPageStatusConnected => '已連線';

  @override
  String get mcpPageStatusConnecting => '連線中…';

  @override
  String get mcpPageStatusDisconnected => '未連線';

  @override
  String get mcpPageStatusDisabled => '已停用';

  @override
  String mcpPageToolsCount(int enabled, int total) {
    return '工具: $enabled/$total';
  }

  @override
  String get mcpPageConnectionFailed => '連線失敗';

  @override
  String get mcpPageDetails => '詳情';

  @override
  String get mcpPageDelete => '刪除';

  @override
  String get mcpPageConfirmDeleteTitle => '確認刪除';

  @override
  String get mcpPageConfirmDeleteContent => '刪除後可透過撤銷還原。是否刪除？';

  @override
  String get mcpPageServerDeleted => '已刪除伺服器';

  @override
  String get mcpPageUndo => '撤銷';

  @override
  String get mcpPageCancel => '取消';

  @override
  String get mcpConversationSheetTitle => 'MCP伺服器';

  @override
  String get mcpConversationSheetSubtitle => '選擇在此助理中啟用的服務';

  @override
  String get mcpConversationSheetSelectAll => '全選';

  @override
  String get mcpConversationSheetClearAll => '全不選';

  @override
  String get mcpConversationSheetNoRunning => '暫無已啟動的 MCP 伺服器';

  @override
  String get mcpConversationSheetConnected => '已連線';

  @override
  String mcpConversationSheetToolsCount(int enabled, int total) {
    return '工具: $enabled/$total';
  }

  @override
  String get mcpServerEditSheetEnabledLabel => '是否啟用';

  @override
  String get mcpServerEditSheetNameLabel => '名稱';

  @override
  String get mcpServerEditSheetTransportLabel => '傳輸類型';

  @override
  String get mcpServerEditSheetSseRetryHint => '如果SSE連線失敗，請多試幾次';

  @override
  String get mcpServerEditSheetUrlLabel => '伺服器地址';

  @override
  String get mcpServerEditSheetCustomHeadersTitle => '自訂請求標頭';

  @override
  String get mcpServerEditSheetHeaderNameLabel => '請求標頭名稱';

  @override
  String get mcpServerEditSheetHeaderNameHint => '如 Authorization';

  @override
  String get mcpServerEditSheetHeaderValueLabel => '請求標頭值';

  @override
  String get mcpServerEditSheetHeaderValueHint => '如 Bearer xxxxxx';

  @override
  String get mcpServerEditSheetRemoveHeaderTooltip => '刪除';

  @override
  String get mcpServerEditSheetAddHeader => '新增請求標頭';

  @override
  String get mcpServerEditSheetTitleEdit => '編輯 MCP';

  @override
  String get mcpServerEditSheetTitleAdd => '新增 MCP';

  @override
  String get mcpServerEditSheetSyncToolsTooltip => '同步工具';

  @override
  String get mcpServerEditSheetTabBasic => '基礎設定';

  @override
  String get mcpServerEditSheetTabTools => '工具';

  @override
  String get mcpServerEditSheetNoToolsHint => '暫無工具，點擊上方同步';

  @override
  String get mcpServerEditSheetCancel => '取消';

  @override
  String get mcpServerEditSheetSave => '儲存';

  @override
  String get mcpServerEditSheetUrlRequired => '請輸入伺服器地址';

  @override
  String get defaultModelPageBackTooltip => '返回';

  @override
  String get defaultModelPageTitle => '預設模型';

  @override
  String get defaultModelPageChatModelTitle => '聊天模型';

  @override
  String get defaultModelPageChatModelSubtitle => '全域預設的聊天模型';

  @override
  String get defaultModelPageTitleModelTitle => '標題總結模型';

  @override
  String get defaultModelPageTitleModelSubtitle => '用於總結對話標題的模型，推薦使用快速且便宜的模型';

  @override
  String get defaultModelPageSummaryModelTitle => '摘要模型';

  @override
  String get defaultModelPageSummaryModelSubtitle => '用於生成對話摘要的模型，推薦使用快速且便宜的模型';

  @override
  String get defaultModelPageTranslateModelTitle => '翻譯模型';

  @override
  String get defaultModelPageTranslateModelSubtitle =>
      '用於翻譯訊息內容的模型，推薦使用快速且準確的模型';

  @override
  String get defaultModelPageOcrModelTitle => 'OCR 模型';

  @override
  String get defaultModelPageOcrModelSubtitle => '用於對圖片執行文字辨識的模型';

  @override
  String get defaultModelPagePromptLabel => '提示詞';

  @override
  String get defaultModelPageTitlePromptHint => '輸入用於標題總結的提示詞範本';

  @override
  String get defaultModelPageSummaryPromptHint => '輸入用於生成摘要的提示詞範本';

  @override
  String get defaultModelPageTranslatePromptHint => '輸入用於翻譯的提示詞範本';

  @override
  String get defaultModelPageOcrPromptHint => '輸入用於 OCR 辨識的提示詞範本';

  @override
  String get defaultModelPageResetDefault => '重設為預設';

  @override
  String get defaultModelPageSave => '儲存';

  @override
  String defaultModelPageTitleVars(String contentVar, String localeVar) {
    return '變數: 對話內容: $contentVar, 語言: $localeVar';
  }

  @override
  String defaultModelPageSummaryVars(
    String previousSummaryVar,
    String userMessagesVar,
  ) {
    return '變數：舊摘要：$previousSummaryVar，新訊息：$userMessagesVar';
  }

  @override
  String defaultModelPageTranslateVars(String sourceVar, String targetVar) {
    return '變數：原始文本：$sourceVar，目標語言：$targetVar';
  }

  @override
  String get defaultModelPageUseCurrentModel => '使用目前對話模型';

  @override
  String get translatePagePasteButton => '貼上';

  @override
  String get translatePageCopyResult => '複製結果';

  @override
  String get translatePageClearAll => '清空全部';

  @override
  String get translatePageInputHint => '輸入要翻譯的內容…';

  @override
  String get translatePageOutputHint => '翻譯結果會顯示在這裡…';

  @override
  String get modelDetailSheetAddModel => '新增模型';

  @override
  String get modelDetailSheetEditModel => '編輯模型';

  @override
  String get modelDetailSheetBasicTab => '基本設定';

  @override
  String get modelDetailSheetAdvancedTab => '進階設定';

  @override
  String get modelDetailSheetBuiltinToolsTab => '內建工具';

  @override
  String get modelDetailSheetModelIdLabel => '模型 ID';

  @override
  String get modelDetailSheetModelIdHint => '必填，建議小寫字母、數字、連字號';

  @override
  String modelDetailSheetModelIdDisabledHint(String modelId) {
    return '$modelId';
  }

  @override
  String get modelDetailSheetModelNameLabel => '模型名稱';

  @override
  String get modelDetailSheetModelTypeLabel => '模型類型';

  @override
  String get modelDetailSheetChatType => '聊天';

  @override
  String get modelDetailSheetEmbeddingType => '嵌入';

  @override
  String get modelDetailSheetInputModesLabel => '輸入模式';

  @override
  String get modelDetailSheetOutputModesLabel => '輸出模式';

  @override
  String get modelDetailSheetAbilitiesLabel => '能力';

  @override
  String get modelDetailSheetTextMode => '文字';

  @override
  String get modelDetailSheetImageMode => '圖片';

  @override
  String get modelDetailSheetToolsAbility => '工具';

  @override
  String get modelDetailSheetReasoningAbility => '推理';

  @override
  String get modelDetailSheetProviderOverrideDescription =>
      '供應商覆寫：允許為特定模型自訂供應商設定。（暫未實現）';

  @override
  String get modelDetailSheetAddProviderOverride => '新增供應商覆寫';

  @override
  String get modelDetailSheetCustomHeadersTitle => '自訂 Headers';

  @override
  String get modelDetailSheetAddHeader => '新增 Header';

  @override
  String get modelDetailSheetCustomBodyTitle => '自訂 Body';

  @override
  String get modelFetchInvertTooltip => '反選';

  @override
  String get modelDetailSheetAddBody => '新增 Body';

  @override
  String get modelDetailSheetBuiltinToolsDescription => '內建工具僅支援官方 API。';

  @override
  String get modelDetailSheetGeminiCodeExecutionMutuallyExclusiveHint =>
      '程式碼執行無法與搜尋/URL 上下文/MCP 工具共存。';

  @override
  String get modelDetailSheetBuiltinToolsUnsupportedHint => '目前供應商不支援這些內建工具。';

  @override
  String get modelDetailSheetSearchTool => '搜尋';

  @override
  String get modelDetailSheetSearchToolDescription => '啟用 Google 搜尋整合';

  @override
  String get modelDetailSheetUrlContextTool => 'URL 上下文';

  @override
  String get modelDetailSheetUrlContextToolDescription => '啟用 URL 內容處理';

  @override
  String get modelDetailSheetCodeExecutionTool => '程式碼執行';

  @override
  String get modelDetailSheetCodeExecutionToolDescription => '啟用程式碼執行工具';

  @override
  String get modelDetailSheetYoutubeTool => 'YouTube';

  @override
  String get modelDetailSheetYoutubeToolDescription =>
      '啟用 YouTube 連結讀取（自動辨識提示詞中的連結）';

  @override
  String get modelDetailSheetOpenaiBuiltinToolsResponsesOnlyHint =>
      '需要啟用 OpenAI Responses API。';

  @override
  String get modelDetailSheetOpenaiCodeInterpreterTool => '程式碼解譯器';

  @override
  String get modelDetailSheetOpenaiCodeInterpreterToolDescription =>
      '啟用程式碼解譯器工具（容器自動，記憶體上限 4g）';

  @override
  String get modelDetailSheetOpenaiImageGenerationTool => '圖像生成';

  @override
  String get modelDetailSheetOpenaiImageGenerationToolDescription => '啟用圖像生成工具';

  @override
  String get modelDetailSheetCancelButton => '取消';

  @override
  String get modelDetailSheetAddButton => '新增';

  @override
  String get modelDetailSheetConfirmButton => '確認';

  @override
  String get modelDetailSheetInvalidIdError => '請輸入有效的模型 ID（不少於2個字元）';

  @override
  String get modelDetailSheetModelIdExistsError => '模型 ID 已存在';

  @override
  String get modelDetailSheetHeaderKeyHint => 'Header Key';

  @override
  String get modelDetailSheetHeaderValueHint => 'Header Value';

  @override
  String get modelDetailSheetBodyKeyHint => 'Body Key';

  @override
  String get modelDetailSheetBodyJsonHint => 'Body JSON';

  @override
  String get modelSelectSheetSearchHint => '搜尋模型或供應商';

  @override
  String get modelSelectSheetFavoritesSection => '收藏';

  @override
  String get modelSelectSheetFavoriteTooltip => '收藏';

  @override
  String get modelSelectSheetChatType => '聊天';

  @override
  String get modelSelectSheetEmbeddingType => '嵌入';

  @override
  String get providerDetailPageShareTooltip => '分享';

  @override
  String get providerDetailPageDeleteProviderTooltip => '刪除供應商';

  @override
  String get providerDetailPageDeleteProviderTitle => '刪除供應商';

  @override
  String get providerDetailPageDeleteProviderContent => '確定要刪除該供應商嗎？此操作不可撤銷。';

  @override
  String get providerDetailPageCancelButton => '取消';

  @override
  String get providerDetailPageDeleteButton => '刪除';

  @override
  String get providerDetailPageProviderDeletedSnackbar => '已刪除供應商';

  @override
  String get providerDetailPageConfigTab => '設定';

  @override
  String get providerDetailPageModelsTab => '模型';

  @override
  String get providerDetailPageNetworkTab => '網路代理';

  @override
  String get providerDetailPageEnabledTitle => '是否啟用';

  @override
  String get providerDetailPageManageSectionTitle => '管理';

  @override
  String get providerDetailPageNameLabel => '名稱';

  @override
  String get providerDetailPageApiKeyHint => '留空則使用上層預設';

  @override
  String get providerDetailPageHideTooltip => '隱藏';

  @override
  String get providerDetailPageShowTooltip => '顯示';

  @override
  String get providerDetailPageApiPathLabel => 'API 路徑';

  @override
  String get providerDetailPageResponseApiTitle => 'Response API (/responses)';

  @override
  String get providerDetailPageAihubmixAppCodeLabel => '應用 Code（享 10% 優惠）';

  @override
  String get providerDetailPageAihubmixAppCodeHelp =>
      '為請求附加 APP-Code，可享 10% 優惠，僅對 AIhubmix 生效。';

  @override
  String get providerDetailPageVertexAiTitle => 'Vertex AI';

  @override
  String get providerDetailPageLocationLabel => '區域 Location';

  @override
  String get providerDetailPageProjectIdLabel => '專案 ID';

  @override
  String get providerDetailPageServiceAccountJsonLabel => '服務帳號 JSON（貼上或匯入）';

  @override
  String get providerDetailPageImportJsonButton => '匯入 JSON';

  @override
  String get providerDetailPageTestButton => '測試';

  @override
  String get providerDetailPageSaveButton => '儲存';

  @override
  String get providerDetailPageProviderRemovedMessage => '供應商已刪除';

  @override
  String get providerDetailPageNoModelsTitle => '暫無模型';

  @override
  String get providerDetailPageNoModelsSubtitle => '點擊下方按鈕新增模型';

  @override
  String get providerDetailPageDeleteModelButton => '刪除';

  @override
  String get providerDetailPageConfirmDeleteTitle => '確認刪除';

  @override
  String get providerDetailPageConfirmDeleteContent => '刪除後可透過撤銷還原。是否刪除？';

  @override
  String get providerDetailPageModelDeletedSnackbar => '已刪除模型';

  @override
  String get providerDetailPageUndoButton => '撤銷';

  @override
  String get providerDetailPageAddNewModelButton => '新增新模型';

  @override
  String get providerDetailPageFetchModelsButton => '取得';

  @override
  String get providerDetailPageEnableProxyTitle => '是否啟用代理';

  @override
  String get providerDetailPageHostLabel => '主機地址';

  @override
  String get providerDetailPagePortLabel => '連接埠';

  @override
  String get providerDetailPageUsernameOptionalLabel => '使用者名稱（可選）';

  @override
  String get providerDetailPagePasswordOptionalLabel => '密碼（可選）';

  @override
  String get providerDetailPageSavedSnackbar => '已儲存';

  @override
  String get providerDetailPageEmbeddingsGroupTitle => '嵌入';

  @override
  String get providerDetailPageOtherModelsGroupTitle => '其他模型';

  @override
  String get providerGroupLabel => '分組';

  @override
  String get providerGroupAuto => '自動';

  @override
  String get providerGroupOfficial => '官方';

  @override
  String get providerGroupSelfHosted => '自建';

  @override
  String get providerGroupLocal => '本地';

  @override
  String get providerGroupPublic => '公益站';

  @override
  String get providerDetailPageRemoveGroupTooltip => '移除本組';

  @override
  String get providerDetailPageAddGroupTooltip => '新增本組';

  @override
  String get providerDetailPageFilterHint => '輸入模型名稱篩選';

  @override
  String get providerDetailPageDeleteText => '刪除';

  @override
  String get providerDetailPageEditTooltip => '編輯';

  @override
  String get providerDetailPageTestConnectionTitle => '測試連線';

  @override
  String get providerDetailPageSelectModelButton => '選擇模型';

  @override
  String get providerDetailPageChangeButton => '更換';

  @override
  String get providerDetailPageUseStreamingLabel => '使用串流';

  @override
  String get providerDetailPageTestingMessage => '正在測試…';

  @override
  String get providerDetailPageTestSuccessMessage => '測試成功';

  @override
  String get providersPageTitle => '供應商';

  @override
  String get providersPageImportTooltip => '匯入';

  @override
  String get providersPageAddTooltip => '新增';

  @override
  String get providersPageProviderAddedSnackbar => '已新增供應商';

  @override
  String get providersPageSiliconFlowName => '矽基流動';

  @override
  String get providersPageAliyunName => '阿里雲千問';

  @override
  String get providersPageZhipuName => '智譜';

  @override
  String get providersPageByteDanceName => '火山引擎';

  @override
  String get providersPageEnabledStatus => '啟用';

  @override
  String get providersPageDisabledStatus => '停用';

  @override
  String get providersPageModelsCountSuffix => ' models';

  @override
  String get providersPageModelsCountSingleSuffix => '個模型';

  @override
  String get addProviderSheetTitle => '新增供應商';

  @override
  String get addProviderSheetEnabledLabel => '是否啟用';

  @override
  String get addProviderSheetNameLabel => '名稱';

  @override
  String get addProviderSheetApiPathLabel => 'API 路徑';

  @override
  String get addProviderSheetVertexAiLocationLabel => '位置';

  @override
  String get addProviderSheetVertexAiProjectIdLabel => '專案ID';

  @override
  String get addProviderSheetVertexAiServiceAccountJsonLabel =>
      '服務帳號 JSON（貼上或匯入）';

  @override
  String get addProviderSheetImportJsonButton => '匯入 JSON';

  @override
  String get addProviderSheetCancelButton => '取消';

  @override
  String get addProviderSheetAddButton => '新增';

  @override
  String get importProviderSheetTitle => '匯入供應商';

  @override
  String get importProviderSheetScanQrTooltip => '掃碼匯入';

  @override
  String get importProviderSheetFromGalleryTooltip => '從相簿匯入';

  @override
  String importProviderSheetImportSuccessMessage(int count) {
    return '已匯入$count個供應商';
  }

  @override
  String importProviderSheetImportFailedMessage(String error) {
    return '匯入失敗: $error';
  }

  @override
  String get importProviderSheetDescription => '貼上分享字串（可多行，每行一個）或 ChatBox JSON';

  @override
  String get importProviderSheetInputHint => 'ai-provider:v1:...';

  @override
  String get importProviderSheetCancelButton => '取消';

  @override
  String get importProviderSheetImportButton => '匯入';

  @override
  String get shareProviderSheetTitle => '分享供應商設定';

  @override
  String get shareProviderSheetDescription => '複製下面的分享字串，或使用QR Code分享。';

  @override
  String get shareProviderSheetCopiedMessage => '已複製';

  @override
  String get shareProviderSheetCopyButton => '複製';

  @override
  String get shareProviderSheetShareButton => '分享';

  @override
  String get desktopProviderContextMenuShare => '分享';

  @override
  String get desktopProviderShareCopyText => '複製文字';

  @override
  String get desktopProviderShareCopyQr => '複製 QR 碼';

  @override
  String get providerDetailPageApiBaseUrlLabel => 'API Base URL';

  @override
  String get providerDetailPageModelsTitle => '模型';

  @override
  String get providerModelsGetButton => '取得';

  @override
  String get providerDetailPageCapsVision => '視覺';

  @override
  String get providerDetailPageCapsImage => '生圖';

  @override
  String get providerDetailPageCapsTool => '工具';

  @override
  String get providerDetailPageCapsReasoning => '推理';

  @override
  String get qrScanPageTitle => '掃碼匯入';

  @override
  String get qrScanPageInstruction => '將QR Code對準取景框';

  @override
  String get searchServicesPageBackTooltip => '返回';

  @override
  String get searchServicesPageTitle => '搜尋服務';

  @override
  String get searchServicesPageDone => '完成';

  @override
  String get searchServicesPageEdit => '編輯';

  @override
  String get searchServicesPageAddProvider => '新增提供商';

  @override
  String get searchServicesPageSearchProviders => '搜尋提供商';

  @override
  String get searchServicesPageGeneralOptions => '通用選項';

  @override
  String get searchServicesPageAutoTestTitle => '啟動時自動測試連線';

  @override
  String get searchServicesPageMaxResults => '最大結果數';

  @override
  String get searchServicesPageTimeoutSeconds => '超時時間（秒）';

  @override
  String get searchServicesPageAtLeastOneServiceRequired => '至少需要一個搜尋服務';

  @override
  String get searchServicesPageTestingStatus => '測試中…';

  @override
  String get searchServicesPageConnectedStatus => '已連線';

  @override
  String get searchServicesPageFailedStatus => '連線失敗';

  @override
  String get searchServicesPageNotTestedStatus => '未測試';

  @override
  String get searchServicesPageEditServiceTooltip => '編輯服務';

  @override
  String get searchServicesPageTestConnectionTooltip => '測試連線';

  @override
  String get searchServicesPageDeleteServiceTooltip => '刪除服務';

  @override
  String get searchServicesPageConfiguredStatus => '已設定';

  @override
  String get miniMapTitle => '迷你地圖';

  @override
  String get miniMapTooltip => '迷你地圖';

  @override
  String get searchServicesPageApiKeyRequiredStatus => '需要 API Key';

  @override
  String get searchServicesPageUrlRequiredStatus => '需要 URL';

  @override
  String get searchServicesAddDialogTitle => '新增搜尋服務';

  @override
  String get searchServicesAddDialogServiceType => '服務類型';

  @override
  String get searchServicesAddDialogBingLocal => '本機';

  @override
  String get searchServicesAddDialogCancel => '取消';

  @override
  String get searchServicesAddDialogAdd => '新增';

  @override
  String get searchServicesAddDialogApiKeyRequired => 'API Key 必填';

  @override
  String get searchServicesAddDialogInstanceUrl => '實例 URL';

  @override
  String get searchServicesAddDialogUrlRequired => 'URL 必填';

  @override
  String get searchServicesAddDialogEnginesOptional => '搜尋引擎（可選）';

  @override
  String get searchServicesAddDialogLanguageOptional => '語言（可選）';

  @override
  String get searchServicesAddDialogUsernameOptional => '使用者名稱（可選）';

  @override
  String get searchServicesAddDialogPasswordOptional => '密碼（可選）';

  @override
  String get searchServicesAddDialogRegionOptional => '地區（可選，預設 us-en）';

  @override
  String get searchServicesEditDialogEdit => '編輯';

  @override
  String get searchServicesEditDialogCancel => '取消';

  @override
  String get searchServicesEditDialogSave => '儲存';

  @override
  String get searchServicesEditDialogBingLocalNoConfig => 'Bing 本機搜尋不需要設定。';

  @override
  String get searchServicesEditDialogApiKeyRequired => 'API Key 必填';

  @override
  String get searchServicesEditDialogInstanceUrl => '實例 URL';

  @override
  String get searchServicesEditDialogUrlRequired => 'URL 必填';

  @override
  String get searchServicesEditDialogEnginesOptional => '搜尋引擎（可選）';

  @override
  String get searchServicesEditDialogLanguageOptional => '語言（可選）';

  @override
  String get searchServicesEditDialogUsernameOptional => '使用者名稱（可選）';

  @override
  String get searchServicesEditDialogPasswordOptional => '密碼（可選）';

  @override
  String get searchServicesEditDialogRegionOptional => '地區（可選，預設 us-en）';

  @override
  String get searchSettingsSheetTitle => '搜尋設定';

  @override
  String get searchSettingsSheetBuiltinSearchTitle => '模型內建搜尋';

  @override
  String get searchSettingsSheetBuiltinSearchDescription => '是否啟用模型內建的搜尋功能';

  @override
  String get searchSettingsSheetWebSearchTitle => '網路搜尋';

  @override
  String get searchSettingsSheetWebSearchDescription => '是否啟用網頁搜尋';

  @override
  String get searchSettingsSheetOpenSearchServicesTooltip => '開啟搜尋服務設定';

  @override
  String get searchSettingsSheetNoServicesMessage => '暫無可用服務，請先在\"搜尋服務\"中新增';

  @override
  String get aboutPageEasterEggMessage => '\n（好吧現在還沒彩蛋）';

  @override
  String get aboutPageEasterEggButton => '好的';

  @override
  String get aboutPageAppDescription => '開源 AI 助理';

  @override
  String get aboutPageNoQQGroup => '暫無QQ群';

  @override
  String get aboutPageVersion => '版本';

  @override
  String get aboutPageSystem => '系統';

  @override
  String get aboutPageWebsite => '官網';

  @override
  String get aboutPageLicense => '授權';

  @override
  String get aboutPageJoinQQGroup => '加入 QQ 群';

  @override
  String get aboutPageJoinDiscord => '加入我們的 Discord';

  @override
  String get displaySettingsPageShowUserAvatarTitle => '顯示使用者頭像';

  @override
  String get displaySettingsPageShowUserAvatarSubtitle => '是否在聊天訊息中顯示使用者頭像';

  @override
  String get displaySettingsPageShowUserNameTimestampTitle => '顯示使用者名稱與時間戳';

  @override
  String get displaySettingsPageShowUserNameTimestampSubtitle =>
      '是否在聊天訊息中顯示使用者名稱以時間戳';

  @override
  String get displaySettingsPageShowUserMessageActionsTitle => '顯示使用者訊息操作按鈕';

  @override
  String get displaySettingsPageShowUserMessageActionsSubtitle =>
      '在使用者訊息下方顯示複製、重傳與更多按鈕';

  @override
  String get displaySettingsPageShowModelNameTimestampTitle => '顯示模型名稱與時間戳';

  @override
  String get displaySettingsPageShowModelNameTimestampSubtitle =>
      '是否在聊天訊息中顯示模型名稱及時間戳';

  @override
  String get displaySettingsPageChatModelIconTitle => '聊天列表模型圖示';

  @override
  String get displaySettingsPageChatModelIconSubtitle => '是否在聊天訊息中顯示模型圖示';

  @override
  String get displaySettingsPageShowTokenStatsTitle => '顯示Token和上下文統計';

  @override
  String get displaySettingsPageShowTokenStatsSubtitle => '顯示 token 用量與訊息數量';

  @override
  String get displaySettingsPageAutoCollapseThinkingTitle => '自動折疊思考';

  @override
  String get displaySettingsPageAutoCollapseThinkingSubtitle =>
      '思考完成後自動折疊，保持介面簡潔';

  @override
  String get displaySettingsPageShowChatListDateTitle => '顯示對話列表日期';

  @override
  String get displaySettingsPageShowChatListDateSubtitle => '在左側對話列表中顯示日期分組標籤';

  @override
  String get displaySettingsPageKeepSidebarOpenOnAssistantTapTitle =>
      '點選助手時不自動關閉側邊欄';

  @override
  String get displaySettingsPageKeepSidebarOpenOnTopicTapTitle =>
      '點選話題時不自動關閉側邊欄';

  @override
  String get displaySettingsPageKeepAssistantListExpandedOnSidebarCloseTitle =>
      '關閉側邊欄時不折疊助手列表';

  @override
  String get displaySettingsPageShowUpdatesTitle => '顯示更新';

  @override
  String get displaySettingsPageShowUpdatesSubtitle => '顯示應用程式更新通知';

  @override
  String get displaySettingsPageMessageNavButtonsTitle => '訊息導航按鈕';

  @override
  String get displaySettingsPageMessageNavButtonsSubtitle => '滾動時顯示快速跳轉按鈕';

  @override
  String get displaySettingsPageHapticsOnSidebarTitle => '側邊欄觸覺回饋';

  @override
  String get displaySettingsPageHapticsOnSidebarSubtitle => '開啟/關閉側邊欄時啟用觸覺回饋';

  @override
  String get displaySettingsPageHapticsGlobalTitle => '全域觸覺回饋';

  @override
  String get displaySettingsPageHapticsIosSwitchTitle => '開關觸覺回饋';

  @override
  String get displaySettingsPageHapticsOnListItemTapTitle => '列表項點擊觸覺回饋';

  @override
  String get displaySettingsPageHapticsOnCardTapTitle => '卡片點擊觸覺回饋';

  @override
  String get displaySettingsPageHapticsOnGenerateTitle => '訊息生成觸覺回饋';

  @override
  String get displaySettingsPageHapticsOnGenerateSubtitle => '生成訊息時啟用觸覺回饋';

  @override
  String get displaySettingsPageNewChatAfterDeleteTitle => '刪除話題後新建對話';

  @override
  String get displaySettingsPageNewChatOnAssistantSwitchTitle => '切換助理時新建對話';

  @override
  String get displaySettingsPageNewChatOnLaunchTitle => '啟動時新建對話';

  @override
  String get displaySettingsPageAutoSwitchTopicsTitle => '自動切換話題';

  @override
  String get desktopDisplaySettingsTopicPositionTitle => '主題位置';

  @override
  String get desktopDisplaySettingsTopicPositionLeft => '左側';

  @override
  String get desktopDisplaySettingsTopicPositionRight => '右側';

  @override
  String get displaySettingsPageNewChatOnLaunchSubtitle => '應用程式啟動時自動建立新對話';

  @override
  String get displaySettingsPageChatFontSizeTitle => '聊天字體大小';

  @override
  String get displaySettingsPageAutoScrollEnableTitle => '自動回到底部';

  @override
  String get displaySettingsPageAutoScrollIdleTitle => '自動回到底部延遲';

  @override
  String get displaySettingsPageAutoScrollIdleSubtitle => '使用者停止捲動後等待多久再自動回到底部';

  @override
  String get displaySettingsPageAutoScrollDisabledLabel => '已關閉';

  @override
  String get displaySettingsPageChatFontSampleText => '這是一個範例的聊天文本';

  @override
  String get displaySettingsPageChatBackgroundMaskTitle => '聊天背景遮罩透明度';

  @override
  String get displaySettingsPageThemeSettingsTitle => '主題設定';

  @override
  String get displaySettingsPageThemeColorTitle => '主題顏色';

  @override
  String get desktopSettingsFontsTitle => '字體設定';

  @override
  String get displaySettingsPageTrayTitle => '系統匣';

  @override
  String get displaySettingsPageTrayShowTrayTitle => '顯示系統匣圖示';

  @override
  String get displaySettingsPageTrayMinimizeOnCloseTitle => '關閉視窗時最小化到系統匣';

  @override
  String get desktopFontAppLabel => '應用字體';

  @override
  String get desktopFontCodeLabel => '程式碼字體';

  @override
  String get desktopFontFamilySystemDefault => '系統預設';

  @override
  String get desktopFontFamilyMonospaceDefault => '系統預設';

  @override
  String get desktopFontFilterHint => '輸入以過濾字體…';

  @override
  String get displaySettingsPageAppFontTitle => '應用字體';

  @override
  String get displaySettingsPageCodeFontTitle => '程式碼字體';

  @override
  String get fontPickerChooseLocalFile => '選擇本機檔案';

  @override
  String get fontPickerGetFromGoogleFonts => '從 Google Fonts 取得';

  @override
  String get fontPickerFilterHint => '輸入以過濾字體…';

  @override
  String get desktopFontLoading => '正在載入字體…';

  @override
  String get displaySettingsPageFontLocalFileLabel => '本機檔案';

  @override
  String get displaySettingsPageFontResetLabel => '回復預設設定';

  @override
  String get displaySettingsPageOtherSettingsTitle => '其他設定';

  @override
  String get themeSettingsPageDynamicColorSection => '動態顏色';

  @override
  String get themeSettingsPageUseDynamicColorTitle => '系統動態配色';

  @override
  String get themeSettingsPageUseDynamicColorSubtitle => '基於系統配色（Android 12+）';

  @override
  String get themeSettingsPageUsePureBackgroundTitle => '純色背景';

  @override
  String get themeSettingsPageUsePureBackgroundSubtitle => '僅氣泡與強調色隨主題變化';

  @override
  String get themeSettingsPageColorPalettesSection => '配色方案';

  @override
  String get ttsServicesPageBackButton => '返回';

  @override
  String get ttsServicesPageTitle => '語音服務';

  @override
  String get ttsServicesPageAddTooltip => '新增';

  @override
  String get ttsServicesPageAddNotImplemented => '新增 TTS 服務暫未實現';

  @override
  String get ttsServicesPageSystemTtsTitle => '系統TTS';

  @override
  String get ttsServicesPageSystemTtsAvailableSubtitle => '使用系統內建語音合成';

  @override
  String ttsServicesPageSystemTtsUnavailableSubtitle(String error) {
    return '不可用：$error';
  }

  @override
  String get ttsServicesPageSystemTtsUnavailableNotInitialized => '未初始化';

  @override
  String get ttsServicesPageTestSpeechText => '你好，這是一次測試語音。';

  @override
  String get ttsServicesPageConfigureTooltip => '設定';

  @override
  String get ttsServicesPageTestVoiceTooltip => '測試語音';

  @override
  String get ttsServicesPageStopTooltip => '停止';

  @override
  String get ttsServicesPageDeleteTooltip => '刪除';

  @override
  String get ttsServicesPageSystemTtsSettingsTitle => '系統 TTS 設定';

  @override
  String get ttsServicesPageEngineLabel => '引擎';

  @override
  String get ttsServicesPageAutoLabel => '自動';

  @override
  String get ttsServicesPageLanguageLabel => '語言';

  @override
  String get ttsServicesPageSpeechRateLabel => '語速';

  @override
  String get ttsServicesPagePitchLabel => '音調';

  @override
  String get ttsServicesPageSettingsSavedMessage => '設定已儲存。';

  @override
  String get ttsServicesPageDoneButton => '完成';

  @override
  String get ttsServicesPageNetworkSectionTitle => '網路 TTS';

  @override
  String get ttsServicesPageNoNetworkServices => '暫無語音服務';

  @override
  String get ttsServicesDialogAddTitle => '新增語音服務';

  @override
  String get ttsServicesDialogEditTitle => '編輯語音服務';

  @override
  String get ttsServicesDialogProviderType => '服務提供者';

  @override
  String get ttsServicesDialogCancelButton => '取消';

  @override
  String get ttsServicesDialogAddButton => '新增';

  @override
  String get ttsServicesDialogSaveButton => '儲存';

  @override
  String get ttsServicesFieldNameLabel => '名稱';

  @override
  String get ttsServicesFieldApiKeyLabel => 'API Key';

  @override
  String get ttsServicesFieldBaseUrlLabel => 'API 基址';

  @override
  String get ttsServicesFieldModelLabel => '模型';

  @override
  String get ttsServicesFieldVoiceLabel => '音色';

  @override
  String get ttsServicesFieldVoiceIdLabel => '音色 ID';

  @override
  String get ttsServicesFieldEmotionLabel => '情感';

  @override
  String get ttsServicesFieldSpeedLabel => '語速';

  @override
  String get ttsServicesViewDetailsButton => '檢視詳細';

  @override
  String get ttsServicesDialogErrorTitle => '錯誤詳情';

  @override
  String get ttsServicesCloseButton => '關閉';

  @override
  String imageViewerPageShareFailedOpenFile(String message) {
    return '無法分享，已嘗試開啟檔案: $message';
  }

  @override
  String imageViewerPageShareFailed(String error) {
    return '分享失敗: $error';
  }

  @override
  String get imageViewerPageShareButton => '分享圖片';

  @override
  String get imageViewerPageSaveButton => '儲存圖片';

  @override
  String get imageViewerPageSaveSuccess => '已儲存到相簿';

  @override
  String imageViewerPageSaveFailed(String error) {
    return '儲存失敗: $error';
  }

  @override
  String get settingsShare => 'Kelivo - 開源AI助理';

  @override
  String get searchProviderBingLocalDescription =>
      '使用網路抓取工具取得 Bing 搜尋結果。無需 API 金鑰，但可能不夠穩定。';

  @override
  String get searchProviderDuckDuckGoDescription =>
      '基於 DDGS 的 DuckDuckGo 隱私搜尋，無需 API 金鑰，支援設定地區。';

  @override
  String get searchProviderBraveDescription => 'Brave 獨立搜尋引擎。注重隱私，無追蹤或建立個人檔案。';

  @override
  String get searchProviderExaDescription => '具備語義理解的神經搜尋引擎。適合研究與查找特定內容。';

  @override
  String get searchProviderLinkUpDescription =>
      '提供來源可追溯答案的搜尋 API，同時提供搜尋結果與 AI 摘要。';

  @override
  String get searchProviderMetasoDescription => '秘塔中文搜尋引擎。針對中文內容優化並提供 AI 能力。';

  @override
  String get searchProviderSearXNGDescription => '重視隱私的元搜尋引擎。需自建實例，無追蹤。';

  @override
  String get searchProviderTavilyDescription =>
      '為大型語言模型（LLM）優化的 AI 搜尋 API，提供高品質、相關的搜尋結果。';

  @override
  String get searchProviderZhipuDescription =>
      '智譜 AI 旗下中文 AI 搜尋服務，針對中文內容與查詢進行優化。';

  @override
  String get searchProviderOllamaDescription =>
      'Ollama 網路搜尋 API。為模型補充最新資訊，降低幻覺並提升準確性。';

  @override
  String get searchProviderJinaDescription =>
      'AI 搜尋基礎設施：提供 Embeddings、重排序、Web Reader、DeepSearch 與小語言模型。支援多語言與多模態。';

  @override
  String get searchServiceNameBingLocal => 'Bing（本機）';

  @override
  String get searchServiceNameDuckDuckGo => 'DuckDuckGo';

  @override
  String get searchServiceNameTavily => 'Tavily';

  @override
  String get searchServiceNameExa => 'Exa';

  @override
  String get searchServiceNameZhipu => 'Zhipu（智譜）';

  @override
  String get searchServiceNameSearXNG => 'SearXNG';

  @override
  String get searchServiceNameLinkUp => 'LinkUp';

  @override
  String get searchServiceNameBrave => 'Brave 搜尋';

  @override
  String get searchServiceNameMetaso => 'Metaso（秘塔）';

  @override
  String get searchServiceNameOllama => 'Ollama';

  @override
  String get searchServiceNameJina => 'Jina';

  @override
  String get searchServiceNamePerplexity => 'Perplexity';

  @override
  String get searchProviderPerplexityDescription =>
      'Perplexity 搜尋 API。提供排序的網頁結果，支援地區與網域過濾。';

  @override
  String get searchServiceNameBocha => '博查';

  @override
  String get searchProviderBochaDescription =>
      '博查 AI 全網網頁搜尋，支援時間範圍與摘要，更適合 AI 使用。';

  @override
  String get generationInterrupted => '生成已中斷';

  @override
  String get titleForLocale => '新對話';

  @override
  String get quickPhraseBackTooltip => '返回';

  @override
  String get quickPhraseGlobalTitle => '快捷片語';

  @override
  String get quickPhraseAssistantTitle => '助理快捷片語';

  @override
  String get quickPhraseAddTooltip => '新增快捷片語';

  @override
  String get quickPhraseEmptyMessage => '暫無快捷片語';

  @override
  String get quickPhraseAddTitle => '新增快捷片語';

  @override
  String get quickPhraseEditTitle => '編輯快捷片語';

  @override
  String get quickPhraseTitleLabel => '標題';

  @override
  String get quickPhraseContentLabel => '內容';

  @override
  String get quickPhraseCancelButton => '取消';

  @override
  String get quickPhraseSaveButton => '儲存';

  @override
  String get instructionInjectionTitle => '指令注入';

  @override
  String get instructionInjectionBackTooltip => '返回';

  @override
  String get instructionInjectionAddTooltip => '新增指令注入';

  @override
  String get instructionInjectionImportTooltip => '從檔案匯入';

  @override
  String get instructionInjectionEmptyMessage => '暫無指令注入卡片';

  @override
  String get instructionInjectionDefaultTitle => '學習模式';

  @override
  String get instructionInjectionAddTitle => '新增指令注入';

  @override
  String get instructionInjectionEditTitle => '編輯指令注入';

  @override
  String get instructionInjectionNameLabel => '名稱';

  @override
  String get instructionInjectionPromptLabel => '提示詞';

  @override
  String instructionInjectionImportSuccess(int count) {
    return '已匯入 $count 個指令注入';
  }

  @override
  String get instructionInjectionSheetSubtitle => '為目前對話選擇並套用一條指令提示詞';

  @override
  String get mcpJsonEditButtonTooltip => '編輯 JSON';

  @override
  String get mcpJsonEditTitle => '編輯 JSON';

  @override
  String get mcpJsonEditParseFailed => 'JSON 解析失敗';

  @override
  String get mcpJsonEditSavedApplied => '已儲存並套用';

  @override
  String get mcpTimeoutSettingsTooltip => '設定工具呼叫逾時';

  @override
  String get mcpTimeoutDialogTitle => '工具呼叫逾時';

  @override
  String get mcpTimeoutSecondsLabel => '工具呼叫逾時（秒）';

  @override
  String get mcpTimeoutInvalid => '請輸入大於 0 的秒數';

  @override
  String get quickPhraseEditButton => '編輯';

  @override
  String get quickPhraseDeleteButton => '刪除';

  @override
  String get quickPhraseMenuTitle => '快捷片語';

  @override
  String get chatInputBarQuickPhraseTooltip => '快捷片語';

  @override
  String get assistantEditQuickPhraseDescription =>
      '管理此助理的快捷片語。點擊下方按鈕以新增或編輯片語。';

  @override
  String get assistantEditManageQuickPhraseButton => '管理快捷片語';

  @override
  String get assistantEditPageMemoryTab => '記憶';

  @override
  String get assistantEditMemorySwitchTitle => '記憶';

  @override
  String get assistantEditMemorySwitchDescription => '允許助理主動儲存並在對話間引用使用者相關資訊';

  @override
  String get assistantEditRecentChatsSwitchTitle => '參考歷史聊天記錄';

  @override
  String get assistantEditRecentChatsSwitchDescription =>
      '在新對話中引用最近的對話標題以增強上下文';

  @override
  String get assistantEditManageMemoryTitle => '管理記憶';

  @override
  String get assistantEditAddMemoryButton => '新增記憶';

  @override
  String get assistantEditMemoryEmpty => '暫無記憶';

  @override
  String get assistantEditMemoryDialogTitle => '記憶';

  @override
  String get assistantEditMemoryDialogHint => '輸入記憶內容';

  @override
  String get assistantEditAddQuickPhraseButton => '新增快捷片語';

  @override
  String get multiKeyPageDeleteSnackbarDeletedOne => '已刪除 1 個 Key';

  @override
  String get multiKeyPageUndo => '撤銷';

  @override
  String get multiKeyPageUndoRestored => '已撤銷刪除';

  @override
  String get multiKeyPageDeleteErrorsTooltip => '刪除錯誤';

  @override
  String get multiKeyPageDeleteErrorsConfirmTitle => '刪除所有錯誤的 Key？';

  @override
  String get multiKeyPageDeleteErrorsConfirmContent => '這將移除所有狀態為錯誤的 Key。';

  @override
  String multiKeyPageDeletedErrorsSnackbar(int n) {
    return '已刪除 $n 個錯誤 Key';
  }

  @override
  String get providerDetailPageProviderTypeTitle => '供應商類型';

  @override
  String get displaySettingsPageChatItemDisplayTitle => '聊天項顯示';

  @override
  String get displaySettingsPageRenderingSettingsTitle => '渲染設定';

  @override
  String get displaySettingsPageBehaviorStartupTitle => '行為與啟動';

  @override
  String get displaySettingsPageHapticsSettingsTitle => '觸覺回饋';

  @override
  String get assistantSettingsNoPromptPlaceholder => '暫無提示詞';

  @override
  String get providersPageMultiSelectTooltip => '多選';

  @override
  String get providersPageDeleteSelectedConfirmContent =>
      '確定要刪除選中的供應商嗎？此操作不可撤銷。';

  @override
  String get providersPageDeleteSelectedSnackbar => '已刪除選中的供應商';

  @override
  String providersPageExportSelectedTitle(int count) {
    return '匯出 $count 個供應商';
  }

  @override
  String get providersPageExportCopyButton => '複製';

  @override
  String get providersPageExportShareButton => '分享';

  @override
  String get providersPageExportCopiedSnackbar => '已複製匯出代碼';

  @override
  String get providersPageDeleteAction => '刪除';

  @override
  String get providersPageExportAction => '匯出';

  @override
  String get assistantEditPresetTitle => '預設對話訊息';

  @override
  String get assistantEditPresetAddUser => '新增預設使用者訊息';

  @override
  String get assistantEditPresetAddAssistant => '新增預設助手訊息';

  @override
  String get assistantEditPresetInputHintUser => '輸入使用者訊息…';

  @override
  String get assistantEditPresetInputHintAssistant => '輸入助手訊息…';

  @override
  String get assistantEditPresetEmpty => '暫無預設訊息';

  @override
  String get assistantEditPresetEditDialogTitle => '編輯預設訊息';

  @override
  String get assistantEditPresetRoleUser => '使用者';

  @override
  String get assistantEditPresetRoleAssistant => '助手';

  @override
  String get desktopTtsPleaseAddProvider => '請先在設定中新增語音服務商';

  @override
  String get settingsPageNetworkProxy => '網絡代理';

  @override
  String get networkProxyEnableLabel => '啟動代理';

  @override
  String get networkProxySettingsHeader => '代理設定';

  @override
  String get networkProxyType => '代理類型';

  @override
  String get networkProxyTypeHttp => 'HTTP';

  @override
  String get networkProxyTypeHttps => 'HTTPS';

  @override
  String get networkProxyTypeSocks5 => 'SOCKS5';

  @override
  String get networkProxyServerHost => '伺服器地址';

  @override
  String get networkProxyPort => '連接埠';

  @override
  String get networkProxyUsername => '使用者名稱';

  @override
  String get networkProxyPassword => '密碼';

  @override
  String get networkProxyOptionalHint => '可選';

  @override
  String get networkProxyTestHeader => '連線測試';

  @override
  String get networkProxyTestUrlHint => '測試地址';

  @override
  String get networkProxyTestButton => '測試';

  @override
  String get networkProxyTesting => '測試中…';

  @override
  String get networkProxyTestSuccess => '連線成功';

  @override
  String networkProxyTestFailed(String error) {
    return '測試失敗：$error';
  }

  @override
  String get networkProxyNoUrl => '請輸入測試地址';

  @override
  String get networkProxyPriorityNote => '同時啟用全域代理與供應商代理時，將優先使用供應商代理。';

  @override
  String get desktopShowProviderInModelCapsule => '模型膠囊顯示供應商';

  @override
  String get messageWebViewOpenInBrowser => '在瀏覽器中開啟';

  @override
  String get messageWebViewConsoleLogs => '控制台日誌';

  @override
  String get messageWebViewNoConsoleMessages => '暫無控制台訊息';

  @override
  String get messageWebViewRefreshTooltip => '重新整理';

  @override
  String get messageWebViewForwardTooltip => '前進';

  @override
  String get chatInputBarOcrTooltip => 'OCR 文字辨識';

  @override
  String get providerDetailPageBatchDetectButton => '檢測';

  @override
  String get providerDetailPageBatchDetecting => '檢測中...';

  @override
  String get providerDetailPageBatchDetectStart => '開始檢測';

  @override
  String get providerDetailPageDetectSuccess => '檢測成功';

  @override
  String get providerDetailPageDetectFailed => '檢測失敗';

  @override
  String get providerDetailPageDeleteAllModelsWarning => '此操作不可撤回';

  @override
  String get requestLogSettingTitle => '請求日誌列印';

  @override
  String get requestLogSettingSubtitle => '開啟後會將請求/回應詳細寫入 logs/logs.txt';

  @override
  String get flutterLogSettingTitle => 'Flutter日誌列印';

  @override
  String get flutterLogSettingSubtitle =>
      '開啟後會將 Flutter 錯誤與 print 輸出寫入 logs/flutter_logs.txt';

  @override
  String get logViewerTitle => '請求日誌';

  @override
  String get logViewerEmpty => '暫無日誌';

  @override
  String get logViewerCurrentLog => '目前日誌';

  @override
  String get logViewerExport => '匯出';

  @override
  String get logViewerOpenFolder => '開啟日誌目錄';

  @override
  String get assistantEditManageSummariesTitle => '管理摘要';

  @override
  String get assistantEditSummaryEmpty => '暫無摘要';

  @override
  String get assistantEditSummaryDialogTitle => '編輯摘要';

  @override
  String get assistantEditSummaryDialogHint => '輸入摘要內容';

  @override
  String get assistantEditDeleteSummaryTitle => '清除摘要';

  @override
  String get assistantEditDeleteSummaryContent => '確定要清除此摘要嗎？';
}
