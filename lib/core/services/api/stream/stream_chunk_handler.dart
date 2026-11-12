import 'dart:convert';

import '../../../models/message_part.dart';
import '../../../models/message_part_snapshot.dart';
import '../../../models/token_usage.dart';
import '../generation/text_generation_result.dart';
import 'stream_chunk.dart';
import 'stream_text_buffer.dart';

/// Folds [StreamChunk] events into an ordered [MessagePart] list.
///
/// Text, reasoning, and images are located by event [id] so interleaved
/// arrivals do not clobber the last part. Tool calls are located by tool id.
/// One instance per response stream; do not reuse after [Finish].
class StreamChunkHandler {
  StreamChunkHandler({
    Iterable<MessagePart> seed = const <MessagePart>[],
    this.onRetry,
  }) {
    for (final part in seed) {
      // Empty reasoning retains its position in persisted timing overlays.
      if (_isBlankPart(part) && part is! ReasoningPart) continue;
      _seedPart(part);
    }
  }

  /// Control events that are not folded into [parts].
  final void Function(RetryPending pending)? onRetry;

  final List<MessagePart> _parts = <MessagePart>[];
  final Map<int, StreamTextBuffer> _textBuffers = {};
  List<MessagePart>? _snapshot;
  final _partSnapshots = MessagePartSnapshotBuilder(arrivalOrdered: true);
  final _changedParts = <int>{};

  void _addPart(MessagePart part) {
    _changedParts.add(_parts.length);
    _parts.add(part);
  }

  void _setPart(int index, MessagePart part) {
    _changedParts.add(index);
    _parts[index] = part;
  }

  final Map<String, int> _textIndex = <String, int>{};
  final Map<String, int> _reasoningIndex = <String, int>{};
  final Map<String, int> _imageIndex = <String, int>{};
  final Map<String, int> _toolIndex = <String, int>{};
  final Map<String, _ToolBuffer> _tools = <String, _ToolBuffer>{};
  final Set<String> _dirtyTools = <String>{};
  int get pendingToolBufferCount =>
      _tools.values.where((tool) => !tool.released).length;
  final Map<String, StringBuffer> _serverInput = <String, StringBuffer>{};
  final Map<String, String> _imageMime = <String, String>{};
  final Map<String, StringBuffer> _imageBuffers = <String, StringBuffer>{};

  TokenUsage? usage;
  TokenUsage? _completedUsage;
  TokenUsage? _resultTotalUsage;

  /// All API requests in this turn. [usage] remains the latest request only.
  TokenUsage? get totalUsage =>
      _resultTotalUsage ??
      (_completedUsage == null
          ? usage
          : _completedUsage! + (usage ?? const TokenUsage()));
  dynamic reasoningDetails;
  bool finished = false;
  String? finishReason;

  List<MessagePart> get parts {
    if (_snapshot != null) return _snapshot!;
    for (final index in _textBuffers.keys) {
      _flushText(index);
    }
    _flushTools();
    _snapshot = _partSnapshots.update(_parts, changed: _changedParts);
    _changedParts.clear();
    return _snapshot!;
  }

  /// Read one call without materializing or decoding the rest of the turn.
  Map<String, dynamic>? toolPayload(String id) {
    _flushTool(id);
    final index = _toolIndex[id];
    if (index == null) return null;
    final part = _parts[index];
    if (part is! ToolCallPart) return null;
    return jsonDecode(part.payloadJson) as Map<String, dynamic>;
  }

  void _flushTools() {
    for (final id in _dirtyTools.toList(growable: false)) {
      _flushTool(id);
    }
  }

  void _flushText(int index) {
    final buffer = _textBuffers[index];
    if (buffer == null) return;
    final current = _parts[index];
    final text = buffer.value;
    if (current is TextPart && current.text != text) {
      _setPart(index, TextPart(text));
    } else if (current is ReasoningPart && current.text != text) {
      _setPart(index, ReasoningPart(text));
    }
  }

  void _endText(int? index) {
    if (index == null) return;
    _flushText(index);
    _textBuffers.remove(index);
  }

  TextGenerationResult toResult() {
    return TextGenerationResult(
      parts: [
        for (final part in parts)
          if (!_isBlankPart(part)) part,
      ],
      usage: usage,
      totalUsage: totalUsage,
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
    _snapshot = null;
    for (final part in result.parts) {
      switch (part) {
        case TextPart(:final text) when text.isEmpty:
          continue;
        case ReasoningPart(:final text) when text.isEmpty:
          continue;
        case ImagePart(:final uri) when uri.isEmpty:
          continue;
        default:
          _addPart(part);
      }
    }
    if (result.usage != null) {
      usage = (usage ?? const TokenUsage()).merge(result.usage!);
    }
    _resultTotalUsage = result.totalUsage;
    if (result.reasoningDetails != null) {
      reasoningDetails = result.reasoningDetails;
    }
    finishReason = result.finishReason ?? finishReason;
    finished = true;
  }

  void _seedPart(MessagePart part) {
    _addPart(part);
    if (part is! ToolCallPart) return;
    try {
      final decoded = jsonDecode(part.payloadJson);
      if (decoded is! Map) return;
      final id = (decoded['id'] ?? '').toString();
      if (id.isEmpty) return;
      _toolIndex[id] = _parts.length - 1;
      final buffer = _tools.putIfAbsent(id, _ToolBuffer.new);
      final name = (decoded['name'] ?? '').toString();
      if (name.isNotEmpty) buffer.name = name;
      if (decoded.containsKey('arguments')) {
        buffer.arguments = decoded['arguments'];
      }
      if (decoded.containsKey('content')) {
        buffer.content = decoded['content'];
      }
      buffer.server = decoded['server'] == true;
      final metadata = decoded['metadata'];
      if (metadata is Map) {
        buffer.metadata = Map<String, dynamic>.from(metadata);
      }
      if (buffer.content != null) buffer.release();
    } catch (_) {}
  }

  void handle(StreamChunk chunk) {
    if (finished) return;
    _snapshot = null;
    switch (chunk) {
      case TextStart(:final id):
        _ensureText(id);
      case TextDelta(:final id, :final text):
        if (text.isEmpty) return;
        final index = _ensureText(id);
        _textBuffers.putIfAbsent(index, StreamTextBuffer.new).add(text);
      case TextEnd(:final id):
        _endText(_textIndex.remove(id));
      case ReasoningStart(:final id):
        _ensureReasoning(id);
      case ReasoningDelta(:final id, :final text, :final details):
        if (details != null) reasoningDetails = details;
        if (text.isEmpty) return;
        final index = _ensureReasoning(id);
        _textBuffers.putIfAbsent(index, StreamTextBuffer.new).add(text);
      case ReasoningEnd(:final id):
        _endText(_reasoningIndex.remove(id));
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
        _flushTool(id);
      case ToolCallResult(:final id, :final output, :final metadata):
        _upsertTool(id, content: output ?? '', metadata: metadata);
        _flushTool(id);
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
      case ImageDelta(:final id, :final data):
        if (data.isEmpty) return;
        final mime = _imageMime[id] ?? 'image/png';
        if (isCompleteImageUri(data)) {
          _ensureImage(id, mimeType: mime, data: data);
          return;
        }
        _imageBuffers.putIfAbsent(id, StringBuffer.new).write(data);
      case ImageSnapshot(:final id, :final data):
        if (data.isEmpty) return;
        final mime = _imageMime[id] ?? 'image/png';
        _ensureImage(id, mimeType: mime, data: data);
        if (!isCompleteImageUri(data)) {
          _imageBuffers[id] = StringBuffer(data);
        }
      case ImageEnd(:final id):
        final mime = _imageMime[id] ?? 'image/png';
        final buffered = _imageBuffers.remove(id)?.toString() ?? '';
        final index = _imageIndex[id];
        final current = index != null && _parts[index] is ImagePart
            ? _parts[index] as ImagePart
            : null;
        if (buffered.isNotEmpty &&
            (current == null || current.uri.startsWith('data:'))) {
          _ensureImage(id, mimeType: mime, data: buffered);
        }
        _imageIndex.remove(id);
        _imageMime.remove(id);
      case AssistantRoundEnd(:final reasoningDetails):
        for (final index in _textBuffers.keys.toList()) {
          _endText(index);
        }
        _textIndex.clear();
        _reasoningIndex.clear();
        _addPart(AssistantRoundEndPart(reasoningDetails: reasoningDetails));
        this.reasoningDetails = null;
      case ProviderArtifact():
        // Provider state, not message content; the chat stores it separately.
        break;
      case GeneratedFile(:final uri, :final name, :final mime):
        if (uri.isEmpty) return;
        // An image belongs in an image part so the viewer, the export sheet,
        // and the next request treat it as a picture rather than a download.
        _addPart(
          (mime ?? '').startsWith('image/')
              ? ImagePart(uri: uri, mime: mime)
              : FilePart(uri: uri, name: name, mime: mime),
        );
      case Annotations(:final id, :final annotations):
        final items = [
          for (final citation in annotations.whereType<UrlCitationAnnotation>())
            if (citation.url.isNotEmpty)
              <String, dynamic>{
                'url': citation.url,
                if (citation.title.isNotEmpty) 'title': citation.title,
              },
        ];
        if (items.isEmpty) return;
        final targetId = _lastSearchToolId() ?? (id.isNotEmpty ? id : null);
        if (targetId == null) return;
        _restoreTool(targetId);
        final existing = _tools[targetId];
        _upsertTool(
          targetId,
          name: (existing != null && existing.name.isNotEmpty)
              ? existing.name
              : 'builtin_search',
          content: _mergeSearchItems(existing?.content, items),
          server: true,
        );
      case Usage(:final usage, :final startsRequest):
        if (startsRequest) {
          if (this.usage != null) {
            _completedUsage =
                (_completedUsage ?? const TokenUsage()) + this.usage!;
          }
          this.usage = null;
        }
        this.usage = (this.usage ?? const TokenUsage()).merge(usage);
      case final RetryPending pending:
        onRetry?.call(pending);
      case RetryAttemptStart():
        break;
      case Finish(:final finishReason):
        for (final index in _textBuffers.keys.toList()) {
          _endText(index);
        }
        this.finishReason = finishReason;
        finished = true;
        // Tool payloads were encoded while the turn was still streaming, so
        // their replay metadata stops at whatever had arrived by then. The
        // metadata holds a live reference to the provider's block list, so
        // re-encoding now captures the finished turn.
        _flushTools();
        for (final id in _tools.keys) {
          _refreshToolMetadata(id);
        }
        _textIndex.clear();
        _reasoningIndex.clear();
        _imageIndex.clear();
        _toolIndex.clear();
        _tools.clear();
        _serverInput.clear();
        _imageMime.clear();
        _imageBuffers.clear();
    }
  }

  int _ensureText(String id) {
    final existing = _textIndex[id];
    if (existing != null && _parts[existing] is TextPart) return existing;
    _addPart(const TextPart(''));
    return _textIndex[id] = _parts.length - 1;
  }

  int _ensureReasoning(String id) {
    final existing = _reasoningIndex[id];
    if (existing != null && _parts[existing] is ReasoningPart) {
      return existing;
    }
    _addPart(const ReasoningPart(''));
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
    final part = ImagePart(uri: uri, mime: mimeType, id: id);
    if (index != null && _parts[index] is ImagePart) {
      _setPart(index, part);
      return index;
    }
    _addPart(part);
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
    _restoreTool(id);
    if (name != null && name.isNotEmpty) buffer.name = name;
    if (nameDelta.isNotEmpty) buffer.name += nameDelta;
    if (inputDelta.isNotEmpty) {
      buffer.input.add(inputDelta);
      buffer.inputDirty = true;
    }
    // A decoder that never saw the call reports no arguments; empty ones are
    // no news either, and would erase the input already streamed for it.
    if (argumentsObject != null &&
        !(argumentsObject is Map && argumentsObject.isEmpty)) {
      buffer.arguments = argumentsObject;
    }
    if (content != null) buffer.content = content;
    buffer.server = buffer.server || server;
    if (metadata != null && metadata.isNotEmpty) {
      buffer.metadata = <String, dynamic>{...?buffer.metadata, ...metadata};
    }
    _dirtyTools.add(id);
    // Reserve arrival order now; encoding is deferred until a snapshot or an
    // explicit protocol boundary. No reader can observe the placeholder.
    if (!_toolIndex.containsKey(id)) {
      _toolIndex[id] = _parts.length;
      _addPart(const ToolCallPart('{}'));
    }
  }

  void _flushTool(String id) {
    if (!_dirtyTools.remove(id)) return;
    final buffer = _tools[id]!;
    if (buffer.inputDirty) {
      buffer.decodedInput = _tryDecode(buffer.input.value);
      buffer.inputDirty = false;
    }

    final body = jsonEncode(<String, dynamic>{
      'id': id,
      'name': buffer.name,
      'arguments': buffer.arguments ?? buffer.decodedInput,
      'content': buffer.content,
      'server': buffer.server,
    });
    buffer.metadataOffset = body.length - 1;
    final encodedMetadata = buffer.metadata?.isNotEmpty == true
        ? jsonEncode(buffer.metadata)
        : null;
    final payload = encodedMetadata == null
        ? body
        : '${body.substring(0, buffer.metadataOffset)}$_metadataPrefix$encodedMetadata}';

    final index = _toolIndex[id]!;
    final previous = _parts[index] as ToolCallPart;
    if (previous.payloadJson != payload) {
      _setPart(index, ToolCallPart(payload));
    }
    if (buffer.content != null) buffer.release();
  }

  void _restoreTool(String id) {
    final buffer = _tools[id];
    if (buffer == null || !buffer.released) return;
    final part = _parts[_toolIndex[id]!] as ToolCallPart;
    final decoded = jsonDecode(part.payloadJson) as Map<String, dynamic>;
    buffer.arguments = decoded['arguments'];
    buffer.content = decoded['content'];
    buffer.released = false;
  }

  void _refreshToolMetadata(String id) {
    final buffer = _tools[id]!;
    if (buffer.metadata == null) return;
    final metadata = buffer.metadata!.isEmpty
        ? null
        : jsonEncode(buffer.metadata);
    if (buffer.metadataOffset == null) {
      // Seeded parts can have arbitrary JSON key order; normalize once.
      _upsertTool(id);
      _flushTool(id);
      return;
    }
    final index = _toolIndex[id]!;
    final part = _parts[index] as ToolCallPart;
    final offset = buffer.metadataOffset!;
    if (metadata == null) {
      if (part.payloadJson.length == offset + 1) return;
    } else if (part.payloadJson.length ==
            offset + _metadataPrefix.length + metadata.length + 1 &&
        part.payloadJson.startsWith(
          metadata,
          offset + _metadataPrefix.length,
        )) {
      return;
    }
    final body = part.payloadJson.substring(0, offset);
    _setPart(
      index,
      ToolCallPart(
        metadata == null ? '$body}' : '$body$_metadataPrefix$metadata}',
      ),
    );
  }

  static const _metadataPrefix = ',"metadata":';

  static bool _isBlankPart(MessagePart part) {
    return switch (part) {
      TextPart(:final text) => text.isEmpty,
      ReasoningPart(:final text) => text.isEmpty,
      ImagePart(:final uri) => isBlankImageUri(uri),
      _ => false,
    };
  }

  String? _lastSearchToolId() {
    _flushTools();
    for (final part in _parts.reversed) {
      if (part is! ToolCallPart) continue;
      try {
        final decoded = jsonDecode(part.payloadJson);
        if (decoded is! Map) continue;
        final name = (decoded['name'] ?? '').toString();
        if (name != 'search_web' && name != 'builtin_search') continue;
        final id = (decoded['id'] ?? '').toString();
        if (id.isNotEmpty) return id;
      } catch (_) {}
    }
    return null;
  }

  /// Merge citation [items] onto an existing search payload, de-duplicating by url.
  static Object mergeSearchItems(
    Object? existing,
    List<Map<String, dynamic>> incoming,
  ) => _mergeSearchItems(existing, incoming);

  static Object _mergeSearchItems(
    Object? existing,
    List<Map<String, dynamic>> incoming,
  ) {
    final existingMap = _asStringKeyedMap(existing);
    final items = <Map<String, dynamic>>[];
    final seen = <String>{};
    final rawItems = existingMap?['items'];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is! Map) continue;
        final url = (item['url'] ?? '').toString();
        if (url.isNotEmpty && !seen.add(url)) continue;
        items.add(Map<String, dynamic>.from(item));
      }
    }
    for (final item in incoming) {
      final url = (item['url'] ?? '').toString();
      if (url.isNotEmpty && !seen.add(url)) continue;
      items.add(item);
    }
    if (existingMap != null) {
      return <String, dynamic>{...existingMap, 'items': items};
    }
    return <String, dynamic>{'items': items};
  }

  static Map<String, dynamic>? _asStringKeyedMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }
}

class _ToolBuffer {
  String name = '';
  final StreamTextBuffer input = StreamTextBuffer();
  bool inputDirty = false;
  Object decodedInput = const <String, dynamic>{};
  Object? arguments;
  Object? content;
  bool server = false;
  Map<String, dynamic>? metadata;
  bool released = false;
  int? metadataOffset;

  void release() {
    input.value = '';
    inputDirty = false;
    decodedInput = const <String, dynamic>{};
    arguments = null;
    content = null;
    released = true;
  }
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
