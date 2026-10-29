import 'package:uuid/uuid.dart';

enum AsrServiceKind {
  sherpaOnnx('sherpa_onnx'),
  system('system'),
  openAiRealtime('openai_realtime'),
  groq('groq'),
  mistral('mistral'),
  elevenLabs('elevenlabs'),
  dashScope('dashscope'),
  qwenAudio('qwen_audio'),
  volcengine('volcengine'),
  mimo('mimo'),
  step('step');

  const AsrServiceKind(this.id);

  final String id;

  static AsrServiceKind fromId(Object? value) {
    switch (value?.toString()) {
      case 'sherpa_onnx':
      case 'sherpaOnnx':
        return AsrServiceKind.sherpaOnnx;
      case 'system':
        return AsrServiceKind.system;
      case 'openai_realtime':
      case 'openAiRealtime':
        return AsrServiceKind.openAiRealtime;
      case 'groq':
        return AsrServiceKind.groq;
      case 'mistral':
        return AsrServiceKind.mistral;
      case 'elevenlabs':
        return AsrServiceKind.elevenLabs;
      case 'dashscope':
      case 'dashScope':
        return AsrServiceKind.dashScope;
      case 'qwen_audio':
      case 'qwenAudio':
        return AsrServiceKind.qwenAudio;
      case 'volcengine':
        return AsrServiceKind.volcengine;
      case 'mimo':
        return AsrServiceKind.mimo;
      case 'step':
        return AsrServiceKind.step;
      default:
        throw FormatException('Unsupported ASR service kind: $value');
    }
  }
}

abstract class AsrServiceOptions {
  AsrServiceOptions({String? id, required this.name, required this.kind})
    : id = id == null || id.trim().isEmpty ? const Uuid().v4() : id;

  final String id;
  final String name;
  final AsrServiceKind kind;

  bool get isConfigured;

  Map<String, dynamic> toJson();

  static AsrServiceOptions fromJson(Map<String, dynamic> json) {
    final kind = AsrServiceKind.fromId(json['kind']);
    final id = _optionalId(json['id']);

    switch (kind) {
      case AsrServiceKind.sherpaOnnx:
        return SherpaOnnxAsrOptions(
          id: id,
          name: _string(json['name'], 'Offline Model'),
          modelId: _string(json['modelId']),
          modelDirectory: _string(json['modelDirectory']),
          language: _string(json['language']),
          sampleRate: _positiveInt(json['sampleRate'], 16000),
        );
      case AsrServiceKind.system:
        return SystemAsrOptions(
          id: id,
          name: _string(json['name'], 'System'),
          localeId: _string(json['localeId']),
        );
      case AsrServiceKind.openAiRealtime:
        return OpenAiRealtimeAsrOptions(
          id: id,
          name: _string(json['name'], 'OpenAI Realtime'),
          apiKey: _string(json['apiKey']),
          websocketUrl: _string(
            json['websocketUrl'],
            'wss://api.openai.com/v1/realtime?intent=transcription',
          ),
          model: _string(json['model'], 'gpt-live-transcribe'),
          language: _string(json['language']),
          prompt: _string(json['prompt']),
          sampleRate: _positiveInt(json['sampleRate'], 24000),
          vadThreshold: _double(json['vadThreshold'], 0),
          prefixPaddingMs: _nonNegativeInt(json['prefixPaddingMs'], 300),
          silenceDurationMs: _nonNegativeInt(json['silenceDurationMs'], 500),
        );
      case AsrServiceKind.groq:
      case AsrServiceKind.mistral:
      case AsrServiceKind.elevenLabs:
        return AudioTranscriptionAsrOptions(
          id: id,
          kind: kind,
          name: json['name'] as String?,
          apiKey: _string(json['apiKey']),
          baseUrl: json['baseUrl'] as String?,
          model: json['model'] as String?,
          language: _string(json['language']),
          sampleRate: _positiveInt(json['sampleRate'], 16000),
          segmentDurationSec: _nonNegativeInt(json['segmentDurationSec'], 30),
        );
      case AsrServiceKind.dashScope:
        return DashScopeAsrOptions(
          id: id,
          name: _string(json['name'], 'DashScope'),
          apiKey: _string(json['apiKey']),
          websocketUrl: _string(
            json['websocketUrl'],
            'wss://dashscope.aliyuncs.com/api-ws/v1/realtime',
          ),
          model: _string(json['model'], 'qwen3-asr-flash-realtime'),
          language: _string(json['language']),
          sampleRate: _positiveInt(json['sampleRate'], 16000),
          vadThreshold: _double(json['vadThreshold'], 0),
          silenceDurationMs: _nonNegativeInt(json['silenceDurationMs'], 800),
        );
      case AsrServiceKind.volcengine:
        return VolcengineAsrOptions(
          id: id,
          name: _string(json['name'], 'Volcengine'),
          apiKey: _string(json['apiKey']),
          websocketUrl: _string(
            json['websocketUrl'],
            'wss://openspeech.bytedance.com/api/v3/sauc/bigmodel',
          ),
          // Keep Seed-ASR 2.0 default. Docs also list bigasr (1.0).
          // See VolcengineAsrOptions.resourceId comment — needs Key verification
          // before changing user defaults.
          resourceId: _string(json['resourceId'], 'volc.seedasr.sauc.duration'),
          language: _string(json['language']),
        );
      case AsrServiceKind.qwenAudio:
        return QwenAudioAsrOptions(
          id: id,
          name: _string(json['name'], 'Qwen Audio'),
          apiKey: _string(json['apiKey']),
          workspaceId: _string(json['workspaceId']),
          region: _string(json['region'], 'cn-beijing'),
          mode: QwenAudioAsrMode.values.byName(
            _string(json['mode'], 'realtime'),
          ),
          endpoint: _string(json['endpoint']),
          model: json['model'] as String?,
          language: _string(json['language']),
          sampleRate: _positiveInt(json['sampleRate'], 16000),
          format: _string(json['format'], 'pcm'),
          segmentDurationSec: _nonNegativeInt(json['segmentDurationSec'], 30),
        );
      case AsrServiceKind.mimo:
        return MimoAsrOptions(
          id: id,
          name: _string(json['name'], 'MiMo'),
          apiKey: _string(json['apiKey']),
          baseUrl: _string(json['baseUrl'], 'https://api.xiaomimimo.com/v1'),
          model: _string(json['model'], 'mimo-v2.5-asr'),
          language: _string(json['language'], 'auto'),
          sampleRate: _positiveInt(json['sampleRate'], 16000),
          segmentDurationSec: _nonNegativeInt(json['segmentDurationSec'], 30),
        );
      case AsrServiceKind.step:
        return StepAsrOptions(
          id: id,
          name: _string(json['name'], 'Step'),
          apiKey: _string(json['apiKey']),
          baseUrl: _string(json['baseUrl'], 'https://api.stepfun.com'),
          model: _string(json['model'], 'stepaudio-2.5-asr'),
          language: _string(json['language'], 'auto'),
          sampleRate: _positiveInt(json['sampleRate'], 16000),
          segmentDurationSec: _nonNegativeInt(json['segmentDurationSec'], 30),
          enableItn: _bool(json['enableItn'], true),
          enableTimestamp: _bool(json['enableTimestamp'], false),
          hotwords: _stringList(json['hotwords']),
        );
    }
  }

  Map<String, dynamic> baseJson() => {'id': id, 'name': name, 'kind': kind.id};
}

class SherpaOnnxAsrOptions extends AsrServiceOptions {
  SherpaOnnxAsrOptions({
    super.id,
    super.name = 'Offline Model',
    this.modelId = '',
    this.modelDirectory = '',
    this.language = '',
    this.sampleRate = 16000,
  }) : super(kind: AsrServiceKind.sherpaOnnx);

  final String modelId;
  final String modelDirectory;
  final String language;
  final int sampleRate;

  @override
  bool get isConfigured => modelId.trim().isNotEmpty;

  SherpaOnnxAsrOptions copyWith({
    String? id,
    String? name,
    String? modelId,
    String? modelDirectory,
    String? language,
    int? sampleRate,
  }) => SherpaOnnxAsrOptions(
    id: id ?? this.id,
    name: name ?? this.name,
    modelId: modelId ?? this.modelId,
    modelDirectory: modelDirectory ?? this.modelDirectory,
    language: language ?? this.language,
    sampleRate: sampleRate ?? this.sampleRate,
  );

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson(),
    'modelId': modelId,
    'modelDirectory': modelDirectory,
    'language': language,
    'sampleRate': sampleRate,
  };
}

class SystemAsrOptions extends AsrServiceOptions {
  SystemAsrOptions({super.id, super.name = 'System', this.localeId = ''})
    : super(kind: AsrServiceKind.system);

  final String localeId;

  @override
  bool get isConfigured => true;

  SystemAsrOptions copyWith({String? id, String? name, String? localeId}) =>
      SystemAsrOptions(
        id: id ?? this.id,
        name: name ?? this.name,
        localeId: localeId ?? this.localeId,
      );

  @override
  Map<String, dynamic> toJson() => {...baseJson(), 'localeId': localeId};
}

class OpenAiRealtimeAsrOptions extends AsrServiceOptions {
  OpenAiRealtimeAsrOptions({
    super.id,
    super.name = 'OpenAI Realtime',
    this.apiKey = '',
    this.websocketUrl = 'wss://api.openai.com/v1/realtime?intent=transcription',
    this.model = 'gpt-live-transcribe',
    this.language = '',
    this.prompt = '',
    this.sampleRate = 24000,
    this.vadThreshold = 0,
    this.prefixPaddingMs = 300,
    this.silenceDurationMs = 500,
  }) : super(kind: AsrServiceKind.openAiRealtime);

  final String apiKey;
  final String websocketUrl;
  final String model;
  final String language;
  final String prompt;
  final int sampleRate;
  final double vadThreshold;
  final int prefixPaddingMs;
  final int silenceDurationMs;

  @override
  bool get isConfigured =>
      apiKey.trim().isNotEmpty && websocketUrl.trim().isNotEmpty;

  OpenAiRealtimeAsrOptions copyWith({
    String? id,
    String? name,
    String? apiKey,
    String? websocketUrl,
    String? model,
    String? language,
    String? prompt,
    int? sampleRate,
    double? vadThreshold,
    int? prefixPaddingMs,
    int? silenceDurationMs,
  }) => OpenAiRealtimeAsrOptions(
    id: id ?? this.id,
    name: name ?? this.name,
    apiKey: apiKey ?? this.apiKey,
    websocketUrl: websocketUrl ?? this.websocketUrl,
    model: model ?? this.model,
    language: language ?? this.language,
    prompt: prompt ?? this.prompt,
    sampleRate: sampleRate ?? this.sampleRate,
    vadThreshold: vadThreshold ?? this.vadThreshold,
    prefixPaddingMs: prefixPaddingMs ?? this.prefixPaddingMs,
    silenceDurationMs: silenceDurationMs ?? this.silenceDurationMs,
  );

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson(),
    'apiKey': apiKey,
    'websocketUrl': websocketUrl,
    'model': model,
    'language': language,
    'prompt': prompt,
    'sampleRate': sampleRate,
    'vadThreshold': vadThreshold,
    'prefixPaddingMs': prefixPaddingMs,
    'silenceDurationMs': silenceDurationMs,
  };
}

/// File transcription settings shared by Groq, Mistral, and ElevenLabs.
class AudioTranscriptionAsrOptions extends AsrServiceOptions {
  factory AudioTranscriptionAsrOptions({
    String? id,
    required AsrServiceKind kind,
    String? name,
    String apiKey = '',
    String? baseUrl,
    String? model,
    String language = '',
    int sampleRate = 16000,
    int segmentDurationSec = 30,
  }) {
    final defaults = switch (kind) {
      AsrServiceKind.groq => (
        name: 'Groq',
        baseUrl: 'https://api.groq.com/openai/v1',
        model: 'whisper-large-v3',
      ),
      AsrServiceKind.mistral => (
        name: 'Mistral',
        baseUrl: 'https://api.mistral.ai/v1',
        model: 'voxtral-mini-latest',
      ),
      AsrServiceKind.elevenLabs => (
        name: 'ElevenLabs',
        baseUrl: 'https://api.elevenlabs.io/v1',
        model: 'scribe_v2',
      ),
      _ => throw ArgumentError.value(
        kind,
        'kind',
        'Unsupported transcription provider',
      ),
    };
    return AudioTranscriptionAsrOptions._(
      id: id,
      kind: kind,
      name: name ?? defaults.name,
      apiKey: apiKey,
      baseUrl: baseUrl ?? defaults.baseUrl,
      model: model ?? defaults.model,
      language: language,
      sampleRate: sampleRate,
      segmentDurationSec: segmentDurationSec,
    );
  }

  AudioTranscriptionAsrOptions._({
    super.id,
    required super.kind,
    required super.name,
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    required this.language,
    required this.sampleRate,
    required this.segmentDurationSec,
  });

  final String apiKey;
  final String baseUrl;
  final String model;
  final String language;
  final int sampleRate;
  final int segmentDurationSec;

  @override
  bool get isConfigured =>
      apiKey.trim().isNotEmpty &&
      baseUrl.trim().isNotEmpty &&
      model.trim().isNotEmpty &&
      sampleRate > 0;

  AudioTranscriptionAsrOptions copyWith({
    String? id,
    String? name,
    String? apiKey,
    String? baseUrl,
    String? model,
    String? language,
    int? sampleRate,
    int? segmentDurationSec,
  }) => AudioTranscriptionAsrOptions(
    id: id ?? this.id,
    kind: kind,
    name: name ?? this.name,
    apiKey: apiKey ?? this.apiKey,
    baseUrl: baseUrl ?? this.baseUrl,
    model: model ?? this.model,
    language: language ?? this.language,
    sampleRate: sampleRate ?? this.sampleRate,
    segmentDurationSec: segmentDurationSec ?? this.segmentDurationSec,
  );

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson(),
    'apiKey': apiKey,
    'baseUrl': baseUrl,
    'model': model,
    'language': language,
    'sampleRate': sampleRate,
    'segmentDurationSec': segmentDurationSec,
  };
}

class DashScopeAsrOptions extends AsrServiceOptions {
  DashScopeAsrOptions({
    super.id,
    super.name = 'DashScope',
    this.apiKey = '',
    this.websocketUrl = 'wss://dashscope.aliyuncs.com/api-ws/v1/realtime',
    this.model = 'qwen3-asr-flash-realtime',
    this.language = '',
    this.sampleRate = 16000,
    this.vadThreshold = 0,
    this.silenceDurationMs = 800,
  }) : super(kind: AsrServiceKind.dashScope);

  final String apiKey;
  final String websocketUrl;
  final String model;
  final String language;
  final int sampleRate;
  final double vadThreshold;
  final int silenceDurationMs;

  @override
  bool get isConfigured =>
      apiKey.trim().isNotEmpty && websocketUrl.trim().isNotEmpty;

  DashScopeAsrOptions copyWith({
    String? id,
    String? name,
    String? apiKey,
    String? websocketUrl,
    String? model,
    String? language,
    int? sampleRate,
    double? vadThreshold,
    int? silenceDurationMs,
  }) => DashScopeAsrOptions(
    id: id ?? this.id,
    name: name ?? this.name,
    apiKey: apiKey ?? this.apiKey,
    websocketUrl: websocketUrl ?? this.websocketUrl,
    model: model ?? this.model,
    language: language ?? this.language,
    sampleRate: sampleRate ?? this.sampleRate,
    vadThreshold: vadThreshold ?? this.vadThreshold,
    silenceDurationMs: silenceDurationMs ?? this.silenceDurationMs,
  );

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson(),
    'apiKey': apiKey,
    'websocketUrl': websocketUrl,
    'model': model,
    'language': language,
    'sampleRate': sampleRate,
    'vadThreshold': vadThreshold,
    'silenceDurationMs': silenceDurationMs,
  };
}

class VolcengineAsrOptions extends AsrServiceOptions {
  /// Compatible resource ids (official docs):
  /// - ASR 2.0 (Seed-ASR) duration: `volc.seedasr.sauc.duration` (current default)
  /// - ASR 1.0 (BigASR) duration: `volc.bigasr.sauc.duration`
  /// Do not auto-migrate existing user configs; wrong id → 403 not-granted.
  /// Needs real Key verification before changing the app default.
  static const String seedAsrDurationResourceId = 'volc.seedasr.sauc.duration';
  static const String bigAsrDurationResourceId = 'volc.bigasr.sauc.duration';
  static const List<String> knownDurationResourceIds = <String>[
    seedAsrDurationResourceId,
    bigAsrDurationResourceId,
  ];

  VolcengineAsrOptions({
    super.id,
    super.name = 'Volcengine',
    this.apiKey = '',
    this.websocketUrl = 'wss://openspeech.bytedance.com/api/v3/sauc/bigmodel',
    this.resourceId = seedAsrDurationResourceId,
    this.language = '',
  }) : super(kind: AsrServiceKind.volcengine);

  final String apiKey;
  final String websocketUrl;
  final String resourceId;
  final String language;

  @override
  bool get isConfigured =>
      apiKey.trim().isNotEmpty &&
      websocketUrl.trim().isNotEmpty &&
      resourceId.trim().isNotEmpty;

  VolcengineAsrOptions copyWith({
    String? id,
    String? name,
    String? apiKey,
    String? websocketUrl,
    String? resourceId,
    String? language,
  }) => VolcengineAsrOptions(
    id: id ?? this.id,
    name: name ?? this.name,
    apiKey: apiKey ?? this.apiKey,
    websocketUrl: websocketUrl ?? this.websocketUrl,
    resourceId: resourceId ?? this.resourceId,
    language: language ?? this.language,
  );

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson(),
    'apiKey': apiKey,
    'websocketUrl': websocketUrl,
    'resourceId': resourceId,
    'language': language,
  };
}

class MimoAsrOptions extends AsrServiceOptions {
  MimoAsrOptions({
    super.id,
    super.name = 'MiMo',
    this.apiKey = '',
    this.baseUrl = 'https://api.xiaomimimo.com/v1',
    this.model = 'mimo-v2.5-asr',
    this.language = 'auto',
    this.sampleRate = 16000,
    this.segmentDurationSec = 30,
  }) : super(kind: AsrServiceKind.mimo);

  final String apiKey;
  final String baseUrl;
  final String model;
  final String language;
  final int sampleRate;
  final int segmentDurationSec;

  @override
  bool get isConfigured =>
      apiKey.trim().isNotEmpty && baseUrl.trim().isNotEmpty;

  MimoAsrOptions copyWith({
    String? id,
    String? name,
    String? apiKey,
    String? baseUrl,
    String? model,
    String? language,
    int? sampleRate,
    int? segmentDurationSec,
  }) => MimoAsrOptions(
    id: id ?? this.id,
    name: name ?? this.name,
    apiKey: apiKey ?? this.apiKey,
    baseUrl: baseUrl ?? this.baseUrl,
    model: model ?? this.model,
    language: language ?? this.language,
    sampleRate: sampleRate ?? this.sampleRate,
    segmentDurationSec: segmentDurationSec ?? this.segmentDurationSec,
  );

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson(),
    'apiKey': apiKey,
    'baseUrl': baseUrl,
    'model': model,
    'language': language,
    'sampleRate': sampleRate,
    'segmentDurationSec': segmentDurationSec,
  };
}

enum QwenAudioAsrMode {
  realtime('qwen-audio-3.0-asr-flash-streaming'),
  transcription('qwen-audio-3.0-asr-flash');

  const QwenAudioAsrMode(this.defaultModel);
  final String defaultModel;
}

class QwenAudioAsrOptions extends AsrServiceOptions {
  QwenAudioAsrOptions({
    super.id,
    super.name = 'Qwen Audio',
    this.apiKey = '',
    this.workspaceId = '',
    this.region = 'cn-beijing',
    this.mode = QwenAudioAsrMode.realtime,
    this.endpoint = '',
    String? model,
    this.language = '',
    this.sampleRate = 16000,
    this.format = 'pcm',
    this.segmentDurationSec = 30,
  }) : model = model ?? mode.defaultModel,
       super(kind: AsrServiceKind.qwenAudio);

  final String apiKey;
  final String workspaceId;
  final String region;
  final QwenAudioAsrMode mode;

  /// Optional complete URL, including the request path.
  final String endpoint;
  final String model;
  final String language;
  final int sampleRate;
  final String format;
  final int segmentDurationSec;

  String get defaultEndpoint {
    final ws = workspaceId.trim();
    final reg = region.trim().isEmpty ? 'cn-beijing' : region.trim();
    final host = ws.isNotEmpty
        ? '$ws.$reg.maas.aliyuncs.com'
        : reg == 'ap-southeast-1'
        ? 'dashscope-intl.aliyuncs.com'
        : 'dashscope.aliyuncs.com';
    return mode == QwenAudioAsrMode.realtime
        ? 'wss://$host/api-ws/v1/inference'
        : 'https://$host/api/v1/services/aigc/multimodal-generation/generation';
  }

  String get endpointUrl =>
      endpoint.trim().isEmpty ? defaultEndpoint : endpoint.trim();

  bool get hasValidEndpoint {
    final uri = Uri.tryParse(endpointUrl);
    final schemes = mode == QwenAudioAsrMode.realtime
        ? const ['ws', 'wss']
        : const ['http', 'https'];
    return uri != null &&
        schemes.contains(uri.scheme) &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasFragment;
  }

  bool get hasValidWorkspaceId =>
      workspaceId.trim().isEmpty ||
      RegExp(
        r'^[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$',
      ).hasMatch(workspaceId.trim());

  @override
  bool get isConfigured =>
      apiKey.trim().isNotEmpty &&
      model.trim().isNotEmpty &&
      sampleRate > 0 &&
      hasValidWorkspaceId &&
      hasValidEndpoint;

  QwenAudioAsrOptions copyWith({
    String? id,
    String? name,
    String? apiKey,
    String? workspaceId,
    String? region,
    QwenAudioAsrMode? mode,
    String? endpoint,
    String? model,
    String? language,
    int? sampleRate,
    String? format,
    int? segmentDurationSec,
  }) => QwenAudioAsrOptions(
    id: id ?? this.id,
    name: name ?? this.name,
    apiKey: apiKey ?? this.apiKey,
    workspaceId: workspaceId ?? this.workspaceId,
    region: region ?? this.region,
    mode: mode ?? this.mode,
    endpoint: endpoint ?? this.endpoint,
    model: model ?? this.model,
    language: language ?? this.language,
    sampleRate: sampleRate ?? this.sampleRate,
    format: format ?? this.format,
    segmentDurationSec: segmentDurationSec ?? this.segmentDurationSec,
  );

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson(),
    'apiKey': apiKey,
    'workspaceId': workspaceId,
    'region': region,
    'mode': mode.name,
    'endpoint': endpoint,
    'model': model,
    'language': language,
    'sampleRate': sampleRate,
    'format': format,
    'segmentDurationSec': segmentDurationSec,
  };
}

class StepAsrOptions extends AsrServiceOptions {
  StepAsrOptions({
    super.id,
    super.name = 'Step',
    this.apiKey = '',
    this.baseUrl = 'https://api.stepfun.com',
    this.model = 'stepaudio-2.5-asr',
    this.language = 'auto',
    this.sampleRate = 16000,
    this.segmentDurationSec = 30,
    this.enableItn = true,
    this.enableTimestamp = false,
    this.hotwords = const [],
  }) : super(kind: AsrServiceKind.step);

  final String apiKey;
  final String baseUrl;
  final String model;
  final String language;
  final int sampleRate;
  final int segmentDurationSec;
  final bool enableItn;
  final bool enableTimestamp;
  final List<String> hotwords;

  @override
  bool get isConfigured =>
      apiKey.trim().isNotEmpty &&
      baseUrl.trim().isNotEmpty &&
      model.trim().isNotEmpty;

  StepAsrOptions copyWith({
    String? id,
    String? name,
    String? apiKey,
    String? baseUrl,
    String? model,
    String? language,
    int? sampleRate,
    int? segmentDurationSec,
    bool? enableItn,
    bool? enableTimestamp,
    List<String>? hotwords,
  }) => StepAsrOptions(
    id: id ?? this.id,
    name: name ?? this.name,
    apiKey: apiKey ?? this.apiKey,
    baseUrl: baseUrl ?? this.baseUrl,
    model: model ?? this.model,
    language: language ?? this.language,
    sampleRate: sampleRate ?? this.sampleRate,
    segmentDurationSec: segmentDurationSec ?? this.segmentDurationSec,
    enableItn: enableItn ?? this.enableItn,
    enableTimestamp: enableTimestamp ?? this.enableTimestamp,
    hotwords: hotwords ?? this.hotwords,
  );

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson(),
    'apiKey': apiKey,
    'baseUrl': baseUrl,
    'model': model,
    'language': language,
    'sampleRate': sampleRate,
    'segmentDurationSec': segmentDurationSec,
    'enableItn': enableItn,
    'enableTimestamp': enableTimestamp,
    'hotwords': hotwords,
  };
}

String? _optionalId(Object? value) {
  final id = value?.toString().trim() ?? '';
  return id.isEmpty ? null : id;
}

String _string(Object? value, [String fallback = '']) {
  return value == null ? fallback : value.toString();
}

int _positiveInt(Object? value, int fallback) {
  final result = value is num ? value.toInt() : int.tryParse('$value');
  return result == null || result <= 0 ? fallback : result;
}

int _nonNegativeInt(Object? value, int fallback) {
  final result = value is num ? value.toInt() : int.tryParse('$value');
  return result == null || result < 0 ? fallback : result;
}

double _double(Object? value, double fallback) {
  final result = value is num ? value.toDouble() : double.tryParse('$value');
  return result ?? fallback;
}

bool _bool(Object? value, bool fallback) => value is bool ? value : fallback;

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
