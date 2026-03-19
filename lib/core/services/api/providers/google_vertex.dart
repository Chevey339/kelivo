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
  Future<String> Function(String, Map<String, dynamic>)? onToolCall,
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

Future<String> _downloadRemoteAsBase64(
  http.Client client,
  ProviderConfig config,
  String url,
) async {
  final req = http.Request('GET', Uri.parse(url));
  // Add Vertex auth if enabled
  if (config.vertexAI == true) {
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
    case 'claude-opus-4-6':
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
  Future<String> Function(String, Map<String, dynamic>)? onToolCall,
  Map<String, String>? extraHeaders,
  Map<String, dynamic>? extraBody,
  bool stream = true,
}) async* {
  final upstreamId = _apiModelId(config, modelId);
  bool supportsAdaptiveThinking(String id) {
    final lower = id.toLowerCase();
    if (!lower.contains('claude-')) return false;
    final m = RegExp(
      r'claude-(opus|sonnet)-(\d+)-(\d+)',
      caseSensitive: false,
    ).firstMatch(lower);
    if (m != null) {
      final major = int.tryParse(m.group(2) ?? '');
      final minor = int.tryParse(m.group(3) ?? '');
      if (major != null && minor != null) {
        return major > 4 || (major == 4 && minor >= 6);
      }
    }
    return lower.contains('4-6') || lower.contains('4.6');
  }

  String adaptiveEffort(int? budget) {
    final effort = _effortForBudget(budget);
    if (effort == 'auto') return 'medium';
    return effort;
  }

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

  final headers = <String, String>{'Content-Type': 'application/json'};
  final token = await _maybeVertexAccessToken(config);
  if (token != null && token.isNotEmpty) {
    headers['Authorization'] = 'Bearer $token';
  }
  if (extraHeaders != null) {
    headers.addAll(extraHeaders);
  }

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
    nonSystemMessages.add({
      'role': role.isEmpty ? 'user' : role,
      'content': m['content'] ?? '',
    });
  }

  // Transform messages + images (Force Base64 for Vertex)
  final initialMessages = <Map<String, dynamic>>[];
  for (int i = 0; i < nonSystemMessages.length; i++) {
    final m = nonSystemMessages[i];
    final isLast = i == nonSystemMessages.length - 1;
    if (isLast &&
        (userImagePaths?.isNotEmpty == true) &&
        (m['role'] == 'user')) {
      final parts = <Map<String, dynamic>>[];
      final text = (m['content'] ?? '').toString();
      if (text.isNotEmpty) parts.add({'type': 'text', 'text': text});
      for (final p in userImagePaths!) {
        // Vertex AI Claude does not support remote URLs in 'image' blocks generally.
        // We must download and encode.
        String mime;
        String b64;
        if (p.startsWith('http')) {
          try {
            b64 = await _downloadRemoteAsBase64(client, config, p);
            mime = 'image/png'; // TODO: detect mime from response or url
            if (p.toLowerCase().endsWith('.jpg') ||
                p.toLowerCase().endsWith('.jpeg')) {
              mime = 'image/jpeg';
            }
            if (p.toLowerCase().endsWith('.webp')) {
              mime = 'image/webp';
            }
            if (p.toLowerCase().endsWith('.gif')) {
              mime = 'image/gif';
            }
          } catch (_) {
            parts.add({
              'type': 'text',
              'text': '(image failed to download) $p',
            });
            continue;
          }
        } else if (p.startsWith('data:')) {
          mime = _mimeFromDataUrl(p);
          final idx = p.indexOf('base64,');
          if (idx > 0) {
            b64 = p.substring(idx + 7);
          } else {
            b64 = ''; // Should not happen for valid data uri
          }
        } else {
          mime = _mimeFromPath(p);
          b64 = await _encodeBase64File(p, withPrefix: false);
        }
        if (b64.isNotEmpty) {
          parts.add({
            'type': 'image',
            'source': {'type': 'base64', 'media_type': mime, 'data': b64},
          });
        }
      }
      initialMessages.add({'role': 'user', 'content': parts});
    } else {
      initialMessages.add({
        'role': m['role'] ?? 'user',
        'content': m['content'] ?? '',
      });
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
    final body = <String, dynamic>{
      'anthropic_version': 'vertex-2023-10-16',
      'messages': convo,
      'stream': stream,
      'max_tokens': effectiveMaxTokens,
      if (systemPrompt.isNotEmpty) 'system': systemPrompt,
      if (temperature != null) 'temperature': temperature,
      if (topP != null) 'top_p': topP,
      if (allTools.isNotEmpty) 'tools': allTools,
      if (allTools.isNotEmpty) 'tool_choice': {'type': 'auto'},
      if (isReasoning)
        if (supportsAdaptiveThinking(upstreamId))
          'thinking': {
            'type': (effectiveThinkingBudget == 0) ? 'disabled' : 'adaptive',
          }
        else
          'thinking': {
            'type': (effectiveThinkingBudget == 0) ? 'disabled' : 'enabled',
            if (effectiveThinkingBudget != null && effectiveThinkingBudget > 0)
              'budget_tokens': effectiveThinkingBudget,
          },
      if (isReasoning &&
          supportsAdaptiveThinking(upstreamId) &&
          effectiveThinkingBudget != 0)
        'output_config': {'effort': adaptiveEffort(effectiveThinkingBudget)},
    };
    if (extraBody != null) {
      extraBody.forEach((k, v) {
        body[k] = (v is String) ? _parseOverrideValue(v) : v;
      });
    }

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
          final inTok = (u['input_tokens'] ?? 0) as int? ?? 0;
          final outTok = (u['output_tokens'] ?? 0) as int? ?? 0;
          final round = TokenUsage(
            promptTokens: inTok,
            completionTokens: outTok,
            cachedTokens: 0,
            totalTokens: inTok + outTok,
          );
          totalUsage = (totalUsage ?? const TokenUsage()).merge(round);
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
          final res = await onToolCall(name, args);
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

    // Streaming path
    final sse = response.stream.transform(utf8.decoder);
    String buffer = '';
    int roundTokens = 0;
    TokenUsage? usage;
    String? lastStopReason;

    final Map<String, Map<String, dynamic>> anthToolUse =
        <String, Map<String, dynamic>>{};
    final Map<int, String> cliIndexToId = <int, String>{};
    final Map<String, String> toolResultsContent = <String, String>{};
    final List<Map<String, dynamic>> assistantBlocks = <Map<String, dynamic>>[];
    final StringBuffer textBuf = StringBuffer();

    // Server tool helpers (web_search)
    final Map<int, String> srvIndexToId = <int, String>{};
    final Map<String, String> srvArgsStr = <String, String>{};
    final Map<String, Map<String, dynamic>> srvArgs =
        <String, Map<String, dynamic>>{};

    final Map<int, int> thinkingIndexToAssistantBlock = <int, int>{};
    final Map<int, StringBuffer> thinkingText = <int, StringBuffer>{};
    final Map<int, StringBuffer> thinkingSig = <int, StringBuffer>{};
    final Map<int, int> redactedThinkingIndexToAssistantBlock = <int, int>{};
    final Map<int, StringBuffer> redactedThinkingData = <int, StringBuffer>{};

    int? parseIndex(dynamic raw) {
      if (raw == null) return null;
      if (raw is int) return raw;
      return int.tryParse(raw.toString());
    }

    void flushTextBlock() {
      final t = textBuf.toString();
      if (t.isNotEmpty) {
        assistantBlocks.add({'type': 'text', 'text': t});
        textBuf.clear();
      }
    }

    bool messageStopped = false;

    await for (final chunk in sse) {
      buffer += chunk;
      final lines = buffer.split('\n');
      buffer = lines.last;

      for (int i = 0; i < lines.length - 1; i++) {
        final line = lines[i].trim();
        if (line.isEmpty || !line.startsWith('data:')) continue;

        final data = line.substring(5).trimLeft();
        try {
          final obj = jsonDecode(data);
          final type = obj['type'];

          if (type == 'content_block_start') {
            final cb = obj['content_block'];
            final idx = parseIndex(obj['index']);
            if (cb is Map && (cb['type'] == 'thinking')) {
              flushTextBlock();
              if (idx != null) {
                assistantBlocks.add({
                  'type': 'thinking',
                  'thinking': '',
                  'signature': '',
                });
                thinkingIndexToAssistantBlock[idx] = assistantBlocks.length - 1;
                thinkingText[idx] = StringBuffer();
                thinkingSig[idx] = StringBuffer();
              }
            } else if (cb is Map && (cb['type'] == 'redacted_thinking')) {
              flushTextBlock();
              if (idx != null) {
                assistantBlocks.add({'type': 'redacted_thinking', 'data': ''});
                redactedThinkingIndexToAssistantBlock[idx] =
                    assistantBlocks.length - 1;
                redactedThinkingData[idx] = StringBuffer();
              }
            } else if (cb is Map && (cb['type'] == 'tool_use')) {
              flushTextBlock();
              final id = (cb['id'] ?? '').toString();
              final name = (cb['name'] ?? '').toString();
              final idx2 = idx ?? -1;
              if (id.isNotEmpty) {
                anthToolUse.putIfAbsent(id, () => {'name': name, 'args': ''});
                assistantBlocks.add({
                  'type': 'tool_use',
                  'id': id,
                  'name': name,
                  'input': {},
                });
                if (idx2 >= 0) {
                  cliIndexToId[idx2] = id;
                }
                yield ChatStreamChunk(
                  content: '',
                  isDone: false,
                  totalTokens: roundTokens,
                  usage: usage,
                  toolCalls: [
                    ToolCallInfo(
                      id: id,
                      name: name,
                      arguments: const <String, dynamic>{},
                    ),
                  ],
                );
              }
            } else if (cb is Map && (cb['type'] == 'server_tool_use')) {
              final id = (cb['id'] ?? '').toString();
              final idx2 = idx ?? -1;
              if (id.isNotEmpty && idx2 >= 0) {
                srvIndexToId[idx2] = id;
                srvArgsStr[id] = '';
              }
              // Emit placeholder for server tool to show card (e.g., built-in web_search)
              if (id.isNotEmpty) {
                yield ChatStreamChunk(
                  content: '',
                  isDone: false,
                  totalTokens: roundTokens,
                  usage: usage,
                  toolCalls: [
                    ToolCallInfo(
                      id: id,
                      name: 'search_web',
                      arguments: const <String, dynamic>{},
                    ),
                  ],
                );
              }
            } else if (cb is Map && (cb['type'] == 'web_search_tool_result')) {
              // Emit simplified search results to UI
              final toolUseId = (cb['tool_use_id'] ?? '').toString();
              final contentBlock = cb['content'];
              final items = <Map<String, dynamic>>[];
              String? errorCode;
              if (contentBlock is List) {
                for (int j = 0; j < contentBlock.length; j++) {
                  final it = contentBlock[j];
                  if (it is Map && (it['type'] == 'web_search_result')) {
                    items.add({
                      'index': j + 1,
                      'title': (it['title'] ?? '').toString(),
                      'url': (it['url'] ?? '').toString(),
                      if ((it['page_age'] ?? '').toString().isNotEmpty)
                        'page_age': (it['page_age'] ?? '').toString(),
                    });
                  }
                }
              } else if (contentBlock is Map &&
                  (contentBlock['type'] == 'web_search_tool_result_error')) {
                errorCode = (contentBlock['error_code'] ?? '').toString();
              }
              Map<String, dynamic> args = const <String, dynamic>{};
              if (srvArgs.containsKey(toolUseId)) {
                args = srvArgs[toolUseId]!;
              }
              final payload = jsonEncode({
                'items': items,
                if ((errorCode ?? '').isNotEmpty) 'error': errorCode,
              });
              yield ChatStreamChunk(
                content: '',
                isDone: false,
                totalTokens: roundTokens,
                usage: usage,
                toolResults: [
                  ToolResultInfo(
                    id: toolUseId.isEmpty ? 'builtin_search' : toolUseId,
                    name: 'search_web',
                    arguments: args,
                    content: payload,
                  ),
                ],
              );
            }
          } else if (type == 'content_block_delta') {
            final delta = obj['delta'];
            if (delta != null) {
              if (delta['type'] == 'text_delta') {
                final content = delta['text'] ?? '';
                if (content is String && content.isNotEmpty) {
                  textBuf.write(content);
                  yield ChatStreamChunk(
                    content: content,
                    isDone: false,
                    totalTokens: roundTokens,
                  );
                }
              } else if (delta['type'] == 'thinking_delta') {
                final idx = parseIndex(obj['index']);
                final thinking =
                    (delta['thinking'] ?? delta['text'] ?? '') as String;
                if (thinking.isNotEmpty) {
                  yield ChatStreamChunk(
                    content: '',
                    reasoning: thinking,
                    isDone: false,
                    totalTokens: roundTokens,
                  );
                  if (idx != null && thinkingText.containsKey(idx)) {
                    thinkingText[idx]!.write(thinking);
                  }
                }
              } else if (delta['type'] == 'signature_delta') {
                final idx = parseIndex(obj['index']);
                final sig = (delta['signature'] ?? '').toString();
                if (sig.isNotEmpty &&
                    idx != null &&
                    thinkingSig.containsKey(idx)) {
                  thinkingSig[idx]!.write(sig);
                }
              } else if (delta['type'] == 'redacted_thinking_delta') {
                final idx = parseIndex(obj['index']);
                final data = (delta['data'] ?? '').toString();
                if (data.isNotEmpty &&
                    idx != null &&
                    redactedThinkingData.containsKey(idx)) {
                  redactedThinkingData[idx]!.write(data);
                }
              } else if (delta['type'] == 'tool_use_delta') {
                final idx = (obj['index'] is int)
                    ? obj['index'] as int
                    : int.tryParse((obj['index'] ?? '').toString());
                final id = (idx != null && cliIndexToId.containsKey(idx))
                    ? cliIndexToId[idx]!
                    : '';
                if (id.isNotEmpty) {
                  final argsDelta =
                      (delta['partial_json'] ??
                              delta['input'] ??
                              delta['text'] ??
                              '')
                          .toString();
                  final entry = anthToolUse.putIfAbsent(
                    id,
                    () => {'name': '', 'args': ''},
                  );
                  if (argsDelta.isNotEmpty) {
                    entry['args'] = (entry['args'] ?? '') + argsDelta;
                  }
                }
              } else if (delta['type'] == 'input_json_delta') {
                final idxRaw = obj['index'];
                final index = (idxRaw is int)
                    ? idxRaw
                    : int.tryParse((idxRaw ?? '').toString());
                final part = (delta['partial_json'] ?? '').toString();
                if (index != null && part.isNotEmpty) {
                  if (cliIndexToId.containsKey(index)) {
                    final id = cliIndexToId[index]!;
                    final entry = anthToolUse.putIfAbsent(
                      id,
                      () => {'name': '', 'args': ''},
                    );
                    entry['args'] = (entry['args'] ?? '') + part;
                  } else if (srvIndexToId.containsKey(index)) {
                    final id = srvIndexToId[index]!;
                    srvArgsStr[id] = (srvArgsStr[id] ?? '') + part;
                  }
                }
              }
            }
          } else if (type == 'content_block_stop') {
            final idx = parseIndex(obj['index']);
            if (idx != null && thinkingIndexToAssistantBlock.containsKey(idx)) {
              final pos = thinkingIndexToAssistantBlock.remove(idx)!;
              final t = thinkingText.remove(idx)?.toString() ?? '';
              final sig = thinkingSig.remove(idx)?.toString() ?? '';
              assistantBlocks[pos] = {
                'type': 'thinking',
                'thinking': t,
                'signature': sig,
              };
            }
            if (idx != null &&
                redactedThinkingIndexToAssistantBlock.containsKey(idx)) {
              final pos = redactedThinkingIndexToAssistantBlock.remove(idx)!;
              final data = redactedThinkingData.remove(idx)?.toString() ?? '';
              assistantBlocks[pos] = {
                'type': 'redacted_thinking',
                'data': data,
              };
            }
            String id = (obj['content_block']?['id'] ?? obj['id'] ?? '')
                .toString();
            if (id.isEmpty && idx != null && cliIndexToId.containsKey(idx)) {
              id = cliIndexToId[idx]!;
            }
            if (id.isNotEmpty && anthToolUse.containsKey(id)) {
              final name = (anthToolUse[id]!['name'] ?? '').toString();
              Map<String, dynamic> args;
              try {
                args =
                    (jsonDecode((anthToolUse[id]!['args'] ?? '{}') as String)
                            as Map)
                        .cast<String, dynamic>();
              } catch (_) {
                args = <String, dynamic>{};
              }
              // Update last assistant tool_use block input
              for (int k = assistantBlocks.length - 1; k >= 0; k--) {
                final b = assistantBlocks[k];
                if (b['type'] == 'tool_use' &&
                    (b['id']?.toString() ?? '') == id) {
                  assistantBlocks[k] = {
                    'type': 'tool_use',
                    'id': id,
                    'name': name,
                    'input': args,
                  };
                  break;
                }
              }
              if (onToolCall != null) {
                final res = await onToolCall(name, args);
                toolResultsContent[id] = res;
                yield ChatStreamChunk(
                  content: '',
                  isDone: false,
                  totalTokens: roundTokens,
                  toolResults: [
                    ToolResultInfo(
                      id: id,
                      name: name,
                      arguments: args,
                      content: res,
                    ),
                  ],
                  usage: usage,
                );
              }
            } else {
              if (idx != null && srvIndexToId.containsKey(idx)) {
                final sid = srvIndexToId[idx]!;
                Map<String, dynamic> args;
                try {
                  args = (jsonDecode((srvArgsStr[sid] ?? '{}')) as Map)
                      .cast<String, dynamic>();
                } catch (_) {
                  args = <String, dynamic>{};
                }
                srvArgs[sid] = args;
                yield ChatStreamChunk(
                  content: '',
                  isDone: false,
                  totalTokens: roundTokens,
                  usage: usage,
                  toolCalls: [
                    ToolCallInfo(id: sid, name: 'search_web', arguments: args),
                  ],
                );
              }
            }
          } else if (type == 'message_delta') {
            final u = obj['usage'] ?? obj['message']?['usage'];
            if (u != null) {
              final inTok = (u['input_tokens'] ?? 0) as int;
              final outTok = (u['output_tokens'] ?? 0) as int;
              usage = (usage ?? const TokenUsage()).merge(
                TokenUsage(promptTokens: inTok, completionTokens: outTok),
              );
              roundTokens = usage.totalTokens;
            }
            try {
              final d = obj['delta'];
              final sr = (d is Map)
                  ? (d['stop_reason'] ?? d['stopReason'])
                  : null;
              if (sr is String && sr.isNotEmpty) {
                lastStopReason = sr;
              }
            } catch (_) {}
          } else if (type == 'message_stop') {
            flushTextBlock();
            messageStopped = true;
          }
        } catch (_) {}
      }
      if (messageStopped) break;
    }

    if (usage != null) {
      totalUsage = (totalUsage ?? const TokenUsage()).merge(usage);
    }

    if (anthToolUse.isEmpty) {
      final hadServerTool =
          assistantBlocks.any(
            (b) => b['type'] == 'tool_use' || b['type'] == 'text',
          ) &&
          srvIndexToId.isNotEmpty;
      final sr = lastStopReason ?? '';
      if (sr == 'pause_turn' || hadServerTool) {
        // Continue this turn with assistant content only (not fully supported by Vertex streamRawPredict yet, but good for future proofing)
        convo = [
          ...convo,
          {'role': 'assistant', 'content': assistantBlocks},
        ];
        continue;
      } else {
        yield ChatStreamChunk(
          content: '',
          isDone: true,
          totalTokens: (totalUsage?.totalTokens ?? roundTokens),
          usage: totalUsage ?? usage,
        );
        return;
      }
    }

    // Build tool_result blocks
    final toolResultsBlocks = <Map<String, dynamic>>[];
    for (final entry in anthToolUse.entries) {
      final id = entry.key;
      final name = (entry.value['name'] ?? '').toString();
      Map<String, dynamic> args;
      try {
        args = (jsonDecode((entry.value['args'] ?? '{}') as String) as Map)
            .cast<String, dynamic>();
      } catch (_) {
        args = <String, dynamic>{};
      }
      String res = toolResultsContent[id] ?? '';
      if (res.isEmpty && onToolCall != null) {
        res = await onToolCall(name, args);
      }
      toolResultsBlocks.add({
        'type': 'tool_result',
        'tool_use_id': id,
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
