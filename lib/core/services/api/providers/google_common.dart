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

bool _isGemma4Model(String modelId) {
  return RegExp(
    r'(^|[/:_-])gemma[-_]?4([._-]|$)',
    caseSensitive: false,
  ).hasMatch(modelId);
}

bool _isGemini35FlashModel(String modelId) {
  return modelId.contains(
    RegExp(r'gemini-3\.5-flash([._:@/-]|$)', caseSensitive: false),
  );
}

bool _isGemini35FlashLiteModel(String modelId) {
  return modelId.contains(
    RegExp(r'gemini-3\.5-flash-lite([._:@/-]|$)', caseSensitive: false),
  );
}

bool _isGemini36FlashModel(String modelId) {
  return modelId.contains(
    RegExp(r'gemini-3\.6-flash([._:@/-]|$)', caseSensitive: false),
  );
}

bool _isGemini3TextModel(String modelId) {
  return modelId.contains(
    RegExp(r'gemini-3(?:\.\d+)?-(?!pro-image)', caseSensitive: false),
  );
}

bool _shouldOmitGeminiSamplingParams(String modelId) {
  return _isGemini3TextModel(modelId);
}

Map<String, dynamic> _googleThinkingConfig(
  String upstreamModelId,
  int? budget,
) {
  final off = _isOff(budget);
  if (_isGemma4Model(upstreamModelId)) {
    if (off) return const <String, dynamic>{};
    return const <String, dynamic>{
      'includeThoughts': true,
      'thinkingLevel': 'high',
    };
  }

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
  final isGemini35Flash = _isGemini35FlashModel(upstreamModelId);
  final isGemini35FlashLite = _isGemini35FlashLiteModel(upstreamModelId);
  final isGemini36Flash = _isGemini36FlashModel(upstreamModelId);
  if (isGemini3ProImage) {
    return {
      'includeThoughts': true,
      if (budget != null && budget >= 0) 'thinkingBudget': budget,
    };
  }
  // Gemini 3.1 Pro: supports 'low', 'medium', 'high' (no minimal)
  if (isGemini31Pro) {
    String level = 'high';
    if (off) {
      level = 'low';
    } else if (budget != null && budget > 0) {
      if (budget < 8000) {
        level = 'low';
      } else if (budget < 24000) {
        level = 'medium'; // gemini 3.1 pro support medium
      }
    }
    return {'includeThoughts': true, 'thinkingLevel': level};
  }
  // Gemini 3 Pro: supports 'low' and 'high' only (no off)
  if (isGemini3Pro) {
    String level = 'high';
    if (off || (budget != null && budget > 0 && budget < 8000)) {
      // Off or Light (1024) -> low
      level = 'low';
    }
    return {'includeThoughts': true, 'thinkingLevel': level};
  }
  // Gemini 3 Flash, 3.5 Flash/Lite, and 3.6 Flash support
  // 'minimal', 'low', 'medium', and 'high'.
  if (isGemini3Flash || isGemini35Flash || isGemini36Flash) {
    String level = isGemini35FlashLite
        ? 'minimal'
        : (isGemini35Flash || isGemini36Flash ? 'medium' : 'high');
    if (off) {
      level = 'minimal';
    } else if (budget != null && budget > 0) {
      // Light (1024) -> low, Medium (16000) -> medium, Heavy (32000) -> high
      if (budget < 8000) {
        level = 'low';
      } else if (budget < 24000) {
        level = 'medium';
      } else {
        level = 'high';
      }
    }
    return {'includeThoughts': true, 'thinkingLevel': level};
  }
  // Gemini 2.x and below: use thinkingBudget
  if (off) return {'includeThoughts': false};
  return {
    'includeThoughts': true,
    if (budget != null && budget >= 0) 'thinkingBudget': budget,
  };
}

Map<String, dynamic>? _googleToolMetadata(Map<String, dynamic> message) {
  final metadata = message['metadata'];
  if (metadata is! Map) return null;
  final google = metadata['google'];
  if (google is! Map) return null;
  return google.cast<String, dynamic>();
}

Map<String, dynamic>? _googleFunctionCallPartFromToolCall(Map toolCall) {
  final metadata = toolCall['metadata'];
  if (metadata is Map) {
    final google = metadata['google'];
    if (google is Map) {
      final part = google['part'];
      if (part is Map && part['functionCall'] is Map) {
        // Mutable copy: callers may need to backfill a thought signature.
        return Map<String, dynamic>.from(part);
      }
    }
  }

  final fn = toolCall['function'];
  if (fn is! Map) return null;
  final name = (fn['name'] ?? '').toString();
  if (name.isEmpty) return null;
  Map<String, dynamic> args = const <String, dynamic>{};
  try {
    args = (jsonDecode((fn['arguments'] ?? '{}').toString()) as Map)
        .cast<String, dynamic>();
  } catch (_) {}
  final part = <String, dynamic>{
    'functionCall': {'name': name, 'args': args},
  };
  final id = (toolCall['id'] ?? '').toString();
  if (id.isNotEmpty) part['id'] = id;
  return part;
}

/// Gemini 3 validates that the first functionCall part of a replayed model
/// turn carries a thought signature; a missing one fails the whole request
/// with "Function call is missing a thought_signature in functionCall parts".
/// When the original signature was not persisted (legacy history, non-streaming
/// responses), fall back to the documented placeholder so old conversations
/// keep working.
void _ensureGeminiFunctionCallThoughtSig(List<Map<String, dynamic>> parts) {
  for (final part in parts) {
    if (part['functionCall'] is! Map) continue;
    final hasSig =
        part.containsKey('thoughtSignature') ||
        part.containsKey('thought_signature');
    if (!hasSig) {
      part['thoughtSignature'] = _geminiDummyThoughtSignature;
    }
    return; // Only the first functionCall part is validated.
  }
}

Map<String, dynamic> _googleFunctionResponsePartFromToolMessage(
  Map<String, dynamic> message,
) {
  final name = (message['name'] ?? '').toString();
  final content = (message['content'] ?? '').toString();
  Map<String, dynamic> response;
  try {
    response = (jsonDecode(content) as Map).cast<String, dynamic>();
  } catch (_) {
    response = {'result': content};
  }
  final part = <String, dynamic>{
    'functionResponse': {'name': name, 'response': response},
  };
  final google = _googleToolMetadata(message);
  final rawPart = google?['part'];
  final rawFunctionCall = rawPart is Map ? rawPart['functionCall'] : null;
  final id = rawFunctionCall is Map ? rawFunctionCall['id']?.toString() : null;
  if (id != null && id.isNotEmpty) {
    (part['functionResponse'] as Map<String, dynamic>)['id'] = id;
  }
  return part;
}

List<Map<String, dynamic>> _googleApiContents(
  List<Map<String, dynamic>> contents,
) {
  return [
    for (final content in contents)
      {
        ...content,
        if (content['parts'] is List)
          'parts': [
            for (final part in content['parts'] as List)
              part is Map ? _googleApiPart(part) : part,
          ],
      },
  ];
}

Map<String, dynamic> _googleApiPart(Map part) {
  final out = Map<String, dynamic>.from(part);
  out.remove('id');
  return out;
}

int? _defaultGeminiMaxOutputTokens(String upstreamModelId) {
  if (_isGemini35FlashModel(upstreamModelId) ||
      _isGemini36FlashModel(upstreamModelId)) {
    return 65536;
  }
  return null;
}

bool _shouldRequestGoogleThoughts(
  ProviderConfig config,
  String modelId,
  ModelInfo effective,
) {
  if (effective.abilities.contains(ModelAbility.reasoning)) return true;
  final kind = ProviderConfig.classify(
    config.id,
    explicitType: config.providerType,
  );
  if (kind != ProviderKind.google) return false;
  return _apiModelId(config, modelId).toLowerCase().contains('gemini');
}

/// Gemini reports prompt-level blocks (safety filters etc.) in-band as
/// `promptFeedback.blockReason` on a frame without candidates; surface those
/// as a stream error instead of an empty "normal" completion.
void _throwIfGeminiPromptBlocked(String data) {
  if (!data.contains('blockReason')) return;
  Object? decoded;
  try {
    decoded = jsonDecode(data);
  } catch (_) {
    return;
  }
  if (decoded is! Map) return;
  final candidates = decoded['candidates'];
  if (candidates is List && candidates.isNotEmpty) return;
  final feedback = decoded['promptFeedback'];
  if (feedback is! Map) return;
  final reason = (feedback['blockReason'] ?? '').toString().trim();
  if (reason.isEmpty || reason == 'BLOCK_REASON_UNSPECIFIED') return;
  final message = (feedback['blockReasonMessage'] ?? '').toString().trim();
  throw HttpException(
    message.isEmpty
        ? 'Prompt blocked ($reason)'
        : 'Prompt blocked ($reason): $message',
  );
}

/// Output-side content filtering ends the candidate with one of these
/// `finishReason` values and then closes the stream like a regular
/// completion, so a mid-generation block would otherwise just look like a
/// short reply.
const Set<String> _geminiBlockedFinishReasons = {
  'SAFETY',
  'RECITATION',
  'BLOCKLIST',
  'PROHIBITED_CONTENT',
  'SPII',
  'IMAGE_SAFETY',
};

/// Surfaces candidate-level content filtering (`finishReason: SAFETY` etc.)
/// as a stream error so truncated output is not persisted as a normal finish.
void _throwIfGeminiCandidateBlocked(String data) {
  if (!data.contains('finishReason')) return;
  Object? decoded;
  try {
    decoded = jsonDecode(data);
  } catch (_) {
    return;
  }
  if (decoded is! Map) return;
  final candidates = decoded['candidates'];
  if (candidates is! List) return;
  for (final cand in candidates) {
    if (cand is! Map) continue;
    final reason = (cand['finishReason'] ?? '').toString().trim();
    if (!_geminiBlockedFinishReasons.contains(reason)) continue;
    final message = (cand['finishMessage'] ?? '').toString().trim();
    throw HttpException(
      message.isEmpty
          ? 'Response blocked ($reason)'
          : 'Response blocked ($reason): $message',
    );
  }
}

Stream<StreamChunk> _sendGoogleStream(
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
  // Effective model features (includes user overrides)
  final effective = _effectiveModelInfo(config, modelId);
  final isReasoning = _shouldRequestGoogleThoughts(config, modelId, effective);
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
      if (roleRaw == 'tool') {
        contents.add({
          'role': 'user',
          'parts': [_googleFunctionResponsePartFromToolMessage(msg)],
        });
        continue;
      }
      if (roleRaw == 'assistant' && msg['tool_calls'] is List) {
        final parts = <Map<String, dynamic>>[];
        final raw = _extractGeminiThoughtMeta(
          (msg['content'] ?? '').toString(),
        ).cleanedText;
        if (raw.trim().isNotEmpty && raw.trim() != '\n\n') {
          parts.add({'text': raw});
        }
        for (final tc in msg['tool_calls'] as List) {
          if (tc is! Map) continue;
          final part = _googleFunctionCallPartFromToolCall(tc);
          if (part != null) parts.add(part);
        }
        if (persistGeminiThoughtSigs) {
          _ensureGeminiFunctionCallThoughtSig(parts);
        }
        if (parts.isNotEmpty) contents.add({'role': 'model', 'parts': parts});
        continue;
      }
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

      // Semantic media detection only - custom attachment markers are not
      // recognized. Attachments arrive via structured media-path keys /
      // userImagePaths, plus Markdown ![](...).
      final hasMarkdownImages = raw.contains('![') && raw.contains('](');
      final internalMediaRefs = parseInternalMediaRefs(
        msg[multimodalInternalMediaPathsKey],
      );
      // Consume injected media refs for user and assistant history turns.
      final hasInternalMedia = internalMediaRefs.isNotEmpty;
      final hasAttachedImages =
          isLast && role == 'user' && (userImagePaths?.isNotEmpty == true);
      if (hasMarkdownImages || hasAttachedImages || hasInternalMedia) {
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
            final b64 = await _tryEncodeBase64File(ref.src, withPrefix: false);
            if (b64 == null) continue;
            parts.add({
              'inline_data': {'mime_type': mime, 'data': b64},
            });
          } else {
            parts.add({'text': '(image) ${ref.src}'});
          }
        }
        final supplementalRefs = _supplementalMediaRefs(
          internalRaw: msg[multimodalInternalMediaPathsKey],
          userPaths: userImagePaths,
          includeUserPaths: hasAttachedImages,
        );
        if (supplementalRefs.isNotEmpty) {
          for (final mediaRef in supplementalRefs) {
            final p = mediaRef.uri;
            final normalized = normalizeSrc(p);
            if (!seenSources.add(normalized)) continue;
            if (p.startsWith('data:')) {
              final mime = _mimeForInternalMediaRef(mediaRef);
              final idx = p.indexOf('base64,');
              if (idx > 0) {
                final b64 = p.substring(idx + 7);
                parts.add({
                  'inline_data': {'mime_type': mime, 'data': b64},
                });
              }
            } else if (!(p.startsWith('http://') || p.startsWith('https://'))) {
              final mime = _mimeForInternalMediaRef(mediaRef);
              final b64 = await _tryEncodeBase64File(p, withPrefix: false);
              if (b64 == null) continue;
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

    final requestHeaders = <String, String>{'Content-Type': 'application/json'};
    if (isVertex) {
      final token = await GoogleServiceAccountAuth.getAccessTokenFromJson(
        config.serviceAccountJson ?? '',
      );
      requestHeaders['Authorization'] = 'Bearer $token';
      final proj = (config.projectId ?? '').trim();
      if (proj.isNotEmpty) {
        requestHeaders['X-Goog-User-Project'] = proj;
      }
    } else {
      final apiKey = _effectiveApiKey(config);
      if (apiKey.isNotEmpty) {
        requestHeaders['x-goog-api-key'] = apiKey;
      }
    }
    final headers = _customHeaders(
      config,
      modelId,
      baseHeaders: requestHeaders,
      assistantHeaders: extraHeaders,
    );

    final toolsArr = _buildGeminiToolsArray(
      builtIns: builtIns,
      allowCoexistence: isGemini3,
      geminiTools: geminiTools,
    );
    final geminiToolConfig = buildGeminiToolConfig(
      tools: toolsArr,
      isGemini3: isGemini3 && !isVertex,
    );

    final thinkingConfig = isReasoning
        ? _googleThinkingConfig(upstreamModelId, thinkingBudget)
        : const <String, dynamic>{};
    final defaultMaxOutputTokens = _defaultGeminiMaxOutputTokens(
      upstreamModelId,
    );
    final omitSamplingParams = _shouldOmitGeminiSamplingParams(upstreamModelId);
    final generationConfig = <String, dynamic>{
      if (maxTokens ?? defaultMaxOutputTokens case final resolvedMaxTokens?)
        'maxOutputTokens': resolvedMaxTokens,
      if (thinkingConfig.isNotEmpty) 'thinkingConfig': thinkingConfig,
    };

    Map<String, dynamic> baseBody = {
      'contents': contents,
      if (systemPrompt.isNotEmpty)
        'systemInstruction': {
          'parts': [
            {'text': systemPrompt},
          ],
        },
      if (!omitSamplingParams && temperature != null)
        'temperature': temperature,
      if (!omitSamplingParams && topP != null) 'topP': topP,
      if (generationConfig.isNotEmpty) 'generationConfig': generationConfig,
      if (toolsArr.isNotEmpty) 'tools': toolsArr,
      if (geminiToolConfig != null) 'toolConfig': geminiToolConfig,
    };
    final extraG = _customBody(config, modelId, assistantBody: extraBody);
    if (extraG.isNotEmpty) baseBody.addAll(extraG);

    TokenUsage? totalUsage;
    List<Map<String, dynamic>> currentContents =
        List<Map<String, dynamic>>.from(contents);
    while (true) {
      final req = http.Request('POST', Uri.parse(url));
      req.headers.addAll(headers);
      final body = Map<String, dynamic>.from(baseBody);
      body['contents'] = _googleApiContents(currentContents);
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
        yield* emitDone(
          usage: totalUsage,
          totalTokens: totalUsage?.totalTokens ?? 0,
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
          // Prefer API-provided functionCall id, fall back to synthetic.
          final partId = _effectiveToolCallId(call['id'], 'fn', idx);
          // Preserve the raw part (incl. thoughtSignature) so the tool event
          // metadata can replay this model turn exactly on later requests.
          final rawPart = fc.cast<String, dynamic>();
          String? thoughtSigKey;
          dynamic thoughtSigVal;
          if (fc.containsKey('thoughtSignature')) {
            thoughtSigKey = 'thoughtSignature';
            thoughtSigVal = fc['thoughtSignature'];
          } else if (fc.containsKey('thought_signature')) {
            thoughtSigKey = 'thought_signature';
            thoughtSigVal = fc['thought_signature'];
          }
          final googleMetadata = <String, dynamic>{
            'google': {
              'part': rawPart,
              if (thoughtSigKey != null && thoughtSigVal != null)
                'thoughtSigKey': thoughtSigKey,
              if (thoughtSigKey != null && thoughtSigVal != null)
                'thoughtSigVal': thoughtSigVal,
            },
          };
          yield* emitToolCalls(
            [
              ToolCallInfo(
                id: partId,
                name: name,
                arguments: args,
                metadata: googleMetadata,
              ),
            ],
            usage: totalUsage,
            totalTokens: totalUsage?.totalTokens ?? 0,
          );
          final res = await onToolCall(name, args, toolCallId: partId);
          yield* emitToolResults(
            [
              ToolResultInfo(
                id: partId,
                name: name,
                arguments: args,
                content: res,
                metadata: googleMetadata,
              ),
            ],
            usage: totalUsage,
            totalTokens: totalUsage?.totalTokens ?? 0,
          );
          final frPart = <String, dynamic>{
            'functionResponse': {
              'name': name,
              'response': {'result': res},
              if (call.containsKey('id')) 'id': call['id'],
            },
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
            yield* emitToolCalls(
              [
                ToolCallInfo(
                  id: ceId,
                  name: 'code_execution',
                  arguments: {'language': lang, 'code': code},
                ),
              ],
              usage: totalUsage,
              totalTokens: totalUsage?.totalTokens ?? 0,
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
          yield* emitToolResults(
            [
              ToolResultInfo(
                id: resultId,
                name: 'code_execution',
                arguments: const <String, dynamic>{},
                content: output.isEmpty ? outcome : output,
              ),
            ],
            usage: totalUsage,
            totalTokens: totalUsage?.totalTokens ?? 0,
          );
        }
      }
      final buf = StringBuffer();
      final reasoningBuf = StringBuffer();
      for (final p in parts) {
        if (p is! Map) continue;
        final text = p['text'];
        if (text is! String || text.isEmpty) continue;
        final thought = p['thought'] as bool? ?? false;
        if (thought) {
          reasoningBuf.write(text);
        } else {
          buf.write(text);
        }
      }
      final reasoningStr = reasoningBuf.toString();
      if (reasoningStr.isNotEmpty) {
        yield* emitDelta(
          reasoning: reasoningStr,
          usage: totalUsage,
          totalTokens: totalUsage?.totalTokens ?? 0,
        );
      }
      var contentStr = buf.toString();
      if (persistGeminiThoughtSigs) {
        final metaComment = _collectThoughtSigCommentFromParts(parts);
        if (metaComment.isNotEmpty) contentStr += metaComment;
      }
      yield* emitDone(
        content: contentStr,
        usage: totalUsage,
        totalTokens: totalUsage?.totalTokens ?? 0,
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
    if (roleRaw == 'tool') {
      contents.add({
        'role': 'user',
        'parts': [_googleFunctionResponsePartFromToolMessage(msg)],
      });
      continue;
    }
    if (roleRaw == 'assistant' && msg['tool_calls'] is List) {
      final parts = <Map<String, dynamic>>[];
      final raw = _extractGeminiThoughtMeta(
        (msg['content'] ?? '').toString(),
      ).cleanedText;
      if (raw.trim().isNotEmpty && raw.trim() != '\n\n') {
        parts.add({'text': raw});
      }
      for (final tc in msg['tool_calls'] as List) {
        if (tc is! Map) continue;
        final part = _googleFunctionCallPartFromToolCall(tc);
        if (part != null) parts.add(part);
      }
      if (persistGeminiThoughtSigs) _ensureGeminiFunctionCallThoughtSig(parts);
      if (parts.isNotEmpty) contents.add({'role': 'model', 'parts': parts});
      continue;
    }
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

    // Only parse images if there are images to process.
    // Semantic media detection only - custom attachment markers are not
    // recognized. Attachments arrive via structured media-path keys /
    // userImagePaths, plus Markdown ![](...).
    final hasMarkdownImages = raw.contains('![') && raw.contains('](');
    final internalMediaRefs = parseInternalMediaRefs(
      msg[multimodalInternalMediaPathsKey],
    );
    // Consume injected media refs for user and assistant history turns.
    final hasInternalMedia = internalMediaRefs.isNotEmpty;
    final hasAttachedImages =
        isLast && role == 'user' && (userImagePaths?.isNotEmpty == true);

    if (hasMarkdownImages || hasAttachedImages || hasInternalMedia) {
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
          final b64 = await _tryEncodeBase64File(ref.src, withPrefix: false);
          if (b64 == null) continue;
          parts.add({
            'inline_data': {'mime_type': mime, 'data': b64},
          });
        } else {
          // Remote URL: Gemini official API doesn't fetch http(s) here; keep short reference
          parts.add({'text': '(image) ${ref.src}'});
        }
      }
      final supplementalRefs = _supplementalMediaRefs(
        internalRaw: msg[multimodalInternalMediaPathsKey],
        userPaths: userImagePaths,
        includeUserPaths: hasAttachedImages,
      );
      if (supplementalRefs.isNotEmpty) {
        for (final mediaRef in supplementalRefs) {
          final p = mediaRef.uri;
          final normalized = normalizeSrc(p);
          if (!seenSources.add(normalized)) continue;
          if (p.startsWith('data:')) {
            final mime = _mimeForInternalMediaRef(mediaRef);
            final idx = p.indexOf('base64,');
            if (idx > 0) {
              final b64 = p.substring(idx + 7);
              parts.add({
                'inline_data': {'mime_type': mime, 'data': b64},
              });
            }
          } else if (!(p.startsWith('http://') || p.startsWith('https://'))) {
            final mime = _mimeForInternalMediaRef(mediaRef);
            final b64 = await _tryEncodeBase64File(p, withPrefix: false);
            if (b64 == null) continue;
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

  final wantsImageOutput = effective.output.contains(Modality.image);
  bool expectImage = wantsImageOutput;
  bool receivedImage = false;

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
  int malformedResponseRetryCount = 0;
  var streamRound = 0;

  while (true) {
    final defaultMaxOutputTokens = _defaultGeminiMaxOutputTokens(
      upstreamModelId,
    );
    final omitSamplingParams = _shouldOmitGeminiSamplingParams(upstreamModelId);
    final gen = <String, dynamic>{
      if (!omitSamplingParams && temperature != null)
        'temperature': temperature,
      if (!omitSamplingParams && topP != null) 'topP': topP,
      if (maxTokens ?? defaultMaxOutputTokens case final resolvedMaxTokens?)
        'maxOutputTokens': resolvedMaxTokens,
      // Enable IMAGE+TEXT output modalities when model is configured to output images
      if (wantsImageOutput) 'responseModalities': ['TEXT', 'IMAGE'],
      if (isReasoning)
        ...() {
          final thinkingConfig = _googleThinkingConfig(
            upstreamModelId,
            thinkingBudget,
          );
          if (thinkingConfig.isEmpty) return const <String, dynamic>{};
          return {'thinkingConfig': thinkingConfig};
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
    final requestHeaders = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
    };
    if (config.vertexAI == true) {
      final token = await _maybeVertexAccessToken(config);
      if (token != null && token.isNotEmpty) {
        requestHeaders['Authorization'] = 'Bearer $token';
      }
      final proj = (config.projectId ?? '').trim();
      if (proj.isNotEmpty) requestHeaders['X-Goog-User-Project'] = proj;
    } else {
      final apiKey = _effectiveApiKey(config);
      if (apiKey.isNotEmpty) {
        requestHeaders['x-goog-api-key'] = apiKey;
      }
    }
    final headers = _customHeaders(
      config,
      modelId,
      baseHeaders: requestHeaders,
      assistantHeaders: extraHeaders,
    );
    request.headers.addAll(headers);
    final extra = _customBody(config, modelId, assistantBody: extraBody);
    if (extra.isNotEmpty) {
      body.addAll(extra);
    }
    body['contents'] = _googleApiContents(convo);
    request.body = jsonEncode(body);

    final resp = await client.send(request);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final errorBody = await resp.stream.bytesToString();
      throw HttpException('HTTP ${resp.statusCode}: $errorBody');
    }

    final sse = resp.stream.transform(utf8.decoder);
    final decoder = GoogleStreamDecoder(
      isGemini3: isGemini3,
      persistThoughtSigs: persistGeminiThoughtSigs,
      expectImage: expectImage,
      receivedImage: receivedImage,
      initialUsage: usage,
      citations: builtinCitations,
      sourceId: 'round-${streamRound++}',
    );
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

    Future<String> takeBufferedImageMarkdown() async {
      final pending = decoder.takeBufferedImage();
      if (pending == null) return '';
      final path = await AppDirectories.saveBase64Image(
        pending.mimeType,
        pending.data,
      );
      if (path == null || path.isEmpty) return '';
      final uri = SandboxPathResolver.canonicalize(path);
      final sb = StringBuffer()
        ..write('\n\n![image](')
        ..write(uri)
        ..write(')');
      if (pending.trailingText.isNotEmpty) {
        sb.write(pending.trailingText);
      }
      return sb.toString();
    }

    await for (final event in parseSseEventStrings(sse)) {
      final data = event.data;
      if (data.isEmpty) continue;
      // Gemini can deliver {"error":{code,message,status}}, a prompt-level
      // block, or a candidate-level content-filter finish in-band on a 2xx
      // stream; raise before the malformed-chunk guard below can swallow it.
      _throwIfInBandStreamError(data);
      _throwIfGeminiPromptBlocked(data);
      _throwIfGeminiCandidateBlocked(data);
      final decoded = decoder.accept(event);
      for (final remote in decoder.takePendingRemoteImages()) {
        try {
          final b64 = await _downloadRemoteAsBase64(client, config, remote.uri);
          for (final chunk in decoder.ingestImageData(
            remote.mimeType,
            b64,
            thoughtSigKey: remote.thoughtSigKey,
            thoughtSigVal: remote.thoughtSigVal,
          )) {
            yield await _sanitizeStreamChunk(chunk, sanitizeTextIfNeeded);
          }
        } catch (_) {}
      }
      for (final chunk in decoder.takeOrphanedTrailingText()) {
        yield await _sanitizeStreamChunk(chunk, sanitizeTextIfNeeded);
      }
      for (final chunk in decoded.chunks) {
        yield await _sanitizeStreamChunk(chunk, sanitizeTextIfNeeded);
        if (chunk is ToolCallEnd &&
            decoder.isClientFunctionCall(chunk.id) &&
            onToolCall != null) {
          final call = decoder.functionCallById(chunk.id)!;
          if (call.result.isEmpty) {
            final resText = await onToolCall(
              call.name,
              call.args,
              toolCallId: call.id,
            );
            call.result = resText;
            yield* emitToolResults(
              [
                ToolResultInfo(
                  id: call.id,
                  name: call.name,
                  arguments: call.args,
                  content: resText,
                  metadata: {
                    'google': {
                      'part': call.part,
                      if (call.thoughtSigKey != null &&
                          call.thoughtSigVal != null)
                        'thoughtSigKey': call.thoughtSigKey,
                      if (call.thoughtSigKey != null &&
                          call.thoughtSigVal != null)
                        'thoughtSigVal': call.thoughtSigVal,
                    },
                  },
                ),
              ],
              usage: decoder.usage,
              totalTokens: decoder.usage?.totalTokens ?? 0,
            );
          }
        }
      }
      if (decoded.completed || decoder.canFinishNow) break;
    }
    for (final chunk in decoder.onClosed()) {
      yield await _sanitizeStreamChunk(chunk, sanitizeTextIfNeeded);
    }

    receivedImage = decoder.receivedImage;
    usage = decoder.usage ?? usage;
    totalTokens = usage?.totalTokens ?? totalTokens;
    final calls = [
      for (final call in decoder.functionCalls)
        <String, dynamic>{
          'id': call.id,
          'apiId': call.apiId,
          'name': call.name,
          'args': call.args,
          'result': call.result,
          'thoughtSigKey': call.thoughtSigKey,
          'thoughtSigVal': call.thoughtSigVal,
          'part': call.part,
        },
    ];
    final roundModelParts = decoder.roundModelParts;
    final retryMalformedResponse = decoder.retryMalformedResponse;
    final responseTextThoughtSigKey = decoder.textThoughtSigKey;
    final responseTextThoughtSigVal = decoder.textThoughtSigVal;
    final responseImageThoughtSigs = decoder.imageThoughtSigs;

    if (retryMalformedResponse) {
      // This is a transient model-generation failure, so retry the unchanged
      // round once without adding the malformed candidate to conversation.
      if (malformedResponseRetryCount == 0) {
        malformedResponseRetryCount++;
        continue;
      }
      throw const HttpException(
        'Gemini response generation failed (MALFORMED_RESPONSE)',
      );
    }

    // Flush any buffered inline image that never became Image* events.
    if (!decoder.emittedImageEvents) {
      final pendingImage = await takeBufferedImageMarkdown();
      if (pendingImage.isNotEmpty) {
        final sanitized = await sanitizeTextIfNeeded(pendingImage);
        yield* emitDelta(
          content: sanitized,
          usage: usage,
          totalTokens: totalTokens,
        );
      }
    }

    if (calls.isEmpty) {
      // No tool calls; this round finished. Citations already left the decoder.
      if (persistGeminiThoughtSigs) {
        final metaComment = _buildGeminiThoughtSigComment(
          textKey: responseTextThoughtSigKey,
          textValue: responseTextThoughtSigVal,
          imageSigs: responseImageThoughtSigs,
        );
        if (metaComment.isNotEmpty) {
          yield* emitDelta(
            content: metaComment,
            usage: usage,
            totalTokens: totalTokens,
          );
        }
      }
      yield* emitDone(usage: usage, totalTokens: totalTokens);
      return;
    }

    // Append model functionCall(s) and user functionResponse(s) to conversation, then loop
    malformedResponseRetryCount = 0;
    if (isGemini3) {
      // Gemini 3: preserve the original model parts order exactly.
      convo.add({'role': 'model', 'parts': roundModelParts});

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
          'functionResponse': {
            'name': name,
            'response': responseObj,
            if (apiId != null) 'id': apiId,
          },
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
