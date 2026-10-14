import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

enum NetworkTtsKind {
  openai,
  gemini,
  azure,
  minimax,
  qwen,
  qwenAudio,
  groq,
  xai,
  elevenlabs,
  mimo,
  step,
  fishAudio,
}

String networkTtsKindDisplayName(NetworkTtsKind k) {
  switch (k) {
    case NetworkTtsKind.openai:
      return 'OpenAI';
    case NetworkTtsKind.gemini:
      return 'Gemini';
    case NetworkTtsKind.azure:
      return 'Azure';
    case NetworkTtsKind.minimax:
      return 'MiniMax';
    case NetworkTtsKind.qwen:
      return 'Qwen';
    case NetworkTtsKind.qwenAudio:
      return 'Qwen Audio';
    case NetworkTtsKind.groq:
      return 'Groq';
    case NetworkTtsKind.xai:
      return 'xAI';
    case NetworkTtsKind.elevenlabs:
      return 'ElevenLabs';
    case NetworkTtsKind.mimo:
      return 'MiMo';
    case NetworkTtsKind.step:
      return 'StepFun';
    case NetworkTtsKind.fishAudio:
      return 'Fish Audio';
  }
}

bool isValidAzureTtsEndpoint(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null &&
      uri.hasAuthority &&
      uri.host.isNotEmpty &&
      (uri.scheme == 'http' || uri.scheme == 'https');
}

/// Migrates retired MiMo TTS model ids. `mimo-v2-tts` is no longer served.
String migrateMimoTtsModel(String? raw) {
  final model = (raw ?? '').trim();
  if (model.isEmpty || model == 'mimo-v2-tts') return 'mimo-v2.5-tts';
  return model;
}

abstract class TtsServiceOptions {
  final String id;
  final bool enabled;
  final String name;
  final NetworkTtsKind kind;

  TtsServiceOptions({
    String? id,
    required this.enabled,
    required this.name,
    required this.kind,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson();

  static TtsServiceOptions fromJson(Map<String, dynamic> json) {
    final type = (json['kind'] ?? '').toString();
    final enabled = json['enabled'] == true;
    final name = (json['name'] ?? '').toString();
    final id = (json['id'] ?? '').toString();
    switch (type) {
      case 'openai':
        return OpenAiTtsOptions(
          id: id.isEmpty ? null : id,
          enabled: enabled,
          name: name.isEmpty ? 'OpenAI TTS' : name,
          apiKey: (json['apiKey'] ?? '').toString(),
          baseUrl: (json['baseUrl'] ?? 'https://api.openai.com/v1').toString(),
          model: (json['model'] ?? 'gpt-4o-mini-tts').toString(),
          voice: (json['voice'] ?? 'alloy').toString(),
        );
      case 'gemini':
        return GeminiTtsOptions(
          id: id.isEmpty ? null : id,
          enabled: enabled,
          name: name.isEmpty ? 'Gemini TTS' : name,
          apiKey: (json['apiKey'] ?? '').toString(),
          baseUrl:
              (json['baseUrl'] ??
                      'https://generativelanguage.googleapis.com/v1beta')
                  .toString(),
          // New configs default to 3.1; existing persisted model strings are kept.
          model: (json['model'] ?? 'gemini-3.1-flash-tts-preview').toString(),
          voiceName: (json['voiceName'] ?? 'Kore').toString(),
        );
      case 'azure':
        return AzureTtsOptions(
          id: id.isEmpty ? null : id,
          enabled: enabled,
          name: name.isEmpty ? 'Azure TTS' : name,
          apiKey: (json['apiKey'] ?? '').toString(),
          baseUrl: (json['baseUrl'] ?? '').toString(),
          language: (json['language'] ?? 'zh-CN').toString(),
          voice: (json['voice'] ?? 'zh-CN-XiaoxiaoNeural').toString(),
        );
      case 'minimax':
        return MiniMaxTtsOptions(
          id: id.isEmpty ? null : id,
          enabled: enabled,
          name: name.isEmpty ? 'MiniMax TTS' : name,
          apiKey: (json['apiKey'] ?? '').toString(),
          baseUrl: (json['baseUrl'] ?? 'https://api.minimaxi.com/v1')
              .toString(),
          // New configs default to 2.8; existing persisted model strings are kept.
          model: (json['model'] ?? 'speech-2.8-turbo').toString(),
          voiceId: (json['voiceId'] ?? 'female-shaonv').toString(),
          emotion: (json['emotion'] ?? '').toString(),
          speed: _toDouble(json['speed'], 1.0),
          volume: _toDouble(json['volume'], 1.0),
          pitch: _toInt(json['pitch'], 0),
          languageBoost: (json['languageBoost'] ?? '').toString(),
          format: (json['format'] ?? 'mp3').toString(),
          sampleRate: _toInt(json['sampleRate'], 32000),
          bitrate: _toInt(json['bitrate'], 128000),
          channel: _toInt(json['channel'], 1),
          subtitleEnable: json['subtitleEnable'] == true,
          pronunciationDictionary:
              (json['pronunciationDictionary'] as List?)
                  ?.map((value) => value.toString())
                  .toList(growable: false) ??
              const <String>[],
        );
      case 'qwen':
        return QwenTtsOptions(
          id: id.isEmpty ? null : id,
          enabled: enabled,
          name: name.isEmpty ? 'Qwen TTS' : name,
          apiKey: (json['apiKey'] ?? '').toString(),
          baseUrl: (json['baseUrl'] ?? 'https://dashscope.aliyuncs.com/api/v1')
              .toString(),
          model: (json['model'] ?? 'qwen3-tts-flash').toString(),
          voice: (json['voice'] ?? 'Cherry').toString(),
          languageType: (json['languageType'] ?? 'Auto').toString(),
        );
      case 'qwen_audio':
      case 'qwenAudio':
        return QwenAudioTtsOptions(
          id: id.isEmpty ? null : id,
          enabled: enabled,
          name: name.isEmpty ? 'Qwen Audio TTS' : name,
          apiKey: (json['apiKey'] ?? '').toString(),
          workspaceId: (json['workspaceId'] ?? '').toString(),
          region: (json['region'] ?? 'cn-beijing').toString(),
          model: (json['model'] ?? 'qwen-audio-3.0-tts-flash').toString(),
          voice: (json['voice'] ?? 'longanhuan_v3.6').toString(),
          format: (json['format'] ?? 'mp3').toString(),
          sampleRate: _toInt(json['sampleRate'], 22050),
        );
      case 'groq':
        return GroqTtsOptions(
          id: id.isEmpty ? null : id,
          enabled: enabled,
          name: name.isEmpty ? 'Groq TTS' : name,
          apiKey: (json['apiKey'] ?? '').toString(),
          baseUrl: (json['baseUrl'] ?? 'https://api.groq.com/openai/v1')
              .toString(),
          model: (json['model'] ?? 'canopylabs/orpheus-v1-english').toString(),
          voice: (json['voice'] ?? 'austin').toString(),
        );
      case 'xai':
        return XaiTtsOptions(
          id: id.isEmpty ? null : id,
          enabled: enabled,
          name: name.isEmpty ? 'xAI TTS' : name,
          apiKey: (json['apiKey'] ?? '').toString(),
          baseUrl: (json['baseUrl'] ?? 'https://api.x.ai/v1').toString(),
          voiceId: (json['voiceId'] ?? 'eve').toString(),
          language: (json['language'] ?? 'auto').toString(),
        );
      case 'elevenlabs':
        return ElevenLabsTtsOptions(
          id: id.isEmpty ? null : id,
          enabled: enabled,
          name: name.isEmpty ? 'ElevenLabs TTS' : name,
          apiKey: (json['apiKey'] ?? '').toString(),
          baseUrl: (json['baseUrl'] ?? 'https://api.elevenlabs.io').toString(),
          modelId: (json['modelId'] ?? 'eleven_multilingual_v2').toString(),
          voiceId: (json['voiceId'] ?? '').toString(),
          outputFormat: (json['outputFormat'] ?? 'mp3_44100_128').toString(),
        );
      case 'mimo':
        return MimoTtsOptions(
          id: id.isEmpty ? null : id,
          enabled: enabled,
          name: name.isEmpty ? 'MiMo TTS' : name,
          apiKey: (json['apiKey'] ?? '').toString(),
          baseUrl: (json['baseUrl'] ?? 'https://api.xiaomimimo.com/v1')
              .toString(),
          model: migrateMimoTtsModel((json['model'] ?? '').toString()),
          voice: (json['voice'] ?? 'mimo_default').toString(),
          instruction: (json['instruction'] ?? '').toString(),
          stream: json['stream'] != false,
          optimizeTextPreview: json['optimizeTextPreview'] == true,
        );
      case 'step':
        return StepTtsOptions(
          id: id.isEmpty ? null : id,
          enabled: enabled,
          name: name.isEmpty ? 'StepFun TTS' : name,
          apiKey: (json['apiKey'] ?? '').toString(),
          baseUrl: (json['baseUrl'] ?? 'https://api.stepfun.com/v1').toString(),
          model: (json['model'] ?? 'stepaudio-2.5-tts').toString(),
          voice: (json['voice'] ?? 'cixingnansheng').toString(),
          responseFormat: (json['responseFormat'] ?? 'mp3').toString(),
          speed: _toDouble(json['speed'], 1.0),
          volume: _toDouble(json['volume'], 1.0),
          sampleRate: _toInt(json['sampleRate'], 24000),
          instruction: (json['instruction'] ?? '').toString(),
        );
      case 'fish_audio':
      case 'fishAudio':
        return FishAudioTtsOptions(
          id: id.isEmpty ? null : id,
          enabled: enabled,
          name: name.isEmpty ? 'Fish Audio TTS' : name,
          apiKey: (json['apiKey'] ?? '').toString(),
          baseUrl: (json['baseUrl'] ?? 'https://api.fish.audio').toString(),
          model: (json['model'] ?? 's2.1-pro').toString(),
          referenceId: (json['referenceId'] ?? '').toString(),
          format: (json['format'] ?? 'mp3').toString(),
          temperature: _toDouble(json['temperature'], 0.7),
          topP: _toDouble(json['topP'], 0.7),
          speed: _toDouble(json['speed'], 1.0),
          sampleRate: _toInt(json['sampleRate'], 44100),
          latency: (json['latency'] ?? 'normal').toString(),
        );
      default:
        // Fallback to OpenAI shape to avoid crash if kind missing
        return OpenAiTtsOptions(
          id: id.isEmpty ? null : id,
          enabled: enabled,
          name: name.isEmpty ? 'OpenAI TTS' : name,
          apiKey: (json['apiKey'] ?? '').toString(),
          baseUrl: (json['baseUrl'] ?? 'https://api.openai.com/v1').toString(),
          model: (json['model'] ?? 'gpt-4o-mini-tts').toString(),
          voice: (json['voice'] ?? 'alloy').toString(),
        );
    }
  }
}

double _toDouble(dynamic v, double def) {
  if (v == null) return def;
  if (v is num) return v.toDouble();
  try {
    return double.parse(v.toString());
  } catch (_) {
    return def;
  }
}

int _toInt(dynamic v, int def) {
  if (v == null) return def;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? def;
}

class OpenAiTtsOptions extends TtsServiceOptions {
  final String apiKey;
  final String baseUrl;
  final String model;
  final String voice;
  OpenAiTtsOptions({
    super.id,
    required super.enabled,
    required super.name,
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    required this.voice,
  }) : super(kind: NetworkTtsKind.openai);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'enabled': enabled,
    'name': name,
    'kind': 'openai',
    'apiKey': apiKey,
    'baseUrl': baseUrl,
    'model': model,
    'voice': voice,
  };
}

class GeminiTtsOptions extends TtsServiceOptions {
  final String apiKey;
  final String baseUrl;
  final String model;
  final String voiceName;
  GeminiTtsOptions({
    super.id,
    required super.enabled,
    required super.name,
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    required this.voiceName,
  }) : super(kind: NetworkTtsKind.gemini);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'enabled': enabled,
    'name': name,
    'kind': 'gemini',
    'apiKey': apiKey,
    'baseUrl': baseUrl,
    'model': model,
    'voiceName': voiceName,
  };
}

class AzureTtsOptions extends TtsServiceOptions {
  final String apiKey;
  final String baseUrl;
  final String language;
  final String voice;

  AzureTtsOptions({
    super.id,
    required super.enabled,
    required super.name,
    required this.apiKey,
    required this.baseUrl,
    required this.language,
    required this.voice,
  }) : super(kind: NetworkTtsKind.azure);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'enabled': enabled,
    'name': name,
    'kind': 'azure',
    'apiKey': apiKey,
    'baseUrl': baseUrl,
    'language': language,
    'voice': voice,
  };
}

class MiniMaxTtsOptions extends TtsServiceOptions {
  final String apiKey;
  final String baseUrl;
  final String model;
  final String voiceId;
  final String emotion;
  final double speed;
  final double volume;
  final int pitch;
  final String languageBoost;
  final String format;
  final int sampleRate;
  final int bitrate;
  final int channel;
  final bool subtitleEnable;
  final List<String> pronunciationDictionary;
  MiniMaxTtsOptions({
    super.id,
    required super.enabled,
    required super.name,
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    required this.voiceId,
    this.emotion = '',
    this.speed = 1.0,
    this.volume = 1.0,
    this.pitch = 0,
    this.languageBoost = '',
    this.format = 'mp3',
    this.sampleRate = 32000,
    this.bitrate = 128000,
    this.channel = 1,
    this.subtitleEnable = false,
    this.pronunciationDictionary = const <String>[],
  }) : super(kind: NetworkTtsKind.minimax);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'enabled': enabled,
    'name': name,
    'kind': 'minimax',
    'apiKey': apiKey,
    'baseUrl': baseUrl,
    'model': model,
    'voiceId': voiceId,
    'emotion': emotion,
    'speed': speed,
    'volume': volume,
    'pitch': pitch,
    'languageBoost': languageBoost,
    'format': format,
    'sampleRate': sampleRate,
    'bitrate': bitrate,
    'channel': channel,
    'subtitleEnable': subtitleEnable,
    'pronunciationDictionary': pronunciationDictionary,
  };
}

class QwenTtsOptions extends TtsServiceOptions {
  final String apiKey;
  final String baseUrl;
  final String model;
  final String voice;
  final String languageType;

  QwenTtsOptions({
    super.id,
    required super.enabled,
    required super.name,
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    required this.voice,
    required this.languageType,
  }) : super(kind: NetworkTtsKind.qwen);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'enabled': enabled,
    'name': name,
    'kind': 'qwen',
    'apiKey': apiKey,
    'baseUrl': baseUrl,
    'model': model,
    'voice': voice,
    'languageType': languageType,
  };
}

class GroqTtsOptions extends TtsServiceOptions {
  static const int maxCharsPerRequest = 200;

  final String apiKey;
  final String baseUrl;
  final String model;
  final String voice;

  GroqTtsOptions({
    super.id,
    required super.enabled,
    required super.name,
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    required this.voice,
  }) : super(kind: NetworkTtsKind.groq);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'enabled': enabled,
    'name': name,
    'kind': 'groq',
    'apiKey': apiKey,
    'baseUrl': baseUrl,
    'model': model,
    'voice': voice,
  };
}

class XaiTtsOptions extends TtsServiceOptions {
  final String apiKey;
  final String baseUrl;
  final String voiceId;
  final String language;

  XaiTtsOptions({
    super.id,
    required super.enabled,
    required super.name,
    required this.apiKey,
    required this.baseUrl,
    required this.voiceId,
    required this.language,
  }) : super(kind: NetworkTtsKind.xai);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'enabled': enabled,
    'name': name,
    'kind': 'xai',
    'apiKey': apiKey,
    'baseUrl': baseUrl,
    'voiceId': voiceId,
    'language': language,
  };
}

class ElevenLabsTtsOptions extends TtsServiceOptions {
  final String apiKey;
  final String baseUrl;
  final String modelId;
  final String voiceId;
  final String outputFormat; // e.g. mp3_44100_128

  ElevenLabsTtsOptions({
    super.id,
    required super.enabled,
    required super.name,
    required this.apiKey,
    required this.baseUrl,
    required this.modelId,
    required this.voiceId,
    this.outputFormat = 'mp3_44100_128',
  }) : super(kind: NetworkTtsKind.elevenlabs);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'enabled': enabled,
    'name': name,
    'kind': 'elevenlabs',
    'apiKey': apiKey,
    'baseUrl': baseUrl,
    'modelId': modelId,
    'voiceId': voiceId,
    'outputFormat': outputFormat,
  };
}

class MimoTtsOptions extends TtsServiceOptions {
  final String apiKey;
  final String baseUrl;
  final String model;
  final String voice;
  final String instruction;
  final bool stream;
  final bool optimizeTextPreview;

  MimoTtsOptions({
    super.id,
    required super.enabled,
    required super.name,
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    required this.voice,
    this.instruction = '',
    this.stream = true,
    this.optimizeTextPreview = false,
  }) : super(kind: NetworkTtsKind.mimo);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'enabled': enabled,
    'name': name,
    'kind': 'mimo',
    'apiKey': apiKey,
    'baseUrl': baseUrl,
    'model': model,
    'voice': voice,
    'instruction': instruction,
    'stream': stream,
    'optimizeTextPreview': optimizeTextPreview,
  };
}

class QwenAudioTtsOptions extends TtsServiceOptions {
  final String apiKey;
  final String workspaceId;
  final String region;
  final String model;
  final String voice;
  final String format;
  final int sampleRate;

  QwenAudioTtsOptions({
    super.id,
    required super.enabled,
    required super.name,
    required this.apiKey,
    required this.workspaceId,
    this.region = 'cn-beijing',
    required this.model,
    required this.voice,
    this.format = 'mp3',
    this.sampleRate = 22050,
  }) : super(kind: NetworkTtsKind.qwenAudio);

  String get websocketUrl {
    final ws = workspaceId.trim();
    final reg = region.trim().isEmpty ? 'cn-beijing' : region.trim();
    if (ws.isEmpty) {
      return 'wss://dashscope.aliyuncs.com/api-ws/v1/inference';
    }
    return 'wss://$ws.$reg.maas.aliyuncs.com/api-ws/v1/inference';
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'enabled': enabled,
    'name': name,
    'kind': 'qwen_audio',
    'apiKey': apiKey,
    'workspaceId': workspaceId,
    'region': region,
    'model': model,
    'voice': voice,
    'format': format,
    'sampleRate': sampleRate,
  };
}

class StepTtsOptions extends TtsServiceOptions {
  static const int maxCharsPerRequest = 1000;

  final String apiKey;
  final String baseUrl;
  final String model;
  final String voice;
  final String responseFormat;
  final double speed;
  final double volume;
  final int sampleRate;
  final String instruction;

  StepTtsOptions({
    super.id,
    required super.enabled,
    required super.name,
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    required this.voice,
    this.responseFormat = 'mp3',
    this.speed = 1.0,
    this.volume = 1.0,
    this.sampleRate = 24000,
    this.instruction = '',
  }) : super(kind: NetworkTtsKind.step);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'enabled': enabled,
    'name': name,
    'kind': 'step',
    'apiKey': apiKey,
    'baseUrl': baseUrl,
    'model': model,
    'voice': voice,
    'responseFormat': responseFormat,
    'speed': speed,
    'volume': volume,
    'sampleRate': sampleRate,
    'instruction': instruction,
  };
}

class FishAudioTtsOptions extends TtsServiceOptions {
  final String apiKey;
  final String baseUrl;
  final String model;
  final String referenceId;
  final String format;
  final double temperature;
  final double topP;
  final double speed;
  final int sampleRate;
  final String latency;

  FishAudioTtsOptions({
    super.id,
    required super.enabled,
    required super.name,
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    required this.referenceId,
    this.format = 'mp3',
    this.temperature = 0.7,
    this.topP = 0.7,
    this.speed = 1.0,
    this.sampleRate = 44100,
    this.latency = 'normal',
  }) : super(kind: NetworkTtsKind.fishAudio);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'enabled': enabled,
    'name': name,
    'kind': 'fish_audio',
    'apiKey': apiKey,
    'baseUrl': baseUrl,
    'model': model,
    'referenceId': referenceId,
    'format': format,
    'temperature': temperature,
    'topP': topP,
    'speed': speed,
    'sampleRate': sampleRate,
    'latency': latency,
  };
}

class NetworkTtsResult {
  final Uint8List bytes;
  final String mime; // e.g. audio/mpeg or audio/wav
  final int? sampleRate; // for PCM->WAV info
  NetworkTtsResult({required this.bytes, required this.mime, this.sampleRate});
}

const List<String> miniMaxEmotionValues = <String>[
  '',
  'happy',
  'sad',
  'angry',
  'fearful',
  'disgusted',
  'surprised',
  'calm',
  'fluent',
  'whipser',
];

// FLAC remains accepted for existing profiles, but is not offered until the
// app can safely merge multiple encoded FLAC responses.
const List<String> miniMaxAudioFormats = <String>['mp3', 'pcm'];
const Set<String> _miniMaxSupportedAudioFormats = <String>{
  'mp3',
  'pcm',
  'flac',
};

const List<int> miniMaxSampleRates = <int>[
  8000,
  16000,
  22050,
  24000,
  32000,
  44100,
];

const List<int> miniMaxBitrates = <int>[32000, 64000, 128000, 256000];

const Map<String, List<int>> fishAudioSampleRates = <String, List<int>>{
  'wav': <int>[8000, 16000, 24000, 32000, 44100],
  'pcm': <int>[8000, 16000, 24000, 32000, 44100],
  'mp3': <int>[32000, 44100],
  'opus': <int>[48000],
};

int networkTtsMaxCharsPerRequest(TtsServiceOptions options) =>
    options is GroqTtsOptions ? GroqTtsOptions.maxCharsPerRequest : 220;

typedef QwenAudioWebSocketConnector =
    Future<WebSocket> Function(String url, {Map<String, dynamic>? headers});

class NetworkTtsService {
  static Future<NetworkTtsResult> synthesize({
    required TtsServiceOptions options,
    required String text,
    http.Client? client,
    FutureOr<bool> Function()? cancelled,
    QwenAudioWebSocketConnector? qwenAudioWebSocketConnector,
  }) async {
    final c = client ?? http.Client();
    try {
      switch (options.kind) {
        case NetworkTtsKind.openai:
          return await _openAiSpeech(
            options as OpenAiTtsOptions,
            text,
            c,
            cancelled,
          );
        case NetworkTtsKind.gemini:
          return await _geminiSpeech(
            options as GeminiTtsOptions,
            text,
            c,
            cancelled,
          );
        case NetworkTtsKind.azure:
          return await _azureSpeech(
            options as AzureTtsOptions,
            text,
            c,
            cancelled,
          );
        case NetworkTtsKind.minimax:
          return await _miniMaxSpeech(
            options as MiniMaxTtsOptions,
            text,
            c,
            cancelled,
          );
        case NetworkTtsKind.qwen:
          return await _qwenSpeech(
            options as QwenTtsOptions,
            text,
            c,
            cancelled,
          );
        case NetworkTtsKind.qwenAudio:
          return await _qwenAudioSpeech(
            options as QwenAudioTtsOptions,
            text,
            cancelled,
            qwenAudioWebSocketConnector,
          );
        case NetworkTtsKind.groq:
          return await _groqSpeech(
            options as GroqTtsOptions,
            text,
            c,
            cancelled,
          );
        case NetworkTtsKind.xai:
          return await _xaiSpeech(options as XaiTtsOptions, text, c, cancelled);
        case NetworkTtsKind.elevenlabs:
          return await _elevenLabsSpeech(
            options as ElevenLabsTtsOptions,
            text,
            c,
            cancelled,
          );
        case NetworkTtsKind.mimo:
          return await _mimoSpeech(
            options as MimoTtsOptions,
            text,
            c,
            cancelled,
          );
        case NetworkTtsKind.step:
          return await _stepSpeech(
            options as StepTtsOptions,
            text,
            c,
            cancelled,
          );
        case NetworkTtsKind.fishAudio:
          return await _fishAudioSpeech(
            options as FishAudioTtsOptions,
            text,
            c,
            cancelled,
          );
      }
    } finally {
      if (client == null) {
        try {
          c.close();
        } catch (_) {}
      }
    }
  }

  static Future<NetworkTtsResult> _openAiSpeech(
    OpenAiTtsOptions opt,
    String text,
    http.Client c,
    FutureOr<bool> Function()? cancelled,
  ) async {
    final uri = Uri.parse(
      opt.baseUrl.endsWith('/')
          ? '${opt.baseUrl}audio/speech'
          : '${opt.baseUrl}/audio/speech',
    );
    final body = jsonEncode({
      'model': opt.model,
      'input': text,
      'voice': opt.voice,
      'response_format': 'mp3',
    });
    final req = http.Request('POST', uri)
      ..headers['Authorization'] = 'Bearer ${opt.apiKey}'
      ..headers['Content-Type'] = 'application/json'
      ..body = body;
    final resp = await c.send(req);
    if (cancelled != null && await cancelled()) {
      throw _Cancelled();
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final text = await resp.stream.bytesToString();
      throw Exception(
        'OpenAI TTS failed: ${resp.statusCode} ${resp.reasonPhrase} $text',
      );
    }
    final bytes = await resp.stream.toBytes();
    return NetworkTtsResult(
      bytes: Uint8List.fromList(bytes),
      mime: 'audio/mpeg',
    );
  }

  static Future<NetworkTtsResult> _geminiSpeech(
    GeminiTtsOptions opt,
    String text,
    http.Client c,
    FutureOr<bool> Function()? cancelled,
  ) async {
    final uri = Uri.parse(
      opt.baseUrl.endsWith('/')
          ? '${opt.baseUrl}models/${opt.model}:generateContent'
          : '${opt.baseUrl}/models/${opt.model}:generateContent',
    );
    final body = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': text},
          ],
        },
      ],
      'generationConfig': {
        'responseModalities': ['AUDIO'],
        'speechConfig': {
          'voiceConfig': {
            'prebuiltVoiceConfig': {'voiceName': opt.voiceName},
          },
        },
      },
      'model': opt.model,
    });

    final req = http.Request('POST', uri)
      ..headers['x-goog-api-key'] = opt.apiKey
      ..headers['Content-Type'] = 'application/json'
      ..body = body;
    final resp = await c.send(req);
    if (cancelled != null && await cancelled()) {
      throw _Cancelled();
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final text = await resp.stream.bytesToString();
      throw Exception(
        'Gemini TTS failed: ${resp.statusCode} ${resp.reasonPhrase} $text',
      );
    }
    final textResp = await resp.stream.bytesToString();
    final jsonObj = jsonDecode(textResp) as Map<String, dynamic>;
    final candidates = (jsonObj['candidates'] as List?) ?? const [];
    if (candidates.isEmpty) {
      throw Exception('Gemini TTS: empty candidates');
    }
    final parts =
        (((candidates[0] as Map)['content'] as Map)['parts'] as List?);
    if (parts == null || parts.isEmpty) {
      throw Exception('Gemini TTS: empty audio parts');
    }
    final inline = (parts[0] as Map)['inlineData'] as Map?;
    if (inline == null) throw Exception('Gemini TTS: no inlineData');
    final dataB64 = (inline['data'] ?? '').toString();
    if (dataB64.isEmpty) throw Exception('Gemini TTS: empty audio data');
    final pcm = base64Decode(dataB64);
    // Convert PCM (24kHz 16-bit mono) to WAV
    final wav = _pcmToWav(Uint8List.fromList(pcm), sampleRate: 24000);
    return NetworkTtsResult(bytes: wav, mime: 'audio/wav', sampleRate: 24000);
  }

  static Future<NetworkTtsResult> _azureSpeech(
    AzureTtsOptions opt,
    String text,
    http.Client c,
    FutureOr<bool> Function()? cancelled,
  ) async {
    final configuredBase = opt.baseUrl.trim();
    if (!isValidAzureTtsEndpoint(configuredBase)) {
      throw Exception('Azure TTS endpoint must be an absolute HTTP(S) URL');
    }
    final base = Uri.parse(configuredBase);
    final basePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    final uri = base.replace(
      path: basePath.endsWith('/cognitiveservices/v1')
          ? basePath
          : '$basePath/cognitiveservices/v1',
    );
    final attributeEscape = const HtmlEscape(HtmlEscapeMode.attribute);
    final textEscape = const HtmlEscape(HtmlEscapeMode.element);
    final body =
        '<speak version="1.0" xml:lang="${attributeEscape.convert(opt.language)}">'
        '<voice name="${attributeEscape.convert(opt.voice)}">'
        '${textEscape.convert(text)}</voice></speak>';
    final abort = Completer<void>();
    var finished = false;

    Future<bool> cancellationRequested() async {
      if (cancelled == null || !await cancelled()) return false;
      if (!abort.isCompleted) abort.complete();
      return true;
    }

    Future<void> monitorCancellation() async {
      while (!finished) {
        if (await cancellationRequested()) return;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }

    if (cancelled != null) unawaited(monitorCancellation());
    const fallbackDelays = <Duration>[
      Duration(milliseconds: 200),
      Duration(milliseconds: 600),
    ];
    late http.StreamedResponse resp;
    try {
      for (var attempt = 0; ; attempt++) {
        if (await cancellationRequested()) throw _Cancelled();
        final req =
            http.AbortableRequest('POST', uri, abortTrigger: abort.future)
              ..headers['Ocp-Apim-Subscription-Key'] = opt.apiKey
              ..headers['Content-Type'] = 'application/ssml+xml'
              ..headers['X-Microsoft-OutputFormat'] =
                  'audio-24khz-96kbitrate-mono-mp3'
              ..headers['User-Agent'] = 'Kelivo'
              ..body = body;
        resp = await c.send(req);
        if (await cancellationRequested()) {
          await _cancelAzureResponseStream(resp.stream);
          throw _Cancelled();
        }
        if (!const <int>{429, 502, 503}.contains(resp.statusCode) ||
            attempt == fallbackDelays.length) {
          break;
        }
        final delay =
            _azureRetryAfterDelay(resp.headers['retry-after']) ??
            fallbackDelays[attempt];
        await _cancelAzureResponseStream(resp.stream);
        await _waitForAzureRetry(delay, cancellationRequested);
      }
      final responseBytes = await _readAzureResponseBytes(
        resp.stream,
        abort.future,
      );
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception(
          'Azure TTS failed: ${resp.statusCode} ${resp.reasonPhrase} '
          '${utf8.decode(responseBytes, allowMalformed: true)}',
        );
      }
      return NetworkTtsResult(bytes: responseBytes, mime: 'audio/mpeg');
    } on http.RequestAbortedException {
      throw _Cancelled();
    } finally {
      finished = true;
    }
  }

  static Future<NetworkTtsResult> _miniMaxSpeech(
    MiniMaxTtsOptions opt,
    String text,
    http.Client c,
    FutureOr<bool> Function()? cancelled,
  ) async {
    _validateMiniMaxOptions(opt);
    final uri = Uri.parse(
      opt.baseUrl.endsWith('/')
          ? '${opt.baseUrl}t2a_v2'
          : '${opt.baseUrl}/t2a_v2',
    );
    final voiceSetting = <String, dynamic>{
      'voice_id': opt.voiceId,
      'speed': opt.speed,
      'vol': opt.volume,
      'pitch': opt.pitch,
      if (opt.emotion.trim().isNotEmpty) 'emotion': opt.emotion.trim(),
    };
    final body = jsonEncode({
      'model': opt.model,
      'text': text,
      'stream': true,
      'output_format': 'hex',
      'stream_options': {'exclude_aggregated_audio': true},
      'voice_setting': voiceSetting,
      'audio_setting': {
        'sample_rate': opt.sampleRate,
        'bitrate': opt.bitrate,
        'format': opt.format,
        'channel': opt.channel,
      },
      if (opt.languageBoost.trim().isNotEmpty)
        'language_boost': opt.languageBoost.trim(),
      if (opt.pronunciationDictionary.isNotEmpty)
        'pronunciation_dict': {'tone': opt.pronunciationDictionary},
      'subtitle_enable': opt.subtitleEnable,
    });

    final req = http.Request('POST', uri)
      ..headers['Authorization'] = 'Bearer ${opt.apiKey}'
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'text/event-stream'
      ..body = body;

    final resp = await c.send(req);
    if (cancelled != null && await cancelled()) {
      throw _Cancelled();
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final txt = await resp.stream.bytesToString();
      throw Exception(
        'MiniMax TTS failed: ${resp.statusCode} ${resp.reasonPhrase} $txt',
      );
    }

    final buf = BytesBuilder(copy: false);
    final events = StreamIterator<String>(_sseDataStream(resp.stream));
    try {
      while (await _moveNextWithCancellation(events, cancelled)) {
        final dataStr = events.current;
        if (dataStr == '[DONE]') continue;
        late final Map<String, dynamic> obj;
        try {
          obj = Map<String, dynamic>.from(jsonDecode(dataStr) as Map);
        } catch (error) {
          throw FormatException(
            'MiniMax TTS returned malformed SSE data.',
            error,
          );
        }
        _throwForMiniMaxBusinessError(obj);
        final data = obj['data'] as Map?;
        final audioHex = (data?['audio'] ?? '').toString();
        if (audioHex.isEmpty) continue;
        try {
          buf.add(_hexToBytes(audioHex));
        } catch (error) {
          throw FormatException(
            'MiniMax TTS returned invalid hex audio.',
            error,
          );
        }
      }
    } finally {
      await events.cancel();
    }

    final bytes = buf.takeBytes();
    if (bytes.isEmpty) {
      throw Exception('MiniMax TTS returned no audio data');
    }
    final format = opt.format.toLowerCase();
    final audioBytes = Uint8List.fromList(bytes);
    if (format == 'pcm') {
      return NetworkTtsResult(
        bytes: _pcmToWav(
          audioBytes,
          sampleRate: opt.sampleRate,
          channels: opt.channel,
        ),
        mime: 'audio/wav',
        sampleRate: opt.sampleRate,
      );
    }
    return NetworkTtsResult(
      bytes: audioBytes,
      mime: _audioMimeForFormat(format),
      sampleRate: opt.sampleRate,
    );
  }

  static Future<NetworkTtsResult> _qwenSpeech(
    QwenTtsOptions opt,
    String text,
    http.Client c,
    FutureOr<bool> Function()? cancelled,
  ) async {
    final uri = Uri.parse(
      _joinUrl(opt.baseUrl, '/services/aigc/multimodal-generation/generation'),
    );
    final body = jsonEncode({
      'model': opt.model,
      'input': {
        'text': text,
        'voice': opt.voice,
        'language_type': opt.languageType,
      },
    });
    final req = http.Request('POST', uri)
      ..headers['Authorization'] = 'Bearer ${opt.apiKey}'
      ..headers['Content-Type'] = 'application/json'
      ..headers['X-DashScope-SSE'] = 'enable'
      ..body = body;
    final resp = await c.send(req);
    if (cancelled != null && await cancelled()) {
      throw _Cancelled();
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final txt = await resp.stream.bytesToString();
      throw Exception(
        'Qwen TTS failed: ${resp.statusCode} ${resp.reasonPhrase} $txt',
      );
    }

    final buf = BytesBuilder(copy: false);
    await for (final data in _sseDataStream(resp.stream)) {
      if (cancelled != null && await cancelled()) {
        throw _Cancelled();
      }
      if (data == '[DONE]') continue;
      final obj = jsonDecode(data) as Map<String, dynamic>;
      final output = obj['output'] as Map<String, dynamic>?;
      final audio = output?['audio'] as Map<String, dynamic>?;
      final dataB64 = (audio?['data'] ?? '').toString();
      if (dataB64.isEmpty) continue;
      buf.add(base64Decode(dataB64));
    }
    final audioBytes = buf.takeBytes();
    if (audioBytes.isEmpty) {
      throw Exception('Qwen TTS returned no audio data');
    }
    if (audioBytes.lengthInBytes >= 4 &&
        ByteData.sublistView(audioBytes).getUint32(0, Endian.little) ==
            _riffFourCc) {
      final wav = _parseWav(audioBytes, allowStreamingLengths: true);
      final normalized = _encodeWav(wav.formatData, wav.audioData);
      return NetworkTtsResult(
        bytes: normalized,
        mime: 'audio/wav',
        sampleRate: ByteData.sublistView(
          wav.formatData,
        ).getUint32(4, Endian.little),
      );
    }
    if (audioBytes.lengthInBytes.isOdd) {
      throw const FormatException(
        'Qwen PCM data is not aligned to 16-bit samples.',
      );
    }
    return NetworkTtsResult(
      bytes: _pcmToWav(audioBytes, sampleRate: 24000),
      mime: 'audio/wav',
      sampleRate: 24000,
    );
  }

  static Future<NetworkTtsResult> _groqSpeech(
    GroqTtsOptions opt,
    String text,
    http.Client c,
    FutureOr<bool> Function()? cancelled,
  ) async {
    final uri = Uri.parse(_joinUrl(opt.baseUrl, '/audio/speech'));
    final body = jsonEncode({
      'model': opt.model,
      'input': text,
      'voice': opt.voice,
      'response_format': 'wav',
    });
    final req = http.Request('POST', uri)
      ..headers['Authorization'] = 'Bearer ${opt.apiKey}'
      ..headers['Content-Type'] = 'application/json'
      ..body = body;
    final resp = await c.send(req);
    if (cancelled != null && await cancelled()) {
      throw _Cancelled();
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final txt = await resp.stream.bytesToString();
      throw Exception(
        'Groq TTS failed: ${resp.statusCode} ${resp.reasonPhrase} $txt',
      );
    }
    final bytes = await resp.stream.toBytes();
    return NetworkTtsResult(
      bytes: Uint8List.fromList(bytes),
      mime: 'audio/wav',
    );
  }

  static Future<NetworkTtsResult> _xaiSpeech(
    XaiTtsOptions opt,
    String text,
    http.Client c,
    FutureOr<bool> Function()? cancelled,
  ) async {
    final uri = Uri.parse(_joinUrl(opt.baseUrl, '/tts'));
    final body = jsonEncode({
      'text': text,
      'voice_id': opt.voiceId,
      'language': opt.language,
    });
    final req = http.Request('POST', uri)
      ..headers['Authorization'] = 'Bearer ${opt.apiKey}'
      ..headers['Content-Type'] = 'application/json'
      ..body = body;
    final resp = await c.send(req);
    if (cancelled != null && await cancelled()) {
      throw _Cancelled();
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final txt = await resp.stream.bytesToString();
      throw Exception(
        'xAI TTS failed: ${resp.statusCode} ${resp.reasonPhrase} $txt',
      );
    }
    final bytes = await resp.stream.toBytes();
    return NetworkTtsResult(
      bytes: Uint8List.fromList(bytes),
      mime: 'audio/mpeg',
    );
  }

  static Future<NetworkTtsResult> _elevenLabsSpeech(
    ElevenLabsTtsOptions opt,
    String text,
    http.Client c,
    FutureOr<bool> Function()? cancelled,
  ) async {
    final base = opt.baseUrl.endsWith('/')
        ? opt.baseUrl.substring(0, opt.baseUrl.length - 1)
        : opt.baseUrl;
    final outputFmt = (opt.outputFormat.isEmpty)
        ? 'mp3_44100_128'
        : opt.outputFormat;
    final apiBase = base.toLowerCase().endsWith('/v1') ? base : '$base/v1';
    final uri = Uri.parse(
      '$apiBase/text-to-speech/${opt.voiceId}?output_format=$outputFmt',
    );
    final body = jsonEncode({'text': text, 'model_id': opt.modelId});
    final req = http.Request('POST', uri)
      ..headers['xi-api-key'] = opt.apiKey
      ..headers['Content-Type'] = 'application/json'
      ..body = body;
    final resp = await c.send(req);
    if (cancelled != null && await cancelled()) {
      throw _Cancelled();
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final txt = await resp.stream.bytesToString();
      throw Exception(
        'ElevenLabs TTS failed: ${resp.statusCode} ${resp.reasonPhrase} $txt',
      );
    }
    final bytes = await resp.stream.toBytes();
    final lower = outputFmt.toLowerCase();
    final audioBytes = Uint8List.fromList(bytes);
    if (lower.startsWith('pcm_')) {
      final sampleRate = int.tryParse(lower.substring(4));
      if (sampleRate == null || sampleRate <= 0 || audioBytes.length.isOdd) {
        throw FormatException('Invalid ElevenLabs PCM response format.');
      }
      return NetworkTtsResult(
        bytes: _pcmToWav(audioBytes, sampleRate: sampleRate),
        mime: 'audio/wav',
        sampleRate: sampleRate,
      );
    }
    final mime = lower.startsWith('mp3_')
        ? 'audio/mpeg'
        : lower.startsWith('opus_')
        ? 'audio/ogg'
        : 'application/octet-stream';
    return NetworkTtsResult(bytes: audioBytes, mime: mime);
  }

  static Future<NetworkTtsResult> _mimoSpeech(
    MimoTtsOptions opt,
    String text,
    http.Client c,
    FutureOr<bool> Function()? cancelled,
  ) async {
    final model = migrateMimoTtsModel(opt.model);
    final isVoiceDesign = model == 'mimo-v2.5-tts-voicedesign';
    final isVoiceClone = model == 'mimo-v2.5-tts-voiceclone';
    if (isVoiceDesign && opt.instruction.trim().isEmpty) {
      throw ArgumentError('MiMo Voice Design requires a voice description.');
    }
    if (isVoiceClone) {
      _validateMimoVoiceCloneReference(opt.voice);
    } else if (!isVoiceDesign && opt.voice.trim().isEmpty) {
      throw ArgumentError('MiMo TTS requires a built-in voice.');
    }
    final uri = Uri.parse(_joinUrl(opt.baseUrl, '/chat/completions'));
    final instruction = opt.instruction.trim();
    final messages = <Map<String, dynamic>>[
      if (instruction.isNotEmpty || isVoiceClone)
        {'role': 'user', 'content': instruction},
      {'role': 'assistant', 'content': text},
    ];
    final useStream = opt.stream;
    final audio = <String, dynamic>{
      'format': useStream ? 'pcm16' : 'wav',
      if (isVoiceDesign)
        'optimize_text_preview': opt.optimizeTextPreview
      else
        'voice': opt.voice.trim(),
    };
    final body = jsonEncode({
      'model': model,
      'messages': messages,
      'audio': audio,
      'stream': useStream,
    });
    final req = http.Request('POST', uri)
      ..headers['api-key'] = opt.apiKey
      ..headers['Content-Type'] = 'application/json'
      ..body = body;
    final resp = await c.send(req);
    if (cancelled != null && await cancelled()) {
      throw _Cancelled();
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final err = await resp.stream.bytesToString();
      throw Exception(
        'MiMo TTS failed: ${resp.statusCode} ${resp.reasonPhrase} $err',
      );
    }
    if (!useStream) {
      final raw = await resp.stream.bytesToString();
      if (cancelled != null && await cancelled()) {
        throw _Cancelled();
      }
      final jsonObj = jsonDecode(raw) as Map<String, dynamic>;
      final choices = (jsonObj['choices'] as List?) ?? const [];
      if (choices.isEmpty) {
        throw Exception('MiMo TTS returned empty choices');
      }
      final message = (choices.first as Map)['message'] as Map?;
      final audio = message?['audio'] as Map?;
      final dataB64 = (audio?['data'] ?? '').toString();
      if (dataB64.isEmpty) {
        throw Exception('MiMo TTS returned no audio data');
      }
      final bytes = base64Decode(dataB64);
      return NetworkTtsResult(
        bytes: Uint8List.fromList(bytes),
        mime: 'audio/wav',
        sampleRate: 24000,
      );
    }
    final buf = BytesBuilder(copy: false);
    await for (final data in _sseDataStream(resp.stream)) {
      if (cancelled != null && await cancelled()) {
        throw _Cancelled();
      }
      if (data == '[DONE]') continue;
      final jsonObj = jsonDecode(data) as Map<String, dynamic>;
      final choices = (jsonObj['choices'] as List?) ?? const [];
      if (choices.isEmpty) continue;
      final choice = choices.first as Map;
      final delta = choice['delta'] as Map?;
      final message = choice['message'] as Map?;
      final audio = (delta?['audio'] ?? message?['audio']) as Map?;
      final dataB64 = (audio?['data'] ?? '').toString();
      if (dataB64.isEmpty) continue;
      buf.add(base64Decode(dataB64));
    }
    final pcm = buf.takeBytes();
    if (pcm.isEmpty) {
      throw Exception('MiMo TTS returned no audio chunks');
    }
    return NetworkTtsResult(
      bytes: _pcmToWav(Uint8List.fromList(pcm), sampleRate: 24000),
      mime: 'audio/wav',
      sampleRate: 24000,
    );
  }

  static Future<NetworkTtsResult> _stepSpeech(
    StepTtsOptions opt,
    String text,
    http.Client c,
    FutureOr<bool> Function()? cancelled,
  ) async {
    final chunks = _splitStepTtsText(text, StepTtsOptions.maxCharsPerRequest);
    final parts = <Uint8List>[];
    for (final chunk in chunks) {
      if (cancelled != null && await cancelled()) {
        throw _Cancelled();
      }
      final uri = Uri.parse(_joinUrl(opt.baseUrl, '/audio/speech'));
      final body = <String, dynamic>{
        'model': opt.model,
        'input': chunk,
        'voice': opt.voice,
        // Official StepFun fields are snake_case.
        'response_format': opt.responseFormat,
        'speed': opt.speed,
        'volume': opt.volume,
        'sample_rate': opt.sampleRate,
      };
      // instruction is only valid for stepaudio-2.5-tts; other models error.
      if (opt.model.trim() == 'stepaudio-2.5-tts' &&
          opt.instruction.trim().isNotEmpty) {
        body['instruction'] = opt.instruction.trim();
      }
      final req = http.Request('POST', uri)
        ..headers['Authorization'] = 'Bearer ${opt.apiKey}'
        ..headers['Content-Type'] = 'application/json'
        ..headers['Accept'] = 'application/octet-stream'
        ..body = jsonEncode(body);
      final resp = await c.send(req);
      if (cancelled != null && await cancelled()) {
        throw _Cancelled();
      }
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        final err = await resp.stream.bytesToString();
        throw Exception(
          'StepFun TTS failed: ${resp.statusCode} ${resp.reasonPhrase} $err',
        );
      }
      parts.add(Uint8List.fromList(await resp.stream.toBytes()));
    }
    if (parts.isEmpty) {
      throw Exception('StepFun TTS returned empty audio');
    }
    final format = opt.responseFormat.toLowerCase();
    if (format == 'pcm') {
      final pcm = BytesBuilder(copy: false);
      for (final part in parts) {
        pcm.add(part);
      }
      return NetworkTtsResult(
        bytes: _pcmToWav(
          Uint8List.fromList(pcm.takeBytes()),
          sampleRate: opt.sampleRate,
        ),
        mime: 'audio/wav',
        sampleRate: opt.sampleRate,
      );
    }
    if (format == 'wav' && parts.length > 1) {
      return NetworkTtsResult(
        bytes: combineWavAudio(parts),
        mime: 'audio/wav',
        sampleRate: opt.sampleRate,
      );
    }
    if (format == 'flac' && parts.length > 1) {
      throw StateError(
        'StepFun FLAC cannot be merged across multiple text chunks.',
      );
    }
    if (parts.length == 1) {
      return NetworkTtsResult(
        bytes: parts.single,
        mime: _audioMimeForFormat(format),
        sampleRate: opt.sampleRate,
      );
    }
    final merged = BytesBuilder(copy: false);
    for (final p in parts) {
      merged.add(p);
    }
    return NetworkTtsResult(
      bytes: Uint8List.fromList(merged.takeBytes()),
      mime: _audioMimeForFormat(format),
      sampleRate: opt.sampleRate,
    );
  }

  static Future<NetworkTtsResult> _fishAudioSpeech(
    FishAudioTtsOptions opt,
    String text,
    http.Client c,
    FutureOr<bool> Function()? cancelled,
  ) async {
    _validateFishAudioOptions(opt);
    final uri = Uri.parse(_joinUrl(opt.baseUrl, '/v1/tts'));
    final body = <String, dynamic>{
      'text': text,
      'format': opt.format,
      'temperature': opt.temperature,
      'top_p': opt.topP,
      'prosody': {'speed': opt.speed},
      'sample_rate': opt.sampleRate,
      'latency': opt.latency,
      'reference_id': opt.referenceId.trim(),
    };
    final req = http.Request('POST', uri)
      ..headers['Authorization'] = 'Bearer ${opt.apiKey}'
      ..headers['Content-Type'] = 'application/json'
      ..headers['model'] = opt.model
      ..body = jsonEncode(body);
    final resp = await c.send(req);
    if (cancelled != null && await cancelled()) {
      throw _Cancelled();
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final err = await resp.stream.bytesToString();
      throw Exception(
        'Fish Audio TTS failed: ${resp.statusCode} ${resp.reasonPhrase} $err',
      );
    }
    final bytes = Uint8List.fromList(await resp.stream.toBytes());
    if (bytes.isEmpty) {
      throw Exception('Fish Audio TTS returned empty audio');
    }
    if (opt.format.toLowerCase() == 'pcm') {
      return NetworkTtsResult(
        bytes: _pcmToWav(bytes, sampleRate: opt.sampleRate),
        mime: 'audio/wav',
        sampleRate: opt.sampleRate,
      );
    }
    return NetworkTtsResult(
      bytes: bytes,
      mime: _audioMimeForFormat(opt.format),
      sampleRate: opt.sampleRate,
    );
  }

  static Future<NetworkTtsResult> _qwenAudioSpeech(
    QwenAudioTtsOptions opt,
    String text,
    FutureOr<bool> Function()? cancelled,
    QwenAudioWebSocketConnector? connector,
  ) async {
    final uri = Uri.parse(opt.websocketUrl);
    final connect =
        connector ??
        (String url, {Map<String, dynamic>? headers}) =>
            WebSocket.connect(url, headers: headers);
    final socket = await connect(
      uri.toString(),
      headers: <String, dynamic>{
        'Authorization': 'Bearer ${opt.apiKey}',
        if (opt.workspaceId.trim().isNotEmpty)
          'X-DashScope-WorkSpace': opt.workspaceId.trim(),
      },
    );
    final taskId = const Uuid().v4();
    final audio = BytesBuilder(copy: false);
    final started = Completer<void>();
    final finished = Completer<void>();
    // Lifecycle failures can arrive before the corresponding await is
    // attached. Keep a listener present while preserving errors for awaits.
    unawaited(started.future.catchError((Object _) {}));
    unawaited(finished.future.catchError((Object _) {}));
    void fail(Object error, [StackTrace? stackTrace]) {
      if (!started.isCompleted) {
        started.completeError(error, stackTrace ?? StackTrace.current);
      }
      if (!finished.isCompleted) {
        finished.completeError(error, stackTrace ?? StackTrace.current);
      }
    }

    late final StreamSubscription<dynamic> sub;
    sub = socket.listen(
      (event) {
        if (event is List<int>) {
          audio.add(event);
          return;
        }
        if (event is! String) {
          fail(FormatException('Qwen Audio TTS returned an unknown frame.'));
          return;
        }
        late final Map<String, dynamic> obj;
        try {
          obj = Map<String, dynamic>.from(jsonDecode(event) as Map);
        } catch (error) {
          fail(
            FormatException(
              'Qwen Audio TTS returned malformed lifecycle JSON.',
              error,
            ),
          );
          return;
        }
        final header = (obj['header'] as Map?)?.cast<String, dynamic>() ?? {};
        final name = (header['event'] ?? '').toString();
        if (name == 'task-started' && !started.isCompleted) {
          started.complete();
        } else if (name == 'result-generated') {
          // Sentence/timestamp metadata only. Audio arrives in binary frames.
        } else if (name == 'task-finished' && !finished.isCompleted) {
          finished.complete();
        } else if (name == 'task-failed' || name == 'error') {
          final payload = obj['payload'] as Map?;
          final msg =
              (header['error_message'] ??
                      header['error_code'] ??
                      payload?['message'] ??
                      name)
                  .toString();
          fail(Exception('Qwen Audio TTS failed: $msg'));
        }
      },
      onError: (Object e, StackTrace st) {
        fail(e, st);
      },
      onDone: () {
        if (!started.isCompleted || !finished.isCompleted) {
          fail(Exception('Qwen Audio TTS socket closed before task-finished'));
        }
      },
      cancelOnError: false,
    );
    try {
      socket.add(
        jsonEncode({
          'header': {
            'action': 'run-task',
            'task_id': taskId,
            'streaming': 'duplex',
          },
          'payload': {
            'task_group': 'audio',
            'task': 'tts',
            'function': 'SpeechSynthesizer',
            'model': opt.model,
            'parameters': {
              'text_type': 'PlainText',
              'voice': opt.voice,
              'format': opt.format,
              'sample_rate': opt.sampleRate,
            },
            'input': {},
          },
        }),
      );
      await _waitWithCancellation(
        started.future.timeout(const Duration(seconds: 30)),
        cancelled,
      );
      socket.add(
        jsonEncode({
          'header': {
            'action': 'continue-task',
            'task_id': taskId,
            'streaming': 'duplex',
          },
          'payload': {
            'input': {'text': text},
          },
        }),
      );
      socket.add(
        jsonEncode({
          'header': {
            'action': 'finish-task',
            'task_id': taskId,
            'streaming': 'duplex',
          },
          'payload': {'input': {}},
        }),
      );
      await _waitWithCancellation(
        finished.future.timeout(const Duration(seconds: 120)),
        cancelled,
      );
      final bytes = audio.takeBytes();
      if (bytes.isEmpty) {
        throw Exception('Qwen Audio TTS returned no audio');
      }
      final fmt = opt.format.toLowerCase();
      if (fmt == 'pcm') {
        return NetworkTtsResult(
          bytes: _pcmToWav(
            Uint8List.fromList(bytes),
            sampleRate: opt.sampleRate,
          ),
          mime: 'audio/wav',
          sampleRate: opt.sampleRate,
        );
      }
      return NetworkTtsResult(
        bytes: Uint8List.fromList(bytes),
        mime: _audioMimeForFormat(fmt),
        sampleRate: opt.sampleRate,
      );
    } finally {
      await sub.cancel();
      await socket.close();
    }
  }
}

List<String> _splitStepTtsText(String text, int maxChars) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const <String>[];
  if (trimmed.length <= maxChars) return <String>[trimmed];
  final out = <String>[];
  var i = 0;
  while (i < trimmed.length) {
    final end = (i + maxChars < trimmed.length) ? i + maxChars : trimmed.length;
    out.add(trimmed.substring(i, end));
    i = end;
  }
  return out;
}

String _audioMimeForFormat(String format) {
  switch (format.toLowerCase()) {
    case 'wav':
      return 'audio/wav';
    case 'pcm':
      return 'audio/pcm';
    case 'opus':
    case 'ogg':
      return 'audio/ogg';
    case 'flac':
      return 'audio/flac';
    case 'mp3':
    default:
      return 'audio/mpeg';
  }
}

void _validateMiniMaxOptions(MiniMaxTtsOptions opt) {
  if (opt.voiceId.trim().isEmpty) {
    throw ArgumentError('MiniMax TTS requires a voice ID.');
  }
  final emotion = opt.emotion.trim();
  if (!miniMaxEmotionValues.contains(emotion)) {
    throw ArgumentError.value(
      opt.emotion,
      'emotion',
      'Unsupported MiniMax emotion.',
    );
  }
  if (opt.speed < 0.5 || opt.speed > 2.0) {
    throw RangeError.value(opt.speed, 'speed', 'Must be between 0.5 and 2.0.');
  }
  if (opt.volume < 0.1 || opt.volume > 10.0) {
    throw RangeError.value(
      opt.volume,
      'volume',
      'Must be between 0.1 and 10.0.',
    );
  }
  if (opt.pitch < -12 || opt.pitch > 12) {
    throw RangeError.range(opt.pitch, -12, 12, 'pitch');
  }
  final format = opt.format.toLowerCase();
  if (!_miniMaxSupportedAudioFormats.contains(format)) {
    throw ArgumentError.value(
      opt.format,
      'format',
      'Unsupported audio format.',
    );
  }
  if (!miniMaxSampleRates.contains(opt.sampleRate)) {
    throw ArgumentError.value(
      opt.sampleRate,
      'sampleRate',
      'Unsupported MiniMax sample rate.',
    );
  }
  if (!miniMaxBitrates.contains(opt.bitrate)) {
    throw ArgumentError.value(
      opt.bitrate,
      'bitrate',
      'Unsupported MiniMax bitrate.',
    );
  }
  if (opt.channel != 1 && opt.channel != 2) {
    throw ArgumentError.value(opt.channel, 'channel', 'Must be 1 or 2.');
  }
}

void _throwForMiniMaxBusinessError(Map<String, dynamic> event) {
  final baseResponse = event['base_resp'] as Map?;
  if (baseResponse == null) return;
  final statusCode = _toInt(baseResponse['status_code'], 0);
  if (statusCode == 0) return;
  final message = (baseResponse['status_msg'] ?? 'Unknown error').toString();
  throw Exception('MiniMax TTS failed: $statusCode $message');
}

void _validateMimoVoiceCloneReference(String voice) {
  final value = voice.trim();
  final match = RegExp(
    r'^data:audio/(?:mpeg|mp3|wav);base64,',
    caseSensitive: false,
  ).firstMatch(value);
  if (match == null) {
    throw ArgumentError('MiMo Voice Clone requires a WAV/MP3 Base64 data URI.');
  }
  late final List<int> bytes;
  try {
    bytes = base64Decode(value.substring(match.end));
  } catch (_) {
    throw ArgumentError(
      'MiMo Voice Clone reference audio is not valid Base64.',
    );
  }
  if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
    throw ArgumentError(
      'MiMo Voice Clone reference audio must be between 1 byte and 10 MB.',
    );
  }
}

void _validateFishAudioOptions(FishAudioTtsOptions opt) {
  if (opt.referenceId.trim().isEmpty) {
    throw ArgumentError('Fish Audio TTS requires a voice/reference ID.');
  }
  final format = opt.format.toLowerCase();
  final sampleRates = fishAudioSampleRates[format];
  if (sampleRates == null) {
    throw ArgumentError.value(
      opt.format,
      'format',
      'Unsupported audio format.',
    );
  }
  if (!sampleRates.contains(opt.sampleRate)) {
    throw ArgumentError.value(
      opt.sampleRate,
      'sampleRate',
      'Fish Audio $format requires one of: ${sampleRates.join(', ')} Hz.',
    );
  }
}

Future<bool> _moveNextWithCancellation<T>(
  StreamIterator<T> iterator,
  FutureOr<bool> Function()? cancelled,
) async {
  if (cancelled == null) return iterator.moveNext();
  final pending = iterator.moveNext();
  while (true) {
    final result = await Future.any<({bool moved, bool value})>([
      pending.then((value) => (moved: true, value: value)),
      Future<({bool moved, bool value})>.delayed(
        const Duration(milliseconds: 50),
        () => (moved: false, value: false),
      ),
    ]);
    if (result.moved) return result.value;
    if (await cancelled()) {
      throw _Cancelled();
    }
  }
}

Future<void> _waitWithCancellation(
  Future<void> future,
  FutureOr<bool> Function()? cancelled,
) async {
  if (cancelled == null) return future;
  while (true) {
    final completed = await Future.any<bool>([
      future.then((_) => true),
      Future<bool>.delayed(const Duration(milliseconds: 50), () => false),
    ]);
    if (completed) return;
    if (await cancelled()) throw _Cancelled();
  }
}

Duration? _azureRetryAfterDelay(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return null;
  final seconds = int.tryParse(raw);
  if (seconds != null && seconds >= 0) return Duration(seconds: seconds);
  try {
    final delay = HttpDate.parse(
      raw,
    ).toUtc().difference(DateTime.now().toUtc());
    return delay.isNegative ? Duration.zero : delay;
  } catch (_) {
    return null;
  }
}

Future<void> _cancelAzureResponseStream(Stream<List<int>> stream) async {
  try {
    await stream.listen((_) {}).cancel();
  } catch (_) {}
}

Future<void> _waitForAzureRetry(
  Duration delay,
  FutureOr<bool> Function() cancelled,
) async {
  final elapsed = Stopwatch()..start();
  while (elapsed.elapsed < delay) {
    if (await cancelled()) throw _Cancelled();
    final remaining = delay - elapsed.elapsed;
    await Future<void>.delayed(
      remaining < const Duration(milliseconds: 50)
          ? remaining
          : const Duration(milliseconds: 50),
    );
  }
  if (await cancelled()) throw _Cancelled();
}

Future<Uint8List> _readAzureResponseBytes(
  Stream<List<int>> stream,
  Future<void> abortTrigger,
) async {
  final chunks = BytesBuilder(copy: false);
  final iterator = StreamIterator<List<int>>(stream);
  var aborted = false;
  unawaited(
    abortTrigger.then((_) async {
      aborted = true;
      try {
        await iterator.cancel();
      } catch (_) {}
    }),
  );
  try {
    while (await iterator.moveNext()) {
      chunks.add(iterator.current);
    }
    if (aborted) throw _Cancelled();
  } finally {
    try {
      await iterator.cancel();
    } catch (_) {}
  }
  return chunks.takeBytes();
}

class _Cancelled implements Exception {}

String _joinUrl(String baseUrl, String path) {
  final base = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  final suffix = path.startsWith('/') ? path : '/$path';
  return '$base$suffix';
}

Stream<String> _sseDataStream(Stream<List<int>> stream) async* {
  final lines = stream
      .transform(const Utf8Decoder())
      .transform(const LineSplitter());
  final buffer = StringBuffer();
  await for (final line in lines) {
    if (line.isEmpty) {
      if (buffer.isNotEmpty) {
        yield buffer.toString();
        buffer.clear();
      }
      continue;
    }
    if (!line.startsWith('data:')) continue;
    if (buffer.isNotEmpty) buffer.write('\n');
    buffer.write(line.substring(5).trim());
  }
  if (buffer.isNotEmpty) {
    yield buffer.toString();
  }
}

Uint8List _pcmToWav(
  Uint8List pcm, {
  required int sampleRate,
  int channels = 1,
  int bitsPerSample = 16,
}) {
  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  final dataLength = pcm.lengthInBytes;
  final totalLength = 36 + dataLength;
  final out = BytesBuilder();
  void writeString(String s) => out.add(utf8.encode(s));
  void writeInt32LE(int v) =>
      out.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
  void writeInt16LE(int v) =>
      out.add(Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little));

  writeString('RIFF');
  writeInt32LE(totalLength);
  writeString('WAVE');
  writeString('fmt ');
  writeInt32LE(16); // PCM chunk size
  writeInt16LE(1); // audio format PCM
  writeInt16LE(channels);
  writeInt32LE(sampleRate);
  writeInt32LE(byteRate);
  writeInt16LE(channels * bitsPerSample ~/ 8);
  writeInt16LE(bitsPerSample);
  writeString('data');
  writeInt32LE(dataLength);
  out.add(pcm);
  return out.toBytes();
}

/// Concatenates RIFF/WAVE files that use the same `fmt ` chunk.
Uint8List combineWavAudio(List<Uint8List> wavFiles) {
  if (wavFiles.isEmpty) {
    throw ArgumentError.value(wavFiles, 'wavFiles', 'Must not be empty.');
  }

  final parsed = wavFiles.map(_parseWav).toList(growable: false);
  final format = parsed.first.formatData;
  for (final wav in parsed.skip(1)) {
    if (!_sameBytes(format, wav.formatData)) {
      throw const FormatException('WAV fmt chunks do not match.');
    }
  }
  if (parsed.length == 1) return Uint8List.fromList(wavFiles.single);

  return _encodeWav(format, parsed.expand((wav) => wav.audioData));
}

Uint8List _encodeWav(Uint8List format, Iterable<Uint8List> audioData) {
  final formatTag = _supportedWavFormatTag(format);
  final view = ByteData.sublistView(format);
  final channels = view.getUint16(2, Endian.little);
  final sampleRate = view.getUint32(4, Endian.little);
  final byteRate = view.getUint32(8, Endian.little);
  final blockAlign = view.getUint16(12, Endian.little);
  final bitsPerSample = view.getUint16(14, Endian.little);
  if (channels == 0 ||
      sampleRate == 0 ||
      bitsPerSample == 0 ||
      bitsPerSample % 8 != 0 ||
      blockAlign != channels * (bitsPerSample ~/ 8) ||
      byteRate != sampleRate * blockAlign ||
      (formatTag == 3 && bitsPerSample != 32 && bitsPerSample != 64)) {
    throw const FormatException('Invalid WAV audio format.');
  }

  final combinedData = BytesBuilder(copy: false);
  for (final data in audioData) {
    if (data.lengthInBytes % blockAlign != 0) {
      throw const FormatException('Invalid WAV block alignment.');
    }
    combinedData.add(data);
  }
  final audioBytes = combinedData.takeBytes();
  if (audioBytes.isEmpty) {
    throw const FormatException('WAV data chunk is empty.');
  }

  final body = BytesBuilder(copy: false)..add(utf8.encode('WAVE'));
  _writeRiffChunk(body, 'fmt ', format);
  if (formatTag != 1) {
    final sampleCount = audioBytes.lengthInBytes ~/ blockAlign;
    _writeRiffChunk(body, 'fact', _uint32Le(sampleCount));
  }
  _writeRiffChunk(body, 'data', audioBytes);

  final bodyBytes = body.takeBytes();
  if (bodyBytes.lengthInBytes > 0xffffffff) {
    throw const FormatException('Combined WAV file is too large.');
  }
  final output = BytesBuilder(copy: false)..add(utf8.encode('RIFF'));
  output.add(_uint32Le(bodyBytes.lengthInBytes));
  output.add(bodyBytes);
  return output.takeBytes();
}

const int _riffFourCc = 0x46464952;
const int _waveFourCc = 0x45564157;
const int _fmtFourCc = 0x20746d66;
const int _dataFourCc = 0x61746164;

({Uint8List formatData, List<Uint8List> audioData}) _parseWav(
  Uint8List bytes, {
  bool allowStreamingLengths = false,
}) {
  if (bytes.lengthInBytes < 12) {
    throw const FormatException('WAV file is too short.');
  }
  final view = ByteData.sublistView(bytes);
  if (view.getUint32(0, Endian.little) != _riffFourCc ||
      view.getUint32(8, Endian.little) != _waveFourCc) {
    throw const FormatException('Invalid RIFF/WAVE header.');
  }

  final declaredSize = view.getUint32(4, Endian.little);
  final declaredEnd = 8 + declaredSize;
  final streamingRiff =
      allowStreamingLengths &&
      declaredEnd > bytes.lengthInBytes &&
      _isStreamingWavLength(declaredSize);
  final riffEnd = streamingRiff ? bytes.lengthInBytes : declaredEnd;
  if (riffEnd < 12 || riffEnd != bytes.lengthInBytes) {
    throw const FormatException('Invalid RIFF size.');
  }

  final audioData = <Uint8List>[];
  Uint8List? formatData;
  var offset = 12;
  while (offset < riffEnd) {
    if (offset + 8 > riffEnd) {
      throw const FormatException('Truncated WAV chunk header.');
    }
    final id = view.getUint32(offset, Endian.little);
    final size = view.getUint32(offset + 4, Endian.little);
    final dataStart = offset + 8;
    // Streaming WAV writers may use a sentinel for data, or derive its size
    // from the placeholder RIFF end (for example 0x7fffff9b in Qwen responses).
    // Only the audio chunk may consume the remaining response in this case.
    final streamingData =
        allowStreamingLengths &&
        id == _dataFourCc &&
        dataStart + size > riffEnd &&
        (_isStreamingWavLength(size) ||
            (streamingRiff && dataStart + size == declaredEnd));
    final dataEnd = streamingData ? riffEnd : dataStart + size;
    final paddedEnd = dataEnd + (!streamingData && size.isOdd ? 1 : 0);
    if (dataEnd > riffEnd || paddedEnd > riffEnd) {
      throw const FormatException('Truncated WAV chunk data.');
    }

    final data = Uint8List.fromList(bytes.sublist(dataStart, dataEnd));
    if (id == _fmtFourCc) {
      if (formatData != null && !_sameBytes(formatData, data)) {
        throw const FormatException('WAV contains conflicting fmt chunks.');
      }
      formatData = data;
    } else if (id == _dataFourCc) {
      audioData.add(data);
    }
    offset = paddedEnd;
  }

  if (formatData == null || audioData.isEmpty) {
    throw const FormatException('WAV must contain fmt and data chunks.');
  }
  return (formatData: formatData, audioData: audioData);
}

bool _isStreamingWavLength(int size) =>
    size == 0xffffffff || size == 0x7fffffff || size == 0x7fffffbf;

int _supportedWavFormatTag(Uint8List format) {
  if (format.lengthInBytes < 16) {
    throw const FormatException('Invalid WAV fmt chunk.');
  }
  final view = ByteData.sublistView(format);
  final tag = view.getUint16(0, Endian.little);
  if (tag == 1 || tag == 3) return tag;
  if (tag == 0xfffe && format.lengthInBytes >= 40) {
    final subFormat = view.getUint16(24, Endian.little);
    if (subFormat == 1 || subFormat == 3) return subFormat;
  }
  throw const FormatException('Unsupported WAV format for concatenation.');
}

void _writeRiffChunk(BytesBuilder output, String id, Uint8List data) {
  output.add(utf8.encode(id));
  output.add(_uint32Le(data.lengthInBytes));
  output.add(data);
  if (data.lengthInBytes.isOdd) output.addByte(0);
}

Uint8List _uint32Le(int value) {
  return Uint8List(4)..buffer.asByteData().setUint32(0, value, Endian.little);
}

bool _sameBytes(Uint8List left, Uint8List right) {
  if (left.lengthInBytes != right.lengthInBytes) return false;
  for (var i = 0; i < left.lengthInBytes; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

Uint8List _hexToBytes(String hex) {
  final clean = hex.replaceAll(RegExp(r'\s+'), '');
  if (clean.length % 2 != 0) {
    throw FormatException('Hex string must have even length');
  }
  final out = Uint8List(clean.length ~/ 2);
  for (int i = 0; i < clean.length; i += 2) {
    out[i ~/ 2] = int.parse(clean.substring(i, i + 2), radix: 16);
  }
  return out;
}
