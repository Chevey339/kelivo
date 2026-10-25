import 'dart:io';

import '../../models/model_spec.dart';
import '../../providers/settings_provider.dart';
import '../../utils/multimodal_input_utils.dart';
import '../model_spec/model_spec_resolver.dart';
import '../../../utils/sandbox_path_resolver.dart';
import 'builtin_tools.dart';
import 'chat_api_helpers.dart';

enum NativeInputProtocol { chatCompletions, responses, claude, gemini }

/// Whether a user audio attachment reaches [modelId] as audio. Mirrors the
/// request routing in ChatApiService: only Chat Completions and Gemini carry
/// audio parts.
bool acceptsNativeAudioInput(ProviderConfig config, String modelId) {
  if (!ModelSpecResolver.instance.spec(config, modelId).supportsAudioInput) {
    return false;
  }
  return switch (ProviderConfig.classify(
    config.id,
    explicitType: config.providerType,
  )) {
    ProviderKind.openai => config.useResponseApi != true,
    ProviderKind.google =>
      !(config.vertexAI == true && modelId.toLowerCase().startsWith('claude-')),
    ProviderKind.claude => false,
  };
}

/// Serializes user attachments independently of image input. In particular,
/// enabling audio or PDF must work even when image input is disabled.
class NativeInputAttachments {
  const NativeInputAttachments({
    required this.config,
    required this.spec,
    required this.protocol,
  });

  final ProviderConfig config;
  final ModelSpec spec;
  final NativeInputProtocol protocol;

  Future<List<Map<String, dynamic>>> build(
    Map<String, dynamic> message, {
    List<String>? userPaths,
  }) async {
    if (message['role'] != 'user') return const [];
    final refs = <InternalDocumentRef>[
      ...parseInternalDocumentRefs(message[multimodalInternalDocumentPathsKey]),
      for (final ref in supplementalMediaRefs(
        internalRaw: message[multimodalInternalMediaPathsKey],
        userPaths: userPaths,
        includeUserPaths: true,
      ))
        (
          uri: ref.uri,
          name: _fileName(ref.uri),
          mime: mimeForInternalMediaRef(ref),
        ),
    ];
    final parts = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final ref in refs) {
      final mime = resolveMediaAttachmentMime(
        explicitMime: ref.mime,
        fileName: ref.name,
        path: ref.uri,
      );
      final pdf = isPdfMime(mime);
      final audio = isAudioMime(mime);
      final video = isVideoMime(mime);
      if (!(pdf && spec.supportsPdfInput ||
          audio && spec.supportsAudioInput ||
          video && spec.supportsVideoInput)) {
        continue;
      }
      final remote = _isRemote(ref.uri);
      final source = remote || ref.uri.startsWith('data:')
          ? ref.uri
          : SandboxPathResolver.resolveForIo(ref.uri) ?? ref.uri;
      if (!seen.add(source)) continue;
      if (!pdf &&
          (protocol == NativeInputProtocol.responses ||
              protocol == NativeInputProtocol.claude)) {
        throw UnsupportedError(
          '${protocol == NativeInputProtocol.responses ? 'Responses API' : 'Claude API'} '
          'does not support ${audio ? 'audio' : 'video'} input. '
          'Select a provider and API that support this input mode.',
        );
      }
      if (protocol == NativeInputProtocol.gemini) {
        if (remote &&
            config.vertexAI != true &&
            !(Uri.tryParse(ref.uri)?.host ==
                    'generativelanguage.googleapis.com' &&
                Uri.parse(ref.uri).path.contains('/files/'))) {
          throw UnsupportedError(
            'Gemini input requires a local file or a Gemini Files API URI.',
          );
        }
        final wireMime = _geminiMime(mime);
        parts.add(
          remote
              ? {
                  'file_data': {'file_uri': ref.uri, 'mime_type': wireMime},
                }
              : {
                  'inline_data': {
                    'mime_type': wireMime,
                    'data': await _base64(ref.uri),
                  },
                },
        );
      } else if (protocol == NativeInputProtocol.claude) {
        if (remote && config.vertexAI == true) {
          throw UnsupportedError('Claude on Vertex requires a local PDF file.');
        }
        parts.add({
          'type': 'document',
          if (ref.name.isNotEmpty) 'title': ref.name,
          'source': remote
              ? {'type': 'url', 'url': ref.uri}
              : {
                  'type': 'base64',
                  'media_type': 'application/pdf',
                  'data': await _base64(ref.uri),
                },
        });
      } else if (pdf) {
        final responses = protocol == NativeInputProtocol.responses;
        if (remote &&
            !responses &&
            !BuiltInToolsHelper.isOpenRouterProvider(config)) {
          throw UnsupportedError(
            'Chat Completions requires a local PDF file, not a file URL.',
          );
        }
        final file = <String, dynamic>{
          if (!remote || !responses) 'filename': ref.name,
          if (remote && responses)
            'file_url': ref.uri
          else
            'file_data': remote
                ? ref.uri
                : 'data:application/pdf;base64,${await _base64(ref.uri)}',
        };
        parts.add(
          responses
              ? {'type': 'input_file', ...file}
              : {'type': 'file', 'file': file},
        );
      } else if (audio) {
        final format = _audioFormat(mime);
        final host = Uri.tryParse(config.baseUrl)?.host.toLowerCase() ?? '';
        final dashScope =
            host == 'dashscope.aliyuncs.com' ||
            host == 'dashscope-intl.aliyuncs.com' ||
            host.endsWith('.dashscope.aliyuncs.com') ||
            host.endsWith('.maas.aliyuncs.com');
        final extended = host != 'api.openai.com';
        if (format == null ||
            (!extended && format != 'wav' && format != 'mp3')) {
          throw UnsupportedError(
            'This Chat Completions provider does not support $mime input. '
            'Use WAV/MP3 or select a provider that accepts this format.',
          );
        }
        if (remote && !dashScope) {
          throw UnsupportedError('Audio input requires a local audio file.');
        }
        final data = remote ? ref.uri : await _base64(ref.uri);
        parts.add({
          'type': 'input_audio',
          'input_audio': {
            'data': dashScope && !remote ? 'data:$mime;base64,$data' : data,
            'format': format,
          },
        });
      } else if (video) {
        final host = Uri.tryParse(config.baseUrl)?.host.toLowerCase() ?? '';
        if (host == 'api.openai.com') {
          throw UnsupportedError(
            'OpenAI Chat Completions does not support video input.',
          );
        }
        parts.add({
          'type': 'video_url',
          'video_url': {
            'url': remote
                ? ref.uri
                : 'data:$mime;base64,${await _base64(ref.uri)}',
          },
        });
      }
    }
    return parts;
  }

  static String _fileName(String uri) {
    if (uri.startsWith('data:')) return 'attachment';
    final path = _isRemote(uri) ? Uri.parse(uri).path : uri;
    return path.split(RegExp(r'[\\/]')).last;
  }

  static bool _isRemote(String uri) =>
      uri.startsWith('https://') || uri.startsWith('http://');

  static Future<String> _base64(String uri) async {
    if (uri.startsWith('data:')) {
      final marker = uri.indexOf(';base64,');
      if (marker < 0 || marker + 8 == uri.length) {
        throw const FormatException(
          'Attachment must contain base64 file data.',
        );
      }
      return uri.substring(marker + 8);
    }
    final data = await tryEncodeBase64File(uri, withPrefix: false);
    if (data == null || data.isEmpty) {
      throw FileSystemException('Cannot read attachment', uri);
    }
    return data;
  }

  static String? _audioFormat(String mime) => switch (mime.toLowerCase()) {
    'audio/wav' || 'audio/x-wav' || 'audio/wave' => 'wav',
    'audio/mpeg' || 'audio/mp3' => 'mp3',
    'audio/mp4' || 'audio/m4a' || 'audio/x-m4a' => 'm4a',
    'audio/aac' => 'aac',
    'audio/flac' || 'audio/x-flac' => 'flac',
    'audio/ogg' => 'ogg',
    'audio/opus' => 'opus',
    'audio/aiff' || 'audio/x-aiff' => 'aiff',
    'audio/pcm' || 'audio/pcm16' => 'pcm16',
    _ => null,
  };

  static String _geminiMime(String mime) => switch (mime.toLowerCase()) {
    'audio/mp4' || 'audio/x-m4a' => 'audio/m4a',
    'audio/x-wav' || 'audio/wave' => 'audio/wav',
    'audio/x-flac' => 'audio/flac',
    'audio/x-aiff' => 'audio/aiff',
    'video/quicktime' => 'video/mov',
    'video/x-msvideo' => 'video/avi',
    'video/x-ms-wmv' => 'video/wmv',
    _ => mime,
  };
}
