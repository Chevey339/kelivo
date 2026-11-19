import '../../models/conversation.dart';
import '../../models/model_spec.dart';
import '../../models/provider_oauth.dart';
import '../../providers/settings_provider.dart';
import '../model_spec/model_spec_resolver.dart';
import 'chat_api_helpers.dart';
import 'providers/zhipu_layout_parsing.dart';

export '../../models/model_spec.dart' show ResponseSpeed;

/// Codex uses account discovery. OpenAI-compatible chat endpoints can request
/// public API tiers; a relay decides whether it honors them.
class ResponseSpeedCapabilities {
  static final _openAIModel = RegExp(r'^(gpt-|o[134](?:-|$))');
  static final _snapshotSuffix = RegExp(r'-\d{4}-\d{2}-\d{2}$');

  const ResponseSpeedCapabilities(
    this.tiers, {
    this.supportedProvider = true,
    this.providerDependent = false,
    this.ultrafastRequiresResponses = false,
  });

  final Map<ResponseSpeed, String> tiers;
  final bool supportedProvider;
  final bool providerDependent;
  final bool ultrafastRequiresResponses;

  bool supports(ResponseSpeed speed) =>
      speed == ResponseSpeed.standard || tiers.containsKey(speed);

  ResponseSpeed next(ResponseSpeed current) {
    final options = [
      ResponseSpeed.standard,
      for (final speed in [ResponseSpeed.fast, ResponseSpeed.ultrafast])
        if (supports(speed)) speed,
    ];
    final index = options.indexOf(current);
    return options[(index + 1) % options.length];
  }

  static bool allowsManualTiers(ProviderConfig config, ModelSpec spec) =>
      _isPublicOpenAIProvider(config) && _usesChatRequest(config, spec);

  static bool _isPublicOpenAIProvider(ProviderConfig config) =>
      !config.isOAuth &&
      ProviderConfig.classify(config.id, explicitType: config.providerType) ==
          ProviderKind.openai;

  static bool _usesChatRequest(ProviderConfig config, ModelSpec spec) =>
      spec.type == ModelType.chat &&
      !(isOfficialZhipuHost(config) && isOfficialGlmOcrModel(spec.upstreamId));

  static ResponseSpeedCapabilities resolve(
    ProviderConfig config,
    String modelId,
  ) {
    if (config.oauthProvider == OAuthProvider.chatgpt) {
      final override = config.modelOverrides[modelId];
      final credentials = config.oauthCredentials;
      final raw =
          override is Map &&
              credentials != null &&
              !credentials.requiresLogin &&
              override['oauthServiceTierSessionId'] == credentials.sessionId
          ? override['oauthServiceTiers']
          : null;
      final ids = raw is List ? raw.whereType<String>().toSet() : <String>{};
      return ResponseSpeedCapabilities({
        if (ids.contains('fast') || ids.contains('priority'))
          ResponseSpeed.fast: ids.contains('fast') ? 'fast' : 'priority',
        if (ids.contains('ultrafast')) ResponseSpeed.ultrafast: 'ultrafast',
      });
    }
    if (!_isPublicOpenAIProvider(config)) {
      return const ResponseSpeedCapabilities({}, supportedProvider: false);
    }
    final resolved = ModelSpecResolver.instance.resolve(config, modelId);
    final override = resolved.override.responseSpeedTiers;
    final model = _modelName(resolved.spec.upstreamId);
    if (!_usesChatRequest(config, resolved.spec) ||
        (override == null && !_openAIModel.hasMatch(model))) {
      return const ResponseSpeedCapabilities({}, supportedProvider: false);
    }
    final declared = override ?? _defaultTiers(model);
    final ultra = declared.contains(ResponseSpeed.ultrafast);
    final providerDependent =
        Uri.tryParse(config.baseUrl)?.host != 'api.openai.com';
    return ResponseSpeedCapabilities(
      {
        if (declared.contains(ResponseSpeed.fast))
          ResponseSpeed.fast: providerDependent ? 'priority' : 'fast',
        if (config.useResponseApi == true && ultra)
          ResponseSpeed.ultrafast: 'ultrafast',
      },
      providerDependent: providerDependent,
      ultrafastRequiresResponses: ultra && config.useResponseApi != true,
    );
  }

  static List<ResponseSpeed> defaultTiersFor(String upstreamModelId) =>
      _defaultTiers(_modelName(upstreamModelId));

  static String _modelName(String id) => id.split('/').last.toLowerCase();

  static List<ResponseSpeed> _defaultTiers(String model) {
    final family = model.replaceFirst(_snapshotSuffix, '');
    // Official Fast pricing table: https://developers.openai.com/api/docs/pricing
    final fast = const [
      'gpt-6.2-astra',
      'gpt-6.2-sol',
      'gpt-6-astra',
      'gpt-6-sol',
      'gpt-6-luna',
      'gpt-6.1-sol',
      'gpt-6.1-terra',
      'gpt-5.6-sol',
      'gpt-5.6-terra',
      'gpt-5.6-luna',
      'gpt-5.5',
      'gpt-5.4',
      'gpt-5.4-mini',
      'gpt-5.3-codex',
      'gpt-5.2',
      'gpt-5.1',
      'gpt-5',
      'gpt-5-mini',
      'gpt-4.1',
      'gpt-4.1-mini',
      'gpt-4o',
      'gpt-4o-mini',
      'o3',
    ].contains(family);
    final ultra = const [
      'gpt-6.2-astra',
      'gpt-6.2-sol',
      'gpt-6-astra',
      'gpt-6.1-sol',
    ].contains(family);
    return [if (fast) ResponseSpeed.fast, if (ultra) ResponseSpeed.ultrafast];
  }
}

/// Persisted in conversation extras, including drafts and portable backups.
/// Scoping by provider/model prevents a choice leaking to a different backend.
class ConversationResponseSpeed {
  static const _key = 'responseSpeeds';

  static ResponseSpeed? selected(
    Conversation? conversation,
    String providerId,
    String modelId,
  ) {
    final all = conversation?.extras[_key];
    final provider = all is Map ? all[providerId] : null;
    final value = provider is Map ? provider[modelId] : null;
    for (final speed in ResponseSpeed.values) {
      if (speed.name == value) return speed;
    }
    return null;
  }

  static Map<String, dynamic> updateExtras(
    Map<String, dynamic> extras,
    String providerId,
    String modelId,
    ResponseSpeed speed,
  ) {
    final raw = extras[_key];
    final all = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final provider = all[providerId];
    all[providerId] = {
      if (provider is Map) ...Map<String, dynamic>.from(provider),
      modelId: speed.name,
    };
    return {...extras, _key: all};
  }

  static ResponseSpeed effective(
    Conversation? conversation,
    ProviderConfig config,
    String modelId, {
    Map<String, dynamic>? assistantBody,
  }) {
    final saved = selected(conversation, config.id, modelId);
    final inherited = customBody(
      config,
      modelId,
      assistantBody: assistantBody,
    )['service_tier'];
    final speed =
        saved ??
        switch (inherited) {
          'fast' || 'priority' => ResponseSpeed.fast,
          'ultrafast' => ResponseSpeed.ultrafast,
          _ => ResponseSpeed.standard,
        };
    // A custom request remains effective until the user makes a UI choice.
    // Do not label an inherited accelerated request as Standard.
    if (saved == null) return speed;
    return ResponseSpeedCapabilities.resolve(config, modelId).supports(speed)
        ? speed
        : ResponseSpeed.standard;
  }

  /// Captured once in GenerationContext, then passed through every retry and
  /// tool round. Null leaves advanced custom request settings untouched.
  static String? requestTier(
    Conversation? conversation,
    ProviderConfig config,
    String modelId,
  ) {
    final speed = selected(conversation, config.id, modelId);
    if (speed == null) return null;
    final capabilities = ResponseSpeedCapabilities.resolve(config, modelId);
    // A relay alias can lose all tiers when its declaration is reset to
    // inherited. Its saved choice still needs to fall back to Standard.
    if (!capabilities.supportedProvider &&
        !(ResponseSpeedCapabilities._isPublicOpenAIProvider(config) &&
            ResponseSpeedCapabilities._usesChatRequest(
              config,
              ModelSpecResolver.instance.spec(config, modelId),
            ))) {
      return null;
    }
    return capabilities.tiers[speed] ?? 'default';
  }
}

/// Explicit UI choices win over custom body fields. Codex's standard tier is
/// represented by omission; the public API needs `default` to override the
/// project's configured tier.
void applyServiceTier(
  Map<String, dynamic> body,
  ProviderConfig config,
  String? serviceTier,
) {
  if (serviceTier == null) return;
  if (serviceTier == 'default' &&
      config.oauthProvider == OAuthProvider.chatgpt) {
    body.remove('service_tier');
  } else {
    body['service_tier'] = serviceTier;
  }
}
