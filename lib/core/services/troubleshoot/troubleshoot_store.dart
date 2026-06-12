import 'troubleshoot_data.dart';

class TroubleshootStore {
  TroubleshootStore._();

  static final Map<String, ErrorAnalysisResult> _results = {};

  static void set(String messageId, ErrorAnalysisResult result) {
    _results[messageId] = result;
  }

  static ErrorAnalysisResult? get(String messageId) => _results[messageId];

  static void remove(String messageId) => _results.remove(messageId);

  static void clearConversation(String conversationId) {
    _results.removeWhere((key, _) => key.startsWith('$conversationId-'));
  }

  static void clear() => _results.clear();
}
