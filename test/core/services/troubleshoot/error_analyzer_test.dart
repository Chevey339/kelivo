import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/troubleshoot/error_analyzer.dart';
import 'package:Kelivo/core/services/troubleshoot/troubleshoot_data.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';

ProviderConfig _config({
  String id = 'test',
  String name = 'Test',
  String apiKey = 'sk-test',
  String baseUrl = 'https://api.test.com/v1',
  ProviderKind? providerType,
  String? chatPath,
  bool? useResponseApi,
  Map<String, dynamic>? modelOverrides,
}) {
  return ProviderConfig(
    id: id,
    enabled: true,
    name: name,
    apiKey: apiKey,
    baseUrl: baseUrl,
    providerType: providerType,
    chatPath: chatPath,
    useResponseApi: useResponseApi,
    modelOverrides: modelOverrides ?? const {},
  );
}

void main() {
  group('ErrorAnalyzer.analyze', () {
    test('404 + useResponseApi=true → response_api_not_supported', () {
      final config = _config(useResponseApi: true);
      final result = ErrorAnalyzer.analyze(
        statusCode: 404,
        errorBody: 'Not Found',
        config: config,
      );
      expect(result, isNotNull);
      expect(result!.faqKey, 'response_api_not_supported');
      expect(result.action, isNotNull);
      expect(result.action!.type, ActionType.openProviderDetail);
      expect(result.action!.providerId, 'test');
    });

    test(
      '404 + useResponseApi=false → no match (not null if other matches)',
      () {
        final config = _config(useResponseApi: false);
        final result = ErrorAnalyzer.analyze(
          statusCode: 404,
          errorBody: 'Not Found',
          config: config,
        );
        expect(result, isNull);
      },
    );

    test(
      '404 + Google provider + baseUrl without v1beta → gemini_wrong_provider_type',
      () {
        final config = _config(
          providerType: ProviderKind.google,
          baseUrl: 'https://api.test.com/v1',
        );
        final result = ErrorAnalyzer.analyze(
          statusCode: 404,
          errorBody: 'Not Found',
          config: config,
        );
        expect(result, isNotNull);
        expect(result!.faqKey, 'gemini_wrong_provider_type');
      },
    );

    test(
      '404 + Google provider + baseUrl with v1beta → no match (not null if other)',
      () {
        final config = _config(
          providerType: ProviderKind.google,
          baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
        );
        final result = ErrorAnalyzer.analyze(
          statusCode: 404,
          errorBody: 'Not Found',
          config: config,
        );
        expect(result, isNull);
      },
    );

    test('empty chatPath → empty_api_path', () {
      final config = _config(chatPath: '');
      final result = ErrorAnalyzer.analyze(
        statusCode: 200,
        errorBody: 'OK',
        config: config,
      );
      expect(result, isNotNull);
      expect(result!.faqKey, 'empty_api_path');
    });

    test('non-empty chatPath → no match on path check', () {
      final config = _config(chatPath: '/chat/completions');
      final result = ErrorAnalyzer.analyze(
        statusCode: 200,
        errorBody: 'OK',
        config: config,
      );
      expect(result, isNull);
    });

    test('body contains Insufficient Balance → insufficient_balance', () {
      final config = _config();
      final result = ErrorAnalyzer.analyze(
        statusCode: 402,
        errorBody: '{"error":{"message":"Insufficient Balance"}}',
        config: config,
      );
      expect(result, isNotNull);
      expect(result!.faqKey, 'insufficient_balance');
    });

    test('HTTP 402 with any error body → insufficient_balance', () {
      final config = _config();
      final result = ErrorAnalyzer.analyze(
        statusCode: 402,
        errorBody: '{"error":{"message":"Quota exceeded"}}',
        config: config,
      );
      expect(result, isNotNull);
      expect(result!.faqKey, 'insufficient_balance');
    });

    test('non-402 without Insufficient Balance text → no match on balance', () {
      final config = _config();
      final result = ErrorAnalyzer.analyze(
        statusCode: 403,
        errorBody: '{"error":{"message":"Forbidden"}}',
        config: config,
      );
      expect(result, isNull);
    });

    test('unknown variant image_url + non-vision model → model_no_vision', () {
      final config = _config(
        modelOverrides: {
          'gpt-3.5-turbo': {
            'input': ['text'],
          },
        },
      );
      final result = ErrorAnalyzer.analyze(
        statusCode: 400,
        errorBody:
            '''{"error":{"message":"unknown variant `image_url`, expected `text`"}}''',
        config: config,
        modelId: 'gpt-3.5-turbo',
      );
      expect(result, isNotNull);
      expect(result!.faqKey, 'model_no_vision');
    });

    test('unknown variant image_url + vision model → no match', () {
      final config = _config(
        modelOverrides: {
          'gpt-4o': {
            'input': ['text', 'image'],
          },
        },
      );
      final result = ErrorAnalyzer.analyze(
        statusCode: 400,
        errorBody:
            '''{"error":{"message":"unknown variant `image_url`, expected `text`"}}''',
        config: config,
        modelId: 'gpt-4o',
      );
      expect(result, isNull);
    });

    test('body without image_url text → no match on image check', () {
      final config = _config();
      final result = ErrorAnalyzer.analyze(
        statusCode: 400,
        errorBody: '{"error":{"message":"some other error"}}',
        config: config,
        modelId: 'gpt-3.5-turbo',
      );
      expect(result, isNull);
    });

    test('null config → null result', () {
      final result = ErrorAnalyzer.analyze(
        statusCode: 500,
        errorBody: 'Server Error',
        config: null,
      );
      expect(result, isNull);
    });

    test('zero statusCode with known pattern still matches', () {
      final config = _config(chatPath: '');
      final result = ErrorAnalyzer.analyze(
        statusCode: 0,
        errorBody: 'some error',
        config: config,
      );
      expect(result, isNotNull);
      expect(result!.faqKey, 'empty_api_path');
    });

    test('case insensitive balance check', () {
      final config = _config();
      final result = ErrorAnalyzer.analyze(
        statusCode: 402,
        errorBody: 'insufficient balance',
        config: config,
      );
      expect(result, isNotNull);
      expect(result!.faqKey, 'insufficient_balance');
    });
  });

  group('ErrorAnalyzer.unknownError', () {
    test('returns unknown_error result with openAbout action', () {
      final result = ErrorAnalyzer.unknownError();
      expect(result, isNotNull);
      expect(result.faqKey, 'unknown_error');
      expect(result.titleKey, 'troubleshootUnknownErrorTitle');
      expect(result.summaryKey, 'troubleshootUnknownErrorSummary');
      expect(result.action, isNotNull);
      expect(result.action!.type, ActionType.openAbout);
    });
  });
}
