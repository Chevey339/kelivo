import 'dart:convert';

import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/provider_oauth.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/response_speed.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderConfig _config() => ProviderConfig(
  id: 'openai',
  enabled: true,
  name: 'OpenAI',
  apiKey: '',
  baseUrl: 'https://api.openai.com/v1',
  providerType: ProviderKind.openai,
  useResponseApi: true,
);

void main() {
  test('speed cycles only through advertised tiers and respects transport', () {
    const fastOnly = ResponseSpeedCapabilities({ResponseSpeed.fast: 'fast'});
    expect(fastOnly.next(ResponseSpeed.standard), ResponseSpeed.fast);
    expect(fastOnly.next(ResponseSpeed.fast), ResponseSpeed.standard);
    const both = ResponseSpeedCapabilities({
      ResponseSpeed.fast: 'fast',
      ResponseSpeed.ultrafast: 'ultrafast',
    });
    expect(both.next(ResponseSpeed.fast), ResponseSpeed.ultrafast);
    expect(both.next(ResponseSpeed.ultrafast), ResponseSpeed.standard);
    expect(
      const ResponseSpeedCapabilities({}).next(ResponseSpeed.standard),
      ResponseSpeed.standard,
    );
    final chatCompletions = ResponseSpeedCapabilities.resolve(
      _config().copyWith(useResponseApi: false),
      'gpt-6-astra',
    );
    expect(chatCompletions.ultrafastRequiresResponses, isTrue);
    expect(chatCompletions.next(ResponseSpeed.fast), ResponseSpeed.standard);
  });

  test('official API support follows endpoint, model and transport', () {
    final config = _config();
    expect(
      ResponseSpeedCapabilities.resolve(
        config,
        'gpt-6-astra',
      ).supports(ResponseSpeed.ultrafast),
      isTrue,
    );
    expect(
      ResponseSpeedCapabilities.resolve(
        config.copyWith(useResponseApi: false),
        'gpt-6-astra',
      ).supports(ResponseSpeed.ultrafast),
      isFalse,
    );
    expect(
      ResponseSpeedCapabilities.resolve(
        config,
        'gpt-6.1-terra',
      ).supports(ResponseSpeed.fast),
      isTrue,
    );
    expect(
      ResponseSpeedCapabilities.resolve(
        config,
        'gpt-6.1-terra',
      ).supports(ResponseSpeed.ultrafast),
      isFalse,
    );
    expect(
      ResponseSpeedCapabilities.resolve(
        config,
        'gpt-5.4-2026-03-05',
      ).supports(ResponseSpeed.fast),
      isTrue,
    );
    expect(ResponseSpeedCapabilities.resolve(config, 'gpt-5.3-codex').tiers, {
      ResponseSpeed.fast: 'fast',
    });
    expect(
      ResponseSpeedCapabilities.resolve(
        config,
        'gpt-5-nano',
      ).supports(ResponseSpeed.fast),
      isFalse,
    );
    expect(
      ResponseSpeedCapabilities.resolve(
        config,
        'unknown-model',
      ).supports(ResponseSpeed.fast),
      isFalse,
    );
    expect(
      ResponseSpeedCapabilities.resolve(
        config.copyWith(providerType: ProviderKind.claude),
        'gpt-6-astra',
      ).supportedProvider,
      isFalse,
    );
    final alias = config.copyWith(
      modelOverrides: {
        'alias': {'apiModelId': 'gpt-6-astra'},
      },
    );
    expect(
      ResponseSpeedCapabilities.resolve(
        alias,
        'alias',
      ).supports(ResponseSpeed.ultrafast),
      isTrue,
    );
  });

  test(
    'relay GPT models expose tiers without claiming provider availability',
    () {
      final gateway = _config().copyWith(baseUrl: 'https://gateway.example/v1');
      final capabilities = ResponseSpeedCapabilities.resolve(
        gateway,
        'gpt-6-astra',
      );
      expect(capabilities.supportedProvider, isTrue);
      expect(capabilities.providerDependent, isTrue);
      expect(capabilities.tiers, {
        ResponseSpeed.fast: 'priority',
        ResponseSpeed.ultrafast: 'ultrafast',
      });
      expect(
        ResponseSpeedCapabilities.resolve(
          gateway,
          'deepseek-v4-flash',
        ).supportedProvider,
        isFalse,
      );
      expect(
        ResponseSpeedCapabilities.resolve(
          gateway,
          'openai/gpt-5.6-sol',
        ).supports(ResponseSpeed.fast),
        isTrue,
      );
      expect(
        ResponseSpeedCapabilities.resolve(
          gateway,
          'openai/gpt-5.3-codex',
        ).tiers,
        {ResponseSpeed.fast: 'priority'},
      );
    },
  );

  test('Codex uses current account discovery, never a plan-name guess', () {
    final credentials = ProviderOAuthCredentials(
      accessToken: 'test',
      refreshToken: 'test',
      expiresAt: DateTime(2099),
      sessionId: 'account-a',
      plan: 'pro',
    );
    final config = _config().copyWith(
      oauthProvider: OAuthProvider.chatgpt,
      oauthCredentials: credentials,
      modelOverrides: {
        'model': {
          'oauthServiceTierSessionId': 'account-a',
          'oauthServiceTiers': ['priority'],
        },
      },
    );
    final capabilities = ResponseSpeedCapabilities.resolve(config, 'model');
    expect(capabilities.tiers, {ResponseSpeed.fast: 'priority'});
    expect(capabilities.supports(ResponseSpeed.ultrafast), isFalse);
    expect(
      ResponseSpeedCapabilities.resolve(config, 'other-model').tiers,
      isEmpty,
    );
    expect(
      ResponseSpeedCapabilities.resolve(
        config.copyWith(
          oauthCredentials: credentials.copyWith(requiresLogin: true),
        ),
        'model',
      ).tiers,
      isEmpty,
    );
    expect(
      ResponseSpeedCapabilities.resolve(
        config.copyWith(
          modelOverrides: {
            'model': {
              'oauthServiceTierSessionId': 'old-account',
              'oauthServiceTiers': ['fast', 'ultrafast'],
            },
          },
        ),
        'model',
      ).tiers,
      isEmpty,
    );
  });

  test(
    'speed survives serialization and stays scoped to a chat, provider and model',
    () {
      final first = Conversation(title: 'one', extras: {'unrelated': true});
      final changed = first.copyWith(
        extras: ConversationResponseSpeed.updateExtras(
          first.extras,
          'openai',
          'gpt-6-astra',
          ResponseSpeed.fast,
        ),
      );
      final restored = Conversation.fromJson(
        jsonDecode(jsonEncode(changed.toJson())) as Map<String, dynamic>,
      );
      expect(restored.extras['unrelated'], isTrue);
      expect(first.extras, {'unrelated': true});
      expect(
        ConversationResponseSpeed.selected(restored, 'openai', 'gpt-6-astra'),
        ResponseSpeed.fast,
      );
      expect(
        ConversationResponseSpeed.selected(first, 'openai', 'gpt-6-astra'),
        isNull,
      );
      expect(
        ConversationResponseSpeed.selected(restored, 'other', 'gpt-6-astra'),
        isNull,
      );
      expect(
        ConversationResponseSpeed.selected(restored, 'openai', 'other'),
        isNull,
      );
      expect(
        ConversationResponseSpeed.requestTier(
          restored,
          _config(),
          'gpt-6-astra',
        ),
        'fast',
      );
      expect(
        ConversationResponseSpeed.requestTier(
          restored,
          _config().copyWith(id: 'other'),
          'gpt-6-astra',
        ),
        isNull,
      );
    },
  );

  test('inherited custom speed is shown accurately until explicitly reset', () {
    final config = _config().copyWith(
      customBody: const [
        {'key': 'service_tier', 'value': 'ultrafast'},
      ],
    );
    final conversation = Conversation(title: 'one');
    expect(
      ConversationResponseSpeed.effective(conversation, config, 'gpt-5-nano'),
      ResponseSpeed.ultrafast,
    );
    expect(
      ConversationResponseSpeed.requestTier(conversation, config, 'gpt-5-nano'),
      isNull,
    );
    final reset = conversation.copyWith(
      extras: ConversationResponseSpeed.updateExtras(
        conversation.extras,
        config.id,
        'gpt-5-nano',
        ResponseSpeed.standard,
      ),
    );
    expect(
      ConversationResponseSpeed.effective(reset, config, 'gpt-5-nano'),
      ResponseSpeed.standard,
    );
    expect(
      ConversationResponseSpeed.requestTier(reset, config, 'gpt-5-nano'),
      'default',
    );
  });

  test(
    'standard explicitly overrides custom speed, including Codex routing',
    () {
      final body = <String, dynamic>{
        'service_tier': 'ultrafast',
        'reasoning': {'effort': 'high'},
      };
      applyServiceTier(body, _config(), 'default');
      expect(body['service_tier'], 'default');
      applyServiceTier(
        body,
        _config().copyWith(oauthProvider: OAuthProvider.chatgpt),
        'default',
      );
      expect(body, {
        'reasoning': {'effort': 'high'},
      });
      applyServiceTier(body, _config(), 'ultrafast');
      applyServiceTier(body, _config(), null);
      expect(body['service_tier'], 'ultrafast');
    },
  );
}
