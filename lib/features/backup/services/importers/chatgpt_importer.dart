import '../../../core/models/unified_thread.dart';
import '../../../core/models/unified_message.dart';
import '../../../core/models/message_attachment.dart';

/// Imports threads from a ChatGPT (OpenAI) export JSON.
///
/// ChatGPT export format (conversations.json) is a JSON array of conversation
/// objects. Each conversation has:
/// - id, title, create_time, update_time
/// - mapping: Map<String, Node> where each Node has:
///     - id, parent (nullable), children (List<String>)
///     - message (nullable) with:
///         - author.role: 'user' | 'assistant' | 'system'
///         - content.parts: List<String> (text) OR
///         - content.content_type: 'text' | 'code' | 'execution_output' | 'tether_quote'
/// - current_node: the active leaf node ID
class ChatGPTImporter {
  /// Parse a ChatGPT conversations.json string into a list of [UnifiedThread].
  List<UnifiedThread> importFromJson(String jsonString) {
    final dynamic decoded;
    try {
      decoded = _parseJson(jsonString);
    } catch (e) {
      throw FormatException('ChatGPT JSON parse error: $e');
    }

    final List<dynamic> conversations;
    if (decoded is List) {
      conversations = decoded;
    } else if (decoded is Map && decoded.containsKey('items')) {
      // Some exports wrap in { "items": [...] }
      conversations = (decoded['items'] as List<dynamic>?) ?? [];
    } else {
      conversations = [decoded];
    }

    final threads = <UnifiedThread>[];
    for (final raw in conversations) {
      if (raw is! Map) continue;
      try {
        final thread = _parseConversation(raw as Map<String, dynamic>);
        if (thread != null) threads.add(thread);
      } catch (_) {
        // Skip malformed conversations
        continue;
      }
    }
    return threads;
  }

  UnifiedThread? _parseConversation(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final title = _sanitizeTitle(json['title'] as String? ?? 'Untitled');
    final createTime = _parseTimestamp(json['create_time']);
    final updateTime = _parseTimestamp(json['update_time']);
    final mapping = json['mapping'] as Map<String, dynamic>? ?? {};
    final currentNodeId = json['current_node'] as String?;

    if (id == null) return null;

    // Walk from current_node up to root to get the active linear thread
    final messages = _flattenActiveTree(mapping, currentNodeId);
    if (messages.isEmpty) return null;

    // Extract model info from the first assistant message's metadata
    String? modelName;
    for (final msg in messages) {
      if (msg.role == 'assistant') {
        final meta = msg.metadata;
        if (meta != null && meta['model'] != null) {
          modelName = meta['model'] as String?;
          if (modelName != null) break;
        }
      }
    }

    final metadata = <String, dynamic>{
      'original_source': 'chatgpt',
      if (modelName != null) 'model': modelName,
    };

    return UnifiedThread(
      id: 'chatgpt_$id',
      source: 'chatgpt',
      originalId: id,
      title: title,
      createdAt: createTime,
      updatedAt: updateTime,
      messages: messages,
      metadata: metadata,
    );
  }

  List<UnifiedMessage> _flattenActiveTree(
    Map<String, dynamic> mapping,
    String? currentNodeId,
  ) {
    if (currentNodeId == null) return [];

    // Build node map
    final nodes = <String, Map<String, dynamic>>{};
    mapping.forEach((key, value) {
      if (value is Map) {
        nodes[key] = value.cast<String, dynamic>();
      }
    });

    // Walk from current_node up to root
    final nodeIds = <String>[];
    String? cursor = currentNodeId;
    while (cursor != null && nodes.containsKey(cursor)) {
      nodeIds.insert(0, cursor);
      final node = nodes[cursor]!;
      cursor = node['parent'] as String?;
    }

    // Convert nodes to messages in order
    final messages = <UnifiedMessage>[];
    for (final nodeId in nodeIds) {
      final node = nodes[nodeId]!;
      final msg = _parseNodeMessage(node, nodeId);
      if (msg != null) messages.add(msg);
    }

    return messages;
  }

  UnifiedMessage? _parseNodeMessage(
    Map<String, dynamic> node,
    String nodeId,
  ) {
    final message = node['message'] as Map<String, dynamic>?;
    if (message == null) return null;

    final author = message['author'] as Map<String, dynamic>? ?? {};
    final role = _mapRole(author['role'] as String? ?? 'user');
    final content = message['content'] as Map<String, dynamic>? ?? {};
    final contentType = content['content_type'] as String? ?? 'text';

    // Extract text content
    String textContent = '';
    final attachments = <MessageAttachment>[];

    if (contentType == 'text') {
      final parts = content['parts'] as List<dynamic>?;
      if (parts != null) {
        for (final part in parts) {
          if (part is String) {
            textContent += part;
          } else if (part is Map) {
            // Could be a multimodal part with image_url, etc.
            final partMap = part as Map<String, dynamic>;
            if (partMap['asset_pointer'] != null) {
              attachments.add(MessageAttachment(
                type: 'image',
                url: partMap['asset_pointer'] as String?,
                name: 'chatgpt_image',
                mimeType: 'image/png',
              ));
            }
            if (partMap['text'] != null) {
              textContent += partMap['text'] as String;
            }
          }
        }
      }
    } else if (contentType == 'code') {
      final text = content['text'] as String? ?? '';
      textContent = text;
      attachments.add(MessageAttachment(
        type: 'code',
        content: text,
        name: 'code_snippet',
        mimeType: 'text/plain',
      ));
    } else if (contentType == 'execution_output') {
      textContent = content['text'] as String? ?? '';
      attachments.add(MessageAttachment(
        type: 'tool_result',
        content: textContent,
        name: 'execution_output',
      ));
    } else if (contentType == 'tether_quote') {
      textContent = content['text'] as String? ?? '';
    }

    // Get timestamp
    final timestamp = _parseTimestamp(message['create_time']);

    // Get metadata
    final metadataMap = message['metadata'] as Map<String, dynamic>?;

    final metadata = <String, dynamic>{
      if (metadataMap != null) ...metadataMap,
      'original_node_id': nodeId,
      'content_type': contentType,
    };

    return UnifiedMessage(
      originalId: message['id'] as String?,
      role: role,
      content: textContent,
      timestamp: timestamp,
      attachments: attachments.isNotEmpty ? attachments : null,
      metadata: metadata,
    );
  }

  String _mapRole(String? role) {
    switch (role) {
      case 'user':
        return 'user';
      case 'assistant':
        return 'assistant';
      case 'system':
        return 'system';
      case 'tool':
        return 'tool';
      default:
        return 'user';
    }
  }

  DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is num) {
      // Unix timestamp (seconds or milliseconds)
      if (value > 1e11) {
        // Milliseconds
        return DateTime.fromMillisecondsSinceEpoch(value.toInt());
      }
      return DateTime.fromMillisecondsSinceEpoch(
        (value * 1000).toInt(),
      );
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  String _sanitizeTitle(String title) {
    if (title.trim().isEmpty) return 'Untitled Conversation';
    return title.trim();
  }

  dynamic _parseJson(String jsonString) {
    // Use dart:convert
    import 'dart:convert' show jsonDecode;
    return jsonDecode(jsonString);
  }
}
