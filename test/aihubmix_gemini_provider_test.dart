import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/model_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';

ProviderConfig _config(String baseUrl, {bool vertexAI = false}) {
  return ProviderConfig(
    id: 'AIhubmix',
    enabled: true,
    name: 'AIhubmix',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.google,
    vertexAI: vertexAI,
  );
}

void main() {
  test('AIhubmix base URL follows the selected provider type', () {
    String? forKind(String base, ProviderKind kind) =>
        ProviderConfig.aihubmixBaseUrlForKind(base, kind);

    expect(
      forKind('https://aihubmix.com/v1', ProviderKind.google),
      'https://aihubmix.com/gemini/v1beta',
    );
    expect(
      forKind('https://aihubmix.com/gemini/', ProviderKind.google),
      'https://aihubmix.com/gemini/v1beta',
    );
    expect(
      forKind('https://aihubmix.com/gemini/v1beta', ProviderKind.google),
      isNull,
    );
    expect(
      forKind('https://aihubmix.com/gemini/v1beta', ProviderKind.openai),
      'https://aihubmix.com/v1',
    );
    expect(
      forKind('https://aihubmix.com/gemini/v1beta', ProviderKind.claude),
      'https://aihubmix.com/v1',
    );
    expect(forKind('https://aihubmix.com/v1', ProviderKind.openai), isNull);
    expect(
      forKind(
        'https://generativelanguage.googleapis.com/v1beta',
        ProviderKind.google,
      ),
      isNull,
    );
    expect(forKind('https://example.com/v1', ProviderKind.google), isNull);
  });

  test('Gemini-type AIhubmix lists models from the OpenAI-format list', () {
    expect(
      GoogleProvider.aihubmixModelListUri(
        _config('https://aihubmix.com/gemini/v1beta'),
      ).toString(),
      'https://aihubmix.com/v1/models',
    );
    expect(
      GoogleProvider.aihubmixModelListUri(
        _config('https://api.aihubmix.com/gemini/v1beta/'),
      ).toString(),
      'https://api.aihubmix.com/v1/models',
    );
    expect(
      GoogleProvider.aihubmixModelListUri(
        _config('https://generativelanguage.googleapis.com/v1beta'),
      ),
      isNull,
    );
    expect(
      GoogleProvider.aihubmixModelListUri(
        _config('https://aihubmix.com/gemini/v1beta', vertexAI: true),
      ),
      isNull,
    );
  });

  test('only Gemini-routed AIhubmix model ids are kept', () {
    expect(GoogleProvider.isAihubmixGeminiModel('gemini-2.5-flash'), isTrue);
    expect(
      GoogleProvider.isAihubmixGeminiModel('gemini-embedding-001'),
      isTrue,
    );
    expect(
      GoogleProvider.isAihubmixGeminiModel('gemini-3.1-flash-lite-nothink'),
      isFalse,
    );
    expect(
      GoogleProvider.isAihubmixGeminiModel('gemini-2.5-pro-search'),
      isFalse,
    );
    expect(GoogleProvider.isAihubmixGeminiModel('gpt-4o'), isFalse);
  });
}
