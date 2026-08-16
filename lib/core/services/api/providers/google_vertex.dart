part of '../chat_api_service.dart';

Stream<ChatStreamChunk> _sendGoogleVertexStream(
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
}) {
  final cfg = config.copyWith(vertexAI: true);
  return _sendGoogleStream(
    client,
    cfg,
    modelId,
    messages,
    userImagePaths: userImagePaths,
    thinkingBudget: thinkingBudget,
    temperature: temperature,
    topP: topP,
    maxTokens: maxTokens,
    tools: tools,
    onToolCall: onToolCall,
    extraHeaders: extraHeaders,
    extraBody: extraBody,
    stream: stream,
  );
}

/// Whether Vertex media downloads may attach Bearer / X-Goog-User-Project.
///
/// Strict Google host allowlist only — never broad *.google.com.
/// Auth headers are HTTPS-only so tokens are never sent in cleartext on
/// `http://storage.googleapis.com/...` (or any other allowlisted HTTP URL).
bool _shouldAttachVertexMediaAuth(Uri uri) {
  if (uri.scheme.toLowerCase() != 'https') return false;
  final host = uri.host.trim().toLowerCase();
  if (host.isEmpty) return false;
  if (host == 'googleapis.com' || host.endsWith('.googleapis.com')) {
    return true;
  }
  if (host == 'googleusercontent.com' ||
      host.endsWith('.googleusercontent.com')) {
    return true;
  }
  if (host == 'storage.cloud.google.com') return true;
  return false;
}

Future<String> _downloadRemoteAsBase64(
  http.Client client,
  ProviderConfig config,
  String url,
) async {
  final uri = Uri.parse(url);
  final req = http.Request('GET', uri);
  // Attach Vertex auth only for allowlisted Google media hosts.
  if (config.vertexAI == true && _shouldAttachVertexMediaAuth(uri)) {
    try {
      final token = await _maybeVertexAccessToken(config);
      if (token != null && token.isNotEmpty) {
        req.headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {}
    final proj = (config.projectId ?? '').trim();
    if (proj.isNotEmpty) {
      req.headers['X-Goog-User-Project'] = proj;
    }
  }
  final resp = await client.send(req);
  if (resp.statusCode < 200 || resp.statusCode >= 300) {
    final err = await resp.stream.bytesToString();
    throw HttpException('HTTP ${resp.statusCode}: $err');
  }
  final bytes = await resp.stream.fold<List<int>>(<int>[], (acc, b) {
    acc.addAll(b);
    return acc;
  });
  return base64Encode(bytes);
}

// Returns OAuth token for Vertex AI when serviceAccountJson is configured; otherwise null.
Future<String?> _maybeVertexAccessToken(ProviderConfig cfg) async {
  if (cfg.vertexAI == true) {
    final jsonStr = (cfg.serviceAccountJson ?? '').trim();
    if (jsonStr.isEmpty) {
      // Fallback: some users may paste a temporary OAuth token into apiKey
      if (cfg.apiKey.isNotEmpty) return cfg.apiKey;
      return null;
    }
    try {
      return await GoogleServiceAccountAuth.getAccessTokenFromJson(jsonStr);
    } catch (_) {
      // On failure, do not crash streaming; let server return 401 and surface error upstream
      return null;
    }
  }
  return null;
}

int _getMaxOutputTokensForClaudeModel(String modelId) {
  // Limits based on Google Vertex AI documentation
  switch (modelId) {
    case 'claude-fable-5':
    case 'claude-opus-5':
    case 'claude-opus-4-8':
    case 'claude-opus-4-7':
    case 'claude-opus-4-6':
    case 'claude-sonnet-5':
    case 'claude-sonnet-4-6':
      return 128000;
    case 'claude-opus-4-5@20251101':
    case 'claude-sonnet-4-5@20250929':
    case 'claude-haiku-4-5@20251001':
    case 'claude-sonnet-4@20250514':
      return 64000;
    case 'claude-opus-4-1@20250805':
    case 'claude-opus-4@20250514':
      return 32000;
    case 'claude-3-haiku@20240307':
      return 8000;
    case 'claude-3-5-sonnet@20240620':
    case 'claude-3-5-sonnet-v2@20241022':
      return 8192;
    default:
      // Fallback for older models
      return 4096;
  }
}

Stream<ChatStreamChunk> _sendGoogleVertexClaudeStream({
  required http.Client client,
  required ProviderConfig config,
  required String modelId,
  required List<Map<String, dynamic>> messages,
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
  final upstreamId = _apiModelId(config, modelId);
  final loc = (config.location ?? 'us-central1').trim();
  final proj = (config.projectId ?? '').trim();
  final endpoint = stream ? 'streamRawPredict' : 'rawPredict';
  // Vertex AI Anthropic URL
  final host = (loc.toLowerCase() == 'global')
      ? 'aiplatform.googleapis.com'
      : '$loc-aiplatform.googleapis.com';
  final url = Uri.parse(
    'https://$host/v1/projects/$proj/locations/$loc/publishers/anthropic/models/$upstreamId:$endpoint',
  );

  final isReasoning = _effectiveModelInfo(
    config,
    modelId,
  ).abilities.contains(ModelAbility.reasoning);

  // Determine effective max_tokens based on model capabilities
  int effectiveMaxTokens =
      maxTokens ?? _getMaxOutputTokensForClaudeModel(upstreamId);

  // Ensure thinking_budget < max_tokens (API requirement)
  int? effectiveThinkingBudget = thinkingBudget;
  if (isReasoning &&
      effectiveThinkingBudget != null &&
      effectiveThinkingBudget > 0) {
    if (effectiveThinkingBudget >= effectiveMaxTokens) {
      // Reserve at least 1k tokens for response content
      effectiveThinkingBudget = effectiveMaxTokens - 1024;
      if (effectiveThinkingBudget < 1024) {
        effectiveThinkingBudget = 1024; // floor
      }
    }
  }

  final requestHeaders = <String, String>{'Content-Type': 'application/json'};
  final token = await _maybeVertexAccessToken(config);
  if (token != null && token.isNotEmpty) {
    requestHeaders['Authorization'] = 'Bearer $token';
  }
  final headers = _customHeaders(
    config,
    modelId,
    baseHeaders: requestHeaders,
    assistantHeaders: extraHeaders,
  );

  // Extract system prompt
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
    // Keep media-paths through transform; final request only emits role/content.
    nonSystemMessages.add(
      Map<String, dynamic>.from(m)
        ..remove(multimodalInternalRevisionIdKey)
        ..['role'] = role.isEmpty ? 'user' : role,
    );
  }

  // Transform messages + images (Force Base64 for Vertex)
  final initialMessages = <Map<String, dynamic>>[];
  for (int i = 0; i < nonSystemMessages.length; i++) {
    final m = nonSystemMessages[i];
    final isLast = i == nonSystemMessages.length - 1;
    final roleName = (m['role'] ?? 'user').toString();
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
        isLast && roleName == 'user' && (userImagePaths?.isNotEmpty == true);

    if ((roleName == 'user' || roleName == 'assistant') &&
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

      Future<void> addVertexClaudeImage(
        String source, {
        String? explicitMime,
      }) async {
        final normalized = normalizeSrc(source);
        if (!seenSources.add(normalized)) return;
        // Vertex AI Claude does not support remote URLs in 'image' blocks generally.
        // We must download and encode.
        String mime;
        String b64;
        if (source.startsWith('http://') || source.startsWith('https://')) {
          try {
            b64 = await _downloadRemoteAsBase64(client, config, source);
            mime = (explicitMime != null && explicitMime.trim().isNotEmpty)
                ? explicitMime.trim()
                : 'image/png'; // TODO: detect mime from response or url
            if (explicitMime == null || explicitMime.trim().isEmpty) {
              final lower = source.toLowerCase();
              if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
                mime = 'image/jpeg';
              }
              if (lower.endsWith('.webp')) mime = 'image/webp';
              if (lower.endsWith('.gif')) mime = 'image/gif';
            }
          } catch (_) {
            parts.add({
              'type': 'text',
              'text': '(image failed to download) $source',
            });
            return;
          }
        } else if (source.startsWith('data:')) {
          mime = (explicitMime != null && explicitMime.trim().isNotEmpty)
              ? explicitMime.trim()
              : _mimeFromDataUrl(source);
          final idx = source.indexOf('base64,');
          if (idx > 0) {
            b64 = source.substring(idx + 7);
          } else {
            return;
          }
        } else {
          mime = (explicitMime != null && explicitMime.trim().isNotEmpty)
              ? explicitMime.trim()
              : _mimeFromPath(source);
          final encoded = await _tryEncodeBase64File(source, withPrefix: false);
          if (encoded == null) return;
          b64 = encoded;
        }
        if (b64.isNotEmpty) {
          parts.add({
            'type': 'image',
            'source': {
              'type': 'base64',
              'media_type': _normalizeClaudeImageMime(mime),
              'data': b64,
            },
          });
        }
      }

      final parsed = await _parseTextAndImages(
        raw,
        allowRemoteImages: true,
        allowLocalImages: true,
        keepRemoteMarkdownText: true,
      );
      if (parsed.text.isNotEmpty) {
        parts.add({'type': 'text', 'text': parsed.text});
      }
      for (final ref in parsed.images) {
        await addVertexClaudeImage(ref.src);
      }
      final supplementalRefs = _supplementalMediaRefs(
        internalRaw: m[multimodalInternalMediaPathsKey],
        userPaths: userImagePaths,
        includeUserPaths: hasAttachedImages,
      );
      for (final mediaRef in supplementalRefs) {
        final mime = _mimeForInternalMediaRef(mediaRef);
        // Never emit Anthropic image blocks for video/audio or other
        // non-Claude image MIME types (e.g. video/mp4).
        if (isVideoMime(mime) ||
            isAudioMime(mime) ||
            !_isClaudeSupportedImageMime(mime)) {
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
        await addVertexClaudeImage(mediaRef.uri, explicitMime: mediaRef.mime);
      }
      initialMessages.add({
        'role': roleName,
        'content': parts.isEmpty ? raw : parts,
      });
    } else {
      initialMessages.add({'role': roleName, 'content': raw});
    }
  }

  // Tools setup (copy logic from Claude)
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
  final List<Map<String, dynamic>> allTools = [];
  if (anthropicTools != null && anthropicTools.isNotEmpty) {
    allTools.addAll(anthropicTools);
  }
  if (tools != null && tools.isNotEmpty) {
    for (final t in tools) {
      if (t['type'] is String &&
          (t['type'] as String).startsWith('web_search_')) {
        allTools.add(t);
      }
    }
  }

  final builtIns = _builtInTools(config, modelId);
  if (builtIns.contains(BuiltInToolNames.search)) {
    Map<String, dynamic> ws = const <String, dynamic>{};
    try {
      final ov = config.modelOverrides[modelId];
      if (ov is Map && ov['webSearch'] is Map) {
        ws = (ov['webSearch'] as Map).cast<String, dynamic>();
      }
    } catch (_) {}
    final entry = <String, dynamic>{
      'type': 'web_search_20250305',
      'name': 'web_search',
    };
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

  List<Map<String, dynamic>> convo = List<Map<String, dynamic>>.from(
    initialMessages,
  );
  TokenUsage? totalUsage;

  while (true) {
    final omitSamplingParams = _claudeShouldOmitSamplingParams(
      upstreamId,
      effectiveThinkingBudget,
    );
    final compatibleTopP = _claudeCompatibleTopP(
      upstreamId,
      effectiveThinkingBudget,
      topP,
    );
    final thinking = isReasoning
        ? _claudeThinkingConfig(upstreamId, effectiveThinkingBudget)
        : null;
    final outputConfig = isReasoning
        ? _claudeOutputConfig(upstreamId, effectiveThinkingBudget)
        : null;
    final body = <String, dynamic>{
      'anthropic_version': 'vertex-2023-10-16',
      'messages': convo,
      'stream': stream,
      'max_tokens': effectiveMaxTokens,
      if (systemPrompt.isNotEmpty) 'system': systemPrompt,
      if (!omitSamplingParams &&
          !_isClaudeReasoningEnabled(effectiveThinkingBudget) &&
          temperature != null)
        'temperature': temperature,
      if (compatibleTopP != null) 'top_p': compatibleTopP,
      if (allTools.isNotEmpty) 'tools': allTools,
      if (allTools.isNotEmpty) 'tool_choice': {'type': 'auto'},
      if (thinking != null) 'thinking': thinking,
      if (outputConfig != null) 'output_config': outputConfig,
    };
    body.addAll(_customBody(config, modelId, assistantBody: extraBody));

    final request = http.Request('POST', url);
    request.headers.addAll(headers);
    request.body = jsonEncode(body);

    final response = await client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorBody = await response.stream.bytesToString();
      throw HttpException('HTTP ${response.statusCode}: $errorBody');
    }

    if (!stream) {
      // Vertex rawPredict response is same as Anthropic non-stream response
      final txt = await response.stream.bytesToString();
      final obj = jsonDecode(txt) as Map;
      // Usage
      try {
        final u = (obj['usage'] as Map?)?.cast<String, dynamic>();
        if (u != null) {
          totalUsage = (totalUsage ?? const TokenUsage()).merge(
            _claudeUsageFromMap(u),
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
        } else if (type == 'thinking' || type == 'redacted_thinking') {
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
      if (toolUses.isNotEmpty && onToolCall != null) {
        final callInfos = <ToolCallInfo>[];
        for (final e in toolUses.entries) {
          callInfos.add(
            ToolCallInfo(
              id: e.key,
              name: (e.value['name'] ?? '').toString(),
              arguments: (e.value['args'] as Map<String, dynamic>),
            ),
          );
        }
        yield ChatStreamChunk(
          content: '',
          isDone: false,
          totalTokens: (totalUsage?.totalTokens ?? 0),
          usage: totalUsage,
          toolCalls: callInfos,
        );
        final results = <Map<String, dynamic>>[];
        final resultsInfo = <ToolResultInfo>[];
        for (final e in toolUses.entries) {
          final name = (e.value['name'] ?? '').toString();
          final args = (e.value['args'] as Map<String, dynamic>);
          final res = await onToolCall(name, args, toolCallId: e.key);
          results.add({
            'type': 'tool_result',
            'tool_use_id': e.key,
            'content': res,
          });
          resultsInfo.add(
            ToolResultInfo(
              id: e.key,
              name: name,
              arguments: args,
              content: res,
            ),
          );
        }
        if (resultsInfo.isNotEmpty) {
          yield ChatStreamChunk(
            content: '',
            isDone: false,
            totalTokens: (totalUsage?.totalTokens ?? 0),
            usage: totalUsage,
            toolResults: resultsInfo,
          );
        }
        // Extend convo: assistant + user tool_result, loop
        final assistantMsg = {'role': 'assistant', 'content': assistantBlocks};
        final userToolMsg = {'role': 'user', 'content': results};
        convo = [...convo, assistantMsg, userToolMsg];
        continue; // next round
      }
      // No tool use -> return final text
      yield ChatStreamChunk(
        content: buf.toString(),
        isDone: true,
        totalTokens: (totalUsage?.totalTokens ?? 0),
        usage: totalUsage,
      );
      return;
    }

    final sse = response.stream.transform(utf8.decoder);
    final decoder = ClaudeStreamDecoder();
    final adapter = LegacyChunkAdapter();
    final executedToolIds = <String>{};

    await for (final event in parseSseEventStrings(sse)) {
      // Anthropic-on-Vertex reports failures in-band as `event: error` with
      // {type:"error", error:{type,message}}; raise before the
      // malformed-chunk guard below can swallow it.
      _throwIfInBandStreamError(event.data);
      final decoded = decoder.accept(event);
      for (final chunk in decoded.chunks) {
        for (final mapped in adapter.handle(chunk)) {
          yield mapped;
        }
        if (chunk is ToolCallEnd &&
            decoder.isClientTool(chunk.id) &&
            onToolCall != null &&
            executedToolIds.add(chunk.id)) {
          final tool = decoder.clientTools[chunk.id]!;
          final args = tool.decodedArguments;
          final res = await onToolCall(tool.name, args, toolCallId: tool.id);
          decoder.recordToolResult(tool.id, res);
          yield ChatStreamChunk(
            content: '',
            isDone: false,
            totalTokens: decoder.usage?.totalTokens ?? 0,
            usage: decoder.usage,
            toolResults: [
              ToolResultInfo(
                id: tool.id,
                name: tool.name,
                arguments: args,
                content: res,
              ),
            ],
          );
        }
      }
      if (decoded.completed) break;
    }
    for (final chunk in decoder.onClosed()) {
      for (final mapped in adapter.handle(chunk)) {
        yield mapped;
      }
    }

    final usage = decoder.usage;
    final roundTokens = usage?.totalTokens ?? 0;
    final assistantBlocks = decoder.assistantBlocks;
    final lastStopReason = decoder.lastStopReason;
    final toolResultsContent = decoder.toolResults;

    if (usage != null) {
      totalUsage = (totalUsage ?? const TokenUsage()).merge(usage);
    }

    if (decoder.clientTools.isEmpty) {
      final sr = lastStopReason ?? '';
      if (sr == 'pause_turn') {
        convo = [
          ...convo,
          {'role': 'assistant', 'content': assistantBlocks},
        ];
        continue;
      }
      yield ChatStreamChunk(
        content: '',
        isDone: true,
        totalTokens: (totalUsage?.totalTokens ?? roundTokens),
        usage: totalUsage ?? usage,
      );
      return;
    }

    final toolResultsBlocks = <Map<String, dynamic>>[];
    for (final tool in decoder.clientTools.values) {
      final args = tool.decodedArguments;
      var res = toolResultsContent[tool.id] ?? '';
      if (res.isEmpty && onToolCall != null) {
        res = await onToolCall(tool.name, args, toolCallId: tool.id);
      }
      toolResultsBlocks.add({
        'type': 'tool_result',
        'tool_use_id': tool.id,
        if (res.isNotEmpty) 'content': res,
      });
    }

    convo = [
      ...convo,
      {'role': 'assistant', 'content': assistantBlocks},
      {'role': 'user', 'content': toolResultsBlocks},
    ];
  }
}
