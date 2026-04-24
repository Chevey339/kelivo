import 'dart:convert' show jsonDecode;

import '../../../core/models/unified_thread.dart';
import 'chatgpt_importer.dart';
import 'gemini_importer.dart';
import 'perplexity_importer.dart';
import 'claude_importer.dart';

/// Result of an import operation.
class ImportResult {
  final List<UnifiedThread> imported;
  final List<ImportError> errors;

  const ImportResult({required this.imported, required this.errors});

  int get successCount => imported.length;
  int get errorCount => errors.length;
}

/// Describes a single import error.
class ImportError {
  final int index;
  final String message;

  const ImportError({required this.index, required this.message});

  @override
  String toString() => 'Item $index: $message';
}

/// Detected source format.
enum DetectedSource {
  chatgpt,
  gemini,
  perplexity,
  claude,
  kelivo,
  unknown;

  String get sourceName {
    switch (this) {
      case DetectedSource.chatgpt:
        return 'chatgpt';
      case DetectedSource.gemini:
        return 'gemini';
      case DetectedSource.perplexity:
        return 'perplexity';
      case DetectedSource.claude:
        return 'claude';
      case DetectedSource.kelivo:
        return 'kelivo';
      case DetectedSource.unknown:
        return 'other';
    }
  }
}

/// Coordinates detection and import from all supported chat platforms.
class ImportManager {
  final ChatGPTImporter _chatgpt;
  final GeminiImporter _gemini;
  final PerplexityImporter _perplexity;
  final ClaudeImporter _claude;

  ImportManager()
      : _chatgpt = ChatGPTImporter(),
        _gemini = GeminiImporter(),
        _perplexity = PerplexityImporter(),
        _claude = ClaudeImporter();

  /// Auto-detect the source format from the JSON structure.
  DetectedSource detectSource(dynamic parsedJson) {
    try {
      if (parsedJson is List) {
        if (parsedJson.isEmpty) return DetectedSource.unknown;
        final first = parsedJson.first;
        if (first is! Map) return DetectedSource.unknown;
        final map = first as Map<String, dynamic>;

        // ChatGPT: has 'mapping' and 'current_node'
        if (map.containsKey('mapping') && map.containsKey('current_node')) {
          return DetectedSource.chatgpt;
        }
        if (map.containsKey('mapping')) {
          return DetectedSource.chatgpt;
        }
        // Claude: has 'uuid' and 'chat_messages'
        if (map.containsKey('uuid') && map.containsKey('chat_messages')) {
          return DetectedSource.claude;
        }
        if (map.containsKey('name') && map.containsKey('chat_messages')) {
          return DetectedSource.claude;
        }
        // Gemini: has 'title' + 'messages' + 'createTime'
        if (map.containsKey('title') &&
            map.containsKey('messages') &&
            map.containsKey('createTime')) {
          return DetectedSource.gemini;
        }
        // Perplexity: has 'title' + 'messages' + ('url' or 'thread_id')
        if (map.containsKey('title') &&
            map.containsKey('messages') &&
            (map.containsKey('url') || map.containsKey('thread_id'))) {
          return DetectedSource.perplexity;
        }
        // Fallback: check message structure
        final messages = map['messages'] as List<dynamic>?;
        if (messages != null && messages.isNotEmpty) {
          final firstMsg = messages.first;
          if (firstMsg is Map) {
            final msgMap = firstMsg as Map<String, dynamic>;
            if (msgMap.containsKey('role') && msgMap.containsKey('content')) {
              if (msgMap.containsKey('citations')) {
                return DetectedSource.perplexity;
              }
              if (!msgMap.containsKey('author')) {
                return DetectedSource.perplexity;
              }
            }
          }
        }
      } else if (parsedJson is Map) {
        if (parsedJson.containsKey('items')) {
          final items = parsedJson['items'];
          if (items is List && items.isNotEmpty) {
            return detectSource(items);
          }
        }
        if (parsedJson.containsKey('sessions')) {
          return DetectedSource.gemini;
        }
        if (parsedJson.containsKey('accounts')) {
          return DetectedSource.claude;
        }
        if (parsedJson.containsKey('conversations')) {
          return DetectedSource.claude;
        }
        if (parsedJson.containsKey('threads')) {
          return DetectedSource.perplexity;
        }
      }
    } catch (_) {
      return DetectedSource.unknown;
    }
    return DetectedSource.unknown;
  }

  /// Import threads from a JSON string, auto-detecting the source.
  ImportResult importFromJson(String jsonString) {
    final dynamic parsed;
    try {
      parsed = jsonDecode(jsonString);
    } catch (e) {
      return ImportResult(
        imported: [],
        errors: [ImportError(index: 0, message: 'Invalid JSON: $e')],
      );
    }

    final source = detectSource(parsed);
    if (source == DetectedSource.unknown) {
      return ImportResult(
        imported: [],
        errors: [
          ImportError(
            index: 0,
            message:
                'Could not detect source format. Please select the source manually.',
          ),
        ],
      );
    }

    return importWithSource(jsonString, source);
  }

  /// Import threads from a JSON string with a known source.
  ImportResult importWithSource(String jsonString, DetectedSource source) {
    try {
      switch (source) {
        case DetectedSource.chatgpt:
          final threads = _chatgpt.importFromJson(jsonString);
          return ImportResult(imported: threads, errors: []);
        case DetectedSource.gemini:
          final threads = _gemini.importFromJson(jsonString);
          return ImportResult(imported: threads, errors: []);
        case DetectedSource.perplexity:
          final threads = _perplexity.importFromJson(jsonString);
          return ImportResult(imported: threads, errors: []);
        case DetectedSource.claude:
          final threads = _claude.importFromJson(jsonString);
          return ImportResult(imported: threads, errors: []);
        case DetectedSource.kelivo:
          final threads = _importKelivo(jsonString);
          return ImportResult(imported: threads, errors: []);
        case DetectedSource.unknown:
          return ImportResult(
            imported: [],
            errors: [
              ImportError(index: 0, message: 'Unknown source format'),
            ],
          );
      }
    } catch (e) {
      return ImportResult(
        imported: [],
        errors: [ImportError(index: 0, message: 'Import failed: $e')],
      );
    }
  }

  List<UnifiedThread> _importKelivo(String jsonString) {
    final dynamic parsed;
    try {
      parsed = jsonDecode(jsonString);
    } catch (e) {
      throw FormatException('Invalid JSON: $e');
    }

    if (parsed is List) {
      return (parsed as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map((m) => UnifiedThread.fromJson(m))
          .toList();
    }

    if (parsed is Map) {
      final map = parsed as Map<String, dynamic>;
      if (map.containsKey('threads')) {
        return (map['threads'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map((m) => UnifiedThread.fromJson(m))
            .toList();
      }
      return [UnifiedThread.fromJson(map)];
    }

    return [];
  }
}
