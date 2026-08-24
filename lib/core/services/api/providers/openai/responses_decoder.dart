import 'dart:convert';

import '../../../../models/token_usage.dart';
import '../../stream/sse_event.dart';
import '../../stream/stream_chunk.dart';
import '../../stream/stream_chunk_decoder.dart';
import '../../stream/stream_chunk_ids.dart';

class ResponsesFunctionCall {
  ResponsesFunctionCall({
    required this.index,
    required this.callId,
    required this.name,
    this.args = '',
    this.seriesId = '',
  });

  final int index;
  String callId;
  String name;
  String args;

  /// First-seen stream id used by UI chunks, handler, and approval.
  ///
  /// OpenAI may emit an item id (for example `fc_1`) before `call_id`.
  /// [seriesId] stays on that first-seen id; [callId] may later become the
  /// vendor `call_id` for the API transcript.
  String seriesId;

  Map<String, dynamic> get decodedArguments {
    try {
      return (jsonDecode(args.isEmpty ? '{}' : args) as Map)
          .cast<String, dynamic>();
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Map<String, String> toIndexFields() => <String, String>{
    'call_id': callId,
    'name': name,
    'args': args,
    'series_id': seriesId,
  };
}

class ResponsesPendingImage {
  const ResponsesPendingImage({
    required this.index,
    required this.base64,
    this.outputFormat = '',
  });

  final int index;
  final String base64;
  final String outputFormat;
}

/// Stateful OpenAI Responses SSE decoder. One instance per HTTP response.
class ResponsesStreamDecoder implements StreamChunkDecoder {
  ResponsesStreamDecoder({this.initialUsage, String sourceId = 'stream'})
    : _ids = StreamChunkIds(sourceId);

  final TokenUsage? initialUsage;
  final StreamChunkIds _ids;
  TokenUsage? _round;

  TokenUsage? get usage {
    if (_round == null) return initialUsage;
    return (initialUsage ?? const TokenUsage()).accumulate(_round!);
  }

  bool completed = false;
  int approxCompletionChars = 0;

  List<Map<String, dynamic>> outputItems = const <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> citations = <Map<String, dynamic>>[];
  final Map<int, ResponsesFunctionCall> toolCallsByIndex =
      <int, ResponsesFunctionCall>{};
  final Map<String, ResponsesFunctionCall> toolCallsByKey =
      <String, ResponsesFunctionCall>{};
  final Map<int, ResponsesPendingImage> imagesByIndex =
      <int, ResponsesPendingImage>{};

  final Map<int, String> _toolEventIdsByIndex = <int, String>{};
  final Map<String, String> _toolEventIdsByKey = <String, String>{};
  final Set<String> _openToolIds = <String>{};
  final Set<String> _endedToolIds = <String>{};
  final Map<int, String> _imageIdsByIndex = <int, String>{};
  final Set<String> _openImageIds = <String>{};
  final Set<String> _endedImageIds = <String>{};
  final Set<String> _openServerToolIds = <String>{};
  final Set<String> _endedServerToolIds = <String>{};
  final Set<String> _seenCitationUrls = <String>{};
  bool _emittedCitationEvents = false;
  bool _closed = false;

  bool get emittedImageEvents =>
      _openImageIds.isNotEmpty || _endedImageIds.isNotEmpty;
  bool get emittedCitationEvents => _emittedCitationEvents;

  bool get hasFunctionCalls =>
      toolCallsByIndex.isNotEmpty || toolCallsByKey.isNotEmpty;

  List<ResponsesFunctionCall> takeFunctionCalls() {
    if (toolCallsByIndex.isNotEmpty) {
      final sorted = toolCallsByIndex.keys.toList()..sort();
      return [
        for (final index in sorted)
          _withSeriesId(toolCallsByIndex[index]!, _toolEventIdsByIndex[index]),
      ];
    }
    var index = 0;
    return [
      for (final entry in toolCallsByKey.entries)
        _withSeriesId(
          ResponsesFunctionCall(
            index: index++,
            callId: entry.key,
            name: entry.value.name,
            args: entry.value.args,
            seriesId: entry.value.seriesId,
          ),
          _toolEventIdsByKey[entry.key],
        ),
    ];
  }

  List<ResponsesPendingImage> takeImages() {
    final sorted = imagesByIndex.keys.toList()..sort();
    return [for (final index in sorted) imagesByIndex[index]!];
  }

  @override
  DecodeResult accept(SseEvent event) {
    if (_closed || completed) {
      return const DecodeResult(completed: true);
    }
    final data = event.data;
    if (data.isEmpty) return const DecodeResult();
    if (data == '[DONE]') {
      completed = true;
      return DecodeResult(chunks: _closeOpenSeries(), completed: true);
    }

    late final Map<String, dynamic> obj;
    try {
      final decoded = jsonDecode(data);
      if (decoded is! Map) return const DecodeResult();
      obj = decoded.cast<String, dynamic>();
    } catch (error) {
      logDecoderParseError(
        provider: 'responses',
        eventType: event.event ?? 'json',
        error: error,
      );
      return const DecodeResult();
    }

    final chunks = <StreamChunk>[];
    try {
      _parseEvent(obj, chunks);
    } catch (error) {
      logDecoderParseError(
        provider: 'responses',
        eventType: (obj['type'] ?? event.event ?? 'response').toString(),
        error: error,
      );
    }
    return DecodeResult(chunks: chunks, completed: completed);
  }

  @override
  List<StreamChunk> onClosed() {
    if (_closed) return const <StreamChunk>[];
    _closed = true;
    if (completed) return const <StreamChunk>[];
    return _closeOpenSeries();
  }

  void _parseEvent(Map<String, dynamic> obj, List<StreamChunk> chunks) {
    final type = obj['type'];
    if (type == 'response.output_text.delta') {
      final delta = obj['delta'];
      if (delta is String && delta.isNotEmpty) {
        approxCompletionChars += delta.length;
        chunks.add(TextDelta(id: _ids.text(), text: delta));
      }
      return;
    }
    if (type == 'response.reasoning_summary_text.delta' ||
        type == 'response.reasoning_text.delta') {
      final delta = obj['delta'];
      if (delta is String && delta.isNotEmpty) {
        chunks.add(ReasoningDelta(id: _ids.reasoning(), text: delta));
      }
      return;
    }
    if (type == 'response.output_item.added') {
      final item = obj['item'];
      final idx = (obj['output_index'] ?? 0) as int;
      if (item is Map && (item['type'] ?? '') == 'function_call') {
        final callId = (item['call_id'] ?? '').toString();
        final name = (item['name'] ?? '').toString();
        final args = (item['arguments'] ?? '').toString();
        toolCallsByIndex[idx] = ResponsesFunctionCall(
          index: idx,
          callId: callId,
          name: name,
          args: args,
        );
        final eventId = _toolSeriesId(
          idx,
          vendorId: callId.isNotEmpty ? callId : (item['id'] ?? '').toString(),
        );
        _assignSeriesId(toolCallsByIndex[idx]!, eventId);
        chunks.addAll(_startTool(eventId, name: name, args: args));
      } else if (item is Map && _isImageGenerationType(item['type'])) {
        imagesByIndex.putIfAbsent(
          idx,
          () => ResponsesPendingImage(index: idx, base64: ''),
        );
        chunks.addAll(_startImage(idx, itemId: (item['id'] ?? '').toString()));
      } else if (item is Map && _isResponsesServerTool(item['type'])) {
        chunks.addAll(_startServerTool(item.cast<String, dynamic>()));
      }
      return;
    }
    if (type == 'response.image_generation_call.partial_image') {
      final b64 = (obj['partial_image_b64'] ?? '').toString();
      if (b64.isNotEmpty) {
        final idx = (obj['output_index'] ?? 0) as int;
        imagesByIndex[idx] = ResponsesPendingImage(
          index: idx,
          base64: b64,
          outputFormat: (obj['output_format'] ?? '').toString(),
        );
        final imageId = _imageSeriesId(
          idx,
          itemId: (obj['item_id'] ?? '').toString(),
        );
        chunks.addAll(_startImage(idx, itemId: imageId));
        chunks.add(ImageSnapshot(id: imageId, data: _rawImageBase64(b64)));
      }
      return;
    }
    if (type == 'response.function_call_arguments.delta') {
      final idx = (obj['output_index'] ?? 0) as int;
      final delta = (obj['delta'] ?? '').toString();
      final entry = toolCallsByIndex.putIfAbsent(
        idx,
        () => ResponsesFunctionCall(index: idx, callId: '', name: ''),
      );
      if (delta.isNotEmpty) entry.args += delta;
      final eventId = _toolSeriesId(idx, vendorId: entry.callId);
      _assignSeriesId(entry, eventId);
      if (_openToolIds.add(eventId) && !_endedToolIds.contains(eventId)) {
        chunks.add(ToolCallStart(id: eventId, toolName: entry.name));
      }
      if (delta.isNotEmpty) {
        chunks.add(ToolCallDelta(id: eventId, inputDelta: delta));
      }
      return;
    }
    if (type == 'response.output_item.done') {
      final item = obj['item'];
      final idx = (obj['output_index'] ?? 0) as int;
      if (item is Map && (item['type'] ?? '') == 'function_call') {
        final args = (item['arguments'] ?? '').toString();
        final entry = toolCallsByIndex.putIfAbsent(
          idx,
          () => ResponsesFunctionCall(
            index: idx,
            callId: (item['call_id'] ?? '').toString(),
            name: (item['name'] ?? '').toString(),
          ),
        );
        if (args.isNotEmpty) entry.args = args;
        if (entry.callId.isEmpty) {
          entry.callId = (item['call_id'] ?? '').toString();
        }
        if (entry.name.isEmpty) {
          entry.name = (item['name'] ?? '').toString();
        }
        final eventId = _toolSeriesId(
          idx,
          vendorId: entry.callId.isNotEmpty
              ? entry.callId
              : (item['id'] ?? '').toString(),
        );
        _assignSeriesId(entry, eventId);
        if (args.isNotEmpty && !_openToolIds.contains(eventId)) {
          chunks.addAll(_startTool(eventId, name: entry.name, args: args));
        }
        chunks.addAll(_endTool(eventId));
      } else if (item is Map && _isImageGenerationType(item['type'])) {
        final source = responsesImageGenerationSource(item);
        // Remote URLs are already renderable; only base64 needs saving.
        if (source.isNotEmpty && !_isRemoteImageUrl(source)) {
          imagesByIndex[idx] = ResponsesPendingImage(
            index: idx,
            base64: source,
            outputFormat: (item['output_format'] ?? item['outputFormat'] ?? '')
                .toString(),
          );
        }
        final imageId = _imageSeriesId(
          idx,
          itemId: (item['id'] ?? '').toString(),
        );
        chunks.addAll(_startImage(idx, itemId: imageId));
        if (source.isNotEmpty) {
          chunks.add(ImageSnapshot(id: imageId, data: _rawImageBase64(source)));
        }
        chunks.addAll(_endImage(imageId));
      } else if (item is Map && _isResponsesServerTool(item['type'])) {
        chunks.addAll(
          _endServerTool(
            item.cast<String, dynamic>(),
            fallbackStatus: ServerToolStatus.completed,
          ),
        );
      }
      return;
    }
    if (type == 'response.output_text.annotation.added') {
      _emitCitationAnnotation(obj['annotation'], chunks);
      return;
    }
    if (type == 'response.incomplete' || type == 'response.failed') {
      _onTerminal(obj, chunks, failed: true);
      return;
    }
    if (type is String &&
        type.contains('function_call') &&
        type != 'response.function_call_arguments.done') {
      final id = (obj['id'] ?? obj['call_id'] ?? '').toString();
      final name = (obj['name'] ?? obj['function']?['name'] ?? '').toString();
      final argsDelta =
          (obj['arguments'] ?? obj['arguments_delta'] ?? obj['delta'] ?? '')
              .toString();
      if (id.isNotEmpty || name.isNotEmpty) {
        final key = id.isNotEmpty ? id : name;
        final entry = toolCallsByKey.putIfAbsent(
          key,
          () => ResponsesFunctionCall(index: 0, callId: key, name: name),
        );
        if (name.isNotEmpty) entry.name = name;
        if (argsDelta.isNotEmpty) entry.args += argsDelta;
        final eventId = _toolEventIdsByKey.putIfAbsent(
          key,
          () => id.isNotEmpty ? id : _ids.next('tool'),
        );
        _assignSeriesId(entry, eventId);
        chunks.addAll(_startTool(eventId, name: entry.name, args: argsDelta));
      }
      return;
    }
    if (type == 'response.completed') {
      _onTerminal(obj, chunks, failed: false);
      return;
    }

    final output = obj['output'];
    if (output is Map) {
      final content = (output['content'] ?? '').toString();
      if (content.isNotEmpty) {
        approxCompletionChars += content.length;
        chunks.add(TextDelta(id: _ids.text(), text: content));
      }
      if (obj['usage'] != null) {
        _round = _mergeUsage(_round, obj['usage']);
        if (usage != null) chunks.add(Usage(usage!));
      }
    }
  }

  void _onTerminal(
    Map<String, dynamic> obj,
    List<StreamChunk> chunks, {
    required bool failed,
  }) {
    final response = obj['response'];
    if (response is Map) {
      final u = response['usage'];
      if (u != null) {
        _round = _mergeUsage(_round, u);
        if (usage != null) chunks.add(Usage(usage!));
      }
      final output = response['output'];
      outputItems = const <Map<String, dynamic>>[];
      if (output is List) {
        outputItems = [
          for (final it in output)
            if (it is Map) it.cast<String, dynamic>(),
        ];
        try {
          _collectCitations(output);
          _collectCompletedImages(output);
        } catch (_) {}
        _emitCollectedImages(chunks);
        _emitCollectedCitations(chunks);
        for (final item in outputItems) {
          if (_isResponsesServerTool(item['type']) &&
              !_endedServerToolIds.contains((item['id'] ?? '').toString())) {
            chunks.addAll(
              _endServerTool(
                item,
                fallbackStatus: failed
                    ? ServerToolStatus.failed
                    : ServerToolStatus.completed,
              ),
            );
          }
        }
      }
    }
    final status = failed
        ? ServerToolStatus.failed
        : ServerToolStatus.completed;
    chunks.addAll(_closeOpenSeries(serverStatus: status));
    completed = true;
  }

  void _collectCitations(List<dynamic> output) {
    citations.clear();
    var idx = 1;
    final seen = <String>{};
    for (final it in output) {
      if (it is! Map || it['type'] != 'message') continue;
      final content = it['content'];
      if (content is! List) continue;
      for (final block in content) {
        if (block is! Map) continue;
        final anns = block['annotations'] as List? ?? const <dynamic>[];
        for (final an in anns) {
          if (an is! Map) continue;
          if ((an['type'] ?? '') != 'url_citation') continue;
          final url = (an['url'] ?? '').toString();
          if (url.isEmpty || seen.contains(url)) continue;
          final title = (an['title'] ?? '').toString();
          citations.add(<String, dynamic>{
            'index': idx,
            'url': url,
            if (title.isNotEmpty) 'title': title,
          });
          seen.add(url);
          idx += 1;
        }
      }
    }
  }

  void _collectCompletedImages(List<dynamic> output) {
    for (var outputIndex = 0; outputIndex < output.length; outputIndex++) {
      final it = output[outputIndex];
      if (it is! Map || !_isImageGenerationType(it['type'])) continue;
      final source = responsesImageGenerationSource(it);
      if (source.isEmpty || _isRemoteImageUrl(source)) continue;
      imagesByIndex[outputIndex] = ResponsesPendingImage(
        index: outputIndex,
        base64: source,
        outputFormat: (it['output_format'] ?? it['outputFormat'] ?? '')
            .toString(),
      );
      final itemId = (it['id'] ?? '').toString();
      if (itemId.isNotEmpty) {
        _imageIdsByIndex.putIfAbsent(outputIndex, () => itemId);
      }
    }
  }

  void _emitCitationAnnotation(dynamic annotation, List<StreamChunk> chunks) {
    if (annotation is! Map) return;
    if ((annotation['type'] ?? '') != 'url_citation') return;
    final url = (annotation['url'] ?? '').toString();
    if (url.isEmpty || _seenCitationUrls.contains(url)) return;
    final title = (annotation['title'] ?? '').toString();
    citations.add(<String, dynamic>{
      'index': citations.length + 1,
      'url': url,
      if (title.isNotEmpty) 'title': title,
    });
    _seenCitationUrls.add(url);
    _emittedCitationEvents = true;
    chunks.add(
      Annotations(<StreamAnnotation>[
        UrlCitationAnnotation(url: url, title: title),
      ], id: _ids.searchSticky()),
    );
  }

  void _emitCollectedCitations(List<StreamChunk> chunks) {
    if (citations.isEmpty || _emittedCitationEvents) return;
    _emittedCitationEvents = true;
    chunks.add(
      Annotations([
        for (final item in citations)
          UrlCitationAnnotation(
            url: (item['url'] ?? '').toString(),
            title: (item['title'] ?? '').toString(),
          ),
      ], id: _ids.searchSticky()),
    );
  }

  void _emitCollectedImages(List<StreamChunk> chunks) {
    final sorted = imagesByIndex.keys.toList()..sort();
    for (final idx in sorted) {
      final image = imagesByIndex[idx]!;
      if (image.base64.isEmpty) continue;
      final id = _imageSeriesId(idx);
      chunks.addAll(_startImage(idx, itemId: id));
      if (!_endedImageIds.contains(id)) {
        chunks.add(ImageSnapshot(id: id, data: _rawImageBase64(image.base64)));
        chunks.addAll(_endImage(id));
      }
    }
  }

  String _toolSeriesId(int index, {String vendorId = ''}) {
    final existing = _toolEventIdsByIndex[index];
    if (existing != null) return existing;
    final id = vendorId.isNotEmpty ? vendorId : _ids.next('tool');
    _toolEventIdsByIndex[index] = id;
    return id;
  }

  /// Persist the first-seen stream id. Late vendor `call_id` stays on [callId].
  void _assignSeriesId(ResponsesFunctionCall entry, String eventId) {
    if (entry.seriesId.isEmpty) {
      entry.seriesId = eventId;
    }
  }

  ResponsesFunctionCall _withSeriesId(
    ResponsesFunctionCall call,
    String? eventId,
  ) {
    final fallback = eventId != null && eventId.isNotEmpty
        ? eventId
        : call.callId;
    _assignSeriesId(call, fallback);
    return call;
  }

  List<StreamChunk> _startTool(
    String id, {
    required String name,
    String args = '',
  }) {
    if (_endedToolIds.contains(id)) return const <StreamChunk>[];
    final chunks = <StreamChunk>[];
    if (_openToolIds.add(id)) {
      chunks.add(ToolCallStart(id: id, toolName: name));
    }
    if (args.isNotEmpty) {
      chunks.add(ToolCallDelta(id: id, inputDelta: args));
    }
    return chunks;
  }

  List<StreamChunk> _endTool(String id) {
    _openToolIds.remove(id);
    if (!_endedToolIds.add(id)) return const <StreamChunk>[];
    return <StreamChunk>[ToolCallEnd(id)];
  }

  String _imageSeriesId(int index, {String itemId = ''}) {
    final existing = _imageIdsByIndex[index];
    if (existing != null) return existing;
    final id = itemId.isNotEmpty ? itemId : _ids.next('image');
    _imageIdsByIndex[index] = id;
    return id;
  }

  List<StreamChunk> _startImage(int index, {String itemId = ''}) {
    final id = _imageSeriesId(index, itemId: itemId);
    if (_endedImageIds.contains(id) || !_openImageIds.add(id)) {
      return const <StreamChunk>[];
    }
    return <StreamChunk>[ImageStart(id: id)];
  }

  List<StreamChunk> _endImage(String id) {
    _openImageIds.remove(id);
    if (!_endedImageIds.add(id)) return const <StreamChunk>[];
    return <StreamChunk>[ImageEnd(id)];
  }

  List<StreamChunk> _startServerTool(Map<String, dynamic> item) {
    final id = (item['id'] ?? '').toString();
    if (id.isEmpty) return const <StreamChunk>[];
    if (_endedServerToolIds.contains(id) || !_openServerToolIds.add(id)) {
      return const <StreamChunk>[];
    }
    return <StreamChunk>[
      ServerToolStart(
        id: id,
        toolName: _serverToolName((item['type'] ?? '').toString()),
        input: item['action'],
      ),
    ];
  }

  List<StreamChunk> _endServerTool(
    Map<String, dynamic> item, {
    required ServerToolStatus fallbackStatus,
  }) {
    final id = (item['id'] ?? '').toString();
    if (id.isEmpty) return const <StreamChunk>[];
    if (!_openServerToolIds.contains(id) && !_endedServerToolIds.contains(id)) {
      return <StreamChunk>[
        ..._startServerTool(item),
        ..._finishServerTool(id, item, fallbackStatus),
      ];
    }
    return _finishServerTool(id, item, fallbackStatus);
  }

  List<StreamChunk> _finishServerTool(
    String id,
    Map<String, dynamic> item,
    ServerToolStatus fallbackStatus,
  ) {
    _openServerToolIds.remove(id);
    if (!_endedServerToolIds.add(id)) return const <StreamChunk>[];
    return <StreamChunk>[
      ServerToolEnd(
        id: id,
        input: item['action'],
        output: item['output'] ?? item['result'] ?? item['action'],
        status: _serverToolStatus(
          (item['status'] ?? '').toString(),
          fallback: fallbackStatus,
        ),
      ),
    ];
  }

  List<StreamChunk> _closeOpenSeries({
    ServerToolStatus serverStatus = ServerToolStatus.completed,
  }) {
    final chunks = <StreamChunk>[];
    for (final id in _openToolIds.toList()) {
      chunks.addAll(_endTool(id));
    }
    for (final id in _openImageIds.toList()) {
      chunks.addAll(_endImage(id));
    }
    for (final id in _openServerToolIds.toList()) {
      chunks.addAll(
        _finishServerTool(id, <String, dynamic>{'id': id}, serverStatus),
      );
    }
    return chunks;
  }
}

bool _isResponsesServerTool(dynamic type) {
  final value = (type ?? '').toString();
  if (value.isEmpty ||
      value == 'function_call' ||
      value == 'message' ||
      value == 'reasoning' ||
      _isImageGenerationType(value)) {
    return false;
  }
  if (value.contains('search')) return true;
  const excluded = <String>{
    'custom_tool_call',
    'computer_call',
    'local_shell_call',
    'shell_call',
  };
  return value.endsWith('_call') && !excluded.contains(value);
}

String _serverToolName(String type) {
  final local = type.contains(':') ? type.split(':').last : type;
  if (local.contains('web_search') || local == 'search') return 'search_web';
  return local.replaceAll(RegExp(r'_call$'), '');
}

ServerToolStatus _serverToolStatus(
  String raw, {
  required ServerToolStatus fallback,
}) {
  return switch (raw) {
    'failed' || 'incomplete' || 'cancelled' => ServerToolStatus.failed,
    'completed' => ServerToolStatus.completed,
    'in_progress' => ServerToolStatus.inProgress,
    _ => fallback,
  };
}

bool _isRemoteImageUrl(String raw) {
  final trimmed = raw.trim().toLowerCase();
  return trimmed.startsWith('http://') || trimmed.startsWith('https://');
}

String _rawImageBase64(String raw) {
  final marker = ';base64,';
  final index = raw.indexOf(marker);
  if (raw.startsWith('data:') && index >= 0) {
    return raw.substring(index + marker.length);
  }
  return raw;
}

/// Image payload of a Responses `image_generation` output item.
///
/// OpenRouter returns `imageUrl` / `imageB64` (bare or wrapped in `{url: ...}`);
/// OpenAI returns base64 in `result`.
String responsesImageGenerationSource(Map<dynamic, dynamic> item) {
  for (final key in const <String>[
    'imageUrl',
    'image_url',
    'imageB64',
    'image_b64',
    'result',
  ]) {
    final raw = item[key];
    final value = raw is Map ? raw['url'] : raw;
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

bool _isImageGenerationType(dynamic type) {
  return type == 'image_generation_call' ||
      type == 'openrouter:image_generation';
}

TokenUsage? _mergeUsage(TokenUsage? current, dynamic rawUsage) {
  if (rawUsage is! Map) return current;
  final details =
      rawUsage['prompt_tokens_details'] ?? rawUsage['input_tokens_details'];
  final cachedTokens = details is Map ? _readInt(details['cached_tokens']) : 0;
  return (current ?? const TokenUsage()).merge(
    TokenUsage(
      promptTokens: _readInt(
        rawUsage['prompt_tokens'] ?? rawUsage['input_tokens'],
      ),
      completionTokens: _readInt(
        rawUsage['completion_tokens'] ?? rawUsage['output_tokens'],
      ),
      cachedTokens: cachedTokens,
    ),
  );
}

int _readInt(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
