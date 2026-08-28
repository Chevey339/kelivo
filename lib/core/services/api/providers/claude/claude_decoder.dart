import 'dart:convert';

import '../../../../../utils/utf16_safe_cut.dart';

import '../../../../models/token_usage.dart';
import '../../stream/sse_event.dart';
import '../../stream/stream_chunk.dart';
import '../../stream/stream_chunk_decoder.dart';
import '../../stream/stream_chunk_ids.dart';

/// Stateful Claude Messages SSE decoder. One instance per HTTP response.
class ClaudeStreamDecoder implements StreamChunkDecoder {
  ClaudeStreamDecoder({
    this.skipRedactedThinkingBlocks = false,
    this.initialUsage,
    this.serverToolNames = const <String>{},
    String sourceId = 'stream',
  }) : _ids = StreamChunkIds(sourceId);

  final bool skipRedactedThinkingBlocks;
  final TokenUsage? initialUsage;

  /// Tool names this request declared as Anthropic-hosted server tools.
  final Set<String> serverToolNames;
  final StreamChunkIds _ids;

  final List<Map<String, dynamic>> assistantBlocks = <Map<String, dynamic>>[];
  final Map<String, ClaudeClientTool> clientTools =
      <String, ClaudeClientTool>{};
  final Map<String, String> toolResults = <String, String>{};

  TokenUsage? _round;

  TokenUsage? get usage {
    if (_round == null) return initialUsage;
    return (initialUsage ?? const TokenUsage()).accumulate(_round!);
  }

  String? lastStopReason;
  bool messageStopped = false;

  final Map<int, String> _clientIndexToId = <int, String>{};
  final Map<int, String> _serverIndexToId = <int, String>{};
  final Map<String, StringBuffer> _serverArgs = <String, StringBuffer>{};

  /// Each `server_tool_use` block already appended to [assistantBlocks], so its
  /// streamed input can be filled in once the block closes.
  final Map<String, Map<String, dynamic>> _serverBlocks =
      <String, Map<String, dynamic>>{};
  final Map<String, String> _serverToolNames = <String, String>{};
  final Set<String> _serverToolStarted = <String>{};
  final Set<String> _serverToolEnded = <String>{};
  final Set<String> _clientToolEnded = <String>{};
  final Map<int, int> _thinkingBlockIndex = <int, int>{};
  final Map<int, StringBuffer> _thinkingText = <int, StringBuffer>{};
  final Map<int, StringBuffer> _thinkingSig = <int, StringBuffer>{};
  final Map<int, int> _redactedBlockIndex = <int, int>{};
  final Map<int, StringBuffer> _redactedData = <int, StringBuffer>{};
  final StringBuffer _textBuf = StringBuffer();
  final List<Map<String, dynamic>> _citationItems = <Map<String, dynamic>>[];
  bool _closed = false;

  Map<String, dynamic> get _anthropicMetadata => <String, dynamic>{
    'anthropic': <String, dynamic>{'assistant_blocks': assistantBlocks},
  };

  bool isClientTool(String id) => clientTools.containsKey(id);

  void recordToolResult(String id, String content) {
    toolResults[id] = content;
  }

  @override
  DecodeResult accept(SseEvent event) {
    if (_closed || messageStopped) {
      return const DecodeResult(completed: true);
    }
    final data = event.data;
    if (data.isEmpty) return const DecodeResult();
    if (data == '[DONE]') {
      messageStopped = true;
      return const DecodeResult(completed: true);
    }

    late final Map<String, dynamic> obj;
    try {
      final decoded = jsonDecode(data);
      if (decoded is! Map) return const DecodeResult();
      obj = decoded.cast<String, dynamic>();
    } catch (error) {
      logDecoderParseError(
        provider: 'claude',
        eventType: event.event ?? 'json',
        error: error,
      );
      return const DecodeResult();
    }

    final type = (obj['type'] ?? event.event ?? '').toString();
    final chunks = <StreamChunk>[];

    try {
      switch (type) {
        case 'content_block_start':
          chunks.addAll(_onBlockStart(obj));
        case 'content_block_delta':
          chunks.addAll(_onBlockDelta(obj));
        case 'content_block_stop':
          chunks.addAll(_onBlockStop(obj));
        case 'message_start':
        case 'message_delta':
          chunks.addAll(_onMessageDelta(obj));
        case 'message_stop':
          _flushTextBlock();
          chunks.addAll(_flushCitations());
          messageStopped = true;
          return DecodeResult(chunks: chunks, completed: true);
      }
    } catch (error) {
      logDecoderParseError(provider: 'claude', eventType: type, error: error);
    }

    return DecodeResult(chunks: chunks, completed: messageStopped);
  }

  @override
  List<StreamChunk> onClosed() {
    if (_closed) return const <StreamChunk>[];
    _closed = true;
    _flushTextBlock();
    return <StreamChunk>[
      ..._flushCitations(),
      ..._closeOpenClientTools(),
      ..._closeOpenServerTools(),
    ];
  }

  List<StreamChunk> _onBlockStart(Map<String, dynamic> obj) {
    final cb = obj['content_block'];
    if (cb is! Map) return const <StreamChunk>[];
    final block = cb.cast<String, dynamic>();
    var kind = (block['type'] ?? '').toString();
    // Some Claude-compatible relays run a declared server tool upstream but
    // label its block `tool_use`. Executing that as a client tool answers with
    // an empty result, so keep it on the server-tool path.
    if (kind == 'tool_use' &&
        serverToolNames.contains((block['name'] ?? '').toString())) {
      kind = 'server_tool_use';
    }
    final idx = _parseIndex(obj['index']);
    final chunks = <StreamChunk>[];

    if (kind == 'thinking') {
      _flushTextBlock();
      if (idx != null) {
        assistantBlocks.add({
          'type': 'thinking',
          'thinking': '',
          'signature': '',
        });
        _thinkingBlockIndex[idx] = assistantBlocks.length - 1;
        _thinkingText[idx] = StringBuffer();
        _thinkingSig[idx] = StringBuffer();
        chunks.add(ReasoningStart(id: _ids.indexed('thinking', idx)));
      }
    } else if (kind == 'redacted_thinking') {
      _flushTextBlock();
      if (!skipRedactedThinkingBlocks && idx != null) {
        assistantBlocks.add({'type': 'redacted_thinking', 'data': ''});
        _redactedBlockIndex[idx] = assistantBlocks.length - 1;
        _redactedData[idx] = StringBuffer();
        chunks.add(ReasoningStart(id: _ids.indexed('redacted', idx)));
      }
    } else if (kind == 'tool_use') {
      _flushTextBlock();
      final id = (block['id'] ?? '').toString();
      final name = (block['name'] ?? '').toString();
      if (id.isNotEmpty) {
        clientTools.putIfAbsent(id, () => ClaudeClientTool(id: id, name: name));
        assistantBlocks.add({
          'type': 'tool_use',
          'id': id,
          'name': name,
          'input': <String, dynamic>{},
        });
        if (idx != null) _clientIndexToId[idx] = id;
        chunks.add(
          ToolCallStart(id: id, toolName: name, metadata: _anthropicMetadata),
        );
      }
    } else if (kind == 'server_tool_use') {
      _flushTextBlock();
      final id = (block['id'] ?? '').toString();
      final name = (block['name'] ?? '').toString();
      if (id.isNotEmpty && idx != null) {
        _serverIndexToId[idx] = id;
        _serverArgs[id] = StringBuffer();
      }
      if (id.isNotEmpty) {
        // Server tools have to be replayed as the blocks the API sent, not as
        // client tool calls: results only decrypt when their original block
        // comes back intact, and an unrun one only runs if it comes back at
        // all. Whether they may be sent is the request side's call.
        final serverBlock = <String, dynamic>{
          'type': 'server_tool_use',
          'id': id,
          'name': name,
          'input': <String, dynamic>{},
          if (block['caller'] != null) 'caller': block['caller'],
        };
        assistantBlocks.add(serverBlock);
        _serverBlocks[id] = serverBlock;
      }
      final display = _serverToolDisplayName(name);
      if (id.isNotEmpty && display != null) {
        _serverToolNames[id] = display;
        _serverToolStarted.add(id);
        chunks.add(ServerToolStart(id: id, toolName: display));
        chunks.add(
          ToolCallStart(
            id: id,
            toolName: display,
            metadata: _anthropicMetadata,
          ),
        );
      }
    } else if (kind.endsWith('_tool_result')) {
      _flushTextBlock();
      assistantBlocks.add(Map<String, dynamic>.from(block));
      // Result blocks are named `<tool>_tool_result`, so the display-name
      // allowlist decides which ones we surface; web search keeps its own
      // citation-aware mapping.
      final name = kind.substring(0, kind.length - '_tool_result'.length);
      if (name == 'web_search') {
        chunks.addAll(_webSearchResult(block));
      } else if (_serverToolDisplayName(name) != null) {
        chunks.addAll(_serverToolResult(block, name));
      }
    } else if (kind == 'text') {
      if (idx != null) {
        chunks.add(TextStart(_ids.indexed('text', idx)));
      }
    }
    return chunks;
  }

  List<StreamChunk> _onBlockDelta(Map<String, dynamic> obj) {
    final delta = obj['delta'];
    if (delta is! Map) return const <StreamChunk>[];
    final d = delta.cast<String, dynamic>();
    final kind = (d['type'] ?? '').toString();
    final idx = _parseIndex(obj['index']);
    final chunks = <StreamChunk>[];

    if (kind == 'text_delta') {
      final content = d['text'];
      if (content is String && content.isNotEmpty) {
        _textBuf.write(content);
        chunks.add(
          TextDelta(
            id: idx == null ? _ids.text() : _ids.indexed('text', idx),
            text: content,
          ),
        );
      }
    } else if (kind == 'thinking_delta') {
      final thinking = (d['thinking'] ?? d['text'] ?? '').toString();
      if (thinking.isNotEmpty) {
        chunks.add(
          ReasoningDelta(
            id: idx == null ? _ids.reasoning() : _ids.indexed('thinking', idx),
            text: thinking,
          ),
        );
        if (idx != null) _thinkingText[idx]?.write(thinking);
      }
    } else if (kind == 'signature_delta') {
      final sig = (d['signature'] ?? '').toString();
      if (sig.isNotEmpty && idx != null) _thinkingSig[idx]?.write(sig);
    } else if (kind == 'redacted_thinking_delta') {
      final data = (d['data'] ?? '').toString();
      if (data.isNotEmpty && idx != null) _redactedData[idx]?.write(data);
    } else if (kind == 'citations_delta') {
      final citation = d['citation'];
      if (citation is Map) {
        final url = (citation['url'] ?? '').toString();
        if (url.isNotEmpty) {
          _citationItems.add(<String, dynamic>{
            'index': _citationItems.length + 1,
            'title': (citation['title'] ?? '').toString(),
            'url': url,
            if ((citation['cited_text'] ?? '').toString().isNotEmpty)
              'cited_text': citation['cited_text'].toString(),
          });
        }
      }
    } else if (kind == 'tool_use_delta' || kind == 'input_json_delta') {
      final part = (d['partial_json'] ?? d['input'] ?? d['text'] ?? '')
          .toString();
      if (part.isEmpty || idx == null) return chunks;
      final clientId = _clientIndexToId[idx];
      if (clientId != null) {
        clientTools
            .putIfAbsent(clientId, () => ClaudeClientTool(id: clientId))
            .input
            .write(part);
        chunks.add(ToolCallDelta(id: clientId, inputDelta: part));
      } else {
        final serverId = _serverIndexToId[idx];
        if (serverId != null) {
          // The buffer feeds the replayed block, so it fills either way. The
          // card chunks only go out for a tool that opened one: a nameless
          // card is worse than none.
          _serverArgs.putIfAbsent(serverId, StringBuffer.new).write(part);
          if (_serverToolStarted.contains(serverId)) {
            chunks.add(ToolCallDelta(id: serverId, inputDelta: part));
          }
        }
      }
    }
    return chunks;
  }

  List<StreamChunk> _onBlockStop(Map<String, dynamic> obj) {
    final idx = _parseIndex(obj['index']);
    final chunks = <StreamChunk>[];

    if (idx != null && _thinkingBlockIndex.containsKey(idx)) {
      final pos = _thinkingBlockIndex.remove(idx)!;
      assistantBlocks[pos] = {
        'type': 'thinking',
        'thinking': _thinkingText.remove(idx)?.toString() ?? '',
        'signature': _thinkingSig.remove(idx)?.toString() ?? '',
      };
      chunks.add(ReasoningEnd(id: _ids.indexed('thinking', idx)));
    }
    if (idx != null && _redactedBlockIndex.containsKey(idx)) {
      final pos = _redactedBlockIndex.remove(idx)!;
      assistantBlocks[pos] = {
        'type': 'redacted_thinking',
        'data': _redactedData.remove(idx)?.toString() ?? '',
      };
      chunks.add(ReasoningEnd(id: _ids.indexed('redacted', idx)));
    }

    var id = (obj['content_block'] is Map)
        ? ((obj['content_block'] as Map)['id'] ?? obj['id'] ?? '').toString()
        : (obj['id'] ?? '').toString();
    if (id.isEmpty && idx != null) {
      id = _clientIndexToId[idx] ?? '';
    }

    if (id.isNotEmpty && clientTools.containsKey(id)) {
      final tool = clientTools[id]!;
      final args = tool.decodedArguments;
      _updateToolUseBlock(id, tool.name, args);
      _clientToolEnded.add(id);
      chunks.add(ToolCallEnd(id));
      return chunks;
    }

    if (idx != null && _serverIndexToId.containsKey(idx)) {
      final sid = _serverIndexToId[idx]!;
      _serverBlocks[sid]?['input'] = _serverArgsFor(sid);
      if (_serverToolStarted.contains(sid)) chunks.add(ToolCallEnd(sid));
    }
    return chunks;
  }

  List<StreamChunk> _onMessageDelta(Map<String, dynamic> obj) {
    final chunks = <StreamChunk>[];
    final rawUsage =
        obj['usage'] ??
        (obj['message'] is Map ? (obj['message'] as Map)['usage'] : null);
    if (rawUsage is Map) {
      final parsed = claudeUsageFromMap(rawUsage.cast<String, dynamic>());
      _round = (_round ?? const TokenUsage()).merge(parsed);
      chunks.add(Usage(usage!));
    }
    try {
      final delta = obj['delta'];
      final reason = (delta is Map)
          ? (delta['stop_reason'] ?? delta['stopReason'])
          : null;
      if (reason is String && reason.isNotEmpty) {
        lastStopReason = reason;
      }
    } catch (_) {}
    return chunks;
  }

  /// Tool name shown in the UI, or null for a server tool we don't surface.
  static String? _serverToolDisplayName(String name) {
    switch (name) {
      case 'web_search':
        return 'search_web';
      case 'web_fetch':
      case 'code_execution':
      case 'bash_code_execution':
      case 'text_editor_code_execution':
        return name;
      default:
        return null;
    }
  }

  /// Fetched pages and container output can be megabytes; the card and the
  /// persisted message only need a readable excerpt.
  static const _serverToolOutputLimit = 4000;

  static Object? _clipServerToolValue(Object? value) {
    if (value is String) {
      if (value.length <= _serverToolOutputLimit) return value;
      return '${truncateHeadUtf16Safe(value, _serverToolOutputLimit)}…';
    }
    if (value is List) {
      return value.map(_clipServerToolValue).toList();
    }
    if (value is Map) {
      return <String, dynamic>{
        for (final entry in value.entries)
          entry.key.toString(): _clipServerToolValue(entry.value),
      };
    }
    return value;
  }

  /// [blockToolName] is the tool the result block itself names, which is the
  /// only name a turn that runs a server tool left over from an earlier one
  /// carries: the API sends the result without repeating the request block.
  List<StreamChunk> _serverToolResult(
    Map<String, dynamic> block,
    String blockToolName,
  ) {
    final toolUseId = (block['tool_use_id'] ?? '').toString();
    final id = toolUseId.isEmpty ? _ids.next('server_tool') : toolUseId;
    if (!_serverToolEnded.add(id)) return const <StreamChunk>[];
    final toolName =
        _serverToolNames[id] ??
        _serverToolDisplayName(blockToolName) ??
        'server_tool';
    final args = _serverArgsOrNull(id);
    final content = block['content'];
    // Anthropic reports a server tool failure as a `*_tool_result_error`
    // content block. Without a failed card a throttled turn renders nothing at
    // all, which reads like the tool had never been enabled.
    final errorCode =
        content is Map && (content['type'] ?? '').toString().endsWith('_error')
        ? (content['error_code'] ?? '').toString()
        : '';
    final clipped = _clipServerToolValue(content);
    return <StreamChunk>[
      if (_serverToolStarted.add(id))
        ServerToolStart(id: id, toolName: toolName, input: args),
      ServerToolEnd(
        id: id,
        input: args,
        output: errorCode.isNotEmpty
            ? <String, dynamic>{
                'items': const <Map<String, dynamic>>[],
                'error': errorCode,
              }
            : (clipped is Map<String, dynamic>
                  ? clipped
                  : <String, dynamic>{'content': clipped}),
        status: errorCode.isNotEmpty
            ? ServerToolStatus.failed
            : ServerToolStatus.completed,
        metadata: _anthropicMetadata,
      ),
    ];
  }

  List<StreamChunk> _webSearchResult(Map<String, dynamic> block) {
    final toolUseId = (block['tool_use_id'] ?? '').toString();
    final contentBlock = block['content'];
    final items = <Map<String, dynamic>>[];
    String? errorCode;
    if (contentBlock is List) {
      for (var i = 0; i < contentBlock.length; i++) {
        final it = contentBlock[i];
        if (it is Map && (it['type'] == 'web_search_result')) {
          items.add({
            'index': i + 1,
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
    final args = _serverArgsOrNull(toolUseId);
    final id = toolUseId.isEmpty ? _ids.search() : toolUseId;
    _serverToolEnded.add(id);
    return <StreamChunk>[
      if (_serverToolStarted.add(id))
        ServerToolStart(id: id, toolName: 'search_web', input: args),
      ServerToolEnd(
        id: id,
        input: args,
        output: <String, dynamic>{
          'items': items,
          if ((errorCode ?? '').isNotEmpty) 'error': errorCode,
        },
        metadata: _anthropicMetadata,
      ),
    ];
  }

  List<StreamChunk> _closeOpenClientTools() {
    final chunks = <StreamChunk>[];
    for (final tool in clientTools.values) {
      if (!_clientToolEnded.add(tool.id)) continue;
      _updateToolUseBlock(tool.id, tool.name, tool.decodedArguments);
      chunks.add(ToolCallEnd(tool.id));
    }
    return chunks;
  }

  List<StreamChunk> _closeOpenServerTools() {
    final chunks = <StreamChunk>[];
    for (final id in _serverToolStarted) {
      if (!_serverToolEnded.add(id)) continue;
      chunks.add(
        ServerToolEnd(
          id: id,
          input: _serverArgsFor(id),
          output: const <String, dynamic>{'items': <Map<String, dynamic>>[]},
          status: ServerToolStatus.failed,
          metadata: _anthropicMetadata,
        ),
      );
    }
    return chunks;
  }

  /// The streamed input of a call this response opened, or null when the call
  /// opened in an earlier response of the turn: that decoder held the input,
  /// and an empty map here would erase it from the card.
  Map<String, dynamic>? _serverArgsOrNull(String id) =>
      _serverArgs.containsKey(id) ? decodeStreamedInput(_serverArgs[id]) : null;

  Map<String, dynamic> _serverArgsFor(String id) =>
      decodeStreamedInput(_serverArgs[id]);

  List<StreamChunk> _flushCitations() {
    if (_citationItems.isEmpty) return const <StreamChunk>[];
    final items = List<Map<String, dynamic>>.from(_citationItems);
    _citationItems.clear();
    String? id;
    for (final sid in _serverIndexToId.values) {
      if (!_serverToolEnded.contains(sid)) id = sid;
    }
    if (id == null) {
      if (_serverIndexToId.isNotEmpty || _serverToolEnded.isNotEmpty) {
        return const <StreamChunk>[];
      }
      id = _ids.search();
    }
    if (!_serverToolEnded.add(id)) {
      return const <StreamChunk>[];
    }
    final args = _serverArgsFor(id);
    return <StreamChunk>[
      if (_serverToolStarted.add(id))
        ServerToolStart(id: id, toolName: 'search_web', input: args),
      ServerToolEnd(
        id: id,
        input: args,
        output: <String, dynamic>{'items': items},
        metadata: _anthropicMetadata,
      ),
    ];
  }

  void _flushTextBlock() {
    final text = _textBuf.toString();
    if (text.isEmpty) return;
    assistantBlocks.add({'type': 'text', 'text': text});
    _textBuf.clear();
  }

  void _updateToolUseBlock(String id, String name, Map<String, dynamic> args) {
    for (var i = assistantBlocks.length - 1; i >= 0; i--) {
      final block = assistantBlocks[i];
      if (block['type'] == 'tool_use' &&
          (block['id']?.toString() ?? '') == id) {
        assistantBlocks[i] = {
          'type': 'tool_use',
          'id': id,
          'name': name,
          'input': args,
        };
        return;
      }
    }
  }

  int? _parseIndex(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    return int.tryParse(raw.toString());
  }
}

/// A tool's streamed input arrives as partial JSON in a buffer, and an
/// incomplete or absent one reads as no arguments at all.
Map<String, dynamic> decodeStreamedInput(StringBuffer? buffer) {
  final raw = buffer?.toString() ?? '';
  if (raw.isEmpty) return const <String, dynamic>{};
  try {
    return (jsonDecode(raw) as Map).cast<String, dynamic>();
  } catch (_) {
    return const <String, dynamic>{};
  }
}

class ClaudeClientTool {
  ClaudeClientTool({required this.id, this.name = ''});

  final String id;
  String name;
  final StringBuffer input = StringBuffer();

  Map<String, dynamic> get decodedArguments => decodeStreamedInput(input);
}

TokenUsage claudeUsageFromMap(Map<String, dynamic> usage) {
  final inTok = _readClaudeUsageInt(usage['input_tokens']);
  final outTok = _readClaudeUsageInt(usage['output_tokens']);
  final cached =
      _readClaudeUsageInt(usage['cache_read_input_tokens']) +
      _readClaudeUsageInt(usage['cache_creation_input_tokens']);
  return TokenUsage(
    promptTokens: inTok,
    completionTokens: outTok,
    cachedTokens: cached,
    totalTokens: inTok + outTok,
  );
}

int _readClaudeUsageInt(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
