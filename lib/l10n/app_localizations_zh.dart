// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get settingsSearchHint => '搜索设置';

  @override
  String get settingsSearchCancel => '取消';

  @override
  String get settingsSearchClear => '清空搜索';

  @override
  String get settingsSearchSuggestions => '常用设置';

  @override
  String get settingsSearchNoResults => '未找到相关设置';

  @override
  String get settingsSearchNoResultsHint => '试试其他名称，或更简短的关键词。';

  @override
  String settingsSearchResultCount(int count) {
    return '找到 $count 项设置';
  }

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
  String get storageSpacePageTitle => '存储空间';

  @override
  String get storageSpaceRefreshTooltip => '刷新';

  @override
  String get storageSpaceLoadFailed => '无法加载文件或检查图片使用情况，请刷新后重试。';

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
  String get storageSpaceCategoryDisplacedDatabases => '保留的旧数据库';

  @override
  String get storageSpaceSubDisplacedDatabases => '自动重建前保留的数据库';

  @override
  String get storageSpaceClearDisplacedDatabasesConfirmMessage =>
      '确定删除这些保留的旧数据库吗？它们是 Kelivo 重建数据库时留下的，可能是那些聊天记录和设置仅存的一份。删除后无法恢复。';

  @override
  String get storageSpaceRestoreTracesHint => '恢复完成后保留的旧数据快照。清理不会影响当前应用数据。';

  @override
  String get storageSpaceClearRestoreTracesButton => '清理恢复痕迹';

  @override
  String get storageSpaceClearDisplacedDatabasesButton => '删除保留的旧数据库';

  @override
  String get storageSpaceClearRestoreTracesConfirmMessage =>
      '确定清理已完成恢复留下的旧数据快照吗？当前数据库、设置和文件不会受到影响。';

  @override
  String get storageSpaceSubCompletedRestoreRuns => '已完成的恢复快照';

  @override
  String get storageSpaceCategoryCache => '缓存';

  @override
  String get storageSpaceCategoryLogs => '日志';

  @override
  String get storageSpaceCategoryOther => '其他';

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
    return '删除 $count 个项目及其对应的会话附件副本？删除后，聊天记录中的这些附件将无法使用。';
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
  String statsPageCost(String currency) {
    return '费用 ($currency)';
  }

  @override
  String statsPageModelsWithoutPricing(int count) {
    return '$count 个模型无定价';
  }

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
  String contextMessageCount(int count) {
    return '$count 条消息';
  }

  @override
  String contextMessageCountLimited(int actual, int configured) {
    return '$actual/$configured 条消息';
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
  String get mcpServerEditSheetStdioCommandLabel => '命令';

  @override
  String get mcpServerEditSheetStdioArgumentsLabel => '参数';

  @override
  String get mcpServerEditSheetStdioWorkingDirectoryLabel => '工作目录（可选）';

  @override
  String get mcpWorkspaceBindingLabel => '绑定工作区（可选）';

  @override
  String get mcpWorkspaceBindingHint =>
      '服务器可通过 /workspace 访问此工作区。工作目录留空时默认进入该目录，切换聊天不会改变绑定。';

  @override
  String get mcpWorkspaceBindingMobileOnly =>
      '工作区绑定适用于移动端 Linux 环境。在桌面端运行此服务器前，请先解除绑定。';

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
  String get assistantEditThinkingBudgetTitle => '思考';

  @override
  String get assistantEditReasoningFollowDefault => '跟随模型默认';

  @override
  String get assistantEditReasoningClampedSubtitle => '实际档位会按各模型的能力收敛';

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
  String get iosBackgroundStatusOn => '开启';

  @override
  String get iosBackgroundStatusOff => '关闭';

  @override
  String get iosLiveActivityTitle => '实时活动';

  @override
  String get iosLiveActivitySubtitle => '支持时在锁屏和灵动岛显示后台回复状态。';

  @override
  String get notificationChatCompletedTitle => '生成完成';

  @override
  String get notificationChatCompletedBody => '助手回复已生成';

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
  String get assistantEditPromptIso8601Title => '使用 ISO 8601 格式';

  @override
  String get assistantEditPromptIso8601Subtitle =>
      '包含时区偏移，例如 2026-08-08T14:30:05+08:00';

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
  String get backupPageScopeTitle => '备份与导入内容';

  @override
  String backupPageScopeSelectedCount(int selected, int total) {
    return '$selected/$total';
  }

  @override
  String get backupPageBackupManagementDescription =>
      '选择备份和导入的内容，适用于本地、WebDAV 和 S3。导入时保留未选中的内容。技能和工作区包含各自的文件。';

  @override
  String get backupPageAssistantsLabel => '助手';

  @override
  String get backupPageProvidersLabel => '供应商';

  @override
  String get backupPageMcpLabel => 'MCP 服务器';

  @override
  String get backupPageEnvironmentVariablesLabel => '环境变量';

  @override
  String get backupPageSkillsLabel => '技能';

  @override
  String get backupPageWorldBooksLabel => '世界书';

  @override
  String get backupPageMemoriesLabel => '记忆';

  @override
  String get backupPageQuickPhrasesLabel => '快捷短语';

  @override
  String get backupPageInstructionsLabel => '提示词注入';

  @override
  String get backupPageWorkspacesLabel => '工作区';

  @override
  String get backupPageSearchServicesLabel => '搜索服务';

  @override
  String get backupPageSpeechServicesLabel => '语音服务';

  @override
  String get backupPageSettingsLabel => '其他设置';

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
  String get backupRestoreDirectoryBlockedTitle => '还原正在等待目录释放';

  @override
  String get backupRestoreDirectoryBlockedContent =>
      'Windows 无法移动下方目录。请关闭正在使用该目录的终端、编辑器或其他程序，然后继续还原。如果仍然受阻，请检查当前账户是否有移动该目录的权限。此前的还原进度已保留。';

  @override
  String get backupRestoreContinueButton => '继续还原';

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
  String get restoreProgressTitle => '正在恢复备份';

  @override
  String get restoreProgressWarning => '请保持 Kelivo 开启直到完成。此时关闭应用，下次启动会从头再来一次。';

  @override
  String get restoreProgressStageCheckingBackup => '正在校验备份';

  @override
  String get restoreProgressStagePreservingCurrentData => '正在保留当前数据';

  @override
  String get restoreProgressStageInstallingBackup => '正在写入备份';

  @override
  String get restoreProgressStageVerifying => '正在验证';

  @override
  String get restoreProgressStageRollingBack => '正在恢复原有数据';

  @override
  String get restoreProgressStageFinishing => '即将完成';

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
  String get startupRecoveryRepairFailed =>
      '修复未能完成。数据已保留，可以选择通过校验的副本恢复，或导出数据进一步排查。';

  @override
  String get startupRecoveryResetFailed => '重置失败。请彻底关闭 Kelivo 后重新打开。';

  @override
  String get startupRecoveryResetDialogTitle => '重置全部数据？';

  @override
  String get startupRecoveryResetDialogContent =>
      '开始使用新的空数据库？当前数据库及其日志文件、已有副本都会保留，供之后恢复。';

  @override
  String get startupRecoveryResetDialogConfirm => '重置并重启';

  @override
  String get startupRecoveryResetDialogCancel => '取消';

  @override
  String get startupRecoveryWhatFailed => '失败原因';

  @override
  String get startupRecoveryStageLabel => '失败阶段';

  @override
  String get startupRecoveryStageRestore => '恢复关卡';

  @override
  String get startupRecoveryStageDatabase => '数据库启动';

  @override
  String get startupRecoveryDiagnosticLabel => '诊断码';

  @override
  String get startupRecoverySchemaLabel => '数据库版本';

  @override
  String startupRecoverySchemaValue(String installed, int expected) {
    return '磁盘上为 $installed · 当前版本需要 $expected';
  }

  @override
  String get startupRecoveryAppVersionLabel => '应用';

  @override
  String get startupRecoveryUnknownValue => '未知';

  @override
  String get startupRecoveryCollecting => '正在收集诊断信息…';

  @override
  String get startupRecoveryShowDetails => '展开技术细节';

  @override
  String get startupRecoveryHideDetails => '收起技术细节';

  @override
  String get startupRecoveryCopyReport => '复制完整报告';

  @override
  String get startupRecoveryReportCopied => '已复制完整报告';

  @override
  String get startupRecoveryShareReport => '导出报告';

  @override
  String startupRecoveryReportStored(String path) {
    return '报告已保存到 $path';
  }

  @override
  String startupRecoveryReportSaved(String path) {
    return '报告已保存到 $path';
  }

  @override
  String get startupRecoveryReportShared => '报告已导出。';

  @override
  String get startupRecoveryReportSaveFailed => '无法导出报告。';

  @override
  String get startupRecoverySectionDataTitle => '你的数据';

  @override
  String get startupRecoverySectionDataBody =>
      '目前没有任何数据被删除。在尝试下面的操作前，先把副本保存到安全的地方。';

  @override
  String startupRecoveryExportSavedTo(String path) {
    return '数据副本已保存到 $path';
  }

  @override
  String get startupRecoverySectionRepairTitle => '诊断与修复';

  @override
  String get startupRecoverySectionRepairBody =>
      '完整性检查只读取数据库。修复会清理上次更新中断留下的元数据并重新启动，不会删除聊天记录。';

  @override
  String get startupRecoveryIntegrityButton => '检查数据库完整性';

  @override
  String get startupRecoveryIntegrityHealthy => 'SQLite 未在数据库文件中发现损坏。';

  @override
  String startupRecoveryIntegrityDamaged(String detail) {
    return 'SQLite 报告了问题 —— $detail';
  }

  @override
  String get startupRecoveryIntegrityMissing => '数据目录中没有找到数据库文件。';

  @override
  String get startupRecoveryIntegrityFailed => '完整性检查无法运行。';

  @override
  String get startupRecoveryDangerZone => '危险操作';

  @override
  String get startupRecoveryDangerBody =>
      '重新开始后，当前数据将不再显示。Kelivo 会保留旧数据库和已有副本以供恢复，建议先导出一份数据副本。';

  @override
  String get startupRecoveryResetAcknowledge => '我确认开始使用新的空数据库。';

  @override
  String get startupDatabaseUpdateRequiredTitle => '请更新 Kelivo 以继续';

  @override
  String get startupDatabaseUpdateRequiredContent =>
      '本设备上的聊天数据库由更新版本的 Kelivo 创建，当前版本无法打开。数据未被改动。请安装最新版 Kelivo 后重新打开。';

  @override
  String get startupDatabaseUpdateRequiredDowngradeTitle => '若要改用旧版';

  @override
  String get startupDatabaseUpdateRequiredDowngradeIntro =>
      '当前版本打不开本机这份数据库。若你必须留在旧版，请按下面的步骤处理；在备份完成之前，不要删除或覆盖这里的数据。';

  @override
  String get startupDatabaseUpdateRequiredDowngradeStep1 =>
      '先安装并打开最新版 Kelivo，在「设置 → 数据备份」导出一份备份文件。';

  @override
  String startupDatabaseUpdateRequiredDowngradeStep2(String url) {
    return '打开 $url，把备份转换成你打算使用的旧版格式。';
  }

  @override
  String get startupDatabaseUpdateRequiredDowngradeStep3 =>
      '确认本机数据已经另外备份好之后，再安装旧版，并导入转换后的备份。';

  @override
  String get startupDatabaseUpdateRequiredOpenTool => '打开转换工具';

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
      '请选择恢复方式。备份管理中的分类开关同样适用于本次导入。';

  @override
  String get backupPageOverwriteMode => '完全覆盖';

  @override
  String get backupPageOverwriteModeDescription =>
      '替换所选内容，保留未选内容及其他本机设置。替换聊天时，也会清除本机未发送的草稿。';

  @override
  String get backupPageMergeMode => '合并';

  @override
  String get backupPageMergeModeDescription =>
      '保留本地数据并加入备份数据；相同会话会跳过，冲突会话会重新分配 ID。';

  @override
  String get backupPageRestore => '恢复';

  @override
  String get backupPageForwardCompatTitle => '备份来自更新的版本';

  @override
  String backupPageForwardCompatBody(int backupVersion, int currentVersion) {
    return '这份备份由更新版本的 Kelivo 创建（数据格式 $backupVersion，当前版本支持 $currentVersion），且未声明旧版本能否读取。\n\n你可以继续导入：当前版本不认识的内容会被跳过，备份文件本身不会被修改。但如果新版本改变了已有数据的存储方式，部分内容可能会被错误导入。\n\n更稳妥的做法是先升级 Kelivo。';
  }

  @override
  String get backupPageForwardCompatContinue => '仍然导入';

  @override
  String get backupPageForwardCompatCancel => '取消';

  @override
  String get backupPageSchemaTooNewMessage =>
      '这份备份由更新版本的 Kelivo 创建，当前版本无法读取。请先升级 Kelivo 后重试。';

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
  String get backupProgressFailed => '操作失败';

  @override
  String backupProgressFailedAt(String phase) {
    return '失败阶段：$phase';
  }

  @override
  String get backupProgressCopyError => '复制错误';

  @override
  String get backupProgressErrorCopied => '错误已复制';

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
  String get backupPageIosSystemBackupNote =>
      'Kelivo 的本地数据已设置为不参与 iCloud 系统备份。换机或卸载 App 前，请先导出备份文件。';

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
  String get compressContextDesc => '生成可查看、可撤销的摘要';

  @override
  String get clearContextDesc => '标记上下文分界点';

  @override
  String get contextManagement => '上下文管理';

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
  String get compressContextOptionsDesc => '在当前聊天生成可查看、可编辑、可撤销的摘要。原始消息保留。';

  @override
  String get compressContextKeepStart => '开头取样';

  @override
  String get compressContextKeepRecent => '末尾取样';

  @override
  String get compressContextUnlimited => '全部内容';

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
  String get compressContextKeepRecentMessages => '保留 N 条';

  @override
  String get compressContextKeepCountLabel => '保留用户消息数';

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
  String get reasoningBudgetSheetTitle => '思维链强度';

  @override
  String get reasoningLevelSheetTitle => '推理';

  @override
  String get reasoningLevelAuto => '自动';

  @override
  String get reasoningLevelAutoSubtitle => '使用模型或供应商的默认设置';

  @override
  String get reasoningLevelOff => '关闭';

  @override
  String get reasoningLevelOffSubtitle => '关闭推理，直接回答';

  @override
  String get reasoningLevelMinimal => '最低';

  @override
  String get reasoningLevelMinimalSubtitle => '使用极少推理来回答问题';

  @override
  String get reasoningLevelLow => '低';

  @override
  String get reasoningLevelLowSubtitle => '使用少量推理来回答问题';

  @override
  String get reasoningLevelMedium => '中';

  @override
  String get reasoningLevelMediumSubtitle => '使用较多推理来回答问题';

  @override
  String get reasoningLevelHigh => '高';

  @override
  String get reasoningLevelHighSubtitle => '使用大量推理来回答问题，适合复杂问题';

  @override
  String get reasoningLevelXhigh => '极高';

  @override
  String get reasoningLevelXhighSubtitle => '使用很高推理深度，适合更复杂的问题';

  @override
  String get reasoningLevelMax => '最大';

  @override
  String get reasoningLevelMaxSubtitle => '使用最大推理深度，适合最复杂的问题';

  @override
  String get reasoningLevelFollowModelDefaultSubtitle => '使用模型或助手未设置时的默认档位';

  @override
  String get reasoningLevelNoReasoning => '此模型不支持推理';

  @override
  String get reasoningLevelCustomBudget => '自定义推理预算';

  @override
  String get reasoningLevelCustomBudgetHint => '例如：2048';

  @override
  String get reasoningLevelCompactMin => 'min';

  @override
  String get reasoningLevelCompactLow => 'low';

  @override
  String get reasoningLevelCompactMid => 'mid';

  @override
  String get reasoningLevelCompactHigh => 'high';

  @override
  String get reasoningLevelCompactXhigh => 'xhigh';

  @override
  String get reasoningLevelCompactMax => 'max';

  @override
  String reasoningLevelBudgetTokens(String budget) {
    return '$budget tokens';
  }

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
  String chatMessageWidgetWebFetch(String target) {
    return '读取网页: $target';
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
  String get displaySettingsPageCollapseLongUserMessagesTitle => '折叠过长消息';

  @override
  String get displaySettingsPageCollapseLongUserMessagesSubtitle =>
      '超过阈值的用户消息折叠显示，点击可展开';

  @override
  String get displaySettingsPageCollapseLongUserMessagesCharsTitle =>
      '超过多少字符折叠';

  @override
  String get displaySettingsPageCollapseLongUserMessagesCharsUnit => '字符';

  @override
  String get chatMessageExpandLongText => '展开';

  @override
  String get chatMessageCollapseLongText => '收起';

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
  String get chatInputBarToolsTooltip => '工具';

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
  String get chatInputBarVoiceAttachAudioTooltip => '停止并存为音频';

  @override
  String get chatInputBarVoiceSendAudioTooltip => '直接发送录音';

  @override
  String get chatInputBarVoiceSavingAudio => '正在保存录音…';

  @override
  String get audioClipPlayTooltip => '播放音频';

  @override
  String get audioClipPauseTooltip => '暂停';

  @override
  String get audioClipPlaybackFailed => '无法播放此音频';

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
  String get contextUsageTitle => '上下文窗口';

  @override
  String get contextUsageStateExact => '精确（来自上次响应）';

  @override
  String get contextUsageStateExactCalibrated => '精确（分项按估算比例）';

  @override
  String get contextUsageStateEstimated => '估算';

  @override
  String get contextUsageStateStale => '已过时，正在更新…';

  @override
  String get contextUsageStateComputing => '计算中…';

  @override
  String get contextUsageStateNone => '暂无数据';

  @override
  String get contextUsageBucketSystem => '系统提示词';

  @override
  String get contextUsageBucketInjections => '指令注入';

  @override
  String get contextUsageBucketHistory => '历史消息';

  @override
  String get contextUsageBucketTools => '内置工具';

  @override
  String get contextUsageBucketMemory => '记忆';

  @override
  String get contextUsageBucketWorldBook => '世界书';

  @override
  String get contextUsageBucketSkills => '技能';

  @override
  String get contextUsageBucketWorkspace => '工作区';

  @override
  String get contextUsageBucketSearch => '搜索提示';

  @override
  String get contextUsageBucketMcpTools => 'MCP 工具';

  @override
  String get contextUsageBucketAttachments => '附件';

  @override
  String get contextUsageBucketDraft => '草稿';

  @override
  String get contextUsageBucketUsed => '已用';

  @override
  String get contextUsageFreeSpace => '剩余空间';

  @override
  String contextUsageUsedWindow(String used, String window, int percent) {
    return '$used / $window ($percent%)';
  }

  @override
  String get contextUsageNoWindow => '未设置上下文窗口';

  @override
  String get contextUsageSetWindow => '设置上下文窗口';

  @override
  String get contextUsageRefresh => '刷新';

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
  String get mcpPageStatusDisabled => '已停用';

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
  String get defaultModelPageTitleModelSubtitle =>
      '用于总结对话标题，默认跟随当前对话模型，也可指定其他模型。';

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
      '用于在助手回复后生成聊天建议，可跟随当前对话模型或指定其他模型。默认未启用。';

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
  String get defaultModelPageDisable => '禁用';

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
  String get modelDetailSheetWebFetchTool => '网页抓取';

  @override
  String get modelDetailSheetOpenrouterWebFetchToolDescription =>
      '启用 OpenRouter 网页抓取服务端工具';

  @override
  String get modelDetailSheetClaudeWebFetchToolDescription =>
      '允许 Claude 抓取对话中出现的网页与 PDF';

  @override
  String get modelDetailSheetClaudeCodeExecutionToolDescription =>
      '允许 Claude 在 Anthropic 沙箱中运行 Python 与 Bash';

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
  String get modelDetailSheetHeaderKeyHint => 'Header Key';

  @override
  String get modelDetailSheetHeaderValueHint => 'Header Value';

  @override
  String get modelDetailSheetBodyKeyHint => 'Body Key';

  @override
  String get modelDetailSheetBodyJsonHint => 'Body JSON';

  @override
  String get modelSpecFormSourceCustom => '自定义';

  @override
  String get modelSpecFormSourceCatalog => '目录';

  @override
  String get modelSpecFormSourceInferred => '推断';

  @override
  String get modelSpecFormSourceDefault => '默认';

  @override
  String get modelSpecFormReset => '重置为默认';

  @override
  String get modelSpecFormModalitiesSection => '模态与能力';

  @override
  String get modelSpecFormImageType => '图像';

  @override
  String get modelSpecFormAudioMode => '音频';

  @override
  String get modelSpecFormVideoMode => '视频';

  @override
  String get modelSpecFormPdfMode => 'PDF';

  @override
  String get modelSpecFormStructuredOutputAbility => '结构化输出';

  @override
  String get modelSpecFormReasoningSection => '推理';

  @override
  String get modelSpecFormDialect => '推理方言';

  @override
  String get modelSpecFormDialectNone => '无';

  @override
  String get modelSpecFormDialectNoneSubtitle => '不写入推理字段';

  @override
  String get modelSpecFormDialectOpenaiReasoningEffort =>
      'OpenAI reasoning effort';

  @override
  String get modelSpecFormDialectOpenaiReasoningEffortSubtitle =>
      'reasoning_effort';

  @override
  String get modelSpecFormDialectOpenaiResponsesReasoning =>
      'OpenAI Responses reasoning';

  @override
  String get modelSpecFormDialectOpenaiResponsesReasoningSubtitle =>
      'reasoning.effort';

  @override
  String get modelSpecFormDialectOpenrouterReasoning => 'OpenRouter reasoning';

  @override
  String get modelSpecFormDialectOpenrouterReasoningSubtitle => 'reasoning';

  @override
  String get modelSpecFormDialectAnthropicBudget => 'Anthropic budget';

  @override
  String get modelSpecFormDialectAnthropicBudgetSubtitle =>
      'thinking.budget_tokens';

  @override
  String get modelSpecFormDialectAnthropicAdaptiveEffort =>
      'Anthropic adaptive effort';

  @override
  String get modelSpecFormDialectAnthropicAdaptiveEffortSubtitle =>
      'thinking + output_config.effort';

  @override
  String get modelSpecFormDialectAnthropicBetweenTools =>
      'Anthropic adaptive / between_tools';

  @override
  String get modelSpecFormDialectAnthropicBetweenToolsSubtitle =>
      '自适应思考；关闭时使用 between_tools';

  @override
  String get modelSpecFormDialectAnthropicEffort => 'Anthropic effort';

  @override
  String get modelSpecFormDialectAnthropicEffortSubtitle =>
      'thinking + output_config.effort';

  @override
  String get modelSpecFormDialectGeminiThinkingBudget =>
      'Gemini thinking budget';

  @override
  String get modelSpecFormDialectGeminiThinkingBudgetSubtitle =>
      'thinkingConfig.thinkingBudget';

  @override
  String get modelSpecFormDialectGeminiThinkingLevel => 'Gemini thinking level';

  @override
  String get modelSpecFormDialectGeminiThinkingLevelSubtitle =>
      'thinkingConfig.thinkingLevel';

  @override
  String get modelSpecFormDialectQwenEnableThinking => 'Qwen enable thinking';

  @override
  String get modelSpecFormDialectQwenEnableThinkingSubtitle =>
      'enable_thinking';

  @override
  String get modelSpecFormDialectThinkingType => 'Thinking type';

  @override
  String get modelSpecFormDialectThinkingTypeSubtitle => 'thinking.type';

  @override
  String get modelSpecFormDialectSiliconflowEnableThinking =>
      'SiliconFlow enable thinking';

  @override
  String get modelSpecFormDialectSiliconflowEnableThinkingSubtitle =>
      'enable_thinking';

  @override
  String get modelSpecFormDialectInternThinkingMode => 'Intern thinking mode';

  @override
  String get modelSpecFormDialectInternThinkingModeSubtitle => 'thinking_mode';

  @override
  String get modelSpecFormDialectChatTemplateKwargs => 'Chat template kwargs';

  @override
  String get modelSpecFormDialectChatTemplateKwargsSubtitle =>
      'chat_template_kwargs.enable_thinking';

  @override
  String get modelSpecFormDialectKimiThinking => 'Kimi thinking';

  @override
  String get modelSpecFormDialectKimiThinkingSubtitle => 'thinking';

  @override
  String get modelSpecFormDialectCustom => '自定义 JSON';

  @override
  String get modelSpecFormDialectCustomSubtitle => '按级别写入 JSON 补丁';

  @override
  String get modelSpecFormLevels => '支持的级别';

  @override
  String get modelSpecFormCanDisable => '允许关闭';

  @override
  String get modelSpecFormDefaultLevel => '默认级别';

  @override
  String get modelSpecFormBudgets => 'Token 预算';

  @override
  String modelSpecFormBudgetPlaceholder(String tokens) {
    return '$tokens';
  }

  @override
  String modelSpecFormCustomPatch(String level) {
    return 'JSON 补丁（$level）';
  }

  @override
  String get modelSpecFormCustomPatchHint => '例如 reasoning_effort: high';

  @override
  String get modelSpecFormInvalidJson => '自定义推理补丁必须是有效的 JSON 对象';

  @override
  String get modelSpecFormInvalidNumber => '请输入有效数字';

  @override
  String get modelSpecFormStrategySection => '策略';

  @override
  String get modelSpecFormSampling => '采样';

  @override
  String get modelSpecFormRequestQuirks => '请求兼容';

  @override
  String get modelSpecFormDynamicWebSearch => '动态过滤搜索工具';

  @override
  String get modelSpecFormDynamicWebSearchSubtitle =>
      '开启动态过滤时，使用 2026-03-18 版网页搜索与抓取工具';

  @override
  String get modelSpecFormRemoteImageUrls => '远程图片链接';

  @override
  String get modelSpecFormRemoteImageUrlsSubtitle =>
      '直接发送 http(s) 图片链接；关闭后丢弃远程链接，只发送本地图片';

  @override
  String get modelSpecFormPromptCacheControl => '提示缓存标记';

  @override
  String get modelSpecFormPromptCacheControlSubtitle =>
      '开启提示缓存时，在 OpenRouter 请求中加入 cache_control';

  @override
  String get modelSpecFormSamplingAlways => '始终保留';

  @override
  String get modelSpecFormSamplingAlwaysSubtitle => '保留 temperature 等采样字段';

  @override
  String get modelSpecFormSamplingOnlyWhenReasoningOff => '仅在关闭推理时';

  @override
  String get modelSpecFormSamplingOnlyWhenReasoningOffSubtitle => '模型思考时移除采样字段';

  @override
  String get modelSpecFormSamplingNever => '从不';

  @override
  String get modelSpecFormSamplingNeverSubtitle => '始终移除采样字段';

  @override
  String get modelSpecFormReplay => '推理回放';

  @override
  String get modelSpecFormReplayNone => '无';

  @override
  String get modelSpecFormReplayNoneSubtitle => '不把先前推理发回模型';

  @override
  String get modelSpecFormReplayToolTurns => '工具轮次';

  @override
  String get modelSpecFormReplayToolTurnsSubtitle => '仅在工具调用轮次回放推理';

  @override
  String get modelSpecFormReplayAll => '全部';

  @override
  String get modelSpecFormReplayAllSubtitle => '每一轮后续请求都回放推理';

  @override
  String get modelSpecFormReplayField => '回放字段';

  @override
  String get modelSpecFormReplayFieldReasoningContent => 'reasoning_content';

  @override
  String get modelSpecFormReplayFieldReasoning => 'reasoning';

  @override
  String get modelSpecFormReplayFieldReasoningDetails => 'reasoning_details';

  @override
  String get modelSpecFormLimitsSection => '限额';

  @override
  String get modelSpecFormLimitsPricingSection => '限额与定价';

  @override
  String get modelSpecFormContextWindow => '上下文窗口';

  @override
  String get modelSpecFormMaxOutput => '最大输出';

  @override
  String get modelSpecFormPricingSection => '定价 / 1M';

  @override
  String get modelSpecFormPricingInput => '输入';

  @override
  String get modelSpecFormPricingOutput => '输出';

  @override
  String get modelSpecFormPricingCacheRead => '缓存读取';

  @override
  String get modelSpecFormPricingCacheWrite => '缓存写入';

  @override
  String get modelSpecFormCurrency => '货币';

  @override
  String get modelSpecFormAdvancedSection => '请求';

  @override
  String get modelSelectSheetSearchHint => '搜索模型或服务商';

  @override
  String get modelSelectSheetFavoritesSection => '收藏';

  @override
  String get modelSelectSheetFollowAssistant => '跟随助手';

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
  String get providerDetailPagePromptCacheKeyTitle => '发送会话缓存键';

  @override
  String get providerDetailPagePromptCacheKeyHelp =>
      '为 OpenAI 兼容请求附加稳定的会话级 prompt_cache_key。仅在供应商支持时开启，自定义 Body 优先，不保证缓存命中。';

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
  String get modelCatalogTitle => '模型目录';

  @override
  String modelCatalogSourceBundled(String date) {
    return '内置快照 · $date';
  }

  @override
  String modelCatalogSourceRemote(String date) {
    return 'models.dev · 更新于 $date';
  }

  @override
  String get modelCatalogAutoUpdate => '每 24 小时自动更新';

  @override
  String get modelCatalogRefresh => '立即更新';

  @override
  String get modelCatalogUpdated => '模型目录已更新';

  @override
  String modelCatalogRefreshFailed(String error) {
    return '更新失败：$error';
  }

  @override
  String modelCatalogProviderCount(int count) {
    return '$count 个供应商';
  }

  @override
  String modelCatalogModelCount(int count) {
    return '$count 个模型';
  }

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
  String get searchServicesPageWebFetchSection => '网页抓取';

  @override
  String get searchServicesPageWebFetchModeTitle => '抓取方式';

  @override
  String get searchServicesPageWebFetchFollow => '跟随搜索服务';

  @override
  String searchServicesPageWebFetchFollowValue(String name) {
    return '跟随搜索 · $name';
  }

  @override
  String searchServicesPageWebFetchFollowSubtitle(String name) {
    return '当前：$name';
  }

  @override
  String get searchServicesPageWebFetchLocal => '本地抓取';

  @override
  String get searchServicesPageWebFetchLocalSubtitle => '免费，由本机直接请求网页';

  @override
  String get searchServicesPageWebFetchProviderSubtitle =>
      '使用该服务商的 API Key 和额度';

  @override
  String get searchServicesPageWebFetchOff => '关闭';

  @override
  String get searchServicesPageWebFetchOffSubtitle => '联网时只搜索，不读取网页';

  @override
  String get searchServicesPageWebFetchFooter =>
      '开启联网搜索后，模型还可以读取网页全文。搜索服务不支持抓取时会改用本地抓取，本地抓取无法处理需要 JavaScript 渲染或有反爬限制的页面。';

  @override
  String get searchServicesPageWebFetchSupported => '支持网页抓取';

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
  String get searchServicesDialogApiKeyOptional => 'API Key（可选）';

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
  String get searchServiceEditorTestModeSearch => '搜索';

  @override
  String get searchServiceEditorTestModeFetch => '抓取';

  @override
  String get searchServiceEditorTestUrlHint => '输入测试网址';

  @override
  String get searchServiceEditorTestFetchRun => '运行抓取测试';

  @override
  String get searchServiceEditorTestFetchRunning => '抓取中…';

  @override
  String searchServiceEditorTestFetchFailed(String message) {
    return '抓取失败：$message';
  }

  @override
  String searchServiceEditorTestFetchStats(String characters, String seconds) {
    return '$characters 字符 · $seconds 秒';
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
  String get searchSettingsSheetClaudeDynamicSearchTitle => '动态过滤';

  @override
  String get searchSettingsSheetClaudeDynamicSearchDescription =>
      '筛选搜索结果，节省 token';

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
  String get aboutPageQQGroupThree => 'Kelivo 三群';

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
  String get displaySettingsPageShowTotalTokensTitle => '显示整轮累计 Token';

  @override
  String get displaySettingsPageShowTotalTokensSubtitle =>
      '累计显示本次回复中所有 API 请求的用量。关闭时仅显示最后一次请求；统计页面始终包含所有请求。';

  @override
  String get displaySettingsPageShowTokenStatsSubtitle => '显示 token 用量与消息数量';

  @override
  String get displaySettingsPageShowThinkingCardsTitle => '显示思考卡片';

  @override
  String get displaySettingsPageShowThinkingCardsSubtitle =>
      '关闭后，聊天中不再显示思考过程卡片';

  @override
  String get displaySettingsPageShowToolCardsTitle => '显示工具卡片';

  @override
  String get displaySettingsPageShowToolCardsSubtitle => '关闭后，聊天中不再显示工具调用卡片';

  @override
  String get displaySettingsShowReasoningLevelBadge => '在推理按钮上显示档位';

  @override
  String get displaySettingsShowReasoningLevelBadgeSubtitle =>
      '在输入栏的推理图标旁显示当前档位';

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
  String get displaySettingsPageHideToolResultImagesTitle => '隐藏工具结果中的图片';

  @override
  String get displaySettingsPageRegenerateDeleteTrailingMessagesTitle =>
      '重新生成时删除下面的消息';

  @override
  String get displaySettingsPageShowRegenerateConfirmDialogTitle => '重新生成前弹出确认';

  @override
  String get displaySettingsPageForkKeepMessageVersionsTitle => '创建分支时保留消息版本';

  @override
  String get displaySettingsPageEditAssistantKeepThinkingToolCardsTitle =>
      '编辑助手时保留思考与工具卡片';

  @override
  String get displaySettingsPageEditAssistantKeepThinkingToolCardsSubtitle =>
      '关闭后，当前编辑版本只保留助手正文；切回上一版本仍可查看思考与工具卡片';

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
  String get displaySettingsPageAutoScrollEnableTitle => '自动跟随底部';

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
  String get linuxHideTitleBarTitle => '隐藏系统标题栏';

  @override
  String get linuxHideTitleBarDescription => '同时隐藏窗口按钮。请通过窗口管理器移动、调整大小和关闭窗口。';

  @override
  String get linuxHideTitleBarError => '无法更改标题栏，请重试。';

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
  String get themeAdvancedSettingsPageTitle => '主题高级设置';

  @override
  String get themeAdvancedSettingsPageUseLayeredSurfacesTitle => '新版分层配色（实验）';

  @override
  String get themeAdvancedSettingsPageUseLayeredSurfacesSubtitle =>
      '页面更深、卡片更亮，两者都保留主题色相；关闭可恢复旧外观';

  @override
  String get themeAdvancedSettingsPageUseLayeredSheetTilesTitle => '弹窗内瓦片分层';

  @override
  String get themeAdvancedSettingsPageUseLayeredSheetTilesSubtitle =>
      '默认瓦片与弹窗同色';

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
  String get asrServicesGroqSubtitle => 'Whisper 分段云端转写';

  @override
  String get asrServicesMistralSubtitle => 'Voxtral 分段云端转写';

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
  String get searchProviderExaMcpDescription =>
      '通过 MCP 使用 Exa 搜索。不填 API Key 可在免费限额内使用。';

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
  String get searchProviderDeepSeekDescription =>
      'DeepSeek 官方网页搜索与抓取 API，使用 DeepSeek API Key。';

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
  String get searchServiceNameExaMcp => 'Exa MCP';

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
  String get searchServiceNameDeepSeek => 'DeepSeek';

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
  String get searchServiceNameAnySearch => 'AnySearch';

  @override
  String get searchProviderAnySearchDescription =>
      '面向 AI 智能体的统一搜索服务，可在网页与专业数据源间自动路由。API Key 可选。';

  @override
  String get searchServiceNameKagi => 'Kagi';

  @override
  String get searchProviderKagiDescription => 'Kagi 搜索 API，提供 Kagi 的高级网页搜索结果。';

  @override
  String get searchServiceNameKimi => 'Kimi';

  @override
  String get searchProviderKimiDescription =>
      'Kimi 搜索 API。Pro 返回相关网页正文片段，Basic 返回标题、链接和摘要。';

  @override
  String get searchServiceNameParallel => 'Parallel';

  @override
  String get searchProviderParallelDescription =>
      'Parallel 搜索 API。返回面向 LLM 优化的网页摘录，支持 turbo、fast、basic 和 advanced 模式。';

  @override
  String get searchServicesDialogSearchMode => '搜索模式';

  @override
  String get searchServiceNameYou => 'You.com';

  @override
  String get searchProviderYouDescription =>
      'You.com 搜索 API。返回网页与新闻结果，支持 Highlights 或 Snippets。';

  @override
  String get searchServicesDialogContentMode => '内容模式';

  @override
  String get searchServicesDialogHighlights => 'Highlights';

  @override
  String get searchServicesDialogSnippets => 'Snippets';

  @override
  String get searchServicesDialogWebSearch => 'Web Search';

  @override
  String get searchServicesDialogLlmContext => 'LLM Context';

  @override
  String get searchServicesDialogMaximumTokens => '最大 token 数';

  @override
  String get searchServicesDialogMaximumTokensInvalid =>
      '最大 token 数必须介于 1024 和 32768 之间。';

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
  String get assistantEditLocalToolLocationTitle => '当前位置';

  @override
  String get assistantEditLocalToolLocationSubtitle => '读取本设备的一次性位置，需要授予定位权限。';

  @override
  String get assistantEditLocalToolWeatherTitle => '天气';

  @override
  String get assistantEditLocalToolWeatherSubtitle =>
      '获取当前位置或指定地点的 Apple 天气，结果中会展示 WeatherKit 数据来源。';

  @override
  String get assistantEditLocalToolHealthTitle => '健康摘要';

  @override
  String get assistantEditLocalToolHealthSubtitle =>
      '读取本设备的健康活动摘要，需要授予健康数据读取权限。';

  @override
  String assistantEditLocalToolHealthSelectedCount(int selected, int total) {
    return '已选择 $selected/$total 项';
  }

  @override
  String get healthDataSettingsTitle => '健康数据';

  @override
  String get healthDataSettingsDescription =>
      '当前助手在日常对话中可使用的 HealthKit 信号。开关表示 Kelivo 可以尝试读取该范围，实际授权仍由 iOS 管理。';

  @override
  String healthDataSettingsBadge(int selected, int total) {
    return '$selected/$total 开启';
  }

  @override
  String get healthDataSettingsIosReadTitle => 'iOS 健康读取';

  @override
  String get healthDataSettingsIosReadSubtitle => '设备可用，读取范围由 iOS 管理';

  @override
  String get healthDataSettingsOpenSystemSettings => '打开系统设置';

  @override
  String get healthDataSettingsEnableAll => '全部开启';

  @override
  String get healthDataSettingsDisableAll => '全部关闭';

  @override
  String get healthDataSettingsCategoryActivity => '活动';

  @override
  String get healthDataSettingsCategoryRest => '休息';

  @override
  String get healthDataSettingsCategoryHeart => '心率';

  @override
  String get healthDataSettingsCategoryBody => '身体';

  @override
  String get healthDataSettingsTypeStepsTitle => '步数';

  @override
  String get healthDataSettingsTypeStepsSubtitle => '行走步数摘要';

  @override
  String get healthDataSettingsTypeDaylightTitle => '日照';

  @override
  String get healthDataSettingsTypeDaylightSubtitle => '户外日光时间';

  @override
  String get healthDataSettingsTypeActiveEnergyTitle => '能量';

  @override
  String get healthDataSettingsTypeActiveEnergySubtitle => '活动能量消耗';

  @override
  String get healthDataSettingsTypeExerciseMinutesTitle => '锻炼';

  @override
  String get healthDataSettingsTypeExerciseMinutesSubtitle => 'Apple 锻炼分钟数';

  @override
  String get healthDataSettingsTypeStandTimeTitle => '站立';

  @override
  String get healthDataSettingsTypeStandTimeSubtitle => '站立时间';

  @override
  String get healthDataSettingsTypeDistanceTitle => '距离';

  @override
  String get healthDataSettingsTypeDistanceSubtitle => '步行和跑步距离';

  @override
  String get healthDataSettingsTypeWorkoutsTitle => '健身训练';

  @override
  String get healthDataSettingsTypeWorkoutsSubtitle => '训练记录：类型、时长、距离与消耗';

  @override
  String get healthDataSettingsTypeSleepTitle => '睡眠';

  @override
  String get healthDataSettingsTypeSleepSubtitle => '最近 24 小时的睡眠、卧床、清醒与睡眠分期';

  @override
  String get healthDataSettingsTypeMindfulnessTitle => '静息';

  @override
  String get healthDataSettingsTypeMindfulnessSubtitle => '正念或静息时段';

  @override
  String get healthDataSettingsTypeHeartRateTitle => '心率';

  @override
  String get healthDataSettingsTypeHeartRateSubtitle => '最近心率样本';

  @override
  String get healthDataSettingsTypeRestingHeartRateTitle => '静息心率';

  @override
  String get healthDataSettingsTypeRestingHeartRateSubtitle => '静息状态心率';

  @override
  String get healthDataSettingsTypeBloodOxygenTitle => '血氧';

  @override
  String get healthDataSettingsTypeBloodOxygenSubtitle => '血氧饱和度';

  @override
  String get healthDataSettingsTypeDietaryEnergyTitle => '摄入能量';

  @override
  String get healthDataSettingsTypeDietaryEnergySubtitle => '饮食热量记录';

  @override
  String get healthDataSettingsTypeWaterTitle => '饮水';

  @override
  String get healthDataSettingsTypeWaterSubtitle => '饮水量记录';

  @override
  String get healthDataSettingsTypeWeightTitle => '体重';

  @override
  String get healthDataSettingsTypeWeightSubtitle => '体重样本';

  @override
  String get healthDataSettingsTypeBmiTitle => 'BMI';

  @override
  String get healthDataSettingsTypeBmiSubtitle => '身体质量指数';

  @override
  String get healthDataSettingsTypeBloodGlucoseTitle => '血糖';

  @override
  String get healthDataSettingsTypeBloodGlucoseSubtitle => '血糖样本';

  @override
  String get assistantEditLocalToolRemindersQueryTitle => '查询提醒';

  @override
  String get assistantEditLocalToolRemindersQuerySubtitle =>
      '读取本设备上的提醒事项，需要授予提醒事项完整访问权限。';

  @override
  String get assistantEditLocalToolRemindersCreateTitle => '创建提醒';

  @override
  String get assistantEditLocalToolRemindersCreateSubtitle =>
      '在你确认后于本设备创建提醒事项，需要授予提醒事项完整访问权限。';

  @override
  String get assistantEditLocalToolRemindersCompleteTitle => '完成提醒';

  @override
  String get assistantEditLocalToolRemindersCompleteSubtitle =>
      '在你确认后将提醒事项标记为完成，需要授予提醒事项完整访问权限。';

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
  String get settingsPageAutoRetry => '自动重试';

  @override
  String get autoRetryEnableLabel => '开启自动重试';

  @override
  String get autoRetryMaxRetries => '最大重试次数';

  @override
  String get autoRetryInitialDelay => '首次延迟（毫秒）';

  @override
  String get autoRetryMultiplier => '退避倍率';

  @override
  String get autoRetryMaxDelay => '最大延迟（毫秒）';

  @override
  String get autoRetryJitter => '抖动';

  @override
  String get autoRetryJitterSubtitle => '每次等待随机 ±20%';

  @override
  String get autoRetryOnNetworkError => '网络错误时重试';

  @override
  String get autoRetryStatusCodes => '可重试状态码';

  @override
  String get autoRetryKeywords => '重试关键字';

  @override
  String get autoRetryStopKeywords => '停止重试关键字';

  @override
  String get autoRetryAddHint => '添加';

  @override
  String get autoRetryRestoreDefaults => '恢复默认';

  @override
  String get autoRetryFooter => '仅在当前这轮模型响应尚未产生任何输出时才会自动重试。';

  @override
  String autoRetryCountdown(int seconds, int attempt, int maxRetries) {
    return '$seconds 秒后重试 ($attempt/$maxRetries)';
  }

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
      '此限制仅适用于未选择全量注入的类型。某一类型的记忆超过该条数时，只注入最近的若干条，其余由模型用 memory_search_profile 按需查询。调大更全面但更费 token。若你改过规则提示词，请一并更新或恢复默认。';

  @override
  String get memorySettingsFullInjectionTypesTitle => '全量注入类型';

  @override
  String get memorySettingsFullInjectionTypesSubtitle =>
      '可多选。选中类型会注入全局及当前助手的全部有效记忆，不受条数限制，会增加上下文和 token 消耗。';

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
  String worldBookImportUnsupportedEntries(int count) {
    return '导入完成。$count 个条目使用了暂不支持的酒馆功能（如宏、正则、时效、筛选或插入规则），已保留内容并停用，请检查后再启用。';
  }

  @override
  String get worldBookInjectionRoleUser => '用户';

  @override
  String get worldBookInjectionRoleAssistant => '助手';

  @override
  String get mcpToolNeedsApproval => '需要审批';

  @override
  String get toolApprovalPending => '等待审批';

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
  String tokenDetailFirstToken(String value) {
    return '${value}s（首字）';
  }

  @override
  String tokenDetailTotalTokens(int count) {
    return '$count tokens';
  }

  @override
  String tokenDetailReasoningTokens(int count) {
    return '$count tokens';
  }

  @override
  String tokenDetailCacheWriteTokens(int count) {
    return '$count 缓存写入 tokens';
  }

  @override
  String tokenDetailCost(String amount) {
    return '$amount';
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
  String get migrationStartWithoutBackupButton => '不备份，直接迁移';

  @override
  String get migrationSkipChatsJsonOption => '跳过 chats.json';

  @override
  String get migrationSkipChatsJsonDescription =>
      '仍会备份原始 Hive、设置和本地文件，超大聊天记录建议选择。';

  @override
  String get migrationSkipBackupOption => '跳过本次备份';

  @override
  String get migrationSkipBackupDescription => '仅在已有并确认备份可用时选择，之后将立即开始迁移。';

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
  String get migrationFailedSubtitle =>
      '原始 Hive 数据仍然保留；如果备份已经完成，备份文件也不会被修改。查看下方原因后可以重试。';

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
  String get imageSettingsPageSendSectionTitle => '发送';

  @override
  String get imageSettingsPageMarkdownImageLinksTitle =>
      '将 Markdown 图片链接作为图片发送';

  @override
  String get imageSettingsPageMarkdownImageLinksSubtitle =>
      '开启后，消息文本中的 ![alt](url) 会作为图片发送给视觉模型；关闭后仅作为普通文本发送。手动添加的图片附件不受影响。';

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
  String get messageStyleSettingsPageAssistantFitContent => '助手气泡贴合内容';

  @override
  String get messageStyleSettingsPageAssistantFitContentSubtitle =>
      '助手气泡按文字宽度收缩，不再占满整行';

  @override
  String get messageStyleSettingsPageAssistantSplitParagraphs => '分段显示为多个气泡';

  @override
  String get messageStyleSettingsPageAssistantSplitParagraphsSubtitle =>
      '助手回复遇到空行时拆分，每段单独一个气泡';

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

  @override
  String get localSnapshotSectionTitle => '本地副本';

  @override
  String get localSnapshotEnabledTitle => '保留本地副本';

  @override
  String get localSnapshotEnabledSubtitle => 'Kelivo 会定期在本机存一份数据库副本，让数据不只有一份。';

  @override
  String get localSnapshotIntervalTitle => '备份频率';

  @override
  String get localSnapshotIntervalAutomatic => '自动';

  @override
  String get localSnapshotIntervalAutomaticDetail => '每天一次，数据库越大间隔越长';

  @override
  String localSnapshotIntervalDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '每 $days 天',
      one: '每天',
    );
    return '$_temp0';
  }

  @override
  String get localSnapshotKeepTitle => '保留份数';

  @override
  String localSnapshotKeepValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 份',
    );
    return '$_temp0';
  }

  @override
  String get localSnapshotKeepSubtitle => '另外各留一份上周和上个月的，万一问题过了很久才发现也还能找回来。';

  @override
  String get localSnapshotKeepWeekly => '保留一份上周的';

  @override
  String get localSnapshotKeepMonthly => '保留一份上个月的';

  @override
  String get localSnapshotKeepProtectedNote => '无论设成几份，最近一份仍有内容的副本都不会被自动清理。';

  @override
  String get localSnapshotMaximumTitle => '占用上限';

  @override
  String get localSnapshotMaximumUnlimited => '不限制';

  @override
  String get localSnapshotAnnounceTitle => '备份完成时提示';

  @override
  String get localSnapshotAnnounceSubtitle => '失败一定会告诉你。这里只是成功时多一句提示。';

  @override
  String get localSnapshotTakeNow => '立即备份一份';

  @override
  String get localSnapshotManageCopies => '管理副本';

  @override
  String localSnapshotUsage(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 份',
      zero: '暂无副本',
    );
    return '$_temp0 · $size';
  }

  @override
  String get localSnapshotStatusNever => '还没有备份过';

  @override
  String localSnapshotStatusSuccess(String when) {
    return '上次备份：$when';
  }

  @override
  String localSnapshotStatusFailure(String when, String reason) {
    return '上次备份失败（$when）：$reason';
  }

  @override
  String get localSnapshotStatusSkippedSpace => '已跳过：本机剩余空间不足';

  @override
  String get localSnapshotStatusUnchanged => '距上次备份数据没有变化';

  @override
  String get localSnapshotCopiesTitle => '本地副本';

  @override
  String get localSnapshotCopiesEmpty => '还没有本地副本';

  @override
  String get localSnapshotCopiesEmptyHint => '数据有变化时会自动存一份，恢复数据前也一定会先存一份。';

  @override
  String get localSnapshotCopiesScopeNote =>
      '本地副本只存在这台设备上。它防的是应用内数据被损坏或误删，防不了设备丢失或卸载应用——那要靠 WebDAV / S3 备份。';

  @override
  String get localSnapshotOriginAutomatic => '自动备份';

  @override
  String get localSnapshotOriginManual => '手动备份';

  @override
  String get localSnapshotOriginBeforeRestore => '恢复前备份';

  @override
  String get localSnapshotKindRecovered => '故障恢复时留下的';

  @override
  String localSnapshotCopyContents(int conversations, int messages) {
    String _temp0 = intl.Intl.pluralLogic(
      conversations,
      locale: localeName,
      other: '$conversations 个对话',
    );
    String _temp1 = intl.Intl.pluralLogic(
      messages,
      locale: localeName,
      other: '$messages 条消息',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get localSnapshotCopyContentsUnknown => '内容需恢复后才能确认';

  @override
  String get localSnapshotCopyPinned => '已保留';

  @override
  String get localSnapshotActionRestore => '恢复';

  @override
  String get localSnapshotActionExport => '导出';

  @override
  String get localSnapshotActionDelete => '删除';

  @override
  String get localSnapshotActionPin => '保留这份';

  @override
  String get localSnapshotActionUnpin => '取消保留';

  @override
  String get localSnapshotRestoreTitle => '恢复这份副本？';

  @override
  String localSnapshotRestoreMessage(String when) {
    return '当前聊天和设置将替换为 $when 的副本。替换前会保存当前聊天和设置的副本。未发送的草稿不包含在副本中，此次恢复会清除这些草稿。';
  }

  @override
  String get localSnapshotRestorePreparing => '正在准备副本';

  @override
  String get localSnapshotDeleteTitle => '删除这份副本？';

  @override
  String get localSnapshotDeleteMessage =>
      '这份副本会从设备上永久删除。它里面有、而当前数据库里没有的数据将无法找回。';

  @override
  String get localSnapshotDeleteLastWarning => '这是唯一一份还有内容的副本。';

  @override
  String get localSnapshotExportPreparing => '正在准备导出';

  @override
  String get localSnapshotExportDone => '副本已导出';

  @override
  String localSnapshotExportFailed(String reason) {
    return '导出副本失败：$reason';
  }

  @override
  String get localSnapshotTakeDone => '副本已保存';

  @override
  String localSnapshotTakeFailed(String reason) {
    return '保存副本失败：$reason';
  }

  @override
  String get localSnapshotDeleteDone => '副本已删除';

  @override
  String get localSnapshotBusyMessage => '已有备份任务在进行中';

  @override
  String get localSnapshotRunInBackground => '转到后台继续';

  @override
  String get localSnapshotRunningInBackground => '正在后台备份副本';

  @override
  String startupRecoveryLocalCopiesAvailable(int count, String when) {
    return '本机还保留着 $count 份本地副本，最新一份是 $when 的。重置不会删除它们——重启后可以在 设置 › 备份 › 本地副本 里恢复。';
  }

  @override
  String startupRecoveryRecoveredCopiesDeleted(int count) {
    return '另外还有 $count 份故障恢复时留下的数据库副本，重置会把它们一并永久删除。想留住的话请先导出数据。';
  }

  @override
  String get toolSchemaSettingsPageTitle => '工具描述';

  @override
  String get toolSchemaSettingsGroupSearch => '搜索';

  @override
  String get toolSchemaSettingsGroupMemory => '记忆';

  @override
  String get toolSchemaSettingsGroupLocal => '本地工具';

  @override
  String get toolSchemaSettingsModified => '已修改';

  @override
  String get toolSchemaSettingsResetDefault => '恢复默认';

  @override
  String get toolSchemaSettingsResetAll => '全部恢复默认';

  @override
  String get toolSchemaSettingsResetAllTitle => '全部恢复默认？';

  @override
  String get toolSchemaSettingsResetAllMessage =>
      '将把所有内置工具的描述恢复为应用默认文案，自定义措辞会丢失。';

  @override
  String get toolSchemaSettingsResetAllConfirm => '恢复';

  @override
  String toolSchemaSettingsParamDescriptions(int count) {
    return '参数描述 ($count)';
  }

  @override
  String get toolSchemaSettingsMemoryLangNote =>
      '记忆工具的默认描述会随记忆提示语言在中/英之间切换。自定义描述按工具名只存一份，切换语言后不会跟着变。';

  @override
  String get toolSchemaSettingsDescriptionLabel => '描述';

  @override
  String get toolSchemaSettingsToolName => '工具名';

  @override
  String get toolSchemaEditorPageTitle => '编辑描述';

  @override
  String get toolSchemaSettingsCancel => '取消';

  @override
  String get workspaceFileNotAvailable => '文件不可用';

  @override
  String get workspaceTerminalNotAvailable => '终端不可用';

  @override
  String get workspacePreviewCopyPath => '复制路径';

  @override
  String get workspacePreviewShare => '分享';

  @override
  String get workspacePreviewOpenExternally => '用其他应用打开';

  @override
  String get workspacePreviewOpenWith => '打开方式…';

  @override
  String get workspacePreviewFileTooLarge => '文件过大，无法预览，请用其他应用打开。';

  @override
  String get workspacePreviewSource => '源码';

  @override
  String get workspacePreviewRendered => '渲染';

  @override
  String get workspacePreviewFileName => '名称';

  @override
  String get workspacePreviewFileSize => '大小';

  @override
  String get workspacePreviewFileModified => '修改时间';

  @override
  String get workspacePreviewPathCopied => '已复制路径';

  @override
  String workspacePreviewLineCount(int count) {
    return '$count 行';
  }

  @override
  String get workspaceFilesSort => '排序';

  @override
  String get workspaceFilesSortName => '名称';

  @override
  String get workspaceFilesSortModified => '修改时间';

  @override
  String get workspaceFilesSortSize => '大小';

  @override
  String get workspaceFilesSortAscending => '升序';

  @override
  String get workspaceFilesSortDescending => '降序';

  @override
  String get workspaceFilesShowHidden => '显示隐藏文件';

  @override
  String get workspaceFilesHideHidden => '隐藏隐藏文件';

  @override
  String get workspaceFilesRefresh => '刷新';

  @override
  String get workspaceFilesNewFolder => '新建文件夹';

  @override
  String get workspaceFilesNewFile => '新建文件';

  @override
  String get workspaceFilesImport => '导入';

  @override
  String get workspaceFilesExport => '导出';

  @override
  String get workspaceFilesExportFolder => '导出当前文件夹';

  @override
  String get workspaceFilesEmpty => '此文件夹为空';

  @override
  String get workspaceFilesError => '无法加载这些文件';

  @override
  String get workspaceFilesRetry => '重试';

  @override
  String get workspaceFilesPreview => '预览';

  @override
  String get workspaceFilesRename => '重命名';

  @override
  String get workspaceFilesMove => '移动';

  @override
  String get workspaceFilesDelete => '删除';

  @override
  String get workspaceFilesShare => '分享';

  @override
  String get workspaceFilesCopyPath => '复制路径';

  @override
  String get workspaceFilesExportItem => '导出';

  @override
  String get workspaceFilesNameLabel => '名称';

  @override
  String get workspaceFilesNameHint => '输入名称';

  @override
  String get workspaceFilesCreate => '创建';

  @override
  String get workspaceFilesCancel => '取消';

  @override
  String get workspaceFilesConfirm => '确认';

  @override
  String get workspaceFilesSave => '保存';

  @override
  String get workspaceFilesDeleteTitle => '删除此项？';

  @override
  String workspaceFilesDeleteMessage(String name) {
    return '删除 $name？';
  }

  @override
  String workspaceFilesDeleteFolderMessage(String name) {
    return '删除文件夹 $name 及其全部内容？';
  }

  @override
  String get workspaceFilesMoveTitle => '移动到文件夹';

  @override
  String get workspaceFilesMoveHere => '移动到此处';

  @override
  String get workspaceFilesPathCopied => '已复制路径';

  @override
  String get workspaceFilesInvalidName => '名称无效';

  @override
  String get workspaceFilesInvalidPath => '该路径超出当前文件夹';

  @override
  String workspaceFilesOperationFailed(String error) {
    return '操作失败：$error';
  }

  @override
  String get workspaceFilesActions => '操作';

  @override
  String get workspaceFilesMore => '更多';

  @override
  String get workspaceFilesJustNow => '刚刚';

  @override
  String workspaceFilesMinutesAgo(int count) {
    return '$count 分钟前';
  }

  @override
  String workspaceFilesHoursAgo(int count) {
    return '$count 小时前';
  }

  @override
  String workspaceFilesDaysAgo(int count) {
    return '$count 天前';
  }

  @override
  String get workspaceFilesPanelTitle => '对话文件';

  @override
  String get workspaceFilesTabAttachments => '附件';

  @override
  String get workspaceFilesTabOutputs => '输出';

  @override
  String get workspaceFilesTabWorkspace => '工作区';

  @override
  String get workspaceFilesNoWorkspaceBound => '尚未绑定工作区';

  @override
  String get workspaceFilesKindManaged => '托管';

  @override
  String get workspaceFilesKindLinked => '链接';

  @override
  String get workspaceFilesMissingWorkspace => '找不到工作区';

  @override
  String get workspaceFilesClose => '关闭';

  @override
  String get workspacesTitle => '工作区';

  @override
  String get workspacesCreate => '创建';

  @override
  String get workspacesCreateTitle => '新建工作区';

  @override
  String get workspacesNameLabel => '名称';

  @override
  String get workspacesNameHint => '工作区名称';

  @override
  String get workspacesLinkFolder => '链接文件夹';

  @override
  String get workspacesEmpty => '还没有工作区';

  @override
  String get workspacesEmptyCta => '创建工作区';

  @override
  String get workspacesSettings => '设置';

  @override
  String get workspacesOpenFiles => '打开文件';

  @override
  String get workspacesLastUsedNever => '从未使用';

  @override
  String workspacesLastUsed(String when) {
    return '最近使用 $when';
  }

  @override
  String get workspacesDeleteTitle => '删除此工作区？';

  @override
  String workspacesDeleteMessage(String name) {
    return '删除工作区 $name？';
  }

  @override
  String get workspacesDeleteAlsoFiles => '同时删除文件';

  @override
  String get workspacesUnlinkTitle => '取消链接此工作区？';

  @override
  String workspacesUnlinkMessage(String name) {
    return '取消链接 $name？磁盘上的文件会保留。';
  }

  @override
  String get workspacesSettingsTitle => '工作区设置';

  @override
  String get workspacesShellNeedsApproval => '运行终端命令前询问';

  @override
  String get workspacesDefaultCwd => '默认工作目录';

  @override
  String get workspacesDefaultCwdHint => '相对路径，例如 src';

  @override
  String get workspacesDefaultCwdInvalid => '请使用不含 .. 的相对路径';

  @override
  String get workspacesCreateManaged => '创建工作区';

  @override
  String get workspacesLinkExisting => '链接已有文件夹';

  @override
  String get workspacesUnlink => '取消链接';

  @override
  String get workspacesItemMore => '工作区操作';

  @override
  String get workspaceToolDenied => '已拒绝';

  @override
  String get workspaceToolTimeout => '超时';

  @override
  String get workspaceToolCancelled => '已取消';

  @override
  String get workspaceToolInterrupted => '已中断';

  @override
  String get workspaceToolEnvironmentNotReady => '沙箱环境未安装';

  @override
  String get workspaceToolInstall => '安装';

  @override
  String get workspaceToolFuzzy => '模糊';

  @override
  String get workspaceToolCreated => '已创建';

  @override
  String get workspaceToolUpdated => '已更新';

  @override
  String get workspaceToolTruncated => '已截断';

  @override
  String get workspaceToolImageTag => '图片';

  @override
  String get workspaceToolStdout => 'stdout';

  @override
  String get workspaceToolStderr => 'stderr';

  @override
  String get workspaceToolOpenFullOutput => '打开完整输出';

  @override
  String get workspaceToolChangedFiles => '变更的文件';

  @override
  String get workspaceToolCancel => '取消';

  @override
  String get workspaceToolCopyCommand => '复制命令';

  @override
  String get workspaceToolCopyOutput => '复制输出';

  @override
  String get workspaceToolCopyDiff => '复制差异';

  @override
  String get workspaceToolCopied => '已复制';

  @override
  String get workspaceToolDiffTruncated => '差异已截断';

  @override
  String get workspaceToolOpenPreview => '打开预览';

  @override
  String get workspaceToolNoOutput => '无输出';

  @override
  String get workspaceToolNotAvailable => '不可用';

  @override
  String get workspaceToolClose => '关闭';

  @override
  String get workspaceToolTitleShell => '运行命令';

  @override
  String get workspaceToolTitleReadFile => '读取文件';

  @override
  String get workspaceToolTitleViewImage => '查看图片';

  @override
  String get workspaceToolTitleWriteFile => '写入文件';

  @override
  String get workspaceToolTitleEditFile => '编辑文件';

  @override
  String get workspaceToolTitleListDir => '列出目录';

  @override
  String get workspaceToolTitleGlob => 'Glob';

  @override
  String get workspaceToolTitleGrep => 'Grep';

  @override
  String workspaceToolCount(int count) {
    return '$count';
  }

  @override
  String workspaceToolMoreFiles(int count) {
    return '+$count';
  }

  @override
  String workspaceToolDurationMs(int ms) {
    return '${ms}ms';
  }

  @override
  String workspaceToolDurationSec(String sec) {
    return '${sec}s';
  }

  @override
  String get workspaceEnvTitle => '环境';

  @override
  String workspaceEnvEngineUbuntu(String version) {
    return 'Ubuntu $version (PRoot)';
  }

  @override
  String workspaceEnvEngineAlpine(String version) {
    return 'Alpine $version (iSH)';
  }

  @override
  String get workspaceEnvEngineNative => '系统终端';

  @override
  String get workspaceEnvPhaseNotInstalled => '未安装';

  @override
  String get workspaceEnvPhaseDownloading => '下载中';

  @override
  String get workspaceEnvPhaseVerifying => '校验中';

  @override
  String get workspaceEnvPhaseExtracting => '解压中';

  @override
  String get workspaceEnvPhasePatching => '配置中';

  @override
  String get workspaceEnvPhaseReady => '就绪';

  @override
  String get workspaceEnvPhaseError => '错误';

  @override
  String get workspaceEnvPhaseNeedsRestart => '需要重启';

  @override
  String workspaceEnvMetaLine(String version, String arch) {
    return '$version · $arch';
  }

  @override
  String workspaceEnvInstalledAt(String date) {
    return '安装于 $date';
  }

  @override
  String workspaceEnvDiskUsage(String size) {
    return '占用空间 $size';
  }

  @override
  String workspaceEnvRuntimeReason(String reason) {
    return '$reason';
  }

  @override
  String get workspaceEnvInstall => '安装';

  @override
  String get workspaceEnvInstallSubtitleAndroid =>
      '可选择 Ubuntu、Alpine、Debian，也可导入本地 rootfs 镜像。';

  @override
  String get workspaceEnvInstallSubtitleIos => '已内置，无需下载';

  @override
  String get workspaceEnvCancel => '取消';

  @override
  String get workspaceEnvRetry => '重试';

  @override
  String get workspaceEnvRepair => '修复';

  @override
  String get workspaceEnvReset => '重置';

  @override
  String get workspaceEnvResetConfirmTitle => '重置环境？';

  @override
  String get workspaceEnvResetConfirmBody => '这将删除已安装的软件包和沙箱文件系统。';

  @override
  String get workspaceEnvCheckForUpdate => '检查更新';

  @override
  String get workspaceEnvUpdate => '更新';

  @override
  String workspaceEnvAvailableVersion(String version) {
    return '新版本 $version 可用';
  }

  @override
  String get workspaceEnvUpToDate => '已是最新';

  @override
  String get workspaceEnvRestartBanner => '请重启 Kelivo 以完成安装';

  @override
  String get workspaceEnvDetectingMirrors => '正在检测最快镜像…';

  @override
  String workspaceEnvApplyingMirror(String category) {
    return '正在应用 $category 镜像…';
  }

  @override
  String get workspaceEnvMirrorsSection => '镜像';

  @override
  String get workspaceEnvUseMirror => '使用镜像';

  @override
  String get workspaceEnvDetect => '测速';

  @override
  String get workspaceEnvOfficial => '官方';

  @override
  String get workspaceEnvMirrorsDisabled => '镜像设置在沙箱中执行，就绪后才能更改。';

  @override
  String workspaceEnvMirrorsDisabledReason(String reason) {
    return '镜像设置在沙箱中执行，当前不可用：$reason';
  }

  @override
  String get workspaceEnvMirrorDetectTitle => '镜像测速';

  @override
  String workspaceEnvMirrorLatency(int ms) {
    return '$ms ms';
  }

  @override
  String workspaceEnvMirrorFailed(String reason) {
    return '$reason';
  }

  @override
  String get workspaceEnvErrorUnsupportedAbi => '当前设备架构不受支持。';

  @override
  String get workspaceEnvErrorArchitectureMismatch =>
      '已安装的沙盒架构与当前应用不匹配，请重新安装沙盒后使用。原沙盒文件已保留。';

  @override
  String get workspaceEnvErrorProotMissing => '缺少 PRoot 可执行文件。';

  @override
  String get workspaceEnvErrorInsufficientDisk => '存储空间不足，无法安装沙箱。';

  @override
  String get workspaceEnvErrorInsufficientDiskHint => '请为所选镜像释放更多存储空间后重试。';

  @override
  String get workspaceEnvErrorNetwork => '下载失败，请检查网络后重试。';

  @override
  String get workspaceEnvErrorChecksumMismatch => '下载文件已损坏，请重试。';

  @override
  String get workspaceEnvErrorExtractFailed => '无法解压沙箱镜像。';

  @override
  String get workspaceEnvErrorCleanupFailed => '无法清理旧沙箱文件，请重试。';

  @override
  String get workspaceEnvCleanupIncomplete => '沙箱已就绪，但部分旧文件未能清理，仍占用存储空间。';

  @override
  String get workspaceEnvErrorResetFailed => '未能完成沙箱重置，请重试。';

  @override
  String get workspaceEnvErrorPatchFailed => '无法完成沙箱配置。';

  @override
  String get workspaceEnvErrorCancelled => '安装已取消。';

  @override
  String get workspaceEnvErrorGeneric => '安装沙箱时出错。';

  @override
  String get workspaceEnvChipInstall => '安装沙箱';

  @override
  String workspaceEnvChipInstalling(int percent) {
    return '正在安装… $percent %';
  }

  @override
  String get workspaceEnvChipInstallingIndeterminate => '正在安装…';

  @override
  String get workspaceEnvChipError => '沙箱错误';

  @override
  String get workspaceEnvChipRestart => '需要重启';

  @override
  String get workspaceEnvNativeExplanation =>
      '在桌面端，Kelivo 使用系统终端，而不是 Linux 沙箱。';

  @override
  String workspaceEnvNativeShellPath(String path) {
    return '终端：$path';
  }

  @override
  String get workspaceEnvNativeShellApproval => '请求批准模式下，Shell 工具需要批准。';

  @override
  String workspaceEnvDownloadProgress(
    String downloaded,
    String total,
    int percent,
  ) {
    return '$downloaded / $total MB ($percent%)';
  }

  @override
  String get workspaceEnvMirrorsFailed => '无法检测镜像';

  @override
  String get workspaceEnvCategoryApt => 'APT';

  @override
  String get workspaceEnvCategoryApk => 'APK';

  @override
  String get workspaceEnvCategoryPip => 'pip';

  @override
  String get workspaceEnvCategoryNpm => 'npm';

  @override
  String get skillsTitle => '技能';

  @override
  String get skillsTab => '技能';

  @override
  String get skillsSearchHint => '搜索技能';

  @override
  String get skillsEmptyTitle => '还没有技能';

  @override
  String get skillsEmptyBody =>
      '技能是包含 SKILL.md 的文件夹。可粘贴 Markdown、导入 .md/.zip，或从 GitHub 安装。';

  @override
  String get skillsEmptyFormat =>
      '---\nname: my-skill\ndescription: 这个技能做什么\n---\n\n# 说明';

  @override
  String get skillsImport => '导入';

  @override
  String get skillsImportPaste => '粘贴 Markdown';

  @override
  String get skillsImportFile => '从文件';

  @override
  String get skillsImportGitHub => '从 GitHub';

  @override
  String get skillsImportPasteLabel => 'SKILL.md';

  @override
  String get skillsImportPasteHint => '粘贴带 YAML 前置元数据的 SKILL.md';

  @override
  String get skillsImportGitHubLabel => 'GitHub 链接';

  @override
  String get skillsImportGitHubHint =>
      'github.com/owner/repo 或 github.com/owner/repo/tree/ref/path';

  @override
  String get skillsImportConfirm => '导入';

  @override
  String get skillsCancel => '取消';

  @override
  String get skillsSave => '保存';

  @override
  String skillsUsedCount(int count) {
    return '已使用 $count 次';
  }

  @override
  String get skillsEnabled => '启用';

  @override
  String get skillsBrowseFiles => '浏览文件';

  @override
  String get skillsEdit => '编辑';

  @override
  String get skillsExport => '导出';

  @override
  String get skillsDelete => '删除';

  @override
  String get skillsDeleteTitle => '删除此技能？';

  @override
  String skillsDeleteMessage(String name) {
    return '删除 $name？此操作无法撤销。';
  }

  @override
  String get skillsUseAll => '使用全部技能';

  @override
  String get skillsUseAllSubtitle => '此助手可以使用所有已启用的技能。';

  @override
  String get skillsDisabledHint => '请先在技能页启用此技能。';

  @override
  String get skillsOpenPage => '管理技能';

  @override
  String get skillsInheritAssistant => '跟随助手';

  @override
  String get skillsInheritAssistantSubtitle => '使用与此对话助手相同的技能。';

  @override
  String get skillsActiveLabel => '生效中';

  @override
  String get skillsSessionTitle => '此对话的技能';

  @override
  String get skillsEditTitle => '编辑技能';

  @override
  String get skillsDetailKindLabel => 'Skill';

  @override
  String get skillsNoEnabled => '没有已启用的技能';

  @override
  String get terminalTitle => '终端';

  @override
  String get terminalOpenInSystem => '在系统终端中打开';

  @override
  String get terminalHostDirectory => '主机目录';

  @override
  String get terminalBindWorkspaceFirst => '请先绑定工作区';

  @override
  String get terminalNotAvailable => '不可用';

  @override
  String get terminalRuntimeUnavailable => '终端环境尚未就绪';

  @override
  String get terminalRename => '重命名';

  @override
  String get terminalClose => '关闭';

  @override
  String get terminalClear => '清屏';

  @override
  String get terminalCloseSession => '关闭会话';

  @override
  String get terminalCopy => '复制';

  @override
  String get terminalPaste => '粘贴';

  @override
  String get terminalNewSession => '新建会话';

  @override
  String get terminalMore => '更多';

  @override
  String get terminalNameLabel => '名称';

  @override
  String get terminalCancel => '取消';

  @override
  String get terminalSave => '保存';

  @override
  String get workspaceDeskMenuWorkspace => '工作区';

  @override
  String get workspaceDeskMenuSkills => '技能';

  @override
  String get workspaceDeskBarTitle => '工作区';

  @override
  String get workspaceDeskBarNoWorkspace => '无工作区';

  @override
  String get workspaceDeskBarEmptyHint => '从工具栏绑定工作区后即可在此浏览文件';

  @override
  String get workspaceDeskBarToggle => '工作区文件';

  @override
  String get workspaceDeskOpenSystemTerminal => '在系统终端中打开';

  @override
  String get workspaceDeskReveal => '在文件管理器中显示';

  @override
  String get workspaceDeskBarClose => '关闭工作区栏';

  @override
  String get workspaceEntryBind => '绑定工作区';

  @override
  String get workspaceEntryUnbind => '解除绑定';

  @override
  String get workspaceEntryChange => '更换';

  @override
  String get workspaceEntrySetAssistantDefault => '设为助手默认工作区';

  @override
  String get workspaceEntryLocked => '已锁定';

  @override
  String get workspaceEntryChangeConfirmTitle => '更换工作区？';

  @override
  String get workspaceEntryUnbindConfirmTitle => '解除绑定？';

  @override
  String get workspaceEntryChangeConfirmBody =>
      '此对话已使用过工作区工具，之前消息中的文件链接可能不再可用。';

  @override
  String get workspaceEntryCwd => '工作目录';

  @override
  String get workspaceEntryCwdHint => '相对于工作区根目录';

  @override
  String get workspaceEntryCwdInvalid => '路径无效或已超出工作区';

  @override
  String get workspaceEntryCwdMissing => '该目录不存在';

  @override
  String get workspaceEntryCwdCreate => '创建它';

  @override
  String get workspaceEntryFiles => '文件';

  @override
  String get workspaceEntryTerminal => '终端';

  @override
  String get workspaceEntryOpenSystemTerminal => '在系统终端中打开';

  @override
  String get workspaceEntryReveal => '在文件管理器中显示';

  @override
  String get workspaceEntrySessionSkills => '技能';

  @override
  String get workspaceEntryEnvironment => '环境';

  @override
  String get workspaceEntryManage => '管理工作区';

  @override
  String get workspaceEntryCreate => '新建工作区…';

  @override
  String get workspaceEntryDefaultWorkspace => '默认工作区';

  @override
  String get workspaceEntryDefaultWorkspaceSubtitle => '新建对话时自动绑定，已有对话不受影响。';

  @override
  String get workspaceEntryDefaultWorkspaceUnset => '未设置';

  @override
  String get workspaceEntryDefaultWorkspaceAutomaticSubtitle =>
      '首次为对话绑定工作区时，将记为此助手的默认工作区。';

  @override
  String workspaceBindingRememberedDefault(String assistant) {
    return '已记为「$assistant」的默认工作区，新对话将自动使用。';
  }

  @override
  String workspaceBindingSuggestDefault(String assistant) {
    return '以后与「$assistant」的新对话也使用这个工作区？';
  }

  @override
  String get workspaceBindingUndoDefault => '撤销';

  @override
  String get workspaceBindingUseAsDefault => '设为默认';

  @override
  String get workspaceEntryNone => '无';

  @override
  String get workspaceEntryStartConversationFirst => '请先开始对话';

  @override
  String get workspaceEntryTooltip => '工作区';

  @override
  String get workspaceEntryPickerTitle => '选择工作区';

  @override
  String get settingsPageWorkspace => '工作区与环境';

  @override
  String get settingsPageSkills => '技能';

  @override
  String get commonClose => '关闭';

  @override
  String get terminalCopyAllOutput => '复制全部输出';

  @override
  String get terminalFontDecrease => '字号 −';

  @override
  String get terminalFontIncrease => '字号 +';

  @override
  String get terminalCloseSessionConfirmMessage => '会话仍在运行。关闭将结束该进程。';

  @override
  String get terminalCopiedAll => '已复制全部输出';

  @override
  String get terminalConfirm => '确认';

  @override
  String terminalExitCode(int code) {
    return 'exit $code';
  }

  @override
  String get workspaceMgmtNewWorkspace => '新建工作区';

  @override
  String get workspaceMgmtEmptyHint => '新建一个工作区来存放项目文件和工作目录。';

  @override
  String get workspaceMgmtKindManagedTitle => '托管工作区';

  @override
  String get workspaceMgmtKindManagedSubtitle => '应用内目录，沙盒可读写';

  @override
  String get workspaceMgmtKindLinkedTitle => '链接文件夹';

  @override
  String get workspaceMgmtKindLinkedSubtitle => '直接使用本机文件夹';

  @override
  String get workspaceMgmtImportFromFolder => '从文件夹导入';

  @override
  String get workspaceMgmtImportFromFolderSubtitle => '将文件夹复制到新的托管工作区';

  @override
  String get workspaceMgmtKindSection => '类型';

  @override
  String get workspaceMgmtCreate => '创建';

  @override
  String get workspaceMgmtShellApprovalSubtitle => '每次运行命令前询问';

  @override
  String get workspaceMgmtDefaultCwdRoot => '/';

  @override
  String get workspaceMgmtPickCwdTitle => '默认工作目录';

  @override
  String get workspaceMgmtFolderPickerUnavailable => '此设备不支持选择文件夹。';

  @override
  String get workspaceMgmtImportProgressTitle => '正在导入文件夹';

  @override
  String get workspaceMgmtImportProgressPhase => '正在复制文件…';

  @override
  String get workspaceMgmtImportFailed => '无法导入该文件夹。';

  @override
  String workspaceMgmtImportDone(String name) {
    return '已导入 $name';
  }

  @override
  String get workspaceMgmtLastUsedJustNow => '刚刚';

  @override
  String workspaceMgmtLastUsedMinutesAgo(int n) {
    return '$n 分钟前';
  }

  @override
  String workspaceMgmtLastUsedHoursAgo(int n) {
    return '$n 小时前';
  }

  @override
  String workspaceMgmtLastUsedDaysAgo(int n) {
    return '$n 天前';
  }

  @override
  String workspaceMgmtRowDetail(String kind, String when) {
    return '$kind · 上次使用 $when';
  }

  @override
  String workspaceMgmtRowDetailNever(String kind) {
    return '$kind · 从未使用';
  }

  @override
  String get workspacePreviewBack => '返回';

  @override
  String get workspacePreviewWrap => '自动换行';

  @override
  String get workspacePreviewFontDecrease => '减小字号';

  @override
  String get workspacePreviewFontIncrease => '增大字号';

  @override
  String get workspacePreviewCopy => '复制';

  @override
  String get workspacePreviewRetry => '重试';

  @override
  String get workspacePreviewLoadError => '无法加载此文件。';

  @override
  String get workspacePreviewRevealInFinder => '在 Finder 中显示';

  @override
  String get workspacePreviewOpenInSystemApp => '用系统应用打开';

  @override
  String get workspacePreviewOpenInBrowser => '在浏览器中打开';

  @override
  String get workspacePreviewTable => '表格';

  @override
  String get workspacePreviewPlainLanguage => '代码';

  @override
  String get workspacePreviewOpen => '打开';

  @override
  String get workspacePreviewRevealFailed => '无法在文件管理器中显示此文件。';

  @override
  String get workspacePreviewEmptyTable => '此表格为空。';

  @override
  String get workspaceFilesNew => '新建';

  @override
  String get workspaceFilesFoldersFirst => '文件夹优先';

  @override
  String get workspaceFilesSelectDirectory => '选择此目录';

  @override
  String get workspaceFilesEmptyHint => '用「新建」或「导入」添加文件';

  @override
  String get workspaceFilesEmptyAttachments => '还没有附件';

  @override
  String get workspaceFilesEmptyOutputs => '助手还没有产出文件';

  @override
  String get workspaceFilesMoveTo => '移动到…';

  @override
  String workspaceFilesItemCount(int count) {
    return '$count 项';
  }

  @override
  String get skillsImportTooltip => '导入技能';

  @override
  String get skillsImportPasteSubtitle => '粘贴带 frontmatter 的 SKILL.md';

  @override
  String get skillsImportFileSubtitle => '选择 .md 或 .zip 文件';

  @override
  String get skillsImportGitHubSubtitle => '从仓库导入 SKILL.md';

  @override
  String get skillsImportResolving => '正在解析仓库…';

  @override
  String get skillsImportDownloading => '正在下载…';

  @override
  String get skillsImportExtracting => '正在解压…';

  @override
  String get skillsImportInstalling => '正在安装…';

  @override
  String get skillsImportGitHubRepoLabel => '仓库地址';

  @override
  String get skillsImportGitHubUrlHint =>
      'https://github.com/owner/repo 或 owner/repo[/path]';

  @override
  String get skillsImportGitHubHelp => '支持仓库根目录或子目录下的 SKILL.md';

  @override
  String get skillsEmptyHint => '技能是带 frontmatter 的 SKILL.md，导入后助手可按需调用';

  @override
  String get skillsMoreActions => '更多';

  @override
  String get skillsSearchClear => '清除';

  @override
  String get skillsSessionEmpty => '还没有已启用的技能，请先在技能库中启用';

  @override
  String get workspaceToolRunning => '运行中';

  @override
  String workspaceToolExitCode(int code) {
    return 'exit $code';
  }

  @override
  String get workspaceToolAwaitingApproval => '等待批准';

  @override
  String get workspaceToolCompleted => '完成';

  @override
  String workspaceToolLines(int count) {
    return '$count 行';
  }

  @override
  String workspaceToolItems(int count) {
    return '$count 项';
  }

  @override
  String workspaceToolFileMatches(int count) {
    return '$count 个匹配';
  }

  @override
  String workspaceToolContentMatches(int count) {
    return '$count 处匹配';
  }

  @override
  String get workspaceToolExpand => '展开';

  @override
  String get workspaceToolSectionCommand => '命令';

  @override
  String get workspaceToolSectionPath => '路径';

  @override
  String get workspaceToolSectionPattern => '模式';

  @override
  String get workspaceToolSectionOutput => '输出';

  @override
  String get workspaceToolSectionDiff => '差异';

  @override
  String get workspaceToolSectionError => '错误';

  @override
  String get workspaceToolSavedOutput => '已保存完整输出';

  @override
  String get workspaceToolApprove => '允许';

  @override
  String get workspaceToolDeny => '拒绝';

  @override
  String get workspaceToolCopy => '复制';

  @override
  String get workspaceEnvEngineLocalShell => '本机 Shell';

  @override
  String get workspaceEnvInstallEnvironment => '安装环境';

  @override
  String get workspaceEnvInstallDescription => '安装 Linux 环境，以便在沙盒中运行工具。';

  @override
  String get workspaceEnvStatusLabel => '状态';

  @override
  String get workspaceEnvStatusInstalled => '已安装';

  @override
  String get workspaceEnvSizeLabel => '大小';

  @override
  String get workspaceEnvPathLabel => '路径';

  @override
  String get workspaceEnvInstalledAtLabel => '安装于';

  @override
  String get workspaceEnvArchLabel => '架构';

  @override
  String workspaceEnvArchVersion(String arch, String version) {
    return '$arch · $version';
  }

  @override
  String get workspaceEnvBrowseSection => '浏览';

  @override
  String get workspaceEnvBrowseFiles => '浏览文件系统';

  @override
  String get workspaceEnvBrowseFilesDetail => '查看沙盒中的完整目录';

  @override
  String get workspaceEnvDetectFastMirrors => '检测快速镜像';

  @override
  String get workspaceEnvActionsSection => '操作';

  @override
  String get workspaceEnvInfoSection => '信息';

  @override
  String get workspaceEnvInfoBody =>
      '环境是沙盒使用的 Linux 根文件系统。工作区单独存放，重置环境不会删除工作区文件。数据保存在本机已解压的 rootfs 中。';

  @override
  String get workspaceEnvRepairDetail => '重新校验并修补文件';

  @override
  String get workspaceEnvUpdateCurrent => '已是最新';

  @override
  String workspaceEnvUpdateAvailableShort(String version) {
    return '可更新到 $version';
  }

  @override
  String get workspaceEnvResetConfirmMessage =>
      '这将删除整个 Linux 环境及其中安装的软件包。工作区文件不受影响。';

  @override
  String get workspaceEnvRestartDoneBanner => '重置已完成，请重启应用以完成安装。';

  @override
  String get workspaceEnvPathCopied => '已复制路径';

  @override
  String get workspaceEnvUseMirrorSubtitle => '将所选镜像写入沙盒';

  @override
  String get workspaceEnvRegionGlobal => '全球';

  @override
  String get workspaceEnvRegionChina => '中国';

  @override
  String get workspaceEnvRegionEurope => '欧洲';

  @override
  String get workspaceEnvRegionAsia => '亚洲';

  @override
  String get workspaceEnvMirrorTimeout => '超时';

  @override
  String get workspaceEnvSpeedTest => '测速';

  @override
  String get workspaceEnvApplySuccess => '镜像已应用';

  @override
  String get workspaceEnvApplyFailed => '无法应用镜像';

  @override
  String get workspaceEnvRestoreSuccess => '已恢复官方源';

  @override
  String get workspaceEnvMirrorsTested => '已应用最快镜像';

  @override
  String get workspaceEnvRelativeJustNow => '刚刚';

  @override
  String workspaceEnvRelativeMinutesAgo(int count) {
    return '$count 分钟前';
  }

  @override
  String workspaceEnvRelativeHoursAgo(int count) {
    return '$count 小时前';
  }

  @override
  String workspaceEnvRelativeDaysAgo(int count) {
    return '$count 天前';
  }

  @override
  String workspaceEnvDownloadLine(
    String downloaded,
    String total,
    String phase,
  ) {
    return '$downloaded / $total · $phase';
  }

  @override
  String get workspaceEnvNativeUnsandboxed =>
      '命令在本机直接运行（无沙盒），除非此对话已启用完全访问，否则需要批准。';

  @override
  String get workspaceEnvRootfsTitle => '/';

  @override
  String get workspaceEnvBrowserUnavailable => '沙盒文件系统不可用。';

  @override
  String get workspaceEnvMirrorNameOfficial => '官方';

  @override
  String get workspaceEnvMirrorNameOfficialCdn => '官方 CDN';

  @override
  String get workspaceEnvMirrorNameOfficialPypi => '官方 PyPI';

  @override
  String get workspaceEnvMirrorNameOfficialNpm => '官方 npm';

  @override
  String get workspaceEnvMirrorNameTuna => '清华 TUNA';

  @override
  String get workspaceEnvMirrorNameAlibaba => '阿里云';

  @override
  String get workspaceEnvMirrorNameUstc => '中科大 USTC';

  @override
  String get workspaceEnvMirrorNameHuawei => '华为云';

  @override
  String get workspaceEnvMirrorNameTencent => '腾讯云';

  @override
  String get workspaceEnvMirrorNameNetease => '网易';

  @override
  String get workspaceEnvMirrorNameLeaseweb => 'LEASEWEB UK';

  @override
  String get workspaceEnvMirrorNameRwth => 'RWTH Germany';

  @override
  String get workspaceEnvMirrorNameJaist => 'JAIST Japan';

  @override
  String get workspaceEnvMirrorNameKakao => 'Kakao Korea';

  @override
  String get workspaceEnvMirrorNameNpmmirror => 'npmmirror';

  @override
  String workspaceEnvSelectionNamed(String name, String region) {
    return '$name · $region';
  }

  @override
  String get workspaceFilesEmptyPickerHint => '点「新建文件夹」添加子文件夹';

  @override
  String get skillsDetailBodyEmpty => '还没有技能正文';

  @override
  String skillsDetailBodyTooLarge(String size) {
    return '文件较大，暂不支持预览（$size）。';
  }

  @override
  String get workspaceEnvSizeTimeout => '计算超时';

  @override
  String get workspaceEnvInfoCopied => '已复制环境信息';

  @override
  String get workspacePreviewEmptyFile => '文件为空';

  @override
  String get workspacePreviewEmptyHint => '此文件没有任何可预览的内容。';

  @override
  String get workspacePreviewRevealInExplorer => '在文件资源管理器中显示';

  @override
  String get workspacePreviewRevealInFileManager => '在文件管理器中显示';

  @override
  String workspaceBindingSetAssistantDefault(String assistant) {
    return '已设为「$assistant」的默认工作区';
  }

  @override
  String get storageSpaceCategoryWorkspaceFiles => '工作区文件';

  @override
  String get storageSpaceCategoryWorkspaceFilesHint => '托管工作区中保存的文件。';

  @override
  String get storageSpaceCategorySandboxEnvironment => '沙箱环境';

  @override
  String get storageSpaceCategorySandboxEnvironmentHint => '沙箱安装目录与根文件系统。';

  @override
  String get storageSpaceCategorySkills => '技能';

  @override
  String get storageSpaceCategorySkillsHint => '已安装的技能文件。';

  @override
  String get storageSpaceCategorySessionFiles => '会话文件';

  @override
  String get storageSpaceCategorySessionFilesHint => '各对话的附件与输出。';

  @override
  String get storageSpaceManageSkills => '管理技能';

  @override
  String get storageSessionFilesCleanOrphans => '清理无对话的会话文件';

  @override
  String storageSessionFilesCleanOrphansHint(String size) {
    return '删除已无对应对话的会话目录。可回收 $size。';
  }

  @override
  String get workspaceDesktopFolderPath => '文件夹路径';

  @override
  String get workspaceDesktopFolderMissing => '请选择已存在的文件夹，或输入它的绝对路径。';

  @override
  String get workspaceDesktopManagedHint => '由 Kelivo 为此项目创建并管理文件夹。';

  @override
  String get workspaceDesktopHostHint => '在本机访问文件和执行命令。';

  @override
  String get workspaceDesktopSearch => '搜索工作区';

  @override
  String get workspaceDesktopNoResults => '没有匹配的工作区';

  @override
  String get workspaceEnvDependencies => '环境预设';

  @override
  String get workspaceEnvDependenciesDetail => '安装到共享沙盒，所有工作区均可使用。';

  @override
  String get workspaceEnvDependencyPython => 'Python、pip 和虚拟环境';

  @override
  String get workspaceEnvDependencyNode => 'Node.js 和 npm';

  @override
  String get workspaceEnvDependencyGit => '克隆仓库与版本管理';

  @override
  String get workspaceEnvDependencySsh => 'SSH、SCP、SFTP 与密钥生成';

  @override
  String get workspaceEnvDependencyNetwork => '网络工具';

  @override
  String get workspaceEnvDependencyArchive => '压缩工具';

  @override
  String get workspaceEnvDependencyInstalled => '已安装';

  @override
  String get workspaceEnvDependencyUnknown => '未检测';

  @override
  String get workspaceEnvDependencyChecking => '正在检测工具…';

  @override
  String get workspaceEnvDependencyInstalling => '正在安装…';

  @override
  String get workspaceEnvDependencyCheckFailed => '未能检测工具，请刷新重试。';

  @override
  String get workspaceEnvDependencyInstallFailed => '安装未完成，请查看日志或更换软件包源后重试。';

  @override
  String get workspaceEnvDependencyLog => '安装日志';

  @override
  String get workspaceEnvDependencyRefresh => '刷新工具状态';

  @override
  String get workspaceEnvDependencyReadyFirst => '请先安装沙盒环境，再安装这些工具。';

  @override
  String get workspaceEnvDependencySources => '软件包源';

  @override
  String get workspaceEnvDependencySourcesDetail =>
      '预设使用所选 apt/apk 源安装；pip 和 npm 源用于后续安装的软件包。';

  @override
  String get workspaceEnvDownloadSource => '沙盒下载源';

  @override
  String get workspaceEnvDownloadAutomatic => '自动选择最快源';

  @override
  String get workspaceEnvDownloadAutomaticDetail => '下载前检测官方源和内置镜像的速度。';

  @override
  String get workspaceEnvDownloadCustom => '自定义链接';

  @override
  String get workspaceEnvDownloadCustomHint =>
      'https://example.com/ubuntu-base/releases/24.04/release/';

  @override
  String get workspaceEnvDownloadCustomDetail =>
      '填写镜像目录或完整下载链接，镜像需匹配所选系统、版本及设备架构。';

  @override
  String get workspaceEnvDownloadInvalidUrl => '请输入有效的 HTTP 或 HTTPS 链接。';

  @override
  String get workspaceEnvDownloadVerified => '下载后会校验所选镜像的官方 SHA-256。软件包源可单独配置。';

  @override
  String get workspaceEnvDownloadStart => '下载并安装';

  @override
  String get workspaceEnvDownloadSave => '保存下载源';

  @override
  String get workspaceToolsTitle => '工具';

  @override
  String get workspaceToolsDescription => '选择此工作区的对话可以使用哪些工具，修改后自动保存。';

  @override
  String get workspaceToolHelpShell => '在工作区环境中执行命令。';

  @override
  String get workspaceToolHelpRead => '按行读取文件内容，支持分页。';

  @override
  String get workspaceToolHelpViewImage => '让模型查看工作区中的图片内容。';

  @override
  String get workspaceToolHelpWrite => '创建文件或覆盖文件内容。';

  @override
  String get workspaceToolHelpEdit => '替换已有文件中的指定文本。';

  @override
  String get workspaceToolHelpList => '浏览目录及其中的文件。';

  @override
  String get workspaceToolHelpGlob => '按文件名或路径模式查找文件。';

  @override
  String get workspaceToolHelpGrep => '搜索文件中的文本内容。';

  @override
  String get workspaceEnvVariablesTitle => '环境变量';

  @override
  String get workspaceEnvVariablesEntryDetail => '管理命令使用的变量与输出隐私';

  @override
  String get workspaceEnvVariablesEmpty => '还没有环境变量。可以添加工具需要的 API 密钥等配置。';

  @override
  String get workspaceEnvVariablesScope =>
      '所有工作区共用。修改会用于新的 Agent 命令和应用内终端会话，已有终端需重新打开。外部系统终端使用其自身的环境变量。';

  @override
  String get workspaceEnvPrivacyMode => '隐私模式';

  @override
  String get workspaceEnvPrivacyDetail =>
      '命令仍能使用真实值。工作区工具输出发给模型前，匹配到的至少 5 个字符的变量值会替换为 [REDACTED]，本地日志保留原文。较短的值不做遮蔽，以免误替换常见开关和数字。';

  @override
  String get workspaceEnvVariableAdd => '添加变量';

  @override
  String get workspaceEnvVariableEdit => '编辑变量';

  @override
  String get workspaceEnvVariableName => '名称';

  @override
  String get workspaceEnvVariableValue => '值';

  @override
  String get workspaceEnvVariableNote => '备注（可选）';

  @override
  String get workspaceEnvVariableNameHint =>
      '名称使用字母、数字和下划线，不能以数字开头，区分大小写。命令中可通过 \$NAME 使用变量。';

  @override
  String get workspaceEnvVariableInvalidName => '请输入有效的变量名称。';

  @override
  String get workspaceEnvVariableInvalidValue => '值不能为空，也不能包含空字符（NUL）。';

  @override
  String get workspaceEnvVariableDuplicate => '已存在同名变量。';

  @override
  String get workspaceEnvVariablesSaveFailed => '环境设置保存失败，请重试。';

  @override
  String get incomingShareTitle => '接收分享';

  @override
  String get incomingShareReplaceDraft => '输入框中有尚未发送的内容。是否替换为分享的内容，并开始新对话？';

  @override
  String get incomingShareFailed =>
      '部分分享内容未能导入，请检查文件访问权限和可用存储空间。一次最多分享 32 个文件。';

  @override
  String get incomingShareImporting => '正在导入';

  @override
  String get incomingShareMoveTo => '移动到…';

  @override
  String get incomingShareNewChat => '新对话';

  @override
  String get incomingShareMoveHint => '将草稿和附件移到其他对话，内容不会自动发送。';

  @override
  String get incomingShareNoConversations => '没有匹配的对话';

  @override
  String get chatInputBarRemoveAttachment => '移除附件';

  @override
  String get incomingShareMoveFailed => '无法切换对话，草稿已保留。';

  @override
  String attachmentRequiresWorkspace(String name) {
    return '「$name」无法在普通对话中直接读取。请绑定工作区并启用文件工具，或将草稿移到已有工作区的对话。';
  }

  @override
  String get storageSessionFilesUnlinked => '未关联的会话';

  @override
  String get workspaceExternalMount => '挂载外部文件夹';

  @override
  String get workspaceExternalMountSubtitle =>
      '所选文件夹挂载到 /mounts/<name>，供各工作区的 AI 工具、Shell 和文件浏览器访问。最多挂载 10 个文件夹。';

  @override
  String get workspaceExternalStorageTitle => '允许访问文件';

  @override
  String get workspaceExternalStorageMessage =>
      '工作区和 Shell 需要直接读写外部文件夹，请在 Android 系统设置中允许 Kelivo 访问文件。Android 11 及以上需开启“所有文件访问权限”，然后选择要挂载的本地文件夹。';

  @override
  String get workspaceExternalGrantAccess => '前往授权';

  @override
  String get workspaceExternalLocalOnly =>
      'Android 仅支持挂载本地文件夹，此文件提供方没有可供 Shell 访问的本地目录。';

  @override
  String get workspaceExternalUnavailable =>
      '外部文件夹不可用。请检查存储连接和访问权限，重新选择文件夹以恢复访问。';

  @override
  String get workspaceExternalReconnect => '重新选择文件夹';

  @override
  String get workspaceMountAdd => '添加文件夹';

  @override
  String get workspaceMountEdit => '编辑挂载';

  @override
  String get workspaceMountEmpty => '尚未挂载文件夹';

  @override
  String get workspaceMountReadOnly => '只读';

  @override
  String get workspaceMountReadWrite => '读写';

  @override
  String get workspaceMountAllowWrite => '允许写入';

  @override
  String get workspaceMountPermissionsHint =>
      '关闭后，AI 文件工具和文件浏览器会拒绝修改此文件夹。Shell 会检查部分常用文件命令，但任意脚本不保证受限。保存挂载变更时会停止正在运行的命令和终端会话。';

  @override
  String get workspaceMountBrowse => '浏览文件';

  @override
  String get workspaceMountUnmount => '卸载';

  @override
  String get workspaceMountUnmountMessage => '卸载此挂载？原文件夹及其中的文件会保留。';

  @override
  String get workspaceMountInactive => '不可用，请重新选择文件夹';

  @override
  String get workspaceMountInvalidName =>
      '名称最多 64 个字符，不能包含斜杠、冒号或控制字符，也不能为 . 或 ..。';

  @override
  String get workspaceMountDuplicate => '已存在同名挂载。';

  @override
  String get workspaceMountLimit => '最多挂载 10 个文件夹，请先卸载一个挂载。';

  @override
  String get workspaceMountOverlap => '此文件夹与已有挂载相同或互相包含。请选择其他文件夹，以避免权限冲突。';

  @override
  String get workspaceMountTargetOccupied =>
      '/mounts 下的同名位置已有本地文件。请更换挂载名称，或先移走这些文件。原有文件未被删除。';

  @override
  String get workspaceEnvSystemImage => '系统镜像';

  @override
  String get workspaceEnvDistribution => '发行版';

  @override
  String get workspaceEnvSystemVersion => '版本';

  @override
  String get workspaceEnvLocalImage => '本地镜像';

  @override
  String get workspaceEnvChooseImage => '选择 rootfs 镜像文件';

  @override
  String get workspaceEnvLocalImageHint =>
      '支持根文件系统压缩包（.tar.gz、.tar.xz、.tar），不支持 ISO 或磁盘镜像。镜像需匹配设备 CPU 架构并包含 /bin/sh，解压后自动识别系统和版本。';

  @override
  String get workspaceEnvImportImage => '导入镜像';

  @override
  String get workspaceEnvInvalidImage =>
      '请选择适用于此设备的 rootfs 镜像，需包含可执行的 /bin/sh，且 CPU 架构匹配。';

  @override
  String get workspaceEnvReplaceSystem => '更换系统';

  @override
  String get workspaceEnvReplaceSystemHint =>
      '更换会替换当前环境内的软件包和文件，并停止运行中的命令与终端会话。工作区、聊天文件和外部文件夹会保留。新镜像准备失败时保留原有环境。';

  @override
  String get workspaceEnvProotOptions => 'PRoot 配置';

  @override
  String get workspaceEnvShellPath => 'Shell 路径';

  @override
  String get workspaceEnvShellAutomatic => '自动选择';

  @override
  String get workspaceEnvShellHint =>
      '留空时优先使用 /bin/bash，否则使用 /bin/sh。自定义 Shell 需填写环境内的绝对路径。';

  @override
  String get workspaceEnvProotArguments => '额外 PRoot 参数';

  @override
  String get workspaceEnvProotArgumentsHint =>
      '每行填写一个参数，无需 Shell 引号。例如将 -k 和 5.10.0 分别放在两行，或使用 --kernel-release=5.10.0。配置对之后启动的命令和终端会话生效。';

  @override
  String get workspaceEnvProotInvalid => '请填写有效的 Shell 绝对路径，并将 PRoot 参数逐行填写。';

  @override
  String get workspaceFileMissing => '文件已不存在';

  @override
  String get workspaceFilePreviewUnavailable => '无法预览';

  @override
  String get workspaceToolRelatedFiles => '相关文件';

  @override
  String get workspaceToolFilesTruncated => '仅列出部分文件。';

  @override
  String get displaySettingsPageShowProducedFilesTitle => '显示回复底部文件卡片';

  @override
  String get displaySettingsPageShowProducedFilesSubtitle =>
      '在回复底部显示工具创建或修改的文件。';

  @override
  String get defaultModelPagePerChatModelTitle => '每个对话独立模型';

  @override
  String get defaultModelPagePerChatModelSubtitle =>
      '开启后，在对话中切换模型只影响当前对话；关闭后会直接修改当前助手的模型，使用该助手的所有对话都会跟随。';

  @override
  String get googleFontsTitle => 'Google Fonts';

  @override
  String get googleFontsRefresh => '刷新字体列表';

  @override
  String get googleFontsSearchHint => '搜索字体或语言';

  @override
  String get googleFontsHint =>
      '下载常规字重字体后预览并应用，已安装字体可离线使用。目录来自 Expo Google Fonts，字体从 Google Fonts 下载。';

  @override
  String get googleFontsNoResults => '没有匹配的字体';

  @override
  String get googleFontsFailed => '无法加载、下载或应用字体，请检查网络后重试。';

  @override
  String get googleFontsDownloading => '正在下载字体…';

  @override
  String get googleFontsPreview => '字体预览：你好，世界！Hello world 0123456789';

  @override
  String get googleFontsLicense => '字体许可证';

  @override
  String get assistantEditLocationPermissionSettingsMessage =>
      '定位权限已被禁止。请在系统设置中允许定位访问，然后重新开启此工具。';

  @override
  String get healthDataSettingsCategoryReproductive => '生殖健康';

  @override
  String get healthDataSettingsTypeMenstrualFlowTitle => '经期记录';

  @override
  String get healthDataSettingsTypeMenstrualFlowSubtitle =>
      '最近 90 天记录的经量与周期开始日期';

  @override
  String get assistantEditGradientBackgroundTitle => '渐变背景';

  @override
  String get assistantEditGradientStaticTitle => '静态模式';

  @override
  String get assistantEditGradientStaticDescription => '更省电，适合长对话和持续输出。';

  @override
  String get assistantEditGradientHorizontal => '水平位置';

  @override
  String get assistantEditGradientVertical => '垂直位置';

  @override
  String get assistantEditGradientPreview => '预览';

  @override
  String get assistantEditGradientNextFrame => '换一帧';

  @override
  String get backgroundSettingsTitle => '后台任务';

  @override
  String get backgroundTaskTitle => 'Kelivo 任务';

  @override
  String get backgroundCompleted => '生成完成';

  @override
  String get backgroundFailed => '生成失败，请打开会话查看详情。';

  @override
  String get backgroundCancelled => '生成已取消';

  @override
  String get backgroundInterrupted => '后台生成已中断，请打开会话继续。';

  @override
  String get backgroundRequesting => '正在请求';

  @override
  String get backgroundGenerating => '正在生成回复';

  @override
  String get backgroundThinking => '正在思考';

  @override
  String get backgroundToolRunning => '正在执行工具';

  @override
  String get backgroundRetrying => '等待重试';

  @override
  String get backgroundWorking => '正在处理';

  @override
  String get backgroundTasks => '任务';

  @override
  String get backgroundStopTasks => '停止任务';

  @override
  String get backgroundOpenChat => '打开会话';

  @override
  String get backgroundAndroidEnabled => '后台生成';

  @override
  String get backgroundAndroidEnabledDetail =>
      '在锁屏、切到后台或划掉最近任务后继续当前生成。任务运行期间会显示系统常驻通知。';

  @override
  String get backgroundIosEnabled => '增强后台运行';

  @override
  String get backgroundIosEnabledDetail => '为当前任务申请后台执行时间。可另外开启定位或静音音频辅助保活。';

  @override
  String get backgroundNotifications => '任务通知';

  @override
  String get backgroundNotificationsDetail =>
      '在当前查看的会话之外完成或失败时通知。此开关不控制 Android 必需的常驻通知。';

  @override
  String get backgroundPrivacy => '任务状态隐私';

  @override
  String get backgroundPrivacyDetail => '在通知和实时状态中隐藏会话标题及工具详情，仅显示通用状态、任务数量和耗时。';

  @override
  String get backgroundLiveActivities => '实时活动';

  @override
  String get backgroundLiveActivitiesDetail => '在锁屏和灵动岛显示当前任务，是否可用及展示位置由系统决定。';

  @override
  String get backgroundOverlay => '任务悬浮窗';

  @override
  String get backgroundOverlayDetail => '在其他应用上显示可拖动的任务悬浮窗。点击进入会话；关闭按钮仅隐藏悬浮窗。';

  @override
  String get backgroundLiveUpdates => '实时通知 / 灵动岛';

  @override
  String get backgroundLiveUpdatesDetail =>
      '在支持的设备上使用 Android 16 实时通知。系统成功展示实时通知时优先于悬浮窗。';

  @override
  String get backgroundLocation => '定位辅助保活';

  @override
  String get backgroundLocationDetail =>
      '在后台任务期间使用低精度定位辅助运行，不保存坐标或发送给 AI 服务。需要开启增强后台运行并授权定位。';

  @override
  String get backgroundSilentAudio => '静音音频保活';

  @override
  String get backgroundSilentAudioDetail =>
      '后台任务运行时播放静音音频，并让位于录音和朗读。需要开启增强后台运行，无需麦克风权限。';

  @override
  String get backgroundSpeech => '后台朗读';

  @override
  String get backgroundSpeechDetail => '锁屏或切到后台时继续系统及网络朗读。关闭时，切到后台会暂停朗读。';

  @override
  String get backgroundFinishVisibility => '完成状态保留时间';

  @override
  String get backgroundFinishImmediately => '立即收起';

  @override
  String get backgroundFinishOneMinute => '1 分钟';

  @override
  String get backgroundFinishFiveMinutes => '5 分钟';

  @override
  String get backgroundFinishUntilForeground => '回到应用时收起';

  @override
  String get backgroundFinishVisibilityDetail =>
      '用于 Android 悬浮窗和 iOS 锁屏完成卡片。回到应用时清理完成状态，最长保留 15 分钟；取消任务立即收起。';

  @override
  String get backgroundOverlayIcon => '悬浮窗图标';

  @override
  String get backgroundIconDefault => 'Kelivo 图标';

  @override
  String get backgroundIconImage => '选择图片';

  @override
  String get backgroundIconEmoji => '选择 Emoji';

  @override
  String get backgroundPermissionsTitle => '权限与系统设置';

  @override
  String get backgroundNotificationsPermission => '通知权限';

  @override
  String get backgroundBatteryOptimization => '电池优化';

  @override
  String get backgroundBatteryOptimizationDetail => '允许不受限制地使用电池可改善后台运行。';

  @override
  String get backgroundAutostart => '自启动与后台运行';

  @override
  String get backgroundAutostartDetail =>
      '请手动检查设备的自启动和后台限制。Android 无法可靠查询这些厂商设置的授权状态。';

  @override
  String get backgroundLocationPermission => '定位权限';

  @override
  String get backgroundLocationAlways => '允许持续后台定位';

  @override
  String get backgroundLocationAlwaysDetail => '可进一步授予“始终允许”定位权限，仅在点击此入口时申请。';

  @override
  String get backgroundSystemSettings => '应用系统设置';

  @override
  String get backgroundPermissionGranted => '已允许';

  @override
  String get backgroundPermissionDenied => '未允许';

  @override
  String get backgroundPermissionLimited => '使用应用期间';

  @override
  String get backgroundPermissionUnknown => '需手动检查';

  @override
  String get backgroundPermissionNotDetermined => '尚未申请';

  @override
  String get backgroundRuntimeTitle => '当前状态';

  @override
  String get backgroundRuntimeActive => '正在运行';

  @override
  String get backgroundRuntimeIdle => '未运行';

  @override
  String get backgroundLocationActive => '后台定位';

  @override
  String get backgroundAudioActive => '静音音频';

  @override
  String get backgroundActivityActive => '实时活动';

  @override
  String get backgroundOverlayActive => '悬浮窗';

  @override
  String get backgroundLastError => '最近中断或错误';

  @override
  String get backgroundNoError => '暂无记录';

  @override
  String get backgroundUnsupported => '当前设备不支持或系统设置未允许';

  @override
  String get backgroundIosLimit =>
      '后台执行由 iOS 控制，实时活动本身不能保活。强退可能停止生成，实时状态可能要等再次打开应用后才能清理。';

  @override
  String get backgroundAndroidLimit =>
      '如任务中断，请检查通知、电池及厂商后台设置。系统强行停止或终止进程仍可能中断生成。';

  @override
  String get backgroundStale => '状态暂未更新，请打开应用查看。';

  @override
  String get backgroundIconError => '无法导入此图片，请选择其他图片。';

  @override
  String get backgroundNotificationChannels => '通知渠道';

  @override
  String get backgroundCompletionChannel => '任务完成通知渠道';

  @override
  String get backgroundOngoingChannel => '任务运行通知渠道';

  @override
  String get backgroundOverlayAppearance => '悬浮窗外观';

  @override
  String get backgroundOverlayAppearanceDetail => '调整尺寸、图标、进度环和显示内容';

  @override
  String get backgroundOverlayPreviewHint => '拖动可移动 · 点击进入会话 · 长按可收起';

  @override
  String get backgroundOverlayCard => '信息卡片';

  @override
  String get backgroundOverlayCircle => '圆形图标';

  @override
  String get backgroundOverlaySize => '尺寸与形状';

  @override
  String get backgroundOverlayWidth => '宽度';

  @override
  String get backgroundOverlayHeight => '高度';

  @override
  String get backgroundOverlayCornerRadius => '圆角';

  @override
  String get backgroundOverlayIconSize => '图标大小';

  @override
  String get backgroundOverlayProgressSize => '进度环直径';

  @override
  String get backgroundOverlayProgressStroke => '进度环粗细';

  @override
  String get backgroundOverlayContent => '显示内容';

  @override
  String get backgroundOverlayShowProgress => '显示进度环';

  @override
  String get backgroundOverlayShowTitle => '显示标题';

  @override
  String get backgroundOverlayShowSubtitle => '显示副标题';

  @override
  String get backgroundOverlayShowTime => '显示耗时';

  @override
  String get backgroundOverlayShowClose => '显示关闭按钮';

  @override
  String get backgroundOverlayShowBackground => '显示背景';

  @override
  String get backgroundOverlayShowBorder => '显示边框';

  @override
  String get backgroundOverlayReset => '恢复默认样式';

  @override
  String get mcpStdioEnvironmentRequired => '请先安装工作区运行环境，再使用移动端 STDIO。';

  @override
  String get mcpArgumentsHint => '用空格分隔参数，包含空格的内容用引号包裹；空参数写成 \'\'。';

  @override
  String get mcpArgumentsInvalid => '请检查参数中的引号是否闭合、末尾是否有未完成的转义。';

  @override
  String get mcpImportEnvironment => '从环境导入';

  @override
  String get mcpEnvironmentEmpty => '还没有环境变量，请先在环境设置中添加。';

  @override
  String get mcpEnvironmentHint => '默认继承运行环境的变量，导入后可为此服务器单独修改。';

  @override
  String get mcpImportJson => '导入 JSON';

  @override
  String get mcpImportJsonHint =>
      '粘贴 Claude Desktop 或 Cursor 的 MCP 配置，预览后添加服务器，不覆盖现有配置。';

  @override
  String get mcpImportPaste => '从剪贴板粘贴';

  @override
  String get mcpImportPreview => '预览';

  @override
  String get mcpImportConfirm => '导入';

  @override
  String get startupRecoverySnapshotTitle => '从数据库快照恢复';

  @override
  String get startupRecoverySnapshotBody =>
      '即使数据库无法打开，也可以选择本机快照恢复聊天和设置。请勿卸载 Kelivo，卸载会一并删除这些快照。';

  @override
  String get startupRecoverySnapshotEmpty => '未在本机找到数据库快照。请先导出数据，再尝试其他恢复操作。';

  @override
  String get startupRecoverySnapshotButton => '选择快照恢复';

  @override
  String startupRecoverySnapshotConfirm(String when) {
    return '将聊天和设置恢复到 $when 的快照？快照之后的更改不会包含在内。现有附件文件和快照会保留，Kelivo 将重启以完成恢复。';
  }

  @override
  String startupRecoverySnapshotFailed(String reason) {
    return '无法准备快照恢复：$reason';
  }

  @override
  String get startupRecoverySnapshotReady => '快照已准备好，请重启 Kelivo 完成恢复。';

  @override
  String get scheduledTasksTitle => '定时任务';

  @override
  String get scheduledTasksDescription => '在指定时间自动执行任务，支持新建聊天、继续追问或重新运行。';

  @override
  String get scheduledTasksEmpty => '把任务交给时间';

  @override
  String get scheduledTasksEmptyDetail => '晨间简报、每日复盘，或任何希望定期完成的事。';

  @override
  String get scheduledTasksAdd => '添加任务';

  @override
  String get scheduledTasksEdit => '编辑任务';

  @override
  String get scheduledTasksName => '任务名称';

  @override
  String get scheduledTasksNameHint => '晨间简报';

  @override
  String get scheduledTasksPrompt => '任务内容';

  @override
  String get scheduledTasksPromptHint => '希望助手为你完成什么？';

  @override
  String get scheduledTasksAssistant => '执行助手';

  @override
  String get scheduledTasksChooseAssistant => '选择助手';

  @override
  String get scheduledTasksAssistantMissing => '助手已不存在';

  @override
  String get scheduledTasksTime => '执行时间';

  @override
  String get scheduledTasksTimeHint => '24 小时制，例如 08:00';

  @override
  String get scheduledTasksRepeat => '重复';

  @override
  String get scheduledTasksEveryDay => '每天';

  @override
  String get scheduledTasksWeekdays => '工作日';

  @override
  String get scheduledTasksEnabled => '启用任务';

  @override
  String get scheduledTasksPermission => '闹钟和提醒';

  @override
  String get scheduledTasksPermissionDetail =>
      '允许设置闹钟，才能按指定时间执行。未授权时，已启用的任务会等待授权。';

  @override
  String get scheduledTasksPermissionAction => '去授权';

  @override
  String get scheduledTasksReliability =>
      '建议在电池设置中允许 Kelivo 后台运行。强行停止后需重新打开应用。错过的任务不会补跑，执行时间跟随设备时区。';

  @override
  String get scheduledTasksExecutionDetail =>
      '结果保存在对话中，完成后会发送回复预览通知，点击可打开对话。单次最多运行 10 分钟；需要用户回答或工具确认时会停止。';

  @override
  String get scheduledTasksRunNow => '立即运行';

  @override
  String get scheduledTasksHistory => '执行记录';

  @override
  String get scheduledTasksNoRuns => '尚无执行记录';

  @override
  String get scheduledTasksRunning => '正在运行';

  @override
  String get scheduledTasksCompleted => '已完成';

  @override
  String get scheduledTasksFailed => '执行失败';

  @override
  String get scheduledTasksInterrupted => '已中断';

  @override
  String get scheduledTasksPaused => '已暂停';

  @override
  String get scheduledTasksWaitingPermission => '等待授权';

  @override
  String scheduledTasksNextRun(String time) {
    return '下次：$time';
  }

  @override
  String get scheduledTasksDelete => '删除任务';

  @override
  String get scheduledTasksDeleteDetail => '删除此任务及执行记录？已经生成的对话会保留。';

  @override
  String get scheduledTasksSave => '保存';

  @override
  String get scheduledTasksCancel => '取消';

  @override
  String get scheduledTasksInvalid => '请填写名称、任务内容和助手，自定义重复需至少选择一天。';

  @override
  String get scheduledTasksLoading => '正在加载…';

  @override
  String get scheduledTasksOpenChat => '查看对话';

  @override
  String get scheduledTasksNeedsInput => '任务需要用户回答或工具确认，已停止。可打开对话继续。';

  @override
  String get scheduledTasksTimeout => '已达到执行时限。';

  @override
  String get scheduledTasksProcessTerminated => '上次执行被系统终止。';

  @override
  String get scheduledTasksOnce => '仅一次';

  @override
  String get scheduledTasksCustom => '自定义';

  @override
  String get scheduledTasksExecution => '执行任务';

  @override
  String get scheduledTasksMode => '执行方式';

  @override
  String get scheduledTasksNewChat => '新建聊天';

  @override
  String get scheduledTasksFollowUp => '继续追问';

  @override
  String get scheduledTasksRegenerate => '重新运行';

  @override
  String get scheduledTasksChat => '目标聊天';

  @override
  String get scheduledTasksChooseChat => '选择聊天';

  @override
  String get scheduledTasksMessage => '重新运行的问题';

  @override
  String get scheduledTasksChooseMessage => '选择问题';

  @override
  String get scheduledTasksAttachmentMessage => '含附件的消息';

  @override
  String get scheduledTasksModel => '模型';

  @override
  String get scheduledTasksChooseModel => '选择模型';

  @override
  String get scheduledTasksModelDefault => '跟随聊天或助手的模型';

  @override
  String get scheduledTasksSchedule => '执行时间';

  @override
  String get scheduledTasksActiveWindow => '活动时段';

  @override
  String get scheduledTasksStartDate => '开始日期';

  @override
  String get scheduledTasksEndDate => '结束日期';

  @override
  String get scheduledTasksActiveWindowDetail =>
      '仅在此日期范围内执行，包含结束当天。未设置的日期不作限制。';

  @override
  String get scheduledTasksDate => '日期';

  @override
  String get scheduledTasksDateUnrestricted => '不限';

  @override
  String get scheduledTasksClear => '清除';

  @override
  String get scheduledTasksSearch => '搜索';

  @override
  String get scheduledTasksNoTargets => '此助手下没有符合条件的内容';

  @override
  String get scheduledTasksFutureDate => '请选择未来的执行日期和时间。';

  @override
  String get scheduledTasksDateRangeInvalid => '结束日期不能早于开始日期。';

  @override
  String get scheduledTasksRegenerateDetail =>
      '使用原有上下文，为所选问题生成新的回答，保留已有回答和后续消息。';

  @override
  String get scheduledTasksSaving => '正在保存…';

  @override
  String get scheduledTasksFinished => '计划已结束';

  @override
  String get scheduledTasksModelMissing => '所选模型已不可用，请编辑任务重新选择。';

  @override
  String get scheduledTasksChatMissing => '目标聊天已不存在或已移至其他助手。';

  @override
  String get scheduledTasksMessageMissing => '所选问题已不存在，请重新选择。';

  @override
  String get scheduledTasksChatBusy => '此聊天正在生成回答，本次任务已跳过。';

  @override
  String get scheduledTasksDesktopEmpty => '暂无定时任务';

  @override
  String get scheduledTasksDesktopReliability =>
      '仅在 Kelivo 运行时执行，最小化或驻留托盘时也会继续。退出或电脑休眠期间错过的任务不会补运行，也不会自动启动应用。';

  @override
  String get scheduledTasksDesktopExecutionDetail =>
      '结果保存在对话中，可从任务的运行记录打开。单次最多运行 10 分钟；需要用户回答或工具确认时会停止。';

  @override
  String get worldBookStickyLabel => '粘滞（消息数）';

  @override
  String get worldBookStickyHint => '触发后在后续 N 条消息中保持激活，重复命中不延长。0 表示关闭。';

  @override
  String get worldBookCooldownLabel => '冷却（消息数）';

  @override
  String get worldBookCooldownHint => '触发后（或粘滞结束后）N 条消息内不再触发。0 表示关闭。';

  @override
  String get worldBookDelayLabel => '延迟（消息数）';

  @override
  String get worldBookDelayHint => '对话至少有 N 条消息时才允许触发。按单条消息计数，不是对话轮数。0 表示关闭。';

  @override
  String get worldBookDragToReorder => '拖动调整顺序';

  @override
  String worldBookEnabledCount(int enabled, int total) {
    return '已启用 $enabled/$total';
  }

  @override
  String get assistantConversationSystemPromptTitle => '独立对话系统提示';

  @override
  String get assistantConversationSystemPromptHint => '允许每个对话设置自己的系统提示词。';

  @override
  String get assistantConversationInjectionTitle => '独立对话指令注入';

  @override
  String get assistantConversationInjectionHint => '每个对话单独选择指令注入和世界书，默认不选中。';

  @override
  String get conversationSystemPromptTitle => '对话系统提示词';

  @override
  String get conversationSystemPromptHint => '仅对当前对话生效，留空时使用助手的系统提示词。';

  @override
  String get conversationSystemPromptClear => '恢复助手提示词';

  @override
  String get conversationSystemPromptPlaceholder => '为这个对话编写系统提示词…';

  @override
  String get conversationPromptScope => '仅当前对话';

  @override
  String get oauthAccountsTab => '账号登录';

  @override
  String get oauthLogin => '登录';

  @override
  String oauthLoginTo(String provider) {
    return '登录 $provider';
  }

  @override
  String get oauthConnected => '已连接';

  @override
  String get oauthNotConnected => '未连接';

  @override
  String oauthWaiting(String provider) {
    return '正在等待 $provider 授权';
  }

  @override
  String get oauthCancel => '取消授权';

  @override
  String get oauthOpenBrowser => '打开授权页面';

  @override
  String get oauthCopyCode => '复制验证码';

  @override
  String get oauthCodeHint => '在授权页面输入此验证码';

  @override
  String get oauthDeviceHint => '请先在 ChatGPT 安全设置或工作区权限中启用设备码登录。';

  @override
  String get oauthDeviceLogin => '使用设备码登录';

  @override
  String get oauthDetails => '查看账号详情';

  @override
  String get oauthConnectAnother => '再连一个';

  @override
  String get oauthRelogin => '重新登录';

  @override
  String get oauthNeedsLogin => '需重新登录';

  @override
  String oauthExpired(String provider) {
    return '$provider 登录已过期';
  }

  @override
  String get oauthLoginRestored => '已重新登录，可使用消息的重试按钮再次发送。';

  @override
  String get oauthLogout => '退出登录';

  @override
  String get oauthLogoutDescription => '清除此账号在本机保存的授权凭证';

  @override
  String get oauthRefreshing => '正在续期授权…';

  @override
  String get oauthRefreshUsage => '刷新用量';

  @override
  String get oauthUsageDetails => '用量明细';

  @override
  String get oauthUsageUnavailable => '暂时无法获取用量';

  @override
  String oauthLastUpdated(String time) {
    return '更新于 $time';
  }

  @override
  String get oauthSyncModels => '同步';

  @override
  String get oauthSyncing => '正在同步模型…';

  @override
  String get oauthModelsHint => '可用模型由账号同步。';

  @override
  String get oauthNoModels => '同步模型后即可开始对话';

  @override
  String get oauthConnection => '接入';

  @override
  String get oauthConnectionInfo => '接入信息';

  @override
  String get oauthEndpoint => '接入端点';

  @override
  String get oauthScope => '授权范围';

  @override
  String get oauthAccountId => '账号 ID';

  @override
  String get oauthTokenExpiry => '令牌有效期';

  @override
  String get oauthName => '供应商名称';

  @override
  String get oauthEnabledHint => '在模型选择器中显示这些模型';

  @override
  String get oauthNetwork => '网络代理';

  @override
  String get oauthFollowGlobal => '跟随全局设置';

  @override
  String get oauthCustomRequest => '自定义请求';

  @override
  String get oauthWeekly => '本周窗口';

  @override
  String get oauthMonthly => '本月窗口';

  @override
  String get oauthTotal => '总额度';

  @override
  String oauthHours(String count) {
    return '$count 小时窗口';
  }

  @override
  String oauthMinutes(String count) {
    return '$count 分钟窗口';
  }

  @override
  String oauthDays(String count) {
    return '$count 天窗口';
  }

  @override
  String get oauthWindow => '用量窗口';

  @override
  String oauthResetsAt(String time) {
    return '重置于 $time';
  }

  @override
  String oauthUsedValue(String value) {
    return '已用 $value';
  }

  @override
  String get oauthNetworkError => '连接失败，请检查网络后重试。';

  @override
  String get oauthInvalidResponse => '授权未完成，请重试。';

  @override
  String get oauthTimeout => '授权超时，请重试。';

  @override
  String get oauthDenied => '授权未获批准，请重试。';

  @override
  String get oauthSaving => '正在连接账号…';

  @override
  String get oauthQuotaExceeded => '该账号暂无可用额度。';

  @override
  String get oauthRateLimited => '请求过于频繁，请稍后重试。';

  @override
  String get oauthPermissionDenied => '该账号无权访问此资源。';

  @override
  String get oauthRequestFailed => '供应商未能完成请求。';

  @override
  String get oauthQuotaAvailable => '额度可用';

  @override
  String oauthSavedResets(String count) {
    return '可用额度重置次数：$count';
  }

  @override
  String get oauthPrimaryWindow => '主要窗口';

  @override
  String get oauthSecondaryWindow => '次要窗口';

  @override
  String get oauthAuthorizationCode => '授权码或回调链接';

  @override
  String get oauthAuthorizationCodeHint => '如果浏览器没有自动返回，请将最后的回调链接或授权码粘贴到这里。';

  @override
  String get oauthInvalidAuthorizationCode => '请输入本次登录的授权码或回调链接。';

  @override
  String get oauthSubmitAuthorizationCode => '完成登录';

  @override
  String get oauthExtraUsage => '额外用量';

  @override
  String get oauthPromptCachingHelp => '复用多轮对话中的上下文，可设置缓存保留时长。';

  @override
  String get scheduledTasksPreparation => '执行与通知';

  @override
  String get scheduledTasksAllowPreparation => '允许提前准备';

  @override
  String get scheduledTasksPreparationDetail =>
      '提前准备适合不依赖实时信息的文字任务，不会使用工具、附件或执行外部操作。';

  @override
  String get scheduledTasksIOSDetail =>
      '受 iOS 后台限制，Kelivo 不能在指定时间自动唤醒并运行模型。此功能会在 App 可运行时提前准备内容，由系统到点展示通知。每次仅准备下一次结果；离开 App 后不保证准备完成，后续任务需再次打开 Kelivo 才能补充。';

  @override
  String get scheduledTasksContextPolicy => '对话上下文';

  @override
  String get scheduledTasksContextLatest => '跟随最新对话';

  @override
  String get scheduledTasksContextSnapshot => '使用准备时的快照';

  @override
  String get scheduledTasksUnavailable => '无法执行时';

  @override
  String get scheduledTasksRemind => '仅发送提醒';

  @override
  String get scheduledTasksSkip => '跳过本次';

  @override
  String get scheduledTasksNotify => '结果通知';

  @override
  String get scheduledTasksShowPreview => '通知显示结果正文';

  @override
  String get scheduledTasksPreparationWindow => '最多提前';

  @override
  String get scheduledTasksPreparationAttempts => '自动准备次数上限';

  @override
  String get scheduledTasksPreparationCooldown => '准备最小间隔（分钟）';

  @override
  String get scheduledTasksPreparationBudget =>
      '所有任务合计最多同时准备一个。每小时累计尝试六次后暂停自动准备，取消的请求也计入次数；「立刻准备」不受次数上限限制。';

  @override
  String get scheduledTasksPreparing => '正在准备结果';

  @override
  String get scheduledTasksPrepared => '结果已准备';

  @override
  String get scheduledTasksPendingPreparation => '本次尚未准备';

  @override
  String get scheduledTasksNotificationRegistered => '通知已登记';

  @override
  String get scheduledTasksNotificationUnavailable => '通知未登记';

  @override
  String get scheduledTasksReminded => '已到期 · 仅提醒';

  @override
  String get scheduledTasksSkipped => '已跳过';

  @override
  String get scheduledTasksCancelled => '已取消';

  @override
  String get scheduledTasksReminderBody => '定时任务已到期，打开 Kelivo 继续。';

  @override
  String get scheduledTasksResultBody => '定时任务结果已准备好。';

  @override
  String get scheduledTasksNotificationPermission => '允许任务通知';

  @override
  String get scheduledTasksPreparationCost =>
      '提前准备会调用模型，可能产生额外费用。选择「跟随最新对话」时，到期前的新消息可能使已准备内容失效。即使结果未使用或请求被取消，仍可能计费；重新准备会再次调用模型。';

  @override
  String get scheduledTasksAllowPreparationTip =>
      '在 Kelivo 可运行时，提前生成下一次任务的结果，到期前不会显示在聊天中。仅使用文字，不使用工具、附件或自定义请求体；调用模型可能产生费用。';

  @override
  String get scheduledTasksContextPolicyTip =>
      '跟随最新对话：到期前发送新消息、编辑消息或切换消息版本后，已准备内容会失效；重新准备会占用次数，并可能增加费用。到期后，已保存的通知结果会原样补入对话。\n\n使用准备时的快照：对话变化后仍保留已准备结果，内容不会包含后续聊天。';

  @override
  String get scheduledTasksPreparationWindowTip =>
      '允许在任务到期前多久开始准备，最长 24 小时。例如第二天早上提醒，前一天中午打开 Kelivo 时就有机会准备。时间越长，准备机会越多，但内容也可能更早过时。不会改变任务时间，也不代表能在后台定时运行。「立刻准备」不受这项自动等待和准备次数上限限制。';

  @override
  String get scheduledTasksPreparationAttemptsTip =>
      '本次累计尝试达到上限后，自动准备会暂停。首次、失败、取消和手动准备都计入尝试记录；「立刻准备」不受此上限限制。尝试越多，可能产生的模型费用越多，这不是费用上限。';

  @override
  String get scheduledTasksPreparationCooldownTip =>
      '同一次任务两次开始准备之间，至少间隔多少分钟。间隔越长，重复请求越少。重试仍需 App 有运行机会，不是在后台设定一个定时器。「立刻准备」不受这项自动等待和准备次数上限限制。';

  @override
  String get scheduledTasksUnavailableTip =>
      '到期时没有可用结果、也无法运行任务，就发送提醒或跳过本次。提醒不包含模型生成的回答，且需要开启通知。如果到期时 Kelivo 正在打开运行，可直接执行任务。';

  @override
  String get scheduledTasksNotifyTip =>
      '允许发送结果通知和无法执行时的提醒。关闭后仍会执行任务、调用模型，提前准备也仍可能产生费用。还需要允许系统通知权限。';

  @override
  String get scheduledTasksShowPreviewTip =>
      '在通知中显示已生成的结果，系统设置允许时也会显示在锁屏上。关闭后只显示通用提示，完整结果仍可在聊天中查看；同时遵循全局通知隐私设置。';

  @override
  String scheduledTasksHours(int count) {
    return '$count 小时';
  }

  @override
  String scheduledTasksMinutes(int count) {
    return '$count 分钟';
  }

  @override
  String get scheduledTasksPreparationOff => '未开启准备';

  @override
  String get scheduledTasksPreparationQueued => '排队中';

  @override
  String get scheduledTasksPreparationQueuedDetail => '正在准备其他任务，随后按到期时间依次准备。';

  @override
  String get scheduledTasksPreparationIdle => '等待空闲';

  @override
  String get scheduledTasksPreparationIdleDetail => '等待当前回复完成或此任务的对话状态稳定后继续。';

  @override
  String get scheduledTasksPreparationWindowWaiting => '未到准备时间';

  @override
  String get scheduledTasksPreparationCooldownWaiting => '等待重试';

  @override
  String scheduledTasksPreparationRetryAt(String time) {
    return '下次可尝试：$time';
  }

  @override
  String get scheduledTasksPreparationLimitReached => '自动准备次数已用完';

  @override
  String scheduledTasksPreparationAttemptsUsed(int count, int limit) {
    return '本次已尝试 $count 次，自动准备上限为 $limit 次。可使用「立刻准备」继续。';
  }

  @override
  String get scheduledTasksPreparationHourlyLimit => '自动准备已达小时上限';

  @override
  String get scheduledTasksPreparationHourlyLimitDetail =>
      '已达到每小时准备次数上限，自动准备将在额度恢复后继续；仍可使用「立刻准备」。';

  @override
  String get scheduledTasksPreparationUnavailable => '暂时无法准备';

  @override
  String get scheduledTasksPreparationReadFailed =>
      '暂时无法读取任务信息，稍后会重新检查；具体原因见执行记录。';

  @override
  String get scheduledTasksPreparationResultRetained =>
      '暂时无法校验上下文，已保留准备结果，稍后会重新检查。';

  @override
  String get scheduledTasksPreparationContextChanged => '对话内容或配置已变化，原准备结果已作废。';

  @override
  String get scheduledTasksPreparationPublishing => '待写入对话';

  @override
  String get scheduledTasksPreparationPublishingDetail =>
      '等待当前回复结束后，将已保存的结果写入对话。';

  @override
  String get scheduledTasksPreparationPrompt => '准备提示词';

  @override
  String get scheduledTasksPreparationPromptTip =>
      '仅在提前准备本任务时附加的系统提示词，与任务内容分开。可以自定义语气和要求，也可以留空，不附加准备提示词。无论如何设置，提前准备都不能使用工具或获取实时信息。到期前修改会使已准备的结果失效，再次准备可能产生额外模型费用。';

  @override
  String get scheduledTasksPreparationPromptEmpty => '留空则不附加准备提示词';

  @override
  String scheduledTasksPreparationPromptVariables(
    String timeVariable,
    String offsetVariable,
  ) {
    return '可用占位符：$timeVariable 为计划发送的本地时间，$offsetVariable 为该时间的 UTC 偏移。准备时会自动替换。';
  }

  @override
  String get scheduledTasksPrepareNow => '立刻准备';

  @override
  String get scheduledTasksPrepareNowDetail =>
      '立刻准备下一次内容，到原定时间再发送。不受自动准备的等待时间和次数上限限制，会调用模型并可能产生费用；已有准备结果时直接复用。';

  @override
  String get scheduledTasksPrepareNowReady => '本次结果已经准备好，无需再次调用模型。';

  @override
  String get scheduledTasksPrepareNowStarted => '正在准备下一次内容，将在计划时间发布。';

  @override
  String get scheduledTasksPrepareNowBusy => '正在准备其他任务，请等待完成后再试。';

  @override
  String get scheduledTasksPrepareNowChatBusy => '请等待当前回复结束后，再尝试准备。';

  @override
  String get scheduledTasksPrepareNowDisabled =>
      '请先启用任务和「允许提前准备」。重新生成模式不支持提前准备。';

  @override
  String get scheduledTasksPrepareNowUnavailable => '暂时无法开始准备，请稍后再试。';

  @override
  String get scheduledTasksPrepareNowNoUpcoming =>
      '没有可提前准备的下一次任务，请检查任务时间和启用状态。';

  @override
  String get phoneControlTitle => '手机控制';

  @override
  String get phoneControlSubtitle => '通过无障碍读取屏幕并执行操作';

  @override
  String get phoneControlAccessibilityService => '无障碍服务';

  @override
  String get phoneControlOpenSettings => '前往无障碍设置';

  @override
  String get phoneControlRefresh => '刷新状态';

  @override
  String get phoneControlChecking => '正在检查服务状态…';

  @override
  String get phoneControlReady => '已启用并连接';

  @override
  String get phoneControlDisabled => '未启用';

  @override
  String get phoneControlDisconnected => '已启用，但尚未连接。请在系统设置中关闭再开启服务，然后刷新状态。';

  @override
  String get phoneControlStatusUnavailable => '无法读取服务状态，请刷新后重试。';

  @override
  String get phoneControlSettingsUnavailable =>
      '无法打开设置，请手动进入 Android 系统设置 → 无障碍。';

  @override
  String get phoneControlUsageTitle => '使用说明';

  @override
  String get phoneControlDisclosure =>
      '在对话中发起手机控制任务后，助手可以读取当前屏幕、点击、输入、滑动、导航和打开应用。屏幕内容会发送给当前对话配置的模型服务商，并保存在对话的工具结果中。密码字段会隐藏，服务不会持续记录屏幕内容。你可以随时关闭助手的此项工具，或在系统设置中停用服务。';

  @override
  String get phoneControlAssistantTitle => '还需开启助手工具';

  @override
  String get phoneControlAssistantHint =>
      '需要同时完成两项设置：在系统无障碍设置中启用“Kelivo 手机控制”，并在要使用的助手 → 本地工具中开启“手机控制”（也可从对话工具菜单开启）。每个助手单独配置，执行任务时请保持手机解锁。';

  @override
  String get phoneControlRestrictedTitle => '无法开启无障碍？';

  @override
  String get phoneControlRestrictedHint =>
      '部分下载的 APK 需要先在应用信息右上角菜单中选择“允许受限制的设置”。点击打开 Kelivo 应用信息，完成后再返回无障碍设置。';

  @override
  String get phoneControlEnableAssistant => '允许此助手使用手机控制';

  @override
  String get composerDraftLabel => '草稿';

  @override
  String get composerDraftRecovered => '已恢复一条尚未发送的内容。';

  @override
  String get composerDraftRestore => '继续编辑';

  @override
  String get composerDraftDiscard => '丢弃';

  @override
  String get composerDraftSaveFailed => '最新草稿保存失败，内容仍保留在当前窗口。';

  @override
  String get composerDraftRetry => '重试保存';

  @override
  String get composerDraftConflictTitle => '这个对话已有草稿';

  @override
  String get composerDraftConflictBody => '追加会保留两边的文字和附件；替换会丢弃原来的草稿。内容不会自动发送。';

  @override
  String get composerDraftAppend => '追加';

  @override
  String get composerDraftReplace => '替换草稿';

  @override
  String get composerDraftMissingFile => '有附件无法读取，请移除或重新选择该文件。';

  @override
  String get composerDraftMessageMissing => '正在编辑的原消息已不存在。请复制内容到新消息，或取消本次编辑。';

  @override
  String get composerDraftDeleteNotice => '这些对话中未发送的草稿也会一起删除。';

  @override
  String get mcpOAuthSettings => 'OAuth 设置';

  @override
  String get mcpOAuthAutomatic => '自动';

  @override
  String get mcpOAuthMetadataUrl => '客户端元数据文档 URL';

  @override
  String get mcpOAuthClientAuthentication => '客户端认证方式';

  @override
  String get mcpOAuthPublicClient => '公共客户端';

  @override
  String get mcpOAuthRedirectUri => '本地回调 URL（可选）';

  @override
  String get mcpOAuthFillRedirectExample => '填入示例';

  @override
  String get mcpOAuthRedirectHint =>
      '留空使用平台默认回调。若服务仅允许 localhost 回调，可填写 HTTP 回环地址。端口 0 自动选择可用端口；预注册客户端可能要求固定端口。';

  @override
  String get mcpOAuthClientIdRequired => '请输入客户端 ID，或选择自动注册。';

  @override
  String get mcpOAuthMetadataUrlInvalid => '请输入包含路径的 HTTPS 元数据文档 URL。';

  @override
  String get mcpOAuthSecretRequired => '此客户端认证方式需要 Client secret。';

  @override
  String get mcpOAuthRedirectInvalid =>
      '请使用 localhost、127.0.0.1 或 [::1] 的 HTTP 回调地址，不要包含凭据、查询参数或片段。';

  @override
  String get mcpOAuthDiscovering => '正在发现授权服务器…';

  @override
  String get mcpOAuthRegistering => '正在准备授权…';

  @override
  String get mcpOAuthWaitingBrowser => '等待浏览器授权…';

  @override
  String get mcpOAuthExchangingToken => '正在完成登录…';

  @override
  String get markdownPlaygroundTitle => 'Markdown Playground';

  @override
  String get markdownPlaygroundSource => 'Markdown 源码';

  @override
  String get markdownPlaygroundPreview => '渲染预览';

  @override
  String get markdownPlaygroundAst => 'AST 语法树';

  @override
  String get markdownPlaygroundPlay => '逐字输入';

  @override
  String get markdownPlaygroundPause => '暂停';

  @override
  String get markdownPlaygroundResume => '继续';

  @override
  String get markdownPlaygroundShowAll => '显示全文';

  @override
  String get markdownPlaygroundWidth => '预览宽度';

  @override
  String get markdownPlaygroundTheme => '预览主题';

  @override
  String get markdownPlaygroundPlain => '选区纯文本';

  @override
  String get markdownPlaygroundMarkdown => '选区 Markdown';

  @override
  String get markdownPlaygroundSelectionHint => '在预览中选择文本，查看复制结果。';

  @override
  String get markdownPlaygroundEmpty => '输入 Markdown 开始预览。';

  @override
  String markdownPlaygroundProgress(int shown, int total) {
    return '已输入 $shown / $total';
  }

  @override
  String get markdownCopyMarkdownAction => '复制为 Markdown';

  @override
  String get markdownCopyCsvAction => '复制 CSV';

  @override
  String get markdownCopyImageAction => '复制图片';

  @override
  String get markdownCodeLabel => '代码';

  @override
  String get markdownDetailsLabel => '详情';

  @override
  String markdownMoreRows(int count) {
    return '再显示 $count 行';
  }

  @override
  String get markdownNoteLabel => '备注';

  @override
  String get markdownTipLabel => '提示';

  @override
  String get markdownImportantLabel => '重要';

  @override
  String get markdownWarningLabel => '警告';

  @override
  String get markdownCautionLabel => '注意';

  @override
  String get markdownDangerLabel => '危险';

  @override
  String get markdownCopyRichTextAction => '复制富文本';

  @override
  String get markdownCopySelectionFailed => '复制所选内容失败。';

  @override
  String get recoveryMissingDataTitle => '检测到已有数据';

  @override
  String get recoveryMissingDataBody =>
      '当前数据库缺失，但设备上仍有旧数据。Kelivo 已暂停启动，没有新建空数据库，并保留现有文件和副本。';

  @override
  String get recoveryEmptyDataTitle => '当前聊天记录为空';

  @override
  String get recoveryEmptyDataBody =>
      '当前数据库没有对话，但发现了历史副本。Kelivo 已暂停启动，你可以恢复副本，也可以明确选择保留当前数据。应用不会自动覆盖数据。';

  @override
  String get recoveryKeepCurrent => '保留当前数据并继续';

  @override
  String get recoveryKeepCurrentConfirm => '继续使用当前空数据库？历史副本仍会保留，可以稍后恢复。';

  @override
  String get recoverySearchingCopies => '正在查找并校验本机数据副本…';

  @override
  String recoveryFoundCopies(int count) {
    return '找到 $count 份通过校验的副本。可以选择恢复聊天与设置，原文件会保留。';
  }

  @override
  String recoveryInvalidCopy(String name) {
    return '$name：校验未通过，原文件已保留。';
  }

  @override
  String get recoverySearchFailed => '部分数据位置无法读取。现有文件已保留，请先导出数据副本再尝试其他恢复操作。';

  @override
  String get recoveryDiscoveredCopyBody =>
      '在原存储目录或其他位置发现的副本。原文件会保留，恢复前会进行完整校验。';

  @override
  String get recoveryStorageFailureTitle => '数据存储需要检查';

  @override
  String get recoveryStorageFailureBody =>
      'Kelivo 未能启用受保护的数据存储，已暂停启动并保留原数据。可以导出数据副本或重试，应用不会因此新建空数据库。';

  @override
  String get recoveryProtectingTitle => '正在保护聊天数据库';

  @override
  String get recoveryProtectingData =>
      '正在复制并校验数据库。图片、附件和快照留在 Documents，不会重复复制；原数据库也会保留。';

  @override
  String get recoveryStorageReadyTitle => '聊天数据库已转存至 App 内部';

  @override
  String get recoveryStorageReadyBody =>
      '存放聊天、助手和设置的数据库已转存至 App 内部。快照、图片和附件仍在系统“文件”App 可访问的 Documents 中，原数据库也已保留。若之前的聊天仍然缺失，可前往“设置 → 备份与恢复 → 本地副本”查看恢复副本。';

  @override
  String get recoveryRetainedData => '保留的原数据';

  @override
  String get recoveryNoValidCopies => '找到了数据副本，但没有副本通过校验。原文件均已保留，可以导出数据进一步排查。';

  @override
  String get recoveryStorageInsufficientSpaceBody =>
      '剩余空间不足，无法在保留原数据库的同时建立经过校验的内部副本。现有数据和快照均未改动，请腾出一些空间后重试。';

  @override
  String get migrationFreshStartTitle => '已重新开始';

  @override
  String get migrationFreshStartSubtitle => '已新建空数据库，旧数据已保留。请重启 App 后继续使用。';

  @override
  String get migrationFreshStartFailedTitle => '重新开始未完成';

  @override
  String get migrationFreshStartFailedSubtitle =>
      '旧数据已保留。请重试重新开始，或关闭并重新打开 App。';

  @override
  String get imageExportPreparing => '正在准备图片…';

  @override
  String imageExportDiagrams(int completed, int total) {
    return '正在准备图表 $completed/$total…';
  }

  @override
  String imageExportCapturing(int completed, int total) {
    return '正在截图 $completed/$total…';
  }

  @override
  String get imageExportProcessing => '正在合成图片并准备预览…';

  @override
  String get imageExportSaving => '正在保存图片…';

  @override
  String get backupEncryptionTitle => '加密备份';

  @override
  String get backupEncryptionOffHint => '未加密的备份可被直接读取。';

  @override
  String get backupEncryptionOnHint => '备份将加密保存，重启应用后需重新输入口令。';

  @override
  String get backupEncryptionPasswordHint =>
      '请妥善保存口令，遗忘后无法恢复备份。口令仅在内存中保留至退出应用。';

  @override
  String get backupEncryptionPassword => '口令';

  @override
  String get backupEncryptionConfirmPassword => '确认口令';

  @override
  String get backupEncryptionMismatch => '两次输入的口令不一致。';

  @override
  String get backupEncryptionShowPassword => '显示口令';

  @override
  String get backupEncryptionHidePassword => '隐藏口令';

  @override
  String get backupEncryptionUnlockTitle => '加密备份';

  @override
  String get backupEncryptionUnlockHint => '请输入创建这份备份时使用的口令。';

  @override
  String get backupEncryptionUnlock => '解锁';

  @override
  String get backupEncryptionFailed => '口令错误或备份已损坏，请重试或取消。';

  @override
  String get backupEncryptionInvalid => '加密备份不完整或格式无效。';

  @override
  String get backupEncryptionUnsupported => '此加密备份需要更新版本的 Kelivo。';

  @override
  String get backupProgressEncrypting => '正在加密备份';

  @override
  String get backupProgressDecrypting => '正在解密备份';

  @override
  String get mcpPageStatusFailed => '连接失败';

  @override
  String mcpPageCardToolsShort(int enabled, int total) {
    return '工具 $enabled/$total';
  }

  @override
  String mcpPageSelectServer(String name) {
    return '选择 $name';
  }

  @override
  String get mcpIconTitle => '服务器图标';

  @override
  String get mcpIconInvalid => '无法使用此图片，请选择不超过 10 MB 的有效图片。';

  @override
  String get mcpSelectServers => '选择服务器';

  @override
  String get mcpMoveToGroup => '移到分组';

  @override
  String get mcpRenameGroup => '重命名分组';

  @override
  String get mcpDeleteGroupConfirm => '组内服务器将移至「其他」，不会删除服务器。';

  @override
  String get mcpGroupNameInvalid => '请输入非空且不重复的分组名称。';

  @override
  String get mcpEnableSelected => '启用';

  @override
  String get mcpDisableSelected => '停用';

  @override
  String mcpDeleteSelectedConfirm(int count) {
    return '删除选中的 $count 个服务器？';
  }

  @override
  String get browserTitle => '浏览器';

  @override
  String get browserSearchHint => '搜索或输入网址';

  @override
  String get browserStartTitle => '下一站，去哪里？';

  @override
  String get browserStartSubtitle => '自由浏览，也可以让 Agent 帮你探索。';

  @override
  String get browserNewTab => '新建标签页';

  @override
  String get browserTabs => '标签页';

  @override
  String get browserCloseTab => '关闭标签页';

  @override
  String get browserClose => '关闭浏览器';

  @override
  String get browserBack => '后退';

  @override
  String get browserForward => '前进';

  @override
  String get browserReload => '重新加载';

  @override
  String get browserStop => '停止加载';

  @override
  String get browserMore => '更多';

  @override
  String get browserBookmarks => '书签';

  @override
  String get browserHistory => '历史记录';

  @override
  String get browserSettings => '浏览器设置';

  @override
  String get browserAddBookmark => '添加书签';

  @override
  String get browserRemoveBookmark => '移除书签';

  @override
  String get browserNoBookmarks => '收藏的网站会显示在这里。';

  @override
  String get browserNoHistory => '浏览记录会显示在这里。';

  @override
  String get browserSearchLibrary => '搜索已保存的页面';

  @override
  String get browserClearHistory => '清空历史记录';

  @override
  String get browserClearHistoryConfirm => '删除全部浏览记录？书签会保留。';

  @override
  String get browserToday => '今天';

  @override
  String get browserYesterday => '昨天';

  @override
  String get browserDelete => '删除';

  @override
  String get browserCancel => '取消';

  @override
  String get browserDone => '完成';

  @override
  String get browserFind => '在页面中查找';

  @override
  String get browserFindPreviousMatch => '上一个匹配项';

  @override
  String get browserFindNextMatch => '下一个匹配项';

  @override
  String get browserFindHint => '查找文字';

  @override
  String get browserSearchEngine => '搜索引擎';

  @override
  String get browserDesktopMode => '桌面版网站';

  @override
  String get browserDesktopModeDescription => '使用桌面版用户代理重新加载页面。';

  @override
  String get browserRestoreTabs => '恢复标签页';

  @override
  String get browserRestoreTabsDescription => '启动 Kelivo 时恢复上次的标签页。';

  @override
  String get browserSaveHistory => '保存浏览记录';

  @override
  String get browserSaveHistoryDescription => '在本地记录访问过的页面。';

  @override
  String get browserClearData => '清除网站数据';

  @override
  String get browserClearDataConfirm =>
      '清除 Cookie、网站存储和缓存，并关闭全部标签页？网站登录状态也会清除。';

  @override
  String get browserDataCleared => '已清除网站数据';

  @override
  String get browserAgentControl => 'Agent 控制';

  @override
  String get browserAgentWorking => 'AI 正在操作';

  @override
  String get browserTakeOver => '接管';

  @override
  String get browserAgentPaused => 'AI 操作已暂停';

  @override
  String get browserAllowAgent => '允许继续';

  @override
  String get browserAgentDescription =>
      '在聊天中发送任务后，AI 才会操作浏览器。允许继续只解除暂停，不会自动发送消息或启动任务。';

  @override
  String get browserOpenExternal => '在默认浏览器打开';

  @override
  String get browserCopyLink => '复制链接';

  @override
  String get browserLinkCopied => '已复制链接';

  @override
  String get browserUnsupported => '此平台暂不支持内置浏览器。';

  @override
  String get browserLoadFailed => '无法加载此页面';

  @override
  String get browserRetry => '重试';

  @override
  String get browserFavorites => '个人收藏';

  @override
  String get browserEditBookmark => '编辑书签';

  @override
  String get browserBookmarkTitle => '标题';

  @override
  String get browserBookmarkUrl => '网址';

  @override
  String get browserSave => '保存';

  @override
  String get browserDownloads => '下载';

  @override
  String get browserNoDownloads => '下载的文件会显示在这里。';

  @override
  String get browserDownloadCancel => '取消下载';

  @override
  String get browserOpenDownload => '打开文件';

  @override
  String get browserDownloadFailed => '下载失败';

  @override
  String get browserAgentEnableHint => '在聊天工具中启用浏览器工具，再在这里允许控制。';

  @override
  String get browserSessionRequired => '从一个对话中打开浏览器，即可允许 Agent 控制。';

  @override
  String get browserDownloadCancelled => '已取消';

  @override
  String get browserAgentEnabled => '允许助手使用浏览器';

  @override
  String get browserAgentEnabledDescription => '开启后，助手可以浏览并操作这个浏览器中的页面。';

  @override
  String get browserToolTitle => '浏览器控制';

  @override
  String get browserToolSubtitle => '浏览并操作浏览器中已登录的网页。请先在浏览器设置中开启 Agent 控制。';

  @override
  String get browserOpen => '打开浏览器';

  @override
  String get browserInvalidUrl => '请输入有效的 HTTP 或 HTTPS 网址。';

  @override
  String get browserClearDataUnavailable => 'Windows 浏览器引擎暂不支持清除全部网站数据。';

  @override
  String get browserSurfaceStyle => '表面样式';

  @override
  String get browserSurfaceLiquid => '液态玻璃';

  @override
  String get browserSurfaceFrosted => '磨砂';

  @override
  String get browserSurfaceSolid => '纯色';

  @override
  String get browserPageOptions => '页面选项';

  @override
  String get browserAskAi => '让 AI 处理此页';

  @override
  String get browserAskAiHint => '返回聊天，补充需求后发送。';

  @override
  String get browserAskAiCurrentPage => '浏览器当前页面';

  @override
  String get browserAskAiUnavailable => '当前会话不可用，请先从聊天中打开浏览器。';

  @override
  String get browserAskAiEditing => '请先完成或取消正在编辑的消息，再添加网页任务。';

  @override
  String get browserAskAiAssistantDisabled => '请先在此助手的工具中开启“浏览器控制”。';

  @override
  String get browserAskAiBrowserDisabled => '请先在浏览器设置中允许助手使用浏览器。';

  @override
  String browserAskAiDraft(String page) {
    return '请使用浏览器处理这个页面：\n$page\n\n我的需求：';
  }

  @override
  String get browserOpenFullPage => '完整页面打开';

  @override
  String get browserClosePanel => '关闭浏览器面板';

  @override
  String get browserSearchTabs => '搜索标签页';

  @override
  String browserTabsCount(int count) {
    return '$count 个标签页';
  }

  @override
  String get browserOpenInSidebar => '在侧栏打开';

  @override
  String get browserUserAgent => '用户代理（UA）';

  @override
  String get browserUserAgentMobile => '移动端';

  @override
  String get browserUserAgentDesktop => '桌面端';

  @override
  String get browserUserAgentCustom => '自定义';

  @override
  String get browserUserAgentHint => '输入自定义 User-Agent';

  @override
  String get browserUserAgentInvalid =>
      'UA 仅支持可打印 ASCII 字符（英文字母、数字和英文符号），最多 2048 个字符。';

  @override
  String get browserUserAgentDescription => '更改后将重新加载当前网页。';

  @override
  String browserStepsShowEarlier(int count) {
    return '更早的 $count 步';
  }

  @override
  String get browserOpenThisPage => '在浏览器中打开';

  @override
  String get browserGroupToggleSemantics => '展开或收起浏览步骤';

  @override
  String get browserStepGroupTitle => '浏览网页';

  @override
  String browserStepCount(int count) {
    return '$count 步';
  }

  @override
  String browserStepCurrent(int count) {
    return '第 $count 步';
  }

  @override
  String browserActionFailedCount(int count) {
    return '· $count 步失败';
  }

  @override
  String browserActionFailed(String action) {
    return '$action失败';
  }

  @override
  String get browserCardOpen => '打开';

  @override
  String get browserCardEnable => '去开启';

  @override
  String browserCardRunning(String action) {
    return '正在$action…';
  }

  @override
  String get browserCardLive => '实时';

  @override
  String get browserCardOpenFailed => '未能打开页面';

  @override
  String get browserCardBlankPage => '空白页';

  @override
  String browserCardTabCount(int count) {
    return '$count 个标签页';
  }

  @override
  String get browserActionOpen => '打开网页';

  @override
  String get browserActionNewTab => '新建标签页';

  @override
  String get browserActionRender => '渲染页面';

  @override
  String get browserActionExtract => '提取正文';

  @override
  String get browserActionSnapshot => '读取页面结构';

  @override
  String get browserActionClick => '点击';

  @override
  String get browserActionType => '输入文字';

  @override
  String get browserActionPress => '按键';

  @override
  String get browserActionScroll => '滚动页面';

  @override
  String get browserActionWait => '等待页面';

  @override
  String get browserActionBack => '后退';

  @override
  String get browserActionForward => '前进';

  @override
  String get browserActionReload => '刷新页面';

  @override
  String get browserActionEvaluate => '执行脚本';

  @override
  String get browserActionSwitchTab => '切换标签页';

  @override
  String get browserActionCloseTab => '关闭标签页';

  @override
  String get browserActionListTabs => '查看标签页';

  @override
  String get browserActionUnknown => '浏览器操作';

  @override
  String browserMetaChars(String count) {
    return '$count 字';
  }

  @override
  String browserMetaElements(int count) {
    return '$count 个元素';
  }

  @override
  String get browserErrAgentDisabled => '浏览器控制未开启';

  @override
  String get browserErrStaleRef => '元素已失效，需重新读取页面';

  @override
  String get browserErrNotVisible => '元素不可见或被遮挡';

  @override
  String get browserErrNotFound => '未找到元素';

  @override
  String get browserErrTimeout => '页面加载超时';

  @override
  String get browserErrHumanControl => '你正在接管浏览器';

  @override
  String get browserErrTabClosed => '标签页已关闭';

  @override
  String get browserErrGeneric => '操作失败';

  @override
  String get browserDirectionUp => '上';

  @override
  String get browserDirectionDown => '下';

  @override
  String get browserDirectionLeft => '左';

  @override
  String get browserDirectionRight => '右';

  @override
  String browserMetaTabs(int count) {
    return '$count 个';
  }

  @override
  String get browserTabsCurrentConversation => '当前对话';

  @override
  String get browserTabsAll => '全部标签';

  @override
  String get browserTabsUnassigned => '个人标签';

  @override
  String get browserTabsUnknownConversation => '其他对话';

  @override
  String get browserTabsEmptyConversation => '这里还没有标签页。打开网页，或从「全部标签」中选择已有页面。';

  @override
  String get browserTabsNoResults => '没有匹配的标签页';

  @override
  String get browserMoveToConversation => '移到当前对话';

  @override
  String get browserReopenInConversation => '在当前对话重新打开';

  @override
  String get browserTabBusy => '助手仍在操作此页面，请等待任务完成或停止任务后再移动。';

  @override
  String get browserLiveViewLimit => '浏览器资源正在使用中，请等待任务结束后重试，或关闭不需要的页面。';

  @override
  String get browserAskAiInOwnerConversation => '让所属对话的 AI 处理';

  @override
  String get displaySettingsPageShowBrowserPageCardsTitle => '显示网页卡片';

  @override
  String get browserObserverHint => 'AI 正在操作此页面，点击“接管”后可以操作网页。';

  @override
  String get genuiSurfaceTitle => '交互界面';

  @override
  String get genuiStatusStreaming => '生成中';

  @override
  String get genuiStatusInterrupted => '已中断';

  @override
  String get genuiStatusUnsaved => '尚未保存';

  @override
  String get genuiStatusUnsavedRetry => '点击重试保存';

  @override
  String get genuiReadOnlyUntilComplete => '生成完成后可操作';

  @override
  String get genuiReadOnlySnapshot => '只读快照';

  @override
  String genuiPendingNode(String id) {
    return '等待 $id';
  }

  @override
  String get genuiViewSource => '查看源码';

  @override
  String get genuiCopySource => '复制源码';

  @override
  String get genuiExpand => '展开';

  @override
  String get genuiExpandedStub => '正在展开视图中操作';

  @override
  String get genuiMore => '更多';

  @override
  String get genuiReset => '重置为默认值';

  @override
  String get genuiRepair => '修复界面';

  @override
  String get genuiInvalidTitle => '这段界面无法渲染';

  @override
  String genuiNodesFailed(int count) {
    return '$count 个节点无法显示';
  }

  @override
  String genuiErrorLine(int line) {
    return '第 $line 行';
  }

  @override
  String get genuiValueUnavailable => '无值';

  @override
  String get genuiFormulaInvalid => '这条公式无法显示';

  @override
  String get genuiNodeUnavailable => '此组件无法显示';

  @override
  String get genuiErrorHeader => '界面首行格式无效';

  @override
  String get genuiErrorVersion => '不支持此界面语言版本';

  @override
  String get genuiErrorCatalog => '不支持此组件目录';

  @override
  String get genuiErrorRoot => '根组件缺失或无效';

  @override
  String get genuiErrorSyntax => '声明格式不正确';

  @override
  String get genuiErrorDuplicateSymbol => '同一名称被重复定义';

  @override
  String get genuiErrorDuplicateProperty => '同一属性被重复定义';

  @override
  String get genuiErrorReservedName => '此名称是保留名称';

  @override
  String genuiErrorUnknownComponent(String detail) {
    return '未知组件 $detail';
  }

  @override
  String genuiErrorUnknownProperty(String detail) {
    return '未知属性 $detail';
  }

  @override
  String genuiErrorMissingProperty(String detail) {
    return '缺少必需属性 $detail';
  }

  @override
  String get genuiErrorBinding => '输入绑定不是有效的可写状态';

  @override
  String get genuiErrorReference => '组件引用无效';

  @override
  String get genuiErrorMissingReference => '被引用的内容尚未定义';

  @override
  String get genuiErrorDependency => '依赖的内容无法显示';

  @override
  String get genuiErrorCycle => '不支持循环引用';

  @override
  String get genuiErrorDuplicateParent => '同一组件不能出现在两个位置';

  @override
  String get genuiErrorUnreachableNode => '此组件未包含在根组件中';

  @override
  String get genuiErrorType => '值的类型不匹配';

  @override
  String get genuiErrorValue => '值不在支持的选项或范围内';

  @override
  String get genuiErrorSourceBudget => '界面源码超过大小上限';

  @override
  String get genuiErrorDeclarationBudget => '单条声明超过大小上限';

  @override
  String get genuiErrorDeclarationCount => '声明数量超过上限';

  @override
  String get genuiErrorComponentCount => '组件数量超过上限';

  @override
  String get genuiErrorInputCount => '输入数量超过上限';

  @override
  String get genuiErrorComponentDepth => '组件嵌套过深';

  @override
  String get genuiErrorExpressionDepth => '计算嵌套过深';

  @override
  String get genuiErrorFunction => '计算函数不受支持';

  @override
  String get genuiErrorAction => '此操作不受支持';

  @override
  String get genuiErrorNestedSample => '不支持嵌套采样';

  @override
  String get genuiErrorSample => '采样区间或数量无效';

  @override
  String get genuiErrorDataBudget => '数据超过支持的大小';

  @override
  String get genuiErrorRowKey => '每行需要唯一且非空的标识';

  @override
  String get genuiErrorDomain => '该值不在函数定义域内';

  @override
  String get genuiErrorDivisionByZero => '不能除以零';

  @override
  String get genuiErrorNonFinite => '计算结果不是有限数值';

  @override
  String get genuiErrorOperationsBudget => '计算操作量超过上限';

  @override
  String genuiMetricTrend(String value) {
    return '变化 $value';
  }

  @override
  String genuiFormErrorsLeft(int count) {
    return '还有 $count 项需要修改';
  }

  @override
  String get genuiFieldRequired => '必填';

  @override
  String genuiNumberRange(String min, String max) {
    return '范围 $min–$max';
  }

  @override
  String genuiNumberMinimum(String min) {
    return '最小值 $min';
  }

  @override
  String genuiNumberMaximum(String max) {
    return '最大值 $max';
  }

  @override
  String genuiFieldTooShort(int min) {
    return '至少 $min 个字符';
  }

  @override
  String genuiFieldTooLong(int max) {
    return '最多 $max 个字符';
  }

  @override
  String get genuiInvalidNumber => '请输入完整的有限数值';

  @override
  String get genuiChooseOption => '请选择一项';

  @override
  String get genuiFinishComposing => '请先完成输入法组字';

  @override
  String genuiActionDisabledDep(String id) {
    return '已停用：依赖的 $id 无法显示';
  }

  @override
  String get genuiActionUnavailable => '此视图暂不支持这项操作';

  @override
  String get genuiActionDisabled => '此界面已停用该操作';

  @override
  String get genuiFormUnavailable => '此表单包含无法显示的内容';

  @override
  String genuiDecrease(String label) {
    return '减少 $label';
  }

  @override
  String genuiIncrease(String label) {
    return '增加 $label';
  }

  @override
  String genuiCharacterCount(int used, int max) {
    return '$used / $max 个字符';
  }

  @override
  String get genuiBlockLimit => '每条消息最多渲染 3 个界面，其余以源码显示';

  @override
  String get genuiChartLine => '折线图';

  @override
  String get genuiChartArea => '面积图';

  @override
  String get genuiChartBar => '柱状图';

  @override
  String get genuiChartScatter => '散点图';

  @override
  String get genuiChartPie => '饼图';

  @override
  String get genuiChartDonut => '环形图';

  @override
  String get genuiChartEmpty => '所选区间没有数据';

  @override
  String get genuiChartAllHidden => '所有系列均已隐藏，可通过图例显示。';

  @override
  String genuiChartSummary(String kind, int series, int points, int missing) {
    return '$kind，$series 个系列，$points 行数据，$missing 个值缺失（未连线，未填零）。';
  }

  @override
  String genuiChartPieSummary(String kind, int count, String total) {
    return '$kind，$count 项，合计 $total。';
  }

  @override
  String get genuiChartDomainGap => '未定义';

  @override
  String genuiChartDomainSummary(int count) {
    return '$count 个采样点无定义；阴影区域不连线。';
  }

  @override
  String genuiChartShowSeries(String name) {
    return '显示 $name';
  }

  @override
  String genuiChartHideSeries(String name) {
    return '隐藏 $name';
  }

  @override
  String get genuiChartKeyboardHint => '左右方向键选择数据行，上下方向键选择系列，Esc 清除选择。';

  @override
  String get genuiChartTotal => '合计';

  @override
  String get genuiChartFieldsError => '请选择一个 X 字段和一到四个不同的 Y 字段。';

  @override
  String get genuiChartRecordsError => '图表数据必须是记录数组。';

  @override
  String get genuiChartXError => 'X 值须全为数值或全为文本；散点图必须使用数值。';

  @override
  String get genuiChartYError => 'Y 字段须存在，且只能包含数值或空值。';

  @override
  String get genuiChartPieError => '饼图数值必须非负，且总和须为大于零的有限数。';

  @override
  String genuiChartMissingValues(int count) {
    return '$count 个值缺失，未填零。';
  }

  @override
  String get genuiChartNoVisibleValues => '所选系列没有可绘制的数值。';

  @override
  String genuiChartUnit(String unit) {
    return '单位：$unit';
  }

  @override
  String get genuiSomeValuesUnavailable => '部分值无法计算';

  @override
  String get genuiViewChart => '图表';

  @override
  String get genuiViewData => '数据';

  @override
  String get genuiTableFilterHint => '筛选可见文本';

  @override
  String genuiTableRows(int count) {
    return '$count 行';
  }

  @override
  String genuiTablePageInfo(int from, int to, int total) {
    return '第 $from–$to 行，共 $total 行';
  }

  @override
  String genuiTablePerPage(int n) {
    return '$n 行/页';
  }

  @override
  String get genuiTableEmpty => '没有匹配的行';

  @override
  String get genuiSortAsc => '升序';

  @override
  String get genuiSortDesc => '降序';

  @override
  String get genuiSortNone => '未排序';

  @override
  String get genuiValueTrue => '是';

  @override
  String get genuiValueFalse => '否';

  @override
  String get genuiTablePreviousPage => '上一页';

  @override
  String get genuiTableNextPage => '下一页';

  @override
  String get genuiTableCellsError => '表格数据必须是记录数组，单元格只能是有限标量或空值。';

  @override
  String get genuiTableColumnsError => '请选择 1–8 个不同的字段，并提供表头；小数位数可为 0–10。';

  @override
  String get genuiTableRowKeyError => '每行都需要一个非空值的标量标识。';

  @override
  String get genuiViewStateFailed => '保存状态过大，无法更改视图。请缩短输入或重置界面后重试。';

  @override
  String get genuiAttachState => '附带当前界面状态';

  @override
  String get genuiChipExactText => '将随消息发送的准确文本（已冻结）';

  @override
  String get genuiChipStale => '来源已失效 · 请移除或重新附带';

  @override
  String get genuiChipRemove => '移除附带的界面';

  @override
  String get genuiReplaceTitle => '替换已附带的界面？';

  @override
  String get genuiReplaceBody => '一份草稿只能附带一个界面状态。';

  @override
  String get genuiReplaceCurrent => '当前';

  @override
  String get genuiReplaceNew => '替换为';

  @override
  String get genuiReplaceConfirm => '替换';

  @override
  String get genuiMergeTitle => '合并到当前草稿？';

  @override
  String get genuiMergeConfirm => '合并';

  @override
  String get genuiContextEmpty => '没有附带参数或结果字段。';

  @override
  String get genuiContextOmitted => '[部分字段或数据行已省略。]';

  @override
  String get genuiChipOmitted => '此前附带的界面来源已失效，本条消息未附带其状态。';

  @override
  String get genuiDraftChanged => '草稿已发生变化，请重新附带。';

  @override
  String get genuiRepairDraft => '请根据以下诊断和源码片段修复这段界面。';

  @override
  String get genuiCopySourceMarkdown => '复制源码 / Markdown';

  @override
  String get genuiTextFailed => '无法读取界面状态，请重试。';

  @override
  String get genuiCopyLimit => '文本超过 64 KiB 复制上限，请选择较小的片段。';

  @override
  String get genuiExportSnapshot => '导出只读快照';

  @override
  String get genuiExpandedSharedState => '与消息内共享同一状态';

  @override
  String get genuiExportTooLarge => '图片超过 1600 万像素，请减少所选消息或导出较小的界面。';

  @override
  String get genuiWebTitle => '网页预览';

  @override
  String get genuiWebOpen => '打开';

  @override
  String get genuiWebNotReady => '生成完成后才可打开';

  @override
  String get genuiWebInvalidMeta => '首行元信息无效，未加载';

  @override
  String get genuiWebSandboxNote => '沙盒预览 · 关闭后不保留';

  @override
  String get genuiWebUnsupported => '此平台暂不支持内嵌网页预览，可导出后在浏览器中打开';

  @override
  String get genuiWebExportHtml => '导出 HTML';

  @override
  String get genuiWebInfo => '预览说明';

  @override
  String get genuiWebCspNote => 'CSP: default-src \'none\' · 限制网络访问 · 独立页面状态';

  @override
  String get genuiWebFailed => '预览初始化或加载失败。可查看或复制源码。';

  @override
  String get genuiWebEmpty => '元信息后没有 HTML 内容';

  @override
  String get genuiWebBlockLimit => '每条消息最多渲染 3 个网页预览，其余以源码显示';

  @override
  String get genuiWebCloseFailed => '无法确认上一个预览已关闭。请重启应用后再打开。';

  @override
  String get displaySettingsShowGenUiHeader => '显示交互界面标题栏';

  @override
  String get displaySettingsShowGenUiHeaderSubtitle =>
      '关闭后更沉浸；源码与操作仍可从界面底部的更多菜单访问。';

  @override
  String get genuiClearFilter => '清除筛选';

  @override
  String get genuiClearSelection => '清除选择';

  @override
  String get chatInputBarQueuedPausedReason => '压缩未完成，不会自动发送';

  @override
  String get contextChanged => '历史已发生变化，请重新打开此操作并确认范围。';

  @override
  String get contextOperationSuperseded => '已并入后续摘要';

  @override
  String get compressIncludeAttachments => '附件文字与工具结果';

  @override
  String contextEditCharacters(int count) {
    return '$count 字';
  }

  @override
  String get compressOverSnack => '摘要过长，应用后会超出上下文上限，未应用';

  @override
  String get contextSummaryHint => '这是后续请求实际使用的摘要，保存不会改写已有回复。附件仅使用已有文字，不会额外识图。';

  @override
  String get compressAdvanced => '高级选项';

  @override
  String get compressTaskWaiting => '等待当前回复完成';

  @override
  String get contextBudgetExceeded => '预计上下文超过当前模型上限，请缩短摘要、重新压缩或选择上下文更大的模型。';

  @override
  String get contextManualSupplement => '将手工编辑的摘要作为补充';

  @override
  String get contextDetailEdited => '已人工编辑';

  @override
  String get contextSourceLabel => '摘要来源';

  @override
  String get contextImpactSourceTitle => '修改已压缩的原文？';

  @override
  String get chatInputBarQueuedCompressionFailed => '压缩失败，不会自动发送';

  @override
  String contextTokenInfo(int before, int after) {
    return '摘要输入约 $before tokens → 摘要约 $after tokens';
  }

  @override
  String get worldBookTransferFailed => '保存条目失败，请重试。';

  @override
  String contextDetailKeptCount(int count) {
    return '最近 $count 条用户消息及其回复、工具过程';
  }

  @override
  String get toolPermissionRequestApproval => '请求批准';

  @override
  String get compressNothingNew => '自上次压缩后没有新的可压缩内容';

  @override
  String get browserActionScreenshot => '截取页面';

  @override
  String get displaySettingsPageIosNativeSelectionMenuSubtitle =>
      '用于输入框和消息选区；如遇卡顿可关闭，恢复原菜单。';

  @override
  String contextUndoneSnack(String from, String to) {
    return '已撤销 · $from → $to';
  }

  @override
  String get toolApprovalByFullAccess => '已自动执行';

  @override
  String get displaySettingsPageAutoScrollSubtitle =>
      '开启后，流式输出时位于底部会自动跟随。上滑后保持阅读位置，主动回到底部后才继续跟随；关闭后不随新内容自动滚动。';

  @override
  String get toolApprovalRealTarget => '实际目标';

  @override
  String get compressTaskRetry => '重试';

  @override
  String get wsDeniedPathOutside => '目标不在授权区域内，已拒绝。';

  @override
  String contextImpactSaveConfirm(int count) {
    return '保存并撤销 $count 个节点';
  }

  @override
  String get contextRestore => '恢复';

  @override
  String compressUsageOriginal(String value) {
    return '原 $value';
  }

  @override
  String toolApprovalPendingKind(String kind) {
    return '等待审批 · $kind';
  }

  @override
  String get contextTaskApplying => '正在应用摘要';

  @override
  String get storageSpaceImagesHint => '删除会影响聊天图片和工具结果。正在使用的头像与背景会受到保护。';

  @override
  String get displaySettingsPageIosNativeSelectionMenuTitle => 'iOS 26+ 原生选择菜单';

  @override
  String get worldBookMoveEntries => '移动到…';

  @override
  String get compressReread => '重新读取已压缩的原始消息';

  @override
  String get chatInputBarQueuedPausedHold => '待发内容保持暂停，请取消排队后编辑或发送';

  @override
  String get contextSummaryTitle => '压缩摘要';

  @override
  String get contextKeepInvalid => '请输入正整数的用户消息数量。';

  @override
  String get compressTaskAbandon => '放弃';

  @override
  String get browserAgentTimedOut => '操作超时，AI 已暂停';

  @override
  String get compressCancelledSnack => '已取消压缩，当前上下文未改变';

  @override
  String get contextImpactClearTitle => '撤销较早的清除？';

  @override
  String get compressTaskWaitingApproval => '等待工具审批完成';

  @override
  String get contextTaskFailed => '压缩失败';

  @override
  String get wsDeniedSkillsReadonly => '技能目录只读。';

  @override
  String get compressTaskMerging => '正在合并摘要';

  @override
  String get toolPermissionFullAccessDesc =>
      '允许此对话直接访问本机文件、运行命令及使用已启用的联网工具，不再逐次询问。';

  @override
  String get compressStaleSnack => '聊天内容已变化，压缩结果未应用';

  @override
  String get worldBookCopyEntries => '复制到…';

  @override
  String get contextEditEmpty => '摘要不能为空。如需丢弃全部旧历史，请使用“清空上下文”。';

  @override
  String get toolApprovalDenyWithReason => '拒绝并说明原因…';

  @override
  String get toolApprovalRequestedPath => '请求路径';

  @override
  String get toolApprovalScopeOnce => '仅授权本次调用';

  @override
  String get storageSpaceImageTypeLabel => '类型';

  @override
  String get contextImpactUndoTitle => '撤销较早的压缩？';

  @override
  String get contextOriginalMessages => '查看原始消息';

  @override
  String storageSpaceDeleteImagesConfirmMessage(int count) {
    return '删除 $count 张图片？相关聊天图片、工具截图及其会话副本将无法再查看或使用。正在使用的头像与背景会保留。';
  }

  @override
  String get chatInputBarQueuedAfterCompress => '压缩完成后发送';

  @override
  String get toolPermissionFullAccessDescMobile =>
      '允许此对话在沙箱和已授权文件夹内自动执行工具，不再逐次询问。';

  @override
  String get compressTaskAdjustRetry => '调整选项后重试';

  @override
  String get contextDetailLegacy => '由旧版清除位置转换';

  @override
  String get contextDetailCurrent => '当前上下文';

  @override
  String get toolPermissionUndo => '撤销';

  @override
  String get contextDetailViewOriginals => '查看被压缩的原文';

  @override
  String get contextTaskCompleted => '压缩已完成';

  @override
  String get chatInputBarQueuedPaused => '已暂停';

  @override
  String get contextCompressMarker => '上下文已压缩';

  @override
  String contextDetailParts(int count) {
    return '自动分 $count 段';
  }

  @override
  String get contextEditPending => '已保存，当前回复结束后生效';

  @override
  String get contextTaskRetry => '重试压缩';

  @override
  String get contextUndoCompressTooltip => '撤销此次压缩';

  @override
  String get contextDividerCompressed => '压缩上下文';

  @override
  String compressSuccessSnack(String from, String to) {
    return '上下文已压缩 · $from → $to';
  }

  @override
  String get contextEffectiveHistory => '当前摘要及后续消息';

  @override
  String get compressRereadAll => '本段全部原文';

  @override
  String get contextDone => '完成';

  @override
  String get contextMore => '更多';

  @override
  String compressFailedSnack(String reason) {
    return '压缩失败：$reason';
  }

  @override
  String get branchInheritNote => '只继承此处之前有效的上下文节点';

  @override
  String get contextTaskInterrupted => '压缩已中断，输入内容已保留';

  @override
  String get storageSpaceImageTypeAll => '全部';

  @override
  String contextRangeInfo(int count, int keep) {
    return '替代 $count 条消息；原样保留最近 $keep 条用户消息及后续回复。';
  }

  @override
  String contextInputModeInfo(String mode, String source) {
    return '摘要输入：$mode · $source';
  }

  @override
  String get contextDetailKept => '原样保留';

  @override
  String worldBookEntriesCopied(int count) {
    return '已复制 $count 个条目';
  }

  @override
  String get toolPermissionSaveFailed => '保存失败，权限未更改。';

  @override
  String get compressDiscardedSnack => '已清空上下文，进行中的压缩已废弃';

  @override
  String get browserActionSelect => '选择选项';

  @override
  String get toolPermissionTitle => '权限';

  @override
  String get contextDetailNext => '下次请求';

  @override
  String get contextTaskCancel => '取消压缩';

  @override
  String get toolPermissionFullAccess => '完全访问';

  @override
  String get chatInputBarQueuedCompressionCancelled => '压缩已取消，不会自动发送';

  @override
  String get toolPermissionResetSnack => '已更换工作区 · 此对话权限已恢复为请求批准';

  @override
  String get contextImpactUndoOne => '撤销';

  @override
  String get contextDetailContinueNewChat => '在新聊天继续';

  @override
  String get contextTaskPaused => '发送已暂停，可取消排队恢复编辑';

  @override
  String get contextTaskReview => '请检查摘要后再应用';

  @override
  String compressApproxTokens(String value) {
    return '约 $value tokens';
  }

  @override
  String get storageSpaceImageInUseHint => '请先在对应设置中更换或移除头像、背景或图标，再删除。';

  @override
  String get compressRereadLastLayer => '展开最近一层压缩';

  @override
  String get contextRestoreOperation => '恢复操作';

  @override
  String get contextOriginalHistory => '重新读取本段全部原文';

  @override
  String get contextImpactEditTitle => '保存较早的摘要？';

  @override
  String get contextOpenNewChat => '打开新聊天';

  @override
  String get wsPathChanged => '审批期间目标已变化。';

  @override
  String get contextEditUnknownPreview => '用量暂不可用，保存前会重新检查。';

  @override
  String get contextTaskWait => '等待当前回复和工具执行结束';

  @override
  String compressTaskElapsed(int i, int n, int seconds) {
    return '第 $i/$n 段 · 已用 $seconds 秒';
  }

  @override
  String get wsContextChanged => '对话上下文已变化，请求失效。';

  @override
  String contextChangeImpact(int count) {
    return '此次修改还会撤销 $count 个受影响的上下文操作，原始消息保留。是否继续？';
  }

  @override
  String get contextImpactSave => '保存';

  @override
  String contextTaskProgress(int done, int total) {
    return '正在压缩 $done/$total 段';
  }

  @override
  String get contextSummaryNotSmaller => '摘要没有比输入更短，请检查后再应用。';

  @override
  String get storageSpaceImageTypeTool => '工具图片';

  @override
  String get contextPreviousHistory => '重新读取最近一层压缩原文';

  @override
  String get contextDetailRead => '实际读取';

  @override
  String get contextViewGenerated => '查看已生成摘要';

  @override
  String get contextImpactDeleteDescription =>
      '删除原文时，一并撤销相关摘要及依赖后继，避免继续发送残留内容。其他消息与独立节点保持不变。';

  @override
  String get storageSpaceImageTypeAvatar => '头像与背景';

  @override
  String get contextDetailAfterUndo => '撤销后';

  @override
  String get contextOperationUndo => '撤销此次上下文操作';

  @override
  String contextHistoryWindowNote(int count) {
    return '原样保留的历史仍受当前聊天“最多发送 $count 条消息”的限制。';
  }

  @override
  String get contextOverLimitWarning => '撤销后可能超出模型上下文上限，建议重新压缩。仍可撤销，发送前会再次检查。';

  @override
  String get storageSpaceImageTypeChat => '聊天图片';

  @override
  String get worldBookSelectEntries => '多选条目';

  @override
  String get compressUsageSummary => '预计摘要';

  @override
  String contextDetailRange(String from, String to, int count) {
    return '第 $from–$to 条 · $count 条用户消息';
  }

  @override
  String get contextOperationHidden => '已被后续清除隔开';

  @override
  String get contextUndoClearTooltip => '撤销此次清除';

  @override
  String compressKeepDescription(int count) {
    return '保留最近 $count 条用户消息及其回复、工具过程；更早内容由摘要替代。纯附件消息也算一条。';
  }

  @override
  String get contextOperationUndone => '已撤销';

  @override
  String contextEditPreview(String value) {
    return '保存后约 $value tokens。输入时不影响当前生效内容。';
  }

  @override
  String get contextDetailExcluded => '不再发送';

  @override
  String get worldBookNoMoveTargets => '请先创建另一本世界书，再移动条目。';

  @override
  String worldBookSelectedEntries(int count) {
    return '已选择 $count 项';
  }

  @override
  String get contextDetailReplaced => '被替代范围';

  @override
  String get displaySettingsPageAutoScrollEnabledLabel => '开启';

  @override
  String get contextChangeTitle => '确认上下文影响';

  @override
  String get contextDetailTitle => '压缩摘要';

  @override
  String get compressModelGlobal => '全局设置 · 本次启动后固定';

  @override
  String get wsDeniedMountReadonly => '只读挂载，不能写入。';

  @override
  String get compressRereadDesc => '处理多次压缩造成的信息损失，会增加本次用量';

  @override
  String get toolApprovalSwitchToFullAccess => '切换到完全访问';

  @override
  String get compressUsageInput => '本次摘要输入';

  @override
  String get contextDetailSummaryLabel => '实际用于后续请求的摘要';

  @override
  String get contextImpactDeleteTitle => '删除已压缩的原文？';

  @override
  String get compressAdvancedOff => '重读原文 关';

  @override
  String get contextOperationActive => '当前生效';

  @override
  String get compressAdvancedOn => '重读原文 开';

  @override
  String get contextTaskMerging => '正在合并摘要';

  @override
  String contextSampledInfo(int count) {
    return '本次只读取选定的 $count 字符，摘要会替代整个选定历史范围。';
  }

  @override
  String get contextDividerRunning => '正在压缩上下文';

  @override
  String get contextClearDetails => '此前聊天历史不再参与后续请求；系统提示、记忆和工具定义仍然生效。';

  @override
  String get compressCopyResult => '复制结果';

  @override
  String get contextDetailInUse => '当前直接使用';

  @override
  String get contextImpactDescription =>
      '相关摘要将一并撤销；原始聊天消息保留，不会自动调用模型。独立的上下文节点保持不变。';

  @override
  String get compressIncludeAttachmentsDesc =>
      '纳入已有附件文字、工具参数与结果；过长内容会截断并标明，不会重新识图。';

  @override
  String worldBookEntriesMoved(int count) {
    return '已移动 $count 个条目';
  }

  @override
  String get contextImpactSourceDescription =>
      '确认后变更原文，并撤销概括过它的摘要及依赖后继。其他消息与独立节点保留，不会自动调用模型。';

  @override
  String get contextEditTitle => '编辑摘要';

  @override
  String get compressUsageNext => '生效后下次请求';

  @override
  String get contextSummaryEmpty => '摘要不能为空；需要排除历史时请使用清除上下文。';

  @override
  String get toolApprovalDenied => '已拒绝';

  @override
  String get contextDetailModel => '模型 · 时间';

  @override
  String compressIncludeManual(int count) {
    return '纳入人工补充 · $count 份';
  }

  @override
  String contextBudgetInfo(int used, String limit) {
    return '下次请求估算（含输出预留）：$used / $limit tokens';
  }

  @override
  String get contextTaskDismiss => '关闭状态提示';

  @override
  String contextUndoBudgetInfo(int used) {
    return '撤销后预计约 $used tokens（含输出预留）';
  }

  @override
  String get storageSpaceImageInUse => '使用中';

  @override
  String get worldBookSelectionDone => '完成';

  @override
  String get contextDividerFailed => '压缩失败';

  @override
  String get toolPermissionUnboundHint => '未绑定工作区：不会因此开启文件或 Shell 工具。';

  @override
  String get contextChangeWaiting => '等待当前回复和工具执行结束后生效。';

  @override
  String storageSpaceDeletedUploadsPartial(int deleted, int kept) {
    return '已删除 $deleted 个项目；保留了 $kept 个正在使用或无法删除的项目。';
  }

  @override
  String get contextSourceScopeHint => '仅处理最近清除边界之后的历史，可能包含平时发送窗口之外的较早消息。';

  @override
  String get contextTaskPreparing => '正在准备压缩';

  @override
  String contextImpactUsage(String from, String to) {
    return '约 $from → $to tokens';
  }

  @override
  String contextImpactConfirm(int count) {
    return '撤销 $count 个节点';
  }

  @override
  String get contextDividerEdited => '已编辑';

  @override
  String get compressAdjust => '调整';

  @override
  String get compressRegenerate => '重新压缩';

  @override
  String get toolPermissionEnabledSnack => '已为此对话启用完全访问';

  @override
  String get contextDetailSuperseded => '已由后续摘要替代';

  @override
  String get contextTaskQueued => '已排队，等待压缩完成';

  @override
  String get contextNewConversation => '使用摘要创建新聊天';

  @override
  String get contextUnknownLimit => '上限未知';

  @override
  String get browserErrActionTimeout => '操作超时，结果未确认，请检查页面后允许继续';

  @override
  String get toolPermissionRequestApprovalDesc =>
      '工作区外文件访问、桌面命令和其他需要授权的工具将在执行前询问。';

  @override
  String get contextLimitedInputHint => '仅读取所选字符范围；被替代历史中的其余内容不会进入摘要，原始消息仍可回看。';

  @override
  String get contextTaskCancelled => '压缩已取消';

  @override
  String get contextDetailClearTitle => '上下文已清除';

  @override
  String get contextImpactKeep => '保持不变';

  @override
  String get contextImpactUndoAlso => '一并撤销';

  @override
  String get contextClearMarker => '上下文已清除';

  @override
  String get toolPermissionScopeThisChat => '仅此对话';

  @override
  String get dataDirectoryTitle => '数据存储目录';

  @override
  String get dataDirectoryChange => '更改目录';

  @override
  String get dataDirectoryChoose => '选择一个空的本地文件夹';

  @override
  String get dataDirectoryHint =>
      '请选择本地磁盘上的空文件夹。聊天记录、附件和应用管理的文件将在重启后搬迁。少量设备设置和系统缓存仍保留在系统目录。';

  @override
  String get dataDirectoryPendingHint => '将在下次重启时搬迁。复制和校验完成前，原数据保持不变。目标目录：';

  @override
  String get dataDirectoryRestart => '重启并搬迁数据';

  @override
  String get dataDirectoryCancelMove => '取消搬迁，继续使用原目录';

  @override
  String get dataDirectoryPreviousHint =>
      '已保留原数据副本。新目录成功启动后，可以清理旧副本以释放磁盘空间。再次更改目录前，请先清理此副本。';

  @override
  String get dataDirectoryCleanPrevious => '清理原数据副本';

  @override
  String get dataDirectoryCleanConfirm =>
      '确定清理以下目录中的原数据副本？当前目录中的数据会保留，搬迁后发生变化的文件不会被删除。';

  @override
  String get dataDirectoryMoving => '正在搬迁并校验数据…请保持 Kelivo 开启。';

  @override
  String get dataDirectoryStartupFailed => '无法打开数据目录';

  @override
  String get dataDirectoryRetry => '重试';

  @override
  String get dataDirectoryUnavailable =>
      '数据目录不可用。请重新连接磁盘，或将文件夹恢复到原位置后重试。应用不会创建空数据库。';

  @override
  String get dataDirectoryIdentityMismatch => '此文件夹与已设置的数据目录不匹配。请恢复原文件夹后重试。';

  @override
  String get dataDirectoryNotEmpty => '请选择空文件夹，不会覆盖已有文件。';

  @override
  String get dataDirectoryOverlap => '请选择当前数据目录之外的独立文件夹，不能选择其上级目录、子目录或磁盘根目录。';

  @override
  String get dataDirectoryLocalOnly => '请选择本地磁盘上的文件夹，不支持网络共享目录。';

  @override
  String get dataDirectoryFinishPrevious => '请先完成或取消待执行的搬迁，并清理保留的旧副本，再选择其他目录。';

  @override
  String get dataDirectoryPendingRestore => '有备份恢复尚未完成。请取消目录搬迁并重启，完成恢复后再更改目录。';

  @override
  String get dataDirectorySourceChanged =>
      '原数据在复制后发生了变化，已保留原文件。若正在搬迁，请取消后重新开始；若正在清理，请先检查原目录。';

  @override
  String get dataDirectoryCopyChanged => '目标目录存在意外文件或文件变化，原数据已保留。请检查目标目录后重试。';

  @override
  String get dataDirectoryGenericError =>
      '操作未完成。请检查磁盘剩余空间、文件夹权限，以及是否有其他 Kelivo 进程运行，然后重试。已有数据已保留。';

  @override
  String get dataDirectoryCancelHint => '取消搬迁会保留目标目录中已复制的文件，你可以检查后手动清理这些副本。';
}

/// The translations for Chinese, using the Han script (`zh_Hans`).
class AppLocalizationsZhHans extends AppLocalizationsZh {
  AppLocalizationsZhHans() : super('zh_Hans');

  @override
  String get settingsSearchHint => '搜索设置';

  @override
  String get settingsSearchCancel => '取消';

  @override
  String get settingsSearchClear => '清空搜索';

  @override
  String get settingsSearchSuggestions => '常用设置';

  @override
  String get settingsSearchNoResults => '未找到相关设置';

  @override
  String get settingsSearchNoResultsHint => '试试其他名称，或更简短的关键词。';

  @override
  String settingsSearchResultCount(int count) {
    return '找到 $count 项设置';
  }

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
  String get storageSpacePageTitle => '存储空间';

  @override
  String get storageSpaceRefreshTooltip => '刷新';

  @override
  String get storageSpaceLoadFailed => '无法加载文件或检查图片使用情况，请刷新后重试。';

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
  String get storageSpaceCategoryDisplacedDatabases => '保留的旧数据库';

  @override
  String get storageSpaceSubDisplacedDatabases => '自动重建前保留的数据库';

  @override
  String get storageSpaceClearDisplacedDatabasesConfirmMessage =>
      '确定删除这些保留的旧数据库吗？它们是 Kelivo 重建数据库时留下的，可能是那些聊天记录和设置仅存的一份。删除后无法恢复。';

  @override
  String get storageSpaceRestoreTracesHint => '恢复完成后保留的旧数据快照。清理不会影响当前应用数据。';

  @override
  String get storageSpaceClearRestoreTracesButton => '清理恢复痕迹';

  @override
  String get storageSpaceClearDisplacedDatabasesButton => '删除保留的旧数据库';

  @override
  String get storageSpaceClearRestoreTracesConfirmMessage =>
      '确定清理已完成恢复留下的旧数据快照吗？当前数据库、设置和文件不会受到影响。';

  @override
  String get storageSpaceSubCompletedRestoreRuns => '已完成的恢复快照';

  @override
  String get storageSpaceCategoryCache => '缓存';

  @override
  String get storageSpaceCategoryLogs => '日志';

  @override
  String get storageSpaceCategoryOther => '其他';

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
    return '删除 $count 个项目及其对应的会话附件副本？删除后，聊天记录中的这些附件将无法使用。';
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
  String statsPageCost(String currency) {
    return '费用 ($currency)';
  }

  @override
  String statsPageModelsWithoutPricing(int count) {
    return '$count 个模型无定价';
  }

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
  String contextMessageCount(int count) {
    return '$count 条消息';
  }

  @override
  String contextMessageCountLimited(int actual, int configured) {
    return '$actual/$configured 条消息';
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
  String get mcpServerEditSheetStdioCommandLabel => '命令';

  @override
  String get mcpServerEditSheetStdioArgumentsLabel => '参数';

  @override
  String get mcpServerEditSheetStdioWorkingDirectoryLabel => '工作目录（可选）';

  @override
  String get mcpWorkspaceBindingLabel => '绑定工作区（可选）';

  @override
  String get mcpWorkspaceBindingHint =>
      '服务器可通过 /workspace 访问此工作区。工作目录留空时默认进入该目录，切换聊天不会改变绑定。';

  @override
  String get mcpWorkspaceBindingMobileOnly =>
      '工作区绑定适用于移动端 Linux 环境。在桌面端运行此服务器前，请先解除绑定。';

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
  String get assistantEditThinkingBudgetTitle => '思考';

  @override
  String get assistantEditReasoningFollowDefault => '跟随模型默认';

  @override
  String get assistantEditReasoningClampedSubtitle => '实际档位会按各模型的能力收敛';

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
  String get iosBackgroundStatusOn => '开启';

  @override
  String get iosBackgroundStatusOff => '关闭';

  @override
  String get iosLiveActivityTitle => '实时活动';

  @override
  String get iosLiveActivitySubtitle => '支持时在锁屏和灵动岛显示后台回复状态。';

  @override
  String get notificationChatCompletedTitle => '生成完成';

  @override
  String get notificationChatCompletedBody => '助手回复已生成';

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
  String get assistantEditPromptIso8601Title => '使用 ISO 8601 格式';

  @override
  String get assistantEditPromptIso8601Subtitle =>
      '包含时区偏移，例如 2026-08-08T14:30:05+08:00';

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
  String get backupPageScopeTitle => '备份与导入内容';

  @override
  String backupPageScopeSelectedCount(int selected, int total) {
    return '$selected/$total';
  }

  @override
  String get backupPageBackupManagementDescription =>
      '选择备份和导入的内容，适用于本地、WebDAV 和 S3。导入时保留未选中的内容。技能和工作区包含各自的文件。';

  @override
  String get backupPageAssistantsLabel => '助手';

  @override
  String get backupPageProvidersLabel => '供应商';

  @override
  String get backupPageMcpLabel => 'MCP 服务器';

  @override
  String get backupPageEnvironmentVariablesLabel => '环境变量';

  @override
  String get backupPageSkillsLabel => '技能';

  @override
  String get backupPageWorldBooksLabel => '世界书';

  @override
  String get backupPageMemoriesLabel => '记忆';

  @override
  String get backupPageQuickPhrasesLabel => '快捷短语';

  @override
  String get backupPageInstructionsLabel => '提示词注入';

  @override
  String get backupPageWorkspacesLabel => '工作区';

  @override
  String get backupPageSearchServicesLabel => '搜索服务';

  @override
  String get backupPageSpeechServicesLabel => '语音服务';

  @override
  String get backupPageSettingsLabel => '其他设置';

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
  String get backupRestoreDirectoryBlockedTitle => '还原正在等待目录释放';

  @override
  String get backupRestoreDirectoryBlockedContent =>
      'Windows 无法移动下方目录。请关闭正在使用该目录的终端、编辑器或其他程序，然后继续还原。如果仍然受阻，请检查当前账户是否有移动该目录的权限。此前的还原进度已保留。';

  @override
  String get backupRestoreContinueButton => '继续还原';

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
  String get restoreProgressTitle => '正在恢复备份';

  @override
  String get restoreProgressWarning => '请保持 Kelivo 开启直到完成。此时关闭应用，下次启动会从头再来一次。';

  @override
  String get restoreProgressStageCheckingBackup => '正在校验备份';

  @override
  String get restoreProgressStagePreservingCurrentData => '正在保留当前数据';

  @override
  String get restoreProgressStageInstallingBackup => '正在写入备份';

  @override
  String get restoreProgressStageVerifying => '正在验证';

  @override
  String get restoreProgressStageRollingBack => '正在恢复原有数据';

  @override
  String get restoreProgressStageFinishing => '即将完成';

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
  String get startupRecoveryRepairFailed =>
      '修复未能完成。数据已保留，可以选择通过校验的副本恢复，或导出数据进一步排查。';

  @override
  String get startupRecoveryResetFailed => '重置失败。请彻底关闭 Kelivo 后重新打开。';

  @override
  String get startupRecoveryResetDialogTitle => '重置全部数据？';

  @override
  String get startupRecoveryResetDialogContent =>
      '开始使用新的空数据库？当前数据库及其日志文件、已有副本都会保留，供之后恢复。';

  @override
  String get startupRecoveryResetDialogConfirm => '重置并重启';

  @override
  String get startupRecoveryResetDialogCancel => '取消';

  @override
  String get startupRecoveryWhatFailed => '失败原因';

  @override
  String get startupRecoveryStageLabel => '失败阶段';

  @override
  String get startupRecoveryStageRestore => '恢复关卡';

  @override
  String get startupRecoveryStageDatabase => '数据库启动';

  @override
  String get startupRecoveryDiagnosticLabel => '诊断码';

  @override
  String get startupRecoverySchemaLabel => '数据库版本';

  @override
  String startupRecoverySchemaValue(String installed, int expected) {
    return '磁盘上为 $installed · 当前版本需要 $expected';
  }

  @override
  String get startupRecoveryAppVersionLabel => '应用';

  @override
  String get startupRecoveryUnknownValue => '未知';

  @override
  String get startupRecoveryCollecting => '正在收集诊断信息…';

  @override
  String get startupRecoveryShowDetails => '展开技术细节';

  @override
  String get startupRecoveryHideDetails => '收起技术细节';

  @override
  String get startupRecoveryCopyReport => '复制完整报告';

  @override
  String get startupRecoveryReportCopied => '已复制完整报告';

  @override
  String get startupRecoveryShareReport => '导出报告';

  @override
  String startupRecoveryReportStored(String path) {
    return '报告已保存到 $path';
  }

  @override
  String startupRecoveryReportSaved(String path) {
    return '报告已保存到 $path';
  }

  @override
  String get startupRecoveryReportShared => '报告已导出。';

  @override
  String get startupRecoveryReportSaveFailed => '无法导出报告。';

  @override
  String get startupRecoverySectionDataTitle => '你的数据';

  @override
  String get startupRecoverySectionDataBody =>
      '目前没有任何数据被删除。在尝试下面的操作前，先把副本保存到安全的地方。';

  @override
  String startupRecoveryExportSavedTo(String path) {
    return '数据副本已保存到 $path';
  }

  @override
  String get startupRecoverySectionRepairTitle => '诊断与修复';

  @override
  String get startupRecoverySectionRepairBody =>
      '完整性检查只读取数据库。修复会清理上次更新中断留下的元数据并重新启动，不会删除聊天记录。';

  @override
  String get startupRecoveryIntegrityButton => '检查数据库完整性';

  @override
  String get startupRecoveryIntegrityHealthy => 'SQLite 未在数据库文件中发现损坏。';

  @override
  String startupRecoveryIntegrityDamaged(String detail) {
    return 'SQLite 报告了问题 —— $detail';
  }

  @override
  String get startupRecoveryIntegrityMissing => '数据目录中没有找到数据库文件。';

  @override
  String get startupRecoveryIntegrityFailed => '完整性检查无法运行。';

  @override
  String get startupRecoveryDangerZone => '危险操作';

  @override
  String get startupRecoveryDangerBody =>
      '重新开始后，当前数据将不再显示。Kelivo 会保留旧数据库和已有副本以供恢复，建议先导出一份数据副本。';

  @override
  String get startupRecoveryResetAcknowledge => '我确认开始使用新的空数据库。';

  @override
  String get startupDatabaseUpdateRequiredTitle => '请更新 Kelivo 以继续';

  @override
  String get startupDatabaseUpdateRequiredContent =>
      '本设备上的聊天数据库由更新版本的 Kelivo 创建，当前版本无法打开。数据未被改动。请安装最新版 Kelivo 后重新打开。';

  @override
  String get startupDatabaseUpdateRequiredDowngradeTitle => '若要改用旧版';

  @override
  String get startupDatabaseUpdateRequiredDowngradeIntro =>
      '当前版本打不开本机这份数据库。若你必须留在旧版，请按下面的步骤处理；在备份完成之前，不要删除或覆盖这里的数据。';

  @override
  String get startupDatabaseUpdateRequiredDowngradeStep1 =>
      '先安装并打开最新版 Kelivo，在「设置 → 数据备份」导出一份备份文件。';

  @override
  String startupDatabaseUpdateRequiredDowngradeStep2(String url) {
    return '打开 $url，把备份转换成你打算使用的旧版格式。';
  }

  @override
  String get startupDatabaseUpdateRequiredDowngradeStep3 =>
      '确认本机数据已经另外备份好之后，再安装旧版，并导入转换后的备份。';

  @override
  String get startupDatabaseUpdateRequiredOpenTool => '打开转换工具';

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
      '请选择恢复方式。备份管理中的分类开关同样适用于本次导入。';

  @override
  String get backupPageOverwriteMode => '完全覆盖';

  @override
  String get backupPageOverwriteModeDescription =>
      '替换所选内容，保留未选内容及其他本机设置。替换聊天时，也会清除本机未发送的草稿。';

  @override
  String get backupPageMergeMode => '合并';

  @override
  String get backupPageMergeModeDescription =>
      '保留本地数据并加入备份数据；相同会话会跳过，冲突会话会重新分配 ID。';

  @override
  String get backupPageRestore => '恢复';

  @override
  String get backupPageForwardCompatTitle => '备份来自更新的版本';

  @override
  String backupPageForwardCompatBody(int backupVersion, int currentVersion) {
    return '这份备份由更新版本的 Kelivo 创建（数据格式 $backupVersion，当前版本支持 $currentVersion），且未声明旧版本能否读取。\n\n你可以继续导入：当前版本不认识的内容会被跳过，备份文件本身不会被修改。但如果新版本改变了已有数据的存储方式，部分内容可能会被错误导入。\n\n更稳妥的做法是先升级 Kelivo。';
  }

  @override
  String get backupPageForwardCompatContinue => '仍然导入';

  @override
  String get backupPageForwardCompatCancel => '取消';

  @override
  String get backupPageSchemaTooNewMessage =>
      '这份备份由更新版本的 Kelivo 创建，当前版本无法读取。请先升级 Kelivo 后重试。';

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
  String get backupProgressFailed => '操作失败';

  @override
  String backupProgressFailedAt(String phase) {
    return '失败阶段：$phase';
  }

  @override
  String get backupProgressCopyError => '复制错误';

  @override
  String get backupProgressErrorCopied => '错误已复制';

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
  String get backupPageIosSystemBackupNote =>
      'Kelivo 的本地数据已设置为不参与 iCloud 系统备份。换机或卸载 App 前，请先导出备份文件。';

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
  String get compressContextDesc => '生成可查看、可撤销的摘要';

  @override
  String get clearContextDesc => '标记上下文分界点';

  @override
  String get contextManagement => '上下文管理';

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
  String get compressContextOptionsDesc => '在当前聊天生成可查看、可编辑、可撤销的摘要。原始消息保留。';

  @override
  String get compressContextKeepStart => '开头取样';

  @override
  String get compressContextKeepRecent => '末尾取样';

  @override
  String get compressContextUnlimited => '全部内容';

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
  String get compressContextKeepRecentMessages => '保留 N 条';

  @override
  String get compressContextKeepCountLabel => '保留用户消息数';

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
  String get reasoningBudgetSheetTitle => '思维链强度';

  @override
  String get reasoningLevelSheetTitle => '推理';

  @override
  String get reasoningLevelAuto => '自动';

  @override
  String get reasoningLevelAutoSubtitle => '使用模型或供应商的默认设置';

  @override
  String get reasoningLevelOff => '关闭';

  @override
  String get reasoningLevelOffSubtitle => '关闭推理，直接回答';

  @override
  String get reasoningLevelMinimal => '最低';

  @override
  String get reasoningLevelMinimalSubtitle => '使用极少推理来回答问题';

  @override
  String get reasoningLevelLow => '低';

  @override
  String get reasoningLevelLowSubtitle => '使用少量推理来回答问题';

  @override
  String get reasoningLevelMedium => '中';

  @override
  String get reasoningLevelMediumSubtitle => '使用较多推理来回答问题';

  @override
  String get reasoningLevelHigh => '高';

  @override
  String get reasoningLevelHighSubtitle => '使用大量推理来回答问题，适合复杂问题';

  @override
  String get reasoningLevelXhigh => '极高';

  @override
  String get reasoningLevelXhighSubtitle => '使用很高推理深度，适合更复杂的问题';

  @override
  String get reasoningLevelMax => '最大';

  @override
  String get reasoningLevelMaxSubtitle => '使用最大推理深度，适合最复杂的问题';

  @override
  String get reasoningLevelFollowModelDefaultSubtitle => '使用模型或助手未设置时的默认档位';

  @override
  String get reasoningLevelNoReasoning => '此模型不支持推理';

  @override
  String get reasoningLevelCustomBudget => '自定义推理预算';

  @override
  String get reasoningLevelCustomBudgetHint => '例如：2048';

  @override
  String get reasoningLevelCompactMin => 'min';

  @override
  String get reasoningLevelCompactLow => 'low';

  @override
  String get reasoningLevelCompactMid => 'mid';

  @override
  String get reasoningLevelCompactHigh => 'high';

  @override
  String get reasoningLevelCompactXhigh => 'xhigh';

  @override
  String get reasoningLevelCompactMax => 'max';

  @override
  String reasoningLevelBudgetTokens(String budget) {
    return '$budget tokens';
  }

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
  String chatMessageWidgetWebFetch(String target) {
    return '读取网页: $target';
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
  String get displaySettingsPageCollapseLongUserMessagesTitle => '折叠过长消息';

  @override
  String get displaySettingsPageCollapseLongUserMessagesSubtitle =>
      '超过阈值的用户消息折叠显示，点击可展开';

  @override
  String get displaySettingsPageCollapseLongUserMessagesCharsTitle =>
      '超过多少字符折叠';

  @override
  String get displaySettingsPageCollapseLongUserMessagesCharsUnit => '字符';

  @override
  String get chatMessageExpandLongText => '展开';

  @override
  String get chatMessageCollapseLongText => '收起';

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
  String get chatInputBarToolsTooltip => '工具';

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
  String get chatInputBarVoiceAttachAudioTooltip => '停止并存为音频';

  @override
  String get chatInputBarVoiceSendAudioTooltip => '直接发送录音';

  @override
  String get chatInputBarVoiceSavingAudio => '正在保存录音…';

  @override
  String get audioClipPlayTooltip => '播放音频';

  @override
  String get audioClipPauseTooltip => '暂停';

  @override
  String get audioClipPlaybackFailed => '无法播放此音频';

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
  String get contextUsageTitle => '上下文窗口';

  @override
  String get contextUsageStateExact => '精确（来自上次响应）';

  @override
  String get contextUsageStateExactCalibrated => '精确（分项按估算比例）';

  @override
  String get contextUsageStateEstimated => '估算';

  @override
  String get contextUsageStateStale => '已过时，正在更新…';

  @override
  String get contextUsageStateComputing => '计算中…';

  @override
  String get contextUsageStateNone => '暂无数据';

  @override
  String get contextUsageBucketSystem => '系统提示词';

  @override
  String get contextUsageBucketInjections => '指令注入';

  @override
  String get contextUsageBucketHistory => '历史消息';

  @override
  String get contextUsageBucketTools => '内置工具';

  @override
  String get contextUsageBucketMemory => '记忆';

  @override
  String get contextUsageBucketWorldBook => '世界书';

  @override
  String get contextUsageBucketSkills => '技能';

  @override
  String get contextUsageBucketWorkspace => '工作区';

  @override
  String get contextUsageBucketSearch => '搜索提示';

  @override
  String get contextUsageBucketMcpTools => 'MCP 工具';

  @override
  String get contextUsageBucketAttachments => '附件';

  @override
  String get contextUsageBucketDraft => '草稿';

  @override
  String get contextUsageBucketUsed => '已用';

  @override
  String get contextUsageFreeSpace => '剩余空间';

  @override
  String contextUsageUsedWindow(String used, String window, int percent) {
    return '$used / $window ($percent%)';
  }

  @override
  String get contextUsageNoWindow => '未设置上下文窗口';

  @override
  String get contextUsageSetWindow => '设置上下文窗口';

  @override
  String get contextUsageRefresh => '刷新';

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
  String get mcpPageStatusDisabled => '已停用';

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
  String get defaultModelPageTitleModelSubtitle =>
      '用于总结对话标题，默认跟随当前对话模型，也可指定其他模型。';

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
      '用于在助手回复后生成聊天建议，可跟随当前对话模型或指定其他模型。默认未启用。';

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
  String get defaultModelPageDisable => '禁用';

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
  String get modelDetailSheetWebFetchTool => '网页抓取';

  @override
  String get modelDetailSheetOpenrouterWebFetchToolDescription =>
      '启用 OpenRouter 网页抓取服务端工具';

  @override
  String get modelDetailSheetClaudeWebFetchToolDescription =>
      '允许 Claude 抓取对话中出现的网页与 PDF';

  @override
  String get modelDetailSheetClaudeCodeExecutionToolDescription =>
      '允许 Claude 在 Anthropic 沙箱中运行 Python 与 Bash';

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
  String get modelDetailSheetHeaderKeyHint => 'Header Key';

  @override
  String get modelDetailSheetHeaderValueHint => 'Header Value';

  @override
  String get modelDetailSheetBodyKeyHint => 'Body Key';

  @override
  String get modelDetailSheetBodyJsonHint => 'Body JSON';

  @override
  String get modelSpecFormSourceCustom => '自定义';

  @override
  String get modelSpecFormSourceCatalog => '目录';

  @override
  String get modelSpecFormSourceInferred => '推断';

  @override
  String get modelSpecFormSourceDefault => '默认';

  @override
  String get modelSpecFormReset => '重置为默认';

  @override
  String get modelSpecFormModalitiesSection => '模态与能力';

  @override
  String get modelSpecFormImageType => '图像';

  @override
  String get modelSpecFormAudioMode => '音频';

  @override
  String get modelSpecFormVideoMode => '视频';

  @override
  String get modelSpecFormPdfMode => 'PDF';

  @override
  String get modelSpecFormStructuredOutputAbility => '结构化输出';

  @override
  String get modelSpecFormReasoningSection => '推理';

  @override
  String get modelSpecFormDialect => '推理方言';

  @override
  String get modelSpecFormDialectNone => '无';

  @override
  String get modelSpecFormDialectNoneSubtitle => '不写入推理字段';

  @override
  String get modelSpecFormDialectOpenaiReasoningEffort =>
      'OpenAI reasoning effort';

  @override
  String get modelSpecFormDialectOpenaiReasoningEffortSubtitle =>
      'reasoning_effort';

  @override
  String get modelSpecFormDialectOpenaiResponsesReasoning =>
      'OpenAI Responses reasoning';

  @override
  String get modelSpecFormDialectOpenaiResponsesReasoningSubtitle =>
      'reasoning.effort';

  @override
  String get modelSpecFormDialectOpenrouterReasoning => 'OpenRouter reasoning';

  @override
  String get modelSpecFormDialectOpenrouterReasoningSubtitle => 'reasoning';

  @override
  String get modelSpecFormDialectAnthropicBudget => 'Anthropic budget';

  @override
  String get modelSpecFormDialectAnthropicBudgetSubtitle =>
      'thinking.budget_tokens';

  @override
  String get modelSpecFormDialectAnthropicAdaptiveEffort =>
      'Anthropic adaptive effort';

  @override
  String get modelSpecFormDialectAnthropicAdaptiveEffortSubtitle =>
      'thinking + output_config.effort';

  @override
  String get modelSpecFormDialectAnthropicBetweenTools =>
      'Anthropic adaptive / between_tools';

  @override
  String get modelSpecFormDialectAnthropicBetweenToolsSubtitle =>
      '自适应思考；关闭时使用 between_tools';

  @override
  String get modelSpecFormDialectAnthropicEffort => 'Anthropic effort';

  @override
  String get modelSpecFormDialectAnthropicEffortSubtitle =>
      'thinking + output_config.effort';

  @override
  String get modelSpecFormDialectGeminiThinkingBudget =>
      'Gemini thinking budget';

  @override
  String get modelSpecFormDialectGeminiThinkingBudgetSubtitle =>
      'thinkingConfig.thinkingBudget';

  @override
  String get modelSpecFormDialectGeminiThinkingLevel => 'Gemini thinking level';

  @override
  String get modelSpecFormDialectGeminiThinkingLevelSubtitle =>
      'thinkingConfig.thinkingLevel';

  @override
  String get modelSpecFormDialectQwenEnableThinking => 'Qwen enable thinking';

  @override
  String get modelSpecFormDialectQwenEnableThinkingSubtitle =>
      'enable_thinking';

  @override
  String get modelSpecFormDialectThinkingType => 'Thinking type';

  @override
  String get modelSpecFormDialectThinkingTypeSubtitle => 'thinking.type';

  @override
  String get modelSpecFormDialectSiliconflowEnableThinking =>
      'SiliconFlow enable thinking';

  @override
  String get modelSpecFormDialectSiliconflowEnableThinkingSubtitle =>
      'enable_thinking';

  @override
  String get modelSpecFormDialectInternThinkingMode => 'Intern thinking mode';

  @override
  String get modelSpecFormDialectInternThinkingModeSubtitle => 'thinking_mode';

  @override
  String get modelSpecFormDialectChatTemplateKwargs => 'Chat template kwargs';

  @override
  String get modelSpecFormDialectChatTemplateKwargsSubtitle =>
      'chat_template_kwargs.enable_thinking';

  @override
  String get modelSpecFormDialectKimiThinking => 'Kimi thinking';

  @override
  String get modelSpecFormDialectKimiThinkingSubtitle => 'thinking';

  @override
  String get modelSpecFormDialectCustom => '自定义 JSON';

  @override
  String get modelSpecFormDialectCustomSubtitle => '按级别写入 JSON 补丁';

  @override
  String get modelSpecFormLevels => '支持的级别';

  @override
  String get modelSpecFormCanDisable => '允许关闭';

  @override
  String get modelSpecFormDefaultLevel => '默认级别';

  @override
  String get modelSpecFormBudgets => 'Token 预算';

  @override
  String modelSpecFormBudgetPlaceholder(String tokens) {
    return '$tokens';
  }

  @override
  String modelSpecFormCustomPatch(String level) {
    return 'JSON 补丁（$level）';
  }

  @override
  String get modelSpecFormCustomPatchHint => '例如 reasoning_effort: high';

  @override
  String get modelSpecFormInvalidJson => '自定义推理补丁必须是有效的 JSON 对象';

  @override
  String get modelSpecFormInvalidNumber => '请输入有效数字';

  @override
  String get modelSpecFormStrategySection => '策略';

  @override
  String get modelSpecFormSampling => '采样';

  @override
  String get modelSpecFormRequestQuirks => '请求兼容';

  @override
  String get modelSpecFormDynamicWebSearch => '动态过滤搜索工具';

  @override
  String get modelSpecFormDynamicWebSearchSubtitle =>
      '开启动态过滤时，使用 2026-03-18 版网页搜索与抓取工具';

  @override
  String get modelSpecFormRemoteImageUrls => '远程图片链接';

  @override
  String get modelSpecFormRemoteImageUrlsSubtitle =>
      '直接发送 http(s) 图片链接；关闭后丢弃远程链接，只发送本地图片';

  @override
  String get modelSpecFormPromptCacheControl => '提示缓存标记';

  @override
  String get modelSpecFormPromptCacheControlSubtitle =>
      '开启提示缓存时，在 OpenRouter 请求中加入 cache_control';

  @override
  String get modelSpecFormSamplingAlways => '始终保留';

  @override
  String get modelSpecFormSamplingAlwaysSubtitle => '保留 temperature 等采样字段';

  @override
  String get modelSpecFormSamplingOnlyWhenReasoningOff => '仅在关闭推理时';

  @override
  String get modelSpecFormSamplingOnlyWhenReasoningOffSubtitle => '模型思考时移除采样字段';

  @override
  String get modelSpecFormSamplingNever => '从不';

  @override
  String get modelSpecFormSamplingNeverSubtitle => '始终移除采样字段';

  @override
  String get modelSpecFormReplay => '推理回放';

  @override
  String get modelSpecFormReplayNone => '无';

  @override
  String get modelSpecFormReplayNoneSubtitle => '不把先前推理发回模型';

  @override
  String get modelSpecFormReplayToolTurns => '工具轮次';

  @override
  String get modelSpecFormReplayToolTurnsSubtitle => '仅在工具调用轮次回放推理';

  @override
  String get modelSpecFormReplayAll => '全部';

  @override
  String get modelSpecFormReplayAllSubtitle => '每一轮后续请求都回放推理';

  @override
  String get modelSpecFormReplayField => '回放字段';

  @override
  String get modelSpecFormReplayFieldReasoningContent => 'reasoning_content';

  @override
  String get modelSpecFormReplayFieldReasoning => 'reasoning';

  @override
  String get modelSpecFormReplayFieldReasoningDetails => 'reasoning_details';

  @override
  String get modelSpecFormLimitsSection => '限额';

  @override
  String get modelSpecFormLimitsPricingSection => '限额与定价';

  @override
  String get modelSpecFormContextWindow => '上下文窗口';

  @override
  String get modelSpecFormMaxOutput => '最大输出';

  @override
  String get modelSpecFormPricingSection => '定价 / 1M';

  @override
  String get modelSpecFormPricingInput => '输入';

  @override
  String get modelSpecFormPricingOutput => '输出';

  @override
  String get modelSpecFormPricingCacheRead => '缓存读取';

  @override
  String get modelSpecFormPricingCacheWrite => '缓存写入';

  @override
  String get modelSpecFormCurrency => '货币';

  @override
  String get modelSpecFormAdvancedSection => '请求';

  @override
  String get modelSelectSheetSearchHint => '搜索模型或服务商';

  @override
  String get modelSelectSheetFavoritesSection => '收藏';

  @override
  String get modelSelectSheetFollowAssistant => '跟随助手';

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
  String get providerDetailPagePromptCacheKeyTitle => '发送会话缓存键';

  @override
  String get providerDetailPagePromptCacheKeyHelp =>
      '为 OpenAI 兼容请求附加稳定的会话级 prompt_cache_key。仅在供应商支持时开启，自定义 Body 优先，不保证缓存命中。';

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
  String get modelCatalogTitle => '模型目录';

  @override
  String modelCatalogSourceBundled(String date) {
    return '内置快照 · $date';
  }

  @override
  String modelCatalogSourceRemote(String date) {
    return 'models.dev · 更新于 $date';
  }

  @override
  String get modelCatalogAutoUpdate => '每 24 小时自动更新';

  @override
  String get modelCatalogRefresh => '立即更新';

  @override
  String get modelCatalogUpdated => '模型目录已更新';

  @override
  String modelCatalogRefreshFailed(String error) {
    return '更新失败：$error';
  }

  @override
  String modelCatalogProviderCount(int count) {
    return '$count 个供应商';
  }

  @override
  String modelCatalogModelCount(int count) {
    return '$count 个模型';
  }

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
  String get searchServicesPageWebFetchSection => '网页抓取';

  @override
  String get searchServicesPageWebFetchModeTitle => '抓取方式';

  @override
  String get searchServicesPageWebFetchFollow => '跟随搜索服务';

  @override
  String searchServicesPageWebFetchFollowValue(String name) {
    return '跟随搜索 · $name';
  }

  @override
  String searchServicesPageWebFetchFollowSubtitle(String name) {
    return '当前：$name';
  }

  @override
  String get searchServicesPageWebFetchLocal => '本地抓取';

  @override
  String get searchServicesPageWebFetchLocalSubtitle => '免费，由本机直接请求网页';

  @override
  String get searchServicesPageWebFetchProviderSubtitle =>
      '使用该服务商的 API Key 和额度';

  @override
  String get searchServicesPageWebFetchOff => '关闭';

  @override
  String get searchServicesPageWebFetchOffSubtitle => '联网时只搜索，不读取网页';

  @override
  String get searchServicesPageWebFetchFooter =>
      '开启联网搜索后，模型还可以读取网页全文。搜索服务不支持抓取时会改用本地抓取，本地抓取无法处理需要 JavaScript 渲染或有反爬限制的页面。';

  @override
  String get searchServicesPageWebFetchSupported => '支持网页抓取';

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
  String get searchServicesDialogApiKeyOptional => 'API Key（可选）';

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
  String get searchServiceEditorTestModeSearch => '搜索';

  @override
  String get searchServiceEditorTestModeFetch => '抓取';

  @override
  String get searchServiceEditorTestUrlHint => '输入测试网址';

  @override
  String get searchServiceEditorTestFetchRun => '运行抓取测试';

  @override
  String get searchServiceEditorTestFetchRunning => '抓取中…';

  @override
  String searchServiceEditorTestFetchFailed(String message) {
    return '抓取失败：$message';
  }

  @override
  String searchServiceEditorTestFetchStats(String characters, String seconds) {
    return '$characters 字符 · $seconds 秒';
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
  String get searchSettingsSheetClaudeDynamicSearchTitle => '动态过滤';

  @override
  String get searchSettingsSheetClaudeDynamicSearchDescription =>
      '筛选搜索结果，节省 token';

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
  String get aboutPageQQGroupThree => 'Kelivo 三群';

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
  String get displaySettingsPageShowTotalTokensTitle => '显示整轮累计 Token';

  @override
  String get displaySettingsPageShowTotalTokensSubtitle =>
      '累计显示本次回复中所有 API 请求的用量。关闭时仅显示最后一次请求；统计页面始终包含所有请求。';

  @override
  String get displaySettingsPageShowTokenStatsSubtitle => '显示 token 用量与消息数量';

  @override
  String get displaySettingsPageShowThinkingCardsTitle => '显示思考卡片';

  @override
  String get displaySettingsPageShowThinkingCardsSubtitle =>
      '关闭后，聊天中不再显示思考过程卡片';

  @override
  String get displaySettingsPageShowToolCardsTitle => '显示工具卡片';

  @override
  String get displaySettingsPageShowToolCardsSubtitle => '关闭后，聊天中不再显示工具调用卡片';

  @override
  String get displaySettingsShowReasoningLevelBadge => '在推理按钮上显示档位';

  @override
  String get displaySettingsShowReasoningLevelBadgeSubtitle =>
      '在输入栏的推理图标旁显示当前档位';

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
  String get displaySettingsPageHideToolResultImagesTitle => '隐藏工具结果中的图片';

  @override
  String get displaySettingsPageRegenerateDeleteTrailingMessagesTitle =>
      '重新生成时删除下面的消息';

  @override
  String get displaySettingsPageShowRegenerateConfirmDialogTitle => '重新生成前弹出确认';

  @override
  String get displaySettingsPageForkKeepMessageVersionsTitle => '创建分支时保留消息版本';

  @override
  String get displaySettingsPageEditAssistantKeepThinkingToolCardsTitle =>
      '编辑助手时保留思考与工具卡片';

  @override
  String get displaySettingsPageEditAssistantKeepThinkingToolCardsSubtitle =>
      '关闭后，当前编辑版本只保留助手正文；切回上一版本仍可查看思考与工具卡片';

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
  String get displaySettingsPageAutoScrollEnableTitle => '自动跟随底部';

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
  String get linuxHideTitleBarTitle => '隐藏系统标题栏';

  @override
  String get linuxHideTitleBarDescription => '同时隐藏窗口按钮。请通过窗口管理器移动、调整大小和关闭窗口。';

  @override
  String get linuxHideTitleBarError => '无法更改标题栏，请重试。';

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
  String get themeAdvancedSettingsPageTitle => '主题高级设置';

  @override
  String get themeAdvancedSettingsPageUseLayeredSurfacesTitle => '新版分层配色（实验）';

  @override
  String get themeAdvancedSettingsPageUseLayeredSurfacesSubtitle =>
      '页面更深、卡片更亮，两者都保留主题色相；关闭可恢复旧外观';

  @override
  String get themeAdvancedSettingsPageUseLayeredSheetTilesTitle => '弹窗内瓦片分层';

  @override
  String get themeAdvancedSettingsPageUseLayeredSheetTilesSubtitle =>
      '默认瓦片与弹窗同色';

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
  String get asrServicesGroqSubtitle => 'Whisper 分段云端转写';

  @override
  String get asrServicesMistralSubtitle => 'Voxtral 分段云端转写';

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
  String get searchProviderExaMcpDescription =>
      '通过 MCP 使用 Exa 搜索。不填 API Key 可在免费限额内使用。';

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
  String get searchProviderDeepSeekDescription =>
      'DeepSeek 官方网页搜索与抓取 API，使用 DeepSeek API Key。';

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
  String get searchServiceNameExaMcp => 'Exa MCP';

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
  String get searchServiceNameDeepSeek => 'DeepSeek';

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
  String get searchServiceNameAnySearch => 'AnySearch';

  @override
  String get searchProviderAnySearchDescription =>
      '面向 AI 智能体的统一搜索服务，可在网页与专业数据源间自动路由。API Key 可选。';

  @override
  String get searchServiceNameKagi => 'Kagi';

  @override
  String get searchProviderKagiDescription => 'Kagi 搜索 API，提供 Kagi 的高级网页搜索结果。';

  @override
  String get searchServiceNameKimi => 'Kimi';

  @override
  String get searchProviderKimiDescription =>
      'Kimi 搜索 API。Pro 返回相关网页正文片段，Basic 返回标题、链接和摘要。';

  @override
  String get searchServiceNameParallel => 'Parallel';

  @override
  String get searchProviderParallelDescription =>
      'Parallel 搜索 API。返回面向 LLM 优化的网页摘录，支持 turbo、fast、basic 和 advanced 模式。';

  @override
  String get searchServicesDialogSearchMode => '搜索模式';

  @override
  String get searchServiceNameYou => 'You.com';

  @override
  String get searchProviderYouDescription =>
      'You.com 搜索 API。返回网页与新闻结果，支持 Highlights 或 Snippets。';

  @override
  String get searchServicesDialogContentMode => '内容模式';

  @override
  String get searchServicesDialogHighlights => 'Highlights';

  @override
  String get searchServicesDialogSnippets => 'Snippets';

  @override
  String get searchServicesDialogWebSearch => 'Web Search';

  @override
  String get searchServicesDialogLlmContext => 'LLM Context';

  @override
  String get searchServicesDialogMaximumTokens => '最大 token 数';

  @override
  String get searchServicesDialogMaximumTokensInvalid =>
      '最大 token 数必须介于 1024 和 32768 之间。';

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
  String get assistantEditLocalToolLocationTitle => '当前位置';

  @override
  String get assistantEditLocalToolLocationSubtitle => '读取本设备的一次性位置，需要授予定位权限。';

  @override
  String get assistantEditLocalToolWeatherTitle => '天气';

  @override
  String get assistantEditLocalToolWeatherSubtitle =>
      '获取当前位置或指定地点的 Apple 天气，结果中会展示 WeatherKit 数据来源。';

  @override
  String get assistantEditLocalToolHealthTitle => '健康摘要';

  @override
  String get assistantEditLocalToolHealthSubtitle =>
      '读取本设备的健康活动摘要，需要授予健康数据读取权限。';

  @override
  String assistantEditLocalToolHealthSelectedCount(int selected, int total) {
    return '已选择 $selected/$total 项';
  }

  @override
  String get healthDataSettingsTitle => '健康数据';

  @override
  String get healthDataSettingsDescription =>
      '当前助手在日常对话中可使用的 HealthKit 信号。开关表示 Kelivo 可以尝试读取该范围，实际授权仍由 iOS 管理。';

  @override
  String healthDataSettingsBadge(int selected, int total) {
    return '$selected/$total 开启';
  }

  @override
  String get healthDataSettingsIosReadTitle => 'iOS 健康读取';

  @override
  String get healthDataSettingsIosReadSubtitle => '设备可用，读取范围由 iOS 管理';

  @override
  String get healthDataSettingsOpenSystemSettings => '打开系统设置';

  @override
  String get healthDataSettingsEnableAll => '全部开启';

  @override
  String get healthDataSettingsDisableAll => '全部关闭';

  @override
  String get healthDataSettingsCategoryActivity => '活动';

  @override
  String get healthDataSettingsCategoryRest => '休息';

  @override
  String get healthDataSettingsCategoryHeart => '心率';

  @override
  String get healthDataSettingsCategoryBody => '身体';

  @override
  String get healthDataSettingsTypeStepsTitle => '步数';

  @override
  String get healthDataSettingsTypeStepsSubtitle => '行走步数摘要';

  @override
  String get healthDataSettingsTypeDaylightTitle => '日照';

  @override
  String get healthDataSettingsTypeDaylightSubtitle => '户外日光时间';

  @override
  String get healthDataSettingsTypeActiveEnergyTitle => '能量';

  @override
  String get healthDataSettingsTypeActiveEnergySubtitle => '活动能量消耗';

  @override
  String get healthDataSettingsTypeExerciseMinutesTitle => '锻炼';

  @override
  String get healthDataSettingsTypeExerciseMinutesSubtitle => 'Apple 锻炼分钟数';

  @override
  String get healthDataSettingsTypeStandTimeTitle => '站立';

  @override
  String get healthDataSettingsTypeStandTimeSubtitle => '站立时间';

  @override
  String get healthDataSettingsTypeDistanceTitle => '距离';

  @override
  String get healthDataSettingsTypeDistanceSubtitle => '步行和跑步距离';

  @override
  String get healthDataSettingsTypeWorkoutsTitle => '健身训练';

  @override
  String get healthDataSettingsTypeWorkoutsSubtitle => '训练记录：类型、时长、距离与消耗';

  @override
  String get healthDataSettingsTypeSleepTitle => '睡眠';

  @override
  String get healthDataSettingsTypeSleepSubtitle => '最近 24 小时的睡眠、卧床、清醒与睡眠分期';

  @override
  String get healthDataSettingsTypeMindfulnessTitle => '静息';

  @override
  String get healthDataSettingsTypeMindfulnessSubtitle => '正念或静息时段';

  @override
  String get healthDataSettingsTypeHeartRateTitle => '心率';

  @override
  String get healthDataSettingsTypeHeartRateSubtitle => '最近心率样本';

  @override
  String get healthDataSettingsTypeRestingHeartRateTitle => '静息心率';

  @override
  String get healthDataSettingsTypeRestingHeartRateSubtitle => '静息状态心率';

  @override
  String get healthDataSettingsTypeBloodOxygenTitle => '血氧';

  @override
  String get healthDataSettingsTypeBloodOxygenSubtitle => '血氧饱和度';

  @override
  String get healthDataSettingsTypeDietaryEnergyTitle => '摄入能量';

  @override
  String get healthDataSettingsTypeDietaryEnergySubtitle => '饮食热量记录';

  @override
  String get healthDataSettingsTypeWaterTitle => '饮水';

  @override
  String get healthDataSettingsTypeWaterSubtitle => '饮水量记录';

  @override
  String get healthDataSettingsTypeWeightTitle => '体重';

  @override
  String get healthDataSettingsTypeWeightSubtitle => '体重样本';

  @override
  String get healthDataSettingsTypeBmiTitle => 'BMI';

  @override
  String get healthDataSettingsTypeBmiSubtitle => '身体质量指数';

  @override
  String get healthDataSettingsTypeBloodGlucoseTitle => '血糖';

  @override
  String get healthDataSettingsTypeBloodGlucoseSubtitle => '血糖样本';

  @override
  String get assistantEditLocalToolRemindersQueryTitle => '查询提醒';

  @override
  String get assistantEditLocalToolRemindersQuerySubtitle =>
      '读取本设备上的提醒事项，需要授予提醒事项完整访问权限。';

  @override
  String get assistantEditLocalToolRemindersCreateTitle => '创建提醒';

  @override
  String get assistantEditLocalToolRemindersCreateSubtitle =>
      '在你确认后于本设备创建提醒事项，需要授予提醒事项完整访问权限。';

  @override
  String get assistantEditLocalToolRemindersCompleteTitle => '完成提醒';

  @override
  String get assistantEditLocalToolRemindersCompleteSubtitle =>
      '在你确认后将提醒事项标记为完成，需要授予提醒事项完整访问权限。';

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
  String get settingsPageAutoRetry => '自动重试';

  @override
  String get autoRetryEnableLabel => '开启自动重试';

  @override
  String get autoRetryMaxRetries => '最大重试次数';

  @override
  String get autoRetryInitialDelay => '首次延迟（毫秒）';

  @override
  String get autoRetryMultiplier => '退避倍率';

  @override
  String get autoRetryMaxDelay => '最大延迟（毫秒）';

  @override
  String get autoRetryJitter => '抖动';

  @override
  String get autoRetryJitterSubtitle => '每次等待随机 ±20%';

  @override
  String get autoRetryOnNetworkError => '网络错误时重试';

  @override
  String get autoRetryStatusCodes => '可重试状态码';

  @override
  String get autoRetryKeywords => '重试关键字';

  @override
  String get autoRetryStopKeywords => '停止重试关键字';

  @override
  String get autoRetryAddHint => '添加';

  @override
  String get autoRetryRestoreDefaults => '恢复默认';

  @override
  String get autoRetryFooter => '仅在当前这轮模型响应尚未产生任何输出时才会自动重试。';

  @override
  String autoRetryCountdown(int seconds, int attempt, int maxRetries) {
    return '$seconds 秒后重试 ($attempt/$maxRetries)';
  }

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
      '此限制仅适用于未选择全量注入的类型。某一类型的记忆超过该条数时，只注入最近的若干条，其余由模型用 memory_search_profile 按需查询。调大更全面但更费 token。若你改过规则提示词，请一并更新或恢复默认。';

  @override
  String get memorySettingsFullInjectionTypesTitle => '全量注入类型';

  @override
  String get memorySettingsFullInjectionTypesSubtitle =>
      '可多选。选中类型会注入全局及当前助手的全部有效记忆，不受条数限制，会增加上下文和 token 消耗。';

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
  String worldBookImportUnsupportedEntries(int count) {
    return '导入完成。$count 个条目使用了暂不支持的酒馆功能（如宏、正则、时效、筛选或插入规则），已保留内容并停用，请检查后再启用。';
  }

  @override
  String get worldBookInjectionRoleUser => '用户';

  @override
  String get worldBookInjectionRoleAssistant => '助手';

  @override
  String get mcpToolNeedsApproval => '需要审批';

  @override
  String get toolApprovalPending => '等待审批';

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
  String tokenDetailFirstToken(String value) {
    return '${value}s（首字）';
  }

  @override
  String tokenDetailTotalTokens(int count) {
    return '$count tokens';
  }

  @override
  String tokenDetailReasoningTokens(int count) {
    return '$count tokens';
  }

  @override
  String tokenDetailCacheWriteTokens(int count) {
    return '$count 缓存写入 tokens';
  }

  @override
  String tokenDetailCost(String amount) {
    return '$amount';
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
  String get migrationStartWithoutBackupButton => '不备份，直接迁移';

  @override
  String get migrationSkipChatsJsonOption => '跳过 chats.json';

  @override
  String get migrationSkipChatsJsonDescription =>
      '仍会备份原始 Hive、设置和本地文件，超大聊天记录建议选择。';

  @override
  String get migrationSkipBackupOption => '跳过本次备份';

  @override
  String get migrationSkipBackupDescription => '仅在已有并确认备份可用时选择，之后将立即开始迁移。';

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
  String get migrationFailedSubtitle =>
      '原始 Hive 数据仍然保留；如果备份已经完成，备份文件也不会被修改。查看下方原因后可以重试。';

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
  String get imageSettingsPageSendSectionTitle => '发送';

  @override
  String get imageSettingsPageMarkdownImageLinksTitle =>
      '将 Markdown 图片链接作为图片发送';

  @override
  String get imageSettingsPageMarkdownImageLinksSubtitle =>
      '开启后，消息文本中的 ![alt](url) 会作为图片发送给视觉模型；关闭后仅作为普通文本发送。手动添加的图片附件不受影响。';

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
  String get messageStyleSettingsPageAssistantFitContent => '助手气泡贴合内容';

  @override
  String get messageStyleSettingsPageAssistantFitContentSubtitle =>
      '助手气泡按文字宽度收缩，不再占满整行';

  @override
  String get messageStyleSettingsPageAssistantSplitParagraphs => '分段显示为多个气泡';

  @override
  String get messageStyleSettingsPageAssistantSplitParagraphsSubtitle =>
      '助手回复遇到空行时拆分，每段单独一个气泡';

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

  @override
  String get localSnapshotSectionTitle => '本地副本';

  @override
  String get localSnapshotEnabledTitle => '保留本地副本';

  @override
  String get localSnapshotEnabledSubtitle => 'Kelivo 会定期在本机存一份数据库副本，让数据不只有一份。';

  @override
  String get localSnapshotIntervalTitle => '备份频率';

  @override
  String get localSnapshotIntervalAutomatic => '自动';

  @override
  String get localSnapshotIntervalAutomaticDetail => '每天一次，数据库越大间隔越长';

  @override
  String localSnapshotIntervalDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '每 $days 天',
      one: '每天',
    );
    return '$_temp0';
  }

  @override
  String get localSnapshotKeepTitle => '保留份数';

  @override
  String localSnapshotKeepValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 份',
    );
    return '$_temp0';
  }

  @override
  String get localSnapshotKeepSubtitle => '另外各留一份上周和上个月的，万一问题过了很久才发现也还能找回来。';

  @override
  String get localSnapshotKeepWeekly => '保留一份上周的';

  @override
  String get localSnapshotKeepMonthly => '保留一份上个月的';

  @override
  String get localSnapshotKeepProtectedNote => '无论设成几份，最近一份仍有内容的副本都不会被自动清理。';

  @override
  String get localSnapshotMaximumTitle => '占用上限';

  @override
  String get localSnapshotMaximumUnlimited => '不限制';

  @override
  String get localSnapshotAnnounceTitle => '备份完成时提示';

  @override
  String get localSnapshotAnnounceSubtitle => '失败一定会告诉你。这里只是成功时多一句提示。';

  @override
  String get localSnapshotTakeNow => '立即备份一份';

  @override
  String get localSnapshotManageCopies => '管理副本';

  @override
  String localSnapshotUsage(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 份',
      zero: '暂无副本',
    );
    return '$_temp0 · $size';
  }

  @override
  String get localSnapshotStatusNever => '还没有备份过';

  @override
  String localSnapshotStatusSuccess(String when) {
    return '上次备份：$when';
  }

  @override
  String localSnapshotStatusFailure(String when, String reason) {
    return '上次备份失败（$when）：$reason';
  }

  @override
  String get localSnapshotStatusSkippedSpace => '已跳过：本机剩余空间不足';

  @override
  String get localSnapshotStatusUnchanged => '距上次备份数据没有变化';

  @override
  String get localSnapshotCopiesTitle => '本地副本';

  @override
  String get localSnapshotCopiesEmpty => '还没有本地副本';

  @override
  String get localSnapshotCopiesEmptyHint => '数据有变化时会自动存一份，恢复数据前也一定会先存一份。';

  @override
  String get localSnapshotCopiesScopeNote =>
      '本地副本只存在这台设备上。它防的是应用内数据被损坏或误删，防不了设备丢失或卸载应用——那要靠 WebDAV / S3 备份。';

  @override
  String get localSnapshotOriginAutomatic => '自动备份';

  @override
  String get localSnapshotOriginManual => '手动备份';

  @override
  String get localSnapshotOriginBeforeRestore => '恢复前备份';

  @override
  String get localSnapshotKindRecovered => '故障恢复时留下的';

  @override
  String localSnapshotCopyContents(int conversations, int messages) {
    String _temp0 = intl.Intl.pluralLogic(
      conversations,
      locale: localeName,
      other: '$conversations 个对话',
    );
    String _temp1 = intl.Intl.pluralLogic(
      messages,
      locale: localeName,
      other: '$messages 条消息',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get localSnapshotCopyContentsUnknown => '内容需恢复后才能确认';

  @override
  String get localSnapshotCopyPinned => '已保留';

  @override
  String get localSnapshotActionRestore => '恢复';

  @override
  String get localSnapshotActionExport => '导出';

  @override
  String get localSnapshotActionDelete => '删除';

  @override
  String get localSnapshotActionPin => '保留这份';

  @override
  String get localSnapshotActionUnpin => '取消保留';

  @override
  String get localSnapshotRestoreTitle => '恢复这份副本？';

  @override
  String localSnapshotRestoreMessage(String when) {
    return '当前聊天和设置将替换为 $when 的副本。替换前会保存当前聊天和设置的副本。未发送的草稿不包含在副本中，此次恢复会清除这些草稿。';
  }

  @override
  String get localSnapshotRestorePreparing => '正在准备副本';

  @override
  String get localSnapshotDeleteTitle => '删除这份副本？';

  @override
  String get localSnapshotDeleteMessage =>
      '这份副本会从设备上永久删除。它里面有、而当前数据库里没有的数据将无法找回。';

  @override
  String get localSnapshotDeleteLastWarning => '这是唯一一份还有内容的副本。';

  @override
  String get localSnapshotExportPreparing => '正在准备导出';

  @override
  String get localSnapshotExportDone => '副本已导出';

  @override
  String localSnapshotExportFailed(String reason) {
    return '导出副本失败：$reason';
  }

  @override
  String get localSnapshotTakeDone => '副本已保存';

  @override
  String localSnapshotTakeFailed(String reason) {
    return '保存副本失败：$reason';
  }

  @override
  String get localSnapshotDeleteDone => '副本已删除';

  @override
  String get localSnapshotBusyMessage => '已有备份任务在进行中';

  @override
  String get localSnapshotRunInBackground => '转到后台继续';

  @override
  String get localSnapshotRunningInBackground => '正在后台备份副本';

  @override
  String startupRecoveryLocalCopiesAvailable(int count, String when) {
    return '本机还保留着 $count 份本地副本，最新一份是 $when 的。重置不会删除它们——重启后可以在 设置 › 备份 › 本地副本 里恢复。';
  }

  @override
  String startupRecoveryRecoveredCopiesDeleted(int count) {
    return '另外还有 $count 份故障恢复时留下的数据库副本，重置会把它们一并永久删除。想留住的话请先导出数据。';
  }

  @override
  String get toolSchemaSettingsPageTitle => '工具描述';

  @override
  String get toolSchemaSettingsGroupSearch => '搜索';

  @override
  String get toolSchemaSettingsGroupMemory => '记忆';

  @override
  String get toolSchemaSettingsGroupLocal => '本地工具';

  @override
  String get toolSchemaSettingsModified => '已修改';

  @override
  String get toolSchemaSettingsResetDefault => '恢复默认';

  @override
  String get toolSchemaSettingsResetAll => '全部恢复默认';

  @override
  String get toolSchemaSettingsResetAllTitle => '全部恢复默认？';

  @override
  String get toolSchemaSettingsResetAllMessage =>
      '将把所有内置工具的描述恢复为应用默认文案，自定义措辞会丢失。';

  @override
  String get toolSchemaSettingsResetAllConfirm => '恢复';

  @override
  String toolSchemaSettingsParamDescriptions(int count) {
    return '参数描述 ($count)';
  }

  @override
  String get toolSchemaSettingsMemoryLangNote =>
      '记忆工具的默认描述会随记忆提示语言在中/英之间切换。自定义描述按工具名只存一份，切换语言后不会跟着变。';

  @override
  String get toolSchemaSettingsDescriptionLabel => '描述';

  @override
  String get toolSchemaSettingsToolName => '工具名';

  @override
  String get toolSchemaEditorPageTitle => '编辑描述';

  @override
  String get toolSchemaSettingsCancel => '取消';

  @override
  String get workspaceFileNotAvailable => '文件不可用';

  @override
  String get workspaceTerminalNotAvailable => '终端不可用';

  @override
  String get workspacePreviewCopyPath => '复制路径';

  @override
  String get workspacePreviewShare => '分享';

  @override
  String get workspacePreviewOpenExternally => '用其他应用打开';

  @override
  String get workspacePreviewOpenWith => '打开方式…';

  @override
  String get workspacePreviewFileTooLarge => '文件过大，无法预览，请用其他应用打开。';

  @override
  String get workspacePreviewSource => '源码';

  @override
  String get workspacePreviewRendered => '渲染';

  @override
  String get workspacePreviewFileName => '名称';

  @override
  String get workspacePreviewFileSize => '大小';

  @override
  String get workspacePreviewFileModified => '修改时间';

  @override
  String get workspacePreviewPathCopied => '已复制路径';

  @override
  String workspacePreviewLineCount(int count) {
    return '$count 行';
  }

  @override
  String get workspaceFilesSort => '排序';

  @override
  String get workspaceFilesSortName => '名称';

  @override
  String get workspaceFilesSortModified => '修改时间';

  @override
  String get workspaceFilesSortSize => '大小';

  @override
  String get workspaceFilesSortAscending => '升序';

  @override
  String get workspaceFilesSortDescending => '降序';

  @override
  String get workspaceFilesShowHidden => '显示隐藏文件';

  @override
  String get workspaceFilesHideHidden => '隐藏隐藏文件';

  @override
  String get workspaceFilesRefresh => '刷新';

  @override
  String get workspaceFilesNewFolder => '新建文件夹';

  @override
  String get workspaceFilesNewFile => '新建文件';

  @override
  String get workspaceFilesImport => '导入';

  @override
  String get workspaceFilesExport => '导出';

  @override
  String get workspaceFilesExportFolder => '导出当前文件夹';

  @override
  String get workspaceFilesEmpty => '此文件夹为空';

  @override
  String get workspaceFilesError => '无法加载这些文件';

  @override
  String get workspaceFilesRetry => '重试';

  @override
  String get workspaceFilesPreview => '预览';

  @override
  String get workspaceFilesRename => '重命名';

  @override
  String get workspaceFilesMove => '移动';

  @override
  String get workspaceFilesDelete => '删除';

  @override
  String get workspaceFilesShare => '分享';

  @override
  String get workspaceFilesCopyPath => '复制路径';

  @override
  String get workspaceFilesExportItem => '导出';

  @override
  String get workspaceFilesNameLabel => '名称';

  @override
  String get workspaceFilesNameHint => '输入名称';

  @override
  String get workspaceFilesCreate => '创建';

  @override
  String get workspaceFilesCancel => '取消';

  @override
  String get workspaceFilesConfirm => '确认';

  @override
  String get workspaceFilesSave => '保存';

  @override
  String get workspaceFilesDeleteTitle => '删除此项？';

  @override
  String workspaceFilesDeleteMessage(String name) {
    return '删除 $name？';
  }

  @override
  String workspaceFilesDeleteFolderMessage(String name) {
    return '删除文件夹 $name 及其全部内容？';
  }

  @override
  String get workspaceFilesMoveTitle => '移动到文件夹';

  @override
  String get workspaceFilesMoveHere => '移动到此处';

  @override
  String get workspaceFilesPathCopied => '已复制路径';

  @override
  String get workspaceFilesInvalidName => '名称无效';

  @override
  String get workspaceFilesInvalidPath => '该路径超出当前文件夹';

  @override
  String workspaceFilesOperationFailed(String error) {
    return '操作失败：$error';
  }

  @override
  String get workspaceFilesActions => '操作';

  @override
  String get workspaceFilesMore => '更多';

  @override
  String get workspaceFilesJustNow => '刚刚';

  @override
  String workspaceFilesMinutesAgo(int count) {
    return '$count 分钟前';
  }

  @override
  String workspaceFilesHoursAgo(int count) {
    return '$count 小时前';
  }

  @override
  String workspaceFilesDaysAgo(int count) {
    return '$count 天前';
  }

  @override
  String get workspaceFilesPanelTitle => '对话文件';

  @override
  String get workspaceFilesTabAttachments => '附件';

  @override
  String get workspaceFilesTabOutputs => '输出';

  @override
  String get workspaceFilesTabWorkspace => '工作区';

  @override
  String get workspaceFilesNoWorkspaceBound => '尚未绑定工作区';

  @override
  String get workspaceFilesKindManaged => '托管';

  @override
  String get workspaceFilesKindLinked => '链接';

  @override
  String get workspaceFilesMissingWorkspace => '找不到工作区';

  @override
  String get workspaceFilesClose => '关闭';

  @override
  String get workspacesTitle => '工作区';

  @override
  String get workspacesCreate => '创建';

  @override
  String get workspacesCreateTitle => '新建工作区';

  @override
  String get workspacesNameLabel => '名称';

  @override
  String get workspacesNameHint => '工作区名称';

  @override
  String get workspacesLinkFolder => '链接文件夹';

  @override
  String get workspacesEmpty => '还没有工作区';

  @override
  String get workspacesEmptyCta => '创建工作区';

  @override
  String get workspacesSettings => '设置';

  @override
  String get workspacesOpenFiles => '打开文件';

  @override
  String get workspacesLastUsedNever => '从未使用';

  @override
  String workspacesLastUsed(String when) {
    return '最近使用 $when';
  }

  @override
  String get workspacesDeleteTitle => '删除此工作区？';

  @override
  String workspacesDeleteMessage(String name) {
    return '删除工作区 $name？';
  }

  @override
  String get workspacesDeleteAlsoFiles => '同时删除文件';

  @override
  String get workspacesUnlinkTitle => '取消链接此工作区？';

  @override
  String workspacesUnlinkMessage(String name) {
    return '取消链接 $name？磁盘上的文件会保留。';
  }

  @override
  String get workspacesSettingsTitle => '工作区设置';

  @override
  String get workspacesShellNeedsApproval => '运行终端命令前询问';

  @override
  String get workspacesDefaultCwd => '默认工作目录';

  @override
  String get workspacesDefaultCwdHint => '相对路径，例如 src';

  @override
  String get workspacesDefaultCwdInvalid => '请使用不含 .. 的相对路径';

  @override
  String get workspacesCreateManaged => '创建工作区';

  @override
  String get workspacesLinkExisting => '链接已有文件夹';

  @override
  String get workspacesUnlink => '取消链接';

  @override
  String get workspacesItemMore => '工作区操作';

  @override
  String get workspaceToolDenied => '已拒绝';

  @override
  String get workspaceToolTimeout => '超时';

  @override
  String get workspaceToolCancelled => '已取消';

  @override
  String get workspaceToolInterrupted => '已中断';

  @override
  String get workspaceToolEnvironmentNotReady => '沙箱环境未安装';

  @override
  String get workspaceToolInstall => '安装';

  @override
  String get workspaceToolFuzzy => '模糊';

  @override
  String get workspaceToolCreated => '已创建';

  @override
  String get workspaceToolUpdated => '已更新';

  @override
  String get workspaceToolTruncated => '已截断';

  @override
  String get workspaceToolImageTag => '图片';

  @override
  String get workspaceToolStdout => 'stdout';

  @override
  String get workspaceToolStderr => 'stderr';

  @override
  String get workspaceToolOpenFullOutput => '打开完整输出';

  @override
  String get workspaceToolChangedFiles => '变更的文件';

  @override
  String get workspaceToolCancel => '取消';

  @override
  String get workspaceToolCopyCommand => '复制命令';

  @override
  String get workspaceToolCopyOutput => '复制输出';

  @override
  String get workspaceToolCopyDiff => '复制差异';

  @override
  String get workspaceToolCopied => '已复制';

  @override
  String get workspaceToolDiffTruncated => '差异已截断';

  @override
  String get workspaceToolOpenPreview => '打开预览';

  @override
  String get workspaceToolNoOutput => '无输出';

  @override
  String get workspaceToolNotAvailable => '不可用';

  @override
  String get workspaceToolClose => '关闭';

  @override
  String get workspaceToolTitleShell => '运行命令';

  @override
  String get workspaceToolTitleReadFile => '读取文件';

  @override
  String get workspaceToolTitleViewImage => '查看图片';

  @override
  String get workspaceToolTitleWriteFile => '写入文件';

  @override
  String get workspaceToolTitleEditFile => '编辑文件';

  @override
  String get workspaceToolTitleListDir => '列出目录';

  @override
  String get workspaceToolTitleGlob => 'Glob';

  @override
  String get workspaceToolTitleGrep => 'Grep';

  @override
  String workspaceToolCount(int count) {
    return '$count';
  }

  @override
  String workspaceToolMoreFiles(int count) {
    return '+$count';
  }

  @override
  String workspaceToolDurationMs(int ms) {
    return '${ms}ms';
  }

  @override
  String workspaceToolDurationSec(String sec) {
    return '${sec}s';
  }

  @override
  String get workspaceEnvTitle => '环境';

  @override
  String workspaceEnvEngineUbuntu(String version) {
    return 'Ubuntu $version (PRoot)';
  }

  @override
  String workspaceEnvEngineAlpine(String version) {
    return 'Alpine $version (iSH)';
  }

  @override
  String get workspaceEnvEngineNative => '系统终端';

  @override
  String get workspaceEnvPhaseNotInstalled => '未安装';

  @override
  String get workspaceEnvPhaseDownloading => '下载中';

  @override
  String get workspaceEnvPhaseVerifying => '校验中';

  @override
  String get workspaceEnvPhaseExtracting => '解压中';

  @override
  String get workspaceEnvPhasePatching => '配置中';

  @override
  String get workspaceEnvPhaseReady => '就绪';

  @override
  String get workspaceEnvPhaseError => '错误';

  @override
  String get workspaceEnvPhaseNeedsRestart => '需要重启';

  @override
  String workspaceEnvMetaLine(String version, String arch) {
    return '$version · $arch';
  }

  @override
  String workspaceEnvInstalledAt(String date) {
    return '安装于 $date';
  }

  @override
  String workspaceEnvDiskUsage(String size) {
    return '占用空间 $size';
  }

  @override
  String workspaceEnvRuntimeReason(String reason) {
    return '$reason';
  }

  @override
  String get workspaceEnvInstall => '安装';

  @override
  String get workspaceEnvInstallSubtitleAndroid =>
      '可选择 Ubuntu、Alpine、Debian，也可导入本地 rootfs 镜像。';

  @override
  String get workspaceEnvInstallSubtitleIos => '已内置，无需下载';

  @override
  String get workspaceEnvCancel => '取消';

  @override
  String get workspaceEnvRetry => '重试';

  @override
  String get workspaceEnvRepair => '修复';

  @override
  String get workspaceEnvReset => '重置';

  @override
  String get workspaceEnvResetConfirmTitle => '重置环境？';

  @override
  String get workspaceEnvResetConfirmBody => '这将删除已安装的软件包和沙箱文件系统。';

  @override
  String get workspaceEnvCheckForUpdate => '检查更新';

  @override
  String get workspaceEnvUpdate => '更新';

  @override
  String workspaceEnvAvailableVersion(String version) {
    return '新版本 $version 可用';
  }

  @override
  String get workspaceEnvUpToDate => '已是最新';

  @override
  String get workspaceEnvRestartBanner => '请重启 Kelivo 以完成安装';

  @override
  String get workspaceEnvDetectingMirrors => '正在检测最快镜像…';

  @override
  String workspaceEnvApplyingMirror(String category) {
    return '正在应用 $category 镜像…';
  }

  @override
  String get workspaceEnvMirrorsSection => '镜像';

  @override
  String get workspaceEnvUseMirror => '使用镜像';

  @override
  String get workspaceEnvDetect => '测速';

  @override
  String get workspaceEnvOfficial => '官方';

  @override
  String get workspaceEnvMirrorsDisabled => '镜像设置在沙箱中执行，就绪后才能更改。';

  @override
  String workspaceEnvMirrorsDisabledReason(String reason) {
    return '镜像设置在沙箱中执行，当前不可用：$reason';
  }

  @override
  String get workspaceEnvMirrorDetectTitle => '镜像测速';

  @override
  String workspaceEnvMirrorLatency(int ms) {
    return '$ms ms';
  }

  @override
  String workspaceEnvMirrorFailed(String reason) {
    return '$reason';
  }

  @override
  String get workspaceEnvErrorUnsupportedAbi => '当前设备架构不受支持。';

  @override
  String get workspaceEnvErrorArchitectureMismatch =>
      '已安装的沙盒架构与当前应用不匹配，请重新安装沙盒后使用。原沙盒文件已保留。';

  @override
  String get workspaceEnvErrorProotMissing => '缺少 PRoot 可执行文件。';

  @override
  String get workspaceEnvErrorInsufficientDisk => '存储空间不足，无法安装沙箱。';

  @override
  String get workspaceEnvErrorInsufficientDiskHint => '请为所选镜像释放更多存储空间后重试。';

  @override
  String get workspaceEnvErrorNetwork => '下载失败，请检查网络后重试。';

  @override
  String get workspaceEnvErrorChecksumMismatch => '下载文件已损坏，请重试。';

  @override
  String get workspaceEnvErrorExtractFailed => '无法解压沙箱镜像。';

  @override
  String get workspaceEnvErrorCleanupFailed => '无法清理旧沙箱文件，请重试。';

  @override
  String get workspaceEnvCleanupIncomplete => '沙箱已就绪，但部分旧文件未能清理，仍占用存储空间。';

  @override
  String get workspaceEnvErrorResetFailed => '未能完成沙箱重置，请重试。';

  @override
  String get workspaceEnvErrorPatchFailed => '无法完成沙箱配置。';

  @override
  String get workspaceEnvErrorCancelled => '安装已取消。';

  @override
  String get workspaceEnvErrorGeneric => '安装沙箱时出错。';

  @override
  String get workspaceEnvChipInstall => '安装沙箱';

  @override
  String workspaceEnvChipInstalling(int percent) {
    return '正在安装… $percent %';
  }

  @override
  String get workspaceEnvChipInstallingIndeterminate => '正在安装…';

  @override
  String get workspaceEnvChipError => '沙箱错误';

  @override
  String get workspaceEnvChipRestart => '需要重启';

  @override
  String get workspaceEnvNativeExplanation =>
      '在桌面端，Kelivo 使用系统终端，而不是 Linux 沙箱。';

  @override
  String workspaceEnvNativeShellPath(String path) {
    return '终端：$path';
  }

  @override
  String get workspaceEnvNativeShellApproval => '请求批准模式下，Shell 工具需要批准。';

  @override
  String workspaceEnvDownloadProgress(
    String downloaded,
    String total,
    int percent,
  ) {
    return '$downloaded / $total MB ($percent%)';
  }

  @override
  String get workspaceEnvMirrorsFailed => '无法检测镜像';

  @override
  String get workspaceEnvCategoryApt => 'APT';

  @override
  String get workspaceEnvCategoryApk => 'APK';

  @override
  String get workspaceEnvCategoryPip => 'pip';

  @override
  String get workspaceEnvCategoryNpm => 'npm';

  @override
  String get skillsTitle => '技能';

  @override
  String get skillsTab => '技能';

  @override
  String get skillsSearchHint => '搜索技能';

  @override
  String get skillsEmptyTitle => '还没有技能';

  @override
  String get skillsEmptyBody =>
      '技能是包含 SKILL.md 的文件夹。可粘贴 Markdown、导入 .md/.zip，或从 GitHub 安装。';

  @override
  String get skillsEmptyFormat =>
      '---\nname: my-skill\ndescription: 这个技能做什么\n---\n\n# 说明';

  @override
  String get skillsImport => '导入';

  @override
  String get skillsImportPaste => '粘贴 Markdown';

  @override
  String get skillsImportFile => '从文件';

  @override
  String get skillsImportGitHub => '从 GitHub';

  @override
  String get skillsImportPasteLabel => 'SKILL.md';

  @override
  String get skillsImportPasteHint => '粘贴带 YAML 前置元数据的 SKILL.md';

  @override
  String get skillsImportGitHubLabel => 'GitHub 链接';

  @override
  String get skillsImportGitHubHint =>
      'github.com/owner/repo 或 github.com/owner/repo/tree/ref/path';

  @override
  String get skillsImportConfirm => '导入';

  @override
  String get skillsCancel => '取消';

  @override
  String get skillsSave => '保存';

  @override
  String skillsUsedCount(int count) {
    return '已使用 $count 次';
  }

  @override
  String get skillsEnabled => '启用';

  @override
  String get skillsBrowseFiles => '浏览文件';

  @override
  String get skillsEdit => '编辑';

  @override
  String get skillsExport => '导出';

  @override
  String get skillsDelete => '删除';

  @override
  String get skillsDeleteTitle => '删除此技能？';

  @override
  String skillsDeleteMessage(String name) {
    return '删除 $name？此操作无法撤销。';
  }

  @override
  String get skillsUseAll => '使用全部技能';

  @override
  String get skillsUseAllSubtitle => '此助手可以使用所有已启用的技能。';

  @override
  String get skillsDisabledHint => '请先在技能页启用此技能。';

  @override
  String get skillsOpenPage => '管理技能';

  @override
  String get skillsInheritAssistant => '跟随助手';

  @override
  String get skillsInheritAssistantSubtitle => '使用与此对话助手相同的技能。';

  @override
  String get skillsActiveLabel => '生效中';

  @override
  String get skillsSessionTitle => '此对话的技能';

  @override
  String get skillsEditTitle => '编辑技能';

  @override
  String get skillsDetailKindLabel => 'Skill';

  @override
  String get skillsNoEnabled => '没有已启用的技能';

  @override
  String get terminalTitle => '终端';

  @override
  String get terminalOpenInSystem => '在系统终端中打开';

  @override
  String get terminalHostDirectory => '主机目录';

  @override
  String get terminalBindWorkspaceFirst => '请先绑定工作区';

  @override
  String get terminalNotAvailable => '不可用';

  @override
  String get terminalRuntimeUnavailable => '终端环境尚未就绪';

  @override
  String get terminalRename => '重命名';

  @override
  String get terminalClose => '关闭';

  @override
  String get terminalClear => '清屏';

  @override
  String get terminalCloseSession => '关闭会话';

  @override
  String get terminalCopy => '复制';

  @override
  String get terminalPaste => '粘贴';

  @override
  String get terminalNewSession => '新建会话';

  @override
  String get terminalMore => '更多';

  @override
  String get terminalNameLabel => '名称';

  @override
  String get terminalCancel => '取消';

  @override
  String get terminalSave => '保存';

  @override
  String get workspaceDeskMenuWorkspace => '工作区';

  @override
  String get workspaceDeskMenuSkills => '技能';

  @override
  String get workspaceDeskBarTitle => '工作区';

  @override
  String get workspaceDeskBarNoWorkspace => '无工作区';

  @override
  String get workspaceDeskBarEmptyHint => '从工具栏绑定工作区后即可在此浏览文件';

  @override
  String get workspaceDeskBarToggle => '工作区文件';

  @override
  String get workspaceDeskOpenSystemTerminal => '在系统终端中打开';

  @override
  String get workspaceDeskReveal => '在文件管理器中显示';

  @override
  String get workspaceDeskBarClose => '关闭工作区栏';

  @override
  String get workspaceEntryBind => '绑定工作区';

  @override
  String get workspaceEntryUnbind => '解除绑定';

  @override
  String get workspaceEntryChange => '更换';

  @override
  String get workspaceEntrySetAssistantDefault => '设为助手默认工作区';

  @override
  String get workspaceEntryLocked => '已锁定';

  @override
  String get workspaceEntryChangeConfirmTitle => '更换工作区？';

  @override
  String get workspaceEntryUnbindConfirmTitle => '解除绑定？';

  @override
  String get workspaceEntryChangeConfirmBody =>
      '此对话已使用过工作区工具，之前消息中的文件链接可能不再可用。';

  @override
  String get workspaceEntryCwd => '工作目录';

  @override
  String get workspaceEntryCwdHint => '相对于工作区根目录';

  @override
  String get workspaceEntryCwdInvalid => '路径无效或已超出工作区';

  @override
  String get workspaceEntryCwdMissing => '该目录不存在';

  @override
  String get workspaceEntryCwdCreate => '创建它';

  @override
  String get workspaceEntryFiles => '文件';

  @override
  String get workspaceEntryTerminal => '终端';

  @override
  String get workspaceEntryOpenSystemTerminal => '在系统终端中打开';

  @override
  String get workspaceEntryReveal => '在文件管理器中显示';

  @override
  String get workspaceEntrySessionSkills => '技能';

  @override
  String get workspaceEntryEnvironment => '环境';

  @override
  String get workspaceEntryManage => '管理工作区';

  @override
  String get workspaceEntryCreate => '新建工作区…';

  @override
  String get workspaceEntryDefaultWorkspace => '默认工作区';

  @override
  String get workspaceEntryDefaultWorkspaceSubtitle => '新建对话时自动绑定，已有对话不受影响。';

  @override
  String get workspaceEntryDefaultWorkspaceUnset => '未设置';

  @override
  String get workspaceEntryDefaultWorkspaceAutomaticSubtitle =>
      '首次为对话绑定工作区时，将记为此助手的默认工作区。';

  @override
  String workspaceBindingRememberedDefault(String assistant) {
    return '已记为「$assistant」的默认工作区，新对话将自动使用。';
  }

  @override
  String workspaceBindingSuggestDefault(String assistant) {
    return '以后与「$assistant」的新对话也使用这个工作区？';
  }

  @override
  String get workspaceBindingUndoDefault => '撤销';

  @override
  String get workspaceBindingUseAsDefault => '设为默认';

  @override
  String get workspaceEntryNone => '无';

  @override
  String get workspaceEntryStartConversationFirst => '请先开始对话';

  @override
  String get workspaceEntryTooltip => '工作区';

  @override
  String get workspaceEntryPickerTitle => '选择工作区';

  @override
  String get settingsPageWorkspace => '工作区与环境';

  @override
  String get settingsPageSkills => '技能';

  @override
  String get commonClose => '关闭';

  @override
  String get terminalCopyAllOutput => '复制全部输出';

  @override
  String get terminalFontDecrease => '字号 −';

  @override
  String get terminalFontIncrease => '字号 +';

  @override
  String get terminalCloseSessionConfirmMessage => '会话仍在运行。关闭将结束该进程。';

  @override
  String get terminalCopiedAll => '已复制全部输出';

  @override
  String get terminalConfirm => '确认';

  @override
  String terminalExitCode(int code) {
    return 'exit $code';
  }

  @override
  String get workspaceMgmtNewWorkspace => '新建工作区';

  @override
  String get workspaceMgmtEmptyHint => '新建一个工作区来存放项目文件和工作目录。';

  @override
  String get workspaceMgmtKindManagedTitle => '托管工作区';

  @override
  String get workspaceMgmtKindManagedSubtitle => '应用内目录，沙盒可读写';

  @override
  String get workspaceMgmtKindLinkedTitle => '链接文件夹';

  @override
  String get workspaceMgmtKindLinkedSubtitle => '直接使用本机文件夹';

  @override
  String get workspaceMgmtImportFromFolder => '从文件夹导入';

  @override
  String get workspaceMgmtImportFromFolderSubtitle => '将文件夹复制到新的托管工作区';

  @override
  String get workspaceMgmtKindSection => '类型';

  @override
  String get workspaceMgmtCreate => '创建';

  @override
  String get workspaceMgmtShellApprovalSubtitle => '每次运行命令前询问';

  @override
  String get workspaceMgmtDefaultCwdRoot => '/';

  @override
  String get workspaceMgmtPickCwdTitle => '默认工作目录';

  @override
  String get workspaceMgmtFolderPickerUnavailable => '此设备不支持选择文件夹。';

  @override
  String get workspaceMgmtImportProgressTitle => '正在导入文件夹';

  @override
  String get workspaceMgmtImportProgressPhase => '正在复制文件…';

  @override
  String get workspaceMgmtImportFailed => '无法导入该文件夹。';

  @override
  String workspaceMgmtImportDone(String name) {
    return '已导入 $name';
  }

  @override
  String get workspaceMgmtLastUsedJustNow => '刚刚';

  @override
  String workspaceMgmtLastUsedMinutesAgo(int n) {
    return '$n 分钟前';
  }

  @override
  String workspaceMgmtLastUsedHoursAgo(int n) {
    return '$n 小时前';
  }

  @override
  String workspaceMgmtLastUsedDaysAgo(int n) {
    return '$n 天前';
  }

  @override
  String workspaceMgmtRowDetail(String kind, String when) {
    return '$kind · 上次使用 $when';
  }

  @override
  String workspaceMgmtRowDetailNever(String kind) {
    return '$kind · 从未使用';
  }

  @override
  String get workspacePreviewBack => '返回';

  @override
  String get workspacePreviewWrap => '自动换行';

  @override
  String get workspacePreviewFontDecrease => '减小字号';

  @override
  String get workspacePreviewFontIncrease => '增大字号';

  @override
  String get workspacePreviewCopy => '复制';

  @override
  String get workspacePreviewRetry => '重试';

  @override
  String get workspacePreviewLoadError => '无法加载此文件。';

  @override
  String get workspacePreviewRevealInFinder => '在 Finder 中显示';

  @override
  String get workspacePreviewOpenInSystemApp => '用系统应用打开';

  @override
  String get workspacePreviewOpenInBrowser => '在浏览器中打开';

  @override
  String get workspacePreviewTable => '表格';

  @override
  String get workspacePreviewPlainLanguage => '代码';

  @override
  String get workspacePreviewOpen => '打开';

  @override
  String get workspacePreviewRevealFailed => '无法在文件管理器中显示此文件。';

  @override
  String get workspacePreviewEmptyTable => '此表格为空。';

  @override
  String get workspaceFilesNew => '新建';

  @override
  String get workspaceFilesFoldersFirst => '文件夹优先';

  @override
  String get workspaceFilesSelectDirectory => '选择此目录';

  @override
  String get workspaceFilesEmptyHint => '用「新建」或「导入」添加文件';

  @override
  String get workspaceFilesEmptyAttachments => '还没有附件';

  @override
  String get workspaceFilesEmptyOutputs => '助手还没有产出文件';

  @override
  String get workspaceFilesMoveTo => '移动到…';

  @override
  String workspaceFilesItemCount(int count) {
    return '$count 项';
  }

  @override
  String get skillsImportTooltip => '导入技能';

  @override
  String get skillsImportPasteSubtitle => '粘贴带 frontmatter 的 SKILL.md';

  @override
  String get skillsImportFileSubtitle => '选择 .md 或 .zip 文件';

  @override
  String get skillsImportGitHubSubtitle => '从仓库导入 SKILL.md';

  @override
  String get skillsImportResolving => '正在解析仓库…';

  @override
  String get skillsImportDownloading => '正在下载…';

  @override
  String get skillsImportExtracting => '正在解压…';

  @override
  String get skillsImportInstalling => '正在安装…';

  @override
  String get skillsImportGitHubRepoLabel => '仓库地址';

  @override
  String get skillsImportGitHubUrlHint =>
      'https://github.com/owner/repo 或 owner/repo[/path]';

  @override
  String get skillsImportGitHubHelp => '支持仓库根目录或子目录下的 SKILL.md';

  @override
  String get skillsEmptyHint => '技能是带 frontmatter 的 SKILL.md，导入后助手可按需调用';

  @override
  String get skillsMoreActions => '更多';

  @override
  String get skillsSearchClear => '清除';

  @override
  String get skillsSessionEmpty => '还没有已启用的技能，请先在技能库中启用';

  @override
  String get workspaceToolRunning => '运行中';

  @override
  String workspaceToolExitCode(int code) {
    return 'exit $code';
  }

  @override
  String get workspaceToolAwaitingApproval => '等待批准';

  @override
  String get workspaceToolCompleted => '完成';

  @override
  String workspaceToolLines(int count) {
    return '$count 行';
  }

  @override
  String workspaceToolItems(int count) {
    return '$count 项';
  }

  @override
  String workspaceToolFileMatches(int count) {
    return '$count 个匹配';
  }

  @override
  String workspaceToolContentMatches(int count) {
    return '$count 处匹配';
  }

  @override
  String get workspaceToolExpand => '展开';

  @override
  String get workspaceToolSectionCommand => '命令';

  @override
  String get workspaceToolSectionPath => '路径';

  @override
  String get workspaceToolSectionPattern => '模式';

  @override
  String get workspaceToolSectionOutput => '输出';

  @override
  String get workspaceToolSectionDiff => '差异';

  @override
  String get workspaceToolSectionError => '错误';

  @override
  String get workspaceToolSavedOutput => '已保存完整输出';

  @override
  String get workspaceToolApprove => '允许';

  @override
  String get workspaceToolDeny => '拒绝';

  @override
  String get workspaceToolCopy => '复制';

  @override
  String get workspaceEnvEngineLocalShell => '本机 Shell';

  @override
  String get workspaceEnvInstallEnvironment => '安装环境';

  @override
  String get workspaceEnvInstallDescription => '安装 Linux 环境，以便在沙盒中运行工具。';

  @override
  String get workspaceEnvStatusLabel => '状态';

  @override
  String get workspaceEnvStatusInstalled => '已安装';

  @override
  String get workspaceEnvSizeLabel => '大小';

  @override
  String get workspaceEnvPathLabel => '路径';

  @override
  String get workspaceEnvInstalledAtLabel => '安装于';

  @override
  String get workspaceEnvArchLabel => '架构';

  @override
  String workspaceEnvArchVersion(String arch, String version) {
    return '$arch · $version';
  }

  @override
  String get workspaceEnvBrowseSection => '浏览';

  @override
  String get workspaceEnvBrowseFiles => '浏览文件系统';

  @override
  String get workspaceEnvBrowseFilesDetail => '查看沙盒中的完整目录';

  @override
  String get workspaceEnvDetectFastMirrors => '检测快速镜像';

  @override
  String get workspaceEnvActionsSection => '操作';

  @override
  String get workspaceEnvInfoSection => '信息';

  @override
  String get workspaceEnvInfoBody =>
      '环境是沙盒使用的 Linux 根文件系统。工作区单独存放，重置环境不会删除工作区文件。数据保存在本机已解压的 rootfs 中。';

  @override
  String get workspaceEnvRepairDetail => '重新校验并修补文件';

  @override
  String get workspaceEnvUpdateCurrent => '已是最新';

  @override
  String workspaceEnvUpdateAvailableShort(String version) {
    return '可更新到 $version';
  }

  @override
  String get workspaceEnvResetConfirmMessage =>
      '这将删除整个 Linux 环境及其中安装的软件包。工作区文件不受影响。';

  @override
  String get workspaceEnvRestartDoneBanner => '重置已完成，请重启应用以完成安装。';

  @override
  String get workspaceEnvPathCopied => '已复制路径';

  @override
  String get workspaceEnvUseMirrorSubtitle => '将所选镜像写入沙盒';

  @override
  String get workspaceEnvRegionGlobal => '全球';

  @override
  String get workspaceEnvRegionChina => '中国';

  @override
  String get workspaceEnvRegionEurope => '欧洲';

  @override
  String get workspaceEnvRegionAsia => '亚洲';

  @override
  String get workspaceEnvMirrorTimeout => '超时';

  @override
  String get workspaceEnvSpeedTest => '测速';

  @override
  String get workspaceEnvApplySuccess => '镜像已应用';

  @override
  String get workspaceEnvApplyFailed => '无法应用镜像';

  @override
  String get workspaceEnvRestoreSuccess => '已恢复官方源';

  @override
  String get workspaceEnvMirrorsTested => '已应用最快镜像';

  @override
  String get workspaceEnvRelativeJustNow => '刚刚';

  @override
  String workspaceEnvRelativeMinutesAgo(int count) {
    return '$count 分钟前';
  }

  @override
  String workspaceEnvRelativeHoursAgo(int count) {
    return '$count 小时前';
  }

  @override
  String workspaceEnvRelativeDaysAgo(int count) {
    return '$count 天前';
  }

  @override
  String workspaceEnvDownloadLine(
    String downloaded,
    String total,
    String phase,
  ) {
    return '$downloaded / $total · $phase';
  }

  @override
  String get workspaceEnvNativeUnsandboxed =>
      '命令在本机直接运行（无沙盒），除非此对话已启用完全访问，否则需要批准。';

  @override
  String get workspaceEnvRootfsTitle => '/';

  @override
  String get workspaceEnvBrowserUnavailable => '沙盒文件系统不可用。';

  @override
  String get workspaceEnvMirrorNameOfficial => '官方';

  @override
  String get workspaceEnvMirrorNameOfficialCdn => '官方 CDN';

  @override
  String get workspaceEnvMirrorNameOfficialPypi => '官方 PyPI';

  @override
  String get workspaceEnvMirrorNameOfficialNpm => '官方 npm';

  @override
  String get workspaceEnvMirrorNameTuna => '清华 TUNA';

  @override
  String get workspaceEnvMirrorNameAlibaba => '阿里云';

  @override
  String get workspaceEnvMirrorNameUstc => '中科大 USTC';

  @override
  String get workspaceEnvMirrorNameHuawei => '华为云';

  @override
  String get workspaceEnvMirrorNameTencent => '腾讯云';

  @override
  String get workspaceEnvMirrorNameNetease => '网易';

  @override
  String get workspaceEnvMirrorNameLeaseweb => 'LEASEWEB UK';

  @override
  String get workspaceEnvMirrorNameRwth => 'RWTH Germany';

  @override
  String get workspaceEnvMirrorNameJaist => 'JAIST Japan';

  @override
  String get workspaceEnvMirrorNameKakao => 'Kakao Korea';

  @override
  String get workspaceEnvMirrorNameNpmmirror => 'npmmirror';

  @override
  String workspaceEnvSelectionNamed(String name, String region) {
    return '$name · $region';
  }

  @override
  String get workspaceFilesEmptyPickerHint => '点「新建文件夹」添加子文件夹';

  @override
  String get skillsDetailBodyEmpty => '还没有技能正文';

  @override
  String skillsDetailBodyTooLarge(String size) {
    return '文件较大，暂不支持预览（$size）。';
  }

  @override
  String get workspaceEnvSizeTimeout => '计算超时';

  @override
  String get workspaceEnvInfoCopied => '已复制环境信息';

  @override
  String get workspacePreviewEmptyFile => '文件为空';

  @override
  String get workspacePreviewEmptyHint => '此文件没有任何可预览的内容。';

  @override
  String get workspacePreviewRevealInExplorer => '在文件资源管理器中显示';

  @override
  String get workspacePreviewRevealInFileManager => '在文件管理器中显示';

  @override
  String workspaceBindingSetAssistantDefault(String assistant) {
    return '已设为「$assistant」的默认工作区';
  }

  @override
  String get storageSpaceCategoryWorkspaceFiles => '工作区文件';

  @override
  String get storageSpaceCategoryWorkspaceFilesHint => '托管工作区中保存的文件。';

  @override
  String get storageSpaceCategorySandboxEnvironment => '沙箱环境';

  @override
  String get storageSpaceCategorySandboxEnvironmentHint => '沙箱安装目录与根文件系统。';

  @override
  String get storageSpaceCategorySkills => '技能';

  @override
  String get storageSpaceCategorySkillsHint => '已安装的技能文件。';

  @override
  String get storageSpaceCategorySessionFiles => '会话文件';

  @override
  String get storageSpaceCategorySessionFilesHint => '各对话的附件与输出。';

  @override
  String get storageSpaceManageSkills => '管理技能';

  @override
  String get storageSessionFilesCleanOrphans => '清理无对话的会话文件';

  @override
  String storageSessionFilesCleanOrphansHint(String size) {
    return '删除已无对应对话的会话目录。可回收 $size。';
  }

  @override
  String get workspaceDesktopFolderPath => '文件夹路径';

  @override
  String get workspaceDesktopFolderMissing => '请选择已存在的文件夹，或输入它的绝对路径。';

  @override
  String get workspaceDesktopManagedHint => '由 Kelivo 为此项目创建并管理文件夹。';

  @override
  String get workspaceDesktopHostHint => '在本机访问文件和执行命令。';

  @override
  String get workspaceDesktopSearch => '搜索工作区';

  @override
  String get workspaceDesktopNoResults => '没有匹配的工作区';

  @override
  String get workspaceEnvDependencies => '环境预设';

  @override
  String get workspaceEnvDependenciesDetail => '安装到共享沙盒，所有工作区均可使用。';

  @override
  String get workspaceEnvDependencyPython => 'Python、pip 和虚拟环境';

  @override
  String get workspaceEnvDependencyNode => 'Node.js 和 npm';

  @override
  String get workspaceEnvDependencyGit => '克隆仓库与版本管理';

  @override
  String get workspaceEnvDependencySsh => 'SSH、SCP、SFTP 与密钥生成';

  @override
  String get workspaceEnvDependencyNetwork => '网络工具';

  @override
  String get workspaceEnvDependencyArchive => '压缩工具';

  @override
  String get workspaceEnvDependencyInstalled => '已安装';

  @override
  String get workspaceEnvDependencyUnknown => '未检测';

  @override
  String get workspaceEnvDependencyChecking => '正在检测工具…';

  @override
  String get workspaceEnvDependencyInstalling => '正在安装…';

  @override
  String get workspaceEnvDependencyCheckFailed => '未能检测工具，请刷新重试。';

  @override
  String get workspaceEnvDependencyInstallFailed => '安装未完成，请查看日志或更换软件包源后重试。';

  @override
  String get workspaceEnvDependencyLog => '安装日志';

  @override
  String get workspaceEnvDependencyRefresh => '刷新工具状态';

  @override
  String get workspaceEnvDependencyReadyFirst => '请先安装沙盒环境，再安装这些工具。';

  @override
  String get workspaceEnvDependencySources => '软件包源';

  @override
  String get workspaceEnvDependencySourcesDetail =>
      '预设使用所选 apt/apk 源安装；pip 和 npm 源用于后续安装的软件包。';

  @override
  String get workspaceEnvDownloadSource => '沙盒下载源';

  @override
  String get workspaceEnvDownloadAutomatic => '自动选择最快源';

  @override
  String get workspaceEnvDownloadAutomaticDetail => '下载前检测官方源和内置镜像的速度。';

  @override
  String get workspaceEnvDownloadCustom => '自定义链接';

  @override
  String get workspaceEnvDownloadCustomHint =>
      'https://example.com/ubuntu-base/releases/24.04/release/';

  @override
  String get workspaceEnvDownloadCustomDetail =>
      '填写镜像目录或完整下载链接，镜像需匹配所选系统、版本及设备架构。';

  @override
  String get workspaceEnvDownloadInvalidUrl => '请输入有效的 HTTP 或 HTTPS 链接。';

  @override
  String get workspaceEnvDownloadVerified => '下载后会校验所选镜像的官方 SHA-256。软件包源可单独配置。';

  @override
  String get workspaceEnvDownloadStart => '下载并安装';

  @override
  String get workspaceEnvDownloadSave => '保存下载源';

  @override
  String get workspaceToolsTitle => '工具';

  @override
  String get workspaceToolsDescription => '选择此工作区的对话可以使用哪些工具，修改后自动保存。';

  @override
  String get workspaceToolHelpShell => '在工作区环境中执行命令。';

  @override
  String get workspaceToolHelpRead => '按行读取文件内容，支持分页。';

  @override
  String get workspaceToolHelpViewImage => '让模型查看工作区中的图片内容。';

  @override
  String get workspaceToolHelpWrite => '创建文件或覆盖文件内容。';

  @override
  String get workspaceToolHelpEdit => '替换已有文件中的指定文本。';

  @override
  String get workspaceToolHelpList => '浏览目录及其中的文件。';

  @override
  String get workspaceToolHelpGlob => '按文件名或路径模式查找文件。';

  @override
  String get workspaceToolHelpGrep => '搜索文件中的文本内容。';

  @override
  String get workspaceEnvVariablesTitle => '环境变量';

  @override
  String get workspaceEnvVariablesEntryDetail => '管理命令使用的变量与输出隐私';

  @override
  String get workspaceEnvVariablesEmpty => '还没有环境变量。可以添加工具需要的 API 密钥等配置。';

  @override
  String get workspaceEnvVariablesScope =>
      '所有工作区共用。修改会用于新的 Agent 命令和应用内终端会话，已有终端需重新打开。外部系统终端使用其自身的环境变量。';

  @override
  String get workspaceEnvPrivacyMode => '隐私模式';

  @override
  String get workspaceEnvPrivacyDetail =>
      '命令仍能使用真实值。工作区工具输出发给模型前，匹配到的至少 5 个字符的变量值会替换为 [REDACTED]，本地日志保留原文。较短的值不做遮蔽，以免误替换常见开关和数字。';

  @override
  String get workspaceEnvVariableAdd => '添加变量';

  @override
  String get workspaceEnvVariableEdit => '编辑变量';

  @override
  String get workspaceEnvVariableName => '名称';

  @override
  String get workspaceEnvVariableValue => '值';

  @override
  String get workspaceEnvVariableNote => '备注（可选）';

  @override
  String get workspaceEnvVariableNameHint =>
      '名称使用字母、数字和下划线，不能以数字开头，区分大小写。命令中可通过 \$NAME 使用变量。';

  @override
  String get workspaceEnvVariableInvalidName => '请输入有效的变量名称。';

  @override
  String get workspaceEnvVariableInvalidValue => '值不能为空，也不能包含空字符（NUL）。';

  @override
  String get workspaceEnvVariableDuplicate => '已存在同名变量。';

  @override
  String get workspaceEnvVariablesSaveFailed => '环境设置保存失败，请重试。';

  @override
  String get incomingShareTitle => '接收分享';

  @override
  String get incomingShareReplaceDraft => '输入框中有尚未发送的内容。是否替换为分享的内容，并开始新对话？';

  @override
  String get incomingShareFailed =>
      '部分分享内容未能导入，请检查文件访问权限和可用存储空间。一次最多分享 32 个文件。';

  @override
  String get incomingShareImporting => '正在导入';

  @override
  String get incomingShareMoveTo => '移动到…';

  @override
  String get incomingShareNewChat => '新对话';

  @override
  String get incomingShareMoveHint => '将草稿和附件移到其他对话，内容不会自动发送。';

  @override
  String get incomingShareNoConversations => '没有匹配的对话';

  @override
  String get chatInputBarRemoveAttachment => '移除附件';

  @override
  String get incomingShareMoveFailed => '无法切换对话，草稿已保留。';

  @override
  String attachmentRequiresWorkspace(String name) {
    return '「$name」无法在普通对话中直接读取。请绑定工作区并启用文件工具，或将草稿移到已有工作区的对话。';
  }

  @override
  String get storageSessionFilesUnlinked => '未关联的会话';

  @override
  String get workspaceExternalMount => '挂载外部文件夹';

  @override
  String get workspaceExternalMountSubtitle =>
      '所选文件夹挂载到 /mounts/<name>，供各工作区的 AI 工具、Shell 和文件浏览器访问。最多挂载 10 个文件夹。';

  @override
  String get workspaceExternalStorageTitle => '允许访问文件';

  @override
  String get workspaceExternalStorageMessage =>
      '工作区和 Shell 需要直接读写外部文件夹，请在 Android 系统设置中允许 Kelivo 访问文件。Android 11 及以上需开启“所有文件访问权限”，然后选择要挂载的本地文件夹。';

  @override
  String get workspaceExternalGrantAccess => '前往授权';

  @override
  String get workspaceExternalLocalOnly =>
      'Android 仅支持挂载本地文件夹，此文件提供方没有可供 Shell 访问的本地目录。';

  @override
  String get workspaceExternalUnavailable =>
      '外部文件夹不可用。请检查存储连接和访问权限，重新选择文件夹以恢复访问。';

  @override
  String get workspaceExternalReconnect => '重新选择文件夹';

  @override
  String get workspaceMountAdd => '添加文件夹';

  @override
  String get workspaceMountEdit => '编辑挂载';

  @override
  String get workspaceMountEmpty => '尚未挂载文件夹';

  @override
  String get workspaceMountReadOnly => '只读';

  @override
  String get workspaceMountReadWrite => '读写';

  @override
  String get workspaceMountAllowWrite => '允许写入';

  @override
  String get workspaceMountPermissionsHint =>
      '关闭后，AI 文件工具和文件浏览器会拒绝修改此文件夹。Shell 会检查部分常用文件命令，但任意脚本不保证受限。保存挂载变更时会停止正在运行的命令和终端会话。';

  @override
  String get workspaceMountBrowse => '浏览文件';

  @override
  String get workspaceMountUnmount => '卸载';

  @override
  String get workspaceMountUnmountMessage => '卸载此挂载？原文件夹及其中的文件会保留。';

  @override
  String get workspaceMountInactive => '不可用，请重新选择文件夹';

  @override
  String get workspaceMountInvalidName =>
      '名称最多 64 个字符，不能包含斜杠、冒号或控制字符，也不能为 . 或 ..。';

  @override
  String get workspaceMountDuplicate => '已存在同名挂载。';

  @override
  String get workspaceMountLimit => '最多挂载 10 个文件夹，请先卸载一个挂载。';

  @override
  String get workspaceMountOverlap => '此文件夹与已有挂载相同或互相包含。请选择其他文件夹，以避免权限冲突。';

  @override
  String get workspaceMountTargetOccupied =>
      '/mounts 下的同名位置已有本地文件。请更换挂载名称，或先移走这些文件。原有文件未被删除。';

  @override
  String get workspaceEnvSystemImage => '系统镜像';

  @override
  String get workspaceEnvDistribution => '发行版';

  @override
  String get workspaceEnvSystemVersion => '版本';

  @override
  String get workspaceEnvLocalImage => '本地镜像';

  @override
  String get workspaceEnvChooseImage => '选择 rootfs 镜像文件';

  @override
  String get workspaceEnvLocalImageHint =>
      '支持根文件系统压缩包（.tar.gz、.tar.xz、.tar），不支持 ISO 或磁盘镜像。镜像需匹配设备 CPU 架构并包含 /bin/sh，解压后自动识别系统和版本。';

  @override
  String get workspaceEnvImportImage => '导入镜像';

  @override
  String get workspaceEnvInvalidImage =>
      '请选择适用于此设备的 rootfs 镜像，需包含可执行的 /bin/sh，且 CPU 架构匹配。';

  @override
  String get workspaceEnvReplaceSystem => '更换系统';

  @override
  String get workspaceEnvReplaceSystemHint =>
      '更换会替换当前环境内的软件包和文件，并停止运行中的命令与终端会话。工作区、聊天文件和外部文件夹会保留。新镜像准备失败时保留原有环境。';

  @override
  String get workspaceEnvProotOptions => 'PRoot 配置';

  @override
  String get workspaceEnvShellPath => 'Shell 路径';

  @override
  String get workspaceEnvShellAutomatic => '自动选择';

  @override
  String get workspaceEnvShellHint =>
      '留空时优先使用 /bin/bash，否则使用 /bin/sh。自定义 Shell 需填写环境内的绝对路径。';

  @override
  String get workspaceEnvProotArguments => '额外 PRoot 参数';

  @override
  String get workspaceEnvProotArgumentsHint =>
      '每行填写一个参数，无需 Shell 引号。例如将 -k 和 5.10.0 分别放在两行，或使用 --kernel-release=5.10.0。配置对之后启动的命令和终端会话生效。';

  @override
  String get workspaceEnvProotInvalid => '请填写有效的 Shell 绝对路径，并将 PRoot 参数逐行填写。';

  @override
  String get workspaceFileMissing => '文件已不存在';

  @override
  String get workspaceFilePreviewUnavailable => '无法预览';

  @override
  String get workspaceToolRelatedFiles => '相关文件';

  @override
  String get workspaceToolFilesTruncated => '仅列出部分文件。';

  @override
  String get displaySettingsPageShowProducedFilesTitle => '显示回复底部文件卡片';

  @override
  String get displaySettingsPageShowProducedFilesSubtitle =>
      '在回复底部显示工具创建或修改的文件。';

  @override
  String get defaultModelPagePerChatModelTitle => '每个对话独立模型';

  @override
  String get defaultModelPagePerChatModelSubtitle =>
      '开启后，在对话中切换模型只影响当前对话；关闭后会直接修改当前助手的模型，使用该助手的所有对话都会跟随。';

  @override
  String get googleFontsTitle => 'Google Fonts';

  @override
  String get googleFontsRefresh => '刷新字体列表';

  @override
  String get googleFontsSearchHint => '搜索字体或语言';

  @override
  String get googleFontsHint =>
      '下载常规字重字体后预览并应用，已安装字体可离线使用。目录来自 Expo Google Fonts，字体从 Google Fonts 下载。';

  @override
  String get googleFontsNoResults => '没有匹配的字体';

  @override
  String get googleFontsFailed => '无法加载、下载或应用字体，请检查网络后重试。';

  @override
  String get googleFontsDownloading => '正在下载字体…';

  @override
  String get googleFontsPreview => '字体预览：你好，世界！Hello world 0123456789';

  @override
  String get googleFontsLicense => '字体许可证';

  @override
  String get assistantEditLocationPermissionSettingsMessage =>
      '定位权限已被禁止。请在系统设置中允许定位访问，然后重新开启此工具。';

  @override
  String get healthDataSettingsCategoryReproductive => '生殖健康';

  @override
  String get healthDataSettingsTypeMenstrualFlowTitle => '经期记录';

  @override
  String get healthDataSettingsTypeMenstrualFlowSubtitle =>
      '最近 90 天记录的经量与周期开始日期';

  @override
  String get assistantEditGradientBackgroundTitle => '渐变背景';

  @override
  String get assistantEditGradientStaticTitle => '静态模式';

  @override
  String get assistantEditGradientStaticDescription => '更省电，适合长对话和持续输出。';

  @override
  String get assistantEditGradientHorizontal => '水平位置';

  @override
  String get assistantEditGradientVertical => '垂直位置';

  @override
  String get assistantEditGradientPreview => '预览';

  @override
  String get assistantEditGradientNextFrame => '换一帧';

  @override
  String get backgroundSettingsTitle => '后台任务';

  @override
  String get backgroundTaskTitle => 'Kelivo 任务';

  @override
  String get backgroundCompleted => '生成完成';

  @override
  String get backgroundFailed => '生成失败，请打开会话查看详情。';

  @override
  String get backgroundCancelled => '生成已取消';

  @override
  String get backgroundInterrupted => '后台生成已中断，请打开会话继续。';

  @override
  String get backgroundRequesting => '正在请求';

  @override
  String get backgroundGenerating => '正在生成回复';

  @override
  String get backgroundThinking => '正在思考';

  @override
  String get backgroundToolRunning => '正在执行工具';

  @override
  String get backgroundRetrying => '等待重试';

  @override
  String get backgroundWorking => '正在处理';

  @override
  String get backgroundTasks => '任务';

  @override
  String get backgroundStopTasks => '停止任务';

  @override
  String get backgroundOpenChat => '打开会话';

  @override
  String get backgroundAndroidEnabled => '后台生成';

  @override
  String get backgroundAndroidEnabledDetail =>
      '在锁屏、切到后台或划掉最近任务后继续当前生成。任务运行期间会显示系统常驻通知。';

  @override
  String get backgroundIosEnabled => '增强后台运行';

  @override
  String get backgroundIosEnabledDetail => '为当前任务申请后台执行时间。可另外开启定位或静音音频辅助保活。';

  @override
  String get backgroundNotifications => '任务通知';

  @override
  String get backgroundNotificationsDetail =>
      '在当前查看的会话之外完成或失败时通知。此开关不控制 Android 必需的常驻通知。';

  @override
  String get backgroundPrivacy => '任务状态隐私';

  @override
  String get backgroundPrivacyDetail => '在通知和实时状态中隐藏会话标题及工具详情，仅显示通用状态、任务数量和耗时。';

  @override
  String get backgroundLiveActivities => '实时活动';

  @override
  String get backgroundLiveActivitiesDetail => '在锁屏和灵动岛显示当前任务，是否可用及展示位置由系统决定。';

  @override
  String get backgroundOverlay => '任务悬浮窗';

  @override
  String get backgroundOverlayDetail => '在其他应用上显示可拖动的任务悬浮窗。点击进入会话；关闭按钮仅隐藏悬浮窗。';

  @override
  String get backgroundLiveUpdates => '实时通知 / 灵动岛';

  @override
  String get backgroundLiveUpdatesDetail =>
      '在支持的设备上使用 Android 16 实时通知。系统成功展示实时通知时优先于悬浮窗。';

  @override
  String get backgroundLocation => '定位辅助保活';

  @override
  String get backgroundLocationDetail =>
      '在后台任务期间使用低精度定位辅助运行，不保存坐标或发送给 AI 服务。需要开启增强后台运行并授权定位。';

  @override
  String get backgroundSilentAudio => '静音音频保活';

  @override
  String get backgroundSilentAudioDetail =>
      '后台任务运行时播放静音音频，并让位于录音和朗读。需要开启增强后台运行，无需麦克风权限。';

  @override
  String get backgroundSpeech => '后台朗读';

  @override
  String get backgroundSpeechDetail => '锁屏或切到后台时继续系统及网络朗读。关闭时，切到后台会暂停朗读。';

  @override
  String get backgroundFinishVisibility => '完成状态保留时间';

  @override
  String get backgroundFinishImmediately => '立即收起';

  @override
  String get backgroundFinishOneMinute => '1 分钟';

  @override
  String get backgroundFinishFiveMinutes => '5 分钟';

  @override
  String get backgroundFinishUntilForeground => '回到应用时收起';

  @override
  String get backgroundFinishVisibilityDetail =>
      '用于 Android 悬浮窗和 iOS 锁屏完成卡片。回到应用时清理完成状态，最长保留 15 分钟；取消任务立即收起。';

  @override
  String get backgroundOverlayIcon => '悬浮窗图标';

  @override
  String get backgroundIconDefault => 'Kelivo 图标';

  @override
  String get backgroundIconImage => '选择图片';

  @override
  String get backgroundIconEmoji => '选择 Emoji';

  @override
  String get backgroundPermissionsTitle => '权限与系统设置';

  @override
  String get backgroundNotificationsPermission => '通知权限';

  @override
  String get backgroundBatteryOptimization => '电池优化';

  @override
  String get backgroundBatteryOptimizationDetail => '允许不受限制地使用电池可改善后台运行。';

  @override
  String get backgroundAutostart => '自启动与后台运行';

  @override
  String get backgroundAutostartDetail =>
      '请手动检查设备的自启动和后台限制。Android 无法可靠查询这些厂商设置的授权状态。';

  @override
  String get backgroundLocationPermission => '定位权限';

  @override
  String get backgroundLocationAlways => '允许持续后台定位';

  @override
  String get backgroundLocationAlwaysDetail => '可进一步授予“始终允许”定位权限，仅在点击此入口时申请。';

  @override
  String get backgroundSystemSettings => '应用系统设置';

  @override
  String get backgroundPermissionGranted => '已允许';

  @override
  String get backgroundPermissionDenied => '未允许';

  @override
  String get backgroundPermissionLimited => '使用应用期间';

  @override
  String get backgroundPermissionUnknown => '需手动检查';

  @override
  String get backgroundPermissionNotDetermined => '尚未申请';

  @override
  String get backgroundRuntimeTitle => '当前状态';

  @override
  String get backgroundRuntimeActive => '正在运行';

  @override
  String get backgroundRuntimeIdle => '未运行';

  @override
  String get backgroundLocationActive => '后台定位';

  @override
  String get backgroundAudioActive => '静音音频';

  @override
  String get backgroundActivityActive => '实时活动';

  @override
  String get backgroundOverlayActive => '悬浮窗';

  @override
  String get backgroundLastError => '最近中断或错误';

  @override
  String get backgroundNoError => '暂无记录';

  @override
  String get backgroundUnsupported => '当前设备不支持或系统设置未允许';

  @override
  String get backgroundIosLimit =>
      '后台执行由 iOS 控制，实时活动本身不能保活。强退可能停止生成，实时状态可能要等再次打开应用后才能清理。';

  @override
  String get backgroundAndroidLimit =>
      '如任务中断，请检查通知、电池及厂商后台设置。系统强行停止或终止进程仍可能中断生成。';

  @override
  String get backgroundStale => '状态暂未更新，请打开应用查看。';

  @override
  String get backgroundIconError => '无法导入此图片，请选择其他图片。';

  @override
  String get backgroundNotificationChannels => '通知渠道';

  @override
  String get backgroundCompletionChannel => '任务完成通知渠道';

  @override
  String get backgroundOngoingChannel => '任务运行通知渠道';

  @override
  String get backgroundOverlayAppearance => '悬浮窗外观';

  @override
  String get backgroundOverlayAppearanceDetail => '调整尺寸、图标、进度环和显示内容';

  @override
  String get backgroundOverlayPreviewHint => '拖动可移动 · 点击进入会话 · 长按可收起';

  @override
  String get backgroundOverlayCard => '信息卡片';

  @override
  String get backgroundOverlayCircle => '圆形图标';

  @override
  String get backgroundOverlaySize => '尺寸与形状';

  @override
  String get backgroundOverlayWidth => '宽度';

  @override
  String get backgroundOverlayHeight => '高度';

  @override
  String get backgroundOverlayCornerRadius => '圆角';

  @override
  String get backgroundOverlayIconSize => '图标大小';

  @override
  String get backgroundOverlayProgressSize => '进度环直径';

  @override
  String get backgroundOverlayProgressStroke => '进度环粗细';

  @override
  String get backgroundOverlayContent => '显示内容';

  @override
  String get backgroundOverlayShowProgress => '显示进度环';

  @override
  String get backgroundOverlayShowTitle => '显示标题';

  @override
  String get backgroundOverlayShowSubtitle => '显示副标题';

  @override
  String get backgroundOverlayShowTime => '显示耗时';

  @override
  String get backgroundOverlayShowClose => '显示关闭按钮';

  @override
  String get backgroundOverlayShowBackground => '显示背景';

  @override
  String get backgroundOverlayShowBorder => '显示边框';

  @override
  String get backgroundOverlayReset => '恢复默认样式';

  @override
  String get mcpStdioEnvironmentRequired => '请先安装工作区运行环境，再使用移动端 STDIO。';

  @override
  String get mcpArgumentsHint => '用空格分隔参数，包含空格的内容用引号包裹；空参数写成 \'\'。';

  @override
  String get mcpArgumentsInvalid => '请检查参数中的引号是否闭合、末尾是否有未完成的转义。';

  @override
  String get mcpImportEnvironment => '从环境导入';

  @override
  String get mcpEnvironmentEmpty => '还没有环境变量，请先在环境设置中添加。';

  @override
  String get mcpEnvironmentHint => '默认继承运行环境的变量，导入后可为此服务器单独修改。';

  @override
  String get mcpImportJson => '导入 JSON';

  @override
  String get mcpImportJsonHint =>
      '粘贴 Claude Desktop 或 Cursor 的 MCP 配置，预览后添加服务器，不覆盖现有配置。';

  @override
  String get mcpImportPaste => '从剪贴板粘贴';

  @override
  String get mcpImportPreview => '预览';

  @override
  String get mcpImportConfirm => '导入';

  @override
  String get startupRecoverySnapshotTitle => '从数据库快照恢复';

  @override
  String get startupRecoverySnapshotBody =>
      '即使数据库无法打开，也可以选择本机快照恢复聊天和设置。请勿卸载 Kelivo，卸载会一并删除这些快照。';

  @override
  String get startupRecoverySnapshotEmpty => '未在本机找到数据库快照。请先导出数据，再尝试其他恢复操作。';

  @override
  String get startupRecoverySnapshotButton => '选择快照恢复';

  @override
  String startupRecoverySnapshotConfirm(String when) {
    return '将聊天和设置恢复到 $when 的快照？快照之后的更改不会包含在内。现有附件文件和快照会保留，Kelivo 将重启以完成恢复。';
  }

  @override
  String startupRecoverySnapshotFailed(String reason) {
    return '无法准备快照恢复：$reason';
  }

  @override
  String get startupRecoverySnapshotReady => '快照已准备好，请重启 Kelivo 完成恢复。';

  @override
  String get scheduledTasksTitle => '定时任务';

  @override
  String get scheduledTasksDescription => '在指定时间自动执行任务，支持新建聊天、继续追问或重新运行。';

  @override
  String get scheduledTasksEmpty => '把任务交给时间';

  @override
  String get scheduledTasksEmptyDetail => '晨间简报、每日复盘，或任何希望定期完成的事。';

  @override
  String get scheduledTasksAdd => '添加任务';

  @override
  String get scheduledTasksEdit => '编辑任务';

  @override
  String get scheduledTasksName => '任务名称';

  @override
  String get scheduledTasksNameHint => '晨间简报';

  @override
  String get scheduledTasksPrompt => '任务内容';

  @override
  String get scheduledTasksPromptHint => '希望助手为你完成什么？';

  @override
  String get scheduledTasksAssistant => '执行助手';

  @override
  String get scheduledTasksChooseAssistant => '选择助手';

  @override
  String get scheduledTasksAssistantMissing => '助手已不存在';

  @override
  String get scheduledTasksTime => '执行时间';

  @override
  String get scheduledTasksTimeHint => '24 小时制，例如 08:00';

  @override
  String get scheduledTasksRepeat => '重复';

  @override
  String get scheduledTasksEveryDay => '每天';

  @override
  String get scheduledTasksWeekdays => '工作日';

  @override
  String get scheduledTasksEnabled => '启用任务';

  @override
  String get scheduledTasksPermission => '闹钟和提醒';

  @override
  String get scheduledTasksPermissionDetail =>
      '允许设置闹钟，才能按指定时间执行。未授权时，已启用的任务会等待授权。';

  @override
  String get scheduledTasksPermissionAction => '去授权';

  @override
  String get scheduledTasksReliability =>
      '建议在电池设置中允许 Kelivo 后台运行。强行停止后需重新打开应用。错过的任务不会补跑，执行时间跟随设备时区。';

  @override
  String get scheduledTasksExecutionDetail =>
      '结果保存在对话中，完成后会发送回复预览通知，点击可打开对话。单次最多运行 10 分钟；需要用户回答或工具确认时会停止。';

  @override
  String get scheduledTasksRunNow => '立即运行';

  @override
  String get scheduledTasksHistory => '执行记录';

  @override
  String get scheduledTasksNoRuns => '尚无执行记录';

  @override
  String get scheduledTasksRunning => '正在运行';

  @override
  String get scheduledTasksCompleted => '已完成';

  @override
  String get scheduledTasksFailed => '执行失败';

  @override
  String get scheduledTasksInterrupted => '已中断';

  @override
  String get scheduledTasksPaused => '已暂停';

  @override
  String get scheduledTasksWaitingPermission => '等待授权';

  @override
  String scheduledTasksNextRun(String time) {
    return '下次：$time';
  }

  @override
  String get scheduledTasksDelete => '删除任务';

  @override
  String get scheduledTasksDeleteDetail => '删除此任务及执行记录？已经生成的对话会保留。';

  @override
  String get scheduledTasksSave => '保存';

  @override
  String get scheduledTasksCancel => '取消';

  @override
  String get scheduledTasksInvalid => '请填写名称、任务内容和助手，自定义重复需至少选择一天。';

  @override
  String get scheduledTasksLoading => '正在加载…';

  @override
  String get scheduledTasksOpenChat => '查看对话';

  @override
  String get scheduledTasksNeedsInput => '任务需要用户回答或工具确认，已停止。可打开对话继续。';

  @override
  String get scheduledTasksTimeout => '已达到执行时限。';

  @override
  String get scheduledTasksProcessTerminated => '上次执行被系统终止。';

  @override
  String get scheduledTasksOnce => '仅一次';

  @override
  String get scheduledTasksCustom => '自定义';

  @override
  String get scheduledTasksExecution => '执行任务';

  @override
  String get scheduledTasksMode => '执行方式';

  @override
  String get scheduledTasksNewChat => '新建聊天';

  @override
  String get scheduledTasksFollowUp => '继续追问';

  @override
  String get scheduledTasksRegenerate => '重新运行';

  @override
  String get scheduledTasksChat => '目标聊天';

  @override
  String get scheduledTasksChooseChat => '选择聊天';

  @override
  String get scheduledTasksMessage => '重新运行的问题';

  @override
  String get scheduledTasksChooseMessage => '选择问题';

  @override
  String get scheduledTasksAttachmentMessage => '含附件的消息';

  @override
  String get scheduledTasksModel => '模型';

  @override
  String get scheduledTasksChooseModel => '选择模型';

  @override
  String get scheduledTasksModelDefault => '跟随聊天或助手的模型';

  @override
  String get scheduledTasksSchedule => '执行时间';

  @override
  String get scheduledTasksActiveWindow => '活动时段';

  @override
  String get scheduledTasksStartDate => '开始日期';

  @override
  String get scheduledTasksEndDate => '结束日期';

  @override
  String get scheduledTasksActiveWindowDetail =>
      '仅在此日期范围内执行，包含结束当天。未设置的日期不作限制。';

  @override
  String get scheduledTasksDate => '日期';

  @override
  String get scheduledTasksDateUnrestricted => '不限';

  @override
  String get scheduledTasksClear => '清除';

  @override
  String get scheduledTasksSearch => '搜索';

  @override
  String get scheduledTasksNoTargets => '此助手下没有符合条件的内容';

  @override
  String get scheduledTasksFutureDate => '请选择未来的执行日期和时间。';

  @override
  String get scheduledTasksDateRangeInvalid => '结束日期不能早于开始日期。';

  @override
  String get scheduledTasksRegenerateDetail =>
      '使用原有上下文，为所选问题生成新的回答，保留已有回答和后续消息。';

  @override
  String get scheduledTasksSaving => '正在保存…';

  @override
  String get scheduledTasksFinished => '计划已结束';

  @override
  String get scheduledTasksModelMissing => '所选模型已不可用，请编辑任务重新选择。';

  @override
  String get scheduledTasksChatMissing => '目标聊天已不存在或已移至其他助手。';

  @override
  String get scheduledTasksMessageMissing => '所选问题已不存在，请重新选择。';

  @override
  String get scheduledTasksChatBusy => '此聊天正在生成回答，本次任务已跳过。';

  @override
  String get scheduledTasksDesktopEmpty => '暂无定时任务';

  @override
  String get scheduledTasksDesktopReliability =>
      '仅在 Kelivo 运行时执行，最小化或驻留托盘时也会继续。退出或电脑休眠期间错过的任务不会补运行，也不会自动启动应用。';

  @override
  String get scheduledTasksDesktopExecutionDetail =>
      '结果保存在对话中，可从任务的运行记录打开。单次最多运行 10 分钟；需要用户回答或工具确认时会停止。';

  @override
  String get worldBookStickyLabel => '粘滞（消息数）';

  @override
  String get worldBookStickyHint => '触发后在后续 N 条消息中保持激活，重复命中不延长。0 表示关闭。';

  @override
  String get worldBookCooldownLabel => '冷却（消息数）';

  @override
  String get worldBookCooldownHint => '触发后（或粘滞结束后）N 条消息内不再触发。0 表示关闭。';

  @override
  String get worldBookDelayLabel => '延迟（消息数）';

  @override
  String get worldBookDelayHint => '对话至少有 N 条消息时才允许触发。按单条消息计数，不是对话轮数。0 表示关闭。';

  @override
  String get worldBookDragToReorder => '拖动调整顺序';

  @override
  String worldBookEnabledCount(int enabled, int total) {
    return '已启用 $enabled/$total';
  }

  @override
  String get assistantConversationSystemPromptTitle => '独立对话系统提示';

  @override
  String get assistantConversationSystemPromptHint => '允许每个对话设置自己的系统提示词。';

  @override
  String get assistantConversationInjectionTitle => '独立对话指令注入';

  @override
  String get assistantConversationInjectionHint => '每个对话单独选择指令注入和世界书，默认不选中。';

  @override
  String get conversationSystemPromptTitle => '对话系统提示词';

  @override
  String get conversationSystemPromptHint => '仅对当前对话生效，留空时使用助手的系统提示词。';

  @override
  String get conversationSystemPromptClear => '恢复助手提示词';

  @override
  String get conversationSystemPromptPlaceholder => '为这个对话编写系统提示词…';

  @override
  String get conversationPromptScope => '仅当前对话';

  @override
  String get oauthAccountsTab => '账号登录';

  @override
  String get oauthLogin => '登录';

  @override
  String oauthLoginTo(String provider) {
    return '登录 $provider';
  }

  @override
  String get oauthConnected => '已连接';

  @override
  String get oauthNotConnected => '未连接';

  @override
  String oauthWaiting(String provider) {
    return '正在等待 $provider 授权';
  }

  @override
  String get oauthCancel => '取消授权';

  @override
  String get oauthOpenBrowser => '打开授权页面';

  @override
  String get oauthCopyCode => '复制验证码';

  @override
  String get oauthCodeHint => '在授权页面输入此验证码';

  @override
  String get oauthDeviceHint => '请先在 ChatGPT 安全设置或工作区权限中启用设备码登录。';

  @override
  String get oauthDeviceLogin => '使用设备码登录';

  @override
  String get oauthDetails => '查看账号详情';

  @override
  String get oauthConnectAnother => '再连一个';

  @override
  String get oauthRelogin => '重新登录';

  @override
  String get oauthNeedsLogin => '需重新登录';

  @override
  String oauthExpired(String provider) {
    return '$provider 登录已过期';
  }

  @override
  String get oauthLoginRestored => '已重新登录，可使用消息的重试按钮再次发送。';

  @override
  String get oauthLogout => '退出登录';

  @override
  String get oauthLogoutDescription => '清除此账号在本机保存的授权凭证';

  @override
  String get oauthRefreshing => '正在续期授权…';

  @override
  String get oauthRefreshUsage => '刷新用量';

  @override
  String get oauthUsageDetails => '用量明细';

  @override
  String get oauthUsageUnavailable => '暂时无法获取用量';

  @override
  String oauthLastUpdated(String time) {
    return '更新于 $time';
  }

  @override
  String get oauthSyncModels => '同步';

  @override
  String get oauthSyncing => '正在同步模型…';

  @override
  String get oauthModelsHint => '可用模型由账号同步。';

  @override
  String get oauthNoModels => '同步模型后即可开始对话';

  @override
  String get oauthConnection => '接入';

  @override
  String get oauthConnectionInfo => '接入信息';

  @override
  String get oauthEndpoint => '接入端点';

  @override
  String get oauthScope => '授权范围';

  @override
  String get oauthAccountId => '账号 ID';

  @override
  String get oauthTokenExpiry => '令牌有效期';

  @override
  String get oauthName => '供应商名称';

  @override
  String get oauthEnabledHint => '在模型选择器中显示这些模型';

  @override
  String get oauthNetwork => '网络代理';

  @override
  String get oauthFollowGlobal => '跟随全局设置';

  @override
  String get oauthCustomRequest => '自定义请求';

  @override
  String get oauthWeekly => '本周窗口';

  @override
  String get oauthMonthly => '本月窗口';

  @override
  String get oauthTotal => '总额度';

  @override
  String oauthHours(String count) {
    return '$count 小时窗口';
  }

  @override
  String oauthMinutes(String count) {
    return '$count 分钟窗口';
  }

  @override
  String oauthDays(String count) {
    return '$count 天窗口';
  }

  @override
  String get oauthWindow => '用量窗口';

  @override
  String oauthResetsAt(String time) {
    return '重置于 $time';
  }

  @override
  String oauthUsedValue(String value) {
    return '已用 $value';
  }

  @override
  String get oauthNetworkError => '连接失败，请检查网络后重试。';

  @override
  String get oauthInvalidResponse => '授权未完成，请重试。';

  @override
  String get oauthTimeout => '授权超时，请重试。';

  @override
  String get oauthDenied => '授权未获批准，请重试。';

  @override
  String get oauthSaving => '正在连接账号…';

  @override
  String get oauthQuotaExceeded => '该账号暂无可用额度。';

  @override
  String get oauthRateLimited => '请求过于频繁，请稍后重试。';

  @override
  String get oauthPermissionDenied => '该账号无权访问此资源。';

  @override
  String get oauthRequestFailed => '供应商未能完成请求。';

  @override
  String get oauthQuotaAvailable => '额度可用';

  @override
  String oauthSavedResets(String count) {
    return '可用额度重置次数：$count';
  }

  @override
  String get oauthPrimaryWindow => '主要窗口';

  @override
  String get oauthSecondaryWindow => '次要窗口';

  @override
  String get oauthAuthorizationCode => '授权码或回调链接';

  @override
  String get oauthAuthorizationCodeHint => '如果浏览器没有自动返回，请将最后的回调链接或授权码粘贴到这里。';

  @override
  String get oauthInvalidAuthorizationCode => '请输入本次登录的授权码或回调链接。';

  @override
  String get oauthSubmitAuthorizationCode => '完成登录';

  @override
  String get oauthExtraUsage => '额外用量';

  @override
  String get oauthPromptCachingHelp => '复用多轮对话中的上下文，可设置缓存保留时长。';

  @override
  String get scheduledTasksPreparation => '执行与通知';

  @override
  String get scheduledTasksAllowPreparation => '允许提前准备';

  @override
  String get scheduledTasksPreparationDetail =>
      '提前准备适合不依赖实时信息的文字任务，不会使用工具、附件或执行外部操作。';

  @override
  String get scheduledTasksIOSDetail =>
      '受 iOS 后台限制，Kelivo 不能在指定时间自动唤醒并运行模型。此功能会在 App 可运行时提前准备内容，由系统到点展示通知。每次仅准备下一次结果；离开 App 后不保证准备完成，后续任务需再次打开 Kelivo 才能补充。';

  @override
  String get scheduledTasksContextPolicy => '对话上下文';

  @override
  String get scheduledTasksContextLatest => '跟随最新对话';

  @override
  String get scheduledTasksContextSnapshot => '使用准备时的快照';

  @override
  String get scheduledTasksUnavailable => '无法执行时';

  @override
  String get scheduledTasksRemind => '仅发送提醒';

  @override
  String get scheduledTasksSkip => '跳过本次';

  @override
  String get scheduledTasksNotify => '结果通知';

  @override
  String get scheduledTasksShowPreview => '通知显示结果正文';

  @override
  String get scheduledTasksPreparationWindow => '最多提前';

  @override
  String get scheduledTasksPreparationAttempts => '自动准备次数上限';

  @override
  String get scheduledTasksPreparationCooldown => '准备最小间隔（分钟）';

  @override
  String get scheduledTasksPreparationBudget =>
      '所有任务合计最多同时准备一个。每小时累计尝试六次后暂停自动准备，取消的请求也计入次数；「立刻准备」不受次数上限限制。';

  @override
  String get scheduledTasksPreparing => '正在准备结果';

  @override
  String get scheduledTasksPrepared => '结果已准备';

  @override
  String get scheduledTasksPendingPreparation => '本次尚未准备';

  @override
  String get scheduledTasksNotificationRegistered => '通知已登记';

  @override
  String get scheduledTasksNotificationUnavailable => '通知未登记';

  @override
  String get scheduledTasksReminded => '已到期 · 仅提醒';

  @override
  String get scheduledTasksSkipped => '已跳过';

  @override
  String get scheduledTasksCancelled => '已取消';

  @override
  String get scheduledTasksReminderBody => '定时任务已到期，打开 Kelivo 继续。';

  @override
  String get scheduledTasksResultBody => '定时任务结果已准备好。';

  @override
  String get scheduledTasksNotificationPermission => '允许任务通知';

  @override
  String get scheduledTasksPreparationCost =>
      '提前准备会调用模型，可能产生额外费用。选择「跟随最新对话」时，到期前的新消息可能使已准备内容失效。即使结果未使用或请求被取消，仍可能计费；重新准备会再次调用模型。';

  @override
  String get scheduledTasksAllowPreparationTip =>
      '在 Kelivo 可运行时，提前生成下一次任务的结果，到期前不会显示在聊天中。仅使用文字，不使用工具、附件或自定义请求体；调用模型可能产生费用。';

  @override
  String get scheduledTasksContextPolicyTip =>
      '跟随最新对话：到期前发送新消息、编辑消息或切换消息版本后，已准备内容会失效；重新准备会占用次数，并可能增加费用。到期后，已保存的通知结果会原样补入对话。\n\n使用准备时的快照：对话变化后仍保留已准备结果，内容不会包含后续聊天。';

  @override
  String get scheduledTasksPreparationWindowTip =>
      '允许在任务到期前多久开始准备，最长 24 小时。例如第二天早上提醒，前一天中午打开 Kelivo 时就有机会准备。时间越长，准备机会越多，但内容也可能更早过时。不会改变任务时间，也不代表能在后台定时运行。「立刻准备」不受这项自动等待和准备次数上限限制。';

  @override
  String get scheduledTasksPreparationAttemptsTip =>
      '本次累计尝试达到上限后，自动准备会暂停。首次、失败、取消和手动准备都计入尝试记录；「立刻准备」不受此上限限制。尝试越多，可能产生的模型费用越多，这不是费用上限。';

  @override
  String get scheduledTasksPreparationCooldownTip =>
      '同一次任务两次开始准备之间，至少间隔多少分钟。间隔越长，重复请求越少。重试仍需 App 有运行机会，不是在后台设定一个定时器。「立刻准备」不受这项自动等待和准备次数上限限制。';

  @override
  String get scheduledTasksUnavailableTip =>
      '到期时没有可用结果、也无法运行任务，就发送提醒或跳过本次。提醒不包含模型生成的回答，且需要开启通知。如果到期时 Kelivo 正在打开运行，可直接执行任务。';

  @override
  String get scheduledTasksNotifyTip =>
      '允许发送结果通知和无法执行时的提醒。关闭后仍会执行任务、调用模型，提前准备也仍可能产生费用。还需要允许系统通知权限。';

  @override
  String get scheduledTasksShowPreviewTip =>
      '在通知中显示已生成的结果，系统设置允许时也会显示在锁屏上。关闭后只显示通用提示，完整结果仍可在聊天中查看；同时遵循全局通知隐私设置。';

  @override
  String scheduledTasksHours(int count) {
    return '$count 小时';
  }

  @override
  String scheduledTasksMinutes(int count) {
    return '$count 分钟';
  }

  @override
  String get scheduledTasksPreparationOff => '未开启准备';

  @override
  String get scheduledTasksPreparationQueued => '排队中';

  @override
  String get scheduledTasksPreparationQueuedDetail => '正在准备其他任务，随后按到期时间依次准备。';

  @override
  String get scheduledTasksPreparationIdle => '等待空闲';

  @override
  String get scheduledTasksPreparationIdleDetail => '等待当前回复完成或此任务的对话状态稳定后继续。';

  @override
  String get scheduledTasksPreparationWindowWaiting => '未到准备时间';

  @override
  String get scheduledTasksPreparationCooldownWaiting => '等待重试';

  @override
  String scheduledTasksPreparationRetryAt(String time) {
    return '下次可尝试：$time';
  }

  @override
  String get scheduledTasksPreparationLimitReached => '自动准备次数已用完';

  @override
  String scheduledTasksPreparationAttemptsUsed(int count, int limit) {
    return '本次已尝试 $count 次，自动准备上限为 $limit 次。可使用「立刻准备」继续。';
  }

  @override
  String get scheduledTasksPreparationHourlyLimit => '自动准备已达小时上限';

  @override
  String get scheduledTasksPreparationHourlyLimitDetail =>
      '已达到每小时准备次数上限，自动准备将在额度恢复后继续；仍可使用「立刻准备」。';

  @override
  String get scheduledTasksPreparationUnavailable => '暂时无法准备';

  @override
  String get scheduledTasksPreparationReadFailed =>
      '暂时无法读取任务信息，稍后会重新检查；具体原因见执行记录。';

  @override
  String get scheduledTasksPreparationResultRetained =>
      '暂时无法校验上下文，已保留准备结果，稍后会重新检查。';

  @override
  String get scheduledTasksPreparationContextChanged => '对话内容或配置已变化，原准备结果已作废。';

  @override
  String get scheduledTasksPreparationPublishing => '待写入对话';

  @override
  String get scheduledTasksPreparationPublishingDetail =>
      '等待当前回复结束后，将已保存的结果写入对话。';

  @override
  String get scheduledTasksPreparationPrompt => '准备提示词';

  @override
  String get scheduledTasksPreparationPromptTip =>
      '仅在提前准备本任务时附加的系统提示词，与任务内容分开。可以自定义语气和要求，也可以留空，不附加准备提示词。无论如何设置，提前准备都不能使用工具或获取实时信息。到期前修改会使已准备的结果失效，再次准备可能产生额外模型费用。';

  @override
  String get scheduledTasksPreparationPromptEmpty => '留空则不附加准备提示词';

  @override
  String scheduledTasksPreparationPromptVariables(
    String timeVariable,
    String offsetVariable,
  ) {
    return '可用占位符：$timeVariable 为计划发送的本地时间，$offsetVariable 为该时间的 UTC 偏移。准备时会自动替换。';
  }

  @override
  String get scheduledTasksPrepareNow => '立刻准备';

  @override
  String get scheduledTasksPrepareNowDetail =>
      '立刻准备下一次内容，到原定时间再发送。不受自动准备的等待时间和次数上限限制，会调用模型并可能产生费用；已有准备结果时直接复用。';

  @override
  String get scheduledTasksPrepareNowReady => '本次结果已经准备好，无需再次调用模型。';

  @override
  String get scheduledTasksPrepareNowStarted => '正在准备下一次内容，将在计划时间发布。';

  @override
  String get scheduledTasksPrepareNowBusy => '正在准备其他任务，请等待完成后再试。';

  @override
  String get scheduledTasksPrepareNowChatBusy => '请等待当前回复结束后，再尝试准备。';

  @override
  String get scheduledTasksPrepareNowDisabled =>
      '请先启用任务和「允许提前准备」。重新生成模式不支持提前准备。';

  @override
  String get scheduledTasksPrepareNowUnavailable => '暂时无法开始准备，请稍后再试。';

  @override
  String get scheduledTasksPrepareNowNoUpcoming =>
      '没有可提前准备的下一次任务，请检查任务时间和启用状态。';

  @override
  String get phoneControlTitle => '手机控制';

  @override
  String get phoneControlSubtitle => '通过无障碍读取屏幕并执行操作';

  @override
  String get phoneControlAccessibilityService => '无障碍服务';

  @override
  String get phoneControlOpenSettings => '前往无障碍设置';

  @override
  String get phoneControlRefresh => '刷新状态';

  @override
  String get phoneControlChecking => '正在检查服务状态…';

  @override
  String get phoneControlReady => '已启用并连接';

  @override
  String get phoneControlDisabled => '未启用';

  @override
  String get phoneControlDisconnected => '已启用，但尚未连接。请在系统设置中关闭再开启服务，然后刷新状态。';

  @override
  String get phoneControlStatusUnavailable => '无法读取服务状态，请刷新后重试。';

  @override
  String get phoneControlSettingsUnavailable =>
      '无法打开设置，请手动进入 Android 系统设置 → 无障碍。';

  @override
  String get phoneControlUsageTitle => '使用说明';

  @override
  String get phoneControlDisclosure =>
      '在对话中发起手机控制任务后，助手可以读取当前屏幕、点击、输入、滑动、导航和打开应用。屏幕内容会发送给当前对话配置的模型服务商，并保存在对话的工具结果中。密码字段会隐藏，服务不会持续记录屏幕内容。你可以随时关闭助手的此项工具，或在系统设置中停用服务。';

  @override
  String get phoneControlAssistantTitle => '还需开启助手工具';

  @override
  String get phoneControlAssistantHint =>
      '需要同时完成两项设置：在系统无障碍设置中启用“Kelivo 手机控制”，并在要使用的助手 → 本地工具中开启“手机控制”（也可从对话工具菜单开启）。每个助手单独配置，执行任务时请保持手机解锁。';

  @override
  String get phoneControlRestrictedTitle => '无法开启无障碍？';

  @override
  String get phoneControlRestrictedHint =>
      '部分下载的 APK 需要先在应用信息右上角菜单中选择“允许受限制的设置”。点击打开 Kelivo 应用信息，完成后再返回无障碍设置。';

  @override
  String get phoneControlEnableAssistant => '允许此助手使用手机控制';

  @override
  String get composerDraftLabel => '草稿';

  @override
  String get composerDraftRecovered => '已恢复一条尚未发送的内容。';

  @override
  String get composerDraftRestore => '继续编辑';

  @override
  String get composerDraftDiscard => '丢弃';

  @override
  String get composerDraftSaveFailed => '最新草稿保存失败，内容仍保留在当前窗口。';

  @override
  String get composerDraftRetry => '重试保存';

  @override
  String get composerDraftConflictTitle => '这个对话已有草稿';

  @override
  String get composerDraftConflictBody => '追加会保留两边的文字和附件；替换会丢弃原来的草稿。内容不会自动发送。';

  @override
  String get composerDraftAppend => '追加';

  @override
  String get composerDraftReplace => '替换草稿';

  @override
  String get composerDraftMissingFile => '有附件无法读取，请移除或重新选择该文件。';

  @override
  String get composerDraftMessageMissing => '正在编辑的原消息已不存在。请复制内容到新消息，或取消本次编辑。';

  @override
  String get composerDraftDeleteNotice => '这些对话中未发送的草稿也会一起删除。';

  @override
  String get mcpOAuthSettings => 'OAuth 设置';

  @override
  String get mcpOAuthAutomatic => '自动';

  @override
  String get mcpOAuthMetadataUrl => '客户端元数据文档 URL';

  @override
  String get mcpOAuthClientAuthentication => '客户端认证方式';

  @override
  String get mcpOAuthPublicClient => '公共客户端';

  @override
  String get mcpOAuthRedirectUri => '本地回调 URL（可选）';

  @override
  String get mcpOAuthFillRedirectExample => '填入示例';

  @override
  String get mcpOAuthRedirectHint =>
      '留空使用平台默认回调。若服务仅允许 localhost 回调，可填写 HTTP 回环地址。端口 0 自动选择可用端口；预注册客户端可能要求固定端口。';

  @override
  String get mcpOAuthClientIdRequired => '请输入客户端 ID，或选择自动注册。';

  @override
  String get mcpOAuthMetadataUrlInvalid => '请输入包含路径的 HTTPS 元数据文档 URL。';

  @override
  String get mcpOAuthSecretRequired => '此客户端认证方式需要 Client secret。';

  @override
  String get mcpOAuthRedirectInvalid =>
      '请使用 localhost、127.0.0.1 或 [::1] 的 HTTP 回调地址，不要包含凭据、查询参数或片段。';

  @override
  String get mcpOAuthDiscovering => '正在发现授权服务器…';

  @override
  String get mcpOAuthRegistering => '正在准备授权…';

  @override
  String get mcpOAuthWaitingBrowser => '等待浏览器授权…';

  @override
  String get mcpOAuthExchangingToken => '正在完成登录…';

  @override
  String get markdownPlaygroundTitle => 'Markdown Playground';

  @override
  String get markdownPlaygroundSource => 'Markdown 源码';

  @override
  String get markdownPlaygroundPreview => '渲染预览';

  @override
  String get markdownPlaygroundAst => 'AST 语法树';

  @override
  String get markdownPlaygroundPlay => '逐字输入';

  @override
  String get markdownPlaygroundPause => '暂停';

  @override
  String get markdownPlaygroundResume => '继续';

  @override
  String get markdownPlaygroundShowAll => '显示全文';

  @override
  String get markdownPlaygroundWidth => '预览宽度';

  @override
  String get markdownPlaygroundTheme => '预览主题';

  @override
  String get markdownPlaygroundPlain => '选区纯文本';

  @override
  String get markdownPlaygroundMarkdown => '选区 Markdown';

  @override
  String get markdownPlaygroundSelectionHint => '在预览中选择文本，查看复制结果。';

  @override
  String get markdownPlaygroundEmpty => '输入 Markdown 开始预览。';

  @override
  String markdownPlaygroundProgress(int shown, int total) {
    return '已输入 $shown / $total';
  }

  @override
  String get markdownCopyMarkdownAction => '复制为 Markdown';

  @override
  String get markdownCopyCsvAction => '复制 CSV';

  @override
  String get markdownCopyImageAction => '复制图片';

  @override
  String get markdownCodeLabel => '代码';

  @override
  String get markdownDetailsLabel => '详情';

  @override
  String markdownMoreRows(int count) {
    return '再显示 $count 行';
  }

  @override
  String get markdownNoteLabel => '备注';

  @override
  String get markdownTipLabel => '提示';

  @override
  String get markdownImportantLabel => '重要';

  @override
  String get markdownWarningLabel => '警告';

  @override
  String get markdownCautionLabel => '注意';

  @override
  String get markdownDangerLabel => '危险';

  @override
  String get markdownCopyRichTextAction => '复制富文本';

  @override
  String get markdownCopySelectionFailed => '复制所选内容失败。';

  @override
  String get recoveryMissingDataTitle => '检测到已有数据';

  @override
  String get recoveryMissingDataBody =>
      '当前数据库缺失，但设备上仍有旧数据。Kelivo 已暂停启动，没有新建空数据库，并保留现有文件和副本。';

  @override
  String get recoveryEmptyDataTitle => '当前聊天记录为空';

  @override
  String get recoveryEmptyDataBody =>
      '当前数据库没有对话，但发现了历史副本。Kelivo 已暂停启动，你可以恢复副本，也可以明确选择保留当前数据。应用不会自动覆盖数据。';

  @override
  String get recoveryKeepCurrent => '保留当前数据并继续';

  @override
  String get recoveryKeepCurrentConfirm => '继续使用当前空数据库？历史副本仍会保留，可以稍后恢复。';

  @override
  String get recoverySearchingCopies => '正在查找并校验本机数据副本…';

  @override
  String recoveryFoundCopies(int count) {
    return '找到 $count 份通过校验的副本。可以选择恢复聊天与设置，原文件会保留。';
  }

  @override
  String recoveryInvalidCopy(String name) {
    return '$name：校验未通过，原文件已保留。';
  }

  @override
  String get recoverySearchFailed => '部分数据位置无法读取。现有文件已保留，请先导出数据副本再尝试其他恢复操作。';

  @override
  String get recoveryDiscoveredCopyBody =>
      '在原存储目录或其他位置发现的副本。原文件会保留，恢复前会进行完整校验。';

  @override
  String get recoveryStorageFailureTitle => '数据存储需要检查';

  @override
  String get recoveryStorageFailureBody =>
      'Kelivo 未能启用受保护的数据存储，已暂停启动并保留原数据。可以导出数据副本或重试，应用不会因此新建空数据库。';

  @override
  String get recoveryProtectingTitle => '正在保护聊天数据库';

  @override
  String get recoveryProtectingData =>
      '正在复制并校验数据库。图片、附件和快照留在 Documents，不会重复复制；原数据库也会保留。';

  @override
  String get recoveryStorageReadyTitle => '聊天数据库已转存至 App 内部';

  @override
  String get recoveryStorageReadyBody =>
      '存放聊天、助手和设置的数据库已转存至 App 内部。快照、图片和附件仍在系统“文件”App 可访问的 Documents 中，原数据库也已保留。若之前的聊天仍然缺失，可前往“设置 → 备份与恢复 → 本地副本”查看恢复副本。';

  @override
  String get recoveryRetainedData => '保留的原数据';

  @override
  String get recoveryNoValidCopies => '找到了数据副本，但没有副本通过校验。原文件均已保留，可以导出数据进一步排查。';

  @override
  String get recoveryStorageInsufficientSpaceBody =>
      '剩余空间不足，无法在保留原数据库的同时建立经过校验的内部副本。现有数据和快照均未改动，请腾出一些空间后重试。';

  @override
  String get migrationFreshStartTitle => '已重新开始';

  @override
  String get migrationFreshStartSubtitle => '已新建空数据库，旧数据已保留。请重启 App 后继续使用。';

  @override
  String get migrationFreshStartFailedTitle => '重新开始未完成';

  @override
  String get migrationFreshStartFailedSubtitle =>
      '旧数据已保留。请重试重新开始，或关闭并重新打开 App。';

  @override
  String get imageExportPreparing => '正在准备图片…';

  @override
  String imageExportDiagrams(int completed, int total) {
    return '正在准备图表 $completed/$total…';
  }

  @override
  String imageExportCapturing(int completed, int total) {
    return '正在截图 $completed/$total…';
  }

  @override
  String get imageExportProcessing => '正在合成图片并准备预览…';

  @override
  String get imageExportSaving => '正在保存图片…';

  @override
  String get backupEncryptionTitle => '加密备份';

  @override
  String get backupEncryptionOffHint => '未加密的备份可被直接读取。';

  @override
  String get backupEncryptionOnHint => '备份将加密保存，重启应用后需重新输入口令。';

  @override
  String get backupEncryptionPasswordHint =>
      '请妥善保存口令，遗忘后无法恢复备份。口令仅在内存中保留至退出应用。';

  @override
  String get backupEncryptionPassword => '口令';

  @override
  String get backupEncryptionConfirmPassword => '确认口令';

  @override
  String get backupEncryptionMismatch => '两次输入的口令不一致。';

  @override
  String get backupEncryptionShowPassword => '显示口令';

  @override
  String get backupEncryptionHidePassword => '隐藏口令';

  @override
  String get backupEncryptionUnlockTitle => '加密备份';

  @override
  String get backupEncryptionUnlockHint => '请输入创建这份备份时使用的口令。';

  @override
  String get backupEncryptionUnlock => '解锁';

  @override
  String get backupEncryptionFailed => '口令错误或备份已损坏，请重试或取消。';

  @override
  String get backupEncryptionInvalid => '加密备份不完整或格式无效。';

  @override
  String get backupEncryptionUnsupported => '此加密备份需要更新版本的 Kelivo。';

  @override
  String get backupProgressEncrypting => '正在加密备份';

  @override
  String get backupProgressDecrypting => '正在解密备份';

  @override
  String get mcpPageStatusFailed => '连接失败';

  @override
  String mcpPageCardToolsShort(int enabled, int total) {
    return '工具 $enabled/$total';
  }

  @override
  String mcpPageSelectServer(String name) {
    return '选择 $name';
  }

  @override
  String get mcpIconTitle => '服务器图标';

  @override
  String get mcpIconInvalid => '无法使用此图片，请选择不超过 10 MB 的有效图片。';

  @override
  String get mcpSelectServers => '选择服务器';

  @override
  String get mcpMoveToGroup => '移到分组';

  @override
  String get mcpRenameGroup => '重命名分组';

  @override
  String get mcpDeleteGroupConfirm => '组内服务器将移至「其他」，不会删除服务器。';

  @override
  String get mcpGroupNameInvalid => '请输入非空且不重复的分组名称。';

  @override
  String get mcpEnableSelected => '启用';

  @override
  String get mcpDisableSelected => '停用';

  @override
  String mcpDeleteSelectedConfirm(int count) {
    return '删除选中的 $count 个服务器？';
  }

  @override
  String get browserTitle => '浏览器';

  @override
  String get browserSearchHint => '搜索或输入网址';

  @override
  String get browserStartTitle => '下一站，去哪里？';

  @override
  String get browserStartSubtitle => '自由浏览，也可以让 Agent 帮你探索。';

  @override
  String get browserNewTab => '新建标签页';

  @override
  String get browserTabs => '标签页';

  @override
  String get browserCloseTab => '关闭标签页';

  @override
  String get browserClose => '关闭浏览器';

  @override
  String get browserBack => '后退';

  @override
  String get browserForward => '前进';

  @override
  String get browserReload => '重新加载';

  @override
  String get browserStop => '停止加载';

  @override
  String get browserMore => '更多';

  @override
  String get browserBookmarks => '书签';

  @override
  String get browserHistory => '历史记录';

  @override
  String get browserSettings => '浏览器设置';

  @override
  String get browserAddBookmark => '添加书签';

  @override
  String get browserRemoveBookmark => '移除书签';

  @override
  String get browserNoBookmarks => '收藏的网站会显示在这里。';

  @override
  String get browserNoHistory => '浏览记录会显示在这里。';

  @override
  String get browserSearchLibrary => '搜索已保存的页面';

  @override
  String get browserClearHistory => '清空历史记录';

  @override
  String get browserClearHistoryConfirm => '删除全部浏览记录？书签会保留。';

  @override
  String get browserToday => '今天';

  @override
  String get browserYesterday => '昨天';

  @override
  String get browserDelete => '删除';

  @override
  String get browserCancel => '取消';

  @override
  String get browserDone => '完成';

  @override
  String get browserFind => '在页面中查找';

  @override
  String get browserFindPreviousMatch => '上一个匹配项';

  @override
  String get browserFindNextMatch => '下一个匹配项';

  @override
  String get browserFindHint => '查找文字';

  @override
  String get browserSearchEngine => '搜索引擎';

  @override
  String get browserDesktopMode => '桌面版网站';

  @override
  String get browserDesktopModeDescription => '使用桌面版用户代理重新加载页面。';

  @override
  String get browserRestoreTabs => '恢复标签页';

  @override
  String get browserRestoreTabsDescription => '启动 Kelivo 时恢复上次的标签页。';

  @override
  String get browserSaveHistory => '保存浏览记录';

  @override
  String get browserSaveHistoryDescription => '在本地记录访问过的页面。';

  @override
  String get browserClearData => '清除网站数据';

  @override
  String get browserClearDataConfirm =>
      '清除 Cookie、网站存储和缓存，并关闭全部标签页？网站登录状态也会清除。';

  @override
  String get browserDataCleared => '已清除网站数据';

  @override
  String get browserAgentControl => 'Agent 控制';

  @override
  String get browserAgentWorking => 'AI 正在操作';

  @override
  String get browserTakeOver => '接管';

  @override
  String get browserAgentPaused => 'AI 操作已暂停';

  @override
  String get browserAllowAgent => '允许继续';

  @override
  String get browserAgentDescription =>
      '在聊天中发送任务后，AI 才会操作浏览器。允许继续只解除暂停，不会自动发送消息或启动任务。';

  @override
  String get browserOpenExternal => '在默认浏览器打开';

  @override
  String get browserCopyLink => '复制链接';

  @override
  String get browserLinkCopied => '已复制链接';

  @override
  String get browserUnsupported => '此平台暂不支持内置浏览器。';

  @override
  String get browserLoadFailed => '无法加载此页面';

  @override
  String get browserRetry => '重试';

  @override
  String get browserFavorites => '个人收藏';

  @override
  String get browserEditBookmark => '编辑书签';

  @override
  String get browserBookmarkTitle => '标题';

  @override
  String get browserBookmarkUrl => '网址';

  @override
  String get browserSave => '保存';

  @override
  String get browserDownloads => '下载';

  @override
  String get browserNoDownloads => '下载的文件会显示在这里。';

  @override
  String get browserDownloadCancel => '取消下载';

  @override
  String get browserOpenDownload => '打开文件';

  @override
  String get browserDownloadFailed => '下载失败';

  @override
  String get browserAgentEnableHint => '在聊天工具中启用浏览器工具，再在这里允许控制。';

  @override
  String get browserSessionRequired => '从一个对话中打开浏览器，即可允许 Agent 控制。';

  @override
  String get browserDownloadCancelled => '已取消';

  @override
  String get browserAgentEnabled => '允许助手使用浏览器';

  @override
  String get browserAgentEnabledDescription => '开启后，助手可以浏览并操作这个浏览器中的页面。';

  @override
  String get browserToolTitle => '浏览器控制';

  @override
  String get browserToolSubtitle => '浏览并操作浏览器中已登录的网页。请先在浏览器设置中开启 Agent 控制。';

  @override
  String get browserOpen => '打开浏览器';

  @override
  String get browserInvalidUrl => '请输入有效的 HTTP 或 HTTPS 网址。';

  @override
  String get browserClearDataUnavailable => 'Windows 浏览器引擎暂不支持清除全部网站数据。';

  @override
  String get browserSurfaceStyle => '表面样式';

  @override
  String get browserSurfaceLiquid => '液态玻璃';

  @override
  String get browserSurfaceFrosted => '磨砂';

  @override
  String get browserSurfaceSolid => '纯色';

  @override
  String get browserPageOptions => '页面选项';

  @override
  String get browserAskAi => '让 AI 处理此页';

  @override
  String get browserAskAiHint => '返回聊天，补充需求后发送。';

  @override
  String get browserAskAiCurrentPage => '浏览器当前页面';

  @override
  String get browserAskAiUnavailable => '当前会话不可用，请先从聊天中打开浏览器。';

  @override
  String get browserAskAiEditing => '请先完成或取消正在编辑的消息，再添加网页任务。';

  @override
  String get browserAskAiAssistantDisabled => '请先在此助手的工具中开启“浏览器控制”。';

  @override
  String get browserAskAiBrowserDisabled => '请先在浏览器设置中允许助手使用浏览器。';

  @override
  String browserAskAiDraft(String page) {
    return '请使用浏览器处理这个页面：\n$page\n\n我的需求：';
  }

  @override
  String get browserOpenFullPage => '完整页面打开';

  @override
  String get browserClosePanel => '关闭浏览器面板';

  @override
  String get browserSearchTabs => '搜索标签页';

  @override
  String browserTabsCount(int count) {
    return '$count 个标签页';
  }

  @override
  String get browserOpenInSidebar => '在侧栏打开';

  @override
  String get browserUserAgent => '用户代理（UA）';

  @override
  String get browserUserAgentMobile => '移动端';

  @override
  String get browserUserAgentDesktop => '桌面端';

  @override
  String get browserUserAgentCustom => '自定义';

  @override
  String get browserUserAgentHint => '输入自定义 User-Agent';

  @override
  String get browserUserAgentInvalid =>
      'UA 仅支持可打印 ASCII 字符（英文字母、数字和英文符号），最多 2048 个字符。';

  @override
  String get browserUserAgentDescription => '更改后将重新加载当前网页。';

  @override
  String browserStepsShowEarlier(int count) {
    return '更早的 $count 步';
  }

  @override
  String get browserOpenThisPage => '在浏览器中打开';

  @override
  String get browserGroupToggleSemantics => '展开或收起浏览步骤';

  @override
  String get browserStepGroupTitle => '浏览网页';

  @override
  String browserStepCount(int count) {
    return '$count 步';
  }

  @override
  String browserStepCurrent(int count) {
    return '第 $count 步';
  }

  @override
  String browserActionFailedCount(int count) {
    return '· $count 步失败';
  }

  @override
  String browserActionFailed(String action) {
    return '$action失败';
  }

  @override
  String get browserCardOpen => '打开';

  @override
  String get browserCardEnable => '去开启';

  @override
  String browserCardRunning(String action) {
    return '正在$action…';
  }

  @override
  String get browserCardLive => '实时';

  @override
  String get browserCardOpenFailed => '未能打开页面';

  @override
  String get browserCardBlankPage => '空白页';

  @override
  String browserCardTabCount(int count) {
    return '$count 个标签页';
  }

  @override
  String get browserActionOpen => '打开网页';

  @override
  String get browserActionNewTab => '新建标签页';

  @override
  String get browserActionRender => '渲染页面';

  @override
  String get browserActionExtract => '提取正文';

  @override
  String get browserActionSnapshot => '读取页面结构';

  @override
  String get browserActionClick => '点击';

  @override
  String get browserActionType => '输入文字';

  @override
  String get browserActionPress => '按键';

  @override
  String get browserActionScroll => '滚动页面';

  @override
  String get browserActionWait => '等待页面';

  @override
  String get browserActionBack => '后退';

  @override
  String get browserActionForward => '前进';

  @override
  String get browserActionReload => '刷新页面';

  @override
  String get browserActionEvaluate => '执行脚本';

  @override
  String get browserActionSwitchTab => '切换标签页';

  @override
  String get browserActionCloseTab => '关闭标签页';

  @override
  String get browserActionListTabs => '查看标签页';

  @override
  String get browserActionUnknown => '浏览器操作';

  @override
  String browserMetaChars(String count) {
    return '$count 字';
  }

  @override
  String browserMetaElements(int count) {
    return '$count 个元素';
  }

  @override
  String get browserErrAgentDisabled => '浏览器控制未开启';

  @override
  String get browserErrStaleRef => '元素已失效，需重新读取页面';

  @override
  String get browserErrNotVisible => '元素不可见或被遮挡';

  @override
  String get browserErrNotFound => '未找到元素';

  @override
  String get browserErrTimeout => '页面加载超时';

  @override
  String get browserErrHumanControl => '你正在接管浏览器';

  @override
  String get browserErrTabClosed => '标签页已关闭';

  @override
  String get browserErrGeneric => '操作失败';

  @override
  String get browserDirectionUp => '上';

  @override
  String get browserDirectionDown => '下';

  @override
  String get browserDirectionLeft => '左';

  @override
  String get browserDirectionRight => '右';

  @override
  String browserMetaTabs(int count) {
    return '$count 个';
  }

  @override
  String get browserTabsCurrentConversation => '当前对话';

  @override
  String get browserTabsAll => '全部标签';

  @override
  String get browserTabsUnassigned => '个人标签';

  @override
  String get browserTabsUnknownConversation => '其他对话';

  @override
  String get browserTabsEmptyConversation => '这里还没有标签页。打开网页，或从「全部标签」中选择已有页面。';

  @override
  String get browserTabsNoResults => '没有匹配的标签页';

  @override
  String get browserMoveToConversation => '移到当前对话';

  @override
  String get browserReopenInConversation => '在当前对话重新打开';

  @override
  String get browserTabBusy => '助手仍在操作此页面，请等待任务完成或停止任务后再移动。';

  @override
  String get browserLiveViewLimit => '浏览器资源正在使用中，请等待任务结束后重试，或关闭不需要的页面。';

  @override
  String get browserAskAiInOwnerConversation => '让所属对话的 AI 处理';

  @override
  String get displaySettingsPageShowBrowserPageCardsTitle => '显示网页卡片';

  @override
  String get browserObserverHint => 'AI 正在操作此页面，点击“接管”后可以操作网页。';

  @override
  String get genuiSurfaceTitle => '交互界面';

  @override
  String get genuiStatusStreaming => '生成中';

  @override
  String get genuiStatusInterrupted => '已中断';

  @override
  String get genuiStatusUnsaved => '尚未保存';

  @override
  String get genuiStatusUnsavedRetry => '点击重试保存';

  @override
  String get genuiReadOnlyUntilComplete => '生成完成后可操作';

  @override
  String get genuiReadOnlySnapshot => '只读快照';

  @override
  String genuiPendingNode(String id) {
    return '等待 $id';
  }

  @override
  String get genuiViewSource => '查看源码';

  @override
  String get genuiCopySource => '复制源码';

  @override
  String get genuiExpand => '展开';

  @override
  String get genuiExpandedStub => '正在展开视图中操作';

  @override
  String get genuiMore => '更多';

  @override
  String get genuiReset => '重置为默认值';

  @override
  String get genuiRepair => '修复界面';

  @override
  String get genuiInvalidTitle => '这段界面无法渲染';

  @override
  String genuiNodesFailed(int count) {
    return '$count 个节点无法显示';
  }

  @override
  String genuiErrorLine(int line) {
    return '第 $line 行';
  }

  @override
  String get genuiValueUnavailable => '无值';

  @override
  String get genuiFormulaInvalid => '这条公式无法显示';

  @override
  String get genuiNodeUnavailable => '此组件无法显示';

  @override
  String get genuiErrorHeader => '界面首行格式无效';

  @override
  String get genuiErrorVersion => '不支持此界面语言版本';

  @override
  String get genuiErrorCatalog => '不支持此组件目录';

  @override
  String get genuiErrorRoot => '根组件缺失或无效';

  @override
  String get genuiErrorSyntax => '声明格式不正确';

  @override
  String get genuiErrorDuplicateSymbol => '同一名称被重复定义';

  @override
  String get genuiErrorDuplicateProperty => '同一属性被重复定义';

  @override
  String get genuiErrorReservedName => '此名称是保留名称';

  @override
  String genuiErrorUnknownComponent(String detail) {
    return '未知组件 $detail';
  }

  @override
  String genuiErrorUnknownProperty(String detail) {
    return '未知属性 $detail';
  }

  @override
  String genuiErrorMissingProperty(String detail) {
    return '缺少必需属性 $detail';
  }

  @override
  String get genuiErrorBinding => '输入绑定不是有效的可写状态';

  @override
  String get genuiErrorReference => '组件引用无效';

  @override
  String get genuiErrorMissingReference => '被引用的内容尚未定义';

  @override
  String get genuiErrorDependency => '依赖的内容无法显示';

  @override
  String get genuiErrorCycle => '不支持循环引用';

  @override
  String get genuiErrorDuplicateParent => '同一组件不能出现在两个位置';

  @override
  String get genuiErrorUnreachableNode => '此组件未包含在根组件中';

  @override
  String get genuiErrorType => '值的类型不匹配';

  @override
  String get genuiErrorValue => '值不在支持的选项或范围内';

  @override
  String get genuiErrorSourceBudget => '界面源码超过大小上限';

  @override
  String get genuiErrorDeclarationBudget => '单条声明超过大小上限';

  @override
  String get genuiErrorDeclarationCount => '声明数量超过上限';

  @override
  String get genuiErrorComponentCount => '组件数量超过上限';

  @override
  String get genuiErrorInputCount => '输入数量超过上限';

  @override
  String get genuiErrorComponentDepth => '组件嵌套过深';

  @override
  String get genuiErrorExpressionDepth => '计算嵌套过深';

  @override
  String get genuiErrorFunction => '计算函数不受支持';

  @override
  String get genuiErrorAction => '此操作不受支持';

  @override
  String get genuiErrorNestedSample => '不支持嵌套采样';

  @override
  String get genuiErrorSample => '采样区间或数量无效';

  @override
  String get genuiErrorDataBudget => '数据超过支持的大小';

  @override
  String get genuiErrorRowKey => '每行需要唯一且非空的标识';

  @override
  String get genuiErrorDomain => '该值不在函数定义域内';

  @override
  String get genuiErrorDivisionByZero => '不能除以零';

  @override
  String get genuiErrorNonFinite => '计算结果不是有限数值';

  @override
  String get genuiErrorOperationsBudget => '计算操作量超过上限';

  @override
  String genuiMetricTrend(String value) {
    return '变化 $value';
  }

  @override
  String genuiFormErrorsLeft(int count) {
    return '还有 $count 项需要修改';
  }

  @override
  String get genuiFieldRequired => '必填';

  @override
  String genuiNumberRange(String min, String max) {
    return '范围 $min–$max';
  }

  @override
  String genuiNumberMinimum(String min) {
    return '最小值 $min';
  }

  @override
  String genuiNumberMaximum(String max) {
    return '最大值 $max';
  }

  @override
  String genuiFieldTooShort(int min) {
    return '至少 $min 个字符';
  }

  @override
  String genuiFieldTooLong(int max) {
    return '最多 $max 个字符';
  }

  @override
  String get genuiInvalidNumber => '请输入完整的有限数值';

  @override
  String get genuiChooseOption => '请选择一项';

  @override
  String get genuiFinishComposing => '请先完成输入法组字';

  @override
  String genuiActionDisabledDep(String id) {
    return '已停用：依赖的 $id 无法显示';
  }

  @override
  String get genuiActionUnavailable => '此视图暂不支持这项操作';

  @override
  String get genuiActionDisabled => '此界面已停用该操作';

  @override
  String get genuiFormUnavailable => '此表单包含无法显示的内容';

  @override
  String genuiDecrease(String label) {
    return '减少 $label';
  }

  @override
  String genuiIncrease(String label) {
    return '增加 $label';
  }

  @override
  String genuiCharacterCount(int used, int max) {
    return '$used / $max 个字符';
  }

  @override
  String get genuiBlockLimit => '每条消息最多渲染 3 个界面，其余以源码显示';

  @override
  String get genuiChartLine => '折线图';

  @override
  String get genuiChartArea => '面积图';

  @override
  String get genuiChartBar => '柱状图';

  @override
  String get genuiChartScatter => '散点图';

  @override
  String get genuiChartPie => '饼图';

  @override
  String get genuiChartDonut => '环形图';

  @override
  String get genuiChartEmpty => '所选区间没有数据';

  @override
  String get genuiChartAllHidden => '所有系列均已隐藏，可通过图例显示。';

  @override
  String genuiChartSummary(String kind, int series, int points, int missing) {
    return '$kind，$series 个系列，$points 行数据，$missing 个值缺失（未连线，未填零）。';
  }

  @override
  String genuiChartPieSummary(String kind, int count, String total) {
    return '$kind，$count 项，合计 $total。';
  }

  @override
  String get genuiChartDomainGap => '未定义';

  @override
  String genuiChartDomainSummary(int count) {
    return '$count 个采样点无定义；阴影区域不连线。';
  }

  @override
  String genuiChartShowSeries(String name) {
    return '显示 $name';
  }

  @override
  String genuiChartHideSeries(String name) {
    return '隐藏 $name';
  }

  @override
  String get genuiChartKeyboardHint => '左右方向键选择数据行，上下方向键选择系列，Esc 清除选择。';

  @override
  String get genuiChartTotal => '合计';

  @override
  String get genuiChartFieldsError => '请选择一个 X 字段和一到四个不同的 Y 字段。';

  @override
  String get genuiChartRecordsError => '图表数据必须是记录数组。';

  @override
  String get genuiChartXError => 'X 值须全为数值或全为文本；散点图必须使用数值。';

  @override
  String get genuiChartYError => 'Y 字段须存在，且只能包含数值或空值。';

  @override
  String get genuiChartPieError => '饼图数值必须非负，且总和须为大于零的有限数。';

  @override
  String genuiChartMissingValues(int count) {
    return '$count 个值缺失，未填零。';
  }

  @override
  String get genuiChartNoVisibleValues => '所选系列没有可绘制的数值。';

  @override
  String genuiChartUnit(String unit) {
    return '单位：$unit';
  }

  @override
  String get genuiSomeValuesUnavailable => '部分值无法计算';

  @override
  String get genuiViewChart => '图表';

  @override
  String get genuiViewData => '数据';

  @override
  String get genuiTableFilterHint => '筛选可见文本';

  @override
  String genuiTableRows(int count) {
    return '$count 行';
  }

  @override
  String genuiTablePageInfo(int from, int to, int total) {
    return '第 $from–$to 行，共 $total 行';
  }

  @override
  String genuiTablePerPage(int n) {
    return '$n 行/页';
  }

  @override
  String get genuiTableEmpty => '没有匹配的行';

  @override
  String get genuiSortAsc => '升序';

  @override
  String get genuiSortDesc => '降序';

  @override
  String get genuiSortNone => '未排序';

  @override
  String get genuiValueTrue => '是';

  @override
  String get genuiValueFalse => '否';

  @override
  String get genuiTablePreviousPage => '上一页';

  @override
  String get genuiTableNextPage => '下一页';

  @override
  String get genuiTableCellsError => '表格数据必须是记录数组，单元格只能是有限标量或空值。';

  @override
  String get genuiTableColumnsError => '请选择 1–8 个不同的字段，并提供表头；小数位数可为 0–10。';

  @override
  String get genuiTableRowKeyError => '每行都需要一个非空值的标量标识。';

  @override
  String get genuiViewStateFailed => '保存状态过大，无法更改视图。请缩短输入或重置界面后重试。';

  @override
  String get genuiAttachState => '附带当前界面状态';

  @override
  String get genuiChipExactText => '将随消息发送的准确文本（已冻结）';

  @override
  String get genuiChipStale => '来源已失效 · 请移除或重新附带';

  @override
  String get genuiChipRemove => '移除附带的界面';

  @override
  String get genuiReplaceTitle => '替换已附带的界面？';

  @override
  String get genuiReplaceBody => '一份草稿只能附带一个界面状态。';

  @override
  String get genuiReplaceCurrent => '当前';

  @override
  String get genuiReplaceNew => '替换为';

  @override
  String get genuiReplaceConfirm => '替换';

  @override
  String get genuiMergeTitle => '合并到当前草稿？';

  @override
  String get genuiMergeConfirm => '合并';

  @override
  String get genuiContextEmpty => '没有附带参数或结果字段。';

  @override
  String get genuiContextOmitted => '[部分字段或数据行已省略。]';

  @override
  String get genuiChipOmitted => '此前附带的界面来源已失效，本条消息未附带其状态。';

  @override
  String get genuiDraftChanged => '草稿已发生变化，请重新附带。';

  @override
  String get genuiRepairDraft => '请根据以下诊断和源码片段修复这段界面。';

  @override
  String get genuiCopySourceMarkdown => '复制源码 / Markdown';

  @override
  String get genuiTextFailed => '无法读取界面状态，请重试。';

  @override
  String get genuiCopyLimit => '文本超过 64 KiB 复制上限，请选择较小的片段。';

  @override
  String get genuiExportSnapshot => '导出只读快照';

  @override
  String get genuiExpandedSharedState => '与消息内共享同一状态';

  @override
  String get genuiExportTooLarge => '图片超过 1600 万像素，请减少所选消息或导出较小的界面。';

  @override
  String get genuiWebTitle => '网页预览';

  @override
  String get genuiWebOpen => '打开';

  @override
  String get genuiWebNotReady => '生成完成后才可打开';

  @override
  String get genuiWebInvalidMeta => '首行元信息无效，未加载';

  @override
  String get genuiWebSandboxNote => '沙盒预览 · 关闭后不保留';

  @override
  String get genuiWebUnsupported => '此平台暂不支持内嵌网页预览，可导出后在浏览器中打开';

  @override
  String get genuiWebExportHtml => '导出 HTML';

  @override
  String get genuiWebInfo => '预览说明';

  @override
  String get genuiWebCspNote => 'CSP: default-src \'none\' · 限制网络访问 · 独立页面状态';

  @override
  String get genuiWebFailed => '预览初始化或加载失败。可查看或复制源码。';

  @override
  String get genuiWebEmpty => '元信息后没有 HTML 内容';

  @override
  String get genuiWebBlockLimit => '每条消息最多渲染 3 个网页预览，其余以源码显示';

  @override
  String get genuiWebCloseFailed => '无法确认上一个预览已关闭。请重启应用后再打开。';

  @override
  String get displaySettingsShowGenUiHeader => '显示交互界面标题栏';

  @override
  String get displaySettingsShowGenUiHeaderSubtitle =>
      '关闭后更沉浸；源码与操作仍可从界面底部的更多菜单访问。';

  @override
  String get genuiClearFilter => '清除筛选';

  @override
  String get genuiClearSelection => '清除选择';

  @override
  String get chatInputBarQueuedPausedReason => '压缩未完成，不会自动发送';

  @override
  String get contextChanged => '历史已发生变化，请重新打开此操作并确认范围。';

  @override
  String get contextOperationSuperseded => '已并入后续摘要';

  @override
  String get compressIncludeAttachments => '附件文字与工具结果';

  @override
  String contextEditCharacters(int count) {
    return '$count 字';
  }

  @override
  String get compressOverSnack => '摘要过长，应用后会超出上下文上限，未应用';

  @override
  String get contextSummaryHint => '这是后续请求实际使用的摘要，保存不会改写已有回复。附件仅使用已有文字，不会额外识图。';

  @override
  String get compressAdvanced => '高级选项';

  @override
  String get compressTaskWaiting => '等待当前回复完成';

  @override
  String get contextBudgetExceeded => '预计上下文超过当前模型上限，请缩短摘要、重新压缩或选择上下文更大的模型。';

  @override
  String get contextManualSupplement => '将手工编辑的摘要作为补充';

  @override
  String get contextDetailEdited => '已人工编辑';

  @override
  String get contextSourceLabel => '摘要来源';

  @override
  String get contextImpactSourceTitle => '修改已压缩的原文？';

  @override
  String get chatInputBarQueuedCompressionFailed => '压缩失败，不会自动发送';

  @override
  String contextTokenInfo(int before, int after) {
    return '摘要输入约 $before tokens → 摘要约 $after tokens';
  }

  @override
  String get worldBookTransferFailed => '保存条目失败，请重试。';

  @override
  String contextDetailKeptCount(int count) {
    return '最近 $count 条用户消息及其回复、工具过程';
  }

  @override
  String get toolPermissionRequestApproval => '请求批准';

  @override
  String get compressNothingNew => '自上次压缩后没有新的可压缩内容';

  @override
  String get browserActionScreenshot => '截取页面';

  @override
  String get displaySettingsPageIosNativeSelectionMenuSubtitle =>
      '用于输入框和消息选区；如遇卡顿可关闭，恢复原菜单。';

  @override
  String contextUndoneSnack(String from, String to) {
    return '已撤销 · $from → $to';
  }

  @override
  String get toolApprovalByFullAccess => '已自动执行';

  @override
  String get displaySettingsPageAutoScrollSubtitle =>
      '开启后，流式输出时位于底部会自动跟随。上滑后保持阅读位置，主动回到底部后才继续跟随；关闭后不随新内容自动滚动。';

  @override
  String get toolApprovalRealTarget => '实际目标';

  @override
  String get compressTaskRetry => '重试';

  @override
  String get wsDeniedPathOutside => '目标不在授权区域内，已拒绝。';

  @override
  String contextImpactSaveConfirm(int count) {
    return '保存并撤销 $count 个节点';
  }

  @override
  String get contextRestore => '恢复';

  @override
  String compressUsageOriginal(String value) {
    return '原 $value';
  }

  @override
  String toolApprovalPendingKind(String kind) {
    return '等待审批 · $kind';
  }

  @override
  String get contextTaskApplying => '正在应用摘要';

  @override
  String get storageSpaceImagesHint => '删除会影响聊天图片和工具结果。正在使用的头像与背景会受到保护。';

  @override
  String get displaySettingsPageIosNativeSelectionMenuTitle => 'iOS 26+ 原生选择菜单';

  @override
  String get worldBookMoveEntries => '移动到…';

  @override
  String get compressReread => '重新读取已压缩的原始消息';

  @override
  String get chatInputBarQueuedPausedHold => '待发内容保持暂停，请取消排队后编辑或发送';

  @override
  String get contextSummaryTitle => '压缩摘要';

  @override
  String get contextKeepInvalid => '请输入正整数的用户消息数量。';

  @override
  String get compressTaskAbandon => '放弃';

  @override
  String get browserAgentTimedOut => '操作超时，AI 已暂停';

  @override
  String get compressCancelledSnack => '已取消压缩，当前上下文未改变';

  @override
  String get contextImpactClearTitle => '撤销较早的清除？';

  @override
  String get compressTaskWaitingApproval => '等待工具审批完成';

  @override
  String get contextTaskFailed => '压缩失败';

  @override
  String get wsDeniedSkillsReadonly => '技能目录只读。';

  @override
  String get compressTaskMerging => '正在合并摘要';

  @override
  String get toolPermissionFullAccessDesc =>
      '允许此对话直接访问本机文件、运行命令及使用已启用的联网工具，不再逐次询问。';

  @override
  String get compressStaleSnack => '聊天内容已变化，压缩结果未应用';

  @override
  String get worldBookCopyEntries => '复制到…';

  @override
  String get contextEditEmpty => '摘要不能为空。如需丢弃全部旧历史，请使用“清空上下文”。';

  @override
  String get toolApprovalDenyWithReason => '拒绝并说明原因…';

  @override
  String get toolApprovalRequestedPath => '请求路径';

  @override
  String get toolApprovalScopeOnce => '仅授权本次调用';

  @override
  String get storageSpaceImageTypeLabel => '类型';

  @override
  String get contextImpactUndoTitle => '撤销较早的压缩？';

  @override
  String get contextOriginalMessages => '查看原始消息';

  @override
  String storageSpaceDeleteImagesConfirmMessage(int count) {
    return '删除 $count 张图片？相关聊天图片、工具截图及其会话副本将无法再查看或使用。正在使用的头像与背景会保留。';
  }

  @override
  String get chatInputBarQueuedAfterCompress => '压缩完成后发送';

  @override
  String get toolPermissionFullAccessDescMobile =>
      '允许此对话在沙箱和已授权文件夹内自动执行工具，不再逐次询问。';

  @override
  String get compressTaskAdjustRetry => '调整选项后重试';

  @override
  String get contextDetailLegacy => '由旧版清除位置转换';

  @override
  String get contextDetailCurrent => '当前上下文';

  @override
  String get toolPermissionUndo => '撤销';

  @override
  String get contextDetailViewOriginals => '查看被压缩的原文';

  @override
  String get contextTaskCompleted => '压缩已完成';

  @override
  String get chatInputBarQueuedPaused => '已暂停';

  @override
  String get contextCompressMarker => '上下文已压缩';

  @override
  String contextDetailParts(int count) {
    return '自动分 $count 段';
  }

  @override
  String get contextEditPending => '已保存，当前回复结束后生效';

  @override
  String get contextTaskRetry => '重试压缩';

  @override
  String get contextUndoCompressTooltip => '撤销此次压缩';

  @override
  String get contextDividerCompressed => '压缩上下文';

  @override
  String compressSuccessSnack(String from, String to) {
    return '上下文已压缩 · $from → $to';
  }

  @override
  String get contextEffectiveHistory => '当前摘要及后续消息';

  @override
  String get compressRereadAll => '本段全部原文';

  @override
  String get contextDone => '完成';

  @override
  String get contextMore => '更多';

  @override
  String compressFailedSnack(String reason) {
    return '压缩失败：$reason';
  }

  @override
  String get branchInheritNote => '只继承此处之前有效的上下文节点';

  @override
  String get contextTaskInterrupted => '压缩已中断，输入内容已保留';

  @override
  String get storageSpaceImageTypeAll => '全部';

  @override
  String contextRangeInfo(int count, int keep) {
    return '替代 $count 条消息；原样保留最近 $keep 条用户消息及后续回复。';
  }

  @override
  String contextInputModeInfo(String mode, String source) {
    return '摘要输入：$mode · $source';
  }

  @override
  String get contextDetailKept => '原样保留';

  @override
  String worldBookEntriesCopied(int count) {
    return '已复制 $count 个条目';
  }

  @override
  String get toolPermissionSaveFailed => '保存失败，权限未更改。';

  @override
  String get compressDiscardedSnack => '已清空上下文，进行中的压缩已废弃';

  @override
  String get browserActionSelect => '选择选项';

  @override
  String get toolPermissionTitle => '权限';

  @override
  String get contextDetailNext => '下次请求';

  @override
  String get contextTaskCancel => '取消压缩';

  @override
  String get toolPermissionFullAccess => '完全访问';

  @override
  String get chatInputBarQueuedCompressionCancelled => '压缩已取消，不会自动发送';

  @override
  String get toolPermissionResetSnack => '已更换工作区 · 此对话权限已恢复为请求批准';

  @override
  String get contextImpactUndoOne => '撤销';

  @override
  String get contextDetailContinueNewChat => '在新聊天继续';

  @override
  String get contextTaskPaused => '发送已暂停，可取消排队恢复编辑';

  @override
  String get contextTaskReview => '请检查摘要后再应用';

  @override
  String compressApproxTokens(String value) {
    return '约 $value tokens';
  }

  @override
  String get storageSpaceImageInUseHint => '请先在对应设置中更换或移除头像、背景或图标，再删除。';

  @override
  String get compressRereadLastLayer => '展开最近一层压缩';

  @override
  String get contextRestoreOperation => '恢复操作';

  @override
  String get contextOriginalHistory => '重新读取本段全部原文';

  @override
  String get contextImpactEditTitle => '保存较早的摘要？';

  @override
  String get contextOpenNewChat => '打开新聊天';

  @override
  String get wsPathChanged => '审批期间目标已变化。';

  @override
  String get contextEditUnknownPreview => '用量暂不可用，保存前会重新检查。';

  @override
  String get contextTaskWait => '等待当前回复和工具执行结束';

  @override
  String compressTaskElapsed(int i, int n, int seconds) {
    return '第 $i/$n 段 · 已用 $seconds 秒';
  }

  @override
  String get wsContextChanged => '对话上下文已变化，请求失效。';

  @override
  String contextChangeImpact(int count) {
    return '此次修改还会撤销 $count 个受影响的上下文操作，原始消息保留。是否继续？';
  }

  @override
  String get contextImpactSave => '保存';

  @override
  String contextTaskProgress(int done, int total) {
    return '正在压缩 $done/$total 段';
  }

  @override
  String get contextSummaryNotSmaller => '摘要没有比输入更短，请检查后再应用。';

  @override
  String get storageSpaceImageTypeTool => '工具图片';

  @override
  String get contextPreviousHistory => '重新读取最近一层压缩原文';

  @override
  String get contextDetailRead => '实际读取';

  @override
  String get contextViewGenerated => '查看已生成摘要';

  @override
  String get contextImpactDeleteDescription =>
      '删除原文时，一并撤销相关摘要及依赖后继，避免继续发送残留内容。其他消息与独立节点保持不变。';

  @override
  String get storageSpaceImageTypeAvatar => '头像与背景';

  @override
  String get contextDetailAfterUndo => '撤销后';

  @override
  String get contextOperationUndo => '撤销此次上下文操作';

  @override
  String contextHistoryWindowNote(int count) {
    return '原样保留的历史仍受当前聊天“最多发送 $count 条消息”的限制。';
  }

  @override
  String get contextOverLimitWarning => '撤销后可能超出模型上下文上限，建议重新压缩。仍可撤销，发送前会再次检查。';

  @override
  String get storageSpaceImageTypeChat => '聊天图片';

  @override
  String get worldBookSelectEntries => '多选条目';

  @override
  String get compressUsageSummary => '预计摘要';

  @override
  String contextDetailRange(String from, String to, int count) {
    return '第 $from–$to 条 · $count 条用户消息';
  }

  @override
  String get contextOperationHidden => '已被后续清除隔开';

  @override
  String get contextUndoClearTooltip => '撤销此次清除';

  @override
  String compressKeepDescription(int count) {
    return '保留最近 $count 条用户消息及其回复、工具过程；更早内容由摘要替代。纯附件消息也算一条。';
  }

  @override
  String get contextOperationUndone => '已撤销';

  @override
  String contextEditPreview(String value) {
    return '保存后约 $value tokens。输入时不影响当前生效内容。';
  }

  @override
  String get contextDetailExcluded => '不再发送';

  @override
  String get worldBookNoMoveTargets => '请先创建另一本世界书，再移动条目。';

  @override
  String worldBookSelectedEntries(int count) {
    return '已选择 $count 项';
  }

  @override
  String get contextDetailReplaced => '被替代范围';

  @override
  String get displaySettingsPageAutoScrollEnabledLabel => '开启';

  @override
  String get contextChangeTitle => '确认上下文影响';

  @override
  String get contextDetailTitle => '压缩摘要';

  @override
  String get compressModelGlobal => '全局设置 · 本次启动后固定';

  @override
  String get wsDeniedMountReadonly => '只读挂载，不能写入。';

  @override
  String get compressRereadDesc => '处理多次压缩造成的信息损失，会增加本次用量';

  @override
  String get toolApprovalSwitchToFullAccess => '切换到完全访问';

  @override
  String get compressUsageInput => '本次摘要输入';

  @override
  String get contextDetailSummaryLabel => '实际用于后续请求的摘要';

  @override
  String get contextImpactDeleteTitle => '删除已压缩的原文？';

  @override
  String get compressAdvancedOff => '重读原文 关';

  @override
  String get contextOperationActive => '当前生效';

  @override
  String get compressAdvancedOn => '重读原文 开';

  @override
  String get contextTaskMerging => '正在合并摘要';

  @override
  String contextSampledInfo(int count) {
    return '本次只读取选定的 $count 字符，摘要会替代整个选定历史范围。';
  }

  @override
  String get contextDividerRunning => '正在压缩上下文';

  @override
  String get contextClearDetails => '此前聊天历史不再参与后续请求；系统提示、记忆和工具定义仍然生效。';

  @override
  String get compressCopyResult => '复制结果';

  @override
  String get contextDetailInUse => '当前直接使用';

  @override
  String get contextImpactDescription =>
      '相关摘要将一并撤销；原始聊天消息保留，不会自动调用模型。独立的上下文节点保持不变。';

  @override
  String get compressIncludeAttachmentsDesc =>
      '纳入已有附件文字、工具参数与结果；过长内容会截断并标明，不会重新识图。';

  @override
  String worldBookEntriesMoved(int count) {
    return '已移动 $count 个条目';
  }

  @override
  String get contextImpactSourceDescription =>
      '确认后变更原文，并撤销概括过它的摘要及依赖后继。其他消息与独立节点保留，不会自动调用模型。';

  @override
  String get contextEditTitle => '编辑摘要';

  @override
  String get compressUsageNext => '生效后下次请求';

  @override
  String get contextSummaryEmpty => '摘要不能为空；需要排除历史时请使用清除上下文。';

  @override
  String get toolApprovalDenied => '已拒绝';

  @override
  String get contextDetailModel => '模型 · 时间';

  @override
  String compressIncludeManual(int count) {
    return '纳入人工补充 · $count 份';
  }

  @override
  String contextBudgetInfo(int used, String limit) {
    return '下次请求估算（含输出预留）：$used / $limit tokens';
  }

  @override
  String get contextTaskDismiss => '关闭状态提示';

  @override
  String contextUndoBudgetInfo(int used) {
    return '撤销后预计约 $used tokens（含输出预留）';
  }

  @override
  String get storageSpaceImageInUse => '使用中';

  @override
  String get worldBookSelectionDone => '完成';

  @override
  String get contextDividerFailed => '压缩失败';

  @override
  String get toolPermissionUnboundHint => '未绑定工作区：不会因此开启文件或 Shell 工具。';

  @override
  String get contextChangeWaiting => '等待当前回复和工具执行结束后生效。';

  @override
  String storageSpaceDeletedUploadsPartial(int deleted, int kept) {
    return '已删除 $deleted 个项目；保留了 $kept 个正在使用或无法删除的项目。';
  }

  @override
  String get contextSourceScopeHint => '仅处理最近清除边界之后的历史，可能包含平时发送窗口之外的较早消息。';

  @override
  String get contextTaskPreparing => '正在准备压缩';

  @override
  String contextImpactUsage(String from, String to) {
    return '约 $from → $to tokens';
  }

  @override
  String contextImpactConfirm(int count) {
    return '撤销 $count 个节点';
  }

  @override
  String get contextDividerEdited => '已编辑';

  @override
  String get compressAdjust => '调整';

  @override
  String get compressRegenerate => '重新压缩';

  @override
  String get toolPermissionEnabledSnack => '已为此对话启用完全访问';

  @override
  String get contextDetailSuperseded => '已由后续摘要替代';

  @override
  String get contextTaskQueued => '已排队，等待压缩完成';

  @override
  String get contextNewConversation => '使用摘要创建新聊天';

  @override
  String get contextUnknownLimit => '上限未知';

  @override
  String get browserErrActionTimeout => '操作超时，结果未确认，请检查页面后允许继续';

  @override
  String get toolPermissionRequestApprovalDesc =>
      '工作区外文件访问、桌面命令和其他需要授权的工具将在执行前询问。';

  @override
  String get contextLimitedInputHint => '仅读取所选字符范围；被替代历史中的其余内容不会进入摘要，原始消息仍可回看。';

  @override
  String get contextTaskCancelled => '压缩已取消';

  @override
  String get contextDetailClearTitle => '上下文已清除';

  @override
  String get contextImpactKeep => '保持不变';

  @override
  String get contextImpactUndoAlso => '一并撤销';

  @override
  String get contextClearMarker => '上下文已清除';

  @override
  String get toolPermissionScopeThisChat => '仅此对话';

  @override
  String get dataDirectoryTitle => '数据存储目录';

  @override
  String get dataDirectoryChange => '更改目录';

  @override
  String get dataDirectoryChoose => '选择一个空的本地文件夹';

  @override
  String get dataDirectoryHint =>
      '请选择本地磁盘上的空文件夹。聊天记录、附件和应用管理的文件将在重启后搬迁。少量设备设置和系统缓存仍保留在系统目录。';

  @override
  String get dataDirectoryPendingHint => '将在下次重启时搬迁。复制和校验完成前，原数据保持不变。目标目录：';

  @override
  String get dataDirectoryRestart => '重启并搬迁数据';

  @override
  String get dataDirectoryCancelMove => '取消搬迁，继续使用原目录';

  @override
  String get dataDirectoryPreviousHint =>
      '已保留原数据副本。新目录成功启动后，可以清理旧副本以释放磁盘空间。再次更改目录前，请先清理此副本。';

  @override
  String get dataDirectoryCleanPrevious => '清理原数据副本';

  @override
  String get dataDirectoryCleanConfirm =>
      '确定清理以下目录中的原数据副本？当前目录中的数据会保留，搬迁后发生变化的文件不会被删除。';

  @override
  String get dataDirectoryMoving => '正在搬迁并校验数据…请保持 Kelivo 开启。';

  @override
  String get dataDirectoryStartupFailed => '无法打开数据目录';

  @override
  String get dataDirectoryRetry => '重试';

  @override
  String get dataDirectoryUnavailable =>
      '数据目录不可用。请重新连接磁盘，或将文件夹恢复到原位置后重试。应用不会创建空数据库。';

  @override
  String get dataDirectoryIdentityMismatch => '此文件夹与已设置的数据目录不匹配。请恢复原文件夹后重试。';

  @override
  String get dataDirectoryNotEmpty => '请选择空文件夹，不会覆盖已有文件。';

  @override
  String get dataDirectoryOverlap => '请选择当前数据目录之外的独立文件夹，不能选择其上级目录、子目录或磁盘根目录。';

  @override
  String get dataDirectoryLocalOnly => '请选择本地磁盘上的文件夹，不支持网络共享目录。';

  @override
  String get dataDirectoryFinishPrevious => '请先完成或取消待执行的搬迁，并清理保留的旧副本，再选择其他目录。';

  @override
  String get dataDirectoryPendingRestore => '有备份恢复尚未完成。请取消目录搬迁并重启，完成恢复后再更改目录。';

  @override
  String get dataDirectorySourceChanged =>
      '原数据在复制后发生了变化，已保留原文件。若正在搬迁，请取消后重新开始；若正在清理，请先检查原目录。';

  @override
  String get dataDirectoryCopyChanged => '目标目录存在意外文件或文件变化，原数据已保留。请检查目标目录后重试。';

  @override
  String get dataDirectoryGenericError =>
      '操作未完成。请检查磁盘剩余空间、文件夹权限，以及是否有其他 Kelivo 进程运行，然后重试。已有数据已保留。';

  @override
  String get dataDirectoryCancelHint => '取消搬迁会保留目标目录中已复制的文件，你可以检查后手动清理这些副本。';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get settingsSearchHint => '搜尋設定';

  @override
  String get settingsSearchCancel => '取消';

  @override
  String get settingsSearchClear => '清除搜尋';

  @override
  String get settingsSearchSuggestions => '常用設定';

  @override
  String get settingsSearchNoResults => '找不到相關設定';

  @override
  String get settingsSearchNoResultsHint => '試試其他名稱，或更簡短的關鍵字。';

  @override
  String settingsSearchResultCount(int count) {
    return '找到 $count 項設定';
  }

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
  String get storageSpacePageTitle => '儲存空間';

  @override
  String get storageSpaceRefreshTooltip => '重新整理';

  @override
  String get storageSpaceLoadFailed => '無法載入檔案或檢查圖片使用情況，請重新整理後重試。';

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
  String get storageSpaceCategoryDisplacedDatabases => '保留的舊資料庫';

  @override
  String get storageSpaceSubDisplacedDatabases => '自動重建前保留的資料庫';

  @override
  String get storageSpaceClearDisplacedDatabasesConfirmMessage =>
      '確定刪除這些保留的舊資料庫嗎？它們是 Kelivo 重建資料庫時留下的，可能是那些聊天記錄和設定僅存的一份。刪除後無法復原。';

  @override
  String get storageSpaceRestoreTracesHint => '還原完成後保留的舊資料快照。清理不會影響目前的應用程式資料。';

  @override
  String get storageSpaceClearRestoreTracesButton => '清理還原痕跡';

  @override
  String get storageSpaceClearDisplacedDatabasesButton => '刪除保留的舊資料庫';

  @override
  String get storageSpaceClearRestoreTracesConfirmMessage =>
      '確定清理已完成還原留下的舊資料快照嗎？目前的資料庫、設定和檔案不會受到影響。';

  @override
  String get storageSpaceSubCompletedRestoreRuns => '已完成的還原快照';

  @override
  String get storageSpaceCategoryCache => '快取';

  @override
  String get storageSpaceCategoryLogs => '日誌';

  @override
  String get storageSpaceCategoryOther => '其他';

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
    return '刪除 $count 個項目及其對應的對話附件副本？刪除後，聊天記錄中的這些附件將無法使用。';
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
  String statsPageCost(String currency) {
    return '費用 ($currency)';
  }

  @override
  String statsPageModelsWithoutPricing(int count) {
    return '$count 個模型無定價';
  }

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
  String contextMessageCount(int count) {
    return '$count 則訊息';
  }

  @override
  String contextMessageCountLimited(int actual, int configured) {
    return '$actual/$configured 則訊息';
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
  String get mcpServerEditSheetStdioCommandLabel => '命令';

  @override
  String get mcpServerEditSheetStdioArgumentsLabel => '參數';

  @override
  String get mcpServerEditSheetStdioWorkingDirectoryLabel => '工作目錄（可選）';

  @override
  String get mcpWorkspaceBindingLabel => '綁定工作區（可選）';

  @override
  String get mcpWorkspaceBindingHint =>
      '伺服器可透過 /workspace 存取此工作區。工作目錄留空時預設進入該目錄，切換聊天不會改變綁定。';

  @override
  String get mcpWorkspaceBindingMobileOnly =>
      '工作區綁定適用於行動端 Linux 環境。在桌面端執行此伺服器前，請先解除綁定。';

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
  String get assistantEditThinkingBudgetTitle => '思考';

  @override
  String get assistantEditReasoningFollowDefault => '跟隨模型預設';

  @override
  String get assistantEditReasoningClampedSubtitle => '實際檔位會依各模型的能力收斂';

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
  String get iosBackgroundStatusOn => '開啟';

  @override
  String get iosBackgroundStatusOff => '關閉';

  @override
  String get iosLiveActivityTitle => '即時活動';

  @override
  String get iosLiveActivitySubtitle => '支援時在鎖定畫面和動態島顯示後台回覆狀態。';

  @override
  String get notificationChatCompletedTitle => '生成完成';

  @override
  String get notificationChatCompletedBody => '助手回覆已生成';

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
  String get assistantEditPromptIso8601Title => '使用 ISO 8601 格式';

  @override
  String get assistantEditPromptIso8601Subtitle =>
      '包含時區偏移，例如 2026-08-08T14:30:05+08:00';

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
  String get backupPageScopeTitle => '備份與匯入內容';

  @override
  String backupPageScopeSelectedCount(int selected, int total) {
    return '$selected/$total';
  }

  @override
  String get backupPageBackupManagementDescription =>
      '選擇備份和匯入的內容，適用於本機、WebDAV 和 S3。匯入時保留未選取的內容。技能和工作區包含各自的檔案。';

  @override
  String get backupPageAssistantsLabel => '助手';

  @override
  String get backupPageProvidersLabel => '供應商';

  @override
  String get backupPageMcpLabel => 'MCP 伺服器';

  @override
  String get backupPageEnvironmentVariablesLabel => '環境變數';

  @override
  String get backupPageSkillsLabel => '技能';

  @override
  String get backupPageWorldBooksLabel => '世界書';

  @override
  String get backupPageMemoriesLabel => '記憶';

  @override
  String get backupPageQuickPhrasesLabel => '快捷短語';

  @override
  String get backupPageInstructionsLabel => '提示詞注入';

  @override
  String get backupPageWorkspacesLabel => '工作區';

  @override
  String get backupPageSearchServicesLabel => '搜尋服務';

  @override
  String get backupPageSpeechServicesLabel => '語音服務';

  @override
  String get backupPageSettingsLabel => '其他設定';

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
  String get backupRestoreDirectoryBlockedTitle => '還原正在等待資料夾釋放';

  @override
  String get backupRestoreDirectoryBlockedContent =>
      'Windows 無法移動下方資料夾。請關閉正在使用該資料夾的終端機、編輯器或其他程式，然後繼續還原。如果仍然受阻，請檢查目前帳戶是否有移動該資料夾的權限。先前的還原進度已保留。';

  @override
  String get backupRestoreContinueButton => '繼續還原';

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
  String get restoreProgressTitle => '正在還原備份';

  @override
  String get restoreProgressWarning =>
      '請保持 Kelivo 開啟直到完成。此時關閉應用程式，下次啟動會從頭再來一次。';

  @override
  String get restoreProgressStageCheckingBackup => '正在驗證備份';

  @override
  String get restoreProgressStagePreservingCurrentData => '正在保留目前資料';

  @override
  String get restoreProgressStageInstallingBackup => '正在寫入備份';

  @override
  String get restoreProgressStageVerifying => '正在驗證';

  @override
  String get restoreProgressStageRollingBack => '正在還原原有資料';

  @override
  String get restoreProgressStageFinishing => '即將完成';

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
  String get startupRecoveryRepairFailed =>
      '修復未能完成。資料已保留，可選擇通過驗證的副本還原，或匯出資料進一步檢查。';

  @override
  String get startupRecoveryResetFailed => '重設失敗。請完全關閉 Kelivo 後再重新開啟。';

  @override
  String get startupRecoveryResetDialogTitle => '重設全部資料？';

  @override
  String get startupRecoveryResetDialogContent =>
      '開始使用新的空資料庫？目前資料庫及其日誌檔案、既有副本都會保留，以供日後還原。';

  @override
  String get startupRecoveryResetDialogConfirm => '重設並重新啟動';

  @override
  String get startupRecoveryResetDialogCancel => '取消';

  @override
  String get startupRecoveryWhatFailed => '失敗原因';

  @override
  String get startupRecoveryStageLabel => '失敗階段';

  @override
  String get startupRecoveryStageRestore => '還原關卡';

  @override
  String get startupRecoveryStageDatabase => '資料庫啟動';

  @override
  String get startupRecoveryDiagnosticLabel => '診斷碼';

  @override
  String get startupRecoverySchemaLabel => '資料庫版本';

  @override
  String startupRecoverySchemaValue(String installed, int expected) {
    return '磁碟上為 $installed · 目前版本需要 $expected';
  }

  @override
  String get startupRecoveryAppVersionLabel => '應用程式';

  @override
  String get startupRecoveryUnknownValue => '未知';

  @override
  String get startupRecoveryCollecting => '正在收集診斷資訊…';

  @override
  String get startupRecoveryShowDetails => '展開技術細節';

  @override
  String get startupRecoveryHideDetails => '收合技術細節';

  @override
  String get startupRecoveryCopyReport => '複製完整報告';

  @override
  String get startupRecoveryReportCopied => '已複製完整報告';

  @override
  String get startupRecoveryShareReport => '匯出報告';

  @override
  String startupRecoveryReportStored(String path) {
    return '報告已儲存至 $path';
  }

  @override
  String startupRecoveryReportSaved(String path) {
    return '報告已儲存至 $path';
  }

  @override
  String get startupRecoveryReportShared => '報告已匯出。';

  @override
  String get startupRecoveryReportSaveFailed => '無法匯出報告。';

  @override
  String get startupRecoverySectionDataTitle => '你的資料';

  @override
  String get startupRecoverySectionDataBody =>
      '目前沒有任何資料被刪除。在嘗試下方操作前，先把副本存到安全的地方。';

  @override
  String startupRecoveryExportSavedTo(String path) {
    return '資料副本已儲存至 $path';
  }

  @override
  String get startupRecoverySectionRepairTitle => '診斷與修復';

  @override
  String get startupRecoverySectionRepairBody =>
      '完整性檢查只會讀取資料庫。修復會清除上次更新中斷留下的中繼資料並重新啟動，不會刪除聊天記錄。';

  @override
  String get startupRecoveryIntegrityButton => '檢查資料庫完整性';

  @override
  String get startupRecoveryIntegrityHealthy => 'SQLite 未在資料庫檔案中發現損壞。';

  @override
  String startupRecoveryIntegrityDamaged(String detail) {
    return 'SQLite 回報了問題 —— $detail';
  }

  @override
  String get startupRecoveryIntegrityMissing => '資料目錄中找不到資料庫檔案。';

  @override
  String get startupRecoveryIntegrityFailed => '完整性檢查無法執行。';

  @override
  String get startupRecoveryDangerZone => '危險操作';

  @override
  String get startupRecoveryDangerBody =>
      '重新開始後，目前資料將不再顯示。Kelivo 會保留舊資料庫與既有副本以供還原，建議先匯出一份資料副本。';

  @override
  String get startupRecoveryResetAcknowledge => '我確認開始使用新的空資料庫。';

  @override
  String get startupDatabaseUpdateRequiredTitle => '請更新 Kelivo 以繼續';

  @override
  String get startupDatabaseUpdateRequiredContent =>
      '本裝置上的聊天資料庫由更新版本的 Kelivo 建立，目前版本無法開啟。資料未被改動。請安裝最新版 Kelivo 後重新開啟。';

  @override
  String get startupDatabaseUpdateRequiredDowngradeTitle => '若要改用舊版';

  @override
  String get startupDatabaseUpdateRequiredDowngradeIntro =>
      '目前版本無法開啟本機這份資料庫。若你必須留在舊版，請依下列步驟處理；在備份完成之前，不要刪除或覆蓋這裡的資料。';

  @override
  String get startupDatabaseUpdateRequiredDowngradeStep1 =>
      '先安裝並開啟最新版 Kelivo，在「設定 → 資料備份」匯出一份備份檔。';

  @override
  String startupDatabaseUpdateRequiredDowngradeStep2(String url) {
    return '打開 $url，把備份轉換成你打算使用的舊版格式。';
  }

  @override
  String get startupDatabaseUpdateRequiredDowngradeStep3 =>
      '確認本機資料已經另外備份好之後，再安裝舊版，並匯入轉換後的備份。';

  @override
  String get startupDatabaseUpdateRequiredOpenTool => '打開轉換工具';

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
      '請選擇還原方式。備份管理中的分類開關同樣適用於本次匯入。';

  @override
  String get backupPageOverwriteMode => '完全覆蓋';

  @override
  String get backupPageOverwriteModeDescription =>
      '取代所選內容，保留未選內容及其他本機設定。取代聊天時，也會清除本機未傳送的草稿。';

  @override
  String get backupPageMergeMode => '合併';

  @override
  String get backupPageMergeModeDescription =>
      '保留本機資料並加入備份資料；相同對話會略過，衝突對話會重新分配 ID。';

  @override
  String get backupPageRestore => '還原';

  @override
  String get backupPageForwardCompatTitle => '備份來自更新的版本';

  @override
  String backupPageForwardCompatBody(int backupVersion, int currentVersion) {
    return '這份備份由更新版本的 Kelivo 建立（資料格式 $backupVersion，目前版本支援 $currentVersion），且未聲明舊版本能否讀取。\n\n你可以繼續匯入：目前版本不認識的內容會被略過，備份檔案本身不會被修改。但如果新版本改變了既有資料的儲存方式，部分內容可能會被錯誤匯入。\n\n更穩妥的做法是先升級 Kelivo。';
  }

  @override
  String get backupPageForwardCompatContinue => '仍然匯入';

  @override
  String get backupPageForwardCompatCancel => '取消';

  @override
  String get backupPageSchemaTooNewMessage =>
      '這份備份由更新版本的 Kelivo 建立，目前版本無法讀取。請先升級 Kelivo 後重試。';

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
  String get backupProgressFailed => '操作失敗';

  @override
  String backupProgressFailedAt(String phase) {
    return '失敗階段：$phase';
  }

  @override
  String get backupProgressCopyError => '複製錯誤';

  @override
  String get backupProgressErrorCopied => '錯誤已複製';

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
  String get backupPageIosSystemBackupNote =>
      'Kelivo 的本機資料已設定為不參與 iCloud 系統備份。更換裝置或移除 App 前，請先匯出備份檔案。';

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
  String get compressContextDesc => '生成可查看、可撤銷的摘要';

  @override
  String get clearContextDesc => '標記上下文分界點';

  @override
  String get contextManagement => '上下文管理';

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
  String get compressContextOptionsDesc => '在目前聊天產生可查看、可編輯、可撤銷的摘要。原始訊息保留。';

  @override
  String get compressContextKeepStart => '開頭取樣';

  @override
  String get compressContextKeepRecent => '末尾取樣';

  @override
  String get compressContextUnlimited => '全部內容';

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
  String get compressContextKeepRecentMessages => '保留 N 則';

  @override
  String get compressContextKeepCountLabel => '保留使用者訊息數';

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
  String get reasoningBudgetSheetTitle => '思維鏈強度';

  @override
  String get reasoningLevelSheetTitle => '推理';

  @override
  String get reasoningLevelAuto => '自動';

  @override
  String get reasoningLevelAutoSubtitle => '使用模型或供應商的預設設定';

  @override
  String get reasoningLevelOff => '關閉';

  @override
  String get reasoningLevelOffSubtitle => '關閉推理，直接回答';

  @override
  String get reasoningLevelMinimal => '最低';

  @override
  String get reasoningLevelMinimalSubtitle => '使用極少推理來回答問題';

  @override
  String get reasoningLevelLow => '低';

  @override
  String get reasoningLevelLowSubtitle => '使用少量推理來回答問題';

  @override
  String get reasoningLevelMedium => '中';

  @override
  String get reasoningLevelMediumSubtitle => '使用較多推理來回答問題';

  @override
  String get reasoningLevelHigh => '高';

  @override
  String get reasoningLevelHighSubtitle => '使用大量推理來回答問題，適合複雜問題';

  @override
  String get reasoningLevelXhigh => '極高';

  @override
  String get reasoningLevelXhighSubtitle => '使用很高推理深度，適合更複雜的問題';

  @override
  String get reasoningLevelMax => '最大';

  @override
  String get reasoningLevelMaxSubtitle => '使用最大推理深度，適合最複雜的問題';

  @override
  String get reasoningLevelFollowModelDefaultSubtitle => '使用模型或助手未設定時的預設檔位';

  @override
  String get reasoningLevelNoReasoning => '此模型不支援推理';

  @override
  String get reasoningLevelCustomBudget => '自訂推理預算';

  @override
  String get reasoningLevelCustomBudgetHint => '例如：2048';

  @override
  String get reasoningLevelCompactMin => 'min';

  @override
  String get reasoningLevelCompactLow => 'low';

  @override
  String get reasoningLevelCompactMid => 'mid';

  @override
  String get reasoningLevelCompactHigh => 'high';

  @override
  String get reasoningLevelCompactXhigh => 'xhigh';

  @override
  String get reasoningLevelCompactMax => 'max';

  @override
  String reasoningLevelBudgetTokens(String budget) {
    return '$budget tokens';
  }

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
  String chatMessageWidgetWebFetch(String target) {
    return '讀取網頁: $target';
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
  String get displaySettingsPageCollapseLongUserMessagesTitle => '摺疊過長訊息';

  @override
  String get displaySettingsPageCollapseLongUserMessagesSubtitle =>
      '超過閾值的使用者訊息摺疊顯示，點擊可展開';

  @override
  String get displaySettingsPageCollapseLongUserMessagesCharsTitle =>
      '超過多少字元摺疊';

  @override
  String get displaySettingsPageCollapseLongUserMessagesCharsUnit => '字元';

  @override
  String get chatMessageExpandLongText => '展開';

  @override
  String get chatMessageCollapseLongText => '收起';

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
  String get chatInputBarToolsTooltip => '工具';

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
  String get chatInputBarVoiceAttachAudioTooltip => '停止並存為音訊';

  @override
  String get chatInputBarVoiceSendAudioTooltip => '直接發送錄音';

  @override
  String get chatInputBarVoiceSavingAudio => '正在儲存錄音…';

  @override
  String get audioClipPlayTooltip => '播放音訊';

  @override
  String get audioClipPauseTooltip => '暫停';

  @override
  String get audioClipPlaybackFailed => '無法播放此音訊';

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
  String get contextUsageTitle => '上下文視窗';

  @override
  String get contextUsageStateExact => '精確（來自上次回應）';

  @override
  String get contextUsageStateExactCalibrated => '精確（分項按估算比例）';

  @override
  String get contextUsageStateEstimated => '估算';

  @override
  String get contextUsageStateStale => '已過時，正在更新…';

  @override
  String get contextUsageStateComputing => '計算中…';

  @override
  String get contextUsageStateNone => '暫無資料';

  @override
  String get contextUsageBucketSystem => '系統提示詞';

  @override
  String get contextUsageBucketInjections => '指令注入';

  @override
  String get contextUsageBucketHistory => '歷史訊息';

  @override
  String get contextUsageBucketTools => '內建工具';

  @override
  String get contextUsageBucketMemory => '記憶';

  @override
  String get contextUsageBucketWorldBook => '世界書';

  @override
  String get contextUsageBucketSkills => '技能';

  @override
  String get contextUsageBucketWorkspace => '工作區';

  @override
  String get contextUsageBucketSearch => '搜尋提示';

  @override
  String get contextUsageBucketMcpTools => 'MCP 工具';

  @override
  String get contextUsageBucketAttachments => '附件';

  @override
  String get contextUsageBucketDraft => '草稿';

  @override
  String get contextUsageBucketUsed => '已用';

  @override
  String get contextUsageFreeSpace => '剩餘空間';

  @override
  String contextUsageUsedWindow(String used, String window, int percent) {
    return '$used / $window ($percent%)';
  }

  @override
  String get contextUsageNoWindow => '未設定上下文視窗';

  @override
  String get contextUsageSetWindow => '設定上下文視窗';

  @override
  String get contextUsageRefresh => '重新整理';

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
  String get defaultModelPageTitleModelSubtitle =>
      '用於總結對話標題，預設跟隨目前對話模型，也可指定其他模型。';

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
      '用於在助手回覆後生成聊天建議，可跟隨目前對話模型或指定其他模型。預設未啟用。';

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
  String get defaultModelPageDisable => '停用';

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
  String get modelDetailSheetWebFetchTool => '網頁擷取';

  @override
  String get modelDetailSheetOpenrouterWebFetchToolDescription =>
      '啟用 OpenRouter 網頁擷取伺服器工具';

  @override
  String get modelDetailSheetClaudeWebFetchToolDescription =>
      '允許 Claude 擷取對話中出現的網頁與 PDF';

  @override
  String get modelDetailSheetClaudeCodeExecutionToolDescription =>
      '允許 Claude 在 Anthropic 沙箱中執行 Python 與 Bash';

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
  String get modelDetailSheetHeaderKeyHint => 'Header Key';

  @override
  String get modelDetailSheetHeaderValueHint => 'Header Value';

  @override
  String get modelDetailSheetBodyKeyHint => 'Body Key';

  @override
  String get modelDetailSheetBodyJsonHint => 'Body JSON';

  @override
  String get modelSpecFormSourceCustom => '自訂';

  @override
  String get modelSpecFormSourceCatalog => '目錄';

  @override
  String get modelSpecFormSourceInferred => '推斷';

  @override
  String get modelSpecFormSourceDefault => '預設';

  @override
  String get modelSpecFormReset => '重設為預設';

  @override
  String get modelSpecFormModalitiesSection => '模態與能力';

  @override
  String get modelSpecFormImageType => '圖像';

  @override
  String get modelSpecFormAudioMode => '音訊';

  @override
  String get modelSpecFormVideoMode => '影片';

  @override
  String get modelSpecFormPdfMode => 'PDF';

  @override
  String get modelSpecFormStructuredOutputAbility => '結構化輸出';

  @override
  String get modelSpecFormReasoningSection => '推理';

  @override
  String get modelSpecFormDialect => '推理方言';

  @override
  String get modelSpecFormDialectNone => '無';

  @override
  String get modelSpecFormDialectNoneSubtitle => '不寫入推理欄位';

  @override
  String get modelSpecFormDialectOpenaiReasoningEffort =>
      'OpenAI reasoning effort';

  @override
  String get modelSpecFormDialectOpenaiReasoningEffortSubtitle =>
      'reasoning_effort';

  @override
  String get modelSpecFormDialectOpenaiResponsesReasoning =>
      'OpenAI Responses reasoning';

  @override
  String get modelSpecFormDialectOpenaiResponsesReasoningSubtitle =>
      'reasoning.effort';

  @override
  String get modelSpecFormDialectOpenrouterReasoning => 'OpenRouter reasoning';

  @override
  String get modelSpecFormDialectOpenrouterReasoningSubtitle => 'reasoning';

  @override
  String get modelSpecFormDialectAnthropicBudget => 'Anthropic budget';

  @override
  String get modelSpecFormDialectAnthropicBudgetSubtitle =>
      'thinking.budget_tokens';

  @override
  String get modelSpecFormDialectAnthropicAdaptiveEffort =>
      'Anthropic adaptive effort';

  @override
  String get modelSpecFormDialectAnthropicAdaptiveEffortSubtitle =>
      'thinking + output_config.effort';

  @override
  String get modelSpecFormDialectAnthropicBetweenTools =>
      'Anthropic adaptive / between_tools';

  @override
  String get modelSpecFormDialectAnthropicBetweenToolsSubtitle =>
      '自適應思考；關閉時使用 between_tools';

  @override
  String get modelSpecFormDialectAnthropicEffort => 'Anthropic effort';

  @override
  String get modelSpecFormDialectAnthropicEffortSubtitle =>
      'thinking + output_config.effort';

  @override
  String get modelSpecFormDialectGeminiThinkingBudget =>
      'Gemini thinking budget';

  @override
  String get modelSpecFormDialectGeminiThinkingBudgetSubtitle =>
      'thinkingConfig.thinkingBudget';

  @override
  String get modelSpecFormDialectGeminiThinkingLevel => 'Gemini thinking level';

  @override
  String get modelSpecFormDialectGeminiThinkingLevelSubtitle =>
      'thinkingConfig.thinkingLevel';

  @override
  String get modelSpecFormDialectQwenEnableThinking => 'Qwen enable thinking';

  @override
  String get modelSpecFormDialectQwenEnableThinkingSubtitle =>
      'enable_thinking';

  @override
  String get modelSpecFormDialectThinkingType => 'Thinking type';

  @override
  String get modelSpecFormDialectThinkingTypeSubtitle => 'thinking.type';

  @override
  String get modelSpecFormDialectSiliconflowEnableThinking =>
      'SiliconFlow enable thinking';

  @override
  String get modelSpecFormDialectSiliconflowEnableThinkingSubtitle =>
      'enable_thinking';

  @override
  String get modelSpecFormDialectInternThinkingMode => 'Intern thinking mode';

  @override
  String get modelSpecFormDialectInternThinkingModeSubtitle => 'thinking_mode';

  @override
  String get modelSpecFormDialectChatTemplateKwargs => 'Chat template kwargs';

  @override
  String get modelSpecFormDialectChatTemplateKwargsSubtitle =>
      'chat_template_kwargs.enable_thinking';

  @override
  String get modelSpecFormDialectKimiThinking => 'Kimi thinking';

  @override
  String get modelSpecFormDialectKimiThinkingSubtitle => 'thinking';

  @override
  String get modelSpecFormDialectCustom => '自訂 JSON';

  @override
  String get modelSpecFormDialectCustomSubtitle => '依級別寫入 JSON 補丁';

  @override
  String get modelSpecFormLevels => '支援的級別';

  @override
  String get modelSpecFormCanDisable => '允許關閉';

  @override
  String get modelSpecFormDefaultLevel => '預設級別';

  @override
  String get modelSpecFormBudgets => 'Token 預算';

  @override
  String modelSpecFormBudgetPlaceholder(String tokens) {
    return '$tokens';
  }

  @override
  String modelSpecFormCustomPatch(String level) {
    return 'JSON 補丁（$level）';
  }

  @override
  String get modelSpecFormCustomPatchHint => '例如 reasoning_effort: high';

  @override
  String get modelSpecFormInvalidJson => '自訂推理補丁必須是有效的 JSON 物件';

  @override
  String get modelSpecFormInvalidNumber => '請輸入有效數字';

  @override
  String get modelSpecFormStrategySection => '策略';

  @override
  String get modelSpecFormSampling => '取樣';

  @override
  String get modelSpecFormRequestQuirks => '請求相容';

  @override
  String get modelSpecFormDynamicWebSearch => '動態過濾搜尋工具';

  @override
  String get modelSpecFormDynamicWebSearchSubtitle =>
      '開啟動態過濾時，使用 2026-03-18 版網頁搜尋與擷取工具';

  @override
  String get modelSpecFormRemoteImageUrls => '遠端圖片連結';

  @override
  String get modelSpecFormRemoteImageUrlsSubtitle =>
      '直接傳送 http(s) 圖片連結；關閉後捨棄遠端連結，只傳送本機圖片';

  @override
  String get modelSpecFormPromptCacheControl => '提示快取標記';

  @override
  String get modelSpecFormPromptCacheControlSubtitle =>
      '開啟提示快取時，在 OpenRouter 請求中加入 cache_control';

  @override
  String get modelSpecFormSamplingAlways => '始終保留';

  @override
  String get modelSpecFormSamplingAlwaysSubtitle => '保留 temperature 等取樣欄位';

  @override
  String get modelSpecFormSamplingOnlyWhenReasoningOff => '僅在關閉推理時';

  @override
  String get modelSpecFormSamplingOnlyWhenReasoningOffSubtitle => '模型思考時移除取樣欄位';

  @override
  String get modelSpecFormSamplingNever => '從不';

  @override
  String get modelSpecFormSamplingNeverSubtitle => '始終移除取樣欄位';

  @override
  String get modelSpecFormReplay => '推理回放';

  @override
  String get modelSpecFormReplayNone => '無';

  @override
  String get modelSpecFormReplayNoneSubtitle => '不把先前推理傳回模型';

  @override
  String get modelSpecFormReplayToolTurns => '工具輪次';

  @override
  String get modelSpecFormReplayToolTurnsSubtitle => '僅在工具呼叫輪次回放推理';

  @override
  String get modelSpecFormReplayAll => '全部';

  @override
  String get modelSpecFormReplayAllSubtitle => '每一輪後續請求都回放推理';

  @override
  String get modelSpecFormReplayField => '回放欄位';

  @override
  String get modelSpecFormReplayFieldReasoningContent => 'reasoning_content';

  @override
  String get modelSpecFormReplayFieldReasoning => 'reasoning';

  @override
  String get modelSpecFormReplayFieldReasoningDetails => 'reasoning_details';

  @override
  String get modelSpecFormLimitsSection => '限額';

  @override
  String get modelSpecFormLimitsPricingSection => '限額與定價';

  @override
  String get modelSpecFormContextWindow => '上下文視窗';

  @override
  String get modelSpecFormMaxOutput => '最大輸出';

  @override
  String get modelSpecFormPricingSection => '定價 / 1M';

  @override
  String get modelSpecFormPricingInput => '輸入';

  @override
  String get modelSpecFormPricingOutput => '輸出';

  @override
  String get modelSpecFormPricingCacheRead => '快取讀取';

  @override
  String get modelSpecFormPricingCacheWrite => '快取寫入';

  @override
  String get modelSpecFormCurrency => '貨幣';

  @override
  String get modelSpecFormAdvancedSection => '請求';

  @override
  String get modelSelectSheetSearchHint => '搜尋模型或供應商';

  @override
  String get modelSelectSheetFavoritesSection => '收藏';

  @override
  String get modelSelectSheetFollowAssistant => '跟隨助手';

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
  String get providerDetailPagePromptCacheKeyTitle => '傳送對話快取鍵';

  @override
  String get providerDetailPagePromptCacheKeyHelp =>
      '為 OpenAI 相容請求附加穩定的對話級 prompt_cache_key。僅在供應商支援時開啟，自訂 Body 優先，不保證快取命中。';

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
  String get modelCatalogTitle => '模型目錄';

  @override
  String modelCatalogSourceBundled(String date) {
    return '內建快照 · $date';
  }

  @override
  String modelCatalogSourceRemote(String date) {
    return 'models.dev · 更新於 $date';
  }

  @override
  String get modelCatalogAutoUpdate => '每 24 小時自動更新';

  @override
  String get modelCatalogRefresh => '立即更新';

  @override
  String get modelCatalogUpdated => '模型目錄已更新';

  @override
  String modelCatalogRefreshFailed(String error) {
    return '更新失敗：$error';
  }

  @override
  String modelCatalogProviderCount(int count) {
    return '$count 個供應商';
  }

  @override
  String modelCatalogModelCount(int count) {
    return '$count 個模型';
  }

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
  String get searchServicesPageWebFetchSection => '網頁抓取';

  @override
  String get searchServicesPageWebFetchModeTitle => '抓取方式';

  @override
  String get searchServicesPageWebFetchFollow => '跟隨搜尋服務';

  @override
  String searchServicesPageWebFetchFollowValue(String name) {
    return '跟隨搜尋 · $name';
  }

  @override
  String searchServicesPageWebFetchFollowSubtitle(String name) {
    return '目前：$name';
  }

  @override
  String get searchServicesPageWebFetchLocal => '本機抓取';

  @override
  String get searchServicesPageWebFetchLocalSubtitle => '免費，由本機直接請求網頁';

  @override
  String get searchServicesPageWebFetchProviderSubtitle =>
      '使用該服務商的 API Key 與額度';

  @override
  String get searchServicesPageWebFetchOff => '關閉';

  @override
  String get searchServicesPageWebFetchOffSubtitle => '連網時只搜尋，不讀取網頁';

  @override
  String get searchServicesPageWebFetchFooter =>
      '開啟連網搜尋後，模型還可以讀取網頁全文。搜尋服務不支援抓取時會改用本機抓取，本機抓取無法處理需要 JavaScript 渲染或有反爬限制的頁面。';

  @override
  String get searchServicesPageWebFetchSupported => '支援網頁抓取';

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
  String get searchServicesDialogApiKeyOptional => 'API Key（選填）';

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
  String get searchServiceEditorTestModeSearch => '搜尋';

  @override
  String get searchServiceEditorTestModeFetch => '抓取';

  @override
  String get searchServiceEditorTestUrlHint => '輸入測試網址';

  @override
  String get searchServiceEditorTestFetchRun => '執行抓取測試';

  @override
  String get searchServiceEditorTestFetchRunning => '抓取中…';

  @override
  String searchServiceEditorTestFetchFailed(String message) {
    return '抓取失敗：$message';
  }

  @override
  String searchServiceEditorTestFetchStats(String characters, String seconds) {
    return '$characters 字元 · $seconds 秒';
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
  String get searchSettingsSheetClaudeDynamicSearchTitle => '動態過濾';

  @override
  String get searchSettingsSheetClaudeDynamicSearchDescription =>
      '篩選搜尋結果，節省 token';

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
  String get aboutPageQQGroupThree => 'Kelivo 三群';

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
  String get displaySettingsPageShowTotalTokensTitle => '顯示整輪累計 Token';

  @override
  String get displaySettingsPageShowTotalTokensSubtitle =>
      '累計顯示本次回覆中所有 API 請求的用量。關閉時僅顯示最後一次請求；統計頁面始終包含所有請求。';

  @override
  String get displaySettingsPageShowTokenStatsSubtitle => '顯示 token 用量與訊息數量';

  @override
  String get displaySettingsPageShowThinkingCardsTitle => '顯示思考卡片';

  @override
  String get displaySettingsPageShowThinkingCardsSubtitle =>
      '關閉後，聊天中不再顯示思考過程卡片';

  @override
  String get displaySettingsPageShowToolCardsTitle => '顯示工具卡片';

  @override
  String get displaySettingsPageShowToolCardsSubtitle => '關閉後，聊天中不再顯示工具呼叫卡片';

  @override
  String get displaySettingsShowReasoningLevelBadge => '在推理按鈕上顯示檔位';

  @override
  String get displaySettingsShowReasoningLevelBadgeSubtitle =>
      '在輸入欄的推理圖示旁顯示目前檔位';

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
  String get displaySettingsPageHideToolResultImagesTitle => '隱藏工具結果中的圖片';

  @override
  String get displaySettingsPageRegenerateDeleteTrailingMessagesTitle =>
      '重新生成時刪除下面的訊息';

  @override
  String get displaySettingsPageShowRegenerateConfirmDialogTitle => '重新生成前彈出確認';

  @override
  String get displaySettingsPageForkKeepMessageVersionsTitle => '建立分支時保留訊息版本';

  @override
  String get displaySettingsPageEditAssistantKeepThinkingToolCardsTitle =>
      '編輯助手時保留思考與工具卡片';

  @override
  String get displaySettingsPageEditAssistantKeepThinkingToolCardsSubtitle =>
      '關閉後，目前編輯版本只保留助手正文；切回上一版本仍可查看思考與工具卡片';

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
  String get displaySettingsPageAutoScrollEnableTitle => '自動跟隨底部';

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
  String get linuxHideTitleBarTitle => '隱藏系統標題列';

  @override
  String get linuxHideTitleBarDescription => '同時隱藏視窗按鈕。請透過視窗管理員移動、調整大小和關閉視窗。';

  @override
  String get linuxHideTitleBarError => '無法變更標題列，請重試。';

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
  String get themeAdvancedSettingsPageTitle => '主題進階設定';

  @override
  String get themeAdvancedSettingsPageUseLayeredSurfacesTitle => '新版分層配色（實驗）';

  @override
  String get themeAdvancedSettingsPageUseLayeredSurfacesSubtitle =>
      '頁面更深、卡片更亮，兩者都保留主題色相；關閉可恢復舊外觀';

  @override
  String get themeAdvancedSettingsPageUseLayeredSheetTilesTitle => '彈窗內瓦片分層';

  @override
  String get themeAdvancedSettingsPageUseLayeredSheetTilesSubtitle =>
      '預設瓦片與彈窗同色';

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
  String get asrServicesGroqSubtitle => 'Whisper 分段雲端轉寫';

  @override
  String get asrServicesMistralSubtitle => 'Voxtral 分段雲端轉寫';

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
  String get searchProviderExaMcpDescription =>
      '透過 MCP 使用 Exa 搜尋。不填 API Key 可在免費限額內使用。';

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
  String get searchProviderDeepSeekDescription =>
      'DeepSeek 官方網頁搜尋與擷取 API，使用 DeepSeek API Key。';

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
  String get searchServiceNameExaMcp => 'Exa MCP';

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
  String get searchServiceNameDeepSeek => 'DeepSeek';

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
  String get searchServiceNameAnySearch => 'AnySearch';

  @override
  String get searchProviderAnySearchDescription =>
      '面向 AI 智慧代理的統一搜尋服務，可在網頁與專業資料來源間自動路由。API Key 可選。';

  @override
  String get searchServiceNameKagi => 'Kagi';

  @override
  String get searchProviderKagiDescription => 'Kagi 搜尋 API，提供 Kagi 的高級網頁搜尋結果。';

  @override
  String get searchServiceNameKimi => 'Kimi';

  @override
  String get searchProviderKimiDescription =>
      'Kimi 搜尋 API。Pro 傳回相關網頁正文片段，Basic 傳回標題、連結和摘要。';

  @override
  String get searchServiceNameParallel => 'Parallel';

  @override
  String get searchProviderParallelDescription =>
      'Parallel 搜尋 API。返回面向 LLM 優化的網頁摘錄，支援 turbo、fast、basic 和 advanced 模式。';

  @override
  String get searchServicesDialogSearchMode => '搜尋模式';

  @override
  String get searchServiceNameYou => 'You.com';

  @override
  String get searchProviderYouDescription =>
      'You.com 搜尋 API。返回網頁與新聞結果，支援 Highlights 或 Snippets。';

  @override
  String get searchServicesDialogContentMode => '內容模式';

  @override
  String get searchServicesDialogHighlights => 'Highlights';

  @override
  String get searchServicesDialogSnippets => 'Snippets';

  @override
  String get searchServicesDialogWebSearch => 'Web Search';

  @override
  String get searchServicesDialogLlmContext => 'LLM Context';

  @override
  String get searchServicesDialogMaximumTokens => '最大 token 數';

  @override
  String get searchServicesDialogMaximumTokensInvalid =>
      '最大 token 數必須介於 1024 和 32768 之間。';

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
  String get assistantEditLocalToolLocationTitle => '目前位置';

  @override
  String get assistantEditLocalToolLocationSubtitle => '讀取本裝置的一次性位置，需要授予定位權限。';

  @override
  String get assistantEditLocalToolWeatherTitle => '天氣';

  @override
  String get assistantEditLocalToolWeatherSubtitle =>
      '取得目前位置或指定地點的 Apple 天氣，結果中會顯示 WeatherKit 資料來源。';

  @override
  String get assistantEditLocalToolHealthTitle => '健康摘要';

  @override
  String get assistantEditLocalToolHealthSubtitle =>
      '讀取本裝置的健康活動摘要，需要授予健康資料讀取權限。';

  @override
  String assistantEditLocalToolHealthSelectedCount(int selected, int total) {
    return '已選擇 $selected/$total 項';
  }

  @override
  String get healthDataSettingsTitle => '健康資料';

  @override
  String get healthDataSettingsDescription =>
      '目前助手在日常對話中可使用的 HealthKit 訊號。開關表示 Kelivo 可以嘗試讀取該範圍，實際授權仍由 iOS 管理。';

  @override
  String healthDataSettingsBadge(int selected, int total) {
    return '$selected/$total 開啟';
  }

  @override
  String get healthDataSettingsIosReadTitle => 'iOS 健康讀取';

  @override
  String get healthDataSettingsIosReadSubtitle => '裝置可用，讀取範圍由 iOS 管理';

  @override
  String get healthDataSettingsOpenSystemSettings => '開啟系統設定';

  @override
  String get healthDataSettingsEnableAll => '全部開啟';

  @override
  String get healthDataSettingsDisableAll => '全部關閉';

  @override
  String get healthDataSettingsCategoryActivity => '活動';

  @override
  String get healthDataSettingsCategoryRest => '休息';

  @override
  String get healthDataSettingsCategoryHeart => '心率';

  @override
  String get healthDataSettingsCategoryBody => '身體';

  @override
  String get healthDataSettingsTypeStepsTitle => '步數';

  @override
  String get healthDataSettingsTypeStepsSubtitle => '行走步數摘要';

  @override
  String get healthDataSettingsTypeDaylightTitle => '日照';

  @override
  String get healthDataSettingsTypeDaylightSubtitle => '戶外日光時間';

  @override
  String get healthDataSettingsTypeActiveEnergyTitle => '能量';

  @override
  String get healthDataSettingsTypeActiveEnergySubtitle => '活動能量消耗';

  @override
  String get healthDataSettingsTypeExerciseMinutesTitle => '鍛鍊';

  @override
  String get healthDataSettingsTypeExerciseMinutesSubtitle => 'Apple 鍛鍊分鐘數';

  @override
  String get healthDataSettingsTypeStandTimeTitle => '站立';

  @override
  String get healthDataSettingsTypeStandTimeSubtitle => '站立時間';

  @override
  String get healthDataSettingsTypeDistanceTitle => '距離';

  @override
  String get healthDataSettingsTypeDistanceSubtitle => '步行和跑步距離';

  @override
  String get healthDataSettingsTypeWorkoutsTitle => '健身訓練';

  @override
  String get healthDataSettingsTypeWorkoutsSubtitle => '訓練紀錄：類型、時長、距離與消耗';

  @override
  String get healthDataSettingsTypeSleepTitle => '睡眠';

  @override
  String get healthDataSettingsTypeSleepSubtitle => '最近 24 小時的睡眠、臥床、清醒與睡眠分期';

  @override
  String get healthDataSettingsTypeMindfulnessTitle => '靜息';

  @override
  String get healthDataSettingsTypeMindfulnessSubtitle => '正念或靜息時段';

  @override
  String get healthDataSettingsTypeHeartRateTitle => '心率';

  @override
  String get healthDataSettingsTypeHeartRateSubtitle => '最近心率樣本';

  @override
  String get healthDataSettingsTypeRestingHeartRateTitle => '靜息心率';

  @override
  String get healthDataSettingsTypeRestingHeartRateSubtitle => '靜息狀態心率';

  @override
  String get healthDataSettingsTypeBloodOxygenTitle => '血氧';

  @override
  String get healthDataSettingsTypeBloodOxygenSubtitle => '血氧飽和度';

  @override
  String get healthDataSettingsTypeDietaryEnergyTitle => '攝入能量';

  @override
  String get healthDataSettingsTypeDietaryEnergySubtitle => '飲食熱量紀錄';

  @override
  String get healthDataSettingsTypeWaterTitle => '飲水';

  @override
  String get healthDataSettingsTypeWaterSubtitle => '飲水量紀錄';

  @override
  String get healthDataSettingsTypeWeightTitle => '體重';

  @override
  String get healthDataSettingsTypeWeightSubtitle => '體重樣本';

  @override
  String get healthDataSettingsTypeBmiTitle => 'BMI';

  @override
  String get healthDataSettingsTypeBmiSubtitle => '身體質量指數';

  @override
  String get healthDataSettingsTypeBloodGlucoseTitle => '血糖';

  @override
  String get healthDataSettingsTypeBloodGlucoseSubtitle => '血糖樣本';

  @override
  String get assistantEditLocalToolRemindersQueryTitle => '查詢提醒';

  @override
  String get assistantEditLocalToolRemindersQuerySubtitle =>
      '讀取本裝置上的提醒事項，需要授予提醒事項完整存取權限。';

  @override
  String get assistantEditLocalToolRemindersCreateTitle => '建立提醒';

  @override
  String get assistantEditLocalToolRemindersCreateSubtitle =>
      '在你確認後於本裝置建立提醒事項，需要授予提醒事項完整存取權限。';

  @override
  String get assistantEditLocalToolRemindersCompleteTitle => '完成提醒';

  @override
  String get assistantEditLocalToolRemindersCompleteSubtitle =>
      '在你確認後將提醒事項標記為完成，需要授予提醒事項完整存取權限。';

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
  String get settingsPageAutoRetry => '自動重試';

  @override
  String get autoRetryEnableLabel => '開啟自動重試';

  @override
  String get autoRetryMaxRetries => '最大重試次數';

  @override
  String get autoRetryInitialDelay => '首次延遲（毫秒）';

  @override
  String get autoRetryMultiplier => '退避倍率';

  @override
  String get autoRetryMaxDelay => '最大延遲（毫秒）';

  @override
  String get autoRetryJitter => '抖動';

  @override
  String get autoRetryJitterSubtitle => '每次等待隨機 ±20%';

  @override
  String get autoRetryOnNetworkError => '網路錯誤時重試';

  @override
  String get autoRetryStatusCodes => '可重試狀態碼';

  @override
  String get autoRetryKeywords => '重試關鍵字';

  @override
  String get autoRetryStopKeywords => '停止重試關鍵字';

  @override
  String get autoRetryAddHint => '新增';

  @override
  String get autoRetryRestoreDefaults => '恢復預設';

  @override
  String get autoRetryFooter => '僅在目前這輪模型回應尚未產生任何輸出時才會自動重試。';

  @override
  String autoRetryCountdown(int seconds, int attempt, int maxRetries) {
    return '$seconds 秒後重試 ($attempt/$maxRetries)';
  }

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
      '此限制僅適用於未選擇全量注入的類型。某一類型的記憶超過該條數時，只注入最近的若干條，其餘由模型用 memory_search_profile 按需查詢。調大更全面但更費 token。若你改過規則提示詞，請一併更新或恢復預設。';

  @override
  String get memorySettingsFullInjectionTypesTitle => '全量注入類型';

  @override
  String get memorySettingsFullInjectionTypesSubtitle =>
      '可多選。選中類型會注入全域及目前助手的全部有效記憶，不受條數限制，會增加上下文和 token 消耗。';

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
  String worldBookImportUnsupportedEntries(int count) {
    return '匯入完成。$count 個條目使用了暫不支援的酒館功能（如巨集、正則、時效、篩選或插入規則），已保留內容並停用，請檢查後再啟用。';
  }

  @override
  String get worldBookInjectionRoleUser => '使用者';

  @override
  String get worldBookInjectionRoleAssistant => '助手';

  @override
  String get mcpToolNeedsApproval => '需要審批';

  @override
  String get toolApprovalPending => '等待審批';

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
  String tokenDetailFirstToken(String value) {
    return '${value}s（首字）';
  }

  @override
  String tokenDetailTotalTokens(int count) {
    return '$count tokens';
  }

  @override
  String tokenDetailReasoningTokens(int count) {
    return '$count tokens';
  }

  @override
  String tokenDetailCacheWriteTokens(int count) {
    return '$count 快取寫入 tokens';
  }

  @override
  String tokenDetailCost(String amount) {
    return '$amount';
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
  String get migrationStartWithoutBackupButton => '不備份，直接遷移';

  @override
  String get migrationSkipChatsJsonOption => '跳過 chats.json';

  @override
  String get migrationSkipChatsJsonDescription =>
      '仍會備份原始 Hive、設定和本機檔案，超大聊天記錄建議選擇。';

  @override
  String get migrationSkipBackupOption => '跳過本次備份';

  @override
  String get migrationSkipBackupDescription => '僅在已有並確認備份可用時選擇，之後將立即開始遷移。';

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
  String get migrationFailedSubtitle =>
      '原始 Hive 資料仍然保留；如果備份已經完成，備份檔案也不會被修改。查看下方原因後可以重試。';

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
  String get imageSettingsPageSendSectionTitle => '傳送';

  @override
  String get imageSettingsPageMarkdownImageLinksTitle =>
      '將 Markdown 圖片連結作為圖片傳送';

  @override
  String get imageSettingsPageMarkdownImageLinksSubtitle =>
      '開啟後，訊息文字中的 ![alt](url) 會作為圖片傳送給視覺模型；關閉後僅以純文字傳送。手動加入的圖片附件不受影響。';

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
  String get messageStyleSettingsPageAssistantFitContent => '助手氣泡貼合內容';

  @override
  String get messageStyleSettingsPageAssistantFitContentSubtitle =>
      '助手氣泡按文字寬度收縮，不再佔滿整行';

  @override
  String get messageStyleSettingsPageAssistantSplitParagraphs => '分段顯示為多個氣泡';

  @override
  String get messageStyleSettingsPageAssistantSplitParagraphsSubtitle =>
      '助手回覆遇到空行時拆分，每段單獨一個氣泡';

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

  @override
  String get localSnapshotSectionTitle => '本機副本';

  @override
  String get localSnapshotEnabledTitle => '保留本機副本';

  @override
  String get localSnapshotEnabledSubtitle => 'Kelivo 會定期在本機存一份資料庫副本，讓資料不只有一份。';

  @override
  String get localSnapshotIntervalTitle => '備份頻率';

  @override
  String get localSnapshotIntervalAutomatic => '自動';

  @override
  String get localSnapshotIntervalAutomaticDetail => '每天一次，資料庫越大間隔越長';

  @override
  String localSnapshotIntervalDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '每 $days 天',
      one: '每天',
    );
    return '$_temp0';
  }

  @override
  String get localSnapshotKeepTitle => '保留份數';

  @override
  String localSnapshotKeepValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 份',
    );
    return '$_temp0';
  }

  @override
  String get localSnapshotKeepSubtitle => '另外各留一份上週和上個月的，萬一問題過了很久才發現也還能找回來。';

  @override
  String get localSnapshotKeepWeekly => '保留一份上週的';

  @override
  String get localSnapshotKeepMonthly => '保留一份上個月的';

  @override
  String get localSnapshotKeepProtectedNote => '無論設成幾份，最近一份仍有內容的副本都不會被自動清理。';

  @override
  String get localSnapshotMaximumTitle => '佔用上限';

  @override
  String get localSnapshotMaximumUnlimited => '不限制';

  @override
  String get localSnapshotAnnounceTitle => '備份完成時提示';

  @override
  String get localSnapshotAnnounceSubtitle => '失敗一定會告訴你。這裡只是成功時多一句提示。';

  @override
  String get localSnapshotTakeNow => '立即備份一份';

  @override
  String get localSnapshotManageCopies => '管理副本';

  @override
  String localSnapshotUsage(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 份',
      zero: '暫無副本',
    );
    return '$_temp0 · $size';
  }

  @override
  String get localSnapshotStatusNever => '還沒有備份過';

  @override
  String localSnapshotStatusSuccess(String when) {
    return '上次備份：$when';
  }

  @override
  String localSnapshotStatusFailure(String when, String reason) {
    return '上次備份失敗（$when）：$reason';
  }

  @override
  String get localSnapshotStatusSkippedSpace => '已跳過：本機剩餘空間不足';

  @override
  String get localSnapshotStatusUnchanged => '距上次備份資料沒有變化';

  @override
  String get localSnapshotCopiesTitle => '本機副本';

  @override
  String get localSnapshotCopiesEmpty => '還沒有本機副本';

  @override
  String get localSnapshotCopiesEmptyHint => '資料有變化時會自動存一份，還原資料前也一定會先存一份。';

  @override
  String get localSnapshotCopiesScopeNote =>
      '本機副本只存在這台裝置上。它防的是應用內資料被損壞或誤刪，防不了裝置遺失或解除安裝應用——那要靠 WebDAV / S3 備份。';

  @override
  String get localSnapshotOriginAutomatic => '自動備份';

  @override
  String get localSnapshotOriginManual => '手動備份';

  @override
  String get localSnapshotOriginBeforeRestore => '還原前備份';

  @override
  String get localSnapshotKindRecovered => '故障還原時留下的';

  @override
  String localSnapshotCopyContents(int conversations, int messages) {
    String _temp0 = intl.Intl.pluralLogic(
      conversations,
      locale: localeName,
      other: '$conversations 個對話',
    );
    String _temp1 = intl.Intl.pluralLogic(
      messages,
      locale: localeName,
      other: '$messages 則訊息',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get localSnapshotCopyContentsUnknown => '內容需還原後才能確認';

  @override
  String get localSnapshotCopyPinned => '已保留';

  @override
  String get localSnapshotActionRestore => '還原';

  @override
  String get localSnapshotActionExport => '匯出';

  @override
  String get localSnapshotActionDelete => '刪除';

  @override
  String get localSnapshotActionPin => '保留這份';

  @override
  String get localSnapshotActionUnpin => '取消保留';

  @override
  String get localSnapshotRestoreTitle => '還原這份副本？';

  @override
  String localSnapshotRestoreMessage(String when) {
    return '目前聊天和設定將取代為 $when 的副本。取代前會儲存目前聊天和設定的副本。未傳送的草稿不包含在副本中，此次還原會清除這些草稿。';
  }

  @override
  String get localSnapshotRestorePreparing => '正在準備副本';

  @override
  String get localSnapshotDeleteTitle => '刪除這份副本？';

  @override
  String get localSnapshotDeleteMessage =>
      '這份副本會從裝置上永久刪除。它裡面有、而目前資料庫裡沒有的資料將無法找回。';

  @override
  String get localSnapshotDeleteLastWarning => '這是唯一一份還有內容的副本。';

  @override
  String get localSnapshotExportPreparing => '正在準備匯出';

  @override
  String get localSnapshotExportDone => '副本已匯出';

  @override
  String localSnapshotExportFailed(String reason) {
    return '匯出副本失敗：$reason';
  }

  @override
  String get localSnapshotTakeDone => '副本已儲存';

  @override
  String localSnapshotTakeFailed(String reason) {
    return '儲存副本失敗：$reason';
  }

  @override
  String get localSnapshotDeleteDone => '副本已刪除';

  @override
  String get localSnapshotBusyMessage => '已有備份任務在進行中';

  @override
  String get localSnapshotRunInBackground => '轉到背景繼續';

  @override
  String get localSnapshotRunningInBackground => '正在背景備份副本';

  @override
  String startupRecoveryLocalCopiesAvailable(int count, String when) {
    return '本機還保留著 $count 份本機副本，最新一份是 $when 的。重設不會刪除它們——重新啟動後可以在 設定 › 備份 › 本機副本 裡還原。';
  }

  @override
  String startupRecoveryRecoveredCopiesDeleted(int count) {
    return '另外還有 $count 份故障還原時留下的資料庫副本，重設會把它們一併永久刪除。想留住的話請先匯出資料。';
  }

  @override
  String get toolSchemaSettingsPageTitle => '工具描述';

  @override
  String get toolSchemaSettingsGroupSearch => '搜尋';

  @override
  String get toolSchemaSettingsGroupMemory => '記憶';

  @override
  String get toolSchemaSettingsGroupLocal => '本機工具';

  @override
  String get toolSchemaSettingsModified => '已修改';

  @override
  String get toolSchemaSettingsResetDefault => '還原預設';

  @override
  String get toolSchemaSettingsResetAll => '全部還原預設';

  @override
  String get toolSchemaSettingsResetAllTitle => '全部還原預設？';

  @override
  String get toolSchemaSettingsResetAllMessage =>
      '將把所有內建工具的描述還原為應用預設文案，自訂措辭會遺失。';

  @override
  String get toolSchemaSettingsResetAllConfirm => '還原';

  @override
  String toolSchemaSettingsParamDescriptions(int count) {
    return '參數描述 ($count)';
  }

  @override
  String get toolSchemaSettingsMemoryLangNote =>
      '記憶工具的預設描述會隨記憶提示語言在中/英之間切換。自訂描述依工具名只存一份，切換語言後不會跟著變。';

  @override
  String get toolSchemaSettingsDescriptionLabel => '描述';

  @override
  String get toolSchemaSettingsToolName => '工具名';

  @override
  String get toolSchemaEditorPageTitle => '編輯描述';

  @override
  String get toolSchemaSettingsCancel => '取消';

  @override
  String get workspaceFileNotAvailable => '檔案不可用';

  @override
  String get workspaceTerminalNotAvailable => '終端機不可用';

  @override
  String get workspacePreviewCopyPath => '複製路徑';

  @override
  String get workspacePreviewShare => '分享';

  @override
  String get workspacePreviewOpenExternally => '用其他應用程式開啟';

  @override
  String get workspacePreviewOpenWith => '開啟方式…';

  @override
  String get workspacePreviewFileTooLarge => '檔案過大，無法預覽，請用其他應用程式開啟。';

  @override
  String get workspacePreviewSource => '原始碼';

  @override
  String get workspacePreviewRendered => '渲染';

  @override
  String get workspacePreviewFileName => '名稱';

  @override
  String get workspacePreviewFileSize => '大小';

  @override
  String get workspacePreviewFileModified => '修改時間';

  @override
  String get workspacePreviewPathCopied => '已複製路徑';

  @override
  String workspacePreviewLineCount(int count) {
    return '$count 行';
  }

  @override
  String get workspaceFilesSort => '排序';

  @override
  String get workspaceFilesSortName => '名稱';

  @override
  String get workspaceFilesSortModified => '修改時間';

  @override
  String get workspaceFilesSortSize => '大小';

  @override
  String get workspaceFilesSortAscending => '升序';

  @override
  String get workspaceFilesSortDescending => '降序';

  @override
  String get workspaceFilesShowHidden => '顯示隱藏檔案';

  @override
  String get workspaceFilesHideHidden => '隱藏隱藏檔案';

  @override
  String get workspaceFilesRefresh => '重新整理';

  @override
  String get workspaceFilesNewFolder => '新增資料夾';

  @override
  String get workspaceFilesNewFile => '新增檔案';

  @override
  String get workspaceFilesImport => '匯入';

  @override
  String get workspaceFilesExport => '匯出';

  @override
  String get workspaceFilesExportFolder => '匯出目前資料夾';

  @override
  String get workspaceFilesEmpty => '此資料夾是空的';

  @override
  String get workspaceFilesError => '無法載入這些檔案';

  @override
  String get workspaceFilesRetry => '重試';

  @override
  String get workspaceFilesPreview => '預覽';

  @override
  String get workspaceFilesRename => '重新命名';

  @override
  String get workspaceFilesMove => '移動';

  @override
  String get workspaceFilesDelete => '刪除';

  @override
  String get workspaceFilesShare => '分享';

  @override
  String get workspaceFilesCopyPath => '複製路徑';

  @override
  String get workspaceFilesExportItem => '匯出';

  @override
  String get workspaceFilesNameLabel => '名稱';

  @override
  String get workspaceFilesNameHint => '輸入名稱';

  @override
  String get workspaceFilesCreate => '建立';

  @override
  String get workspaceFilesCancel => '取消';

  @override
  String get workspaceFilesConfirm => '確認';

  @override
  String get workspaceFilesSave => '儲存';

  @override
  String get workspaceFilesDeleteTitle => '刪除此項目？';

  @override
  String workspaceFilesDeleteMessage(String name) {
    return '刪除 $name？';
  }

  @override
  String workspaceFilesDeleteFolderMessage(String name) {
    return '刪除資料夾 $name 及其全部內容？';
  }

  @override
  String get workspaceFilesMoveTitle => '移動到資料夾';

  @override
  String get workspaceFilesMoveHere => '移動到此處';

  @override
  String get workspaceFilesPathCopied => '已複製路徑';

  @override
  String get workspaceFilesInvalidName => '名稱無效';

  @override
  String get workspaceFilesInvalidPath => '該路徑超出目前資料夾';

  @override
  String workspaceFilesOperationFailed(String error) {
    return '操作失敗：$error';
  }

  @override
  String get workspaceFilesActions => '操作';

  @override
  String get workspaceFilesMore => '更多';

  @override
  String get workspaceFilesJustNow => '剛剛';

  @override
  String workspaceFilesMinutesAgo(int count) {
    return '$count 分鐘前';
  }

  @override
  String workspaceFilesHoursAgo(int count) {
    return '$count 小時前';
  }

  @override
  String workspaceFilesDaysAgo(int count) {
    return '$count 天前';
  }

  @override
  String get workspaceFilesPanelTitle => '對話檔案';

  @override
  String get workspaceFilesTabAttachments => '附件';

  @override
  String get workspaceFilesTabOutputs => '輸出';

  @override
  String get workspaceFilesTabWorkspace => '工作區';

  @override
  String get workspaceFilesNoWorkspaceBound => '尚未綁定工作區';

  @override
  String get workspaceFilesKindManaged => '託管';

  @override
  String get workspaceFilesKindLinked => '連結';

  @override
  String get workspaceFilesMissingWorkspace => '找不到工作區';

  @override
  String get workspaceFilesClose => '關閉';

  @override
  String get workspacesTitle => '工作區';

  @override
  String get workspacesCreate => '建立';

  @override
  String get workspacesCreateTitle => '新增工作區';

  @override
  String get workspacesNameLabel => '名稱';

  @override
  String get workspacesNameHint => '工作區名稱';

  @override
  String get workspacesLinkFolder => '連結資料夾';

  @override
  String get workspacesEmpty => '還沒有工作區';

  @override
  String get workspacesEmptyCta => '建立工作區';

  @override
  String get workspacesSettings => '設定';

  @override
  String get workspacesOpenFiles => '開啟檔案';

  @override
  String get workspacesLastUsedNever => '從未使用';

  @override
  String workspacesLastUsed(String when) {
    return '最近使用 $when';
  }

  @override
  String get workspacesDeleteTitle => '刪除此工作區？';

  @override
  String workspacesDeleteMessage(String name) {
    return '刪除工作區 $name？';
  }

  @override
  String get workspacesDeleteAlsoFiles => '同時刪除檔案';

  @override
  String get workspacesUnlinkTitle => '取消連結此工作區？';

  @override
  String workspacesUnlinkMessage(String name) {
    return '取消連結 $name？磁碟上的檔案會保留。';
  }

  @override
  String get workspacesSettingsTitle => '工作區設定';

  @override
  String get workspacesShellNeedsApproval => '執行終端機命令前詢問';

  @override
  String get workspacesDefaultCwd => '預設工作目錄';

  @override
  String get workspacesDefaultCwdHint => '相對路徑，例如 src';

  @override
  String get workspacesDefaultCwdInvalid => '請使用不含 .. 的相對路徑';

  @override
  String get workspacesCreateManaged => '建立工作區';

  @override
  String get workspacesLinkExisting => '連結既有資料夾';

  @override
  String get workspacesUnlink => '取消連結';

  @override
  String get workspacesItemMore => '工作區操作';

  @override
  String get workspaceToolDenied => '已拒絕';

  @override
  String get workspaceToolTimeout => '逾時';

  @override
  String get workspaceToolCancelled => '已取消';

  @override
  String get workspaceToolInterrupted => '已中斷';

  @override
  String get workspaceToolEnvironmentNotReady => '沙箱環境未安裝';

  @override
  String get workspaceToolInstall => '安裝';

  @override
  String get workspaceToolFuzzy => '模糊';

  @override
  String get workspaceToolCreated => '已建立';

  @override
  String get workspaceToolUpdated => '已更新';

  @override
  String get workspaceToolTruncated => '已截斷';

  @override
  String get workspaceToolImageTag => '圖片';

  @override
  String get workspaceToolStdout => 'stdout';

  @override
  String get workspaceToolStderr => 'stderr';

  @override
  String get workspaceToolOpenFullOutput => '開啟完整輸出';

  @override
  String get workspaceToolChangedFiles => '變更的檔案';

  @override
  String get workspaceToolCancel => '取消';

  @override
  String get workspaceToolCopyCommand => '複製命令';

  @override
  String get workspaceToolCopyOutput => '複製輸出';

  @override
  String get workspaceToolCopyDiff => '複製差異';

  @override
  String get workspaceToolCopied => '已複製';

  @override
  String get workspaceToolDiffTruncated => '差異已截斷';

  @override
  String get workspaceToolOpenPreview => '開啟預覽';

  @override
  String get workspaceToolNoOutput => '無輸出';

  @override
  String get workspaceToolNotAvailable => '不可用';

  @override
  String get workspaceToolClose => '關閉';

  @override
  String get workspaceToolTitleShell => '執行命令';

  @override
  String get workspaceToolTitleReadFile => '讀取檔案';

  @override
  String get workspaceToolTitleViewImage => '檢視圖片';

  @override
  String get workspaceToolTitleWriteFile => '寫入檔案';

  @override
  String get workspaceToolTitleEditFile => '編輯檔案';

  @override
  String get workspaceToolTitleListDir => '列出目錄';

  @override
  String get workspaceToolTitleGlob => 'Glob';

  @override
  String get workspaceToolTitleGrep => 'Grep';

  @override
  String workspaceToolCount(int count) {
    return '$count';
  }

  @override
  String workspaceToolMoreFiles(int count) {
    return '+$count';
  }

  @override
  String workspaceToolDurationMs(int ms) {
    return '${ms}ms';
  }

  @override
  String workspaceToolDurationSec(String sec) {
    return '${sec}s';
  }

  @override
  String get workspaceEnvTitle => '環境';

  @override
  String workspaceEnvEngineUbuntu(String version) {
    return 'Ubuntu $version (PRoot)';
  }

  @override
  String workspaceEnvEngineAlpine(String version) {
    return 'Alpine $version (iSH)';
  }

  @override
  String get workspaceEnvEngineNative => '系統終端機';

  @override
  String get workspaceEnvPhaseNotInstalled => '未安裝';

  @override
  String get workspaceEnvPhaseDownloading => '下載中';

  @override
  String get workspaceEnvPhaseVerifying => '校驗中';

  @override
  String get workspaceEnvPhaseExtracting => '解壓中';

  @override
  String get workspaceEnvPhasePatching => '設定中';

  @override
  String get workspaceEnvPhaseReady => '就緒';

  @override
  String get workspaceEnvPhaseError => '錯誤';

  @override
  String get workspaceEnvPhaseNeedsRestart => '需要重新啟動';

  @override
  String workspaceEnvMetaLine(String version, String arch) {
    return '$version · $arch';
  }

  @override
  String workspaceEnvInstalledAt(String date) {
    return '安裝於 $date';
  }

  @override
  String workspaceEnvDiskUsage(String size) {
    return '佔用空間 $size';
  }

  @override
  String workspaceEnvRuntimeReason(String reason) {
    return '$reason';
  }

  @override
  String get workspaceEnvInstall => '安裝';

  @override
  String get workspaceEnvInstallSubtitleAndroid =>
      '可選擇 Ubuntu、Alpine、Debian，也可匯入本機 rootfs 映像。';

  @override
  String get workspaceEnvInstallSubtitleIos => '已內建，無需下載';

  @override
  String get workspaceEnvCancel => '取消';

  @override
  String get workspaceEnvRetry => '重試';

  @override
  String get workspaceEnvRepair => '修復';

  @override
  String get workspaceEnvReset => '重設';

  @override
  String get workspaceEnvResetConfirmTitle => '重設環境？';

  @override
  String get workspaceEnvResetConfirmBody => '這會刪除已安裝的套件和沙箱檔案系統。';

  @override
  String get workspaceEnvCheckForUpdate => '檢查更新';

  @override
  String get workspaceEnvUpdate => '更新';

  @override
  String workspaceEnvAvailableVersion(String version) {
    return '新版本 $version 可用';
  }

  @override
  String get workspaceEnvUpToDate => '已是最新';

  @override
  String get workspaceEnvRestartBanner => '請重新啟動 Kelivo 以完成安裝';

  @override
  String get workspaceEnvDetectingMirrors => '正在偵測最快鏡像…';

  @override
  String workspaceEnvApplyingMirror(String category) {
    return '正在套用 $category 鏡像…';
  }

  @override
  String get workspaceEnvMirrorsSection => '鏡像';

  @override
  String get workspaceEnvUseMirror => '使用鏡像';

  @override
  String get workspaceEnvDetect => '測速';

  @override
  String get workspaceEnvOfficial => '官方';

  @override
  String get workspaceEnvMirrorsDisabled => '鏡像設定在沙箱中執行，就緒後才能變更。';

  @override
  String workspaceEnvMirrorsDisabledReason(String reason) {
    return '鏡像設定在沙箱中執行，目前不可用：$reason';
  }

  @override
  String get workspaceEnvMirrorDetectTitle => '鏡像測速';

  @override
  String workspaceEnvMirrorLatency(int ms) {
    return '$ms ms';
  }

  @override
  String workspaceEnvMirrorFailed(String reason) {
    return '$reason';
  }

  @override
  String get workspaceEnvErrorUnsupportedAbi => '目前裝置架構不受支援。';

  @override
  String get workspaceEnvErrorArchitectureMismatch =>
      '已安裝的沙盒架構與目前應用程式不符，請重新安裝沙盒後使用。原沙盒檔案已保留。';

  @override
  String get workspaceEnvErrorProotMissing => '缺少 PRoot 執行檔。';

  @override
  String get workspaceEnvErrorInsufficientDisk => '儲存空間不足，無法安裝沙箱。';

  @override
  String get workspaceEnvErrorInsufficientDiskHint => '請為所選映像釋放更多儲存空間後重試。';

  @override
  String get workspaceEnvErrorNetwork => '下載失敗，請檢查網路後重試。';

  @override
  String get workspaceEnvErrorChecksumMismatch => '下載檔案已損毀，請重試。';

  @override
  String get workspaceEnvErrorExtractFailed => '無法解壓沙箱映像。';

  @override
  String get workspaceEnvErrorCleanupFailed => '無法清理舊沙箱檔案，請重試。';

  @override
  String get workspaceEnvCleanupIncomplete => '沙箱已就緒，但部分舊檔案未能清理，仍佔用儲存空間。';

  @override
  String get workspaceEnvErrorResetFailed => '未能完成沙箱重設，請重試。';

  @override
  String get workspaceEnvErrorPatchFailed => '無法完成沙箱設定。';

  @override
  String get workspaceEnvErrorCancelled => '安裝已取消。';

  @override
  String get workspaceEnvErrorGeneric => '安裝沙箱時發生錯誤。';

  @override
  String get workspaceEnvChipInstall => '安裝沙箱';

  @override
  String workspaceEnvChipInstalling(int percent) {
    return '正在安裝… $percent %';
  }

  @override
  String get workspaceEnvChipInstallingIndeterminate => '正在安裝…';

  @override
  String get workspaceEnvChipError => '沙箱錯誤';

  @override
  String get workspaceEnvChipRestart => '需要重新啟動';

  @override
  String get workspaceEnvNativeExplanation =>
      '在桌面端，Kelivo 使用系統終端機，而不是 Linux 沙箱。';

  @override
  String workspaceEnvNativeShellPath(String path) {
    return '終端機：$path';
  }

  @override
  String get workspaceEnvNativeShellApproval => '請求批准模式下，Shell 工具需要批准。';

  @override
  String workspaceEnvDownloadProgress(
    String downloaded,
    String total,
    int percent,
  ) {
    return '$downloaded / $total MB ($percent%)';
  }

  @override
  String get workspaceEnvMirrorsFailed => '無法偵測鏡像';

  @override
  String get workspaceEnvCategoryApt => 'APT';

  @override
  String get workspaceEnvCategoryApk => 'APK';

  @override
  String get workspaceEnvCategoryPip => 'pip';

  @override
  String get workspaceEnvCategoryNpm => 'npm';

  @override
  String get skillsTitle => '技能';

  @override
  String get skillsTab => '技能';

  @override
  String get skillsSearchHint => '搜尋技能';

  @override
  String get skillsEmptyTitle => '還沒有技能';

  @override
  String get skillsEmptyBody =>
      '技能是包含 SKILL.md 的資料夾。可貼上 Markdown、匯入 .md/.zip，或從 GitHub 安裝。';

  @override
  String get skillsEmptyFormat =>
      '---\nname: my-skill\ndescription: 這個技能做什麼\n---\n\n# 說明';

  @override
  String get skillsImport => '匯入';

  @override
  String get skillsImportPaste => '貼上 Markdown';

  @override
  String get skillsImportFile => '從檔案';

  @override
  String get skillsImportGitHub => '從 GitHub';

  @override
  String get skillsImportPasteLabel => 'SKILL.md';

  @override
  String get skillsImportPasteHint => '貼上含 YAML 前置資料的 SKILL.md';

  @override
  String get skillsImportGitHubLabel => 'GitHub 連結';

  @override
  String get skillsImportGitHubHint =>
      'github.com/owner/repo 或 github.com/owner/repo/tree/ref/path';

  @override
  String get skillsImportConfirm => '匯入';

  @override
  String get skillsCancel => '取消';

  @override
  String get skillsSave => '儲存';

  @override
  String skillsUsedCount(int count) {
    return '已使用 $count 次';
  }

  @override
  String get skillsEnabled => '啟用';

  @override
  String get skillsBrowseFiles => '瀏覽檔案';

  @override
  String get skillsEdit => '編輯';

  @override
  String get skillsExport => '匯出';

  @override
  String get skillsDelete => '刪除';

  @override
  String get skillsDeleteTitle => '刪除此技能？';

  @override
  String skillsDeleteMessage(String name) {
    return '刪除 $name？此操作無法復原。';
  }

  @override
  String get skillsUseAll => '使用全部技能';

  @override
  String get skillsUseAllSubtitle => '此助手可以使用所有已啟用的技能。';

  @override
  String get skillsDisabledHint => '請先在技能頁啟用此技能。';

  @override
  String get skillsOpenPage => '管理技能';

  @override
  String get skillsInheritAssistant => '跟隨助手';

  @override
  String get skillsInheritAssistantSubtitle => '使用與此對話助手相同的技能。';

  @override
  String get skillsActiveLabel => '生效中';

  @override
  String get skillsSessionTitle => '此對話的技能';

  @override
  String get skillsEditTitle => '編輯技能';

  @override
  String get skillsDetailKindLabel => 'Skill';

  @override
  String get skillsNoEnabled => '沒有已啟用的技能';

  @override
  String get terminalTitle => '終端機';

  @override
  String get terminalOpenInSystem => '在系統終端機中開啟';

  @override
  String get terminalHostDirectory => '主機目錄';

  @override
  String get terminalBindWorkspaceFirst => '請先綁定工作區';

  @override
  String get terminalNotAvailable => '不可用';

  @override
  String get terminalRuntimeUnavailable => '終端機環境尚未就緒';

  @override
  String get terminalRename => '重新命名';

  @override
  String get terminalClose => '關閉';

  @override
  String get terminalClear => '清除';

  @override
  String get terminalCloseSession => '關閉工作階段';

  @override
  String get terminalCopy => '複製';

  @override
  String get terminalPaste => '貼上';

  @override
  String get terminalNewSession => '新增工作階段';

  @override
  String get terminalMore => '更多';

  @override
  String get terminalNameLabel => '名稱';

  @override
  String get terminalCancel => '取消';

  @override
  String get terminalSave => '儲存';

  @override
  String get workspaceDeskMenuWorkspace => '工作區';

  @override
  String get workspaceDeskMenuSkills => '技能';

  @override
  String get workspaceDeskBarTitle => '工作區';

  @override
  String get workspaceDeskBarNoWorkspace => '無工作區';

  @override
  String get workspaceDeskBarEmptyHint => '從工具列綁定工作區後即可在此瀏覽檔案';

  @override
  String get workspaceDeskBarToggle => '工作區檔案';

  @override
  String get workspaceDeskOpenSystemTerminal => '在系統終端機中開啟';

  @override
  String get workspaceDeskReveal => '在檔案管理員中顯示';

  @override
  String get workspaceDeskBarClose => '關閉工作區列';

  @override
  String get workspaceEntryBind => '綁定工作區';

  @override
  String get workspaceEntryUnbind => '解除綁定';

  @override
  String get workspaceEntryChange => '更換';

  @override
  String get workspaceEntrySetAssistantDefault => '設為助手預設工作區';

  @override
  String get workspaceEntryLocked => '已鎖定';

  @override
  String get workspaceEntryChangeConfirmTitle => '更換工作區？';

  @override
  String get workspaceEntryUnbindConfirmTitle => '解除綁定？';

  @override
  String get workspaceEntryChangeConfirmBody =>
      '此對話已使用過工作區工具，之前訊息中的檔案連結可能不再可用。';

  @override
  String get workspaceEntryCwd => '工作目錄';

  @override
  String get workspaceEntryCwdHint => '相對於工作區根目錄';

  @override
  String get workspaceEntryCwdInvalid => '路徑無效或已超出工作區';

  @override
  String get workspaceEntryCwdMissing => '該目錄不存在';

  @override
  String get workspaceEntryCwdCreate => '建立它';

  @override
  String get workspaceEntryFiles => '檔案';

  @override
  String get workspaceEntryTerminal => '終端機';

  @override
  String get workspaceEntryOpenSystemTerminal => '在系統終端機中開啟';

  @override
  String get workspaceEntryReveal => '在檔案管理員中顯示';

  @override
  String get workspaceEntrySessionSkills => '技能';

  @override
  String get workspaceEntryEnvironment => '環境';

  @override
  String get workspaceEntryManage => '管理工作區';

  @override
  String get workspaceEntryCreate => '新增工作區…';

  @override
  String get workspaceEntryDefaultWorkspace => '預設工作區';

  @override
  String get workspaceEntryDefaultWorkspaceSubtitle => '新建對話時自動綁定，已有對話不受影響。';

  @override
  String get workspaceEntryDefaultWorkspaceUnset => '未設定';

  @override
  String get workspaceEntryDefaultWorkspaceAutomaticSubtitle =>
      '首次為對話綁定工作區時，將記為此助手的預設工作區。';

  @override
  String workspaceBindingRememberedDefault(String assistant) {
    return '已記為「$assistant」的預設工作區，新對話將自動使用。';
  }

  @override
  String workspaceBindingSuggestDefault(String assistant) {
    return '以後與「$assistant」的新對話也使用這個工作區？';
  }

  @override
  String get workspaceBindingUndoDefault => '復原';

  @override
  String get workspaceBindingUseAsDefault => '設為預設';

  @override
  String get workspaceEntryNone => '無';

  @override
  String get workspaceEntryStartConversationFirst => '請先開始對話';

  @override
  String get workspaceEntryTooltip => '工作區';

  @override
  String get workspaceEntryPickerTitle => '選擇工作區';

  @override
  String get settingsPageWorkspace => '工作區與環境';

  @override
  String get settingsPageSkills => '技能';

  @override
  String get commonClose => '關閉';

  @override
  String get terminalCopyAllOutput => '複製全部輸出';

  @override
  String get terminalFontDecrease => '字級 −';

  @override
  String get terminalFontIncrease => '字級 +';

  @override
  String get terminalCloseSessionConfirmMessage => '工作階段仍在執行。關閉將結束該程序。';

  @override
  String get terminalCopiedAll => '已複製全部輸出';

  @override
  String get terminalConfirm => '確認';

  @override
  String terminalExitCode(int code) {
    return 'exit $code';
  }

  @override
  String get workspaceMgmtNewWorkspace => '新增工作區';

  @override
  String get workspaceMgmtEmptyHint => '新增一個工作區來存放專案檔案和工作目錄。';

  @override
  String get workspaceMgmtKindManagedTitle => '託管工作區';

  @override
  String get workspaceMgmtKindManagedSubtitle => '應用程式內目錄，沙盒可讀寫';

  @override
  String get workspaceMgmtKindLinkedTitle => '連結資料夾';

  @override
  String get workspaceMgmtKindLinkedSubtitle => '直接使用本機資料夾';

  @override
  String get workspaceMgmtImportFromFolder => '從資料夾匯入';

  @override
  String get workspaceMgmtImportFromFolderSubtitle => '將資料夾複製到新的託管工作區';

  @override
  String get workspaceMgmtKindSection => '類型';

  @override
  String get workspaceMgmtCreate => '建立';

  @override
  String get workspaceMgmtShellApprovalSubtitle => '每次執行命令前詢問';

  @override
  String get workspaceMgmtDefaultCwdRoot => '/';

  @override
  String get workspaceMgmtPickCwdTitle => '預設工作目錄';

  @override
  String get workspaceMgmtFolderPickerUnavailable => '此裝置不支援選擇資料夾。';

  @override
  String get workspaceMgmtImportProgressTitle => '正在匯入資料夾';

  @override
  String get workspaceMgmtImportProgressPhase => '正在複製檔案…';

  @override
  String get workspaceMgmtImportFailed => '無法匯入該資料夾。';

  @override
  String workspaceMgmtImportDone(String name) {
    return '已匯入 $name';
  }

  @override
  String get workspaceMgmtLastUsedJustNow => '剛剛';

  @override
  String workspaceMgmtLastUsedMinutesAgo(int n) {
    return '$n 分鐘前';
  }

  @override
  String workspaceMgmtLastUsedHoursAgo(int n) {
    return '$n 小時前';
  }

  @override
  String workspaceMgmtLastUsedDaysAgo(int n) {
    return '$n 天前';
  }

  @override
  String workspaceMgmtRowDetail(String kind, String when) {
    return '$kind · 上次使用 $when';
  }

  @override
  String workspaceMgmtRowDetailNever(String kind) {
    return '$kind · 從未使用';
  }

  @override
  String get workspacePreviewBack => '返回';

  @override
  String get workspacePreviewWrap => '自動換行';

  @override
  String get workspacePreviewFontDecrease => '縮小字級';

  @override
  String get workspacePreviewFontIncrease => '增大字級';

  @override
  String get workspacePreviewCopy => '複製';

  @override
  String get workspacePreviewRetry => '重試';

  @override
  String get workspacePreviewLoadError => '無法載入此檔案。';

  @override
  String get workspacePreviewRevealInFinder => '在 Finder 中顯示';

  @override
  String get workspacePreviewOpenInSystemApp => '用系統應用程式開啟';

  @override
  String get workspacePreviewOpenInBrowser => '在瀏覽器中開啟';

  @override
  String get workspacePreviewTable => '表格';

  @override
  String get workspacePreviewPlainLanguage => '程式碼';

  @override
  String get workspacePreviewOpen => '開啟';

  @override
  String get workspacePreviewRevealFailed => '無法在檔案管理員中顯示此檔案。';

  @override
  String get workspacePreviewEmptyTable => '此表格為空。';

  @override
  String get workspaceFilesNew => '新增';

  @override
  String get workspaceFilesFoldersFirst => '資料夾優先';

  @override
  String get workspaceFilesSelectDirectory => '選擇此目錄';

  @override
  String get workspaceFilesEmptyHint => '用「新增」或「匯入」加入檔案';

  @override
  String get workspaceFilesEmptyAttachments => '還沒有附件';

  @override
  String get workspaceFilesEmptyOutputs => '助手還沒有產出檔案';

  @override
  String get workspaceFilesMoveTo => '移動到…';

  @override
  String workspaceFilesItemCount(int count) {
    return '$count 項';
  }

  @override
  String get skillsImportTooltip => '匯入技能';

  @override
  String get skillsImportPasteSubtitle => '貼上帶 frontmatter 的 SKILL.md';

  @override
  String get skillsImportFileSubtitle => '選擇 .md 或 .zip 檔案';

  @override
  String get skillsImportGitHubSubtitle => '從倉庫匯入 SKILL.md';

  @override
  String get skillsImportResolving => '正在解析儲存庫…';

  @override
  String get skillsImportDownloading => '正在下載…';

  @override
  String get skillsImportExtracting => '正在解壓縮…';

  @override
  String get skillsImportInstalling => '正在安裝…';

  @override
  String get skillsImportGitHubRepoLabel => '倉庫地址';

  @override
  String get skillsImportGitHubUrlHint =>
      'https://github.com/owner/repo 或 owner/repo[/path]';

  @override
  String get skillsImportGitHubHelp => '支援倉庫根目錄或子目錄下的 SKILL.md';

  @override
  String get skillsEmptyHint => '技能是帶 frontmatter 的 SKILL.md，匯入後助手可按需呼叫';

  @override
  String get skillsMoreActions => '更多';

  @override
  String get skillsSearchClear => '清除';

  @override
  String get skillsSessionEmpty => '還沒有已啟用的技能，請先在技能庫中啟用';

  @override
  String get workspaceToolRunning => '執行中';

  @override
  String workspaceToolExitCode(int code) {
    return 'exit $code';
  }

  @override
  String get workspaceToolAwaitingApproval => '等待核准';

  @override
  String get workspaceToolCompleted => '完成';

  @override
  String workspaceToolLines(int count) {
    return '$count 行';
  }

  @override
  String workspaceToolItems(int count) {
    return '$count 項';
  }

  @override
  String workspaceToolFileMatches(int count) {
    return '$count 個符合';
  }

  @override
  String workspaceToolContentMatches(int count) {
    return '$count 處符合';
  }

  @override
  String get workspaceToolExpand => '展開';

  @override
  String get workspaceToolSectionCommand => '命令';

  @override
  String get workspaceToolSectionPath => '路徑';

  @override
  String get workspaceToolSectionPattern => '模式';

  @override
  String get workspaceToolSectionOutput => '輸出';

  @override
  String get workspaceToolSectionDiff => '差異';

  @override
  String get workspaceToolSectionError => '錯誤';

  @override
  String get workspaceToolSavedOutput => '已儲存完整輸出';

  @override
  String get workspaceToolApprove => '允許';

  @override
  String get workspaceToolDeny => '拒絕';

  @override
  String get workspaceToolCopy => '複製';

  @override
  String get workspaceEnvEngineLocalShell => '本機 Shell';

  @override
  String get workspaceEnvInstallEnvironment => '安裝環境';

  @override
  String get workspaceEnvInstallDescription => '安裝 Linux 環境，以便在沙盒中執行工具。';

  @override
  String get workspaceEnvStatusLabel => '狀態';

  @override
  String get workspaceEnvStatusInstalled => '已安裝';

  @override
  String get workspaceEnvSizeLabel => '大小';

  @override
  String get workspaceEnvPathLabel => '路徑';

  @override
  String get workspaceEnvInstalledAtLabel => '安裝於';

  @override
  String get workspaceEnvArchLabel => '架構';

  @override
  String workspaceEnvArchVersion(String arch, String version) {
    return '$arch · $version';
  }

  @override
  String get workspaceEnvBrowseSection => '瀏覽';

  @override
  String get workspaceEnvBrowseFiles => '瀏覽檔案系統';

  @override
  String get workspaceEnvBrowseFilesDetail => '檢視沙盒中的完整目錄';

  @override
  String get workspaceEnvDetectFastMirrors => '偵測快速鏡像';

  @override
  String get workspaceEnvActionsSection => '操作';

  @override
  String get workspaceEnvInfoSection => '資訊';

  @override
  String get workspaceEnvInfoBody =>
      '環境是沙盒使用的 Linux 根檔案系統。工作區單獨存放，重設環境不會刪除工作區檔案。資料保存在本機已解壓的 rootfs 中。';

  @override
  String get workspaceEnvRepairDetail => '重新校驗並修補檔案';

  @override
  String get workspaceEnvUpdateCurrent => '已是最新';

  @override
  String workspaceEnvUpdateAvailableShort(String version) {
    return '可更新到 $version';
  }

  @override
  String get workspaceEnvResetConfirmMessage =>
      '這將刪除整個 Linux 環境及其中安裝的套件。工作區檔案不受影響。';

  @override
  String get workspaceEnvRestartDoneBanner => '重設已完成，請重新啟動應用以完成安裝。';

  @override
  String get workspaceEnvPathCopied => '已複製路徑';

  @override
  String get workspaceEnvUseMirrorSubtitle => '將所選鏡像寫入沙盒';

  @override
  String get workspaceEnvRegionGlobal => '全球';

  @override
  String get workspaceEnvRegionChina => '中國';

  @override
  String get workspaceEnvRegionEurope => '歐洲';

  @override
  String get workspaceEnvRegionAsia => '亞洲';

  @override
  String get workspaceEnvMirrorTimeout => '逾時';

  @override
  String get workspaceEnvSpeedTest => '測速';

  @override
  String get workspaceEnvApplySuccess => '鏡像已套用';

  @override
  String get workspaceEnvApplyFailed => '無法套用鏡像';

  @override
  String get workspaceEnvRestoreSuccess => '已恢復官方來源';

  @override
  String get workspaceEnvMirrorsTested => '已套用最快鏡像';

  @override
  String get workspaceEnvRelativeJustNow => '剛剛';

  @override
  String workspaceEnvRelativeMinutesAgo(int count) {
    return '$count 分鐘前';
  }

  @override
  String workspaceEnvRelativeHoursAgo(int count) {
    return '$count 小時前';
  }

  @override
  String workspaceEnvRelativeDaysAgo(int count) {
    return '$count 天前';
  }

  @override
  String workspaceEnvDownloadLine(
    String downloaded,
    String total,
    String phase,
  ) {
    return '$downloaded / $total · $phase';
  }

  @override
  String get workspaceEnvNativeUnsandboxed =>
      '指令在本機直接執行（無沙盒），除非此對話已啟用完全存取，否則需要批准。';

  @override
  String get workspaceEnvRootfsTitle => '/';

  @override
  String get workspaceEnvBrowserUnavailable => '沙盒檔案系統不可用。';

  @override
  String get workspaceEnvMirrorNameOfficial => '官方';

  @override
  String get workspaceEnvMirrorNameOfficialCdn => '官方 CDN';

  @override
  String get workspaceEnvMirrorNameOfficialPypi => '官方 PyPI';

  @override
  String get workspaceEnvMirrorNameOfficialNpm => '官方 npm';

  @override
  String get workspaceEnvMirrorNameTuna => '清華 TUNA';

  @override
  String get workspaceEnvMirrorNameAlibaba => '阿里雲';

  @override
  String get workspaceEnvMirrorNameUstc => '中科大 USTC';

  @override
  String get workspaceEnvMirrorNameHuawei => '華為雲';

  @override
  String get workspaceEnvMirrorNameTencent => '騰訊雲';

  @override
  String get workspaceEnvMirrorNameNetease => '網易';

  @override
  String get workspaceEnvMirrorNameLeaseweb => 'LEASEWEB UK';

  @override
  String get workspaceEnvMirrorNameRwth => 'RWTH Germany';

  @override
  String get workspaceEnvMirrorNameJaist => 'JAIST Japan';

  @override
  String get workspaceEnvMirrorNameKakao => 'Kakao Korea';

  @override
  String get workspaceEnvMirrorNameNpmmirror => 'npmmirror';

  @override
  String workspaceEnvSelectionNamed(String name, String region) {
    return '$name · $region';
  }

  @override
  String get workspaceFilesEmptyPickerHint => '點「新增資料夾」新增子資料夾';

  @override
  String get skillsDetailBodyEmpty => '還沒有技能正文';

  @override
  String skillsDetailBodyTooLarge(String size) {
    return '檔案較大，暫不支援預覽（$size）。';
  }

  @override
  String get workspaceEnvSizeTimeout => '計算逾時';

  @override
  String get workspaceEnvInfoCopied => '已複製環境資訊';

  @override
  String get workspacePreviewEmptyFile => '檔案為空';

  @override
  String get workspacePreviewEmptyHint => '此檔案沒有任何可預覽的內容。';

  @override
  String get workspacePreviewRevealInExplorer => '在檔案總管中顯示';

  @override
  String get workspacePreviewRevealInFileManager => '在檔案管理員中顯示';

  @override
  String workspaceBindingSetAssistantDefault(String assistant) {
    return '已設為「$assistant」的預設工作區';
  }

  @override
  String get storageSpaceCategoryWorkspaceFiles => '工作區檔案';

  @override
  String get storageSpaceCategoryWorkspaceFilesHint => '託管工作區中儲存的檔案。';

  @override
  String get storageSpaceCategorySandboxEnvironment => '沙箱環境';

  @override
  String get storageSpaceCategorySandboxEnvironmentHint => '沙箱安裝目錄與根檔案系統。';

  @override
  String get storageSpaceCategorySkills => '技能';

  @override
  String get storageSpaceCategorySkillsHint => '已安裝的技能檔案。';

  @override
  String get storageSpaceCategorySessionFiles => '會話檔案';

  @override
  String get storageSpaceCategorySessionFilesHint => '各對話的附件與輸出。';

  @override
  String get storageSpaceManageSkills => '管理技能';

  @override
  String get storageSessionFilesCleanOrphans => '清理無對話的會話檔案';

  @override
  String storageSessionFilesCleanOrphansHint(String size) {
    return '刪除已無對應對話的會話目錄。可回收 $size。';
  }

  @override
  String get workspaceDesktopFolderPath => '資料夾路徑';

  @override
  String get workspaceDesktopFolderMissing => '請選擇已存在的資料夾，或輸入它的絕對路徑。';

  @override
  String get workspaceDesktopManagedHint => '由 Kelivo 為此專案建立並管理資料夾。';

  @override
  String get workspaceDesktopHostHint => '在本機存取檔案和執行命令。';

  @override
  String get workspaceDesktopSearch => '搜尋工作區';

  @override
  String get workspaceDesktopNoResults => '沒有符合的工作區';

  @override
  String get workspaceEnvDependencies => '環境預設';

  @override
  String get workspaceEnvDependenciesDetail => '安裝到共用沙盒，所有工作區均可使用。';

  @override
  String get workspaceEnvDependencyPython => 'Python、pip 和虛擬環境';

  @override
  String get workspaceEnvDependencyNode => 'Node.js 和 npm';

  @override
  String get workspaceEnvDependencyGit => '複製儲存庫與版本管理';

  @override
  String get workspaceEnvDependencySsh => 'SSH、SCP、SFTP 與金鑰產生';

  @override
  String get workspaceEnvDependencyNetwork => '網路工具';

  @override
  String get workspaceEnvDependencyArchive => '壓縮工具';

  @override
  String get workspaceEnvDependencyInstalled => '已安裝';

  @override
  String get workspaceEnvDependencyUnknown => '未檢測';

  @override
  String get workspaceEnvDependencyChecking => '正在檢測工具…';

  @override
  String get workspaceEnvDependencyInstalling => '正在安裝…';

  @override
  String get workspaceEnvDependencyCheckFailed => '未能檢測工具，請重新整理再試。';

  @override
  String get workspaceEnvDependencyInstallFailed => '安裝未完成，請查看記錄或更換軟體套件來源後重試。';

  @override
  String get workspaceEnvDependencyLog => '安裝記錄';

  @override
  String get workspaceEnvDependencyRefresh => '重新整理工具狀態';

  @override
  String get workspaceEnvDependencyReadyFirst => '請先安裝沙盒環境，再安裝這些工具。';

  @override
  String get workspaceEnvDependencySources => '軟體套件來源';

  @override
  String get workspaceEnvDependencySourcesDetail =>
      '預設使用所選 apt/apk 來源安裝；pip 和 npm 來源用於後續安裝的軟體套件。';

  @override
  String get workspaceEnvDownloadSource => '沙盒下載來源';

  @override
  String get workspaceEnvDownloadAutomatic => '自動選擇最快來源';

  @override
  String get workspaceEnvDownloadAutomaticDetail => '下載前檢測官方來源和內建鏡像的速度。';

  @override
  String get workspaceEnvDownloadCustom => '自訂連結';

  @override
  String get workspaceEnvDownloadCustomHint =>
      'https://example.com/ubuntu-base/releases/24.04/release/';

  @override
  String get workspaceEnvDownloadCustomDetail =>
      '填寫映像目錄或完整下載連結，映像需符合所選系統、版本及裝置架構。';

  @override
  String get workspaceEnvDownloadInvalidUrl => '請輸入有效的 HTTP 或 HTTPS 連結。';

  @override
  String get workspaceEnvDownloadVerified =>
      '下載後會驗證所選映像的官方 SHA-256。軟體套件來源可另行設定。';

  @override
  String get workspaceEnvDownloadStart => '下載並安裝';

  @override
  String get workspaceEnvDownloadSave => '儲存下載來源';

  @override
  String get workspaceToolsTitle => '工具';

  @override
  String get workspaceToolsDescription => '選擇此工作區的對話可以使用哪些工具，修改後自動儲存。';

  @override
  String get workspaceToolHelpShell => '在工作區環境中執行命令。';

  @override
  String get workspaceToolHelpRead => '按行讀取檔案內容，支援分頁。';

  @override
  String get workspaceToolHelpViewImage => '讓模型檢視工作區中的圖片內容。';

  @override
  String get workspaceToolHelpWrite => '建立檔案或覆寫檔案內容。';

  @override
  String get workspaceToolHelpEdit => '取代現有檔案中的指定文字。';

  @override
  String get workspaceToolHelpList => '瀏覽目錄及其中的檔案。';

  @override
  String get workspaceToolHelpGlob => '按檔名或路徑模式尋找檔案。';

  @override
  String get workspaceToolHelpGrep => '搜尋檔案中的文字內容。';

  @override
  String get workspaceEnvVariablesTitle => '環境變數';

  @override
  String get workspaceEnvVariablesEntryDetail => '管理命令使用的變數與輸出隱私';

  @override
  String get workspaceEnvVariablesEmpty => '還沒有環境變數。可以新增工具需要的 API 金鑰等設定。';

  @override
  String get workspaceEnvVariablesScope =>
      '所有工作區共用。修改會用於新的 Agent 命令和應用程式內終端機工作階段，已有終端機需重新開啟。外部系統終端機使用其自身的環境變數。';

  @override
  String get workspaceEnvPrivacyMode => '隱私模式';

  @override
  String get workspaceEnvPrivacyDetail =>
      '命令仍能使用真實值。工作區工具輸出傳給模型前，匹配到的至少 5 個字元的變數值會替換為 [REDACTED]，本機日誌保留原文。較短的值不做遮蔽，以免誤替換常見開關和數字。';

  @override
  String get workspaceEnvVariableAdd => '新增變數';

  @override
  String get workspaceEnvVariableEdit => '編輯變數';

  @override
  String get workspaceEnvVariableName => '名稱';

  @override
  String get workspaceEnvVariableValue => '值';

  @override
  String get workspaceEnvVariableNote => '備註（選填）';

  @override
  String get workspaceEnvVariableNameHint =>
      '名稱使用字母、數字和底線，不能以數字開頭，區分大小寫。命令中可透過 \$NAME 使用變數。';

  @override
  String get workspaceEnvVariableInvalidName => '請輸入有效的變數名稱。';

  @override
  String get workspaceEnvVariableInvalidValue => '值不能為空，也不能包含空字元（NUL）。';

  @override
  String get workspaceEnvVariableDuplicate => '已存在同名變數。';

  @override
  String get workspaceEnvVariablesSaveFailed => '環境設定儲存失敗，請重試。';

  @override
  String get incomingShareTitle => '接收分享';

  @override
  String get incomingShareReplaceDraft => '輸入框中有尚未傳送的內容。是否替換為分享的內容，並開始新對話？';

  @override
  String get incomingShareFailed =>
      '部分分享內容未能匯入，請檢查檔案存取權限和可用儲存空間。一次最多分享 32 個檔案。';

  @override
  String get incomingShareImporting => '正在匯入';

  @override
  String get incomingShareMoveTo => '移動到…';

  @override
  String get incomingShareNewChat => '新對話';

  @override
  String get incomingShareMoveHint => '將草稿和附件移到其他對話，內容不會自動傳送。';

  @override
  String get incomingShareNoConversations => '沒有符合的對話';

  @override
  String get chatInputBarRemoveAttachment => '移除附件';

  @override
  String get incomingShareMoveFailed => '無法切換對話，草稿已保留。';

  @override
  String attachmentRequiresWorkspace(String name) {
    return '「$name」無法在一般對話中直接讀取。請綁定工作區並啟用檔案工具，或將草稿移到已有工作區的對話。';
  }

  @override
  String get storageSessionFilesUnlinked => '未關聯的對話';

  @override
  String get workspaceExternalMount => '掛載外部資料夾';

  @override
  String get workspaceExternalMountSubtitle =>
      '所選資料夾掛載至 /mounts/<name>，供各工作區的 AI 工具、Shell 和檔案瀏覽器存取。最多掛載 10 個資料夾。';

  @override
  String get workspaceExternalStorageTitle => '允許存取檔案';

  @override
  String get workspaceExternalStorageMessage =>
      '工作區和 Shell 需要直接讀寫外部資料夾，請在 Android 系統設定中允許 Kelivo 存取檔案。Android 11 及以上需開啟「所有檔案存取權限」，然後選擇要掛載的本機資料夾。';

  @override
  String get workspaceExternalGrantAccess => '前往授權';

  @override
  String get workspaceExternalLocalOnly =>
      'Android 僅支援掛載本機資料夾，此檔案提供者沒有可供 Shell 存取的本機目錄。';

  @override
  String get workspaceExternalUnavailable =>
      '外部資料夾無法使用。請檢查儲存裝置連線及存取權限，重新選擇資料夾以恢復存取。';

  @override
  String get workspaceExternalReconnect => '重新選擇資料夾';

  @override
  String get workspaceMountAdd => '新增資料夾';

  @override
  String get workspaceMountEdit => '編輯掛載';

  @override
  String get workspaceMountEmpty => '尚未掛載資料夾';

  @override
  String get workspaceMountReadOnly => '唯讀';

  @override
  String get workspaceMountReadWrite => '讀寫';

  @override
  String get workspaceMountAllowWrite => '允許寫入';

  @override
  String get workspaceMountPermissionsHint =>
      '關閉後，AI 檔案工具和檔案瀏覽器會拒絕修改此資料夾。Shell 會檢查部分常用檔案命令，但任意腳本不保證受限。儲存掛載變更時會停止正在執行的命令和終端工作階段。';

  @override
  String get workspaceMountBrowse => '瀏覽檔案';

  @override
  String get workspaceMountUnmount => '卸載';

  @override
  String get workspaceMountUnmountMessage => '卸載此掛載？原資料夾及其中的檔案會保留。';

  @override
  String get workspaceMountInactive => '無法使用，請重新選擇資料夾';

  @override
  String get workspaceMountInvalidName =>
      '名稱最多 64 個字元，不能包含斜線、冒號或控制字元，也不能為 . 或 ..。';

  @override
  String get workspaceMountDuplicate => '已存在同名掛載。';

  @override
  String get workspaceMountLimit => '最多掛載 10 個資料夾，請先卸載一個掛載。';

  @override
  String get workspaceMountOverlap => '此資料夾與已有掛載相同或互相包含。請選擇其他資料夾，以避免權限衝突。';

  @override
  String get workspaceMountTargetOccupied =>
      '/mounts 下的同名位置已有本機檔案。請更換掛載名稱，或先移走這些檔案。原有檔案未被刪除。';

  @override
  String get workspaceEnvSystemImage => '系統映像';

  @override
  String get workspaceEnvDistribution => '發行版';

  @override
  String get workspaceEnvSystemVersion => '版本';

  @override
  String get workspaceEnvLocalImage => '本機映像';

  @override
  String get workspaceEnvChooseImage => '選擇 rootfs 映像檔案';

  @override
  String get workspaceEnvLocalImageHint =>
      '支援根檔案系統壓縮包（.tar.gz、.tar.xz、.tar），不支援 ISO 或磁碟映像。映像需符合裝置 CPU 架構並包含 /bin/sh，解壓後自動識別系統和版本。';

  @override
  String get workspaceEnvImportImage => '匯入映像';

  @override
  String get workspaceEnvInvalidImage =>
      '請選擇適用於此裝置的 rootfs 映像，需包含可執行的 /bin/sh，且 CPU 架構相符。';

  @override
  String get workspaceEnvReplaceSystem => '更換系統';

  @override
  String get workspaceEnvReplaceSystemHint =>
      '更換會取代目前環境內的軟體套件和檔案，並停止執行中的命令與終端工作階段。工作區、聊天檔案和外部資料夾會保留。新映像準備失敗時保留原有環境。';

  @override
  String get workspaceEnvProotOptions => 'PRoot 設定';

  @override
  String get workspaceEnvShellPath => 'Shell 路徑';

  @override
  String get workspaceEnvShellAutomatic => '自動選擇';

  @override
  String get workspaceEnvShellHint =>
      '留空時優先使用 /bin/bash，否則使用 /bin/sh。自訂 Shell 需填寫環境內的絕對路徑。';

  @override
  String get workspaceEnvProotArguments => '額外 PRoot 參數';

  @override
  String get workspaceEnvProotArgumentsHint =>
      '每行填寫一個參數，無需 Shell 引號。例如將 -k 和 5.10.0 分別放在兩行，或使用 --kernel-release=5.10.0。設定對之後啟動的命令和終端工作階段生效。';

  @override
  String get workspaceEnvProotInvalid => '請填寫有效的 Shell 絕對路徑，並將 PRoot 參數逐行填寫。';

  @override
  String get workspaceFileMissing => '檔案已不存在';

  @override
  String get workspaceFilePreviewUnavailable => '無法預覽';

  @override
  String get workspaceToolRelatedFiles => '相關檔案';

  @override
  String get workspaceToolFilesTruncated => '僅列出部分檔案。';

  @override
  String get displaySettingsPageShowProducedFilesTitle => '顯示回覆底部檔案卡片';

  @override
  String get displaySettingsPageShowProducedFilesSubtitle =>
      '在回覆底部顯示工具建立或修改的檔案。';

  @override
  String get defaultModelPagePerChatModelTitle => '每個對話獨立模型';

  @override
  String get defaultModelPagePerChatModelSubtitle =>
      '開啟後，在對話中切換模型只影響目前對話；關閉後會直接修改目前助手的模型，使用該助手的所有對話都會跟隨。';

  @override
  String get googleFontsTitle => 'Google Fonts';

  @override
  String get googleFontsRefresh => '重新整理字型列表';

  @override
  String get googleFontsSearchHint => '搜尋字型或語言';

  @override
  String get googleFontsHint =>
      '下載一般字重字型後預覽並套用，已安裝字型可離線使用。目錄來自 Expo Google Fonts，字型從 Google Fonts 下載。';

  @override
  String get googleFontsNoResults => '沒有符合的字型';

  @override
  String get googleFontsFailed => '無法載入、下載或套用字型，請檢查網路後重試。';

  @override
  String get googleFontsDownloading => '正在下載字型…';

  @override
  String get googleFontsPreview => '字型預覽：你好，世界！Hello world 0123456789';

  @override
  String get googleFontsLicense => '字型授權條款';

  @override
  String get assistantEditLocationPermissionSettingsMessage =>
      '定位權限已被禁止。請在系統設定中允許定位存取，然後重新開啟此工具。';

  @override
  String get healthDataSettingsCategoryReproductive => '生殖健康';

  @override
  String get healthDataSettingsTypeMenstrualFlowTitle => '經期記錄';

  @override
  String get healthDataSettingsTypeMenstrualFlowSubtitle =>
      '最近 90 天記錄的經量與週期開始日期';

  @override
  String get assistantEditGradientBackgroundTitle => '漸層背景';

  @override
  String get assistantEditGradientStaticTitle => '靜態模式';

  @override
  String get assistantEditGradientStaticDescription => '更省電，適合長對話和持續輸出。';

  @override
  String get assistantEditGradientHorizontal => '水平位置';

  @override
  String get assistantEditGradientVertical => '垂直位置';

  @override
  String get assistantEditGradientPreview => '預覽';

  @override
  String get assistantEditGradientNextFrame => '換一幀';

  @override
  String get backgroundSettingsTitle => '背景任務';

  @override
  String get backgroundTaskTitle => 'Kelivo 任務';

  @override
  String get backgroundCompleted => '生成完成';

  @override
  String get backgroundFailed => '生成失敗，請開啟對話查看詳情。';

  @override
  String get backgroundCancelled => '生成已取消';

  @override
  String get backgroundInterrupted => '背景生成已中斷，請開啟對話繼續。';

  @override
  String get backgroundRequesting => '正在請求';

  @override
  String get backgroundGenerating => '正在生成回覆';

  @override
  String get backgroundThinking => '正在思考';

  @override
  String get backgroundToolRunning => '正在執行工具';

  @override
  String get backgroundRetrying => '等待重試';

  @override
  String get backgroundWorking => '正在處理';

  @override
  String get backgroundTasks => '任務';

  @override
  String get backgroundStopTasks => '停止任務';

  @override
  String get backgroundOpenChat => '開啟對話';

  @override
  String get backgroundAndroidEnabled => '背景生成';

  @override
  String get backgroundAndroidEnabledDetail =>
      '在鎖定螢幕、切到背景或劃掉最近任務後繼續目前的生成。任務執行期間會顯示系統常駐通知。';

  @override
  String get backgroundIosEnabled => '增強背景執行';

  @override
  String get backgroundIosEnabledDetail => '為目前任務申請背景執行時間。可另外開啟定位或靜音音訊輔助保活。';

  @override
  String get backgroundNotifications => '任務通知';

  @override
  String get backgroundNotificationsDetail =>
      '在目前查看的對話之外完成或失敗時通知。此開關不控制 Android 必需的常駐通知。';

  @override
  String get backgroundPrivacy => '任務狀態隱私';

  @override
  String get backgroundPrivacyDetail => '在通知和即時狀態中隱藏對話標題及工具詳情，僅顯示通用狀態、任務數量和耗時。';

  @override
  String get backgroundLiveActivities => '即時動態';

  @override
  String get backgroundLiveActivitiesDetail =>
      '在鎖定畫面和動態島顯示目前任務，是否可用及展示位置由系統決定。';

  @override
  String get backgroundOverlay => '任務懸浮視窗';

  @override
  String get backgroundOverlayDetail =>
      '在其他應用程式上顯示可拖動的任務懸浮視窗。點擊進入對話；關閉按鈕僅隱藏懸浮視窗。';

  @override
  String get backgroundLiveUpdates => '即時通知 / 動態島';

  @override
  String get backgroundLiveUpdatesDetail =>
      '在支援的裝置上使用 Android 16 即時通知。系統成功展示即時通知時優先於懸浮視窗。';

  @override
  String get backgroundLocation => '定位輔助保活';

  @override
  String get backgroundLocationDetail =>
      '在背景任務期間使用低精度定位輔助執行，不儲存座標或傳送給 AI 服務。需要開啟增強背景執行並授權定位。';

  @override
  String get backgroundSilentAudio => '靜音音訊保活';

  @override
  String get backgroundSilentAudioDetail =>
      '背景任務執行時播放靜音音訊，並讓位於錄音和朗讀。需要開啟增強背景執行，無需麥克風權限。';

  @override
  String get backgroundSpeech => '背景朗讀';

  @override
  String get backgroundSpeechDetail => '鎖定螢幕或切到背景時繼續系統及網路朗讀。關閉時，切到背景會暫停朗讀。';

  @override
  String get backgroundFinishVisibility => '完成狀態保留時間';

  @override
  String get backgroundFinishImmediately => '立即收起';

  @override
  String get backgroundFinishOneMinute => '1 分鐘';

  @override
  String get backgroundFinishFiveMinutes => '5 分鐘';

  @override
  String get backgroundFinishUntilForeground => '回到應用程式時收起';

  @override
  String get backgroundFinishVisibilityDetail =>
      '用於 Android 懸浮視窗和 iOS 鎖定畫面完成卡片。回到應用程式時清理完成狀態，最長保留 15 分鐘；取消任務立即收起。';

  @override
  String get backgroundOverlayIcon => '懸浮視窗圖示';

  @override
  String get backgroundIconDefault => 'Kelivo 圖示';

  @override
  String get backgroundIconImage => '選擇圖片';

  @override
  String get backgroundIconEmoji => '選擇 Emoji';

  @override
  String get backgroundPermissionsTitle => '權限與系統設定';

  @override
  String get backgroundNotificationsPermission => '通知權限';

  @override
  String get backgroundBatteryOptimization => '電池最佳化';

  @override
  String get backgroundBatteryOptimizationDetail => '允許不受限制地使用電池可改善背景執行。';

  @override
  String get backgroundAutostart => '自動啟動與背景執行';

  @override
  String get backgroundAutostartDetail =>
      '請手動檢查裝置的自動啟動和背景限制。Android 無法可靠查詢這些廠商設定的授權狀態。';

  @override
  String get backgroundLocationPermission => '定位權限';

  @override
  String get backgroundLocationAlways => '允許持續背景定位';

  @override
  String get backgroundLocationAlwaysDetail => '可進一步授予「永遠允許」定位權限，僅在點擊此入口時申請。';

  @override
  String get backgroundSystemSettings => '應用程式系統設定';

  @override
  String get backgroundPermissionGranted => '已允許';

  @override
  String get backgroundPermissionDenied => '未允許';

  @override
  String get backgroundPermissionLimited => '使用應用程式期間';

  @override
  String get backgroundPermissionUnknown => '需手動檢查';

  @override
  String get backgroundPermissionNotDetermined => '尚未申請';

  @override
  String get backgroundRuntimeTitle => '目前狀態';

  @override
  String get backgroundRuntimeActive => '正在執行';

  @override
  String get backgroundRuntimeIdle => '未執行';

  @override
  String get backgroundLocationActive => '背景定位';

  @override
  String get backgroundAudioActive => '靜音音訊';

  @override
  String get backgroundActivityActive => '即時動態';

  @override
  String get backgroundOverlayActive => '懸浮視窗';

  @override
  String get backgroundLastError => '最近中斷或錯誤';

  @override
  String get backgroundNoError => '暫無紀錄';

  @override
  String get backgroundUnsupported => '目前裝置不支援或系統設定未允許';

  @override
  String get backgroundIosLimit =>
      '背景執行由 iOS 控制，即時動態本身無法保活。強制結束可能停止生成，即時狀態可能要等再次開啟應用程式後才能清理。';

  @override
  String get backgroundAndroidLimit =>
      '如任務中斷，請檢查通知、電池及廠商背景設定。系統強制停止或終止程序仍可能中斷生成。';

  @override
  String get backgroundStale => '狀態暫未更新，請開啟應用程式查看。';

  @override
  String get backgroundIconError => '無法匯入此圖片，請選擇其他圖片。';

  @override
  String get backgroundNotificationChannels => '通知管道';

  @override
  String get backgroundCompletionChannel => '任務完成通知頻道';

  @override
  String get backgroundOngoingChannel => '任務執行通知頻道';

  @override
  String get backgroundOverlayAppearance => '懸浮窗外觀';

  @override
  String get backgroundOverlayAppearanceDetail => '調整尺寸、圖示、進度環和顯示內容';

  @override
  String get backgroundOverlayPreviewHint => '拖曳可移動 · 點擊進入對話 · 長按可收起';

  @override
  String get backgroundOverlayCard => '資訊卡片';

  @override
  String get backgroundOverlayCircle => '圓形圖示';

  @override
  String get backgroundOverlaySize => '尺寸與形狀';

  @override
  String get backgroundOverlayWidth => '寬度';

  @override
  String get backgroundOverlayHeight => '高度';

  @override
  String get backgroundOverlayCornerRadius => '圓角';

  @override
  String get backgroundOverlayIconSize => '圖示大小';

  @override
  String get backgroundOverlayProgressSize => '進度環直徑';

  @override
  String get backgroundOverlayProgressStroke => '進度環粗細';

  @override
  String get backgroundOverlayContent => '顯示內容';

  @override
  String get backgroundOverlayShowProgress => '顯示進度環';

  @override
  String get backgroundOverlayShowTitle => '顯示標題';

  @override
  String get backgroundOverlayShowSubtitle => '顯示副標題';

  @override
  String get backgroundOverlayShowTime => '顯示耗時';

  @override
  String get backgroundOverlayShowClose => '顯示關閉按鈕';

  @override
  String get backgroundOverlayShowBackground => '顯示背景';

  @override
  String get backgroundOverlayShowBorder => '顯示邊框';

  @override
  String get backgroundOverlayReset => '恢復預設樣式';

  @override
  String get mcpStdioEnvironmentRequired => '請先安裝工作區執行環境，再使用行動版 STDIO。';

  @override
  String get mcpArgumentsHint => '用空格分隔參數，包含空格的內容用引號包裹；空參數寫成 \'\'。';

  @override
  String get mcpArgumentsInvalid => '請檢查參數中的引號是否閉合、結尾是否有未完成的跳脫。';

  @override
  String get mcpImportEnvironment => '從環境匯入';

  @override
  String get mcpEnvironmentEmpty => '尚無環境變數，請先在環境設定中新增。';

  @override
  String get mcpEnvironmentHint => '預設繼承執行環境的變數，匯入後可為此伺服器個別修改。';

  @override
  String get mcpImportJson => '匯入 JSON';

  @override
  String get mcpImportJsonHint =>
      '貼上 Claude Desktop 或 Cursor 的 MCP 設定，預覽後新增伺服器，不覆蓋現有設定。';

  @override
  String get mcpImportPaste => '從剪貼簿貼上';

  @override
  String get mcpImportPreview => '預覽';

  @override
  String get mcpImportConfirm => '匯入';

  @override
  String get startupRecoverySnapshotTitle => '從資料庫快照還原';

  @override
  String get startupRecoverySnapshotBody =>
      '即使資料庫無法開啟，也可以選擇本機快照還原聊天和設定。請勿解除安裝 Kelivo，解除安裝會一併刪除這些快照。';

  @override
  String get startupRecoverySnapshotEmpty => '未在本機找到資料庫快照。請先匯出資料，再嘗試其他還原操作。';

  @override
  String get startupRecoverySnapshotButton => '選擇快照還原';

  @override
  String startupRecoverySnapshotConfirm(String when) {
    return '將聊天和設定還原到 $when 的快照？快照之後的變更不會包含在內。現有附件檔案和快照會保留，Kelivo 將重新啟動以完成還原。';
  }

  @override
  String startupRecoverySnapshotFailed(String reason) {
    return '無法準備快照還原：$reason';
  }

  @override
  String get startupRecoverySnapshotReady => '快照已準備好，請重新啟動 Kelivo 完成還原。';

  @override
  String get scheduledTasksTitle => '定時任務';

  @override
  String get scheduledTasksDescription => '在指定時間自動執行任務，支援新增聊天、繼續追問或重新執行。';

  @override
  String get scheduledTasksEmpty => '把任務交給時間';

  @override
  String get scheduledTasksEmptyDetail => '晨間簡報、每日回顧，或任何希望定期完成的事。';

  @override
  String get scheduledTasksAdd => '新增任務';

  @override
  String get scheduledTasksEdit => '編輯任務';

  @override
  String get scheduledTasksName => '任務名稱';

  @override
  String get scheduledTasksNameHint => '晨間簡報';

  @override
  String get scheduledTasksPrompt => '任務內容';

  @override
  String get scheduledTasksPromptHint => '希望助手為你完成什麼？';

  @override
  String get scheduledTasksAssistant => '執行助手';

  @override
  String get scheduledTasksChooseAssistant => '選擇助手';

  @override
  String get scheduledTasksAssistantMissing => '助手已不存在';

  @override
  String get scheduledTasksTime => '執行時間';

  @override
  String get scheduledTasksTimeHint => '24 小時制，例如 08:00';

  @override
  String get scheduledTasksRepeat => '重複';

  @override
  String get scheduledTasksEveryDay => '每天';

  @override
  String get scheduledTasksWeekdays => '工作日';

  @override
  String get scheduledTasksEnabled => '啟用任務';

  @override
  String get scheduledTasksPermission => '鬧鐘和提醒';

  @override
  String get scheduledTasksPermissionDetail =>
      '允許設定鬧鐘，才能按指定時間執行。未授權時，已啟用的任務會等待授權。';

  @override
  String get scheduledTasksPermissionAction => '前往授權';

  @override
  String get scheduledTasksReliability =>
      '建議在電池設定中允許 Kelivo 背景執行。強制停止後需重新開啟應用程式。錯過的任務不會補跑，執行時間跟隨裝置時區。';

  @override
  String get scheduledTasksExecutionDetail =>
      '結果儲存在對話中，完成後會傳送回覆預覽通知，點擊可開啟對話。單次最多執行 10 分鐘；需要使用者回答或工具確認時會停止。';

  @override
  String get scheduledTasksRunNow => '立即執行';

  @override
  String get scheduledTasksHistory => '執行紀錄';

  @override
  String get scheduledTasksNoRuns => '尚無執行紀錄';

  @override
  String get scheduledTasksRunning => '正在執行';

  @override
  String get scheduledTasksCompleted => '已完成';

  @override
  String get scheduledTasksFailed => '執行失敗';

  @override
  String get scheduledTasksInterrupted => '已中斷';

  @override
  String get scheduledTasksPaused => '已暫停';

  @override
  String get scheduledTasksWaitingPermission => '等待授權';

  @override
  String scheduledTasksNextRun(String time) {
    return '下次：$time';
  }

  @override
  String get scheduledTasksDelete => '刪除任務';

  @override
  String get scheduledTasksDeleteDetail => '刪除此任務及執行紀錄？已經產生的對話會保留。';

  @override
  String get scheduledTasksSave => '儲存';

  @override
  String get scheduledTasksCancel => '取消';

  @override
  String get scheduledTasksInvalid => '請填寫名稱、任務內容和助手，自訂重複需至少選擇一天。';

  @override
  String get scheduledTasksLoading => '正在載入…';

  @override
  String get scheduledTasksOpenChat => '查看對話';

  @override
  String get scheduledTasksNeedsInput => '任務需要使用者回答或工具確認，已停止。可開啟對話繼續。';

  @override
  String get scheduledTasksTimeout => '已達到執行時限。';

  @override
  String get scheduledTasksProcessTerminated => '上次執行被系統終止。';

  @override
  String get scheduledTasksOnce => '僅一次';

  @override
  String get scheduledTasksCustom => '自訂';

  @override
  String get scheduledTasksExecution => '執行任務';

  @override
  String get scheduledTasksMode => '執行方式';

  @override
  String get scheduledTasksNewChat => '新增聊天';

  @override
  String get scheduledTasksFollowUp => '繼續追問';

  @override
  String get scheduledTasksRegenerate => '重新執行';

  @override
  String get scheduledTasksChat => '目標聊天';

  @override
  String get scheduledTasksChooseChat => '選擇聊天';

  @override
  String get scheduledTasksMessage => '重新執行的問題';

  @override
  String get scheduledTasksChooseMessage => '選擇問題';

  @override
  String get scheduledTasksAttachmentMessage => '含附件的訊息';

  @override
  String get scheduledTasksModel => '模型';

  @override
  String get scheduledTasksChooseModel => '選擇模型';

  @override
  String get scheduledTasksModelDefault => '跟隨聊天或助手的模型';

  @override
  String get scheduledTasksSchedule => '執行時間';

  @override
  String get scheduledTasksActiveWindow => '活動時段';

  @override
  String get scheduledTasksStartDate => '開始日期';

  @override
  String get scheduledTasksEndDate => '結束日期';

  @override
  String get scheduledTasksActiveWindowDetail =>
      '僅在此日期範圍內執行，包含結束當天。未設定的日期不作限制。';

  @override
  String get scheduledTasksDate => '日期';

  @override
  String get scheduledTasksDateUnrestricted => '不限';

  @override
  String get scheduledTasksClear => '清除';

  @override
  String get scheduledTasksSearch => '搜尋';

  @override
  String get scheduledTasksNoTargets => '此助手下沒有符合條件的內容';

  @override
  String get scheduledTasksFutureDate => '請選擇未來的執行日期和時間。';

  @override
  String get scheduledTasksDateRangeInvalid => '結束日期不能早於開始日期。';

  @override
  String get scheduledTasksRegenerateDetail =>
      '使用原有上下文，為所選問題產生新的回答，保留已有回答和後續訊息。';

  @override
  String get scheduledTasksSaving => '正在儲存…';

  @override
  String get scheduledTasksFinished => '排程已結束';

  @override
  String get scheduledTasksModelMissing => '所選模型已無法使用，請編輯任務重新選擇。';

  @override
  String get scheduledTasksChatMissing => '目標聊天已不存在或已移至其他助手。';

  @override
  String get scheduledTasksMessageMissing => '所選問題已不存在，請重新選擇。';

  @override
  String get scheduledTasksChatBusy => '此聊天正在產生回答，本次任務已略過。';

  @override
  String get scheduledTasksDesktopEmpty => '尚無排程任務';

  @override
  String get scheduledTasksDesktopReliability =>
      '僅在 Kelivo 執行時運作，最小化或常駐系統匣時也會繼續。結束或電腦休眠期間錯過的任務不會補執行，也不會自動啟動應用程式。';

  @override
  String get scheduledTasksDesktopExecutionDetail =>
      '結果儲存在對話中，可從任務的執行記錄開啟。單次最多執行 10 分鐘；需要使用者回答或工具確認時會停止。';

  @override
  String get worldBookStickyLabel => '黏滯（訊息數）';

  @override
  String get worldBookStickyHint => '觸發後在後續 N 則訊息中保持啟用，重複命中不延長。0 表示關閉。';

  @override
  String get worldBookCooldownLabel => '冷卻（訊息數）';

  @override
  String get worldBookCooldownHint => '觸發後（或黏滯結束後）N 則訊息內不再觸發。0 表示關閉。';

  @override
  String get worldBookDelayLabel => '延遲（訊息數）';

  @override
  String get worldBookDelayHint => '對話至少有 N 則訊息時才允許觸發。按單則訊息計數，不是對話輪數。0 表示關閉。';

  @override
  String get worldBookDragToReorder => '拖曳調整順序';

  @override
  String worldBookEnabledCount(int enabled, int total) {
    return '已啟用 $enabled/$total';
  }

  @override
  String get assistantConversationSystemPromptTitle => '獨立對話系統提示';

  @override
  String get assistantConversationSystemPromptHint => '允許每個對話設定自己的系統提示詞。';

  @override
  String get assistantConversationInjectionTitle => '獨立對話指令注入';

  @override
  String get assistantConversationInjectionHint => '每個對話單獨選擇指令注入和世界書，預設不選取。';

  @override
  String get conversationSystemPromptTitle => '對話系統提示詞';

  @override
  String get conversationSystemPromptHint => '僅對目前對話生效，留空時使用助理的系統提示詞。';

  @override
  String get conversationSystemPromptClear => '恢復助理提示詞';

  @override
  String get conversationSystemPromptPlaceholder => '為這個對話編寫系統提示詞…';

  @override
  String get conversationPromptScope => '僅目前對話';

  @override
  String get oauthAccountsTab => '帳號登入';

  @override
  String get oauthLogin => '登入';

  @override
  String oauthLoginTo(String provider) {
    return '登入 $provider';
  }

  @override
  String get oauthConnected => '已連線';

  @override
  String get oauthNotConnected => '未連線';

  @override
  String oauthWaiting(String provider) {
    return '正在等待 $provider 授權';
  }

  @override
  String get oauthCancel => '取消授權';

  @override
  String get oauthOpenBrowser => '開啟授權頁面';

  @override
  String get oauthCopyCode => '複製驗證碼';

  @override
  String get oauthCodeHint => '在授權頁面輸入此驗證碼';

  @override
  String get oauthDeviceHint => '請先在 ChatGPT 安全設定或工作區權限中啟用裝置碼登入。';

  @override
  String get oauthDeviceLogin => '使用裝置碼登入';

  @override
  String get oauthDetails => '查看帳號詳情';

  @override
  String get oauthConnectAnother => '再連一個';

  @override
  String get oauthRelogin => '重新登入';

  @override
  String get oauthNeedsLogin => '需重新登入';

  @override
  String oauthExpired(String provider) {
    return '$provider 登入已過期';
  }

  @override
  String get oauthLoginRestored => '已重新登入，可使用訊息的重試按鈕再次傳送。';

  @override
  String get oauthLogout => '登出';

  @override
  String get oauthLogoutDescription => '清除此帳號在本機儲存的授權憑證';

  @override
  String get oauthRefreshing => '正在續期授權…';

  @override
  String get oauthRefreshUsage => '重新整理用量';

  @override
  String get oauthUsageDetails => '用量明細';

  @override
  String get oauthUsageUnavailable => '暫時無法取得用量';

  @override
  String oauthLastUpdated(String time) {
    return '更新於 $time';
  }

  @override
  String get oauthSyncModels => '同步';

  @override
  String get oauthSyncing => '正在同步模型…';

  @override
  String get oauthModelsHint => '可用模型由帳號同步。';

  @override
  String get oauthNoModels => '同步模型後即可開始對話';

  @override
  String get oauthConnection => '連線';

  @override
  String get oauthConnectionInfo => '連線資訊';

  @override
  String get oauthEndpoint => '連線端點';

  @override
  String get oauthScope => '授權範圍';

  @override
  String get oauthAccountId => '帳號 ID';

  @override
  String get oauthTokenExpiry => '權杖有效期限';

  @override
  String get oauthName => '供應商名稱';

  @override
  String get oauthEnabledHint => '在模型選擇器中顯示這些模型';

  @override
  String get oauthNetwork => '網路代理';

  @override
  String get oauthFollowGlobal => '跟隨全域設定';

  @override
  String get oauthCustomRequest => '自訂請求';

  @override
  String get oauthWeekly => '本週視窗';

  @override
  String get oauthMonthly => '本月視窗';

  @override
  String get oauthTotal => '總額度';

  @override
  String oauthHours(String count) {
    return '$count 小時視窗';
  }

  @override
  String oauthMinutes(String count) {
    return '$count 分鐘視窗';
  }

  @override
  String oauthDays(String count) {
    return '$count 天視窗';
  }

  @override
  String get oauthWindow => '用量視窗';

  @override
  String oauthResetsAt(String time) {
    return '重設於 $time';
  }

  @override
  String oauthUsedValue(String value) {
    return '已用 $value';
  }

  @override
  String get oauthNetworkError => '連線失敗，請檢查網路後重試。';

  @override
  String get oauthInvalidResponse => '授權未完成，請重試。';

  @override
  String get oauthTimeout => '授權逾時，請重試。';

  @override
  String get oauthDenied => '授權未獲批准，請重試。';

  @override
  String get oauthSaving => '正在連接帳號…';

  @override
  String get oauthQuotaExceeded => '此帳號暫無可用額度。';

  @override
  String get oauthRateLimited => '請求過於頻繁，請稍後重試。';

  @override
  String get oauthPermissionDenied => '此帳號無權存取此資源。';

  @override
  String get oauthRequestFailed => '供應商未能完成請求。';

  @override
  String get oauthQuotaAvailable => '額度可用';

  @override
  String oauthSavedResets(String count) {
    return '可用額度重設次數：$count';
  }

  @override
  String get oauthPrimaryWindow => '主要視窗';

  @override
  String get oauthSecondaryWindow => '次要視窗';

  @override
  String get oauthAuthorizationCode => '授權碼或回呼連結';

  @override
  String get oauthAuthorizationCodeHint => '如果瀏覽器沒有自動返回，請將最後的回呼連結或授權碼貼到這裡。';

  @override
  String get oauthInvalidAuthorizationCode => '請輸入本次登入的授權碼或回呼連結。';

  @override
  String get oauthSubmitAuthorizationCode => '完成登入';

  @override
  String get oauthExtraUsage => '額外用量';

  @override
  String get oauthPromptCachingHelp => '重用多輪對話中的上下文，可設定快取保留時間。';

  @override
  String get scheduledTasksPreparation => '執行與通知';

  @override
  String get scheduledTasksAllowPreparation => '允許提前準備';

  @override
  String get scheduledTasksPreparationDetail =>
      '提前準備適合不依賴即時資訊的文字任務，不會使用工具、附件或執行外部操作。';

  @override
  String get scheduledTasksIOSDetail =>
      '受 iOS 背景限制，Kelivo 不能在指定時間自動喚醒並執行模型。此功能會在 App 可執行時提前準備內容，由系統到點顯示通知。每次僅準備下一次結果；離開 App 後不保證準備完成，後續任務需再次開啟 Kelivo 才能補充。';

  @override
  String get scheduledTasksContextPolicy => '對話上下文';

  @override
  String get scheduledTasksContextLatest => '跟隨最新對話';

  @override
  String get scheduledTasksContextSnapshot => '使用準備時的快照';

  @override
  String get scheduledTasksUnavailable => '無法執行時';

  @override
  String get scheduledTasksRemind => '僅傳送提醒';

  @override
  String get scheduledTasksSkip => '略過本次';

  @override
  String get scheduledTasksNotify => '結果通知';

  @override
  String get scheduledTasksShowPreview => '通知顯示結果全文';

  @override
  String get scheduledTasksPreparationWindow => '最多提前';

  @override
  String get scheduledTasksPreparationAttempts => '自動準備次數上限';

  @override
  String get scheduledTasksPreparationCooldown => '準備最小間隔（分鐘）';

  @override
  String get scheduledTasksPreparationBudget =>
      '所有任務合計最多同時準備一個。每小時累計嘗試六次後暫停自動準備，取消的請求也計入次數；「立刻準備」不受次數上限限制。';

  @override
  String get scheduledTasksPreparing => '正在準備結果';

  @override
  String get scheduledTasksPrepared => '結果已準備';

  @override
  String get scheduledTasksPendingPreparation => '本次尚未準備';

  @override
  String get scheduledTasksNotificationRegistered => '通知已登記';

  @override
  String get scheduledTasksNotificationUnavailable => '通知未登記';

  @override
  String get scheduledTasksReminded => '已到期 · 僅提醒';

  @override
  String get scheduledTasksSkipped => '已略過';

  @override
  String get scheduledTasksCancelled => '已取消';

  @override
  String get scheduledTasksReminderBody => '定時任務已到期，開啟 Kelivo 繼續。';

  @override
  String get scheduledTasksResultBody => '定時任務結果已準備好。';

  @override
  String get scheduledTasksNotificationPermission => '允許任務通知';

  @override
  String get scheduledTasksPreparationCost =>
      '提前準備會呼叫模型，可能產生額外費用。選擇「跟隨最新對話」時，到期前的新訊息可能使已準備內容失效。即使結果未使用或請求被取消，仍可能計費；重新準備會再次呼叫模型。';

  @override
  String get scheduledTasksAllowPreparationTip =>
      '在 Kelivo 可執行時，提前產生下一次任務的結果，到期前不會顯示在聊天中。僅使用文字，不使用工具、附件或自訂請求內容；呼叫模型可能產生費用。';

  @override
  String get scheduledTasksContextPolicyTip =>
      '跟隨最新對話：到期前傳送新訊息、編輯訊息或切換訊息版本後，已準備內容會失效；重新準備會占用次數，並可能增加費用。到期後，已儲存的通知結果會原樣補入對話。\n\n使用準備時的快照：對話變化後仍保留已準備結果，內容不會包含後續聊天。';

  @override
  String get scheduledTasksPreparationWindowTip =>
      '允許在任務到期前多久開始準備，最長 24 小時。例如第二天早上提醒，前一天中午開啟 Kelivo 時就有機會準備。時間越長，準備機會越多，但內容也可能更早過時。不會改變任務時間，也不代表能在背景定時執行。「立刻準備」不受這項自動等待和準備次數上限限制。';

  @override
  String get scheduledTasksPreparationAttemptsTip =>
      '本次累計嘗試達到上限後，自動準備會暫停。首次、失敗、取消和手動準備都計入嘗試記錄；「立刻準備」不受此上限限制。嘗試越多，可能產生的模型費用越多，這不是費用上限。';

  @override
  String get scheduledTasksPreparationCooldownTip =>
      '同一次任務兩次開始準備之間，至少間隔多少分鐘。間隔越長，重複請求越少。重試仍需 App 有執行機會，不是在背景設定一個計時器。「立刻準備」不受這項自動等待和準備次數上限限制。';

  @override
  String get scheduledTasksUnavailableTip =>
      '到期時沒有可用結果、也無法執行任務，就傳送提醒或略過本次。提醒不包含模型產生的回答，且需要開啟通知。如果到期時 Kelivo 正在開啟執行，可直接執行任務。';

  @override
  String get scheduledTasksNotifyTip =>
      '允許傳送結果通知和無法執行時的提醒。關閉後仍會執行任務、呼叫模型，提前準備也仍可能產生費用。還需要允許系統通知權限。';

  @override
  String get scheduledTasksShowPreviewTip =>
      '在通知中顯示已產生的結果，系統設定允許時也會顯示在鎖定畫面上。關閉後只顯示一般提示，完整結果仍可在聊天中查看；同時遵循全域通知隱私設定。';

  @override
  String scheduledTasksHours(int count) {
    return '$count 小時';
  }

  @override
  String scheduledTasksMinutes(int count) {
    return '$count 分鐘';
  }

  @override
  String get scheduledTasksPreparationOff => '未開啟準備';

  @override
  String get scheduledTasksPreparationQueued => '排隊中';

  @override
  String get scheduledTasksPreparationQueuedDetail => '正在準備其他任務，隨後按到期時間依次準備。';

  @override
  String get scheduledTasksPreparationIdle => '等待空閒';

  @override
  String get scheduledTasksPreparationIdleDetail => '等待目前回覆完成或此任務的對話狀態穩定後繼續。';

  @override
  String get scheduledTasksPreparationWindowWaiting => '未到準備時間';

  @override
  String get scheduledTasksPreparationCooldownWaiting => '等待重試';

  @override
  String scheduledTasksPreparationRetryAt(String time) {
    return '下次可嘗試：$time';
  }

  @override
  String get scheduledTasksPreparationLimitReached => '自動準備次數已用完';

  @override
  String scheduledTasksPreparationAttemptsUsed(int count, int limit) {
    return '本次已嘗試 $count 次，自動準備上限為 $limit 次。可使用「立刻準備」繼續。';
  }

  @override
  String get scheduledTasksPreparationHourlyLimit => '自動準備已達小時上限';

  @override
  String get scheduledTasksPreparationHourlyLimitDetail =>
      '已達到每小時準備次數上限，自動準備將在額度恢復後繼續；仍可使用「立刻準備」。';

  @override
  String get scheduledTasksPreparationUnavailable => '暫時無法準備';

  @override
  String get scheduledTasksPreparationReadFailed =>
      '暫時無法讀取任務資訊，稍後會重新檢查；具體原因見執行記錄。';

  @override
  String get scheduledTasksPreparationResultRetained =>
      '暫時無法校驗上下文，已保留準備結果，稍後會重新檢查。';

  @override
  String get scheduledTasksPreparationContextChanged => '對話內容或設定已變更，原準備結果已作廢。';

  @override
  String get scheduledTasksPreparationPublishing => '待寫入對話';

  @override
  String get scheduledTasksPreparationPublishingDetail =>
      '等待目前回覆結束後，將已儲存的結果寫入對話。';

  @override
  String get scheduledTasksPreparationPrompt => '準備提示詞';

  @override
  String get scheduledTasksPreparationPromptTip =>
      '僅在提前準備本任務時附加的系統提示詞，與任務內容分開。可以自訂語氣和要求，也可以留空，不附加準備提示詞。無論如何設定，提前準備都不能使用工具或取得即時資訊。到期前修改會使已準備的結果失效，再次準備可能產生額外模型費用。';

  @override
  String get scheduledTasksPreparationPromptEmpty => '留空則不附加準備提示詞';

  @override
  String scheduledTasksPreparationPromptVariables(
    String timeVariable,
    String offsetVariable,
  ) {
    return '可用佔位符：$timeVariable 為計劃傳送的本地時間，$offsetVariable 為該時間的 UTC 偏移。準備時會自動替換。';
  }

  @override
  String get scheduledTasksPrepareNow => '立刻準備';

  @override
  String get scheduledTasksPrepareNowDetail =>
      '立刻準備下一次內容，到原定時間再傳送。不受自動準備的等待時間和次數上限限制，會呼叫模型並可能產生費用；已有準備結果時直接重用。';

  @override
  String get scheduledTasksPrepareNowReady => '本次結果已經準備好，無需再次呼叫模型。';

  @override
  String get scheduledTasksPrepareNowStarted => '正在準備下一次內容，將在計劃時間發佈。';

  @override
  String get scheduledTasksPrepareNowBusy => '正在準備其他任務，請等待完成後再試。';

  @override
  String get scheduledTasksPrepareNowChatBusy => '請等待目前回覆結束後，再嘗試準備。';

  @override
  String get scheduledTasksPrepareNowDisabled =>
      '請先啟用任務和「允許提前準備」。重新生成模式不支援提前準備。';

  @override
  String get scheduledTasksPrepareNowUnavailable => '暫時無法開始準備，請稍後再試。';

  @override
  String get scheduledTasksPrepareNowNoUpcoming =>
      '沒有可提前準備的下一次任務，請檢查任務時間和啟用狀態。';

  @override
  String get phoneControlTitle => '手機控制';

  @override
  String get phoneControlSubtitle => '透過無障礙讀取畫面並執行操作';

  @override
  String get phoneControlAccessibilityService => '無障礙服務';

  @override
  String get phoneControlOpenSettings => '前往無障礙設定';

  @override
  String get phoneControlRefresh => '重新整理狀態';

  @override
  String get phoneControlChecking => '正在檢查服務狀態…';

  @override
  String get phoneControlReady => '已啟用並連線';

  @override
  String get phoneControlDisabled => '未啟用';

  @override
  String get phoneControlDisconnected => '已啟用，但尚未連線。請在系統設定中關閉再開啟服務，然後重新整理狀態。';

  @override
  String get phoneControlStatusUnavailable => '無法讀取服務狀態，請重新整理後重試。';

  @override
  String get phoneControlSettingsUnavailable =>
      '無法開啟設定，請手動進入 Android 系統設定 → 無障礙。';

  @override
  String get phoneControlUsageTitle => '使用說明';

  @override
  String get phoneControlDisclosure =>
      '在對話中發起手機控制任務後，助手可以讀取目前畫面、點擊、輸入、滑動、導覽和開啟應用程式。畫面內容會傳送給目前對話設定的模型服務商，並儲存在對話的工具結果中。密碼欄位會隱藏，服務不會持續記錄畫面內容。你可以隨時關閉助手的此項工具，或在系統設定中停用服務。';

  @override
  String get phoneControlAssistantTitle => '還需開啟助手工具';

  @override
  String get phoneControlAssistantHint =>
      '需要同時完成兩項設定：在系統無障礙設定中啟用「Kelivo 手機控制」，並在要使用的助手 → 本地工具中開啟「手機控制」（也可從對話工具選單開啟）。每個助手單獨設定，執行任務時請保持手機解鎖。';

  @override
  String get phoneControlRestrictedTitle => '無法開啟無障礙？';

  @override
  String get phoneControlRestrictedHint =>
      '部分下載的 APK 需要先在應用程式資訊右上角選單中選擇「允許受限制的設定」。點擊開啟 Kelivo 應用程式資訊，完成後再返回無障礙設定。';

  @override
  String get phoneControlEnableAssistant => '允許此助手使用手機控制';

  @override
  String get composerDraftLabel => '草稿';

  @override
  String get composerDraftRecovered => '已還原一則尚未傳送的內容。';

  @override
  String get composerDraftRestore => '繼續編輯';

  @override
  String get composerDraftDiscard => '捨棄';

  @override
  String get composerDraftSaveFailed => '最新草稿儲存失敗，內容仍保留在目前視窗。';

  @override
  String get composerDraftRetry => '重試儲存';

  @override
  String get composerDraftConflictTitle => '這個對話已有草稿';

  @override
  String get composerDraftConflictBody => '附加會保留兩邊的文字和附件；取代會捨棄原來的草稿。內容不會自動傳送。';

  @override
  String get composerDraftAppend => '附加';

  @override
  String get composerDraftReplace => '取代草稿';

  @override
  String get composerDraftMissingFile => '有附件無法讀取，請移除或重新選擇該檔案。';

  @override
  String get composerDraftMessageMissing => '正在編輯的原訊息已不存在。請複製內容到新訊息，或取消本次編輯。';

  @override
  String get composerDraftDeleteNotice => '這些對話中未傳送的草稿也會一起刪除。';

  @override
  String get mcpOAuthSettings => 'OAuth 設定';

  @override
  String get mcpOAuthAutomatic => '自動';

  @override
  String get mcpOAuthMetadataUrl => '用戶端中繼資料文件 URL';

  @override
  String get mcpOAuthClientAuthentication => '用戶端驗證方式';

  @override
  String get mcpOAuthPublicClient => '公用用戶端';

  @override
  String get mcpOAuthRedirectUri => '本機回呼 URL（選填）';

  @override
  String get mcpOAuthFillRedirectExample => '填入範例';

  @override
  String get mcpOAuthRedirectHint =>
      '留空使用平台預設回呼。若服務僅允許 localhost 回呼，可填寫 HTTP 回環位址。連接埠 0 自動選擇可用連接埠；預先註冊的用戶端可能要求固定連接埠。';

  @override
  String get mcpOAuthClientIdRequired => '請輸入用戶端 ID，或選擇自動註冊。';

  @override
  String get mcpOAuthMetadataUrlInvalid => '請輸入包含路徑的 HTTPS 中繼資料文件 URL。';

  @override
  String get mcpOAuthSecretRequired => '此用戶端驗證方式需要 Client secret。';

  @override
  String get mcpOAuthRedirectInvalid =>
      '請使用 localhost、127.0.0.1 或 [::1] 的 HTTP 回呼位址，不要包含憑證、查詢參數或片段。';

  @override
  String get mcpOAuthDiscovering => '正在探索授權伺服器…';

  @override
  String get mcpOAuthRegistering => '正在準備授權…';

  @override
  String get mcpOAuthWaitingBrowser => '等待瀏覽器授權…';

  @override
  String get mcpOAuthExchangingToken => '正在完成登入…';

  @override
  String get markdownPlaygroundTitle => 'Markdown Playground';

  @override
  String get markdownPlaygroundSource => 'Markdown 原始碼';

  @override
  String get markdownPlaygroundPreview => '渲染預覽';

  @override
  String get markdownPlaygroundAst => 'AST 語法樹';

  @override
  String get markdownPlaygroundPlay => '逐字輸入';

  @override
  String get markdownPlaygroundPause => '暫停';

  @override
  String get markdownPlaygroundResume => '繼續';

  @override
  String get markdownPlaygroundShowAll => '顯示全文';

  @override
  String get markdownPlaygroundWidth => '預覽寬度';

  @override
  String get markdownPlaygroundTheme => '預覽主題';

  @override
  String get markdownPlaygroundPlain => '選取範圍純文字';

  @override
  String get markdownPlaygroundMarkdown => '選取範圍 Markdown';

  @override
  String get markdownPlaygroundSelectionHint => '在預覽中選取文字，檢視複製結果。';

  @override
  String get markdownPlaygroundEmpty => '輸入 Markdown 開始預覽。';

  @override
  String markdownPlaygroundProgress(int shown, int total) {
    return '已輸入 $shown / $total';
  }

  @override
  String get markdownCopyMarkdownAction => '複製為 Markdown';

  @override
  String get markdownCopyCsvAction => '複製 CSV';

  @override
  String get markdownCopyImageAction => '複製圖片';

  @override
  String get markdownCodeLabel => '程式碼';

  @override
  String get markdownDetailsLabel => '詳情';

  @override
  String markdownMoreRows(int count) {
    return '再顯示 $count 行';
  }

  @override
  String get markdownNoteLabel => '備註';

  @override
  String get markdownTipLabel => '提示';

  @override
  String get markdownImportantLabel => '重要';

  @override
  String get markdownWarningLabel => '警告';

  @override
  String get markdownCautionLabel => '注意';

  @override
  String get markdownDangerLabel => '危險';

  @override
  String get markdownCopyRichTextAction => '複製富文字';

  @override
  String get markdownCopySelectionFailed => '複製所選內容失敗。';

  @override
  String get recoveryMissingDataTitle => '偵測到既有資料';

  @override
  String get recoveryMissingDataBody =>
      '目前資料庫遺失，但裝置上仍有舊資料。Kelivo 已暫停啟動，沒有建立空資料庫，並保留現有檔案與副本。';

  @override
  String get recoveryEmptyDataTitle => '目前聊天記錄為空';

  @override
  String get recoveryEmptyDataBody =>
      '目前資料庫沒有對話，但發現了歷史副本。Kelivo 已暫停啟動，你可以還原副本，也可以明確選擇保留目前資料。應用程式不會自動覆寫資料。';

  @override
  String get recoveryKeepCurrent => '保留目前資料並繼續';

  @override
  String get recoveryKeepCurrentConfirm => '繼續使用目前的空資料庫？歷史副本仍會保留，可稍後還原。';

  @override
  String get recoverySearchingCopies => '正在尋找並驗證本機資料副本…';

  @override
  String recoveryFoundCopies(int count) {
    return '找到 $count 份通過驗證的副本。可選擇還原聊天與設定，原始檔案會保留。';
  }

  @override
  String recoveryInvalidCopy(String name) {
    return '$name：驗證未通過，原始檔案已保留。';
  }

  @override
  String get recoverySearchFailed => '部分資料位置無法讀取。現有檔案已保留，請先匯出資料副本再嘗試其他還原操作。';

  @override
  String get recoveryDiscoveredCopyBody =>
      '在原儲存目錄或其他位置發現的副本。原始檔案會保留，還原前會進行完整驗證。';

  @override
  String get recoveryStorageFailureTitle => '資料儲存需要檢查';

  @override
  String get recoveryStorageFailureBody =>
      'Kelivo 未能啟用受保護的資料儲存，已暫停啟動並保留原資料。可匯出資料副本或重試，應用程式不會因此建立空資料庫。';

  @override
  String get recoveryProtectingTitle => '正在保護聊天資料庫';

  @override
  String get recoveryProtectingData =>
      '正在複製並驗證資料庫。圖片、附件和快照留在 Documents，不會重複複製；原資料庫也會保留。';

  @override
  String get recoveryStorageReadyTitle => '聊天資料庫已轉存至 App 內部';

  @override
  String get recoveryStorageReadyBody =>
      '存放聊天、助手和設定的資料庫已轉存至 App 內部。快照、圖片和附件仍在系統「檔案」App 可存取的 Documents 中，原資料庫也已保留。若先前的聊天仍然遺失，可前往「設定 → 備份與還原 → 本機副本」查看還原副本。';

  @override
  String get recoveryRetainedData => '保留的原資料';

  @override
  String get recoveryNoValidCopies => '找到了資料副本，但沒有副本通過驗證。原始檔案均已保留，可匯出資料進一步檢查。';

  @override
  String get recoveryStorageInsufficientSpaceBody =>
      '剩餘空間不足，無法在保留原資料庫的同時建立經過驗證的內部副本。現有資料和快照均未更動，請釋放一些空間後重試。';

  @override
  String get migrationFreshStartTitle => '已重新開始';

  @override
  String get migrationFreshStartSubtitle =>
      '已建立新的空白資料庫，舊資料已保留。請重新啟動 App 後繼續使用。';

  @override
  String get migrationFreshStartFailedTitle => '重新開始未完成';

  @override
  String get migrationFreshStartFailedSubtitle =>
      '舊資料已保留。請重試重新開始，或關閉並重新開啟 App。';

  @override
  String get imageExportPreparing => '正在準備圖片…';

  @override
  String imageExportDiagrams(int completed, int total) {
    return '正在準備圖表 $completed/$total…';
  }

  @override
  String imageExportCapturing(int completed, int total) {
    return '正在擷取圖片 $completed/$total…';
  }

  @override
  String get imageExportProcessing => '正在合成圖片並準備預覽…';

  @override
  String get imageExportSaving => '正在儲存圖片…';

  @override
  String get backupEncryptionTitle => '加密備份';

  @override
  String get backupEncryptionOffHint => '未加密的備份可被直接讀取。';

  @override
  String get backupEncryptionOnHint => '備份將加密儲存，重新啟動應用程式後需重新輸入口令。';

  @override
  String get backupEncryptionPasswordHint =>
      '請妥善保存口令，遺忘後無法還原備份。口令僅在記憶體中保留至結束應用程式。';

  @override
  String get backupEncryptionPassword => '口令';

  @override
  String get backupEncryptionConfirmPassword => '確認口令';

  @override
  String get backupEncryptionMismatch => '兩次輸入的口令不一致。';

  @override
  String get backupEncryptionShowPassword => '顯示口令';

  @override
  String get backupEncryptionHidePassword => '隱藏口令';

  @override
  String get backupEncryptionUnlockTitle => '加密備份';

  @override
  String get backupEncryptionUnlockHint => '請輸入建立這份備份時使用的口令。';

  @override
  String get backupEncryptionUnlock => '解鎖';

  @override
  String get backupEncryptionFailed => '口令錯誤或備份已損壞，請重試或取消。';

  @override
  String get backupEncryptionInvalid => '加密備份不完整或格式無效。';

  @override
  String get backupEncryptionUnsupported => '此加密備份需要更新版本的 Kelivo。';

  @override
  String get backupProgressEncrypting => '正在加密備份';

  @override
  String get backupProgressDecrypting => '正在解密備份';

  @override
  String get mcpPageStatusFailed => '連線失敗';

  @override
  String mcpPageCardToolsShort(int enabled, int total) {
    return '工具 $enabled/$total';
  }

  @override
  String mcpPageSelectServer(String name) {
    return '選擇 $name';
  }

  @override
  String get mcpIconTitle => '伺服器圖示';

  @override
  String get mcpIconInvalid => '無法使用此圖片，請選擇不超過 10 MB 的有效圖片。';

  @override
  String get mcpSelectServers => '選擇伺服器';

  @override
  String get mcpMoveToGroup => '移到群組';

  @override
  String get mcpRenameGroup => '重新命名群組';

  @override
  String get mcpDeleteGroupConfirm => '群組內的伺服器將移至「其他」，不會刪除伺服器。';

  @override
  String get mcpGroupNameInvalid => '請輸入非空且不重複的群組名稱。';

  @override
  String get mcpEnableSelected => '啟用';

  @override
  String get mcpDisableSelected => '停用';

  @override
  String mcpDeleteSelectedConfirm(int count) {
    return '刪除選取的 $count 個伺服器？';
  }

  @override
  String get browserTitle => '瀏覽器';

  @override
  String get browserSearchHint => '搜尋或輸入網址';

  @override
  String get browserStartTitle => '下一站，去哪裡？';

  @override
  String get browserStartSubtitle => '自由瀏覽，也可以讓 Agent 幫你探索。';

  @override
  String get browserNewTab => '新增分頁';

  @override
  String get browserTabs => '分頁';

  @override
  String get browserCloseTab => '關閉分頁';

  @override
  String get browserClose => '關閉瀏覽器';

  @override
  String get browserBack => '上一頁';

  @override
  String get browserForward => '下一頁';

  @override
  String get browserReload => '重新載入';

  @override
  String get browserStop => '停止載入';

  @override
  String get browserMore => '更多';

  @override
  String get browserBookmarks => '書籤';

  @override
  String get browserHistory => '歷史記錄';

  @override
  String get browserSettings => '瀏覽器設定';

  @override
  String get browserAddBookmark => '新增書籤';

  @override
  String get browserRemoveBookmark => '移除書籤';

  @override
  String get browserNoBookmarks => '收藏的網站會顯示在這裡。';

  @override
  String get browserNoHistory => '瀏覽記錄會顯示在這裡。';

  @override
  String get browserSearchLibrary => '搜尋已儲存的頁面';

  @override
  String get browserClearHistory => '清除歷史記錄';

  @override
  String get browserClearHistoryConfirm => '刪除全部瀏覽記錄？書籤會保留。';

  @override
  String get browserToday => '今天';

  @override
  String get browserYesterday => '昨天';

  @override
  String get browserDelete => '刪除';

  @override
  String get browserCancel => '取消';

  @override
  String get browserDone => '完成';

  @override
  String get browserFind => '在頁面中尋找';

  @override
  String get browserFindPreviousMatch => '上一個符合項目';

  @override
  String get browserFindNextMatch => '下一個符合項目';

  @override
  String get browserFindHint => '尋找文字';

  @override
  String get browserSearchEngine => '搜尋引擎';

  @override
  String get browserDesktopMode => '電腦版網站';

  @override
  String get browserDesktopModeDescription => '使用電腦版使用者代理重新載入頁面。';

  @override
  String get browserRestoreTabs => '還原分頁';

  @override
  String get browserRestoreTabsDescription => '啟動 Kelivo 時還原上次的分頁。';

  @override
  String get browserSaveHistory => '儲存瀏覽記錄';

  @override
  String get browserSaveHistoryDescription => '在本機記錄造訪過的頁面。';

  @override
  String get browserClearData => '清除網站資料';

  @override
  String get browserClearDataConfirm =>
      '清除 Cookie、網站儲存空間和快取，並關閉全部分頁？網站登入狀態也會清除。';

  @override
  String get browserDataCleared => '已清除網站資料';

  @override
  String get browserAgentControl => 'Agent 控制';

  @override
  String get browserAgentWorking => 'AI 正在操作';

  @override
  String get browserTakeOver => '接管';

  @override
  String get browserAgentPaused => 'AI 操作已暫停';

  @override
  String get browserAllowAgent => '允許繼續';

  @override
  String get browserAgentDescription =>
      '在聊天中傳送任務後，AI 才會操作瀏覽器。允許繼續只解除暫停，不會自動傳送訊息或啟動任務。';

  @override
  String get browserOpenExternal => '在預設瀏覽器開啟';

  @override
  String get browserCopyLink => '複製連結';

  @override
  String get browserLinkCopied => '已複製連結';

  @override
  String get browserUnsupported => '此平台暫不支援內建瀏覽器。';

  @override
  String get browserLoadFailed => '無法載入此頁面';

  @override
  String get browserRetry => '重試';

  @override
  String get browserFavorites => '個人收藏';

  @override
  String get browserEditBookmark => '編輯書籤';

  @override
  String get browserBookmarkTitle => '標題';

  @override
  String get browserBookmarkUrl => '網址';

  @override
  String get browserSave => '儲存';

  @override
  String get browserDownloads => '下載';

  @override
  String get browserNoDownloads => '下載的檔案會顯示在這裡。';

  @override
  String get browserDownloadCancel => '取消下載';

  @override
  String get browserOpenDownload => '開啟檔案';

  @override
  String get browserDownloadFailed => '下載失敗';

  @override
  String get browserAgentEnableHint => '在聊天工具中啟用瀏覽器工具，再在這裡允許控制。';

  @override
  String get browserSessionRequired => '從一個對話中開啟瀏覽器，即可允許 Agent 控制。';

  @override
  String get browserDownloadCancelled => '已取消';

  @override
  String get browserAgentEnabled => '允許助手使用瀏覽器';

  @override
  String get browserAgentEnabledDescription => '開啟後，助手可以瀏覽並操作這個瀏覽器中的頁面。';

  @override
  String get browserToolTitle => '瀏覽器控制';

  @override
  String get browserToolSubtitle => '瀏覽並操作瀏覽器中已登入的網頁。請先在瀏覽器設定中開啟 Agent 控制。';

  @override
  String get browserOpen => '開啟瀏覽器';

  @override
  String get browserInvalidUrl => '請輸入有效的 HTTP 或 HTTPS 網址。';

  @override
  String get browserClearDataUnavailable => 'Windows 瀏覽器引擎暫不支援清除全部網站資料。';

  @override
  String get browserSurfaceStyle => '表面樣式';

  @override
  String get browserSurfaceLiquid => '液態玻璃';

  @override
  String get browserSurfaceFrosted => '磨砂';

  @override
  String get browserSurfaceSolid => '純色';

  @override
  String get browserPageOptions => '頁面選項';

  @override
  String get browserAskAi => '讓 AI 處理此頁';

  @override
  String get browserAskAiHint => '返回聊天，補充需求後傳送。';

  @override
  String get browserAskAiCurrentPage => '瀏覽器目前頁面';

  @override
  String get browserAskAiUnavailable => '目前對話無法使用，請先從聊天中開啟瀏覽器。';

  @override
  String get browserAskAiEditing => '請先完成或取消正在編輯的訊息，再加入網頁任務。';

  @override
  String get browserAskAiAssistantDisabled => '請先在此助理的工具中開啟「瀏覽器控制」。';

  @override
  String get browserAskAiBrowserDisabled => '請先在瀏覽器設定中允許助理使用瀏覽器。';

  @override
  String browserAskAiDraft(String page) {
    return '請使用瀏覽器處理這個頁面：\n$page\n\n我的需求：';
  }

  @override
  String get browserOpenFullPage => '完整頁面開啟';

  @override
  String get browserClosePanel => '關閉瀏覽器面板';

  @override
  String get browserSearchTabs => '搜尋分頁';

  @override
  String browserTabsCount(int count) {
    return '$count 個分頁';
  }

  @override
  String get browserOpenInSidebar => '在側欄開啟';

  @override
  String get browserUserAgent => '使用者代理（UA）';

  @override
  String get browserUserAgentMobile => '行動版';

  @override
  String get browserUserAgentDesktop => '桌面版';

  @override
  String get browserUserAgentCustom => '自訂';

  @override
  String get browserUserAgentHint => '輸入自訂 User-Agent';

  @override
  String get browserUserAgentInvalid =>
      'UA 僅支援可列印 ASCII 字元（英文字母、數字和英文符號），最多 2048 個字元。';

  @override
  String get browserUserAgentDescription => '變更後將重新載入目前網頁。';

  @override
  String browserStepsShowEarlier(int count) {
    return '更早的 $count 步';
  }

  @override
  String get browserOpenThisPage => '在瀏覽器中開啟';

  @override
  String get browserGroupToggleSemantics => '展開或收合瀏覽步驟';

  @override
  String get browserStepGroupTitle => '瀏覽網頁';

  @override
  String browserStepCount(int count) {
    return '$count 步';
  }

  @override
  String browserStepCurrent(int count) {
    return '第 $count 步';
  }

  @override
  String browserActionFailedCount(int count) {
    return '· $count 步失敗';
  }

  @override
  String browserActionFailed(String action) {
    return '$action失敗';
  }

  @override
  String get browserCardOpen => '打開';

  @override
  String get browserCardEnable => '去開啟';

  @override
  String browserCardRunning(String action) {
    return '正在$action…';
  }

  @override
  String get browserCardLive => '即時';

  @override
  String get browserCardOpenFailed => '無法開啟頁面';

  @override
  String get browserCardBlankPage => '空白頁';

  @override
  String browserCardTabCount(int count) {
    return '$count 個分頁';
  }

  @override
  String get browserActionOpen => '開啟網頁';

  @override
  String get browserActionNewTab => '新增分頁';

  @override
  String get browserActionRender => '渲染頁面';

  @override
  String get browserActionExtract => '擷取正文';

  @override
  String get browserActionSnapshot => '讀取頁面結構';

  @override
  String get browserActionClick => '點擊';

  @override
  String get browserActionType => '輸入文字';

  @override
  String get browserActionPress => '按鍵';

  @override
  String get browserActionScroll => '捲動頁面';

  @override
  String get browserActionWait => '等待頁面';

  @override
  String get browserActionBack => '上一頁';

  @override
  String get browserActionForward => '下一頁';

  @override
  String get browserActionReload => '重新整理';

  @override
  String get browserActionEvaluate => '執行指令碼';

  @override
  String get browserActionSwitchTab => '切換分頁';

  @override
  String get browserActionCloseTab => '關閉分頁';

  @override
  String get browserActionListTabs => '檢視分頁';

  @override
  String get browserActionUnknown => '瀏覽器操作';

  @override
  String browserMetaChars(String count) {
    return '$count 字';
  }

  @override
  String browserMetaElements(int count) {
    return '$count 個元素';
  }

  @override
  String get browserErrAgentDisabled => '瀏覽器控制未開啟';

  @override
  String get browserErrStaleRef => '元素已失效，需重新讀取頁面';

  @override
  String get browserErrNotVisible => '元素不可見或被遮擋';

  @override
  String get browserErrNotFound => '找不到元素';

  @override
  String get browserErrTimeout => '頁面載入逾時';

  @override
  String get browserErrHumanControl => '你正在接管瀏覽器';

  @override
  String get browserErrTabClosed => '分頁已關閉';

  @override
  String get browserErrGeneric => '操作失敗';

  @override
  String get browserDirectionUp => '上';

  @override
  String get browserDirectionDown => '下';

  @override
  String get browserDirectionLeft => '左';

  @override
  String get browserDirectionRight => '右';

  @override
  String browserMetaTabs(int count) {
    return '$count 個';
  }

  @override
  String get browserTabsCurrentConversation => '目前對話';

  @override
  String get browserTabsAll => '所有分頁';

  @override
  String get browserTabsUnassigned => '個人分頁';

  @override
  String get browserTabsUnknownConversation => '其他對話';

  @override
  String get browserTabsEmptyConversation => '這裡還沒有分頁。開啟網頁，或從「所有分頁」選擇現有頁面。';

  @override
  String get browserTabsNoResults => '沒有符合的分頁';

  @override
  String get browserMoveToConversation => '移到目前對話';

  @override
  String get browserReopenInConversation => '在目前對話重新開啟';

  @override
  String get browserTabBusy => '助手仍在操作此頁面，請等待任務完成或停止任務後再移動。';

  @override
  String get browserLiveViewLimit => '瀏覽器資源正在使用中，請等待任務結束後重試，或關閉不需要的頁面。';

  @override
  String get browserAskAiInOwnerConversation => '讓所屬對話的 AI 處理';

  @override
  String get displaySettingsPageShowBrowserPageCardsTitle => '顯示網頁卡片';

  @override
  String get browserObserverHint => 'AI 正在操作此頁面，點選「接管」後可以操作網頁。';

  @override
  String get genuiSurfaceTitle => '互動介面';

  @override
  String get genuiStatusStreaming => '生成中';

  @override
  String get genuiStatusInterrupted => '已中斷';

  @override
  String get genuiStatusUnsaved => '尚未儲存';

  @override
  String get genuiStatusUnsavedRetry => '點擊重試儲存';

  @override
  String get genuiReadOnlyUntilComplete => '生成完成後可操作';

  @override
  String get genuiReadOnlySnapshot => '唯讀快照';

  @override
  String genuiPendingNode(String id) {
    return '等待 $id';
  }

  @override
  String get genuiViewSource => '檢視原始碼';

  @override
  String get genuiCopySource => '複製原始碼';

  @override
  String get genuiExpand => '展開';

  @override
  String get genuiExpandedStub => '正在展開檢視中操作';

  @override
  String get genuiMore => '更多';

  @override
  String get genuiReset => '重設為預設值';

  @override
  String get genuiRepair => '修復介面';

  @override
  String get genuiInvalidTitle => '這段介面無法顯示';

  @override
  String genuiNodesFailed(int count) {
    return '$count 個節點無法顯示';
  }

  @override
  String genuiErrorLine(int line) {
    return '第 $line 行';
  }

  @override
  String get genuiValueUnavailable => '無值';

  @override
  String get genuiFormulaInvalid => '這條公式無法顯示';

  @override
  String get genuiNodeUnavailable => '此元件無法顯示';

  @override
  String get genuiErrorHeader => '介面首行格式無效';

  @override
  String get genuiErrorVersion => '不支援此介面語言版本';

  @override
  String get genuiErrorCatalog => '不支援此元件目錄';

  @override
  String get genuiErrorRoot => '根元件缺失或無效';

  @override
  String get genuiErrorSyntax => '宣告格式不正確';

  @override
  String get genuiErrorDuplicateSymbol => '同一名稱被重複定義';

  @override
  String get genuiErrorDuplicateProperty => '同一屬性被重複定義';

  @override
  String get genuiErrorReservedName => '此名稱是保留名稱';

  @override
  String genuiErrorUnknownComponent(String detail) {
    return '未知元件 $detail';
  }

  @override
  String genuiErrorUnknownProperty(String detail) {
    return '未知屬性 $detail';
  }

  @override
  String genuiErrorMissingProperty(String detail) {
    return '缺少必要屬性 $detail';
  }

  @override
  String get genuiErrorBinding => '輸入綁定不是有效的可寫狀態';

  @override
  String get genuiErrorReference => '元件參照無效';

  @override
  String get genuiErrorMissingReference => '被參照的內容尚未定義';

  @override
  String get genuiErrorDependency => '依賴的內容無法顯示';

  @override
  String get genuiErrorCycle => '不支援循環參照';

  @override
  String get genuiErrorDuplicateParent => '同一元件不能出現在兩個位置';

  @override
  String get genuiErrorUnreachableNode => '此元件未包含在根元件中';

  @override
  String get genuiErrorType => '值的類型不符';

  @override
  String get genuiErrorValue => '值不在支援的選項或範圍內';

  @override
  String get genuiErrorSourceBudget => '介面原始碼超過大小上限';

  @override
  String get genuiErrorDeclarationBudget => '單條宣告超過大小上限';

  @override
  String get genuiErrorDeclarationCount => '宣告數量超過上限';

  @override
  String get genuiErrorComponentCount => '元件數量超過上限';

  @override
  String get genuiErrorInputCount => '輸入數量超過上限';

  @override
  String get genuiErrorComponentDepth => '元件巢狀層級過深';

  @override
  String get genuiErrorExpressionDepth => '計算巢狀層級過深';

  @override
  String get genuiErrorFunction => '計算函數不受支援';

  @override
  String get genuiErrorAction => '此操作不受支援';

  @override
  String get genuiErrorNestedSample => '不支援巢狀取樣';

  @override
  String get genuiErrorSample => '取樣區間或數量無效';

  @override
  String get genuiErrorDataBudget => '資料超過支援的大小';

  @override
  String get genuiErrorRowKey => '每列需要唯一且非空的識別值';

  @override
  String get genuiErrorDomain => '此值不在函數定義域內';

  @override
  String get genuiErrorDivisionByZero => '不能除以零';

  @override
  String get genuiErrorNonFinite => '計算結果不是有限數值';

  @override
  String get genuiErrorOperationsBudget => '計算操作量超過上限';

  @override
  String genuiMetricTrend(String value) {
    return '變化 $value';
  }

  @override
  String genuiFormErrorsLeft(int count) {
    return '還有 $count 項需要修改';
  }

  @override
  String get genuiFieldRequired => '必填';

  @override
  String genuiNumberRange(String min, String max) {
    return '範圍 $min–$max';
  }

  @override
  String genuiNumberMinimum(String min) {
    return '最小值 $min';
  }

  @override
  String genuiNumberMaximum(String max) {
    return '最大值 $max';
  }

  @override
  String genuiFieldTooShort(int min) {
    return '至少 $min 個字元';
  }

  @override
  String genuiFieldTooLong(int max) {
    return '最多 $max 個字元';
  }

  @override
  String get genuiInvalidNumber => '請輸入完整的有限數值';

  @override
  String get genuiChooseOption => '請選擇一項';

  @override
  String get genuiFinishComposing => '請先完成輸入法組字';

  @override
  String genuiActionDisabledDep(String id) {
    return '已停用：依賴的 $id 無法顯示';
  }

  @override
  String get genuiActionUnavailable => '此檢視暫不支援這項操作';

  @override
  String get genuiActionDisabled => '此介面已停用該操作';

  @override
  String get genuiFormUnavailable => '此表單包含無法顯示的內容';

  @override
  String genuiDecrease(String label) {
    return '減少 $label';
  }

  @override
  String genuiIncrease(String label) {
    return '增加 $label';
  }

  @override
  String genuiCharacterCount(int used, int max) {
    return '$used / $max 個字元';
  }

  @override
  String get genuiBlockLimit => '每則訊息最多顯示 3 個介面，其餘以原始碼顯示';

  @override
  String get genuiChartLine => '折線圖';

  @override
  String get genuiChartArea => '面積圖';

  @override
  String get genuiChartBar => '長條圖';

  @override
  String get genuiChartScatter => '散佈圖';

  @override
  String get genuiChartPie => '圓餅圖';

  @override
  String get genuiChartDonut => '環圈圖';

  @override
  String get genuiChartEmpty => '所選區間沒有資料';

  @override
  String get genuiChartAllHidden => '所有系列均已隱藏，可透過圖例顯示。';

  @override
  String genuiChartSummary(String kind, int series, int points, int missing) {
    return '$kind，$series 個系列，$points 列資料，$missing 個值缺失（未連線，未填零）。';
  }

  @override
  String genuiChartPieSummary(String kind, int count, String total) {
    return '$kind，$count 項，合計 $total。';
  }

  @override
  String get genuiChartDomainGap => '未定義';

  @override
  String genuiChartDomainSummary(int count) {
    return '$count 個取樣點無定義；陰影區域不連線。';
  }

  @override
  String genuiChartShowSeries(String name) {
    return '顯示 $name';
  }

  @override
  String genuiChartHideSeries(String name) {
    return '隱藏 $name';
  }

  @override
  String get genuiChartKeyboardHint => '左右方向鍵選擇資料列，上下方向鍵選擇系列，Esc 清除選擇。';

  @override
  String get genuiChartTotal => '合計';

  @override
  String get genuiChartFieldsError => '請選擇一個 X 欄位和一到四個不同的 Y 欄位。';

  @override
  String get genuiChartRecordsError => '圖表資料必須是記錄陣列。';

  @override
  String get genuiChartXError => 'X 值須全為數值或全為文字；散佈圖必須使用數值。';

  @override
  String get genuiChartYError => 'Y 欄位須存在，且只能包含數值或空值。';

  @override
  String get genuiChartPieError => '圓餅圖數值必須非負，且總和須為大於零的有限數。';

  @override
  String genuiChartMissingValues(int count) {
    return '$count 個值缺失，未填零。';
  }

  @override
  String get genuiChartNoVisibleValues => '所選系列沒有可繪製的數值。';

  @override
  String genuiChartUnit(String unit) {
    return '單位：$unit';
  }

  @override
  String get genuiSomeValuesUnavailable => '部分值無法計算';

  @override
  String get genuiViewChart => '圖表';

  @override
  String get genuiViewData => '資料';

  @override
  String get genuiTableFilterHint => '篩選可見文字';

  @override
  String genuiTableRows(int count) {
    return '$count 列';
  }

  @override
  String genuiTablePageInfo(int from, int to, int total) {
    return '第 $from–$to 列，共 $total 列';
  }

  @override
  String genuiTablePerPage(int n) {
    return '$n 列/頁';
  }

  @override
  String get genuiTableEmpty => '沒有符合的列';

  @override
  String get genuiSortAsc => '升冪';

  @override
  String get genuiSortDesc => '降冪';

  @override
  String get genuiSortNone => '未排序';

  @override
  String get genuiValueTrue => '是';

  @override
  String get genuiValueFalse => '否';

  @override
  String get genuiTablePreviousPage => '上一頁';

  @override
  String get genuiTableNextPage => '下一頁';

  @override
  String get genuiTableCellsError => '表格資料必須是記錄陣列，儲存格只能是有限純量或空值。';

  @override
  String get genuiTableColumnsError => '請選擇 1–8 個不同的欄位，並提供表頭；小數位數可為 0–10。';

  @override
  String get genuiTableRowKeyError => '每列都需要一個非空值的純量識別碼。';

  @override
  String get genuiViewStateFailed => '儲存狀態過大，無法變更檢視。請縮短輸入或重設介面後重試。';

  @override
  String get genuiAttachState => '附帶目前介面狀態';

  @override
  String get genuiChipExactText => '將隨訊息傳送的準確文字（已凍結）';

  @override
  String get genuiChipStale => '來源已失效 · 請移除或重新附帶';

  @override
  String get genuiChipRemove => '移除附帶的介面';

  @override
  String get genuiReplaceTitle => '取代已附帶的介面？';

  @override
  String get genuiReplaceBody => '一份草稿只能附帶一個介面狀態。';

  @override
  String get genuiReplaceCurrent => '目前';

  @override
  String get genuiReplaceNew => '取代為';

  @override
  String get genuiReplaceConfirm => '取代';

  @override
  String get genuiMergeTitle => '合併到目前草稿？';

  @override
  String get genuiMergeConfirm => '合併';

  @override
  String get genuiContextEmpty => '沒有附帶參數或結果欄位。';

  @override
  String get genuiContextOmitted => '[部分欄位或資料列已省略。]';

  @override
  String get genuiChipOmitted => '先前附帶的介面來源已失效，此則訊息未附帶其狀態。';

  @override
  String get genuiDraftChanged => '草稿已變更，請重新附帶。';

  @override
  String get genuiRepairDraft => '請根據以下診斷和原始碼片段修復這段介面。';

  @override
  String get genuiCopySourceMarkdown => '複製原始碼 / Markdown';

  @override
  String get genuiTextFailed => '無法讀取介面狀態，請重試。';

  @override
  String get genuiCopyLimit => '文字超過 64 KiB 複製上限，請選取較小的片段。';

  @override
  String get genuiExportSnapshot => '匯出唯讀快照';

  @override
  String get genuiExpandedSharedState => '與訊息內共用相同狀態';

  @override
  String get genuiExportTooLarge => '圖片超過 1600 萬像素，請減少所選訊息或匯出較小的介面。';

  @override
  String get genuiWebTitle => '網頁預覽';

  @override
  String get genuiWebOpen => '開啟';

  @override
  String get genuiWebNotReady => '生成完成後才可開啟';

  @override
  String get genuiWebInvalidMeta => '首行中繼資訊無效，未載入';

  @override
  String get genuiWebSandboxNote => '沙盒預覽 · 關閉後不保留';

  @override
  String get genuiWebUnsupported => '此平台暫不支援內嵌網頁預覽，可匯出後在瀏覽器中開啟';

  @override
  String get genuiWebExportHtml => '匯出 HTML';

  @override
  String get genuiWebInfo => '預覽說明';

  @override
  String get genuiWebCspNote => 'CSP: default-src \'none\' · 限制網路存取 · 獨立頁面狀態';

  @override
  String get genuiWebFailed => '預覽初始化或載入失敗。可檢視或複製原始碼。';

  @override
  String get genuiWebEmpty => '中繼資訊後沒有 HTML 內容';

  @override
  String get genuiWebBlockLimit => '每則訊息最多顯示 3 個網頁預覽，其餘以原始碼顯示';

  @override
  String get genuiWebCloseFailed => '無法確認上一個預覽已關閉。請重新啟動應用程式後再開啟。';

  @override
  String get displaySettingsShowGenUiHeader => '顯示互動介面標題列';

  @override
  String get displaySettingsShowGenUiHeaderSubtitle =>
      '關閉後更沉浸；原始碼與操作仍可從介面底部的更多選單存取。';

  @override
  String get genuiClearFilter => '清除篩選';

  @override
  String get genuiClearSelection => '清除選取';

  @override
  String get chatInputBarQueuedPausedReason => '壓縮未完成，不會自動傳送';

  @override
  String get contextChanged => '歷史已發生變化，請重新開啟此操作並確認範圍。';

  @override
  String get contextOperationSuperseded => '已併入後續摘要';

  @override
  String get compressIncludeAttachments => '附件文字與工具結果';

  @override
  String contextEditCharacters(int count) {
    return '$count 字';
  }

  @override
  String get compressOverSnack => '摘要過長，套用後會超出上下文上限，未套用';

  @override
  String get contextSummaryHint =>
      '這是後續請求實際使用的摘要，儲存不會改寫既有回覆。附件僅使用已有文字，不會額外辨識圖片。';

  @override
  String get compressAdvanced => '進階選項';

  @override
  String get compressTaskWaiting => '等待目前回覆完成';

  @override
  String get contextBudgetExceeded => '預計上下文超過目前模型上限，請縮短摘要、重新壓縮或選擇上下文更大的模型。';

  @override
  String get contextManualSupplement => '將手動編輯的摘要作為補充';

  @override
  String get contextDetailEdited => '已人工編輯';

  @override
  String get contextSourceLabel => '摘要來源';

  @override
  String get contextImpactSourceTitle => '修改已壓縮的原文？';

  @override
  String get chatInputBarQueuedCompressionFailed => '壓縮失敗，不會自動傳送';

  @override
  String contextTokenInfo(int before, int after) {
    return '摘要輸入約 $before tokens → 摘要約 $after tokens';
  }

  @override
  String get worldBookTransferFailed => '儲存條目失敗，請重試。';

  @override
  String contextDetailKeptCount(int count) {
    return '最近 $count 則使用者訊息及其回覆、工具過程';
  }

  @override
  String get toolPermissionRequestApproval => '請求批准';

  @override
  String get compressNothingNew => '自上次壓縮後沒有新的可壓縮內容';

  @override
  String get browserActionScreenshot => '擷取畫面';

  @override
  String get displaySettingsPageIosNativeSelectionMenuSubtitle =>
      '用於輸入框和訊息選取範圍；如遇卡頓可關閉，恢復原選單。';

  @override
  String contextUndoneSnack(String from, String to) {
    return '已撤銷 · $from → $to';
  }

  @override
  String get toolApprovalByFullAccess => '已自動執行';

  @override
  String get displaySettingsPageAutoScrollSubtitle =>
      '開啟後，串流輸出時位於底部會自動跟隨。向上捲動後保持閱讀位置，主動回到底部後才繼續跟隨；關閉後不隨新內容自動捲動。';

  @override
  String get toolApprovalRealTarget => '實際目標';

  @override
  String get compressTaskRetry => '重試';

  @override
  String get wsDeniedPathOutside => '目標不在授權區域內，已拒絕。';

  @override
  String contextImpactSaveConfirm(int count) {
    return '儲存並撤銷 $count 個節點';
  }

  @override
  String get contextRestore => '恢復';

  @override
  String compressUsageOriginal(String value) {
    return '原 $value';
  }

  @override
  String toolApprovalPendingKind(String kind) {
    return '等待審批 · $kind';
  }

  @override
  String get contextTaskApplying => '正在套用摘要';

  @override
  String get storageSpaceImagesHint => '刪除會影響聊天圖片和工具結果。正在使用的頭像與背景會受到保護。';

  @override
  String get displaySettingsPageIosNativeSelectionMenuTitle => 'iOS 26+ 原生選取選單';

  @override
  String get worldBookMoveEntries => '移動到…';

  @override
  String get compressReread => '重新讀取已壓縮的原始訊息';

  @override
  String get chatInputBarQueuedPausedHold => '待傳內容維持暫停，請取消排隊後編輯或傳送';

  @override
  String get contextSummaryTitle => '壓縮摘要';

  @override
  String get contextKeepInvalid => '請輸入正整數的使用者訊息數量。';

  @override
  String get compressTaskAbandon => '放棄';

  @override
  String get browserAgentTimedOut => '操作逾時，AI 已暫停';

  @override
  String get compressCancelledSnack => '已取消壓縮，目前上下文未改變';

  @override
  String get contextImpactClearTitle => '撤銷較早的清除？';

  @override
  String get compressTaskWaitingApproval => '等待工具審批完成';

  @override
  String get contextTaskFailed => '壓縮失敗';

  @override
  String get wsDeniedSkillsReadonly => '技能目錄唯讀。';

  @override
  String get compressTaskMerging => '正在合併摘要';

  @override
  String get toolPermissionFullAccessDesc =>
      '允許此對話直接存取本機檔案、執行命令及使用已啟用的聯網工具，不再逐次詢問。';

  @override
  String get compressStaleSnack => '聊天內容已變更，壓縮結果未套用';

  @override
  String get worldBookCopyEntries => '複製到…';

  @override
  String get contextEditEmpty => '摘要不能為空。如需捨棄全部舊歷史，請使用「清空上下文」。';

  @override
  String get toolApprovalDenyWithReason => '拒絕並說明原因…';

  @override
  String get toolApprovalRequestedPath => '請求路徑';

  @override
  String get toolApprovalScopeOnce => '僅授權本次呼叫';

  @override
  String get storageSpaceImageTypeLabel => '類型';

  @override
  String get contextImpactUndoTitle => '撤銷較早的壓縮？';

  @override
  String get contextOriginalMessages => '檢視原始訊息';

  @override
  String storageSpaceDeleteImagesConfirmMessage(int count) {
    return '刪除 $count 張圖片？相關聊天圖片、工具截圖及其對話副本將無法再檢視或使用。正在使用的頭像與背景會保留。';
  }

  @override
  String get chatInputBarQueuedAfterCompress => '壓縮完成後傳送';

  @override
  String get toolPermissionFullAccessDescMobile =>
      '允許此對話在沙盒和已授權資料夾內自動執行工具，不再逐次詢問。';

  @override
  String get compressTaskAdjustRetry => '調整選項後重試';

  @override
  String get contextDetailLegacy => '由舊版清除位置轉換';

  @override
  String get contextDetailCurrent => '目前上下文';

  @override
  String get toolPermissionUndo => '復原';

  @override
  String get contextDetailViewOriginals => '檢視被壓縮的原文';

  @override
  String get contextTaskCompleted => '壓縮已完成';

  @override
  String get chatInputBarQueuedPaused => '已暫停';

  @override
  String get contextCompressMarker => '上下文已壓縮';

  @override
  String contextDetailParts(int count) {
    return '自動分 $count 段';
  }

  @override
  String get contextEditPending => '已儲存，目前回覆結束後生效';

  @override
  String get contextTaskRetry => '重試壓縮';

  @override
  String get contextUndoCompressTooltip => '撤銷此次壓縮';

  @override
  String get contextDividerCompressed => '壓縮上下文';

  @override
  String compressSuccessSnack(String from, String to) {
    return '上下文已壓縮 · $from → $to';
  }

  @override
  String get contextEffectiveHistory => '目前摘要及後續訊息';

  @override
  String get compressRereadAll => '本段全部原文';

  @override
  String get contextDone => '完成';

  @override
  String get contextMore => '更多';

  @override
  String compressFailedSnack(String reason) {
    return '壓縮失敗：$reason';
  }

  @override
  String get branchInheritNote => '只繼承此處之前有效的上下文節點';

  @override
  String get contextTaskInterrupted => '壓縮已中斷，輸入內容已保留';

  @override
  String get storageSpaceImageTypeAll => '全部';

  @override
  String contextRangeInfo(int count, int keep) {
    return '替代 $count 則訊息；原樣保留最近 $keep 則使用者訊息及後續回覆。';
  }

  @override
  String contextInputModeInfo(String mode, String source) {
    return '摘要輸入：$mode · $source';
  }

  @override
  String get contextDetailKept => '原樣保留';

  @override
  String worldBookEntriesCopied(int count) {
    return '已複製 $count 個條目';
  }

  @override
  String get toolPermissionSaveFailed => '儲存失敗，權限未變更。';

  @override
  String get compressDiscardedSnack => '已清空上下文，進行中的壓縮已捨棄';

  @override
  String get browserActionSelect => '選擇選項';

  @override
  String get toolPermissionTitle => '權限';

  @override
  String get contextDetailNext => '下次請求';

  @override
  String get contextTaskCancel => '取消壓縮';

  @override
  String get toolPermissionFullAccess => '完全存取';

  @override
  String get chatInputBarQueuedCompressionCancelled => '壓縮已取消，不會自動傳送';

  @override
  String get toolPermissionResetSnack => '已更換工作區 · 此對話權限已恢復為請求批准';

  @override
  String get contextImpactUndoOne => '撤銷';

  @override
  String get contextDetailContinueNewChat => '在新聊天繼續';

  @override
  String get contextTaskPaused => '傳送已暫停，可取消排隊恢復編輯';

  @override
  String get contextTaskReview => '請檢查摘要後再套用';

  @override
  String compressApproxTokens(String value) {
    return '約 $value tokens';
  }

  @override
  String get storageSpaceImageInUseHint => '請先在對應設定中更換或移除頭像、背景或圖示，再刪除。';

  @override
  String get compressRereadLastLayer => '展開最近一層壓縮';

  @override
  String get contextRestoreOperation => '恢復操作';

  @override
  String get contextOriginalHistory => '重新讀取本段全部原文';

  @override
  String get contextImpactEditTitle => '儲存較早的摘要？';

  @override
  String get contextOpenNewChat => '開啟新聊天';

  @override
  String get wsPathChanged => '審批期間目標已變化。';

  @override
  String get contextEditUnknownPreview => '用量暫不可用，儲存前會重新檢查。';

  @override
  String get contextTaskWait => '等待目前回覆和工具執行結束';

  @override
  String compressTaskElapsed(int i, int n, int seconds) {
    return '第 $i/$n 段 · 已用 $seconds 秒';
  }

  @override
  String get wsContextChanged => '對話上下文已變化，請求失效。';

  @override
  String contextChangeImpact(int count) {
    return '此次修改還會撤銷 $count 個受影響的上下文操作，原始訊息保留。是否繼續？';
  }

  @override
  String get contextImpactSave => '儲存';

  @override
  String contextTaskProgress(int done, int total) {
    return '正在壓縮 $done/$total 段';
  }

  @override
  String get contextSummaryNotSmaller => '摘要沒有比輸入更短，請檢查後再套用。';

  @override
  String get storageSpaceImageTypeTool => '工具圖片';

  @override
  String get contextPreviousHistory => '重新讀取最近一層壓縮原文';

  @override
  String get contextDetailRead => '實際讀取';

  @override
  String get contextViewGenerated => '檢視已產生摘要';

  @override
  String get contextImpactDeleteDescription =>
      '刪除原文時，一併撤銷相關摘要及相依後繼，避免繼續傳送殘留內容。其他訊息與獨立節點保持不變。';

  @override
  String get storageSpaceImageTypeAvatar => '頭像與背景';

  @override
  String get contextDetailAfterUndo => '撤銷後';

  @override
  String get contextOperationUndo => '撤銷此次上下文操作';

  @override
  String contextHistoryWindowNote(int count) {
    return '原樣保留的歷史仍受目前聊天「最多傳送 $count 則訊息」的限制。';
  }

  @override
  String get contextOverLimitWarning => '撤銷後可能超出模型上下文上限，建議重新壓縮。仍可撤銷，傳送前會再次檢查。';

  @override
  String get storageSpaceImageTypeChat => '聊天圖片';

  @override
  String get worldBookSelectEntries => '多選條目';

  @override
  String get compressUsageSummary => '預計摘要';

  @override
  String contextDetailRange(String from, String to, int count) {
    return '第 $from–$to 則 · $count 則使用者訊息';
  }

  @override
  String get contextOperationHidden => '已被後續清除隔開';

  @override
  String get contextUndoClearTooltip => '撤銷此次清除';

  @override
  String compressKeepDescription(int count) {
    return '保留最近 $count 則使用者訊息及其回覆、工具過程；較早內容由摘要取代。純附件訊息也算一則。';
  }

  @override
  String get contextOperationUndone => '已撤銷';

  @override
  String contextEditPreview(String value) {
    return '儲存後約 $value tokens。輸入時不影響目前生效內容。';
  }

  @override
  String get contextDetailExcluded => '不再傳送';

  @override
  String get worldBookNoMoveTargets => '請先建立另一本世界書，再移動條目。';

  @override
  String worldBookSelectedEntries(int count) {
    return '已選擇 $count 項';
  }

  @override
  String get contextDetailReplaced => '被取代範圍';

  @override
  String get displaySettingsPageAutoScrollEnabledLabel => '開啟';

  @override
  String get contextChangeTitle => '確認上下文影響';

  @override
  String get contextDetailTitle => '壓縮摘要';

  @override
  String get compressModelGlobal => '全域設定 · 本次啟動後固定';

  @override
  String get wsDeniedMountReadonly => '唯讀掛載，無法寫入。';

  @override
  String get compressRereadDesc => '處理多次壓縮造成的資訊損失，會增加本次用量';

  @override
  String get toolApprovalSwitchToFullAccess => '切換到完全存取';

  @override
  String get compressUsageInput => '本次摘要輸入';

  @override
  String get contextDetailSummaryLabel => '實際用於後續請求的摘要';

  @override
  String get contextImpactDeleteTitle => '刪除已壓縮的原文？';

  @override
  String get compressAdvancedOff => '重讀原文 關';

  @override
  String get contextOperationActive => '目前生效';

  @override
  String get compressAdvancedOn => '重讀原文 開';

  @override
  String get contextTaskMerging => '正在合併摘要';

  @override
  String contextSampledInfo(int count) {
    return '本次只讀取選定的 $count 字元，摘要會替代整個選定歷史範圍。';
  }

  @override
  String get contextDividerRunning => '正在壓縮上下文';

  @override
  String get contextClearDetails => '此前聊天歷史不再參與後續請求；系統提示、記憶和工具定義仍然生效。';

  @override
  String get compressCopyResult => '複製結果';

  @override
  String get contextDetailInUse => '目前直接使用';

  @override
  String get contextImpactDescription =>
      '相關摘要將一併撤銷；原始聊天訊息保留，不會自動呼叫模型。獨立的上下文節點保持不變。';

  @override
  String get compressIncludeAttachmentsDesc =>
      '納入已有附件文字、工具參數與結果；過長內容會截斷並標明，不會重新識圖。';

  @override
  String worldBookEntriesMoved(int count) {
    return '已移動 $count 個條目';
  }

  @override
  String get contextImpactSourceDescription =>
      '確認後變更原文，並撤銷概括過它的摘要及相依後繼。其他訊息與獨立節點保留，不會自動呼叫模型。';

  @override
  String get contextEditTitle => '編輯摘要';

  @override
  String get compressUsageNext => '生效後下次請求';

  @override
  String get contextSummaryEmpty => '摘要不能為空；需要排除歷史時請使用清除上下文。';

  @override
  String get toolApprovalDenied => '已拒絕';

  @override
  String get contextDetailModel => '模型 · 時間';

  @override
  String compressIncludeManual(int count) {
    return '納入人工補充 · $count 份';
  }

  @override
  String contextBudgetInfo(int used, String limit) {
    return '下次請求估算（含輸出預留）：$used / $limit tokens';
  }

  @override
  String get contextTaskDismiss => '關閉狀態提示';

  @override
  String contextUndoBudgetInfo(int used) {
    return '撤銷後預計約 $used tokens（含輸出預留）';
  }

  @override
  String get storageSpaceImageInUse => '使用中';

  @override
  String get worldBookSelectionDone => '完成';

  @override
  String get contextDividerFailed => '壓縮失敗';

  @override
  String get toolPermissionUnboundHint => '未綁定工作區：不會因此開啟檔案或 Shell 工具。';

  @override
  String get contextChangeWaiting => '等待目前回覆與工具執行結束後生效。';

  @override
  String storageSpaceDeletedUploadsPartial(int deleted, int kept) {
    return '已刪除 $deleted 個項目；保留了 $kept 個正在使用或無法刪除的項目。';
  }

  @override
  String get contextSourceScopeHint => '僅處理最近清除邊界之後的歷史，可能包含平時傳送範圍之外的較早訊息。';

  @override
  String get contextTaskPreparing => '正在準備壓縮';

  @override
  String contextImpactUsage(String from, String to) {
    return '約 $from → $to tokens';
  }

  @override
  String contextImpactConfirm(int count) {
    return '撤銷 $count 個節點';
  }

  @override
  String get contextDividerEdited => '已編輯';

  @override
  String get compressAdjust => '調整';

  @override
  String get compressRegenerate => '重新壓縮';

  @override
  String get toolPermissionEnabledSnack => '已為此對話啟用完全存取';

  @override
  String get contextDetailSuperseded => '已由後續摘要取代';

  @override
  String get contextTaskQueued => '已排隊，等待壓縮完成';

  @override
  String get contextNewConversation => '使用摘要建立新聊天';

  @override
  String get contextUnknownLimit => '上限未知';

  @override
  String get browserErrActionTimeout => '操作逾時，結果未確認，請檢查頁面後允許繼續';

  @override
  String get toolPermissionRequestApprovalDesc =>
      '工作區外檔案存取、桌面命令和其他需要授權的工具將在執行前詢問。';

  @override
  String get contextLimitedInputHint => '僅讀取所選字元範圍；被替代歷史中的其餘內容不會進入摘要，原始訊息仍可檢視。';

  @override
  String get contextTaskCancelled => '壓縮已取消';

  @override
  String get contextDetailClearTitle => '上下文已清除';

  @override
  String get contextImpactKeep => '保持不變';

  @override
  String get contextImpactUndoAlso => '一併撤銷';

  @override
  String get contextClearMarker => '上下文已清除';

  @override
  String get toolPermissionScopeThisChat => '僅此對話';

  @override
  String get dataDirectoryTitle => '資料儲存目錄';

  @override
  String get dataDirectoryChange => '變更目錄';

  @override
  String get dataDirectoryChoose => '選擇一個空的本機資料夾';

  @override
  String get dataDirectoryHint =>
      '請選擇本機磁碟上的空資料夾。聊天記錄、附件和應用程式管理的檔案將在重新啟動後搬遷。少量裝置設定和系統快取仍保留在系統目錄。';

  @override
  String get dataDirectoryPendingHint => '將在下次重新啟動時搬遷。複製和驗證完成前，原資料保持不變。目標目錄：';

  @override
  String get dataDirectoryRestart => '重新啟動並搬遷資料';

  @override
  String get dataDirectoryCancelMove => '取消搬遷，繼續使用原目錄';

  @override
  String get dataDirectoryPreviousHint =>
      '已保留原資料副本。新目錄成功啟動後，可以清理舊副本以釋放磁碟空間。再次變更目錄前，請先清理此副本。';

  @override
  String get dataDirectoryCleanPrevious => '清理原資料副本';

  @override
  String get dataDirectoryCleanConfirm =>
      '確定清理以下目錄中的原資料副本？目前目錄中的資料會保留，搬遷後發生變化的檔案不會被刪除。';

  @override
  String get dataDirectoryMoving => '正在搬遷並驗證資料…請保持 Kelivo 開啟。';

  @override
  String get dataDirectoryStartupFailed => '無法開啟資料目錄';

  @override
  String get dataDirectoryRetry => '重試';

  @override
  String get dataDirectoryUnavailable =>
      '資料目錄無法使用。請重新連接磁碟，或將資料夾還原至原位置後重試。應用程式不會建立空資料庫。';

  @override
  String get dataDirectoryIdentityMismatch => '此資料夾與已設定的資料目錄不符。請還原原資料夾後重試。';

  @override
  String get dataDirectoryNotEmpty => '請選擇空資料夾，不會覆寫現有檔案。';

  @override
  String get dataDirectoryOverlap => '請選擇目前資料目錄之外的獨立資料夾，不能選擇其上層目錄、子目錄或磁碟根目錄。';

  @override
  String get dataDirectoryLocalOnly => '請選擇本機磁碟上的資料夾，不支援網路共用目錄。';

  @override
  String get dataDirectoryFinishPrevious => '請先完成或取消待執行的搬遷，並清理保留的舊副本，再選擇其他目錄。';

  @override
  String get dataDirectoryPendingRestore =>
      '有備份還原尚未完成。請取消目錄搬遷並重新啟動，完成還原後再變更目錄。';

  @override
  String get dataDirectorySourceChanged =>
      '原資料在複製後發生了變化，已保留原檔案。若正在搬遷，請取消後重新開始；若正在清理，請先檢查原目錄。';

  @override
  String get dataDirectoryCopyChanged => '目標目錄存在非預期檔案或檔案變更，原資料已保留。請檢查目標目錄後重試。';

  @override
  String get dataDirectoryGenericError =>
      '操作未完成。請檢查磁碟剩餘空間、資料夾權限，以及是否有其他 Kelivo 處理程序執行，然後重試。現有資料已保留。';

  @override
  String get dataDirectoryCancelHint => '取消搬遷會保留目標目錄中已複製的檔案，你可以檢查後手動清理這些副本。';
}
