import 'dart:convert';
import 'assistant_regex.dart';
import 'preset_message.dart';

class Assistant {
  static const int defaultRecentChatsSummaryMessageCount = 5;
  static const int minContextMessageSize = 1;
  static const int maxContextMessageSize = 1024;
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
  final String? background; // chat background (color/image ref)
  // Custom request overrides (per assistant)
  final List<Map<String, String>>
  customHeaders; // [{name:'X-Header', value:'v'}]
  final List<Map<String, String>> customBody; // [{key:'foo', value:'{"a":1}'}]
  // Memory features
  final bool enableMemory; // assistant memory feature switch
  final bool enableRecentChatsReference; // include recent chat titles in prompt
  final int
  recentChatsSummaryMessageCount; // refresh summary after N new messages
  // Preset conversation messages (ordered)
  final List<PresetMessage> presetMessages;
  // Regex replacement rules
  final List<AssistantRegex> regexRules;
  // Proactive care ("Ta的来信")
  final bool enableProactiveCare;
  final DateTime? proactiveCareNextMessageAt;
  final String proactiveCarePrompt;
  final String proactiveCareDecisionPrompt;

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
    this.limitContextMessages = true,
    this.streamOutput = true,
    this.thinkingBudget,
    this.maxTokens,
    this.systemPrompt = '',
    this.messageTemplate = '{{ message }}',
    this.searchEnabled = false,
    this.mcpServerIds = const <String>[],
    this.localToolIds = const <String>[],
    this.background,
    this.customHeaders = const <Map<String, String>>[],
    this.customBody = const <Map<String, String>>[],
    this.enableMemory = false,
    this.enableRecentChatsReference = false,
    this.recentChatsSummaryMessageCount = defaultRecentChatsSummaryMessageCount,
    this.presetMessages = const <PresetMessage>[],
    this.regexRules = const <AssistantRegex>[],
    this.enableProactiveCare = false,
    this.proactiveCareNextMessageAt,
    this.proactiveCarePrompt = '',
    this.proactiveCareDecisionPrompt = '',
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
    String? background,
    List<Map<String, String>>? customHeaders,
    List<Map<String, String>>? customBody,
    bool? enableMemory,
    bool? enableRecentChatsReference,
    int? recentChatsSummaryMessageCount,
    List<PresetMessage>? presetMessages,
    List<AssistantRegex>? regexRules,
    bool? enableProactiveCare,
    DateTime? proactiveCareNextMessageAt,
    String? proactiveCarePrompt,
    String? proactiveCareDecisionPrompt,
    bool clearProactiveCareNextMessageAt = false,
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
      background: clearBackground ? null : (background ?? this.background),
      customHeaders: customHeaders ?? this.customHeaders,
      customBody: customBody ?? this.customBody,
      enableMemory: enableMemory ?? this.enableMemory,
      enableRecentChatsReference:
          enableRecentChatsReference ?? this.enableRecentChatsReference,
      recentChatsSummaryMessageCount:
          recentChatsSummaryMessageCount ?? this.recentChatsSummaryMessageCount,
      presetMessages: presetMessages ?? this.presetMessages,
      regexRules: regexRules ?? this.regexRules,
      enableProactiveCare: enableProactiveCare ?? this.enableProactiveCare,
      proactiveCareNextMessageAt: clearProactiveCareNextMessageAt
          ? null
          : (proactiveCareNextMessageAt ?? this.proactiveCareNextMessageAt),
      proactiveCarePrompt: proactiveCarePrompt ?? this.proactiveCarePrompt,
      proactiveCareDecisionPrompt:
          proactiveCareDecisionPrompt ?? this.proactiveCareDecisionPrompt,
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
    'background': background,
    'customHeaders': customHeaders,
    'customBody': customBody,
    'enableMemory': enableMemory,
    'enableRecentChatsReference': enableRecentChatsReference,
    'recentChatsSummaryMessageCount': recentChatsSummaryMessageCount,
    'presetMessages': PresetMessage.encodeList(presetMessages),
    'regexRules': regexRules.map((e) => e.toJson()).toList(),
    'enableProactiveCare': enableProactiveCare,
    'proactiveCareNextMessageAt': proactiveCareNextMessageAt?.toIso8601String(),
    'proactiveCarePrompt': proactiveCarePrompt,
    'proactiveCareDecisionPrompt': proactiveCareDecisionPrompt,
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
    limitContextMessages: json['limitContextMessages'] as bool? ?? true,
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
    enableRecentChatsReference:
        json['enableRecentChatsReference'] as bool? ?? false,
    recentChatsSummaryMessageCount: (() {
      final raw = (json['recentChatsSummaryMessageCount'] as num?)?.toInt();
      if (raw == null || raw < 1) {
        return defaultRecentChatsSummaryMessageCount;
      }
      return raw;
    })(),
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
    enableProactiveCare: json['enableProactiveCare'] as bool? ?? false,
    proactiveCareNextMessageAt: (() {
      final raw = json['proactiveCareNextMessageAt'];
      if (raw is! String || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    })(),
    proactiveCarePrompt: (json['proactiveCarePrompt'] as String?) ?? '',
    proactiveCareDecisionPrompt:
        (json['proactiveCareDecisionPrompt'] as String?) ?? '',
  );

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
