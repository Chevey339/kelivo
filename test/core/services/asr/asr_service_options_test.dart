import 'package:Kelivo/core/services/asr/asr_service_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AsrServiceKind', () {
    test('uses stable serialized ids', () {
      expect(AsrServiceKind.sherpaOnnx.id, 'sherpa_onnx');
      expect(AsrServiceKind.system.id, 'system');
      expect(AsrServiceKind.openAiRealtime.id, 'openai_realtime');
      expect(AsrServiceKind.groq.id, 'groq');
      expect(AsrServiceKind.mistral.id, 'mistral');
      expect(AsrServiceKind.dashScope.id, 'dashscope');
      expect(AsrServiceKind.volcengine.id, 'volcengine');
      expect(AsrServiceKind.mimo.id, 'mimo');
      expect(AsrServiceKind.step.id, 'step');
    });

    test('rejects unknown kinds instead of falling back', () {
      expect(
        () => AsrServiceOptions.fromJson({'kind': 'unknown'}),
        throwsFormatException,
      );
    });
  });

  group('AsrServiceOptions', () {
    for (final kind in [AsrServiceKind.groq, AsrServiceKind.mistral]) {
      test(
        '${kind.name} restores defaults and custom transcription settings',
        () {
          final defaults =
              AsrServiceOptions.fromJson({'kind': kind.id})
                  as AudioTranscriptionAsrOptions;
          expect(defaults.kind, kind);
          expect(
            defaults.name,
            kind == AsrServiceKind.groq ? 'Groq' : 'Mistral',
          );
          expect(
            defaults.baseUrl,
            kind == AsrServiceKind.groq
                ? 'https://api.groq.com/openai/v1'
                : 'https://api.mistral.ai/v1',
          );
          expect(
            defaults.model,
            kind == AsrServiceKind.groq
                ? 'whisper-large-v3'
                : 'voxtral-mini-latest',
          );
          expect(defaults.sampleRate, 16000);
          expect(defaults.segmentDurationSec, 30);
          expect(defaults.language, isEmpty);
          expect(defaults.isConfigured, isFalse);
          final custom = defaults.copyWith(
            id: '${kind.name}-id',
            name: 'Custom transcription',
            apiKey: 'key',
            baseUrl: 'https://proxy.test/v1',
            model: 'custom-model',
            language: 'zh',
            sampleRate: 8000,
            segmentDurationSec: 10,
          );
          expect(custom.isConfigured, isTrue);
          final restored = AsrServiceOptions.fromJson(custom.toJson());
          expect(restored.toJson(), custom.toJson());
          expect(restored.kind, kind);
          expect(custom.copyWith(model: '').isConfigured, isFalse);
          expect(custom.copyWith(baseUrl: '').isConfigured, isFalse);
          expect(custom.copyWith(sampleRate: 0).isConfigured, isFalse);
        },
      );
    }

    test('uses concise default display names', () {
      final options = <AsrServiceOptions>[
        SherpaOnnxAsrOptions(),
        SystemAsrOptions(),
        OpenAiRealtimeAsrOptions(),
        DashScopeAsrOptions(),
        VolcengineAsrOptions(),
        MimoAsrOptions(),
        StepAsrOptions(),
      ];

      expect(options.map((option) => option.name), [
        'Offline Model',
        'System',
        'OpenAI Realtime',
        'DashScope',
        'Volcengine',
        'MiMo',
        'Step',
      ]);
      for (final option in options) {
        final name = option.name.toLowerCase();
        expect(name.contains('asr'), isFalse);
        expect(name.contains('recognition'), isFalse);
      }
    });

    test('has provider-appropriate defaults', () {
      final openAi = AsrServiceOptions.fromJson({'kind': 'openai_realtime'});
      final dashScope = AsrServiceOptions.fromJson({'kind': 'dashscope'});
      final volcengine = AsrServiceOptions.fromJson({'kind': 'volcengine'});
      final mimo = AsrServiceOptions.fromJson({'kind': 'mimo'});
      final step = AsrServiceOptions.fromJson({'kind': 'step'});

      expect(openAi, isA<OpenAiRealtimeAsrOptions>());
      expect(
        (openAi as OpenAiRealtimeAsrOptions).websocketUrl,
        'wss://api.openai.com/v1/realtime?intent=transcription',
      );
      expect(openAi.model, 'gpt-live-transcribe');
      expect(openAi.sampleRate, 24000);
      expect(openAi.vadThreshold, 0);
      expect(openAi.isConfigured, isFalse);

      expect(dashScope, isA<DashScopeAsrOptions>());
      expect(
        (dashScope as DashScopeAsrOptions).websocketUrl,
        'wss://dashscope.aliyuncs.com/api-ws/v1/realtime',
      );
      expect(dashScope.model, 'qwen3-asr-flash-realtime');
      expect(dashScope.sampleRate, 16000);
      expect(dashScope.vadThreshold, 0);
      expect(dashScope.isConfigured, isFalse);

      expect(volcengine, isA<VolcengineAsrOptions>());
      expect(
        (volcengine as VolcengineAsrOptions).websocketUrl,
        'wss://openspeech.bytedance.com/api/v3/sauc/bigmodel',
      );
      expect(volcengine.resourceId, 'volc.seedasr.sauc.duration');
      expect(volcengine.isConfigured, isFalse);

      expect(mimo, isA<MimoAsrOptions>());
      expect((mimo as MimoAsrOptions).model, 'mimo-v2.5-asr');
      expect(mimo.language, 'auto');
      expect(mimo.segmentDurationSec, 30);
      expect(mimo.isConfigured, isFalse);

      expect(step, isA<StepAsrOptions>());
      expect((step as StepAsrOptions).baseUrl, 'https://api.stepfun.com');
      expect(step.model, 'stepaudio-2.5-asr');
      expect(step.language, 'auto');
      expect(step.sampleRate, 16000);
      expect(step.segmentDurationSec, 30);
      expect(step.enableItn, isTrue);
      expect(step.enableTimestamp, isFalse);
      expect(step.hotwords, isEmpty);
      expect(step.isConfigured, isFalse);
    });

    test('round-trips every provider and preserves instance ids', () {
      final options = <AsrServiceOptions>[
        SherpaOnnxAsrOptions(
          id: 'sherpa-id',
          name: 'Local',
          modelId: 'sense-voice-zh-en',
          modelDirectory: '/models/sense-voice',
          language: 'zh',
          sampleRate: 16000,
        ),
        SystemAsrOptions(id: 'system-id', name: 'Device', localeId: 'zh_CN'),
        OpenAiRealtimeAsrOptions(
          id: 'openai-id',
          name: 'OpenAI',
          apiKey: 'openai-secret',
          websocketUrl: 'wss://example.test/realtime',
          model: 'gpt-4o-transcribe',
          language: 'zh',
          prompt: 'Kelivo vocabulary',
          sampleRate: 24000,
          vadThreshold: 0.4,
          prefixPaddingMs: 250,
          silenceDurationMs: 650,
        ),
        DashScopeAsrOptions(
          id: 'dash-id',
          name: 'Dash',
          apiKey: 'dash-secret',
          websocketUrl: 'wss://example.test/dash',
          model: 'qwen-asr',
          language: 'zh',
          sampleRate: 16000,
          vadThreshold: 0.25,
          silenceDurationMs: 900,
        ),
        VolcengineAsrOptions(
          id: 'volc-id',
          name: 'Volc',
          apiKey: 'volc-secret',
          websocketUrl: 'wss://example.test/volc',
          resourceId: 'volc.bigasr.sauc.concurrent',
          language: 'zh-CN',
        ),
        MimoAsrOptions(
          id: 'mimo-id',
          name: 'MiMo',
          apiKey: 'mimo-secret',
          baseUrl: 'https://example.test/v1',
          model: 'mimo-v2.5-asr',
          language: '',
          sampleRate: 16000,
          segmentDurationSec: 45,
        ),
        StepAsrOptions(
          id: 'step-id',
          name: 'StepFun',
          apiKey: 'step-secret',
          baseUrl: 'https://api.stepfun.ai',
          model: 'stepaudio-2-asr-pro',
          language: 'zh',
          sampleRate: 8000,
          segmentDurationSec: 60,
          enableItn: false,
          enableTimestamp: true,
          hotwords: const ['Kelivo', '阶跃星辰'],
        ),
      ];

      for (final original in options) {
        final restored = AsrServiceOptions.fromJson(original.toJson());
        expect(restored.runtimeType, original.runtimeType);
        expect(restored.toJson(), original.toJson());
        expect(restored.id, original.id);
      }
    });

    test('reports local and system configuration readiness', () {
      expect(SherpaOnnxAsrOptions().isConfigured, isFalse);
      expect(
        SherpaOnnxAsrOptions(modelId: 'zipformer-zh').isConfigured,
        isTrue,
      );
      expect(SystemAsrOptions().isConfigured, isTrue);
    });
  });
}
