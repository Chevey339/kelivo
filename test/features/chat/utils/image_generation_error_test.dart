import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/models/provider_oauth.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_helpers.dart';
import 'package:Kelivo/core/services/network/provider_http_exception.dart';
import 'package:Kelivo/features/chat/utils/image_generation_error.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  const message = "Complexity 'xhigh' is not supported for this image model.";
  final config = ProviderConfig(
    id: 'codex',
    enabled: true,
    name: 'Codex',
    apiKey: '',
    baseUrl: OAuthProvider.chatgpt.baseUrl,
    providerType: ProviderKind.openai,
    oauthProvider: OAuthProvider.chatgpt,
    useResponseApi: true,
  );

  for (final locale in ['en', 'zh']) {
    test(
      'HTTP and SSE complexity errors keep upstream details and add $locale help',
      () async {
        final l10n = await AppLocalizations.delegate.load(Locale(locale));
        final errors = <Object>[
          ProviderHttpException(
            http.Response('', 400),
            jsonEncode({
              'error': {'code': 'invalid_value', 'message': message},
            }),
          ),
        ];
        try {
          throwIfInBandStreamError(
            jsonEncode({
              'type': 'response.failed',
              'response': {
                'error': {'code': 'invalid_value', 'message': message},
              },
            }),
          );
          fail('Expected the stream error to be propagated');
        } on HttpException catch (error) {
          errors.add(error);
        }
        expect(errors, hasLength(2));
        for (final error in errors) {
          final result = formatImageGenerationError(
            error,
            config: config,
            l10n: l10n,
          );
          expect(result, startsWith(error.toString()));
          expect(result, contains('invalid_value'));
          expect(result, contains(message));
          expect(result, endsWith(l10n.imageGenerationComplexityErrorHint));
        }
      },
    );
  }

  test(
    'unrelated provider errors and non-OAuth requests are unchanged',
    () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      for (final error in [
        const HttpException('Rate limited'),
        const HttpException(
          "The model 'gpt-image-2-codex' does not support the 'input_fidelity' parameter.",
        ),
        StateError(message),
      ]) {
        expect(
          formatImageGenerationError(error, config: config, l10n: l10n),
          error.toString(),
        );
      }
      final apiConfig = ProviderConfig(
        id: 'OpenAI',
        enabled: true,
        name: 'OpenAI',
        apiKey: 'mock',
        baseUrl: 'https://api.openai.com/v1',
        providerType: ProviderKind.openai,
      );
      const error = HttpException(message);
      expect(
        formatImageGenerationError(error, config: apiConfig, l10n: l10n),
        error.toString(),
      );
    },
  );
}
