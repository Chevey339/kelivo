import 'dart:convert';
import 'package:crypto/crypto.dart';

String contextTextReference(String messageId, int ordinal, String callId) =>
    'ctx_${sha256.convert(utf8.encode('$messageId:$ordinal:$callId')).toString().substring(0, 24)}';

enum AutoCompressionMode { off, notify, auto }

/// Resolved values. A conversation stores only its overrides; absence inherits
/// the current global value, including an explicit `off` override.
class CompressionConfig {
  const CompressionConfig({
    this.mode = AutoCompressionMode.off,
    this.nativeEnabled = false,
    this.nativeKeepRecentUserTurns = 6,
    this.nativeTriggerInputRatio = .8,
    this.templateId = 'general',
    this.keepRecentUserTurns = 6,
    this.triggerInputRatio = .8,
    this.targetInputRatio = .6,
    this.summaryTokens = 4096,
    this.maxOutputTokens,
    this.maxRequestAttempts = 8,
    this.requestTimeoutMinutes,
    this.planningWindow,
    this.includeReference = true,
    this.replaceConsumedTools = false,
    this.summaryInWorldBookScan = true,
    this.providerId,
    this.modelId,
  });

  static const conversationKind = 'conversationCompression';
  final AutoCompressionMode mode;
  final bool nativeEnabled;
  final int nativeKeepRecentUserTurns;
  final double nativeTriggerInputRatio;
  final String templateId;
  final int keepRecentUserTurns;
  final double triggerInputRatio;
  final double targetInputRatio;
  final int summaryTokens;

  /// Total generation budget, including reasoning. Null uses the summary target.
  final int? maxOutputTokens;
  final int maxRequestAttempts;

  /// Per model invocation. Null preserves each compression mode's default.
  final num? requestTimeoutMinutes;
  Duration? get requestTimeout => requestTimeoutMinutes == null
      ? null
      : Duration(
          microseconds:
              (requestTimeoutMinutes! * Duration.microsecondsPerMinute).ceil(),
        );
  final int? planningWindow;
  final bool includeReference;
  final bool replaceConsumedTools;
  final bool summaryInWorldBookScan;
  final String? providerId;
  final String? modelId;

  CompressionConfig withOverrides(Map<String, dynamic> overrides) =>
      CompressionConfig.fromJson({...toJson(), ...overrides});

  Map<String, dynamic> toJson({bool includeMode = true}) => {
    if (includeMode) 'mode': mode.name,
    'nativeEnabled': nativeEnabled,
    'nativeKeepRecentUserTurns': nativeKeepRecentUserTurns,
    'nativeTriggerInputRatio': nativeTriggerInputRatio,
    'templateId': templateId,
    'keepRecentUserTurns': keepRecentUserTurns,
    'triggerInputRatio': triggerInputRatio,
    'targetInputRatio': targetInputRatio,
    'summaryTokens': summaryTokens,
    'maxOutputTokens': maxOutputTokens,
    'maxRequestAttempts': maxRequestAttempts,
    'requestTimeoutMinutes': requestTimeoutMinutes,
    'planningWindow': planningWindow,
    'includeReference': includeReference,
    'replaceConsumedTools': replaceConsumedTools,
    'summaryInWorldBookScan': summaryInWorldBookScan,
    'providerId': providerId,
    'modelId': modelId,
  };

  factory CompressionConfig.fromJson(Map<String, dynamic> json) {
    final config = CompressionConfig(
      mode: AutoCompressionMode.values.byName(json['mode'] as String? ?? 'off'),
      nativeEnabled: json['nativeEnabled'] == true,
      nativeKeepRecentUserTurns: json['nativeKeepRecentUserTurns'] as int? ?? 6,
      nativeTriggerInputRatio: (json['nativeTriggerInputRatio'] as num? ?? .8)
          .toDouble(),
      templateId: json['templateId'] as String? ?? 'general',
      keepRecentUserTurns: json['keepRecentUserTurns'] as int? ?? 6,
      triggerInputRatio: (json['triggerInputRatio'] as num? ?? .8).toDouble(),
      targetInputRatio: (json['targetInputRatio'] as num? ?? .6).toDouble(),
      summaryTokens: json['summaryTokens'] as int? ?? 4096,
      maxOutputTokens: json['maxOutputTokens'] as int?,
      maxRequestAttempts: json['maxRequestAttempts'] as int? ?? 8,
      requestTimeoutMinutes: json['requestTimeoutMinutes'] as num?,
      planningWindow: json['planningWindow'] as int?,
      includeReference: json['includeReference'] as bool? ?? true,
      replaceConsumedTools: json['replaceConsumedTools'] as bool? ?? false,
      summaryInWorldBookScan: json['summaryInWorldBookScan'] as bool? ?? true,
      providerId: json['providerId'] as String?,
      modelId: json['modelId'] as String?,
    );
    if (config.templateId.isEmpty ||
        config.nativeKeepRecentUserTurns < 0 ||
        config.nativeKeepRecentUserTurns > 10000 ||
        !config.nativeTriggerInputRatio.isFinite ||
        config.nativeTriggerInputRatio <= 0 ||
        config.nativeTriggerInputRatio >= 1 ||
        config.keepRecentUserTurns < 0 ||
        config.keepRecentUserTurns > 10000 ||
        !config.triggerInputRatio.isFinite ||
        !config.targetInputRatio.isFinite ||
        config.targetInputRatio <= 0 ||
        config.triggerInputRatio >= 1 ||
        config.targetInputRatio >= config.triggerInputRatio ||
        config.summaryTokens < 128 ||
        config.summaryTokens > 65536 ||
        (config.maxOutputTokens != null &&
            (config.maxOutputTokens! < config.summaryTokens ||
                config.maxOutputTokens! > 1048576)) ||
        config.maxRequestAttempts < 1 ||
        config.maxRequestAttempts > 128 ||
        (config.requestTimeoutMinutes != null &&
            (!config.requestTimeoutMinutes!.isFinite ||
                config.requestTimeoutMinutes! <= 0 ||
                !(config.requestTimeoutMinutes! *
                        Duration.microsecondsPerMinute)
                    .isFinite)) ||
        (config.planningWindow != null && config.planningWindow! < 1024) ||
        (config.providerId == null) != (config.modelId == null)) {
      throw const FormatException('Invalid compression settings');
    }
    return config;
  }
}

class CompressionTemplate {
  const CompressionTemplate({
    required this.id,
    required this.name,
    required this.prompt,
    this.scene = 'general',
    this.outputLanguage = 'conversation',
    this.builtIn = false,
  });
  static const entityKind = 'compressionTemplate';
  final String id;
  final String name;
  final String prompt;
  final String scene;

  /// `conversation`, `legacy` (UI locale), or an explicitly selected language.
  final String outputLanguage;
  final bool builtIn;

  Map<String, dynamic> toJson() => {
    'formatVersion': 1,
    'id': id,
    'name': name,
    'prompt': prompt,
    'scene': scene,
    'outputLanguage': outputLanguage,
  };

  factory CompressionTemplate.fromJson(
    Map<String, dynamic> json, {
    bool builtIn = false,
  }) {
    if (json['formatVersion'] != 1 ||
        json['name'] is! String ||
        (json['name'] as String).trim().isEmpty ||
        json['prompt'] is! String ||
        (json['prompt'] as String).trim().isEmpty ||
        (json['prompt'] as String).length > 200000) {
      throw const FormatException('Invalid compression template');
    }
    return CompressionTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      prompt: json['prompt'] as String,
      scene: json['scene'] as String? ?? 'general',
      outputLanguage: json['outputLanguage'] as String? ?? 'conversation',
      builtIn: builtIn,
    );
  }
}

class CompressionRecipe {
  const CompressionRecipe({
    required this.id,
    required this.name,
    required this.template,
    required this.settings,
    this.focus = '',
  });
  static const entityKind = 'compressionRecipe';
  final String id;
  final String name;
  final CompressionTemplate template;
  final CompressionConfig settings;
  final String focus;
  Map<String, dynamic> toJson() => {
    'formatVersion': 1,
    'id': id,
    'name': name,
    'template': template.toJson(),
    'settings': settings.toJson(includeMode: false),
    'focus': focus,
  };

  factory CompressionRecipe.fromJson(Map<String, dynamic> json) {
    if (json['formatVersion'] != 1 || (json['name'] as String).trim().isEmpty) {
      throw const FormatException('Invalid compression recipe');
    }
    return CompressionRecipe(
      id: json['id'] as String,
      name: json['name'] as String,
      template: CompressionTemplate.fromJson(
        Map<String, dynamic>.from(json['template'] as Map),
      ),
      settings: CompressionConfig.fromJson({
        ...Map<String, dynamic>.from(json['settings'] as Map),
        'mode': 'off',
      }),
      focus: json['focus'] as String? ?? '',
    );
  }
}

class CompressionInputBudget {
  const CompressionInputBudget({required this.window, required this.output});
  final int window;
  final int output;
  int get input => (window - output - (window * .05).ceil()).clamp(0, window);
  bool shouldTrigger(int tokens, CompressionConfig config) =>
      input > 0 &&
      tokens >=
          input *
              (config.nativeEnabled
                  ? config.nativeTriggerInputRatio
                  : config.triggerInputRatio);
  bool accepts({
    required int before,
    required int after,
    required CompressionConfig config,
  }) => after < before && after < input * config.triggerInputRatio;
}
