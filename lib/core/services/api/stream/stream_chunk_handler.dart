import 'dart:convert';

import '../../../models/message_part.dart';
import '../../../models/token_usage.dart';
import '../generation/text_generation_result.dart';
import 'stream_chunk.dart';

/// Folds [StreamChunk] events into an ordered [MessagePart] list.
///
/// Text, reasoning, and images are located by event [id] so interleaved
/// arrivals do not clobber the last part. Tool calls are located by tool id.
/// One instance per response stream; do not reuse after [Finish].
class StreamChunkHandler {
  final List<MessagePart> _parts = <MessagePart>[];
  final Map<String, int> _textIndex = <String, int>{};
  final Map<String, int> _reasoningIndex = <String, int>{};
  final Map<String, int> _imageIndex = <String, int>{};
  final Map<String, _ToolBuffer> _tools = <String, _ToolBuffer>{};
  final Map<String, StringBuffer> _serverInput = <String, StringBuffer>{};
  final Map<String, String> _imageMime = <String, String>{};

  TokenUsage? usage;
  dynamic reasoningDetails;
  bool finished = false;
  String? finishReason;

  List<MessagePart> get parts => List<MessagePart>.unmodifiable(_parts);

  TextGenerationResult toResult() {
    return TextGenerationResult(
      parts: [
        for (final part in _parts)
          if (!_isBlankPart(part)) part,
      ],
      usage: usage,
      finishReason: finishReason,
      reasoningDetails: reasoningDetails,
    );
  }

  static TextGenerationResult collect(Iterable<StreamChunk> chunks) {
    final handler = StreamChunkHandler();
    for (final chunk in chunks) {
      handler.handle(chunk);
    }
    return handler.toResult();
  }

  /// Merge a complete non-stream result. Image URIs are kept as-is.
  void handleResult(TextGenerationResult result) {
    if (finished) return;
    for (final part in result.parts) {
      switch (part) {
        case TextPart(:final text) when text.isEmpty:
          continue;
        case ReasoningPart(:final text) when text.isEmpty:
          continue;
        case ImagePart(:final uri) when uri.isEmpty:
          continue;
        default:
          _parts.add(part);
      }
    }
    if (result.usage != null) {
      usage = (usage ?? const TokenUsage()).merge(result.usage!);
    }
    if (result.reasoningDetails != null) {
      reasoningDetails = result.reasoningDetails;
    }
    finishReason = result.finishReason ?? finishReason;
    finished = true;
  }

  void handle(StreamChunk chunk) {
    if (finished) return;
    switch (chunk) {
      case TextStart(:final id):
        _ensureText(id);
      case TextDelta(:final id, :final text):
        if (text.isEmpty) return;
        final index = _ensureText(id);
        final current = _parts[index] as TextPart;
        _parts[index] = TextPart(current.text + text);
      case TextEnd(:final id):
        _textIndex.remove(id);
      case ReasoningStart(:final id):
        _ensureReasoning(id);
      case ReasoningDelta(:final id, :final text, :final details):
        if (details != null) reasoningDetails = details;
        if (text.isEmpty) return;
        final index = _ensureReasoning(id);
        final current = _parts[index] as ReasoningPart;
        _parts[index] = ReasoningPart(current.text + text);
      case ReasoningEnd(:final id):
        _reasoningIndex.remove(id);
      case ToolCallStart(:final id, :final toolName, :final metadata):
        _upsertTool(id, name: toolName, metadata: metadata);
      case ToolCallDelta(
        :final id,
        :final toolNameDelta,
        :final inputDelta,
        :final metadata,
      ):
        _upsertTool(
          id,
          nameDelta: toolNameDelta,
          inputDelta: inputDelta,
          metadata: metadata,
        );
      case ToolCallEnd(:final id):
        _upsertTool(id);
      case ToolCallResult(:final id, :final output, :final metadata):
        _upsertTool(id, content: output ?? '', metadata: metadata);
      case ServerToolStart(
        :final id,
        :final toolName,
        :final input,
        :final metadata,
      ):
        _upsertTool(
          id,
          name: toolName,
          argumentsObject: input,
          server: true,
          metadata: metadata,
        );
      case ServerToolInputDelta(:final id, :final inputDelta):
        _serverInput.putIfAbsent(id, StringBuffer.new).write(inputDelta);
      case ServerToolInputEnd(:final id):
        final raw = _serverInput.remove(id)?.toString() ?? '';
        if (raw.isNotEmpty) {
          _upsertTool(id, argumentsObject: _tryDecode(raw), server: true);
        }
      case ServerToolEnd(
        :final id,
        :final input,
        :final output,
        :final status,
        :final metadata,
      ):
        final raw = _serverInput.remove(id)?.toString();
        _upsertTool(
          id,
          argumentsObject: input ?? (raw == null ? null : _tryDecode(raw)),
          content: output ?? status.name,
          server: true,
          metadata: metadata,
        );
      case ImageStart(:final id, :final mimeType):
        _imageMime[id] = mimeType;
        _ensureImage(id, mimeType: mimeType, data: '');
      case ImageDelta(:final id, :final data):
        if (data.isEmpty) return;
        final mime = _imageMime[id] ?? 'image/png';
        final index = _imageIndex[id];
        if (isCompleteImageUri(data) ||
            index == null ||
            _parts[index] is! ImagePart) {
          _ensureImage(id, mimeType: mime, data: data);
        } else {
          final current = _parts[index] as ImagePart;
          _parts[index] = ImagePart(
            uri: '${current.uri}$data',
            mime: current.mime ?? mime,
          );
        }
      case ImageSnapshot(:final id, :final data):
        final mime = _imageMime[id] ?? 'image/png';
        final index = _imageIndex[id];
        if (isCompleteImageUri(data) ||
            index == null ||
            _parts[index] is! ImagePart) {
          _ensureImage(id, mimeType: mime, data: data);
        } else {
          final current = _parts[index] as ImagePart;
          final prefix = current.uri.contains(',')
              ? current.uri.substring(0, current.uri.indexOf(',') + 1)
              : 'data:$mime;base64,';
          _parts[index] = ImagePart(
            uri: '$prefix$data',
            mime: current.mime ?? mime,
          );
        }
      case ImageEnd(:final id):
        _imageIndex.remove(id);
        _imageMime.remove(id);
      case Annotations():
        break;
      case Usage(:final usage):
        this.usage = (this.usage ?? const TokenUsage()).merge(usage);
      case Finish(:final finishReason):
        this.finishReason = finishReason;
        finished = true;
        _textIndex.clear();
        _reasoningIndex.clear();
        _imageIndex.clear();
        _tools.clear();
        _serverInput.clear();
        _imageMime.clear();
    }
  }

  int _ensureText(String id) {
    final existing = _textIndex[id];
    if (existing != null && _parts[existing] is TextPart) return existing;
    _parts.add(const TextPart(''));
    return _textIndex[id] = _parts.length - 1;
  }

  int _ensureReasoning(String id) {
    final existing = _reasoningIndex[id];
    if (existing != null && _parts[existing] is ReasoningPart) {
      return existing;
    }
    _parts.add(const ReasoningPart(''));
    return _reasoningIndex[id] = _parts.length - 1;
  }

  int _ensureImage(
    String id, {
    required String mimeType,
    required String data,
  }) {
    _imageMime[id] = mimeType;
    final uri = isCompleteImageUri(data) ? data : 'data:$mimeType;base64,$data';
    final index = _imageIndex[id];
    final part = ImagePart(uri: uri, mime: mimeType);
    if (index != null && _parts[index] is ImagePart) {
      _parts[index] = part;
      return index;
    }
    _parts.add(part);
    return _imageIndex[id] = _parts.length - 1;
  }

  void _upsertTool(
    String id, {
    String? name,
    String nameDelta = '',
    String inputDelta = '',
    Object? argumentsObject,
    Object? content,
    bool server = false,
    Map<String, dynamic>? metadata,
  }) {
    final buffer = _tools.putIfAbsent(id, _ToolBuffer.new);
    if (name != null && name.isNotEmpty) buffer.name = name;
    if (nameDelta.isNotEmpty) buffer.name += nameDelta;
    if (inputDelta.isNotEmpty) buffer.input.write(inputDelta);
    if (argumentsObject != null) buffer.arguments = argumentsObject;
    if (content != null) buffer.content = content;
    buffer.server = buffer.server || server;
    if (metadata != null && metadata.isNotEmpty) {
      buffer.metadata = <String, dynamic>{...?buffer.metadata, ...metadata};
    }

    final payload = jsonEncode(<String, dynamic>{
      'id': id,
      'name': buffer.name,
      'arguments': buffer.arguments ?? _tryDecode(buffer.input.toString()),
      'content': buffer.content,
      'server': buffer.server,
      if (buffer.metadata != null && buffer.metadata!.isNotEmpty)
        'metadata': buffer.metadata,
    });

    final index = _parts.indexWhere(
      (part) => part is ToolCallPart && _toolId(part) == id,
    );
    final part = ToolCallPart(payload);
    if (index < 0) {
      _parts.add(part);
    } else {
      _parts[index] = part;
    }
  }

  static bool _isBlankPart(MessagePart part) {
    return switch (part) {
      TextPart(:final text) => text.isEmpty,
      ReasoningPart(:final text) => text.isEmpty,
      ImagePart(:final uri) => uri.isEmpty,
      _ => false,
    };
  }

  String? _toolId(ToolCallPart part) {
    try {
      final decoded = jsonDecode(part.payloadJson);
      if (decoded is Map) return (decoded['id'] ?? '').toString();
    } catch (_) {}
    return null;
  }
}

class _ToolBuffer {
  String name = '';
  final StringBuffer input = StringBuffer();
  Object? arguments;
  Object? content;
  bool server = false;
  Map<String, dynamic>? metadata;
}

Object _tryDecode(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return <String, dynamic>{};
  try {
    return jsonDecode(trimmed);
  } catch (_) {
    return raw;
  }
}
