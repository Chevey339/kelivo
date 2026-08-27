import 'dart:convert';

import '../../../../utils/multimodal_input_utils.dart';
import '../../../../../utils/sandbox_path_resolver.dart';
import '../../chat_api_helpers.dart';

/// The replay metadata a tool card of a Claude turn carries: every response
/// the API produced for the turn so far, the current one last. A turn that
/// hands off between a hosted and a client tool, or resumes after
/// `pause_turn`, spans several responses, and the protocol replays each as its
/// own assistant message with the client results between them — so the
/// boundary is recorded here rather than inferred from the blocks later.
Map<String, dynamic> claudeReplayMetadata(
  List<List<Map<String, dynamic>>> responses,
) => <String, dynamic>{
  'anthropic': <String, dynamic>{'responses': responses},
};

/// Anthropic rejects an empty text block, and dropping `content` altogether
/// leaves the tool call unanswered, which reads to the model as a malformed
/// turn. A tool that produced nothing gets an explicit placeholder instead.
String claudeToolResultContent(String result) =>
    result.trim().isEmpty ? '(no output)' : result;

String joinedTextOfBlocks(Iterable<Map> blocks) => blocks
    .where((block) => block['type'] == 'text')
    .map((block) => (block['text'] ?? '').toString())
    .join();

Set<String> toolUseIdsInBlocks(
  Iterable<Map> blocks, {
  bool clientOnly = false,
}) {
  return {
    for (final block in blocks)
      if (block['type'] == 'tool_use' ||
          (!clientOnly && block['type'] == 'server_tool_use'))
        if ((block['id'] ?? '').toString() case final id when id.isNotEmpty) id,
  };
}

Set<String> toolResultIdsInBlocks(Iterable<Map> blocks) {
  return {
    for (final block in blocks)
      if ((block['type'] ?? '').toString().endsWith('_tool_result'))
        if ((block['tool_use_id'] ?? '').toString() case final id
            when id.isNotEmpty)
          id,
  };
}

/// Turns the app's message history into the Anthropic `messages` array.
///
/// A tool turn is persisted as one assistant message holding the cards, the
/// `tool` message of each card, and the text of the whole turn as a plain
/// assistant message after them. Replayed, it becomes the responses the API
/// produced — see [claudeReplayMetadata] — each its own assistant message
/// behind the client results it waited for, with the turn's text folded into
/// them rather than sent again.
class ClaudeHistory {
  ClaudeHistory({
    required this.replayServerToolBlocks,
    required this.skipRedactedThinkingBlocks,
    this.skipImageParsing = false,
    this.userImagePaths,
  });

  /// Only Anthropic runs a server tool or decrypts what one returned, so
  /// everywhere else its blocks are dropped and the call replays as the
  /// synthesised client pair, exactly as it did before these tools existed.
  final bool replayServerToolBlocks;
  final bool skipRedactedThinkingBlocks;
  final bool skipImageParsing;
  final List<String>? userImagePaths;

  /// The blocks of one response as this endpoint may be sent them.
  List<Map<String, dynamic>> sanitize(Iterable<Map> blocks) {
    return [
      for (final block in blocks)
        if (_keepBlock((block['type'] ?? '').toString()))
          block.map((key, value) => MapEntry(key.toString(), value)),
    ];
  }

  bool _keepBlock(String type) {
    if (skipRedactedThinkingBlocks && type == 'redacted_thinking') return false;
    if (!replayServerToolBlocks &&
        (type == 'server_tool_use' || type.endsWith('_tool_result'))) {
      return false;
    }
    return true;
  }

  /// [messages] with the system prompt already taken out.
  Future<List<Map<String, dynamic>>> build(
    List<Map<String, dynamic>> messages,
  ) async {
    final out = <Map<String, dynamic>>[];
    final pendingResults = <Map<String, dynamic>>[];
    final replayedClientCalls = <String>{};
    // The API refuses `image` blocks in an assistant turn, yet a chart the
    // model drew is what the user's next question is about. Such images wait
    // here and open the following user message, so the model still sees them.
    final carriedImages = <Map<String, dynamic>>[];
    _ReplayedTurn? turn;

    /// A result is sent only once the call it answers has been: the API
    /// rejects one pointing at a `tool_use` that is not in the history.
    void flushResults({Set<String>? only}) {
      final taken = <Map<String, dynamic>>[];
      pendingResults.removeWhere((result) {
        final id = (result['tool_use_id'] ?? '').toString();
        if (only != null && !only.contains(id)) return false;
        if (replayedClientCalls.contains(id)) taken.add(result);
        return true;
      });
      if (taken.isNotEmpty) out.add({'role': 'user', 'content': taken});
    }

    /// Emits the next response of [turn], behind the client results of the
    /// one before it. Without any in between the two are one assistant turn.
    void emitResponse(_ReplayedTurn turn) {
      final blocks = turn.responses[turn.emitted];
      if (turn.emitted > 0) {
        flushResults(
          only: toolUseIdsInBlocks(
            turn.responses[turn.emitted - 1],
            clientOnly: true,
          ),
        );
      }
      final last = turn.messages.lastOrNull;
      if (last != null && identical(out.last, last)) {
        (last['content'] as List).addAll(blocks);
      } else {
        final message = <String, dynamic>{
          'role': 'assistant',
          'content': blocks,
        };
        out.add(message);
        turn.messages.add(message);
      }
      replayedClientCalls.addAll(toolUseIdsInBlocks(blocks, clientOnly: true));
      turn.emitted++;
    }

    /// The persisted assistant message after a replayed turn aggregates the
    /// text of every response of it, which the replayed blocks already carry.
    /// Only what they stop short of — a snapshot cut mid-stream, or a last
    /// response that had no card to record it — is still to be sent; on any
    /// other disagreement the blocks win, being what the API produced.
    void foldTurnText(_ReplayedTurn turn, Map<String, dynamic> m) {
      final said = turn.text.trim();
      final text = (m['content'] ?? '').toString().trim();
      final rest = said.isEmpty
          ? text
          : text.startsWith(said)
          ? text.substring(said.length).trim()
          : '';
      // Nothing left to say. The results may now sit next to the user message
      // after them, which the API combines into the one turn they already were.
      if (rest.isEmpty) return;
      final last = turn.messages.lastOrNull;
      if (pendingResults.isEmpty && last != null && identical(out.last, last)) {
        (last['content'] as List).add({'type': 'text', 'text': rest});
      } else {
        flushResults();
        out.add({'role': 'assistant', 'content': rest});
      }
    }

    for (var i = 0; i < messages.length; i++) {
      final m = messages[i];
      final role = (m['role'] ?? 'user').toString();
      if (role == 'tool') {
        final id = (m['tool_call_id'] ?? '').toString();
        // A server tool replayed as its own blocks already carries its result.
        if (id.isNotEmpty && !(turn?.serverToolIds.contains(id) ?? false)) {
          pendingResults.add({
            'type': 'tool_result',
            'tool_use_id': id,
            'content': claudeToolResultContent((m['content'] ?? '').toString()),
          });
        }
        continue;
      }

      if (role == 'assistant' && m['tool_calls'] is! List && _hasMedia(m)) {
        final split = await _splitParts(m, includeUserPaths: false);
        carriedImages.addAll(split.images);
      }

      if (turn != null) {
        while (turn.emitted < turn.responses.length) {
          emitResponse(turn);
        }
        // With its images carried forward, an assistant message is plain text.
        if (role == 'assistant' && m['tool_calls'] is! List) {
          foldTurnText(turn, m);
          turn = null;
          continue;
        }
        turn = null;
      }
      flushResults();

      if (role == 'assistant' && m['tool_calls'] is List) {
        final toolCalls = m['tool_calls'] as List;
        turn = _readTurn(toolCalls);
        if (turn != null) {
          if (turn.responses.isNotEmpty) emitResponse(turn);
        } else {
          // Nothing recorded of the turn: rebuild it from the calls.
          final blocks = <Map<String, dynamic>>[];
          final text = (m['content'] ?? '').toString();
          if (text.trim().isNotEmpty && text.trim() != '\n\n') {
            blocks.add({'type': 'text', 'text': text});
          }
          for (final tc in toolCalls.whereType<Map>()) {
            final block = _toolUseBlockFromToolCall(tc);
            if (block != null) blocks.add(block);
          }
          if (blocks.isNotEmpty) {
            out.add({'role': 'assistant', 'content': blocks});
            replayedClientCalls.addAll(toolUseIdsInBlocks(blocks));
          }
        }
        continue;
      }

      out.add(
        await _plainMessage(
          m,
          role,
          isLast: i == messages.length - 1,
          carriedImages: carriedImages,
        ),
      );
    }

    if (turn != null && turn.emitted < turn.responses.length) {
      // History cut off at a client result: the responses still to come would
      // prefill the answer, so they go, and with them the hosted calls whose
      // results were only in them — replayed open, the API rejects those.
      final lostResults = toolResultIdsInBlocks(
        turn.responses.skip(turn.emitted).expand((blocks) => blocks),
      );
      for (final message in turn.messages) {
        final blocks = message['content'] as List;
        blocks.removeWhere(
          (block) =>
              block['type'] == 'server_tool_use' &&
              lostResults.contains((block['id'] ?? '').toString()),
        );
        if (blocks.isEmpty) out.remove(message);
      }
    }
    flushResults();
    return out;
  }

  /// The turn a persisted tool message records, read off the fullest of its
  /// cards: each card holds the responses up to the one that last wrote it,
  /// so the last one written holds them all. Null when none recorded any.
  _ReplayedTurn? _readTurn(List toolCalls) {
    List<List<Map<String, dynamic>>>? recorded;
    for (final tc in toolCalls.whereType<Map>()) {
      final responses = _recordedResponses(tc);
      if (responses != null && responses.length > (recorded?.length ?? 0)) {
        recorded = responses;
      }
    }
    if (recorded == null) return null;

    final cards = <String, Map>{
      for (final tc in toolCalls.whereType<Map>())
        if ((tc['id'] ?? '').toString() case final id when id.isNotEmpty)
          id: tc,
    };
    final resolved = toolResultIdsInBlocks(recorded.expand((blocks) => blocks));
    final declared = <String>{};
    final responses = <List<Map<String, dynamic>>>[];
    for (final raw in recorded) {
      // A `server_tool_use` whose result never arrived — the stream stopped
      // between the two — would replay as a call with no output.
      final blocks = sanitize(raw)
        ..removeWhere(
          (block) =>
              block['type'] == 'server_tool_use' &&
              !resolved.contains((block['id'] ?? '').toString()),
        );
      // A hosted call this endpoint drops the block of replays as the client
      // pair instead, as every call did before these tools existed.
      final kept = toolUseIdsInBlocks(blocks);
      for (final id in toolUseIdsInBlocks(raw)) {
        declared.add(id);
        if (replayServerToolBlocks || kept.contains(id)) continue;
        final block = _toolUseBlockFromToolCall(cards[id]);
        if (block != null) blocks.add(block);
      }
      responses.add(blocks);
    }
    // A call the recording lost belongs to the response that opened the turn.
    for (final entry in cards.entries) {
      if (declared.contains(entry.key)) continue;
      final block = _toolUseBlockFromToolCall(entry.value);
      if (block != null) responses.first.add(block);
    }
    // A turn left with nothing to send still owns its `tool` messages.
    responses.removeWhere((blocks) => blocks.isEmpty);
    return _ReplayedTurn(
      responses: responses,
      text: joinedTextOfBlocks(recorded.expand((blocks) => blocks)),
      serverToolIds: replayServerToolBlocks
          ? {
              for (final block in recorded.expand((blocks) => blocks))
                if (block['type'] == 'server_tool_use')
                  (block['id'] ?? '').toString(),
            }
          : const <String>{},
    );
  }

  /// The responses a card recorded. A card written by an earlier version of
  /// the app carries its one response as `assistant_blocks`.
  static List<List<Map<String, dynamic>>>? _recordedResponses(Map tc) {
    final meta = tc['metadata'];
    if (meta is! Map) return null;
    final anthropic = meta['anthropic'];
    if (anthropic is! Map) return null;
    List<Map<String, dynamic>> blocksOf(Object? raw) => [
      if (raw is List)
        for (final block in raw.whereType<Map>()) block.cast<String, dynamic>(),
    ];
    final responses = anthropic['responses'];
    if (responses is List) {
      final read = [for (final raw in responses) blocksOf(raw)]
        ..removeWhere((blocks) => blocks.isEmpty);
      return read.isEmpty ? null : read;
    }
    final blocks = blocksOf(anthropic['assistant_blocks']);
    return blocks.isEmpty ? null : [blocks];
  }

  static Map<String, dynamic>? _toolUseBlockFromToolCall(Map? tc) {
    if (tc == null) return null;
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

  /// Semantic media detection only - custom attachment markers are not
  /// recognized. Attachments arrive via structured media-path keys /
  /// userImagePaths, plus Markdown ![](...).
  bool _hasMedia(Map<String, dynamic> m) =>
      shouldParseMarkdownImages(
        (m['content'] ?? '').toString(),
        skipImageParsing: skipImageParsing,
      ) ||
      parseInternalMediaRefs(m[multimodalInternalMediaPathsKey]).isNotEmpty;

  Future<Map<String, dynamic>> _plainMessage(
    Map<String, dynamic> m,
    String role, {
    required bool isLast,
    required List<Map<String, dynamic>> carriedImages,
  }) async {
    final raw = (m['content'] ?? '').toString();
    final hasAttachedImages =
        isLast && role == 'user' && (userImagePaths?.isNotEmpty == true);
    if (role != 'user' ||
        !(_hasMedia(m) || hasAttachedImages || carriedImages.isNotEmpty)) {
      return {'role': role, 'content': raw};
    }

    final split = await _splitParts(m, includeUserPaths: hasAttachedImages);
    final parts = <Map<String, dynamic>>[
      if (carriedImages.isNotEmpty) ...[
        // Without the label the model takes its own chart for an upload.
        {'type': 'text', 'text': 'Images from your previous reply:'},
        ...carriedImages,
      ],
      ...split.text,
      ...split.images,
    ];
    carriedImages.clear();
    return {'role': role, 'content': parts.isEmpty ? raw : parts};
  }

  /// Splits a message into the text and image blocks Claude accepts: Markdown
  /// images and internal media refs become image blocks, remote URLs and
  /// unsupported media stay as text.
  Future<({List<Map<String, dynamic>> text, List<Map<String, dynamic>> images})>
  _splitParts(Map<String, dynamic> m, {required bool includeUserPaths}) async {
    final raw = (m['content'] ?? '').toString();
    final text = <Map<String, dynamic>>[];
    final images = <Map<String, dynamic>>[];
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
        text.add({'type': 'text', 'text': source});
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
          images.add({
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
      images.add({
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
      text.add({'type': 'text', 'text': parsed.text});
    }
    for (final ref in parsed.images) {
      if (ref.kind == 'data' || ref.kind == 'path' || ref.kind == 'url') {
        await addClaudeImage(ref.src);
      }
    }
    final supplementalRefs = supplementalMediaRefs(
      internalRaw: m[multimodalInternalMediaPathsKey],
      userPaths: userImagePaths,
      includeUserPaths: includeUserPaths,
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
            text.add({'type': 'text', 'text': uri});
          }
        }
        continue;
      }
      await addClaudeImage(mediaRef.uri, explicitMime: mediaRef.mime);
    }
    return (text: text, images: images);
  }
}

String normalizeClaudeImageMime(String mime) {
  final normalized = mime.trim().toLowerCase();
  if (normalized == 'image/jpg') return 'image/jpeg';
  return normalized;
}

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

/// A persisted tool turn being replayed: its responses in the order the API
/// produced them, sanitised for this endpoint, and how far the replay got.
class _ReplayedTurn {
  _ReplayedTurn({
    required this.responses,
    required this.text,
    required this.serverToolIds,
  });

  final List<List<Map<String, dynamic>>> responses;

  /// The text of the whole turn, every response joined — what the persisted
  /// assistant message after it aggregates.
  final String text;

  /// Server tools replayed as their own blocks; the synthesised `tool` message
  /// for one of these would be an orphan `tool_result`.
  final Set<String> serverToolIds;

  int emitted = 0;
  final List<Map<String, dynamic>> messages = [];
}
