import 'compress_context_options.dart';
import 'context_operation.dart';

typedef CompressionBudget = ({int usedTokens, int? contextWindow});

enum CompressionPhase {
  waiting,
  preparing,
  summarizing,
  merging,
  review,
  applying,
  completed,
  failed,
  cancelled,
  interrupted,
}

/// Configuration is resolved before dispatch; no page/BuildContext is retained.
class CompressionRequest {
  const CompressionRequest({
    required this.options,
    required this.model,
    required this.generate,
    required this.quoteMarker,
    this.contextWindowTokens,
  });
  final CompressContextOptions options;
  final String model;
  final String Function(int) quoteMarker;
  final int? contextWindowTokens;
  final Future<String> Function(String content, String requestId) generate;
}

class ContextCompressionTask {
  ContextCompressionTask({
    required this.id,
    required this.conversationId,
    required this.options,
    this.request,
    this.phase = CompressionPhase.waiting,
  });
  final String id;
  final String conversationId;
  final CompressContextOptions options;
  CompressionRequest? request;
  CompressionPhase phase;
  DateTime startedAt = DateTime.now();
  String? anchorGroupId;
  CompressionBudget? previousBudget;
  int completedParts = 0;
  int totalParts = 0;
  String? error;
  String summary = '';
  String? resultConversationId;
  ContextOperation? candidate;
  String? sourceFingerprint;
  CompressionBudget? budget;
  bool get active => switch (phase) {
    CompressionPhase.waiting ||
    CompressionPhase.preparing ||
    CompressionPhase.summarizing ||
    CompressionPhase.merging ||
    CompressionPhase.review ||
    CompressionPhase.applying => true,
    _ => false,
  };
  Map<String, dynamic> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'options': options.toJson(),
    'phase': phase.name,
    'summary': summary,
    'candidate': candidate?.toJson(),
    'error': error,
    'resultConversationId': resultConversationId,
    'startedAt': startedAt.toIso8601String(),
    'anchorGroupId': anchorGroupId,
  };
}
