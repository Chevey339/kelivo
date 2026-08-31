import 'dart:convert';
import 'assistant_regex.dart';
import 'health_data_type.dart';
import 'preset_message.dart';

enum MemorySmartAddMode { batched, perItem }

enum MemoryWriteScope {
  alwaysGlobal,
  alwaysAssistant,
  toolDefaultGlobal,
  toolDefaultAssistant,
}

class Assistant {
  static const int defaultRecentChatsSummaryMessageCount = 5;
  static const int defaultMemoryOrganizeEveryNTurns = 1;
  static const int minMemoryOrganizeEveryNTurns = 1;
  static const int maxMemoryOrganizeEveryNTurns = 20;
  static const double defaultTemperature = 1.0;
  static const int minContextMessageSize = 1;
  static const int maxContextMessageSize = 4096;
  static const List<int> recentChatsSummaryMessageCountOptions = <int>[
    1,
    3,
    5,
    10,
    20,
    50,
  ];

  final String id;
  final String name;
  final String? avatar; // path/url/base64, null for initial-letter avatar
  final bool
  useAssistantAvatar; // replace model icon in chat with assistant avatar
  final bool useAssistantName; // replace model name in chat with assistant name
  final String? chatModelProvider; // null -> use global default
  final String? chatModelId; // null -> use global default
  final double? temperature; // null to disable; else 0.0 - 2.0
  final double? topP; // null to disable; else 0.0 - 1.0
  final int contextMessageSize; // number of previous messages to include
  final bool limitContextMessages; // whether to enforce contextMessageSize
  final bool streamOutput; // streaming responses
  final int?
  thinkingBudget; // null = use global/default; 0=off; >0 tokens budget
  final int? maxTokens; // null = unlimited
  final String systemPrompt;
  final String messageTemplate; // e.g. "{{ message }}"
  final bool searchEnabled; // per-assistant external web search switch
  final List<String> mcpServerIds; // bound MCP server IDs
  final List<String> localToolIds; // enabled local tool IDs
  /// HealthKit metric IDs this collaborator may read. Kept when the health
  /// master toggle is off so turning it back on restores the selection.
  final List<String> healthDataTypeIds;
  final String? background; // chat background (color/image ref)
  // Custom request overrides (per assistant)
  final List<Map<String, String>>
  customHeaders; // [{name:'X-Header', value:'v'}]
  final List<Map<String, String>> customBody; // [{key:'foo', value:'{"a":1}'}]
  // Memory features (§4.1)
  final bool enableMemory;
  final bool autoOrganizeMemory;
  final int memoryOrganizeEveryNTurns;
  final MemorySmartAddMode memorySmartAddMode;
  final MemoryWriteScope memoryWriteScope;
  final bool allowPastConversationRecall;
  final bool generateConversationSummary;
  final int
  recentChatsSummaryMessageCount; // refresh summary after N new messages
  final bool appendCurrentTimeToUserMessage;
  // Preset conversation messages (ordered)
  final List<PresetMessage> presetMessages;
  // Regex replacement rules
  final List<AssistantRegex> regexRules;

  const Assistant({
    required this.id,
    required this.name,
    this.avatar,
    this.useAssistantAvatar = false,
    this.useAssistantName = false,
    this.chatModelProvider,
    this.chatModelId,
    this.temperature,
    this.topP,
    this.contextMessageSize = 64,
    this.limitContextMessages = false,
    this.streamOutput = true,
    this.thinkingBudget,
    this.maxTokens,
    this.systemPrompt = '',
    this.messageTemplate = '{{ message }}',
    this.searchEnabled = false,
    this.mcpServerIds = const <String>[],
    this.localToolIds = const <String>[],
    this.healthDataTypeIds = HealthDataTypeIds.defaultSelected,
    this.background,
    this.customHeaders = const <Map<String, String>>[],
    this.customBody = const <Map<String, String>>[],
    this.enableMemory = false,
    this.autoOrganizeMemory = false,
    this.memoryOrganizeEveryNTurns = defaultMemoryOrganizeEveryNTurns,
    this.memorySmartAddMode = MemorySmartAddMode.batched,
    this.memoryWriteScope = MemoryWriteScope.alwaysGlobal,
    this.allowPastConversationRecall = false,
    this.generateConversationSummary = false,
    this.recentChatsSummaryMessageCount = defaultRecentChatsSummaryMessageCount,
    this.appendCurrentTimeToUserMessage = false,
    this.presetMessages = const <PresetMessage>[],
    this.regexRules = const <AssistantRegex>[],
  });

  Assistant copyWith({
    String? id,
    String? name,
    String? avatar,
    bool? useAssistantAvatar,
    bool? useAssistantName,
    String? chatModelProvider,
    String? chatModelId,
    double? temperature,
    double? topP,
    int? contextMessageSize,
    bool? limitContextMessages,
    bool? streamOutput,
    int? thinkingBudget,
    int? maxTokens,
    String? systemPrompt,
    String? messageTemplate,
    bool? searchEnabled,
    List<String>? mcpServerIds,
    List<String>? localToolIds,
    List<String>? healthDataTypeIds,
    String? background,
    List<Map<String, String>>? customHeaders,
    List<Map<String, String>>? customBody,
    bool? enableMemory,
    bool? autoOrganizeMemory,
    int? memoryOrganizeEveryNTurns,
    MemorySmartAddMode? memorySmartAddMode,
    MemoryWriteScope? memoryWriteScope,
    bool? allowPastConversationRecall,
    bool? generateConversationSummary,
    int? recentChatsSummaryMessageCount,
    bool? appendCurrentTimeToUserMessage,
    List<PresetMessage>? presetMessages,
    List<AssistantRegex>? regexRules,
    bool clearChatModel = false,
    bool clearAvatar = false,
    bool clearTemperature = false,
    bool clearTopP = false,
    bool clearThinkingBudget = false,
    bool clearMaxTokens = false,
    bool clearBackground = false,
  }) {
    return Assistant(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: clearAvatar ? null : (avatar ?? this.avatar),
      useAssistantAvatar: useAssistantAvatar ?? this.useAssistantAvatar,
      useAssistantName: useAssistantName ?? this.useAssistantName,
      chatModelProvider: clearChatModel
          ? null
          : (chatModelProvider ?? this.chatModelProvider),
      chatModelId: clearChatModel ? null : (chatModelId ?? this.chatModelId),
      temperature: clearTemperature ? null : (temperature ?? this.temperature),
      topP: clearTopP ? null : (topP ?? this.topP),
      contextMessageSize: contextMessageSize ?? this.contextMessageSize,
      limitContextMessages: limitContextMessages ?? this.limitContextMessages,
      streamOutput: streamOutput ?? this.streamOutput,
      thinkingBudget: clearThinkingBudget
          ? null
          : (thinkingBudget ?? this.thinkingBudget),
      maxTokens: clearMaxTokens ? null : (maxTokens ?? this.maxTokens),
      systemPrompt: systemPrompt ?? this.systemPrompt,
      messageTemplate: messageTemplate ?? this.messageTemplate,
      searchEnabled: searchEnabled ?? this.searchEnabled,
      mcpServerIds: mcpServerIds ?? this.mcpServerIds,
      localToolIds: localToolIds ?? this.localToolIds,
      healthDataTypeIds: healthDataTypeIds ?? this.healthDataTypeIds,
      background: clearBackground ? null : (background ?? this.background),
      customHeaders: customHeaders ?? this.customHeaders,
      customBody: customBody ?? this.customBody,
      enableMemory: enableMemory ?? this.enableMemory,
      autoOrganizeMemory: autoOrganizeMemory ?? this.autoOrganizeMemory,
      memoryOrganizeEveryNTurns:
          memoryOrganizeEveryNTurns ?? this.memoryOrganizeEveryNTurns,
      memorySmartAddMode: memorySmartAddMode ?? this.memorySmartAddMode,
      memoryWriteScope: memoryWriteScope ?? this.memoryWriteScope,
      allowPastConversationRecall:
          allowPastConversationRecall ?? this.allowPastConversationRecall,
      generateConversationSummary:
          generateConversationSummary ?? this.generateConversationSummary,
      recentChatsSummaryMessageCount:
          recentChatsSummaryMessageCount ?? this.recentChatsSummaryMessageCount,
      appendCurrentTimeToUserMessage:
          appendCurrentTimeToUserMessage ?? this.appendCurrentTimeToUserMessage,
      presetMessages: presetMessages ?? this.presetMessages,
      regexRules: regexRules ?? this.regexRules,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'avatar': avatar,
    'useAssistantAvatar': useAssistantAvatar,
    'useAssistantName': useAssistantName,
    'chatModelProvider': chatModelProvider,
    'chatModelId': chatModelId,
    'temperature': temperature,
    'topP': topP,
    'contextMessageSize': contextMessageSize,
    'limitContextMessages': limitContextMessages,
    'streamOutput': streamOutput,
    'thinkingBudget': thinkingBudget,
    'maxTokens': maxTokens,
    'systemPrompt': systemPrompt,
    'messageTemplate': messageTemplate,
    'searchEnabled': searchEnabled,
    'mcpServerIds': mcpServerIds,
    'localToolIds': localToolIds,
    'healthDataTypeIds': healthDataTypeIds,
    'background': background,
    'customHeaders': customHeaders,
    'customBody': customBody,
    'enableMemory': enableMemory,
    'autoOrganizeMemory': autoOrganizeMemory,
    'memoryOrganizeEveryNTurns': memoryOrganizeEveryNTurns,
    'memorySmartAddMode': memorySmartAddModeToString(memorySmartAddMode),
    'memoryWriteScope': memoryWriteScopeToString(memoryWriteScope),
    'allowPastConversationRecall': allowPastConversationRecall,
    'generateConversationSummary': generateConversationSummary,
    'recentChatsSummaryMessageCount': recentChatsSummaryMessageCount,
    'appendCurrentTimeToUserMessage': appendCurrentTimeToUserMessage,
    'presetMessages': PresetMessage.encodeList(presetMessages),
    'regexRules': regexRules.map((e) => e.toJson()).toList(),
  };

  static Assistant fromJson(Map<String, dynamic> json) => Assistant(
    id: json['id'] as String,
    name: (json['name'] as String?) ?? '',
    avatar: json['avatar'] as String?,
    useAssistantAvatar: json['useAssistantAvatar'] as bool? ?? false,
    useAssistantName: json['useAssistantName'] as bool? ?? false,
    chatModelProvider: json['chatModelProvider'] as String?,
    chatModelId: json['chatModelId'] as String?,
    temperature: (json['temperature'] as num?)?.toDouble(),
    topP: (json['topP'] as num?)?.toDouble(),
    contextMessageSize: (json['contextMessageSize'] as num?)?.toInt() ?? 64,
    limitContextMessages: json['limitContextMessages'] as bool? ?? false,
    streamOutput: json['streamOutput'] as bool? ?? true,
    thinkingBudget: (json['thinkingBudget'] as num?)?.toInt(),
    maxTokens: (json['maxTokens'] as num?)?.toInt(),
    systemPrompt: (json['systemPrompt'] as String?) ?? '',
    messageTemplate: (json['messageTemplate'] as String?) ?? '{{ message }}',
    searchEnabled: json['searchEnabled'] as bool? ?? false,
    mcpServerIds:
        (json['mcpServerIds'] as List?)?.cast<String>() ?? const <String>[],
    localToolIds:
        (json['localToolIds'] as List?)?.cast<String>() ?? const <String>[],
    healthDataTypeIds: HealthDataTypeIds.parseStoredIds(
      json['healthDataTypeIds'],
    ),
    background: json['background'] as String?,
    customHeaders: (() {
      final raw = json['customHeaders'];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map(
              (e) => {
                'name': (e['name'] ?? e['key'] ?? '').toString(),
                'value': (e['value'] ?? '').toString(),
              },
            )
            .toList();
      }
      return const <Map<String, String>>[];
    })(),
    customBody: (() {
      final raw = json['customBody'];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map(
              (e) => {
                'key': (e['key'] ?? e['name'] ?? '').toString(),
                'value': (e['value'] ?? '').toString(),
              },
            )
            .toList();
      }
      return const <Map<String, String>>[];
    })(),
    enableMemory: json['enableMemory'] as bool? ?? false,
    autoOrganizeMemory: json['autoOrganizeMemory'] as bool? ?? false,
    memoryOrganizeEveryNTurns: (() {
      final raw = (json['memoryOrganizeEveryNTurns'] as num?)?.toInt();
      if (raw == null ||
          raw < minMemoryOrganizeEveryNTurns ||
          raw > maxMemoryOrganizeEveryNTurns) {
        return defaultMemoryOrganizeEveryNTurns;
      }
      return raw;
    })(),
    memorySmartAddMode: memorySmartAddModeFromString(
      json['memorySmartAddMode'] as String?,
    ),
    memoryWriteScope: memoryWriteScopeFromString(
      json['memoryWriteScope'] as String?,
    ),
    // Legacy `enableRecentChatsReference` maps onto allowPastConversationRecall.
    allowPastConversationRecall:
        json['allowPastConversationRecall'] as bool? ??
        json['enableRecentChatsReference'] as bool? ??
        false,
    generateConversationSummary:
        json['generateConversationSummary'] as bool? ?? false,
    recentChatsSummaryMessageCount: (() {
      final raw = (json['recentChatsSummaryMessageCount'] as num?)?.toInt();
      if (raw == null || raw < 1) {
        return defaultRecentChatsSummaryMessageCount;
      }
      return raw;
    })(),
    appendCurrentTimeToUserMessage:
        json['appendCurrentTimeToUserMessage'] as bool? ?? false,
    presetMessages: (() {
      try {
        return PresetMessage.decodeList(json['presetMessages']);
      } catch (_) {
        return const <PresetMessage>[];
      }
    })(),
    regexRules: (() {
      final raw = json['regexRules'];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((e) => AssistantRegex.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
      return const <AssistantRegex>[];
    })(),
  );

  static String memorySmartAddModeToString(MemorySmartAddMode mode) {
    switch (mode) {
      case MemorySmartAddMode.batched:
        return 'batched';
      case MemorySmartAddMode.perItem:
        return 'perItem';
    }
  }

  static MemorySmartAddMode memorySmartAddModeFromString(String? value) {
    switch (value) {
      case 'perItem':
        return MemorySmartAddMode.perItem;
      case 'batched':
      default:
        return MemorySmartAddMode.batched;
    }
  }

  static String memoryWriteScopeToString(MemoryWriteScope scope) {
    switch (scope) {
      case MemoryWriteScope.alwaysGlobal:
        return 'alwaysGlobal';
      case MemoryWriteScope.alwaysAssistant:
        return 'alwaysAssistant';
      case MemoryWriteScope.toolDefaultGlobal:
        return 'toolDefaultGlobal';
      case MemoryWriteScope.toolDefaultAssistant:
        return 'toolDefaultAssistant';
    }
  }

  static MemoryWriteScope memoryWriteScopeFromString(String? value) {
    switch (value) {
      case 'alwaysAssistant':
        return MemoryWriteScope.alwaysAssistant;
      case 'toolDefaultGlobal':
        return MemoryWriteScope.toolDefaultGlobal;
      case 'toolDefaultAssistant':
        return MemoryWriteScope.toolDefaultAssistant;
      case 'alwaysGlobal':
      default:
        return MemoryWriteScope.alwaysGlobal;
    }
  }

  static String encodeList(List<Assistant> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());
  static List<Assistant> decodeList(String raw) {
    try {
      final arr = jsonDecode(raw) as List<dynamic>;
      return [
        for (final e in arr) Assistant.fromJson(e as Map<String, dynamic>),
      ];
    } catch (_) {
      return const <Assistant>[];
    }
  }
}
