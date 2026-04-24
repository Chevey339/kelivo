import '../../../core/models/unified_thread.dart';
import '../../../core/models/unified_message.dart';
import '../../../core/models/message_attachment.dart';

/// Imports threads from a Perplexity AI export JSON.
///
/// Perplexity export format is a JSON array of thread objects.
/// Each thread has:
/// - title: String
/// - url: String (unique permalink)
/// - messages: [{ role: 'user' | 'assistant', content: String, timestamp: Number (unix ms) }]
/// - Assistant messages may have: citations: [{ url: String, title: String }]
class PerplexityImporter {
  /// Parse a Perplexity export JSON string into a list of [UnifiedThread].
  List<UnifiedThread> importFromJson(String jsonString) {
    final dynamic decoded;
    try {
      decoded = _parseJson(jsonString);
    } catch (e) {
      throw FormatException('Perplexity JSON parse error: $e');
    }

    final List<dynamic> threads;
    if (decoded is List) {
      threads = decoded;
    } else if (decoded is Map) {
      threads = (decoded['threads'] ?? decoded['items'] ?? []) as List<dynamic>;
    } else {
      threads = [];
    }

    final result = <UnifiedThread>[];
    for (final raw in threads) {
      if (raw is! Map) continue;
      try {
        final thread = _parseThread(raw as Map<String, dynamic>);
        if (thread != null) result.add(thread);
      } catch (_) {
        continue;
      }
    }
    return result;
  }

  UnifiedThread? _parseThread(Map<String, dynamic> json) {
    final title = json['title'] as String? ?? 'Perplexity Thread';
    final url = json['url'] as String?;
    // Use URL as the originalId if available
    final originalId = url ?? json['id'] as String?;

    final rawMessages = json['messages'] as List<dynamic>? ?? [];
    if (rawMessages.isEmpty) return null;

    DateTime? earliestTs;
    DateTime? latestTs;
    final messages = <UnifiedMessage>[];

    for (final raw in rawMessages) {
      if (raw is! Map) continue;
      final msg = _parseMessage(raw as Map<String, dynamic>);
      if (msg != null) {
        messages.add(msg);
        if (earliestTs == null || msg.timestamp.isBefore(earliestTs)) {
          earliestTs = msg.timestamp;
        }
        if (latestTs == null || msg.timestamp.isAfter(latestTs)) {
          latestTs = msg.timestamp;
        }
      }
    }

    if (messages.isEmpty) return null;

    final threadId = 'perplexity_${originalId ?? earliestTs!.millisecondsSinceEpoch}';

    return UnifiedThread(
      id: threadId,
      source: 'perplexity',
      originalId: originalId,
      title: title.trim().isNotEmpty ? title.trim() : 'Perplexity Thread',
      createdAt: earliestTs,
      updatedAt: latestTs ?? earliestTs,
      messages: messages,
      metadata: <String, dynamic>{
        'original_source': 'perplexity',
        if (url != null) 'url': url,
      },
    );
  }

  UnifiedMessage? _parseMessage(Map<String, dynamic> json) {
    final role = json['role'] as String? ?? 'user';
    final mappedRole = role.toLowerCase() == 'user' ? 'user' : 'assistant';
    final content = json['content'] as String? ?? '';
    final timestamp = _parseTimestamp(
      json['timestamp'] ?? json['created_at'],
    );

    if (content.trim().isEmpty) return null;

    // Handle citations in assistant messages
    final attachments = <MessageAttachment>[];
    final rawCitations = json['citations'] as List<dynamic>?;
    if (rawCitations != null && rawCitations.isNotEmpty) {
      for (final cit in rawCitations) {
        if (cit is Map) {
          final citMap = cit as Map<String, dynamic>;
          attachments.add(MessageAttachment(
            type: 'citation',
            url: citMap['url'] as String?,
            name: citMap['title'] as String?,
          ));
        } else if (cit is String) {
          attachments.add(MessageAttachment(
            type: 'citation',
            url: cit,
            name: 'Source',
          ));
        }
      }
    }

    return UnifiedMessage(
      role: mappedRole,
      content: content.trim(),
      timestamp: timestamp,
      attachments: attachments.isNotEmpty ? attachments : null,
    );
  }

  DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is num) {
      if (value > 1e11) {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt());
      }
      return DateTime.fromMillisecondsSinceEpoch((value * 1000).toInt());
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  dynamic _parseJson(String jsonString) {
    import 'dart:convert' show jsonDecode;
    return jsonDecode(jsonString);
  }
}
