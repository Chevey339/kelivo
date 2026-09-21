import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../../../l10n/app_localizations_zh.dart';

enum SettingsSearchDestination {
  display,
  colorMode,
  theme,
  themeAdvanced,
  chatDisplay,
  rendering,
  behavior,
  image,
  messageStyle,
  autoRetry,
  haptics,
  background,
  assistant,
  providers,
  defaultModel,
  search,
  tts,
  mcp,
  workspace,
  skills,
  quickPhrases,
  instructionInjection,
  worldBook,
  memory,
  networkProxy,
  backup,
  storage,
  scheduledTasks,
  hotkeys,
  stats,
  toolSchemas,
  logs,
  about,
  sponsor,
}

extension SettingsSearchDestinationDetails on SettingsSearchDestination {
  String title(AppLocalizations l) => switch (this) {
    SettingsSearchDestination.display => l.settingsPageDisplay,
    SettingsSearchDestination.colorMode => l.settingsPageColorMode,
    SettingsSearchDestination.theme => l.displaySettingsPageThemeSettingsTitle,
    SettingsSearchDestination.themeAdvanced => l.themeAdvancedSettingsPageTitle,
    SettingsSearchDestination.chatDisplay =>
      l.displaySettingsPageChatItemDisplayTitle,
    SettingsSearchDestination.rendering =>
      l.displaySettingsPageRenderingSettingsTitle,
    SettingsSearchDestination.behavior =>
      l.displaySettingsPageBehaviorStartupTitle,
    SettingsSearchDestination.image => l.imageSettingsPageTitle,
    SettingsSearchDestination.messageStyle => l.messageStyleSettingsPageTitle,
    SettingsSearchDestination.autoRetry => l.settingsPageAutoRetry,
    SettingsSearchDestination.haptics =>
      l.displaySettingsPageHapticsSettingsTitle,
    SettingsSearchDestination.background => l.backgroundSettingsTitle,
    SettingsSearchDestination.assistant => l.settingsPageAssistant,
    SettingsSearchDestination.providers => l.settingsPageProviders,
    SettingsSearchDestination.defaultModel => l.settingsPageDefaultModel,
    SettingsSearchDestination.search => l.settingsPageSearch,
    SettingsSearchDestination.tts => l.settingsPageTts,
    SettingsSearchDestination.mcp => l.settingsPageMcp,
    SettingsSearchDestination.workspace => l.settingsPageWorkspace,
    SettingsSearchDestination.skills => l.settingsPageSkills,
    SettingsSearchDestination.quickPhrases => l.settingsPageQuickPhrase,
    SettingsSearchDestination.instructionInjection =>
      l.settingsPageInstructionInjection,
    SettingsSearchDestination.worldBook => l.settingsPageWorldBook,
    SettingsSearchDestination.memory => l.settingsPageMemory,
    SettingsSearchDestination.networkProxy => l.settingsPageNetworkProxy,
    SettingsSearchDestination.backup => l.settingsPageBackup,
    SettingsSearchDestination.storage => l.settingsPageChatStorage,
    SettingsSearchDestination.scheduledTasks => l.scheduledTasksTitle,
    SettingsSearchDestination.hotkeys => l.settingsPageHotkeys,
    SettingsSearchDestination.stats => l.settingsPageStatistics,
    SettingsSearchDestination.toolSchemas => l.toolSchemaSettingsPageTitle,
    SettingsSearchDestination.logs => l.settingsPageLogs,
    SettingsSearchDestination.about => l.settingsPageAbout,
    SettingsSearchDestination.sponsor => l.settingsPageSponsor,
  };

  IconData get icon => switch (this) {
    SettingsSearchDestination.display => LucideIcons.monitor,
    SettingsSearchDestination.colorMode => LucideIcons.sunMoon,
    SettingsSearchDestination.theme => LucideIcons.palette,
    SettingsSearchDestination.themeAdvanced => LucideIcons.layers,
    SettingsSearchDestination.chatDisplay => LucideIcons.messageCircle,
    SettingsSearchDestination.rendering => LucideIcons.textInitial,
    SettingsSearchDestination.behavior => LucideIcons.settings2,
    SettingsSearchDestination.image => LucideIcons.image,
    SettingsSearchDestination.messageStyle => LucideIcons.messageSquare,
    SettingsSearchDestination.autoRetry => LucideIcons.refreshCw,
    SettingsSearchDestination.haptics => LucideIcons.vibrate,
    SettingsSearchDestination.background => LucideIcons.activity,
    SettingsSearchDestination.assistant => LucideIcons.bot,
    SettingsSearchDestination.providers => LucideIcons.boxes,
    SettingsSearchDestination.defaultModel => LucideIcons.heart,
    SettingsSearchDestination.search => LucideIcons.globe,
    SettingsSearchDestination.tts => LucideIcons.volume2,
    SettingsSearchDestination.mcp => LucideIcons.terminal,
    SettingsSearchDestination.workspace => LucideIcons.folderCode,
    SettingsSearchDestination.skills => LucideIcons.wandSparkles,
    SettingsSearchDestination.quickPhrases => LucideIcons.zap,
    SettingsSearchDestination.instructionInjection => LucideIcons.layers,
    SettingsSearchDestination.worldBook => LucideIcons.bookOpen,
    SettingsSearchDestination.memory => LucideIcons.brain,
    SettingsSearchDestination.networkProxy => LucideIcons.ethernetPort,
    SettingsSearchDestination.backup => LucideIcons.database,
    SettingsSearchDestination.storage => LucideIcons.hardDrive,
    SettingsSearchDestination.scheduledTasks => LucideIcons.clock,
    SettingsSearchDestination.hotkeys => LucideIcons.keyboard,
    SettingsSearchDestination.stats => LucideIcons.chartColumnBig,
    SettingsSearchDestination.toolSchemas => LucideIcons.wrench,
    SettingsSearchDestination.logs => LucideIcons.fileText,
    SettingsSearchDestination.about => LucideIcons.info,
    SettingsSearchDestination.sponsor => LucideIcons.heart,
  };

  bool get isDisplaySection => switch (this) {
    SettingsSearchDestination.theme ||
    SettingsSearchDestination.themeAdvanced ||
    SettingsSearchDestination.chatDisplay ||
    SettingsSearchDestination.rendering ||
    SettingsSearchDestination.behavior ||
    SettingsSearchDestination.image ||
    SettingsSearchDestination.messageStyle ||
    SettingsSearchDestination.autoRetry ||
    SettingsSearchDestination.haptics ||
    SettingsSearchDestination.background => true,
    _ => false,
  };
}

class SettingsSearchItem {
  SettingsSearchItem({
    required this.id,
    required this.title,
    required this.path,
    required this.destination,
    required this.targetLabel,
    required List<String> alternateTitles,
    required String keywords,
  }) : _title = _normalize(title),
       _alternateTitles = alternateTitles.map(_normalize).toList(),
       _path = _normalize(path.join(' ')),
       _keywords = _normalize(keywords);

  final String id;
  final String title;
  final List<String> path;
  final SettingsSearchDestination destination;
  final String? targetLabel;
  final String _title;
  final List<String> _alternateTitles;
  final String _path;
  final String _keywords;

  IconData get icon => destination.icon;

  int _score(String query, List<String> tokens) {
    var score = _title == query
        ? 1000
        : _title.startsWith(query)
        ? 500
        : 0;
    for (final token in tokens) {
      if (_title.contains(token)) {
        score += 100;
      } else if (_alternateTitles.any((title) => title.contains(token))) {
        score += 70;
      } else if (_keywords.contains(token)) {
        score += 30;
      } else if (_path.contains(token)) {
        score += 10;
      } else {
        return 0;
      }
    }
    return score;
  }
}

/// Small, immutable, in-memory index. Normalize translations once per locale /
/// availability change; typing only scans strings, never providers or widgets.
class SettingsSearchIndex {
  SettingsSearchIndex(
    AppLocalizations l, {
    required TargetPlatform platform,
    bool logsEnabled = false,
    bool dynamicColorSupported = false,
  }) {
    final desktop = switch (platform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };
    final en = AppLocalizationsEn();
    final zh = AppLocalizationsZh();
    final hant = AppLocalizationsZhHant();
    final items = <SettingsSearchItem>[];
    void add(
      String id,
      SettingsSearchDestination destination,
      String Function(AppLocalizations) title, {
      String keywords = '',
      bool page = false,
      String? targetLabel,
    }) {
      final path = <String>[
        l.settingsPageTitle,
        if (destination.isDisplaySection ||
            (desktop && destination == SettingsSearchDestination.colorMode))
          l.settingsPageDisplay,
        if (!desktop && destination == SettingsSearchDestination.themeAdvanced)
          l.displaySettingsPageThemeSettingsTitle,
        if (!page) destination.title(l),
      ];
      items.add(
        SettingsSearchItem(
          id: id,
          title: title(l),
          path: path,
          destination: destination,
          targetLabel: targetLabel ?? (page ? null : title(l)),
          alternateTitles: [title(en), title(zh), title(hant)],
          keywords: keywords,
        ),
      );
    }

    add(
      'display',
      SettingsSearchDestination.display,
      (l) => l.settingsPageDisplay,
      page: true,
      keywords: 'display appearance 显示 顯示 外观 外觀',
    );
    add(
      'colorMode',
      SettingsSearchDestination.colorMode,
      (l) => l.settingsPageColorMode,
      page: true,
      keywords: 'dark light system night 黑暗 深色 暗黑 浅色 夜间 夜間',
      targetLabel: desktop ? l.settingsPageColorMode : null,
    );
    add(
      'theme',
      SettingsSearchDestination.theme,
      (l) => l.displaySettingsPageThemeSettingsTitle,
      page: true,
      keywords: 'theme color palette accent 主题 主題 颜色 顏色 配色 自定义 自訂',
      targetLabel: desktop ? l.displaySettingsPageThemeColorTitle : null,
    );
    add(
      'themeAdvanced',
      SettingsSearchDestination.themeAdvanced,
      (l) => l.themeAdvancedSettingsPageTitle,
      page: true,
      keywords: 'layered surface 分层 分層 高级 高級',
      targetLabel: desktop
          ? l.themeAdvancedSettingsPageUseLayeredSurfacesTitle
          : null,
    );
    add(
      'chatDisplay',
      SettingsSearchDestination.chatDisplay,
      (l) => l.displaySettingsPageChatItemDisplayTitle,
      page: true,
      keywords: 'avatar timestamp token 聊天 头像 頭像 时间戳 時間戳',
      targetLabel: desktop ? l.displaySettingsPageChatItemDisplayTitle : null,
    );
    add(
      'rendering',
      SettingsSearchDestination.rendering,
      (l) => l.displaySettingsPageRenderingSettingsTitle,
      page: true,
      keywords: 'markdown latex math formula 渲染 数学 數學 公式 代码 代碼',
      targetLabel: desktop ? l.displaySettingsPageRenderingSettingsTitle : null,
    );
    add(
      'behavior',
      SettingsSearchDestination.behavior,
      (l) => l.displaySettingsPageBehaviorStartupTitle,
      page: true,
      keywords: 'startup behavior 启动 啟動 行为 行為 折叠 摺疊',
      targetLabel: desktop ? l.displaySettingsPageBehaviorStartupTitle : null,
    );
    add(
      'image',
      SettingsSearchDestination.image,
      (l) => l.imageSettingsPageTitle,
      page: true,
      keywords: 'image compress quality 图片 圖片 压缩 壓縮 画质 畫質',
      targetLabel: desktop ? l.imageSettingsPageTitle : null,
    );
    add(
      'messageStyle',
      SettingsSearchDestination.messageStyle,
      (l) => l.messageStyleSettingsPageTitle,
      page: true,
      keywords: 'bubble frosted blur glass 气泡 氣泡 毛玻璃 圆角 圓角 消息样式',
    );
    add(
      'autoRetry',
      SettingsSearchDestination.autoRetry,
      (l) => l.settingsPageAutoRetry,
      page: true,
      keywords: 'retry timeout error 自动重试 自動重試 失败 失敗 网络 网络错误',
    );
    if (!desktop) {
      add(
        'haptics',
        SettingsSearchDestination.haptics,
        (l) => l.displaySettingsPageHapticsSettingsTitle,
        page: true,
        keywords: 'haptic vibration 震动 振动 震動 触感 觸感',
      );
    }
    if (!desktop) {
      add(
        'background',
        SettingsSearchDestination.background,
        (l) => l.backgroundSettingsTitle,
        page: true,
        keywords:
            'background keep alive notification live activity 后台 後台 保活 灵动岛 靈動島',
      );
    }
    add(
      'assistant',
      SettingsSearchDestination.assistant,
      (l) => l.settingsPageAssistant,
      page: true,
      keywords:
          'assistant system prompt temperature top p 人设 人設 系统提示词 系統提示詞 助手',
    );
    add(
      'providers',
      SettingsSearchDestination.providers,
      (l) => l.settingsPageProviders,
      page: true,
      keywords:
          'provider api key url base endpoint oauth openai claude gemini deepseek 服务商 服務商 供应商 供應商 接口 密钥 密鑰 模型',
    );
    add(
      'defaultModel',
      SettingsSearchDestination.defaultModel,
      (l) => l.settingsPageDefaultModel,
      page: true,
      keywords:
          'default model title summary translate ocr compression suggestion 默认 預設 模型 标题 標題 总结 總結 翻译 翻譯 识图 識圖 压缩 壓縮 建议 建議',
    );
    add(
      'search',
      SettingsSearchDestination.search,
      (l) => l.settingsPageSearch,
      page: true,
      keywords:
          'web internet tavily exa brave bing google search 联网 聯網 搜索 搜尋 引擎',
    );
    add(
      'tts',
      SettingsSearchDestination.tts,
      (l) => l.settingsPageTts,
      page: true,
      keywords:
          'tts asr stt speech voice audio recognition whisper 语音 語音 朗读 朗讀 识别 識別 声音 聲音 转文字',
    );
    add(
      'mcp',
      SettingsSearchDestination.mcp,
      (l) => l.settingsPageMcp,
      page: true,
      keywords: 'mcp server tools sse stdio streamable 工具 服务器 伺服器',
    );
    add(
      'workspace',
      SettingsSearchDestination.workspace,
      (l) => l.settingsPageWorkspace,
      page: true,
      keywords:
          'workspace sandbox file terminal shell python 工作区 工作區 文件 沙箱 终端 終端',
    );
    add(
      'skills',
      SettingsSearchDestination.skills,
      (l) => l.settingsPageSkills,
      page: true,
      keywords: 'skills 技能',
    );
    add(
      'quickPhrases',
      SettingsSearchDestination.quickPhrases,
      (l) => l.settingsPageQuickPhrase,
      page: true,
      keywords: 'quick phrase 快捷短语 快捷短語 常用语 常用語',
    );
    add(
      'instructionInjection',
      SettingsSearchDestination.instructionInjection,
      (l) => l.settingsPageInstructionInjection,
      page: true,
      keywords: 'prompt injection 提示词 提示詞 指令 注入',
    );
    add(
      'worldBook',
      SettingsSearchDestination.worldBook,
      (l) => l.settingsPageWorldBook,
      page: true,
      keywords: 'world book lorebook 世界书 世界書 知识 知識 角色',
    );
    add(
      'memory',
      SettingsSearchDestination.memory,
      (l) => l.settingsPageMemory,
      page: true,
      keywords: 'memory remember 记忆 記憶 长期 長期',
    );
    add(
      'networkProxy',
      SettingsSearchDestination.networkProxy,
      (l) => l.settingsPageNetworkProxy,
      page: true,
      keywords: 'network proxy socks http 网络 網路 代理 端口 埠',
    );
    add(
      'backup',
      SettingsSearchDestination.backup,
      (l) => l.settingsPageBackup,
      page: true,
      keywords:
          'backup restore export import webdav s3 cloud sync 备份 備份 恢复 還原 导入 匯入 导出 匯出 同步 快照',
    );
    if (!desktop) {
      add(
        'storage',
        SettingsSearchDestination.storage,
        (l) => l.settingsPageChatStorage,
        page: true,
        keywords: 'storage cache cleanup database 存储 儲存 缓存 快取 空间 空間 清理 数据库 資料庫',
      );
    }
    if (desktop || platform == TargetPlatform.android) {
      add(
        'scheduledTasks',
        SettingsSearchDestination.scheduledTasks,
        (l) => l.scheduledTasksTitle,
        page: true,
        keywords: 'scheduled timer alarm cron 定时 定時 计划 排程 任务 任務',
      );
    }
    if (desktop) {
      add(
        'hotkeys',
        SettingsSearchDestination.hotkeys,
        (l) => l.settingsPageHotkeys,
        page: true,
        keywords: 'hotkey shortcut 快捷键 快捷鍵 热键 熱鍵',
      );
    }
    add(
      'stats',
      SettingsSearchDestination.stats,
      (l) => l.settingsPageStatistics,
      page: true,
      keywords: 'statistics token usage 统计 統計 用量 消耗',
    );
    add(
      'toolSchemas',
      SettingsSearchDestination.toolSchemas,
      (l) => l.toolSchemaSettingsPageTitle,
      page: true,
      keywords: 'tool schema json 工具 参数 參數 定义 定義',
    );
    if (!desktop && logsEnabled) {
      add(
        'logs',
        SettingsSearchDestination.logs,
        (l) => l.settingsPageLogs,
        page: true,
        keywords: 'log debug request flutter context 日志 日誌 调试 偵錯 请求 請求',
      );
    }
    add(
      'about',
      SettingsSearchDestination.about,
      (l) => l.settingsPageAbout,
      page: true,
      keywords: 'about version update 关于 關於 版本 更新',
    );
    if (!desktop) {
      add(
        'sponsor',
        SettingsSearchDestination.sponsor,
        (l) => l.settingsPageSponsor,
        page: true,
        keywords: 'sponsor donate 赞助 贊助 支持',
      );
    }

    // Display rows share their localized labels with the navigation anchors.
    add(
      'displaySettingsPageLanguageTitle',
      SettingsSearchDestination.display,
      (l) => l.displaySettingsPageLanguageTitle,
      keywords: 'language locale chinese english 语言 語言 中文 英文 简体 简中 繁体 繁中',
    );
    add(
      'displaySettingsPageAppFontTitle',
      SettingsSearchDestination.display,
      (l) => l.displaySettingsPageAppFontTitle,
      keywords: 'font typeface 字体 字型 系统字体',
      targetLabel: desktop ? l.desktopFontAppLabel : null,
    );
    add(
      'displaySettingsPageCodeFontTitle',
      SettingsSearchDestination.display,
      (l) => l.displaySettingsPageCodeFontTitle,
      keywords: 'monospace font 等宽 等寬 代码字体',
      targetLabel: desktop ? l.desktopFontCodeLabel : null,
    );
    add(
      'displaySettingsPageChatFontSizeTitle',
      SettingsSearchDestination.display,
      (l) => l.displaySettingsPageChatFontSizeTitle,
      keywords: 'font size text scale 字号 字號 文字大小 字体大小',
    );
    add(
      'displaySettingsPageAutoScrollIdleTitle',
      SettingsSearchDestination.display,
      (l) => l.displaySettingsPageAutoScrollIdleTitle,
      keywords: 'auto scroll 自动滚动 自動捲動 延迟 延遲',
    );
    add(
      'displaySettingsPageChatBackgroundMaskTitle',
      SettingsSearchDestination.display,
      (l) => l.displaySettingsPageChatBackgroundMaskTitle,
      keywords: 'background wallpaper opacity 背景 壁纸 壁紙 蒙版 透明度',
    );
    add(
      'displaySettingsPageChatInputBackgroundOpacityTitle',
      SettingsSearchDestination.display,
      (l) => l.displaySettingsPageChatInputBackgroundOpacityTitle,
    );
    add(
      'displaySettingsPageShowUserAvatarTitle',
      SettingsSearchDestination.chatDisplay,
      (l) => l.displaySettingsPageShowUserAvatarTitle,
    );
    add(
      'displaySettingsPageShowUserNameTitle',
      SettingsSearchDestination.chatDisplay,
      (l) => l.displaySettingsPageShowUserNameTitle,
    );
    add(
      'displaySettingsPageShowUserTimestampTitle',
      SettingsSearchDestination.chatDisplay,
      (l) => l.displaySettingsPageShowUserTimestampTitle,
    );
    add(
      'displaySettingsPageShowUserMessageActionsTitle',
      SettingsSearchDestination.chatDisplay,
      (l) => l.displaySettingsPageShowUserMessageActionsTitle,
    );
    add(
      'displaySettingsPageChatModelIconTitle',
      SettingsSearchDestination.chatDisplay,
      (l) => l.displaySettingsPageChatModelIconTitle,
    );
    add(
      'displaySettingsPageUseNewAssistantAvatarUxTitle',
      SettingsSearchDestination.chatDisplay,
      (l) => l.displaySettingsPageUseNewAssistantAvatarUxTitle,
    );
    add(
      'displaySettingsPageShowModelNameTitle',
      SettingsSearchDestination.chatDisplay,
      (l) => l.displaySettingsPageShowModelNameTitle,
    );
    add(
      'displaySettingsPageShowModelTimestampTitle',
      SettingsSearchDestination.chatDisplay,
      (l) => l.displaySettingsPageShowModelTimestampTitle,
    );
    add(
      'displaySettingsPageShowProviderInChatMessageTitle',
      SettingsSearchDestination.chatDisplay,
      (l) => l.displaySettingsPageShowProviderInChatMessageTitle,
    );
    add(
      'displaySettingsPageShowTokenStatsTitle',
      SettingsSearchDestination.chatDisplay,
      (l) => l.displaySettingsPageShowTokenStatsTitle,
      keywords: 'token usage 令牌 消耗 用量',
    );
    add(
      'displaySettingsPageShowThinkingCardsTitle',
      SettingsSearchDestination.chatDisplay,
      (l) => l.displaySettingsPageShowThinkingCardsTitle,
    );
    add(
      'displaySettingsPageShowToolCardsTitle',
      SettingsSearchDestination.chatDisplay,
      (l) => l.displaySettingsPageShowToolCardsTitle,
    );
    add(
      'displaySettingsPageShowProducedFilesTitle',
      SettingsSearchDestination.chatDisplay,
      (l) => l.displaySettingsPageShowProducedFilesTitle,
    );
    add(
      'displaySettingsPageEnableDollarLatexTitle',
      SettingsSearchDestination.rendering,
      (l) => l.displaySettingsPageEnableDollarLatexTitle,
      keywords: 'latex dollar 美元符号 公式',
    );
    add(
      'displaySettingsPageEnableMathTitle',
      SettingsSearchDestination.rendering,
      (l) => l.displaySettingsPageEnableMathTitle,
    );
    add(
      'displaySettingsPageEnableUserMarkdownTitle',
      SettingsSearchDestination.rendering,
      (l) => l.displaySettingsPageEnableUserMarkdownTitle,
    );
    add(
      'displaySettingsPageEnableReasoningMarkdownTitle',
      SettingsSearchDestination.rendering,
      (l) => l.displaySettingsPageEnableReasoningMarkdownTitle,
    );
    add(
      'displaySettingsPageEnableAssistantMarkdownTitle',
      SettingsSearchDestination.rendering,
      (l) => l.displaySettingsPageEnableAssistantMarkdownTitle,
    );
    add(
      'displaySettingsPageAutoCollapseCodeBlockTitle',
      SettingsSearchDestination.rendering,
      (l) => l.displaySettingsPageAutoCollapseCodeBlockTitle,
      keywords: 'code block threshold lines 代码块 折叠 行数',
    );
    if (!desktop) {
      add(
        'displaySettingsPageMobileCodeBlockWrapTitle',
        SettingsSearchDestination.rendering,
        (l) => l.displaySettingsPageMobileCodeBlockWrapTitle,
      );
    }
    add(
      'displaySettingsPageAutoCollapseThinkingTitle',
      SettingsSearchDestination.behavior,
      (l) => l.displaySettingsPageAutoCollapseThinkingTitle,
    );
    add(
      'displaySettingsPageCollapseThinkingStepsTitle',
      SettingsSearchDestination.behavior,
      (l) => l.displaySettingsPageCollapseThinkingStepsTitle,
    );
    add(
      'displaySettingsPageShowToolResultSummaryTitle',
      SettingsSearchDestination.behavior,
      (l) => l.displaySettingsPageShowToolResultSummaryTitle,
    );
    add(
      'displaySettingsPageHideToolResultImagesTitle',
      SettingsSearchDestination.behavior,
      (l) => l.displaySettingsPageHideToolResultImagesTitle,
      keywords: 'tool image 工具 图片 隐藏',
    );
    add(
      'displaySettingsPageInsertSuggestionOnlyTitle',
      SettingsSearchDestination.behavior,
      (l) => l.displaySettingsPageInsertSuggestionOnlyTitle,
    );
    add(
      'displaySettingsPageCollapseLongUserMessagesTitle',
      SettingsSearchDestination.behavior,
      (l) => l.displaySettingsPageCollapseLongUserMessagesTitle,
      keywords: 'collapse long message threshold 长消息 长文本 折叠',
    );
    add(
      'displaySettingsPageRegenerateDeleteTrailingMessagesTitle',
      SettingsSearchDestination.behavior,
      (l) => l.displaySettingsPageRegenerateDeleteTrailingMessagesTitle,
    );
    add(
      'displaySettingsPageShowRegenerateConfirmDialogTitle',
      SettingsSearchDestination.behavior,
      (l) => l.displaySettingsPageShowRegenerateConfirmDialogTitle,
    );
    add(
      'displaySettingsPageForkKeepMessageVersionsTitle',
      SettingsSearchDestination.behavior,
      (l) => l.displaySettingsPageForkKeepMessageVersionsTitle,
    );
    add(
      'displaySettingsPageEditAssistantKeepThinkingToolCardsTitle',
      SettingsSearchDestination.behavior,
      (l) => l.displaySettingsPageEditAssistantKeepThinkingToolCardsTitle,
    );
    add(
      'displaySettingsPageShowUpdatesTitle',
      SettingsSearchDestination.behavior,
      (l) => l.displaySettingsPageShowUpdatesTitle,
    );
    if (!desktop) {
      add(
        'displaySettingsPageKeepScreenOnDuringGenerationTitle',
        SettingsSearchDestination.behavior,
        (l) => l.displaySettingsPageKeepScreenOnDuringGenerationTitle,
      );
    }
    add(
      'displaySettingsPageMessageNavButtonsTitle',
      SettingsSearchDestination.behavior,
      (l) => l.displaySettingsPageMessageNavButtonsTitle,
    );
    add(
      'displaySettingsPageShowChatListDateTitle',
      SettingsSearchDestination.behavior,
      (l) => l.displaySettingsPageShowChatListDateTitle,
    );
    if (!desktop) {
      add(
        'displaySettingsPageKeepSidebarOpenOnAssistantTapTitle',
        SettingsSearchDestination.behavior,
        (l) => l.displaySettingsPageKeepSidebarOpenOnAssistantTapTitle,
      );
    }
    if (!desktop) {
      add(
        'displaySettingsPageKeepSidebarOpenOnTopicTapTitle',
        SettingsSearchDestination.behavior,
        (l) => l.displaySettingsPageKeepSidebarOpenOnTopicTapTitle,
      );
    }
    if (!desktop) {
      add(
        'displaySettingsPageKeepAssistantListExpandedOnSidebarCloseTitle',
        SettingsSearchDestination.behavior,
        (l) =>
            l.displaySettingsPageKeepAssistantListExpandedOnSidebarCloseTitle,
      );
    }
    add(
      'displaySettingsPageNewChatOnAssistantSwitchTitle',
      SettingsSearchDestination.behavior,
      (l) => l.displaySettingsPageNewChatOnAssistantSwitchTitle,
    );
    add(
      'displaySettingsPageNewChatAfterDeleteTitle',
      SettingsSearchDestination.behavior,
      (l) => l.displaySettingsPageNewChatAfterDeleteTitle,
    );
    add(
      'displaySettingsPageNewChatOnLaunchTitle',
      SettingsSearchDestination.behavior,
      (l) => l.displaySettingsPageNewChatOnLaunchTitle,
    );
    if (!desktop) {
      add(
        'displaySettingsPageEnterToSendTitle',
        SettingsSearchDestination.behavior,
        (l) => l.displaySettingsPageEnterToSendTitle,
      );
    }
    add(
      'displaySettingsPageLongPasteAsFileTitle',
      SettingsSearchDestination.behavior,
      (l) => l.displaySettingsPageLongPasteAsFileTitle,
      keywords: 'paste clipboard threshold 粘贴 貼上 长文本 长文',
    );
    if (!desktop) {
      add(
        'displaySettingsPageHapticsGlobalTitle',
        SettingsSearchDestination.haptics,
        (l) => l.displaySettingsPageHapticsGlobalTitle,
      );
    }
    if (!desktop) {
      add(
        'displaySettingsPageHapticsIosSwitchTitle',
        SettingsSearchDestination.haptics,
        (l) => l.displaySettingsPageHapticsIosSwitchTitle,
      );
    }
    if (!desktop) {
      add(
        'displaySettingsPageHapticsOnSidebarTitle',
        SettingsSearchDestination.haptics,
        (l) => l.displaySettingsPageHapticsOnSidebarTitle,
      );
    }
    if (!desktop) {
      add(
        'displaySettingsPageHapticsOnListItemTapTitle',
        SettingsSearchDestination.haptics,
        (l) => l.displaySettingsPageHapticsOnListItemTapTitle,
      );
    }
    if (!desktop) {
      add(
        'displaySettingsPageHapticsOnCardTapTitle',
        SettingsSearchDestination.haptics,
        (l) => l.displaySettingsPageHapticsOnCardTapTitle,
      );
    }
    if (!desktop) {
      add(
        'displaySettingsPageHapticsOnGenerateTitle',
        SettingsSearchDestination.haptics,
        (l) => l.displaySettingsPageHapticsOnGenerateTitle,
      );
    }

    add(
      'themeSettingsPageUsePureBackgroundTitle',
      SettingsSearchDestination.theme,
      (l) => l.themeSettingsPageUsePureBackgroundTitle,
    );
    if (!desktop &&
        platform == TargetPlatform.android &&
        dynamicColorSupported) {
      add(
        'themeSettingsPageUseDynamicColorTitle',
        SettingsSearchDestination.theme,
        (l) => l.themeSettingsPageUseDynamicColorTitle,
      );
    }
    add(
      'themeAdvancedSettingsPageUseLayeredSurfacesTitle',
      SettingsSearchDestination.themeAdvanced,
      (l) => l.themeAdvancedSettingsPageUseLayeredSurfacesTitle,
    );
    add(
      'themeAdvancedSettingsPageUseLayeredSheetTilesTitle',
      SettingsSearchDestination.themeAdvanced,
      (l) => l.themeAdvancedSettingsPageUseLayeredSheetTilesTitle,
    );
    if (desktop) {
      add(
        'desktopDisplaySettingsTopicPositionTitle',
        SettingsSearchDestination.display,
        (l) => l.desktopDisplaySettingsTopicPositionTitle,
      );
    }
    if (desktop) {
      add(
        'displaySettingsPageTrayShowTrayTitle',
        SettingsSearchDestination.display,
        (l) => l.displaySettingsPageTrayShowTrayTitle,
      );
    }
    if (desktop) {
      add(
        'displaySettingsPageTrayMinimizeOnCloseTitle',
        SettingsSearchDestination.display,
        (l) => l.displaySettingsPageTrayMinimizeOnCloseTitle,
      );
    }
    if (desktop) {
      add(
        'desktopShowProviderInModelCapsule',
        SettingsSearchDestination.display,
        (l) => l.desktopShowProviderInModelCapsule,
      );
    }
    if (desktop) {
      add(
        'displaySettingsPageAutoSwitchTopicsTitle',
        SettingsSearchDestination.behavior,
        (l) => l.displaySettingsPageAutoSwitchTopicsTitle,
      );
    }
    if (desktop) {
      add(
        'displaySettingsPageSendShortcutTitle',
        SettingsSearchDestination.behavior,
        (l) => l.displaySettingsPageSendShortcutTitle,
      );
    }
    if (desktop) {
      add(
        'displaySettingsPageAutoScrollEnableTitle',
        SettingsSearchDestination.display,
        (l) => l.displaySettingsPageAutoScrollEnableTitle,
      );
    }

    entries = List.unmodifiable(items);
    suggestions = List.unmodifiable([
      for (final id in [
        'providers',
        'theme',
        'displaySettingsPageLanguageTitle',
        'displaySettingsPageChatFontSizeTitle',
        'backup',
        'tts',
      ])
        items.firstWhere((item) => item.id == id),
    ]);
  }

  late final List<SettingsSearchItem> entries;
  late final List<SettingsSearchItem> suggestions;

  List<SettingsSearchItem> search(String text) {
    final query = _normalize(text);
    if (query.isEmpty) return const [];
    final tokens = query.split(' ').toSet().toList();
    final matches = <({SettingsSearchItem item, int score, int order})>[];
    for (var i = 0; i < entries.length; i++) {
      final score = entries[i]._score(query, tokens);
      if (score > 0) matches.add((item: entries[i], score: score, order: i));
    }
    matches.sort((a, b) {
      final score = b.score.compareTo(a.score);
      return score != 0 ? score : a.order.compareTo(b.order);
    });
    return [for (final match in matches) match.item];
  }
}

final _separators = RegExp(r'[\s\-_/·,，。:：]+');

String _normalize(String text) => String.fromCharCodes(
  text.runes.map(
    (rune) => rune >= 0xff01 && rune <= 0xff5e ? rune - 0xfee0 : rune,
  ),
).toLowerCase().replaceAll(_separators, ' ').trim();
