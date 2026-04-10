part of '../chat_api_service.dart';

/// Builds the Gemini tools array, handling Gemini 3 coexistence vs 2.x mutual exclusion.
///
/// Gemini 3: built-in tools can coexist with function_declarations (MCP).
/// Gemini 2.x and below: code_execution is exclusive; search/url_context exclude MCP.
List<Map<String, dynamic>> _buildGeminiToolsArray({
  required Set<String> builtIns,
  required bool allowCoexistence,
  List<Map<String, dynamic>>? geminiTools,
}) {
  final toolsArr = <Map<String, dynamic>>[];
  if (allowCoexistence) {
    if (builtIns.contains(BuiltInToolNames.codeExecution)) {
      toolsArr.add({'code_execution': {}});
    }
    if (builtIns.contains(BuiltInToolNames.search)) {
      toolsArr.add({'google_search': {}});
    }
    if (builtIns.contains(BuiltInToolNames.urlContext)) {
      toolsArr.add({'url_context': {}});
    }
    if (geminiTools != null) {
      toolsArr.addAll(geminiTools);
    }
  } else {
    if (builtIns.contains(BuiltInToolNames.codeExecution)) {
      toolsArr.add({'code_execution': {}});
    } else if (builtIns.contains(BuiltInToolNames.search) ||
        builtIns.contains(BuiltInToolNames.urlContext)) {
      if (builtIns.contains(BuiltInToolNames.search)) {
        toolsArr.add({'google_search': {}});
      }
      if (builtIns.contains(BuiltInToolNames.urlContext)) {
        toolsArr.add({'url_context': {}});
      }
    } else if (geminiTools != null) {
      toolsArr.addAll(geminiTools);
    }
  }
  return toolsArr;
}

Stream<ChatStreamChunk> _sendGoogleStream(
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
  // Check for Vertex AI Claude models (prefix "claude-")
  // If it's a Claude model on Vertex, route to special handling
  if ((config.vertexAI == true) &&
      modelId.toLowerCase().startsWith('claude-')) {
    yield* _sendGoogleVertexClaudeStream(
      client: client,
      config: config,
      modelId: modelId,
      messages: messages,
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
    return;
  }

  final upstreamModelId = _apiModelId(config, modelId);
  final bool isGemini3 = upstreamModelId.toLowerCase().contains('gemini-3');
  final bool persistGeminiThoughtSigs = isGemini3;
  final builtIns = _builtInTools(config, modelId);
  final enableYoutube = builtIns.contains(BuiltInToolNames.youtube);
  // Non-streaming path: use generateContent
  if (!stream) {
    final isVertex = config.vertexAI == true;
    final base = config.baseUrl.endsWith('/')
        ? config.baseUrl.substring(0, config.baseUrl.length - 1)
        : config.baseUrl;
    String url;
    if (isVertex &&
        (config.projectId?.isNotEmpty == true) &&
        (config.location?.isNotEmpty == true)) {
      url =
          'https://aiplatform.googleapis.com/v1/projects/${config.projectId}/locations/${config.location}/publishers/google/models/$upstreamModelId:generateContent';
    } else {
      url = '$base/models/$upstreamModelId:generateContent';
    }

    // Extract system messages into systemInstruction (Google Gemini API best practice)
    String systemPrompt = '';
    final contents = <Map<String, dynamic>>[];
    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];
      final roleRaw = (msg['role'] ?? 'user').toString();
      if (roleRaw == 'system') {
        final s = (msg['content'] ?? '').toString();
        if (s.isNotEmpty) {
          systemPrompt = systemPrompt.isEmpty ? s : '$systemPrompt\n\n$s';
        }
        continue;
      }
      final role = roleRaw == 'assistant' ? 'model' : 'user';
      final isLast = i == messages.length - 1;
      final parts = <Map<String, dynamic>>[];
      final meta = _extractGeminiThoughtMeta((msg['content'] ?? '').toString());
      final raw = meta.cleanedText;
      final seenSources = <String>{};
      String normalizeSrc(String src) {
        if (src.startsWith('http') || src.startsWith('data:')) return src;
        try {
          return SandboxPathResolver.fix(src);
        } catch (_) {
          return src;
        }
      }

      final hasMarkdownImages = raw.contains('![') && raw.contains('](');
      final hasCustomImages = raw.contains('[image:');
      final hasAttachedImages =
          isLast && role == 'user' && (userImagePaths?.isNotEmpty == true);
      if (hasMarkdownImages || hasCustomImages || hasAttachedImages) {
        final parsed = await _parseTextAndImages(
          raw,
          // Gemini API 目前无法直接拉取远程 http(s) 图片
          allowRemoteImages: false,
          allowLocalImages: true,
          keepRemoteMarkdownText: true,
        );
        if (parsed.text.isNotEmpty) parts.add({'text': parsed.text});
        for (final ref in parsed.images) {
          final normalized = normalizeSrc(ref.src);
          if (!seenSources.add(normalized)) continue;
          if (ref.kind == 'data') {
            final mime = _mimeFromDataUrl(ref.src);
            final idx = ref.src.indexOf('base64,');
            if (idx > 0) {
              final b64 = ref.src.substring(idx + 7);
              parts.add({
                'inline_data': {'mime_type': mime, 'data': b64},
              });
            } else {
              parts.add({'text': ref.src});
            }
          } else if (ref.kind == 'path') {
            final mime = _mimeFromPath(ref.src);
            final b64 = await _encodeBase64File(ref.src, withPrefix: false);
            parts.add({
              'inline_data': {'mime_type': mime, 'data': b64},
            });
          } else {
            parts.add({'text': '(image) ${ref.src}'});
          }
        }
        if (hasAttachedImages) {
          for (final p in userImagePaths!) {
            final normalized = normalizeSrc(p);
            if (!seenSources.add(normalized)) continue;
            if (p.startsWith('data:')) {
              final mime = _mimeFromDataUrl(p);
              final idx = p.indexOf('base64,');
              if (idx > 0) {
                final b64 = p.substring(idx + 7);
                parts.add({
                  'inline_data': {'mime_type': mime, 'data': b64},
                });
              }
            } else if (!(p.startsWith('http://') || p.startsWith('https://'))) {
              final mime = _mimeFromPath(p);
              final b64 = await _encodeBase64File(p, withPrefix: false);
              parts.add({
                'inline_data': {'mime_type': mime, 'data': b64},
              });
            } else {
              parts.add({'text': '(image) $p'});
            }
          }
        }
      } else {
        if (raw.isNotEmpty) parts.add({'text': raw});
      }
      // YouTube URL ingestion as file_data parts (Gemini official API)
      // Only inject on the last user message of this request.
      if (role == 'user' && isLast && enableYoutube) {
        final urls = _extractYouTubeUrls(raw);
        for (final u in urls) {
          // Vertex AI requires mime_type for file_data
          if (isVertex) {
            parts.add({
              'file_data': {'file_uri': u, 'mime_type': 'video/*'},
            });
          } else {
            parts.add({
              'file_data': {'file_uri': u},
            });
          }
        }
      }
      if (role == 'model') {
        _applyGeminiThoughtSignatures(
          meta,
          parts,
          attachDummyWhenMissing: persistGeminiThoughtSigs,
        );
      }
      contents.add({'role': role, 'parts': parts});
    }

    // Map OpenAI-style tools to Gemini functionDeclarations (MCP)
    List<Map<String, dynamic>>? geminiTools;
    if (tools != null && tools.isNotEmpty) {
      final decls = <Map<String, dynamic>>[];
      for (final t in tools) {
        final fn = (t['function'] as Map<String, dynamic>?);
        if (fn == null) continue;
        final name = (fn['name'] ?? '').toString();
        if (name.isEmpty) continue;
        final desc = (fn['description'] ?? '').toString();
        final params = (fn['parameters'] as Map?)?.cast<String, dynamic>();
        final d = <String, dynamic>{
          'name': name,
          if (desc.isNotEmpty) 'description': desc,
        };
        if (params != null) d['parameters'] = _cleanSchemaForGemini(params);
        decls.add(d);
      }
      if (decls.isNotEmpty) {
        geminiTools = [
          {'function_declarations': decls},
        ];
      }
    }

    final headers = <String, String>{'Content-Type': 'application/json'};
    if (isVertex) {
      final token = await GoogleServiceAccountAuth.getAccessTokenFromJson(
        config.serviceAccountJson ?? '',
      );
      headers['Authorization'] = 'Bearer $token';
      final proj = (config.projectId ?? '').trim();
      if (proj.isNotEmpty) {
        headers['X-Goog-User-Project'] = proj;
      }
    } else {
      final apiKey = _effectiveApiKey(config);
      if (apiKey.isNotEmpty) {
        headers['x-goog-api-key'] = apiKey;
      }
    }
    headers.addAll(_customHeaders(config, modelId));
    if (extraHeaders != null && extraHeaders.isNotEmpty) {
      headers.addAll(extraHeaders);
    }

    final toolsArr = _buildGeminiToolsArray(
      builtIns: builtIns,
      allowCoexistence: isGemini3,
      geminiTools: geminiTools,
    );
    final geminiToolConfig = buildGeminiToolConfig(
      tools: toolsArr,
      isGemini3: isGemini3 && !isVertex,
    );

    Map<String, dynamic> baseBody = {
      'contents': contents,
      if (systemPrompt.isNotEmpty)
        'systemInstruction': {
          'parts': [
            {'text': systemPrompt},
          ],
        },
      if (temperature != null) 'temperature': temperature,
      if (topP != null) 'topP': topP,
      if (maxTokens != null) 'generationConfig': {'maxOutputTokens': maxTokens},
      if (toolsArr.isNotEmpty) 'tools': toolsArr,
      if (geminiToolConfig != null) 'toolConfig': geminiToolConfig,
    };
    final extraG = _customBody(config, modelId);
    if (extraG.isNotEmpty) baseBody.addAll(extraG);
    if (extraBody != null && extraBody.isNotEmpty) {
      extraBody.forEach((k, v) {
        baseBody[k] = (v is String) ? _parseOverrideValue(v) : v;
      });
    }

    TokenUsage? totalUsage;
    List<Map<String, dynamic>> currentContents =
        List<Map<String, dynamic>>.from(contents);
    while (true) {
      final req = http.Request('POST', Uri.parse(url));
      req.headers.addAll(headers);
      final body = Map<String, dynamic>.from(baseBody);
      body['contents'] = currentContents;
      req.body = jsonEncode(body);
      final resp = await client.send(req);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        final errorBody = await resp.stream.bytesToString();
        throw HttpException('HTTP ${resp.statusCode}: $errorBody');
      }
      final txt = await resp.stream.bytesToString();
      final obj = jsonDecode(txt) as Map<String, dynamic>;
      try {
        final u = (obj['usageMetadata'] as Map?)?.cast<String, dynamic>();
        if (u != null) {
          final prompt = (u['promptTokenCount'] ?? 0) as int? ?? 0;
          final completion = (u['candidatesTokenCount'] ?? 0) as int? ?? 0;
          totalUsage = (totalUsage ?? const TokenUsage()).merge(
            TokenUsage(
              promptTokens: prompt,
              completionTokens: completion,
              cachedTokens: 0,
            ),
          );
        }
      } catch (_) {}
      final candidates = (obj['candidates'] as List?) ?? const <dynamic>[];
      if (candidates.isEmpty) {
        yield ChatStreamChunk(
          content: '',
          isDone: true,
          totalTokens: totalUsage?.totalTokens ?? 0,
          usage: totalUsage,
        );
        return;
      }
      final cand = (candidates.first as Map).cast<String, dynamic>();
      final parts = (cand['content']?['parts'] as List?) ?? const <dynamic>[];
      final functionCallParts = parts
          .where((e) => e is Map && e.containsKey('functionCall'))
          .toList();
      if (functionCallParts.isNotEmpty && onToolCall != null) {
        final responseParts = <Map<String, dynamic>>[];
        for (int idx = 0; idx < functionCallParts.length; idx++) {
          final fc = functionCallParts[idx] as Map;
          final call = (fc['functionCall'] as Map).cast<String, dynamic>();
          final name = (call['name'] ?? '').toString();
          final args =
              (call['args'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{};
          // Prefer API-provided id (part-level), fall back to synthetic
          final partId = fc['id']?.toString() ?? 'fn_$idx';
          yield ChatStreamChunk(
            content: '',
            isDone: false,
            totalTokens: totalUsage?.totalTokens ?? 0,
            usage: totalUsage,
            toolCalls: [ToolCallInfo(id: partId, name: name, arguments: args)],
          );
          final res = await onToolCall(name, args);
          yield ChatStreamChunk(
            content: '',
            isDone: false,
            totalTokens: totalUsage?.totalTokens ?? 0,
            usage: totalUsage,
            toolResults: [
              ToolResultInfo(
                id: partId,
                name: name,
                arguments: args,
                content: res,
              ),
            ],
          );
          final frPart = <String, dynamic>{
            'functionResponse': {
              'name': name,
              'response': {'result': res},
            },
            if (fc.containsKey('id')) 'id': fc['id'],
          };
          responseParts.add(frPart);
        }
        currentContents = [
          ...currentContents,
          // Pass ALL parts from model response (preserves server-side tool parts,
          // thought signatures, and other fields)
          {'role': 'model', 'parts': parts},
          {'role': 'user', 'parts': responseParts},
        ];
        continue;
      }
      // Emit server-side code execution parts as tool cards.
      // Assumes executableCode and codeExecutionResult alternate in 1:1 pairs
      // (matching current Gemini API behavior).
      int codeExecIdx = 0;
      for (final p in parts) {
        if (p is! Map) continue;
        final ec = p['executableCode'] ?? p['executable_code'];
        if (ec is Map) {
          final lang = (ec['language'] ?? '').toString().toLowerCase();
          final code = (ec['code'] ?? '').toString();
          if (code.isNotEmpty) {
            final ceId = 'code_exec_$codeExecIdx';
            codeExecIdx++;
            yield ChatStreamChunk(
              content: '',
              isDone: false,
              totalTokens: totalUsage?.totalTokens ?? 0,
              usage: totalUsage,
              toolCalls: [
                ToolCallInfo(
                  id: ceId,
                  name: 'code_execution',
                  arguments: {'language': lang, 'code': code},
                ),
              ],
            );
          }
        }
        final cr = p['codeExecutionResult'] ?? p['code_execution_result'];
        if (cr is Map) {
          final outcome = (cr['outcome'] ?? '').toString();
          final output = (cr['output'] ?? '').toString();
          final resultId = codeExecIdx > 0
              ? 'code_exec_${codeExecIdx - 1}'
              : 'code_exec_0';
          yield ChatStreamChunk(
            content: '',
            isDone: false,
            totalTokens: totalUsage?.totalTokens ?? 0,
            usage: totalUsage,
            toolResults: [
              ToolResultInfo(
                id: resultId,
                name: 'code_execution',
                arguments: const <String, dynamic>{},
                content: output.isEmpty ? outcome : output,
              ),
            ],
          );
        }
      }
      final buf = StringBuffer();
      for (final p in parts) {
        if (p is! Map) continue;
        if (p['text'] is String) buf.write(p['text']);
      }
      var contentStr = buf.toString();
      if (persistGeminiThoughtSigs) {
        final metaComment = _collectThoughtSigCommentFromParts(parts);
        if (metaComment.isNotEmpty) contentStr += metaComment;
      }
      yield ChatStreamChunk(
        content: contentStr,
        isDone: true,
        totalTokens: totalUsage?.totalTokens ?? 0,
        usage: totalUsage,
      );
      return;
    }
  }

  // Implement SSE streaming via :streamGenerateContent with alt=sse
  // Build endpoint per Vertex vs Gemini
  String baseUrl;
  if (config.vertexAI == true &&
      (config.location?.isNotEmpty == true) &&
      (config.projectId?.isNotEmpty == true)) {
    final loc = config.location!.trim();
    final proj = config.projectId!.trim();
    baseUrl =
        'https://aiplatform.googleapis.com/v1/projects/$proj/locations/$loc/publishers/google/models/$upstreamModelId:streamGenerateContent';
  } else {
    final base = config.baseUrl.endsWith('/')
        ? config.baseUrl.substring(0, config.baseUrl.length - 1)
        : config.baseUrl;
    baseUrl = '$base/models/$upstreamModelId:streamGenerateContent';
  }

  // Build query with alt=sse
  final uriBase = Uri.parse(baseUrl);
  final qp = Map<String, String>.from(uriBase.queryParameters);
  qp['alt'] = 'sse';
  final uri = uriBase.replace(queryParameters: qp);
  final isVertex = config.vertexAI == true;

  // Extract system messages into systemInstruction (Google Gemini API best practice)
  String systemPrompt = '';
  final contents = <Map<String, dynamic>>[];
  for (int i = 0; i < messages.length; i++) {
    final msg = messages[i];
    final roleRaw = (msg['role'] ?? 'user').toString();
    if (roleRaw == 'system') {
      final s = (msg['content'] ?? '').toString();
      if (s.isNotEmpty) {
        systemPrompt = systemPrompt.isEmpty ? s : '$systemPrompt\n\n$s';
      }
      continue;
    }
    final role = roleRaw == 'assistant' ? 'model' : 'user';
    final isLast = i == messages.length - 1;
    final parts = <Map<String, dynamic>>[];
    final meta = _extractGeminiThoughtMeta((msg['content'] ?? '').toString());
    final raw = meta.cleanedText;
    final seenSources = <String>{};
    String normalizeSrc(String src) {
      if (src.startsWith('http') || src.startsWith('data:')) return src;
      try {
        return SandboxPathResolver.fix(src);
      } catch (_) {
        return src;
      }
    }

    // Only parse images if there are images to process
    final hasMarkdownImages = raw.contains('![') && raw.contains('](');
    final hasCustomImages = raw.contains('[image:');
    final hasAttachedImages =
        isLast && role == 'user' && (userImagePaths?.isNotEmpty == true);

    if (hasMarkdownImages || hasCustomImages || hasAttachedImages) {
      final parsed = await _parseTextAndImages(
        raw,
        // Gemini API 目前无法直接拉取远程 http(s) 图片
        allowRemoteImages: false,
        allowLocalImages: true,
        keepRemoteMarkdownText: true,
      );
      if (parsed.text.isNotEmpty) parts.add({'text': parsed.text});
      // Images extracted from this message's text
      for (final ref in parsed.images) {
        final normalized = normalizeSrc(ref.src);
        if (!seenSources.add(normalized)) continue;
        if (ref.kind == 'data') {
          final mime = _mimeFromDataUrl(ref.src);
          final idx = ref.src.indexOf('base64,');
          if (idx > 0) {
            final b64 = ref.src.substring(idx + 7);
            parts.add({
              'inline_data': {'mime_type': mime, 'data': b64},
            });
          } else {
            // If malformed data URL, include as plain text fallback
            parts.add({'text': ref.src});
          }
        } else if (ref.kind == 'path') {
          final mime = _mimeFromPath(ref.src);
          final b64 = await _encodeBase64File(ref.src, withPrefix: false);
          parts.add({
            'inline_data': {'mime_type': mime, 'data': b64},
          });
        } else {
          // Remote URL: Gemini official API doesn't fetch http(s) here; keep short reference
          parts.add({'text': '(image) ${ref.src}'});
        }
      }
      if (hasAttachedImages) {
        for (final p in userImagePaths!) {
          final normalized = normalizeSrc(p);
          if (!seenSources.add(normalized)) continue;
          if (p.startsWith('data:')) {
            final mime = _mimeFromDataUrl(p);
            final idx = p.indexOf('base64,');
            if (idx > 0) {
              final b64 = p.substring(idx + 7);
              parts.add({
                'inline_data': {'mime_type': mime, 'data': b64},
              });
            }
          } else if (!(p.startsWith('http://') || p.startsWith('https://'))) {
            final mime = _mimeFromPath(p);
            final b64 = await _encodeBase64File(p, withPrefix: false);
            parts.add({
              'inline_data': {'mime_type': mime, 'data': b64},
            });
          } else {
            // http url fallback reference text
            parts.add({'text': '(image) $p'});
          }
        }
      }
    } else {
      // No images, use simple text content
      if (raw.isNotEmpty) parts.add({'text': raw});
    }
    // YouTube URL ingestion as file_data parts (Gemini official API)
    // Only inject on the last user message of this request.
    if (role == 'user' && isLast && enableYoutube) {
      final urls = _extractYouTubeUrls(raw);
      for (final u in urls) {
        // Vertex AI requires mime_type for file_data
        if (isVertex) {
          parts.add({
            'file_data': {'file_uri': u, 'mime_type': 'video/*'},
          });
        } else {
          parts.add({
            'file_data': {'file_uri': u},
          });
        }
      }
    }
    if (role == 'model') {
      _applyGeminiThoughtSignatures(
        meta,
        parts,
        attachDummyWhenMissing: persistGeminiThoughtSigs,
      );
    }
    contents.add({'role': role, 'parts': parts});
  }

  // Effective model features (includes user overrides)
  final effective = _effectiveModelInfo(config, modelId);
  final isReasoning = effective.abilities.contains(ModelAbility.reasoning);
  final wantsImageOutput = effective.output.contains(Modality.image);
  bool expectImage = wantsImageOutput;
  bool receivedImage = false;
  final off = _isOff(thinkingBudget);

  // Map OpenAI-style tools to Gemini functionDeclarations (MCP)
  List<Map<String, dynamic>>? geminiTools;
  if (tools != null && tools.isNotEmpty) {
    final decls = <Map<String, dynamic>>[];
    for (final t in tools) {
      final fn = (t['function'] as Map<String, dynamic>?);
      if (fn == null) continue;
      final name = (fn['name'] ?? '').toString();
      if (name.isEmpty) continue;
      final desc = (fn['description'] ?? '').toString();
      final params = (fn['parameters'] as Map?)?.cast<String, dynamic>();
      final d = <String, dynamic>{
        'name': name,
        if (desc.isNotEmpty) 'description': desc,
      };
      if (params != null) {
        // Google Gemini requires strict JSON Schema compliance
        // Fix array properties that are missing 'items' field
        final cleanedParams = _cleanSchemaForGemini(params);
        d['parameters'] = cleanedParams;
      }
      decls.add(d);
    }
    if (decls.isNotEmpty) {
      geminiTools = [
        {'function_declarations': decls},
      ];
    }
  }
  final toolsArr = _buildGeminiToolsArray(
    builtIns: builtIns,
    allowCoexistence: isGemini3,
    geminiTools: geminiTools,
  );
  final geminiToolConfig = buildGeminiToolConfig(
    tools: toolsArr,
    isGemini3: isGemini3 && !isVertex,
  );

  // Maintain a rolling conversation for multi-round tool calls
  List<Map<String, dynamic>> convo = List<Map<String, dynamic>>.from(contents);
  TokenUsage? usage;
  int totalTokens = 0;

  // Accumulate built-in search citations across stream rounds
  final List<Map<String, dynamic>> builtinCitations = <Map<String, dynamic>>[];

  List<Map<String, dynamic>> parseCitations(dynamic gm) {
    final out = <Map<String, dynamic>>[];
    if (gm is! Map) return out;
    final chunks = gm['groundingChunks'] as List? ?? const <dynamic>[];
    int idx = 1;
    final seen = <String>{};
    for (final ch in chunks) {
      if (ch is! Map) continue;
      final web =
          ch['web'] as Map? ?? ch['webSite'] as Map? ?? ch['webPage'] as Map?;
      if (web is! Map) continue;
      final uri = (web['uri'] ?? web['url'] ?? '').toString();
      if (uri.isEmpty) continue;
      // Deduplicate by uri
      if (seen.contains(uri)) continue;
      seen.add(uri);
      final title = (web['title'] ?? web['name'] ?? uri).toString();
      final id = 'c${idx.toString().padLeft(2, '0')}';
      out.add({'id': id, 'index': idx, 'title': title, 'url': uri});
      idx++;
    }
    return out;
  }

  while (true) {
    final gen = <String, dynamic>{
      if (temperature != null) 'temperature': temperature,
      if (topP != null) 'topP': topP,
      if (maxTokens != null) 'maxOutputTokens': maxTokens,
      // Enable IMAGE+TEXT output modalities when model is configured to output images
      if (wantsImageOutput) 'responseModalities': ['TEXT', 'IMAGE'],
      if (isReasoning)
        'thinkingConfig': () {
          // Match gemini-3-pro or gemini-3-pro-preview (and similar variants)
          final isGemini3ProImage = upstreamModelId.contains(
            RegExp(r'gemini-3-pro-image(-preview)?', caseSensitive: false),
          );
          final isGemini31Pro = upstreamModelId.contains(
            RegExp(r'gemini-3\.1-pro(-preview)?', caseSensitive: false),
          );
          final isGemini3Pro = upstreamModelId.contains(
            RegExp(r'gemini-3-pro(-preview)?', caseSensitive: false),
          );
          final isGemini3Flash = upstreamModelId.contains(
            RegExp(r'gemini-3-flash(-preview)?', caseSensitive: false),
          );
          if (isGemini3ProImage) {
            return {
              'includeThoughts': true,
              if (thinkingBudget != null && thinkingBudget >= 0)
                'thinkingBudget': thinkingBudget,
            };
          }
          // Gemini 3.1 Pro: supports 'low', 'medium', 'high' (no minimal)
          if (isGemini31Pro) {
            String level = 'high';
            if (off) {
              level = 'low';
            } else if (thinkingBudget != null && thinkingBudget > 0) {
              if (thinkingBudget < 8000) {
                level = 'low';
              } else if (thinkingBudget < 24000) {
                level = 'medium'; // gemini 3.1 pro support medium
              }
            }
            return {'includeThoughts': true, 'thinkingLevel': level};
          }
          // Gemini 3 Pro: supports 'low' and 'high' only (no off)
          if (isGemini3Pro) {
            String level = 'high';
            if (off ||
                (thinkingBudget != null &&
                    thinkingBudget > 0 &&
                    thinkingBudget < 8000)) {
              // Off or Light (1024) → low
              level = 'low';
            }
            return {
              'includeThoughts': true,
              'thinkingLevel': level,
            }; // Gemini 3.0 Pro does not support medium, only low and high
          }
          // Gemini 3 Flash: supports 'minimal', 'low', 'medium', 'high'
          if (isGemini3Flash) {
            String level = 'high';
            if (off) {
              level = 'minimal';
            } else if (thinkingBudget != null && thinkingBudget > 0) {
              // Light (1024) → low, Medium (16000) → medium, Heavy (32000) → high
              if (thinkingBudget < 8000) {
                level = 'low';
              } else if (thinkingBudget < 24000) {
                level = 'medium';
              }
            }
            return {'includeThoughts': true, 'thinkingLevel': level};
          }
          // Gemini 2.x and below: use thinkingBudget
          if (off) return {'includeThoughts': false};
          return {
            'includeThoughts': true,
            if (thinkingBudget != null && thinkingBudget >= 0)
              'thinkingBudget': thinkingBudget,
          };
        }(),
    };
    final body = <String, dynamic>{
      'contents': convo,
      if (systemPrompt.isNotEmpty)
        'systemInstruction': {
          'parts': [
            {'text': systemPrompt},
          ],
        },
      if (gen.isNotEmpty) 'generationConfig': gen,
      if (toolsArr.isNotEmpty) 'tools': toolsArr,
      if (geminiToolConfig != null) 'toolConfig': geminiToolConfig,
    };

    final request = http.Request('POST', uri);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
    };
    if (config.vertexAI == true) {
      final token = await _maybeVertexAccessToken(config);
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      final proj = (config.projectId ?? '').trim();
      if (proj.isNotEmpty) headers['X-Goog-User-Project'] = proj;
    } else {
      final apiKey = _effectiveApiKey(config);
      if (apiKey.isNotEmpty) {
        headers['x-goog-api-key'] = apiKey;
      }
    }
    headers.addAll(_customHeaders(config, modelId));
    if (extraHeaders != null && extraHeaders.isNotEmpty) {
      headers.addAll(extraHeaders);
    }
    request.headers.addAll(headers);
    final extra = _customBody(config, modelId);
    if (extra.isNotEmpty) {
      body.addAll(extra);
    }
    if (extraBody != null && extraBody.isNotEmpty) {
      extraBody.forEach((k, v) {
        body[k] = (v is String) ? _parseOverrideValue(v) : v;
      });
    }
    request.body = jsonEncode(body);

    final resp = await client.send(request);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final errorBody = await resp.stream.bytesToString();
      throw HttpException('HTTP ${resp.statusCode}: $errorBody');
    }

    final sse = resp.stream.transform(utf8.decoder);
    String buffer = '';
    // Collect any function calls in this round
    final List<Map<String, dynamic>> calls =
        <Map<String, dynamic>>[]; // {id,name,args,res}
    // Capture server-side tool parts (Gemini 3 tool combination)
    final List<Map<String, dynamic>> roundServerParts =
        <Map<String, dynamic>>[];
    // Accumulate text for model turn in convo (needed for Gemini 3 full-parts rebuild)
    final StringBuffer roundAccumulatedText = StringBuffer();
    // Counter for server-side code execution tool cards
    int codeExecCounter = 0;

    // Track thought signature across chunks (Gemini 3 requirement)
    String? persistentThoughtSigKey;
    dynamic persistentThoughtSigVal;
    // Capture thought signatures for history (Gemini 3 image/editing)
    String? responseTextThoughtSigKey;
    dynamic responseTextThoughtSigVal;
    final List<Map<String, dynamic>> responseImageThoughtSigs =
        <Map<String, dynamic>>[];

    // Track a streaming inline image; buffer chunks and emit only the latest frame once finished
    String imageMime = 'image/png';
    String pendingImageData = '';
    String pendingImageTrailingText = '';
    bool bufferingInlineImage = false;

    bool looksLikeImageStart(String data) {
      const prefixes = <String>[
        '/9j/', // jpeg
        'iVBOR', // png
        'R0lGOD', // gif
        'UklGR', // webp
        'Qk', // bmp variants
        'SUkq', // tiff
      ];
      for (final p in prefixes) {
        if (data.startsWith(p)) return true;
      }
      return false;
    }

    Future<String> sanitizeTextIfNeeded(String input) async {
      if (input.isEmpty) return input;
      if (input.contains('data:image') && input.contains('base64,')) {
        try {
          return await MarkdownMediaSanitizer.replaceInlineBase64Images(input);
        } catch (_) {
          return input;
        }
      }
      return input;
    }

    void bufferInlineImageChunk(String mime, String data) {
      imageMime = mime.isNotEmpty ? mime : 'image/png';
      final hasExisting = pendingImageData.isNotEmpty;
      // Gemini image-preview streams often send full preview frames instead of deltas.
      // If the previous chunk already looks complete (padding) or a new frame header appears, replace it.
      final prevLooksComplete = hasExisting && pendingImageData.endsWith('=');
      final newFrame = hasExisting && looksLikeImageStart(data);
      if (prevLooksComplete || newFrame) {
        pendingImageData = data;
      } else {
        pendingImageData += data;
      }
      bufferingInlineImage = true;
      receivedImage = true;
    }

    Future<String> takeBufferedImageMarkdown() async {
      if (!bufferingInlineImage || pendingImageData.isEmpty) return '';
      final trailing = pendingImageTrailingText;
      final path = await AppDirectories.saveBase64Image(
        imageMime,
        pendingImageData,
      );
      bufferingInlineImage = false;
      pendingImageData = '';
      pendingImageTrailingText = '';
      if (path == null || path.isEmpty) return '';
      final sb = StringBuffer()
        ..write('\n\n![image](')
        ..write(path)
        ..write(')');
      if (trailing.isNotEmpty) {
        sb.write(trailing);
      }
      return sb.toString();
    }

    await for (final chunk in _ensureTrailingNewline(sse)) {
      buffer += chunk;
      final lines = buffer.split('\n');
      buffer = lines.last; // keep incomplete line

      for (int i = 0; i < lines.length - 1; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        if (!line.startsWith('data:')) continue;
        final data = line.substring(5).trim(); // after 'data:'
        if (data.isEmpty) continue;
        try {
          final obj = jsonDecode(data) as Map<String, dynamic>;
          final um = obj['usageMetadata'];
          if (um is Map<String, dynamic>) {
            usage = (usage ?? const TokenUsage()).merge(
              TokenUsage(
                promptTokens: (um['promptTokenCount'] ?? 0) as int,
                completionTokens: (um['candidatesTokenCount'] ?? 0) as int,
                totalTokens: (um['totalTokenCount'] ?? 0) as int,
              ),
            );
            totalTokens = usage.totalTokens;
          }

          final candidates = obj['candidates'];
          if (candidates is List && candidates.isNotEmpty) {
            String textDelta = '';
            String reasoningDelta = '';
            String? finishReason; // detect stream completion from server
            for (final cand in candidates) {
              if (cand is! Map) continue;
              final content = cand['content'];
              if (content is! Map) continue;
              final parts = content['parts'];
              if (parts is! List) continue;
              for (final p in parts) {
                if (p is! Map) continue;
                String? partThoughtSigKey;
                dynamic partThoughtSigVal;
                if (p.containsKey('thoughtSignature')) {
                  partThoughtSigKey = 'thoughtSignature';
                  partThoughtSigVal = p['thoughtSignature'];
                } else if (p.containsKey('thought_signature')) {
                  partThoughtSigKey = 'thought_signature';
                  partThoughtSigVal = p['thought_signature'];
                }
                final t = (p['text'] ?? '') as String? ?? '';
                final thought = p['thought'] as bool? ?? false;

                // Check for thought signature in this part and update persistence
                if (partThoughtSigKey != null) {
                  persistentThoughtSigKey = partThoughtSigKey;
                  persistentThoughtSigVal = partThoughtSigVal;
                }

                // Capture thought signature for text part (Gemini 3 image/editing)
                if (persistGeminiThoughtSigs &&
                    !thought &&
                    partThoughtSigKey != null &&
                    partThoughtSigVal != null) {
                  if (t.isNotEmpty && responseTextThoughtSigKey == null) {
                    responseTextThoughtSigKey = partThoughtSigKey;
                    responseTextThoughtSigVal = partThoughtSigVal;
                  }
                }

                if (t.isNotEmpty) {
                  if (thought) {
                    reasoningDelta += t;
                  } else if (bufferingInlineImage) {
                    pendingImageTrailingText += t;
                  } else {
                    textDelta += t;
                    // Accumulate full text for convo rebuild (Gemini 3)
                    if (isGemini3) roundAccumulatedText.write(t);
                  }
                }
                // Parse inline image data from Gemini (inlineData)
                // Response shape: { inlineData: { mimeType: 'image/png', data: '...base64...' } }
                final inline = (p['inlineData'] ?? p['inline_data']);
                if (inline is Map) {
                  final mime =
                      (inline['mimeType'] ?? inline['mime_type'] ?? 'image/png')
                          .toString();
                  final data = (inline['data'] ?? '').toString();
                  if (data.isNotEmpty) {
                    if (persistGeminiThoughtSigs &&
                        partThoughtSigKey != null &&
                        partThoughtSigVal != null) {
                      final exists = responseImageThoughtSigs.any(
                        (e) =>
                            e['k'] == partThoughtSigKey &&
                            e['v'] == partThoughtSigVal,
                      );
                      if (!exists) {
                        responseImageThoughtSigs.add({
                          'k': partThoughtSigKey,
                          'v': partThoughtSigVal,
                        });
                      }
                    }
                    bufferInlineImageChunk(mime, data);
                  }
                }
                // Parse fileData: { fileUri: 'https://...', mimeType: 'image/png' }
                final fileData = (p['fileData'] ?? p['file_data']);
                if (fileData is Map) {
                  final mime =
                      (fileData['mimeType'] ??
                              fileData['mime_type'] ??
                              'image/png')
                          .toString();
                  final uri =
                      (fileData['fileUri'] ??
                              fileData['file_uri'] ??
                              fileData['uri'] ??
                              '')
                          .toString();
                  if (uri.startsWith('http')) {
                    try {
                      final b64 = await _downloadRemoteAsBase64(
                        client,
                        config,
                        uri,
                      );
                      if (persistGeminiThoughtSigs &&
                          partThoughtSigKey != null &&
                          partThoughtSigVal != null) {
                        final exists = responseImageThoughtSigs.any(
                          (e) =>
                              e['k'] == partThoughtSigKey &&
                              e['v'] == partThoughtSigVal,
                        );
                        if (!exists) {
                          responseImageThoughtSigs.add({
                            'k': partThoughtSigKey,
                            'v': partThoughtSigVal,
                          });
                        }
                      }
                      bufferInlineImageChunk(mime, b64);
                    } catch (_) {}
                  }
                }
                // Emit server-side code execution parts as tool cards.
                // Assumes executableCode and codeExecutionResult alternate in
                // 1:1 pairs (matching current Gemini API behavior).
                final codeExec = p['executableCode'] ?? p['executable_code'];
                if (codeExec is Map) {
                  final lang = (codeExec['language'] ?? '')
                      .toString()
                      .toLowerCase();
                  final code = (codeExec['code'] ?? '').toString();
                  if (code.isNotEmpty) {
                    final ceId = 'code_exec_$codeExecCounter';
                    codeExecCounter++;
                    yield ChatStreamChunk(
                      content: '',
                      isDone: false,
                      totalTokens: totalTokens,
                      usage: usage,
                      toolCalls: [
                        ToolCallInfo(
                          id: ceId,
                          name: 'code_execution',
                          arguments: {'language': lang, 'code': code},
                        ),
                      ],
                    );
                  }
                }
                final codeResult =
                    p['codeExecutionResult'] ?? p['code_execution_result'];
                if (codeResult is Map) {
                  final outcome = (codeResult['outcome'] ?? '').toString();
                  final output = (codeResult['output'] ?? '').toString();
                  final resultId = codeExecCounter > 0
                      ? 'code_exec_${codeExecCounter - 1}'
                      : 'code_exec_0';
                  yield ChatStreamChunk(
                    content: '',
                    isDone: false,
                    totalTokens: totalTokens,
                    usage: usage,
                    toolResults: [
                      ToolResultInfo(
                        id: resultId,
                        name: 'code_execution',
                        arguments: const <String, dynamic>{},
                        content: output.isEmpty ? outcome : output,
                      ),
                    ],
                  );
                }
                // Capture server-side tool parts for convo rebuild (Gemini 3).
                // Uses deny-list: preserves any part not already handled by client
                // (text, functionCall, inlineData, fileData, thought, code execution).
                // Per the API contract, all parts must be returned to maintain context.
                // TODO: update this deny-list when Gemini API introduces new
                // client-handled part types to avoid incorrectly capturing them.
                if (isGemini3 &&
                    !p.containsKey('text') &&
                    !p.containsKey('functionCall') &&
                    !p.containsKey('inlineData') &&
                    !p.containsKey('inline_data') &&
                    !p.containsKey('fileData') &&
                    !p.containsKey('file_data') &&
                    p['thought'] != true) {
                  roundServerParts.add(Map<String, dynamic>.from(p));
                }
                final fc = p['functionCall'];
                if (fc is Map) {
                  final name = (fc['name'] ?? '').toString();
                  Map<String, dynamic> args = const <String, dynamic>{};
                  final rawArgs = fc['args'];
                  if (rawArgs is Map) {
                    args = rawArgs.cast<String, dynamic>();
                  } else if (rawArgs is String && rawArgs.isNotEmpty) {
                    try {
                      args = (jsonDecode(rawArgs) as Map)
                          .cast<String, dynamic>();
                    } catch (_) {}
                  }
                  // Prefer API-provided id (part-level), fall back to synthetic
                  final apiId = p['id']?.toString();
                  final id =
                      apiId ?? 'call_${DateTime.now().microsecondsSinceEpoch}';

                  // Capture thought signature (Gemini 3 Pro requirement)
                  // Preserve exact key/value as received
                  String? thoughtSigKey;
                  dynamic thoughtSigVal;
                  if (p.containsKey('thoughtSignature')) {
                    thoughtSigKey = 'thoughtSignature';
                    thoughtSigVal = p['thoughtSignature'];
                  } else if (p.containsKey('thought_signature')) {
                    thoughtSigKey = 'thought_signature';
                    thoughtSigVal = p['thought_signature'];
                  }

                  // Fallback to persistent signature if not found in this part
                  if (thoughtSigKey == null &&
                      persistentThoughtSigKey != null) {
                    thoughtSigKey = persistentThoughtSigKey;
                    thoughtSigVal = persistentThoughtSigVal;
                  }

                  // Emit placeholder immediately
                  yield ChatStreamChunk(
                    content: '',
                    isDone: false,
                    totalTokens: totalTokens,
                    usage: usage,
                    toolCalls: [
                      ToolCallInfo(id: id, name: name, arguments: args),
                    ],
                  );
                  String resText = '';
                  if (onToolCall != null) {
                    resText = await onToolCall(name, args);
                    yield ChatStreamChunk(
                      content: '',
                      isDone: false,
                      totalTokens: totalTokens,
                      usage: usage,
                      toolResults: [
                        ToolResultInfo(
                          id: id,
                          name: name,
                          arguments: args,
                          content: resText,
                        ),
                      ],
                    );
                  }
                  calls.add({
                    'id': id,
                    'apiId': apiId,
                    'name': name,
                    'args': args,
                    'result': resText,
                    'thoughtSigKey': thoughtSigKey,
                    'thoughtSigVal': thoughtSigVal,
                  });
                }
              }
              // Capture explicit finish reason if present
              final fr = cand['finishReason'];
              if (fr is String && fr.isNotEmpty) finishReason = fr;

              // Parse grounding metadata for citations if present
              final gm = cand['groundingMetadata'] ?? obj['groundingMetadata'];
              final cite = parseCitations(gm);
              if (cite.isNotEmpty) {
                // merge unique by url
                final existingUrls = builtinCitations
                    .map((e) => e['url']?.toString() ?? '')
                    .toSet();
                for (final it in cite) {
                  final u = it['url']?.toString() ?? '';
                  if (u.isEmpty || existingUrls.contains(u)) continue;
                  builtinCitations.add(it);
                  existingUrls.add(u);
                }
                // emit a tool result chunk so UI can render citations card
                final payload = jsonEncode({'items': builtinCitations});
                yield ChatStreamChunk(
                  content: '',
                  isDone: false,
                  totalTokens: totalTokens,
                  usage: usage,
                  toolResults: [
                    ToolResultInfo(
                      id: 'builtin_search',
                      name: 'builtin_search',
                      arguments: const <String, dynamic>{},
                      content: payload,
                    ),
                  ],
                );
              }
            }

            // When finishing, emit any buffered inline image (and trailing text) in one batch to avoid partial base64 during streaming.
            if (finishReason != null) {
              final pendingImage = await takeBufferedImageMarkdown();
              if (pendingImage.isNotEmpty) {
                textDelta += pendingImage;
              }
            }

            if (reasoningDelta.isNotEmpty) {
              yield ChatStreamChunk(
                content: '',
                reasoning: reasoningDelta,
                isDone: false,
                totalTokens: totalTokens,
                usage: usage,
              );
            }
            if (textDelta.isNotEmpty) {
              textDelta = await sanitizeTextIfNeeded(textDelta);
              yield ChatStreamChunk(
                content: textDelta,
                isDone: false,
                totalTokens: totalTokens,
                usage: usage,
              );
            }

            // If server signaled finish, end stream immediately
            if (finishReason != null &&
                calls.isEmpty &&
                (!expectImage || receivedImage)) {
              // Emit final citations if any not emitted
              if (builtinCitations.isNotEmpty) {
                final payload = jsonEncode({'items': builtinCitations});
                yield ChatStreamChunk(
                  content: '',
                  isDone: false,
                  totalTokens: totalTokens,
                  usage: usage,
                  toolResults: [
                    ToolResultInfo(
                      id: 'builtin_search',
                      name: 'builtin_search',
                      arguments: const <String, dynamic>{},
                      content: payload,
                    ),
                  ],
                );
              }
              if (persistGeminiThoughtSigs) {
                final metaComment = _buildGeminiThoughtSigComment(
                  textKey: responseTextThoughtSigKey,
                  textValue: responseTextThoughtSigVal,
                  imageSigs: responseImageThoughtSigs,
                );
                if (metaComment.isNotEmpty) {
                  yield ChatStreamChunk(
                    content: metaComment,
                    isDone: false,
                    totalTokens: totalTokens,
                    usage: usage,
                  );
                }
              }
              yield ChatStreamChunk(
                content: '',
                isDone: true,
                totalTokens: totalTokens,
                usage: usage,
              );
              return;
            }
          }
        } catch (_) {
          // ignore malformed chunk
        }
      }
    }

    // Flush any buffered inline image (e.g., when stream ends without explicit finishReason)
    final pendingImage = await takeBufferedImageMarkdown();
    if (pendingImage.isNotEmpty) {
      final sanitized = await sanitizeTextIfNeeded(pendingImage);
      yield ChatStreamChunk(
        content: sanitized,
        isDone: false,
        totalTokens: totalTokens,
        usage: usage,
      );
    }

    if (calls.isEmpty) {
      // No tool calls; this round finished
      if (persistGeminiThoughtSigs) {
        final metaComment = _buildGeminiThoughtSigComment(
          textKey: responseTextThoughtSigKey,
          textValue: responseTextThoughtSigVal,
          imageSigs: responseImageThoughtSigs,
        );
        if (metaComment.isNotEmpty) {
          yield ChatStreamChunk(
            content: metaComment,
            isDone: false,
            totalTokens: totalTokens,
            usage: usage,
          );
        }
      }
      yield ChatStreamChunk(
        content: '',
        isDone: true,
        totalTokens: totalTokens,
        usage: usage,
      );
      return;
    }

    // Append model functionCall(s) and user functionResponse(s) to conversation, then loop
    if (isGemini3) {
      // Gemini 3: build a single model turn with all parts (text, server-side
      // tool parts, and functionCall parts) to preserve full context.
      final modelParts = <Map<String, dynamic>>[];

      // 1. Accumulated text part (with thought signature if available)
      final accText = roundAccumulatedText.toString();
      if (accText.isNotEmpty) {
        final textPart = <String, dynamic>{'text': accText};
        if (responseTextThoughtSigKey != null &&
            responseTextThoughtSigVal != null) {
          textPart[responseTextThoughtSigKey] = responseTextThoughtSigVal;
        }
        modelParts.add(textPart);
      }

      // 2. Server-side tool parts (toolCall/toolResponse, preserved raw)
      modelParts.addAll(roundServerParts);

      // 3. functionCall parts (with thought signatures)
      for (final c in calls) {
        final name = (c['name'] ?? '').toString();
        final args =
            (c['args'] as Map<String, dynamic>? ?? const <String, dynamic>{});
        final thoughtSigKey = c['thoughtSigKey'] as String?;
        final thoughtSigVal = c['thoughtSigVal'];
        final apiId = c['apiId'] as String?;
        final part = <String, dynamic>{
          'functionCall': {'name': name, 'args': args},
          if (apiId != null) 'id': apiId,
        };
        if (thoughtSigKey != null && thoughtSigVal != null) {
          part[thoughtSigKey] = thoughtSigVal;
        }
        modelParts.add(part);
      }

      convo.add({'role': 'model', 'parts': modelParts});

      // 4. All functionResponses in one user turn
      final responseParts = <Map<String, dynamic>>[];
      for (final c in calls) {
        final name = (c['name'] ?? '').toString();
        final resText = (c['result'] ?? '').toString();
        final apiId = c['apiId'] as String?;
        Map<String, dynamic> responseObj;
        try {
          responseObj = (jsonDecode(resText) as Map).cast<String, dynamic>();
        } catch (_) {
          responseObj = {'result': resText};
        }
        responseParts.add({
          'functionResponse': {'name': name, 'response': responseObj},
          if (apiId != null) 'id': apiId,
        });
      }
      convo.add({'role': 'user', 'parts': responseParts});
    } else {
      // Gemini 2.x: existing per-call reconstruction
      for (final c in calls) {
        final name = (c['name'] ?? '').toString();
        final args =
            (c['args'] as Map<String, dynamic>? ?? const <String, dynamic>{});
        final resText = (c['result'] ?? '').toString();
        final thoughtSigKey = c['thoughtSigKey'] as String?;
        final thoughtSigVal = c['thoughtSigVal'];

        final part = <String, dynamic>{
          'functionCall': {'name': name, 'args': args},
        };
        if (thoughtSigKey != null && thoughtSigVal != null) {
          part[thoughtSigKey] = thoughtSigVal;
        }

        convo.add({
          'role': 'model',
          'parts': [part],
        });
        Map<String, dynamic> responseObj;
        try {
          responseObj = (jsonDecode(resText) as Map).cast<String, dynamic>();
        } catch (_) {
          responseObj = {'result': resText};
        }
        convo.add({
          'role': 'user',
          'parts': [
            {
              'functionResponse': {'name': name, 'response': responseObj},
            },
          ],
        });
      }
    }
    // Continue while(true) for next round
  }
}
