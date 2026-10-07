import '../../../custom_request_merger.dart';
import '../../../../models/provider_oauth.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../../models/model_spec.dart';
import '../../../../models/token_usage.dart';
import '../../../../providers/settings_provider.dart';
import '../../../../utils/multimodal_input_utils.dart';
import '../../../../../utils/sandbox_path_resolver.dart';
import '../../chat_api_helpers.dart';
import '../../native_input_attachments.dart';
import '../../tool_result_content.dart';
import '../../generation/tool_loop_runner.dart';
import '../../reasoning/reasoning_dialects.dart';
import '../../stream/sse_decode_loop.dart';
import '../../stream/sse_framing.dart';
import '../../stream/stream_chunk.dart';
import '../../stream/stream_chunk_emit.dart';
import '../../stream/stream_chunk_ids.dart';
import 'chat_completions_decoder.dart';
import 'openai_tool_transcript.dart';
import 'reasoning_details_replay.dart';
import 'openai_request_shaping.dart';

Map<String, dynamic> copyChatCompletionMessage(Map<String, dynamic> m) {
  final role = (m['role'] ?? 'user').toString();
  final out = <String, dynamic>{
    'role': role,
    'content': m.containsKey('content') ? (m['content'] ?? '') : '',
  };

  // Preserve optional name (some providers support it on non-tool roles).
  final name = m['name'];
  if (role != 'tool' && name != null && name.toString().isNotEmpty) {
    out['name'] = name;
  }

  // Preserve assistant tool_calls + vendor reasoning echoes (when present).
  if (role == 'assistant') {
    final toolCalls = m['tool_calls'];
    if (toolCalls is List && toolCalls.isNotEmpty) {
      out['tool_calls'] = [
        for (final toolCall in toolCalls.whereType<Map>())
          openaiToolCallForRequest(toolCall),
      ];
    }
    final functionCall = m['function_call'];
    if (functionCall != null) {
      out['function_call'] = functionCall;
    }
    if (m['reasoning_content'] != null) {
      out['reasoning_content'] = m['reasoning_content'];
    }
    if (m['reasoning'] != null) {
      out['reasoning'] = m['reasoning'];
    }
    if (m['reasoning_details'] != null) {
      out['reasoning_details'] = m['reasoning_details'];
    }
  }

  // Preserve tool linkage fields.
  if (role == 'tool') {
    final toolCallId = m['tool_call_id'];
    if (toolCallId != null && toolCallId.toString().isNotEmpty) {
      out['tool_call_id'] = toolCallId;
    }
    if (name != null && name.toString().isNotEmpty) {
      out['name'] = name;
    }
  }

  // Keep structured media refs across tool-followup rebuilds so later
  // Chat Completions builders can still emit image_url / multimodal parts.
  final mediaPaths = m[multimodalInternalMediaPathsKey];
  if (mediaPaths != null) {
    if (mediaPaths is List) {
      out[multimodalInternalMediaPathsKey] = [
        for (final item in mediaPaths)
          if (item is Map) Map<String, dynamic>.from(item) else item,
      ];
    } else if (mediaPaths is Map) {
      out[multimodalInternalMediaPathsKey] = Map<String, dynamic>.from(
        mediaPaths,
      );
    } else {
      out[multimodalInternalMediaPathsKey] = mediaPaths;
    }
  }
  final documents = m[multimodalInternalDocumentPathsKey];
  if (documents != null) {
    out[multimodalInternalDocumentPathsKey] = documents;
  }
  final revisionId = m[multimodalInternalRevisionIdKey];
  if (revisionId != null) {
    out[multimodalInternalRevisionIdKey] = revisionId;
  }

  return out;
}

List<Map<String, dynamic>> copyChatCompletionTools(
  List<Map<String, dynamic>> tools,
) {
  // These parameters are JSON Schema. Google's native Schema repairs can add
  // constraints (e.g. string items/required properties) that change its meaning.
  return tools.map((tool) {
    final result = Map<String, dynamic>.from(tool);
    final fn = result['function'];
    if (fn is Map) {
      result['function'] = Map<String, dynamic>.from(fn);
    }
    return result;
  }).toList();
}

bool _isRemoteImageContentPart(dynamic part) {
  if (part is! Map) return false;
  final type = (part['type'] ?? '').toString().trim().toLowerCase();
  if (type != 'image_url' && type != 'input_image') return false;

  final imageUrl = part['image_url'];
  final rawUrl = imageUrl is Map ? imageUrl['url'] : imageUrl;
  return rawUrl is String && isRemoteHttpUrl(rawUrl);
}

Map<String, dynamic> _buildAssistantToolCallMessage({
  required List<Map<String, dynamic>> calls,
  dynamic content,
  String? reasoningContent,
  String reasoningField = 'reasoning_content',
  dynamic reasoningDetails,
  bool includeEmptyReasoningContent = false,
}) {
  final normalizedContent = switch (content) {
    String value when value.isNotEmpty => value,
    List<dynamic> value when value.isNotEmpty => value,
    _ => '\n\n',
  };

  final msg = <String, dynamic>{
    'role': 'assistant',
    'content': normalizedContent,
    'tool_calls': calls,
  };
  if (reasoningContent != null &&
      (reasoningContent.isNotEmpty || includeEmptyReasoningContent)) {
    msg[reasoningField] = reasoningContent;
  }
  if (reasoningDetails is List && reasoningDetails.isNotEmpty) {
    msg['reasoning_details'] = reasoningDetails;
  }
  return msg;
}

Map<String, dynamic>? openaiFirstChoice(Map<String, dynamic> obj) {
  try {
    final choices = obj['choices'] as List?;
    if (choices != null && choices.isNotEmpty) {
      return (choices.first as Map).cast<String, dynamic>();
    }
  } catch (_) {}
  return null;
}

Map<String, dynamic>? openaiFirstChoiceMessage(Map<String, dynamic> obj) {
  return (openaiFirstChoice(obj)?['message'] as Map?)?.cast<String, dynamic>();
}

List<EmitToolCall> openaiCallsFromCompletionMessage(Map<String, dynamic>? msg) {
  final tcs = (msg?['tool_calls'] as List?) ?? const <dynamic>[];
  final calls = <EmitToolCall>[];
  for (var i = 0; i < tcs.length; i++) {
    final raw = tcs[i];
    if (raw is! Map) continue;
    final t = raw.cast<String, dynamic>();
    final id = effectiveToolCallId(t['id'], 'call', i);
    final f =
        (t['function'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final name = (f['name'] ?? '').toString();
    Map<String, dynamic> args;
    try {
      args = (jsonDecode((f['arguments'] ?? '{}').toString()) as Map)
          .cast<String, dynamic>();
    } catch (_) {
      args = <String, dynamic>{};
    }
    calls.add(
      emitToolCall(
        id: id,
        name: name,
        arguments: args,
        metadata: openaiMetadataForExtraContent(t['extra_content']),
      ),
    );
  }
  return calls;
}

String? openaiReasoningText(Map<String, dynamic>? message) {
  final raw = (message?['reasoning_content'] ?? message?['reasoning'])
      ?.toString();
  if (raw == null || raw.isEmpty) return null;
  return raw;
}

({String content, List<({String uri, String mimeType})> images})
openaiVisibleOutputFromMessage(Map<String, dynamic>? cmsg) {
  var content = '';
  final images = <({String uri, String mimeType})>[];
  if (cmsg == null) return (content: content, images: images);
  final cc = cmsg['content'];
  if (cc is String) {
    content = cc;
  } else if (cc is List) {
    final buf = StringBuffer();
    for (final it in cc) {
      if (it is Map && (it['type'] == 'text')) {
        final t = (it['text'] ?? '').toString();
        if (t.isNotEmpty) buf.write(t);
      } else if (it is Map &&
          (it['type'] == 'image_url' || it['type'] == 'image')) {
        dynamic iu = it['image_url'];
        String? url;
        if (iu is String) {
          url = iu;
        } else if (iu is Map) {
          final u2 = iu['url'];
          if (u2 is String) url = u2;
        }
        if (url != null && url.isNotEmpty) {
          final mime = mimeTypeFromImageUri(url) ?? 'image/png';
          images.add((
            uri: completeRenderableImageUri(url, mimeType: mime),
            mimeType: mime,
          ));
        }
      }
    }
    content = buf.toString();
  }
  return (content: content, images: images);
}

Future<List<Map<String, dynamic>>> buildOpenAIChatCompletionMessages(
  List<Map<String, dynamic>> messages, {
  List<String>? userMediaPaths,
  required NativeInputAttachments nativeInputs,
  required bool canImageInput,
  required bool allowRemoteImages,
  required ReasoningReplayPolicy reasoningReplay,
  ReasoningReplayField replayField = ReasoningReplayField.reasoningContent,
  // Replay preferences filter stored history; active tool continuations must
  // retain the reasoning returned by this request, including signed blocks.
  int? currentToolMessagesStart,
  bool skipImageParsing = false,
}) async {
  final out = <Map<String, dynamic>>[];
  final upstreamModelId = (nativeInputs.spec.apiModelId ?? nativeInputs.spec.id)
      .toLowerCase();
  final requiresSignedReasoning =
      upstreamModelId.contains('claude') ||
      upstreamModelId.startsWith('anthropic/');
  // Assistant turns cannot carry image_url/video_url; stash for the last user
  // message (same pattern as Responses shouldAttachAssistantImage).
  // Use last *user* index — not array-tail — so tool follow-ups that append
  // assistant tool_calls / tool results still receive stashed assistant media.
  int lastUserIndex = -1;
  for (int i = messages.length - 1; i >= 0; i--) {
    if ((messages[i]['role'] ?? '').toString() == 'user') {
      lastUserIndex = i;
      break;
    }
  }
  final pendingAssistantMediaUrls = <String>[];
  final pendingToolImageParts = <Map<String, dynamic>>[];
  void flushToolImages() {
    if (pendingToolImageParts.isEmpty) return;
    out.add({
      'role': 'user',
      'content': [...pendingToolImageParts],
    });
    pendingToolImageParts.clear();
  }

  final pendingAssistantVideoUrls = <String>{};
  final toolTurnIds = <int>{};
  final messageTurnIds = <int>[];
  var currentTurnId = -1;
  for (final message in messages) {
    final messageRole = (message['role'] ?? 'user').toString();
    if (messageRole == 'user') currentTurnId++;
    messageTurnIds.add(currentTurnId);
    final messageToolCalls = message['tool_calls'];
    if (messageRole == 'tool' ||
        (messageRole == 'assistant' &&
            messageToolCalls is List &&
            messageToolCalls.isNotEmpty)) {
      toolTurnIds.add(currentTurnId);
    }
  }
  for (int i = 0; i < messages.length; i++) {
    final m = messages[i];
    final originalContent = m['content'];
    final raw = originalContent is List
        ? textFromContentParts(originalContent)
        : (originalContent ?? '').toString();
    final role = (m['role'] ?? 'user').toString();
    // Complete the entire batch of tool replies before adding a user image.
    if (role != 'tool') flushToolImages();
    final isAssistant = role == 'assistant';
    final nativeParts = await nativeInputs.build(
      m,
      userPaths: i == lastUserIndex ? userMediaPaths : null,
    );
    void addMessage(Map<String, dynamic> message) {
      if (nativeParts.isNotEmpty) {
        final content = message['content'];
        message['content'] = [
          if (content is List)
            ...content
          else if (content is String && content.isNotEmpty)
            {'type': 'text', 'text': content},
          ...nativeParts,
        ];
      }
      out.add(message);
    }

    final internalMediaRefs = parseInternalMediaRefs(
      m[multimodalInternalMediaPathsKey],
    );
    final outMsg = Map<String, dynamic>.from(m);
    outMsg.remove(multimodalInternalMediaPathsKey);
    outMsg.remove(multimodalInternalDocumentPathsKey);
    outMsg.remove(multimodalInternalRevisionIdKey);
    outMsg.remove(multimodalInternalClaudeContainerKey);
    outMsg.remove(multimodalInternalClaudeTurnKey);
    outMsg.remove(multimodalInternalClaudeThinkingRecoveryKey);
    outMsg.remove(multimodalInternalResponsesItemKey);
    outMsg.remove(multimodalInternalGeminiThoughtSignatureKey);
    outMsg.remove('metadata');
    outMsg['role'] = role;

    if (isAssistant) {
      final toolCalls = outMsg['tool_calls'];
      if (toolCalls is List && toolCalls.isNotEmpty) {
        outMsg['tool_calls'] = [
          for (final toolCall in toolCalls.whereType<Map>())
            openaiToolCallForRequest(toolCall),
        ];
      }
      final rawDetails = outMsg['reasoning_details'];
      // The all-history policy must not turn legacy unsigned Claude text into
      // a thinking block. Only its native details can carry the signature.
      final signedDetails =
          requiresSignedReasoning ||
          reasoningDetailsNeedSignedReplay(rawDetails);
      final keepReplay =
          (currentToolMessagesStart != null && i >= currentToolMessagesStart) ||
          reasoningReplay == ReasoningReplayPolicy.all ||
          (reasoningReplay == ReasoningReplayPolicy.toolTurns &&
              toolTurnIds.contains(messageTurnIds[i]));
      if (!keepReplay) {
        outMsg.remove('reasoning_content');
        outMsg.remove('reasoning');
        outMsg.remove('reasoning_details');
      } else if (signedDetails) {
        outMsg.remove('reasoning_content');
        outMsg.remove('reasoning');
        // Signed / Anthropic-tagged fragments must be rebuilt into whole
        // blocks; other vendors replay the sequence verbatim.
        final details = normalizeReasoningDetailsForReplay(rawDetails);
        if (details == null) {
          outMsg.remove('reasoning_details');
        } else {
          outMsg['reasoning_details'] = details;
        }
      } else if (replayField != ReasoningReplayField.reasoningDetails) {
        final field = replayField.wireName;
        final value =
            outMsg[field] ?? outMsg['reasoning_content'] ?? outMsg['reasoning'];
        outMsg.remove('reasoning_content');
        outMsg.remove('reasoning');
        if (value != null) {
          outMsg[field] = value;
        }
      }
    }

    // Bare userImagePaths attach to the last *user* turn (not array-tail), so
    // tool follow-ups that append assistant/tool messages still keep them.
    final hasAttachedImages =
        canImageInput &&
        role == 'user' &&
        i == lastUserIndex &&
        (userMediaPaths?.isNotEmpty == true);
    final shouldAttachAssistantMedia =
        canImageInput &&
        role == 'user' &&
        i == lastUserIndex &&
        pendingAssistantMediaUrls.isNotEmpty;
    final hasInternalMedia = canImageInput && internalMediaRefs.isNotEmpty;

    if (originalContent is List) {
      dynamic content = canImageInput
          ? (allowRemoteImages
                ? originalContent
                : originalContent
                      .where((part) => !_isRemoteImageContentPart(part))
                      .toList(growable: false))
          : raw;
      // List-shaped content used to early-return before assistant-media /
      // userImagePaths attachment. Merge those onto the last user turn, and
      // still stash assistant media — including image_url/video_url already
      // embedded in the List with no structured sidecar refs.
      final listHasEmbeddedMedia =
          canImageInput &&
          content is List &&
          content.any((part) {
            if (part is! Map) return false;
            final type = (part['type'] ?? '').toString();
            return type == 'image_url' || type == 'video_url';
          });
      if (canImageInput &&
          (hasInternalMedia ||
              hasAttachedImages ||
              shouldAttachAssistantMedia ||
              (isAssistant && listHasEmbeddedMedia))) {
        final parts = <Map<String, dynamic>>[
          if (content is List)
            for (final part in content)
              if (part is Map)
                part.map((key, value) => MapEntry(key.toString(), value)),
        ];
        final seenSources = <String>{};
        final seenImageUrls = <String>{};
        final seenVideoUrls = <String>{};

        String normalizeSrc(String src) {
          if (src.startsWith('http') || src.startsWith('data:')) return src;
          try {
            return SandboxPathResolver.fix(src);
          } catch (_) {
            return src;
          }
        }

        void addImageUrl(String url) {
          if (url.isEmpty) return;
          if (!allowRemoteImages && isRemoteHttpUrl(url)) return;
          if (seenImageUrls.add(url)) {
            parts.add({
              'type': 'image_url',
              'image_url': {'url': url},
            });
          }
        }

        void addVideoUrl(String url) {
          if (url.isEmpty) return;
          if (seenVideoUrls.add(url)) {
            parts.add({
              'type': 'video_url',
              'video_url': {'url': url},
            });
          }
        }

        void stashOrAddImageUrl(String url) {
          if (url.isEmpty) return;
          if (!allowRemoteImages && isRemoteHttpUrl(url)) return;
          if (isAssistant) {
            if (!pendingAssistantMediaUrls.contains(url)) {
              pendingAssistantMediaUrls.add(url);
            }
            return;
          }
          addImageUrl(url);
        }

        void stashOrAddVideoUrl(String url) {
          if (url.isEmpty) return;
          if (isAssistant) {
            if (!pendingAssistantMediaUrls.contains(url)) {
              pendingAssistantMediaUrls.add(url);
            }
            pendingAssistantVideoUrls.add(url);
            return;
          }
          addVideoUrl(url);
        }

        // Index existing List media; on assistant turns also stash them so the
        // role gate moves unsupported image_url/video_url onto the last user.
        for (final part in List<Map<String, dynamic>>.from(parts)) {
          final type = (part['type'] ?? '').toString();
          if (type == 'image_url') {
            final image = part['image_url'];
            final url = image is Map
                ? (image['url'] ?? '').toString()
                : image?.toString() ?? '';
            if (url.isNotEmpty) {
              seenImageUrls.add(url);
              seenSources.add(normalizeSrc(url));
              if (isAssistant) stashOrAddImageUrl(url);
            }
          } else if (type == 'video_url') {
            final video = part['video_url'];
            final url = video is Map
                ? (video['url'] ?? '').toString()
                : video?.toString() ?? '';
            if (url.isNotEmpty) {
              seenVideoUrls.add(url);
              seenSources.add(normalizeSrc(url));
              if (isAssistant) stashOrAddVideoUrl(url);
            }
          }
        }

        final supplementalRefs = supplementalMediaRefs(
          internalRaw: m[multimodalInternalMediaPathsKey],
          userPaths: userMediaPaths,
          includeUserPaths: hasAttachedImages,
        );
        for (final mediaRef in supplementalRefs) {
          final mediaPath = mediaRef.uri;
          if (!allowRemoteImages && isRemoteHttpUrl(mediaPath)) {
            final normalized = normalizeSrc(mediaPath);
            if (!seenSources.add(normalized)) continue;
            if (!isAssistant) {
              parts.add({'type': 'text', 'text': mediaPath});
            }
            continue;
          }
          final normalized = normalizeSrc(mediaPath);
          if (!seenSources.add(normalized)) continue;
          final bool isInlineUrl =
              isRemoteHttpUrl(mediaPath) || mediaPath.startsWith('data:');
          final String mime = mimeForInternalMediaRef(mediaRef);
          if (isAudioMime(mime) ||
              (role == 'user' && (isVideoMime(mime) || isPdfMime(mime)))) {
            continue;
          }
          final bool isVideo = isVideoMime(mime);
          final String? dataUrl = isInlineUrl
              ? mediaPath
              : await tryEncodeBase64DataUrl(
                  mediaPath,
                  explicitMime: mediaRef.mime,
                );
          if (dataUrl == null) continue;
          if (isVideo) {
            stashOrAddVideoUrl(dataUrl);
          } else {
            stashOrAddImageUrl(dataUrl);
          }
        }
        if (shouldAttachAssistantMedia) {
          for (final url in pendingAssistantMediaUrls) {
            if (pendingAssistantVideoUrls.contains(url)) {
              addVideoUrl(url);
            } else {
              addImageUrl(url);
            }
          }
        }
        if (isAssistant) {
          // Keep assistant List content image-free; media is stashed above.
          content = [
            for (final part in parts)
              if (part['type'] != 'image_url' && part['type'] != 'video_url')
                part,
          ];
          if (content.isEmpty) content = raw;
        } else {
          content = parts;
        }
      }
      outMsg['content'] = content;
      addMessage(outMsg);
      continue;
    }

    if (role == 'system') {
      outMsg['content'] = raw;
      addMessage(outMsg);
      continue;
    }

    if (role == 'tool') {
      final result = await ToolResultContent.read(
        (m['name'] ?? '').toString(),
        raw,
        metadata: (m['metadata'] as Map?)?.cast<String, dynamic>(),
        canImageInput: canImageInput,
      );
      outMsg['content'] = result.text;
      addMessage(outMsg);
      if (result.imageUrls.isNotEmpty) {
        pendingToolImageParts.add({
          'type': 'text',
          'text': 'Image returned by view_image (${m['tool_call_id']}):',
        });
        pendingToolImageParts.addAll([
          for (final url in result.imageUrls)
            {
              'type': 'image_url',
              'image_url': {'url': url, 'detail': 'high'},
            },
        ]);
      }
      continue;
    }

    if ((role == 'assistant' &&
        outMsg['tool_calls'] is List &&
        (outMsg['tool_calls'] as List).isNotEmpty)) {
      outMsg['content'] = raw;
      addMessage(outMsg);
      continue;
    }

    final hasMarkdownImages = shouldParseMarkdownImages(
      raw,
      skipImageParsing: skipImageParsing,
    );
    // Semantic media detection only - custom attachment markers are not
    // recognized. Attachments arrive via structured media-path keys /
    // userMediaPaths, plus Markdown ![](...).
    // Consume injected media refs for user and assistant history turns.

    if (!hasMarkdownImages &&
        !hasAttachedImages &&
        !hasInternalMedia &&
        !shouldAttachAssistantMedia) {
      outMsg['content'] = raw;
      addMessage(outMsg);
      continue;
    }

    final parsed = await parseTextAndImages(
      raw,
      allowRemoteImages: canImageInput && allowRemoteImages,
      allowLocalImages: canImageInput,
      allowDataImages: canImageInput,
      keepRemoteMarkdownText: true,
      keepDisallowedImageText: canImageInput,
      skipImageParsing: skipImageParsing,
    );
    if (!canImageInput) {
      outMsg['content'] = parsed.text;
      addMessage(outMsg);
      continue;
    }

    final parts = <Map<String, dynamic>>[];
    final seenSources = <String>{};
    final seenImageUrls = <String>{};
    final seenVideoUrls = <String>{};

    String normalizeSrc(String src) {
      if (src.startsWith('http') || src.startsWith('data:')) return src;
      try {
        return SandboxPathResolver.fix(src);
      } catch (_) {
        return src;
      }
    }

    void addImageUrl(String url) {
      if (url.isEmpty) return;
      if (!allowRemoteImages && isRemoteHttpUrl(url)) return;
      if (seenImageUrls.add(url)) {
        parts.add({
          'type': 'image_url',
          'image_url': {'url': url},
        });
      }
    }

    void addVideoUrl(String url) {
      if (url.isEmpty) return;
      if (seenVideoUrls.add(url)) {
        parts.add({
          'type': 'video_url',
          'video_url': {'url': url},
        });
      }
    }

    void stashOrAddImageUrl(String url) {
      if (url.isEmpty) return;
      if (!allowRemoteImages && isRemoteHttpUrl(url)) return;
      if (isAssistant) {
        if (!pendingAssistantMediaUrls.contains(url)) {
          pendingAssistantMediaUrls.add(url);
        }
        return;
      }
      addImageUrl(url);
    }

    void stashOrAddVideoUrl(String url) {
      if (url.isEmpty) return;
      if (isAssistant) {
        if (!pendingAssistantMediaUrls.contains(url)) {
          pendingAssistantMediaUrls.add(url);
        }
        pendingAssistantVideoUrls.add(url);
        return;
      }
      addVideoUrl(url);
    }

    if (parsed.text.isNotEmpty) {
      parts.add({'type': 'text', 'text': parsed.text});
    }
    for (final ref in parsed.images) {
      final normalized = normalizeSrc(ref.src);
      if (!seenSources.add(normalized)) continue;
      final String? url;
      if (ref.kind == 'data') {
        url = ref.src;
      } else if (ref.kind == 'path') {
        url = await tryEncodeBase64DataUrl(ref.src);
        if (url == null) continue;
      } else {
        url = ref.src;
      }
      stashOrAddImageUrl(url);
    }
    final supplementalRefs = supplementalMediaRefs(
      internalRaw: m[multimodalInternalMediaPathsKey],
      userPaths: userMediaPaths,
      includeUserPaths: hasAttachedImages,
    );
    for (final mediaRef in supplementalRefs) {
      final p = mediaRef.uri;
      if (!allowRemoteImages && isRemoteHttpUrl(p)) {
        // Keep the remote reference visible as text when image fetch/embed
        // is disabled for this model (e.g. Kimi K3).
        final normalized = normalizeSrc(p);
        if (!seenSources.add(normalized)) continue;
        parts.add({'type': 'text', 'text': p});
        continue;
      }
      final normalized = normalizeSrc(p);
      if (!seenSources.add(normalized)) continue;
      final bool isInlineUrl = isRemoteHttpUrl(p) || p.startsWith('data:');
      final String mime = mimeForInternalMediaRef(mediaRef);
      if (isAudioMime(mime) ||
          (role == 'user' && (isVideoMime(mime) || isPdfMime(mime)))) {
        continue;
      }
      final bool isVideo = isVideoMime(mime);
      final String? dataUrl = isInlineUrl
          ? p
          : await tryEncodeBase64DataUrl(p, explicitMime: mediaRef.mime);
      if (dataUrl == null) continue;
      if (isVideo) {
        stashOrAddVideoUrl(dataUrl);
      } else {
        stashOrAddImageUrl(dataUrl);
      }
    }
    // Attach stashed assistant media to the last user message.
    if (shouldAttachAssistantMedia) {
      for (final url in pendingAssistantMediaUrls) {
        if (pendingAssistantVideoUrls.contains(url)) {
          addVideoUrl(url);
        } else {
          addImageUrl(url);
        }
      }
    }
    // Assistant content stays string or multimodal text-only parts.
    if (isAssistant) {
      if (parts.isEmpty) {
        outMsg['content'] = raw;
      } else if (parts.length == 1 && parts.first['type'] == 'text') {
        outMsg['content'] = parts.first['text'] ?? raw;
      } else {
        final textOnly = <Map<String, dynamic>>[
          for (final part in parts)
            if (part['type'] == 'text') part,
        ];
        outMsg['content'] = textOnly.isEmpty ? raw : textOnly;
      }
    } else {
      outMsg['content'] = parts.isEmpty ? raw : parts;
    }
    addMessage(outMsg);
  }
  flushToolImages();
  return out;
}

/// Follow-up tool-call responses are consumed inside the SSE parser's
/// per-event catch, which tolerates malformed JSON. Convert their transport
/// failures into [HttpException] up front so that catch cannot swallow them
/// and let the no-[DONE] fallback persist truncated output as a completion.
Stream<StreamChunk> runOpenAIChatCompletionsToolFollowUps({
  required http.Client client,
  required ProviderConfig config,
  required String modelId,
  required String upstreamModelId,
  required Uri url,
  required ModelSpec spec,
  required List<Map<String, dynamic>> messages,
  required Map<dynamic, dynamic> firstToolAcc,
  required String firstAssistantContent,
  required String firstReasoning,
  required dynamic firstReasoningDetails,
  required ToolCallHandler onToolCall,
  required List<String>? userImagePaths,
  required bool canImageInput,
  required bool allowRemoteImages,
  required bool skipImageParsing,
  required ReasoningRequest reasoning,
  required double? temperature,
  required double? topP,
  required List<Map<String, dynamic>>? tools,
  required Object? builtInSearchQuery,
  required Map<String, dynamic> extraBodyCfg,
  required String? promptCacheKey,
  required Map<String, String>? extraHeaders,
  required bool wantsImageOutput,
  required bool needsReasoningEcho,
  required bool reasoningDetailsAllowSnapshots,
  required void Function(Map<String, dynamic> body) applyMaxTokens,
  required TokenUsage? initialUsage,
  required int streamRound,
  required int approxPromptTokens,
  required int approxCompletionChars,
  required bool includeReasoningDetailsOnDone,
  StreamRoundRunner? retryRound,
}) async* {
  var usage = initialUsage;
  var chars = approxCompletionChars;
  var round = streamRound;
  ChatCompletionsStreamDecoder? lastRound;
  var currentMessages = [
    for (final message in messages) copyChatCompletionMessage(message),
  ];

  String assistantContent() =>
      lastRound?.assistantContent ?? firstAssistantContent;
  String reasoningEcho() => lastRound?.reasoningEcho ?? firstReasoning;
  dynamic reasoningDetails() =>
      lastRound == null ? firstReasoningDetails : lastRound!.reasoningDetails;

  yield* runClientToolFollowUps(
    reasoningDetailsOf: reasoningDetails,
    initialCalls: clientToolCallsFromChatAcc(firstToolAcc),
    onToolCall: onToolCall,
    append: (executed) {
      currentMessages = [
        ...currentMessages,
        _buildAssistantToolCallMessage(
          calls: openaiToolCallMaps([for (final item in executed) item.call]),
          content: assistantContent(),
          reasoningContent: needsReasoningEcho ? reasoningEcho() : null,
          reasoningField: spec.reasoning.replayField.wireName,
          includeEmptyReasoningContent: needsReasoningEcho,
          reasoningDetails: reasoningDetails(),
        ),
        ...openaiToolResultMessages(executed),
      ];
    },
    sendFollowUp: () async* {
      usage = const TokenUsage();
      final body2 = <String, dynamic>{
        'model': upstreamModelId,
        'messages': await buildOpenAIChatCompletionMessages(
          currentMessages,
          userMediaPaths: userImagePaths,
          nativeInputs: NativeInputAttachments(
            config: config,
            spec: spec,
            protocol: NativeInputProtocol.chatCompletions,
          ),
          canImageInput: canImageInput,
          allowRemoteImages: allowRemoteImages,
          reasoningReplay: spec.reasoning.replay,
          currentToolMessagesStart: messages.length,
          replayField: spec.reasoning.replayField,
          skipImageParsing: skipImageParsing,
        ),
        'stream': true,
        if (temperature != null) 'temperature': temperature,
        if (topP != null) 'top_p': topP,
        if (tools != null && tools.isNotEmpty)
          'tools': copyChatCompletionTools(tools),
        if (tools != null && tools.isNotEmpty) 'tool_choice': 'auto',
      };
      applyMaxTokens(body2);
      maybeAddStreamingUsageOptions(body2, stream: true, config: config);
      applyOpenAIResolvedRequest(
        body2,
        spec: spec,
        reasoning: reasoning,
        transport: ReasoningTransport.chatCompletions,
      );
      CustomRequestMerger.applyBody(body2, extraBodyCfg);
      if (promptCacheKey != null) {
        body2.putIfAbsent('prompt_cache_key', () => promptCacheKey);
      }
      // Built-in tools run after the custom body and merge by type.
      applyChatCompletionsBuiltInTools(
        body2,
        config: config,
        modelId: modelId,
        upstreamModelId: upstreamModelId,
        searchQuery: builtInSearchQuery,
      );
      final req2 = http.Request('POST', url);
      req2.headers.addAll(
        customHeaders(
          config,
          modelId,
          baseHeaders: <String, String>{
            'Authorization': 'Bearer ${apiKeyForRequest(config, modelId)}',
            'Content-Type': 'application/json',
            'Accept': 'text/event-stream',
          },
          assistantHeaders: extraHeaders,
        ),
      );
      req2.body = jsonEncode(body2);
      final http.StreamedResponse resp2;
      try {
        resp2 = await client.send(req2);
        if (resp2.statusCode < 200 || resp2.statusCode >= 300) {
          final errorBody = await resp2.stream.bytesToString();
          throw HttpException('HTTP ${resp2.statusCode}: $errorBody');
        }
      } on ProviderOAuthException {
        rethrow;
      } on HttpException {
        rethrow;
      } catch (e) {
        throw HttpException('Follow-up request failed: $e');
      }
      final s2 = rethrowFollowUpStreamErrors(
        resp2.stream.transform(utf8.decoder),
      );
      final roundDecoder = ChatCompletionsStreamDecoder(
        wantsImageOutput: wantsImageOutput,
        needsReasoningEcho: needsReasoningEcho,
        allowReasoningSnapshots: reasoningDetailsAllowSnapshots,
        initialUsage: usage,
        sourceId: 'round-${round++}',
      );
      yield* decodeSseEvents(
        parseSseEventStrings(s2, recoverAdjacentJsonDataRecords: true),
        roundDecoder,
      );
      usage = roundDecoder.usage ?? usage;
      // Add this round. `=` would drop earlier rounds when usage is absent.
      chars += roundDecoder.approxCompletionChars;
      lastRound = roundDecoder;
    },
    takeCallsAfterRound: () {
      final decoder = lastRound;
      if (decoder == null) return const <EmitToolCall>[];
      if (decoder.finishReason == 'tool_calls' ||
          decoder.toolCalls.isNotEmpty) {
        return clientToolCallsFromChatAcc(decoder.toolCalls);
      }
      return const <EmitToolCall>[];
    },
    finish: () {
      final approxTotal = approxPromptTokens + (chars / 4).round();
      return emitDone(
        ids: StreamChunkIds('finish'),
        reasoningDetails: includeReasoningDetailsOnDone
            ? reasoningDetails()
            : null,
        usage: usage,
        totalTokens: usage?.totalTokens ?? approxTotal,
      );
    },
    retryRound: retryRound,
    usageOf: () => usage,
  );
}

Stream<StreamChunk> runOpenAIChatCompletionsNonStreamToolFollowUps({
  required http.Client client,
  required ProviderConfig config,
  required String modelId,
  required String upstreamModelId,
  required Uri url,
  required ModelSpec spec,
  required List<Map<String, dynamic>> messages,
  required Map<String, dynamic> requestBody,
  required Map<String, dynamic> firstObj,
  required List<EmitToolCall> initialCalls,
  required ToolCallHandler onToolCall,
  required List<String>? userImagePaths,
  required bool canImageInput,
  required bool allowRemoteImages,
  required bool skipImageParsing,
  required bool needsReasoningEcho,
  required Map<String, String>? extraHeaders,
  required TokenUsage? initialUsage,
  StreamRoundRunner? retryRound,
}) async* {
  var usage = initialUsage;
  var lastObj = firstObj;
  final citationsDecoder = ChatCompletionsStreamDecoder(sourceId: 'finish');
  for (final chunk in citationsDecoder.decodeCitations(lastObj)) {
    yield chunk;
  }
  var currentMessages = [
    for (final message in messages) copyChatCompletionMessage(message),
  ];
  var round = 0;
  Stream<StreamChunk> emitToolRoundOutput() async* {
    final message = openaiFirstChoiceMessage(lastObj);
    final visible = openaiVisibleOutputFromMessage(message);
    final ids = StreamChunkIds('round-${round++}');
    yield* emitDelta(
      ids: ids,
      content: visible.content,
      reasoning: openaiReasoningText(message),
      reasoningDetails: message?['reasoning_details'],
    );
    yield* emitImages(visible.images, ids: ids);
  }

  yield* emitToolRoundOutput();

  yield* runClientToolFollowUps(
    reasoningDetailsOf: () =>
        openaiFirstChoiceMessage(lastObj)?['reasoning_details'],
    initialCalls: initialCalls,
    onToolCall: onToolCall,
    emitCalls: true,
    append: (executed) {
      final msg =
          openaiFirstChoiceMessage(lastObj) ?? const <String, dynamic>{};
      final reasoningForTools =
          (msg['reasoning_content'] ?? msg['reasoning'])?.toString() ?? '';
      currentMessages = [
        ...currentMessages,
        _buildAssistantToolCallMessage(
          calls: openaiToolCallMaps([for (final item in executed) item.call]),
          content: msg['content'],
          reasoningContent: needsReasoningEcho ? reasoningForTools : null,
          reasoningField: spec.reasoning.replayField.wireName,
          includeEmptyReasoningContent: needsReasoningEcho,
          reasoningDetails: msg['reasoning_details'],
        ),
        ...openaiToolResultMessages(executed),
      ];
    },
    sendFollowUp: () async* {
      usage = const TokenUsage();
      final req = http.Request('POST', url);
      req.headers.addAll(
        customHeaders(
          config,
          modelId,
          baseHeaders: <String, String>{
            'Authorization': 'Bearer ${apiKeyForRequest(config, modelId)}',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          assistantHeaders: extraHeaders,
        ),
      );
      final reqBody = Map<String, dynamic>.from(requestBody);
      reqBody['messages'] = await buildOpenAIChatCompletionMessages(
        currentMessages,
        userMediaPaths: userImagePaths,
        nativeInputs: NativeInputAttachments(
          config: config,
          spec: spec,
          protocol: NativeInputProtocol.chatCompletions,
        ),
        canImageInput: canImageInput,
        allowRemoteImages: allowRemoteImages,
        reasoningReplay: spec.reasoning.replay,
        currentToolMessagesStart: messages.length,
        replayField: spec.reasoning.replayField,
        skipImageParsing: skipImageParsing,
      );
      reqBody.remove('stream');
      req.body = jsonEncode(reqBody);
      final resp2 = await client.send(req);
      if (resp2.statusCode < 200 || resp2.statusCode >= 300) {
        final errorBody = await resp2.stream.bytesToString();
        throw HttpException('HTTP ${resp2.statusCode}: $errorBody');
      }
      lastObj =
          jsonDecode(await decodeUtf8Stream(resp2.stream))
              as Map<String, dynamic>;
      if (openaiCallsFromCompletionMessage(
        openaiFirstChoiceMessage(lastObj),
      ).isNotEmpty) {
        yield* emitToolRoundOutput();
      }
      final roundUsage = openaiUsageFromObj(lastObj);
      for (final chunk in citationsDecoder.decodeCitations(lastObj)) {
        yield chunk;
      }
      if (roundUsage != null) {
        usage = roundUsage;
      }
    },
    takeCallsAfterRound: () =>
        openaiCallsFromCompletionMessage(openaiFirstChoiceMessage(lastObj)),
    finish: () async* {
      final choice = openaiFirstChoice(lastObj);
      if (choice == null) {
        yield* emitDone(
          ids: StreamChunkIds('finish'),
          content: (lastObj['output_text'] ?? '').toString(),
          usage: usage,
          totalTokens: usage?.totalTokens ?? 0,
        );
        return;
      }
      final visible = openaiVisibleOutputFromMessage(
        (choice['message'] as Map?)?.cast<String, dynamic>(),
      );
      final lastMessage = openaiFirstChoiceMessage(lastObj);
      final ids = StreamChunkIds('finish');
      yield* emitImages(visible.images, ids: ids);
      yield* emitDone(
        ids: ids,
        content: visible.content,
        reasoning: openaiReasoningText(lastMessage),
        reasoningDetails: lastMessage?['reasoning_details'],
        usage: usage,
        totalTokens: usage?.totalTokens ?? 0,
        finishReason: (choice['finish_reason'] ?? '').toString().isEmpty
            ? null
            : choice['finish_reason'].toString(),
      );
    },
    retryRound: retryRound,
    usageOf: () => usage,
  );
}
