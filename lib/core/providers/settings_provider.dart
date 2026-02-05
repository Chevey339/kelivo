import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:socks5_proxy/socks_client.dart' as socks;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'dart:convert';
import '../services/search/search_service.dart';
import '../services/tts/network_tts.dart';
import '../services/network/request_logger.dart';
import '../services/logging/flutter_logger.dart';
import '../models/api_keys.dart';
import '../models/backup.dart';
import '../models/provider_group.dart';
import '../services/haptics.dart';
import '../../utils/app_directories.dart';
import '../../utils/sandbox_path_resolver.dart';
import '../../utils/avatar_cache.dart';
import '../../utils/provider_grouping_logic.dart';

// Desktop: topic list position
enum DesktopTopicPosition { left, right }

// Desktop: send message shortcut
enum DesktopSendShortcut { enter, ctrlEnter }

class SettingsProvider extends ChangeNotifier {
  static const String _providersOrderKey = 'providers_order_v1';
  static const String _providerGroupsKey = 'provider_groups_v1'; // [{id,name,createdAt}]
  static const String _providerGroupMapKey = 'provider_group_map_v1'; // providerKey -> groupId
  static const String _providerGroupCollapsedKey = 'provider_group_collapsed_v1'; // groupId|__ungrouped__ -> bool
  static const String providerUngroupedGroupKey = '__ungrouped__';
  static const List<String> _builtInProviderKeysInOrder = [
    'OpenAI',
    'SiliconFlow',
    'Gemini',
    'OpenRouter',
    'KelivoIN',
    'Tensdaq',
    'DeepSeek',
    'AIhubmix',
    'Aliyun',
    'Zhipu AI',
    'Claude',
    'Grok',
    'ByteDance',
  ];
  static const Set<String> _builtInProviderKeys = {..._builtInProviderKeysInOrder};
  static const String _themeModeKey = 'theme_mode_v1';
  static const String _providerConfigsKey = 'provider_configs_v1';
  static const String _pinnedModelsKey = 'pinned_models_v1';
  static const String _selectedModelKey = 'selected_model_v1';
  static const String _titleModelKey = 'title_model_v1';
  static const String _titlePromptKey = 'title_prompt_v1';
  static const String _ocrModelKey = 'ocr_model_v1';
  static const String _ocrPromptKey = 'ocr_prompt_v1';
  static const String _summaryModelKey = 'summary_model_v1';
  static const String _summaryPromptKey = 'summary_prompt_v1';
  static const String _themePaletteKey = 'theme_palette_v1';
  static const String _useDynamicColorKey = 'use_dynamic_color_v1';
  static const String _thinkingBudgetKey = 'thinking_budget_v1';
  static const String _displayShowUserAvatarKey = 'display_show_user_avatar_v1';
  static const String _displayShowModelIconKey = 'display_show_model_icon_v1';
  static const String _displayShowModelNameTimestampKey = 'display_show_model_name_timestamp_v1';
  static const String _displayShowTokenStatsKey = 'display_show_token_stats_v1';
  static const String _displayShowUserNameTimestampKey = 'display_show_user_name_timestamp_v1';
  static const String _displayShowUserMessageActionsKey = 'display_show_user_message_actions_v1';
  static const String _displayAutoCollapseThinkingKey = 'display_auto_collapse_thinking_v1';
  static const String _displayShowMessageNavKey = 'display_show_message_nav_v1';
  static const String _displayShowProviderInModelCapsuleKey = 'display_show_provider_in_model_capsule_v1';
  static const String _displayHapticsOnGenerateKey = 'display_haptics_on_generate_v1';
  static const String _displayHapticsOnDrawerKey = 'display_haptics_on_drawer_v1';
  static const String _displayHapticsGlobalEnabledKey = 'display_haptics_global_enabled_v1';
  static const String _displayHapticsIosSwitchKey = 'display_haptics_ios_switch_v1';
  static const String _displayHapticsOnListItemTapKey = 'display_haptics_on_list_item_tap_v1';
  static const String _displayHapticsOnCardTapKey = 'display_haptics_on_card_tap_v1';
  static const String _displayShowAppUpdatesKey = 'display_show_app_updates_v1';
  static const String _displayKeepSidebarOpenOnAssistantTapKey = 'display_keep_sidebar_open_on_assistant_tap_v1';
  static const String _displayKeepSidebarOpenOnTopicTapKey = 'display_keep_sidebar_open_on_topic_tap_v1';
  static const String _displayKeepAssistantListExpandedOnSidebarCloseKey = 'display_keep_assistant_list_expanded_on_sidebar_close_v1';
  static const String _displayNewChatOnAssistantSwitchKey = 'display_new_chat_on_assistant_switch_v1';
  static const String _displayNewChatOnLaunchKey = 'display_new_chat_on_launch_v1';
  static const String _displayNewChatAfterDeleteKey = 'display_new_chat_after_delete_v1';
  static const String _displayEnterToSendOnMobileKey = 'display_enter_to_send_on_mobile_v1';
  static const String _desktopSendShortcutKey = 'desktop_send_shortcut_v1';
  static const String _displayChatFontScaleKey = 'display_chat_font_scale_v1';
  static const String _displayAutoScrollEnabledKey = 'display_auto_scroll_enabled_v1';
  static const String _displayAutoScrollIdleSecondsKey = 'display_auto_scroll_idle_seconds_v1';
  static const String _displayChatBackgroundMaskStrengthKey = 'display_chat_background_mask_strength_v1';
  static const String _displayEnableDollarLatexKey = 'display_enable_dollar_latex_v1';
  static const String _displayEnableMathRenderingKey = 'display_enable_math_rendering_v1';
  static const String _displayEnableUserMarkdownKey = 'display_enable_user_markdown_v1';
  static const String _displayEnableReasoningMarkdownKey = 'display_enable_reasoning_markdown_v1';
  static const String _displayShowChatListDateKey = 'display_show_chat_list_date_v1';
  static const String _displayMobileCodeBlockWrapKey = 'display_mobile_code_block_wrap_v1';
  static const String _displayAutoCollapseCodeBlockKey = 'display_auto_collapse_code_block_v1';
  static const String _displayAutoCollapseCodeBlockLinesKey = 'display_auto_collapse_code_block_lines_v1';
  static const String _displayDesktopAutoSwitchTopicsKey = 'display_desktop_auto_switch_topics_v1';
  static const String _displayDesktopShowTrayKey = 'display_desktop_show_tray_v1';
  static const String _displayDesktopMinimizeToTrayOnCloseKey = 'display_desktop_minimize_to_tray_on_close_v1';
  static const String _displayUsePureBackgroundKey = 'display_use_pure_background_v1';
  static const String _displayChatMessageBackgroundStyleKey = 'display_chat_message_background_style_v1';
  // Network request logging (debug)
  static const String _requestLogEnabledKey = 'request_log_enabled_v1';
  // Flutter runtime logging (debug)
  static const String _flutterLogEnabledKey = 'flutter_log_enabled_v1';
  // Desktop topic panel placement + right sidebar open state
  static const String _desktopTopicPositionKey = 'desktop_topic_position_v1';
  static const String _desktopRightSidebarOpenKey = 'desktop_right_sidebar_open_v1';
  // Android background chat generation mode
  static const String _androidBackgroundChatModeKey = 'android_background_chat_mode_v1';
  // Fonts
  static const String _displayAppFontFamilyKey = 'display_app_font_family_v1';
  static const String _displayCodeFontFamilyKey = 'display_code_font_family_v1';
  static const String _displayAppFontIsGoogleKey = 'display_app_font_is_google_v1';
  static const String _displayCodeFontIsGoogleKey = 'display_code_font_is_google_v1';
  static const String _displayAppFontLocalPathKey = 'display_app_font_local_path_v1';
  static const String _displayCodeFontLocalPathKey = 'display_code_font_local_path_v1';
  static const String _displayAppFontLocalAliasKey = 'display_app_font_local_alias_v1';
  static const String _displayCodeFontLocalAliasKey = 'display_code_font_local_alias_v1';
  static const String _appLocaleKey = 'app_locale_v1';
  static const String _translateModelKey = 'translate_model_v1';
  static const String _translatePromptKey = 'translate_prompt_v1';
  static const String _translateTargetLangKey = 'translate_target_lang_v1';
  static const String _ocrEnabledKey = 'ocr_enabled_v1';
  static const String _learningModeEnabledKey = 'learning_mode_enabled_v1';
  static const String _learningModePromptKey = 'learning_mode_prompt_v1';
  static const String _searchServicesKey = 'search_services_v1';
  static const String _searchCommonKey = 'search_common_v1';
  static const String _searchSelectedKey = 'search_selected_v1';
  static const String _searchEnabledKey = 'search_enabled_v1';
  static const String _searchAutoTestOnLaunchKey = 'search_auto_test_on_launch_v1';
  static const String _webDavConfigKey = 'webdav_config_v1';
  // Global network proxy
  static const String _globalProxyEnabledKey = 'global_proxy_enabled_v1';
  static const String _globalProxyTypeKey = 'global_proxy_type_v1'; // http|https|socks5
  static const String _globalProxyHostKey = 'global_proxy_host_v1';
  static const String _globalProxyPortKey = 'global_proxy_port_v1';
  static const String _globalProxyUsernameKey = 'global_proxy_username_v1';
  static const String _globalProxyPasswordKey = 'global_proxy_password_v1';
  static const String _globalProxyBypassKey = 'global_proxy_bypass_v1';
  static const String _defaultGlobalProxyBypassRules =
      'localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,::1';
  // TTS services (network)
  static const String _ttsServicesKey = 'tts_services_v1';
  static const String _ttsSelectedKey = 'tts_selected_v1';
  // Desktop UI
  static const String _desktopSidebarWidthKey = 'desktop_sidebar_width_v1';
  static const String _desktopSidebarOpenKey = 'desktop_sidebar_open_v1';
  static const String _desktopRightSidebarWidthKey = 'desktop_right_sidebar_width_v1';

  // ===== Network TTS services =====
  List<TtsServiceOptions> _ttsServices = const <TtsServiceOptions>[];
  int _ttsServiceSelected = -1; // -1 => use System TTS
  List<TtsServiceOptions> get ttsServices => _ttsServices;
  int get ttsServiceSelected => _ttsServiceSelected;
  bool get usingSystemTts => _ttsServiceSelected < 0;
  TtsServiceOptions? get selectedTtsService => (_ttsServiceSelected >= 0 && _ttsServiceSelected < _ttsServices.length)
      ? _ttsServices[_ttsServiceSelected]
      : null;

  List<String> _providersOrder = const [];
  List<String> get providersOrder => _providersOrder;

  // ===== Provider grouping =====
  List<ProviderGroup> _providerGroups = const <ProviderGroup>[];
  Map<String, String> _providerGroupMap = <String, String>{}; // providerKey -> groupId
  final Map<String, bool> _providerGroupCollapsed = <String, bool>{}; // groupId|__ungrouped__ -> bool

  List<ProviderGroup> get providerGroups => List.unmodifiable(_providerGroups);

  ProviderGroup? groupById(String id) {
    for (final g in _providerGroups) {
      if (g.id == id) return g;
    }
    return null;
  }

  String? groupIdForProvider(String providerKey) {
    final gid = _providerGroupMap[providerKey];
    if (gid == null) return null;
    return groupById(gid) == null ? null : gid;
  }

  bool get providerGroupingActive {
    for (final entry in _providerGroupMap.entries) {
      final gid = entry.value;
      if (groupById(gid) != null) return true;
    }
    return false;
  }

  bool isGroupCollapsed(String groupIdOrUngrouped) => _providerGroupCollapsed[groupIdOrUngrouped] ?? false;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;
  // Theme palette & dynamic color
  String _themePaletteId = 'default';
  String get themePaletteId => _themePaletteId;
  bool _useDynamicColor = true; // when supported on Android
  bool get useDynamicColor => _useDynamicColor;
  bool _dynamicColorSupported = false; // runtime capability, not persisted
  bool get dynamicColorSupported => _dynamicColorSupported;

  // When enabled, force pure white/black backgrounds regardless of theme color
  bool _usePureBackground = false;
  bool get usePureBackground => _usePureBackground;

  // Desktop UI persisted state
  double _desktopSidebarWidth = 240;
  bool _desktopSidebarOpen = true;
  double get desktopSidebarWidth => _desktopSidebarWidth;
  bool get desktopSidebarOpen => _desktopSidebarOpen;
  double _desktopRightSidebarWidth = 300;
  double get desktopRightSidebarWidth => _desktopRightSidebarWidth;

  // Desktop: topic list position (left or right) and right sidebar open state
  DesktopTopicPosition _desktopTopicPosition = DesktopTopicPosition.left;
  DesktopTopicPosition get desktopTopicPosition => _desktopTopicPosition;
  bool get desktopTopicsOnRight => _desktopTopicPosition == DesktopTopicPosition.right;
  bool _desktopRightSidebarOpen = true;
  bool get desktopRightSidebarOpen => _desktopRightSidebarOpen;

  Map<String, ProviderConfig> _providerConfigs = {};
  Map<String, ProviderConfig> get providerConfigs => Map.unmodifiable(_providerConfigs);
  bool get hasAnyActiveModel => _providerConfigs.values.any((c) => c.enabled && c.models.isNotEmpty);
  // Returns a config for the given key without mutating internal state when missing.
  // This avoids implicitly creating providers during read paths (e.g., rendering old chats).
  ProviderConfig getProviderConfig(String key, {String? defaultName}) {
    final existed = _providerConfigs[key];
    if (existed != null) return existed;
    // Return a non-persisted, default-constructed config for read-only scenarios.
    return ProviderConfig.defaultsFor(key, displayName: defaultName);
  }

  // Explicitly ensure a provider config exists in memory (without persisting to storage).
  // Useful for seeding first-run defaults.
  ProviderConfig ensureProviderConfig(String key, {String? defaultName}) {
    final existed = _providerConfigs[key];
    if (existed != null) return existed;
    final cfg = ProviderConfig.defaultsFor(key, displayName: defaultName);
    _providerConfigs[key] = cfg;
    return cfg;
  }

  // Search service settings
  List<SearchServiceOptions> _searchServices = [SearchServiceOptions.defaultOption];
  List<SearchServiceOptions> get searchServices => List.unmodifiable(_searchServices);
  SearchCommonOptions _searchCommonOptions = const SearchCommonOptions();
  SearchCommonOptions get searchCommonOptions => _searchCommonOptions;
  int _searchServiceSelected = 0;
  int get searchServiceSelected => _searchServiceSelected;
  bool _searchEnabled = false;
  bool get searchEnabled => _searchEnabled;
  bool _searchAutoTestOnLaunch = false;
  bool get searchAutoTestOnLaunch => _searchAutoTestOnLaunch;
  // Ephemeral connection test results: serviceId -> connected (true), failed (false), or null (not tested)
  final Map<String, bool?> _searchConnection = <String, bool?>{};
  Map<String, bool?> get searchConnection => Map.unmodifiable(_searchConnection);

  // ===== Global Proxy Settings =====
  bool _globalProxyEnabled = false;
  String _globalProxyType = 'http';
  String _globalProxyHost = '';
  String _globalProxyPort = '8080';
  String _globalProxyUsername = '';
  String _globalProxyPassword = '';
  String _globalProxyBypass = _defaultGlobalProxyBypassRules;

  bool get globalProxyEnabled => _globalProxyEnabled;
  String get globalProxyType => _globalProxyType; // http|https|socks5
  String get globalProxyHost => _globalProxyHost;
  String get globalProxyPort => _globalProxyPort;
  String get globalProxyUsername => _globalProxyUsername;
  String get globalProxyPassword => _globalProxyPassword;
  String get globalProxyBypass => _globalProxyBypass;

  SettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _providersOrder = prefs.getStringList(_providersOrderKey) ?? [];
    final m = prefs.getString(_themeModeKey);
    switch (m) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'dark':
        _themeMode = ThemeMode.dark;
        break;
      default:
        _themeMode = ThemeMode.system;
    }
    _themePaletteId = prefs.getString(_themePaletteKey) ?? 'default';
    _useDynamicColor = prefs.getBool(_useDynamicColorKey) ?? true;
    final cfgStr = prefs.getString(_providerConfigsKey);
    if (cfgStr != null && cfgStr.isNotEmpty) {
      try {
        final raw = jsonDecode(cfgStr) as Map<String, dynamic>;
        _providerConfigs = raw.map((k, v) => MapEntry(k, ProviderConfig.fromJson(v as Map<String, dynamic>)));
      } catch (_) {}
    }

    // load provider grouping
    try {
      final groupsStr = prefs.getString(_providerGroupsKey) ?? '';
      _providerGroups = groupsStr.isEmpty ? const <ProviderGroup>[] : ProviderGroup.decodeList(groupsStr);
    } catch (_) {
      _providerGroups = const <ProviderGroup>[];
    }
    try {
      final mapStr = prefs.getString(_providerGroupMapKey) ?? '';
      if (mapStr.isNotEmpty) {
        final raw = jsonDecode(mapStr) as Map<String, dynamic>;
        _providerGroupMap = raw.map((k, v) => MapEntry(k, v.toString()));
      } else {
        _providerGroupMap = <String, String>{};
      }
    } catch (_) {
      _providerGroupMap = <String, String>{};
    }
    try {
      final collapsedStr = prefs.getString(_providerGroupCollapsedKey) ?? '';
      if (collapsedStr.isNotEmpty) {
        final raw = jsonDecode(collapsedStr) as Map<String, dynamic>;
        _providerGroupCollapsed
          ..clear()
          ..addAll(raw.map((k, v) => MapEntry(k, (v is bool) ? v : (v.toString() == 'true'))));
      } else {
        _providerGroupCollapsed.clear();
      }
    } catch (_) {
      _providerGroupCollapsed.clear();
    }
    // load pinned models
    final pinned = prefs.getStringList(_pinnedModelsKey) ?? const <String>[];
    _pinnedModels
      ..clear()
      ..addAll(pinned);
    // load selected model
    final sel = prefs.getString(_selectedModelKey);
    if (sel != null && sel.contains('::')) {
      final parts = sel.split('::');
      if (parts.length >= 2) {
        _currentModelProvider = parts[0];
        _currentModelId = parts.sublist(1).join('::');
      }
    }
    // load title model
    final titleSel = prefs.getString(_titleModelKey);
    if (titleSel != null && titleSel.contains('::')) {
      final parts = titleSel.split('::');
      if (parts.length >= 2) {
        _titleModelProvider = parts[0];
        _titleModelId = parts.sublist(1).join('::');
      }
    }
    // load title prompt
    final tp = prefs.getString(_titlePromptKey);
    _titlePrompt = (tp == null || tp.trim().isEmpty) ? defaultTitlePrompt : tp;
    // load translate model
    final translateSel = prefs.getString(_translateModelKey);
    if (translateSel != null && translateSel.contains('::')) {
      final parts = translateSel.split('::');
      if (parts.length >= 2) {
        _translateModelProvider = parts[0];
        _translateModelId = parts.sublist(1).join('::');
      }
    }
    // load translate prompt
    final transp = prefs.getString(_translatePromptKey);
    _translatePrompt = (transp == null || transp.trim().isEmpty) ? defaultTranslatePrompt : transp;
    // load translate target language
    final targetLang = prefs.getString(_translateTargetLangKey);
    if (targetLang != null && targetLang.trim().isNotEmpty) {
      _translateTargetLang = targetLang.trim();
    }
    // load OCR model
    final ocrSel = prefs.getString(_ocrModelKey);
    if (ocrSel != null && ocrSel.contains('::')) {
      final parts = ocrSel.split('::');
      if (parts.length >= 2) {
        _ocrModelProvider = parts[0];
        _ocrModelId = parts.sublist(1).join('::');
      }
    }
    // load OCR prompt
    final ocrp = prefs.getString(_ocrPromptKey);
    _ocrPrompt = (ocrp == null || ocrp.trim().isEmpty) ? defaultOcrPrompt : ocrp;
    // load OCR enabled (only effective when model is configured)
    _ocrEnabled = prefs.getBool(_ocrEnabledKey) ?? false;
    if (_ocrModelProvider == null || _ocrModelId == null) {
      _ocrEnabled = false;
    }
    // load summary model
    final summarySel = prefs.getString(_summaryModelKey);
    if (summarySel != null && summarySel.contains('::')) {
      final parts = summarySel.split('::');
      if (parts.length >= 2) {
        _summaryModelProvider = parts[0];
        _summaryModelId = parts.sublist(1).join('::');
      }
    }
    // load summary prompt
    final summaryp = prefs.getString(_summaryPromptKey);
    _summaryPrompt =
        (summaryp == null || summaryp.trim().isEmpty) ? defaultSummaryPrompt : summaryp;
    // learning mode
    _learningModeEnabled = prefs.getBool(_learningModeEnabledKey) ?? false;
    final lmp = prefs.getString(_learningModePromptKey);
    _learningModePrompt = (lmp == null || lmp.trim().isEmpty) ? defaultLearningModePrompt : lmp;
    // load thinking budget (reasoning strength)
    _thinkingBudget = prefs.getInt(_thinkingBudgetKey);

    // display settings
    _showUserAvatar = prefs.getBool(_displayShowUserAvatarKey) ?? true;
    _showModelIcon = prefs.getBool(_displayShowModelIconKey) ?? true;
    _showModelNameTimestamp = prefs.getBool(_displayShowModelNameTimestampKey) ?? true;
    _showTokenStats = prefs.getBool(_displayShowTokenStatsKey) ?? true;
    _showUserNameTimestamp = prefs.getBool(_displayShowUserNameTimestampKey) ?? true;
    _showUserMessageActions = prefs.getBool(_displayShowUserMessageActionsKey) ?? true;
    _autoCollapseThinking = prefs.getBool(_displayAutoCollapseThinkingKey) ?? true;
    _showMessageNavButtons = prefs.getBool(_displayShowMessageNavKey) ?? true;
    _showProviderInModelCapsule = prefs.getBool(_displayShowProviderInModelCapsuleKey) ?? true;
    _hapticsOnGenerate = prefs.getBool(_displayHapticsOnGenerateKey) ?? false;
    _hapticsOnDrawer = prefs.getBool(_displayHapticsOnDrawerKey) ?? true;
    _hapticsGlobalEnabled = prefs.getBool(_displayHapticsGlobalEnabledKey) ?? true;
    _hapticsIosSwitch = prefs.getBool(_displayHapticsIosSwitchKey) ?? true;
    _hapticsOnListItemTap = prefs.getBool(_displayHapticsOnListItemTapKey) ?? true;
    _hapticsOnCardTap = prefs.getBool(_displayHapticsOnCardTapKey) ?? true;
    // Apply global haptics to service layer
    Haptics.setEnabled(_hapticsGlobalEnabled);
    _showAppUpdates = prefs.getBool(_displayShowAppUpdatesKey) ?? true;
    _keepSidebarOpenOnAssistantTap = prefs.getBool(_displayKeepSidebarOpenOnAssistantTapKey) ?? false;
    _keepSidebarOpenOnTopicTap = prefs.getBool(_displayKeepSidebarOpenOnTopicTapKey) ?? false;
    _keepAssistantListExpandedOnSidebarClose = prefs.getBool(_displayKeepAssistantListExpandedOnSidebarCloseKey) ?? false;
    _requestLogEnabled = prefs.getBool(_requestLogEnabledKey) ?? false;
    await RequestLogger.setEnabled(_requestLogEnabled);
    _flutterLogEnabled = prefs.getBool(_flutterLogEnabledKey) ?? false;
    await FlutterLogger.setEnabled(_flutterLogEnabled);
    _newChatOnLaunch = prefs.getBool(_displayNewChatOnLaunchKey) ?? true;
    _newChatOnAssistantSwitch = prefs.getBool(_displayNewChatOnAssistantSwitchKey) ?? false;
    _newChatAfterDelete = prefs.getBool(_displayNewChatAfterDeleteKey) ?? false;
    // Enter to send on mobile: iOS defaults to true, Android defaults to false
    final enterToSendPref = prefs.getBool(_displayEnterToSendOnMobileKey);
    if (enterToSendPref == null) {
      _enterToSendOnMobile = Platform.isIOS;
      await prefs.setBool(_displayEnterToSendOnMobileKey, _enterToSendOnMobile);
    } else {
      _enterToSendOnMobile = enterToSendPref;
    }
    // Desktop send shortcut: Enter (default) or Ctrl/Cmd+Enter
    final sendShortcutStr = prefs.getString(_desktopSendShortcutKey);
    switch (sendShortcutStr) {
      case 'ctrlEnter':
        _desktopSendShortcut = DesktopSendShortcut.ctrlEnter;
        break;
      case 'enter':
      default:
        _desktopSendShortcut = DesktopSendShortcut.enter;
    }
    _chatFontScale = prefs.getDouble(_displayChatFontScaleKey) ?? 1.0;
    _autoScrollEnabled = prefs.getBool(_displayAutoScrollEnabledKey) ?? true;
    _autoScrollIdleSeconds = prefs.getInt(_displayAutoScrollIdleSecondsKey) ?? 8;
    _chatBackgroundMaskStrength = prefs.getDouble(_displayChatBackgroundMaskStrengthKey) ?? 1.0;
    final pureBgPref = prefs.getBool(_displayUsePureBackgroundKey);
    if (pureBgPref == null) {
      final isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;
      _usePureBackground = isDesktop;
      await prefs.setBool(_displayUsePureBackgroundKey, _usePureBackground);
    } else {
      _usePureBackground = pureBgPref;
    }
    // display: markdown/math rendering
    _enableDollarLatex = prefs.getBool(_displayEnableDollarLatexKey) ?? true;
    _enableMathRendering = prefs.getBool(_displayEnableMathRenderingKey) ?? true;
    _enableUserMarkdown = prefs.getBool(_displayEnableUserMarkdownKey) ?? true;
    _enableReasoningMarkdown = prefs.getBool(_displayEnableReasoningMarkdownKey) ?? true;
    _showChatListDate = prefs.getBool(_displayShowChatListDateKey) ?? false;
    _mobileCodeBlockWrap = prefs.getBool(_displayMobileCodeBlockWrapKey) ?? false;
    _autoCollapseCodeBlock = prefs.getBool(_displayAutoCollapseCodeBlockKey) ?? false;
    _autoCollapseCodeBlockLines =
        (prefs.getInt(_displayAutoCollapseCodeBlockLinesKey) ?? 2).clamp(1, 999);
    _desktopAutoSwitchTopics = prefs.getBool(_displayDesktopAutoSwitchTopicsKey) ?? false;
    // Desktop: tray settings (default enabled on desktop platforms)
    final trayPref = prefs.getBool(_displayDesktopShowTrayKey);
    if (trayPref == null) {
      final isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;
      _desktopShowTray = isDesktop;
      await prefs.setBool(_displayDesktopShowTrayKey, _desktopShowTray);
    } else {
      _desktopShowTray = trayPref;
    }
    final minimizeTrayPref = prefs.getBool(_displayDesktopMinimizeToTrayOnCloseKey);
    if (minimizeTrayPref == null) {
      _desktopMinimizeToTrayOnClose = _desktopShowTray;
      await prefs.setBool(_displayDesktopMinimizeToTrayOnCloseKey, _desktopMinimizeToTrayOnClose);
    } else {
      // Enforce invariant: cannot minimize to tray if tray is hidden.
      _desktopMinimizeToTrayOnClose = minimizeTrayPref && _desktopShowTray;
      if (minimizeTrayPref && !_desktopShowTray) {
        await prefs.setBool(_displayDesktopMinimizeToTrayOnCloseKey, _desktopMinimizeToTrayOnClose);
      }
    }
    // desktop: topic panel placement + right sidebar open state
    final topicPos = prefs.getString(_desktopTopicPositionKey);
    switch (topicPos) {
      case 'right':
        _desktopTopicPosition = DesktopTopicPosition.right;
        break;
      case 'left':
      default:
        _desktopTopicPosition = DesktopTopicPosition.left;
    }
    _desktopRightSidebarOpen = prefs.getBool(_desktopRightSidebarOpenKey) ?? true;
    // Chat message background style (default | frosted | solid)
    final bgStyleStr = prefs.getString(_displayChatMessageBackgroundStyleKey) ?? 'default';
    switch (bgStyleStr) {
      case 'frosted':
        _chatMessageBackgroundStyle = ChatMessageBackgroundStyle.frosted;
        break;
      case 'solid':
        _chatMessageBackgroundStyle = ChatMessageBackgroundStyle.solid;
        break;
      default:
        _chatMessageBackgroundStyle = ChatMessageBackgroundStyle.defaultStyle;
    }
    // desktop UI
    _desktopSidebarWidth = prefs.getDouble(_desktopSidebarWidthKey) ?? 300;
    _desktopSidebarOpen = prefs.getBool(_desktopSidebarOpenKey) ?? true;
    _desktopRightSidebarWidth = prefs.getDouble(_desktopRightSidebarWidthKey) ?? 300;
    // Load app locale; default to follow system on first launch
    _appLocaleTag = prefs.getString(_appLocaleKey);
    if (_appLocaleTag == null || _appLocaleTag!.isEmpty) {
      _appLocaleTag = 'system';
      await prefs.setString(_appLocaleKey, 'system');
    }

    // Android background chat mode (Android only; default ON on first run)
    try {
      final rawBg = prefs.getString(_androidBackgroundChatModeKey);
      if (rawBg == null) {
        // Default to OFF to avoid permission prompts on first launch
        _androidBackgroundChatMode = AndroidBackgroundChatMode.off;
        await prefs.setString(_androidBackgroundChatModeKey, 'off');
      } else {
        switch (rawBg) {
          case 'on_notify':
            _androidBackgroundChatMode = AndroidBackgroundChatMode.onNotify;
            break;
          case 'on':
            _androidBackgroundChatMode = AndroidBackgroundChatMode.on;
            break;
          case 'off':
          default:
            _androidBackgroundChatMode = AndroidBackgroundChatMode.off;
        }
      }
    } catch (_) {
      _androidBackgroundChatMode = AndroidBackgroundChatMode.off;
    }
    
    // load search settings
    final searchServicesStr = prefs.getString(_searchServicesKey);
    if (searchServicesStr != null && searchServicesStr.isNotEmpty) {
      try {
        final list = jsonDecode(searchServicesStr) as List;
        _searchServices = list.map((e) => SearchServiceOptions.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }
    final searchCommonStr = prefs.getString(_searchCommonKey);
    if (searchCommonStr != null && searchCommonStr.isNotEmpty) {
      try {
        _searchCommonOptions = SearchCommonOptions.fromJson(jsonDecode(searchCommonStr) as Map<String, dynamic>);
      } catch (_) {}
    }
    _searchServiceSelected = prefs.getInt(_searchSelectedKey) ?? 0;
    _searchEnabled = prefs.getBool(_searchEnabledKey) ?? false;
    _searchAutoTestOnLaunch = prefs.getBool(_searchAutoTestOnLaunchKey) ?? false;

    // load global proxy
    _globalProxyEnabled = prefs.getBool(_globalProxyEnabledKey) ?? false;
    _globalProxyType = prefs.getString(_globalProxyTypeKey) ?? 'http';
    _globalProxyHost = prefs.getString(_globalProxyHostKey) ?? '';
    _globalProxyPort = prefs.getString(_globalProxyPortKey) ?? '8080';
    _globalProxyUsername = prefs.getString(_globalProxyUsernameKey) ?? '';
    _globalProxyPassword = prefs.getString(_globalProxyPasswordKey) ?? '';
    final bypass = prefs.getString(_globalProxyBypassKey);
    if (bypass == null) {
      _globalProxyBypass = _defaultGlobalProxyBypassRules;
      await prefs.setString(_globalProxyBypassKey, _globalProxyBypass);
    } else {
      _globalProxyBypass = bypass;
    }

    // load network TTS services
    try {
      final ttsStr = prefs.getString(_ttsServicesKey) ?? '';
      if (ttsStr.isNotEmpty) {
        final list = jsonDecode(ttsStr) as List;
        _ttsServices = [
          for (final e in list)
            if (e is Map<String, dynamic>) TtsServiceOptions.fromJson(e) else TtsServiceOptions.fromJson(Map<String, dynamic>.from(e as Map))
        ];
      } else {
        _ttsServices = const <TtsServiceOptions>[];
      }
    } catch (_) {
      _ttsServices = const <TtsServiceOptions>[];
    }
    _ttsServiceSelected = prefs.getInt(_ttsSelectedKey) ?? -1;
    if (_ttsServiceSelected >= _ttsServices.length) {
      _ttsServiceSelected = _ttsServices.isEmpty ? -1 : 0;
      await prefs.setInt(_ttsSelectedKey, _ttsServiceSelected);
    }
    // webdav config
    final webdavStr = prefs.getString(_webDavConfigKey);
    if (webdavStr != null && webdavStr.isNotEmpty) {
      try { _webDavConfig = WebDavConfig.fromJson(jsonDecode(webdavStr) as Map<String, dynamic>); } catch (_) {}
    }
    if (_providerConfigs.isEmpty) {
      // Seed a couple of sensible defaults on first launch, but do not recreate
      // providers implicitly during later reads (e.g., when switching chats).
      ensureProviderConfig('KelivoIN', defaultName: 'KelivoIN');
      ensureProviderConfig('Tensdaq', defaultName: 'Tensdaq');
      ensureProviderConfig('SiliconFlow', defaultName: 'SiliconFlow');
      ensureProviderConfig('AIhubmix', defaultName: 'AIhubmix');
    }
    
    // kick off a one-time connectivity test for services (exclude local Bing)
    if (_searchAutoTestOnLaunch) {
      _initSearchConnectivityTests();
    }

    // Attempt to reload any user-installed local fonts (mobile platforms)
    await _reloadLocalFontsIfAny();

    // Final cleanup pass for provider order + grouping state (best-effort).
    if (_cleanupProviderOrderAndGrouping()) {
      try {
        await prefs.setStringList(_providersOrderKey, _providersOrder);
        await prefs.setString(_providerGroupMapKey, jsonEncode(_providerGroupMap));
        await prefs.setString(_providerGroupCollapsedKey, jsonEncode(_providerGroupCollapsed));
      } catch (_) {}
    }

    notifyListeners();
  }

  Future<void> setGlobalProxyEnabled(bool v) async {
    _globalProxyEnabled = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_globalProxyEnabledKey, _globalProxyEnabled);
  }

  Future<void> setGlobalProxyType(String v) async {
    _globalProxyType = v.trim().isEmpty ? 'http' : v.trim();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_globalProxyTypeKey, _globalProxyType);
  }

  Future<void> setGlobalProxyHost(String v) async {
    _globalProxyHost = v.trim();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_globalProxyHostKey, _globalProxyHost);
  }

  Future<void> setGlobalProxyPort(String v) async {
    _globalProxyPort = v.trim();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_globalProxyPortKey, _globalProxyPort);
  }

  Future<void> setGlobalProxyUsername(String v) async {
    _globalProxyUsername = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_globalProxyUsernameKey, _globalProxyUsername);
  }

  Future<void> setGlobalProxyPassword(String v) async {
    _globalProxyPassword = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_globalProxyPasswordKey, _globalProxyPassword);
  }

  Future<void> setGlobalProxyBypass(String v) async {
    _globalProxyBypass = v.trim();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_globalProxyBypassKey, _globalProxyBypass);
  }

  // Apply global proxy to Dart IO layer; provider-level proxies take precedence at call sites.
  String _lastProxySignature = '';
  void applyGlobalProxyOverridesIfNeeded() {
    try {
      final enabled = _globalProxyEnabled;
      final host = _globalProxyHost.trim();
      final portStr = _globalProxyPort.trim();
      final user = _globalProxyUsername.trim();
      final pass = _globalProxyPassword;
      final type = _globalProxyType;
      final bypass = _globalProxyBypass;
      final sig = [enabled, type, host, portStr, user, pass, bypass].join('|');
      if (_lastProxySignature == sig) return;
      _lastProxySignature = sig;
      if (!enabled || host.isEmpty || portStr.isEmpty) {
        HttpOverrides.global = null;
        return;
      }
      final port = int.tryParse(portStr) ?? 8080;
      if (type == 'socks5') {
        HttpOverrides.global = _SocksProxyHttpOverrides(
          host: host,
          port: port,
          username: user.isEmpty ? null : user,
          password: pass,
          bypassRules: bypass,
        );
      } else {
        HttpOverrides.global = _ProxyHttpOverrides(
          host: host,
          port: port,
          username: user.isEmpty ? null : user,
          password: pass,
          bypassRules: bypass,
        );
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> setTtsServices(List<TtsServiceOptions> v) async {
    _ttsServices = List.unmodifiable(v);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final list = v.map((e) => e.toJson()).toList();
    await prefs.setString(_ttsServicesKey, jsonEncode(list));
    if (_ttsServiceSelected >= _ttsServices.length) {
      _ttsServiceSelected = _ttsServices.isEmpty ? -1 : 0;
      await prefs.setInt(_ttsSelectedKey, _ttsServiceSelected);
    }
  }

  Future<void> setTtsServiceSelected(int index) async {
    _ttsServiceSelected = index;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_ttsSelectedKey, _ttsServiceSelected);
  }

  // ===== User Font Settings =====
  String? _appFontFamily; // system or Google font family to use globally
  String? _codeFontFamily; // system or Google font family to use for code blocks
  // Whether the above family names refer to Google Fonts (as opposed to system fonts)
  bool _appFontIsGoogle = false;
  bool _codeFontIsGoogle = false;
  // Local font file selections (mobile): persisted for reload
  String? _appFontLocalPath;
  String? _codeFontLocalPath;
  // The alias family name registered via FontLoader for local fonts
  String? _appFontLocalAlias;
  String? _codeFontLocalAlias;

  String? get appFontFamily => _effectiveAppFontAlias ?? _appFontFamily;
  String? get codeFontFamily => _effectiveCodeFontAlias ?? _codeFontFamily;
  bool get appFontIsGoogle => _appFontIsGoogle;
  bool get codeFontIsGoogle => _codeFontIsGoogle;
  String? get appFontLocalAlias => _appFontLocalAlias;
  String? get codeFontLocalAlias => _codeFontLocalAlias;

  // Use alias if a local font is set and successfully registered
  String? get _effectiveAppFontAlias => (_appFontLocalAlias?.isNotEmpty == true) ? _appFontLocalAlias : null;
  String? get _effectiveCodeFontAlias => (_codeFontLocalAlias?.isNotEmpty == true) ? _codeFontLocalAlias : null;

  Future<void> setAppFontSystemFamily(String? family) async {
    _appFontIsGoogle = false;
    _appFontFamily = (family == null || family.trim().isEmpty) ? null : family.trim();
    // Clear local alias for system/google switch
    _appFontLocalAlias = null;
    _appFontLocalPath = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_displayAppFontFamilyKey, _appFontFamily ?? '');
    await prefs.setBool(_displayAppFontIsGoogleKey, _appFontIsGoogle);
    await prefs.remove(_displayAppFontLocalAliasKey);
    await prefs.remove(_displayAppFontLocalPathKey);
  }

  Future<void> setCodeFontSystemFamily(String? family) async {
    _codeFontIsGoogle = false;
    _codeFontFamily = (family == null || family.trim().isEmpty) ? null : family.trim();
    _codeFontLocalAlias = null;
    _codeFontLocalPath = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_displayCodeFontFamilyKey, _codeFontFamily ?? '');
    await prefs.setBool(_displayCodeFontIsGoogleKey, _codeFontIsGoogle);
    await prefs.remove(_displayCodeFontLocalAliasKey);
    await prefs.remove(_displayCodeFontLocalPathKey);
  }

  Future<void> setAppFontFromGoogle(String family) async {
    _appFontIsGoogle = true;
    _appFontFamily = family.trim();
    _appFontLocalAlias = null;
    _appFontLocalPath = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_displayAppFontFamilyKey, _appFontFamily!);
    await prefs.setBool(_displayAppFontIsGoogleKey, true);
    await prefs.remove(_displayAppFontLocalAliasKey);
    await prefs.remove(_displayAppFontLocalPathKey);
  }

  Future<void> setCodeFontFromGoogle(String family) async {
    _codeFontIsGoogle = true;
    _codeFontFamily = family.trim();
    _codeFontLocalAlias = null;
    _codeFontLocalPath = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_displayCodeFontFamilyKey, _codeFontFamily!);
    await prefs.setBool(_displayCodeFontIsGoogleKey, true);
    await prefs.remove(_displayCodeFontLocalAliasKey);
    await prefs.remove(_displayCodeFontLocalPathKey);
  }

  Future<void> setAppFontFromLocal({required String path, String? alias}) async {
    final fam = await _registerLocalFont(path: path, aliasPrefix: alias ?? 'kelivo_local_app');
    if (fam == null) return;
    _appFontIsGoogle = false;
    _appFontFamily = fam;
    _appFontLocalAlias = fam;
    _appFontLocalPath = path;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_displayAppFontFamilyKey, _appFontFamily!);
    await prefs.setBool(_displayAppFontIsGoogleKey, false);
    await prefs.setString(_displayAppFontLocalAliasKey, _appFontLocalAlias!);
    await prefs.setString(_displayAppFontLocalPathKey, _appFontLocalPath!);
  }

  Future<void> setCodeFontFromLocal({required String path, String? alias}) async {
    final fam = await _registerLocalFont(path: path, aliasPrefix: alias ?? 'kelivo_local_code');
    if (fam == null) return;
    _codeFontIsGoogle = false;
    _codeFontFamily = fam;
    _codeFontLocalAlias = fam;
    _codeFontLocalPath = path;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_displayCodeFontFamilyKey, _codeFontFamily!);
    await prefs.setBool(_displayCodeFontIsGoogleKey, false);
    await prefs.setString(_displayCodeFontLocalAliasKey, _codeFontLocalAlias!);
    await prefs.setString(_displayCodeFontLocalPathKey, _codeFontLocalPath!);
  }

  Future<void> clearAppFont() async {
    _appFontFamily = null;
    _appFontIsGoogle = false;
    _appFontLocalAlias = null;
    _appFontLocalPath = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_displayAppFontFamilyKey);
    await prefs.remove(_displayAppFontIsGoogleKey);
    await prefs.remove(_displayAppFontLocalAliasKey);
    await prefs.remove(_displayAppFontLocalPathKey);
  }

  Future<void> clearCodeFont() async {
    _codeFontFamily = null;
    _codeFontIsGoogle = false;
    _codeFontLocalAlias = null;
    _codeFontLocalPath = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_displayCodeFontFamilyKey);
    await prefs.remove(_displayCodeFontIsGoogleKey);
    await prefs.remove(_displayCodeFontLocalAliasKey);
    await prefs.remove(_displayCodeFontLocalPathKey);
  }

  Future<void> _reloadLocalFontsIfAny() async {
    final prefs = await SharedPreferences.getInstance();
    // Load persisted values
    _appFontFamily = _nonEmpty(prefs.getString(_displayAppFontFamilyKey));
    _codeFontFamily = _nonEmpty(prefs.getString(_displayCodeFontFamilyKey));
    _appFontIsGoogle = prefs.getBool(_displayAppFontIsGoogleKey) ?? false;
    _codeFontIsGoogle = prefs.getBool(_displayCodeFontIsGoogleKey) ?? false;
    _appFontLocalPath = _nonEmpty(prefs.getString(_displayAppFontLocalPathKey));
    _codeFontLocalPath = _nonEmpty(prefs.getString(_displayCodeFontLocalPathKey));
    _appFontLocalAlias = _nonEmpty(prefs.getString(_displayAppFontLocalAliasKey));
    _codeFontLocalAlias = _nonEmpty(prefs.getString(_displayCodeFontLocalAliasKey));

    // Re-register local fonts if paths are available (best effort)
    if (_appFontLocalPath != null && _appFontLocalPath!.isNotEmpty) {
      final alias = _appFontLocalAlias ?? 'kelivo_local_app';
      final fam = await _registerLocalFont(path: _appFontLocalPath!, aliasPrefix: alias);
      if (fam != null) {
        _appFontLocalAlias = fam;
        _appFontFamily = fam;
      }
    }
    if (_codeFontLocalPath != null && _codeFontLocalPath!.isNotEmpty) {
      final alias = _codeFontLocalAlias ?? 'kelivo_local_code';
      final fam = await _registerLocalFont(path: _codeFontLocalPath!, aliasPrefix: alias);
      if (fam != null) {
        _codeFontLocalAlias = fam;
        _codeFontFamily = fam;
      }
    }
  }

  String? _nonEmpty(String? s) => (s == null || s.isEmpty) ? null : s;

  Future<String?> _registerLocalFont({required String path, required String aliasPrefix}) async {
    try {
      // Use a stable alias derived from file name to reduce duplicates
      final ts = DateTime.now().millisecondsSinceEpoch;
      final alias = '${aliasPrefix}_$ts';
      final file = File(path);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      final bd = bytes.buffer.asByteData();
      final loader = FontLoader(alias);
      loader.addFont(Future.value(bd));
      await loader.load();
      return alias;
    } catch (_) {
      return null;
    }
  }

  // ===== Desktop UI setters =====
  Future<void> setDesktopSidebarWidth(double width) async {
    final w = width.clamp(200.0, 640.0).toDouble();
    if ((w - _desktopSidebarWidth).abs() < 0.5) return;
    _desktopSidebarWidth = w;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_desktopSidebarWidthKey, _desktopSidebarWidth);
  }

  Future<void> setDesktopSidebarOpen(bool open) async {
    if (_desktopSidebarOpen == open) return;
    _desktopSidebarOpen = open;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_desktopSidebarOpenKey, _desktopSidebarOpen);
  }

  Future<void> setDesktopRightSidebarWidth(double w) async {
    if ((_desktopRightSidebarWidth - w).abs() < 0.5) return;
    _desktopRightSidebarWidth = w;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_desktopRightSidebarWidthKey, _desktopRightSidebarWidth);
  }

  // Desktop: topic panel placement (left/right)
  Future<void> setDesktopTopicPosition(DesktopTopicPosition pos) async {
    if (_desktopTopicPosition == pos) return;
    _desktopTopicPosition = pos;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final v = (pos == DesktopTopicPosition.right) ? 'right' : 'left';
    await prefs.setString(_desktopTopicPositionKey, v);
  }

  // Desktop: right sidebar visible state
  Future<void> setDesktopRightSidebarOpen(bool open) async {
    if (_desktopRightSidebarOpen == open) return;
    _desktopRightSidebarOpen = open;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_desktopRightSidebarOpenKey, _desktopRightSidebarOpen);
  }

  // ===== App locale (UI language) =====
  String? _appLocaleTag; // 'system', 'zh_CN', 'zh_Hant', 'en_US'
  Locale get appLocale => _parseLocaleTag(_appLocaleTag ?? 'en_US');
  bool get isFollowingSystemLocale => (_appLocaleTag == null) || (_appLocaleTag == 'system');
  Locale? get appLocaleForMaterialApp => isFollowingSystemLocale ? null : appLocale;
  Future<void> setAppLocale(Locale locale) async {
    final tag = _localeToTag(locale);
    if (_appLocaleTag == tag) return;
    _appLocaleTag = tag;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appLocaleKey, _appLocaleTag!);
  }

  Future<void> setAppLocaleFollowSystem() async {
    if (_appLocaleTag == 'system') return;
    _appLocaleTag = 'system';
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appLocaleKey, 'system');
  }

  // Supported locales mapping
  String _mapDeviceLocaleToSupportedTag(Locale device) {
    final lc = (device.languageCode).toLowerCase();
    final region = (device.countryCode ?? '').toUpperCase();
    final script = (device.scriptCode ?? '').toLowerCase();
    if (lc == 'zh') {
      // Map Traditional Chinese by script or common regions
      if (script == 'hant' || region == 'TW' || region == 'HK' || region == 'MO') {
        return 'zh_Hant';
      }
      return 'zh_CN';
    }
    return 'en_US';
  }

  String _localeToTag(Locale l) {
    final lc = l.languageCode.toLowerCase();
    if (lc == 'zh') {
      final script = (l.scriptCode ?? '').toLowerCase();
      if (script == 'hant') return 'zh_Hant';
      return 'zh_CN';
    }
    return 'en_US';
  }

  Locale _parseLocaleTag(String tag) {
    switch (tag) {
      case 'zh_CN':
        return const Locale('zh', 'CN');
      case 'zh_Hant':
        return const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
      case 'en_US':
      default:
        return const Locale('en', 'US');
    }
  }

  // ===== Backup & WebDAV settings =====
  WebDavConfig _webDavConfig = const WebDavConfig();
  WebDavConfig get webDavConfig => _webDavConfig;
  Future<void> setWebDavConfig(WebDavConfig cfg) async {
    _webDavConfig = cfg;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_webDavConfigKey, jsonEncode(cfg.toJson()));
  }

  Future<void> _initSearchConnectivityTests() async {
    final services = List<SearchServiceOptions>.from(_searchServices);
    final common = _searchCommonOptions;
    for (final s in services) {
      if (s is BingLocalOptions) {
        _searchConnection[s.id] = null; // no label for local Bing
        continue;
      }
      // Run in background; don't await all
      unawaited(_testSingleSearchService(s, common));
    }
  }

  Future<void> _testSingleSearchService(SearchServiceOptions s, SearchCommonOptions common) async {
    try {
      final svc = SearchService.getService(s);
      await svc.search(query: 'connectivity test', commonOptions: common, serviceOptions: s);
      _searchConnection[s.id] = true;
    } catch (_) {
      _searchConnection[s.id] = false;
    }
    notifyListeners();
  }

  void setSearchConnection(String id, bool? value) {
    _searchConnection[id] = value;
    notifyListeners();
  }

  Future<void> setProvidersOrder(List<String> order) async {
    _providersOrder = List.unmodifiable(order);
    _cleanupProviderOrderAndGrouping();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_providersOrderKey, _providersOrder);
  }

  Set<String> _knownProviderKeys() => <String>{
        ..._builtInProviderKeys,
        ..._providerConfigs.keys,
      };

  bool _cleanupProviderOrderAndGrouping() {
    bool changed = false;
    final knownKeys = _knownProviderKeys();

    // Clean providers order: remove non-existing and dedupe, append new at end.
    final nextOrder = <String>[];
    final seen = <String>{};
    for (final k in _providersOrder) {
      if (!knownKeys.contains(k)) {
        changed = true;
        continue;
      }
      if (!seen.add(k)) {
        changed = true;
        continue;
      }
      nextOrder.add(k);
    }
    final mergedDefault = <String>[
      ..._builtInProviderKeysInOrder,
      ..._providerConfigs.keys.where((k) => !_builtInProviderKeys.contains(k)),
    ];
    for (final k in mergedDefault) {
      if (knownKeys.contains(k) && seen.add(k)) {
        nextOrder.add(k);
        changed = true;
      }
    }
    if (!listEquals(_providersOrder, nextOrder)) {
      _providersOrder = List.unmodifiable(nextOrder);
      changed = true;
    }

    // Clean group map: remove invalid groupIds or non-existing provider keys.
    final validGroupIds = {for (final g in _providerGroups) g.id};
    final nextMap = <String, String>{};
    for (final entry in _providerGroupMap.entries) {
      final providerKey = entry.key;
      final groupId = entry.value;
      if (!knownKeys.contains(providerKey)) {
        changed = true;
        continue;
      }
      if (!validGroupIds.contains(groupId)) {
        changed = true;
        continue;
      }
      nextMap[providerKey] = groupId;
    }
    if (!mapEquals(_providerGroupMap, nextMap)) {
      _providerGroupMap = nextMap;
      changed = true;
    }

    // Clean collapsed state: remove unknown group ids (except ungrouped).
    final nextCollapsed = <String, bool>{};
    for (final entry in _providerGroupCollapsed.entries) {
      final key = entry.key;
      if (key == providerUngroupedGroupKey || validGroupIds.contains(key)) {
        nextCollapsed[key] = entry.value;
      } else {
        changed = true;
      }
    }
    if (!mapEquals(_providerGroupCollapsed, nextCollapsed)) {
      _providerGroupCollapsed
        ..clear()
        ..addAll(nextCollapsed);
      changed = true;
    }

    return changed;
  }

  Future<void> _persistProviderGrouping(SharedPreferences prefs) async {
    await prefs.setString(_providerGroupsKey, ProviderGroup.encodeList(_providerGroups));
    await prefs.setString(_providerGroupMapKey, jsonEncode(_providerGroupMap));
    await prefs.setString(_providerGroupCollapsedKey, jsonEncode(_providerGroupCollapsed));
    await prefs.setStringList(_providersOrderKey, _providersOrder);
  }

  Future<String> createGroup(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    final key = trimmed.toLowerCase();
    for (final g in _providerGroups) {
      if (g.name.trim().toLowerCase() == key) return g.id;
    }
    final id = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    _providerGroups = List.unmodifiable(<ProviderGroup>[..._providerGroups, ProviderGroup(id: id, name: trimmed, createdAt: now)]);
    _cleanupProviderOrderAndGrouping();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await _persistProviderGrouping(prefs);
    return id;
  }

  Future<void> renameGroup(String groupId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final idx = _providerGroups.indexWhere((g) => g.id == groupId);
    if (idx < 0) return;

    final key = trimmed.toLowerCase();
    for (final g in _providerGroups) {
      if (g.id != groupId && g.name.trim().toLowerCase() == key) return;
    }

    final current = _providerGroups[idx];
    if (current.name == trimmed) return;
    final mut = List<ProviderGroup>.of(_providerGroups);
    mut[idx] = current.copyWith(name: trimmed);
    _providerGroups = List.unmodifiable(mut);
    _cleanupProviderOrderAndGrouping();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await _persistProviderGrouping(prefs);
  }

  Future<void> reorderProviderGroups(int oldIndex, int newIndex) async {
    if (_providerGroups.isEmpty) return;
    if (oldIndex < 0 || oldIndex >= _providerGroups.length) return;
    if (newIndex < 0 || newIndex > _providerGroups.length) return;
    if (oldIndex == newIndex) return;

    final mut = List<ProviderGroup>.of(_providerGroups);
    final item = mut.removeAt(oldIndex);
    final insertIndex = newIndex.clamp(0, mut.length);
    mut.insert(insertIndex, item);
    _providerGroups = List.unmodifiable(mut);
    _cleanupProviderOrderAndGrouping();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await _persistProviderGrouping(prefs);
  }

  Future<void> deleteGroup(String groupId) async {
    if (groupById(groupId) == null) return;
    final res = deleteProviderGroup(
      groups: _providerGroups,
      providerGroupMap: _providerGroupMap,
      collapsed: _providerGroupCollapsed,
      groupId: groupId,
    );
    _providerGroups = res.groups;
    _providerGroupMap = Map<String, String>.from(res.providerGroupMap);
    _providerGroupCollapsed
      ..clear()
      ..addAll(res.collapsed);
    _cleanupProviderOrderAndGrouping();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await _persistProviderGrouping(prefs);
  }

  Future<void> setProviderGroup(String providerKey, String? groupId) async {
    final known = _knownProviderKeys();
    if (!known.contains(providerKey)) return;
    final target = (groupId != null && groupById(groupId) != null) ? groupId : null;
    final current = groupIdForProvider(providerKey);
    if (current == target) return;

    if (target == null) {
      _providerGroupMap.remove(providerKey);
    } else {
      _providerGroupMap[providerKey] = target;
    }
    _cleanupProviderOrderAndGrouping();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await _persistProviderGrouping(prefs);
  }

  Future<void> moveProvidersToGroup(Iterable<String> providerKeys, String? targetGroupId) async {
    final known = _knownProviderKeys();
    final validGroupIds = {for (final g in _providerGroups) g.id};
    final normalizedTargetGroupId = (targetGroupId != null && validGroupIds.contains(targetGroupId)) ? targetGroupId : null;

    final keysSet = providerKeys.where(known.contains).toSet();
    if (keysSet.isEmpty) return;

    // Preserve current visible order when appending into the target group.
    final orderedKeys = <String>[];
    for (final k in _providersOrder) {
      if (keysSet.remove(k)) orderedKeys.add(k);
    }
    orderedKeys.addAll(keysSet);

    List<String> order = _providersOrder;
    Map<String, String> groupMap = _providerGroupMap;

    String? groupIdFor(String key) {
      final gid = groupMap[key];
      return (gid != null && validGroupIds.contains(gid)) ? gid : null;
    }

    bool changed = false;
    for (final key in orderedKeys) {
      final current = groupIdFor(key);
      if (current == normalizedTargetGroupId) continue;

      final res = moveProviderInGroupedOrder(
        providersOrder: order,
        providerGroupMap: groupMap,
        knownProviderKeys: known,
        validGroupIds: validGroupIds,
        providerKey: key,
        targetGroupId: normalizedTargetGroupId,
        targetPos: 1 << 30, // append
      );
      order = res.providersOrder;
      groupMap = res.providerGroupMap;
      changed = true;
    }

    if (!changed) return;
    _providersOrder = order;
    _providerGroupMap = Map<String, String>.from(groupMap);
    _cleanupProviderOrderAndGrouping();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await _persistProviderGrouping(prefs);
  }

  Future<void> setGroupCollapsed(String groupIdOrUngrouped, bool value) async {
    if (groupIdOrUngrouped != providerUngroupedGroupKey && groupById(groupIdOrUngrouped) == null) return;
    _providerGroupCollapsed[groupIdOrUngrouped] = value;
    _cleanupProviderOrderAndGrouping();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await _persistProviderGrouping(prefs);
  }

  Future<void> toggleGroupCollapsed(String groupIdOrUngrouped) async =>
      setGroupCollapsed(groupIdOrUngrouped, !isGroupCollapsed(groupIdOrUngrouped));

  Future<void> moveProvider(String providerKey, String? targetGroupId, int targetPos) async {
    final known = _knownProviderKeys();
    if (!known.contains(providerKey)) return;

    final validGroupIds = {for (final g in _providerGroups) g.id};
    final res = moveProviderInGroupedOrder(
      providersOrder: _providersOrder,
      providerGroupMap: _providerGroupMap,
      knownProviderKeys: known,
      validGroupIds: validGroupIds,
      providerKey: providerKey,
      targetGroupId: targetGroupId,
      targetPos: targetPos,
    );
    _providersOrder = res.providersOrder;
    _providerGroupMap = Map<String, String>.from(res.providerGroupMap);
    _cleanupProviderOrderAndGrouping();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await _persistProviderGrouping(prefs);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final v = mode == ThemeMode.light
        ? 'light'
        : mode == ThemeMode.dark
            ? 'dark'
            : 'system';
    await prefs.setString(_themeModeKey, v);
  }

  Future<void> setThemePalette(String id) async {
    if (_themePaletteId == id) return;
    _themePaletteId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePaletteKey, id);
  }

  Future<void> setUseDynamicColor(bool v) async {
    if (_useDynamicColor == v) return;
    _useDynamicColor = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useDynamicColorKey, v);
  }

  Future<void> setUsePureBackground(bool v) async {
    if (_usePureBackground == v) return;
    _usePureBackground = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayUsePureBackgroundKey, v);
  }

  // Display: chat message background style (affects user/assistant bubbles)
  ChatMessageBackgroundStyle _chatMessageBackgroundStyle = ChatMessageBackgroundStyle.defaultStyle;
  ChatMessageBackgroundStyle get chatMessageBackgroundStyle => _chatMessageBackgroundStyle;
  Future<void> setChatMessageBackgroundStyle(ChatMessageBackgroundStyle style) async {
    if (_chatMessageBackgroundStyle == style) return;
    _chatMessageBackgroundStyle = style;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final v = switch (style) {
      ChatMessageBackgroundStyle.frosted => 'frosted',
      ChatMessageBackgroundStyle.solid => 'solid',
      ChatMessageBackgroundStyle.defaultStyle => 'default',
    };
    await prefs.setString(_displayChatMessageBackgroundStyleKey, v);
  }

  // ===== Android background chat generation =====
  AndroidBackgroundChatMode _androidBackgroundChatMode = AndroidBackgroundChatMode.off;
  AndroidBackgroundChatMode get androidBackgroundChatMode => _androidBackgroundChatMode;
  Future<void> setAndroidBackgroundChatMode(AndroidBackgroundChatMode mode) async {
    if (_androidBackgroundChatMode == mode) return;
    _androidBackgroundChatMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final v = switch (mode) {
      AndroidBackgroundChatMode.onNotify => 'on_notify',
      AndroidBackgroundChatMode.on => 'on',
      AndroidBackgroundChatMode.off => 'off',
    };
    await prefs.setString(_androidBackgroundChatModeKey, v);
    // Best-effort: update Android background execution state immediately
    try {
      if (Platform.isAndroid) {
        // Direct call; file is present in project and guards by Platform
        // ignore: depend_on_referenced_packages
        // ignore_for_file: unnecessary_import
        // ignore: avoid_print
        // Defer import here is not possible; rely on main.dart sync. This is a no-op placeholder.
      }
    } catch (_) {}
  }

  void setDynamicColorSupported(bool v) {
    if (_dynamicColorSupported == v) return;
    _dynamicColorSupported = v;
    notifyListeners();
  }

  Future<void> toggleTheme() => setThemeMode(
      _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  Future<void> followSystem() => setThemeMode(ThemeMode.system);

  Future<void> setProviderConfig(String key, ProviderConfig config) async {
    _providerConfigs[key] = config;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final map = _providerConfigs.map((k, v) => MapEntry(k, v.toJson()));
    await prefs.setString(_providerConfigsKey, jsonEncode(map));
  }

  // ===== Provider Avatars =====
  Future<void> setProviderAvatarEmoji(String key, String emoji) async {
    final e = emoji.trim();
    if (e.isEmpty) return;
    final old = getProviderConfig(key);
    await setProviderConfig(key, old.copyWith(avatarType: 'emoji', avatarValue: e));
  }

  Future<void> setProviderAvatarUrl(String key, String url) async {
    final u = url.trim();
    if (u.isEmpty) return;
    final old = getProviderConfig(key);
    await setProviderConfig(key, old.copyWith(avatarType: 'url', avatarValue: u));
    // Prefetch for offline
    try { await AvatarCache.getPath(u); } catch (_) {}
  }

  Future<void> setProviderAvatarFilePath(String key, String path) async {
    final p = path.trim();
    if (p.isEmpty) return;
    final fixedInput = SandboxPathResolver.fix(p);
    try {
      final src = File(fixedInput);
      if (!await src.exists()) return;
      final avatarsDir = await AppDirectories.getAvatarsDirectory();
      if (!await avatarsDir.exists()) {
        await avatarsDir.create(recursive: true);
      }
      String ext = '';
      final dot = fixedInput.lastIndexOf('.');
      if (dot != -1 && dot < fixedInput.length - 1) {
        ext = fixedInput.substring(dot + 1).toLowerCase();
        if (ext.length > 6) ext = 'jpg';
      } else {
        ext = 'jpg';
      }
      final safeKey = key.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final filename = 'provider_${safeKey}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final dest = File('${avatarsDir.path}/$filename');
      await src.copy(dest.path);

      // Clean old stored avatar file if under managed avatars folder
      final old = getProviderConfig(key);
      if (old.avatarType == 'file' && (old.avatarValue ?? '').isNotEmpty) {
        try {
          final oldFile = File(old.avatarValue!);
          if ((oldFile.path.contains('/avatars/') || oldFile.path.contains('\\\\avatars\\\\')) && await oldFile.exists()) {
            await oldFile.delete();
          }
        } catch (_) {}
      }

      await setProviderConfig(key, old.copyWith(avatarType: 'file', avatarValue: dest.path));
    } catch (_) {
      // Fallback: still save original path
      final old = getProviderConfig(key);
      await setProviderConfig(key, old.copyWith(avatarType: 'file', avatarValue: fixedInput));
    }
  }

  Future<void> resetProviderAvatar(String key) async {
    final old = getProviderConfig(key);
    // Attempt to remove old local file if we managed it
    if (old.avatarType == 'file' && (old.avatarValue ?? '').isNotEmpty) {
      try {
        final f = File(old.avatarValue!);
        if ((f.path.contains('/avatars/') || f.path.contains('\\\\avatars\\\\')) && await f.exists()) {
          await f.delete();
        }
      } catch (_) {}
    }
    // Best-effort: evict cached URL avatar
    if (old.avatarType == 'url' && (old.avatarValue ?? '').isNotEmpty) {
      try { await AvatarCache.evict(old.avatarValue!); } catch (_) {}
    }
    await setProviderConfig(key, old.copyWith(avatarType: null, avatarValue: null));
  }

  /// Clears all global model selections (current, title, translate, OCR) that reference the given provider.
  /// Used when a provider is disabled or deleted.
  Future<void> clearSelectionsForProvider(String providerKey) async {
    final prefs = await SharedPreferences.getInstance();
    bool changed = false;
    if (_currentModelProvider == providerKey) {
      _currentModelProvider = null;
      _currentModelId = null;
      await prefs.remove(_selectedModelKey);
      changed = true;
    }
    if (_titleModelProvider == providerKey) {
      _titleModelProvider = null;
      _titleModelId = null;
      await prefs.remove(_titleModelKey);
      changed = true;
    }
    if (_translateModelProvider == providerKey) {
      _translateModelProvider = null;
      _translateModelId = null;
      await prefs.remove(_translateModelKey);
      changed = true;
    }
    if (_ocrModelProvider == providerKey) {
      _ocrModelProvider = null;
      _ocrModelId = null;
      _ocrEnabled = false;
      await prefs.remove(_ocrModelKey);
      await prefs.setBool(_ocrEnabledKey, false);
      changed = true;
    }
    if (_summaryModelProvider == providerKey) {
      _summaryModelProvider = null;
      _summaryModelId = null;
      await prefs.remove(_summaryModelKey);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Clears global model selections that reference a specific model.
  /// Used when a model is deleted from a provider.
  Future<void> clearSelectionsForModel(String providerKey, String modelId) async {
    final prefs = await SharedPreferences.getInstance();
    bool changed = false;
    if (_currentModelProvider == providerKey && _currentModelId == modelId) {
      _currentModelProvider = null;
      _currentModelId = null;
      await prefs.remove(_selectedModelKey);
      changed = true;
    }
    if (_titleModelProvider == providerKey && _titleModelId == modelId) {
      _titleModelProvider = null;
      _titleModelId = null;
      await prefs.remove(_titleModelKey);
      changed = true;
    }
    if (_translateModelProvider == providerKey && _translateModelId == modelId) {
      _translateModelProvider = null;
      _translateModelId = null;
      await prefs.remove(_translateModelKey);
      changed = true;
    }
    if (_ocrModelProvider == providerKey && _ocrModelId == modelId) {
      _ocrModelProvider = null;
      _ocrModelId = null;
      _ocrEnabled = false;
      await prefs.remove(_ocrModelKey);
      await prefs.setBool(_ocrEnabledKey, false);
      changed = true;
    }
    if (_summaryModelProvider == providerKey && _summaryModelId == modelId) {
      _summaryModelProvider = null;
      _summaryModelId = null;
      await prefs.remove(_summaryModelKey);
      changed = true;
    }
    // Also remove from pinned if applicable
    final pinKey = '$providerKey::$modelId';
    if (_pinnedModels.contains(pinKey)) {
      _pinnedModels.remove(pinKey);
      await prefs.setStringList(_pinnedModelsKey, _pinnedModels.toList());
      changed = true;
    }
    if (changed) notifyListeners();
  }

  Future<void> removeProviderConfig(String key) async {
    if (!_providerConfigs.containsKey(key)) return;
    _providerConfigs.remove(key);
    // Remove from order
    _providersOrder = List<String>.from(_providersOrder.where((k) => k != key));
    // Also remove from grouping map
    _providerGroupMap.remove(key);
    _cleanupProviderOrderAndGrouping();

    // Clear selections referencing this provider to avoid re-creating defaults
    final prefs = await SharedPreferences.getInstance();
    if (_currentModelProvider == key) {
      _currentModelProvider = null;
      _currentModelId = null;
      await prefs.remove(_selectedModelKey);
    }
    if (_titleModelProvider == key) {
      _titleModelProvider = null;
      _titleModelId = null;
      await prefs.remove(_titleModelKey);
    }
    if (_translateModelProvider == key) {
      _translateModelProvider = null;
      _translateModelId = null;
      await prefs.remove(_translateModelKey);
    }
    if (_ocrModelProvider == key) {
      _ocrModelProvider = null;
      _ocrModelId = null;
      _ocrEnabled = false;
      await prefs.remove(_ocrModelKey);
      await prefs.setBool(_ocrEnabledKey, false);
    }
    if (_summaryModelProvider == key) {
      _summaryModelProvider = null;
      _summaryModelId = null;
      await prefs.remove(_summaryModelKey);
    }

    // Remove pinned models for this provider
    final beforePinned = _pinnedModels.length;
    _pinnedModels.removeWhere((entry) => entry.startsWith('$key::'));
    if (_pinnedModels.length != beforePinned) {
      await prefs.setStringList(_pinnedModelsKey, _pinnedModels.toList());
    }

    // Persist updates
    final map = _providerConfigs.map((k, v) => MapEntry(k, v.toJson()));
    await prefs.setString(_providerConfigsKey, jsonEncode(map));
    await prefs.setStringList(_providersOrderKey, _providersOrder);
    await prefs.setString(_providerGroupMapKey, jsonEncode(_providerGroupMap));
    notifyListeners();
  }

  // Favorites (pinned models)
  final Set<String> _pinnedModels = <String>{};
  Set<String> get pinnedModels => Set.unmodifiable(_pinnedModels);
  bool isModelPinned(String providerKey, String modelId) => _pinnedModels.contains('$providerKey::$modelId');
  Future<void> togglePinModel(String providerKey, String modelId) async {
    final k = '$providerKey::$modelId';
    if (_pinnedModels.contains(k)) {
      _pinnedModels.remove(k);
    } else {
      _pinnedModels.add(k);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_pinnedModelsKey, _pinnedModels.toList());
  }

  // Selected model for chat
  String? _currentModelProvider;
  String? _currentModelId;
  String? get currentModelProvider => _currentModelProvider;
  String? get currentModelId => _currentModelId;
  String? get currentModelKey => (_currentModelProvider != null && _currentModelId != null)
      ? '${_currentModelProvider!}::${_currentModelId!}'
      : null;
  Future<void> setCurrentModel(String providerKey, String modelId) async {
    _currentModelProvider = providerKey;
    _currentModelId = modelId;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedModelKey, '$providerKey::$modelId');
  }

  Future<void> resetCurrentModel() async {
    _currentModelProvider = null;
    _currentModelId = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedModelKey);
  }

  // Title model and prompt
  String? _titleModelProvider;
  String? _titleModelId;
  String? get titleModelProvider => _titleModelProvider;
  String? get titleModelId => _titleModelId;
  String? get titleModelKey => (_titleModelProvider != null && _titleModelId != null)
      ? '${_titleModelProvider!}::${_titleModelId!}'
      : null;

  static const String defaultTitlePrompt = '''I will give you some dialogue content in the `<content>` block.
You need to summarize the conversation between user and assistant into a short title.
1. The title language should be consistent with the user's primary language
2. Do not use punctuation or other special symbols
3. Reply directly with the title
4. Summarize using {locale} language
5. The title should not exceed 10 characters

<content>
{content}
</content>''';

  String _titlePrompt = defaultTitlePrompt;
  String get titlePrompt => _titlePrompt;

  Future<void> setTitleModel(String providerKey, String modelId) async {
    _titleModelProvider = providerKey;
    _titleModelId = modelId;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_titleModelKey, '$providerKey::$modelId');
  }

  Future<void> resetTitleModel() async {
    _titleModelProvider = null;
    _titleModelId = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_titleModelKey);
  }

  Future<void> setTitlePrompt(String prompt) async {
    _titlePrompt = prompt.trim().isEmpty ? defaultTitlePrompt : prompt;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_titlePromptKey, _titlePrompt);
  }

  Future<void> resetTitlePrompt() async => setTitlePrompt(defaultTitlePrompt);

  // Translate model and prompt
  String? _translateModelProvider;
  String? _translateModelId;
  String? get translateModelProvider => _translateModelProvider;
  String? get translateModelId => _translateModelId;
  String? get translateModelKey => (_translateModelProvider != null && _translateModelId != null)
      ? '${_translateModelProvider!}::${_translateModelId!}'
      : null;

  static const String defaultTranslatePrompt = '''You are a translation expert, skilled in translating various languages, and maintaining accuracy, faithfulness, and elegance in translation.
Next, I will send you text. Please translate it into {target_lang}, and return the translation result directly, without adding any explanations or other content.

Please translate the <source_text> section:
<source_text>
{source_text}
</source_text>''';

  String _translatePrompt = defaultTranslatePrompt;
  String get translatePrompt => _translatePrompt;
  String? _translateTargetLang;
  String? get translateTargetLang => _translateTargetLang;

  Future<void> setTranslateModel(String providerKey, String modelId) async {
    _translateModelProvider = providerKey;
    _translateModelId = modelId;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_translateModelKey, '$providerKey::$modelId');
  }

  Future<void> resetTranslateModel() async {
    _translateModelProvider = null;
    _translateModelId = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_translateModelKey);
  }

  Future<void> setTranslatePrompt(String prompt) async {
    _translatePrompt = prompt.trim().isEmpty ? defaultTranslatePrompt : prompt;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_translatePromptKey, _translatePrompt);
  }

  Future<void> resetTranslatePrompt() async => setTranslatePrompt(defaultTranslatePrompt);
  Future<void> setTranslateTargetLang(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;
    _translateTargetLang = trimmed;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_translateTargetLangKey, trimmed);
  }

  Future<void> resetTranslateTargetLang() async {
    _translateTargetLang = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_translateTargetLangKey);
  }

  // OCR model, prompt and toggle
  String? _ocrModelProvider;
  String? _ocrModelId;
  String? get ocrModelProvider => _ocrModelProvider;
  String? get ocrModelId => _ocrModelId;
  String? get ocrModelKey => (_ocrModelProvider != null && _ocrModelId != null)
      ? '${_ocrModelProvider!}::${_ocrModelId!}'
      : null;

  static const String defaultOcrPrompt = '''You are an OCR assistant.

Extract all visible text from the image and also describe any non-text elements (icons, shapes, arrows, objects, symbols, or emojis).

For each element, specify:
- The exact text (for text) or a short description (for non-text).
- For document-type content, please use markdown and latex format.
- If there are objects like buildings or characters, try to identify who they are.
- Its approximate position in the image (e.g., 'top left', 'center right', 'bottom middle').
- Its spatial relationship to nearby elements (e.g., 'above', 'below', 'next to', 'on the left of').

Keep the original reading order and layout structure as much as possible.
Do not interpret or translate—only transcribe and describe what is visually present.''';

  String _ocrPrompt = defaultOcrPrompt;
  String get ocrPrompt => _ocrPrompt;

  bool _ocrEnabled = false;
  bool get ocrEnabled => _ocrEnabled;

  Future<void> setOcrModel(String providerKey, String modelId) async {
    _ocrModelProvider = providerKey;
    _ocrModelId = modelId;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ocrModelKey, '$providerKey::$modelId');
  }

  Future<void> resetOcrModel() async {
    _ocrModelProvider = null;
    _ocrModelId = null;
    _ocrEnabled = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ocrModelKey);
    await prefs.setBool(_ocrEnabledKey, false);
  }

  Future<void> setOcrPrompt(String prompt) async {
    _ocrPrompt = prompt.trim().isEmpty ? defaultOcrPrompt : prompt;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ocrPromptKey, _ocrPrompt);
  }

  Future<void> resetOcrPrompt() async => setOcrPrompt(defaultOcrPrompt);

  Future<void> setOcrEnabled(bool value) async {
    // If there is no OCR model configured, force disable.
    if (_ocrModelProvider == null || _ocrModelId == null) {
      value = false;
    }
    if (_ocrEnabled == value) return;
    _ocrEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_ocrEnabledKey, _ocrEnabled);
  }

  // Summary model and prompt
  String? _summaryModelProvider;
  String? _summaryModelId;
  String? get summaryModelProvider => _summaryModelProvider;
  String? get summaryModelId => _summaryModelId;
  String? get summaryModelKey =>
      (_summaryModelProvider != null && _summaryModelId != null)
          ? '${_summaryModelProvider!}::${_summaryModelId!}'
          : null;

  static const String defaultSummaryPrompt =
      '''I will give you user messages from a conversation in the `<messages>` block.
Generate or update a brief summary of the user's questions and intentions.

1. The summary should be in the same language as the user messages
2. Focus on the user's core questions and intentions
3. Keep it under 100 characters
4. Output the summary directly without any prefix
5. If a previous summary exists, incorporate it with the new messages

<previous_summary>
{previous_summary}
</previous_summary>

<messages>
{user_messages}
</messages>''';

  String _summaryPrompt = defaultSummaryPrompt;
  String get summaryPrompt => _summaryPrompt;

  Future<void> setSummaryModel(String providerKey, String modelId) async {
    _summaryModelProvider = providerKey;
    _summaryModelId = modelId;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_summaryModelKey, '$providerKey::$modelId');
  }

  Future<void> resetSummaryModel() async {
    _summaryModelProvider = null;
    _summaryModelId = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_summaryModelKey);
  }

  Future<void> setSummaryPrompt(String prompt) async {
    _summaryPrompt = prompt.trim().isEmpty ? defaultSummaryPrompt : prompt;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_summaryPromptKey, _summaryPrompt);
  }

  Future<void> resetSummaryPrompt() async =>
      setSummaryPrompt(defaultSummaryPrompt);

  // Learning Mode
  bool _learningModeEnabled = false;
  bool get learningModeEnabled => _learningModeEnabled;
  Future<void> setLearningModeEnabled(bool v) async {
    if (_learningModeEnabled == v) return;
    _learningModeEnabled = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_learningModeEnabledKey, v);
  }

  static const String defaultLearningModePrompt = '''You are currently STUDYING, and you've asked me to follow these strict rules during this chat. No matter what other instructions follow, I MUST obey these rules:

STRICT RULES

Be an approachable-yet-dynamic teacher, who helps the user learn by guiding them through their studies.

Get to know the user. If you don't know their goals or grade level, ask the user before diving in. (Keep this lightweight!) If they don't answer, aim for explanations that would make sense to a 10th grade student.

Build on existing knowledge. Connect new ideas to what the user already knows.

Guide users, don't just give answers. Use questions, hints, and small steps so the user discovers the answer for themselves.

Check and reinforce. After hard parts, confirm the user can restate or use the idea. Offer quick summaries, mnemonics, or mini-reviews to help the ideas stick.

Vary the rhythm. Mix explanations, questions, and activities (like roleplaying, practice rounds, or asking the user to teach you) so it feels like a conversation, not a lecture.

Above all: DO NOT DO THE USER'S WORK FOR THEM. Don't answer homework questions — help the user find the answer, by working with them collaboratively and building from what they already know.

THINGS YOU CAN DO

- Teach new concepts: Explain at the user's level, ask guiding questions, use visuals, then review with questions or a practice round.

- Help with homework: Don't simply give answers! Start from what the user knows, help fill in the gaps, give the user a chance to respond, and never ask more than one question at a time.

- Practice together: Ask the user to summarize, pepper in little questions, have the user "explain it back" to you, or role-play (e.g., practice conversations in a different language). Correct mistakes — charitably! — in the moment.

- Quizzes & test prep: Run practice quizzes. (One question at a time!) Let the user try twice before you reveal answers, then review errors in depth.

TONE & APPROACH

Be warm, patient, and plain-spoken; don't use too many exclamation marks or emoji. Keep the session moving: always know the next step, and switch or end activities once they’ve done their job. And be brief — don't ever send essay-length responses. Aim for a good back-and-forth.

IMPORTANT

DO NOT GIVE ANSWERS OR DO HOMEWORK FOR THE USER. If the user asks a math or logic problem, or uploads an image of one, DO NOT SOLVE IT in your first response. Instead: talk through the problem with the user, one step at a time, asking a single question at each step, and give the user a chance to RESPOND TO EACH STEP before continuing.''';

  String _learningModePrompt = defaultLearningModePrompt;
  String get learningModePrompt => _learningModePrompt;
  Future<void> setLearningModePrompt(String prompt) async {
    _learningModePrompt = prompt.trim().isEmpty ? defaultLearningModePrompt : prompt;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_learningModePromptKey, _learningModePrompt);
  }

  Future<void> resetLearningModePrompt() async => setLearningModePrompt(defaultLearningModePrompt);

  // Reasoning strength / thinking budget
  int? _thinkingBudget; // null = not set, use provider defaults; -1 = auto; 0 = off; >0 = budget tokens
  int? get thinkingBudget => _thinkingBudget;
  Future<void> setThinkingBudget(int? budget) async {
    _thinkingBudget = budget;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (budget == null) {
      await prefs.remove(_thinkingBudgetKey);
    } else {
      await prefs.setInt(_thinkingBudgetKey, budget);
    }
  }

  // Display settings: user avatar and model icon visibility
  bool _showUserAvatar = true;
  bool get showUserAvatar => _showUserAvatar;
  Future<void> setShowUserAvatar(bool v) async {
    if (_showUserAvatar == v) return;
    _showUserAvatar = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayShowUserAvatarKey, v);
  }

  // Display: user name & timestamp (for user messages)
  bool _showUserNameTimestamp = true;
  bool get showUserNameTimestamp => _showUserNameTimestamp;
  Future<void> setShowUserNameTimestamp(bool v) async {
    if (_showUserNameTimestamp == v) return;
    _showUserNameTimestamp = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayShowUserNameTimestampKey, v);
  }

  bool _showUserMessageActions = true;
  bool get showUserMessageActions => _showUserMessageActions;
  Future<void> setShowUserMessageActions(bool v) async {
    if (_showUserMessageActions == v) return;
    _showUserMessageActions = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayShowUserMessageActionsKey, v);
  }

  bool _showModelIcon = true;
  bool get showModelIcon => _showModelIcon;
  Future<void> setShowModelIcon(bool v) async {
    if (_showModelIcon == v) return;
    _showModelIcon = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayShowModelIconKey, v);
  }

  // Display: model name & timestamp (for assistant messages)
  bool _showModelNameTimestamp = true;
  bool get showModelNameTimestamp => _showModelNameTimestamp;
  Future<void> setShowModelNameTimestamp(bool v) async {
    if (_showModelNameTimestamp == v) return;
    _showModelNameTimestamp = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayShowModelNameTimestampKey, v);
  }

  // Display: token/context stats
  bool _showTokenStats = true;
  bool get showTokenStats => _showTokenStats;
  Future<void> setShowTokenStats(bool v) async {
    if (_showTokenStats == v) return;
    _showTokenStats = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayShowTokenStatsKey, v);
  }

  // Display: auto-collapse reasoning/thinking section
  bool _autoCollapseThinking = true;
  bool get autoCollapseThinking => _autoCollapseThinking;
  Future<void> setAutoCollapseThinking(bool v) async {
    if (_autoCollapseThinking == v) return;
    _autoCollapseThinking = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayAutoCollapseThinkingKey, v);
  }

  // Display: show message navigation button
  bool _showMessageNavButtons = true;
  bool get showMessageNavButtons => _showMessageNavButtons;
  Future<void> setShowMessageNavButtons(bool v) async {
    if (_showMessageNavButtons == v) return;
    _showMessageNavButtons = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayShowMessageNavKey, v);
  }

  // Display: show provider name in model capsule (desktop header)
  bool _showProviderInModelCapsule = true;
  bool get showProviderInModelCapsule => _showProviderInModelCapsule;
  Future<void> setShowProviderInModelCapsule(bool v) async {
    if (_showProviderInModelCapsule == v) return;
    _showProviderInModelCapsule = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayShowProviderInModelCapsuleKey, v);
  }

  // Display: create a new chat on app launch
  bool _newChatOnLaunch = true;
  bool get newChatOnLaunch => _newChatOnLaunch;
  Future<void> setNewChatOnLaunch(bool v) async {
    if (_newChatOnLaunch == v) return;
    _newChatOnLaunch = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayNewChatOnLaunchKey, v);
  }

  // Display: create a new chat when switching assistants
  bool _newChatOnAssistantSwitch = false;
  bool get newChatOnAssistantSwitch => _newChatOnAssistantSwitch;
  Future<void> setNewChatOnAssistantSwitch(bool v) async {
    if (_newChatOnAssistantSwitch == v) return;
    _newChatOnAssistantSwitch = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayNewChatOnAssistantSwitchKey, v);
  }

  // Display: create a new chat after deleting one
  bool _newChatAfterDelete = false;
  bool get newChatAfterDelete => _newChatAfterDelete;
  Future<void> setNewChatAfterDelete(bool v) async {
    if (_newChatAfterDelete == v) return;
    _newChatAfterDelete = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayNewChatAfterDeleteKey, v);
  }

  // Display: enter key sends message on mobile (iOS defaults true, Android defaults false)
  bool _enterToSendOnMobile = false;
  bool get enterToSendOnMobile => _enterToSendOnMobile;
  Future<void> setEnterToSendOnMobile(bool v) async {
    if (_enterToSendOnMobile == v) return;
    _enterToSendOnMobile = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayEnterToSendOnMobileKey, v);
  }

  // Desktop: send shortcut (Enter or Ctrl/Cmd+Enter)
  DesktopSendShortcut _desktopSendShortcut = DesktopSendShortcut.enter;
  DesktopSendShortcut get desktopSendShortcut => _desktopSendShortcut;
  Future<void> setDesktopSendShortcut(DesktopSendShortcut v) async {
    if (_desktopSendShortcut == v) return;
    _desktopSendShortcut = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final str = v == DesktopSendShortcut.ctrlEnter ? 'ctrlEnter' : 'enter';
    await prefs.setString(_desktopSendShortcutKey, str);
  }

  // Display: chat font scale (0.5 - 1.5, default 1.0)
  double _chatFontScale = 1.0;
  double get chatFontScale => _chatFontScale;
  Future<void> setChatFontScale(double scale) async {
    final s = scale.clamp(0.5, 1.5);
    if (_chatFontScale == s) return;
    _chatFontScale = s;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_displayChatFontScaleKey, _chatFontScale);
  }

  // Display: auto-scroll back to bottom toggle
  bool _autoScrollEnabled = true;
  bool get autoScrollEnabled => _autoScrollEnabled;
  Future<void> setAutoScrollEnabled(bool v) async {
    if (_autoScrollEnabled == v) return;
    _autoScrollEnabled = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayAutoScrollEnabledKey, v);
  }

  // Display: auto-scroll back to bottom idle timeout (seconds)
  int _autoScrollIdleSeconds = 8;
  int get autoScrollIdleSeconds => _autoScrollIdleSeconds;
  Future<void> setAutoScrollIdleSeconds(int seconds) async {
    final v = seconds.clamp(2, 64);
    if (_autoScrollIdleSeconds == v) return;
    _autoScrollIdleSeconds = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_displayAutoScrollIdleSecondsKey, _autoScrollIdleSeconds);
  }

  // Display: chat background mask strength (0.0 - 2.0, default 1.0)
  double _chatBackgroundMaskStrength = 1.0;
  double get chatBackgroundMaskStrength => _chatBackgroundMaskStrength;
  Future<void> setChatBackgroundMaskStrength(double strength) async {
    final s = strength.clamp(0.0, 2.0);
    if (_chatBackgroundMaskStrength == s) return;
    _chatBackgroundMaskStrength = s;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_displayChatBackgroundMaskStrengthKey, _chatBackgroundMaskStrength);
  }

  // Display: inline $...$ LaTeX rendering
  bool _enableDollarLatex = true;
  bool get enableDollarLatex => _enableDollarLatex;
  Future<void> setEnableDollarLatex(bool v) async {
    if (_enableDollarLatex == v) return;
    _enableDollarLatex = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayEnableDollarLatexKey, v);
  }

  // Display: LaTeX math rendering (inline/block)
  bool _enableMathRendering = true;
  bool get enableMathRendering => _enableMathRendering;
  Future<void> setEnableMathRendering(bool v) async {
    if (_enableMathRendering == v) return;
    _enableMathRendering = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayEnableMathRenderingKey, v);
  }

  // Display: render user messages with Markdown
  bool _enableUserMarkdown = true;
  bool get enableUserMarkdown => _enableUserMarkdown;
  Future<void> setEnableUserMarkdown(bool v) async {
    if (_enableUserMarkdown == v) return;
    _enableUserMarkdown = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayEnableUserMarkdownKey, v);
  }

  // Display: render reasoning (thinking) content with Markdown
  bool _enableReasoningMarkdown = true;
  bool get enableReasoningMarkdown => _enableReasoningMarkdown;
  Future<void> setEnableReasoningMarkdown(bool v) async {
    if (_enableReasoningMarkdown == v) return;
    _enableReasoningMarkdown = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayEnableReasoningMarkdownKey, v);
  }

  // Display: show chat list date
  bool _showChatListDate = false;
  bool get showChatListDate => _showChatListDate;
  Future<void> setShowChatListDate(bool v) async {
    if (_showChatListDate == v) return;
    _showChatListDate = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayShowChatListDateKey, v);
  }

  // Display: mobile code block word wrap
  bool _mobileCodeBlockWrap = false;
  bool get mobileCodeBlockWrap => _mobileCodeBlockWrap;
  Future<void> setMobileCodeBlockWrap(bool v) async {
    if (_mobileCodeBlockWrap == v) return;
    _mobileCodeBlockWrap = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayMobileCodeBlockWrapKey, v);
  }

  // Display: auto-collapse code blocks
  bool _autoCollapseCodeBlock = false;
  bool get autoCollapseCodeBlock => _autoCollapseCodeBlock;
  Future<void> setAutoCollapseCodeBlock(bool v) async {
    if (_autoCollapseCodeBlock == v) return;
    _autoCollapseCodeBlock = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayAutoCollapseCodeBlockKey, v);
  }

  // Display: code block auto-collapse threshold (lines)
  int _autoCollapseCodeBlockLines = 2;
  int get autoCollapseCodeBlockLines => _autoCollapseCodeBlockLines;
  Future<void> setAutoCollapseCodeBlockLines(int v) async {
    final next = v.clamp(1, 999);
    if (_autoCollapseCodeBlockLines == next) return;
    _autoCollapseCodeBlockLines = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_displayAutoCollapseCodeBlockLinesKey, next);
  }

  // Desktop-only: auto switch to Topics tab when changing assistant
  bool _desktopAutoSwitchTopics = false;
  bool get desktopAutoSwitchTopics => _desktopAutoSwitchTopics;
  Future<void> setDesktopAutoSwitchTopics(bool v) async {
    if (_desktopAutoSwitchTopics == v) return;
    _desktopAutoSwitchTopics = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayDesktopAutoSwitchTopicsKey, v);
  }

  // Desktop-only: show system tray icon
  bool _desktopShowTray = false;
  bool get desktopShowTray => _desktopShowTray;
  Future<void> setDesktopShowTray(bool v) async {
    if (_desktopShowTray == v) return;
    _desktopShowTray = v;
    if (!_desktopShowTray && _desktopMinimizeToTrayOnClose) {
      _desktopMinimizeToTrayOnClose = false;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayDesktopShowTrayKey, _desktopShowTray);
    await prefs.setBool(_displayDesktopMinimizeToTrayOnCloseKey, _desktopMinimizeToTrayOnClose);
  }

  // Desktop-only: minimize to tray when closing window
  bool _desktopMinimizeToTrayOnClose = false;
  bool get desktopMinimizeToTrayOnClose => _desktopMinimizeToTrayOnClose;
  Future<void> setDesktopMinimizeToTrayOnClose(bool v) async {
    final next = _desktopShowTray ? v : false;
    if (_desktopMinimizeToTrayOnClose == next) return;
    _desktopMinimizeToTrayOnClose = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayDesktopMinimizeToTrayOnCloseKey, _desktopMinimizeToTrayOnClose);
  }

  // Display: haptics on message generation
  bool _hapticsOnGenerate = false;
  bool get hapticsOnGenerate => _hapticsOnGenerate;
  Future<void> setHapticsOnGenerate(bool v) async {
    if (_hapticsOnGenerate == v) return;
    _hapticsOnGenerate = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayHapticsOnGenerateKey, v);
  }

  // Display: haptics on drawer open/close
  bool _hapticsOnDrawer = true;
  bool get hapticsOnDrawer => _hapticsOnDrawer;
  Future<void> setHapticsOnDrawer(bool v) async {
    if (_hapticsOnDrawer == v) return;
    _hapticsOnDrawer = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayHapticsOnDrawerKey, v);
  }

  // Display: global haptics master switch
  bool _hapticsGlobalEnabled = true;
  bool get hapticsGlobalEnabled => _hapticsGlobalEnabled;
  Future<void> setHapticsGlobalEnabled(bool v) async {
    if (_hapticsGlobalEnabled == v) return;
    _hapticsGlobalEnabled = v;
    // Apply immediately to service
    Haptics.setEnabled(v);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayHapticsGlobalEnabledKey, v);
  }

  // Display: iOS-style switch haptics only
  bool _hapticsIosSwitch = true;
  bool get hapticsIosSwitch => _hapticsIosSwitch;
  Future<void> setHapticsIosSwitch(bool v) async {
    if (_hapticsIosSwitch == v) return;
    _hapticsIosSwitch = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayHapticsIosSwitchKey, v);
  }

  // Display: list item tap haptics (e.g., rows in settings pages)
  bool _hapticsOnListItemTap = true;
  bool get hapticsOnListItemTap => _hapticsOnListItemTap;
  Future<void> setHapticsOnListItemTap(bool v) async {
    if (_hapticsOnListItemTap == v) return;
    _hapticsOnListItemTap = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayHapticsOnListItemTapKey, v);
  }

  // Display: card tap haptics (e.g., Assistant cards etc.)
  bool _hapticsOnCardTap = true;
  bool get hapticsOnCardTap => _hapticsOnCardTap;
  Future<void> setHapticsOnCardTap(bool v) async {
    if (_hapticsOnCardTap == v) return;
    _hapticsOnCardTap = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayHapticsOnCardTapKey, v);
  }

  // Display: show app updates notification
  bool _showAppUpdates = true;
  bool get showAppUpdates => _showAppUpdates;
  Future<void> setShowAppUpdates(bool v) async {
    if (_showAppUpdates == v) return;
    _showAppUpdates = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayShowAppUpdatesKey, v);
  }

  // Display: keep sidebar open when selecting assistant (mobile)
  bool _keepSidebarOpenOnAssistantTap = false;
  bool get keepSidebarOpenOnAssistantTap => _keepSidebarOpenOnAssistantTap;
  Future<void> setKeepSidebarOpenOnAssistantTap(bool v) async {
    if (_keepSidebarOpenOnAssistantTap == v) return;
    _keepSidebarOpenOnAssistantTap = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayKeepSidebarOpenOnAssistantTapKey, v);
  }

  // Display: keep sidebar open when switching topics (mobile)
  bool _keepSidebarOpenOnTopicTap = false;
  bool get keepSidebarOpenOnTopicTap => _keepSidebarOpenOnTopicTap;
  Future<void> setKeepSidebarOpenOnTopicTap(bool v) async {
    if (_keepSidebarOpenOnTopicTap == v) return;
    _keepSidebarOpenOnTopicTap = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayKeepSidebarOpenOnTopicTapKey, v);
  }

  // Display: keep assistant list expanded when closing sidebar (mobile)
  bool _keepAssistantListExpandedOnSidebarClose = false;
  bool get keepAssistantListExpandedOnSidebarClose => _keepAssistantListExpandedOnSidebarClose;
  Future<void> setKeepAssistantListExpandedOnSidebarClose(bool v) async {
    if (_keepAssistantListExpandedOnSidebarClose == v) return;
    _keepAssistantListExpandedOnSidebarClose = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_displayKeepAssistantListExpandedOnSidebarCloseKey, v);
  }

  // Network: request logging (debug)
  bool _requestLogEnabled = false;
  bool get requestLogEnabled => _requestLogEnabled;
  Future<void> setRequestLogEnabled(bool v) async {
    if (_requestLogEnabled == v) return;
    _requestLogEnabled = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_requestLogEnabledKey, v);
    await RequestLogger.setEnabled(v);
  }

  // Flutter: runtime logging (debug)
  bool _flutterLogEnabled = false;
  bool get flutterLogEnabled => _flutterLogEnabled;
  Future<void> setFlutterLogEnabled(bool v) async {
    if (_flutterLogEnabled == v) return;
    _flutterLogEnabled = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_flutterLogEnabledKey, v);
    await FlutterLogger.setEnabled(v);
  }

  // Search service settings
  Future<void> setSearchServices(List<SearchServiceOptions> services) async {
    _searchServices = List.from(services);
    if (_searchServiceSelected >= _searchServices.length) {
      _searchServiceSelected = _searchServices.isNotEmpty ? _searchServices.length - 1 : 0;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_searchServicesKey, jsonEncode(_searchServices.map((e) => e.toJson()).toList()));
    await prefs.setInt(_searchSelectedKey, _searchServiceSelected);
  }

  Future<void> setSearchCommonOptions(SearchCommonOptions options) async {
    _searchCommonOptions = options;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_searchCommonKey, jsonEncode(options.toJson()));
  }

  Future<void> setSearchServiceSelected(int index) async {
    _searchServiceSelected = index.clamp(0, _searchServices.isNotEmpty ? _searchServices.length - 1 : 0);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_searchSelectedKey, _searchServiceSelected);
  }

  Future<void> setSearchEnabled(bool enabled) async {
    _searchEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_searchEnabledKey, enabled);
  }

  Future<void> setSearchAutoTestOnLaunch(bool enabled) async {
    _searchAutoTestOnLaunch = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_searchAutoTestOnLaunchKey, enabled);
  }

  // Combined update for settings
  Future<void> updateSettings(SettingsProvider newSettings) async {
    if (!listEquals(_searchServices, newSettings._searchServices)) {
      await setSearchServices(newSettings._searchServices);
    }
    if (_searchCommonOptions != newSettings._searchCommonOptions) {
      await setSearchCommonOptions(newSettings._searchCommonOptions);
    }
    if (_searchServiceSelected != newSettings._searchServiceSelected) {
      await setSearchServiceSelected(newSettings._searchServiceSelected);
    }
    if (_searchEnabled != newSettings._searchEnabled) {
      await setSearchEnabled(newSettings._searchEnabled);
    }
    if (_searchAutoTestOnLaunch != newSettings._searchAutoTestOnLaunch) {
      await setSearchAutoTestOnLaunch(newSettings._searchAutoTestOnLaunch);
    }
  }

  SettingsProvider copyWith({
    List<SearchServiceOptions>? searchServices,
    SearchCommonOptions? searchCommonOptions,
    int? searchServiceSelected,
    bool? searchEnabled,
    bool? searchAutoTestOnLaunch,
  }) {
    final copy = SettingsProvider();
    copy._searchServices = searchServices ?? _searchServices;
    copy._searchCommonOptions = searchCommonOptions ?? _searchCommonOptions;
    copy._searchServiceSelected = searchServiceSelected ?? _searchServiceSelected;
    copy._searchEnabled = searchEnabled ?? _searchEnabled;
    copy._searchAutoTestOnLaunch = searchAutoTestOnLaunch ?? _searchAutoTestOnLaunch;
    // Copy other fields
    copy._providersOrder = _providersOrder;
    copy._themeMode = _themeMode;
    copy._providerConfigs = _providerConfigs;
    copy._pinnedModels.addAll(_pinnedModels);
    copy._currentModelProvider = _currentModelProvider;
    copy._currentModelId = _currentModelId;
    copy._titleModelProvider = _titleModelProvider;
    copy._titleModelId = _titleModelId;
    copy._titlePrompt = _titlePrompt;
    copy._translateModelProvider = _translateModelProvider;
    copy._translateModelId = _translateModelId;
    copy._translatePrompt = _translatePrompt;
    copy._translateTargetLang = _translateTargetLang;
    copy._ocrModelProvider = _ocrModelProvider;
    copy._ocrModelId = _ocrModelId;
    copy._ocrPrompt = _ocrPrompt;
    copy._ocrEnabled = _ocrEnabled;
    copy._thinkingBudget = _thinkingBudget;
    copy._showUserAvatar = _showUserAvatar;
    copy._showModelIcon = _showModelIcon;
    copy._showModelNameTimestamp = _showModelNameTimestamp;
    copy._showTokenStats = _showTokenStats;
    copy._showUserNameTimestamp = _showUserNameTimestamp;
    copy._showUserMessageActions = _showUserMessageActions;
    copy._autoCollapseThinking = _autoCollapseThinking;
    copy._showMessageNavButtons = _showMessageNavButtons;
    copy._showProviderInModelCapsule = _showProviderInModelCapsule;
    copy._hapticsOnGenerate = _hapticsOnGenerate;
    copy._hapticsOnDrawer = _hapticsOnDrawer;
    copy._hapticsGlobalEnabled = _hapticsGlobalEnabled;
    copy._hapticsIosSwitch = _hapticsIosSwitch;
    copy._hapticsOnListItemTap = _hapticsOnListItemTap;
    copy._hapticsOnCardTap = _hapticsOnCardTap;
    copy._showAppUpdates = _showAppUpdates;
    copy._keepSidebarOpenOnAssistantTap = _keepSidebarOpenOnAssistantTap;
    copy._keepSidebarOpenOnTopicTap = _keepSidebarOpenOnTopicTap;
    copy._keepAssistantListExpandedOnSidebarClose = _keepAssistantListExpandedOnSidebarClose;
    copy._requestLogEnabled = _requestLogEnabled;
    copy._flutterLogEnabled = _flutterLogEnabled;
    copy._newChatOnLaunch = _newChatOnLaunch;
    copy._newChatOnAssistantSwitch = _newChatOnAssistantSwitch;
    copy._newChatAfterDelete = _newChatAfterDelete;
    copy._chatFontScale = _chatFontScale;
    copy._autoScrollEnabled = _autoScrollEnabled;
    copy._autoScrollIdleSeconds = _autoScrollIdleSeconds;
    copy._enableDollarLatex = _enableDollarLatex;
    copy._enableMathRendering = _enableMathRendering;
    copy._enableUserMarkdown = _enableUserMarkdown;
    copy._enableReasoningMarkdown = _enableReasoningMarkdown;
    copy._showChatListDate = _showChatListDate;
    copy._autoCollapseCodeBlock = _autoCollapseCodeBlock;
    copy._autoCollapseCodeBlockLines = _autoCollapseCodeBlockLines;
    copy._desktopAutoSwitchTopics = _desktopAutoSwitchTopics;
    copy._desktopShowTray = _desktopShowTray;
    copy._desktopMinimizeToTrayOnClose = _desktopMinimizeToTrayOnClose;
    copy._usePureBackground = _usePureBackground;
    copy._chatMessageBackgroundStyle = _chatMessageBackgroundStyle;
    return copy;
  }
}

String _normalizeProxyHost(String host) {
  var h = host.trim().toLowerCase();
  if (h.startsWith('[') && h.endsWith(']') && h.length > 2) {
    h = h.substring(1, h.length - 1);
  }
  final zoneIndex = h.indexOf('%');
  if (zoneIndex > 0) {
    h = h.substring(0, zoneIndex);
  }
  if (h.endsWith('.')) {
    h = h.substring(0, h.length - 1);
  }
  return h;
}

bool _shouldBypassProxy(String host, String bypassRules) {
  final h = _normalizeProxyHost(host);
  if (h.isEmpty) return false;

  final rules = bypassRules.split(RegExp(r'[,;\s]+'));
  for (final rawRule in rules) {
    final rule = rawRule.trim();
    if (rule.isEmpty) continue;
    final r = rule.toLowerCase();

    if (r == '*') return true;

    if (r.startsWith('*.') || r.startsWith('*')) {
      final suffix = r.substring(1);
      if (suffix.isNotEmpty && h.endsWith(suffix)) return true;
      continue;
    }

    if (r.contains('/')) {
      final addr = InternetAddress.tryParse(h);
      if (addr != null && _matchesCidr(addr, r)) return true;
      continue;
    }

    if (h == r) return true;
  }

  return false;
}

BigInt _bytesToBigInt(List<int> bytes) {
  var n = BigInt.zero;
  for (final b in bytes) {
    n = (n << 8) | BigInt.from(b);
  }
  return n;
}

BigInt _internetAddressToBigInt(InternetAddress addr) => _bytesToBigInt(addr.rawAddress);

bool _matchesCidr(InternetAddress addr, String cidr) {
  final parts = cidr.split('/');
  if (parts.length != 2) return false;
  final networkStr = parts[0].trim();
  final prefixLen = int.tryParse(parts[1].trim());
  if (prefixLen == null) return false;
  final network = InternetAddress.tryParse(networkStr);
  if (network == null) return false;

  if (addr.type != network.type) return false;
  final totalBits = addr.type == InternetAddressType.IPv4 ? 32 : 128;
  if (prefixLen < 0 || prefixLen > totalBits) return false;

  final mask = prefixLen == 0
      ? BigInt.zero
      : ((BigInt.one << prefixLen) - BigInt.one) << (totalBits - prefixLen);

  final a = _internetAddressToBigInt(addr);
  final n = _internetAddressToBigInt(network);
  return (a & mask) == (n & mask);
}

class _ProxyHttpOverrides extends HttpOverrides {
  final String host;
  final int port;
  final String? username;
  final String? password;
  final String bypassRules;
  _ProxyHttpOverrides({required this.host, required this.port, this.username, this.password, required this.bypassRules});
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.findProxy = (uri) => _shouldBypassProxy(uri.host, bypassRules) ? 'DIRECT' : 'PROXY $host:$port';
    if (username != null && username!.isNotEmpty) {
      client.addProxyCredentials(host, port, '', HttpClientBasicCredentials(username!, password ?? ''));
    }
    return client;
  }
}
class _SocksProxyHttpOverrides extends HttpOverrides {
  final String host;
  final int port;
  final String? username;
  final String? password;
  final String bypassRules;
  _SocksProxyHttpOverrides({required this.host, required this.port, this.username, this.password, required this.bypassRules});
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    Future<InternetAddress?>? proxyAddrFuture;

    ConnectionTask<Socket> directConnection(Uri uri) {
      if (uri.scheme == 'https') {
        final Future<SecureSocket> socket = SecureSocket.connect(uri.host, uri.port, context: context);
        return ConnectionTask.fromSocket(socket, () async => (await socket).close());
      }
      final Future<Socket> socket = Socket.connect(uri.host, uri.port);
      return ConnectionTask.fromSocket(socket, () async => (await socket).close());
    }

    Future<InternetAddress?> resolveProxyAddress() async {
      final parsed = InternetAddress.tryParse(host);
      if (parsed != null) return parsed;
      proxyAddrFuture ??= InternetAddress.lookup(host).then((list) => list.isNotEmpty ? list.first : null);
      try {
        return await proxyAddrFuture;
      } catch (_) {
        return null;
      }
    }

    try {
      client.connectionFactory = (uri, proxyHost, proxyPort) async {
        if (_shouldBypassProxy(uri.host, bypassRules)) {
          return directConnection(uri);
        }

        final proxyAddr = await resolveProxyAddress();
        if (proxyAddr == null) {
          // Preserve previous behavior: if proxy cannot be configured, fall back to direct.
          return directConnection(uri);
        }

        final proxies = <socks.ProxySettings>[
          socks.ProxySettings(proxyAddr, port, username: username, password: password),
        ];

        final socket = socks.SocksTCPClient.connect(
          proxies,
          InternetAddress(uri.host, type: InternetAddressType.unix),
          uri.port,
        );

        if (uri.scheme == 'https') {
          final Future<SecureSocket> secureSocket;
          return ConnectionTask.fromSocket(
            secureSocket = (await socket).secure(uri.host, context: context),
            () async => (await secureSocket).close(),
          );
        }

        return ConnectionTask.fromSocket(
          socket,
          () async => (await socket).close(),
        );
      };
    } catch (_) {
      // ignore
    }
    return client;
  }
}

enum ProviderKind { openai, google, claude }

// Background rendering mode for chat message bubbles
enum ChatMessageBackgroundStyle { defaultStyle, frosted, solid }
enum AndroidBackgroundChatMode { off, on, onNotify }

class ProviderConfig {
  final String id;
  final bool enabled;
  final String name;
  final String apiKey;
  final String baseUrl;
  final ProviderKind? providerType; // Explicit provider type to avoid misclassification
  final String? chatPath; // openai only
  final bool? useResponseApi; // openai only
  final bool? vertexAI; // google only
  final String? location; // google vertex ai only
  final String? projectId; // google vertex ai only
  // Google Vertex AI via service account JSON (paste or import)
  final String? serviceAccountJson; // google vertex ai only
  final List<String> models; // placeholder for future model management
  // Per-model overrides (by logical model key).
  // Each entry may point to an upstream/vendor model id via `apiModelId` so that
  // multiple logical models can share the same backend model with different params.
  // {'<key>': {'apiModelId': String?, 'name': String?, 'type': 'chat'|'embedding', 'input': ['text','image'], 'output': [...], 'abilities': ['tool','reasoning']}}
  final Map<String, dynamic> modelOverrides;
  // Per-provider proxy
  final bool? proxyEnabled;
  final String? proxyHost;
  final String? proxyPort;
  final String? proxyUsername;
  final String? proxyPassword;
  // Custom provider avatar (same scheme as user: emoji | url | file)
  final String? avatarType; // 'emoji' | 'url' | 'file'
  final String? avatarValue;
  // Multi-key mode
  final bool? multiKeyEnabled; // default false
  final List<ApiKeyConfig>? apiKeys; // when enabled
  final KeyManagementConfig? keyManagement;
  // AIhubmix promo header opt-in
  final bool? aihubmixAppCodeEnabled;

  ProviderConfig({
    required this.id,
    required this.enabled,
    required this.name,
    required this.apiKey,
    required this.baseUrl,
    this.providerType,
    this.chatPath,
    this.useResponseApi,
    this.vertexAI,
    this.location,
    this.projectId,
    this.serviceAccountJson,
    this.models = const [],
    this.modelOverrides = const {},
    this.proxyEnabled,
    this.proxyHost,
    this.proxyPort,
    this.proxyUsername,
    this.proxyPassword,
    this.avatarType,
    this.avatarValue,
    this.multiKeyEnabled,
    this.apiKeys,
    this.keyManagement,
    this.aihubmixAppCodeEnabled,
  });

  // Sentinel for copyWith nullability control (allow explicit null set)
  static const Object _sentinel = Object();

  ProviderConfig copyWith({
    String? id,
    bool? enabled,
    String? name,
    String? apiKey,
    String? baseUrl,
    ProviderKind? providerType,
    String? chatPath,
    bool? useResponseApi,
    bool? vertexAI,
    String? location,
    String? projectId,
    String? serviceAccountJson,
    List<String>? models,
    Map<String, dynamic>? modelOverrides,
    bool? proxyEnabled,
    String? proxyHost,
    String? proxyPort,
    String? proxyUsername,
    String? proxyPassword,
    Object? avatarType = _sentinel,
    Object? avatarValue = _sentinel,
    bool? multiKeyEnabled,
    List<ApiKeyConfig>? apiKeys,
    KeyManagementConfig? keyManagement,
    bool? aihubmixAppCodeEnabled,
  }) => ProviderConfig(
        id: id ?? this.id,
        enabled: enabled ?? this.enabled,
        name: name ?? this.name,
        apiKey: apiKey ?? this.apiKey,
        baseUrl: baseUrl ?? this.baseUrl,
        providerType: providerType ?? this.providerType,
        chatPath: chatPath ?? this.chatPath,
        useResponseApi: useResponseApi ?? this.useResponseApi,
        vertexAI: vertexAI ?? this.vertexAI,
        location: location ?? this.location,
        projectId: projectId ?? this.projectId,
        serviceAccountJson: serviceAccountJson ?? this.serviceAccountJson,
        models: models ?? this.models,
        modelOverrides: modelOverrides ?? this.modelOverrides,
        proxyEnabled: proxyEnabled ?? this.proxyEnabled,
        proxyHost: proxyHost ?? this.proxyHost,
        proxyPort: proxyPort ?? this.proxyPort,
        proxyUsername: proxyUsername ?? this.proxyUsername,
        proxyPassword: proxyPassword ?? this.proxyPassword,
        avatarType: (identical(avatarType, _sentinel)) ? this.avatarType : (avatarType as String?),
        avatarValue: (identical(avatarValue, _sentinel)) ? this.avatarValue : (avatarValue as String?),
        multiKeyEnabled: multiKeyEnabled ?? this.multiKeyEnabled,
        apiKeys: apiKeys ?? this.apiKeys,
        keyManagement: keyManagement ?? this.keyManagement,
        aihubmixAppCodeEnabled: aihubmixAppCodeEnabled ?? this.aihubmixAppCodeEnabled,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'enabled': enabled,
        'name': name,
        'apiKey': apiKey,
        'baseUrl': baseUrl,
        'providerType': providerType?.name,
        'chatPath': chatPath,
        'useResponseApi': useResponseApi,
        'vertexAI': vertexAI,
        'location': location,
        'projectId': projectId,
        'serviceAccountJson': serviceAccountJson,
        'models': models,
        'modelOverrides': modelOverrides,
        'proxyEnabled': proxyEnabled,
        'proxyHost': proxyHost,
        'proxyPort': proxyPort,
        'proxyUsername': proxyUsername,
        'proxyPassword': proxyPassword,
        'avatarType': avatarType,
        'avatarValue': avatarValue,
        'multiKeyEnabled': multiKeyEnabled,
        'apiKeys': apiKeys?.map((e) => e.toJson()).toList(),
        'keyManagement': keyManagement?.toJson(),
        'aihubmixAppCodeEnabled': aihubmixAppCodeEnabled,
      };

  factory ProviderConfig.fromJson(Map<String, dynamic> json) => ProviderConfig(
        id: json['id'] as String? ?? (json['name'] as String? ?? ''),
        enabled: json['enabled'] as bool? ?? true,
        name: json['name'] as String? ?? '',
        apiKey: json['apiKey'] as String? ?? '',
        baseUrl: json['baseUrl'] as String? ?? '',
        providerType: json['providerType'] != null 
            ? ProviderKind.values.firstWhere(
                (e) => e.name == json['providerType'],
                orElse: () => classify(json['id'] as String? ?? ''),
              )
            : null,
        chatPath: json['chatPath'] as String?,
        useResponseApi: json['useResponseApi'] as bool?,
        vertexAI: json['vertexAI'] as bool?,
        location: json['location'] as String?,
        projectId: json['projectId'] as String?,
        serviceAccountJson: json['serviceAccountJson'] as String?,
        models: (json['models'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        modelOverrides: (json['modelOverrides'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ?? const {},
        proxyEnabled: json['proxyEnabled'] as bool?,
        proxyHost: json['proxyHost'] as String?,
        proxyPort: json['proxyPort'] as String?,
        proxyUsername: json['proxyUsername'] as String?,
        proxyPassword: json['proxyPassword'] as String?,
        avatarType: json['avatarType'] as String?,
        avatarValue: json['avatarValue'] as String?,
        multiKeyEnabled: json['multiKeyEnabled'] as bool?,
        apiKeys: (json['apiKeys'] as List?)
            ?.whereType<Map>()
            .map((e) => ApiKeyConfig.fromJson(e.cast<String, dynamic>()))
            .toList(),
        keyManagement: KeyManagementConfig.fromJson(
          (json['keyManagement'] as Map?)?.cast<String, dynamic>(),
        ),
        aihubmixAppCodeEnabled: json['aihubmixAppCodeEnabled'] as bool?,
      );

  static ProviderKind classify(String key, {ProviderKind? explicitType}) {
    // If an explicit type is provided, use it
    if (explicitType != null) return explicitType;
    
    // Otherwise, infer from the key
    final k = key.toLowerCase();
    if (k.contains('gemini') || k.contains('google')) return ProviderKind.google;
    if (k.contains('claude') || k.contains('anthropic')) return ProviderKind.claude;
    return ProviderKind.openai;
  }

  static String _defaultBase(String key) {
    final k = key.toLowerCase();
    if (k.contains('tensdaq')) return 'https://tensdaq-api.x-aio.com/v1';
    if (k.contains('kelivoin')) return 'https://text.pollinations.ai/openai';
    if (k.contains('openrouter')) return 'https://openrouter.ai/api/v1';
    if (k.contains('aihubmix')) return 'https://aihubmix.com/v1';
    if (RegExp(r'qwen|aliyun|dashscope').hasMatch(k)) return 'https://dashscope.aliyuncs.com/compatible-mode/v1';
    if (RegExp(r'bytedance|doubao|volces|ark').hasMatch(k)) return 'https://ark.cn-beijing.volces.com/api/v3';
    if (k.contains('silicon')) return 'https://api.siliconflow.cn/v1';
    if (k.contains('grok') || k.contains('x.ai') || k.contains('xai')) return 'https://api.x.ai/v1';
    if (k.contains('deepseek')) return 'https://api.deepseek.com/v1';
    if (RegExp(r'zhipu|智谱|glm').hasMatch(k)) return 'https://open.bigmodel.cn/api/paas/v4';
    if (k.contains('gemini') || k.contains('google')) return 'https://generativelanguage.googleapis.com/v1beta';
    if (k.contains('claude') || k.contains('anthropic')) return 'https://api.anthropic.com/v1';
    return 'https://api.openai.com/v1';
  }

  static ProviderConfig defaultsFor(String key, {String? displayName}) {
    bool _defaultEnabled(String k) {
      final s = k.toLowerCase();
      if (s.contains('tensdaq')) return true;
      if (s.contains('openai')) return true;
      if (s.contains('gemini') || s.contains('google')) return true;
      if (s.contains('silicon')) return true;
      if (s.contains('openrouter')) return true;
      if (s.contains('kelivoin')) return true;
      return false; // others disabled by default
    }
    final kind = classify(key);
    final lowerKey = key.toLowerCase();
    switch (kind) {
      case ProviderKind.google:
        return ProviderConfig(
          id: key,
          enabled: _defaultEnabled(key),
          name: displayName ?? key,
          apiKey: '',
          baseUrl: _defaultBase(key),
          providerType: ProviderKind.google,
          vertexAI: false,
          location: '',
          projectId: '',
          serviceAccountJson: '',
          models: const [],
          modelOverrides: const {},
          proxyEnabled: false,
          proxyHost: '',
          proxyPort: '8080',
          proxyUsername: '',
          proxyPassword: '',
          multiKeyEnabled: false,
          apiKeys: const [],
          keyManagement: const KeyManagementConfig(),
          aihubmixAppCodeEnabled: false,
        );
      case ProviderKind.claude:
        return ProviderConfig(
          id: key,
          enabled: _defaultEnabled(key),
          name: displayName ?? key,
          apiKey: '',
          baseUrl: _defaultBase(key),
          providerType: ProviderKind.claude,
          models: const [],
          modelOverrides: const {},
          proxyEnabled: false,
          proxyHost: '',
          proxyPort: '8080',
          proxyUsername: '',
          proxyPassword: '',
          multiKeyEnabled: false,
          apiKeys: const [],
          keyManagement: const KeyManagementConfig(),
          aihubmixAppCodeEnabled: false,
        );
      case ProviderKind.openai:
      default:
        // Special-case KelivoIN default models and overrides
        if (lowerKey.contains('kelivoin')) {
          return ProviderConfig(
            id: key,
            enabled: _defaultEnabled(key),
            name: displayName ?? key,
            apiKey: 'kelivo',
            baseUrl: _defaultBase(key),
            providerType: ProviderKind.openai,
            chatPath: null, // keep empty in UI; code uses default '/chat/completions'
            useResponseApi: false,
            models: const [
              // 'openai-fast',
              'mistral',
              'qwen-coder',
            ],
            modelOverrides: const {
              // 'openai-fast': {
              //   'type': 'chat',
              //   'input': ['text'],
              //   'output': ['text'],
              //   'abilities': ['tool'],
              // },
              'mistral': {
                'type': 'chat',
                'input': ['text'],
                'output': ['text'],
                'abilities': ['tool'],
              },
              'qwen-coder': {
                'type': 'chat',
                'input': ['text'],
                'output': ['text'],
                'abilities': ['tool'],
              },
            },
            proxyEnabled: false,
            proxyHost: '',
            proxyPort: '8080',
            proxyUsername: '',
            proxyPassword: '',
            multiKeyEnabled: false,
            apiKeys: const [],
            keyManagement: const KeyManagementConfig(),
            aihubmixAppCodeEnabled: false,
          );
        }
        // Special-case SiliconFlow: prefill two partnered models
        if (lowerKey.contains('silicon')) {
          return ProviderConfig(
            id: key,
            enabled: _defaultEnabled(key),
            name: displayName ?? key,
            apiKey: '',
            baseUrl: _defaultBase(key),
            providerType: ProviderKind.openai,
            chatPath: '/chat/completions',
            useResponseApi: false,
            models: const [
              'THUDM/GLM-4-9B-0414',
              'Qwen/Qwen3-8B',
            ],
            modelOverrides: const {
              'THUDM/GLM-4-9B-0414': {
                'type': 'chat',
                'input': ['text'],
                'output': ['text'],
                'abilities': ['tool'],
              },
              'Qwen/Qwen3-8B': {
                'type': 'chat',
                'input': ['text'],
                'output': ['text'],
                'abilities': ['tool', 'reasoning'],
              },
            },
            proxyEnabled: false,
            proxyHost: '',
            proxyPort: '8080',
            proxyUsername: '',
            proxyPassword: '',
            multiKeyEnabled: false,
            apiKeys: const [],
            keyManagement: const KeyManagementConfig(),
            aihubmixAppCodeEnabled: false,
          );
        }
        return ProviderConfig(
          id: key,
          enabled: _defaultEnabled(key),
          name: displayName ?? key,
          apiKey: '',
          baseUrl: _defaultBase(key),
          providerType: ProviderKind.openai,
          chatPath: '/chat/completions',
          useResponseApi: false,
          models: const [],
          modelOverrides: const {},
          proxyEnabled: false,
          proxyHost: '',
          proxyPort: '8080',
          proxyUsername: '',
          proxyPassword: '',
          multiKeyEnabled: false,
          apiKeys: const [],
          keyManagement: const KeyManagementConfig(),
          aihubmixAppCodeEnabled: lowerKey.contains('aihubmix'),
        );
    }
  }
}
