import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import '../services/search/search_service.dart';
import '../models/api_keys.dart';
import '../models/backup.dart';
import '../services/icloud_sync_service.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _providersOrderKey = 'providers_order_v1';
  static const String _themeModeKey = 'theme_mode_v1';
  static const String _providerConfigsKey = 'provider_configs_v1';
  static const String _pinnedModelsKey = 'pinned_models_v1';
  static const String _selectedModelKey = 'selected_model_v1';
  static const String _titleModelKey = 'title_model_v1';
  static const String _titlePromptKey = 'title_prompt_v1';
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
  static const String _displayHapticsOnGenerateKey = 'display_haptics_on_generate_v1';
  static const String _displayHapticsOnDrawerKey = 'display_haptics_on_drawer_v1';
  static const String _displayShowAppUpdatesKey = 'display_show_app_updates_v1';
  static const String _displayNewChatOnLaunchKey = 'display_new_chat_on_launch_v1';
  static const String _displayChatFontScaleKey = 'display_chat_font_scale_v1';
  static const String _displayAutoScrollIdleSecondsKey = 'display_auto_scroll_idle_seconds_v1';
  static const String _displayEnableDollarLatexKey = 'display_enable_dollar_latex_v1';
  static const String _displayEnableMathRenderingKey = 'display_enable_math_rendering_v1';
  static const String _displayEnableUserMarkdownKey = 'display_enable_user_markdown_v1';
  static const String _displayEnableReasoningMarkdownKey = 'display_enable_reasoning_markdown_v1';
  static const String _appLocaleKey = 'app_locale_v1';
  static const String _translateModelKey = 'translate_model_v1';
  static const String _translatePromptKey = 'translate_prompt_v1';
  static const String _learningModeEnabledKey = 'learning_mode_enabled_v1';
  static const String _learningModePromptKey = 'learning_mode_prompt_v1';
  static const String _searchServicesKey = 'search_services_v1';
  static const String _searchCommonKey = 'search_common_v1';
  static const String _searchSelectedKey = 'search_selected_v1';
  static const String _searchEnabledKey = 'search_enabled_v1';
  static const String _webDavConfigKey = 'webdav_config_v1';
  static const String _iCloudSyncEnabledKey = 'icloud_sync_enabled_v1';

  List<String> _providersOrder = const [];
  List<String> get providersOrder => _providersOrder;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;
  // Theme palette & dynamic color
  String _themePaletteId = 'default';
  String get themePaletteId => _themePaletteId;
  bool _useDynamicColor = true; // when supported on Android
  bool get useDynamicColor => _useDynamicColor;
  bool _dynamicColorSupported = false; // runtime capability, not persisted
  bool get dynamicColorSupported => _dynamicColorSupported;

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
  // Ephemeral connection test results: serviceId -> connected (true), failed (false), or null (not tested)
  final Map<String, bool?> _searchConnection = <String, bool?>{};
  Map<String, bool?> get searchConnection => Map.unmodifiable(_searchConnection);

  bool _icloudSyncEnabled = false;
  bool get icloudSyncEnabled => _icloudSyncEnabled;
  bool get supportsICloudSync => ICloudSyncService.instance.isSupported;

  bool _loading = false;
  bool _pendingReload = false;

  SettingsProvider() {
    _load();
    if (supportsICloudSync) {
      ICloudSyncService.instance.addListener(_handleICloudUpdate);
    }
  }

  Future<void> _load() async {
    if (_loading) {
      _pendingReload = true;
      return;
    }
    _loading = true;
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
    _hapticsOnGenerate = prefs.getBool(_displayHapticsOnGenerateKey) ?? false;
    _hapticsOnDrawer = prefs.getBool(_displayHapticsOnDrawerKey) ?? true;
    _showAppUpdates = prefs.getBool(_displayShowAppUpdatesKey) ?? true;
    _newChatOnLaunch = prefs.getBool(_displayNewChatOnLaunchKey) ?? true;
    _chatFontScale = prefs.getDouble(_displayChatFontScaleKey) ?? 1.0;
    _autoScrollIdleSeconds = prefs.getInt(_displayAutoScrollIdleSecondsKey) ?? 8;
    // display: markdown/math rendering
    _enableDollarLatex = prefs.getBool(_displayEnableDollarLatexKey) ?? true;
    _enableMathRendering = prefs.getBool(_displayEnableMathRenderingKey) ?? true;
    _enableUserMarkdown = prefs.getBool(_displayEnableUserMarkdownKey) ?? true;
    _enableReasoningMarkdown = prefs.getBool(_displayEnableReasoningMarkdownKey) ?? true;
    // Load app locale; default to follow system on first launch
    _appLocaleTag = prefs.getString(_appLocaleKey);
    if (_appLocaleTag == null || _appLocaleTag!.isEmpty) {
      _appLocaleTag = 'system';
      await prefs.setString(_appLocaleKey, 'system');
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
    // webdav config
    final webdavStr = prefs.getString(_webDavConfigKey);
    if (webdavStr != null && webdavStr.isNotEmpty) {
      try { _webDavConfig = WebDavConfig.fromJson(jsonDecode(webdavStr) as Map<String, dynamic>); } catch (_) {}
    }
    _icloudSyncEnabled = prefs.getBool(_iCloudSyncEnabledKey) ?? false;
    await _applyICloudSyncSetting();
    if (_providerConfigs.isEmpty) {
      // Seed a couple of sensible defaults on first launch, but do not recreate
      // providers implicitly during later reads (e.g., when switching chats).
      ensureProviderConfig('KelivoIN', defaultName: 'KelivoIN');
      ensureProviderConfig('Tensdaq', defaultName: 'Tensdaq');
      ensureProviderConfig('SiliconFlow', defaultName: 'SiliconFlow');
    }
    
    // kick off a one-time connectivity test for services (exclude local Bing)
    _initSearchConnectivityTests();

    notifyListeners();
    _loading = false;
    if (_pendingReload) {
      _pendingReload = false;
      unawaited(_load());
    }
  }

  Future<void> _applyICloudSyncSetting() async {
    if (!supportsICloudSync) {
      await ICloudSyncService.instance.disable();
      return;
    }
    if (_icloudSyncEnabled) {
      await ICloudSyncService.instance.enable();
    } else {
      await ICloudSyncService.instance.disable();
    }
  }

  void _handleICloudUpdate() {
    unawaited(_load());
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

  Future<void> setICloudSyncEnabled(bool enabled) async {
    if (!supportsICloudSync) return;
    if (_icloudSyncEnabled == enabled) return;
    _icloudSyncEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_iCloudSyncEnabledKey, enabled);
    await _applyICloudSyncSetting();
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
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_providersOrderKey, _providersOrder);
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

  Future<void> removeProviderConfig(String key) async {
    if (!_providerConfigs.containsKey(key)) return;
    _providerConfigs.remove(key);
    // Remove from order
    _providersOrder = List<String>.from(_providersOrder.where((k) => k != key));

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

  Future<void> setTranslateModel(String providerKey, String modelId) async {
    _translateModelProvider = providerKey;
    _translateModelId = modelId;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_translateModelKey, '$providerKey::$modelId');
  }

  Future<void> setTranslatePrompt(String prompt) async {
    _translatePrompt = prompt.trim().isEmpty ? defaultTranslatePrompt : prompt;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_translatePromptKey, _translatePrompt);
  }

  Future<void> resetTranslatePrompt() async => setTranslatePrompt(defaultTranslatePrompt);

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

  // Display: chat font scale (0.8 - 1.5, default 1.0)
  double _chatFontScale = 1.0;
  double get chatFontScale => _chatFontScale;
  Future<void> setChatFontScale(double scale) async {
    final s = scale.clamp(0.8, 1.5);
    if (_chatFontScale == s) return;
    _chatFontScale = s;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_displayChatFontScaleKey, _chatFontScale);
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
  }

  SettingsProvider copyWith({
    List<SearchServiceOptions>? searchServices,
    SearchCommonOptions? searchCommonOptions,
    int? searchServiceSelected,
    bool? searchEnabled,
  }) {
    final copy = SettingsProvider();
    copy._searchServices = searchServices ?? _searchServices;
    copy._searchCommonOptions = searchCommonOptions ?? _searchCommonOptions;
    copy._searchServiceSelected = searchServiceSelected ?? _searchServiceSelected;
    copy._searchEnabled = searchEnabled ?? _searchEnabled;
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
    copy._thinkingBudget = _thinkingBudget;
    copy._showUserAvatar = _showUserAvatar;
    copy._showModelIcon = _showModelIcon;
    copy._showModelNameTimestamp = _showModelNameTimestamp;
    copy._showTokenStats = _showTokenStats;
    copy._showUserNameTimestamp = _showUserNameTimestamp;
    copy._showUserMessageActions = _showUserMessageActions;
    copy._autoCollapseThinking = _autoCollapseThinking;
    copy._showMessageNavButtons = _showMessageNavButtons;
    copy._hapticsOnGenerate = _hapticsOnGenerate;
    copy._hapticsOnDrawer = _hapticsOnDrawer;
    copy._showAppUpdates = _showAppUpdates;
    copy._newChatOnLaunch = _newChatOnLaunch;
    copy._chatFontScale = _chatFontScale;
    copy._autoScrollIdleSeconds = _autoScrollIdleSeconds;
    copy._enableDollarLatex = _enableDollarLatex;
    copy._enableMathRendering = _enableMathRendering;
    copy._enableUserMarkdown = _enableUserMarkdown;
    copy._enableReasoningMarkdown = _enableReasoningMarkdown;
    return copy;
  }

  @override
  void dispose() {
    if (supportsICloudSync) {
      ICloudSyncService.instance.removeListener(_handleICloudUpdate);
    }
    super.dispose();
  }
}

enum ProviderKind { openai, google, claude }

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
  // Per-model overrides (by model id)
  // {'<modelId>': {'name': String?, 'type': 'chat'|'embedding', 'input': ['text','image'], 'output': [...], 'abilities': ['tool','reasoning']}}
  final Map<String, dynamic> modelOverrides;
  // Per-provider proxy
  final bool? proxyEnabled;
  final String? proxyHost;
  final String? proxyPort;
  final String? proxyUsername;
  final String? proxyPassword;
  // Multi-key mode
  final bool? multiKeyEnabled; // default false
  final List<ApiKeyConfig>? apiKeys; // when enabled
  final KeyManagementConfig? keyManagement;

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
    this.multiKeyEnabled,
    this.apiKeys,
    this.keyManagement,
  });

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
    bool? multiKeyEnabled,
    List<ApiKeyConfig>? apiKeys,
    KeyManagementConfig? keyManagement,
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
        multiKeyEnabled: multiKeyEnabled ?? this.multiKeyEnabled,
        apiKeys: apiKeys ?? this.apiKeys,
        keyManagement: keyManagement ?? this.keyManagement,
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
        'multiKeyEnabled': multiKeyEnabled,
        'apiKeys': apiKeys?.map((e) => e.toJson()).toList(),
        'keyManagement': keyManagement?.toJson(),
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
        multiKeyEnabled: json['multiKeyEnabled'] as bool?,
        apiKeys: (json['apiKeys'] as List?)
            ?.whereType<Map>()
            .map((e) => ApiKeyConfig.fromJson(e.cast<String, dynamic>()))
            .toList(),
        keyManagement: KeyManagementConfig.fromJson(
          (json['keyManagement'] as Map?)?.cast<String, dynamic>(),
        ),
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
        );
    }
  }
}
