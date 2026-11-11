import '../../../../models/native_compaction.dart';
import '../../native_compaction_context.dart';
import '../../request_history_context.dart';
import '../../request_image_context.dart';
import 'dart:async';
import 'dart:convert';

import '../../../../models/model_spec.dart';
import '../../../../providers/model_provider.dart';
import '../../../../providers/settings_provider.dart';
import '../../../../utils/multimodal_input_utils.dart';
import '../../../../../utils/sandbox_path_resolver.dart';
import '../../../model_spec/model_spec_resolver.dart';
import '../../builtin_tools.dart';
import '../../chat_api_helpers.dart';
import '../../native_input_attachments.dart';
import '../../tool_result_content.dart';
import 'openai_request_shaping.dart';
import 'responses_api.dart';
import 'responses_history.dart';

Future<Map<String, dynamic>> buildOpenAIResponsesBody(
  ProviderConfig config,
  String modelId,
  List<Map<String, dynamic>> messages, {
  List<Map<String, dynamic>>? tools,
  List<String>? userImagePaths,
  Iterable<String>? configuredBuiltInTools,
  bool stream = true,
  bool skipImageParsing = false,
  double? temperature,
  double? topP,
  int? maxTokens,
}) async {
  final upstreamModelId = apiModelId(config, modelId);
  final spec = ModelSpecResolver.instance.spec(config, modelId);
  final canImageInput = spec.input.contains(Modality.image);
  final allowRemoteImages = canImageInput && spec.remoteImageUrls;
  late Map<String, dynamic> body;
  messages = filterResponsesReasoningHistory(messages, spec.reasoning.replay);
  final input = <Map<String, dynamic>>[];
  // Extract system messages into `instructions` (Responses API best practice)
  String instructions = '';
  // Prepare tools list for Responses path (may be augmented with built-in web search)
  final List<Map<String, dynamic>> toolList = [];
  if (tools != null && tools.isNotEmpty) {
    for (final t in tools) {
      toolList.add(Map<String, dynamic>.from(t));
    }
  }

  void addResponsesBuiltInTool(Map<String, dynamic> entry) {
    final type = (entry['type'] ?? '').toString();
    if (type.isEmpty) return;
    final exists = toolList.any((e) => (e['type'] ?? '').toString() == type);
    if (!exists) toolList.add(entry);
  }

  final builtInPayload = BuiltInToolsHelper.buildResponsesTools(
    cfg: config,
    modelId: modelId,
    upstreamModelId: upstreamModelId,
    configuredTools: configuredBuiltInTools,
  );
  for (final tool in builtInPayload.tools) {
    addResponsesBuiltInTool(tool);
  }
  // Collect assistant images to attach to the last user message.
  // Use last *user* index so tool follow-ups still receive stashed media.
  final List<String> lastAssistantImageUrls = <String>[];
  final lastResponsesUserIndex = lastUserInputIndex(messages);
  for (int i = 0; i < messages.length; i++) {
    final m = messages[i];
    final sourceStart = input.length;
    try {
      if (m[nativeCompactionMessageKey] case final Map payload) {
        validateNativeCompactionScope([m], config);
        final native = NativeCompactionPayload.fromJson(
          Map<String, dynamic>.from(payload),
        );
        input.addAll(
          (jsonDecode(jsonEncode(native.output)) as List).map(
            (item) => {
              ...Map<String, dynamic>.from(item as Map),
              nativeCompactionWireKey: true,
            },
          ),
        );
        continue;
      }
      final originalContent = m['content'];
      final raw = originalContent is List
          ? textFromContentParts(originalContent)
          : (originalContent ?? '').toString();
      final roleRaw = (m['role'] ?? 'user').toString();

      if (roleRaw == 'assistant' &&
          m[multimodalInternalResponsesItemKey] is Map) {
        input.add(responsesInputItem(m));
        continue;
      }

      // Responses API supports a top-level `instructions` field that has higher priority
      if (roleRaw == 'system') {
        if (raw.isNotEmpty) {
          instructions = instructions.isEmpty ? raw : ('$instructions\n\n$raw');
        }
        continue;
      }

      // Handle tool result messages (role: 'tool') - convert to function_call_output format
      if (roleRaw == 'tool') {
        final toolCallId = (m['tool_call_id'] ?? '').toString();
        final content = (m['content'] ?? '').toString();
        if (toolCallId.isNotEmpty) {
          input.add({
            'type': 'function_call_output',
            'call_id': toolCallId,
            'output': (await ToolResultContent.read(
              (m['name'] ?? '').toString(),
              content,
              metadata: (m['metadata'] as Map?)?.cast<String, dynamic>(),
              toolCallId: m['tool_call_id']?.toString(),
              canImageInput: canImageInput,
            )).responsesOutput,
          });
        }
        continue;
      }

      final nativeParts =
          await NativeInputAttachments(
            config: config,
            spec: spec,
            protocol: NativeInputProtocol.responses,
          ).build(
            m,
            userPaths: i == lastResponsesUserIndex ? userImagePaths : null,
          );
      void addMessage(Map<String, dynamic> message) {
        if (nativeParts.isNotEmpty) {
          final content = message['content'];
          message['content'] = [
            if (content is List)
              ...content
            else if (content is String && content.isNotEmpty)
              {'type': 'input_text', 'text': content},
            ...nativeParts,
          ];
        }
        input.add(message);
      }

      final isAssistant = roleRaw == 'assistant';
      // Reconstructed assistant text precedes its calls. Insert it here so
      // no message separates a tool-call batch from its matching results.
      final assistantMessageIndex = input.length;

      // Handle assistant messages with tool_calls - convert to function_call format
      if (isAssistant && m['tool_calls'] is List) {
        final toolCalls = m['tool_calls'] as List;
        for (final tc in toolCalls) {
          if (tc is! Map) continue;
          final callId = (tc['id'] ?? '').toString();
          final fn = tc['function'];
          if (fn is! Map) continue;
          final name = (fn['name'] ?? '').toString();
          final arguments = (fn['arguments'] ?? '{}').toString();
          if (callId.isNotEmpty && name.isNotEmpty) {
            input.add({
              'type': 'function_call',
              'call_id': callId,
              'name': name,
              'arguments': arguments,
            });
          }
        }
        // Skip adding the assistant message content if it only contains tool calls
        if (raw.trim().isEmpty || raw.trim() == '\n\n') continue;
      }

      // Only parse images if there are images to process.
      // Semantic media detection only - custom attachment markers are not
      // recognized. Attachments arrive via structured media-path keys /
      // userImagePaths, plus Markdown ![](...).
      final hasMarkdownImages = shouldParseMarkdownImages(
        raw,
        skipImageParsing: skipImageParsing,
      );
      final internalMediaRefs = parseInternalMediaRefs(
        m[multimodalInternalMediaPathsKey],
      );
      // Consume injected media refs for user and assistant history turns.
      final hasInternalMedia = canImageInput && internalMediaRefs.isNotEmpty;
      final hasAttachedImages =
          canImageInput &&
          (m['role'] == 'user') &&
          i == lastResponsesUserIndex &&
          (userImagePaths?.isNotEmpty == true);
      // For the last user message, also attach the last assistant image if available
      final shouldAttachAssistantImage =
          canImageInput &&
          (m['role'] == 'user') &&
          i == lastResponsesUserIndex &&
          lastAssistantImageUrls.isNotEmpty;

      if (hasMarkdownImages ||
          hasAttachedImages ||
          hasInternalMedia ||
          shouldAttachAssistantImage) {
        final parsed = await parseTextAndImages(
          raw,
          literalText: internalLiteralText(m),
          imageReferences: internalImageReferences(m),
          allowRemoteImages: allowRemoteImages,
          allowLocalImages: canImageInput,
          allowDataImages: canImageInput,
          keepRemoteMarkdownText: true,
          keepDisallowedImageText: canImageInput,
          skipImageParsing: skipImageParsing,
        );
        if (!canImageInput) {
          if (isAssistant) {
            input.insert(assistantMessageIndex, {
              'type': 'message',
              'role': 'assistant',
              'status': 'completed',
              'content': [
                {'type': 'output_text', 'text': parsed.text},
              ],
            });
          } else {
            addMessage({'role': roleRaw, 'content': parsed.text});
          }
          continue;
        }

        final parts = <Map<String, dynamic>>[];
        final seenImageSources = <String>{};
        final seenImageUrls = <String>{};
        String normalizeSrc(String src) => SandboxPathResolver.dedupeKey(src);

        void addImage(String url) {
          if (url.isEmpty) return;
          if (!allowRemoteImages && isRemoteHttpUrl(url)) return;
          if (seenImageUrls.add(url)) {
            parts.add({'type': 'input_image', 'image_url': url});
          }
        }

        if (parsed.text.isNotEmpty) {
          // Use output_text for assistant, input_text for user
          parts.add({
            'type': isAssistant ? 'output_text' : 'input_text',
            'text': parsed.text,
          });
        }
        // Images extracted from this message's text
        for (final ref in parsed.images) {
          final normalized = normalizeSrc(ref.src);
          if (!seenImageSources.add(normalized)) continue;
          final String? url;
          if (ref.kind == 'data') {
            url = ref.src;
          } else if (ref.kind == 'path') {
            url = await tryEncodeBase64DataUrl(ref.src);
            if (url == null) continue;
          } else {
            url = ref.src; // http(s)
          }
          // For assistant messages, collect images; for user messages, add directly
          if (isAssistant) {
            if (!lastAssistantImageUrls.contains(url)) {
              lastAssistantImageUrls.add(url);
            }
          } else {
            addImage(url);
          }
        }
        // Structured / attached media refs (user + assistant history turns)
        final supplementalRefs = supplementalMediaRefs(
          internalRaw: m[multimodalInternalMediaPathsKey],
          userPaths: userImagePaths,
          includeUserPaths: hasAttachedImages,
        );
        for (final mediaRef in supplementalRefs) {
          final p = mediaRef.uri;
          final String mime = mimeForInternalMediaRef(mediaRef);
          final bool isAv = isAudioMime(mime) || isVideoMime(mime);
          if ((isAv || isPdfMime(mime)) && !isAssistant) continue;
          if (isAv) {
            // Responses path has no first-class A/V input parts here; never
            // encode video/audio as input_image. Keep a text reference for both
            // remote and local paths so pure A/V attachments do not become
            // content: [] (API reject / silent drop).
            final normalized = normalizeSrc(p);
            if (seenImageSources.add(normalized)) {
              parts.add({
                'type': isAssistant ? 'output_text' : 'input_text',
                'text': p,
              });
            }
            continue;
          }
          if (!allowRemoteImages && isRemoteHttpUrl(p)) {
            // Keep the remote reference visible as text when image embed is off.
            final normalized = normalizeSrc(p);
            if (!seenImageSources.add(normalized)) continue;
            parts.add({
              'type': isAssistant ? 'output_text' : 'input_text',
              'text': p,
            });
            continue;
          }
          final normalized = normalizeSrc(p);
          if (!seenImageSources.add(normalized)) continue;
          final dataUrl = (isRemoteHttpUrl(p) || p.startsWith('data:'))
              ? p
              : await tryEncodeBase64DataUrl(p, explicitMime: mediaRef.mime);
          if (dataUrl == null) continue;
          // Assistant Responses messages may only contain output_text/refusal.
          // Mirror the markdown path: stash for the following user turn.
          if (isAssistant) {
            if (!lastAssistantImageUrls.contains(dataUrl)) {
              lastAssistantImageUrls.add(dataUrl);
            }
          } else {
            addImage(dataUrl);
          }
        }
        // Attach all stashed assistant images to the last user message
        if (shouldAttachAssistantImage) {
          for (final url in lastAssistantImageUrls) {
            addImage(url);
          }
        }
        // Use proper message object format for assistant messages
        if (isAssistant) {
          // Never emit input_image inside assistant completed output.
          final assistantContent = <Map<String, dynamic>>[
            for (final part in parts)
              if (part['type'] == 'output_text' || part['type'] == 'refusal')
                part,
          ];
          if (assistantContent.isEmpty) {
            assistantContent.add({'type': 'output_text', 'text': parsed.text});
          }
          input.insert(assistantMessageIndex, {
            'type': 'message',
            'role': 'assistant',
            'status': 'completed',
            'content': assistantContent,
          });
        } else {
          addMessage({'role': roleRaw, 'content': parts});
        }
      } else {
        // No images
        if (isAssistant) {
          // Use proper message object format for assistant messages
          input.insert(assistantMessageIndex, {
            'type': 'message',
            'role': 'assistant',
            'status': 'completed',
            'content': [
              {'type': 'output_text', 'text': raw},
            ],
          });
        } else {
          addMessage({'role': roleRaw, 'content': raw});
        }
      }
    } finally {
      RequestHistoryContext.mark(m, input.skip(sourceStart));
    }
  }
  body = {
    'model': upstreamModelId,
    'input': input,
    'stream': stream,
    if (instructions.isNotEmpty) 'instructions': instructions,
    if (temperature != null) 'temperature': temperature,
    if (topP != null) 'top_p': topP,
    if (maxTokens != null) 'max_output_tokens': maxTokens,
    if (toolList.isNotEmpty) 'tools': toResponsesToolsFormat(toolList),
    if (toolList.isNotEmpty) 'tool_choice': 'auto',
  };
  // OpenAI-compatible native search can optionally expose source details.
  // OpenRouter rejects the `include` parameter, so skip it there.
  if (!BuiltInToolsHelper.isDashScopeProvider(config) &&
      !BuiltInToolsHelper.isOpenRouterProvider(config)) {
    try {
      final ov = config.modelOverrides[modelId];
      final ws = (ov is Map ? ov['webSearch'] : null);
      if (ws is Map && ws['include_sources'] == true) {
        body['include'] = ['web_search_call.action.sources'];
      }
    } catch (_) {}
  }
  if (Uri.tryParse(config.baseUrl)?.host == 'api.openai.com') {
    body['include'] = [
      ...?body['include'] as List?,
      'reasoning.encrypted_content',
    ];
  }
  return body;
}
