import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

enum NetworkTtsKind {
  openai,
  gemini,
  minimax,
  qwen,
  groq,
  xai,
  elevenlabs,
  mimo,
}

String networkTtsKindDisplayName(NetworkTtsKind k) {
  switch (k) {
    case NetworkTtsKind.openai:
      return 'OpenAI';
    case NetworkTtsKind.gemini:
      return 'Gemini';
    case NetworkTtsKind.minimax:
      return 'MiniMax';
    case NetworkTtsKind.qwen:
      return 'Qwen';
    case NetworkTtsKind.groq:
      return 'Groq';
    case NetworkTtsKind.xai:
      return 'xAI';
    case NetworkTtsKind.elevenlabs:
      return 'ElevenLabs';
    case NetworkTtsKind.mimo:
      return 'MiMo';
  }
}

abstract class TtsServiceOptions {
  final String id;
  final bool enabled;
  final String name;
  final NetworkTtsKind kind;
  final String? linkedProviderId;

  TtsServiceOptions({
    String? id,
    required this.enabled,
    required this.name,
    required this.kind,
    this.linkedProviderId,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson();

  static TtsServiceOptions fromJson(Map<String, dynamic> json) {
    final type = (json['kind'] ?? '').toString();
    final enabled = json['enabled'] == true;
    final name = (json['name'] ?? '').toString();
    final id = (json['id'] ?? '').toString();
    final linkedId = json['linkedProviderId'];
    final linkedProviderId = (linkedId is String && linkedId.isNotEmpty)
        ? linkedId
        : null;
    switch (type) {
      case 'openai':
        return OpenAiTtsOptions(
          id: id.isEmpty ? null : id,
          enabled: enabled,
          name: name.isEmpty ? 'OpenAI TTS' : name,
          linkedProviderId: linkedProviderId,
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
          linkedProviderId: linkedProviderId,
          apiKey: (json['apiKey'] ?? '').toString(),
          baseUrl:
              (json['baseUrl'] ??
                      'https://generativelanguage.googleapis.com/v1beta')
                  .toString(),
          model: (json['model'] ?? 'gemini-2.5-flash-preview-tts').toString(),
          voiceName: (json['voiceName'] ?? 'Kore').toString(),
        );
      case 'minimax':
        return MiniMaxTtsOptions(
          id: id.isEmpty ? null : id,
          enabled: enabled,
          name: name.isEmpty ? 'MiniMax TTS' : name,
          linkedProviderId: linkedProviderId,
          apiKey: (json['apiKey'] ?? '').toString(),
          baseUrl: (json['baseUrl'] ?? 'https://api.minimaxi.com/v1')
              .toString(),
          model: (json['model'] ?? 'speech-2.6-turbo').toString(),
          voiceId: (json['voiceId'] ?? 'female-shaonv').toString(),
          emotion: (json['emotion'] ?? 'calm').toString(),
          speed: _toDouble(json['speed'], 1.0),
        );
      case 'qwen':
        return QwenTtsOptions(
          id: id.isEmpty ? null : id,
          enabled: enabled,
          name: name.isEmpty ? 'Qwen TTS' : name,
          linkedProviderId: linkedProviderId,
          apiKey: (json['apiKey'] ?? '').toString(),
          baseUrl: (json['baseUrl'] ?? 'https://dashscope.aliyuncs.com/api/v1')
              .toString(),
          model: (json['model'] ?? 'qwen3-tts-flash').toString(),
          voice: (json['voice'] ?? 'Cherry').toString(),
          languageType: (json['languageType'] ?? 'Auto').toString(),
        );
      case 'groq':
        return GroqTtsOptions(
          id: id.isEmpty ? null : id,
          enabled: enabled,
          name: name.isEmpty ? 'Groq TTS' : name,
          linkedProviderId: linkedProviderId,
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
          linkedProviderId: linkedProviderId,
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
          linkedProviderId: linkedProviderId,
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
          linkedProviderId: linkedProviderId,
          apiKey: (json['apiKey'] ?? '').toString(),
          baseUrl: (json['baseUrl'] ?? 'https://api.xiaomimimo.com/v1')
              .toString(),
          model: (json['model'] ?? 'mimo-v2-tts').toString(),
          voice: (json['voice'] ?? 'mimo_default').toString(),
        );
      default:
        // Fallback to OpenAI shape to avoid crash if kind missing
        return OpenAiTtsOptions(
          id: id.isEmpty ? null : id,
          enabled: enabled,
          name: name.isEmpty ? 'OpenAI TTS' : name,
          linkedProviderId: linkedProviderId,
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

class OpenAiTtsOptions extends TtsServiceOptions {
  final String apiKey;
  final String baseUrl;
  final String model;
  final String voice;
  OpenAiTtsOptions({
    super.id,
    required super.enabled,
    required super.name,
    super.linkedProviderId,
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
    if (linkedProviderId != null) 'linkedProviderId': linkedProviderId,
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
    super.linkedProviderId,
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
    if (linkedProviderId != null) 'linkedProviderId': linkedProviderId,
    'apiKey': apiKey,
    'baseUrl': baseUrl,
    'model': model,
    'voiceName': voiceName,
  };
}

class MiniMaxTtsOptions extends TtsServiceOptions {
  final String apiKey;
  final String baseUrl;
  final String model;
  final String voiceId;
  final String emotion;
  final double speed;
  MiniMaxTtsOptions({
    super.id,
    required super.enabled,
    required super.name,
    super.linkedProviderId,
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    required this.voiceId,
    required this.emotion,
    required this.speed,
  }) : super(kind: NetworkTtsKind.minimax);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'enabled': enabled,
    'name': name,
    'kind': 'minimax',
    if (linkedProviderId != null) 'linkedProviderId': linkedProviderId,
    'apiKey': apiKey,
    'baseUrl': baseUrl,
    'model': model,
    'voiceId': voiceId,
    'emotion': emotion,
    'speed': speed,
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
    super.linkedProviderId,
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
    if (linkedProviderId != null) 'linkedProviderId': linkedProviderId,
    'apiKey': apiKey,
    'baseUrl': baseUrl,
    'model': model,
    'voice': voice,
    'languageType': languageType,
  };
}

class GroqTtsOptions extends TtsServiceOptions {
  final String apiKey;
  final String baseUrl;
  final String model;
  final String voice;

  GroqTtsOptions({
    super.id,
    required super.enabled,
    required super.name,
    super.linkedProviderId,
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
    if (linkedProviderId != null) 'linkedProviderId': linkedProviderId,
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
    super.linkedProviderId,
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
    if (linkedProviderId != null) 'linkedProviderId': linkedProviderId,
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
    super.linkedProviderId,
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
    if (linkedProviderId != null) 'linkedProviderId': linkedProviderId,
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

  MimoTtsOptions({
    super.id,
    required super.enabled,
    required super.name,
    super.linkedProviderId,
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    required this.voice,
  }) : super(kind: NetworkTtsKind.mimo);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'enabled': enabled,
    'name': name,
    'kind': 'mimo',
    if (linkedProviderId != null) 'linkedProviderId': linkedProviderId,
    'apiKey': apiKey,
    'baseUrl': baseUrl,
    'model': model,
    'voice': voice,
  };
}

class NetworkTtsResult {
  final Uint8List bytes;
  final String mime; // e.g. audio/mpeg or audio/wav
  final int? sampleRate; // for PCM->WAV info
  NetworkTtsResult({required this.bytes, required this.mime, this.sampleRate});
}

class NetworkTtsService {
  static Future<NetworkTtsResult> synthesize({
    required TtsServiceOptions options,
    required String text,
    http.Client? client,
    FutureOr<bool> Function()? cancelled,
  }) async {
    final c = client ?? http.Client();
    try {
      switch (options.kind) {
        case NetworkTtsKind.openai:
          return _openAiSpeech(options as OpenAiTtsOptions, text, c, cancelled);
        case NetworkTtsKind.gemini:
          return _geminiSpeech(options as GeminiTtsOptions, text, c, cancelled);
        case NetworkTtsKind.minimax:
          return _miniMaxSpeech(
            options as MiniMaxTtsOptions,
            text,
            c,
            cancelled,
          );
        case NetworkTtsKind.qwen:
          return _qwenSpeech(options as QwenTtsOptions, text, c, cancelled);
        case NetworkTtsKind.groq:
          return _groqSpeech(options as GroqTtsOptions, text, c, cancelled);
        case NetworkTtsKind.xai:
          return _xaiSpeech(options as XaiTtsOptions, text, c, cancelled);
        case NetworkTtsKind.elevenlabs:
          return _elevenLabsSpeech(
            options as ElevenLabsTtsOptions,
            text,
            c,
            cancelled,
          );
        case NetworkTtsKind.mimo:
          return _mimoSpeech(options as MimoTtsOptions, text, c, cancelled);
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

  static Future<NetworkTtsResult> _miniMaxSpeech(
    MiniMaxTtsOptions opt,
    String text,
    http.Client c,
    FutureOr<bool> Function()? cancelled,
  ) async {
    final uri = Uri.parse(
      opt.baseUrl.endsWith('/')
          ? '${opt.baseUrl}t2a_v2'
          : '${opt.baseUrl}/t2a_v2',
    );
    final body = jsonEncode({
      'model': opt.model,
      'text': text,
      'stream': true,
      'output_format': 'hex',
      'stream_options': {'exclude_aggregated_audio': true},
      'voice_setting': {
        'voice_id': opt.voiceId,
        'emotion': opt.emotion,
        'speed': opt.speed,
      },
    });

    final req = http.Request('POST', uri)
      ..headers['Authorization'] = 'Bearer ${opt.apiKey}'
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'text/event-stream'
      ..body = body;

    final resp = await c.send(req);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final txt = await resp.stream.bytesToString();
      throw Exception(
        'MiniMax TTS failed: ${resp.statusCode} ${resp.reasonPhrase} $txt',
      );
    }

    final controller = StreamController<List<int>>();
    final buf = BytesBuilder(copy: false);
    // Parse SSE line-by-line
    final completer = Completer<void>();
    final sub = resp.stream.listen(
      (chunk) {
        controller.add(chunk);
      },
      onDone: () {
        controller.close();
      },
      onError: (e, st) {
        controller.addError(e, st);
        controller.close();
      },
    );

    final transformer = const Utf8Decoder()
        .bind(controller.stream)
        .transform(const LineSplitter());
    transformer.listen(
      (line) {
        if (cancelled != null) {
          // best-effort cancellation gate
        }
        if (!line.startsWith('data:')) return;
        final dataStr = line.substring(5).trim();
        if (dataStr == '[DONE]') return;
        try {
          final obj = jsonDecode(dataStr) as Map<String, dynamic>;
          final data = obj['data'] as Map<String, dynamic>?;
          final audioHex = (data?['audio'] ?? '').toString();
          if (audioHex.isEmpty) return;
          buf.add(_hexToBytes(audioHex));
        } catch (_) {
          // ignore malformed lines
        }
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete();
      },
      onError: (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      },
    );

    await completer.future;
    try {
      await sub.cancel();
    } catch (_) {}

    final bytes = buf.takeBytes();
    return NetworkTtsResult(
      bytes: Uint8List.fromList(bytes),
      mime: 'audio/mpeg',
      sampleRate: 32000,
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
    final pcm = buf.takeBytes();
    if (pcm.isEmpty) {
      throw Exception('Qwen TTS returned no audio data');
    }
    return NetworkTtsResult(
      bytes: _pcmToWav(Uint8List.fromList(pcm), sampleRate: 24000),
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
    // Determine mime based on output format
    final lower = outputFmt.toLowerCase();
    final mime = lower.startsWith('mp3_')
        ? 'audio/mpeg'
        : lower.startsWith('pcm_')
        ? 'audio/wav' // we don't convert PCM to WAV here; default to mp3
        : lower.startsWith('opus_')
        ? 'audio/ogg'
        : 'application/octet-stream';
    return NetworkTtsResult(bytes: Uint8List.fromList(bytes), mime: mime);
  }

  static Future<NetworkTtsResult> _mimoSpeech(
    MimoTtsOptions opt,
    String text,
    http.Client c,
    FutureOr<bool> Function()? cancelled,
  ) async {
    final uri = Uri.parse(_joinUrl(opt.baseUrl, '/chat/completions'));
    final body = jsonEncode({
      'model': opt.model,
      'messages': [
        {'role': 'assistant', 'content': text},
      ],
      'audio': {'format': 'pcm16', 'voice': opt.voice},
      'stream': true,
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
      final text = await resp.stream.bytesToString();
      throw Exception(
        'MiMo TTS failed: ${resp.statusCode} ${resp.reasonPhrase} $text',
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
      final delta = (choices.first as Map)['delta'] as Map?;
      final audio = delta?['audio'] as Map?;
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
