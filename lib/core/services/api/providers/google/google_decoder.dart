import 'dart:convert';

import '../../../../models/token_usage.dart';
import '../../stream/sse_event.dart';
import '../../stream/stream_chunk.dart';
import '../../stream/stream_chunk_decoder.dart';
import '../../stream/stream_chunk_ids.dart';

/// One Gemini `functionCall` collected during a generateContent stream.
class GoogleFunctionCall {
  GoogleFunctionCall({
    required this.id,
    this.apiId,
    required this.name,
    required this.args,
    this.result = '',
    this.thoughtSigKey,
    this.thoughtSigVal,
    required this.part,
  });

  final String id;
  final String? apiId;
  final String name;
  final Map<String, dynamic> args;
  String result;
  final String? thoughtSigKey;
  final dynamic thoughtSigVal;
  final Map<String, dynamic> part;
}

/// Buffered inline image the provider must persist to disk.
class GooglePendingImage {
  const GooglePendingImage({
    required this.mimeType,
    required this.data,
    this.trailingText = '',
  });

  final String mimeType;
  final String data;
  final String trailingText;
}

/// `fileData` URI the provider must download before the image can be buffered.
class GoogleRemoteImage {
  const GoogleRemoteImage({
    required this.mimeType,
    required this.uri,
    this.thoughtSigKey,
    this.thoughtSigVal,
  });

  final String mimeType;
  final String uri;
  final String? thoughtSigKey;
  final dynamic thoughtSigVal;
}

/// Stateful Gemini / Vertex Gemini SSE decoder. One instance per HTTP response.
class GoogleStreamDecoder implements StreamChunkDecoder {
  GoogleStreamDecoder({
    this.isGemini3 = false,
    this.persistThoughtSigs = false,
    this.expectImage = false,
    this.receivedImage = false,
    this.initialUsage,
    List<Map<String, dynamic>>? citations,
    String sourceId = 'stream',
  }) : usage = initialUsage,
       builtinCitations = citations ?? <Map<String, dynamic>>[],
       _ids = StreamChunkIds(sourceId);

  final bool isGemini3;
  final bool persistThoughtSigs;
  final bool expectImage;
  final TokenUsage? initialUsage;
  final StreamChunkIds _ids;

  bool receivedImage;
  TokenUsage? usage;
  String? finishReason;
  bool retryMalformedResponse = false;
  bool streamComplete = false;

  final List<GoogleFunctionCall> functionCalls = <GoogleFunctionCall>[];
  final List<Map<String, dynamic>> roundModelParts = <Map<String, dynamic>>[];
  String? textThoughtSigKey;
  dynamic textThoughtSigVal;
  final List<Map<String, dynamic>> imageThoughtSigs = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> builtinCitations;

  String imageMime = 'image/png';
  String pendingImageData = '';
  String pendingImageTrailingText = '';
  bool bufferingInlineImage = false;

  final List<GoogleRemoteImage> _pendingRemoteImages = <GoogleRemoteImage>[];
  bool _holdTextForImage = false;
  String? _lastCodeExecId;
  String? _imageId;
  bool _imageStarted = false;
  bool _imageEnded = false;
  int _syntheticPartIndex = 0;
  bool _closed = false;

  bool get emittedImageEvents => _imageStarted;

  bool isClientFunctionCall(String id) =>
      functionCalls.any((call) => call.id == id);

  GoogleFunctionCall? functionCallById(String id) {
    for (final call in functionCalls) {
      if (call.id == id) return call;
    }
    return null;
  }

  bool get canFinishNow =>
      finishReason != null &&
      !retryMalformedResponse &&
      functionCalls.isEmpty &&
      (!expectImage || receivedImage);

  List<GoogleRemoteImage> takePendingRemoteImages() {
    final out = List<GoogleRemoteImage>.from(_pendingRemoteImages);
    _pendingRemoteImages.clear();
    return out;
  }

  List<StreamChunk> ingestImageData(
    String mime,
    String data, {
    String? thoughtSigKey,
    dynamic thoughtSigVal,
  }) {
    if (persistThoughtSigs && thoughtSigKey != null && thoughtSigVal != null) {
      _rememberImageSig(thoughtSigKey, thoughtSigVal);
    }
    final chunks = bufferInlineImage(mime, data);
    if (canFinishNow) streamComplete = true;
    return chunks;
  }

  List<StreamChunk> bufferInlineImage(String mime, String data) {
    imageMime = mime.isNotEmpty ? mime : 'image/png';
    final hasExisting = pendingImageData.isNotEmpty;
    final prevLooksComplete = hasExisting && pendingImageData.endsWith('=');
    final newFrame = hasExisting && _looksLikeImageStart(data);
    final replaced = prevLooksComplete || newFrame;
    if (replaced) {
      pendingImageData = data;
    } else {
      pendingImageData += data;
    }
    bufferingInlineImage = true;
    receivedImage = true;
    return _imageChunks(replaced: replaced, appended: replaced ? '' : data);
  }

  /// Text held after a `fileData` URI when the provider failed to download it.
  List<StreamChunk> takeOrphanedTrailingText() {
    if (bufferingInlineImage || pendingImageData.isNotEmpty) {
      return const <StreamChunk>[];
    }
    if (pendingImageTrailingText.isEmpty) return const <StreamChunk>[];
    final text = pendingImageTrailingText;
    pendingImageTrailingText = '';
    _holdTextForImage = false;
    return <StreamChunk>[TextDelta(id: _ids.text(), text: text)];
  }

  GooglePendingImage? takeBufferedImage() {
    if (!bufferingInlineImage || pendingImageData.isEmpty) return null;
    final image = GooglePendingImage(
      mimeType: imageMime,
      data: pendingImageData,
      trailingText: pendingImageTrailingText,
    );
    bufferingInlineImage = false;
    pendingImageData = '';
    pendingImageTrailingText = '';
    return image;
  }

  List<StreamChunk> citationChunks() {
    if (builtinCitations.isEmpty) return const <StreamChunk>[];
    final searchId = _ids.searchSticky();
    return <StreamChunk>[
      ServerToolStart(id: searchId, toolName: 'builtin_search'),
      ServerToolEnd(
        id: searchId,
        output: <String, dynamic>{'items': builtinCitations},
      ),
    ];
  }

  @override
  DecodeResult accept(SseEvent event) {
    if (_closed || streamComplete) {
      return const DecodeResult(completed: true);
    }
    final data = event.data;
    if (data.isEmpty) return const DecodeResult();
    if (data == '[DONE]') {
      streamComplete = true;
      return DecodeResult(chunks: _closeOpenImage(), completed: true);
    }

    late final Map<String, dynamic> obj;
    try {
      final decoded = jsonDecode(data);
      if (decoded is! Map) return const DecodeResult();
      obj = decoded.cast<String, dynamic>();
    } catch (_) {
      return const DecodeResult();
    }

    final chunks = <StreamChunk>[];
    try {
      _parseEvent(obj, chunks);
    } catch (_) {
      return const DecodeResult();
    }

    if (finishReason == 'MALFORMED_RESPONSE' && functionCalls.isEmpty) {
      retryMalformedResponse = true;
    }
    if (canFinishNow) streamComplete = true;
    return DecodeResult(chunks: chunks, completed: streamComplete);
  }

  @override
  List<StreamChunk> onClosed() {
    if (_closed) return const <StreamChunk>[];
    _closed = true;
    return _closeOpenImage();
  }

  void _parseEvent(Map<String, dynamic> obj, List<StreamChunk> chunks) {
    final um = obj['usageMetadata'];
    if (um is Map<String, dynamic>) {
      usage = (usage ?? const TokenUsage()).merge(
        TokenUsage(
          promptTokens: (um['promptTokenCount'] ?? 0) as int,
          completionTokens: (um['candidatesTokenCount'] ?? 0) as int,
          totalTokens: (um['totalTokenCount'] ?? 0) as int,
        ),
      );
      chunks.add(Usage(usage!));
    }

    final candidates = obj['candidates'];
    if (candidates is! List || candidates.isEmpty) return;

    var textDelta = '';
    var reasoningDelta = '';

    for (final cand in candidates) {
      if (cand is! Map) continue;
      final content = cand['content'];
      if (content is! Map) continue;
      final parts = content['parts'];
      if (parts is! List) continue;

      for (final p in parts) {
        if (p is! Map) continue;
        _parsePart(
          p,
          chunks,
          onText: (value) => textDelta += value,
          onReasoning: (value) => reasoningDelta += value,
        );
      }

      final fr = cand['finishReason'];
      if (fr is String && fr.isNotEmpty) finishReason = fr;

      final gm = cand['groundingMetadata'] ?? obj['groundingMetadata'];
      final cite = _parseCitations(gm);
      if (cite.isNotEmpty) {
        final existingUrls = builtinCitations
            .map((e) => e['url']?.toString() ?? '')
            .toSet();
        for (final it in cite) {
          final u = it['url']?.toString() ?? '';
          if (u.isEmpty || existingUrls.contains(u)) continue;
          builtinCitations.add(it);
          existingUrls.add(u);
        }
        chunks.addAll(citationChunks());
      }
    }

    if (reasoningDelta.isNotEmpty) {
      chunks.add(ReasoningDelta(id: _ids.reasoning(), text: reasoningDelta));
    }
    if (textDelta.isNotEmpty) {
      chunks.add(TextDelta(id: _ids.text(), text: textDelta));
    }
  }

  void _parsePart(
    Map<dynamic, dynamic> p,
    List<StreamChunk> chunks, {
    required void Function(String text) onText,
    required void Function(String text) onReasoning,
  }) {
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
    final fc = p['functionCall'];
    final rawPart = Map<String, dynamic>.from(p);

    if (isGemini3 && !thought && rawPart.isNotEmpty) {
      roundModelParts.add(rawPart);
    }

    if (persistThoughtSigs &&
        !thought &&
        partThoughtSigKey != null &&
        partThoughtSigVal != null) {
      if (t.isNotEmpty && textThoughtSigKey == null) {
        textThoughtSigKey = partThoughtSigKey;
        textThoughtSigVal = partThoughtSigVal;
      }
    }

    if (t.isNotEmpty) {
      if (thought) {
        onReasoning(t);
      } else if (bufferingInlineImage || _holdTextForImage) {
        pendingImageTrailingText += t;
      } else {
        onText(t);
      }
    }

    final inline = p['inlineData'] ?? p['inline_data'];
    if (inline is Map) {
      final mime = (inline['mimeType'] ?? inline['mime_type'] ?? 'image/png')
          .toString();
      final data = (inline['data'] ?? '').toString();
      if (data.isNotEmpty) {
        if (persistThoughtSigs &&
            partThoughtSigKey != null &&
            partThoughtSigVal != null) {
          _rememberImageSig(partThoughtSigKey, partThoughtSigVal);
        }
        chunks.addAll(bufferInlineImage(mime, data));
      }
    }

    final fileData = p['fileData'] ?? p['file_data'];
    if (fileData is Map) {
      final mime =
          (fileData['mimeType'] ?? fileData['mime_type'] ?? 'image/png')
              .toString();
      final uri =
          (fileData['fileUri'] ?? fileData['file_uri'] ?? fileData['uri'] ?? '')
              .toString();
      if (uri.startsWith('http')) {
        _holdTextForImage = true;
        _pendingRemoteImages.add(
          GoogleRemoteImage(
            mimeType: mime,
            uri: uri,
            thoughtSigKey: partThoughtSigKey,
            thoughtSigVal: partThoughtSigVal,
          ),
        );
      }
    }

    final codeExec = p['executableCode'] ?? p['executable_code'];
    if (codeExec is Map) {
      final lang = (codeExec['language'] ?? '').toString().toLowerCase();
      final code = (codeExec['code'] ?? '').toString();
      if (code.isNotEmpty) {
        final ceId = _ids.next('code_exec');
        _lastCodeExecId = ceId;
        chunks.add(ToolCallStart(id: ceId, toolName: 'code_execution'));
        chunks.add(
          ToolCallDelta(
            id: ceId,
            inputDelta: jsonEncode(<String, dynamic>{
              'language': lang,
              'code': code,
            }),
          ),
        );
        chunks.add(ToolCallEnd(ceId));
      }
    }

    final codeResult = p['codeExecutionResult'] ?? p['code_execution_result'];
    if (codeResult is Map) {
      final outcome = (codeResult['outcome'] ?? '').toString();
      final output = (codeResult['output'] ?? '').toString();
      final resultId = _lastCodeExecId ?? _ids.next('code_exec');
      chunks.add(ServerToolStart(id: resultId, toolName: 'code_execution'));
      chunks.add(
        ServerToolEnd(id: resultId, output: output.isEmpty ? outcome : output),
      );
    }

    if (fc is Map) {
      final name = (fc['name'] ?? '').toString();
      var args = const <String, dynamic>{};
      final rawArgs = fc['args'];
      if (rawArgs is Map) {
        args = rawArgs.cast<String, dynamic>();
      } else if (rawArgs is String && rawArgs.isNotEmpty) {
        try {
          args = (jsonDecode(rawArgs) as Map).cast<String, dynamic>();
        } catch (_) {}
      }
      final apiId = fc['id']?.toString();
      final id = _effectiveToolCallId(apiId, 'call', _syntheticPartIndex++);

      String? thoughtSigKey;
      dynamic thoughtSigVal;
      if (p.containsKey('thoughtSignature')) {
        thoughtSigKey = 'thoughtSignature';
        thoughtSigVal = p['thoughtSignature'];
      } else if (p.containsKey('thought_signature')) {
        thoughtSigKey = 'thought_signature';
        thoughtSigVal = p['thought_signature'];
      }

      final metadata = <String, dynamic>{
        'google': <String, dynamic>{
          'part': rawPart,
          if (thoughtSigKey != null && thoughtSigVal != null)
            'thoughtSigKey': thoughtSigKey,
          if (thoughtSigKey != null && thoughtSigVal != null)
            'thoughtSigVal': thoughtSigVal,
        },
      };
      functionCalls.add(
        GoogleFunctionCall(
          id: id,
          apiId: apiId,
          name: name,
          args: args,
          thoughtSigKey: thoughtSigKey,
          thoughtSigVal: thoughtSigVal,
          part: rawPart,
        ),
      );
      chunks.add(ToolCallStart(id: id, toolName: name, metadata: metadata));
      chunks.add(
        ToolCallDelta(id: id, inputDelta: jsonEncode(args), metadata: metadata),
      );
      chunks.add(ToolCallEnd(id));
    }
  }

  List<StreamChunk> _imageChunks({
    required bool replaced,
    required String appended,
  }) {
    final chunks = <StreamChunk>[];
    _imageId ??= _ids.next('image');
    if (!_imageStarted) {
      _imageStarted = true;
      chunks.add(ImageStart(id: _imageId!, mimeType: imageMime));
    }
    if (replaced) {
      chunks.add(ImageSnapshot(id: _imageId!, data: pendingImageData));
    } else if (appended.isNotEmpty) {
      chunks.add(ImageDelta(id: _imageId!, data: appended));
    }
    return chunks;
  }

  List<StreamChunk> _closeOpenImage() {
    if (!_imageStarted || _imageEnded || _imageId == null) {
      return const <StreamChunk>[];
    }
    _imageEnded = true;
    return <StreamChunk>[ImageEnd(_imageId!)];
  }

  void _rememberImageSig(String key, dynamic value) {
    final exists = imageThoughtSigs.any(
      (e) => e['k'] == key && e['v'] == value,
    );
    if (!exists) {
      imageThoughtSigs.add(<String, dynamic>{'k': key, 'v': value});
    }
  }

  List<Map<String, dynamic>> _parseCitations(dynamic gm) {
    final out = <Map<String, dynamic>>[];
    if (gm is! Map) return out;
    final chunks = gm['groundingChunks'] as List? ?? const <dynamic>[];
    var idx = 1;
    final seen = <String>{};
    for (final ch in chunks) {
      if (ch is! Map) continue;
      final web =
          ch['web'] as Map? ?? ch['webSite'] as Map? ?? ch['webPage'] as Map?;
      if (web is! Map) continue;
      final uri = (web['uri'] ?? web['url'] ?? '').toString();
      if (uri.isEmpty) continue;
      if (seen.contains(uri)) continue;
      seen.add(uri);
      final title = (web['title'] ?? web['name'] ?? uri).toString();
      final id = 'c${idx.toString().padLeft(2, '0')}';
      out.add(<String, dynamic>{
        'id': id,
        'index': idx,
        'title': title,
        'url': uri,
      });
      idx++;
    }
    return out;
  }
}

String _effectiveToolCallId(
  dynamic rawId,
  String fallbackPrefix,
  Object index,
) {
  final id = rawId?.toString().trim() ?? '';
  if (id.isNotEmpty) return id;
  return '${fallbackPrefix}_${DateTime.now().microsecondsSinceEpoch}_$index';
}

bool _looksLikeImageStart(String data) {
  const prefixes = <String>['/9j/', 'iVBOR', 'R0lGOD', 'UklGR', 'Qk', 'SUkq'];
  for (final prefix in prefixes) {
    if (data.startsWith(prefix)) return true;
  }
  return false;
}
