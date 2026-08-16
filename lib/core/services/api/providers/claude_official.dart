import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../models/token_usage.dart';
import '../../../providers/model_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../utils/multimodal_input_utils.dart';
import '../../../../utils/sandbox_path_resolver.dart';
import '../builtin_tools.dart';
import '../chat_api_helpers.dart';
import '../generation/tool_loop_runner.dart';
import '../stream/sse_framing.dart';
import '../stream/stream_chunk.dart';
import '../stream/stream_chunk_emit.dart';
import '../stream/stream_chunk_ids.dart';
import 'claude/claude_decoder.dart';

int _defaultClaudeMaxOutputTokens(String modelId) {
  final lower = modelId.trim().toLowerCase();
  if (RegExp(
    r'claude-(?:fable-5|mythos-5|opus-(?:5|4-8)|sonnet-5)(?:$|[._:@/-])',
    caseSensitive: false,
  ).hasMatch(lower)) {
    return 128000;
  }
  return 64000;
}

String normalizeClaudeImageMime(String mime) {
  final normalized = mime.trim().toLowerCase();
  if (normalized == 'image/jpg') return 'image/jpeg';
  return normalized;
}

bool isClaudeSupportedImageMime(String mime) {
  switch (normalizeClaudeImageMime(mime)) {
    case 'image/jpeg':
    case 'image/png':
    case 'image/gif':
    case 'image/webp':
      return true;
    default:
      return false;
  }
}

Stream<StreamChunk> sendClaudeStream(
  http.Client client,
  ProviderConfig config,
  String modelId,
  List<Map<String, dynamic>> messages, {
  List<String>? userImagePaths,
  int? thinkingBudget,
  double? temperature,
  double? topP,
  int? maxTokens,
  List<Map<String, dynamic>>? tools,
  ToolCallHandler? onToolCall,
  Map<String, String>? extraHeaders,
  Map<String, dynamic>? extraBody,
  bool stream = true,
}) async* {
  final upstreamModelId = apiModelId(config, modelId);
  // Endpoint and headers (constant across rounds)
  final base = config.baseUrl.endsWith('/')
      ? config.baseUrl.substring(0, config.baseUrl.length - 1)
      : config.baseUrl;
  final url = Uri.parse('$base/messages');

  final isReasoning = effectiveModelInfo(
    config,
    modelId,
  ).abilities.contains(ModelAbility.reasoning);
  final skipRedactedThinkingBlocks = BuiltInToolsHelper.isOpenRouterProvider(
    config,
  );

  // Extract system prompt (Anthropic uses top-level `system`)
  String systemPrompt = '';
  final nonSystemMessages = <Map<String, dynamic>>[];
  for (final m in messages) {
    final role = (m['role'] ?? '').toString();
    if (role == 'system') {
      final s = (m['content'] ?? '').toString();
      if (s.isNotEmpty) {
        systemPrompt = systemPrompt.isEmpty ? s : '$systemPrompt\n\n$s';
      }
      continue;
    }
    // Keep media-paths through transform; they are not forwarded in the
    // final Anthropic request body (we rebuild role/content below).
    nonSystemMessages.add(
      Map<String, dynamic>.from(m)
        ..remove(multimodalInternalRevisionIdKey)
        ..['role'] = role.isEmpty ? 'user' : role,
    );
  }

  // Transform last user message to include images per Anthropic schema
  final initialMessages = <Map<String, dynamic>>[];
  final pendingToolResults = <Map<String, dynamic>>[];
  void flushPendingToolResults() {
    if (pendingToolResults.isEmpty) return;
    initialMessages.add({
      'role': 'user',
      'content': List<Map<String, dynamic>>.from(pendingToolResults),
    });
    pendingToolResults.clear();
  }

  Map<String, dynamic>? toolUseBlockFromToolCall(Map tc) {
    final id = (tc['id'] ?? '').toString();
    final fn = tc['function'];
    if (id.isEmpty || fn is! Map) return null;
    Map<String, dynamic> input = const <String, dynamic>{};
    try {
      input = (jsonDecode((fn['arguments'] ?? '{}').toString()) as Map)
          .cast<String, dynamic>();
    } catch (_) {}
    return {
      'type': 'tool_use',
      'id': id,
      'name': (fn['name'] ?? '').toString(),
      'input': input,
    };
  }

  Set<String> toolUseIdsInBlocks(List<Map<String, dynamic>> blocks) {
    return blocks
        .where((block) => block['type'] == 'tool_use')
        .map((block) => (block['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Map<String, dynamic>? assistantBlockForClaudeRequest(Map block) {
    final type = (block['type'] ?? '').toString();
    if (skipRedactedThinkingBlocks && type == 'redacted_thinking') {
      return null;
    }
    return block.map((key, value) => MapEntry(key.toString(), value));
  }

  List<Map<String, dynamic>> assistantBlocksForClaudeRequest(
    Iterable<Map> blocks,
  ) {
    return [
      for (final block in blocks)
        if (assistantBlockForClaudeRequest(block) case final sanitized?)
          sanitized,
    ];
  }

  List<Map<String, dynamic>>? anthropicBlocksFromToolCallMetadata(
    List toolCalls,
  ) {
    final expectedIds = toolCalls
        .whereType<Map>()
        .map((tc) => (tc['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();
    List<Map<String, dynamic>>? bestBlocks;
    var bestMatchCount = -1;

    for (final tc in toolCalls) {
      if (tc is! Map) continue;
      final meta = tc['metadata'];
      if (meta is! Map) continue;
      final anthropic = meta['anthropic'];
      if (anthropic is! Map) continue;
      final blocks = anthropic['assistant_blocks'];
      if (blocks is! List || blocks.isEmpty) continue;
      final candidate = assistantBlocksForClaudeRequest(
        blocks.whereType<Map>(),
      );
      final matchCount = toolUseIdsInBlocks(
        candidate,
      ).where(expectedIds.contains).length;
      if (matchCount > bestMatchCount ||
          (matchCount == bestMatchCount &&
              candidate.length > (bestBlocks?.length ?? 0))) {
        bestBlocks = candidate;
        bestMatchCount = matchCount;
      }
    }
    if (bestBlocks == null) return null;
    if (expectedIds.isEmpty) return bestBlocks;

    final presentIds = toolUseIdsInBlocks(bestBlocks);
    if (presentIds.containsAll(expectedIds)) return bestBlocks;

    final completed = <Map<String, dynamic>>[
      for (final block in bestBlocks) Map<String, dynamic>.from(block),
    ];
    for (final tc in toolCalls.whereType<Map>()) {
      final block = toolUseBlockFromToolCall(tc);
      if (block == null) continue;
      final id = (block['id'] ?? '').toString();
      if (presentIds.contains(id)) continue;
      completed.add(block);
      presentIds.add(id);
    }
    return completed;
  }

  for (int i = 0; i < nonSystemMessages.length; i++) {
    final m = nonSystemMessages[i];
    final isLast = i == nonSystemMessages.length - 1;
    final role = (m['role'] ?? 'user').toString();
    if (role == 'tool') {
      final id = (m['tool_call_id'] ?? '').toString();
      if (id.isNotEmpty) {
        pendingToolResults.add({
          'type': 'tool_result',
          'tool_use_id': id,
          'content': (m['content'] ?? '').toString(),
        });
      }
      continue;
    }
    flushPendingToolResults();

    if (role == 'assistant' && m['tool_calls'] is List) {
      final toolCalls = m['tool_calls'] as List;
      final blocks =
          anthropicBlocksFromToolCallMetadata(toolCalls) ??
          <Map<String, dynamic>>[];
      if (blocks.isEmpty) {
        final text = (m['content'] ?? '').toString();
        if (text.trim().isNotEmpty && text.trim() != '\n\n') {
          blocks.add({'type': 'text', 'text': text});
        }
        for (final tc in toolCalls) {
          if (tc is! Map) continue;
          final block = toolUseBlockFromToolCall(tc);
          if (block != null) blocks.add(block);
        }
      }
      if (blocks.isNotEmpty) {
        initialMessages.add({'role': 'assistant', 'content': blocks});
      }
      continue;
    }
    final raw = (m['content'] ?? '').toString();
    // Semantic media detection only - custom attachment markers are not
    // recognized. Attachments arrive via structured media-path keys /
    // userImagePaths, plus Markdown ![](...).
    final hasMarkdownImages = raw.contains('![') && raw.contains('](');
    final internalMediaRefs = parseInternalMediaRefs(
      m[multimodalInternalMediaPathsKey],
    );
    // Consume injected media refs for user and assistant history turns.
    final hasInternalMedia = internalMediaRefs.isNotEmpty;
    final hasAttachedImages =
        isLast && role == 'user' && (userImagePaths?.isNotEmpty == true);

    if ((role == 'user' || role == 'assistant') &&
        (hasMarkdownImages || hasInternalMedia || hasAttachedImages)) {
      final parts = <Map<String, dynamic>>[];
      final seenSources = <String>{};
      String normalizeSrc(String src) {
        if (src.startsWith('http') || src.startsWith('data:')) return src;
        try {
          return SandboxPathResolver.fix(src);
        } catch (_) {
          return src;
        }
      }

      Future<void> addClaudeImage(String source, {String? explicitMime}) async {
        final normalized = normalizeSrc(source);
        if (!seenSources.add(normalized)) return;
        if (source.startsWith('http://') || source.startsWith('https://')) {
          // Preserve prior official-Claude behavior for remote URLs.
          parts.add({'type': 'text', 'text': source});
          return;
        }
        if (source.startsWith('data:')) {
          final mime = normalizeClaudeImageMime(
            (explicitMime != null && explicitMime.trim().isNotEmpty)
                ? explicitMime.trim()
                : mimeFromDataUrl(source),
          );
          final idx = source.indexOf('base64,');
          if (idx > 0) {
            parts.add({
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': mime,
                'data': source.substring(idx + 7),
              },
            });
          }
          return;
        }
        final mime = normalizeClaudeImageMime(
          (explicitMime != null && explicitMime.trim().isNotEmpty)
              ? explicitMime.trim()
              : mimeFromPath(source),
        );
        final b64 = await tryEncodeBase64File(source, withPrefix: false);
        if (b64 == null) return;
        parts.add({
          'type': 'image',
          'source': {'type': 'base64', 'media_type': mime, 'data': b64},
        });
      }

      final parsed = await parseTextAndImages(
        raw,
        allowRemoteImages: true,
        allowLocalImages: true,
        keepRemoteMarkdownText: true,
      );
      if (parsed.text.isNotEmpty) {
        parts.add({'type': 'text', 'text': parsed.text});
      }
      for (final ref in parsed.images) {
        if (ref.kind == 'data' || ref.kind == 'path' || ref.kind == 'url') {
          await addClaudeImage(ref.src);
        }
      }
      final supplementalRefs = supplementalMediaRefs(
        internalRaw: m[multimodalInternalMediaPathsKey],
        userPaths: userImagePaths,
        includeUserPaths: hasAttachedImages,
      );
      for (final mediaRef in supplementalRefs) {
        final mime = mimeForInternalMediaRef(mediaRef);
        // Never emit Anthropic image blocks for video/audio or other
        // non-Claude image MIME types (e.g. video/mp4).
        if (isVideoMime(mime) ||
            isAudioMime(mime) ||
            !isClaudeSupportedImageMime(mime)) {
          final uri = mediaRef.uri;
          final isRemote =
              uri.startsWith('http://') || uri.startsWith('https://');
          if (isRemote) {
            final normalized = normalizeSrc(uri);
            if (seenSources.add(normalized)) {
              parts.add({'type': 'text', 'text': uri});
            }
          }
          continue;
        }
        await addClaudeImage(mediaRef.uri, explicitMime: mediaRef.mime);
      }
      initialMessages.add({
        'role': role,
        'content': parts.isEmpty ? raw : parts,
      });
    } else {
      initialMessages.add({'role': role, 'content': raw});
    }
  }
  flushPendingToolResults();

  // Map OpenAI-style tools to Anthropic custom tools (client tools)
  List<Map<String, dynamic>>? anthropicTools;
  if (tools != null && tools.isNotEmpty) {
    anthropicTools = [];
    for (final t in tools) {
      final fn = (t['function'] as Map<String, dynamic>?);
      if (fn == null) continue;
      final name = (fn['name'] ?? '').toString();
      if (name.isEmpty) continue;
      final desc = (fn['description'] ?? '').toString();
      final params =
          (fn['parameters'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{'type': 'object'};
      anthropicTools.add({
        'name': name,
        if (desc.isNotEmpty) 'description': desc,
        'input_schema': params,
      });
    }
  }

  // Collect final tools list: client + server + built-in web_search
  final List<Map<String, dynamic>> allTools = [];
  if (anthropicTools != null && anthropicTools.isNotEmpty) {
    allTools.addAll(anthropicTools);
  }
  if (tools != null && tools.isNotEmpty) {
    for (final t in tools) {
      final type = (t['type'] ?? '').toString();
      if (type.startsWith('web_search_')) {
        allTools.add(t);
      }
    }
  }
  final builtIns = builtInTools(config, modelId);
  if (builtIns.contains(BuiltInToolNames.search)) {
    Map<String, dynamic> ws = const <String, dynamic>{};
    try {
      final ov = config.modelOverrides[modelId];
      if (ov is Map && ov['webSearch'] is Map) {
        ws = (ov['webSearch'] as Map).cast<String, dynamic>();
      }
    } catch (_) {}
    final searchToolType = BuiltInToolsHelper.claudeBuiltInSearchToolType(
      cfg: config,
      modelId: modelId,
    );
    final entry = <String, dynamic>{
      'type': searchToolType,
      'name': 'web_search',
    };
    if (searchToolType == 'web_search_20260209') {
      allTools.add(<String, dynamic>{
        'type': 'code_execution_20250825',
        'name': 'code_execution',
      });
    }
    if (ws['max_uses'] is int && (ws['max_uses'] as int) > 0) {
      entry['max_uses'] = ws['max_uses'];
    }
    if (ws['allowed_domains'] is List) {
      entry['allowed_domains'] = List<String>.from(
        (ws['allowed_domains'] as List).map((e) => e.toString()),
      );
    }
    if (ws['blocked_domains'] is List) {
      entry['blocked_domains'] = List<String>.from(
        (ws['blocked_domains'] as List).map((e) => e.toString()),
      );
    }
    if (ws['user_location'] is Map) {
      entry['user_location'] = (ws['user_location'] as Map)
          .cast<String, dynamic>();
    }
    allTools.add(entry);
  }

  // Headers (constant across rounds)
  final baseHeaders = customHeaders(
    config,
    modelId,
    baseHeaders: <String, String>{
      'x-api-key': effectiveApiKey(config),
      'anthropic-version': '2023-06-01',
      'Content-Type': 'application/json',
      'Accept': stream ? 'text/event-stream' : 'application/json',
    },
    assistantHeaders: extraHeaders,
  );

  // Running conversation across rounds
  List<Map<String, dynamic>> convo = List<Map<String, dynamic>>.from(
    initialMessages,
  );
  TokenUsage? totalUsage;
  var streamRound = 0;
  var pendingCalls = <EmitToolCall>[];
  var lastAssistantBlocks = <Map<String, dynamic>>[];
  var lastStreamResults = <Map<String, dynamic>>[];
  var lastText = '';
  var pauseTurn = false;

  yield* runProviderToolRounds(
    sendRound: () async* {
      final omitSamplingParams = claudeShouldOmitSamplingParams(
        upstreamModelId,
        thinkingBudget,
      );
      final compatibleTopP = claudeCompatibleTopP(
        upstreamModelId,
        thinkingBudget,
        topP,
      );
      final thinking = isReasoning
          ? claudeThinkingConfig(
              upstreamModelId,
              thinkingBudget,
              config: config,
            )
          : null;
      final outputConfig = isReasoning
          ? claudeOutputConfig(upstreamModelId, thinkingBudget, config: config)
          : null;

      // Prepare request body per round
      final body = <String, dynamic>{
        'model': upstreamModelId,
        'max_tokens':
            maxTokens ?? _defaultClaudeMaxOutputTokens(upstreamModelId),
        'messages': convo,
        'stream': stream,
        if (systemPrompt.isNotEmpty) 'system': systemPrompt,
        if (config.claudePromptCachingEnabled == true)
          'cache_control': ProviderConfig.claudePromptCacheControl(
            config.claudePromptCachingTtl,
          ),
        if (!omitSamplingParams &&
            !isClaudeReasoningEnabled(thinkingBudget) &&
            temperature != null)
          'temperature': temperature,
        if (compatibleTopP != null) 'top_p': compatibleTopP,
        if (allTools.isNotEmpty) 'tools': allTools,
        if (allTools.isNotEmpty) 'tool_choice': {'type': 'auto'},
        if (thinking != null) 'thinking': thinking,
        if (outputConfig != null) 'output_config': outputConfig,
      };
      final extraClaude = customBody(config, modelId, assistantBody: extraBody);
      if (extraClaude.isNotEmpty) {
        body.addAll(extraClaude);
      }

      final request = http.Request('POST', url);
      request.headers.addAll(baseHeaders);
      request.body = jsonEncode(body);

      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errorBody = await response.stream.bytesToString();
        throw HttpException('HTTP ${response.statusCode}: $errorBody');
      }

      pendingCalls = [];
      lastStreamResults = [];
      lastText = '';
      lastAssistantBlocks = [];
      pauseTurn = false;

      // Non-streaming path: parse full JSON, handle tool_use, then continue loop if needed.
      if (!stream) {
        final txt = await decodeUtf8Stream(response.stream);
        final obj = jsonDecode(txt) as Map;
        // Usage
        try {
          final u = (obj['usage'] as Map?)?.cast<String, dynamic>();
          if (u != null) {
            totalUsage = (totalUsage ?? const TokenUsage()).merge(
              claudeUsageFromMap(u),
            );
          }
        } catch (_) {}
        final content = (obj['content'] as List?) ?? const <dynamic>[];
        final List<Map<String, dynamic>> assistantBlocks =
            <Map<String, dynamic>>[];
        final Map<String, Map<String, dynamic>> toolUses =
            <String, Map<String, dynamic>>{}; // id -> {name,args}
        final buf = StringBuffer();
        for (final it in content) {
          if (it is! Map) continue;
          final type = (it['type'] ?? '').toString();
          if (type == 'text') {
            final t = (it['text'] ?? '').toString();
            if (t.isNotEmpty) {
              assistantBlocks.add({'type': 'text', 'text': t});
              buf.write(t);
            }
          } else if (type == 'thinking' ||
              (type == 'redacted_thinking' && !skipRedactedThinkingBlocks)) {
            // Preserve thinking blocks unmodified for tool-use continuation.
            // When thinking is enabled, the next request must include the last assistant
            // message starting with a thinking/redacted_thinking block.
            try {
              assistantBlocks.add(
                Map<String, dynamic>.from(it.cast<String, dynamic>()),
              );
            } catch (_) {}
          } else if (type == 'tool_use') {
            final id = (it['id'] ?? '').toString();
            final name = (it['name'] ?? '').toString();
            final args =
                (it['input'] as Map?)?.cast<String, dynamic>() ??
                const <String, dynamic>{};
            if (id.isNotEmpty) {
              toolUses[id] = {'name': name, 'args': args};
              assistantBlocks.add({
                'type': 'tool_use',
                'id': id,
                'name': name,
                'input': args,
              });
            }
          }
        }
        lastAssistantBlocks = assistantBlocks;
        lastText = buf.toString();
        if (toolUses.isNotEmpty && onToolCall != null) {
          pendingCalls = [
            for (final e in toolUses.entries)
              emitToolCall(
                id: e.key,
                name: (e.value['name'] ?? '').toString(),
                arguments: (e.value['args'] as Map<String, dynamic>),
                metadata: {
                  'anthropic': {'assistant_blocks': assistantBlocks},
                },
              ),
          ];
        }
        return;
      }

      final sse = response.stream.transform(utf8.decoder);
      final decoder = ClaudeStreamDecoder(
        skipRedactedThinkingBlocks: skipRedactedThinkingBlocks,
        sourceId: 'round-${streamRound++}',
      );
      final executedToolIds = <String>{};

      await for (final event in parseSseEventStrings(sse)) {
        throwIfInBandStreamError(event.data);
        final decoded = decoder.accept(event);
        for (final chunk in decoded.chunks) {
          yield chunk;
          if (chunk is ToolCallEnd &&
              decoder.isClientTool(chunk.id) &&
              onToolCall != null &&
              executedToolIds.add(chunk.id)) {
            final tool = decoder.clientTools[chunk.id]!;
            final args = tool.decodedArguments;
            final call = emitToolCall(
              id: tool.id,
              name: tool.name,
              arguments: args,
              metadata: {
                'anthropic': {'assistant_blocks': decoder.assistantBlocks},
              },
            );
            await for (final resultChunk in executeClientTools(
              calls: [call],
              onToolCall: onToolCall,
              usage: decoder.usage,
              totalTokens: decoder.usage?.totalTokens ?? 0,
            )) {
              if (resultChunk is ToolCallResult) {
                decoder.recordToolResult(
                  tool.id,
                  (resultChunk.output ?? '').toString(),
                );
              }
              yield resultChunk;
            }
          }
        }
        if (decoded.completed) break;
      }
      for (final chunk in decoder.onClosed()) {
        yield chunk;
      }

      final usage = decoder.usage;
      final assistantBlocks = decoder.assistantBlocks;
      final lastStopReason = decoder.lastStopReason;
      final toolResultsContent = decoder.toolResults;

      if (usage != null) {
        totalUsage = (totalUsage ?? const TokenUsage()).merge(usage);
      }

      lastAssistantBlocks = assistantBlocks;
      if (decoder.clientTools.isEmpty) {
        pauseTurn = (lastStopReason ?? '') == 'pause_turn';
        return;
      }

      pendingCalls = [
        for (final tool in decoder.clientTools.values)
          emitToolCall(
            id: tool.id,
            name: tool.name,
            arguments: tool.decodedArguments,
            metadata: {
              'anthropic': {'assistant_blocks': assistantBlocks},
            },
          ),
      ];
      for (final tool in decoder.clientTools.values) {
        var res = toolResultsContent[tool.id] ?? '';
        if (res.isEmpty && onToolCall != null) {
          res = await onToolCall(
            tool.name,
            tool.decodedArguments,
            toolCallId: tool.id,
          );
        }
        lastStreamResults.add({
          'type': 'tool_result',
          'tool_use_id': tool.id,
          if (res.isNotEmpty) 'content': res,
        });
      }
    },
    takeCalls: () => pendingCalls,
    continueWithoutCalls: () => pauseTurn,
    executeAfterRound: !stream,
    emitCalls: !stream,
    onToolCall: onToolCall,
    append: (executed) {
      if (pauseTurn) {
        convo = [
          ...convo,
          {'role': 'assistant', 'content': lastAssistantBlocks},
        ];
        return;
      }
      final results = stream
          ? lastStreamResults
          : [
              for (final item in executed)
                <String, dynamic>{
                  'type': 'tool_result',
                  'tool_use_id': item.call.id,
                  'content': item.content,
                },
            ];
      convo = [
        ...convo,
        {'role': 'assistant', 'content': lastAssistantBlocks},
        {'role': 'user', 'content': results},
      ];
    },
    finish: () => emitDone(
      ids: StreamChunkIds('finish'),
      content: lastText,
      usage: totalUsage,
      totalTokens: totalUsage?.totalTokens ?? 0,
    ),
    usageOf: () => totalUsage,
  );
}
