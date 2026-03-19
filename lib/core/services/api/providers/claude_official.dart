part of '../chat_api_service.dart';

Stream<ChatStreamChunk> _sendClaudeStream(
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
}) async* {
  final upstreamModelId = _apiModelId(config, modelId);
  // Endpoint and headers (constant across rounds)
  final base = config.baseUrl.endsWith('/')
      ? config.baseUrl.substring(0, config.baseUrl.length - 1)
      : config.baseUrl;
  final url = Uri.parse('$base/messages');

  final isReasoning = _effectiveModelInfo(
    config,
    modelId,
  ).abilities.contains(ModelAbility.reasoning);

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
    nonSystemMessages.add({
      'role': role.isEmpty ? 'user' : role,
      'content': m['content'] ?? '',
    });
  }

  // Transform last user message to include images per Anthropic schema
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
        if (p.startsWith('http') || p.startsWith('data:')) {
          parts.add({'type': 'text', 'text': p});
        } else {
          final mime = _mimeFromPath(p);
          final b64 = await _encodeBase64File(p, withPrefix: false);
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

  // Headers (constant across rounds)
  final baseHeaders = <String, String>{
    'x-api-key': _effectiveApiKey(config),
    'anthropic-version': '2023-06-01',
    'Content-Type': 'application/json',
    'Accept': stream ? 'text/event-stream' : 'application/json',
  };
  baseHeaders.addAll(_customHeaders(config, modelId));
  if (extraHeaders != null && extraHeaders.isNotEmpty) {
    baseHeaders.addAll(extraHeaders);
  }

  // Running conversation across rounds
  List<Map<String, dynamic>> convo = List<Map<String, dynamic>>.from(
    initialMessages,
  );
  TokenUsage? totalUsage;

  while (true) {
    // Prepare request body per round
    final body = <String, dynamic>{
      'model': upstreamModelId,
      'max_tokens': maxTokens ?? 64000,
      'messages': convo,
      'stream': stream,
      if (systemPrompt.isNotEmpty) 'system': systemPrompt,
      if (temperature != null) 'temperature': temperature,
      if (topP != null) 'top_p': topP,
      if (allTools.isNotEmpty) 'tools': allTools,
      if (allTools.isNotEmpty) 'tool_choice': {'type': 'auto'},
      if (isReasoning)
        'thinking': {
          'type': thinkingBudget == 0
              ? 'disabled'
              : (thinkingBudget == null || thinkingBudget == -1) &&
                    RegExp(
                      r'claude-(?:opus|sonnet)-4-6',
                      caseSensitive: false,
                    ).hasMatch(upstreamModelId)
              ? 'adaptive'
              : 'enabled',
          if (thinkingBudget != null && thinkingBudget > 0)
            'budget_tokens': thinkingBudget,
        },
    };
    final extraClaude = _customBody(config, modelId);
    if (extraClaude.isNotEmpty) {
      body.addAll(extraClaude);
    }
    if (extraBody != null && extraBody.isNotEmpty) {
      extraBody.forEach((k, v) {
        body[k] = (v is String) ? _parseOverrideValue(v) : v;
      });
    }

    final request = http.Request('POST', url);
    request.headers.addAll(baseHeaders);
    request.body = jsonEncode(body);

    final response = await client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorBody = await response.stream.bytesToString();
      throw HttpException('HTTP ${response.statusCode}: $errorBody');
    }

    // Non-streaming path: parse full JSON, handle tool_use, then continue loop if needed.
    if (!stream) {
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

    final sse = response.stream.transform(utf8.decoder);
    String buffer = '';
    int roundTokens = 0;
    TokenUsage? usage;
    String? lastStopReason;

    // Per-round accumulation
    final Map<String, Map<String, dynamic>> anthToolUse =
        <String, Map<String, dynamic>>{}; // id -> {name, args}
    final Map<int, String> cliIndexToId =
        <int, String>{}; // client tool: index -> id
    final Map<String, String> toolResultsContent =
        <String, String>{}; // id -> result text
    final List<Map<String, dynamic>> assistantBlocks = <Map<String, dynamic>>[];
    final StringBuffer textBuf = StringBuffer();

    // Track thinking blocks so they can be sent back for tool-use continuation.
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

    // Server tool helpers (web_search)
    final Map<int, String> srvIndexToId = <int, String>{};
    final Map<String, String> srvArgsStr = <String, String>{};
    final Map<String, Map<String, dynamic>> srvArgs =
        <String, Map<String, dynamic>>{};

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
              // Preserve thinking blocks (with signature) for tool-use continuation.
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
              // Flush text block before tool_use
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
                if (idx2 >= 0) cliIndexToId[idx2] = id;
                // Emit placeholder tool-call card immediately
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
              if (srvArgs.containsKey(toolUseId)) args = srvArgs[toolUseId]!;
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
                // Client tool input fragments stream under the same content_block index
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
            // Finalize thinking blocks so they can be sent back unmodified.
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
              // Emit tool result to UI (placeholder was emitted at start)
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
                  args = jsonDecode(
                    srvArgsStr[sid] ?? '{}',
                  ).cast<String, dynamic>();
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
            // Capture stop reason to handle pause_turn for server tools
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
            // Flush remaining text
            final t = textBuf.toString();
            if (t.isNotEmpty) {
              assistantBlocks.add({'type': 'text', 'text': t});
            }
            messageStopped = true;
          }
        } catch (_) {
          // ignore malformed chunk
        }
      }
      if (messageStopped) {
        break; // break await-for
      }
    }

    // Merge usage across rounds for final token count
    if (usage != null) {
      totalUsage = (totalUsage ?? const TokenUsage()).merge(usage);
    }

    // If no client tool calls, decide whether to continue (pause_turn/server tool) or finalize
    if (anthToolUse.isEmpty) {
      final hadServerTool =
          assistantBlocks.any(
            (b) => b['type'] == 'tool_use' || b['type'] == 'text',
          ) &&
          srvIndexToId.isNotEmpty;
      final sr = lastStopReason ?? '';
      if (sr == 'pause_turn' || hadServerTool) {
        // Continue this turn with assistant content only
        convo = [
          ...convo,
          {'role': 'assistant', 'content': assistantBlocks},
        ];
        // Loop to next round
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

    // Build tool_result blocks in a single user message (parallel-safe)
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

    // Extend conversation: assistant content (with tool_use blocks) + user tool_results
    convo = [
      ...convo,
      {'role': 'assistant', 'content': assistantBlocks},
      {'role': 'user', 'content': toolResultsBlocks},
    ];
    // Loop to next round; the next response will stream more assistant content
  }
}
