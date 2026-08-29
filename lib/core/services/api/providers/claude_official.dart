import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../models/token_usage.dart';
import '../../../providers/model_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../utils/multimodal_input_utils.dart';
import '../../../../utils/mcp_structured_image.dart';
import '../builtin_tools.dart';
import '../chat_api_helpers.dart';
import '../generation/tool_loop_runner.dart';
import '../stream/sse_framing.dart';
import '../stream/stream_chunk.dart';
import '../stream/stream_chunk_emit.dart';
import '../stream/stream_chunk_ids.dart';
import 'claude/claude_container.dart';
import 'claude/claude_decoder.dart';
import 'claude/claude_files.dart';
import 'claude/claude_history.dart';

export 'claude/claude_history.dart'
    show
        normalizeClaudeImageMime,
        isClaudeSupportedImageMime,
        claudeToolResultContent;

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
  bool builtInSearchOnly = false,
  bool skipImageParsing = false,
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
  final replayServerToolBlocks = BuiltInToolsHelper.isOfficialAnthropicEndpoint(
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
        ..remove(multimodalInternalGeminiThoughtSignatureKey)
        ..['role'] = role.isEmpty ? 'user' : role,
    );
  }

  final history = ClaudeHistory(
    replayServerToolBlocks: replayServerToolBlocks,
    skipRedactedThinkingBlocks: skipRedactedThinkingBlocks,
    skipImageParsing: skipImageParsing,
    userImagePaths: userImagePaths,
  );
  final initialMessages = await history.build(nonSystemMessages);

  // Map OpenAI-style tools to Anthropic custom tools (client tools)
  List<Map<String, dynamic>>? anthropicTools;
  if (tools != null && tools.isNotEmpty) {
    anthropicTools = [];
    for (final t in tools) {
      final fn = (t['function'] as Map<String, dynamic>?);
      if (fn == null) continue;
      final name = BuiltInToolsHelper.claimedToolName(t);
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
  // Anthropic rejects a `tools` array holding two entries of the same name, and
  // an MCP server is free to expose one called `web_search`, `web_fetch`, or
  // `code_execution`. The client tools are the ones the caller asked for by
  // name, so a hosted entry that collides with one is dropped instead of sent
  // alongside it.
  final claimedToolNames = <String>{
    for (final t in allTools) (t['name'] ?? '').toString(),
  };
  void addHostedTool(Map<String, dynamic> tool) {
    if (claimedToolNames.add((tool['name'] ?? '').toString())) {
      allTools.add(tool);
    }
  }

  if (tools != null && tools.isNotEmpty) {
    for (final t in tools) {
      final type = (t['type'] ?? '').toString();
      if (type.startsWith('web_search_')) {
        addHostedTool(t);
      }
    }
  }
  // Utility calls (title / summary generation) only want search injected; a
  // hosted fetch or container run on one of those is both off-contract and
  // billed.
  final builtIns = builtInSearchOnly
      ? builtInTools(
          config,
          modelId,
        ).where((name) => name == BuiltInToolNames.search).toSet()
      : builtInTools(config, modelId);
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
    addHostedTool(entry);
  }
  for (final entry in BuiltInToolsHelper.claudeServerToolEntries(
    cfg: config,
    modelId: modelId,
    enabled: builtIns,
  )) {
    addHostedTool(entry);
  }

  // Client tools are declared by `input_schema`, the Anthropic-hosted ones by
  // `type`. The decoder needs the latter to recognise a downgraded block.
  final declaredServerToolNames = <String>{
    for (final t in allTools)
      if (t['input_schema'] == null && (t['type'] ?? '').toString().isNotEmpty)
        (t['name'] ?? '').toString(),
  }..remove('');
  // The `container` parameter is only accepted alongside the tool that uses it.
  final hasCodeExecution = declaredServerToolNames.contains('code_execution');
  // The data files the message builder left out of the prompt, on the
  // strength of the same predicate, go up to the container instead. The tool
  // has to be in this request for a `container_upload` to be accepted, and a
  // utility call never declares it.
  final uploadsDataFiles =
      hasCodeExecution &&
      BuiltInToolsHelper.sendsDataFilesToSandbox(
        cfg: config,
        modelId: modelId,
        clientTools: tools ?? const [],
      );

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
  // Carried through every round of this turn — after a client tool, after a
  // pause — and stored after each so the next turn resumes in it too.
  ClaudeContainerRef? container = history.storedContainer;
  // Every response of this turn so far, stored against the message after each
  // so the turn replays as the responses it was. A turn without a tool call
  // replays from its text alone and stores nothing.
  final turnResponses = <List<Map<String, dynamic>>>[];
  Stream<StreamChunk> recordTurn(List<Map<String, dynamic>> response) async* {
    turnResponses.add(response);
    if (toolUseIdsInBlocks(turnResponses.expand((b) => b)).isNotEmpty) {
      yield ProviderArtifact(
        kind: claudeTurnArtifactKind,
        payload: encodeClaudeTurn(turnResponses),
      );
    }
    // Stored against this turn's message so the next turn can resume in the
    // same container — now rather than at the end, which a cancelled turn
    // never reaches.
    if (hasCodeExecution && container != null) {
      yield ProviderArtifact(
        kind: claudeContainerArtifactKind,
        payload: container!.encode(),
      );
    }
  }

  final downloadedFileIds = <String>{};
  var lastStreamResults = <Map<String, dynamic>>[];
  final nonStreamText = StringBuffer();
  var pauseTurn = false;

  // A container the conversation goes on using gets the files it has not
  // seen; a fresh one — none stored, or the stored one found expired — gets
  // every file the user attached. Either way the uploads ride the last user
  // message, and each file goes once. A file this turn is about that cannot
  // go up fails the turn before any request is made; an earlier turn's is
  // reported in its place instead, so one lost attachment from long ago does
  // not end the conversation.
  final uploadedPaths = <String>{};
  final turnFileUris = {for (final doc in history.turnDataFiles) doc.uri};
  Future<void> uploadDataFiles() async {
    if (!uploadsDataFiles) return;
    final blocks = <Map<String, dynamic>>[];
    for (final doc
        in container == null ? history.dataFiles : history.unseenDataFiles) {
      if (!uploadedPaths.add(doc.uri)) continue;
      try {
        final fileId = await uploadClaudeFile(
          client: client,
          base: base,
          headers: baseHeaders,
          path: doc.uri,
          name: doc.name,
          mime: doc.mime,
        );
        blocks.add({'type': 'container_upload', 'file_id': fileId});
      } on ClaudeFileUploadException catch (e) {
        if (turnFileUris.contains(doc.uri)) rethrow;
        blocks.add({'type': 'text', 'text': e.toString()});
      }
    }
    if (blocks.isEmpty) return;
    final last = convo.last;
    final content = last['content'];
    convo[convo.length - 1] = {
      ...last,
      'content': [
        if (content is List)
          ...content
        else if ((content ?? '').toString().isNotEmpty)
          {'type': 'text', 'text': content.toString()},
        ...blocks,
      ],
    };
  }

  await uploadDataFiles();

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
        if (hasCodeExecution && container != null) 'container': container!.id,
      };
      final extraClaude = customBody(config, modelId, assistantBody: extraBody);
      if (extraClaude.isNotEmpty) {
        body.addAll(extraClaude);
      }

      http.Request buildRequest() {
        final request = http.Request('POST', url);
        request.headers.addAll(baseHeaders);
        request.body = jsonEncode(body);
        return request;
      }

      var response = await client.send(buildRequest());
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errorBody = await response.stream.bytesToString();
        // A stored container can have expired since the last turn; forget
        // it and let this round start a fresh one.
        final staleContainer =
            body.containsKey('container') &&
            isClaudeStaleContainerError(response.statusCode, errorBody);
        if (!staleContainer) {
          throw HttpException('HTTP ${response.statusCode}: $errorBody');
        }
        container = null;
        body.remove('container');
        await uploadDataFiles();
        response = await client.send(buildRequest());
        if (response.statusCode < 200 || response.statusCode >= 300) {
          final retryBody = await response.stream.bytesToString();
          throw HttpException('HTTP ${response.statusCode}: $retryBody');
        }
      }

      pendingCalls = [];
      lastStreamResults = [];
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
            totalUsage = (totalUsage ?? const TokenUsage()).accumulate(
              claudeUsageFromMap(u),
            );
          }
        } catch (_) {}
        container =
            ClaudeContainerRef.fromResponse(obj['container']) ?? container;
        final content = (obj['content'] as List?) ?? const <dynamic>[];
        final List<Map<String, dynamic>> assistantBlocks =
            <Map<String, dynamic>>[];
        final Map<String, Map<String, dynamic>> toolUses =
            <String, Map<String, dynamic>>{}; // id -> {name,args}
        for (final it in content) {
          if (it is! Map) continue;
          final type = (it['type'] ?? '').toString();
          if (type == 'text') {
            final t = (it['text'] ?? '').toString();
            if (t.isNotEmpty) {
              assistantBlocks.add({'type': 'text', 'text': t});
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
          } else if (type == 'server_tool_use' ||
              type.endsWith('_tool_result')) {
            // The hosted call and its result are the model's own turn: a
            // continuation round that drops either is rejected.
            try {
              assistantBlocks.add(
                Map<String, dynamic>.from(it.cast<String, dynamic>()),
              );
            } catch (_) {}
            for (final fileId in claudeGeneratedFileIds(it['content'])) {
              if (!downloadedFileIds.add(fileId)) continue;
              final file = await downloadClaudeGeneratedFile(
                client: client,
                base: base,
                headers: baseHeaders,
                fileId: fileId,
              );
              if (file != null) yield file;
            }
          }
        }
        // The continuation round sends these, so they go through the same
        // sanitising as replayed history; the stored copy stays whole.
        lastAssistantBlocks = history.sanitize(assistantBlocks);
        nonStreamText.write(joinedTextOfBlocks(assistantBlocks));
        final decoder = ClaudeStreamDecoder(
          skipRedactedThinkingBlocks: skipRedactedThinkingBlocks,
          serverToolNames: declaredServerToolNames,
          sourceId: 'round-${streamRound++}',
        );
        for (final chunk in decoder.decodeCompleteServerTools(
          assistantBlocks,
        )) {
          yield chunk;
        }
        yield* recordTurn(assistantBlocks);
        if (toolUses.isEmpty) {
          // A hosted tool that ran past the turn limit asks to be resumed,
          // with no client tool to answer first.
          pauseTurn = (obj['stop_reason'] ?? '').toString() == 'pause_turn';
        }
        if (toolUses.isNotEmpty && onToolCall != null) {
          pendingCalls = [
            for (final e in toolUses.entries)
              emitToolCall(
                id: e.key,
                name: (e.value['name'] ?? '').toString(),
                arguments: (e.value['args'] as Map<String, dynamic>),
              ),
          ];
        }
        return;
      }

      final sse = response.stream.transform(utf8.decoder);
      final decoder = ClaudeStreamDecoder(
        skipRedactedThinkingBlocks: skipRedactedThinkingBlocks,
        initialUsage: totalUsage,
        serverToolNames: declaredServerToolNames,
        sourceId: 'round-${streamRound++}',
      );
      final executedToolIds = <String>{};
      // Downloads run alongside the stream: awaiting one here would leave the
      // SSE events unread, and the text after the tool frozen, for as long as
      // the file takes.
      final downloads = <Future<GeneratedFile?>>[];
      var streamCompleted = false;

      try {
        await for (final event in parseSseEventStrings(sse)) {
          throwIfInBandStreamError(event.data);
          final decoded = decoder.accept(event);
          for (final chunk in decoded.chunks) {
            yield chunk;
            if (chunk is ServerToolEnd) {
              // Code execution reports what it wrote as ids the card cannot do
              // anything with, so the bytes are fetched here and the message
              // carries the file itself.
              for (final fileId in claudeGeneratedFileIds(chunk.output)) {
                if (!downloadedFileIds.add(fileId)) continue;
                downloads.add(
                  downloadClaudeGeneratedFile(
                    client: client,
                    base: base,
                    headers: baseHeaders,
                    fileId: fileId,
                  ),
                );
              }
            }
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
        streamCompleted = true;
      } finally {
        // A turn that stops here — cancelled, or on an in-band error — still
        // sees its downloads out rather than closing the client under them;
        // what they wrote has no message to go to, so it is removed again.
        final files = await Future.wait(downloads);
        if (!streamCompleted) {
          for (final file in files) {
            if (file != null) await discardClaudeGeneratedFile(file);
          }
        }
      }
      for (final chunk in decoder.onClosed()) {
        yield chunk;
      }
      for (final download in downloads) {
        final file = await download;
        if (file != null) yield file;
      }

      final usage = decoder.usage;
      final assistantBlocks = decoder.assistantBlocks;
      final lastStopReason = decoder.lastStopReason;
      final toolResultsContent = decoder.toolResults;

      totalUsage = usage ?? totalUsage;
      container = decoder.container ?? container;

      // The continuation round sends these as they are, so they go through the
      // same sanitising as replayed history — the stored copy stays whole.
      lastAssistantBlocks = history.sanitize(assistantBlocks);
      yield* recordTurn(assistantBlocks);
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
          ),
      ];
      for (final tool in decoder.clientTools.values) {
        var res = toolResultsContent[tool.id] ?? '';
        if (res.isEmpty && onToolCall != null) {
          res = ClientToolResult.fromHandler(
            await onToolCall(
              tool.name,
              tool.decodedArguments,
              toolCallId: tool.id,
            ),
          ).content;
        }
        lastStreamResults.add({
          'type': 'tool_result',
          'tool_use_id': tool.id,
          'content': claudeToolResultContent(res),
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
                  'content': claudeToolResultContent(item.content),
                },
            ];
      convo = [
        ...convo,
        {'role': 'assistant', 'content': lastAssistantBlocks},
        {'role': 'user', 'content': results},
      ];
    },
    finish: () async* {
      yield* emitDone(
        ids: StreamChunkIds('finish'),
        content: nonStreamText.toString(),
        usage: totalUsage,
        totalTokens: totalUsage?.totalTokens ?? 0,
      );
    },
    usageOf: () => totalUsage,
  );
}
