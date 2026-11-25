import '../../../core/database/generation_run.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/message_part.dart';
import '../../../utils/unicode_case_fold.dart';
import '../../intelligent_ui/text/ui_search_text.dart';

/// A necessary piece of a preview query. A retained row is always verified
/// against the displayed text, including its Markdown source spans.
final class ConversationFindPrefilter {
  const ConversationFindPrefilter._(
    this.literals,
    this.ideographs,
    this.foldSources,
  );
  final List<String> literals;
  final bool ideographs;
  final String foldSources;

  static const maxSqlTextBytes = 16 * 1024;
  static const projectionMarkers = ['&', '<', '[', '\\', 'kelivo-'];
  static final _ideograph = RegExp(r'[\u3400-\u4DBF\u4E00-\u9FFF]');
  static final _word = RegExp(r'[\p{L}\p{N}]+', unicode: true);

  static ConversationFindPrefilter? forQuery(String query) {
    final sample = String.fromCharCodes(query.runes.take(32));
    final han = _ideograph.allMatches(sample).map((m) => m[0]!).toSet();
    if (han.isNotEmpty) {
      return ConversationFindPrefilter._(
        han.take(3).toList(growable: false),
        true,
        '',
      );
    }
    String? word;
    for (final match in _word.allMatches(sample)) {
      final token = match[0]!;
      // The sanitizer can repair supplementary characters from damaged UTF-16.
      if (token.runes.any((rune) => rune > 0xffff)) continue;
      if (word == null || token.length > word.length) word = token;
    }
    if (word == null) return null;
    final folded = word.runes.map(foldUnicodeScalar).join();
    return ConversationFindPrefilter._(
      [folded],
      false,
      nonAsciiFoldSources(folded),
    );
  }

  /// SQLite passes oversized bodies through to keep its transaction short.
  /// Check literal text on the search isolate before starting a Markdown parse.
  bool mayMatchLargeBody(ChatMessage message) {
    if (!ideographs ||
        message.isStreaming ||
        message.translation?.isNotEmpty == true) {
      return true;
    }
    // A UTF-16 code unit takes at most three UTF-8 bytes on disk.
    final text = message.parts.whereType<TextPart>().singleOrNull?.text;
    if (text != null && text.length > maxSqlTextBytes ~/ 3) {
      return literals.every(text.contains) ||
          projectionMarkers.any(text.contains);
    }
    return true;
  }
}

/// Only fields needed by the timeline projection cross the worker boundary.
/// A live MessagePartSnapshot itself can retain an unsendable WeakReference.
final class ConversationFindCandidate {
  static const batchSize = 48;

  ConversationFindCandidate(ChatMessage message, {this.surfaces = const {}})
    : id = message.id,
      conversationId = message.conversationId,
      role = message.role,
      parts = List.of(message.parts),
      reasoning = message.reasoningText,
      segments = message.reasoningSegmentsJson,
      translation = message.translation,
      streaming = message.isStreaming,
      generation = message.generationState;

  final String id, conversationId, role;
  final List<MessagePart> parts;
  final String? reasoning, segments, translation;
  final bool streaming;
  final GenerationRunState? generation;
  final Map<String, UiSearchSurfaceText> surfaces;

  ChatMessage toMessage() => ChatMessage(
    id: id,
    conversationId: conversationId,
    role: role,
    parts: parts,
    reasoningText: reasoning,
    reasoningSegmentsJson: segments,
    translation: translation,
    isStreaming: streaming,
  )..hydrateGenerationState(generation);
}
