import 'dart:convert';

import '../../../models/token_usage.dart';
import '../chat_api_service.dart';
import 'stream_chunk.dart';

/// Bridges [StreamChunk] events back to the existing [ChatStreamChunk] bag.
///
/// Stateful: create one instance per response stream. After the first
/// [Finish], further events are ignored so `isDone` is emitted exactly once.
/// Fold adapter output back into one bag. Non-stream callers historically
/// received content, reasoning, usage and `isDone` on a single chunk.
ChatStreamChunk coalesceChatStreamChunks(List<ChatStreamChunk> chunks) {
  final content = StringBuffer();
  final reasoning = StringBuffer();
  dynamic reasoningDetails;
  TokenUsage? usage;
  final toolCalls = <String, ToolCallInfo>{};
  final toolResults = <String, ToolResultInfo>{};
  var isDone = false;
  for (final chunk in chunks) {
    content.write(chunk.content);
    if ((chunk.reasoning ?? '').isNotEmpty) {
      reasoning.write(chunk.reasoning);
    }
    if (chunk.reasoningDetails != null) {
      reasoningDetails = chunk.reasoningDetails;
    }
    if (chunk.usage != null) {
      usage = (usage ?? const TokenUsage()).merge(chunk.usage!);
    }
    for (final call in chunk.toolCalls ?? const <ToolCallInfo>[]) {
      toolCalls[call.id] = call;
    }
    for (final result in chunk.toolResults ?? const <ToolResultInfo>[]) {
      toolResults[result.id] = result;
    }
    isDone = isDone || chunk.isDone;
  }
  return ChatStreamChunk(
    content: content.toString(),
    reasoning: reasoning.isEmpty ? null : reasoning.toString(),
    reasoningDetails: reasoningDetails,
    isDone: isDone,
    totalTokens: usage?.totalTokens ?? 0,
    usage: usage,
    toolCalls: toolCalls.isEmpty ? null : toolCalls.values.toList(),
    toolResults: toolResults.isEmpty ? null : toolResults.values.toList(),
  );
}

class LegacyChunkAdapter {
  TokenUsage? _usage;
  dynamic _reasoningDetails;
  bool _finished = false;

  final Map<String, _ToolCallBuffer> _toolCalls = <String, _ToolCallBuffer>{};
  final Map<String, _ServerToolBuffer> _serverTools =
      <String, _ServerToolBuffer>{};
  final Map<String, _ImageBuffer> _images = <String, _ImageBuffer>{};

  Stream<ChatStreamChunk> adapt(Stream<StreamChunk> input) async* {
    await for (final chunk in input) {
      for (final mapped in handle(chunk)) {
        yield mapped;
      }
    }
  }

  List<ChatStreamChunk> handle(StreamChunk chunk) {
    if (_finished) return const <ChatStreamChunk>[];

    switch (chunk) {
      case TextDelta(:final text):
        if (text.isEmpty) return const <ChatStreamChunk>[];
        return <ChatStreamChunk>[_delta(content: text)];
      case ReasoningDelta(:final text, :final details):
        if (details != null) _reasoningDetails = details;
        if (text.isEmpty && details == null) {
          return const <ChatStreamChunk>[];
        }
        return <ChatStreamChunk>[
          _delta(
            reasoning: text.isEmpty ? null : text,
            reasoningDetails: details,
          ),
        ];
      case ToolCallStart(:final id, :final toolName, :final metadata):
        final buffer = _toolCalls.putIfAbsent(id, _ToolCallBuffer.new);
        if (toolName.isNotEmpty) buffer.name = toolName;
        if (metadata != null) buffer.metadata = metadata;
        return <ChatStreamChunk>[
          _delta(
            toolCalls: <ToolCallInfo>[
              ToolCallInfo(
                id: id,
                name: buffer.name,
                arguments: const <String, dynamic>{},
                metadata: buffer.metadata,
              ),
            ],
          ),
        ];
      case ToolCallDelta(
        :final id,
        :final toolNameDelta,
        :final inputDelta,
        :final metadata,
      ):
        final buffer = _toolCalls.putIfAbsent(id, _ToolCallBuffer.new);
        if (toolNameDelta.isNotEmpty) buffer.name += toolNameDelta;
        buffer.input.write(inputDelta);
        if (metadata != null) buffer.metadata = metadata;
        return const <ChatStreamChunk>[];
      case ToolCallEnd(:final id):
        final buffer = _toolCalls.remove(id) ?? _ToolCallBuffer();
        return <ChatStreamChunk>[
          _delta(
            toolCalls: <ToolCallInfo>[
              ToolCallInfo(
                id: id,
                name: buffer.name,
                arguments: _decodeArguments(buffer.input.toString()),
                metadata: buffer.metadata,
              ),
            ],
          ),
        ];
      case ServerToolStart(
        :final id,
        :final toolName,
        :final input,
        :final metadata,
      ):
        final buffer = _serverTools.putIfAbsent(id, _ServerToolBuffer.new);
        buffer.name = toolName;
        if (input != null) buffer.input = input;
        if (metadata != null) buffer.metadata = metadata;
        return const <ChatStreamChunk>[];
      case ServerToolInputDelta(:final id, :final inputDelta):
        final buffer = _serverTools.putIfAbsent(id, _ServerToolBuffer.new);
        buffer.inputDelta.write(inputDelta);
        return const <ChatStreamChunk>[];
      case ServerToolEnd(
        :final id,
        :final input,
        :final output,
        :final metadata,
      ):
        final buffer = _serverTools.remove(id) ?? _ServerToolBuffer();
        final resolvedInput = input ?? buffer.resolvedInput;
        return <ChatStreamChunk>[
          _delta(
            toolResults: <ToolResultInfo>[
              ToolResultInfo(
                id: id,
                name: buffer.name,
                arguments: _asArgumentMap(resolvedInput),
                content: _stringifyOutput(output),
                metadata: metadata ?? buffer.metadata,
              ),
            ],
          ),
        ];
      case ImageStart(:final id, :final mimeType):
        _images.putIfAbsent(id, _ImageBuffer.new).mimeType = mimeType;
        return const <ChatStreamChunk>[];
      case ImageDelta(:final id, :final data):
        final buffer = _images.putIfAbsent(id, _ImageBuffer.new);
        buffer.data.write(data);
        return <ChatStreamChunk>[
          _delta(content: _imageDeltaContent(buffer, data)),
        ];
      case ImageSnapshot(:final id, :final data):
        final buffer = _images.putIfAbsent(id, _ImageBuffer.new);
        buffer.data
          ..clear()
          ..write(data);
        buffer.closed = true;
        return <ChatStreamChunk>[
          _delta(content: _imageMarkdown(buffer.mimeType, data)),
        ];
      case ImageEnd(:final id):
        final buffer = _images.remove(id);
        if (buffer == null || buffer.closed || !buffer.opened) {
          return const <ChatStreamChunk>[];
        }
        buffer.closed = true;
        return <ChatStreamChunk>[_delta(content: ')')];
      case Annotations(:final annotations):
        if (annotations.isEmpty) return const <ChatStreamChunk>[];
        return <ChatStreamChunk>[
          _delta(
            toolResults: <ToolResultInfo>[
              ToolResultInfo(
                id: 'builtin_search',
                name: 'search_web',
                arguments: const <String, dynamic>{},
                content: jsonEncode(<String, dynamic>{
                  'items': annotations
                      .whereType<UrlCitationAnnotation>()
                      .map(
                        (citation) => <String, dynamic>{
                          'url': citation.url,
                          if (citation.title.isNotEmpty)
                            'title': citation.title,
                        },
                      )
                      .toList(),
                }),
              ),
            ],
          ),
        ];
      case Usage(:final usage):
        _usage = (_usage ?? const TokenUsage()).merge(usage);
        return <ChatStreamChunk>[_delta()];
      case Finish():
        _finished = true;
        final trailing = <ChatStreamChunk>[
          for (final buffer in _images.values)
            if (!buffer.closed && buffer.opened) _delta(content: ')'),
          ChatStreamChunk(
            content: '',
            reasoningDetails: _reasoningDetails,
            isDone: true,
            totalTokens: _usage?.totalTokens ?? 0,
            usage: _usage,
          ),
        ];
        _images.clear();
        return trailing;
      case TextStart() ||
          TextEnd() ||
          ReasoningStart() ||
          ReasoningEnd() ||
          ServerToolInputEnd():
        return const <ChatStreamChunk>[];
    }
  }

  ChatStreamChunk _delta({
    String content = '',
    String? reasoning,
    dynamic reasoningDetails,
    List<ToolCallInfo>? toolCalls,
    List<ToolResultInfo>? toolResults,
  }) {
    return ChatStreamChunk(
      content: content,
      reasoning: reasoning,
      reasoningDetails: reasoningDetails,
      isDone: false,
      totalTokens: _usage?.totalTokens ?? 0,
      usage: _usage,
      toolCalls: toolCalls,
      toolResults: toolResults,
    );
  }

  String _imageDeltaContent(_ImageBuffer buffer, String data) {
    if (isCompleteImageUri(data)) {
      buffer.opened = true;
      return _imageMarkdown(buffer.mimeType, data);
    }
    if (buffer.opened) return data;
    buffer.opened = true;
    return '${_imageMarkdownPrefix(buffer.mimeType)}$data';
  }

  String _imageMarkdown(String mimeType, String data) {
    if (isCompleteImageUri(data)) return '\n\n![image]($data)';
    return '${_imageMarkdownPrefix(mimeType)}$data)';
  }

  String _imageMarkdownPrefix(String mimeType) {
    return '\n\n![image](data:$mimeType;base64,';
  }
}

class _ToolCallBuffer {
  String name = '';
  final StringBuffer input = StringBuffer();
  Map<String, dynamic>? metadata;
}

class _ServerToolBuffer {
  String name = '';
  Object? input;
  final StringBuffer inputDelta = StringBuffer();
  Map<String, dynamic>? metadata;

  Object? get resolvedInput {
    if (input != null) return input;
    final raw = inputDelta.toString();
    if (raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return raw;
    }
  }
}

class _ImageBuffer {
  String mimeType = 'image/png';
  final StringBuffer data = StringBuffer();
  bool opened = false;
  bool closed = false;
}

Map<String, dynamic> _decodeArguments(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return <String, dynamic>{};
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map) return decoded.cast<String, dynamic>();
  } catch (_) {}
  return <String, dynamic>{};
}

Map<String, dynamic> _asArgumentMap(Object? value) {
  if (value is Map) return value.cast<String, dynamic>();
  if (value is String) return _decodeArguments(value);
  return <String, dynamic>{};
}

String _stringifyOutput(Object? output) {
  if (output == null) return '';
  if (output is String) return output;
  return jsonEncode(output);
}
