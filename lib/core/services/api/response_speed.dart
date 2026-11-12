import '../../models/conversation.dart';
import '../../models/provider_oauth.dart';
import '../../providers/settings_provider.dart';
import '../model_spec/model_spec_resolver.dart';
import 'chat_api_helpers.dart';

enum ResponseSpeed { standard, fast, ultrafast }

/// Codex uses account discovery. OpenAI-compatible GPT endpoints can request
/// documented tiers too; a relay decides whether it honors them.
class ResponseSpeedCapabilities {
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
    if (config.isOAuth ||
        ProviderConfig.classify(config.id, explicitType: config.providerType) !=
            ProviderKind.openai) {
      return const ResponseSpeedCapabilities({}, supportedProvider: false);
    }
    final model =
        (ModelSpecResolver.instance.spec(config, modelId).apiModelId ?? modelId)
            .split('/')
            .last
            .toLowerCase();
    final openAIModel = RegExp(r'^(gpt-|o[134](?:-|$))').hasMatch(model);
    if (!openAIModel) {
      return const ResponseSpeedCapabilities({}, supportedProvider: false);
    }
    final providerDependent =
        Uri.tryParse(config.baseUrl)?.host != 'api.openai.com';
    bool matches(String name) =>
        model == name ||
        RegExp(
          '^${RegExp.escape(name)}-\\d{4}-\\d{2}-\\d{2}\$',
        ).hasMatch(model);
    // Official Fast pricing table: https://developers.openai.com/api/docs/pricing
    final fast = const [
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
    ].any(matches);
    final ultraModel = matches('gpt-6-astra') || matches('gpt-6.1-sol');
    return ResponseSpeedCapabilities(
      {
        if (fast) ResponseSpeed.fast: providerDependent ? 'priority' : 'fast',
        if (config.useResponseApi == true && ultraModel)
          ResponseSpeed.ultrafast: 'ultrafast',
      },
      providerDependent: providerDependent,
      ultrafastRequiresResponses: ultraModel && config.useResponseApi != true,
    );
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
    if (!capabilities.supportedProvider) return null;
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
