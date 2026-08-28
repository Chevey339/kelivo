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

/// Anthropic rejects an empty text block, and dropping `content` altogether
/// leaves the tool call unanswered, which reads to the model as a malformed
/// turn. A tool that produced nothing gets an explicit placeholder instead.
String claudeToolResultContent(String result) =>
    result.trim().isEmpty ? '(no output)' : result;

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
        ..['role'] = role.isEmpty ? 'user' : role,
    );
  }

  // Transform last user message to include images per Anthropic schema
  final initialMessages = <Map<String, dynamic>>[];
  final pendingToolResults = <Map<String, dynamic>>[];

  /// Emits the pending results as one `user` message, restricted to [only]
  /// when given: each response of a turn is answered by the results of the
  /// client calls it declared, so they cannot all be flushed at once.
  /// Returns whether a message was emitted.
  bool flushPendingToolResults({Set<String>? only}) {
    final taken = only == null
        ? List<Map<String, dynamic>>.from(pendingToolResults)
        : [
            for (final result in pendingToolResults)
              if (only.contains((result['tool_use_id'] ?? '').toString()))
                result,
          ];
    if (taken.isEmpty) return false;
    pendingToolResults.removeWhere(taken.contains);
    initialMessages.add({'role': 'user', 'content': taken});
    return true;
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

  Set<String> toolUseIdsInBlocks(
    Iterable<Map<String, dynamic>> blocks, {
    Set<String> types = const {'tool_use', 'server_tool_use'},
  }) {
    return blocks
        .where((block) => types.contains(block['type']))
        .map((block) => (block['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  String joinedTextOfBlocks(Iterable<Map<String, dynamic>> blocks) {
    return blocks
        .where((block) => block['type'] == 'text')
        .map((block) => (block['text'] ?? '').toString())
        .join();
  }

  Map<String, dynamic>? assistantBlockForClaudeRequest(Map block) {
    final type = (block['type'] ?? '').toString();
    if (skipRedactedThinkingBlocks && type == 'redacted_thinking') {
      return null;
    }
    // Only Anthropic runs a server tool or decrypts what one returned, so
    // everywhere else its blocks are dropped and the call replays as the
    // synthesised client pair, exactly as it did before these tools existed.
    if (!replayServerToolBlocks &&
        (type == 'server_tool_use' || type.endsWith('_tool_result'))) {
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

  /// Two cards of one response carry identical copies of its block list, and
  /// only a call or a result identifies itself; everything else is compared
  /// whole.
  String replayBlockKey(Map<String, dynamic> block) {
    final type = (block['type'] ?? '').toString();
    if (type == 'tool_use' || type == 'server_tool_use') {
      final id = (block['id'] ?? '').toString();
      if (id.isNotEmpty) return 'call:$id';
    } else if (type.endsWith('_tool_result')) {
      final id = (block['tool_use_id'] ?? '').toString();
      if (id.isNotEmpty) return 'result:$id';
    }
    return 'block:${jsonEncode(block)}';
  }

  /// Order the responses of one turn by their hand-off: a response opening
  /// with the result of a `server_tool_use` it does not hold itself continues
  /// the response that does.
  List<List<Map<String, dynamic>>> responsesInHandOffOrder(
    List<List<Map<String, dynamic>>> responses,
  ) {
    if (responses.length < 2) return responses;
    final callOwner = <String, int>{};
    for (var i = 0; i < responses.length; i++) {
      for (final block in responses[i]) {
        if (block['type'] != 'server_tool_use') continue;
        final id = (block['id'] ?? '').toString();
        if (id.isNotEmpty) callOwner.putIfAbsent(id, () => i);
      }
    }
    // A turn spans a couple of responses at most, so relaxing the ranks in
    // place is cheaper than building the graph they describe.
    final rank = List<int>.filled(responses.length, 0);
    for (var pass = 0; pass < responses.length; pass++) {
      var moved = false;
      for (var i = 0; i < responses.length; i++) {
        for (final block in responses[i]) {
          if (!(block['type'] ?? '').toString().endsWith('_tool_result')) {
            continue;
          }
          final owner = callOwner[(block['tool_use_id'] ?? '').toString()];
          if (owner == null || owner == i || rank[i] > rank[owner]) continue;
          rank[i] = rank[owner] + 1;
          moved = true;
        }
      }
      if (!moved) break;
    }
    final order = [for (var i = 0; i < responses.length; i++) i]
      ..sort(
        (a, b) =>
            rank[a] == rank[b] ? a.compareTo(b) : rank[a].compareTo(rank[b]),
      );
    return [for (final i in order) responses[i]];
  }

  /// A turn that starts a hosted tool and a client tool at once is split in
  /// two: the client result has to be answered before the hosted one arrives,
  /// so the API closes the first response with the call still open and opens
  /// the next with its result. Each card kept the blocks of the response it
  /// appeared in. The responses come back in hand-off order but stay apart:
  /// the protocol replays each as its own assistant message, with the client
  /// `tool_result` between them, so they must not be flattened into one.
  List<List<Map<String, dynamic>>>? anthropicResponsesFromToolCallMetadata(
    List toolCalls,
  ) {
    final expectedIds = toolCalls
        .whereType<Map>()
        .map((tc) => (tc['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();

    final responses = <List<Map<String, dynamic>>>[];
    final seenResponses = <String>{};
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
      if (candidate.isEmpty) continue;
      if (!seenResponses.add(jsonEncode(candidate))) continue;
      responses.add(candidate);
    }
    if (responses.isEmpty) return null;

    final ordered = <List<Map<String, dynamic>>>[];
    final seenBlocks = <String>{};
    final callsSoFar = <String>{};
    for (final response in responsesInHandOffOrder(responses)) {
      // Only a response opening with the result of a call an earlier one left
      // running is the far side of a hand-off. Anything else — a snapshot cut
      // mid-stream, a card of the same response — is more of the same one.
      final opener = response.first;
      final continues =
          (opener['type'] ?? '').toString().endsWith('_tool_result') &&
          callsSoFar.contains((opener['tool_use_id'] ?? '').toString());
      final blocks = [
        for (final block in response)
          if (seenBlocks.add(replayBlockKey(block))) block,
      ];
      callsSoFar.addAll(toolUseIdsInBlocks(blocks));
      if (blocks.isEmpty) continue;
      if (continues || ordered.isEmpty) {
        ordered.add(blocks);
      } else {
        ordered.last.addAll(blocks);
      }
    }
    if (expectedIds.isEmpty) return ordered;

    final presentIds = toolUseIdsInBlocks([
      for (final response in ordered) ...response,
    ]);
    if (presentIds.containsAll(expectedIds)) return ordered;

    // A call the cards lost belongs to the response that opened the turn.
    for (final tc in toolCalls.whereType<Map>()) {
      final block = toolUseBlockFromToolCall(tc);
      if (block == null) continue;
      final id = (block['id'] ?? '').toString();
      if (presentIds.contains(id)) continue;
      ordered.first.add(block);
      presentIds.add(id);
    }
    return ordered;
  }

  // Server tools replayed as their own blocks already carry their result; the
  // synthesised `tool` message for the same id would be an orphan tool_result.
  final replayedServerToolIds = <String>{};

  // The assistant message just replayed from its own blocks, if any. Those
  // blocks cover the whole turn, the text written after the tool included, so
  // the plain assistant message that follows repeats it — and with the `tool`
  // message suppressed above there is nothing left to separate the two. The
  // text is the turn's, every response of it joined: the persisted message
  // aggregates them all, so the message alone would not match it.
  ({Map<String, dynamic> message, String text})? replayedTurn;

  // The later responses of a replayed turn, each with the client calls that
  // have to be answered before it: the API only produced the response once
  // their `tool_result` had been sent, so it is emitted once that has been.
  final deferredResponses =
      <({List<Map<String, dynamic>> blocks, Set<String> awaitedClientIds})>[];

  for (int i = 0; i < nonSystemMessages.length; i++) {
    final m = nonSystemMessages[i];
    final isLast = i == nonSystemMessages.length - 1;
    final role = (m['role'] ?? 'user').toString();
    if (role == 'tool') {
      final id = (m['tool_call_id'] ?? '').toString();
      if (id.isNotEmpty && !replayedServerToolIds.contains(id)) {
        pendingToolResults.add({
          'type': 'tool_result',
          'tool_use_id': id,
          'content': claudeToolResultContent((m['content'] ?? '').toString()),
        });
      }
      continue;
    }
    // Client tool results land between the two as a user message, so only a
    // turn left adjacent can be folded — or the text of the responses those
    // results deferred, which become the adjacent turn below. Media keeps the
    // structured path below, so only a plain-text message folds.
    final foldsIntoReplayedTurn =
        (pendingToolResults.isEmpty || deferredResponses.isNotEmpty) &&
        role == 'assistant' &&
        m['tool_calls'] is! List &&
        parseInternalMediaRefs(m[multimodalInternalMediaPathsKey]).isEmpty &&
        !shouldParseMarkdownImages(
          (m['content'] ?? '').toString(),
          skipImageParsing: skipImageParsing,
        );
    var turn = replayedTurn;
    replayedTurn = null;
    if (deferredResponses.isNotEmpty) {
      // A result no response claims — the cards lost which one declared it —
      // still belongs before them all, so it goes out with the first group.
      final claimed = <String>{
        for (final deferred in deferredResponses) ...deferred.awaitedClientIds,
      };
      final unclaimed = {
        for (final result in pendingToolResults)
          if (!claimed.contains((result['tool_use_id'] ?? '').toString()))
            (result['tool_use_id'] ?? '').toString(),
      };
      for (final deferred in deferredResponses) {
        // Roles alternate, so each response that a client result deferred
        // becomes its own assistant message just after those results.
        final answered = flushPendingToolResults(
          only: {...deferred.awaitedClientIds, ...unclaimed},
        );
        unclaimed.clear();
        final text = (turn?.text ?? '') + joinedTextOfBlocks(deferred.blocks);
        if (answered || turn == null) {
          final message = <String, dynamic>{
            'role': 'assistant',
            'content': deferred.blocks,
          };
          initialMessages.add(message);
          turn = (message: message, text: text);
        } else {
          // No client result in between: the split was only ever in the cards.
          (turn.message['content'] as List).addAll(deferred.blocks);
          turn = (message: turn.message, text: text);
        }
      }
      deferredResponses.clear();
    }
    flushPendingToolResults();

    if (turn != null && foldsIntoReplayedTurn) {
      final blocks = (turn.message['content'] as List)
          .cast<Map<String, dynamic>>();
      // The persisted message aggregates the text of every response of the
      // turn, so compare against the turn's join — a response of it that wrote
      // nothing did not write what an earlier one did.
      final joined = turn.text.trim();
      final text = (m['content'] ?? '').toString().trim();
      if (joined.isEmpty) {
        // The turn wrote nothing around its tools, so the message carries all
        // of its text.
        if (text.isNotEmpty) blocks.add({'type': 'text', 'text': text});
      } else if (text.startsWith(joined)) {
        // A snapshot taken mid-stream can stop short of the finished text.
        final rest = text.substring(joined.length).trim();
        if (rest.isNotEmpty) blocks.add({'type': 'text', 'text': rest});
      }
      // Any other disagreement leaves the blocks as they are: they are what
      // the API itself produced, and appending the message on top would send
      // the same turn twice — which is what the roles had to alternate for.
      continue;
    }

    if (role == 'assistant' && m['tool_calls'] is List) {
      final toolCalls = m['tool_calls'] as List;
      final responses =
          anthropicResponsesFromToolCallMetadata(toolCalls) ??
          <List<Map<String, dynamic>>>[];
      final hadReplayBlocks = responses.isNotEmpty;
      final resolvedServerToolIds = <String>{};
      for (final block in responses.expand((response) => response)) {
        final type = (block['type'] ?? '').toString();
        if (type == 'server_tool_use') {
          final sid = (block['id'] ?? '').toString();
          if (sid.isNotEmpty) replayedServerToolIds.add(sid);
        } else if (type.endsWith('_tool_result')) {
          resolvedServerToolIds.add((block['tool_use_id'] ?? '').toString());
        }
      }
      // A `server_tool_use` whose result block never arrived — the stream was
      // stopped or dropped between the two — would replay as a call with no
      // output, which the API rejects. Drop the call; its `tool` message is
      // already suppressed by [replayedServerToolIds].
      for (final response in responses) {
        response.removeWhere(
          (block) =>
              block['type'] == 'server_tool_use' &&
              !resolvedServerToolIds.contains((block['id'] ?? '').toString()),
        );
      }
      responses.removeWhere((response) => response.isEmpty);
      final blocks = responses.isEmpty
          ? <Map<String, dynamic>>[]
          : responses.removeAt(0);
      var awaited = toolUseIdsInBlocks(blocks, types: const {'tool_use'});
      for (final response in responses) {
        deferredResponses.add((blocks: response, awaitedClientIds: awaited));
        awaited = toolUseIdsInBlocks(response, types: const {'tool_use'});
      }
      if (!hadReplayBlocks) {
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
        final message = <String, dynamic>{
          'role': 'assistant',
          'content': blocks,
        };
        initialMessages.add(message);
        if (hadReplayBlocks) {
          replayedTurn = (message: message, text: joinedTextOfBlocks(blocks));
        }
      }
      continue;
    }
    final raw = (m['content'] ?? '').toString();
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
        skipImageParsing: skipImageParsing,
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
  // History cut off at the client result leaves the later responses with no
  // place to go: replayed here they would prefill the answer, and a hosted
  // call whose result is only in them would be an open call. Drop both and let
  // the model run the tool again.
  if (deferredResponses.isNotEmpty) {
    final deferredResults = <String>{
      for (final deferred in deferredResponses)
        for (final block in deferred.blocks)
          if ((block['type'] ?? '').toString().endsWith('_tool_result'))
            (block['tool_use_id'] ?? '').toString(),
    };
    deferredResponses.clear();
    final turn = replayedTurn;
    if (turn != null) {
      final blocks = (turn.message['content'] as List)
          .cast<Map<String, dynamic>>();
      blocks.removeWhere(
        (block) =>
            block['type'] == 'server_tool_use' &&
            deferredResults.contains((block['id'] ?? '').toString()),
      );
      if (blocks.isEmpty) initialMessages.remove(turn.message);
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
            totalUsage = (totalUsage ?? const TokenUsage()).accumulate(
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
          } else if (type == 'server_tool_use' ||
              type.endsWith('_tool_result')) {
            // The hosted call and its result are the model's own turn: a
            // continuation round that drops either is rejected.
            try {
              assistantBlocks.add(
                Map<String, dynamic>.from(it.cast<String, dynamic>()),
              );
            } catch (_) {}
          }
        }
        // The continuation round sends these, so they go through the same
        // sanitising as replayed history; the metadata below stays whole.
        lastAssistantBlocks = assistantBlocksForClaudeRequest(assistantBlocks);
        lastText = buf.toString();
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
        initialUsage: totalUsage,
        serverToolNames: declaredServerToolNames,
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

      totalUsage = usage ?? totalUsage;

      // The continuation round sends these as they are, so they go through the
      // same sanitising as replayed history — the persisted copy below stays
      // whole either way.
      lastAssistantBlocks = assistantBlocksForClaudeRequest(assistantBlocks);
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
    finish: () => emitDone(
      ids: StreamChunkIds('finish'),
      content: lastText,
      usage: totalUsage,
      totalTokens: totalUsage?.totalTokens ?? 0,
    ),
    usageOf: () => totalUsage,
  );
}
