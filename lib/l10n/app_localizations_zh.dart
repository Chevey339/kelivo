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
  String get settingsPageDisplay => '偏好设置';

  @override
  String get settingsPageDisplaySubtitle => '外观、行为与交互偏好';

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
  String get storageSpaceCategoryFonts => '字体';

  @override
  String get storageSpaceCategoryLocalModels => '本地模型';

  @override
  String get storageSpaceOtherHint => '包括导入字体、本地下载模型和其他应用文件。';

  @override
  String get storageSpaceSubOtherApp => '其他文件';

  @override
  String get storageSpaceCategoryChatData => '聊天记录';

  @override
  String get storageSpaceCategoryLegacyChatData => '聊天记录（旧）';

  @override
  String get storageSpaceCategoryRestoreTraces => '恢复痕迹';

  @override
  String get storageSpaceRestoreTracesHint => '恢复完成后保留的旧数据快照。清理不会影响当前应用数据。';

  @override
  String get storageSpaceClearRestoreTracesButton => '清理恢复痕迹';

  @override
  String get storageSpaceClearRestoreTracesConfirmMessage =>
      '确定清理已完成恢复留下的旧数据快照吗？当前数据库、设置和文件不会受到影响。';

  @override
  String get storageSpaceSubCompletedRestoreRuns => '已完成的恢复快照';

  @override
  String get storageSpaceCategoryAssistantData => '助手';

  @override
  String get storageSpaceCategoryCache => '缓存';

  @override
  String get storageSpaceCategoryLogs => '日志';

  @override
  String get storageSpaceCategoryOther => '其他';

  @override
  String storageSpaceFilesCount(int count) {
    return '$count 个文件';
  }

  @override
  String get storageSpaceSafeToClearHint => '可安全清理，不影响聊天记录。';

  @override
  String get storageSpaceLegacyChatDataHint =>
      '这是迁移到 SQLite 前保留的 Hive 旧文件。清理后不会删除当前聊天记录。';

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
  String get storageSpaceSubChatDatabase => '聊天数据库';

  @override
  String get storageSpaceSubChatWriteAheadLog => '写入日志';

  @override
  String get storageSpaceSubChatSharedMemory => '共享内存索引';

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
  String get storageSpaceSubLogsContext => '上下文日志';

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
  String get storageSpaceClearLegacyChatDataButton => '清理旧聊天记录';

  @override
  String get storageSpaceExportLegacyChatFileButton => '导出';

  @override
  String storageSpaceExportDone(Object fileName) {
    return '已导出 $fileName';
  }

  @override
  String storageSpaceExportFailed(Object error) {
    return '导出失败：$error';
  }

  @override
  String get storageSpaceClearLegacyChatDataConfirmMessage =>
      '确定清理保留的旧聊天文件吗？当前 SQLite 聊天记录不会受到影响。';

  @override
  String get storageSpaceViewLogsButton => '查看日志';

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
  String get storageSpaceSourceLabel => '来源';

  @override
  String get storageSpaceSourceAll => '全部';

  @override
  String get storageSpaceSourceUserUpload => '用户上传';

  @override
  String get storageSpaceSourceAssistant => '助手发出';

  @override
  String get storageSpaceSortLabel => '排序';

  @override
  String get storageSpaceSortNewest => '最新';

  @override
  String get storageSpaceSortOldest => '最旧';

  @override
  String get storageSpaceSortLargest => '最大';

  @override
  String get storageSpaceSortSmallest => '最小';

  @override
  String get settingsPageAboutSection => '关于';

  @override
  String get settingsPageAbout => '关于';

  @override
  String get settingsPageStatistics => '统计';

  @override
  String get settingsPageDocs => '使用文档';

  @override
  String get settingsPageLogs => '日志';

  @override
  String get settingsPageSponsor => '赞助';

  @override
  String get settingsPageShare => '分享';

  @override
  String get statsPageTitle => '统计';

  @override
  String get statsPageRangeAllTime => '全部';

  @override
  String get statsPageRangeLast30Days => '最近 30 天';

  @override
  String get statsPageRangePreviousMonth => '上个月';

  @override
  String get statsPageRangePreviousQuarter => '上个季度';

  @override
  String get statsPageRangeCustom => '自定义';

  @override
  String get statsPageHeatmapTitle => '聊天热力图';

  @override
  String get statsPageHeatmapLess => '少';

  @override
  String get statsPageHeatmapMore => '多';

  @override
  String get statsPageSummaryTitle => '总览';

  @override
  String get statsPageTotalConversations => '总对话数';

  @override
  String get statsPageTotalMessages => '总消息数';

  @override
  String get statsPageInputTokens => '输入 Tokens';

  @override
  String get statsPageOutputTokens => '输出 Tokens';

  @override
  String get statsPageCachedTokens => '缓存 Tokens';

  @override
  String get statsPageLaunchCount => '应用启动次数';

  @override
  String get statsPageUsageTrendTitle => '用量趋势';

  @override
  String get statsPageModelUsageTitle => '模型使用率';

  @override
  String get statsPageAssistantUsageTitle => '助手使用率';

  @override
  String get statsPageTopicVolumeTitle => '话题内容量';

  @override
  String get statsPageModelColumn => '模型';

  @override
  String get statsPageAssistantColumn => '助手';

  @override
  String get statsPageTopicColumn => '话题';

  @override
  String get statsPageMessagesColumn => '消息数';

  @override
  String get statsPageTopicsColumn => '话题数';

  @override
  String get statsPageEmptyTitle => '暂无统计数据';

  @override
  String get statsPageShowAllTooltip => '查看全部';

  @override
  String get statsPageClose => '关闭';

  @override
  String get statsPageUnknownProvider => '未知供应商';

  @override
  String get statsPageUnknownAssistant => '默认助手';

  @override
  String get statsPageUnknownModel => '未知模型';

  @override
  String get statsPageUnknownTopic => '未命名话题';

  @override
  String get statsPageCustomRangeTitle => '自定义时间段';

  @override
  String get statsPageCustomRangeStart => '开始';

  @override
  String get statsPageCustomRangeEnd => '结束';

  @override
  String get statsPageCustomRangeCancel => '取消';

  @override
  String get statsPageCustomRangeApply => '应用';

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
  String get sponsorPageScanQrHint => '扫描二维码赞助';

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
  String get mermaidImageTab => '图片';

  @override
  String get mermaidCodeTab => '代码';

  @override
  String get mermaidFullScreen => '全屏';

  @override
  String get mermaidGeneratingImage => '图片生成中';

  @override
  String get mermaidGenerationFailedHint => '生成失败，换个方式问问吧';

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
  String assistantProviderSampleAssistantSystemPrompt(String model_name) {
    return '你是$model_name，一位乐于助人的 AI 助手。请准确、简洁地回答问题；不确定时如实说明。需要时可使用清晰结构（短段落或列表）。默认使用用户的语言回复。';
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
  String get mcpTransportTagSse => 'SSE';

  @override
  String get mcpTransportTagHttp => 'HTTP';

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
  String get homePageAudioAttachmentUnsupported =>
      '当前模型不支持音频附件，请切换到支持音频输入的模型或移除音频文件后重试。';

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
  String get homePageDeleteMessage => '删除本版本';

  @override
  String get homePageDeleteMessageConfirm => '确定要删除当前版本吗？此操作不可撤销。';

  @override
  String get homePageDeleteAllVersions => '删除全部版本';

  @override
  String get homePageDeleteAllVersionsConfirm => '确定要删除这条消息的全部版本吗？此操作不可撤销。';

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
  String get assistantEditPageLocalToolsTab => '本地工具';

  @override
  String get assistantEditTabLayoutTooltip => '自定义标签页';

  @override
  String get assistantEditTabLayoutTitle => '自定义标签页';

  @override
  String get assistantEditTabLayoutSubtitle => '拖动标签页调整顺序，关闭暂时用不到的标签页。';

  @override
  String get assistantEditOutlineModeTitle => '二级列表样式';

  @override
  String get assistantEditOutlineModeSubtitle => '先显示助手概览，再从列表进入各个设置项。';

  @override
  String get assistantEditTabLayoutResetTooltip => '重置标签页布局';

  @override
  String get assistantEditTabLayoutAtLeastOneVisible => '至少保留一个可见标签页';

  @override
  String assistantEditTabLayoutDragHandle(String tab) {
    return '拖动以调整 $tab 的顺序';
  }

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
  String get assistantRegexScopeReplaceOnly => '仅替换';

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
  String get assistantEditUseAssistantAvatarSubtitle => '在聊天中使用助手头像替代模型头像';

  @override
  String get assistantEditUseAssistantNameTitle => '使用助手名字';

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
  String get desktopNavGlobalSearchTooltip => '全局搜索';

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
  String get displaySettingsPageIosBackgroundChatTitle => 'iOS 后台生成';

  @override
  String get iosBackgroundSettingsPageTitle => 'iOS 后台生成';

  @override
  String get iosBackgroundStatusOn => '开启';

  @override
  String get iosBackgroundStatusOff => '关闭';

  @override
  String get iosBackgroundGenerationEnableTitle => '后台生成';

  @override
  String get iosBackgroundGenerationEnableSubtitle =>
      'App 离开前台后，使用 iOS 分配的后台时间继续当前回复。';

  @override
  String get iosBackgroundTaskRefreshTitle => '后台任务恢复';

  @override
  String get iosBackgroundTaskRefreshSubtitle => '在系统条件允许时，向 iOS 请求刷新和处理机会。';

  @override
  String get iosLiveActivityTitle => '实时活动';

  @override
  String get iosLiveActivitySubtitle => '支持时在锁屏和灵动岛显示后台回复状态。';

  @override
  String get iosBackgroundNotificationsTitle => '任务通知';

  @override
  String get iosBackgroundNotificationsSubtitle => '后台回复完成或中断时发送本地通知。';

  @override
  String get iosBackgroundLimitNoticeTitle => 'iOS 仍可能暂停任务';

  @override
  String get iosBackgroundLimitNoticeBody =>
      '这些选项使用 Apple 支持的后台时间、BackgroundTasks、通知和实时活动。它们能提升连续性，但不能强制 iOS 永久保持 Kelivo 运行。';

  @override
  String get iosBackgroundUnsupportedLiveActivity =>
      '需要 iOS 16.1 或更高版本，并在系统设置中允许实时活动。';

  @override
  String get iosBackgroundNativeStatusTitle => '系统状态';

  @override
  String get iosBackgroundNativeStatusUnavailable => '需要在 iOS 上运行后查看';

  @override
  String get iosBackgroundLiveActivityAvailable => '实时活动可用';

  @override
  String get iosBackgroundLiveActivityUnavailable => '实时活动不可用';

  @override
  String get iosBackgroundNotificationsAuthorized => '通知已允许';

  @override
  String get iosBackgroundNotificationsNotAuthorized => '通知未允许';

  @override
  String get iosBackgroundGenerationActiveTitle => 'Kelivo 正在生成';

  @override
  String get iosBackgroundGenerationActiveDetail => '助手正在后台回复';

  @override
  String get iosBackgroundGenerationStreamingDetail => '正在接收助手回复';

  @override
  String iosBackgroundGenerationTokenCount(int count) {
    return '$count tokens';
  }

  @override
  String get iosBackgroundGenerationCompleteTitle => '生成完成';

  @override
  String get iosBackgroundGenerationCompleteDetail => '助手回复已准备好';

  @override
  String get iosBackgroundGenerationInterruptedTitle => '生成已中断';

  @override
  String get iosBackgroundGenerationInterruptedDetail => '后台回复在完成前停止';

  @override
  String get iosBackgroundGenerationCancelledDetail => '生成已停止';

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
  String get assistantEditPromptTimeVarWarning =>
      '在系统提示词中使用时间变量会让每一轮请求的开头都不同，Prompt 缓存无法命中，费用和首字延迟都会上升。需要让模型知道当前时间时，请改用下方的「追加当前时间」开关。';

  @override
  String get assistantEditPromptAppendTimeTitle => '追加当前时间';

  @override
  String get assistantEditPromptAppendTimeSubtitle =>
      '在每条用户消息末尾追加发送时刻。时间在请求末尾，不影响 Prompt 缓存。';

  @override
  String get assistantEditPromptAppendTimeInfoTitle => '追加时间格式';

  @override
  String assistantEditPromptAppendTimeInfoBody(String example) {
    return '开启后，会在每条用户消息末尾先空一行，再追加如下标签：\n\n$example\n\n时间取该消息自己的发送时刻，重试时保持不变。';
  }

  @override
  String get assistantEditPromptAppendTimeInfoClose => '知道了';

  @override
  String get assistantEditPromptTimeVarDialogTitle => '系统提示词中含时间变量';

  @override
  String assistantEditPromptTimeVarDialogBody(String variables) {
    return '你的系统提示词里用了 $variables。系统提示词每次请求都会重新渲染，含时间变量会让每一轮请求的开头都不同，Prompt 缓存无法命中。建议移除这些变量，改用「追加当前时间」——它把时间放在请求末尾，不影响前缀。';
  }

  @override
  String get assistantEditPromptTimeVarDialogRemove => '去移除';

  @override
  String get assistantEditPromptTimeVarDialogKeep => '仍然开启';

  @override
  String get codeBlockPreviewButton => '预览';

  @override
  String get codeBlockSaveAsButton => '另存为文件';

  @override
  String get codeBlockCollapseButton => '折叠';

  @override
  String get codeBlockExpandButton => '展开';

  @override
  String get codeBlockDefaultFileNameStem => '代码';

  @override
  String get markdownTableLabel => '表格';

  @override
  String get markdownTableExportCsvTooltip => '导出 CSV';

  @override
  String get markdownTableSaveImageTooltip => '保存到相册';

  @override
  String get markdownTableDefaultFileNameStem => '表格';

  @override
  String get markdownTableCopiedCsvSnackbar => '已复制 CSV，长按复制可复制为图片';

  @override
  String get markdownTableCopiedMarkdownSnackbar => '已复制表格';

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
  String get backupPageRestartContent => '导入成功。重启 Kelivo 后将安全应用。';

  @override
  String backupPageRestartContentWithSkipped(int count) {
    return '导入已完成，但已跳过 $count 个消息顺序非法的会话。重启 Kelivo 后将安全应用已导入的数据。';
  }

  @override
  String get restartAppFailedMessage => 'Kelivo 无法自动重启，请完全关闭后重新打开。';

  @override
  String get backupRestoreRolledBackTitle => '恢复已回滚';

  @override
  String get backupRestoreRolledBackContent => '恢复未能完成。Kelivo 已验证并保留原有数据。';

  @override
  String get backupRestoreFailureTitle => '恢复需要处理';

  @override
  String get backupRestoreFailureContent =>
      'Kelivo 无法验证完整的原有或新数据，因此未打开聊天数据。请关闭 Kelivo 后重试；若问题反复出现，请保留诊断码以便支持人员排查。';

  @override
  String get backupRestoreBusinessLeaseUnavailableTitle => 'Kelivo 已在运行';

  @override
  String get backupRestoreBusinessLeaseUnavailableContent =>
      'Kelivo 的数据仍被另一个应用进程占用。请关闭其他 Kelivo 窗口后重新启动；当前进程尚未打开聊天数据。';

  @override
  String get backupRestoreFailureRestartButton => '重启 Kelivo';

  @override
  String get backupRestoreFailureCopyButton => '复制诊断码';

  @override
  String get backupRestoreFailureCopied => '已复制诊断码';

  @override
  String backupRestoreFailureDiagnostic(String code) {
    return '诊断码：$code';
  }

  @override
  String get startupRecoveryMoreOptions => '更多恢复选项';

  @override
  String get startupRecoveryRepairButton => '修复并重启';

  @override
  String get startupRecoveryExportButton => '导出我的数据副本';

  @override
  String get startupRecoveryResetButton => '重置数据';

  @override
  String get startupRecoveryBusy => '处理中…';

  @override
  String get startupRecoveryExportSucceeded => '已保存一份数据副本。';

  @override
  String get startupRecoveryExportFailed => '无法导出数据副本。';

  @override
  String get startupRecoveryRepairFailed => '修复未能解决问题。请先导出数据副本，然后重置。';

  @override
  String get startupRecoveryResetFailed => '重置失败。请彻底关闭 Kelivo 后重新打开。';

  @override
  String get startupRecoveryResetDialogTitle => '重置全部数据？';

  @override
  String get startupRecoveryResetDialogContent =>
      '这将永久删除本设备上 Kelivo 的数据库并重新开始。如果之后可能还需要这些数据，请先导出一份副本。此操作无法撤销。';

  @override
  String get startupRecoveryResetDialogConfirm => '重置并重启';

  @override
  String get startupRecoveryResetDialogCancel => '取消';

  @override
  String get startupDatabaseUpdateRequiredTitle => '请更新 Kelivo 以继续';

  @override
  String get startupDatabaseUpdateRequiredContent =>
      '本设备上的聊天数据库由更新版本的 Kelivo 创建，当前版本无法打开。数据未被改动。请安装最新版 Kelivo 后重新打开。';

  @override
  String backupPageRestoreFailedMessage(String error) {
    return '恢复失败：$error';
  }

  @override
  String backupPageExportFailedMessage(String error) {
    return '导出失败：$error';
  }

  @override
  String get backupPageOK => '好的';

  @override
  String get backupPageCancel => '取消';

  @override
  String get backupPageSelectImportMode => '选择导入模式';

  @override
  String get backupPageSelectImportModeDescription =>
      '请选择恢复方式。聊天和文件开关决定本次恢复的组件。';

  @override
  String get backupPageOverwriteMode => '完全覆盖';

  @override
  String get backupPageOverwriteModeDescription => '仅替换已选组件；保留未选组件及无关本地设置';

  @override
  String get backupPageMergeMode => '合并';

  @override
  String get backupPageMergeModeDescription =>
      '保留本地数据并加入备份数据；相同会话会跳过，冲突会话会重新分配 ID。';

  @override
  String get backupPageRestore => '恢复';

  @override
  String get backupPageBackupUploaded => '已上传备份';

  @override
  String get backupPageBackup => '立即备份';

  @override
  String get backupPageExporting => '正在导出...';

  @override
  String get backupProgressCancel => '取消';

  @override
  String get backupProgressCancelled => '已取消';

  @override
  String get backupProgressPreparing => '准备中';

  @override
  String get backupProgressSnapshotting => '正在创建数据库快照';

  @override
  String get backupProgressPacking => '正在打包';

  @override
  String get backupProgressVerifying => '正在校验';

  @override
  String get backupProgressUploading => '正在上传';

  @override
  String get backupProgressDownloading => '正在下载';

  @override
  String get backupProgressExtracting => '正在解压';

  @override
  String get backupProgressValidating => '正在验证';

  @override
  String get backupProgressReadingSettings => '正在读取设置';

  @override
  String get backupProgressStaging => '正在暂存';

  @override
  String get backupProgressCommitting => '正在提交';

  @override
  String get backupProgressImportingSessions => '正在导入会话';

  @override
  String get backupProgressImportingMessages => '正在导入消息';

  @override
  String get backupProgressMaterializingFiles => '正在写入文件';

  @override
  String get backupProgressListingRemote => '正在列出远端备份';

  @override
  String get backupProgressFinalizing => '正在完成';

  @override
  String backupProgressBytes(String done, String total) {
    return '$done / $total';
  }

  @override
  String backupProgressItems(String done, String total) {
    return '$done / $total';
  }

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
  String get backupPageDeleteConfirmTitle => '确认删除';

  @override
  String backupPageDeleteConfirmContent(Object name) {
    return '确定要删除远程备份“$name”吗？此操作不可撤销。';
  }

  @override
  String get backupPageBackupManagement => '备份管理';

  @override
  String get backupPageWebDavBackup => 'WebDAV 备份';

  @override
  String get backupPageWebDavServerSettings => 'WebDAV 服务器设置';

  @override
  String get backupPageS3Backup => 'S3 备份';

  @override
  String get backupPageS3ServerSettings => 'S3 服务器设置';

  @override
  String get backupPageS3Endpoint => '端点';

  @override
  String get backupPageS3Region => '区域';

  @override
  String get backupPageS3Bucket => 'Bucket';

  @override
  String get backupPageS3AccessKeyId => '访问密钥 ID';

  @override
  String get backupPageS3SecretAccessKey => '秘密访问密钥';

  @override
  String get backupPageS3SessionToken => 'Session Token（可选）';

  @override
  String get backupPageS3Prefix => '前缀（目录）';

  @override
  String get backupPageS3PathStyle => '路径风格（Path-style）';

  @override
  String get backupPageUserAgent => 'User-Agent';

  @override
  String get backupPageUserAgentHint => '可选';

  @override
  String get backupPageSave => '保存';

  @override
  String get backupPageBackupNow => '立即备份';

  @override
  String get backupPageLocalBackup => '本地备份';

  @override
  String get backupPageImportFromCherryStudio => '从 Cherry Studio 导入';

  @override
  String backupPageCherryStudioUnsupportedBackupVersion(String version) {
    return '此备份使用 Cherry Studio 格式版本 $version，Kelivo 目前尚无法导入。请改用 Cherry Studio v1 导出备份，或等待后续版本支持 Cherry Studio v2。';
  }

  @override
  String get backupPageImportFromChatbox => '从 Chatbox 导入';

  @override
  String get backupReminderSectionTitle => '备份提醒';

  @override
  String get backupReminderEnableTitle => '定期提醒我备份';

  @override
  String get backupReminderFrequencyTitle => '提醒频率';

  @override
  String get backupReminderTimeTitle => '提醒时间';

  @override
  String get backupReminderTimeInputHint => 'HH:mm';

  @override
  String get backupReminderTimeInvalid => '请输入 00:00 到 23:59 之间的时间。';

  @override
  String get backupReminderLastBackupTitle => '上次备份';

  @override
  String get backupReminderNextReminderTitle => '下次提醒';

  @override
  String get backupReminderNever => '从未';

  @override
  String get backupReminderDisabled => '关闭';

  @override
  String get backupReminderDueNow => '现在已到期';

  @override
  String get backupReminderEveryDay => '每天';

  @override
  String get backupReminderEveryThreeDays => '每 3 天';

  @override
  String get backupReminderEveryWeek => '每周';

  @override
  String get backupReminderEveryFourteenDays => '每 14 天';

  @override
  String get backupReminderEveryMonth => '每月';

  @override
  String backupReminderCustomDays(int days) {
    return '每 $days 天';
  }

  @override
  String get backupReminderCustomOption => '自定义...';

  @override
  String get backupReminderCustomDialogTitle => '自定义频率';

  @override
  String get backupReminderCustomDialogDescription => '输入两次备份提醒之间间隔多少天。';

  @override
  String get backupReminderCustomDaysLabel => '天数';

  @override
  String get backupReminderCustomDaysInvalid => '请输入 1 到 365 之间的数字。';

  @override
  String get backupReminderSidebarTitle => '备份提醒';

  @override
  String get backupReminderSidebarSubtitle => '已经到你设定的备份周期了。';

  @override
  String get backupReminderSidebarAction => '去备份';

  @override
  String get backupReminderSnoozeTooltip => '稍后提醒';

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
  String get userMessageEditSaveOnly => '仅保存';

  @override
  String get userMessageEditUnsupportedSnackbar => '该内容不支持编辑';

  @override
  String get userMessageEditOverwriteTitle => '提示';

  @override
  String get userMessageEditOverwriteContent => '修改将覆盖输入框已有内容，是否覆盖？';

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
  String get compressContext => '压缩上下文';

  @override
  String get compressContextDesc => '总结对话并开始新聊天';

  @override
  String get clearContextDesc => '标记上下文分界点';

  @override
  String get contextManagement => '上下文管理';

  @override
  String get compressingContext => '正在压缩上下文...';

  @override
  String get compressContextFailed => '压缩上下文失败';

  @override
  String get compressContextNoMessages => '没有可压缩的消息';

  @override
  String get compressContextNoConversation => '没有可压缩的会话';

  @override
  String get compressContextNoModel => '未配置压缩模型';

  @override
  String get compressContextEmptySummary => '压缩返回了空摘要';

  @override
  String get compressContextOptionsTitle => '压缩上下文';

  @override
  String get compressContextOptionsDesc => '选择发送给压缩模型的当前聊天范围。';

  @override
  String get compressContextKeepStart => '最开始';

  @override
  String get compressContextKeepRecent => '最近';

  @override
  String get compressContextUnlimited => '无限制';

  @override
  String get compressContextMaxCharsLabel => '字符数';

  @override
  String get compressContextInvalidLimit => '请输入大于 0 的字符数';

  @override
  String get compressContextStartButton => '开始压缩';

  @override
  String get compressContextModelLabel => '压缩模型';

  @override
  String get compressContextModelUnset => '选择模型';

  @override
  String get compressContextKeepRecentMessages => '保留N条';

  @override
  String get compressContextKeepCountLabel => '保留最近条数';

  @override
  String get compressContextKeepAllMessages => '保留条数覆盖全部消息，无内容可压缩';

  @override
  String compressContextEstimatePreview(
    int summarized,
    int kept,
    int minTokens,
    int maxTokens,
    int totalTokens,
  ) {
    return '总结 $summarized 字符，原样保留 $kept 字符 → 压缩后约 $minTokens–$maxTokens tokens（原文约 $totalTokens tokens）';
  }

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
  String get messageMoreSheetSelectMessages => '选择消息';

  @override
  String get messageMoreSheetCreateBranch => '创建分支';

  @override
  String get messageMoreSheetDelete => '删除本版本';

  @override
  String get messageMoreSheetDeleteAllVersions => '删除全部版本';

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
  String get reasoningBudgetSheetXhigh => '极限推理';

  @override
  String get reasoningBudgetSheetMax => '全力推理';

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
  String get reasoningBudgetSheetXhighSubtitle => '使用最大推理深度，适合最复杂的问题';

  @override
  String get reasoningBudgetSheetCustomLabel => '自定义推理预算';

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
  String get chatMessageWidgetAttachmentUnavailable => '附件不可用';

  @override
  String chatMessageWidgetCitationsTitle(int count) {
    return '引用（共$count条）';
  }

  @override
  String get chatMessageWidgetSearchResultsTitle => '搜索结果';

  @override
  String get chatMessageWidgetCitationSourcesTitle => '引用来源';

  @override
  String get chatMessageWidgetRegenerateTooltip => '重新生成';

  @override
  String get chatMessageWidgetRegenerateConfirmTitle => '确认重新生成';

  @override
  String get chatMessageWidgetRegenerateConfirmContent =>
      '重新生成只会更新当前消息，不会删除下面的消息。确定要继续吗？';

  @override
  String get chatMessageWidgetRegenerateConfirmDeleteTrailingContent =>
      '重新生成将会删除此消息下面的所有消息，且无法撤销。确定要继续吗？';

  @override
  String get chatMessageWidgetRegenerateConfirmCancel => '取消';

  @override
  String get chatMessageWidgetRegenerateConfirmOk => '重新生成';

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
  String chatMessageWidgetWebSearch(String query) {
    return '联网检索: $query';
  }

  @override
  String get chatMessageWidgetBuiltinSearch => '模型内置搜索';

  @override
  String get chatMessageWidgetReadClipboard => '读取剪切板';

  @override
  String get chatMessageWidgetWriteClipboard => '写入剪切板';

  @override
  String get chatMessageWidgetSpeakingTitle => '正在朗读:';

  @override
  String chatMessageWidgetSpeakText(String text) {
    return '正在朗读: $text';
  }

  @override
  String get chatMessageWidgetMemoryRead => '读取记忆';

  @override
  String get chatMessageWidgetMemoryUpdate => '更新记忆';

  @override
  String get chatMessageWidgetMemorySearchProfile => '检索记忆';

  @override
  String get chatMessageWidgetMemoryEdit => '编辑记忆';

  @override
  String get chatMessageWidgetMemoryDelete => '删除记忆';

  @override
  String get chatMessageWidgetUpdateUserProfile => '更新用户画像';

  @override
  String get chatMessageWidgetChatSearch => '搜索历史对话';

  @override
  String get chatMessageWidgetCreateMemory => '创建记忆';

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
  String get chatMessageWidgetImages => '图片';

  @override
  String chatMessageWidgetCitationsCount(int count) {
    return '$count个引用';
  }

  @override
  String chatSelectionSelectedCountTitle(int count) {
    return '已选择$count条消息';
  }

  @override
  String get chatSelectionExportTxt => 'TXT';

  @override
  String get chatSelectionExportMd => 'MD';

  @override
  String get chatSelectionExportImage => '图片';

  @override
  String get chatSelectionThinkingTools => '思考工具';

  @override
  String get chatSelectionThinkingContent => '思考内容';

  @override
  String get chatSelectionDeleteSelected => '删除所选';

  @override
  String get chatSelectionSelectMessagesToDelete => '请选择要删除的消息';

  @override
  String chatSelectionDeleteSelectedConfirm(int count) {
    return '确定要删除已选择的$count个版本吗？此操作不可撤销。';
  }

  @override
  String chatSelectionDeleteSelectedAllVersionsConfirm(int count) {
    return '确定要删除已选择$count条消息的全部版本吗？此操作不可撤销。';
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
  String get displaySettingsPageEnableAssistantMarkdownTitle =>
      '助手消息 Markdown 渲染';

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
  String get messageExportThinkingContentLabel => '思考内容';

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
  String get sideDrawerMenuCopy => '复制';

  @override
  String get sideDrawerMenuMoveTo => '移动到';

  @override
  String get sideDrawerMenuDelete => '删除';

  @override
  String get sideDrawerMenuSelect => '多选';

  @override
  String sideDrawerSelectionTitle(int count) {
    return '已选 $count 项';
  }

  @override
  String get sideDrawerSelectionSelectAll => '全选';

  @override
  String get sideDrawerSelectionDeselectAll => '取消全选';

  @override
  String get sideDrawerSelectionPin => '置顶';

  @override
  String get sideDrawerSelectionUnpin => '取消置顶';

  @override
  String get sideDrawerSelectionMove => '移动';

  @override
  String get sideDrawerSelectionDelete => '删除';

  @override
  String get sideDrawerSelectionDeleteConfirmTitle => '删除话题';

  @override
  String sideDrawerSelectionDeleteConfirmContent(int count) {
    return '确定删除 $count 个话题？';
  }

  @override
  String sideDrawerDeleteSelectedSnackbar(int count) {
    return '已删除 $count 个话题';
  }

  @override
  String sideDrawerMoveSelectedSnackbar(int count) {
    return '已移动 $count 个话题';
  }

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
  String get sideDrawerSearchHint => '搜索当前助手';

  @override
  String get sideDrawerSearchAssistantsHint => '搜索助手';

  @override
  String get sideDrawerTopicSearchModeLabel => '话题模式';

  @override
  String get sideDrawerGlobalSearchModeLabel => '全局模式';

  @override
  String get sideDrawerSearchModeSwipeToTopicHint => '左/右滑搜索栏切换到话题搜索';

  @override
  String get sideDrawerSearchModeSwipeToGlobalHint => '左/右滑搜索栏切换到全局搜索';

  @override
  String get sideDrawerGlobalSearchHint => '搜索全部会话';

  @override
  String get sideDrawerGlobalSearchEmptyHint => '在标题和消息中全局搜索';

  @override
  String get sideDrawerGlobalSearchNoResults => '没有匹配的会话';

  @override
  String sideDrawerGlobalSearchResultCount(int count) {
    return '共 $count 条结果';
  }

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
  String get providerAvatarChooseBuiltInIcon => '选择内置图标';

  @override
  String get providerAvatarIconDialogTitle => '选择内置图标';

  @override
  String get providerAvatarIconSearchHint => '搜索图标';

  @override
  String get providerAvatarIconNoResults => '未找到图标';

  @override
  String get providerAvatarInputLobehubIcon => '输入 LobeHub 图标';

  @override
  String get providerAvatarChooseLobehubIcon => '输入 LobeHub 图标';

  @override
  String get providerAvatarLobehubDialogTitle => '输入 LobeHub 图标';

  @override
  String get providerAvatarLobehubDialogHint => '输入 LobeHub 图标名，如 openai';

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
  String get chatInputBarVoiceInputTooltip => '语音输入';

  @override
  String get chatInputBarVoiceCancelTooltip => '取消录音';

  @override
  String get chatInputBarVoiceStopTooltip => '停止并转为文字';

  @override
  String get chatInputBarVoiceSendTooltip => '转文字并发送';

  @override
  String get chatInputBarVoiceTranscribing => '正在识别…';

  @override
  String get chatInputBarImageProcessing => '正在处理图片';

  @override
  String get chatInputBarImageMode => '绘图模式';

  @override
  String get chatInputBarDisableImageModeTooltip => '关闭绘图模式';

  @override
  String get chatInputBarQueuedPending => '排队中';

  @override
  String get chatInputBarQueuedCancel => '取消排队';

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
  String get mcpPageStatusAuthorizationRequired => '需要授权';

  @override
  String get mcpPageStatusAuthorizing => '授权中…';

  @override
  String get mcpPageStatusDisabled => '已禁用';

  @override
  String get mcpPageOAuthRequired => '需要 OAuth 登录';

  @override
  String get mcpPageOAuthSignIn => 'OAuth 登录';

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
  String get titleModelThinkingTitle => '是否开启思考';

  @override
  String get defaultModelPageSummaryModelTitle => '摘要模型';

  @override
  String get defaultModelPageSummaryModelSubtitle => '用于生成对话摘要的模型，推荐使用快速且便宜的模型';

  @override
  String get defaultModelPageSuggestionModelTitle => '聊天建议模型';

  @override
  String get defaultModelPageSuggestionModelSubtitle =>
      '用于在助手回复后生成继续对话的建议气泡。选择模型后才会启用。';

  @override
  String get assistantEditRecentChatsSummaryFrequencyTitle => '摘要更新频率';

  @override
  String get assistantEditRecentChatsSummaryFrequencyDescription =>
      '累计达到所选条数的新消息后，会更新历史聊天摘要。';

  @override
  String assistantEditRecentChatsSummaryFrequencyOption(int count) {
    return '每 $count 条';
  }

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomButton => '自定义';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomTitle => '自定义摘要频率';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomDescription =>
      '输入累计多少条新消息后再更新历史聊天摘要。';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomLabel => '新消息条数';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomHint =>
      '请输入大于 0 的整数';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomInvalid =>
      '请输入大于 0 的整数';

  @override
  String get defaultModelPageTranslateModelTitle => '翻译模型';

  @override
  String get defaultModelPageTranslateModelSubtitle =>
      '用于翻译消息内容的模型，推荐使用快速且准确的模型';

  @override
  String get defaultModelPageOcrModelTitle => 'OCR 模型';

  @override
  String backgroundTaskFailed(String task, String error) {
    return '$task失败：$error';
  }

  @override
  String get defaultModelPageOcrModelSubtitle => '用于对图片执行文字识别的模型';

  @override
  String get defaultModelPageOcrModelRequiresImageInput =>
      '请选择标记为支持图片输入的模型用于 OCR';

  @override
  String get defaultModelPagePromptLabel => '提示词';

  @override
  String get defaultModelPageTitlePromptHint => '输入用于标题总结的提示词模板';

  @override
  String get defaultModelPageSummaryPromptHint => '输入用于生成摘要的提示词模板';

  @override
  String get defaultModelPageSuggestionPromptHint => '输入用于生成聊天建议的提示词模板';

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
  String defaultModelPageSuggestionVars(String contentVar, String localeVar) {
    return '变量：对话内容：$contentVar，语言：$localeVar';
  }

  @override
  String get defaultModelPageCompressModelTitle => '压缩模型';

  @override
  String get defaultModelPageCompressModelSubtitle => '用于压缩对话上下文的模型，推荐使用快速模型';

  @override
  String get defaultModelPageCompressPromptHint => '输入用于上下文压缩的提示词模板';

  @override
  String defaultModelPageCompressVars(String contentVar, String localeVar) {
    return '变量：对话内容：$contentVar，语言：$localeVar';
  }

  @override
  String defaultModelPageTranslateVars(String sourceVar, String targetVar) {
    return '变量：原始文本：$sourceVar，目标语言：$targetVar';
  }

  @override
  String get defaultModelPageUseCurrentModel => '使用当前对话模型';

  @override
  String get defaultModelPageNotEnabled => '未启用';

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
  String get modelDetailSheetSaveFailedMessage => '保存失败，请重试';

  @override
  String get modelDetailSheetAddBody => '添加 Body';

  @override
  String get modelDetailSheetBuiltinToolsDescription => '内置工具取决于供应商和 API 模式。';

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
  String get modelDetailSheetOpenrouterWebFetchTool => '网页抓取';

  @override
  String get modelDetailSheetOpenrouterWebFetchToolDescription =>
      '启用 OpenRouter 网页抓取服务端工具';

  @override
  String get modelDetailSheetOpenrouterShellTool => 'Shell';

  @override
  String get modelDetailSheetOpenrouterShellToolDescription =>
      '在托管的隔离沙箱中运行 Shell 命令';

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
  String get providerDetailPageCustomRequestTitle => '自定义请求';

  @override
  String get providerDetailPageCustomRequestDescription =>
      '应用于此供应商的所有模型。模型配置优先于此处，此处配置优先于助手配置。';

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
  String get providerDetailPageClaudePromptCachingTitle =>
      'Claude Prompt Caching';

  @override
  String get providerDetailPageClaudePromptCachingHelp =>
      '通过 Claude 官方或 OpenRouter 调用 Claude 时附加 cache_control。';

  @override
  String get providerDetailPageClaudePromptCachingTtlTitle => '缓存 TTL';

  @override
  String get providerDetailPageClaudePromptCachingTtlHelp =>
      '5 分钟为默认值。1 小时写入成本更高，但长对话中可减少重复重建缓存。';

  @override
  String get providerDetailPageClaudePromptCachingTtl5m => '5 分钟';

  @override
  String get providerDetailPageClaudePromptCachingTtl1h => '1 小时';

  @override
  String get providerDetailPageBalanceTitle => '账户余额';

  @override
  String get providerDetailPageBalanceInfo => '获取账户余额';

  @override
  String get providerDetailPageBalanceApiPathLabel => '余额 API 路径';

  @override
  String get providerDetailPageBalanceResultPathLabel => '结果 JSON 路径';

  @override
  String get providerDetailPageBalanceQueryButton => '查询余额';

  @override
  String get providerDetailPageBalanceQuerying => '查询中...';

  @override
  String get providerDetailPageBalanceResetDefaultsButton => '重置';

  @override
  String get providerDetailPageBalanceResetDefaultsTooltip => '重置余额设置';

  @override
  String providerDetailPageBalanceResult(String value) {
    return '余额：$value';
  }

  @override
  String providerDetailPageBalanceError(String message) {
    return '余额查询失败：$message';
  }

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
  String get providerDetailPageImportJsonReadFailedMessage => '读取文件失败';

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
  String get providersPageSearchHint => '搜索供应商或分组';

  @override
  String get providersPageProviderAddedSnackbar => '已添加供应商';

  @override
  String get providerGroupsGroupLabel => '分组';

  @override
  String get providerGroupsOther => '其他';

  @override
  String get providerGroupsOtherUngroupedOption => '其他（未分组）';

  @override
  String get providerGroupsPickerTitle => '选择分组';

  @override
  String get providerGroupsManageTitle => '分组管理';

  @override
  String get providerGroupsManageAction => '管理分组';

  @override
  String get providerGroupsCreateNewGroupAction => '新建分组…';

  @override
  String get providerGroupsCreateDialogTitle => '新建分组';

  @override
  String get providerGroupsNameHint => '输入分组名称';

  @override
  String get providerGroupsCreateDialogCancel => '取消';

  @override
  String get providerGroupsCreateDialogOk => '创建';

  @override
  String get providerGroupsCreateFailedToast => '创建分组失败';

  @override
  String get providerGroupsDeleteConfirmTitle => '删除分组';

  @override
  String get providerGroupsDeleteConfirmContent => '该组内供应商将移动到「其他」';

  @override
  String get providerGroupsDeleteConfirmCancel => '取消';

  @override
  String get providerGroupsDeleteConfirmOk => '删除';

  @override
  String get providerGroupsDeletedToast => '已删除分组';

  @override
  String get providerGroupsEmptyState => '暂无分组';

  @override
  String get providerGroupsExpandToMoveToast => '请先展开分组';

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
  String get miniMapScrollToBottomTooltip => '滚动到底部';

  @override
  String miniMapSearchMatchCount(int count) {
    return '$count 处';
  }

  @override
  String get miniMapSearchNoResults => '没有匹配的消息';

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
  String get searchServicesFieldCustomUrlOptional => '自定义 URL（可选）';

  @override
  String get searchServicesDialogApiKey => 'API Key';

  @override
  String get searchServicesDialogModel => '模型';

  @override
  String get searchServicesDialogSystemPrompt => '系统提示词';

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
  String get searchServiceEditorProviderTypeTitle => '搜索提供商';

  @override
  String get searchServiceEditorConfigurationTitle => '服务配置';

  @override
  String get searchServiceEditorNoConfiguration => '此提供商无需额外配置。';

  @override
  String get searchServiceEditorMultiKeyTitle => '多 Key 轮询';

  @override
  String get searchServiceEditorMultiKeyNone => '未配置';

  @override
  String get searchApiKeysPageDescription =>
      '列表中的 Key 按顺序轮询使用，第一个为主 Key；不查额度，以防触发服务商风控。';

  @override
  String get searchApiKeysPagePrimaryBadge => '主';

  @override
  String get searchApiKeysPageBatchHint => '可一次粘贴多个 Key：每行一个，或用逗号分隔';

  @override
  String searchApiKeysPageBatchResult(String added, String skipped) {
    return '已添加 $added 个，跳过 $skipped 个重复';
  }

  @override
  String get searchApiKeysPageAdd => '添加';

  @override
  String get searchApiKeysPageEmpty => '尚未配置任何 Key。';

  @override
  String searchServiceEditorMultiKeyCount(String count) {
    return '共 $count 个 Key';
  }

  @override
  String get searchServiceEditorUsageTitle => '账户用量';

  @override
  String get searchServiceEditorUsageNotQueried => '尚未查询用量。';

  @override
  String get searchServiceEditorUsageQuery => '查询用量';

  @override
  String get searchServiceEditorUsageQuerying => '查询中…';

  @override
  String searchServiceEditorUsageRemaining(String remaining) {
    return '剩余 $remaining 额度';
  }

  @override
  String searchServiceEditorUsageBalance(String balance) {
    return '余额 $balance';
  }

  @override
  String searchServiceEditorUsageUsed(String used, String limit) {
    return '已使用 $used / $limit 额度';
  }

  @override
  String searchServiceEditorUsageFailed(String message) {
    return '用量查询失败：$message';
  }

  @override
  String get searchServiceEditorTestTitle => '测试搜索';

  @override
  String get searchServiceEditorTestQueryHint => '输入测试关键词';

  @override
  String get searchServiceEditorTestRun => '运行测试搜索';

  @override
  String get searchServiceEditorTestRunning => '搜索中…';

  @override
  String get searchServiceEditorTestNoResults => '提供商未返回任何结果。';

  @override
  String searchServiceEditorTestFailed(String message) {
    return '搜索失败：$message';
  }

  @override
  String get searchServiceEditorResultOpenTooltip => '打开结果';

  @override
  String get searchServiceEditorDeleteTooltip => '删除搜索服务';

  @override
  String get searchServiceEditorDeleteTitle => '删除搜索服务？';

  @override
  String searchServiceEditorDeleteMessage(String provider) {
    return '确定删除 $provider 吗？此操作无法撤销。';
  }

  @override
  String get searchServiceEditorDeleteConfirm => '删除';

  @override
  String get searchServiceEditorDiscardTitle => '放弃更改？';

  @override
  String get searchServiceEditorDiscardMessage => '尚未保存的搜索服务设置将会丢失。';

  @override
  String get searchServiceEditorKeepEditing => '继续编辑';

  @override
  String get searchServiceEditorDiscard => '放弃';

  @override
  String get searchSettingsSheetTitle => '搜索设置';

  @override
  String get searchSettingsSheetBuiltinSearchTitle => '模型内置搜索';

  @override
  String get searchSettingsSheetBuiltinSearchDescription => '是否启用模型内置的搜索功能';

  @override
  String get searchSettingsSheetClaudeDynamicSearchTitle => '模型内置搜索(新)';

  @override
  String get searchSettingsSheetClaudeDynamicSearchDescription =>
      '在支持的 Claude 官方模型上使用 `web_search_20260209`，支持动态过滤能力。';

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
  String get aboutPageKelivoSearchUnlocked => '有扇没有名字的门开了一条缝。去设置里找找看。';

  @override
  String get aboutPageKelivoSearchAlreadyUnlocked => '这扇门你已经推开过了。';

  @override
  String get aboutPageAppName => 'Kelivo';

  @override
  String get aboutPageAppDescription => '开源AI 助手';

  @override
  String get aboutPageNoQQGroup => '暂无QQ群';

  @override
  String get aboutPageVersion => '版本';

  @override
  String aboutPageVersionDetail(String version, String buildNumber) {
    return '$version / $buildNumber';
  }

  @override
  String get aboutPageSystem => '系统';

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
    return '其他（$os）';
  }

  @override
  String get aboutPageWebsite => '官网';

  @override
  String get aboutPageGithub => 'GitHub';

  @override
  String get aboutPageLicense => '许可证';

  @override
  String get aboutPageJoinQQGroup => '加入QQ群';

  @override
  String get aboutPageQQGroupOne => 'Kelivo 一群';

  @override
  String get aboutPageQQGroupTwo => 'Kelivo 二群';

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
  String get displaySettingsPageShowUserNameTitle => '显示用户名称';

  @override
  String get displaySettingsPageShowUserTimestampTitle => '显示用户时间戳';

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
  String get displaySettingsPageShowModelNameTitle => '显示模型名称';

  @override
  String get displaySettingsPageShowModelTimestampTitle => '显示模型时间戳';

  @override
  String get displaySettingsPageShowProviderInChatMessageTitle => '模型名称后显示供应商';

  @override
  String get displaySettingsPageShowProviderInChatMessageSubtitle =>
      '在聊天消息的模型名称后面显示供应商名称（如 模型 | 供应商）';

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
  String get displaySettingsPageCollapseThinkingStepsTitle => '折叠思考步骤';

  @override
  String get displaySettingsPageCollapseThinkingStepsSubtitle =>
      '默认只显示最新步骤，展开后查看全部';

  @override
  String get displaySettingsPageShowToolResultSummaryTitle => '显示工具结果摘要';

  @override
  String get displaySettingsPageInsertSuggestionOnlyTitle => '点击建议时仅填入输入框';

  @override
  String get displaySettingsPageShowToolResultSummarySubtitle =>
      '在工具步骤下方显示摘要文本';

  @override
  String get displaySettingsPageRegenerateDeleteTrailingMessagesTitle =>
      '重新生成时删除下面的消息';

  @override
  String get displaySettingsPageShowRegenerateConfirmDialogTitle => '重新生成前弹出确认';

  @override
  String get displaySettingsPageForkKeepMessageVersionsTitle => '创建分支时保留消息版本';

  @override
  String chainOfThoughtExpandSteps(Object count) {
    return '展开更多 $count 步';
  }

  @override
  String get chainOfThoughtCollapse => '收起';

  @override
  String get displaySettingsPageShowChatListDateTitle => '显示对话列表日期';

  @override
  String get displaySettingsPageShowChatListDateSubtitle => '在左侧对话列表中显示日期分组标签';

  @override
  String get displaySettingsPageEnableImageCropperTitle => '启用图片裁剪';

  @override
  String get displaySettingsPageEnableImageCropperSubtitle =>
      '从相册或相机选择图片后，允许裁剪图片';

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
  String get displaySettingsPageKeepScreenOnDuringGenerationTitle =>
      '生成时保持屏幕常亮';

  @override
  String get displaySettingsPageKeepScreenOnDuringGenerationSubtitle =>
      '防止生成中途锁屏导致中断，会增加耗电';

  @override
  String get displaySettingsPageMessageNavButtonsTitle => '消息导航按钮';

  @override
  String get displaySettingsPageMessageNavButtonsSubtitle => '选择快速跳转按钮的显示时机';

  @override
  String get displaySettingsPageMessageNavButtonsModeAlways => '始终显示';

  @override
  String get displaySettingsPageMessageNavButtonsModeScroll => '滚动时显示';

  @override
  String get displaySettingsPageMessageNavButtonsModeHover => '鼠标悬停时显示';

  @override
  String get displaySettingsPageMessageNavButtonsModeScrollAndHover =>
      '滚动和鼠标悬停时显示';

  @override
  String get displaySettingsPageMessageNavButtonsModeNever => '永不显示';

  @override
  String get displaySettingsPageUseNewAssistantAvatarUxTitle => '聊天标题栏显示助手头像';

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
  String get displaySettingsPageEnterToSendTitle => '回车键发送消息';

  @override
  String get displaySettingsPageLongPasteAsFileTitle => '超长粘贴转为文件';

  @override
  String get displaySettingsPageLongPasteAsFileThresholdTitle => '转换阈值';

  @override
  String get displaySettingsPageLongPasteAsFileThresholdUnit => '字符';

  @override
  String get displaySettingsPageSendShortcutTitle => '发送快捷键';

  @override
  String get displaySettingsPageSendShortcutEnter => 'Enter';

  @override
  String get displaySettingsPageSendShortcutCtrlEnter => 'Ctrl/Cmd + Enter';

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
  String get displaySettingsPageChatInputBackgroundOpacityTitle => '输入框背景透明度';

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
  String get themeSettingsPageCustomPaletteName => '自定义';

  @override
  String get themeSettingsPageCustomColorReset => '重置';

  @override
  String get themeSettingsPageCustomThemesSection => '自定义主题';

  @override
  String get customThemeNewTheme => '新建主题';

  @override
  String get customThemeEditTheme => '编辑主题';

  @override
  String get customThemeImportTheme => '导入主题';

  @override
  String get customThemeNameLabel => '主题名称';

  @override
  String get customThemePrimaryColor => '主色';

  @override
  String get customThemeSecondaryColor => '辅色';

  @override
  String get customThemeTertiaryColor => '第三色';

  @override
  String get customThemeColorAuto => '自动';

  @override
  String get customThemeSave => '保存';

  @override
  String get customThemeCancel => '取消';

  @override
  String get customThemeDelete => '删除';

  @override
  String get customThemeDeleteConfirm => '删除该主题？';

  @override
  String get customThemeCopied => '主题 JSON 已复制到剪贴板';

  @override
  String get customThemeCopyAction => '复制';

  @override
  String get customThemeImportHint => '在此粘贴主题 JSON';

  @override
  String get customThemeImportInvalid => '无效的主题 JSON';

  @override
  String get customThemeHexLabel => '十六进制';

  @override
  String get ttsServicesPageBackButton => '返回';

  @override
  String get ttsServicesPageTitle => '语音服务';

  @override
  String get ttsServicesSectionTitle => '文字转语音';

  @override
  String get ttsServicesPageSettingsTooltip => 'TTS 设置';

  @override
  String get ttsServicesPageAddTooltip => '新增';

  @override
  String get asrServicesSectionTitle => '语音识别';

  @override
  String get asrServicesSectionDescription => '使用本地、系统或云端服务将语音转换为文字。';

  @override
  String get asrServicesAddTooltip => '添加语音识别服务';

  @override
  String get asrServicesEmptyTitle => '尚未添加语音识别服务';

  @override
  String get asrServicesEmptySubtitle => '添加后，聊天输入框才会显示麦克风。';

  @override
  String get asrServicesOnDeviceGroup => '设备端';

  @override
  String get asrServicesCloudGroup => '云端';

  @override
  String get asrServicesSystemTitle => '系统';

  @override
  String get asrServicesSystemSubtitle => '使用设备内置能力';

  @override
  String get asrServicesLocalTitle => '本地模型';

  @override
  String get asrServicesLocalSubtitle => '下载后在设备上离线运行';

  @override
  String get asrServicesOpenAiTitle => 'OpenAI Realtime';

  @override
  String get asrServicesOpenAiSubtitle => '低延迟流式转写';

  @override
  String get asrServicesDashScopeTitle => 'DashScope';

  @override
  String get asrServicesDashScopeSubtitle => 'Qwen 实时转写';

  @override
  String get asrServicesVolcengineTitle => '火山引擎';

  @override
  String get asrServicesVolcengineSubtitle => '豆包语音流式转写';

  @override
  String get asrServicesMimoTitle => 'MiMo';

  @override
  String get asrServicesMimoSubtitle => '分段云端转写';

  @override
  String get asrServicesStepTitle => 'Step';

  @override
  String get asrServicesStepSubtitle => 'Step Audio 分段云端转写';

  @override
  String get asrServicesAddTitle => '添加语音识别';

  @override
  String get asrServicesEditTitle => '编辑语音识别';

  @override
  String get asrServicesSelectedLabel => '已选择';

  @override
  String get asrServicesUnavailableLabel => '不可用';

  @override
  String get asrServicesEditAction => '编辑';

  @override
  String get asrServicesDeleteAction => '删除';

  @override
  String get asrServicesCancelAction => '取消';

  @override
  String get asrServicesAddAction => '添加';

  @override
  String get asrServicesSaveAction => '保存';

  @override
  String get asrServicesNameLabel => '名称';

  @override
  String get asrServicesApiKeyLabel => 'API Key';

  @override
  String get asrServicesEndpointLabel => '服务地址';

  @override
  String get asrServicesModelLabel => '模型';

  @override
  String get asrServicesResourceIdLabel => '资源 ID';

  @override
  String get asrServicesLanguageLabel => '语言';

  @override
  String get asrServicesAutomaticLabel => '自动';

  @override
  String get asrServicesApiKeyRequired => '请输入 API Key 后再使用此服务。';

  @override
  String get asrServicesChooseModelTitle => '模型';

  @override
  String get asrServicesModelDownloadAction => '下载';

  @override
  String get asrServicesModelUseAction => '使用此模型';

  @override
  String get asrServicesModelDeleteAction => '删除下载';

  @override
  String get asrServicesModelDownloadedLabel => '已下载';

  @override
  String get asrServicesModelDownloadingLabel => '正在下载…';

  @override
  String get asrServicesModelNotDownloadedLabel => '未下载';

  @override
  String asrServicesDownloadFailed(String error) {
    return '模型下载失败：$error';
  }

  @override
  String get asrServicesSystemChecking => '正在检查…';

  @override
  String get asrServicesSystemAvailable => '可用';

  @override
  String get asrServicesSystemCheckFailed => '这台设备没有可用的系统语音识别服务。';

  @override
  String get asrServicesMicrophonePermissionDenied => '未获得麦克风权限。';

  @override
  String get asrServicesNoSpeechDetected => '没有识别到语音。';

  @override
  String asrServicesRecognitionFailed(String error) {
    return '语音识别失败：$error';
  }

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
  String get ttsServicesFieldLanguageTypeLabel => '语言类型';

  @override
  String get ttsServicesFieldLanguageLabel => '语言';

  @override
  String get ttsServicesFieldWorkspaceIdLabel => '业务空间 ID';

  @override
  String get ttsServicesFieldRegionLabel => '地域';

  @override
  String get ttsServicesFieldFormatLabel => '音频格式';

  @override
  String get ttsServicesFieldOutputFormatLabel => '输出格式';

  @override
  String get ttsServicesFieldSampleRateLabel => '采样率';

  @override
  String get ttsServicesFieldVolumeLabel => '音量';

  @override
  String get ttsServicesFieldPitchLabel => '音调';

  @override
  String get ttsServicesFieldLanguageBoostLabel => '语言增强';

  @override
  String get ttsServicesFieldBitrateLabel => '比特率';

  @override
  String get ttsServicesFieldChannelLabel => '声道数';

  @override
  String get ttsServicesFieldSubtitlesLabel => '生成字幕';

  @override
  String get ttsServicesFieldPronunciationDictionaryLabel => '发音词典（每行一项）';

  @override
  String get ttsServicesFieldInstructionLabel => '风格／音色描述';

  @override
  String get ttsServicesFieldStreamingLabel => '流式输出';

  @override
  String get ttsServicesFieldOptimizeTextPreviewLabel => '优化播报文本';

  @override
  String get ttsServicesFieldReferenceAudioLabel => '参考音频（WAV/MP3 数据 URI）';

  @override
  String get ttsServicesFieldChooseReferenceAudioButton => '选择参考音频';

  @override
  String get ttsServicesFieldTemperatureLabel => '随机度';

  @override
  String get ttsServicesFieldTopPLabel => 'Top P';

  @override
  String get ttsServicesFieldLatencyLabel => '延迟模式';

  @override
  String get ttsServicesEmotionAutoLabel => '自动匹配';

  @override
  String get ttsServicesValidationApiKeyRequired => 'API Key 不能为空';

  @override
  String get ttsServicesValidationReferenceIdRequired => '音色／参考 ID 不能为空';

  @override
  String get ttsServicesValidationInstructionRequired => '音色描述不能为空';

  @override
  String ttsServicesValidationSampleRate(String format, String rates) {
    return '$format 格式要求使用 $rates Hz。';
  }

  @override
  String get ttsServicesViewDetailsButton => '查看详情';

  @override
  String get ttsServicesDialogErrorTitle => '错误详情';

  @override
  String get ttsServicesCloseButton => '关闭';

  @override
  String get ttsSettingsPageTitle => 'TTS 设置';

  @override
  String get ttsSettingsPlaybackSection => '播放';

  @override
  String get ttsSettingsAutoPlayTitle => '自动播放助手回复';

  @override
  String get ttsSettingsAutoPlayDescription => '助手回复生成完成后自动开始 TTS 播放。';

  @override
  String get ttsSettingsCacheReplayTitle => '使用缓存复播';

  @override
  String get ttsSettingsCacheReplayDescription => '重新播放网络语音时使用已生成的音频，不再请求语音服务。';

  @override
  String get ttsSettingsTextSelectionSection => '文本选择';

  @override
  String get ttsSettingsTextSelectionFallbackDescription => '没有匹配内容时将播放完整回复。';

  @override
  String get ttsSettingsTextSelectionFullTextTitle => '全文';

  @override
  String get ttsSettingsTextSelectionFullTextDescription => '播放完整助手回复。';

  @override
  String get ttsSettingsTextSelectionQuotedOnlyTitle => '仅引号内文字';

  @override
  String get ttsSettingsTextSelectionQuotedOnlyDescription =>
      '播放 “”、‘’、\"\"、\'\'、「」或『』内的文字。';

  @override
  String get ttsSettingsTextSelectionOutsideParenthesesTitle => '括号外文字';

  @override
  String get ttsSettingsTextSelectionOutsideParenthesesDescription =>
      '跳过 () 和 （） 内的文字。';

  @override
  String get ttsSettingsTextSelectionItalicOnlyTitle => '仅斜体文字';

  @override
  String get ttsSettingsTextSelectionItalicOnlyDescription =>
      '播放 Markdown 或 HTML 斜体文字。';

  @override
  String get ttsSettingsTextSelectionNonItalicTitle => '仅正体文字';

  @override
  String get ttsSettingsTextSelectionNonItalicDescription =>
      '跳过 Markdown 或 HTML 斜体文字。';

  @override
  String get ttsFloatingPlayerLabel => '语音播放器';

  @override
  String get ttsFloatingPauseTooltip => '暂停';

  @override
  String get ttsFloatingResumeTooltip => '继续播放';

  @override
  String get ttsFloatingReplayTooltip => '重新播放';

  @override
  String get ttsFloatingRewind15Tooltip => '后退 15 秒';

  @override
  String get ttsFloatingForward15Tooltip => '前进 15 秒';

  @override
  String get ttsFloatingSpeedTooltip => '播放倍速';

  @override
  String get ttsFloatingCloseTooltip => '关闭播放器';

  @override
  String get ttsFloatingExpandTooltip => '展开播放控制';

  @override
  String get ttsFloatingCollapseTooltip => '收起播放控制';

  @override
  String get ttsFloatingSaveTooltip => '保存音频';

  @override
  String get ttsSaveDialogTitle => '保存 TTS 音频';

  @override
  String get ttsSaveSuccess => '音频已保存';

  @override
  String get ttsSaveNothing => '暂无可保存的音频';

  @override
  String ttsSaveFailed(String message) {
    return '保存音频失败：$message';
  }

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
  String get imageViewerPageCloseButton => '关闭预览';

  @override
  String get imageViewerPageSaveButton => '保存图片';

  @override
  String get imageViewerPageCopyButton => '复制图片';

  @override
  String get imageViewerPagePreviousButton => '上一张图片';

  @override
  String get imageViewerPageNextButton => '下一张图片';

  @override
  String get imageViewerPageZoomInButton => '放大';

  @override
  String get imageViewerPageZoomOutButton => '缩小';

  @override
  String get imageViewerPageResetZoomButton => '重置缩放';

  @override
  String get imageViewerPageFlipHorizontalButton => '左右镜像';

  @override
  String get imageViewerPageFlipVerticalButton => '上下镜像';

  @override
  String get imageViewerPageRotateLeftButton => '向左旋转';

  @override
  String get imageViewerPageRotateRightButton => '向右旋转';

  @override
  String imageViewerPageCounter(int index, int total) {
    return '$index/$total';
  }

  @override
  String imageViewerPageImageLabel(int index, int total) {
    return '第 $index 张图片，共 $total 张';
  }

  @override
  String get imageViewerPageImageLoadFailed => '无法加载图片';

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
  String get searchServiceNameDoubao => '豆包';

  @override
  String get searchProviderDoubaoDescription => '火山引擎豆包网页搜索 API。';

  @override
  String get searchServiceNameSerper => 'Serper';

  @override
  String get searchProviderSerperDescription =>
      'Serper Google 搜索 API。响应快速，支持国家/地区、语言、时间和页码过滤。';

  @override
  String get searchServiceNameQuerit => 'Querit';

  @override
  String get searchProviderQueritDescription =>
      '面向 LLM 应用的 Querit 搜索 API。返回实时网页结果，并支持站点、时间、国家和语言过滤。';

  @override
  String get searchServiceNameGrok => 'Grok';

  @override
  String get searchProviderGrokDescription =>
      '通过 xAI Responses API 使用 Grok 搜索。调用网页和 X 搜索工具，并返回带引用的来源。';

  @override
  String get searchServiceNameStepFun => 'StepFun';

  @override
  String get searchProviderStepFunDescription =>
      '通过 StepFun POST /v1/search 进行网页搜索。';

  @override
  String get searchServiceNameFirecrawl => 'Firecrawl';

  @override
  String get searchProviderFirecrawlDescription =>
      'Firecrawl Search API v2。API Key 可选。此处不支持 Scrape。';

  @override
  String get searchServiceNameTinyFish => 'TinyFish';

  @override
  String get searchProviderTinyFishDescription =>
      'TinyFish Search API，支持地区与语言参数。需要 API Key。此处不支持 Fetch/Scrape。';

  @override
  String get searchServiceNameKelivo => 'Kelivo';

  @override
  String get searchServicesDialogCountryOptional => '国家/地区（可选）';

  @override
  String get searchServicesDialogLanguageOptional => '语言（可选）';

  @override
  String get searchServicesDialogTimeFilterOptional => '时间过滤（可选）';

  @override
  String get searchServicesDialogPageOptional => '页码（可选）';

  @override
  String get searchServicesDialogPageInvalid => '页码必须是正整数。';

  @override
  String get searchServicesDialogSitesIncludeOptional => '包含站点（可选）';

  @override
  String get searchServicesDialogSitesExcludeOptional => '排除站点（可选）';

  @override
  String get searchServicesDialogTimeRangeOptional => '时间范围（可选）';

  @override
  String get searchServicesDialogCountriesOptional => '国家（可选）';

  @override
  String get searchServicesDialogLanguagesOptional => '语言（可选）';

  @override
  String get searchServicesDialogSitesHint => 'example.com, docs.example.com';

  @override
  String get searchServicesDialogTimeRangeHint => 'd7';

  @override
  String get searchServicesDialogCountriesHint => 'united states, japan';

  @override
  String get searchServicesDialogLanguagesHint => 'english, japanese';

  @override
  String get generationInterrupted => '生成已中断';

  @override
  String get titleForLocale => '新对话';

  @override
  String get temporaryChatTitle => '临时对话';

  @override
  String get temporaryChatEmptyMessage => '临时对话不显示在历史记录，退出后将被完全删除';

  @override
  String get temporaryChatToggleTooltip => '切换临时对话';

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
  String get instructionInjectionUngroupedGroup => '未分组';

  @override
  String get instructionInjectionGroupLabel => '分组';

  @override
  String get instructionInjectionGroupHint => '可选';

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
  String get assistantEditLocalToolTimeInfoTitle => '时间信息';

  @override
  String get assistantEditLocalToolTimeInfoSubtitle =>
      '读取设备日期、星期、时间、时区、UTC 偏移和时间戳。';

  @override
  String get assistantEditLocalToolClipboardTitle => '剪切板';

  @override
  String get assistantEditLocalToolClipboardSubtitle =>
      '在明确需要时读取或写入设备剪切板中的纯文本。';

  @override
  String get assistantEditLocalToolTextToSpeechTitle => '文字转语音';

  @override
  String get assistantEditLocalToolTextToSpeechSubtitle =>
      '允许助手使用已配置的语音播放朗读文本。';

  @override
  String get assistantEditLocalToolAskUserTitle => '询问用户';

  @override
  String get assistantEditLocalToolAskUserSubtitle => '允许助手提出简短问题，并在你回答后继续生成。';

  @override
  String get assistantEditLocalToolCalculateTitle => '计算器';

  @override
  String get assistantEditLocalToolCalculateSubtitle =>
      '计算数学表达式，支持加减乘除幂运算 sqrt sin cos 等。';

  @override
  String get assistantEditLocalToolScreenTimeTitle => '屏幕使用时间';

  @override
  String get assistantEditLocalToolScreenTimeSubtitle =>
      '查询本设备的应用使用时长，需要授予使用情况访问权限。';

  @override
  String get chatMessageWidgetScreenTimeTotal => '总屏幕时间';

  @override
  String get chatMessageWidgetScreenTimePermissionRequired =>
      '未授予使用情况访问权限，请在系统设置中开启后重试。';

  @override
  String get assistantEditLocalToolCalendarQueryTitle => '查询日历';

  @override
  String get assistantEditLocalToolCalendarQuerySubtitle =>
      '读取本设备上的日历日程，需要授予日历权限。';

  @override
  String get assistantEditLocalToolCalendarCreateTitle => '创建日程';

  @override
  String get assistantEditLocalToolCalendarCreateSubtitle =>
      '在你确认后于本设备创建日历日程，需要授予日历权限。';

  @override
  String get assistantEditMemorySwitchDescription => '允许助手主动存储并在对话间引用用户相关信息';

  @override
  String get assistantEditRecentChatsSwitchTitle => '参考历史聊天记录';

  @override
  String get assistantEditRecentChatsSwitchDescription =>
      '在新对话中引用最近的对话标题以增强上下文';

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
  String get networkProxyBypassLabel => '代理绕过';

  @override
  String get networkProxyBypassHint =>
      '用逗号分隔的主机或 CIDR，例如：localhost,127.0.0.1,192.168.0.0/16,*.local';

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
  String get providerDetailPageMultiSelectButton => '多选';

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
  String get providerDetailPageDeleteSelectedModelsButton => '删除';

  @override
  String get providerDetailPageDeleteSelectedModelsTooltip => '删除所选模型';

  @override
  String providerDetailPageDeleteSelectedModelsConfirm(int count) {
    return '确定删除选中的 $count 个模型吗？此操作不可撤回。';
  }

  @override
  String get providerDetailPageDeleteFailedDetectedModelsButton => '删除不可用';

  @override
  String get providerDetailPageDeleteFailedDetectedModelsTooltip => '删除检测失败的模型';

  @override
  String providerDetailPageDeleteFailedDetectedModelsConfirm(int count) {
    return '确定删除检测失败的 $count 个模型吗？此操作不可撤回。';
  }

  @override
  String providerDetailPageSelectedModelsDeletedSnackbar(int count) {
    return '已删除 $count 个模型';
  }

  @override
  String get providerDetailPageDeleteAllModelsTooltip => '删除全部模型';

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
  String get contextLogSettingTitle => '上下文日志';

  @override
  String get contextLogSettingSubtitle =>
      '开启后会将每次实际发送给模型的完整上下文写入 logs/context_logs.txt';

  @override
  String get contextLogViewerTitle => '上下文';

  @override
  String contextLogSnapshotMessages(int count) {
    return '$count 条消息';
  }

  @override
  String contextLogSnapshotTokens(int count) {
    return '$count tokens';
  }

  @override
  String get contextLogSourceSystemPrompt => '系统提示词';

  @override
  String get contextLogSourceMemoryRules => '记忆规则';

  @override
  String get contextLogSourceSearchPrompt => '搜索提示';

  @override
  String get contextLogSourceInstructionInjection => '指令注入';

  @override
  String get contextLogSourceWorldBook => '世界书';

  @override
  String get contextLogSourceMemorySnapshot => '记忆快照';

  @override
  String get contextLogSourceChatHistory => '聊天历史';

  @override
  String get contextLogSourceToolCall => '工具调用';

  @override
  String get contextLogSourceToolResult => '工具结果';

  @override
  String get contextLogTokensEstimateHint => 'tokens 仅为预估值，请以模型实际消耗为准。';

  @override
  String contextLogSnapshotsCount(int count) {
    return '$count 条快照';
  }

  @override
  String get contextLogSnapshotFallbackTitle => '快照';

  @override
  String get contextLogKindFull => '全量快照';

  @override
  String get contextLogKindUpdate => '增量更新';

  @override
  String get contextLogSectionComposition => '构成';

  @override
  String get contextLogLoadOlder => '加载更早的日志';

  @override
  String get contextLogLoading => '加载中…';

  @override
  String get contextLogAllLoaded => '已加载全部日志';

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
  String logViewerRequestsCount(int count) {
    return '$count 条请求';
  }

  @override
  String get logViewerFieldId => 'ID';

  @override
  String get logViewerFieldMethod => '方法';

  @override
  String get logViewerFieldStatus => '状态';

  @override
  String get logViewerFieldStarted => '开始';

  @override
  String get logViewerFieldEnded => '结束';

  @override
  String get logViewerFieldDuration => '耗时';

  @override
  String get logViewerSectionSummary => '概览';

  @override
  String get logViewerSectionParameters => '参数';

  @override
  String get logViewerSectionRequestHeaders => '请求头';

  @override
  String get logViewerSectionRequestBody => '请求体';

  @override
  String get logViewerSectionResponseHeaders => '响应头';

  @override
  String get logViewerSectionResponseBody => '响应体';

  @override
  String get logViewerSectionWarnings => '警告';

  @override
  String get logViewerErrorTitle => '错误';

  @override
  String logViewerMoreCount(int count) {
    return '+$count 条更多';
  }

  @override
  String get logViewerSectionAttachments => '附件';

  @override
  String get logViewerPayloadOmitted => '已省略';

  @override
  String get logViewerShowMore => '显示更多';

  @override
  String get logSettingsTitle => '日志设置';

  @override
  String get logSettingsSaveOutput => '保存响应输出';

  @override
  String get logSettingsSaveOutputSubtitle =>
      '记录流式输出的每个分片（可能影响生成性能）。HTTP 报错响应仍会写入。';

  @override
  String get logSettingsElidePayloads => '省略大载荷';

  @override
  String get logSettingsElidePayloadsSubtitle =>
      '把内联的 base64 图片和文件替换成占位符，日志更小、查看器更快。';

  @override
  String get logSettingsAutoDelete => '自动删除';

  @override
  String get logSettingsAutoDeleteSubtitle => '删除超过指定天数的日志';

  @override
  String get logSettingsAutoDeleteDisabled => '不启用';

  @override
  String logSettingsAutoDeleteDays(int count) {
    return '$count 天';
  }

  @override
  String get logSettingsMaxSize => '日志大小上限';

  @override
  String get logSettingsMaxSizeSubtitle => '超出后将删除最早的日志';

  @override
  String get logSettingsMaxSizeUnlimited => '不限制';

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

  @override
  String get homePageProcessingFiles => '正在解析文件……';

  @override
  String get settingsPageWorldBook => '世界书';

  @override
  String get settingsPageMemory => '记忆';

  @override
  String get memorySettingsPageTitle => '记忆';

  @override
  String get memorySettingsGlobalSubtitle => '记忆模式、模型与提示词';

  @override
  String get memorySettingsModeSection => '记忆模式';

  @override
  String get memorySettingsModelSection => '记忆模型';

  @override
  String get memorySettingsModelTitle => '处理模型';

  @override
  String get memorySettingsModelUnset => '未选择';

  @override
  String get memorySettingsModelTip => '开启「自动整理记忆」后，后台会频繁调用此模型，建议选择便宜且速度快的模型。';

  @override
  String get memorySettingsAboutTitle => '记忆说明';

  @override
  String get memorySettingsAboutSubtitle => '了解记忆如何运作与触发';

  @override
  String get memoryAboutQuickstartTitle => '三步上手';

  @override
  String get memoryAboutQuickstartBody =>
      '① 在「设置 → 记忆」里选择处理模型。\n② 在助手的「记忆」页打开长期记忆和自动整理。\n③ 聊几轮，或点「整理记忆」，再到「全部记忆」查看结果。';

  @override
  String get memoryAboutTypesTitle => '记忆类型';

  @override
  String get memoryAboutTypesBody =>
      '身份：用户的稳定信息，例如称呼、职业、语言、长期偏好。写成完整的第三人称陈述。\n\n工作流：用户习惯怎么做事，例如工具、格式、审阅方式。\n\n语气：用户希望助手怎么说话，例如语气、篇幅、语言风格。\n\n指令：助手应长期遵守的规则，而不是本次对话里的一次性任务。';

  @override
  String get memoryAboutScopeTitle => '全局与助手范围';

  @override
  String get memoryAboutScopeBody =>
      '全局记忆会对所有助手注入。助手范围的记忆只对该助手可见。跨助手都该知道的事实用全局；只属于某一个助手的规则或上下文用助手范围。';

  @override
  String get memoryAboutInjectionTitle => '记忆如何注入';

  @override
  String get memoryAboutInjectionBody =>
      '开对话时，每类会把最近的若干条放进模型上下文。某类超过注入上限时，块会标上 mode=\"summary\"，并用 total / shown 标明总数与展示条数，其余由模型用 memory_search_profile 按需查询。可在「设置 → 记忆」调大上限，更全面但更费 token。';

  @override
  String get memoryAboutPipelineTitle => '后台整理';

  @override
  String get memoryAboutPipelineBody =>
      '开启自动整理后，对话结束会走：判断是否值得记 → 提取候选 → 去重合并 → 必要时把身份类记忆提炼进用户画像。也可以在助手「记忆」页点「整理记忆」。因此处理模型会被较频繁调用。';

  @override
  String get memoryAboutCacheTitle => '保持缓存良好';

  @override
  String get memoryAboutCacheBody =>
      '注入前缀会保持稳定，未改动时可复用 Prompt 缓存，从而降低费用与延迟。避免无意义的大批量改动或重排。日常增删改单条通常影响有限。';

  @override
  String get memoryAboutFaqTitle => '常见问题';

  @override
  String get memoryAboutFaqWhyNotRememberedTitle => '为什么没记住？';

  @override
  String get memoryAboutFaqWhyNotRememberedBody =>
      '整理会被跳过，常见原因包括：新消息不足，暂不整理；没有新消息需要整理；尚未选择记忆处理模型。临时对话不会写入记忆。也可以按助手关闭记忆或自动整理。';

  @override
  String get memorySettingsThinkingTitle => '启用思考';

  @override
  String get memorySettingsThinkingSubtitle => '在模型支持时允许记忆模型使用推理';

  @override
  String get memorySettingsInjectionSection => '记忆注入';

  @override
  String get memorySettingsInjectionMaxItemsTitle => '每类注入条数';

  @override
  String get memorySettingsInjectionMaxItemsSubtitle =>
      '某一类型的记忆超过该条数时，只注入最近的若干条，其余由模型用 memory_search_profile 按需查询。调大更全面但更费 token。若你改过规则提示词，请一并更新或恢复默认。';

  @override
  String memorySettingsInjectionMaxItemsOption(int n) {
    return '$n';
  }

  @override
  String get memorySettingsInjectionMaxItemsCustomButton => '自定义';

  @override
  String get memorySettingsInjectionMaxItemsCustomTitle => '自定义注入条数';

  @override
  String get memorySettingsInjectionMaxItemsCustomDescription =>
      '请输入 1 到 100 之间的整数。';

  @override
  String get memorySettingsInjectionMaxItemsCustomLabel => '条数';

  @override
  String get memorySettingsInjectionMaxItemsCustomHint => '1–100';

  @override
  String get memorySettingsInjectionMaxItemsCustomInvalid =>
      '请输入 1 到 100 之间的整数';

  @override
  String get memorySettingsPromptLangSection => '提示词语言';

  @override
  String get memorySettingsPromptLangAuto => '自动';

  @override
  String get memorySettingsPromptLangAutoSubtitle => '跟随界面语言（中文用 zh，否则用 en）';

  @override
  String get memorySettingsPromptLangZh => '中文';

  @override
  String get memorySettingsPromptLangZhSubtitle => '始终使用中文记忆提示词与工具描述';

  @override
  String get memorySettingsPromptLangEn => 'English';

  @override
  String get memorySettingsPromptLangEnSubtitle => '始终使用英文记忆提示词与工具描述';

  @override
  String get memorySettingsPromptsSection => '提示词模板';

  @override
  String get memorySettingsLegacyPromptTitle => '旧版记忆规则';

  @override
  String get memoryPromptEditRulesTitle => '记忆规则';

  @override
  String get memoryPromptEditRulesSubtitle => '注入到主对话的系统提示中';

  @override
  String get memoryPromptEditGateTitle => 'Gatekeeper';

  @override
  String get memoryPromptEditGateSubtitle => '判断这一轮是否值得记忆';

  @override
  String get memoryPromptEditExtractTitle => 'Extract';

  @override
  String get memoryPromptEditExtractSubtitle => '从对话中提取候选记忆条目';

  @override
  String get memoryPromptEditSmartAddTitle => 'Smart Add';

  @override
  String get memoryPromptEditSmartAddSubtitle =>
      'NEW / MERGE / CONFLICT / SKIP 去重判定';

  @override
  String get memoryPromptEditDistillTitle => 'Profile Distiller';

  @override
  String get memoryPromptEditDistillSubtitle => '从身份类记忆提炼画像字段';

  @override
  String get memoryPromptEditMigrateTitle => '旧版记忆迁移';

  @override
  String get memoryPromptEditMigrateSubtitle => '选择「模型整理」时用于改写记忆原文';

  @override
  String get memoryPromptEditReset => '恢复默认';

  @override
  String get memoryPromptEditSave => '保存';

  @override
  String get memoryPromptEditSectionPerItem => '逐条提示词';

  @override
  String get memoryPromptEditSectionBatch => '合并提示词';

  @override
  String get memorySettingsEntriesSection => '全部记忆';

  @override
  String get memorySettingsLegacySection => '旧版记忆';

  @override
  String get memorySettingsEntriesTitle => '记忆列表';

  @override
  String get memorySettingsEntriesSubtitle => '浏览、编辑、归档与删除记忆';

  @override
  String get memorySettingsProfileTitle => '用户画像';

  @override
  String get memorySettingsProfileSubtitle => '供模型使用的结构化身份字段';

  @override
  String get memorySettingsLegacyTitle => '旧版记忆（只读）';

  @override
  String get memorySettingsLegacySubtitle => '来自旧版本的记忆';

  @override
  String get memoryEntryTypeIdentity => '身份';

  @override
  String get memoryEntryTypeWorkflow => '工作流';

  @override
  String get memoryEntryTypeVoice => '语气';

  @override
  String get memoryEntryTypeInstruction => '指令';

  @override
  String get memoryEntryScopeGlobal => '全局';

  @override
  String get memoryEntryScopeAssistant => '仅本助手';

  @override
  String memoryEntryScopeAssistantNamed(String name) {
    return '$name';
  }

  @override
  String get memoryEntrySourceManual => '手动';

  @override
  String get memoryEntrySourceTool => '工具';

  @override
  String get memoryEntrySourceExtracted => '提取';

  @override
  String get memoryEntrySourceDistilled => '蒸馏';

  @override
  String get memoryEntryStatusActive => '活跃';

  @override
  String get memoryEntryStatusArchived => '已归档';

  @override
  String memoryEntryUpdatedAt(String date) {
    return '更新于 $date';
  }

  @override
  String get memoryEntryActionEdit => '编辑';

  @override
  String get memoryEntryActionDelete => '删除';

  @override
  String get memoryEntryActionArchive => '归档';

  @override
  String get memoryEntryActionRestore => '恢复';

  @override
  String get memoryEntryActionSwitchScope => '切换范围';

  @override
  String get memoryEntryActionBatchDelete => '删除所选';

  @override
  String get memoryEntryActionAdd => '添加记忆';

  @override
  String get memoryEntryDeleteConfirmTitle => '删除这条记忆？';

  @override
  String get memoryEntryDeleteConfirmContent => '将永久删除该记忆，且无法撤销。';

  @override
  String memoryEntryBatchDeleteConfirmTitle(int count) {
    return '删除 $count 条记忆？';
  }

  @override
  String get memoryEntryBatchDeleteConfirmContent => '所选记忆将被永久删除。';

  @override
  String get memoryEntrySwitchScopeConfirmTitle => '更改记忆范围？';

  @override
  String get memoryEntrySwitchScopeToGlobal => '将这条记忆设为全局（所有助手可见）？';

  @override
  String get memoryEntrySwitchScopeToAssistant => '将这条记忆限制为仅本助手？';

  @override
  String get memoryEntryArchivedSection => '已归档';

  @override
  String get memoryEntryEmpty => '还没有记忆';

  @override
  String get memoryEntryEmptyDisabled => '该助手未启用长期记忆';

  @override
  String get memoryEntryEditTitle => '编辑记忆';

  @override
  String get memoryEntryCreateTitle => '新建记忆';

  @override
  String get memoryEntryContentHint => '输入记忆内容';

  @override
  String get memoryEntryTypeLabel => '类型';

  @override
  String get memoryEntryScopeLabel => '范围';

  @override
  String get memoryFilterScopeAll => '全部范围';

  @override
  String get memoryFilterScopeGlobal => '仅全局';

  @override
  String get memoryFilterScopeAssistant => '助手';

  @override
  String get memoryFilterTypeAll => '全部类型';

  @override
  String get memoryFilterStatusAll => '全部状态';

  @override
  String get memoryFilterStatusActive => '活跃';

  @override
  String get memoryFilterStatusArchived => '已归档';

  @override
  String get memorySearchHint => '搜索记忆';

  @override
  String get memorySearchEmpty => '没有匹配的记忆';

  @override
  String memoryOrphanBanner(int count) {
    return '有 $count 条孤儿助手记忆（助手已删除）';
  }

  @override
  String get memoryOrphanCleanupButton => '清理';

  @override
  String get memoryOrphanConfirmTitle => '清理孤儿记忆？';

  @override
  String memoryOrphanConfirmContent(int count) {
    return '将永久删除 $count 条所属助手已不存在的记忆。';
  }

  @override
  String get memoryOrganizeButton => '整理记忆';

  @override
  String get memoryOrganizeNeedsConversation => '需要在与该助手的对话中使用';

  @override
  String get memoryOrganizeNeedsModel => '请先在 设置 → 记忆 中选择记忆处理模型';

  @override
  String get memoryOrganizeStatusNever => '尚未整理';

  @override
  String memoryOrganizeStatusLast(String when) {
    return '上次整理：$when';
  }

  @override
  String memoryOrganizeStatusExtracted(int count) {
    return '提取 $count 条';
  }

  @override
  String get memoryOrganizeStatusSkipped => '无需记忆';

  @override
  String memoryOrganizeStatusFailed(String reason) {
    return '失败：$reason';
  }

  @override
  String memoryOrganizeStatusSkippedReason(String reason) {
    return '已跳过：$reason';
  }

  @override
  String get memoryOutcomeTemporaryConversation => '临时对话不会写入记忆';

  @override
  String get memoryOutcomeMemoryDisabled => '该助手已关闭记忆';

  @override
  String get memoryOutcomeAutoOrganizeOff => '自动整理已关闭';

  @override
  String get memoryOutcomeStreaming => '回复仍在生成，已跳过整理';

  @override
  String get memoryOutcomeBelowThreshold => '新消息不足，暂不整理';

  @override
  String get memoryOutcomeEmptyWindow => '没有新消息需要整理';

  @override
  String get memoryOutcomeMemoryModelUnset => '尚未选择记忆处理模型';

  @override
  String get memoryOutcomeMemoryModelMissing => '所选记忆模型已不可用';

  @override
  String get memoryOutcomeAssistantMissing => '找不到助手';

  @override
  String get memoryOutcomeConversationMissing => '找不到对话';

  @override
  String get memoryOutcomeQueueOverflow => '整理队列已满，本次任务被丢弃';

  @override
  String get memoryOutcomeGateRequestFailed => '判断是否值得记忆时，无法请求记忆模型';

  @override
  String get memoryOutcomeGateParseFailed => '判断是否值得记忆的回复无法解析';

  @override
  String get memoryOutcomeExtractRequestFailed => '提取记忆时，无法请求记忆模型';

  @override
  String get memoryOutcomeExtractParseFailed => '提取记忆的回复无法解析';

  @override
  String get memoryOutcomeDistillFailed => '用户画像提炼失败';

  @override
  String get memoryOutcomeMemoryExecutionError => '记忆工具执行失败';

  @override
  String get memoryOutcomeUnsupportedTool => '不支持的记忆工具';

  @override
  String get memoryOutcomeInvalidMemoryType => '记忆类型无效';

  @override
  String get memoryOutcomeInvalidMemoryContent => '记忆内容无效';

  @override
  String get memoryOutcomeInvalidQuery => '查询无效';

  @override
  String get memoryOutcomeInvalidMemoryId => '记忆 ID 无效';

  @override
  String get memoryOutcomeMemoryNotFound => '找不到这条记忆';

  @override
  String get memoryOutcomeInvalidProfileFields => '画像字段无效';

  @override
  String get memoryOutcomeChatSearchUnavailable => '对话搜索不可用';

  @override
  String get memoryOrganizeJustNow => '刚刚';

  @override
  String memoryOrganizeMinutesAgo(int n) {
    return '$n 分钟前';
  }

  @override
  String memoryOrganizeHoursAgo(int n) {
    return '$n 小时前';
  }

  @override
  String memoryOrganizeDaysAgo(int n) {
    return '$n 天前';
  }

  @override
  String get memoryModelMissingNotice => '需要先在 设置 → 记忆 中选择记忆处理模型。';

  @override
  String get memoryModelMissingGoSelect => '去选择';

  @override
  String get memoryEntriesPageTitle => '全部记忆';

  @override
  String get userProfilePageTitle => '用户画像';

  @override
  String get userProfilePreferredName => '希望怎么称呼我';

  @override
  String get userProfilePreferredNameHint => '这是希望模型怎么称呼你，与侧栏显示的用户名无关';

  @override
  String get userProfileGender => '性别';

  @override
  String get userProfilePronouns => '代词';

  @override
  String get userProfilePreferredLanguage => '偏好语言';

  @override
  String get userProfileTimezone => '时区';

  @override
  String get userProfileOccupation => '职业';

  @override
  String get userProfileLocation => '所在地';

  @override
  String get userProfileCustomSection => '自定义字段';

  @override
  String get userProfileAddCustom => '添加自定义字段';

  @override
  String get userProfileCustomKeyHint => '键名（custom.name）';

  @override
  String get userProfileCustomValueHint => '值';

  @override
  String get userProfileInvalidKey => '键名须为 custom. 后跟 1–32 位字母、数字、_ 或 -';

  @override
  String get userProfileClear => '清除';

  @override
  String get userProfileSave => '保存';

  @override
  String get userProfileEmptyValue => '未设置';

  @override
  String get legacyMemoryPageTitle => '旧版记忆';

  @override
  String get legacyMemoryBanner => '这些记忆来自旧版本，不会参与对话；你可以将它们迁移到当前记忆系统。';

  @override
  String get legacyMemoryEmpty => '没有旧版记忆';

  @override
  String get legacyMemoryCopy => '复制';

  @override
  String get legacyMemoryCopied => '已复制';

  @override
  String get legacyMemoryExport => '导出';

  @override
  String get legacyMemoryExportTitle => 'Kelivo 旧版记忆导出';

  @override
  String legacyMemoryAssistantHeader(String name) {
    return '助手：$name';
  }

  @override
  String get legacyMemorySearchHint => '搜索旧版记忆';

  @override
  String get legacyMemoryMigrate => '迁移';

  @override
  String get legacyMemoryMigrationTitle => '迁移旧版记忆';

  @override
  String legacyMemoryMigrationSubtitle(int count) {
    return '使用模型整理并分类 $count 条旧版记忆，原数据不会改变。';
  }

  @override
  String get legacyMemoryMigrationModel => '迁移模型';

  @override
  String get legacyMemoryMigrationChooseModel => '选择模型';

  @override
  String get legacyMemoryMigrationTarget => '保存到';

  @override
  String get legacyMemoryMigrationTargetGlobal => '全局';

  @override
  String get legacyMemoryMigrationTargetAssistant => '当前助手';

  @override
  String get legacyMemoryMigrationTargetOriginalAssistants => '原助手';

  @override
  String get legacyMemoryMigrationTargetGlobalDescription => '所有助手均可使用';

  @override
  String get legacyMemoryMigrationTargetAssistantDescription => '仅当前助手可使用';

  @override
  String get legacyMemoryMigrationTargetOriginalDescription => '每条记忆保留在原来的助手下';

  @override
  String get legacyMemoryMigrationStart => '开始迁移';

  @override
  String get legacyMemoryMigrationAnalyzing => '正在使用模型分析';

  @override
  String get legacyMemoryMigrationWriting => '正在写入记忆';

  @override
  String legacyMemoryMigrationProgress(int current, int total) {
    return '$current / $total';
  }

  @override
  String get legacyMemoryMigrationComplete => '迁移完成';

  @override
  String legacyMemoryMigrationResult(int created, int skipped) {
    return '已迁移 $created 条 · 跳过已有 $skipped 条';
  }

  @override
  String get legacyMemoryMigrationFailed => '迁移已停止。可以重试，已保存的记忆会自动跳过。';

  @override
  String get legacyMemoryMigrationRetry => '重试';

  @override
  String get legacyMemoryMigrationClose => '完成';

  @override
  String get legacyMemoryMigrationContentMode => '内容处理';

  @override
  String get legacyMemoryMigrationContentPreserve => '保留原文';

  @override
  String get legacyMemoryMigrationContentOrganize => '模型整理';

  @override
  String get legacyMemoryMigrationContentPreserveDescription =>
      '模型只负责分类，写入时保留旧记忆原文。';

  @override
  String get legacyMemoryMigrationContentOrganizeDescription =>
      '模型会分类并改写内容，使用可编辑的迁移提示词。';

  @override
  String get legacyMemoryMigrationBatchSize => '批大小';

  @override
  String legacyMemoryMigrationPartial(int created, int skipped, int failed) {
    return '已迁移 $created · 跳过 $skipped · 失败 $failed';
  }

  @override
  String get legacyMemoryMigrationContinue => '继续迁移';

  @override
  String get legacyMemoryMigrationErrorNetwork => '网络异常，请检查连接后重试。';

  @override
  String get legacyMemoryMigrationErrorFormat => '模型返回格式不正确。';

  @override
  String get legacyMemoryMigrationErrorAuth => '鉴权失败，请检查 API 密钥。';

  @override
  String legacyMemoryMigrationErrorOther(String message) {
    return '迁移失败：$message';
  }

  @override
  String get legacyMemoryModeTitle => '使用旧版记忆';

  @override
  String get legacyMemoryModeSubtitle => '全局设置，影响所有助手';

  @override
  String legacyMemoryModeCacheWarning(String token) {
    return '默认模板会注入当前时间 $token，影响缓存命中率，如不需要可删除';
  }

  @override
  String get memoryUiContentLabel => '内容';

  @override
  String get memoryUiValueLabel => '值';

  @override
  String get memoryUiCustomKeyLabel => '键名';

  @override
  String get memoryUiStatusLabel => '状态';

  @override
  String get memoryUiAssistantLabel => '助手';

  @override
  String get memoryUiAssistantAll => '全部助手';

  @override
  String get memoryUiSearchClear => '清除搜索';

  @override
  String get memoryUiAssistantLegacyTitle => '旧版记忆（只读）';

  @override
  String get memoryUiAssistantLegacySubtitle => '该助手来自旧版本的记忆';

  @override
  String get assistantEditMemorySwitchTitle => '使用长期记忆';

  @override
  String get assistantEditMemorySwitchSubtitle => '把已保存的记忆注入对话，并允许此助手写入新记忆';

  @override
  String get assistantEditAutoOrganizeTitle => '自动整理记忆';

  @override
  String get assistantEditAutoOrganizeSubtitle => '对话后自动运行记忆管线';

  @override
  String get assistantEditAllowPastRecallTitle => '允许回忆过去对话';

  @override
  String get assistantEditAllowPastRecallSubtitle => '启用跨会话的对话搜索';

  @override
  String get assistantEditGenerateSummaryTitle => '生成会话摘要';

  @override
  String get assistantEditGenerateSummarySubtitle => '摘要仅供对话搜索使用';

  @override
  String get assistantEditManageMemoryTitle => '本助手可见的记忆';

  @override
  String get assistantEditWriteScopeTitle => '记忆写入范围';

  @override
  String get assistantEditWriteScopeSubtitle => '新记忆默认写入的位置';

  @override
  String get assistantEditWriteScopeAlwaysGlobal => '一律全局';

  @override
  String get assistantEditWriteScopeAlwaysGlobalSubtitle => '新记忆对所有助手可见';

  @override
  String get assistantEditWriteScopeAlwaysAssistant => '一律本助手';

  @override
  String get assistantEditWriteScopeAlwaysAssistantSubtitle => '新记忆只对本助手可见';

  @override
  String get assistantEditWriteScopeToolDefaultGlobal => '模型自选（默认全局）';

  @override
  String get assistantEditWriteScopeToolDefaultGlobalSubtitle =>
      '模型可选择全局或本助手，缺省写入全局';

  @override
  String get assistantEditWriteScopeToolDefaultAssistant => '模型自选（默认本助手）';

  @override
  String get assistantEditWriteScopeToolDefaultAssistantSubtitle =>
      '模型可选择全局或本助手，缺省写入本助手';

  @override
  String get assistantEditDedupeModeTitle => '去重方式';

  @override
  String get assistantEditDedupeModeSubtitle => '候选记忆如何与已有条目比对';

  @override
  String get assistantEditDedupeModeBatched => '合并';

  @override
  String get assistantEditDedupeModeBatchedSubtitle =>
      '一次请求判断本轮全部候选。更快更省；条目多时精度较差。';

  @override
  String get assistantEditDedupeModePerItem => '逐条';

  @override
  String get assistantEditDedupeModePerItemSubtitle =>
      '每条候选单独请求判断。更准确，但会增加处理模型调用。';

  @override
  String get assistantEditOrganizeFrequencyTitle => '整理频率';

  @override
  String get assistantEditOrganizeFrequencySubtitle => '每累积 N 轮助手回复触发一次自动整理';

  @override
  String assistantEditOrganizeFrequencyOption(int n) {
    return '每 $n 轮';
  }

  @override
  String get assistantEditOrganizeFrequencyCustomButton => '自定义';

  @override
  String get assistantEditOrganizeFrequencyCustomTitle => '自定义整理频率';

  @override
  String get assistantEditOrganizeFrequencyCustomDescription =>
      '请输入 1 到 20 之间的整数。';

  @override
  String get assistantEditOrganizeFrequencyCustomLabel => '轮数';

  @override
  String get assistantEditOrganizeFrequencyCustomHint => '1–20';

  @override
  String get assistantEditOrganizeFrequencyCustomInvalid => '请输入 1 到 20 之间的整数';

  @override
  String get worldBookTitle => '世界书';

  @override
  String get worldBookAdd => '添加世界书';

  @override
  String get worldBookEmptyMessage => '暂无世界书';

  @override
  String get worldBookUnnamed => '未命名世界书';

  @override
  String get worldBookDisabledTag => '已停用';

  @override
  String get worldBookAlwaysOnTag => '常驻';

  @override
  String get worldBookAddEntry => '添加条目';

  @override
  String get worldBookExport => '分享/导出';

  @override
  String get worldBookConfig => '配置';

  @override
  String get worldBookDeleteTitle => '删除世界书';

  @override
  String worldBookDeleteMessage(String name) {
    return '确定删除「$name」？此操作无法撤销。';
  }

  @override
  String get worldBookCancel => '取消';

  @override
  String get worldBookDelete => '删除';

  @override
  String worldBookExportFailed(String error) {
    return '导出失败：$error';
  }

  @override
  String get worldBookNoEntriesHint => '暂无条目';

  @override
  String get worldBookUnnamedEntry => '未命名条目';

  @override
  String worldBookKeywordsLine(String keywords) {
    return '关键词：$keywords';
  }

  @override
  String get worldBookEditEntry => '编辑条目';

  @override
  String get worldBookDeleteEntry => '删除条目';

  @override
  String get worldBookNameLabel => '名称';

  @override
  String get worldBookDescriptionLabel => '简介';

  @override
  String get worldBookEnabledLabel => '启用';

  @override
  String get worldBookSave => '保存';

  @override
  String get worldBookEntryNameLabel => '条目名称';

  @override
  String get worldBookEntryEnabledLabel => '启用条目';

  @override
  String get worldBookEntryPriorityLabel => '优先级';

  @override
  String get worldBookEntryKeywordsLabel => '关键词';

  @override
  String get worldBookEntryKeywordsHint => '输入关键词后点 + 添加。';

  @override
  String get worldBookEntryKeywordInputHint => '输入关键词';

  @override
  String get worldBookEntryKeywordAddTooltip => '添加关键词';

  @override
  String get worldBookEntryUseRegexLabel => '使用正则';

  @override
  String get worldBookEntryCaseSensitiveLabel => '区分大小写';

  @override
  String get worldBookEntryAlwaysOnLabel => '常驻激活';

  @override
  String get worldBookEntryAlwaysOnHint => '无需匹配也会注入';

  @override
  String get worldBookEntryScanDepthLabel => '扫描深度';

  @override
  String get worldBookEntryContentLabel => '内容';

  @override
  String get worldBookEntryInjectionPositionLabel => '注入位置';

  @override
  String get worldBookEntryInjectionRoleLabel => '注入角色';

  @override
  String get worldBookEntryInjectDepthLabel => '注入深度';

  @override
  String get worldBookInjectionPositionBeforeSystemPrompt => '系统提示前';

  @override
  String get worldBookInjectionPositionAfterSystemPrompt => '系统提示后';

  @override
  String get worldBookInjectionPositionTopOfChat => '对话顶部';

  @override
  String get worldBookInjectionPositionBottomOfChat => '对话底部';

  @override
  String get worldBookInjectionPositionAtDepth => '指定深度';

  @override
  String get worldBookInjectionRoleUser => '用户';

  @override
  String get worldBookInjectionRoleAssistant => '助手';

  @override
  String get mcpToolNeedsApproval => '需要审批';

  @override
  String get toolApprovalPending => '等待审批';

  @override
  String get toolApprovalApprove => '批准';

  @override
  String get toolApprovalDeny => '拒绝';

  @override
  String get toolApprovalDenyTitle => '拒绝工具调用';

  @override
  String get toolApprovalDenyHint => '原因（可选）';

  @override
  String toolApprovalDeniedMessage(Object reason, Object toolName) {
    return '工具调用 \"$toolName\" 已被用户拒绝。原因：$reason';
  }

  @override
  String get askUserCardSubmit => '提交回答';

  @override
  String get askUserCardCustomHint => '输入你的回答';

  @override
  String get askUserCardSomethingElse => '其他';

  @override
  String get askUserCardSkip => '跳过';

  @override
  String get askUserCardSkipped => '已跳过';

  @override
  String get askUserCardAnswered => '已回答';

  @override
  String get askUserCardInactive => '这个问题已不再活动。请重新生成或继续对话。';

  @override
  String get askUserCardCancelled => '问题已取消';

  @override
  String askUserCardQuestionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '询问 $count 个问题',
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
  String get debugPageConversationToolsTitle => '对话工具';

  @override
  String get debugPageCreateOversizedConversationButton => '创建超大对话（30 MB）';

  @override
  String get debugPageCreateManyMessagesConversationButton => '创建 1024 条消息的对话';

  @override
  String get debugPageCreateDailyMixedMarkdownConversationButton =>
      '创建 3000 条日常混合 Markdown 消息';

  @override
  String get debugPageCreateLongReasoningConversationButton =>
      '创建长思考链对话（128 条）';

  @override
  String get debugPageCreatingButton => '创建中...';

  @override
  String get debugPageCreatingOversizedConversation => '正在创建 30 MB 超大对话...';

  @override
  String get debugPageCreatingManyMessagesConversation => '正在创建 1024 条消息的对话...';

  @override
  String get debugPageCreatingDailyMixedMarkdownConversation =>
      '正在创建 3000 条日常混合 Markdown 对话...';

  @override
  String get debugPageCreatingLongReasoningConversation => '正在创建长思考链调试对话...';

  @override
  String get debugPageNoCurrentAssistant => '当前没有助手。请先创建或选择一个助手。';

  @override
  String debugPageConversationCreated(int count) {
    return '已创建包含 $count 条消息的调试对话。';
  }

  @override
  String debugPageCreateConversationFailed(String error) {
    return '创建调试对话失败：$error';
  }

  @override
  String debugPageOversizedConversationTitle(int sizeMB) {
    return '超大对话测试（$sizeMB MB）';
  }

  @override
  String debugPageManyMessagesConversationTitle(int count) {
    return '$count 条消息测试';
  }

  @override
  String debugPageDailyMixedMarkdownConversationTitle(int count) {
    return '$count 条日常混合 Markdown 消息测试';
  }

  @override
  String debugPageLongReasoningConversationTitle(int count) {
    return '$count 条长思考链测试';
  }

  @override
  String get debugPageOversizedConversationSeedText =>
      '这是一段用于复现超大对话渲染卡顿的长调试文本。它包含重复的 Markdown 风格文本、标点、中文内容和普通词语，方便测试聊天渲染、存储和滚动性能。';

  @override
  String debugPageManyMessagesSeedText(String role, int index) {
    return '$role 消息 #$index：快速随机调试样例，用于测试列表渲染、滚动稳定性、消息分组和会话历史性能。';
  }

  @override
  String get migrationIntroTitle => '升级聊天记录存储';

  @override
  String get migrationIntroSubtitle =>
      'Kelivo 将聊天记录迁移到更快的 SQLite 数据库。升级会在应用打开前完成，避免新旧数据同时写入。';

  @override
  String get migrationBackupNote => '迁移开始前，会先导出包含设置、聊天记录和本地文件的 ZIP 备份。';

  @override
  String get migrationPerformanceNote =>
      '迁移后，启动、历史加载和搜索都会使用 SQLite 索引，长对话会更流畅。';

  @override
  String get migrationSourceDatabaseLabel => 'Hive';

  @override
  String get migrationTargetDatabaseLabel => 'SQLite';

  @override
  String get migrationChooseFolderButton => '选择文件夹并备份';

  @override
  String get migrationSaveBackupButton => '保存备份 ZIP';

  @override
  String get migrationBackingUpTitle => '正在备份';

  @override
  String get migrationBackingUpSubtitle =>
      '正在导出设置、聊天记录、上传文件、图片和字体。请保持 Kelivo 开启，等待备份完成。';

  @override
  String get migrationMigratingTitle => '正在迁移到 SQLite';

  @override
  String get migrationMigratingSubtitle =>
      '正在分批写入会话和消息，避免超大聊天记录占满内存。请保持 Kelivo 在前台，等待迁移完成。';

  @override
  String migrationBackingUpDetail(String fileName) {
    return '正在备份 $fileName';
  }

  @override
  String migrationMigratingDetail(int count) {
    return '已迁移 $count 条消息';
  }

  @override
  String get migrationMigratingPrepareDetail => '正在准备 SQLite 数据库';

  @override
  String get migrationMigratingToolEventsDetail => '正在迁移工具调用记录';

  @override
  String get migrationMigratingValidateDetail => '正在校验迁移数据';

  @override
  String get migrationBackupReadyDetail => '备份 ZIP 已准备好';

  @override
  String get migrationSavingBackupZipDetail => '正在保存备份 ZIP';

  @override
  String get migrationBackupFileSavedTitle => '备份 ZIP 已保存';

  @override
  String get migrationChecklistBackupFiles => '导出 Hive 备份 ZIP';

  @override
  String get migrationChecklistPrepareSqlite => '准备 SQLite 数据库';

  @override
  String get migrationChecklistMigrateMessages => '迁移会话和消息';

  @override
  String get migrationChecklistMigrateToolEvents => '迁移工具调用记录';

  @override
  String get migrationChecklistValidate => '校验迁移数据';

  @override
  String get migrationStepBackup => '备份';

  @override
  String get migrationStepMigrate => '迁移';

  @override
  String get migrationStepComplete => '完成';

  @override
  String get migrationCompleteTitle => '升级完成';

  @override
  String get migrationCompleteSubtitle =>
      '你的聊天记录已迁移到 SQLite。请重启 Kelivo 进入升级后的应用。';

  @override
  String get migrationConversationCount => '对话';

  @override
  String get migrationMessageCount => '消息';

  @override
  String get migrationConvertedCount => '已转换';

  @override
  String get migrationMalformedCount => '格式异常';

  @override
  String get migrationMissingFilesCount => '缺失文件';

  @override
  String get migrationRestartButton => '重启 Kelivo';

  @override
  String get migrationFailedTitle => '迁移失败';

  @override
  String get migrationFailedSubtitle => '原始 Hive 数据和备份都仍然保留。查看下方原因后可以重试。';

  @override
  String get migrationUnknownError => '未知迁移错误。';

  @override
  String get migrationFailureLogTitle => '失败日志';

  @override
  String get migrationRetryButton => '重试迁移';

  @override
  String get migrationSkipButton => '跳过迁移并全新开始';

  @override
  String get migrationSkipDialogTitle => '跳过迁移？';

  @override
  String get migrationSkipDialogMessage =>
      'Kelivo 将以空的聊天数据库启动。旧的聊天记录会保留在磁盘上（重命名为 .retired 后缀），但不会被迁移，也不会在应用中显示。之后如需找回，请使用已保存的备份 ZIP。';

  @override
  String get migrationSkipDialogCancel => '取消';

  @override
  String get migrationSkipDialogConfirm => '跳过并全新开始';

  @override
  String get migrationChatsExportDegradedNote =>
      'chats.json 导出因出错而被跳过。备份 ZIP 仍包含原始 Hive 文件，完整聊天记录未丢失。';

  @override
  String get timelineJumpToLatest => '跳到最新';

  @override
  String largeContentShowMore(int count) {
    return '再显示 $count 项';
  }

  @override
  String get largeContentCollapse => '收起';

  @override
  String get imageSettingsPageTitle => '图片处理';

  @override
  String get imageSettingsPageEditSectionTitle => '编辑';

  @override
  String get imageSettingsPageQualitySectionTitle => '上传图片质量';

  @override
  String get imageSettingsPageQualityOriginal => '原图';

  @override
  String get imageSettingsPageQualityOriginalSubtitle => '不压缩，原样上传';

  @override
  String get imageSettingsPageQualityHigh => '高质量';

  @override
  String get imageSettingsPageQualityHighSubtitle => '最长边 2048 像素 · 质量 90';

  @override
  String get imageSettingsPageQualityBalanced => '平衡';

  @override
  String get imageSettingsPageQualityBalancedSubtitle => '最长边 1568 像素 · 质量 85';

  @override
  String get imageSettingsPageQualitySaver => '节省流量';

  @override
  String get imageSettingsPageQualitySaverSubtitle => '最长边 1024 像素 · 质量 70';

  @override
  String get imageSettingsPageQualityCustom => '自定义';

  @override
  String get imageSettingsPageQualityCustomSubtitle => '自选压缩质量';

  @override
  String get imageSettingsPageCustomQualityTitle => '压缩质量';

  @override
  String get imageSettingsPageCompressTransparentTitle => '压缩透明及动态图片';

  @override
  String get imageSettingsPageCompressTransparentSubtitle =>
      '开启后将压缩透明 PNG、GIF 等格式；透明区域填充为白色，动图仅保留第一帧。';

  @override
  String get imageSettingsPageFooter =>
      '压缩在添加图片时进行，已保存或已发送的图片不受影响；压缩后图片以 JPEG 格式随消息发送。';

  @override
  String get memoryTraceSettingsTitle => '流程追踪';

  @override
  String get memoryTraceSettingsSubtitle => '逐步查看每次后台记忆处理的全过程';

  @override
  String get memoryTracePageTitle => '记忆流程追踪';

  @override
  String get memoryTraceRecordingSection => '记录';

  @override
  String get memoryTraceToggleTitle => '记录流程追踪';

  @override
  String get memoryTraceToggleSubtitle => '仅在内存中保留最近几次后台运行的提示词、模型回复与实际改动';

  @override
  String get memoryTraceRunsSection => '最近运行';

  @override
  String get memoryTraceEmptyTitle => '暂无追踪记录';

  @override
  String get memoryTraceEmptySubtitle => '后台记忆流程运行后，记录会显示在这里。';

  @override
  String get memoryTraceDisabledTitle => '记录已关闭';

  @override
  String get memoryTraceDisabledSubtitle => '开启记录后，下一次后台记忆运行才会被捕获。';

  @override
  String get memoryTraceClearAction => '清空';

  @override
  String get memoryTraceClearSheetTitle => '清空追踪记录';

  @override
  String get memoryTraceClearSheetMessage => '将删除所有已记录的追踪。追踪从不写入磁盘，因此不会影响其他数据。';

  @override
  String get memoryTraceClearConfirm => '清空记录';

  @override
  String get memoryTraceCancel => '取消';

  @override
  String get memoryTraceClearedToast => '追踪记录已清空';

  @override
  String get memoryTraceCopyAction => '复制';

  @override
  String get memoryTraceCopiedToast => '已复制到剪贴板';

  @override
  String get memoryTraceTriggerAuto => '自动';

  @override
  String get memoryTraceTriggerManual => '手动';

  @override
  String get memoryTraceTriggerTool => '工具调用';

  @override
  String get memoryTraceTriggerSummary => '对话摘要';

  @override
  String get memoryTraceScopeAssistant => '助手';

  @override
  String get memoryTraceScopeGlobal => '全局';

  @override
  String get memoryTraceStepGatekeeper => '守门判断';

  @override
  String get memoryTraceStepExtract => '记忆抽取';

  @override
  String get memoryTraceStepSmartAdd => '智能写入';

  @override
  String get memoryTraceStepDistiller => '用户画像提炼';

  @override
  String get memoryTraceStepSummary => '对话摘要生成';

  @override
  String get memoryTraceStepChatSearch => '历史对话检索';

  @override
  String get memoryTraceStepTool => '记忆工具';

  @override
  String get memoryTraceStatusSuccess => '成功';

  @override
  String get memoryTraceStatusFailed => '失败';

  @override
  String get memoryTraceStatusSkipped => '跳过';

  @override
  String get memoryTraceStatusRunning => '进行中';

  @override
  String get memoryTraceOutcomeAdvanced => '水位已推进';

  @override
  String get memoryTraceOutcomeHeld => '水位未推进';

  @override
  String get memoryTraceOutcomeForced => '强制推进';

  @override
  String get memoryTraceDetailTitle => '追踪详情';

  @override
  String get memoryTraceSectionOverview => '概览';

  @override
  String get memoryTraceSectionPrompt => '提示词';

  @override
  String get memoryTraceSectionResponse => '原始回复';

  @override
  String get memoryTraceSectionParsed => '解析结果';

  @override
  String get memoryTraceSectionMutations => '实际改动';

  @override
  String get memoryTraceFieldTime => '开始时间';

  @override
  String get memoryTraceFieldDuration => '耗时';

  @override
  String get memoryTraceFieldTrigger => '触发方式';

  @override
  String get memoryTraceFieldScope => '作用范围';

  @override
  String get memoryTraceFieldConversation => '对话';

  @override
  String get memoryTraceFieldAssistant => '助手';

  @override
  String get memoryTraceFieldWindow => '消息窗口';

  @override
  String get memoryTraceFieldWatermark => '水位';

  @override
  String get memoryTraceFieldOutcome => '结果';

  @override
  String get memoryTraceFieldError => '错误';

  @override
  String get memoryTraceMutationCreated => '新建';

  @override
  String get memoryTraceMutationMerged => '合并';

  @override
  String get memoryTraceMutationEdited => '修改';

  @override
  String get memoryTraceMutationArchived => '归档';

  @override
  String get memoryTraceMutationLinked => '关联';

  @override
  String get memoryTraceMutationProfileWritten => '写入画像字段';

  @override
  String get memoryTraceMutationProfileCleared => '清除画像字段';

  @override
  String get memoryTraceMutationSummary => '写入对话摘要';

  @override
  String get memoryTraceBefore => '改动前';

  @override
  String get memoryTraceAfter => '改动后';

  @override
  String get memoryTraceEmptyValue => '（空）';

  @override
  String memoryTraceStepsCount(int count) {
    return '$count 个步骤';
  }

  @override
  String memoryTraceMutationsCount(int count) {
    return '$count 项改动';
  }

  @override
  String memoryTraceRepeatCount(int count) {
    return '重复 $count 次';
  }

  @override
  String memoryTraceWindowValue(int size, int start, int end) {
    return '$size 条消息 · #$start–#$end';
  }

  @override
  String get memoryTraceShowMore => '展开全文';

  @override
  String get memoryTraceShowLess => '收起';

  @override
  String get messageStyleSettingsPageTitle => '消息样式';

  @override
  String get messageStyleSettingsPageReset => '重置';

  @override
  String get messageStyleSettingsPageResetConfirm => '恢复全部消息样式自定义？';

  @override
  String get messageStyleSettingsPageCancel => '取消';

  @override
  String get messageStyleSettingsPageLight => '浅色';

  @override
  String get messageStyleSettingsPageDark => '深色';

  @override
  String get messageStyleSettingsPageDefaultHint => '默认样式跟随当前主题，没有可调参数。';

  @override
  String get messageStyleSettingsPageStyleDefaultSubtitle => '跟随主题，不可调节';

  @override
  String get messageStyleSettingsPageStyleFrostedSubtitle => '半透明毛玻璃';

  @override
  String get messageStyleSettingsPageStyleSolidSubtitle => '不透明纯色底';

  @override
  String get messageStyleSettingsPageBlur => '模糊强度';

  @override
  String get messageStyleSettingsPageBlurHint => '模糊作用于气泡背后的内容，未设置聊天壁纸时效果不明显';

  @override
  String get messageStyleSettingsPageBackgroundColor => '背景颜色';

  @override
  String get messageStyleSettingsPageBackgroundOpacity => '背景不透明度';

  @override
  String get messageStyleSettingsPageBorderColor => '边框颜色';

  @override
  String get messageStyleSettingsPageBorderOpacity => '边框不透明度';

  @override
  String get messageStyleSettingsPageBorderWidth => '边框宽度';

  @override
  String get messageStyleSettingsPageTextColor => '文字颜色';

  @override
  String get messageStyleSettingsPageCornerRadius => '圆角半径';

  @override
  String get messageStyleSettingsPagePreviewUser => '这是一条用户消息';

  @override
  String get messageStyleSettingsPagePreviewAssistant => '这是一条助手回复。';

  @override
  String get messageStyleSettingsPagePreviewThinking => '思考中';

  @override
  String get messageStyleSettingsPageRoleUser => '用户';

  @override
  String get messageStyleSettingsPageRoleAssistant => '助手';

  @override
  String get messageStyleSettingsPageRoleAssistantHint =>
      '助手设定同时作用于思考、工具调用和翻译卡片。';
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
  String get settingsPageDisplay => '偏好设置';

  @override
  String get settingsPageDisplaySubtitle => '外观、行为与交互偏好';

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
  String get storageSpaceCategoryFonts => '字体';

  @override
  String get storageSpaceCategoryLocalModels => '本地模型';

  @override
  String get storageSpaceOtherHint => '包括导入字体、本地下载模型和其他应用文件。';

  @override
  String get storageSpaceSubOtherApp => '其他文件';

  @override
  String get storageSpaceCategoryChatData => '聊天记录';

  @override
  String get storageSpaceCategoryLegacyChatData => '聊天记录（旧）';

  @override
  String get storageSpaceCategoryRestoreTraces => '恢复痕迹';

  @override
  String get storageSpaceRestoreTracesHint => '恢复完成后保留的旧数据快照。清理不会影响当前应用数据。';

  @override
  String get storageSpaceClearRestoreTracesButton => '清理恢复痕迹';

  @override
  String get storageSpaceClearRestoreTracesConfirmMessage =>
      '确定清理已完成恢复留下的旧数据快照吗？当前数据库、设置和文件不会受到影响。';

  @override
  String get storageSpaceSubCompletedRestoreRuns => '已完成的恢复快照';

  @override
  String get storageSpaceCategoryAssistantData => '助手';

  @override
  String get storageSpaceCategoryCache => '缓存';

  @override
  String get storageSpaceCategoryLogs => '日志';

  @override
  String get storageSpaceCategoryOther => '其他';

  @override
  String storageSpaceFilesCount(int count) {
    return '$count 个文件';
  }

  @override
  String get storageSpaceSafeToClearHint => '可安全清理，不影响聊天记录。';

  @override
  String get storageSpaceLegacyChatDataHint =>
      '这是迁移到 SQLite 前保留的 Hive 旧文件。清理后不会删除当前聊天记录。';

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
  String get storageSpaceSubChatDatabase => '聊天数据库';

  @override
  String get storageSpaceSubChatWriteAheadLog => '写入日志';

  @override
  String get storageSpaceSubChatSharedMemory => '共享内存索引';

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
  String get storageSpaceSubLogsContext => '上下文日志';

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
  String get storageSpaceClearLegacyChatDataButton => '清理旧聊天记录';

  @override
  String get storageSpaceExportLegacyChatFileButton => '导出';

  @override
  String storageSpaceExportDone(Object fileName) {
    return '已导出 $fileName';
  }

  @override
  String storageSpaceExportFailed(Object error) {
    return '导出失败：$error';
  }

  @override
  String get storageSpaceClearLegacyChatDataConfirmMessage =>
      '确定清理保留的旧聊天文件吗？当前 SQLite 聊天记录不会受到影响。';

  @override
  String get storageSpaceViewLogsButton => '查看日志';

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
  String get storageSpaceSourceLabel => '来源';

  @override
  String get storageSpaceSourceAll => '全部';

  @override
  String get storageSpaceSourceUserUpload => '用户上传';

  @override
  String get storageSpaceSourceAssistant => '助手发出';

  @override
  String get storageSpaceSortLabel => '排序';

  @override
  String get storageSpaceSortNewest => '最新';

  @override
  String get storageSpaceSortOldest => '最旧';

  @override
  String get storageSpaceSortLargest => '最大';

  @override
  String get storageSpaceSortSmallest => '最小';

  @override
  String get settingsPageAboutSection => '关于';

  @override
  String get settingsPageAbout => '关于';

  @override
  String get settingsPageStatistics => '统计';

  @override
  String get settingsPageDocs => '使用文档';

  @override
  String get settingsPageLogs => '日志';

  @override
  String get settingsPageSponsor => '赞助';

  @override
  String get settingsPageShare => '分享';

  @override
  String get statsPageTitle => '统计';

  @override
  String get statsPageRangeAllTime => '全部';

  @override
  String get statsPageRangeLast30Days => '最近 30 天';

  @override
  String get statsPageRangePreviousMonth => '上个月';

  @override
  String get statsPageRangePreviousQuarter => '上个季度';

  @override
  String get statsPageRangeCustom => '自定义';

  @override
  String get statsPageHeatmapTitle => '聊天热力图';

  @override
  String get statsPageHeatmapLess => '少';

  @override
  String get statsPageHeatmapMore => '多';

  @override
  String get statsPageSummaryTitle => '总览';

  @override
  String get statsPageTotalConversations => '总对话数';

  @override
  String get statsPageTotalMessages => '总消息数';

  @override
  String get statsPageInputTokens => '输入 Tokens';

  @override
  String get statsPageOutputTokens => '输出 Tokens';

  @override
  String get statsPageCachedTokens => '缓存 Tokens';

  @override
  String get statsPageLaunchCount => '应用启动次数';

  @override
  String get statsPageUsageTrendTitle => '用量趋势';

  @override
  String get statsPageModelUsageTitle => '模型使用率';

  @override
  String get statsPageAssistantUsageTitle => '助手使用率';

  @override
  String get statsPageTopicVolumeTitle => '话题内容量';

  @override
  String get statsPageModelColumn => '模型';

  @override
  String get statsPageAssistantColumn => '助手';

  @override
  String get statsPageTopicColumn => '话题';

  @override
  String get statsPageMessagesColumn => '消息数';

  @override
  String get statsPageTopicsColumn => '话题数';

  @override
  String get statsPageEmptyTitle => '暂无统计数据';

  @override
  String get statsPageShowAllTooltip => '查看全部';

  @override
  String get statsPageClose => '关闭';

  @override
  String get statsPageUnknownProvider => '未知供应商';

  @override
  String get statsPageUnknownAssistant => '默认助手';

  @override
  String get statsPageUnknownModel => '未知模型';

  @override
  String get statsPageUnknownTopic => '未命名话题';

  @override
  String get statsPageCustomRangeTitle => '自定义时间段';

  @override
  String get statsPageCustomRangeStart => '开始';

  @override
  String get statsPageCustomRangeEnd => '结束';

  @override
  String get statsPageCustomRangeCancel => '取消';

  @override
  String get statsPageCustomRangeApply => '应用';

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
  String get sponsorPageScanQrHint => '扫描二维码赞助';

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
  String get mermaidImageTab => '图片';

  @override
  String get mermaidCodeTab => '代码';

  @override
  String get mermaidFullScreen => '全屏';

  @override
  String get mermaidGeneratingImage => '图片生成中';

  @override
  String get mermaidGenerationFailedHint => '生成失败，换个方式问问吧';

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
  String assistantProviderSampleAssistantSystemPrompt(String model_name) {
    return '你是$model_name，一位乐于助人的 AI 助手。请准确、简洁地回答问题；不确定时如实说明。需要时可使用清晰结构（短段落或列表）。默认使用用户的语言回复。';
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
  String get mcpTransportTagSse => 'SSE';

  @override
  String get mcpTransportTagHttp => 'HTTP';

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
  String get homePageAudioAttachmentUnsupported =>
      '当前模型不支持音频附件，请切换到支持音频输入的模型或移除音频文件后重试。';

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
  String get homePageDeleteMessage => '删除本版本';

  @override
  String get homePageDeleteMessageConfirm => '确定要删除当前版本吗？此操作不可撤销。';

  @override
  String get homePageDeleteAllVersions => '删除全部版本';

  @override
  String get homePageDeleteAllVersionsConfirm => '确定要删除这条消息的全部版本吗？此操作不可撤销。';

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
  String get assistantEditPageLocalToolsTab => '本地工具';

  @override
  String get assistantEditTabLayoutTooltip => '自定义标签页';

  @override
  String get assistantEditTabLayoutTitle => '自定义标签页';

  @override
  String get assistantEditTabLayoutSubtitle => '拖动标签页调整顺序，关闭暂时用不到的标签页。';

  @override
  String get assistantEditOutlineModeTitle => '二级列表样式';

  @override
  String get assistantEditOutlineModeSubtitle => '先显示助手概览，再从列表进入各个设置项。';

  @override
  String get assistantEditTabLayoutResetTooltip => '重置标签页布局';

  @override
  String get assistantEditTabLayoutAtLeastOneVisible => '至少保留一个可见标签页';

  @override
  String assistantEditTabLayoutDragHandle(String tab) {
    return '拖动以调整 $tab 的顺序';
  }

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
  String get assistantRegexScopeReplaceOnly => '仅替换';

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
  String get assistantEditUseAssistantAvatarSubtitle => '在聊天中使用助手头像替代模型头像';

  @override
  String get assistantEditUseAssistantNameTitle => '使用助手名字';

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
  String get desktopNavGlobalSearchTooltip => '全局搜索';

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
  String get displaySettingsPageIosBackgroundChatTitle => 'iOS 后台生成';

  @override
  String get iosBackgroundSettingsPageTitle => 'iOS 后台生成';

  @override
  String get iosBackgroundStatusOn => '开启';

  @override
  String get iosBackgroundStatusOff => '关闭';

  @override
  String get iosBackgroundGenerationEnableTitle => '后台生成';

  @override
  String get iosBackgroundGenerationEnableSubtitle =>
      'App 离开前台后，使用 iOS 分配的后台时间继续当前回复。';

  @override
  String get iosBackgroundTaskRefreshTitle => '后台任务恢复';

  @override
  String get iosBackgroundTaskRefreshSubtitle => '在系统条件允许时，向 iOS 请求刷新和处理机会。';

  @override
  String get iosLiveActivityTitle => '实时活动';

  @override
  String get iosLiveActivitySubtitle => '支持时在锁屏和灵动岛显示后台回复状态。';

  @override
  String get iosBackgroundNotificationsTitle => '任务通知';

  @override
  String get iosBackgroundNotificationsSubtitle => '后台回复完成或中断时发送本地通知。';

  @override
  String get iosBackgroundLimitNoticeTitle => 'iOS 仍可能暂停任务';

  @override
  String get iosBackgroundLimitNoticeBody =>
      '这些选项使用 Apple 支持的后台时间、BackgroundTasks、通知和实时活动。它们能提升连续性，但不能强制 iOS 永久保持 Kelivo 运行。';

  @override
  String get iosBackgroundUnsupportedLiveActivity =>
      '需要 iOS 16.1 或更高版本，并在系统设置中允许实时活动。';

  @override
  String get iosBackgroundNativeStatusTitle => '系统状态';

  @override
  String get iosBackgroundNativeStatusUnavailable => '需要在 iOS 上运行后查看';

  @override
  String get iosBackgroundLiveActivityAvailable => '实时活动可用';

  @override
  String get iosBackgroundLiveActivityUnavailable => '实时活动不可用';

  @override
  String get iosBackgroundNotificationsAuthorized => '通知已允许';

  @override
  String get iosBackgroundNotificationsNotAuthorized => '通知未允许';

  @override
  String get iosBackgroundGenerationActiveTitle => 'Kelivo 正在生成';

  @override
  String get iosBackgroundGenerationActiveDetail => '助手正在后台回复';

  @override
  String get iosBackgroundGenerationStreamingDetail => '正在接收助手回复';

  @override
  String iosBackgroundGenerationTokenCount(int count) {
    return '$count tokens';
  }

  @override
  String get iosBackgroundGenerationCompleteTitle => '生成完成';

  @override
  String get iosBackgroundGenerationCompleteDetail => '助手回复已准备好';

  @override
  String get iosBackgroundGenerationInterruptedTitle => '生成已中断';

  @override
  String get iosBackgroundGenerationInterruptedDetail => '后台回复在完成前停止';

  @override
  String get iosBackgroundGenerationCancelledDetail => '生成已停止';

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
  String get assistantEditPromptTimeVarWarning =>
      '在系统提示词中使用时间变量会让每一轮请求的开头都不同，Prompt 缓存无法命中，费用和首字延迟都会上升。需要让模型知道当前时间时，请改用下方的「追加当前时间」开关。';

  @override
  String get assistantEditPromptAppendTimeTitle => '追加当前时间';

  @override
  String get assistantEditPromptAppendTimeSubtitle =>
      '在每条用户消息末尾追加发送时刻。时间在请求末尾，不影响 Prompt 缓存。';

  @override
  String get assistantEditPromptAppendTimeInfoTitle => '追加时间格式';

  @override
  String assistantEditPromptAppendTimeInfoBody(String example) {
    return '开启后，会在每条用户消息末尾先空一行，再追加如下标签：\n\n$example\n\n时间取该消息自己的发送时刻，重试时保持不变。';
  }

  @override
  String get assistantEditPromptAppendTimeInfoClose => '知道了';

  @override
  String get assistantEditPromptTimeVarDialogTitle => '系统提示词中含时间变量';

  @override
  String assistantEditPromptTimeVarDialogBody(String variables) {
    return '你的系统提示词里用了 $variables。系统提示词每次请求都会重新渲染，含时间变量会让每一轮请求的开头都不同，Prompt 缓存无法命中。建议移除这些变量，改用「追加当前时间」——它把时间放在请求末尾，不影响前缀。';
  }

  @override
  String get assistantEditPromptTimeVarDialogRemove => '去移除';

  @override
  String get assistantEditPromptTimeVarDialogKeep => '仍然开启';

  @override
  String get codeBlockPreviewButton => '预览';

  @override
  String get codeBlockSaveAsButton => '另存为文件';

  @override
  String get codeBlockCollapseButton => '折叠';

  @override
  String get codeBlockExpandButton => '展开';

  @override
  String get codeBlockDefaultFileNameStem => '代码';

  @override
  String get markdownTableLabel => '表格';

  @override
  String get markdownTableExportCsvTooltip => '导出 CSV';

  @override
  String get markdownTableSaveImageTooltip => '保存到相册';

  @override
  String get markdownTableDefaultFileNameStem => '表格';

  @override
  String get markdownTableCopiedCsvSnackbar => '已复制 CSV，长按复制可复制为图片';

  @override
  String get markdownTableCopiedMarkdownSnackbar => '已复制表格';

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
  String get backupPageRestartContent => '导入成功。重启 Kelivo 后将安全应用。';

  @override
  String backupPageRestartContentWithSkipped(int count) {
    return '导入已完成，但已跳过 $count 个消息顺序非法的会话。重启 Kelivo 后将安全应用已导入的数据。';
  }

  @override
  String get restartAppFailedMessage => 'Kelivo 无法自动重启，请完全关闭后重新打开。';

  @override
  String get backupRestoreRolledBackTitle => '恢复已回滚';

  @override
  String get backupRestoreRolledBackContent => '恢复未能完成。Kelivo 已验证并保留原有数据。';

  @override
  String get backupRestoreFailureTitle => '恢复需要处理';

  @override
  String get backupRestoreFailureContent =>
      'Kelivo 无法验证完整的原有或新数据，因此未打开聊天数据。请关闭 Kelivo 后重试；若问题反复出现，请保留诊断码以便支持人员排查。';

  @override
  String get backupRestoreBusinessLeaseUnavailableTitle => 'Kelivo 已在运行';

  @override
  String get backupRestoreBusinessLeaseUnavailableContent =>
      'Kelivo 的数据仍被另一个应用进程占用。请关闭其他 Kelivo 窗口后重新启动；当前进程尚未打开聊天数据。';

  @override
  String get backupRestoreFailureRestartButton => '重启 Kelivo';

  @override
  String get backupRestoreFailureCopyButton => '复制诊断码';

  @override
  String get backupRestoreFailureCopied => '已复制诊断码';

  @override
  String backupRestoreFailureDiagnostic(String code) {
    return '诊断码：$code';
  }

  @override
  String get startupRecoveryMoreOptions => '更多恢复选项';

  @override
  String get startupRecoveryRepairButton => '修复并重启';

  @override
  String get startupRecoveryExportButton => '导出我的数据副本';

  @override
  String get startupRecoveryResetButton => '重置数据';

  @override
  String get startupRecoveryBusy => '处理中…';

  @override
  String get startupRecoveryExportSucceeded => '已保存一份数据副本。';

  @override
  String get startupRecoveryExportFailed => '无法导出数据副本。';

  @override
  String get startupRecoveryRepairFailed => '修复未能解决问题。请先导出数据副本，然后重置。';

  @override
  String get startupRecoveryResetFailed => '重置失败。请彻底关闭 Kelivo 后重新打开。';

  @override
  String get startupRecoveryResetDialogTitle => '重置全部数据？';

  @override
  String get startupRecoveryResetDialogContent =>
      '这将永久删除本设备上 Kelivo 的数据库并重新开始。如果之后可能还需要这些数据，请先导出一份副本。此操作无法撤销。';

  @override
  String get startupRecoveryResetDialogConfirm => '重置并重启';

  @override
  String get startupRecoveryResetDialogCancel => '取消';

  @override
  String get startupDatabaseUpdateRequiredTitle => '请更新 Kelivo 以继续';

  @override
  String get startupDatabaseUpdateRequiredContent =>
      '本设备上的聊天数据库由更新版本的 Kelivo 创建，当前版本无法打开。数据未被改动。请安装最新版 Kelivo 后重新打开。';

  @override
  String backupPageRestoreFailedMessage(String error) {
    return '恢复失败：$error';
  }

  @override
  String backupPageExportFailedMessage(String error) {
    return '导出失败：$error';
  }

  @override
  String get backupPageOK => '好的';

  @override
  String get backupPageCancel => '取消';

  @override
  String get backupPageSelectImportMode => '选择导入模式';

  @override
  String get backupPageSelectImportModeDescription =>
      '请选择恢复方式。聊天和文件开关决定本次恢复的组件。';

  @override
  String get backupPageOverwriteMode => '完全覆盖';

  @override
  String get backupPageOverwriteModeDescription => '仅替换已选组件；保留未选组件及无关本地设置';

  @override
  String get backupPageMergeMode => '合并';

  @override
  String get backupPageMergeModeDescription =>
      '保留本地数据并加入备份数据；相同会话会跳过，冲突会话会重新分配 ID。';

  @override
  String get backupPageRestore => '恢复';

  @override
  String get backupPageBackupUploaded => '已上传备份';

  @override
  String get backupPageBackup => '立即备份';

  @override
  String get backupPageExporting => '正在导出...';

  @override
  String get backupProgressCancel => '取消';

  @override
  String get backupProgressCancelled => '已取消';

  @override
  String get backupProgressPreparing => '准备中';

  @override
  String get backupProgressSnapshotting => '正在创建数据库快照';

  @override
  String get backupProgressPacking => '正在打包';

  @override
  String get backupProgressVerifying => '正在校验';

  @override
  String get backupProgressUploading => '正在上传';

  @override
  String get backupProgressDownloading => '正在下载';

  @override
  String get backupProgressExtracting => '正在解压';

  @override
  String get backupProgressValidating => '正在验证';

  @override
  String get backupProgressReadingSettings => '正在读取设置';

  @override
  String get backupProgressStaging => '正在暂存';

  @override
  String get backupProgressCommitting => '正在提交';

  @override
  String get backupProgressImportingSessions => '正在导入会话';

  @override
  String get backupProgressImportingMessages => '正在导入消息';

  @override
  String get backupProgressMaterializingFiles => '正在写入文件';

  @override
  String get backupProgressListingRemote => '正在列出远端备份';

  @override
  String get backupProgressFinalizing => '正在完成';

  @override
  String backupProgressBytes(String done, String total) {
    return '$done / $total';
  }

  @override
  String backupProgressItems(String done, String total) {
    return '$done / $total';
  }

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
  String get backupPageDeleteConfirmTitle => '确认删除';

  @override
  String backupPageDeleteConfirmContent(Object name) {
    return '确定要删除远程备份“$name”吗？此操作不可撤销。';
  }

  @override
  String get backupPageBackupManagement => '备份管理';

  @override
  String get backupPageWebDavBackup => 'WebDAV 备份';

  @override
  String get backupPageWebDavServerSettings => 'WebDAV 服务器设置';

  @override
  String get backupPageS3Backup => 'S3 备份';

  @override
  String get backupPageS3ServerSettings => 'S3 服务器设置';

  @override
  String get backupPageS3Endpoint => '端点';

  @override
  String get backupPageS3Region => '区域';

  @override
  String get backupPageS3Bucket => 'Bucket';

  @override
  String get backupPageS3AccessKeyId => '访问密钥 ID';

  @override
  String get backupPageS3SecretAccessKey => '秘密访问密钥';

  @override
  String get backupPageS3SessionToken => 'Session Token（可选）';

  @override
  String get backupPageS3Prefix => '前缀（目录）';

  @override
  String get backupPageS3PathStyle => '路径风格（Path-style）';

  @override
  String get backupPageUserAgent => 'User-Agent';

  @override
  String get backupPageUserAgentHint => '可选';

  @override
  String get backupPageSave => '保存';

  @override
  String get backupPageBackupNow => '立即备份';

  @override
  String get backupPageLocalBackup => '本地备份';

  @override
  String get backupPageImportFromCherryStudio => '从 Cherry Studio 导入';

  @override
  String backupPageCherryStudioUnsupportedBackupVersion(String version) {
    return '此备份使用 Cherry Studio 格式版本 $version，Kelivo 目前尚无法导入。请改用 Cherry Studio v1 导出备份，或等待后续版本支持 Cherry Studio v2。';
  }

  @override
  String get backupPageImportFromChatbox => '从 Chatbox 导入';

  @override
  String get backupReminderSectionTitle => '备份提醒';

  @override
  String get backupReminderEnableTitle => '定期提醒我备份';

  @override
  String get backupReminderFrequencyTitle => '提醒频率';

  @override
  String get backupReminderTimeTitle => '提醒时间';

  @override
  String get backupReminderTimeInputHint => 'HH:mm';

  @override
  String get backupReminderTimeInvalid => '请输入 00:00 到 23:59 之间的时间。';

  @override
  String get backupReminderLastBackupTitle => '上次备份';

  @override
  String get backupReminderNextReminderTitle => '下次提醒';

  @override
  String get backupReminderNever => '从未';

  @override
  String get backupReminderDisabled => '关闭';

  @override
  String get backupReminderDueNow => '现在已到期';

  @override
  String get backupReminderEveryDay => '每天';

  @override
  String get backupReminderEveryThreeDays => '每 3 天';

  @override
  String get backupReminderEveryWeek => '每周';

  @override
  String get backupReminderEveryFourteenDays => '每 14 天';

  @override
  String get backupReminderEveryMonth => '每月';

  @override
  String backupReminderCustomDays(int days) {
    return '每 $days 天';
  }

  @override
  String get backupReminderCustomOption => '自定义...';

  @override
  String get backupReminderCustomDialogTitle => '自定义频率';

  @override
  String get backupReminderCustomDialogDescription => '输入两次备份提醒之间间隔多少天。';

  @override
  String get backupReminderCustomDaysLabel => '天数';

  @override
  String get backupReminderCustomDaysInvalid => '请输入 1 到 365 之间的数字。';

  @override
  String get backupReminderSidebarTitle => '备份提醒';

  @override
  String get backupReminderSidebarSubtitle => '已经到你设定的备份周期了。';

  @override
  String get backupReminderSidebarAction => '去备份';

  @override
  String get backupReminderSnoozeTooltip => '稍后提醒';

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
  String get userMessageEditSaveOnly => '仅保存';

  @override
  String get userMessageEditUnsupportedSnackbar => '该内容不支持编辑';

  @override
  String get userMessageEditOverwriteTitle => '提示';

  @override
  String get userMessageEditOverwriteContent => '修改将覆盖输入框已有内容，是否覆盖？';

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
  String get compressContext => '压缩上下文';

  @override
  String get compressContextDesc => '总结对话并开始新聊天';

  @override
  String get clearContextDesc => '标记上下文分界点';

  @override
  String get contextManagement => '上下文管理';

  @override
  String get compressingContext => '正在压缩上下文...';

  @override
  String get compressContextFailed => '压缩上下文失败';

  @override
  String get compressContextNoMessages => '没有可压缩的消息';

  @override
  String get compressContextNoConversation => '没有可压缩的会话';

  @override
  String get compressContextNoModel => '未配置压缩模型';

  @override
  String get compressContextEmptySummary => '压缩返回了空摘要';

  @override
  String get compressContextOptionsTitle => '压缩上下文';

  @override
  String get compressContextOptionsDesc => '选择发送给压缩模型的当前聊天范围。';

  @override
  String get compressContextKeepStart => '最开始';

  @override
  String get compressContextKeepRecent => '最近';

  @override
  String get compressContextUnlimited => '无限制';

  @override
  String get compressContextMaxCharsLabel => '字符数';

  @override
  String get compressContextInvalidLimit => '请输入大于 0 的字符数';

  @override
  String get compressContextStartButton => '开始压缩';

  @override
  String get compressContextModelLabel => '压缩模型';

  @override
  String get compressContextModelUnset => '选择模型';

  @override
  String get compressContextKeepRecentMessages => '保留N条';

  @override
  String get compressContextKeepCountLabel => '保留最近条数';

  @override
  String get compressContextKeepAllMessages => '保留条数覆盖全部消息，无内容可压缩';

  @override
  String compressContextEstimatePreview(
    int summarized,
    int kept,
    int minTokens,
    int maxTokens,
    int totalTokens,
  ) {
    return '总结 $summarized 字符，原样保留 $kept 字符 → 压缩后约 $minTokens–$maxTokens tokens（原文约 $totalTokens tokens）';
  }

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
  String get messageMoreSheetSelectMessages => '选择消息';

  @override
  String get messageMoreSheetCreateBranch => '创建分支';

  @override
  String get messageMoreSheetDelete => '删除本版本';

  @override
  String get messageMoreSheetDeleteAllVersions => '删除全部版本';

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
  String get reasoningBudgetSheetXhigh => '极限推理';

  @override
  String get reasoningBudgetSheetMax => '全力推理';

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
  String get reasoningBudgetSheetXhighSubtitle => '使用最大推理深度，适合最复杂的问题';

  @override
  String get reasoningBudgetSheetCustomLabel => '自定义推理预算';

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
  String get chatMessageWidgetAttachmentUnavailable => '附件不可用';

  @override
  String chatMessageWidgetCitationsTitle(int count) {
    return '引用（共$count条）';
  }

  @override
  String get chatMessageWidgetSearchResultsTitle => '搜索结果';

  @override
  String get chatMessageWidgetCitationSourcesTitle => '引用来源';

  @override
  String get chatMessageWidgetRegenerateTooltip => '重新生成';

  @override
  String get chatMessageWidgetRegenerateConfirmTitle => '确认重新生成';

  @override
  String get chatMessageWidgetRegenerateConfirmContent =>
      '重新生成只会更新当前消息，不会删除下面的消息。确定要继续吗？';

  @override
  String get chatMessageWidgetRegenerateConfirmDeleteTrailingContent =>
      '重新生成将会删除此消息下面的所有消息，且无法撤销。确定要继续吗？';

  @override
  String get chatMessageWidgetRegenerateConfirmCancel => '取消';

  @override
  String get chatMessageWidgetRegenerateConfirmOk => '重新生成';

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
  String chatMessageWidgetWebSearch(String query) {
    return '联网检索: $query';
  }

  @override
  String get chatMessageWidgetBuiltinSearch => '模型内置搜索';

  @override
  String get chatMessageWidgetReadClipboard => '读取剪切板';

  @override
  String get chatMessageWidgetWriteClipboard => '写入剪切板';

  @override
  String get chatMessageWidgetSpeakingTitle => '正在朗读:';

  @override
  String chatMessageWidgetSpeakText(String text) {
    return '正在朗读: $text';
  }

  @override
  String get chatMessageWidgetMemoryRead => '读取记忆';

  @override
  String get chatMessageWidgetMemoryUpdate => '更新记忆';

  @override
  String get chatMessageWidgetMemorySearchProfile => '检索记忆';

  @override
  String get chatMessageWidgetMemoryEdit => '编辑记忆';

  @override
  String get chatMessageWidgetMemoryDelete => '删除记忆';

  @override
  String get chatMessageWidgetUpdateUserProfile => '更新用户画像';

  @override
  String get chatMessageWidgetChatSearch => '搜索历史对话';

  @override
  String get chatMessageWidgetCreateMemory => '创建记忆';

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
  String get chatMessageWidgetImages => '图片';

  @override
  String chatMessageWidgetCitationsCount(int count) {
    return '$count个引用';
  }

  @override
  String chatSelectionSelectedCountTitle(int count) {
    return '已选择$count条消息';
  }

  @override
  String get chatSelectionExportTxt => 'TXT';

  @override
  String get chatSelectionExportMd => 'MD';

  @override
  String get chatSelectionExportImage => '图片';

  @override
  String get chatSelectionThinkingTools => '思考工具';

  @override
  String get chatSelectionThinkingContent => '思考内容';

  @override
  String get chatSelectionDeleteSelected => '删除所选';

  @override
  String get chatSelectionSelectMessagesToDelete => '请选择要删除的消息';

  @override
  String chatSelectionDeleteSelectedConfirm(int count) {
    return '确定要删除已选择的$count个版本吗？此操作不可撤销。';
  }

  @override
  String chatSelectionDeleteSelectedAllVersionsConfirm(int count) {
    return '确定要删除已选择$count条消息的全部版本吗？此操作不可撤销。';
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
  String get displaySettingsPageEnableAssistantMarkdownTitle =>
      '助手消息 Markdown 渲染';

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
  String get messageExportThinkingContentLabel => '思考内容';

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
  String get sideDrawerMenuCopy => '复制';

  @override
  String get sideDrawerMenuMoveTo => '移动到';

  @override
  String get sideDrawerMenuDelete => '删除';

  @override
  String get sideDrawerMenuSelect => '多选';

  @override
  String sideDrawerSelectionTitle(int count) {
    return '已选 $count 项';
  }

  @override
  String get sideDrawerSelectionSelectAll => '全选';

  @override
  String get sideDrawerSelectionDeselectAll => '取消全选';

  @override
  String get sideDrawerSelectionPin => '置顶';

  @override
  String get sideDrawerSelectionUnpin => '取消置顶';

  @override
  String get sideDrawerSelectionMove => '移动';

  @override
  String get sideDrawerSelectionDelete => '删除';

  @override
  String get sideDrawerSelectionDeleteConfirmTitle => '删除话题';

  @override
  String sideDrawerSelectionDeleteConfirmContent(int count) {
    return '确定删除 $count 个话题？';
  }

  @override
  String sideDrawerDeleteSelectedSnackbar(int count) {
    return '已删除 $count 个话题';
  }

  @override
  String sideDrawerMoveSelectedSnackbar(int count) {
    return '已移动 $count 个话题';
  }

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
  String get sideDrawerSearchHint => '搜索当前助手';

  @override
  String get sideDrawerSearchAssistantsHint => '搜索助手';

  @override
  String get sideDrawerTopicSearchModeLabel => '话题模式';

  @override
  String get sideDrawerGlobalSearchModeLabel => '全局模式';

  @override
  String get sideDrawerSearchModeSwipeToTopicHint => '左/右滑搜索栏切换到话题搜索';

  @override
  String get sideDrawerSearchModeSwipeToGlobalHint => '左/右滑搜索栏切换到全局搜索';

  @override
  String get sideDrawerGlobalSearchHint => '搜索全部会话';

  @override
  String get sideDrawerGlobalSearchEmptyHint => '在标题和消息中全局搜索';

  @override
  String get sideDrawerGlobalSearchNoResults => '没有匹配的会话';

  @override
  String sideDrawerGlobalSearchResultCount(int count) {
    return '共 $count 条结果';
  }

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
  String get providerAvatarChooseBuiltInIcon => '选择内置图标';

  @override
  String get providerAvatarIconDialogTitle => '选择内置图标';

  @override
  String get providerAvatarIconSearchHint => '搜索图标';

  @override
  String get providerAvatarIconNoResults => '未找到图标';

  @override
  String get providerAvatarInputLobehubIcon => '输入 LobeHub 图标';

  @override
  String get providerAvatarChooseLobehubIcon => '输入 LobeHub 图标';

  @override
  String get providerAvatarLobehubDialogTitle => '输入 LobeHub 图标';

  @override
  String get providerAvatarLobehubDialogHint => '输入 LobeHub 图标名，如 openai';

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
  String get chatInputBarVoiceInputTooltip => '语音输入';

  @override
  String get chatInputBarVoiceCancelTooltip => '取消录音';

  @override
  String get chatInputBarVoiceStopTooltip => '停止并转为文字';

  @override
  String get chatInputBarVoiceSendTooltip => '转文字并发送';

  @override
  String get chatInputBarVoiceTranscribing => '正在识别…';

  @override
  String get chatInputBarImageProcessing => '正在处理图片';

  @override
  String get chatInputBarImageMode => '绘图模式';

  @override
  String get chatInputBarDisableImageModeTooltip => '关闭绘图模式';

  @override
  String get chatInputBarQueuedPending => '排队中';

  @override
  String get chatInputBarQueuedCancel => '取消排队';

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
  String get mcpPageStatusAuthorizationRequired => '需要授权';

  @override
  String get mcpPageStatusAuthorizing => '授权中…';

  @override
  String get mcpPageStatusDisabled => '已禁用';

  @override
  String get mcpPageOAuthRequired => '需要 OAuth 登录';

  @override
  String get mcpPageOAuthSignIn => 'OAuth 登录';

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
  String get titleModelThinkingTitle => '是否开启思考';

  @override
  String get defaultModelPageSummaryModelTitle => '摘要模型';

  @override
  String get defaultModelPageSummaryModelSubtitle => '用于生成对话摘要的模型，推荐使用快速且便宜的模型';

  @override
  String get defaultModelPageSuggestionModelTitle => '聊天建议模型';

  @override
  String get defaultModelPageSuggestionModelSubtitle =>
      '用于在助手回复后生成继续对话的建议气泡。选择模型后才会启用。';

  @override
  String get assistantEditRecentChatsSummaryFrequencyTitle => '摘要更新频率';

  @override
  String get assistantEditRecentChatsSummaryFrequencyDescription =>
      '累计达到所选条数的新消息后，会更新历史聊天摘要。';

  @override
  String assistantEditRecentChatsSummaryFrequencyOption(int count) {
    return '每 $count 条';
  }

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomButton => '自定义';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomTitle => '自定义摘要频率';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomDescription =>
      '输入累计多少条新消息后再更新历史聊天摘要。';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomLabel => '新消息条数';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomHint =>
      '请输入大于 0 的整数';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomInvalid =>
      '请输入大于 0 的整数';

  @override
  String get defaultModelPageTranslateModelTitle => '翻译模型';

  @override
  String get defaultModelPageTranslateModelSubtitle =>
      '用于翻译消息内容的模型，推荐使用快速且准确的模型';

  @override
  String get defaultModelPageOcrModelTitle => 'OCR 模型';

  @override
  String backgroundTaskFailed(String task, String error) {
    return '$task失败：$error';
  }

  @override
  String get defaultModelPageOcrModelSubtitle => '用于对图片执行文字识别的模型';

  @override
  String get defaultModelPageOcrModelRequiresImageInput =>
      '请选择标记为支持图片输入的模型用于 OCR';

  @override
  String get defaultModelPagePromptLabel => '提示词';

  @override
  String get defaultModelPageTitlePromptHint => '输入用于标题总结的提示词模板';

  @override
  String get defaultModelPageSummaryPromptHint => '输入用于生成摘要的提示词模板';

  @override
  String get defaultModelPageSuggestionPromptHint => '输入用于生成聊天建议的提示词模板';

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
  String defaultModelPageSuggestionVars(String contentVar, String localeVar) {
    return '变量：对话内容：$contentVar，语言：$localeVar';
  }

  @override
  String get defaultModelPageCompressModelTitle => '压缩模型';

  @override
  String get defaultModelPageCompressModelSubtitle => '用于压缩对话上下文的模型，推荐使用快速模型';

  @override
  String get defaultModelPageCompressPromptHint => '输入用于上下文压缩的提示词模板';

  @override
  String defaultModelPageCompressVars(String contentVar, String localeVar) {
    return '变量：对话内容：$contentVar，语言：$localeVar';
  }

  @override
  String defaultModelPageTranslateVars(String sourceVar, String targetVar) {
    return '变量：原始文本：$sourceVar，目标语言：$targetVar';
  }

  @override
  String get defaultModelPageUseCurrentModel => '使用当前对话模型';

  @override
  String get defaultModelPageNotEnabled => '未启用';

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
  String get modelDetailSheetSaveFailedMessage => '保存失败，请重试';

  @override
  String get modelDetailSheetAddBody => '添加 Body';

  @override
  String get modelDetailSheetBuiltinToolsDescription => '内置工具取决于供应商和 API 模式。';

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
  String get modelDetailSheetOpenrouterWebFetchTool => '网页抓取';

  @override
  String get modelDetailSheetOpenrouterWebFetchToolDescription =>
      '启用 OpenRouter 网页抓取服务端工具';

  @override
  String get modelDetailSheetOpenrouterShellTool => 'Shell';

  @override
  String get modelDetailSheetOpenrouterShellToolDescription =>
      '在托管的隔离沙箱中运行 Shell 命令';

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
  String get providerDetailPageCustomRequestTitle => '自定义请求';

  @override
  String get providerDetailPageCustomRequestDescription =>
      '应用于此供应商的所有模型。模型配置优先于此处，此处配置优先于助手配置。';

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
  String get providerDetailPageClaudePromptCachingTitle =>
      'Claude Prompt Caching';

  @override
  String get providerDetailPageClaudePromptCachingHelp =>
      '通过 Claude 官方或 OpenRouter 调用 Claude 时附加 cache_control。';

  @override
  String get providerDetailPageClaudePromptCachingTtlTitle => '缓存 TTL';

  @override
  String get providerDetailPageClaudePromptCachingTtlHelp =>
      '5 分钟为默认值。1 小时写入成本更高，但长对话中可减少重复重建缓存。';

  @override
  String get providerDetailPageClaudePromptCachingTtl5m => '5 分钟';

  @override
  String get providerDetailPageClaudePromptCachingTtl1h => '1 小时';

  @override
  String get providerDetailPageBalanceTitle => '账户余额';

  @override
  String get providerDetailPageBalanceInfo => '获取账户余额';

  @override
  String get providerDetailPageBalanceApiPathLabel => '余额 API 路径';

  @override
  String get providerDetailPageBalanceResultPathLabel => '结果 JSON 路径';

  @override
  String get providerDetailPageBalanceQueryButton => '查询余额';

  @override
  String get providerDetailPageBalanceQuerying => '查询中...';

  @override
  String get providerDetailPageBalanceResetDefaultsButton => '重置';

  @override
  String get providerDetailPageBalanceResetDefaultsTooltip => '重置余额设置';

  @override
  String providerDetailPageBalanceResult(String value) {
    return '余额：$value';
  }

  @override
  String providerDetailPageBalanceError(String message) {
    return '余额查询失败：$message';
  }

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
  String get providerDetailPageImportJsonReadFailedMessage => '读取文件失败';

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
  String get providersPageSearchHint => '搜索供应商或分组';

  @override
  String get providersPageProviderAddedSnackbar => '已添加供应商';

  @override
  String get providerGroupsGroupLabel => '分组';

  @override
  String get providerGroupsOther => '其他';

  @override
  String get providerGroupsOtherUngroupedOption => '其他（未分组）';

  @override
  String get providerGroupsPickerTitle => '选择分组';

  @override
  String get providerGroupsManageTitle => '分组管理';

  @override
  String get providerGroupsManageAction => '管理分组';

  @override
  String get providerGroupsCreateNewGroupAction => '新建分组…';

  @override
  String get providerGroupsCreateDialogTitle => '新建分组';

  @override
  String get providerGroupsNameHint => '输入分组名称';

  @override
  String get providerGroupsCreateDialogCancel => '取消';

  @override
  String get providerGroupsCreateDialogOk => '创建';

  @override
  String get providerGroupsCreateFailedToast => '创建分组失败';

  @override
  String get providerGroupsDeleteConfirmTitle => '删除分组';

  @override
  String get providerGroupsDeleteConfirmContent => '该组内供应商将移动到「其他」';

  @override
  String get providerGroupsDeleteConfirmCancel => '取消';

  @override
  String get providerGroupsDeleteConfirmOk => '删除';

  @override
  String get providerGroupsDeletedToast => '已删除分组';

  @override
  String get providerGroupsEmptyState => '暂无分组';

  @override
  String get providerGroupsExpandToMoveToast => '请先展开分组';

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
  String get miniMapScrollToBottomTooltip => '滚动到底部';

  @override
  String miniMapSearchMatchCount(int count) {
    return '$count 处';
  }

  @override
  String get miniMapSearchNoResults => '没有匹配的消息';

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
  String get searchServicesFieldCustomUrlOptional => '自定义 URL（可选）';

  @override
  String get searchServicesDialogApiKey => 'API Key';

  @override
  String get searchServicesDialogModel => '模型';

  @override
  String get searchServicesDialogSystemPrompt => '系统提示词';

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
  String get searchServiceEditorProviderTypeTitle => '搜索提供商';

  @override
  String get searchServiceEditorConfigurationTitle => '服务配置';

  @override
  String get searchServiceEditorNoConfiguration => '此提供商无需额外配置。';

  @override
  String get searchServiceEditorMultiKeyTitle => '多 Key 轮询';

  @override
  String get searchServiceEditorMultiKeyNone => '未配置';

  @override
  String get searchApiKeysPageDescription =>
      '列表中的 Key 按顺序轮询使用，第一个为主 Key；不查额度，以防触发服务商风控。';

  @override
  String get searchApiKeysPagePrimaryBadge => '主';

  @override
  String get searchApiKeysPageBatchHint => '可一次粘贴多个 Key：每行一个，或用逗号分隔';

  @override
  String searchApiKeysPageBatchResult(String added, String skipped) {
    return '已添加 $added 个，跳过 $skipped 个重复';
  }

  @override
  String get searchApiKeysPageAdd => '添加';

  @override
  String get searchApiKeysPageEmpty => '尚未配置任何 Key。';

  @override
  String searchServiceEditorMultiKeyCount(String count) {
    return '共 $count 个 Key';
  }

  @override
  String get searchServiceEditorUsageTitle => '账户用量';

  @override
  String get searchServiceEditorUsageNotQueried => '尚未查询用量。';

  @override
  String get searchServiceEditorUsageQuery => '查询用量';

  @override
  String get searchServiceEditorUsageQuerying => '查询中…';

  @override
  String searchServiceEditorUsageRemaining(String remaining) {
    return '剩余 $remaining 额度';
  }

  @override
  String searchServiceEditorUsageBalance(String balance) {
    return '余额 $balance';
  }

  @override
  String searchServiceEditorUsageUsed(String used, String limit) {
    return '已使用 $used / $limit 额度';
  }

  @override
  String searchServiceEditorUsageFailed(String message) {
    return '用量查询失败：$message';
  }

  @override
  String get searchServiceEditorTestTitle => '测试搜索';

  @override
  String get searchServiceEditorTestQueryHint => '输入测试关键词';

  @override
  String get searchServiceEditorTestRun => '运行测试搜索';

  @override
  String get searchServiceEditorTestRunning => '搜索中…';

  @override
  String get searchServiceEditorTestNoResults => '提供商未返回任何结果。';

  @override
  String searchServiceEditorTestFailed(String message) {
    return '搜索失败：$message';
  }

  @override
  String get searchServiceEditorResultOpenTooltip => '打开结果';

  @override
  String get searchServiceEditorDeleteTooltip => '删除搜索服务';

  @override
  String get searchServiceEditorDeleteTitle => '删除搜索服务？';

  @override
  String searchServiceEditorDeleteMessage(String provider) {
    return '确定删除 $provider 吗？此操作无法撤销。';
  }

  @override
  String get searchServiceEditorDeleteConfirm => '删除';

  @override
  String get searchServiceEditorDiscardTitle => '放弃更改？';

  @override
  String get searchServiceEditorDiscardMessage => '尚未保存的搜索服务设置将会丢失。';

  @override
  String get searchServiceEditorKeepEditing => '继续编辑';

  @override
  String get searchServiceEditorDiscard => '放弃';

  @override
  String get searchSettingsSheetTitle => '搜索设置';

  @override
  String get searchSettingsSheetBuiltinSearchTitle => '模型内置搜索';

  @override
  String get searchSettingsSheetBuiltinSearchDescription => '是否启用模型内置的搜索功能';

  @override
  String get searchSettingsSheetClaudeDynamicSearchTitle => '模型内置搜索(新)';

  @override
  String get searchSettingsSheetClaudeDynamicSearchDescription =>
      '在支持的 Claude 官方模型上使用 `web_search_20260209`，支持动态过滤能力。';

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
  String get aboutPageKelivoSearchUnlocked => '有扇没有名字的门开了一条缝。去设置里找找看。';

  @override
  String get aboutPageKelivoSearchAlreadyUnlocked => '这扇门你已经推开过了。';

  @override
  String get aboutPageAppName => 'Kelivo';

  @override
  String get aboutPageAppDescription => '开源 AI 助手';

  @override
  String get aboutPageNoQQGroup => '暂无QQ群';

  @override
  String get aboutPageVersion => '版本';

  @override
  String aboutPageVersionDetail(String version, String buildNumber) {
    return '$version / $buildNumber';
  }

  @override
  String get aboutPageSystem => '系统';

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
    return '其他（$os）';
  }

  @override
  String get aboutPageWebsite => '官网';

  @override
  String get aboutPageGithub => 'GitHub';

  @override
  String get aboutPageLicense => '许可证';

  @override
  String get aboutPageJoinQQGroup => '加入QQ群';

  @override
  String get aboutPageQQGroupOne => 'Kelivo 一群';

  @override
  String get aboutPageQQGroupTwo => 'Kelivo 二群';

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
  String get displaySettingsPageShowUserNameTitle => '显示用户名称';

  @override
  String get displaySettingsPageShowUserTimestampTitle => '显示用户时间戳';

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
  String get displaySettingsPageShowModelNameTitle => '显示模型名称';

  @override
  String get displaySettingsPageShowModelTimestampTitle => '显示模型时间戳';

  @override
  String get displaySettingsPageShowProviderInChatMessageTitle => '模型名称后显示供应商';

  @override
  String get displaySettingsPageShowProviderInChatMessageSubtitle =>
      '在聊天消息的模型名称后面显示供应商名称（如 模型 | 供应商）';

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
  String get displaySettingsPageCollapseThinkingStepsTitle => '折叠思考步骤';

  @override
  String get displaySettingsPageCollapseThinkingStepsSubtitle =>
      '默认只显示最新步骤，展开后查看全部';

  @override
  String get displaySettingsPageShowToolResultSummaryTitle => '显示工具结果摘要';

  @override
  String get displaySettingsPageInsertSuggestionOnlyTitle => '点击建议时仅填入输入框';

  @override
  String get displaySettingsPageShowToolResultSummarySubtitle =>
      '在工具步骤下方显示摘要文本';

  @override
  String get displaySettingsPageRegenerateDeleteTrailingMessagesTitle =>
      '重新生成时删除下面的消息';

  @override
  String get displaySettingsPageShowRegenerateConfirmDialogTitle => '重新生成前弹出确认';

  @override
  String get displaySettingsPageForkKeepMessageVersionsTitle => '创建分支时保留消息版本';

  @override
  String chainOfThoughtExpandSteps(Object count) {
    return '展开更多 $count 步';
  }

  @override
  String get chainOfThoughtCollapse => '收起';

  @override
  String get displaySettingsPageShowChatListDateTitle => '显示对话列表日期';

  @override
  String get displaySettingsPageShowChatListDateSubtitle => '在左侧对话列表中显示日期分组标签';

  @override
  String get displaySettingsPageEnableImageCropperTitle => '启用图片裁剪';

  @override
  String get displaySettingsPageEnableImageCropperSubtitle =>
      '从相册或相机选择图片后，允许裁剪图片';

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
  String get displaySettingsPageKeepScreenOnDuringGenerationTitle =>
      '生成时保持屏幕常亮';

  @override
  String get displaySettingsPageKeepScreenOnDuringGenerationSubtitle =>
      '防止生成中途锁屏导致中断，会增加耗电';

  @override
  String get displaySettingsPageMessageNavButtonsTitle => '消息导航按钮';

  @override
  String get displaySettingsPageMessageNavButtonsSubtitle => '选择快速跳转按钮的显示时机';

  @override
  String get displaySettingsPageMessageNavButtonsModeAlways => '始终显示';

  @override
  String get displaySettingsPageMessageNavButtonsModeScroll => '滚动时显示';

  @override
  String get displaySettingsPageMessageNavButtonsModeHover => '鼠标悬停时显示';

  @override
  String get displaySettingsPageMessageNavButtonsModeScrollAndHover =>
      '滚动和鼠标悬停时显示';

  @override
  String get displaySettingsPageMessageNavButtonsModeNever => '永不显示';

  @override
  String get displaySettingsPageUseNewAssistantAvatarUxTitle => '聊天标题栏显示助手头像';

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
  String get displaySettingsPageEnterToSendTitle => '回车键发送消息';

  @override
  String get displaySettingsPageLongPasteAsFileTitle => '超长粘贴转为文件';

  @override
  String get displaySettingsPageLongPasteAsFileThresholdTitle => '转换阈值';

  @override
  String get displaySettingsPageLongPasteAsFileThresholdUnit => '字符';

  @override
  String get displaySettingsPageSendShortcutTitle => '发送快捷键';

  @override
  String get displaySettingsPageSendShortcutEnter => 'Enter';

  @override
  String get displaySettingsPageSendShortcutCtrlEnter => 'Ctrl/Cmd + Enter';

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
  String get displaySettingsPageChatInputBackgroundOpacityTitle => '输入框背景透明度';

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
  String get themeSettingsPageCustomPaletteName => '自定义';

  @override
  String get themeSettingsPageCustomColorReset => '重置';

  @override
  String get themeSettingsPageCustomThemesSection => '自定义主题';

  @override
  String get customThemeNewTheme => '新建主题';

  @override
  String get customThemeEditTheme => '编辑主题';

  @override
  String get customThemeImportTheme => '导入主题';

  @override
  String get customThemeNameLabel => '主题名称';

  @override
  String get customThemePrimaryColor => '主色';

  @override
  String get customThemeSecondaryColor => '辅色';

  @override
  String get customThemeTertiaryColor => '第三色';

  @override
  String get customThemeColorAuto => '自动';

  @override
  String get customThemeSave => '保存';

  @override
  String get customThemeCancel => '取消';

  @override
  String get customThemeDelete => '删除';

  @override
  String get customThemeDeleteConfirm => '删除该主题？';

  @override
  String get customThemeCopied => '主题 JSON 已复制到剪贴板';

  @override
  String get customThemeCopyAction => '复制';

  @override
  String get customThemeImportHint => '在此粘贴主题 JSON';

  @override
  String get customThemeImportInvalid => '无效的主题 JSON';

  @override
  String get customThemeHexLabel => '十六进制';

  @override
  String get ttsServicesPageBackButton => '返回';

  @override
  String get ttsServicesPageTitle => '语音服务';

  @override
  String get ttsServicesSectionTitle => '文字转语音';

  @override
  String get ttsServicesPageSettingsTooltip => 'TTS 设置';

  @override
  String get ttsServicesPageAddTooltip => '新增';

  @override
  String get asrServicesSectionTitle => '语音识别';

  @override
  String get asrServicesSectionDescription => '使用本地、系统或云端服务将语音转换为文字。';

  @override
  String get asrServicesAddTooltip => '添加语音识别服务';

  @override
  String get asrServicesEmptyTitle => '尚未添加语音识别服务';

  @override
  String get asrServicesEmptySubtitle => '添加后，聊天输入框才会显示麦克风。';

  @override
  String get asrServicesOnDeviceGroup => '设备端';

  @override
  String get asrServicesCloudGroup => '云端';

  @override
  String get asrServicesSystemTitle => '系统';

  @override
  String get asrServicesSystemSubtitle => '使用设备内置能力';

  @override
  String get asrServicesLocalTitle => '本地模型';

  @override
  String get asrServicesLocalSubtitle => '下载后在设备上离线运行';

  @override
  String get asrServicesOpenAiTitle => 'OpenAI Realtime';

  @override
  String get asrServicesOpenAiSubtitle => '低延迟流式转写';

  @override
  String get asrServicesDashScopeTitle => 'DashScope';

  @override
  String get asrServicesDashScopeSubtitle => 'Qwen 实时转写';

  @override
  String get asrServicesVolcengineTitle => '火山引擎';

  @override
  String get asrServicesVolcengineSubtitle => '豆包语音流式转写';

  @override
  String get asrServicesMimoTitle => 'MiMo';

  @override
  String get asrServicesMimoSubtitle => '分段云端转写';

  @override
  String get asrServicesStepTitle => 'Step';

  @override
  String get asrServicesStepSubtitle => 'Step Audio 分段云端转写';

  @override
  String get asrServicesAddTitle => '添加语音识别';

  @override
  String get asrServicesEditTitle => '编辑语音识别';

  @override
  String get asrServicesSelectedLabel => '已选择';

  @override
  String get asrServicesUnavailableLabel => '不可用';

  @override
  String get asrServicesEditAction => '编辑';

  @override
  String get asrServicesDeleteAction => '删除';

  @override
  String get asrServicesCancelAction => '取消';

  @override
  String get asrServicesAddAction => '添加';

  @override
  String get asrServicesSaveAction => '保存';

  @override
  String get asrServicesNameLabel => '名称';

  @override
  String get asrServicesApiKeyLabel => 'API Key';

  @override
  String get asrServicesEndpointLabel => '服务地址';

  @override
  String get asrServicesModelLabel => '模型';

  @override
  String get asrServicesResourceIdLabel => '资源 ID';

  @override
  String get asrServicesLanguageLabel => '语言';

  @override
  String get asrServicesAutomaticLabel => '自动';

  @override
  String get asrServicesApiKeyRequired => '请输入 API Key 后再使用此服务。';

  @override
  String get asrServicesChooseModelTitle => '模型';

  @override
  String get asrServicesModelDownloadAction => '下载';

  @override
  String get asrServicesModelUseAction => '使用此模型';

  @override
  String get asrServicesModelDeleteAction => '删除下载';

  @override
  String get asrServicesModelDownloadedLabel => '已下载';

  @override
  String get asrServicesModelDownloadingLabel => '正在下载…';

  @override
  String get asrServicesModelNotDownloadedLabel => '未下载';

  @override
  String asrServicesDownloadFailed(String error) {
    return '模型下载失败：$error';
  }

  @override
  String get asrServicesSystemChecking => '正在检查…';

  @override
  String get asrServicesSystemAvailable => '可用';

  @override
  String get asrServicesSystemCheckFailed => '这台设备没有可用的系统语音识别服务。';

  @override
  String get asrServicesMicrophonePermissionDenied => '未获得麦克风权限。';

  @override
  String get asrServicesNoSpeechDetected => '没有识别到语音。';

  @override
  String asrServicesRecognitionFailed(String error) {
    return '语音识别失败：$error';
  }

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
  String get ttsServicesFieldLanguageTypeLabel => '语言类型';

  @override
  String get ttsServicesFieldLanguageLabel => '语言';

  @override
  String get ttsServicesValidationApiKeyRequired => 'API Key 不能为空';

  @override
  String get ttsServicesViewDetailsButton => '查看详情';

  @override
  String get ttsServicesDialogErrorTitle => '错误详情';

  @override
  String get ttsServicesCloseButton => '关闭';

  @override
  String get ttsSettingsPageTitle => 'TTS 设置';

  @override
  String get ttsSettingsPlaybackSection => '播放';

  @override
  String get ttsSettingsAutoPlayTitle => '自动播放助手回复';

  @override
  String get ttsSettingsAutoPlayDescription => '助手回复生成完成后自动开始 TTS 播放。';

  @override
  String get ttsSettingsCacheReplayTitle => '使用缓存复播';

  @override
  String get ttsSettingsCacheReplayDescription => '重新播放网络语音时使用已生成的音频，不再请求语音服务。';

  @override
  String get ttsSettingsTextSelectionSection => '文本选择';

  @override
  String get ttsSettingsTextSelectionFallbackDescription => '没有匹配内容时将播放完整回复。';

  @override
  String get ttsSettingsTextSelectionFullTextTitle => '全文';

  @override
  String get ttsSettingsTextSelectionFullTextDescription => '播放完整助手回复。';

  @override
  String get ttsSettingsTextSelectionQuotedOnlyTitle => '仅引号内文字';

  @override
  String get ttsSettingsTextSelectionQuotedOnlyDescription =>
      '播放 “”、‘’、\"\"、\'\'、「」或『』内的文字。';

  @override
  String get ttsSettingsTextSelectionOutsideParenthesesTitle => '括号外文字';

  @override
  String get ttsSettingsTextSelectionOutsideParenthesesDescription =>
      '跳过 () 和 （） 内的文字。';

  @override
  String get ttsSettingsTextSelectionItalicOnlyTitle => '仅斜体文字';

  @override
  String get ttsSettingsTextSelectionItalicOnlyDescription =>
      '播放 Markdown 或 HTML 斜体文字。';

  @override
  String get ttsSettingsTextSelectionNonItalicTitle => '仅正体文字';

  @override
  String get ttsSettingsTextSelectionNonItalicDescription =>
      '跳过 Markdown 或 HTML 斜体文字。';

  @override
  String get ttsFloatingPlayerLabel => '语音播放器';

  @override
  String get ttsFloatingPauseTooltip => '暂停';

  @override
  String get ttsFloatingResumeTooltip => '继续播放';

  @override
  String get ttsFloatingReplayTooltip => '重新播放';

  @override
  String get ttsFloatingRewind15Tooltip => '后退 15 秒';

  @override
  String get ttsFloatingForward15Tooltip => '前进 15 秒';

  @override
  String get ttsFloatingSpeedTooltip => '播放倍速';

  @override
  String get ttsFloatingCloseTooltip => '关闭播放器';

  @override
  String get ttsFloatingExpandTooltip => '展开播放控制';

  @override
  String get ttsFloatingCollapseTooltip => '收起播放控制';

  @override
  String get ttsFloatingSaveTooltip => '保存音频';

  @override
  String get ttsSaveDialogTitle => '保存 TTS 音频';

  @override
  String get ttsSaveSuccess => '音频已保存';

  @override
  String get ttsSaveNothing => '暂无可保存的音频';

  @override
  String ttsSaveFailed(String message) {
    return '保存音频失败：$message';
  }

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
  String get imageViewerPageCloseButton => '关闭预览';

  @override
  String get imageViewerPageSaveButton => '保存图片';

  @override
  String get imageViewerPageCopyButton => '复制图片';

  @override
  String get imageViewerPagePreviousButton => '上一张图片';

  @override
  String get imageViewerPageNextButton => '下一张图片';

  @override
  String get imageViewerPageZoomInButton => '放大';

  @override
  String get imageViewerPageZoomOutButton => '缩小';

  @override
  String get imageViewerPageResetZoomButton => '重置缩放';

  @override
  String get imageViewerPageFlipHorizontalButton => '左右镜像';

  @override
  String get imageViewerPageFlipVerticalButton => '上下镜像';

  @override
  String get imageViewerPageRotateLeftButton => '向左旋转';

  @override
  String get imageViewerPageRotateRightButton => '向右旋转';

  @override
  String imageViewerPageCounter(int index, int total) {
    return '$index/$total';
  }

  @override
  String imageViewerPageImageLabel(int index, int total) {
    return '第 $index 张图片，共 $total 张';
  }

  @override
  String get imageViewerPageImageLoadFailed => '无法加载图片';

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
  String get searchServiceNameDoubao => '豆包';

  @override
  String get searchProviderDoubaoDescription => '火山引擎豆包网页搜索 API。';

  @override
  String get searchServiceNameSerper => 'Serper';

  @override
  String get searchProviderSerperDescription =>
      'Serper Google 搜索 API。响应快速，支持国家/地区、语言、时间和页码过滤。';

  @override
  String get searchServiceNameQuerit => 'Querit';

  @override
  String get searchProviderQueritDescription =>
      '面向 LLM 应用的 Querit 搜索 API。返回实时网页结果，并支持站点、时间、国家和语言过滤。';

  @override
  String get searchServiceNameGrok => 'Grok';

  @override
  String get searchProviderGrokDescription =>
      '通过 xAI Responses API 使用 Grok 搜索。调用网页和 X 搜索工具，并返回带引用的来源。';

  @override
  String get searchServiceNameStepFun => 'StepFun';

  @override
  String get searchProviderStepFunDescription =>
      '通过 StepFun POST /v1/search 进行网页搜索。';

  @override
  String get searchServiceNameFirecrawl => 'Firecrawl';

  @override
  String get searchProviderFirecrawlDescription =>
      'Firecrawl Search API v2。API Key 可选。此处不支持 Scrape。';

  @override
  String get searchServiceNameTinyFish => 'TinyFish';

  @override
  String get searchProviderTinyFishDescription =>
      'TinyFish Search API，支持地区与语言参数。需要 API Key。此处不支持 Fetch/Scrape。';

  @override
  String get searchServiceNameKelivo => 'Kelivo';

  @override
  String get searchServicesDialogCountryOptional => '国家/地区（可选）';

  @override
  String get searchServicesDialogLanguageOptional => '语言（可选）';

  @override
  String get searchServicesDialogTimeFilterOptional => '时间过滤（可选）';

  @override
  String get searchServicesDialogPageOptional => '页码（可选）';

  @override
  String get searchServicesDialogPageInvalid => '页码必须是正整数。';

  @override
  String get searchServicesDialogSitesIncludeOptional => '包含站点（可选）';

  @override
  String get searchServicesDialogSitesExcludeOptional => '排除站点（可选）';

  @override
  String get searchServicesDialogTimeRangeOptional => '时间范围（可选）';

  @override
  String get searchServicesDialogCountriesOptional => '国家（可选）';

  @override
  String get searchServicesDialogLanguagesOptional => '语言（可选）';

  @override
  String get searchServicesDialogSitesHint => 'example.com, docs.example.com';

  @override
  String get searchServicesDialogTimeRangeHint => 'd7';

  @override
  String get searchServicesDialogCountriesHint => 'united states, japan';

  @override
  String get searchServicesDialogLanguagesHint => 'english, japanese';

  @override
  String get generationInterrupted => '生成已中断';

  @override
  String get titleForLocale => '新对话';

  @override
  String get temporaryChatTitle => '临时对话';

  @override
  String get temporaryChatEmptyMessage => '临时对话不显示在历史记录，退出后将被完全删除';

  @override
  String get temporaryChatToggleTooltip => '切换临时对话';

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
  String get instructionInjectionUngroupedGroup => '未分组';

  @override
  String get instructionInjectionGroupLabel => '分组';

  @override
  String get instructionInjectionGroupHint => '可选';

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
  String get assistantEditLocalToolTimeInfoTitle => '时间信息';

  @override
  String get assistantEditLocalToolTimeInfoSubtitle =>
      '读取设备日期、星期、时间、时区、UTC 偏移和时间戳。';

  @override
  String get assistantEditLocalToolClipboardTitle => '剪切板';

  @override
  String get assistantEditLocalToolClipboardSubtitle =>
      '在明确需要时读取或写入设备剪切板中的纯文本。';

  @override
  String get assistantEditLocalToolTextToSpeechTitle => '文字转语音';

  @override
  String get assistantEditLocalToolTextToSpeechSubtitle =>
      '允许助手使用已配置的语音播放朗读文本。';

  @override
  String get assistantEditLocalToolAskUserTitle => '询问用户';

  @override
  String get assistantEditLocalToolAskUserSubtitle => '允许助手提出简短问题，并在你回答后继续生成。';

  @override
  String get assistantEditLocalToolCalculateTitle => '计算器';

  @override
  String get assistantEditLocalToolCalculateSubtitle =>
      '计算数学表达式，支持加减乘除幂运算 sqrt sin cos 等。';

  @override
  String get assistantEditLocalToolScreenTimeTitle => '屏幕使用时间';

  @override
  String get assistantEditLocalToolScreenTimeSubtitle =>
      '查询本设备的应用使用时长，需要授予使用情况访问权限。';

  @override
  String get chatMessageWidgetScreenTimeTotal => '总屏幕时间';

  @override
  String get chatMessageWidgetScreenTimePermissionRequired =>
      '未授予使用情况访问权限，请在系统设置中开启后重试。';

  @override
  String get assistantEditLocalToolCalendarQueryTitle => '查询日历';

  @override
  String get assistantEditLocalToolCalendarQuerySubtitle =>
      '读取本设备上的日历日程，需要授予日历权限。';

  @override
  String get assistantEditLocalToolCalendarCreateTitle => '创建日程';

  @override
  String get assistantEditLocalToolCalendarCreateSubtitle =>
      '在你确认后于本设备创建日历日程，需要授予日历权限。';

  @override
  String get assistantEditMemorySwitchDescription => '允许助手主动存储并在对话间引用用户相关信息';

  @override
  String get assistantEditRecentChatsSwitchTitle => '参考历史聊天记录';

  @override
  String get assistantEditRecentChatsSwitchDescription =>
      '在新对话中引用最近的对话标题以增强上下文';

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
  String get networkProxyBypassLabel => '代理绕过';

  @override
  String get networkProxyBypassHint =>
      '用逗号分隔的主机或 CIDR，例如：localhost,127.0.0.1,192.168.0.0/16,*.local';

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
  String get providerDetailPageMultiSelectButton => '多选';

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
  String get providerDetailPageDeleteSelectedModelsButton => '删除';

  @override
  String get providerDetailPageDeleteSelectedModelsTooltip => '删除所选模型';

  @override
  String providerDetailPageDeleteSelectedModelsConfirm(int count) {
    return '确定删除选中的 $count 个模型吗？此操作不可撤回。';
  }

  @override
  String get providerDetailPageDeleteFailedDetectedModelsButton => '删除不可用';

  @override
  String get providerDetailPageDeleteFailedDetectedModelsTooltip => '删除检测失败的模型';

  @override
  String providerDetailPageDeleteFailedDetectedModelsConfirm(int count) {
    return '确定删除检测失败的 $count 个模型吗？此操作不可撤回。';
  }

  @override
  String providerDetailPageSelectedModelsDeletedSnackbar(int count) {
    return '已删除 $count 个模型';
  }

  @override
  String get providerDetailPageDeleteAllModelsTooltip => '删除全部模型';

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
  String get contextLogSettingTitle => '上下文日志';

  @override
  String get contextLogSettingSubtitle =>
      '开启后会将每次实际发送给模型的完整上下文写入 logs/context_logs.txt';

  @override
  String get contextLogViewerTitle => '上下文';

  @override
  String contextLogSnapshotMessages(int count) {
    return '$count 条消息';
  }

  @override
  String contextLogSnapshotTokens(int count) {
    return '$count tokens';
  }

  @override
  String get contextLogSourceSystemPrompt => '系统提示词';

  @override
  String get contextLogSourceMemoryRules => '记忆规则';

  @override
  String get contextLogSourceSearchPrompt => '搜索提示';

  @override
  String get contextLogSourceInstructionInjection => '指令注入';

  @override
  String get contextLogSourceWorldBook => '世界书';

  @override
  String get contextLogSourceMemorySnapshot => '记忆快照';

  @override
  String get contextLogSourceChatHistory => '聊天历史';

  @override
  String get contextLogSourceToolCall => '工具调用';

  @override
  String get contextLogSourceToolResult => '工具结果';

  @override
  String get contextLogTokensEstimateHint => 'tokens 仅为预估值，请以模型实际消耗为准。';

  @override
  String contextLogSnapshotsCount(int count) {
    return '$count 条快照';
  }

  @override
  String get contextLogSnapshotFallbackTitle => '快照';

  @override
  String get contextLogKindFull => '全量快照';

  @override
  String get contextLogKindUpdate => '增量更新';

  @override
  String get contextLogSectionComposition => '构成';

  @override
  String get contextLogLoadOlder => '加载更早的日志';

  @override
  String get contextLogLoading => '加载中…';

  @override
  String get contextLogAllLoaded => '已加载全部日志';

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
  String logViewerRequestsCount(int count) {
    return '$count 条请求';
  }

  @override
  String get logViewerFieldId => 'ID';

  @override
  String get logViewerFieldMethod => '方法';

  @override
  String get logViewerFieldStatus => '状态';

  @override
  String get logViewerFieldStarted => '开始';

  @override
  String get logViewerFieldEnded => '结束';

  @override
  String get logViewerFieldDuration => '耗时';

  @override
  String get logViewerSectionSummary => '概览';

  @override
  String get logViewerSectionParameters => '参数';

  @override
  String get logViewerSectionRequestHeaders => '请求头';

  @override
  String get logViewerSectionRequestBody => '请求体';

  @override
  String get logViewerSectionResponseHeaders => '响应头';

  @override
  String get logViewerSectionResponseBody => '响应体';

  @override
  String get logViewerSectionWarnings => '警告';

  @override
  String get logViewerErrorTitle => '错误';

  @override
  String logViewerMoreCount(int count) {
    return '+$count 条更多';
  }

  @override
  String get logViewerSectionAttachments => '附件';

  @override
  String get logViewerPayloadOmitted => '已省略';

  @override
  String get logViewerShowMore => '显示更多';

  @override
  String get logSettingsTitle => '日志设置';

  @override
  String get logSettingsSaveOutput => '保存响应输出';

  @override
  String get logSettingsSaveOutputSubtitle =>
      '记录流式输出的每个分片（可能影响生成性能）。HTTP 报错响应仍会写入。';

  @override
  String get logSettingsElidePayloads => '省略大载荷';

  @override
  String get logSettingsElidePayloadsSubtitle =>
      '把内联的 base64 图片和文件替换成占位符，日志更小、查看器更快。';

  @override
  String get logSettingsAutoDelete => '自动删除';

  @override
  String get logSettingsAutoDeleteSubtitle => '删除超过指定天数的日志';

  @override
  String get logSettingsAutoDeleteDisabled => '不启用';

  @override
  String logSettingsAutoDeleteDays(int count) {
    return '$count 天';
  }

  @override
  String get logSettingsMaxSize => '日志大小上限';

  @override
  String get logSettingsMaxSizeSubtitle => '超出后将删除最早的日志';

  @override
  String get logSettingsMaxSizeUnlimited => '不限制';

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

  @override
  String get homePageProcessingFiles => '正在解析文件……';

  @override
  String get settingsPageWorldBook => '世界书';

  @override
  String get settingsPageMemory => '记忆';

  @override
  String get memorySettingsPageTitle => '记忆';

  @override
  String get memorySettingsGlobalSubtitle => '记忆模式、模型与提示词';

  @override
  String get memorySettingsModeSection => '记忆模式';

  @override
  String get memorySettingsModelSection => '记忆模型';

  @override
  String get memorySettingsModelTitle => '处理模型';

  @override
  String get memorySettingsModelUnset => '未选择';

  @override
  String get memorySettingsModelTip => '开启「自动整理记忆」后，后台会频繁调用此模型，建议选择便宜且速度快的模型。';

  @override
  String get memorySettingsAboutTitle => '记忆说明';

  @override
  String get memorySettingsAboutSubtitle => '了解记忆如何运作与触发';

  @override
  String get memoryAboutQuickstartTitle => '三步上手';

  @override
  String get memoryAboutQuickstartBody =>
      '① 在「设置 → 记忆」里选择处理模型。\n② 在助手的「记忆」页打开长期记忆和自动整理。\n③ 聊几轮，或点「整理记忆」，再到「全部记忆」查看结果。';

  @override
  String get memoryAboutTypesTitle => '记忆类型';

  @override
  String get memoryAboutTypesBody =>
      '身份：用户的稳定信息，例如称呼、职业、语言、长期偏好。写成完整的第三人称陈述。\n\n工作流：用户习惯怎么做事，例如工具、格式、审阅方式。\n\n语气：用户希望助手怎么说话，例如语气、篇幅、语言风格。\n\n指令：助手应长期遵守的规则，而不是本次对话里的一次性任务。';

  @override
  String get memoryAboutScopeTitle => '全局与助手范围';

  @override
  String get memoryAboutScopeBody =>
      '全局记忆会对所有助手注入。助手范围的记忆只对该助手可见。跨助手都该知道的事实用全局；只属于某一个助手的规则或上下文用助手范围。';

  @override
  String get memoryAboutInjectionTitle => '记忆如何注入';

  @override
  String get memoryAboutInjectionBody =>
      '开对话时，每类会把最近的若干条放进模型上下文。某类超过注入上限时，块会标上 mode=\"summary\"，并用 total / shown 标明总数与展示条数，其余由模型用 memory_search_profile 按需查询。可在「设置 → 记忆」调大上限，更全面但更费 token。';

  @override
  String get memoryAboutPipelineTitle => '后台整理';

  @override
  String get memoryAboutPipelineBody =>
      '开启自动整理后，对话结束会走：判断是否值得记 → 提取候选 → 去重合并 → 必要时把身份类记忆提炼进用户画像。也可以在助手「记忆」页点「整理记忆」。因此处理模型会被较频繁调用。';

  @override
  String get memoryAboutCacheTitle => '保持缓存良好';

  @override
  String get memoryAboutCacheBody =>
      '注入前缀会保持稳定，未改动时可复用 Prompt 缓存，从而降低费用与延迟。避免无意义的大批量改动或重排。日常增删改单条通常影响有限。';

  @override
  String get memoryAboutFaqTitle => '常见问题';

  @override
  String get memoryAboutFaqWhyNotRememberedTitle => '为什么没记住？';

  @override
  String get memoryAboutFaqWhyNotRememberedBody =>
      '整理会被跳过，常见原因包括：新消息不足，暂不整理；没有新消息需要整理；尚未选择记忆处理模型。临时对话不会写入记忆。也可以按助手关闭记忆或自动整理。';

  @override
  String get memorySettingsThinkingTitle => '启用思考';

  @override
  String get memorySettingsThinkingSubtitle => '在模型支持时允许记忆模型使用推理';

  @override
  String get memorySettingsInjectionSection => '记忆注入';

  @override
  String get memorySettingsInjectionMaxItemsTitle => '每类注入条数';

  @override
  String get memorySettingsInjectionMaxItemsSubtitle =>
      '某一类型的记忆超过该条数时，只注入最近的若干条，其余由模型用 memory_search_profile 按需查询。调大更全面但更费 token。若你改过规则提示词，请一并更新或恢复默认。';

  @override
  String memorySettingsInjectionMaxItemsOption(int n) {
    return '$n';
  }

  @override
  String get memorySettingsInjectionMaxItemsCustomButton => '自定义';

  @override
  String get memorySettingsInjectionMaxItemsCustomTitle => '自定义注入条数';

  @override
  String get memorySettingsInjectionMaxItemsCustomDescription =>
      '请输入 1 到 100 之间的整数。';

  @override
  String get memorySettingsInjectionMaxItemsCustomLabel => '条数';

  @override
  String get memorySettingsInjectionMaxItemsCustomHint => '1–100';

  @override
  String get memorySettingsInjectionMaxItemsCustomInvalid =>
      '请输入 1 到 100 之间的整数';

  @override
  String get memorySettingsPromptLangSection => '提示词语言';

  @override
  String get memorySettingsPromptLangAuto => '自动';

  @override
  String get memorySettingsPromptLangAutoSubtitle => '跟随界面语言（中文用 zh，否则用 en）';

  @override
  String get memorySettingsPromptLangZh => '中文';

  @override
  String get memorySettingsPromptLangZhSubtitle => '始终使用中文记忆提示词与工具描述';

  @override
  String get memorySettingsPromptLangEn => 'English';

  @override
  String get memorySettingsPromptLangEnSubtitle => '始终使用英文记忆提示词与工具描述';

  @override
  String get memorySettingsPromptsSection => '提示词模板';

  @override
  String get memorySettingsLegacyPromptTitle => '旧版记忆规则';

  @override
  String get memoryPromptEditRulesTitle => '记忆规则';

  @override
  String get memoryPromptEditRulesSubtitle => '注入到主对话的系统提示中';

  @override
  String get memoryPromptEditGateTitle => 'Gatekeeper';

  @override
  String get memoryPromptEditGateSubtitle => '判断这一轮是否值得记忆';

  @override
  String get memoryPromptEditExtractTitle => 'Extract';

  @override
  String get memoryPromptEditExtractSubtitle => '从对话中提取候选记忆条目';

  @override
  String get memoryPromptEditSmartAddTitle => 'Smart Add';

  @override
  String get memoryPromptEditSmartAddSubtitle =>
      'NEW / MERGE / CONFLICT / SKIP 去重判定';

  @override
  String get memoryPromptEditDistillTitle => 'Profile Distiller';

  @override
  String get memoryPromptEditDistillSubtitle => '从身份类记忆提炼画像字段';

  @override
  String get memoryPromptEditMigrateTitle => '旧版记忆迁移';

  @override
  String get memoryPromptEditMigrateSubtitle => '选择「模型整理」时用于改写记忆原文';

  @override
  String get memoryPromptEditReset => '恢复默认';

  @override
  String get memoryPromptEditSave => '保存';

  @override
  String get memoryPromptEditSectionPerItem => '逐条提示词';

  @override
  String get memoryPromptEditSectionBatch => '合并提示词';

  @override
  String get memorySettingsEntriesSection => '全部记忆';

  @override
  String get memorySettingsLegacySection => '旧版记忆';

  @override
  String get memorySettingsEntriesTitle => '记忆列表';

  @override
  String get memorySettingsEntriesSubtitle => '浏览、编辑、归档与删除记忆';

  @override
  String get memorySettingsProfileTitle => '用户画像';

  @override
  String get memorySettingsProfileSubtitle => '供模型使用的结构化身份字段';

  @override
  String get memorySettingsLegacyTitle => '旧版记忆（只读）';

  @override
  String get memorySettingsLegacySubtitle => '来自旧版本的记忆';

  @override
  String get memoryEntryTypeIdentity => '身份';

  @override
  String get memoryEntryTypeWorkflow => '工作流';

  @override
  String get memoryEntryTypeVoice => '语气';

  @override
  String get memoryEntryTypeInstruction => '指令';

  @override
  String get memoryEntryScopeGlobal => '全局';

  @override
  String get memoryEntryScopeAssistant => '仅本助手';

  @override
  String memoryEntryScopeAssistantNamed(String name) {
    return '$name';
  }

  @override
  String get memoryEntrySourceManual => '手动';

  @override
  String get memoryEntrySourceTool => '工具';

  @override
  String get memoryEntrySourceExtracted => '提取';

  @override
  String get memoryEntrySourceDistilled => '蒸馏';

  @override
  String get memoryEntryStatusActive => '活跃';

  @override
  String get memoryEntryStatusArchived => '已归档';

  @override
  String memoryEntryUpdatedAt(String date) {
    return '更新于 $date';
  }

  @override
  String get memoryEntryActionEdit => '编辑';

  @override
  String get memoryEntryActionDelete => '删除';

  @override
  String get memoryEntryActionArchive => '归档';

  @override
  String get memoryEntryActionRestore => '恢复';

  @override
  String get memoryEntryActionSwitchScope => '切换范围';

  @override
  String get memoryEntryActionBatchDelete => '删除所选';

  @override
  String get memoryEntryActionAdd => '添加记忆';

  @override
  String get memoryEntryDeleteConfirmTitle => '删除这条记忆？';

  @override
  String get memoryEntryDeleteConfirmContent => '将永久删除该记忆，且无法撤销。';

  @override
  String memoryEntryBatchDeleteConfirmTitle(int count) {
    return '删除 $count 条记忆？';
  }

  @override
  String get memoryEntryBatchDeleteConfirmContent => '所选记忆将被永久删除。';

  @override
  String get memoryEntrySwitchScopeConfirmTitle => '更改记忆范围？';

  @override
  String get memoryEntrySwitchScopeToGlobal => '将这条记忆设为全局（所有助手可见）？';

  @override
  String get memoryEntrySwitchScopeToAssistant => '将这条记忆限制为仅本助手？';

  @override
  String get memoryEntryArchivedSection => '已归档';

  @override
  String get memoryEntryEmpty => '还没有记忆';

  @override
  String get memoryEntryEmptyDisabled => '该助手未启用长期记忆';

  @override
  String get memoryEntryEditTitle => '编辑记忆';

  @override
  String get memoryEntryCreateTitle => '新建记忆';

  @override
  String get memoryEntryContentHint => '输入记忆内容';

  @override
  String get memoryEntryTypeLabel => '类型';

  @override
  String get memoryEntryScopeLabel => '范围';

  @override
  String get memoryFilterScopeAll => '全部范围';

  @override
  String get memoryFilterScopeGlobal => '仅全局';

  @override
  String get memoryFilterScopeAssistant => '助手';

  @override
  String get memoryFilterTypeAll => '全部类型';

  @override
  String get memoryFilterStatusAll => '全部状态';

  @override
  String get memoryFilterStatusActive => '活跃';

  @override
  String get memoryFilterStatusArchived => '已归档';

  @override
  String get memorySearchHint => '搜索记忆';

  @override
  String get memorySearchEmpty => '没有匹配的记忆';

  @override
  String memoryOrphanBanner(int count) {
    return '有 $count 条孤儿助手记忆（助手已删除）';
  }

  @override
  String get memoryOrphanCleanupButton => '清理';

  @override
  String get memoryOrphanConfirmTitle => '清理孤儿记忆？';

  @override
  String memoryOrphanConfirmContent(int count) {
    return '将永久删除 $count 条所属助手已不存在的记忆。';
  }

  @override
  String get memoryOrganizeButton => '整理记忆';

  @override
  String get memoryOrganizeNeedsConversation => '需要在与该助手的对话中使用';

  @override
  String get memoryOrganizeNeedsModel => '请先在 设置 → 记忆 中选择记忆处理模型';

  @override
  String get memoryOrganizeStatusNever => '尚未整理';

  @override
  String memoryOrganizeStatusLast(String when) {
    return '上次整理：$when';
  }

  @override
  String memoryOrganizeStatusExtracted(int count) {
    return '提取 $count 条';
  }

  @override
  String get memoryOrganizeStatusSkipped => '无需记忆';

  @override
  String memoryOrganizeStatusFailed(String reason) {
    return '失败：$reason';
  }

  @override
  String memoryOrganizeStatusSkippedReason(String reason) {
    return '已跳过：$reason';
  }

  @override
  String get memoryOutcomeTemporaryConversation => '临时对话不会写入记忆';

  @override
  String get memoryOutcomeMemoryDisabled => '该助手已关闭记忆';

  @override
  String get memoryOutcomeAutoOrganizeOff => '自动整理已关闭';

  @override
  String get memoryOutcomeStreaming => '回复仍在生成，已跳过整理';

  @override
  String get memoryOutcomeBelowThreshold => '新消息不足，暂不整理';

  @override
  String get memoryOutcomeEmptyWindow => '没有新消息需要整理';

  @override
  String get memoryOutcomeMemoryModelUnset => '尚未选择记忆处理模型';

  @override
  String get memoryOutcomeMemoryModelMissing => '所选记忆模型已不可用';

  @override
  String get memoryOutcomeAssistantMissing => '找不到助手';

  @override
  String get memoryOutcomeConversationMissing => '找不到对话';

  @override
  String get memoryOutcomeQueueOverflow => '整理队列已满，本次任务被丢弃';

  @override
  String get memoryOutcomeGateRequestFailed => '判断是否值得记忆时，无法请求记忆模型';

  @override
  String get memoryOutcomeGateParseFailed => '判断是否值得记忆的回复无法解析';

  @override
  String get memoryOutcomeExtractRequestFailed => '提取记忆时，无法请求记忆模型';

  @override
  String get memoryOutcomeExtractParseFailed => '提取记忆的回复无法解析';

  @override
  String get memoryOutcomeDistillFailed => '用户画像提炼失败';

  @override
  String get memoryOutcomeMemoryExecutionError => '记忆工具执行失败';

  @override
  String get memoryOutcomeUnsupportedTool => '不支持的记忆工具';

  @override
  String get memoryOutcomeInvalidMemoryType => '记忆类型无效';

  @override
  String get memoryOutcomeInvalidMemoryContent => '记忆内容无效';

  @override
  String get memoryOutcomeInvalidQuery => '查询无效';

  @override
  String get memoryOutcomeInvalidMemoryId => '记忆 ID 无效';

  @override
  String get memoryOutcomeMemoryNotFound => '找不到这条记忆';

  @override
  String get memoryOutcomeInvalidProfileFields => '画像字段无效';

  @override
  String get memoryOutcomeChatSearchUnavailable => '对话搜索不可用';

  @override
  String get memoryOrganizeJustNow => '刚刚';

  @override
  String memoryOrganizeMinutesAgo(int n) {
    return '$n 分钟前';
  }

  @override
  String memoryOrganizeHoursAgo(int n) {
    return '$n 小时前';
  }

  @override
  String memoryOrganizeDaysAgo(int n) {
    return '$n 天前';
  }

  @override
  String get memoryModelMissingNotice => '需要先在 设置 → 记忆 中选择记忆处理模型。';

  @override
  String get memoryModelMissingGoSelect => '去选择';

  @override
  String get memoryEntriesPageTitle => '全部记忆';

  @override
  String get userProfilePageTitle => '用户画像';

  @override
  String get userProfilePreferredName => '希望怎么称呼我';

  @override
  String get userProfilePreferredNameHint => '这是希望模型怎么称呼你，与侧栏显示的用户名无关';

  @override
  String get userProfileGender => '性别';

  @override
  String get userProfilePronouns => '代词';

  @override
  String get userProfilePreferredLanguage => '偏好语言';

  @override
  String get userProfileTimezone => '时区';

  @override
  String get userProfileOccupation => '职业';

  @override
  String get userProfileLocation => '所在地';

  @override
  String get userProfileCustomSection => '自定义字段';

  @override
  String get userProfileAddCustom => '添加自定义字段';

  @override
  String get userProfileCustomKeyHint => '键名（custom.name）';

  @override
  String get userProfileCustomValueHint => '值';

  @override
  String get userProfileInvalidKey => '键名须为 custom. 后跟 1–32 位字母、数字、_ 或 -';

  @override
  String get userProfileClear => '清除';

  @override
  String get userProfileSave => '保存';

  @override
  String get userProfileEmptyValue => '未设置';

  @override
  String get legacyMemoryPageTitle => '旧版记忆';

  @override
  String get legacyMemoryBanner => '这些记忆来自旧版本，不会参与对话；你可以将它们迁移到当前记忆系统。';

  @override
  String get legacyMemoryEmpty => '没有旧版记忆';

  @override
  String get legacyMemoryCopy => '复制';

  @override
  String get legacyMemoryCopied => '已复制';

  @override
  String get legacyMemoryExport => '导出';

  @override
  String get legacyMemoryExportTitle => 'Kelivo 旧版记忆导出';

  @override
  String legacyMemoryAssistantHeader(String name) {
    return '助手：$name';
  }

  @override
  String get legacyMemorySearchHint => '搜索旧版记忆';

  @override
  String get legacyMemoryMigrate => '迁移';

  @override
  String get legacyMemoryMigrationTitle => '迁移旧版记忆';

  @override
  String legacyMemoryMigrationSubtitle(int count) {
    return '使用模型整理并分类 $count 条旧版记忆，原数据不会改变。';
  }

  @override
  String get legacyMemoryMigrationModel => '迁移模型';

  @override
  String get legacyMemoryMigrationChooseModel => '选择模型';

  @override
  String get legacyMemoryMigrationTarget => '保存到';

  @override
  String get legacyMemoryMigrationTargetGlobal => '全局';

  @override
  String get legacyMemoryMigrationTargetAssistant => '当前助手';

  @override
  String get legacyMemoryMigrationTargetOriginalAssistants => '原助手';

  @override
  String get legacyMemoryMigrationTargetGlobalDescription => '所有助手均可使用';

  @override
  String get legacyMemoryMigrationTargetAssistantDescription => '仅当前助手可使用';

  @override
  String get legacyMemoryMigrationTargetOriginalDescription => '每条记忆保留在原来的助手下';

  @override
  String get legacyMemoryMigrationStart => '开始迁移';

  @override
  String get legacyMemoryMigrationAnalyzing => '正在使用模型分析';

  @override
  String get legacyMemoryMigrationWriting => '正在写入记忆';

  @override
  String legacyMemoryMigrationProgress(int current, int total) {
    return '$current / $total';
  }

  @override
  String get legacyMemoryMigrationComplete => '迁移完成';

  @override
  String legacyMemoryMigrationResult(int created, int skipped) {
    return '已迁移 $created 条 · 跳过已有 $skipped 条';
  }

  @override
  String get legacyMemoryMigrationFailed => '迁移已停止。可以重试，已保存的记忆会自动跳过。';

  @override
  String get legacyMemoryMigrationRetry => '重试';

  @override
  String get legacyMemoryMigrationClose => '完成';

  @override
  String get legacyMemoryMigrationContentMode => '内容处理';

  @override
  String get legacyMemoryMigrationContentPreserve => '保留原文';

  @override
  String get legacyMemoryMigrationContentOrganize => '模型整理';

  @override
  String get legacyMemoryMigrationContentPreserveDescription =>
      '模型只负责分类，写入时保留旧记忆原文。';

  @override
  String get legacyMemoryMigrationContentOrganizeDescription =>
      '模型会分类并改写内容，使用可编辑的迁移提示词。';

  @override
  String get legacyMemoryMigrationBatchSize => '批大小';

  @override
  String legacyMemoryMigrationPartial(int created, int skipped, int failed) {
    return '已迁移 $created · 跳过 $skipped · 失败 $failed';
  }

  @override
  String get legacyMemoryMigrationContinue => '继续迁移';

  @override
  String get legacyMemoryMigrationErrorNetwork => '网络异常，请检查连接后重试。';

  @override
  String get legacyMemoryMigrationErrorFormat => '模型返回格式不正确。';

  @override
  String get legacyMemoryMigrationErrorAuth => '鉴权失败，请检查 API 密钥。';

  @override
  String legacyMemoryMigrationErrorOther(String message) {
    return '迁移失败：$message';
  }

  @override
  String get legacyMemoryModeTitle => '使用旧版记忆';

  @override
  String get legacyMemoryModeSubtitle => '全局设置，影响所有助手';

  @override
  String legacyMemoryModeCacheWarning(String token) {
    return '默认模板会注入当前时间 $token，影响缓存命中率，如不需要可删除';
  }

  @override
  String get memoryUiContentLabel => '内容';

  @override
  String get memoryUiValueLabel => '值';

  @override
  String get memoryUiCustomKeyLabel => '键名';

  @override
  String get memoryUiStatusLabel => '状态';

  @override
  String get memoryUiAssistantLabel => '助手';

  @override
  String get memoryUiAssistantAll => '全部助手';

  @override
  String get memoryUiSearchClear => '清除搜索';

  @override
  String get memoryUiAssistantLegacyTitle => '旧版记忆（只读）';

  @override
  String get memoryUiAssistantLegacySubtitle => '该助手来自旧版本的记忆';

  @override
  String get assistantEditMemorySwitchTitle => '使用长期记忆';

  @override
  String get assistantEditMemorySwitchSubtitle => '把已保存的记忆注入对话，并允许此助手写入新记忆';

  @override
  String get assistantEditAutoOrganizeTitle => '自动整理记忆';

  @override
  String get assistantEditAutoOrganizeSubtitle => '对话后自动运行记忆管线';

  @override
  String get assistantEditAllowPastRecallTitle => '允许回忆过去对话';

  @override
  String get assistantEditAllowPastRecallSubtitle => '启用跨会话的对话搜索';

  @override
  String get assistantEditGenerateSummaryTitle => '生成会话摘要';

  @override
  String get assistantEditGenerateSummarySubtitle => '摘要仅供对话搜索使用';

  @override
  String get assistantEditManageMemoryTitle => '本助手可见的记忆';

  @override
  String get assistantEditWriteScopeTitle => '记忆写入范围';

  @override
  String get assistantEditWriteScopeSubtitle => '新记忆默认写入的位置';

  @override
  String get assistantEditWriteScopeAlwaysGlobal => '一律全局';

  @override
  String get assistantEditWriteScopeAlwaysGlobalSubtitle => '新记忆对所有助手可见';

  @override
  String get assistantEditWriteScopeAlwaysAssistant => '一律本助手';

  @override
  String get assistantEditWriteScopeAlwaysAssistantSubtitle => '新记忆只对本助手可见';

  @override
  String get assistantEditWriteScopeToolDefaultGlobal => '模型自选（默认全局）';

  @override
  String get assistantEditWriteScopeToolDefaultGlobalSubtitle =>
      '模型可选择全局或本助手，缺省写入全局';

  @override
  String get assistantEditWriteScopeToolDefaultAssistant => '模型自选（默认本助手）';

  @override
  String get assistantEditWriteScopeToolDefaultAssistantSubtitle =>
      '模型可选择全局或本助手，缺省写入本助手';

  @override
  String get assistantEditDedupeModeTitle => '去重方式';

  @override
  String get assistantEditDedupeModeSubtitle => '候选记忆如何与已有条目比对';

  @override
  String get assistantEditDedupeModeBatched => '合并';

  @override
  String get assistantEditDedupeModeBatchedSubtitle =>
      '一次请求判断本轮全部候选。更快更省；条目多时精度较差。';

  @override
  String get assistantEditDedupeModePerItem => '逐条';

  @override
  String get assistantEditDedupeModePerItemSubtitle =>
      '每条候选单独请求判断。更准确，但会增加处理模型调用。';

  @override
  String get assistantEditOrganizeFrequencyTitle => '整理频率';

  @override
  String get assistantEditOrganizeFrequencySubtitle => '每累积 N 轮助手回复触发一次自动整理';

  @override
  String assistantEditOrganizeFrequencyOption(int n) {
    return '每 $n 轮';
  }

  @override
  String get assistantEditOrganizeFrequencyCustomButton => '自定义';

  @override
  String get assistantEditOrganizeFrequencyCustomTitle => '自定义整理频率';

  @override
  String get assistantEditOrganizeFrequencyCustomDescription =>
      '请输入 1 到 20 之间的整数。';

  @override
  String get assistantEditOrganizeFrequencyCustomLabel => '轮数';

  @override
  String get assistantEditOrganizeFrequencyCustomHint => '1–20';

  @override
  String get assistantEditOrganizeFrequencyCustomInvalid => '请输入 1 到 20 之间的整数';

  @override
  String get worldBookTitle => '世界书';

  @override
  String get worldBookAdd => '添加世界书';

  @override
  String get worldBookEmptyMessage => '暂无世界书';

  @override
  String get worldBookUnnamed => '未命名世界书';

  @override
  String get worldBookDisabledTag => '已停用';

  @override
  String get worldBookAlwaysOnTag => '常驻';

  @override
  String get worldBookAddEntry => '添加条目';

  @override
  String get worldBookExport => '分享/导出';

  @override
  String get worldBookConfig => '配置';

  @override
  String get worldBookDeleteTitle => '删除世界书';

  @override
  String worldBookDeleteMessage(String name) {
    return '确定删除「$name」？此操作无法撤销。';
  }

  @override
  String get worldBookCancel => '取消';

  @override
  String get worldBookDelete => '删除';

  @override
  String worldBookExportFailed(String error) {
    return '导出失败：$error';
  }

  @override
  String get worldBookNoEntriesHint => '暂无条目';

  @override
  String get worldBookUnnamedEntry => '未命名条目';

  @override
  String worldBookKeywordsLine(String keywords) {
    return '关键词：$keywords';
  }

  @override
  String get worldBookEditEntry => '编辑条目';

  @override
  String get worldBookDeleteEntry => '删除条目';

  @override
  String get worldBookNameLabel => '名称';

  @override
  String get worldBookDescriptionLabel => '简介';

  @override
  String get worldBookEnabledLabel => '启用';

  @override
  String get worldBookSave => '保存';

  @override
  String get worldBookEntryNameLabel => '条目名称';

  @override
  String get worldBookEntryEnabledLabel => '启用条目';

  @override
  String get worldBookEntryPriorityLabel => '优先级';

  @override
  String get worldBookEntryKeywordsLabel => '关键词';

  @override
  String get worldBookEntryKeywordsHint => '输入关键词后点 + 添加。';

  @override
  String get worldBookEntryKeywordInputHint => '输入关键词';

  @override
  String get worldBookEntryKeywordAddTooltip => '添加关键词';

  @override
  String get worldBookEntryUseRegexLabel => '使用正则';

  @override
  String get worldBookEntryCaseSensitiveLabel => '区分大小写';

  @override
  String get worldBookEntryAlwaysOnLabel => '常驻激活';

  @override
  String get worldBookEntryAlwaysOnHint => '无需匹配也会注入';

  @override
  String get worldBookEntryScanDepthLabel => '扫描深度';

  @override
  String get worldBookEntryContentLabel => '内容';

  @override
  String get worldBookEntryInjectionPositionLabel => '注入位置';

  @override
  String get worldBookEntryInjectionRoleLabel => '注入角色';

  @override
  String get worldBookEntryInjectDepthLabel => '注入深度';

  @override
  String get worldBookInjectionPositionBeforeSystemPrompt => '系统提示前';

  @override
  String get worldBookInjectionPositionAfterSystemPrompt => '系统提示后';

  @override
  String get worldBookInjectionPositionTopOfChat => '对话顶部';

  @override
  String get worldBookInjectionPositionBottomOfChat => '对话底部';

  @override
  String get worldBookInjectionPositionAtDepth => '指定深度';

  @override
  String get worldBookInjectionRoleUser => '用户';

  @override
  String get worldBookInjectionRoleAssistant => '助手';

  @override
  String get mcpToolNeedsApproval => '需要审批';

  @override
  String get toolApprovalPending => '等待审批';

  @override
  String get toolApprovalApprove => '批准';

  @override
  String get toolApprovalDeny => '拒绝';

  @override
  String get toolApprovalDenyTitle => '拒绝工具调用';

  @override
  String get toolApprovalDenyHint => '原因（可选）';

  @override
  String toolApprovalDeniedMessage(Object reason, Object toolName) {
    return '工具调用 \"$toolName\" 已被用户拒绝。原因：$reason';
  }

  @override
  String get askUserCardSubmit => '提交回答';

  @override
  String get askUserCardCustomHint => '输入你的回答';

  @override
  String get askUserCardSomethingElse => '其他';

  @override
  String get askUserCardSkip => '跳过';

  @override
  String get askUserCardSkipped => '已跳过';

  @override
  String get askUserCardAnswered => '已回答';

  @override
  String get askUserCardInactive => '这个问题已不再活动。请重新生成或继续对话。';

  @override
  String get askUserCardCancelled => '问题已取消';

  @override
  String askUserCardQuestionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '询问 $count 个问题',
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
  String get debugPageConversationToolsTitle => '对话工具';

  @override
  String get debugPageCreateOversizedConversationButton => '创建超大对话（30 MB）';

  @override
  String get debugPageCreateManyMessagesConversationButton => '创建 1024 条消息的对话';

  @override
  String get debugPageCreateDailyMixedMarkdownConversationButton =>
      '创建 3000 条日常混合 Markdown 消息';

  @override
  String get debugPageCreateLongReasoningConversationButton =>
      '创建长思考链对话（128 条）';

  @override
  String get debugPageCreatingButton => '创建中...';

  @override
  String get debugPageCreatingOversizedConversation => '正在创建 30 MB 超大对话...';

  @override
  String get debugPageCreatingManyMessagesConversation => '正在创建 1024 条消息的对话...';

  @override
  String get debugPageCreatingDailyMixedMarkdownConversation =>
      '正在创建 3000 条日常混合 Markdown 对话...';

  @override
  String get debugPageCreatingLongReasoningConversation => '正在创建长思考链调试对话...';

  @override
  String get debugPageNoCurrentAssistant => '当前没有助手。请先创建或选择一个助手。';

  @override
  String debugPageConversationCreated(int count) {
    return '已创建包含 $count 条消息的调试对话。';
  }

  @override
  String debugPageCreateConversationFailed(String error) {
    return '创建调试对话失败：$error';
  }

  @override
  String debugPageOversizedConversationTitle(int sizeMB) {
    return '超大对话测试（$sizeMB MB）';
  }

  @override
  String debugPageManyMessagesConversationTitle(int count) {
    return '$count 条消息测试';
  }

  @override
  String debugPageDailyMixedMarkdownConversationTitle(int count) {
    return '$count 条日常混合 Markdown 消息测试';
  }

  @override
  String debugPageLongReasoningConversationTitle(int count) {
    return '$count 条长思考链测试';
  }

  @override
  String get debugPageOversizedConversationSeedText =>
      '这是一段用于复现超大对话渲染卡顿的长调试文本。它包含重复的 Markdown 风格文本、标点、中文内容和普通词语，方便测试聊天渲染、存储和滚动性能。';

  @override
  String debugPageManyMessagesSeedText(String role, int index) {
    return '$role 消息 #$index：快速随机调试样例，用于测试列表渲染、滚动稳定性、消息分组和会话历史性能。';
  }

  @override
  String get migrationIntroTitle => '升级聊天记录存储';

  @override
  String get migrationIntroSubtitle =>
      'Kelivo 将聊天记录迁移到更快的 SQLite 数据库。升级会在应用打开前完成，避免新旧数据同时写入。';

  @override
  String get migrationBackupNote => '迁移开始前，会先导出包含设置、聊天记录和本地文件的 ZIP 备份。';

  @override
  String get migrationPerformanceNote =>
      '迁移后，启动、历史加载和搜索都会使用 SQLite 索引，长对话会更流畅。';

  @override
  String get migrationSourceDatabaseLabel => 'Hive';

  @override
  String get migrationTargetDatabaseLabel => 'SQLite';

  @override
  String get migrationChooseFolderButton => '选择文件夹并备份';

  @override
  String get migrationSaveBackupButton => '保存备份 ZIP';

  @override
  String get migrationBackingUpTitle => '正在备份';

  @override
  String get migrationBackingUpSubtitle =>
      '正在导出设置、聊天记录、上传文件、图片和字体。请保持 Kelivo 开启，等待备份完成。';

  @override
  String get migrationMigratingTitle => '正在迁移到 SQLite';

  @override
  String get migrationMigratingSubtitle =>
      '正在分批写入会话和消息，避免超大聊天记录占满内存。请保持 Kelivo 在前台，等待迁移完成。';

  @override
  String migrationBackingUpDetail(String fileName) {
    return '正在备份 $fileName';
  }

  @override
  String migrationMigratingDetail(int count) {
    return '已迁移 $count 条消息';
  }

  @override
  String get migrationMigratingPrepareDetail => '正在准备 SQLite 数据库';

  @override
  String get migrationMigratingToolEventsDetail => '正在迁移工具调用记录';

  @override
  String get migrationMigratingValidateDetail => '正在校验迁移数据';

  @override
  String get migrationBackupReadyDetail => '备份 ZIP 已准备好';

  @override
  String get migrationSavingBackupZipDetail => '正在保存备份 ZIP';

  @override
  String get migrationBackupFileSavedTitle => '备份 ZIP 已保存';

  @override
  String get migrationChecklistBackupFiles => '导出 Hive 备份 ZIP';

  @override
  String get migrationChecklistPrepareSqlite => '准备 SQLite 数据库';

  @override
  String get migrationChecklistMigrateMessages => '迁移会话和消息';

  @override
  String get migrationChecklistMigrateToolEvents => '迁移工具调用记录';

  @override
  String get migrationChecklistValidate => '校验迁移数据';

  @override
  String get migrationStepBackup => '备份';

  @override
  String get migrationStepMigrate => '迁移';

  @override
  String get migrationStepComplete => '完成';

  @override
  String get migrationCompleteTitle => '升级完成';

  @override
  String get migrationCompleteSubtitle =>
      '你的聊天记录已迁移到 SQLite。请重启 Kelivo 进入升级后的应用。';

  @override
  String get migrationConversationCount => '对话';

  @override
  String get migrationMessageCount => '消息';

  @override
  String get migrationConvertedCount => '已转换';

  @override
  String get migrationMalformedCount => '格式异常';

  @override
  String get migrationMissingFilesCount => '缺失文件';

  @override
  String get migrationRestartButton => '重启 Kelivo';

  @override
  String get migrationFailedTitle => '迁移失败';

  @override
  String get migrationFailedSubtitle => '原始 Hive 数据和备份都仍然保留。查看下方原因后可以重试。';

  @override
  String get migrationUnknownError => '未知迁移错误。';

  @override
  String get migrationFailureLogTitle => '失败日志';

  @override
  String get migrationRetryButton => '重试迁移';

  @override
  String get migrationSkipButton => '跳过迁移并全新开始';

  @override
  String get migrationSkipDialogTitle => '跳过迁移？';

  @override
  String get migrationSkipDialogMessage =>
      'Kelivo 将以空的聊天数据库启动。旧的聊天记录会保留在磁盘上（重命名为 .retired 后缀），但不会被迁移，也不会在应用中显示。之后如需找回，请使用已保存的备份 ZIP。';

  @override
  String get migrationSkipDialogCancel => '取消';

  @override
  String get migrationSkipDialogConfirm => '跳过并全新开始';

  @override
  String get migrationChatsExportDegradedNote =>
      'chats.json 导出因出错而被跳过。备份 ZIP 仍包含原始 Hive 文件，完整聊天记录未丢失。';

  @override
  String get timelineJumpToLatest => '跳到最新';

  @override
  String largeContentShowMore(int count) {
    return '再显示 $count 项';
  }

  @override
  String get largeContentCollapse => '收起';

  @override
  String get imageSettingsPageTitle => '图片处理';

  @override
  String get imageSettingsPageEditSectionTitle => '编辑';

  @override
  String get imageSettingsPageQualitySectionTitle => '上传图片质量';

  @override
  String get imageSettingsPageQualityOriginal => '原图';

  @override
  String get imageSettingsPageQualityOriginalSubtitle => '不压缩，原样上传';

  @override
  String get imageSettingsPageQualityHigh => '高质量';

  @override
  String get imageSettingsPageQualityHighSubtitle => '最长边 2048 像素 · 质量 90';

  @override
  String get imageSettingsPageQualityBalanced => '平衡';

  @override
  String get imageSettingsPageQualityBalancedSubtitle => '最长边 1568 像素 · 质量 85';

  @override
  String get imageSettingsPageQualitySaver => '节省流量';

  @override
  String get imageSettingsPageQualitySaverSubtitle => '最长边 1024 像素 · 质量 70';

  @override
  String get imageSettingsPageQualityCustom => '自定义';

  @override
  String get imageSettingsPageQualityCustomSubtitle => '自选压缩质量';

  @override
  String get imageSettingsPageCustomQualityTitle => '压缩质量';

  @override
  String get imageSettingsPageCompressTransparentTitle => '压缩透明及动态图片';

  @override
  String get imageSettingsPageCompressTransparentSubtitle =>
      '开启后将压缩透明 PNG、GIF 等格式；透明区域填充为白色，动图仅保留第一帧。';

  @override
  String get imageSettingsPageFooter =>
      '压缩在添加图片时进行，已保存或已发送的图片不受影响；压缩后图片以 JPEG 格式随消息发送。';

  @override
  String get memoryTraceSettingsTitle => '流程追踪';

  @override
  String get memoryTraceSettingsSubtitle => '逐步查看每次后台记忆处理的全过程';

  @override
  String get memoryTracePageTitle => '记忆流程追踪';

  @override
  String get memoryTraceRecordingSection => '记录';

  @override
  String get memoryTraceToggleTitle => '记录流程追踪';

  @override
  String get memoryTraceToggleSubtitle => '仅在内存中保留最近几次后台运行的提示词、模型回复与实际改动';

  @override
  String get memoryTraceRunsSection => '最近运行';

  @override
  String get memoryTraceEmptyTitle => '暂无追踪记录';

  @override
  String get memoryTraceEmptySubtitle => '后台记忆流程运行后，记录会显示在这里。';

  @override
  String get memoryTraceDisabledTitle => '记录已关闭';

  @override
  String get memoryTraceDisabledSubtitle => '开启记录后，下一次后台记忆运行才会被捕获。';

  @override
  String get memoryTraceClearAction => '清空';

  @override
  String get memoryTraceClearSheetTitle => '清空追踪记录';

  @override
  String get memoryTraceClearSheetMessage => '将删除所有已记录的追踪。追踪从不写入磁盘，因此不会影响其他数据。';

  @override
  String get memoryTraceClearConfirm => '清空记录';

  @override
  String get memoryTraceCancel => '取消';

  @override
  String get memoryTraceClearedToast => '追踪记录已清空';

  @override
  String get memoryTraceCopyAction => '复制';

  @override
  String get memoryTraceCopiedToast => '已复制到剪贴板';

  @override
  String get memoryTraceTriggerAuto => '自动';

  @override
  String get memoryTraceTriggerManual => '手动';

  @override
  String get memoryTraceTriggerTool => '工具调用';

  @override
  String get memoryTraceTriggerSummary => '对话摘要';

  @override
  String get memoryTraceScopeAssistant => '助手';

  @override
  String get memoryTraceScopeGlobal => '全局';

  @override
  String get memoryTraceStepGatekeeper => '守门判断';

  @override
  String get memoryTraceStepExtract => '记忆抽取';

  @override
  String get memoryTraceStepSmartAdd => '智能写入';

  @override
  String get memoryTraceStepDistiller => '用户画像提炼';

  @override
  String get memoryTraceStepSummary => '对话摘要生成';

  @override
  String get memoryTraceStepChatSearch => '历史对话检索';

  @override
  String get memoryTraceStepTool => '记忆工具';

  @override
  String get memoryTraceStatusSuccess => '成功';

  @override
  String get memoryTraceStatusFailed => '失败';

  @override
  String get memoryTraceStatusSkipped => '跳过';

  @override
  String get memoryTraceStatusRunning => '进行中';

  @override
  String get memoryTraceOutcomeAdvanced => '水位已推进';

  @override
  String get memoryTraceOutcomeHeld => '水位未推进';

  @override
  String get memoryTraceOutcomeForced => '强制推进';

  @override
  String get memoryTraceDetailTitle => '追踪详情';

  @override
  String get memoryTraceSectionOverview => '概览';

  @override
  String get memoryTraceSectionPrompt => '提示词';

  @override
  String get memoryTraceSectionResponse => '原始回复';

  @override
  String get memoryTraceSectionParsed => '解析结果';

  @override
  String get memoryTraceSectionMutations => '实际改动';

  @override
  String get memoryTraceFieldTime => '开始时间';

  @override
  String get memoryTraceFieldDuration => '耗时';

  @override
  String get memoryTraceFieldTrigger => '触发方式';

  @override
  String get memoryTraceFieldScope => '作用范围';

  @override
  String get memoryTraceFieldConversation => '对话';

  @override
  String get memoryTraceFieldAssistant => '助手';

  @override
  String get memoryTraceFieldWindow => '消息窗口';

  @override
  String get memoryTraceFieldWatermark => '水位';

  @override
  String get memoryTraceFieldOutcome => '结果';

  @override
  String get memoryTraceFieldError => '错误';

  @override
  String get memoryTraceMutationCreated => '新建';

  @override
  String get memoryTraceMutationMerged => '合并';

  @override
  String get memoryTraceMutationEdited => '修改';

  @override
  String get memoryTraceMutationArchived => '归档';

  @override
  String get memoryTraceMutationLinked => '关联';

  @override
  String get memoryTraceMutationProfileWritten => '写入画像字段';

  @override
  String get memoryTraceMutationProfileCleared => '清除画像字段';

  @override
  String get memoryTraceMutationSummary => '写入对话摘要';

  @override
  String get memoryTraceBefore => '改动前';

  @override
  String get memoryTraceAfter => '改动后';

  @override
  String get memoryTraceEmptyValue => '（空）';

  @override
  String memoryTraceStepsCount(int count) {
    return '$count 个步骤';
  }

  @override
  String memoryTraceMutationsCount(int count) {
    return '$count 项改动';
  }

  @override
  String memoryTraceRepeatCount(int count) {
    return '重复 $count 次';
  }

  @override
  String memoryTraceWindowValue(int size, int start, int end) {
    return '$size 条消息 · #$start–#$end';
  }

  @override
  String get memoryTraceShowMore => '展开全文';

  @override
  String get memoryTraceShowLess => '收起';

  @override
  String get messageStyleSettingsPageTitle => '消息样式';

  @override
  String get messageStyleSettingsPageReset => '重置';

  @override
  String get messageStyleSettingsPageResetConfirm => '恢复全部消息样式自定义？';

  @override
  String get messageStyleSettingsPageCancel => '取消';

  @override
  String get messageStyleSettingsPageLight => '浅色';

  @override
  String get messageStyleSettingsPageDark => '深色';

  @override
  String get messageStyleSettingsPageDefaultHint => '默认样式跟随当前主题，没有可调参数。';

  @override
  String get messageStyleSettingsPageStyleDefaultSubtitle => '跟随主题，不可调节';

  @override
  String get messageStyleSettingsPageStyleFrostedSubtitle => '半透明毛玻璃';

  @override
  String get messageStyleSettingsPageStyleSolidSubtitle => '不透明纯色底';

  @override
  String get messageStyleSettingsPageBlur => '模糊强度';

  @override
  String get messageStyleSettingsPageBlurHint => '模糊作用于气泡背后的内容，未设置聊天壁纸时效果不明显';

  @override
  String get messageStyleSettingsPageBackgroundColor => '背景颜色';

  @override
  String get messageStyleSettingsPageBackgroundOpacity => '背景不透明度';

  @override
  String get messageStyleSettingsPageBorderColor => '边框颜色';

  @override
  String get messageStyleSettingsPageBorderOpacity => '边框不透明度';

  @override
  String get messageStyleSettingsPageBorderWidth => '边框宽度';

  @override
  String get messageStyleSettingsPageTextColor => '文字颜色';

  @override
  String get messageStyleSettingsPageCornerRadius => '圆角半径';

  @override
  String get messageStyleSettingsPagePreviewUser => '这是一条用户消息';

  @override
  String get messageStyleSettingsPagePreviewAssistant => '这是一条助手回复。';

  @override
  String get messageStyleSettingsPagePreviewThinking => '思考中';

  @override
  String get messageStyleSettingsPageRoleUser => '用户';

  @override
  String get messageStyleSettingsPageRoleAssistant => '助手';

  @override
  String get messageStyleSettingsPageRoleAssistantHint =>
      '助手设定同时作用于思考、工具调用和翻译卡片。';
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
  String get settingsPageDisplay => '偏好設定';

  @override
  String get settingsPageDisplaySubtitle => '外觀、行為與互動偏好';

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
  String get storageSpaceCategoryFonts => '字體';

  @override
  String get storageSpaceCategoryLocalModels => '本地模型';

  @override
  String get storageSpaceOtherHint => '包括匯入字體、本地下載模型和其他應用程式檔案。';

  @override
  String get storageSpaceSubOtherApp => '其他檔案';

  @override
  String get storageSpaceCategoryChatData => '聊天記錄';

  @override
  String get storageSpaceCategoryLegacyChatData => '聊天記錄（舊）';

  @override
  String get storageSpaceCategoryRestoreTraces => '還原痕跡';

  @override
  String get storageSpaceRestoreTracesHint => '還原完成後保留的舊資料快照。清理不會影響目前的應用程式資料。';

  @override
  String get storageSpaceClearRestoreTracesButton => '清理還原痕跡';

  @override
  String get storageSpaceClearRestoreTracesConfirmMessage =>
      '確定清理已完成還原留下的舊資料快照嗎？目前的資料庫、設定和檔案不會受到影響。';

  @override
  String get storageSpaceSubCompletedRestoreRuns => '已完成的還原快照';

  @override
  String get storageSpaceCategoryAssistantData => '助理';

  @override
  String get storageSpaceCategoryCache => '快取';

  @override
  String get storageSpaceCategoryLogs => '日誌';

  @override
  String get storageSpaceCategoryOther => '其他';

  @override
  String storageSpaceFilesCount(int count) {
    return '$count 個檔案';
  }

  @override
  String get storageSpaceSafeToClearHint => '可安全清理，不影響聊天記錄。';

  @override
  String get storageSpaceLegacyChatDataHint =>
      '這是遷移到 SQLite 前保留的 Hive 舊檔案。清理後不會刪除目前的聊天記錄。';

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
  String get storageSpaceSubChatDatabase => '聊天資料庫';

  @override
  String get storageSpaceSubChatWriteAheadLog => '寫入日誌';

  @override
  String get storageSpaceSubChatSharedMemory => '共享記憶體索引';

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
  String get storageSpaceSubLogsContext => '上下文日誌';

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
  String get storageSpaceClearLegacyChatDataButton => '清理舊聊天記錄';

  @override
  String get storageSpaceExportLegacyChatFileButton => '匯出';

  @override
  String storageSpaceExportDone(Object fileName) {
    return '已匯出 $fileName';
  }

  @override
  String storageSpaceExportFailed(Object error) {
    return '匯出失敗：$error';
  }

  @override
  String get storageSpaceClearLegacyChatDataConfirmMessage =>
      '確定清理保留的舊聊天檔案嗎？目前的 SQLite 聊天記錄不會受到影響。';

  @override
  String get storageSpaceViewLogsButton => '查看日誌';

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
  String get storageSpaceSourceLabel => '來源';

  @override
  String get storageSpaceSourceAll => '全部';

  @override
  String get storageSpaceSourceUserUpload => '使用者上傳';

  @override
  String get storageSpaceSourceAssistant => '助理傳送';

  @override
  String get storageSpaceSortLabel => '排序';

  @override
  String get storageSpaceSortNewest => '最新';

  @override
  String get storageSpaceSortOldest => '最舊';

  @override
  String get storageSpaceSortLargest => '最大';

  @override
  String get storageSpaceSortSmallest => '最小';

  @override
  String get settingsPageAboutSection => '關於';

  @override
  String get settingsPageAbout => '關於';

  @override
  String get settingsPageStatistics => '統計';

  @override
  String get settingsPageDocs => '使用文件';

  @override
  String get settingsPageLogs => '日誌';

  @override
  String get settingsPageSponsor => '贊助';

  @override
  String get settingsPageShare => '分享';

  @override
  String get statsPageTitle => '統計';

  @override
  String get statsPageRangeAllTime => '全部';

  @override
  String get statsPageRangeLast30Days => '最近 30 天';

  @override
  String get statsPageRangePreviousMonth => '上個月';

  @override
  String get statsPageRangePreviousQuarter => '上個季度';

  @override
  String get statsPageRangeCustom => '自訂';

  @override
  String get statsPageHeatmapTitle => '聊天熱力圖';

  @override
  String get statsPageHeatmapLess => '少';

  @override
  String get statsPageHeatmapMore => '多';

  @override
  String get statsPageSummaryTitle => '總覽';

  @override
  String get statsPageTotalConversations => '總對話數';

  @override
  String get statsPageTotalMessages => '總消息數';

  @override
  String get statsPageInputTokens => '輸入 Tokens';

  @override
  String get statsPageOutputTokens => '輸出 Tokens';

  @override
  String get statsPageCachedTokens => '快取 Tokens';

  @override
  String get statsPageLaunchCount => '應用啟動次數';

  @override
  String get statsPageUsageTrendTitle => '用量趨勢';

  @override
  String get statsPageModelUsageTitle => '模型使用率';

  @override
  String get statsPageAssistantUsageTitle => '助手使用率';

  @override
  String get statsPageTopicVolumeTitle => '話題內容量';

  @override
  String get statsPageModelColumn => '模型';

  @override
  String get statsPageAssistantColumn => '助手';

  @override
  String get statsPageTopicColumn => '話題';

  @override
  String get statsPageMessagesColumn => '消息數';

  @override
  String get statsPageTopicsColumn => '話題數';

  @override
  String get statsPageEmptyTitle => '暫無統計資料';

  @override
  String get statsPageShowAllTooltip => '查看全部';

  @override
  String get statsPageClose => '關閉';

  @override
  String get statsPageUnknownProvider => '未知供應商';

  @override
  String get statsPageUnknownAssistant => '預設助手';

  @override
  String get statsPageUnknownModel => '未知模型';

  @override
  String get statsPageUnknownTopic => '未命名話題';

  @override
  String get statsPageCustomRangeTitle => '自訂時間段';

  @override
  String get statsPageCustomRangeStart => '開始';

  @override
  String get statsPageCustomRangeEnd => '結束';

  @override
  String get statsPageCustomRangeCancel => '取消';

  @override
  String get statsPageCustomRangeApply => '套用';

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
  String get sponsorPageScanQrHint => '掃描二維碼贊助';

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
  String get mermaidImageTab => '圖片';

  @override
  String get mermaidCodeTab => '程式碼';

  @override
  String get mermaidFullScreen => '全螢幕';

  @override
  String get mermaidGeneratingImage => '圖片生成中';

  @override
  String get mermaidGenerationFailedHint => '生成失敗，換個方式問問吧';

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
  String assistantProviderSampleAssistantSystemPrompt(String model_name) {
    return '你是$model_name，一位樂於助人的 AI 助理。請準確、簡潔地回答問題；不確定時如實說明。需要時可使用清晰結構（短段落或列表）。預設使用使用者的語言回覆。';
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
  String get mcpTransportTagSse => 'SSE';

  @override
  String get mcpTransportTagHttp => 'HTTP';

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
  String get homePageAudioAttachmentUnsupported =>
      '目前模型不支援音訊附件，請切換到支援音訊輸入的模型或移除音訊檔案後再試。';

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
  String get homePageDeleteMessage => '刪除本版本';

  @override
  String get homePageDeleteMessageConfirm => '確定要刪除目前版本嗎？此操作不可撤銷。';

  @override
  String get homePageDeleteAllVersions => '刪除全部版本';

  @override
  String get homePageDeleteAllVersionsConfirm => '確定要刪除這則訊息的全部版本嗎？此操作不可撤銷。';

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
  String get assistantEditPageLocalToolsTab => '本機工具';

  @override
  String get assistantEditTabLayoutTooltip => '自訂標籤頁';

  @override
  String get assistantEditTabLayoutTitle => '自訂標籤頁';

  @override
  String get assistantEditTabLayoutSubtitle => '拖動標籤頁調整順序，關閉暫時用不到的標籤頁。';

  @override
  String get assistantEditOutlineModeTitle => '二級列表樣式';

  @override
  String get assistantEditOutlineModeSubtitle => '先顯示助理概覽，再從列表進入各個設定項。';

  @override
  String get assistantEditTabLayoutResetTooltip => '重設標籤頁佈局';

  @override
  String get assistantEditTabLayoutAtLeastOneVisible => '至少保留一個可見標籤頁';

  @override
  String assistantEditTabLayoutDragHandle(String tab) {
    return '拖動以調整 $tab 的順序';
  }

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
  String get assistantRegexScopeReplaceOnly => '僅替換';

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
  String get assistantEditUseAssistantAvatarSubtitle => '在聊天中使用助理頭像取代模型頭像';

  @override
  String get assistantEditUseAssistantNameTitle => '使用助理名字';

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
  String get desktopNavGlobalSearchTooltip => '全域搜尋';

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
  String get displaySettingsPageIosBackgroundChatTitle => 'iOS 後台生成';

  @override
  String get iosBackgroundSettingsPageTitle => 'iOS 後台生成';

  @override
  String get iosBackgroundStatusOn => '開啟';

  @override
  String get iosBackgroundStatusOff => '關閉';

  @override
  String get iosBackgroundGenerationEnableTitle => '後台生成';

  @override
  String get iosBackgroundGenerationEnableSubtitle =>
      'App 離開前台後，使用 iOS 分配的後台時間繼續目前回覆。';

  @override
  String get iosBackgroundTaskRefreshTitle => '後台任務恢復';

  @override
  String get iosBackgroundTaskRefreshSubtitle => '在系統條件允許時，向 iOS 請求重新整理和處理機會。';

  @override
  String get iosLiveActivityTitle => '即時活動';

  @override
  String get iosLiveActivitySubtitle => '支援時在鎖定畫面和動態島顯示後台回覆狀態。';

  @override
  String get iosBackgroundNotificationsTitle => '任務通知';

  @override
  String get iosBackgroundNotificationsSubtitle => '後台回覆完成或中斷時發送本機通知。';

  @override
  String get iosBackgroundLimitNoticeTitle => 'iOS 仍可能暫停任務';

  @override
  String get iosBackgroundLimitNoticeBody =>
      '這些選項使用 Apple 支援的後台時間、BackgroundTasks、通知和即時活動。它們能提升連續性，但不能強制 iOS 永久保持 Kelivo 運行。';

  @override
  String get iosBackgroundUnsupportedLiveActivity =>
      '需要 iOS 16.1 或更高版本，並在系統設定中允許即時活動。';

  @override
  String get iosBackgroundNativeStatusTitle => '系統狀態';

  @override
  String get iosBackgroundNativeStatusUnavailable => '需要在 iOS 上運行後查看';

  @override
  String get iosBackgroundLiveActivityAvailable => '即時活動可用';

  @override
  String get iosBackgroundLiveActivityUnavailable => '即時活動不可用';

  @override
  String get iosBackgroundNotificationsAuthorized => '通知已允許';

  @override
  String get iosBackgroundNotificationsNotAuthorized => '通知未允許';

  @override
  String get iosBackgroundGenerationActiveTitle => 'Kelivo 正在生成';

  @override
  String get iosBackgroundGenerationActiveDetail => '助理正在後台回覆';

  @override
  String get iosBackgroundGenerationStreamingDetail => '正在接收助理回覆';

  @override
  String iosBackgroundGenerationTokenCount(int count) {
    return '$count tokens';
  }

  @override
  String get iosBackgroundGenerationCompleteTitle => '生成完成';

  @override
  String get iosBackgroundGenerationCompleteDetail => '助理回覆已準備好';

  @override
  String get iosBackgroundGenerationInterruptedTitle => '生成已中斷';

  @override
  String get iosBackgroundGenerationInterruptedDetail => '後台回覆在完成前停止';

  @override
  String get iosBackgroundGenerationCancelledDetail => '生成已停止';

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
  String get assistantEditPromptTimeVarWarning =>
      '在系統提示詞中使用時間變數會讓每一輪請求的開頭都不同，Prompt 快取無法命中，費用和首字延遲都會上升。需要讓模型知道當前時間時，請改用下方的「追加當前時間」開關。';

  @override
  String get assistantEditPromptAppendTimeTitle => '追加當前時間';

  @override
  String get assistantEditPromptAppendTimeSubtitle =>
      '在每條使用者訊息末尾追加傳送時刻。時間在請求末尾，不影響 Prompt 快取。';

  @override
  String get assistantEditPromptAppendTimeInfoTitle => '追加時間格式';

  @override
  String assistantEditPromptAppendTimeInfoBody(String example) {
    return '開啟後，會在每條使用者訊息末尾先空一行，再追加如下標籤：\n\n$example\n\n時間取該訊息自己的傳送時刻，重試時保持不變。';
  }

  @override
  String get assistantEditPromptAppendTimeInfoClose => '知道了';

  @override
  String get assistantEditPromptTimeVarDialogTitle => '系統提示詞中含時間變數';

  @override
  String assistantEditPromptTimeVarDialogBody(String variables) {
    return '你的系統提示詞裡用了 $variables。系統提示詞每次請求都會重新渲染，含時間變數會讓每一輪請求的開頭都不同，Prompt 快取無法命中。建議移除這些變數，改用「追加當前時間」——它把時間放在請求末尾，不影響前綴。';
  }

  @override
  String get assistantEditPromptTimeVarDialogRemove => '去移除';

  @override
  String get assistantEditPromptTimeVarDialogKeep => '仍然開啟';

  @override
  String get codeBlockPreviewButton => '預覽';

  @override
  String get codeBlockSaveAsButton => '另存為檔案';

  @override
  String get codeBlockCollapseButton => '摺疊';

  @override
  String get codeBlockExpandButton => '展開';

  @override
  String get codeBlockDefaultFileNameStem => '程式碼';

  @override
  String get markdownTableLabel => '表格';

  @override
  String get markdownTableExportCsvTooltip => '匯出 CSV';

  @override
  String get markdownTableSaveImageTooltip => '儲存到相簿';

  @override
  String get markdownTableDefaultFileNameStem => '表格';

  @override
  String get markdownTableCopiedCsvSnackbar => '已複製 CSV，長按複製可複製為圖片';

  @override
  String get markdownTableCopiedMarkdownSnackbar => '已複製表格';

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
  String get backupPageRestartContent => '匯入成功。重新啟動 Kelivo 後將安全套用。';

  @override
  String backupPageRestartContentWithSkipped(int count) {
    return '匯入已完成，但已略過 $count 個訊息順序無效的會話。重新啟動 Kelivo 後將安全套用已匯入的資料。';
  }

  @override
  String get restartAppFailedMessage => 'Kelivo 無法自動重新啟動，請完全關閉後再重新開啟。';

  @override
  String get backupRestoreRolledBackTitle => '已保留原有資料';

  @override
  String get backupRestoreRolledBackContent => '還原未能完成。Kelivo 已驗證並保留先前的資料。';

  @override
  String get backupRestoreFailureTitle => '還原需要處理';

  @override
  String get backupRestoreFailureContent =>
      'Kelivo 無法驗證完整的原有或新資料，因此未開啟聊天資料。請關閉 Kelivo 後重試；若問題持續發生，請保留診斷碼以供支援人員排查。';

  @override
  String get backupRestoreBusinessLeaseUnavailableTitle => 'Kelivo 已在執行';

  @override
  String get backupRestoreBusinessLeaseUnavailableContent =>
      'Kelivo 的資料仍由另一個應用程式程序使用。請關閉其他 Kelivo 視窗後重新啟動；目前程序尚未開啟聊天資料。';

  @override
  String get backupRestoreFailureRestartButton => '重新啟動 Kelivo';

  @override
  String get backupRestoreFailureCopyButton => '複製診斷碼';

  @override
  String get backupRestoreFailureCopied => '已複製診斷碼';

  @override
  String backupRestoreFailureDiagnostic(String code) {
    return '診斷碼：$code';
  }

  @override
  String get startupRecoveryMoreOptions => '更多復原選項';

  @override
  String get startupRecoveryRepairButton => '修復並重新啟動';

  @override
  String get startupRecoveryExportButton => '匯出我的資料副本';

  @override
  String get startupRecoveryResetButton => '重設資料';

  @override
  String get startupRecoveryBusy => '處理中…';

  @override
  String get startupRecoveryExportSucceeded => '已儲存一份資料副本。';

  @override
  String get startupRecoveryExportFailed => '無法匯出資料副本。';

  @override
  String get startupRecoveryRepairFailed => '修復未能解決問題。請先匯出資料副本，然後重設。';

  @override
  String get startupRecoveryResetFailed => '重設失敗。請完全關閉 Kelivo 後再重新開啟。';

  @override
  String get startupRecoveryResetDialogTitle => '重設全部資料？';

  @override
  String get startupRecoveryResetDialogContent =>
      '這會永久刪除本裝置上 Kelivo 的資料庫並重新開始。如果之後可能還需要這些資料，請先匯出一份副本。此操作無法復原。';

  @override
  String get startupRecoveryResetDialogConfirm => '重設並重新啟動';

  @override
  String get startupRecoveryResetDialogCancel => '取消';

  @override
  String get startupDatabaseUpdateRequiredTitle => '請更新 Kelivo 以繼續';

  @override
  String get startupDatabaseUpdateRequiredContent =>
      '本裝置上的聊天資料庫由更新版本的 Kelivo 建立，目前版本無法開啟。資料未被改動。請安裝最新版 Kelivo 後重新開啟。';

  @override
  String backupPageRestoreFailedMessage(String error) {
    return '還原失敗：$error';
  }

  @override
  String backupPageExportFailedMessage(String error) {
    return '匯出失敗：$error';
  }

  @override
  String get backupPageOK => '好的';

  @override
  String get backupPageCancel => '取消';

  @override
  String get backupPageSelectImportMode => '選擇匯入模式';

  @override
  String get backupPageSelectImportModeDescription =>
      '請選擇還原方式。聊天與檔案開關決定本次還原的元件。';

  @override
  String get backupPageOverwriteMode => '完全覆蓋';

  @override
  String get backupPageOverwriteModeDescription => '僅替換已選元件；保留未選元件及無關的本機設定';

  @override
  String get backupPageMergeMode => '合併';

  @override
  String get backupPageMergeModeDescription =>
      '保留本機資料並加入備份資料；相同對話會略過，衝突對話會重新分配 ID。';

  @override
  String get backupPageRestore => '還原';

  @override
  String get backupPageBackupUploaded => '已上傳備份';

  @override
  String get backupPageBackup => '立即備份';

  @override
  String get backupPageExporting => '正在匯出...';

  @override
  String get backupProgressCancel => '取消';

  @override
  String get backupProgressCancelled => '已取消';

  @override
  String get backupProgressPreparing => '準備中';

  @override
  String get backupProgressSnapshotting => '正在建立資料庫快照';

  @override
  String get backupProgressPacking => '正在打包';

  @override
  String get backupProgressVerifying => '正在校驗';

  @override
  String get backupProgressUploading => '正在上傳';

  @override
  String get backupProgressDownloading => '正在下載';

  @override
  String get backupProgressExtracting => '正在解壓';

  @override
  String get backupProgressValidating => '正在驗證';

  @override
  String get backupProgressReadingSettings => '正在讀取設定';

  @override
  String get backupProgressStaging => '正在暫存';

  @override
  String get backupProgressCommitting => '正在提交';

  @override
  String get backupProgressImportingSessions => '正在匯入對話';

  @override
  String get backupProgressImportingMessages => '正在匯入訊息';

  @override
  String get backupProgressMaterializingFiles => '正在寫入檔案';

  @override
  String get backupProgressListingRemote => '正在列出遠端備份';

  @override
  String get backupProgressFinalizing => '正在完成';

  @override
  String backupProgressBytes(String done, String total) {
    return '$done / $total';
  }

  @override
  String backupProgressItems(String done, String total) {
    return '$done / $total';
  }

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
  String get backupPageDeleteConfirmTitle => '確認刪除';

  @override
  String backupPageDeleteConfirmContent(Object name) {
    return '確定要刪除遠端備份「$name」嗎？此操作不可撤銷。';
  }

  @override
  String get backupPageBackupManagement => '備份管理';

  @override
  String get backupPageWebDavBackup => 'WebDAV 備份';

  @override
  String get backupPageWebDavServerSettings => 'WebDAV 伺服器設定';

  @override
  String get backupPageS3Backup => 'S3 備份';

  @override
  String get backupPageS3ServerSettings => 'S3 伺服器設定';

  @override
  String get backupPageS3Endpoint => 'Endpoint（地址）';

  @override
  String get backupPageS3Region => 'Region（區域）';

  @override
  String get backupPageS3Bucket => 'Bucket';

  @override
  String get backupPageS3AccessKeyId => 'Access Key ID';

  @override
  String get backupPageS3SecretAccessKey => 'Secret Access Key';

  @override
  String get backupPageS3SessionToken => 'Session Token（可選）';

  @override
  String get backupPageS3Prefix => '前綴（目錄）';

  @override
  String get backupPageS3PathStyle => '路徑風格（Path-style）';

  @override
  String get backupPageUserAgent => 'User-Agent';

  @override
  String get backupPageUserAgentHint => '可選';

  @override
  String get backupPageSave => '儲存';

  @override
  String get backupPageBackupNow => '立即備份';

  @override
  String get backupPageLocalBackup => '本機備份';

  @override
  String get backupPageImportFromCherryStudio => '從 Cherry Studio 匯入';

  @override
  String backupPageCherryStudioUnsupportedBackupVersion(String version) {
    return '此備份使用 Cherry Studio 格式版本 $version，Kelivo 目前尚無法匯入。請改用 Cherry Studio v1 匯出備份，或等待後續版本支援 Cherry Studio v2。';
  }

  @override
  String get backupPageImportFromChatbox => '從 Chatbox 匯入';

  @override
  String get backupReminderSectionTitle => '備份提醒';

  @override
  String get backupReminderEnableTitle => '定期提醒我備份';

  @override
  String get backupReminderFrequencyTitle => '提醒頻率';

  @override
  String get backupReminderTimeTitle => '提醒時間';

  @override
  String get backupReminderTimeInputHint => 'HH:mm';

  @override
  String get backupReminderTimeInvalid => '請輸入 00:00 到 23:59 之間的時間。';

  @override
  String get backupReminderLastBackupTitle => '上次備份';

  @override
  String get backupReminderNextReminderTitle => '下次提醒';

  @override
  String get backupReminderNever => '從未';

  @override
  String get backupReminderDisabled => '關閉';

  @override
  String get backupReminderDueNow => '現在已到期';

  @override
  String get backupReminderEveryDay => '每天';

  @override
  String get backupReminderEveryThreeDays => '每 3 天';

  @override
  String get backupReminderEveryWeek => '每週';

  @override
  String get backupReminderEveryFourteenDays => '每 14 天';

  @override
  String get backupReminderEveryMonth => '每月';

  @override
  String backupReminderCustomDays(int days) {
    return '每 $days 天';
  }

  @override
  String get backupReminderCustomOption => '自訂...';

  @override
  String get backupReminderCustomDialogTitle => '自訂頻率';

  @override
  String get backupReminderCustomDialogDescription => '輸入兩次備份提醒之間間隔多少天。';

  @override
  String get backupReminderCustomDaysLabel => '天數';

  @override
  String get backupReminderCustomDaysInvalid => '請輸入 1 到 365 之間的數字。';

  @override
  String get backupReminderSidebarTitle => '備份提醒';

  @override
  String get backupReminderSidebarSubtitle => '已經到你設定的備份週期了。';

  @override
  String get backupReminderSidebarAction => '去備份';

  @override
  String get backupReminderSnoozeTooltip => '稍後提醒';

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
  String get userMessageEditSaveOnly => '僅儲存';

  @override
  String get userMessageEditUnsupportedSnackbar => '該內容不支援編輯';

  @override
  String get userMessageEditOverwriteTitle => '提示';

  @override
  String get userMessageEditOverwriteContent => '修改將覆蓋輸入框已有內容，是否覆蓋？';

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
  String get compressContext => '壓縮上下文';

  @override
  String get compressContextDesc => '總結對話並開始新聊天';

  @override
  String get clearContextDesc => '標記上下文分界點';

  @override
  String get contextManagement => '上下文管理';

  @override
  String get compressingContext => '正在壓縮上下文...';

  @override
  String get compressContextFailed => '壓縮上下文失敗';

  @override
  String get compressContextNoMessages => '沒有可壓縮的訊息';

  @override
  String get compressContextNoConversation => '沒有可壓縮的對話';

  @override
  String get compressContextNoModel => '未設定壓縮模型';

  @override
  String get compressContextEmptySummary => '壓縮返回了空摘要';

  @override
  String get compressContextOptionsTitle => '壓縮上下文';

  @override
  String get compressContextOptionsDesc => '選擇要傳送給壓縮模型的目前聊天範圍。';

  @override
  String get compressContextKeepStart => '最開始';

  @override
  String get compressContextKeepRecent => '最近';

  @override
  String get compressContextUnlimited => '無限制';

  @override
  String get compressContextMaxCharsLabel => '字元數';

  @override
  String get compressContextInvalidLimit => '請輸入大於 0 的字元數';

  @override
  String get compressContextStartButton => '開始壓縮';

  @override
  String get compressContextModelLabel => '壓縮模型';

  @override
  String get compressContextModelUnset => '選擇模型';

  @override
  String get compressContextKeepRecentMessages => '保留N條';

  @override
  String get compressContextKeepCountLabel => '保留最近條數';

  @override
  String get compressContextKeepAllMessages => '保留條數涵蓋全部訊息，無內容可壓縮';

  @override
  String compressContextEstimatePreview(
    int summarized,
    int kept,
    int minTokens,
    int maxTokens,
    int totalTokens,
  ) {
    return '總結 $summarized 字元，原樣保留 $kept 字元 → 壓縮後約 $minTokens–$maxTokens tokens（原文約 $totalTokens tokens）';
  }

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
  String get messageMoreSheetSelectMessages => '選擇訊息';

  @override
  String get messageMoreSheetCreateBranch => '建立分支';

  @override
  String get messageMoreSheetDelete => '刪除本版本';

  @override
  String get messageMoreSheetDeleteAllVersions => '刪除全部版本';

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
  String get reasoningBudgetSheetXhigh => '極限推理';

  @override
  String get reasoningBudgetSheetMax => '全力推理';

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
  String get reasoningBudgetSheetXhighSubtitle => '使用最大推理深度，適合最複雜的問題';

  @override
  String get reasoningBudgetSheetCustomLabel => '自訂推理預算';

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
  String get chatMessageWidgetAttachmentUnavailable => '附件不可用';

  @override
  String chatMessageWidgetCitationsTitle(int count) {
    return '引用（共$count條）';
  }

  @override
  String get chatMessageWidgetSearchResultsTitle => '搜尋結果';

  @override
  String get chatMessageWidgetCitationSourcesTitle => '引用來源';

  @override
  String get chatMessageWidgetRegenerateTooltip => '重新生成';

  @override
  String get chatMessageWidgetRegenerateConfirmTitle => '確認重新生成';

  @override
  String get chatMessageWidgetRegenerateConfirmContent =>
      '重新生成只會更新目前訊息，不會刪除下面的訊息。確定要繼續嗎？';

  @override
  String get chatMessageWidgetRegenerateConfirmDeleteTrailingContent =>
      '重新生成將會刪除此訊息下面的所有訊息，且無法復原。確定要繼續嗎？';

  @override
  String get chatMessageWidgetRegenerateConfirmCancel => '取消';

  @override
  String get chatMessageWidgetRegenerateConfirmOk => '重新生成';

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
  String chatMessageWidgetWebSearch(String query) {
    return '聯網檢索: $query';
  }

  @override
  String get chatMessageWidgetBuiltinSearch => '模型內建搜尋';

  @override
  String get chatMessageWidgetReadClipboard => '讀取剪貼簿';

  @override
  String get chatMessageWidgetWriteClipboard => '寫入剪貼簿';

  @override
  String get chatMessageWidgetSpeakingTitle => '正在朗讀:';

  @override
  String chatMessageWidgetSpeakText(String text) {
    return '正在朗讀: $text';
  }

  @override
  String get chatMessageWidgetMemoryRead => '讀取記憶';

  @override
  String get chatMessageWidgetMemoryUpdate => '更新記憶';

  @override
  String get chatMessageWidgetMemorySearchProfile => '檢索記憶';

  @override
  String get chatMessageWidgetMemoryEdit => '編輯記憶';

  @override
  String get chatMessageWidgetMemoryDelete => '刪除記憶';

  @override
  String get chatMessageWidgetUpdateUserProfile => '更新使用者畫像';

  @override
  String get chatMessageWidgetChatSearch => '搜尋歷史對話';

  @override
  String get chatMessageWidgetCreateMemory => '建立記憶';

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
  String get chatMessageWidgetImages => '圖片';

  @override
  String chatMessageWidgetCitationsCount(int count) {
    return '$count個引用';
  }

  @override
  String chatSelectionSelectedCountTitle(int count) {
    return '已選擇$count條訊息';
  }

  @override
  String get chatSelectionExportTxt => 'TXT';

  @override
  String get chatSelectionExportMd => 'MD';

  @override
  String get chatSelectionExportImage => '圖片';

  @override
  String get chatSelectionThinkingTools => '思考工具';

  @override
  String get chatSelectionThinkingContent => '思考內容';

  @override
  String get chatSelectionDeleteSelected => '刪除所選';

  @override
  String get chatSelectionSelectMessagesToDelete => '請選擇要刪除的訊息';

  @override
  String chatSelectionDeleteSelectedConfirm(int count) {
    return '確定要刪除已選擇的$count個版本嗎？此操作不可撤銷。';
  }

  @override
  String chatSelectionDeleteSelectedAllVersionsConfirm(int count) {
    return '確定要刪除已選擇$count條訊息的全部版本嗎？此操作不可撤銷。';
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
  String get displaySettingsPageEnableAssistantMarkdownTitle =>
      '助手訊息 Markdown 渲染';

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
  String get messageExportThinkingContentLabel => '思考內容';

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
  String get sideDrawerMenuCopy => '複製';

  @override
  String get sideDrawerMenuMoveTo => '移動到';

  @override
  String get sideDrawerMenuDelete => '刪除';

  @override
  String get sideDrawerMenuSelect => '多選';

  @override
  String sideDrawerSelectionTitle(int count) {
    return '已選 $count 項';
  }

  @override
  String get sideDrawerSelectionSelectAll => '全選';

  @override
  String get sideDrawerSelectionDeselectAll => '取消全選';

  @override
  String get sideDrawerSelectionPin => '置頂';

  @override
  String get sideDrawerSelectionUnpin => '取消置頂';

  @override
  String get sideDrawerSelectionMove => '移動';

  @override
  String get sideDrawerSelectionDelete => '刪除';

  @override
  String get sideDrawerSelectionDeleteConfirmTitle => '刪除話題';

  @override
  String sideDrawerSelectionDeleteConfirmContent(int count) {
    return '確定刪除 $count 個話題？';
  }

  @override
  String sideDrawerDeleteSelectedSnackbar(int count) {
    return '已刪除 $count 個話題';
  }

  @override
  String sideDrawerMoveSelectedSnackbar(int count) {
    return '已移動 $count 個話題';
  }

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
  String get sideDrawerSearchHint => '搜尋當前助理';

  @override
  String get sideDrawerSearchAssistantsHint => '搜尋助理';

  @override
  String get sideDrawerTopicSearchModeLabel => '話題模式';

  @override
  String get sideDrawerGlobalSearchModeLabel => '全域模式';

  @override
  String get sideDrawerSearchModeSwipeToTopicHint => '左/右滑搜尋欄切換到話題搜尋';

  @override
  String get sideDrawerSearchModeSwipeToGlobalHint => '左/右滑搜尋欄切換到全域搜尋';

  @override
  String get sideDrawerGlobalSearchHint => '搜尋全部會話';

  @override
  String get sideDrawerGlobalSearchEmptyHint => '在標題與訊息中全域搜尋';

  @override
  String get sideDrawerGlobalSearchNoResults => '沒有匹配的會話';

  @override
  String sideDrawerGlobalSearchResultCount(int count) {
    return '共 $count 筆結果';
  }

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
  String get providerAvatarChooseBuiltInIcon => '選擇內建圖示';

  @override
  String get providerAvatarIconDialogTitle => '選擇內建圖示';

  @override
  String get providerAvatarIconSearchHint => '搜尋圖示';

  @override
  String get providerAvatarIconNoResults => '找不到圖示';

  @override
  String get providerAvatarInputLobehubIcon => '輸入 LobeHub 圖示';

  @override
  String get providerAvatarChooseLobehubIcon => '輸入 LobeHub 圖示';

  @override
  String get providerAvatarLobehubDialogTitle => '輸入 LobeHub 圖示';

  @override
  String get providerAvatarLobehubDialogHint => '輸入 LobeHub 圖示名稱，如 openai';

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
  String get chatInputBarVoiceInputTooltip => '語音輸入';

  @override
  String get chatInputBarVoiceCancelTooltip => '取消錄音';

  @override
  String get chatInputBarVoiceStopTooltip => '停止並轉為文字';

  @override
  String get chatInputBarVoiceSendTooltip => '轉文字並發送';

  @override
  String get chatInputBarVoiceTranscribing => '正在辨識…';

  @override
  String get chatInputBarImageProcessing => '正在處理圖片';

  @override
  String get chatInputBarImageMode => '繪圖模式';

  @override
  String get chatInputBarDisableImageModeTooltip => '關閉繪圖模式';

  @override
  String get chatInputBarQueuedPending => '排隊中';

  @override
  String get chatInputBarQueuedCancel => '取消排隊';

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
  String get mcpPageStatusAuthorizationRequired => '需要授權';

  @override
  String get mcpPageStatusAuthorizing => '授權中…';

  @override
  String get mcpPageStatusDisabled => '已停用';

  @override
  String get mcpPageOAuthRequired => '需要 OAuth 登入';

  @override
  String get mcpPageOAuthSignIn => 'OAuth 登入';

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
  String get titleModelThinkingTitle => '是否開啟思考';

  @override
  String get defaultModelPageSummaryModelTitle => '摘要模型';

  @override
  String get defaultModelPageSummaryModelSubtitle => '用於生成對話摘要的模型，推薦使用快速且便宜的模型';

  @override
  String get defaultModelPageSuggestionModelTitle => '聊天建議模型';

  @override
  String get defaultModelPageSuggestionModelSubtitle =>
      '用於在助手回覆後生成繼續對話的建議氣泡。選擇模型後才會啟用。';

  @override
  String get assistantEditRecentChatsSummaryFrequencyTitle => '摘要更新頻率';

  @override
  String get assistantEditRecentChatsSummaryFrequencyDescription =>
      '累計達到所選條數的新訊息後，會更新歷史聊天摘要。';

  @override
  String assistantEditRecentChatsSummaryFrequencyOption(int count) {
    return '每 $count 則';
  }

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomButton => '自訂';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomTitle => '自訂摘要頻率';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomDescription =>
      '輸入累計多少則新訊息後再更新歷史聊天摘要。';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomLabel => '新訊息數量';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomHint =>
      '請輸入大於 0 的整數';

  @override
  String get assistantEditRecentChatsSummaryFrequencyCustomInvalid =>
      '請輸入大於 0 的整數';

  @override
  String get defaultModelPageTranslateModelTitle => '翻譯模型';

  @override
  String get defaultModelPageTranslateModelSubtitle =>
      '用於翻譯訊息內容的模型，推薦使用快速且準確的模型';

  @override
  String get defaultModelPageOcrModelTitle => 'OCR 模型';

  @override
  String backgroundTaskFailed(String task, String error) {
    return '$task失敗：$error';
  }

  @override
  String get defaultModelPageOcrModelSubtitle => '用於對圖片執行文字辨識的模型';

  @override
  String get defaultModelPageOcrModelRequiresImageInput =>
      '請選擇標記為支援圖片輸入的模型用於 OCR';

  @override
  String get defaultModelPagePromptLabel => '提示詞';

  @override
  String get defaultModelPageTitlePromptHint => '輸入用於標題總結的提示詞範本';

  @override
  String get defaultModelPageSummaryPromptHint => '輸入用於生成摘要的提示詞範本';

  @override
  String get defaultModelPageSuggestionPromptHint => '輸入用於生成聊天建議的提示詞範本';

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
  String defaultModelPageSuggestionVars(String contentVar, String localeVar) {
    return '變數：對話內容：$contentVar，語言：$localeVar';
  }

  @override
  String get defaultModelPageCompressModelTitle => '壓縮模型';

  @override
  String get defaultModelPageCompressModelSubtitle => '用於壓縮對話上下文的模型，建議使用快速模型';

  @override
  String get defaultModelPageCompressPromptHint => '輸入用於上下文壓縮的提示詞範本';

  @override
  String defaultModelPageCompressVars(String contentVar, String localeVar) {
    return '變數：對話內容：$contentVar，語言：$localeVar';
  }

  @override
  String defaultModelPageTranslateVars(String sourceVar, String targetVar) {
    return '變數：原始文本：$sourceVar，目標語言：$targetVar';
  }

  @override
  String get defaultModelPageUseCurrentModel => '使用目前對話模型';

  @override
  String get defaultModelPageNotEnabled => '未啟用';

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
  String get modelDetailSheetSaveFailedMessage => '保存失敗，請重試';

  @override
  String get modelDetailSheetAddBody => '新增 Body';

  @override
  String get modelDetailSheetBuiltinToolsDescription => '內建工具取決於供應商和 API 模式。';

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
  String get modelDetailSheetOpenrouterWebFetchTool => '網頁擷取';

  @override
  String get modelDetailSheetOpenrouterWebFetchToolDescription =>
      '啟用 OpenRouter 網頁擷取伺服器工具';

  @override
  String get modelDetailSheetOpenrouterShellTool => 'Shell';

  @override
  String get modelDetailSheetOpenrouterShellToolDescription =>
      '在託管的隔離沙箱中執行 Shell 命令';

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
  String get providerDetailPageCustomRequestTitle => '自訂請求';

  @override
  String get providerDetailPageCustomRequestDescription =>
      '套用於此供應商的所有模型。模型設定優先於此處，此處設定優先於助手設定。';

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
  String get providerDetailPageClaudePromptCachingTitle =>
      'Claude Prompt Caching';

  @override
  String get providerDetailPageClaudePromptCachingHelp =>
      '透過 Claude 官方或 OpenRouter 呼叫 Claude 時附加 cache_control。';

  @override
  String get providerDetailPageClaudePromptCachingTtlTitle => '快取 TTL';

  @override
  String get providerDetailPageClaudePromptCachingTtlHelp =>
      '5 分鐘為預設值。1 小時寫入成本更高，但長對話中可減少重複重建快取。';

  @override
  String get providerDetailPageClaudePromptCachingTtl5m => '5 分鐘';

  @override
  String get providerDetailPageClaudePromptCachingTtl1h => '1 小時';

  @override
  String get providerDetailPageBalanceTitle => '帳戶餘額';

  @override
  String get providerDetailPageBalanceInfo => '取得帳戶餘額';

  @override
  String get providerDetailPageBalanceApiPathLabel => '餘額 API 路徑';

  @override
  String get providerDetailPageBalanceResultPathLabel => '結果 JSON 路徑';

  @override
  String get providerDetailPageBalanceQueryButton => '查詢餘額';

  @override
  String get providerDetailPageBalanceQuerying => '查詢中...';

  @override
  String get providerDetailPageBalanceResetDefaultsButton => '重設';

  @override
  String get providerDetailPageBalanceResetDefaultsTooltip => '重設餘額設定';

  @override
  String providerDetailPageBalanceResult(String value) {
    return '餘額：$value';
  }

  @override
  String providerDetailPageBalanceError(String message) {
    return '餘額查詢失敗：$message';
  }

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
  String get providerDetailPageImportJsonReadFailedMessage => '讀取檔案失敗';

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
  String get providersPageSearchHint => '搜尋供應商或分組';

  @override
  String get providersPageProviderAddedSnackbar => '已新增供應商';

  @override
  String get providerGroupsGroupLabel => '分組';

  @override
  String get providerGroupsOther => '其他';

  @override
  String get providerGroupsOtherUngroupedOption => '其他（未分組）';

  @override
  String get providerGroupsPickerTitle => '選擇分組';

  @override
  String get providerGroupsManageTitle => '分組管理';

  @override
  String get providerGroupsManageAction => '管理分組';

  @override
  String get providerGroupsCreateNewGroupAction => '新增分組…';

  @override
  String get providerGroupsCreateDialogTitle => '新增分組';

  @override
  String get providerGroupsNameHint => '輸入分組名稱';

  @override
  String get providerGroupsCreateDialogCancel => '取消';

  @override
  String get providerGroupsCreateDialogOk => '建立';

  @override
  String get providerGroupsCreateFailedToast => '建立分組失敗';

  @override
  String get providerGroupsDeleteConfirmTitle => '刪除分組';

  @override
  String get providerGroupsDeleteConfirmContent => '該組內供應商將移動到「其他」';

  @override
  String get providerGroupsDeleteConfirmCancel => '取消';

  @override
  String get providerGroupsDeleteConfirmOk => '刪除';

  @override
  String get providerGroupsDeletedToast => '已刪除分組';

  @override
  String get providerGroupsEmptyState => '暫無分組';

  @override
  String get providerGroupsExpandToMoveToast => '請先展開分組';

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
  String get miniMapScrollToBottomTooltip => '捲動到底部';

  @override
  String miniMapSearchMatchCount(int count) {
    return '$count 處';
  }

  @override
  String get miniMapSearchNoResults => '沒有匹配的訊息';

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
  String get searchServicesFieldCustomUrlOptional => '自訂 URL（可選）';

  @override
  String get searchServicesDialogApiKey => 'API Key';

  @override
  String get searchServicesDialogModel => '模型';

  @override
  String get searchServicesDialogSystemPrompt => '系統提示詞';

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
  String get searchServiceEditorProviderTypeTitle => '搜尋提供商';

  @override
  String get searchServiceEditorConfigurationTitle => '服務設定';

  @override
  String get searchServiceEditorNoConfiguration => '此提供商無需額外設定。';

  @override
  String get searchServiceEditorMultiKeyTitle => '多 Key 輪詢';

  @override
  String get searchServiceEditorMultiKeyNone => '未設定';

  @override
  String get searchApiKeysPageDescription =>
      '列表中的 Key 依序輪詢使用，第一個為主 Key；不查額度，以防觸發服務商風控。';

  @override
  String get searchApiKeysPagePrimaryBadge => '主';

  @override
  String get searchApiKeysPageBatchHint => '可一次貼上多個 Key：每行一個，或以逗號分隔';

  @override
  String searchApiKeysPageBatchResult(String added, String skipped) {
    return '已新增 $added 個，略過 $skipped 個重複';
  }

  @override
  String get searchApiKeysPageAdd => '新增';

  @override
  String get searchApiKeysPageEmpty => '尚未設定任何 Key。';

  @override
  String searchServiceEditorMultiKeyCount(String count) {
    return '共 $count 個 Key';
  }

  @override
  String get searchServiceEditorUsageTitle => '帳戶用量';

  @override
  String get searchServiceEditorUsageNotQueried => '尚未查詢用量。';

  @override
  String get searchServiceEditorUsageQuery => '查詢用量';

  @override
  String get searchServiceEditorUsageQuerying => '查詢中…';

  @override
  String searchServiceEditorUsageRemaining(String remaining) {
    return '剩餘 $remaining 額度';
  }

  @override
  String searchServiceEditorUsageBalance(String balance) {
    return '餘額 $balance';
  }

  @override
  String searchServiceEditorUsageUsed(String used, String limit) {
    return '已使用 $used / $limit 額度';
  }

  @override
  String searchServiceEditorUsageFailed(String message) {
    return '用量查詢失敗：$message';
  }

  @override
  String get searchServiceEditorTestTitle => '測試搜尋';

  @override
  String get searchServiceEditorTestQueryHint => '輸入測試關鍵字';

  @override
  String get searchServiceEditorTestRun => '執行測試搜尋';

  @override
  String get searchServiceEditorTestRunning => '搜尋中…';

  @override
  String get searchServiceEditorTestNoResults => '提供商未回傳任何結果。';

  @override
  String searchServiceEditorTestFailed(String message) {
    return '搜尋失敗：$message';
  }

  @override
  String get searchServiceEditorResultOpenTooltip => '開啟結果';

  @override
  String get searchServiceEditorDeleteTooltip => '刪除搜尋服務';

  @override
  String get searchServiceEditorDeleteTitle => '刪除搜尋服務？';

  @override
  String searchServiceEditorDeleteMessage(String provider) {
    return '確定刪除 $provider 嗎？此操作無法復原。';
  }

  @override
  String get searchServiceEditorDeleteConfirm => '刪除';

  @override
  String get searchServiceEditorDiscardTitle => '放棄變更？';

  @override
  String get searchServiceEditorDiscardMessage => '尚未儲存的搜尋服務設定將會遺失。';

  @override
  String get searchServiceEditorKeepEditing => '繼續編輯';

  @override
  String get searchServiceEditorDiscard => '放棄';

  @override
  String get searchSettingsSheetTitle => '搜尋設定';

  @override
  String get searchSettingsSheetBuiltinSearchTitle => '模型內建搜尋';

  @override
  String get searchSettingsSheetBuiltinSearchDescription => '是否啟用模型內建的搜尋功能';

  @override
  String get searchSettingsSheetClaudeDynamicSearchTitle => '模型內建搜尋(新)';

  @override
  String get searchSettingsSheetClaudeDynamicSearchDescription =>
      '在支援的 Claude 官方模型上使用 `web_search_20260209`，支援動態過濾能力。';

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
  String get aboutPageKelivoSearchUnlocked => '有扇沒有名字的門開了一條縫。去設定裡找找看。';

  @override
  String get aboutPageKelivoSearchAlreadyUnlocked => '這扇門你已經推開過了。';

  @override
  String get aboutPageAppName => 'Kelivo';

  @override
  String get aboutPageAppDescription => '開源 AI 助理';

  @override
  String get aboutPageNoQQGroup => '暫無QQ群';

  @override
  String get aboutPageVersion => '版本';

  @override
  String aboutPageVersionDetail(String version, String buildNumber) {
    return '$version / $buildNumber';
  }

  @override
  String get aboutPageSystem => '系統';

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
    return '其他（$os）';
  }

  @override
  String get aboutPageWebsite => '官網';

  @override
  String get aboutPageGithub => 'GitHub';

  @override
  String get aboutPageLicense => '授權';

  @override
  String get aboutPageJoinQQGroup => '加入 QQ 群';

  @override
  String get aboutPageQQGroupOne => 'Kelivo 一群';

  @override
  String get aboutPageQQGroupTwo => 'Kelivo 二群';

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
  String get displaySettingsPageShowUserNameTitle => '顯示使用者名稱';

  @override
  String get displaySettingsPageShowUserTimestampTitle => '顯示使用者時間戳';

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
  String get displaySettingsPageShowModelNameTitle => '顯示模型名稱';

  @override
  String get displaySettingsPageShowModelTimestampTitle => '顯示模型時間戳';

  @override
  String get displaySettingsPageShowProviderInChatMessageTitle => '模型名稱後顯示供應商';

  @override
  String get displaySettingsPageShowProviderInChatMessageSubtitle =>
      '在聊天訊息的模型名稱後面顯示供應商名稱（如 模型 | 供應商）';

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
  String get displaySettingsPageCollapseThinkingStepsTitle => '折疊思考步驟';

  @override
  String get displaySettingsPageCollapseThinkingStepsSubtitle =>
      '預設只顯示最新步驟，展開後查看全部';

  @override
  String get displaySettingsPageShowToolResultSummaryTitle => '顯示工具結果摘要';

  @override
  String get displaySettingsPageInsertSuggestionOnlyTitle => '點擊建議時僅填入輸入框';

  @override
  String get displaySettingsPageShowToolResultSummarySubtitle =>
      '在工具步驟下方顯示摘要文字';

  @override
  String get displaySettingsPageRegenerateDeleteTrailingMessagesTitle =>
      '重新生成時刪除下面的訊息';

  @override
  String get displaySettingsPageShowRegenerateConfirmDialogTitle => '重新生成前彈出確認';

  @override
  String get displaySettingsPageForkKeepMessageVersionsTitle => '建立分支時保留訊息版本';

  @override
  String chainOfThoughtExpandSteps(Object count) {
    return '展開更多 $count 步';
  }

  @override
  String get chainOfThoughtCollapse => '收起';

  @override
  String get displaySettingsPageShowChatListDateTitle => '顯示對話列表日期';

  @override
  String get displaySettingsPageShowChatListDateSubtitle => '在左側對話列表中顯示日期分組標籤';

  @override
  String get displaySettingsPageEnableImageCropperTitle => '啟用圖片裁剪';

  @override
  String get displaySettingsPageEnableImageCropperSubtitle =>
      '從相簿或相機選擇圖片後，允許裁剪圖片';

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
  String get displaySettingsPageKeepScreenOnDuringGenerationTitle =>
      '生成時保持螢幕常亮';

  @override
  String get displaySettingsPageKeepScreenOnDuringGenerationSubtitle =>
      '防止生成途中鎖定螢幕導致中斷，會增加耗電';

  @override
  String get displaySettingsPageMessageNavButtonsTitle => '訊息導航按鈕';

  @override
  String get displaySettingsPageMessageNavButtonsSubtitle => '選擇快速跳轉按鈕的顯示時機';

  @override
  String get displaySettingsPageMessageNavButtonsModeAlways => '始終顯示';

  @override
  String get displaySettingsPageMessageNavButtonsModeScroll => '滾動時顯示';

  @override
  String get displaySettingsPageMessageNavButtonsModeHover => '滑鼠懸停時顯示';

  @override
  String get displaySettingsPageMessageNavButtonsModeScrollAndHover =>
      '滾動和滑鼠懸停時顯示';

  @override
  String get displaySettingsPageMessageNavButtonsModeNever => '永不顯示';

  @override
  String get displaySettingsPageUseNewAssistantAvatarUxTitle => '聊天標題欄顯示助手頭像';

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
  String get displaySettingsPageEnterToSendTitle => '回車鍵發送訊息';

  @override
  String get displaySettingsPageLongPasteAsFileTitle => '超長貼上轉為檔案';

  @override
  String get displaySettingsPageLongPasteAsFileThresholdTitle => '轉換閾值';

  @override
  String get displaySettingsPageLongPasteAsFileThresholdUnit => '字元';

  @override
  String get displaySettingsPageSendShortcutTitle => '發送快捷鍵';

  @override
  String get displaySettingsPageSendShortcutEnter => 'Enter';

  @override
  String get displaySettingsPageSendShortcutCtrlEnter => 'Ctrl/Cmd + Enter';

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
  String get displaySettingsPageChatInputBackgroundOpacityTitle => '輸入框背景透明度';

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
  String get themeSettingsPageCustomPaletteName => '自定義';

  @override
  String get themeSettingsPageCustomColorReset => '重置';

  @override
  String get themeSettingsPageCustomThemesSection => '自定義主題';

  @override
  String get customThemeNewTheme => '新增主題';

  @override
  String get customThemeEditTheme => '編輯主題';

  @override
  String get customThemeImportTheme => '匯入主題';

  @override
  String get customThemeNameLabel => '主題名稱';

  @override
  String get customThemePrimaryColor => '主色';

  @override
  String get customThemeSecondaryColor => '輔色';

  @override
  String get customThemeTertiaryColor => '第三色';

  @override
  String get customThemeColorAuto => '自動';

  @override
  String get customThemeSave => '儲存';

  @override
  String get customThemeCancel => '取消';

  @override
  String get customThemeDelete => '刪除';

  @override
  String get customThemeDeleteConfirm => '刪除該主題？';

  @override
  String get customThemeCopied => '主題 JSON 已複製到剪貼簿';

  @override
  String get customThemeCopyAction => '複製';

  @override
  String get customThemeImportHint => '在此貼上主題 JSON';

  @override
  String get customThemeImportInvalid => '無效的主題 JSON';

  @override
  String get customThemeHexLabel => '十六進制';

  @override
  String get ttsServicesPageBackButton => '返回';

  @override
  String get ttsServicesPageTitle => '語音服務';

  @override
  String get ttsServicesSectionTitle => '文字轉語音';

  @override
  String get ttsServicesPageSettingsTooltip => 'TTS 設定';

  @override
  String get ttsServicesPageAddTooltip => '新增';

  @override
  String get asrServicesSectionTitle => '語音辨識';

  @override
  String get asrServicesSectionDescription => '使用本機、系統或雲端服務將語音轉換為文字。';

  @override
  String get asrServicesAddTooltip => '新增語音辨識服務';

  @override
  String get asrServicesEmptyTitle => '尚未新增語音辨識服務';

  @override
  String get asrServicesEmptySubtitle => '新增後，聊天輸入框才會顯示麥克風。';

  @override
  String get asrServicesOnDeviceGroup => '裝置端';

  @override
  String get asrServicesCloudGroup => '雲端';

  @override
  String get asrServicesSystemTitle => '系統';

  @override
  String get asrServicesSystemSubtitle => '使用裝置內建能力';

  @override
  String get asrServicesLocalTitle => '本機模型';

  @override
  String get asrServicesLocalSubtitle => '下載後在裝置上離線執行';

  @override
  String get asrServicesOpenAiTitle => 'OpenAI Realtime';

  @override
  String get asrServicesOpenAiSubtitle => '低延遲串流轉寫';

  @override
  String get asrServicesDashScopeTitle => 'DashScope';

  @override
  String get asrServicesDashScopeSubtitle => 'Qwen 即時轉寫';

  @override
  String get asrServicesVolcengineTitle => '火山引擎';

  @override
  String get asrServicesVolcengineSubtitle => '豆包語音串流轉寫';

  @override
  String get asrServicesMimoTitle => 'MiMo';

  @override
  String get asrServicesMimoSubtitle => '分段雲端轉寫';

  @override
  String get asrServicesStepTitle => 'Step';

  @override
  String get asrServicesStepSubtitle => 'Step Audio 分段雲端轉寫';

  @override
  String get asrServicesAddTitle => '新增語音辨識';

  @override
  String get asrServicesEditTitle => '編輯語音辨識';

  @override
  String get asrServicesSelectedLabel => '已選擇';

  @override
  String get asrServicesUnavailableLabel => '不可用';

  @override
  String get asrServicesEditAction => '編輯';

  @override
  String get asrServicesDeleteAction => '刪除';

  @override
  String get asrServicesCancelAction => '取消';

  @override
  String get asrServicesAddAction => '新增';

  @override
  String get asrServicesSaveAction => '儲存';

  @override
  String get asrServicesNameLabel => '名稱';

  @override
  String get asrServicesApiKeyLabel => 'API Key';

  @override
  String get asrServicesEndpointLabel => '服務位址';

  @override
  String get asrServicesModelLabel => '模型';

  @override
  String get asrServicesResourceIdLabel => '資源 ID';

  @override
  String get asrServicesLanguageLabel => '語言';

  @override
  String get asrServicesAutomaticLabel => '自動';

  @override
  String get asrServicesApiKeyRequired => '請輸入 API Key 後再使用此服務。';

  @override
  String get asrServicesChooseModelTitle => '模型';

  @override
  String get asrServicesModelDownloadAction => '下載';

  @override
  String get asrServicesModelUseAction => '使用此模型';

  @override
  String get asrServicesModelDeleteAction => '刪除下載';

  @override
  String get asrServicesModelDownloadedLabel => '已下載';

  @override
  String get asrServicesModelDownloadingLabel => '正在下載…';

  @override
  String get asrServicesModelNotDownloadedLabel => '未下載';

  @override
  String asrServicesDownloadFailed(String error) {
    return '模型下載失敗：$error';
  }

  @override
  String get asrServicesSystemChecking => '正在檢查…';

  @override
  String get asrServicesSystemAvailable => '可用';

  @override
  String get asrServicesSystemCheckFailed => '這台裝置沒有可用的系統語音辨識服務。';

  @override
  String get asrServicesMicrophonePermissionDenied => '未取得麥克風權限。';

  @override
  String get asrServicesNoSpeechDetected => '沒有辨識到語音。';

  @override
  String asrServicesRecognitionFailed(String error) {
    return '語音辨識失敗：$error';
  }

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
  String get ttsServicesFieldLanguageTypeLabel => '語言類型';

  @override
  String get ttsServicesFieldLanguageLabel => '語言';

  @override
  String get ttsServicesFieldWorkspaceIdLabel => '業務空間 ID';

  @override
  String get ttsServicesFieldRegionLabel => '地域';

  @override
  String get ttsServicesFieldFormatLabel => '音訊格式';

  @override
  String get ttsServicesFieldOutputFormatLabel => '輸出格式';

  @override
  String get ttsServicesFieldSampleRateLabel => '取樣率';

  @override
  String get ttsServicesFieldVolumeLabel => '音量';

  @override
  String get ttsServicesFieldPitchLabel => '音調';

  @override
  String get ttsServicesFieldLanguageBoostLabel => '語言增強';

  @override
  String get ttsServicesFieldBitrateLabel => '位元率';

  @override
  String get ttsServicesFieldChannelLabel => '聲道數';

  @override
  String get ttsServicesFieldSubtitlesLabel => '產生字幕';

  @override
  String get ttsServicesFieldPronunciationDictionaryLabel => '發音詞典（每行一項）';

  @override
  String get ttsServicesFieldInstructionLabel => '風格／音色描述';

  @override
  String get ttsServicesFieldStreamingLabel => '串流輸出';

  @override
  String get ttsServicesFieldOptimizeTextPreviewLabel => '最佳化播報文字';

  @override
  String get ttsServicesFieldReferenceAudioLabel => '參考音訊（WAV/MP3 資料 URI）';

  @override
  String get ttsServicesFieldChooseReferenceAudioButton => '選擇參考音訊';

  @override
  String get ttsServicesFieldTemperatureLabel => '隨機度';

  @override
  String get ttsServicesFieldTopPLabel => 'Top P';

  @override
  String get ttsServicesFieldLatencyLabel => '延遲模式';

  @override
  String get ttsServicesEmotionAutoLabel => '自動配對';

  @override
  String get ttsServicesValidationApiKeyRequired => 'API Key 不能為空';

  @override
  String get ttsServicesValidationReferenceIdRequired => '音色／參考 ID 不能為空';

  @override
  String get ttsServicesValidationInstructionRequired => '音色描述不能為空';

  @override
  String ttsServicesValidationSampleRate(String format, String rates) {
    return '$format 格式要求使用 $rates Hz。';
  }

  @override
  String get ttsServicesViewDetailsButton => '檢視詳細';

  @override
  String get ttsServicesDialogErrorTitle => '錯誤詳情';

  @override
  String get ttsServicesCloseButton => '關閉';

  @override
  String get ttsSettingsPageTitle => 'TTS 設定';

  @override
  String get ttsSettingsPlaybackSection => '播放';

  @override
  String get ttsSettingsAutoPlayTitle => '自動播放助理回覆';

  @override
  String get ttsSettingsAutoPlayDescription => '助理回覆產生完成後自動開始 TTS 播放。';

  @override
  String get ttsSettingsCacheReplayTitle => '使用快取重播';

  @override
  String get ttsSettingsCacheReplayDescription => '重新播放網路語音時使用已產生的音訊，不再請求語音服務。';

  @override
  String get ttsSettingsTextSelectionSection => '文字選擇';

  @override
  String get ttsSettingsTextSelectionFallbackDescription => '沒有符合內容時將播放完整回覆。';

  @override
  String get ttsSettingsTextSelectionFullTextTitle => '全文';

  @override
  String get ttsSettingsTextSelectionFullTextDescription => '播放完整助理回覆。';

  @override
  String get ttsSettingsTextSelectionQuotedOnlyTitle => '僅引號內文字';

  @override
  String get ttsSettingsTextSelectionQuotedOnlyDescription =>
      '播放 “”、‘’、\"\"、\'\'、「」或『』內的文字。';

  @override
  String get ttsSettingsTextSelectionOutsideParenthesesTitle => '括號外文字';

  @override
  String get ttsSettingsTextSelectionOutsideParenthesesDescription =>
      '跳過 () 和 （） 內的文字。';

  @override
  String get ttsSettingsTextSelectionItalicOnlyTitle => '僅斜體文字';

  @override
  String get ttsSettingsTextSelectionItalicOnlyDescription =>
      '播放 Markdown 或 HTML 斜體文字。';

  @override
  String get ttsSettingsTextSelectionNonItalicTitle => '僅正體文字';

  @override
  String get ttsSettingsTextSelectionNonItalicDescription =>
      '跳過 Markdown 或 HTML 斜體文字。';

  @override
  String get ttsFloatingPlayerLabel => '語音播放器';

  @override
  String get ttsFloatingPauseTooltip => '暫停';

  @override
  String get ttsFloatingResumeTooltip => '繼續播放';

  @override
  String get ttsFloatingReplayTooltip => '重新播放';

  @override
  String get ttsFloatingRewind15Tooltip => '倒退 15 秒';

  @override
  String get ttsFloatingForward15Tooltip => '前進 15 秒';

  @override
  String get ttsFloatingSpeedTooltip => '播放倍速';

  @override
  String get ttsFloatingCloseTooltip => '關閉播放器';

  @override
  String get ttsFloatingExpandTooltip => '展開播放控制';

  @override
  String get ttsFloatingCollapseTooltip => '收起播放控制';

  @override
  String get ttsFloatingSaveTooltip => '儲存音訊';

  @override
  String get ttsSaveDialogTitle => '儲存 TTS 音訊';

  @override
  String get ttsSaveSuccess => '音訊已儲存';

  @override
  String get ttsSaveNothing => '暫無可儲存的音訊';

  @override
  String ttsSaveFailed(String message) {
    return '儲存音訊失敗：$message';
  }

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
  String get imageViewerPageCloseButton => '關閉預覽';

  @override
  String get imageViewerPageSaveButton => '儲存圖片';

  @override
  String get imageViewerPageCopyButton => '複製圖片';

  @override
  String get imageViewerPagePreviousButton => '上一張圖片';

  @override
  String get imageViewerPageNextButton => '下一張圖片';

  @override
  String get imageViewerPageZoomInButton => '放大';

  @override
  String get imageViewerPageZoomOutButton => '縮小';

  @override
  String get imageViewerPageResetZoomButton => '重設縮放';

  @override
  String get imageViewerPageFlipHorizontalButton => '左右鏡像';

  @override
  String get imageViewerPageFlipVerticalButton => '上下鏡像';

  @override
  String get imageViewerPageRotateLeftButton => '向左旋轉';

  @override
  String get imageViewerPageRotateRightButton => '向右旋轉';

  @override
  String imageViewerPageCounter(int index, int total) {
    return '$index/$total';
  }

  @override
  String imageViewerPageImageLabel(int index, int total) {
    return '第 $index 張圖片，共 $total 張';
  }

  @override
  String get imageViewerPageImageLoadFailed => '無法載入圖片';

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
  String get searchServiceNameDoubao => '豆包';

  @override
  String get searchProviderDoubaoDescription => '火山引擎豆包網頁搜尋 API。';

  @override
  String get searchServiceNameSerper => 'Serper';

  @override
  String get searchProviderSerperDescription =>
      'Serper Google 搜尋 API。回應快速，支援國家/地區、語言、時間和頁碼過濾。';

  @override
  String get searchServiceNameQuerit => 'Querit';

  @override
  String get searchProviderQueritDescription =>
      '面向 LLM 應用的 Querit 搜尋 API。返回即時網頁結果，並支援站點、時間、國家和語言過濾。';

  @override
  String get searchServiceNameGrok => 'Grok';

  @override
  String get searchProviderGrokDescription =>
      '透過 xAI Responses API 使用 Grok 搜尋。呼叫網頁和 X 搜尋工具，並返回帶引用的來源。';

  @override
  String get searchServiceNameStepFun => 'StepFun';

  @override
  String get searchProviderStepFunDescription =>
      '透過 StepFun POST /v1/search 進行網頁搜尋。';

  @override
  String get searchServiceNameFirecrawl => 'Firecrawl';

  @override
  String get searchProviderFirecrawlDescription =>
      'Firecrawl Search API v2。API Key 可選。此處不支援 Scrape。';

  @override
  String get searchServiceNameTinyFish => 'TinyFish';

  @override
  String get searchProviderTinyFishDescription =>
      'TinyFish Search API，支援地區與語言參數。需要 API Key。此處不支援 Fetch/Scrape。';

  @override
  String get searchServiceNameKelivo => 'Kelivo';

  @override
  String get searchServicesDialogCountryOptional => '國家/地區（可選）';

  @override
  String get searchServicesDialogLanguageOptional => '語言（可選）';

  @override
  String get searchServicesDialogTimeFilterOptional => '時間過濾（可選）';

  @override
  String get searchServicesDialogPageOptional => '頁碼（可選）';

  @override
  String get searchServicesDialogPageInvalid => '頁碼必須是正整數。';

  @override
  String get searchServicesDialogSitesIncludeOptional => '包含站點（可選）';

  @override
  String get searchServicesDialogSitesExcludeOptional => '排除站點（可選）';

  @override
  String get searchServicesDialogTimeRangeOptional => '時間範圍（可選）';

  @override
  String get searchServicesDialogCountriesOptional => '國家（可選）';

  @override
  String get searchServicesDialogLanguagesOptional => '語言（可選）';

  @override
  String get searchServicesDialogSitesHint => 'example.com, docs.example.com';

  @override
  String get searchServicesDialogTimeRangeHint => 'd7';

  @override
  String get searchServicesDialogCountriesHint => 'united states, japan';

  @override
  String get searchServicesDialogLanguagesHint => 'english, japanese';

  @override
  String get generationInterrupted => '生成已中斷';

  @override
  String get titleForLocale => '新對話';

  @override
  String get temporaryChatTitle => '臨時對話';

  @override
  String get temporaryChatEmptyMessage => '臨時對話不會顯示在歷史記錄中，退出後將被完全刪除';

  @override
  String get temporaryChatToggleTooltip => '切換臨時對話';

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
  String get instructionInjectionUngroupedGroup => '未分組';

  @override
  String get instructionInjectionGroupLabel => '分組';

  @override
  String get instructionInjectionGroupHint => '可選';

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
  String get assistantEditLocalToolTimeInfoTitle => '時間資訊';

  @override
  String get assistantEditLocalToolTimeInfoSubtitle =>
      '讀取裝置日期、星期、時間、時區、UTC 偏移和時間戳。';

  @override
  String get assistantEditLocalToolClipboardTitle => '剪貼簿';

  @override
  String get assistantEditLocalToolClipboardSubtitle =>
      '在明確需要時讀取或寫入裝置剪貼簿中的純文字。';

  @override
  String get assistantEditLocalToolTextToSpeechTitle => '文字轉語音';

  @override
  String get assistantEditLocalToolTextToSpeechSubtitle =>
      '允許助手使用已設定的語音播放朗讀文字。';

  @override
  String get assistantEditLocalToolAskUserTitle => '詢問使用者';

  @override
  String get assistantEditLocalToolAskUserSubtitle => '允許助手提出簡短問題，並在你回答後繼續生成。';

  @override
  String get assistantEditLocalToolCalculateTitle => '計算機';

  @override
  String get assistantEditLocalToolCalculateSubtitle =>
      '計算數學表達式，支援加減乘除冪運算 sqrt sin cos 等。';

  @override
  String get assistantEditLocalToolScreenTimeTitle => '螢幕使用時間';

  @override
  String get assistantEditLocalToolScreenTimeSubtitle =>
      '查詢本裝置的應用使用時長，需要授予使用情況存取權限。';

  @override
  String get chatMessageWidgetScreenTimeTotal => '總螢幕使用時間';

  @override
  String get chatMessageWidgetScreenTimePermissionRequired =>
      '未授予使用記錄存取權限，請在系統設定中開啟後重試。';

  @override
  String get assistantEditLocalToolCalendarQueryTitle => '查詢日曆';

  @override
  String get assistantEditLocalToolCalendarQuerySubtitle =>
      '讀取本裝置上的日曆行程，需要授予日曆權限。';

  @override
  String get assistantEditLocalToolCalendarCreateTitle => '建立行程';

  @override
  String get assistantEditLocalToolCalendarCreateSubtitle =>
      '在你確認後於本裝置建立日曆行程，需要授予日曆權限。';

  @override
  String get assistantEditMemorySwitchDescription => '允許助理主動儲存並在對話間引用使用者相關資訊';

  @override
  String get assistantEditRecentChatsSwitchTitle => '參考歷史聊天記錄';

  @override
  String get assistantEditRecentChatsSwitchDescription =>
      '在新對話中引用最近的對話標題以增強上下文';

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
  String get networkProxyBypassLabel => '代理繞過';

  @override
  String get networkProxyBypassHint =>
      '以逗號分隔的主機或 CIDR，例如：localhost,127.0.0.1,192.168.0.0/16,*.local';

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
  String get providerDetailPageMultiSelectButton => '多選';

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
  String get providerDetailPageDeleteSelectedModelsButton => '刪除';

  @override
  String get providerDetailPageDeleteSelectedModelsTooltip => '刪除所選模型';

  @override
  String providerDetailPageDeleteSelectedModelsConfirm(int count) {
    return '確定刪除選中的 $count 個模型嗎？此操作不可撤回。';
  }

  @override
  String get providerDetailPageDeleteFailedDetectedModelsButton => '刪除不可用';

  @override
  String get providerDetailPageDeleteFailedDetectedModelsTooltip => '刪除檢測失敗的模型';

  @override
  String providerDetailPageDeleteFailedDetectedModelsConfirm(int count) {
    return '確定刪除檢測失敗的 $count 個模型嗎？此操作不可撤回。';
  }

  @override
  String providerDetailPageSelectedModelsDeletedSnackbar(int count) {
    return '已刪除 $count 個模型';
  }

  @override
  String get providerDetailPageDeleteAllModelsTooltip => '刪除全部模型';

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
  String get contextLogSettingTitle => '上下文日誌';

  @override
  String get contextLogSettingSubtitle =>
      '開啟後會將每次實際傳送給模型的完整上下文寫入 logs/context_logs.txt';

  @override
  String get contextLogViewerTitle => '上下文';

  @override
  String contextLogSnapshotMessages(int count) {
    return '$count 則訊息';
  }

  @override
  String contextLogSnapshotTokens(int count) {
    return '$count tokens';
  }

  @override
  String get contextLogSourceSystemPrompt => '系統提示詞';

  @override
  String get contextLogSourceMemoryRules => '記憶規則';

  @override
  String get contextLogSourceSearchPrompt => '搜尋提示';

  @override
  String get contextLogSourceInstructionInjection => '指令注入';

  @override
  String get contextLogSourceWorldBook => '世界書';

  @override
  String get contextLogSourceMemorySnapshot => '記憶快照';

  @override
  String get contextLogSourceChatHistory => '聊天歷史';

  @override
  String get contextLogSourceToolCall => '工具呼叫';

  @override
  String get contextLogSourceToolResult => '工具結果';

  @override
  String get contextLogTokensEstimateHint => 'tokens 僅為預估值，請以模型實際消耗為準。';

  @override
  String contextLogSnapshotsCount(int count) {
    return '$count 則快照';
  }

  @override
  String get contextLogSnapshotFallbackTitle => '快照';

  @override
  String get contextLogKindFull => '全量快照';

  @override
  String get contextLogKindUpdate => '增量更新';

  @override
  String get contextLogSectionComposition => '構成';

  @override
  String get contextLogLoadOlder => '載入更早的日誌';

  @override
  String get contextLogLoading => '載入中…';

  @override
  String get contextLogAllLoaded => '已載入全部日誌';

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
  String logViewerRequestsCount(int count) {
    return '$count 個請求';
  }

  @override
  String get logViewerFieldId => 'ID';

  @override
  String get logViewerFieldMethod => '方法';

  @override
  String get logViewerFieldStatus => '狀態';

  @override
  String get logViewerFieldStarted => '開始';

  @override
  String get logViewerFieldEnded => '結束';

  @override
  String get logViewerFieldDuration => '耗時';

  @override
  String get logViewerSectionSummary => '概覽';

  @override
  String get logViewerSectionParameters => '參數';

  @override
  String get logViewerSectionRequestHeaders => '請求標頭';

  @override
  String get logViewerSectionRequestBody => '請求本文';

  @override
  String get logViewerSectionResponseHeaders => '回應標頭';

  @override
  String get logViewerSectionResponseBody => '回應本文';

  @override
  String get logViewerSectionWarnings => '警告';

  @override
  String get logViewerErrorTitle => '錯誤';

  @override
  String logViewerMoreCount(int count) {
    return '+$count 條更多';
  }

  @override
  String get logViewerSectionAttachments => '附件';

  @override
  String get logViewerPayloadOmitted => '已省略';

  @override
  String get logViewerShowMore => '顯示更多';

  @override
  String get logSettingsTitle => '日誌設定';

  @override
  String get logSettingsSaveOutput => '保存回應輸出';

  @override
  String get logSettingsSaveOutputSubtitle =>
      '記錄串流輸出的每個分片（可能影響生成效能）。HTTP 報錯回應仍會寫入。';

  @override
  String get logSettingsElidePayloads => '省略大載荷';

  @override
  String get logSettingsElidePayloadsSubtitle =>
      '把內聯的 base64 圖片和檔案替換成佔位符，日誌更小、檢視器更快。';

  @override
  String get logSettingsAutoDelete => '自動刪除';

  @override
  String get logSettingsAutoDeleteSubtitle => '刪除超過指定天數的日誌';

  @override
  String get logSettingsAutoDeleteDisabled => '不啟用';

  @override
  String logSettingsAutoDeleteDays(int count) {
    return '$count 天';
  }

  @override
  String get logSettingsMaxSize => '日誌大小上限';

  @override
  String get logSettingsMaxSizeSubtitle => '超出後將刪除最早的日誌';

  @override
  String get logSettingsMaxSizeUnlimited => '不限制';

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

  @override
  String get homePageProcessingFiles => '正在解析檔案……';

  @override
  String get settingsPageWorldBook => '世界書';

  @override
  String get settingsPageMemory => '記憶';

  @override
  String get memorySettingsPageTitle => '記憶';

  @override
  String get memorySettingsGlobalSubtitle => '記憶模式、模型與提示詞';

  @override
  String get memorySettingsModeSection => '記憶模式';

  @override
  String get memorySettingsModelSection => '記憶模型';

  @override
  String get memorySettingsModelTitle => '處理模型';

  @override
  String get memorySettingsModelUnset => '未選擇';

  @override
  String get memorySettingsModelTip => '開啟「自動整理記憶」後，後台會頻繁呼叫此模型，建議選擇便宜且速度快的模型。';

  @override
  String get memorySettingsAboutTitle => '記憶說明';

  @override
  String get memorySettingsAboutSubtitle => '瞭解記憶如何運作與觸發';

  @override
  String get memoryAboutQuickstartTitle => '三步上手';

  @override
  String get memoryAboutQuickstartBody =>
      '① 在「設定 → 記憶」裡選擇處理模型。\n② 在助手的「記憶」頁打開長期記憶和自動整理。\n③ 聊幾輪，或點「整理記憶」，再到「全部記憶」查看結果。';

  @override
  String get memoryAboutTypesTitle => '記憶類型';

  @override
  String get memoryAboutTypesBody =>
      '身分：使用者的穩定資訊，例如稱呼、職業、語言、長期偏好。寫成完整的第三人稱陳述。\n\n工作流：使用者習慣怎麼做事，例如工具、格式、審閱方式。\n\n語氣：使用者希望助手怎麼說話，例如語氣、篇幅、語言風格。\n\n指令：助手應長期遵守的規則，而不是本次對話裡的一次性任務。';

  @override
  String get memoryAboutScopeTitle => '全域與助手範圍';

  @override
  String get memoryAboutScopeBody =>
      '全域記憶會對所有助手注入。助手範圍的記憶只對該助手可見。跨助手都該知道的事實用全域；只屬於某一個助手的規則或上下文用助手範圍。';

  @override
  String get memoryAboutInjectionTitle => '記憶如何注入';

  @override
  String get memoryAboutInjectionBody =>
      '開對話時，每類會把最近的若干條放進模型上下文。某類超過注入上限時，塊會標上 mode=\"summary\"，並用 total / shown 標明總數與展示條數，其餘由模型用 memory_search_profile 按需查詢。可在「設定 → 記憶」調大上限，更全面但更費 token。';

  @override
  String get memoryAboutPipelineTitle => '後台整理';

  @override
  String get memoryAboutPipelineBody =>
      '開啟自動整理後，對話結束會走：判斷是否值得記 → 擷取候選 → 去重合併 → 必要時把身分類記憶提煉進使用者畫像。也可以在助手「記憶」頁點「整理記憶」。因此處理模型會被較頻繁呼叫。';

  @override
  String get memoryAboutCacheTitle => '保持快取良好';

  @override
  String get memoryAboutCacheBody =>
      '注入前綴會保持穩定，未改動時可復用 Prompt 快取，從而降低費用與延遲。避免無意義的大批量改動或重排。日常增刪改單條通常影響有限。';

  @override
  String get memoryAboutFaqTitle => '常見問題';

  @override
  String get memoryAboutFaqWhyNotRememberedTitle => '為什麼沒記住？';

  @override
  String get memoryAboutFaqWhyNotRememberedBody =>
      '整理會被跳過，常見原因包括：新訊息不足，暫不整理；沒有新訊息需要整理；尚未選擇記憶處理模型。臨時對話不會寫入記憶。也可以按助手關閉記憶或自動整理。';

  @override
  String get memorySettingsThinkingTitle => '啟用思考';

  @override
  String get memorySettingsThinkingSubtitle => '在模型支援時允許記憶模型使用推理';

  @override
  String get memorySettingsInjectionSection => '記憶注入';

  @override
  String get memorySettingsInjectionMaxItemsTitle => '每類注入條數';

  @override
  String get memorySettingsInjectionMaxItemsSubtitle =>
      '某一類型的記憶超過該條數時，只注入最近的若干條，其餘由模型用 memory_search_profile 按需查詢。調大更全面但更費 token。若你改過規則提示詞，請一併更新或恢復預設。';

  @override
  String memorySettingsInjectionMaxItemsOption(int n) {
    return '$n';
  }

  @override
  String get memorySettingsInjectionMaxItemsCustomButton => '自訂';

  @override
  String get memorySettingsInjectionMaxItemsCustomTitle => '自訂注入條數';

  @override
  String get memorySettingsInjectionMaxItemsCustomDescription =>
      '請輸入 1 到 100 之間的整數。';

  @override
  String get memorySettingsInjectionMaxItemsCustomLabel => '條數';

  @override
  String get memorySettingsInjectionMaxItemsCustomHint => '1–100';

  @override
  String get memorySettingsInjectionMaxItemsCustomInvalid =>
      '請輸入 1 到 100 之間的整數';

  @override
  String get memorySettingsPromptLangSection => '提示詞語言';

  @override
  String get memorySettingsPromptLangAuto => '自動';

  @override
  String get memorySettingsPromptLangAutoSubtitle => '跟隨介面語言（中文用 zh，否則用 en）';

  @override
  String get memorySettingsPromptLangZh => '中文';

  @override
  String get memorySettingsPromptLangZhSubtitle => '一律使用中文記憶提示詞與工具描述';

  @override
  String get memorySettingsPromptLangEn => 'English';

  @override
  String get memorySettingsPromptLangEnSubtitle => '一律使用英文記憶提示詞與工具描述';

  @override
  String get memorySettingsPromptsSection => '提示詞模板';

  @override
  String get memorySettingsLegacyPromptTitle => '舊版記憶規則';

  @override
  String get memoryPromptEditRulesTitle => '記憶規則';

  @override
  String get memoryPromptEditRulesSubtitle => '注入到主對話的系統提示中';

  @override
  String get memoryPromptEditGateTitle => 'Gatekeeper';

  @override
  String get memoryPromptEditGateSubtitle => '判斷這一輪是否值得記憶';

  @override
  String get memoryPromptEditExtractTitle => 'Extract';

  @override
  String get memoryPromptEditExtractSubtitle => '從對話中提取候選記憶條目';

  @override
  String get memoryPromptEditSmartAddTitle => 'Smart Add';

  @override
  String get memoryPromptEditSmartAddSubtitle =>
      'NEW / MERGE / CONFLICT / SKIP 去重判定';

  @override
  String get memoryPromptEditDistillTitle => 'Profile Distiller';

  @override
  String get memoryPromptEditDistillSubtitle => '從身分類記憶提煉畫像欄位';

  @override
  String get memoryPromptEditMigrateTitle => '舊版記憶遷移';

  @override
  String get memoryPromptEditMigrateSubtitle => '選擇「模型整理」時用於改寫記憶原文';

  @override
  String get memoryPromptEditReset => '恢復預設';

  @override
  String get memoryPromptEditSave => '儲存';

  @override
  String get memoryPromptEditSectionPerItem => '逐條提示詞';

  @override
  String get memoryPromptEditSectionBatch => '合併提示詞';

  @override
  String get memorySettingsEntriesSection => '全部記憶';

  @override
  String get memorySettingsLegacySection => '舊版記憶';

  @override
  String get memorySettingsEntriesTitle => '記憶列表';

  @override
  String get memorySettingsEntriesSubtitle => '瀏覽、編輯、封存與刪除記憶';

  @override
  String get memorySettingsProfileTitle => '使用者畫像';

  @override
  String get memorySettingsProfileSubtitle => '供模型使用的結構化身分欄位';

  @override
  String get memorySettingsLegacyTitle => '舊版記憶（唯讀）';

  @override
  String get memorySettingsLegacySubtitle => '來自舊版本的記憶';

  @override
  String get memoryEntryTypeIdentity => '身分';

  @override
  String get memoryEntryTypeWorkflow => '工作流';

  @override
  String get memoryEntryTypeVoice => '語氣';

  @override
  String get memoryEntryTypeInstruction => '指令';

  @override
  String get memoryEntryScopeGlobal => '全域';

  @override
  String get memoryEntryScopeAssistant => '僅本助手';

  @override
  String memoryEntryScopeAssistantNamed(String name) {
    return '$name';
  }

  @override
  String get memoryEntrySourceManual => '手動';

  @override
  String get memoryEntrySourceTool => '工具';

  @override
  String get memoryEntrySourceExtracted => '擷取';

  @override
  String get memoryEntrySourceDistilled => '蒸餾';

  @override
  String get memoryEntryStatusActive => '作用中';

  @override
  String get memoryEntryStatusArchived => '已封存';

  @override
  String memoryEntryUpdatedAt(String date) {
    return '更新於 $date';
  }

  @override
  String get memoryEntryActionEdit => '編輯';

  @override
  String get memoryEntryActionDelete => '刪除';

  @override
  String get memoryEntryActionArchive => '封存';

  @override
  String get memoryEntryActionRestore => '還原';

  @override
  String get memoryEntryActionSwitchScope => '切換範圍';

  @override
  String get memoryEntryActionBatchDelete => '刪除所選';

  @override
  String get memoryEntryActionAdd => '新增記憶';

  @override
  String get memoryEntryDeleteConfirmTitle => '刪除這條記憶？';

  @override
  String get memoryEntryDeleteConfirmContent => '將永久刪除該記憶，且無法復原。';

  @override
  String memoryEntryBatchDeleteConfirmTitle(int count) {
    return '刪除 $count 條記憶？';
  }

  @override
  String get memoryEntryBatchDeleteConfirmContent => '所選記憶將被永久刪除。';

  @override
  String get memoryEntrySwitchScopeConfirmTitle => '更改記憶範圍？';

  @override
  String get memoryEntrySwitchScopeToGlobal => '將這條記憶設為全域（所有助手可見）？';

  @override
  String get memoryEntrySwitchScopeToAssistant => '將這條記憶限制為僅本助手？';

  @override
  String get memoryEntryArchivedSection => '已封存';

  @override
  String get memoryEntryEmpty => '還沒有記憶';

  @override
  String get memoryEntryEmptyDisabled => '該助手未啟用長期記憶';

  @override
  String get memoryEntryEditTitle => '編輯記憶';

  @override
  String get memoryEntryCreateTitle => '新建記憶';

  @override
  String get memoryEntryContentHint => '輸入記憶內容';

  @override
  String get memoryEntryTypeLabel => '類型';

  @override
  String get memoryEntryScopeLabel => '範圍';

  @override
  String get memoryFilterScopeAll => '全部範圍';

  @override
  String get memoryFilterScopeGlobal => '僅全域';

  @override
  String get memoryFilterScopeAssistant => '助手';

  @override
  String get memoryFilterTypeAll => '全部類型';

  @override
  String get memoryFilterStatusAll => '全部狀態';

  @override
  String get memoryFilterStatusActive => '作用中';

  @override
  String get memoryFilterStatusArchived => '已封存';

  @override
  String get memorySearchHint => '搜尋記憶';

  @override
  String get memorySearchEmpty => '沒有相符的記憶';

  @override
  String memoryOrphanBanner(int count) {
    return '有 $count 條孤兒助手記憶（助手已刪除）';
  }

  @override
  String get memoryOrphanCleanupButton => '清理';

  @override
  String get memoryOrphanConfirmTitle => '清理孤兒記憶？';

  @override
  String memoryOrphanConfirmContent(int count) {
    return '將永久刪除 $count 條所屬助手已不存在的記憶。';
  }

  @override
  String get memoryOrganizeButton => '整理記憶';

  @override
  String get memoryOrganizeNeedsConversation => '需要在與該助手的對話中使用';

  @override
  String get memoryOrganizeNeedsModel => '請先在 設定 → 記憶 中選擇記憶處理模型';

  @override
  String get memoryOrganizeStatusNever => '尚未整理';

  @override
  String memoryOrganizeStatusLast(String when) {
    return '上次整理：$when';
  }

  @override
  String memoryOrganizeStatusExtracted(int count) {
    return '擷取 $count 條';
  }

  @override
  String get memoryOrganizeStatusSkipped => '無需記憶';

  @override
  String memoryOrganizeStatusFailed(String reason) {
    return '失敗：$reason';
  }

  @override
  String memoryOrganizeStatusSkippedReason(String reason) {
    return '已跳過：$reason';
  }

  @override
  String get memoryOutcomeTemporaryConversation => '臨時對話不會寫入記憶';

  @override
  String get memoryOutcomeMemoryDisabled => '此助手已關閉記憶';

  @override
  String get memoryOutcomeAutoOrganizeOff => '自動整理已關閉';

  @override
  String get memoryOutcomeStreaming => '回覆仍在產生，已跳過整理';

  @override
  String get memoryOutcomeBelowThreshold => '新訊息不足，暫不整理';

  @override
  String get memoryOutcomeEmptyWindow => '沒有新訊息需要整理';

  @override
  String get memoryOutcomeMemoryModelUnset => '尚未選擇記憶處理模型';

  @override
  String get memoryOutcomeMemoryModelMissing => '所選記憶模型已不可用';

  @override
  String get memoryOutcomeAssistantMissing => '找不到助手';

  @override
  String get memoryOutcomeConversationMissing => '找不到對話';

  @override
  String get memoryOutcomeQueueOverflow => '整理佇列已滿，本次任務被捨棄';

  @override
  String get memoryOutcomeGateRequestFailed => '判斷是否值得記憶時，無法請求記憶模型';

  @override
  String get memoryOutcomeGateParseFailed => '判斷是否值得記憶的回覆無法解析';

  @override
  String get memoryOutcomeExtractRequestFailed => '擷取記憶時，無法請求記憶模型';

  @override
  String get memoryOutcomeExtractParseFailed => '擷取記憶的回覆無法解析';

  @override
  String get memoryOutcomeDistillFailed => '使用者畫像提煉失敗';

  @override
  String get memoryOutcomeMemoryExecutionError => '記憶工具執行失敗';

  @override
  String get memoryOutcomeUnsupportedTool => '不支援的記憶工具';

  @override
  String get memoryOutcomeInvalidMemoryType => '記憶類型無效';

  @override
  String get memoryOutcomeInvalidMemoryContent => '記憶內容無效';

  @override
  String get memoryOutcomeInvalidQuery => '查詢無效';

  @override
  String get memoryOutcomeInvalidMemoryId => '記憶 ID 無效';

  @override
  String get memoryOutcomeMemoryNotFound => '找不到這條記憶';

  @override
  String get memoryOutcomeInvalidProfileFields => '畫像欄位無效';

  @override
  String get memoryOutcomeChatSearchUnavailable => '對話搜尋不可用';

  @override
  String get memoryOrganizeJustNow => '剛剛';

  @override
  String memoryOrganizeMinutesAgo(int n) {
    return '$n 分鐘前';
  }

  @override
  String memoryOrganizeHoursAgo(int n) {
    return '$n 小時前';
  }

  @override
  String memoryOrganizeDaysAgo(int n) {
    return '$n 天前';
  }

  @override
  String get memoryModelMissingNotice => '需要先在 設定 → 記憶 中選擇記憶處理模型。';

  @override
  String get memoryModelMissingGoSelect => '去選擇';

  @override
  String get memoryEntriesPageTitle => '全部記憶';

  @override
  String get userProfilePageTitle => '使用者畫像';

  @override
  String get userProfilePreferredName => '希望怎麼稱呼我';

  @override
  String get userProfilePreferredNameHint => '這是希望模型怎麼稱呼你，與側欄顯示的使用者名稱無關';

  @override
  String get userProfileGender => '性別';

  @override
  String get userProfilePronouns => '代詞';

  @override
  String get userProfilePreferredLanguage => '偏好語言';

  @override
  String get userProfileTimezone => '時區';

  @override
  String get userProfileOccupation => '職業';

  @override
  String get userProfileLocation => '所在地';

  @override
  String get userProfileCustomSection => '自訂欄位';

  @override
  String get userProfileAddCustom => '新增自訂欄位';

  @override
  String get userProfileCustomKeyHint => '鍵名（custom.name）';

  @override
  String get userProfileCustomValueHint => '值';

  @override
  String get userProfileInvalidKey => '鍵名須為 custom. 後接 1–32 位字母、數字、_ 或 -';

  @override
  String get userProfileClear => '清除';

  @override
  String get userProfileSave => '儲存';

  @override
  String get userProfileEmptyValue => '未設定';

  @override
  String get legacyMemoryPageTitle => '舊版記憶';

  @override
  String get legacyMemoryBanner => '這些記憶來自舊版本，不會參與對話；你可以將它們遷移到目前的記憶系統。';

  @override
  String get legacyMemoryEmpty => '沒有舊版記憶';

  @override
  String get legacyMemoryCopy => '複製';

  @override
  String get legacyMemoryCopied => '已複製';

  @override
  String get legacyMemoryExport => '匯出';

  @override
  String get legacyMemoryExportTitle => 'Kelivo 舊版記憶匯出';

  @override
  String legacyMemoryAssistantHeader(String name) {
    return '助手：$name';
  }

  @override
  String get legacyMemorySearchHint => '搜尋舊版記憶';

  @override
  String get legacyMemoryMigrate => '遷移';

  @override
  String get legacyMemoryMigrationTitle => '遷移舊版記憶';

  @override
  String legacyMemoryMigrationSubtitle(int count) {
    return '使用模型整理並分類 $count 條舊版記憶，原資料不會改變。';
  }

  @override
  String get legacyMemoryMigrationModel => '遷移模型';

  @override
  String get legacyMemoryMigrationChooseModel => '選擇模型';

  @override
  String get legacyMemoryMigrationTarget => '儲存到';

  @override
  String get legacyMemoryMigrationTargetGlobal => '全域';

  @override
  String get legacyMemoryMigrationTargetAssistant => '目前的助手';

  @override
  String get legacyMemoryMigrationTargetOriginalAssistants => '原助手';

  @override
  String get legacyMemoryMigrationTargetGlobalDescription => '所有助手均可使用';

  @override
  String get legacyMemoryMigrationTargetAssistantDescription => '僅目前的助手可使用';

  @override
  String get legacyMemoryMigrationTargetOriginalDescription => '每條記憶保留在原來的助手下';

  @override
  String get legacyMemoryMigrationStart => '開始遷移';

  @override
  String get legacyMemoryMigrationAnalyzing => '正在使用模型分析';

  @override
  String get legacyMemoryMigrationWriting => '正在寫入記憶';

  @override
  String legacyMemoryMigrationProgress(int current, int total) {
    return '$current / $total';
  }

  @override
  String get legacyMemoryMigrationComplete => '遷移完成';

  @override
  String legacyMemoryMigrationResult(int created, int skipped) {
    return '已遷移 $created 條 · 略過已有 $skipped 條';
  }

  @override
  String get legacyMemoryMigrationFailed => '遷移已停止。可以重試，已儲存的記憶會自動略過。';

  @override
  String get legacyMemoryMigrationRetry => '重試';

  @override
  String get legacyMemoryMigrationClose => '完成';

  @override
  String get legacyMemoryMigrationContentMode => '內容處理';

  @override
  String get legacyMemoryMigrationContentPreserve => '保留原文';

  @override
  String get legacyMemoryMigrationContentOrganize => '模型整理';

  @override
  String get legacyMemoryMigrationContentPreserveDescription =>
      '模型只負責分類，寫入時保留舊記憶原文。';

  @override
  String get legacyMemoryMigrationContentOrganizeDescription =>
      '模型會分類並改寫內容，使用可編輯的遷移提示詞。';

  @override
  String get legacyMemoryMigrationBatchSize => '批大小';

  @override
  String legacyMemoryMigrationPartial(int created, int skipped, int failed) {
    return '已遷移 $created · 略過 $skipped · 失敗 $failed';
  }

  @override
  String get legacyMemoryMigrationContinue => '繼續遷移';

  @override
  String get legacyMemoryMigrationErrorNetwork => '網路異常，請檢查連線後重試。';

  @override
  String get legacyMemoryMigrationErrorFormat => '模型回傳格式不正確。';

  @override
  String get legacyMemoryMigrationErrorAuth => '鑑權失敗，請檢查 API 金鑰。';

  @override
  String legacyMemoryMigrationErrorOther(String message) {
    return '遷移失敗：$message';
  }

  @override
  String get legacyMemoryModeTitle => '使用舊版記憶';

  @override
  String get legacyMemoryModeSubtitle => '全域設定，影響所有助手';

  @override
  String legacyMemoryModeCacheWarning(String token) {
    return '預設模板會注入目前時間 $token，影響快取命中率，如不需要可刪除';
  }

  @override
  String get memoryUiContentLabel => '內容';

  @override
  String get memoryUiValueLabel => '值';

  @override
  String get memoryUiCustomKeyLabel => '鍵名';

  @override
  String get memoryUiStatusLabel => '狀態';

  @override
  String get memoryUiAssistantLabel => '助手';

  @override
  String get memoryUiAssistantAll => '全部助手';

  @override
  String get memoryUiSearchClear => '清除搜尋';

  @override
  String get memoryUiAssistantLegacyTitle => '舊版記憶（唯讀）';

  @override
  String get memoryUiAssistantLegacySubtitle => '該助手來自舊版本的記憶';

  @override
  String get assistantEditMemorySwitchTitle => '使用長期記憶';

  @override
  String get assistantEditMemorySwitchSubtitle => '把已儲存的記憶注入對話，並允許此助手寫入新記憶';

  @override
  String get assistantEditAutoOrganizeTitle => '自動整理記憶';

  @override
  String get assistantEditAutoOrganizeSubtitle => '對話後自動執行記憶管線';

  @override
  String get assistantEditAllowPastRecallTitle => '允許回憶過去對話';

  @override
  String get assistantEditAllowPastRecallSubtitle => '啟用跨會話的對話搜尋';

  @override
  String get assistantEditGenerateSummaryTitle => '產生會話摘要';

  @override
  String get assistantEditGenerateSummarySubtitle => '摘要僅供對話搜尋使用';

  @override
  String get assistantEditManageMemoryTitle => '本助手可見的記憶';

  @override
  String get assistantEditWriteScopeTitle => '記憶寫入範圍';

  @override
  String get assistantEditWriteScopeSubtitle => '新記憶預設寫入的位置';

  @override
  String get assistantEditWriteScopeAlwaysGlobal => '一律全域';

  @override
  String get assistantEditWriteScopeAlwaysGlobalSubtitle => '新記憶對所有助手可見';

  @override
  String get assistantEditWriteScopeAlwaysAssistant => '一律本助手';

  @override
  String get assistantEditWriteScopeAlwaysAssistantSubtitle => '新記憶只對本助手可見';

  @override
  String get assistantEditWriteScopeToolDefaultGlobal => '模型自選（預設全域）';

  @override
  String get assistantEditWriteScopeToolDefaultGlobalSubtitle =>
      '模型可選擇全域或本助手，缺省寫入全域';

  @override
  String get assistantEditWriteScopeToolDefaultAssistant => '模型自選（預設本助手）';

  @override
  String get assistantEditWriteScopeToolDefaultAssistantSubtitle =>
      '模型可選擇全域或本助手，缺省寫入本助手';

  @override
  String get assistantEditDedupeModeTitle => '去重方式';

  @override
  String get assistantEditDedupeModeSubtitle => '候選記憶如何與既有條目比對';

  @override
  String get assistantEditDedupeModeBatched => '合併';

  @override
  String get assistantEditDedupeModeBatchedSubtitle =>
      '一次請求判斷本輪全部候選。更快更省；條目多時精度較差。';

  @override
  String get assistantEditDedupeModePerItem => '逐條';

  @override
  String get assistantEditDedupeModePerItemSubtitle =>
      '每條候選單獨請求判斷。更準確，但會增加處理模型呼叫。';

  @override
  String get assistantEditOrganizeFrequencyTitle => '整理頻率';

  @override
  String get assistantEditOrganizeFrequencySubtitle => '每累積 N 輪助手回覆觸發一次自動整理';

  @override
  String assistantEditOrganizeFrequencyOption(int n) {
    return '每 $n 輪';
  }

  @override
  String get assistantEditOrganizeFrequencyCustomButton => '自訂';

  @override
  String get assistantEditOrganizeFrequencyCustomTitle => '自訂整理頻率';

  @override
  String get assistantEditOrganizeFrequencyCustomDescription =>
      '請輸入 1 到 20 之間的整數。';

  @override
  String get assistantEditOrganizeFrequencyCustomLabel => '輪數';

  @override
  String get assistantEditOrganizeFrequencyCustomHint => '1–20';

  @override
  String get assistantEditOrganizeFrequencyCustomInvalid => '請輸入 1 到 20 之間的整數';

  @override
  String get worldBookTitle => '世界書';

  @override
  String get worldBookAdd => '新增世界書';

  @override
  String get worldBookEmptyMessage => '暫無世界書';

  @override
  String get worldBookUnnamed => '未命名世界書';

  @override
  String get worldBookDisabledTag => '已停用';

  @override
  String get worldBookAlwaysOnTag => '常駐';

  @override
  String get worldBookAddEntry => '新增條目';

  @override
  String get worldBookExport => '分享/匯出';

  @override
  String get worldBookConfig => '設定';

  @override
  String get worldBookDeleteTitle => '刪除世界書';

  @override
  String worldBookDeleteMessage(String name) {
    return '確定刪除「$name」？此操作無法復原。';
  }

  @override
  String get worldBookCancel => '取消';

  @override
  String get worldBookDelete => '刪除';

  @override
  String worldBookExportFailed(String error) {
    return '匯出失敗：$error';
  }

  @override
  String get worldBookNoEntriesHint => '暫無條目';

  @override
  String get worldBookUnnamedEntry => '未命名條目';

  @override
  String worldBookKeywordsLine(String keywords) {
    return '關鍵詞：$keywords';
  }

  @override
  String get worldBookEditEntry => '編輯條目';

  @override
  String get worldBookDeleteEntry => '刪除條目';

  @override
  String get worldBookNameLabel => '名稱';

  @override
  String get worldBookDescriptionLabel => '簡介';

  @override
  String get worldBookEnabledLabel => '啟用';

  @override
  String get worldBookSave => '儲存';

  @override
  String get worldBookEntryNameLabel => '條目名稱';

  @override
  String get worldBookEntryEnabledLabel => '啟用條目';

  @override
  String get worldBookEntryPriorityLabel => '優先級';

  @override
  String get worldBookEntryKeywordsLabel => '關鍵詞';

  @override
  String get worldBookEntryKeywordsHint => '輸入關鍵詞後點 + 新增。';

  @override
  String get worldBookEntryKeywordInputHint => '輸入關鍵詞';

  @override
  String get worldBookEntryKeywordAddTooltip => '新增關鍵詞';

  @override
  String get worldBookEntryUseRegexLabel => '使用正則';

  @override
  String get worldBookEntryCaseSensitiveLabel => '區分大小寫';

  @override
  String get worldBookEntryAlwaysOnLabel => '常駐啟用';

  @override
  String get worldBookEntryAlwaysOnHint => '無需匹配也會注入';

  @override
  String get worldBookEntryScanDepthLabel => '掃描深度';

  @override
  String get worldBookEntryContentLabel => '內容';

  @override
  String get worldBookEntryInjectionPositionLabel => '注入位置';

  @override
  String get worldBookEntryInjectionRoleLabel => '注入角色';

  @override
  String get worldBookEntryInjectDepthLabel => '注入深度';

  @override
  String get worldBookInjectionPositionBeforeSystemPrompt => '系統提示前';

  @override
  String get worldBookInjectionPositionAfterSystemPrompt => '系統提示後';

  @override
  String get worldBookInjectionPositionTopOfChat => '對話頂部';

  @override
  String get worldBookInjectionPositionBottomOfChat => '對話底部';

  @override
  String get worldBookInjectionPositionAtDepth => '指定深度';

  @override
  String get worldBookInjectionRoleUser => '使用者';

  @override
  String get worldBookInjectionRoleAssistant => '助手';

  @override
  String get mcpToolNeedsApproval => '需要審批';

  @override
  String get toolApprovalPending => '等待審批';

  @override
  String get toolApprovalApprove => '批准';

  @override
  String get toolApprovalDeny => '拒絕';

  @override
  String get toolApprovalDenyTitle => '拒絕工具調用';

  @override
  String get toolApprovalDenyHint => '原因（可選）';

  @override
  String toolApprovalDeniedMessage(Object reason, Object toolName) {
    return '工具調用 \"$toolName\" 已被使用者拒絕。原因：$reason';
  }

  @override
  String get askUserCardSubmit => '提交回答';

  @override
  String get askUserCardCustomHint => '輸入你的回答';

  @override
  String get askUserCardSomethingElse => '其他';

  @override
  String get askUserCardSkip => '跳過';

  @override
  String get askUserCardSkipped => '已跳過';

  @override
  String get askUserCardAnswered => '已回答';

  @override
  String get askUserCardInactive => '這個問題已不再活動。請重新生成或繼續對話。';

  @override
  String get askUserCardCancelled => '問題已取消';

  @override
  String askUserCardQuestionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '詢問 $count 個問題',
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
  String get debugPageConversationToolsTitle => '對話工具';

  @override
  String get debugPageCreateOversizedConversationButton => '建立超大對話（30 MB）';

  @override
  String get debugPageCreateManyMessagesConversationButton => '建立 1024 條訊息的對話';

  @override
  String get debugPageCreateDailyMixedMarkdownConversationButton =>
      '建立 3000 條日常混合 Markdown 訊息';

  @override
  String get debugPageCreateLongReasoningConversationButton =>
      '建立長思考鏈對話（128 條）';

  @override
  String get debugPageCreatingButton => '建立中...';

  @override
  String get debugPageCreatingOversizedConversation => '正在建立 30 MB 超大對話...';

  @override
  String get debugPageCreatingManyMessagesConversation => '正在建立 1024 條訊息的對話...';

  @override
  String get debugPageCreatingDailyMixedMarkdownConversation =>
      '正在建立 3000 條日常混合 Markdown 對話...';

  @override
  String get debugPageCreatingLongReasoningConversation => '正在建立長思考鏈調試對話...';

  @override
  String get debugPageNoCurrentAssistant => '目前沒有助手。請先建立或選擇一個助手。';

  @override
  String debugPageConversationCreated(int count) {
    return '已建立包含 $count 條訊息的調試對話。';
  }

  @override
  String debugPageCreateConversationFailed(String error) {
    return '建立調試對話失敗：$error';
  }

  @override
  String debugPageOversizedConversationTitle(int sizeMB) {
    return '超大對話測試（$sizeMB MB）';
  }

  @override
  String debugPageManyMessagesConversationTitle(int count) {
    return '$count 條訊息測試';
  }

  @override
  String debugPageDailyMixedMarkdownConversationTitle(int count) {
    return '$count 條日常混合 Markdown 訊息測試';
  }

  @override
  String debugPageLongReasoningConversationTitle(int count) {
    return '$count 條長思考鏈測試';
  }

  @override
  String get debugPageOversizedConversationSeedText =>
      '這是一段用於復現超大對話渲染卡頓的長調試文字。它包含重複的 Markdown 風格文字、標點、中文內容和普通詞語，方便測試聊天渲染、儲存和捲動效能。';

  @override
  String debugPageManyMessagesSeedText(String role, int index) {
    return '$role 訊息 #$index：快速隨機調試樣例，用於測試列表渲染、捲動穩定性、訊息分組和會話歷史效能。';
  }

  @override
  String get migrationIntroTitle => '升級聊天記錄儲存';

  @override
  String get migrationIntroSubtitle =>
      'Kelivo 將聊天記錄遷移到更快的 SQLite 資料庫。升級會在應用程式開啟前完成，避免新舊資料同時寫入。';

  @override
  String get migrationBackupNote => '遷移開始前，會先匯出包含設定、聊天記錄和本地檔案的 ZIP 備份。';

  @override
  String get migrationPerformanceNote =>
      '遷移後，啟動、歷史載入和搜尋都會使用 SQLite 索引，長對話會更流暢。';

  @override
  String get migrationSourceDatabaseLabel => 'Hive';

  @override
  String get migrationTargetDatabaseLabel => 'SQLite';

  @override
  String get migrationChooseFolderButton => '選擇資料夾並備份';

  @override
  String get migrationSaveBackupButton => '儲存備份 ZIP';

  @override
  String get migrationBackingUpTitle => '正在備份';

  @override
  String get migrationBackingUpSubtitle =>
      '正在匯出設定、聊天記錄、上傳檔案、圖片和字體。請保持 Kelivo 開啟，等待備份完成。';

  @override
  String get migrationMigratingTitle => '正在遷移到 SQLite';

  @override
  String get migrationMigratingSubtitle =>
      '正在分批寫入對話和訊息，避免超大聊天記錄占滿記憶體。請保持 Kelivo 在前台，等待遷移完成。';

  @override
  String migrationBackingUpDetail(String fileName) {
    return '正在備份 $fileName';
  }

  @override
  String migrationMigratingDetail(int count) {
    return '已遷移 $count 條訊息';
  }

  @override
  String get migrationMigratingPrepareDetail => '正在準備 SQLite 資料庫';

  @override
  String get migrationMigratingToolEventsDetail => '正在遷移工具呼叫記錄';

  @override
  String get migrationMigratingValidateDetail => '正在校驗遷移資料';

  @override
  String get migrationBackupReadyDetail => '備份 ZIP 已準備好';

  @override
  String get migrationSavingBackupZipDetail => '正在儲存備份 ZIP';

  @override
  String get migrationBackupFileSavedTitle => '備份 ZIP 已保存';

  @override
  String get migrationChecklistBackupFiles => '匯出 Hive 備份 ZIP';

  @override
  String get migrationChecklistPrepareSqlite => '準備 SQLite 資料庫';

  @override
  String get migrationChecklistMigrateMessages => '遷移對話和訊息';

  @override
  String get migrationChecklistMigrateToolEvents => '遷移工具呼叫記錄';

  @override
  String get migrationChecklistValidate => '校驗遷移資料';

  @override
  String get migrationStepBackup => '備份';

  @override
  String get migrationStepMigrate => '遷移';

  @override
  String get migrationStepComplete => '完成';

  @override
  String get migrationCompleteTitle => '升級完成';

  @override
  String get migrationCompleteSubtitle =>
      '你的聊天記錄已遷移到 SQLite。請重啟 Kelivo 進入升級後的應用程式。';

  @override
  String get migrationConversationCount => '對話';

  @override
  String get migrationMessageCount => '訊息';

  @override
  String get migrationConvertedCount => '已轉換';

  @override
  String get migrationMalformedCount => '格式異常';

  @override
  String get migrationMissingFilesCount => '缺失檔案';

  @override
  String get migrationRestartButton => '重啟 Kelivo';

  @override
  String get migrationFailedTitle => '遷移失敗';

  @override
  String get migrationFailedSubtitle => '原始 Hive 資料和備份都仍然保留。查看下方原因後可以重試。';

  @override
  String get migrationUnknownError => '未知遷移錯誤。';

  @override
  String get migrationFailureLogTitle => '失敗日誌';

  @override
  String get migrationRetryButton => '重試遷移';

  @override
  String get migrationSkipButton => '跳過遷移並全新開始';

  @override
  String get migrationSkipDialogTitle => '跳過遷移？';

  @override
  String get migrationSkipDialogMessage =>
      'Kelivo 將以空的聊天資料庫啟動。舊的聊天記錄會保留在磁碟上（重新命名為 .retired 後綴），但不會被遷移，也不會在應用程式中顯示。之後如需找回，請使用已儲存的備份 ZIP。';

  @override
  String get migrationSkipDialogCancel => '取消';

  @override
  String get migrationSkipDialogConfirm => '跳過並全新開始';

  @override
  String get migrationChatsExportDegradedNote =>
      'chats.json 匯出因出錯而被跳過。備份 ZIP 仍包含原始 Hive 檔案，完整聊天記錄未遺失。';

  @override
  String get timelineJumpToLatest => '跳到最新';

  @override
  String largeContentShowMore(int count) {
    return '再顯示 $count 項';
  }

  @override
  String get largeContentCollapse => '收起';

  @override
  String get imageSettingsPageTitle => '圖片處理';

  @override
  String get imageSettingsPageEditSectionTitle => '編輯';

  @override
  String get imageSettingsPageQualitySectionTitle => '上傳圖片品質';

  @override
  String get imageSettingsPageQualityOriginal => '原圖';

  @override
  String get imageSettingsPageQualityOriginalSubtitle => '不壓縮，原樣上傳';

  @override
  String get imageSettingsPageQualityHigh => '高品質';

  @override
  String get imageSettingsPageQualityHighSubtitle => '最長邊 2048 像素 · 品質 90';

  @override
  String get imageSettingsPageQualityBalanced => '平衡';

  @override
  String get imageSettingsPageQualityBalancedSubtitle => '最長邊 1568 像素 · 品質 85';

  @override
  String get imageSettingsPageQualitySaver => '節省流量';

  @override
  String get imageSettingsPageQualitySaverSubtitle => '最長邊 1024 像素 · 品質 70';

  @override
  String get imageSettingsPageQualityCustom => '自訂';

  @override
  String get imageSettingsPageQualityCustomSubtitle => '自選壓縮品質';

  @override
  String get imageSettingsPageCustomQualityTitle => '壓縮品質';

  @override
  String get imageSettingsPageCompressTransparentTitle => '壓縮透明及動態圖片';

  @override
  String get imageSettingsPageCompressTransparentSubtitle =>
      '開啟後將壓縮透明 PNG、GIF 等格式；透明區域填充為白色，動圖僅保留第一幀。';

  @override
  String get imageSettingsPageFooter =>
      '壓縮會在加入圖片時進行，已儲存或已傳送的圖片不受影響；壓縮後圖片會以 JPEG 格式隨訊息傳送。';

  @override
  String get memoryTraceSettingsTitle => '流程追蹤';

  @override
  String get memoryTraceSettingsSubtitle => '逐步檢視每次背景記憶處理的完整過程';

  @override
  String get memoryTracePageTitle => '記憶流程追蹤';

  @override
  String get memoryTraceRecordingSection => '記錄';

  @override
  String get memoryTraceToggleTitle => '記錄流程追蹤';

  @override
  String get memoryTraceToggleSubtitle => '僅在記憶體中保留最近幾次背景執行的提示詞、模型回覆與實際變更';

  @override
  String get memoryTraceRunsSection => '最近執行';

  @override
  String get memoryTraceEmptyTitle => '尚無追蹤記錄';

  @override
  String get memoryTraceEmptySubtitle => '背景記憶流程執行後，記錄會顯示在這裡。';

  @override
  String get memoryTraceDisabledTitle => '記錄已關閉';

  @override
  String get memoryTraceDisabledSubtitle => '開啟記錄後，下一次背景記憶執行才會被擷取。';

  @override
  String get memoryTraceClearAction => '清空';

  @override
  String get memoryTraceClearSheetTitle => '清空追蹤記錄';

  @override
  String get memoryTraceClearSheetMessage => '將刪除所有已記錄的追蹤。追蹤從不寫入磁碟，因此不會影響其他資料。';

  @override
  String get memoryTraceClearConfirm => '清空記錄';

  @override
  String get memoryTraceCancel => '取消';

  @override
  String get memoryTraceClearedToast => '追蹤記錄已清空';

  @override
  String get memoryTraceCopyAction => '複製';

  @override
  String get memoryTraceCopiedToast => '已複製到剪貼簿';

  @override
  String get memoryTraceTriggerAuto => '自動';

  @override
  String get memoryTraceTriggerManual => '手動';

  @override
  String get memoryTraceTriggerTool => '工具呼叫';

  @override
  String get memoryTraceTriggerSummary => '對話摘要';

  @override
  String get memoryTraceScopeAssistant => '助手';

  @override
  String get memoryTraceScopeGlobal => '全域';

  @override
  String get memoryTraceStepGatekeeper => '守門判斷';

  @override
  String get memoryTraceStepExtract => '記憶擷取';

  @override
  String get memoryTraceStepSmartAdd => '智慧寫入';

  @override
  String get memoryTraceStepDistiller => '使用者輪廓提煉';

  @override
  String get memoryTraceStepSummary => '對話摘要生成';

  @override
  String get memoryTraceStepChatSearch => '歷史對話檢索';

  @override
  String get memoryTraceStepTool => '記憶工具';

  @override
  String get memoryTraceStatusSuccess => '成功';

  @override
  String get memoryTraceStatusFailed => '失敗';

  @override
  String get memoryTraceStatusSkipped => '略過';

  @override
  String get memoryTraceStatusRunning => '進行中';

  @override
  String get memoryTraceOutcomeAdvanced => '水位已推進';

  @override
  String get memoryTraceOutcomeHeld => '水位未推進';

  @override
  String get memoryTraceOutcomeForced => '強制推進';

  @override
  String get memoryTraceDetailTitle => '追蹤詳情';

  @override
  String get memoryTraceSectionOverview => '概覽';

  @override
  String get memoryTraceSectionPrompt => '提示詞';

  @override
  String get memoryTraceSectionResponse => '原始回覆';

  @override
  String get memoryTraceSectionParsed => '解析結果';

  @override
  String get memoryTraceSectionMutations => '實際變更';

  @override
  String get memoryTraceFieldTime => '開始時間';

  @override
  String get memoryTraceFieldDuration => '耗時';

  @override
  String get memoryTraceFieldTrigger => '觸發方式';

  @override
  String get memoryTraceFieldScope => '作用範圍';

  @override
  String get memoryTraceFieldConversation => '對話';

  @override
  String get memoryTraceFieldAssistant => '助手';

  @override
  String get memoryTraceFieldWindow => '訊息視窗';

  @override
  String get memoryTraceFieldWatermark => '水位';

  @override
  String get memoryTraceFieldOutcome => '結果';

  @override
  String get memoryTraceFieldError => '錯誤';

  @override
  String get memoryTraceMutationCreated => '新增';

  @override
  String get memoryTraceMutationMerged => '合併';

  @override
  String get memoryTraceMutationEdited => '修改';

  @override
  String get memoryTraceMutationArchived => '封存';

  @override
  String get memoryTraceMutationLinked => '關聯';

  @override
  String get memoryTraceMutationProfileWritten => '寫入輪廓欄位';

  @override
  String get memoryTraceMutationProfileCleared => '清除輪廓欄位';

  @override
  String get memoryTraceMutationSummary => '寫入對話摘要';

  @override
  String get memoryTraceBefore => '變更前';

  @override
  String get memoryTraceAfter => '變更後';

  @override
  String get memoryTraceEmptyValue => '（空）';

  @override
  String memoryTraceStepsCount(int count) {
    return '$count 個步驟';
  }

  @override
  String memoryTraceMutationsCount(int count) {
    return '$count 項變更';
  }

  @override
  String memoryTraceRepeatCount(int count) {
    return '重複 $count 次';
  }

  @override
  String memoryTraceWindowValue(int size, int start, int end) {
    return '$size 則訊息 · #$start–#$end';
  }

  @override
  String get memoryTraceShowMore => '展開全文';

  @override
  String get memoryTraceShowLess => '收合';

  @override
  String get messageStyleSettingsPageTitle => '訊息樣式';

  @override
  String get messageStyleSettingsPageReset => '重設';

  @override
  String get messageStyleSettingsPageResetConfirm => '恢復全部訊息樣式自訂？';

  @override
  String get messageStyleSettingsPageCancel => '取消';

  @override
  String get messageStyleSettingsPageLight => '淺色';

  @override
  String get messageStyleSettingsPageDark => '深色';

  @override
  String get messageStyleSettingsPageDefaultHint => '預設樣式跟隨目前主題，沒有可調參數。';

  @override
  String get messageStyleSettingsPageStyleDefaultSubtitle => '跟隨主題，不可調節';

  @override
  String get messageStyleSettingsPageStyleFrostedSubtitle => '半透明毛玻璃';

  @override
  String get messageStyleSettingsPageStyleSolidSubtitle => '不透明純色底';

  @override
  String get messageStyleSettingsPageBlur => '模糊強度';

  @override
  String get messageStyleSettingsPageBlurHint => '模糊作用於氣泡背後的內容，未設定聊天桌布時效果不明顯';

  @override
  String get messageStyleSettingsPageBackgroundColor => '背景顏色';

  @override
  String get messageStyleSettingsPageBackgroundOpacity => '背景不透明度';

  @override
  String get messageStyleSettingsPageBorderColor => '邊框顏色';

  @override
  String get messageStyleSettingsPageBorderOpacity => '邊框不透明度';

  @override
  String get messageStyleSettingsPageBorderWidth => '邊框寬度';

  @override
  String get messageStyleSettingsPageTextColor => '文字顏色';

  @override
  String get messageStyleSettingsPageCornerRadius => '圓角半徑';

  @override
  String get messageStyleSettingsPagePreviewUser => '這是一則使用者訊息';

  @override
  String get messageStyleSettingsPagePreviewAssistant => '這是一則助手回覆。';

  @override
  String get messageStyleSettingsPagePreviewThinking => '思考中';

  @override
  String get messageStyleSettingsPageRoleUser => '使用者';

  @override
  String get messageStyleSettingsPageRoleAssistant => '助手';

  @override
  String get messageStyleSettingsPageRoleAssistantHint =>
      '助手設定同時作用於思考、工具呼叫和翻譯卡片。';
}
